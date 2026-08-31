local MODULE_NAME = "Log"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local log = include("log.lua")

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = log
return log
