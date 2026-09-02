-- lua/edae/rm/effect_builder.lua
-- 效果器构建模块：负责根据状态和所有者构建表现效果器数组
-- 包括血量衰减、血迹、语音等，供 AnimationPlayer / TwitchController 使用

local MODULE_NAME = "EffectBuilder"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants        = include("edae/config/constants.lua")
local log              = include("edae/log/init.lua")
local HealthManager    = include("edae/rm/health_manager.lua")
local LifeCycleHandler = include("edae/lch/life_cycle_handler.lua")

local STATE_ENUM       = Constants.LifeCycleHandler.STATE_ENUM

local EffectBuilder    = {}

-- ============================================================
-- 内部构建函数
-- ============================================================

--- 构建基于时间间隔的血迹效果器
local function BuildBloodTimeEffect(bloodCfg)
    local decal = bloodCfg.DECAL or "Blood"
    local interval = bloodCfg.INTERVAL or 1.0

    return {
        name = "blood_time",
        predicate = function(ctx, effectState)
            return CurTime() >= (effectState.nextTime or 0)
        end,
        action = function(ctx, effectState)
            local ragdoll = ctx.ragdoll
            local filter = { ragdoll }
            if ctx.animationModel then
                table.insert(filter, ctx.animationModel)
            end
            util.Decal(decal, ragdoll:GetPos(), ragdoll:GetPos() - Vector(0, 0, 50), filter)
            effectState.nextTime = CurTime() + interval
        end
    }
end

--- 构建基于距离的血迹效果器
local function BuildBloodDistanceEffect(bloodCfg)
    local decal = bloodCfg.DECAL or "Blood"
    local distance = bloodCfg.DISTANCE or 50

    return {
        name = "blood_distance",
        predicate = function(ctx, effectState)
            local curPos = ctx.ragdoll:GetPos()
            if not effectState.lastPos then
                effectState.lastPos = curPos
                return false
            end
            return curPos:DistToSqr(effectState.lastPos) >= (distance * distance)
        end,
        action = function(ctx, effectState)
            local ragdoll = ctx.ragdoll
            local filter = { ragdoll }
            if ctx.animationModel then
                table.insert(filter, ctx.animationModel)
            end
            util.Decal(decal, ragdoll:GetPos(), ragdoll:GetPos() - Vector(0, 0, 50), filter)
            effectState.lastPos = ragdoll:GetPos()
        end
    }
end

--- 构建血迹效果器（根据配置选择模式）
local function BuildBloodEffect(ragdoll, state)
    if state ~= STATE_ENUM.CRAWLING and state ~= STATE_ENUM.WRITHING and state ~= STATE_ENUM.TWITCHING then
        return nil
    end

    local bloodCfg = Constants.BLOOD
    if not bloodCfg or not bloodCfg.ENABLED then
        return nil
    end

    local mode = bloodCfg.MODE or "time"
    if mode == "time" then
        return BuildBloodTimeEffect(bloodCfg)
    elseif mode == "distance" then
        return BuildBloodDistanceEffect(bloodCfg)
    else
        log.warn("Unknown blood mode '", tostring(mode), "', no blood effect will be added")
        return nil
    end
end

--- 构建语音效果器
local function BuildVoiceEffects(owner, state)
    local voiceCfg = Constants.VOICE
    if not voiceCfg then return nil end

    local stateConfigs = voiceCfg.CONFIG and voiceCfg.CONFIG[state]
    if not stateConfigs then return nil end

    local effects = {}
    for _, cfg in ipairs(stateConfigs) do
        local category = cfg.category or "external"
        local soundKey = cfg.key
        if soundKey then
            local interval = cfg.interval or voiceCfg.INTERVAL or 10
            local priority = cfg.priority or voiceCfg.PRIORITY or 10
            local interrupt = cfg.interrupt
            if interrupt == nil then
                interrupt = voiceCfg.INTERRUPT
                if interrupt == nil then interrupt = true end
            end

            local effect = {
                name = "voice_" .. tostring(state) .. "_" .. tostring(soundKey),
                predicate = function(ctx, effectState)
                    return CurTime() >= (effectState.nextTime or 0)
                end,
                action = function(ctx, effectState)
                    if TFAVOX_PlayVoicePriority and IsValid(owner) then
                        local sounds = owner.TFAVOX_Sounds
                        if sounds and sounds[category] and sounds[category][soundKey] then
                            TFAVOX_PlayVoicePriority(owner, sounds[category][soundKey], priority, interrupt)
                        end
                    end
                    effectState.nextTime = CurTime() + interval
                end
            }
            table.insert(effects, effect)
        end
    end

    return #effects > 0 and effects or nil
end

--- 构建血量衰减效果器（每固定间隔扣血，触发健康变化钩子）
--- 构建血量衰减效果器（根据状态使用不同的间隔/伤害）
local function BuildHealthDrainEffect(state)
    local config   = Constants.DRAIN[state]
    local interval = config.interval
    local amount   = config.amount

    return {
        name = "health_drain",
        predicate = function(ctx, effectState)
            return CurTime() >= (effectState.nextTime or 0)
        end,
        action = function(ctx, effectState)
            local ragdoll = ctx.ragdoll
            local died = HealthManager:Damage(ragdoll, amount)

            hook.Run(Constants.Events.OnRagdollHealthChanged, ragdoll, HealthManager:Get(ragdoll))

            if died then
                LifeCycleHandler:SetState(ragdoll, STATE_ENUM.DEAD)
            end

            effectState.nextTime = CurTime() + interval
        end
    }
end

-- ============================================================
-- 主构建函数
-- ============================================================

--- 构建所有效果器
--- @param ragdoll Entity 布娃娃实体
--- @param state string 当前状态
--- @param owner Entity|nil 布娃娃所有者
--- @return table|nil effects 效果器数组
function EffectBuilder:Build(ragdoll, state, owner)
    if not IsValid(ragdoll) or not table.HasValue(STATE_ENUM, state) then
        log.warn("EffectBuilder:Build invalid arguments")
        return nil
    end

    local effects = {}

    -- 血量衰减（爬行、挣扎、抽搐）
    if state == STATE_ENUM.CRAWLING or state == STATE_ENUM.WRITHING or state == STATE_ENUM.TWITCHING then
        table.insert(effects, BuildHealthDrainEffect(state)) -- 传入 state
    end

    -- 血迹
    local bloodEffect = BuildBloodEffect(ragdoll, state)
    if bloodEffect then
        table.insert(effects, bloodEffect)
    end

    -- 语音
    if IsValid(owner) then
        -- 在 EffectBuilder:Build 中替换语音部分
        local voiceEffects = BuildVoiceEffects(owner, state)
        if voiceEffects then
            for _, ve in ipairs(voiceEffects) do
                table.insert(effects, ve)
            end
        end
    end

    if #effects == 0 then
        return nil
    end
    return effects
end

-- 注册单例
_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = EffectBuilder
return EffectBuilder
