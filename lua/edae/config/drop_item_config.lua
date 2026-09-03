-- ./lua/edae/config/drop_item_config.lua
-- DropItem 模型配置聚合（迁移自 includes/config.lua）

local constants           = include("edae/config/drop_item_constants.lua")

local LSY_ZDF             = include("edae/config/drop_item/LSY_ZDF.lua")
local LSY_JSF             = include("edae/config/drop_item/LSY_JSF.lua")
local ZT_ZDF              = include("edae/config/drop_item/ZT_ZDF.lua")
local ZT_JSF              = include("edae/config/drop_item/ZT_JSF.lua")
local ZTQ_ZDF             = include("edae/config/drop_item/ZTQ_ZDF.lua")
local ZTQ_JSF             = include("edae/config/drop_item/ZTQ_JSF.lua")

local MODEL_TO_CONFIG_MAP = {
    ["models/lc_90/lsy_zdf_pm.mdl"] = LSY_ZDF,
    ["models/lc_90e/lsy_zdf_e.mdl"] = LSY_ZDF,
    ["models/lc_90f/lsy_zdf_f.mdl"] = LSY_ZDF,

    ["models/lc_90/lsy_jsf_pm.mdl"] = LSY_JSF,
    ["models/lc_90e/lsy_jsf_e.mdl"] = LSY_JSF,
    ["models/lc_90f/lsy_jsf_f.mdl"] = LSY_JSF,

    ["models/lc_90/zt_zdf_pm.mdl"]  = ZT_ZDF,
    ["models/lc_90e/zt_zdf_e.mdl"]  = ZT_ZDF,
    ["models/lc_90f/zt_zdf_f.mdl"]  = ZT_ZDF,

    ["models/lc_90/zt_jsf_pm.mdl"]  = ZT_JSF,
    ["models/lc_90e/zt_jsf_e.mdl"]  = ZT_JSF,
    ["models/lc_90f/zt_jsf_f.mdl"]  = ZT_JSF,

    ["models/lc_90/ztq_zdf_pm.mdl"] = ZTQ_ZDF,
    ["models/lc_90e/ztq_zdf_e.mdl"] = ZTQ_ZDF,
    ["models/lc_90f/ztq_zdf_f.mdl"] = ZTQ_ZDF,

    ["models/lc_90/ztq_jsf_pm.mdl"] = ZTQ_JSF,
    ["models/lc_90e/ztq_jsf_e.mdl"] = ZTQ_JSF,
    ["models/lc_90f/ztq_jsf_f.mdl"] = ZTQ_JSF,
}

return {
    PHASES              = constants.PHASES,
    CONDITIONS          = constants.CONDITIONS,
    MODEL_TO_CONFIG_MAP = MODEL_TO_CONFIG_MAP,
}
