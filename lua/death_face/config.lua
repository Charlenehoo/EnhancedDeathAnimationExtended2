-- ./lua/death_face/config.lua
local config = {}

local modelConfigs = {
    kasumi = include("death_face/config/kasumi.lua"),
    hitomi = include("death_face/config/hitomi.lua"),
    lc_90  = include("death_face/config/lc_90.lua"), -- 新增加
    zt_zdf = include("death_face/config/zt_zdf.lua"),
    eve    = include("death_face/config/eve.lua"),  -- 新增
}

function config.GetModelConfig(model)
    if model then
        if model:find("kasumi", 1, true) then
            return modelConfigs.kasumi
        elseif model:find("hitomi", 1, true) then
            return modelConfigs.hitomi
        elseif model:find("zt_zdf", 1, true) then
            return modelConfigs.zt_zdf
        elseif model:find("eve_pm", 1, true) or model:find("stellar_blade/eve", 1, true) then
            return modelConfigs.eve              -- 新增
        elseif model:find("lc_90", 1, true) then -- 新增加
            return modelConfigs.lc_90
        end
    end
    return modelConfigs.kasumi
end

return config
