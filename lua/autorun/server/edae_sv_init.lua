include("edae/rm/ragdoll_manager.lua")

local Constants = include("edae/config/constants.lua")
for k, v in pairs(Constants.NETWORK_STRING) do
    util.AddNetworkString(v)
end
local AnimationPlayer     = include("edae/ap/animation_player.lua")
local PlaybackCoordinator = include("edae/rm/playback_coordinator.lua")
local LifeCycleHandler    = include("edae/life_cycle_handler.lua")
local HealthManager       = include("edae/rm/health_manager.lua")


EnhancedDeathAnimationExtended                        = EnhancedDeathAnimationExtended or {}

EnhancedDeathAnimationExtended.Events                 = Constants.Events
EnhancedDeathAnimationExtended.PlaybackReasons        = Constants.PlaybackReasons

EnhancedDeathAnimationExtended.Interface              = {}
EnhancedDeathAnimationExtended.Interface.SetBoneSkip  = function(ragdoll, boneName, skip, recursive)
    return AnimationPlayer:SetBoneSkip(ragdoll, boneName, skip, recursive)
end
EnhancedDeathAnimationExtended.Interface.StopPlayback = function(ragdoll, reason)
    return PlaybackCoordinator:Stop(ragdoll, reason)
end
EnhancedDeathAnimationExtended.Interface.GetState     = function(ragdoll)
    return LifeCycleHandler:GetState(ragdoll)
end
EnhancedDeathAnimationExtended.Interface.GetHealth    = function(ragdoll)
    return HealthManager:Get(ragdoll)
end
EnhancedDeathAnimationExtended.Interface.DamageHealth = function(ragdoll, damage)
    return HealthManager:Damage(ragdoll, damage)
end

-- PreRagdollInitialized：在布娃娃初始化前触发，参数为 (owner, ragdoll, initFunc)
-- 返回值：
--   true  : 外部接管初始化，模块不再自动调用 initFunc
--   其他  : 立即初始化

hook.Run("EDAE_Loaded")
