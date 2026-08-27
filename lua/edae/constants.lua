-- lua/autorun/edae_sh_constants.lua
local Constants = {}

Constants.ADDON_NAME = "EnhancedDeathAnimationExtended"
Constants.ANIMATION_PLAYER_DEFAULT_MODEL_NAME = "models/brutal_deaths/model_anim_modify.mdl"
Constants.ANIMATION_PLAYER_SHADOW_PARAMS_TEMPLATE = {
    secondstoarrive = 0.03,
    delta = nil,

    pos = vector_origin,
    angle = angle_zero,

    maxangular = 400,
    maxangulardamp = 200,

    maxspeed = 400,
    maxspeeddamp = 300,

    dampfactor = 0.8,
    teleportdistance = 0,
}

return Constants
