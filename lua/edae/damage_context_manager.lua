-- lua/edae/damage_context_manager.lua
local MODULE_NAME = "DamageContextManager"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants            = include("edae/config/constants.lua")
local log                  = include("edae/log/init.lua")
local EntityDataStore      = include("edae/eds/entity_data_store.lua")

local store                = EntityDataStore:ForOwner(MODULE_NAME)

-- 标志位枚举（共享）
local FLAG_ENUM            = Constants.DamageContextManager.FLAG_ENUM

-- 存储键（模块私有）
local FLAG_KEY             = "Flag"
local HIT_GROUP_KEY        = "HitGroup"
local DMG_INFO_KEY         = "DmgInfo"

local DamageContextManager = {}

-- 位操作辅助
local band, bor            = bit.band, bit.bor

-- 计算伤害标志位（所有标志非互斥，尽可能同时设置）
local function computeDamageFlags(ent, hitgroup, dmginfo)
    local flags = 0

    -- 类型标志
    if dmginfo:GetDamageType() == DMG_BURN or ent:IsOnFire() then
        flags = bor(flags, FLAG_ENUM.BURN)
    end

    if dmginfo:IsExplosionDamage() or dmginfo:GetDamageType() == DMG_BLAST then
        flags = bor(flags, FLAG_ENUM.BLAST)
    end

    if ent:IsOnGround() then
        if ent:IsNPC() and ent:GetIdealMoveSpeed() > 150 then
            flags = bor(flags, FLAG_ENUM.MOVING)
        elseif ent:IsPlayer() and ent:GetVelocity():LengthSqr() >= math.pow(ent:GetWalkSpeed(), 2) then
            flags = bor(flags, FLAG_ENUM.MOVING)
        end
    end

    if dmginfo:GetDamageType() == DMG_CLUB or dmginfo:GetDamageType() == DMG_CRUSH then
        flags = bor(flags, FLAG_ENUM.CLUB)
    end

    -- ===== 新增：溺水伤害 =====
    if dmginfo:GetDamageType() == DMG_DROWN then
        flags = bor(flags, FLAG_ENUM.DROWN)
    end

    -- 默认子弹类型：当没有其他类型标志时设置
    local typeFlags = bor(FLAG_ENUM.BURN, FLAG_ENUM.BLAST, FLAG_ENUM.MOVING, FLAG_ENUM.CLUB)
    if band(flags, typeFlags) == 0 then
        flags = bor(flags, FLAG_ENUM.BULLET)
    end

    -- 特殊射击标志（非互斥，独立检查）
    local dmgPos = dmginfo:GetDamagePosition()

    -- 霰弹枪
    if dmginfo:IsDamageType(DMG_BUCKSHOT) or dmginfo:GetAmmoType() == 7 then
        flags = bor(flags, FLAG_ENUM.SHOTGUN)
    end

    -- 颈部射击
    local headBone = ent:LookupBone("ValveBiped.Bip01_Head1")
    if headBone and hitgroup == HITGROUP_HEAD then
        local headPos = ent:GetBonePosition(headBone)
        if headPos and dmgPos.z < headPos.z then
            flags = bor(flags, FLAG_ENUM.NECK)
        end
    end

    -- 背部射击
    local forward = ent:GetForward()
    local toHit = dmgPos - ent:GetPos()
    if forward and toHit:LengthSqr() > 0 and forward:Dot(toHit:GetNormalized()) < 0 then
        flags = bor(flags, FLAG_ENUM.BACK)
    end

    -- 骨盆射击
    local pelvisBone = ent:LookupBone("ValveBiped.Bip01_Pelvis")
    if pelvisBone then
        local pelvisPos = ent:GetBonePosition(pelvisBone)
        if pelvisPos and dmgPos.z < (pelvisPos.z + 2) then
            flags = bor(flags, FLAG_ENUM.PELVIS)
        end
    end

    return flags
end

--- 获取实体的伤害上下文（返回包含 flags 和原始信息的表）
function DamageContextManager:Get(ent)
    if not IsValid(ent) then
        log.warn("DamageContextManager:Get called with invalid entity")
        return nil
    end

    local flags         = store:Get(ent, FLAG_KEY) or 0
    local hitGroup      = store:Get(ent, HIT_GROUP_KEY) or 0
    local dmgInfo       = store:Get(ent, DMG_INFO_KEY)

    local context       = {
        flags    = flags,
        hitGroup = hitGroup,
        dmgInfo  = dmgInfo,
    }

    -- 便捷布尔字段
    context.isBurn      = band(flags, FLAG_ENUM.BURN) ~= 0
    context.isBlast     = band(flags, FLAG_ENUM.BLAST) ~= 0
    context.isMoving    = band(flags, FLAG_ENUM.MOVING) ~= 0
    context.isClub      = band(flags, FLAG_ENUM.CLUB) ~= 0
    context.isBullet    = band(flags, FLAG_ENUM.BULLET) ~= 0
    context.isDrown     = band(flags, FLAG_ENUM.DROWN) ~= 0 -- <-- 新增
    context.neckShot    = band(flags, FLAG_ENUM.NECK) ~= 0
    context.shotgunShot = band(flags, FLAG_ENUM.SHOTGUN) ~= 0
    context.backShot    = band(flags, FLAG_ENUM.BACK) ~= 0
    context.pelvisShot  = band(flags, FLAG_ENUM.PELVIS) ~= 0

    return context
end

--- 更新实体的伤害上下文
function DamageContextManager:Update(ent, hitgroup, dmginfo)
    if not IsValid(ent) or not dmginfo then
        log.warn("DamageContextManager:Update invalid arguments")
        return
    end

    local flags = computeDamageFlags(ent, hitgroup, dmginfo)

    store:Set(ent, FLAG_KEY, flags)
    store:Set(ent, HIT_GROUP_KEY, hitgroup)
    store:Set(ent, DMG_INFO_KEY, dmginfo)

    log.trace("Updated damage context for ", ent, ": flags=", flags,
        ", hitgroup=", hitgroup,
        ", drown=", band(flags, FLAG_ENUM.DROWN) ~= 0,
        ", neck=", band(flags, FLAG_ENUM.NECK) ~= 0,
        ", shotgun=", band(flags, FLAG_ENUM.SHOTGUN) ~= 0,
        ", back=", band(flags, FLAG_ENUM.BACK) ~= 0,
        ", pelvis=", band(flags, FLAG_ENUM.PELVIS) ~= 0)
end

function DamageContextManager:Clear(ent)
    store:Clear(ent)
end

local function handleScaleDamage(ent, hitgroup, dmginfo)
    DamageContextManager:Update(ent, hitgroup, dmginfo)
end

hook.Add("ScaleNPCDamage", Constants.ADDON_NAME .. MODULE_NAME .. "ScaleNPCDamage", function(npc, hitgroup, dmginfo)
    handleScaleDamage(npc, hitgroup, dmginfo)
end)

hook.Add("ScalePlayerDamage", Constants.ADDON_NAME .. MODULE_NAME .. "ScalePlayerDamage",
    function(ply, hitgroup, dmginfo)
        handleScaleDamage(ply, hitgroup, dmginfo)
    end)

-- 新增：监听布娃娃创建，广播上下文事件
hook.Add("CreateEntityRagdoll", MODULE_NAME .. "_CreateEntityRagdoll", function(owner, ragdoll)
    if not IsValid(owner) or not IsValid(ragdoll) then return end
    if ragdoll:GetClass() ~= Constants.RAGDOLL_CLASS then return end

    -- 获取并清除上下文（如果存在）
    local context = DamageContextManager:Get(owner)
    DamageContextManager:Clear(owner) -- 清除，避免残留

    -- 广播自定义事件（Fire-and-Forget）
    hook.Run(Constants.Events.PostCreateRagdoll, owner, ragdoll, context)
end)

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = DamageContextManager
return DamageContextManager
