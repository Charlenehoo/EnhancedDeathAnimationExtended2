-- lua/edae/rm/health_manager.lua
-- 布娃娃血量管理模块：负责血量的存取、扣减和死亡判断

local MODULE_NAME = "RagdollHealthManager"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants            = include("edae/config/constants.lua")
local log                  = include("edae/log/init.lua")
local EntityDataStore      = include("edae/eds/entity_data_store.lua")

local store                = EntityDataStore:ForOwner(MODULE_NAME)

local HEALTH_KEY           = Constants.RagdollManager.HEALTH_KEY
local MAX_HEALTH           = Constants.RagdollManager.MAX_HEALTH

local RagdollHealthManager = {}

--- 获取布娃娃当前血量
--- @param ragdoll Entity
--- @return number health 如果未设置则返回默认最大血量
function RagdollHealthManager:Get(ragdoll)
    if not IsValid(ragdoll) then
        log.warn("RagdollHealthManager:Get called with invalid ragdoll")
        return nil
    end

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

    -- 可选：限制血量不超过最大值，不小于 0（是否启用由调用者决定）
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

    local currentHealth = self:Get(ragdoll)
    local newHealth = currentHealth - damage
    newHealth = math.max(newHealth, 0) -- 防止负值

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
    return self:Get(ragdoll) <= 0
end

--- 重置布娃娃血量至最大值
--- @param ragdoll Entity
--- @return boolean success
function RagdollHealthManager:Reset(ragdoll)
    return self:Set(ragdoll, MAX_HEALTH)
end

-- 注册单例
_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = RagdollHealthManager
return RagdollHealthManager
