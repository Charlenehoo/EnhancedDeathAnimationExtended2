local MODULE_NAME = "EntityDataStore"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants = include("edae/config/constants.lua")
local log = include("edae/log/init.lua")

local EntityDataStore = {}
EntityDataStore.SUPER_OWNER = Constants.EntityDataStore.SUPER_OWNER

local function getRoot(ent, create)
    local root = ent[Constants.EntityDataStore.STORAGE_KEY]
    if not root and create then
        root = {}
        ent[Constants.EntityDataStore.STORAGE_KEY] = root
    end
    return root
end

function EntityDataStore:Set(ent, key, value, owner)
    owner = owner or Constants.EntityDataStore.DEFAULT_OWNER
    local root = getRoot(ent, true)

    local existing = root[key]
    if existing and existing.owner ~= owner then
        if owner == self.SUPER_OWNER then
            log.info("Overwriting field '", key, "' owned by ", existing.owner, " with SUPER_ADMIN")
        else
            log.warn("Field '", key, "' is already owned by ", existing.owner, "; cannot be overwritten by ", owner)
            return false
        end
    end

    root[key] = { value = value, owner = owner }
    return true
end

function EntityDataStore:Get(ent, key)
    local root = getRoot(ent, false)
    if not root or not root[key] then return nil end
    return root[key].value
end

function EntityDataStore:Has(ent, key)
    local root = getRoot(ent, false)
    return root ~= nil and root[key] ~= nil
end

function EntityDataStore:GetOwner(ent, key)
    local root = getRoot(ent, false)
    if root and root[key] then
        return root[key].owner
    end
    return nil
end

function EntityDataStore:ForOwner(owner)
    local sub = {}

    function sub:Set(ent, key, value)
        return EntityDataStore:Set(ent, key, value, owner)
    end

    function sub:Get(ent, key)
        return EntityDataStore:Get(ent, key)
    end

    function sub:Has(ent, key)
        return EntityDataStore:Has(ent, key)
    end

    function sub:GetOwner(ent, key)
        return EntityDataStore:GetOwner(ent, key)
    end

    return sub
end

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = EntityDataStore
return EntityDataStore
