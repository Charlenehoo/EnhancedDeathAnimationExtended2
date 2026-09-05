-- lua/edae/rm/ragdoll_manager.lua
-- 布娃娃管理器（门面）：负责协调布娃娃生命周期中的各个模块
-- 职责：
--   1. 监听原始游戏事件（创建、伤害、网络消息），翻译为停止原因并调用 PlaybackCoordinator:Stop
--   2. 监听状态变化事件（OnRagdollStateChange），只启动新播放，不停止旧播放
--   3. 对外提供自救请求/取消接口
--   4. 复活逻辑委托给 ReviveManager
-- 注意：DropItem 和 FlexPlayer 功能已迁移至独立扩展模块（di 和 fp），
--       它们通过自注册事件钩子工作，不再由此模块直接调用。

local MODULE_NAME = "RagdollManager"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants            = include("edae/config/constants.lua")
local log                  = include("edae/log/init.lua")
local EntityDataStore      = include("edae/eds/entity_data_store.lua")
local DamageContextManager = include("edae/damage_context_manager.lua")
local LifeCycleHandler     = include("edae/life_cycle_handler.lua")
local HealthManager        = include("edae/rm/health_manager.lua")
local RagdollPoseHelper    = include("edae/rm/pose_helper.lua")
local PlaybackCoordinator  = include("edae/rm/playback_coordinator.lua")
local VoiceManager         = include("edae/rm/voice_manager.lua")
local ReviveManager        = include("edae/rm/revive_manager.lua")

local store                = EntityDataStore:ForOwner(MODULE_NAME)

local STATE_ENUM           = Constants.LifeCycleHandler.STATE_ENUM
local PlaybackReasons      = Constants.PlaybackReasons
local Events               = Constants.Events

local Manager              = {}

-- ============================================================
-- 对外委托接口
-- ============================================================

function Manager:GetHealth(ragdoll)
    return HealthManager:Get(ragdoll)
end

function Manager:SetHealth(ragdoll, health)
    return HealthManager:Set(ragdoll, health)
end

function Manager:IsFacingUp(ragdoll)
    return RagdollPoseHelper:IsFacingUp(ragdoll)
end

-- ============================================================
-- 自救/取消自救接口（由 PlayerProxy 调用）
-- ============================================================

function Manager:RequestSelfRevive(ply)
    if not IsValid(ply) or ply:Alive() then return end
    local ragdoll = ply:GetRagdollEntity()
    if not IsValid(ragdoll) then return end

    PlaybackCoordinator:Stop(ragdoll, PlaybackReasons.InterruptedBySelfRevive)
end

function Manager:CancelSelfRevive(ply)
    if not IsValid(ply) or ply:Alive() then return end
    local ragdoll = ply:GetRagdollEntity()
    if not IsValid(ragdoll) then return end

    PlaybackCoordinator:Stop(ragdoll, PlaybackReasons.Cancelled)
end

-- ============================================================
-- 事件处理方法
-- ============================================================

--- 布娃娃创建时初始化
function Manager:OnCreate(owner, ragdoll, initState)
    if not IsValid(owner) or not IsValid(ragdoll) then return end

    local damageContext = DamageContextManager:Get(owner)
    DamageContextManager:Clear(owner)

    store:Set(ragdoll, Constants.RagdollManager.OWNER_KEY, owner)
    HealthManager:Set(ragdoll, Constants.RagdollManager.MAX_HEALTH)

    -- initState 若未提供则默认为 nil，LifeCycleHandler:Init 会回退到 FALLING
    LifeCycleHandler:Init(ragdoll, initState, damageContext)

    hook.Run(Events.OnRagdollInitialized, ragdoll, owner)
end

--- 布娃娃受到伤害
function Manager:OnTakeDamage(ragdoll, dmginfo)
    if not IsValid(ragdoll) or not dmginfo then return end

    local owner = store:Get(ragdoll, Constants.RagdollManager.OWNER_KEY)
    local currentState = LifeCycleHandler:GetState(ragdoll)

    -- 爬行状态受击播放音效
    if currentState == STATE_ENUM.CRAWLING and IsValid(owner) then
        VoiceManager:PlayDamageSound(owner)
    end

    local damage = dmginfo:GetDamage()
    local died = HealthManager:Damage(ragdoll, damage)

    if died then
        PlaybackCoordinator:Stop(ragdoll, PlaybackReasons.InterruptedByHealthDepleted)
    end
end

--- 状态变化响应：只启动新播放，不停止旧播放
function Manager:OnStateChange(ragdoll, state, fromState, initData)
    if not IsValid(ragdoll) then return end

    local owner = store:Get(ragdoll, Constants.RagdollManager.OWNER_KEY)

    -- 语音处理
    if state == STATE_ENUM.DEAD then
        VoiceManager:StopAll(owner)
        if fromState == STATE_ENUM.CRAWLING then
            VoiceManager:PlayDeathSound(owner)
        end
    else
        VoiceManager:StopAll(owner)
    end

    if state == STATE_ENUM.DEAD then
        return -- 死亡不播放
    end

    -- 玩家相机模式：默认 false，可根据实际需求从上层传入
    local isPlayerCameraMode = false

    -- 启动新播放
    PlaybackCoordinator:Start(ragdoll, state, initData, owner, isPlayerCameraMode)
end

-- ============================================================
-- 事件订阅
-- ============================================================

-- 状态变化
hook.Add(Events.OnRagdollStateChange, MODULE_NAME .. "_OnRagdollStateChange",
    function(ragdoll, state, fromState, initData)
        if not IsValid(ragdoll) then return end
        Manager:OnStateChange(ragdoll, state, fromState, initData)
    end)

-- 布娃娃创建
hook.Add("CreateEntityRagdoll", MODULE_NAME .. "_CreateEntityRagdoll", function(owner, ragdoll)
    if not IsValid(owner) or not IsValid(ragdoll) then return end
    if ragdoll:GetClass() ~= Constants.RAGDOLL_CLASS then return end

    -- 构造初始化函数，外部可调用并传入自定义初始状态
    local function initFunc(initState)
        Manager:OnCreate(owner, ragdoll, initState)
    end

    -- 触发预初始化事件，传递 initFunc 供外部使用
    local result = hook.Run(Constants.Events.PreRagdollInitialized, owner, ragdoll, initFunc)

    -- 外部返回 true 表示接管初始化，不再自动执行
    if result == true then
        return
    end

    initFunc()
end)

-- 布娃娃受到伤害
hook.Add("PostEntityTakeDamage", MODULE_NAME .. "_PostEntityTakeDamage", function(ent, dmginfo, wasDamageTaken)
    if not wasDamageTaken then return end
    if not IsValid(ent) or not ent:IsRagdoll() or ent:GetClass() ~= Constants.RAGDOLL_CLASS then return end
    Manager:OnTakeDamage(ent, dmginfo)
end)

-- 复活请求已由 ReviveManager 监听处理，此处不再重复注册

-- 注册单例
_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = Manager
return Manager
