-- lua/edae/rm/ragdoll_manager.lua
-- 布娃娃管理器（门面）：负责协调布娃娃生命周期中的各个模块
-- 职责：
--   1. 监听自定义事件（OnMortalityEvaluated），评估后初始化布娃娃
--   2. 监听状态变化事件（OnRagdollStateChange），只启动新播放，不停止旧播放
--   3. 对外提供自救请求/取消接口
--   4. 复活逻辑委托给 ReviveManager
-- 注意：所有原生游戏事件（伤害、创建）已由专门模块翻译为领域事件，本模块只依赖领域事件。

local MODULE_NAME = "RagdollManager"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants           = include("edae/config/constants.lua")
local log                 = include("edae/log/init.lua")
local EntityDataStore     = include("edae/eds/entity_data_store.lua")
local LifeCycleHandler    = include("edae/life_cycle_handler.lua")
local HealthManager       = include("edae/rm/health_manager.lua")
local RagdollPoseHelper   = include("edae/rm/pose_helper.lua")
local PlaybackCoordinator = include("edae/rm/playback_coordinator.lua")
local VoiceManager        = include("edae/rm/voice_manager.lua")
local ReviveManager       = include("edae/rm/revive_manager.lua")

local store               = EntityDataStore:ForOwner(MODULE_NAME)

local STATE_ENUM          = Constants.LifeCycleHandler.STATE_ENUM
local PlaybackReasons     = Constants.PlaybackReasons
local Events              = Constants.Events

local Manager             = {}

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

--- 布娃娃创建时初始化（由 OnMortalityEvaluated 事件调用）
--- @param owner Entity 布娃娃所有者（NPC 或玩家）
--- @param ragdoll Entity 布娃娃实体
--- @param initState string|nil 建议的初始状态（"falling" 或 "dead"）
--- @param damageContext table|nil 伤害上下文
--- @param probTable table|nil 状态概率表
function Manager:OnCreate(owner, ragdoll, initState, damageContext, probTable)
    if not IsValid(owner) or not IsValid(ragdoll) then return end

    store:Set(ragdoll, Constants.RagdollManager.OWNER_KEY, owner)
    HealthManager:Set(ragdoll, Constants.RagdollManager.MAX_HEALTH)

    -- 存储概率表供 LifeCycleHandler 后续使用
    if probTable and type(probTable) == "table" then
        store:Set(ragdoll, "ProbTable", probTable)
        log.trace("RagdollManager: stored probTable for ragdoll ", ragdoll)
    end

    -- 初始化生命周期状态（initState 可能为 nil，LifeCycleHandler 会回退到 FALLING）
    LifeCycleHandler:Init(ragdoll, initState, damageContext)

    hook.Run(Events.OnRagdollInitialized, ragdoll, owner)
end

--- 布娃娃受到伤害（由 PostRagdollTakeDamage 事件调用）
--- @param ragdoll Entity 布娃娃实体
--- @param eventData table 由 RagdollDamageProcessor 翻译后的事件数据（不含 ragdoll 和 dmginfo）
function Manager:OnTakeDamage(ragdoll, eventData)
    if not IsValid(ragdoll) then return end

    local owner = store:Get(ragdoll, Constants.RagdollManager.OWNER_KEY)
    local currentState = LifeCycleHandler:GetState(ragdoll)

    -- 爬行状态受击播放音效
    if currentState == STATE_ENUM.CRAWLING and IsValid(owner) then
        VoiceManager:PlayDamageSound(owner, eventData)
    end

    local damage = eventData.finalDamage or 0
    local died = HealthManager:Damage(ragdoll, damage)

    -- 根据命中骨骼禁用动画（示例）
    if eventData.hitBone and damage > 30 then
        PlaybackCoordinator:SetBoneSkip(ragdoll, eventData.hitBone, true, false)
    end

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

-- 1. 监听 MortalityEvaluator 的评估结果
hook.Add(Events.OnMortalityEvaluated, MODULE_NAME .. "_OnMortalityEvaluated",
    function(ragdoll, decision, probTable, damageContext, owner)
        if not IsValid(ragdoll) or not IsValid(owner) then return end

        -- 定义初始化函数（供外部接管时调用）
        local function initFunc(overrideState, overrideProbTable)
            Manager:OnCreate(owner, ragdoll, overrideState or decision, damageContext, overrideProbTable or probTable)
        end

        -- 触发预初始化事件，允许外部接管（如 BSMod）
        -- 额外传递决策、概率表和伤害上下文，供外部参考
        local result = hook.Run(
            Events.PreRagdollInitialized,
            owner,
            ragdoll,
            initFunc,
            decision,
            probTable,
            damageContext
        )

        -- 如果外部返回 true，说明已接管，不再执行默认初始化
        if result == true then
            log.trace("RagdollManager: initialization taken over by external handler")
            return
        end

        -- 否则按 ME 的建议初始化
        local initState = STATE_ENUM.FALLING -- 安全回退

        -- 验证 decision 是否是有效的 STATE_ENUM
        if decision and table.HasValue(STATE_ENUM, decision) then
            initState = decision
        else
            log.warn("RagdollManager: invalid decision '" .. tostring(decision) .. "', using FALLING")
        end
        Manager:OnCreate(owner, ragdoll, initState, damageContext, probTable)
    end)

-- 2. 状态变化
hook.Add(Events.OnRagdollStateChange, MODULE_NAME .. "_OnRagdollStateChange",
    function(ragdoll, state, fromState, initData)
        if not IsValid(ragdoll) then return end
        Manager:OnStateChange(ragdoll, state, fromState, initData)
    end)

-- 3. 布娃娃受到伤害（由 RagdollDamageProcessor 触发的自定义事件）
hook.Add(Events.PostRagdollTakeDamage, MODULE_NAME .. "_OnPostRagdollTakeDamage", function(ragdoll, eventData)
    if not IsValid(ragdoll) or not eventData then return end
    Manager:OnTakeDamage(ragdoll, eventData)
end)

-- 4. 复活请求已由 ReviveManager 监听处理，此处不再重复注册

-- 注册单例
_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = Manager
return Manager
