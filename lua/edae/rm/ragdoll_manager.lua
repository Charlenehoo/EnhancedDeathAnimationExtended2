-- lua/edae/rm/ragdoll_manager.lua
-- 布娃娃管理器（门面）：负责协调布娃娃生命周期中的各个模块
-- 本模块只负责：
--   1. 响应状态变化事件，停止旧动画并启动新动画（通过 AnimationPlaybackController）
--   2. 监听复活请求事件，执行实际复活（PerformRevive）
--   3. 提供对外的自救请求/取消接口，内部委托给 LifeCycleHandler
-- 所有状态决策逻辑均在 LifeCycleHandler 中

local MODULE_NAME = "RagdollManager"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants                   = include("edae/config/constants.lua")
local log                         = include("edae/log/init.lua")
local EntityDataStore             = include("edae/eds/entity_data_store.lua")
local DamageContextManager        = include("edae/damage_context_manager.lua")
local LifeCycleHandler            = include("edae/lch/life_cycle_handler.lua")
local RagdollHealthManager        = include("edae/rm/health_manager.lua")
local RagdollPoseHelper           = include("edae/rm/pose_helper.lua")
local AnimationPlaybackController = include("edae/rm/playback_controller.lua")
local AnimationPlayer             = include("edae/ap/animation_player.lua")
local TwitchController            = include("edae/tc/twitch_controller.lua")
local VoiceManager                = include("edae/rm/voice_manager.lua")

local store                       = EntityDataStore:ForOwner(MODULE_NAME)

local STATE_ENUM                  = Constants.LifeCycleHandler.STATE_ENUM
local Events                      = Constants.Events

local Manager                     = {}

-- ============================================================
-- 对外委托接口（保留部分常用方法，方便外部调用）
-- ============================================================

--- 获取布娃娃血量
function Manager:GetHealth(ragdoll)
    return RagdollHealthManager:Get(ragdoll)
end

--- 设置布娃娃血量
function Manager:SetHealth(ragdoll, health)
    return RagdollHealthManager:Set(ragdoll, health)
end

--- 判断布娃娃是否面朝上
function Manager:IsFacingUp(ragdoll)
    return RagdollPoseHelper:IsFacingUp(ragdoll)
end

-- ============================================================
-- 自救接口（对外，内部委托给 LifeCycleHandler）
-- ============================================================

--- 请求开始自救
--- @param ply Player 死亡玩家的实体
function Manager:RequestSelfRevive(ply)
    if not IsValid(ply) or ply:Alive() then return end
    local ragdoll = ply:GetRagdollEntity()
    if not IsValid(ragdoll) then return end

    LifeCycleHandler:RequestSelfRevive(ragdoll)
end

--- 请求取消自救
--- @param ply Player 死亡玩家的实体
function Manager:CancelSelfRevive(ply)
    if not IsValid(ply) or ply:Alive() then return end
    local ragdoll = ply:GetRagdollEntity()
    if not IsValid(ragdoll) then return end

    LifeCycleHandler:CancelSelfRevive(ragdoll)
end

-- ============================================================
-- 复活执行（实际重生玩家）
-- ============================================================

--- 执行真正复活：删除布娃娃，重生玩家，给予短暂无敌
--- @param ragdoll Entity 布娃娃实体
function Manager:PerformRevive(ragdoll)
    if not IsValid(ragdoll) then return end

    local owner = store:Get(ragdoll, "Owner")
    if not IsValid(owner) then
        log.warn("RagdollManager:PerformRevive - owner not found for ragdoll")
        ragdoll:Remove()
        return
    end

    local pos = ragdoll:GetPos()
    local ang = ragdoll:GetAngles()

    ragdoll:Remove()

    owner:Spawn()
    if IsValid(owner) then
        owner:SetPos(pos)
        owner:SetEyeAngles(Angle(0, ang.yaw, 0))
        owner:SetHealth(Constants.RagdollManager.MAX_HEALTH)
        owner:GodEnable()
        timer.Simple(2, function()
            if IsValid(owner) then owner:GodDisable() end
        end)
        log.trace("RagdollManager:PerformRevive - player ", owner, " revived at ", pos)
    else
        log.warn("RagdollManager:PerformRevive - player spawn failed")
    end
end

-- ============================================================
-- 事件处理方法
-- ============================================================

--- 布娃娃创建时初始化
function Manager:OnCreate(owner, ragdoll)
    if not IsValid(owner) or not IsValid(ragdoll) then return end

    store:Set(ragdoll, "Owner", owner)

    local currentHealth = RagdollHealthManager:Get(ragdoll)
    if currentHealth == nil then
        RagdollHealthManager:Set(ragdoll, Constants.RagdollManager.MAX_HEALTH)
    end

    local damageContext = DamageContextManager:Get(owner)
    DamageContextManager:Clear(owner)

    local state = LifeCycleHandler:Init(ragdoll, damageContext)

    AnimationPlaybackController:PlayForState(ragdoll, state, damageContext, owner)

    hook.Run(Events.OnRagdollInitialized, ragdoll, owner)
end

--- 布娃娃受到伤害
function Manager:OnTakeDamage(ragdoll, dmginfo)
    if not IsValid(ragdoll) or not dmginfo then return end

    local owner = store:Get(ragdoll, "Owner")
    local currentState = LifeCycleHandler:GetState(ragdoll)

    if currentState == STATE_ENUM.CRAWLING and IsValid(owner) then
        VoiceManager:PlayDamageSound(owner)
    end

    local damage = dmginfo:GetDamage()
    local died = RagdollHealthManager:Damage(ragdoll, damage)

    if died then
        LifeCycleHandler:SetState(ragdoll, STATE_ENUM.DEAD)
        VoiceManager:StopAll(owner)
    else
        LifeCycleHandler:DetermineState(ragdoll)
    end
end

--- 布娃娃状态改变（由 LifeCycleHandler 触发事件）
--- 职责：停止旧动画，启动新动画（除非新状态为 DEAD）
function Manager:OnStateChange(ragdoll, state, fromState)
    if not IsValid(ragdoll) then return end

    local owner = store:Get(ragdoll, "Owner")

    if fromState == STATE_ENUM.CRAWLING and state == STATE_ENUM.DEAD then
        VoiceManager:PlayDeathSound(owner)
    else
        VoiceManager:StopAll(owner)
    end

    -- 停止当前动画（无论新状态是什么，先停止之前的）
    AnimationPlayer:Stop(ragdoll)
    TwitchController:Stop(ragdoll)

    -- DEAD 状态无需播放动画
    if state == STATE_ENUM.DEAD then
        return
    end

    -- 所有非 DEAD 状态（包括 FALLING、CRAWLING、WRITHING、TWITCHING、SELF_REVIVING、GETTING_UP）
    -- 都通过 AnimationPlaybackController 自动播放对应动画
    AnimationPlaybackController:PlayForState(ragdoll, state, nil, owner)
end

-- ============================================================
-- 监听取消自救请求事件（由 LifeCycleHandler 发出）
-- ============================================================
hook.Add("EDAE_OnSelfReviveCancelRequested", Constants.ADDON_NAME .. MODULE_NAME .. "OnSelfReviveCancelRequested",
    function(ragdoll)
        if not IsValid(ragdoll) then return end
        AnimationPlayer:Cancel(ragdoll)
    end)

-- ============================================================
-- 事件订阅
-- ============================================================

hook.Add(Events.OnRagdollStateChange, Constants.ADDON_NAME .. MODULE_NAME .. Events.OnRagdollStateChange,
    function(ragdoll, state, fromState)
        if not IsValid(ragdoll) then return end
        Manager:OnStateChange(ragdoll, state, fromState)
    end)

hook.Add("CreateEntityRagdoll", Constants.ADDON_NAME .. MODULE_NAME .. "CreateEntityRagdoll",
    function(owner, ragdoll)
        if not IsValid(owner) or not IsValid(ragdoll) then return end
        if ragdoll:GetClass() ~= Constants.RAGDOLL_CLASS then return end
        Manager:OnCreate(owner, ragdoll)
    end)

hook.Add("PostEntityTakeDamage", Constants.ADDON_NAME .. MODULE_NAME .. "PostEntityTakeDamage",
    function(ent, dmginfo, wasDamageTaken)
        if not wasDamageTaken then return end
        if not IsValid(ent) or not ent:IsRagdoll() or ent:GetClass() ~= Constants.RAGDOLL_CLASS then return end
        Manager:OnTakeDamage(ent, dmginfo)
    end)

hook.Add(Constants.Events.OnRagdollHealthChanged, Constants.ADDON_NAME .. MODULE_NAME .. "OnRagdollHealthChanged",
    function(ragdoll, newHealth)
        if not IsValid(ragdoll) then return end
        LifeCycleHandler:DetermineState(ragdoll)
    end)

-- 监听复活请求事件（由 LifeCycleHandler 发出）
hook.Add(Events.OnReviveRequested, Constants.ADDON_NAME .. MODULE_NAME .. "OnReviveRequested",
    function(ragdoll)
        if not IsValid(ragdoll) then return end
        Manager:PerformRevive(ragdoll)
    end)

-- 注册单例
_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = Manager
return Manager
