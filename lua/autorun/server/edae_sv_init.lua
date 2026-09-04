include("edae/rm/ragdoll_manager.lua")

local Constants = include("edae/config/constants.lua")
for k, v in pairs(Constants.NETWORK_STRING) do
    util.AddNetworkString(v)
end
local PlaybackCoordinator = include("edae/rm/playback_coordinator.lua")
local LifeCycleHandler    = include("edae/life_cycle_handler.lua")
local HealthManager       = include("edae/rm/health_manager.lua")


local EnhancedDeathAnimationExtended           = {}

EnhancedDeathAnimationExtended.Events          = Constants.Events
EnhancedDeathAnimationExtended.PlaybackReasons = Constants.PlaybackReasons
EnhancedDeathAnimationExtended.STATES          = Constants.LifeCycleHandler.STATE_ENUM
EnhancedDeathAnimationExtended.Interface       = {
    SetBoneSkip = function(ragdoll, boneName, skip)
        return PlaybackCoordinator:SetBoneSkip(ragdoll, boneName, skip)
    end,
    StopPlayback = function(ragdoll, reason)
        return PlaybackCoordinator:Stop(ragdoll, reason)
    end,
    GetState = function(ragdoll)
        return LifeCycleHandler:GetState(ragdoll)
    end,
    GetHealth = function(ragdoll)
        return HealthManager:Get(ragdoll)
    end,
    DamageHealth = function(ragdoll, damage)
        return HealthManager:Damage(ragdoll, damage)
    end,
    SetHealth = function(ragdoll, health)
        return HealthManager:Set(ragdoll, health)
    end,
    ResetHealth = function(ragdoll)
        return HealthManager:Reset(ragdoll)
    end,
    SetGlobalHealthOverride = function(handler)
        HealthManager:SetGlobalOverride(handler)
    end,
    ClearGlobalHealthOverride = function()
        HealthManager:ClearGlobalOverride()
    end,
    SetEntityHealthOverride = function(ragdoll, handler)
        return HealthManager:SetEntityOverride(ragdoll, handler)
    end,
    ClearEntityHealthOverride = function(ragdoll)
        return HealthManager:ClearEntityOverride(ragdoll)
    end,
}

hook.Run("EDAE_Loaded", EnhancedDeathAnimationExtended)
