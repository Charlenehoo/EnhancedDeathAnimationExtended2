local MODULE_NAME = "AnimationSelector"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants = include("edae/constants.lua")
local log = include("log/init.lua")

-- ============================================================
-- 动画分类表（硬编码）
-- 根据老代码 anim_table.txt 的结构整理，并补充了新代码中已有的动画名称
-- ============================================================
local animationCategories = include("edae/animation_categories.lua")

local AnimationSelector = {}

-- 随机选择一个动画
local function randomFromList(list)
    if not list or #list == 0 then
        return nil
    end
    return list[math.random(#list)]
end

-- ============================================================
-- 死亡动画选择（对应老代码 Animrag_Death_AnimChoose）
-- ============================================================
local function selectDeathAnimation(context)
    if not context then
        log.warn("AnimationSelector: no context provided for death animation, falling back to 'dying1'")
        return randomFromList(animationCategories.dying), 1
    end

    local dmgType = context.dmgType or "Bullet"
    local hitGroup = context.hitGroup or 0
    local neckShot = context.neckShot
    local shotgunShot = context.shotgunShot
    local backShot = context.backShot
    local pelvisShot = context.pelvisShot

    local category = nil

    if dmgType == "Fire" then
        category = animationCategories.fire
    elseif dmgType == "Explosion" then
        category = animationCategories.explosion
    elseif dmgType == "Moving" then
        category = animationCategories.moving
    elseif dmgType == "Club" then
        category = animationCategories.club
    else -- 默认子弹类型
        if hitGroup == HITGROUP_HEAD then
            if neckShot then
                category = animationCategories.neck
            else
                category = animationCategories.head
            end
        elseif shotgunShot then
            category = animationCategories.shotgun
        elseif hitGroup == HITGROUP_CHEST or hitGroup == HITGROUP_STOMACH then
            if pelvisShot then
                category = animationCategories.pelvis
            elseif backShot then
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
        log.warn("AnimationSelector: no animation found for dmgType=", dmgType, ", hitGroup=", hitGroup,
            ", falling back to 'dying1'")
        animName = randomFromList(animationCategories.dying)
    end

    return animName, 1 -- 死亡动画只播放一次
end

-- ============================================================
-- 爬行动画选择（对应老代码 Animrag_Crawl_StartCrawlAnimation 中的动画选择）
-- 由于无法得知 Ragdoll 面朝上/下，此处简化：随机选择或默认 crawling1
-- ============================================================
local function selectCrawlAnimation(context)
    -- 老代码根据 Facing 选择：朝上 crawling1，朝下 crawling5/6 等
    -- 这里我们简单随机从 crawl 类别中选择一个，如果需要面朝信息，后续可扩展
    local animName = randomFromList(animationCategories.crawl)
    if not animName then
        log.warn("AnimationSelector: no crawl animation found")
        animName = "crawling1"
    end
    return animName, 0 -- 0 表示无限循环（外部 opts.totalLoops 控制）
end

-- ============================================================
-- 挣扎动画选择
-- ============================================================
local function selectWritheAnimation(context)
    local animName = randomFromList(animationCategories.writhe)
    if not animName then
        animName = "writhing1"
    end
    return animName, 0
end

-- ============================================================
-- 主选择函数
-- @param context table 伤害上下文（来自 DamageContextManager:Get）
-- @param state string 动画状态："falling", "crawling", "writhing", "twitching", "overkill" 等
-- @return animationName string|nil, totalLoops number
-- ============================================================
function AnimationSelector:Select(context, state)
    if state == "falling" then
        return selectDeathAnimation(context)
    elseif state == "crawling" then
        return selectCrawlAnimation(context)
    elseif state == "writhing" or state == "twitching" then
        return selectWritheAnimation(context)
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
