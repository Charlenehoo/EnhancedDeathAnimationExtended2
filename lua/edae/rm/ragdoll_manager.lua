-- lua/edae/rm/ragdoll_manager.lua
-- 布娃娃管理器（门面）：负责协调布娃娃生命周期中的各个模块
-- 只处理事件入口和模块间协作，具体业务逻辑委托给辅助模块

local MODULE_NAME = "RagdollManager"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants                   = include("edae/config/constants.lua")
local log                         = include("edae/log/init.lua")
local EntityDataStore             = include("edae/eds/entity_data_store.lua")
local DamageContextManager        = include("edae/dcm/damage_context_manager.lua")
local LifeCycleHandler            = include("edae/lch/life_cycle_handler.lua")
local RagdollHealthManager        = include("edae/rm/health_manager.lua")
local RagdollPoseHelper           = include("edae/rm/pose_helper.lua")
local AnimationPlaybackController = include("edae/rm/playback_controller.lua")
local AnimationPlayer             = include("edae/ap/animation_player.lua")
local VoiceManager                = include("edae/rm/voice_manager.lua") -- 新增

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
-- 事件处理方法
-- ============================================================

--- 布娃娃创建时初始化
function Manager:OnCreate(owner, ragdoll)
    if not IsValid(owner) or not IsValid(ragdoll) then return end

    -- 存储 owner 到 EntityDataStore，方便后续使用（例如受击音效）
    EntityDataStore:Set(ragdoll, "Owner", owner)

    -- 初始化血量
    local currentHealth = RagdollHealthManager:Get(ragdoll)
    if currentHealth == nil then
        RagdollHealthManager:Set(ragdoll, Constants.RagdollManager.MAX_HEALTH)
    end

    -- 获取伤害上下文
    local damageContext = DamageContextManager:Get(owner)

    -- 初始化生命周期（进入 FALLING 状态）
    local state = LifeCycleHandler:Init(ragdoll, damageContext)

    -- 播放对应状态的动画
    AnimationPlaybackController:PlayForState(ragdoll, state, damageContext, owner)

    -- 触发初始化完成事件（供外部模块如 NPC Monitor 使用）
    hook.Run(Events.OnRagdollInitialized, ragdoll, owner)
end

--- 布娃娃受到伤害
function Manager:OnTakeDamage(ragdoll, dmginfo)
    if not IsValid(ragdoll) or not dmginfo then return end

    -- 获取所有者（在 OnCreate 时已存储）
    local owner = EntityDataStore:Get(ragdoll, "Owner")

    -- 播放受击音效（统一使用 crithit）
    if IsValid(owner) then
        VoiceManager:PlayDamageSound(owner)
    end

    local damage = dmginfo:GetDamage()
    local died = RagdollHealthManager:Damage(ragdoll, damage)

    if died then
        -- 血量归零，强制进入 DEAD 状态
        LifeCycleHandler:SetState(ragdoll, STATE_ENUM.DEAD)
        -- 死亡时停止所有语音
        VoiceManager:StopAll(owner)
    else
        -- 血量未归零，可让生命周期处理器根据当前状态做进一步判断（通常无操作）
        LifeCycleHandler:DetermineState(ragdoll)
    end
end

--- 布娃娃状态改变（由 LifeCycleHandler 触发事件）
function Manager:OnStateChange(ragdoll, state)
    if not IsValid(ragdoll) then return end

    -- 停止当前动画
    AnimationPlayer:Stop(ragdoll)

    -- DEAD 状态无需播放动画
    if state == STATE_ENUM.DEAD then
        -- 可选：此处也可调用 VoiceManager:StopAll(owner)，但已在 OnTakeDamage 中处理
        return
    end

    -- 获取所有者（用于语音效果器）
    local owner = EntityDataStore:Get(ragdoll, "Owner")

    -- 播放新状态的动画（此处的 owner 和 damageContext 未知，传 nil）
    -- 对于非 FALLING 状态，yaw 计算不依赖 owner，所以是安全的
    AnimationPlaybackController:PlayForState(ragdoll, state, nil, owner)
end

-- ============================================================
-- 事件订阅
-- ============================================================

hook.Add(Events.OnRagdollStateChange, Constants.ADDON_NAME .. MODULE_NAME .. Events.OnRagdollStateChange,
    function(ragdoll, state)
        if not IsValid(ragdoll) then return end
        Manager:OnStateChange(ragdoll, state)
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

-- 注册单例
_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = Manager
return Manager
