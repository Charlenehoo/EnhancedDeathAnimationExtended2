-- npc_monitor_init.lua
-- 服务器端自动运行入口：加载 npc_monitor 库

if SERVER then
    include("npc_monitor/init.lua")
end
