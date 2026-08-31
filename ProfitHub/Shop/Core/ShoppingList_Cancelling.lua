local E = _G.HironCraftProfitShoppingListEnv
if not E then
    E = {}
    _G.HironCraftProfitShoppingListEnv = E
    setmetatable(E, { __index = _G })
end
setfenv(1, E)

if not PT or not S then return end

S.cancel = S.cancel or {
    auctions = {},
    sold = {},
    totalOnSale = 0,
    totalSold = 0,
    pending = false,
    cancelling = {},
    scan = nil,
    wantScan = false,
    undercut = {},
}

function S:QueryOwnedAuctions()
    if not (C_AuctionHouse and C_AuctionHouse.QueryOwnedAuctions) then return end
    if not self.isAuctionHouseOpen then return end
    self.cancel.pending = true
    if self.RefreshCancelUI then self:RefreshCancelUI() end
    local sorts = { { sortOrder = (Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price) or 1, reverseSort = false } }
    pcall(C_AuctionHouse.QueryOwnedAuctions, sorts)
end

function S:ReadOwnedAuctions()
    local active, sold = {}, {}
    local totalOnSale, totalSold = 0, 0
    local num = (C_AuctionHouse and C_AuctionHouse.GetNumOwnedAuctions and C_AuctionHouse.GetNumOwnedAuctions()) or 0

    for i = 1, num do
        local ok, info = pcall(C_AuctionHouse.GetOwnedAuctionInfo, i)
        if ok and info and info.auctionID then
            local itemID = info.itemKey and info.itemKey.itemID
            local price = info.buyoutAmount or info.bidAmount or 0
            local qty = info.quantity or 1
            local isSold = info.status == 1

            local unitPrice, totalPrice
            if isSold then
                totalPrice = price
                unitPrice = qty > 0 and math.floor(price / qty + 0.5) or price
            else
                unitPrice = price
                totalPrice = price * qty
            end

            local rec = {
                auctionID = info.auctionID,
                itemID = itemID,
                itemLink = info.itemLink,
                quantity = qty,
                unitPrice = unitPrice,
                totalPrice = totalPrice,
                timeLeft = info.timeLeftSeconds or 0,
                cancelling = self.cancel.cancelling[info.auctionID] == true,
            }
            if isSold then
                sold[#sold + 1] = rec
                totalSold = totalSold + totalPrice
            else
                active[#active + 1] = rec
                totalOnSale = totalOnSale + totalPrice
            end
        end
    end

    table.sort(active, function(a, b) return (a.unitPrice or 0) < (b.unitPrice or 0) end)

    self.cancel.auctions = active
    self.cancel.sold = sold
    self.cancel.totalOnSale = totalOnSale
    self.cancel.totalSold = totalSold
    self.cancel.pending = false

    if self.cancel.wantScan and #active > 0 then
        self.cancel.wantScan = false
        self:StartUndercutScan()
    end

    if self.RefreshCancelUI then self:RefreshCancelUI() end
end

function S:CancelOwnedAuction(auctionID)
    if not auctionID then return end
    if not (C_AuctionHouse and C_AuctionHouse.CancelAuction) then return end
    if self.cancel.cancelling[auctionID] then return end
    self.cancel.cancelling[auctionID] = true
    if self.RefreshCancelUI then self:RefreshCancelUI() end
    pcall(C_AuctionHouse.CancelAuction, auctionID)
end

function S:IsAuctionUndercut(auction)
    if not auction or not auction.itemID then return false end
    local competitorMin = self.cancel.undercut[auction.itemID]
    return competitorMin ~= nil and competitorMin > 0 and competitorMin < (auction.unitPrice or 0)
end

function S:CountUncancelledShown()
    local n = 0
    for _, a in ipairs(self.cancel.auctions or {}) do
        if a.auctionID and not self.cancel.cancelling[a.auctionID] then
            n = n + 1
        end
    end
    return n
end

function S:CountUncancelledUndercut()
    local n = 0
    for _, a in ipairs(self.cancel.auctions or {}) do
        if a.auctionID and not self.cancel.cancelling[a.auctionID] and self:IsAuctionUndercut(a) then
            n = n + 1
        end
    end
    return n
end

function S:CancelAllShownAuctions()
    for _, a in ipairs(self.cancel.auctions or {}) do
        if a.auctionID and not self.cancel.cancelling[a.auctionID] then
            self:CancelOwnedAuction(a.auctionID)
            return
        end
    end
end

function S:CancelUndercutAuctions()
    for _, a in ipairs(self.cancel.auctions or {}) do
        if a.auctionID and not self.cancel.cancelling[a.auctionID] and self:IsAuctionUndercut(a) then
            self:CancelOwnedAuction(a.auctionID)
            return
        end
    end
end

local function BuildTiersForResults(isCommodity, itemID, itemKey)
    local tiers, index, total = {}, {}, 0
    local function add(price, qty, owned)
        local t = index[price]
        if not t then
            t = { price = price, qty = 0, owned = false }
            index[price] = t
            tiers[#tiers + 1] = t
        end
        t.qty = t.qty + (qty or 0)
        if owned then t.owned = true end
    end

    if isCommodity then
        local n = C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0
        for i = 1, n do
            local ok, r = pcall(C_AuctionHouse.GetCommoditySearchResultInfo, itemID, i)
            if ok and r and r.unitPrice then
                add(r.unitPrice, r.quantity or 1, r.containsOwnerItem)
                total = total + (r.quantity or 1)
            end
        end
    else
        local n = C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
        for i = 1, n do
            local ok, r = pcall(C_AuctionHouse.GetItemSearchResultInfo, itemKey, i)
            if ok and r then
                local unit = r.buyoutAmount or r.bidAmount
                if unit and unit > 0 then
                    add(unit, r.quantity or 1, r.containsOwnerItem)
                    total = total + (r.quantity or 1)
                end
            end
        end
    end

    table.sort(tiers, function(a, b) return a.price < b.price end)
    return tiers, total
end

function S:StartUndercutScan()
    if not (C_AuctionHouse and C_AuctionHouse.SendSearchQuery and C_AuctionHouse.MakeItemKey) then return end
    if not self.isAuctionHouseOpen then return end

    local seen, queue = {}, {}
    for _, a in ipairs(self.cancel.auctions or {}) do
        if a.itemID and not seen[a.itemID] then
            seen[a.itemID] = true
            queue[#queue + 1] = a.itemID
        end
    end

    self.cancel.undercut = {}
    self.cancel.scan = { queue = queue, index = 0, results = 0, active = true, current = nil }
    self:ScanNextUndercut()
end

function S:ScanNextUndercut()
    local scan = self.cancel.scan
    if not scan or not scan.active then return end

    scan.index = scan.index + 1
    local itemID = scan.queue[scan.index]
    if not itemID then
        scan.active = false
        scan.current = nil
        if self.RefreshCancelUI then self:RefreshCancelUI() end
        return
    end

    scan.current = itemID
    local okKey, itemKey = pcall(C_AuctionHouse.MakeItemKey, itemID)
    scan.itemKey = okKey and itemKey or nil

    if self.RefreshCancelUI then self:RefreshCancelUI() end

    if scan.itemKey then
        pcall(C_AuctionHouse.SendSearchQuery, scan.itemKey, { { sortOrder = (Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price) or 1, reverseSort = false } }, true)
        C_Timer.After(2.0, function()
            if self.cancel.scan == scan and scan.active and scan.current == itemID then
                S:ScanNextUndercut()
            end
        end)
    else
        C_Timer.After(0.05, function() S:ScanNextUndercut() end)
    end
end

function S:OnCancelScanResults(isCommodity, idOrKey)
    local scan = self.cancel.scan
    if not scan or not scan.active or not scan.current then return end

    if isCommodity then
        if scan.current ~= idOrKey then return end
    else
        if type(idOrKey) ~= "table" or idOrKey.itemID ~= scan.current then return end
        if not scan.itemKey then return end
    end

    local tiers, total = BuildTiersForResults(isCommodity, scan.current, scan.itemKey)
    ComputeSellReference(tiers, total)

    local competitorMin = nil
    for _, t in ipairs(tiers) do
        if not t.isFlip and not t.owned then
            competitorMin = t.price
            break
        end
    end
    self.cancel.undercut[scan.current] = competitorMin or 0

    scan.results = scan.results + 1
    self:ScanNextUndercut()
end

local cancelEventFrame = CreateFrame("Frame")
cancelEventFrame:RegisterEvent("OWNED_AUCTIONS_UPDATED")
cancelEventFrame:RegisterEvent("AUCTION_CANCELED")
cancelEventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
cancelEventFrame:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
cancelEventFrame:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
cancelEventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "OWNED_AUCTIONS_UPDATED" then
        if S.frame and S.shopTab == "cancel" and S.frame:IsShown() then
            S:ReadOwnedAuctions()
        end
        return
    end

    if event == "AUCTION_CANCELED" then
        local auctionID = ...
        if auctionID then
            S.cancel.cancelling[auctionID] = nil
        end
        if S.frame and S.shopTab == "cancel" and S.frame:IsShown() then
            S:QueryOwnedAuctions()
        end
        return
    end

    if event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        if S.shopTab == "cancel" then
            S:OnCancelScanResults(true, ...)
        end
        return
    end

    if event == "ITEM_SEARCH_RESULTS_UPDATED" then
        if S.shopTab == "cancel" then
            S:OnCancelScanResults(false, ...)
        end
        return
    end

    if event == "AUCTION_HOUSE_CLOSED" then
        S.cancel.auctions = {}
        S.cancel.sold = {}
        S.cancel.totalOnSale = 0
        S.cancel.totalSold = 0
        S.cancel.cancelling = {}
        S.cancel.undercut = {}
        S.cancel.scan = nil
        S.cancel.pending = false
        return
    end
end)
