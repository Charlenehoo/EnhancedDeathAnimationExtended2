-- ./lua/edae/di/rule_engine.lua
-- DropItem 规则引擎：负责条件检查与规则执行

local MODULE_NAME = "DropItemRuleEngine"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants                      = include("edae/config/drop_item_constants.lua")
local log                            = include("edae/log/init.lua")

local PHASES                         = Constants.PHASES
local CONDITIONS                     = Constants.CONDITIONS

local DEFAULT_RANDOM_CHANCE          = 0.5
local DEFAULT_MOVING_THRESHOLD_SQR   = 140 * 140
local DEFAULT_HEADSHOT_THRESHOLD_SQR = 32 * 32

local RuleEngine                     = {}

-- ============================================================
-- 条件检查
-- ============================================================
local function checkConditions(rule, ent, data, phase)
    local conditionMask = rule.condition
    if not conditionMask or conditionMask == 0 then
        return true
    end

    local values = rule.conditionValues or {}

    -- RANDOM
    if bit.band(conditionMask, CONDITIONS.RANDOM) ~= 0 then
        local chance = values[CONDITIONS.RANDOM] or DEFAULT_RANDOM_CHANCE
        if math.random() > chance then
            return false
        end
    end

    -- IS_HITGROUP（仅 DURING 阶段，hitgroup 由门面传入）
    if bit.band(conditionMask, CONDITIONS.IS_HITGROUP) ~= 0 then
        local expected = values[CONDITIONS.IS_HITGROUP]
        if expected == nil then
            log.warn("IS_HITGROUP condition missing expected hitgroup value")
            return false
        end

        if phase ~= PHASES.DURING then
            log.warn("IS_HITGROUP used in unsupported phase: ", phase)
            return false
        end

        local actual = data.hitgroup
        if actual ~= expected then
            return false
        end
    end

    -- IS_MOVING
    if bit.band(conditionMask, CONDITIONS.IS_MOVING) ~= 0 then
        local thresholdSqr = values[CONDITIONS.IS_MOVING] or DEFAULT_MOVING_THRESHOLD_SQR
        local vel = ent:GetVelocity()
        if vel:LengthSqr() < thresholdSqr then
            return false
        end
    end

    -- IS_BULLET_NEAR_BONE（仅 AFTER 阶段）
    if bit.band(conditionMask, CONDITIONS.IS_BULLET_NEAR_BONE) ~= 0 then
        if phase ~= PHASES.AFTER then
            log.warn("IS_BULLET_NEAR_BONE used outside AFTER phase, ignoring")
            return false
        end
        local dmg = data.dmg
        if not IsValid(dmg) then
            return false
        end
        if not dmg:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) then
            return false
        end
        local dmgPos = dmg:GetDamagePosition()
        if not dmgPos then
            return false
        end
        local boneName = rule.boneName
        if not boneName then
            log.warn("IS_BULLET_NEAR_BONE requires boneName in rule")
            return false
        end
        local boneIdx = ent:LookupBone(boneName)
        if not boneIdx then
            return false
        end
        local bonePos, _ = ent:GetBonePosition(boneIdx)
        if not bonePos then
            return false
        end
        local thresholdSqr = values[CONDITIONS.IS_BULLET_NEAR_BONE] or DEFAULT_HEADSHOT_THRESHOLD_SQR
        if (bonePos - dmgPos):LengthSqr() >= thresholdSqr then
            return false
        end
    end

    return true
end

-- ============================================================
-- 单条规则执行
-- ============================================================
local function applyRule(ent, rule, data, phase)
    local boneIdx = ent:LookupBone(rule.boneName)
    if not boneIdx then
        return false
    end
    local pos, ang = ent:GetBonePosition(boneIdx)

    local bgID = ent:FindBodygroupByName(rule.bodyGroupName)
    if not bgID then
        return false
    end

    if ent:GetBodygroup(bgID) ~= rule.fromSubModelID then
        return false
    end

    if not checkConditions(rule, ent, data, phase) then
        return false
    end

    -- 如果配置了 callback，则将上下文打包成一个表传入
    if rule.callback then
        local ctx = {
            ent         = ent,
            rule        = rule,
            data        = data,
            phase       = phase,
            boneIdx     = boneIdx,
            bonePos     = pos,
            boneAng     = ang,
            bodygroupID = bgID,
        }
        local handled = rule.callback(ctx)
        if handled then
            return true
        end
    end

    -- 默认副作用：切换 bodygroup
    ent:SetBodygroup(bgID, rule.toSubModelID)

    -- 默认副作用：生成掉落物实体
    if rule.createEnt then
        local count = rule.createEntCount or 1
        local offsetBase = Vector(0, 0, 4)

        for i = 1, count do
            local subModel = ents.Create("prop_physics")
            if IsValid(subModel) then
                subModel:SetModel(rule.createEnt)
                subModel:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
                local offset = offsetBase * i
                subModel:SetPos(pos + offset)
                subModel:SetAngles(ang)
                subModel:Spawn()
                subModel:SetVelocity(ent:GetVelocity())
                SafeRemoveEntityDelayed(subModel, 30)
            end
        end
    end

    -- 默认副作用：播放声音
    if rule.playSound then
        local sound
        if type(rule.playSound) == "table" then
            sound = table.Random(rule.playSound)
        else
            sound = rule.playSound
        end
        if sound then
            ent:EmitSound(sound)
        end
    end

    return true
end

--- 执行一组规则
--- @param ent Entity 目标实体
--- @param rules table 规则数组
--- @param data table 上下文数据（含 hitgroup 或 dmg 等）
--- @param phase string 阶段（PHASES.DURING 或 PHASES.AFTER）
function RuleEngine:ApplyRules(ent, rules, data, phase)
    if not rules or #rules == 0 then return end
    for _, rule in ipairs(rules) do
        applyRule(ent, rule, data, phase)
    end
end

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = RuleEngine
return RuleEngine
