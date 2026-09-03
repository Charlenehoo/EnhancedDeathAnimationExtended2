-- lua/edae/rm/revive_manager.lua
-- 复活管理器：负责监听复活请求事件，执行实际的玩家复活逻辑
-- 从 EntityDataStore 中获取布娃娃的所有者，移除布娃娃并重生玩家

local MODULE_NAME = "ReviveManager"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants       = include("edae/config/constants.lua")
local log             = include("edae/log/init.lua")
local EntityDataStore = include("edae/eds/entity_data_store.lua")

local store           = EntityDataStore:ForOwner(MODULE_NAME)

local OWNER_KEY       = Constants.RagdollManager.OWNER_KEY

local ReviveManager   = {}

--- 执行真正复活：删除布娃娃，重生玩家，给予短暂无敌
--- @param ragdoll Entity 布娃娃实体
function ReviveManager:PerformRevive(ragdoll)
    if not IsValid(ragdoll) then return end

    local owner = store:Get(ragdoll, OWNER_KEY)
    if not IsValid(owner) then
        log.warn("ReviveManager:PerformRevive - owner not found for ragdoll")
        ragdoll:Remove()
        return
    end

    local pos = ragdoll:GetPos()
    local ang = ragdoll:GetAngles()

    ragdoll:Remove()

    owner:Spawn()
    if IsValid(owner) then
        owner:SetPos(pos)
        owner:SetEyeAngles(Angle(0, ang.yaw, 0))
        owner:SetHealth(Constants.RagdollManager.MAX_HEALTH)
        owner:GodEnable()
        timer.Simple(2, function()
            if IsValid(owner) then owner:GodDisable() end
        end)
        log.trace("ReviveManager:PerformRevive - player ", owner, " revived at ", pos)
    else
        log.warn("ReviveManager:PerformRevive - player spawn failed")
    end
end

-- 监听复活请求事件（由 LifeCycleHandler 在起身动画完成后发出）
hook.Add(Constants.Events.OnReviveRequested, MODULE_NAME .. "_OnReviveRequested", function(ragdoll)
    if not IsValid(ragdoll) then return end
    ReviveManager:PerformRevive(ragdoll)
end)

-- 注册单例
_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = ReviveManager
return ReviveManager
