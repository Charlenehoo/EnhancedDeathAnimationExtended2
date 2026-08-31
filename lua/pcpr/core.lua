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

local originalGetRagdollEntity = meta.GetRagdollEntity
if not originalGetRagdollEntity then
    log.fatal("Cannot find function: Player.GetRagdollEntity")
    return
end

local plyToRagdollMap = {}

hook.Add("PlayerDisconnected", Constants.ADDON_NAME .. MODULE_NAME .. "PlayerDisconnected", function(ply)
    plyToRagdollMap[ply] = nil
end)

meta.GetRagdollEntity = function(self)
    return plyToRagdollMap[self] or originalGetRagdollEntity(self)
end

local cleanUp = function(ply)
    local ragdoll = ply:GetRagdollEntity()
    if IsValid(ragdoll) then
        ragdoll:Remove()
    end
    plyToRagdollMap[ply] = nil
    return originalCreateRagdoll(ply)
end

meta.CreateRagdoll = function(self)
    if not IsValid(self) or not self:IsPlayer() then
        return cleanUp(self)
    end

    local plyModel = self:GetModel()
    if not plyModel then
        log.warn("Cannot find model for player: ", self)
        return cleanUp(self)
    end

    local ragdoll = ents.Create("prop_ragdoll")
    plyToRagdollMap[self] = ragdoll
    if not IsValid(ragdoll) then
        return cleanUp(self)
    end

    ragdoll:SetModel(plyModel)
    local ragdollModel = ragdoll:GetModel()
    if not ragdollModel or ragdollModel ~= plyModel then
        log.warn("Cannot set model for player: ", self, "; Ragdoll: ", ragdoll)
        return cleanUp(self)
    end
    ragdoll:Spawn()

    local physicsObjectCount = ragdoll:GetPhysicsObjectCount()
    if not physicsObjectCount or physicsObjectCount < 1 then
        return cleanUp(self)
    end

    for physObjNum = 0, physicsObjectCount - 1 do
        local boneID = ragdoll:TranslatePhysBoneToBone(physObjNum)
        if not boneID then continue end

        local pos, ang = self:GetBonePosition(boneID)
        if not pos then continue end

        local physObj = ragdoll:GetPhysicsObjectNum(physObjNum)
        if not physObj then continue end

        physObj:SetPos(pos, true)
        physObj:SetAngles(ang)
        physObj:EnableMotion(true)
        physObj:Wake()
    end

    self:SpectateEntity(ragdoll)

    hook.Run("CreateEntityRagdoll", self, ragdoll)

    return ragdoll
end
