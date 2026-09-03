-- ./lua/death_face/config/eve.lua
return {
    -- ============================================================================
    -- 形态键配置（基于 Eve 模型实际 FlexName 列表）
    -- 濒死阶段（oscillate）：痛苦皱眉、半闭眼、张嘴哀嚎、嘴角下压
    -- 强直阶段（spike）：睁眼、眼球上翻、苦笑面容（牙关紧闭、口角后缩）
    -- 死后阶段（fade）：面部松弛，眼睛半闭，嘴巴微张
    -- ============================================================================
    flexConfig = {
        -- ===================================
        -- 眉毛 (Brows)
        -- ===================================
        brow_up = {
            oscillateBase = 0.10,
            oscillateAmp = 0.08,
            oscillateFreq = 1.8,
            fadeTarget = 0.05,
            spikeTarget = 0.05,
        },
        brow_up_left = {
            oscillateBase = 0.05,
            oscillateAmp = 0.05,
            oscillateFreq = 2.0,
            fadeTarget = 0.03,
            spikeTarget = 0.03,
        },
        brow_up_right = {
            oscillateBase = 0.12,
            oscillateAmp = 0.08,
            oscillateFreq = 1.8,
            fadeTarget = 0.05,
            spikeTarget = 0.05,
        },
        inner_Brow_up = {
            oscillateBase = 0.08,
            oscillateAmp = 0.06,
            oscillateFreq = 1.5,
            fadeTarget = 0.04,
            spikeTarget = 0.02,
        },
        inner_Brow_up_left = {
            oscillateBase = 0.04,
            oscillateAmp = 0.04,
            oscillateFreq = 1.7,
            fadeTarget = 0.02,
            spikeTarget = 0.01,
        },
        inner_Brow_up_right = {
            oscillateBase = 0.10,
            oscillateAmp = 0.06,
            oscillateFreq = 1.5,
            fadeTarget = 0.04,
            spikeTarget = 0.02,
        },
        outer_Brow_up = {
            oscillateBase = 0.06,
            oscillateAmp = 0.05,
            oscillateFreq = 1.6,
            fadeTarget = 0.03,
            spikeTarget = 0.01,
        },
        outer_Brow_up_left = {
            oscillateBase = 0.03,
            oscillateAmp = 0.03,
            oscillateFreq = 1.8,
            fadeTarget = 0.02,
            spikeTarget = 0.01,
        },
        outer_Brow_up_right = {
            oscillateBase = 0.08,
            oscillateAmp = 0.05,
            oscillateFreq = 1.6,
            fadeTarget = 0.03,
            spikeTarget = 0.01,
        },
        brow_furrow = {
            oscillateBase = 0.30,
            oscillateAmp = 0.15,
            oscillateFreq = 2.2,
            fadeTarget = 0.10,
            spikeTarget = 0.55,
        },
        brow_furrow_left = {
            oscillateBase = 0.15,
            oscillateAmp = 0.10,
            oscillateFreq = 2.4,
            fadeTarget = 0.08,
            spikeTarget = 0.40,
        },
        brow_furrow_right = {
            oscillateBase = 0.20,
            oscillateAmp = 0.12,
            oscillateFreq = 2.2,
            fadeTarget = 0.10,
            spikeTarget = 0.50,
        },
        brow_in = {
            oscillateBase = 0.20,
            oscillateAmp = 0.12,
            oscillateFreq = 2.0,
            fadeTarget = 0.08,
            spikeTarget = 0.45,
        },
        brow_in_left = {
            oscillateBase = 0.10,
            oscillateAmp = 0.08,
            oscillateFreq = 2.2,
            fadeTarget = 0.06,
            spikeTarget = 0.35,
        },
        brow_in_right = {
            oscillateBase = 0.15,
            oscillateAmp = 0.10,
            oscillateFreq = 2.0,
            fadeTarget = 0.08,
            spikeTarget = 0.40,
        },
        brow_down = {
            oscillateBase = 0.25,
            oscillateAmp = 0.12,
            oscillateFreq = 2.0,
            fadeTarget = 0.08,
            spikeTarget = 0.50,
        },

        -- ===================================
        -- 眼睑 (Eyelids)
        -- ===================================
        blink = {
            oscillateBase = 0.20,
            oscillateAmp = 0.15,
            oscillateFreq = 2.5,
            fadeTarget = 0.30,
            spikeTarget = 0.02,
        },
        squint_lower = {
            oscillateBase = 0.30,
            oscillateAmp = 0.10,
            oscillateFreq = 2.8,
            fadeTarget = 0.10,
            spikeTarget = 0.05,
        },
        upper_Lid_down_L = {
            oscillateBase = 0.45,
            oscillateAmp = 0.15,
            oscillateFreq = 2.2,
            fadeTarget = 0.20,
            spikeTarget = 0.0,
        },
        upper_Lid_down_R = {
            oscillateBase = 0.50,
            oscillateAmp = 0.18,
            oscillateFreq = 2.2,
            fadeTarget = 0.22,
            spikeTarget = 0.0,
        },
        lower_Lid_up_L = {
            oscillateBase = 0.35,
            oscillateAmp = 0.12,
            oscillateFreq = 2.5,
            fadeTarget = 0.10,
            spikeTarget = 0.0,
        },
        lower_Lid_up_R = {
            oscillateBase = 0.40,
            oscillateAmp = 0.14,
            oscillateFreq = 2.5,
            fadeTarget = 0.12,
            spikeTarget = 0.0,
        },
        upper_Lid_up_L = {
            oscillateBase = 0.0,
            oscillateAmp = 0.0,
            oscillateFreq = 0,
            fadeTarget = 0.0,
            spikeTarget = 0.40,
        },
        upper_Lid_up_R = {
            oscillateBase = 0.0,
            oscillateAmp = 0.0,
            oscillateFreq = 0,
            fadeTarget = 0.0,
            spikeTarget = 0.40,
        },
        lower_Lid_down_L = {
            oscillateBase = 0.0,
            oscillateAmp = 0.0,
            oscillateFreq = 0,
            fadeTarget = 0.0,
            spikeTarget = 0.25,
        },
        lower_Lid_down_R = {
            oscillateBase = 0.0,
            oscillateAmp = 0.0,
            oscillateFreq = 0,
            fadeTarget = 0.0,
            spikeTarget = 0.25,
        },

        -- ===================================
        -- 嘴巴 (Mouth)
        -- ===================================
        jaw_open = {
            oscillateBase = 0.45,
            oscillateAmp = 0.30,
            oscillateFreq = 2.2,
            oscillateDecay = false, -- 濒死期持续张嘴
            fadeTarget = 0.20,
            spikeTarget = 0.05,
        },
        jaw_thrust = {
            oscillateBase = 0.10,
            oscillateAmp = 0.08,
            oscillateFreq = 1.8,
            fadeTarget = 0.05,
            spikeTarget = 0.15,
        },
        whole_Mouth_down = {
            oscillateBase = 0.10,
            oscillateAmp = 0.05,
            oscillateFreq = 2.0,
            fadeTarget = 0.05,
            spikeTarget = 0.20,
        },
        whole_Mouth_up = {
            oscillateBase = 0.05,
            oscillateAmp = 0.03,
            oscillateFreq = 2.5,
            fadeTarget = 0.02,
            spikeTarget = 0.10,
        },
        lower_Lip_down = {
            oscillateBase = 0.30,
            oscillateAmp = 0.20,
            oscillateFreq = 1.8,
            fadeTarget = 0.10,
            spikeTarget = 0.0,
        },
        upper_Lip_up = {
            oscillateBase = 0.15,
            oscillateAmp = 0.10,
            oscillateFreq = 2.5,
            fadeTarget = 0.05,
            spikeTarget = 0.25,
        },
        upper_Lip_down = {
            oscillateBase = 0.10,
            oscillateAmp = 0.08,
            oscillateFreq = 2.2,
            fadeTarget = 0.04,
            spikeTarget = 0.20,
        },
        lip_Corner_down_left = {
            oscillateBase = 0.35,
            oscillateAmp = 0.18,
            oscillateFreq = 1.6,
            fadeTarget = 0.08,
            spikeTarget = 0.60,
        },
        lip_Corner_down_right = {
            oscillateBase = 0.40,
            oscillateAmp = 0.20,
            oscillateFreq = 1.5,
            fadeTarget = 0.10,
            spikeTarget = 0.65,
        },
        lip_stretch = {
            oscillateBase = 0.20,
            oscillateAmp = 0.15,
            oscillateFreq = 1.8,
            fadeTarget = 0.05,
            spikeTarget = 0.65,
        },
        lip_pucker = {
            oscillateBase = 0.10,
            oscillateAmp = 0.08,
            oscillateFreq = 2.5,
            fadeTarget = 0.0,
            spikeTarget = 0.50,
        },
        Sad = {
            oscillateBase = 0.25,
            oscillateAmp = 0.15,
            oscillateFreq = 1.5,
            fadeTarget = 0.05,
            spikeTarget = 0.55,
        },
        Sad_Smile = {
            oscillateBase = 0.15,
            oscillateAmp = 0.10,
            oscillateFreq = 1.8,
            fadeTarget = 0.02,
            spikeTarget = 0.40,
        },
        Sad_Smile_left = {
            oscillateBase = 0.08,
            oscillateAmp = 0.06,
            oscillateFreq = 2.0,
            fadeTarget = 0.02,
            spikeTarget = 0.30,
        },
        Sad_Smile_right = {
            oscillateBase = 0.12,
            oscillateAmp = 0.08,
            oscillateFreq = 1.8,
            fadeTarget = 0.02,
            spikeTarget = 0.35,
        },
        Smile = {
            oscillateBase = 0.0,
            oscillateAmp = 0.0,
            oscillateFreq = 0,
            fadeTarget = 0.0,
            spikeTarget = 0.25,
        },
        dimple = {
            oscillateBase = 0.0,
            oscillateAmp = 0.0,
            oscillateFreq = 0,
            fadeTarget = 0.0,
            spikeTarget = 0.20,
        },
        dimple_left = {
            oscillateBase = 0.0,
            oscillateAmp = 0.0,
            oscillateFreq = 0,
            fadeTarget = 0.0,
            spikeTarget = 0.15,
        },
        dimple_right = {
            oscillateBase = 0.0,
            oscillateAmp = 0.0,
            oscillateFreq = 0,
            fadeTarget = 0.0,
            spikeTarget = 0.18,
        },

        -- ===================================
        -- 鼻子 (Nose)
        -- ===================================
        nose_wrinkle = {
            oscillateBase = 0.20,
            oscillateAmp = 0.12,
            oscillateFreq = 2.0,
            fadeTarget = 0.05,
            spikeTarget = 0.40,
        },
        nose_Wrinkle_left = {
            oscillateBase = 0.10,
            oscillateAmp = 0.08,
            oscillateFreq = 2.2,
            fadeTarget = 0.04,
            spikeTarget = 0.30,
        },
        nose_Wrinkle_right = {
            oscillateBase = 0.15,
            oscillateAmp = 0.10,
            oscillateFreq = 2.0,
            fadeTarget = 0.05,
            spikeTarget = 0.35,
        },
        nose_Depressor = {
            oscillateBase = 0.10,
            oscillateAmp = 0.05,
            oscillateFreq = 1.8,
            fadeTarget = 0.03,
            spikeTarget = 0.20,
        },
        nostrill_flare = {
            oscillateBase = 0.10,
            oscillateAmp = 0.08,
            oscillateFreq = 2.5,
            fadeTarget = 0.02,
            spikeTarget = 0.25,
        },
    },

    -- ============================================================================
    -- 眼睛控制策略：Eye Target
    -- ============================================================================
    eyeControl = "eyetarget",
    eyeControlConfig = {}, -- eyetarget 策略无需额外配置

    -- ============================================================================
    -- 眼球运动配置（弧度）
    -- 濒死阶段小幅不规则转动；强直阶段眼球上翻；死后回正
    -- ============================================================================
    eyeConfigTemplate = {
        horiz = {
            oscillateBase = 0,
            oscillateAmp  = math.pi / 18, -- 水平摆动约 10°
            oscillateFreq = 1.0,
            fadeTarget    = 0,
            spikeTarget   = 0,
        },
        vert = {
            oscillateBase = 0,
            oscillateAmp  = math.pi / 36, -- 垂直摆动约 5°
            oscillateFreq = 1.5,
            fadeTarget    = 0,
            spikeTarget   = 0.30, -- 强直期上翻约 17°
        },
    },
}
