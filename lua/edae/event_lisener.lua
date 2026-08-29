local MODULE_NAME = "Event Lisener"

local Constants = include("edae/constants.lua")
local log = include("edae/log/init.lua")
local AnimationPlayer = include("edae/animation_player.lua")
local AnimationSelector = include("edae/animation_selector.lua")
local DamageContextManager = include("edae/damage_context_manager.lua")

-- 播放动画的通用函数
local function playAnimationForState(ragdoll, state, damageContext, yaw)
    local animationName, totalLoops = AnimationSelector:Select(damageContext, state)
    if not animationName then
        log.warn("Event Lisener: no animation for state ", state)
        return
    end

    local opts = {
        state = state,
        totalLoops = totalLoops or 0,
        yaw = yaw or ragdoll:GetAngles().yaw,
        damageContext = damageContext,
    }

    AnimationPlayer:Play(ragdoll, animationName, opts)
end

hook.Add("CreateEntityRagdoll", Constants.ADDON_NAME .. MODULE_NAME .. "CreateEntityRagdoll", function(owner, ragdoll)
    if not IsValid(owner) or not IsValid(ragdoll) then return end

    local context = DamageContextManager:Get(owner)
    local state = "falling"
    local aimVector = owner:GetAimVector()
    local yaw = aimVector:Angle().yaw

    -- 初始状态直接播放
    playAnimationForState(ragdoll, state, context, yaw)
end)

hook.Add("EDAE_RagdollStateChange", Constants.ADDON_NAME .. MODULE_NAME .. "RagdollStateChange",
    function(ragdoll, nextState, damageContext, yaw)
        if not IsValid(ragdoll) then return end
        playAnimationForState(ragdoll, nextState, damageContext, yaw)
    end)

-- 其他钩子（ScaleNPCDamage 等）保持不变...

local function handleScaleDamage(ent, hitgroup, dmginfo)
    DamageContextManager:Update(ent, hitgroup, dmginfo)
end

hook.Add("ScaleNPCDamage", Constants.ADDON_NAME .. MODULE_NAME .. "ScaleNPCDamage", function(npc, hitgroup, dmginfo)
    handleScaleDamage(npc, hitgroup, dmginfo)
end)

hook.Add("ScalePlayerDamage", Constants.ADDON_NAME .. MODULE_NAME .. "ScalePlayerDamage",
    function(ply, hitgroup, dmginfo)
        handleScaleDamage(ply, hitgroup, dmginfo)
    end)

-- hook.Add("ScalePlayerDamage", Constants.ADDON_NAME .. MODULE_NAME .. "ScalePlayerDamage",
--     function(ply, hitgroup, dmginfo)
--         dmginfo:ScaleDamage(100)
--     end)
