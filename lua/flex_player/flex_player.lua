-- lua/fp/flex_player.lua
-- FlexPlayer：面部形态键动画播放器
-- 负责驱动 ragdoll 的面部 Flex 权重与眼睛方向，支持 oscillate / spike_fade / fade 三种模式
-- 使用统一的 Scheduler 协程管理器，上下文存储在 EntityDataStore 中
-- 振荡衰减因子基于布娃娃当前血量计算（血量比例），血量越低，振荡幅度越小
--
-- 本模块已从 edae/fp/ 迁移至 fp/（与 edae 同级），作为独立扩展
-- 通过自注册 OnRagdollStateChange 事件钩子自动控制，无需 RagdollManager 直接调用

local MODULE_NAME = "FlexPlayer"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants          = include("edae/config/constants.lua")
local log                = include("edae/log/init.lua")
local Scheduler          = include("edae/coroutine_scheduler.lua")
local EntityDataStore    = include("edae/eds/entity_data_store.lua")
local HealthManager      = include("edae/rm/health_manager.lua")
local config             = include("fp/config.lua") -- 路径调整：从 fp/config.lua 加载

local store              = EntityDataStore:ForOwner(MODULE_NAME)
local FLEX_CTX_KEY       = "FlexContext"

-- ============================================================
-- 常量
-- ============================================================
local ANIM_DURATION      = 9.0
local OSCILLATE_DURATION = 99999 -- 无限振荡
local SPIKE_DURATION     = 0.3
local SPIKE_COOLDOWN     = 2.1
local FREQ               = 10.0

-- ============================================================
-- 数学与辅助
-- ============================================================
local function easeOutCubic(t)
    return 1 - (1 - t) ^ 3
end

local function MakeEyeDir(hor, ver)
    local cosV = math.cos(ver)
    return Vector(
        math.cos(hor) * cosV,
        math.sin(hor) * cosV,
        math.sin(ver)
    )
end

-- ============================================================
-- 眼睛控制策略（与原版一致）
-- ============================================================
local function SetEyeDirection_EyeTarget(ent, hor, ver)
    local dir = MakeEyeDir(hor, ver)

    if ent:IsRagdoll() then
        local eyesID = ent:LookupAttachment("eyes")
        if not eyesID or eyesID == 0 then return false end
        local attach = ent:GetAttachment(eyesID)
        if not attach then return false end
        ent:SetEyeTarget(dir * 200)
        return true
    else
        local eyePos
        if ent.LookupAttachment then
            local eyesID = ent:LookupAttachment("eyes")
            if eyesID and eyesID ~= 0 then
                local attach = ent:GetAttachment(eyesID)
                if attach then eyePos = attach.Pos end
            end
        end
        if not eyePos and ent.EyePos then eyePos = ent:EyePos() end
        if not eyePos then eyePos = ent:GetPos() end
        ent:SetEyeTarget(eyePos + dir * 200)
        return true
    end
end

local function SetEyeDirection_BoneAngles(ragdoll, hor, ver, eyeControlConfig)
    local base      = eyeControlConfig.baseAngles or Angle(0, 0, 0)
    local yaw       = math.deg(hor) * (eyeControlConfig.horScale or 1.0)
    local pitch     = math.deg(ver) * (eyeControlConfig.verScale or 1.0)

    local leftHor   = yaw * (eyeControlConfig.left and eyeControlConfig.left.horScale or 1.0)
    local leftVer   = pitch * (eyeControlConfig.left and eyeControlConfig.left.verScale or 1.0)
    local rightHor  = yaw * (eyeControlConfig.right and eyeControlConfig.right.horScale or 1.0)
    local rightVer  = pitch * (eyeControlConfig.right and eyeControlConfig.right.verScale or 1.0)

    local leftAng   = base + Angle(leftVer, leftHor, 0)
    local rightAng  = base + Angle(rightVer, rightHor, 0)

    local leftBone  = ragdoll:LookupBone(eyeControlConfig.leftBone or "Eye_L")
    local rightBone = ragdoll:LookupBone(eyeControlConfig.rightBone or "Eye_R")

    if leftBone then ragdoll:ManipulateBoneAngles(leftBone, leftAng) end
    if rightBone then ragdoll:ManipulateBoneAngles(rightBone, rightAng) end
    return leftBone ~= nil or rightBone ~= nil
end

local function SetEyeDirection_FlexEye(ragdoll, hor, ver, eyeControlConfig)
    local upWeight   = math.max(0, ver)
    local downWeight = math.max(0, -ver)

    local upL        = ragdoll:GetFlexIDByName(eyeControlConfig.upL)
    local downL      = ragdoll:GetFlexIDByName(eyeControlConfig.downL)
    local upR        = ragdoll:GetFlexIDByName(eyeControlConfig.upR)
    local downR      = ragdoll:GetFlexIDByName(eyeControlConfig.downR)

    if upL then ragdoll:SetFlexWeight(upL, upWeight * 0.5) end
    if downL then ragdoll:SetFlexWeight(downL, downWeight * 0.5) end
    if upR then ragdoll:SetFlexWeight(upR, upWeight * 0.5) end
    if downR then ragdoll:SetFlexWeight(downR, downWeight * 0.5) end
end

local function GetEyeControlFunction(eyeControl, eyeControlConfig)
    eyeControlConfig = eyeControlConfig or {}
    if eyeControl == "boneangle" then
        return function(ragdoll, hor, ver)
            SetEyeDirection_BoneAngles(ragdoll, hor, ver, eyeControlConfig)
        end
    elseif eyeControl == "flexeye" then
        if not eyeControlConfig then
            ErrorNoHalt("[FlexPlayer] eyeControl is 'flexeye' but eyeControlConfig is missing!\n")
            return function() end
        end
        return function(ragdoll, hor, ver)
            SetEyeDirection_FlexEye(ragdoll, hor, ver, eyeControlConfig)
        end
    else
        return SetEyeDirection_EyeTarget
    end
end

-- ============================================================
-- Flex 波形与眼睛状态创建
-- ============================================================
local function CreateFlexWaves(flexConfig)
    local flexWaves = {}
    for name, cfg in pairs(flexConfig) do
        local baseFreq = cfg.oscillateFreq or FREQ
        local baseAmp  = cfg.oscillateAmp or 0
        if baseAmp <= 0 then
            flexWaves[name] = nil
        else
            local beatDelta = cfg.oscillateBeatDelta
            if not beatDelta then
                if baseFreq < 1.2 then
                    beatDelta = math.Rand(0.3, 0.5)
                elseif baseFreq < 3.0 then
                    beatDelta = math.Rand(0.5, 0.7)
                else
                    beatDelta = math.Rand(0.6, 0.9)
                end
            end
            local highFreq = math.min(baseFreq * 2.31, 10)
            local norm = 1.0 + 0.6 + 0.25
            local layers = {
                { weight = 1.0 / norm,  freq = baseFreq,             phase = math.Rand(0, math.pi * 2) },
                { weight = 0.6 / norm,  freq = baseFreq + beatDelta, phase = math.Rand(0, math.pi * 2) },
                { weight = 0.25 / norm, freq = highFreq,             phase = math.Rand(0, math.pi * 2) },
            }
            flexWaves[name] = layers
        end
    end
    return flexWaves
end

local function CreateEyeState(template, freqMin, freqMax)
    return {
        oscillateBase  = template.oscillateBase,
        oscillateAmp   = template.oscillateAmp,
        oscillateFreq  = math.Rand(freqMin, freqMax),
        oscillatePhase = math.Rand(0, math.pi * 2),
        fadeTarget     = template.fadeTarget,
        spikeTarget    = template.spikeTarget,
    }
end

-- ============================================================
-- 权重计算
-- ============================================================
local function ComputeOscillateWeight(cfg, layers, t, decayFactor)
    local sum = 0
    for _, layer in ipairs(layers) do
        sum = sum + layer.weight * math.cos(layer.freq * t + layer.phase)
    end
    return cfg.oscillateBase - cfg.oscillateAmp * sum * decayFactor
end

local function ComputeEyeAngle(eyeState, t, decayFactor)
    return eyeState.oscillateBase
        + eyeState.oscillateAmp * math.sin(eyeState.oscillateFreq * t + eyeState.oscillatePhase) * decayFactor
end

-- ============================================================
-- 应用函数
-- ============================================================
local function ApplyAnimation(ragdoll, weights, currentHor, currentVer, setEyeDirection)
    for name, weight in pairs(weights) do
        local id = ragdoll:GetFlexIDByName(name)
        if id then
            ragdoll:SetFlexWeight(id, math.Clamp(weight, 0, 1))
        end
    end
    if setEyeDirection then
        setEyeDirection(ragdoll, currentHor, currentVer)
    end
end

-- ============================================================
-- 状态处理函数
-- ============================================================
local function ProcessOscillate(ctx, animState, t_local, elapsed)
    -- 基于血量的衰减因子计算
    local healthRatio = 1.0
    if IsValid(ctx.entity) then
        local currentHealth = HealthManager:Get(ctx.entity)
        local maxHealth = Constants.RagdollManager.MAX_HEALTH
        if maxHealth and maxHealth > 0 then
            healthRatio = math.Clamp(currentHealth / maxHealth, 0, 1)
        end
    end

    local globalDecay = healthRatio

    for name, cfg in pairs(ctx.flexConfig) do
        local decayFactor
        if cfg.oscillateDecay == false then
            decayFactor = 1
        else
            decayFactor = globalDecay
        end
        local layers = animState.flexWaves[name]
        if layers then
            animState.currentWeights[name] = ComputeOscillateWeight(cfg, layers, t_local, decayFactor)
        else
            animState.currentWeights[name] = cfg.oscillateBase
        end
    end

    animState.currentHor = ComputeEyeAngle(animState.eyeHoriz, t_local, globalDecay)
    animState.currentVer = ComputeEyeAngle(animState.eyeVert, t_local, globalDecay)
end

local function ProcessSpike(ctx, animState, t_local, elapsed)
    if t_local < SPIKE_DURATION then
        local progress = t_local / SPIKE_DURATION
        for name, cfg in pairs(ctx.flexConfig) do
            local from                     = animState.startWeights[name]
            local to                       = cfg.spikeTarget
            animState.currentWeights[name] = from + (to - from) * progress
        end
        local horTarget = animState.eyeHoriz.spikeTarget
        local verTarget = animState.eyeVert.spikeTarget
        animState.currentHor = animState.fadeStartHor + (horTarget - animState.fadeStartHor) * progress
        animState.currentVer = animState.fadeStartVer + (verTarget - animState.fadeStartVer) * progress
    else
        -- spike 结束，转入 fade
        for name, cfg in pairs(ctx.flexConfig) do
            animState.startWeights[name] = cfg.spikeTarget
        end
        animState.fadeStartHor = animState.eyeHoriz.spikeTarget
        animState.fadeStartVer = animState.eyeVert.spikeTarget
        animState.state = "fade"
        animState.stateStartTime = elapsed
        ctx.cooldownUntil = CurTime() + SPIKE_COOLDOWN
    end
end

local function ProcessFade(ctx, animState, t_local, elapsed)
    local remainingTime = ANIM_DURATION - animState.stateStartTime
    local progress = math.min(t_local / remainingTime, 1.0)
    local eased = easeOutCubic(progress)

    for name, cfg in pairs(ctx.flexConfig) do
        local from                     = animState.startWeights[name]
        local to                       = cfg.fadeTarget
        animState.currentWeights[name] = from + (to - from) * eased
    end
    animState.currentHor = animState.fadeStartHor + (animState.eyeHoriz.fadeTarget - animState.fadeStartHor) * eased
    animState.currentVer = animState.fadeStartVer + (animState.eyeVert.fadeTarget - animState.fadeStartVer) * eased

    if progress >= 1 then
        animState.state = "idle"
    end
end

local function ProcessIdle(ctx, animState)
    -- 保持当前权重与眼睛方向不变
end

-- ============================================================
-- 主协程：由 Scheduler 驱动
-- ============================================================
local function FlexCoroutine(ctx)
    local ent = ctx.entity
    local elapsed = 0
    local flexWaves = CreateFlexWaves(ctx.flexConfig)

    local animState = {
        state          = "oscillate",
        stateStartTime = 0,
        startWeights   = {},
        currentWeights = {},
        flexWaves      = flexWaves,
        currentHor     = 0,
        currentVer     = 0,
        fadeStartHor   = 0,
        fadeStartVer   = 0,
        eyeHoriz       = CreateEyeState(ctx.eyeConfig.horiz, 1.5, 3.0),
        eyeVert        = CreateEyeState(ctx.eyeConfig.vert, 2.0, 4.0),
        finished       = false,
    }

    for name, cfg in pairs(ctx.flexConfig) do
        animState.startWeights[name] = 0
        animState.currentWeights[name] = 0
    end

    while IsValid(ent) and not ctx.stopRequested do
        -- 检查是否有新的目标模式
        if ctx.requestedMode then
            local target = ctx.requestedMode
            ctx.requestedMode = nil

            -- 保存当前权重作为过渡起点
            for name, cfg in pairs(ctx.flexConfig) do
                animState.startWeights[name] = animState.currentWeights[name]
            end
            animState.fadeStartHor = animState.currentHor
            animState.fadeStartVer = animState.currentVer

            if target == "oscillate" then
                animState.state = "oscillate"
                animState.stateStartTime = elapsed
            elseif target == "spike_fade" then
                animState.state = "spike"
                animState.stateStartTime = elapsed
            elseif target == "fade" then
                animState.state = "fade"
                animState.stateStartTime = elapsed
            end
        end

        local t_local = elapsed - animState.stateStartTime

        if animState.state == "oscillate" then
            ProcessOscillate(ctx, animState, t_local, elapsed)
        elseif animState.state == "spike" then
            ProcessSpike(ctx, animState, t_local, elapsed)
        elseif animState.state == "fade" then
            ProcessFade(ctx, animState, t_local, elapsed)
        elseif animState.state == "idle" then
            ProcessIdle(ctx, animState)
        end

        ApplyAnimation(ent, animState.currentWeights, animState.currentHor, animState.currentVer, ctx.setEyeDirection)

        -- 等待下一帧
        coroutine.yield()
        elapsed = elapsed + FrameTime()
    end

    -- 清理上下文
    local currentCtx = store:Get(ent, FLEX_CTX_KEY)
    if currentCtx == ctx then
        store:Clear(ent)
    end
end

-- ============================================================
-- 对外接口
-- ============================================================
local FlexPlayer = {}

--- 启动 FlexPlayer，并设置初始模式
--- @param ragdoll Entity 布娃娃实体
--- @param mode string 模式："oscillate"、"spike_fade"、"fade"
--- @return boolean 是否成功
function FlexPlayer:Start(ragdoll, mode)
    if not IsValid(ragdoll) then return false end

    -- 如果已有上下文，则只更新目标模式，不重新创建协程
    local existingCtx = store:Get(ragdoll, FLEX_CTX_KEY)
    if existingCtx then
        existingCtx.requestedMode = mode
        return true
    end

    -- 获取模型配置
    local modelName = ragdoll:GetModel()
    local modelConfig = config.GetModelConfig(modelName)
    if not modelConfig then
        log.warn("FlexPlayer:Start - no config for model ", modelName)
        return false
    end

    local ctx = {
        entity = ragdoll,
        owner = nil,
        flexConfig = modelConfig.flexConfig,
        eyeConfig = modelConfig.eyeConfigTemplate,
        setEyeDirection = GetEyeControlFunction(
            modelConfig.eyeControl or "eyetarget",
            modelConfig.eyeControlConfig
        ),
        requestedMode = mode,
        stopRequested = false,
    }

    store:Set(ragdoll, FLEX_CTX_KEY, ctx)
    Scheduler:Start(FlexCoroutine, ctx)
    return true
end

--- 请求切换模式（如果协程正在运行，将在下一帧生效）
--- @param ragdoll Entity
--- @param mode string
function FlexPlayer:SwitchMode(ragdoll, mode)
    local ctx = store:Get(ragdoll, FLEX_CTX_KEY)
    if ctx then
        ctx.requestedMode = mode
    else
        -- 没有运行，直接启动
        self:Start(ragdoll, mode)
    end
end

--- 停止 FlexPlayer（清理上下文，协程将在下一帧退出）
--- @param ragdoll Entity
function FlexPlayer:Stop(ragdoll)
    local ctx = store:Get(ragdoll, FLEX_CTX_KEY)
    if ctx then
        ctx.stopRequested = true
    end
end

--- 检查是否正在运行
function FlexPlayer:IsRunning(ragdoll)
    return store:Get(ragdoll, FLEX_CTX_KEY) ~= nil
end

-- ============================================================
-- 自注册事件钩子（取代 RagdollManager 中的直接调用）
-- ============================================================
local STATE_ENUM = Constants.LifeCycleHandler.STATE_ENUM

hook.Add(Constants.Events.OnRagdollStateChange, MODULE_NAME .. "_OnRagdollStateChange",
    function(ragdoll, state, fromState)
        if not IsValid(ragdoll) then return end

        if state == STATE_ENUM.DEAD then
            if fromState == STATE_ENUM.CRAWLING then
                FlexPlayer:SwitchMode(ragdoll, "spike_fade")
            else
                FlexPlayer:SwitchMode(ragdoll, "fade")
            end
        else
            FlexPlayer:SwitchMode(ragdoll, "oscillate")
        end
    end)

-- 注册单例
_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = FlexPlayer
return FlexPlayer
