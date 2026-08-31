local E = _G.HironCraftProfitShoppingListEnv
if not E then
    E = {}
    _G.HironCraftProfitShoppingListEnv = E
    setmetatable(E, { __index = _G })
end
setfenv(1, E)

PT = HironCraftProfit
if not PT then return end

PT.ShoppingList = PT.ShoppingList or {}
S = PT.ShoppingList

FONT = HironCraftProfit.FONT or STANDARD_TEXT_FONT
L = PT.L or {}
LibAHTab = LibStub and LibStub("LibAHTab-1-0", true)
S.LibAHTab = LibAHTab

function GetLibAHTab()
    if not LibAHTab and LibStub then
        LibAHTab = LibStub("LibAHTab-1-0", true)
        S.LibAHTab = LibAHTab
    end
    return LibAHTab
end

AH_TAB_ID = "HironCraftProfitProfessionShopping"
AH_TAB_TEXT_KEY = "PG_SHOP_TAB"

function T(key, default)
    return L[key] or default or key
end

TITLE = "PG_SHOP_TITLE"
ROW_HEIGHT = 28
ROW_GAP = 2
SEARCH_PENDING_TIMEOUT = 5.0
SEARCH_STEP_DELAY = 0.5
MAX_SEARCH_RETRIES = 1
SCAN_ALL_DUPLICATE_WINDOW = 5.0
WINDOW_WIDTH = 920
WINDOW_HEIGHT = 420

S.FONT = FONT
S.AH_TAB_ID = AH_TAB_ID
S.AH_TAB_TEXT_KEY = AH_TAB_TEXT_KEY
S.TITLE = TITLE
S.ROW_HEIGHT = ROW_HEIGHT
S.ROW_GAP = ROW_GAP
S.WINDOW_WIDTH = WINDOW_WIDTH
S.WINDOW_HEIGHT = WINDOW_HEIGHT

S.session = S.session or {
    active = false,
    rows = {},
    skillLineID = nil,
    itemData = {},
}
S.isAuctionHouseOpen = false
S.scanAllState = S.scanAllState or {
    active = false,
    queue = nil,
    pointer = 0,
    token = 0,
}
S.buyAllState = S.buyAllState or {
    active = false,
    order = nil,
    pointer = 1,
    currentRowIndex = nil,
}
S.frame = S.frame or nil
S.pendingCommodityRow = nil
S.pendingSearchCommodityRow = nil
S.pendingItemPurchases = S.pendingItemPurchases or {}
S.pendingSearchItemPurchases = S.pendingSearchItemPurchases or {}
S.importResolveState = S.importResolveState or nil
S.searchResults = S.searchResults or {
    active = false,
    pending = false,
    query = "",
    rows = {},
    serial = 0,
}
S.directSearchBuy = S.directSearchBuy or nil
S.OnShoppingDataChanged = S.OnShoppingDataChanged or nil
S.OnAuctionStateChanged = S.OnAuctionStateChanged or nil


PT.config = PT.config or {}

if PT.config.shoppingListMirrorAuctionatorAPI == nil then
    PT.config.shoppingListMirrorAuctionatorAPI = PT.config.shoppingListInterceptCraftSim == true
end
if PT.config.shoppingListInterceptCraftSim == nil then
    PT.config.shoppingListInterceptCraftSim = PT.config.shoppingListMirrorAuctionatorAPI == true
end

if PT.config.shoppingListMirrorAutoScan == nil then
    PT.config.shoppingListMirrorAutoScan = false
end

function S:IsAuctionatorPlanMirrorEnabled()
    return PT.config and PT.config.shoppingListMirrorAuctionatorAPI == true
end

function S:SetAuctionatorPlanMirrorEnabled(value)
    PT.config = PT.config or {}
    local enabled = value == true
    PT.config.shoppingListMirrorAuctionatorAPI = enabled
    PT.config.shoppingListInterceptCraftSim = enabled

    if enabled and self.EnsureAuctionatorPlanMirror then
        self:EnsureAuctionatorPlanMirror()
    end

    if self.RefreshWindow then
        self:RefreshWindow()
    end

    return enabled
end

function S:IsCraftSimInterceptEnabled()
    return self.IsAuctionatorPlanMirrorEnabled and self:IsAuctionatorPlanMirrorEnabled()
end

function S:SetCraftSimInterceptEnabled(value)
    if self.SetAuctionatorPlanMirrorEnabled then
        return self:SetAuctionatorPlanMirrorEnabled(value)
    end
    return false
end

function IsAHAvailable()
    return C_AuctionHouse
        and C_AuctionHouse.MakeItemKey
        and C_AuctionHouse.SendSearchQuery
        and C_AuctionHouse.GetNumCommoditySearchResults
        and C_AuctionHouse.GetCommoditySearchResultInfo
        and C_AuctionHouse.GetNumItemSearchResults
        and C_AuctionHouse.GetItemSearchResultInfo
end

function FormatMoneyText(value)
    if type(value) ~= "number" or value <= 0 then
        return T("PG_DASH", "—")
    end
    return GetCoinTextureString(value, 12) or tostring(value)
end

function IsValidItemID(itemID)
    local n = tonumber(itemID)
    if not n then return false end
    n = math.floor(n)
    return n > 0 and n < 2147483647
end

function RequestItemData(itemID)
    if not IsValidItemID(itemID) then
        return
    end
    if not C_Item or not C_Item.RequestLoadItemDataByID then
        return
    end
    local okInfo, name = pcall(GetItemInfo, itemID)
    if okInfo and name then
        return
    end
    pcall(C_Item.RequestLoadItemDataByID, tonumber(itemID))
end

function GetItemName(itemID)
    if not itemID then
        return "?"
    end
    local name = GetItemInfo(itemID)
    if name then
        return name
    end
    RequestItemData(itemID)
    return T("PG_LOADING_ITEM", "Загрузка...")
end

function GetItemIcon(itemID)
    if not itemID then
        return 134400
    end
    local _, _, _, _, icon = GetItemInfoInstant(itemID)
    return icon or 134400
end

function IsPlaceholderItemLabel(label, itemID)
    local value = tostring(label or "")
    if value == "" then
        return true
    end
    if value == T("PG_LOADING_ITEM", "Загрузка...") then
        return true
    end
    if itemID and value == ("item:" .. tostring(itemID)) then
        return true
    end
    return false
end

function RequestSessionItemData()
    local session = S.session
    if not session or not session.rows then return end

    local key = tostring(session.importSerial or "") .. ":" .. tostring(#session.rows)
    if S._sessionItemDataServed == key then
        return
    end

    for _, row in ipairs(session.rows) do
        RequestItemData(row.itemID)
        RequestItemData(row.chosenItemID)
        for _, opt in ipairs(row.options or {}) do
            RequestItemData(opt.itemID)
        end
    end

    S._sessionItemDataServed = key
end

function GetRowTooltipItemID(rowData)
    if not rowData then
        return nil
    end
    return rowData.chosenItemID or rowData.itemID or (rowData.options and rowData.options[1] and rowData.options[1].itemID)
end

function AnchorTooltipAtCursor()
    if not GameTooltip or not UIParent or not GetCursorPosition then return end
    local scale = UIParent:GetEffectiveScale() or 1
    local x, y = GetCursorPosition()
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end

function ShowRowTooltip(widget)
    local rowIndex = widget and widget.rowIndex
    local rowData = rowIndex and S.session and S.session.rows and S.session.rows[rowIndex]
    local itemID = GetRowTooltipItemID(rowData)
    if not itemID or not GameTooltip then
        return
    end
    GameTooltip:SetOwner(widget, "ANCHOR_NONE")
    GameTooltip:SetHyperlink("item:" .. itemID)
    AnchorTooltipAtCursor()
    GameTooltip:Show()
end

function GetRemainingQuantity(row)
    return math.max(0, tonumber(row and row.remainingQuantity) or tonumber(row and row.quantity) or 0)
end

function GetVisibleRows()
    local out = {}
    for _, row in ipairs(S.session and S.session.rows or {}) do
        if not row.hidden then
            table.insert(out, row)
        end
    end
    return out
end

function HasShoppingSession()
    return S.session and S.session.active and S.session.rows ~= nil
end

function ShouldShowAuctionTab()
    return HasShoppingSession() or (PT.config and PT.config.shoppingListAlwaysShowTab == true)
end

function UpdateAuctionTabVisibility()
    local tabLib = GetLibAHTab()
    if not tabLib or not tabLib.DoesIDExist or not tabLib.GetButton then return end
    if not tabLib:DoesIDExist(AH_TAB_ID) then return end

    local button = tabLib:GetButton(AH_TAB_ID)
    if button then
        button:SetShown(ShouldShowAuctionTab())
    end
end

function MarkRowPurchased(row, statusText)
    if not row then return end
    row.remainingQuantity = 0
    row.searchPending = false
    row.purchaseStage = nil
    row.pendingQuantity = nil
    row.pendingUnitPrice = nil
    row.pendingTotalPrice = nil
    row.totalQuantity = 0
    row.minPrice = nil
    row.bestAuctionID = nil
    row.bestAuctionQuantity = nil
    row.bestBuyoutAmount = nil
    row.hidden = true
    row.status = statusText or T("PG_SHOP_STATUS_BOUGHT", "Bought")
end

function AnnouncePurchase(itemID, quantity, totalCopper)
    itemID = tonumber(itemID)
    if not itemID then return end
    local link = select(2, GetItemInfo(itemID)) or ("item:" .. itemID)
    local qty = (tonumber(quantity) and tonumber(quantity) > 0) and ("\195\151" .. quantity) or ""
    local price = ""
    if tonumber(totalCopper) and tonumber(totalCopper) > 0 then
        local coins = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString and C_CurrencyInfo.GetCoinTextureString(totalCopper))
            or (GetCoinTextureString and GetCoinTextureString(totalCopper))
            or tostring(totalCopper)
        price = " " .. T("PG_SHOP_BUY_ANNOUNCE_FOR", "for") .. " " .. coins
    end
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffb19cd9HironCraft|r %s %s %s%s",
            T("PG_SHOP_BUY_ANNOUNCE", "bought:"), link, qty, price))
    end
end

function IsRowBuyableNow(row)
    if not row or GetRemainingQuantity(row) <= 0 or not row.chosenItemID or not row.minPrice then
        return false
    end
    if row.purchaseStage == "await_price" or row.purchaseStage == "confirm" or row.purchaseStage == "processing" or row.searchPending then
        return true
    end
    if row.isCommodity == true then
        return (tonumber(row.totalQuantity) or 0) > 0
    end
    if row.isCommodity == false then
        return row.bestAuctionID ~= nil and row.bestBuyoutAmount ~= nil
    end
    return false
end

function NormalizeTierValue(value)
    local n = tonumber(value)
    if not n then
        return nil
    end
    n = math.floor(n)
    if n < 1 or n > 5 then
        return nil
    end
    return n
end

function GetExplicitOptionTier(opt)
    if type(opt) ~= "table" then
        return nil
    end
    return NormalizeTierValue(opt.tier or opt.qualityTier or opt.professionQuality or opt.craftedQuality or opt.materialQuality)
end

function CopyOptions(options)
    local out = {}
    for _, opt in ipairs(options or {}) do
        if type(opt) == "table" and opt.itemID then
            local tier = GetExplicitOptionTier(opt)
            table.insert(out, {
                itemID = tonumber(opt.itemID),
                tier = tier,
                materialQuality = tier or NormalizeTierValue(opt.materialQuality),
                professionQuality = NormalizeTierValue(opt.professionQuality),
                craftedQuality = NormalizeTierValue(opt.craftedQuality),
                label = opt.label or opt.name,
            })
        end
    end
    return out
end

function CopyTierFieldsFrom(source, target)
    if type(source) ~= "table" or type(target) ~= "table" then
        return target
    end

    local tier = NormalizeTierValue(
        source.tier
        or source.qualityTier
        or source.chosenTier
        or source.professionQuality
        or source.craftedQuality
        or source.materialQuality
    )

    target.tier = target.tier or tier
    target.chosenTier = NormalizeTierValue(source.chosenTier) or target.chosenTier or tier
    target.materialQuality = NormalizeTierValue(source.materialQuality) or target.materialQuality or tier
    target.professionQuality = NormalizeTierValue(source.professionQuality) or target.professionQuality or tier
    target.craftedQuality = NormalizeTierValue(source.craftedQuality) or target.craftedQuality
    target.quality = source.quality or source.itemQuality or target.quality
    target.itemClassID = source.itemClassID or source.classID or target.itemClassID
    target.itemSubClassID = source.itemSubClassID or source.subClassID or target.itemSubClassID
    target.expansionID = source.expansionID or target.expansionID

    return target
end

function GetDB()
    _G.HironCraftProfit_DB = _G.HironCraftProfit_DB or {}
    _G.HironCraftProfit_DB.shoppingList = _G.HironCraftProfit_DB.shoppingList or {}
    local db = _G.HironCraftProfit_DB.shoppingList
    db.nextListID = tonumber(db.nextListID) or 1
    db.savedLists = db.savedLists or {}
    return db
end

SEARCH_DEFAULTS = {
    exactMatch = false,
    categoryKey = "any",
    itemClassID = nil,
    itemSubClassID = nil,
    inventoryType = nil,
    quality = "any",
    sortMode = "price_asc",
    onlyAvailable = false,
    hideNoPrice = false,
    minPrice = "",
    maxPrice = "",
    minQuantity = "",
    minItemLevel = "",
    maxItemLevel = "",
    minRequiredLevel = "",
    maxRequiredLevel = "",
    expansionID = "any",
    materialQuality = "any",
}

function CopySearchDefaults()
    local out = {}
    for key, value in pairs(SEARCH_DEFAULTS) do
        out[key] = value
    end
    return out
end

QUALITY_TO_FILTER = {
    poor      = "PoorQuality",
    common    = "CommonQuality",
    uncommon  = "UncommonQuality",
    rare      = "RareQuality",
    epic      = "EpicQuality",
    legendary = "LegendaryQuality",
    artifact  = "ArtifactQuality",
}

QUALITY_TO_ITEM_QUALITY = {
    poor      = 0,
    common    = 1,
    uncommon  = 2,
    rare      = 3,
    epic      = 4,
    legendary = 5,
    artifact  = 6,
}

function SoftRefreshSearchUI()
    if S.frame and S.frame:IsShown() and S.RefreshWindow then
        S:RefreshWindow()
    end
end

function NormalizeOptionText(value)
    value = tostring(value or "")
    value = value:gsub("^%s+", "")
    value = value:gsub("%s+$", "")
    return value
end

function ParsePlainNumber(value)
    value = NormalizeOptionText(value)
    if value == "" then
        return nil
    end
    local n = tonumber(value)
    if not n then
        return nil
    end
    return math.floor(n)
end

function ParseMoneyInput(value)
    value = NormalizeOptionText(value)
    if value == "" then
        return nil
    end
    local lower = string.lower(value)
    local gold = tonumber(lower:match("([%d%.]+)%s*g")) or tonumber(lower:match("([%d%.]+)%s*з"))
    local silver = tonumber(lower:match("([%d%.]+)%s*s")) or tonumber(lower:match("([%d%.]+)%s*с"))
    local copper = tonumber(lower:match("([%d%.]+)%s*c")) or tonumber(lower:match("([%d%.]+)%s*м"))
    if gold or silver or copper then
        return math.floor((gold or 0) * 10000 + (silver or 0) * 100 + (copper or 0))
    end
    local plain = tonumber(lower)
    if plain then
        return math.floor(plain * 10000)
    end
    return nil
end

function ReadMaterialQuality(itemID, itemLink)
    if C_TradeSkillUI and C_TradeSkillUI.GetItemReagentQualityByItemInfo then
        local ok, quality = pcall(C_TradeSkillUI.GetItemReagentQualityByItemInfo, itemLink or itemID)
        if ok and quality then
            return tonumber(quality)
        end
    end
    return nil
end

function ReadCraftedQuality(itemID, itemLink)
    if C_TradeSkillUI and C_TradeSkillUI.GetItemCraftedQualityByItemInfo then
        local ok, quality = pcall(C_TradeSkillUI.GetItemCraftedQualityByItemInfo, itemLink or itemID)
        if ok and quality then
            return tonumber(quality)
        end
    end
    return nil
end

function ReadProfessionQuality(itemID, itemLink)
    local craftedQuality = ReadCraftedQuality(itemID, itemLink)
    local materialQuality = ReadMaterialQuality(itemID, itemLink)
    return craftedQuality or materialQuality, craftedQuality, materialQuality
end

function ReadSearchItemStaticInfo(itemID)
    if not itemID then
        return {}
    end
    local name, link, quality, itemLevel, requiredLevel, itemType, itemSubType, stackCount, equipLoc, icon, sellPrice, classID, subClassID, bindType, expansionID = GetItemInfo(itemID)
    if not name then
        RequestItemData(itemID)
    end
    local professionQuality, craftedQuality, materialQuality = ReadProfessionQuality(itemID, link)
    return {
        name = name,
        link = link,
        quality = quality,
        itemLevel = itemLevel,
        requiredLevel = requiredLevel,
        classID = classID,
        subClassID = subClassID,
        expansionID = expansionID,
        stackCount = stackCount,
        professionQuality = professionQuality,
        craftedQuality = craftedQuality,
        materialQuality = materialQuality,
    }
end

function ResolveOptionTier(opt)
    if type(opt) ~= "table" then
        return nil
    end
    local tier = GetExplicitOptionTier(opt)
    if tier then
        return tier
    end
    local itemID = tonumber(opt.itemID)
    if not itemID then
        return nil
    end
    local _, link = GetItemInfo(itemID)
    if not link then
        RequestItemData(itemID)
    end
    tier = NormalizeTierValue(ReadMaterialQuality(itemID, link))
    if tier then
        opt.materialQuality = tier
        return tier
    end
    return nil
end

function S:GetSearchOptions()
    self.searchOptions = self.searchOptions or CopySearchDefaults()
    local opts = self.searchOptions

    for key, value in pairs(SEARCH_DEFAULTS) do
        if opts[key] == nil then
            opts[key] = value
        end
    end

    if opts.quality == nil or opts.quality == "" then
        opts.quality = "any"
    end
    if opts.sortMode == nil or opts.sortMode == "" then
        opts.sortMode = "price_asc"
    end
    if opts.expansionID == nil or opts.expansionID == "" then
        opts.expansionID = "any"
    end
    if opts.materialQuality == nil or opts.materialQuality == "" then
        opts.materialQuality = "any"
    end

    if opts.itemClassID == "any" or opts.itemClassID == "" then
        opts.itemClassID = nil
    end
    if opts.itemSubClassID == "any" or opts.itemSubClassID == "" then
        opts.itemSubClassID = nil
    end

    return opts
end

function S:SetSearchOption(key, value, noRefresh)
    local opts = self:GetSearchOptions()
    opts[key] = value
    if not noRefresh then
        SoftRefreshSearchUI()
    end
    return true
end

function S:ResetSearchOptions(noRefresh)
    self.searchOptions = CopySearchDefaults()

    if not noRefresh then
        SoftRefreshSearchUI()
    end

    return true
end

function S:HasActiveServerSearchFilters()
    local opts = self:GetSearchOptions()
    if opts.itemClassID ~= nil then return true end
    if opts.itemSubClassID ~= nil then return true end
    if opts.inventoryType ~= nil then return true end
    if opts.quality and opts.quality ~= "any" then return true end
    if ParsePlainNumber(opts.minRequiredLevel) then return true end
    if ParsePlainNumber(opts.maxRequiredLevel) then return true end
    return false
end

function S:HasActiveSearchFilters()
    local opts = self:GetSearchOptions()
    if self:HasActiveServerSearchFilters() then return true end
    if opts.onlyAvailable then return true end
    if opts.hideNoPrice then return true end
    if ParseMoneyInput(opts.minPrice) then return true end
    if ParseMoneyInput(opts.maxPrice) then return true end
    if ParsePlainNumber(opts.minQuantity) then return true end
    if ParsePlainNumber(opts.minItemLevel) then return true end
    if ParsePlainNumber(opts.maxItemLevel) then return true end
    if opts.expansionID and opts.expansionID ~= "any" then return true end
    if opts.materialQuality and opts.materialQuality ~= "any" then return true end
    return false
end

function S:CanRunEmptyAuctionSearch()
    return self:HasActiveSearchFilters()
end

function S:SearchResultMatchesOptions(row)
    if not row then
        return false
    end

    local opts = self:GetSearchOptions()
    local itemID = row.itemID or row.chosenItemID
    if itemID and (row.quality == nil or row.itemLevel == nil or row.requiredLevel == nil or row.itemClassID == nil) then
        local info = ReadSearchItemStaticInfo(itemID)
        row.quality = row.quality or info.quality
        row.itemLevel = row.itemLevel or info.itemLevel
        row.requiredLevel = row.requiredLevel or info.requiredLevel
        row.itemClassID = row.itemClassID or info.classID
        row.itemSubClassID = row.itemSubClassID or info.subClassID
        row.expansionID = row.expansionID or info.expansionID
        row.professionQuality = row.professionQuality or info.professionQuality
        row.craftedQuality = row.craftedQuality or info.craftedQuality
        row.materialQuality = row.materialQuality or info.materialQuality
    end

    local price = tonumber(row.minPrice)
    local quantity = tonumber(row.totalQuantity) or 0

    if opts.onlyAvailable and quantity <= 0 then return false end
    if opts.hideNoPrice and not price then
        local finalNoPrice = row.totalQuantity ~= nil and quantity <= 0
        local finalCommodityNoPrice = row.isCommodity == true and row.totalQuantity ~= nil
        if finalNoPrice or finalCommodityNoPrice then return false end
    end

    local minPrice = ParseMoneyInput(opts.minPrice)
    local maxPrice = ParseMoneyInput(opts.maxPrice)
    if minPrice and (not price or price < minPrice) then return false end
    if maxPrice and (not price or price > maxPrice) then return false end

    local minQuantity = ParsePlainNumber(opts.minQuantity)
    if minQuantity and quantity < minQuantity then return false end

    local minItemLevel = ParsePlainNumber(opts.minItemLevel)
    local maxItemLevel = ParsePlainNumber(opts.maxItemLevel)
    local itemLevel = tonumber(row.itemLevel)

    local minRequiredLevel = ParsePlainNumber(opts.minRequiredLevel)
    local maxRequiredLevel = ParsePlainNumber(opts.maxRequiredLevel)
    local requiredLevel = tonumber(row.requiredLevel)

    if minItemLevel then
        if itemLevel == nil or itemLevel < minItemLevel then return false end
    end
    if maxItemLevel then
        if itemLevel == nil or itemLevel > maxItemLevel then return false end
    end

    if minRequiredLevel then
        if requiredLevel == nil or requiredLevel < minRequiredLevel then return false end
    end
    if maxRequiredLevel then
        if requiredLevel == nil or requiredLevel > maxRequiredLevel then return false end
    end

    if opts.quality and opts.quality ~= "any" then
        local expectedQuality = QUALITY_TO_ITEM_QUALITY[opts.quality]
        if expectedQuality ~= nil then
            if row.quality == nil or tonumber(row.quality) ~= expectedQuality then
                return false
            end
        end
    end

    if opts.itemClassID ~= nil then
        if row.itemClassID == nil or tonumber(row.itemClassID) ~= tonumber(opts.itemClassID) then return false end
    end
    if opts.itemSubClassID ~= nil then
        if row.itemSubClassID == nil or tonumber(row.itemSubClassID) ~= tonumber(opts.itemSubClassID) then return false end
    end
    if opts.inventoryType ~= nil then
        if row.inventoryType == nil or tonumber(row.inventoryType) ~= tonumber(opts.inventoryType) then return false end
    end
    if opts.expansionID and opts.expansionID ~= "any" then
        if row.expansionID == nil or tonumber(row.expansionID) ~= tonumber(opts.expansionID) then return false end
    end
    if opts.materialQuality and opts.materialQuality ~= "any" then
        if row.materialQuality == nil or tonumber(row.materialQuality) ~= tonumber(opts.materialQuality) then return false end
    end

    return true
end

function ExportMaterialRows(rows)
    local out = {}
    for _, row in ipairs(rows or {}) do
        local quantity = tonumber(row.quantity) or tonumber(row.remainingQuantity) or 0
        local hasOptions = row.options and #row.options > 0
        local unresolvedName = NormalizeOptionText(row.unresolvedName or row.importName or ((not row.itemID and not hasOptions) and row.label) or "")

        if quantity > 0 and (row.itemID or hasOptions or unresolvedName ~= "") then
            local tier = NormalizeTierValue(row.chosenTier or row.tier or row.professionQuality or row.craftedQuality or row.materialQuality)
            local importSearchName = NormalizeOptionText(row.importSearchName or unresolvedName)
            table.insert(out, {
                itemID = row.itemID,
                unresolvedName = unresolvedName ~= "" and unresolvedName or nil,
                importName = unresolvedName ~= "" and unresolvedName or nil,
                importSearchName = importSearchName ~= "" and importSearchName or nil,
                importExpandGrades = row.importExpandGrades == true,
                importResolveAttempted = row.importResolveAttempted == true,
                auctionatorSearchString = row.auctionatorSearchString,
                auctionatorTier = NormalizeTierValue(row.auctionatorTier),
                auctionatorIsExact = row.auctionatorIsExact,
                itemKey = row.itemKey,
                itemLevel = row.itemLevel,
                itemSuffix = row.itemSuffix,
                quality = row.quality,
                itemClassID = row.itemClassID,
                itemSubClassID = row.itemSubClassID,
                expansionID = row.expansionID,
                maxTier = row.maxTier,
                options = CopyOptions(row.options),
                quantity = quantity,
                label = row.label or unresolvedName,
                tier = tier,
                chosenTier = tier,
                materialQuality = tier or NormalizeTierValue(row.materialQuality),
                professionQuality = tier or NormalizeTierValue(row.professionQuality),
                craftedQuality = NormalizeTierValue(row.craftedQuality),
            })
        end
    end
    return out
end

function SyncActiveSavedList()
    local id = S.activeSavedListID
    if not id then
        return
    end
    local db = GetDB()
    for _, list in ipairs(db.savedLists or {}) do
        if list.id == id then
            list.rows = ExportMaterialRows(S.session and S.session.rows or {})
            list.skillLineID = S.session and S.session.skillLineID or list.skillLineID
            list.updatedAt = time and time() or 0
            return
        end
    end
end

function GetOptionLabel(opt)
    if not opt or not opt.itemID then
        return T("PG_DASH", "—")
    end
    local tier = ResolveOptionTier(opt)
    if tier then
        return string.format("|cff7f7f7fR%d|r", tier)
    end
    if opt.label and opt.label ~= "" then
        return opt.label
    end
    return GetItemName(opt.itemID)
end

function GetRowBaseLabel(row)
    if row.label and row.label ~= "" then
        return row.label
    end
    local displayItemID = row.chosenItemID or row.itemID or (row.options and row.options[1] and row.options[1].itemID)
    if displayItemID then
        return GetItemName(displayItemID)
    end
    return "?"
end

function NormalizeMaterials(materials)
    local rows = {}
    if not materials then
        return rows
    end

    for _, entry in ipairs(materials) do
        if type(entry) == "table" then
            local unresolvedName = NormalizeOptionText(entry.unresolvedName or entry.importName or entry.nameOnlyName or ((not entry.itemID and not entry.options and not entry.anyOf) and entry.label) or "")
            local options = CopyOptions(entry.options or entry.anyOf)
            local tier = NormalizeTierValue(entry.chosenTier or entry.tier or entry.qualityTier or entry.professionQuality or entry.craftedQuality or entry.materialQuality)
            local importSearchName = NormalizeOptionText(entry.importSearchName or unresolvedName)

            local row = {
                itemID = entry.itemID,
                unresolvedName = unresolvedName ~= "" and unresolvedName or nil,
                importName = unresolvedName ~= "" and unresolvedName or nil,
                importSearchName = importSearchName ~= "" and importSearchName or nil,
                importExpandGrades = entry.importExpandGrades == true,
                importResolveAttempted = entry.importResolveAttempted == true,
                auctionatorSearchString = entry.auctionatorSearchString,
                auctionatorTier = NormalizeTierValue(entry.auctionatorTier),
                auctionatorIsExact = entry.auctionatorIsExact,
                itemKey = entry.itemKey,
                itemLevel = tonumber(entry.itemLevel),
                itemSuffix = tonumber(entry.itemSuffix),
                quality = entry.quality or entry.itemQuality,
                itemClassID = entry.itemClassID or entry.classID,
                itemSubClassID = entry.itemSubClassID or entry.subClassID,
                expansionID = entry.expansionID,
                maxTier = tonumber(entry.maxTier) or (options and #options > 1 and #options or nil),
                options = options,
                quantity = tonumber(entry.quantity or entry.count) or 0,
                label = entry.label or (unresolvedName ~= "" and unresolvedName or nil),
                tier = tier,
                chosenTier = tier,
                materialQuality = tier or NormalizeTierValue(entry.materialQuality),
                professionQuality = tier or NormalizeTierValue(entry.professionQuality),
                craftedQuality = NormalizeTierValue(entry.craftedQuality),
            }

            if row.quantity > 0 and (row.itemID or (#row.options > 0) or row.unresolvedName) then
                table.insert(rows, row)
            end
        end
    end

    table.sort(rows, function(a, b)
        local an = GetRowBaseLabel(a)
        local bn = GetRowBaseLabel(b)
        if an == bn then
            local aid = a.itemID or (a.options[1] and a.options[1].itemID) or 0
            local bid = b.itemID or (b.options[1] and b.options[1].itemID) or 0
            return aid < bid
        end
        return an < bn
    end)

    for index, row in ipairs(rows) do
        local tier = NormalizeTierValue(row.chosenTier or row.tier or row.professionQuality or row.craftedQuality or row.materialQuality)
        row.index = index
        row.remainingQuantity = row.quantity
        row.status = T("PG_SHOP_STATUS_NOT_SCANNED", "Not scanned")
        row.searchPending = false
        row.purchaseStage = nil
        row.pendingQuantity = nil
        row.pendingUnitPrice = nil
        row.pendingTotalPrice = nil
        row.chosenItemID = row.itemID
        row.chosenTier = tier
        row.tier = tier
        row.materialQuality = tier or row.materialQuality
        row.professionQuality = tier or row.professionQuality
        row.minPrice = nil
        row.totalQuantity = nil
        row.isCommodity = nil
        row.bestAuctionID = nil
        row.bestAuctionQuantity = nil
        row.bestBuyoutAmount = nil
        row.lastChosenName = tier and string.format("R%d", tier) or nil
        row.hidden = false
    end

    return rows
end

function ReindexSessionRows()
    if not S.session or not S.session.rows then return end
    for index, row in ipairs(S.session.rows) do
        row.index = index
    end
end

function RefreshShoppingWindow()
    if S.frame and S.frame:IsShown() and S.RefreshWindow then
        S:RefreshWindow()
    end
    if S.OnShoppingDataChanged then
        S:OnShoppingDataChanged()
    end
end

function EnsureManualShoppingSession(name)
    S.session = S.session or {}
    if not S.session.active then
        S.activeSavedListID = nil
        if S.ResetSearchOptions then S:ResetSearchOptions(true) end
        S.session = {
            active = true,
            rows = {},
            skillLineID = nil,
            itemData = {},
            listName = name or T("PG_SHOP_MANUAL_LIST_DEFAULT", "Manual list"),
            listKind = "manual",
        }
        S.pendingCommodityRow = nil
        S.pendingItemPurchases = {}
    end
    S.session.rows = S.session.rows or {}
    S.session.itemData = S.session.itemData or {}
    return S.session
end

function MakeManualRow(itemID, quantity, label, sourceData)
    local row = {
        itemID = itemID,
        options = {},
        quantity = quantity,
        label = label,
        remainingQuantity = quantity,
        status = T("PG_SHOP_STATUS_NOT_SCANNED", "Not scanned"),
        searchPending = false,
        purchaseStage = nil,
        pendingQuantity = nil,
        pendingUnitPrice = nil,
        pendingTotalPrice = nil,
        chosenItemID = itemID,
        chosenTier = nil,
        minPrice = nil,
        totalQuantity = nil,
        isCommodity = nil,
        bestAuctionID = nil,
        bestAuctionQuantity = nil,
        bestBuyoutAmount = nil,
        lastChosenName = nil,
        hidden = false,
    }

    CopyTierFieldsFrom(sourceData, row)

    if row.tier and not row.chosenTier then
        row.chosenTier = row.tier
    end

    return row
end

function S:ClearAuctionSearch(keepSearchText)
    self.searchResults = self.searchResults or {}
    self.searchResults.active = false
    self.searchResults.pending = false
    self.searchResults.query = ""
    self.searchResults.rows = {}
    self.searchResults.serial = (self.searchResults.serial or 0) + 1
    if not keepSearchText and self.ClearSearchText then
        self:ClearSearchText(true)
    end
    RefreshShoppingWindow()
end

function S:AddManualItem(itemID, quantity, label, sourceData)
    itemID = tonumber(itemID)
    quantity = math.floor(tonumber(quantity) or 1)

    if not itemID or itemID <= 0 then
        return false, "bad_item_id"
    end
    if quantity <= 0 then quantity = 1 end
    if quantity > 999999 then quantity = 999999 end

    RequestItemData(itemID)

    if IsPlaceholderItemLabel(label, itemID) then
        label = GetItemInfo(itemID)
    end

    local session = EnsureManualShoppingSession()
    local rows = session.rows

    for _, row in ipairs(rows or {}) do
        if row.itemID == itemID and not (row.options and #row.options > 0) then
            row.hidden = false
            row.quantity = math.min(999999, (tonumber(row.quantity) or 0) + quantity)
            row.remainingQuantity = math.min(999999, (tonumber(row.remainingQuantity) or 0) + quantity)
            row.chosenItemID = itemID
            row.status = T("PG_SHOP_STATUS_NOT_SCANNED", "Not scanned")
            row.purchaseStage = nil
            row.pendingQuantity = nil
            row.pendingUnitPrice = nil
            row.pendingTotalPrice = nil
            if IsPlaceholderItemLabel(row.label, itemID) and label then
                row.label = label
            end

            CopyTierFieldsFrom(sourceData, row)

            if row.tier and not row.chosenTier then
                row.chosenTier = row.tier
            end

            ReindexSessionRows()
            SyncActiveSavedList()
            RefreshShoppingWindow()
            if self.isAuctionHouseOpen and self.SearchItemID then
                C_Timer.After(0.05, function()
                    if S.session and S.session.active then
                        S:SearchItemID(itemID, true)
                    end
                end)
            end
            return true, row.index
        end
    end

    local row = MakeManualRow(itemID, quantity, label or GetItemInfo(itemID), sourceData)
    table.insert(rows, row)
    ReindexSessionRows()
    SyncActiveSavedList()
    RefreshShoppingWindow()

    if self.ShowWindow then
        self:ShowWindow()
    end

    if self.isAuctionHouseOpen and self.SearchItemID then
        C_Timer.After(0.05, function()
            if S.session and S.session.active then
                S:SearchItemID(itemID, true)
            end
        end)
    end

    return true, row.index
end


function FindSearchResultRowByItemID(itemID)
    if not itemID or not S.searchResults or not S.searchResults.rows then
        return nil
    end
    for _, row in ipairs(S.searchResults.rows or {}) do
        if row.itemID == itemID then
            return row
        end
    end
    return nil
end

function RefreshSearchResultNames(itemID)
    if not S.searchResults or not S.searchResults.rows then
        return false
    end

    local changed = false
    local query = S.searchResults.originalQuery or S.searchResults.query or ""

    for index = #S.searchResults.rows, 1, -1 do
        local row = S.searchResults.rows[index]
        if row and row.itemID and (not itemID or row.itemID == itemID) then
            local name = ReadBrowseResultName(row.itemKey, row.itemID)
            if name and name ~= "" then
                if not SearchResultNameMatches(name, query) then
                    if S.searchResults.seen then
                        S.searchResults.seen[row.seenKey or tostring(row.itemID)] = nil
                    end
                    table.remove(S.searchResults.rows, index)
                    changed = true
                elseif row.label ~= name then
                    row.label = name
                    row.loadingName = false
                    changed = true
                end
            end
        end
    end

    return changed
end

function GetSearchResultProxyRow(searchRow)
    if not searchRow then
        return nil
    end
    if searchRow.sessionRowIndex and S.session and S.session.rows then
        local row = S.session.rows[searchRow.sessionRowIndex]
        if row and row.itemID == searchRow.itemID then
            return row
        end
    end
    local live = FindRowByItemID(searchRow.itemID)
    if live then
        searchRow.sessionRowIndex = live.index
        return live
    end
    return nil
end

function TryDirectSearchBuy()
    RefreshShoppingWindow()
end

function S:GetSearchResultProxyRow(searchRow)
    return GetSearchResultProxyRow(searchRow)
end

function S:BuySearchResult(itemID, quantity, label)
    local row = FindSearchResultRowByItemID(tonumber(itemID))
    if row and self.BuySearchResultRow then
        return self:BuySearchResultRow(row, quantity)
    end
    return false, "missing_search_row"
end

SEARCH_RESULT_LIMIT = 150
SEARCH_DEEP_RESULT_LIMIT = 800
BROWSE_STEP_DELAY = 0.18
BROWSE_MORE_REQUEST_LIMIT = 18
BROWSE_DEEP_MORE_REQUEST_LIMIT = 80

CYR_LOWER_MAP = {
    ["А"]="а", ["Б"]="б", ["В"]="в", ["Г"]="г", ["Д"]="д", ["Е"]="е", ["Ё"]="е", ["Ж"]="ж", ["З"]="з", ["И"]="и", ["Й"]="й", ["К"]="к", ["Л"]="л", ["М"]="м", ["Н"]="н", ["О"]="о", ["П"]="п", ["Р"]="р", ["С"]="с", ["Т"]="т", ["У"]="у", ["Ф"]="ф", ["Х"]="х", ["Ц"]="ц", ["Ч"]="ч", ["Ш"]="ш", ["Щ"]="щ", ["Ъ"]="ъ", ["Ы"]="ы", ["Ь"]="ь", ["Э"]="э", ["Ю"]="ю", ["Я"]="я",
    ["Ґ"]="ґ", ["Є"]="є", ["І"]="і", ["Ї"]="ї",
}

EN_TO_RU_KEYBOARD_MAP = {
    ["`"]="ё", ["~"]="Ё",
    ["q"]="й", ["w"]="ц", ["e"]="у", ["r"]="к", ["t"]="е", ["y"]="н", ["u"]="г", ["i"]="ш", ["o"]="щ", ["p"]="з", ["["]="х", ["]"]="ъ",
    ["a"]="ф", ["s"]="ы", ["d"]="в", ["f"]="а", ["g"]="п", ["h"]="р", ["j"]="о", ["k"]="л", ["l"]="д", [";"]="ж", ["'"]="э",
    ["z"]="я", ["x"]="ч", ["c"]="с", ["v"]="м", ["b"]="и", ["n"]="т", ["m"]="ь", [","]="б", ["."]="ю", ["/"]=".",
    ["Q"]="Й", ["W"]="Ц", ["E"]="У", ["R"]="К", ["T"]="Е", ["Y"]="Н", ["U"]="Г", ["I"]="Ш", ["O"]="Щ", ["P"]="З", ["{"]="Х", ["}"]="Ъ",
    ["A"]="Ф", ["S"]="Ы", ["D"]="В", ["F"]="А", ["G"]="П", ["H"]="Р", ["J"]="О", ["K"]="Л", ["L"]="Д", [":"]="Ж", ['"']="Э",
    ["Z"]="Я", ["X"]="Ч", ["C"]="С", ["V"]="М", ["B"]="И", ["N"]="Т", ["M"]="Ь", ["<"]="Б", [">"]="Ю", ["?"]=",",
}

RU_TO_EN_KEYBOARD_MAP = {}
for en, ru in pairs(EN_TO_RU_KEYBOARD_MAP) do
    if RU_TO_EN_KEYBOARD_MAP[ru] == nil then
        RU_TO_EN_KEYBOARD_MAP[ru] = en
    end
end

function SearchLower(text)
    text = tostring(text or "")
    if strlower then
        text = strlower(text)
    else
        text = string.lower(text)
    end
    text = text:gsub("Ё", "е"):gsub("ё", "е")
    for upper, lower in pairs(CYR_LOWER_MAP) do
        text = text:gsub(upper, lower)
    end
    return text
end

function NormalizeSearchText(text)
    text = tostring(text or "")
    text = text:gsub("|Hitem:(%d+).-|h%[(.-)%]|h", "%2")
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+$", "")
    text = text:gsub('^["\']+', "")
    text = text:gsub('["\']+$', "")
    text = text:gsub("^\194\171", ""):gsub("^\194\187", "")
    text = text:gsub("\194\171$", ""):gsub("\194\187$", "")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    text = text:gsub("%s+", " ")
    return text
end

function ConvertKeyboardLayoutText(text, map)
    text = tostring(text or "")
    if text == "" or type(map) ~= "table" then
        return text
    end

    local out = {}
    local index = 1
    local len = string.len(text)

    while index <= len do
        local byte = string.byte(text, index) or 0
        local charLen = 1

        if byte >= 240 then
            charLen = 4
        elseif byte >= 224 then
            charLen = 3
        elseif byte >= 192 then
            charLen = 2
        end

        local char = string.sub(text, index, index + charLen - 1)
        table.insert(out, map[char] or char)
        index = index + charLen
    end

    return table.concat(out)
end

function AddUniqueSearchVariant(out, seen, value)
    value = NormalizeSearchText(value)
    if value == "" then
        return
    end

    local key = SearchLower(value)
    if not seen[key] then
        seen[key] = true
        table.insert(out, value)
    end
end

function BuildKeyboardLayoutSearchVariants(text)
    local value = NormalizeSearchText(text)
    local out = {}
    local seen = {}

    AddUniqueSearchVariant(out, seen, value)
    AddUniqueSearchVariant(out, seen, ConvertKeyboardLayoutText(value, EN_TO_RU_KEYBOARD_MAP))
    AddUniqueSearchVariant(out, seen, ConvertKeyboardLayoutText(value, RU_TO_EN_KEYBOARD_MAP))

    if #out == 0 then
        table.insert(out, "")
    end

    return out
end

function NormalizeSearchComparable(text)
    text = SearchLower(NormalizeSearchText(text))
    text = text:gsub("ё", "е")
    text = text:gsub("[%[%]%(%){}<>\"'.,:;!%?]+", " ")
    text = text:gsub("«", " "):gsub("»", " ")
    text = text:gsub("%-", " "):gsub("–", " "):gsub("—", " "):gsub("_", " ")
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+$", "")
    text = text:gsub("%s+", " ")
    return text
end

function SplitSearchWords(text)
    local words = {}
    text = NormalizeSearchComparable(text)
    for word in string.gmatch(text, "%S+") do
        if word and word ~= "" then
            table.insert(words, word)
        end
    end
    return words
end

SearchResultNameMatches = function(name, query)
    local variants = BuildKeyboardLayoutSearchVariants(query)
    if #variants == 0 or NormalizeSearchComparable(query) == "" then
        return true
    end

    local normalizedName = NormalizeSearchComparable(name)
    if normalizedName == "" then
        return false
    end

    local opts = S.GetSearchOptions and S:GetSearchOptions() or {}
    for _, variant in ipairs(variants) do
        local normalizedQuery = NormalizeSearchComparable(variant)
        if normalizedQuery ~= "" then
            if opts.exactMatch then
                if normalizedName == normalizedQuery then
                    return true
                end
            else
                local words = SplitSearchWords(normalizedQuery)
                local matched = #words > 0

                for _, word in ipairs(words) do
                    if not string.find(normalizedName, word, 1, true) then
                        matched = false
                        break
                    end
                end

                if matched then
                    return true
                end
            end
        end
    end

    return false
end

function ExtractItemIDFromSearchText(text)
    text = tostring(text or "")
    local itemID = text:match("item:(%d+)") or text:match("Hitem:(%d+)") or text:match("^%s*(%d+)%s*$")
    itemID = tonumber(itemID)
    if itemID and itemID > 0 then
        return itemID
    end
    return nil
end

function BuildBrowseFilters(searchText)
    local F = Enum and Enum.AuctionHouseFilter
    if not F then
        return {}
    end

    local opts = S.GetSearchOptions and S:GetSearchOptions() or {}
    local filters = {}

    local function Add(value)
        if value ~= nil then
            table.insert(filters, value)
        end
    end

    if opts.exactMatch and searchText and searchText ~= "" then
        Add(F.ExactMatch)
    end

    if opts.quality and opts.quality ~= "any" then
        local filterName = QUALITY_TO_FILTER[opts.quality]
        if filterName and F[filterName] ~= nil then
            Add(F[filterName])
        end
    else
        Add(F.PoorQuality)
        Add(F.CommonQuality)
        Add(F.UncommonQuality)
        Add(F.RareQuality)
        Add(F.EpicQuality)
        Add(F.LegendaryQuality)
        Add(F.ArtifactQuality)
    end

    if #filters == 0 and F.None ~= nil then
        Add(F.None)
    end

    return filters
end

function BuildBrowseSorts()
    local sorts = {}
    local SortOrder = Enum and Enum.AuctionHouseSortOrder
    if not SortOrder then
        return sorts
    end
    local opts = S.GetSearchOptions and S:GetSearchOptions() or {}
    local mode = opts.sortMode or "price_asc"
    if mode == "price_desc" then
        table.insert(sorts, { sortOrder = SortOrder.Price, reverseSort = true })
        table.insert(sorts, { sortOrder = SortOrder.Name, reverseSort = false })
    elseif mode == "name" then
        table.insert(sorts, { sortOrder = SortOrder.Name, reverseSort = false })
        table.insert(sorts, { sortOrder = SortOrder.Price, reverseSort = false })
    elseif mode == "quantity" and SortOrder.Quantity then
        table.insert(sorts, { sortOrder = SortOrder.Quantity, reverseSort = true })
        table.insert(sorts, { sortOrder = SortOrder.Price, reverseSort = false })
    else
        table.insert(sorts, { sortOrder = SortOrder.Price, reverseSort = false })
        table.insert(sorts, { sortOrder = SortOrder.Name, reverseSort = false })
    end
    return sorts
end

function BuildBrowseItemClassFilters()
    local opts = S.GetSearchOptions and S:GetSearchOptions() or {}
    local filters = {}
    local classID = tonumber(opts.itemClassID)
    if not classID then
        return filters
    end
    local entry = {
        classID = classID,
    }
    local subClassID = tonumber(opts.itemSubClassID)
    if subClassID then
        entry.subClassID = subClassID
    end
    local inventoryType = tonumber(opts.inventoryType)
    if inventoryType then
        entry.inventoryType = inventoryType
    end
    table.insert(filters, entry)
    return filters
end

function BuildBrowseQuery(searchText)
    local opts = S.GetSearchOptions and S:GetSearchOptions() or {}
    local query = {
        searchString = searchText or "",
        sorts = BuildBrowseSorts(),
        minLevel = ParsePlainNumber(opts.minRequiredLevel) or 0,
        maxLevel = ParsePlainNumber(opts.maxRequiredLevel) or 0,
        filters = BuildBrowseFilters(searchText or ""),
    }
    local itemClassFilters = BuildBrowseItemClassFilters()
    if #itemClassFilters > 0 then
        query.itemClassFilters = itemClassFilters
    end
    return query
end

function BuildBrowseSearchVariants(searchText)
    return BuildKeyboardLayoutSearchVariants(searchText)
end

function SearchUsesClientSideHeavyFilters()
    local opts = S.GetSearchOptions and S:GetSearchOptions() or {}
    if opts.expansionID and opts.expansionID ~= "any" then return true end
    if opts.materialQuality and opts.materialQuality ~= "any" then return true end
    if ParseMoneyInput(opts.minPrice) then return true end
    if ParseMoneyInput(opts.maxPrice) then return true end
    if ParsePlainNumber(opts.minQuantity) then return true end
    if ParsePlainNumber(opts.minItemLevel) then return true end
    if ParsePlainNumber(opts.maxItemLevel) then return true end
    return false
end

function GetSearchResultLimit()
    return SearchUsesClientSideHeavyFilters() and SEARCH_DEEP_RESULT_LIMIT or SEARCH_RESULT_LIMIT
end

function GetBrowseMoreRequestLimit()
    return SearchUsesClientSideHeavyFilters() and BROWSE_DEEP_MORE_REQUEST_LIMIT or BROWSE_MORE_REQUEST_LIMIT
end

ReadBrowseResultName = function(itemKey, itemID)
    if C_AuctionHouse and C_AuctionHouse.GetItemKeyInfo and itemKey then
        local ok, info = pcall(C_AuctionHouse.GetItemKeyInfo, itemKey)
        if ok and type(info) == "table" and info.itemName and info.itemName ~= "" then
            return info.itemName
        end
    end
    local name = itemID and GetItemInfo(itemID) or nil
    if name and name ~= "" then
        return name
    end
    if itemID then
        RequestItemData(itemID)
    end
    return nil
end

function BuildSearchSeenKey(itemKey, itemID, professionQuality)
    local parts = { "itemID=" .. tostring(itemID or "") }

    if type(itemKey) == "table" then
        local itemLevel = tonumber(itemKey.itemLevel or itemKey.iLevel)
        local itemSuffix = tonumber(itemKey.itemSuffix or itemKey.suffixID or itemKey.suffix)
        local battlePetSpeciesID = tonumber(itemKey.battlePetSpeciesID or itemKey.petSpeciesID)
        local battlePetLevel = tonumber(itemKey.battlePetLevel or itemKey.petLevel)
        local battlePetBreedQuality = tonumber(itemKey.battlePetBreedQuality or itemKey.petBreedQuality)

        if itemLevel then table.insert(parts, "ilvl=" .. tostring(itemLevel)) end
        if itemSuffix then table.insert(parts, "suffix=" .. tostring(itemSuffix)) end
        if battlePetSpeciesID then table.insert(parts, "pet=" .. tostring(battlePetSpeciesID)) end
        if battlePetLevel then table.insert(parts, "petLevel=" .. tostring(battlePetLevel)) end
        if battlePetBreedQuality then table.insert(parts, "petQuality=" .. tostring(battlePetBreedQuality)) end
    end

    return table.concat(parts, ";")
end

function ReadAuctionItemCommodityStatus(itemKey, itemID, result)
    if result and type(result.isCommodity) == "boolean" then
        return result.isCommodity
    end

    if C_AuctionHouse and C_AuctionHouse.GetItemKeyInfo and itemKey then
        local ok, info = pcall(C_AuctionHouse.GetItemKeyInfo, itemKey)
        if ok and type(info) == "table" and type(info.isCommodity) == "boolean" then
            return info.isCommodity
        end
    end

    if itemID and C_AuctionHouse and C_AuctionHouse.GetItemCommodityStatus then
        local ok, status = pcall(C_AuctionHouse.GetItemCommodityStatus, itemID)
        if ok then
            local enum = Enum and Enum.ItemCommodityStatus
            if enum then
                if enum.Commodity ~= nil and status == enum.Commodity then
                    return true
                end
                if enum.Item ~= nil and status == enum.Item then
                    return false
                end
            end

            if type(status) == "number" then
                if status == 2 then
                    return true
                end
                if status == 1 then
                    return false
                end
            end

            if type(status) == "boolean" then
                return status
            end
        end
    end
    return nil
end

function IsLikelyCommodityByStaticInfo(info)
    local stackCount = tonumber(info and info.stackCount) or 0
    if stackCount > 1 then
        return true
    end

    local classID = tonumber(info and info.classID)
    if classID == 0 or classID == 3 or classID == 5 or classID == 7 or classID == 8 or classID == 16 then
        return true
    end

    return false
end

function AddSearchResultRow(result)
    local itemKey = result and result.itemKey
    local itemID = itemKey and itemKey.itemID
    if not itemID then
        return false
    end

    S.searchResults = S.searchResults or {}
    S.searchResults.rows = S.searchResults.rows or {}
    S.searchResults.seen = S.searchResults.seen or {}

    local name = ReadBrowseResultName(itemKey, itemID)
    local query = S.searchResults and (S.searchResults.originalQuery or S.searchResults.query) or ""

    if not name or name == "" then
        RequestItemData(itemID)
    elseif not SearchResultNameMatches(name, query) then
        return false
    end

    local staticInfo = ReadSearchItemStaticInfo(itemID)
    local isCommodity = ReadAuctionItemCommodityStatus(itemKey, itemID, result)
    if isCommodity == nil then
        isCommodity = IsLikelyCommodityByStaticInfo(staticInfo)
    end
    local seenKey = BuildSearchSeenKey(itemKey, itemID, staticInfo.professionQuality)

    if S.searchResults.seen[seenKey] then
        local row = S.searchResults.seen[seenKey]
        if type(row) == "table" then
            row.itemKey = itemKey
            if name and name ~= "" then
                row.label = name
                row.loadingName = false
            end
            local oldPrice = tonumber(row.minPrice)
            local newPrice = tonumber(result.minPrice)
            if newPrice and newPrice > 0 and (not oldPrice or newPrice < oldPrice) then
                row.minPrice = newPrice
            end
            local oldQty = tonumber(row.totalQuantity) or 0
            local newQty = tonumber(result.totalQuantity) or 0
            row.totalQuantity = math.max(oldQty, newQty)
            row.status = T("PG_SHOP_SEARCH_RESULT", "Search result")
            if isCommodity ~= nil then
                row.isCommodity = isCommodity
            end
            row.quality = row.quality or staticInfo.quality
            row.itemLevel = row.itemLevel or tonumber(itemKey.itemLevel or itemKey.iLevel) or staticInfo.itemLevel
            row.requiredLevel = row.requiredLevel or staticInfo.requiredLevel
            row.itemClassID = row.itemClassID or staticInfo.classID
            row.itemSubClassID = row.itemSubClassID or staticInfo.subClassID
            row.expansionID = row.expansionID or staticInfo.expansionID
            row.materialQuality = row.materialQuality or staticInfo.materialQuality
            row.professionQuality = row.professionQuality or staticInfo.professionQuality
            row.craftedQuality = row.craftedQuality or staticInfo.craftedQuality
        end
        return false
    end

    if #S.searchResults.rows >= GetSearchResultLimit() then
        return false
    end

    RequestItemData(itemID)

    local row = {
        isSearchResult = true,
        itemID = itemID,
        itemKey = itemKey,
        seenKey = seenKey,
        label = name or ("item:" .. tostring(itemID)),
        loadingName = name == nil,
        quantity = 1,
        remainingQuantity = 1,
        chosenItemID = itemID,
        minPrice = result.minPrice,
        totalQuantity = result.totalQuantity,
        isCommodity = isCommodity,
        quality = staticInfo.quality,
        itemLevel = tonumber(itemKey.itemLevel or itemKey.iLevel) or staticInfo.itemLevel,
        requiredLevel = staticInfo.requiredLevel,
        itemClassID = staticInfo.classID,
        itemSubClassID = staticInfo.subClassID,
        expansionID = staticInfo.expansionID,
        professionQuality = staticInfo.professionQuality,
        craftedQuality = staticInfo.craftedQuality,
        materialQuality = staticInfo.materialQuality,
        status = T("PG_SHOP_SEARCH_RESULT", "Search result"),
    }

    table.insert(S.searchResults.rows, row)
    S.searchResults.seen[seenKey] = row
    return true
end

IMPORT_RESOLVE_STEP_DELAY = 0.18
IMPORT_RESOLVE_MORE_REQUEST_LIMIT = 12
IMPORT_RESOLVE_TIMEOUT = 5.0

function CanResolveImportByBrowse()
    return S.isAuctionHouseOpen
        and C_AuctionHouse
        and C_AuctionHouse.SendBrowseQuery
        and C_AuctionHouse.GetBrowseResults
end

function BuildImportBrowseFilters()
    local F = Enum and Enum.AuctionHouseFilter
    local filters = {}
    if not F then
        return filters
    end

    local function Add(value)
        if value ~= nil then
            table.insert(filters, value)
        end
    end

    Add(F.PoorQuality)
    Add(F.CommonQuality)
    Add(F.UncommonQuality)
    Add(F.RareQuality)
    Add(F.EpicQuality)
    Add(F.LegendaryQuality)
    Add(F.ArtifactQuality)

    if #filters == 0 and F.None ~= nil then
        Add(F.None)
    end

    return filters
end

function BuildImportBrowseSorts()
    local sorts = {}
    local SortOrder = Enum and Enum.AuctionHouseSortOrder
    if not SortOrder then
        return sorts
    end

    table.insert(sorts, { sortOrder = SortOrder.Price, reverseSort = false })
    table.insert(sorts, { sortOrder = SortOrder.Name, reverseSort = false })
    return sorts
end

function BuildImportBrowseQuery(searchText)
    return {
        searchString = searchText or "",
        sorts = BuildImportBrowseSorts(),
        minLevel = 0,
        maxLevel = 0,
        filters = BuildImportBrowseFilters(),
    }
end

function SplitImportExpansionMaterials(materials)
    local immediate = {}
    local expand = {}

    for _, material in ipairs(materials or {}) do
        if type(material) == "table" then
            local searchName = NormalizeOptionText(material.importSearchName or material.label or material.unresolvedName or material.importName)
            local hasOptions = type(material.options) == "table" and #material.options > 0
            local shouldBrowse = searchName ~= ""
                and not hasOptions
                and material.importResolveAttempted ~= true
                and (material.importExpandGrades == true or material.itemID == nil)
            if shouldBrowse then
                material.importSearchName = searchName
                table.insert(expand, material)
            else
                table.insert(immediate, material)
            end
        else
            table.insert(immediate, material)
        end
    end

    return immediate, expand
end

function FindSavedListByID(listID)
    if not listID then
        return nil
    end

    local db = GetDB()
    for _, list in ipairs(db.savedLists or {}) do
        if list.id == listID then
            return list
        end
    end

    return nil
end

function IsCurrentImportSessionSerial(sessionSerial)
    if not sessionSerial then
        return true
    end
    return S.session and S.session.active and S.session.importSerial == sessionSerial
end

function InvalidateImportResolveState()
    if S.importResolveState then
        S.importResolveState.active = false
        S.importResolveState.pending = false
        S.importResolveState.current = nil
        S.importResolveState.queue = nil
        S.importResolveState.afterDone = nil
    end
    S.importResolveState = nil
end

function BuildImportMergeKey(row)
    if type(row) ~= "table" then
        return nil
    end

    local tier = NormalizeTierValue(row.chosenTier or row.tier or row.professionQuality or row.craftedQuality or row.materialQuality) or 0

    if row.itemID then
        return "i:" .. tostring(row.itemID) .. ":" .. tostring(tier)
    end

    if row.options and #row.options > 0 then
        local parts = {}
        for _, opt in ipairs(row.options or {}) do
            if opt.itemID then
                local optTier = NormalizeTierValue(opt.tier or opt.qualityTier or opt.professionQuality or opt.craftedQuality or opt.materialQuality) or 0
                table.insert(parts, tostring(opt.itemID) .. ":" .. tostring(optTier))
            end
        end
        table.sort(parts)
        if #parts > 0 then
            return "o:" .. table.concat(parts, ";") .. ":" .. tostring(tier)
        end
    end

    local name = NormalizeOptionText(row.importSearchName or row.unresolvedName or row.importName or row.label)
    if name ~= "" then
        return "n:" .. SearchLower(name) .. ":" .. tostring(tier)
    end

    return nil
end

function MergeRowIntoSessionRows(row)
    if not row then
        return false
    end

    S.session = S.session or {}
    S.session.rows = S.session.rows or {}

    local key = BuildImportMergeKey(row)
    if key then
        for _, existing in ipairs(S.session.rows or {}) do
            if BuildImportMergeKey(existing) == key then
                local addQty = tonumber(row.quantity) or tonumber(row.remainingQuantity) or 0
                if addQty > 0 then
                    existing.quantity = math.max(0, (tonumber(existing.quantity) or 0) + addQty)
                    existing.remainingQuantity = math.max(0, (tonumber(existing.remainingQuantity) or 0) + addQty)
                end

                if IsPlaceholderItemLabel(existing.label, existing.itemID) and row.label then
                    existing.label = row.label
                end

                CopyTierFieldsFrom(row, existing)
                existing.importSearchName = existing.importSearchName or row.importSearchName
                existing.importExpandGrades = existing.importExpandGrades or row.importExpandGrades == true
                existing.importResolveAttempted = existing.importResolveAttempted or row.importResolveAttempted == true
                existing.auctionatorSearchString = existing.auctionatorSearchString or row.auctionatorSearchString
                existing.auctionatorTier = existing.auctionatorTier or row.auctionatorTier
                if row.auctionatorIsExact ~= nil then
                    existing.auctionatorIsExact = row.auctionatorIsExact
                end
                existing.hidden = false
                return true
            end
        end
    end

    table.insert(S.session.rows, row)
    return true
end

function NormalizeAndMergeMaterials(materials)
    local normalized = NormalizeMaterials(materials or {})
    local out = {}
    local byKey = {}

    for _, row in ipairs(normalized or {}) do
        local key = BuildImportMergeKey(row)
        local existing = key and byKey[key] or nil

        if existing then
            local addQty = tonumber(row.quantity) or tonumber(row.remainingQuantity) or 0
            if addQty > 0 then
                existing.quantity = math.max(0, (tonumber(existing.quantity) or 0) + addQty)
                existing.remainingQuantity = math.max(0, (tonumber(existing.remainingQuantity) or 0) + addQty)
            end

            if IsPlaceholderItemLabel(existing.label, existing.itemID) and row.label then
                existing.label = row.label
            end

            CopyTierFieldsFrom(row, existing)
            existing.importSearchName = existing.importSearchName or row.importSearchName
            existing.importExpandGrades = existing.importExpandGrades or row.importExpandGrades == true
            existing.importResolveAttempted = existing.importResolveAttempted or row.importResolveAttempted == true
            existing.auctionatorSearchString = existing.auctionatorSearchString or row.auctionatorSearchString
            existing.auctionatorTier = existing.auctionatorTier or row.auctionatorTier
            if row.auctionatorIsExact ~= nil then
                existing.auctionatorIsExact = row.auctionatorIsExact
            end
            existing.hidden = false
        else
            table.insert(out, row)
            if key then
                byKey[key] = row
            end
        end
    end

    for index, row in ipairs(out) do
        row.index = index
    end

    return out
end

function BuildImportResolveMaterialKey(material)
    if type(material) ~= "table" then
        return nil
    end

    local tier = NormalizeTierValue(material.chosenTier or material.tier or material.qualityTier or material.professionQuality or material.craftedQuality or material.materialQuality or material.auctionatorTier) or 0
    local name = NormalizeOptionText(material.importSearchName or material.unresolvedName or material.importName or material.label)

    if name ~= "" then
        return "n:" .. SearchLower(name) .. ":" .. tostring(tier)
    end

    if material.itemID then
        return "i:" .. tostring(material.itemID) .. ":" .. tostring(tier)
    end

    local auctionatorSearchString = NormalizeOptionText(material.auctionatorSearchString)
    if auctionatorSearchString ~= "" then
        return "a:" .. auctionatorSearchString
    end

    return nil
end

function CombineImportResolveMaterials(materials)
    local out = {}
    local byKey = {}

    for _, material in ipairs(materials or {}) do
        if type(material) == "table" then
            local key = BuildImportResolveMaterialKey(material)
            local existing = key and byKey[key] or nil

            if existing then
                local addQty = tonumber(material.quantity) or 0
                if addQty > 0 then
                    existing.quantity = math.max(1, (tonumber(existing.quantity) or 1) + addQty)
                end
            else
                table.insert(out, material)
                if key then
                    byKey[key] = material
                end
            end
        end
    end

    return out
end

function AppendImportedMaterialsToTarget(targetListID, materials, sessionSerial)
    local normalized = NormalizeAndMergeMaterials(materials or {})
    if #normalized == 0 then
        return 0
    end

    local savedList = FindSavedListByID(targetListID)
    if savedList then
        savedList.rows = savedList.rows or {}
        for _, row in ipairs(normalized) do
            local exported = ExportMaterialRows({ row })[1]
            if exported then
                table.insert(savedList.rows, exported)
            end
        end
        savedList.updatedAt = time and time() or 0
    end

    local sessionMatches = (not sessionSerial) or IsCurrentImportSessionSerial(sessionSerial)
    if sessionMatches and ((not targetListID) or S.activeSavedListID == targetListID) then
        if not S.session or not S.session.active then
            S.session = {
                active = true,
                rows = {},
                skillLineID = nil,
                itemData = {},
                listName = savedList and savedList.name or T("PG_SHOP_IMPORTED_LIST", "Imported shopping list"),
                listKind = savedList and "saved" or "manual",
            }
        end

        S.session.rows = S.session.rows or {}
        for _, row in ipairs(normalized) do
            MergeRowIntoSessionRows(row)
        end
        ReindexSessionRows()

        if S.scanAllState and S.scanAllState.active and S.scanAllState.queue then
            local seenInQueue = {}
            for _, id in ipairs(S.scanAllState.queue) do
                seenInQueue[id] = true
            end
            for _, row in ipairs(normalized) do
                if row.itemID and not seenInQueue[row.itemID] then
                    seenInQueue[row.itemID] = true
                    table.insert(S.scanAllState.queue, row.itemID)
                end
                for _, opt in ipairs(row.options or {}) do
                    if opt.itemID and not seenInQueue[opt.itemID] then
                        seenInQueue[opt.itemID] = true
                        table.insert(S.scanAllState.queue, opt.itemID)
                    end
                end
            end

            for _, sessionRow in ipairs(S.session.rows or {}) do
                if not sessionRow.status or sessionRow.status == "" then
                    sessionRow.status = T("PG_SHOP_STATUS_QUEUED", "Queued")
                end
            end
        end
    end

    RefreshShoppingWindow()
    return #normalized
end

function ImportBrowseNameMatches(name, query)
    name = NormalizeSearchComparable(name)
    if name == "" then
        return false
    end

    for _, variant in ipairs(BuildKeyboardLayoutSearchVariants(query)) do
        local normalizedQuery = NormalizeSearchComparable(variant)
        if normalizedQuery ~= "" and name == normalizedQuery then
            return true
        end
    end

    return false
end

function BuildImportMaterialFromBrowseResult(result, sourceMaterial)
    local itemKey = result and result.itemKey
    local itemID = itemKey and itemKey.itemID
    if not itemID then
        return nil
    end

    local query = NormalizeOptionText(sourceMaterial and (sourceMaterial.importSearchName or sourceMaterial.label or sourceMaterial.unresolvedName or sourceMaterial.importName) or "")
    local name = ReadBrowseResultName(itemKey, itemID)

    if name and name ~= "" then
        if not ImportBrowseNameMatches(name, query) then
            return nil
        end
    elseif query ~= "" then
        RequestItemData(itemID)
        return nil, true
    end

    local staticInfo = ReadSearchItemStaticInfo(itemID)
    local tier = NormalizeTierValue(staticInfo.professionQuality or staticInfo.craftedQuality or staticInfo.materialQuality)
    local wantedTier = NormalizeTierValue(sourceMaterial and (sourceMaterial.chosenTier or sourceMaterial.tier or sourceMaterial.qualityTier or sourceMaterial.professionQuality or sourceMaterial.craftedQuality or sourceMaterial.materialQuality))

    if wantedTier then
        if not tier then
            RequestItemData(itemID)
            return nil, true
        end
        if tier ~= wantedTier then
            return nil
        end
    end

    local quantity = math.max(1, tonumber(sourceMaterial and sourceMaterial.quantity) or 1)

    local material = {
        itemID = itemID,
        quantity = quantity,
        label = name or staticInfo.name or query or GetItemName(itemID),
        quality = staticInfo.quality,
        itemClassID = staticInfo.classID,
        itemSubClassID = staticInfo.subClassID,
        expansionID = staticInfo.expansionID,
        itemKey = {
            itemID = tonumber(itemKey.itemID),
            itemLevel = tonumber(itemKey.itemLevel or itemKey.iLevel) or 0,
            itemSuffix = tonumber(itemKey.itemSuffix or itemKey.suffixID or itemKey.suffix) or 0,
            battlePetSpeciesID = tonumber(itemKey.battlePetSpeciesID or itemKey.petSpeciesID) or 0,
            battlePetLevel = tonumber(itemKey.battlePetLevel or itemKey.petLevel) or 0,
            battlePetBreedQuality = tonumber(itemKey.battlePetBreedQuality or itemKey.petBreedQuality) or 0,
        },
        itemLevel = tonumber(itemKey.itemLevel or itemKey.iLevel) or staticInfo.itemLevel,
        itemSuffix = tonumber(itemKey.itemSuffix or itemKey.suffixID or itemKey.suffix),
    }

    if tier then
        material.tier = tier
        material.chosenTier = tier
        material.materialQuality = tier
        material.professionQuality = tier
    else
        material.materialQuality = NormalizeTierValue(staticInfo.materialQuality)
        material.professionQuality = NormalizeTierValue(staticInfo.professionQuality)
        material.craftedQuality = NormalizeTierValue(staticInfo.craftedQuality)
    end

    return material
end

function HasMoreImportResolveVariants(state)
    return state
        and state.importSearchVariants
        and state.importVariantIndex
        and state.importVariantIndex < #state.importSearchVariants
end

function SendImportResolveVariant(state, entry, variantIndex, sessionSerial)
    if not state or not entry then
        return false
    end

    local variants = state.importSearchVariants or {}
    local searchText = NormalizeOptionText(variants[variantIndex] or "")
    if searchText == "" then
        return false
    end

    if C_AuctionHouse and C_AuctionHouse.IsThrottledMessageSystemReady then
        local okT, ready = pcall(C_AuctionHouse.IsThrottledMessageSystemReady)
        if okT and not ready then
            state.pending = true
            local ss = state.sessionSerial
            C_Timer.After(0.1, function()
                local live = S.importResolveState
                if live and live.active and live == state and live.current == entry
                   and live.sessionSerial == ss and IsCurrentImportSessionSerial(sessionSerial) then
                    SendImportResolveVariant(live, entry, variantIndex, sessionSerial)
                end
            end)
            return true
        end
    end

    state.importVariantIndex = variantIndex
    state.currentSearchText = searchText
    state.currentAdded = 0
    state.moreRequests = 0
    state.lastBrowseCount = 0
    state.waitingForImportItemInfo = false
    state.itemInfoRetryCount = 0
    state.staleBrowseRetryCount = 0
    state.emptyBrowseRetryCount = 0
    state.pending = true
    state.serial = (state.serial or 0) + 1

    local serial = state.serial
    local stateSessionSerial = state.sessionSerial

    local ok, err = pcall(C_AuctionHouse.SendBrowseQuery, BuildImportBrowseQuery(searchText, entry.material))
    if not ok then
        state.pending = false
        return false, err
    end

    C_Timer.After(IMPORT_RESOLVE_TIMEOUT, function()
        local live = S.importResolveState
        if not live or not live.active or live.serial ~= serial or live.sessionSerial ~= stateSessionSerial or not live.pending then
            return
        end
        if not IsCurrentImportSessionSerial(sessionSerial) then
            InvalidateImportResolveState()
            return
        end

        live.pending = false

        if (live.currentAdded or 0) <= 0 and HasMoreImportResolveVariants(live) then
            SendImportResolveVariant(live, live.current, (live.importVariantIndex or 1) + 1, sessionSerial)
            return
        end

        if live.current and live.current.material then
            live.current.material.importResolveAttempted = true
        end

        S:RunNextImportResolveSearch()
    end)

    return true
end

function S:RunNextImportResolveSearch()
    local state = self.importResolveState
    if not state or not state.active then
        return false
    end

    if state.sessionSerial and not IsCurrentImportSessionSerial(state.sessionSerial) then
        InvalidateImportResolveState()
        return false
    end

    state.pointer = (state.pointer or 0) + 1
    local entry = state.queue and state.queue[state.pointer]
    if not entry then
        local afterDone = state.afterDone
        local sessionSerial = state.sessionSerial

        state.active = false
        state.current = nil
        state.afterDone = nil
        state.pending = false

        RefreshShoppingWindow()

        if type(afterDone) == "function" and IsCurrentImportSessionSerial(sessionSerial) then
            afterDone()
        end

        return false
    end

    if entry.sessionSerial and not IsCurrentImportSessionSerial(entry.sessionSerial) then
        InvalidateImportResolveState()
        return false
    end

    local material = entry.material
    local searchText = NormalizeOptionText(material and (material.importSearchName or material.label or material.unresolvedName or material.importName) or "")
    local sessionSerial = entry.sessionSerial or state.sessionSerial

    if DebugAuctionatorMirrorEnabled and DebugAuctionatorMirrorEnabled() then
        print(string.format(
            "|cff33ccffHironCraftProfit resolve start|r pointer=%s name='%s' qty=%s exact=%s tier=%s",
            tostring(state.pointer),
            tostring(searchText),
            tostring(material and material.quantity),
            tostring(material and material.auctionatorIsExact),
            tostring(material and (material.auctionatorTier or material.tier))
        ))
    end

    if searchText == "" or not CanResolveImportByBrowse() then
        AppendImportedMaterialsToTarget(entry.targetListID, { material }, sessionSerial)
        C_Timer.After(IMPORT_RESOLVE_STEP_DELAY, function()
            local live = S.importResolveState
            if live and live.active and live.sessionSerial == state.sessionSerial and IsCurrentImportSessionSerial(sessionSerial) then
                S:RunNextImportResolveSearch()
            end
        end)
        return false
    end

    state.current = entry
    state.importSearchVariants = BuildKeyboardLayoutSearchVariants(searchText)
    state.importVariantIndex = 0
    state.currentSearchText = nil

    if self.searchResults then
        self.searchResults.active = false
        self.searchResults.pending = false
        self.searchResults.query = ""
        self.searchResults.rows = {}
    end

    local ok, err = SendImportResolveVariant(state, entry, 1, sessionSerial)
    if not ok then
        AppendImportedMaterialsToTarget(entry.targetListID, { material }, sessionSerial)
        if err then
            print(T("PG_SHOP_ERR_SEARCH", "HironCraft: auction search error:"), err)
        end
        local stateSessionSerial = state.sessionSerial
        C_Timer.After(IMPORT_RESOLVE_STEP_DELAY, function()
            local live = S.importResolveState
            if live and live.active and live.sessionSerial == stateSessionSerial and IsCurrentImportSessionSerial(sessionSerial) then
                S:RunNextImportResolveSearch()
            end
        end)
        return false
    end

    return true
end

function S:QueueImportGradeExpansion(materials, targetListID, afterDone, sessionSerial)
    materials = CombineImportResolveMaterials(materials or {})

    if not materials or #materials == 0 or not CanResolveImportByBrowse() then
        if type(afterDone) == "function" and IsCurrentImportSessionSerial(sessionSerial) then
            afterDone()
        end
        return false
    end

    if sessionSerial and not IsCurrentImportSessionSerial(sessionSerial) then
        return false
    end

    if sessionSerial
       and self.importResolveState
       and self.importResolveState.active
       and self.importResolveState.sessionSerial
       and self.importResolveState.sessionSerial ~= sessionSerial
    then
        InvalidateImportResolveState()
    end

    self.importResolveState = self.importResolveState or {
        active = false,
        queue = {},
        pointer = 0,
        seen = {},
    }

    local state = self.importResolveState
    state.queue = state.queue or {}
    state.seen = state.seen or {}
    state.resolveSeen = state.resolveSeen or {}
    state.sessionSerial = sessionSerial or state.sessionSerial

    if type(afterDone) == "function" then
        state.afterDone = afterDone
    end

    for _, material in ipairs(materials or {}) do
        local resolveKey = BuildImportResolveMaterialKey(material)
        local queueKey = tostring(sessionSerial or "") .. ":" .. tostring(targetListID or "session") .. ":" .. tostring(resolveKey or material)

        if not state.resolveSeen[queueKey] then
            state.resolveSeen[queueKey] = true
            table.insert(state.queue, {
                material = material,
                targetListID = targetListID,
                sessionSerial = sessionSerial,
            })
        end
    end

    if not state.active then
        state.active = true
        state.pointer = 0
        state.current = nil
        state.currentAdded = 0
        state.pending = false
        self:RunNextImportResolveSearch()
    end

    return true
end

function S:ApplyImportBrowseResults()
    local state = self.importResolveState
    if not state or not state.active or not state.current then
        return false
    end

    local entry = state.current
    local sessionSerial = entry.sessionSerial or state.sessionSerial

    if sessionSerial and not IsCurrentImportSessionSerial(sessionSerial) then
        InvalidateImportResolveState()
        return false
    end

    local results = nil
    if C_AuctionHouse and C_AuctionHouse.GetBrowseResults then
        local ok, value = pcall(C_AuctionHouse.GetBrowseResults)
        if ok then
            results = value
        end
    end

    results = results or {}
    local addedNow = 0

    if DebugAuctionatorMirrorEnabled and DebugAuctionatorMirrorEnabled() then
        local currentMaterial = entry and entry.material
        local currentName = NormalizeOptionText(currentMaterial and (currentMaterial.importSearchName or currentMaterial.label or currentMaterial.unresolvedName or currentMaterial.importName) or "")

        print(string.format(
            "|cff33ccffHironCraftProfit resolve results|r name='%s' count=%d",
            tostring(currentName),
            tonumber(#results) or 0
        ))
    end

local expectedName = NormalizeOptionText(entry and entry.material and (
    entry.material.importSearchName
    or entry.material.label
    or entry.material.unresolvedName
    or entry.material.importName
) or "")

if expectedName ~= "" and #results == 0 then
    state.emptyBrowseRetryCount = (tonumber(state.emptyBrowseRetryCount) or 0) + 1

    if DebugAuctionatorMirrorEnabled and DebugAuctionatorMirrorEnabled() then
        print(string.format(
            "|cff33ccffHironCraftProfit empty browse wait|r expected='%s' retry=%d",
            tostring(expectedName),
            tonumber(state.emptyBrowseRetryCount) or 0
        ))
    end

    local emptyRetryLimit = HasMoreImportResolveVariants(state) and 3 or 20
    if state.emptyBrowseRetryCount <= emptyRetryLimit then
        state.pending = true

        local stateSessionSerial = state.sessionSerial
        local serial = state.serial

        C_Timer.After(0.15, function()
            local live = S.importResolveState
            if live
               and live.active
               and live.current == entry
               and live.serial == serial
               and live.sessionSerial == stateSessionSerial
               and IsCurrentImportSessionSerial(sessionSerial)
            then
                S:ApplyImportBrowseResults()
            end
        end)

        return true
    end

    if HasMoreImportResolveVariants(state) then
        local sent = SendImportResolveVariant(state, entry, (state.importVariantIndex or 1) + 1, sessionSerial)
        if sent then
            return true
        end
    end
else
    state.emptyBrowseRetryCount = 0
end

if expectedName ~= "" and #results > 0 then
        local hasNamedResult = false
        local hasMatchingResult = false

        for _, result in ipairs(results) do
            local itemKey = result and result.itemKey
            local itemID = itemKey and itemKey.itemID
            local name = itemID and ReadBrowseResultName(itemKey, itemID) or nil

            if name and name ~= "" then
                hasNamedResult = true

                if ImportBrowseNameMatches(name, expectedName) then
                    hasMatchingResult = true
                    break
                end
            end
        end

        if hasNamedResult and not hasMatchingResult then
            state.staleBrowseRetryCount = (tonumber(state.staleBrowseRetryCount) or 0) + 1

            if DebugAuctionatorMirrorEnabled and DebugAuctionatorMirrorEnabled() then
                print(string.format(
                    "|cff33ccffHironCraftProfit stale browse ignored|r expected='%s' retry=%d",
                    tostring(expectedName),
                    tonumber(state.staleBrowseRetryCount) or 0
                ))
            end

            local staleRetryLimit = HasMoreImportResolveVariants(state) and 3 or 20
            if state.staleBrowseRetryCount <= staleRetryLimit then
                state.pending = true

                local stateSessionSerial = state.sessionSerial
                local serial = state.serial

                C_Timer.After(0.10, function()
                    local live = S.importResolveState
                    if live
                       and live.active
                       and live.current == entry
                       and live.serial == serial
                       and live.sessionSerial == stateSessionSerial
                       and IsCurrentImportSessionSerial(sessionSerial)
                    then
                        S:ApplyImportBrowseResults()
                    end
                end)

                return true
            end

            if HasMoreImportResolveVariants(state) then
                local sent = SendImportResolveVariant(state, entry, (state.importVariantIndex or 1) + 1, sessionSerial)
                if sent then
                    return true
                end
            end
        else
            state.staleBrowseRetryCount = 0
        end
    end

for resultIndex, result in ipairs(results) do
    if DebugAuctionatorMirrorEnabled and DebugAuctionatorMirrorEnabled() then
        local itemKey = result and result.itemKey
        local itemID = itemKey and itemKey.itemID
        local name = itemID and ReadBrowseResultName(itemKey, itemID) or nil

        print(string.format(
            "|cff33ccffHironCraftProfit browse result %d|r itemID=%s name='%s' minPrice=%s totalQty=%s",
            resultIndex,
            tostring(itemID),
            tostring(name),
            tostring(result and result.minPrice),
            tostring(result and result.totalQuantity)
        ))
    end

    local material, waitingForInfo = BuildImportMaterialFromBrowseResult(result, entry.material)

    if DebugAuctionatorMirrorEnabled and DebugAuctionatorMirrorEnabled() then
        print(string.format(
            "|cff33ccffHironCraftProfit browse material|r itemID=%s name='%s' waiting=%s",
            tostring(material and material.itemID),
            tostring(material and (material.importSearchName or material.label)),
            tostring(waitingForInfo)
        ))
    end

    if waitingForInfo then
        state.waitingForImportItemInfo = true
    end

    if material and material.itemID then
            local seenKey = tostring(entry.targetListID or "session") .. ":" .. tostring(sessionSerial or "") .. ":" .. tostring(material.itemID) .. ":" .. tostring(material.itemLevel or "") .. ":" .. tostring(material.itemSuffix or "")
            if not state.seen[seenKey] then
                state.seen[seenKey] = true
                addedNow = addedNow + AppendImportedMaterialsToTarget(entry.targetListID, { material }, sessionSerial)
            end
        end
    end

    state.currentAdded = (state.currentAdded or 0) + addedNow

    local canRequestMore = false
    if C_AuctionHouse and C_AuctionHouse.HasFullBrowseResults and C_AuctionHouse.RequestMoreBrowseResults then
        local okFull, isFull = pcall(C_AuctionHouse.HasFullBrowseResults)
        canRequestMore = okFull and not isFull
    end

    local resultCount = #results
    local moreRequests = tonumber(state.moreRequests) or 0
    local lastBrowseCount = tonumber(state.lastBrowseCount) or 0

    if canRequestMore and moreRequests < IMPORT_RESOLVE_MORE_REQUEST_LIMIT and resultCount >= lastBrowseCount then
        state.moreRequests = moreRequests + 1
        state.lastBrowseCount = resultCount
        local okMore = pcall(C_AuctionHouse.RequestMoreBrowseResults)
        if okMore then
            state.pending = true
            RefreshShoppingWindow()
            return true
        end
    end

    if (state.currentAdded or 0) <= 0 and state.waitingForImportItemInfo and (state.itemInfoRetryCount or 0) < 20 then
        state.itemInfoRetryCount = (state.itemInfoRetryCount or 0) + 1
        state.pending = true
        local stateSessionSerial = state.sessionSerial
        C_Timer.After(0.15, function()
            local live = S.importResolveState
            if live
               and live.active
               and live.current == entry
               and live.sessionSerial == stateSessionSerial
               and IsCurrentImportSessionSerial(sessionSerial)
            then
                S:ApplyImportBrowseResults()
            end
        end)
        return true
    end

    if (state.currentAdded or 0) <= 0 and HasMoreImportResolveVariants(state) then
        local sent = SendImportResolveVariant(state, entry, (state.importVariantIndex or 1) + 1, sessionSerial)
        if sent then
            return true
        end
    end

    state.pending = false

    if (state.currentAdded or 0) <= 0 and entry.material then
        entry.material.importResolveAttempted = true
        AppendImportedMaterialsToTarget(entry.targetListID, { entry.material }, sessionSerial)
    end

    local stateSessionSerial = state.sessionSerial
    C_Timer.After(IMPORT_RESOLVE_STEP_DELAY, function()
        local live = S.importResolveState
        if live and live.active and live.sessionSerial == stateSessionSerial and IsCurrentImportSessionSerial(sessionSerial) then
            S:RunNextImportResolveSearch()
        end
    end)

    return true
end

function S:SendNextBrowseSearch()
    if not self.searchResults or not self.searchResults.active then
        return false
    end

    local variants = self.searchResults.variants or {}
    self.searchResults.variantIndex = (self.searchResults.variantIndex or 0) + 1
    local query = variants[self.searchResults.variantIndex]
    if not query then
        self.searchResults.pending = false
        RefreshShoppingWindow()
        return false
    end

    self.searchResults.pending = true
    self.searchResults.currentQuery = query
    self.searchResults.moreRequests = 0
    self.searchResults.lastBrowseCount = 0

    local ok, err = pcall(C_AuctionHouse.SendBrowseQuery, BuildBrowseQuery(query))
    if not ok then
        if self.searchResults.variantIndex >= #variants then
            self.searchResults.pending = false
            print(T("PG_SHOP_ERR_SEARCH", "HironCraft: auction search error:"), err)
        else
            C_Timer.After(BROWSE_STEP_DELAY, function()
                if S.searchResults and S.searchResults.active then
                    S:SendNextBrowseSearch()
                end
            end)
        end
        RefreshShoppingWindow()
        return false, err
    end

    RefreshShoppingWindow()
    return true
end

function S:ApplyBrowseSearchResults()
    if not self.searchResults or not self.searchResults.active then
        return
    end

    local results = nil
    if C_AuctionHouse and C_AuctionHouse.GetBrowseResults then
        local ok, value = pcall(C_AuctionHouse.GetBrowseResults)
        if ok then
            results = value
        end
    end

    results = results or {}
    if S.searchDebug then
        local q = self.searchResults and (self.searchResults.currentQuery or self.searchResults.query)
        print(string.format("|cffb19cd9PHShop dbg|r query=|cffffd24a%s|r rawResults=%d", tostring(q), #results))
        for i, result in ipairs(results) do
            local itemKey = result and result.itemKey
            local itemID = itemKey and itemKey.itemID
            local name = itemID and ReadBrowseResultName(itemKey, itemID)
            print(string.format("   [%d] id=%s name=%s match=%s", i, tostring(itemID), tostring(name),
                tostring(itemID and name and name ~= "" and SearchResultNameMatches(name, q))))
            if i >= 8 then print("   ...") break end
        end
    end
    for _, result in ipairs(results) do
        AddSearchResultRow(result)
    end

    RefreshSearchResultNames()

    local opts = self.GetSearchOptions and self:GetSearchOptions() or {}
    local sortMode = opts.sortMode or "price_asc"

    table.sort(self.searchResults.rows or {}, function(a, b)
        if sortMode == "price_desc" then
            return (tonumber(a.minPrice) or 0) > (tonumber(b.minPrice) or 0)
        elseif sortMode == "name" then
            local an = tostring(a.label or "")
            local bn = tostring(b.label or "")
            if an == bn then
                return (tonumber(a.minPrice) or math.huge) < (tonumber(b.minPrice) or math.huge)
            end
            return an < bn
        elseif sortMode == "quantity" then
            return (tonumber(a.totalQuantity) or 0) > (tonumber(b.totalQuantity) or 0)
        end
        return (tonumber(a.minPrice) or math.huge) < (tonumber(b.minPrice) or math.huge)
    end)

    local canRequestMore = false
    if C_AuctionHouse and C_AuctionHouse.HasFullBrowseResults and C_AuctionHouse.RequestMoreBrowseResults then
        local okFull, isFull = pcall(C_AuctionHouse.HasFullBrowseResults)
        canRequestMore = okFull and not isFull
    end

    local resultCount = #results
    local totalRows = #(self.searchResults.rows or {})
    local moreRequests = tonumber(self.searchResults.moreRequests) or 0
    local lastBrowseCount = tonumber(self.searchResults.lastBrowseCount) or 0

    if canRequestMore and totalRows < GetSearchResultLimit() and moreRequests < GetBrowseMoreRequestLimit() and resultCount >= lastBrowseCount then
        self.searchResults.moreRequests = moreRequests + 1
        self.searchResults.lastBrowseCount = resultCount
        local okMore = pcall(C_AuctionHouse.RequestMoreBrowseResults)
        if okMore then
            self.searchResults.pending = true
            RefreshShoppingWindow()
            return
        end
    end

    local hasRows = #(self.searchResults.rows or {}) > 0
    if S.searchDebug then
        print(string.format("|cffb19cd9PHShop dbg|r rowsAfter=%d variant=%s/%s canMore=%s",
            #(self.searchResults.rows or {}), tostring(self.searchResults.variantIndex),
            tostring(self.searchResults.variants and #self.searchResults.variants), tostring(canRequestMore)))
    end
    if not hasRows and self.searchResults.variantIndex and self.searchResults.variants and self.searchResults.variantIndex < #self.searchResults.variants then
        C_Timer.After(BROWSE_STEP_DELAY, function()
            if S.searchResults and S.searchResults.active then
                S:SendNextBrowseSearch()
            end
        end)
    else
        self.searchResults.pending = false
    end

    RefreshShoppingWindow()
end

SHOPPING_SEARCH_HISTORY_LIMIT = 30

function S:GetSearchHistory()
    local db = GetDB()
    db.searchHistory = db.searchHistory or {}
    return db.searchHistory
end

function S:AddSearchHistory(query)
    query = NormalizeSearchText(query)
    if query == "" then return end

    local db = GetDB()
    db.searchHistory = db.searchHistory or {}
    local history = db.searchHistory

    local lowered = SearchLower(query)
    for index, entry in ipairs(history) do
        if entry.text and SearchLower(entry.text) == lowered then
            entry.count = (tonumber(entry.count) or 0) + 1
            entry.text = query
            table.remove(history, index)
            table.insert(history, 1, entry)
            return
        end
    end

    table.insert(history, 1, { text = query, count = 1 })

    while #history > SHOPPING_SEARCH_HISTORY_LIMIT do
        table.remove(history)
    end
end

function S:RemoveSearchHistory(query)
    query = NormalizeSearchText(query)
    if query == "" then return end

    local db = GetDB()
    local history = db.searchHistory or {}
    local lowered = SearchLower(query)
    for index, entry in ipairs(history) do
        if entry.text and SearchLower(entry.text) == lowered then
            table.remove(history, index)
            return
        end
    end
end

function S:ClearSearchHistory()
    local db = GetDB()
    db.searchHistory = {}
end

function S:StartAuctionSearch(searchText)
    searchText = NormalizeSearchText(searchText)

    if searchText == "" and not self:CanRunEmptyAuctionSearch() then
        self:ClearAuctionSearch()
        return false, "empty_query_without_server_filters"
    end

    local itemID = ExtractItemIDFromSearchText(searchText)
    if itemID then
        self:ClearAuctionSearch()
        return self:AddManualItem(itemID, 1)
    end

    if not C_AuctionHouse or not C_AuctionHouse.SendBrowseQuery or not C_AuctionHouse.GetBrowseResults then
        return false, "no_browse_api"
    end

    if not self.isAuctionHouseOpen then
        return false, "auction_house_closed"
    end

    if searchText ~= "" then
        self:AddSearchHistory(searchText)
    end

    self.searchResults = self.searchResults or {}
    self.searchResults.active = true
    self.searchResults.pending = true
    self.searchResults.lastError = nil
    self.searchResults.query = searchText
    self.searchResults.originalQuery = searchText
    self.searchResults.currentQuery = nil
    self.searchResults.rows = {}
    self.searchResults.seen = {}
    self.searchResults.variants = BuildBrowseSearchVariants(searchText)
    self.searchResults.variantIndex = 0
    self.searchResults.serial = (self.searchResults.serial or 0) + 1
    self.selectedSearchResult = nil

    return self:SendNextBrowseSearch()
end

function EnsureItemInfoLoaded(rows, onReady)
    if not C_Item or not C_Item.RequestLoadItemDataByID then
        onReady()
        return
    end

    local pending = {}
    for _, row in ipairs(rows or {}) do
        if row.itemID and not GetItemInfo(row.itemID) then
            pending[row.itemID] = true
            C_Item.RequestLoadItemDataByID(row.itemID)
        end
        for _, opt in ipairs(row.options or {}) do
            if opt.itemID and not GetItemInfo(opt.itemID) then
                pending[opt.itemID] = true
                C_Item.RequestLoadItemDataByID(opt.itemID)
            end
        end
    end

    if not next(pending) then
        onReady()
        return
    end

    local tries = 0
    local function Poll()
        tries = tries + 1
        for itemID in pairs(pending) do
            if GetItemInfo(itemID) then
                pending[itemID] = nil
            end
        end
        if not next(pending) or tries >= 20 then
            onReady()
            return
        end
        C_Timer.After(0.1, Poll)
    end
    Poll()
end

function BuildSorts()
    return {
        {
            sortOrder = Enum.AuctionHouseSortOrder.Price,
            reverseSort = false,
        }
    }
end

REFRESH_WINDOW_THROTTLE = 0.05
_refreshLastAt = 0
_refreshPending = false

function RefreshWindow()
    if not S.frame or not S.frame:IsShown() then
        return
    end

    local now = GetTime and GetTime() or 0
    if (now - _refreshLastAt) < REFRESH_WINDOW_THROTTLE then
        if _refreshPending then return end
        _refreshPending = true
        C_Timer.After(REFRESH_WINDOW_THROTTLE, function()
            _refreshPending = false
            if S.frame and S.frame:IsShown() then
                _refreshLastAt = GetTime and GetTime() or 0
                if S.RefreshWindow then S:RefreshWindow() end
                if S.OnShoppingDataChanged then S:OnShoppingDataChanged() end
            end
        end)
        return
    end

    _refreshLastAt = now
    if S.RefreshWindow then
        S:RefreshWindow()
    end
    if S.OnShoppingDataChanged then
        S:OnShoppingDataChanged()
    end
end

function GetItemData(itemID)
    S.session = S.session or {}
    S.session.itemData = S.session.itemData or {}
    if not S.session.itemData[itemID] then
        S.session.itemData[itemID] = {
            itemID = itemID,
            itemKey = nil,
            searched = false,
            pending = false,
            pendingSince = nil,
            isCommodity = nil,
            minPrice = nil,
            totalQuantity = nil,
            bestAuctionID = nil,
            bestAuctionQuantity = nil,
            bestBuyoutAmount = nil,
            requestSerial = 0,
            retryCount = 0,
        }
    end
    return S.session.itemData[itemID]
end

function ClearStalePendingSearches(force)
    local now = GetTime and GetTime() or 0
    local changed = false
    for _, data in pairs(S.session and S.session.itemData or {}) do
        if data.pending then
            local stale = force
            if not stale and data.pendingSince then
                stale = (now - data.pendingSince) >= SEARCH_PENDING_TIMEOUT
            end
            if stale then
                data.pending = false
                data.pendingSince = nil
                if not data.searched then
                    data.searched = true
                end
                if data.totalQuantity == nil then
                    data.totalQuantity = 0
                end
                changed = true
            end
        end
    end
    return changed
end

FindRowByItemID = function(itemID)
    for _, row in ipairs(S.session and S.session.rows or {}) do
        if not row.hidden then
            if row.itemID == itemID then
                return row
            end
            for _, opt in ipairs(row.options or {}) do
                if opt.itemID == itemID then
                    return row
                end
            end
        end
    end
    return nil
end

function FindRowByAuctionID(auctionID)
    for _, pending in pairs(S.pendingItemPurchases or {}) do
        if pending.auctionID == auctionID and pending.rowIndex then
            return S.session.rows and S.session.rows[pending.rowIndex], pending
        end
    end
    return nil, nil
end

function FindSearchRowByAuctionID(auctionID)
    local pending = S.pendingSearchItemPurchases and S.pendingSearchItemPurchases[auctionID]
    if pending and pending.searchRow then
        return pending.searchRow, pending
    end
    return nil, nil
end

function RefreshSearchRowAfterPurchase(row)
    if not row or not row.itemID or not S.isAuctionHouseOpen then
        return
    end

    C_Timer.After(0.25, function()
        if not row or not row.itemID or not S.isAuctionHouseOpen then
            return
        end

        if row.isCommodity == true then
            row.status = T("PG_SHOP_SEARCH_RESULT", "Search result")
            RefreshShoppingWindow()
            return
        end

        if S.RequestSearchItemAuction then
            S:RequestSearchItemAuction(row)
        else
            RefreshShoppingWindow()
        end
    end)
end

function MarkSearchRowPurchased(row, statusText)
    if not row then return end

    local boughtQty = tonumber(row.pendingQuantity) or 1
    local oldTotalQuantity = tonumber(row.totalQuantity)

    row.searchPending = false
    row.directPurchaseSearchPending = false
    row.purchaseStage = nil
    row.pendingQuantity = nil
    row.pendingUnitPrice = nil
    row.pendingTotalPrice = nil

    if oldTotalQuantity then
        row.totalQuantity = math.max(0, oldTotalQuantity - boughtQty)
    end

    if row.isCommodity ~= true then
        row.bestAuctionID = nil
        row.bestAuctionQuantity = nil
        row.bestBuyoutAmount = nil
    end

    row.quantity = math.max(1, tonumber(row.quantity) or boughtQty or 1)
    row.remainingQuantity = row.quantity
    row.status = statusText or T("PG_SHOP_STATUS_BOUGHT", "Bought")

    RefreshSearchRowAfterPurchase(row)
end

function ResolveRow(row)
    if not row then return end

    if GetRemainingQuantity(row) <= 0 then
        row.status = T("PG_SHOP_STATUS_BOUGHT", "Bought")
        row.searchPending = false
        return
    end

    if not row.itemID and not (row.options and #row.options > 0) then
        row.searchPending = false
        row.chosenItemID = nil
        row.minPrice = nil
        row.totalQuantity = nil
        row.isCommodity = nil
        row.bestAuctionID = nil
        row.bestAuctionQuantity = nil
        row.bestBuyoutAmount = nil
        row.status = T("PG_SHOP_STATUS_NOT_SCANNED", "Not scanned")
        return
    end

    if row.options and #row.options > 0 then
        local bestData, bestOpt
        local anySearched = false
        local anyPending = false

        for _, opt in ipairs(row.options) do
            ResolveOptionTier(opt)
            local data = GetItemData(opt.itemID)
            if data.pending then anyPending = true end
            if data.searched then anySearched = true end
            if data.minPrice and data.minPrice > 0 then
                if (not bestData) or data.minPrice < bestData.minPrice then
                    bestData = data
                    bestOpt = opt
                end
            end
        end

        row.searchPending = anyPending

        if anyPending then
            row.chosenItemID = nil
            row.chosenTier = nil
            row.minPrice = nil
            row.totalQuantity = nil
            row.isCommodity = nil
            row.bestAuctionID = nil
            row.bestAuctionQuantity = nil
            row.bestBuyoutAmount = nil
            row.lastChosenName = nil
            row.status = T("PG_SHOP_STATUS_SCANNING", "Scanning...")
            return
        end

        if bestData and bestOpt then
            local bestTier = ResolveOptionTier(bestOpt)
            local staticInfo = ReadSearchItemStaticInfo(bestOpt.itemID)
            row.chosenItemID = bestOpt.itemID
            row.chosenTier = bestTier
            row.professionQuality = bestTier
            row.craftedQuality = nil
            row.materialQuality = bestTier
            row.itemClassID = staticInfo.classID
            row.itemSubClassID = staticInfo.subClassID
            row.expansionID = staticInfo.expansionID
            row.minPrice = bestData.minPrice
            row.totalQuantity = bestData.totalQuantity
            row.isCommodity = bestData.isCommodity
            row.bestAuctionID = bestData.bestAuctionID
            row.bestAuctionQuantity = bestData.bestAuctionQuantity
            row.bestBuyoutAmount = bestData.bestBuyoutAmount
            row.lastChosenName = GetOptionLabel(bestOpt)
            row.status = T("PG_SHOP_STATUS_SELECTED", "Selected")
        else
            row.chosenItemID = nil
            row.chosenTier = nil
            row.minPrice = nil
            row.totalQuantity = nil
            row.isCommodity = nil
            row.bestAuctionID = nil
            row.bestAuctionQuantity = nil
            row.bestBuyoutAmount = nil
            row.lastChosenName = nil
            row.professionQuality = nil
            row.craftedQuality = nil
            row.materialQuality = nil
            row.itemClassID = nil
            row.itemSubClassID = nil
            row.expansionID = nil
            if anySearched then
                row.status = T("PG_SHOP_STATUS_NO_PRICE", "No price")
            else
                row.status = T("PG_SHOP_STATUS_NOT_SCANNED", "Not scanned")
            end
        end
    else
        local data = GetItemData(row.itemID)
        row.searchPending = data.pending
        row.chosenItemID = row.itemID
        row.chosenTier = nil
        row.minPrice = data.minPrice
        row.totalQuantity = data.totalQuantity
        row.isCommodity = data.isCommodity
        row.bestAuctionID = data.bestAuctionID
        row.bestAuctionQuantity = data.bestAuctionQuantity
        row.bestBuyoutAmount = data.bestBuyoutAmount
        row.lastChosenName = T("PG_DASH", "—")
        if data.pending then
            row.status = T("PG_SHOP_STATUS_SCANNING", "Scanning...")
        elseif data.searched then
            row.status = data.totalQuantity and data.totalQuantity > 0 and T("PG_SHOP_STATUS_FOUND", "Found") or T("PG_SHOP_STATUS_NO_ITEM", "No item")
        else
            row.status = T("PG_SHOP_STATUS_NOT_SCANNED", "Not scanned")
        end
    end
end

function ResolveAllRows()
    for _, row in ipairs(S.session and S.session.rows or {}) do
        ResolveRow(row)
    end
    RefreshWindow()
end

function QueueRefreshChosenSearch(row)
    if not row or not row.index or not row.chosenItemID then
        return
    end
    C_Timer.After(0.35, function()
        if not S.session.active or not S.isAuctionHouseOpen then
            return
        end
        local liveRow = S.session.rows and S.session.rows[row.index]
        if not liveRow or GetRemainingQuantity(liveRow) <= 0 or not liveRow.chosenItemID then
            return
        end
        S:SearchItemID(liveRow.chosenItemID, true)
    end)
end

function ApplyCommodityResults(itemID)
    local data = GetItemData(itemID)
    data.pending = false
    data.pendingSince = nil
    data.searched = true
    data.retryCount = 0
    data.isCommodity = true
    data.bestAuctionID = nil
    data.bestAuctionQuantity = nil
    data.bestBuyoutAmount = nil

    local count = C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0
    if count <= 0 then
        data.minPrice = nil
        data.totalQuantity = 0
        ResolveAllRows()
        return
    end

    local minPrice = nil
    local totalQuantity = 0
    for index = 1, count do
        local ok, result = pcall(C_AuctionHouse.GetCommoditySearchResultInfo, itemID, index)
        if ok and type(result) == "table" then
            if result.unitPrice and result.unitPrice > 0 then
                if not minPrice or result.unitPrice < minPrice then
                    minPrice = result.unitPrice
                end
            end
            if result.quantity then
                totalQuantity = totalQuantity + result.quantity
            end
        end
    end
    data.minPrice = minPrice
    data.totalQuantity = totalQuantity
    if minPrice and minPrice > 0 and PT.Prices and PT.Prices.UpdateItem then
        PT.Prices:UpdateItem(itemID, minPrice, minPrice, totalQuantity)
    end
    ResolveAllRows()
end

function ApplyItemResults(itemKey)
    local itemID = itemKey and itemKey.itemID
    if not itemID then
        return
    end

    local data = GetItemData(itemID)
    data.pending = false
    data.pendingSince = nil
    data.searched = true
    data.retryCount = 0
    data.isCommodity = false

    local count = C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
    if count <= 0 then
        data.minPrice = nil
        data.totalQuantity = 0
        data.bestAuctionID = nil
        data.bestAuctionQuantity = nil
        data.bestBuyoutAmount = nil
        ResolveAllRows()
        return
    end

    local minPrice = nil
    local totalQuantity = 0
    local bestAuctionID = nil
    local bestAuctionQuantity = nil
    local bestBuyoutAmount = nil

    for index = 1, count do
        local ok, result = pcall(C_AuctionHouse.GetItemSearchResultInfo, itemKey, index)
        if ok and type(result) == "table" then
            local listingPrice = nil
            if result.buyoutAmount and result.buyoutAmount > 0 then
                listingPrice = result.buyoutAmount
            elseif result.bidAmount and result.bidAmount > 0 then
                listingPrice = result.bidAmount
            end
            if listingPrice and (not minPrice or listingPrice < minPrice) then
                minPrice = listingPrice
                bestAuctionID = result.auctionID
                bestAuctionQuantity = result.quantity or 1
                bestBuyoutAmount = result.buyoutAmount or result.bidAmount
            end
            totalQuantity = totalQuantity + (result.quantity or 1)
        end
    end

    data.minPrice = minPrice
    data.totalQuantity = totalQuantity
    data.bestAuctionID = bestAuctionID
    data.bestAuctionQuantity = bestAuctionQuantity
    data.bestBuyoutAmount = bestBuyoutAmount
    if minPrice and minPrice > 0 and PT.Prices and PT.Prices.UpdateItemFromKey then
        PT.Prices:UpdateItemFromKey(itemKey, minPrice, minPrice, totalQuantity)
    end
    ResolveAllRows()
end

function ApplySearchItemResults(itemKey)
    local itemID = itemKey and itemKey.itemID
    if not itemID then
        return false
    end

    local row = FindSearchResultRowByItemID(itemID)
    if not row then
        return false
    end

    row.itemKey = itemKey
    row.searchPending = false
    row.directPurchaseSearchPending = false
    row.isCommodity = false

    local count = C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
    if count <= 0 then
        row.minPrice = nil
        row.totalQuantity = 0
        row.bestAuctionID = nil
        row.bestAuctionQuantity = nil
        row.bestBuyoutAmount = nil
        row.purchaseStage = nil
        row.status = T("PG_SHOP_STATUS_NO_ITEM", "No item")
        RefreshShoppingWindow()
        return true
    end

    local minPrice = nil
    local totalQuantity = 0
    local bestAuctionID = nil
    local bestAuctionQuantity = nil
    local bestBuyoutAmount = nil

    for index = 1, count do
        local ok, result = pcall(C_AuctionHouse.GetItemSearchResultInfo, itemKey, index)
        if ok and type(result) == "table" then
            local listingPrice = nil
            if result.buyoutAmount and result.buyoutAmount > 0 then
                listingPrice = result.buyoutAmount
            elseif result.bidAmount and result.bidAmount > 0 then
                listingPrice = result.bidAmount
            end

            if listingPrice and (not minPrice or listingPrice < minPrice) then
                minPrice = listingPrice
                bestAuctionID = result.auctionID
                bestAuctionQuantity = result.quantity or 1
                bestBuyoutAmount = result.buyoutAmount or result.bidAmount
            end

            totalQuantity = totalQuantity + (result.quantity or 1)
        end
    end

    row.minPrice = minPrice
    row.totalQuantity = totalQuantity
    row.bestAuctionID = bestAuctionID
    row.bestAuctionQuantity = bestAuctionQuantity
    row.bestBuyoutAmount = bestBuyoutAmount
    row.purchaseStage = nil
    row.status = bestAuctionID and T("PG_SHOP_STATUS_FOUND", "Found") or T("PG_SHOP_STATUS_NO_BUYOUT", "No buyout")

    RefreshShoppingWindow()
    return true
end

S._Private = S._Private or {}
S._Private.T = T
S._Private.FormatMoneyText = FormatMoneyText
S._Private.RequestItemData = RequestItemData
S._Private.GetItemName = GetItemName
S._Private.GetItemIcon = GetItemIcon
S._Private.RequestSessionItemData = RequestSessionItemData
S._Private.GetRowTooltipItemID = GetRowTooltipItemID
S._Private.ShowRowTooltip = ShowRowTooltip
S._Private.GetRemainingQuantity = GetRemainingQuantity
S._Private.GetVisibleRows = GetVisibleRows
S._Private.HasShoppingSession = HasShoppingSession
S._Private.ShouldShowAuctionTab = ShouldShowAuctionTab
S._Private.UpdateAuctionTabVisibility = UpdateAuctionTabVisibility
S._Private.GetOptionLabel = GetOptionLabel
S._Private.GetRowBaseLabel = GetRowBaseLabel
S._Private.IsAHAvailable = IsAHAvailable

function S:CreateWindow()
    return nil
end

function S:EnsureAuctionTab()
    return nil
end

function S:ShowWindow()
    return nil
end

function S:HideWindow()
    if self.frame then
        self.frame:Hide()
    end
    UpdateAuctionTabVisibility()
end

function S:IsAvailable()
    return IsAHAvailable() and GetLibAHTab() ~= nil
end

function S:ApplyAlwaysShowTabSetting()
    if AuctionHouseFrame and GetLibAHTab() then
        if ShouldShowAuctionTab() and self.EnsureAuctionTab then
            self:EnsureAuctionTab()
        end
        UpdateAuctionTabVisibility()
    end
end

function S:CanBuy(skillLineID)
    return skillLineID ~= nil and IsAHAvailable() and GetLibAHTab() ~= nil
end

function S:StopScanAll()
    self.scanAllState.active = false
    self.scanAllState.queue = nil
    self.scanAllState.pointer = 0
    self.scanAllState.token = (self.scanAllState.token or 0) + 1
    if ClearStalePendingSearches(false) then
        ResolveAllRows()
        return
    end
    RefreshWindow()
end

function S:StopBuyAll()
    self.buyAllState.active = false
    self.buyAllState.order = nil
    self.buyAllState.pointer = 1
    self.buyAllState.currentRowIndex = nil
    RefreshWindow()
end

function S:EndShoppingSession()
    self:StopScanAll()
    self:StopBuyAll()
    self.session = {
        active = false,
        rows = {},
        skillLineID = nil,
        itemData = {},
    }
    self.pendingCommodityRow = nil
    self.pendingSearchCommodityRow = nil
    self.pendingItemPurchases = {}
    self.pendingSearchItemPurchases = {}
    self.importResolveState = nil
    if self.searchResults then
        self.searchResults.active = false
        self.searchResults.pending = false
        self.searchResults.query = ""
        self.searchResults.rows = {}
    end
    if self.frame then
        self.frame:Hide()
    end
    UpdateAuctionTabVisibility()
end

function S:GetRows()
    return self.session and self.session.rows or {}
end

function GetSavedListDisplayName(list, index)
    local name = NormalizeOptionText(list and list.name)
    if name ~= "" then
        return name
    end
    return string.format(T("PG_SHOP_SAVED_LIST_DEFAULT", "Shopping list %d"), tonumber(index) or 1)
end

function S:GetSavedLists()
    local db = GetDB()
    local out = {}
    for index, list in ipairs(db.savedLists or {}) do
        local name = GetSavedListDisplayName(list, index)
        if NormalizeOptionText(list.name) == "" then
            list.name = name
        end
        table.insert(out, {
            id = list.id,
            name = name,
            count = #(list.rows or {}),
            skillLineID = list.skillLineID,
            createdAt = list.createdAt,
            updatedAt = list.updatedAt,
            temporary = list.temporary == true,
        })
    end
    table.sort(out, function(a, b)
        if a.temporary ~= b.temporary then
            return a.temporary == true
        end
        return tostring(a.name or "") < tostring(b.name or "")
    end)
    return out
end

function S:CleanupTemporaryLists()
    local db = GetDB()
    if not db.savedLists then return end
    local removed = 0
    for i = #db.savedLists, 1, -1 do
        if db.savedLists[i].temporary then
            table.remove(db.savedLists, i)
            removed = removed + 1
        end
    end
    if removed > 0 and self.activeSavedListID then
        local stillExists = false
        for _, l in ipairs(db.savedLists) do
            if l.id == self.activeSavedListID then stillExists = true break end
        end
        if not stillExists then
            self.activeSavedListID = nil
        end
    end
end

function S:GetActiveListID()
    return self.activeSavedListID or "temporary"
end

function S:GetActiveListName()
    if self.activeSavedListID then
        local db = GetDB()
        for index, list in ipairs(db.savedLists or {}) do
            if list.id == self.activeSavedListID then
                local name = GetSavedListDisplayName(list, index)
                if NormalizeOptionText(list.name) == "" then
                    list.name = name
                end
                return name
            end
        end
    end
    return self.session and self.session.listName or T("PG_SHOP_LIST_TEMPORARY", "Temporary list")
end

function S:RenameSavedList(listID, name)
    if not listID then
        return false, "missing_id"
    end

    local listName = NormalizeOptionText(name)
    if listName == "" then
        return false, "empty_name"
    end

    local db = GetDB()
    for _, list in ipairs(db.savedLists or {}) do
        if list.id == listID then
            list.name = listName
            list.updatedAt = time and time() or 0
            if self.activeSavedListID == listID and self.session then
                self.session.listName = listName
                self.session.listKind = "saved"
            end
            RefreshWindow()
            return true
        end
    end

    return false, "not_found"
end

function S:CreateSavedList(name)
    self:StopScanAll()
    self:StopBuyAll()

    local db = GetDB()
    local id = "list_" .. tostring(db.nextListID or 1)
    db.nextListID = (tonumber(db.nextListID) or 1) + 1

    local listName = NormalizeOptionText(name)
    if listName == "" then
        listName = string.format(T("PG_SHOP_SAVED_LIST_DEFAULT", "Shopping list %d"), db.nextListID - 1)
    end

    table.insert(db.savedLists, {
        id = id,
        name = listName,
        rows = {},
        skillLineID = nil,
        createdAt = time and time() or 0,
        updatedAt = time and time() or 0,
    })

    self.activeSavedListID = id
    if self.ResetSearchOptions then self:ResetSearchOptions(true) end
    self._loadingSavedListID = nil
    self._loadingSavedListName = nil
    self.session = {
        active = true,
        rows = {},
        skillLineID = nil,
        itemData = {},
        listName = listName,
        listKind = "saved",
    }
    self.pendingCommodityRow = nil
    self.pendingSearchCommodityRow = nil
    self.pendingItemPurchases = {}
    self.pendingSearchItemPurchases = {}
    if self.searchResults then
        self.searchResults.active = false
        self.searchResults.pending = false
        self.searchResults.query = ""
        self.searchResults.rows = {}
    end
    self:ShowWindow()
    RefreshWindow()
    return true, id
end

function S:PromoteTempListToSaved(listID, newName)
    if not listID then
        return false, "missing_id"
    end
    local db = GetDB()
    for _, list in ipairs(db.savedLists or {}) do
        if list.id == listID then
            local cleanName = NormalizeOptionText(newName)
            if cleanName ~= "" then
                list.name = cleanName
            end
            list.temporary = nil
            list.seedRows = nil
            list.seedMaterials = nil
            list.updatedAt = time and time() or 0
            if self.activeSavedListID == listID and self.session then
                self.session.temporary = nil
                if cleanName ~= "" then
                    self.session.listName = cleanName
                end
            end
            RefreshWindow()
            return true, listID
        end
    end
    return false, "not_found"
end

function S:SaveActiveList(name)
    if not self.session or not self.session.active then
        return false, "no_active_list"
    end

    local rows = ExportMaterialRows(self.session.rows or {})
    if #rows == 0 then
        return false, "empty"
    end

    local db = GetDB()
    local listName = NormalizeOptionText(name)

    if self.activeSavedListID then
        for _, list in ipairs(db.savedLists or {}) do
            if list.id == self.activeSavedListID then
                if listName ~= "" then
                    list.name = listName
                    self.session.listName = listName
                end
                list.rows = rows
                list.skillLineID = self.session.skillLineID
                list.updatedAt = time and time() or 0
                if list.temporary then
                    list.temporary = nil
                    list.seedRows = nil
                    list.seedMaterials = nil
                end
                if self.session then
                    self.session.temporary = nil
                end
                RefreshWindow()
                return true, list.id
            end
        end
    end

    local id = "list_" .. tostring(db.nextListID or 1)
    db.nextListID = (tonumber(db.nextListID) or 1) + 1

    if listName == "" then
        listName = string.format(T("PG_SHOP_SAVED_LIST_DEFAULT", "Shopping list %d"), db.nextListID - 1)
    end

    table.insert(db.savedLists, {
        id = id,
        name = listName,
        rows = rows,
        skillLineID = self.session.skillLineID,
        createdAt = time and time() or 0,
        updatedAt = time and time() or 0,
    })

    self.activeSavedListID = id
    self.session.listName = listName
    self.session.listKind = "saved"
    RefreshWindow()
    return true, id
end

function S:DeleteSavedList(listID)
    if not listID then
        return false, "missing_id"
    end
    local db = GetDB()
    for index, list in ipairs(db.savedLists or {}) do
        if list.id == listID then
            table.remove(db.savedLists, index)
            if self.activeSavedListID == listID then
                self.activeSavedListID = nil
                if self.session then
                    self.session.listName = T("PG_SHOP_LIST_TEMPORARY", "Temporary list")
                    self.session.listKind = "temporary"
                end
            end
            RefreshWindow()
            return true
        end
    end
    return false, "not_found"
end

function S:LoadSavedList(listID)
    if not listID then
        return false, "missing_id"
    end
    local db = GetDB()
    for _, list in ipairs(db.savedLists or {}) do
        if list.id == listID then
            local listName = GetSavedListDisplayName(list, _)
            if NormalizeOptionText(list.name) == "" then
                list.name = listName
            end

            local rowsToLoad = list.rows
            if (not rowsToLoad or #rowsToLoad == 0) then
                if list.seedRows and #list.seedRows > 0 then
                    rowsToLoad = list.seedRows
                elseif list.seedMaterials and #list.seedMaterials > 0 then
                    rowsToLoad = list.seedMaterials
                end
            end

            if not rowsToLoad or #rowsToLoad == 0 then
                self:StopScanAll()
                self:StopBuyAll()
                if self.ResetSearchOptions then self:ResetSearchOptions(true) end
                self.activeSavedListID = listID
                self._loadingSavedListID = nil
                self._loadingSavedListName = nil
                self.session = {
                    active = true,
                    rows = {},
                    skillLineID = list.skillLineID,
                    itemData = {},
                    listName = listName,
                    listKind = "saved",
                    temporary = list.temporary == true,
                }
                self.pendingCommodityRow = nil
                self.pendingItemPurchases = {}
                if self.searchResults then
                    self.searchResults.active = false
                    self.searchResults.pending = false
                    self.searchResults.query = ""
                    self.searchResults.rows = {}
                end
                self:ShowWindow()
                RefreshWindow()
                return true
            end
            self._loadingSavedListID = listID
            self._loadingSavedListName = listName
            local ok, err = self:CreateShoppingSession(rowsToLoad, list.skillLineID, { noAutoScan = true })
            if not ok then
                self._loadingSavedListID = nil
                self._loadingSavedListName = nil
            end
            return ok, err
        end
    end
    return false, "not_found"
end

function S:CreateManualList(name)
    self:StopScanAll()
    self:StopBuyAll()
    self.activeSavedListID = nil
    if self.ResetSearchOptions then self:ResetSearchOptions(true) end
    self._loadingSavedListID = nil
    self._loadingSavedListName = nil
    local listName = NormalizeOptionText(name)
    if listName == "" then
        listName = T("PG_SHOP_MANUAL_LIST_DEFAULT", "Manual list")
    end
    self.session = {
        active = true,
        rows = {},
        skillLineID = nil,
        itemData = {},
        listName = listName,
        listKind = "manual",
    }
    self.pendingCommodityRow = nil
    self.pendingSearchCommodityRow = nil
    self.pendingItemPurchases = {}
    self.pendingSearchItemPurchases = {}
    if self.searchResults then
        self.searchResults.active = false
        self.searchResults.pending = false
        self.searchResults.query = ""
        self.searchResults.rows = {}
    end
    self:ShowWindow()
    RefreshWindow()
    return true
end

function S:AddItemToActiveList(itemID, quantity, label, sourceData)
    itemID = tonumber(itemID)
    quantity = math.floor(tonumber(quantity) or 1)

    if not itemID or itemID <= 0 then
        return false, "bad_item"
    end

    if quantity <= 0 then
        quantity = 1
    end

    return self:AddManualItem(itemID, quantity, label, sourceData)
end

function EncodeExportField(value)
    value = tostring(value or "")
    return (value:gsub("([%%%^,;%c])", function(char)
        return string.format("%%%02X", string.byte(char))
    end))
end
function DecodeExportField(value)
    value = tostring(value or "")
    return (value:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16) or 32)
    end))
end

function SplitExportString(value, sep)
    local out = {}
    value = tostring(value or "")
    sep = sep or "^"

    if sep == "^" then
        for part in string.gmatch(value .. "^", "([^%^]*)%^") do
            table.insert(out, part)
        end
    elseif sep == "," then
        for part in string.gmatch(value .. ",", "([^,]*),") do
            table.insert(out, part)
        end
    elseif sep == ";;" then
        for part in string.gmatch(value .. ";;", "(.-);;") do
            table.insert(out, part)
        end
    end

    return out
end

function BuildExportRowToken(row)
    if not row then
        return nil
    end

    local quantity = math.max(1, tonumber(row.quantity) or tonumber(row.remainingQuantity) or 1)
    local tier = NormalizeTierValue(row.chosenTier or row.tier or row.professionQuality or row.craftedQuality or row.materialQuality) or 0

    if row.options and #row.options > 0 then
        local opts = {}
        for _, opt in ipairs(row.options or {}) do
            if opt.itemID then
                local optTier = NormalizeTierValue(opt.tier or opt.qualityTier or opt.professionQuality or opt.craftedQuality or opt.materialQuality) or 0
                table.insert(opts, tostring(opt.itemID) .. ":" .. tostring(optTier))
            end
        end

        if #opts > 0 then
            return "o," .. tostring(quantity) .. "," .. tostring(tier) .. "," .. table.concat(opts, ";") .. "," .. EncodeExportField(row.label or "")
        end
    end

    local itemID = row.chosenItemID or row.itemID
    if itemID then
        return "i," .. tostring(itemID) .. "," .. tostring(quantity) .. "," .. tostring(tier) .. "," .. EncodeExportField(row.label or "")
    end

    local nameOnly = NormalizeOptionText(row.unresolvedName or row.importName or row.label or "")
    if nameOnly ~= "" then
        return "n," .. tostring(quantity) .. "," .. tostring(tier) .. "," .. EncodeExportField(nameOnly)
    end

    return nil
end

RU_FIRST_UPPER = {
    ["а"] = "А", ["б"] = "Б", ["в"] = "В", ["г"] = "Г", ["д"] = "Д", ["е"] = "Е", ["ё"] = "Ё", ["ж"] = "Ж",
    ["з"] = "З", ["и"] = "И", ["й"] = "Й", ["к"] = "К", ["л"] = "Л", ["м"] = "М", ["н"] = "Н", ["о"] = "О",
    ["п"] = "П", ["р"] = "Р", ["с"] = "С", ["т"] = "Т", ["у"] = "У", ["ф"] = "Ф", ["х"] = "Х", ["ц"] = "Ц",
    ["ч"] = "Ч", ["ш"] = "Ш", ["щ"] = "Щ", ["ъ"] = "Ъ", ["ы"] = "Ы", ["ь"] = "Ь", ["э"] = "Э", ["ю"] = "Ю", ["я"] = "Я",
}

function UpperFirstImportLetter(value)
    value = tostring(value or "")
    for lower, upper in pairs(RU_FIRST_UPPER) do
        if string.sub(value, 1, #lower) == lower then
            return upper .. string.sub(value, #lower + 1)
        end
    end

    local first = string.sub(value, 1, 1)
    local upper = string.upper(first)
    if upper ~= first then
        return upper .. string.sub(value, 2)
    end

    return value
end

function StripImportItemToken(value)
    value = NormalizeOptionText(value)
    if value == "" then
        return "", nil, nil
    end

    local quantity
    local tier
    local chunks = SplitExportString(value, ";;")

    if #chunks > 1 then
        local meta = {}
        for index = 2, #chunks do
            local part = NormalizeOptionText(chunks[index])
            if part ~= "" then
                table.insert(meta, part)
            end
        end

        local last = meta[#meta]
        local prev = meta[#meta - 1]
        local lastNumber = tonumber(last)
        local prevNumber = tonumber(prev)

        if prev == "#" and lastNumber then
            quantity = lastNumber
        elseif prevNumber and lastNumber then
            tier = NormalizeTierValue(prevNumber)
            quantity = lastNumber
        elseif lastNumber then
            tier = NormalizeTierValue(lastNumber)
        end
    else
        local lastNumber = value:match(";%s*(%d+)%s*$")
        if lastNumber then
            quantity = tonumber(lastNumber)
        end
    end

    local quotedName = value:match('^%s*"(.-)"%s*;;') or value:match('^%s*"(.-)"%s*;') or value:match('^%s*"(.-)"%s*$')
    if quotedName then
        return NormalizeOptionText(quotedName), quantity, tier
    end

    local name = value:match("^(.-);;") or value:match("^(.-);") or value
    name = NormalizeOptionText(name)
    name = name:gsub("^%[", "")
    name = name:gsub("%]$", "")
    name = name:gsub('^"', "")
    name = name:gsub('"$', "")

    return NormalizeOptionText(name), quantity, tier
end

function ResolveImportItem(value)
    value = NormalizeOptionText(value)
    if value == "" then
        return nil, nil
    end

    value = value:gsub("^%[", "")
    value = value:gsub("%]$", "")

    local itemID = tonumber(value:match("item:(%d+)"))
        or tonumber(value:match("Hitem:(%d+)"))
        or tonumber(value:match("^[iI]:?(%d+)$"))
        or tonumber(value:match("^(%d+)$"))

    if itemID and itemID > 0 then
        RequestItemData(itemID)
        return itemID, GetItemInfo(itemID) or value
    end

    local variants = {}
    for _, variant in ipairs(BuildKeyboardLayoutSearchVariants(value)) do
        table.insert(variants, variant)
        table.insert(variants, UpperFirstImportLetter(variant))
    end
    local seen = {}

    for _, candidate in ipairs(variants) do
        candidate = NormalizeOptionText(candidate)
        if candidate ~= "" and not seen[candidate] then
            seen[candidate] = true

            local name, link = GetItemInfo(candidate)
            if link then
                itemID = tonumber(tostring(link):match("item:(%d+)"))
            end

            if itemID and itemID > 0 then
                RequestItemData(itemID)
                return itemID, name or candidate
            end
        end
    end

    return nil, value
end

function IsExplicitImportItemIDText(value)
    value = NormalizeOptionText(value)
    if value == "" then
        return false
    end

    return value:match("item:%d+") ~= nil
        or value:match("Hitem:%d+") ~= nil
        or value:match("^[iI]:?%d+$") ~= nil
        or value:match("^%d+$") ~= nil
end

function IsIgnoredImportToken(value)
    value = NormalizeOptionText(value)
    if value == "" then
        return true
    end

    local numeric = tonumber(value)
    if numeric and value:match("^%d+$") and numeric <= 0 then
        return true
    end

    return false
end

function BuildMaterialFromPlainItem(value)
    local cleanValue, quantity, tier = StripImportItemToken(value)

    if IsIgnoredImportToken(cleanValue) then
        return nil
    end

    local itemID, label = ResolveImportItem(cleanValue)

    if cleanValue == "" then
        return nil
    end

    tier = NormalizeTierValue(tier)

    local material = {
        itemID = itemID,
        unresolvedName = not itemID and cleanValue or nil,
        importName = not itemID and cleanValue or nil,
        quantity = math.max(1, tonumber(quantity) or 1),
        label = label or cleanValue,
        importSearchName = cleanValue,
        importExpandGrades = not itemID and not IsExplicitImportItemIDText(cleanValue),
    }

    if tier then
        material.tier = tier
        material.chosenTier = tier
        material.materialQuality = tier
        material.professionQuality = tier
    end

    return material
end

function BuildMaterialFromAuctionatorItemToken(value)
    local cleanValue, quantity, tier = StripImportItemToken(value)

    if IsIgnoredImportToken(cleanValue) then
        return nil
    end

    local itemID, label = ResolveImportItem(cleanValue)

    if cleanValue == "" then
        return nil
    end

    tier = NormalizeTierValue(tier)

    local material = {
        itemID = itemID,
        unresolvedName = not itemID and cleanValue or nil,
        importName = not itemID and cleanValue or nil,
        quantity = math.max(1, tonumber(quantity) or 1),
        label = label or cleanValue,
        importSearchName = cleanValue,
        importExpandGrades = not itemID and not IsExplicitImportItemIDText(cleanValue),
    }

    if tier then
        material.tier = tier
        material.chosenTier = tier
        material.materialQuality = tier
        material.professionQuality = tier
    end

    return material
end

function BuildMaterialFromHironCraftProfitToken(token)
    token = tostring(token or "")
    if token == "" then
        return nil
    end

    local parts = SplitExportString(token, ",")
    local kind = parts[1]

    if kind == "i" then
        local itemID = tonumber(parts[2])
        local quantity = tonumber(parts[3]) or 1
        local tier = NormalizeTierValue(parts[4])
        local label = DecodeExportField(parts[5] or "")

        if not itemID or itemID <= 0 then
            return nil
        end

        local row = {
            itemID = itemID,
            quantity = quantity,
            label = label ~= "" and label or nil,
        }

        if tier then
            row.tier = tier
            row.chosenTier = tier
            row.materialQuality = tier
            row.professionQuality = tier
        end

        return row
    end

    if kind == "o" then
        local quantity = tonumber(parts[2]) or 1
        local tier = NormalizeTierValue(parts[3])
        local optionsText = parts[4] or ""
        local label = DecodeExportField(parts[5] or "")
        local options = {}

        for optText in string.gmatch(optionsText, "[^;]+") do
            local itemID, optTier = tostring(optText):match("^(%d+):?(%d*)$")
            itemID = tonumber(itemID)
            optTier = NormalizeTierValue(optTier)
            if itemID then
                table.insert(options, {
                    itemID = itemID,
                    tier = optTier,
                    materialQuality = optTier,
                    professionQuality = optTier,
                })
            end
        end

        if #options == 0 then
            return nil
        end

        local row = {
            options = options,
            quantity = quantity,
            label = label ~= "" and label or nil,
        }

        if tier then
            row.tier = tier
            row.chosenTier = tier
            row.materialQuality = tier
            row.professionQuality = tier
        end

        return row
    end

    if kind == "n" then
        local quantity = tonumber(parts[2]) or 1
        local tier = NormalizeTierValue(parts[3])
        local label = DecodeExportField(parts[4] or "")
        if label == "" then
            return nil
        end
        local row = {
            unresolvedName = label,
            importName = label,
            quantity = quantity,
            label = label,
            importSearchName = label,
            importExpandGrades = true,
        }
        if tier then
            row.tier = tier
            row.chosenTier = tier
            row.materialQuality = tier
            row.professionQuality = tier
        end
        return row
    end

    return BuildMaterialFromPlainItem(token)
end

function GetCurrentExportRows()
    if S.session and S.session.active and S.session.rows and #S.session.rows > 0 then
        return S.session.rows, S:GetActiveListName()
    end

    local db = GetDB()
    local activeID = S.activeSavedListID
    if activeID then
        for _, list in ipairs(db.savedLists or {}) do
            if list.id == activeID then
                return list.rows or {}, list.name or activeID
            end
        end
    end

    return {}, T("PG_SHOP_LIST_TEMPORARY", "Temporary list")
end

function ExportRowsAsHironCraftProfit(listName, rows)
    local parts = {
        "HIRONCRAFT_PROFIT_SHOP_V1",
        EncodeExportField(listName or T("PG_SHOP_LIST_TEMPORARY", "Temporary list")),
    }

    for _, row in ipairs(rows or {}) do
        local token = BuildExportRowToken(row)
        if token then
            table.insert(parts, token)
        end
    end

    return table.concat(parts, "^")
end

function BuildReadableAuctionatorToken(row)
    if not row then
        return nil
    end

    local quantity = math.max(1, math.floor(tonumber(row.quantity) or tonumber(row.remainingQuantity) or 1))
    local itemID = row.chosenItemID or row.itemID or (row.options and row.options[1] and row.options[1].itemID)
    local name = itemID and GetItemInfo(itemID) or row.label or row.unresolvedName or row.importName

    name = NormalizeOptionText(name)
    if name == "" then
        return nil
    end

    name = name:gsub("[%^%c]", " ")
    name = NormalizeOptionText(name)
    if name == "" then
        return nil
    end

    name = name:gsub('"', [[\"]])
    name = '"' .. name .. '"'

    if quantity > 1 then
        return name .. "; " .. tostring(quantity)
    end

    return name
end

function ExportRowsAsAuctionator(listName, rows)
    local parts = {
        NormalizeOptionText(listName or T("PG_SHOP_LIST_TEMPORARY", "Temporary list")):gsub("[%^%c]", " "),
    }

    for _, row in ipairs(rows or {}) do
        local token = BuildReadableAuctionatorToken(row)
        if token then
            table.insert(parts, token)
        end
    end

    return table.concat(parts, "^")
end
function S:ExportActiveList(format)
    local rows, listName = GetCurrentExportRows()
    format = tostring(format or "ahui")

    if format == "auctionator" then
        return ExportRowsAsAuctionator(listName, rows)
    end

    return ExportRowsAsHironCraftProfit(listName, rows)
end

function AddImportedRowsToCurrentList(materials)
    if not S.session or not S.session.active then
        S:CreateSavedList(T("PG_SHOP_IMPORTED_LIST", "Imported shopping list"))
    end

    local immediate, expand = SplitImportExpansionMaterials(materials or {})
    local canExpand = #expand > 0 and CanResolveImportByBrowse()
    local added = 0

    local source = canExpand and immediate or (materials or {})
    for _, material in ipairs(source) do
        if material.itemID and not (material.options and #material.options > 0) then
            local ok = S:AddManualItem(material.itemID, material.quantity or 1, material.label, material)
            if ok then
                added = added + 1
            end
        else
            local normalized = NormalizeMaterials({ material })
            local row = normalized[1]
            if row then
                table.insert(S.session.rows, row)
                added = added + 1
            end
        end
    end

    ReindexSessionRows()
    SyncActiveSavedList()
    RefreshShoppingWindow()

    if canExpand then
        S:QueueImportGradeExpansion(expand, S.activeSavedListID)
        added = added + #expand
    end

    return added
end

function CreateImportedSavedList(listName, materials)
    local immediate, expand = SplitImportExpansionMaterials(materials or {})
    local canExpand = #expand > 0 and CanResolveImportByBrowse()
    local source = canExpand and immediate or (materials or {})
    local rows = NormalizeAndMergeMaterials(source)

    if #rows == 0 and not canExpand then
        return nil, 0
    end

    local db = GetDB()
    local id = "list_" .. tostring(db.nextListID or 1)
    db.nextListID = (tonumber(db.nextListID) or 1) + 1

    listName = NormalizeOptionText(listName)
    if listName == "" then
        listName = string.format(T("PG_SHOP_SAVED_LIST_DEFAULT", "Shopping list %d"), db.nextListID - 1)
    end

    table.insert(db.savedLists, {
        id = id,
        name = listName,
        rows = ExportMaterialRows(rows),
        skillLineID = nil,
        createdAt = time and time() or 0,
        updatedAt = time and time() or 0,
    })

    S.activeSavedListID = id
    S._loadingSavedListID = nil
    S._loadingSavedListName = nil
    S.session = {
        active = true,
        rows = rows,
        skillLineID = nil,
        itemData = {},
        listName = listName,
        listKind = "saved",
    }
    S.pendingCommodityRow = nil
    S.pendingSearchCommodityRow = nil
    S.pendingItemPurchases = {}
    S.pendingSearchItemPurchases = {}
    if S.searchResults then
        S.searchResults.active = false
        S.searchResults.pending = false
        S.searchResults.query = ""
        S.searchResults.rows = {}
    end

    ReindexSessionRows()
    if S.SetShopTab then S:SetShopTab("buy") end
    S:ShowWindow()
    RefreshShoppingWindow()

    if canExpand then
        S:QueueImportGradeExpansion(expand, id)
    end

    return id, #rows + (canExpand and #expand or 0)
end

function ParseHironCraftProfitImport(text)
    local lists = {}
    for line in string.gmatch(tostring(text or "") .. "\n", "([^\n]*)\n") do
        line = NormalizeOptionText(line)
        if line ~= "" then
            local parts = SplitExportString(line, "^")
            if parts[1] == "HIRONCRAFT_PROFIT_SHOP_V1" then
                local listName = DecodeExportField(parts[2] or "")
                local materials = {}
                for index = 3, #parts do
                    local material = BuildMaterialFromHironCraftProfitToken(parts[index])
                    if material then
                        table.insert(materials, material)
                    end
                end
                table.insert(lists, { name = listName, materials = materials })
            end
        end
    end
    return lists
end

function ParseAuctionatorNewImport(text)
    local lists = {}
    text = tostring(text or "")
    text = text:gsub("%s+\n", "\n")
    text = text:gsub("\n+", "\n")

    for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
        line = NormalizeOptionText(line)
        if line ~= "" and string.find(line, "%^") then
            local parts = SplitExportString(line, "^")
            local listName = NormalizeOptionText(parts[1])
            local materials = {}
            for index = 2, #parts do
                local material = BuildMaterialFromAuctionatorItemToken(parts[index])
                if material then
                    table.insert(materials, material)
                end
            end
            table.insert(lists, { name = listName, materials = materials })
        end
    end

    return lists
end

function ParseAuctionatorOldImport(text)
    local lists = {}
    text = tostring(text or "")
    text = text:gsub("%s+\n", "\n")
    text = text:gsub("\n%s+", "\n")
    text = text:gsub("\n\n", "\n")
    text = text:gsub("^\n", "")
    text = text:gsub("%*+%s*", "*")
    text = text:gsub("^%*", "")

    for block in string.gmatch(text .. "*", "([^%*]*)%*") do
        block = NormalizeOptionText(block)
        if block ~= "" then
            local listName, items = string.match(block, "^([^\n]*)\n?(.*)$")
            listName = NormalizeOptionText(listName)
            local materials = {}
            for item in string.gmatch((items or "") .. "\n", "([^\n]*)\n") do
                local material = BuildMaterialFromAuctionatorItemToken(item)
                if material then
                    table.insert(materials, material)
                end
            end
            table.insert(lists, { name = listName, materials = materials })
        end
    end

    return lists
end

function ParseAuctionatorCommaImport(text)
    local materials = {}
    text = tostring(text or "")
    text = text:gsub("%s+\n", "\n")

    for token in string.gmatch(text .. ",", "([^,]*),") do
        local material = BuildMaterialFromAuctionatorItemToken(token)
        if material then
            table.insert(materials, material)
        end
    end

    if #materials == 0 then
        return {}
    end

    return {
        {
            name = T("PG_SHOP_IMPORTED_LIST", "Imported shopping list"),
            materials = materials,
        }
    }
end

function ParseTSMImport(text)
    local materials = {}
    text = tostring(text or ""):gsub("%s", "")

    for itemType, stringID in string.gmatch(text, "([ip]?):?(%d+)") do
        if itemType ~= "p" then
            local itemID = tonumber(stringID)
            if itemID and itemID > 0 then
                table.insert(materials, {
                    itemID = itemID,
                    quantity = 1,
                    label = GetItemInfo(itemID),
                })
            end
        end
    end

    if #materials == 0 then
        return {}
    end

    return {
        {
            name = T("PG_SHOP_IMPORTED_LIST", "Imported shopping list"),
            materials = materials,
        }
    }
end

function ParsePlainImport(text)
    local materials = {}
    for line in string.gmatch(tostring(text or "") .. "\n", "([^\n]*)\n") do
        local material = BuildMaterialFromPlainItem(line)
        if material then
            table.insert(materials, material)
        end
    end

    if #materials == 0 then
        return {}
    end

    return {
        {
            name = T("PG_SHOP_IMPORTED_LIST", "Imported shopping list"),
            materials = materials,
        }
    }
end

function ParseImportText(text)
    text = tostring(text or "")
    local trimmed = NormalizeOptionText(text)
    if trimmed == "" then
        return {}
    end

    if string.find(trimmed, "HIRONCRAFT_PROFIT_SHOP_V1", 1, true) then
        local lists = ParseHironCraftProfitImport(trimmed)
        if #lists > 0 then
            return lists
        end
    end

    if string.find(trimmed, "%^") then
        local lists = ParseAuctionatorNewImport(trimmed)
        if #lists > 0 then
            return lists
        end
    end

    if string.find(trimmed, "%*") then
        local lists = ParseAuctionatorOldImport(trimmed)
        if #lists > 0 then
            return lists
        end
    end

    if string.find(trimmed, ",") then
        local lists = ParseTSMImport(trimmed)
        if #lists > 0 then
            return lists
        end

        lists = ParseAuctionatorCommaImport(trimmed)
        if #lists > 0 then
            return lists
        end
    end

    return ParsePlainImport(trimmed)
end

function S:ImportShoppingLists(text, mode)
    local lists = ParseImportText(text)
    if #lists == 0 then
        return false, "empty", 0
    end

    local importedLists = 0
    local importedItems = 0
    mode = mode or "new"

    if mode == "merge" then
        for _, list in ipairs(lists) do
            importedItems = importedItems + AddImportedRowsToCurrentList(list.materials or {})
        end
        return importedItems > 0, importedItems > 0 and "merged" or "empty", importedItems
    end

    for _, list in ipairs(lists) do
        local _, count = CreateImportedSavedList(list.name, list.materials or {})
        if count and count > 0 then
            importedLists = importedLists + 1
            importedItems = importedItems + count
        end
    end

    return importedItems > 0, importedItems > 0 and "created" or "empty", importedItems, importedLists
end


SHOPPING_PLAN_MIRROR_SOURCE = "auctionator_api_mirror"

function NormalizeAuctionatorTierValue(value)
    local n = tonumber(value)
    if not n then
        return nil
    end

    n = math.floor(n)
    if n < 1 or n > 5 then
        return nil
    end

    return n
end

function IsOwnAuctionatorShoppingListCall(callerID)
    local caller = tostring(callerID or "")
    return caller == "HironCraftProfit" or caller:find("^HironCraftProfit") ~= nil
end

function BuildMaterialFromAuctionatorSearchString(token)
    token = NormalizeOptionText(token)
    if token == "" then
        return nil
    end

    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if api and type(api.ConvertFromSearchString) == "function" then
        local ok, terms = pcall(api.ConvertFromSearchString, "HironCraftProfit", token)

        if ok and type(terms) == "table" then
            local searchName = NormalizeOptionText(terms.searchString or terms.name or terms.itemName)
            if searchName ~= "" then
                local quantity = math.floor(tonumber(terms.quantity) or 1)
                if quantity <= 0 then
                    return nil
                end

                local auctionatorTier = NormalizeAuctionatorTierValue(terms.tier)
                local itemID = tonumber(terms.itemID)
                local label

                if itemID and itemID > 0 then
                    RequestItemData(itemID)
                    label = GetItemInfo(itemID) or searchName
                elseif auctionatorTier then
                    itemID = nil
                    label = searchName
                else
                    itemID, label = ResolveImportItem(searchName)
                end

                local material = {
                    itemID = itemID,
                    unresolvedName = not itemID and searchName or nil,
                    importName = not itemID and searchName or nil,
                    quantity = quantity,
                    label = label or searchName,
                    importSearchName = searchName,
                    importExpandGrades = auctionatorTier ~= nil or (not itemID and not IsExplicitImportItemIDText(searchName)),
                    auctionatorSearchString = token,
                    auctionatorTier = auctionatorTier,
                    auctionatorIsExact = terms.isExact ~= false,
                }

                if auctionatorTier then
                    material.tier = auctionatorTier
                    material.chosenTier = auctionatorTier
                    material.materialQuality = auctionatorTier
                    material.professionQuality = auctionatorTier
                else
                    local tier = NormalizeTierValue(terms.tier)
                    if tier then
                        material.tier = tier
                        material.chosenTier = tier
                        material.materialQuality = tier
                        material.professionQuality = tier
                    end
                end

                return material
            end
        end
    end

    local material = BuildMaterialFromAuctionatorItemToken(token)
    if material then
        material.auctionatorSearchString = token
    end
    return material
end

function S:ResolveUnresolvedSessionRowsByBrowse(afterDone)
    if not self.session or not self.session.active or not self.session.rows then
        return false
    end

    if not CanResolveImportByBrowse() then
        return false
    end

    if self.importResolveState and self.importResolveState.active then
        return false
    end

    local materials = {}
    local rows = self.session.rows

    for index = #rows, 1, -1 do
        local row = rows[index]
        local hasOptions = type(row and row.options) == "table" and #row.options > 0
        local searchName = NormalizeOptionText(row and (row.importSearchName or row.unresolvedName or row.importName or row.label) or "")

        if row
           and not row.itemID
           and not hasOptions
           and searchName ~= ""
           and row.importResolveAttempted ~= true
        then
            local quantity = GetRemainingQuantity(row)
            if quantity <= 0 then
                quantity = tonumber(row.quantity) or 1
            end
            if quantity <= 0 then
                quantity = 1
            end

            local tier = NormalizeTierValue(row.chosenTier or row.tier or row.professionQuality or row.craftedQuality or row.materialQuality)

            table.insert(materials, 1, {
                unresolvedName = searchName,
                importName = searchName,
                importSearchName = searchName,
                importExpandGrades = true,
                importResolveAttempted = true,
                quantity = quantity,
                label = row.label or searchName,
                tier = tier,
                chosenTier = tier,
                materialQuality = tier or NormalizeTierValue(row.materialQuality),
                professionQuality = tier or NormalizeTierValue(row.professionQuality),
                craftedQuality = NormalizeTierValue(row.craftedQuality),
                auctionatorSearchString = row.auctionatorSearchString,
                auctionatorTier = row.auctionatorTier,
                auctionatorIsExact = row.auctionatorIsExact,
            })

            table.remove(rows, index)
        end
    end

    if #materials == 0 then
        return false
    end

    ReindexSessionRows()
    SyncActiveSavedList()
    RefreshShoppingWindow()

    return self:QueueImportGradeExpansion(materials, self.activeSavedListID, afterDone)
end

function ScheduleTemporaryAuctionatorPlanScan(sessionSerial)
    S._pendingAuctionatorPlanScan = true
    S._pendingAuctionatorPlanScanSerial = sessionSerial or (S.session and S.session.importSerial)

    local function TryStart()
        if not S._pendingAuctionatorPlanScan then
            return
        end

        local wantedSerial = S._pendingAuctionatorPlanScanSerial
        if wantedSerial and (not S.session or S.session.importSerial ~= wantedSerial) then
            S._pendingAuctionatorPlanScan = false
            S._pendingAuctionatorPlanScanSerial = nil
            return
        end

        if not S.session or not S.session.active then
            S._pendingAuctionatorPlanScan = false
            return
        end

        if not S.isAuctionHouseOpen then
            RefreshShoppingWindow()
            return
        end

        if S.importResolveState and S.importResolveState.active then
            return
        end

        if S.scanAllState and S.scanAllState.active then
            return
        end

        if S.ResolveUnresolvedSessionRowsByBrowse
           and S:ResolveUnresolvedSessionRowsByBrowse(function()
                ScheduleTemporaryAuctionatorPlanScan(sessionSerial)
           end)
        then
            S._pendingAuctionatorPlanScan = false
            return
        end

        S._pendingAuctionatorPlanScan = false
        S._pendingAuctionatorPlanScanSerial = nil
        S._auctionatorPlanMirrorActiveKey = nil

        if S.ScanAllRows then
            S:ScanAllRows()
        else
            RefreshShoppingWindow()
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.15, TryStart)
        C_Timer.After(0.50, TryStart)
    else
        TryStart()
    end
end

function CreateTemporaryImportedList(listName, materials, sourceKind)
    local immediate, expand = SplitImportExpansionMaterials(materials or {})
    local canExpand = #expand > 0 and CanResolveImportByBrowse()
    expand = CombineImportResolveMaterials(expand)
    local source = canExpand and immediate or (materials or {})
    local rows = NormalizeAndMergeMaterials(source)

    if #rows == 0 and not canExpand then
        return false, "empty", 0
    end

    listName = NormalizeOptionText(listName)
    if listName == "" then
        listName = T("PG_SHOP_LIST_TEMPORARY", "Temporary list")
    end

    S:StopScanAll()
    S:StopBuyAll()

    if S.ResetSearchOptions then
        S:ResetSearchOptions(true)
    end

    InvalidateImportResolveState()
    S._pendingAuctionatorPlanScan = false
    S._pendingAuctionatorPlanScanSerial = nil
    S._auctionatorPlanSessionSerial = (tonumber(S._auctionatorPlanSessionSerial) or 0) + 1
    local sessionSerial = S._auctionatorPlanSessionSerial

    local db = GetDB()
    local resolvedSourceKind = sourceKind or SHOPPING_PLAN_MIRROR_SOURCE

    if db.savedLists then
        for index = #db.savedLists, 1, -1 do
            local existing = db.savedLists[index]
            if existing
               and existing.temporary == true
               and (existing.sourceKind or SHOPPING_PLAN_MIRROR_SOURCE) == resolvedSourceKind
               and (existing.name == listName or (existing.sourceKind == resolvedSourceKind and sourceKind ~= nil))
            then
                if S.activeSavedListID == existing.id then
                    S.activeSavedListID = nil
                end
                table.remove(db.savedLists, index)
            end
        end
    end

    local id = "list_" .. tostring(db.nextListID or 1)
    db.nextListID = (tonumber(db.nextListID) or 1) + 1

    local exportedRows = ExportMaterialRows(rows)
    local seedRows = ExportMaterialRows(rows)

    table.insert(db.savedLists, {
        id = id,
        name = listName,
        rows = exportedRows,
        seedRows = seedRows,
        seedMaterials = materials,
        skillLineID = nil,
        createdAt = time and time() or 0,
        updatedAt = time and time() or 0,
        temporary = true,
        sourceKind = resolvedSourceKind,
    })

    S.activeSavedListID = id
    S._loadingSavedListID = nil
    S._loadingSavedListName = nil

    S.session = {
        active = true,
        rows = rows,
        skillLineID = nil,
        itemData = {},
        listName = listName,
        listKind = "saved",
        sourceKind = sourceKind or SHOPPING_PLAN_MIRROR_SOURCE,
        temporary = true,
        importSerial = sessionSerial,
    }

    S.pendingCommodityRow = nil
    S.pendingSearchCommodityRow = nil
    S.pendingItemPurchases = {}
    S.pendingSearchItemPurchases = {}

    if S.searchResults then
        S.searchResults.active = false
        S.searchResults.pending = false
        S.searchResults.query = ""
        S.searchResults.rows = {}
    end

    ReindexSessionRows()

    if S.SetShopTab then S:SetShopTab("buy") end

    if S.ShowWindow then
        S:ShowWindow()
    end

    RefreshShoppingWindow()

    local totalCount = #rows + (canExpand and #expand or 0)

    if canExpand then
        S:QueueImportGradeExpansion(expand, id, function()
            ScheduleTemporaryAuctionatorPlanScan(sessionSerial)
        end, sessionSerial)

        if S.isAuctionHouseOpen and S.ScanAllRows then
            local hasResolvedRow = false
            for _, row in ipairs(rows) do
                if row.itemID then
                    hasResolvedRow = true
                    break
                end
            end
            if hasResolvedRow then
                C_Timer.After(0, function()
                    if S.session
                       and S.session.active
                       and S.session.importSerial == sessionSerial
                       and S.isAuctionHouseOpen
                       and not (S.scanAllState and S.scanAllState.active)
                    then
                        S:ScanAllRows()
                    end
                end)
            end
        end
    else
        ScheduleTemporaryAuctionatorPlanScan(sessionSerial)

        if S.isAuctionHouseOpen and S.ScanAllRows then
            local hasResolvedRow = false
            for _, row in ipairs(rows) do
                if row.itemID then
                    hasResolvedRow = true
                    break
                end
            end
            if hasResolvedRow then
                C_Timer.After(0, function()
                    if S.session
                       and S.session.active
                       and S.session.importSerial == sessionSerial
                       and S.isAuctionHouseOpen
                       and not (S.scanAllState and S.scanAllState.active)
                    then
                        S:ScanAllRows()
                    end
                end)
            end
        end
    end

    return true, "created", totalCount
end

function S:CreateTemporaryImportedList(listName, materials, sourceKind)
    return CreateTemporaryImportedList(listName, materials, sourceKind)
end

function BuildMirroredAuctionatorPlanName(callerID, listName)
    local caller = NormalizeOptionText(callerID)
    local targetName = NormalizeOptionText(listName)

    if targetName == "" then
        targetName = T("PG_SHOP_IMPORTED_LIST", "Imported shopping list")
    end

    if caller ~= "" and not targetName:find(caller, 1, true) then
        targetName = caller .. ": " .. targetName
    end

    return targetName
end

AUCTIONATOR_PLAN_MIRROR_DEBOUNCE = 6.0
AUCTIONATOR_PLAN_MIRROR_CACHE_TTL = 60.0

function BuildAuctionatorPlanFingerprint(callerID, listName, searchStrings)
    if type(searchStrings) ~= "table" then
        return nil
    end

    local tokens = {}
    for _, token in pairs(searchStrings) do
        token = NormalizeOptionText(token)
        if token ~= "" then
            table.insert(tokens, token)
        end
    end

    if #tokens == 0 then
        return nil
    end

    table.sort(tokens)

    return table.concat({
        NormalizeOptionText(callerID),
        NormalizeOptionText(listName),
        table.concat(tokens, "\n"),
    }, "\031")
end

function GetClockSeconds()
    if GetTime then
        return GetTime()
    end
    if time then
        return time()
    end
    return 0
end

function IsRecentlyMirroredAuctionatorPlan(fingerprint)
    if not fingerprint then
        return false
    end

    local now = GetClockSeconds()
    S._auctionatorPlanMirrorRecent = S._auctionatorPlanMirrorRecent or {}

    local last = S._auctionatorPlanMirrorRecent[fingerprint]
    if last and (now - last) < AUCTIONATOR_PLAN_MIRROR_DEBOUNCE then
        return true
    end

    S._auctionatorPlanMirrorRecent[fingerprint] = now

    for key, stamp in pairs(S._auctionatorPlanMirrorRecent) do
        if (now - (tonumber(stamp) or 0)) > AUCTIONATOR_PLAN_MIRROR_CACHE_TTL then
            S._auctionatorPlanMirrorRecent[key] = nil
        end
    end

    return false
end

function IsMirrorBusyWithSamePlan(fingerprint)
    if not fingerprint or S._auctionatorPlanMirrorActiveKey ~= fingerprint then
        return false
    end

    if S._pendingAuctionatorPlanScan then
        return true
    end

    if S.importResolveState and S.importResolveState.active then
        return true
    end

    if S.scanAllState and S.scanAllState.active then
        return true
    end

    return false
end

function CopyAuctionatorAdvancedTerm(term)
    if type(term) ~= "table" then
        return term
    end

    local copy = {}
    for key, value in pairs(term) do
        copy[key] = value
    end
    return copy
end

function CopyAuctionatorSearchTerms(searchTerms)
    local out = {}

    if type(searchTerms) ~= "table" then
        return out
    end

    local numericKeys = {}
    local otherKeys = {}

    for key in pairs(searchTerms) do
        if type(key) == "number" then
            table.insert(numericKeys, key)
        else
            table.insert(otherKeys, key)
        end
    end

    table.sort(numericKeys)

    for _, key in ipairs(numericKeys) do
        local term = searchTerms[key]
        if term ~= nil then
            table.insert(out, CopyAuctionatorAdvancedTerm(term))
        end
    end

    table.sort(otherKeys, function(a, b)
        return tostring(a) < tostring(b)
    end)

    for _, key in ipairs(otherKeys) do
        local term = searchTerms[key]

        if type(term) == "table" then
            local searchName = NormalizeOptionText(term.searchString or term.name or term.itemName)
            if searchName ~= "" then
                table.insert(out, CopyAuctionatorAdvancedTerm(term))
            end
        elseif NormalizeOptionText(term) ~= "" then
            table.insert(out, term)
        end
    end

    return out
end

function IsAuctionatorReagentSearchCaller(callerID)
    local caller = NormalizeOptionText(callerID)
    if caller == "" then
        return false
    end

    local reagentCaller = NormalizeOptionText(_G.AUCTIONATOR_L_REAGENT_SEARCH)
    if reagentCaller ~= "" and caller == reagentCaller then
        return true
    end

    local lower = SearchLower(caller)
    return lower:find("reagent", 1, true) ~= nil
        or lower:find("реаг", 1, true) ~= nil
end

function GetAuctionatorAdvancedTermQuantity(term)
    if type(term) ~= "table" then
        return 1
    end

    local rawQuantity = term.quantity
    if rawQuantity == nil then
        rawQuantity = term.count
    end

    if rawQuantity == nil then
        return nil
    end

    local quantity = tonumber(rawQuantity)
    if quantity == nil then
        return nil
    end

    return math.floor(quantity)
end
function LooksLikeAuctionatorTemporaryReagentSearch(callerID, searchTerms)
    if type(searchTerms) ~= "table" or #searchTerms == 0 then
        return false
    end

    local fromReagentCaller = IsAuctionatorReagentSearchCaller(callerID)
    local hasPositiveMaterial = false
    local hasOutputMarker = false

    for _, term in ipairs(searchTerms) do
        if type(term) == "table" then
            local searchName = NormalizeOptionText(term.searchString or term.name or term.itemName)
            local quantity = GetAuctionatorAdvancedTermQuantity(term)

            if searchName ~= "" then
                if quantity and quantity > 0 then
                    hasPositiveMaterial = true
                else
                    hasOutputMarker = true
                end
            end
        elseif NormalizeOptionText(term) ~= "" then
            hasPositiveMaterial = true
        end
    end

    return hasPositiveMaterial and (fromReagentCaller or hasOutputMarker)
end

function BuildMaterialFromAuctionatorAdvancedTerm(term)
    local searchName
    local quantity
    local tier
    local itemID
    local label
    local isExact
    local itemQuality

    if type(term) == "table" then
        searchName = NormalizeOptionText(term.searchString or term.name or term.itemName)
        quantity = GetAuctionatorAdvancedTermQuantity(term)
        tier = NormalizeAuctionatorTierValue(term.tier or term.qualityTier or term.materialQuality)
        itemID = tonumber(term.itemID or (term.itemKey and term.itemKey.itemID))
        isExact = term.isExact == true
        itemQuality = term.quality
    else
        searchName = NormalizeOptionText(term)
        quantity = 1
        isExact = false
    end

    if searchName == "" or quantity == nil or quantity <= 0 then
        return nil
    end

    if itemID and itemID > 0 then
        RequestItemData(itemID)
        label = GetItemInfo(itemID) or searchName
    elseif tier then
        itemID = nil
        label = searchName
    else
        itemID, label = ResolveImportItem(searchName)
    end

    local material = {
        itemID = itemID,
        unresolvedName = not itemID and searchName or nil,
        importName = not itemID and searchName or nil,
        quantity = math.max(1, quantity),
        label = label or searchName,
        importSearchName = searchName,
        importExpandGrades = (not itemID) and (tier ~= nil or not IsExplicitImportItemIDText(searchName)),
        auctionatorAdvancedTerm = true,
        auctionatorTier = tier,
        auctionatorIsExact = isExact,
        quality = itemQuality,
    }

    if tier then
        material.tier = tier
        material.chosenTier = tier
        material.materialQuality = tier
        material.professionQuality = tier
    end

    return material
end

function BuildAuctionatorAdvancedSearchFingerprint(callerID, searchTerms)
    if type(searchTerms) ~= "table" or #searchTerms == 0 then
        return nil
    end

    local tokens = {}

    for _, term in ipairs(searchTerms) do
        if type(term) == "table" then
            local searchName = NormalizeOptionText(term.searchString or term.name or term.itemName)
            local quantity = GetAuctionatorAdvancedTermQuantity(term)

            if searchName ~= "" and quantity and quantity > 0 then
                table.insert(tokens, table.concat({
                    searchName,
                    tostring(quantity),
                    tostring(term.tier or ""),
                    tostring(term.quality or ""),
                    tostring(term.isExact == true),
                }, "\030"))
            end
        else
            local searchName = NormalizeOptionText(term)
            if searchName ~= "" then
                table.insert(tokens, searchName)
            end
        end
    end

    if #tokens == 0 then
        return nil
    end

    table.sort(tokens)

    return table.concat({
        "auctionator_advanced",
        NormalizeOptionText(callerID),
        table.concat(tokens, "\031"),
    }, "\031")
end

function IsRecentlyMirroredAuctionatorAdvancedSearch(fingerprint)
    if not fingerprint then
        return false
    end

    local now = GetClockSeconds()
    S._auctionatorAdvancedMirrorRecent = S._auctionatorAdvancedMirrorRecent or {}

    local last = S._auctionatorAdvancedMirrorRecent[fingerprint]
    if last and (now - last) < 0.75 then
        return true
    end

    S._auctionatorAdvancedMirrorRecent[fingerprint] = now

    for key, stamp in pairs(S._auctionatorAdvancedMirrorRecent) do
        if (now - (tonumber(stamp) or 0)) > 10 then
            S._auctionatorAdvancedMirrorRecent[key] = nil
        end
    end

    return false
end

function BuildMirroredAuctionatorAdvancedSearchName(callerID, searchTerms)
    local caller = NormalizeOptionText(callerID)
    local outputName = ""

    for _, term in ipairs(searchTerms or {}) do
        if type(term) == "table" then
            local quantity = GetAuctionatorAdvancedTermQuantity(term)
            local searchName = NormalizeOptionText(term.searchString or term.name or term.itemName)

            if searchName ~= "" and (quantity == nil or quantity <= 0) then
                outputName = searchName
                break
            end
        end
    end

    local name = outputName ~= "" and outputName or T("PG_SHOP_IMPORTED_LIST", "Imported shopping list")

    if caller ~= "" and not name:find(caller, 1, true) then
        name = caller .. ": " .. name
    end

    return name
end

DebugAuctionatorMirrorEnabled = function()
    return PT.config and PT.config.shoppingListMirrorDebug == true
end

function DebugAuctionatorValue(value, depth)
    depth = depth or 0

    if depth > 2 then
        return "..."
    end

    if type(value) ~= "table" then
        return tostring(value)
    end

    local parts = {}
    local keys = {}

    for key in pairs(value) do
        table.insert(keys, key)
    end

    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)

    for _, key in ipairs(keys) do
        local v = value[key]
        if type(v) == "table" then
            table.insert(parts, tostring(key) .. "={" .. DebugAuctionatorValue(v, depth + 1) .. "}")
        else
            table.insert(parts, tostring(key) .. "=" .. tostring(v))
        end
    end

    return table.concat(parts, ", ")
end

function DebugAuctionatorMirror(callerID, searchTerms, stage)
    if not DebugAuctionatorMirrorEnabled() then
        return
    end

    print("|cffb19cd9HironCraft mirror debug|r", stage or "", "caller:", tostring(callerID), "terms:", tostring(type(searchTerms) == "table" and #searchTerms or "not_table"))

    if type(searchTerms) ~= "table" then
        return
    end

    for index, term in ipairs(searchTerms) do
        if type(term) == "table" then
            local searchName = NormalizeOptionText(term.searchString or term.name or term.itemName)
            local quantity = GetAuctionatorAdvancedTermQuantity(term)
            local itemID = tonumber(term.itemID or (term.itemKey and term.itemKey.itemID))
            local tier = NormalizeAuctionatorTierValue(term.tier or term.qualityTier or term.materialQuality)

            print(string.format(
                "|cff33ccffHironCraftProfit term %d|r name='%s' qty=%s tier=%s itemID=%s raw={%s}",
                index,
                searchName,
                tostring(quantity),
                tostring(tier),
                tostring(itemID),
                DebugAuctionatorValue(term, 0)
            ))
        else
            print(string.format(
                "|cff33ccffHironCraftProfit term %d|r raw='%s'",
                index,
                tostring(term)
            ))
        end
    end
end

function S:MirrorAuctionatorMultiSearchAdvanced(callerID, searchTerms)
    searchTerms = CopyAuctionatorSearchTerms(searchTerms)
    DebugAuctionatorMirror(callerID, searchTerms, "copied")
    if not self:IsAuctionatorPlanMirrorEnabled() then
        return false, "disabled", 0
    end

    if not self.isAuctionHouseOpen then
        return false, "ah_closed", 0
    end

    if IsOwnAuctionatorShoppingListCall(callerID) then
        return false, "own_call", 0
    end

    if #searchTerms == 0 then
        return false, "empty", 0
    end

    if not LooksLikeAuctionatorTemporaryReagentSearch(callerID, searchTerms) then
        return false, "not_reagent_search", 0
    end

    local fingerprint = BuildAuctionatorAdvancedSearchFingerprint(callerID, searchTerms)
    if not fingerprint then
        return false, "empty", 0
    end

    if IsMirrorBusyWithSamePlan(fingerprint) or IsRecentlyMirroredAuctionatorAdvancedSearch(fingerprint) then
        return false, "duplicate", 0
    end

    local materials = {}

    for index, term in ipairs(searchTerms) do
        local material = BuildMaterialFromAuctionatorAdvancedTerm(term)

        if DebugAuctionatorMirrorEnabled() then
            if material then
                print(string.format(
                    "|cff33ccffHironCraftProfit material %d|r itemID=%s name='%s' qty=%s tier=%s expand=%s",
                    index,
                    tostring(material.itemID),
                    tostring(material.importSearchName or material.label),
                    tostring(material.quantity),
                    tostring(material.auctionatorTier or material.tier),
                    tostring(material.importExpandGrades)
                ))
            else
                print(string.format(
                    "|cff33ccffHironCraftProfit material %d|r skipped",
                    index
                ))
            end
        end

        if material then
            table.insert(materials, material)
        end
    end

    if #materials == 0 then
        return false, "empty", 0
    end

    self._auctionatorPlanMirrorActiveKey = fingerprint

    local ok, status, count = CreateTemporaryImportedList(
        BuildMirroredAuctionatorAdvancedSearchName(callerID, searchTerms),
        materials,
        SHOPPING_PLAN_MIRROR_SOURCE .. ":" .. NormalizeOptionText(callerID)
    )

    if not ok and self._auctionatorPlanMirrorActiveKey == fingerprint then
        self._auctionatorPlanMirrorActiveKey = nil
    end

    if ok then
        print(string.format(
            T("PG_SHOP_PLAN_MIRROR_DONE", "HironCraft: shopping plan copied: %d items."),
            tonumber(count) or 0
        ))
    end

    return ok == true, status or "created", count or 0
end

function S:EnsureAuctionatorTemporarySearchMirror()
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if not api then
        return false, "auctionator_api_missing"
    end

    local hooked = false

    local function ReadMultiSearchArgs(a, b, c)
        local callerID = a
        local searchTerms = b

        if type(a) == "table" then
            callerID = b
            searchTerms = c
        end

        return callerID, CopyAuctionatorSearchTerms(searchTerms)
    end

    local function MirrorFromCopiedTerms(callerID, copiedTerms)
        local shopping = HironCraftProfit and HironCraftProfit.ShoppingList
        if not shopping
        or not shopping.IsAuctionatorPlanMirrorEnabled
        or not shopping.MirrorAuctionatorMultiSearchAdvanced
        or not shopping:IsAuctionatorPlanMirrorEnabled()
        then
            return false
        end

        local ok, mirrored, status = pcall(
            shopping.MirrorAuctionatorMultiSearchAdvanced,
            shopping,
            callerID,
            copiedTerms
        )

        if not ok then
            print(T("PG_SHOP_PLAN_MIRROR_ERROR", "HironCraft: shopping plan copy error."), mirrored)
            return false
        end

        if mirrored == true or status == "duplicate" then
            return true
        end

        return false
    end

    local function ScheduleMirrorFromCopiedTerms(callerID, copiedTerms)
        local count = type(copiedTerms) == "table" and #copiedTerms or 1

        local delay = math.min(8.0, math.max(1.25, count * 0.65))

        if DebugAuctionatorMirrorEnabled and DebugAuctionatorMirrorEnabled() then
            print(string.format(
                "|cff33ccffHironCraftProfit mirror scheduled|r delay=%.2f terms=%s",
                delay,
                tostring(count)
            ))
        end

        if C_Timer and C_Timer.After then
            C_Timer.After(delay, function()
                MirrorFromCopiedTerms(callerID, copiedTerms)
            end)
        else
            MirrorFromCopiedTerms(callerID, copiedTerms)
        end
    end

    if type(api.MultiSearchAdvanced) == "function" and not api._HironCraftProfitAuctionatorTemporarySearchMirrorHooked then
        local originalMultiSearchAdvanced = api.MultiSearchAdvanced
        api._HironCraftProfitMultiSearchAdvancedOriginal = originalMultiSearchAdvanced

        api.MultiSearchAdvanced = function(...)
            local callerID, copiedTerms = ReadMultiSearchArgs(...)

            if MirrorFromCopiedTerms(callerID, copiedTerms) then
                return true
            end

            return originalMultiSearchAdvanced(...)
        end

        api._HironCraftProfitAuctionatorTemporarySearchMirrorHooked = true
        hooked = true
    end

    if type(api.MultiSearch) == "function" and not api._HironCraftProfitAuctionatorTemporarySimpleSearchMirrorHooked then
        local originalMultiSearch = api.MultiSearch
        api._HironCraftProfitMultiSearchOriginal = originalMultiSearch

        api.MultiSearch = function(...)
            local callerID, copiedTerms = ReadMultiSearchArgs(...)

            if MirrorFromCopiedTerms(callerID, copiedTerms) then
                return true
            end

            return originalMultiSearch(...)
        end

        api._HironCraftProfitAuctionatorTemporarySimpleSearchMirrorHooked = true
        hooked = true
    end

    return hooked
        or api._HironCraftProfitAuctionatorTemporarySearchMirrorHooked == true
        or api._HironCraftProfitAuctionatorTemporarySimpleSearchMirrorHooked == true
end

function S:MirrorAuctionatorShoppingListCreate(callerID, listName, searchStrings)
    if not self:IsAuctionatorPlanMirrorEnabled() then
        return false, "disabled", 0
    end

    if not self.isAuctionHouseOpen then
        return false, "ah_closed", 0
    end

    if IsOwnAuctionatorShoppingListCall(callerID) then
        return false, "own_call", 0
    end

    if type(searchStrings) ~= "table" then
        return false, "bad_items", 0
    end

    local fingerprint = BuildAuctionatorPlanFingerprint(callerID, listName, searchStrings)
    if not fingerprint then
        return false, "empty", 0
    end

    if IsMirrorBusyWithSamePlan(fingerprint) or IsRecentlyMirroredAuctionatorPlan(fingerprint) then
        return false, "duplicate", 0
    end

    local materials = {}
    for _, token in pairs(searchStrings) do
        local material = BuildMaterialFromAuctionatorSearchString(token)
        if material then
            table.insert(materials, material)
        end
    end

    if #materials == 0 then
        return false, "empty", 0
    end

    self._auctionatorPlanMirrorActiveKey = fingerprint

    local ok, status, count = CreateTemporaryImportedList(
        BuildMirroredAuctionatorPlanName(callerID, listName),
        materials,
        SHOPPING_PLAN_MIRROR_SOURCE .. ":" .. NormalizeOptionText(callerID)
    )

    if not ok and self._auctionatorPlanMirrorActiveKey == fingerprint then
        self._auctionatorPlanMirrorActiveKey = nil
    end

    if ok then
        print(string.format(
            T("PG_SHOP_PLAN_MIRROR_DONE", "HironCraft: shopping plan copied: %d items."),
            tonumber(count) or 0
        ))
    end

    return ok == true, status or "created", count or 0
end

function S:EnsureAuctionatorPlanMirror()
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if not api then
        return false, "auctionator_api_missing"
    end

    local hookedSomething = false

    if type(api.CreateShoppingList) == "function" then
        if not api._HironCraftProfitAuctionatorPlanMirrorHooked then
            local function MirrorAfterOriginal(callerID, listName, searchStrings, ...)
                local shopping = HironCraftProfit and HironCraftProfit.ShoppingList
                if not shopping
                   or not shopping.IsAuctionatorPlanMirrorEnabled
                   or not shopping.MirrorAuctionatorShoppingListCreate
                   or not shopping:IsAuctionatorPlanMirrorEnabled()
                then
                    return
                end

                local ok, err = pcall(
                    shopping.MirrorAuctionatorShoppingListCreate,
                    shopping,
                    callerID,
                    listName,
                    searchStrings
                )

                if not ok then
                    print(T("PG_SHOP_PLAN_MIRROR_ERROR", "HironCraft: shopping plan copy error."), err)
                end
            end

            if hooksecurefunc then
                hooksecurefunc(api, "CreateShoppingList", MirrorAfterOriginal)
            else
                local originalCreateShoppingList = api.CreateShoppingList
                api._HironCraftProfitAuctionatorPlanMirrorOriginal = originalCreateShoppingList

                api.CreateShoppingList = function(callerID, listName, searchStrings, ...)
                    local r1, r2, r3, r4, r5 = originalCreateShoppingList(callerID, listName, searchStrings, ...)
                    MirrorAfterOriginal(callerID, listName, searchStrings, ...)
                    return r1, r2, r3, r4, r5
                end
            end

            api._HironCraftProfitAuctionatorPlanMirrorHooked = true
        end

        hookedSomething = true
    end

    if self.EnsureAuctionatorTemporarySearchMirror then
        local ok = self:EnsureAuctionatorTemporarySearchMirror()
        hookedSomething = hookedSomething or ok == true
    end

    if hookedSomething then
        return true
    end

    return false, "auctionator_api_missing"
end

function S:EnsureCraftSimAuctionatorIntercept()
    if self.EnsureAuctionatorPlanMirror then
        return self:EnsureAuctionatorPlanMirror()
    end
    return false, "auctionator_api_missing"
end

function S:ImportCraftSimAuctionatorShoppingList(callerID, listName, searchStrings)
    if self.MirrorAuctionatorShoppingListCreate then
        return self:MirrorAuctionatorShoppingListCreate(callerID, listName, searchStrings)
    end
    return false, "missing_mirror", 0
end

function S:HandleAuctionatorShoppingListCreate(callerID, listName, searchStrings, ...)
    if self.MirrorAuctionatorShoppingListCreate then
        return self:MirrorAuctionatorShoppingListCreate(callerID, listName, searchStrings)
    end
    return false
end


function S:RemoveRow(index)
    local rows = self.session and self.session.rows
    local row = rows and rows[index]
    if not row then
        return false, "missing_row"
    end

    if self.pendingCommodityRow == row and C_AuctionHouse and C_AuctionHouse.CancelCommoditiesPurchase then
        pcall(C_AuctionHouse.CancelCommoditiesPurchase)
        self.pendingCommodityRow = nil
    end

    for auctionID, pending in pairs(self.pendingItemPurchases or {}) do
        if pending and pending.rowIndex == index then
            self.pendingItemPurchases[auctionID] = nil
        end
    end

    table.remove(rows, index)
    ReindexSessionRows()
    SyncActiveSavedList()
    RefreshWindow()
    return true
end

function S:SetRowQuantity(index, quantity)
    local row = self.session and self.session.rows and self.session.rows[index]
    if not row then
        return false, "missing_row"
    end
    if row.isCommodity == false then
        return false, "not_quantity_editable"
    end
    local q = math.floor(tonumber(quantity) or 0)
    if q < 0 then q = 0 end
    if q > 999999 then q = 999999 end
    row.quantity = q
    row.remainingQuantity = q
    row.hidden = false
    row.purchaseStage = nil
    row.pendingQuantity = nil
    row.pendingUnitPrice = nil
    row.pendingTotalPrice = nil
    if q <= 0 then
        row.status = T("PG_SHOP_STATUS_BOUGHT", "Bought")
    elseif row.chosenItemID and self.isAuctionHouseOpen then
        self:SearchItemID(row.chosenItemID, true)
    else
        row.status = T("PG_SHOP_STATUS_NOT_SCANNED", "Not scanned")
        RefreshWindow()
    end
    SyncActiveSavedList()
    return true
end

function S:RefreshPrices()
    self:StopScanAll()
    self:StopBuyAll()
    if self.pendingCommodityRow and C_AuctionHouse and C_AuctionHouse.CancelCommoditiesPurchase then
        pcall(C_AuctionHouse.CancelCommoditiesPurchase)
    end
    self.pendingCommodityRow = nil
    self.pendingSearchCommodityRow = nil
    self.pendingItemPurchases = {}
    self.pendingSearchItemPurchases = {}
    self.session.itemData = {}
    self._lastScanAllSessionSerial = nil
    self._lastScanAllKey = nil
    self._lastScanAllStartedAt = nil

    for _, row in ipairs(self:GetRows()) do
        row.searchPending = false
        row.purchaseStage = nil
        row.pendingQuantity = nil
        row.pendingUnitPrice = nil
        row.pendingTotalPrice = nil
        row.minPrice = nil
        row.totalQuantity = nil
        row.isCommodity = nil
        row.bestAuctionID = nil
        row.bestAuctionQuantity = nil
        row.bestBuyoutAmount = nil
        row.lastChosenName = nil
        row.skipped = nil

        if row.options and #row.options > 0 then
            row.chosenItemID = nil
            row.chosenTier = nil
            row.professionQuality = nil
            row.craftedQuality = nil
            row.materialQuality = nil
            row.itemClassID = nil
            row.itemSubClassID = nil
            row.expansionID = nil
        else
            row.chosenItemID = row.itemID
            row.chosenTier = nil
        end

        if GetRemainingQuantity(row) <= 0 then
            row.status = T("PG_SHOP_STATUS_BOUGHT", "Bought")
        else
            row.status = T("PG_SHOP_STATUS_NOT_SCANNED", "Not scanned")
        end
    end

    if self.isAuctionHouseOpen then
        self:ScanAllRows()
        return
    end

    RefreshWindow()
end

function S:ResetPrices()
    return self:RefreshPrices()
end

function S:CreateShoppingSession(materials, skillLineID, options)
    if not IsAHAvailable() or not GetLibAHTab() then
        return false, "no_auction_house_tab_lib"
    end

    local rows = NormalizeMaterials(materials)
    if not rows or #rows == 0 then
        return false, "empty"
    end

    local loadID = self._loadingSavedListID
    local loadName = self._loadingSavedListName
    local noAutoScan = type(options) == "table" and options.noAutoScan == true

    EnsureItemInfoLoaded(rows, function()
        S:StopScanAll()
        S:StopBuyAll()
        if S.ResetSearchOptions then S:ResetSearchOptions(true) end
        S._shoppingSessionSerial = (tonumber(S._shoppingSessionSerial) or 0) + 1
        local sessionSerial = S._shoppingSessionSerial
        S.activeSavedListID = loadID
        S.session.active = true
        S.session.scannedOnce = nil
        S.session.rows = rows
        S.session.skillLineID = skillLineID
        S.session.itemData = {}
        S.session.listName = loadName or T("PG_SHOP_LIST_TEMPORARY", "Temporary list")
        S.session.listKind = loadID and "saved" or "temporary"
        S.session.importSerial = sessionSerial
        S.pendingCommodityRow = nil
        S.pendingItemPurchases = {}
        S._loadingSavedListID = nil
        S._loadingSavedListName = nil
        if S.searchResults then
            S.searchResults.active = false
            S.searchResults.pending = false
            S.searchResults.query = ""
            S.searchResults.rows = {}
        end
        if S.SetShopTab then S:SetShopTab("buy") end
        S:ShowWindow()
        for _, delay in ipairs({ 0, 0.15, 0.45 }) do
            C_Timer.After(delay, function()
                if S.session.active and AuctionHouseFrame and S.ShowWindow then
                    S:ShowWindow()
                end
            end)
        end
        if S.isAuctionHouseOpen and not noAutoScan then
            C_Timer.After(0.1, function()
                if S.session.active and S.isAuctionHouseOpen then
                    S:ScanAllRows()
                end
            end)
        end
    end)

    return true
end

function S:BuildScanQueue()
    local seen = {}
    local queue = {}
    for _, row in ipairs(self:GetRows()) do
        if GetRemainingQuantity(row) > 0 then
            if row.itemID and not seen[row.itemID] then
                seen[row.itemID] = true
                table.insert(queue, row.itemID)
            end
            for _, opt in ipairs(row.options or {}) do
                if opt.itemID and not seen[opt.itemID] then
                    seen[opt.itemID] = true
                    table.insert(queue, opt.itemID)
                end
            end
        end
    end
    table.sort(queue)
    return queue
end

function S:RunScanAllStep(token)
    if not self.scanAllState.active then return end
    if token ~= self.scanAllState.token then return end
    if not self.session.active or not self.isAuctionHouseOpen then
        self:StopScanAll()
        return
    end
    self.scanAllState.pointer = (self.scanAllState.pointer or 0) + 1
    local itemID = self.scanAllState.queue and self.scanAllState.queue[self.scanAllState.pointer]
    if not itemID then
        self:StopScanAll()
        if ClearStalePendingSearches(false) then
            ResolveAllRows()
        end
        return
    end
    self:SearchItemID(itemID, true)
    if self.scanAllState.active and token == self.scanAllState.token then
        C_Timer.After(SEARCH_STEP_DELAY, function()
            S:RunScanAllStep(token)
        end)
    end
end

function S:ScanAllRows()
    if not self.session.active then return end
    if not self.isAuctionHouseOpen then
        RefreshWindow()
        return
    end
    if self.scanAllState.active then
        RefreshWindow()
        return true, "already_scanning"
    end
    if self.session then self.session.scannedOnce = true end
    self:StopBuyAll()

    local hasActiveExpansion = self.importResolveState and self.importResolveState.active
    if not hasActiveExpansion
       and self.ResolveUnresolvedSessionRowsByBrowse
       and self:ResolveUnresolvedSessionRowsByBrowse(function()
            if S.session and S.session.active and S.isAuctionHouseOpen then
                S:ScanAllRows()
            end
       end)
    then
        return
    end

    local queue = self:BuildScanQueue()
    if #queue == 0 then
        RefreshWindow()
        return
    end

    local now = GetClockSeconds()
    local sessionSerial = self.session and self.session.importSerial
    local scanKey = table.concat(queue, ",")

    if sessionSerial
       and self._lastScanAllSessionSerial == sessionSerial
       and self._lastScanAllKey == scanKey
       and (now - (tonumber(self._lastScanAllStartedAt) or 0)) < SCAN_ALL_DUPLICATE_WINDOW
    then
        RefreshWindow()
        return true, "recent_duplicate"
    end

    self._lastScanAllSessionSerial = sessionSerial
    self._lastScanAllKey = scanKey
    self._lastScanAllStartedAt = now

    self.scanAllState.active = true
    self.scanAllState.queue = queue
    self.scanAllState.pointer = 0
    self.scanAllState.token = (self.scanAllState.token or 0) + 1
    for _, row in ipairs(self:GetRows()) do
        if GetRemainingQuantity(row) > 0 then
            row.status = T("PG_SHOP_STATUS_QUEUED", "Queued")
            row.searchPending = false
            if row.options and #row.options > 0 then
                row.chosenItemID = nil
                row.chosenTier = nil
                row.minPrice = nil
                row.totalQuantity = nil
                row.isCommodity = nil
                row.bestAuctionID = nil
                row.bestAuctionQuantity = nil
                row.bestBuyoutAmount = nil
                row.lastChosenName = nil
            end
        end
    end
    RefreshWindow()
    self:RunScanAllStep(self.scanAllState.token)
end

function S:ScanRow(index)
    self:StopScanAll()
    self:StopBuyAll()
    local row = self.session.rows and self.session.rows[index]
    if not row then return end
    if row.itemID then
        self:SearchItemID(row.itemID)
    elseif row.unresolvedName or row.importName or row.label then
        if self.ResolveUnresolvedSessionRowsByBrowse
           and self:ResolveUnresolvedSessionRowsByBrowse(function()
                if S.session and S.session.active and S.isAuctionHouseOpen then
                    S:ScanAllRows()
                end
           end)
        then
            return
        end

        row.status = T("PG_SHOP_STATUS_NOT_SCANNED", "Not scanned")
        RefreshWindow()
    end
    for _, opt in ipairs(row.options or {}) do
        self:SearchItemID(opt.itemID, true)
    end
end

function S:SearchItemID(itemID, silent)
    if not itemID then return end
    local data = GetItemData(itemID)
    if not self.isAuctionHouseOpen then
        data.pending = false
        data.pendingSince = nil
        data.searched = false
        ResolveAllRows()
        return
    end
    local ok, itemKey = pcall(C_AuctionHouse.MakeItemKey, itemID)
    if not ok or not itemKey then
        data.pending = false
        data.pendingSince = nil
        data.searched = false
        ResolveAllRows()
        return
    end
    data.itemKey = itemKey
    data.pending = true
    data.pendingSince = GetTime and GetTime() or 0
    data.searched = false
    data.isCommodity = nil
    data.minPrice = nil
    data.totalQuantity = nil
    data.bestAuctionID = nil
    data.bestAuctionQuantity = nil
    data.bestBuyoutAmount = nil
    data.requestSerial = (data.requestSerial or 0) + 1
    local requestSerial = data.requestSerial
    if not silent then
        data.retryCount = 0
    end
    if not silent then
        local row = FindRowByItemID(itemID)
        if row then
            row.status = T("PG_SHOP_STATUS_SCANNING", "Scanning...")
        end
    end
    ResolveAllRows()
    local okQuery, err = pcall(C_AuctionHouse.SendSearchQuery, itemKey, BuildSorts(), true)
    if okQuery then
        C_Timer.After(SEARCH_PENDING_TIMEOUT, function()
            if not S.session.active then return end
            local live = S.session.itemData and S.session.itemData[itemID]
            if not live then return end
            if live.requestSerial ~= requestSerial then return end
            if not live.pending then return end
            if (live.retryCount or 0) < MAX_SEARCH_RETRIES and S.isAuctionHouseOpen then
                live.pending = false
                live.pendingSince = nil
                live.retryCount = (live.retryCount or 0) + 1
                C_Timer.After(0.2, function()
                    if S.session.active and S.isAuctionHouseOpen then
                        S:SearchItemID(itemID, true)
                    end
                end)
                return
            end
            live.pending = false
            live.pendingSince = nil
            live.searched = true
            if live.totalQuantity == nil then
                live.totalQuantity = 0
            end
            ResolveAllRows()
        end)
        return
    end
    data.pending = false
    data.pendingSince = nil
    data.searched = false
    local row = FindRowByItemID(itemID)
    if row then
        row.status = T("PG_SHOP_STATUS_SEARCH_ERROR", "Search error")
    end
    if err then
        print(T("PG_SHOP_ERR_SEARCH", "HironCraft: auction search error:"), err)
    end
    ResolveAllRows()
end

function S:BeginCommodityPurchase(row)
    if not row or not row.chosenItemID or GetRemainingQuantity(row) <= 0 then return end
    if not self.isAuctionHouseOpen then
        row.status = T("PG_SHOP_STATUS_OPEN_AH", "Open AH")
        RefreshWindow()
        return
    end
    local available = tonumber(row.totalQuantity) or 0
    if available <= 0 then
        row.status = T("PG_SHOP_STATUS_NO_ITEM", "No item")
        RefreshWindow()
        return
    end
    local quantity = math.min(GetRemainingQuantity(row), available)
    if quantity <= 0 then
        row.status = T("PG_SHOP_STATUS_NO_ITEM", "No item")
        RefreshWindow()
        return
    end
    if self.pendingCommodityRow and self.pendingCommodityRow ~= row and C_AuctionHouse and C_AuctionHouse.CancelCommoditiesPurchase then
        pcall(C_AuctionHouse.CancelCommoditiesPurchase)
        self.pendingCommodityRow.purchaseStage = nil
        self.pendingCommodityRow.pendingQuantity = nil
        self.pendingCommodityRow.pendingUnitPrice = nil
        self.pendingCommodityRow.pendingTotalPrice = nil
    end
    self.pendingCommodityRow = row
    row.pendingQuantity = quantity
    row.pendingUnitPrice = nil
    row.pendingTotalPrice = nil
    row.purchaseStage = "await_price"
    row.purchaseStageStartedAt = GetTime and GetTime() or 0
    row.status = T("PG_SHOP_STATUS_REQUESTING_PRICE", "Requesting price")
    RefreshWindow()
    local ok, err = pcall(C_AuctionHouse.StartCommoditiesPurchase, row.chosenItemID, quantity)
    if not ok then
        row.purchaseStage = nil
        row.pendingQuantity = nil
        row.status = T("PG_SHOP_STATUS_BUY_ERROR", "Purchase error")
        self.pendingCommodityRow = nil
        if err then
            print(T("PG_SHOP_ERR_START_BUY", "HironCraft: start purchase error:"), err)
        end
        RefreshWindow()
    end
end

function S:ConfirmCommodityPurchase(row)
    if not row or row.purchaseStage ~= "confirm" or not row.pendingQuantity or row.pendingQuantity <= 0 then
        return
    end
    row.purchaseStage = "processing"
    row.purchaseStageStartedAt = GetTime and GetTime() or 0
    row.status = T("PG_SHOP_STATUS_BUYING", "Buying...")
    RefreshWindow()
    local ok, err = pcall(C_AuctionHouse.ConfirmCommoditiesPurchase, row.chosenItemID, row.pendingQuantity)
    if not ok then
        row.purchaseStage = nil
        row.status = T("PG_SHOP_STATUS_CONFIRM_ERROR", "Confirmation error")
        if err then
            print(T("PG_SHOP_ERR_CONFIRM_BUY", "HironCraft: purchase confirmation error:"), err)
        end
        RefreshWindow()
    end
end

function S:BuyItemAuction(row)
    if not row or GetRemainingQuantity(row) <= 0 then return end
    if not row.bestAuctionID or not row.bestBuyoutAmount then
        row.status = T("PG_SHOP_STATUS_NO_BUYOUT", "No buyout")
        RefreshWindow()
        return
    end
    local purchaseQuantity = row.bestAuctionQuantity or 1
    row.purchaseStage = "processing"
    row.purchaseStageStartedAt = GetTime and GetTime() or 0
    row.status = T("PG_SHOP_STATUS_BUYING_AUCTION", "Buying auction")
    self.pendingItemPurchases[row.bestAuctionID] = {
        auctionID = row.bestAuctionID,
        rowIndex = row.index,
        quantity = purchaseQuantity,
        itemID = row.chosenItemID,
        totalPrice = row.bestBuyoutAmount,
    }
    RefreshWindow()
    local ok, err = pcall(C_AuctionHouse.PlaceBid, row.bestAuctionID, row.bestBuyoutAmount)
    if not ok then
        self.pendingItemPurchases[row.bestAuctionID] = nil
        row.purchaseStage = nil
        row.status = T("PG_SHOP_STATUS_BUY_ERROR", "Purchase error")
        if err then
            print(T("PG_SHOP_ERR_BUY_AUCTION", "HironCraft: auction purchase error:"), err)
        end
        RefreshWindow()
    end
end

function S:BeginSearchCommodityPurchase(row, quantity)
    if not row or not row.itemID then return false, "missing_item" end
    if not self.isAuctionHouseOpen then
        row.status = T("PG_SHOP_STATUS_OPEN_AH", "Open AH")
        RefreshShoppingWindow()
        return false, "auction_house_closed"
    end

    quantity = math.floor(tonumber(quantity) or tonumber(row.quantity) or 1)
    if quantity <= 0 then quantity = 1 end

    local available = tonumber(row.totalQuantity) or 0
    if available > 0 and quantity > available then
        quantity = available
    end

    if quantity <= 0 then
        row.status = T("PG_SHOP_STATUS_NO_ITEM", "No item")
        RefreshShoppingWindow()
        return false, "no_quantity"
    end

    if self.pendingCommodityRow and C_AuctionHouse and C_AuctionHouse.CancelCommoditiesPurchase then
        pcall(C_AuctionHouse.CancelCommoditiesPurchase)
        self.pendingCommodityRow.purchaseStage = nil
        self.pendingCommodityRow.pendingQuantity = nil
        self.pendingCommodityRow.pendingUnitPrice = nil
        self.pendingCommodityRow.pendingTotalPrice = nil
        self.pendingCommodityRow = nil
    end

    if self.pendingSearchCommodityRow and self.pendingSearchCommodityRow ~= row and C_AuctionHouse and C_AuctionHouse.CancelCommoditiesPurchase then
        pcall(C_AuctionHouse.CancelCommoditiesPurchase)
        self.pendingSearchCommodityRow.purchaseStage = nil
        self.pendingSearchCommodityRow.pendingQuantity = nil
        self.pendingSearchCommodityRow.pendingUnitPrice = nil
        self.pendingSearchCommodityRow.pendingTotalPrice = nil
    end

    self.pendingSearchCommodityRow = row
    row.quantity = quantity
    row.remainingQuantity = quantity
    row.pendingQuantity = quantity
    row.pendingUnitPrice = nil
    row.pendingTotalPrice = nil
    row.purchaseStage = "await_price"
    row.purchaseStageStartedAt = GetTime and GetTime() or 0
    row.status = T("PG_SHOP_STATUS_REQUESTING_PRICE", "Requesting price")
    RefreshShoppingWindow()

    local ok, err = pcall(C_AuctionHouse.StartCommoditiesPurchase, row.itemID, quantity)
    if not ok then
        row.purchaseStage = nil
        row.pendingQuantity = nil
        row.status = T("PG_SHOP_STATUS_BUY_ERROR", "Purchase error")
        self.pendingSearchCommodityRow = nil
        if err then
            print(T("PG_SHOP_ERR_START_BUY", "HironCraft: start purchase error:"), err)
        end
        RefreshShoppingWindow()
        return false, err
    end

    return true
end

function S:ConfirmSearchCommodityPurchase(row)
    if not row or row.purchaseStage ~= "confirm" or not row.pendingQuantity or row.pendingQuantity <= 0 then
        return false, "not_ready"
    end

    row.purchaseStage = "processing"
    row.purchaseStageStartedAt = GetTime and GetTime() or 0
    row.status = T("PG_SHOP_STATUS_BUYING", "Buying...")
    RefreshShoppingWindow()

    local ok, err = pcall(C_AuctionHouse.ConfirmCommoditiesPurchase, row.itemID, row.pendingQuantity)
    if not ok then
        row.purchaseStage = nil
        row.status = T("PG_SHOP_STATUS_CONFIRM_ERROR", "Confirmation error")
        if err then
            print(T("PG_SHOP_ERR_CONFIRM_BUY", "HironCraft: purchase confirmation error:"), err)
        end
        RefreshShoppingWindow()
        return false, err
    end

    return true
end

function S:BuySearchItemAuction(row)
    if not row or not row.bestAuctionID or not row.bestBuyoutAmount then
        if row then
            row.status = T("PG_SHOP_STATUS_NO_BUYOUT", "No buyout")
            RefreshShoppingWindow()
        end
        return false, "no_buyout"
    end

    local purchaseQuantity = row.bestAuctionQuantity or 1
    row.purchaseStage = "processing"
    row.purchaseStageStartedAt = GetTime and GetTime() or 0
    row.status = T("PG_SHOP_STATUS_BUYING_AUCTION", "Buying auction")
    self.pendingSearchItemPurchases[row.bestAuctionID] = {
        auctionID = row.bestAuctionID,
        searchRow = row,
        quantity = purchaseQuantity,
        itemID = row.itemID,
        totalPrice = row.bestBuyoutAmount,
    }
    RefreshShoppingWindow()

    local ok, err = pcall(C_AuctionHouse.PlaceBid, row.bestAuctionID, row.bestBuyoutAmount)
    if not ok then
        self.pendingSearchItemPurchases[row.bestAuctionID] = nil
        row.purchaseStage = nil
        row.status = T("PG_SHOP_STATUS_BUY_ERROR", "Purchase error")
        if err then
            print(T("PG_SHOP_ERR_BUY_AUCTION", "HironCraft: auction purchase error:"), err)
        end
        RefreshShoppingWindow()
        return false, err
    end

    return true
end

function S:RequestSearchItemAuction(row)
    if not row or not row.itemID then return false, "missing_item" end
    if not self.isAuctionHouseOpen then
        row.status = T("PG_SHOP_STATUS_OPEN_AH", "Open AH")
        RefreshShoppingWindow()
        return false, "auction_house_closed"
    end

    local itemKey = row.itemKey
    if not itemKey and C_AuctionHouse and C_AuctionHouse.MakeItemKey then
        local okKey, madeKey = pcall(C_AuctionHouse.MakeItemKey, row.itemID)
        if okKey then
            itemKey = madeKey
            row.itemKey = madeKey
        end
    end

    if not itemKey then
        row.status = T("PG_SHOP_STATUS_SEARCH_ERROR", "Search error")
        RefreshShoppingWindow()
        return false, "missing_item_key"
    end

    row.isCommodity = false
    row.searchPending = true
    row.directPurchaseSearchPending = true
    row.purchaseStage = "await_search"
    row.purchaseStageStartedAt = GetTime and GetTime() or 0
    row.status = T("PG_SHOP_STATUS_SCANNING", "Scanning...")
    RefreshShoppingWindow()

    local okQuery, err = pcall(C_AuctionHouse.SendSearchQuery, itemKey, BuildSorts(), true)
    if not okQuery then
        row.searchPending = false
        row.directPurchaseSearchPending = false
        row.purchaseStage = nil
        row.status = T("PG_SHOP_STATUS_SEARCH_ERROR", "Search error")
        if err then
            print(T("PG_SHOP_ERR_SEARCH", "HironCraft: auction search error:"), err)
        end
        RefreshShoppingWindow()
        return false, err
    end

    C_Timer.After(SEARCH_PENDING_TIMEOUT, function()
        if row and row.directPurchaseSearchPending then
            row.searchPending = false
            row.directPurchaseSearchPending = false
            row.purchaseStage = nil
            row.status = T("PG_SHOP_STATUS_NO_ITEM", "No item")
            RefreshShoppingWindow()
        end
    end)

    return true
end

function S:BuySearchResultRow(row, quantity)
    if not row or not row.itemID then
        return false, "missing_search_row"
    end

    if GetRemainingQuantity(row) <= 0 then
        row.status = T("PG_SHOP_STATUS_BOUGHT", "Bought")
        RefreshShoppingWindow()
        return false, "already_bought"
    end

    if row.purchaseStage == "confirm" then
        return self:ConfirmSearchCommodityPurchase(row)
    end

    if row.purchaseStage == "await_price" or row.purchaseStage == "processing" or row.searchPending then
        RefreshShoppingWindow()
        return false, "busy"
    end

    if row.isCommodity == true then
        return self:BeginSearchCommodityPurchase(row, quantity)
    end

    if row.bestAuctionID and row.bestBuyoutAmount then
        return self:BuySearchItemAuction(row)
    end

    return self:RequestSearchItemAuction(row)
end

function S:BuySearchResult(itemID, quantity, label)
    local row = FindSearchResultRowByItemID(tonumber(itemID))
    if row then
        return self:BuySearchResultRow(row, quantity)
    end
    return false, "missing_search_row"
end

function S:BuyRow(index)
    self:StopScanAll()
    local row = self.session.rows and self.session.rows[index]
    if not row then return end
    if GetRemainingQuantity(row) <= 0 then
        row.status = T("PG_SHOP_STATUS_BOUGHT", "Bought")
        RefreshWindow()
        return
    end
    if not self.isAuctionHouseOpen then
        row.status = T("PG_SHOP_STATUS_OPEN_AH", "Open AH")
        RefreshWindow()
        return
    end
    if row.searchPending then
        row.status = T("PG_SHOP_STATUS_WAIT_SCAN", "Wait for scan")
        RefreshWindow()
        return
    end
    if row.purchaseStage == "await_price" or row.purchaseStage == "processing" then
        RefreshWindow()
        return
    end
    if row.purchaseStage == "confirm" then
        self:ConfirmCommodityPurchase(row)
        return
    end
    if not row.chosenItemID then
        row.status = T("PG_SHOP_STATUS_SCAN_FIRST", "Scan first")
        RefreshWindow()
        return
    end
    if row.isCommodity == true then
        self:BeginCommodityPurchase(row)
        return
    end
    if row.bestAuctionID and row.bestBuyoutAmount then
        self:BuyItemAuction(row)
        return
    end
    self:SearchItemID(row.chosenItemID)
end

function S:BuildBuyAllOrder()
    local order = {}
    for index, row in ipairs(self:GetRows()) do
        if IsRowBuyableNow(row) then
            table.insert(order, index)
        end
    end
    return order
end

SHOPPING_HOTKEY_PROXY_NAME = "HironCraftProfitShoppingListHotkeyProxy"
SHOPPING_SKIP_PROXY_NAME = "HironCraftProfitShoppingListSkipProxy"
SHOPPING_REFRESH_PROXY_NAME = "HironCraftProfitShoppingListRefreshProxy"

function S:GetShoppingBindingDB()
    _G.HironCraftProfit_DB = _G.HironCraftProfit_DB or {}
    _G.HironCraftProfit_DB.shoppingList = _G.HironCraftProfit_DB.shoppingList or {}
    return _G.HironCraftProfit_DB.shoppingList
end

function S:GetShoppingBinding()
    local db = self:GetShoppingBindingDB()
    return db.binding
end

function S:GetShoppingSkipBinding()
    local db = self:GetShoppingBindingDB()
    return db.skipBinding
end

function S:SetShoppingSkipBinding(binding)
    local db = self:GetShoppingBindingDB()
    db.skipBinding = binding
    self:ApplyShoppingBinding()
end

function S:ClearShoppingSkipBinding()
    local db = self:GetShoppingBindingDB()
    db.skipBinding = nil
    self:ApplyShoppingBinding()
end

function S:GetShoppingRefreshBinding()
    local db = self:GetShoppingBindingDB()
    return db.refreshBinding
end

function S:SetShoppingRefreshBinding(binding)
    local db = self:GetShoppingBindingDB()
    db.refreshBinding = binding
    self:ApplyShoppingBinding()
end

function S:ClearShoppingRefreshBinding()
    local db = self:GetShoppingBindingDB()
    db.refreshBinding = nil
    self:ApplyShoppingBinding()
end

function S:GetNextBuyableRowIndex()
    local sessionRows = self.session and self.session.rows
    if not sessionRows then return nil end

    local displayRows
    if S._Private and S._Private.GetSortedVisibleRows then
        local ok, value = pcall(S._Private.GetSortedVisibleRows)
        if ok and type(value) == "table" then displayRows = value end
    end
    if not displayRows then displayRows = sessionRows end

    local targetRow
    for _, row in ipairs(displayRows) do
        if not row.hidden and not row.skipped and row.purchaseStage == "confirm" then
            targetRow = row
            break
        end
    end
    if not targetRow then
        for _, row in ipairs(displayRows) do
            if not row.hidden and not row.skipped and IsRowBuyableNow(row) then
                targetRow = row
                break
            end
        end
    end
    if not targetRow then return nil end

    for index, row in ipairs(sessionRows) do
        if row == targetRow then return index end
    end
    return nil
end

function S:RunHotkeyAction()
    if not self.isAuctionHouseOpen then
        return
    end
    local now = GetTime and GetTime() or 0
    if self._lastHotkeyBuyTime and (now - self._lastHotkeyBuyTime) < 0.3 then
        return
    end
    local idx = self:GetNextBuyableRowIndex()
    if not idx then return end
    self._lastHotkeyBuyTime = now
    self:BuyRow(idx)
end

function S:RunHotkeySkipAction()
    local idx = self:GetNextBuyableRowIndex()
    if not idx then return end
    local row = self.session and self.session.rows and self.session.rows[idx]
    if not row then return end
    row.skipped = true
    if RefreshWindow then RefreshWindow() end
end

function S:ClearAllSkips()
    local rows = self.session and self.session.rows
    if not rows then return end
    for _, row in ipairs(rows) do
        row.skipped = nil
    end
    if RefreshWindow then RefreshWindow() end
end

function S:CreateHotkeyProxy()
    if self.hotkeyProxy then return self.hotkeyProxy end

    local proxy = CreateFrame("Button", SHOPPING_HOTKEY_PROXY_NAME, UIParent)
    proxy:RegisterForClicks("LeftButtonUp")
    proxy:SetScript("OnClick", function()
        if S.RunHotkeyAction then S:RunHotkeyAction() end
    end)
    proxy:Hide()

    self.hotkeyProxy = proxy
    return proxy
end

function S:CreateSkipHotkeyProxy()
    if self.skipHotkeyProxy then return self.skipHotkeyProxy end

    local proxy = CreateFrame("Button", SHOPPING_SKIP_PROXY_NAME, UIParent)
    proxy:RegisterForClicks("LeftButtonUp")
    proxy:SetScript("OnClick", function()
        if S.RunHotkeySkipAction then S:RunHotkeySkipAction() end
    end)
    proxy:Hide()

    self.skipHotkeyProxy = proxy
    return proxy
end

function S:RunHotkeyRefreshAction()
    if self.RefreshPrices then
        self:RefreshPrices()
    elseif self.ResetPrices then
        self:ResetPrices()
    end
end

function S:CreateRefreshHotkeyProxy()
    if self.refreshHotkeyProxy then return self.refreshHotkeyProxy end

    local proxy = CreateFrame("Button", SHOPPING_REFRESH_PROXY_NAME, UIParent)
    proxy:RegisterForClicks("LeftButtonUp")
    proxy:SetScript("OnClick", function()
        if S.RunHotkeyRefreshAction then S:RunHotkeyRefreshAction() end
    end)
    proxy:Hide()

    self.refreshHotkeyProxy = proxy
    return proxy
end

function S:GetShoppingBindingOwner()
    if self.frame and self.frame:IsShown() then
        return self.frame
    end
    return nil
end

function S:ApplyShoppingBinding()
    local proxy = self:CreateHotkeyProxy()
    local skipProxy = self:CreateSkipHotkeyProxy()
    local refreshProxy = self:CreateRefreshHotkeyProxy()
    if InCombatLockdown() then
        self.pendingBindingRefresh = true
        return false
    end

    ClearOverrideBindings(proxy)
    ClearOverrideBindings(skipProxy)
    ClearOverrideBindings(refreshProxy)
    if self.shoppingBindingOwner then
        ClearOverrideBindings(self.shoppingBindingOwner)
        self.shoppingBindingOwner = nil
    end

    local owner = self:GetShoppingBindingOwner()
    if owner then
        local buyBinding = self:GetShoppingBinding()
        local skipBinding = self:GetShoppingSkipBinding()
        local refreshBinding = self:GetShoppingRefreshBinding()
        local bound = false
        if buyBinding and buyBinding ~= "" then
            SetOverrideBindingClick(owner, false, buyBinding, SHOPPING_HOTKEY_PROXY_NAME, "LeftButton")
            bound = true
        end
        if skipBinding and skipBinding ~= "" then
            SetOverrideBindingClick(owner, false, skipBinding, SHOPPING_SKIP_PROXY_NAME, "LeftButton")
            bound = true
        end
        if refreshBinding and refreshBinding ~= "" then
            SetOverrideBindingClick(owner, false, refreshBinding, SHOPPING_REFRESH_PROXY_NAME, "LeftButton")
            bound = true
        end
        if bound then
            self.shoppingBindingOwner = owner
        end
    end

    self.pendingBindingRefresh = false
    return true
end

function S:ClearShoppingTemporaryBinding()
    if InCombatLockdown() then
        self.pendingBindingRefresh = true
        return false
    end
    if self.shoppingBindingOwner then
        ClearOverrideBindings(self.shoppingBindingOwner)
        self.shoppingBindingOwner = nil
    end
    if self.hotkeyProxy then
        ClearOverrideBindings(self.hotkeyProxy)
    end
    if self.skipHotkeyProxy then
        ClearOverrideBindings(self.skipHotkeyProxy)
    end
    if self.refreshHotkeyProxy then
        ClearOverrideBindings(self.refreshHotkeyProxy)
    end
    return true
end

function S:SetShoppingBinding(binding)
    local db = self:GetShoppingBindingDB()
    db.binding = binding
    self:ApplyShoppingBinding()
end

function S:ClearShoppingBinding()
    local db = self:GetShoppingBindingDB()
    db.binding = nil
    self:ApplyShoppingBinding()
end

function S:HandleBuyAllClick()
    self:StopBuyAll()
    RefreshWindow()
end

function S:AdvanceBuyAll()
    if not self.buyAllState.active then return end
    if not self.isAuctionHouseOpen then
        self:StopBuyAll()
        return
    end
    local rows = self:GetRows()
    local currentIndex = self.buyAllState.currentRowIndex
    local currentRow = currentIndex and rows[currentIndex] or nil
    if currentRow then
        if currentRow.purchaseStage == "confirm" then
            self:ConfirmCommodityPurchase(currentRow)
            return
        end
        if currentRow.purchaseStage == "await_price" or currentRow.purchaseStage == "processing" or currentRow.searchPending then
            RefreshWindow()
            return
        end
        if GetRemainingQuantity(currentRow) <= 0 or not IsRowBuyableNow(currentRow) then
            self.buyAllState.pointer = (self.buyAllState.pointer or 1) + 1
            self.buyAllState.currentRowIndex = nil
            currentRow = nil
        elseif currentRow.chosenItemID and currentRow.minPrice then
            self:BuyRow(currentIndex)
            if currentRow.purchaseStage == "confirm" or currentRow.purchaseStage == "await_price" or currentRow.purchaseStage == "processing" or currentRow.searchPending then
                return
            end
            if GetRemainingQuantity(currentRow) <= 0 or not IsRowBuyableNow(currentRow) then
                self.buyAllState.pointer = (self.buyAllState.pointer or 1) + 1
                self.buyAllState.currentRowIndex = nil
            end
            RefreshWindow()
            return
        else
            self.buyAllState.pointer = (self.buyAllState.pointer or 1) + 1
            self.buyAllState.currentRowIndex = nil
        end
    end
    while self.buyAllState.active do
        local idx = self.buyAllState.order and self.buyAllState.order[self.buyAllState.pointer]
        if not idx then
            self:StopBuyAll()
            return
        end
        local row = rows[idx]
        if row and IsRowBuyableNow(row) then
            self.buyAllState.currentRowIndex = idx
            self:BuyRow(idx)
            return
        end
        self.buyAllState.pointer = (self.buyAllState.pointer or 1) + 1
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
eventFrame:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
eventFrame:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
eventFrame:RegisterEvent("AUCTION_HOUSE_BROWSE_FAILURE")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
eventFrame:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
eventFrame:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
eventFrame:RegisterEvent("COMMODITY_PRICE_UPDATED")
eventFrame:RegisterEvent("COMMODITY_PRICE_UNAVAILABLE")
eventFrame:RegisterEvent("COMMODITY_PURCHASED")
eventFrame:RegisterEvent("COMMODITY_PURCHASE_SUCCEEDED")
eventFrame:RegisterEvent("COMMODITY_PURCHASE_FAILED")
eventFrame:RegisterEvent("AUCTION_HOUSE_PURCHASE_COMPLETED")
eventFrame:RegisterEvent("UI_ERROR_MESSAGE")
eventFrame:RegisterEvent("PLAYER_LOGIN")

S:CleanupTemporaryLists()

function IsNotEnoughMoneyError(errorType, message)
    if tonumber(errorType) == 49 then return true end
    if _G.LE_GAME_ERR_NOT_ENOUGH_MONEY and tonumber(errorType) == _G.LE_GAME_ERR_NOT_ENOUGH_MONEY then return true end
    if message and _G.ERR_NOT_ENOUGH_MONEY and message == _G.ERR_NOT_ENOUGH_MONEY then return true end
    return false
end

function ResetStuckPurchaseState(reasonText)
    local affected = false
    local resetItemIDs = {}

    if (S.pendingCommodityRow or S.pendingSearchCommodityRow)
       and C_AuctionHouse and C_AuctionHouse.CancelCommoditiesPurchase
    then
        pcall(C_AuctionHouse.CancelCommoditiesPurchase)
    end

    if S.session and S.session.rows then
        for _, row in ipairs(S.session.rows) do
            if row.purchaseStage == "await_price"
            or row.purchaseStage == "processing"
            or row.purchaseStage == "confirm"
            or row.purchaseStage == "await_search"
            or row.searchPending then
                row.purchaseStage = nil
                row.purchaseStageStartedAt = nil
                row.searchPending = false
                row.directPurchaseSearchPending = false
                row.pendingQuantity = nil
                row.pendingUnitPrice = nil
                row.pendingTotalPrice = nil
                row.status = reasonText or T("PG_SHOP_STATUS_PURCHASE_FAILED", "Purchase failed")
                affected = true
                if row.itemID then
                    resetItemIDs[#resetItemIDs + 1] = row.itemID
                end
            end
        end
    end

    if S.pendingCommodityRow then
        S.pendingCommodityRow = nil
        affected = true
    end
    if S.pendingSearchCommodityRow then
        S.pendingSearchCommodityRow = nil
        affected = true
    end

    if S.session and S.session.itemData then
        for _, data in pairs(S.session.itemData) do
            if data.pending then
                data.pending = false
                data.pendingSince = nil
            end
        end
    end

    if affected and RefreshWindow then
        RefreshWindow()
    end

    if #resetItemIDs > 0 then
        for _, itemID in ipairs(resetItemIDs) do
            if type(S.SearchItemID) == "function" then
                S:SearchItemID(itemID, false)
            end
        end
    end
end

PURCHASE_STUCK_TIMEOUT = 3
if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(1, function()
        if not S.session or not S.session.active then return end
        if not S.isAuctionHouseOpen then return end

        local now = GetTime and GetTime() or 0
        if now == 0 then return end

        local stuck = false
        for _, row in ipairs(S.session.rows or {}) do
            if (row.purchaseStage == "await_price"
                or row.purchaseStage == "processing"
                or row.purchaseStage == "await_search")
               and row.purchaseStageStartedAt
               and (now - row.purchaseStageStartedAt) > PURCHASE_STUCK_TIMEOUT
            then
                stuck = true
                break
            end
        end

        if stuck then
            ResetStuckPurchaseState(T("PG_SHOP_STATUS_PURCHASE_TIMEOUT", "Purchase timed out"))
        end
    end)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        S:CleanupTemporaryLists()
        return
    end

    if event == "ADDON_LOADED" then
        local addonName = ...

        if addonName == "Auctionator" then
            if S.IsAuctionatorPlanMirrorEnabled
               and S:IsAuctionatorPlanMirrorEnabled()
               and S.EnsureAuctionatorPlanMirror
            then
                C_Timer.After(0, function()
                    if S.IsAuctionatorPlanMirrorEnabled
                       and S:IsAuctionatorPlanMirrorEnabled()
                       and S.EnsureAuctionatorPlanMirror
                    then
                        S:EnsureAuctionatorPlanMirror()
                    end
                end)
            end
        end

        return
    end

    if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        local panelType = ...
        if panelType == Enum.PlayerInteractionType.Auctioneer then
            C_Timer.After(0, function()
                local tabLib = GetLibAHTab()
                if not tabLib or not AuctionHouseFrame then return end
                if ShouldShowAuctionTab() then
                    S.isAuctionHouseOpen = true
                    S:EnsureAuctionTab()
                    UpdateAuctionTabVisibility()
                    if HasShoppingSession() then
                        S:ShowWindow()
                        if tabLib:DoesIDExist(AH_TAB_ID) then
                            tabLib:SetSelected(AH_TAB_ID)
                        end
                    end
                else
                    UpdateAuctionTabVisibility()
                end
            end)
        end
        return
    end

    if event == "AUCTION_HOUSE_SHOW" then
        S.isAuctionHouseOpen = true
        C_Timer.After(0, function()
            if ShouldShowAuctionTab() then
                S:EnsureAuctionTab()
                UpdateAuctionTabVisibility()
                if HasShoppingSession() then
                    S:ShowWindow()
                    local tabLib = GetLibAHTab()
                    if tabLib and tabLib:DoesIDExist(AH_TAB_ID) then
                        tabLib:SetSelected(AH_TAB_ID)
                    end
                end
            else
                UpdateAuctionTabVisibility()
            end
        end)
        if S.OnAuctionStateChanged then
            S:OnAuctionStateChanged(true)
        end
        if S.session and S.session.active and not S.session.scannedOnce and ScheduleTemporaryAuctionatorPlanScan then
            ScheduleTemporaryAuctionatorPlanScan(S.session.importSerial)
        end
        RefreshWindow()
        return
    end

    if event == "AUCTION_HOUSE_CLOSED" then
        S.isAuctionHouseOpen = false
        S:StopScanAll()
        S:StopBuyAll()
        S.pendingCommodityRow = nil
        S.pendingSearchCommodityRow = nil
        S.pendingItemPurchases = {}
        S.pendingSearchItemPurchases = {}
        S.importResolveState = nil
        S.directSearchBuy = nil
        S._auctionatorPlanMirrorActiveKey = nil
        if S.ClearSearchText then S:ClearSearchText(true) end
        if S.ResetSearchOptions then S:ResetSearchOptions(true) end
        if S.searchResults then
            S.searchResults.active = false
            S.searchResults.pending = false
            S.searchResults.query = ""
            S.searchResults.rows = {}
        end
        if S.OnAuctionStateChanged then
            S:OnAuctionStateChanged(false)
        end
        RefreshWindow()
        return
    end

    if event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
        if S.importResolveState and S.importResolveState.active and S.importResolveState.current then
            S:ApplyImportBrowseResults()
            return
        end
        if S.searchResults and S.searchResults.active then
            S:ApplyBrowseSearchResults()
        end
        return
    end

    if event == "AUCTION_HOUSE_BROWSE_FAILURE" then
        if S.searchResults and S.searchResults.active then
            S.searchResults.pending = false
            S.searchResults.lastError = T("PG_SHOP_STATUS_SEARCH_ERROR", "Search error")
            RefreshShoppingWindow()
        end
        return
    end

    if event == "GET_ITEM_INFO_RECEIVED" then
        local itemID, success = ...
        local changedSearchName = false
        if success then
            changedSearchName = RefreshSearchResultNames(itemID)
        elseif itemID then
            RequestItemData(itemID)
        end
        local liveRow = S.session.active and FindRowByItemID(itemID)
        if liveRow then
            if IsPlaceholderItemLabel(liveRow.label, itemID) then
                liveRow.label = GetItemInfo(itemID)
            end
            ResolveAllRows()
        elseif changedSearchName then
            RefreshWindow()
        end
        return
    end

    local hasSession = S.session and S.session.active

    if event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        local itemID = ...
        if hasSession then
            ApplyCommodityResults(itemID)
        end
        return
    end

    if event == "ITEM_SEARCH_RESULTS_UPDATED" then
        local itemKey = ...
        if type(itemKey) == "table" and itemKey.itemID then
            local handledSearch = ApplySearchItemResults(itemKey)
            if hasSession then
                ApplyItemResults(itemKey)
            elseif handledSearch then
                RefreshShoppingWindow()
            end
        end
        return
    end

    if event == "COMMODITY_PRICE_UPDATED" then
        local updatedUnitPrice, updatedTotalPrice = ...
        local searchRow = S.pendingSearchCommodityRow
        if searchRow and searchRow.purchaseStage == "await_price" then
            searchRow.pendingUnitPrice = updatedUnitPrice
            searchRow.pendingTotalPrice = updatedTotalPrice
            searchRow.purchaseStage = "confirm"
            searchRow.status = string.format(T("PG_SHOP_STATUS_CONFIRM_PRICE", "Confirm %s"), FormatMoneyText(updatedTotalPrice))
            RefreshShoppingWindow()
            return
        end

        if not hasSession then
            return
        end

        local row = S.pendingCommodityRow
        if row and row.purchaseStage == "await_price" then
            row.pendingUnitPrice = updatedUnitPrice
            row.pendingTotalPrice = updatedTotalPrice
            row.purchaseStage = "confirm"
            row.status = string.format(T("PG_SHOP_STATUS_CONFIRM_PRICE", "Confirm %s"), FormatMoneyText(updatedTotalPrice))
            RefreshWindow()
        end
        return
    end

    if event == "COMMODITY_PRICE_UNAVAILABLE" then
        local searchRow = S.pendingSearchCommodityRow
        if searchRow then
            searchRow.purchaseStage = nil
            searchRow.pendingQuantity = nil
            searchRow.pendingUnitPrice = nil
            searchRow.pendingTotalPrice = nil
            searchRow.status = T("PG_SHOP_STATUS_PRICE_UNAVAILABLE", "Price unavailable")
            S.pendingSearchCommodityRow = nil
            RefreshShoppingWindow()
            return
        end

        if not hasSession then
            return
        end

        local row = S.pendingCommodityRow
        if row then
            row.purchaseStage = nil
            row.pendingQuantity = nil
            row.pendingUnitPrice = nil
            row.pendingTotalPrice = nil
            row.status = T("PG_SHOP_STATUS_PRICE_UNAVAILABLE", "Price unavailable")
            S.pendingCommodityRow = nil
            RefreshWindow()
        end
        return
    end

    if event == "COMMODITY_PURCHASE_SUCCEEDED" then
        local searchRow = S.pendingSearchCommodityRow
        if searchRow then
            local boughtQty = searchRow.pendingQuantity or GetRemainingQuantity(searchRow)
            AnnouncePurchase(searchRow.itemID, boughtQty, searchRow.pendingTotalPrice)
            MarkSearchRowPurchased(searchRow, boughtQty and boughtQty > 0 and string.format(T("PG_SHOP_STATUS_BOUGHT_QTY", "Bought %d"), boughtQty) or T("PG_SHOP_STATUS_BOUGHT", "Bought"))
            S.pendingSearchCommodityRow = nil
            RefreshShoppingWindow()
            return
        end

        if not hasSession then
            return
        end

        local row = S.pendingCommodityRow
        if row then
            local boughtQty = row.pendingQuantity or GetRemainingQuantity(row)
            AnnouncePurchase(row.chosenItemID or row.itemID, boughtQty, row.pendingTotalPrice)
            MarkRowPurchased(row, boughtQty and boughtQty > 0 and string.format(T("PG_SHOP_STATUS_BOUGHT_QTY", "Bought %d"), boughtQty) or T("PG_SHOP_STATUS_BOUGHT", "Bought"))
            S.pendingCommodityRow = nil
            if S.buyAllState.active and S.buyAllState.currentRowIndex == row.index then
                S.buyAllState.pointer = (S.buyAllState.pointer or 1) + 1
                S.buyAllState.currentRowIndex = nil
            end
            RefreshWindow()
        end
        return
    end

    if event == "COMMODITY_PURCHASED" then
        local itemID, quantity = ...
        local searchRow = S.pendingSearchCommodityRow
        if searchRow and (not itemID or searchRow.itemID == itemID) then
            MarkSearchRowPurchased(searchRow, quantity and quantity > 0 and string.format(T("PG_SHOP_STATUS_BOUGHT_QTY", "Bought %d"), quantity) or T("PG_SHOP_STATUS_BOUGHT", "Bought"))
            S.pendingSearchCommodityRow = nil
            RefreshShoppingWindow()
            return
        end

        if not hasSession then
            return
        end

        local row = S.pendingCommodityRow
        if not row or (itemID and row.chosenItemID ~= itemID) then
            row = FindRowByItemID(itemID)
        end
        if row then
            MarkRowPurchased(row, quantity and quantity > 0 and string.format(T("PG_SHOP_STATUS_BOUGHT_QTY", "Bought %d"), quantity) or T("PG_SHOP_STATUS_BOUGHT", "Bought"))
            if S.pendingCommodityRow == row then
                S.pendingCommodityRow = nil
            end
            if S.buyAllState.active and S.buyAllState.currentRowIndex == row.index then
                S.buyAllState.pointer = (S.buyAllState.pointer or 1) + 1
                S.buyAllState.currentRowIndex = nil
            end
            RefreshWindow()
        end
        return
    end

    if event == "UI_ERROR_MESSAGE" then
        local errorType, message = ...

        local hasPending = (S.pendingCommodityRow ~= nil) or (S.pendingSearchCommodityRow ~= nil)
        if not hasPending and S.session and S.session.rows then
            for _, row in ipairs(S.session.rows) do
                if row.purchaseStage == "await_price"
                or row.purchaseStage == "processing"
                or row.purchaseStage == "confirm"
                or row.purchaseStage == "await_search" then
                    hasPending = true
                    break
                end
            end
        end

        if hasPending then
            local reason
            if IsNotEnoughMoneyError(errorType, message) then
                reason = T("PG_SHOP_STATUS_NO_MONEY", "Not enough gold")
            else
                reason = T("PG_SHOP_STATUS_PURCHASE_FAILED", "Purchase failed")
            end
            ResetStuckPurchaseState(reason)
        end
        return
    end

    if event == "COMMODITY_PURCHASE_FAILED" then
        local searchRow = S.pendingSearchCommodityRow
        if searchRow then
            searchRow.purchaseStage = nil
            searchRow.pendingQuantity = nil
            searchRow.pendingUnitPrice = nil
            searchRow.pendingTotalPrice = nil
            searchRow.status = T("PG_SHOP_STATUS_PURCHASE_FAILED", "Purchase failed")
            S.pendingSearchCommodityRow = nil
            RefreshShoppingWindow()
            return
        end

        if not hasSession then
            return
        end

        local row = S.pendingCommodityRow
        if row then
            row.purchaseStage = nil
            row.pendingQuantity = nil
            row.pendingUnitPrice = nil
            row.pendingTotalPrice = nil
            row.status = T("PG_SHOP_STATUS_PURCHASE_FAILED", "Purchase failed")
            S.pendingCommodityRow = nil
            RefreshWindow()
        end
        return
    end

    if event == "AUCTION_HOUSE_PURCHASE_COMPLETED" then
        local auctionID = ...
        local searchRow, searchPending = FindSearchRowByAuctionID(auctionID)
        if searchRow and searchPending then
            AnnouncePurchase(searchPending.itemID or searchRow.itemID, searchPending.quantity, searchPending.totalPrice)
            MarkSearchRowPurchased(searchRow, string.format(T("PG_SHOP_STATUS_BOUGHT_AUCTION", "Bought auction x%d"), searchPending.quantity or 1))
            S.pendingSearchItemPurchases[auctionID] = nil
            RefreshShoppingWindow()
            return
        end

        if not hasSession then
            return
        end

        local row, pending = FindRowByAuctionID(auctionID)
        if row and pending then
            AnnouncePurchase(pending.itemID or row.chosenItemID or row.itemID, pending.quantity, pending.totalPrice)
            MarkRowPurchased(row, string.format(T("PG_SHOP_STATUS_BOUGHT_AUCTION", "Bought auction x%d"), pending.quantity or 1))
            S.pendingItemPurchases[auctionID] = nil
            if S.buyAllState.active and S.buyAllState.currentRowIndex == row.index then
                S.buyAllState.pointer = (S.buyAllState.pointer or 1) + 1
                S.buyAllState.currentRowIndex = nil
            end
            RefreshWindow()
        end
        return
    end
end)

_G.SLASH_HIRONCRAFT_PROFITSHOPPINGDEBUG1 = "/ahuishopdebug"
_G.SlashCmdList["HIRONCRAFT_PROFITSHOPPINGDEBUG"] = function()
    PT.config = PT.config or {}
    PT.config.shoppingListMirrorDebug = not PT.config.shoppingListMirrorDebug

    print("HironCraft shopping mirror debug:", PT.config.shoppingListMirrorDebug and "ON" or "OFF")
end

_G.SLASH_PHSHOPDBG1 = "/phshopdbg"
_G.SlashCmdList["PHSHOPDBG"] = function()
    S.searchDebug = not S.searchDebug
    print("|cffb19cd9PHShop|r дебаг поиска:", S.searchDebug and "ВКЛ" or "ВЫКЛ")
end

C_Timer.After(0, function()
    if S.IsAuctionatorPlanMirrorEnabled
       and S:IsAuctionatorPlanMirrorEnabled()
       and S.EnsureAuctionatorPlanMirror
    then
        S:EnsureAuctionatorPlanMirror()
    end
end)
