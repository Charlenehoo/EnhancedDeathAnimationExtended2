-- lua/edae/rm/assemblers/animation_assembler.lua
-- 动画参数组装器：负责组装骨骼动画播放所需的全部参数
-- 包括动画名称、循环次数、骨骼白名单、预等待、姿态、效果器等
-- 所有配置值均从 Constants 显式读取，避免底层模块依赖全局默认值

local MODULE_NAME = "AnimationAssembler"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants             = include("edae/config/constants.lua")
local log                   = include("edae/log/init.lua")
local AnimationSelector     = include("edae/as/animation_selector.lua")
local BoneWhitelistSelector = include("edae/as/bone_whitelist_selector.lua")
local PreWaitBuilder        = include("edae/as/prewait_builder.lua")
local EffectBuilder         = include("edae/as/effect_builder.lua")
local HealthManager         = include("edae/rm/health_manager.lua")
local RagdollPoseHelper     = include("edae/rm/pose_helper.lua")
local helper                = include("edae/helper.lua")
local femaleModels          = include("edae/config/female_models.lua") -- 女性模型名单
local animationModelMap     = include("edae/config/animation_model_map.lua")

local STATE_ENUM            = Constants.LifeCycleHandler.STATE_ENUM

local AnimationAssembler    = {}

-- 判断模型是否为女性
local function isFemaleModel(ragdoll)
    local modelName = ragdoll:GetModel()
    if not modelName then return false end
    -- 提取文件名（去掉路径和扩展名）
    local fileName = string.match(modelName, "([^/]+)%.mdl$") or modelName
    for _, femaleModel in ipairs(femaleModels) do
        if fileName == femaleModel then
            return true
        end
    end
    return false
end

--- 组装动画播放参数
--- @param ragdoll Entity 布娃娃实体
--- @param state string 当前状态（使用 Constants.LifeCycleHandler.STATE_ENUM）
--- @param damageContext table|nil 伤害上下文（仅 FALLING 状态需要）
--- @param owner Entity|nil 布娃娃所有者（用于 FALLING 的 yaw 计算和语音效果）
--- @param isPlayerCameraMode boolean|nil 是否玩家相机模式（仅 CRAWLING 使用，默认 false）
--- @return animationName string|nil, opts table|nil 动画名和播放选项，失败返回 nil
function AnimationAssembler:Assemble(ragdoll, state, damageContext, owner, isPlayerCameraMode)
    if not IsValid(ragdoll) then
        log.warn("AnimationAssembler: invalid ragdoll")
        return nil, nil
    end

    if state == STATE_ENUM.DEAD or state == STATE_ENUM.TWITCHING then
        log.warn("AnimationAssembler: state '", state, "' is not handled by animation assembler")
        return nil, nil
    end

    isPlayerCameraMode = isPlayerCameraMode or false

    -- 从 Constants 读取配置，不再作为 option
    local naturalLevel = Constants.ANIMATION_SELECTOR.NATURAL_LEVEL
    local useRandomCrawlWhitelist = Constants.ANIMATION_SELECTOR.USE_RANDOM_CRAWL_WHITELIST

    -- 判断是否使用女性动画变体（基于模型名单）
    local useFemale = isFemaleModel(ragdoll)

    -- 计算姿态信息
    local isFacingUp = RagdollPoseHelper:IsFacingUp(ragdoll)

    -- 计算 yaw 和 groundPos
    local yaw, groundPos
    if state == STATE_ENUM.FALLING then
        if owner and owner:IsValid() then
            yaw = RagdollPoseHelper:GetYawFromOwner(owner)
            groundPos = owner:GetPos()
        else
            yaw = RagdollPoseHelper:GetYawFromRagdoll(ragdoll)
            groundPos = nil -- 让 AnimationPlayer 自行追踪地面
        end
    else
        yaw = RagdollPoseHelper:GetYawFromRagdoll(ragdoll)
        groundPos = nil
    end

    -- 选择动画名称
    local animInfo = {}
    if state == STATE_ENUM.FALLING then
        -- 展平伤害上下文
        if damageContext then
            animInfo.isBurn = damageContext.isBurn
            animInfo.isBlast = damageContext.isBlast
            animInfo.isMoving = damageContext.isMoving
            animInfo.isClub = damageContext.isClub
            animInfo.hitGroup = damageContext.hitGroup
            animInfo.neckShot = damageContext.neckShot
            animInfo.shotgunShot = damageContext.shotgunShot
            animInfo.backShot = damageContext.backShot
            animInfo.pelvisShot = damageContext.pelvisShot
        end
    elseif state == STATE_ENUM.CRAWLING then
        animInfo.isFacingUp = isFacingUp
        animInfo.useFemale = useFemale
    elseif state == STATE_ENUM.WRITHING or state == STATE_ENUM.SELF_REVIVING or state == STATE_ENUM.GETTING_UP then
        animInfo.isFacingUp = isFacingUp
    end

    local animationName = AnimationSelector:SelectAnimation(state, animInfo)
    if not animationName then
        log.warn("AnimationAssembler: no animation selected for state '", state, "'")
        return nil, nil
    end

    -- ========== 新增：根据动画名查找模型名 ==========
    local modelName = animationModelMap.ANIMATION_TO_MODEL[animationName]
    if not modelName then
        modelName = animationModelMap.DEFAULT_MODEL
    end

    -- 选择骨骼白名单
    local boneWhitelist = BoneWhitelistSelector:Select(
        state,
        animationName,
        naturalLevel,
        isPlayerCameraMode,
        useRandomCrawlWhitelist
    )

    -- 构建预等待函数数组
    local preWait = PreWaitBuilder:Build(
        state,
        Constants.ANIMATION_SELECTOR.PRE_WAIT_TIME,
        Constants.ANIMATION_SELECTOR.STOP_LINEAR_THRESHOLD,
        Constants.ANIMATION_SELECTOR.STOP_ANGULAR_THRESHOLD,
        Constants.ANIMATION_SELECTOR.STOP_TIMEOUT,
        Constants.ANIMATION_SELECTOR.STOP_CHECK_INTERVAL
    )

    -- 构建效果器
    local effects = EffectBuilder:Build(ragdoll, state, owner)

    -- 确定循环次数
    local totalLoops
    if state == STATE_ENUM.FALLING or state == STATE_ENUM.SELF_REVIVING or state == STATE_ENUM.GETTING_UP then
        totalLoops = 1
    else
        totalLoops = 0 -- 无限循环，由停止原因控制
    end

    -- 确定基础播放速率（仅 WRITHING 有特殊处理）
    local basePlaybackRate = 1.0
    if state == STATE_ENUM.WRITHING then
        local idealRate = math.Rand(0.4, 1) * Constants.ANIMATION_SELECTOR.WRITHE_INTENSITY
        basePlaybackRate = math.Clamp(idealRate, 0.4, 1.5)
    end

    -- 组装 opts
    local opts = {
        totalLoops                = totalLoops,
        preWait                   = preWait,
        boneWhitelist             = boneWhitelist,
        yaw                       = yaw,
        groundPos                 = groundPos,
        effects                   = effects,
        enableRotate              = true,
        initialHealth             = HealthManager:Get(ragdoll),
        enableHealthBasedSlowdown = (state == STATE_ENUM.WRITHING),
        basePlaybackRate          = basePlaybackRate,
        animationModelName        = modelName,
    }

    log.trace("AnimationAssembler: assembled animation '", animationName, "' for state '", state, "'")
    return animationName, opts
end

-- 注册单例
_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = AnimationAssembler
return AnimationAssembler
