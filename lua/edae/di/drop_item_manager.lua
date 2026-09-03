-- ./lua/edae/di/drop_item_manager.lua
-- DropItem 管理器：独立子系统门面
-- 提供两个接口供 RagdollManager 调用：
--   OnRagdollCreated(owner, ragdoll, hitgroup)  -- 布娃娃创建时执行 DURING 阶段
--   OnRagdollTakeDamage(ragdoll, dmginfo)       -- 布娃娃受击时执行 AFTER 阶段
-- 使用 EDAE 日志与 EntityDataStore，不直接注册钩子

local MODULE_NAME = "DropItemManager"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants            = include("edae/config/drop_item_constants.lua")
local DropItemConfig       = include("edae/config/drop_item_config.lua")
local RuleEngine           = include("edae/di/rule_engine.lua")
local log                  = include("edae/log/init.lua")
local EntityDataStore      = include("edae/eds/entity_data_store.lua")

local store                = EntityDataStore:ForOwner(MODULE_NAME)

local PHASES               = DropItemConfig.PHASES
local MODEL_TO_CONFIG_MAP  = DropItemConfig.MODEL_TO_CONFIG_MAP

-- EntityDataStore 键名
local KEY_CONFIG_CACHE     = "DropItemConfigurationsCache"
local KEY_INVALID_MODEL    = "DropItemInvalidModel"
local KEY_DURING_COMPLETED = "DropItemCreateEntityRagdollEnd"

local DropItemManager      = {}

-- ============================================================
-- 配置缓存
-- ============================================================
local function tryGetConfigurations(ent)
    if store:Has(ent, KEY_INVALID_MODEL) then
        return nil
    end

    local configs = store:Get(ent, KEY_CONFIG_CACHE)
    if configs then
        return configs
    end

    local model = ent:GetModel()
    if not model then
        log.trace("DropItem: Skipping Invalid Model: ", tostring(ent))
        store:Set(ent, KEY_INVALID_MODEL, true)
        return nil
    end

    configs = MODEL_TO_CONFIG_MAP[string.lower(model)]
    if not configs then
        log.trace("DropItem: Skipping Invalid Config: ", model)
        store:Set(ent, KEY_INVALID_MODEL, true)
        return nil
    end

    store:Set(ent, KEY_CONFIG_CACHE, configs)
    return configs
end

-- ============================================================
-- 门面接口：布娃娃创建时（DURING 阶段）
-- ============================================================
--- 由 RagdollManager 在创建布娃娃后调用
--- @param owner Entity 原始实体
--- @param ragdoll Entity 布娃娃实体
--- @param hitgroup number|nil 致命伤害的 hitgroup（可由 DamageContextManager 获取）
function DropItemManager:OnRagdollCreated(owner, ragdoll, hitgroup)
    if not IsValid(ragdoll) then return end

    local configs = tryGetConfigurations(ragdoll)
    if not configs then return end

    local phaseDuringConfigurations = configs[PHASES.DURING]
    if phaseDuringConfigurations then
        local data = {
            owner    = owner,
            hitgroup = hitgroup,
        }
        RuleEngine:ApplyRules(ragdoll, phaseDuringConfigurations, data, PHASES.DURING)
    end

    store:Set(ragdoll, KEY_DURING_COMPLETED, true)
    log.trace("DropItem: DURING phase completed for ragdoll: ", tostring(ragdoll))
end

-- ============================================================
-- 门面接口：布娃娃受击时（AFTER 阶段）
-- ============================================================
--- 由 RagdollManager 在布娃娃受到伤害后调用
--- @param ragdoll Entity 布娃娃实体
--- @param dmginfo CTakeDamageInfo 伤害信息
function DropItemManager:OnRagdollTakeDamage(ragdoll, dmginfo)
    if not IsValid(ragdoll) or not dmginfo then return end
    if not store:Has(ragdoll, KEY_DURING_COMPLETED) then return end

    local configs = tryGetConfigurations(ragdoll)
    if not configs then return end

    local phaseAfterConfigurations = configs[PHASES.AFTER]
    if phaseAfterConfigurations then
        local data = { dmg = dmginfo }
        RuleEngine:ApplyRules(ragdoll, phaseAfterConfigurations, data, PHASES.AFTER)
    end
end

-- ============================================================
-- 清理接口（可选，供门面在布娃娃移除时调用）
-- ============================================================
function DropItemManager:OnRagdollRemoved(ragdoll)
    if not IsValid(ragdoll) then return end
    store:Clear(ragdoll)
end

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = DropItemManager
return DropItemManager
