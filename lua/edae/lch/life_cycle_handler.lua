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

-- 依赖的其他模块接口（假设已实现）
local RagdollManager         = include("edae/rm/ragdoll_manager.lua")         -- 提供 GetHealth(ragdoll)
local DamageContextManager   = include("edae/dcm/damage_context_manager.lua") -- 可能用于获取上下文，但通常由外部传入

local store                  = EntityDataStore:ForOwner(MODULE_NAME)

local STATE_KEY              = Constants.LifeCycleHandler.STATE_KEY
local STATE_ENUM             = Constants.LifeCycleHandler.STATE_ENUM
local HEALTH_KEY             = Constants.RagdollManager.HEALTH_KEY

-- 额外存储键
local STATE_ENTER_TIME_KEY   = "StateEnterTime"
local NEXT_STATE_DECIDED_KEY = "NextStateDecided"
local ANIM_END_TIME_KEY      = "AnimEndTime"

-- 从常量中读取概率配置，若未定义则使用默认值
local CRAWL_CHANCE           = Constants.LifeCycleHandler.CRAWL_CHANCE or 0.5
local WRITHE_CHANCE          = Constants.LifeCycleHandler.WRITHE_CHANCE or 0.3
local DEAD_AFTER_FALL_CHANCE = Constants.LifeCycleHandler.DEAD_AFTER_FALL_CHANCE or 0.2

local LifeCycleHandler       = {}

-- 初始化：在 Ragdoll 创建时调用
function LifeCycleHandler:Init(ragdoll)
    if not IsValid(ragdoll) then return end

    store:Set(ragdoll, STATE_KEY, STATE_ENUM.FALLING)
    store:Set(ragdoll, STATE_ENTER_TIME_KEY, CurTime())
    store:Set(ragdoll, NEXT_STATE_DECIDED_KEY, false)
    store:Set(ragdoll, ANIM_END_TIME_KEY, nil)

    log.trace("LifeCycleHandler: initialized ragdoll to state 'falling'")
end

-- 获取当前状态
function LifeCycleHandler:GetState(ragdoll)
    if not IsValid(ragdoll) then return nil end
    return store:Get(ragdoll, STATE_KEY)
end

-- 强制设置状态（通常由外部模块显式调用）
function LifeCycleHandler:SetState(ragdoll, newState)
    if not IsValid(ragdoll) then return end
    local currentState = LifeCycleHandler:GetState(ragdoll)
    if currentState == newState then return end

    -- 更新状态和进入时间
    store:Set(ragdoll, STATE_KEY, newState)
    store:Set(ragdoll, STATE_ENTER_TIME_KEY, CurTime())
    store:Set(ragdoll, NEXT_STATE_DECIDED_KEY, false)
    store:Set(ragdoll, ANIM_END_TIME_KEY, nil)

    log.info("LifeCycleHandler: state change '", currentState, "' -> '", newState, "' for ", ragdoll)

    -- 触发状态变化事件，供动画播放器、爬行控制器等模块监听
    -- 注意：伤害上下文需要外部提供，这里尝试从 RagdollManager 获取（假设其存储了 owner 的伤害上下文）
    local damageContext = RagdollManager:GetDamageContext(ragdoll) -- 假设已实现
    local yaw = ragdoll:GetAngles().yaw
    hook.Run("EDAE_RagdollStateChange", ragdoll, newState, damageContext, yaw)
end

-- 主判定函数：根据当前生命值、动画进度、随机概率等决定是否需要切换状态
-- 由 RagdollManager 在每次伤害后调用，或由 AnimationPlayer 在动画结束时调用
function LifeCycleHandler:DetermineState(ragdoll, forceState)
    if not IsValid(ragdoll) then return end

    -- 1. 强制状态优先
    if forceState then
        LifeCycleHandler:SetState(ragdoll, forceState)
        return
    end

    -- 2. 检查生命值：若 ≤0，进入 dead
    local health = RagdollManager:GetHealth(ragdoll)
    if health ~= nil and health <= 0 then
        if LifeCycleHandler:GetState(ragdoll) ~= STATE_ENUM.DEAD then
            LifeCycleHandler:SetState(ragdoll, STATE_ENUM.DEAD)
        end
        return
    end

    local currentState = LifeCycleHandler:GetState(ragdoll)

    -- 3. 根据当前状态和条件推进
    if currentState == STATE_ENUM.FALLING then
        -- 检查死亡动画是否已经播放完毕
        local animEndTime = store:Get(ragdoll, ANIM_END_TIME_KEY)
        if animEndTime and CurTime() >= animEndTime then
            -- 决定下一步状态：爬行、挣扎、或死亡
            local nextState = LifeCycleHandler:_ChoosePostFallState()
            LifeCycleHandler:SetState(ragdoll, nextState)
        end
    elseif currentState == STATE_ENUM.CRAWLING or currentState == STATE_ENUM.WRITHING then
        -- 此处可加入复活条件判定（由外部事件触发，不在此函数中处理）
        -- 若生命值未耗尽但动画自然循环结束，不改变状态（循环播放）
    elseif currentState == STATE_ENUM.REVIVING then
        -- 复活动画播放结束后，实际复活由 ReviveSystem 处理
    end
end

-- 动画播放器在动画循环完成时调用此方法
-- @param ragdoll Entity
-- @param animationName string 刚结束的动画名称（可选）
function LifeCycleHandler:OnAnimationFinished(ragdoll, animationName)
    if not IsValid(ragdoll) then return end

    local currentState = LifeCycleHandler:GetState(ragdoll)

    if currentState == STATE_ENUM.FALLING then
        -- 死亡动画播放完毕，记录结束时间，等待 DetermineState 决定下一步
        store:Set(ragdoll, ANIM_END_TIME_KEY, CurTime())
        -- 立即尝试推进
        LifeCycleHandler:DetermineState(ragdoll)
    elseif currentState == STATE_ENUM.CRAWLING or currentState == STATE_ENUM.WRITHING then
        -- 爬行/挣扎动画可以循环，不自动切换状态
        -- 除非生命值耗尽（已在伤害时处理），否则保持循环
    elseif currentState == STATE_ENUM.REVIVING then
        -- 复活动画结束，触发复活完成事件，具体逻辑由外部处理
        hook.Run("EDAE_ReviveFinished", ragdoll)
    end
end

-- 内部函数：根据概率随机选择 falling 之后的状态
function LifeCycleHandler:_ChoosePostFallState()
    local roll = math.random()
    if roll < DEAD_AFTER_FALL_CHANCE then
        return STATE_ENUM.DEAD
    elseif roll < DEAD_AFTER_FALL_CHANCE + CRAWL_CHANCE then
        return STATE_ENUM.CRAWLING
    else
        return STATE_ENUM.WRITHING
    end
end

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = LifeCycleHandler
return LifeCycleHandler
