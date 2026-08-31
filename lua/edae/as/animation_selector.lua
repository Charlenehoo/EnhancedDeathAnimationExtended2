-- lua/edae/as/animation_selector.lua
local MODULE_NAME = "AnimationSelector"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants = include("edae/config/constants.lua")
local log = include("edae/log/init.lua")
local animationCategories = include("edae/as/animation_categories.lua")

local AnimationSelector = {}

-- 随机选择一个动画
local function randomFromList(list)
    if not list or #list == 0 then
        return nil
    end
    return list[math.random(#list)]
end

-- ============================================================
-- 死亡动画选择（基于伤害上下文 flags 和 hitGroup）
-- ============================================================
local function selectDeathAnimation(context)
    if not context then
        log.warn("AnimationSelector: no context provided, falling back to 'dying1'")
        return randomFromList(animationCategories.dying), 1
    end

    local category = nil

    -- 按优先级判断特殊伤害类型
    if context.isBurn then
        category = animationCategories.fire
    elseif context.isBlast then
        category = animationCategories.explosion
    elseif context.isMoving then
        category = animationCategories.moving
    elseif context.isClub then
        category = animationCategories.club
    else
        -- 默认子弹类型，根据 hitGroup 和特殊标志细分
        local hitGroup = context.hitGroup or HITGROUP_GENERIC

        if hitGroup == HITGROUP_HEAD then
            if context.neckShot then
                category = animationCategories.neck
            else
                category = animationCategories.head
            end
        elseif context.shotgunShot then
            category = animationCategories.shotgun
        elseif hitGroup == HITGROUP_CHEST or hitGroup == HITGROUP_STOMACH then
            if context.pelvisShot then
                category = animationCategories.pelvis
            elseif context.backShot then
                category = animationCategories.back
            else
                category = animationCategories.torso
            end
        elseif hitGroup == HITGROUP_LEFTARM then
            category = animationCategories.leftArm
        elseif hitGroup == HITGROUP_RIGHTARM then
            category = animationCategories.rightArm
        elseif hitGroup == HITGROUP_LEFTLEG then
            category = animationCategories.leftLeg
        elseif hitGroup == HITGROUP_RIGHTLEG then
            category = animationCategories.rightLeg
        else
            category = animationCategories.dying
        end
    end

    local animName = randomFromList(category)
    if not animName then
        log.warn("AnimationSelector: no animation found for context, falling back to 'dying1'")
        animName = randomFromList(animationCategories.dying) or "dying1"
    end

    return animName, 1 -- 死亡动画只播放一次
end

-- ============================================================
-- 爬行动画选择（随机，可根据需要扩展）
-- ============================================================
local function selectCrawlAnimation()
    local animName = randomFromList(animationCategories.crawl)
    if not animName then
        log.warn("AnimationSelector: no crawl animation found")
        animName = "crawling1"
    end
    return animName, 0 -- 0 表示无限循环
end

-- ============================================================
-- 挣扎动画选择（随机）
-- ============================================================
local function selectWritheAnimation()
    local animName = randomFromList(animationCategories.writhe)
    if not animName then
        animName = "writhing1"
    end
    return animName, 0
end

-- ============================================================
-- 主选择函数
-- @param state string 动画状态："falling", "crawling", "writhing", "twitching", "overkill"
-- @param context table|nil 伤害上下文（由 DamageContextManager:Get 提供）
-- @return animationName string|nil, totalLoops number
-- ============================================================
function AnimationSelector:Select(state, context)
    if state == "falling" then
        return selectDeathAnimation(context)
    elseif state == "crawling" then
        return selectCrawlAnimation()
    elseif state == "writhing" or state == "twitching" then
        return selectWritheAnimation()
    elseif state == "overkill" then
        log.trace("AnimationSelector: state is 'overkill', no animation will be played")
        return nil, 0
    else
        log.warn("AnimationSelector: unknown state '", tostring(state), "'")
        return nil, 0
    end
end

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = AnimationSelector
return AnimationSelector
