local MODULE_NAME = "AnimationPlayer"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants = include("edae/constants.lua")
local log = include("edae/log/init.lua")
local Scheduler = include("edae/coroutine_scheduler.lua")

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

    while IsValid(ragdoll) and IsValid(animationModel) and not ctx.stopSignal do
        local deltaTime = FrameTime()

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

            -- -- ============ 调试日志埋点（Start）============
            -- if boneName == "ValveBiped.Bip01_Pelvis" then
            --     local actualPos = ragdollPhysObj:GetPos()
            --     local errorVec = actualPos - amBonePos
            --     local errorDist = errorVec:Length()
            --     local velocity = ragdollPhysObj:GetVelocity()
            --     local speed = velocity:Length()

            --     -- 写入 CSV: 时间, 距离误差, 速度, 误差X, 误差Y, 误差Z
            --     local csvLine = string.format("%.6f,%.4f,%.4f,%.4f,%.4f,%.4f\n",
            --         CurTime(),
            --         errorDist,
            --         speed,
            --         errorVec.x, errorVec.y, errorVec.z
            --     )
            --     file.Append("edae_shadow_debug.csv", csvLine)
            -- end
            -- -- ============ 调试日志埋点（End）============

            local shadowParams = ctx.shadowParamsTemplate
            shadowParams.delta = deltaTime
            shadowParams.pos = amBonePos
            shadowParams.angle = amBoneAngle

            ragdollPhysObj:Wake()
            ragdollPhysObj:ComputeShadowControl(shadowParams)
        end
        coroutine.yield()
    end

    cleanUp(ctx)
end

function AnimationPlayer:Play(ragdoll, animationName, animationModelName)
    if not IsValid(ragdoll) then
        log.warn("Invalid ragdoll: ", tostring(ragdoll))
        return nil
    end

    if not animationName then
        log.warn("No animationName")
        return nil
    end

    if not animationModelName then
        animationModelName = Constants.ANIMATION_PLAYER_DEFAULT_MODEL_NAME
    end
    local animationModel = ents.Create("prop_dynamic")
    animationModel:SetModel(animationModelName)
    if animationModel:GetModel() ~= animationModelName then
        log.warn("Invalid animationModelName: ", tostring(animationModelName))
        return nil
    end

    local startPos = ragdoll:GetPos()
    local startAngles = ragdoll:GetAngles()
    local startYaw = Angle(0, startAngles.yaw, 0)

    animationModel:SetBodygroup(animationModel:FindBodygroupByName("barney"), 1)
    animationModel:SetPos(startPos)
    animationModel:SetAngles(startYaw)

    animationModel:Spawn()
    animationModel:Fire("SetAnimation", animationName)

    local shadowParamsTemplate = table.Copy(Constants.ANIMATION_PLAYER_SHADOW_PARAMS_TEMPLATE)

    local ctx = {
        ragdoll = ragdoll,
        animationModel = animationModel,
        animationName = animationName,
        animationModelName = animationModelName,
        shadowParamsTemplate = shadowParamsTemplate,

        stopSignal = nil,
    }
    local coro = Scheduler:Start(playAnimationCoroutine, ctx)
    ctx.coro = coro

    return ctx
end

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = AnimationPlayer
return AnimationPlayer
