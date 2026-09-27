-- Real selling functions with asynchronous auction/bag events. No live trades.
local function noop() end
if not setfenv then
    function setfenv(fn, env)
        if type(fn) == 'number' then fn = debug.getinfo(fn + 1, 'f').func end
        for i = 1, 100 do
            local name = debug.getupvalue(fn, i)
            if not name then return fn end
            if name == '_ENV' then
                debug.upvaluejoin(fn, i, function() return env end, 1)
                return fn
            end
        end
    end
end

local now, bags, timers, posts, confirmations, messages, warnings, searches
local mode, popup, handler, ready
local registered = {}
local S = { RefreshSellUI = noop, frame = { IsShown = function() return true end } }
local E = setmetatable({ PT = {}, S = S,
    T = function(_, fallback) return fallback end,
    GetTime = function() return now end,
    GetMoney = function() return 100000000 end,
    print = function(text) warnings[#warnings + 1] = text end,
    DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) messages[#messages + 1] = text end },
    CreateFrame = function() return {
        RegisterEvent = function(_, event) registered[event] = true end,
        SetScript = function(_, _, fn) handler = fn end,
    } end,
    C_Timer = { After = function(delay, fn) timers[#timers + 1] = { time = now + delay, fn = fn } end },
    Enum = { ItemCommodityStatus = { Unknown = 0, Item = 1, Commodity = 2 }, BagIndex = { ReagentBag = 5 } },
    ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot)
        return { bag = bag, slot = slot, IsValid = function() return bags[slot] ~= nil end }
    end },
    C_Container = {
        GetContainerNumSlots = function(bag) return bag == 0 and 6 or 0 end,
        GetContainerItemInfo = function(_, slot) return bags[slot] end,
        GetContainerItemID = function(_, slot) return bags[slot] and bags[slot].itemID end,
    },
    C_Item = {
        DoesItemExist = function(loc) return bags[loc.slot] ~= nil end,
        GetItemInfo = function(link) return link, nil, 1, nil, nil, nil, nil, nil, nil, nil, nil, 7 end,
    },
    StaticPopupDialogs = {}, ACCEPT = 'Accept', CANCEL = 'Cancel',
    CONFIRM_AUCTION_POSTING_TEXT = 'Auction warning',
    StaticPopup_Show = function(key, text, details, data)
        popup = { key = key, data = data, details = details, text = text }
        return popup
    end,
    StaticPopup_Hide = function(key) if popup and popup.key == key then popup = nil end end,
}, { __index = _G })
local function emit(event, ...) assert(registered[event], event); handler(nil, event, ...) end
local function post(...)
    posts[#posts + 1] = { ... }
    if mode == 'throw' then error('post failed') end
    if mode == 'error' then emit('AUCTION_HOUSE_POST_ERROR') end
    return mode == 'confirmation'
end
E.C_AuctionHouse = {
    PostCommodity = post, PostItem = post,
    ConfirmPostCommodity = function(...) confirmations[#confirmations + 1] = { ... } end,
    ConfirmPostItem = function(...) confirmations[#confirmations + 1] = { ... } end,
    IsThrottledMessageSystemReady = function() return ready end,
    MakeItemKey = function(id) return { itemID = id, itemLevel = 0 } end,
    GetItemKeyFromItem = function(loc) return { itemID = bags[loc.slot].itemID, itemLevel = 10 } end,
    SendSearchQuery = function(...) searches[#searches + 1] = { ... } end,
    GetNumCommoditySearchResults = function() return 0 end,
    GetCommoditySearchResultInfo = noop,
    GetNumItemSearchResults = function() return 0 end,
    GetItemSearchResultInfo = noop,
    GetItemCommodityStatus = function(loc)
        local info = type(loc) == 'table' and bags[loc.slot]
        return info and info.equipment and 1 or 2
    end,
    IsSellItemValid = function(loc) return bags[loc.slot] and not bags[loc.slot].isBound end,
    GetAvailablePostCount = function(loc)
        local info, total = bags[loc.slot], 0
        if not info then return 0 end
        for _, stack in pairs(bags) do
            if stack.itemID == info.itemID and not stack.isBound then total = total + stack.stackCount end
        end
        return total
    end,
    CalculateCommodityDeposit = function() return 100 end,
    CalculateItemDeposit = function() return 100 end,
}
HironCraftProfitShoppingListEnv = E
dofile('ProfitHub/Shop/Core/ShoppingList_Selling.lua')

local function advance(seconds)
    local untilTime = now + seconds
    for _ = 1, 1000 do
        table.sort(timers, function(a, b) return a.time < b.time end)
        if not timers[1] or timers[1].time > untilTime then now = untilTime; return end
        local timer = table.remove(timers, 1)
        now = timer.time
        timer.fn()
    end
    error('timer loop')
end
local function stack(id, count, extra)
    local info = { itemID = id, stackCount = count, hyperlink = 'item:' .. id, quality = 1 }
    for key, value in pairs(extra or {}) do info[key] = value end
    return info
end
local function reset(extra)
    now, bags, timers, posts, confirmations, messages, warnings, searches = 100, {}, {}, {}, {}, {}, {}, {}
    mode, ready, popup = 'normal', true, nil
    _G.HironCraftProfit_DB = nil
    S.sell = { items = {}, quantity = 0, price = 0, duration = 2 }
    S._lastPostKey, S._lastPostTime, S._lastSellPostTime = nil, nil, nil
    S._pendingSellScan, S._sellRefreshPending, S._sellRescanTries = nil, nil, nil
    S.isAuctionHouseOpen, S.shopTab = true, 'sell'
    bags[1], bags[2] = stack(1001, 13, extra), stack(1002, 2)
    S:RefreshSellList()
    S:SelectSellItem(S.sell.items[1])
    S:OnSellSearchResults(not extra, extra and { itemID = 1001, itemLevel = 10 } or 1001)
    S.sell.price = 2389900
end
local checked = 0
local function check(ok, why) assert(ok, why); checked = checked + 1 end

reset()
check(S:PostSellItem(), 'initial post rejected')
check(#posts == 1 and #messages == 0 and #S.sell.items == 2, 'request was counted as a successful auction')
check(not E.GetSellLastPrices()[1001], 'unconfirmed price persisted')
local pending = S.sell.awaitingPost
for _ = 1, 10 do S:RunSellHotkeyAction(); S:PostSellItem() end
S:SkipSellItem(); S:SelectSellItem(S.sell.items[2]); S:ClearSellSelection(); S:RefreshSellList()
check(#posts == 1 and S.sell.selected.itemID == 1001 and S.sell.awaitingPost == pending, 'pending post bypassed')
emit('AUCTION_HOUSE_AUCTION_CREATED', 11)
check(S.sell.awaitingPost and #messages == 0, 'advanced before bags updated')
bags[1] = nil
emit('BAG_UPDATE_DELAYED')
check(not S.sell.awaitingPost and S.sell.selected.itemID == 1002 and #S.sell.items == 1, 'confirmed item did not advance')
check(#messages == 1 and E.GetSellLastPrices()[1001] == 2389900, 'missing confirmed record')
emit('AUCTION_HOUSE_AUCTION_CREATED', 11); advance(1)
check(#messages == 1 and #posts == 1, 'duplicate success event or timer posted another auction')
check(not S:PostSellItem(), 'next item posted at seeded price before search completed')

reset()
S:PostSellItem(); bags[1] = nil; emit('BAG_UPDATE_DELAYED'); advance(1)
check(S.sell.awaitingPost and S.sell.selected.itemID == 1001 and #messages == 0, 'bag event alone confirmed sale')
emit('AUCTION_HOUSE_AUCTION_CREATED', 12)
check(#messages == 1 and S.sell.selected.itemID == 1002, 'bag-first confirmation failed')

reset()
S.sell.quantity = 5
S:PostSellItem(); bags[1].stackCount = 8
emit('AUCTION_HOUSE_AUCTION_CREATED', 13); emit('BAG_UPDATE_DELAYED'); advance(1)
check(S.sell.selected.itemID == 1001 and S.sell.selected.count == 8 and S.sell.quantity == 5,
    'partial stack was subtracted twice or skipped')
check(#messages == 1 and messages[1]:find('x5', 1, true), 'wrong posted quantity')

reset()
mode = 'confirmation'; S:PostSellItem()
pending = S.sell.awaitingPost
check(popup and pending.phase == 'confirmation' and #confirmations == 0, 'warning was not shown')
advance(25); S:RunSellHotkeyAction(); emit('AUCTION_HOUSE_AUCTION_CREATED', 999)
check(#posts == 1 and #confirmations == 0 and #messages == 0, 'warning was auto-confirmed')
S.sell.price, S.sell.quantity, S.sell.duration = 100, 1, 3
check(not S:ConfirmSellPost(pending, false), 'confirmation lacked click guard')
E.StaticPopupDialogs[popup.key].OnAccept(nil, pending)
E.StaticPopupDialogs[popup.key].OnAccept(nil, pending)
check(#confirmations == 1 and confirmations[1][2] == 2 and confirmations[1][3] == 13
    and confirmations[1][4] == 2389900, 'confirmation changed frozen values or duplicated')
bags[1] = nil; emit('AUCTION_HOUSE_AUCTION_CREATED', 14)
check(#messages == 1 and not S.sell.awaitingPost, 'confirmed warning did not complete')

reset()
mode = 'confirmation'; S:PostSellItem()
E.StaticPopupDialogs[popup.key].OnCancel(nil, popup.data)
check(not S.sell.awaitingPost and S.sell.selected.itemID == 1001 and #confirmations == 0, 'cancel removed the item')

for _, failure in ipairs({ 'throw', 'error', 'AUCTION_HOUSE_SHOW_ERROR' }) do
    reset(); mode = failure; S:PostSellItem()
    if failure == 'AUCTION_HOUSE_SHOW_ERROR' then emit(failure, 1) end
    check(not S.sell.awaitingPost and #messages == 0 and #warnings == 1 and #S.sell.items == 2,
        'failure lost item or logged success: ' .. failure)
end

reset(); S:PostSellItem(); advance(22)
check(S.sell.awaitingPost.delayed and #warnings == 1 and #messages == 0, 'silent timeout or false success')
S:RunSellHotkeyAction()
check(#posts == 1, 'ambiguous timeout retried automatically')
bags[1] = nil; emit('AUCTION_HOUSE_AUCTION_CREATED', 15)
check(#messages == 1 and not S.sell.awaitingPost, 'late success could not recover')

reset(); mode = 'confirmation'; S:PostSellItem(); pending = S.sell.awaitingPost
emit('AUCTION_HOUSE_CLOSED'); S.isAuctionHouseOpen = false
check(not popup and not S.sell.awaitingPost and not S:ConfirmSellPost(pending, true), 'closed auction confirmed old popup')
advance(30); emit('AUCTION_HOUSE_AUCTION_CREATED', 16)
check(#messages == 0 and #confirmations == 0, 'closed auction processed a stale callback')

reset(); bags[1] = stack(9999, 20)
check(not S:PostSellItem() and #posts == 0, 'posted different item from stale bag slot')
reset(); bags[1].isLocked = true
check(not S:PostSellItem() and #posts == 0, 'posted locked stack')
reset(); S.sell.price = 0
check(not S:PostSellItem(), 'zero price normalized into a cheap auction')
reset(); ready = false
check(not S:PostSellItem(), 'ignored auction throttle')
reset(); S.sell.scan.pending = true
S:RunSellHotkeyAction()
check(#posts == 0, 'hotkey posted while searching')

reset(); S.sell.scan.pending = true
S:OnSellSearchResults(false, { itemID = 9999 })
S:OnSellSearchResults(true, 9999)
check(S.sell.scan.pending and S.sell.selected.isCommodity, 'foreign result changed commodity type or finished scan')
reset({ equipment = true }); S.sell.scan.pending = true
S:OnSellSearchResults(false, { itemID = 1001, itemLevel = 20 })
check(S.sell.scan.pending, 'different item variant finished scan')
S:OnSellSearchResults(false, { itemID = 1001, itemLevel = 10 })
mode = 'confirmation'; S:PostSellItem()
E.StaticPopupDialogs[popup.key].OnAccept(nil, popup.data)
check(#confirmations == 1 and confirmations[1][4] == nil and confirmations[1][5] == 2389900,
    'noncommodity confirmation arguments wrong')

reset(); bags[3] = stack(1001, 7); S:RefreshSellList(); S.sell.quantity = 20
S:PostSellItem(); bags[1], bags[3] = nil, nil; emit('AUCTION_HOUSE_AUCTION_CREATED', 17)
check(#messages == 1 and messages[1]:find('x20', 1, true), 'multiple stacks did not settle')
reset(); bags[3] = stack(9999, 1, { isBound = true }); bags[1] = nil
S:RefreshSellList()
check(#S.sell.items == 1 and S.sell.selected.itemID == 1002, 'empty/bound slots retained stale sold entry')

-- Both visual styles must disable Post while the core refuses it.
reset()
local oldRefresh = S.RefreshSellUI
local uiEnv = setmetatable({ HironCraftProfit = { ShoppingList = S } }, { __index = E })
local ui = assert(loadfile('ProfitHub/Shop/UI/ShoppingList_Selling_UI.lua'))
setfenv(ui, uiEnv); ui()
S.RefreshSellUI = oldRefresh
local function widget()
    return { SetText = noop, SetTextColor = noop, SetBackdropBorderColor = noop,
        SetEnabled = function(self, value) self.enabled = value end }
end
local form = { depositLine = widget(), totalLine = widget(), priceMoney = widget(),
    postBtn = widget(), skipBtn = widget() }
form.postBtn.label = widget()
S.frame.sellPanel = { _built = true, form = form }
for _, fantasy in ipairs({ false, true }) do
    S.IsFantasy = function() return fantasy end
    S.sell.awaitingPost = nil
    S:UpdateSellTotals()
    check(form.postBtn.enabled and form.skipBtn.enabled, 'ready UI disabled the action')
    S.sell.awaitingPost = {}
    S:UpdateSellTotals()
    check(not form.postBtn.enabled and not form.skipBtn.enabled, 'pending UI allowed post/skip')
end
print('Auction selling checks passed: ' .. checked)
