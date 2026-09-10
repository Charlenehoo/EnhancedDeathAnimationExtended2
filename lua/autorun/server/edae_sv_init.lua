-- lua/autorun/server/edae_sv_init.lua
include("edae/ragdoll/ragdoll_manager.lua")

local Constants = include("edae/core/constants.lua")
for k, v in pairs(Constants.NETWORK_STRING) do
    util.AddNetworkString(v)
end
local AnimationPlayer     = include("edae/playback/animation_player.lua")
local PlaybackCoordinator = include("edae/playback/playback_coordinator.lua")
local LifeCycleHandler    = include("edae/state/life_cycle_handler.lua")
local HealthManager       = include("edae/core/health_manager.lua")
local BoneControlManager  = include("edae/core/bone_control_manager.lua")
local helper              = include("edae/helper.lua")

include("edae/damage/damage_context_manager.lua")   -- 翻译活体伤害 → PostCreateRagdoll 事件
include("edae/damage/ragdoll_damage_processor.lua") -- 翻译布娃娃伤害 → PostRagdollTakeDamage 事件

EnhancedDeathAnimationExtended                                     = EnhancedDeathAnimationExtended or {}

EnhancedDeathAnimationExtended.Events                              = Constants.Events
EnhancedDeathAnimationExtended.PlaybackReasons                     = Constants.PlaybackReasons
EnhancedDeathAnimationExtended.STATE_ENUM                          = Constants.LifeCycleHandler.STATE_ENUM

EnhancedDeathAnimationExtended.Interface                           = {}

-- ============================================================================
-- 骨骼控制接口
-- ============================================================================

EnhancedDeathAnimationExtended.Interface.RequestBoneControl        = function(ragdoll, ownerID, bones, priority,
                                                                              isActiveFunc, onGranted, onLost, onDeny)
    return BoneControlManager:RequestBones(ragdoll, ownerID, bones, priority, isActiveFunc, onGranted, onLost, onDeny)
end

EnhancedDeathAnimationExtended.Interface.ReleaseBoneControl        = function(ragdoll, ownerID, bones)
    BoneControlManager:ReleaseBones(ragdoll, ownerID, bones)
end

EnhancedDeathAnimationExtended.Interface.ReleaseAllBoneControls    = function(ragdoll, ownerID)
    BoneControlManager:ReleaseAllBones(ragdoll, ownerID)
end

EnhancedDeathAnimationExtended.Interface.GetBoneOwner              = function(ragdoll, boneName)
    return BoneControlManager:GetOwner(ragdoll, boneName)
end

--- 获取 EDAE 内部所有 owner 使用过的最大骨骼控制优先级。
---
--- 契约：
---   * 外部兼容模块（如 ngm2_edae_compat）应使用此值 + 1 及以上作为优先级，
---     以保证能够抢占 EDAE 内部任何 owner 的骨骼控制权。
---   * 此值由 Constants.BoneControlPriority 表在加载时自动计算。
---   * EDAE 内部若新增 owner 且优先级不超过当前 MAX_LOCAL，契约自动成立，
---     外部无需重新适配。
---   * EDAE 内部若确需突破当前 MAX_LOCAL，属于破坏性变更，必须同步通知
---     所有外部兼容模块。
---
--- @return number
EnhancedDeathAnimationExtended.Interface.GetMaxBoneControlPriority = function()
    return Constants.BoneControlPriority.MAX_LOCAL
end

-- ============================================================================
-- 播放控制接口
-- ============================================================================

EnhancedDeathAnimationExtended.Interface.StopPlayback              = function(ragdoll, reason)
    return PlaybackCoordinator:Stop(ragdoll, reason)
end

-- ============================================================================
-- 状态与健康接口
-- ============================================================================

EnhancedDeathAnimationExtended.Interface.GetState                  = function(ragdoll)
    return LifeCycleHandler:GetState(ragdoll)
end

EnhancedDeathAnimationExtended.Interface.GetHealth                 = function(ragdoll)
    return HealthManager:Get(ragdoll)
end

EnhancedDeathAnimationExtended.Interface.DamageHealth              = function(ragdoll, damage)
    return HealthManager:Damage(ragdoll, damage)
end

-- ============================================================================
-- 骨骼辅助
-- ============================================================================

-- 获取指定骨骼及其所有子骨骼的名称列表
EnhancedDeathAnimationExtended.Interface.GetBoneChain              = function(ragdoll, rootBoneName)
    return helper.GetBoneChain(ragdoll, rootBoneName)
end

-- PreRagdollInitialized：在布娃娃初始化前触发，参数为 (owner, ragdoll, initFunc)
-- 返回值：
--   true  : 外部接管初始化，模块不再自动调用 initFunc
--   其他  : 立即初始化

hook.Run("EDAE_Loaded")
