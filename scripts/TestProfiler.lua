-- The hitch profiler must be inert until enabled, keep return values and
-- errors intact, and name the functions that consumed a slow frame.
local clockValue = 0
function debugprofilestop() return clockValue end
local printed = {}
function print(line) printed[#printed + 1] = line end
local onUpdate
function CreateFrame()
    return {SetScript=function(_, _, fn) onUpdate = fn end, Show=function() end, Hide=function() end}
end
SlashCmdList = {}

local CO = {}
function CO:Slow(value) clockValue = clockValue + 900; return value, 'second' end
function CO:Fast() clockValue = clockValue + 1 end
function CO:Fail() error('boom') end
function CO:DebugDump() return 'untouched' end
HironCraftProfitCraftingOrders = CO
local originalSlow = CO.Slow
local Scan = {OrderFulfillment = {Lookup = function() clockValue = clockValue + 200 end}}
assert(loadfile('Utils/Profiler.lua'))('HironCraft', Scan)
assert(CO.Slow == originalSlow, 'functions were wrapped before /hcprof')

SlashCmdList.HIRONCRAFTPROF('150')
assert(Scan.Profiler.enabled and CO.Slow ~= originalSlow and CO.DebugDump() == 'untouched')
onUpdate()
local a, b = CO:Slow('first')
assert(a == 'first' and b == 'second', 'wrapper lost return values')
CO:Fast()
Scan.OrderFulfillment.Lookup()
assert(not pcall(CO.Fail, CO), 'wrapper swallowed an error')
printed = {}
onUpdate()
local report = table.concat(printed, '\n')
assert(report:find('frame 1101 ms', 1, true), report)
assert(report:find('900 ms', 1, true) and report:find('CO:Slow', 1, true), report)
assert(report:find('OrderFulfillment.Lookup', 1, true), report)
assert(not report:find('CO:Fast', 1, true), 'sub-5 ms entries should be omitted')

printed = {}
clockValue = clockValue + 10
onUpdate()
assert(#printed == 0, 'fast frame was reported')

SlashCmdList.HIRONCRAFTPROF('off')
assert(not Scan.Profiler.enabled)
local x = CO:Slow('passthrough')
assert(x == 'passthrough', 'disabled wrapper did not forward')
print = nil
io.write('Profiler tests passed (inert until enabled, returns/errors intact, slow frame attribution).\n')
