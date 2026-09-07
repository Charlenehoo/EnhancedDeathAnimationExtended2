-- lua/edae/mortality_evaluator.lua
-- 死亡后果评估器（Mortality Evaluator, ME）
-- 职责：监听原始布娃娃创建事件，根据伤害上下文评估“死亡后果”，
--       产出决策（是否播放死亡动画）和状态概率表，供后续模块（RM, LCH）使用。
-- 链式位置：EDAE_PostCreateRagdoll → EDAE_OnMortalityEvaluated → EDAE_PreRagdollInitialized

local MODULE_NAME = "MortalityEvaluator"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants          = include("edae/config/constants.lua")
local log                = include("edae/log/init.lua")

local STATE_ENUM         = Constants.LifeCycleHandler.STATE_ENUM

local MortalityEvaluator = {}

-- ============================================================
-- 默认规则表（可被外部扩展/覆盖）
-- 每个规则条目：
--   {
--     name = "描述",
--     condition = function(damageContext) return boolean end,
--     decision = "falling" | "dead",  -- 建议的初始状态
--     probTable = { [STATE_ENUM.CRAWLING] = 0.3, ... } | nil
--   }
-- 规则按顺序匹配，一旦匹配则立即返回，不再继续。
-- ============================================================
MortalityEvaluator.RULES = {
    {
        name = "drowning",
        condition = function(ctx) return ctx.isDrown end,
        decision = STATE_ENUM.FALLING,
        probTable = { [STATE_ENUM.DEAD] = 1.0 },
    },
}

-- ============================================================
-- 核心评估函数：根据伤害上下文返回决策和概率表
-- ============================================================
function MortalityEvaluator:Evaluate(damageContext)
    if not damageContext then
        return STATE_ENUM.DEAD, nil
    end

    for _, rule in ipairs(self.RULES) do
        if rule.condition(damageContext) then
            log.trace("MortalityEvaluator: rule '", rule.name, "' matched, decision=", rule.decision)
            return rule.decision, rule.probTable
        end
    end

    -- 默认：播放死亡动画，使用默认概率（由 LCH 处理）
    return STATE_ENUM.FALLING, nil
end

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = MortalityEvaluator
return MortalityEvaluator
