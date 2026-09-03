local constants = include("includes/config/constants.lua")

local BONE_HEAD = constants.BONES.HEAD
local BONE_LEFT_CALF = constants.BONES.LEFT_CALF
local BONE_RIGHT_CALF = constants.BONES.RIGHT_CALF
local BONE_LEFT_FOOT = constants.BONES.LEFT_FOOT
local BONE_RIGHT_FOOT = constants.BONES.RIGHT_FOOT
local PHASES = constants.PHASES
local CONDITIONS = constants.CONDITIONS

return {
    [PHASES.BEFORE] = {
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
    },
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
            createEnt = "models/fj/lsy_tk.mdl",
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
            createEnt = "models/fj/lsy_tk.mdl",
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
            conditionValues = { [CONDITIONS.IS_BULLET_NEAR_BONE] = 32 * 32 }, -- IS_HEADSHOT_THRESHOLD_SQR = 32 * 32
            bodyGroupName = "头盔",
            boneName = BONE_HEAD,
            fromSubModelID = 1,
            toSubModelID = 2,
            createEnt = "models/fj/lsy_tk.mdl",
            playSound = nil
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
    },
}
