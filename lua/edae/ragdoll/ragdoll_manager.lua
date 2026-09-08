-- lua/edae/ragdoll/ragdoll_manager.lua
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

local Constants           = include("edae/core/constants.lua")
local log                 = include("edae/core/log/init.lua")
local EntityDataStore     = include("edae/core/entity_data_store.lua")
local LifeCycleHandler    = include("edae/state/life_cycle_handler.lua")
local HealthManager       = include("edae/core/health_manager.lua")
local RagdollPoseHelper   = include("edae/playback/pose_helper.lua")
local PlaybackCoordinator = include("edae/playback/playback_coordinator.lua")
local VoiceManager        = include("edae/ragdoll/voice_manager.lua")
local ReviveManager       = include("edae/ragdoll/revive_manager.lua")
local HoldWoundOverlay    = include("edae/overlay/hold_wound.lua")

local store               = EntityDataStore:ForOwner(MODULE_NAME)

local STATE_ENUM          = Constants.LifeCycleHandler.STATE_ENUM
local PlaybackReasons     = Constants.PlaybackReasons
local Events              = Constants.Events

local Manager             = {}

-- ============================================================
-- 对外委托接口
-- ============================================================

--- 获取布娃娃血量
--- @param ragdoll Entity
--- @return number
function Manager:GetHealth(ragdoll)
    return HealthManager:Get(ragdoll)
end

--- 设置布娃娃血量
--- @param ragdoll Entity
--- @param health number
--- @return boolean
function Manager:SetHealth(ragdoll, health)
    return HealthManager:Set(ragdoll, health)
end

--- 判断布娃娃是否面朝上
--- @param ragdoll Entity
--- @return boolean
function Manager:IsFacingUp(ragdoll)
    return RagdollPoseHelper:IsFacingUp(ragdoll)
end

-- ============================================================
-- 自救/取消自救接口（由 PlayerProxy 调用）
-- ============================================================

--- 请求开始自救
--- @param ply Player
function Manager:RequestSelfRevive(ply)
    if not IsValid(ply) or ply:Alive() then return end
    local ragdoll = ply:GetRagdollEntity()
    if not IsValid(ragdoll) then return end

    PlaybackCoordinator:Stop(ragdoll, PlaybackReasons.InterruptedBySelfRevive)
end

--- 取消自救
--- @param ply Player
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
function Manager:OnCreate(owner, ragdoll, damageContext, initState, probTable)
    if not IsValid(owner) then
        log.warn("Manager:OnCreate - owner is invalid, aborting")
        return
    end
    if not IsValid(ragdoll) then
        log.warn("Manager:OnCreate - ragdoll is invalid, aborting")
        return
    end
    log.trace("Manager:OnCreate - both owner and ragdoll are valid")

    -- 存储所有者
    store:Set(ragdoll, Constants.RagdollManager.OWNER_KEY, owner)
    log.trace("Manager:OnCreate - stored owner in EntityDataStore")

    -- 初始化血量
    HealthManager:Set(ragdoll, Constants.RagdollManager.MAX_HEALTH)
    log.trace("Manager:OnCreate - initialized health to ", Constants.RagdollManager.MAX_HEALTH)

    -- 存储概率表供 LifeCycleHandler 后续使用
    if probTable and type(probTable) == "table" then
        store:Set(ragdoll, "ProbTable", probTable)
        log.trace("Manager:OnCreate - stored probTable for ragdoll ", ragdoll)
    else
        log.trace("Manager:OnCreate - no probTable provided, skipping storage")
    end

    -- 初始化生命周期状态（initState 可能为 nil，LifeCycleHandler 会回退到 FALLING）
    log.trace("Manager:OnCreate - calling LifeCycleHandler:Init with initState=", tostring(initState))
    LifeCycleHandler:Init(ragdoll, initState)
    log.trace("Manager:OnCreate - LifeCycleHandler:Init completed")

    if initState ~= STATE_ENUM.DEAD then
        PlaybackCoordinator:Start(owner, ragdoll, initState, damageContext)
    end

    -- 触发布娃娃初始化完成事件
    log.trace("Manager:OnCreate - firing OnRagdollInitialized event")
    hook.Run(Events.OnRagdollInitialized, ragdoll, owner)
end

--- @param ragdoll Entity Ragdoll
--- @param data table | nil
function Manager:OnTakeDamage(ragdoll, data)
    if not IsValid(ragdoll) then return end
    if not data then return end

    local owner = store:Get(ragdoll, Constants.RagdollManager.OWNER_KEY)
    local currentState = LifeCycleHandler:GetState(ragdoll)

    if (currentState == STATE_ENUM.CRAWLING or currentState == STATE_ENUM.DROWNING) and
        IsValid(owner) then
        VoiceManager:PlayDamageSound(owner)
    end

    local damage = data.finalDamage or 0
    local died = HealthManager:Damage(ragdoll, damage)
    if data.hitBone and damage > 30 then
        PlaybackCoordinator:SetBoneSkip(ragdoll, data.hitBone, true, false)
    end

    if currentState == STATE_ENUM.WRITHING and RagdollPoseHelper:IsFacingUp(ragdoll) and data.hitPos and data.hitPhysID then
        HoldWoundOverlay:Start(ragdoll, data.hitPos, data.hitPhysID)
    end

    if died then
        PlaybackCoordinator:Stop(ragdoll, PlaybackReasons.InterruptedByHealthDepleted)
    end
end

--- 状态变化响应：只启动新播放，不停止旧播放
--- @param ragdoll Entity
--- @param state string
--- @param fromState string|nil
function Manager:OnStateChange(ragdoll, state, fromState)
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

    -- 启动新播放
    PlaybackCoordinator:Start(owner, ragdoll, state, nil)
end

-- ============================================================
-- 事件订阅
-- ============================================================

---comment
---@param owner Entity
---@param ragdoll Entity
---@param damageContext table | nil
---@param decision string
---@param probTable table | nil
local function handlePostCreateRagdoll(owner, ragdoll, damageContext, decision, probTable)
    if not IsValid(owner) then
        log.warn("RagdollManager: handlePostCreateRagdoll - owner is invalid, aborting")
        return
    end
    if not IsValid(ragdoll) then
        log.warn("RagdollManager: handlePostCreateRagdoll - ragdoll is invalid, aborting")
        return
    end
    log.trace("RagdollManager: handlePostCreateRagdoll - both ragdoll and owner are valid")

    --- 定义初始化函数（供外部接管时调用）
    ---@param overrideState string | nil
    ---@param overrideProbTable table | nil
    local function initFunc(overrideState, overrideProbTable)
        log.trace("RagdollManager: initFunc called with overrideState=", tostring(overrideState),
            ", overrideProbTable=", tostring(overrideProbTable))
        Manager:OnCreate(owner, ragdoll, damageContext, overrideState or decision, overrideProbTable or probTable)
    end

    log.trace("RagdollManager: firing PreRagdollInitialized hook...")
    local result = hook.Run(
        Events.PreRagdollInitialized,
        owner,
        ragdoll,
        damageContext,
        decision,
        probTable,
        initFunc
    )
    log.trace("RagdollManager: PreRagdollInitialized hook returned: ", tostring(result))

    if result == true then
        log.trace("RagdollManager: initialization taken over by external handler, skipping default init")
        return
    end

    -- 否则按 ME 的建议初始化
    local initState = STATE_ENUM.FALLING -- 安全回退
    log.trace("RagdollManager: default init, decision from ME = ", tostring(decision))

    -- 验证 decision 是否是有效的 STATE_ENUM
    if decision and table.HasValue(STATE_ENUM, decision) then
        initState = decision
        log.trace("RagdollManager: using valid decision '", decision, "' as initState")
    else
        log.warn("RagdollManager: invalid decision '" .. tostring(decision) .. "', using FALLING")
    end
    log.trace("RagdollManager: calling initFunc with initState=", initState, " and probTable=",
        probTable and "provided" or "nil")

    Manager:OnCreate(owner, ragdoll, damageContext, initState, probTable)
end

hook.Add(Events.PostCreateRagdoll, Constants.ADDON_NAME .. MODULE_NAME .. "PostCreateRagdoll",
    function(owner, ragdoll, damageContext, decision, probTable)
        handlePostCreateRagdoll(owner, ragdoll, damageContext, decision, probTable)
    end)

hook.Add(Events.OnRagdollStateChange, Constants.ADDON_NAME .. MODULE_NAME .. "OnRagdollStateChange",
    function(ragdoll, state, fromState)
        Manager:OnStateChange(ragdoll, state, fromState)
    end)

hook.Add(Events.PostRagdollTakeDamage, Constants.ADDON_NAME .. MODULE_NAME .. "PostRagdollTakeDamage",
    function(ragdoll, data)
        Manager:OnTakeDamage(ragdoll, data)
    end)

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = Manager
return Manager
