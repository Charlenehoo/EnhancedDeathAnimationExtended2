-- lua/autorun/edae_sh_constants.lua
_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}

local Constants = {}

Constants.ADDON_NAME = "EnhancedDeathAnimationExtended"
Constants.ANIMATION_PLAYER_DEFAULT_MODEL_NAME = "models/brutal_deaths/model_anim_modify.mdl"
Constants.ANIMATION_PLAYER_SHADOW_PARAMS_TEMPLATE = {
    secondstoarrive = 0.03,
    delta = 0.1,
    pos = vector_origin,
    angle = angle_zero,
    maxangular = 5,
    maxangulardamp = 10,
    maxspeed = 1000,
    maxspeeddamp = 10,
    dampfactor = 0.8,
    teleportdistance = 0,
}

_EnhancedDeathAnimationExtendedSingletons.Constants = Constants

return Constants
