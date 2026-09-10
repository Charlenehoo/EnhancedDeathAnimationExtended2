-- lua/edae/playback/animation_player.lua
-- 动画播放器：负责创建动画模型，驱动布娃娃骨骼跟随动画
-- 底层只提供 Stop(ragdoll, reason) 接口，语义化别名（如 Cancel）由上层 Coordinator 提供
-- 停止后先清理上下文，再发出 OnAnimationFinished 事件
-- 支持 Pause / Resume：冻结动画模型时间轴，同时跳过 CSC；支持多源暂停（引用计数）

local MODULE_NAME = "AnimationPlayer"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants             = include("edae/core/constants.lua")
local log                   = include("edae/core/log/init.lua")
local Scheduler             = include("edae/core/coroutine_scheduler.lua")
local helper                = include("edae/playback/helper.lua")
local EntityDataStore       = include("edae/core/entity_data_store.lua")
local HealthManager         = include("edae/core/health_manager.lua")
local GroundStrategyBuilder = include("edae/playback/builders/ground_strategy_builder.lua")
local BoneControlManager    = include("edae/core/bone_control_manager.lua")

local store                 = EntityDataStore:ForOwner(MODULE_NAME)

local AnimationPlayer       = {}

local function alignAnimationModel(ctx)
    local animationModel = ctx.animationModel
    animationModel:SetAngles(Angle(0, ctx.yaw, 0))
    animationModel:SetPos(ctx.groundPos)
    return true
end

-- 安全清理：仅清除自己的上下文，防止误删新播放的上下文
local function cleanUp(ctx)
    local animationModel = ctx.animationModel
    if IsValid(animationModel) then
        animationModel:Remove()
    end

    -- 释放骨骼控制权
    if ctx.boneControlOwnerID then
        BoneControlManager:ReleaseAllBones(ctx.ragdoll, ctx.boneControlOwnerID)
    end

    -- 只有存储中的上下文还是当前 ctx 时才清除
    local currentCtx = store:Get(ctx.ragdoll, Constants.ANIMATION_PLAYER.CONEXT_KEY)
    if currentCtx == ctx then
        store:Clear(ctx.ragdoll)
    end
end

--- 停止动画播放
--- 底层唯一停止接口，接受原因字符串
--- @param ragdoll Entity
--- @param reason string 停止原因（Constants.PlaybackReasons 中的值）
--- @return boolean 是否找到并标记了活动上下文
function AnimationPlayer:Stop(ragdoll, reason)
    log.trace("AnimationPlayer:Stop called for ragdoll: ", tostring(ragdoll), " reason: ", tostring(reason))
    local ctx = store:Get(ragdoll, Constants.ANIMATION_PLAYER.CONEXT_KEY)
    if not ctx then
        log.trace("AnimationPlayer:Stop no active context for ragdoll: ", tostring(ragdoll))
        return false
    end

    ctx.requestedStopReason = reason or Constants.PlaybackReasons.Cancelled
    ctx.active = false
    return true
end

--- 暂停动画播放（引用计数式）
--- 首次暂停会冻结动画模型时间轴（SetPlaybackRate=0）并记录暂停起始时间；
--- 之后再次 Pause 只会增加计数，不会重复冻结。
--- 暂停期间主循环会跳过动画结束时间检查，避免长时间暂停导致动画被判定为“自然结束”。
--- @param ragdoll Entity
--- @return boolean 是否成功暂停
function AnimationPlayer:Pause(ragdoll)
    if not IsValid(ragdoll) then
        log.warn("AnimationPlayer:Pause invalid ragdoll")
        return false
    end

    local ctx = store:Get(ragdoll, Constants.ANIMATION_PLAYER.CONEXT_KEY)
    if not ctx then
        log.trace("AnimationPlayer:Pause no active context for ragdoll: ", tostring(ragdoll))
        return false
    end

    ctx.pauseCount = (ctx.pauseCount or 0) + 1

    if ctx.pauseCount == 1 then
        ctx.paused         = true
        ctx.pauseStartTime = CurTime()
        if IsValid(ctx.animationModel) then
            ctx.animationModel:Fire("SetPlaybackRate", 0)
        end
        log.trace("AnimationPlayer:Pause ragdoll ", tostring(ragdoll), " paused")
    end

    return true
end

--- 恢复动画播放（引用计数式）
--- 只有计数归零才真正恢复；恢复时会补偿 animationEndTime，
--- 使“暂停时长”不计入动画的总播放窗口。
--- @param ragdoll Entity
--- @return boolean 是否成功恢复
function AnimationPlayer:Resume(ragdoll)
    if not IsValid(ragdoll) then
        log.warn("AnimationPlayer:Resume invalid ragdoll")
        return false
    end

    local ctx = store:Get(ragdoll, Constants.ANIMATION_PLAYER.CONEXT_KEY)
    if not ctx or not ctx.pauseCount or ctx.pauseCount <= 0 then
        log.trace("AnimationPlayer:Resume no active pause for ragdoll: ", tostring(ragdoll))
        return false
    end

    ctx.pauseCount = ctx.pauseCount - 1

    if ctx.pauseCount == 0 then
        local pauseDuration = CurTime() - (ctx.pauseStartTime or CurTime())

        -- 补偿动画结束时间：暂停期间 CurTime 继续走，会把“剩余播放窗口”错误地吃掉
        if ctx.animationEndTime then
            ctx.animationEndTime = ctx.animationEndTime + pauseDuration
        end

        ctx.paused         = false
        ctx.pauseStartTime = nil

        if IsValid(ctx.animationModel) then
            -- 恢复时使用当前生效的播放速率（可能被血量驱动减慢过）
            local rate = ctx.currentPlaybackRate or ctx.basePlaybackRate or 1.0
            ctx.animationModel:Fire("SetPlaybackRate", rate)
        end

        log.trace("AnimationPlayer:Resume ragdoll ", tostring(ragdoll), " resumed after ", pauseDuration, "s")
    end

    return true
end

-- 旋转效果器：每帧检查旋转目标并调用 Helper 中的旋转算法
local function BuildRotateEffect()
    return {
        name = "rotate_control",
        predicate = function(ctx, state)
            return ctx.rotateTargetYaw ~= nil or ctx.rotateTargetPos ~= nil
        end,
        action = function(ctx, state)
            helper.RotateAnimationModel(
                ctx,
                ctx.rotateTargetYaw,
                ctx.rotateTargetPos,
                ctx.rotateMaxTurnSpeed
            )
        end
    }
end

local function playAnimationCoroutine(ctx)
    log.trace("playAnimationCoroutine started")
    local ragdoll = ctx.ragdoll
    local animationModel = ctx.animationModel

    ctx.totalBones = #ctx.boneMap
    ctx.FallCount = 0
    ctx.HitWallCount = 0

    local stopReason = Constants.PlaybackReasons.CompletedNormally

    local function shouldTerminate()
        -- ========================================================================
        -- 硬条件：逻辑层面的终止，暂停期间也检查
        -- ------------------------------------------------------------------------
        -- 暂停只冻结"表现"（CSC、动画时间轴），不冻结"逻辑"。
        -- 所以实体失效、外部 Stop、血量耗尽这三类条件在暂停期间仍然生效，
        -- 从而保证：暂停期间被外部打死、被删除实体、被 Stop，状态机都能正常推进。
        -- ========================================================================

        if not IsValid(ragdoll) or not IsValid(animationModel) then
            stopReason = Constants.PlaybackReasons.FailedByFall
            return true
        end

        if not ctx.active then
            stopReason = ctx.requestedStopReason or Constants.PlaybackReasons.Cancelled
            return true
        end

        if HealthManager:IsDead(ragdoll) then
            stopReason = Constants.PlaybackReasons.InterruptedByHealthDepleted
            return true
        end

        -- ========================================================================
        -- 软条件：依赖 CSC 循环产生的计数或 activeBoneCount，暂停期间跳过
        -- ------------------------------------------------------------------------
        -- 理由：
        --   * FallCount / HitWallCount 由 CSC 循环累积，暂停期间不增长；
        --     暂停前若已 >= 阈值，早就该终止；暂停前若 < 阈值，暂停后仍 < 阈值。
        --     所以跳过不影响语义。
        --   * activeBoneCount 会因骨骼抢占而改变。例如 StiffOverlay 暂停
        --     AnimationPlayer 并抢走全部骨骼后，所有骨骼 skip = true，
        --     activeBoneCount 变成 0，导致 HitWallCount (>= 0) 恒成立，
        --     播放器会被误判为"撞墙"而提前终止——这不是我们想要的。
        -- ========================================================================

        if ctx.paused then
            return false
        end

        if ctx.FallCount >= Constants.ANIMATION_PLAYER.FALL_LIMIT then
            stopReason = Constants.PlaybackReasons.FailedByFall
            return true
        end

        local activeBoneCount = 0
        for _, b in ipairs(ctx.boneMap) do
            if not b.skip and not b.Fall then
                activeBoneCount = activeBoneCount + 1
            end
        end
        if ctx.HitWallCount >= activeBoneCount then
            stopReason = Constants.PlaybackReasons.FailedByHitWall
            return true
        end

        return false
    end

    helper.EnableMotion(ctx, false)
    coroutine.yield()

    helper.EnableMotion(ctx, true)
    coroutine.yield()

    if ctx.preWait then
        for _, waitFunc in ipairs(ctx.preWait) do
            waitFunc(ctx)
        end
    end

    animationModel:Fire("SetAnimation", ctx.animationName, 0)
    Scheduler:Wait(0.15)

    -- 外层循环：控制总播放次数
    while not shouldTerminate() do
        if ctx.totalLoops > 0 and ctx.loopCount >= ctx.totalLoops then
            log.trace("Reached total loops limit, stopping")
            break
        end

        ctx.loopCount = ctx.loopCount + 1
        log.trace("Loop: ", ctx.loopCount, "/", ctx.totalLoops)

        -- 血量驱动减慢逻辑（仅挣扎状态启用）
        if ctx.enableHealthBasedSlowdown then
            local currentHealth = HealthManager:Get(ctx.ragdoll)
            local initialHealth = ctx.initialHealth or HealthManager:Get(ctx.ragdoll)
            if initialHealth <= 0 then initialHealth = 1 end

            local rate = math.max(currentHealth / initialHealth, 0)
            local r = math.ease.InOutCubic(rate)

            local newPlaybackRate = math.max(ctx.basePlaybackRate * r * math.Rand(0.8, 1.2), 0.1)
            ctx.currentPlaybackRate = newPlaybackRate -- 记录，供 Resume 恢复
            ctx.animationDuration = ctx.baseAnimationDuration / newPlaybackRate
            ctx.animationModel:Fire("SetPlaybackRate", newPlaybackRate)

            if ctx.baseShadowParams then
                ctx.shadowParamsTemplate.maxangular = math.max(
                    ctx.baseShadowParams.maxangular * r * math.Rand(0.8, 1.2),
                    80
                )
                ctx.shadowParamsTemplate.secondstoarrive = ctx.baseShadowParams.secondstoarrive *
                    (-0.5 * r + 1.5) * math.Rand(0.9, 1.1)
            end
        end

        ctx.animationModel:Fire("SetAnimation", ctx.animationName, 0)
        Scheduler:Wait(0.15)
        ctx.animationEndTime = CurTime() + ctx.animationDuration

        -- 内层循环：播放单次动画
        -- 条件拆开：先检查终止，再检查暂停，最后检查动画结束
        while not shouldTerminate() do
            -- 暂停状态：仅 yield，不检查动画结束时间，不执行效果器和 CSC
            -- Resume 时会补偿 animationEndTime，因此这里不需要额外记录已流失的时间
            if ctx.paused then
                coroutine.yield()
                continue
            end

            -- 动画结束检查：只有在未暂停时才生效
            if CurTime() >= ctx.animationEndTime then
                break
            end

            -- 执行效果器
            if ctx.effects then
                for idx, effect in ipairs(ctx.effects) do
                    local stateKey = effect.name or idx
                    local effectState = ctx.effectStates[stateKey]
                    if not effectState then
                        effectState = {}
                        ctx.effectStates[stateKey] = effectState
                    end

                    if effect.predicate(ctx, effectState) then
                        effect.action(ctx, effectState)
                    end
                end
            end

            -- 遍历骨骼
            for i = 1, #ctx.boneMap do
                local bone = ctx.boneMap[i]

                -- 1. 跳过被显式禁用的骨骼
                if bone.skip then
                    continue
                end

                -- 2. 跳过已失效的骨骼（之前已标记为 Fall）
                if bone.Fall then
                    continue
                end

                local boneName = bone.boneName
                local amBoneID = bone.amBoneID
                local ragdollPhysObj = bone.ragdollPhysObj

                -- 3. 获取动画模型骨骼位置
                local amBonePos, amBoneAngle = animationModel:GetBonePosition(amBoneID)
                if not amBonePos then
                    log.warn("Cannot get bone position for ", boneName, ", marking as Fall")
                    bone.Fall = true
                    ctx.FallCount = ctx.FallCount + 1
                    if ctx.boneControlOwnerID then
                        BoneControlManager:ReleaseBones(
                            ctx.ragdoll,
                            ctx.boneControlOwnerID,
                            { [boneName] = true }
                        )
                    end
                    continue
                end

                -- 4-6. 调用骨骼处理策略（地面检测、高度修正、墙壁检测）
                local shouldContinue, targetPos = ctx.boneStrategy(ctx, bone, amBonePos, amBoneAngle)
                if not shouldContinue then
                    if bone.Fall then
                        if ctx.boneControlOwnerID then
                            BoneControlManager:ReleaseBones(
                                ctx.ragdoll,
                                ctx.boneControlOwnerID,
                                { [boneName] = true }
                            )
                        end
                    end
                    continue
                end

                -- 7. 正常驱动骨骼
                local shadowParams = ctx.shadowParamsTemplate
                shadowParams.pos = targetPos
                shadowParams.angle = amBoneAngle
                ragdollPhysObj:Wake()
                ragdollPhysObj:ComputeShadowControl(shadowParams)
            end

            coroutine.yield()
        end

        if shouldTerminate() then
            log.trace("Termination condition met, breaking outer loop")
            break
        end

        -- 正常完成一次循环，重新定位动画模型
        local newGroundPos = ctx.repositionStrategy(ctx)
        animationModel:SetPos(newGroundPos)
        animationModel:Fire("SetAnimation", ctx.animationName, 0)
        Scheduler:Wait(0.15)
    end

    -- 先清理，再发射事件，确保状态机启动新播放时旧上下文已清除
    cleanUp(ctx)
    hook.Run(Constants.Events.OnAnimationFinished, ragdoll, ctx.animationName, stopReason)
end

--- 播放动画
--- @param ragdoll Entity
--- @param animationName string
--- @param opts table|nil 可选参数，包含动画模型名、总循环次数、预等待、效果器等
--- @return boolean 是否成功启动
function AnimationPlayer:Play(ragdoll, animationName, opts)
    if not IsValid(ragdoll) then
        log.warn("Invalid ragdoll: ", tostring(ragdoll))
        return false
    end

    if not animationName then
        log.warn("No animationName")
        return false
    end

    opts            = opts or {}

    -- 如果未提供 groundPos，则直接使用布娃娃位置（不应发生，因为 Assembler 总会传入）
    local groundPos = opts.groundPos or ragdoll:GetPos()
    local baseRate  = opts.basePlaybackRate or 1.0

    local ctx       = {
        ragdoll                   = ragdoll,
        animationName             = animationName,
        totalLoops                = opts.totalLoops or Constants.ANIMATION_PLAYER.DEFAULT_TOTAL_LOOPS,
        groundPos                 = groundPos,
        yaw                       = opts.yaw or ragdoll:GetAngles().yaw,
        animationModelName        = opts.animationModelName or Constants.ANIMATION_PLAYER.DEFAULT_ANIMATION_MODEL_NAME,
        enableHealthBasedSlowdown = opts.enableHealthBasedSlowdown or false,
        basePlaybackRate          = baseRate,
        currentPlaybackRate       = baseRate, -- 当前生效速率，暂停恢复时使用
        preWait                   = opts.preWait,
        boneWhitelist             = opts.boneWhitelist,
        persistentSkipBones       = opts.persistentSkipBones,
        effects                   = opts.effects and table.Copy(opts.effects) or nil,
        effectStates              = {},
        boneStrategy              = opts.boneStrategy or GroundStrategyBuilder.DefaultBoneStrategy,
        repositionStrategy        = opts.repositionStrategy or GroundStrategyBuilder.DefaultRepositionStrategy,

        rotateTargetYaw           = nil,
        rotateTargetPos           = nil,
        rotateMaxTurnSpeed        = opts.rotateMaxTurnSpeed or 360,
        anchorPosGetter           = nil,
        enableRotate              = opts.enableRotate or false,

        shadowParamsTemplate      = opts.shadowParamsTemplate,
        baseShadowParams          = nil,
        animationModel            = nil,
        animationDuration         = nil,
        baseAnimationDuration     = nil,
        ragdollPhysicsObjectCount = nil,
        boneMap                   = nil,
        amRefBoneID               = nil,
        animationEndTime          = nil,
        loopCount                 = 0,
        totalBones                = 0,
        FallCount                 = 0,
        HitWallCount              = 0,
        coro                      = nil,
        active                    = true,
        boneControlOwnerID        = nil, -- 骨骼控制管理器中的所有者 ID

        -- 暂停相关
        paused                    = false,
        pauseCount                = 0,
        pauseStartTime            = nil,
    }

    if
        not helper.CreateAnimationModel(ctx) or
        not helper.CheckAnimationName(ctx) or
        not alignAnimationModel(ctx) or
        not helper.MakeBoneMap(ctx) or
        not helper.FillShadowParamsTemplate(ctx)
    then
        cleanUp(ctx)
        return false
    end

    ctx.anchorPosGetter = helper.CreateAnchorPositionGetter(ctx.animationModel, ragdoll)

    if ctx.enableRotate then
        ctx.effects = ctx.effects or {}
        table.insert(ctx.effects, BuildRotateEffect())
    end

    -- 集成 BoneControlManager：申请骨骼控制权
    local ownerID = MODULE_NAME
    ctx.boneControlOwnerID = ownerID

    -- 收集需要控制的骨骼（排除 persistentSkipBones 中明确跳过的）
    local allBones = {}
    for _, bone in ipairs(ctx.boneMap) do
        local skipPermanent = ctx.persistentSkipBones and ctx.persistentSkipBones[bone.boneName]
        if not skipPermanent then
            allBones[bone.boneName] = true
        end
    end

    if table.Count(allBones) > 0 then
        local isActiveFunc = function()
            return ctx.coro and coroutine.status(ctx.coro) ~= "dead"
        end

        local function setBoneSkipByName(boneName, skip)
            for _, bone in ipairs(ctx.boneMap) do
                if bone.boneName == boneName then
                    bone.skip = skip
                    break
                end
            end
        end

        local acquired = BoneControlManager:RequestBones(
            ragdoll,
            ownerID,
            allBones,
            Constants.BoneControlPriority.AnimationPlayer, -- 基础动画优先级
            isActiveFunc,
            function(owner, boneName)                      -- onGranted
                setBoneSkipByName(boneName, false)
            end,
            function(owner, boneName) -- onLost
                setBoneSkipByName(boneName, true)
            end
        )

        -- 初始化 skip 状态：未获得的骨骼立即 skip
        for _, bone in ipairs(ctx.boneMap) do
            if ctx.persistentSkipBones and ctx.persistentSkipBones[bone.boneName] then
                bone.skip = true
            elseif not acquired[bone.boneName] then
                bone.skip = true
            else
                bone.skip = false
            end
        end
    else
        -- 没有需要控制的骨骼（全部被持久跳过）
        for _, bone in ipairs(ctx.boneMap) do
            bone.skip = true
        end
    end

    local coro = Scheduler:Start(playAnimationCoroutine, ctx)
    ctx.coro = coro

    store:Set(ragdoll, Constants.ANIMATION_PLAYER.CONEXT_KEY, ctx)
    return true
end

--- 请求布娃娃旋转到指定方向或背对指定位置
--- @param ragdoll Entity 布娃娃实体
--- @param targetYaw number|nil 目标绝对 Yaw 角（度）
--- @param targetPos Vector|nil 目标位置（布娃娃将背对该位置）
--- @param maxTurnSpeed number|nil 最大角速度（度/秒），nil 表示瞬时旋转
--- @return boolean 是否成功记录旋转请求
function AnimationPlayer:Rotate(ragdoll, targetYaw, targetPos, maxTurnSpeed)
    local ctx = store:Get(ragdoll, Constants.ANIMATION_PLAYER.CONEXT_KEY)
    if not ctx then
        log.warn("AnimationPlayer:Rotate called but no active context for ragdoll")
        return false
    end

    ctx.rotateTargetYaw = targetYaw
    ctx.rotateTargetPos = targetPos
    if maxTurnSpeed then
        ctx.rotateMaxTurnSpeed = maxTurnSpeed
    end

    return true
end

--- 以增量方式旋转布娃娃（基于当前朝向增加角度）
--- @param ragdoll Entity 布娃娃实体
--- @param deltaYaw number 旋转增量（度，正为逆时针，负为顺时针）
--- @param maxTurnSpeed number|nil 最大角速度（度/秒），nil 表示瞬时旋转
--- @return boolean 是否成功记录旋转请求
function AnimationPlayer:RotateBy(ragdoll, deltaYaw, maxTurnSpeed)
    local ctx = store:Get(ragdoll, Constants.ANIMATION_PLAYER.CONEXT_KEY)
    if not ctx then
        log.warn("AnimationPlayer:RotateBy called but no active context for ragdoll")
        return false
    end
    if not IsValid(ctx.animationModel) then
        return false
    end

    local currentYaw = ctx.animationModel:GetAngles().yaw
    local targetYaw = currentYaw + deltaYaw

    return self:Rotate(ragdoll, targetYaw, nil, maxTurnSpeed)
end

--- 设置指定骨骼是否跳过动画控制（已弃用，请使用 BoneControlManager）
--- @param ragdoll Entity 布娃娃实体
--- @param boneName string 完整骨骼名（如 "ValveBiped.Bip01_Head1"）
--- @param skip boolean 是否跳过（true=跳过，false=恢复控制）
--- @return boolean 是否成功找到并修改了该骨骼
function AnimationPlayer:SetBoneSkip(ragdoll, boneName, skip)
    log.warn("AnimationPlayer:SetBoneSkip is deprecated. Use BoneControlManager instead.")
    local ctx = store:Get(ragdoll, Constants.ANIMATION_PLAYER.CONEXT_KEY)
    if not ctx or not ctx.boneMap then
        log.warn("AnimationPlayer:SetBoneSkip no active context or boneMap for ragdoll: ", tostring(ragdoll))
        return false
    end

    for _, bone in ipairs(ctx.boneMap) do
        if bone.boneName == boneName then
            bone.skip = skip and true or false
            return true
        end
    end

    return false
end

--- 查询指定骨骼是否被跳过动画控制（已弃用）
--- @param ragdoll Entity 布娃娃实体
--- @param boneName string 完整骨骼名（如 "ValveBiped.Bip01_Head1"）
--- @return boolean 是否跳过（true=跳过，false=未跳过或未找到）
function AnimationPlayer:IsBoneSkip(ragdoll, boneName)
    log.warn("AnimationPlayer:IsBoneSkip is deprecated.")
    local ctx = store:Get(ragdoll, Constants.ANIMATION_PLAYER.CONEXT_KEY)
    if not ctx or not ctx.boneMap then
        return false
    end

    for _, bone in ipairs(ctx.boneMap) do
        if bone.boneName == boneName then
            return bone.skip or false
        end
    end

    return false
end

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = AnimationPlayer
return AnimationPlayer
