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

local DummyCollisionStrategy = {}
function DummyCollisionStrategy:Evaluate(physObj, currentPos, desiredPos, context)
    return "free", nil
end

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
    local gravityProxy = ctx.gravityProxy
    local gravityProxyPhysObj = ctx.gravityProxyPhysObj

    local collisionStrategy = ctx.collisionStrategy or DummyCollisionStrategy

    if not IsValid(ragdoll) or not IsValid(animationModel) or not IsValid(gravityProxy) then
        cleanUp(ctx)
        return
    end

    enableMotion(ctx, false)
    coroutine.yield()

    enableMotion(ctx, true)
    coroutine.yield()

    -- 第一次播放动画
    animationModel:Fire("SetAnimation", ctx.animationName)
    coroutine.yield()

    while IsValid(ragdoll) and IsValid(animationModel) and IsValid(gravityProxy) and not ctx.stopSignal do
        if ctx.totalLoops > 0 and ctx.loopCount >= ctx.totalLoops then break end
        ctx.loopCount = ctx.loopCount + 1

        ctx.animationEndTime = CurTime() + ctx.animationDuration
        while CurTime() < ctx.animationEndTime do
            local deltaTime = FrameTime()

            -- 保持重力代理水平速度与布娃娃一致
            local ragdollVelocity = ragdoll:GetVelocity()
            local gravityProxyPhysObVelocity = gravityProxyPhysObj:GetVelocity()
            gravityProxyPhysObj:SetVelocityInstantaneous(Vector(ragdollVelocity.x, ragdollVelocity.y,
                gravityProxyPhysObVelocity.z))

            -- 用重力代理修正动画模型实体的绝对高度（贴地）
            local gravityProxyPhysObjPos = gravityProxyPhysObj:GetPos()
            local currentDatumZ = gravityProxyPhysObjPos.z - ctx.gravityProxyDatumToPos.z
            local targetZ = currentDatumZ + ctx.amDatumToPosZ
            local amPos = animationModel:GetPos()
            animationModel:SetPos(Vector(amPos.x, amPos.y, targetZ))

            -- 驱动布娃娃骨骼
            for i = #ctx.boneMap, 1, -1 do
                local boneName = ctx.boneMap[i].boneName
                local amBoneID = ctx.boneMap[i].amBoneID
                local ragdollPhysObj = ctx.boneMap[i].ragdollPhysObj

                local amBonePos, amBoneAngle = animationModel:GetBonePosition(amBoneID)
                if not amBonePos then continue end

                local currentPos = ragdollPhysObj:GetPos()
                local context = {
                    ragdoll = ragdoll,
                    animModel = animationModel,
                    boneName = boneName,
                    physObj = ragdollPhysObj,
                }
                local status, fallbackPos = collisionStrategy:Evaluate(
                    ragdollPhysObj,
                    currentPos,
                    amBonePos,
                    context
                )

                local shadowParams = ctx.shadowParamsTemplate

                if status == "free" then
                    shadowParams.pos = amBonePos
                    shadowParams.angle = amBoneAngle
                elseif status == "fallback" then
                    shadowParams.pos = fallbackPos
                    shadowParams.angle = amBoneAngle
                else
                    table.remove(ctx.boneMap, i)
                    continue
                end

                ragdollPhysObj:Wake()
                ragdollPhysObj:ComputeShadowControl(shadowParams)
            end
            coroutine.yield()
        end

        -- ===== 老实现风格的重复定位 =====
        -- 从布娃娃当前位置向下 TraceLine 找到地面
        local ragdollPos = ragdoll:GetPos()
        local trace = util.TraceLine({
            start = ragdollPos,
            endpos = ragdollPos - Vector(0, 0, 200),
            mask = MASK_SOLID,
            filter = { ragdoll, animationModel, gravityProxy }
        })

        local groundPos = trace.Hit and trace.HitPos or ragdollPos
        -- 设置动画模型实体位置：地面点 + 模型原点偏移
        animationModel:SetPos(groundPos + ctx.amDatumToPos)

        -- 重新播放动画
        animationModel:Fire("SetAnimation", ctx.animationName)
        coroutine.yield() -- 等待一帧让动画状态生效
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

local function creatGravityProxy(ctx)
    local gravityProxy = ents.Create("prop_sphere")
    ctx.gravityProxy = gravityProxy


    local radius = ctx.gravityProxyRadius
    ctx.gravityProxyDatumToPos = Vector(0, 0, radius)

    gravityProxy:SetKeyValue("radius", tostring(radius))
    gravityProxy:SetModel(ctx.gravityProxyModelName)
    gravityProxy:Spawn()

    gravityProxy:SetPos(ctx.datum + ctx.gravityProxyDatumToPos)
    gravityProxy:SetCustomCollisionCheck(true)
    gravityProxy:SetFriction(0)
    gravityProxy:SetGravity(10)

    local gravityProxyPhysObj = gravityProxy:GetPhysicsObject()
    ctx.gravityProxyPhysObj = gravityProxyPhysObj

    gravityProxyPhysObj:EnableDrag(false)
    gravityProxyPhysObj:EnableGravity(true)

    return true
end

local function makeBoneMap(ctx)
    local ragdoll = ctx.ragdoll
    local animationModel = ctx.animationModel

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
        local amBoneID = animationModel:LookupBone(boneName)
        if not amBoneID then continue end

        -- The physics object or nil if not found
        local ragdollPhysObj = ragdoll:GetPhysicsObjectNum(ragdollPhysObjNum)
        if not ragdollPhysObj then continue end

        local data = {
            boneName = boneName,
            amBoneID = amBoneID,
            ragdollPhysObj = ragdollPhysObj,
            ragdollBoneID = ragdollBoneID,
        }

        table.insert(ctx.boneMap, data)

        if boneName == ctx.amRefBoneName then
            ctx.amRefBoneID = amBoneID
        end
    end
    return ctx.amRefBoneID ~= nil
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

local function alignAnimationModel(ctx)
    local animationModel = ctx.animationModel
    -- animationModel:SetAngles(Angle(0, ctx.yaw, 0))

    local animationModelDatum = helper.GetStandPos(animationModel)
    if not animationModelDatum then return false end

    local datumToPos  = animationModel:GetPos() - animationModelDatum
    ctx.amDatumToPos  = datumToPos
    ctx.amDatumToPosZ = datumToPos.z

    animationModel:SetPos(ctx.datum + datumToPos)
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
        amRefBoneName             = opts.animationModelRefBoneName or
            Constants.ANIMATION_PLAYER.ANIMATION_MODEL.REF_BONE_NAME,
        gravityProxyModelName     = opts.gravityProxyModelName or Constants.ANIMATION_PLAYER.GRAVITY_PROXY.MODEL_NAME,
        gravityProxyRadius        = opts.radius or Constants.ANIMATION_PLAYER.GRAVITY_PROXY.RADIUS,
        collisionStrategy         = opts.collisionStrategy or DummyCollisionStrategy,

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
        -- 以下由 creatGravityProxy 填充
        gravityProxy              = nil,
        gravityProxyPhysObj       = nil,
        gravityProxyDatumToPos    = nil,
        -- ===============================

        -- ===============================
        -- 以下由 fillShadowParamsTemplate 填充
        shadowParamsTemplate      = opts.shadowParamsTemplate,
        -- ===============================

        animationEndTime          = nil,

        coro                      = nil,
        stopSignal                = nil,
    }

    if
        not createAnimationModel(ctx) or
        not checkAnimationName(ctx) or
        not alignAnimationModel(ctx) or
        not makeBoneMap(ctx) or
        not creatGravityProxy(ctx) or
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

hook.Add("ShouldCollide", Constants.ADDON_NAME .. MODULE_NAME .. "ShouldCollide", function(ent1, ent2)
    if ent1[Constants.RAGDOLL_CONTEXT_KEY] then
        return ent2 ~= ent1[Constants.RAGDOLL_CONTEXT_KEY].gravityProxy
    end

    if ent2[Constants.RAGDOLL_CONTEXT_KEY] then
        return ent1 ~= ent2[Constants.RAGDOLL_CONTEXT_KEY].gravityProxy
    end

    return true
end)

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = AnimationPlayer
return AnimationPlayer
