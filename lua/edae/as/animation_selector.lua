-- lua/edae/as/animation_selector.lua
local MODULE_NAME = "AnimationSelector"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants = include("edae/config/constants.lua")
local log = include("edae/log/init.lua")
local Scheduler = include("edae/coroutine_scheduler.lua")
local animationCategories = include("edae/as/animation_categories.lua")
local BoneWhitelists = include("edae/as/bone_whitelists.lua")

local STATE_ENUM = Constants.LifeCycleHandler.STATE_ENUM

local AnimationSelector = {}

-- 随机选择一个动画
local function randomFromList(list)
    if not list or #list == 0 then
        return nil
    end
    return list[math.random(#list)]
end

-- 判断 ragdoll 是否已经静止（只检查白名单内的骨骼，若未提供白名单则检查全部）
local function isRagdollStopped(ragdoll, boneWhitelist)
    local physCount = ragdoll:GetPhysicsObjectCount()
    for i = 0, physCount - 1 do
        local boneID = ragdoll:TranslatePhysBoneToBone(i)
        if boneID then
            local boneName = ragdoll:GetBoneName(boneID)
            -- 如果提供了白名单，仅检查白名单内的骨骼
            if (not boneWhitelist) or (boneWhitelist and boneWhitelist[boneName]) then
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
                function() return isRagdollStopped(ctx.ragdoll, ctx.boneWhitelist) end,
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
-- @param state string 使用 STATE_ENUM 中的值
-- ============================================================
local function selectBoneWhitelist(state, animationName, opts)
    opts = opts or {}

    if state == STATE_ENUM.FALLING then
        local naturalLevel = Constants.ANIMATION_SELECTOR.NATURAL_LEVEL
        return BoneWhitelists.MoveTbD[naturalLevel]
    end

    -- 玩家相机模式特殊处理（仅爬行时）
    if opts.isPlayerCameraMode and state == STATE_ENUM.CRAWLING then
        local whitelist = table.Copy(BoneWhitelists.NrmTb)
        whitelist["ValveBiped.Bip01_Head1"] = nil
        whitelist["ValveBiped.Bip01_Spine4"] = nil
        return whitelist
    end

    -- 挣扎/抽搐动画统一使用面朝上白名单
    if state == STATE_ENUM.WRITHING then
        return BoneWhitelists.MoveTbC.MoveTb_1
    end

    -- 爬行动画：根据动画名判断面朝上/下
    if state == STATE_ENUM.CRAWLING then
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
-- 死亡动画选择（FALLING 状态）
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
        boneWhitelist = selectBoneWhitelist(STATE_ENUM.FALLING, animName, nil),
    }
end

-- ============================================================
-- 爬行动画选择
-- ============================================================
local function selectCrawlAnimation(opts)
    opts = opts or {}
    local isFacingUp = opts.isFacingUp
    local useFemale = Constants.ANIMATION_SELECTOR.USE_FEMALE_ANIMATIONS

    local animName

    if isFacingUp then
        animName = useFemale and "crawling1_f" or "crawling1"
    else
        -- 面朝下：只从 crawling5 和 crawling6 中选择
        local crawlNum = math.random(5, 6)
        animName = useFemale and ("crawling" .. crawlNum .. "_f") or ("crawling" .. crawlNum)
    end

    return {
        animationName = animName,
        totalLoops = 0,
        preWait = makeCrawlOrWrithePreWait(),
        boneWhitelist = selectBoneWhitelist(STATE_ENUM.CRAWLING, animName, opts),
    }
end

-- ============================================================
-- 挣扎动画选择
-- ============================================================
local function selectWritheAnimation(opts)
    opts = opts or {}
    local isFacingUp = opts.isFacingUp

    -- 挣扎动画：面朝上选 writhing1，面朝下选 writhing2
    local animName = isFacingUp and "writhing1" or "writhing2"

    return {
        animationName = animName,
        totalLoops = 0,
        preWait = makeCrawlOrWrithePreWait(),
        boneWhitelist = selectBoneWhitelist(STATE_ENUM.WRITHING, animName, opts),
    }
end

-- ============================================================
-- 主选择函数
-- @param playBackInfo table { state, damageContext, isFacingUp, ... }
-- @return table|nil { animationName, totalLoops, preWait, boneWhitelist }
-- ============================================================
function AnimationSelector:Select(playBackInfo)
    local state = playBackInfo.state
    local damageContext = playBackInfo.damageContext
    local opts = {
        isFacingUp = playBackInfo.isFacingUp,
        -- 可在此扩展其他选项，如 isPlayerCameraMode
        -- isPlayerCameraMode = playBackInfo.isPlayerCameraMode,
    }

    if state == STATE_ENUM.FALLING then
        return selectDeathAnimation(damageContext)
    elseif state == STATE_ENUM.CRAWLING then
        return selectCrawlAnimation(opts)
    elseif state == STATE_ENUM.WRITHING then
        return selectWritheAnimation(opts)
    else
        -- DEAD、REVIVING 以及其他未知状态不播放动画
        if state == STATE_ENUM.DEAD then
            log.trace("AnimationSelector: state is 'dead', no animation will be played")
        else
            log.warn("AnimationSelector: unknown state '", tostring(state), "'")
        end
        return nil
    end
end

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = AnimationSelector
return AnimationSelector
