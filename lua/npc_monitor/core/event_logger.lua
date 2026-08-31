-- npc_monitor/core/event_logger.lua
-- 订阅核心事件并输出日志，保持事件总线与日志逻辑解耦

local Events          = include("npc_monitor/core/events.lua")
local log             = include("npc_monitor/logging/log.lua")
local helpers         = include("npc_monitor/helpers.lua")
local addUniqueHook   = helpers.addUniqueHook

local getScheduleName = helpers.getScheduleName
local getStateName    = helpers.getStateName

local function shouldLog(npc)
    if not IsValid(npc) then return false end
    if npc:GetClass() == "cdg_info_target" then return false end
    return true
end

-- 订阅 schedule 变化事件
-- addUniqueHook(Events.TranslateSchedule, function(npc, last, current)
--     if shouldLog(npc) then
--         log.trace(npc, "TranslateSchedule: ", getScheduleName(last, npc), " -> ", getScheduleName(current, npc))
--     end
-- end)

-- 订阅 state 变化事件
-- addUniqueHook(Events.OnStateChange, function(npc, last, current)
--     if shouldLog(npc) then
--         log.info(npc, "StateChange: ", getStateName(last), " -> ", getStateName(current))
--     end
-- end)

-- 订阅 enemy 变化事件
-- addUniqueHook(Events.OnEnemyChange, function(npc, last, current)
--     if shouldLog(npc) then
--         last = last or "No Enemy"
--         current = current or "No Enemy"
--         log.info(npc, "EnemyChange: ", tostring(last), " -> ", tostring(current))
--     end
-- end)

-- 如果启用条件变化检测，可在此订阅 Events.OnCondition
-- hook.Add(Events.OnCondition, "NPCMonitor.EventLogger.OnCondition",
--     function(npc, conditionName, conditionID, lastValue, currentValue)
--         if not shouldLog(npc) then return end
--         local status = currentValue and "SET" or "CLEAR"
--         log.trace(npc, "ConditionChange: ", conditionName, " [", status, "]")
--     end)
