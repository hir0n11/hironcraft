local HironCraftScan = select(2, ...)

-- The Registry: ["EVENT_NAME"] = { func1, func2, ... }
local registry = {}

local Events = {}

-- A failing listener must not stop the code that raised the event: a decline
-- is recorded, and then shared, after its listeners ran. The error goes to
-- the error log (Utils/ErrorLog.lua) and on to the game's handler.

--- Registers a function to be called when a specific event is emitted.
-- @param eventName string The unique tag for the event.
-- @param func function The callback function.
function Events:Register(eventName, func)
    if type(eventName) == 'table' then
        for _, event in ipairs(eventName) do
            Events:Register(event, func)
        end
        return
    end
    assert(type(func) == "function")
    
    if not registry[eventName] then
        registry[eventName] = {}
    end
    
    table.insert(registry[eventName], func)
end

--- Unregisters a specific function from an event.
-- @param eventName string
-- @param func function
function Events:Unregister(eventName, func)
    if not registry[eventName] then return end
    
    for i, registeredFunc in ipairs(registry[eventName]) do
        if registeredFunc == func then
            table.remove(registry[eventName], i)
            break
        end
    end
end

--- Emits an event, passing all additional arguments to the registered functions.
-- @param eventName string
-- @param ... any Arguments passed to the callbacks.
function Events:Emit(eventName, ...)
    local callbacks = registry[eventName]
    if not callbacks then return end

    local count, args = select('#', ...), { ... }
    local function OnError(err)
        if HironCraftScan.ReportError then
            HironCraftScan.ReportError(eventName, err, debugstack and debugstack(2) or nil)
        end
    end
    for _, func in ipairs(callbacks) do
        xpcall(function() return func(unpack(args, 1, count)) end, OnError)
    end
end

-- Attach to the addon namespace
HironCraftScan.Events = Events