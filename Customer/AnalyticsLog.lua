local Scan = select(2, ...)

-- The analytics journal: what customers asked for, which greetings went out
-- and which orders were crafted, as a list of small events.
--
-- Kept the way Journalator keeps its logs. Events are written to one open
-- store; full stores are closed into a compressed string that costs next to
-- nothing to keep and is only unpacked when the analytics window asks for its
-- dates. What is unpacked stays in memory until the interface is reloaded, so
-- the window opens at once the second time. Writing an event is a table
-- insert, nothing is counted until the window is open.
--
-- A store is { from, to, n, maxQ, data, f }. With f = 'n' the data was packed
-- by the game's own encoder (CBOR, deflate, base64), which is many times
-- faster than the Lua libraries; without f it is LibSerialize + LibDeflate,
-- as everything was before 0.4.94 and still is where the encoder is missing.
--
-- Event fields (short, they are stored by the thousand):
--   k  kind: r request to us, g greeting sent,
--      d order result, l a request row got its order result, x a request row
--      replaced by a narrower one (m, a mention in chat, is no longer kept)
--   t  time;  q  own sequence number (events made here; merged ones have m)
--   p (kind) online: [t, e) in seconds; without e, a historical 5-minute mark
--   m  the linked account an event came from
--   w  the character that recorded it, "Name-Realm" (since 0.4.95; profiles
--      count by it, see AnalyticsProfiles.lua)
--   c  customer;  f  side, 'H' or 'A';  id  request token
--   i  item;  r  recipe;  p  profession;  s  slot;  lb  slot label
--   x  crafter;  g  general request;  o  crafting order;  st  'f' / 'r'
--   tip  tip in copper;  cut  the Artisan's Consortium's part of it;  to  the replacing token;  man  marked by hand
--   c (kind) a craft for a crafting order (op its craft operation, pr 1 when
--      resourcefulness returned anything), with rs: the customer's reagents
--      it returned, each { i item, n count, v price per unit when it
--      happened, s price source a/t/p, c 1 }
local M = {}
Scan.AnalyticsLog = M

M.STORE_LIMIT = 2000
M.QUIET_SECONDS = 3 * 60
-- Unpacked events kept in memory at most (about 0.6 KB each).
M.CACHE_EVENTS = 40000
-- Unpacking goes on within one frame for this long before the next frame.
M.FRAME_BUDGET_MS = 10

local LibSerialize = LibStub and LibStub('LibSerialize', true)
local LibDeflate = LibStub and LibStub('LibDeflate', true)

local function Clock()
    return (GetTime and GetTime()) or time()
end

-- The character playing here, and whether what it does is recorded: once a
-- realm has crafter pool profiles, a character outside all of them is not.
local function Who()
    local profiles = Scan.AnalyticsProfiles
    return profiles and profiles.Current() or nil
end

local function MayRecord()
    local profiles = Scan.AnalyticsProfiles
    return not profiles or profiles.MayRecord()
end

function M.Root()
    local analytics = Scan.DB and Scan.DB.analytics
    if type(analytics) ~= 'table' then return nil end
    if type(analytics.stores) ~= 'table' then analytics.stores = {} end
    if type(analytics.open) ~= 'table' or type(analytics.open.events) ~= 'table' then
        analytics.open = { events = {} }
    end
    analytics.seq = tonumber(analytics.seq) or 0
    return analytics
end

-- On unless switched off (the old chat counter was opt-in).
function M.IsEnabled()
    local analytics = Scan.DB and Scan.DB.analytics
    return type(analytics) == 'table' and analytics.enabled ~= false
end

function M.SetEnabled(on)
    if not on and M.StopPresence then M.StopPresence() end
    Scan.DB.analytics.enabled = on and true or false
    if on and M.StartPresence then M.StartPresence() end
end

function M.Seq()
    local root = M.Root()
    return root and root.seq or 0
end

-- Load: what the player does - greetings, whispers they type, crafting and
-- claiming or delivering orders, combat. What arrives by itself (requests
-- in chat, incoming whispers, results from linked accounts) is not load:
-- the player may be away, which is the best time to exchange. Linked
-- accounts exchange analytics only once both have been quiet for a while.
local lastActivity = Clock()

function M.NoteActivity()
    lastActivity = Clock()
end

function M.IsQuiet()
    if InCombatLockdown and InCombatLockdown() then return false end
    return Clock() - lastActivity >= M.QUIET_SECONDS
end

function M.QuietFor()
    return Clock() - lastActivity
end

local listeners = {}
function M.OnChange(callback)
    listeners[#listeners + 1] = callback
end

local function Changed()
    for _, callback in ipairs(listeners) do
        pcall(callback)
    end
end

-- 'H' or 'A' for the character logged in here.
local function PlayerSide()
    if type(UnitFactionGroup) ~= 'function' then return nil end
    local ok, faction = pcall(UnitFactionGroup, 'player')
    return ok and (faction == 'Horde' and 'H' or faction == 'Alliance' and 'A') or nil
end
M.PlayerSide = PlayerSide

-- The customer's side from their race (crafting orders cross sides).
local function CustomerSide(guid)
    local quickReplies = Scan.QuickReplies
    if type(guid) ~= 'string' or not (quickReplies and quickReplies.CustomerFaction) then return nil end
    local ok, faction = pcall(quickReplies.CustomerFaction, quickReplies, { guid = guid })
    return ok and (faction == 'Horde' and 'H' or faction == 'Alliance' and 'A') or nil
end

local function Encode(events)
    local serialized = LibSerialize:Serialize(events)
    return LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(serialized))
end

local function Decode(data)
    if type(data) ~= 'string' then return nil end
    local decoded = LibDeflate:DecodeForPrint(data)
    local decompressed = decoded and LibDeflate:DecompressDeflate(decoded)
    if not decompressed then return nil end
    local ok, events = LibSerialize:Deserialize(decompressed)
    return ok and type(events) == 'table' and events or nil
end
M.Decode = Decode

local function Native()
    local util = C_EncodingUtil
    if type(util) == 'table' and util.SerializeCBOR and util.DeserializeCBOR and util.CompressString
        and util.DecompressString and util.EncodeBase64 and util.DecodeBase64 then
        return util
    end
    return nil
end

local function NativeDecode(data)
    local util = Native()
    if not util or type(data) ~= 'string' then return nil end
    local ok, events = pcall(function()
        return util.DeserializeCBOR(util.DecompressString(util.DecodeBase64(data)))
    end)
    return ok and type(events) == 'table' and events or nil
end

local function Same(lhs, rhs)
    if lhs == rhs then return true end
    if type(lhs) ~= 'table' or type(rhs) ~= 'table' then return false end
    for key, value in pairs(lhs) do
        if not Same(value, rhs[key]) then return false end
    end
    for key in pairs(rhs) do
        if lhs[key] == nil then return false end
    end
    return true
end

-- Packed by the game's encoder, but only when unpacking it gives back exactly
-- what went in: a journal is never trusted to an encoder that changes it.
local function NativeEncode(events)
    local util = Native()
    if not util then return nil end
    local ok, data = pcall(function()
        return util.EncodeBase64(util.CompressString(util.SerializeCBOR(events)))
    end)
    if not ok or type(data) ~= 'string' or data == '' then return nil end
    local back = NativeDecode(data)
    return back and Same(events, back) and data or nil
end

local function Pack(events)
    local data = NativeEncode(events)
    if data then return data, 'n' end
    return Encode(events), nil
end

-- A store's events, or nil when its data cannot be read.
local function Unpack(store)
    if store.f == 'n' then return NativeDecode(store.data) end
    return Decode(store.data)
end
M.Unpack = Unpack

local function Month(t)
    return date('%Y-%m', t)
end

local function WithoutMentions(events)
    local kept
    for index, event in ipairs(events) do
        if type(event) == 'table' and event.k == 'm' then
            if not kept then
                kept = {}
                for earlier = 1, index - 1 do kept[earlier] = events[earlier] end
            end
        elseif kept then
            kept[#kept + 1] = event
        end
    end
    return kept
end

-- Close the open store into a compressed one.
function M.CloseOpenStore()
    local root = M.Root()
    local open = root and root.open
    if not open or #open.events == 0 then return false end
    local events = WithoutMentions(open.events) or open.events
    if #events > 0 then
        local data, format = Pack(events)
        root.stores[#root.stores + 1] = {
            from = open.from, to = open.to, n = #events, maxQ = open.maxQ,
            data = data, f = format,
        }
    end
    root.open = { events = {} }
    return true
end

-- Stores emptied by Tidy are taken out of the list.
local function PruneEmpty(root)
    local kept
    for index, store in ipairs(root.stores) do
        if store.n == 0 and store.data == nil then
            if not kept then
                kept = {}
                for earlier = 1, index - 1 do kept[earlier] = root.stores[earlier] end
            end
        elseif kept then
            kept[#kept + 1] = store
        end
    end
    if kept then root.stores = kept end
end

-- Closing costs a moment of compression: done behind the loading screen, when
-- a month is over or the store is full.
function M.Maintain()
    local root = M.Root()
    if root then PruneEmpty(root) end
    local open = root and root.open
    if not open or #open.events == 0 then return end
    if #open.events >= M.STORE_LIMIT or (open.from and Month(open.from) ~= Month(time())) then
        M.CloseOpenStore()
    end
end

local function Append(event, source)
    local root = M.Root()
    if not root then return nil end
    event.t = tonumber(event.t) or time()
    if source then
        event.q = nil
        event.m = source
    else
        root.seq = root.seq + 1
        event.q = root.seq
        if event.w == nil then event.w = Who() end
    end
    -- Everyone who ever recorded here can be put into a profile.
    if type(event.w) == 'string' then
        if type(root.recorders) ~= 'table' then root.recorders = {} end
        root.recorders[event.w] = true
    end
    local open = root.open
    open.events[#open.events + 1] = event
    open.from = math.min(open.from or event.t, event.t)
    local ends = event.k == 'p' and tonumber(event.e) or event.t
    open.to = math.max(open.to or event.t, event.t, ends or event.t)
    if event.q then open.maxQ = event.q end
    if Scan.ReturnPrices then Scan.ReturnPrices.Observe(event) end
    Changed()
    return event
end

function M.Record(event)
    if not M.IsEnabled() or type(event) ~= 'table' or not MayRecord() then return nil end
    -- A greeting sent or an order crafted here: the player is at work.
    if event.k == 'g' or event.k == 'c' then M.NoteActivity() end
    return Append(event)
end

-- Events received from a linked account. They are not sent on again.
function M.Merge(events, source)
    if type(events) ~= 'table' then return 0 end
    local count = 0
    for _, event in ipairs(events) do
        -- An older HironCraft on the other account may still send mentions.
        if type(event) == 'table' and type(event.k) == 'string' and event.k ~= 'm' and tonumber(event.t) then
            Append(event, source or 'peer')
            count = count + 1
        end
    end
    return count
end

-- Which profession makes an item, for mentions of items none of our crafters
-- make. Learned when a profession window opens.
local function ItemProfessions(root)
    if type(root.item_prof) ~= 'table' then root.item_prof = {} end
    if type(root.unknown_items) ~= 'table' then root.unknown_items = {} end
    return root.item_prof, root.unknown_items
end

function M.ProfessionOfItem(itemID)
    local root = M.Root()
    return root and type(root.item_prof) == 'table' and root.item_prof[itemID] or nil
end

function M.LearnProfessionItems(ppID, itemIDs)
    local root = M.Root()
    if not root or not ppID then return end
    local known, unknown = ItemProfessions(root)
    for itemID in pairs(itemIDs or {}) do
        if unknown[itemID] then
            known[itemID] = ppID
            unknown[itemID] = nil
            root.unknown_count = math.max(0, (root.unknown_count or 1) - 1)
        end
    end
end

function M.UnknownItems()
    local root = M.Root()
    return root and type(root.unknown_items) == 'table' and root.unknown_items or {}
end

-- Precise, half-open intervals [t, e). Checkpoints update only the local
-- pending interval; immutable journal records are emitted at most once per
-- five minutes, and on leaving the world. Already-sent records never change.
M.PRESENCE_SLOT = 300 -- Historical marks without an `e` retain this size.
M.PRESENCE_CHECKPOINT = 30
local PRESENCE_FLUSH = 300
local PRESENCE_MAX_GAP = 75
local presenceRunning, presenceTicker = false, nil

local function CommitPresence(root)
    local pending = root.presencePending
    root.presencePending = nil
    if pending and pending.e > pending.t and M.IsEnabled() then
        -- Not through Record: the time was spent on the character it names,
        -- which was recorded then, whoever is playing now.
        return Append({ k = 'p', t = pending.t, e = pending.e, f = pending.f, w = pending.w })
    end
end

function M.NotePresence(now)
    if not M.IsEnabled() or not M.Root() then return nil end
    now = now or time()
    local root, side, who = M.Root(), PlayerSide(), Who()
    if not MayRecord() then
        -- A character outside every profile is not at work.
        if root.presencePending then
            CommitPresence(root)
            Changed()
        end
        return nil
    end
    local pending = root.presencePending
    if pending and (now < pending.e or now - pending.e > PRESENCE_MAX_GAP or pending.f ~= side
        or pending.w ~= who) then
        -- A suspended client or disconnected/loading gap is not proof of
        -- continuous online time. Preserve only the last observed endpoint.
        CommitPresence(root)
        pending = nil
    end
    if not pending then
        root.presencePending = { t = now, e = now, f = side, w = who }
    else
        if now == pending.e then return nil end
        pending.e = now
        if now - pending.t >= PRESENCE_FLUSH then
            CommitPresence(root)
            root.presencePending = { t = now, e = now, f = side, w = who }
        end
    end
    Changed()
    return true
end

function M.StartPresence()
    if not M.IsEnabled() or not M.Root() then return end
    if not presenceRunning then
        -- Saved by an earlier session: do not extend it across a relog or
        -- offline gap. It is safe to replay; it was never sent while pending.
        CommitPresence(M.Root())
        presenceRunning = true
    end
    M.NotePresence()
    if not presenceTicker and C_Timer and C_Timer.NewTicker then
        presenceTicker = C_Timer.NewTicker(M.PRESENCE_CHECKPOINT, function()
            if presenceRunning then pcall(M.NotePresence) end
        end)
    end
end

function M.StopPresence()
    local root = M.Root()
    if not root then return end
    if presenceRunning then M.NotePresence() end
    CommitPresence(root)
    presenceRunning = false
end

local function SideOf(faction)
    return faction == 'Horde' and 'H' or faction == 'Alliance' and 'A' or nil
end

-- A new request row: this character saw it, so it is on this side.
function M.Request(customer, response, side)
    if type(response) ~= 'table' or type(response.requestToken) ~= 'string' then return end
    local slot = type(response.equipmentRequest) == 'table' and response.equipmentRequest or nil
    M.Record({
        k = 'r', t = tonumber(response.time) or time(), id = response.requestToken, c = customer,
        i = tonumber(response.itemID), r = tonumber(response.recipeID),
        p = tonumber(response.parentProfID), s = slot and slot.key, lb = slot and slot.label,
        x = response.crafterFullName, g = response.generic_request and 1 or nil,
        f = side or PlayerSide(),
    })
end

-- "LF tailor" became "[Cloak]": one conversation, counted once.
function M.Replaced(oldToken, newToken)
    if type(oldToken) ~= 'string' or type(newToken) ~= 'string' or oldToken == newToken then return end
    M.Record({ k = 'x', id = oldToken, to = newToken })
end

-- A greeting leaves from this character, so the conversation is on its side.
function M.Greeting(customer, response, at, side)
    if type(response) ~= 'table' or type(response.requestToken) ~= 'string' then return nil end
    return M.Record({ k = 'g', t = at, id = response.requestToken, c = customer, x = response.crafterFullName,
        f = side or PlayerSide() })
end

-- The server swallowed the greeting: it was never sent.
function M.Retract(events)
    local root = M.Root()
    if not root or type(events) ~= 'table' then return end
    local open = root.open.events
    for _, event in ipairs(events) do
        for index = #open, math.max(1, #open - 200), -1 do
            if open[index] == event then
                table.remove(open, index)
                break
            end
        end
    end
    Changed()
end

-- A delivered or declined crafting order, from the order journal. Made here or
-- received from a linked account; the same order is counted once.
function M.Outcome(notice, source)
    if type(notice) ~= 'table' or notice.orderID == nil then return end
    local status = notice.status == 'fulfilled' and 'f' or notice.status == 'rejected' and 'r' or nil
    if not status or not M.IsEnabled() then return end
    local event = {
        k = 'd', t = tonumber(notice.updatedAt) or time(), o = notice.orderID, st = status,
        c = notice.customerName, i = tonumber(notice.itemID), r = tonumber(notice.spellID),
        p = tonumber(notice.parentProfessionID), x = notice.crafterFullName,
        tip = status == 'f' and tonumber(notice.tipAmount) or nil,
        cut = status == 'f' and tonumber(notice.consortiumCut) or nil,
        id = type(notice.requestToken) == 'string' and notice.requestToken or nil,
        f = CustomerSide(notice.customerGuid),
    }
    if source then
        return Append(event, source)
    end
    return M.Record(event)
end

-- A request row got the result of a crafting order (or was marked by hand).
function M.Link(token, orderID, status, manual, at)
    if type(token) ~= 'string' then return end
    local st = status == 'fulfilled' and 'f' or status == 'rejected' and 'r' or nil
    if not st then return end
    M.Record({ k = 'l', t = at, id = token, o = orderID, st = st, man = manual and 1 or nil })
end

-- Once, on the first login with the journal: what is still kept elsewhere.
-- The order journal holds the last few hundred results, the order rows their
-- requests and greetings, the statuses which order answered which row.
function M.Backfill()
    local root = M.Root()
    if not root or root.backfilled or not M.IsEnabled() then return false end
    root.backfilled = 1
    local myID = Scan.DB.settings and Scan.DB.settings.my_uuid
    local notices = Scan.DB.settings and Scan.DB.settings.order_completion_notices
    -- The order journal is kept for the whole account: only the orders of
    -- this realm's crafters belong in this realm's analytics.
    local profiles = Scan.AnalyticsProfiles
    for _, notice in pairs(type(notices) == 'table' and notices or {}) do
        if type(notice) == 'table' and (not profiles or profiles.IsLocal(notice.crafterFullName)) then
            local own = notice.origin == nil or notice.origin == myID
            M.Outcome(notice, not own and 'notice' or nil)
        end
    end
    local seen = {}
    for customer, info in pairs(Scan.DB.customers or {}) do
        for _, response in pairs(type(info) == 'table' and type(info.responses) == 'table' and info.responses or {}) do
            local token = type(response) == 'table' and response.requestToken
            if type(token) == 'string' and not seen[token] and token:sub(1, 6) ~= 'order:' then
                seen[token] = true
                local side = SideOf(response.conversationFaction)
                M.Request(customer, response, side)
                if response.greeting_sent and tonumber(response.greetingSentAt) then
                    M.Greeting(customer, response, tonumber(response.greetingSentAt), side)
                end
            end
        end
    end
    local statuses = Scan.DB.realm and Scan.DB.realm.order_statuses
    for _, entry in pairs(type(statuses) == 'table' and statuses or {}) do
        if type(entry) == 'table' and entry.requestToken then
            M.Link(entry.requestToken, entry.craftingOrderID, entry.status, entry.automatic == false,
                tonumber(entry.updatedAt))
        end
    end
    return true
end

-- The chat counter kept before 0.4.41 (seen_items) held mentions of items in
-- chat, which are no longer counted: only which profession makes an item is
-- taken from it. Done once, the first time the window opens.
function M.MigrateLegacy()
    local root = M.Root()
    if not root or type(root.seen_items) ~= 'table' then return false end
    local known, unknown = ItemProfessions(root)
    for itemID, info in pairs(root.seen_items) do
        itemID = tonumber(itemID)
        if itemID and type(info) == 'table' then
            local ppID = tonumber(info.ppID)
            if ppID then known[itemID] = ppID elseif not known[itemID] then unknown[itemID] = true end
        end
    end
    root.seen_items = nil
    return true
end

-- Mentions of items in chat left the window in 0.4.65 and are not recorded
-- any more. The first time an older store is unpacked they are taken out of
-- it and the store is packed again, by the game's encoder when it is there.
-- A store that held nothing else is left empty for PruneEmpty.
local function Tidy(store, events)
    local kept = WithoutMentions(events)
    if kept then
        events = kept
        if #events == 0 then
            store.data, store.f, store.n = nil, nil, 0
        else
            local data = NativeEncode(events)
            store.data, store.f, store.n = data or Encode(events), data and 'n' or nil, #events
        end
    elseif store.f ~= 'n' and store.tidy ~= 1 and #events > 0 then
        local data = NativeEncode(events)
        if data then store.data, store.f = data, 'n' end
    end
    store.tidy = store.f ~= 'n' and store.data ~= nil and 1 or nil
    return events
end

-- Unpacked stores, kept until the interface is reloaded: the most recently
-- used ones, up to CACHE_EVENTS events.
local unpacked = setmetatable({}, { __mode = 'k' })
local usedAt, useClock = setmetatable({}, { __mode = 'k' }), 0
-- What the last LoadRange cost, for reading in the saved variables.
local unpackedCount, unpackedMs = 0, 0

local function Events(store)
    local events = unpacked[store]
    if not events then
        local started = debugprofilestop and debugprofilestop()
        events = Unpack(store)
        -- Data that cannot be read is left exactly as it is.
        events = events and Tidy(store, events) or {}
        unpacked[store] = events
        unpackedCount = unpackedCount + 1
        if started then unpackedMs = unpackedMs + (debugprofilestop() - started) end
    end
    useClock = useClock + 1
    usedAt[store] = useClock
    return events
end

function M.ReleaseCache()
    unpacked = setmetatable({}, { __mode = 'k' })
    usedAt = setmetatable({}, { __mode = 'k' })
end

-- Lets go of the least recently used stores beyond the limit.
function M.TrimCache(limit)
    limit = limit or M.CACHE_EVENTS
    local stores = {}
    for store in pairs(unpacked) do stores[#stores + 1] = store end
    table.sort(stores, function(lhs, rhs) return (usedAt[lhs] or 0) > (usedAt[rhs] or 0) end)
    local held = 0
    for _, store in ipairs(stores) do
        held = held + #unpacked[store]
        if held > limit then unpacked[store], usedAt[store] = nil, nil end
    end
end

local function Overlaps(store, from, to)
    return (store.to or math.huge) >= from and (store.from or 0) <= to
end

-- One frame runs a load's steps for FRAME_BUDGET_MS; frames are reused.
local idleDrivers = {}
local function Drive(step, finish)
    local driver = table.remove(idleDrivers) or CreateFrame('Frame')
    local function Stop()
        if not driver then return end
        driver:SetScript('OnUpdate', nil)
        idleDrivers[#idleDrivers + 1] = driver
        driver = nil
    end
    driver:SetScript('OnUpdate', function()
        if not step() then
            Stop()
            finish()
        end
    end)
    return Stop
end

-- Every store that overlaps [from, to]. What is already unpacked is taken at
-- once; the rest is unpacked a few milliseconds per frame, so a long range
-- never freezes the game. progress(done, total); done(chunks) gets a list of
-- event arrays, the open store last. Returns a function that cancels the
-- load, or nothing when it finished before returning.
function M.LoadRange(from, to, progress, done)
    local root = M.Root()
    if not root then done({}) return end
    M.MigrateLegacy()
    local wanted = {}
    for _, store in ipairs(root.stores) do
        if Overlaps(store, from or 0, to or math.huge) then wanted[#wanted + 1] = store end
    end
    local chunks, step = {}, 0
    unpackedCount, unpackedMs = 0, 0
    local function Finish()
        local current = M.Root()
        PruneEmpty(current)
        local native = 0
        for _, store in ipairs(wanted) do
            if store.f == 'n' then native = native + 1 end
        end
        current.perf = current.perf or {}
        current.perf.at, current.perf.stores, current.perf.native = time(), #wanted, native
        current.perf.unpacked, current.perf.unpackMs = unpackedCount, math.floor(unpackedMs + 0.5)
        chunks[#chunks + 1] = current.open.events
        local pending = current.presencePending
        if pending and pending.e > pending.t then
            -- A snapshot, not the mutable saved table or a sync-able record.
            chunks[#chunks + 1] = { { k = 'p', t = pending.t, e = pending.e, f = pending.f, w = pending.w } }
        end
        done(chunks)
    end
    local function Next()
        step = step + 1
        local store = wanted[step]
        if not store then return false end
        chunks[#chunks + 1] = Events(store)
        if progress then progress(step, #wanted) end
        return true
    end
    if not (CreateFrame and C_Timer) or M.synchronous then
        while Next() do end
        Finish()
        return
    end
    local function Slice()
        local started = debugprofilestop and debugprofilestop()
        while true do
            local store = wanted[step + 1]
            local cached = store and unpacked[store] ~= nil
            if not Next() then return false end
            if not cached and (not started or debugprofilestop() - started >= M.FRAME_BUDGET_MS) then
                return true
            end
        end
    end
    if not Slice() then
        Finish()
        return
    end
    return Drive(Slice, Finish)
end

-- How long the window took to count what LoadRange gave it.
function M.NoteBuild(milliseconds)
    local root = M.Root()
    if not root or not milliseconds then return end
    root.perf = root.perf or {}
    root.perf.buildMs = math.floor(milliseconds + 0.5)
end

-- Once: every store from before 0.4.94 is tidied (see Tidy), also the ones
-- nobody looks at. One store per call, off the cache; false when none is left.
function M.TidyStep()
    local root = M.Root()
    if not root or root.tidied == 1 then return false end
    for _, store in ipairs(root.stores) do
        if store.f ~= 'n' and store.tidy ~= 1 and store.data ~= nil then
            if unpacked[store] then
                store.tidy = 1
            else
                local events = Unpack(store)
                if events then Tidy(store, events) else store.tidy = 1 end
            end
            return true
        end
    end
    PruneEmpty(root)
    root.tidied = 1
    return false
end

-- Own events newer than a linked account has, oldest first, at most limit,
-- leaving out the kinds in skip. Returns the events, the sequence number the
-- account is up to after them, and whether more remain.
function M.OwnSince(from, limit, skip)
    local root = M.Root()
    if not root then return {}, from, false end
    from = tonumber(from) or 0
    local found = {}
    local function Collect(events)
        for _, event in ipairs(events) do
            if event.q and event.q > from and not event.m and not (skip and skip[event.k]) then
                found[#found + 1] = event
            end
        end
    end
    for _, store in ipairs(root.stores) do
        if (tonumber(store.maxQ) or 0) > from then Collect(Events(store)) end
    end
    M.TrimCache()
    Collect(root.open.events)
    table.sort(found, function(lhs, rhs) return lhs.q < rhs.q end)
    local batch = {}
    for index = 1, math.min(limit or #found, #found) do
        local copy = {}
        for key, value in pairs(found[index]) do copy[key] = value end
        batch[#batch + 1] = copy
    end
    -- Retracted and skipped events leave gaps in the numbers: once nothing is
    -- left, the account is up to date with everything numbered so far.
    local more = #found > #batch
    local last = more and batch[#batch].q or root.seq
    return batch, last, more
end

-- Customers with a delivered order whose tip was never recorded: the order
-- journal and this journal's open store.
function M.UntippedCustomers()
    local names = {}
    local notices = Scan.DB.settings and Scan.DB.settings.order_completion_notices
    for _, notice in pairs(type(notices) == 'table' and notices or {}) do
        if type(notice) == 'table' and notice.status == 'fulfilled' and notice.tipAmount == nil
            and type(notice.customerName) == 'string' then
            names[#names + 1] = notice.customerName
        end
    end
    local root = M.Root()
    for _, event in ipairs(root and root.open.events or {}) do
        if event.k == 'd' and event.st == 'f' and event.tip == nil and type(event.c) == 'string' then
            names[#names + 1] = event.c
        end
    end
    return names
end

-- Gathering is on by default. The old chat counter was opt-in, and an
-- account switched off back then kept its greetings out of the combined
-- picture unnoticed: it is switched on once. Unticked by hand after that, it
-- stays off.
function M.Startup()
    local analytics = Scan.DB and Scan.DB.analytics
    if type(analytics) ~= 'table' then return end
    if analytics.default_on ~= 1 then
        analytics.enabled = nil
        analytics.default_on = 1
    end
    if M.IsEnabled() and M.Root() then
        pcall(M.Backfill)
        if analytics.untipped_silver ~= 1 and Scan.Generous and Scan.Generous.MarkUntipped then
            analytics.untipped_silver = 1
            pcall(Scan.Generous.MarkUntipped, M.UntippedCustomers())
        end
        pcall(M.Maintain)
    end
end

-- Stream the complete history once to build the unfiltered reagent catalogue.
-- Unlike LoadRange this does not retain decompressed stores in the UI cache.
function M.VisitReturnEvents(visit, done)
    local root = M.Root()
    if not root then done(); return end
    local stores, index = {}, 0
    for _, store in ipairs(root.stores) do stores[#stores + 1] = store end
    local function Visit(events)
        for _, event in ipairs(events or {}) do if event.k == 'c' then visit(event) end end
    end
    local function Step()
        index = index + 1
        local store = stores[index]
        if not store then Visit(root.open.events); done(); return end
        Visit(unpacked[store] or Unpack(store))
        if C_Timer and C_Timer.After then C_Timer.After(0, Step) else Step() end
    end
    Step()
end

-- Freeze the latest successful exact-quality HironCraft price at craft time.
-- Unknown prices remain unknown, including after a later scan.
local function ReagentPrice(itemID)
    local price = Scan.ReturnPrices and Scan.ReturnPrices.GetPrice(itemID)
    if price and price > 0 then return price, 'p' end
end
M.ReagentPrice = ReagentPrice

local function RecipeProfession(recipeID)
    if C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillLineForRecipe and recipeID then
        local ok, skillLine, _, parent = pcall(C_TradeSkillUI.GetTradeSkillLineForRecipe, recipeID)
        if ok and (tonumber(parent) or tonumber(skillLine)) then return tonumber(parent) or tonumber(skillLine) end
    end
    local info = C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
    return info and tonumber(info.professionID) or nil
end

-- A craft finished. Only crafts for a crafting order are kept: each counts
-- for the chance of resourcefulness, and the customer's reagents it returned
-- are kept with their price at that moment (the crafter's own are not
-- counted).
local countedOperations = {}
function M.CraftResult(data)
    if type(data) ~= 'table' or not M.IsEnabled() then return end
    local order = C_CraftingOrders and C_CraftingOrders.GetClaimedOrder and C_CraftingOrders.GetClaimedOrder()
    if type(order) ~= 'table' or order.orderID == nil then return end
    local operation = tonumber(data.operationID)
    if operation and operation ~= 0 then
        if countedOperations[operation] then return end
        countedOperations[operation] = true
    end
    local audit = Scan.ReagentAudit
    local fromCustomer = audit and audit.CustomerItems and audit.CustomerItems(order) or {}
    local returned, any = nil, false
    for _, entry in ipairs(type(data.resourcesReturned) == 'table' and data.resourcesReturned or {}) do
        -- Reagents that are currencies have no auction price: left out.
        local itemID = tonumber(entry.reagent and entry.reagent.itemID or entry.itemID)
        local count = tonumber(entry.quantity)
        if count and count > 0 then any = true end
        if itemID and count and count > 0 and fromCustomer[itemID] then
            local price, source = ReagentPrice(itemID)
            returned = returned or {}
            returned[#returned + 1] = { i = itemID, n = count, v = price, s = source, c = 1 }
        end
    end
    local crafter = Scan.GetPlayerName and Scan.GetPlayerName(true) or nil
    return M.Record({ k = 'c', o = order.orderID, op = operation ~= 0 and operation or nil,
        r = tonumber(order.spellID), p = RecipeProfession(order.spellID), x = crafter,
        pr = any and 1 or nil, rs = returned })
end

-- Whispers the player types, crafting and orders count as load.
if CreateFrame then
    local presence = CreateFrame('Frame')
    for _, event in ipairs({ 'PLAYER_ENTERING_WORLD', 'PLAYER_LEAVING_WORLD', 'PLAYER_LOGOUT' }) do
        presence:RegisterEvent(event)
    end
    presence:SetScript('OnEvent', function(_, event)
        if event == 'PLAYER_ENTERING_WORLD' then M.StartPresence() else M.StopPresence() end
    end)
    local watcher = CreateFrame('Frame')
    for _, event in ipairs({
        'CHAT_MSG_WHISPER_INFORM', 'CHAT_MSG_BN_WHISPER_INFORM', 'CRAFTINGORDERS_CLAIMED_ORDER_ADDED',
        'CRAFTINGORDERS_CLAIMED_ORDER_UPDATED', 'CRAFTINGORDERS_FULFILL_ORDER_RESPONSE',
        'TRADE_SKILL_ITEM_CRAFTED_RESULT', 'PLAYER_REGEN_DISABLED',
    }) do
        pcall(watcher.RegisterEvent, watcher, event)
    end
    watcher:SetScript('OnEvent', function(_, event, ...)
        M.NoteActivity()
        if event == 'TRADE_SKILL_ITEM_CRAFTED_RESULT' then pcall(M.CraftResult, ...) end
    end)
end

if Scan.Utils and Scan.Utils.onLoad then
    Scan.Utils.onLoad(function()
        pcall(M.Startup)
        pcall(M.StartPresence)
    end)
end
