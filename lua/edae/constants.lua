-- lua/autorun/edae_sh_constants.lua
local Constants = {}

Constants.ADDON_NAME = "EnhancedDeathAnimationExtended"
Constants.ANIMATION_PLAYER_DEFAULT_ANIMATION_MODEL_NAME = "models/brutal_deaths/model_anim_modify.mdl"

Constants.RAGDOLL_CONTEXT_KEY = Constants.ADDON_NAME .. "_" .. "Context"

Constants.ANIMATION_PLAYER = {}
Constants.ANIMATION_PLAYER.GRAVITY_PROXY = {}
Constants.ANIMATION_PLAYER.GRAVITY_PROXY.MODEL_NAME = "models/editor/cube_small.mdl"
Constants.ANIMATION_PLAYER.GRAVITY_PROXY.RADIUS = tostring(32)

Constants.ANIMATION_PLAYER_SHADOW_PARAMS_TEMPLATE = {
    teleportdistance = 0,
    secondstoarrive = 0.01,
    delta = nil,
    dampfactor = nil,

    maxangular = 400,
    maxangulardamp = 200,

    maxspeed = 400,
    maxspeeddamp = 300,

    pos = vector_origin,
    angle = angle_zero,
}

return Constants
