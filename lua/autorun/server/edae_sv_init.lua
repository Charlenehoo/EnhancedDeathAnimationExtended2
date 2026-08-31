_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}

local Constants = include("edae/config/constants.lua")
for k, v in pairs(Constants.NETWORK_STRING) do
    util.AddNetworkString(v)
end

include("edae/rm/ragdoll_manager.lua")
