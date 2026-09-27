local E = _G.HironCraftProfitShoppingListEnv
if not E then
    E = {}
    _G.HironCraftProfitShoppingListEnv = E
    setmetatable(E, { __index = _G })
end
setfenv(1, E)

if not PT or not S then return end

S.sell = S.sell or {
    items = {},
    selected = nil,
    quantity = 0,
    price = 0,
    duration = 2,
    scan = nil,
    pendingBuy = nil,
}


function GetSellExclusions()
    _G.HironCraftProfit_DB = _G.HironCraftProfit_DB or {}
    _G.HironCraftProfit_DB.shoppingList = _G.HironCraftProfit_DB.shoppingList or {}
    _G.HironCraftProfit_DB.shoppingList.sellExclusions = _G.HironCraftProfit_DB.shoppingList.sellExclusions or {}
    return _G.HironCraftProfit_DB.shoppingList.sellExclusions
end

function GetSellLastPrices()
    _G.HironCraftProfit_DB = _G.HironCraftProfit_DB or {}
    _G.HironCraftProfit_DB.shoppingList = _G.HironCraftProfit_DB.shoppingList or {}
    _G.HironCraftProfit_DB.shoppingList.sellLastPrice = _G.HironCraftProfit_DB.shoppingList.sellLastPrice or {}
    return _G.HironCraftProfit_DB.shoppingList.sellLastPrice
end

function S:IsSellExcluded(itemID)
    return itemID ~= nil and GetSellExclusions()[itemID] == true
end

function S:AddSellExclusion(itemID)
    if self.sell.awaitingPost then return end
    if not itemID then return end
    GetSellExclusions()[itemID] = true
    if self.sell.selected and self.sell.selected.itemID == itemID then
        self:ClearSellSelection()
    end
    self:RefreshSellList()
end

function S:RemoveSellExclusion(itemID)
    if not itemID then return end
    GetSellExclusions()[itemID] = nil
    self:RefreshSellList()
    if self.RefreshSellExclusionsEditor then self:RefreshSellExclusionsEditor() end
end

function S:ClearSellExclusions()
    wipe(GetSellExclusions())
    self:RefreshSellList()
    if self.RefreshSellExclusionsEditor then self:RefreshSellExclusionsEditor() end
end

function S:GetSellExclusionIDs()
    local ids = {}
    for itemID, v in pairs(GetSellExclusions()) do
        if v then ids[#ids + 1] = itemID end
    end
    table.sort(ids)
    return ids
end

SELL_FLIP_DROP_RATIO_DEFAULT = 0.85
SELL_FLIP_DROP_RATIO = 0.85
SELL_FLIP_SMALL_ABS = 5
SELL_FLIP_SMALL_FRACTION = 0.05
SELL_FLIP_MAX_SKIP = 3

S.FLIP_DROP_RATIO_DEFAULT = 0.6
S.FLIP_MIN_QTY_DEFAULT = 100

function S:GetFlipMinQty()
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB.sell = HironCraftProfit_DB.sell or {}
    local v = tonumber(HironCraftProfit_DB.sell.flipMinQty)
    if not v or v < 0 then return S.FLIP_MIN_QTY_DEFAULT end
    return math.floor(v)
end

function S:SetFlipMinQty(v)
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB.sell = HironCraftProfit_DB.sell or {}
    v = tonumber(v)
    if not v or v < 0 then v = S.FLIP_MIN_QTY_DEFAULT end
    HironCraftProfit_DB.sell.flipMinQty = math.floor(v)
end

function S:GetFlipRatio()
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB.sell = HironCraftProfit_DB.sell or {}
    local v = tonumber(HironCraftProfit_DB.sell.flipDropRatio)
    if not v or v <= 0 or v >= 1 then return SELL_FLIP_DROP_RATIO_DEFAULT end
    return v
end

function S:SetFlipRatio(v)
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB.sell = HironCraftProfit_DB.sell or {}
    v = tonumber(v)
    if not v or v <= 0 or v >= 1 then v = SELL_FLIP_DROP_RATIO_DEFAULT end
    HironCraftProfit_DB.sell.flipDropRatio = v
    SELL_FLIP_DROP_RATIO = v
end

SELL_DURATION_TO_HOURS = { [1] = 12, [2] = 24, [3] = 48 }

function GetSellDefaultDuration()
    _G.HironCraftProfit_DB = _G.HironCraftProfit_DB or {}
    _G.HironCraftProfit_DB.shoppingList = _G.HironCraftProfit_DB.shoppingList or {}
    local d = _G.HironCraftProfit_DB.shoppingList.sellDefaultDuration
    if d ~= 1 and d ~= 2 and d ~= 3 then d = 2 end
    return d
end

function SetSellDefaultDuration(code)
    if not SELL_DURATION_TO_HOURS[code] then return end
    _G.HironCraftProfit_DB = _G.HironCraftProfit_DB or {}
    _G.HironCraftProfit_DB.shoppingList = _G.HironCraftProfit_DB.shoppingList or {}
    _G.HironCraftProfit_DB.shoppingList.sellDefaultDuration = code
end

local function SellAHReady()
    return C_AuctionHouse
        and C_AuctionHouse.MakeItemKey
        and C_AuctionHouse.SendSearchQuery
        and C_AuctionHouse.GetNumCommoditySearchResults
        and C_AuctionHouse.GetCommoditySearchResultInfo
        and C_AuctionHouse.GetNumItemSearchResults
        and C_AuctionHouse.GetItemSearchResultInfo
end

function NormalizeSellPrice(price)
    price = tonumber(price) or 0
    if price % 100 ~= 0 then
        price = price + (100 - price % 100)
    end
    if price < 100 then
        price = 100
    end
    return price
end

local function IsItemCommodity(itemID)
    if not itemID or not C_AuctionHouse or not C_AuctionHouse.GetItemCommodityStatus then
        return false
    end
    local ok, status = pcall(C_AuctionHouse.GetItemCommodityStatus, itemID)
    if ok and Enum and Enum.ItemCommodityStatus then
        if status == Enum.ItemCommodityStatus.Commodity then return true end
        if status == Enum.ItemCommodityStatus.Item then return false end
        if C_Item and C_Item.RequestLoadItemDataByID then
            pcall(C_Item.RequestLoadItemDataByID, itemID)
        end
    end
    return false
end

local function DetermineCommodity(bag, slot, itemID)
    if C_AuctionHouse and C_AuctionHouse.GetItemCommodityStatus and Enum and Enum.ItemCommodityStatus
        and ItemLocation and ItemLocation.CreateFromBagAndSlot then
        local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
        if loc and C_Item and C_Item.DoesItemExist and C_Item.DoesItemExist(loc) then
            local ok, st = pcall(C_AuctionHouse.GetItemCommodityStatus, loc)
            if ok and st ~= Enum.ItemCommodityStatus.Unknown then
                return st == Enum.ItemCommodityStatus.Commodity
            end
        end
    end
    return IsItemCommodity(itemID)
end

local function IterateSellBags(callback)
    if not C_Container or not C_Container.GetContainerNumSlots then return end
    local maxBag = 5
    if Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag then
        maxBag = Enum.BagIndex.ReagentBag
    end
    for bag = 0, maxBag do
        local okSlots, slots = pcall(C_Container.GetContainerNumSlots, bag)
        if okSlots and slots and slots > 0 then
            for slot = 1, slots do
                callback(bag, slot)
            end
        end
    end
end

function S:ScanSellBags()
    local agg = {}
    local order = {}
    local dbg = { slots = 0, noinfo = 0, q0 = 0, excl = 0, invalid = 0, bound = 0, noval = 0 }

    IterateSellBags(function(bag, slot)
        dbg.slots = dbg.slots + 1
        local okInfo, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
        if not okInfo or not info or not info.itemID then
            -- Empty bag slots are normal, not a reason to retain a stale list.
            if not okInfo or (C_Container.GetContainerItemID and C_Container.GetContainerItemID(bag, slot)) then
                dbg.noinfo = dbg.noinfo + 1
            end
            return
        end
        if (info.quality or 1) == 0 then dbg.q0 = dbg.q0 + 1; return end
        if GetSellExclusions()[info.itemID] then dbg.excl = dbg.excl + 1; return end

        if ItemLocation and ItemLocation.CreateFromBagAndSlot and C_AuctionHouse and C_AuctionHouse.IsSellItemValid then
            local itemLoc = ItemLocation:CreateFromBagAndSlot(bag, slot)
            if itemLoc and itemLoc:IsValid() then
                local okValid, valid = pcall(C_AuctionHouse.IsSellItemValid, itemLoc, false)
                if okValid and valid == false then dbg.invalid = dbg.invalid + 1; return end
            else
                if info.isBound then dbg.bound = dbg.bound + 1; return end
                if info.hasNoValue then dbg.noval = dbg.noval + 1; return end
            end
        else
            if info.isBound then dbg.bound = dbg.bound + 1; return end
            if info.hasNoValue then dbg.noval = dbg.noval + 1; return end
        end

        local itemID = info.itemID
        local link = info.hyperlink
        local commodity = DetermineCommodity(bag, slot, itemID)
        local key = commodity and ("c:" .. itemID) or (link or ("i:" .. itemID))

        local entry = agg[key]
        if not entry then
            local name, _, quality, _, _, _, _, _, _, _, _, classID = nil
            if link and C_Item and C_Item.GetItemInfo then
                name, _, quality, _, _, _, _, _, _, _, _, classID = C_Item.GetItemInfo(link)
            end
            entry = {
                key = key,
                itemID = itemID,
                itemLink = link,
                itemName = name,
                icon = info.iconFileID,
                quality = quality or info.quality,
                classID = classID,
                count = 0,
                bag = bag,
                slot = slot,
                isCommodity = commodity,
            }
            agg[key] = entry
            order[#order + 1] = entry
        end
        entry.count = entry.count + (info.stackCount or 1)
    end)

    table.sort(order, function(a, b)
        local an = a.itemName or ""
        local bn = b.itemName or ""
        if an == bn then
            return (a.itemID or 0) < (b.itemID or 0)
        end
        return an < bn
    end)

    local prev = self.sell.items or {}
    local unstable = dbg.noinfo > 0
    if unstable and #order < #prev then
        self._sellRescanTries = (self._sellRescanTries or 0) + 1
        if self._sellRescanTries <= 3 then
            if C_Timer then
                C_Timer.After(0.35, function()
                    if S.frame and S.shopTab == "sell" and S.frame:IsShown() then
                        S:RefreshSellList()
                    end
                end)
            end
            return prev
        end
    end

    self._sellRescanTries = 0
    self.sell.items = order
    return order
end

function S:RefreshSellList()
    -- Bag events can precede AUCTION_CREATED. Keep the submitted item selected
    -- until both the server and inventory have acknowledged it.
    if self.sell.awaitingPost then
        self:TryFinishSellPost()
        return
    end
    if not self.sell._durInit then
        self.sell.duration = GetSellDefaultDuration()
        self.sell._durInit = true
    end

    local prevKey = self.sell.selected and self.sell.selected.key
    local prevIndex
    if prevKey then
        local order = (self.GetSellDisplayOrder and self:GetSellDisplayOrder()) or self.sell.items or {}
        for i, e in ipairs(order) do
            if e.key == prevKey then prevIndex = i; break end
        end
    end

    self:ScanSellBags()

    if prevKey then
        local order = (self.GetSellDisplayOrder and self:GetSellDisplayOrder()) or self.sell.items or {}
        local stillThere
        for _, e in ipairs(order) do
            if e.key == prevKey then stillThere = e; break end
        end

        if stillThere then
            self.sell.selected = stillThere
            self.sell.quantity = math.min(self.sell.quantity or 0, self:GetSellPostLimit())
        elseif prevIndex and #order > 0 then
            local target = order[prevIndex] or order[#order]
            if target then
                self:SelectSellItem(target)
            else
                self:ClearSellSelection()
            end
        else
            self:ClearSellSelection()
        end
    end

    -- Nothing chosen yet: the first item of the list is, with its prices.
    if not self.sell.selected then
        local order = (self.GetSellDisplayOrder and self:GetSellDisplayOrder()) or self.sell.items or {}
        if order[1] then
            self:SelectSellItem(order[1])
            return
        end
    end

    if self.RefreshSellUI then
        self:RefreshSellUI()
    end
end

function S:RefreshSellListSoon()
    S._sellRefreshAt = (GetTime and GetTime() or 0) + 0.15
    if S._sellRefreshPending then return end
    if not C_Timer then
        S:RefreshSellList()
        return
    end
    S._sellRefreshPending = true
    local tick
    tick = function()
        local now = GetTime and GetTime() or 0
        local due = S._sellRefreshAt or 0
        if now < due then
            C_Timer.After(math.max(0.02, due - now), tick)
            return
        end
        S._sellRefreshPending = nil
        if S.frame and S.shopTab == "sell" and S.frame:IsShown() then
            S:RefreshSellList()
        end
    end
    C_Timer.After(0.15, tick)
end

function S:GetSellEntryByKey(key)
    if not key then return nil end
    for _, e in ipairs(self.sell.items or {}) do
        if e.key == key then return e end
    end
    return nil
end

function S:ClearSellSelection()
    if self.sell.awaitingPost then return end
    self.sell.selected = nil
    self.sell.scan = nil
    self.sell.quantity = 0
    self.sell.price = 0
    self._pendingSellScan = nil
    if self.RefreshSellUI then
        self:RefreshSellUI()
    end
end

function S:GetSellDurationCode()
    return self.sell.duration or 2
end

function S:SetSellDuration(code)
    if SELL_DURATION_TO_HOURS[code] then
        self.sell.duration = code
        SetSellDefaultDuration(code)
    end
end

function S:GetSellPostLimit()
    local entry = self.sell.selected
    if not entry then return 0 end
    local limit = entry.count or 0
    if ItemLocation and C_AuctionHouse and C_AuctionHouse.GetAvailablePostCount then
        local loc = ItemLocation:CreateFromBagAndSlot(entry.bag, entry.slot)
        if loc and C_Item and C_Item.DoesItemExist and C_Item.DoesItemExist(loc) then
            local okCount, count = pcall(C_AuctionHouse.GetAvailablePostCount, loc)
            if okCount and count then
                limit = math.min(count, entry.count or count)
            end
        end
    end
    return limit
end

function S:GetSellDeposit()
    local entry = self.sell.selected
    if not entry then return 0 end
    local qty = self.sell.quantity or 0
    if qty <= 0 then return 0 end
    local dur = self:GetSellDurationCode()
    local deposit = 0
    if entry.isCommodity then
        if C_AuctionHouse and C_AuctionHouse.CalculateCommodityDeposit then
            local ok, value = pcall(C_AuctionHouse.CalculateCommodityDeposit, entry.itemID, dur, qty)
            if ok and value then deposit = value end
        end
    else
        if ItemLocation and C_AuctionHouse and C_AuctionHouse.CalculateItemDeposit then
            local loc = ItemLocation:CreateFromBagAndSlot(entry.bag, entry.slot)
            local ok, value = pcall(C_AuctionHouse.CalculateItemDeposit, loc, dur, qty)
            if ok and value then deposit = value end
        end
    end
    return deposit
end

function S:SelectSellItem(entry)
    if self.sell.awaitingPost then return end
    if not entry then return end
    self.sell.selected = entry
    self.sell.quantity = self:GetSellPostLimit()
    self.sell.price = 0
    self.sell.scan = nil
    self.sell.awaitingPost = nil

    self.sell._priceSeeded = nil
    local seed = entry.itemID and GetSellLastPrices()[entry.itemID]
    if (not seed or seed <= 0) and PT.Prices and PT.Prices.GetMinBuyout and entry.itemID then
        local mb = PT.Prices:GetMinBuyout(entry.itemID)
        if mb and mb > 0 then seed = mb end
    end
    if seed and seed > 0 then
        self.sell.price = NormalizeSellPrice(seed)
        self.sell._priceSeeded = true
    end

    if self.RefreshSellUI then
        self:RefreshSellUI()
    end
    self:DoSellSearch(entry)
end

local function BuildSellSorts()
    if not Enum or not Enum.AuctionHouseSortOrder then
        return nil
    end
    return { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
end

function S:DoSellSearch(entry)
    if self.sell.awaitingPost then return end
    entry = entry or self.sell.selected
    if not entry then return end
    if not SellAHReady() then return end
    if not self.isAuctionHouseOpen then return end

    local itemKey
    if not entry.isCommodity and entry.bag and entry.slot
        and ItemLocation and ItemLocation.CreateFromBagAndSlot then
        local loc = ItemLocation:CreateFromBagAndSlot(entry.bag, entry.slot)
        if loc and loc:IsValid() then
            local okGet, key = pcall(C_AuctionHouse.GetItemKeyFromItem, loc)
            if okGet and key then itemKey = key end

            if not itemKey then
                local ilvl
                if C_Item and C_Item.GetCurrentItemLevel then
                    local okLvl, lvl = pcall(C_Item.GetCurrentItemLevel, loc)
                    if okLvl then ilvl = lvl end
                end
                if ilvl and ilvl > 0 then
                    local okMk, k = pcall(C_AuctionHouse.MakeItemKey, entry.itemID, ilvl)
                    if okMk and k then itemKey = k end
                end
            end
        end
    end

    if not itemKey then
        local okKey, key = pcall(C_AuctionHouse.MakeItemKey, entry.itemID)
        if not okKey or not key then return end
        itemKey = key
    end

    self.sell.scan = {
        itemID = entry.itemID,
        itemKey = itemKey,
        isCommodity = entry.isCommodity,
        pending = true,
        tiers = {},
        totalQty = 0,
        reference = nil,
        skipped = {},
    }

    if self.RefreshSellUI then
        self:RefreshSellUI()
    end

    self:QueueSellSearch(itemKey, BuildSellSorts())
end

function S:QueueSellSearch(itemKey, sorts)
    self._pendingSellScan = { itemKey = itemKey, sorts = sorts }
    self:ProcessSellScanQueue()
end

function S:ProcessSellScanQueue()
    if self.sell.awaitingPost or not self.isAuctionHouseOpen then return end
    local q = self._pendingSellScan
    if not q then return end
    if not (C_AuctionHouse and C_AuctionHouse.SendSearchQuery) then return end
    if not self:IsSellAHThrottleReady() then return end
    self._pendingSellScan = nil
    pcall(C_AuctionHouse.SendSearchQuery, q.itemKey, q.sorts, true)
end

local function AddTier(tiers, index, price, qty, owned, auctionID, ownerName)
    local tier = index[price]
    if not tier then
        tier = { price = price, qty = 0, owned = false, auctionIDs = {}, ownerSeen = {}, owners = {} }
        index[price] = tier
        tiers[#tiers + 1] = tier
    end
    tier.qty = tier.qty + (qty or 0)
    if owned then tier.owned = true end
    if auctionID then
        tier.auctionIDs[#tier.auctionIDs + 1] = auctionID
    end
    if type(ownerName) == "string" and ownerName ~= "" and not tier.ownerSeen[ownerName] then
        tier.ownerSeen[ownerName] = true
        tier.owners[#tier.owners + 1] = ownerName
    end
end

function ComputeSellReference(tiers, totalQty)
    if #tiers == 0 then return nil, {}, 0 end

    local ratio = S:GetFlipRatio()
    local skipped = {}
    local i = 1
    while i < #tiers and #skipped < SELL_FLIP_MAX_SKIP do
        local cur = tiers[i]
        local nxt = tiers[i + 1]
        local drop = nxt and cur.price < (ratio * nxt.price)
        local small = cur.qty <= S:GetFlipMinQty()
        if drop and small and not cur.owned then
            cur.isFlip = true
            skipped[#skipped + 1] = cur
            i = i + 1
        else
            break
        end
    end

    local ref = tiers[i]
    if ref then ref.isReference = true end
    return ref and ref.price or nil, skipped, i
end

function S:OnSellSearchResults(isCommodity, idOrKey)
    local scan = self.sell.scan
    if not scan or not scan.pending then return end
    if self.sell.awaitingPost then return end
    if isCommodity then
        if scan.itemID ~= idOrKey then return end
    else
        local key = scan.itemKey
        if not key or type(idOrKey) ~= "table" then return end
        for _, field in ipairs({ "itemID", "itemLevel", "itemSuffix", "battlePetSpeciesID" }) do
            if (key[field] or 0) ~= (idOrKey[field] or 0) then return end
        end
    end

    scan.isCommodity = isCommodity
    if self.sell.selected and self.sell.selected.itemID == scan.itemID then
        self.sell.selected.isCommodity = isCommodity
    end

    local tiers = {}
    local index = {}
    local totalQty = 0

    if isCommodity then
        if scan.itemID ~= idOrKey then return end
        local num = C_AuctionHouse.GetNumCommoditySearchResults(scan.itemID) or 0
        for i = 1, num do
            local ok, r = pcall(C_AuctionHouse.GetCommoditySearchResultInfo, scan.itemID, i)
            if ok and r and r.unitPrice then
                local owned = r.containsOwnerItem
                AddTier(tiers, index, r.unitPrice, r.quantity or 1, owned, nil)
                totalQty = totalQty + (r.quantity or 1)
            end
        end
    else
        if not scan.itemKey then return end
        local num = C_AuctionHouse.GetNumItemSearchResults(scan.itemKey) or 0
        for i = 1, num do
            local ok, r = pcall(C_AuctionHouse.GetItemSearchResultInfo, scan.itemKey, i)
            if ok and r then
                local unit = r.buyoutAmount or r.bidAmount
                local stack = (r.itemKey and r.quantity) or 1
                if unit and unit > 0 then
                    local ownerName = (type(r.owners) == "table" and r.owners[1]) or r.owner
                    AddTier(tiers, index, unit, stack, r.containsOwnerItem, r.auctionID, ownerName)
                    totalQty = totalQty + stack
                end
            end
        end
    end

    table.sort(tiers, function(a, b) return a.price < b.price end)

    local reference, skipped = ComputeSellReference(tiers, totalQty)

    scan.tiers = tiers
    scan.totalQty = totalQty
    scan.reference = reference
    scan.skipped = skipped
    scan.pending = false

    local liveMin
    for _, tr in ipairs(tiers) do
        if tr.price and tr.price > 0 and (not liveMin or tr.price < liveMin) then
            liveMin = tr.price
        end
    end
    if liveMin and PT.Prices then
        if isCommodity and PT.Prices.UpdateItem then
            PT.Prices:UpdateItem(scan.itemID, liveMin, liveMin, totalQty)
        elseif scan.itemKey and PT.Prices.UpdateItemFromKey then
            PT.Prices:UpdateItemFromKey(scan.itemKey, liveMin, liveMin, totalQty)
        end
    end

    scan.ourLastPrice = scan.itemID and GetSellLastPrices()[scan.itemID] or nil

    local canOverwrite = (self.sell.price or 0) <= 0 or self.sell._priceSeeded

    if reference and canOverwrite then
        self.sell.price = NormalizeSellPrice(reference)
        self.sell._priceSeeded = nil
    elseif not reference and canOverwrite then
        local key = isCommodity and scan.itemID or scan.itemKey
        local known = (PT.Prices and PT.Prices.GetMinBuyout and key) and PT.Prices:GetMinBuyout(key) or nil
        local fb
        if known and known > 0 then
            fb = known
            scan.priceFromDB = true
        elseif scan.ourLastPrice and scan.ourLastPrice > 0 then
            fb = scan.ourLastPrice
            scan.priceFromLastPost = true
        end
        if fb then
            self.sell.price = NormalizeSellPrice(fb)
            self.sell._priceSeeded = nil
        end
    end

    if self.RefreshSellUI then
        self:RefreshSellUI()
    end
end

local SELL_CONFIRM_DIALOG = "HIRONCRAFT_SELL_CONFIRM"

local function MatchesSellEntry(info, entry)
    return info and info.itemID == entry.itemID
        and (entry.isCommodity or info.hyperlink == entry.itemLink)
end

local function SellLocationMatches(entry)
    if not C_Container or not C_Container.GetContainerItemInfo then return false end
    local info = C_Container.GetContainerItemInfo(entry.bag, entry.slot)
    return MatchesSellEntry(info, entry) and not info.isLocked
end

local function CountSellInventory(entry)
    local count, complete = 0, true
    IterateSellBags(function(bag, slot)
        local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
        if not ok or (not info and C_Container.GetContainerItemID and C_Container.GetContainerItemID(bag, slot)) then
            complete = false
        elseif MatchesSellEntry(info, entry) then
            count = count + (info.stackCount or 1)
        end
    end)
    return complete and count or nil
end

function S:FailSellPost(pending, message)
    if not pending or self.sell.awaitingPost ~= pending then return end
    self.sell.awaitingPost = nil
    if StaticPopup_Hide then StaticPopup_Hide(SELL_CONFIRM_DIALOG) end
    if message then print("|cffb19cd9HironCraft:|r " .. message) end
    self:RefreshSellList()
end

function S:TryFinishSellPost()
    local pending = self.sell.awaitingPost
    if not pending or not pending.created then return end
    local count = CountSellInventory(pending.entry)
    if not count or count > pending.beforeCount - pending.quantity then return end

    local entry, qty, price = pending.entry, pending.quantity, pending.price
    self.sell.awaitingPost = nil
    self._sellDepositTrusted = true
    GetSellLastPrices()[entry.itemID] = price
    local link = entry.itemLink or entry.itemName or ("item:" .. tostring(entry.itemID))
    local each = (GetMoneyString and GetMoneyString(price, true)) or tostring(price)
    local total = (GetMoneyString and GetMoneyString(price * qty, true)) or tostring(price * qty)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            T("PG_SELL_POSTED_MSG", "Posted: %s x%d at %s/ea (total %s)"), link, qty, each, total))
    end
    -- Read actual remaining stacks/locations instead of subtracting from a
    -- cached entry that BAG_UPDATE may already have changed.
    self:RefreshSellList()
end

function S:WatchSellPost(pending)
    if not C_Timer then return end
    local function tick()
        if S.sell.awaitingPost ~= pending then return end
        S:TryFinishSellPost()
        if S.sell.awaitingPost ~= pending then return end
        if (GetTime() - pending.startedAt) >= 20 then
            -- No automatic retry: a delayed server response is not a failure.
            pending.delayed = true
            print("|cffb19cd9HironCraft:|r " .. T("PG_SELL_POST_DELAYED",
                "Auction response delayed. Check your auctions and reopen the auction house before retrying."))
            if S.RefreshSellUI then S:RefreshSellUI() end
            return
        end
        C_Timer.After(0.2, tick)
    end
    C_Timer.After(0.2, tick)
end

function S:ConfirmSellPost(pending, userInitiated)
    if userInitiated ~= true then return false end
    if self.sell.awaitingPost ~= pending or pending.phase ~= "confirmation" then return false end
    if not self.isAuctionHouseOpen or not self:IsSellAHThrottleReady()
        or not SellLocationMatches(pending.entry) or self:GetSellPostLimit() < pending.quantity then
        self:FailSellPost(pending, T("PG_SELL_POST_FAILED", "could not post the item — try again"))
        return false
    end
    pending.phase = "posting"
    pending.startedAt = GetTime()
    local ok
    if pending.entry.isCommodity then
        ok = C_AuctionHouse.ConfirmPostCommodity and pcall(C_AuctionHouse.ConfirmPostCommodity,
            pending.location, pending.duration, pending.quantity, pending.price)
    else
        ok = C_AuctionHouse.ConfirmPostItem and pcall(C_AuctionHouse.ConfirmPostItem,
            pending.location, pending.duration, pending.quantity, nil, pending.price)
    end
    if not ok then
        self:FailSellPost(pending, T("PG_SELL_POST_FAILED", "could not post the item — try again"))
        return false
    end
    self:WatchSellPost(pending)
    if self.RefreshSellUI then self:RefreshSellUI() end
    return true
end

function S:ShowSellPostConfirmation(pending)
    if not StaticPopupDialogs or not StaticPopup_Show then
        self:FailSellPost(pending, T("PG_SELL_POST_FAILED", "could not post the item — try again"))
        return
    end
    StaticPopupDialogs[SELL_CONFIRM_DIALOG] = StaticPopupDialogs[SELL_CONFIRM_DIALOG] or {
        text = "%s\n\n%s", button1 = ACCEPT, button2 = CANCEL,
        timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true,
        OnAccept = function(_, data) S:ConfirmSellPost(data, true) end,
        OnCancel = function(_, data) S:FailSellPost(data) end,
    }
    -- Blizzard's popup only knows about posts made through its own sell form.
    -- Preserve its warning, but bind confirmation to our exact frozen request.
    if StaticPopup_Hide then StaticPopup_Hide("AUCTION_HOUSE_POST_WARNING") end
    local price = GetMoneyString and GetMoneyString(pending.price, true) or tostring(pending.price)
    local details = string.format("%s x%d — %s", pending.entry.itemLink or pending.entry.itemName
        or ("item:" .. tostring(pending.entry.itemID)),
        pending.quantity, price)
    if not StaticPopup_Show(SELL_CONFIRM_DIALOG, CONFIRM_AUCTION_POSTING_TEXT, details, pending) then
        self:FailSellPost(pending, T("PG_SELL_POST_FAILED", "could not post the item — try again"))
    end
end

function S:PostSellItem()
    local entry = self.sell.selected
    if not entry then return false end
    if self.sell.awaitingPost or self.sell.pendingBuy then return false end
    if not self.isAuctionHouseOpen then return false end
    if not C_AuctionHouse then return false end
    if not self:IsSellAHThrottleReady() then return false end
    if not self:IsSellScanReady() then return false end
    if not SellLocationMatches(entry) then
        self:RefreshSellList()
        return false
    end

    local now = (GetTime and GetTime()) or 0
    if self._lastPostKey == entry.key and self._lastPostTime and (now - self._lastPostTime) < 0.5 then
        return false
    end

    local qty = math.floor(tonumber(self.sell.quantity) or 0)
    local rawPrice = tonumber(self.sell.price) or 0
    if rawPrice <= 0 then return false end
    local price = NormalizeSellPrice(rawPrice)
    local dur = self:GetSellDurationCode()

    if qty <= 0 or price <= 0 then return false end

    local limit = self:GetSellPostLimit()
    if qty > limit then qty = limit end
    if qty <= 0 then return false end

    local deposit = self:GetSellDeposit()
    if self._sellDepositTrusted and deposit > 0 and (GetMoney and GetMoney() or 0) < deposit then
        local now2 = (GetTime and GetTime()) or 0
        if not self._lastDepositWarn or (now2 - self._lastDepositWarn) > 3 then
            self._lastDepositWarn = now2
            local depStr = (GetMoneyString and GetMoneyString(deposit, true)) or tostring(deposit)
            print("|cffb19cd9HironCraft:|r " ..
                string.format(T("PG_SELL_NO_DEPOSIT", "not enough gold for the deposit (need %s)"), depStr))
        end
        return false
    end

    local loc = ItemLocation:CreateFromBagAndSlot(entry.bag, entry.slot)
    if not (C_Item and C_Item.DoesItemExist and C_Item.DoesItemExist(loc)) then
        self:RefreshSellList()
        return false
    end

    local isCommodity = entry.isCommodity and true or false
    if C_AuctionHouse.GetItemCommodityStatus and Enum and Enum.ItemCommodityStatus then
        local okS, st = pcall(C_AuctionHouse.GetItemCommodityStatus, loc)
        if not okS or st == Enum.ItemCommodityStatus.Unknown then
            okS, st = pcall(C_AuctionHouse.GetItemCommodityStatus, entry.itemID)
        end
        if okS then
            if st == Enum.ItemCommodityStatus.Commodity then
                isCommodity = true
            elseif st == Enum.ItemCommodityStatus.Item then
                isCommodity = false
            end
        end
    end
    entry.isCommodity = isCommodity

    local beforeCount = CountSellInventory(entry)
    if not beforeCount or beforeCount < qty then return false end
    local snapshot = {}
    for key, value in pairs(entry) do snapshot[key] = value end
    local pending = { entry = snapshot, quantity = qty, price = price, duration = dur,
        location = loc, beforeCount = beforeCount, startedAt = now, phase = "posting" }
    self.sell.awaitingPost = pending
    self._pendingSellScan = nil
    local ok, needsConfirmation = false, false
    if isCommodity then
        if C_AuctionHouse.PostCommodity then
            ok, needsConfirmation = pcall(C_AuctionHouse.PostCommodity, loc, dur, qty, price)
        end
    else
        if C_AuctionHouse.PostItem then
            ok, needsConfirmation = pcall(C_AuctionHouse.PostItem, loc, dur, qty, nil, price)
        end
    end

    if not ok then
        self:FailSellPost(pending, T("PG_SELL_POST_FAILED", "could not post the item — try again"))
        return false
    end

    self._lastPostKey = entry.key
    self._lastPostTime = now
    if self.sell.awaitingPost == pending then
        if needsConfirmation then
            pending.phase = "confirmation"
            self:ShowSellPostConfirmation(pending)
        else
            self:WatchSellPost(pending)
        end
    end
    if self.RefreshSellUI then
        self:RefreshSellUI()
    end

    return true
end

function S:AdvanceSellSelection(fromKey)
    local items = (self.GetSellDisplayOrder and self:GetSellDisplayOrder()) or self.sell.items or {}
    local target
    for i, e in ipairs(items) do
        if e.key == fromKey then
            target = items[i + 1]
            break
        end
    end
    if not target then
        for _, e in ipairs(items) do
            if e.key ~= fromKey then target = e; break end
        end
    end
    if target then
        self:SelectSellItem(target)
    else
        self:ClearSellSelection()
    end
end

function S:SkipSellItem()
    local entry = self.sell.selected
    if not entry then return end
    self:AdvanceSellSelection(entry.key)
end

SELL_HOTKEY_PROXY_NAME = "HironCraftProfitShoppingSellHotkeyProxy"
SELL_SKIP_PROXY_NAME = "HironCraftProfitShoppingSellSkipProxy"

local SELL_BIND_DBKEY = { post = "sellBinding", skip = "sellSkipBinding" }

function S:GetSellBinding(action)
    action = SELL_BIND_DBKEY[action] and action or "post"
    _G.HironCraftProfit_DB = _G.HironCraftProfit_DB or {}
    _G.HironCraftProfit_DB.shoppingList = _G.HironCraftProfit_DB.shoppingList or {}
    return _G.HironCraftProfit_DB.shoppingList[SELL_BIND_DBKEY[action]]
end

function S:SetSellBinding(action, binding)
    action = SELL_BIND_DBKEY[action] and action or "post"
    _G.HironCraftProfit_DB = _G.HironCraftProfit_DB or {}
    _G.HironCraftProfit_DB.shoppingList = _G.HironCraftProfit_DB.shoppingList or {}
    _G.HironCraftProfit_DB.shoppingList[SELL_BIND_DBKEY[action]] = binding
    self:ApplySellBinding()
    if self.UpdateSellBindText then self:UpdateSellBindText() end
end

function S:ClearSellBinding(action)
    action = SELL_BIND_DBKEY[action] and action or "post"
    _G.HironCraftProfit_DB = _G.HironCraftProfit_DB or {}
    _G.HironCraftProfit_DB.shoppingList = _G.HironCraftProfit_DB.shoppingList or {}
    _G.HironCraftProfit_DB.shoppingList[SELL_BIND_DBKEY[action]] = nil
    self:ApplySellBinding()
    if self.UpdateSellBindText then self:UpdateSellBindText() end
end

function S:IsSellScanReady()
    local scan = self.sell and self.sell.scan
    if not scan then return false end
    if not self.sell.selected or scan.itemID ~= self.sell.selected.itemID then return false end
    if scan.pending then return false end
    return true
end

function S:IsSellAHThrottleReady()
    if C_AuctionHouse and C_AuctionHouse.IsThrottledMessageSystemReady then
        local ok, ready = pcall(C_AuctionHouse.IsThrottledMessageSystemReady)
        if ok then return ready == true end
    end
    return true
end

function S:RunSellHotkeyAction()
    if not self.isAuctionHouseOpen then return end
    if self.shopTab ~= "sell" then return end
    if not self.sell.selected then return end
    -- Posting must remain in the real click/key handler. Never replay a busy
    -- press from THROTTLED_SYSTEM_READY (which has no hardware action context).
    if not self:IsSellAHThrottleReady() then return end
    local now = GetTime and GetTime() or 0
    if self._lastSellPostTime and (now - self._lastSellPostTime) < 0.35 then return end
    if self:PostSellItem() then
        self._lastSellPostTime = now
    end
end

function S:RunSkipHotkeyAction()
    if not self.isAuctionHouseOpen then return end
    if self.shopTab ~= "sell" then return end
    if not self.sell.selected then return end
    self:SkipSellItem()
end

function S:CreateSellHotkeyProxy()
    if self.sellHotkeyProxy then return self.sellHotkeyProxy end
    local proxy = CreateFrame("Button", SELL_HOTKEY_PROXY_NAME, UIParent)
    proxy:RegisterForClicks("LeftButtonUp")
    proxy:SetScript("OnClick", function()
        if S.RunSellHotkeyAction then S:RunSellHotkeyAction() end
    end)
    proxy:Hide()
    self.sellHotkeyProxy = proxy
    return proxy
end

function S:CreateSellSkipProxy()
    if self.sellSkipProxy then return self.sellSkipProxy end
    local proxy = CreateFrame("Button", SELL_SKIP_PROXY_NAME, UIParent)
    proxy:RegisterForClicks("LeftButtonUp")
    proxy:SetScript("OnClick", function()
        if S.RunSkipHotkeyAction then S:RunSkipHotkeyAction() end
    end)
    proxy:Hide()
    self.sellSkipProxy = proxy
    return proxy
end

function S:ApplySellBinding()
    local postProxy = self:CreateSellHotkeyProxy()
    local skipProxy = self:CreateSellSkipProxy()
    if InCombatLockdown() then return false end
    ClearOverrideBindings(postProxy)
    ClearOverrideBindings(skipProxy)
    if self.sellBindingOwner then
        ClearOverrideBindings(self.sellBindingOwner)
        self.sellBindingOwner = nil
    end
    local owner = (self.frame and self.frame:IsShown()) and self.frame or nil
    if owner then
        local pb = self:GetSellBinding("post")
        if pb and pb ~= "" then
            SetOverrideBindingClick(owner, false, pb, SELL_HOTKEY_PROXY_NAME, "LeftButton")
        end
        local sb = self:GetSellBinding("skip")
        if sb and sb ~= "" then
            SetOverrideBindingClick(owner, false, sb, SELL_SKIP_PROXY_NAME, "LeftButton")
        end
        self.sellBindingOwner = owner
    end
    return true
end

function S:ClearSellTemporaryBinding()
    if self.sellBindingOwner then
        ClearOverrideBindings(self.sellBindingOwner)
        self.sellBindingOwner = nil
    end
    if self.sellHotkeyProxy then
        ClearOverrideBindings(self.sellHotkeyProxy)
    end
    if self.sellSkipProxy then
        ClearOverrideBindings(self.sellSkipProxy)
    end
    return true
end

function S:BuySellTier(tier)
    if self.sell.awaitingPost then return end
    if not tier or not self.sell.selected then return end
    if not self.isAuctionHouseOpen then return end
    local entry = self.sell.selected
    local pending = self.sell.pendingBuy
    if pending then
        if pending.itemID ~= entry.itemID or pending.tierPrice ~= tier.price
            or not pending.ready or pending.confirming then return end
        if (GetTime() - pending.requestedAt) > 10 then
            if C_AuctionHouse.CancelCommoditiesPurchase then C_AuctionHouse.CancelCommoditiesPurchase() end
            self.sell.pendingBuy = nil
            if self.RefreshSellUI then self:RefreshSellUI() end
            return
        end
        -- The price event only arms this confirmation. A second row click,
        -- never a timer/server event, actually completes the purchase.
        pending.confirming = true
        local ok = C_AuctionHouse.ConfirmCommoditiesPurchase
            and pcall(C_AuctionHouse.ConfirmCommoditiesPurchase, pending.itemID, pending.qty)
        if not ok then self.sell.pendingBuy = nil end
        if self.RefreshSellUI then self:RefreshSellUI() end
        return
    end
    if not entry.isCommodity then return end
    if tier.owned then return end
    if not (C_AuctionHouse and C_AuctionHouse.StartCommoditiesPurchase) then return end

    local qty = tier.qty or 1
    if qty < 1 then qty = 1 end

    self.sell.pendingBuy = {
        itemID = entry.itemID,
        qty = qty,
        expected = (tier.price or 0) * qty,
        itemLink = entry.itemLink or entry.itemName,
        tierPrice = tier.price,
        requestedAt = GetTime(),
    }
    if self.RefreshSellUI then self:RefreshSellUI() end
    local ok = pcall(C_AuctionHouse.StartCommoditiesPurchase, entry.itemID, qty)
    if not ok then
        self.sell.pendingBuy = nil
        if self.RefreshSellUI then self:RefreshSellUI() end
    end
end

local sellEventFrame = CreateFrame("Frame")
sellEventFrame:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
sellEventFrame:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
sellEventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
sellEventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
sellEventFrame:RegisterEvent("COMMODITY_PRICE_UPDATED")
sellEventFrame:RegisterEvent("COMMODITY_PRICE_UNAVAILABLE")
sellEventFrame:RegisterEvent("COMMODITY_PURCHASE_SUCCEEDED")
sellEventFrame:RegisterEvent("COMMODITY_PURCHASE_FAILED")
sellEventFrame:RegisterEvent("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
pcall(sellEventFrame.RegisterEvent, sellEventFrame, "AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED")
sellEventFrame:RegisterEvent("AUCTION_HOUSE_AUCTION_CREATED")
sellEventFrame:RegisterEvent("AUCTION_HOUSE_POST_ERROR")
sellEventFrame:RegisterEvent("AUCTION_HOUSE_SHOW_ERROR")
sellEventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "AUCTION_HOUSE_AUCTION_CREATED" then
        local pending = S.sell.awaitingPost
        if pending and pending.phase == "posting" then
            pending.created = true
            S:TryFinishSellPost()
        end
        return
    end
    if event == "AUCTION_HOUSE_POST_ERROR" or event == "AUCTION_HOUSE_SHOW_ERROR" then
        local pending = S.sell.awaitingPost
        if pending and not pending.created then
            S:FailSellPost(pending, T("PG_SELL_POST_FAILED", "could not post the item — try again"))
        end
        return
    end
    if event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
        if S._pendingSellScan then
            C_Timer.After(0.05, function() S:ProcessSellScanQueue() end)
        end
        if S.RefreshSellUI then S:RefreshSellUI() end
        return
    end

    if event == "AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED" then
        -- A request the auction house threw away: a post it dropped left its
        -- item in the bags, so read them again and show it.
        if S.frame and S.shopTab == "sell" and S.frame:IsShown() then
            S:RefreshSellListSoon()
        end
        return
    end

    if event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        local itemID = ...
        S:OnSellSearchResults(true, itemID)
        return
    end

    if event == "ITEM_SEARCH_RESULTS_UPDATED" then
        local itemKey = ...
        S:OnSellSearchResults(false, itemKey)
        return
    end

    if event == "BAG_UPDATE_DELAYED" then
        S:TryFinishSellPost()
        if S.frame and S.shopTab == "sell" and S.frame:IsShown() then
            S:RefreshSellListSoon()
        end
        return
    end

    if event == "COMMODITY_PRICE_UPDATED" then
        local pb = S.sell.pendingBuy
        if not pb then return end
        local _, totalPrice = ...
        if not totalPrice or not pb.requestedAt or (GetTime() - pb.requestedAt) > 10
            or (pb.expected and pb.expected > 0 and totalPrice > pb.expected * 1.1) then
            if C_AuctionHouse.CancelCommoditiesPurchase then
                pcall(C_AuctionHouse.CancelCommoditiesPurchase)
            end
            S.sell.pendingBuy = nil
            if S.RefreshSellUI then S:RefreshSellUI() end
            return
        end
        pb.totalPrice = totalPrice
        pb.ready = true
        if S.RefreshSellUI then S:RefreshSellUI() end
        return
    end

    if event == "COMMODITY_PRICE_UNAVAILABLE" then
        if S.sell.pendingBuy then
            S.sell.pendingBuy = nil
            if S.RefreshSellUI then S:RefreshSellUI() end
        end
        return
    end

    if event == "COMMODITY_PURCHASE_SUCCEEDED" then
        local pb = S.sell.pendingBuy
        if pb then
            local link = pb.itemLink or ("item:" .. tostring(pb.itemID))
            local msg = string.format(T("PG_SELL_BOUGHT_MSG", "Sniped: %s x%d"), link, pb.qty or 0)
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage(msg)
            end
            S.sell.pendingBuy = nil
            C_Timer.After(0.2, function()
                S:RefreshSellList()
                if S.sell.selected then
                    S:DoSellSearch(S.sell.selected)
                end
            end)
        end
        return
    end

    if event == "COMMODITY_PURCHASE_FAILED" then
        S.sell.pendingBuy = nil
        if S.RefreshSellUI then S:RefreshSellUI() end
        return
    end

    if event == "AUCTION_HOUSE_CLOSED" then
        S.sell.scan = nil
        S.sell.pendingBuy = nil
        S.sell.pendingBindPost = nil
        S.sell.awaitingPost = nil
        S._pendingSellScan = nil
        if StaticPopup_Hide then StaticPopup_Hide(SELL_CONFIRM_DIALOG) end
        S._sellDepositTrusted = nil
        return
    end
end)
