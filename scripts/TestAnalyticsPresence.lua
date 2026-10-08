-- Exact local presence, immutable sync records, fast relogs and interval union.
strmatch = string.match
assert(loadfile('Workflow/Core/Libs/LibStub/LibStub.lua'))()
assert(loadfile('Libs/LibSerialize.lua'))()
assert(loadfile('Libs/LibDeflate.lua'))()
local base = os.time({ year = 2026, month = 9, day = 28, hour = 12, min = 4, sec = 17 })
local now, ticker, tickerSeconds = base
local frames = {}
time = function(t) return t and os.time(t) or now end
date = os.date
GetTime = function() return now - base end
UnitFactionGroup = function() return 'Horde' end
C_Timer = { NewTicker = function(seconds, fn)
    tickerSeconds, ticker = seconds, fn
    return {}
end }
function CreateFrame()
    local f = { events = {} }
    function f:RegisterEvent(event) self.events[event] = true end
    function f:SetScript(_, fn) self.handler = fn end
    frames[#frames + 1] = f
    return f
end
local Scan = { DB = { analytics = {}, settings = {} }, Utils = {} }
assert(loadfile('Customer/AnalyticsLog.lua'))('HironCraft', Scan)
assert(loadfile('Customer/AnalyticsReport.lua'))('HironCraft', Scan)
local Log, R = Scan.AnalyticsLog, Scan.AnalyticsReport
Log.synchronous = true
local checked = 0
local function check(ok, why) assert(ok, why); checked = checked + 1 end
local function near(value, expected) return math.abs((value or 0) - expected) < 0.00001 end
local function tick(at) now = at; ticker() end
local function all()
    local chunks
    Log.LoadRange(0, now, nil, function(value) chunks = value end)
    return chunks
end
local function report(filters) return R.Build(all(), filters or {}) end
local function reset(at)
    Log.StopPresence()
    Scan.DB.analytics = {}
    now = at or base
end
local function emit(event)
    for _, f in ipairs(frames) do if f.events[event] then f.handler(f, event) end end
end

Log.StartPresence()
check(tickerSeconds == 30 and Log.Root().presencePending.t == base, 'login was rounded to a five-minute slot')
check(Log.Seq() == 0, 'login claimed unobserved time or queued a sync record')
tick(base + 30)
local snapshot = all()
check(near(report().totals.online, 0.5), 'live checkpoint was not shown locally')
tick(base + 60)
check(snapshot[#snapshot][1].e == base + 30, 'a snapshot was mutated after publication')
for elapsed = 90, 270, 30 do tick(base + elapsed) end
check(Log.Seq() == 0, 'each checkpoint added network/journal traffic')
tick(base + 300)
local committed = Log.Root().open.events[1]
check(Log.Seq() == 1 and committed.t == base and committed.e == base + 300, 'five-minute batch lost exact endpoints')
now = base + 315; Log.StopPresence()
check(Log.Seq() == 2 and committed.e == base + 300, 'exit changed an already-sendable record')
check(near(report().totals.online, 315 / 60), 'normal exit did not record the final 15 seconds')
tick(base + 360)
check(not Log.Root().presencePending and Log.Seq() == 2, 'ticker kept counting after logout')
now = base + 600; Log.StartPresence()
tick(base + 630); now = base + 640; Log.StopPresence()
check(near(report().totals.online, 355 / 60), 'fast relog filled the offline gap')
Log.Merge({ { k = 'p', t = base + 100, e = base + 400, f = 'A' } }, 'peer')
check(near(report().totals.online, 440 / 60), 'two active accounts doubled overlap')
check(near(report({ side = 'H' }).totals.online, 355 / 60), 'side filter included the other account')

reset(); Log.StartPresence(); tick(base + 30); tick(base + 600); tick(base + 630); Log.StopPresence()
check(near(report().totals.online, 1), 'a suspended/disconnected gap was counted as continuous online')

reset()
Log.Root().presencePending = { t = base, e = base + 20, f = 'H' }
now = base + 3600; Log.StartPresence()
check(Log.Root().open.events[1].e == base + 20 and Log.Root().presencePending.t == now,
    'saved checkpoint was extended across sessions')
now = now + 10; Log.StopPresence()
check(near(report().totals.online, 0.5), 'checkpoint recovery lost or duplicated time')

reset(); emit('PLAYER_ENTERING_WORLD'); now = base + 10; emit('PLAYER_ENTERING_WORLD')
check(Log.Seq() == 0 and Log.Root().presencePending.t == base, 'duplicate enter restarted the session')
now = base + 17; emit('PLAYER_LEAVING_WORLD'); emit('PLAYER_LOGOUT')
check(Log.Seq() == 1 and near(report().totals.online, 17 / 60), 'short login or duplicate logout is inaccurate')

reset(); Log.StartPresence(); tick(base + 30); Log.SetEnabled(false)
tick(base + 300)
check(Log.Seq() == 1 and not Log.Root().presencePending, 'disabled collection kept recording')
now = base + 360; Log.SetEnabled(true); tick(base + 390); now = base + 400; Log.StopPresence()
check(near(report().totals.online, 70 / 60), 'enable/disable bridged a disabled gap')

local midnight = os.time({ year = 2026, month = 9, day = 29, hour = 0, min = 0, sec = 0 })
reset(midnight - 15); Log.StartPresence(); tick(midnight + 15); now = midnight + 25; Log.StopPresence()
local result = report()
check(near(result.hours.online[23], 15 / 60) and near(result.hours.online[0], 25 / 60), 'midnight/hour split is inaccurate')
check(near(result.calendar.days['2026-09-28'].online, 15 / 60)
    and near(result.calendar.days['2026-09-29'].online, 25 / 60), 'dated buckets lost seconds at midnight')
check(near(report({ from = midnight, to = now }).totals.online, 25 / 60), 'selected day did not clip the interval')
check(Log.Root().open.to == midnight + 25, 'archive range ignored the interval endpoint')
Log.CloseOpenStore()
check(Log.Root().stores[1].to == midnight + 25, 'compressed store will be skipped when loading the next day')

reset(base + 600)
local start = math.floor(base / 300) * 300
Log.Record({ k = 'p', t = start, f = 'H' })
Log.Record({ k = 'p', t = start + 100, e = start + 400, f = 'H' })
check(near(report().totals.online, 400 / 60), 'legacy and precise intervals double-counted overlap')
local first = report({ from = start + 280, to = start + 319 })
check(near(first.totals.online, 40 / 60), 'partial custom range was rounded to five minutes')
print('Analytics presence checks passed: ' .. checked)
