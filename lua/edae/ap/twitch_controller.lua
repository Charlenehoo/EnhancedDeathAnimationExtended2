-- lua/edae/tc/twitch_controller.lua
-- 物理抽搐控制器：通过向布娃娃骨骼施加随机力来模拟抽搐
-- 底层只提供 Stop(ragdoll, reason) 接口，语义化别名由上层 Coordinator 提供
-- 停止后先清理上下文，再发出 OnTwitchFinished 事件

local MODULE_NAME = "TwitchController"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants        = include("edae/config/constants.lua")
local log              = include("edae/log/init.lua")
local Scheduler        = include("edae/coroutine_scheduler.lua")
local HealthManager    = include("edae/rm/health_manager.lua")
local EntityDataStore  = include("edae/eds/entity_data_store.lua")

local store            = EntityDataStore:ForOwner(MODULE_NAME)

local TWITCH_CTX_KEY   = "TwitchContext"

local TwitchController = {}

-- 获取白名单内且具有有效物理对象的骨骼名称列表
local function GetValidBoneList(ragdoll, whitelist)
    local valid = {}
    local count = ragdoll:GetPhysicsObjectCount()
    for i = 0, count - 1 do
        local boneID = ragdoll:TranslatePhysBoneToBone(i)
        if boneID then
            local boneName = ragdoll:GetBoneName(boneID)
            if whitelist[boneName] then
                local phyObj = ragdoll:GetPhysicsObjectNum(i)
                if IsValid(phyObj) then
                    table.insert(valid, boneName)
                end
            end
        end
    end
    return valid
end

-- 计算布娃娃所有物理对象的总质量
local function GetTotalMass(ragdoll)
    local totalMass = 0
    local count = ragdoll:GetPhysicsObjectCount()
    for i = 0, count - 1 do
        local phyObj = ragdoll:GetPhysicsObjectNum(i)
        if IsValid(phyObj) then
            totalMass = totalMass + phyObj:GetMass()
        end
    end
    return totalMass
end

-- 模拟原始 ApplyForce 的多帧施加效果（连续 10 帧）
local function ApplyForceOverFrames(ragdoll, boneName, forceVec)
    local boneID = ragdoll:LookupBone(boneName)
    if not boneID then return end
    local phyID = ragdoll:TranslateBoneToPhysBone(boneID)
    local phyObj = ragdoll:GetPhysicsObjectNum(phyID)
    if not IsValid(phyObj) then return end

    for i = 1, 10 do
        if not IsValid(ragdoll) or not IsValid(phyObj) then break end
        phyObj:ApplyForceOffset(forceVec, phyObj:GetPos())
        phyObj:ApplyForceCenter(Vector(0, 0, forceVec.z * 0.1))
        phyObj:AddAngleVelocity(-phyObj:GetAngleVelocity() / 10)
        if i < 10 then
            coroutine.yield({ type = "time", targetTime = CurTime() + FrameTime() })
        end
    end
end

-- 执行自定义效果器（与 AnimationPlayer 一致的接口）
local function RunEffects(ctx)
    if not ctx.effects then return end
    for idx, effect in ipairs(ctx.effects) do
        local stateKey = effect.name or idx
        local effectState = ctx.effectStates[stateKey]
        if not effectState then
            effectState = {}
            ctx.effectStates[stateKey] = effectState
        end
        if effect.predicate(ctx, effectState) then
            effect.action(ctx, effectState)
        end
    end
end

-- 安全清理：仅清除自己的上下文，防止误删新播放的上下文
local function cleanUp(ctx)
    local currentCtx = store:Get(ctx.ragdoll, TWITCH_CTX_KEY)
    if currentCtx == ctx then
        store:Clear(ctx.ragdoll)
    end
end

local function TwitchCoroutine(ragdoll, ctx)
    local initialHealth = ctx.initialHealth
    local boneList      = ctx.boneList
    local speedMode     = ctx.speedMode
    local massFix       = ctx.massFix
    local baseForce     = ctx.baseForce
    local intensity     = ctx.intensity

    local currentIndex  = 0
    local stopReason    = Constants.PlaybackReasons.CompletedNormally

    local function shouldTerminate()
        if not IsValid(ragdoll) then
            stopReason = Constants.PlaybackReasons.FailedByFall
            return true
        end
        if ctx.stopSignal then
            stopReason = ctx.requestedStopReason or Constants.PlaybackReasons.Cancelled
            return true
        end
        if HealthManager:IsDead(ragdoll) then
            stopReason = Constants.PlaybackReasons.InterruptedByHealthDepleted
            return true
        end
        return false
    end

    -- 预等待
    if ctx.preWait then
        for _, waitFunc in ipairs(ctx.preWait) do
            waitFunc(ctx)
            if shouldTerminate() then
                -- 预等待过程中可能被终止
                cleanUp(ctx)
                hook.Run(Constants.Events.OnTwitchFinished, ragdoll, stopReason)
                return
            end
        end
    end

    while not shouldTerminate() do
        RunEffects(ctx)

        local currentHealth = HealthManager:Get(ragdoll) or 0
        if currentHealth <= 0 then
            stopReason = Constants.PlaybackReasons.InterruptedByHealthDepleted
            break
        end
        local rate = math.max(currentHealth / initialHealth, 0)
        local r = math.ease.InOutCubic(rate)

        -- 构造基础力向量
        local mass = ragdoll:GetPhysicsObject():GetMass() * 10
        local forceMagnitude = math.Clamp(mass * baseForce, 0, 2000 * 0.12)
        local forceVec = Vector(0, 0, forceMagnitude * massFix * (0.9 * r + 0.1) *
            math.Rand(0.8, 1) * intensity)

        -- 选择目标骨骼
        currentIndex = currentIndex + 1
        if math.Rand(0, 1) > 0.5 then
            currentIndex = currentIndex + 1
        end
        if currentIndex > #boneList then
            currentIndex = 1
            table.Shuffle(boneList)
        end
        local boneName = boneList[currentIndex]

        -- 根据模式执行
        if speedMode == "High" then
            ApplyForceOverFrames(ragdoll, boneName, forceVec)

            if math.Rand(0, 1) > 0.5 then
                currentIndex = currentIndex + 1
                if currentIndex > #boneList then
                    currentIndex = 1
                    table.Shuffle(boneList)
                end
                Scheduler:Wait(0.01)
                if not shouldTerminate() then
                    ApplyForceOverFrames(ragdoll, boneList[currentIndex], forceVec)
                end
            end

            local mult = 10 - 9 * r
            local mult2 = math.max((-19 * intensity + 20), 1)
            local delay = math.Rand(0.15, 0.3) * mult * mult2
            Scheduler:Wait(delay)
        else -- "Low"
            local bias = 1 - rate
            local minDelay = Lerp(bias, 0.15, 1)
            local maxDelay = Lerp(bias, 3, 6)
            local delay = math.Rand(minDelay, maxDelay)

            local forceCount
            if delay < 0.5 then
                forceCount = 1
            else
                forceCount = math.random(1, 3)
            end

            for i = 0, forceCount - 1 do
                if i > 0 then
                    Scheduler:Wait(math.Rand(0.05, 0.15))
                    if shouldTerminate() then break end
                end
                ApplyForceOverFrames(ragdoll, boneName, forceVec)

                currentIndex = currentIndex + 1
                if currentIndex > #boneList then
                    currentIndex = 1
                    table.Shuffle(boneList)
                end
                boneName = boneList[currentIndex]
                Scheduler:Wait(0.01)
                if not shouldTerminate() then
                    ApplyForceOverFrames(ragdoll, boneName, forceVec)
                end
            end
            Scheduler:Wait(delay)
        end
    end

    -- 先清理，再发射事件
    cleanUp(ctx)
    hook.Run(Constants.Events.OnTwitchFinished, ragdoll, stopReason)
end

--- 启动抽搐
--- @param ragdoll Entity 布娃娃实体
--- @param opts table 抽搐选项，包含 boneWhitelist、preWait、effects、intensity、speedMode、initialHealth 等
--- @return boolean 是否成功启动
function TwitchController:Start(ragdoll, opts)
    if not IsValid(ragdoll) then return false end

    opts = opts or {}
    local whitelist = opts.boneWhitelist
    if not whitelist then return false end

    local intensity = opts.intensity or 1.0
    local speedMode = opts.speedMode
    local effects = opts.effects
    local preWait = opts.preWait
    local initialHealth = opts.initialHealth or HealthManager:Get(ragdoll)

    if initialHealth <= 0 then return false end

    local boneList = GetValidBoneList(ragdoll, whitelist)
    if #boneList == 0 then return false end
    table.Shuffle(boneList)

    local totalMass = GetTotalMass(ragdoll)
    local massFix = totalMass / 50

    if not speedMode then
        speedMode = math.random(2) == 1 and "High" or "Low"
    end

    local ctx = {
        ragdoll             = ragdoll,
        initialHealth       = initialHealth,
        boneList            = boneList,
        speedMode           = speedMode,
        massFix             = massFix,
        baseForce           = math.random(10, 15),
        intensity           = intensity,
        effects             = effects and table.Copy(effects) or nil,
        effectStates        = {},
        preWait             = preWait,
        stopSignal          = false,
        requestedStopReason = nil,
    }

    store:Set(ragdoll, TWITCH_CTX_KEY, ctx)
    Scheduler:Start(TwitchCoroutine, ragdoll, ctx)

    return true
end

--- 停止抽搐
--- @param ragdoll Entity
--- @param reason string 停止原因（Constants.PlaybackReasons 中的值）
--- @return boolean 是否找到并标记了活动上下文
function TwitchController:Stop(ragdoll, reason)
    log.trace("TwitchController:Stop called for ragdoll: ", tostring(ragdoll), " reason: ", tostring(reason))
    local ctx = store:Get(ragdoll, TWITCH_CTX_KEY)
    if not ctx then
        log.trace("TwitchController:Stop no active context for ragdoll: ", tostring(ragdoll))
        return false
    end

    ctx.requestedStopReason = reason or Constants.PlaybackReasons.Cancelled
    ctx.stopSignal = true
    return true
end

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = TwitchController
return TwitchController
