local MODULE_NAME = "RagdollManager"

local Constants = include("edae/config/constants.lua")
local log = include("edae/log/init.lua")

local Manager = {}

function Manager:OnCreate(ragdoll)

end

hook.Add("CreateEntityRagdoll", Constants.ADDON_NAME .. MODULE_NAME .. "CreateEntityRagdoll", function(owner, ragdoll)

end)
