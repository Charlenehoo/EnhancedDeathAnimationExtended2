local M = {}

local function makeReverseTable(t)
    local reverseT = {}
    for k, v in pairs(t) do
        reverseT[v] = k
    end
    return reverseT
end

M.SCHEDULE_ENUM               = {
    --- The schedule enum limit
    LAST_SHARED_SCHEDULE = 88,
    --- Begins AI script based on NPC's `m_hCine` save value.
    SCHED_AISCRIPT = 56,
    --- Idle stance and face ideal yaw angles.
    SCHED_ALERT_FACE = 5,
    SCHED_ALERT_FACE_BESTSOUND = 6,
    SCHED_ALERT_REACT_TO_COMBAT_SOUND = 7,
    --- Rotate 180 degrees and back to check for enemies.
    SCHED_ALERT_SCAN = 8,
    --- Remain idle until an enemy is heard or found.
    SCHED_ALERT_STAND = 9,
    --- Walk until an enemy is heard or found.
    SCHED_ALERT_WALK = 10,
    --- Remain idle until provoked or an enemy is found.
    SCHED_AMBUSH = 52,
    --- Performs ACT_ARM.
    SCHED_ARM_WEAPON = 48,
    --- Back away from enemy. If not possible to back away then go behind enemy.
    SCHED_BACK_AWAY_FROM_ENEMY = 24,
    --- Requires valid enemy, backs away from SaveValue: m_vSavePosition
    SCHED_BACK_AWAY_FROM_SAVE_POSITION = 26,
    --- Heavy damage was taken for the first time in a while.
    SCHED_BIG_FLINCH = 23,

    --- Begin chasing an enemy.
    SCHED_CHASE_ENEMY = 17,
    -- //=========================================================
    -- // > ChaseEnemy
    -- //=========================================================
    -- AI_DEFINE_SCHEDULE
    -- (
    -- 	SCHED_CHASE_ENEMY,

    -- 	"	Tasks"
    -- 	"		TASK_STOP_MOVING				0"
    -- 	"		TASK_SET_FAIL_SCHEDULE			SCHEDULE:SCHED_CHASE_ENEMY_FAILED"
    -- //	"		TASK_SET_TOLERANCE_DISTANCE		24"
    -- 	"		TASK_GET_CHASE_PATH_TO_ENEMY	300"
    -- 	"		TASK_RUN_PATH					0"
    -- 	"		TASK_WAIT_FOR_MOVEMENT			0"
    -- 	"		TASK_FACE_ENEMY			0"
    -- 	""
    -- 	"	Interrupts"
    -- 	"		COND_NEW_ENEMY"
    -- 	"		COND_ENEMY_DEAD"
    -- 	"		COND_ENEMY_UNREACHABLE"
    -- 	"		COND_CAN_RANGE_ATTACK1"
    -- 	"		COND_CAN_MELEE_ATTACK1"
    -- 	"		COND_CAN_RANGE_ATTACK2"
    -- 	"		COND_CAN_MELEE_ATTACK2"
    -- 	"		COND_TOO_CLOSE_TO_ATTACK"
    -- 	"		COND_TASK_FAILED"
    -- 	"		COND_LOST_ENEMY"
    -- 	"		COND_BETTER_WEAPON_AVAILABLE"
    -- 	"		COND_HEAR_DANGER"
    -- );

    --- Failed to chase enemy.
    SCHED_CHASE_ENEMY_FAILED = 18,
    --- Face current enemy.
    SCHED_COMBAT_FACE = 12,
    --- Will walk around patrolling an area until an enemy is found.
    SCHED_COMBAT_PATROL = 75,
    SCHED_COMBAT_STAND = 15,
    SCHED_COMBAT_SWEEP = 13,
    SCHED_COMBAT_WALK = 16,
    --- When not moving, will perform ACT_COWER.
    SCHED_COWER = 40,
    --- Regular NPC death.
    SCHED_DIE = 53,
    --- Plays NPC death sound (doesn't kill NPC).
    SCHED_DIE_RAGDOLL = 54,
    --- Holsters active weapon. (Only works with NPC's that can holster weapons)
    SCHED_DISARM_WEAPON = 49,
    SCHED_DROPSHIP_DUSTOFF = 79,
    --- Preform Ducking animation. (Only works with npc_alyx)
    SCHED_DUCK_DODGE = 84,
    --- Search for a place to shoot current enemy.
    SCHED_ESTABLISH_LINE_OF_FIRE = 35,
    --- Fallback from an established line of fire.
    SCHED_ESTABLISH_LINE_OF_FIRE_FALLBACK = 36,
    --- Failed doing current schedule.
    SCHED_FAIL = 81,
    --- Failed to establish a line of fire.
    SCHED_FAIL_ESTABLISH_LINE_OF_FIRE = 38,
    SCHED_FAIL_NOSTOP = 82,
    --- Failed to take cover.
    SCHED_FAIL_TAKE_COVER = 31,
    --- Fall to ground when in the air.
    SCHED_FALL_TO_GROUND = 78,
    --- Will express fear face. (Only works on NPCs with expressions)
    SCHED_FEAR_FACE = 14,
    SCHED_FLEE_FROM_BEST_SOUND = 29,
    --- Plays ACT_FLINCH_PHYSICS.
    SCHED_FLINCH_PHYSICS = 80,
    --- Force walk to SaveValue: m_vecLastPosition (debug).
    SCHED_FORCED_GO = 71,
    --- Force run to SaveValue: m_vecLastPosition (debug).
    SCHED_FORCED_GO_RUN = 72,
    --- Pick up item if within a radius of 5 units.
    SCHED_GET_HEALTHKIT = 66,
    --- Take cover and reload weapon.
    SCHED_HIDE_AND_RELOAD = 50,
    --- Idle stance
    SCHED_IDLE_STAND = 1,
    --- Walk to position.
    SCHED_IDLE_WALK = 2,
    --- Walk to random position within a radius of 200 units.
    SCHED_IDLE_WANDER = 3,
    SCHED_INTERACTION_MOVE_TO_PARTNER = 85,
    SCHED_INTERACTION_WAIT_FOR_PARTNER = 86,
    SCHED_INVESTIGATE_SOUND = 11,
    SCHED_MELEE_ATTACK1 = 41,
    SCHED_MELEE_ATTACK2 = 42,
    --- Move away from player.
    SCHED_MOVE_AWAY = 68,
    --- Stop moving and continue enemy scan.
    SCHED_MOVE_AWAY_END = 70,
    --- Failed to move away; stop moving.
    SCHED_MOVE_AWAY_FAIL = 69,
    --- Move away from enemy while facing it and checking for new enemies.
    SCHED_MOVE_AWAY_FROM_ENEMY = 25,
    --- Move to the range the weapon is preferably used at.
    SCHED_MOVE_TO_WEAPON_RANGE = 34,
    --- Pick up a new weapon if within a radius of 5 units.
    SCHED_NEW_WEAPON = 63,
    --- Fail safe: Create the weapon that the NPC went to pick up if it was removed during pick up schedule.
    SCHED_NEW_WEAPON_CHEAT = 64,
    --- No schedule is being performed.
    SCHED_NONE = 0,
    --- Prevents movement until COND.NPC_UNFREEZE(68) is set.
    SCHED_NPC_FREEZE = 73,
    --- Run to random position and stop if enemy is heard or found.
    SCHED_PATROL_RUN = 76,
    --- Walk to random position and stop if enemy is heard or found.
    SCHED_PATROL_WALK = 74,
    SCHED_PRE_FAIL_ESTABLISH_LINE_OF_FIRE = 37,
    SCHED_RANGE_ATTACK1 = 43,
    SCHED_RANGE_ATTACK2 = 44,
    --- Stop moving and reload until danger is heard.
    SCHED_RELOAD = 51,
    --- Retreat from the established enemy.
    SCHED_RUN_FROM_ENEMY = 32,
    SCHED_RUN_FROM_ENEMY_FALLBACK = 33,
    SCHED_RUN_FROM_ENEMY_MOB = 83,
    --- Run to random position within a radius of 500 units.
    SCHED_RUN_RANDOM = 77,
    SCHED_SCENE_GENERIC = 62,
    SCHED_SCRIPTED_CUSTOM_MOVE = 59,
    SCHED_SCRIPTED_FACE = 61,
    SCHED_SCRIPTED_RUN = 58,
    SCHED_SCRIPTED_WAIT = 60,
    SCHED_SCRIPTED_WALK = 57,
    --- Shoot cover that the enemy is behind.
    SCHED_SHOOT_ENEMY_COVER = 39,
    --- Sets the NPC to a sleep-like state.
    SCHED_SLEEP = 87,
    SCHED_SMALL_FLINCH = 22,
    SCHED_SPECIAL_ATTACK1 = 45,
    SCHED_SPECIAL_ATTACK2 = 46,
    SCHED_STANDOFF = 47,
    SCHED_SWITCH_TO_PENDING_WEAPON = 65,
    SCHED_TAKE_COVER_FROM_BEST_SOUND = 28,
    --- Take cover from current enemy.
    SCHED_TAKE_COVER_FROM_ENEMY = 27,
    --- Flee from SaveValue: vLastKnownLocation
    SCHED_TAKE_COVER_FROM_ORIGIN = 30,

    --- Chase set NPC target.
    SCHED_TARGET_CHASE = 21,
    -- //=========================================================
    -- // > ChaseEnemy
    -- //=========================================================
    -- AI_DEFINE_SCHEDULE
    -- (
    -- 	SCHED_TARGET_CHASE,

    -- 	"	Tasks"
    -- 	"		TASK_STOP_MOVING				0"
    -- //	"		TASK_SET_TOLERANCE_DISTANCE		24"
    -- 	"		TASK_GET_PATH_TO_TARGET			0"
    -- 	"		TASK_RUN_PATH					0"
    -- 	"		TASK_WAIT_FOR_MOVEMENT			0"
    -- 	""
    -- 	"	Interrupts"
    -- 	"		COND_NEW_ENEMY"
    -- 	"		COND_ENEMY_DEAD"
    -- 	"		COND_ENEMY_UNREACHABLE"
    -- 	"		COND_CAN_RANGE_ATTACK1"
    -- 	"		COND_CAN_MELEE_ATTACK1"
    -- 	"		COND_CAN_RANGE_ATTACK2"
    -- 	"		COND_CAN_MELEE_ATTACK2"
    -- 	"		COND_TOO_CLOSE_TO_ATTACK"
    -- 	"		COND_TASK_FAILED"
    -- 	"		COND_LOST_ENEMY"
    -- 	"		COND_BETTER_WEAPON_AVAILABLE"
    -- 	"		COND_HEAR_DANGER"
    -- );

    --- Face NPC target.
    SCHED_TARGET_FACE = 20,
    --- Human victory dance.
    SCHED_VICTORY_DANCE = 19,
    SCHED_WAIT_FOR_SCRIPT = 55,
    SCHED_WAIT_FOR_SPEAK_FINISH = 67,
    --- Spot an enemy and go from an idle state to combat state.
    SCHED_WAKE_ANGRY = 4,
}
M.SCHEDULE_ID_TO_NAME         = makeReverseTable(M.SCHEDULE_ENUM)

M.COMBINE_SCHEDULE_ENUM       = {
    SCHED_COMBINE_SUPPRESS = 88, -- == M.SCHEDULE_ENUM.LAST_SHARED_SCHEDULE == 88, 这似乎很奇怪, 确是正确的, 具体见 C:\Users\CharleneHoo\Dev\Gmod\source-sdk-2013\src\game\server\ai_basenpc.h
    SCHED_COMBINE_COMBAT_FAIL = 89,
    SCHED_COMBINE_VICTORY_DANCE = 90,
    SCHED_COMBINE_COMBAT_FACE = 91,

    SCHED_COMBINE_HIDE_AND_RELOAD = 92,
    --  //=========================================================
    --  // 	SCHED_HIDE_AND_RELOAD	
    --  //=========================================================
    --  DEFINE_SCHEDULE
    --  (
    --  SCHED_COMBINE_HIDE_AND_RELOAD,

    --  "	Tasks"
    --  "		TASK_SET_FAIL_SCHEDULE		SCHEDULE:SCHED_RELOAD"
    --  "		TASK_FIND_COVER_FROM_ENEMY	0"
    --  "		TASK_RUN_PATH				0"
    --  "		TASK_WAIT_FOR_MOVEMENT		0"
    --  "		TASK_REMEMBER				MEMORY:INCOVER"
    --  "		TASK_FACE_ENEMY				0"
    --  "		TASK_RELOAD					0"
    --  ""
    --  "	Interrupts"
    --  "		COND_CAN_MELEE_ATTACK1"
    --  "		COND_CAN_MELEE_ATTACK2"
    --  "		COND_HEAVY_DAMAGE"
    --  "		COND_HEAR_DANGER"
    --  "		COND_HEAR_MOVE_AWAY"
    --  )

    SCHED_COMBINE_SIGNAL_SUPPRESS = 93,
    SCHED_COMBINE_ENTER_OVERWATCH = 94,
    SCHED_COMBINE_OVERWATCH = 95,
    SCHED_COMBINE_ASSAULT = 96,
    SCHED_COMBINE_ESTABLISH_LINE_OF_FIRE = 97,
    SCHED_COMBINE_PRESS_ATTACK = 98,
    SCHED_COMBINE_WAIT_IN_COVER = 99,
    SCHED_COMBINE_RANGE_ATTACK1 = 100,
    SCHED_COMBINE_RANGE_ATTACK2 = 101,
    SCHED_COMBINE_TAKE_COVER1 = 102,
    SCHED_COMBINE_TAKE_COVER_FROM_BEST_SOUND = 103,
    SCHED_COMBINE_RUN_AWAY_FROM_BEST_SOUND = 104,
    SCHED_COMBINE_GRENADE_COVER1 = 105,
    SCHED_COMBINE_TOSS_GRENADE_COVER1 = 106,
    SCHED_COMBINE_TAKECOVER_FAILED = 107,
    SCHED_COMBINE_GRENADE_AND_RELOAD = 108,
    SCHED_COMBINE_PATROL = 109,
    SCHED_COMBINE_BUGBAIT_DISTRACTION = 110,
    SCHED_COMBINE_CHARGE_TURRET = 111,
    SCHED_COMBINE_DROP_GRENADE = 112,
    SCHED_COMBINE_CHARGE_PLAYER = 113,

    SCHED_COMBINE_AR2_ALTFIRE = 116,
    SCHED_COMBINE_FORCED_GRENADE_THROW = 117,
    SCHED_COMBINE_MOVE_TO_FORCED_GREN_LOS = 118,

    SCHED_COMBINE_PATROL_ENEMY = 114,
    SCHED_COMBINE_BURNING_STAND = 115,
    SCHED_COMBINE_FACE_IDEAL_YAW = 119,
    SCHED_COMBINE_MOVE_TO_MELEE = 120,
    --  //=========================================================
    --  // SCHED_COMBINE_PATROL_ENEMY
    --  //
    --  // Used instead if SCHED_COMBINE_PATROL if I have an enemy.
    --  // Wait for the enemy a bit in the hopes of ambushing him.
    --  //=========================================================
    --  DEFINE_SCHEDULE	
    --  (
    --  SCHED_COMBINE_PATROL_ENEMY,

    --  "	Tasks"
    --  "		TASK_STOP_MOVING					0"
    --  "		TASK_WAIT_FACE_ENEMY				1"
    --  "		TASK_WAIT_FACE_ENEMY_RANDOM			3"
    --  ""
    --  "	Interrupts"
    --  "		COND_ENEMY_DEAD"
    --  "		COND_LIGHT_DAMAGE"
    --  "		COND_HEAVY_DAMAGE"
    --  "		COND_HEAR_DANGER"
    --  "		COND_HEAR_MOVE_AWAY"
    --  "		COND_NEW_ENEMY"
    --  "		COND_SEE_ENEMY"
    --  "		COND_CAN_RANGE_ATTACK1"
    --  "		COND_CAN_RANGE_ATTACK2"
    --  )

    --  DEFINE_SCHEDULE
    --  (
    --  SCHED_COMBINE_BURNING_STAND,

    --  "	Tasks"
    --  "		TASK_SET_ACTIVITY				ACTIVITY:ACT_COMBINE_BUGBAIT"
    --  "		TASK_RANDOMIZE_FRAMERATE		20"
    --  "		TASK_WAIT						2"
    --  "		TASK_WAIT_RANDOM				3"
    --  "		TASK_COMBINE_DIE_INSTANTLY		DMG_BURN"
    --  "		TASK_WAIT						1.0"
    --  "	"
    --  "	Interrupts"
    --  )

    --  DEFINE_SCHEDULE
    --  (
    --  SCHED_COMBINE_FACE_IDEAL_YAW,

    --  "	Tasks"
    --  "		TASK_FACE_IDEAL				0"
    --  "	"
    --  "	Interrupts"
    --  )

    --  DEFINE_SCHEDULE
    --  (
    --  SCHED_COMBINE_MOVE_TO_MELEE,

    --  "	Tasks"
    --  "		TASK_STORE_ENEMY_POSITION_IN_SAVEPOSITION	0"
    --  "		TASK_GET_PATH_TO_SAVEPOSITION				0"
    --  "		TASK_RUN_PATH								0"
    --  "		TASK_WAIT_FOR_MOVEMENT						0"
    --   "	"
    --  "	Interrupts"
    --  "		COND_NEW_ENEMY"
    --  "		COND_ENEMY_DEAD"
    --  "		COND_CAN_MELEE_ATTACK1"
    --  )
}
M.COMBINE_SCHEDULE_ID_TO_NAME = makeReverseTable(M.COMBINE_SCHEDULE_ENUM)

M.NPC_STATE_ENUM              = {
    NPC_STATE_INVALID  = -1, -- Invalid state
    NPC_STATE_NONE     = 0,  -- NPC default state
    NPC_STATE_IDLE     = 1,  -- NPC is idle
    NPC_STATE_ALERT    = 2,  -- NPC is alert and searching for enemies
    NPC_STATE_COMBAT   = 3,  -- NPC is in combat
    NPC_STATE_SCRIPT   = 4,  -- NPC is executing scripted sequence
    NPC_STATE_PLAYDEAD = 5,  -- NPC is playing dead (used for expressions)
    NPC_STATE_PRONE    = 6,  -- NPC is prone to death
    NPC_STATE_DEAD     = 7,  -- NPC is dead
}
M.NPC_STATE_ID_TO_NAME        = makeReverseTable(M.NPC_STATE_ENUM)

return M
