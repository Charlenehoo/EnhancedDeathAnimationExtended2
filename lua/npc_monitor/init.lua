-- npc_monitor/init.lua
-- 库统一入口：负责加载需要主动启动的模块

NPCMonitor = NPCMonitor or {}
if NPCMonitor._loaded then return end
NPCMonitor._loaded = true

include("npc_monitor/core/init.lua")
include("npc_monitor/schedule/init.lua")
include("npc_monitor/enhance/init.lua")
