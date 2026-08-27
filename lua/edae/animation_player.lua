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

local function playAnimationCoroutine(ctx)
    local ragdoll = ctx.ragdoll
    local animationModel = ctx.animationModel

    if not IsValid(ragdoll) or not IsValid(animationModel) then
        cleanUp(ctx)
        return
    end
    local ragdollPhysicsObjectCount = ragdoll:GetPhysicsObjectCount()
    if not ragdollPhysicsObjectCount or ragdollPhysicsObjectCount < 1 then
        cleanUp(ctx)
        return
    end

    if not enableMotion(ragdoll, false) then
        cleanUp(ctx)
        return
    end
    coroutine.yield()

    if not enableMotion(ragdoll, true) then
        cleanUp(ctx)
        return
    end
    coroutine.yield()

    while IsValid(ragdoll) and IsValid(animationModel) do
        local now = CurTime()
        local deltaTime = FrameTime()

        if ctx.stopSignal then
            log.trace("Animation end due to ctx.stopSignal")
            break
        end

        if (now > ctx.animationEndTime) then
            log.trace("Animation end due to now: ", now, " > ", "ctx.animationEndTime: ", ctx.animationEndTime)
            break
        end

        for ragdollPhysObjNum = 0, ragdollPhysicsObjectCount - 1 do
            local ragdollBoneID = ragdoll:TranslatePhysBoneToBone(ragdollPhysObjNum)

            -- "__INVALIDBONE__" in case the name cannot be read or the index is out of range, or we failed or entity doesn't have a model.
            local boneName = ragdoll:GetBoneName(ragdollBoneID)

            -- Index of the given bone name, or nil if the bone doesn't exist on the Entity.
            local amBoneID = animationModel:LookupBone(boneName)
            if not amBoneID then continue end

            -- The bone's position relative to the world. It can return nothing if the requested bone is out of bounds, or the entity has no model.
            -- The bone's angle relative to the world.
            local amBonePos, amBoneAngle = animationModel:GetBonePosition(amBoneID)
            if not amBonePos then continue end

            -- The physics object or nil if not found
            local ragdollPhysObj = ragdoll:GetPhysicsObjectNum(ragdollPhysObjNum)
            if not ragdollPhysObj then continue end

            local shadowParams = ctx.shadowParamsTemplate
            -- shadowParams.delta = deltaTime
            shadowParams.pos = amBonePos
            shadowParams.angle = amBoneAngle

            ragdollPhysObj:Wake()
            ragdollPhysObj:ComputeShadowControl(shadowParams)
        end
        coroutine.yield()
    end

    cleanUp(ctx)
end

--- 播放动画
--- @param ragdoll Entity
--- @param animationName string
--- @param opts table|nil
---   opts.animationModelName string
---   opts.collisionChecker table
---   opts.shadowParamsTemplate table
function AnimationPlayer:Play(ragdoll, animationName, opts)
    opts = opts or {}

    if not IsValid(ragdoll) then
        log.warn("Invalid ragdoll: ", tostring(ragdoll))
        return nil
    end

    if not animationName then
        log.warn("No animationName")
        return nil
    end

    local animationModelName = opts.animationModelName or Constants.ANIMATION_PLAYER_DEFAULT_MODEL_NAME
    local animationModel = ents.Create("prop_dynamic")
    animationModel:SetModel(animationModelName)
    animationModel:Spawn()
    if animationModel:GetModel() ~= animationModelName then
        log.warn("Invalid animationModelName: ", tostring(animationModelName))
        animationModel:Remove()
        return nil
    end

    local _, animationDuration = animationModel:LookupSequence(animationName)
    if not animationDuration or animationDuration <= 0 then
        log.warn("Invalid animation sequence: ", animationName)
        animationModel:Remove()
        return nil
    end
    local animationEndTime = CurTime() + animationDuration

    local ragdollStandPos  = helper.GetStandPos(ragdoll)
    animationModel:SetPos(ragdollStandPos)

    local ragdollAngles = ragdoll:GetAngles()
    local ragdollYaw = Angle(0, ragdollAngles.yaw, 0)
    animationModel:SetAngles(ragdollYaw)

    animationModel:SetBodygroup(animationModel:FindBodygroupByName("barney"), 1) -- for debug, will be comment out when release
    animationModel:Fire("SetAnimation", animationName)

    local shadowParams = table.Copy(Constants.ANIMATION_PLAYER_SHADOW_PARAMS_TEMPLATE)
    if opts.shadowParamsTemplate then
        for k, v in pairs(opts.shadowParamsTemplate) do
            shadowParams[k] = v
        end
    end

    local ctx = {
        ragdoll = ragdoll,
        animationModel = animationModel,
        animationName = animationName,

        animationEndTime = animationEndTime,

        animationModelName = animationModelName,
        shadowParamsTemplate = shadowParams,
        collisionChecker = opts.collisionChecker,

        stopSignal = nil,
        coro = nil,
    }
    local coro = Scheduler:Start(playAnimationCoroutine, ctx)
    ctx.coro = coro

    return ctx
end

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = AnimationPlayer
return AnimationPlayer
