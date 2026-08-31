local MODULE_NAME = "DamageContextManager"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants = include("edae/constants.lua")
local log = include("log/init.lua")

local DamageContextManager = {}

-- 伤害类型判断
local function DetermineDamageType(ent, dmginfo)
    if dmginfo:GetDamageType() == DMG_BURN or ent:IsOnFire() then
        return "Fire"
    elseif dmginfo:IsExplosionDamage() or dmginfo:GetDamageType() == DMG_BLAST then
        return "Explosion"
    elseif ent:IsOnGround() then
        if ent:IsNPC() and ent:GetIdealMoveSpeed() > 150 then
            return "Moving"
        elseif ent:IsPlayer() and ent:GetVelocity():LengthSqr() >= math.pow(ent:GetWalkSpeed(), 2) then
            return "Moving"
        end
    end

    if dmginfo:GetDamageType() == DMG_CLUB or dmginfo:GetDamageType() == DMG_CRUSH then
        return "Club"
    end

    return "Bullet"
end

-- 特殊射击位置判断
local function DetermineSpecialFlags(ent, hitGroup, dmginfo, context)
    local dmgPos = dmginfo:GetDamagePosition()

    -- 重置标志
    context.neckShot = false
    context.shotgunShot = false
    context.backShot = false
    context.pelvisShot = false

    -- 霰弹枪判断
    if dmginfo:IsDamageType(DMG_BUCKSHOT) or dmginfo:GetAmmoType() == 7 then
        context.shotgunShot = true
        return
    end

    -- 颈部射击（头部命中但伤害位置低于头部骨骼）
    local headBone = ent:LookupBone("ValveBiped.Bip01_Head1")
    if headBone and hitGroup == HITGROUP_HEAD then
        local headPos = ent:GetBonePosition(headBone)
        if headPos and dmgPos.z < headPos.z then
            context.neckShot = true
            return
        end
    end

    -- 背部射击（仅NPC）
    if ent:IsNPC() then
        local forward = ent:GetForward()
        local toHit = dmgPos - ent:GetPos()
        if forward and toHit:LengthSqr() > 0 and forward:Dot(toHit:GetNormalized()) < 0 then
            context.backShot = true
            return
        end
    end

    -- 骨盆射击
    local pelvisBone = ent:LookupBone("ValveBiped.Bip01_Pelvis")
    if pelvisBone then
        local pelvisPos = ent:GetBonePosition(pelvisBone)
        if pelvisPos and dmgPos.z < (pelvisPos.z + 2) then
            context.pelvisShot = true
        end
    end
end

--- 获取实体的伤害上下文，如果不存在则创建（存储在实体上）
--- @param ent Entity
--- @return table context
function DamageContextManager:Get(ent)
    if not IsValid(ent) then
        log.warn("DamageContextManager:Get called with invalid entity")
        return nil
    end

    local context = ent[Constants.PLAYER_NPC_CONTEXT_KEY]
    if not context then
        context = {
            dmgType     = "Bullet", -- 伤害类型
            hitGroup    = 0,        -- 命中组
            dmgInfo     = nil,      -- 伤害信息对象（仅引用）
            neckShot    = false,
            shotgunShot = false,
            backShot    = false,
            pelvisShot  = false,
        }
        ent[Constants.PLAYER_NPC_CONTEXT_KEY] = context
    end
    return context
end

--- 更新实体的伤害上下文（通常在 ScaleNPCDamage / ScalePlayerDamage 钩子中调用）
--- @param ent Entity
--- @param hitgroup number
--- @param dmginfo CTakeDamageInfo
function DamageContextManager:Update(ent, hitgroup, dmginfo)
    if not IsValid(ent) or not dmginfo then
        log.warn("DamageContextManager:Update invalid arguments")
        return
    end

    local context = self:Get(ent)
    if not context then return end

    -- 更新基本字段
    context.hitGroup = hitgroup
    context.dmgInfo  = dmginfo
    context.dmgType  = DetermineDamageType(ent, dmginfo)

    -- 计算特殊射击标志
    DetermineSpecialFlags(ent, hitgroup, dmginfo, context)

    log.trace("Updated damage context for ", ent, ": dmg=", context.dmgType,
        ", hitgroup=", context.hitGroup,
        ", neck=", context.neckShot,
        ", shotgun=", context.shotgunShot,
        ", back=", context.backShot,
        ", pelvis=", context.pelvisShot)
end

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = DamageContextManager
return DamageContextManager
