-- Low-priority, exact-item price queries for the resourcefulness catalogue.
-- Historical AnalyticsLog events are never repriced.
local _, Scan = ...
local P = { freshFor = 900, retryAfter = 300, pauseFor = 15 }
Scan.ReturnPrices = P
local listeners, queue, pending, sending = {}, {}, nil, false
local open, pausedUntil, nextSend, total, finished = false, 0, 0, 0, 0
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
function P.Observe(event)
    if type(event) ~= 'table' or event.k ~= 'c' then return end
    local _, catalog = DB()
    for _, reagent in ipairs(event.rs or {}) do
        local id = tonumber(reagent.i)
        if id and id > 0 and reagent.c and (tonumber(reagent.n) or 0) > 0 then catalog[id] = true end
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
local function UserBusy()
    local shop = HironCraftProfit and HironCraftProfit.ShoppingList
    if shop and ((shop.scanAllState and shop.scanAllState.active) or shop.pendingSearchCommodityRow
        or next(shop.pendingSearchItemPurchases or {})) then return true end
    local ah = AuctionHouseFrame
    for _, key in ipairs({ 'CommoditiesBuyFrame', 'ItemBuyFrame', 'ItemSellFrame',
        'CommoditiesSellFrame', 'BuyDialog' }) do
        if ah and ah[key] and ah[key]:IsShown() then return true end
    end
    return false
end
function P.Status()
    local db, catalog = DB()
    local count = 0
    for _ in pairs(catalog) do count = count + 1 end
    return { open = open, total = total, finished = finished, catalog = count,
        running = pending ~= nil or #queue > 0, paused = Now() < pausedUntil or UserBusy(),
        at = db.lastSuccess, indexing = P.indexing }
end
function P.Suspend()
    if sending or not open then return end
    pausedUntil = Now() + P.pauseFor
    -- Keep this item queued, but discard the interrupted query's reply.
    pending = nil
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
    pending = nil
    table.remove(queue, 1)
    finished = finished + 1
    nextSend = Now() + 1
    Changed()
end
function P.Start(force)
    if not open then Changed(); return false end
    if P.indexing then P.forceAfterIndex = force or P.forceAfterIndex; return false end
    if pending or #queue > 0 then return false end
    local db, catalog = DB()
    queue = {}
    for id in pairs(catalog) do
        local record = db.items[id]
        local stale = not record or not record.at or time() - record.at >= P.freshFor
        local retry = not record or not record.attempt or time() - record.attempt >= P.retryAfter
        if force or (stale and retry) then queue[#queue + 1] = id end
    end
    table.sort(queue)
    total, finished = #queue, 0
    nextSend = math.max(nextSend, Now() + 1)
    Changed()
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
function P.IndexHistory()
    if P.indexing then return end
    local db = DB()
    if db.catalogIndexed then return end
    local log = Scan.AnalyticsLog
    if not log or not log.VisitReturnEvents or not log.Root() then return end
    P.indexing = true
    log.VisitReturnEvents(P.Observe, function()
        P.indexing = nil
        db.catalogIndexed = true
        if open then P.Start(P.forceAfterIndex) end
        P.forceAfterIndex = nil
        Changed()
    end)
end
local events = CreateFrame('Frame')
for _, event in ipairs({ 'AUCTION_HOUSE_SHOW', 'AUCTION_HOUSE_CLOSED',
    'COMMODITY_SEARCH_RESULTS_UPDATED', 'ITEM_SEARCH_RESULTS_UPDATED', 'PLAYER_LOGIN' }) do events:RegisterEvent(event) end
events:SetScript('OnEvent', function(_, event, item)
    if event == 'PLAYER_LOGIN' then
        P.IndexHistory()
    elseif event == 'AUCTION_HOUSE_SHOW' then
        open, pausedUntil, nextSend = true, Now() + 3, Now() + 3
        P.IndexHistory()
        P.Start(false)
        if not P.timer then P.timer = C_Timer.NewTicker(1, P.Tick) end
    elseif event == 'AUCTION_HOUSE_CLOSED' then
        open, pending, queue = false, nil, {}
        if P.timer then P.timer:Cancel(); P.timer = nil end
        Changed()
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
