local MODULE_NAME = "Event Lisener"

local Constants = include("edae/constants.lua")
local log = include("edae/log/init.lua")
local AnimationPlayer = include("edae/animation_player.lua")
local AnimationSelector = include("edae/animation_selector.lua")

hook.Add("CreateEntityRagdoll", Constants.ADDON_NAME .. MODULE_NAME .. "CreateEntityRagdoll", function(owner, ragdoll)
    if not IsValid(owner) or not IsValid(ragdoll) then return end

    local aimVector = owner:GetAimVector()

    local opts = {}
    opts.state = "falling"
    opts.yaw = aimVector:Angle().yaw
    local animationName = AnimationSelector:Select()
    local ctx = AnimationPlayer:Play(ragdoll, animationName, opts)
end)

hook.Add("ScalePlayerDamage", Constants.ADDON_NAME .. MODULE_NAME .. "ScalePlayerDamage",
    function(ply, hitgroup, dmginfo)
        dmginfo:ScaleDamage(100)
    end)
