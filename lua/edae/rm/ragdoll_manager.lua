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

--- 判断布娃娃是否面朝上
--- @param ragdoll Entity
--- @return boolean true = 面朝上, false = 面朝下
function Manager:IsFacingUp(ragdoll)
    if not IsValid(ragdoll) then return false end

    local chestAttach = ragdoll:LookupAttachment("chest")
    local eyesAttach  = ragdoll:LookupAttachment("eyes")

    if chestAttach and chestAttach > 0 then
        local chestAng = ragdoll:GetAttachment(chestAttach).Ang
        if chestAng then
            return chestAng:Forward().z >= 0
        end
    end

    if eyesAttach and eyesAttach > 0 then
        local eyesAng = ragdoll:GetAttachment(eyesAttach).Ang
        if eyesAng then
            return eyesAng:Forward().z >= 0
        end
    end

    -- 默认视为面朝下
    return false
end

function Manager:GetYawForState(owner, ragdoll, state)
    if not IsValid(owner) or not IsValid(ragdoll) then return 0 end

    if state == Constants.LifeCycleHandler.STATE_ENUM.FALLING then
        -- 死亡倒地动画：布娃娃刚生成，尚未倒地，实体角度即可反映躯干朝向
        return owner:GetAngles().yaw
    else
        -- 爬行/挣扎动画：布娃娃已躺倒，需从胸部骨骼提取水平偏航
        local spineBone = ragdoll:LookupBone("ValveBiped.Bip01_Spine4")
            or ragdoll:LookupBone("ValveBiped.Bip01_Spine2")
            or ragdoll:LookupBone("ValveBiped.Bip01_Spine1")
            or ragdoll:LookupBone("ValveBiped.Bip01_Spine")

        if spineBone then
            local matrix = ragdoll:GetBoneMatrix(spineBone)
            if matrix then
                local angles = matrix:GetAngles()
                if angles then
                    local forward = angles:Forward()
                    if forward then
                        return forward:Angle().y
                    end
                end
            end
        end

        -- 回退到实体角度
        return ragdoll:GetAngles().yaw
    end
end

function Manager:PlayAnimationForState(ragdoll, state, damageContext)
    local yaw = self:GetYawForState(ragdoll, state)

    local playBackInfo = {
        state = state,
        damageContext = damageContext,
        isFacingUp = self:IsFacingUp(ragdoll),
        yaw = yaw, -- 可选：传递给选择器，虽然目前未使用
    }
    local playbackData = AnimationSelector:Select(playBackInfo)
    if not playbackData then
        log.warn("AnimationSelector returned no playback data for state: ", state)
        return
    end

    local opts = {
        totalLoops = playbackData.totalLoops,
        preWait = playbackData.preWait,
        yaw = yaw, -- 关键：将计算好的 yaw 传给 AnimationPlayer
    }

    AnimationPlayer:Play(ragdoll, playbackData.animationName, opts)
end

function Manager:OnCreate(owner, ragdoll)
    local healthBefore = self:GetHealth(ragdoll)
    self:SetHealth(ragdoll, healthBefore or MAX_HEALTH)

    local damageContext = DamageContextManager:Get(owner)
    local state = LifeCycleHandler:Init(ragdoll, damageContext)

    self:PlayAnimationForState(ragdoll, state, damageContext)

    hook.Run(Constants.Events.OnRagdollInitialized, ragdoll, owner)
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
    AnimationPlayer:Stop(ragdoll)
    if state == STATE_ENUM.DEAD then return end

    self:PlayAnimationForState(ragdoll, state, nil) -- 状态切换时无伤害上下文
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
