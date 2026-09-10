-- lua/edae/playback/animation_player/internal.lua
-- AnimationPlayer 的私有实现。
-- 只由 animation_player.lua 引用，不对外暴露。
-- 所有函数接受 ctx（AP 的黑板）作为第一个参数。
-- 通用工具（无 ctx 依赖）请放到 edae/helper.lua。

local log              = include("edae/core/log/init.lua")
local shadowParams     = include("edae/data/shadow_params.lua")
local RagdollBoneCache = include("edae/core/ragdoll_bone_cache.lua")
local Constants        = include("edae/core/constants.lua")
local LifeCycleHandler = include("edae/state/life_cycle_handler.lua")
local helper           = include("edae/helper.lua") -- 使用 helper.Sign

local AP               = {}

-- ============================================================================
-- 物理控制
-- ============================================================================

function AP.EnableMotion(ctx, enable)
    for ragdollPhysObjNum = 0, ctx.ragdollPhysicsObjectCount - 1 do
        local ragdollPhysObj = ctx.ragdoll:GetPhysicsObjectNum(ragdollPhysObjNum)
        if not ragdollPhysObj then continue end
        ragdollPhysObj:EnableMotion(enable)
        if enable then
            ragdollPhysObj:Wake()
        end
    end
end

-- ============================================================================
-- 参数模板
-- ============================================================================

function AP.FillShadowParamsTemplate(ctx)
    local shadowParamsCopy = table.Copy(shadowParams.Default)
    if ctx.shadowParamsTemplate then
        for k, v in pairs(ctx.shadowParamsTemplate) do
            shadowParamsCopy[k] = v
        end
    end
    ctx.shadowParamsTemplate = shadowParamsCopy
    ctx.baseShadowParams     = table.Copy(shadowParamsCopy)
    return true
end

-- ============================================================================
-- 骨骼映射
-- ============================================================================

function AP.MakeBoneMap(ctx)
    local ragdoll        = ctx.ragdoll
    local animationModel = ctx.animationModel

    local boneDataMap    = RagdollBoneCache.GetBoneDataMap(ragdoll)
    if not boneDataMap then return false end

    ctx.boneMap = {}
    for boneName, boneData in pairs(boneDataMap) do
        local amBoneID = animationModel:LookupBone(boneName)
        if amBoneID then
            local ragdollPhysObj = boneData.physObj
            if IsValid(ragdollPhysObj) then
                local skip = (ctx.boneWhitelist ~= nil) and (not ctx.boneWhitelist[boneName])
                local data = {
                    boneName       = boneName,
                    amBoneID       = amBoneID,
                    ragdollPhysObj = ragdollPhysObj,
                    ragdollBoneID  = boneData.boneID,
                    skip           = skip,
                    Fall           = false,
                    HitWall        = false,
                    lastHitZ       = 0,
                    lastAddZ       = 0,
                }
                table.insert(ctx.boneMap, data)
            end
        end
    end

    if ctx.persistentSkipBones then
        for _, bone in ipairs(ctx.boneMap) do
            if ctx.persistentSkipBones[bone.boneName] then
                bone.skip = true
            end
        end
    end

    if #ctx.boneMap == 0 then
        log.warn("Cannot make bone map")
        return false
    end

    ctx.ragdollPhysicsObjectCount = ragdoll:GetPhysicsObjectCount()
    ctx.totalBones                = #ctx.boneMap
    return true
end

-- ============================================================================
-- 动画序列校验
-- ============================================================================

function AP.CheckAnimationName(ctx)
    local _, animationDuration = ctx.animationModel:LookupSequence(ctx.animationName)
    if not animationDuration or animationDuration <= 0 then
        log.warn("Invalid animation sequence: ", ctx.animationName)
        return false
    end
    ctx.animationDuration     = animationDuration
    ctx.baseAnimationDuration = animationDuration
    return true
end

-- ============================================================================
-- AnimationModel 生命周期（惰性创建、跨播放复用、终态释放）
-- ----------------------------------------------------------------------------
-- 语义：
--   * 惰性创建：Acquire 时若无缓存则创建。
--   * 跨播放复用：AP Stop → Release 不立即删除，
--     而是判断 ragdoll 状态：非 DEAD 则保留，下次 Acquire 复用。
--   * 终态释放：ragdoll 进入 DEAD 时，Release 真正 Remove。
--   * ragdoll 销毁：ragdoll 被删除时，CallOnRemove 兜底清理。
--   * 对 AP 透明：AP 只调 Acquire / Release，不知道是否真的删除。
-- ============================================================================

-- 弱键表：ragdoll → 当前持有的模型
local ragdollModel     = setmetatable({}, { __mode = "k" })
-- 弱键表：ragdoll → 当前模型的 modelName（换模型时判断是否需 SetModel）
local ragdollModelName = setmetatable({}, { __mode = "k" })

--- 获取或创建 animationModel
--- @param ctx table 需包含 ragdoll 和 animationModelName
--- @return boolean 是否成功
function AP.AcquireAnimationModel(ctx)
    local ragdoll   = ctx.ragdoll
    local modelName = ctx.animationModelName

    if not IsValid(ragdoll) then
        log.warn("AP.AcquireAnimationModel: invalid ragdoll")
        return false
    end

    if not util.IsValidModel(modelName) then
        log.warn("AP.AcquireAnimationModel: invalid model name: ", tostring(modelName))
        return false
    end

    local cachedModel = ragdollModel[ragdoll]
    local cachedName  = ragdollModelName[ragdoll]

    -- 情况 1：缓存有效且 modelName 一致 → 复用
    if IsValid(cachedModel) and cachedName == modelName then
        ctx.animationModel = cachedModel
        log.trace("AP.AcquireAnimationModel: reused ", modelName)
        return true
    end

    -- 情况 2：缓存有效但 modelName 变化 → 先删除旧的
    if IsValid(cachedModel) then
        cachedModel:Remove()
        ragdollModel[ragdoll]     = nil
        ragdollModelName[ragdoll] = nil
    end

    -- 创建新模型
    local animationModel = ents.Create("prop_dynamic")
    if not IsValid(animationModel) then
        log.warn("AP.AcquireAnimationModel: failed to create entity")
        return false
    end

    animationModel:SetModel(modelName)
    animationModel:SetNoDraw(true)
    animationModel:Spawn()

    ragdollModel[ragdoll]     = animationModel
    ragdollModelName[ragdoll] = modelName

    -- ragdoll 销毁时兜底清理（同名键覆盖，不会重复注册）
    ragdoll:CallOnRemove("EDAE_AnimModelCleanup", function()
        local m = ragdollModel[ragdoll]
        if IsValid(m) then m:Remove() end
        ragdollModel[ragdoll]     = nil
        ragdollModelName[ragdoll] = nil
    end)

    ctx.animationModel = animationModel
    log.trace("AP.AcquireAnimationModel: created ", modelName)
    return true
end

--- 释放 animationModel（由 AP 在 cleanUp 时调用）
--- 是否真正 Remove 由本模块判断，对 AP 透明。
--- @param ctx table 需包含 ragdoll
function AP.ReleaseAnimationModel(ctx)
    local ragdoll = ctx.ragdoll
    if not IsValid(ragdoll) then return end

    -- 以 ragdollModel 表为准（Acquire 写入的 SSOT）
    local model = ragdollModel[ragdoll]
    if not IsValid(model) then
        ragdollModel[ragdoll]     = nil
        ragdollModelName[ragdoll] = nil
        return
    end

    local state = LifeCycleHandler:GetState(ragdoll)

    if state == Constants.LifeCycleHandler.STATE_ENUM.DEAD then
        ragdollModel[ragdoll]     = nil
        ragdollModelName[ragdoll] = nil
        model:Remove()
        log.trace("AP.ReleaseAnimationModel: released (dead)")
    else
        log.trace("AP.ReleaseAnimationModel: retained (state=", tostring(state), ")")
    end
end

-- ============================================================================
-- 锚点与旋转
-- ============================================================================

--- 创建锚点位置获取函数
--- @param ctx table 需包含 animationModel 和 ragdoll
--- @return function 返回无参函数，调用后返回锚点世界坐标
function AP.CreateAnchorPositionGetter(ctx)
    local animationModel = ctx.animationModel
    local ragdoll        = ctx.ragdoll

    local anchorBoneID   = nil
    local bones          = {
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

    if not anchorBoneID then
        for _, boneName in ipairs(bones) do
            local id = ragdoll:LookupBone(boneName)
            if id then
                anchorBoneID = id
                break
            end
        end
    end

    return function()
        if anchorBoneID then
            local pos = animationModel:GetBonePosition(anchorBoneID)
            if pos then return pos end
            pos = ragdoll:GetBonePosition(anchorBoneID)
            if pos then return pos end
        end
        return ragdoll:GetPos()
    end
end

--- 围绕实时锚点旋转动画模型（群共轭变换）
--- @param ctx table 需包含 animationModel / ragdoll / anchorPosGetter
--- @param targetYaw number|nil
--- @param targetPos Vector|nil
--- @param maxTurnSpeed number|nil
function AP.RotateAnimationModel(ctx, targetYaw, targetPos, maxTurnSpeed)
    local animationModel = ctx.animationModel
    local ragdoll        = ctx.ragdoll
    if not IsValid(animationModel) or not IsValid(ragdoll) then return false end

    local anchorPos = ctx.anchorPosGetter()
    if not anchorPos then return false end

    local currentAng = animationModel:GetAngles()
    local currentYaw = currentAng.yaw

    if not targetYaw and targetPos then
        local dir = targetPos - anchorPos
        if dir:LengthSqr() > 0 then
            targetYaw = (anchorPos - targetPos):Angle().yaw
        end
    end
    if not targetYaw then return false end

    local deltaYaw = math.NormalizeAngle(targetYaw - currentYaw)
    if math.abs(deltaYaw) < 0.01 then return true end

    if maxTurnSpeed and maxTurnSpeed > 0 then
        local step = maxTurnSpeed * FrameTime()
        if math.abs(deltaYaw) > step then
            deltaYaw = helper.Sign(deltaYaw) * step
        end
    end

    local origin = animationModel:GetPos()
    local offset = origin - anchorPos
    offset:Rotate(Angle(0, deltaYaw, 0))

    local newOrigin = anchorPos + offset

    animationModel:SetPos(newOrigin)
    animationModel:SetAngles(Angle(0, currentYaw + deltaYaw, 0))

    ctx.yaw = currentYaw + deltaYaw
    return true
end

return AP
