local MODULE_NAME = "AnimationPlayer"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants       = include("edae/config/constants.lua")
local log             = include("edae/log/init.lua")
local Scheduler       = include("edae/cs/coroutine_scheduler.lua")
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
    local ragdoll = ctx.ragdoll

    -- 0. 旋转对齐 yaw
    animationModel:SetAngles(Angle(0, ctx.yaw, 0))

    -- 1. 从 ragdoll:GetPos() 向下打射线获得地面位置
    local groundPos = traceGroundBelow(ragdoll:GetPos(), { ragdoll, animationModel })
    if not groundPos then
        log.warn("Cannot find ground below ragdoll for alignment")
        return false
    end

    -- 2. 获取 animationModel 的脚底到模型原点的偏移（datumToPos）
    local footPos = helper.GetStandPos(animationModel)
    if not footPos then
        log.warn("Cannot find stand pos for animationModel")
        return false
    end
    local datumToPos = animationModel:GetPos() - footPos -- 模型原点 - 脚底 = 偏移

    -- 3. 设置动画模型位置，使脚底与地面点重合
    animationModel:SetPos(groundPos + datumToPos)

    -- 记录偏移供旋转算法使用
    ctx.amDatumToPos = datumToPos
    return true
end

local function cleanUp(ctx)
    local animationModel = ctx.animationModel
    if IsValid(animationModel) then
        animationModel:Remove()
    end
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
            -- 旋转目标持续有效，由外部更新或清除
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

    -- 终止条件：实体无效、停止信号、Fall 计数达到限制、HitWall 计数达到总骨骼数
    local function shouldTerminate()
        return not IsValid(ragdoll) or
            not IsValid(animationModel) or
            ctx.FallCount >= Constants.ANIMATION_PLAYER.FALL_LIMIT or
            ctx.HitWallCount >= ctx.totalBones
    end

    if shouldTerminate() then
        log.warn("Ragdoll or animation model invalid at start, cleaning up")
        cleanUp(ctx)
        return
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

        ctx.animationEndTime = CurTime() + ctx.animationDuration

        -- 内层循环：播放单次动画
        while not shouldTerminate() and CurTime() < ctx.animationEndTime do
            -- 执行效果器（谓词 + 动作）
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

            -- 遍历所有骨骼（跳过已标记 Fall 的骨骼）
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

                    -- 高度修正计算（与原版一致）
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
        animationModel:SetPos(groundPos + ctx.amDatumToPos)

        animationModel:Fire("SetAnimation", ctx.animationName, 0)
        Scheduler:Wait(0.15)
    end

    hook.Run(Constants.Events.OnAnimationFinished, ragdoll, ctx.animationName)
    cleanUp(ctx)
end

function AnimationPlayer:Stop(ragdoll)
    local ctx = store:Get(ragdoll, Constants.ANIMATION_PLAYER.CONEXT_KEY)
    if not ctx then return end

    if ctx.coro and coroutine.status(ctx.coro) ~= "dead" then
        Scheduler:Cancel(ctx.coro)
    end

    cleanUp(ctx)

    store:Clear(ragdoll)
end

--- 播放动画
--- @param ragdoll Entity
--- @param animationName string
--- @param opts table|nil
---   opts.animationModelName string
---   opts.shadowParamsTemplate table
---   opts.preWait table|nil 等待函数数组，每个函数接收 ctx
---   opts.effects table|nil 效果器数组，每个效果器格式：{ name = "string", predicate = function(ctx, state), action = function(ctx, state) }
---   opts.enableRotate boolean 是否启用旋转功能，默认 false
---   opts.rotateMaxTurnSpeed number|nil 最大旋转角速度（度/秒），nil 表示瞬时旋转
function AnimationPlayer:Play(ragdoll, animationName, opts)
    if not IsValid(ragdoll) then
        log.warn("Invalid ragdoll: ", tostring(ragdoll))
        return nil
    end

    if not animationName then
        log.warn("No animationName")
        return nil
    end

    opts = opts or {}

    local ctx = {
        ragdoll                   = ragdoll,
        animationName             = animationName,
        datum                     = helper.GetStandPos(ragdoll),

        totalLoops                = opts.totalLoops or Constants.ANIMATION_PLAYER.DEFAULT_TOTAL_LOOPS,
        yaw                       = opts.yaw or ragdoll:GetAngles().yaw,
        animationModelName        = opts.animationModelName or Constants.ANIMATION_PLAYER.DEFAULT_ANIMATION_MODEL_NAME,
        preWait                   = opts.preWait,
        boneWhitelist             = opts.boneWhitelist,
        effects                   = opts.effects,
        effectStates              = {},

        -- 旋转相关字段
        rotateTargetYaw           = nil,
        rotateTargetPos           = nil,
        rotateMaxTurnSpeed        = opts.rotateMaxTurnSpeed or 360, -- 默认瞬时旋转
        anchorPosGetter           = nil,                            -- 将在模型创建后设置
        enableRotate              = opts.enableRotate or false,

        shadowParamsTemplate      = opts.shadowParamsTemplate,
        animationModel            = nil,
        animationDuration         = nil,
        amDatumToPos              = nil,
        ragdollPhysicsObjectCount = nil,
        boneMap                   = nil,
        amRefBoneID               = nil,
        animationEndTime          = nil,
        loopCount                 = 0,
        totalBones                = 0,
        FallCount                 = 0,
        HitWallCount              = 0,
        coro                      = nil,
    }

    if
        not helper.CreateAnimationModel(ctx) or
        not helper.CheckAnimationName(ctx) or
        not alignAnimationModel(ctx) or
        not helper.MakeBoneMap(ctx) or
        not helper.FillShadowParamsTemplate(ctx)
    then
        cleanUp(ctx)
        return nil
    end

    -- 创建锚点获取闭包
    ctx.anchorPosGetter = helper.CreateAnchorPositionGetter(ctx.animationModel, ragdoll)

    -- 如果启用旋转，添加旋转效果器
    if ctx.enableRotate then
        ctx.effects = ctx.effects or {}
        table.insert(ctx.effects, BuildRotateEffect())
    end

    local coro = Scheduler:Start(playAnimationCoroutine, ctx)
    ctx.coro = coro

    store:Set(ragdoll, Constants.ANIMATION_PLAYER.CONEXT_KEY, ctx)
    return ctx
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

    -- 获取当前实际朝向
    local currentYaw = ctx.animationModel:GetAngles().yaw
    local targetYaw = currentYaw + deltaYaw

    -- 调用绝对旋转接口
    return self:Rotate(ragdoll, targetYaw, nil, maxTurnSpeed)
end

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = AnimationPlayer
return AnimationPlayer
