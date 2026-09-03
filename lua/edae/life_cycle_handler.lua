-- lua/edae/life_cycle_handler.lua
-- 生命周期状态机：管理 Ragdoll 的状态转移
-- 纯逻辑模块，只监听 OnPlaybackStopped 事件，根据原因和当前状态查表转移
-- 不直接操作播放器、血量或任何外部资源；不对外暴露 SetState
-- 所有状态变化均通过内部 setState 完成，并触发 OnRagdollStateChange 事件

local MODULE_NAME = "LifeCycleHandler"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants          = include("edae/config/constants.lua")
local log                = include("edae/log/init.lua")
local EntityDataStore    = include("edae/eds/entity_data_store.lua")

local store              = EntityDataStore:ForOwner(MODULE_NAME)

local STATE_KEY          = Constants.LifeCycleHandler.STATE_KEY
local STATE_ENUM         = Constants.LifeCycleHandler.STATE_ENUM
local PREVIOUS_STATE_KEY = "PreviousState"

local CRAWL_CHANCE       = Constants.LifeCycleHandler.CRAWL_CHANCE
local WRITHE_CHANCE      = Constants.LifeCycleHandler.WRITHE_CHANCE
local TWITCH_CHANCE      = Constants.LifeCycleHandler.TWITCH_CHANCE

local PlaybackReasons    = Constants.PlaybackReasons

local LifeCycleHandler   = {}

-- 获取当前状态
local function getState(ragdoll)
    return store:Get(ragdoll, STATE_KEY) or STATE_ENUM.FALLING
end

-- 保存前一状态
local function savePreviousState(ragdoll, oldState)
    store:Set(ragdoll, PREVIOUS_STATE_KEY, oldState)
end

-- 获取前一状态
local function getPreviousState(ragdoll)
    return store:Get(ragdoll, PREVIOUS_STATE_KEY)
end

-- 内部设置状态，并触发事件
local function setState(ragdoll, newState)
    local oldState = getState(ragdoll)
    if oldState == newState then
        return
    end

    -- 保存前一状态（用于自救取消恢复）
    savePreviousState(ragdoll, oldState)

    store:Set(ragdoll, STATE_KEY, newState)
    log.trace("LifeCycleHandler: state changed for ", ragdoll, ": ", oldState, " -> ", newState)

    hook.Run(Constants.Events.OnRagdollStateChange, ragdoll, newState, oldState)
end

-- 初始化 Ragdoll 状态
function LifeCycleHandler:Init(ragdoll, initData)
    if not IsValid(ragdoll) then
        log.warn("LifeCycleHandler:Init invalid ragdoll")
        return
    end

    store:Set(ragdoll, STATE_KEY, STATE_ENUM.FALLING)
    log.trace("LifeCycleHandler: initialized ragdoll ", ragdoll, " with state 'falling'")

    -- 触发状态变化事件，携带初始化数据（供门面使用）
    hook.Run(Constants.Events.OnRagdollStateChange, ragdoll, STATE_ENUM.FALLING, nil, initData)
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

-- 处理播放停止事件，根据原因和当前状态转移
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
    elseif currentState == STATE_ENUM.FALLING then
        if reason == PlaybackReasons.CompletedNormally then
            -- 概率转移
            local rand = math.random()
            if rand < CRAWL_CHANCE then
                newState = STATE_ENUM.CRAWLING
            elseif rand < CRAWL_CHANCE + WRITHE_CHANCE then
                newState = STATE_ENUM.WRITHING
            elseif rand < CRAWL_CHANCE + WRITHE_CHANCE + TWITCH_CHANCE then
                newState = STATE_ENUM.TWITCHING
            else
                newState = STATE_ENUM.DEAD
            end
        elseif reason == PlaybackReasons.FailedByFall or reason == PlaybackReasons.FailedByHitWall then
            newState = STATE_ENUM.DEAD
        end
    elseif currentState == STATE_ENUM.CRAWLING then
        if reason == PlaybackReasons.FailedByFall or reason == PlaybackReasons.FailedByHitWall then
            newState = STATE_ENUM.TWITCHING
        elseif reason == PlaybackReasons.InterruptedBySelfRevive then
            newState = STATE_ENUM.SELF_REVIVING
        elseif reason == PlaybackReasons.CompletedNormally then
            -- 循环动画自然结束，保持原状态（重新播放）
            newState = currentState
        end
    elseif currentState == STATE_ENUM.WRITHING then
        if reason == PlaybackReasons.FailedByFall or reason == PlaybackReasons.FailedByHitWall then
            newState = STATE_ENUM.TWITCHING
        elseif reason == PlaybackReasons.InterruptedBySelfRevive then
            newState = STATE_ENUM.SELF_REVIVING
        elseif reason == PlaybackReasons.CompletedNormally then
            newState = currentState
        end
    elseif currentState == STATE_ENUM.TWITCHING then
        if reason == PlaybackReasons.InterruptedBySelfRevive then
            newState = STATE_ENUM.SELF_REVIVING
        elseif reason == PlaybackReasons.CompletedNormally then
            newState = currentState -- 抽搐自然结束保持
        end
    elseif currentState == STATE_ENUM.SELF_REVIVING then
        if reason == PlaybackReasons.CompletedNormally then
            newState = STATE_ENUM.GETTING_UP
        elseif reason == PlaybackReasons.Cancelled then
            local prevState = getPreviousState(ragdoll)
            if prevState and prevState ~= STATE_ENUM.SELF_REVIVING then
                newState = prevState
            else
                newState = STATE_ENUM.CRAWLING -- 安全回退
            end
        elseif reason == PlaybackReasons.FailedByFall or reason == PlaybackReasons.FailedByHitWall then
            -- 自救动画失败，回退前一状态
            local prevState = getPreviousState(ragdoll)
            newState = prevState or STATE_ENUM.CRAWLING
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
