local HironCraftScan = select(2, ...)

-- The Registry: ["EVENT_NAME"] = { func1, func2, ... }
local registry = {}

local Events = {}

-- A failing listener must not stop the code that raised the event: a decline
-- is recorded, and then shared, after its listeners ran. The error is kept in
-- SavedVariables (the newest few) so it can be read after the session, and
-- still reported through WoW's error handler (or BugSack).
local MAX_LOGGED_ERRORS = 20

function HironCraftScan.ReportError(context, err, stack)
    local settings = HironCraftScan.DB and HironCraftScan.DB.settings
    if type(settings) == 'table' then
        local log = type(settings.error_log) == 'table' and settings.error_log or {}
        settings.error_log = log
        table.insert(log, 1, {
            at = time and time() or 0,
            context = tostring(context),
            error = tostring(err),
            stack = type(stack) == 'string' and stack:sub(1, 2000) or nil,
        })
        for index = #log, MAX_LOGGED_ERRORS + 1, -1 do log[index] = nil end
    end
    local handler = geterrorhandler and geterrorhandler()
    if handler then pcall(handler, err) end
end

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
        HironCraftScan.ReportError(eventName, err, debugstack and debugstack(2) or nil)
    end
    for _, func in ipairs(callbacks) do
        xpcall(function() return func(unpack(args, 1, count)) end, OnError)
    end
end

-- Attach to the addon namespace
HironCraftScan.Events = Events