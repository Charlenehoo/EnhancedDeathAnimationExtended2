-- lua/edae/data/shadow_params.lua
-- 从旧版 AnimRag 提取的 Shadow 控制参数模板
-- 普通版：对应 Animrag_CSC（用于死亡、爬行等常规动画）
-- 挣扎版：对应 WritheCSC 系列（用于挣扎动画，力度更柔和，只映射角度等）

local ShadowParams = {}

ShadowParams.Default = {
    teleportdistance = 0,
    secondstoarrive = 0.01,
    delta = nil,
    dampfactor = nil,
    maxangular = 400,
    maxangulardamp = 200,
    maxspeed = 400,
    maxspeeddamp = 300,
    pos = vector_origin,
    angle = angle_zero,
}

ShadowParams.Writhe = {}

ShadowParams.Writhe.Base = {
    teleportdistance = 0,
    secondstoarrive = 0.1,
    delta = nil,
    dampfactor = nil,
    maxangular = 300,
    maxangulardamp = 200,
    maxspeed = 0,
    maxspeeddamp = 200,
    pos = vector_origin,
    angle = angle_zero,
}

-- Normal：完全使用 Base 的值
ShadowParams.Writhe.Normal = table.Copy(ShadowParams.Writhe.Base)

-- Fierce：只修改 maxangulardamp
ShadowParams.Writhe.Fierce = table.Copy(ShadowParams.Writhe.Base)
ShadowParams.Writhe.Fierce.maxangulardamp = 20

-- Slow：只修改 secondstoarrive
ShadowParams.Writhe.Slow = table.Copy(ShadowParams.Writhe.Base)
ShadowParams.Writhe.Slow.secondstoarrive = 0.5

return ShadowParams
