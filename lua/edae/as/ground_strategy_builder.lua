-- lua/edae/as/ground_strategy_builder.lua
-- 骨骼处理策略构建器：封装地面检测、高度修正、墙壁检测等完整流程
-- 策略函数签名：
--   function(ctx, bone, amBonePos, amBoneAngle) return shouldContinue, targetPos end
--   ctx：播放上下文
--   bone：骨骼数据
--   amBonePos/amBoneAngle：动画模型骨骼位置和角度
--   返回 shouldContinue（false 表示跳过该骨骼）和 targetPos（驱动骨骼的目标位置）

local MODULE_NAME = "GroundStrategyBuilder"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants             = include("edae/config/constants.lua")
local log                   = include("edae/log/init.lua")

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
local function defaultStrategy(ctx, bone, amBonePos, amBoneAngle)
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

--- 溺水状态策略：完全忽略环境检测，直接使用动画模型位置
--- @param ctx table 播放上下文
--- @param bone table 骨骼数据
--- @param amBonePos Vector 动画模型骨骼位置
--- @param amBoneAngle Angle 动画模型骨骼角度
--- @return boolean shouldContinue
--- @return Vector targetPos
local function drowningStrategy(ctx, bone, amBonePos, amBoneAngle)
    -- 不做任何检测，也不修改 Fall/HitWall 计数
    return true, amBonePos
end

--- 根据状态获取骨骼处理策略
--- @param state string 当前状态
--- @return function 策略函数
function GroundStrategyBuilder:Build(state)
    if state == Constants.LifeCycleHandler.STATE_ENUM.DROWNING then
        return drowningStrategy
    end
    return defaultStrategy
end

-- 暴露默认策略，供 AnimationPlayer 在没有注入策略时使用
GroundStrategyBuilder.DefaultStrategy = defaultStrategy

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = GroundStrategyBuilder
return GroundStrategyBuilder
