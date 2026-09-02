local MODULE_NAME = "CoroutineScheduler"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants = include("edae/config/constants.lua")

local Scheduler = {}

local activeCoros = {}
local timeWaiters = {}
local predicateWaiters = {}
local eventNameToCorosMap = {}
local isRegistered = {}

function Scheduler:_MakeHookIdentifier(eventName)
    return Constants.ADDON_NAME .. MODULE_NAME .. eventName
end

function Scheduler:_HandleMessage(coro, msg)
    if type(msg) == "table" then
        if msg.type == "event" then
            local eventName = msg.name

            eventNameToCorosMap[eventName] = eventNameToCorosMap[eventName] or {}
            table.insert(eventNameToCorosMap[eventName], coro)

            if not isRegistered[eventName] then
                isRegistered[eventName] = true

                local identifier = self:_MakeHookIdentifier(eventName)
                hook.Add(eventName, identifier, function(...)
                    local waiterSnapshot = eventNameToCorosMap[eventName]
                    eventNameToCorosMap[eventName] = nil

                    if waiterSnapshot then
                        for _, waiter in ipairs(waiterSnapshot) do
                            self:_Resume(waiter, ...)
                        end
                    end

                    if not eventNameToCorosMap[eventName] then
                        hook.Remove(eventName, identifier)
                        isRegistered[eventName] = nil
                    end
                end)
            end
        elseif msg.type == "time" then
            table.insert(timeWaiters, { coro = coro, targetTime = msg.targetTime })
        elseif msg.type == "predicate" then
            table.insert(predicateWaiters, {
                coro = coro,
                predicate = msg.predicate,
                timeout = msg.timeout,
                checkInterval = msg.checkInterval,
                startTime = CurTime(),
                lastCheckTime = 0,
            })
        else
            table.insert(activeCoros, coro)
        end
    else
        table.insert(activeCoros, coro)
    end
end

function Scheduler:_Resume(coro, ...)
    if coroutine.status(coro) == "dead" then return false end

    local ok, msg = coroutine.resume(coro, ...)
    if not ok then
        ErrorNoHalt("Coroutine error: " .. tostring(msg) .. "\n")
        return false
    end

    if coroutine.status(coro) == "dead" then return false end

    self:_HandleMessage(coro, msg)

    return true
end

function Scheduler:_Think()
    -- 处理等待下一帧的协程
    local snapshot = activeCoros
    activeCoros = {}
    for _, coro in ipairs(snapshot) do
        self:_Resume(coro)
    end

    local now = CurTime()

    -- 处理时间等待
    local timeToResume = {}
    for i = #timeWaiters, 1, -1 do
        local waiter = timeWaiters[i]
        if now >= waiter.targetTime then
            table.remove(timeWaiters, i)
            timeToResume[#timeToResume + 1] = waiter.coro
        end
    end
    for _, coro in ipairs(timeToResume) do
        self:_Resume(coro)
    end

    -- 处理谓词等待
    local predToResume = {}
    for i = #predicateWaiters, 1, -1 do
        local waiter = predicateWaiters[i]
        local shouldCheck = false
        if waiter.checkInterval <= 0 then
            shouldCheck = true
        elseif now - waiter.lastCheckTime >= waiter.checkInterval then
            shouldCheck = true
        end

        if shouldCheck then
            waiter.lastCheckTime = now
            local ok, result = pcall(waiter.predicate)
            if ok and result == true then
                table.remove(predicateWaiters, i)
                predToResume[#predToResume + 1] = { coro = waiter.coro, value = true }
            elseif waiter.timeout and now - waiter.startTime >= waiter.timeout then
                table.remove(predicateWaiters, i)
                predToResume[#predToResume + 1] = { coro = waiter.coro, value = false }
            end
        end
    end
    for _, item in ipairs(predToResume) do
        self:_Resume(item.coro, item.value)
    end
end

--- Start a coroutine
---@param func function
---@param ... any will be pass to the the coroutine at first run
---@return thread coro
function Scheduler:Start(func, ...)
    local coro = coroutine.create(func)
    self:_Resume(coro, ...)
    return coro
end

-- --- 强制停止一个协程，将其从所有等待队列中移除
-- --- @param coro thread 要停止的协程
-- --- @return boolean 是否找到并移除了该协程
-- function Scheduler:Cancel(coro)
--     if not coro or coroutine.status(coro) == "dead" then
--         return false
--     end

--     local found = false

--     -- 从 activeCoros 中移除
--     for i = #activeCoros, 1, -1 do
--         if activeCoros[i] == coro then
--             table.remove(activeCoros, i)
--             found = true
--         end
--     end

--     -- 从 timeWaiters 中移除
--     for i = #timeWaiters, 1, -1 do
--         if timeWaiters[i].coro == coro then
--             table.remove(timeWaiters, i)
--             found = true
--         end
--     end

--     -- 从 predicateWaiters 中移除
--     for i = #predicateWaiters, 1, -1 do
--         if predicateWaiters[i].coro == coro then
--             table.remove(predicateWaiters, i)
--             found = true
--         end
--     end

--     -- 从 eventNameToCorosMap 中移除，并清理空事件
--     for eventName, waiters in pairs(eventNameToCorosMap) do
--         for i = #waiters, 1, -1 do
--             if waiters[i] == coro then
--                 table.remove(waiters, i)
--                 found = true
--             end
--         end
--         if #waiters == 0 then
--             eventNameToCorosMap[eventName] = nil
--             if isRegistered[eventName] then
--                 hook.Remove(eventName, self:_MakeHookIdentifier(eventName))
--                 isRegistered[eventName] = nil
--             end
--         end
--     end

--     return found
-- end

--- Broadcast + Fire & Forget
---@param eventName string
function Scheduler:WaitForEvent(eventName)
    return coroutine.yield({ type = "event", name = eventName })
end

--- Wait for a specified number of seconds
---@param seconds number
function Scheduler:Wait(seconds)
    assert(type(seconds) == "number" and seconds >= 0, "Wait: seconds must be a non-negative number")
    return coroutine.yield({ type = "time", targetTime = CurTime() + seconds })
end

--- Wait until predicate returns true, with optional timeout and check interval
---@param predicate function
---@param timeout number|nil Timeout in seconds, nil for no timeout
---@param checkInterval number|nil Check interval in seconds, default 0 (every frame)
---@return boolean success true if predicate returned true, false if timed out
function Scheduler:WaitUntil(predicate, timeout, checkInterval)
    assert(type(predicate) == "function", "WaitUntil: predicate must be a function")
    checkInterval = checkInterval or 0
    return coroutine.yield({ type = "predicate", predicate = predicate, timeout = timeout, checkInterval = checkInterval })
end

hook.Add("Think", Scheduler:_MakeHookIdentifier("Think"), function()
    Scheduler:_Think()
end)

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = Scheduler
return Scheduler
