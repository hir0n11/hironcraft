local Scan = select(2, ...)

-- The analytics journal: what customers asked for, which greetings went out
-- and which orders were crafted, as a list of small events.
--
-- Kept the way Journalator keeps its logs. Events are written to one open
-- store; full stores are closed into a compressed string (LibSerialize +
-- LibDeflate) that costs next to nothing to keep and is only unpacked when the
-- analytics window asks for its dates. Writing an event is a table insert,
-- nothing is counted until the window is open.
--
-- Event fields (short, they are stored by the thousand):
--   k  kind: m mention in chat, r request to us, g greeting sent,
--      d order result, l a request row got its order result, x a request row
--      replaced by a narrower one
--   t  time;  q  own sequence number (events made here; merged ones have m)
--   m  the linked account an event came from
--   c  customer;  f  side, 'H' or 'A';  id  request token
--   i  item;  r  recipe;  p  profession;  s  slot;  lb  slot label
--   x  crafter;  g  general request;  o  crafting order;  st  'f' / 'r'
--   tip  tip in copper;  to  the replacing token;  man  marked by hand
--   c (kind) a craft for a crafting order (op its craft operation), with rs: the reagents
--      resourcefulness returned, each { i item, n count, v price per unit
--      when it happened, s price source a/t/p, c 1 when the customer's }
local M = {}
Scan.AnalyticsLog = M

M.STORE_LIMIT = 2000
M.QUIET_SECONDS = 10 * 60
local MENTION_REPEAT_SECONDS = 15
local UNKNOWN_ITEMS_LIMIT = 3000

local LibSerialize = LibStub and LibStub('LibSerialize', true)
local LibDeflate = LibStub and LibStub('LibDeflate', true)

local function Clock()
    return (GetTime and GetTime()) or time()
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
    Scan.DB.analytics.enabled = on and true or false
end

function M.Seq()
    local root = M.Root()
    return root and root.seq or 0
end

-- Load: anything the player does with customers or orders. Linked accounts
-- exchange analytics only once both have been quiet for a while.
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

local function Month(t)
    return date('%Y-%m', t)
end

-- Close the open store into a compressed one.
function M.CloseOpenStore()
    local root = M.Root()
    local open = root and root.open
    if not open or #open.events == 0 then return false end
    root.stores[#root.stores + 1] = {
        from = open.from, to = open.to, n = #open.events, maxQ = open.maxQ,
        data = Encode(open.events),
    }
    root.open = { events = {} }
    return true
end

-- Closing costs a moment of compression: done behind the loading screen, when
-- a month is over or the store is full.
function M.Maintain()
    local root = M.Root()
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
    end
    local open = root.open
    open.events[#open.events + 1] = event
    open.from = math.min(open.from or event.t, event.t)
    open.to = math.max(open.to or event.t, event.t)
    if event.q then open.maxQ = event.q end
    Changed()
    return event
end

function M.Record(event)
    if not M.IsEnabled() or type(event) ~= 'table' then return nil end
    if event.k ~= 'm' then M.NoteActivity() end
    return Append(event)
end

-- Events received from a linked account. They are not sent on again.
function M.Merge(events, source)
    if type(events) ~= 'table' then return 0 end
    local count = 0
    for _, event in ipairs(events) do
        if type(event) == 'table' and type(event.k) == 'string' and tonumber(event.t) then
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

local recentMentions, recentCount = {}, 0

-- An item link seen in chat, whether or not we craft it.
function M.Mention(customer, itemID, ppID)
    itemID = tonumber(itemID)
    if not itemID or not M.IsEnabled() then return end
    local root = M.Root()
    if not root then return end
    -- The same customer repeating the same link right away is impatience.
    local key = tostring(customer) .. ':' .. itemID
    local now = time()
    if recentMentions[key] and now - recentMentions[key] < MENTION_REPEAT_SECONDS then return end
    if recentCount > 2000 then recentMentions, recentCount = {}, 0 end
    recentMentions[key] = now
    recentCount = recentCount + 1

    local known, unknown = ItemProfessions(root)
    ppID = tonumber(ppID)
    if ppID then
        known[itemID] = ppID
        unknown[itemID] = nil
    elseif not known[itemID] then
        local count = root.unknown_count or 0
        if not unknown[itemID] and count < UNKNOWN_ITEMS_LIMIT then
            unknown[itemID] = true
            root.unknown_count = count + 1
        end
    end
    M.Record({ k = 'm', t = now, c = customer, i = itemID, p = ppID or known[itemID], f = PlayerSide() })
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
    for _, notice in pairs(type(notices) == 'table' and notices or {}) do
        if type(notice) == 'table' then
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

-- The chat counter kept before 0.4.41 (seen_items), as mention events in one
-- closed store. Done once, the first time the window opens.
function M.MigrateLegacy()
    local root = M.Root()
    if not root or type(root.seen_items) ~= 'table' then return false end
    local known, unknown = ItemProfessions(root)
    local events = {}
    for itemID, info in pairs(root.seen_items) do
        itemID = tonumber(itemID)
        if itemID and type(info) == 'table' then
            local ppID = tonumber(info.ppID)
            if ppID then known[itemID] = ppID elseif not known[itemID] then unknown[itemID] = true end
            for _, entry in ipairs(type(info.times) == 'table' and info.times or {}) do
                local t = type(entry) == 'table' and tonumber(entry.t) or tonumber(entry)
                if t then
                    events[#events + 1] = { k = 'm', t = t, i = itemID, p = ppID,
                        c = type(entry) == 'table' and entry.customer or nil, L = 1 }
                end
            end
        end
    end
    table.sort(events, function(lhs, rhs) return lhs.t < rhs.t end)
    for first = 1, #events, M.STORE_LIMIT * 5 do
        local chunk = {}
        for index = first, math.min(#events, first + M.STORE_LIMIT * 5 - 1) do chunk[#chunk + 1] = events[index] end
        root.stores[#root.stores + 1] = { from = chunk[1].t, to = chunk[#chunk].t, n = #chunk, data = Encode(chunk) }
    end
    root.seen_items = nil
    return true
end

-- Unpacked stores stay here while the window is open.
local unpacked = {}

function M.ReleaseCache()
    unpacked = {}
end

local function Overlaps(store, from, to)
    return (store.to or math.huge) >= from and (store.from or 0) <= to
end

-- Every store that overlaps [from, to], unpacked one per frame so a long range
-- never freezes the game. progress(done, total); done(chunks) gets a list of
-- event arrays, the open store last.
function M.LoadRange(from, to, progress, done)
    local root = M.Root()
    if not root then done({}) return end
    M.MigrateLegacy()
    local wanted = {}
    for index, store in ipairs(root.stores) do
        if Overlaps(store, from or 0, to or math.huge) then wanted[#wanted + 1] = index end
    end
    local chunks, step = {}, 0
    local function Finish()
        chunks[#chunks + 1] = M.Root().open.events
        done(chunks)
    end
    local function Next()
        step = step + 1
        local index = wanted[step]
        if not index then return false end
        local store = M.Root().stores[index]
        if not unpacked[store] then unpacked[store] = Decode(store.data) or {} end
        chunks[#chunks + 1] = unpacked[store]
        if progress then progress(step, #wanted) end
        return true
    end
    if not (CreateFrame and C_Timer) or M.synchronous then
        while Next() do end
        Finish()
        return
    end
    local frame = CreateFrame('Frame')
    frame:SetScript('OnUpdate', function(self)
        if not Next() then
            self:SetScript('OnUpdate', nil)
            Finish()
        end
    end)
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
        if (tonumber(store.maxQ) or 0) > from then
            if not unpacked[store] then unpacked[store] = Decode(store.data) or {} end
            Collect(unpacked[store])
        end
    end
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

-- What a reagent is worth now: Auctionator, else TSM, else ProfitHub's own
-- scans. Returns the price per unit in copper and where it came from.
local function ReagentPrice(itemID)
    local function Try(source, fn)
        local ok, price = pcall(fn)
        price = ok and tonumber(price) or nil
        if price and price > 0 then return math.floor(price + 0.5), source end
        return nil
    end
    local price, source = nil, nil
    local auctionator = Auctionator and Auctionator.API and Auctionator.API.v1
    if auctionator and auctionator.GetAuctionPriceByItemID then
        price, source = Try('a', function() return auctionator.GetAuctionPriceByItemID('HironCraft', itemID) end)
    end
    if not price and TSM_API and TSM_API.GetCustomPriceValue then
        price, source = Try('t', function() return TSM_API.GetCustomPriceValue('DBMarket', 'i:' .. itemID) end)
    end
    local prices = HironCraftProfit and HironCraftProfit.Prices
    if not price and prices and prices.GetPrice then
        price, source = Try('p', function() return prices:GetPrice(itemID, 'phMarket') end)
    end
    return price, source
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
-- for the chance of resourcefulness, and the reagents it returned are kept
-- with their price at that moment and whether the customer supplied them.
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
    local customerSource = Enum and Enum.CraftingOrderReagentSource and Enum.CraftingOrderReagentSource.Customer or 1
    local fromCustomer = {}
    for _, reagent in ipairs(type(order.reagents) == 'table' and order.reagents or {}) do
        local info = type(reagent) == 'table' and reagent.reagentInfo
        local itemID = info and info.reagent and info.reagent.itemID
        if itemID and reagent.source == customerSource then fromCustomer[itemID] = true end
    end
    local returned = nil
    for _, entry in ipairs(type(data.resourcesReturned) == 'table' and data.resourcesReturned or {}) do
        -- Reagents that are currencies have no auction price: left out.
        local itemID = tonumber(entry.reagent and entry.reagent.itemID or entry.itemID)
        local count = tonumber(entry.quantity)
        if itemID and count and count > 0 then
            local price, source = ReagentPrice(itemID)
            returned = returned or {}
            returned[#returned + 1] = { i = itemID, n = count, v = price, s = source,
                c = fromCustomer[itemID] and 1 or nil }
        end
    end
    local crafter = Scan.GetPlayerName and Scan.GetPlayerName(true) or nil
    return M.Record({ k = 'c', o = order.orderID, op = operation ~= 0 and operation or nil,
        r = tonumber(order.spellID), p = RecipeProfession(order.spellID), x = crafter, rs = returned })
end

-- Whispers and crafting orders count as load, whoever started them.
if CreateFrame then
    local watcher = CreateFrame('Frame')
    for _, event in ipairs({
        'CHAT_MSG_WHISPER', 'CHAT_MSG_WHISPER_INFORM', 'CHAT_MSG_BN_WHISPER',
        'CHAT_MSG_BN_WHISPER_INFORM', 'CRAFTINGORDERS_CLAIMED_ORDER_ADDED',
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
    Scan.Utils.onLoad(function() pcall(M.Startup) end)
end
