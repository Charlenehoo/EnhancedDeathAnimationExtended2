-- ./lua/edae/config/drop_item_constants.lua
-- DropItem 子系统常量（迁移自 includes/config/constants.lua，移除 BEFORE 阶段）

local DropItemConstants = {}

DropItemConstants.BONES = {
    HEAD       = "ValveBiped.Bip01_Head1",
    LEFT_CALF  = "ValveBiped.Bip01_L_Calf",
    RIGHT_CALF = "ValveBiped.Bip01_R_Calf",
    LEFT_FOOT  = "ValveBiped.Bip01_L_Foot",
    RIGHT_FOOT = "ValveBiped.Bip01_R_Foot",
    PELVIS     = "ValveBiped.Bip01_Pelvis",
}

DropItemConstants.PHASES = {
    DURING = "DuringCreateEntityRagdoll",
    AFTER  = "AfterCreateEntityRagdoll",
}

DropItemConstants.CONDITIONS = {
    RANDOM              = 1,
    IS_MOVING           = 2,
    IS_HITGROUP         = 4,
    IS_BULLET_NEAR_BONE = 8,
}

return DropItemConstants
