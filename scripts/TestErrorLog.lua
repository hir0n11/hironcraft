-- Every Lua error that passes through HironCraft is kept in SavedVariables,
-- and still reaches the game's handler (or BugSack) exactly as before.
local now = 1000
function time() return now end
function debugstack() return 'Interface/AddOns/HironCraft/Customer/ChatScanner.lua:10: in function' end

local shown = {}
local handler = function(err) shown[#shown + 1] = err end
function geterrorhandler() return handler end
function seterrorhandler(value) handler = value end

HironCraftScan_DB = nil
local Scan = {}
assert(loadfile('Utils/ErrorLog.lua'))('HironCraft', Scan)
assert(handler ~= nil and Scan.ReportError, 'the error log did not install itself')

-- Before the SavedVariables are loaded nothing may create them; the error
-- waits and is written once they exist.
handler('Interface/AddOns/HironCraft/Bootstrap.lua:5: early')
assert(HironCraftScan_DB == nil, 'the SavedVariable was created before it was loaded')
assert(#shown == 1, 'the game did not see the error')
HironCraftScan_DB = { settings = {} }
handler('Interface/AddOns/HironCraft/Customer/QuickReplies.lua:42: attempt to index nil')
local log = HironCraftScan_DB.settings.error_log
assert(log and #log == 2, 'the errors were not kept')
assert(log[1].error:find('QuickReplies.lua:42', 1, true) and log[2].error:find('early', 1, true),
    'the errors are not newest first')
assert(log[1].stack and log[1].context == 'lua', 'the stack or the context is missing')
assert(#shown == 2, 'the game stopped seeing errors')

-- Another addon's error is not ours to keep.
debugstack = function() return 'Interface/AddOns/OtherAddon/Core.lua:1: in function' end
handler('Interface/AddOns/OtherAddon/Core.lua:1: broken')
assert(#log == 2 and #shown == 3, 'a foreign error was kept, or hidden from the game')

-- An error in an OnUpdate repeats every frame: it is counted, not repeated.
for _ = 1, 50 do handler('Interface/AddOns/HironCraft/UI/Row.lua:7: every frame') end
assert(#log == 3 and log[1].count == 50, 'a repeating error pushed everything else out')

-- An error HironCraft caught itself is kept once, with its context.
Scan.ReportError('ORDER_FULFILLMENT_UPDATED', 'Interface/AddOns/HironCraft/Customer/X.lua:1: listener')
assert(log[1].context == 'ORDER_FULFILLMENT_UPDATED' and log[2].count == 50,
    'a caught error was lost or kept twice')
assert(#shown == 54, 'a caught error did not reach the game')

-- The log keeps only the newest few.
for index = 1, 40 do handler('Interface/AddOns/HironCraft/A.lua:' .. index .. ': distinct') end
assert(#log == 20 and log[1].error:find('A.lua:40', 1, true), 'the log grew without bound')

-- With BugGrabber the handler belongs to it; its announcements are used.
local callbacks = {}
BugGrabber = { RegisterCallback = function(target, event, callback)
    callbacks[#callbacks + 1] = { target = target, event = event, callback = callback }
end }
handler = function() end
HironCraftScan_DB = { settings = {} }
local Scan2 = {}
assert(loadfile('Utils/ErrorLog.lua'))('HironCraft', Scan2)
assert(#callbacks == 1 and callbacks[1].event == 'BugGrabber_BugGrabbed', 'BugGrabber was not listened to')
callbacks[1].callback('BugGrabber_BugGrabbed', {
    message = 'Interface/AddOns/HironCraft/Customer/ChatScanner.lua:9: grabbed',
    stack = 'Interface/AddOns/HironCraft/Customer/ChatScanner.lua:9',
})
assert(HironCraftScan_DB.settings.error_log[1].error:find('grabbed', 1, true), 'a grabbed error was not kept')
BugGrabber = nil

print('Error log tests passed (early errors, foreign errors, repeats, caught errors, limit, BugGrabber).')
