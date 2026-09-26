-- Posting from the Sell tab against a mocked auction house: the first item is
-- chosen by itself, the next item's prices are asked for ahead of time, a
-- press of the post key is kept (never lost, never done at a guessed price),
-- and the auction house's few requests at a time are never exceeded.
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
local searches, posts = {}, {}
local market = {                -- itemID -> { {unitPrice, quantity}, ... }
    [11] = { { 500, 20 }, { 520, 40 } },
    [12] = { { 900, 5 } },
    [13] = { { 300, 100 } },
}
local eventHandler
local S = { RefreshSellUI = noop, frame = { IsShown = function() return true end } }
local E = setmetatable({
    PT = {}, S = S,
    GetTime = function() return now end,
    GetMoney = function() return 10 ^ 9 end,
    T = function(_, fallback) return fallback end,
    CreateFrame = function() return { RegisterEvent = noop, SetScript = function(_, _, fn) eventHandler = fn end,
        RegisterForClicks = noop, Hide = noop } end,
    C_Timer = { After = noop },
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
        PostCommodity = function(loc, _, qty, price) posts[#posts + 1] = { bag = loc.bag, slot = loc.slot, qty = qty, price = price } end,
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
    { key = 'c:13', itemID = 13, count = 50, bag = 0, slot = 3, isCommodity = true, itemName = 'C' },
}
S.ScanSellBags = function(self) self.sell.items = bags return bags end
local function arrive(itemID) eventHandler(nil, 'COMMODITY_SEARCH_RESULTS_UPDATED', itemID) end
local function readyAgain() ready = true; eventHandler(nil, 'AUCTION_HOUSE_THROTTLED_SYSTEM_READY') end

-- Opening the Sell tab chooses the first item and asks for its prices.
S:RefreshSellList()
assert(S.sell.selected and S.sell.selected.key == 'c:11', 'the first item was not chosen')
assert(#searches == 1 and searches[1] == 11)
-- A press before the prices are in is kept, not done at a guessed price.
S:RunSellHotkeyAction()
assert(#posts == 0 and S.sell.postQueued, 'posted before the prices came')
arrive(11)
assert(#posts == 1 and posts[1].price == 500 and posts[1].qty == 30,
    'the kept press was not done with the fresh price: ' .. tostring(posts[1] and posts[1].price))
-- The next item was chosen and, its prices not yet asked for, asked now.
assert(S.sell.selected.key == 'c:12')
local asked = {}
for _, id in ipairs(searches) do asked[id] = (asked[id] or 0) + 1 end
assert(asked[12] == 1, 'the next item was not searched')

-- With the prices of item B in, item C's are asked for ahead of time.
arrive(12)
local cAsked = 0
for _, id in ipairs(searches) do if id == 13 then cAsked = cAsked + 1 end end
assert(cAsked == 1, 'the item after the current one was not asked for ahead of time')
arrive(13)
-- Posting B: C is chosen with its prices already in hand, no new search.
now = now + 1
local before = #searches
S:RunSellHotkeyAction()
assert(#posts == 2 and posts[2].price == 900, 'B was not posted')
assert(S.sell.selected.key == 'c:13' and S.sell.scan and not S.sell.scan.pending and S.sell.price == 300,
    'C did not come with its prices already read')
assert(#searches == before, 'C was searched again although its prices were a moment old')

-- The auction house is busy: the press waits for it instead of being lost.
now = now + 1
ready = false
S:RunSellHotkeyAction()
assert(#posts == 2 and S.sell.postQueued, 'a press during the throttle was lost or sent')
readyAgain()
assert(#posts == 3 and posts[3].price == 300, 'the kept press was not done when the auction house was ready')

-- A kept press for an item no longer chosen, or too old, is dropped.
bags[#bags + 1] = { key = 'c:14', itemID = 14, count = 1, bag = 0, slot = 4, isCommodity = true, itemName = 'D' }
market[14] = { { 1000, 1 } }
S.sell.selected = nil
S:RefreshSellList()
now = now + 1
ready = false
S:RunSellHotkeyAction()
now = now + 10
readyAgain()
arrive(14)
assert(#posts == 3, 'a press from long ago was done')

-- Closing the auction house forgets kept presses and prices.
S.sell.postQueued = { key = 'c:14', at = now }
eventHandler(nil, 'AUCTION_HOUSE_CLOSED')
assert(not S.sell.postQueued and not S.sell.priceCache, 'closing kept a press or old prices')
print('Sell posting passed (first item, kept presses, prices ahead, throttle, stale presses, closing).')
