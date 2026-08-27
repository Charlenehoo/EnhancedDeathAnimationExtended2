_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons.Constants then
    return _EnhancedDeathAnimationExtendedSingletons.Constants
end

local Constants = {}
Constants.ADDON_NAME = "EnhancedDeathAnimationExtended"

Constants.ANIMATION_PLAYER_DEFAULT_MODEL_NAME = "models/brutal_deaths/model_anim_modify.mdl"
Constants.ANIMATION_PLAYER_SHADOW_PARAMS_TEMPLATE = {
    secondstoarrive = 0.03,
    delta = 0.1,
    pos = vector_origin,
    angle = angle_zero,
    maxangular = 5000,
    maxangulardamp = 10000,
    maxspeed = 1000000,
    maxspeeddamp = 10000,
    dampfactor = 0.8,
    teleportdistance = 0,
}

_EnhancedDeathAnimationExtendedSingletons.Constants = Constants
return Constants
