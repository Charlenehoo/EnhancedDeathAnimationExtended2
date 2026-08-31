-- lua\edae\rm\ragdoll_manager.lua

local MODULE_NAME = "RagdollManager"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants = include("edae/config/constants.lua")
local log = include("edae/log/init.lua")
local EntityDataStore = include("edae/eds/entity_data_store.lua")
local DamageContextManager = include("edae/dcm/damage_context_manager.lua")
local AnimationSelector = include("edae/as/animation_selector.lua")
local AnimationPlayer = include("edae/ap/animation_player.lua")
local LifeCycleHandler = include("edae/lch/life_cycle_handler.lua")

local store = EntityDataStore:ForOwner(MODULE_NAME)
local RAGDOLL_CLASS = Constants.RAGDOLL_CLASS
local HEALTH_KEY = Constants.RagdollManager.HEALTH_KEY
local MAX_HEALTH = Constants.RagdollManager.MAX_HEALTH
local Events = Constants.Events
local STATE_ENUM = Constants.LifeCycleHandler.STATE_ENUM

local Manager = {}

function Manager:GetHealth(ragdoll)
    return store:Get(ragdoll, HEALTH_KEY)
end

function Manager:SetHealth(ragdoll, health)
    return store:Set(ragdoll, HEALTH_KEY, health)
end

-- ======================================

function Manager:OnCreate(owner, ragdoll)
    local healthBefore = self:GetHealth(ragdoll)
    self:SetHealth(ragdoll, healthBefore or MAX_HEALTH)
    local damageContext = DamageContextManager:Get(owner)
    local state = LifeCycleHandler:Init(ragdoll, damageContext)
    local animationName, totalLoops, secondsBeforePlay = AnimationSelector:Select(state, damageContext)
    local opts = {}
    opts.totalLoops = totalLoops
    opts.secondsBeforePlay = secondsBeforePlay
    AnimationPlayer:Play(ragdoll, animationName, opts)
end

function Manager:OnTakeDamage(ragdoll, dmginfo)
    local dmg = dmginfo:GetDamage()
    local healthBefore = self:GetHealth(ragdoll)
    healthBefore = healthBefore or MAX_HEALTH
    local healthAfter = healthBefore - dmg
    self:SetHealth(ragdoll, healthAfter)
    LifeCycleHandler:DetermineState(ragdoll)
end

function Manager:OnStateChange(ragdoll, state)
    if AnimationPlayer:IsPlaying(ragdoll) then
        AnimationPlayer:Stop(ragdoll)
    end
    if state == STATE_ENUM.DEAD then return end
    local animationName, totalLoops, secondsBeforePlay = AnimationSelector:Select(state, nil)
    local opts = {}
    opts.totalLoops = totalLoops
    opts.secondsBeforePlay = secondsBeforePlay
    AnimationPlayer:Play(ragdoll, animationName, opts)
end

-- ======================================

hook.Add(Events.OnRagdollStateChange, Constants.ADDON_NAME .. MODULE_NAME .. Events.OnRagdollStateChange,
    function(ragdoll, state)
        if not IsValid(ragdoll) then return end
        Manager:OnStateChange(ragdoll, state)
    end)

hook.Add("CreateEntityRagdoll", Constants.ADDON_NAME .. MODULE_NAME .. "CreateEntityRagdoll", function(owner, ragdoll)
    if not IsValid(owner) then return end
    if not IsValid(ragdoll) or ragdoll:GetClass() ~= RAGDOLL_CLASS then return end
    Manager:OnCreate(owner, ragdoll)
end)

hook.Add("PostEntityTakeDamage", Constants.ADDON_NAME .. MODULE_NAME .. "PostEntityTakeDamage",
    function(ent, dmginfo, wasDamageTaken)
        if not wasDamageTaken then return end
        if not IsValid(ent) or not ent:IsRagdoll() or ent:GetClass() ~= RAGDOLL_CLASS then return end
        Manager:OnTakeDamage(ent, dmginfo)
    end)

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = Manager
return Manager
