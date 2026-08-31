local MODULE_NAME = "CoroutineScheduler"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants = include("edae/constants.lua")

local Scheduler = {}

local activeCoros = {}
local eventNameToCorosMap = {}
local isRegistered = {}

function Scheduler:_MakeHookIdentifier(eventName)
    return Constants.ADDON_NAME .. MODULE_NAME .. eventName
end

function Scheduler:_HandleMessage(coro, msg)
    if type(msg) == "table" and msg.type == "event" then
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
    local snapshot = activeCoros
    activeCoros = {}
    for _, coro in ipairs(snapshot) do
        self:_Resume(coro)
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

--- Broadcast + Fire & Forget
---@param eventName string
function Scheduler:WaitForEvent(eventName)
    return coroutine.yield({ type = "event", name = eventName })
end

hook.Add("Think", Scheduler:_MakeHookIdentifier("Think"), function()
    Scheduler:_Think()
end)

_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = Scheduler
return Scheduler
