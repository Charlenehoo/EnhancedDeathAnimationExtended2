-- lua/edae/as/ground_strategy_builder.lua
-- 骨骼处理策略构建器：封装地面检测、高度修正、墙壁检测、重定位及初始定位等完整流程
-- 策略函数签名：
--   boneStrategy(ctx, bone, amBonePos, amBoneAngle) -> shouldContinue, targetPos
--   repositionStrategy(ctx) -> newGroundPos
--   initialPositionStrategy(owner, ragdoll) -> yaw, groundPos

local MODULE_NAME = "GroundStrategyBuilder"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants             = include("edae/config/constants.lua")
local log                   = include("edae/log/init.lua")
local RagdollPoseHelper     = include("edae/rm/pose_helper.lua")

local GroundStrategyBuilder = {}

-- 向下追踪地面
local function traceGroundBelow(startPos, filterEntities)
    local trace = util.TraceLine({
        start = startPos + Constants.ANIMATION_PLAYER.GROUND_TRACE_UP_OFFSET,
        endpos = startPos + Constants.ANIMATION_PLAYER.GROUND_TRACE_DOWN_OFFSET,
        mask = MASK_SOLID,
        filter = filterEntities
    })
    if trace.Hit then
        return trace.HitPos
    end
    return nil
end

--- 默认骨骼处理策略：地面检测 + 高度修正 + 墙壁检测
--- @param ctx table 播放上下文
--- @param bone table 骨骼数据
--- @param amBonePos Vector 动画模型骨骼位置
--- @param amBoneAngle Angle 动画模型骨骼角度
--- @return boolean shouldContinue 是否继续驱动该骨骼
--- @return Vector|nil targetPos 目标位置（shouldContinue 为 true 时有效）
local function defaultBoneStrategy(ctx, bone, amBonePos, amBoneAngle)
    local ragdoll = ctx.ragdoll
    local animationModel = ctx.animationModel

    -- 1. 地面检测
    local refer = Vector(amBonePos.x, amBonePos.y, animationModel:GetPos().z)
    local groundPos = traceGroundBelow(refer, { ragdoll, animationModel })
    if not groundPos then
        bone.Fall = true
        ctx.FallCount = ctx.FallCount + 1
        log.trace("Bone ", bone.boneName, " no ground found, marking as Fall")
        return false, nil
    end

    -- 2. 高度修正
    local hitDist = refer.z - groundPos.z
    local diff = hitDist - bone.lastHitZ
    bone.lastAddZ = diff + bone.lastAddZ
    bone.lastHitZ = hitDist

    -- 3. 高度突变检测
    if diff >= Constants.ANIMATION_PLAYER.FALL_HEIGHT_THRESHOLD then
        bone.Fall = true
        ctx.FallCount = ctx.FallCount + 1
        log.trace("Bone ", bone.boneName, " fall detected (diff=", diff, "), marking as Fall")
        return false, nil
    end

    -- 4. 计算目标位置
    local bone_pos = amBonePos - Vector(0, 0, bone.lastAddZ)

    -- 5. 墙壁检测
    local tr = util.TraceLine({
        start = bone.ragdollPhysObj:GetPos(),
        endpos = bone_pos,
        mask = MASK_ALL,
        filter = { ragdoll, animationModel }
    })

    if tr.Hit then
        if not bone.HitWall then
            bone.HitWall = true
            ctx.HitWallCount = ctx.HitWallCount + 1
            log.trace("Bone ", bone.boneName, " hit wall, marking as HitWall")
        end
        return false, nil
    end

    -- 检测通过，返回目标位置
    return true, bone_pos
end

--- 默认重定位策略：向下追踪地面，找不到则使用 ragdoll 位置
--- @param ctx table 播放上下文
--- @return Vector newGroundPos
local function defaultRepositionStrategy(ctx)
    local ragdoll = ctx.ragdoll
    local animationModel = ctx.animationModel
    local ragdollPos = ragdoll:GetPos()
    local groundPos = traceGroundBelow(ragdollPos, { ragdoll, animationModel })
    return groundPos or ragdollPos
end

--- 溺水骨骼策略：直接返回动画模型位置，忽略所有环境检测
--- @param ctx table 播放上下文
--- @param bone table 骨骼数据
--- @param amBonePos Vector 动画模型骨骼位置
--- @param amBoneAngle Angle 动画模型骨骼角度
--- @return boolean shouldContinue
--- @return Vector targetPos
local function drowningBoneStrategy(ctx, bone, amBonePos, amBoneAngle)
    return true, amBonePos
end

--- 溺水重定位策略：直接返回 ragdoll 位置
--- @param ctx table 播放上下文
--- @return Vector newGroundPos
local function drowningRepositionStrategy(ctx)
    return ctx.ragdoll:GetPos()
end

--- 默认初始定位策略：FALLING/DROWNING 使用所有者位置，其他状态使用布娃娃自身位置
--- @param state string 当前状态
--- @param owner Entity|nil 布娃娃所有者
--- @param ragdoll Entity 布娃娃实体
--- @return number yaw
--- @return Vector groundPos
local function defaultInitialPositionStrategy(state, owner, ragdoll)
    if state == Constants.LifeCycleHandler.STATE_ENUM.FALLING or
        state == Constants.LifeCycleHandler.STATE_ENUM.DROWNING then
        if IsValid(owner) then
            return RagdollPoseHelper:GetYawFromOwner(owner), owner:GetPos()
        else
            return RagdollPoseHelper:GetYawFromRagdoll(ragdoll), ragdoll:GetPos()
        end
    else
        return RagdollPoseHelper:GetYawFromRagdoll(ragdoll), ragdoll:GetPos()
    end
end

--- 构建策略集合
--- @param state string 当前状态（使用 Constants.LifeCycleHandler.STATE_ENUM）
--- @return table { boneStrategy = function, repositionStrategy = function, initialPositionStrategy = function }
function GroundStrategyBuilder:Build(state)
    local boneStrategy = defaultBoneStrategy
    local repositionStrategy = defaultRepositionStrategy

    if state == Constants.LifeCycleHandler.STATE_ENUM.DROWNING then
        boneStrategy = drowningBoneStrategy
        repositionStrategy = drowningRepositionStrategy
    end

    return {
        boneStrategy = boneStrategy,
        repositionStrategy = repositionStrategy,
        initialPositionStrategy = function(owner, ragdoll)
            return defaultInitialPositionStrategy(state, owner, ragdoll)
        end,
    }
end

-- 暴露默认策略，供 AnimationPlayer 在没有注入策略时使用
GroundStrategyBuilder.DefaultBoneStrategy = defaultBoneStrategy
GroundStrategyBuilder.DefaultRepositionStrategy = defaultRepositionStrategy

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = GroundStrategyBuilder
return GroundStrategyBuilder
