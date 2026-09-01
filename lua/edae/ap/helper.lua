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

--- 查找旋转锚点骨骼 ID
function helper.FindRotationAnchorBoneID(ent)
    local bones = {
        "ValveBiped.Bip01_Pelvis",
        "ValveBiped.Bip01_Spine",
        "ValveBiped.Bip01_Spine1",
        "ValveBiped.Bip01_Spine4",
    }
    for _, boneName in ipairs(bones) do
        local id = ent:LookupBone(boneName)
        if id then return id end
    end
    return nil
end

--- 围绕实时锚点旋转动画模型（群共轭变换）
--- @param ctx table AnimationPlayer 上下文
--- @param targetYaw number|nil 目标绝对 Yaw 角（度）
--- @param targetPos Vector|nil 目标位置（模型将背对该位置）
--- @param maxTurnSpeed number|nil 最大角速度（度/秒），nil 或 0 表示瞬时旋转
function helper.RotateAnimationModel(ctx, targetYaw, targetPos, maxTurnSpeed)
    local animationModel = ctx.animationModel
    local ragdoll = ctx.ragdoll
    if not IsValid(animationModel) or not IsValid(ragdoll) then return false end

    -- 1. 获取实时锚点（优先从动画模型骨骼获取，失败则从 ragdoll 对应骨骼获取，最后回退到 ragdoll 原点）
    local anchorPos = nil
    local anchorBoneID = ctx.rotationAnchorBoneID

    if anchorBoneID then
        anchorPos = animationModel:GetBonePosition(anchorBoneID)
        if not anchorPos then
            anchorPos = ragdoll:GetBonePosition(anchorBoneID)
        end
    end

    if not anchorPos then
        anchorPos = ragdoll:GetPos() -- 最终回退到 ragdoll 位置
    end

    -- 对齐高度，避免旋转时垂直跳动（使用 animationModel 当前原点高度，但此高度可能随动画变化？这里取 ragdoll 锚点高度更合理）
    -- 注：MOD1 中将 anchorPos.z 对齐到 AnimRag 原点高度，但动画模型原点高度不变，故需要谨慎。建议保持锚点原样。
    -- 这里不做强制对齐，遵循真实锚点。

    -- 2. 确定目标 Yaw
    local currentAng = animationModel:GetAngles()
    local currentYaw = currentAng.yaw

    if not targetYaw and targetPos then
        -- 背对目标位置
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
            deltaYaw = math.sign(deltaYaw) * step
        end
    end

    -- 5. 群共轭变换：绕锚点旋转偏移向量
    local origin = animationModel:GetPos()      -- 动画模型原点 O
    local offset = origin - anchorPos           -- v = O - P
    local rotatedOffset = Vector(offset.x, offset.y, offset.z)
    rotatedOffset:Rotate(Angle(0, deltaYaw, 0)) -- 旋转偏移向量

    local newOrigin = anchorPos + rotatedOffset -- O' = P + R * v

    -- 6. 更新动画模型的位置和角度
    animationModel:SetPos(newOrigin)
    animationModel:SetAngles(Angle(0, currentYaw + deltaYaw, 0))

    -- 同步更新上下文中的 yaw
    ctx.yaw = currentYaw + deltaYaw
    return true
end

return helper
