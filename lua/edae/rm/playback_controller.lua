-- lua/edae/rm/playback_controller.lua
-- 动画播放控制器：根据布娃娃状态和伤害上下文，选择动画并组装播放参数，最终调用 AnimationPlayer
-- 职责：将 AnimationSelector 选择的动画数据与姿态辅助（yaw）等结合，形成完整的 opts 传递给 AnimationPlayer

local MODULE_NAME = "AnimationPlaybackController"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants                   = include("edae/config/constants.lua")
local log                         = include("edae/log/init.lua")
local AnimationSelector           = include("edae/as/animation_selector.lua")
local AnimationPlayer             = include("edae/ap/animation_player.lua")
local RagdollPoseHelper           = include("edae/rm/pose_helper.lua")

local STATE_ENUM                  = Constants.LifeCycleHandler.STATE_ENUM

local AnimationPlaybackController = {}

-- ============================================================
-- 内部辅助：构建表现效果器（谓词 + 动作）
-- ============================================================

--- 构建基于时间间隔的血迹效果器
--- @param bloodCfg table 血迹配置
--- @return table effect 效果器
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
            local animModel = ctx.animationModel

            util.Decal(decal, ragdoll:GetPos(),
                ragdoll:GetPos() - Vector(0, 0, 50),
                { ragdoll, animModel })

            effectState.nextTime = CurTime() + interval
        end
    }
end

--- 构建基于距离的血迹效果器
--- @param bloodCfg table 血迹配置
--- @return table effect 效果器
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
            local animModel = ctx.animationModel

            util.Decal(decal, ragdoll:GetPos(),
                ragdoll:GetPos() - Vector(0, 0, 50),
                { ragdoll, animModel })

            effectState.lastPos = ragdoll:GetPos()
        end
    }
end

--- 构建血迹效果器（根据配置选择模式）
--- @param ragdoll Entity 布娃娃实体
--- @param state string 当前状态
--- @return table|nil effect 单个效果器（若无则返回 nil）
local function BuildBloodEffect(ragdoll, state)
    -- 仅爬行和挣扎状态需要血迹
    if state ~= STATE_ENUM.CRAWLING and state ~= STATE_ENUM.WRITHING then
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

--- 构建语音效果器（根据状态选择对应的语音，未配置的状态不播放）
--- @param owner Entity 布娃娃的所有者
--- @param state string 当前状态
--- @return table|nil effect 效果器（若该状态未配置语音则返回 nil）
local function BuildVoiceEffect(owner, state)
    local voiceCfg = Constants.VOICE
    if not voiceCfg then return nil end

    local stateConfig = voiceCfg.CONFIG and voiceCfg.CONFIG[state]
    if not stateConfig then
        return nil -- 该状态没有配置语音，不播放
    end

    local category = stateConfig.category or "external"
    local soundKey = stateConfig.key
    if not soundKey then return nil end

    local interval = stateConfig.interval or voiceCfg.INTERVAL or 10
    local priority = stateConfig.priority or voiceCfg.PRIORITY or 10
    local interrupt = stateConfig.interrupt
    if interrupt == nil then
        interrupt = voiceCfg.INTERRUPT
        if interrupt == nil then interrupt = true end
    end

    return {
        name = "voice_" .. tostring(state),
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
end

--- 构建所有效果器
--- @param ragdoll Entity
--- @param state string
--- @param owner Entity|nil 布娃娃的所有者（用于语音效果器）
--- @return table|nil effects 效果器数组（若无则返回 nil）
local function BuildEffects(ragdoll, state, owner)
    local effects = {}

    local bloodEffect = BuildBloodEffect(ragdoll, state)
    if bloodEffect then
        table.insert(effects, bloodEffect)
    end

    -- 语音效果器：仅当 owner 有效且该状态配置了语音时才添加
    if IsValid(owner) then
        local voiceEffect = BuildVoiceEffect(owner, state)
        if voiceEffect then
            table.insert(effects, voiceEffect)
        end
    end

    if #effects == 0 then
        return nil
    end

    return effects
end

-- ============================================================
-- 主播放接口
-- ============================================================

--- 为指定状态播放动画
--- @param ragdoll Entity 布娃娃实体
--- @param state string 当前状态（来自 STATE_ENUM）
--- @param damageContext table|nil 伤害上下文（仅在 FALLING 状态时需要，用于选择死亡动画）
--- @param owner Entity|nil 布娃娃的所有者（可选，用于 FALLING 状态计算 yaw；若未提供则回退到 ragdoll 自身角度）
--- @return boolean success 是否成功启动播放
function AnimationPlaybackController:PlayForState(ragdoll, state, damageContext, owner)
    if not IsValid(ragdoll) then
        log.warn("AnimationPlaybackController:PlayForState called with invalid ragdoll")
        return false
    end

    if not table.HasValue(STATE_ENUM, state) then
        log.warn("AnimationPlaybackController:PlayForState invalid state: ", tostring(state))
        return false
    end

    if state == STATE_ENUM.DEAD then
        return false
    end

    local yaw
    local groundPos
    if state == STATE_ENUM.FALLING then
        -- 死亡倒地动画：使用 owner 的角度，如果 owner 无效则退回 ragdoll 角度
        if owner and owner:IsValid() then
            yaw = RagdollPoseHelper:GetYawFromOwner(owner)
            groundPos = owner:GetPos()
        else
            log.trace("AnimationPlaybackController: owner not provided for FALLING state, using ragdoll yaw as fallback")
            yaw = RagdollPoseHelper:GetYawFromRagdoll(ragdoll)
        end
    else
        -- 爬行/挣扎等状态：直接从 ragdoll 提取
        yaw = RagdollPoseHelper:GetYawFromRagdoll(ragdoll)
    end

    -- 组装选择器所需信息
    local playBackInfo = {
        state = state,
        damageContext = damageContext,
        isFacingUp = RagdollPoseHelper:IsFacingUp(ragdoll),
        yaw = yaw, -- 虽然选择器目前未使用，但保留以便扩展
        groundPos = groundPos
    }

    -- 选择动画
    local playbackData = AnimationSelector:Select(playBackInfo)
    if not playbackData then
        log.warn("AnimationPlaybackController: no playback data for state ", state)
        return false
    end

    -- 构建效果器（传递 owner 以支持语音效果）
    local effects = BuildEffects(ragdoll, state, owner)

    -- 组装 AnimationPlayer 的 opts
    local opts = {
        totalLoops = playbackData.totalLoops,
        preWait = playbackData.preWait,
        yaw = yaw,
        groundPos = groundPos,
        effects = effects,
        enableRotate = true,
    }

    -- 启动播放
    local ctx = AnimationPlayer:Play(ragdoll, playbackData.animationName, opts)
    if not ctx then
        log.warn("AnimationPlaybackController: failed to start animation ", playbackData.animationName)
        return false
    end

    log.trace("AnimationPlaybackController: started animation '", playbackData.animationName, "' for state '", state,
        "' with yaw=", yaw)
    return true
end

-- 注册单例
_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = AnimationPlaybackController
return AnimationPlaybackController
