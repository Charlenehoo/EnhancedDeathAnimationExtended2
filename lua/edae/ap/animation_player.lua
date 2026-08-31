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

local function cleanUp(ctx)
    local animationModel = ctx.animationModel
    if IsValid(animationModel) then
        animationModel:Remove()
    end
end

local function playAnimationCoroutine(ctx)
    log.trace("playAnimationCoroutine started")
    local ragdoll = ctx.ragdoll
    local animationModel = ctx.animationModel

    ctx.initialBoneCount = #ctx.boneMap
    log.trace("Initial bone count: ", ctx.initialBoneCount)

    -- 辅助函数：判断动画是否应该终止（实体无效、停止信号、骨骼移除过多）
    local function shouldTerminate()
        return not IsValid(ragdoll) or
            not IsValid(animationModel) or
            ctx.stopSignal or
            ctx.initialBoneCount - #ctx.boneMap >= Constants.ANIMATION_PLAYER.MAX_ALLOWED_BONE_REMOVALS
    end

    -- 初始实体检查
    if shouldTerminate() then
        log.warn("Ragdoll or animation model invalid at start, cleaning up")
        cleanUp(ctx)
        return
    end

    helper.EnableMotion(ctx, false)
    coroutine.yield()

    helper.EnableMotion(ctx, true)
    coroutine.yield()

    animationModel:Fire("SetAnimation", ctx.animationName)
    coroutine.yield()

    -- 外层循环：控制播放总次数
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
            -- 处理当前帧的所有骨骼
            for i = #ctx.boneMap, 1, -1 do
                local bone = ctx.boneMap[i]
                local boneName = bone.boneName
                local amBoneID = bone.amBoneID
                local ragdollPhysObj = bone.ragdollPhysObj

                local amBonePos, amBoneAngle = animationModel:GetBonePosition(amBoneID)
                if not amBonePos then
                    log.warn("Cannot get bone position for ", boneName, ", removing from boneMap")
                    table.remove(ctx.boneMap, i)
                    continue
                end

                local refer = Vector(amBonePos.x, amBonePos.y, animationModel:GetPos().z)

                local tr1 = util.TraceLine({
                    start = refer + Constants.ANIMATION_PLAYER.GROUND_TRACE_UP_OFFSET,
                    endpos = refer + Constants.ANIMATION_PLAYER.GROUND_TRACE_DOWN_OFFSET,
                    mask = MASK_SOLID,
                    filter = { ragdoll, animationModel }
                })

                local hitDist = refer.z - tr1.HitPos.z
                local diff = hitDist - bone.lastHitZ

                bone.lastAddZ = diff + bone.lastAddZ
                bone.lastHitZ = hitDist

                if not bone.Fall and diff >= Constants.ANIMATION_PLAYER.FALL_HEIGHT_THRESHOLD then
                    bone.Fall = true
                    log.trace("Bone ", boneName, " fall detected (diff=", diff, "), removing")
                    table.remove(ctx.boneMap, i)
                    continue
                end

                local bone_pos = amBonePos - Vector(0, 0, bone.lastAddZ)

                local tr2 = util.TraceLine({
                    start = ragdollPhysObj:GetPos(),
                    endpos = bone_pos,
                    mask = MASK_ALL,
                    filter = { ragdoll, animationModel }
                })

                if tr2.Hit then
                    bone.HitWall = true
                    log.trace("Bone ", boneName, " hit wall, removing")
                    table.remove(ctx.boneMap, i)
                    continue
                end

                local shadowParams = ctx.shadowParamsTemplate
                shadowParams.pos = bone_pos
                shadowParams.angle = amBoneAngle
                ragdollPhysObj:Wake()
                ragdollPhysObj:ComputeShadowControl(shadowParams)
            end

            -- 让出协程，等待下一帧
            coroutine.yield()
        end

        -- 内层循环结束：检查是否因为停止信号或骨骼移除过多而需要终止整个播放
        if shouldTerminate() then
            log.trace("Termination condition met, breaking outer loop")
            break
        end

        -- 正常完成一次动画循环，重新定位动画模型并准备下一次循环
        local ragdollPos = ragdoll:GetPos()
        local trace = util.TraceLine({
            start = ragdollPos + Constants.ANIMATION_PLAYER.GROUND_TRACE_UP_OFFSET,
            endpos = ragdollPos + Constants.ANIMATION_PLAYER.GROUND_TRACE_DOWN_OFFSET,
            mask = MASK_SOLID,
            filter = { ragdoll, animationModel }
        })

        local groundPos = trace.Hit and trace.HitPos or ragdollPos
        animationModel:SetPos(groundPos + ctx.amDatumToPos)

        animationModel:Fire("SetAnimation", ctx.animationName)
        coroutine.yield()
    end

    hook.Run(Constants.Events.OnAnimationFinished, ragdoll, ctx.animationName)
    cleanUp(ctx)
end

function AnimationPlayer:Stop(ragdoll)
    local ctx = store:Get(ragdoll, Constants.ANIMATION_PLAYER.CONEXT_KEY)
    ctx.stopSignal = true
end

--- 播放动画
--- @param ragdoll Entity
--- @param animationName string
--- @param opts table|nil
---   opts.animationModelName string
---   opts.collisionStrategy table
---   opts.shadowParamsTemplate table
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

    local totalLoops = (opts.totalLoops ~= nil) and opts.totalLoops or Constants.ANIMATION_PLAYER.DEFAULT_TOTAL_LOOPS

    local ctx = {
        ragdoll                   = ragdoll,
        animationName             = animationName,
        datum                     = helper.GetStandPos(ragdoll),

        state                     = opts.state or "falling",
        damageContext             = opts.damageContext,

        totalLoops                = totalLoops,
        loopCount                 = 0,

        yaw                       = opts.yaw or ragdoll:GetAngles().yaw,
        animationModelName        = opts.animationModelName or Constants.ANIMATION_PLAYER.DEFAULT_ANIMATION_MODEL_NAME,

        -- ===============================
        -- 以下由 fillShadowParamsTemplate 填充
        shadowParamsTemplate      = opts.shadowParamsTemplate,
        -- ===============================

        -- ===============================
        -- 以下由 createAnimationModel 填充
        animationModel            = nil,
        -- ===============================

        -- ===============================
        -- 以下由 checkAnimationName 填充
        animationDuration         = nil,
        -- ===============================

        -- ===============================
        -- 以下由 alignAnimationModel 填充
        amDatumToPos              = nil,
        amDatumToPosZ             = nil,
        -- ===============================

        -- ===============================
        -- 以下由 makeBoneMap 填充
        ragdollPhysicsObjectCount = nil,
        boneMap                   = nil,
        amRefBoneID               = nil,
        -- ===============================

        -- ===============================
        -- 以下由 playAnimationCoroutine 填充
        animationEndTime          = nil,
        -- ===============================

        coro                      = nil,
        stopSignal                = nil,
    }

    if
        not helper.CreateAnimationModel(ctx) or
        not helper.CheckAnimationName(ctx) or
        not helper.AlignAnimationModel(ctx) or
        not helper.MakeBoneMap(ctx) or
        not helper.FillShadowParamsTemplate(ctx)
    then
        cleanUp(ctx)
        return nil
    end

    local coro = Scheduler:Start(playAnimationCoroutine, ctx)
    ctx.coro = coro

    store:Set(ragdoll, Constants.ANIMATION_PLAYER.CONEXT_KEY, ctx)
    return ctx
end

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = AnimationPlayer
return AnimationPlayer
