local MODULE_NAME = "LifeCycleHandler"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants = include("edae/constants.lua")
local log = include("edae/log/init.lua")

local LifeCycleHandler = {}

-- 根据当前状态和结束原因，发射下一个状态变化事件
local function transitionAfterFalling(ctx, reason)
    local ragdoll = ctx.ragdoll
    if not IsValid(ragdoll) then return end

    if reason ~= "finished" then
        log.trace("LifeCycleHandler: falling ended with reason '", reason, "', no transition")
        return
    end

    -- TODO: 这里应该根据 ConVar 概率决定 crawling 还是 writhing，暂用随机
    local nextState = math.random() < 0.5 and "crawling" or "writhing"
    log.trace("LifeCycleHandler: transitioning from falling to ", nextState)

    -- 发射状态变化事件，由 event_lisener 监听并执行动画播放
    hook.Run("EDAE_RagdollStateChange", ragdoll, nextState, ctx.damageContext, ctx.yaw)
end

hook.Add("EDAE_AnimationFinished", Constants.ADDON_NAME .. MODULE_NAME .. "AnimationFinished", function(ctx, reason)
    if not ctx or not ctx.state then
        log.warn("LifeCycleHandler: animation finished event without valid ctx")
        return
    end

    if ctx.state == "falling" then
        transitionAfterFalling(ctx, reason)
    elseif ctx.state == "crawling" or ctx.state == "writhing" then
        -- 爬行/挣扎结束：暂时不进行二次流转，仅记录日志
        log.trace("LifeCycleHandler: ", ctx.state, " ended with reason '", reason, "'")
    end
end)

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = LifeCycleHandler
return LifeCycleHandler
