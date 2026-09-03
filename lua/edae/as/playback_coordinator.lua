-- lua/edae/rm/playback_coordinator.lua
-- 统一播放协调器：封装动画播放和物理抽搐的差异，对上层提供一致的 Start/Stop 接口
-- 负责将底层结束事件统一转发为 OnPlaybackStopped 事件
-- 对外只暴露 PlaybackCoordinator 单例，门面（RagdollManager）通过它控制所有播放

local MODULE_NAME = "PlaybackCoordinator"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants           = include("edae/config/constants.lua")
local log                 = include("edae/log/init.lua")
local AnimationPlayer     = include("edae/ap/animation_player.lua")
local TwitchController    = include("edae/tc/twitch_controller.lua")
local AnimationAssembler  = include("edae/as/animation_assembler.lua")
local TwitchAssembler     = include("edae/as/twitch_assembler.lua")

local STATE_ENUM          = Constants.LifeCycleHandler.STATE_ENUM

local PlaybackCoordinator = {}

--- 启动播放
--- 根据状态自动判断使用动画还是抽搐，并调用相应组装器生成参数，最后启动底层播放器
--- @param ragdoll Entity 布娃娃实体
--- @param state string 当前状态（使用 STATE_ENUM）
--- @param damageContext table|nil 伤害上下文（仅 FALLING 需要）
--- @param owner Entity|nil 布娃娃所有者（用于效果器、yaw 等）
--- @param isPlayerCameraMode boolean|nil 是否玩家相机模式（默认 false）
--- @return boolean 是否成功启动
function PlaybackCoordinator:Start(ragdoll, state, damageContext, owner, isPlayerCameraMode)
    if not IsValid(ragdoll) then
        log.warn("PlaybackCoordinator:Start invalid ragdoll")
        return false
    end

    if state == STATE_ENUM.DEAD then
        log.trace("PlaybackCoordinator:Start state is DEAD, nothing to play")
        return false
    end

    if state == STATE_ENUM.TWITCHING then
        -- 物理抽搐：使用 TwitchAssembler
        local twitchOpts = TwitchAssembler:Assemble(ragdoll, state, owner)
        if not twitchOpts then
            log.warn("PlaybackCoordinator:Start TwitchAssembler failed for state '", state, "'")
            return false
        end
        return TwitchController:Start(ragdoll, twitchOpts)
    else
        -- 骨骼动画：使用 AnimationAssembler
        local animationName, animationOpts = AnimationAssembler:Assemble(ragdoll, state, damageContext, owner,
            isPlayerCameraMode)
        if not animationName or not animationOpts then
            log.warn("PlaybackCoordinator:Start AnimationAssembler failed for state '", state, "'")
            return false
        end
        return AnimationPlayer:Play(ragdoll, animationName, animationOpts)
    end
end

--- 停止播放
--- 会同时尝试停止动画和抽搐（各自检查是否有活动上下文）
--- 如果两者均无活动上下文，则手动触发 OnPlaybackStopped 事件，确保状态机仍能收到停止原因
--- @param ragdoll Entity
--- @param reason string 停止原因，使用 Constants.PlaybackReasons 中的值
function PlaybackCoordinator:Stop(ragdoll, reason)
    if not IsValid(ragdoll) then
        -- 实体无效也触发事件，避免状态机等待
        log.trace("PlaybackCoordinator:Stop invalid ragdoll, emitting OnPlaybackStopped manually")
        hook.Run(Constants.Events.OnPlaybackStopped, ragdoll, reason)
        return
    end

    local animStopped = AnimationPlayer:Stop(ragdoll, reason)
    local twitchStopped = TwitchController:Stop(ragdoll, reason)

    -- 如果没有任何活动播放器响应，说明当前没有播放，直接发出统一事件
    if not animStopped and not twitchStopped then
        log.trace("PlaybackCoordinator:Stop no active playback, emitting OnPlaybackStopped manually")
        hook.Run(Constants.Events.OnPlaybackStopped, ragdoll, reason)
    end
end

-- 监听底层播放器结束事件，统一转发为 OnPlaybackStopped
hook.Add(Constants.Events.OnAnimationFinished, MODULE_NAME .. "_OnAnimationFinished", function(ragdoll, animName, reason)
    hook.Run(Constants.Events.OnPlaybackStopped, ragdoll, reason)
end)

hook.Add(Constants.Events.OnTwitchFinished, MODULE_NAME .. "_OnTwitchFinished", function(ragdoll, reason)
    hook.Run(Constants.Events.OnPlaybackStopped, ragdoll, reason)
end)

-- 注册单例
_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = PlaybackCoordinator
return PlaybackCoordinator
