-- lua/edae/as/bone_whitelists.lua
-- 骨骼白名单数据：按语义化结构组织，供动画/抽搐组装器使用
-- 所有白名单的值均为 true 或数字（数字用于肢解分组）

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

-- ============================================================
-- 肢解分组白名单（值表示所属分组，用于 Gib 相关逻辑）
-- ============================================================
local gib = {}
do
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
        gib[PREFIX .. short] = group
    end
end

-- ============================================================
-- 受伤有效性白名单（全部骨骼，值 true）
-- ============================================================
local hitbox = makeBoneSet(FULL_BODY, true)

-- ============================================================
-- 标准控制集（值 true）
-- ============================================================
local normal = makeBoneSet(STANDARD_CONTROL, true)

-- ============================================================
-- 死亡动画控制白名单（三个强度等级）
-- level: full（全量）, moderate（中等）, minimal（最小）
-- ============================================================
local death = {}

-- full：使用标准控制集
death.full = makeBoneSet(STANDARD_CONTROL, true)

-- moderate：在标准控制集基础上移除部分骨骼
do
    local exclude = {
        BONE_SHORT.Spine1,
        BONE_SHORT.R_Foot,
        BONE_SHORT.L_Foot,
        BONE_SHORT.R_Clavicle,
        BONE_SHORT.R_UpperArm,
        BONE_SHORT.L_Clavicle,
        BONE_SHORT.L_UpperArm,
    }
    death.moderate = makeBoneSet(STANDARD_CONTROL, true)
    for _, short in ipairs(exclude) do
        death.moderate[PREFIX .. short] = nil
    end
end

-- minimal：进一步减少
do
    local exclude = {
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
    death.minimal = makeBoneSet(STANDARD_CONTROL, true)
    for _, short in ipairs(exclude) do
        death.minimal[PREFIX .. short] = nil
    end
end

-- ============================================================
-- 爬行动画控制白名单
-- face_up：面朝上
-- face_down：面朝下，包含两组变体（group_a 对应原 MoveTb_2 系列，group_b 对应原 MoveTb_3 系列）
-- ============================================================
local crawl = {}

-- 面朝上（使用与挣扎相同的控制集）
crawl.face_up = makeBoneSet({
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

-- 面朝下：group_a（原 MoveTb_2，6 个变体）
crawl.face_down = {
    group_a = {},
    group_b = {},
}

-- 生成 group_a 的 6 个变体
do
    local variants = {
        { -- variant 1
            BONE_SHORT.R_Thigh, BONE_SHORT.R_Calf, BONE_SHORT.R_Foot,
            BONE_SHORT.L_Thigh, BONE_SHORT.L_Calf, BONE_SHORT.L_Foot,
            BONE_SHORT.R_Forearm, BONE_SHORT.R_Hand,
            BONE_SHORT.L_Forearm, BONE_SHORT.L_Hand,
            BONE_SHORT.Head1,
        },
        { -- variant 2
            BONE_SHORT.R_Clavicle, BONE_SHORT.R_UpperArm, BONE_SHORT.R_Forearm, BONE_SHORT.R_Hand,
            BONE_SHORT.L_Clavicle, BONE_SHORT.L_UpperArm, BONE_SHORT.L_Forearm, BONE_SHORT.L_Hand,
            BONE_SHORT.Head1,
        },
        { -- variant 3
            BONE_SHORT.L_Thigh, BONE_SHORT.L_Calf, BONE_SHORT.L_Foot,
            BONE_SHORT.R_Clavicle, BONE_SHORT.R_Forearm, BONE_SHORT.R_Hand,
            BONE_SHORT.L_Clavicle, BONE_SHORT.L_Forearm, BONE_SHORT.L_Hand,
            BONE_SHORT.Head1,
        },
        { -- variant 4
            BONE_SHORT.R_Thigh, BONE_SHORT.R_Calf, BONE_SHORT.R_Foot,
            BONE_SHORT.R_Clavicle, BONE_SHORT.R_Forearm, BONE_SHORT.R_Hand,
            BONE_SHORT.L_Clavicle, BONE_SHORT.L_Forearm, BONE_SHORT.L_Hand,
            BONE_SHORT.Head1,
        },
        { -- variant 5
            BONE_SHORT.R_Thigh, BONE_SHORT.R_Calf, BONE_SHORT.R_Foot,
            BONE_SHORT.L_Clavicle, BONE_SHORT.L_UpperArm, BONE_SHORT.L_Forearm, BONE_SHORT.L_Hand,
            BONE_SHORT.Head1,
        },
        { -- variant 6
            BONE_SHORT.L_Thigh, BONE_SHORT.L_Calf, BONE_SHORT.L_Foot,
            BONE_SHORT.R_Clavicle, BONE_SHORT.R_UpperArm, BONE_SHORT.R_Forearm, BONE_SHORT.R_Hand,
            BONE_SHORT.Head1,
        },
    }
    for i, v in ipairs(variants) do
        crawl.face_down.group_a[i] = makeBoneSet(v, true)
    end
end

-- 生成 group_b 的 3 个变体（原 MoveTb_3 系列）
do
    local variants = {
        { -- variant 1
            BONE_SHORT.Spine4,
            BONE_SHORT.R_Forearm, BONE_SHORT.R_Hand,
            BONE_SHORT.L_Forearm, BONE_SHORT.L_Hand,
            BONE_SHORT.Head1,
        },
        { -- variant 2
            BONE_SHORT.Spine4,
            BONE_SHORT.L_Forearm, BONE_SHORT.L_Hand,
            BONE_SHORT.Head1,
        },
        { -- variant 3
            BONE_SHORT.Spine4,
            BONE_SHORT.R_Forearm, BONE_SHORT.R_Hand,
            BONE_SHORT.Head1,
        },
    }
    for i, v in ipairs(variants) do
        crawl.face_down.group_b[i] = makeBoneSet(v, true)
    end
end

-- ============================================================
-- 挣扎动画控制白名单（与爬行面朝上相同）
-- ============================================================
local writhe                                     = makeBoneSet({
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

-- ============================================================
-- 抽搐控制白名单
-- ============================================================
local twitch                                     = makeBoneSet({
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

-- ============================================================
-- 玩家相机模式下的爬行白名单（基于标准控制集，移除 Head1 和 Spine4）
-- ============================================================
local player_camera_crawl                        = makeBoneSet(STANDARD_CONTROL, true)
player_camera_crawl[PREFIX .. BONE_SHORT.Head1]  = nil
player_camera_crawl[PREFIX .. BONE_SHORT.Spine4] = nil

-- ============================================================
-- 组装最终输出
-- ============================================================
BoneWhitelists.gib                               = gib
BoneWhitelists.hitbox                            = hitbox
BoneWhitelists.normal                            = normal
BoneWhitelists.death                             = death
BoneWhitelists.crawl                             = crawl
BoneWhitelists.writhe                            = writhe
BoneWhitelists.twitch                            = twitch
BoneWhitelists.player_camera_crawl               = player_camera_crawl

return BoneWhitelists
