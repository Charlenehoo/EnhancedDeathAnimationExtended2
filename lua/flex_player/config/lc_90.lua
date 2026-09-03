-- ./lua/death_face/config/lc_90.lua
return {
    -- ============================================================================
    -- 形态键配置（仅包含面条代码中直接涉及的键，眼球方向键已移至 eyeControlConfig）
    -- 濒死阶段（oscillate）：痛苦紧闭眼、张口呼吸、嘴角下压、皱眉
    -- 强直阶段（spike）：去大脑强直苦笑面容（牙关紧闭、眼球上翻、皱眉加深）
    -- 死后阶段（fade）：松弛自然，闭眼程度略增，嘴巴接近闭合
    -- ============================================================================
    flexConfig = {
        -- 闭眼（原始 death_expression: t * duaration，终值 t ≈ 0.80）
        -- 终末期提升至 0.25，半闭眼更明显
        blink = {
            oscillateBase = 0.30,
            oscillateAmp = 0.20,
            oscillateFreq = 2.0,
            fadeTarget = 0.60,
            spikeTarget = 0.20, -- 强直期睁眼
        },

        -- 张嘴（原始 death_expression: ah * 0.9，终值 ah ≈ 0.14）
        -- 终末期保持极低（0.03），嘴巴接近闭合
        mouth_surprised = {
            oscillateBase = 0.30,
            oscillateAmp = 0.20,
            oscillateFreq = 1.8,
            oscillateDecay = false,
            fadeTarget = 0.03,
            spikeTarget = 0.02, -- 强直期牙关紧闭
        },

        -- 嘴角下压（原始 death_expression: sa，终值 sa ≈ 0.45）
        -- 终末期降低至 0.20，保留轻微悲伤感
        mouth_sad = {
            oscillateBase = 0.30,
            oscillateAmp = 0.20,
            oscillateFreq = 1.6,
            fadeTarget = 0.20,
            spikeTarget = 0.60, -- 强直期苦笑嘴角下压加强
        },

        -- 眉毛下压/悲伤（原始 death_expression: 固定 0.7）
        -- 终末期降低至 0.35，表情放松
        brows_sad = {
            oscillateBase = 0.50,
            oscillateAmp = 0.20,
            oscillateFreq = 2.0,
            fadeTarget = 0.35,
            spikeTarget = 0.70, -- 强直期皱眉加深
        },
    },

    -- ============================================================================
    -- 眼球运动控制：使用形态键（flexeye 模式）
    -- 上下方向分别通过 eyes_look_up 和 eyes_look_down 实现，左右眼共用
    -- ============================================================================
    eyeControl = "flexeye",
    eyeControlConfig = {
        upL   = "eyes_look_up",
        downL = "eyes_look_down",
        upR   = "eyes_look_up",
        downR = "eyes_look_down",
    },

    -- ============================================================================
    -- 眼球运动参数（ver 弧度值将被 SetEyeDirection_FlexEye 乘以 0.5 后设置权重）
    -- 终末期上翻约 17° → 权重 ≈ 0.15
    -- ============================================================================
    eyeConfigTemplate = {
        horiz = {
            oscillateBase = 0,
            oscillateAmp  = math.pi / 18, -- 水平游移（flexeye 模式下暂不生效）
            oscillateFreq = 1.2,
            fadeTarget    = 0,
            spikeTarget   = 0,
        },
        vert = {
            oscillateBase = 0,
            oscillateAmp  = math.pi / 36, -- 垂直游移
            oscillateFreq = 1.8,
            fadeTarget    = math.pi / 12,
            spikeTarget   = math.pi / 6,
        },
    },
}
