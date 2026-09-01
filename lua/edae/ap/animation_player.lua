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

    animationModel:SetAngles(Angle(0, ctx.yaw, 0))

    local persistedDatumToPos = store:Get(ragdoll, Constants.ANIMATION_PLAYER.AM_DATUM_TO_POS_KEY)

    if persistedDatumToPos then
        local groundPos = traceGroundBelow(ragdoll:GetPos(), { ragdoll, animationModel })
        if not groundPos then
            log.warn("Cannot find ground below ragdoll for alignment")
            return false
        end

        animationModel:SetPos(groundPos + persistedDatumToPos)
        ctx.amDatumToPos = persistedDatumToPos

        log.trace("Animation model aligned using persisted datumToPos: ", tostring(persistedDatumToPos))
        return true
    else
        local animationModelDatum = helper.GetStandPos(animationModel)
        if not animationModelDatum then
            log.warn("Cannot find stand pos for animationModel")
            return false
        end

        local datumToPos = animationModel:GetPos() - animationModelDatum

        store:Set(ragdoll, Constants.ANIMATION_PLAYER.AM_DATUM_TO_POS_KEY, datumToPos)

        animationModel:SetPos(ctx.datum + datumToPos)

        ctx.amDatumToPos = datumToPos

        log.trace("Animation model aligned first time, datumToPos stored: ", tostring(datumToPos))
        return true
    end
end

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

    ctx.totalBones = #ctx.boneMap
    ctx.FallCount = 0
    ctx.HitWallCount = 0

    -- 终止条件：实体无效、停止信号、Fall 计数达到限制、HitWall 计数达到总骨骼数
    local function shouldTerminate()
        return not IsValid(ragdoll) or
            not IsValid(animationModel) or
            ctx.stopSignal or
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

    animationModel:Fire("SetAnimation", ctx.animationName)
    coroutine.yield()

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
                    -- 效果器的私有状态表，以 effect.name 或索引为键
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

                    -- 复用 traceGroundBelow 获取 refer 下方的地面位置
                    local groundPos = traceGroundBelow(refer, { ragdoll, animationModel })
                    if not groundPos then
                        -- 如果找不到地面，视为 Fall
                        bone.Fall = true
                        ctx.FallCount = ctx.FallCount + 1
                        log.trace("Bone ", boneName, " no ground found, marking as Fall")
                        continue
                    end

                    local hitDist = refer.z - groundPos.z
                    local diff = hitDist - bone.lastHitZ

                    bone.lastAddZ = diff + bone.lastAddZ
                    bone.lastHitZ = hitDist

                    -- Fall 检测：高度差突变，放弃控制该骨骼
                    if diff >= Constants.ANIMATION_PLAYER.FALL_HEIGHT_THRESHOLD then
                        bone.Fall = true
                        ctx.FallCount = ctx.FallCount + 1
                        log.trace("Bone ", boneName, " fall detected (diff=", diff, "), marking as Fall")
                        continue
                    end

                    local bone_pos = amBonePos - Vector(0, 0, bone.lastAddZ)

                    -- 障碍物检测（HitWall）
                    local tr = util.TraceLine({
                        start = ragdollPhysObj:GetPos(),
                        endpos = bone_pos,
                        mask = MASK_ALL,
                        filter = { ragdoll, animationModel }
                    })

                    if tr.Hit then
                        -- 只计数一次，但骨骼不删除，仅跳过本帧控制
                        if not bone.HitWall then
                            bone.HitWall = true
                            ctx.HitWallCount = ctx.HitWallCount + 1
                            log.trace("Bone ", boneName, " hit wall, marking as HitWall")
                        end
                        continue
                    end

                    -- 正常执行控制
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

        animationModel:Fire("SetAnimation", ctx.animationName)
        coroutine.yield()
    end

    hook.Run(Constants.Events.OnAnimationFinished, ragdoll, ctx.animationName)
    cleanUp(ctx)
end

function AnimationPlayer:Stop(ragdoll)
    local ctx = store:Get(ragdoll, Constants.ANIMATION_PLAYER.CONEXT_KEY)
    if ctx then
        ctx.stopSignal = true
    end
end

--- 播放动画
--- @param ragdoll Entity
--- @param animationName string
--- @param opts table|nil
---   opts.animationModelName string
---   opts.shadowParamsTemplate table
---   opts.preWait table|nil 等待函数数组，每个函数接收 ctx
---   opts.effects table|nil 效果器数组，每个效果器格式：{ name = "string", predicate = function(ctx, state), action = function(ctx, state) }
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
        effectStates              = {}, -- 效果器私有状态存储（键：effect.name 或索引）

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
        loopCount                 = 0,
        totalBones                = 0,
        FallCount                 = 0,
        HitWallCount              = 0,
        -- ===============================

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
        return nil
    end

    local coro = Scheduler:Start(playAnimationCoroutine, ctx)
    ctx.coro = coro

    store:Set(ragdoll, Constants.ANIMATION_PLAYER.CONEXT_KEY, ctx)
    return ctx
end

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = AnimationPlayer
return AnimationPlayer
