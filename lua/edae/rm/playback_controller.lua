-- lua/edae/rm/playback_controller.lua
-- 动画播放控制器：根据布娃娃状态和伤害上下文，选择动画并组装播放参数，最终调用 AnimationPlayer
-- 职责：将 AnimationSelector 选择的动画数据与姿态辅助（yaw）等结合，形成完整的 opts 传递给 AnimationPlayer

local MODULE_NAME = "AnimationPlaybackController"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants                   = include("edae/config/constants.lua")
local log                         = include("edae/log/init.lua")
local AnimationSelector           = include("edae/as/animation_selector.lua")
local AnimationPlayer             = include("edae/ap/animation_player.lua")
local TwitchController            = include("edae/tc/twitch_controller.lua")
local RagdollPoseHelper           = include("edae/rm/pose_helper.lua")
local EffectBuilder               = include("edae/rm/effect_builder.lua")
local HealthManager               = include("edae/rm/health_manager.lua")

local STATE_ENUM                  = Constants.LifeCycleHandler.STATE_ENUM

local AnimationPlaybackController = {}

-- ============================================================
-- 主播放接口
-- ============================================================

--- 为指定状态播放动画
--- @param ragdoll Entity 布娃娃实体
--- @param state string 当前状态（来自 STATE_ENUM）
--- @param damageContext table|nil 伤害上下文（仅在 FALLING 状态时需要，用于选择死亡动画）
--- @param owner Entity|nil 布娃娃的所有者（可选，用于 FALLING 状态计算 yaw；若未提供则回退到 ragdoll 自身角度）
--- @return boolean success 是否成功启动播放
function AnimationPlaybackController:PlayForState(ragdoll, state, damageContext, owner)
    if not IsValid(ragdoll) then
        log.warn("AnimationPlaybackController:PlayForState called with invalid ragdoll")
        return false
    end

    if not table.HasValue(STATE_ENUM, state) then
        log.warn("AnimationPlaybackController:PlayForState invalid state: ", tostring(state))
        return false
    end

    if state == STATE_ENUM.DEAD then
        return false
    end

    local yaw
    local groundPos
    if state == STATE_ENUM.FALLING then
        if owner and owner:IsValid() then
            yaw = RagdollPoseHelper:GetYawFromOwner(owner)
            groundPos = owner:GetPos()
        else
            log.trace("AnimationPlaybackController: owner not provided for FALLING state, using ragdoll yaw as fallback")
            yaw = RagdollPoseHelper:GetYawFromRagdoll(ragdoll)
        end
    else
        yaw = RagdollPoseHelper:GetYawFromRagdoll(ragdoll)
    end

    local playBackInfo = {
        state = state,
        damageContext = damageContext,
        isFacingUp = RagdollPoseHelper:IsFacingUp(ragdoll),
        yaw = yaw,
        groundPos = groundPos
    }

    local playbackData = AnimationSelector:Select(playBackInfo)
    if not playbackData then
        log.warn("AnimationPlaybackController: no playback data for state ", state)
        return false
    end

    -- 构建效果（用于动画或抽搐）
    local effects = EffectBuilder:Build(ragdoll, state, owner)

    -- 如果是抽搐，则启动 TwitchController 并传入效果
    if playbackData.isTwitch then
        local twitchOpts = playbackData.twitchParams or {}
        twitchOpts.effects = effects
        twitchOpts.preWait = playbackData.preWait -- 从 playbackData 传递

        local success = TwitchController:Start(ragdoll, twitchOpts)
        if not success then
            log.warn("AnimationPlaybackController: failed to start twitch for state ", state)
            return false
        end
        log.trace("AnimationPlaybackController: started twitch for state '", state, "'")
        return true
    end

    -- 普通动画播放
    local initialHealth = HealthManager:Get(ragdoll)

    local opts = {
        totalLoops = playbackData.totalLoops,
        preWait = playbackData.preWait,
        yaw = yaw,
        groundPos = groundPos,
        effects = effects,
        enableRotate = true,
        -- 新增字段
        initialHealth = initialHealth,
        enableHealthBasedSlowdown = false,
        basePlaybackRate = playbackData.basePlaybackRate or 1.0,
    }

    if state == STATE_ENUM.WRITHING then
        opts.enableHealthBasedSlowdown = true
    end

    local ctx = AnimationPlayer:Play(ragdoll, playbackData.animationName, opts)
    if not ctx then
        log.warn("AnimationPlaybackController: failed to start animation ", playbackData.animationName)
        return false
    end

    log.trace("AnimationPlaybackController: started animation '", playbackData.animationName, "' for state '", state,
        "' with yaw=", yaw)
    return true
end

-- 注册单例
_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = AnimationPlaybackController
return AnimationPlaybackController
