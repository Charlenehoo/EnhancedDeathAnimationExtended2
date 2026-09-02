-- lua\edae\config\constants.lua
local Constants                                         = {}
Constants.ADDON_NAME                                    = "EnhancedDeathAnimationExtended"
Constants.RAGDOLL_CLASS                                 = "prop_ragdoll"
Constants.Events                                        = {
    OnRagdollStateChange = "EDAE_OnRagdollStateChange",
    OnAnimationFinished = "EDAE_OnAnimationFinished",
    OnRagdollInitialized = "EDAE_RagdollInitialized",
    OnRagdollHealthChanged = "EDAE_OnRagdollHealthChanged"
}

Constants.NETWORK_STRING                                = {}
Constants.NETWORK_STRING.Ragdoll                        = Constants.ADDON_NAME .. "_" .. "Ragdoll"
Constants.NETWORK_STRING.PlayerSpawn                    = Constants.ADDON_NAME .. "_" .. "PlayerSpawn"
Constants.NETWORK_STRING.PlayerRotateRagdoll            = Constants.ADDON_NAME .. "_" .. "PlayerRotateRagdoll"

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
    TWITCHING = "twitching",
    DEAD = "dead",
    REVIVING = "reviving",
}
Constants.LifeCycleHandler.CRAWL_CHANCE                 = 0.4
Constants.LifeCycleHandler.WRITHE_CHANCE                = 0.3
Constants.LifeCycleHandler.TWITCH_CHANCE                = 0.2
-- Constants.LifeCycleHandler.DEAD_AFTER_FALL_CHANCE       = 0.1

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
Constants.DamageContextManager.FLAG_KEY                 = "Flag"
Constants.DamageContextManager.HIT_GROUP_KEY            = "HitGroup"
Constants.DamageContextManager.DMG_INFO_KEY             = "DmgInfo"

Constants.ANIMATION_PLAYER                              = {}
Constants.ANIMATION_PLAYER.CONEXT_KEY                   = "Context"
-- Constants.ANIMATION_PLAYER.AM_DATUM_TO_POS_KEY          = "AmDatumToPos"
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
Constants.ANIMATION_SELECTOR.PRE_WAIT_TIME              = 1.5  -- 播放前固定等待时间（秒）
Constants.ANIMATION_SELECTOR.STOP_LINEAR_THRESHOLD      = 10   -- 停止判定：线速度阈值（单位/秒）
Constants.ANIMATION_SELECTOR.STOP_ANGULAR_THRESHOLD     = 30   -- 停止判定：角速度阈值（度/秒，需根据实际调整）
Constants.ANIMATION_SELECTOR.STOP_TIMEOUT               = 4.5  -- 等待停止的超时时间（秒）
Constants.ANIMATION_SELECTOR.STOP_CHECK_INTERVAL        = 0.15 -- 停止检测轮询间隔（秒）
Constants.ANIMATION_SELECTOR.NATURAL_LEVEL              = 1
Constants.ANIMATION_SELECTOR.USE_RANDOM_CRAWL_WHITELIST = false
Constants.ANIMATION_SELECTOR.USE_FEMALE_ANIMATIONS      = true
Constants.ANIMATION_SELECTOR.TWITCH_INTENSITY           = 1.0
Constants.ANIMATION_SELECTOR.WRITHE_INTENSITY           = 1.0

Constants.PlayerCreatePropRagdoll                       = {}
Constants.PlayerCreatePropRagdoll.ORIGIN_OFFSET         = 50
Constants.PlayerCreatePropRagdoll.ANTI_CLIP_OFFSET      = 5

-- ==============================
-- 血迹效果（Blood Decal）
-- ==============================
Constants.BLOOD                                         = {
    -- 是否启用血迹效果
    ENABLED = true,

    -- 血迹生成模式："time" 按固定时间间隔；"distance" 按移动距离间隔
    MODE = "time",

    -- 血迹贴花名称（需确保游戏资源中存在）
    DECAL = "Blood",

    -- 时间模式下的间隔（秒）
    INTERVAL = 1.0,

    -- 距离模式下的最小移动距离（单位）
    DISTANCE = 50,
}

-- ==============================
-- 语音效果（Voice Effect）
-- ==============================
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


Constants.RagdollManager.HEALTH_DRAIN_INTERVAL = 1.5 -- 每隔多少秒扣一次血
Constants.RagdollManager.HEALTH_DRAIN_AMOUNT   = 10  -- 每次扣减的血量


return Constants
