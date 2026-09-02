-- lua/edae/tc/twitch_controller.lua
-- 物理驱动的抽搐控制器（基于原始 animrag_writhe.lua 逻辑重构）
-- 使用 CoroutineScheduler 实现循环，使用 HealthManager 获取血量并计算衰减

local MODULE_NAME = "TwitchController"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants        = include("edae/config/constants.lua")
local log              = include("edae/log/init.lua")
local Scheduler        = include("edae/coroutine_scheduler.lua")
local HealthManager    = include("edae/rm/health_manager.lua")
local LifeCycleHandler = include("edae/lch/life_cycle_handler.lua")
local EntityDataStore  = include("edae/eds/entity_data_store.lua")

local store            = EntityDataStore:ForOwner(MODULE_NAME)

local STATE_ENUM       = Constants.LifeCycleHandler.STATE_ENUM
local TWITCH_CTX_KEY   = "TwitchContext"

local TwitchController = {}

-- ============================================================
-- 内部工具函数
-- ============================================================

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
        phyObj:ApplyForceCenter(Vector(0, 0, forceVec.z * 0.1)) -- 近似原始额外中心力
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

-- ============================================================
-- 抽搐协程
-- ============================================================

local function TwitchCoroutine(ragdoll, ctx)
    local initialHealth = ctx.initialHealth
    local boneList      = ctx.boneList
    local speedMode     = ctx.speedMode
    local massFix       = ctx.massFix
    local baseForce     = ctx.baseForce
    local intensity     = ctx.intensity

    local currentIndex  = 0

    local function shouldTerminate()
        return not IsValid(ragdoll) or
            HealthManager:IsDead(ragdoll) or
            ctx.stopSignal
    end

    if ctx.preWait then
        for _, waitFunc in ipairs(ctx.preWait) do
            waitFunc(ctx)
            if shouldTerminate() then return end
        end
    end

    while not shouldTerminate() do
        RunEffects(ctx)

        -- 根据当前血量计算衰减率
        local currentHealth = HealthManager:Get(ragdoll) or 0
        if currentHealth <= 0 then break end
        local rate = math.max(currentHealth / initialHealth, 0)
        local r = math.ease.InOutCubic(rate)


        -- 构造基础力向量（Z 轴向上，原始逻辑最终只保留 Z 分量）
        local mass = ragdoll:GetPhysicsObject():GetMass() * 10
        local forceMagnitude = math.Clamp(mass * baseForce, 0, 2000 * 0.12)
        local forceVec = Vector(0, 0, forceMagnitude * massFix * (0.9 * r + 0.1) *
            math.Rand(0.8, 1) * intensity)

        -- 选择目标骨骼（随机跳过，达到末尾重新打乱）
        currentIndex = currentIndex + 1
        if math.Rand(0, 1) > 0.5 then
            currentIndex = currentIndex + 1
        end
        if currentIndex > #boneList then
            currentIndex = 1
            table.Shuffle(boneList)
        end
        local boneName = boneList[currentIndex]

        -- 根据模式执行不同的施力与延迟逻辑
        if speedMode == "High" then
            -- 快速小幅高频：施加一次力，可能立刻对第二个骨骼施力
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

            -- 延迟随衰减因子增大（HP 越低延迟越长）
            local mult = 10 - 9 * r
            local mult2 = math.max((-19 * intensity + 20), 1)
            local delay = math.Rand(0.15, 0.3) * mult * mult2
            Scheduler:Wait(delay)
        else -- "Low"
            -- 慢速大幅低频：可能连续施加多次力（最多3次），每次可能对两个骨骼
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

                -- 立即对下一个骨骼施力（模拟原始中对两个骨骼的操作）
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

    -- 清理存储
    store:Clear(ragdoll)
    log.trace("TwitchController: twitch ended for ", ragdoll)
end

-- ============================================================
-- 公共接口
-- ============================================================

--- 启动抽搐
--- @param ragdoll Entity 布娃娃实体
--- @param opts table 可选参数：
---   opts.boneWhitelist table 骨骼白名单（必填）
---   opts.totalDuration number 总持续时间（秒），默认随机 10~20
---   opts.intensity number 强度系数，默认 1.0
---   opts.speedMode string 速度模式："High" 或 "Low"，不指定则随机
---   opts.effects table|nil 自定义效果数组，格式同 AnimationPlayer
---   opts.preWait table|nil 等待函数数组，格式同 AnimationPlayer
--- @return boolean success
function TwitchController:Start(ragdoll, opts)
    if not IsValid(ragdoll) then return false end

    self:Stop(ragdoll)

    opts = opts or {}
    local whitelist = opts.boneWhitelist
    if not whitelist then return false end

    local intensity = opts.intensity or 1.0
    local speedMode = opts.speedMode
    local effects = opts.effects
    local preWait = opts.preWait

    local boneList = GetValidBoneList(ragdoll, whitelist)
    if #boneList == 0 then return false end
    table.Shuffle(boneList)

    local totalMass = GetTotalMass(ragdoll)
    local massFix = totalMass / 50

    local initialHealth = HealthManager:Get(ragdoll)
    if initialHealth <= 0 then return false end

    if not speedMode then
        speedMode = math.random(2) == 1 and "High" or "Low"
    end

    local ctx = {
        ragdoll       = ragdoll,
        initialHealth = initialHealth,
        boneList      = boneList,
        speedMode     = speedMode,
        massFix       = massFix,
        baseForce     = math.random(10, 15),
        intensity     = intensity,
        effects       = effects,
        effectStates  = {},
        preWait       = preWait,
        stopSignal    = false,
    }

    store:Set(ragdoll, TWITCH_CTX_KEY, ctx)
    Scheduler:Start(TwitchCoroutine, ragdoll, ctx)

    return true
end

--- 停止抽搐
--- @param ragdoll Entity
function TwitchController:Stop(ragdoll)
    if not IsValid(ragdoll) then return end

    local ctx = store:Get(ragdoll, TWITCH_CTX_KEY)
    if ctx then
        ctx.stopSignal = true
    end
    store:Clear(ragdoll) -- 立即清除存储，协程将在下一次检查时退出
end

-- 注册单例
_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = TwitchController
return TwitchController
