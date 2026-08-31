-- lua/edae/as/animation_selector.lua
local MODULE_NAME = "AnimationSelector"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants = include("edae/config/constants.lua")
local log = include("edae/log/init.lua")
local Scheduler = include("edae/cs/coroutine_scheduler.lua")
local animationCategories = include("edae/as/animation_categories.lua")
local BoneWhitelists = include("edae/as/bone_whitelists.lua")

local AnimationSelector = {}

-- 随机选择一个动画
local function randomFromList(list)
    if not list or #list == 0 then
        return nil
    end
    return list[math.random(#list)]
end

local function isRagdollStopped(ragdoll)
    local physCount = ragdoll:GetPhysicsObjectCount()
    for i = 0, physCount - 1 do
        local phys = ragdoll:GetPhysicsObjectNum(i)
        if phys then
            local linVel = phys:GetVelocity():Length()
            local angVel = phys:GetAngleVelocity():Length()
            if linVel > Constants.ANIMATION_SELECTOR.STOP_LINEAR_THRESHOLD or
                angVel > Constants.ANIMATION_SELECTOR.STOP_ANGULAR_THRESHOLD then
                return false
            end
        end
    end
    return true
end

local function makeCrawlOrWrithePreWait()
    return {
        function(ctx)
            Scheduler:Wait(Constants.ANIMATION_SELECTOR.PRE_WAIT_TIME)
        end,
        function(ctx)
            Scheduler:WaitUntil(
                function() return isRagdollStopped(ctx.ragdoll) end,
                Constants.ANIMATION_SELECTOR.STOP_TIMEOUT,
                Constants.ANIMATION_SELECTOR.STOP_CHECK_INTERVAL
            )
        end,
    }
end

-- 判断爬行动画是否为面朝上
local function isCrawlFaceUp(animationName)
    return string.StartWith(animationName, "crawling1")
end

-- ============================================================
-- 选择骨骼白名单
-- ============================================================
local function selectBoneWhitelist(state, animationName, opts)
    opts = opts or {}

    if state == "falling" then
        local naturalLevel = Constants.ANIMATION_SELECTOR.NATURAL_LEVEL
        return BoneWhitelists.MoveTbD[naturalLevel]
    end

    -- 玩家相机模式特殊处理（仅爬行时）
    if opts.isPlayerCameraMode and state == "crawling" then
        local whitelist = table.Copy(BoneWhitelists.NrmTb)
        whitelist["ValveBiped.Bip01_Head1"] = nil
        whitelist["ValveBiped.Bip01_Spine4"] = nil
        return whitelist
    end

    -- 挣扎/抽搐动画统一使用面朝上白名单
    if state == "writhing" or state == "twitching" then
        return BoneWhitelists.MoveTbC.MoveTb_1
    end

    -- 爬行动画：根据动画名判断面朝上/下
    if state == "crawling" then
        if isCrawlFaceUp(animationName) then
            return BoneWhitelists.MoveTbC.MoveTb_1
        else
            local useRandom = Constants.ANIMATION_SELECTOR.USE_RANDOM_CRAWL_WHITELIST
            if string.StartWith(animationName, "crawling5") then
                if useRandom then
                    return BoneWhitelists.MoveTbC.MoveTb_2[math.random(#BoneWhitelists.MoveTbC.MoveTb_2)]
                else
                    return BoneWhitelists.MoveTbC.MoveTb_2[1]
                end
            elseif string.StartWith(animationName, "crawling6") then
                if useRandom then
                    return BoneWhitelists.MoveTbC.MoveTb_3[math.random(#BoneWhitelists.MoveTbC.MoveTb_3)]
                else
                    return BoneWhitelists.MoveTbC.MoveTb_3[1]
                end
            else
                return BoneWhitelists.MoveTbC.MoveTb_1
            end
        end
    end

    return {}
end

-- ============================================================
-- 死亡动画选择
-- ============================================================
local function selectDeathAnimation(context)
    local animName
    if not context then
        log.warn("AnimationSelector: no context provided, falling back to 'dying1'")
        animName = randomFromList(animationCategories.dying)
    else
        local category = nil

        if context.isBurn then
            category = animationCategories.fire
        elseif context.isBlast then
            category = animationCategories.explosion
        elseif context.isMoving then
            category = animationCategories.moving
        elseif context.isClub then
            category = animationCategories.club
        else
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

        animName = randomFromList(category)
    end

    if not animName then
        log.warn("AnimationSelector: no animation found for context, falling back to 'dying1'")
        animName = randomFromList(animationCategories.dying) or "dying1"
    end

    return {
        animationName = animName,
        totalLoops = 1,
        preWait = {},
        boneWhitelist = selectBoneWhitelist("falling", animName, nil),
    }
end

-- ============================================================
-- 爬行动画选择
-- ============================================================
local function selectCrawlAnimation(opts)
    local animName = randomFromList(animationCategories.crawl)
    if not animName then
        animName = "crawling1"
    end
    return {
        animationName = animName,
        totalLoops = 0,
        preWait = makeCrawlOrWrithePreWait(),
        boneWhitelist = selectBoneWhitelist("crawling", animName, opts),
    }
end

-- ============================================================
-- 挣扎动画选择
-- ============================================================
local function selectWritheAnimation(opts)
    local animName = randomFromList(animationCategories.writhe)
    if not animName then
        animName = "writhing1"
    end
    return {
        animationName = animName,
        totalLoops = 0,
        preWait = makeCrawlOrWrithePreWait(),
        boneWhitelist = selectBoneWhitelist("writhing", animName, opts),
    }
end

-- ============================================================
-- 主选择函数
-- ============================================================
function AnimationSelector:Select(state, context, opts)
    opts = opts or {}

    if state == "falling" then
        return selectDeathAnimation(context)
    elseif state == "crawling" then
        return selectCrawlAnimation(opts)
    elseif state == "writhing" or state == "twitching" then
        return selectWritheAnimation(opts)
    elseif state == "overkill" then
        log.trace("AnimationSelector: state is 'overkill', no animation will be played")
        return nil
    else
        log.warn("AnimationSelector: unknown state '", tostring(state), "'")
        return nil
    end
end

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = AnimationSelector
return AnimationSelector
