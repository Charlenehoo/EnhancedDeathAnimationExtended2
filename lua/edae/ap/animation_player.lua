-- lua/edae/ap/animation_player.lua
-- 动画播放器：负责创建动画模型，驱动布娃娃骨骼跟随动画
-- 底层只提供 Stop(ragdoll, reason) 接口，语义化别名（如 Cancel）由上层 Coordinator 提供
-- 停止后先清理上下文，再发出 OnAnimationFinished 事件

local MODULE_NAME = "AnimationPlayer"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants       = include("edae/config/constants.lua")
local log             = include("edae/log/init.lua")
local Scheduler       = include("edae/coroutine_scheduler.lua")
local helper          = include("edae/ap/helper.lua")
local EntityDataStore = include("edae/eds/entity_data_store.lua")

local store           = EntityDataStore:ForOwner(MODULE_NAME)

local AnimationPlayer = {}

-- 从给定位置向下追踪地面，返回命中位置或 nil
local function traceGroundBelow(startPos, filterEntities)
    local trace = util.TraceLine({
        start = startPos + Constants.ANIMATION_PLAYER.GROUND_TRACE_UP_OFFSET,
        endpos = startPos + Constants.ANIMATION_PLAYER.GROUND_TRACE_DOWN_OFFSET,
        mask = MASK_SOLID,
        filter = filterEntities
    })
    if trace.Hit then
        return trace.HitPos
    end
    return nil
end

local function alignAnimationModel(ctx)
    local animationModel = ctx.animationModel
    animationModel:SetAngles(Angle(0, ctx.yaw, 0))
    local groundPos = ctx.groundPos
    animationModel:SetPos(groundPos)
    return true
end

-- 安全清理：仅清除自己的上下文，防止误删新播放的上下文
local function cleanUp(ctx)
    local animationModel = ctx.animationModel
    if IsValid(animationModel) then
        animationModel:Remove()
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
    ctx.stopSignal = true
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
        if not IsValid(ragdoll) or not IsValid(animationModel) then
            stopReason = Constants.PlaybackReasons.FailedByFall
            return true
        end
        if ctx.stopSignal then
            stopReason = ctx.requestedStopReason or Constants.PlaybackReasons.Cancelled
            return true
        end
        if ctx.FallCount >= Constants.ANIMATION_PLAYER.FALL_LIMIT then
            stopReason = Constants.PlaybackReasons.FailedByFall
            return true
        end
        if ctx.HitWallCount >= ctx.totalBones then
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
            local HealthManager = include("edae/rm/health_manager.lua")
            local currentHealth = HealthManager:Get(ctx.ragdoll)
            if currentHealth <= 0 then
                stopReason = Constants.PlaybackReasons.InterruptedByHealthDepleted
                break
            end

            local initialHealth = ctx.initialHealth or HealthManager:Get(ctx.ragdoll)
            if initialHealth <= 0 then initialHealth = 1 end

            local rate = math.max(currentHealth / initialHealth, 0)
            local r = math.ease.InOutCubic(rate)

            local newPlaybackRate = math.max(ctx.basePlaybackRate * r * math.Rand(0.8, 1.2), 0.1)
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
        while not shouldTerminate() and CurTime() < ctx.animationEndTime do
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

                if not bone.Fall then
                    local boneName = bone.boneName
                    local amBoneID = bone.amBoneID
                    local ragdollPhysObj = bone.ragdollPhysObj

                    local amBonePos, amBoneAngle = animationModel:GetBonePosition(amBoneID)
                    if not amBonePos then
                        log.warn("Cannot get bone position for ", boneName, ", marking as Fall")
                        bone.Fall = true
                        ctx.FallCount = ctx.FallCount + 1
                        continue
                    end

                    local refer = Vector(amBonePos.x, amBonePos.y, animationModel:GetPos().z)
                    local groundPos = traceGroundBelow(refer, { ragdoll, animationModel })
                    if not groundPos then
                        bone.Fall = true
                        ctx.FallCount = ctx.FallCount + 1
                        log.trace("Bone ", boneName, " no ground found, marking as Fall")
                        continue
                    end

                    local hitDist = refer.z - groundPos.z
                    local diff = hitDist - bone.lastHitZ
                    bone.lastAddZ = diff + bone.lastAddZ
                    bone.lastHitZ = hitDist

                    if diff >= Constants.ANIMATION_PLAYER.FALL_HEIGHT_THRESHOLD then
                        bone.Fall = true
                        ctx.FallCount = ctx.FallCount + 1
                        log.trace("Bone ", boneName, " fall detected (diff=", diff, "), marking as Fall")
                        continue
                    end

                    local bone_pos = amBonePos - Vector(0, 0, bone.lastAddZ)

                    local tr = util.TraceLine({
                        start = ragdollPhysObj:GetPos(),
                        endpos = bone_pos,
                        mask = MASK_ALL,
                        filter = { ragdoll, animationModel }
                    })

                    if tr.Hit then
                        if not bone.HitWall then
                            bone.HitWall = true
                            ctx.HitWallCount = ctx.HitWallCount + 1
                            log.trace("Bone ", boneName, " hit wall, marking as HitWall")
                        end
                        continue
                    end

                    local shadowParams = ctx.shadowParamsTemplate
                    shadowParams.pos = bone_pos
                    shadowParams.angle = amBoneAngle
                    ragdollPhysObj:Wake()
                    ragdollPhysObj:ComputeShadowControl(shadowParams)
                end
            end

            coroutine.yield()
        end

        if shouldTerminate() then
            log.trace("Termination condition met, breaking outer loop")
            break
        end

        -- 正常完成一次循环，重新定位动画模型
        local ragdollPos = ragdoll:GetPos()
        local groundPos = traceGroundBelow(ragdollPos, { ragdoll, animationModel }) or ragdollPos
        animationModel:SetPos(groundPos)
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

    opts = opts or {}

    local groundPos
    if opts.groundPos then
        groundPos = opts.groundPos
    else
        local ragdollPos = ragdoll:GetPos()
        groundPos = traceGroundBelow(ragdollPos, { ragdoll }) or ragdollPos
    end

    local ctx = {
        ragdoll                   = ragdoll,
        animationName             = animationName,
        totalLoops                = opts.totalLoops or Constants.ANIMATION_PLAYER.DEFAULT_TOTAL_LOOPS,
        groundPos                 = groundPos,
        yaw                       = opts.yaw or ragdoll:GetAngles().yaw,
        animationModelName        = opts.animationModelName or Constants.ANIMATION_PLAYER.DEFAULT_ANIMATION_MODEL_NAME,
        enableHealthBasedSlowdown = opts.enableHealthBasedSlowdown or false,
        basePlaybackRate          = opts.basePlaybackRate or 1.0,
        preWait                   = opts.preWait,
        boneWhitelist             = opts.boneWhitelist,
        effects                   = opts.effects and table.Copy(opts.effects) or nil,
        effectStates              = {},

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
        stopSignal                = nil,
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

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = AnimationPlayer
return AnimationPlayer
