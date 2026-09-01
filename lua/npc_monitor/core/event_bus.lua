-- npc_monitor/core/event_bus.lua
-- 核心事件总线：维护活跃 NPC/Dummy 集合，轮询状态变化并发布事件


local CONSTANTS         = include("npc_monitor/config/constants.lua")
local EDAEConstants     = include("edae/config/constants.lua")
local Events            = include("npc_monitor/core/events.lua")
local log               = include("npc_monitor/logging/log.lua")
local helpers           = include("npc_monitor/helpers.lua")
local addUniqueHook     = helpers.addUniqueHook

-- 活跃实体集合（弱键，实体消失后自动清理）
local activeNPCS        = setmetatable({}, { __mode = "k" })
local activeDummies     = setmetatable({}, { __mode = "k" })

-- 上次状态缓存（弱键，随实体一起回收）
local lastSchedules     = setmetatable({}, { __mode = "k" }) -- { npc -> schedule }
local lastStates        = setmetatable({}, { __mode = "k" }) -- { npc -> state }
local lastEnemies       = setmetatable({}, { __mode = "k" }) -- { npc -> enemy }

-- 条件变化缓存（可选功能，默认不启用）
local allLastConditions = {} -- { condition -> { npc -> has } }
for name, id in pairs(COND) do
    allLastConditions[name] = setmetatable({}, { __mode = "k" })
end

-- 内部：增强 NPC 的感知能力等
local function enhanceNPC(npc)
    npc:SetMaxLookDistance(CONSTANTS.NPC_MAX_LOOK_DISTANCE)
    npc:SetKeyValue("wakeradius", CONSTANTS.NPC_MAX_LOOK_DISTANCE)
end

-- 内部：注册一个新 NPC 到事件总线
local function initNpc(npc)
    activeNPCS[npc]    = true
    lastSchedules[npc] = npc:GetCurrentSchedule()
    lastStates[npc]    = npc:GetNPCState()
    lastEnemies[npc]   = npc:GetEnemy()

    -- 条件变化缓存初始化（如果启用）
    for name, id in pairs(COND) do
        allLastConditions[name][npc] = npc:HasCondition(id)
    end

    enhanceNPC(npc)
end

-- 内部：清理实体相关缓存
local function cleanupEntity(ent)
    activeNPCS[ent]    = nil
    activeDummies[ent] = nil

    lastSchedules[ent] = nil
    lastStates[ent]    = nil
    lastEnemies[ent]   = nil

    if allLastConditions then
        for name in pairs(allLastConditions) do
            allLastConditions[name][ent] = nil
        end
    end
end

-- 公开 API：遍历活跃 NPC
function NPCMonitor.ForEachActiveNPC(callback)
    for npc in pairs(activeNPCS) do
        if callback(npc) then break end
    end
end

-- 公开 API：遍历活跃 Dummy
function NPCMonitor.ForEachActiveDummy(callback)
    for dummy in pairs(activeDummies) do
        if callback(dummy) then break end
    end
end

-- Hook：服务器初始化后扫描已有实体
addUniqueHook("InitPostEntity", function()
    for _, ent in ipairs(ents.GetAll()) do
        if not IsValid(ent) or not ent:IsNPC() then continue end

        if ent:GetClass() == CONSTANTS.RAGADOLL_DUMMY_CLASS then
            activeDummies[ent] = true
        else
            initNpc(ent)
        end
    end
end)

-- Hook：当玩家/实体死亡生成布娃娃时，创建对应的 dummy 目标
addUniqueHook(EDAEConstants.Events.OnRagdollInitialized, function(ragdoll, owner)
    if not IsValid(owner) or not IsValid(ragdoll) then return end

    if CONSTANTS.PLAYER_ONLY then
        if not owner:IsPlayer() then return end
    end

    local dummy = ents.Create(CONSTANTS.RAGADOLL_DUMMY_CLASS)
    if IsValid(dummy) then
        dummy:Spawn()
        dummy:Init(owner, ragdoll)
    end
end)

-- Hook：新实体创建时自动注册
addUniqueHook("OnEntityCreated", function(entity)
    if not IsValid(entity) or not entity:IsNPC() then return end

    if entity:GetClass() == CONSTANTS.RAGADOLL_DUMMY_CLASS then
        activeDummies[entity] = true
    else
        initNpc(entity)
    end
end)

-- Hook：实体移除时清理缓存
addUniqueHook("EntityRemoved", function(ent, _)
    cleanupEntity(ent)
end)

-- Hook：每 Tick 轮询状态变化并发布事件
addUniqueHook("Tick", function()
    -- 条件变化检测（可选功能，默认注释）
    -- for name, id in pairs(COND) do
    --     local lastConditions = allLastConditions[name] -- { npc -> has }
    --     for npc in pairs(activeNPCS) do
    --         if not IsValid(npc) then continue end

    --         local lastCondition = lastConditions[npc]
    --         local currentCondition = npc:HasCondition(id)
    --         if lastCondition ~= currentCondition then
    --             hook.Run(Events.OnCondition, npc, name, id, lastCondition, currentCondition)
    --             lastConditions[npc] = currentCondition
    --         end
    --     end
    -- end

    for npc in pairs(activeNPCS) do
        if not IsValid(npc) then continue end

        -- 检测 schedule 变化
        local lastSchedule = lastSchedules[npc]
        local currentSchedule = npc:GetCurrentSchedule()
        if lastSchedule ~= currentSchedule then
            hook.Run(Events.TranslateSchedule, npc, lastSchedule, currentSchedule)
            lastSchedules[npc] = currentSchedule
        end

        -- 检测 state 变化
        local lastState = lastStates[npc]
        local currentState = npc:GetNPCState()
        if lastState ~= currentState then
            hook.Run(Events.OnStateChange, npc, lastState, currentState)
            lastStates[npc] = currentState
        end

        -- 检测 enemy 变化
        local lastEnemy    = lastEnemies[npc]
        local currentEnemy = npc:GetEnemy()
        if lastEnemy ~= currentEnemy then
            hook.Run(Events.OnEnemyChange, npc, lastEnemy, currentEnemy)
            lastEnemies[npc] = currentEnemy
        end
    end
end)
