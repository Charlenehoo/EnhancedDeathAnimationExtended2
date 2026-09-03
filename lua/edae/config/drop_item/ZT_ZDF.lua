-- ./lua/edae/config/drop_item/ZT_ZDF.lua
local constants       = include("edae/config/drop_item_constants.lua")

local BONE_HEAD       = constants.BONES.HEAD
local BONE_LEFT_CALF  = constants.BONES.LEFT_CALF
local BONE_RIGHT_CALF = constants.BONES.RIGHT_CALF
local BONE_LEFT_FOOT  = constants.BONES.LEFT_FOOT
local BONE_RIGHT_FOOT = constants.BONES.RIGHT_FOOT
local BONE_PELVIS     = constants.BONES.PELVIS
local PHASES          = constants.PHASES
local CONDITIONS      = constants.CONDITIONS

local grenade         = function(ctx)
    if not ARC9EFT or not ARC9EFT.HasExplosivePack then return false end

    local ent = ctx.ent
    local bgID = ctx.bodygroupID
    local rule = ctx.rule
    local pos = ctx.bonePos
    local ang = ctx.boneAng
    local count = rule.createEntCount or 1
    local offsetBase = Vector(0, 0, 4)

    ent:SetBodygroup(bgID, rule.toSubModelID)

    for i = 1, count do
        local grenade = ents.Create("arc9_eft_grenade_v40")
        grenade:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
        grenade:Spawn()
        grenade:SetModel(rule.createEnt)
        local offset = offsetBase * i
        grenade:SetPos(pos + offset)
        grenade:SetAngles(ang)
        grenade:SetVelocity(ent:GetVelocity())
    end

    return true
end

return {
    [PHASES.DURING] = {
        {
            condition = CONDITIONS.IS_HITGROUP + CONDITIONS.RANDOM,
            conditionValues = {
                [CONDITIONS.IS_HITGROUP] = HITGROUP_HEAD,
                [CONDITIONS.RANDOM] = 0.5,
            },
            bodyGroupName = "头盔",
            boneName = BONE_HEAD,
            fromSubModelID = 0,
            toSubModelID = 2,
            createEnt = "models/fj/zt_tk.mdl",
            playSound = {
                "physics/glass/glass_sheet_break2.wav",
                "physics/glass/glass_sheet_break3.wav"
            }
        },
        {
            condition = CONDITIONS.IS_HITGROUP,
            conditionValues = { [CONDITIONS.IS_HITGROUP] = HITGROUP_HEAD },
            bodyGroupName = "头盔",
            boneName = BONE_HEAD,
            fromSubModelID = 0,
            toSubModelID = 1,
            createEnt = nil,
            playSound = {
                "physics/glass/glass_sheet_break1.wav",
            }
        },
        {
            condition = CONDITIONS.IS_HITGROUP + CONDITIONS.RANDOM,
            conditionValues = {
                [CONDITIONS.IS_HITGROUP] = HITGROUP_LEFTLEG,
                [CONDITIONS.RANDOM] = 0.5
            },
            bodyGroupName = "腿装备",
            boneName = BONE_LEFT_CALF,
            fromSubModelID = 0,
            toSubModelID = 1,
            createEnt = "models/fj/ty_tzw_sl.mdl",
            createEntCount = 2,
            playSound = nil,
            callback = grenade
        },
        {
            condition = CONDITIONS.IS_HITGROUP + CONDITIONS.RANDOM,
            conditionValues = {
                [CONDITIONS.IS_HITGROUP] = HITGROUP_RIGHTLEG,
                [CONDITIONS.RANDOM] = 0.5
            },
            bodyGroupName = "腿枪套",
            boneName = BONE_RIGHT_CALF,
            fromSubModelID = 0,
            toSubModelID = 1,
            createEnt = "models/fj/ty_wq_sq1.mdl",
            playSound = nil
        },
        {
            condition = CONDITIONS.IS_HITGROUP + CONDITIONS.RANDOM,
            conditionValues = {
                [CONDITIONS.IS_HITGROUP] = HITGROUP_STOMACH,
                [CONDITIONS.RANDOM] = 0.5
            },
            bodyGroupName = "腰带装备2",
            boneName = BONE_PELVIS,
            fromSubModelID = 0,
            toSubModelID = 1,
            createEnt = "models/fj/ty_bs.mdl",
            playSound = nil
        },
        {
            condition = CONDITIONS.IS_MOVING,
            conditionValues = {
                [CONDITIONS.IS_MOVING] = 140 * 140,
            },
            bodyGroupName = "Skin",
            boneName = BONE_PELVIS,
            fromSubModelID = 0,
            toSubModelID = 2,
            createEnt = nil,
            playSound = nil
        },
        {
            condition = CONDITIONS.IS_MOVING + CONDITIONS.RANDOM,
            conditionValues = {
                [CONDITIONS.IS_MOVING] = 140 * 140,
                [CONDITIONS.RANDOM] = 0.5,
            },
            bodyGroupName = "鞋子左",
            boneName = BONE_LEFT_FOOT,
            fromSubModelID = 0,
            toSubModelID = 2,
            createEnt = "models/fj/ty_xz1_1_z.mdl",
            playSound = nil
        },
        {
            condition = CONDITIONS.IS_MOVING + CONDITIONS.RANDOM,
            conditionValues = {
                [CONDITIONS.IS_MOVING] = 140 * 140,
                [CONDITIONS.RANDOM] = 0.5,
            },
            bodyGroupName = "鞋子右",
            boneName = BONE_RIGHT_FOOT,
            fromSubModelID = 0,
            toSubModelID = 2,
            createEnt = "models/fj/ty_xz1_1_y.mdl",
            playSound = nil
        },
    },
    [PHASES.AFTER] = {
        {
            condition = CONDITIONS.IS_BULLET_NEAR_BONE + CONDITIONS.RANDOM,
            conditionValues = {
                [CONDITIONS.IS_BULLET_NEAR_BONE] = 32 * 32,
                [CONDITIONS.RANDOM] = 0.5,
            },
            bodyGroupName = "头盔",
            boneName = BONE_HEAD,
            fromSubModelID = 0,
            toSubModelID = 2,
            createEnt = "models/fj/zt_tk.mdl",
            playSound = {
                "physics/glass/glass_sheet_break2.wav",
                "physics/glass/glass_sheet_break3.wav"
            }
        },
        {
            condition = CONDITIONS.IS_BULLET_NEAR_BONE,
            conditionValues = { [CONDITIONS.IS_BULLET_NEAR_BONE] = 32 * 32 },
            bodyGroupName = "头盔",
            boneName = BONE_HEAD,
            fromSubModelID = 0,
            toSubModelID = 1,
            createEnt = nil,
            playSound = {
                "physics/glass/glass_sheet_break1.wav",
            }
        },
        {
            condition = CONDITIONS.IS_BULLET_NEAR_BONE,
            conditionValues = { [CONDITIONS.IS_BULLET_NEAR_BONE] = 32 * 32 },
            bodyGroupName = "头盔",
            boneName = BONE_HEAD,
            fromSubModelID = 1,
            toSubModelID = 2,
            createEnt = "models/fj/zt_tk.mdl",
            playSound = nil
        },
        {
            condition = CONDITIONS.IS_BULLET_NEAR_BONE + CONDITIONS.RANDOM,
            conditionValues = {
                [CONDITIONS.IS_BULLET_NEAR_BONE] = 32 * 32,
                [CONDITIONS.RANDOM] = 0.5
            },
            bodyGroupName = "腿装备",
            boneName = BONE_LEFT_CALF,
            fromSubModelID = 0,
            toSubModelID = 1,
            createEnt = "models/fj/ty_tzw_sl.mdl",
            createEntCount = 2,
            playSound = nil,
            callback = grenade
        },
        {
            condition = CONDITIONS.IS_BULLET_NEAR_BONE + CONDITIONS.RANDOM,
            conditionValues = {
                [CONDITIONS.IS_BULLET_NEAR_BONE] = 32 * 32,
                [CONDITIONS.RANDOM] = 0.5
            },
            bodyGroupName = "腿枪套",
            boneName = BONE_RIGHT_CALF,
            fromSubModelID = 0,
            toSubModelID = 1,
            createEnt = "models/fj/ty_wq_sq1.mdl",
            playSound = nil
        },
        {
            condition = CONDITIONS.IS_BULLET_NEAR_BONE + CONDITIONS.RANDOM,
            conditionValues = {
                [CONDITIONS.IS_BULLET_NEAR_BONE] = 32 * 32,
                [CONDITIONS.RANDOM] = 0.5
            },
            bodyGroupName = "腰带装备2",
            boneName = BONE_PELVIS,
            fromSubModelID = 0,
            toSubModelID = 1,
            createEnt = "models/fj/ty_bs.mdl",
            playSound = nil
        },
    },
}
