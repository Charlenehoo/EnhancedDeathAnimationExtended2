-- lua/autorun/edae_sh_constants.lua
local Constants = {}

Constants.ADDON_NAME = "EnhancedDeathAnimationExtended"
Constants.RAGDOLL_CONTEXT_KEY = Constants.ADDON_NAME .. "_" .. "Context"

Constants.ANIMATION_PLAYER = {}

Constants.ANIMATION_PLAYER.ANIMATION_MODEL = {}
Constants.ANIMATION_PLAYER.ANIMATION_MODEL.DEFAULT_MODEL_NAME = "models/brutal_deaths/model_anim_modify.mdl"
Constants.ANIMATION_PLAYER.ANIMATION_MODEL.REF_BONE_NAME = "ValveBiped.Bip01_Pelvis"

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
