-- ./lua/death_face/config/hitomi.lua
return {
    -- ============================================================================
    -- 形态键配置
    -- 濒死阶段（oscillate）：紧闭眼、川字眉、嘴巴不规律哀嚎
    -- 强直阶段（spike）：去大脑强直苦笑面容（牙关紧闭、口角后缩、眼球上翻）
    -- 死后阶段（fade）：松弛
    -- ============================================================================
    flexConfig = {
        -- ===================================
        -- 眉毛 (Brows)
        -- ===================================
        brow_inner_r_up = {
            oscillateBase = 0.12,
            oscillateAmp = 0.28,
            oscillateFreq = 1.8,
            fadeTarget = 0.05,
            spikeTarget = 0.0,
        },
        brow_inner_l_up = {
            oscillateBase = 0.02,
            oscillateAmp = 0.12,
            oscillateFreq = 2.3,
            fadeTarget = 0.05,
            spikeTarget = 0.0,
        },
        brow_inner_r_down = {
            oscillateBase = 0.32,
            oscillateAmp = 0.20,
            oscillateFreq = 2.2,
            fadeTarget = 0.05,
            spikeTarget = 0.45,
        },
        brow_inner_l_down = {
            oscillateBase = 0.06,
            oscillateAmp = 0.16,
            oscillateFreq = 2.8,
            fadeTarget = 0.05,
            spikeTarget = 0.40,
        },
        brow_middle_r_up = {
            oscillateBase = 0.04,
            oscillateAmp = 0.12,
            oscillateFreq = 1.6,
            fadeTarget = 0.0,
            spikeTarget = 0.0,
        },
        brow_middle_l_up = {
            oscillateBase = 0.00,
            oscillateAmp = 0.06,
            oscillateFreq = 2.3,
            fadeTarget = 0.0,
            spikeTarget = 0.0,
        },
        brow_middle_r_down = {
            oscillateBase = 0.25,
            oscillateAmp = 0.16,
            oscillateFreq = 2.4,
            fadeTarget = 0.02,
            spikeTarget = 0.45,
        },
        brow_middle_l_down = {
            oscillateBase = 0.05,
            oscillateAmp = 0.12,
            oscillateFreq = 2.6,
            fadeTarget = 0.02,
            spikeTarget = 0.40,
        },
        brow_outer_r_down = {
            oscillateBase = 0.30,
            oscillateAmp = 0.20,
            oscillateFreq = 2.4,
            fadeTarget = 0.05,
            spikeTarget = 0.45,
        },
        brow_outer_l_down = {
            oscillateBase = 0.06,
            oscillateAmp = 0.16,
            oscillateFreq = 2.8,
            fadeTarget = 0.05,
            spikeTarget = 0.40,
        },

        -- ===================================
        -- 眼睑 (Eyelids)
        -- ===================================
        eyelid_top_r_up = {
            oscillateBase = 0,
            oscillateAmp = 0,
            oscillateFreq = 0,
            fadeTarget = 0,
            spikeTarget = 0.45,
        },
        eyelid_top_l_up = {
            oscillateBase = 0,
            oscillateAmp = 0,
            oscillateFreq = 0,
            fadeTarget = 0,
            spikeTarget = 0.45,
        },
        eyelid_top_r_down = {
            oscillateBase = 0.46,
            oscillateAmp = 0.14,
            oscillateFreq = 2.5,
            fadeTarget = 0.25,
            spikeTarget = 0.0,
        },
        eyelid_top_l_down = {
            oscillateBase = 0.40,
            oscillateAmp = 0.18,
            oscillateFreq = 2.2,
            fadeTarget = 0.22,
            spikeTarget = 0.0,
        },
        eyelid_bottom_r_up = {
            oscillateBase = 0.38,
            oscillateAmp = 0.10,
            oscillateFreq = 2.8,
            fadeTarget = 0,
            spikeTarget = 0.0,
        },
        eyelid_bottom_l_up = {
            oscillateBase = 0.33,
            oscillateAmp = 0.14,
            oscillateFreq = 2.5,
            fadeTarget = 0,
            spikeTarget = 0.0,
        },
        eyelid_bottom_r_down = {
            oscillateBase = 0,
            oscillateAmp = 0,
            oscillateFreq = 0,
            fadeTarget = 0,
            spikeTarget = 0.30,
        },
        eyelid_bottom_l_down = {
            oscillateBase = 0,
            oscillateAmp = 0,
            oscillateFreq = 0,
            fadeTarget = 0,
            spikeTarget = 0.30,
        },
        Blink = {
            oscillateBase = 0.15,
            oscillateAmp = 0.10,
            oscillateFreq = 2.0,
            fadeTarget = 0.40,
            spikeTarget = 0.05,
        },

        -- ===================================
        -- 嘴唇/嘴巴 (Lips / Mouth)
        -- ===================================
        lip_top_middle_up = {
            oscillateBase = 0.08,
            oscillateAmp = 0.03,
            oscillateFreq = 3.5,
            fadeTarget = 0,
            spikeTarget = 0.30,
        },
        lip_top_r_up = {
            oscillateBase = 0.20,
            oscillateAmp = 0.12,
            oscillateFreq = 3.0,
            fadeTarget = 0,
            spikeTarget = 0.35,
        },
        lip_top_l_up = {
            oscillateBase = 0.04,
            oscillateAmp = 0.025,
            oscillateFreq = 4.0,
            fadeTarget = 0,
            spikeTarget = 0.30,
        },
        lip_bottom_middle_up = {
            oscillateBase = 0.06,
            oscillateAmp = 0.05,
            oscillateFreq = 2.5,
            fadeTarget = 0,
            spikeTarget = 0.50,
        },
        lip_bottom_r_up = {
            oscillateBase = 0.04,
            oscillateAmp = 0.03,
            oscillateFreq = 2.8,
            fadeTarget = 0,
            spikeTarget = 0.30,
        },
        lip_bottom_l_up = {
            oscillateBase = 0.02,
            oscillateAmp = 0.015,
            oscillateFreq = 3.5,
            fadeTarget = 0,
            spikeTarget = 0.25,
        },
        lip_bottom_middle_down = {
            oscillateBase = 0.25,
            oscillateAmp = 0.20,
            oscillateFreq = 1.3,
            fadeTarget = 0.10,
            spikeTarget = 0.05,
        },
        lip_bottom_r_down = {
            oscillateBase = 0.30,
            oscillateAmp = 0.25,
            oscillateFreq = 1.4,
            fadeTarget = 0.05,
            spikeTarget = 0.0,
        },
        lip_bottom_l_down = {
            oscillateBase = 0.08,
            oscillateAmp = 0.10,
            oscillateFreq = 1.8,
            fadeTarget = 0.05,
            spikeTarget = 0.0,
        },
        lip_r_smile = {
            oscillateBase = 0.035,
            oscillateAmp = 0.025,
            oscillateFreq = 3.0,
            fadeTarget = 0,
            spikeTarget = 0.05,
        },
        lip_l_smile = {
            oscillateBase = 0.005,
            oscillateAmp = 0.008,
            oscillateFreq = 4.0,
            fadeTarget = 0,
            spikeTarget = 0.05,
        },
        lip_r_sad = {
            oscillateBase = 0.30,
            oscillateAmp = 0.22,
            oscillateFreq = 1.5,
            fadeTarget = 0.08,
            spikeTarget = 0.60,
        },
        lip_l_sad = {
            oscillateBase = 0.08,
            oscillateAmp = 0.06,
            oscillateFreq = 2.0,
            fadeTarget = 0.06,
            spikeTarget = 0.50,
        },
        lip_r_stretcher = {
            oscillateBase = 0.22,
            oscillateAmp = 0.15,
            oscillateFreq = 1.8,
            fadeTarget = 0,
            spikeTarget = 0.70,
        },
        lip_l_stretcher = {
            oscillateBase = 0.06,
            oscillateAmp = 0.05,
            oscillateFreq = 2.2,
            fadeTarget = 0,
            spikeTarget = 0.60,
        },
        lip_r_pucker = {
            oscillateBase = 0.12,
            oscillateAmp = 0.07,
            oscillateFreq = 2.5,
            fadeTarget = 0,
            spikeTarget = 0.70,
        },
        lip_l_pucker = {
            oscillateBase = 0.03,
            oscillateAmp = 0.02,
            oscillateFreq = 3.5,
            fadeTarget = 0,
            spikeTarget = 0.65,
        },
        mouth_open = {
            oscillateBase = 0.63,
            oscillateAmp = 0.32,
            oscillateFreq = 2.4,
            oscillateBeatDelta = 0.8,
            oscillateDecay = false,
            fadeTarget = 0.25,
            spikeTarget = 0.05,
        },
    },

    -- ============================================================================
    -- 眼球运动配置
    -- 这里使用 flexeye 模式，通过 eyes_updown 和 eyes_rightleft 控制眼球方向
    -- 注意：当前 SetEyeDirection_FlexEye 只支持上下（ver），若要水平控制需要扩展该函数
    -- ============================================================================
    eyeControl = "flexeye",
    eyeControlConfig = {
        upL   = "eyes_updown",
        downL = "eyes_updown",
        upR   = "eyes_updown",
        downR = "eyes_updown",
        -- 水平方向暂未在 SetEyeDirection_FlexEye 中实现
    },
    eyeConfigTemplate = {
        horiz = {
            oscillateBase = 0,
            oscillateAmp  = math.pi / 18,
            oscillateFreq = 1.2,
            fadeTarget    = 0,
            spikeTarget   = 0, -- 水平正视
        },
        vert = {
            oscillateBase = 0,
            oscillateAmp  = math.pi / 36,
            oscillateFreq = 1.8,
            fadeTarget    = math.pi / 6,
            spikeTarget   = 0.30,
        },
    },
}
