-- lua/autorun/edae_sh_constants.lua
local Constants = {}

Constants.ADDON_NAME = "EnhancedDeathAnimationExtended"
Constants.RAGDOLL_CLASS = "prop_ragdoll"

Constants.EntityDataStore = {}
Constants.EntityDataStore.STORAGE_KEY = Constants.ADDON_NAME .. "_" .. "EntityData"
Constants.EntityDataStore.SUPER_OWNER = "ADMIN"
Constants.EntityDataStore.DEFAULT_OWNER = "anonymous"

Constants.RAGDOLL_MANAGER = {}
Constants.RAGDOLL_MANAGER.HEALTH_KEY = "Health"
Constants.RAGDOLL_MANAGER.MAX_HEALTH = 100

Constants.RAGDOLL_MANAGER.STATE_KEY = "State"
Constants.RAGDOLL_MANAGER.STATE_ENUM = {
    FALLING = "falling"
}

Constants.PLAYER_NPC_CONTEXT_KEY = Constants.ADDON_NAME .. "_" .. "Player_NPC_Context"
Constants.RAGDOLL_CONTEXT_KEY = Constants.ADDON_NAME .. "_" .. "Ragdoll_Context"



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
