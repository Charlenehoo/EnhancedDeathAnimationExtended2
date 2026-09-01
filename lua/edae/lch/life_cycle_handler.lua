-- lua/edae/lch/life_cycle_handler.lua
-- 生命周期状态机：管理 Ragdoll 从生成到彻底死亡/复活的状态转换
-- 设计为纯逻辑模块，不直接操作动画或伤害，通过事件与其他模块解耦

local MODULE_NAME = "LifeCycleHandler"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants              = include("edae/config/constants.lua")
local log                    = include("edae/log/init.lua")
local EntityDataStore        = include("edae/eds/entity_data_store.lua")

local store                  = EntityDataStore:ForOwner(MODULE_NAME)

local STATE_KEY              = Constants.LifeCycleHandler.STATE_KEY
local STATE_ENUM             = Constants.LifeCycleHandler.STATE_ENUM
local HEALTH_KEY             = Constants.RagdollManager.HEALTH_KEY

local WRITHE_CHANCE          = Constants.LifeCycleHandler.WRITHE_CHANCE
local DEAD_AFTER_FALL_CHANCE = Constants.LifeCycleHandler.DEAD_AFTER_FALL_CHANCE

local LifeCycleHandler       = {}

-- 内部：获取当前状态
local function getState(ragdoll)
    return store:Get(ragdoll, STATE_KEY) or STATE_ENUM.FALLING -- 默认状态
end

-- 内部：设置状态，并在状态改变时触发事件
local function setState(ragdoll, newState)
    local oldState = getState(ragdoll)
    if oldState == newState then
        return newState
    end

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
-- @param ragdoll Entity 刚生成的布娃娃
-- @param damageContext table|nil 伤害上下文（由 DamageContextManager 提供）
-- @return state string 初始状态（通常为 "falling"）
function LifeCycleHandler:Init(ragdoll, damageContext)
    if not IsValid(ragdoll) then
        log.warn("LifeCycleHandler:Init called with invalid ragdoll")
        return nil
    end

    -- 设置初始状态为 FALLING
    local initialState = STATE_ENUM.FALLING
    store:Set(ragdoll, STATE_KEY, initialState)

    log.trace("LifeCycleHandler: initialized ragdoll ", ragdoll, " with state '", initialState, "'")

    return initialState
end

-- 根据当前情况重新计算状态（通常在受伤后调用）
-- @param ragdoll Entity
-- @return newState string
function LifeCycleHandler:DetermineState(ragdoll)
    if not IsValid(ragdoll) then return nil end

    local currentState = getState(ragdoll)
    local health = getHealth(ragdoll)

    -- 如果血量归零，直接进入 DEAD
    if health <= 0 then
        if currentState ~= STATE_ENUM.DEAD then
            log.trace("LifeCycleHandler: ragdoll ", ragdoll, " has no health, setting state to dead")
            return setState(ragdoll, STATE_ENUM.DEAD)
        end
        return currentState
    end

    -- 如果当前状态是 FALLING 且血量正常，则保持不变（等待动画结束）
    -- 其他状态（CRAWLING, WRITHING, REVIVING）在健康时也不改变
    return currentState
end

-- 处理动画结束事件（由 AnimationPlayer 在动画循环结束后触发）
-- @param ragdoll Entity
-- @param animationName string 刚结束的动画名称（可选，用于调试）
function LifeCycleHandler:OnAnimationFinished(ragdoll, animationName)
    if not IsValid(ragdoll) then return end

    local currentState = getState(ragdoll)

    -- 只有 FALLING 动画结束后才进行概率转换
    if currentState ~= STATE_ENUM.FALLING then
        return
    end

    local health = getHealth(ragdoll)
    if health <= 0 then
        setState(ragdoll, STATE_ENUM.DEAD)
        return
    end

    -- 根据概率决定下一个状态
    local rand = math.random()
    local newState

    if rand < DEAD_AFTER_FALL_CHANCE then
        newState = STATE_ENUM.DEAD
    elseif rand < DEAD_AFTER_FALL_CHANCE + WRITHE_CHANCE then
        newState = STATE_ENUM.WRITHING
    else
        newState = STATE_ENUM.CRAWLING
    end

    log.trace("LifeCycleHandler: falling finished for ", ragdoll, ", transitioning to '", newState, "'")
    setState(ragdoll, newState)
end

-- 供外部查询当前状态
-- @param ragdoll Entity
-- @return state string|nil
function LifeCycleHandler:GetState(ragdoll)
    if not IsValid(ragdoll) then return nil end
    return getState(ragdoll)
end

-- 供外部强制设置状态（例如复活）
-- @param ragdoll Entity
-- @param newState string 目标状态（必须是 STATE_ENUM 之一）
function LifeCycleHandler:SetState(ragdoll, newState)
    if not IsValid(ragdoll) then return end
    if not table.HasValue(STATE_ENUM, newState) then
        log.warn("LifeCycleHandler: invalid state '", tostring(newState), "'")
        return
    end
    setState(ragdoll, newState)
end

-- 监听动画结束事件（由 AnimationPlayer 发出）
hook.Add(Constants.Events.OnAnimationFinished, MODULE_NAME .. "_OnAnimationFinished", function(ragdoll, animationName)
    LifeCycleHandler:OnAnimationFinished(ragdoll, animationName)
end)

-- 注册单例
_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = LifeCycleHandler
return LifeCycleHandler
