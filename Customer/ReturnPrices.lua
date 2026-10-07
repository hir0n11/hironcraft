-- Low-priority, exact-item price queries for the resourcefulness catalogue.
-- Historical AnalyticsLog events are never repriced.
--
-- A return is valued with the price known when the craft happens, so the
-- prices of the reagents that come back these days have to be recent. One
-- query takes about half a second (the auction house answers two a second),
-- so the order matters: a visit to the auction house first updates the
-- reagents returned in the last week (currentFor), the latest first, and
-- then, once a day, the rest of the catalogue. A price that any browse of the
-- auction house has just read (a full scan, a search in the shop, another
-- addon's scan) is taken as it is and not asked for again.
local _, Scan = ...
local P = { freshFor = 900, retryAfter = 300, pauseFor = 2,
    currentFor = 7 * 24 * 3600, restFreshFor = 24 * 3600 }
Scan.ReturnPrices = P
local listeners, queue, pending, sending = {}, {}, nil, false
local open, pausedUntil, nextSend, total, finished = false, 0, 0, 0, 0
local tickQueued, loadingSince = false, nil
local function Now() return GetTime() end
local function DB()
    HironCraftProfit_PriceDB = HironCraftProfit_PriceDB or {}
    local db = HironCraftProfit_PriceDB
    db.returnCatalog = db.returnCatalog or {}
    db.returnRealms = db.returnRealms or {}
    local realm = (GetRealmName() or ''):gsub('%s+', '')
    db.returnRealms[realm] = db.returnRealms[realm] or { items = {} }
    return db.returnRealms[realm], db.returnCatalog
end
-- When a catalogue reagent was last returned. 0 for an entry from before
-- that was kept (a plain true), until the history is read again.
local function ReturnedAt(seen)
    return type(seen) == 'number' and seen or 0
end
function P.Observe(event)
    if type(event) ~= 'table' or event.k ~= 'c' then return end
    local _, catalog = DB()
    local at = tonumber(event.t) or time()
    for _, reagent in ipairs(event.rs or {}) do
        local id = tonumber(reagent.i)
        if id and id > 0 and reagent.c and (tonumber(reagent.n) or 0) > 0 then
            catalog[id] = math.max(ReturnedAt(catalog[id]), at)
        end
    end
end
function P.GetPrice(itemID)
    local db = DB()
    local record = db.items[tonumber(itemID)]
    -- Only successful HironCraft scans; no hidden third-party fallback.
    if record and record.price and record.price > 0 then return record.price, record.at end
end
function P.OnChange(fn) listeners[#listeners + 1] = fn end
local function Changed()
    for _, fn in ipairs(listeners) do pcall(fn) end
end
local function ScheduleTick()
    if tickQueued or not open then return end
    tickQueued = true
    C_Timer.After(0, function()
        tickQueued = false
        P.Tick()
    end)
end
function P.AttachScanButton(button)
    local function L(text) return Scan.LOCAL:GetText(text) end
    local function Update()
        local status = P.Status()
        local label = status.indexing and L('Reading reagent history') or L('Scan reagent prices')
        if status.running then
            label = string.format('%s %d/%d', L(status.paused and 'Paused' or 'Scanning'), status.finished, status.total)
        end
        button:SetText(label)
    end
    button:SetScript('OnClick', function()
        if P.Status().open then P.Start(true)
        else print('HironCraft: ' .. L('Open the auction house to update reagent prices.')) end
    end)
    button:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_TOP')
        GameTooltip:SetText(L('Scan reagent prices'))
        GameTooltip:AddLine(L('Reagent price scan tooltip'), 1, 1, 1, true)
        local status = P.Status()
        GameTooltip:AddLine(string.format(L('Reagents: %d, returned in the last week: %d'), status.catalog, status.current))
        GameTooltip:AddLine(status.at and (L('Prices updated') .. ': ' .. date('%d.%m %H:%M', status.at)) or L('Prices not scanned yet'))
        GameTooltip:Show()
    end)
    button:SetScript('OnLeave', function() GameTooltip:Hide() end)
    button:HookScript('OnShow', Update)
    P.OnChange(Update)
    Update()
end
local function UserBusy()
    local shop = HironCraftProfit and HironCraftProfit.ShoppingList
    if shop and ((shop.scanAllState and shop.scanAllState.active) or shop.pendingSearchCommodityRow
        or next(shop.pendingSearchItemPurchases or {}) or shop._pendingSellScan
        or (shop.sell and (shop.sell.pendingBuy or shop.sell.awaitingPost
            or (shop.sell.scan and shop.sell.scan.pending)))) then return true end
    local ah = AuctionHouseFrame
    for _, key in ipairs({ 'CommoditiesBuyFrame', 'ItemBuyFrame', 'ItemSellFrame',
        'CommoditiesSellFrame', 'BuyDialog' }) do
        local pane = ah and ah[key]
        -- A child can remain "shown" underneath a hidden Blizzard tab while
        -- HironCraft/Auctionator is visible. Only an actually visible pane owns it.
        if pane and ((pane.IsVisible and pane:IsVisible())
            or (not pane.IsVisible and pane:IsShown())) then return true end
    end
    return false
end
function P.Status()
    local db, catalog = DB()
    local count, current = 0, 0
    for _, seen in pairs(catalog) do
        count = count + 1
        if time() - ReturnedAt(seen) <= P.currentFor then current = current + 1 end
    end
    return { open = open, total = total, finished = finished, catalog = count, current = current,
        running = pending ~= nil or #queue > 0, paused = Now() < pausedUntil or UserBusy(),
        at = db.lastSuccess, indexing = P.indexing }
end
function P.Suspend()
    if sending or not open then return end
    pausedUntil = Now() + P.pauseFor
    -- Keep this item queued, but discard the interrupted query's reply.
    pending, loadingSince = nil, nil
    Changed()
end
local function Complete(price)
    if not pending then return end
    local db = DB()
    local id = pending.id
    local record = db.items[id] or {}
    db.items[id] = record
    record.attempt = time()
    if price and price > 0 then
        record.price, record.at = math.floor(price + 0.5), time()
        db.lastSuccess = time()
    end
    -- Empty results/timeouts deliberately retain the last successful price.
    pending, loadingSince = nil, nil
    table.remove(queue, 1)
    finished = finished + 1
    nextSend = Now()
    Changed()
    ScheduleTick()
end
-- Prices that a browse of the auction house has read into the price
-- database (a full scan, a search in the shop, another addon's scan) are the
-- same lowest unit prices a query of ours would bring: newer ones are taken
-- as they are, and what waited in the queue for them is done.
function P.TakeBrowsed()
    local store = HironCraftProfit_PriceDB and HironCraftProfit_PriceDB.realms
    local realm = (GetRealmName() or ''):gsub('%s+', '')
    local browsed = type(store) == 'table' and type(store[realm]) == 'table' and store[realm].items
    if type(browsed) ~= 'table' then return 0 end
    local db, catalog = DB()
    local taken = {}
    local count = 0
    for id in pairs(catalog) do
        local seen = browsed[tostring(id)]
        local price, at = type(seen) == 'table' and tonumber(seen.min), type(seen) == 'table' and tonumber(seen.t)
        local record = db.items[id]
        if price and price > 0 and at and at > (record and record.at or 0) then
            record = record or {}
            db.items[id] = record
            record.price, record.at = math.floor(price + 0.5), at
            record.attempt = math.max(record.attempt or 0, at)
            db.lastSuccess = math.max(db.lastSuccess or 0, at)
            taken[id] = true
            count = count + 1
        end
    end
    if count == 0 then return 0 end
    for index = #queue, 1, -1 do
        local id = queue[index]
        if taken[id] and not (pending and pending.id == id) then
            table.remove(queue, index)
            finished = finished + 1
        end
    end
    Changed()
    ScheduleTick()
    return count
end
local function HookBrowse()
    local prices = HironCraftProfit and HironCraftProfit.Prices
    if P.browseHooked or not (prices and prices.OnScanDone) then return end
    P.browseHooked = true
    prices:OnScanDone(function() P.TakeBrowsed() end)
end
function P.Start(force)
    if not open then Changed(); return false end
    if P.indexing then P.forceAfterIndex = force or P.forceAfterIndex; return false end
    if pending or #queue > 0 then return false end
    P.TakeBrowsed()
    local db, catalog = DB()
    -- The reagents returned lately first, and at every visit; the others
    -- after them, once a day. A click on the button asks for all of them.
    local current, rest = {}, {}
    local now = time()
    for id, seen in pairs(catalog) do
        local record = db.items[id]
        local lately = now - ReturnedAt(seen) <= P.currentFor
        local stale = not record or not record.at or now - record.at >= (lately and P.freshFor or P.restFreshFor)
        local retry = not record or not record.attempt or now - record.attempt >= P.retryAfter
        if force or (stale and retry) then
            local list = lately and current or rest
            list[#list + 1] = id
        end
    end
    local function LatestFirst(lhs, rhs)
        local left, right = ReturnedAt(catalog[lhs]), ReturnedAt(catalog[rhs])
        if left ~= right then return left > right end
        return lhs < rhs
    end
    table.sort(current, LatestFirst)
    table.sort(rest, LatestFirst)
    queue = current
    for _, id in ipairs(rest) do queue[#queue + 1] = id end
    -- Warm item-key data up front: the AH can silently ignore a search for
    -- an uncached key, otherwise costing the whole result timeout per item.
    if C_AuctionHouse and C_AuctionHouse.GetItemKeyInfo then
        for _, id in ipairs(queue) do C_AuctionHouse.GetItemKeyInfo(C_AuctionHouse.MakeItemKey(id)) end
    end
    total, finished = #queue, 0
    loadingSince = nil
    Changed()
    ScheduleTick()
    return true
end
function P.Tick()
    if not open then return end
    if UserBusy() then
        if pending then P.Suspend() end
        if not P.busy then P.busy = true; Changed() end
        return
    elseif P.busy then P.busy = nil; Changed() end
    if pending then
        if Now() - pending.at >= 12 then Complete(nil) end
        return
    end
    if #queue == 0 or Now() < nextSend or Now() < pausedUntil then return end
    if HironCraftProfit and HironCraftProfit.Prices and HironCraftProfit.Prices.scanning then return end
    local api = C_AuctionHouse
    if not api or not api.SendSearchQuery or not api.IsThrottledMessageSystemReady() then return end
    local id = queue[1]
    local key = api.MakeItemKey(id)
    if api.GetItemKeyInfo and not api.GetItemKeyInfo(key) then
        loadingSince = loadingSince or Now()
        if Now() - loadingSince < 5 then return end
        pending = { id=id }
        Complete(nil) -- don't stall the whole catalogue on one missing key
        return
    end
    loadingSince = nil
    pending = { id = id, key = key, at = Now() }
    local sorts = {}
    if Enum and Enum.AuctionHouseSortOrder then
        sorts[1] = { sortOrder=Enum.AuctionHouseSortOrder.Price, reverseSort=false }
    end
    sending = true
    local ok = pcall(api.SendSearchQuery, key, sorts, false)
    sending = false
    if not ok then Complete(nil) else Changed() end
end
function P.Results(event, item)
    if not pending or not open or Now() < pausedUntil or UserBusy() then return end
    local id = type(item) == 'table' and item.itemID or item
    if id ~= pending.id then return end
    local api, price = C_AuctionHouse, nil
    if event == 'COMMODITY_SEARCH_RESULTS_UPDATED' then
        if api.GetNumCommoditySearchResults(id) == 0 and api.HasFullCommoditySearchResults
            and not api.HasFullCommoditySearchResults(id) then return end
        for index = 1, api.GetNumCommoditySearchResults(id) do
            local row = api.GetCommoditySearchResultInfo(id, index)
            local amount = row and tonumber(row.unitPrice)
            if amount and amount > 0 then price = math.min(price or amount, amount) end
        end
    elseif event == 'ITEM_SEARCH_RESULTS_UPDATED' then
        if api.GetNumItemSearchResults(pending.key) == 0 and api.HasFullItemSearchResults
            and not api.HasFullItemSearchResults(pending.key) then return end
        for index = 1, api.GetNumItemSearchResults(pending.key) do
            local row = api.GetItemSearchResultInfo(pending.key, index)
            local amount = row and tonumber(row.buyoutAmount)
            if amount and amount > 0 then
                amount = amount / math.max(1, tonumber(row.quantity) or 1)
                price = math.min(price or amount, amount)
            end
        end
    else return end
    Complete(price)
end
-- Reads the returns of the whole journal into the catalogue, once. 2: with
-- the time of each reagent's last return (before 0.4.126 only that it was).
function P.IndexHistory()
    if P.indexing then return end
    local db = DB()
    if db.catalogIndexed == 2 then return end
    local log = Scan.AnalyticsLog
    if not log or not log.VisitReturnEvents or not log.Root() then return end
    P.indexing = true
    log.VisitReturnEvents(P.Observe, function()
        P.indexing = nil
        db.catalogIndexed = 2
        if open then P.Start(P.forceAfterIndex) end
        P.forceAfterIndex = nil
        Changed()
    end)
end
local events = CreateFrame('Frame')
for _, event in ipairs({ 'AUCTION_HOUSE_SHOW', 'AUCTION_HOUSE_CLOSED',
    'AUCTION_HOUSE_THROTTLED_SYSTEM_READY',
    'COMMODITY_SEARCH_RESULTS_UPDATED', 'ITEM_SEARCH_RESULTS_UPDATED', 'PLAYER_LOGIN' }) do events:RegisterEvent(event) end
events:SetScript('OnEvent', function(_, event, item)
    if event == 'PLAYER_LOGIN' then
        HookBrowse()
        P.IndexHistory()
    elseif event == 'AUCTION_HOUSE_SHOW' then
        open, pausedUntil, nextSend = true, Now() + 3, Now() + 3
        HookBrowse()
        P.IndexHistory()
        P.Start(false)
        if not P.timer then P.timer = C_Timer.NewTicker(0.25, P.Tick) end
    elseif event == 'AUCTION_HOUSE_CLOSED' then
        open, pending, queue, loadingSince = false, nil, {}, nil
        if P.timer then P.timer:Cancel(); P.timer = nil end
        Changed()
    elseif event == 'AUCTION_HOUSE_THROTTLED_SYSTEM_READY' then
        ScheduleTick()
    else P.Results(event, item) end
end)
-- These are observers, never automated purchases, sales, bids or cancellations.
if C_AuctionHouse and hooksecurefunc then
    for _, name in ipairs({ 'SendSearchQuery', 'SendSellSearchQuery', 'SendBrowseQuery',
        'SearchForItemKeys', 'ReplicateItems', 'RequestMoreBrowseResults',
        'RequestMoreCommoditySearchResults', 'RequestMoreItemSearchResults',
        'StartCommoditiesPurchase', 'ConfirmCommoditiesPurchase', 'PlaceBid',
        'PostItem', 'PostCommodity', 'CancelAuction' }) do
        if type(C_AuctionHouse[name]) == 'function' then hooksecurefunc(C_AuctionHouse, name, P.Suspend) end
    end
end
