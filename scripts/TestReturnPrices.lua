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
