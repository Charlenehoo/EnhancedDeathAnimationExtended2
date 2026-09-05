-- lua\edae\config\constants.lua
local Constants                                         = {}
Constants.ADDON_NAME                                    = "EnhancedDeathAnimationExtended"
Constants.RAGDOLL_CLASS                                 = "prop_ragdoll"
Constants.Events                                        = {
    PostCreateRagdoll = "EDAE_PostCreateRagdoll",
    OnMortalityEvaluated = "EDAE_OnMortalityEvaluated",
    PreRagdollInitialized = "EDAE_PreRagdollInitialized",
    OnRagdollInitialized = "EDAE_RagdollInitialized",
    OnRagdollStateChange = "EDAE_OnRagdollStateChange",
    OnAnimationFinished = "EDAE_OnAnimationFinished",
    OnTwitchFinished = "EDAE_OnTwitchFinished",
    OnPlaybackStopped = "EDAE_OnPlaybackStopped",
    OnReviveRequested = "EDAE_OnReviveRequested",

    PostRagdollTakeDamage = "EDAE_PostRagdollTakeDamage",
}

Constants.PlaybackReasons                               = {
    CompletedNormally           = "CompletedNormally",
    Cancelled                   = "Cancelled",
    FailedByFall                = "FailedByFall",
    FailedByHitWall             = "FailedByHitWall",
    InterruptedBySelfRevive     = "InterruptedBySelfRevive",
    InterruptedByHealthDepleted = "InterruptedByHealthDepleted",
}

Constants.NETWORK_STRING                                = {}
Constants.NETWORK_STRING.Ragdoll                        = Constants.ADDON_NAME .. "_" .. "Ragdoll"
Constants.NETWORK_STRING.PlayerSpawn                    = Constants.ADDON_NAME .. "_" .. "PlayerSpawn"
Constants.NETWORK_STRING.PlayerRotateRagdoll            = Constants.ADDON_NAME .. "_" .. "PlayerRotateRagdoll"
Constants.NETWORK_STRING.PlayerSelfRevive_Start         = Constants.ADDON_NAME .. "_" .. "PlayerSelfRevive_Start"
Constants.NETWORK_STRING.PlayerSelfRevive_Cancel        = Constants.ADDON_NAME .. "_" .. "PlayerSelfRevive_Cancel"

Constants.EntityDataStore                               = {}
Constants.EntityDataStore.STORAGE_KEY                   = Constants.ADDON_NAME .. "_" .. "EntityData"
Constants.EntityDataStore.SUPER_OWNER                   = "ADMIN"
Constants.EntityDataStore.DEFAULT_OWNER                 = "anonymous"

Constants.RagdollManager                                = {}
Constants.RagdollManager.HEALTH_KEY                     = "Health"
Constants.RagdollManager.OWNER_KEY                      = "Owner"
Constants.RagdollManager.MAX_HEALTH                     = 100

Constants.LifeCycleHandler                              = {}
Constants.LifeCycleHandler.STATE_KEY                    = "State"
Constants.LifeCycleHandler.STATE_ENUM                   = {
    FALLING       = "falling",
    CRAWLING      = "crawling",
    WRITHING      = "writhing",
    TWITCHING     = "twitching",
    DEAD          = "dead",
    SELF_REVIVING = "self_reviving",
    GETTING_UP    = "getting_up",
}
Constants.LifeCycleHandler.CRAWL_CHANCE                 = 0.4
Constants.LifeCycleHandler.WRITHE_CHANCE                = 0.3
Constants.LifeCycleHandler.TWITCH_CHANCE                = 0.2

Constants.DamageContextManager                          = {}
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

Constants.ANIMATION_PLAYER                              = {}
Constants.ANIMATION_PLAYER.CONEXT_KEY                   = "Context"
Constants.ANIMATION_PLAYER.DEFAULT_ANIMATION_MODEL_NAME = "models/brutal_deaths/model_anim_modify.mdl"
Constants.ANIMATION_PLAYER.FALL_LIMIT                   = 5
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

Constants.ANIMATION_SELECTOR                            = {}
Constants.ANIMATION_SELECTOR.PRE_WAIT_TIME              = 0.6
Constants.ANIMATION_SELECTOR.STOP_LINEAR_THRESHOLD      = 100
Constants.ANIMATION_SELECTOR.STOP_ANGULAR_THRESHOLD     = 180
Constants.ANIMATION_SELECTOR.STOP_TIMEOUT               = 4.5
Constants.ANIMATION_SELECTOR.STOP_CHECK_INTERVAL        = 0.15
Constants.ANIMATION_SELECTOR.NATURAL_LEVEL              = 1
Constants.ANIMATION_SELECTOR.USE_RANDOM_CRAWL_WHITELIST = false
Constants.ANIMATION_SELECTOR.USE_FEMALE_ANIMATIONS      = true
Constants.ANIMATION_SELECTOR.TWITCH_INTENSITY           = 1.0
Constants.ANIMATION_SELECTOR.WRITHE_INTENSITY           = 1.0

Constants.PlayerCreatePropRagdoll                       = {}
Constants.PlayerCreatePropRagdoll.ORIGIN_OFFSET         = 98
Constants.PlayerCreatePropRagdoll.ANTI_CLIP_OFFSET      = 2
Constants.PlayerCreatePropRagdoll.ZOOM_PER_ROLL         = 8

Constants.BLOOD                                         = {
    ENABLED = true,
    MODE = "time",
    DECAL = "Blood",
    INTERVAL = 1.0,
    DISTANCE = 50,
}

Constants.VOICE                                         = {
    INTERVAL = 3,
    PRIORITY = 3,
    INTERRUPT = false,
    CONFIG = {
        [Constants.LifeCycleHandler.STATE_ENUM.CRAWLING] = {
            { category = "main",          key = "crithealth", priority = 3, interrupt = false },
            { category = "calloutsextra", key = "mandown",    priority = 3, interrupt = false, interval = 5 },
        },
        [Constants.LifeCycleHandler.STATE_ENUM.WRITHING] = {
            { category = "external", key = "bubble", priority = 3, interrupt = false },
        },
        [Constants.LifeCycleHandler.STATE_ENUM.TWITCHING] = {
            { category = "external", key = "overkill", priority = 3, interrupt = false },
        },
    },
}

Constants.DRAIN                                         = {
    [Constants.LifeCycleHandler.STATE_ENUM.CRAWLING] = {
        interval = 3.0,
        amount   = 5,
    },
    [Constants.LifeCycleHandler.STATE_ENUM.WRITHING] = {
        interval = 1.5,
        amount   = 8,
    },
    [Constants.LifeCycleHandler.STATE_ENUM.TWITCHING] = {
        interval = 1.5,
        amount   = 10,
    },
}

return Constants
