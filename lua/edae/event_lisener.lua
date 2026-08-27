local MODULE_NAME = "Event Lisener"

local Constants = include("edae/constants.lua")
local log = include("edae/log/init.lua")
local AnimationPlayer = include("edae/animation_player.lua")
local AnimationSelector = include("edae/animation_selector.lua")

hook.Add("CreateEntityRagdoll", Constants.ADDON_NAME .. MODULE_NAME .. "CreateEntityRagdoll", function(owner, ragdoll)
    if not IsValid(owner) or not IsValid(ragdoll) then return end

    local state = "falling"
    local animationName = AnimationSelector:Select(state)
    local ctx = AnimationPlayer:Play(ragdoll, animationName)
    ctx.state = state
end)
