-- lua/edae/as/prewait_builder.lua
-- 预等待构建器：为需要等待布娃娃静止的播放状态生成等待函数数组
-- 属于动画组装（assembly）子系统，被 AnimationAssembler 或 TwitchAssembler 调用
-- 所有参数由调用方显式传入并展平，本模块不读取任何常量或默认值

local MODULE_NAME = "PreWaitBuilder"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Scheduler = include("edae/coroutine_scheduler.lua")

local PreWaitBuilder = {}

-- 判断布娃娃是否已经静止（只检查白名单内的骨骼，若未提供白名单则检查全部）
-- 所有阈值参数由调用方传入，不依赖全局常量
local function isRagdollStopped(ragdoll, boneWhitelist, linearThreshold, angularThreshold)
    local physCount = ragdoll:GetPhysicsObjectCount()
    for i = 0, physCount - 1 do
        local boneID = ragdoll:TranslatePhysBoneToBone(i)
        if boneID then
            local boneName = ragdoll:GetBoneName(boneID)
            if (not boneWhitelist) or (boneWhitelist and boneWhitelist[boneName]) then
                local phys = ragdoll:GetPhysicsObjectNum(i)
                if phys then
                    local linVel = phys:GetVelocity():Length()
                    local angVel = phys:GetAngleVelocity():Length()
                    if linVel > linearThreshold or angVel > angularThreshold then
                        return false
                    end
                end
            end
        end
    end
    return true
end

--- 构建预等待函数数组
--- @param state string 当前状态（来自 Constants.LifeCycleHandler.STATE_ENUM）
--- @param preWaitTime number 播放前固定等待时间（秒）
--- @param stopLinearThreshold number 停止判定：线速度阈值
--- @param stopAngularThreshold number 停止判定：角速度阈值
--- @param stopTimeout number 等待停止的超时时间（秒）
--- @param stopCheckInterval number 停止检测轮询间隔（秒）
--- @return table 等待函数数组；对于不需要等待的状态返回空数组
function PreWaitBuilder:Build(state, preWaitTime, stopLinearThreshold, stopAngularThreshold, stopTimeout,
                              stopCheckInterval)
    -- 仅爬行、挣扎、抽搐需要等待静止
    if state ~= "crawling" and state ~= "writhing" and state ~= "twitching" then
        return {}
    end

    return {
        -- 先等待固定时间
        function(ctx)
            Scheduler:Wait(preWaitTime)
        end,
        -- 再等待布娃娃静止（直到满足条件或超时）
        function(ctx)
            Scheduler:WaitUntil(
                function()
                    return isRagdollStopped(ctx.ragdoll, ctx.boneWhitelist, stopLinearThreshold,
                        stopAngularThreshold)
                end,
                stopTimeout,
                stopCheckInterval
            )
        end,
    }
end

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = PreWaitBuilder
return PreWaitBuilder
