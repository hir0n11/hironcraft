local HironCraftScan = select(2, ...)

-- Every Lua error that passes through HironCraft is kept in SavedVariables
-- (settings.error_log, the newest few), so a problem seen in the game can be
-- read afterwards instead of caught on screen. Errors are still shown exactly
-- as before: the game's error frame or BugSack gets every one of them.
local MAX_LOGGED_ERRORS = 20
local MAX_TEXT = 2000
local pending = {}
local reporting = false

local function Settings()
    -- The SavedVariable exists only after ADDON_LOADED. Never create it
    -- earlier: the saved one would then be thrown away.
    local db = rawget(_G, 'HironCraftScan_DB')
    local settings = type(db) == 'table' and db.settings
    return type(settings) == 'table' and settings or nil
end

local function Store(entry)
    local settings = Settings()
    if not settings then
        if #pending < MAX_LOGGED_ERRORS then pending[#pending + 1] = entry end
        return
    end
    local log = type(settings.error_log) == 'table' and settings.error_log or {}
    settings.error_log = log
    for index = 1, #pending do table.insert(log, 1, pending[index]) end
    pending = {}

    -- An error in an OnUpdate repeats every frame: count it instead of
    -- pushing everything else out of the log.
    local newest = log[1]
    if newest and newest.error == entry.error and newest.context == entry.context then
        newest.count = (newest.count or 1) + 1
        newest.last = entry.at
    else
        table.insert(log, 1, entry)
    end
    for index = #log, MAX_LOGGED_ERRORS + 1, -1 do log[index] = nil end
end

local function Record(context, err, stack)
    Store({
        at = time and time() or 0,
        context = tostring(context),
        error = tostring(err):sub(1, MAX_TEXT),
        stack = type(stack) == 'string' and stack:sub(1, MAX_TEXT) or nil,
    })
end

local function IsOurs(text)
    return type(text) == 'string'
        and (text:find('AddOns[\\/]HironCraft[\\/]') ~= nil or text:find('HironCraft\\', 1, true) ~= nil)
end

-- An error HironCraft caught itself (a failing listener) is recorded with
-- its context and then passed on to the game's handler as usual.
function HironCraftScan.ReportError(context, err, stack)
    Record(context, err, stack)
    local handler = geterrorhandler and geterrorhandler()
    if handler then
        reporting = true
        pcall(handler, err)
        reporting = false
    end
end

local function OnAnyError(err, stack)
    if reporting then return end
    if IsOurs(tostring(err)) or IsOurs(stack) then
        Record('lua', err, stack)
    end
end

HironCraftScan.ErrorLog = { OnAnyError = OnAnyError, IsOurs = IsOurs }

-- BugGrabber takes the error handler for itself and refuses to give it up,
-- but announces every error it grabs. Without it, stand in front of the
-- current handler and pass everything on.
local mode, wrapper = nil, nil
local function Hook()
    if mode == 'buggrabber' then return end
    local grabber = rawget(_G, 'BugGrabber')
    if type(grabber) == 'table' and type(grabber.RegisterCallback) == 'function' then
        local ok = pcall(grabber.RegisterCallback, HironCraftScan.ErrorLog, 'BugGrabber_BugGrabbed',
            function(_, bug)
                if type(bug) == 'table' then OnAnyError(bug.message, bug.stack) end
            end)
        if ok then mode = 'buggrabber' return end
    end
    if not (geterrorhandler and seterrorhandler) then return end
    local previous = geterrorhandler()
    if previous == wrapper and wrapper then return end
    wrapper = function(err, ...)
        pcall(OnAnyError, err, debugstack and debugstack(3) or nil)
        if previous then return previous(err, ...) end
    end
    seterrorhandler(wrapper)
    mode = 'handler'
end

Hook()

-- BugGrabber may load after this file, or another addon may replace the
-- handler; look again once everything is in.
if CreateFrame then
    local frame = CreateFrame('Frame')
    frame:RegisterEvent('PLAYER_LOGIN')
    frame:SetScript('OnEvent', function(self)
        self:UnregisterAllEvents()
        Hook()
    end)
end
