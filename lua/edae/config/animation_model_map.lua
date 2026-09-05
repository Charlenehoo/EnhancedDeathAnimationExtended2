-- lua/edae/config/animation_model_map.lua
local M = {}

-- ================================================
-- 正向表：模型路径 -> {动画名1, 动画名2, ...}
-- 这是供人类编辑的配置部分
-- ================================================
M.MODEL_TO_ANIMS = {
    -- HL2 警察模型（包含溺水、燃烧、挥舞等动画）
    ["models/Police.mdl"] = {
        "Choked_Barnacle",
        "idleonfire",
        "moveonfire",
    },

    -- HL2 男性市民模型 07（包含蜷缩、倒地、行走等动画）
    ["models/Humans/Group03/male_07.mdl"] = {
        "cower_Idle",
        "cower_idle",
        "deathpose_back",
        "deathpose_right",
        "deathpose_front",
        "deathpose_left",
        "walk_all",
        "sprint_all",
    },

    -- HL2 男性市民模型 04（包含紧张、站立等动画）
    ["models/Humans/Group01/Male_04.mdl"] = {
        "plazaidle2",
    },

    -- EDAE 默认自定义模型（包含大量 CS/COD 死亡动画）
    ["models/brutal_deaths/model_anim_modify.mdl"] = {
        -- 这里无需显式列出，作为默认回退
    },
}

-- ================================================
-- 运行时反向表：动画名 -> 模型路径（由代码自动生成）
-- 这是供程序查询的部分
-- ================================================
M.ANIM_TO_MODEL = {}

-- 构建反向表（在文件加载时自动执行）
for modelPath, animList in pairs(M.MODEL_TO_ANIMS) do
    for _, animName in ipairs(animList) do
        -- 防止重复动画名覆盖（先定义先保留）
        if not M.ANIM_TO_MODEL[animName] then
            M.ANIM_TO_MODEL[animName] = modelPath
        end
    end
end

-- 默认回退模型（当动画名在反向表中找不到时使用）
M.DEFAULT_MODEL = "models/brutal_deaths/model_anim_modify.mdl"

return M
