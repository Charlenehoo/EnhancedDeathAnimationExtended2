-- lua/edae/rm/playback_coordinator.lua
-- 统一播放协调器：封装动画播放和物理抽搐的差异，对上层提供一致的 Start/Stop/Rotate 接口
-- 负责将底层结束事件统一转发为 OnPlaybackStopped 事件
-- 旋转方法透传给 AnimationPlayer，用于玩家在爬行/挣扎等状态下控制布娃娃朝向

local MODULE_NAME = "PlaybackCoordinator"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants           = include("edae/config/constants.lua")
local log                 = include("edae/log/init.lua")
local AnimationPlayer     = include("edae/ap/animation_player.lua")
local TwitchController    = include("edae/ap/twitch_controller.lua")
local AnimationAssembler  = include("edae/as/animation_assembler.lua")
local TwitchAssembler     = include("edae/as/twitch_assembler.lua")
local EntityDataStore     = include("edae/eds/entity_data_store.lua")
local store               = EntityDataStore:ForOwner(MODULE_NAME)
local BONE_SKIP_KEY       = "PersistentSkipBones"

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
        -- 注入持久化跳过设置
        local persistentSkipBones = store:Get(ragdoll, BONE_SKIP_KEY)
        if persistentSkipBones then
            animationOpts.persistentSkipBones = persistentSkipBones
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

--- 请求布娃娃旋转到指定方向或背对指定位置
--- 透传给 AnimationPlayer，仅当存在动画播放上下文时有效
--- @param ragdoll Entity 布娃娃实体
--- @param targetYaw number|nil 目标绝对 Yaw 角（度）
--- @param targetPos Vector|nil 目标位置（布娃娃将背对该位置）
--- @param maxTurnSpeed number|nil 最大角速度（度/秒），nil 表示瞬时旋转
--- @return boolean 是否成功记录旋转请求
function PlaybackCoordinator:Rotate(ragdoll, targetYaw, targetPos, maxTurnSpeed)
    if not IsValid(ragdoll) then
        log.warn("PlaybackCoordinator:Rotate invalid ragdoll")
        return false
    end

    return AnimationPlayer:Rotate(ragdoll, targetYaw, targetPos, maxTurnSpeed)
end

--- 以增量方式旋转布娃娃（基于当前朝向增加角度）
--- 透传给 AnimationPlayer，仅当存在动画播放上下文时有效
--- @param ragdoll Entity 布娃娃实体
--- @param deltaYaw number 旋转增量（度，正为逆时针，负为顺时针）
--- @param maxTurnSpeed number|nil 最大角速度（度/秒），nil 表示瞬时旋转
--- @return boolean 是否成功记录旋转请求
function PlaybackCoordinator:RotateBy(ragdoll, deltaYaw, maxTurnSpeed)
    if not IsValid(ragdoll) then
        log.warn("PlaybackCoordinator:RotateBy invalid ragdoll")
        return false
    end

    return AnimationPlayer:RotateBy(ragdoll, deltaYaw, maxTurnSpeed)
end

--- 设置骨骼跳过状态（持久化，并对当前播放立即生效）
--- @param ragdoll Entity 布娃娃实体
--- @param boneName string 完整骨骼名
--- @param skip boolean 是否跳过
--- @return boolean 是否成功记录
function PlaybackCoordinator:SetBoneSkip(ragdoll, boneName, skip)
    if not IsValid(ragdoll) then
        log.warn("PlaybackCoordinator:SetBoneSkip invalid ragdoll")
        return false
    end

    -- 更新持久化存储
    local skips = store:Get(ragdoll, BONE_SKIP_KEY) or {}
    skips[boneName] = skip and true or false
    store:Set(ragdoll, BONE_SKIP_KEY, skips)

    -- 立即应用到当前活动动画（如果有）
    AnimationPlayer:SetBoneSkip(ragdoll, boneName, skip)

    return true
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
