-- lua/edae/data/stiff_connections.lua
-- 僵直叠加层（StiffOverlay）使用的骨骼关节表。
-- 每一对描述一个关节：child 是子骨骼，parent 是父骨骼。
-- 约束会以 parent 的世界坐标为关节位置，限制 child 相对 parent 的摆动范围。
--
-- 命名约定：使用 ValveBiped 标准骨骼名。若模型缺骨骼，StiffOverlay
-- 会自动跳过对应关节（收集阶段过滤），不会崩溃。

return {
    -- 躯干链（从骨盆向上）
    { child = "ValveBiped.Bip01_Spine",      parent = "ValveBiped.Bip01_Pelvis" },
    { child = "ValveBiped.Bip01_Spine1",     parent = "ValveBiped.Bip01_Spine" },
    { child = "ValveBiped.Bip01_Spine2",     parent = "ValveBiped.Bip01_Spine1" },
    { child = "ValveBiped.Bip01_Spine4",     parent = "ValveBiped.Bip01_Spine2" },

    -- 头颈
    { child = "ValveBiped.Bip01_Neck1",      parent = "ValveBiped.Bip01_Spine4" },
    { child = "ValveBiped.Bip01_Head1",      parent = "ValveBiped.Bip01_Neck1" },

    -- 左臂链
    { child = "ValveBiped.Bip01_L_UpperArm", parent = "ValveBiped.Bip01_L_Clavicle" },
    { child = "ValveBiped.Bip01_L_Forearm",  parent = "ValveBiped.Bip01_L_UpperArm" },
    { child = "ValveBiped.Bip01_L_Hand",     parent = "ValveBiped.Bip01_L_Forearm" },

    -- 右臂链
    { child = "ValveBiped.Bip01_R_UpperArm", parent = "ValveBiped.Bip01_R_Clavicle" },
    { child = "ValveBiped.Bip01_R_Forearm",  parent = "ValveBiped.Bip01_R_UpperArm" },
    { child = "ValveBiped.Bip01_R_Hand",     parent = "ValveBiped.Bip01_R_Forearm" },

    -- 左腿链
    { child = "ValveBiped.Bip01_L_Thigh",    parent = "ValveBiped.Bip01_Pelvis" },
    { child = "ValveBiped.Bip01_L_Calf",     parent = "ValveBiped.Bip01_L_Thigh" },
    { child = "ValveBiped.Bip01_L_Foot",     parent = "ValveBiped.Bip01_L_Calf" },

    -- 右腿链
    { child = "ValveBiped.Bip01_R_Thigh",    parent = "ValveBiped.Bip01_Pelvis" },
    { child = "ValveBiped.Bip01_R_Calf",     parent = "ValveBiped.Bip01_R_Thigh" },
    { child = "ValveBiped.Bip01_R_Foot",     parent = "ValveBiped.Bip01_R_Calf" },
}
