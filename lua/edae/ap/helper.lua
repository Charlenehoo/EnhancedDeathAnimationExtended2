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

        if ctx.boneWhitelist and not ctx.boneWhitelist[boneName] then continue end

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

    -- animationModel:SetBodygroup(animationModel:FindBodygroupByName("barney"), 1) -- for debug, will be comment out when released

    log.trace("Animation model created: ", animationModelName)
    return true
end

--- 创建锚点位置获取函数
--- @param animationModel Entity 动画模型
--- @param ragdoll Entity 布娃娃
--- @return function 返回一个无参函数，调用后返回锚点世界坐标
function helper.CreateAnchorPositionGetter(animationModel, ragdoll)
    local anchorBoneID = nil

    -- 优先从 animationModel 查找
    local bones = {
        "ValveBiped.Bip01_Pelvis",
        "ValveBiped.Bip01_Spine",
        "ValveBiped.Bip01_Spine1",
        "ValveBiped.Bip01_Spine4",
    }
    for _, boneName in ipairs(bones) do
        local id = animationModel:LookupBone(boneName)
        if id then
            anchorBoneID = id
            break
        end
    end

    -- 如果动画模型没有，则从 ragdoll 查找
    if not anchorBoneID then
        for _, boneName in ipairs(bones) do
            local id = ragdoll:LookupBone(boneName)
            if id then
                anchorBoneID = id
                break
            end
        end
    end

    -- 返回闭包
    return function()
        if anchorBoneID then
            -- 先尝试动画模型骨骼
            local pos = animationModel:GetBonePosition(anchorBoneID)
            if pos then return pos end
            -- 失败则尝试 ragdoll 骨骼
            pos = ragdoll:GetBonePosition(anchorBoneID)
            if pos then return pos end
        end
        -- 最终回退到 ragdoll 原点
        return ragdoll:GetPos()
    end
end

-- 返回 x 的符号：正数返回 1，负数返回 -1，零返回 0
local function sign(x)
    if x > 0 then
        return 1
    elseif x < 0 then
        return -1
    else
        return 0
    end
end

--- 围绕实时锚点旋转动画模型（群共轭变换）
--- @param ctx table AnimationPlayer 上下文（需包含 anchorPosGetter）
--- @param targetYaw number|nil 目标绝对 Yaw 角（度）
--- @param targetPos Vector|nil 目标位置（模型将背对该位置）
--- @param maxTurnSpeed number|nil 最大角速度（度/秒），nil 或 0 表示瞬时旋转
function helper.RotateAnimationModel(ctx, targetYaw, targetPos, maxTurnSpeed)
    local animationModel = ctx.animationModel
    local ragdoll = ctx.ragdoll
    if not IsValid(animationModel) or not IsValid(ragdoll) then return false end

    -- 1. 获取实时锚点
    local anchorPos = ctx.anchorPosGetter()
    if not anchorPos then return false end

    -- 2. 确定目标 Yaw
    local currentAng = animationModel:GetAngles()
    local currentYaw = currentAng.yaw

    if not targetYaw and targetPos then
        local dir = targetPos - anchorPos
        if dir:LengthSqr() > 0 then
            targetYaw = (anchorPos - targetPos):Angle().yaw
        end
    end
    if not targetYaw then return false end

    -- 3. 计算旋转增量（最小角度差）
    local deltaYaw = math.NormalizeAngle(targetYaw - currentYaw)
    if math.abs(deltaYaw) < 0.01 then return true end

    -- 4. 应用最大角速度限制（平滑旋转）
    if maxTurnSpeed and maxTurnSpeed > 0 then
        local step = maxTurnSpeed * FrameTime()
        if math.abs(deltaYaw) > step then
            deltaYaw = sign(deltaYaw) * step
        end
    end

    -- 5. 群共轭变换：绕锚点旋转偏移向量
    local origin = animationModel:GetPos() -- 动画模型原点 O
    local offset = origin - anchorPos      -- v = O - P
    offset:Rotate(Angle(0, deltaYaw, 0))
    -- ctx.amDatumToPos:Rotate(Angle(0, deltaYaw, 0))

    local newOrigin = anchorPos + offset -- O' = P + R * v

    -- 6. 更新动画模型的位置和角度
    animationModel:SetPos(newOrigin)
    animationModel:SetAngles(Angle(0, currentYaw + deltaYaw, 0))

    -- 同步更新上下文中的 yaw
    ctx.yaw = currentYaw + deltaYaw
    return true
end

return helper
