-- lua/edae/overlay/stiff.lua
-- 僵直叠加层：短暂冻结布娃娃的物理骨骼，模拟肌肉僵直 / 尸僵
--
-- 原理：
--   1. Pause PlaybackCoordinator（冻结动画时间轴 / 施力序列）
--   2. 抢占所有相关骨骼（BoneControlManager 的 onLost 会让各播放器跳过 CSC）
--   3. 对相邻骨骼对施加 AdvBallsocket 约束，限制角度在小范围
--   4. 到期后：解除约束 → 释放骨骼 → Resume 播放器
--
-- 优先级通过 Constants.BoneControlPriority.StiffOverlay 获取。
-- 骨骼关节表来自 edae/data/stiff_connections.lua。

local MODULE_NAME = "StiffOverlay"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants             = include("edae/core/constants.lua")
local log                   = include("edae/core/log/init.lua")
local Scheduler             = include("edae/core/coroutine_scheduler.lua")
local EntityDataStore       = include("edae/core/entity_data_store.lua")
local BoneControlManager    = include("edae/core/bone_control_manager.lua")
local HealthManager         = include("edae/core/health_manager.lua")
local RagdollBoneCache      = include("edae/core/ragdoll_bone_cache.lua")
local PlaybackCoordinator   = include("edae/playback/playback_coordinator.lua")
local STIFF_CONNECTIONS     = include("edae/data/stiff_connections.lua")

local store                 = EntityDataStore:ForOwner(MODULE_NAME)

local STORAGE_KEY           = "Stiff"
local BONE_CONTROL_OWNER    = MODULE_NAME

-- 骨骼控制优先级：来自 Constants，见 core/constants.lua 的 BoneControlPriority 表
local BONE_CONTROL_PRIORITY = Constants.BoneControlPriority.StiffOverlay

-- 默认参数
local DEFAULT_OPTIONS       = {
    duration    = 3.0,  -- 僵直持续时间（秒）
    angleLimit  = 8.0,  -- 关节角度限制（度），越小越僵直
    forcelimit  = 1000, -- 约束力上限
    torquelimit = 1000, -- 约束力矩上限
    friction    = 1.0,  -- 约束摩擦（0~1）
    onlyrotate  = 0,    -- 是否只限制旋转不限制位置
    nocollide   = 1,    -- 是否禁用父子间碰撞
    threshold   = 40,   -- Watch 模式：触发僵直的累计伤害阈值
    healthRatio = nil,  -- Watch 模式：或者血量低于最大值的比例时触发
    cooldown    = nil,  -- Watch 模式：两次触发之间的冷却时间，默认 duration + 2
}

-- ============================================================================
-- 内部辅助
-- ============================================================================

local function MergeOptions(opts)
    local result = {}
    for k, v in pairs(DEFAULT_OPTIONS) do
        result[k] = v
    end
    if opts then
        for k, v in pairs(opts) do
            result[k] = v
        end
    end
    return result
end

--- 从 STIFF_CONNECTIONS 收集所有涉及的骨骼名
--- @param ragdoll Entity
--- @return table<string, boolean> 骨骼名集合
--- @return table 有效的连接列表
local function CollectStiffBones(ragdoll)
    local bones = {}
    local connections = {}

    for _, conn in ipairs(STIFF_CONNECTIONS) do
        local childID = ragdoll:LookupBone(conn.child)
        local parentID = ragdoll:LookupBone(conn.parent)
        if childID and parentID then
            bones[conn.child] = true
            bones[conn.parent] = true
            connections[#connections + 1] = {
                childName  = conn.child,
                parentName = conn.parent,
                childID    = childID,
                parentID   = parentID,
            }
        end
    end

    return bones, connections
end

local function ApplyStiffConstraints(ragdoll, connections, opts)
    local constraints = {}
    local angleLimit = opts.angleLimit

    for _, conn in ipairs(connections) do
        local childPhysID  = ragdoll:TranslateBoneToPhysBone(conn.childID)
        local parentPhysID = ragdoll:TranslateBoneToPhysBone(conn.parentID)

        if childPhysID and parentPhysID
            and childPhysID >= 0 and parentPhysID >= 0
            and childPhysID ~= parentPhysID
        then
            local childPhys  = ragdoll:GetPhysicsObjectNum(childPhysID)
            local parentPhys = ragdoll:GetPhysicsObjectNum(parentPhysID)

            if IsValid(childPhys) and IsValid(parentPhys) then
                local jointWorldPos  = parentPhys:GetPos()
                local childLocalPos  = childPhys:WorldToLocal(jointWorldPos)
                local parentLocalPos = parentPhys:WorldToLocal(jointWorldPos)

                local c              = constraint.AdvBallsocket(
                    ragdoll, ragdoll,
                    childPhysID, parentPhysID,
                    childLocalPos, parentLocalPos,
                    opts.forcelimit, opts.torquelimit,
                    -angleLimit, -angleLimit, -angleLimit,
                    angleLimit, angleLimit, angleLimit,
                    opts.friction, opts.friction, opts.friction,
                    opts.onlyrotate,
                    opts.nocollide
                )

                if IsValid(c) then
                    constraints[#constraints + 1] = c
                end
            end
        end
    end

    return constraints
end

local function Release(ragdoll)
    local ctx = store:Get(ragdoll, STORAGE_KEY)
    if not ctx then return end

    store:Clear(ragdoll)

    if ctx.constraints then
        for _, c in ipairs(ctx.constraints) do
            if IsValid(c) then
                c:Remove()
            end
        end
    end

    if ctx.controlledBones then
        BoneControlManager:ReleaseBones(ragdoll, BONE_CONTROL_OWNER, ctx.controlledBones)
    end
    PlaybackCoordinator:Resume(ragdoll)

    log.trace("StiffOverlay: released on ", tostring(ragdoll))
end

-- ============================================================================
-- 协程主体
-- ============================================================================

local function stiffCoroutine(ragdoll, opts)
    local allBones, connections = CollectStiffBones(ragdoll)
    if next(allBones) == nil then
        log.warn("StiffOverlay: no valid bones on ragdoll ", tostring(ragdoll))
        return
    end

    PlaybackCoordinator:Pause(ragdoll)

    local acquired = BoneControlManager:RequestBones(
        ragdoll,
        BONE_CONTROL_OWNER,
        allBones,
        BONE_CONTROL_PRIORITY,
        function() return true end,
        nil,
        function()
            -- 被更高优先级抢占（如 NGM2 肢解 101）：整层释放
            Release(ragdoll)
        end
    )

    local acquiredCount = 0
    for _ in pairs(acquired) do acquiredCount = acquiredCount + 1 end
    if acquiredCount == 0 then
        log.warn("StiffOverlay: failed to acquire any bone on ", tostring(ragdoll))
        PlaybackCoordinator:Resume(ragdoll)
        return
    end

    local validConnections = {}
    for _, conn in ipairs(connections) do
        if acquired[conn.childName] and acquired[conn.parentName] then
            validConnections[#validConnections + 1] = conn
        end
    end

    local constraints = ApplyStiffConstraints(ragdoll, validConnections, opts)

    local ctx = {
        constraints     = constraints,
        controlledBones = acquired,
        active          = true,
    }
    store:Set(ragdoll, STORAGE_KEY, ctx)

    log.trace("StiffOverlay: applied on ", tostring(ragdoll),
        " (", #constraints, "/", #validConnections, " constraints, ",
        acquiredCount, " bones)")

    Scheduler:Wait(opts.duration)

    local currentCtx = store:Get(ragdoll, STORAGE_KEY)
    if currentCtx == ctx then
        Release(ragdoll)
    end
end

-- ============================================================================
-- 公共接口
-- ============================================================================

local StiffOverlay = {}

function StiffOverlay:Start(ragdoll, opts)
    if not IsValid(ragdoll) then return false end
    if store:Get(ragdoll, STORAGE_KEY) then
        log.trace("StiffOverlay: already active on ", tostring(ragdoll))
        return false
    end

    local mergedOpts = MergeOptions(opts)
    Scheduler:Start(stiffCoroutine, ragdoll, mergedOpts)
    return true
end

function StiffOverlay:Stop(ragdoll)
    if not IsValid(ragdoll) then return end
    Release(ragdoll)
end

function StiffOverlay:IsActive(ragdoll)
    if not IsValid(ragdoll) then return false end
    return store:Get(ragdoll, STORAGE_KEY) ~= nil
end

--- 监听指定布娃娃的受击事件，在满足条件时自动触发僵直。
---
--- 语义：
---   * 仅监听 target ragdoll 自身的 PostRagdollTakeDamage 事件，
---     其他布娃娃的受击事件会被忽略。
---   * 累计伤害达到 threshold，或血量低于 initialMaxHealth * healthRatio 时触发。
---   * 触发后累计伤害归零，并进入 cooldown 冷却期。
---   * 返回的句柄调用 Cancel() 可停止监听，但不会影响已经施加的僵直效果。
---     （若需立即停止僵直，请另行调用 StiffOverlay:Stop(ragdoll)。）
---
--- @param ragdoll Entity 目标布娃娃
--- @param opts table|nil 选项（duration / angleLimit / threshold / healthRatio / cooldown 等）
--- @return table 句柄 { Cancel = function() end, _coro = thread|nil }
function StiffOverlay:Watch(ragdoll, opts)
    if not IsValid(ragdoll) then
        return {
            Cancel = function() end,
        }
    end

    local mergedOpts       = MergeOptions(opts)
    local accumulated      = 0
    local cooldownUntil    = 0
    local canceled         = false

    local initialMaxHealth = HealthManager:Get(ragdoll) or 100
    if initialMaxHealth <= 0 then initialMaxHealth = 100 end

    local cooldown = mergedOpts.cooldown or (mergedOpts.duration + 2)

    local coro     = Scheduler:Start(function()
        while not canceled and IsValid(ragdoll) do
            local eventRagdoll, data = Scheduler:WaitForEvent(Constants.Events.PostRagdollTakeDamage)

            if canceled or not IsValid(ragdoll) then
                break
            end

            -- 只处理目标 ragdoll 自身的受击事件，忽略其他实体
            if eventRagdoll ~= ragdoll then
                continue
            end

            -- 冷却期内不累计伤害，直接忽略
            if CurTime() < cooldownUntil then
                continue
            end

            local dmg      = (data and data.finalDamage) or 0
            accumulated    = accumulated + dmg

            local health   = HealthManager:Get(ragdoll) or 0
            local byDamage = accumulated >= mergedOpts.threshold
            local byHealth = mergedOpts.healthRatio
                and health <= initialMaxHealth * mergedOpts.healthRatio

            if byDamage or byHealth then
                -- 若当前没有僵直层，施加；已经存在则跳过（避免打断）
                if not store:Get(ragdoll, STORAGE_KEY) then
                    StiffOverlay:Start(ragdoll, mergedOpts)
                end

                accumulated   = 0
                cooldownUntil = CurTime() + cooldown
            end
        end
    end)

    return {
        Cancel = function()
            canceled = true
        end,
        _coro = coro,
    }
end

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = StiffOverlay
return StiffOverlay
