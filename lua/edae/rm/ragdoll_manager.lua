local MODULE_NAME = "RagdollManager"

local Constants = include("edae/config/constants.lua")
local log = include("edae/log/init.lua")
local EntityDataStore = include("edae/eds/entity_data_store.lua")
local LifeCycleHandler = include("edae/lch/life_cycle_handler.lua")

local store = EntityDataStore:ForOwner(MODULE_NAME)
local RAGDOLL_CLASS = Constants.RAGDOLL_CLASS
local HEALTH_KEY = Constants.RagdollManager.HEALTH_KEY
local MAX_HEALTH = Constants.RagdollManager.MAX_HEALTH

local Manager = {}

function Manager:GetHealth(ragdoll)
    return store:Get(ragdoll, HEALTH_KEY)
end

function Manager:SetHealth(ragdoll, health)
    return store:Set(ragdoll, HEALTH_KEY, health)
end

function Manager:OnCreate(owner, ragdoll)
    store:SetHealth(ragdoll, MAX_HEALTH)
    LifeCycleHandler:Init(ragdoll)
end

function Manager:OnTakeDamage(ragdoll, dmginfo)
    local dmg = dmginfo:GetDamage()
    local healthBefore = store:Get(ragdoll, HEALTH_KEY)
    local healthAfter = healthBefore - dmg
    store:Set(ragdoll, HEALTH_KEY, healthAfter)
    LifeCycleHandler:DetermineState(ragdoll)
end

hook.Add("CreateEntityRagdoll", Constants.ADDON_NAME .. MODULE_NAME .. "CreateEntityRagdoll", function(owner, ragdoll)
    if not IsValid(owner) then return end
    if not IsValid(ragdoll) or not ragdoll:GetClass() == RAGDOLL_CLASS then return end
    Manager:OnCreate(owner, ragdoll)
end)

hook.Add("PostEntityTakeDamage", Constants.ADDON_NAME .. MODULE_NAME .. "PostEntityTakeDamage",
    function(ent, dmginfo, wasDamageTaken)
        if not wasDamageTaken then return end
        if not IsValid(ent) or not ent:IsRagdoll() or not ent:GetClass() == RAGDOLL_CLASS then return end
        Manager:OnTakeDamage(ent, dmginfo)
    end)
