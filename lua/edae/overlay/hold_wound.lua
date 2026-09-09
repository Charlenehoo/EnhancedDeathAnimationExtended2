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
local BoneControlManager = include("edae/core/bone_control_manager.lua")
local fingerPoseSets = include("edae/data/finger_pose_sets.lua")
local RagdollBoneCache = include("edae/core/ragdoll_bone_cache.lua")

local store = EntityDataStore:ForOwner(MODULE_NAME)

local HoldWoundOverlay = {}

local STORAGE_KEY = "HoldWound"
local CONSTRAINT_FORCELIMIT_INITIAL = 0
local CONSTRAINT_FORCELIMIT_FINAL = 1000
local DISTANCE_CHECK_INTERVAL = 0.2
local MAX_DISTANCE_SQR = 150
local BONE_CONTROL_PRIORITY = 50 -- 高于基础动画(10)，低于严重伤害(100)和肢解(200)

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

    -- 释放手部骨骼控制权
    if ctx.boneControlOwnerID and ctx.controlledBones then
        BoneControlManager:ReleaseBones(ragdoll, ctx.boneControlOwnerID, ctx.controlledBones)
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
    local boneDataMap = RagdollBoneCache.GetBoneDataMap(ragdoll)
    local handData = boneDataMap[handBoneName]
    if not handData or not handData.physID then return false end
    local handPhysID = handData.physID
    if not handPhysID then return false end

    -- 申请手部骨骼控制权（合作式）
    local ownerID = MODULE_NAME
    local bonesToRequest = { [handBoneName] = true }
    local acquired = BoneControlManager:RequestBones(
        ragdoll,
        ownerID,
        bonesToRequest,
        BONE_CONTROL_PRIORITY,
        function() return true end, -- 该层存在期间始终有效
        nil,                        -- onGranted 无需额外操作，成功后继续创建约束
        function(owner, boneName)   -- onLost：被更高优先级抢占，立即释放
            Release(ragdoll)
        end
    )

    if not acquired[handBoneName] then
        log.trace("HoldWoundOverlay: failed to acquire hand bone control, aborting")
        return false
    end

    -- 应用紧握手指姿势
    local poseSet = fingerPoseSets.tight_fist
    if poseSet then
        ApplyFingerPose(ragdoll, handBoneName, poseSet)
    end

    -- 移动手到伤口位置
    if not MoveHandToWound(ragdoll, handPhysID, hitPos) then
        BoneControlManager:ReleaseBones(ragdoll, ownerID, bonesToRequest)
        return false
    end

    -- 创建约束
    local constraintEnt = CreateWeld(ragdoll, handPhysID, hitPhysID)
    if not constraintEnt then
        BoneControlManager:ReleaseBones(ragdoll, ownerID, bonesToRequest)
        return false
    end

    -- 保存上下文
    local ctx = {
        active = true,
        constraintEnt = constraintEnt,
        controlledBones = bonesToRequest,
        boneControlOwnerID = ownerID,
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
