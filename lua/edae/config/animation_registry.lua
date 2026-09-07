-- lua/edae/config/animation_registry.lua
-- 场景动画注册表（包含 Artagdoll 集成）
-- 每个场景键对应一个资源列表，选择时随机选取

local DEFAULT_MODEL = "models/brutal_deaths/model_anim_modify.mdl"
local ARTAGDOLL_MODEL = "models/AREAnims/model_anim.mdl"

local SceneRegistry = {

    -- ============================================================
    -- 死亡场景（FALLING 状态）
    -- ============================================================

    -- 燃烧死亡
    DEATH_FIRE = {
        -- 默认模型
        { model = DEFAULT_MODEL,   seq = "bd_death_fire1" },
        { model = DEFAULT_MODEL,   seq = "ex_engineer_burn" },
        { model = DEFAULT_MODEL,   seq = "ex_heavy_burn" },
        { model = DEFAULT_MODEL,   seq = "ex_medic_burn" },
        { model = DEFAULT_MODEL,   seq = "ex_movingonfire" },
        { model = DEFAULT_MODEL,   seq = "ex_runonfire1" },
        { model = DEFAULT_MODEL,   seq = "ex_runonfire2" },
        { model = DEFAULT_MODEL,   seq = "ex_scout_burn" },
        { model = DEFAULT_MODEL,   seq = "ex_sniper_burn" },
        { model = DEFAULT_MODEL,   seq = "ex_soldier_burn" },
        { model = DEFAULT_MODEL,   seq = "ex_spy_burn" },
        -- Artagdoll
        { model = ARTAGDOLL_MODEL, seq = "Burning" },
    },

    -- 爆炸死亡
    DEATH_EXPLOSION = {
        { model = DEFAULT_MODEL,   seq = "DeathExplosion_01" },
        { model = DEFAULT_MODEL,   seq = "DeathExplosion_02" },
        { model = DEFAULT_MODEL,   seq = "DeathExplosion_03" },
        { model = DEFAULT_MODEL,   seq = "DeathExplosion_04" },
        { model = DEFAULT_MODEL,   seq = "DeathExplosion_05" },
        { model = DEFAULT_MODEL,   seq = "DeathExplosion_06" },
        { model = DEFAULT_MODEL,   seq = "DeathExplosion_07" },
        { model = DEFAULT_MODEL,   seq = "DeathExplosion_08" },
        -- Artagdoll 翻滚
        { model = ARTAGDOLL_MODEL, seq = "Tumbling" },
        { model = ARTAGDOLL_MODEL, seq = "LEFT_Tumbling" },
    },

    -- 移动中死亡
    DEATH_MOVING = {
        { model = DEFAULT_MODEL,   seq = "DeathRunning_01" },
        { model = DEFAULT_MODEL,   seq = "DeathRunning_03" },
        { model = DEFAULT_MODEL,   seq = "DeathRunning_04" },
        { model = DEFAULT_MODEL,   seq = "DeathRunning_05" },
        { model = DEFAULT_MODEL,   seq = "DeathRunning_06" },
        { model = DEFAULT_MODEL,   seq = "DeathRunning_07" },
        { model = DEFAULT_MODEL,   seq = "DeathRunning_08" },
        { model = DEFAULT_MODEL,   seq = "DeathRunning_09" },
        { model = DEFAULT_MODEL,   seq = "DeathRunning_10" },
        { model = DEFAULT_MODEL,   seq = "DeathRunning_11a" },
        { model = DEFAULT_MODEL,   seq = "DeathRunning_11b" },
        { model = DEFAULT_MODEL,   seq = "DeathRunning_11c" },
        { model = DEFAULT_MODEL,   seq = "DeathRunning_11d" },
        { model = DEFAULT_MODEL,   seq = "DeathRunning_11e" },
        { model = DEFAULT_MODEL,   seq = "DeathRunning_11f" },
        { model = DEFAULT_MODEL,   seq = "DeathRunning_11g" },
        { model = DEFAULT_MODEL,   seq = "DeathRunning_12" },
        { model = DEFAULT_MODEL,   seq = "DeathRunning_13" },
        { model = DEFAULT_MODEL,   seq = "DeathRunning_14" },
        { model = DEFAULT_MODEL,   seq = "DeathRunning_15" },
        { model = DEFAULT_MODEL,   seq = "DeathRunning_16" },
        { model = DEFAULT_MODEL,   seq = "ex_mix_running_faceplant" },
        { model = DEFAULT_MODEL,   seq = "ex_mix_running_roll" },
        { model = DEFAULT_MODEL,   seq = "ex_mix_running_roll_2" },
        { model = DEFAULT_MODEL,   seq = "ex_mix_running_roll_3" },
        { model = DEFAULT_MODEL,   seq = "ex_mix_running_trip" },
        -- Artagdoll 坠落
        { model = ARTAGDOLL_MODEL, seq = "Falling" },
        { model = ARTAGDOLL_MODEL, seq = "Falling2" },
    },

    -- 钝器打击
    DEATH_CLUB = {
        { model = DEFAULT_MODEL,   seq = "club1" },
        { model = DEFAULT_MODEL,   seq = "club2" },
        { model = DEFAULT_MODEL,   seq = "club3" },
        { model = DEFAULT_MODEL,   seq = "club4" },
        -- Artagdoll 蜷缩/踉跄
        { model = ARTAGDOLL_MODEL, seq = "Cower" },
        { model = ARTAGDOLL_MODEL, seq = "StumbleV2" },
    },

    -- 头部中弹
    DEATH_HEADSHOT = {
        { model = DEFAULT_MODEL,   seq = "16head" },
        { model = DEFAULT_MODEL,   seq = "bd_death_head_01" },
        { model = DEFAULT_MODEL,   seq = "bd_death_head_02" },
        { model = DEFAULT_MODEL,   seq = "bd_death_head_03" },
        { model = DEFAULT_MODEL,   seq = "bd_death_head_04" },
        { model = DEFAULT_MODEL,   seq = "bd_death_head_05" },
        { model = DEFAULT_MODEL,   seq = "bd_death_head_07" },
        { model = DEFAULT_MODEL,   seq = "bd_death_head_08" },
        { model = DEFAULT_MODEL,   seq = "bd_death_head_multi_01" },
        { model = DEFAULT_MODEL,   seq = "bd_death_head_multi_02" },
        { model = DEFAULT_MODEL,   seq = "bd_death_head_multi_03" },
        { model = DEFAULT_MODEL,   seq = "bd_death_head_short_01" },
        { model = DEFAULT_MODEL,   seq = "bd_death_head_short_02" },
        { model = DEFAULT_MODEL,   seq = "bd_death_head_short_03" },
        { model = DEFAULT_MODEL,   seq = "bd_death_head_single_01" },
        { model = DEFAULT_MODEL,   seq = "bd_death_head_single_02" },
        { model = DEFAULT_MODEL,   seq = "bd_death_head_single_03" },
        { model = DEFAULT_MODEL,   seq = "ex_demo_headshot" },
        { model = DEFAULT_MODEL,   seq = "ex_engineer_headshot" },
        { model = DEFAULT_MODEL,   seq = "ex_headshotback" },
        { model = DEFAULT_MODEL,   seq = "ex_headshotfront" },
        { model = DEFAULT_MODEL,   seq = "ex_heavy_headshot" },
        { model = DEFAULT_MODEL,   seq = "ex_medic_headshot" },
        { model = DEFAULT_MODEL,   seq = "ex_mix_falling_back_2_headshot" },
        { model = DEFAULT_MODEL,   seq = "ex_mix_headshot_1" },
        { model = DEFAULT_MODEL,   seq = "ex_mix_headshot_10" },
        { model = DEFAULT_MODEL,   seq = "ex_mix_headshot_11" },
        { model = DEFAULT_MODEL,   seq = "ex_mix_headshot_2" },
        { model = DEFAULT_MODEL,   seq = "ex_mix_headshot_3" },
        { model = DEFAULT_MODEL,   seq = "ex_mix_headshot_4" },
        { model = DEFAULT_MODEL,   seq = "ex_mix_headshot_5" },
        { model = DEFAULT_MODEL,   seq = "ex_mix_headshot_6" },
        { model = DEFAULT_MODEL,   seq = "ex_mix_headshot_8" },
        { model = DEFAULT_MODEL,   seq = "ex_mix_headshot_9" },
        { model = DEFAULT_MODEL,   seq = "ex_mix_shot_in_back_headshot" },
        { model = DEFAULT_MODEL,   seq = "ex_pyro_headshot" },
        { model = DEFAULT_MODEL,   seq = "ex_scout_headshot" },
        { model = DEFAULT_MODEL,   seq = "ex_sniper_headshot" },
        { model = DEFAULT_MODEL,   seq = "ex_soldier_headshot" },
        { model = DEFAULT_MODEL,   seq = "ex_spy_headshot" },
        -- Artagdoll 爆头变体
        { model = ARTAGDOLL_MODEL, seq = "NewHeadshot" },
        { model = ARTAGDOLL_MODEL, seq = "Decerebrate" },
        { model = ARTAGDOLL_MODEL, seq = "StuntWall" },
        { model = ARTAGDOLL_MODEL, seq = "HeadshotCurl" },
        { model = ARTAGDOLL_MODEL, seq = "HeadshotLeft" },
        { model = ARTAGDOLL_MODEL, seq = "HeadshotRight" },
    },

    -- 颈部中弹
    DEATH_NECK = {
        { model = DEFAULT_MODEL, seq = "bd_death_neck_short_01" },
        { model = DEFAULT_MODEL, seq = "bd_death_neck_short_02" },
        { model = DEFAULT_MODEL, seq = "bd_death_neck_short_03" },
        { model = DEFAULT_MODEL, seq = "bd_death_neck_short_04" },
    },

    -- 霰弹枪命中
    DEATH_SHOTGUN = {
        { model = DEFAULT_MODEL, seq = "ex_shotgunback1" },
        { model = DEFAULT_MODEL, seq = "ex_shotgunback2" },
        { model = DEFAULT_MODEL, seq = "ex_shotgunback3" },
        { model = DEFAULT_MODEL, seq = "ex_shotgunback4" },
        { model = DEFAULT_MODEL, seq = "ex_shotgunback5" },
        { model = DEFAULT_MODEL, seq = "ex_shotgunback6" },
        { model = DEFAULT_MODEL, seq = "ex_shotgunback7" },
    },

    -- 骨盆/下腹中弹
    DEATH_PELVIS = {
        { model = DEFAULT_MODEL, seq = "16gutshot" },
        { model = DEFAULT_MODEL, seq = "bd_death_stomach_multi_01" },
        { model = DEFAULT_MODEL, seq = "bd_death_stomach_short_01" },
        { model = DEFAULT_MODEL, seq = "bd_death_stomach_short_02" },
        { model = DEFAULT_MODEL, seq = "bd_death_stomach_single_01" },
        { model = DEFAULT_MODEL, seq = "bd_death_stomach_single_02" },
        { model = DEFAULT_MODEL, seq = "ex_mix_hit_gut" },
    },

    -- 背部中弹/背刺
    DEATH_BACK = {
        { model = DEFAULT_MODEL, seq = "16back" },
        { model = DEFAULT_MODEL, seq = "bd_death_slasher_back" },
        { model = DEFAULT_MODEL, seq = "ex_demo_backstab" },
        { model = DEFAULT_MODEL, seq = "ex_engineer_backstab" },
        { model = DEFAULT_MODEL, seq = "ex_heavy_backstab" },
        { model = DEFAULT_MODEL, seq = "ex_medic_backstab" },
        { model = DEFAULT_MODEL, seq = "ex_mix_flying_back" },
        { model = DEFAULT_MODEL, seq = "ex_pyro_backstab" },
        { model = DEFAULT_MODEL, seq = "ex_scout_backstab" },
        { model = DEFAULT_MODEL, seq = "ex_sniper_backstab" },
        { model = DEFAULT_MODEL, seq = "ex_soldier_backstab" },
        { model = DEFAULT_MODEL, seq = "ex_spy_backstab" },
    },

    -- 左臂受伤
    DEATH_LEFTARM = {
        { model = DEFAULT_MODEL, seq = "bd_death_leftarm_multi_01" },
        { model = DEFAULT_MODEL, seq = "bd_death_leftarm_multi_02" },
        { model = DEFAULT_MODEL, seq = "bd_death_leftarm_multi_03" },
        { model = DEFAULT_MODEL, seq = "bd_death_leftarm_multi_04" },
        { model = DEFAULT_MODEL, seq = "bd_death_leftarm_short_01" },
        { model = DEFAULT_MODEL, seq = "bd_death_leftarm_short_02" },
        { model = DEFAULT_MODEL, seq = "bd_death_leftarm_short_03" },
        { model = DEFAULT_MODEL, seq = "bd_death_leftarm_single_01" },
        { model = DEFAULT_MODEL, seq = "bd_death_leftarm_single_02" },
        { model = DEFAULT_MODEL, seq = "bd_death_leftarm_single_03" },
        { model = DEFAULT_MODEL, seq = "ex_mix_hit_Left_shoulder" },
        { model = DEFAULT_MODEL, seq = "ex_mix_hit_leftarm_2" },
    },

    -- 右臂受伤
    DEATH_RIGHTARM = {
        { model = DEFAULT_MODEL, seq = "bd_death_rightarm_01" },
        { model = DEFAULT_MODEL, seq = "bd_death_rightarm_02" },
        { model = DEFAULT_MODEL, seq = "bd_death_rightarm_multi_01" },
        { model = DEFAULT_MODEL, seq = "bd_death_rightarm_multi_02" },
        { model = DEFAULT_MODEL, seq = "bd_death_rightarm_single_01" },
        { model = DEFAULT_MODEL, seq = "bd_death_rightarm_single_02" },
        { model = DEFAULT_MODEL, seq = "bd_death_rightarm_single_03" },
        { model = DEFAULT_MODEL, seq = "bd_death_rightarm_single_04" },
        { model = DEFAULT_MODEL, seq = "ex_mix_flying_forward_rightarm" },
        { model = DEFAULT_MODEL, seq = "ex_mix_right_arm" },
        { model = DEFAULT_MODEL, seq = "ex_mix_right_arm_3" },
        { model = DEFAULT_MODEL, seq = "ex_mix_rightarm_2" },
    },

    -- 左腿受伤
    DEATH_LEFTLEG = {
        { model = DEFAULT_MODEL, seq = "bd_death_leftleg_long_01" },
        { model = DEFAULT_MODEL, seq = "bd_death_leftleg_long_02" },
        { model = DEFAULT_MODEL, seq = "bd_death_leftleg_short_01" },
        { model = DEFAULT_MODEL, seq = "bd_death_leftleg_short_02" },
        { model = DEFAULT_MODEL, seq = "bd_death_leftleg_short_03" },
        { model = DEFAULT_MODEL, seq = "bd_death_leftleg_short_04" },
        { model = DEFAULT_MODEL, seq = "bd_death_leftleg_short_05" },
        { model = DEFAULT_MODEL, seq = "bd_death_leftleg_short_06" },
        { model = DEFAULT_MODEL, seq = "bd_death_leftleg_short_07" },
        { model = DEFAULT_MODEL, seq = "bd_death_leftleg_short_08" },
        { model = DEFAULT_MODEL, seq = "bd_death_leg_01" },
        { model = DEFAULT_MODEL, seq = "bd_death_leg_02" },
        { model = DEFAULT_MODEL, seq = "bd_death_leg_03" },
        { model = DEFAULT_MODEL, seq = "bd_death_leg_04" },
        { model = DEFAULT_MODEL, seq = "bd_death_leg_05" },
        { model = DEFAULT_MODEL, seq = "bd_death_leg_06" },
        { model = DEFAULT_MODEL, seq = "bd_death_leg_07" },
        { model = DEFAULT_MODEL, seq = "bd_death_leg_08" },
        { model = DEFAULT_MODEL, seq = "ex_mix_groin_hit_left_leg" },
        { model = DEFAULT_MODEL, seq = "ex_mix_hit_left_leg" },
    },

    -- 右腿受伤
    DEATH_RIGHTLEG = {
        { model = DEFAULT_MODEL, seq = "bd_death_rightleg_multi_01" },
        { model = DEFAULT_MODEL, seq = "bd_death_rightleg_multi_02" },
        { model = DEFAULT_MODEL, seq = "bd_death_rightleg_multi_03" },
        { model = DEFAULT_MODEL, seq = "bd_death_rightleg_short_01" },
        { model = DEFAULT_MODEL, seq = "bd_death_rightleg_short_02" },
        { model = DEFAULT_MODEL, seq = "bd_death_rightleg_single_01" },
        { model = DEFAULT_MODEL, seq = "bd_death_rightleg_single_02" },
        { model = DEFAULT_MODEL, seq = "bd_death_rightleg_single_03" },
        { model = DEFAULT_MODEL, seq = "bd_death_rightleg_single_04" },
        { model = DEFAULT_MODEL, seq = "bd_death_rightleg_single_05" },
        { model = DEFAULT_MODEL, seq = "bd_death_leg_01" },
        { model = DEFAULT_MODEL, seq = "bd_death_leg_02" },
        { model = DEFAULT_MODEL, seq = "bd_death_leg_03" },
        { model = DEFAULT_MODEL, seq = "bd_death_leg_04" },
        { model = DEFAULT_MODEL, seq = "bd_death_leg_05" },
        { model = DEFAULT_MODEL, seq = "bd_death_leg_06" },
        { model = DEFAULT_MODEL, seq = "bd_death_leg_07" },
        { model = DEFAULT_MODEL, seq = "bd_death_leg_08" },
        { model = DEFAULT_MODEL, seq = "ex_mix_groin_hit_right_leg" },
    },

    -- 躯干/胸腹中弹
    DEATH_TORSO = {
        { model = DEFAULT_MODEL, seq = "16death1" },
        { model = DEFAULT_MODEL, seq = "16death2" },
        { model = DEFAULT_MODEL, seq = "16death3" },
        { model = DEFAULT_MODEL, seq = "16forward" },
        { model = DEFAULT_MODEL, seq = "16left" },
        { model = DEFAULT_MODEL, seq = "16right" },
        { model = DEFAULT_MODEL, seq = "16crouch_die" },
        { model = DEFAULT_MODEL, seq = "bd_death_torso_long_01" },
        { model = DEFAULT_MODEL, seq = "bd_death_torso_long_02" },
        { model = DEFAULT_MODEL, seq = "bd_death_torso_long_03" },
        { model = DEFAULT_MODEL, seq = "bd_death_torso_short_01" },
        { model = DEFAULT_MODEL, seq = "bd_death_torso_short_02" },
        { model = DEFAULT_MODEL, seq = "bd_death_torso_short_03" },
        { model = DEFAULT_MODEL, seq = "bd_death_torso_short_04" },
        { model = DEFAULT_MODEL, seq = "bd_death_torso_short_05" },
        { model = DEFAULT_MODEL, seq = "bd_death_torso_short_06" },
        { model = DEFAULT_MODEL, seq = "bd_death_torso_short_07" },
        { model = DEFAULT_MODEL, seq = "bd_death_torso_short_08" },
        { model = DEFAULT_MODEL, seq = "bd_death_torso_short_09" },
        { model = DEFAULT_MODEL, seq = "bd_death_torso_short_10" },
        { model = DEFAULT_MODEL, seq = "bd_death_torso_short_11" },
        { model = DEFAULT_MODEL, seq = "bd_death_torso_short_12" },
        { model = DEFAULT_MODEL, seq = "bd_death_torso_short_13" },
        { model = DEFAULT_MODEL, seq = "bd_death_torso_short_14" },
        { model = DEFAULT_MODEL, seq = "bd_death_torso_short_15" },
        { model = DEFAULT_MODEL, seq = "bd_death_torso_short_16" },
        { model = DEFAULT_MODEL, seq = "bd_death_torso_short_17" },
        { model = DEFAULT_MODEL, seq = "bd_death_torso_short_18" },
        { model = DEFAULT_MODEL, seq = "bd_death_torso_short_19" },
        { model = DEFAULT_MODEL, seq = "bd_death_torso_short_20" },
        { model = DEFAULT_MODEL, seq = "bd_death_torso_short_21" },
        { model = DEFAULT_MODEL, seq = "cod_1_torso_1" },
        { model = DEFAULT_MODEL, seq = "cod_1_torso_2" },
        { model = DEFAULT_MODEL, seq = "cod_1_torso_3" },
        { model = DEFAULT_MODEL, seq = "cod_1_torso_4" },
        { model = DEFAULT_MODEL, seq = "cod_1_torso_5" },
        { model = DEFAULT_MODEL, seq = "cod_1_torso_6" },
        { model = DEFAULT_MODEL, seq = "cod_1_torso_7" },
    },

    -- 斩击/切割
    DEATH_SLASHER = {
        { model = DEFAULT_MODEL, seq = "bd_death_slasher_front" },
        { model = DEFAULT_MODEL, seq = "bd_death_slasher_left" },
        { model = DEFAULT_MODEL, seq = "bd_death_slasher_right" },
    },

    -- 通用死亡（兜底）
    DEATH_GENERIC = {
        { model = DEFAULT_MODEL,   seq = "dying1" },
        { model = DEFAULT_MODEL,   seq = "dying2" },
        { model = DEFAULT_MODEL,   seq = "dying3" },
        { model = DEFAULT_MODEL,   seq = "dying4" },
        { model = DEFAULT_MODEL,   seq = "dying5" },
        { model = DEFAULT_MODEL,   seq = "dying6" },
        { model = DEFAULT_MODEL,   seq = "dying7" },
        -- Artagdoll 死亡/姿势
        { model = ARTAGDOLL_MODEL, seq = "Dying1" },
        { model = ARTAGDOLL_MODEL, seq = "Dying2" },
        { model = ARTAGDOLL_MODEL, seq = "Dying3" },
        { model = ARTAGDOLL_MODEL, seq = "Dying4" },
        { model = ARTAGDOLL_MODEL, seq = "Dying5" },
        { model = ARTAGDOLL_MODEL, seq = "Dying6" },
        { model = ARTAGDOLL_MODEL, seq = "DeathPose1" },
        { model = ARTAGDOLL_MODEL, seq = "DeathPose2" },
        { model = ARTAGDOLL_MODEL, seq = "DeathPose3" },
        { model = ARTAGDOLL_MODEL, seq = "DeathPose4" },
        { model = ARTAGDOLL_MODEL, seq = "ragdoll" }, -- 静态姿势
    },

    -- ============================================================
    -- 爬行场景（CRAWLING 状态）
    -- ============================================================
    CRAWLING_FACE_UP_MALE = {
        { model = DEFAULT_MODEL,   seq = "crawling1" },
        { model = ARTAGDOLL_MODEL, seq = "Crawling" }, -- 备选
    },
    CRAWLING_FACE_UP_FEMALE = {
        { model = DEFAULT_MODEL,   seq = "crawling1_f" },
        { model = ARTAGDOLL_MODEL, seq = "Crawling" },
    },
    CRAWLING_FACE_DOWN_MALE = {
        { model = DEFAULT_MODEL,   seq = "crawling5" },
        { model = DEFAULT_MODEL,   seq = "crawling6" },
        { model = ARTAGDOLL_MODEL, seq = "Crawling" },
    },
    CRAWLING_FACE_DOWN_FEMALE = {
        { model = DEFAULT_MODEL,   seq = "crawling5_f" },
        { model = DEFAULT_MODEL,   seq = "crawling6_f" },
        { model = ARTAGDOLL_MODEL, seq = "Crawling" },
    },

    -- ============================================================
    -- 挣扎场景（WRITHING 状态）
    -- ============================================================
    WRITHING_FACE_UP = {
        { model = DEFAULT_MODEL,   seq = "writhing1" },
        { model = ARTAGDOLL_MODEL, seq = "Seizure" },
        { model = ARTAGDOLL_MODEL, seq = "Cower" }, -- 也可用作挣扎
    },
    WRITHING_FACE_DOWN = {
        { model = DEFAULT_MODEL,   seq = "writhing2" },
        { model = ARTAGDOLL_MODEL, seq = "Seizure" },
        { model = ARTAGDOLL_MODEL, seq = "Cower" },
    },

    -- ============================================================
    -- 溺水场景（DROWNING 状态）
    -- ============================================================
    DROWNING = {
        { model = DEFAULT_MODEL,   seq = "Choked_Barnacle" },
        { model = ARTAGDOLL_MODEL, seq = "Drowning" },
    },

    -- ============================================================
    -- 自救场景（SELF_REVIVING 状态）
    -- ============================================================
    SELF_REVIVE_FACE_UP = {
        { model = DEFAULT_MODEL, seq = "crawling_self_revive1" },
        { model = DEFAULT_MODEL, seq = "crawling_self_revive2" },
        -- 暂无 Artagdoll 合适动画，可留空或复用 Crawling
    },
    SELF_REVIVE_FACE_DOWN = {
        { model = DEFAULT_MODEL, seq = "crawling_down_idle" },
    },

    -- ============================================================
    -- 起身场景（GETTING_UP 状态）
    -- ============================================================
    GETTING_UP_FACE_UP = {
        { model = DEFAULT_MODEL, seq = "crawling_up_getup1" },
        { model = DEFAULT_MODEL, seq = "crawling_up_getup2" },
    },
    GETTING_UP_FACE_DOWN = {
        { model = DEFAULT_MODEL, seq = "crawling_down_getup1" },
        { model = DEFAULT_MODEL, seq = "crawling_down_getup2" },
    },

    -- ============================================================
    -- 杂项（暂未主动使用，保留备用）
    -- ============================================================
    MISC = {
        { model = DEFAULT_MODEL,   seq = "ragdoll" },
        { model = DEFAULT_MODEL,   seq = "crawling_ally_revive" },
        { model = DEFAULT_MODEL,   seq = "crawling2" },
        { model = DEFAULT_MODEL,   seq = "crawling3" },
        { model = DEFAULT_MODEL,   seq = "crawling3_f" },
        { model = DEFAULT_MODEL,   seq = "crawling4" },
        -- Artagdoll 其他未分类
        { model = ARTAGDOLL_MODEL, seq = "Balance" },
    },
}

return SceneRegistry
