-- lua/autorun/edae_sh_constants.lua
local Constants = {}

Constants.ADDON_NAME = "EnhancedDeathAnimationExtended"
Constants.RAGDOLL_CONTEXT_KEY = Constants.ADDON_NAME .. "_" .. "Context"

Constants.ANIMATION_PLAYER = {}

Constants.ANIMATION_PLAYER.ANIMATION_MODEL = {}
Constants.ANIMATION_PLAYER.ANIMATION_MODEL.DEFAULT_MODEL_NAME = "models/brutal_deaths/model_anim_modify.mdl"

Constants.ANIMATION_PLAYER.MAX_ALLOWED_BONE_REMOVALS = 5
Constants.ANIMATION_PLAYER.FALL_HEIGHT_THRESHOLD = 20

Constants.ANIMATION_PLAYER.GROUND_TRACE_UP_OFFSET = Vector(0, 0, 10)
Constants.ANIMATION_PLAYER.GROUND_TRACE_DOWN_OFFSET = Vector(0, 0, -100)

Constants.ANIMATION_PLAYER.DEFAULT_TOTAL_LOOPS = 1

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
