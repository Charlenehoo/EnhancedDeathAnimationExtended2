-- lua\edae\config\constants.lua
local Constants                                         = {}
Constants.ADDON_NAME                                    = "EnhancedDeathAnimationExtended"
Constants.RAGDOLL_CLASS                                 = "prop_ragdoll"
Constants.Events                                        = {
    OnRagdollStateChange = "OnRagdollStateChange",
    OnAnimationFinished = "OnAnimationFinished",
}

Constants.NETWORK_STRING                                = {}
Constants.NETWORK_STRING.Ragdoll                        = Constants.ADDON_NAME .. "_" .. "Ragdoll"
Constants.NETWORK_STRING.PlayerSpawn                    = Constants.ADDON_NAME .. "_" .. "PlayerSpawn"

Constants.EntityDataStore                               = {}
Constants.EntityDataStore.STORAGE_KEY                   = Constants.ADDON_NAME .. "_" .. "EntityData"
Constants.EntityDataStore.SUPER_OWNER                   = "ADMIN"
Constants.EntityDataStore.DEFAULT_OWNER                 = "anonymous"

Constants.RagdollManager                                = {}
Constants.RagdollManager.HEALTH_KEY                     = "Health"
Constants.RagdollManager.MAX_HEALTH                     = 100

Constants.LifeCycleHandler                              = {}
Constants.LifeCycleHandler.STATE_KEY                    = "State"
Constants.LifeCycleHandler.STATE_ENUM                   = {
    FALLING = "falling",
    CRAWLING = "crawling",
    WRITHING = "writhing",
    DEAD = "dead",
    REVIVING = "reviving",
}
Constants.LifeCycleHandler.CRAWL_CHANCE                 = 0.5
Constants.LifeCycleHandler.WRITHE_CHANCE                = 0.3
Constants.LifeCycleHandler.DEAD_AFTER_FALL_CHANCE       = 0.2

Constants.DamageContextManager                          = {}
Constants.DamageContextManager.FLAG_KEY                 = "Flag"
Constants.DamageContextManager.FLAG_ENUM                = {
    NECK = 1,
    SHOTGUN = 2,
    BACK = 4,
    PELVIS = 8,
    BURN = 16,
    BLAST = 32,
    MOVING = 64,
    CLUB = 128,
    BULLET = 256,
}
Constants.DamageContextManager.HIT_GROUP_KEY            = "HitGroup"
Constants.DamageContextManager.DMG_INFO_KEY             = "DmgInfo"

Constants.ANIMATION_PLAYER                              = {}
Constants.ANIMATION_PLAYER.CONEXT_KEY                   = "Context"
Constants.ANIMATION_PLAYER.DEFAULT_ANIMATION_MODEL_NAME = "models/brutal_deaths/model_anim_modify.mdl"
Constants.ANIMATION_PLAYER.MAX_ALLOWED_BONE_REMOVALS    = 5
Constants.ANIMATION_PLAYER.FALL_HEIGHT_THRESHOLD        = 20
Constants.ANIMATION_PLAYER.GROUND_TRACE_UP_OFFSET       = Vector(0, 0, 10)
Constants.ANIMATION_PLAYER.GROUND_TRACE_DOWN_OFFSET     = Vector(0, 0, -100)
Constants.ANIMATION_PLAYER.DEFAULT_TOTAL_LOOPS          = 1
Constants.ANIMATION_PLAYER_SHADOW_PARAMS_TEMPLATE       = {
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
Constants.ANIMATION_PLAYER.AM_DATUM_TO_POS_KEY          = "AmDatumToPos"

Constants.ANIMATION_SELECTOR                            = {}
Constants.ANIMATION_SELECTOR.PRE_WAIT_TIME              = 1.5  -- 播放前固定等待时间（秒）
Constants.ANIMATION_SELECTOR.STOP_LINEAR_THRESHOLD      = 10   -- 停止判定：线速度阈值（单位/秒）
Constants.ANIMATION_SELECTOR.STOP_ANGULAR_THRESHOLD     = 30   -- 停止判定：角速度阈值（度/秒，需根据实际调整）
Constants.ANIMATION_SELECTOR.STOP_TIMEOUT               = 4.5  -- 等待停止的超时时间（秒）
Constants.ANIMATION_SELECTOR.STOP_CHECK_INTERVAL        = 0.15 -- 停止检测轮询间隔（秒）
Constants.ANIMATION_SELECTOR.NATURAL_LEVEL              = 1
Constants.ANIMATION_SELECTOR.USE_RANDOM_CRAWL_WHITELIST = false

Constants.PlayerCreatePropRagdoll                       = {}
Constants.PlayerCreatePropRagdoll.ORIGIN_OFFSET         = 50
Constants.PlayerCreatePropRagdoll.ANTI_CLIP_OFFSET      = 5

return Constants
