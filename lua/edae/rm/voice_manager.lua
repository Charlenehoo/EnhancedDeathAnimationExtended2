local MODULE_NAME = "VoiceManager"
_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants = include("edae/config/constants.lua")
local log = include("edae/log/init.lua")

local VoiceManager = {}

-- 播放受击音效（根据 hitgroup 自动选择）
function VoiceManager:PlayDamageSound(owner, dmginfo)
    if not IsValid(owner) then return end
    if not TFAVOX_PlayVoicePriority then return end
    if not owner.TFAVOX_Sounds or not owner.TFAVOX_Sounds.damage then return end

    local hitgroup = dmginfo:GetHitGroup() or HITGROUP_GENERIC
    local damageSounds = owner.TFAVOX_Sounds.damage
    local soundData = damageSounds[hitgroup] or damageSounds[HITGROUP_GENERIC]
    if not soundData then return end

    TFAVOX_PlayVoicePriority(owner, soundData, 10, true)
end

-- 停止所有语音（死亡时调用）
function VoiceManager:StopAll(owner)
    if IsValid(owner) and TFAVOX_StopAll then
        TFAVOX_StopAll(owner)
    end
end

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = VoiceManager
return VoiceManager
