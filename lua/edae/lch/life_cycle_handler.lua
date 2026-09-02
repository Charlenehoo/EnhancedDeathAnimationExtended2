-- lua/edae/lch/life_cycle_handler.lua
-- 生命周期状态机：管理 Ragdoll 从生成到彻底死亡/复活的状态转换
-- 设计为纯逻辑模块，不直接操作动画或伤害，通过事件与其他模块解耦
-- 本模块负责所有状态决策，包括自救、起身流程的状态流转

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
local HEALTH_KEY         = Constants.RagdollManager.HEALTH_KEY

-- 用于保存切换前状态的键（属于 LifeCycleHandler 模块所有）
local PREVIOUS_STATE_KEY = "PreviousState"

local CRAWL_CHANCE       = Constants.LifeCycleHandler.CRAWL_CHANCE
local TWITCH_CHANCE      = Constants.LifeCycleHandler.TWITCH_CHANCE
local WRITHE_CHANCE      = Constants.LifeCycleHandler.WRITHE_CHANCE

local LifeCycleHandler   = {}

-- 内部：获取当前状态
local function getState(ragdoll)
    return store:Get(ragdoll, STATE_KEY) or STATE_ENUM.FALLING -- 默认状态
end

-- 内部：保存上一状态（在切换前调用）
local function savePreviousState(ragdoll, oldState)
    store:Set(ragdoll, PREVIOUS_STATE_KEY, oldState)
end

-- 内部：获取上一状态
local function getPreviousState(ragdoll)
    return store:Get(ragdoll, PREVIOUS_STATE_KEY)
end

-- 内部：清除上一状态记录
local function clearPreviousState(ragdoll)
    store:Set(ragdoll, PREVIOUS_STATE_KEY, nil) -- 注意 EntityDataStore 的 Set 不支持 nil，应使用 Clear?
end

-- 由于 EntityDataStore 的 Set 不支持存储 nil，需要单独删除字段
-- 我们可以在 ForOwner 的子表中增加 Delete 方法，或者直接调用 store:Clear 但会清除所有字段
-- 这里我们使用 store:Clear(ragdoll) 来清除所有 LifeCycleHandler 存储的数据（包括状态和前一状态），但可能不合适
-- 更简单的方式：在 setState 中，如果不需要保留，就不清除，保留旧状态。后续使用时再决定是否覆盖。
-- 我们采用不主动清除的方式，仅在需要时覆盖。

-- 内部：设置状态，并在状态改变时触发事件
local function setState(ragdoll, newState)
    local oldState = getState(ragdoll)
    if oldState == newState then
        return newState
    end

    -- 保存上一状态（用于取消自救时恢复）
    savePreviousState(ragdoll, oldState)

    store:Set(ragdoll, STATE_KEY, newState)
    log.trace("LifeCycleHandler: state changed for ", ragdoll, ": ", oldState, " -> ", newState)

    -- 通知外部模块（如 RagdollManager 切换动画）
    hook.Run(Constants.Events.OnRagdollStateChange, ragdoll, newState, oldState)

    return newState
end

-- 内部：获取当前血量
local function getHealth(ragdoll)
    return EntityDataStore:Get(ragdoll, HEALTH_KEY) or Constants.RagdollManager.MAX_HEALTH
end

-- 初始化 Ragdoll 的生命周期
function LifeCycleHandler:Init(ragdoll, damageContext)
    if not IsValid(ragdoll) then
        log.warn("LifeCycleHandler:Init called with invalid ragdoll")
        return nil
    end

    local initialState = STATE_ENUM.FALLING
    store:Set(ragdoll, STATE_KEY, initialState)

    log.trace("LifeCycleHandler: initialized ragdoll ", ragdoll, " with state '", initialState, "'")

    return initialState
end

-- 根据当前情况重新计算状态（通常在受伤后调用）
function LifeCycleHandler:DetermineState(ragdoll)
    if not IsValid(ragdoll) then return nil end

    local currentState = getState(ragdoll)
    local health = getHealth(ragdoll)

    if health <= 0 then
        if currentState ~= STATE_ENUM.DEAD then
            log.trace("LifeCycleHandler: ragdoll ", ragdoll, " has no health, setting state to dead")
            return setState(ragdoll, STATE_ENUM.DEAD)
        end
        return currentState
    end

    -- 其余情况保持当前状态不变（包括 SELF_REVIVING、GETTING_UP 等）
    return currentState
end

-- 请求开始自救（由外部调用，如 PlayerProxy -> RagdollManager -> 此处）
-- 该方法会检查状态合法性，若允许则切换到 SELF_REVIVING 状态
function LifeCycleHandler:RequestSelfRevive(ragdoll)
    if not IsValid(ragdoll) then return false end

    local currentState = getState(ragdoll)
    if not currentState then return false end

    -- 不允许在 DEAD、SELF_REVIVING、GETTING_UP 状态下再次自救
    if currentState == STATE_ENUM.DEAD or
        currentState == STATE_ENUM.SELF_REVIVING or
        currentState == STATE_ENUM.GETTING_UP then
        return false
    end

    -- 血量必须大于 0
    if getHealth(ragdoll) <= 0 then
        return false
    end

    -- 切换到自救状态（setState 会自动保存前一状态）
    setState(ragdoll, STATE_ENUM.SELF_REVIVING)
    return true
end

-- 请求取消自救（由外部调用，仅当处于 SELF_REVIVING 时有效）
-- 取消操作本身不是状态切换，而是通知动画系统中断动画；
-- 动画中断后，OnAnimationFinished 会处理状态恢复。
function LifeCycleHandler:CancelSelfRevive(ragdoll)
    if not IsValid(ragdoll) then return end
    if getState(ragdoll) ~= STATE_ENUM.SELF_REVIVING then return end

    -- 这里不直接操作动画，而是发出一个取消请求事件，让 RagdollManager 去调用 AnimationPlayer:Cancel
    hook.Run("EDAE_OnSelfReviveCancelRequested", ragdoll)
end

-- 处理动画结束事件（由 AnimationPlayer 在动画循环结束后触发）
function LifeCycleHandler:OnAnimationFinished(ragdoll, animationName, stopReason)
    if not IsValid(ragdoll) then return end

    local currentState = getState(ragdoll)

    if currentState == STATE_ENUM.FALLING then
        local health = getHealth(ragdoll)
        if health <= 0 then
            setState(ragdoll, STATE_ENUM.DEAD)
            return
        end

        local rand = math.random()
        local newState

        if rand < CRAWL_CHANCE then
            newState = STATE_ENUM.CRAWLING
        elseif rand < CRAWL_CHANCE + WRITHE_CHANCE then
            newState = STATE_ENUM.TWITCHING
        elseif rand < CRAWL_CHANCE + WRITHE_CHANCE + TWITCH_CHANCE then
            newState = STATE_ENUM.WRITHING
        else
            newState = STATE_ENUM.DEAD
        end

        log.trace("LifeCycleHandler: falling finished for ", ragdoll, ", transitioning to '", newState, "'")
        setState(ragdoll, newState)
    elseif currentState == STATE_ENUM.CRAWLING or currentState == STATE_ENUM.WRITHING then
        if stopReason == "fall" or stopReason == "hitwall" then
            log.trace("LifeCycleHandler: crawling stopped due to ", stopReason, ", transitioning to twitching")
            setState(ragdoll, STATE_ENUM.TWITCHING)
        end
    elseif currentState == STATE_ENUM.SELF_REVIVING then
        -- 自救动画结束
        if stopReason == "normal" then
            -- 自然播放完毕，进入起身阶段
            log.trace("LifeCycleHandler: self revive finished normally, transitioning to getting up")
            setState(ragdoll, STATE_ENUM.GETTING_UP)
        else
            -- 被取消或中断，恢复到之前的状态
            local prevState = getPreviousState(ragdoll)
            if prevState and prevState ~= STATE_ENUM.SELF_REVIVING then
                log.trace("LifeCycleHandler: self revive cancelled, reverting to '", prevState, "'")
                setState(ragdoll, prevState)
            else
                -- 没有合理的前一状态，回退到 CRAWLING 作为安全默认
                log.warn("LifeCycleHandler: no valid previous state, defaulting to crawling")
                setState(ragdoll, STATE_ENUM.CRAWLING)
            end
        end
    elseif currentState == STATE_ENUM.GETTING_UP then
        -- 起身动画结束（理论上只有 normal，但任何原因都应复活）
        log.trace("LifeCycleHandler: getting up finished, requesting revive")
        hook.Run(Constants.Events.OnReviveRequested, ragdoll)
    end
end

-- 供外部查询当前状态
function LifeCycleHandler:GetState(ragdoll)
    if not IsValid(ragdoll) then return nil end
    return getState(ragdoll)
end

-- 供外部强制设置状态
function LifeCycleHandler:SetState(ragdoll, newState)
    if not IsValid(ragdoll) then return end
    if not table.HasValue(STATE_ENUM, newState) then
        log.warn("LifeCycleHandler: invalid state '", tostring(newState), "'")
        return
    end
    setState(ragdoll, newState)
end

-- 获取上一状态（供其他模块查询，例如调试）
function LifeCycleHandler:GetPreviousState(ragdoll)
    if not IsValid(ragdoll) then return nil end
    return getPreviousState(ragdoll)
end

-- 监听动画结束事件（由 AnimationPlayer 发出）
hook.Add(Constants.Events.OnAnimationFinished, MODULE_NAME .. "_OnAnimationFinished",
    function(ragdoll, animationName, stopReason)
        LifeCycleHandler:OnAnimationFinished(ragdoll, animationName, stopReason)
    end)

-- 注册单例
_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = LifeCycleHandler
return LifeCycleHandler
