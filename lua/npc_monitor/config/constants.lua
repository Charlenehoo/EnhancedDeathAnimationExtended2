-- npc_monitor/config/constants.lua
-- 全局常量配置

local M                 = {}

-- ==============================
-- 基本插件配置
-- ==============================

-- 插件名称，用于生成唯一的 Hook 标识符
M.PLUGIN_NAME           = "NPC_MONITOR"

-- 是否启用热修复友好的 Hook 标识符（若为 true，Hook 标识符可预测；false 则添加随机后缀防止冲突）
M.HOT_FIX_FRIENDLY      = false

-- 是否仅对玩家生成的 ragdoll 生效（true 则忽略非玩家实体）
M.PLAYER_ONLY           = true

-- ==============================
-- 实体关联与感知
-- ==============================

-- ragdoll dummy 实体的类名，用于创建和识别目标
M.RAGADOLL_DUMMY_CLASS  = "ragdoll_dummy_target"

-- NPC 的最大视距（用于增强 NPC 感知能力，单位与游戏世界一致）
M.NPC_MAX_LOOK_DISTANCE = 6000

-- ==============================
-- 声音提示（EmitHint）参数
-- ==============================

-- 声音提示持续时间（秒），用于 EmitHint 的 duration 参数
M.SOUND_HINT_LAST       = 1.5

-- 声音提示半径（单位），用于 EmitHint 的 volume 参数
M.SOUND_HINT_RADIUS     = 500

-- ==============================
-- RAGDOLL_DUMMY 实体配置
-- ==============================

M.RAGDOLL_DUMMY         = {
    -- --------------------------
    -- 模型与外观
    -- --------------------------
    -- 使用的代理模型（不可见的小立方体）
    PROXY_MODEL                   = "models/editor/cube_small.mdl",

    -- 模型缩放比例（1/32，使立方体极小）
    SCALE                         = 0.03125,

    -- 执行者与目标点之间的偏移距离（用于将 dummy 放置在视线前方）
    OFFSET                        = 5,

    -- --------------------------
    -- 关系与优先级
    -- --------------------------
    -- 设置实体关系时使用的最大优先级（D_HT 或 D_NU）
    RELATIONSHIP_MAX_PRIORITY     = 99,

    -- --------------------------
    -- 执行者（Executioner）搜索与验证
    -- --------------------------
    -- 初始化后延迟首次搜索的时间（秒）
    MAX_INIT_DURATION             = 0.3,

    -- 搜索潜在执行者的间隔（秒）
    EXECUTIONER_SEARCH_INTERVAL   = 0.3,

    -- 验证当前执行者是否仍有效的间隔（秒）
    EXECUTIONER_VALIDATE_INTERVAL = 0.6,

    -- 验证连续失败多少次后取消当前执行者并降级位置策略
    EXECUTIONER_MAX_FAIL_COUNT    = 2,

    -- 执行者被指派后的最长有效时间（秒），超时则取消
    EXECUTIONER_TIMEOUT           = 3.0,

    -- 根据不同 ragdoll 状态设置的执行者搜索半径（单位），nil 表示不搜索
    STATE_TO_SEARCH_RADIUS        = {
        init     = nil,                     -- 初始状态，不搜索
        falling  = 315,                     -- 下落状态，搜索半径 315
        writhing = 160,                     -- 挣扎状态，搜索半径 160
        crawling = 630,                     -- 爬行状态，搜索半径 630
        reviving = M.NPC_MAX_LOOK_DISTANCE, -- 复活状态，使用最大视距
        dead     = nil,                     -- 死亡状态，不搜索
    },

    -- --------------------------
    -- 位置提取与重定位
    -- --------------------------
    -- 定期重定位 dummy 的间隔（秒）
    REPOSITION_INTERVAL           = 1.5,

    -- 重定位时随机水平半径的最小值（单位）
    REPOSITION_RADIUS_MIN         = 63,

    -- 重定位时随机水平半径的最大值（单位）
    REPOSITION_RADIUS_MAX         = 80,

    -- 定期重置位置策略到最高优先级（眼睛）的间隔（秒）
    POSITION_RESET_INTERVAL       = 15.0,

    -- --------------------------
    -- 死亡检测与移除
    -- --------------------------
    -- 确认死亡后延迟移除 dummy 的时间（秒）
    DEAD_REMOVE_DELAY             = 9.0,

    -- 静止检查的间隔（秒），用于速度死亡判定
    STATIC_CHECK_INTERVAL         = 1,

    -- 连续静止检查次数达到该值则判定为死亡
    STATIC_CONSECUTIVE_COUNT      = 2,

    -- 角速度平方阈值（约 30°/s 对应 0.25，约 57°/s 对应 1.0）
    STATIC_ANG_VEL_SQR_THRESHOLD  = 1,

    -- 线速度平方阈值（约 5 unit/s 对应 25）
    STATIC_LIN_VEL_SQR_THRESHOLD  = 25,
}

return M
