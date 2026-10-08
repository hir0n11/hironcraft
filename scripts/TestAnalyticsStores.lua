-- The analytics journal's packed stores: the cache that outlives the window,
-- the game's own encoder with the Lua libraries as fallback, and the removal
-- of the mention events that are no longer counted.
local now = os.time({ year = 2026, month = 10, day = 4, hour = 12 })
function time(t) if t then return os.time(t) end return now end
date = os.date
function GetTime() return 1000 end
function InCombatLockdown() return false end
function UnitFactionGroup() return 'Horde' end
strmatch = string.match
assert(loadfile('Workflow/Core/Libs/LibStub/LibStub.lua'))()
assert(loadfile('Libs/LibSerialize.lua'))()
assert(loadfile('Libs/LibDeflate.lua'))()
local LibSerialize, LibDeflate = LibStub('LibSerialize'), LibStub('LibDeflate')

local function newDB() return { analytics = {}, settings = {}, realm = { linked_accounts = {} } } end
local Scan = { DB = newDB(), Utils = {} }
assert(loadfile('Customer/AnalyticsLog.lua'))('HironCraft', Scan)
local Log = Scan.AnalyticsLog
Log.synchronous = true

local function eq(actual, expected, what)
    if actual ~= expected then
        error((what or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
    end
end
local function fresh()
    Scan.DB = newDB()
    Log.ReleaseCache()
    return Log.Root()
end
local function load(from, to)
    local chunks
    Log.LoadRange(from or 0, to or math.huge, nil, function(loaded) chunks = loaded end)
    return chunks
end
local function count(chunks)
    local total = 0
    for _, events in ipairs(chunks) do total = total + #events end
    return total
end
local function libraryPack(events)
    return LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(LibSerialize:Serialize(events)))
end

-- Library unpacking is counted through the inflate call it cannot avoid.
local libraryUnpacks = 0
local inflate = LibDeflate.DecompressDeflate
function LibDeflate:DecompressDeflate(...) libraryUnpacks = libraryUnpacks + 1 return inflate(self, ...) end

-- A stand-in for the game's encoder: different text at every stage, so what
-- one side packed cannot be read by the other.
local native = { packs = 0, unpacks = 0 }
local function nativeAPI()
    return {
        SerializeCBOR = function(value) native.packs = native.packs + 1 return 'CBOR' .. LibSerialize:Serialize(value) end,
        DeserializeCBOR = function(text)
            native.unpacks = native.unpacks + 1
            assert(text:sub(1, 4) == 'CBOR', 'not CBOR')
            local ok, value = LibSerialize:Deserialize(text:sub(5))
            assert(ok, 'broken CBOR')
            return value
        end,
        CompressString = function(text) return 'Z' .. text end,
        DecompressString = function(text) assert(text:sub(1, 1) == 'Z', 'not compressed') return text:sub(2) end,
        EncodeBase64 = function(text) return 'B64' .. LibDeflate:EncodeForPrint(text) end,
        DecodeBase64 = function(text) assert(text:sub(1, 3) == 'B64', 'not base64') return LibDeflate:DecodeForPrint(text:sub(4)) end,
    }
end

local function request(index, at)
    return { k = 'r', t = at or (now - 1000 + index), id = 't' .. index, c = 'Buyer' .. index, i = 100 + index }
end
local function mention(index, at) return { k = 'm', t = at or (now - 1000 + index), i = 500 + index } end

-- Without the game's encoder ---------------------------------------------------

C_EncodingUtil = nil
local root = fresh()
for index = 1, 3 do Log.Record(request(index)) end
assert(Log.CloseOpenStore())
eq(root.stores[1].f, nil, 'library format without the encoder')
eq(root.stores[1].n, 3, 'store size')
eq(#Log.Decode(root.stores[1].data), 3, 'library data')

-- The cache outlives the window: trimming within the limit unpacks nothing again.
libraryUnpacks = 0
eq(count(load()), 3, 'events read back')
eq(libraryUnpacks, 1, 'unpacked once')
Log.TrimCache()
eq(count(load()), 3, 'events from the cache')
eq(libraryUnpacks, 1, 'the cache was kept')
Log.ReleaseCache()
load()
eq(libraryUnpacks, 2, 'a released cache unpacks again')
eq(root.stores[1].tidy, 1, 'an older store is looked through once')
eq(Log.Root().perf.stores, 1, 'load recorded: stores')
eq(Log.Root().perf.unpacked, 1, 'load recorded: unpacked')
Log.NoteBuild(12.4)
eq(Log.Root().perf.buildMs, 12, 'build time recorded')

-- The least recently used stores go first once the limit is passed.
do
    root = fresh()
    for store = 1, 3 do
        for index = 1, 10 do Log.Record(request(store * 100 + index, now - 5000 + store * 1000 + index)) end
        assert(Log.CloseOpenStore())
    end
    load()
    -- Use the first store again: the second is now the oldest.
    load(root.stores[1].from, root.stores[1].to)
    Log.TrimCache(25)
    libraryUnpacks = 0
    load(root.stores[1].from, root.stores[1].to)
    eq(libraryUnpacks, 0, 'the most recently used store stayed')
    load(root.stores[3].from, root.stores[3].to)
    eq(libraryUnpacks, 0, 'the second most recent stayed')
    load(root.stores[2].from, root.stores[2].to)
    eq(libraryUnpacks, 1, 'the least recently used was let go')
end

-- Mentions ---------------------------------------------------------------------

-- A closing store leaves them out.
root = fresh()
Log.Record(request(1)); Log.Record(mention(2)); Log.Record(request(3))
assert(Log.CloseOpenStore())
eq(root.stores[1].n, 2, 'mentions are not packed')
-- A store of nothing but mentions is not written at all.
Log.Record(mention(4))
assert(Log.CloseOpenStore())
eq(#root.stores, 1, 'no store of mentions')
eq(#root.open.events, 0, 'the open store was cleared')

-- An older store loses them the first time it is unpacked, and is packed again.
root = fresh()
root.stores[1] = { from = now - 900, to = now - 800, n = 4, maxQ = 9,
    data = libraryPack({ request(1), mention(2), mention(3), request(4) }) }
root.stores[2] = { from = now - 700, to = now - 600, n = 2, data = libraryPack({ mention(5), mention(6) }) }
root.stores[3] = { from = now - 500, to = now - 400, n = 1, data = libraryPack({ request(7) }) }
local untouched = root.stores[3].data
local chunks = load()
eq(count(chunks), 3, 'only requests are left')
for _, events in ipairs(chunks) do
    for _, event in ipairs(events) do assert(event.k ~= 'm', 'a mention was loaded') end
end
eq(#Log.Root().stores, 2, 'the store of mentions is gone')
eq(Log.Root().stores[1].n, 2, 'the mixed store shrank')
eq(Log.Root().stores[1].maxQ, 9, 'its sequence mark stayed')
eq(#Log.Decode(Log.Root().stores[1].data), 2, 'it was packed again')
eq(Log.Root().stores[2].data, untouched, 'a store without mentions was not rewritten')
Log.ReleaseCache()
eq(count(load()), 3, 'the same after unpacking again')

-- Mentions from an older HironCraft on a linked account are not taken.
root = fresh()
eq(Log.Merge({ mention(1), request(2), mention(3) }, 'peer'), 1, 'merged without mentions')
eq(#root.open.events, 1, 'one event stored')

-- The old chat counter gives its professions and no events.
root = fresh()
root.seen_items = { [7007] = { ppID = 202, times = { now - 5000, { t = now - 4000 } } }, [7008] = { times = { now } } }
eq(count(load()), 0, 'no events from the old counter')
eq(#root.stores, 0, 'no stores from the old counter')
eq(root.seen_items, nil, 'the old counter is gone')
eq(Log.ProfessionOfItem(7007), 202, 'its professions were kept')
assert(Log.UnknownItems()[7008], 'items without a profession are still to be learned')

-- With the game's encoder ------------------------------------------------------

C_EncodingUtil = nativeAPI()
root = fresh()
for index = 1, 3 do Log.Record(request(index)) end
Log.Record({ k = 'c', t = now - 5, o = 77, x = 'Crafter-Realm', rs = { { i = 9, n = 2, v = 150, s = 'p', c = 1 } } })
assert(Log.CloseOpenStore())
eq(root.stores[1].f, 'n', 'packed by the game')
eq(root.stores[1].data:sub(1, 3), 'B64', 'its text')
libraryUnpacks, native.unpacks = 0, 0
chunks = load()
eq(count(chunks), 4, 'events read back')
eq(chunks[1][4].rs[1].v, 150, 'nested values survive')
eq(libraryUnpacks, 0, 'the libraries were not needed')
eq(native.unpacks, 1, 'unpacked by the game once')
eq(root.stores[1].tidy, nil, 'nothing left to tidy in a new store')

-- The sync and the reagent catalogue read such stores too.
do
    local own = Log.OwnSince(0)
    eq(#own, 4, 'own events from a store packed by the game')
    Log.ReleaseCache()
    local crafts, finished = 0, false
    Log.VisitReturnEvents(function() crafts = crafts + 1 end, function() finished = true end)
    assert(finished and crafts == 1, 'the catalogue saw the craft')
end

-- An older store is repacked by the game the first time it is unpacked.
root = fresh()
root.stores[1] = { from = now - 900, to = now - 800, n = 2, data = libraryPack({ request(1), request(2) }) }
libraryUnpacks = 0
eq(count(load()), 2, 'older store read')
eq(libraryUnpacks, 1, 'by the library, once')
eq(root.stores[1].f, 'n', 'then repacked by the game')
eq(root.stores[1].tidy, nil, 'and done with')
Log.ReleaseCache()
eq(count(load()), 2, 'read again')
eq(libraryUnpacks, 1, 'without the library')

-- An encoder that does not give back what went in is not used.
do
    local lossy = nativeAPI()
    local deserialize = lossy.DeserializeCBOR
    lossy.DeserializeCBOR = function(text)
        local value = deserialize(text)
        if type(value) == 'table' and type(value[1]) == 'table' then value[1].c = nil end
        return value
    end
    C_EncodingUtil = lossy
    root = fresh()
    Log.Record(request(1)); Log.Record(request(2))
    assert(Log.CloseOpenStore())
    eq(root.stores[1].f, nil, 'fell back to the library for a new store')
    root.stores[2] = { from = now - 900, to = now - 800, n = 1, data = libraryPack({ request(3) }) }
    local before = root.stores[2].data
    chunks = load()
    eq(count(chunks), 3, 'everything is still read')
    eq(chunks[1][1].c, 'Buyer1', 'nothing was lost')
    eq(root.stores[2].data, before, 'the older store kept its data')
    eq(root.stores[2].tidy, 1, 'and is not tried again')
end

-- One that throws is not used either.
do
    local broken = nativeAPI()
    broken.CompressString = function() error('no compression today') end
    C_EncodingUtil = broken
    root = fresh()
    Log.Record(request(1))
    assert(Log.CloseOpenStore())
    eq(root.stores[1].f, nil, 'fell back to the library when the encoder fails')
    eq(count(load()), 1, 'and reads it')
end

-- A half-present API is no API.
C_EncodingUtil = { SerializeCBOR = function() return 'x' end }
root = fresh()
Log.Record(request(1))
assert(Log.CloseOpenStore())
eq(root.stores[1].f, nil, 'incomplete encoder ignored')

-- Data that cannot be read is never thrown away.
C_EncodingUtil = nativeAPI()
root = fresh()
Log.Record(request(1))
assert(Log.CloseOpenStore())
local packed = root.stores[1].data
C_EncodingUtil = nil
eq(count(load()), 0, 'unreadable without the encoder')
eq(#root.stores, 1, 'but the store stays')
eq(root.stores[1].data, packed, 'with its data')
eq(root.stores[1].f, 'n', 'and its format')
C_EncodingUtil = nativeAPI()
Log.ReleaseCache()
eq(count(load()), 1, 'readable again with it')

root = fresh()
root.stores[1] = { from = now - 900, to = now - 800, n = 5, data = 'not a store at all' }
eq(count(load()), 0, 'garbage gives no events')
eq(#Log.Root().stores, 1, 'garbage is kept')
eq(Log.Root().stores[1].data, 'not a store at all', 'as it was')

-- The background pass over stores nobody opens ----------------------------------

root = fresh()
root.stores[1] = { from = now - 900, to = now - 800, n = 2, data = libraryPack({ mention(1), mention(2) }) }
root.stores[2] = { from = now - 700, to = now - 600, n = 3, data = libraryPack({ request(3), mention(4), request(5) }) }
root.stores[3] = { from = now - 500, to = now - 400, n = 1, data = 'broken' }
root.stores[4] = { from = now - 300, to = now - 200, n = 1, data = libraryPack({ request(6) }) }
local steps = 0
while Log.TidyStep() do
    steps = steps + 1
    assert(steps < 20, 'the pass does not end')
end
root = Log.Root()
eq(steps, 4, 'one store per step')
eq(root.tidied, 1, 'the pass is finished for good')
eq(#root.stores, 3, 'the store of mentions is gone')
eq(root.stores[1].f, 'n', 'mixed store repacked')
eq(root.stores[1].n, 2, 'without its mention')
eq(root.stores[2].data, 'broken', 'the unreadable store is left alone')
eq(root.stores[3].f, 'n', 'clean store repacked')
libraryUnpacks = 0
eq(count(load()), 3, 'everything readable is read')
eq(libraryUnpacks, 1, 'only the unreadable one still goes to the library')
eq(Log.TidyStep(), false, 'nothing more to do')
-- A store closed later needs no pass.
Log.Record(request(9))
assert(Log.CloseOpenStore())
eq(Log.TidyStep(), false, 'new stores are tidy')

-- Loading over frames ------------------------------------------------------------

do
    local frames, created = {}, 0
    CreateFrame = function()
        created = created + 1
        local frame = { scripts = {} }
        function frame:SetScript(name, fn) self.scripts[name] = fn end
        frames[#frames + 1] = frame
        return frame
    end
    C_Timer = { After = function() end }
    local clock = 0
    -- Every look at the clock costs 6 ms: a slice of 10 ms fits two stores.
    debugprofilestop = function() clock = clock + 6 return clock end
    Log.synchronous = false

    root = fresh()
    for store = 1, 5 do
        Log.Record(request(store, now - 5000 + store * 100))
        assert(Log.CloseOpenStore())
    end
    local progress, result = {}, nil
    local cancel = Log.LoadRange(0, math.huge, function(done, total) progress[#progress + 1] = done .. '/' .. total end,
        function(loaded) result = loaded end)
    assert(type(cancel) == 'function', 'a load in progress can be cancelled')
    assert(result == nil, 'not finished within the first slice')
    assert(#progress >= 1 and #progress < 5, 'the first slice started at once and stopped at its budget')
    local ticks = 0
    while not result do
        ticks = ticks + 1
        assert(ticks < 20, 'the load does not end')
        frames[1].scripts.OnUpdate(frames[1])
    end
    eq(progress[#progress], '5/5', 'progress reached the end')
    eq(count(result), 5, 'all stores loaded')
    eq(frames[1].scripts.OnUpdate, nil, 'the frame stopped')

    -- Everything is unpacked now: the answer comes before LoadRange returns.
    result = nil
    cancel = Log.LoadRange(0, math.huge, nil, function(loaded) result = loaded end)
    assert(result and cancel == nil, 'a cached range is answered at once')
    eq(count(result), 5, 'from the cache')

    -- A cancelled load never answers, and its frame is used again.
    Log.ReleaseCache()
    result = nil
    cancel = Log.LoadRange(0, math.huge, nil, function(loaded) result = loaded end)
    assert(frames[1].scripts.OnUpdate, 'the frame is running again')
    cancel()
    eq(frames[1].scripts.OnUpdate, nil, 'cancelled')
    cancel()
    Log.LoadRange(0, math.huge, nil, function(loaded) result = loaded end)
    while not result do frames[1].scripts.OnUpdate(frames[1]) end
    eq(created, 1, 'one frame for all loads')

    -- Two loads at once each get their own.
    Log.ReleaseCache()
    local first, second
    Log.LoadRange(0, math.huge, nil, function(loaded) first = loaded end)
    Log.LoadRange(0, math.huge, nil, function(loaded) second = loaded end)
    for _ = 1, 20 do
        for _, frame in ipairs(frames) do
            if frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame) end
        end
    end
    assert(first and second, 'both loads finished')
    eq(created, 2, 'a second frame only when two run together')

    CreateFrame, C_Timer, debugprofilestop = nil, nil, nil
    Log.synchronous = true
end

print('Analytics stores passed (cache, trimming, mentions, game encoder and fallbacks, unreadable data, background pass, frames).')
