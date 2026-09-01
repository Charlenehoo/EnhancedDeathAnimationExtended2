-- npc_monitor/schedule/selector.lua
-- 根据 NPC 类型选择合适的 schedule

local CONSTANTS = include("npc_monitor/config/constants.lua")

local function selectSchedule(npc, lastSchedule, currentSchedule)
    if lastSchedule == SCHED_FAIL or currentSchedule == SCHED_FAIL then return nil end

    local enemy = npc:GetEnemy()
    if IsValid(enemy) and enemy:GetClass() == CONSTANTS.RAGADOLL_DUMMY_CLASS then return nil end

    if currentSchedule == SCHED_IDLE_STAND or
        currentSchedule == SCHED_ALERT_STAND or
        currentSchedule == SCHED_ALERT_FACE_BESTSOUND then
        local candidates = {}
        NPCMonitor.ForEachActiveDummy(function(dummy)
            if IsValid(dummy) and dummy:IsPotentialExecutioner(npc) then
                table.insert(candidates, dummy)
            end
        end)
        if #candidates > 0 then
            local dummyOfChoice = candidates[math.random(#candidates)]
            npc:SetTarget(dummyOfChoice)
            return SCHED_TARGET_CHASE
        end
    end

    return nil
end

return selectSchedule
