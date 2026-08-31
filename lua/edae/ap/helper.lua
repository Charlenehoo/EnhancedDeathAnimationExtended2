local Constants = include("edae/config/constants.lua")
local log = include("edae/log/init.lua")

local helper = {}

local function getStandPosByBone(ent)
    local LEFT_FOOT = "ValveBiped.Bip01_L_Foot"
    local RIGHT_FOOT = "ValveBiped.Bip01_R_Foot"

    local leftFoot = ent:LookupBone(LEFT_FOOT)
    local rightFoot = ent:LookupBone(RIGHT_FOOT)
    if not leftFoot or not rightFoot then return nil end

    local leftPos, _ = ent:GetBonePosition(leftFoot)
    local rightPos, _ = ent:GetBonePosition(rightFoot)
    if not leftPos or not rightPos then return nil end

    return (leftPos + rightPos) * 0.5
end

function helper.GetStandPos(ent)
    local standPos = getStandPosByBone(ent)
    if standPos then return standPos end

    return ent:GetPos()
end

function helper.EnableMotion(ctx, enable)
    for ragdollPhysObjNum = 0, ctx.ragdollPhysicsObjectCount - 1 do
        local ragdollPhysObj = ctx.ragdoll:GetPhysicsObjectNum(ragdollPhysObjNum)
        if not ragdollPhysObj then continue end
        ragdollPhysObj:EnableMotion(enable)
        if enable then
            ragdollPhysObj:Wake()
        end
    end
end

function helper.FillShadowParamsTemplate(ctx)
    local shadowParams = table.Copy(Constants.ANIMATION_PLAYER_SHADOW_PARAMS_TEMPLATE)
    if ctx.shadowParamsTemplate then
        for k, v in pairs(ctx.shadowParamsTemplate) do
            shadowParams[k] = v
        end
    end
    ctx.shadowParamsTemplate = shadowParams

    return true
end

function helper.MakeBoneMap(ctx)
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

function helper.AlignAnimationModel(ctx)
    local animationModel = ctx.animationModel
    animationModel:SetAngles(Angle(0, ctx.yaw, 0))

    local animationModelDatum = getStandPosByBone(animationModel)
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

function helper.CheckAnimationName(ctx)
    local _, animationDuration = ctx.animationModel:LookupSequence(ctx.animationName)
    if not animationDuration or animationDuration <= 0 then
        log.warn("Invalid animation sequence: ", ctx.animationName)
        return false
    end
    ctx.animationDuration = animationDuration

    log.trace("Animation duration: ", animationDuration)
    return true
end

function helper.CreateAnimationModel(ctx)
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

return helper
