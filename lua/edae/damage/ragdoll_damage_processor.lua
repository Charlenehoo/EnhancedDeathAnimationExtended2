-- lua/edae/damage/ragdoll_damage_processor.lua
-- 伤害翻译器：监听布娃娃受伤事件，进行过滤/修正，提取命中信息，广播 PostRagdollTakeDamage 事件
-- 本模块只负责翻译和广播，不直接操作血量或状态机

local MODULE_NAME = "RagdollDamageProcessor"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants            = include("edae/core/constants.lua")
local log                  = include("edae/core/log/init.lua")
local RagdollBoneCache     = include("edae/core/ragdoll_bone_cache.lua")

local Processor            = {}

-- 默认忽略的伤害类型（物理拉扯、载具撞击等）
local IGNORED_DAMAGE_TYPES = {
    [DMG_CRUSH]   = true,
    [DMG_VEHICLE] = true,
}

-- 伤害修正系数（可选，按伤害类型缩放）
local DAMAGE_MODIFIERS     = {
    -- [DMG_BULLET] = 0.8,
}

--- 判断是否应忽略该伤害
--- @param dmginfo CTakeDamageInfo
--- @return boolean
local function ShouldIgnore(dmginfo)
    local dmgType = dmginfo:GetDamageType()
    return IGNORED_DAMAGE_TYPES[dmgType] == true
end

--- 计算最终伤害（应用修正系数）
--- @param dmginfo CTakeDamageInfo
--- @return number
local function GetFinalDamage(dmginfo)
    local damage = dmginfo:GetDamage()
    for dmgType, multiplier in pairs(DAMAGE_MODIFIERS) do
        if dmginfo:IsDamageType(dmgType) then
            damage = damage * multiplier
        end
    end
    return damage
end

--- 获取距离伤害位置最近的物理骨骼
--- @param ragdoll Entity
--- @param damagePos Vector
--- @return table 包含骨骼名、ID、物理ID、命中位置
local function GetClosestBone(ragdoll, damagePos)
    if not damagePos or damagePos == vector_origin then
        local pelvis = ragdoll:LookupBone("ValveBiped.Bip01_Pelvis")
        damagePos = pelvis and (ragdoll:GetBonePosition(pelvis) or ragdoll:GetPos()) or ragdoll:GetPos()
    end

    local closest = { boneName = "unknown", boneID = -1, physID = -1, hitPos = damagePos }
    local minDistSqr = math.huge

    local boneDataMap = RagdollBoneCache.GetBoneDataMap(ragdoll)
    for boneName, boneData in pairs(boneDataMap) do
        if boneData.physObj then
            local bonePos = boneData.physObj:GetPos()
            local distSqr = bonePos:DistToSqr(damagePos)
            if distSqr < minDistSqr then
                minDistSqr = distSqr
                closest = {
                    boneName = boneName,
                    boneID   = boneData.boneID,
                    physID   = boneData.physID or -1,
                    hitPos   = damagePos,
                }
            end
        end
    end

    return closest
end

--- 可选：根据骨骼名称映射到 HITGROUP_*
--- @param boneName string
--- @return number|nil
local function MapBoneToHitGroup(boneName)
    -- 可在此扩展，例如：
    -- if boneName == "ValveBiped.Bip01_Head1" then return HITGROUP_HEAD end
    return nil
end

--- 处理一次布娃娃伤害，生成结构化事件数据（不包含 ragdoll 和 dmginfo）
--- @param ragdoll Entity 布娃娃实体
--- @param dmginfo CTakeDamageInfo 伤害信息（可能被修改）
--- @return table|nil
function Processor:Process(ragdoll, dmginfo)
    if not IsValid(ragdoll) or not dmginfo then return nil end

    -- 忽略检查
    if ShouldIgnore(dmginfo) then
        log.trace("RagdollDamageProcessor: ignoring damage for ", ragdoll)
        return nil
    end

    -- 修正伤害值
    local originalDamage = dmginfo:GetDamage()
    local finalDamage = GetFinalDamage(dmginfo)
    if finalDamage ~= originalDamage then
        dmginfo:SetDamage(finalDamage)
    end

    -- 提取命中骨骼信息
    local boneHit = GetClosestBone(ragdoll, dmginfo:GetDamagePosition())

    -- 构建事件数据表（不含 ragdoll 和 dmginfo）
    local eventData = {
        dmginfo        = dmginfo,
        originalDamage = originalDamage,
        finalDamage    = finalDamage,
        hitBone        = boneHit.boneName,
        hitBoneID      = boneHit.boneID,
        hitPhysID      = boneHit.physID,
        hitPos         = boneHit.hitPos,
        damageType     = dmginfo:GetDamageType(),
        attacker       = dmginfo:GetAttacker(),
        inflictor      = dmginfo:GetInflictor(),
        hitGroup       = MapBoneToHitGroup(boneHit.boneName), -- 可能为 nil
    }

    return eventData
end

--- 处理实体受伤后事件，翻译并广播领域事件
--- @param ent Entity
--- @param dmginfo CTakeDamageInfo
--- @param wasDamageTaken boolean
local function handlePostEntityTakeDamage(ent, dmginfo, wasDamageTaken)
    if not wasDamageTaken then return end
    if not IsValid(ent) or not ent:IsRagdoll() or ent:GetClass() ~= Constants.RAGDOLL_CLASS then return end

    local eventData = Processor:Process(ent, dmginfo)
    if not eventData then return end

    hook.Run(Constants.Events.PostRagdollTakeDamage, ent, eventData)
end

hook.Add("PostEntityTakeDamage", Constants.ADDON_NAME .. MODULE_NAME .. "PostEntityTakeDamage",
    function(ent, dmginfo, wasDamageTaken)
        handlePostEntityTakeDamage(ent, dmginfo, wasDamageTaken)
    end)

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = Processor
return Processor
