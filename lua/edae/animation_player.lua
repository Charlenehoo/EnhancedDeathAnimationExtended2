local MODULE_NAME = "AnimationPlayer"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants = include("edae/constants.lua")
local log = include("edae/log/init.lua")
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
    local ragdoll = ctx.ragdoll
    local animationModel = ctx.animationModel

    if not IsValid(ragdoll) or not IsValid(animationModel) then
        cleanUp(ctx)
        return
    end

    enableMotion(ctx, false)
    coroutine.yield()

    enableMotion(ctx, true)
    coroutine.yield()

    animationModel:Fire("SetAnimation", ctx.animationName)
    coroutine.yield()

    -- 记录初始骨骼数量，用于判断是否提前终止
    ctx.initialBoneCount = #ctx.boneMap

    while
        IsValid(ragdoll) and
        IsValid(animationModel) and
        not ctx.stopSignal and
        ctx.initialBoneCount - #ctx.boneMap < 5
    do
        if ctx.totalLoops > 0 and ctx.loopCount >= ctx.totalLoops then break end
        ctx.loopCount = ctx.loopCount + 1
        log.trace("Loop: ", ctx.loopCount, "/", ctx.totalLoops)

        ctx.animationEndTime = CurTime() + ctx.animationDuration
        while
            IsValid(ragdoll) and
            IsValid(animationModel) and
            not ctx.stopSignal and
            ctx.initialBoneCount - #ctx.boneMap < 5 and
            CurTime() < ctx.animationEndTime
        do
            -- 逆序遍历骨骼，允许在循环中安全移除
            for i = #ctx.boneMap, 1, -1 do
                local bone = ctx.boneMap[i]
                local boneName = bone.boneName
                local amBoneID = bone.amBoneID
                local ragdollPhysObj = bone.ragdollPhysObj

                local amBonePos, amBoneAngle = animationModel:GetBonePosition(amBoneID)
                if not amBonePos then
                    -- 无法获取骨骼位置，视为失效并移除
                    log.warn()
                    table.remove(ctx.boneMap, i)
                    continue
                end

                -- 地面参考点（x,y 取目标位置，z 取动画模型中心）
                local refer = Vector(amBonePos.x, amBonePos.y, animationModel:GetPos().z)

                -- 地面检测
                local tr1 = util.TraceLine({
                    start = refer + Vector(0, 0, 10),
                    endpos = refer - Vector(0, 0, 100),
                    mask = MASK_SOLID,
                    filter = { ragdoll, animationModel }
                })

                local hitDist = refer.z - tr1.HitPos.z
                local diff = hitDist - bone.lastHitZ

                -- 更新累计修正量和上一帧高度
                bone.lastAddZ = diff + bone.lastAddZ
                bone.lastHitZ = hitDist

                -- 悬空判断：高度差过大
                if not bone.Fall and diff >= 20 then
                    bone.Fall = true
                    log.trace()
                    table.remove(ctx.boneMap, i)
                    continue
                end

                -- 修正后的目标位置
                local bone_pos = amBonePos - Vector(0, 0, bone.lastAddZ)

                -- 撞墙检测
                local tr2 = util.TraceLine({
                    start = ragdollPhysObj:GetPos(),
                    endpos = bone_pos,
                    mask = MASK_ALL,
                    filter = { ragdoll, animationModel }
                })

                if tr2.Hit then
                    bone.HitWall = true
                    log.trace()
                    table.remove(ctx.boneMap, i)
                    continue
                end

                -- 未悬空且未撞墙，驱动骨骼
                local shadowParams = ctx.shadowParamsTemplate
                shadowParams.pos = bone_pos
                shadowParams.angle = amBoneAngle
                ragdollPhysObj:Wake()
                ragdollPhysObj:ComputeShadowControl(shadowParams)
            end

            coroutine.yield()
        end

        if ctx.stopSignal then break end

        -- 原有动画模型重新定位逻辑保持不变
        local ragdollPos = ragdoll:GetPos()
        local trace = util.TraceLine({
            start = ragdollPos + Vector(0, 0, 50),
            endpos = ragdollPos - Vector(0, 0, 100),
            mask = MASK_SOLID,
            filter = { ragdoll, animationModel }
        })

        local groundPos = trace.Hit and trace.HitPos or ragdollPos
        animationModel:SetPos(groundPos + ctx.amDatumToPos)

        animationModel:Fire("SetAnimation", ctx.animationName)
        coroutine.yield()
    end

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

    return true
end

local function checkAnimationName(ctx)
    local _, animationDuration = ctx.animationModel:LookupSequence(ctx.animationName)
    if not animationDuration or animationDuration <= 0 then
        log.warn("Invalid animation sequence: ", ctx.animationName)
        return false
    end
    ctx.animationDuration = animationDuration

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

        totalLoops                = opts.totalLoops or 1,
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
