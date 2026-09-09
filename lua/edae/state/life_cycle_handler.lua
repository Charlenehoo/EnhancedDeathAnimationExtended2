-- lua/edae/state/life_cycle_handler.lua
-- 生命周期状态机：管理 Ragdoll 的状态转移
-- 纯逻辑模块，只监听 OnPlaybackStopped 事件，根据原因和当前状态查表转移
-- 不直接操作播放器、血量或任何外部资源；不对外暴露 SetState
-- 所有状态变化均通过内部 setState 完成，并触发 OnRagdollStateChange 事件

local MODULE_NAME = "LifeCycleHandler"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants          = include("edae/core/constants.lua")
local log                = include("edae/core/log/init.lua")
local EntityDataStore    = include("edae/core/entity_data_store.lua")

local store              = EntityDataStore:ForOwner(MODULE_NAME)

local STATE_KEY          = Constants.LifeCycleHandler.STATE_KEY
local STATE_ENUM         = Constants.LifeCycleHandler.STATE_ENUM
local PREVIOUS_STATE_KEY = "PreviousState"

local CRAWL_CHANCE       = Constants.LifeCycleHandler.CRAWL_CHANCE
local WRITHE_CHANCE      = Constants.LifeCycleHandler.WRITHE_CHANCE
local TWITCH_CHANCE      = Constants.LifeCycleHandler.TWITCH_CHANCE

local PlaybackReasons    = Constants.PlaybackReasons

local LifeCycleHandler   = {}

local defaultProbTable   = {
    [STATE_ENUM.CRAWLING]  = Constants.LifeCycleHandler.CRAWL_CHANCE,
    [STATE_ENUM.WRITHING]  = Constants.LifeCycleHandler.WRITHE_CHANCE,
    [STATE_ENUM.TWITCHING] = Constants.LifeCycleHandler.TWITCH_CHANCE,
    [STATE_ENUM.DEAD]      = 1 - (Constants.LifeCycleHandler.CRAWL_CHANCE +
        Constants.LifeCycleHandler.WRITHE_CHANCE +
        Constants.LifeCycleHandler.TWITCH_CHANCE),
}

--- 根据概率表随机选择一个状态
--- 概率表应为绝对概率，所有值之和应 <= 1，剩余概率自动归为 DEAD
--- 若概率表无效（非表、包含负数、包含未知状态、总和为 0），返回 nil
--- @param probTable table|nil 状态 -> 概率 的映射
--- @return string|nil 选中的状态，若概率表无效则返回 nil
local function selectStateByProbTable(probTable)
    -- 校验：概率表必须是表
    if type(probTable) ~= "table" then
        log.warn("selectStateByProbTable: probTable is not a table, got ", type(probTable))
        return nil
    end

    -- 校验：每个状态必须有效，概率必须是非负数
    local total = 0
    for state, prob in pairs(probTable) do
        if type(prob) ~= "number" or prob < 0 then
            log.warn("selectStateByProbTable: invalid probability for state '", tostring(state), "' = ", tostring(prob))
            return nil
        end
        if not table.HasValue(STATE_ENUM, state) then
            log.warn("selectStateByProbTable: unknown state key '", tostring(state), "' in probTable")
            return nil
        end
        total = total + prob
    end

    -- 总和必须大于 0，否则无法选择
    if total <= 0 then
        log.warn("selectStateByProbTable: total probability is zero or negative, cannot select state")
        return nil
    end

    -- 生成 [0, 1) 的随机数
    local rand = math.random()

    -- 按顺序累加概率，找到随机数落入的区间
    local cumulative = 0
    for state, prob in pairs(probTable) do
        cumulative = cumulative + prob
        if rand < cumulative then
            return state
        end
    end

    -- 若随机数超过了所有列出概率的总和（即总和 < 1），剩余概率归为 DEAD
    return STATE_ENUM.DEAD
end

--- 获取当前状态
--- @param ragdoll Entity
--- @return string
local function getState(ragdoll)
    return store:Get(ragdoll, STATE_KEY) or STATE_ENUM.FALLING
end

--- 保存前一状态
--- @param ragdoll Entity
--- @param oldState string
local function savePreviousState(ragdoll, oldState)
    store:Set(ragdoll, PREVIOUS_STATE_KEY, oldState)
end

--- 获取前一状态
--- @param ragdoll Entity
--- @return string|nil
local function getPreviousState(ragdoll)
    return store:Get(ragdoll, PREVIOUS_STATE_KEY)
end

--- 内部设置状态，并触发事件
--- @param ragdoll Entity
--- @param newState string
local function setState(ragdoll, newState)
    local oldState = getState(ragdoll)
    if oldState == newState then
        return
    end

    -- 保存前一状态（用于自救取消恢复）
    savePreviousState(ragdoll, oldState)

    store:Set(ragdoll, STATE_KEY, newState)

    hook.Run(Constants.Events.OnRagdollStateChange, ragdoll, newState, oldState)
end

--- 初始化 Ragdoll 状态
--- @param ragdoll Entity 布娃娃实体
--- @param initState string|nil 初始状态，默认为 STATE_ENUM.FALLING
function LifeCycleHandler:Init(ragdoll, initState)
    if not IsValid(ragdoll) then
        log.warn("LifeCycleHandler:Init invalid ragdoll")
        return
    end

    initState = initState or STATE_ENUM.FALLING
    if not table.HasValue(STATE_ENUM, initState) then
        log.warn("LifeCycleHandler:Init invalid initState '", tostring(initState), "', falling back to 'falling'")
        initState = STATE_ENUM.FALLING
    end

    store:Set(ragdoll, STATE_KEY, initState)
    log.trace("LifeCycleHandler: initialized ragdoll ", ragdoll, " with state '", initState, "'")
    -- 不触发 OnRagdollStateChange 事件，由 RagdollManager 在创建后直接启动初始播放
end

-- 获取当前状态（供外部查询）
function LifeCycleHandler:GetState(ragdoll)
    if not IsValid(ragdoll) then return nil end
    return getState(ragdoll)
end

-- 获取前一状态（供外部查询，如调试）
function LifeCycleHandler:GetPreviousState(ragdoll)
    if not IsValid(ragdoll) then return nil end
    return getPreviousState(ragdoll)
end

--- 处理播放停止事件，根据原因和当前状态转移
--- @param ragdoll Entity
--- @param reason string 停止原因
function LifeCycleHandler:HandleEvent(ragdoll, reason)
    if not IsValid(ragdoll) then return end

    local currentState = getState(ragdoll)
    if currentState == STATE_ENUM.DEAD then
        return -- DEAD 状态忽略所有事件
    end

    local newState = nil

    -- 血量耗尽：任何非 DEAD 状态直接死亡
    if reason == PlaybackReasons.InterruptedByHealthDepleted then
        newState = STATE_ENUM.DEAD
    elseif currentState == STATE_ENUM.FALLING or currentState == STATE_ENUM.DROWNING then
        local probTable = store:Get(ragdoll, "ProbTable")
        newState = selectStateByProbTable(probTable)
            or selectStateByProbTable(defaultProbTable)
            or STATE_ENUM.DEAD
    elseif currentState == STATE_ENUM.CRAWLING or currentState == STATE_ENUM.WRITHING then
        if reason == PlaybackReasons.FailedByFall or reason == PlaybackReasons.FailedByHitWall then
            newState = STATE_ENUM.TWITCHING
        elseif reason == PlaybackReasons.InterruptedBySelfRevive then
            newState = STATE_ENUM.SELF_REVIVING
        elseif reason == PlaybackReasons.CompletedNormally then
            newState = currentState
        else
            newState = STATE_ENUM.DEAD
        end
    elseif currentState == STATE_ENUM.TWITCHING then
        if reason == PlaybackReasons.InterruptedBySelfRevive then
            newState = STATE_ENUM.SELF_REVIVING
        elseif reason == PlaybackReasons.CompletedNormally then
            newState = currentState
        else
            newState = STATE_ENUM.DEAD
        end
    elseif currentState == STATE_ENUM.SELF_REVIVING then
        if reason == PlaybackReasons.CompletedNormally then
            newState = STATE_ENUM.GETTING_UP
        elseif reason == PlaybackReasons.Cancelled then
            local prevState = getPreviousState(ragdoll)
            if prevState and prevState ~= STATE_ENUM.SELF_REVIVING then
                newState = prevState
            else
                newState = STATE_ENUM.WRITHING
            end
        elseif reason == PlaybackReasons.FailedByFall or reason == PlaybackReasons.FailedByHitWall then
            local prevState = getPreviousState(ragdoll)
            newState = prevState or STATE_ENUM.WRITHING
        end
    elseif currentState == STATE_ENUM.GETTING_UP then
        if reason == PlaybackReasons.CompletedNormally then
            -- 起身完成，请求复活
            hook.Run(Constants.Events.OnReviveRequested, ragdoll)
            -- 不需要再设置状态，复活会移除实体
        elseif reason == PlaybackReasons.FailedByFall or reason == PlaybackReasons.FailedByHitWall then
            newState = STATE_ENUM.CRAWLING
        else
            newState = STATE_ENUM.DEAD
        end
    end

    -- 如果确定了新状态且与当前不同，则执行转移
    if newState and newState ~= currentState then
        log.debug("LifeCycleHandler: state transition for ", ragdoll, ": ", currentState, " -> ", newState, " (reason: ",
            reason, ")")

        setState(ragdoll, newState)
    end
end

-- 监听统一的播放停止事件
hook.Add(Constants.Events.OnPlaybackStopped, MODULE_NAME .. "_OnPlaybackStopped", function(ragdoll, reason)
    if not IsValid(ragdoll) then return end
    LifeCycleHandler:HandleEvent(ragdoll, reason)
end)

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = LifeCycleHandler
return LifeCycleHandler
