local now, clock, frames, calls = 0, 10000, {}, {}
GetTime = function() return now end
time = function() return clock end
GetRealmName = function() return 'Test Realm' end
CreateFrame = function()
    local f = { RegisterEvent = function() end, SetScript = function(self, _, fn) self.event = fn end }
    frames[#frames + 1] = f
    return f
end
local timers = {}
C_Timer = { NewTicker = function(interval) assert(interval == 0.25); return { Cancel = function() end } end,
    After = function(_, fn) timers[#timers+1] = fn end }
local function Flush()
    local list = timers; timers = {}; for _, fn in ipairs(list) do fn() end
end
hooksecurefunc = function(target, key, fn)
    local original = target[key]
    target[key] = function(...) local result = original(...); fn(...); return result end
end
local ready, amount = true, 300
C_AuctionHouse = {
    IsThrottledMessageSystemReady = function() return ready end,
    MakeItemKey = function(id) return { itemID = id, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 } end,
    SendSearchQuery = function(key) calls[#calls + 1] = key.itemID end,
    SendBrowseQuery = function() end,
    GetNumCommoditySearchResults = function() return amount and 1 or 0 end,
    GetCommoditySearchResultInfo = function() return { unitPrice = amount } end,
    GetNumItemSearchResults = function() return 1 end,
    GetItemSearchResultInfo = function() return { buyoutAmount = 800, quantity = 2 } end,
}
local Scan = { AnalyticsLog = {
    Root = function() return {} end,
    VisitReturnEvents = function(visit, done)
        visit({ k = 'c', rs = { { i = 101, n = 3, c = 1 }, { i = 102, n = 1, c = 1 },
            { i = 999, n = 9 }, { i = 101, n = 2, c = 1 } } })
        done()
    end,
} }
assert(loadfile('Customer/ReturnPrices.lua'))('HironCraft', Scan)
local P, event = Scan.ReturnPrices, frames[1].event
event(nil, 'PLAYER_LOGIN')
assert(P.Status().catalog == 2 and #calls == 0)
assert(not P.GetPrice(101))
event(nil, 'AUCTION_HOUSE_SHOW')
P.Tick()
assert(#calls == 0)
now = 4; ready = false; P.Tick(); assert(#calls == 0, 'ignored AH throttle')
ready = true
AuctionHouseFrame = { CommoditiesBuyFrame={IsShown=function() return true end} }
P.Tick()
assert(#calls==0 and P.Status().paused, 'background scan ran inside an active purchase')
AuctionHouseFrame.CommoditiesBuyFrame.IsVisible = function() return false end
P.Tick(); assert(calls[1] == 101)
AuctionHouseFrame = nil
P.Results('COMMODITY_SEARCH_RESULTS_UPDATED', 777); assert(not P.GetPrice(101))
C_AuctionHouse.SendBrowseQuery({})
P.Results('COMMODITY_SEARCH_RESULTS_UPDATED', 101)
assert(not P.GetPrice(101) and P.Status().paused, 'an interrupted reply was accepted')
now = 20; P.Tick()
assert(calls[2] == 101, 'interrupted item was dropped')
P.Results('COMMODITY_SEARCH_RESULTS_UPDATED', 101)
assert(P.GetPrice(101) == 300)
now = 22; P.Tick()
P.Results('ITEM_SEARCH_RESULTS_UPDATED', { itemID = 102 })
assert(P.GetPrice(102) == 400 and P.Status().finished == 2)
event(nil, 'AUCTION_HOUSE_CLOSED')
local n = #calls; P.Tick(); assert(#calls == n)
event(nil, 'AUCTION_HOUSE_SHOW')
assert(P.Status().total == 0, 'fresh prices were rescanned')
P.Start(true); now = 30; P.Tick()
amount = nil; P.Results('COMMODITY_SEARCH_RESULTS_UPDATED', 101)
assert(P.GetPrice(101) == 300, 'empty result erased a valid price')
now = 32; P.Tick()
now = 45; P.Tick()
assert(P.GetPrice(102) == 400 and not P.Status().running, 'timeout erased a valid price')
P.Observe({ k = 'c', rs = { { i = 103, n = 1, c = 1 } } })
event(nil, 'AUCTION_HOUSE_CLOSED')
P.Results('COMMODITY_SEARCH_RESULTS_UPDATED', 103)
assert(not P.GetPrice(103))
event(nil, 'AUCTION_HOUSE_SHOW')
assert(P.Status().total == 1, 'unpriced new reagent was missed')
now = 50; P.Tick()
assert(calls[#calls] == 103)
print('Targeted return prices passed (catalogue, quality IDs, throttle, interruption, stale/late replies, expiry, no-listings, timeout, close).')

-- Complete -> next request in the next frame, no fixed per-item wait.
P.Results('COMMODITY_SEARCH_RESULTS_UPDATED', 103)
local button = {scripts={}}
function button:SetText(text) self.text=text end
function button:SetScript(key,fn) self.scripts[key]=fn end
function button:HookScript(key,fn) self.scripts[key]=fn end
Scan.LOCAL = {GetText=function(_,text) return text end}
P.AttachScanButton(button)
assert(button.text=='Scan reagent prices')
local known, warm = {[101]=true, [102]=true}, {}
C_AuctionHouse.GetItemKeyInfo = function(key)
    warm[key.itemID]=true
    return known[key.itemID] and {} or nil
end
button.scripts.OnClick()
assert(warm[101] and warm[102] and warm[103], 'item keys were not prefetched')
assert(button.text=='Scanning 0/3')
Flush(); assert(calls[#calls]==101)
amount = 350
P.Results('COMMODITY_SEARCH_RESULTS_UPDATED',101)
local first = #calls
ready=false; Flush(); assert(#calls==first, 'event-driven scan ignored throttle')
ready=true; event(nil,'AUCTION_HOUSE_THROTTLED_SYSTEM_READY'); Flush()
assert(#calls==first+1 and calls[#calls]==102, 'ready event waited for a timer')
P.Results('COMMODITY_SEARCH_RESULTS_UPDATED',102); Flush()
assert(#calls==first+1, 'uncached item search was sent and would time out')
known[103]=true; P.Tick(); assert(calls[#calls]==103)
P.Results('COMMODITY_SEARCH_RESULTS_UPDATED',103); Flush()
assert(not P.Status().running and button.text=='Scan reagent prices', 'button did not mirror completion')

-- Manual selling owns the AH even when Blizzard's own sale panel is hidden.
button.scripts.OnClick()
HironCraftProfit = {ShoppingList={sell={scan={pending=true}}}}
first=#calls; Flush(); assert(#calls==first and P.Status().paused)
HironCraftProfit.ShoppingList.sell.scan.pending=false
C_AuctionHouse.SendBrowseQuery({}); now=now+1; P.Tick(); assert(#calls==first)
now=now+1.1; P.Tick(); assert(#calls==first+1, 'manual activity still imposes a 15-second delay')
P.Results('COMMODITY_SEARCH_RESULTS_UPDATED',101)
event(nil,'AUCTION_HOUSE_CLOSED'); Flush()
assert(#calls==first+1 and button.text=='Scan reagent prices', 'queued work ran after AH close')

-- One never-loaded item has a bounded wait and retains its last good price.
HironCraftProfit=nil; known[101]=nil
event(nil,'AUCTION_HOUSE_SHOW'); P.Start(true)
now=now+4; Flush(); first=#calls
now=now+5.1; P.Tick(); Flush()
assert(calls[#calls]==102 and #calls==first+1 and P.GetPrice(101)==350)
print('Fast reagent scan passed (button, prefetch, event-driven queue, throttling, manual priority, bounded cache wait, no stale callbacks).')

-- What matters first: a visit to the auction house updates the reagents that
-- came back lately before the rest, and takes prices it has already seen.
do
    event(nil, 'AUCTION_HOUSE_CLOSED'); Flush()
    C_AuctionHouse.GetItemKeyInfo = nil
    HironCraftProfit = nil
    AuctionHouseFrame = nil
    amount, ready = 500, true
    clock = 2000000
    local DAY = 24 * 3600
    local db = HironCraftProfit_PriceDB
    assert(db.returnRealms.TestRealm.catalogIndexed == 2, 'the history was not read with the times of the returns')
    -- Returned a minute, an hour and a day ago; 8 days ago; and one kept from
    -- before the time of a return was recorded.
    db.returnCatalog = { [201] = clock - 3600, [202] = clock - DAY, [203] = clock - 8 * DAY, [204] = true, [205] = clock - 60 }
    db.returnRealms.TestRealm.items = {}
    assert(P.Status().catalog == 5 and P.Status().current == 3, 'the reagents returned lately are counted wrong')

    local function visit(expected, what)
        event(nil, 'AUCTION_HOUSE_SHOW')
        assert(P.Status().total == #expected, what .. ': ' .. P.Status().total .. ' queued, not ' .. #expected)
        now = now + 4
        for _, id in ipairs(expected) do
            P.Tick(); Flush()
            assert(calls[#calls] == id, what .. ': asked for ' .. tostring(calls[#calls]) .. ', not ' .. id)
            P.Results('COMMODITY_SEARCH_RESULTS_UPDATED', id)
            Flush()
        end
        assert(not P.Status().running, what .. ': the scan did not end')
        event(nil, 'AUCTION_HOUSE_CLOSED'); Flush()
    end
    -- Nothing is priced: all of them, the latest return first, then the old ones.
    visit({ 205, 201, 202, 203, 204 }, 'first visit')
    assert(P.GetPrice(205) == 500 and P.GetPrice(204) == 500)
    -- A quarter of an hour later: the reagents of this week again, the others not.
    clock = clock + 16 * 60
    visit({ 205, 201, 202 }, 'next visit')
    -- Five minutes later nothing is old enough.
    clock = clock + 5 * 60
    visit({}, 'a visit right after')
    -- The next day the others are due as well, after the current ones.
    clock = clock + DAY
    visit({ 205, 201, 202, 203, 204 }, 'the next day')
    -- A new return makes its reagent the first.
    clock = clock + 16 * 60
    P.Observe({ k = 'c', t = clock, rs = { { i = 203, n = 2, c = 1 } } })
    assert(P.Status().current == 4)
    visit({ 203, 205, 201, 202 }, 'after a new return')
    -- A return recorded earlier than the one known does not move it back.
    P.Observe({ k = 'c', t = clock - 3 * DAY, rs = { { i = 203, n = 1, c = 1 } } })
    assert(db.returnCatalog[203] == clock, 'an older return replaced the time of the last one')

    -- A price a browse of the auction house has read is taken when it is
    -- newer than ours, and not asked for again.
    clock = clock + 16 * 60
    db.realms = { TestRealm = { items = {
        ['205'] = { min = 777.4, market = 777.4, t = clock, q = 10 },
        ['201'] = { min = 5, market = 5, t = 1, q = 1 },
        ['999'] = { min = 1, market = 1, t = clock, q = 1 },
    } } }
    local before = P.GetPrice(201)
    assert(P.TakeBrowsed() == 1 and P.GetPrice(205) == 777 and select(2, P.GetPrice(205)) == clock,
        'a newer browsed price was not taken')
    assert(P.GetPrice(201) == before and not P.GetPrice(999), 'an older browsed price, or one outside the catalogue, was taken')
    assert(P.TakeBrowsed() == 0, 'the same browsed price was taken twice')
    visit({ 203, 201, 202 }, 'after a browse')
    -- While a scan waits, what a browse brings leaves the queue; the browse
    -- is heard through the price module's own notice.
    local heard
    HironCraftProfit = { Prices = { OnScanDone = function(_, fn) heard = fn end } }
    clock = clock + 16 * 60
    event(nil, 'AUCTION_HOUSE_SHOW')
    assert(type(heard) == 'function', 'the scanner does not listen to browses')
    HironCraftProfit = nil
    assert(P.Status().total == 4 and P.Status().finished == 0)
    db.realms.TestRealm.items['201'] = { min = 42, market = 42, t = clock, q = 3 }
    db.realms.TestRealm.items['202'] = { min = 43, market = 43, t = clock, q = 3 }
    heard(2)
    assert(P.GetPrice(201) == 42 and P.GetPrice(202) == 43 and P.Status().finished == 2, 'browsed prices did not shorten the queue')
    now = now + 4
    P.Tick(); Flush(); assert(calls[#calls] == 203)
    P.Results('COMMODITY_SEARCH_RESULTS_UPDATED', 203); Flush()
    assert(calls[#calls] == 205, 'the queue lost its order after a browse')
    P.Results('COMMODITY_SEARCH_RESULTS_UPDATED', 205); Flush()
    assert(not P.Status().running and P.Status().finished == 4)
    event(nil, 'AUCTION_HOUSE_CLOSED'); Flush()

    -- A click asks for everything, the current ones first.
    event(nil, 'AUCTION_HOUSE_SHOW')
    assert(P.Status().total == 0)
    button.scripts.OnClick()
    assert(P.Status().total == 5, 'a click did not ask for the whole catalogue')
    now = now + 4; P.Tick(); Flush()
    assert(calls[#calls] == 203, 'a click does not start with the latest return')
    event(nil, 'AUCTION_HOUSE_CLOSED'); Flush()

    -- The tooltip says how many there are and how many are current.
    local lines = {}
    GameTooltip = { SetOwner = function() end, SetText = function(_, text) lines[#lines + 1] = text end,
        AddLine = function(_, text) lines[#lines + 1] = text end, Show = function() end, Hide = function() end }
    date = os.date
    button.scripts.OnEnter(button)
    assert(table.concat(lines, '\n'):find('Reagents: 5, returned in the last week: 4', 1, true),
        'the tooltip does not count the reagents: ' .. table.concat(lines, ' | '))

    -- A catalogue from before the times were kept is read again, once.
    db.returnCatalog = { [101] = true }
    db.returnRealms.TestRealm.catalogIndexed = true
    event(nil, 'PLAYER_LOGIN')
    assert(type(db.returnCatalog[101]) == 'number' and db.returnRealms.TestRealm.catalogIndexed == 2,
        'an old catalogue did not get the times of its returns')
end
print('Reagent scan order passed (latest returns first, every visit / once a day, new return, browsed prices, click, old catalogue).')
