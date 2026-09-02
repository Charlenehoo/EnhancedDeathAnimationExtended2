-- lua/edae/tc/twitch_controller.lua
-- 物理驱动的抽搐控制器：通过协程对布娃娃特定骨骼施加冲量
-- 模块风格与 AnimationPlayer 保持一致

local MODULE_NAME = "TwitchController"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants        = include("edae/config/constants.lua")
local log              = include("edae/log/init.lua")
local Scheduler        = include("edae/cs/coroutine_scheduler.lua")
local HealthManager    = include("edae/rm/health_manager.lua")
local LifeCycleHandler = include("edae/lch/life_cycle_handler.lua")
local EntityDataStore  = include("edae/eds/entity_data_store.lua")

local store            = EntityDataStore:ForOwner(MODULE_NAME)

local STATE_ENUM       = Constants.LifeCycleHandler.STATE_ENUM

-- 存储键
local TWITCH_CTX_KEY   = "TwitchContext"
local TWITCH_CORO_KEY  = "TwitchCoroutine"

local TwitchController = {}

-- ============================================================
-- 内部工具函数
-- ============================================================

-- 获取在骨骼白名单内且具有有效物理对象的骨骼名称列表
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

-- 对指定骨骼的物理对象施加一个向上的力
local function ApplyForce(ragdoll, boneName, forceVec)
    local boneID = ragdoll:LookupBone(boneName)
    if not boneID then return end
    local phyID = ragdoll:TranslateBoneToPhysBone(boneID)
    local phyObj = ragdoll:GetPhysicsObjectNum(phyID)
    if not IsValid(phyObj) then return end

    phyObj:ApplyForceCenter(forceVec)
    phyObj:AddAngleVelocity(-phyObj:GetAngleVelocity() / 10)
end

-- ============================================================
-- 抽搐协程
-- ============================================================

local function TwitchCoroutine(ragdoll, ctx)
    local endTime       = ctx.endTime
    local totalDuration = ctx.totalDuration
    local initialHealth = ctx.initialHealth
    local boneList      = ctx.boneList
    local speedMode     = ctx.speedMode
    local massFix       = ctx.massFix
    local baseForce     = ctx.baseForce
    local intensity     = ctx.intensity

    local currentIndex  = 0

    while true do
        -- 终止条件检查
        if not IsValid(ragdoll) then break end
        if HealthManager:IsDead(ragdoll) then break end
        if CurTime() >= endTime then break end
        if ctx.stopRequested then break end

        -- 计算 HP 衰减率
        local timeFactor = math.max((endTime - CurTime()) / totalDuration, 0)
        local currentHealth = HealthManager:Get(ragdoll) or 0
        if currentHealth <= 0 then break end
        local virtualHP = math.min(initialHealth * timeFactor, currentHealth)
        local rate = math.max(virtualHP / initialHealth, 0)
        if rate <= 0 then break end

        local r = math.ease.InOutCubic(rate)

        -- 生成基础力向量（向上为主，只保留 Z 轴分量）
        local dir = Vector(0, 0, 1)
        local ang = dir:Angle()
        ang:RotateAroundAxis(ang:Up(), math.random(-15, 15))
        local vel = ang:Forward() * baseForce
        local mass = ragdoll:GetPhysicsObject():GetMass() * 10
        local forceVec = Vector(0, 0, mass * (0.9 * r + 0.1) * massFix * intensity * math.Rand(0.8, 1.2))

        -- 选择目标骨骼（随机跳过、打乱列表）
        currentIndex = currentIndex + 1
        if math.Rand(0, 1) > 0.5 then
            currentIndex = currentIndex + 1
        end
        if currentIndex > #boneList then
            currentIndex = 1
            table.Shuffle(boneList) -- 原地打乱
        end
        local boneName = boneList[currentIndex]

        -- 根据模式执行
        if speedMode == "High" then
            -- 快速小幅高频
            ApplyForce(ragdoll, boneName, forceVec)
            -- 有一定概率立即再对下一个骨骼施力
            if math.Rand(0, 1) > 0.5 then
                currentIndex = currentIndex + 1
                if currentIndex > #boneList then
                    currentIndex = 1
                    table.Shuffle(boneList)
                end
                local secondBone = boneList[currentIndex]
                Scheduler:Wait(0.01)
                ApplyForce(ragdoll, secondBone, forceVec)
            end
            -- 计算延迟
            local mult = 10 - 9 * r
            local mult2 = math.max((-19 * intensity + 20), 1)
            local delay = math.Rand(0.15, 0.3) * mult * mult2
            Scheduler:Wait(delay)
        else -- "Low"
            -- 慢速大幅低频
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
                end
                ApplyForce(ragdoll, boneName, forceVec)
                -- 移到下一个骨骼
                currentIndex = currentIndex + 1
                if currentIndex > #boneList then
                    currentIndex = 1
                    table.Shuffle(boneList)
                end
                boneName = boneList[currentIndex]
            end
            Scheduler:Wait(delay)
        end
    end

    -- 清理存储
    store:Clear(ragdoll)
    log.trace("TwitchController: twitch ended for ", ragdoll)

    -- 如果是因为时间耗尽或虚拟 HP 归零，则触发死亡
    if IsValid(ragdoll) and not HealthManager:IsDead(ragdoll) then
        HealthManager:Set(ragdoll, 0)
        LifeCycleHandler:SetState(ragdoll, STATE_ENUM.DEAD)
    end
end

-- ============================================================
-- 公共接口
-- ============================================================

--- 启动抽搐
--- @param ragdoll Entity 布娃娃实体
--- @param opts table|nil 可选参数：{ boneWhitelist, totalDuration, intensity, speedMode }
--- @return boolean success
function TwitchController:Start(ragdoll, opts)
    if not IsValid(ragdoll) then
        log.warn("TwitchController:Start invalid ragdoll")
        return false
    end

    -- 若已在抽搐则先停止
    self:Stop(ragdoll)

    opts = opts or {}
    local whitelist = opts.boneWhitelist or Constants.BoneWhitelists.TwitchTb
    local totalDuration = opts.totalDuration or math.random(10, 20) -- 默认10-20秒
    local intensity = opts.intensity or 1.0
    local speedMode = opts.speedMode                                -- 若不指定则随机

    -- 获取有效骨骼列表并打乱
    local boneList = GetValidBoneList(ragdoll, whitelist)
    if #boneList == 0 then
        log.warn("TwitchController:Start no valid bones for twitch")
        return false
    end
    table.Shuffle(boneList)

    -- 质量修正系数
    local totalMass = GetTotalMass(ragdoll)
    local massFix = totalMass / 50 -- 理想重量 50

    -- 初始健康值
    local initialHealth = HealthManager:Get(ragdoll)
    if initialHealth <= 0 then
        log.warn("TwitchController:Start ragdoll already dead")
        return false
    end

    -- 随机选择速度模式
    if not speedMode then
        speedMode = math.random(2) == 1 and "High" or "Low"
    end

    local ctx = {
        ragdoll       = ragdoll,
        endTime       = CurTime() + totalDuration,
        totalDuration = totalDuration,
        initialHealth = initialHealth,
        boneList      = boneList,
        speedMode     = speedMode,
        massFix       = massFix,
        baseForce     = math.random(10, 15),
        intensity     = intensity,
        stopRequested = false,
    }

    store:Set(ragdoll, TWITCH_CTX_KEY, ctx)
    local coro = Scheduler:Start(TwitchCoroutine, ragdoll, ctx)
    store:Set(ragdoll, TWITCH_CORO_KEY, coro)

    log.trace("TwitchController: started twitch for ", ragdoll, " mode=", speedMode, " duration=", totalDuration)
    return true
end

--- 停止抽搐
--- @param ragdoll Entity
function TwitchController:Stop(ragdoll)
    if not IsValid(ragdoll) then return end

    local ctx = store:Get(ragdoll, TWITCH_CTX_KEY)
    if ctx then
        ctx.stopRequested = true
    end

    -- 立即清除存储，协程会在下一次循环检查时退出
    store:Clear(ragdoll)
end

-- 注册单例
_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = TwitchController
return TwitchController
