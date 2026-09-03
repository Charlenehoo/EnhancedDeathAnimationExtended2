-- lua/edae/rm/assemblers/twitch_assembler.lua
-- 抽搐参数组装器：负责组装物理抽搐播放所需的全部参数
-- 包括骨骼白名单、预等待、效果器、强度、速度模式等
-- 所有配置值均从 Constants 显式读取，避免底层模块依赖全局默认值

local MODULE_NAME = "TwitchAssembler"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants       = include("edae/config/constants.lua")
local log             = include("edae/log/init.lua")
local boneWhitelists  = include("edae/as/bone_whitelists.lua")
local PreWaitBuilder  = include("edae/as/prewait_builder.lua")
local EffectBuilder   = include("edae/rm/effect_builder.lua")
local HealthManager   = include("edae/rm/health_manager.lua")

local STATE_ENUM      = Constants.LifeCycleHandler.STATE_ENUM

local TwitchAssembler = {}

--- 组装抽搐播放参数
--- @param ragdoll Entity 布娃娃实体
--- @param state string 当前状态（应为 STATE_ENUM.TWITCHING）
--- @param owner Entity|nil 布娃娃所有者（用于效果器构建）
--- @return table|nil 抽搐选项表，失败返回 nil
function TwitchAssembler:Assemble(ragdoll, state, owner)
    if not IsValid(ragdoll) then
        log.warn("TwitchAssembler: invalid ragdoll")
        return nil
    end

    if state ~= STATE_ENUM.TWITCHING then
        log.warn("TwitchAssembler: state '", state, "' is not TWITCHING")
        return nil
    end

    -- 获取初始血量，若已死亡则无法启动
    local initialHealth = HealthManager:Get(ragdoll)
    if initialHealth <= 0 then
        log.warn("TwitchAssembler: ragdoll is already dead, cannot twitch")
        return nil
    end

    -- 骨骼白名单（专用抽搐控制集）
    local boneWhitelist = boneWhitelists.twitch

    -- 构建预等待函数数组（复用 PreWaitBuilder）
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

    -- 强度系数
    local intensity = Constants.ANIMATION_SELECTOR.TWITCH_INTENSITY or 1.0

    -- 速度模式：随机选择 High 或 Low（保持原逻辑）
    local speedMode = math.random(2) == 1 and "High" or "Low"

    -- 组装抽搐选项
    local twitchOpts = {
        boneWhitelist = boneWhitelist,
        preWait       = preWait,
        effects       = effects,
        intensity     = intensity,
        speedMode     = speedMode,
        initialHealth = initialHealth,
    }

    log.trace("TwitchAssembler: assembled twitch options for state '", state, "'")
    return twitchOpts
end

-- 注册单例
_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = TwitchAssembler
return TwitchAssembler
