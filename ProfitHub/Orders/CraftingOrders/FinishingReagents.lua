local E = _G.HironCraftProfitCraftingOrdersEnv
if not E then
    E = {}
    _G.HironCraftProfitCraftingOrdersEnv = E
    setmetatable(E, { __index = _G })
end
setfenv(1, E)
if not PT or not CO then return end

local QUALITY_REJECT_WINDOW_SECONDS = 30

-- Midnight exposes many reagents through the finishing slot, but only these
-- four add profession skill. Evaluating every entry by repeatedly rebuilding
-- Blizzard's live transaction causes a visible multi-second hitch.
local FINISHING_SKILL_BONUS_BY_ITEM_ID = {
    [246447] = 5,  -- Apprentice's Scribbles
    [246448] = 10, -- Artisan's Ledger
    [246449] = 20, -- Mentor's Helpful Handiwork
    [246450] = 50, -- Artisan's Consortium Gold Star
}

-- Separate item IDs, not interchangeable ranks. The catalog only populates
-- the picker; the live recipe schematic must still allow the selected item.
-- No automatic combining or fallback from a rare item to five lesser ones.
local MIDNIGHT_BONUS_FINISHERS = {247725, 247726, 247719, 247724, 260630, 247788}

local function GetOwnedItemCount(itemID)
    if not itemID then return 0 end

    if C_Item and type(C_Item.GetItemCount) == "function" then
        local ok, count = pcall(C_Item.GetItemCount, itemID, true, false, true, true)
        if ok and tonumber(count) then return tonumber(count) end
    end

    if type(GetItemCount) == "function" then
        local ok, count = pcall(GetItemCount, itemID, true, false, true)
        if ok and tonumber(count) then return tonumber(count) end
    end

    return 0
end

local function GetTransactionOperationInfo(transaction, order, useConcentration)
    if
        not transaction
        or not order
        or not order.spellID
        or not order.orderID
        or not C_TradeSkillUI
        or type(C_TradeSkillUI.GetCraftingOperationInfoForOrder) ~= "function"
        or type(transaction.CreateCraftingReagentInfoTbl) ~= "function"
    then
        return nil
    end

    local okReagents, reagents = pcall(transaction.CreateCraftingReagentInfoTbl, transaction)
    if not okReagents or type(reagents) ~= "table" then return nil end

    local attempts = {
        { order.spellID, reagents, order.orderID, useConcentration == true },
        { order.spellID, reagents, order.orderID },
    }
    for _, args in ipairs(attempts) do
        local ok, info = pcall(C_TradeSkillUI.GetCraftingOperationInfoForOrder, unpack(args))
        if ok and type(info) == "table" then return info end
    end

    return nil
end

local function ClearTransactionSlot(transaction, slotIndex)
    if
        not transaction
        or not slotIndex
        or type(transaction.GetAllocations) ~= "function"
        or type(transaction.OverwriteAllocations) ~= "function"
    then
        return false
    end

    return SafeCall("Clear finishing reagent", function()
        local allocations = transaction:GetAllocations(slotIndex)
        if not allocations or type(allocations.Clear) ~= "function" then
            error("finishing reagent allocations are unavailable")
        end
        allocations:Clear()
        transaction:OverwriteAllocations(slotIndex, allocations)
        if type(transaction.SetManuallyAllocated) == "function" then
            transaction:SetManuallyAllocated(true)
        end
    end) == true
end

local function AllocateFinishingReagent(transaction, candidate)
    if
        not transaction
        or not candidate
        or not candidate.slotIndex
        or not candidate.itemID
        or type(transaction.OverwriteAllocation) ~= "function"
    then
        return false
    end

    return SafeCall("Allocate finishing reagent", function()
        transaction:OverwriteAllocation(
            candidate.slotIndex,
            { itemID = candidate.itemID },
            candidate.quantity or 1
        )
        if type(transaction.SetManuallyAllocated) == "function" then
            transaction:SetManuallyAllocated(true)
        end
    end) == true
end

local function RefreshOrderEngine(engine, form)
    if form and type(form.UpdateDetailsStats) == "function" then
        SafeCall("UpdateDetailsStats", function() form:UpdateDetailsStats() end)
    end
    if engine and type(engine.UpdateCreateButton) == "function" then
        SafeCall("UpdateCreateButton", function() engine:UpdateCreateButton() end)
    end
end

function CO:GetFinishingReagentCandidates(order)
    local result = {}
    if
        not order
        or not order.spellID
        or not C_TradeSkillUI
        or type(C_TradeSkillUI.GetRecipeSchematic) ~= "function"
    then
        return result, false
    end

    local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, order.spellID, order.isRecraft == true)
    if not ok or type(schematic) ~= "table" or type(schematic.reagentSlotSchematics) ~= "table" then
        return result, false
    end

    local finishingType = Enum
        and Enum.CraftingReagentType
        and Enum.CraftingReagentType.Finishing
    local seen = {}

    for schematicIndex, slot in ipairs(schematic.reagentSlotSchematics) do
        local isFinishing = finishingType ~= nil and GetSlotReagentType(slot) == finishingType
        if isFinishing and Professions and Professions.GetReagentSlotStatus
            and C_TradeSkillUI.GetRecipeInfo then
            local recipeInfo = C_TradeSkillUI.GetRecipeInfo(order.spellID)
            if not recipeInfo then return result, false end
            local statusOK, locked = pcall(Professions.GetReagentSlotStatus, slot, recipeInfo)
            if not statusOK then return result, false end
            if locked then isFinishing = false end
        end
        if isFinishing then
            -- GetAllocations/OverwriteAllocation use the schematic's array
            -- position. dataSlotIndex belongs only to the serialized API payload.
            local slotIndex = schematicIndex
            local quantity = math.max(1, tonumber(slot.quantityRequired) or 1)
            for _, reagent in ipairs(slot.reagents or {}) do
                local itemID = GetOrderReagentItemID(reagent)
                local key = itemID and (tostring(slotIndex) .. ":" .. tostring(itemID))
                if key and not seen[key] then
                    seen[key] = true
                    result[#result + 1] = {
                        itemID = itemID,
                        slotIndex = slotIndex,
                        dataSlotIndex = slot.dataSlotIndex,
                        quantity = quantity,
                        owned = GetOwnedItemCount(itemID),
                        skillBonus = FINISHING_SKILL_BONUS_BY_ITEM_ID[itemID],
                    }
                end
            end
        end
    end

    return result, true
end

function CO:GetFinishingItemLabel(itemID)
    if C_Item and C_Item.GetItemInfo then
        local _, link = C_Item.GetItemInfo(itemID)
        if link then return link end
    end
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
    if not name and C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    end
    return name or ("Item " .. tostring(itemID))
end

function CO:GetPreferredFinishingMenuItems()
    local items, seen, recipes = {}, {}, {}
    local function AddItem(id)
        if id and not seen[id] and not FINISHING_SKILL_BONUS_BY_ITEM_ID[id] then
            seen[id] = true
            items[#items + 1] = {itemID=id, name=self:GetFinishingItemLabel(id), owned=GetOwnedItemCount(id)}
        end
    end
    local function AddOrder(order)
        if not order or not order.spellID then return end
        local key = tostring(order.spellID) .. ':' .. tostring(order.isRecraft == true)
        if recipes[key] then return end
        recipes[key] = true
        local candidates = self:GetFinishingReagentCandidates(order)
        for _, candidate in ipairs(candidates) do AddItem(candidate.itemID) end
    end
    AddItem(self:GetPreferredFinishingItemID())
    for _, id in ipairs(MIDNIGHT_BONUS_FINISHERS) do AddItem(id) end
    if self.GetClaimedOrder then AddOrder(self:GetClaimedOrder()) end
    if self.CustomList and self.CustomList.GetOrders then
        for _, order in ipairs(self.CustomList:GetOrders(self.activePageFrame) or {}) do AddOrder(order) end
    end
    table.sort(items, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.itemID < b.itemID
    end)
    return items
end

local function CustomerOwnsSlot(order, candidate, engine)
    if engine and engine.reagentSlotProvidedByCustomer
        and engine.reagentSlotProvidedByCustomer[candidate.slotIndex] then return true end
    for _, reagent in ipairs(order.reagents or {}) do
        local dataSlot = GetOrderReagentDataSlotIndex and GetOrderReagentDataSlotIndex(reagent)
            or reagent.dataSlotIndex
        if dataSlot ~= nil and tonumber(dataSlot) == tonumber(candidate.dataSlotIndex) then return true end
    end
    return false
end

-- Snapshot a finishing slot before trying a replacement. A failed simulation
-- must not erase a manually chosen reagent (or any other finishing slot).
local function SnapshotSlot(transaction, slotIndex)
    local ok, snapshot = pcall(function()
        local allocations = transaction:GetAllocations(slotIndex)
        if not allocations or not allocations.GetFirstAllocation then return nil end
        if allocations.GetSize and allocations:GetSize() > 1 then return nil end
        local first = allocations:GetFirstAllocation()
        if not first then return {} end
        return {reagent=first:GetReagent(), quantity=first:GetQuantity()}
    end)
    return ok and snapshot or nil
end

local function RestoreSlot(transaction, slotIndex, snapshot)
    if snapshot.reagent then
        return SafeCall("Restore finishing reagent", function()
            transaction:OverwriteAllocation(slotIndex, snapshot.reagent, snapshot.quantity)
        end) == true
    end
    return ClearTransactionSlot(transaction, slotIndex)
end

function CO:HasPreparedFinishingReagent(order, reagentTbl)
    local selected = self.preparedFinisherReagent
    if not selected or not selected.itemID or not selected.dataSlotIndex
        or not SameOrderID(self.preparedFinisherOrderID, order and order.orderID)
        or type(reagentTbl) ~= "table" then
        return false
    end
    for _, reagentInfo in ipairs(reagentTbl) do
        local itemID = GetOrderReagentItemID(reagentInfo)
        if tonumber(itemID) == tonumber(selected.itemID)
            and tonumber(reagentInfo.dataSlotIndex) == tonumber(selected.dataSlotIndex)
            and (tonumber(reagentInfo.quantity) or 0) >= (selected.quantity or 1) then
            return true
        end
    end
    return false
end

function CO:MarkOrderReadyForQualityRejection(order)
    local key = OrderKey(order and order.orderID)
    if not key then return end
    self.qualityRejectOrderIDs = self.qualityRejectOrderIDs or {}
    self.qualityRejectOrderIDs[key] = (GetTime and GetTime() or 0) + QUALITY_REJECT_WINDOW_SECONDS
end

function CO:IsOrderReadyForQualityRejection(order)
    local key = OrderKey(order and order.orderID)
    local expiresAt = key and self.qualityRejectOrderIDs and self.qualityRejectOrderIDs[key]
    if not expiresAt then return false end
    if expiresAt <= (GetTime and GetTime() or 0) then
        self.qualityRejectOrderIDs[key] = nil
        return false
    end
    return true
end

function CO:ClearOrderQualityRejection(order)
    local key = OrderKey(order and order.orderID)
    if key and self.qualityRejectOrderIDs then
        self.qualityRejectOrderIDs[key] = nil
    end
end

function CO:PrepareAutoFinishingReagent(engine, order, useConcentration, pageFrame)
    local skillEnabled = self.IsAutoFinishingEnabled and self:IsAutoFinishingEnabled()
    local preferredEnabled = self.ShouldUsePreferredFinisher and self:ShouldUsePreferredFinisher(order)
    if not skillEnabled and not preferredEnabled then
        return "disabled"
    end
    if not self:IsPersonalCraftingOrder(order, pageFrame or self.activePageFrame) then
        return "disabled"
    end

    local requestedQuality = self:GetOrderRequestedQuality(order)
    if requestedQuality <= 0 and not preferredEnabled then return "not_needed" end

    local transaction, form = self:GetTransactionFromEngine(engine)
    if not transaction then return "unknown" end
    if
        type(transaction.OverwriteAllocation) ~= "function"
        or type(transaction.GetAllocations) ~= "function"
        or type(transaction.OverwriteAllocations) ~= "function"
    then
        return "unknown"
    end

    local baseQuality
    if requestedQuality > 0 then
        local baseInfo = GetTransactionOperationInfo(transaction, order, useConcentration)
        baseQuality = self:BuildQualityInfoFromOperationInfo(order, baseInfo, useConcentration)
        if not baseQuality or not tonumber(baseQuality.quality) or baseQuality.quality <= 0 then return "unknown" end
    end
    local needsSkill = baseQuality and baseQuality.quality < requestedQuality
    if not needsSkill then
        self:ClearOrderQualityRejection(order)
    end

    if not needsSkill and not preferredEnabled then return "not_needed" end
    local candidates, schematicReady = self:GetFinishingReagentCandidates(order)
    if not schematicReady then return "unknown" end

    if not needsSkill or not skillEnabled then
        -- One explicitly selected non-skill item; no automatic substitutions,
        -- no patron orders, and no overwriting customer/manual allocations.
        if not preferredEnabled then return "not_needed" end
        local preferredID = self:GetPreferredFinishingItemID()
        for _, candidate in ipairs(candidates) do
            if candidate.itemID == preferredID and not candidate.skillBonus
                and candidate.owned >= candidate.quantity and not CustomerOwnsSlot(order, candidate, engine) then
                local snapshot = SnapshotSlot(transaction, candidate.slotIndex)
                if not snapshot then return "unknown" end
                if not snapshot.reagent then
                    if not AllocateFinishingReagent(transaction, candidate) then
                        RestoreSlot(transaction, candidate.slotIndex, snapshot)
                        return "unknown"
                    end
                    -- An ordinary bonus must never lower an already attainable
                    -- requested quality (some finishing reagents have tradeoffs).
                    if requestedQuality > 0 then
                        local info = GetTransactionOperationInfo(transaction, order, useConcentration)
                        local quality = self:BuildQualityInfoFromOperationInfo(order, info, useConcentration)
                        if not quality or not tonumber(quality.quality) then
                            RestoreSlot(transaction, candidate.slotIndex, snapshot)
                            return "unknown"
                        end
                        if quality.quality < math.min(requestedQuality, baseQuality.quality) then
                            if not RestoreSlot(transaction, candidate.slotIndex, snapshot) then return "unknown" end
                            return "not_needed"
                        end
                    end
                    RefreshOrderEngine(engine, form)
                    self:InvalidateOrderCaches(order.orderID)
                    return "applied", candidate
                end
            end
        end
        return "not_needed"
    end

    local maxAllowed = self:GetAutoFinishingMaxSkillBonus()
    local currentSkill = tonumber(baseQuality.skill)
    local nextQualitySkill = tonumber(baseQuality.upper)
    local minimumSkillBonus = 1
    if currentSkill and nextQualitySkill and nextQualitySkill > currentSkill then
        minimumSkillBonus = math.max(1, math.ceil(nextQualitySkill - currentSkill))
    end
    local eligible = {}

    for _, candidate in ipairs(candidates) do
        if candidate.skillBonus
            and candidate.skillBonus >= minimumSkillBonus
            and candidate.skillBonus <= maxAllowed
            and candidate.owned >= candidate.quantity
            and not CustomerOwnsSlot(order, candidate, engine)
        then
            eligible[#eligible + 1] = candidate
        end
    end

    table.sort(eligible, function(lhs, rhs)
        if lhs.skillBonus ~= rhs.skillBonus then return lhs.skillBonus < rhs.skillBonus end
        return lhs.itemID < rhs.itemID
    end)

    local selected
    for _, candidate in ipairs(eligible) do
        local snapshot = SnapshotSlot(transaction, candidate.slotIndex)
        if not snapshot then return "unknown" end
        if AllocateFinishingReagent(transaction, candidate) then
            -- The transaction allocation is immediately reflected by
            -- CreateCraftingReagentInfoTbl(). Refreshing the whole Blizzard
            -- form here is unnecessary and was the source of the frame hitch.
            local operationInfo = GetTransactionOperationInfo(transaction, order, useConcentration)
            local qualityInfo = self:BuildQualityInfoFromOperationInfo(order, operationInfo, useConcentration)
            if not qualityInfo or not tonumber(qualityInfo.quality) or qualityInfo.quality <= 0 then
                RestoreSlot(transaction, candidate.slotIndex, snapshot)
                return "unknown"
            end
            if qualityInfo.quality >= requestedQuality then
                selected = candidate
            end
            if not RestoreSlot(transaction, candidate.slotIndex, snapshot) then return "unknown" end
            if selected then break end
        else
            RestoreSlot(transaction, candidate.slotIndex, snapshot)
            return "unknown"
        end
    end

    if selected then
        local snapshot = SnapshotSlot(transaction, selected.slotIndex)
        if not snapshot then return "unknown" end
        if not AllocateFinishingReagent(transaction, selected) then
            RestoreSlot(transaction, selected.slotIndex, snapshot)
            return "unknown"
        end
        RefreshOrderEngine(engine, form)
        self:ClearOrderQualityRejection(order)
        self:InvalidateOrderCaches(order.orderID)
        return "applied", selected
    end

    RefreshOrderEngine(engine, form)
    self:MarkOrderReadyForQualityRejection(order)
    return "reject", {
        currentQuality = tonumber(baseQuality.quality) or 0,
        requestedQuality = requestedQuality,
        maxAllowed = maxAllowed,
    }
end
