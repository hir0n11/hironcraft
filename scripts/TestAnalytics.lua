-- The analytics journal, its report and the exchange between linked accounts.
-- Real LibSerialize/LibDeflate; WoW API stubbed.
local now = os.time({ year = 2026, month = 9, day = 20, hour = 12 })
local clock = 1000
function time(t) if t then return os.time(t) end return now end
date = os.date
function GetTime() return clock end
function InCombatLockdown() return false end
local side = 'Alliance'
function UnitFactionGroup() return side end

strmatch = string.match
assert(loadfile("ProfitHub/Core/Libs/LibStub/LibStub.lua"))()
assert(loadfile('Libs/LibSerialize.lua'))()
assert(loadfile('Libs/LibDeflate.lua'))()

local function newDB()
    return { analytics = {}, settings = { my_uuid = 'me' }, realm = { linked_accounts = {} } }
end
local Scan = { DB = newDB(), Utils = {} }
function Scan.Utils.Contains(list, value)
    for _, entry in ipairs(list or {}) do if entry == value then return true end end
    return false
end
local function load(path) assert(loadfile(path))('HironCraft', Scan) end
load('Customer/AnalyticsLog.lua')
load('Customer/AnalyticsReport.lua')
load('Customer/AnalyticsSync.lua')
local Log, Report, Sync = Scan.AnalyticsLog, Scan.AnalyticsReport, Scan.AnalyticsSync
Log.synchronous = true

local function all()
    local chunks
    Log.LoadRange(0, math.huge, nil, function(loaded) chunks = loaded end)
    return chunks
end
local function build(filters, marks)
    return Report.Build(all(), filters, {
        markOf = function(name) return marks and marks[Report.BaseKey(name)] or nil end,
    })
end
local function row(report, key)
    for _, entry in ipairs(report.rows) do if entry.key == key then return entry end end
end
local function customer(report, key)
    for _, entry in ipairs(report.customers) do if entry.key == key then return entry end end
end

-- A conversation: "LF tailor" greeted from the Alliance, narrowed to a cloak,
-- delivered as a concrete item: one request, counted under that item.
Log.Request('Buyer-Realm', { requestToken = 't1', parentProfID = 197, crafterFullName = 'Tailor-Realm', time = now })
Log.Greeting('Buyer-Realm', { requestToken = 't1', crafterFullName = 'Tailor-Realm' })
Log.Request('Buyer-Realm', { requestToken = 't2', itemID = 1001, parentProfID = 197,
    crafterFullName = 'Tailor-Realm', time = now + 60 })
Log.Replaced('t1', 't2')
Log.Outcome({ orderID = 555, status = 'fulfilled', customerName = 'Buyer', itemID = 2002,
    parentProfessionID = 197, crafterFullName = 'Tailor-Realm', tipAmount = 6000 * 10000, updatedAt = now + 600 })
Log.Link('t2', 555, 'fulfilled')
-- A wrist slot, greeted, crafted as a concrete bracer.
Log.Request('Slot-Realm', { requestToken = 't3', parentProfID = 197, equipmentRequest = { key = 'INVTYPE_WRIST', label = 'Wrist' },
    crafterFullName = 'Tailor-Realm', time = now })
Log.Greeting('Slot-Realm', { requestToken = 't3' })
Log.Outcome({ orderID = 556, status = 'fulfilled', customerName = 'Slot-Realm', itemID = 3003,
    parentProfessionID = 197, tipAmount = 500 * 10000, updatedAt = now + 700, requestToken = 't3' })
-- Greeted, never ordered.
Log.Request('Window-Realm', { requestToken = 't4', itemID = 1001, parentProfID = 197, time = now })
Log.Greeting('Window-Realm', { requestToken = 't4' })
-- Greeted and declined.
Log.Request('Cheap-Realm', { requestToken = 't5', itemID = 1001, parentProfID = 197, time = now })
Log.Greeting('Cheap-Realm', { requestToken = 't5' })
Log.Outcome({ orderID = 558, status = 'rejected', customerName = 'Cheap', itemID = 1001, updatedAt = now + 800 })
Log.Link('t5', 558, 'rejected')
-- An order from someone who never wrote: counted as an order only.
Log.Outcome({ orderID = 557, status = 'fulfilled', customerName = 'Direct', itemID = 2002,
    parentProfessionID = 197, tipAmount = 2000 * 10000, updatedAt = now + 900 })
-- Mentions: the same customer repeating a link within a minute is one.
Log.Mention('Chatty-Realm', 1001, 197)
now = now + 30
Log.Mention('Chatty-Realm', 1001)
now = now + 40
Log.Mention('Other-Realm', 1001)
Log.Mention('Other-Realm', 4004)

local report = build()
local cloak = row(report, 'item:2002')
assert(cloak and cloak.requests == 1 and cloak.greetings == 1 and cloak.crafted == 1,
    'a narrowed request was not counted once, under the crafted item')
assert(cloak.orders == 2 and cloak.tips == 8000 * 10000, 'orders or tips of the crafted item are off')
assert(not row(report, 'prof:197'), 'the replaced profession row was counted as a request of its own')
local bracer = row(report, 'item:3003')
assert(bracer and bracer.requests == 1 and bracer.crafted == 1, 'a slot request was not counted under the bracer')
local asked = row(report, 'item:1001')
assert(asked.requests == 2 and asked.greetings == 2 and asked.crafted == 0 and asked.declined == 1,
    'greeted-but-not-ordered and declined requests are off')
assert(asked.mentions == 2, 'mentions were not merged within a minute: ' .. tostring(asked.mentions))
assert(row(report, 'item:4004').mentions == 1)
local totals = report.totals
assert(totals.requests == 4 and totals.greetings == 4 and totals.crafted == 2 and totals.conversion == 0.5,
    'the funnel totals are off')
assert(totals.orders == 3 and totals.declined == 1, 'order totals are off')
local sum = 0
for hour = 0, 23 do sum = sum + report.hours.orders[hour] end
assert(sum == 3, 'orders by hour do not add up')
sum = 0
for day = 1, 7 do sum = sum + report.weekdays.requests[day] end
assert(sum == 4, 'requests by weekday do not add up')
local buyer = customer(report, 'buyer')
assert(buyer and buyer.orders == 1 and buyer.maxTip == 6000 * 10000 and buyer.conversion == 1)

-- Tiers of the period's customers, by their coin now.
local marks = { buyer = 'generous', slot = 'stingy', direct = 'regular' }
report = build(nil, marks)
assert(report.tiers.generous == 1 and report.tiers.stingy == 1 and report.tiers.regular == 1,
    'customers per tier are off')
-- A customer with delivered orders and no coin (from before tips were kept)
-- counts as silver.
report = build(nil, { buyer = 'generous', slot = 'stingy' })
assert(report.tiers.regular == 1 and report.tiers.none == 0, 'an untipped customer was not counted as silver')
assert(build({ tier = 'regular' }, { buyer = 'generous', slot = 'stingy' }).totals.orders == 1,
    'the silver filter missed an untipped customer')
report = build({ tier = 'generous' }, marks)
assert(report.totals.orders == 1 and #report.customers == 1, 'the tier filter let others through')

-- Side: a conversation is on the side of the character that greeted.
report = build({ side = 'H' })
assert(report.totals.requests == 0 and report.totals.orders == 0, 'Alliance greetings counted for the Horde')
report = build({ side = 'A' })
assert(report.totals.requests == 4 and report.totals.crafted == 2, 'the Alliance lost its conversations')

-- Dates and professions.
report = build({ from = now + 100000 })
assert(report.totals.requests == 0 and report.totals.orders == 0, 'the date filter let old events through')
report = build({ ppID = 164 })
assert(report.totals.requests == 0, 'the profession filter let tailoring through')
report = build({ crafter = 'Tailor-Other' })
assert(report.totals.requests == 2 and report.totals.mentions == 0, 'the crafter filter is off')
print('Analytics report passed (narrowing, slots, funnel, mentions, tiers, sides, dates, filters).')

-- A greeting the server swallowed is taken back.
local sent = Log.Greeting('Swallowed', { requestToken = 't9' })
Log.Retract({ sent })
for _, event in ipairs(Scan.DB.analytics.open.events) do
    assert(event ~= sent, 'a swallowed greeting stayed in the journal')
end

-- Full stores are packed; reading them back gives the same events.
local before = #Scan.DB.analytics.open.events
assert(Log.CloseOpenStore())
assert(#Scan.DB.analytics.stores == 1 and type(Scan.DB.analytics.stores[1].data) == 'string'
    and #Scan.DB.analytics.open.events == 0, 'the store was not packed')
local count = 0
for _, events in ipairs(all()) do count = count + #events end
assert(count == before, 'packed events came back different')
assert(build().totals.crafted == 2, 'the report changed after packing')
-- A range that misses the store does not unpack it.
local unpackedChunks
Log.ReleaseCache()
Log.LoadRange(now + 10 * 86400, math.huge, nil, function(loaded) unpackedChunks = loaded end)
assert(#unpackedChunks == 1, 'a store outside the range was unpacked')

-- The old chat counter becomes mention events once.
Scan.DB.analytics.seen_items = { [7007] = { ppID = 202, times = { now - 5000, { t = now - 4000, customer = 'Old-Realm', c = 2 } } } }
all()
assert(Scan.DB.analytics.seen_items == nil and Log.ProfessionOfItem(7007) == 202, 'the old counter was not moved')
assert(row(build(), 'item:7007').mentions == 2, 'old mentions were lost')
print('Analytics journal passed (retract, packing, ranges, old counter).')

-- Two linked accounts exchange only their own events, in batches, when quiet.
local dbA, dbB = Scan.DB, newDB()
dbB.settings.my_uuid = 'other'
dbA.realm.linked_accounts.other = { permissions = { 1 } }
dbB.realm.linked_accounts.me = { permissions = { 1 } }
local outbox = {}
HironCraftScanComm = {
    Permissions = { Full = 1, Analytics = 2 },
    Transmit = function(_, data, operation, target) outbox[#outbox + 1] = { data = data, op = operation, to = target } end,
    FreshTarget = function(_, accountID) return accountID == 'other' and 'CharB' or 'CharA' end,
}
local function as(db, fn) local saved = Scan.DB; Scan.DB = db; fn(); Scan.DB = saved end
local function deliver()
    local guard = 0
    while #outbox > 0 and guard < 100 do
        guard = guard + 1
        local message = table.remove(outbox, 1)
        -- A message to CharB is handled by account B, which knows A as 'me'.
        if message.to == 'CharB' then
            as(dbB, function() Sync.Receive(message.op, 'CharA', message.data, 'me') end)
        else
            as(dbA, function() Sync.Receive(message.op, 'CharB', message.data, 'other') end)
        end
    end
end
as(dbB, function()
    side = 'Horde'
    Log.Request('Orc-Realm', { requestToken = 'h1', itemID = 1001, parentProfID = 197, time = now })
    Log.Greeting('Orc-Realm', { requestToken = 'h1' })
    side = 'Alliance'
end)
Sync.BATCH = 2
-- Busy right after that activity: nothing is offered.
clock = clock + 1
as(dbA, function() Sync.Tick() end)
assert(#outbox == 0, 'analytics was offered while busy')
clock = clock + Log.QUIET_SECONDS + 1
as(dbA, function() Sync.Tick() end)
assert(#outbox == 1 and outbox[1].op == 'an_offer', 'nothing was offered in a quiet period')
deliver()
local mergedA, mergedB = 0, 0
local function countMerged(db, source)
    local n = 0
    as(db, function()
        for _, events in ipairs(all()) do
            for _, event in ipairs(events) do if event.m == source then n = n + 1 end end
        end
    end)
    return n
end
mergedB = countMerged(dbB, 'me')
mergedA = countMerged(dbA, 'other')
local ownA
as(dbA, function() ownA = select(2, Log.OwnSince(0)) end)
assert(mergedB > 0 and dbB.realm.linked_accounts.me.analytics_received == ownA,
    'account B did not get all of A in batches: ' .. mergedB .. ' / ' .. tostring(dbB.realm.linked_accounts.me.analytics_received))
assert(mergedA == 2 and dbA.realm.linked_accounts.other.analytics_received == 2, 'account A did not get B')
-- Order results reach a fully linked account through the order journal, not twice.
as(dbB, function()
    for _, events in ipairs(all()) do
        for _, event in ipairs(events) do
            assert(not (event.m == 'me' and event.k == 'd'), 'an order result was sent twice')
        end
    end
end)
-- Both now show the Horde conversation, and nothing twice.
as(dbA, function()
    local combined = build()
    assert(combined.totals.requests == 5 and combined.totals.greetings == 5, 'the combined picture is off')
    assert(build({ side = 'H' }).totals.greetings == 1, 'the Horde greeting lost its side')
end)
-- Received events are not sent back; a second round sends nothing new.
Sync.OFFER_INTERVAL = 0
as(dbB, function() Sync.Tick() end)
deliver()
assert(countMerged(dbA, 'other') == 2 and countMerged(dbB, 'me') == mergedB, 'events were exchanged twice')
-- A peer that got busy in the middle stops pulling; "exchange now" does not wait.
as(dbA, function() Log.Request('New-Realm', { requestToken = 'n1', itemID = 1001, time = now }) end)
as(dbB, function() Log.NoteActivity() end)
as(dbA, function() Sync.Tick() end)
deliver()
assert(countMerged(dbB, 'me') == mergedB, 'a busy account pulled analytics')
as(dbA, function() Sync.SyncNow() end)
deliver()
assert(countMerged(dbB, 'me') == mergedB + 1, 'exchange now did not go through')
-- An analytics-only account gets the order results through this exchange.
dbB.realm.linked_accounts.me.analytics_received = 0
dbA.realm.linked_accounts.other.permissions = { 2 }
as(dbB, function() Scan.DB.analytics = { stores = {}, open = { events = {} }, seq = dbB.analytics.seq } end)

as(dbA, function() Sync.SyncNow() end)
deliver()
local results = 0
as(dbB, function()
    for _, events in ipairs(all()) do
        for _, event in ipairs(events) do if event.m == 'me' and event.k == 'd' then results = results + 1 end end
    end
end)
assert(results > 0, 'an analytics-only account got no order results')
print('Analytics exchange passed (quiet only, batches, both ways, no echo, busy peer, exchange now, order results).')

-- Dates for the window.
local from = Report.ParseDate('25.09.2026')
assert(os.date('%d.%m.%Y %H:%M', from) == '25.09.2026 00:00')
assert(os.date('%H:%M:%S', Report.ParseDate('25.09', true)) == '23:59:59')
assert(not Report.ParseDate('31.13.2026') and not Report.ParseDate('abc'))
local today = Report.Range('today')
assert(os.date('%H:%M', today) == '00:00' and select(2, Report.Range('today')) == now)
assert(Report.Range('all') == 0)
print('Analytics dates passed.')

-- The first login with the journal takes in what is still kept elsewhere.
Scan.DB = newDB()
Scan.DB.settings.order_completion_notices = {
    ['a'] = { orderID = 70, status = 'fulfilled', customerName = 'Kept', itemID = 5005, updatedAt = now - 100, origin = 'me' },
    ['b'] = { orderID = 71, status = 'fulfilled', customerName = 'Kept', itemID = 5005, updatedAt = now - 90, origin = 'other' },
}
local keptResponse = { requestToken = 'k1', itemID = 5005, parentProfID = 197, time = now - 200,
    greeting_sent = true, greetingSentAt = now - 190, conversationFaction = 'Horde' }
Scan.DB.customers = { ['Kept-Realm'] = { responses = { [5005] = keptResponse, [197] = keptResponse,
    ['order:72'] = { requestToken = 'order:72', time = now } } } }
Scan.DB.realm.order_statuses = { row = { requestToken = 'k1', craftingOrderID = 70, status = 'fulfilled', updatedAt = now - 100 } }
assert(Log.Backfill() and not Log.Backfill(), 'the backfill did not run exactly once')
report = build()
assert(report.totals.requests == 1 and report.totals.greetings == 1 and report.totals.crafted == 1
    and report.totals.orders == 2, 'the backfill missed something')
assert(build({ side = 'H' }).totals.greetings == 1, 'the backfill lost the conversation side')
local own = 0
for _, event in ipairs(Scan.DB.analytics.open.events) do if event.q then own = own + 1 end end
assert(own == 4, 'a received result was taken in as our own: ' .. own)
print('Analytics backfill passed.')

-- Switched off in the old opt-in days: on once, then a later untick stays.
Scan.DB = newDB()
Scan.DB.analytics.enabled = false
Log.Startup()
assert(Log.IsEnabled() and Scan.DB.analytics.default_on == 1, 'gathering was not switched on by default')
Log.SetEnabled(false)
Log.Startup()
assert(not Log.IsEnabled(), 'an untick by hand did not stay')
print('Analytics default on passed.')

-- Once: silver for customers whose delivered orders carry no tip.
Scan.DB = newDB()
Scan.DB.analytics.default_on = 1
Scan.DB.settings.order_completion_notices = {
    a = { orderID = 1, status = 'fulfilled', customerName = 'Early-Realm', updatedAt = now },
    b = { orderID = 2, status = 'fulfilled', customerName = 'Tipped-Realm', tipAmount = 100, updatedAt = now },
    c = { orderID = 3, status = 'rejected', customerName = 'Refused-Realm', updatedAt = now },
}
local marked = {}
Scan.Generous = { MarkUntipped = function(names) for _, name in ipairs(names) do marked[name] = true end end }
Log.Startup()
assert(marked['Early-Realm'] and not marked['Tipped-Realm'] and not marked['Refused-Realm'],
    'the wrong customers were marked silver')
marked = {}
Log.Startup()
assert(not next(marked), 'the silver marking ran twice')
Scan.Generous = nil
print('Analytics untipped silver passed.')

-- The same request seen by two linked accounts is one conversation: the
-- crafter's PC and the collector see the same chat line.
Scan.DB = newDB()
Log.Request('Twice-Realm', { requestToken = 'pc1', itemID = 6006, parentProfID = 164, time = now })
Log.Merge({
    { k = 'r', t = now + 20, id = 'lap1', c = 'Twice-Realm', i = 6006, p = 164, f = 'A' },
    { k = 'g', t = now + 40, id = 'lap1', c = 'Twice-Realm', f = 'A' },
    { k = 'l', t = now + 900, id = 'lap1', o = 900, st = 'f' },
}, 'laptop')
Log.Outcome({ orderID = 900, status = 'fulfilled', customerName = 'Twice', itemID = 6006,
    parentProfessionID = 164, updatedAt = now + 900 })
report = build()
assert(report.totals.requests == 1 and report.totals.greetings == 1 and report.totals.crafted == 1,
    'one request seen by two accounts was counted twice or lost its greeting')
-- The same account seeing it asked again an hour later: a new request.
Log.Request('Twice-Realm', { requestToken = 'pc2', itemID = 6006, parentProfID = 164, time = now + 3600 })
assert(build().totals.requests == 2, 'a later request was merged into the old one')
print('Analytics cross-account requests passed.')

-- "Exchange now" says in chat how it went.
local said, timers = {}, {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) said[#said + 1] = text end }
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
-- Silence is explained: offline, an old version, or simply no answer.
local heard = nil
HironCraftScanComm.LastHeard = function() return heard end
local function Silent(expected)
    said, timers = {}, {}
    as(dbA, function() Sync.SyncNow() end)
    outbox = {}
    for _, fn in ipairs(timers) do as(dbA, fn) end
    assert(said[#said]:find(expected, 1, true), 'expected "' .. expected .. '", got: ' .. tostring(said[#said]))
end
Silent('is not online')
heard = now
dbA.realm.linked_accounts.other.addon_version = 'old'
Silent('older than 0.4.45')
dbA.realm.linked_accounts.other.addon_version = '0.4.40'
Silent('runs HironCraft 0.4.40')
dbA.realm.linked_accounts.other.addon_version = '0.4.45'
Silent('did not answer')
assert(Sync.Older('0.4.9', '0.4.41') and not Sync.Older('0.4.41', '0.4.41') and not Sync.Older('0.5', '0.4.41')
    and Sync.Older('old', '0.4.41'))
-- Gathering switched off over there: it says so instead of keeping quiet.
said, timers = {}, {}
dbB.analytics.enabled = false
as(dbA, function() Sync.SyncNow() end)
deliver()
local off = false
for _, line in ipairs(said) do if line:find('gathering is off on other', 1, true) then off = true end end
assert(off, 'a switched-off account was not reported: ' .. table.concat(said, ' | '))
dbB.analytics.enabled = nil
said, timers = {}, {}
as(dbB, function() Log.Request('Bee-Realm', { requestToken = 'b9', itemID = 1001, time = now }) end)
as(dbA, function() Sync.SyncNow() end)
deliver()
for _, fn in ipairs(timers) do as(dbA, fn) end
local reported = false
for _, line in ipairs(said) do
    assert(not line:find('did not answer', 1, true), 'an account that answered was reported silent')
    if line:find('1 new events from other', 1, true) then reported = true end
end
assert(reported, 'the result of the exchange was not reported: ' .. table.concat(said, ' | '))
DEFAULT_CHAT_FRAME, C_Timer = nil, nil
print('Analytics exchange report passed.')
