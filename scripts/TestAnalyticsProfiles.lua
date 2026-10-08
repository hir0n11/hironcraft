-- Crafter pool profiles: who is recorded, how events are attributed, and what
-- the report counts for one profile.
local now = os.time({ year = 2026, month = 10, day = 4, hour = 12 })
function time(t) if t then return os.time(t) end return now end
date = os.date
local clock = 1000
function GetTime() return clock end
function InCombatLockdown() return false end
function UnitFactionGroup() return 'Horde' end
function GetNormalizedRealmName() return 'Draenor' end
strmatch = string.match
assert(loadfile('Workflow/Core/Libs/LibStub/LibStub.lua'))()
assert(loadfile('Libs/LibSerialize.lua'))()
assert(loadfile('Libs/LibDeflate.lua'))()

local player = 'Smith-Draenor'
local function newDB()
    return {
        analytics = {}, settings = { my_uuid = 'abcdef12-3456' }, customers = {},
        characters = { ['Smith-Draenor'] = {}, ['Tailor-Draenor'] = {} },
        realm = { linked_accounts = {
            second = { nickname = 'Second', last_active_char = 'Scout-Draenor', backup_chars = { 'Scout-Draenor', 'Spare-Draenor' } },
            elsewhere = { nickname = 'Far', last_active_char = 'Stranger-Silvermoon' },
        } },
    }
end
local Scan = { DB = newDB(), Utils = {}, State = { realmNames = { 'Draenor', 'Frostwhisper' } } }
function Scan.GetPlayerName() return player end
local function load(path) assert(loadfile(path))('HironCraft', Scan) end
load('Customer/AnalyticsLog.lua')
load('Customer/AnalyticsReport.lua')
load('Customer/AnalyticsProfiles.lua')
function Scan.Utils.Contains(list, value)
    for _, entry in ipairs(list or {}) do if entry == value then return true end end
    return false
end
load('Customer/AnalyticsSync.lua')
local Log, Report, Profiles, Sync = Scan.AnalyticsLog, Scan.AnalyticsReport, Scan.AnalyticsProfiles, Scan.AnalyticsSync
Log.synchronous = true

local function eq(actual, expected, what)
    if actual ~= expected then
        error((what or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
    end
end
local function chunks()
    local loaded
    Log.LoadRange(0, math.huge, nil, function(result) loaded = result end)
    return loaded
end
local function events()
    local list = {}
    for _, chunk in ipairs(chunks()) do
        for _, event in ipairs(chunk) do list[#list + 1] = event end
    end
    return list
end
local changes = 0
Profiles.OnChange(function() changes = changes + 1 end)

-- No profiles: as it always was -------------------------------------------------

eq(Profiles.Any(), false, 'no profiles to begin with')
eq(Profiles.Current(), 'Smith-Draenor', 'the player')
eq(Profiles.MayRecord(), true, 'everyone records without profiles')
eq(Profiles.Filter(nil), nil, 'nothing to filter by')
eq(Profiles.Filter('nope'), nil, 'an unknown profile counts everything')
Log.Request('Buyer-Draenor', { requestToken = 't1', itemID = 1, parentProfID = 164, time = now - 500 })
local first = Scan.DB.analytics.open.events[1]
eq(first.w, 'Smith-Draenor', 'events name who recorded them')
assert(Scan.DB.analytics.recorders['Smith-Draenor'], 'the recorder is remembered')

-- Realms -----------------------------------------------------------------------

eq(Profiles.IsLocal('Any-Draenor'), true, 'own realm')
eq(Profiles.IsLocal('Any-Frostwhisper'), true, 'connected realm')
eq(Profiles.IsLocal('Any-Silvermoon'), false, 'another realm')
eq(Profiles.IsLocal('NoRealm'), true, 'no realm in the name')
eq(Profiles.IsLocal(nil), true, 'nothing to judge')
eq(Profiles.FullName('  scout '), 'scout-Draenor', 'the player\'s realm is added')
eq(Profiles.FullName('Scout-Twisting Nether'), 'Scout-TwistingNether', 'realm as the game writes it')
eq(Profiles.FullName('   '), nil, 'nothing typed')
eq(Profiles.DisplayName('Scout-Draenor'), 'Scout', 'own realm is not shown')
eq(Profiles.DisplayName('Scout-Frostwhisper'), 'Scout-Frostwhisper', 'another realm is')

-- Candidates: crafters, linked accounts' characters, recorders, the player; only local ones.
do
    local list = table.concat(Profiles.Candidates(), ',')
    eq(list, 'Scout-Draenor,Smith-Draenor,Spare-Draenor,Tailor-Draenor', 'candidates')
end

-- The first profile ------------------------------------------------------------

eq(Profiles.Create('   '), nil, 'a profile needs a name')
local pool = Profiles.Create('  Draenor pool ')
assert(pool and Profiles.Any(), 'profile created')
eq(pool.name, 'Draenor pool', 'trimmed name')
eq(pool.id, 'abcdef12:1', 'id from the account and a counter')
eq(Profiles.IsLegacy(pool), true, 'the first profile takes the earlier history')
assert(pool.n == 1 and pool.by == 'abcdef12-3456', 'a change is stamped with the clock and the account')
for _, name in ipairs({ 'Scout-Draenor', 'Smith-Draenor', 'Spare-Draenor', 'Tailor-Draenor' }) do
    assert(Profiles.Has(pool, name), name .. ' starts in the first profile')
end
eq(Profiles.Get(pool.id), pool, 'found by id')
eq(Profiles.MayRecord(), true, 'a member records')
assert(changes > 0, 'listeners hear about changes')

-- A character outside every profile records nothing.
player = 'Main-Draenor'
Scan.GetPlayerName = function() return player end
-- (Current is fixed for the session; ask about the other character directly.)
eq(Profiles.MayRecord('Main-Draenor'), false, 'an outsider does not record')
eq(Profiles.MayRecord('Tailor-Draenor'), true, 'a member does')

-- Recording through the journal follows the gate.
do
    local before = #Scan.DB.analytics.open.events
    Profiles.SetMember(pool.id, 'Smith-Draenor', false)
    eq(Profiles.MayRecord(), false, 'the player left the profile')
    Log.Request('Buyer-Draenor', { requestToken = 't2', itemID = 2, parentProfID = 164, time = now - 400 })
    Log.Greeting('Buyer-Draenor', { requestToken = 't2' }, now - 390)
    Log.Outcome({ orderID = 5, status = 'fulfilled', customerName = 'Buyer', itemID = 2, updatedAt = now - 380 })
    eq(#Scan.DB.analytics.open.events, before, 'nothing recorded outside the profiles')
    eq(Log.NotePresence(now - 370), nil, 'no time online either')
    eq(Scan.DB.analytics.presencePending, nil, 'no pending presence')
    -- What a linked account sends is still kept.
    eq(Log.Merge({ { k = 'r', t = now - 360, id = 'peer1', c = 'Other-Draenor', w = 'Scout-Draenor' } }, 'second'), 1,
        'linked events are merged')
    eq(#Scan.DB.analytics.open.events, before + 1, 'and stored')
    eq(Scan.DB.analytics.open.events[before + 1].w, 'Scout-Draenor', 'with their own recorder')
    -- An order result relayed by a linked account's order journal as well.
    Log.Outcome({ orderID = 6, status = 'fulfilled', customerName = 'Buyer', itemID = 2, updatedAt = now - 350,
        crafterFullName = 'Tailor-Draenor' }, 'notice')
    eq(#Scan.DB.analytics.open.events, before + 2, 'relayed results are stored')
    Profiles.SetMember(pool.id, 'Smith-Draenor', true)
    eq(Profiles.MayRecord(), true, 'back in the profile')
    Log.Request('Buyer-Draenor', { requestToken = 't3', itemID = 3, parentProfID = 164, time = now - 340 })
    eq(#Scan.DB.analytics.open.events, before + 3, 'recording again')
end

-- Time online: counted on a member, stopped and kept when the character leaves.
do
    Scan.DB.analytics.presencePending = nil
    Log.NotePresence(now - 300)
    Log.NotePresence(now - 270)
    local pending = Scan.DB.analytics.presencePending
    assert(pending and pending.w == 'Smith-Draenor' and pending.e - pending.t == 30, 'presence names its character')
    -- The window sees the unfinished interval with its character.
    local last = chunks()
    eq(last[#last][1].w, 'Smith-Draenor', 'pending presence carries the recorder')
    local before = #Scan.DB.analytics.open.events
    Profiles.SetMember(pool.id, 'Smith-Draenor', false)
    Log.NotePresence(now - 240)
    eq(Scan.DB.analytics.presencePending, nil, 'presence stops outside the profiles')
    eq(#Scan.DB.analytics.open.events, before + 1, 'what was counted is kept')
    local kept = Scan.DB.analytics.open.events[before + 1]
    assert(kept.k == 'p' and kept.w == 'Smith-Draenor' and kept.e - kept.t == 30, 'with its character and length')
    Profiles.SetMember(pool.id, 'Smith-Draenor', true)
end

-- Counting one profile -----------------------------------------------------------

local function fresh()
    Scan.DB = newDB()
    Log.ReleaseCache()
    return Log.Root()
end
do
    local root = fresh()
    local A, B = 'Smith-Draenor', 'Scout-Draenor'
    root.open.events = {
        -- Recorded by A: a request that ended in an order.
        { k = 'r', t = now - 900, id = 'a1', c = 'One-Draenor', i = 11, p = 164, w = A },
        { k = 'g', t = now - 890, id = 'a1', c = 'One-Draenor', w = A },
        { k = 'd', t = now - 800, o = 1, st = 'f', c = 'One', i = 11, p = 164, x = A, tip = 50000, id = 'a1', w = A },
        { k = 'l', t = now - 800, id = 'a1', o = 1, st = 'f', w = A },
        { k = 'p', t = now - 1000, e = now - 700, f = 'H', w = A },
        -- Recorded by B.
        { k = 'r', t = now - 600, id = 'b1', c = 'Two-Draenor', i = 12, p = 164, w = B, m = 'second' },
        { k = 'g', t = now - 590, id = 'b1', c = 'Two-Draenor', w = B, m = 'second' },
        { k = 'p', t = now - 650, e = now - 500, f = 'H', w = B, m = 'second' },
        -- From before recorders were kept.
        { k = 'r', t = now - 400, id = 'old1', c = 'Three-Draenor', i = 13, p = 164 },
        { k = 'd', t = now - 300, o = 2, st = 'f', c = 'Three', i = 13, p = 164, x = B, tip = 10000 },
        { k = 'c', t = now - 300, o = 2, x = B, p = 164, pr = 1, rs = { { i = 99, n = 1, v = 100, c = 1 } } },
        { k = 'c', t = now - 290, o = 3, x = 'Nobody-Draenor', p = 164 },
        { k = 'p', t = now - 200, e = now - 140, f = 'H' },
    }
    local all = chunks()
    local function build(profile) return Report.Build(all, { from = 0, to = now, profile = profile }, {}) end
    local function returns(profile) return Report.BuildReturns(all, { from = 0, to = now, profile = profile }) end

    local everything = build(nil)
    eq(everything.totals.requests, 3, 'all requests')
    eq(everything.totals.orders, 2, 'all orders')
    eq(returns(nil).totals.crafts, 2, 'all crafts')

    -- Only A, and the earlier history.
    local onlyA = build({ chars = { [A] = true }, legacy = true })
    eq(onlyA.totals.requests, 2, 'A: its own request and the old one')
    eq(onlyA.totals.greetings, 1, 'A: its greeting')
    eq(onlyA.totals.orders, 1, 'A: its order; the old order goes by its crafter B')
    eq(onlyA.totals.tips, 50000, 'A: its tips')
    eq(math.floor(onlyA.totals.online + 0.5), 6, 'A: its 5 minutes and the old minute')
    eq(returns({ chars = { [A] = true }, legacy = true }).totals.crafts, 0, 'A: old crafts go by their crafter')

    -- Only B, without the earlier history.
    local onlyB = build({ chars = { [B] = true }, legacy = false })
    eq(onlyB.totals.requests, 1, 'B: its request')
    eq(onlyB.totals.greetings, 1, 'B: its greeting')
    eq(onlyB.totals.orders, 1, 'B: the old order it crafted')
    eq(onlyB.totals.tips, 10000, 'B: that order\'s tips')
    eq(math.floor(onlyB.totals.online * 60 + 0.5), 150, 'B: its 150 seconds')
    eq(returns({ chars = { [B] = true }, legacy = false }).totals.crafts, 1, 'B: its old craft')

    -- A profile of nobody.
    local nobody = build({ chars = {}, legacy = false })
    eq(nobody.totals.requests, 0, 'nobody: no requests')
    eq(nobody.totals.orders, 0, 'nobody: no orders')
    eq(nobody.totals.online or 0, 0, 'nobody: no time online')

    -- Through the profile module.
    local pool2 = Profiles.Create('Pool')
    Profiles.SetMember(pool2.id, B, false)
    local filter = Profiles.Filter(pool2.id)
    eq(filter.legacy, true, 'first profile is the legacy one')
    eq(build(filter).totals.orders, 1, 'B was unticked')
end

-- Several profiles ---------------------------------------------------------------

do
    fresh()
    changes = 0
    local one = Profiles.Create('One')
    local two = Profiles.Create('Two')
    eq(Profiles.IsLegacy(two), false, 'later profiles do not take the earlier history')
    eq(Profiles.IsLegacy(one), true, 'the oldest one does')
    eq(next(two.chars), nil, 'and start empty')
    eq(two.id, 'abcdef12:2', 'ids go on')
    Profiles.SetMember(two.id, 'Main-Draenor', true)
    eq(Profiles.MayRecord('Main-Draenor'), true, 'a member of any profile records')
    assert(Profiles.Rename(two.id, ' Second '), 'renamed')
    eq(Profiles.Get(two.id).name, 'Second', 'new name')
    eq(Profiles.Rename(two.id, ''), false, 'not to nothing')
    eq(Profiles.Rename('nope', 'x'), false, 'unknown profile')
    -- A member from another realm stays listed so it can be unticked.
    Profiles.SetMember(two.id, 'Guest-Silvermoon', true)
    assert(table.concat(Profiles.Candidates(), ','):find('Guest-Silvermoon', 1, true), 'members are always candidates')
    -- Deleting the legacy profile hands the earlier history to the next one.
    assert(Profiles.Delete(one.id), 'deleted')
    eq(#Profiles.List(), 1, 'one profile left')
    eq(Profiles.IsLegacy(Profiles.Get(two.id)), true, 'the history moved on')
    eq(Profiles.Delete(one.id), false, 'not twice')
    assert(Profiles.Delete(two.id), 'deleted the last one')
    eq(Profiles.Any(), false, 'no profiles')
    eq(Profiles.MayRecord('Main-Draenor'), true, 'everyone records again')
    assert(changes >= 7, 'every change was announced')
    -- Ids are never reused.
    eq(Profiles.Create('Third').id, 'abcdef12:3', 'ids are not reused')
end

-- Another realm's orders stay out of a new journal ---------------------------------

do
    fresh()
    Scan.DB.settings.order_completion_notices = {
        { orderID = 10, status = 'fulfilled', customerName = 'Local', crafterFullName = 'Smith-Draenor', updatedAt = now - 100 },
        { orderID = 11, status = 'fulfilled', customerName = 'Far', crafterFullName = 'Vamo-Kazzak', updatedAt = now - 90 },
        { orderID = 12, status = 'fulfilled', customerName = 'Connected', crafterFullName = 'Alt-Frostwhisper', updatedAt = now - 80 },
        { orderID = 13, status = 'rejected', customerName = 'Unknown', updatedAt = now - 70 },
    }
    assert(Log.Backfill(), 'backfilled')
    local orders = {}
    for _, event in ipairs(events()) do
        if event.k == 'd' then orders[event.o] = true end
    end
    assert(orders[10] and orders[12] and orders[13], 'this realm\'s orders were taken')
    eq(orders[11], nil, 'another realm\'s order was not')
end

-- Sharing with linked accounts ----------------------------------------------------

do
    local dbA, dbB = newDB(), newDB()
    dbA.settings.my_uuid, dbB.settings.my_uuid = 'aaaaaaaa-1', 'bbbbbbbb-2'
    dbA.realm.linked_accounts = { ['bbbbbbbb-2'] = { permissions = { 1 }, last_active_char = 'Scout-Draenor' } }
    dbB.realm.linked_accounts = { ['aaaaaaaa-1'] = { permissions = { 2 }, last_active_char = 'Smith-Draenor' } }
    local outbox, online = {}, true
    HironCraftScanComm = {
        Permissions = { Full = 1, Analytics = 2 },
        Transmit = function(_, data, operation, target) outbox[#outbox + 1] = { data = data, op = operation, to = target } end,
        FreshTarget = function(_, accountID)
            if not online then return nil end
            return accountID == 'bbbbbbbb-2' and 'CharB' or 'CharA'
        end,
    }
    local function as(db, fn) local saved = Scan.DB; Scan.DB = db; Log.ReleaseCache(); fn(); Scan.DB = saved end
    local function deliver()
        local guard = 0
        while #outbox > 0 do
            guard = guard + 1
            assert(guard < 50, 'the accounts keep answering each other')
            local message = table.remove(outbox, 1)
            if message.to == 'CharB' then
                as(dbB, function() Sync.Receive(message.op, 'CharA', message.data, 'aaaaaaaa-1') end)
            else
                as(dbA, function() Sync.Receive(message.op, 'CharB', message.data, 'bbbbbbbb-2') end)
            end
        end
    end
    local function names(db)
        local list = {}
        as(db, function()
            for _, profile in ipairs(Profiles.List()) do
                list[#list + 1] = profile.name .. '=' .. table.concat(Profiles.Members(profile), '+')
            end
        end)
        return table.concat(list, ' | ')
    end

    -- Both are busy (nobody is quiet): a new profile still reaches the other account at once.
    local id
    as(dbA, function() id = Profiles.Create('Pool').id end)
    assert(#outbox == 1 and outbox[1].op == 'an_offer' and outbox[1].data.profiles, 'a new profile was not sent')
    eq(outbox[1].data.profiles.realm, 'Draenor', 'profiles name their realm')
    deliver()
    eq(names(dbB), 'Pool=Scout-Draenor+Smith-Draenor+Tailor-Draenor', 'the other account has the profile')
    as(dbB, function()
        eq(Profiles.Get(id).by, 'aaaaaaaa-1', 'with its stamp')
        eq(Profiles.MayRecord('Main-Draenor'), false, 'and stops recording outside it')
        eq(Profiles.MayRecord('Scout-Draenor'), true, 'while its members record')
    end)
    eq(#outbox, 0, 'what was received is not sent on')

    -- A change over there comes back.
    as(dbB, function() Profiles.SetMember(id, 'Tailor-Draenor', false) end)
    deliver()
    eq(names(dbA), 'Pool=Scout-Draenor+Smith-Draenor', 'a change made on the other account arrived')

    -- Up to date: the minute tick sends nothing, busy or not.
    as(dbA, function() Sync.Tick() end)
    as(dbB, function() Sync.Tick() end)
    deliver()
    as(dbA, function() Sync.Tick() end)
    eq(#outbox, 0, 'profiles were sent again without a change')

    -- Offline: nothing is sent now. Once the account is back, the next tick
    -- brings it up to date without waiting for a quiet moment.
    online = false
    as(dbA, function() Profiles.Rename(id, 'Main pool') end)
    as(dbA, function() Sync.Tick() end)
    eq(#outbox, 0, 'sent to an account that is not online')
    online = true
    as(dbA, function() Sync.Tick() end)
    assert(#outbox == 1 and outbox[1].data.profiles, 'the account that came back was not brought up to date')
    deliver()
    eq(names(dbB), 'Main pool=Scout-Draenor+Smith-Draenor', 'the tick carried the profiles')
    as(dbA, function() Sync.Tick() end)
    as(dbB, function() Sync.Tick() end)
    deliver()
    as(dbA, function() Sync.Tick() end)
    as(dbB, function() Sync.Tick() end)
    eq(#outbox, 0, 'the accounts keep telling each other the same thing')

    -- Both changed it while apart: the later change wins on both, whoever speaks first.
    online = false
    as(dbA, function() Profiles.Rename(id, 'From A') end)
    as(dbB, function() Profiles.Rename(id, 'From B') Profiles.SetMember(id, 'Main-Draenor', true) end)
    online = true
    as(dbA, function() Sync.PushProfiles() end)
    deliver()
    as(dbB, function() Sync.PushProfiles() end)
    deliver()
    eq(names(dbA), names(dbB), 'the accounts agree')
    eq(names(dbA), 'From B=Main-Draenor+Scout-Draenor+Smith-Draenor', 'on the later change')
    -- Changed the same number of times: the same side wins on both.
    online = false
    as(dbA, function() Profiles.Rename(id, 'Tie A') end)
    as(dbB, function() Profiles.Rename(id, 'Tie B') end)
    online = true
    as(dbB, function() Sync.PushProfiles() end)
    deliver()
    as(dbA, function() Sync.PushProfiles() end)
    deliver()
    eq(names(dbA), names(dbB), 'a tie is settled the same way on both')

    -- A deleted profile stays deleted, also when an account that missed it speaks up.
    local stale
    as(dbB, function() stale = Profiles.Export() end)
    online = false
    as(dbA, function() Profiles.Delete(id) end)
    as(dbA, function() eq(Profiles.Merge(stale), false, 'an old copy brought a deleted profile back') end)
    eq(names(dbA), '', 'still deleted')
    online = true
    as(dbA, function() Sync.PushProfiles() end)
    deliver()
    eq(names(dbB), '', 'deleted on the other account too')
    as(dbB, function() eq(Profiles.MayRecord('Main-Draenor'), true, 'everyone records again there') end)
    -- Told twice, nothing happens twice.
    as(dbA, function() eq(Profiles.Merge(Profiles.Export()), false, 'the same state changed something') end)

    -- Each account had made its own first profile before they were shared:
    -- both stay, and the older one takes the earlier history on both accounts.
    local old, young
    as(dbA, function() old = Profiles.Create('Mine') old.at, old.n = now - 500, nil end)
    as(dbB, function() young = Profiles.Create('Theirs') young.at = now - 100 end)
    outbox = {}
    as(dbA, function() Sync.PushProfiles() end)
    deliver()
    as(dbB, function() Sync.PushProfiles() end)
    deliver()
    eq(names(dbA), names(dbB), 'both first profiles are on both accounts')
    as(dbA, function()
        eq(#Profiles.List(), 2, 'two profiles')
        eq(Profiles.List()[1].name, 'Mine', 'oldest first')
        assert(old.n, 'a profile from before sharing got its stamp')
        eq(Profiles.Filter(old.id).legacy, true, 'the older one takes the earlier history')
        eq(Profiles.Filter(young.id).legacy, false, 'the younger one does not')
    end)
    as(dbB, function()
        eq(Profiles.Filter(old.id).legacy, true, 'the same on the other account')
        eq(Profiles.Filter(young.id).legacy, false, 'for both profiles')
    end)

    -- Another realm's profiles are not for this journal; nonsense is ignored.
    as(dbA, function()
        local before = names(dbA)
        eq(Profiles.Merge({ realm = 'Silvermoon', list = { { id = 'x:1', name = 'Far', chars = {}, n = 99, by = 'x' } } }), false,
            'another realm\'s profile was taken')
        eq(Profiles.Merge(nil), false, 'nothing')
        eq(Profiles.Merge({ list = { 5, { id = 7 }, { id = 'y:1', name = '  ', chars = {}, n = 1 }, { id = 'y:2', name = 'No stamp', chars = {} } },
            gone = { 'x', { id = 9 } } }), false, 'nonsense')
        eq(names(dbA), before, 'nothing changed')
        -- A connected realm is this journal's realm.
        eq(Profiles.Merge({ realm = 'Frostwhisper', list = { { id = 'z:1', name = 'Connected', chars = { 'Alt-Frostwhisper' }, n = 1, by = 'z', at = now } } }),
            true, 'a connected realm\'s profile was refused')
    end)

    -- Several ticks in a row go out as one message.
    local timers = {}
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
    outbox = {}
    as(dbA, function()
        Profiles.SetMember(old.id, 'One-Draenor', true)
        Profiles.SetMember(old.id, 'Two-Draenor', true)
        Profiles.SetMember(old.id, 'Three-Draenor', true)
    end)
    eq(#timers, 1, 'one send is waiting')
    eq(#outbox, 0, 'nothing sent before the pause is over')
    as(dbA, function() timers[1]() end)
    eq(#outbox, 1, 'one message for three ticks')
    C_Timer = nil
    HironCraftScanComm = nil
end

print('Analytics profiles passed (gate, recorders, presence, attribution, legacy history, editing, realms, backfill, sharing).')
