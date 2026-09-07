-- lua/edae/as/ground_strategy_builder.lua
-- 地面处理策略构建器：根据状态返回不同的地面检测与位置修正策略
-- 策略函数签名：
--   function(ctx, bone, amBonePos, amBoneAngle) return continueProcessing, bone_pos end
--   ctx：播放上下文（包含 ragdoll、animationModel、常量等）
--   bone：当前处理的骨骼数据表
--   amBonePos/amBoneAngle：动画模型上对应骨骼的位置和角度
--   返回 continueProcessing（false 表示跳过该骨骼）和 bone_pos（用于后续墙壁检测和驱动）

local MODULE_NAME = "GroundStrategyBuilder"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants             = include("edae/config/constants.lua")
local log                   = include("edae/log/init.lua")

local GroundStrategyBuilder = {}

-- 默认地面检测函数（从原 AnimationPlayer 提取，不含 WaterLevel 判断）
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

--- 默认地面处理策略：检测真实地面，进行高度修正和坠落判断
--- @param ctx table 播放上下文
--- @param bone table 骨骼数据
--- @param amBonePos Vector 动画模型骨骼位置
--- @param amBoneAngle Angle 动画模型骨骼角度（本策略未使用，保留接口一致性）
--- @return boolean continueProcessing
--- @return Vector|nil bone_pos
local function defaultStrategy(ctx, bone, amBonePos, amBoneAngle)
    local ragdoll = ctx.ragdoll
    local animationModel = ctx.animationModel

    -- 计算参考点（与动画模型相同高度）
    local refer = Vector(amBonePos.x, amBonePos.y, animationModel:GetPos().z)

    -- 获取地面位置（普通地面检测，不包含 WaterLevel）
    local groundPos = traceGroundBelow(refer, { ragdoll, animationModel })

    -- 无地面则标记 Fall 并跳过
    if not groundPos then
        bone.Fall = true
        ctx.FallCount = ctx.FallCount + 1
        log.trace("Bone ", bone.boneName, " no ground found, marking as Fall")
        return false, nil
    end

    -- 高度修正计算
    local hitDist = refer.z - groundPos.z
    local diff = hitDist - bone.lastHitZ
    bone.lastAddZ = diff + bone.lastAddZ
    bone.lastHitZ = hitDist

    -- 检测高度突变（悬空）
    if diff >= Constants.ANIMATION_PLAYER.FALL_HEIGHT_THRESHOLD then
        bone.Fall = true
        ctx.FallCount = ctx.FallCount + 1
        log.trace("Bone ", bone.boneName, " fall detected (diff=", diff, "), marking as Fall")
        return false, nil
    end

    -- 计算目标位置（应用累积高度偏移）
    local bone_pos = amBonePos - Vector(0, 0, bone.lastAddZ)
    return true, bone_pos
end

--- 溺水状态策略：忽略地面检测和高度修正，直接使用动画模型位置
--- @param ctx table 播放上下文
--- @param bone table 骨骼数据
--- @param amBonePos Vector 动画模型骨骼位置
--- @param amBoneAngle Angle 动画模型骨骼角度（本策略未使用）
--- @return boolean continueProcessing
--- @return Vector bone_pos
local function drowningStrategy(ctx, bone, amBonePos, amBoneAngle)
    -- 始终继续处理，返回动画模型位置
    return true, amBonePos
end

--- 根据状态获取地面处理策略
--- @param state string 当前状态（使用 Constants.LifeCycleHandler.STATE_ENUM）
--- @return function 策略函数
function GroundStrategyBuilder:Build(state)
    if state == Constants.LifeCycleHandler.STATE_ENUM.DROWNING then
        return drowningStrategy
    end
    -- 默认策略
    return defaultStrategy
end

-- 暴露默认策略，供 AnimationPlayer 在没有注入策略时使用
GroundStrategyBuilder.DefaultStrategy = defaultStrategy

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = GroundStrategyBuilder
return GroundStrategyBuilder
