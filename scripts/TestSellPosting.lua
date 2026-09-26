-- Posting from the Sell tab against a mocked auction house: the first item is
-- chosen by itself, requests go one at a time, a press of the post key while
-- the auction house is busy is kept and done when it is ready, and a request
-- the auction house drops brings its item back into the list.
local function noop() end
if not setfenv then
    function setfenv(fn, env)
        if type(fn)=='number' then fn=debug.getinfo(fn+1,'f').func end
        for i=1,100 do
            local name=debug.getupvalue(fn,i)
            if not name then return fn end
            if name=='_ENV' then
                debug.upvaluejoin(fn,i,function() return env end,1)
                return fn
            end
        end
    end
end

local now = 100
local ready = true              -- C_AuctionHouse.IsThrottledMessageSystemReady
local searches, posts, timers = {}, {}, {}
local market = {                -- itemID -> { {unitPrice, quantity}, ... }
    [11] = { { 500, 20 }, { 520, 40 } },
    [12] = { { 900, 5 } },
}
local eventHandler
local refreshes = 0
local S = { RefreshSellUI = noop, frame = { IsShown = function() return true end } }
local E = setmetatable({
    PT = {}, S = S,
    GetTime = function() return now end,
    GetMoney = function() return 10 ^ 9 end,
    T = function(_, fallback) return fallback end,
    CreateFrame = function() return { RegisterEvent = noop, SetScript = function(_, _, fn) eventHandler = fn end,
        RegisterForClicks = noop, Hide = noop } end,
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    Enum = { ItemCommodityStatus = { Unknown = 0, Item = 1, Commodity = 2 },
        AuctionHouseSortOrder = { Price = 0 } },
    ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot)
        return { bag = bag, slot = slot, IsValid = function() return true end } end },
    C_Item = { DoesItemExist = function() return true end },
    C_AuctionHouse = {
        MakeItemKey = function(itemID) return { itemID = itemID } end,
        SendSearchQuery = function(itemKey) searches[#searches + 1] = itemKey.itemID end,
        IsThrottledMessageSystemReady = function() return ready end,
        GetItemCommodityStatus = function() return 2 end,
        GetNumCommoditySearchResults = function(itemID) return #(market[itemID] or {}) end,
        GetCommoditySearchResultInfo = function(itemID, i)
            local r = market[itemID][i]
            return { unitPrice = r[1], quantity = r[2] }
        end,
        GetNumItemSearchResults = function() return 0 end,
        GetItemSearchResultInfo = function() return nil end,
        PostCommodity = function(loc, _, qty, price) posts[#posts + 1] = { slot = loc.slot, qty = qty, price = price } end,
        GetAvailablePostCount = function() return 1000 end,
        CalculateCommodityDeposit = function() return 1 end,
    },
}, { __index = _G })
HironCraftProfitShoppingListEnv = E
dofile('ProfitHub/Shop/Core/ShoppingList_Selling.lua')
S.isAuctionHouseOpen = true
S.shopTab = 'sell'

local bags = {
    { key = 'c:11', itemID = 11, count = 30, bag = 0, slot = 1, isCommodity = true, itemName = 'A' },
    { key = 'c:12', itemID = 12, count = 4, bag = 0, slot = 2, isCommodity = true, itemName = 'B' },
}
S.ScanSellBags = function(self)
    local copy = {}
    for i, e in ipairs(bags) do copy[i] = e end
    self.sell.items = copy
    refreshes = refreshes + 1
    return copy
end
local function arrive(itemID) eventHandler(nil, 'COMMODITY_SEARCH_RESULTS_UPDATED', itemID) end
local function readyAgain() ready = true; eventHandler(nil, 'AUCTION_HOUSE_THROTTLED_SYSTEM_READY') end
local function runTimers() local list = timers; timers = {}; for _, fn in ipairs(list) do fn() end end

-- Opening the Sell tab chooses the first item and asks for its prices.
S:RefreshSellList()
assert(S.sell.selected and S.sell.selected.key == 'c:11', 'the first item was not chosen')
assert(#searches == 1 and searches[1] == 11, 'the first item\'s prices were not asked for')
arrive(11)
assert(S.sell.price == 500)

-- A press posts at once when the auction house is ready, then the next
-- item's prices are asked for.
S:RunSellHotkeyAction()
assert(#posts == 1 and posts[1].price == 500 and posts[1].qty == 30, 'the press did not post')
assert(S.sell.selected.key == 'c:12' and searches[#searches] == 12)
arrive(12)

-- The auction house is busy: the press is kept, not lost, and done when it is
-- ready - one request, the post; nothing else goes with it.
now = now + 1
ready = false
local before = #searches
S:RunSellHotkeyAction()
assert(#posts == 1 and S.sell.postQueued, 'a press during the throttle was lost or sent')
readyAgain()
assert(#posts == 2 and posts[2].price == 900, 'the kept press was not done when the auction house was ready')
assert(not S.sell.postQueued and #searches == before, 'more than one request went at once')

-- A kept press from too long ago is dropped.
bags = { { key = 'c:11', itemID = 11, count = 5, bag = 0, slot = 1, isCommodity = true, itemName = 'A' } }
S.sell.selected = nil
S:RefreshSellList()
arrive(11)
now = now + 1
ready = false
S:RunSellHotkeyAction()
now = now + 10
readyAgain()
assert(#posts == 2 and not S.sell.postQueued, 'a press from long ago was done')

-- A request the auction house dropped: the list is read again, so an item it
-- did not post comes back.
local refreshesBefore = refreshes
eventHandler(nil, 'AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED')
now = now + 1
runTimers()
assert(refreshes > refreshesBefore, 'a dropped request did not bring the bags back')

-- Closing the auction house forgets a kept press.
S.sell.postQueued = { key = 'c:11', at = now }
eventHandler(nil, 'AUCTION_HOUSE_CLOSED')
assert(not S.sell.postQueued, 'closing kept a press')
print('Sell posting passed (first item, one request at a time, kept presses, stale presses, dropped requests, closing).')
