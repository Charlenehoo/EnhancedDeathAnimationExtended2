-- lua/edae/as/animation_categories.lua
-- 动画分类表：按语义化结构组织动画，供 AnimationSelector 使用
-- 结构设计：
--   damage: 按伤害类型/部位分类，用于死亡动画选择
--   crawl:  爬行动画，区分 face_up / face_down，以及 male/female 变体
--   writhe: 挣扎动画，区分 face_up / face_down
--   self_revive: 自救动画，区分 face_up / face_down
--   getting_up: 起身动画，区分 face_up / face_down
--   misc:   暂未使用的其他动画

local animationCategories = {
    -- ============================================================
    -- 伤害相关死亡动画（FALLING 状态使用）
    -- ============================================================
    damage = {
        -- 火烧/燃烧
        fire = {
            "bd_death_fire1",
            "ex_engineer_burn",
            "ex_heavy_burn",
            "ex_medic_burn",
            "ex_movingonfire",
            "ex_runonfire1",
            "ex_runonfire2",
            "ex_scout_burn",
            "ex_sniper_burn",
            "ex_soldier_burn",
            "ex_spy_burn",
        },

        -- 爆炸
        explosion = {
            "DeathExplosion_01",
            "DeathExplosion_02",
            "DeathExplosion_03",
            "DeathExplosion_04",
            "DeathExplosion_05",
            "DeathExplosion_06",
            "DeathExplosion_07",
            "DeathExplosion_08",
        },

        -- 移动中死亡
        moving = {
            "DeathRunning_01",
            "DeathRunning_03",
            "DeathRunning_04",
            "DeathRunning_05",
            "DeathRunning_06",
            "DeathRunning_07",
            "DeathRunning_08",
            "DeathRunning_09",
            "DeathRunning_10",
            "DeathRunning_11a",
            "DeathRunning_11b",
            "DeathRunning_11c",
            "DeathRunning_11d",
            "DeathRunning_11e",
            "DeathRunning_11f",
            "DeathRunning_11g",
            "DeathRunning_12",
            "DeathRunning_13",
            "DeathRunning_14",
            "DeathRunning_15",
            "DeathRunning_16",
            "ex_mix_running_faceplant",
            "ex_mix_running_roll",
            "ex_mix_running_roll_2",
            "ex_mix_running_roll_3",
            "ex_mix_running_trip",
        },

        -- 钝器打击
        club = {
            "club1",
            "club2",
            "club3",
            "club4",
        },

        drown = {
            "Choked_Barnacle",
        },

        -- 头部中弹
        head = {
            "16head",
            "bd_death_head_01",
            "bd_death_head_02",
            "bd_death_head_03",
            "bd_death_head_04",
            "bd_death_head_05",
            "bd_death_head_07",
            "bd_death_head_08",
            "bd_death_head_multi_01",
            "bd_death_head_multi_02",
            "bd_death_head_multi_03",
            "bd_death_head_short_01",
            "bd_death_head_short_02",
            "bd_death_head_short_03",
            "bd_death_head_single_01",
            "bd_death_head_single_02",
            "bd_death_head_single_03",
            "ex_demo_headshot",
            "ex_engineer_headshot",
            "ex_headshotback",
            "ex_headshotfront",
            "ex_heavy_headshot",
            "ex_medic_headshot",
            "ex_mix_falling_back_2_headshot",
            "ex_mix_headshot_1",
            "ex_mix_headshot_10",
            "ex_mix_headshot_11",
            "ex_mix_headshot_2",
            "ex_mix_headshot_3",
            "ex_mix_headshot_4",
            "ex_mix_headshot_5",
            "ex_mix_headshot_6",
            "ex_mix_headshot_8",
            "ex_mix_headshot_9",
            "ex_mix_shot_in_back_headshot",
            "ex_pyro_headshot",
            "ex_scout_headshot",
            "ex_sniper_headshot",
            "ex_soldier_headshot",
            "ex_spy_headshot",
        },

        -- 颈部中弹
        neck = {
            "bd_death_neck_short_01",
            "bd_death_neck_short_02",
            "bd_death_neck_short_03",
            "bd_death_neck_short_04",
        },

        -- 霰弹枪命中
        shotgun = {
            "ex_shotgunback1",
            "ex_shotgunback2",
            "ex_shotgunback3",
            "ex_shotgunback4",
            "ex_shotgunback5",
            "ex_shotgunback6",
            "ex_shotgunback7",
        },

        -- 骨盆/下腹中弹
        pelvis = {
            "16gutshot",
            "bd_death_stomach_multi_01",
            "bd_death_stomach_short_01",
            "bd_death_stomach_short_02",
            "bd_death_stomach_single_01",
            "bd_death_stomach_single_02",
            "ex_mix_hit_gut",
        },

        -- 背部中弹/背刺
        back = {
            "16back",
            "bd_death_slasher_back",
            "ex_demo_backstab",
            "ex_engineer_backstab",
            "ex_heavy_backstab",
            "ex_medic_backstab",
            "ex_mix_flying_back",
            "ex_pyro_backstab",
            "ex_scout_backstab",
            "ex_sniper_backstab",
            "ex_soldier_backstab",
            "ex_spy_backstab",
        },

        -- 左臂受伤
        leftArm = {
            "bd_death_leftarm_multi_01",
            "bd_death_leftarm_multi_02",
            "bd_death_leftarm_multi_03",
            "bd_death_leftarm_multi_04",
            "bd_death_leftarm_short_01",
            "bd_death_leftarm_short_02",
            "bd_death_leftarm_short_03",
            "bd_death_leftarm_single_01",
            "bd_death_leftarm_single_02",
            "bd_death_leftarm_single_03",
            "ex_mix_hit_Left_shoulder",
            "ex_mix_hit_leftarm_2",
        },

        -- 右臂受伤
        rightArm = {
            "bd_death_rightarm_01",
            "bd_death_rightarm_02",
            "bd_death_rightarm_multi_01",
            "bd_death_rightarm_multi_02",
            "bd_death_rightarm_single_01",
            "bd_death_rightarm_single_02",
            "bd_death_rightarm_single_03",
            "bd_death_rightarm_single_04",
            "ex_mix_flying_forward_rightarm",
            "ex_mix_right_arm",
            "ex_mix_right_arm_3",
            "ex_mix_rightarm_2",
        },

        -- 左腿受伤（含通用腿部动画）
        leftLeg = {
            "bd_death_leftleg_long_01",
            "bd_death_leftleg_long_02",
            "bd_death_leftleg_short_01",
            "bd_death_leftleg_short_02",
            "bd_death_leftleg_short_03",
            "bd_death_leftleg_short_04",
            "bd_death_leftleg_short_05",
            "bd_death_leftleg_short_06",
            "bd_death_leftleg_short_07",
            "bd_death_leftleg_short_08",
            "bd_death_leg_01",
            "bd_death_leg_02",
            "bd_death_leg_03",
            "bd_death_leg_04",
            "bd_death_leg_05",
            "bd_death_leg_06",
            "bd_death_leg_07",
            "bd_death_leg_08",
            "ex_mix_groin_hit_left_leg",
            "ex_mix_hit_left_leg",
        },

        -- 右腿受伤（含通用腿部动画）
        rightLeg = {
            "bd_death_rightleg_multi_01",
            "bd_death_rightleg_multi_02",
            "bd_death_rightleg_multi_03",
            "bd_death_rightleg_short_01",
            "bd_death_rightleg_short_02",
            "bd_death_rightleg_single_01",
            "bd_death_rightleg_single_02",
            "bd_death_rightleg_single_03",
            "bd_death_rightleg_single_04",
            "bd_death_rightleg_single_05",
            "bd_death_leg_01",
            "bd_death_leg_02",
            "bd_death_leg_03",
            "bd_death_leg_04",
            "bd_death_leg_05",
            "bd_death_leg_06",
            "bd_death_leg_07",
            "bd_death_leg_08",
            "ex_mix_groin_hit_right_leg",
        },

        -- 躯干/胸腹中弹
        torso = {
            "16death1",
            "16death2",
            "16death3",
            "16forward",
            "16left",
            "16right",
            "16crouch_die",
            "bd_death_torso_long_01",
            "bd_death_torso_long_02",
            "bd_death_torso_long_03",
            "bd_death_torso_short_01",
            "bd_death_torso_short_02",
            "bd_death_torso_short_03",
            "bd_death_torso_short_04",
            "bd_death_torso_short_05",
            "bd_death_torso_short_06",
            "bd_death_torso_short_07",
            "bd_death_torso_short_08",
            "bd_death_torso_short_09",
            "bd_death_torso_short_10",
            "bd_death_torso_short_11",
            "bd_death_torso_short_12",
            "bd_death_torso_short_13",
            "bd_death_torso_short_14",
            "bd_death_torso_short_15",
            "bd_death_torso_short_16",
            "bd_death_torso_short_17",
            "bd_death_torso_short_18",
            "bd_death_torso_short_19",
            "bd_death_torso_short_20",
            "bd_death_torso_short_21",
            "cod_1_torso_1",
            "cod_1_torso_2",
            "cod_1_torso_3",
            "cod_1_torso_4",
            "cod_1_torso_5",
            "cod_1_torso_6",
            "cod_1_torso_7",
        },

        -- 斩击/切割（正面/侧面，背部斩击已归类到 back）
        slasher = {
            "bd_death_slasher_front",
            "bd_death_slasher_left",
            "bd_death_slasher_right",
        },

        -- 通用死亡（兜底）
        dying = {
            "dying1",
            "dying2",
            "dying3",
            "dying4",
            "dying5",
            "dying6",
            "dying7",
        },
    },

    -- ============================================================
    -- 爬行动画（CRAWLING 状态）
    -- ============================================================
    crawl = {
        -- 面朝上爬行
        face_up = {
            male = { "crawling1" },
            female = { "crawling1_f" },
        },
        -- 面朝下爬行（直接提供男女动画列表）
        face_down = {
            male = {
                "crawling5",
                "crawling6",
                -- "crawling7", -- 暂未使用，保留待启用
            },
            female = {
                "crawling5_f",
                "crawling6_f",
                -- "crawling7_f", -- 暂未使用，保留待启用
            },
        },
    },

    -- ============================================================
    -- 挣扎动画（WRITHING 状态）
    -- ============================================================
    writhe = {
        face_up = { "writhing1" },
        face_down = { "writhing2" },
    },

    -- ============================================================
    -- 自救动画（SELF_REVIVING 状态）
    -- ============================================================
    self_revive = {
        face_up = { "crawling_self_revive1", "crawling_self_revive2" },
        face_down = { "crawling_down_idle" },
    },

    -- ============================================================
    -- 起身动画（GETTING_UP 状态）
    -- ============================================================
    getting_up = {
        face_up = { "crawling_up_getup1", "crawling_up_getup2" },
        face_down = { "crawling_down_getup1", "crawling_down_getup2" },
    },

    -- ============================================================
    -- 杂项动画（暂未使用）
    -- ============================================================
    misc = {
        "ragdoll",
        "crawling_ally_revive",
        "crawling2",
        "crawling3",
        "crawling3_f",
        "crawling4",
        -- 这些爬行动画未被主选择逻辑使用，但保留在此
    },
}

return animationCategories
