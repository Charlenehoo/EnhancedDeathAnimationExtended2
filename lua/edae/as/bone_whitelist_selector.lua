-- lua/edae/as/bone_whitelist_selector.lua
-- 骨骼白名单选择器：根据状态、动画名称及选项返回一个白名单表
-- 该模块只负责白名单的选择，不涉及其他组装参数
-- 所有参数均由调用方显式传入，不依赖全局常量

local MODULE_NAME = "BoneWhitelistSelector"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants             = include("edae/config/constants.lua")
local boneWhitelists        = include("edae/as/bone_whitelists.lua")
local helper                = include("edae/helper.lua")

local STATE_ENUM            = Constants.LifeCycleHandler.STATE_ENUM

local BoneWhitelistSelector = {}

--- 选择骨骼白名单
--- @param state string 当前状态（使用 Constants.LifeCycleHandler.STATE_ENUM 中的值）
--- @param animationName string|nil 动画名称（仅爬行状态需要，用于判断面朝上/下）
--- @param naturalLevel number|nil 死亡动画控制等级：1=full, 2=moderate, 3=minimal（仅 FALLING 使用，默认 1）
--- @param isPlayerCameraMode boolean|nil 是否玩家相机模式（仅 CRAWLING 使用，默认 false）
--- @param useRandomCrawlWhitelist boolean|nil 是否随机选择爬行面朝下白名单变体（默认 false，使用第一个）
--- @return table 白名单表，键为完整骨骼名，值为 true（或 nil 表示排除）
function BoneWhitelistSelector:Select(state, animationName, naturalLevel, isPlayerCameraMode, useRandomCrawlWhitelist)
    -- 默认值处理
    naturalLevel = naturalLevel or 1
    isPlayerCameraMode = isPlayerCameraMode or false
    useRandomCrawlWhitelist = useRandomCrawlWhitelist or false

    if state == STATE_ENUM.FALLING then
        -- 死亡动画：根据等级选择
        if naturalLevel == 1 then
            return boneWhitelists.death.full
        elseif naturalLevel == 2 then
            return boneWhitelists.death.moderate
        elseif naturalLevel == 3 then
            return boneWhitelists.death.minimal
        else
            -- 无效等级，回退到 full
            return boneWhitelists.death.full
        end
    elseif state == STATE_ENUM.CRAWLING then
        -- 玩家相机模式特殊处理
        if isPlayerCameraMode then
            return boneWhitelists.player_camera_crawl
        end

        -- 根据动画名判断面朝上/下
        if animationName and string.StartWith(animationName, "crawling1") then
            -- 面朝上
            return boneWhitelists.crawl.face_up
        elseif animationName and string.StartWith(animationName, "crawling5") then
            -- 面朝下，使用 group_a 变体
            local variants = boneWhitelists.crawl.face_down.group_a
            if useRandomCrawlWhitelist then
                return helper.RandomFromDenseTable(variants)
            else
                return variants[1]
            end
        elseif animationName and string.StartWith(animationName, "crawling6") then
            -- 面朝下，使用 group_b 变体
            local variants = boneWhitelists.crawl.face_down.group_b
            if useRandomCrawlWhitelist then
                return helper.RandomFromDenseTable(variants)
            else
                return variants[1]
            end
        else
            -- 未知爬行动画，回退到面朝上白名单
            return boneWhitelists.crawl.face_up
        end
    elseif state == STATE_ENUM.WRITHING then
        return boneWhitelists.writhe
    elseif state == STATE_ENUM.TWITCHING then
        -- 抽搐使用专用白名单
        return boneWhitelists.twitch
    elseif state == STATE_ENUM.SELF_REVIVING or state == STATE_ENUM.GETTING_UP then
        -- 自救和起身动画使用标准控制集
        return boneWhitelists.normal
    else
        -- 未知状态，返回空表
        return {}
    end
end

-- 注册单例
_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = BoneWhitelistSelector
return BoneWhitelistSelector
