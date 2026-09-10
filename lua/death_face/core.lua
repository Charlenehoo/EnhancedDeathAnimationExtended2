-- lua/autorun/server/death_face.lua
local PLUGIN_NAME      = "Death_Face_"
local FADE_DURATION    = 1.5 -- FADE 过渡到目标权重所需时间（秒）

-- ============================================================================
-- 全局可调参数
-- ============================================================================
local SPIKE_DURATION   = 0.3  -- 尖峰阶段持续时间（秒）
local SPIKE_COOLDOWN   = 2.1  -- 尖峰冷却时间（秒）
local FREQ             = 10.0 -- 形态键振荡默认频率（若某个键未单独指定）

local config           = include("death_face/config.lua")

local activeCoroutines = {}

-- ============================================================================
-- EDAE 接口引用（延迟获取）
-- ============================================================================
local EDAE_Events      = nil
local EDAE_GetState    = nil

-- ============================================================================
-- Lipsync 缓存（key -> lipData | false）
-- ============================================================================
local lipsyncCache     = {}

--- 规范化 voice key：'deltaforce_MaiXiaowen/crithit1.wav' -> 'deltaforce_maixiaowen/crithit1'
--- @param actualFile string
--- @return string
local function NormalizeVoiceKey(actualFile)
    local key = actualFile:lower()
    key = key:gsub("^sound/", "")
    key = key:gsub("%.wav$", ""):gsub("%.mp3$", ""):gsub("%.ogg$", "")
    return key
end

--- 获取 lipsync 数据（带缓存）
--- @param voiceKey string
--- @return table|nil
local function GetLipsync(voiceKey)
    local cached = lipsyncCache[voiceKey]
    if cached ~= nil then
        return cached or nil -- false 表示已查过、不存在
    end

    local path = "death_face/lipsync/" .. voiceKey .. ".lua"
    if not file.Exists(path, "LUA") then
        lipsyncCache[voiceKey] = false
        return nil
    end

    local ok, data = pcall(include, path)
    if not ok or type(data) ~= "table" or not data.frames then
        lipsyncCache[voiceKey] = false
        return nil
    end

    lipsyncCache[voiceKey] = data
    return data
end

-- ============================================================================
-- 纯函数：数学与辅助
-- ============================================================================
local function easeOutCubic(t)
    return 1 - (1 - t) ^ 3
end

local function MakeEyeDir(hor, ver)
    local cosV = math.cos(ver)
    return Vector(
        math.cos(hor) * cosV,
        math.sin(hor) * cosV,
        math.sin(ver)
    )
end

-- ============================================================================
-- 眼睛控制策略
-- ============================================================================
local function SetEyeDirection_EyeTarget(ragdoll, hor, ver)
    local dir = MakeEyeDir(hor, ver)
    local eyesID = ragdoll:LookupAttachment("eyes")
    if not eyesID or eyesID == 0 then return false end
    local attach = ragdoll:GetAttachment(eyesID)
    if not attach then return false end
    ragdoll:SetEyeTarget(dir * 200)
    return true
end

local function SetEyeDirection_BoneAngles(ragdoll, hor, ver, eyeControlConfig)
    local base      = eyeControlConfig.baseAngles or Angle(0, 0, 0)
    local yaw       = math.deg(hor) * (eyeControlConfig.horScale or 1.0)
    local pitch     = math.deg(ver) * (eyeControlConfig.verScale or 1.0)

    local leftHor   = yaw * (eyeControlConfig.left and eyeControlConfig.left.horScale or 1.0)
    local leftVer   = pitch * (eyeControlConfig.left and eyeControlConfig.left.verScale or 1.0)
    local rightHor  = yaw * (eyeControlConfig.right and eyeControlConfig.right.horScale or 1.0)
    local rightVer  = pitch * (eyeControlConfig.right and eyeControlConfig.right.verScale or 1.0)

    local leftAng   = base + Angle(leftVer, leftHor, 0)
    local rightAng  = base + Angle(rightVer, rightHor, 0)

    local leftBone  = ragdoll:LookupBone(eyeControlConfig.leftBone or "Eye_L")
    local rightBone = ragdoll:LookupBone(eyeControlConfig.rightBone or "Eye_R")

    if leftBone then ragdoll:ManipulateBoneAngles(leftBone, leftAng) end
    if rightBone then ragdoll:ManipulateBoneAngles(rightBone, rightAng) end
    return leftBone ~= nil or rightBone ~= nil
end

local function SetEyeDirection_FlexEye(ragdoll, hor, ver, eyeControlConfig)
    local upWeight   = math.max(0, ver)
    local downWeight = math.max(0, -ver)

    local upL        = ragdoll:GetFlexIDByName(eyeControlConfig.upL)
    local downL      = ragdoll:GetFlexIDByName(eyeControlConfig.downL)
    local upR        = ragdoll:GetFlexIDByName(eyeControlConfig.upR)
    local downR      = ragdoll:GetFlexIDByName(eyeControlConfig.downR)

    if upL then ragdoll:SetFlexWeight(upL, upWeight * 0.5) end
    if downL then ragdoll:SetFlexWeight(downL, downWeight * 0.5) end
    if upR then ragdoll:SetFlexWeight(upR, upWeight * 0.5) end
    if downR then ragdoll:SetFlexWeight(downR, downWeight * 0.5) end
end

local function GetEyeControlFunction(eyeControl, eyeControlConfig)
    eyeControlConfig = eyeControlConfig or {}
    if eyeControl == "boneangle" then
        return function(ragdoll, hor, ver)
            SetEyeDirection_BoneAngles(ragdoll, hor, ver, eyeControlConfig)
        end
    elseif eyeControl == "flexeye" then
        if not eyeControlConfig then
            ErrorNoHalt("[Death Face] eyeControl is 'flexeye' but eyeControlConfig is missing!\n")
            return function() end
        end
        return function(ragdoll, hor, ver)
            SetEyeDirection_FlexEye(ragdoll, hor, ver, eyeControlConfig)
        end
    else
        return SetEyeDirection_EyeTarget
    end
end

-- ============================================================================
-- 口型 flex 自动检测
-- ============================================================================
local VOICE_MOUTH_FLEX_CANDIDATES = {
    "mouth_open",
    "mouthopen",
    "jaw_open",
    "jawopen",
    "mouth_Open",
}

local function DetectMouthFlex(ragdoll, modelConfig)
    if modelConfig.voiceMouthFlex then
        return modelConfig.voiceMouthFlex
    end
    for _, name in ipairs(VOICE_MOUTH_FLEX_CANDIDATES) do
        if ragdoll:GetFlexIDByName(name) then
            return name
        end
    end
    return nil
end

-- ============================================================================
-- 纯函数：创建多频叠加参数（每个形态键）
-- ============================================================================
local function CreateFlexWaves(flexConfig)
    local flexWaves = {}

    for name, cfg in pairs(flexConfig) do
        local baseFreq = cfg.oscillateFreq or FREQ
        local baseAmp  = cfg.oscillateAmp or 0

        if baseAmp <= 0 then
            flexWaves[name] = nil
        else
            local beatDelta = cfg.oscillateBeatDelta

            if not beatDelta then
                if baseFreq < 1.2 then
                    beatDelta = math.Rand(0.3, 0.5)
                elseif baseFreq < 3.0 then
                    beatDelta = math.Rand(0.5, 0.7)
                else
                    beatDelta = math.Rand(0.6, 0.9)
                end
            end

            local highFreq = math.min(baseFreq * 2.31, 10)
            local norm = 1.0 + 0.6 + 0.25

            local layers = {
                { weight = 1.0 / norm,  freq = baseFreq,             phase = math.Rand(0, math.pi * 2) },
                { weight = 0.6 / norm,  freq = baseFreq + beatDelta, phase = math.Rand(0, math.pi * 2) },
                { weight = 0.25 / norm, freq = highFreq,             phase = math.Rand(0, math.pi * 2) },
            }

            flexWaves[name] = layers
        end
    end

    return flexWaves
end

-- ============================================================================
-- 纯函数：创建眼睛振荡状态
-- ============================================================================
local function CreateEyeState(template, freqMin, freqMax)
    return {
        oscillateBase  = template.oscillateBase,
        oscillateAmp   = template.oscillateAmp,
        oscillateFreq  = math.Rand(freqMin, freqMax),
        oscillatePhase = math.Rand(0, math.pi * 2),
        fadeTarget     = template.fadeTarget,
        spikeTarget    = template.spikeTarget,
    }
end

-- ============================================================================
-- 纯函数：计算某形态键的振荡权重
-- ============================================================================
local function ComputeOscillateWeight(cfg, layers, t)
    local sum = 0
    for _, layer in ipairs(layers) do
        sum = sum + layer.weight * math.cos(layer.freq * t + layer.phase)
    end
    return cfg.oscillateBase - cfg.oscillateAmp * sum
end

-- ============================================================================
-- 纯函数：计算眼睛角度（正弦振荡）
-- ============================================================================
local function ComputeEyeAngle(eyeState, t)
    return eyeState.oscillateBase
        + eyeState.oscillateAmp * math.sin(eyeState.oscillateFreq * t + eyeState.oscillatePhase)
end

-- ============================================================================
-- 应用函数：设置形态键权重与眼球方向
-- ============================================================================
local function ApplyAnimation(ragdoll, weights, currentHor, currentVer, setEyeDirection, ctx)
    local mouthFlex    = ctx.voiceMouthFlex
    local mouthOffset  = ctx.voiceMouthOffset or 0
    local mouthHandled = false

    for name, weight in pairs(weights) do
        local id = ragdoll:GetFlexIDByName(name)
        if id then
            local finalWeight = weight
            if name == mouthFlex then
                mouthHandled = true
                finalWeight = finalWeight + mouthOffset
            end
            ragdoll:SetFlexWeight(id, math.Clamp(finalWeight, 0, 1))
        end
    end

    -- 如果 mouth flex 不在 weights 中（例如 flexConfig 未包含它），单独处理
    if mouthFlex and not mouthHandled and mouthOffset > 0 then
        local id = ragdoll:GetFlexIDByName(mouthFlex)
        if id then
            ragdoll:SetFlexWeight(id, math.Clamp(mouthOffset, 0, 1))
        end
    end

    if setEyeDirection then
        setEyeDirection(ragdoll, currentHor, currentVer)
    end
end

-- ============================================================================
-- 状态处理函数
-- ============================================================================
local function ProcessHit(ctx, animState, elapsed)
    local hit = ctx.pendingHit
    ctx.pendingHit = false

    if hit and animState.state == "oscillate" and CurTime() >= (ctx.cooldownUntil or 0) then
        for name, cfg in pairs(ctx.flexConfig) do
            animState.startWeights[name] = animState.currentWeights[name]
        end

        animState.fadeStartHor = animState.currentHor
        animState.fadeStartVer = animState.currentVer
        animState.state = "spike"
        animState.stateStartTime = elapsed

        -- 注意：声音播放由 ragdoll_manager 统一负责
        -- Death Face 不再主动调用 TFAVOX，只消费 EDAE_VoicePlayed 事件驱动口型
    end
end

local function ProcessOscillate(ctx, animState, t_local, elapsed)
    for name, cfg in pairs(ctx.flexConfig) do
        local layers = animState.flexWaves[name]
        if layers then
            animState.currentWeights[name] = ComputeOscillateWeight(cfg, layers, t_local)
        else
            animState.currentWeights[name] = cfg.oscillateBase
        end
    end

    animState.currentHor = ComputeEyeAngle(animState.eyeHoriz, t_local)
    animState.currentVer = ComputeEyeAngle(animState.eyeVert, t_local)
end

local function ProcessSpike(ctx, animState, t_local, elapsed)
    if t_local < SPIKE_DURATION then
        local progress = t_local / SPIKE_DURATION

        for name, cfg in pairs(ctx.flexConfig) do
            local from                     = animState.startWeights[name]
            local to                       = cfg.spikeTarget
            animState.currentWeights[name] = from + (to - from) * progress
        end

        local horTarget = animState.eyeHoriz.spikeTarget
        local verTarget = animState.eyeVert.spikeTarget
        animState.currentHor = animState.fadeStartHor + (horTarget - animState.fadeStartHor) * progress
        animState.currentVer = animState.fadeStartVer + (verTarget - animState.fadeStartVer) * progress
    else
        for name, cfg in pairs(ctx.flexConfig) do
            animState.startWeights[name] = cfg.spikeTarget
        end
        animState.fadeStartHor = animState.eyeHoriz.spikeTarget
        animState.fadeStartVer = animState.eyeVert.spikeTarget
        animState.state = "fade"
        animState.stateStartTime = elapsed
        ctx.cooldownUntil = CurTime() + SPIKE_COOLDOWN
    end
end

local function ProcessFade(ctx, animState, t_local, elapsed)
    -- 使用固定 FADE_DURATION，避免 elapsed 累加导致的过渡变慢 bug
    local progress = math.min(t_local / FADE_DURATION, 1.0)
    local eased = easeOutCubic(progress)

    for name, cfg in pairs(ctx.flexConfig) do
        local from                     = animState.startWeights[name]
        local to                       = cfg.fadeTarget
        animState.currentWeights[name] = from + (to - from) * eased
    end

    animState.currentHor = animState.fadeStartHor + (animState.eyeHoriz.fadeTarget - animState.fadeStartHor) * eased
    animState.currentVer = animState.fadeStartVer + (animState.eyeVert.fadeTarget - animState.fadeStartVer) * eased
    -- Fade 无限持续，不自动结束；过渡完成后保持 fadeTarget 状态
end

-- ============================================================================
-- 口型同步协程：逐帧查表
-- ============================================================================
local function MouthSyncFromFrames(ctx, lipData, myToken)
    local ragdoll = ctx.ragdoll
    local fps = lipData.fps or 30
    local frames = lipData.frames
    local frameDuration = 1 / fps

    local startTime = CurTime()
    local currentIndex = 0

    while currentIndex < #frames do
        if not IsValid(ragdoll) then return end
        -- 被新声音替换，直接退出（offset 由新协程负责）
        if ctx.mouthToken ~= myToken then return end

        local elapsed = CurTime() - startTime
        local targetIndex = math.floor(elapsed / frameDuration) + 1

        while currentIndex < targetIndex and currentIndex < #frames do
            currentIndex = currentIndex + 1
            ctx.voiceMouthOffset = frames[currentIndex] or 0
        end

        coroutine.yield()
    end

    -- 自然结束，归零（仅当 token 仍属于自己的时候）
    if ctx.mouthToken == myToken then
        ctx.voiceMouthOffset = 0
    end
end

-- ============================================================================
-- 协程主逻辑
-- ============================================================================
local function deathFaceCoroutine(ctx)
    local ragdoll = ctx.ragdoll
    local elapsed = 0

    local flexWaves = CreateFlexWaves(ctx.flexConfig)

    local animState = {
        state          = "oscillate", -- 默认，稍后根据 EDAE 初始化状态覆盖
        stateStartTime = 0,
        startWeights   = {},
        currentWeights = {},
        flexWaves      = flexWaves,
        currentHor     = 0,
        currentVer     = 0,
        fadeStartHor   = 0,
        fadeStartVer   = 0,
        eyeHoriz       = CreateEyeState(ctx.eyeConfigTemplate.horiz, 1.5, 3.0),
        eyeVert        = CreateEyeState(ctx.eyeConfigTemplate.vert, 2.0, 4.0),
        finished       = false,
    }

    for name, cfg in pairs(ctx.flexConfig) do
        animState.startWeights[name]   = 0
        animState.currentWeights[name] = 0
    end

    -- 根据启动时传入的 EDAE 初始状态决定初始表情
    if ctx.initEDAEState == "dead" then
        animState.state = "fade"
        animState.stateStartTime = elapsed
        for name, cfg in pairs(ctx.flexConfig) do
            animState.startWeights[name] = 0
        end
        animState.fadeStartHor = 0
        animState.fadeStartVer = 0
    else
        animState.state = "oscillate"
        animState.stateStartTime = elapsed
    end

    while ragdoll:IsValid() and not animState.finished do
        -- 处理外部命令（治愈优先）
        if ctx.pendingOscillate then
            ctx.pendingOscillate = false
            animState.state = "oscillate"
            animState.stateStartTime = elapsed
            for name, cfg in pairs(ctx.flexConfig) do
                animState.startWeights[name] = animState.currentWeights[name]
            end
            animState.fadeStartHor = animState.currentHor
            animState.fadeStartVer = animState.currentVer
        elseif ctx.pendingFade then
            ctx.pendingFade = false
            if animState.state ~= "spike" then
                animState.state = "fade"
                animState.stateStartTime = elapsed
                for name, cfg in pairs(ctx.flexConfig) do
                    animState.startWeights[name] = animState.currentWeights[name]
                end
                animState.fadeStartHor = animState.currentHor
                animState.fadeStartVer = animState.currentVer
            end
            -- 若为 spike，等待自然结束进入 fade
        end

        -- 处理受击（可能触发 spike）
        ProcessHit(ctx, animState, elapsed)

        local t_local = elapsed - animState.stateStartTime

        if animState.state == "oscillate" then
            ProcessOscillate(ctx, animState, t_local, elapsed)
        elseif animState.state == "spike" then
            ProcessSpike(ctx, animState, t_local, elapsed)
        elseif animState.state == "fade" then
            ProcessFade(ctx, animState, t_local, elapsed)
        end

        ApplyAnimation(ragdoll,
            animState.currentWeights,
            animState.currentHor,
            animState.currentVer,
            ctx.setEyeDirection,
            ctx)

        local dt = coroutine.yield()
        if dt then
            elapsed = elapsed + dt
        end
    end
end

-- ============================================================================
-- 启动协程
-- ============================================================================
local function StartDeathFace(ragdoll, owner, initState)
    if not IsValid(ragdoll) then return end
    if activeCoroutines[ragdoll] then return end

    local modelConfig = config.GetModelConfig(ragdoll:GetModel())

    local ctx = {
        owner             = owner,
        ragdoll           = ragdoll,
        pendingHit        = false,
        cooldownUntil     = 0,
        flexConfig        = modelConfig.flexConfig,
        eyeConfigTemplate = modelConfig.eyeConfigTemplate,
        setEyeDirection   = GetEyeControlFunction(
            modelConfig.eyeControl or "eyetarget",
            modelConfig.eyeControlConfig
        ),
        pendingOscillate  = false,
        pendingFade       = false,
        initEDAEState     = initState, -- 启动时的 EDAE 状态

        -- 口型相关
        voiceMouthFlex    = DetectMouthFlex(ragdoll, modelConfig),
        voiceMouthOffset  = 0,
        mouthCo           = nil,
        mouthToken        = nil,
    }

    local co = coroutine.create(deathFaceCoroutine)
    local ok, err = coroutine.resume(co, ctx)
    if not ok then
        ErrorNoHalt(PLUGIN_NAME .. ": Failed to start coroutine: " .. tostring(err) .. "\n")
        return
    end

    activeCoroutines[ragdoll] = { coroutine = co, context = ctx }
end

-- ============================================================================
-- 初始化函数：在 EDAE 加载完成后调用，获取接口并注册事件
-- ============================================================================
local function InitDeathFace()
    if EDAE_Events then return end -- 已初始化

    if not EnhancedDeathAnimationExtended
        or not EnhancedDeathAnimationExtended.Events
        or not EnhancedDeathAnimationExtended.Interface then
        ErrorNoHalt("[Death Face] EDAE interface not found!\n")
        return
    end

    EDAE_Events   = EnhancedDeathAnimationExtended.Events
    EDAE_GetState = EnhancedDeathAnimationExtended.Interface.GetState

    -- ---- 布娃娃初始化 ----
    hook.Add(EDAE_Events.OnRagdollInitialized, PLUGIN_NAME .. "OnEDAEInit",
        function(ragdoll, owner, initState)
            StartDeathFace(ragdoll, owner, initState)
        end)

    -- ---- 受击事件：只触发 Spike，不发声 ----
    hook.Add(EDAE_Events.PostRagdollTakeDamage, PLUGIN_NAME .. "OnDamage",
        function(ragdoll, data)
            local active = activeCoroutines[ragdoll]
            if not active then return end
            local ctx = active.context

            local edaeState = EDAE_GetState(ragdoll)
            if edaeState == "dead" then return end

            ctx.pendingHit = true
        end)

    -- ---- EDAE 状态变化 ----
    hook.Add(EDAE_Events.OnRagdollStateChange, PLUGIN_NAME .. "OnStateChange",
        function(ragdoll, newState, oldState)
            local active = activeCoroutines[ragdoll]
            if not active then return end
            local ctx = active.context

            -- 治愈事件：从其他状态进入 self_reviving 或 getting_up 的上升沿
            if (newState == "self_reviving" or newState == "getting_up")
                and (oldState ~= "self_reviving" and oldState ~= "getting_up") then
                ctx.pendingOscillate = true
            end

            -- 死亡事件：从其他状态进入 dead 的上升沿
            if newState == "dead" and oldState ~= "dead" then
                ctx.pendingFade = true
            end
        end)

    -- ---- 口型同步：VoiceManager 广播的实际播放文件 ----
    hook.Add(EDAE_Events.VoicePlayed, PLUGIN_NAME .. "OnVoicePlayed",
        function(owner, actualFile, voiceKey)
            if not IsValid(owner) then return end
            local ragdoll = owner:GetRagdollEntity()
            if not IsValid(ragdoll) then return end

            local active = activeCoroutines[ragdoll]
            if not active then return end
            local ctx = active.context

            -- 如果该模型没有可用的口型 flex，直接跳过
            if not ctx.voiceMouthFlex then return end

            -- voiceKey 优先从事件取；没有就本地规范化
            voiceKey = voiceKey or NormalizeVoiceKey(actualFile)

            local lipData = GetLipsync(voiceKey)
            if not lipData then return end

            -- 用新 token 替换当前口型协程；旧协程会在下一帧检测到 token 变化后退出
            local myToken = {}
            ctx.mouthToken = myToken

            local co = coroutine.create(function()
                MouthSyncFromFrames(ctx, lipData, myToken)
            end)
            ctx.mouthCo = co
            coroutine.resume(co)
        end)

    -- ---- 口型同步：语音被打断时停止 ----
    hook.Add(EDAE_Events.VoiceStopped, PLUGIN_NAME .. "OnVoiceStopped",
        function(owner)
            if not IsValid(owner) then return end
            local ragdoll = owner:GetRagdollEntity()
            if not IsValid(ragdoll) then return end

            local active = activeCoroutines[ragdoll]
            if not active then return end
            local ctx            = active.context

            -- 使当前口型协程失效，并归零
            ctx.mouthToken       = nil
            ctx.mouthCo          = nil
            ctx.voiceMouthOffset = 0
        end)
end

-- 监听 EDAE 加载完成事件
hook.Add("EDAE_Loaded", PLUGIN_NAME .. "EDAE_Loaded", InitDeathFace)

-- ============================================================================
-- Tick 驱动所有协程（主协程 + 口型协程）
-- ============================================================================
hook.Add("Tick", PLUGIN_NAME .. "Tick", function()
    local dt = engine.TickInterval()

    for ragdoll, data in pairs(activeCoroutines) do
        if not IsValid(ragdoll) then
            activeCoroutines[ragdoll] = nil
        else
            local ctx = data.context

            -- 驱动主协程
            local ok, msg = coroutine.resume(data.coroutine, dt)
            if not ok then
                ErrorNoHalt(PLUGIN_NAME .. ": Coroutine error: " .. tostring(msg) .. "\n")
                activeCoroutines[ragdoll] = nil
            elseif coroutine.status(data.coroutine) == "dead" then
                activeCoroutines[ragdoll] = nil
            else
                -- 驱动口型协程（如果有）
                local mouthCo = ctx.mouthCo
                if mouthCo and coroutine.status(mouthCo) ~= "dead" then
                    local mok, merr = coroutine.resume(mouthCo)
                    if not mok then
                        ErrorNoHalt(PLUGIN_NAME .. ": Mouth coroutine error: " .. tostring(merr) .. "\n")
                        ctx.mouthCo = nil
                    elseif coroutine.status(mouthCo) == "dead" then
                        ctx.mouthCo = nil
                    end
                end
            end
        end
    end
end)
