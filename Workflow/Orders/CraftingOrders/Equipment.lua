local E = _G.HironCraftProfitCraftingOrdersEnv
if not E or not E.CO then return end
setfenv(1, E)

local function Context(self, page)
    local owner = UnitGUID and UnitGUID("player")
    local profession = self.GetActiveBaseProfessionID and self:GetActiveBaseProfessionID(page or self.activePageFrame)
    return owner, profession and tostring(profession)
end

function CO:GetOrderExpansionKey(order)
    if order and order.hironPatronExpansionKey then return order.hironPatronExpansionKey end
    local id = order and order.hironPatronExpansionID
        or (self.GetOrderProfessionExpansionID and self:GetOrderProfessionExpansionID(order))
    local option = id and FindExpansionOptionByExpansionID and FindExpansionOptionByExpansionID(id)
    return option and option.key
end

local function Bucket(self, field, create, page)
    local owner, profession = Context(self, page)
    if not owner or not profession then return nil end
    local db = GetDB()
    if create then db[field] = db[field] or {}; db[field][owner] = db[field][owner] or {} end
    local all = db[field] and db[field][owner]
    if create then all[profession] = all[profession] or {} end
    return all and all[profession]
end

function CO:GetKnowledgeExpansionProfitOverride(key)
    local bucket = Bucket(self, "knowledgeProfitOverrides", false)
    return bucket and tonumber(bucket[key])
end

function CO:SetKnowledgeExpansionProfitOverride(key, value)
    if key ~= "midnight" and key ~= "tww" then return false end
    local bucket = Bucket(self, "knowledgeProfitOverrides", true)
    if not bucket then return false end
    if self.queueSelectionRunning then self:CancelQueueSelection() end
    bucket[key] = tonumber(value)
    self:RecheckQueuedSelections(nil, true)
    if self.UpdateControlPanel then self:UpdateControlPanel() end
    return true
end

function CO:IsOrderEquipmentOn()
    local bucket = Bucket(self, "professionEquipmentProfiles", false)
    return bucket and bucket.autoEnabled == true or false
end

function CO:SetOrderEquipmentOn(value)
    if self.IsOrderSubmissionPending and self:IsOrderSubmissionPending() then
        self:SetStatus(T("COA_EQUIPMENT_BUSY", "Finish the current action and clear the cursor before changing equipment.")); return false
    end
    if self.queueSelectionRunning then self:CancelQueueSelection() end
    local bucket = Bucket(self, "professionEquipmentProfiles", true)
    if not bucket then return false end
    bucket.autoEnabled = value == true
    self._equipmentSwapPending = nil
    self._equipmentPlanCache = nil
    self.qualityRejectOrderIDs, self.qualityRejectDetails = nil, nil
    if self.InvalidateOrderCaches then self:InvalidateOrderCaches() end
    if value ~= true then self._equipmentDeferredOrders = nil end
    if self.RefreshVisibleRowsSoon then self:RefreshVisibleRowsSoon() end
end

local function Slots(page)
    if not C_TradeSkillUI or not C_TradeSkillUI.GetProfessionSlots then return nil end
    local profession = GetProfessionFromPage(page)
    if not profession then return nil end
    local ok, slots = pcall(C_TradeSkillUI.GetProfessionSlots, profession)
    if not ok or type(slots) ~= "table" or #slots == 0 then return nil end
    local result = {}
    for _, slot in ipairs(slots) do
        slot = tonumber(type(slot) == "table" and (slot.slot or slot.slotID or slot.slotId
            or slot.inventorySlot or slot.inventorySlotID or slot.inventorySlotId or slot.inventorySlotIndex or slot.invSlot) or slot)
        if not slot then return nil end
        result[#result + 1] = slot
    end
    return result
end

local function GUID(inventorySlot, bag, slot)
    if not ItemLocation or not C_Item or not C_Item.GetItemGUID then return nil end
    local ok, value = pcall(function()
        local location = inventorySlot and ItemLocation:CreateFromEquipmentSlot(inventorySlot)
            or ItemLocation:CreateFromBagAndSlot(bag, slot)
        return C_Item.GetItemGUID(location)
    end)
    return ok and value or nil
end

local function Equipped(slot)
    local id = GetInventoryItemID and GetInventoryItemID("player", slot)
    if not id then return nil end
    return { itemID = id, link = GetInventoryItemLink and GetInventoryItemLink("player", slot), guid = GUID(slot) }
end

local function Matches(wanted, found)
    if not wanted or not found or wanted.itemID ~= found.itemID then return false end
    if wanted.guid then return wanted.guid == found.guid end
    return wanted.link ~= nil and wanted.link == found.link
end

local function BagItem(bag, slot)
    local info = C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
    if not info then return nil end
    return { itemID = info.itemID, link = info.hyperlink or (C_Container.GetContainerItemLink and C_Container.GetContainerItemLink(bag, slot)),
        guid = GUID(nil, bag, slot), locked = info.isLocked }
end

local function ExpansionLabel(key)
    local option = FindExpansionOptionByKey and FindExpansionOptionByKey(key)
    return option and T(option.labelKey, option.fallback)
        or (key == "tww" and "TWW" or key == "midnight" and "Midnight" or key)
end

function CO:GetProfessionEquipmentProfile(key, page)
    local bucket = Bucket(self, "professionEquipmentProfiles", false, page)
    return bucket and bucket[key]
end

function CO:SaveProfessionEquipmentProfile(key, page)
    page = page or self.activePageFrame
    if not (FindExpansionOptionByKey and FindExpansionOptionByKey(key)) then return false end
    if self:IsOrderSubmissionPending() or self.queueSelectionRunning
        or (InCombatLockdown and InCombatLockdown()) or (CursorHasItem and CursorHasItem()) then
        self:SetStatus(T("COA_EQUIPMENT_BUSY", "Finish the current action and clear the cursor before changing equipment.")); return false
    end
    local slots, bucket = Slots(page), Bucket(self, "professionEquipmentProfiles", true, page)
    if not slots or not bucket then return false end
    local profile = { slots = {} }
    for _, slot in ipairs(slots) do
        local item = Equipped(slot)
        if not item or (not item.guid and not item.link) then
            self:SetStatus(T("COA_EQUIPMENT_INCOMPLETE", "Equip the profession tool and all accessories before saving a set.")); return false
        end
        profile.slots[tostring(slot)] = item
    end
    bucket[key] = profile
    self._equipmentSwapPending = nil
    self._equipmentPlanCache = nil
    self:SetStatus(string.format(T("COA_EQUIPMENT_SAVED", "%s set saved for this character and profession."), ExpansionLabel(key)))
    if self.UpdateQueueSettingWidgets then self:UpdateQueueSettingWidgets() end
    return true
end

-- Read-only planning is used by row drawing and queue analysis. Only the
-- hardware-click path below moves items. Never substitute another grade or
-- enchant of an item merely because its itemID matches.
function CO:GetOrderEquipmentPlan(order, page, fresh)
    if not self:IsOrderEquipmentOn() then return "ready" end
    local key = self:GetOrderExpansionKey(order)
    if not key then return "blocked", T("COA_EQUIPMENT_EXPANSION_WAIT", "The order's expansion is not known yet. Refresh its details.") end
    local profile = self:GetProfessionEquipmentProfile(key, page)
    if not profile then
        return "blocked", string.format(T("COA_EQUIPMENT_NO_SET", "Save a %s profession equipment set in the Crafting settings first."), ExpansionLabel(key))
    end
    local slots = Slots(page or self.activePageFrame)
    if not slots then return "blocked", T("COA_EQUIPMENT_INCOMPLETE", "Equip the profession tool and all accessories before saving a set.") end
    local signature = { tostring(UnitGUID and UnitGUID("player")), tostring(profile) }
    for _, slot in ipairs(slots) do
        local item = Equipped(slot)
        signature[#signature + 1] = tostring(slot) .. ":" .. tostring(item and (item.guid or item.link))
    end
    signature = table.concat(signature, ";")
    local now = GetTime and GetTime() or 0
    local cached = self._equipmentPlanCache
    if not fresh and cached and cached.signature == signature and now < cached.expires then
        return cached.state, cached.reason, cached.moves
    end
    local function Result(state, reason, moves)
        self._equipmentPlanCache = { signature = signature, expires = now + 0.1, state = state, reason = reason, moves = moves }
        return state, reason, moves
    end
    local pending = self._equipmentSwapPending
    if pending and now < pending.readyAt then
        return Result("waiting", T("COA_EQUIPMENT_WAIT", "Waiting for profession equipment to finish changing."))
    end
    local moves, used = {}, {}
    for _, target in ipairs(slots) do
        local wanted = profile.slots and profile.slots[tostring(target)]
        if not wanted then return Result("blocked", T("COA_EQUIPMENT_INCOMPLETE", "Equip the profession tool and all accessories before saving a set.")) end
        if not Matches(wanted, Equipped(target)) then
            local found
            local lastBag = tonumber(_G.NUM_TOTAL_EQUIPPED_BAG_SLOTS) or tonumber(_G.NUM_BAG_SLOTS) or 4
            -- Accessories may already be worn in the opposite accessory slot.
            for _, source in ipairs(slots) do
                if source ~= target and not Matches(profile.slots[tostring(source)], Equipped(source))
                    and Matches(wanted, Equipped(source)) then
                    found = { inventorySlot = source, target = target, wanted = wanted }; break
                end
            end
            for bag = 0, lastBag do
                if found then break end
                local count = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag) or 0
                for slot = 1, count do
                    local locationKey = bag .. ":" .. slot
                    local info = BagItem(bag, slot)
                    if info and not used[locationKey] and Matches(wanted, info) then
                        if info.locked then return Result("waiting", T("COA_EQUIPMENT_WAIT", "Waiting for profession equipment to finish changing.")) end
                        found = { bag = bag, slot = slot, target = target, wanted = wanted }
                        used[locationKey] = true; break
                    end
                end
                if found then break end
            end
            if not found then return Result("blocked", T("COA_EQUIPMENT_MISSING", "A saved equipment item is missing from your bags. Retrieve it or save the set again.")) end
            moves[#moves + 1] = found
        end
    end
    if #moves > 0 then return Result("swap", nil, moves) end
    return Result("ready")
end

function CO:PrepareOrderEquipment(order, page)
    if not self:IsOrderEquipmentOn() then return true end
    if not order or not order.orderID then return false end
    local known = self.GetRecipeKnownState and self:GetRecipeKnownState(order)
    if known ~= true then
        self:SetStatus(known == false and T("COA_STATUS_UNKNOWN_RECIPE", "This recipe is not known by this character.")
            or T("COA_EQUIPMENT_RECIPE_WAIT", "Recipe data is still loading. Try Next step again in a moment."))
        if self.RefreshVisibleRowsSoon then self:RefreshVisibleRowsSoon() end
        return false
    end
    if self:IsOrderSubmissionPending() or self.queueSelectionRunning
        or (InCombatLockdown and InCombatLockdown()) or (CursorHasItem and CursorHasItem()) then
        self:SetStatus(T("COA_EQUIPMENT_BUSY", "Finish the current action and clear the cursor before changing equipment.")); return false
    end
    if self.viewingCachedOrders or (page and page.ahuiViewingCachedOrders)
        or (self.IsAtUsableCraftingOrderTable and not self:IsAtUsableCraftingOrderTable(page)) then return false end
    local claimed = self.GetClaimedOrder and self:GetClaimedOrder()
    if claimed and not SameOrderID(claimed.orderID, order.orderID) then return false end
    local state, reason, moves = self:GetOrderEquipmentPlan(order, page, true)
    if state ~= "ready" and state ~= "swap" then self:SetStatus(reason); return false end
    if state == "swap" then
        if not (C_Container and C_Container.PickupContainerItem and PickupInventoryItem and CursorHasItem) then return false end
        local changed = false
        -- Resolve again after every move: one accessory swap can fix two slots,
        -- and Blizzard may lock/update the remaining bag slots immediately.
        for _ = 1, #moves do
            local current, _, freshMoves = self:GetOrderEquipmentPlan(order, page, true)
            if current ~= "swap" then break end
            local move = freshMoves[1]
            local ok = pcall(function()
                local source = move.inventorySlot and Equipped(move.inventorySlot) or BagItem(move.bag, move.slot)
                if not Matches(move.wanted, source) or source.locked then error("equipment source changed") end
                if move.inventorySlot then PickupInventoryItem(move.inventorySlot)
                else C_Container.PickupContainerItem(move.bag, move.slot) end
                if not CursorHasItem() then error("item pickup did not succeed") end
                changed = true
                PickupInventoryItem(move.target)
                if CursorHasItem() then
                    if move.inventorySlot then PickupInventoryItem(move.inventorySlot)
                    else C_Container.PickupContainerItem(move.bag, move.slot) end
                end
                if CursorHasItem() then error("item swap did not finish") end
            end)
            if not ok then
                if ClearCursor then ClearCursor() end
                break
            end
        end
        if not changed then
            self:SetStatus(T("COA_EQUIPMENT_WAIT", "Waiting for profession equipment to finish changing.")); return false
        end
        self._equipmentSwapPending = { readyAt = (GetTime and GetTime() or 0) + 0.35 }
        self._equipmentPlanCache = nil
        if self.InvalidateOrderCaches then self:InvalidateOrderCaches() end
        if self.ClearOrderQualityRejection then self:ClearOrderQualityRejection(order) end
        self.preparedFinisherOrderID, self.preparedFinisherReagent, self.preparedFinisherReadyAt = nil, nil, nil
        self.preparedFinisherUseEngineOrderID = nil
        self:SetStatus(T("COA_EQUIPMENT_CHANGED", "Equipment changed. Press Next step again after the quality updates."))
        if self.RefreshVisibleRowsSoon then self:RefreshVisibleRowsSoon(0.4) end
        return false
    end
    local deferred = self._equipmentDeferredOrders and self._equipmentDeferredOrders[OrderKey(order.orderID)]
    if deferred and deferred.context == self._orderSelectionContext then
        local ok, analysis = pcall(self.GetAvailabilityQueueAnalysis, self, order, order.orderType, deferred.opts, page)
        if not ok or not analysis or not analysis.queued or analysis.needsEquipment then
            self:SetStatus((self.GetQueueSkipReason and self:GetQueueSkipReason(order))
                or T("COA_EQUIPMENT_QUALITY_WAIT", "Quality with this set is not confirmed. Check reagents and concentration.")); return false
        end
        self.useConcentration[OrderKey(order.orderID)] = analysis.useConcentration == true or nil
        self._equipmentDeferredOrders[OrderKey(order.orderID)] = nil
    end
    return true
end

-- Guard direct claim/craft entry points too, without moving items from a timer
-- or doing any preparation outside the explicitly clicked action path.
function CO:IsOrderEquipmentReadyForSubmission(order, page)
    if not self:IsOrderEquipmentOn() then return true end
    local state, reason = self:GetOrderEquipmentPlan(order, page, true)
    if state ~= "ready" or self:NeedsEquipmentQueueRecheck(order) then
        self:SetStatus(reason or T("COA_EQUIPMENT_QUALITY_WAIT", "Quality with this set is not confirmed. Check reagents and concentration."))
        return false
    end
    return true
end

function CO:RememberEquipmentQueueAnalysis(order, analysis)
    self._equipmentDeferredOrders = self._equipmentDeferredOrders or {}
    local key = OrderKey(order.orderID)
    self._equipmentDeferredOrders[key] = analysis and analysis.needsEquipment and {
        opts = analysis.equipmentOptions, context = self._orderSelectionContext,
    } or nil
end

function CO:NeedsEquipmentQueueRecheck(order)
    if not self:IsOrderEquipmentOn() then return false end
    local deferred = order and self._equipmentDeferredOrders and self._equipmentDeferredOrders[OrderKey(order.orderID)]
    return deferred and deferred.context == self._orderSelectionContext or false
end
