local now, clock, frames, calls = 0, 10000, {}, {}
GetTime = function() return now end
time = function() return clock end
GetRealmName = function() return 'Test Realm' end
CreateFrame = function()
    local f = { RegisterEvent = function() end, SetScript = function(self, _, fn) self.event = fn end }
    frames[#frames + 1] = f
    return f
end
C_Timer = { NewTicker = function() return { Cancel = function() end } end }
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
AuctionHouseFrame = nil
P.Tick(); assert(calls[1] == 101)
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
