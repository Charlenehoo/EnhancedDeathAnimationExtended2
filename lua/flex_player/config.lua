-- lua/edae/fp/config.lua
-- FlexPlayer 模型配置加载器
local config = {}

local modelConfigs = {
    kasumi = include("flex_player/config/kasumi.lua"),
    hitomi = include("flex_player/config/hitomi.lua"),
    lc_90  = include("flex_player/config/lc_90.lua"),
    -- zt_zdf = include("flex_player/config/zt_zdf.lua"),
    eve    = include("flex_player/config/eve.lua"),
}

function config.GetModelConfig(model)
    if model then
        if model:find("kasumi", 1, true) then
            return modelConfigs.kasumi
        elseif model:find("hitomi", 1, true) then
            return modelConfigs.hitomi
            -- elseif model:find("zt_zdf", 1, true) then
            --     return modelConfigs.zt_zdf
        elseif model:find("eve_pm", 1, true) or model:find("stellar_blade/eve", 1, true) then
            return modelConfigs.eve
        elseif model:find("lc_90", 1, true) then
            return modelConfigs.lc_90
        end
    end
    return modelConfigs.kasumi -- 默认模型
end

return config
