local PT = HironCraftProfit
if not PT then return end

PT.Prices = PT.Prices or {}
local P = PT.Prices

local MARKET_CHEAPEST_PORTION = 0.25
local SCAN_THROTTLE = 60
local READ_CHUNK = 500

local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffb19cd9HironCraft|r " .. tostring(msg))
    end
end

local function RealmKey()
    local r = GetRealmName() or "Unknown"
    return (r:gsub("%s+", ""))
end

local function EnsureDB()
    HironCraftProfit_PriceDB = HironCraftProfit_PriceDB or {}
    HironCraftProfit_PriceDB.realms = HironCraftProfit_PriceDB.realms or {}
    local rk = RealmKey()
    HironCraftProfit_PriceDB.realms[rk] = HironCraftProfit_PriceDB.realms[rk] or { items = {}, lastScan = 0 }
    return HironCraftProfit_PriceDB.realms[rk]
end

function P:GetConfig()
    PT.config = PT.config or {}
    if PT.config.priceSource == nil then
        PT.config.priceSource = "phMarket"
    end
    return PT.config
end

local function IsEquippable(itemID)
    local equipLoc = select(4, C_Item.GetItemInfoInstant(itemID))
    return equipLoc ~= nil and equipLoc ~= ""
        and equipLoc ~= "INVTYPE_NON_EQUIP" and equipLoc ~= "INVTYPE_BAG"
end

local function KeysFromItemKey(itemKey)
    local id = itemKey and tonumber(itemKey.itemID)
    if not id then return nil end

    local species = tonumber(itemKey.battlePetSpeciesID) or 0
    if species ~= 0 then
        return { "pet:" .. species }
    end

    local ilvl = tonumber(itemKey.itemLevel) or 0
    if ilvl > 0 and IsEquippable(id) then
        return { id .. ":" .. ilvl, tostring(id) }
    end

    return { tostring(id) }
end
P.KeysFromItemKey = KeysFromItemKey

function P:KeyForLink(link)
    if type(link) ~= "string" then return nil end
    local id = tonumber(link:match("item:(%d+)"))
    if not id then return nil end
    if IsEquippable(id) and C_Item.GetDetailedItemLevelInfo then
        local ilvl = C_Item.GetDetailedItemLevelInfo(link)
        if ilvl and ilvl > 0 then
            return id .. ":" .. ilvl
        end
    end
    return tostring(id)
end

local function Lookup(idOrKey)
    if not idOrKey then return nil end
    return EnsureDB().items[tostring(idOrKey)]
end

function P:GetMinBuyout(idOrKey)
    local rec = Lookup(idOrKey)
    return rec and rec.min or nil
end

function P:GetMarketValue(idOrKey)
    local rec = Lookup(idOrKey)
    return rec and rec.market or nil
end

function P:NormalizeRealmKey(realm)
    return (tostring(realm or ""):gsub("%s+", ""))
end

function P:CurrentRealmKey()
    return RealmKey()
end

local function LookupRealm(realmKey, idOrKey)
    if not realmKey or not idOrKey then return nil end
    local realms = HironCraftProfit_PriceDB and HironCraftProfit_PriceDB.realms
    local r = realms and realms[tostring(realmKey)]
    return r and r.items and r.items[tostring(idOrKey)]
end

function P:GetRealmMinBuyout(realm, idOrKey)
    local rec = LookupRealm(self:NormalizeRealmKey(realm), idOrKey)
    return rec and rec.min or nil
end

function P:GetRealmMarketValue(realm, idOrKey)
    local rec = LookupRealm(self:NormalizeRealmKey(realm), idOrKey)
    return rec and rec.market or nil
end

function P:GetRealmPrice(realm, item, priceType)
    local key = self:ResolveKey(item)
    if not key then return nil end
    if not realm or realm == "" then realm = self:CurrentRealmKey() end
    if priceType == "min" then
        return self:GetRealmMinBuyout(realm, key)
    end
    return self:GetRealmMarketValue(realm, key)
end

function P:ListRealms()
    local out = {}
    local realms = HironCraftProfit_PriceDB and HironCraftProfit_PriceDB.realms
    if realms then
        for rk, data in pairs(realms) do
            local n = 0
            if type(data) == "table" and type(data.items) == "table" then
                for _ in pairs(data.items) do n = n + 1 end
            end
            out[#out + 1] = { realm = rk, lastScan = (type(data) == "table" and data.lastScan) or 0, count = n }
        end
    end
    table.sort(out, function(a, b) return a.realm < b.realm end)
    return out
end

function P:UpdateItem(idOrKey, minPrice, marketPrice, qty)
    if not idOrKey then return false end
    minPrice = tonumber(minPrice)
    if not minPrice or minPrice <= 0 then return false end
    marketPrice = tonumber(marketPrice) or minPrice
    if marketPrice <= 0 then marketPrice = minPrice end
    local db = EnsureDB()
    db.items = db.items or {}
    local key = tostring(idOrKey)
    local rec = db.items[key]
    if not rec then
        rec = {}
        db.items[key] = rec
    end
    rec.min = minPrice
    rec.market = marketPrice
    rec.t = time()
    if qty ~= nil then rec.q = tonumber(qty) end
    db.lastPartial = time()
    return true
end

function P:UpdateItemFromKey(itemKey, minPrice, marketPrice, qty)
    local keys = KeysFromItemKey(itemKey)
    if not keys then return false end
    local any = false
    for _, k in ipairs(keys) do
        if self:UpdateItem(k, minPrice, marketPrice, qty) then any = true end
    end
    return any
end

function P:GetScanInfo()
    local db = EnsureDB()
    local n = 0
    for _ in pairs(db.items) do n = n + 1 end
    return db.lastScan or 0, n
end

function P:GetLastScan()
    return EnsureDB().lastScan or 0
end

PRICE_DB_MAX_AGE = 7 * 24 * 3600

function P:PruneOldData(maxAge)
    maxAge = tonumber(maxAge) or PRICE_DB_MAX_AGE
    local realms = HironCraftProfit_PriceDB and HironCraftProfit_PriceDB.realms
    if type(realms) ~= "table" then return 0, 0 end
    local cutoff = time() - maxAge
    local cur = RealmKey()
    local removedItems, removedRealms = 0, 0
    for realmKey, r in pairs(realms) do
        if type(r) == "table" and type(r.items) == "table" then
            for k, rec in pairs(r.items) do
                local t = (type(rec) == "table") and rec.t or nil
                if not t or t < cutoff then
                    r.items[k] = nil
                    removedItems = removedItems + 1
                end
            end
            if realmKey ~= cur and not next(r.items) then
                realms[realmKey] = nil
                removedRealms = removedRealms + 1
            end
        end
    end
    return removedItems, removedRealms
end

function P:PurgeExternalRealms()
    local realms = HironCraftProfit_PriceDB and HironCraftProfit_PriceDB.realms
    if type(realms) ~= "table" then return 0, 0 end
    local cur = RealmKey()
    local removedItems, removedRealms = 0, 0
    for realmKey, r in pairs(realms) do
        if realmKey ~= cur and type(r) == "table"
            and (tonumber(r.lastScan) or 0) <= 0
            and (tonumber(r.lastPartial) or 0) <= 0 then
            if type(r.items) == "table" then
                for _ in pairs(r.items) do removedItems = removedItems + 1 end
            end
            realms[realmKey] = nil
            removedRealms = removedRealms + 1
        end
    end
    return removedItems, removedRealms
end

function P:GetDBStats()
    local realms = HironCraftProfit_PriceDB and HironCraftProfit_PriceDB.realms
    local nRealms, nItems = 0, 0
    if type(realms) == "table" then
        for _, r in pairs(realms) do
            nRealms = nRealms + 1
            if type(r) == "table" and type(r.items) == "table" then
                for _ in pairs(r.items) do nItems = nItems + 1 end
            end
        end
    end
    return nRealms, nItems
end

local function GetTSMPrice(itemID, tsmKey)
    if not TSM_API then return nil end
    local ok, str = pcall(function() return "i:" .. tostring(itemID) end)
    if not ok then return nil end
    local price = nil
    pcall(function() price = TSM_API.GetCustomPriceValue(tsmKey or "DBMarket", str) end)
    return tonumber(price)
end

local function GetAuctionatorPrice(itemID)
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if not api then return nil end
    local price = nil
    pcall(function() price = api.GetAuctionPriceByItemID("HironCraft", tonumber(itemID)) end)
    return tonumber(price)
end

function P:HasExternal()
    return (TSM_API ~= nil) or (Auctionator and Auctionator.API and Auctionator.API.v1 ~= nil) or false
end

local function NumericId(idOrKey)
    local n = tonumber(idOrKey)
    if n then return n end
    if type(idOrKey) == "string" then
        return tonumber(idOrKey:match("^(%d+)"))
    end
    return nil
end

function P:GetPrice(idOrKey, source)
    if not idOrKey then return nil end
    source = source or self:GetConfig().priceSource or "phMarket"

    if source == "phMin" then
        return self:GetMinBuyout(idOrKey)
    elseif source == "phMarket" then
        return self:GetMarketValue(idOrKey)
    elseif source == "auctionator" then
        return GetAuctionatorPrice(NumericId(idOrKey))
    elseif type(source) == "string" and source:sub(1, 4) == "tsm:" then
        return GetTSMPrice(NumericId(idOrKey), source:sub(5))
    end

    return self:GetMarketValue(idOrKey)
end

function P:ResolveKey(item)
    if type(item) == "number" then
        return tostring(item), item
    end
    if type(item) == "string" then
        local linkId = item:match("item:(%d+)")
        if linkId then
            return self:KeyForLink(item), tonumber(linkId)
        end
        local n = tonumber(item)
        if n then return tostring(n), n end
    end
    return nil, nil
end

local PRICE_FALLBACK_ORDER = { "phMarket", "auctionator", "tsm:DBMarket" }

function P:GetItemPrice(item, source)
    local key = self:ResolveKey(item)
    if not key then return nil end
    source = source or self:GetConfig().priceSource or "phMarket"

    local price = self:GetPrice(key, source)
    if price and price > 0 then return price end

    for _, s in ipairs(PRICE_FALLBACK_ORDER) do
        if s ~= source then
            price = self:GetPrice(key, s)
            if price and price > 0 then return price end
        end
    end
    return nil
end

function P:GetOwnItemPrice(item)
    local key = self:ResolveKey(item)
    if not key then return nil end
    local src = self:GetConfig().priceSource or "phMarket"
    if src ~= "phMin" and src ~= "phMarket" then src = "phMarket" end
    return self:GetPrice(key, src)
end

P._scanListeners = P._scanListeners or {}
function P:OnScanDone(fn)
    if type(fn) == "function" then
        table.insert(self._scanListeners, fn)
    end
end

P.scanning = false
P.scanProgress = 0
P._scanExpected = 0
P._agg = nil

function P:GetScanProgress()
    return self.scanning == true, self.scanProgress or 0
end

local function ProcessBrowse()
    local results = C_AuctionHouse.GetBrowseResults() or {}
    local now = time()
    local items = {}
    local updated = 0

    for _, r in ipairs(results) do
        local price = tonumber(r.minPrice)
        local qty = tonumber(r.totalQuantity) or 0
        if r.itemKey and price and price > 0 and qty > 0 then
            local keys = KeysFromItemKey(r.itemKey)
            if keys then
                for _, k in ipairs(keys) do
                    local rec = items[k]
                    if not rec then
                        items[k] = { min = price, market = price, t = now, q = qty }
                        updated = updated + 1
                    else
                        if price < rec.min then rec.min = price; rec.market = price end
                        rec.q = rec.q + qty
                    end
                end
            end
        end
    end

    local db = EnsureDB()
    db.items = items
    db.lastScan = now
    P.scanning = false
    P.scanProgress = 100

    Print(("Prices: скан завершён — %d записей."):format(updated))
    if type(P.onScanDone) == "function" then pcall(P.onScanDone, updated) end
    for _, fn in ipairs(P._scanListeners or {}) do pcall(fn, updated) end
end

local function MergeBrowse()
    local results = C_AuctionHouse.GetBrowseResults() or {}
    if #results == 0 then return 0 end

    local now = time()
    local db = EnsureDB()
    db.items = db.items or {}
    local seen = {}
    local updated = 0

    for _, r in ipairs(results) do
        local price = tonumber(r.minPrice)
        local qty = tonumber(r.totalQuantity) or 0
        if r.itemKey and price and price > 0 and qty > 0 then
            local keys = KeysFromItemKey(r.itemKey)
            if keys then
                for _, k in ipairs(keys) do
                    if not seen[k] then
                        db.items[k] = { min = price, market = price, t = now, q = qty }
                        seen[k] = true
                        updated = updated + 1
                    else
                        local rec = db.items[k]
                        if price < rec.min then rec.min = price; rec.market = price end
                        rec.q = (rec.q or 0) + qty
                    end
                end
            end
        end
    end

    db.lastPartial = now
    if updated > 0 then
        for _, fn in ipairs(P._scanListeners or {}) do pcall(fn, updated) end
    end
    return updated
end

local function RequestMore()
    if not P.scanning then return end
    if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then
        C_Timer.After(0.25, RequestMore)
        return
    end
    if C_AuctionHouse.RequestMoreBrowseResults then
        C_AuctionHouse.RequestMoreBrowseResults()
    end
end

function P:CanScan()
    if not (C_AuctionHouse and C_AuctionHouse.SendBrowseQuery) then return false, "no_ah" end
    if not self.ahOpen then return false, "ah_closed" end
    if self.scanning then
        if self._scanStarted and (time() - self._scanStarted) > 125 then
            self.scanning = false
        else
            return false, "scanning"
        end
    end
    local db = EnsureDB()
    local hasItems = next(db.items) ~= nil
    if hasItems and (time() - (db.lastScan or 0)) < SCAN_THROTTLE then
        return false, "throttle"
    end
    return true
end

function P:StartFullScan()
    local ok, reason = self:CanScan()
    if not ok then return false, reason end
    self.scanning = true
    self.scanProgress = 0
    self._scanStarted = time()

    local _, prev = self:GetScanInfo()
    self._scanExpected = (prev and prev > 0) and prev or 20000

    C_AuctionHouse.SendBrowseQuery({
        searchString    = "",
        sorts           = {},
        minLevel        = 0,
        maxLevel        = 0,
        filters         = {},
        itemClassFilters = {},
    })

    C_Timer.After(120, function()
        if P.scanning then
            Print("Prices: скан не завершился за 120с — возможно троттл AH. Попробуй ещё раз.")
            P.scanning = false
        end
    end)
    return true
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
ev:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
ev:RegisterEvent("AUCTION_HOUSE_SHOW")
ev:RegisterEvent("AUCTION_HOUSE_CLOSED")
ev:RegisterEvent("PLAYER_LOGIN")

ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if C_Timer and C_Timer.After then
            C_Timer.After(8, function() P:PruneOldData() end)
        else
            P:PruneOldData()
        end
        return
    end
    if event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
        if P.scanning then
            local cur = #(C_AuctionHouse.GetBrowseResults() or {})
            local exp = P._scanExpected or 20000
            if exp > 0 then
                P.scanProgress = math.min(99, math.floor(cur / exp * 100))
            end
            if C_AuctionHouse.HasFullBrowseResults and C_AuctionHouse.HasFullBrowseResults() then
                ProcessBrowse()
            else
                RequestMore()
            end
        else
            MergeBrowse()
        end
    elseif event == "AUCTION_HOUSE_SHOW" then
        P.ahOpen = true
    elseif event == "AUCTION_HOUSE_CLOSED" then
        P.ahOpen = false
        P.scanning = false
    end
end)

SLASH_PHPRICE1 = "/phprice"
SlashCmdList["PHPRICE"] = function(msg)
    msg = tostring(msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "scan" then
        local ok, reason = P:StartFullScan()
        if ok then
            Print("Prices: full scan started…")
        else
            Print("Prices: cannot scan (" .. tostring(reason) .. "). Open the Auction House.")
        end
    elseif msg == "prune" then
        local ri, rr = P:PruneOldData()
        Print(("Prices: pruned %d stale items, %d realms."):format(ri, rr))
    elseif msg == "purgeexternal" or msg == "purge" then
        local ri, rr = P:PurgeExternalRealms()
        Print(("Prices: purged %d realms (%d items) with no local scan."):format(rr, ri))
    else
        local lastScan, n = P:GetScanInfo()
        local nRealms, nItems = P:GetDBStats()
        local ago = lastScan > 0 and math.floor((time() - lastScan) / 60) or -1
        Print(("Prices: %d items this realm, %d total / %d realms. Last scan %s. /phprice scan | prune | purgeexternal."):format(
            n, nItems, nRealms, ago >= 0 and (ago .. " min ago") or "never"))
    end
end
