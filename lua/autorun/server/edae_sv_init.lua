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

EnhancedDeathAnimationExtended                                  = EnhancedDeathAnimationExtended or {}

EnhancedDeathAnimationExtended.Events                           = Constants.Events
EnhancedDeathAnimationExtended.PlaybackReasons                  = Constants.PlaybackReasons
EnhancedDeathAnimationExtended.STATE_ENUM                       = Constants.LifeCycleHandler.STATE_ENUM

EnhancedDeathAnimationExtended.Interface                        = {}
EnhancedDeathAnimationExtended.Interface.RequestBoneControl     = function(ragdoll, ownerID, bones, priority,
                                                                           isActiveFunc, onGranted, onLost, onDeny)
    return BoneControlManager:RequestBones(ragdoll, ownerID, bones, priority, isActiveFunc, onGranted, onLost, onDeny)
end

EnhancedDeathAnimationExtended.Interface.ReleaseBoneControl     = function(ragdoll, ownerID, bones)
    BoneControlManager:ReleaseBones(ragdoll, ownerID, bones)
end

EnhancedDeathAnimationExtended.Interface.ReleaseAllBoneControls = function(ragdoll, ownerID)
    BoneControlManager:ReleaseAllBones(ragdoll, ownerID)
end

EnhancedDeathAnimationExtended.Interface.GetBoneOwner           = function(ragdoll, boneName)
    return BoneControlManager:GetOwner(ragdoll, boneName)
end
EnhancedDeathAnimationExtended.Interface.StopPlayback           = function(ragdoll, reason)
    return PlaybackCoordinator:Stop(ragdoll, reason)
end
EnhancedDeathAnimationExtended.Interface.GetState               = function(ragdoll)
    return LifeCycleHandler:GetState(ragdoll)
end
EnhancedDeathAnimationExtended.Interface.GetHealth              = function(ragdoll)
    return HealthManager:Get(ragdoll)
end
EnhancedDeathAnimationExtended.Interface.DamageHealth           = function(ragdoll, damage)
    return HealthManager:Damage(ragdoll, damage)
end

-- 获取指定骨骼及其所有子骨骼的名称列表
EnhancedDeathAnimationExtended.Interface.GetBoneChain           = function(ragdoll, rootBoneName)
    return helper.GetBoneChain(ragdoll, rootBoneName)
end

-- PreRagdollInitialized：在布娃娃初始化前触发，参数为 (owner, ragdoll, initFunc)
-- 返回值：
--   true  : 外部接管初始化，模块不再自动调用 initFunc
--   其他  : 立即初始化

hook.Run("EDAE_Loaded")
