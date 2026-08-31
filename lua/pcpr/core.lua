local MODULE_NAME = "Core"

local Constants = include("pcpr/constants.lua")
local log = include("log/init.lua")

local meta = FindMetaTable("Player")
if not meta then
    log.fatal("Cannot find meta table: Player")
    return
end

local originalCreateRagdoll = meta.CreateRagdoll
if not originalCreateRagdoll then
    log.fatal("Cannot find function: Player.CreateRagdoll")
    return
end

local plyToRagdollMap = {}

hook.Add("PlayerDisconnected", Constants.ADDON_NAME .. MODULE_NAME .. "PlayerDisconnected", function(ply)
    plyToRagdollMap[ply] = nil
end)

meta.CreateRagdoll = function(self)
    if not IsValid(self) or not self:IsPlayer() then
        return originalCreateRagdoll(self)
    end
    local ply = self

    local plyModelName = ply:GetModel()
    if not plyModelName then
        log.warn("")
        return originalCreateRagdoll(self)
    end


    -- local ragdoll = ents.Create("prop_ragdoll")
end
