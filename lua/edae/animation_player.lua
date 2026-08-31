local MODULE_NAME = "AnimationPlayer"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants = include("edae/constants.lua")
local log = include("log/init.lua")
local Scheduler = include("edae/coroutine_scheduler.lua")
local helper = include("edae/helper.lua")

local AnimationPlayer = {}

local function cleanUp(ctx)
    local animationModel = ctx.animationModel
    if IsValid(animationModel) then
        animationModel:Remove()
    end

    local gravityProxy = ctx.gravityProxy
    if IsValid(gravityProxy) then
        gravityProxy:Remove()
    end
end

local function enableMotion(ctx, enable)
    for ragdollPhysObjNum = 0, ctx.ragdollPhysicsObjectCount - 1 do
        local ragdollPhysObj = ctx.ragdoll:GetPhysicsObjectNum(ragdollPhysObjNum)
        if not ragdollPhysObj then continue end
        ragdollPhysObj:EnableMotion(enable)
        if enable then
            ragdollPhysObj:Wake()
        end
    end
end

local function playAnimationCoroutine(ctx)
    log.trace("playAnimationCoroutine started")
    local ragdoll = ctx.ragdoll
    local animationModel = ctx.animationModel

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

    enableMotion(ctx, false)
    coroutine.yield()

    enableMotion(ctx, true)
    coroutine.yield()

    animationModel:Fire("SetAnimation", ctx.animationName)
    coroutine.yield()

    ctx.initialBoneCount = #ctx.boneMap
    log.trace("Initial bone count: ", ctx.initialBoneCount)

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

    log.trace("playAnimationCoroutine ended")
    cleanUp(ctx)
end

local function fillShadowParamsTemplate(ctx)
    local shadowParams = table.Copy(Constants.ANIMATION_PLAYER_SHADOW_PARAMS_TEMPLATE)
    if ctx.shadowParamsTemplate then
        for k, v in pairs(ctx.shadowParamsTemplate) do
            shadowParams[k] = v
        end
    end
    ctx.shadowParamsTemplate = shadowParams

    return true
end

local function makeBoneMap(ctx)
    local ragdoll = ctx.ragdoll

    local ragdollPhysicsObjectCount = ragdoll:GetPhysicsObjectCount()
    if not ragdollPhysicsObjectCount or ragdollPhysicsObjectCount < 1 then return false end
    ctx.ragdollPhysicsObjectCount = ragdollPhysicsObjectCount

    ctx.boneMap = {}
    for ragdollPhysObjNum = 0, ragdollPhysicsObjectCount - 1 do
        local ragdollBoneID = ragdoll:TranslatePhysBoneToBone(ragdollPhysObjNum)
        if not ragdollBoneID then continue end

        -- "__INVALIDBONE__" in case the name cannot be read or the index is out of range, or we failed or entity doesn't have a model.
        local boneName = ragdoll:GetBoneName(ragdollBoneID)

        -- Index of the given bone name, or nil if the bone doesn't exist on the Entity.
        local amBoneID = ctx.animationModel:LookupBone(boneName)
        if not amBoneID then continue end

        -- The physics object or nil if not found
        local ragdollPhysObj = ragdoll:GetPhysicsObjectNum(ragdollPhysObjNum)
        if not ragdollPhysObj then continue end

        local data = {
            boneName = boneName,
            amBoneID = amBoneID,
            ragdollPhysObj = ragdollPhysObj,
            ragdollBoneID = ragdollBoneID,

            -- ===============================
            -- 以下由 playAnimationCoroutine 填充
            Fall = false,    -- 是否因悬空而失效
            HitWall = false, -- 是否因撞墙而失效
            lastHitZ = 0,    -- 上一帧目标位置距地面高度
            lastAddZ = 0,    -- 累计高度修正量
            -- ===============================
        }

        table.insert(ctx.boneMap, data)
    end

    if #ctx.boneMap == 0 then
        log.warn("Cannot make bone map")
        return false
    end

    log.trace("Bone map created with ", #ctx.boneMap, " bones")
    return true
end

local function alignAnimationModel(ctx)
    local animationModel = ctx.animationModel
    animationModel:SetAngles(Angle(0, ctx.yaw, 0))

    local animationModelDatum = helper.GetStandPos(animationModel)
    if not animationModelDatum then
        log.warn("Cannot find stand pos for animationModel")
        return false
    end

    local datumToPos = animationModel:GetPos() - animationModelDatum
    animationModel:SetPos(ctx.datum + datumToPos)

    ctx.amDatumToPos  = datumToPos
    ctx.amDatumToPosZ = datumToPos.z

    log.trace("Animation model aligned, datumToPos: ", tostring(datumToPos))
    return true
end

local function checkAnimationName(ctx)
    local _, animationDuration = ctx.animationModel:LookupSequence(ctx.animationName)
    if not animationDuration or animationDuration <= 0 then
        log.warn("Invalid animation sequence: ", ctx.animationName)
        return false
    end
    ctx.animationDuration = animationDuration

    log.trace("Animation duration: ", animationDuration)
    return true
end

local function createAnimationModel(ctx)
    local animationModel = ents.Create("prop_dynamic")
    ctx.animationModel = animationModel

    local animationModelName = ctx.animationModelName
    animationModel:SetModel(animationModelName)
    animationModel:Spawn()

    if animationModel:GetModel() ~= animationModelName then
        log.warn("Invalid animationModelName: ", tostring(animationModelName))
        return false
    end

    animationModel:SetBodygroup(animationModel:FindBodygroupByName("barney"), 1) -- for debug, will be comment out when released

    log.trace("Animation model created: ", animationModelName)
    return true
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

    local ctx = {
        ragdoll                   = ragdoll,
        animationName             = animationName,
        datum                     = helper.GetStandPos(ragdoll),

        state                     = opts.state or "falling",
        damageContext             = opts.damageContext,

        totalLoops                = opts.totalLoops or Constants.ANIMATION_PLAYER.DEFAULT_TOTAL_LOOPS,
        loopCount                 = 0,

        yaw                       = opts.yaw or ragdoll:GetAngles().yaw,
        animationModelName        = opts.animationModelName or
            Constants.ANIMATION_PLAYER.ANIMATION_MODEL.DEFAULT_MODEL_NAME,

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
        not createAnimationModel(ctx) or
        not checkAnimationName(ctx) or
        not alignAnimationModel(ctx) or
        not makeBoneMap(ctx) or
        not fillShadowParamsTemplate(ctx)
    then
        cleanUp(ctx)
        return nil
    end

    local coro = Scheduler:Start(playAnimationCoroutine, ctx)
    ctx.coro = coro

    ragdoll[Constants.RAGDOLL_CONTEXT_KEY] = ctx

    return ctx
end

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = AnimationPlayer
return AnimationPlayer
