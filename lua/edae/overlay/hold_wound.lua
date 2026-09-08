-- lua/edae/overlay/hold_wound.lua
-- 捂住伤口叠加层：将一只手焊接到伤口位置并维持抓握姿势
-- 仅支持单个活动实例（YAGNI）

local MODULE_NAME = "HoldWoundOverlay"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants = include("edae/core/constants.lua")
local log = include("edae/core/log/init.lua")
local EntityDataStore = include("edae/core/entity_data_store.lua")
local Scheduler = include("edae/core/coroutine_scheduler.lua")
local PlaybackCoordinator = include("edae/playback/playback_coordinator.lua")
local fingerPoseSets = include("edae/data/finger_pose_sets.lua")

local store = EntityDataStore:ForOwner(MODULE_NAME)

local HoldWoundOverlay = {}

local STORAGE_KEY = "HoldWound"
local CONSTRAINT_FORCELIMIT_INITIAL = 0
local CONSTRAINT_FORCELIMIT_FINAL = 1000
local DISTANCE_CHECK_INTERVAL = 0.2
local MAX_DISTANCE_SQR = 150

-- 应用手指姿势
local function ApplyFingerPose(ragdoll, handBoneName, poseSet)
    local fingerAngles = poseSet[handBoneName]
    if not fingerAngles then return end
    for fingerBoneName, angle in pairs(fingerAngles) do
        local boneID = ragdoll:LookupBone(fingerBoneName)
        if boneID then
            ragdoll:ManipulateBoneAngles(boneID, angle)
        end
    end
end

-- 将手部物理对象移动到伤口表面（考虑 AABB 偏移）
local function MoveHandToWound(ragdoll, handPhysID, woundPos)
    local handPhysObj = ragdoll:GetPhysicsObjectNum(handPhysID)
    if not IsValid(handPhysObj) then return false end

    local aabbMin, aabbMax = handPhysObj:GetAABB()
    local handCenter = (aabbMin + aabbMax) * 0.5
    local handWorldOffset = handPhysObj:LocalToWorld(handCenter) - handPhysObj:GetPos()
    local targetHandPos = woundPos - handWorldOffset
    handPhysObj:SetPos(targetHandPos)
    return true
end

-- 创建焊接约束
local function CreateWeld(ragdoll, handPhysID, woundPhysID)
    local constraintEnt = constraint.Weld(
        ragdoll, ragdoll,
        handPhysID, woundPhysID,
        CONSTRAINT_FORCELIMIT_INITIAL,
        true, false
    )
    return constraintEnt
end

-- 释放当前叠加层
local function Release(ragdoll)
    local ctx = store:Get(ragdoll, STORAGE_KEY)
    if not ctx then return end

    if IsValid(ctx.constraintEnt) then
        ctx.constraintEnt:Remove()
    end

    for _, boneName in ipairs(ctx.controlledBones) do
        PlaybackCoordinator:SetBoneSkip(ragdoll, boneName, false)
    end

    store:Clear(ragdoll)
end

--- 启动捂住伤口
--- @param ragdoll Entity 布娃娃实体
--- @param hitPos Vector 伤口位置（世界坐标）
--- @param hitPhysID number 伤口骨骼的物理对象索引
--- @return boolean 是否成功启动
function HoldWoundOverlay:Start(ragdoll, hitPos, hitPhysID)
    if not IsValid(ragdoll) or not hitPos or not hitPhysID then return false end
    if store:Get(ragdoll, STORAGE_KEY) then return false end -- 已存在

    -- 获取伤口骨骼的物理对象
    local woundPhysObj = ragdoll:GetPhysicsObjectNum(hitPhysID)
    if not IsValid(woundPhysObj) then return false end

    -- 根据伤口相对方向选择手（简单规则）
    local handSide = (hitPos - ragdoll:GetPos()):Dot(ragdoll:GetRight()) > 0 and "left" or "right"
    local handBoneName = handSide == "left" and "ValveBiped.Bip01_L_Hand" or "ValveBiped.Bip01_R_Hand"
    local handPhysID = ragdoll:TranslateBoneToPhysBone(ragdoll:LookupBone(handBoneName))
    if not handPhysID then return false end

    if PlaybackCoordinator:IsBoneSkip(ragdoll, handBoneName) then
        log.trace("HoldWoundOverlay: hand bone already skipped, aborting")
        return false
    end

    -- 仅控制手部骨骼（约束会将手固定在伤口处，主动画无需驱动）
    local controlledBones = { handBoneName }
    for _, boneName in ipairs(controlledBones) do
        PlaybackCoordinator:SetBoneSkip(ragdoll, boneName, true)
    end

    -- 应用紧握手指姿势
    local poseSet = fingerPoseSets.tight_fist
    if poseSet then
        ApplyFingerPose(ragdoll, handBoneName, poseSet)
    end

    -- 移动手到伤口位置
    if not MoveHandToWound(ragdoll, handPhysID, hitPos) then
        Release(ragdoll)
        return false
    end

    -- 创建约束
    local constraintEnt = CreateWeld(ragdoll, handPhysID, hitPhysID)
    if not constraintEnt then
        Release(ragdoll)
        return false
    end

    -- 保存上下文
    local ctx = {
        active = true,
        constraintEnt = constraintEnt,
        controlledBones = controlledBones,
        handPhysID = handPhysID,
        woundPhysID = hitPhysID,
        woundPhysObj = woundPhysObj,
        woundPosOffset = hitPos - woundPhysObj:GetPos(),
    }
    store:Set(ragdoll, STORAGE_KEY, ctx)

    -- 启动距离监测协程
    Scheduler:Start(function()
        while true do
            Scheduler:Wait(DISTANCE_CHECK_INTERVAL)
            if not IsValid(ragdoll) then break end
            local curCtx = store:Get(ragdoll, STORAGE_KEY)
            if not curCtx or curCtx ~= ctx then break end -- 已被释放或替换

            if not IsValid(curCtx.woundPhysObj) then
                Release(ragdoll)
                break
            end
            local handPhysObj = ragdoll:GetPhysicsObjectNum(curCtx.handPhysID)
            if not IsValid(handPhysObj) then
                Release(ragdoll)
                break
            end

            local currentWoundPos = curCtx.woundPhysObj:GetPos() + curCtx.woundPosOffset
            local distSqr = handPhysObj:GetPos():DistToSqr(currentWoundPos)
            if distSqr > MAX_DISTANCE_SQR then
                Release(ragdoll)
                break
            end
        end
    end)

    return true
end

--- 手动停止捂住伤口
--- @param ragdoll Entity 布娃娃实体
function HoldWoundOverlay:Stop(ragdoll)
    if not IsValid(ragdoll) then return end
    Release(ragdoll)
end

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = HoldWoundOverlay
return HoldWoundOverlay
