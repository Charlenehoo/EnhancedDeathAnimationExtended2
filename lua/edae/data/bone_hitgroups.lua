-- lua/edae/data/bone_hitgroups.lua
-- 骨骼名 → HITGROUP_* 的映射表。
-- 供 RagdollDamageProcessor 在布娃娃受伤时，根据最近骨骼名推导 hitGroup，
-- 从而使 PostRagdollTakeDamage 事件能够携带与原生引擎一致的 hitGroup 语义。
--
-- 说明：
--   * 基于 ValveBiped 标准骨骼命名。非标准模型可能无法命中，调用方需容忍 nil。
--   * 未列出的骨骼（手指、脚趾、装饰骨骼等）返回 nil。
--   * 扩展方式：直接在本表添加条目，无需修改任何逻辑代码。
--
-- 语义划分：
--   - 头部 / 颈部            → HITGROUP_HEAD
--   - Spine4 / Spine3 / Spine2 → HITGROUP_CHEST
--   - Spine1 / Spine / Pelvis  → HITGROUP_STOMACH
--   - L_* 上肢               → HITGROUP_LEFTARM
--   - R_* 上肢               → HITGROUP_RIGHTARM
--   - L_* 下肢               → HITGROUP_LEFTLEG
--   - R_* 下肢               → HITGROUP_RIGHTLEG

return {
    -- 头部 / 颈部
    ["ValveBiped.Bip01_Head1"]      = HITGROUP_HEAD,
    ["ValveBiped.Bip01_Neck1"]      = HITGROUP_HEAD,

    -- 躯干
    ["ValveBiped.Bip01_Spine4"]     = HITGROUP_CHEST,
    ["ValveBiped.Bip01_Spine3"]     = HITGROUP_CHEST,
    ["ValveBiped.Bip01_Spine2"]     = HITGROUP_CHEST,
    ["ValveBiped.Bip01_Spine1"]     = HITGROUP_STOMACH,
    ["ValveBiped.Bip01_Spine"]      = HITGROUP_STOMACH,
    ["ValveBiped.Bip01_Pelvis"]     = HITGROUP_STOMACH,

    -- 左臂
    ["ValveBiped.Bip01_L_Clavicle"] = HITGROUP_LEFTARM,
    ["ValveBiped.Bip01_L_UpperArm"] = HITGROUP_LEFTARM,
    ["ValveBiped.Bip01_L_Forearm"]  = HITGROUP_LEFTARM,
    ["ValveBiped.Bip01_L_Hand"]     = HITGROUP_LEFTARM,

    -- 右臂
    ["ValveBiped.Bip01_R_Clavicle"] = HITGROUP_RIGHTARM,
    ["ValveBiped.Bip01_R_UpperArm"] = HITGROUP_RIGHTARM,
    ["ValveBiped.Bip01_R_Forearm"]  = HITGROUP_RIGHTARM,
    ["ValveBiped.Bip01_R_Hand"]     = HITGROUP_RIGHTARM,

    -- 左腿
    ["ValveBiped.Bip01_L_Thigh"]    = HITGROUP_LEFTLEG,
    ["ValveBiped.Bip01_L_Calf"]     = HITGROUP_LEFTLEG,
    ["ValveBiped.Bip01_L_Foot"]     = HITGROUP_LEFTLEG,

    -- 右腿
    ["ValveBiped.Bip01_R_Thigh"]    = HITGROUP_RIGHTLEG,
    ["ValveBiped.Bip01_R_Calf"]     = HITGROUP_RIGHTLEG,
    ["ValveBiped.Bip01_R_Foot"]     = HITGROUP_RIGHTLEG,
}
