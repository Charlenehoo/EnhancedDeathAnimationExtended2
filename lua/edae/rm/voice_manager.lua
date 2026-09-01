-- lua/edae/rm/voice_manager.lua
local MODULE_NAME = "VoiceManager"
_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local log = include("edae/log/init.lua")

local VoiceManager = {}

--- 播放受击音效（统一使用 crithit）
--- @param owner Entity 玩家实体
function VoiceManager:PlayDamageSound(owner)
    if not IsValid(owner) or not owner:IsPlayer() then return end
    if not TFAVOX_PlayVoicePriority then return end

    local sounds = owner.TFAVOX_Sounds
    if not sounds or not sounds.main or not sounds.main.crithit then return end

    -- 参数说明：玩家、声音表、优先级、是否打断当前语音
    TFAVOX_PlayVoicePriority(owner, sounds.main.crithit, 10, false)
end

--- 停止所有语音（死亡时调用）
--- @param owner Entity 玩家实体
function VoiceManager:StopAll(owner)
    if IsValid(owner) and owner:IsPlayer() and TFAVOX_StopAll then
        TFAVOX_StopAll(owner)
    end
end

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = VoiceManager
return VoiceManager
