-- lua/autorun/edae_sh_constants.lua
local Constants = {}

Constants.ADDON_NAME = "EnhancedDeathAnimationExtended"
Constants.ANIMATION_PLAYER_DEFAULT_MODEL_NAME = "models/brutal_deaths/model_anim_modify.mdl"
Constants.ANIMATION_PLAYER_SHADOW_PARAMS_TEMPLATE = {
    secondstoarrive = 0.75,
    delta = nil,

    pos = vector_origin,
    angle = angle_zero,

    maxangular = 2000,
    maxangulardamp = 1000,

    maxspeed = 2000,
    maxspeeddamp = 1000,

    dampfactor = 0.5,
    teleportdistance = 0,
}

return Constants
