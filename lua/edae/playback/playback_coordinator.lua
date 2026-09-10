-- lua/edae/playback/playback_coordinator.lua
-- 统一播放协调器：封装动画播放和物理抽搐的差异，对上层提供一致的 Start/Stop/Rotate/Pause/Resume 接口
-- 负责将底层结束事件统一转发为 OnPlaybackStopped 事件
-- 旋转方法透传给 AnimationPlayer，用于玩家在爬行/挣扎等状态下控制布娃娃朝向
-- Pause/Resume 维护独立的 pauseCount，屏蔽底层播放器差异，并保证跨播放器切换时暂停状态继承

local MODULE_NAME = "PlaybackCoordinator"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants           = include("edae/core/constants.lua")
local log                 = include("edae/core/log/init.lua")
local AnimationPlayer     = include("edae/playback/animation_player.lua")
local TwitchController    = include("edae/playback/twitch_controller.lua")
local AnimationAssembler  = include("edae/playback/assemblers/animation_assembler.lua")
local TwitchAssembler     = include("edae/playback/assemblers/twitch_assembler.lua")
local EntityDataStore     = include("edae/core/entity_data_store.lua")
local helper              = include("edae/helper.lua")

local store               = EntityDataStore:ForOwner(MODULE_NAME)
local BONE_SKIP_KEY       = "PersistentSkipBones"
local PAUSE_KEY           = "PlaybackPauseCount"

local STATE_ENUM          = Constants.LifeCycleHandler.STATE_ENUM

local PlaybackCoordinator = {}

--- 启动播放
--- @param owner Entity|nil 布娃娃所有者
--- @param ragdoll Entity 布娃娃实体
--- @param state string 当前状态
--- @param damageContext table|nil 伤害上下文（仅 FALLING 需要）
--- @return boolean 是否成功启动
function PlaybackCoordinator:Start(owner, ragdoll, state, damageContext)
    if not IsValid(ragdoll) then
        log.warn("PlaybackCoordinator:Start invalid ragdoll")
        return false
    end

    if state == STATE_ENUM.DEAD then
        log.trace("PlaybackCoordinator:Start state is DEAD, nothing to play")
        return false
    end

    local started = false

    if state == STATE_ENUM.TWITCHING then
        -- 物理抽搐：使用 TwitchAssembler
        local twitchOpts = TwitchAssembler:Assemble(ragdoll, state, owner)
        if not twitchOpts then
            log.warn("PlaybackCoordinator:Start TwitchAssembler failed for state '", state, "'")
            return false
        end
        started = TwitchController:Start(ragdoll, twitchOpts)
    else
        -- 骨骼动画：使用 AnimationAssembler
        local animationName, animationOpts = AnimationAssembler:Assemble(ragdoll, state, damageContext, owner)
        if not animationName or not animationOpts then
            log.warn("PlaybackCoordinator:Start AnimationAssembler failed for state '", state, "'")
            return false
        end
        -- 注入持久化跳过设置
        local persistentSkipBones = store:Get(ragdoll, BONE_SKIP_KEY)
        if persistentSkipBones then
            animationOpts.persistentSkipBones = persistentSkipBones
        end
        started = AnimationPlayer:Play(ragdoll, animationName, animationOpts)
    end

    -- 暂停状态继承：如果 Coordinator 处于暂停状态，新启动的播放器也要暂停
    -- 这保证跨播放器切换时，调用方的"暂停意图"不会丢失
    if started then
        local pauseCount = store:Get(ragdoll, PAUSE_KEY) or 0
        if pauseCount > 0 then
            -- 同步 Pause 两个底层播放器（只有活动那个会真正暂停）
            -- 时机安全：底层 Play/Start 返回后，ctx 已写入 store，Pause 能正常命中
            AnimationPlayer:Pause(ragdoll)
            TwitchController:Pause(ragdoll)
            log.trace("PlaybackCoordinator:Start new playback while paused (count=", pauseCount, ")")
        end
    end

    return started
end

--- 停止播放
--- 会同时尝试停止动画和抽搐（各自检查是否有活动上下文）
--- 如果两者均无活动上下文，则手动触发 OnPlaybackStopped 事件，确保状态机仍能收到停止原因
--- 同时清空暂停计数：停止意味着"这个播放生命周期结束"，暂停不再有意义
--- @param ragdoll Entity
--- @param reason string 停止原因，使用 Constants.PlaybackReasons 中的值
function PlaybackCoordinator:Stop(ragdoll, reason)
    if not IsValid(ragdoll) then
        -- 实体无效也触发事件，避免状态机等待
        log.trace("PlaybackCoordinator:Stop invalid ragdoll, emitting OnPlaybackStopped manually")
        hook.Run(Constants.Events.OnPlaybackStopped, ragdoll, reason)
        return
    end

    -- 清空暂停计数（先于事件触发，让事件处理者看到"未暂停"状态）
    store:Set(ragdoll, PAUSE_KEY, 0)

    local animStopped = AnimationPlayer:Stop(ragdoll, reason)
    local twitchStopped = TwitchController:Stop(ragdoll, reason)

    -- 如果没有任何活动播放器响应，说明当前没有播放，直接发出统一事件
    if not animStopped and not twitchStopped then
        log.trace("PlaybackCoordinator:Stop no active playback, emitting OnPlaybackStopped manually")
        hook.Run(Constants.Events.OnPlaybackStopped, ragdoll, reason)
    end
end

--- 暂停播放（引用计数式）
--- 屏蔽底层播放器差异：
---   - AnimationPlayer 冻结动画模型时间轴 + 跳过 CSC
---   - TwitchController 冻结施力序列进度 + 跳过效果器
--- 调用方无需知道当前是哪个播放器，也无需知道跨播放器切换时的状态继承。
--- @param ragdoll Entity
--- @return boolean 是否成功增加暂停计数
function PlaybackCoordinator:Pause(ragdoll)
    if not IsValid(ragdoll) then
        log.warn("PlaybackCoordinator:Pause invalid ragdoll")
        return false
    end

    local count = store:Get(ragdoll, PAUSE_KEY) or 0
    count = count + 1
    store:Set(ragdoll, PAUSE_KEY, count)

    if count == 1 then
        -- 首次暂停：透传给两个底层播放器
        -- 只有当前活动的那一个会真正暂停，另一个返回 false（无害）
        local animPaused = AnimationPlayer:Pause(ragdoll)
        local twitchPaused = TwitchController:Pause(ragdoll)

        if not animPaused and not twitchPaused then
            log.trace("PlaybackCoordinator:Pause no active playback for ragdoll: ", tostring(ragdoll))
            -- 即使当前没有活动播放器，pauseCount 仍保留
            -- 以便后续 Start 时自动继承暂停状态
        end
    end

    return true
end

--- 恢复播放（引用计数式）
--- 只有计数归零才真正恢复两个底层播放器。
--- 与 Pause 对称：调用方只需保证 Pause/Resume 配对。
--- @param ragdoll Entity
--- @return boolean 是否成功减少暂停计数
function PlaybackCoordinator:Resume(ragdoll)
    if not IsValid(ragdoll) then
        log.warn("PlaybackCoordinator:Resume invalid ragdoll")
        return false
    end

    local count = store:Get(ragdoll, PAUSE_KEY) or 0
    if count <= 0 then
        log.trace("PlaybackCoordinator:Resume no active pause for ragdoll: ", tostring(ragdoll))
        return false
    end

    count = count - 1
    store:Set(ragdoll, PAUSE_KEY, count)

    if count == 0 then
        -- 恢复两个底层播放器（只有活动那个会真正恢复）
        AnimationPlayer:Resume(ragdoll)
        TwitchController:Resume(ragdoll)
    end

    return true
end

--- 查询布娃娃当前是否处于暂停状态
--- @param ragdoll Entity
--- @return boolean
function PlaybackCoordinator:IsPaused(ragdoll)
    if not IsValid(ragdoll) then
        return false
    end
    return (store:Get(ragdoll, PAUSE_KEY) or 0) > 0
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

function PlaybackCoordinator:SetBoneSkip(ragdoll, boneName, skip, recursive)
    if not IsValid(ragdoll) then
        log.warn("PlaybackCoordinator:SetBoneSkip invalid ragdoll")
        return false
    end

    recursive = recursive or false

    -- 确定需要更新的骨骼名称列表
    local boneNamesToUpdate
    if recursive then
        boneNamesToUpdate = helper.GetBoneChain(ragdoll, boneName)
        if #boneNamesToUpdate == 0 then
            log.warn("PlaybackCoordinator:SetBoneSkip no valid bones found for root: ", boneName)
            return false
        end
    else
        boneNamesToUpdate = { boneName }
    end

    -- 更新持久化存储
    local skips = store:Get(ragdoll, BONE_SKIP_KEY) or {}
    for _, name in ipairs(boneNamesToUpdate) do
        skips[name] = skip and true or false
    end
    store:Set(ragdoll, BONE_SKIP_KEY, skips)

    -- 立即应用到当前活动动画（如果有），逐骨骼调用底层接口
    for _, name in ipairs(boneNamesToUpdate) do
        AnimationPlayer:SetBoneSkip(ragdoll, name, skip)
    end

    return true
end

--- 查询指定骨骼是否被跳过动画控制
--- 优先返回当前活动动画的状态；若无活动上下文，则返回持久化设置
--- @param ragdoll Entity 布娃娃实体
--- @param boneName string 完整骨骼名
--- @return boolean 是否跳过（true=跳过，false=未跳过或未设置）
function PlaybackCoordinator:IsBoneSkip(ragdoll, boneName)
    if not IsValid(ragdoll) then
        log.warn("PlaybackCoordinator:IsBoneSkip invalid ragdoll")
        return false
    end

    -- 1. 检查当前活动动画
    local activeSkip = AnimationPlayer:IsBoneSkip(ragdoll, boneName)
    if activeSkip then
        return true
    end

    -- 2. 回退到持久化存储
    local persistentSkips = store:Get(ragdoll, BONE_SKIP_KEY)
    if persistentSkips and persistentSkips[boneName] then
        return true
    end

    return false
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
