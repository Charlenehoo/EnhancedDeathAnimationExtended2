--[[
    骨骼白名单生成模块
    集中管理所有骨骼名称，按需生成各类白名单表，避免重复定义。
--]]

local BoneWhitelists = {}

local PREFIX = "ValveBiped.Bip01_"

-- 骨骼短名称（只写一次）
local BONE_SHORT = {
    Pelvis     = "Pelvis",
    Spine      = "Spine",
    Spine1     = "Spine1",
    Spine2     = "Spine2",
    Spine3     = "Spine3",
    Spine4     = "Spine4",
    R_Thigh    = "R_Thigh",
    R_Calf     = "R_Calf",
    R_Foot     = "R_Foot",
    L_Thigh    = "L_Thigh",
    L_Calf     = "L_Calf",
    L_Foot     = "L_Foot",
    R_Clavicle = "R_Clavicle",
    R_UpperArm = "R_UpperArm",
    R_Forearm  = "R_Forearm",
    R_Hand     = "R_Hand",
    L_Clavicle = "L_Clavicle",
    L_UpperArm = "L_UpperArm",
    L_Forearm  = "L_Forearm",
    L_Hand     = "L_Hand",
    Head1      = "Head1",
}

-- 完整人体骨骼集合（包含所有脊柱）
local FULL_BODY = {
    BONE_SHORT.Pelvis,
    BONE_SHORT.Spine,
    BONE_SHORT.Spine1,
    BONE_SHORT.Spine2,
    BONE_SHORT.Spine3,
    BONE_SHORT.Spine4,
    BONE_SHORT.R_Thigh,
    BONE_SHORT.R_Calf,
    BONE_SHORT.R_Foot,
    BONE_SHORT.L_Thigh,
    BONE_SHORT.L_Calf,
    BONE_SHORT.L_Foot,
    BONE_SHORT.R_Clavicle,
    BONE_SHORT.R_UpperArm,
    BONE_SHORT.R_Forearm,
    BONE_SHORT.R_Hand,
    BONE_SHORT.L_Clavicle,
    BONE_SHORT.L_UpperArm,
    BONE_SHORT.L_Forearm,
    BONE_SHORT.L_Hand,
    BONE_SHORT.Head1,
}

-- 标准控制集（不含 Spine, Spine2, Spine3）
local STANDARD_CONTROL = {
    BONE_SHORT.Pelvis,
    BONE_SHORT.Spine1,
    BONE_SHORT.Spine4,
    BONE_SHORT.R_Thigh,
    BONE_SHORT.R_Calf,
    BONE_SHORT.R_Foot,
    BONE_SHORT.L_Thigh,
    BONE_SHORT.L_Calf,
    BONE_SHORT.L_Foot,
    BONE_SHORT.R_Clavicle,
    BONE_SHORT.R_UpperArm,
    BONE_SHORT.R_Forearm,
    BONE_SHORT.R_Hand,
    BONE_SHORT.L_Clavicle,
    BONE_SHORT.L_UpperArm,
    BONE_SHORT.L_Forearm,
    BONE_SHORT.L_Hand,
    BONE_SHORT.Head1,
}

-- 辅助函数：将短名称列表转为完整骨骼名表，值为 true 或自定义值
local function makeBoneSet(shortNames, value)
    local t = {}
    for _, short in ipairs(shortNames) do
        t[PREFIX .. short] = value or true
    end
    return t
end

-- 生成 Animrag_Gib_Tb（肢解分组白名单）
local function GenerateGibTb()
    local t = {}
    local groupAssignments = {
        [BONE_SHORT.Pelvis]     = 1,
        [BONE_SHORT.Spine1]     = 1,
        [BONE_SHORT.Spine4]     = 1,
        [BONE_SHORT.Head1]      = 1,
        [BONE_SHORT.R_Thigh]    = 2.1,
        [BONE_SHORT.R_Calf]     = 2.1,
        [BONE_SHORT.R_Foot]     = 2.1,
        [BONE_SHORT.L_Thigh]    = 2.2,
        [BONE_SHORT.L_Calf]     = 2.2,
        [BONE_SHORT.L_Foot]     = 2.2,
        [BONE_SHORT.R_Clavicle] = 2.3,
        [BONE_SHORT.R_UpperArm] = 2.3,
        [BONE_SHORT.R_Forearm]  = 2.3,
        [BONE_SHORT.R_Hand]     = 2.3,
        [BONE_SHORT.L_Clavicle] = 2.4,
        [BONE_SHORT.L_UpperArm] = 2.4,
        [BONE_SHORT.L_Forearm]  = 2.4,
        [BONE_SHORT.L_Hand]     = 2.4,
    }
    for short, group in pairs(groupAssignments) do
        t[PREFIX .. short] = group
    end
    return t
end

-- 生成 Hitbox_Tb（受伤骨骼有效性白名单）
local function GenerateHitboxTb()
    return makeBoneSet(FULL_BODY, true)
end

-- 生成 NrmTb（完整标准控制集）
local function GenerateNrmTb()
    return makeBoneSet(STANDARD_CONTROL, true)
end

-- 生成 MoveTb_D 系列（死亡动画控制骨骼集合，返回数组 {MoveTb_1, MoveTb_2, MoveTb_3}）
local function GenerateMoveTbD()
    -- MoveTb_1：全量控制
    local MoveTb_1 = makeBoneSet(STANDARD_CONTROL, true)

    -- MoveTb_2：减少部分控制
    local exclude_2 = {
        BONE_SHORT.Spine1,
        BONE_SHORT.R_Foot,
        BONE_SHORT.L_Foot,
        BONE_SHORT.R_Clavicle,
        BONE_SHORT.R_UpperArm,
        BONE_SHORT.L_Clavicle,
        BONE_SHORT.L_UpperArm,
    }
    local MoveTb_2 = makeBoneSet(STANDARD_CONTROL, true)
    for _, short in ipairs(exclude_2) do
        MoveTb_2[PREFIX .. short] = nil
    end

    -- MoveTb_3：进一步减少
    local exclude_3 = {
        BONE_SHORT.Pelvis,
        BONE_SHORT.Spine1,
        BONE_SHORT.R_Thigh,
        BONE_SHORT.R_Calf,
        BONE_SHORT.L_Thigh,
        BONE_SHORT.L_Calf,
        BONE_SHORT.R_Forearm,
        BONE_SHORT.R_Hand,
        BONE_SHORT.L_Forearm,
        BONE_SHORT.L_Hand,
    }
    local MoveTb_3 = makeBoneSet(STANDARD_CONTROL, true)
    for _, short in ipairs(exclude_3) do
        MoveTb_3[PREFIX .. short] = nil
    end

    return { MoveTb_1, MoveTb_2, MoveTb_3 }
end

-- 生成 MoveTb_C 系列（爬行/挣扎动画控制骨骼集合）
local function GenerateMoveTbC()
    -- 面朝上使用的 MoveTb_1
    local MoveTb_1 = makeBoneSet({
        BONE_SHORT.Pelvis,
        BONE_SHORT.Spine4,
        BONE_SHORT.R_Calf,
        BONE_SHORT.L_Calf,
        BONE_SHORT.R_Forearm,
        BONE_SHORT.R_Hand,
        BONE_SHORT.L_Forearm,
        BONE_SHORT.L_Hand,
        BONE_SHORT.Head1,
    }, true)

    -- 面朝下使用的 MoveTb_2 系列（6个子表）
    local MoveTb_2_1 = makeBoneSet({
        BONE_SHORT.R_Thigh, BONE_SHORT.R_Calf, BONE_SHORT.R_Foot,
        BONE_SHORT.L_Thigh, BONE_SHORT.L_Calf, BONE_SHORT.L_Foot,
        BONE_SHORT.R_Forearm, BONE_SHORT.R_Hand,
        BONE_SHORT.L_Forearm, BONE_SHORT.L_Hand,
        BONE_SHORT.Head1,
    }, true)
    local MoveTb_2_2 = makeBoneSet({
        BONE_SHORT.R_Clavicle, BONE_SHORT.R_UpperArm, BONE_SHORT.R_Forearm, BONE_SHORT.R_Hand,
        BONE_SHORT.L_Clavicle, BONE_SHORT.L_UpperArm, BONE_SHORT.L_Forearm, BONE_SHORT.L_Hand,
        BONE_SHORT.Head1,
    }, true)
    local MoveTb_2_3 = makeBoneSet({
        BONE_SHORT.L_Thigh, BONE_SHORT.L_Calf, BONE_SHORT.L_Foot,
        BONE_SHORT.R_Clavicle, BONE_SHORT.R_Forearm, BONE_SHORT.R_Hand,
        BONE_SHORT.L_Clavicle, BONE_SHORT.L_Forearm, BONE_SHORT.L_Hand,
        BONE_SHORT.Head1,
    }, true)
    local MoveTb_2_4 = makeBoneSet({
        BONE_SHORT.R_Thigh, BONE_SHORT.R_Calf, BONE_SHORT.R_Foot,
        BONE_SHORT.R_Clavicle, BONE_SHORT.R_Forearm, BONE_SHORT.R_Hand,
        BONE_SHORT.L_Clavicle, BONE_SHORT.L_Forearm, BONE_SHORT.L_Hand,
        BONE_SHORT.Head1,
    }, true)
    local MoveTb_2_5 = makeBoneSet({
        BONE_SHORT.R_Thigh, BONE_SHORT.R_Calf, BONE_SHORT.R_Foot,
        BONE_SHORT.L_Clavicle, BONE_SHORT.L_UpperArm, BONE_SHORT.L_Forearm, BONE_SHORT.L_Hand,
        BONE_SHORT.Head1,
    }, true)
    local MoveTb_2_6 = makeBoneSet({
        BONE_SHORT.L_Thigh, BONE_SHORT.L_Calf, BONE_SHORT.L_Foot,
        BONE_SHORT.R_Clavicle, BONE_SHORT.R_UpperArm, BONE_SHORT.R_Forearm, BONE_SHORT.R_Hand,
        BONE_SHORT.Head1,
    }, true)
    local MoveTb_2 = { MoveTb_2_1, MoveTb_2_2, MoveTb_2_3, MoveTb_2_4, MoveTb_2_5, MoveTb_2_6 }

    -- 面朝下使用的 MoveTb_3 系列（3个子表）
    local MoveTb_3_1 = makeBoneSet({
        BONE_SHORT.Spine4,
        BONE_SHORT.R_Forearm, BONE_SHORT.R_Hand,
        BONE_SHORT.L_Forearm, BONE_SHORT.L_Hand,
        BONE_SHORT.Head1,
    }, true)
    local MoveTb_3_2 = makeBoneSet({
        BONE_SHORT.Spine4,
        BONE_SHORT.L_Forearm, BONE_SHORT.L_Hand,
        BONE_SHORT.Head1,
    }, true)
    local MoveTb_3_3 = makeBoneSet({
        BONE_SHORT.Spine4,
        BONE_SHORT.R_Forearm, BONE_SHORT.R_Hand,
        BONE_SHORT.Head1,
    }, true)
    local MoveTb_3 = { MoveTb_3_1, MoveTb_3_2, MoveTb_3_3 }

    return {
        MoveTb_1 = MoveTb_1,
        MoveTb_2 = MoveTb_2,
        MoveTb_3 = MoveTb_3,
    }
end

-- 生成抽搐用骨骼白名单
local function GenerateTwitchTb()
    return makeBoneSet({
        BONE_SHORT.Pelvis,
        BONE_SHORT.Spine,
        BONE_SHORT.Spine1,
        BONE_SHORT.Spine2,
        BONE_SHORT.Spine3,
        BONE_SHORT.Spine4,
        BONE_SHORT.R_Thigh,
        BONE_SHORT.L_Thigh,
        BONE_SHORT.R_Clavicle,
        BONE_SHORT.R_UpperArm,
        BONE_SHORT.L_Clavicle,
        BONE_SHORT.L_UpperArm,
    }, true)
end

-- 添加到返回表
BoneWhitelists.TwitchTb = GenerateTwitchTb()

-- 生成所有白名单并缓存
BoneWhitelists.GibTb    = GenerateGibTb()
BoneWhitelists.HitboxTb = GenerateHitboxTb()
BoneWhitelists.NrmTb    = GenerateNrmTb()
BoneWhitelists.MoveTbD  = GenerateMoveTbD() -- 数组：[1]=MoveTb_1, [2]=MoveTb_2, [3]=MoveTb_3
BoneWhitelists.MoveTbC  = GenerateMoveTbC() -- 表：{ MoveTb_1, MoveTb_2(数组), MoveTb_3(数组) }
BoneWhitelists.TwitchTb = GenerateTwitchTb()

return BoneWhitelists
