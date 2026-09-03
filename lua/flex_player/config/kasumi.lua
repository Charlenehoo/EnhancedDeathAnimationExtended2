return {

    -- ============================================================================
    -- 形态键配置
    -- 濒死阶段（oscillate）：紧闭眼、川字眉、嘴巴不规律哀嚎
    -- 强直阶段（spike）：去大脑强直苦笑面容（牙关紧闭、口角后缩、眼球上翻）
    -- 死后阶段（fade）：松弛
    -- ============================================================================
    flexConfig = {
        -- ===================================
        -- 眉毛 (Brows) - 濒死期川字眉，不对称加剧，振幅放大
        -- ===================================
        browinnerrup = { -- browinnerrup = brow inner r up = 眉毛 内侧 右 向上（AU1 内眉上抬）
            oscillateBase = 0.12,
            oscillateAmp = 0.28,
            oscillateFreq = 1.8,
            fadeTarget = 0.05,
            spikeTarget = 0.0, -- 强直时额肌不收缩
        },
        browinnerlup = {       -- browinnerlup = brow inner l up = 眉毛 内侧 左 向上（AU1 内眉上抬）
            oscillateBase = 0.02,
            oscillateAmp = 0.12,
            oscillateFreq = 2.3, -- 原5.8
            fadeTarget = 0.05,
            spikeTarget = 0.0,
        },
        browinnerrdown = { -- browinnerrdown = brow inner r down = 眉毛 内侧 右 向下（AU4 眉毛下压）
            oscillateBase = 0.32,
            oscillateAmp = 0.20,
            oscillateFreq = 2.2, -- 原3.8
            fadeTarget = 0.05,
            spikeTarget = 0.45,  -- 原0.35，增强皱眉
        },
        browinnerldown = {       -- browinnerldown = brow inner l down = 眉毛 内侧 左 向下（AU4 眉毛下压）
            oscillateBase = 0.06,
            oscillateAmp = 0.16,
            oscillateFreq = 2.8, -- 原6.5
            fadeTarget = 0.05,
            spikeTarget = 0.40,  -- 原0.30
        },
        browmiddlerup = {        -- browmiddlerup = brow middle r up = 眉毛 中段 右 向上（AU1+AU2 相关）
            oscillateBase = 0.04,
            oscillateAmp = 0.12,
            oscillateFreq = 1.6,
            fadeTarget = 0.0,
            spikeTarget = 0.0,
        },
        browmiddlelup = { -- browmiddlelup = brow middle l up = 眉毛 中段 左 向上（AU1+AU2 相关）
            oscillateBase = 0.00,
            oscillateAmp = 0.06,
            oscillateFreq = 2.3, -- 原5.5
            fadeTarget = 0.0,
            spikeTarget = 0.0,
        },
        browmiddlerdown = { -- browmiddlerdown = brow middle r down = 眉毛 中段 右 向下（AU4 相关）
            oscillateBase = 0.25,
            oscillateAmp = 0.16,
            oscillateFreq = 2.4, -- 原3.5
            fadeTarget = 0.02,
            spikeTarget = 0.45,  -- 原0.35
        },
        browmiddleldown = {      -- browmiddleldown = brow middle l down = 眉毛 中段 左 向下（AU4 相关）
            oscillateBase = 0.05,
            oscillateAmp = 0.12,
            oscillateFreq = 2.6, -- 原6.0
            fadeTarget = 0.02,
            spikeTarget = 0.40,  -- 原0.30
        },
        browouterrdown = {       -- browouterrdown = brow outer r down = 眉毛 外侧 右 向下（AU4 相关）
            oscillateBase = 0.30,
            oscillateAmp = 0.20,
            oscillateFreq = 2.4, -- 原3.5
            fadeTarget = 0.05,
            spikeTarget = 0.45,  -- 原0.40
        },
        browouterldown = {       -- browouterldown = brow outer l down = 眉毛 外侧 左 向下（AU4 相关）
            oscillateBase = 0.06,
            oscillateAmp = 0.16,
            oscillateFreq = 2.8, -- 原6.3
            fadeTarget = 0.05,
            spikeTarget = 0.40,  -- 原0.35
        },

        -- ===================================
        -- 眼睑 (Eyelids) - 濒死期痛苦紧闭眼，强直期睁大凝视
        -- ===================================
        eyelidtoprup = { -- eyelidtoprup = eyelid top r up = 上眼睑 右 向上（AU5 上睑上提）
            oscillateBase = 0,
            oscillateAmp = 0,
            oscillateFreq = 0,
            fadeTarget = 0,
            spikeTarget = 0.45, -- 保持不变，强直睁眼
        },
        eyelidtoplup = {        -- eyelidtoplup = eyelid top l up = 上眼睑 左 向上（AU5 上睑上提）
            oscillateBase = 0,
            oscillateAmp = 0,
            oscillateFreq = 0,
            fadeTarget = 0,
            spikeTarget = 0.45,
        },
        eyelidtoprdown = { -- eyelidtoprdown = eyelid top r down = 上眼睑 右 向下（AU43/45 上睑下降）
            oscillateBase = 0.46,
            oscillateAmp = 0.14,
            oscillateFreq = 2.5, -- 原9.2
            fadeTarget = 0.25,
            spikeTarget = 0.0,   -- 强直不闭眼
        },
        eyelidtopldown = {       -- eyelidtopldown = eyelid top l down = 上眼睑 左 向下（AU43/45 上睑下降）
            oscillateBase = 0.40,
            oscillateAmp = 0.18,
            oscillateFreq = 2.2, -- 原7.5
            fadeTarget = 0.22,
            spikeTarget = 0.0,
        },
        eyelidbottomrup = { -- eyelidbottomrup = eyelid bottom r up = 下眼睑 右 向上（AU7 下睑收紧）
            oscillateBase = 0.38,
            oscillateAmp = 0.10,
            oscillateFreq = 2.8, -- 原8.5
            fadeTarget = 0,
            spikeTarget = 0.0,
        },
        eyelidbottomlup = { -- eyelidbottomlup = eyelid bottom l up = 下眼睑 左 向上（AU7 下睑收紧）
            oscillateBase = 0.33,
            oscillateAmp = 0.14,
            oscillateFreq = 2.5, -- 原7.2
            fadeTarget = 0,
            spikeTarget = 0.0,
        },
        eyelidbottomrdown = { -- eyelidbottomrdown = eyelid bottom r down = 下眼睑 右 向下（下睑下拉）
            oscillateBase = 0,
            oscillateAmp = 0,
            oscillateFreq = 0,
            fadeTarget = 0,
            spikeTarget = 0.30, -- 保持不变，睁大眼
        },
        eyelidbottomldown = {   -- eyelidbottomldown = eyelid bottom l down = 下眼睑 左 向下（下睑下拉）
            oscillateBase = 0,
            oscillateAmp = 0,
            oscillateFreq = 0,
            fadeTarget = 0,
            spikeTarget = 0.30,
        },
        Blink = { -- Blink = 眨眼（AU45，辅助闭眼）
            oscillateBase = 0.15,
            oscillateAmp = 0.10,
            oscillateFreq = 2.0, -- 原6.5
            fadeTarget = 0.40,
            spikeTarget = 0.05,  -- 强直时几乎不眨眼
        },

        -- ===================================
        -- 嘴唇/嘴巴 (Lips / Mouth) - 濒死期痛呼，张口幅度增大，不对称加剧
        -- ===================================
        -- 上唇上提（小肌肉群，右侧强低频，左侧弱高频）
        liptopmiddleup = {        -- liptopmiddleup = lip top middle up = 上唇 中段 向上（AU10 上唇上提）
            oscillateBase = 0.08, -- 原0.06，微增
            oscillateAmp = 0.03,  -- 原0.02
            oscillateFreq = 3.5,  -- 原10.0
            fadeTarget = 0,
            spikeTarget = 0.30,
        },
        liptoprup = {             -- liptoprup = lip top r up = 上唇 右侧 向上（AU10 上唇上提）
            oscillateBase = 0.20, -- 原0.15，提高
            oscillateAmp = 0.12,  -- 原0.08，增大
            oscillateFreq = 3.0,  -- 原6.5
            fadeTarget = 0,
            spikeTarget = 0.35,
        },
        liptoplup = {             -- liptoplup = lip top l up = 上唇 左侧 向上（AU10 上唇上提）
            oscillateBase = 0.04, -- 原0.03，微增
            oscillateAmp = 0.025, -- 原0.015，增大
            oscillateFreq = 4.0,  -- 原12.0
            fadeTarget = 0,
            spikeTarget = 0.30,
        },
        -- 下唇/下巴上提（中等肌肉，闭口方向，保持较弱）
        lipbottommiddleup = {     -- lipbottommiddleup = lip bottom middle up = 下唇 中段 向上（AU17 下唇/下巴上提）
            oscillateBase = 0.06, -- 原0.08，降低避免闭口
            oscillateAmp = 0.05,  -- 原0.06
            oscillateFreq = 2.5,  -- 原6.0
            fadeTarget = 0,
            spikeTarget = 0.50,
        },
        lipbottomrup = {          -- lipbottomrup = lip bottom r up = 下唇 右侧 向上（AU17 下唇/下巴上提）
            oscillateBase = 0.04, -- 原0.06，降低
            oscillateAmp = 0.03,  -- 原0.03
            oscillateFreq = 2.8,  -- 原5.5
            fadeTarget = 0,
            spikeTarget = 0.30,
        },
        lipbottomlup = {          -- lipbottomlup = lip bottom l up = 下唇 左侧 向上（AU17 下唇/下巴上提）
            oscillateBase = 0.02, -- 原0.02
            oscillateAmp = 0.015, -- 原0.015
            oscillateFreq = 3.5,  -- 原10.0
            fadeTarget = 0,
            spikeTarget = 0.25,
        },
        -- 下唇下压（大肌肉，张口方向，大幅增强）
        lipbottommiddledown = {   -- lipbottommiddledown = lip bottom middle down = 下唇 中段 向下（AU16 下唇下压）
            oscillateBase = 0.25, -- 原0.18，大幅提高
            oscillateAmp = 0.20,  -- 原0.15，增大
            oscillateFreq = 1.3,  -- 原2.0
            fadeTarget = 0.10,
            spikeTarget = 0.05,
        },
        lipbottomrdown = {        -- lipbottomrdown = lip bottom r down = 下唇 右侧 向下（AU16 下唇下压）
            oscillateBase = 0.30, -- 原0.20，大幅提高
            oscillateAmp = 0.25,  -- 原0.22，增大
            oscillateFreq = 1.4,  -- 原1.6
            fadeTarget = 0.05,
            spikeTarget = 0.0,
        },
        lipbottomldown = {        -- lipbottomldown = lip bottom l down = 下唇 左侧 向下（AU16 下唇下压）
            oscillateBase = 0.08, -- 原0.04，提高但仍远弱于右侧
            oscillateAmp = 0.10,  -- 原0.05，增大
            oscillateFreq = 1.8,  -- 原3.5
            fadeTarget = 0.05,
            spikeTarget = 0.0,
        },
        -- 嘴角上提（小肌肉，保持轻微）
        liprsmile = { -- liprsmile = lip r smile = 嘴角 右侧 微笑（AU12 嘴角上提）
            oscillateBase = 0.035,
            oscillateAmp = 0.025,
            oscillateFreq = 3.0, -- 原9.0
            fadeTarget = 0,
            spikeTarget = 0.05,
        },
        liplsmile = { -- liplsmile = lip l smile = 嘴角 左侧 微笑（AU12 嘴角上提）
            oscillateBase = 0.005,
            oscillateAmp = 0.008,
            oscillateFreq = 4.0, -- 原14.0
            fadeTarget = 0,
            spikeTarget = 0.05,
        },
        -- 嘴角下压（中等肌肉，增强痛呼时的下压）
        liprsad = {               -- liprsad = lip r sad = 嘴角 右侧 悲伤/下压（AU15 嘴角下压）
            oscillateBase = 0.30, -- 原0.25，提高
            oscillateAmp = 0.22,  -- 原0.18，增大
            oscillateFreq = 1.5,  -- 原3.0
            fadeTarget = 0.08,
            spikeTarget = 0.60,
        },
        liplsad = {               -- liplsad = lip l sad = 嘴角 左侧 悲伤/下压（AU15 嘴角下压）
            oscillateBase = 0.08, -- 原0.05，提高
            oscillateAmp = 0.06,  -- 原0.04，增大
            oscillateFreq = 2.0,  -- 原7.0
            fadeTarget = 0.06,
            spikeTarget = 0.50,
        },
        -- 嘴角拉伸（中等肌肉，辅助痛呼）
        liprstretcher = {         -- liprstretcher = lip r stretcher = 嘴角 右侧 拉伸（AU20 嘴角水平拉伸）
            oscillateBase = 0.22, -- 原0.18，提高
            oscillateAmp = 0.15,  -- 原0.12，增大
            oscillateFreq = 1.8,  -- 原4.5
            fadeTarget = 0,
            spikeTarget = 0.70,
        },
        liplstretcher = {         -- liplstretcher = lip l stretcher = 嘴角 左侧 拉伸（AU20 嘴角水平拉伸）
            oscillateBase = 0.06, -- 原0.04，提高
            oscillateAmp = 0.05,  -- 原0.04，增大
            oscillateFreq = 2.2,  -- 原8.5
            fadeTarget = 0,
            spikeTarget = 0.60,
        },
        -- 撅嘴（小肌肉，保持适度）
        liprpucker = { -- liprpucker = lip r pucker = 嘴唇 右侧 撅起（AU18 唇前突/撅嘴）
            oscillateBase = 0.12,
            oscillateAmp = 0.07,
            oscillateFreq = 2.5, -- 原7.5
            fadeTarget = 0,
            spikeTarget = 0.70,
        },
        liplpucker = { -- liplpucker = lip l pucker = 嘴唇 左侧 撅起（AU18 唇前突/撅嘴）
            oscillateBase = 0.03,
            oscillateAmp = 0.02,
            oscillateFreq = 3.5, -- 原12.0
            fadeTarget = 0,
            spikeTarget = 0.65,
        },
        -- 张嘴（大肌肉，主导痛呼，大幅增强）
        mouthopen = {                 -- mouthopen = mouth open = 张嘴（AU26 下颌下移/张口）
            oscillateBase = 0.63,     -- 原0.23，大幅提高
            oscillateAmp = 0.32,
            oscillateFreq = 2.4,      -- 原1.4，降低，更低沉
            oscillateBeatDelta = 0.8, -- 单独指定拍频差
            oscillateDecay = false,
            fadeTarget = 0.25,
            spikeTarget = 0.05,
        },
    },

    -- ============================================================================
    -- 眼球运动配置 - 强直期眼球上翻
    -- ============================================================================
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
            spikeTarget   = 0.30, -- 原0.15，明显上翻
        },
    }
}
