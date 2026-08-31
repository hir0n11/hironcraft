local E = _G.HironCraftProfitCraftingOrdersEnv
if not E then
    E = {}
    _G.HironCraftProfitCraftingOrdersEnv = E
    setmetatable(E, { __index = _G })
end
setfenv(1, E)
if not PT or not CO then return end

function ReadConcentrationCostFromInfo(info)
    if type(info) ~= "table" then return nil end

    local direct = info.concentrationCost
        or info.concentrationAmount
        or info.concentrationSpent
        or info.concentrationRequired
        or info.requiredConcentration
        or info.concentrationCurrencyCost
        or info.currencyCost
        or info.cost

    direct = tonumber(direct)
    if direct and direct > 0 then return math.floor(direct + 0.5) end

    local candidates = {
        info.concentrationCosts,
        info.currencyCosts,
        info.costs,
        info.requiredCurrencies,
    }

    for _, tbl in ipairs(candidates) do
        if type(tbl) == "table" then
            for _, entry in pairs(tbl) do
                if type(entry) == "table" then
                    local currencyID = entry.currencyID or entry.currencyType or entry.currencyTypeID or entry.currencyTypeId
                    local amount = entry.amount or entry.quantity or entry.cost or entry.value
                    if amount and (not currencyID or tostring(currencyID):find("concentration") or tostring(entry.name or ""):lower():find("concentration")) then
                        amount = tonumber(amount)
                        if amount and amount > 0 then return math.floor(amount + 0.5) end
                    end
                end
            end
        end
    end

    return nil
end

function GetConcentrationCostText(cost)
    cost = tonumber(cost)
    if cost and cost > 0 then
        return tostring(math.floor(cost + 0.5))
    end
    return nil
end

function GetOrderReagentPayload(reagentInfo)
    if not reagentInfo then return nil end
    local payload = reagentInfo.reagent
        or reagentInfo.reagentInfo
        or reagentInfo.craftingReagentInfo
        or reagentInfo.craftingReagent
        or reagentInfo.item
        or reagentInfo

    if payload and payload.reagent then payload = payload.reagent end
    if payload and payload.reagentInfo then payload = payload.reagentInfo end
    if payload and payload.craftingReagentInfo then payload = payload.craftingReagentInfo end
    if payload and payload.craftingReagent then payload = payload.craftingReagent end

    return payload
end

function GetOrderReagentItemID(reagentInfo)
    if not reagentInfo then return nil end
    local payload = GetOrderReagentPayload(reagentInfo)
    return (payload and (payload.itemID or payload.itemId or payload.itemTypeID or payload.itemTypeId))
        or reagentInfo.itemID
        or reagentInfo.itemId
        or reagentInfo.itemTypeID
        or reagentInfo.itemTypeId
end

function GetOrderReagentContainer(reagentInfo)
    if type(reagentInfo) ~= "table" then return nil end
    return reagentInfo.reagentInfo
        or reagentInfo.craftingReagentInfo
        or reagentInfo.craftingReagent
        or reagentInfo.reagent
        or reagentInfo.item
end

function GetNestedOrderReagentValue(reagentInfo, ...)
    if type(reagentInfo) ~= "table" then return nil end

    local keys = { ... }
    local candidates = { reagentInfo }
    local function AddCandidate(candidate)
        if type(candidate) == "table" then
            candidates[#candidates + 1] = candidate
        end
    end

    AddCandidate(reagentInfo.reagentInfo)
    AddCandidate(reagentInfo.craftingReagentInfo)
    AddCandidate(reagentInfo.craftingReagent)
    AddCandidate(reagentInfo.reagent)
    AddCandidate(reagentInfo.item)

    for _, candidate in ipairs(candidates) do
        if type(candidate) == "table" then
            for _, key in ipairs(keys) do
                if candidate[key] ~= nil then
                    return candidate[key]
                end
            end

            local nested = candidate.reagent or candidate.reagentInfo or candidate.craftingReagentInfo or candidate.craftingReagent
            if type(nested) == "table" and nested ~= candidate then
                for _, key in ipairs(keys) do
                    if nested[key] ~= nil then
                        return nested[key]
                    end
                end
            end
        end
    end

    return nil
end

function GetOrderReagentDataSlotIndex(reagentInfo)
    if type(reagentInfo) ~= "table" then return nil end

    if reagentInfo.reagent and reagentInfo.reagent.dataSlotIndex then
        return reagentInfo.reagent.dataSlotIndex
    end
    if reagentInfo.reagentInfo and reagentInfo.reagentInfo.dataSlotIndex then
        return reagentInfo.reagentInfo.dataSlotIndex
    end
    if reagentInfo.craftingReagentInfo and reagentInfo.craftingReagentInfo.dataSlotIndex then
        return reagentInfo.craftingReagentInfo.dataSlotIndex
    end
    if reagentInfo.craftingReagent and reagentInfo.craftingReagent.dataSlotIndex then
        return reagentInfo.craftingReagent.dataSlotIndex
    end

    return reagentInfo.dataSlotIndex
        or reagentInfo.slotDataIndex
        or reagentInfo.reagentSlot
        or reagentInfo.slotIndex
end

function GetOrderReagentSlotIndex(reagentInfo)
    if type(reagentInfo) ~= "table" then return nil end

    if reagentInfo.slotIndex then return reagentInfo.slotIndex end
    if reagentInfo.reagentSlot then return reagentInfo.reagentSlot end
    if reagentInfo.reagent and reagentInfo.reagent.slotIndex then return reagentInfo.reagent.slotIndex end
    if reagentInfo.reagentInfo and reagentInfo.reagentInfo.slotIndex then return reagentInfo.reagentInfo.slotIndex end
    if reagentInfo.craftingReagentInfo and reagentInfo.craftingReagentInfo.slotIndex then return reagentInfo.craftingReagentInfo.slotIndex end
    if reagentInfo.craftingReagent and reagentInfo.craftingReagent.slotIndex then return reagentInfo.craftingReagent.slotIndex end

    return GetOrderReagentDataSlotIndex(reagentInfo)
end

function GetOrderReagentQuantity(reagentInfo)
    if type(reagentInfo) ~= "table" then return 0 end

    local direct = reagentInfo.quantity or reagentInfo.quantityRequired or reagentInfo.requiredQuantity
    if direct ~= nil then return direct end

    for _, container in ipairs({ reagentInfo.reagentInfo, reagentInfo.craftingReagentInfo, reagentInfo.craftingReagent, reagentInfo.reagent }) do
        if type(container) == "table" then
            local quantity = container.quantity or container.quantityRequired or container.requiredQuantity
            if quantity ~= nil then return quantity end
        end
    end

    return 0
end

function NormalizeQualityTier(value)
    value = tonumber(value)
    if not value or value <= 0 then return nil end
    return math.floor(value + 0.0001)
end

function ReadProfessionQualityFromItem(itemID, itemLink)
    if not itemID and not itemLink then return nil end

    if C_TradeSkillUI and C_TradeSkillUI.GetItemReagentQualityByItemInfo then
        local ok, quality = pcall(C_TradeSkillUI.GetItemReagentQualityByItemInfo, itemLink or itemID)
        quality = NormalizeQualityTier(ok and quality)
        if quality then return quality end
    end

    if C_TradeSkillUI and C_TradeSkillUI.GetItemCraftedQualityByItemInfo then
        local ok, quality = pcall(C_TradeSkillUI.GetItemCraftedQualityByItemInfo, itemLink or itemID)
        quality = NormalizeQualityTier(ok and quality)
        if quality then return quality end
    end

    return nil
end

function ReadItemInfoFields(itemID, itemLink)
    if not itemID and not itemLink then return nil end

    if C_Item and C_Item.GetItemInfo then
        local results = { pcall(C_Item.GetItemInfo, itemLink or itemID) }
        if results[1] then


            return {
                classID = tonumber(results[13]),
                subclassID = tonumber(results[14]),
                expansionID = tonumber(results[16]),
            }
        end
    end

    if C_Item and C_Item.RequestLoadItemDataByID and itemID then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    end

    return nil
end

function ReadItemExpansionID(itemID, itemLink)
    local fields = ReadItemInfoFields(itemID, itemLink)
    return fields and fields.expansionID
end

function ReadItemClassID(itemID, itemLink)
    local fields = ReadItemInfoFields(itemID, itemLink)
    if fields and fields.classID then return fields.classID end

    if C_Item and C_Item.GetItemInfoInstant then
        local ok, _, _, _, _, _, classID = pcall(C_Item.GetItemInfoInstant, itemLink or itemID)
        if ok and tonumber(classID) then return tonumber(classID) end
    end

    return nil
end

function DetermineProfessionQualityKind(payload, itemID)
    if payload then
        if payload.isCraftingReagent == true
        or payload.isProfessionReagent == true
        or payload.isOptionalReagent == true
        or payload.isFinishingReagent == true
        or payload.isConsumable == true
        or payload.reagentType
        or payload.reagentQuality
        or payload.reagentQualityTier then
            return "reagent"
        end

        if payload.isCraftedItem == true
        or payload.isEquipment == true
        or payload.itemQualityType == "item" then
            return "item"
        end
    end

    local id = itemID or (payload and (payload.itemID or payload.itemId))
    local link = payload and (payload.itemLink or payload.link)
    local classID = ReadItemClassID(id, link)
    local consumableClass = Enum and Enum.ItemClass and Enum.ItemClass.Consumable or 0
    local tradeskillClass = Enum and Enum.ItemClass and (Enum.ItemClass.Tradeskill or Enum.ItemClass.Tradegoods) or 7

    if classID == consumableClass or classID == tradeskillClass then
        return "reagent"
    end

    return "item"
end

function ReadPayloadQuality(payload, itemID)
    if not payload then return nil end
    return NormalizeQualityTier(payload.quality)
        or NormalizeQualityTier(payload.qualityTier)
        or NormalizeQualityTier(payload.reagentQuality)
        or NormalizeQualityTier(payload.reagentQualityTier)
        or NormalizeQualityTier(payload.professionQuality)
        or NormalizeQualityTier(payload.materialQuality)
        or NormalizeQualityTier(payload.craftedQuality)
        or ReadProfessionQualityFromItem(itemID or payload.itemID or payload.itemId, payload.itemLink or payload.link)
end

function ReadPayloadMaxQuality(payload)
    if not payload then return nil end
    return NormalizeQualityTier(payload.maxQuality)
        or NormalizeQualityTier(payload.maxQualityTier)
        or NormalizeQualityTier(payload.maxReagentQuality)
        or NormalizeQualityTier(payload.maxProfessionQuality)
        or NormalizeQualityTier(payload.qualityMax)
end

function ReadPayloadExpansionID(payload, itemID)
    if payload then
        local expansionID = tonumber(payload.expansionID
            or payload.expacID
            or payload.expansion
            or payload.expansionLevel
            or payload.itemExpansionID
            or payload.itemExpansionLevel
            or payload.sourceExpansionID
            or payload.craftingExpansionID)
        if expansionID then return expansionID end
    end
    return ReadItemExpansionID(itemID or (payload and (payload.itemID or payload.itemId)), payload and (payload.itemLink or payload.link))
end

function IsMidnightProfessionReagentQuality(tier, maxTier, expansionID, qualityKind)
    tier = NormalizeQualityTier(tier)
    maxTier = NormalizeQualityTier(maxTier)
    expansionID = tonumber(expansionID)

    if not tier or tier > 2 then return false end
    if qualityKind == "item" then return false end


    if expansionID and expansionID >= 11 then
        return true
    end


    if maxTier and maxTier <= 2 then
        return true
    end

    return false
end

function GetProfessionQualityAtlas(tier, maxTier, expansionID, qualityKind)
    tier = NormalizeQualityTier(tier)
    if not tier then return nil end

    maxTier = NormalizeQualityTier(maxTier)
    expansionID = tonumber(expansionID)
    qualityKind = qualityKind or "reagent"


    if qualityKind == "item" then
        tier = math.max(1, math.min(tier, 5))
        return "Professions-Icon-Quality-Tier" .. tostring(tier)
    end


    if IsMidnightProfessionReagentQuality(tier, maxTier, expansionID, qualityKind) then
        tier = math.max(1, math.min(tier, 2))
        return "Professions-Icon-Quality-12-Tier" .. tostring(tier)
    end


    tier = math.max(1, math.min(tier, 3))
    return "Professions-Icon-Quality-Tier" .. tostring(tier)
end

function CopyReagentQualityFields(target, payload, itemID)
    if not target then return end
    local quality = ReadPayloadQuality(payload, itemID)
    local maxQuality = ReadPayloadMaxQuality(payload)
    local expansionID = ReadPayloadExpansionID(payload, itemID)
    local qualityKind = DetermineProfessionQualityKind(payload, itemID)

    if not maxQuality and expansionID and expansionID >= 11 and qualityKind ~= "item" and quality and quality <= 2 then
        maxQuality = 2
    end

    if not maxQuality and quality then


        maxQuality = qualityKind == "item" and (quality >= 4 and 5 or nil) or (quality <= 3 and 3 or nil)
    end

    target.qualityTier = quality
    target.maxQualityTier = maxQuality
    target.expansionID = expansionID
    target.qualityKind = qualityKind
end

function HasProvidedByCustomerFlag(tbl)
    return type(tbl) == "table" and (
        tbl.providedByCustomer == true
        or tbl.customerProvided == true
        or tbl.isCustomerProvided == true
        or tbl.isProvidedByCustomer == true
        or tbl.providedByNpc == true
        or tbl.providedByNPC == true
        or tbl.npcProvided == true
        or tbl.isNPCProvided == true
        or tbl.isNpcProvided == true
        or tbl.isProvidedByNpc == true
        or tbl.isProvidedByNPC == true
        or tbl.providedByPatron == true
        or tbl.patronProvided == true
        or tbl.isPatronProvided == true
    )
end

function GetReagentSourceValue(reagentInfo, payload)
    local source

    local function ReadSource(tbl)
        if type(tbl) ~= "table" then return nil end
        return tbl.source
            or tbl.orderSource
            or tbl.reagentSource
            or tbl.providedBy
            or tbl.provider
    end

    source = ReadSource(reagentInfo)

    if source == nil and type(reagentInfo) == "table" then
        source = ReadSource(reagentInfo.reagentInfo)
            or ReadSource(reagentInfo.craftingReagentInfo)
            or ReadSource(reagentInfo.craftingReagent)
            or ReadSource(reagentInfo.reagent)
            or ReadSource(reagentInfo.item)
    end

    if source == nil then
        source = ReadSource(payload)
    end

    return source
end

function IsNoneSourceValue(source)
    if source == nil then return false end

    if Enum and Enum.CraftingOrderReagentSource then
        local COS = Enum.CraftingOrderReagentSource
        if COS.None ~= nil and source == COS.None then return true end
    end

    if type(source) == "string" then
        local lower = source:lower()
        return lower == "none" or lower == "noone" or lower == "no_provider" or lower == "noprovider"
    end

    return source == 3
end

function IsProvidedSourceValue(source)
    if source == nil then return false end

    if Enum and Enum.CraftingOrderReagentSource then
        local COS = Enum.CraftingOrderReagentSource
        if COS.Customer ~= nil and source == COS.Customer then return true end
        if COS.Npc ~= nil and source == COS.Npc then return true end
        if COS.NPC ~= nil and source == COS.NPC then return true end
        if COS.Patron ~= nil and source == COS.Patron then return true end
        if COS.Crafter ~= nil and source == COS.Crafter then return false end
        if COS.Any ~= nil and source == COS.Any then return false end
        if COS.None ~= nil and source == COS.None then return false end
    end

    if type(source) == "string" then
        local lower = source:lower()
        return lower == "customer"
            or lower == "npc"
            or lower == "patron"
            or lower == "providedbycustomer"
            or lower == "providedbynpc"
            or lower == "providedbypatron"
            or lower:find("npc", 1, true) ~= nil
            or lower:find("patron", 1, true) ~= nil
    end

    return source == 1
end

function IsCrafterSourceValue(source, nilIsCrafter)
    if source == nil then return nilIsCrafter == true end
    if IsProvidedSourceValue(source) or IsNoneSourceValue(source) then return false end

    if Enum and Enum.CraftingOrderReagentSource then
        local COS = Enum.CraftingOrderReagentSource
        if COS.Crafter ~= nil and source == COS.Crafter then return true end
        if COS.Any ~= nil and source == COS.Any then return true end
    end

    if type(source) == "string" then
        local lower = source:lower()
        return lower == "crafter" or lower == "any" or lower == "player" or lower == "you"
    end

    return source == 0 or source == 2
end

function IsStrictCrafterSourceValue(source)
    if source == nil then return false end
    if IsProvidedSourceValue(source) or IsNoneSourceValue(source) then return false end

    if Enum and Enum.CraftingOrderReagentSource then
        local COS = Enum.CraftingOrderReagentSource
        if COS.Crafter ~= nil and source == COS.Crafter then return true end
        if COS.Any ~= nil and source == COS.Any then return false end
    end

    if type(source) == "string" then
        local lower = source:lower()
        return lower == "crafter"
            or lower == "player"
            or lower == "you"
            or lower == "providedbycrafter"
            or lower == "providedbyplayer"
    end

    return source == 2
end

function IsCustomerProvidedReagent(reagentInfo)
    if not reagentInfo then return false end
    if reagentInfo.crafterRequired == true then return false end
    if reagentInfo.customerProvidedOnly == true then return true end

    local payload = GetOrderReagentPayload(reagentInfo)
    if HasProvidedByCustomerFlag(reagentInfo) or HasProvidedByCustomerFlag(payload) then
        return true
    end

    return IsProvidedSourceValue(GetReagentSourceValue(reagentInfo, payload))
end

function IsCrafterProvidedReagent(reagentInfo)
    if not reagentInfo then return false end
    if reagentInfo.crafterRequired == true then return true end
    if reagentInfo.customerProvidedOnly == true then return false end
    if IsCustomerProvidedReagent(reagentInfo) then return false end

    local payload = GetOrderReagentPayload(reagentInfo)
    return IsCrafterSourceValue(GetReagentSourceValue(reagentInfo, payload), true)
end

function SlotHasRequiredQuantity(slotSchematic)
    if not slotSchematic then return false end

    local quantity = tonumber(slotSchematic.quantityRequired or slotSchematic.requiredQuantity or slotSchematic.quantity)
    if quantity and quantity > 0 then return true end

    local reagents = slotSchematic.reagents or slotSchematic.reagentInfoTbl or slotSchematic.reagentInfos
    if type(reagents) == "table" then
        for _, reagent in ipairs(reagents) do
            local payload = reagent and (reagent.reagent or reagent)
            quantity = tonumber(payload and (payload.quantityRequired or payload.requiredQuantity or payload.quantity))
            if quantity and quantity > 0 then return true end
        end
    end

    return false
end

function IsRequiredCraftingOrderReagentSlot(slotSchematic)
    if not slotSchematic then return true end

    if slotSchematic.optional == true or slotSchematic.isOptional == true then
        return false
    end

    if slotSchematic.required == false or slotSchematic.isRequired == false then
        return false
    end

    if SlotHasRequiredQuantity(slotSchematic) then
        return true
    end

    if Enum and Enum.CraftingReagentType then
        local reagentType = slotSchematic.reagentType
            or (slotSchematic.slotInfo and slotSchematic.slotInfo.reagentType)

        if reagentType == nil then
            return true
        end

        return reagentType == Enum.CraftingReagentType.Basic
            or reagentType == Enum.CraftingReagentType.Automatic
    end

    return true
end

function IsRegionInsideProtectedItemNameZone(row, region)
    if not row or not region or not row.GetLeft or not region.GetLeft then return false end

    local rowLeft = row:GetLeft()
    local regionLeft = region:GetLeft()
    if not rowLeft or not regionLeft then return false end


    return regionLeft < (rowLeft + 230)
end

function FindFontStringByExactText(frame, text, depth, seen)
    if not frame or not text or text == "" or depth > 6 then return nil end
    seen = seen or {}
    if seen[frame] then return nil end
    seen[frame] = true

    if frame.GetRegions then
        local regions = { frame:GetRegions() }
        for _, region in ipairs(regions) do
            if region
            and region.GetObjectType
            and region:GetObjectType() == "FontString"
            and region.GetText
            and region:GetText() == text
            and region.IsShown
            and region:IsShown() then
                return region
            end
        end
    end

    if frame.GetChildren then
        local children = { frame:GetChildren() }
        for _, child in ipairs(children) do
            local found = FindFontStringByExactText(child, text, depth + 1, seen)
            if found then return found end
        end
    end

    return nil
end

function SetRowColumnOverRegion(row, frame, region, fallbackWidth, padX)
    if not row or not frame or not region then return false end

    local rowLeft = row:GetLeft()
    local regionLeft, regionRight = region:GetLeft(), region:GetRight()
    if not rowLeft or not regionLeft or not regionRight then return false end

    padX = padX or 4
    local width = math.max(24, math.min(fallbackWidth or 120, (regionRight - regionLeft) + (padX * 2)))
    local x = math.floor((regionLeft - rowLeft) - padX + 0.5)

    frame:ClearAllPoints()
    frame:SetSize(width, ROW_BUTTON_H)
    frame:SetPoint("LEFT", row, "LEFT", x, 0)
    return true
end

function GetItemTexture(itemID)
    if not itemID then return nil end
    if C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(itemID)
    end
    return GetItemIcon(itemID)
end

function SetIconTooltip(frame, itemID, fallbackText, extraLinesFunc)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:ClearLines()
        if itemID then
            local link = C_Item and C_Item.GetItemInfo and select(2, C_Item.GetItemInfo(itemID))
            if link then
                GameTooltip:SetHyperlink(link)
            else
                GameTooltip:AddLine(fallbackText or ("Item " .. tostring(itemID)), 1, 1, 1)
            end
        elseif fallbackText then
            GameTooltip:AddLine(fallbackText, 1, 1, 1)
        end
        if type(extraLinesFunc) == "function" then
            extraLinesFunc(self)
        end
        ShowGameTooltipCursorRightOrBelow()
    end)
    frame:SetScript("OnLeave", GameTooltip_Hide)
end

function MakeReagentSelectionKey(orderID, slotIndex)
    local orderKey = OrderKey(orderID)
    if not orderKey or slotIndex == nil then return nil end
    return orderKey .. ":" .. tostring(slotIndex)
end

function GetReagentSelectionToken(reagentEntry)
    if type(reagentEntry) ~= "table" then return nil end

    if reagentEntry.selectionToken ~= nil then
        return reagentEntry.selectionToken
    end
    if reagentEntry.schematicIndex ~= nil then
        return "schematic:" .. tostring(reagentEntry.schematicIndex)
    end

    return reagentEntry.dataSlotIndex or reagentEntry.slotIndex
end

function MakeReagentSelectionKeyForEntry(orderID, reagentEntry)
    return MakeReagentSelectionKey(orderID, GetReagentSelectionToken(reagentEntry))
end

function RestoreHiddenOrderRowRegions(row)
    if not row then return end

    row.ahuiOrderColumnsMuted = nil

    if row.ahuiOrderHiddenRegionAlphas then
        for region, alpha in pairs(row.ahuiOrderHiddenRegionAlphas) do
            if region and region.SetAlpha then
                region:SetAlpha(alpha == nil and 1 or alpha)
            end
        end
        wipe(row.ahuiOrderHiddenRegionAlphas)
    end

    if row.ahuiOrderHiddenRegions then
        for region in pairs(row.ahuiOrderHiddenRegions) do
            if region and region.Show then
                region:Show()
            end
        end
        wipe(row.ahuiOrderHiddenRegions)
    end
end

function RectsOverlap(leftA, rightA, topA, bottomA, leftB, rightB, topB, bottomB)
    if not leftA or not rightA or not topA or not bottomA
    or not leftB or not rightB or not topB or not bottomB then
        return false
    end

    return leftA < rightB and rightA > leftB and bottomA < topB and topA > bottomB
end

function ShouldSkipOwnedHironCraftProfitRegion(frame)
    return frame and frame.ahuiCraftingOrdersOwned == true
end

function HideAndMuteOrderRegion(row, region)
    if not row or not region then return end

    row.ahuiOrderHiddenRegions = row.ahuiOrderHiddenRegions or {}
    row.ahuiOrderHiddenRegions[region] = true


    if region.SetAlpha then
        row.ahuiOrderHiddenRegionAlphas = row.ahuiOrderHiddenRegionAlphas or {}
        if row.ahuiOrderHiddenRegionAlphas[region] == nil then
            local alpha = region.GetAlpha and region:GetAlpha() or 1
            row.ahuiOrderHiddenRegionAlphas[region] = alpha
        end
        region:SetAlpha(0)
    end

    if region.Hide then
        region:Hide()
    end
end

function HideOrderCellRegions(row, cell, depth, seen)
    if not row or not cell or depth > 6 or ShouldSkipOwnedHironCraftProfitRegion(cell) then return end
    seen = seen or {}
    if seen[cell] then return end
    seen[cell] = true

    if cell.GetRegions then
        for _, region in ipairs({ cell:GetRegions() }) do
            if region
            and region.IsShown
            and region:IsShown()
            and not ShouldSkipOwnedHironCraftProfitRegion(region) then
                local objectType = region.GetObjectType and region:GetObjectType()
                if objectType == "FontString" or objectType == "Texture" then
                    HideAndMuteOrderRegion(row, region)
                end
            end
        end
    end

    if cell.GetChildren then
        for _, child in ipairs({ cell:GetChildren() }) do
            HideOrderCellRegions(row, child, depth + 1, seen)
        end
    end
end

function HideOrderRowFontStringsInRect(row, frame, left, right, top, bottom, depth, hideTextures)
    if not row or not frame or depth > 5 or ShouldSkipOwnedHironCraftProfitRegion(frame) then return end

    if frame.GetRegions then
        local regions = { frame:GetRegions() }
        for _, region in ipairs(regions) do
            if region
            and region.GetObjectType
            and region.IsShown
            and region:IsShown()
            and not ShouldSkipOwnedHironCraftProfitRegion(region) then
                local objectType = region:GetObjectType()
                local canHide = false

                if objectType == "FontString" then
                    if region.GetText and region:GetText() and region:GetText() ~= "" then
                        canHide = not IsRegionInsideProtectedItemNameZone(row, region)
                    end
                elseif hideTextures == true and objectType == "Texture" then


                    canHide = not IsRegionInsideProtectedItemNameZone(row, region)
                end

                if canHide then
                    local rLeft, rRight, rTop, rBottom = region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom()
                    if RectsOverlap(rLeft, rRight, rTop, rBottom, left, right, top, bottom) then
                        HideAndMuteOrderRegion(row, region)
                    end
                end
            end
        end
    end

    if frame.GetChildren then
        local children = { frame:GetChildren() }
        for _, child in ipairs(children) do
            HideOrderRowFontStringsInRect(row, child, left, right, top, bottom, depth + 1, hideTextures)
        end
    end
end

function CO:HideBlizzardRegionsUnderFrame(row, frame, padX, padY, hideTextures)
    if not row or not frame or not frame:IsShown() then return end

    local left = frame:GetLeft()
    local right = frame:GetRight()
    local top = frame:GetTop()
    local bottom = frame:GetBottom()
    if not left or not right or not top or not bottom then return end

    padX = padX or 4
    padY = padY or 3
    HideOrderRowFontStringsInRect(row, row, left - padX, right + padX, top + padY, bottom - padY, 0, hideTextures == true)
end

function CO:HideBlizzardColumnsUnderHironCraftProfit(row)
    if not row then return end

    row.ahuiOrderColumnsMuted = true

    if row.cells then
        for i = 2, 5 do
            HideOrderCellRegions(row, row.cells[i], 0, {})
        end
    end

    local btn = row.ahuiOrderActionButton
    if btn then
        self:HideBlizzardRegionsUnderFrame(row, btn, 4, 3)
        if btn.check then
            self:HideBlizzardRegionsUnderFrame(row, btn.check, 4, 3)
        end
    end

    self:HideBlizzardRegionsUnderFrame(row, row.ahuiOrderFocusFrame, 4, 3, false)
    self:HideBlizzardRegionsUnderFrame(row, row.ahuiOrderRewardsFrame, 4, 3, true)
    self:HideBlizzardRegionsUnderFrame(row, row.ahuiOrderReagentsFrame, 4, 3, true)
    self:HideBlizzardRegionsUnderFrame(row, row.ahuiOrderProfitFrame, 4, 3, true)
end

function CO:SetStatus(text)
    if not self:IsEnabled() then return end

    if text == self.lastStatus then
        return
    end

    self.lastStatus = text
    if text and text ~= "" then
        print("|cffb19cd9HironCraft:|r " .. text)
    end
end

function CO:GetClaimedOrder()
    if C_CraftingOrders.GetClaimedOrder then
        return C_CraftingOrders.GetClaimedOrder()
    end
    return nil
end

function CO:GetEffectiveOrder(orderID, fallback)
    local claimed = self:GetClaimedOrder()
    if claimed and claimed.orderID == orderID then
        return claimed
    end

    local state = self.rowStates and self.rowStates[orderID]
    if state and state.order then
        return state.order
    end

    return fallback
end

function CO:IsOrderActionInProgress()
    return self.pendingClaimOrderID ~= nil
        or self.pendingCraftOrderID ~= nil
        or self.pendingFulfillOrderID ~= nil
        or self.pendingReleaseOrderID ~= nil
        or self.progressActive == true
end

function CO:IsSafeToPrepareOrderViewForAnalysis(pageFrame)
    if self:IsOrderActionInProgress() then return false end
    pageFrame = pageFrame or self.activePageFrame
    if not pageFrame or not self:IsOrderListOpen(pageFrame) then return false end
    if pageFrame.ahuiCraftingOrdersOrderOpen == true then return false end
    if self:GetClaimedOrder() then return false end
    return self:CanPrepareOrderView(pageFrame) == true
end

function CO:GetRowAction(orderID, fallbackOrder)
    local order = self:GetEffectiveOrder(orderID, fallbackOrder)
    local claimed = self:GetClaimedOrder()

    if claimed and SameOrderID(claimed.orderID, orderID) then
        self.pendingClaimOrderID = nil
        self.rowStates[orderID] = self.rowStates[orderID] or {}
        self.rowStates[orderID].order = claimed
        order = claimed
    end

    local issueKey = OrderKey(orderID)
    if issueKey and self.orderIssues and self.orderIssues[issueKey] then
        return "blocked", self.orderIssues[issueKey], order, false
    end

    if self:GetRecipeKnownState(order) == false then
        return "blocked", T("COA_ACTION_UNKNOWN_RECIPE", "Unknown recipe"), order, false
    end

    if self.viewingCachedOrders then
        return "blocked", T("COA_ACTION_VIEW_ONLY", "View only"), order, false
    end

    local state = self.rowStates and self.rowStates[orderID]
    local pageFrame = self:FindOrderPageFrame(state and state.pageFrame) or self.activePageFrame or (state and state.pageFrame)
    if pageFrame and not self:IsAtUsableCraftingOrderTable(pageFrame) then
        return "blocked", T("COA_ACTION_VIEW_ONLY", "View only"), order, false
    end

    if self.pendingClaimOrderID and SameOrderID(self.pendingClaimOrderID, orderID) then
        return "pending", T("COA_ACTION_CLAIMING", "Claiming"), order, false
    end

    if self.pendingCraftOrderID and SameOrderID(self.pendingCraftOrderID, orderID) then
        return "crafting", T("COA_ACTION_CRAFTING", "Crafting"), order, false
    end

    if self.pendingFulfillOrderID and SameOrderID(self.pendingFulfillOrderID, orderID) then
        return "fulfilling", T("COA_ACTION_FULFILLING", "Completing"), order, false
    end

    local rejectedKey = OrderKey(orderID)
    local rejectedUntil = rejectedKey
        and self.rejectedOrderIDs
        and self.rejectedOrderIDs[rejectedKey]
    if rejectedUntil then
        if rejectedUntil > (GetTime and GetTime() or 0) then
            return "rejecting", T("COA_ACTION_REJECTING", "Declining"), order, false
        end
        self.rejectedOrderIDs[rejectedKey] = nil
    end

    if self.craftedOrderID and SameOrderID(self.craftedOrderID, orderID) then
        if claimed and SameOrderID(claimed.orderID, orderID) then
            return "fulfill", T("COA_ACTION_FULFILL", "Complete"), order or claimed, true
        end
        if order and IsOrderClaimed(order) then
            return "fulfill", T("COA_ACTION_FULFILL", "Complete"), order, true
        end
    end

    if claimed and not SameOrderID(claimed.orderID, orderID) then
        return "blocked", T("COA_ACTION_BUSY", "Busy"), order, false
    end

    if IsOrderCreated(order) then
        local shouldReject = self:ShouldRejectForMissingCustomerReagents(order)
        if shouldReject then
            return "reject", T("COA_ACTION_REJECT", "Decline"), order, true
        end
        return "claim", T("COA_ACTION_CLAIM", "Claim"), order, true
    end

    if IsOrderClaimed(order) then
        if order.isFulfillable then
            return "fulfill", T("COA_ACTION_FULFILL", "Complete"), order, true
        end
        if order.isRecraft then
            return "craft", T("COA_ACTION_RECRAFT", "Recraft"), order, true
        end
        return "craft", T("COA_ACTION_CRAFT", "Craft"), order, true
    end

    return "none", T("COA_ACTION_NONE", "No action"), order, false
end

function CO:IsActionDebug()
    return GetDB().debugActions == true
end

function CO:SetActionDebug(v)
    GetDB().debugActions = v and true or false
    if self.UpdateDebugToggle then self:UpdateDebugToggle() end
    print("|cffb19cd9HironCraft CO-debug:|r " .. (GetDB().debugActions and "|cff33ff33on|r" or "|cffff5555off|r"))
end

function CO:ToggleActionDebug()
    self:SetActionDebug(not self:IsActionDebug())
end

function CO:DActionPrint(...)
    if GetDB().debugActions ~= true then return end
    print("|cffb19cd9CO-debug|r", ...)
end

function CO:DiagnoseRowAction(btn)
    if GetDB().debugActions ~= true then return end

    local orderID = btn and btn.orderID
    local order = self:GetEffectiveOrder(orderID, btn and btn.order)
    local action, label, _, enabled = self:GetRowAction(orderID, btn and btn.order)
    local claimed = self:GetClaimedOrder()
    local key = OrderKey(orderID)
    local function yn(v) return v and "|cff33ff33yes|r" or "|cffff5555no|r" end

    print("|cffb19cd9=== CO debug: order|r " .. tostring(orderID) .. " |cffb19cd9===|r")
    print("  action=|cffffd200" .. tostring(action) .. "|r  reason=|cffffd200" .. tostring(label) .. "|r  enabled=" .. yn(enabled))

    if not order then
        print("  |cffff5555order object is nil|r (not found / not cached)")
        return
    end

    print("  recipeKnown=" .. yn(self:GetRecipeKnownState(order) ~= false)
        .. "  created=" .. yn(IsOrderCreated(order))
        .. "  claimedFlag=" .. yn(IsOrderClaimed(order))
        .. "  fulfillable=" .. yn(order.isFulfillable)
        .. "  recraft=" .. yn(order.isRecraft))

    if claimed then
        print("  |cffff9900another order is claimed:|r " .. tostring(claimed.orderID)
            .. "  matchesThis=" .. yn(SameOrderID(claimed.orderID, orderID))
            .. (SameOrderID(claimed.orderID, orderID) and "" or "  |cffff5555<- this blocks the row (Busy)|r"))
    else
        print("  no order currently claimed")
    end

    print("  issue=|cffffd200" .. tostring(key and self.orderIssues and self.orderIssues[key] or "-") .. "|r"
        .. "  viewingCached=" .. yn(self.viewingCachedOrders))
    print("  pending: claim=" .. tostring(self.pendingClaimOrderID)
        .. " craft=" .. tostring(self.pendingCraftOrderID)
        .. " fulfill=" .. tostring(self.pendingFulfillOrderID)
        .. "  crafted=" .. tostring(self.craftedOrderID))

    local pageFrame = self:FindOrderPageFrame(btn and btn.pageFrame) or self.activePageFrame
    print("  tableUsable=" .. yn(pageFrame and self:IsAtUsableCraftingOrderTable(pageFrame))
        .. "  minQuality=" .. tostring(order.minQuality)
        .. "  spellID=" .. tostring(order.spellID))
end


function CO:SyncRowStateBackgroundLayers(row)
    if not row then return end

    local level = math.max((row:GetFrameLevel() or 1) - 1, 0)
    local strata = row.GetFrameStrata and row:GetFrameStrata() or nil

    local frames = { row.ahuiUnknownRecipeBorder, row.ahuiCraftableOrderBorder, row.ahuiConcentrationRequiredBorder }
    for _, frame in ipairs(frames) do
        if frame then
            if strata and frame.SetFrameStrata then frame:SetFrameStrata(strata) end
            if frame.SetFrameLevel then frame:SetFrameLevel(level) end
            if frame.EnableMouse then frame:EnableMouse(false) end
        end
    end
end

function CO:EnsureUnknownRecipeBorder(row)
    if not row then return nil end
    if row.ahuiUnknownRecipeBorder then return row.ahuiUnknownRecipeBorder end

    local border = CreateFrame("Frame", nil, row, "BackdropTemplate")
    border.ahuiCraftingOrdersOwned = true


    border:SetPoint("TOPLEFT", row, "TOPLEFT", -1, 2)
    border:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 1, -2)
    border:SetFrameLevel(math.max((row:GetFrameLevel() or 1) - 1, 0))
    if border.EnableMouse then border:EnableMouse(false) end
    border:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    border:SetBackdropColor(1, 0.12, 0.08, 0)
    border:SetBackdropBorderColor(1, 0.12, 0.08, 0)
    border:Hide()

    row.ahuiUnknownRecipeBorder = border
    self:SyncRowStateBackgroundLayers(row)
    return border
end

function CO:UpdateUnknownRecipeBorder(row, order)
    local border = self:EnsureUnknownRecipeBorder(row)
    if not border then return end
    if self:GetRecipeKnownState(order) == false then
        self:SyncRowStateBackgroundLayers(row)
        border:Show()
    else
        border:Hide()
    end
end

function CO:EnsureCraftableOrderBorder(row)
    if not row then return nil end
    if row.ahuiCraftableOrderBorder then return row.ahuiCraftableOrderBorder end

    local border = CreateFrame("Frame", nil, row, "BackdropTemplate")
    border.ahuiCraftingOrdersOwned = true
    border:SetPoint("TOPLEFT", row, "TOPLEFT", -1, 2)
    border:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 1, -2)
    border:SetFrameLevel(math.max((row:GetFrameLevel() or 1) - 1, 0))
    if border.EnableMouse then border:EnableMouse(false) end
    border:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    border:SetBackdropColor(0.12, 1.00, 0.28, 0)
    border:SetBackdropBorderColor(0.12, 1.00, 0.28, 0)
    border:Hide()

    row.ahuiCraftableOrderBorder = border
    self:SyncRowStateBackgroundLayers(row)
    return border
end

function CO:GetCraftableOrderVisualCacheKey(order)
    return OrderKey(order and order.orderID)
end

function CO:GetCachedCraftableOrderVisualState(order)
    local cacheKey = self:GetCraftableOrderVisualCacheKey(order)
    if not cacheKey then return nil, false, nil end

    local cached = self.craftableOrderVisualCache and self.craftableOrderVisualCache[cacheKey]
    if cached and cached.expiresAt and cached.expiresAt > CacheNow() then
        return cached.value == true, true, cacheKey
    end

    return nil, false, cacheKey
end

function CO:SetCachedCraftableOrderVisualState(order, value)
    local cacheKey = self:GetCraftableOrderVisualCacheKey(order)
    if not cacheKey then return nil end

    self.craftableOrderVisualCache = self.craftableOrderVisualCache or {}
    self.craftableOrderVisualCache[cacheKey] = {
        value = value == true,
        expiresAt = CacheNow() + (CRAFTABLE_ORDER_VISUAL_HOLD_TTL or 8.0),
    }
    return cacheKey
end

function CO:IsAnyOrderVisualHoldActive()
    return (self.IsOrderVisualStateHoldActive and self:IsOrderVisualStateHoldActive())
        or self.pendingCraftOrderID ~= nil
        or self.pendingClaimOrderID ~= nil
        or self.pendingFulfillOrderID ~= nil
        or self.pendingReleaseOrderID ~= nil
        or self.progressOrderID ~= nil
        or self.pendingCraftButton ~= nil
        or self.progressActive == true
end

function CO:IsCraftableOrderVisualHoldActive()
    return self:IsAnyOrderVisualHoldActive()
end

function CO:UpdateCraftableOrderBorder(row, btn, order)
    local border = self:EnsureCraftableOrderBorder(row)
    if not border then return end

    if self:GetRecipeKnownState(order) == false then
        border.ahuiCraftableOrderVisualKey = self:SetCachedCraftableOrderVisualState(order, false)
        border:Hide()
        return
    end

    local craftable = false
    if btn then
        craftable = self:IsOrderCraftableForSelection(btn) == true
    end

    if craftable then
        border.ahuiCraftableOrderVisualKey = self:SetCachedCraftableOrderVisualState(order, true)
        self:SyncRowStateBackgroundLayers(row)
        border:Show()
        return
    end

    -- Not craftable on this pass. The craftability check depends on async crafting-operation
    -- info that is not always ready on a given refresh, which made the green border flicker
    -- (appear/disappear). Keep the last known-good (green) state until its cache TTL expires,
    -- so a transient "unknown" no longer hides it. A still-craftable order refreshes the cache
    -- on the next positive pass; a genuine loss clears once the cached "true" expires.
    local visualCraftable, hasVisualState, visualKey = self:GetCachedCraftableOrderVisualState(order)
    if hasVisualState and visualCraftable == true then
        border.ahuiCraftableOrderVisualKey = visualKey
        self:SyncRowStateBackgroundLayers(row)
        border:Show()
        return
    end

    border.ahuiCraftableOrderVisualKey = self:SetCachedCraftableOrderVisualState(order, false)
    border:Hide()
end

function CO:GetCachedOrderQualityInfo(order, applyConcentrationOverride)
    if not order then return nil, false end

    local key = OrderKey(order.orderID)
    if not key then return nil, false end

    local useConc
    if applyConcentrationOverride ~= nil then
        useConc = applyConcentrationOverride == true
    else
        useConc = self.useConcentration and self.useConcentration[key] == true
    end

    local revision = GetOrderRevision(self, order.orderID)
    local now = CacheNow()
    local suffixes = { "f", "p" }

    local sawValidMiss = false
    for _, suffix in ipairs(suffixes) do
        local cacheKey = key .. ":" .. (useConc and "1" or "0") .. ":" .. tostring(revision) .. ":" .. suffix
        local cached = self.qualityCache and self.qualityCache[cacheKey]
        if cached and cached.expiresAt and cached.expiresAt > now then
            if cached.value ~= nil then
                return cached.value, true
            end
            sawValidMiss = true
        end
    end

    return nil, sawValidMiss
end

function CO:GetOrderRequestedQuality(order)
    if not order then return 0 end

    local quality = tonumber(order.minQuality)
    if quality and quality > 0 then return quality end

    quality = tonumber(order.minimumQuality)
    if quality and quality > 0 then return quality end

    quality = tonumber(order.requestedQuality)
    if quality and quality > 0 then return quality end

    quality = tonumber(order.requiredQuality)
    if quality and quality > 0 then return quality end

    return 0
end

function CO:GetConcentrationRequirementCacheKey(order)
    local key = OrderKey(order and order.orderID)
    if not key then return nil end

    local requestedQuality = self:GetOrderRequestedQuality(order)
    if requestedQuality <= 0 then return nil end

    return key .. ":" .. tostring(GetOrderRevision(self, order.orderID)) .. ":" .. tostring(requestedQuality)
end

function CO:GetCachedConcentrationRequirement(order)
    local cacheKey = self:GetConcentrationRequirementCacheKey(order)
    if not cacheKey then return nil, false, nil end

    local cached = self.concentrationRequirementCache and self.concentrationRequirementCache[cacheKey]
    if cached and cached.expiresAt and cached.expiresAt > CacheNow() then
        return cached.value == true, true, cacheKey
    end

    return nil, false, cacheKey
end

function CO:SetCachedConcentrationRequirement(order, value)
    local cacheKey = self:GetConcentrationRequirementCacheKey(order)
    if not cacheKey then return nil end

    self.concentrationRequirementCache = self.concentrationRequirementCache or {}
    self.concentrationRequirementCache[cacheKey] = {
        value = value == true,
        expiresAt = CacheNow() + (CONCENTRATION_REQUIREMENT_CACHE_TTL or 30.0),
    }
    return cacheKey
end

function CO:GetConcentrationRequirementVisualCacheKey(order)
    local key = OrderKey(order and order.orderID)
    if not key then return nil end

    local requestedQuality = self:GetOrderRequestedQuality(order)
    if requestedQuality <= 0 then return nil end

    return key .. ":" .. tostring(requestedQuality)
end

function CO:GetCachedConcentrationRequirementVisualState(order)
    local cacheKey = self:GetConcentrationRequirementVisualCacheKey(order)
    if not cacheKey then return nil, false, nil end

    local cached = self.concentrationRequirementVisualCache and self.concentrationRequirementVisualCache[cacheKey]
    if cached and cached.expiresAt and cached.expiresAt > CacheNow() then
        return cached.value == true, true, cacheKey
    end

    return nil, false, cacheKey
end

function CO:SetCachedConcentrationRequirementVisualState(order, value)
    local cacheKey = self:GetConcentrationRequirementVisualCacheKey(order)
    if not cacheKey then return nil end

    self.concentrationRequirementVisualCache = self.concentrationRequirementVisualCache or {}
    self.concentrationRequirementVisualCache[cacheKey] = {
        value = value == true,
        expiresAt = CacheNow() + (CONCENTRATION_REQUIREMENT_VISUAL_HOLD_TTL or 8.0),
    }
    return cacheKey
end

function CO:IsConcentrationVisualHoldActiveForOrder(order)
    local orderID = order and order.orderID
    if not orderID then return false end

    if self:IsAnyOrderVisualHoldActive() then
        return true
    end

    return (self.pendingCraftOrderID and SameOrderID(self.pendingCraftOrderID, orderID))
        or (self.pendingClaimOrderID and SameOrderID(self.pendingClaimOrderID, orderID))
        or (self.pendingFulfillOrderID and SameOrderID(self.pendingFulfillOrderID, orderID))
        or (self.pendingReleaseOrderID and SameOrderID(self.pendingReleaseOrderID, orderID))
        or (self.progressOrderID and SameOrderID(self.progressOrderID, orderID))
        or (self.pendingCraftButton and self.pendingCraftButton.orderID and SameOrderID(self.pendingCraftButton.orderID, orderID))
end

function CO:RequestVisibleOrderQualityWarmup(pageFrame, delay)
    if not self.WarmVisibleOrderQualitySoon then return false end

    local now = CacheNow()
    if self.qualityWarmRequestExpiresAt and self.qualityWarmRequestExpiresAt > now then
        return false
    end

    self.qualityWarmRequestExpiresAt = now + (QUALITY_WARM_REQUEST_THROTTLE or 0.25)
    self:WarmVisibleOrderQualitySoon(pageFrame or self.activePageFrame, delay or QUALITY_WARM_START_DELAY)
    return true
end

function CO:DoesOrderNeedConcentrationForTargetQuality(order, allowPreparedOrderView)
    if not order or not order.orderID then return false end
    if self.viewingCachedOrders then return false end
    if self:GetRecipeKnownState(order) == false then return false end

    local requestedQuality = self:GetOrderRequestedQuality(order)
    if requestedQuality <= 0 then return false end

    local cachedValue, hasCachedValue = self:GetCachedConcentrationRequirement(order)
    if hasCachedValue then return cachedValue end

    local qInfo, cachedOrMiss = self:GetCachedOrderQualityInfo(order, false)
    if not qInfo and not cachedOrMiss then
        qInfo = self:GetOrderQualityInfo(order, false, allowPreparedOrderView == true)
    end

    if not qInfo and allowPreparedOrderView ~= true and self.RequestVisibleOrderQualityWarmup then
        self:RequestVisibleOrderQualityWarmup(self.activePageFrame, QUALITY_WARM_START_DELAY)
    end

    if not qInfo then return nil end

    local craftableQuality = tonumber(qInfo.quality) or 0
    if craftableQuality <= 0 then return nil end

    local needed = craftableQuality < requestedQuality
    self:SetCachedConcentrationRequirement(order, needed)
    return needed
end

function CO:EnsureConcentrationRequiredBorder(row)
    if not row then return nil end
    if row.ahuiConcentrationRequiredBorder then return row.ahuiConcentrationRequiredBorder end

    local border = CreateFrame("Frame", nil, row, "BackdropTemplate")
    border.ahuiCraftingOrdersOwned = true
    border:SetPoint("TOPLEFT", row, "TOPLEFT", -1, 2)
    border:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 1, -2)
    border:SetFrameLevel(math.max((row:GetFrameLevel() or 1) - 1, 0))
    if border.EnableMouse then border:EnableMouse(false) end
    border:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    border:SetBackdropColor(1.00, 0.78, 0.12, 0)
    border:SetBackdropBorderColor(1.00, 0.78, 0.12, 0)
    border:Hide()

    row.ahuiConcentrationRequiredBorder = border
    self:SyncRowStateBackgroundLayers(row)
    return border
end

function CO:UpdateConcentrationRequiredBorder(row, order)
    local border = self:EnsureConcentrationRequiredBorder(row)
    if not border then return end

    local cacheKey = self:GetConcentrationRequirementCacheKey(order)
    local needed = self:DoesOrderNeedConcentrationForTargetQuality(order, false)
    local visualNeeded, hasVisualState, visualKey = self:GetCachedConcentrationRequirementVisualState(order)

    local function SetCostText(show)
        local fs = row.ahuiConcentrationCostText
        if not fs then return end
        if show then
            local cost
            local qInfoConc = self:GetOrderQualityInfo(order, true, true)
            if qInfoConc and qInfoConc.concentrationCost and qInfoConc.concentrationCost > 0 then
                cost = qInfoConc.concentrationCost
            end
            if not cost and self.GetFastConcentrationCost then
                cost = self:GetFastConcentrationCost(order)
            end
            if cost and cost > 0 then
                fs:SetText(string.format("C:%d", math.floor(cost + 0.5)))
                fs:Show()
                return
            end
        end
        fs:SetText("")
        fs:Hide()
    end

    if needed == true then
        border.ahuiConcentrationRequiredCacheKey = cacheKey
        border.ahuiConcentrationRequiredVisualKey = self:SetCachedConcentrationRequirementVisualState(order, true) or visualKey
        self:SyncRowStateBackgroundLayers(row)
        border:Show()
        SetCostText(true)
    elseif needed == false then
        if hasVisualState and visualNeeded == true and self:IsConcentrationVisualHoldActiveForOrder(order) then
            border.ahuiConcentrationRequiredCacheKey = cacheKey
            border.ahuiConcentrationRequiredVisualKey = self:SetCachedConcentrationRequirementVisualState(order, true) or visualKey
            self:SyncRowStateBackgroundLayers(row)
            border:Show()
            SetCostText(true)
            return
        end

        border.ahuiConcentrationRequiredCacheKey = cacheKey
        border.ahuiConcentrationRequiredVisualKey = self:SetCachedConcentrationRequirementVisualState(order, false) or visualKey
        border:Hide()
        SetCostText(false)
    elseif hasVisualState and visualNeeded == true and self:IsConcentrationVisualHoldActiveForOrder(order) then
        border.ahuiConcentrationRequiredCacheKey = cacheKey
        border.ahuiConcentrationRequiredVisualKey = self:SetCachedConcentrationRequirementVisualState(order, true) or visualKey
        self:SyncRowStateBackgroundLayers(row)
        border:Show()
        SetCostText(true)
    elseif border.ahuiConcentrationRequiredCacheKey ~= cacheKey or border.ahuiConcentrationRequiredVisualKey ~= visualKey then
        border.ahuiConcentrationRequiredCacheKey = cacheKey
        border.ahuiConcentrationRequiredVisualKey = visualKey

        local fastCost = self.GetFastConcentrationCost and self:GetFastConcentrationCost(order) or nil
        if fastCost and fastCost > 0 then
            border.ahuiConcentrationRequiredVisualKey = self:SetCachedConcentrationRequirementVisualState(order, true) or visualKey
            self:SyncRowStateBackgroundLayers(row)
            border:Show()
            SetCostText(true)
        else
            border:Hide()
            SetCostText(false)
        end
    end
end

function GetCompactActionText(action, actionText, order)
    if action == "reject" then
        return T("COA_ACTION_REJECT_SHORT", "Decline")
    elseif action == "rejecting" then
        return T("COA_ACTION_REJECTING_SHORT", "...")
    elseif action == "claim" then
        return T("COA_ACTION_CLAIM_SHORT", "Claim")
    elseif action == "craft" then
        if order and order.isRecraft then
            return T("COA_ACTION_RECRAFT_SHORT", "Recraft")
        end
        return T("COA_ACTION_CRAFT_SHORT", "Craft")
    elseif action == "fulfill" then
        return T("COA_ACTION_FULFILL_SHORT", "Done")
    elseif action == "pending" then
        return T("COA_ACTION_CLAIMING_SHORT", "...")
    elseif action == "crafting" then
        return T("COA_ACTION_CRAFTING_SHORT", "...")
    elseif action == "fulfilling" then
        return T("COA_ACTION_FULFILLING_SHORT", "...")
    elseif action == "blocked" then
        return T("COA_ACTION_BLOCKED_SHORT", "—")
    elseif action == "none" then
        return T("COA_ACTION_NONE_SHORT", "—")
    end

    return actionText or ""
end

function CO:UpdateRowButton(btn)
    if not btn or not btn.orderID then return end

    self:SyncRowActionButtonLayers(nil, btn)

    local action, actionText, order, enabled = self:GetRowAction(btn.orderID, btn.order)
    local timeText = GetRemainingTimeText(order)
    local text = GetCompactActionText(action, actionText, order)

    btn.action = action
    btn.actionText = actionText
    btn.timeText = timeText
    btn.actionEnabled = enabled
    btn.order = order or btn.order
    btn.text:SetText(text)

    btn:Enable()

    local selected = self:IsOrderSelected(btn.orderID)
    local isProgressOrder = (self.pendingCraftOrderID and SameOrderID(self.pendingCraftOrderID, btn.orderID))
        or (self.progressActive and self.progressOrderID and SameOrderID(self.progressOrderID, btn.orderID))
    local isQueueOrder = selected and self.currentQueueOrderID and SameOrderID(self.currentQueueOrderID, btn.orderID)

    local fantasy = HironCraftProfit.IsFantasyDesign and HironCraftProfit:IsFantasyDesign()
    local forced = nil
    if isProgressOrder then
        btn.text:SetTextColor(0.55, 0.92, 1, 1)
        if not fantasy then
            btn:SetBackdropColor(0.06, 0.17, 0.22, 0.98)
            btn:SetBackdropBorderColor(0.35, 0.90, 1, 1)
        end
    elseif isQueueOrder then
        btn.text:SetTextColor(1, 0.92, 0.58, 1)
        if not fantasy then
            btn:SetBackdropColor(0.12, 0.10, 0.04, 0.96)
            btn:SetBackdropBorderColor(1, 0.82, 0.32, 1)
        end
    elseif enabled then
        btn.text:SetTextColor(1, 1, 1, 1)
        if not fantasy then
            btn:SetBackdropColor(0.07, 0.09, 0.11, 0.94)
            btn:SetBackdropBorderColor(0.95, 0.78, 0.35, 0.80)
        end
    else
        btn.text:SetTextColor(0.48, 0.48, 0.48, 1)
        forced = "disabled"
        if not fantasy then
            btn:SetBackdropColor(0.035, 0.035, 0.04, 0.88)
            btn:SetBackdropBorderColor(1, 1, 1, 0.08)
        end
    end
    if fantasy and HironCraftProfit.SetPanelButtonForced then
        HironCraftProfit:SetPanelButtonForced(btn, forced)
    end

    if btn.check then
        btn.check:SetChecked(selected)
        btn.check:Show()
    end

    if action == "crafting" or isProgressOrder then
        if self.progressActive and self.progressOrderID and SameOrderID(self.progressOrderID, btn.orderID) then
            if self.progressButton and self.progressButton ~= btn then
                self.progressButton:SetScript("OnUpdate", nil)
                self:HideRowProgressVisual(self.progressButton)
            end
            self.progressButton = btn
            self:SyncRowActionButtonLayers(nil, btn)
            self:StartRowProgressTicker()
            self:ShowRowProgressVisual(btn, btn.ahuiProgressValue or 0.02)
        elseif btn.bar then
            btn.bar:SetValue(0)
            btn.bar:Hide()
        end
    elseif btn.bar and (not self.progressActive or self.progressButton ~= btn) then
        self:HideRowProgressVisual(btn)
    end

    if btn:GetParent() then
        local row = btn:GetParent()
        self:UpdateOrderColumnFrames(row, btn.order)
        self:UpdateCraftableOrderBorder(row, btn, btn.order)
        self:UpdateConcentrationRequiredBorder(row, btn.order)
    end

    self:RefreshHoveredRowButtonTooltip(btn)
end

function CO:RefreshVisibleRows()
    if not self:IsEnabled() then
        self:HideAllOrderOverlays()
        self:StopPageProtector()
        return
    end

    for btn in pairs(self.visibleRowButtons) do
        if btn and btn:IsShown() then
            self:UpdateRowButton(btn)
            local row = btn.GetParent and btn:GetParent()
            if row then
                self:ProtectOrderRowSoon(row, btn)
            end
        end
    end

    self:ApplyOrderNameFontsToVisibleRows(self.activePageFrame)
end

function CO:RefreshVisibleRowsSoon(delay)
    if self.refreshVisibleRowsQueued then return end
    self.refreshVisibleRowsQueued = true

    local function run()
        CO.refreshVisibleRowsQueued = false
        CO:RefreshVisibleRows()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(delay or ROW_REFRESH_DELAY, run)
    else
        run()
    end
end


function CO:HideExternalOrderAddonRegions(pageFrame)
    pageFrame = pageFrame or self.activePageFrame
    if not pageFrame then return end


    for _, containerName in ipairs({ "NMNMRewardIcons", "NMNMReagentIcons" }) do
        local container = pageFrame[containerName]
        if type(container) == "table" then
            for _, rowIcons in pairs(container) do
                if type(rowIcons) == "table" then
                    for _, widget in pairs(rowIcons) do
                        if widget and widget.Hide then widget:Hide() end
                    end
                elseif rowIcons and rowIcons.Hide then
                    rowIcons:Hide()
                end
            end
        end
    end

    local missing = pageFrame.NMNMMissingReagentTextures
    if type(missing) == "table" then
        for texture in pairs(missing) do
            if texture and texture.Hide then texture:Hide() end
        end
    end

    local rows = pageFrame.BrowseFrame and pageFrame.BrowseFrame.OrderList and pageFrame.BrowseFrame.OrderList.ScrollBox
        and pageFrame.BrowseFrame.OrderList.ScrollBox.GetView and pageFrame.BrowseFrame.OrderList.ScrollBox:GetView().frames
    if type(rows) == "table" then
        for _, row in ipairs(rows) do
            if row then
                if row.PriorityTexture and row.PriorityTexture.Hide and not row.PriorityTexture.ahuiCraftingOrdersOwned then row.PriorityTexture:Hide() end
                if row.ErrorTexture and row.ErrorTexture.Hide and not row.ErrorTexture.ahuiCraftingOrdersOwned then row.ErrorTexture:Hide() end
                if row.cells then
                    for _, cell in ipairs(row.cells) do
                        if cell then
                            if cell.missingReagentTexture and cell.missingReagentTexture.Hide then cell.missingReagentTexture:Hide() end
                            if cell.RewardIcon and cell.RewardIcon.Hide then cell.RewardIcon:Hide() end
                        end
                    end
                end
            end
        end
    end
end

function CO:ProtectExternalOrderPageSoon(pageFrame)
    if not self:IsEnabled() then return end
    pageFrame = pageFrame or self.activePageFrame or self:FindOrderPageFrame()
    if not pageFrame then return end

    self.activePageFrame = pageFrame
    self:LockOrderTableColumns()

    local function apply()
        if not CO:IsEnabled() then return end
        CO:LockOrderTableColumns()
        CO:HideExternalOrderAddonRegions(pageFrame)
        CO:RearrangeOrderTableSafely(pageFrame)
        CO:ProtectVisibleRows()
        CO:ProtectOrderHeaderLabels(pageFrame)
        CO:UpdateControlPanelVisibility(pageFrame)
    end

    apply()
    if C_Timer then
        for _, delay in ipairs(EXTERNAL_PAGE_REAPPLY_DELAYS) do
            C_Timer.After(delay, apply)
        end
    end
end

function CO:GetVisibleOrderRows(pageFrame)
    local rows = {}
    local seen = {}

    local function add(row)
        if not row or seen[row] then return end
        if row.IsShown and not row:IsShown() then return end
        seen[row] = true
        rows[#rows + 1] = row
    end

    pageFrame = pageFrame or self.protectedPageFrame or self.activePageFrame or self:FindOrderPageFrame()
    local scrollBox = pageFrame and pageFrame.BrowseFrame and pageFrame.BrowseFrame.OrderList
        and pageFrame.BrowseFrame.OrderList.ScrollBox
    local view = scrollBox and scrollBox.GetView and scrollBox:GetView()
    local frames = view and view.frames
    if type(frames) == "table" then
        for _, row in pairs(frames) do
            add(row)
        end
    end

    for btn in pairs(self.visibleRowButtons or {}) do
        if btn then
            add(btn.GetParent and btn:GetParent())
        end
    end

    return rows
end

function CO:ProtectVisibleRows()
    if not self:IsEnabled() then return end

    local pageFrame = self.protectedPageFrame or self.activePageFrame or self:FindOrderPageFrame()
    self:HideExternalOrderAddonRegions(pageFrame)

    for _, row in ipairs(self:GetVisibleOrderRows(pageFrame)) do
        self:HideBlizzardColumnsUnderHironCraftProfit(row)

        local btn = row.ahuiOrderActionButton
        if btn then
            self:SyncRowActionButtonLayers(row, btn)
        end

        if row.ahuiOrderReagentsFrame then row.ahuiOrderReagentsFrame:SetFrameLevel((row:GetFrameLevel() or 1) + 75) end
        if row.ahuiOrderRewardsFrame then row.ahuiOrderRewardsFrame:SetFrameLevel((row:GetFrameLevel() or 1) + 75) end
        if row.ahuiOrderFocusFrame then row.ahuiOrderFocusFrame:SetFrameLevel((row:GetFrameLevel() or 1) + 75) end
        if row.ahuiOrderProfitFrame then row.ahuiOrderProfitFrame:SetFrameLevel((row:GetFrameLevel() or 1) + 75) end
        self:SyncRowStateBackgroundLayers(row)
    end

    self:ApplyOrderNameFontsToVisibleRows(pageFrame)
    self:ProtectOrderHeaderLabels(pageFrame)
end

function CO:StartPageProtector(pageFrame)
    if not self:IsEnabled() then return end
    self:LockOrderTableColumns()
    pageFrame = pageFrame or self.activePageFrame
    if not pageFrame then return end

    self.protectedPageFrame = pageFrame

    if self.pageProtectorTicker then
        return
    end

    if C_Timer and C_Timer.NewTicker then
        self.pageProtectorTicker = C_Timer.NewTicker(PAGE_PROTECTOR_INTERVAL, function()
            if not CO:IsEnabled() then
                CO:StopPageProtector()
                return
            end

            local pf = CO.protectedPageFrame or CO.activePageFrame
            if not pf or not pf.IsShown or not pf:IsShown() then
                CO:StopPageProtector()
                return
            end

            CO:LockOrderTableColumns()
            CO:UpdateControlPanelVisibility(pf)
            CO:ProtectVisibleRows()
            CO:ProtectOrderHeaderLabels(pf)
        end)
    end
end

function CO:StopPageProtector()
    if self.pageProtectorTicker and self.pageProtectorTicker.Cancel then
        self.pageProtectorTicker:Cancel()
    end
    self.pageProtectorTicker = nil
    self.protectedPageFrame = nil
end

function CO:UpdateControlPanel()
    local panel = self.controlPanel
    if not panel then return end

    self:UpdateControlPanelVisibility(panel.pageFrame or self.activePageFrame)

    if panel.keyText then
        panel.keyText:SetText(T("COA_BINDING_LABEL", "Key:") .. " " .. BindingText(GetDB().binding))
    end

    if panel.selectedText then
        local count = 0
        for _ in pairs(self.selectedOrders or {}) do count = count + 1 end
        panel.selectedText:SetText(T("COA_SELECTED_LABEL", "Selected:") .. " " .. count)
    end

    if panel.expansionButton and panel.expansionButton.text then
        self:SyncSelectedProfessionExpansionFromBlizzard(panel.pageFrame or self.activePageFrame)
        panel.expansionButton.text:SetText(self:GetSelectedProfessionExpansionLabel())
    end

    if self.UpdateShoppingCostText then
        self:UpdateShoppingCostText()
    end

    if self.UpdateProfessionToolSlot then
        self:UpdateProfessionToolSlot()
    end

    if self.UpdateBestQualityToggle then
        self:UpdateBestQualityToggle()
    end

    if self.UpdateAutoToolToggle then
        self:UpdateAutoToolToggle()
    end

    if self.UpdateQueueSettingWidgets then
        self:UpdateQueueSettingWidgets()
    end

    if self.UpdateDebugToggle then
        self:UpdateDebugToggle()
    end

    self:UpdateWeeklyQuestIndicator()
end

function CO:RefreshPageSoon(delay, forceSearch)
    C_Timer.After(delay or 0.2, function()
        local pageFrame = CO.activePageFrame
        if forceSearch == true and pageFrame and pageFrame:IsShown() and pageFrame.StartDefaultSearch then
            SafeCall("StartDefaultSearch", function()
                pageFrame:StartDefaultSearch()
            end)
            CO:ReapplyOrderNameFontsAfterProfessionRefresh(pageFrame)
            CO:ReprotectOrderListAfterProfessionRefresh(pageFrame)
        else
            CO:RefreshVisibleRows()
            CO:ProtectVisibleRows()
            CO:UpdateControlPanel()
        end
    end)
end

function CO:IsCraftingOrdersPageOpen(pageFrame)
    pageFrame = pageFrame or self.activePageFrame
    return pageFrame and pageFrame.IsShown and pageFrame:IsShown()
end

function CO:IsOrderViewOpen(pageFrame)
    if pageFrame and pageFrame.ahuiCraftingOrdersOrderOpen then
        return true
    end

    local view = pageFrame and pageFrame.OrderView
    if view and view.IsShown and view:IsShown() then
        return true
    end

    if view and view.order and pageFrame and pageFrame.BrowseFrame and pageFrame.BrowseFrame.IsShown and not pageFrame.BrowseFrame:IsShown() then
        return true
    end


    local browse = pageFrame and pageFrame.BrowseFrame
    if browse and browse.IsShown and not browse:IsShown() then
        return true
    end

    return false
end

function CO:IsOrderListOpen(pageFrame)
    if not self:IsCraftingOrdersPageOpen(pageFrame) then
        return false
    end

    if self:IsOrderViewOpen(pageFrame) then
        return false
    end

    local browse = pageFrame and pageFrame.BrowseFrame
    if browse and browse.IsShown then
        return browse:IsShown()
    end

    return true
end

function CO:UpdateControlPanelVisibility(pageFrame)
    local panel = self.controlPanel or (pageFrame and pageFrame.ahuiCraftingOrdersPanel)
    if not panel then return end

    if not self:IsEnabled() then
        panel:Hide()
        if panel.shopButton then panel.shopButton:Hide() end
        if panel.shopCostText then panel.shopCostText:Hide() end
        return
    end

    pageFrame = pageFrame or panel.pageFrame or self.activePageFrame or self:FindOrderPageFrame()
    panel.pageFrame = pageFrame or panel.pageFrame

    if pageFrame and self:IsOrderListOpen(pageFrame) then
        panel:Show()
        if self.AnchorControlPanelToOrderList then self:AnchorControlPanelToOrderList(panel, pageFrame) end
        if panel.shopButton then panel.shopButton:Show() end
        if panel.shopCostText then panel.shopCostText:Show() end
        if self.UpdateTabActionButton then self:UpdateTabActionButton(pageFrame) end
    else
        panel:Hide()
        if panel.shopButton then panel.shopButton:Hide() end
        if panel.shopCostText then panel.shopCostText:Hide() end
    end
end

function CO:GetBindingOwner()
    if not self:IsEnabled() then return nil end

    if not (_G.ProfessionsFrame and ProfessionsFrame:IsShown()) then
        return nil
    end

    if self:IsCraftingOrdersPageOpen(self.activePageFrame) then
        return self.activePageFrame
    end

    for btn in pairs(self.visibleRowButtons) do
        if btn and btn:IsShown() and self:IsCraftingOrdersPageOpen(btn.pageFrame) then
            return btn.pageFrame
        end
    end

    return nil
end

function CO:HasVisibleOrderContext()
    return self:GetBindingOwner() ~= nil
end

function CO:IsOrderPageFrame(frame)
    return frame and frame.OrderView and frame.BrowseFrame
end

function CO:CanPrepareOrderView(pageFrame)
    pageFrame = pageFrame or self.activePageFrame
    local orderView = pageFrame and pageFrame.OrderView
    return orderView and type(orderView.SetOrder) == "function"
end

function CO:FindOrderPageInChildren(root, depth, seen)
    if not root or depth > 5 then return nil end
    seen = seen or {}
    if seen[root] then return nil end
    seen[root] = true

    if self:IsOrderPageFrame(root) then
        return root
    end

    if root.GetChildren then
        local children = { root:GetChildren() }
        for _, child in ipairs(children) do
            local found = self:FindOrderPageInChildren(child, depth + 1, seen)
            if found then return found end
        end
    end

    return nil
end

function CO:FindOrderPageFromAncestry(seed)
    local frame = seed
    local depth = 0
    while frame and depth < 12 do
        if self:IsOrderPageFrame(frame) then
            return frame
        end
        frame = frame.GetParent and frame:GetParent() or nil
        depth = depth + 1
    end
    return nil
end

function CO:FindOrderPageFrame(seed)
    local found = self:FindOrderPageFromAncestry(seed)
    if found then
        return found
    end

    if self:IsOrderPageFrame(self.activePageFrame) and self.activePageFrame:IsShown() then
        return self.activePageFrame
    end

    for btn in pairs(self.visibleRowButtons or {}) do
        if btn and btn:IsShown() then
            local pageFrame = btn.pageFrame
            if self:IsOrderPageFrame(pageFrame) and pageFrame:IsShown() then
                return pageFrame
            end

            pageFrame = self:FindOrderPageFromAncestry(btn:GetParent())
            if self:IsOrderPageFrame(pageFrame) and pageFrame:IsShown() then
                return pageFrame
            end
        end
    end

    local professionsFrame = _G.ProfessionsFrame
    if professionsFrame then
        local candidates = {
            professionsFrame.CraftingOrderPage,
            professionsFrame.OrdersPage,
            professionsFrame.CraftingPage and professionsFrame.CraftingPage.CraftingOrderPage,
            professionsFrame.CraftingPage and professionsFrame.CraftingPage.OrderPage,
            professionsFrame.CraftingPage and professionsFrame.CraftingPage.OrderView and professionsFrame.CraftingPage,
        }

        for _, candidate in ipairs(candidates) do
            if self:IsOrderPageFrame(candidate) and candidate:IsShown() then
                return candidate
            end
        end

        local found = self:FindOrderPageInChildren(professionsFrame, 0, {})
        if self:IsOrderPageFrame(found) and found:IsShown() then
            return found
        end
    end

    return nil
end

function CO:EnsurePageBindingHooks(pageFrame)
    if not pageFrame or pageFrame.ahuiCraftingOrdersBindingHooked then
        return
    end

    pageFrame.ahuiCraftingOrdersBindingHooked = true

    if pageFrame.HookScript then
        pageFrame:HookScript("OnShow", function()
            CO.activePageFrame = pageFrame
            CO:EnsureControlPanel(pageFrame)
            CO:UpdateControlPanelVisibility(pageFrame)
            CO:ApplyTemporaryBinding()
            CO:StartPageProtector(pageFrame)
            CO:RefreshVisibleRowsSoon(0.05)
            CO:WarmVisibleOrderQualitySoon(pageFrame, QUALITY_WARM_START_DELAY)
            if CO.UpdateConflictBar then
                C_Timer.After(0.3, function() CO:UpdateConflictBar(pageFrame) end)
            end
        end)

        pageFrame:HookScript("OnHide", function()
            if CO.activePageFrame == pageFrame then
                CO.activePageFrame = nil
            end
            CO:ClearTemporaryBinding()
            CO:StopRowProgress()
            CO:StopPageProtector()
            if CO.controlPanel then CO.controlPanel:Hide() end
            CO._autoRanForOpen = false
            CO._autoToolRanForOpen = false
        end)
    end

    local function hookVisibility(frame)
        if frame and frame.HookScript and not frame.ahuiCraftingOrdersVisibilityHooked then
            frame.ahuiCraftingOrdersVisibilityHooked = true
            frame:HookScript("OnShow", function()
                if frame == pageFrame.OrderView then
                    pageFrame.ahuiCraftingOrdersOrderOpen = true
                elseif frame == pageFrame.BrowseFrame then
                    pageFrame.ahuiCraftingOrdersOrderOpen = false
                end
                CO:UpdateControlPanelVisibility(pageFrame)
                if frame == pageFrame.BrowseFrame then
                    CO:WarmVisibleOrderQualitySoon(pageFrame, QUALITY_WARM_START_DELAY)
                end
            end)
            frame:HookScript("OnHide", function()
                if frame == pageFrame.BrowseFrame then
                    pageFrame.ahuiCraftingOrdersOrderOpen = true
                elseif frame == pageFrame.OrderView and pageFrame.BrowseFrame and pageFrame.BrowseFrame:IsShown() then
                    pageFrame.ahuiCraftingOrdersOrderOpen = false
                end
                CO:UpdateControlPanelVisibility(pageFrame)
            end)
        end
    end

    hookVisibility(pageFrame.OrderView)
    hookVisibility(pageFrame.BrowseFrame)
end

function CO:SetActiveRowButton(btn)
    if not btn then return end
    self.activeRowButton = btn
    self.activeOrderID = btn.orderID or self.activeOrderID
    self.activePageFrame = btn.pageFrame or self.activePageFrame
    self:ApplyTemporaryBinding()
end

function CO:CreateHotkeyProxy()
    if self.hotkeyProxy then return self.hotkeyProxy end

    local proxy = CreateFrame("Button", HOTKEY_PROXY_NAME, UIParent)
    proxy:RegisterForClicks("LeftButtonUp")
    proxy:SetScript("OnClick", function()
        CO:RunActiveRowAction()
    end)
    proxy:Hide()

    self.hotkeyProxy = proxy
    return proxy
end

function CO:ApplyTemporaryBinding()
    local db = GetDB()
    local proxy = self:CreateHotkeyProxy()

    if InCombatLockdown() then
        self.pendingBindingRefresh = true
        return false
    end


    ClearOverrideBindings(proxy)

    if self.bindingOwner then
        ClearOverrideBindings(self.bindingOwner)
        self.bindingOwner = nil
    end

    local owner = self:GetBindingOwner()
    local bindingApplied = false
    if owner and db.binding and db.binding ~= "" then
        SetOverrideBindingClick(proxy, false, db.binding, HOTKEY_PROXY_NAME, "LeftButton")
        bindingApplied = true
    end

    -- In one-button mode the normal Interact With Target key becomes the
    -- order action key only while the crafting-order page is visible. The
    -- original binding is restored automatically by ClearOverrideBindings.
    if owner and self.ApplyOneButtonInteractBindings then
        bindingApplied = self:ApplyOneButtonInteractBindings(proxy) or bindingApplied
    end

    if bindingApplied then
        self.bindingOwner = proxy
        self:StartBindingWatchdog()
    end

    self.pendingBindingRefresh = false
    return true
end

function CO:StartBindingWatchdog()
    if self.bindingWatchdog then return end
    if not (C_Timer and C_Timer.NewTicker) then return end
    self.bindingWatchdog = C_Timer.NewTicker(0.5, function()
        if not CO.bindingOwner then
            CO:StopBindingWatchdog()
            return
        end
        if InCombatLockdown() then return end
        if not CO:GetBindingOwner() then
            CO:ClearTemporaryBinding()
        end
    end)
end

function CO:StopBindingWatchdog()
    if self.bindingWatchdog and self.bindingWatchdog.Cancel then
        self.bindingWatchdog:Cancel()
    end
    self.bindingWatchdog = nil
end

function CO:ClearTemporaryBinding()
    if InCombatLockdown() then
        self.pendingBindingRefresh = true
        return false
    end

    self:StopBindingWatchdog()

    if self.bindingOwner then
        ClearOverrideBindings(self.bindingOwner)
        self.bindingOwner = nil
    end


    if self.hotkeyProxy then
        ClearOverrideBindings(self.hotkeyProxy)
    end

    self.pendingBindingRefresh = false
    return true
end

function CO:SetBinding(binding)
    local db = GetDB()
    db.binding = binding and binding ~= "" and binding or nil

    if db.binding and db.binding ~= "" and self:HasVisibleOrderContext() then
        self:ApplyTemporaryBinding()
    else
        self:ClearTemporaryBinding()
    end

    self:UpdateControlPanel()
end

function CO:ClearBinding()
    local db = GetDB()
    db.binding = nil
    self:ClearTemporaryBinding()
    self:UpdateControlPanel()
end

function CO:CreateBindCapture()
    if self.bindCapture then return end

    local f = CreateFrame("Frame", "HironCraftProfitCraftingOrdersBindCapture", UIParent, "BackdropTemplate")
    f:SetAllPoints(UIParent)
    f:SetFrameStrata("DIALOG")
    f:EnableKeyboard(true)
    f:EnableMouse(true)
    f:Hide()

    local box = CreateFrame("Frame", nil, f, "BackdropTemplate")
    box:SetSize(390, 112)
    box:SetPoint("CENTER")
    box:EnableMouse(false)
    CreateBackdrop(box, 0.96)
    f.box = box

    f.text = box:CreateFontString(nil, "OVERLAY")
    ApplyFont(f.text, 13, "")
    f.text:SetWidth(350)
    f.text:SetJustifyH("CENTER")
    f.text:SetPoint("CENTER")
    f.text:SetText(T("COA_BIND_CAPTURE", "Press a keyboard key or side mouse button (Button4/Button5).\nEsc or left/right click — cancel."))

    local function FinishCapture(self, key)
        local binding = NormalizeBindingKey(key)
        if not binding then return false end

        CO:SetBinding(binding)
        self:Hide()
        CO:SetStatus(T("COA_STATUS_BIND_SET", "Order hotkey assigned.") .. " " .. BindingText(binding))
        return true
    end

    f:SetScript("OnShow", function(self)
        self:SetPropagateKeyboardInput(false)
        if self.SetPropagateMouseClicks then
            self:SetPropagateMouseClicks(false)
        end
    end)

    f:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
            return
        end

        FinishCapture(self, key)
    end)

    f:SetScript("OnMouseDown", function(self, button)
        if type(button) == "string" and button:match("^Button%d+$") then
            FinishCapture(self, button)
            return
        end

        self:Hide()
    end)

    self.bindCapture = f
end

function CO:GetSelectedReagent(orderID, slotIndex)
    local key = MakeReagentSelectionKey(orderID, slotIndex)
    return key and self.selectedReagents[key] or nil
end

function CO:GetSelectedReagentForEntry(orderID, reagentEntry)
    if not reagentEntry then return nil end

    local entryKey = MakeReagentSelectionKeyForEntry(orderID, reagentEntry)
    if entryKey and self.selectedReagents[entryKey] then
        return self.selectedReagents[entryKey]
    end

    local primarySlotIndex = reagentEntry.dataSlotIndex or reagentEntry.slotIndex
    local legacyPrimaryKey = MakeReagentSelectionKey(orderID, primarySlotIndex)
    if entryKey and legacyPrimaryKey and entryKey ~= legacyPrimaryKey then
        return nil
    end

    local selected = self:GetSelectedReagent(orderID, primarySlotIndex)
    if selected then return selected end

    local fallbackSlotIndex = reagentEntry.slotIndex
    if fallbackSlotIndex ~= nil and fallbackSlotIndex ~= primarySlotIndex then
        return self:GetSelectedReagent(orderID, fallbackSlotIndex)
    end

    return nil
end

function CO:SetSelectedReagent(orderID, slotIndex, reagent)
    local key = MakeReagentSelectionKey(orderID, slotIndex)
    if not key then return end
    if reagent then
        self.selectedReagents[key] = reagent
    else
        self.selectedReagents[key] = nil
    end
    self:InvalidateOrderCaches(orderID)
    self:RefreshVisibleRowsSoon()
    if self.UpdateControlPanel then
        self:UpdateControlPanel()
    end
end

function CO:SetSelectedReagentForEntry(orderID, reagentEntry, reagent)
    local key = MakeReagentSelectionKeyForEntry(orderID, reagentEntry)
    if not key then return end

    if reagent then
        self.selectedReagents[key] = reagent
    else
        self.selectedReagents[key] = nil
    end

    local primarySlotIndex = reagentEntry and (reagentEntry.dataSlotIndex or reagentEntry.slotIndex)
    local legacyKey = MakeReagentSelectionKey(orderID, primarySlotIndex)
    if legacyKey and legacyKey ~= key then
        self.selectedReagents[legacyKey] = nil
    end

    local fallbackSlotIndex = reagentEntry and reagentEntry.slotIndex
    local fallbackKey = MakeReagentSelectionKey(orderID, fallbackSlotIndex)
    if fallbackKey and fallbackKey ~= key then
        self.selectedReagents[fallbackKey] = nil
    end

    self:InvalidateOrderCaches(orderID)
    self:RefreshVisibleRowsSoon()
    if self.UpdateControlPanel then
        self:UpdateControlPanel()
    end
end

function GetSchematicSlotQuantity(slotSchematic, orderReagent)
    return (orderReagent and GetOrderReagentQuantity(orderReagent))
        or (slotSchematic and slotSchematic.quantityRequired)
        or 0
end

function FindOrderReagentForSlot(order, slotIndex, dataSlotIndex, itemID)
    if not order or not order.reagents then return nil end
    local itemMatch
    for _, reagentInfo in ipairs(order.reagents) do
        local rSlotIndex = GetOrderReagentSlotIndex(reagentInfo)
        local rDataSlotIndex = GetOrderReagentDataSlotIndex(reagentInfo)
        if (slotIndex ~= nil and rSlotIndex == slotIndex)
        or (dataSlotIndex ~= nil and rDataSlotIndex == dataSlotIndex) then
            return reagentInfo
        end

        if itemID and GetOrderReagentItemID(reagentInfo) == itemID then
            itemMatch = itemMatch or reagentInfo
        end
    end
    return itemMatch
end

function CollectOrderReagentsForSlot(order, slotIndex, dataSlotIndex, itemID)
    local itemMatches = {}
    local slotMatchesWithoutItem = {}
    itemID = tonumber(itemID)
    if not order or type(order.reagents) ~= "table" then return itemMatches end

    for _, reagentInfo in ipairs(order.reagents) do
        local rItemID = tonumber(GetOrderReagentItemID(reagentInfo))

        if itemID and rItemID == itemID then
            itemMatches[#itemMatches + 1] = reagentInfo
        elseif not rItemID then
            local rSlotIndex = GetOrderReagentSlotIndex(reagentInfo)
            local rDataSlotIndex = GetOrderReagentDataSlotIndex(reagentInfo)
            if (slotIndex ~= nil and rSlotIndex ~= nil and rSlotIndex == slotIndex)
            or (dataSlotIndex ~= nil and rDataSlotIndex ~= nil and rDataSlotIndex == dataSlotIndex) then
                slotMatchesWithoutItem[#slotMatchesWithoutItem + 1] = reagentInfo
            end
        end
    end

    if #itemMatches > 0 then return itemMatches end
    return slotMatchesWithoutItem
end

function GetSlotRequiredQuantity(slotSchematic, firstPayload, orderReagent)
    local quantity = tonumber(slotSchematic and (slotSchematic.quantityRequired or slotSchematic.quantity or slotSchematic.requiredQuantity))
        or tonumber(firstPayload and (firstPayload.quantityRequired or firstPayload.quantity or firstPayload.requiredQuantity))

    if quantity and quantity > 0 then
        return quantity
    end

    quantity = tonumber(orderReagent and GetOrderReagentQuantity(orderReagent))
    if quantity and quantity > 0 then
        return quantity
    end

    return 0
end

function GetSlotReagentType(slotSchematic)
    if not slotSchematic then return nil end
    return slotSchematic.reagentType or (slotSchematic.slotInfo and slotSchematic.slotInfo.reagentType)
end

function IsBasicOrAutomaticReagentSlot(slotSchematic)
    local reagentType = GetSlotReagentType(slotSchematic)
    if not Enum or not Enum.CraftingReagentType then
        return reagentType == nil or not (slotSchematic and (slotSchematic.optional == true or slotSchematic.isOptional == true))
    end

    local CRT = Enum.CraftingReagentType
    if reagentType == nil then return true end
    return reagentType == CRT.Basic or reagentType == CRT.Automatic
end

function IsOptionalOrFinishingReagentSlot(slotSchematic)
    if not slotSchematic then return false end
    if slotSchematic.optional == true or slotSchematic.isOptional == true then return true end
    if slotSchematic.required == false or slotSchematic.isRequired == false then return true end

    local reagentType = GetSlotReagentType(slotSchematic)
    if Enum and Enum.CraftingReagentType then
        local CRT = Enum.CraftingReagentType
        if CRT.Modifying ~= nil and reagentType == CRT.Modifying then return true end
        if CRT.Optional ~= nil and reagentType == CRT.Optional then return true end
        if CRT.Finishing ~= nil and reagentType == CRT.Finishing then return true end
    end

    if Enum and Enum.TradeskillSlotDataType and slotSchematic.dataSlotType == Enum.TradeskillSlotDataType.ModifiedReagent then
        return true
    end

    return false
end

function SlotHasCrafterOrderMatch(matches)
    for _, reagentInfo in ipairs(matches or {}) do
        if IsCrafterProvidedReagent(reagentInfo) then
            return true
        end
    end
    return false
end

function ShouldUseSchematicSlotForCrafterReagents(slotSchematic, matches)
    if SlotHasCrafterOrderMatch(matches) then return true end
    if slotSchematic and (slotSchematic.required == true or slotSchematic.isRequired == true) then return true end
    if IsOptionalOrFinishingReagentSlot(slotSchematic) then return false end
    if SlotHasRequiredQuantity(slotSchematic) and IsBasicOrAutomaticReagentSlot(slotSchematic) then return true end
    return IsBasicOrAutomaticReagentSlot(slotSchematic)
end

function MakeReagentEntrySeenKey(slotIndex, dataSlotIndex, itemID, schematicIndex)
    if schematicIndex ~= nil then
        return "schematic:" .. tostring(schematicIndex)
    end
    if itemID ~= nil then
        return "item:" .. tostring(itemID)
    end
    if slotIndex ~= nil or dataSlotIndex ~= nil then
        return "slot:" .. tostring(slotIndex or "") .. ":" .. tostring(dataSlotIndex or "")
    end
    return nil
end

function MarkReagentEntrySeen(seen, slotIndex, dataSlotIndex, itemID, schematicIndex)
    local key = MakeReagentEntrySeenKey(slotIndex, dataSlotIndex, itemID, schematicIndex)
    if key then seen[key] = true end
end

function IsReagentEntrySeen(seen, slotIndex, dataSlotIndex, itemID, schematicIndex)
    local key = MakeReagentEntrySeenKey(slotIndex, dataSlotIndex, itemID, schematicIndex)
    return key and seen[key] == true
end

function HasProvidedByCrafterFlag(tbl)
    return type(tbl) == "table" and (
        tbl.providedByCrafter == true
        or tbl.crafterProvided == true
        or tbl.isCrafterProvided == true
        or tbl.isProvidedByCrafter == true
        or tbl.providedByPlayer == true
        or tbl.playerProvided == true
        or tbl.isPlayerProvided == true
    )
end

function IsExplicitCrafterOrderReagent(reagentInfo)
    if not reagentInfo then return false end
    if IsCustomerProvidedReagent(reagentInfo) then return false end

    local payload = GetOrderReagentPayload(reagentInfo)
    if HasProvidedByCrafterFlag(reagentInfo) or HasProvidedByCrafterFlag(payload) then
        return true
    end

    local source = GetReagentSourceValue(reagentInfo, payload)
    return IsStrictCrafterSourceValue(source) == true
end

function IsOrderCustomerProvidedReagent(reagentInfo)
    if not reagentInfo then return false end
    if IsCustomerProvidedReagent(reagentInfo) then return true end

    local payload = GetOrderReagentPayload(reagentInfo)
    local source = GetReagentSourceValue(reagentInfo, payload)
    if IsStrictCrafterSourceValue(source) then return false end
    if HasProvidedByCrafterFlag(reagentInfo) or HasProvidedByCrafterFlag(payload) then return false end

    return true
end

function GetSchematicReagentChoices(slotSchematic)
    if not slotSchematic then return nil end
    return slotSchematic.reagents or slotSchematic.reagentInfoTbl or slotSchematic.reagentInfos
end

function GetSchematicChoiceItemID(choice)
    if not choice then return nil end
    local payload = GetOrderReagentPayload(choice)
    return tonumber(GetOrderReagentItemID(payload) or GetOrderReagentItemID(choice))
end

function GetFirstSchematicChoice(slotSchematic)
    local choices = GetSchematicReagentChoices(slotSchematic)
    if type(choices) ~= "table" then return nil, nil end

    for _, choice in ipairs(choices) do
        local itemID = GetSchematicChoiceItemID(choice)
        if itemID then
            return choice, itemID
        end
    end

    for _, choice in pairs(choices) do
        local itemID = GetSchematicChoiceItemID(choice)
        if itemID then
            return choice, itemID
        end
    end

    return nil, nil
end

function MakeProvidedReagentSlotKey(slotIndex, dataSlotIndex)
    if slotIndex == nil and dataSlotIndex == nil then return nil end
    return tostring(slotIndex or "") .. ":" .. tostring(dataSlotIndex or "")
end

function GetOrderProvidedReagentQuantities(order)
    local provided = { entries = {}, bySlot = {} }
    if not order or type(order.reagents) ~= "table" then return provided end

    for _, reagentInfo in ipairs(order.reagents) do
        if IsOrderCustomerProvidedReagent(reagentInfo) then
            local itemID = tonumber(GetOrderReagentItemID(reagentInfo))
            if itemID then
                local quantity = tonumber(GetOrderReagentQuantity(reagentInfo)) or 0
                if quantity <= 0 then quantity = 1000000000 end

                local dataSlotIndex = GetOrderReagentDataSlotIndex(reagentInfo)
                local slotIndex = GetOrderReagentSlotIndex(reagentInfo)
                local slotKey = MakeProvidedReagentSlotKey(slotIndex, dataSlotIndex)

                local entry = {
                    itemID = itemID,
                    quantity = quantity,
                    remaining = quantity,
                    dataSlotIndex = dataSlotIndex,
                    slotIndex = slotIndex,
                    slotKey = slotKey,
                }

                provided.entries[#provided.entries + 1] = entry
                provided[itemID] = (provided[itemID] or 0) + quantity
                if slotKey then
                    provided.bySlot[slotKey] = (provided.bySlot[slotKey] or 0) + quantity
                end
            end
        end
    end

    return provided
end

function IsOrderReagentStateAllProvided(order)
    if not order then return false end
    if Enum and Enum.CraftingOrderReagentsType and Enum.CraftingOrderReagentsType.All ~= nil then
        return order.reagentState == Enum.CraftingOrderReagentsType.All
    end
    return tonumber(order.reagentState) == 0
end

function BuildSchematicChoiceItemSet(slotSchematic)
    local set = {}
    local choices = GetSchematicReagentChoices(slotSchematic)
    if type(choices) ~= "table" then return set end

    local function AddChoice(choice)
        local itemID = GetSchematicChoiceItemID(choice)
        if itemID then set[itemID] = true end
    end

    for _, choice in ipairs(choices) do
        AddChoice(choice)
    end
    for _, choice in pairs(choices) do
        AddChoice(choice)
    end

    return set
end

function DoesProvidedEntryMatchSchematicSlot(entry, choiceItemIDs, slotIndex, dataSlotIndex, slotKey, exactOnly)
    if type(entry) ~= "table" then return false end

    if entry.itemID ~= nil then
        return choiceItemIDs and choiceItemIDs[entry.itemID] == true
    end

    if slotKey and entry.slotKey and entry.slotKey == slotKey then
        return true
    end
    if dataSlotIndex ~= nil and entry.dataSlotIndex ~= nil and entry.dataSlotIndex == dataSlotIndex then
        return true
    end
    if slotIndex ~= nil and entry.slotIndex ~= nil and entry.slotIndex == slotIndex then
        return true
    end

    return false
end

function ConsumeProvidedEntry(entry, need)
    if type(entry) ~= "table" then return 0 end
    local remaining = tonumber(entry.remaining)
    if not remaining or remaining <= 0 then return 0 end

    need = tonumber(need)
    if not need or need <= 0 then return 0 end

    local used = math.min(remaining, need)
    entry.remaining = remaining - used
    return used
end

function GetProvidedQuantityForSchematicSlot(slotSchematic, provided, requiredQuantity, slotIndex, dataSlotIndex)
    if type(provided) ~= "table" or type(provided.entries) ~= "table" then return 0 end

    requiredQuantity = tonumber(requiredQuantity) or 0
    if requiredQuantity <= 0 then return 0 end

    local choices = GetSchematicReagentChoices(slotSchematic)
    if type(choices) ~= "table" then return 0 end

    local choiceItemIDs = BuildSchematicChoiceItemSet(slotSchematic)
    local slotKey = MakeProvidedReagentSlotKey(slotIndex, dataSlotIndex)
    local quantity = 0

    local function TakeMatching(exactOnly)
        for _, entry in ipairs(provided.entries) do
            if quantity >= requiredQuantity then return end
            if DoesProvidedEntryMatchSchematicSlot(entry, choiceItemIDs, slotIndex, dataSlotIndex, slotKey, exactOnly) then
                quantity = quantity + ConsumeProvidedEntry(entry, requiredQuantity - quantity)
            end
        end
    end

    TakeMatching(true)
    TakeMatching(false)

    return quantity
end

function BuildOrderReagentCacheSignature(order)
    if not order then return "nil" end

    local parts = {
        tostring(order.reagentState or ""),
        tostring(order.spellID or ""),
        tostring(order.isRecraft == true),
    }

    local reagents = order.reagents
    parts[#parts + 1] = tostring(type(reagents) == "table" and #reagents or 0)

    if type(reagents) == "table" then
        for index, reagentInfo in ipairs(reagents) do
            local payload = GetOrderReagentPayload(reagentInfo)
            local source = GetReagentSourceValue(reagentInfo, payload)
            parts[#parts + 1] = table.concat({
                tostring(index),
                tostring(GetOrderReagentItemID(reagentInfo) or ""),
                tostring(GetOrderReagentDataSlotIndex(reagentInfo) or ""),
                tostring(GetOrderReagentSlotIndex(reagentInfo) or ""),
                tostring(GetOrderReagentQuantity(reagentInfo) or 0),
                tostring(source or ""),
                HasProvidedByCustomerFlag(reagentInfo) and "C" or "",
                HasProvidedByCrafterFlag(reagentInfo) and "P" or "",
            }, "/")
        end
    end

    return table.concat(parts, "|")
end

function CO:BuildDisplayReagents(order)
    local list = {}
    if not order or not order.spellID then return list end

    local orderKey = OrderKey(order.orderID)
    local reagentSignature = BuildOrderReagentCacheSignature(order)
    if orderKey then
        local cache = self.displayReagentsCache and self.displayReagentsCache[orderKey]
        local now = CacheNow()
        if cache
        and cache.expiresAt
        and cache.expiresAt > now
        and cache.spellID == order.spellID
        and cache.isRecraft == order.isRecraft
        and cache.reagentSignature == reagentSignature then
            return cache.value or list
        end
    end

    local schematic
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic then
        local ok, result = pcall(C_TradeSkillUI.GetRecipeSchematic, order.spellID, order.isRecraft)
        if ok then schematic = result end
    end

    local seen = {}

    local function addEntry(itemID, quantity, slotIndex, dataSlotIndex, source, orderReagent, slotSchematic, candidates, qualityPayload, schematicIndex)
        itemID = tonumber(itemID)
        quantity = tonumber(quantity) or 0
        if not itemID or itemID <= 0 or quantity <= 0 then return false end
        if IsReagentEntrySeen(seen, slotIndex, dataSlotIndex, itemID, schematicIndex) then return false end

        local entry = {
            itemID = itemID,
            quantity = quantity,
            slotIndex = slotIndex,
            dataSlotIndex = dataSlotIndex,
            schematicIndex = schematicIndex,
            selectionToken = schematicIndex and ("schematic:" .. tostring(schematicIndex)) or (dataSlotIndex or slotIndex),
            source = source,
            orderReagent = orderReagent,
            slotSchematic = slotSchematic,
            candidates = candidates or {},
            crafterRequired = true,
        }

        CopyReagentQualityFields(entry, qualityPayload or GetOrderReagentPayload(orderReagent) or slotSchematic, itemID)
        list[#list + 1] = entry
        MarkReagentEntrySeen(seen, slotIndex, dataSlotIndex, itemID, schematicIndex)
        return true
    end

    local schematicReady = schematic and schematic.reagentSlotSchematics
    list.ahuiSchematicReady = schematicReady == true

    if schematicReady and not IsOrderReagentStateAllProvided(order) then
        local providedByItemID = GetOrderProvidedReagentQuantities(order)

        for index, slotSchematic in ipairs(schematic.reagentSlotSchematics) do
            if IsRequiredCraftingOrderReagentSlot(slotSchematic) then
                local choices = GetSchematicReagentChoices(slotSchematic)
                local firstChoice, firstItemID = GetFirstSchematicChoice(slotSchematic)
                local firstPayload = firstChoice and GetOrderReagentPayload(firstChoice)
                local dataSlotIndex = slotSchematic.dataSlotIndex or slotSchematic.slotDataIndex or index
                local slotIndex = slotSchematic.slotIndex or dataSlotIndex or index
                local requiredQuantity = GetSlotRequiredQuantity(slotSchematic, firstPayload, nil)

                if firstItemID and requiredQuantity and requiredQuantity > 0 then
                    local providedQuantity = GetProvidedQuantityForSchematicSlot(slotSchematic, providedByItemID, requiredQuantity, slotIndex, dataSlotIndex)
                    local quantity = math.max(0, requiredQuantity - (tonumber(providedQuantity) or 0))

                    if quantity > 0 then
                        local itemID = firstItemID
                        local source = Enum and Enum.CraftingOrderReagentSource and Enum.CraftingOrderReagentSource.Crafter or 2
                        addEntry(itemID, quantity, slotIndex, dataSlotIndex, source, nil, slotSchematic, choices or {}, firstPayload or slotSchematic, index)
                    end
                end
            end
        end
    end


    if orderKey and (schematicReady or IsOrderReagentStateAllProvided(order) or #list > 0) then
        self.displayReagentsCache[orderKey] = {
            spellID = order.spellID,
            isRecraft = order.isRecraft,
            reagentSignature = reagentSignature,
            value = list,
            expiresAt = CacheNow() + REAGENT_CACHE_TTL,
        }
    end

    return list
end

function CO:ShouldRejectForMissingCustomerReagents(order)
    if not order or not order.orderID or not order.spellID then
        return false
    end

    local personalType = Enum
        and Enum.CraftingOrderType
        and Enum.CraftingOrderType.Personal
    if personalType == nil or order.orderType ~= personalType then
        return false
    end

    if IsOrderReagentStateAllProvided(order) then
        return false
    end

    -- BuildDisplayReagents contains only the missing quantity from required
    -- basic/automatic schematic slots. Optional, modifying and finishing slots
    -- are excluded. Do not decline when Blizzard has not supplied a schematic:
    -- an unknown answer must never become a destructive action.
    local missing = self:BuildDisplayReagents(order)
    if type(missing) ~= "table" or missing.ahuiSchematicReady ~= true then
        return false
    end

    return #missing > 0, missing
end

function CO:GetReagentCandidates(order, reagentEntry)
    local candidates = {}
    if not order or not reagentEntry then return candidates end

    local dataSlotIndex = reagentEntry.dataSlotIndex or GetOrderReagentDataSlotIndex(reagentEntry)
    local slotIndex = reagentEntry.slotIndex or GetOrderReagentSlotIndex(reagentEntry) or dataSlotIndex
    local quantity = reagentEntry.quantity or GetOrderReagentQuantity(reagentEntry)

    local function AddCandidate(reagent)
        if not reagent then return end
        local payload = reagent.reagent or reagent
        local itemID = payload.itemID or payload.itemId
        if not itemID then return end
        for _, existing in ipairs(candidates) do
            if existing.itemID == itemID then return end
        end
        local candidate = {
            itemID = itemID,
            dataSlotIndex = payload.dataSlotIndex or dataSlotIndex,
            quantity = quantity,
            slotIndex = slotIndex,
        }
        CopyReagentQualityFields(candidate, payload, itemID)
        candidates[#candidates + 1] = candidate
    end

    AddCandidate(reagentEntry)
    AddCandidate(reagentEntry.orderReagent and GetOrderReagentPayload(reagentEntry.orderReagent))

    for _, reagent in ipairs(reagentEntry.candidates or {}) do
        AddCandidate(reagent)
    end

    if #candidates == 0 and C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic then
        local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, order.spellID, order.isRecraft)
        if ok and schematic and schematic.reagentSlotSchematics then
            for index, slotSchematic in ipairs(schematic.reagentSlotSchematics) do
                local schematicDataSlot = slotSchematic.dataSlotIndex or index
                local schematicSlot = slotSchematic.slotIndex or schematicDataSlot or index
                if schematicDataSlot == dataSlotIndex or schematicSlot == slotIndex then
                    local reagents = slotSchematic.reagents or slotSchematic.reagentInfoTbl or slotSchematic.reagentInfos
                    if reagents then
                        for _, reagent in ipairs(reagents) do
                            AddCandidate(reagent)
                        end
                    end
                end
            end
        end
    end

    table.sort(candidates, function(a, b)
        return (a.itemID or 0) < (b.itemID or 0)
    end)

    return candidates
end

function CO:ApplySelectedReagentsToEngine(engine, order)
    if not engine or not order then return true end

    local form = engine.OrderDetails and engine.OrderDetails.SchematicForm
    local transaction = form and ((form.GetTransaction and form:GetTransaction()) or form.transaction)
    if not transaction then return true end

    local orderKey = OrderKey(order.orderID)
    if not orderKey then return true end

    local applied = false
    for key, selected in pairs(self.selectedReagents or {}) do
        if type(key) == "string" and key:match("^" .. orderKey .. ":") and selected then
            local slotIndex = selected.slotIndex or selected.dataSlotIndex
            if slotIndex and type(selected.mix) == "table" and #selected.mix > 0 then
                if self:AllocateMixToTransaction(transaction, slotIndex, selected.mix) then
                    applied = true
                elseif selected.itemID and (tonumber(selected.quantity) or 0) > 0 then
                    local reagent = { itemID = selected.itemID }
                    local ok = SafeCall("OverwriteAllocation", function()
                        transaction:OverwriteAllocation(slotIndex, reagent, tonumber(selected.quantity))
                    end)
                    if ok then applied = true end
                end
            elseif slotIndex and selected.itemID and (tonumber(selected.quantity) or 0) > 0 then
                local quantity = tonumber(selected.quantity)
                local reagent = { itemID = selected.itemID }
                local ok = SafeCall("OverwriteAllocation", function()
                    transaction:OverwriteAllocation(slotIndex, reagent, quantity)
                end)
                if ok then applied = true end
            end
        end
    end

    if applied then
        if engine.UpdateCreateButton then
            SafeCall("UpdateCreateButton", function() engine:UpdateCreateButton() end)
        end
        if form.UpdateDetailsStats then
            SafeCall("UpdateDetailsStats", function() form:UpdateDetailsStats() end)
        end
    end

    return true
end

function CO:GetTransactionFromEngine(engine)
    local form = engine and engine.OrderDetails and engine.OrderDetails.SchematicForm
    return form and ((form.GetTransaction and form:GetTransaction()) or form.transaction), form
end

function CO:AllocateMixToTransaction(transaction, slotIndex, mix)
    if not transaction or not slotIndex or type(mix) ~= "table" or #mix == 0 then return false end
    if type(transaction.GetAllocations) ~= "function" or type(transaction.OverwriteAllocations) ~= "function" then
        return false
    end

    return SafeCall("AllocateMixToTransaction", function()
        local allocations = transaction:GetAllocations(slotIndex)
        if not (allocations and allocations.Clear and allocations.Allocate) then
            error("no allocations object")
        end
        allocations:Clear()
        for _, part in ipairs(mix) do
            if part.itemID and part.quantity and part.quantity > 0 then
                allocations:Allocate({ itemID = part.itemID }, part.quantity)
            end
        end
        transaction:OverwriteAllocations(slotIndex, allocations)
        if transaction.SetManuallyAllocated then
            transaction:SetManuallyAllocated(true)
        end
    end) == true
end

function CO:SetEngineConcentration(engine, useConcentration)
    local transaction, form = self:GetTransactionFromEngine(engine)
    if not transaction then return false end

    if transaction.SetApplyConcentration then
        SafeCall("SetApplyConcentration", function()
            transaction:SetApplyConcentration(useConcentration == true)
        end)
    elseif transaction.SetApplyingConcentration then
        SafeCall("SetApplyingConcentration", function()
            transaction:SetApplyingConcentration(useConcentration == true)
        end)
    else
        return false
    end

    if form and form.UpdateDetailsStats then
        SafeCall("UpdateDetailsStats", function() form:UpdateDetailsStats() end)
    end
    if engine and engine.UpdateCreateButton then
        SafeCall("UpdateCreateButton", function() engine:UpdateCreateButton() end)
    end

    return true
end

function CO:BuildCraftingReagentInfoTbl(order)
    local list = {}
    if not order then return list end

    local orderKey = OrderKey(order.orderID)
    local revision = GetOrderRevision(self, order and order.orderID)
    local reagentSignature = BuildOrderReagentCacheSignature(order)
    local cacheKey = orderKey and (orderKey .. ":" .. tostring(revision) .. ":" .. tostring(reagentSignature))
    if cacheKey then
        local cache = self.craftingReagentInfoCache and self.craftingReagentInfoCache[cacheKey]
        local now = CacheNow()
        if cache and cache.expiresAt and cache.expiresAt > now then
            return cache.value or list
        end
    end

    local displayReagents = self:BuildDisplayReagents(order)
    if not IsOrderReagentStateAllProvided(order)
    and displayReagents
    and displayReagents.ahuiSchematicReady == false
    and #displayReagents == 0 then
        return list
    end

    local seenSlot = {}

    if order.reagents and type(order.reagents) == "table" then
        for _, r in ipairs(order.reagents) do
            local reagentInfo = r.reagentInfo or r
            local reagent = reagentInfo and reagentInfo.reagent
            local slot = r.slotIndex or (reagentInfo and reagentInfo.dataSlotIndex)
            local itemID = reagent and reagent.itemID
            local quantity = (reagentInfo and reagentInfo.quantity) or r.quantity or 1
            if slot and itemID and quantity > 0 and not seenSlot[slot] then
                seenSlot[slot] = true
                list[#list + 1] = {
                    itemID = itemID,
                    dataSlotIndex = slot,
                    quantity = quantity,
                }
            end
        end
    end

    for _, reagentEntry in ipairs(displayReagents) do
        if not IsCustomerProvidedReagent(reagentEntry) then
            local selected = self:GetSelectedReagentForEntry(order.orderID, reagentEntry)
            local itemID = selected and selected.itemID or reagentEntry.itemID
            local quantity = (selected and selected.quantity) or reagentEntry.quantity or 0
            local dataSlotIndex = (selected and selected.dataSlotIndex) or reagentEntry.dataSlotIndex or reagentEntry.slotIndex

            if itemID and dataSlotIndex and quantity and quantity > 0 and not seenSlot[dataSlotIndex] then
                seenSlot[dataSlotIndex] = true
                list[#list + 1] = {
                    itemID = itemID,
                    dataSlotIndex = dataSlotIndex,
                    quantity = quantity,
                }
            end
        end
    end

    if cacheKey then
        self.craftingReagentInfoCache[cacheKey] = {
            value = list,
            expiresAt = CacheNow() + REAGENT_CACHE_TTL,
        }
    end

    return list
end

function CO:BuildFastCraftingReagentInfoTbl(order)
    local list = {}
    if not order or not order.spellID then return list end

    local providedSlots = {}
    if order.reagents and type(order.reagents) == "table" then
        for _, r in ipairs(order.reagents) do
            local reagentInfo = r.reagentInfo or r
            local reagent = reagentInfo and reagentInfo.reagent
            local slot = r.slotIndex or (reagentInfo and reagentInfo.dataSlotIndex)
            local itemID = reagent and reagent.itemID
            local qty = (reagentInfo and reagentInfo.quantity) or r.quantity or 1
            if slot then
                providedSlots[slot] = true
                if itemID and qty > 0 then
                    list[#list + 1] = {
                        itemID = itemID,
                        dataSlotIndex = slot,
                        quantity = qty,
                    }
                end
            end
        end
    end

    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic then
        local okSch, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, order.spellID, false)
        if okSch and schematic and type(schematic.reagentSlotSchematics) == "table" then
            local basicEnum = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic
            for _, slot in ipairs(schematic.reagentSlotSchematics) do
                local slotIndex = slot.dataSlotIndex or slot.slotIndex
                local isBasic = (slot.reagentType == basicEnum) or (basicEnum == nil)
                local hasOptions = slot.reagents and #slot.reagents > 0
                local required = (slot.required == true) or (slot.required == nil and isBasic)
                if slotIndex and isBasic and required and hasOptions and not providedSlots[slotIndex] then
                    local pick = slot.reagents[1]
                    local itemID = pick and pick.itemID
                    local qty = tonumber(slot.quantityRequired) or tonumber(pick and pick.quantity) or 1
                    if itemID and qty > 0 then
                        list[#list + 1] = {
                            itemID = itemID,
                            dataSlotIndex = slotIndex,
                            quantity = qty,
                        }
                    end
                end
            end
        end
    end

    return list
end

function CO:GetFastConcentrationCost(order)
    if not order or not order.spellID then return nil end
    if not C_TradeSkillUI then return nil end

    local cacheKey = OrderKey(order.orderID)
    if cacheKey and self._fastConcCostCache then
        local cached = self._fastConcCostCache[cacheKey]
        if cached and cached.expiresAt and cached.expiresAt > CacheNow() then
            return cached.value
        end
    end

    local function tryGetCost()
        local reagents = self:BuildFastCraftingReagentInfoTbl(order)
        local attempts = {
            { C_TradeSkillUI.GetCraftingOperationInfo, { order.spellID, reagents, nil, true } },
        }
        if C_TradeSkillUI.GetCraftingOperationInfoForOrder and order.orderID then
            attempts[#attempts + 1] = { C_TradeSkillUI.GetCraftingOperationInfoForOrder, { order.spellID, reagents, order.orderID, true } }
        end
        for _, a in ipairs(attempts) do
            local ok, info = pcall(a[1], unpack(a[2]))
            if ok and info then
                local cost = tonumber(info.concentrationCost)
                    or (info.concentrationCosts and tonumber(info.concentrationCosts[1]))
                if cost and cost > 0 then return cost end
            end
        end
        return nil
    end

    local cost = tryGetCost()
    if cost and cost > 0 then
        self._fastConcCostCache = self._fastConcCostCache or {}
        if cacheKey then
            self._fastConcCostCache[cacheKey] = { value = cost, expiresAt = CacheNow() + 60 }
        end
        return cost
    end

    return nil
end

function CO:GetOrderOperationInfo(order, applyConcentration)
    if not order or not order.spellID or not C_TradeSkillUI or not C_TradeSkillUI.GetCraftingOperationInfoForOrder then
        return nil
    end

    local reagentTbl = self:BuildCraftingReagentInfoTbl(order)
    local attempts = {
        { order.spellID, reagentTbl, order.orderID, applyConcentration == true },
        { order.spellID, reagentTbl, order.orderID },
        { order.spellID, nil, order.orderID, applyConcentration == true },
        { order.spellID, nil, order.orderID },
    }

    for _, args in ipairs(attempts) do
        local ok, info = pcall(C_TradeSkillUI.GetCraftingOperationInfoForOrder, unpack(args))
        if ok and info then return info end
    end

    return nil
end

function CO:BuildQualityInfoFromOperationInfo(order, info, useConc)
    if not order or not info then return nil end

    local totalSkill = SafeNum(info.baseSkill) + SafeNum(info.bonusSkill)
    local totalDifficulty = SafeNum(info.baseDifficulty) + SafeNum(info.bonusDifficulty)
    local lower = SafeNum(info.lowerSkillThreshold)
    local upper = SafeNum(info.upperSkillTreshold or info.upperSkillThreshold)
    if upper <= 0 then upper = math.max(totalDifficulty, totalSkill, 1) end

    local maxQuality = 0
    local recipeInfo = C_TradeSkillUI.GetRecipeInfo and C_TradeSkillUI.GetRecipeInfo(order.spellID)
    if recipeInfo and recipeInfo.maxQuality then
        maxQuality = recipeInfo.maxQuality
    elseif recipeInfo and recipeInfo.qualityIDs then
        maxQuality = #recipeInfo.qualityIDs
    elseif C_TradeSkillUI.GetQualitiesForRecipe then
        local ok, qualities = pcall(C_TradeSkillUI.GetQualitiesForRecipe, order.spellID)
        if ok and type(qualities) == "table" then maxQuality = #qualities end
    end

    local skillPct = Clamp01(totalSkill / math.max(upper, 1))
    local quality = SafeNum(info.craftingQuality or info.quality or info.projectedQuality or info.outputQuality)
    local guaranteedBySkill = skillPct >= 1 or (upper > 0 and totalSkill >= upper)

    if quality <= 0 and guaranteedBySkill then
        quality = maxQuality > 0 and maxQuality or 1
    end

    local qualityPct
    if maxQuality > 0 then
        qualityPct = Clamp01(quality / math.max(maxQuality, 1))
    elseif guaranteedBySkill then
        qualityPct = 1
    else
        qualityPct = 0
    end

    return {
        operationInfo = info,
        quality = quality,
        maxQuality = maxQuality,
        skill = totalSkill,
        difficulty = totalDifficulty,
        lower = lower,
        upper = upper,
        skillPct = skillPct,
        qualityPct = qualityPct,
        concentration = useConc,
        concentrationCost = ReadConcentrationCostFromInfo(info),
        guaranteedBySkill = guaranteedBySkill,
        noConcentrationNeeded = (not useConc) and guaranteedBySkill,
    }
end

function ReadProjectedQualityFromDetails(details)
    if not details then return nil end

    local info
    if details.GetProjectedQualityInfo then
        local ok, value = pcall(details.GetProjectedQualityInfo, details)
        if ok and type(value) == "table" then info = value end
    end

    if not info and details.QualityMeter and details.QualityMeter.GetQualityInfo then
        local ok, value = pcall(details.QualityMeter.GetQualityInfo, details.QualityMeter)
        if ok and type(value) == "table" then info = value end
    end

    if not info then return nil end
    return {
        baseSkill = SafeNum(info.baseSkill or info.skill or info.currentSkill or info.playerSkill),
        bonusSkill = SafeNum(info.bonusSkill or info.skillBonus or info.extraSkill),
        baseDifficulty = SafeNum(info.baseDifficulty or info.difficulty or info.recipeDifficulty),
        bonusDifficulty = SafeNum(info.bonusDifficulty or info.difficultyBonus),
        lowerSkillThreshold = SafeNum(info.lowerSkillThreshold or info.lowerThreshold),
        upperSkillThreshold = SafeNum(info.upperSkillThreshold or info.upperSkillTreshold or info.upperThreshold),
        craftingQuality = SafeNum(info.craftingQuality or info.quality or info.projectedQuality or info.outputQuality),
        concentrationCost = ReadConcentrationCostFromInfo(info),
    }
end

function CO:GetOrderQualityInfoFromPreparedOrderView(order, useConc)
    local pageFrame = self.activePageFrame or self:FindOrderPageFrame()
    if not pageFrame or not pageFrame.OrderView then return nil end
    if not self:IsCraftingOrdersPageOpen(pageFrame) then return nil end
    if self.IsSafeToPrepareOrderViewForAnalysis and not self:IsSafeToPrepareOrderViewForAnalysis(pageFrame) then return nil end

    local engine = self:GetOrderEngine(pageFrame, order)
    if not engine then return nil end

    self:ApplySelectedReagentsToEngine(engine, order)
    self:SetEngineConcentration(engine, useConc)


    local info = self:GetOrderOperationInfo(order, useConc)
    if info then
        return self:BuildQualityInfoFromOperationInfo(order, info, useConc)
    end

    local form = engine.OrderDetails and engine.OrderDetails.SchematicForm
    local details = form and form.Details
    info = ReadProjectedQualityFromDetails(details)
    if info then
        return self:BuildQualityInfoFromOperationInfo(order, info, useConc)
    end

    return nil
end

function CO:GetOrderQualityInfo(order, applyConcentrationOverride, allowPreparedOrderView)
    if not order then return nil end

    local key = OrderKey(order.orderID)
    local useConc
    if applyConcentrationOverride ~= nil then
        useConc = applyConcentrationOverride == true
    else
        useConc = key and self.useConcentration[key] == true
    end

    local revision = GetOrderRevision(self, order.orderID)
    local cacheKey = key and (key .. ":" .. (useConc and "1" or "0") .. ":" .. tostring(revision) .. ":" .. (allowPreparedOrderView and "p" or "f"))
    local now = CacheNow()
    if cacheKey then
        local cached = self.qualityCache and self.qualityCache[cacheKey]
        if cached and cached.expiresAt and cached.expiresAt > now then
            return cached.value
        end
    end

    local info = self:GetOrderOperationInfo(order, useConc)
    local result = self:BuildQualityInfoFromOperationInfo(order, info, useConc)


    if not result and allowPreparedOrderView then
        result = self:GetOrderQualityInfoFromPreparedOrderView(order, useConc)
    end

    local storeRevision = GetOrderRevision(self, order.orderID)
    local storeCacheKey = key and (key .. ":" .. (useConc and "1" or "0") .. ":" .. tostring(storeRevision) .. ":" .. (allowPreparedOrderView and "p" or "f"))
    if storeCacheKey then
        local expiresAt = now + (result and QUALITY_CACHE_TTL or QUALITY_MISS_CACHE_TTL)
        self.qualityCache[storeCacheKey] = {
            value = result,
            expiresAt = expiresAt,
        }


        if allowPreparedOrderView and key then
            local fastCacheKey = key .. ":" .. (useConc and "1" or "0") .. ":" .. tostring(storeRevision) .. ":f"
            self.qualityCache[fastCacheKey] = {
                value = result,
                expiresAt = expiresAt,
            }
        end
    end

    return result
end

function CO:GetConcentrationCostToNextQuality(order, qInfo, allowPreparedOrderView)
    if not order or not qInfo or qInfo.noConcentrationNeeded then return nil end

    if qInfo.concentrationCost and qInfo.concentrationCost > 0 then
        return qInfo.concentrationCost
    end

    local concInfo = self:GetOrderQualityInfo(order, true, allowPreparedOrderView == true)
    if concInfo and concInfo.concentrationCost and concInfo.concentrationCost > 0 then
        return concInfo.concentrationCost
    end

    return nil
end

function CO:ShowQualityTooltip(owner, order)
    if not owner or not order or not Tooltip then return end

    local info = self:GetOrderQualityInfo(order, nil, true)
    Tooltip:Clear()
    Tooltip:AddLine(T("COA_EXPECTED_QUALITY", "Expected quality"), 14, 1, 0.82, 0.35)

    if info then
        Tooltip:AddLine(T("COA_QUALITY_TOOLTIP_QUALITY", "Quality") .. ": " .. GetQualityText(info.quality, info.maxQuality), 12, 1, 1, 1)
        Tooltip:AddLine(T("COA_QUALITY_TOOLTIP_SKILL", "Skill") .. ": " .. tostring(math.floor(info.skill + 0.5)) .. " / " .. tostring(math.floor(info.difficulty + 0.5)), 11, 0.85, 0.85, 0.85)

        local concCostText = GetConcentrationCostText(self:GetConcentrationCostToNextQuality(order, info, true))
        if concCostText then
            Tooltip:AddLine(T("COA_QUALITY_TOOLTIP_CONC_COST", "Concentration to next quality:") .. " " .. concCostText, 11, 0.35, 0.85, 1)
        end

        if info.concentration then
            Tooltip:AddLine(T("COA_QUALITY_TOOLTIP_CONC", "Concentration is applied."), 11, 0.35, 0.85, 1)
        elseif info.noConcentrationNeeded then
            Tooltip:AddLine(T("COA_QUALITY_TOOLTIP_NO_CONC_NEEDED", "Concentration is not needed."), 11, 0.35, 0.95, 0.45)
        end
    else
        Tooltip:AddLine(T("COA_QUALITY_TOOLTIP_NO_DATA", "Quality data is not available yet."), 11, 0.85, 0.85, 0.85)
    end

    ShowStyledTooltip(owner)
end

function CO:ShowConcentrationTooltip(owner)
    if not owner or not Tooltip then return end

    Tooltip:Clear()
    Tooltip:AddLine(T("COA_CONCENTRATION_TOOLTIP", "Toggle concentration for this order."), 14, 1, 0.82, 0.35)

    local order = owner.order
    if order then
        local key = OrderKey(order.orderID)
        Tooltip:AddLine(T("COA_TOOLTIP_QUEUE_STATE", "In queue:") .. " " .. (self:IsOrderSelected(order.orderID) and T("COA_YES", "Yes") or T("COA_NO", "No")), 11, 0.85, 0.85, 0.85)
        Tooltip:AddLine(T("COA_TOOLTIP_STATE", "Current state:") .. " " .. (self.useConcentration[key] and T("COA_CONCENTRATION_ON", "On") or T("COA_CONCENTRATION_OFF", "Off")), 11, 0.85, 0.85, 0.85)
    end

    ShowStyledTooltip(owner)
end

function CO:ShowRowButtonTooltip(btn)
    if not btn or not Tooltip then return end
    if self.CustomList and self.CustomList._listActive then return end

    local action, actionText, order, enabled = self:GetRowAction(btn.orderID, btn.order)
    local timeText = GetRemainingTimeText(order)

    Tooltip:Clear()
    Tooltip:AddLine(T("COA_TOOLTIP_TITLE", "HironCraftProfit order action"), 14, 1, 0.82, 0.35)
    Tooltip:AddLine(T("COA_TOOLTIP_STATE", "Current state:") .. " " .. tostring(actionText or ""), 12, enabled and 0.35 or 0.85, enabled and 0.95 or 0.45, enabled and 0.45 or 0.45)

    if timeText and timeText ~= "" then
        Tooltip:AddLine(T("COA_TOOLTIP_TIME_LEFT", "Time left:") .. " " .. timeText, 11, 0.85, 0.85, 0.85)
    end

    Tooltip:AddLine(T("COA_TOOLTIP_QUEUE_STATE", "In queue:") .. " " .. (self:IsOrderSelected(btn.orderID) and T("COA_YES", "Yes") or T("COA_NO", "No")), 11, 0.85, 0.85, 0.85)
    Tooltip:AddLine(" ", 4, 1, 1, 1)
    Tooltip:AddLine(T("COA_ROW_TOOLTIP_INLINE", "Left click: perform this row step. Assigned key works only on checked orders."), 11, 0.85, 0.85, 0.85)
    Tooltip:AddLine(T("COA_ROW_TOOLTIP_RELEASE", "Right click: release the claimed order."), 11, 0.85, 0.85, 0.85)
    Tooltip:AddLine(T("COA_QUEUE_TOOLTIP_DESC", "Check orders here, then press the assigned key to process the selected queue step by step."), 11, 0.70, 0.90, 1)
    Tooltip:AddLine(" ", 4, 1, 1, 1)
    Tooltip:AddLine(T("COA_BINDING_LABEL", "Key:") .. " " .. BindingText(GetDB().binding), 11, 0.95, 0.82, 0.40)

    ShowStyledTooltip(btn)
end

function CO:RefreshHoveredRowButtonTooltip(btn)
    if btn and (IsFrameMouseOver(btn) or (btn.check and IsFrameMouseOver(btn.check))) then
        self:ShowRowButtonTooltip(btn)
    end
end

function CO:CreateMiniIcon(parent)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(MINI_ICON_SIZE, MINI_ICON_SIZE)
    b.ahuiCraftingOrdersOwned = true
    CreateBackdrop(b, 0.82)

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.icon.ahuiCraftingOrdersOwned = true

    b.count = b:CreateFontString(nil, "OVERLAY")
    ApplyFont(b.count, 8, "OUTLINE")
    b.count:SetPoint("BOTTOMRIGHT", 0, 0)
    b.count.ahuiCraftingOrdersOwned = true

    b.grade = b:CreateFontString(nil, "OVERLAY")
    ApplyFont(b.grade, 8, "OUTLINE")
    b.grade:SetPoint("TOPLEFT", 1, -1)
    b.grade.ahuiCraftingOrdersOwned = true

    b.qualityBadge = b:CreateTexture(nil, "OVERLAY")
    b.qualityBadge:SetPoint("TOPRIGHT", b, "TOPRIGHT", REAGENT_QUALITY_BADGE_X, REAGENT_QUALITY_BADGE_Y)
    b.qualityBadge:SetSize(REAGENT_QUALITY_BADGE_SIZE, REAGENT_QUALITY_BADGE_SIZE)
    b.qualityBadge:Hide()
    b.qualityBadge.ahuiCraftingOrdersOwned = true

    b.missingX = b:CreateTexture(nil, "OVERLAY")
    b.missingX:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", -1, -1)
    b.missingX:SetSize(REAGENT_MISSING_X_SIZE, REAGENT_MISSING_X_SIZE)
    if b.missingX.SetAtlas then
        local ok = pcall(b.missingX.SetAtlas, b.missingX, RED_X_ATLAS, true)
        if not ok then
            b.missingX:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        end
    else
        b.missingX:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    end
    b.missingX:Hide()
    b.missingX.ahuiCraftingOrdersOwned = true

    return b
end


function ResizeMiniIcon(icon, size, badgeSize)
    if not icon then return end
    size = tonumber(size) or MINI_ICON_SIZE
    badgeSize = tonumber(badgeSize) or REAGENT_QUALITY_BADGE_SIZE

    icon:SetSize(size, size)

    if icon.icon then
        icon.icon:ClearAllPoints()
        icon.icon:SetPoint("TOPLEFT", icon, "TOPLEFT", 1, -1)
        icon.icon:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
    end

    if icon.count then
        ApplyFont(icon.count, size <= 15 and 7 or 8, "OUTLINE")
        icon.count:ClearAllPoints()
        icon.count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
    end

    if icon.grade then
        ApplyFont(icon.grade, size <= 15 and 7 or 8, "OUTLINE")
        icon.grade:ClearAllPoints()
        icon.grade:SetPoint("TOPLEFT", icon, "TOPLEFT", 1, -1)
    end

    if icon.qualityBadge then
        icon.qualityBadge:ClearAllPoints()
        icon.qualityBadge:SetPoint("TOPRIGHT", icon, "TOPRIGHT", REAGENT_QUALITY_BADGE_X, REAGENT_QUALITY_BADGE_Y)
        icon.qualityBadge:SetSize(badgeSize, badgeSize)
    end

    if icon.qualityOutline then
        icon.qualityOutline:ClearAllPoints()
        icon.qualityOutline:SetPoint("CENTER", icon.qualityBadge or icon, "CENTER", 0, 0)
        icon.qualityOutline:SetSize(badgeSize + REAGENT_QUALITY_OUTLINE_PAD * 2, badgeSize + REAGENT_QUALITY_OUTLINE_PAD * 2)
    end

    if icon.missingX then
        local xSize = math.max(8, math.min(11, math.floor(size * 0.48 + 0.5)))
        icon.missingX:ClearAllPoints()
        icon.missingX:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 0, 0)
        icon.missingX:SetSize(xSize, xSize)
    end
end

function CO:EnsureOrderColumnFrames(row, btn, order)
    if not row or not btn then return end

    self:ApplyOrderRowHeight(row, order, btn.pageFrame or self.activePageFrame)

    if not row.ahuiOrderReagentsFrame then
        local reagents = CreateFrame("Frame", nil, row, "BackdropTemplate")
        reagents.ahuiCraftingOrdersOwned = true
        reagents:SetSize(REAGENTS_COLUMN_W, ROW_BUTTON_H)
        reagents:SetFrameLevel((row:GetFrameLevel() or 1) + 29)
        row.ahuiOrderReagentsFrame = reagents

        reagents.moreText = reagents:CreateFontString(nil, "OVERLAY")
        ApplyFont(reagents.moreText, 9, "")
        reagents.moreText:SetPoint("RIGHT", reagents, "RIGHT", -1, 0)
        reagents.moreText:SetTextColor(0.82, 0.82, 0.82, 1)
        reagents.moreText.ahuiCraftingOrdersOwned = true
    end

    if not row.ahuiOrderRewardsFrame then
        local rewards = CreateFrame("Frame", nil, row, "BackdropTemplate")
        rewards.ahuiCraftingOrdersOwned = true
        rewards:SetSize(REWARDS_COLUMN_W, ROW_BUTTON_H)
        rewards:SetFrameLevel((row:GetFrameLevel() or 1) + 29)
        row.ahuiOrderRewardsFrame = rewards
    end

    if not row.ahuiOrderProfitFrame then
        local profit = CreateFrame("Frame", nil, row.ahuiOrderRewardsFrame or row, "BackdropTemplate")
        profit.ahuiCraftingOrdersOwned = true
        profit:SetSize(PROFIT_COLUMN_W, ROW_BUTTON_H)
        profit:SetFrameLevel((row:GetFrameLevel() or 1) + 31)
        row.ahuiOrderProfitFrame = profit
    elseif row.ahuiOrderRewardsFrame and row.ahuiOrderProfitFrame:GetParent() ~= row.ahuiOrderRewardsFrame then
        row.ahuiOrderProfitFrame:SetParent(row.ahuiOrderRewardsFrame)
        row.ahuiOrderProfitFrame:SetFrameLevel((row:GetFrameLevel() or 1) + 31)
    end

    if not row.ahuiOrderFocusFrame then
        local focus = CreateFrame("Frame", nil, row, "BackdropTemplate")
        focus.ahuiCraftingOrdersOwned = true
        focus:SetSize(FOCUS_COLUMN_W, ROW_BUTTON_H)
        focus:SetFrameLevel((row:GetFrameLevel() or 1) + 29)

        if focus.qualityBar then
            focus.qualityBar:Hide()
        end
        if focus.skillMarker then focus.skillMarker:Hide() end
        if focus.qualityText then focus.qualityText:Hide() end
        if focus.qualityCheck then focus.qualityCheck:Hide() end

        focus.conc = CreateFrame("Button", nil, focus, "BackdropTemplate")
        focus.conc:SetSize(CONC_BUTTON_SIZE, CONC_BUTTON_SIZE)
        focus.conc:SetPoint("CENTER", focus, "CENTER", 0, 0)
        focus.conc:RegisterForClicks("LeftButtonUp")
        focus.conc.ahuiCraftingOrdersOwned = true
        CreateBackdrop(focus.conc, 0.88)

        focus.conc.icon = focus.conc:CreateTexture(nil, "ARTWORK")
        focus.conc.icon:SetPoint("TOPLEFT", 2, -2)
        focus.conc.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        focus.conc.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        focus.conc.icon.ahuiCraftingOrdersOwned = true
        SetConcentrationIconTexture(focus.conc.icon)


        focus.conc.check = focus.conc:CreateTexture(nil, "OVERLAY")
        focus.conc.check:SetSize(11, 11)
        focus.conc.check:SetPoint("BOTTOMRIGHT", 2, -1)
        if focus.conc.check.SetAtlas then
            focus.conc.check:SetAtlas(CHECKMARK_ATLAS, true)
        else
            focus.conc.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        end
        focus.conc.check:Hide()
        focus.conc.check.ahuiCraftingOrdersOwned = true

        focus.conc.qualityBadge = focus.conc:CreateTexture(nil, "OVERLAY")
        focus.conc.qualityBadge:SetPoint("TOPRIGHT", focus.conc, "TOPRIGHT", 5, 5)
        focus.conc.qualityBadge:SetSize(14, 14)
        focus.conc.qualityBadge:Hide()
        focus.conc.qualityBadge.ahuiCraftingOrdersOwned = true

        focus.conc:SetScript("OnClick", function(self)
            local order = self.order
            local orderID = order and order.orderID or self.orderID
            if not orderID then return end

            local key = OrderKey(orderID)
            local currentValue = key and CO.useConcentration[key] == true
            local newValue = not currentValue
            CO.useConcentration[key] = newValue or nil
            CO:InvalidateOrderCaches(orderID)


            local pageFrame = CO:FindOrderPageFrame(self.pageFrame or CO.activePageFrame or self:GetParent())
            local engine = order and CO:GetOrderEngine(pageFrame, order)
            if engine then
                CO:ApplySelectedReagentsToEngine(engine, order)
                CO:SetEngineConcentration(engine, newValue)
            end

            if newValue then
                CO:SetStatus(T("COA_STATUS_CONCENTRATION_ON", "Concentration enabled for this order."))
            else
                CO:SetStatus(T("COA_STATUS_CONCENTRATION_OFF", "Concentration disabled for this order."))
            end
            CO:RefreshVisibleRowsSoon()
            if IsFrameMouseOver(self) then
                CO:ShowConcentrationTooltip(self)
            end
        end)
        focus.conc:SetScript("OnEnter", function(self)
            CO:ShowConcentrationTooltip(self)
        end)
        focus.conc:SetScript("OnLeave", HideStyledTooltip)

        row.ahuiOrderFocusFrame = focus
    end


    local widths = GetOrderTableColumnWidths()

    if btn then
        btn:ClearAllPoints()
        btn:SetPoint("RIGHT", row, "RIGHT", -ROW_RIGHT_PAD, 0)
        if btn.check then
            btn.check:ClearAllPoints()
            btn.check:SetSize(ROW_CHECKBOX_SIZE, ROW_CHECKBOX_SIZE)
            btn.check:SetPoint("LEFT", btn, "LEFT", 1, 0)
        end
    end

    SetRowColumnByRightOffset(row, row.ahuiOrderReagentsFrame, widths.expiration, widths.reagents, 4)
    local reagentFrameHeight = row.ahuiOrderTallRow and math.max(row:GetHeight() or 0, ORDER_ROW_TALL_H) or ROW_BUTTON_H
    row.ahuiOrderReagentsFrame:SetHeight(math.max(ROW_BUTTON_H, reagentFrameHeight))
    SetRowColumnByRightOffset(row, row.ahuiOrderRewardsFrame, widths.expiration + widths.reagents, widths.tip, 4)

    if row.ahuiOrderProfitFrame and row.ahuiOrderRewardsFrame then
        row.ahuiOrderProfitFrame:ClearAllPoints()
        row.ahuiOrderProfitFrame:SetSize(PROFIT_COLUMN_W, ROW_BUTTON_H)
        row.ahuiOrderProfitFrame:SetPoint("RIGHT", row.ahuiOrderRewardsFrame, "RIGHT", 0, 0)
    end

    local customerRegion = FindFontStringByExactText(row, order and order.customerName, 0, {})
    if not SetRowColumnOverRegion(row, row.ahuiOrderFocusFrame, customerRegion, widths.customer, 4) then
        SetRowColumnByRightOffset(row, row.ahuiOrderFocusFrame, widths.expiration + widths.reagents + widths.tip, widths.customer, 4)
    end

    row.ahuiOrderReagentsFrame:Show()
    row.ahuiOrderRewardsFrame:Show()
    if row.ahuiOrderProfitFrame then row.ahuiOrderProfitFrame:Show() end
    row.ahuiOrderFocusFrame:Show()
end

function CO:UpdateFocusFrame(frame, order)
    if not frame or not order then return end

    local key = OrderKey(order.orderID)
    local useConc = key and self.useConcentration[key] == true

    if frame.conc then
        frame.conc.orderID = order.orderID
        frame.conc.order = order
        frame.conc.pageFrame = self.activePageFrame

        if frame.conc.qualityBadge then
            local qInfo, cachedOrMiss = self:GetCachedOrderQualityInfo(order, useConc)
            if not qInfo and not cachedOrMiss then
                qInfo = self:GetOrderQualityInfo(order, useConc, false)
            end

            local atlas = qInfo and GetProfessionQualityAtlas(qInfo.quality, qInfo.maxQuality, nil, "item") or nil
            if atlas and frame.conc.qualityBadge.SetAtlas then
                local ok = pcall(frame.conc.qualityBadge.SetAtlas, frame.conc.qualityBadge, atlas, true)
                if ok then
                    frame.conc.qualityBadge:SetSize(14, 14)
                    frame.conc.qualityBadge:Show()
                else
                    frame.conc.qualityBadge:Hide()
                end
            else
                frame.conc.qualityBadge:Hide()
            end
        end

        if frame.conc.check then
            frame.conc.check:SetShown(useConc)
        end

        if useConc then
            SetFrameBackdropColors(frame.conc, 0.08, 0.22, 0.30, 0.95, 0.35, 0.85, 1, 0.95)
            frame.conc:SetAlpha(1)
        else
            SetFrameBackdropColors(frame.conc, 0.035, 0.035, 0.04, 0.88, 1, 1, 1, 0.14)
            frame.conc:SetAlpha(1)
        end
    end

    if frame.qualityBar then
        frame.qualityBar:Hide()
    end
    if frame.skillMarker then frame.skillMarker:Hide() end
    if frame.qualityText then frame.qualityText:Hide() end
    if frame.qualityCheck then frame.qualityCheck:Hide() end

end

function GetAuctionatorItemPrice(itemID, itemLink)
    local PP = HironCraftProfit and HironCraftProfit.Prices
    if PP and PP.GetItemPrice then
        local v = PP:GetItemPrice(itemLink or itemID)
        if tonumber(v) and tonumber(v) > 0 then return tonumber(v) end
    end

    if not Auctionator or not Auctionator.API or not Auctionator.API.v1 then return nil end
    local addonName = "HironCraftProfit"

    if itemLink and Auctionator.API.v1.GetAuctionPriceByItemLink then
        local ok, price = pcall(Auctionator.API.v1.GetAuctionPriceByItemLink, addonName, itemLink)
        if ok and tonumber(price) and tonumber(price) > 0 then return tonumber(price) end
    end

    if itemID and Auctionator.API.v1.GetAuctionPriceByItemID then
        local ok, price = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, addonName, itemID)
        if ok and tonumber(price) and tonumber(price) > 0 then return tonumber(price) end
    end

    return nil
end

function GetRewardItemID(reward)
    if type(reward) ~= "table" then return nil end

    local itemID = tonumber(reward.itemID or reward.itemId or reward.itemTypeID or reward.itemTypeId)
    if itemID and itemID > 0 then return itemID end

    local link = reward.itemLink or reward.link
    if link then
        if GetItemInfoInstant then
            local ok, instantID = pcall(GetItemInfoInstant, link)
            instantID = ok and tonumber(instantID) or nil
            if instantID and instantID > 0 then return instantID end
        end

        local linkedID = tostring(link):match("item:(%d+)")
        linkedID = tonumber(linkedID)
        if linkedID and linkedID > 0 then return linkedID end
    end

    return nil
end

local knowledgeScanTip
local knowledgeItemCache = {}

local function ItemTooltipGivesKnowledge(itemID)
    if knowledgeItemCache[itemID] ~= nil then return knowledgeItemCache[itemID] end

    if not knowledgeScanTip then
        knowledgeScanTip = CreateFrame("GameTooltip", "HironCraftProfitCOKnowledgeScanTip", nil, "GameTooltipTemplate")
        knowledgeScanTip:SetOwner(UIParent, "ANCHOR_NONE")
    end

    knowledgeScanTip:ClearLines()
    local ok = pcall(knowledgeScanTip.SetItemByID, knowledgeScanTip, itemID)
    if not ok then return false end

    local n = knowledgeScanTip:NumLines() or 0
    if n == 0 then return false end

    local found = false
    for i = 1, n do
        local fs = _G["HironCraftProfitCOKnowledgeScanTipTextLeft" .. i]
        local text = fs and fs:GetText()
        if text then
            local low = text:lower()
            if low:find("знани") or low:find("knowledge") then
                found = true
                break
            end
        end
    end

    knowledgeItemCache[itemID] = found
    return found
end

function IsKnowledgePointRewardItem(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return false end

    local entry
    if PT and PT.FindEntryById then
        local ok, found = pcall(PT.FindEntryById, itemID)
        if ok then entry = found end
    end
    if not entry and PT and type(PT.idIdx) == "table" then
        entry = PT.idIdx[itemID]
    end

    if type(entry) == "table" then
        local kp = tonumber(entry.kp or entry.knowledgePoints or entry.knowledge)
        if kp and kp > 0 then return true end
        if entry.GetRemainingKnowledgePoints then
            local ok, remaining = pcall(entry.GetRemainingKnowledgePoints, entry)
            if ok and tonumber(remaining) and tonumber(remaining) > 0 then return true end
        end
    end

    if ItemTooltipGivesKnowledge(itemID) then return true end

    return false
end

function IsCurrencyReward(reward)
    if type(reward) ~= "table" then return true end
    return (reward.currencyType or reward.currencyID or reward.currencyId
        or reward.currencyTypeID or reward.currencyTypeId) ~= nil
end

function ShouldIgnoreRewardForProfit(reward)
    if type(reward) ~= "table" then return true end

    if IsCurrencyReward(reward) then
        return true
    end

    return IsKnowledgePointRewardItem(GetRewardItemID(reward))
end

function IsContainerRewardItem(reward)
    local itemID = GetRewardItemID(reward)
    if not itemID then return false end

    local classID
    if GetItemInfoInstant then
        local _, _, _, _, _, cid = GetItemInfoInstant(itemID)
        classID = cid
    end
    if classID == nil and C_Item and C_Item.GetItemInfoInstant then
        local a, _, _, _, _, cid = C_Item.GetItemInfoInstant(itemID)
        if type(a) == "table" then
            classID = a.classID
        else
            classID = cid
        end
    end

    local containerClass = (Enum and Enum.ItemClass and Enum.ItemClass.Container) or 1
    return classID == containerClass
end

function GetRewardKnowledgePointCount(reward)
    local itemID = GetRewardItemID(reward)
    if not itemID then return 0 end

    local kp
    local entry
    if PT and PT.FindEntryById then
        local ok, found = pcall(PT.FindEntryById, itemID)
        if ok then entry = found end
    end
    if not entry and PT and type(PT.idIdx) == "table" then
        entry = PT.idIdx[itemID]
    end
    if type(entry) == "table" then
        kp = tonumber(entry.kp or entry.knowledgePoints or entry.knowledge)
    end
    if not kp or kp <= 0 then kp = 1 end

    local count = tonumber(reward.count) or tonumber(reward.quantity) or 1
    return kp * count
end

function FormatProfitCopper(copper)
    copper = tonumber(copper)
    if not copper then return "-" end
    local sign = copper < 0 and "-" or ""
    local absCopper = math.abs(math.floor(copper))
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        return sign .. C_CurrencyInfo.GetCoinTextureString(absCopper)
    end
    return sign .. FormatCopperShort(absCopper) .. "g"
end

function CO:GetOrderProfitInfo(order)
    if not order then return nil end

    local profit = tonumber(order.tipAmount) or 0
    profit = profit - (tonumber(order.consortiumCut) or 0)
    local missingPrices = false
    local reagentCost = 0
    local rewardValue = 0
    local bagRewardValue = 0
    local knowledgeRewardValue = 0

    local bagValue = self.GetBagRewardValueCopper and self:GetBagRewardValueCopper() or nil
    local kpValue = self.GetKnowledgePointValueCopper and self:GetKnowledgePointValueCopper() or nil

    local rewards = order.npcOrderRewards or order.rewards or {}
    for _, reward in ipairs(rewards) do
        if IsCurrencyReward(reward) then
        elseif type(reward) == "table" and IsKnowledgePointRewardItem(GetRewardItemID(reward)) then
            if kpValue then
                local kp = GetRewardKnowledgePointCount(reward)
                knowledgeRewardValue = knowledgeRewardValue + (kp * kpValue)
            end
        else
            local itemID = GetRewardItemID(reward)
            local count = tonumber(reward.count) or tonumber(reward.quantity) or 1
            if bagValue and IsContainerRewardItem(reward) then
                bagRewardValue = bagRewardValue + (bagValue * count)
            else
                local price
                if reward.itemLink then
                    price = GetAuctionatorItemPrice(nil, reward.itemLink)
                elseif itemID then
                    price = GetAuctionatorItemPrice(itemID, nil)
                end
                if price then
                    rewardValue = rewardValue + (price * count)
                elseif reward.itemLink or itemID then
                    missingPrices = true
                end
            end
        end
    end

    rewardValue = rewardValue + bagRewardValue + knowledgeRewardValue

    local seenSlots = {}
    for _, reagentEntry in ipairs(self:BuildDisplayReagents(order)) do
        if IsCrafterProvidedReagent(reagentEntry) and not IsCustomerProvidedReagent(reagentEntry) then
            local slotIndex = reagentEntry.dataSlotIndex or reagentEntry.slotIndex
            local slotKey = tostring(slotIndex or "") .. ":" .. tostring(reagentEntry.dataSlotIndex or "") .. ":" .. tostring(reagentEntry.itemID or "?")
            if not seenSlots[slotKey] then
                seenSlots[slotKey] = true
                local selected = self:GetSelectedReagentForEntry(order.orderID, reagentEntry)
                local itemID = selected and selected.itemID or reagentEntry.itemID
                local quantity = tonumber(reagentEntry.quantity) or 0
                local price = GetAuctionatorItemPrice(itemID, nil)
                if price then
                    reagentCost = reagentCost + (price * quantity)
                else
                    missingPrices = true
                end
            end
        end
    end

    profit = profit + rewardValue - reagentCost
    return {
        profit = profit,
        reagentCost = reagentCost,
        rewardValue = rewardValue,
        bagRewardValue = bagRewardValue,
        knowledgeRewardValue = knowledgeRewardValue,
        missingPrices = missingPrices,
    }
end

function CO:ShowProfitTooltip(owner, order)
    if not owner or not Tooltip then return end
    Tooltip:Clear()
    Tooltip:AddLine(T("COA_HDR_PROFIT", "Profit"), 14, 1, 0.82, 0.35)

    local info = self:GetOrderProfitInfo(order)
    if not info then
        Tooltip:AddLine(T("COA_PROFIT_NO_DATA", "Profit data is not available."), 11, 0.85, 0.85, 0.85)
        ShowStyledTooltip(owner)
        return
    end

    Tooltip:AddLine(T("COA_PROFIT_RESULT", "Profit:") .. " " .. FormatProfitCopper(info.profit), 12, info.profit >= 0 and 0.35 or 1, info.profit >= 0 and 0.95 or 0.35, 0.35)
    Tooltip:AddLine(T("COA_PROFIT_REWARDS", "Reward value:") .. " " .. FormatProfitCopper(info.rewardValue), 11, 0.85, 0.85, 0.85)
    if info.bagRewardValue and info.bagRewardValue > 0 then
        Tooltip:AddLine("   " .. T("COA_PROFIT_BAG", "в т.ч. сумка:") .. " " .. FormatProfitCopper(info.bagRewardValue), 11, 0.70, 0.90, 1)
    end
    if info.knowledgeRewardValue and info.knowledgeRewardValue > 0 then
        Tooltip:AddLine("   " .. T("COA_PROFIT_KNOWLEDGE", "в т.ч. знания:") .. " " .. FormatProfitCopper(info.knowledgeRewardValue), 11, 0.70, 0.90, 1)
    end
    Tooltip:AddLine(T("COA_PROFIT_REAGENTS", "Reagent cost:") .. " " .. FormatProfitCopper(info.reagentCost), 11, 0.85, 0.85, 0.85)
    if info.missingPrices then
        Tooltip:AddLine(T("COA_PROFIT_MISSING", "Some Auctionator prices are missing."), 11, 1, 0.65, 0.25)
    end
    ShowStyledTooltip(owner)
end

function CO:UpdateProfitFrame(frame, order)
    if not frame or not order then return end

    local info = self:GetOrderProfitInfo(order)
    if not frame.text then
        frame.text = frame:CreateFontString(nil, "OVERLAY")
        frame.text.ahuiCraftingOrdersOwned = true
        ApplyFont(frame.text, 10, "")
        frame.text:SetPoint("CENTER", frame, "CENTER", 0, 0)
        frame.text:SetWidth(math.max(1, (frame:GetWidth() or PROFIT_COLUMN_W) - 4))
        frame.text:SetJustifyH("CENTER")
        frame.text:SetWordWrap(false)
        if frame.text.SetMaxLines then frame.text:SetMaxLines(1) end
    end

    if not info then
        frame.text:SetText("-")
        frame.text:SetTextColor(0.72, 0.72, 0.72, 1)
    else


        frame.text:SetText(FormatProfitCopper(info.profit))
        if info.profit >= 0 then
            frame.text:SetTextColor(0.35, 0.95, 0.45, 1)
        else
            frame.text:SetTextColor(1, 0.35, 0.35, 1)
        end
    end

    frame.order = order
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self) CO:ShowProfitTooltip(self, self.order) end)
    frame:SetScript("OnLeave", HideStyledTooltip)
end


function CO:IsProfitSortType(sortType)
    if sortType == nil then return false end

    if Enum and Enum.CraftingOrderSortType then
        for name, value in pairs(Enum.CraftingOrderSortType) do
            if value == sortType then
                name = tostring(name or "")
                if name == "Tip" or name == "MaxTip" or name:find("Tip") or name:find("Commission") then
                    return true
                end
            end
        end
    end

    local tipSort = ProfessionsSortOrder and ProfessionsSortOrder.Tip
    if type(tipSort) == "table" then
        for _, field in ipairs({ "sortType", "SortType", "orderType", "type" }) do
            if tipSort[field] ~= nil and tipSort[field] == sortType then
                return true
            end
        end
    end

    return tonumber(sortType) == 2
end

function CO:IsProfitSortOrder(sortOrder)
    if not sortOrder then return false end

    local tipSort = ProfessionsSortOrder and ProfessionsSortOrder.Tip
    if sortOrder == tipSort then return true end

    if type(sortOrder) == "table" then
        if sortOrder.ahuiCraftingOrdersProfitSort or sortOrder.ahuiSortByProfit then
            return true
        end

        if tipSort and type(tipSort) == "table" then
            for _, field in ipairs({ "sortType", "SortType", "orderType", "type" }) do
                if sortOrder[field] ~= nil and tipSort[field] ~= nil and sortOrder[field] == tipSort[field] then
                    return true
                end
            end
        end

        return self:IsProfitSortType(sortOrder.sortType or sortOrder.SortType or sortOrder.orderType or sortOrder.type)
    end

    return false
end

function CO:IsProfitSortRequest(request)
    if type(request) ~= "table" then return false end

    if self:IsProfitSortOrder(request.primarySort) then
        return true
    end

    if type(request.primarySort) == "table" and self:IsProfitSortType(request.primarySort.sortType) then
        return true
    end

    return self:IsProfitSortType(request.sortType)
end

function CO:IsActionSortType(sortType)
    if sortType == nil then return false end

    local actionSort = self.GetActionSortOrder and self:GetActionSortOrder() or nil
    if type(actionSort) == "table" then
        for _, field in ipairs({ "sortType", "SortType", "orderType", "type" }) do
            if actionSort[field] ~= nil and actionSort[field] == sortType then
                return true
            end
        end
    end

    local expirationSort = ProfessionsSortOrder and ProfessionsSortOrder.Expiration
    if type(expirationSort) == "table" then
        for _, field in ipairs({ "sortType", "SortType", "orderType", "type" }) do
            if expirationSort[field] ~= nil and expirationSort[field] == sortType then
                return true
            end
        end
    elseif expirationSort ~= nil and expirationSort == sortType then
        return true
    end

    return false
end

function CO:IsActionSortOrder(sortOrder)
    if not sortOrder then return false end

    local actionSort = self.GetActionSortOrder and self:GetActionSortOrder() or nil
    if sortOrder == actionSort then return true end

    if type(sortOrder) == "table" then
        if sortOrder.ahuiCraftingOrdersActionSort or sortOrder.ahuiSortByAction then
            return true
        end

        if type(actionSort) == "table" then
            for _, field in ipairs({ "sortType", "SortType", "orderType", "type" }) do
                if sortOrder[field] ~= nil and actionSort[field] ~= nil and sortOrder[field] == actionSort[field] then
                    return true
                end
            end
        end

        return self:IsActionSortType(sortOrder.sortType or sortOrder.SortType or sortOrder.orderType or sortOrder.type)
    end

    return self:IsActionSortType(sortOrder)
end

function CO:IsActionSortRequest(request)
    if type(request) ~= "table" then return false end

    if self:IsActionSortOrder(request.primarySort) then
        return true
    end

    if type(request.primarySort) == "table" and self:IsActionSortType(request.primarySort.sortType) then
        return true
    end

    return self:IsActionSortType(request.sortType)
end

function CO:IsPageSortedByProfit(pageFrame)
    if not pageFrame or type(pageFrame.primarySort) ~= "table" then return false end
    return self:IsProfitSortOrder(pageFrame.primarySort.order)
end

function CO:IsPageSortedByAction(pageFrame)
    if not pageFrame or type(pageFrame.primarySort) ~= "table" then return false end
    return self:IsActionSortOrder(pageFrame.primarySort.order)
end

function CO:WrapProfitSortShowGeneric(target)
    if not target or target.ahuiProfitSortShowGenericWrapped or type(target.ShowGeneric) ~= "function" then return end

    target.ahuiProfitSortShowGenericWrapped = true
    target.ahuiProfitSortOriginalShowGeneric = target.ShowGeneric

    target.ShowGeneric = function(pageFrame, orders, browseType, offset, isSorted, ...)
        if CO:IsEnabled()
           and type(orders) == "table"
           and (not OrderBrowseType or browseType == OrderBrowseType.Flat) then
            if CO:IsPageSortedByAction(pageFrame) then
                local primarySort = pageFrame.primarySort or {}
                local reversed = false
                if primarySort.reversed ~= nil then
                    reversed = primarySort.reversed == true
                elseif primarySort.ascending ~= nil then
                    reversed = primarySort.ascending ~= true
                end
                CO:SortOrdersByActionAvailability(orders, reversed)
                isSorted = true
            elseif CO:IsPageSortedByProfit(pageFrame) then
                local ascending = pageFrame.primarySort and pageFrame.primarySort.ascending == true
                CO:SortOrdersByProfit(orders, ascending)
                isSorted = true
            end
        end

        return target.ahuiProfitSortOriginalShowGeneric(pageFrame, orders, browseType, offset, isSorted, ...)
    end
end

function CO:IsOrderCraftableForActionSort(order)
    if not order or not order.orderID or not order.spellID then return false end
    if self:GetRecipeKnownState(order) == false then return false end
    if self.viewingCachedOrders then return false end

    local issueKey = OrderKey(order.orderID)
    if issueKey and self.orderIssues and self.orderIssues[issueKey] then return false end

    local claimed = self:GetClaimedOrder()
    if claimed and not SameOrderID(claimed.orderID, order.orderID) then return false end

    if not self:CanSupplyCrafterReagentsForQueue(order, false) then
        return false
    end

    local minQuality = tonumber(order.minQuality) or 0
    if minQuality > 0 then
        local q, cachedOrMiss = self:GetCachedOrderQualityInfo(order, false)
        if not q and not cachedOrMiss then
            q = self:GetOrderQualityInfo(order, false, false)
        end
        if not q or not tonumber(q.quality) or q.quality <= 0 or q.quality < minQuality then
            return false
        end
    end

    return true
end

function CO:GetOrderActionAvailabilitySortRank(order)
    if not order then return 2 end
    if self:GetRecipeKnownState(order) == false then return 4 end

    local needsConcentration = self:DoesOrderNeedConcentrationForTargetQuality(order, false)
    if needsConcentration == true then return 3 end

    if self:IsOrderCraftableForActionSort(order) then return 1 end

    return 2
end

function CO:SortOrdersByActionAvailability(orders, reversed)
    if type(orders) ~= "table" then return orders end

    local ranks = {}
    local function rankValue(order)
        if not order then return 2 end
        local cached = ranks[order]
        if cached ~= nil then return cached end
        local value = self:GetOrderActionAvailabilitySortRank(order)
        ranks[order] = value
        return value
    end

    table.sort(orders, function(a, b)
        local ra = rankValue(a)
        local rb = rankValue(b)
        if ra ~= rb then
            if reversed then
                return ra > rb
            end
            return ra < rb
        end

        local ta = tonumber(a and a.tipAmount) or 0
        local tb = tonumber(b and b.tipAmount) or 0
        if ta ~= tb then
            return ta > tb
        end

        return tostring(a and a.orderID or "") < tostring(b and b.orderID or "")
    end)

    return orders
end

function CO:SortOrdersByProfit(orders, reversed)
    if type(orders) ~= "table" then return orders end

    local values = {}
    local function profitValue(order)
        if not order then return -math.huge end
        local cached = values[order]
        if cached ~= nil then return cached end
        local info = self:GetOrderProfitInfo(order)
        local value = info and tonumber(info.profit) or -math.huge
        values[order] = value
        return value
    end

    table.sort(orders, function(a, b)
        local pa = profitValue(a)
        local pb = profitValue(b)
        if pa ~= pb then
            if reversed then
                return pa < pb
            end
            return pa > pb
        end

        local ta = tonumber(a and a.tipAmount) or 0
        local tb = tonumber(b and b.tipAmount) or 0
        if ta ~= tb then
            if reversed then
                return ta < tb
            end
            return ta > tb
        end

        return tostring(a and a.orderID or "") < tostring(b and b.orderID or "")
    end)

    return orders
end

function CO:MaybePinPendingToFront(orders)
    if type(orders) ~= "table" then return orders end
    local oid = self.pendingFulfillOrderID or self.pendingCraftOrderID or self.progressOrderID
    if not oid then return orders end

    local idx
    for i, o in ipairs(orders) do
        if o and o.orderID and SameOrderID(o.orderID, oid) then idx = i; break end
    end
    if not idx or idx == 1 then return orders end

    local copy = { orders[idx] }
    for i, o in ipairs(orders) do
        if i ~= idx then copy[#copy + 1] = o end
    end
    return copy
end

function CO:InstallProfitSortHooks()
    if self.profitSortHooksInstalled then return end
    self.profitSortHooksInstalled = true

    if not C_CraftingOrders then return end

    if type(C_CraftingOrders.RequestCrafterOrders) == "function" and not self.originalRequestCrafterOrders then
        local originalRequest = C_CraftingOrders.RequestCrafterOrders
        self.originalRequestCrafterOrders = originalRequest

        local ok = pcall(function()
            C_CraftingOrders.RequestCrafterOrders = function(request, ...)
                local canCustomSort = CO:IsEnabled() and not CO.queueSelectionRunning
                if canCustomSort and CO:IsActionSortRequest(request) then
                    CO.ahuiSortCrafterOrdersByAction = true
                    CO.ahuiSortCrafterOrdersByActionReversed = request and request.primarySort and request.primarySort.reversed == true
                    CO.ahuiSortCrafterOrdersByProfit = false
                elseif canCustomSort and CO:IsProfitSortRequest(request) then
                    CO.ahuiSortCrafterOrdersByProfit = true
                    CO.ahuiSortCrafterOrdersByProfitReversed = not (request.primarySort and request.primarySort.reversed == true)
                    CO.ahuiSortCrafterOrdersByAction = false
                else
                    CO.ahuiSortCrafterOrdersByProfit = false
                    CO.ahuiSortCrafterOrdersByAction = false
                end

                return originalRequest(request, ...)
            end
        end)

        if not ok then
            self.originalRequestCrafterOrders = nil
        end
    end

    if type(C_CraftingOrders.GetCrafterOrders) == "function" and not self.originalGetCrafterOrders then
        local originalGet = C_CraftingOrders.GetCrafterOrders
        self.originalGetCrafterOrders = originalGet

        local ok = pcall(function()
            C_CraftingOrders.GetCrafterOrders = function(...)
                local results = { originalGet(...) }
                local orders = results[1]
                if CO:IsEnabled() and CO.ahuiSortCrafterOrdersByAction and type(orders) == "table" then
                    local sorted = {}
                    for index, order in ipairs(orders) do
                        sorted[index] = order
                    end
                    CO:SortOrdersByActionAvailability(sorted, CO.ahuiSortCrafterOrdersByActionReversed)
                    results[1] = sorted
                elseif CO:IsEnabled() and CO.ahuiSortCrafterOrdersByProfit and type(orders) == "table" then
                    local sorted = {}
                    for index, order in ipairs(orders) do
                        sorted[index] = order
                    end
                    CO:SortOrdersByProfit(sorted, CO.ahuiSortCrafterOrdersByProfitReversed)
                    results[1] = sorted
                end
                if CO:IsEnabled() and type(results[1]) == "table" then
                    results[1] = CO:MaybePinPendingToFront(results[1])
                end
                return unpack(results)
            end
        end)

        if not ok then
            self.originalGetCrafterOrders = nil
        end
    end

    if ProfessionsCraftingOrderPageMixin and type(ProfessionsCraftingOrderPageMixin.ShowGeneric) == "function" then
        self:WrapProfitSortShowGeneric(ProfessionsCraftingOrderPageMixin)
    end

    if _G.ProfessionsFrame then
        self:WrapProfitSortShowGeneric(ProfessionsFrame.OrdersPage)
        self:WrapProfitSortShowGeneric(ProfessionsFrame.OrdersPageOffline)
    end
end

function CO:ApplyOrderNameFont(row, order)
    if not row or not row.GetRegions then return end
    local customerName = order and order.customerName

    local function scan(frame, depth, seen)
        if not frame or depth > 4 then return end
        seen = seen or {}
        if seen[frame] then return end
        seen[frame] = true

        if frame.GetRegions then
            for _, region in ipairs({ frame:GetRegions() }) do
                if region and region.GetObjectType and region:GetObjectType() == "FontString"
                   and not region.ahuiCraftingOrdersOwned
                   and region.GetText and region:GetText() and region:GetText() ~= ""
                   and (not customerName or region:GetText() ~= customerName)
                   and IsRegionInsideProtectedItemNameZone(row, region) then
                    ApplyFont(region, 12, "")
                end
            end
        end

        if frame.GetChildren then
            for _, child in ipairs({ frame:GetChildren() }) do
                if child and not child.ahuiCraftingOrdersOwned then
                    scan(child, depth + 1, seen)
                end
            end
        end
    end

    scan(row, 0, {})
end

function CO:ApplyOrderNameFontsToVisibleRows(pageFrame)
    if not self:IsEnabled() then return end
    pageFrame = pageFrame or self.activePageFrame or self:FindOrderPageFrame()

    local seenRows = {}
    local function applyRow(row, order)
        if not row or seenRows[row] then return end
        seenRows[row] = true
        order = order or row.option or (row.ahuiOrderActionButton and row.ahuiOrderActionButton.order)
        if row.IsShown and not row:IsShown() then return end
        self:ApplyOrderNameFont(row, order)
    end

    local scrollBox = pageFrame and pageFrame.BrowseFrame and pageFrame.BrowseFrame.OrderList
        and pageFrame.BrowseFrame.OrderList.ScrollBox
    local view = scrollBox and scrollBox.GetView and scrollBox:GetView()
    local frames = view and view.frames
    if type(frames) == "table" then
        for _, row in pairs(frames) do
            applyRow(row)
        end
    end

    for btn in pairs(self.visibleRowButtons or {}) do
        if btn then
            local row = btn.GetParent and btn:GetParent()
            applyRow(row, btn.order)
        end
    end
end

function CO:ReapplyOrderNameFontsSoon(pageFrame, delay)
    if not self:IsEnabled() then return end
    pageFrame = pageFrame or self.activePageFrame or self:FindOrderPageFrame()

    local function run()
        CO:ApplyOrderNameFontsToVisibleRows(pageFrame or CO.activePageFrame or CO:FindOrderPageFrame())
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(delay or 0, run)
    else
        run()
    end
end

function CO:ReapplyOrderNameFontsAfterProfessionRefresh(pageFrame)
    if not self:IsEnabled() then return end
    pageFrame = pageFrame or self.activePageFrame or self:FindOrderPageFrame()

    self:ReapplyOrderNameFontsSoon(pageFrame, 0)
    self:ReapplyOrderNameFontsSoon(pageFrame, 0.05)
    self:ReapplyOrderNameFontsSoon(pageFrame, 0.18)
    self:ReapplyOrderNameFontsSoon(pageFrame, 0.40)
end

function CO:ReprotectOrderListAfterProfessionRefresh(pageFrame)
    if not self:IsEnabled() then return end
    pageFrame = pageFrame or self.activePageFrame or self:FindOrderPageFrame()

    local function run()
        local pf = pageFrame or CO.activePageFrame or CO:FindOrderPageFrame()
        if not CO:IsEnabled() or not pf or (pf.IsShown and not pf:IsShown()) then return end

        CO.activePageFrame = pf
        CO:LockOrderTableColumns()
        CO:RearrangeOrderTableSafely(pf)
        CO:RefreshVisibleRows()
        CO:ProtectVisibleRows()
        CO:ProtectOrderHeaderLabels(pf)
        CO:UpdateControlPanelVisibility(pf)
    end

    run()
    if C_Timer and C_Timer.After then
        for _, delay in ipairs({ 0.03, 0.08, 0.16, 0.32, 0.65, 1.05 }) do
            C_Timer.After(delay, run)
        end
    end
end

local HIRONCRAFT_PROFIT_CO_REAGENT_DEBUG_SLASH = "HIRONCRAFT_PROFIT_CRAFTING_ORDERS_REAGENT_DEBUG"

function CO:DebugBoolText(value)
    return value and "Y" or "N"
end

function CO:DebugValueText(value)
    if value == nil then return "nil" end
    if type(value) == "boolean" then return value and "true" or "false" end
    return tostring(value)
end

function CO:DebugSafeItemName(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return "?" end
    local name
    if C_Item and C_Item.GetItemInfo then
        local ok, n = pcall(C_Item.GetItemInfo, itemID)
        if ok then name = n end
    end
    return name or ("item:" .. tostring(itemID))
end

function CO:DebugTableKeys(tbl, limit)
    if type(tbl) ~= "table" then return "-" end
    limit = tonumber(limit) or 18
    local keys = {}
    for key in pairs(tbl) do
        keys[#keys + 1] = tostring(key)
        if #keys >= limit then break end
    end
    table.sort(keys)
    if #keys == 0 then return "{}" end
    return table.concat(keys, ",")
end

function CO:DebugSourceText(source)
    if source == nil then return "nil" end
    local value = tostring(source)
    if Enum and Enum.CraftingOrderReagentSource then
        for name, enumValue in pairs(Enum.CraftingOrderReagentSource) do
            if enumValue == source then
                return value .. ":" .. tostring(name)
            end
        end
    end
    return value
end

function CO:DebugReagentLine(prefix, index, reagentInfo)
    local payload = GetOrderReagentPayload(reagentInfo)
    local itemID = tonumber(GetOrderReagentItemID(reagentInfo))
    local source = GetReagentSourceValue(reagentInfo, payload)
    local dataSlotIndex = GetOrderReagentDataSlotIndex(reagentInfo)
    local slotIndex = GetOrderReagentSlotIndex(reagentInfo)
    local quantity = GetOrderReagentQuantity(reagentInfo)

    return string.format(
        "%s[%s] item=%s name=%s qty=%s slot=%s dataSlot=%s source=%s customer=%s crafter=%s strictCrafter=%s keys={%s} payloadKeys={%s}",
        prefix or "R",
        tostring(index or "?"),
        tostring(itemID or "nil"),
        self:DebugSafeItemName(itemID),
        tostring(quantity or "nil"),
        tostring(slotIndex or "nil"),
        tostring(dataSlotIndex or "nil"),
        self:DebugSourceText(source),
        self:DebugBoolText(IsOrderCustomerProvidedReagent(reagentInfo)),
        self:DebugBoolText(IsCrafterProvidedReagent(reagentInfo)),
        self:DebugBoolText(IsStrictCrafterSourceValue(source)),
        self:DebugTableKeys(reagentInfo, 16),
        self:DebugTableKeys(payload, 16)
    )
end

function CO:DebugGetRecipeSchematic(order)
    if not order or not order.spellID or not C_TradeSkillUI or not C_TradeSkillUI.GetRecipeSchematic then return nil, "no_api" end
    local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, order.spellID, order.isRecraft)
    if not ok then return nil, "pcall_failed" end
    if not schematic then return nil, "nil" end
    return schematic, nil
end

function CO:DebugChoiceList(slotSchematic, limit)
    local choices = GetSchematicReagentChoices(slotSchematic)
    if type(choices) ~= "table" then return "-" end
    limit = tonumber(limit) or 10
    local out = {}
    local seen = {}

    local function add(choice)
        if #out >= limit then return end
        local itemID = GetSchematicChoiceItemID(choice)
        if itemID and not seen[itemID] then
            seen[itemID] = true
            out[#out + 1] = tostring(itemID) .. ":" .. self:DebugSafeItemName(itemID)
        end
    end

    for _, choice in ipairs(choices) do add(choice) end
    for _, choice in pairs(choices) do add(choice) end

    if #out == 0 then return "-" end
    return table.concat(out, " | ")
end

function CO:DebugCollectOrderLines(order, title)
    local lines = {}
    local function add(fmt, ...)
        if select("#", ...) > 0 then
            lines[#lines + 1] = string.format(fmt, ...)
        else
            lines[#lines + 1] = tostring(fmt)
        end
    end

    if not order then
        add("HironCraftProfit CO reagent debug: no order")
        return lines
    end

    local recipeName = "?"
    if order.spellID and C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
        local ok, info = pcall(C_TradeSkillUI.GetRecipeInfo, order.spellID)
        if ok and info and info.name then recipeName = info.name end
    end

    add("=== HironCraftProfit CO REAGENT DEBUG %s ===", title or "")
    add("ORDER orderID=%s spellID=%s recipe=%s customer=%s isRecraft=%s reagentState=%s tip=%s cut=%s minQ=%s", tostring(order.orderID), tostring(order.spellID), tostring(recipeName), tostring(order.customerName or "?"), tostring(order.isRecraft), tostring(order.reagentState), tostring(order.tipAmount), tostring(order.consortiumCut), tostring(order.minQuality))
    add("ORDER_KEYS {%s}", self:DebugTableKeys(order, 40))

    local orderReagents = order.reagents
    add("RAW order.reagents count=%s", tostring(type(orderReagents) == "table" and #orderReagents or "nil"))
    if type(orderReagents) == "table" then
        for i, reagentInfo in ipairs(orderReagents) do
            add(self:DebugReagentLine("RAW", i, reagentInfo))
        end
    end

    local schematic, schematicErr = self:DebugGetRecipeSchematic(order)
    if not schematic or type(schematic.reagentSlotSchematics) ~= "table" then
        add("SCHEMATIC missing err=%s hasSchematic=%s keys={%s}", tostring(schematicErr), tostring(schematic ~= nil), self:DebugTableKeys(schematic, 20))
    else
        add("SCHEMATIC slots=%d keys={%s}", #schematic.reagentSlotSchematics, self:DebugTableKeys(schematic, 28))
        local providedForSlots = GetOrderProvidedReagentQuantities(order)
        for index, slotSchematic in ipairs(schematic.reagentSlotSchematics) do
            local choices = GetSchematicReagentChoices(slotSchematic)
            local firstChoice, firstItemID = GetFirstSchematicChoice(slotSchematic)
            local firstPayload = firstChoice and GetOrderReagentPayload(firstChoice)
            local dataSlotIndex = slotSchematic.dataSlotIndex or slotSchematic.slotDataIndex or index
            local slotIndex = dataSlotIndex or slotSchematic.slotIndex or index
            local requiredQuantity = GetSlotRequiredQuantity(slotSchematic, firstPayload, nil)
            local providedQuantity = 0
            if firstItemID and requiredQuantity and requiredQuantity > 0 then
                providedQuantity = GetProvidedQuantityForSchematicSlot(slotSchematic, providedForSlots, requiredQuantity, slotIndex, dataSlotIndex)
            end
            local remaining = math.max(0, (tonumber(requiredQuantity) or 0) - (tonumber(providedQuantity) or 0))
            add("SLOT[%02d] slot=%s dataSlot=%s type=%s requiredSlot=%s basicAuto=%s optional=%s qtyReq=%s provided=%s remaining=%s firstItem=%s choices=%s keys={%s}",
                index,
                tostring(slotIndex or "nil"),
                tostring(dataSlotIndex or "nil"),
                tostring(GetSlotReagentType(slotSchematic) or "nil"),
                self:DebugBoolText(IsRequiredCraftingOrderReagentSlot(slotSchematic)),
                self:DebugBoolText(IsBasicOrAutomaticReagentSlot(slotSchematic)),
                self:DebugBoolText(IsOptionalOrFinishingReagentSlot(slotSchematic)),
                tostring(requiredQuantity or "nil"),
                tostring(providedQuantity or 0),
                tostring(remaining or 0),
                tostring(firstItemID or "nil"),
                self:DebugChoiceList(slotSchematic, 10),
                self:DebugTableKeys(slotSchematic, 20)
            )
            local matches = CollectOrderReagentsForSlot(order, slotIndex, dataSlotIndex, firstItemID)
            if type(matches) == "table" and #matches > 0 then
                for matchIndex, reagentInfo in ipairs(matches) do
                    add("  MATCH " .. self:DebugReagentLine("M", matchIndex, reagentInfo))
                end
            end
        end
    end

    local displayReagents = self:BuildDisplayReagents(order)
    add("DISPLAY count=%s schematicReady=%s", tostring(type(displayReagents) == "table" and #displayReagents or "nil"), tostring(displayReagents and displayReagents.ahuiSchematicReady))
    if type(displayReagents) == "table" then
        for i, reagentEntry in ipairs(displayReagents) do
            local selected = self:GetSelectedReagentForEntry(order.orderID, reagentEntry)
            add("DISPLAY[%02d] item=%s name=%s qty=%s slot=%s dataSlot=%s source=%s customer=%s crafter=%s selected=%s q=%s/%s exp=%s kind=%s candidates=%s", i,
                tostring(reagentEntry.itemID or "nil"),
                self:DebugSafeItemName(reagentEntry.itemID),
                tostring(reagentEntry.quantity or "nil"),
                tostring(reagentEntry.slotIndex or "nil"),
                tostring(reagentEntry.dataSlotIndex or "nil"),
                self:DebugSourceText(reagentEntry.source),
                self:DebugBoolText(IsCustomerProvidedReagent(reagentEntry)),
                self:DebugBoolText(IsCrafterProvidedReagent(reagentEntry)),
                selected and tostring(selected.itemID) or "nil",
                tostring(reagentEntry.qualityTier or "nil"),
                tostring(reagentEntry.maxQualityTier or "nil"),
                tostring(reagentEntry.expansionID or "nil"),
                tostring(reagentEntry.qualityKind or "nil"),
                tostring(type(reagentEntry.candidates) == "table" and #reagentEntry.candidates or "nil")
            )
        end
    end

    local craftingTbl = self:BuildCraftingReagentInfoTbl(order)
    add("CRAFTING_REAGENT_INFO_TBL count=%s", tostring(type(craftingTbl) == "table" and #craftingTbl or "nil"))
    if type(craftingTbl) == "table" then
        for i, reagentInfo in ipairs(craftingTbl) do
            add("CRAFT[%02d] item=%s name=%s qty=%s dataSlot=%s keys={%s}", i, tostring(reagentInfo.itemID or "nil"), self:DebugSafeItemName(reagentInfo.itemID), tostring(reagentInfo.quantity or "nil"), tostring(reagentInfo.dataSlotIndex or "nil"), self:DebugTableKeys(reagentInfo, 12))
        end
    end

    local profitInfo = self:GetOrderProfitInfo(order)
    if profitInfo then
        add("PROFIT profit=%s reagentCost=%s rewardValue=%s missingPrices=%s", tostring(profitInfo.profit), tostring(profitInfo.reagentCost), tostring(profitInfo.rewardValue), tostring(profitInfo.missingPrices))
    else
        add("PROFIT nil")
    end

    add("=== END HironCraftProfit CO REAGENT DEBUG orderID=%s ===", tostring(order.orderID))
    return lines
end

function CO:DebugStoreLines(lines)
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB.craftingOrders = HironCraftProfit_DB.craftingOrders or {}
    HironCraftProfit_DB.craftingOrders.lastReagentDebug = table.concat(lines or {}, "\n")
    HironCraftProfit_DB.craftingOrders.lastReagentDebugAt = date and date("%Y-%m-%d %H:%M:%S") or tostring(time and time() or "?")
end

function CO:DebugPrint(line)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cffb19cd9HironCraft CO DBG:|r " .. tostring(line))
    else
        print("HironCraft CO DBG: " .. tostring(line))
    end
end

function CO:DebugPrintLines(lines, maxLines)
    maxLines = tonumber(maxLines) or 80
    for i, line in ipairs(lines or {}) do
        if i > maxLines then
            self:DebugPrint("... чат обрезан: полный лог сохранён в HironCraftProfit_DB.craftingOrders.lastReagentDebug")
            break
        end
        self:DebugPrint(line)
    end
end

function CO:DebugFindOrderFromFrame(frame)
    local depth = 0
    while frame and depth < 12 do
        if frame.order and type(frame.order) == "table" then return frame.order end
        if frame.option and type(frame.option) == "table" then return frame.option end
        if frame.ahuiOrderActionButton and frame.ahuiOrderActionButton.order then return frame.ahuiOrderActionButton.order end
        frame = frame.GetParent and frame:GetParent() or nil
        depth = depth + 1
    end
    return nil
end

function CO:GetHoveredDebugOrder()
    if GetMouseFoci then
        local rawFoci = { GetMouseFoci() }
        local foci = rawFoci
        if #rawFoci == 1 and type(rawFoci[1]) == "table" and not rawFoci[1].GetParent then
            foci = rawFoci[1]
        end
        for _, focus in ipairs(foci) do
            local order = self:DebugFindOrderFromFrame(focus)
            if order then return order end
        end
    elseif GetMouseFocus then
        local order = self:DebugFindOrderFromFrame(GetMouseFocus())
        if order then return order end
    end

    local visible = self:GetVisibleDebugOrders()
    for _, entry in ipairs(visible) do
        local row = entry.row
        if row and IsFrameMouseOver and IsFrameMouseOver(row) then return entry.order end
        if row and row.ahuiOrderReagentsFrame and IsFrameMouseOver and IsFrameMouseOver(row.ahuiOrderReagentsFrame) then return entry.order end
        if row and row.ahuiOrderRewardsFrame and IsFrameMouseOver and IsFrameMouseOver(row.ahuiOrderRewardsFrame) then return entry.order end
        if row and row.ahuiOrderActionButton and IsFrameMouseOver and IsFrameMouseOver(row.ahuiOrderActionButton) then return entry.order end
    end

    return self.debugLastOrder
end

function CO:GetVisibleDebugOrders()
    local out = {}
    local seen = {}

    local function add(order, row, source)
        if type(order) ~= "table" or not order.orderID then return end
        local key = tostring(order.orderID)
        if seen[key] then return end
        seen[key] = true
        out[#out + 1] = { order = order, row = row, source = source }
    end

    local pageFrame = self.activePageFrame or self:FindOrderPageFrame()
    local scrollBox = pageFrame and pageFrame.BrowseFrame and pageFrame.BrowseFrame.OrderList and pageFrame.BrowseFrame.OrderList.ScrollBox
    local view = scrollBox and scrollBox.GetView and scrollBox:GetView()
    local frames = view and view.frames
    if type(frames) == "table" then
        for _, row in pairs(frames) do
            if row and (not row.IsShown or row:IsShown()) then
                local order = row.option or row.order or (row.GetElementData and row:GetElementData())
                if type(order) == "table" then
                    add(order.option or order.order or order, row, "scrollbox")
                end
            end
        end
    end

    if type(self.visibleRowButtons) == "table" then
        for btn in pairs(self.visibleRowButtons) do
            local row = btn and btn.GetParent and btn:GetParent()
            add(btn and btn.order, row, "button")
        end
    end

    return out
end

function CO:DebugDumpOrder(order, title, printLines)
    local lines = self:DebugCollectOrderLines(order, title)
    self:DebugStoreLines(lines)
    if printLines ~= false then
        self:DebugPrintLines(lines, 90)
    end
    self:DebugPrint("Полный лог сохранён: /dump HironCraftProfit_DB.craftingOrders.lastReagentDebug")
    return lines
end

function CO:DebugDumpVisibleOrders()
    local visible = self:GetVisibleDebugOrders()
    local allLines = {}
    local function push(line) allLines[#allLines + 1] = line end

    push("=== HironCraftProfit CO VISIBLE REAGENT DEBUG count=" .. tostring(#visible) .. " ===")
    for index, entry in ipairs(visible) do
        local order = entry.order
        local display = self:BuildDisplayReagents(order)
        local rawCount = type(order.reagents) == "table" and #order.reagents or 0
        push(string.format("VISIBLE[%02d] orderID=%s spellID=%s customer=%s rawReagents=%s display=%s source=%s", index, tostring(order.orderID), tostring(order.spellID), tostring(order.customerName or "?"), tostring(rawCount), tostring(type(display) == "table" and #display or "nil"), tostring(entry.source or "?")))
        local lines = self:DebugCollectOrderLines(order, "visible#" .. tostring(index))
        for _, line in ipairs(lines) do push(line) end
    end
    push("=== END HironCraftProfit CO VISIBLE REAGENT DEBUG ===")

    self:DebugStoreLines(allLines)
    self:DebugPrint("Видимых заказов: " .. tostring(#visible) .. ". Полный лог сохранён: /dump HironCraftProfit_DB.craftingOrders.lastReagentDebug")
    for index, entry in ipairs(visible) do
        local order = entry.order
        local display = self:BuildDisplayReagents(order)
        self:DebugPrint(string.format("[%02d] orderID=%s spellID=%s customer=%s raw=%s display=%s", index, tostring(order.orderID), tostring(order.spellID), tostring(order.customerName or "?"), tostring(type(order.reagents) == "table" and #order.reagents or "nil"), tostring(type(display) == "table" and #display or "nil")))
    end
    return allLines
end

function CO:DebugClearReagentCaches()
    self.displayReagentsCache = {}
    self.craftingReagentInfoCache = {}
    self.profitCache = {}
    self.qualityCache = {}
    if self.InvalidateOrderCaches then
        self:InvalidateOrderCaches()
    end
    self:RefreshVisibleRowsSoon(0)
end

function CO:HandleReagentDebugSlash(msg)
    msg = tostring(msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

    if msg == "on" then
        self.reagentDebugEnabled = true
        self:DebugPrint("debug ON. Alt+RightClick по иконке реагента или по колонке реагентов = dump заказа. /ahuicodbg hover, /ahuicodbg visible")
        self:RefreshVisibleRowsSoon(0)
        return
    elseif msg == "off" then
        self.reagentDebugEnabled = false
        self:DebugPrint("debug OFF")
        self:RefreshVisibleRowsSoon(0)
        return
    elseif msg == "clear" or msg == "reset" then
        self:DebugClearReagentCaches()
        self:DebugPrint("кэши реагентов очищены")
        return
    elseif msg == "visible" or msg == "all" then
        self:DebugDumpVisibleOrders()
        return
    elseif msg == "hover" or msg == "dump" or msg == "" then
        local order = self:GetHoveredDebugOrder()
        if not order then
            self:DebugPrint("не нашёл заказ под мышкой. Включи /ahuicodbg on и нажми Alt+ПКМ по колонке реагентов проблемной строки, либо /ahuicodbg visible")
            return
        end
        self:DebugDumpOrder(order, "hover")
        return
    elseif msg == "help" or msg == "?" then
        self:DebugPrint("/ahuicodbg on - включает диагностические клики")
        self:DebugPrint("/ahuicodbg hover - дамп заказа под мышкой")
        self:DebugPrint("/ahuicodbg visible - дамп всех видимых заказов")
        self:DebugPrint("/ahuicodbg clear - очистить кэши реагентов")
        self:DebugPrint("После дампа: /dump HironCraftProfit_DB.craftingOrders.lastReagentDebug")
        return
    end

    self:DebugPrint("неизвестная команда. Используй /ahuicodbg help")
end

if not CO.reagentDebugSlashInstalled then
    CO.reagentDebugSlashInstalled = true
    _G.SLASH_HIRONCRAFT_PROFITCOREAGENTDEBUG1 = "/ahuicodbg"
    _G.SLASH_HIRONCRAFT_PROFITCOREAGENTDEBUG2 = "/coadb"
    SlashCmdList["HIRONCRAFT_PROFITCOREAGENTDEBUG"] = function(msg)
        if CO and CO.HandleReagentDebugSlash then
            CO:HandleReagentDebugSlash(msg)
        end
    end
end
