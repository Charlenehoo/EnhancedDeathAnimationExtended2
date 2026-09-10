-- lua/edae/ragdoll/voice_manager.lua
local MODULE_NAME = "VoiceManager"
_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local log                 = include("edae/core/log/init.lua")

local VoiceManager        = {}

local EVENT_VOICE_PLAYED  = "EDAE_VoicePlayed"
local EVENT_VOICE_STOPPED = "EDAE_VoiceStopped"

-- ============================================================
-- 包装 TFAVOX_PlayVoicePriority 以捕获实际文件名
-- ============================================================
-- 原理：
--   1. TFAVOX_GenerateSound 在 softcap 内会为每个音频文件单独注册 soundscript，
--      返回 soundscript 名列表。
--   2. TFAVOX_GetSoundTableSound(sndtbl) 随机选一个 soundscript 名（播放用）。
--   3. TFAVOX_GetSoundTableSound(sndtbl, true) 做同样随机，但会再查 soundscript
--      的 .sound 字段，返回具体文件路径。
--   4. 两次调用均以 CurTime() 为随机种子，因此在同一 tick 内结果完全相同。
--   因此可以在真正播放前精确预测本次将播放的文件路径。
-- ============================================================

local installed           = false

local function InstallVoiceWrapper()
    if installed then return end

    if not TFAVOX_PlayVoicePriority or not TFAVOX_GetSoundTableSound then
        log.warn("[VoiceManager] TFAVOX not available, lipsync capture disabled.")
        return
    end

    -- 防止同一 Lua 状态下重复包装（例如 lua_openscript reload 本文件时）
    if TFAVOX_PlayVoicePriority._edae_wrapped then
        installed = true
        return
    end

    local orig = TFAVOX_PlayVoicePriority

    function TFAVOX_PlayVoicePriority(ply, sndtbl, priority, command)
        if not IsValid(ply) then
            return orig(ply, sndtbl, priority, command)
        end

        -- 复现 TFAVOX 内部的优先级判定，只有确定会播放时才预测文件
        local willPlay = (CurTime() > (ply.TFAVOX_NextPriorityVoiceCall or -1))
            or (priority > (ply.TFAVOX_PriorityVoiceCall or 0))
            or ((priority == (ply.TFAVOX_PriorityVoiceCall or 0)) and command)

        if not willPlay then
            return orig(ply, sndtbl, priority, command)
        end

        -- 同一 tick 内种子确定，拿到的一定是即将播放的文件
        local actualFile = TFAVOX_GetSoundTableSound(sndtbl, true)

        orig(ply, sndtbl, priority, command)

        if actualFile and string.find(actualFile, "%.%w+$") then
            hook.Run(EVENT_VOICE_PLAYED, ply, actualFile)
        end
    end

    TFAVOX_PlayVoicePriority._edae_wrapped = true
    installed = true
    log.info("[VoiceManager] TFAVOX_PlayVoicePriority wrapped for lipsync capture.")
end

-- 在 InitPostEntity 阶段安装包装：此时所有 Lua 文件已加载，
-- TFAVOX_PlayVoicePriority 一定存在，且实体尚未开始触发声音。
hook.Add("InitPostEntity", MODULE_NAME .. "_InstallVoiceWrapper", InstallVoiceWrapper)

-- ============================================================
-- 统一发声入口（EDAE 内部使用，包装器会自动广播事件）
-- ============================================================

--- 统一发声入口
--- @param owner Entity 玩家实体
--- @param category string 声音分类（"main" / "external" / "calloutsextra" 等）
--- @param key string 分类下的键名（"crithit" / "overkill" 等）
--- @param priority number 优先级
--- @param interrupt boolean 是否打断当前语音
--- @return boolean 是否成功播放
function VoiceManager:Play(owner, category, key, priority, interrupt)
    if not IsValid(owner) or not owner:IsPlayer() then return false end
    if not TFAVOX_PlayVoicePriority then return false end

    local sounds = owner.TFAVOX_Sounds
    if not sounds or not sounds[category] or not sounds[category][key] then
        return false
    end

    TFAVOX_PlayVoicePriority(owner, sounds[category][key], priority, interrupt)
    return true
end

--- 播放受击音效（统一使用 crithit）
--- @param owner Entity 玩家实体
function VoiceManager:PlayDamageSound(owner)
    self:Play(owner, "main", "crithit", 10, false)
end

--- 播放死亡音效
--- @param owner Entity 玩家实体
function VoiceManager:PlayDeathSound(owner)
    self:Play(owner, "main", "death", 10, true)
end

--- 停止所有语音（死亡时调用）
--- @param owner Entity 玩家实体
function VoiceManager:StopAll(owner)
    if IsValid(owner) and owner:IsPlayer() and TFAVOX_StopAll then
        TFAVOX_StopAll(owner)
        hook.Run(EVENT_VOICE_STOPPED, owner)
    end
end

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = VoiceManager
return VoiceManager
