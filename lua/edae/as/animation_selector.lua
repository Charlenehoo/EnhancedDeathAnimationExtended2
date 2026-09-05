-- lua/edae/as/animation_selector.lua
-- 动画选择器：根据状态和必要信息返回一个动画名字符串
-- 该模块只负责动画名称的选择，不涉及骨骼白名单、效果器等组装参数
-- 参数透明：主函数接收 state 和 info 表，info 中仅包含除 state 外的其他必要参数
-- 子选择器只接收自己所需的参数，不接触完整 info 表

local MODULE_NAME = "AnimationSelector"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants           = include("edae/config/constants.lua")
local log                 = include("edae/log/init.lua")
local animationCategories = include("edae/as/animation_categories.lua")

local STATE_ENUM          = Constants.LifeCycleHandler.STATE_ENUM

local AnimationSelector   = {}

-- 从列表中随机选择一个元素
local function randomFromList(list)
    if not list or #list == 0 then
        return nil
    end
    return list[math.random(#list)]
end

-- ============================================================
-- 各状态对应的动画选择函数（参数透明，只接收必要参数）
-- ============================================================

--- 死亡动画选择（FALLING 状态）
--- @param isBurn boolean
--- @param isBlast boolean
--- @param isMoving boolean
--- @param isClub boolean
--- @param hitGroup number
--- @param neckShot boolean
--- @param shotgunShot boolean
--- @param backShot boolean
--- @param pelvisShot boolean
--- @return string|nil 动画名
local function selectDeathAnimation(isBurn, isBlast, isMoving, isClub, hitGroup, neckShot, shotgunShot, backShot,
                                    pelvisShot, isDrown)
    local category = nil

    if isBurn then
        category = animationCategories.damage.fire
    elseif isBlast then
        category = animationCategories.damage.explosion
    elseif isMoving then
        category = animationCategories.damage.moving
    elseif isClub then
        category = animationCategories.damage.club
    elseif isDrown then
        category = animationCategories.damage.drown
    else
        hitGroup = hitGroup or HITGROUP_GENERIC

        if hitGroup == HITGROUP_HEAD then
            if neckShot then
                category = animationCategories.damage.neck
            else
                category = animationCategories.damage.head
            end
        elseif shotgunShot then
            category = animationCategories.damage.shotgun
        elseif hitGroup == HITGROUP_CHEST or hitGroup == HITGROUP_STOMACH then
            if pelvisShot then
                category = animationCategories.damage.pelvis
            elseif backShot then
                category = animationCategories.damage.back
            else
                category = animationCategories.damage.torso
            end
        elseif hitGroup == HITGROUP_LEFTARM then
            category = animationCategories.damage.leftArm
        elseif hitGroup == HITGROUP_RIGHTARM then
            category = animationCategories.damage.rightArm
        elseif hitGroup == HITGROUP_LEFTLEG then
            category = animationCategories.damage.leftLeg
        elseif hitGroup == HITGROUP_RIGHTLEG then
            category = animationCategories.damage.rightLeg
        else
            category = animationCategories.damage.dying
        end
    end

    local animName = randomFromList(category)
    if not animName then
        log.warn("AnimationSelector: no death animation found for given damage info, falling back to 'dying'")
        animName = randomFromList(animationCategories.damage.dying) or "dying1"
    end

    return animName
end

--- 爬行动画选择（CRAWLING 状态）
--- @param isFacingUp boolean
--- @param useFemale boolean
--- @return string 动画名
local function selectCrawlAnimation(isFacingUp, useFemale)
    if isFacingUp then
        if useFemale then
            return animationCategories.crawl.face_up.female[1]
        else
            return animationCategories.crawl.face_up.male[1]
        end
    else
        local genderList
        if useFemale then
            genderList = animationCategories.crawl.face_down.female
        else
            genderList = animationCategories.crawl.face_down.male
        end
        return randomFromList(genderList)
    end
end

--- 挣扎动画选择（WRITHING 状态）
--- @param isFacingUp boolean
--- @return string 动画名
local function selectWritheAnimation(isFacingUp)
    if isFacingUp then
        return animationCategories.writhe.face_up[1]
    else
        return animationCategories.writhe.face_down[1]
    end
end

--- 自救动画选择（SELF_REVIVING 状态）
--- @param isFacingUp boolean
--- @return string 动画名
local function selectSelfReviveAnimation(isFacingUp)
    if isFacingUp then
        return randomFromList(animationCategories.self_revive.face_up)
    else
        return animationCategories.self_revive.face_down[1]
    end
end

--- 起身动画选择（GETTING_UP 状态）
--- @param isFacingUp boolean
--- @return string 动画名
local function selectGettingUpAnimation(isFacingUp)
    if isFacingUp then
        return randomFromList(animationCategories.getting_up.face_up)
    else
        return randomFromList(animationCategories.getting_up.face_down)
    end
end

-- ============================================================
-- 主选择函数（供 AnimationAssembler 调用）
-- ============================================================

--- 根据状态和展平的 info 表选择动画名
--- @param state string 当前状态（STATE_ENUM 之一）
--- @param info table 包含除 state 外的其他必要参数，字段如下：
---   isBurn      : boolean (可选，FALLING 使用)
---   isBlast     : boolean (可选)
---   isMoving    : boolean (可选)
---   isClub      : boolean (可选)
---   hitGroup    : number (可选，HITGROUP_*)
---   neckShot    : boolean (可选)
---   shotgunShot : boolean (可选)
---   backShot    : boolean (可选)
---   pelvisShot  : boolean (可选)
---   isFacingUp  : boolean (可选，用于非 FALLING 状态)
---   useFemale   : boolean (可选，用于爬行动画选择)
--- @return string|nil 动画名，若无法选择返回 nil
function AnimationSelector:SelectAnimation(state, info)
    if not state then
        log.warn("AnimationSelector: missing state")
        return nil
    end
    info = info or {}

    if state == STATE_ENUM.FALLING then
        return selectDeathAnimation(
            info.isBurn,
            info.isBlast,
            info.isMoving,
            info.isClub,
            info.hitGroup,
            info.neckShot,
            info.shotgunShot,
            info.backShot,
            info.pelvisShot,
            info.isDrown
        )
    elseif state == STATE_ENUM.CRAWLING then
        return selectCrawlAnimation(info.isFacingUp, info.useFemale)
    elseif state == STATE_ENUM.WRITHING then
        return selectWritheAnimation(info.isFacingUp)
    elseif state == STATE_ENUM.SELF_REVIVING then
        return selectSelfReviveAnimation(info.isFacingUp)
    elseif state == STATE_ENUM.GETTING_UP then
        return selectGettingUpAnimation(info.isFacingUp)
    else
        if state == STATE_ENUM.DEAD then
            log.trace("AnimationSelector: state is 'dead', no animation will be played")
        elseif state == STATE_ENUM.TWITCHING then
            log.warn(
                "AnimationSelector: state is 'twitching', but twitch is not handled here; use TwitchAssembler instead")
        else
            log.warn("AnimationSelector: unknown state '", tostring(state), "'")
        end
        return nil
    end
end

-- 注册单例
_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = AnimationSelector
return AnimationSelector
