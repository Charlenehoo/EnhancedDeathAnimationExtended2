local MODULE_NAME = "Log"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end


local log = include("edae/core/log/log.lua")
log.level = "debug"


_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = log
return log
