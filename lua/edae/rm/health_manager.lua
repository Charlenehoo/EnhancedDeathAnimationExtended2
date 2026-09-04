-- lua/edae/rm/health_manager.lua
-- 布娃娃血量管理模块：负责血量的存取、扣减和死亡判断
-- 支持外部处理器接管（全局或单实体），提供可插拔的血量系统

local MODULE_NAME = "RagdollHealthManager"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants            = include("edae/config/constants.lua")
local log                  = include("edae/log/init.lua")
local EntityDataStore      = include("edae/eds/entity_data_store.lua")

local store                = EntityDataStore:ForOwner(MODULE_NAME)
local overrideStore        = EntityDataStore:ForOwner(MODULE_NAME .. "_Override")

local HEALTH_KEY           = Constants.RagdollManager.HEALTH_KEY
local MAX_HEALTH           = Constants.RagdollManager.MAX_HEALTH

local RagdollHealthManager = {}

-- 全局血量处理器（对所有布娃娃生效）
local globalOverride       = nil

-- 处理器接口要求：
-- {
--     Get = function(ragdoll) ... end,
--     Set = function(ragdoll, health) ... end,
--     Damage = function(ragdoll, amount) ... end, -- 返回是否死亡
--     IsDead = function(ragdoll) ... end,
--     Reset = function(ragdoll) ... end,
-- }

--- 获取布娃娃当前血量
--- @param ragdoll Entity
--- @return number|nil health
function RagdollHealthManager:Get(ragdoll)
    if not IsValid(ragdoll) then
        log.warn("RagdollHealthManager:Get called with invalid ragdoll")
        return nil
    end

    -- 检查实体级处理器
    local entityHandler = overrideStore:Get(ragdoll, "Handler")
    if entityHandler and entityHandler.Get then
        return entityHandler.Get(ragdoll)
    end

    -- 检查全局处理器
    if globalOverride and globalOverride.Get then
        return globalOverride.Get(ragdoll)
    end

    -- 默认实现
    local health = store:Get(ragdoll, HEALTH_KEY)
    if health == nil then
        health = MAX_HEALTH
    end
    return health
end

--- 设置布娃娃血量
--- @param ragdoll Entity
--- @param health number
--- @return boolean success
function RagdollHealthManager:Set(ragdoll, health)
    if not IsValid(ragdoll) then
        log.warn("RagdollHealthManager:Set called with invalid ragdoll")
        return false
    end

    if type(health) ~= "number" then
        log.warn("RagdollHealthManager:Set health must be a number, got ", type(health))
        return false
    end

    -- 检查实体级处理器
    local entityHandler = overrideStore:Get(ragdoll, "Handler")
    if entityHandler and entityHandler.Set then
        return entityHandler.Set(ragdoll, health)
    end

    -- 检查全局处理器
    if globalOverride and globalOverride.Set then
        return globalOverride.Set(ragdoll, health)
    end

    -- 默认实现
    health = math.Clamp(health, 0, MAX_HEALTH)
    local success = store:Set(ragdoll, HEALTH_KEY, health)
    if not success then
        log.warn("RagdollHealthManager:Set failed to set health for ", ragdoll)
        return false
    end

    log.trace("RagdollHealthManager:Set health of ", ragdoll, " to ", health)
    return true
end

--- 对布娃娃造成伤害，扣减血量
--- @param ragdoll Entity
--- @param damage number 伤害值（正数）
--- @return boolean died 是否因伤害而死亡（血量小于等于0）
function RagdollHealthManager:Damage(ragdoll, damage)
    if not IsValid(ragdoll) then
        log.warn("RagdollHealthManager:Damage called with invalid ragdoll")
        return false
    end

    if type(damage) ~= "number" or damage < 0 then
        log.warn("RagdollHealthManager:Damage damage must be a non-negative number, got ", tostring(damage))
        return false
    end

    -- 检查实体级处理器
    local entityHandler = overrideStore:Get(ragdoll, "Handler")
    if entityHandler and entityHandler.Damage then
        return entityHandler.Damage(ragdoll, damage)
    end

    -- 检查全局处理器
    if globalOverride and globalOverride.Damage then
        return globalOverride.Damage(ragdoll, damage)
    end

    -- 默认实现
    local currentHealth = self:Get(ragdoll)
    local newHealth = currentHealth - damage
    newHealth = math.max(newHealth, 0)

    self:Set(ragdoll, newHealth)

    log.trace("RagdollHealthManager:Damage ", ragdoll, " for ", damage, " damage, health now ", newHealth)

    return newHealth <= 0
end

--- 检查布娃娃是否已死亡（血量小于等于0）
--- @param ragdoll Entity
--- @return boolean isDead
function RagdollHealthManager:IsDead(ragdoll)
    if not IsValid(ragdoll) then
        return true -- 无效实体视为死亡
    end

    -- 检查实体级处理器
    local entityHandler = overrideStore:Get(ragdoll, "Handler")
    if entityHandler and entityHandler.IsDead then
        return entityHandler.IsDead(ragdoll)
    end

    -- 检查全局处理器
    if globalOverride and globalOverride.IsDead then
        return globalOverride.IsDead(ragdoll)
    end

    -- 默认实现
    return self:Get(ragdoll) <= 0
end

--- 重置布娃娃血量至最大值
--- @param ragdoll Entity
--- @return boolean success
function RagdollHealthManager:Reset(ragdoll)
    if not IsValid(ragdoll) then
        log.warn("RagdollHealthManager:Reset called with invalid ragdoll")
        return false
    end

    -- 检查实体级处理器
    local entityHandler = overrideStore:Get(ragdoll, "Handler")
    if entityHandler and entityHandler.Reset then
        return entityHandler.Reset(ragdoll)
    end

    -- 检查全局处理器
    if globalOverride and globalOverride.Reset then
        return globalOverride.Reset(ragdoll)
    end

    -- 默认实现
    return self:Set(ragdoll, MAX_HEALTH)
end

--- 设置全局血量处理器（对所有布娃娃生效）
--- @param handler table|nil 处理器表，需包含 Get/Set/Damage/IsDead/Reset 方法
function RagdollHealthManager:SetGlobalOverride(handler)
    globalOverride = handler
    log.trace("RagdollHealthManager: global override set to ", handler and "handler" or "nil")
end

--- 清除全局血量处理器
function RagdollHealthManager:ClearGlobalOverride()
    globalOverride = nil
    log.trace("RagdollHealthManager: global override cleared")
end

--- 为特定布娃娃设置血量处理器
--- @param ragdoll Entity
--- @param handler table 处理器表
--- @return boolean success
function RagdollHealthManager:SetEntityOverride(ragdoll, handler)
    if not IsValid(ragdoll) then
        log.warn("RagdollHealthManager:SetEntityOverride invalid ragdoll")
        return false
    end
    local success = overrideStore:Set(ragdoll, "Handler", handler)
    log.trace("RagdollHealthManager: entity override set for ", ragdoll)
    return success
end

--- 清除特定布娃娃的血量处理器
--- @param ragdoll Entity
--- @return boolean success
function RagdollHealthManager:ClearEntityOverride(ragdoll)
    if not IsValid(ragdoll) then
        log.warn("RagdollHealthManager:ClearEntityOverride invalid ragdoll")
        return false
    end
    local success = overrideStore:Set(ragdoll, "Handler", nil)
    log.trace("RagdollHealthManager: entity override cleared for ", ragdoll)
    return success
end

-- 注册单例
_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = RagdollHealthManager
return RagdollHealthManager
