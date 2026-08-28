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

local function enableMotion(ragdoll, enable, ragdollPhysicsObjectCount)
    if not IsValid(ragdoll) then
        return false
    end

    if not ragdollPhysicsObjectCount then
        ragdollPhysicsObjectCount = ragdoll:GetPhysicsObjectCount()
    end

    if not ragdollPhysicsObjectCount or ragdollPhysicsObjectCount < 1 then
        return false
    end

    local success = 0
    for ragdollPhysObjNum = 0, ragdollPhysicsObjectCount - 1 do
        local ragdollPhysObj = ragdoll:GetPhysicsObjectNum(ragdollPhysObjNum)
        if not ragdollPhysObj then continue end

        success = success + 1
        ragdollPhysObj:EnableMotion(enable)
        if enable then
            ragdollPhysObj:Wake()
        end
    end

    return success > 0
end

local function makeBoneMapping(ragdoll, animationModel, ragdollPhysicsObjectCount)
    local map = {}
    for ragdollPhysObjNum = 0, ragdollPhysicsObjectCount - 1 do
        local ragdollBoneID = ragdoll:TranslatePhysBoneToBone(ragdollPhysObjNum)

        -- "__INVALIDBONE__" in case the name cannot be read or the index is out of range, or we failed or entity doesn't have a model.
        local boneName = ragdoll:GetBoneName(ragdollBoneID)

        -- Index of the given bone name, or nil if the bone doesn't exist on the Entity.
        local amBoneID = animationModel:LookupBone(boneName)
        if not amBoneID then continue end

        -- The physics object or nil if not found
        local ragdollPhysObj = ragdoll:GetPhysicsObjectNum(ragdollPhysObjNum)
        if not ragdollPhysObj then continue end

        local data = { boneName = boneName, ragdollPhysObj = ragdollPhysObj, amBoneID = amBoneID }
        table.insert(map, data)
    end
    return map
end

local function playAnimationCoroutine(ctx)
    local ragdoll = ctx.ragdoll
    local animationModel = ctx.animationModel
    local gravityProxy = ctx.gravityProxy
    local gravityProxyPhysObj = ctx.gravityProxyPhysObj

    local animationName = ctx.animationName
    local heightDifference = ctx.animationModelHeight - ctx.gravityProxyRadius
    local collisionStrategy = ctx.collisionStrategy or DummyCollisionStrategy

    if not IsValid(ragdoll) or not IsValid(animationModel) or not IsValid(gravityProxy) then
        cleanUp(ctx)
        return
    end
    local ragdollPhysicsObjectCount = ragdoll:GetPhysicsObjectCount()
    if not ragdollPhysicsObjectCount or ragdollPhysicsObjectCount < 1 then
        cleanUp(ctx)
        return
    end

    if not enableMotion(ragdoll, false, ragdollPhysicsObjectCount) then
        cleanUp(ctx)
        return
    end
    coroutine.yield()

    if not enableMotion(ragdoll, true, ragdollPhysicsObjectCount) then
        cleanUp(ctx)
        return
    end
    coroutine.yield()

    local animationEndTime = CurTime() + ctx.animationDuration
    animationModel:Fire("SetAnimation", animationName)

    local activeBoneMappings = makeBoneMapping(ragdoll, animationModel, ragdollPhysicsObjectCount)

    while IsValid(ragdoll) and IsValid(animationModel) and IsValid(gravityProxy) do
        local now = CurTime()
        local deltaTime = FrameTime()

        if ctx.stopSignal then
            log.trace("Animation end due to ctx.stopSignal")
            break
        end

        if (now > animationEndTime) then
            log.trace("Animation end due to now: ", now, " > ", "animationEndTime: ", animationEndTime)
            break
        end

        -- if ragdollPhysicsObjectCount - #controlingBones < Constants.MIN_CONTROL_BONE then
        --     break
        -- end

        local ragdollVelocity = ragdoll:GetVelocity()
        gravityProxyPhysObj:SetVelocityInstantaneous(ragdollVelocity)

        local gravityProxyPhysObjPos = gravityProxyPhysObj:GetPos()
        local animationModelPos = animationModel:GetPos()
        animationModel:SetPos(Vector(animationModelPos.x, animationModelPos.y,
            gravityProxyPhysObjPos.z + heightDifference))

        for i = #activeBoneMappings, 1, -1 do
            local boneName = activeBoneMappings[i].boneName
            local amBoneID = activeBoneMappings[i].amBoneID
            local ragdollPhysObj = activeBoneMappings[i].ragdollPhysObj

            -- The bone's position relative to the world. It can return nothing if the requested bone is out of bounds, or the entity has no model.
            -- The bone's angle relative to the world.
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
                -- shadowParams.delta = deltaTime
                shadowParams.pos = amBonePos
                shadowParams.angle = amBoneAngle
            elseif status == "fallback" then
                shadowParams.pos = fallbackPos
                shadowParams.angle = amBoneAngle
            else
                table.remove(activeBoneMappings, i)
                continue
            end

            ragdollPhysObj:Wake()
            ragdollPhysObj:ComputeShadowControl(shadowParams)
        end
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

local function checkAnimationName(ctx)
    local _, animationDuration = ctx.animationModel:LookupSequence(ctx.animationName)
    if not animationDuration or animationDuration <= 0 then
        log.warn("Invalid animation sequence: ", ctx.animationName)
        return false
    end
    ctx.animationDuration = animationDuration
    return true
end

local function creatGravityProxy(ctx)
    local gravityProxy = ents.Create("prop_sphere")
    ctx.gravityProxy = gravityProxy

    local radius = ctx.gravityProxyRadius
    gravityProxy:SetKeyValue("radius", tostring(radius))
    gravityProxy:SetModel(ctx.gravityProxyModelName)
    gravityProxy:Spawn()

    gravityProxy:SetPos(ctx.ragdollStandPos + Vector(0, 0, radius))
    gravityProxy:SetCustomCollisionCheck(true)
    gravityProxy:SetFriction(0)
    gravityProxy:SetGravity(10)

    local gravityProxyPhysObj = gravityProxy:GetPhysicsObject()
    ctx.gravityProxyPhysObj = gravityProxyPhysObj

    gravityProxyPhysObj:EnableDrag(false)
    gravityProxyPhysObj:EnableGravity(true)

    return true
end

local function createAnimationModel(ctx)
    local animationModel = ents.Create("prop_dynamic")
    ctx.animationModel = animationModel

    local animationModelName = ctx.animationModelName
    animationModel:SetModel(animationModelName)
    if animationModel:GetModel() ~= animationModelName then
        log.warn("Invalid animationModelName: ", tostring(animationModelName))
        return false
    end
    animationModel:Spawn()

    local animationModelStandPos = helper.GetStandPos(animationModel)
    local standOffset            = animationModelStandPos - animationModel:GetPos()

    local animationModelHeight   = standOffset:Length()
    ctx.animationModelHeight     = animationModelHeight

    standOffset:Rotate(Angle(0, ctx.yaw, 0)) -- standOffset is Rotated at place
    animationModel:SetPos(ctx.ragdollStandPos - standOffset)
    animationModel:SetAngles(Angle(0, ctx.yaw, 0))

    animationModel:SetBodygroup(animationModel:FindBodygroupByName("barney"), 1) -- for debug, will be comment out when release

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
        ragdoll               = ragdoll,
        animationName         = animationName,
        ragdollStandPos       = helper.GetStandPos(ragdoll),

        yaw                   = opts.yaw or ragdoll:GetAngles().yaw,
        animationModelName    = opts.animationModelName or Constants.ANIMATION_PLAYER_DEFAULT_ANIMATION_MODEL_NAME,
        gravityProxyModelName = opts.gravityProxyModelName or Constants.ANIMATION_PLAYER.GRAVITY_PROXY.MODEL_NAME,
        gravityProxyRadius    = opts.radius or Constants.ANIMATION_PLAYER.GRAVITY_PROXY.RADIUS,
        collisionStrategy     = opts.collisionStrategy or DummyCollisionStrategy,

        -- ===============================
        -- 以下由 createAnimationModel 填充
        animationModel        = nil,
        animationModelHeight  = nil,
        -- ===============================

        -- ===============================
        -- 以下由 checkAnimationName 填充
        animationDuration     = nil,
        -- ===============================

        -- ===============================
        -- 以下由 creatGravityProxy 填充
        gravityProxy          = nil,
        gravityProxyPhysObj   = nil,
        -- ===============================

        -- ===============================
        -- 以下由 fillShadowParamsTemplate 填充
        shadowParamsTemplate  = opts.shadowParamsTemplate,
        -- ===============================

        coro                  = nil,
        stopSignal            = nil,
    }

    if
        not createAnimationModel(ctx) or
        not checkAnimationName(ctx) or
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
