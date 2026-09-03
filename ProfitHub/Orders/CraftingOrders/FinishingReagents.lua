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
        if isFinishing then
            local slotIndex = slot.dataSlotIndex or slot.slotIndex or schematicIndex
            local quantity = tonumber(slot.quantityRequired) or 1
            for _, reagent in ipairs(slot.reagents or {}) do
                local itemID = GetOrderReagentItemID(reagent)
                local key = itemID and (tostring(slotIndex) .. ":" .. tostring(itemID))
                if key and not seen[key] then
                    seen[key] = true
                    result[#result + 1] = {
                        itemID = itemID,
                        slotIndex = slotIndex,
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
    if not self.IsAutoFinishingEnabled or not self:IsAutoFinishingEnabled() then
        return "disabled"
    end
    if not self:IsPersonalCraftingOrder(order, pageFrame or self.activePageFrame) then
        return "disabled"
    end

    local requestedQuality = self:GetOrderRequestedQuality(order)
    if requestedQuality <= 0 then return "not_needed" end

    local transaction, form = self:GetTransactionFromEngine(engine)
    if not transaction then return "unknown" end
    if
        type(transaction.OverwriteAllocation) ~= "function"
        or type(transaction.GetAllocations) ~= "function"
        or type(transaction.OverwriteAllocations) ~= "function"
    then
        return "unknown"
    end

    local baseInfo = GetTransactionOperationInfo(transaction, order, useConcentration)
    local baseQuality = self:BuildQualityInfoFromOperationInfo(order, baseInfo, useConcentration)
    if not baseQuality then return "unknown" end
    if tonumber(baseQuality.quality) and baseQuality.quality >= requestedQuality then
        self:ClearOrderQualityRejection(order)
        return "not_needed"
    end

    local candidates, schematicReady = self:GetFinishingReagentCandidates(order)
    if not schematicReady then return "unknown" end

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
        if AllocateFinishingReagent(transaction, candidate) then
            -- The transaction allocation is immediately reflected by
            -- CreateCraftingReagentInfoTbl(). Refreshing the whole Blizzard
            -- form here is unnecessary and was the source of the frame hitch.
            local operationInfo = GetTransactionOperationInfo(transaction, order, useConcentration)
            local qualityInfo = self:BuildQualityInfoFromOperationInfo(order, operationInfo, useConcentration)
            if qualityInfo and (tonumber(qualityInfo.quality) or 0) >= requestedQuality then
                selected = candidate
            end
            ClearTransactionSlot(transaction, candidate.slotIndex)
            if selected then break end
        end
    end

    if selected and AllocateFinishingReagent(transaction, selected) then
        RefreshOrderEngine(engine, form)
        self:ClearOrderQualityRejection(order)
        self:InvalidateOrderCaches(order.orderID)
        return "applied", selected
    end

    local clearedSlots = {}
    for _, candidate in ipairs(candidates) do
        if candidate.slotIndex and not clearedSlots[candidate.slotIndex] then
            clearedSlots[candidate.slotIndex] = true
            ClearTransactionSlot(transaction, candidate.slotIndex)
        end
    end
    RefreshOrderEngine(engine, form)
    self:MarkOrderReadyForQualityRejection(order)
    return "reject", {
        currentQuality = tonumber(baseQuality.quality) or 0,
        requestedQuality = requestedQuality,
        maxAllowed = maxAllowed,
    }
end
