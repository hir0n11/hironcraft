local PT = HironCraftProfit
if not PT then return end

PT.StackAssist = PT.StackAssist or {}
local SA = PT.StackAssist
local L = PT.L or {}

local BAG_MOVE_DELAY = 2.0
local MAX_ETA_SAMPLES = 100
local DEFAULT_MIN_STACK_TO_BEGIN = 50
local DEFAULT_MIN_REMAINING_CASTS = 20
local SMALL_STACK_TRIGGER = 30
local SMALL_STACK_REMAINING = 10

local MAX_SPEND_SAMPLES = 20

SA.state = SA.state or {
    token = 0,
    combineToken = 0,  
    combining = false,
    active = false,
    recipeID = nil,
    itemID = nil,
    isSalvage = false,
    restartNoticeShown = false,

    timerSamples = {},
    timerValue = 0,
    timerCraftID = nil,
    refreshCount = 0,
    countdownRunning = false,
    timestamp = 0,
    windowTriggered = false,

    stopToken = 0,

    lastBagCount = nil,         
    spendSamples = {},          
    resourcefulnessProcs = 0,   
    craftCount = 0,             
}

local scrubsecretvalues = _G.scrubsecretvalues
local function Chat(msg) end
local function ScrubSecret(value)
    if scrubsecretvalues then
        return scrubsecretvalues(value)
    end
    return value
end

function SA:IsEnabled()
    return true
end

function PT:IsStackAssistEnabled()
    return SA:IsEnabled()
end

local function GetBagMaxIndex()
    local extra = tonumber(NUM_REAGENTBAG_SLOTS) or 0
    return (tonumber(NUM_BAG_SLOTS) or 4) + extra
end

local function IteratePlayerBags(callback)
    for bag = 0, GetBagMaxIndex() do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local stop = callback(bag, slot)
            if stop then
                return
            end
        end
    end
end

local function GetProfessionForm()
    if not ProfessionsFrame
        or not ProfessionsFrame.CraftingPage
        or not ProfessionsFrame.CraftingPage.SchematicForm
    then
        return nil
    end

    local form = ProfessionsFrame.CraftingPage.SchematicForm
    if not form:IsVisible() then
        return nil
    end

    return form
end

local function ResolveRecipeID(recipeID)
    recipeID = ScrubSecret(recipeID)
    if type(recipeID) == "number" and recipeID > 0 then
        return recipeID
    end

    local form = GetProfessionForm()
    if form and form.GetRecipeInfo then
        local info = form:GetRecipeInfo()
        local formRecipeID = info and ScrubSecret(info.recipeID)
        if type(formRecipeID) == "number" and formRecipeID > 0 then
            return formRecipeID
        end
    end

    local stateRecipeID = SA.state and ScrubSecret(SA.state.recipeID)
    if type(stateRecipeID) == "number" and stateRecipeID > 0 then
        return stateRecipeID
    end

    return nil
end

local function GetRecipeReagentCount(recipeID)
    recipeID = ResolveRecipeID(recipeID)
    if not recipeID then
        return 1
    end

    local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
    if not ok or not schematic then
        return 1
    end

    if schematic.quantityMax and schematic.quantityMax > 0 then
        return schematic.quantityMax
    end

    if schematic.reagentSlotSchematics then
        for _, slot in ipairs(schematic.reagentSlotSchematics) do
            local qty = tonumber(slot.quantityRequired or slot.requiredQuantity or 0)
            if qty and qty > 0 then
                return qty
            end
        end
    end

    return 1
end

function SA:GetEffectivePerCraft(recipeID)
    local base = GetRecipeReagentCount(recipeID)
    local samples = self.state.spendSamples
    if not samples or #samples < 3 then
        return base
    end

    local sum = 0
    for i = 1, #samples do
        sum = sum + samples[i]
    end
    return math.max(1, math.min(base, sum / #samples))
end

function SA:StartSession(recipeID, itemID, isSalvage)
    self.state.active = true
    self.state.recipeID = ResolveRecipeID(recipeID)
    self.state.itemID = ScrubSecret(itemID) or self.state.itemID
    self.state.isSalvage = isSalvage == true
    self.state.restartNoticeShown = false
    self.state.stopToken = (self.state.stopToken or 0) + 1

    self.state.lastBagCount = nil
    self.state.spendSamples = {}
    self.state.resourcefulnessProcs = 0
    self.state.craftCount = 0
end

function SA:StopSession()
    self.state.active = false
    self.state.combining = false
    self.state.restartNoticeShown = false
    self.state.recipeID = nil
    self.state.itemID = nil
    self.state.isSalvage = false

    self.state.token = (self.state.token or 0) + 1
    self.state.combineToken = (self.state.combineToken or 0) + 1  
    self.state.stopToken = (self.state.stopToken or 0) + 1

    self.state.lastBagCount = nil
    self.state.spendSamples = {}
    self.state.resourcefulnessProcs = 0
    self.state.craftCount = 0

    self:ResetTimer()
end

function SA:EnsureTimerLabel()
    local form = GetProfessionForm()
    if not form then
        return nil
    end

    if not self.timerLabel or not self.timerLabel:IsObjectType("FontString") then
        local fs = form:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontNormal")
        fs:SetFont(HironCraftProfit.FONT or STANDARD_TEXT_FONT, 13, "")
        fs:SetTextColor(1, 0.82, 0)
        fs:SetJustifyH("RIGHT")
        fs:SetShadowOffset(1, -1)
        self.timerLabel = fs
    end

    self.timerLabel:ClearAllPoints()
    self.timerLabel:SetPoint("BOTTOMRIGHT", form, "BOTTOMRIGHT", -100, 20)

    return self.timerLabel
end

function SA:SetETAText(text)
    local fs = self:EnsureTimerLabel()
    if not fs then return end

    if text and text ~= "" then
        fs:SetText(text)
        fs:Show()
    else
        fs:SetText("")
        fs:Hide()
    end
end

function SA:HideETA()
    if self.timerLabel then
        self.timerLabel:SetText("")
        self.timerLabel:Hide()
    end
end

local function FormatDurationShort(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))

    if seconds < 60 then
        return string.format("%d sec", seconds)
    end

    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local remainingSeconds = math.floor(seconds % 60)

    if hours > 0 then
        return string.format("%d h %d m %d s", hours, minutes, remainingSeconds)
    end

    return string.format("%d m %d s", minutes, remainingSeconds)
end

function SA:GetAverageCraftTime()
    local samples = self.state and self.state.timerSamples
    if not samples or #samples == 0 then
        return nil
    end

    local sum = 0
    for i = 1, #samples do
        sum = sum + samples[i]
    end

    return sum / #samples
end

function SA:ResetTimer()
    self.state.timerSamples = {}
    self.state.timerValue = 0
    self.state.timerCraftID = nil
    self.state.refreshCount = 0
    self.state.countdownRunning = false
    self.state.timestamp = 0
    self.state.windowTriggered = false
    self:HideETA()
end

function SA:GetSelectedSalvageItem()
    local form = GetProfessionForm()
    if not form then
        return nil
    end

    local transaction = form.GetTransaction and form:GetTransaction()
    local item = transaction and transaction.salvageItem

    if not item and form.salvageSlot then
        item = form.salvageSlot.allocationItem
    end

    if not item then
        return nil
    end

    local itemID = tonumber(ScrubSecret(item.debugItemID))
    local location = item.GetItemLocation and item:GetItemLocation()

    if not itemID and form.salvageSlot and form.salvageSlot.allocationItem then
        itemID = tonumber(ScrubSecret(form.salvageSlot.allocationItem.debugItemID))
    end

    if location and location.bagID ~= nil and location.slotIndex ~= nil then
        local bagID = ScrubSecret(location.bagID)
        local slotIndex = ScrubSecret(location.slotIndex)
        if bagID ~= nil and slotIndex ~= nil then
            local info = C_Container.GetContainerItemInfo(bagID, slotIndex)
            return {
                itemID = itemID,
                bag = bagID,
                slot = slotIndex,
                count = info and info.stackCount or 0,
            }
        end
    end

    if itemID then
        return { itemID = itemID }
    end

    return nil
end

function SA:GetFirstReagentSizeStack(itemID)
    itemID = ScrubSecret(itemID)
    if itemID == nil then
        itemID = ScrubSecret(self.state.itemID)
    end

    local selected = self:GetSelectedSalvageItem()
    if selected and selected.itemID then
        itemID = selected.itemID
        self.state.itemID = selected.itemID
    end

    if itemID == nil then
        return nil
    end

    local found = nil

    IteratePlayerBags(function(bag, slot)
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info and info.itemID == itemID then
            found = {
                stackCount = info.stackCount or 0,
                bag = bag,
                slot = slot,
            }
            return true
        end
    end)

    if found then
        return found.stackCount, found.bag, found.slot
    end

    return nil
end

function SA:GetSalvageItemDetails(restartCrafting, recipeID)
    local selected = self:GetSelectedSalvageItem()
    local itemID = ScrubSecret(self.state.itemID)

    if selected and selected.itemID then
        itemID = selected.itemID
        self.state.itemID = selected.itemID
    end

    if restartCrafting then
        local stackSize, bag, slot = self:GetFirstReagentSizeStack(itemID)
        if stackSize and bag and slot then
            return { bag, slot, stackSize }, itemID
        end
        return nil
    end

    if selected and selected.bag and selected.slot then
        if selected.bag < 0 or selected.bag > GetBagMaxIndex() then
            Chat(L["STACK_ASSIST_BAGS_ONLY"] or "Stack Assist works only with items selected in your bags.")
            return nil
        end
        return { selected.bag, selected.slot, selected.count or 0 }, itemID
    end

    local stackSize, bag, slot = self:GetFirstReagentSizeStack(itemID)
    if stackSize and bag and slot then
        return { bag, slot, stackSize }, itemID
    end

    return nil
end

function SA:GetRemainingCountBags(recipeID, itemID)
    itemID = ScrubSecret(itemID) or ScrubSecret(self.state.itemID)
    if itemID == nil then
        local selected = self:GetSelectedSalvageItem()
        if selected and selected.itemID then
            itemID = selected.itemID
            self.state.itemID = selected.itemID
        end
    end

    if itemID == nil then
        return 0, 0
    end

    local totalCount = 0
    local numSlots = 0

    IteratePlayerBags(function(bag, slot)
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info and info.itemID == itemID then
            numSlots = numSlots + 1
            totalCount = totalCount + (info.stackCount or 0)
        end
    end)

    return totalCount, numSlots
end

function SA:GetCraftableCount(recipeID)
    recipeID = ResolveRecipeID(recipeID)

    if self.state.isSalvage or self:GetSelectedSalvageItem() then
        if not recipeID then
            return 0
        end
        local count = self:GetRemainingCountBags(recipeID)
        local perCraft = self:GetEffectivePerCraft(recipeID)
        if perCraft <= 0 then
            return 0
        end
        return math.floor(count / perCraft)
    end

    if not recipeID then
        return 0
    end

    local ok, craftableCount = pcall(C_TradeSkillUI.GetCraftableCount, recipeID)
    return ok and (craftableCount or 0) or 0
end

function SA:CalculateRemainingTime()
    if #self.state.timerSamples > 9 and self.state.timerCraftID ~= nil then
        local avg = self:GetAverageCraftTime()
        if not avg then
            self:SetETAText(L["STACK_ASSIST_CALCULATING"] or "Calculating...")
            return
        end

        local seconds = math.floor((avg * self:GetCraftableCount(self.state.timerCraftID)) + 0.5)
        self.state.timerValue = seconds
        self:SetETAText(string.format("%s %s", L["STACK_ASSIST_ETA"] or "Осталось:", FormatDurationShort(seconds)))
    else
        self:SetETAText(L["STACK_ASSIST_CALCULATING"] or "Calculating...")
    end
end

function SA:SnapshotBagCount()
    local itemID = ScrubSecret(self.state.itemID)
    if not itemID then return end

    local total = 0
    IteratePlayerBags(function(bag, slot)
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info and info.itemID == itemID then
            total = total + (info.stackCount or 0)
        end
    end)
    self.state.lastBagCount = total
end

function SA:RecordActualSpend(recipeID)
    local itemID = ScrubSecret(self.state.itemID)
    if not itemID or not self.state.lastBagCount then return end

    local base = GetRecipeReagentCount(recipeID)

    local total = 0
    IteratePlayerBags(function(bag, slot)
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info and info.itemID == itemID then
            total = total + (info.stackCount or 0)
        end
    end)

    local spent = self.state.lastBagCount - total
    self.state.lastBagCount = total
    self.state.craftCount = (self.state.craftCount or 0) + 1

    if spent >= 0 and spent <= base then
        if spent == 0 then
            self.state.resourcefulnessProcs = (self.state.resourcefulnessProcs or 0) + 1
        end

        table.insert(self.state.spendSamples, spent)
        if #self.state.spendSamples > MAX_SPEND_SAMPLES then
            table.remove(self.state.spendSamples, 1)
        end
    end
end

function SA:RecordCraftBegin(recipeID)
    recipeID = ResolveRecipeID(recipeID)
    if not recipeID then
        return
    end

    self:SnapshotBagCount()

    if C_TradeSkillUI.IsRecipeRepeating() then
        if self.state.timestamp > 0 then
            table.insert(self.state.timerSamples, (GetTime() - self.state.timestamp))
            if #self.state.timerSamples > MAX_ETA_SAMPLES then
                table.remove(self.state.timerSamples, 1)
            end
            if #self.state.timerSamples >= 10 then
                self:CalculateRemainingTime()
            end
        end

        self.state.timestamp = GetTime()
    else
        self.state.timerSamples = {}
        self.state.timestamp = 0
    end
end

function SA:RefreshCrafting(recipeID, maxStackSize, bag, slot)
    recipeID = ResolveRecipeID(recipeID)
    if not self.state.active or not recipeID then
        return
    end

    if not C_TradeSkillUI.IsRecipeRepeating() then
        return
    end

    local form = GetProfessionForm()
    local formRecipeInfo = form and form.GetRecipeInfo and form:GetRecipeInfo()
    local formRecipeID = formRecipeInfo and ScrubSecret(formRecipeInfo.recipeID)

    if form
        and formRecipeID == recipeID
        and form:GetTransaction()
        and form:GetTransaction().salvageItem
    then
        ProfessionsFrame.CraftingPage:CreateInternal(
            recipeID,
            ProfessionsFrame.CraftingPage:GetCraftableCount(),
            form:GetCurrentRecipeLevel()
        )
    elseif bag ~= nil and slot ~= nil then
        maxStackSize = maxStackSize or 1000
        C_TradeSkillUI.CraftSalvage(recipeID, maxStackSize, ItemLocation:CreateFromBagAndSlot(bag, slot))
    end
end

function SA:CombineStacks(scrapSlot, itemID, forced, restartCrafting, recipeID, specialMsg)
    if not self.state.active then
        return
    end

    if self.state.combining and not forced then
        return
    end

    self.state.combining = true
    restartCrafting = restartCrafting == true
    recipeID = ResolveRecipeID(recipeID)

    local combineToken = (self.state.combineToken or 0) + 1
    self.state.combineToken = combineToken

    local lowestStack
    local maxStackSize = 0
    local maxStackToBegin = 150
    local itemInfo

    if not scrapSlot and (C_TradeSkillUI.IsRecipeRepeating() or restartCrafting) then
        local resolvedSlot, resolvedItemID = self:GetSalvageItemDetails(restartCrafting, recipeID)
        scrapSlot = resolvedSlot
        itemID = resolvedItemID
    end

    itemID = ScrubSecret(itemID)

    if not scrapSlot or itemID == nil then
        self.state.combining = false
        return
    end

    self.state.recipeID = recipeID or self.state.recipeID
    self.state.itemID = itemID
    self.state.isSalvage = true

    if forced then
        local detail = C_Container.GetContainerItemInfo(scrapSlot[1], scrapSlot[2])
        if detail and detail.itemID == itemID then
            scrapSlot[3] = detail.stackCount or 0
        end
    end

    local defaultStackMin = math.ceil(self:GetEffectivePerCraft(recipeID))

    for bag = 0, GetBagMaxIndex() do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            if scrapSlot[1] ~= bag or scrapSlot[2] ~= slot then
                itemInfo = C_Container.GetContainerItemInfo(bag, slot)

                if itemInfo and itemInfo.itemID == itemID then
                    maxStackSize = C_Item.GetItemMaxStackSizeByID(itemID) or 1000
                    local maxStackToBeginLocal = maxStackToBegin
                    if maxStackSize == 200 then
                        maxStackToBeginLocal = SMALL_STACK_TRIGGER
                    end

                    if lowestStack and lowestStack[3] > (itemInfo.stackCount or 0) then
                        lowestStack = { bag, slot, itemInfo.stackCount or 0 }
                    elseif not lowestStack then
                        lowestStack = { bag, slot, itemInfo.stackCount or 0 }
                    end

                    maxStackToBegin = maxStackToBeginLocal
                end
            end
        end
    end

    if lowestStack then
        C_Container.PickupContainerItem(lowestStack[1], lowestStack[2])
        C_Container.PickupContainerItem(scrapSlot[1], scrapSlot[2])

        if CursorHasItem and CursorHasItem() then
            ClearCursor()
        end

        if C_TradeSkillUI.IsRecipeRepeating() then
            self:RefreshCrafting(recipeID, maxStackSize, scrapSlot[1], scrapSlot[2])
        end

        if ((scrapSlot[3] + lowestStack[3]) < maxStackSize) or (scrapSlot[3] < maxStackToBegin and lowestStack[3] ~= 0) then
            C_Timer.After(BAG_MOVE_DELAY, function()
                if not SA:IsEnabled() or not SA.state.active or combineToken ~= SA.state.combineToken then
                    SA.state.combining = false
                    return
                end
                SA:CombineStacks(scrapSlot, itemID, true, restartCrafting, recipeID, specialMsg)
            end)
            return
        end
    elseif C_TradeSkillUI.IsRecipeRepeating() then
        self:RefreshCrafting(recipeID, C_Item.GetItemMaxStackSizeByID(itemID) or 1000, scrapSlot[1], scrapSlot[2])
    end

    self.state.combining = false

    if specialMsg then
        Chat(L["STACK_ASSIST_RESTART"] or "Stacking has finished. Please restart.")
    end

    if restartCrafting and not C_TradeSkillUI.IsRecipeRepeating() and not self.state.restartNoticeShown then
        self.state.restartNoticeShown = true
        Chat(L["STACK_ASSIST_RESTART"] or "Crafting has ended prematurely. Please restart and crafting will continue nonstop.")
        C_Timer.After(1, function()
            SA.state.restartNoticeShown = false
        end)
    end
end

function SA:IsMoreToCraft(recipeID)
    recipeID = ResolveRecipeID(recipeID)

    local perCraft = math.ceil(self:GetEffectivePerCraft(recipeID))
    local totalCount, numSlots = self:GetRemainingCountBags(recipeID)
    local moreToCraft = totalCount >= perCraft
    local needsToStack = false

    if moreToCraft and numSlots > 1 then
        local firstStack = self:GetFirstReagentSizeStack(nil)
        if firstStack and firstStack < perCraft then
            needsToStack = true
        end
    end

    return needsToStack, moreToCraft
end

function SA:CraftListener(recipeID)
    if not self.state.active then
        return
    end

    recipeID = ResolveRecipeID(recipeID)
    if not recipeID then
        return
    end

    if not C_TradeSkillUI.IsRecipeRepeating() or self.state.combining then
        return
    end

    local remainingCasts = self:GetCraftableCount(recipeID)
    local minStackToBegin = DEFAULT_MIN_STACK_TO_BEGIN
    local minRemainingCasts = DEFAULT_MIN_REMAINING_CASTS

    if self.state.itemID ~= nil then
        local maxStackSize = C_Item.GetItemMaxStackSizeByID(self.state.itemID)
        if maxStackSize and maxStackSize == 200 then
            minStackToBegin = SMALL_STACK_TRIGGER
            minRemainingCasts = SMALL_STACK_REMAINING
        end
    end

    if remainingCasts and remainingCasts < minRemainingCasts then
        self:CombineStacks(nil, nil, nil, nil, recipeID)
        return
    end

    local firstStack, bag, slot = self:GetFirstReagentSizeStack(nil)
    if firstStack then
        if firstStack < minStackToBegin then
            self:CombineStacks(nil, nil, nil, nil, recipeID)
        elseif (not ProfessionsFrame or not GetProfessionForm()) and C_TradeSkillUI.IsRecipeRepeating() then
            local defaultStackMin = math.ceil(self:GetEffectivePerCraft(recipeID))
            local stackNumRounded = math.floor((firstStack + (defaultStackMin / 2)) / defaultStackMin) * defaultStackMin
            local modVal = 100

            if self.state.itemID ~= nil then
                local maxStackSize = C_Item.GetItemMaxStackSizeByID(self.state.itemID)
                if maxStackSize and maxStackSize < 1000 then
                    if (defaultStackMin * 20) >= (maxStackSize / 2) then
                        modVal = math.floor(maxStackSize / 4)
                    else
                        modVal = math.floor(defaultStackMin * 20)
                    end
                end
            end

            if modVal > 0 and (stackNumRounded % modVal == 0) then
                self:RefreshCrafting(recipeID, nil, bag, slot)
            end
        end
    end
end

function SA:InitializeCountdown(isRepeating)
    if self.state.countdownRunning and not isRepeating then
        return
    end

    if not self.state.active then
        self:StopSession()
        return
    end

    self.state.countdownRunning = true

    if #self.state.timerSamples < 10 then
        self:SetETAText(L["STACK_ASSIST_CALCULATING"] or "Calculating...")
    elseif self.state.timerValue == 0 then
        self:CalculateRemainingTime()
    else
        local countRemaining = self:GetCraftableCount(self.state.timerCraftID)
        self.state.refreshCount = (self.state.refreshCount or 0) + 1

        if self.state.refreshCount == 300 or (countRemaining < 100 and countRemaining % 20 == 0) then
            self:CalculateRemainingTime()
            self.state.refreshCount = 0
        else
            self:SetETAText(string.format("%s %s", L["STACK_ASSIST_ETA"] or "Осталось:", FormatDurationShort(self.state.timerValue)))
            self.state.timerValue = math.max(0, self.state.timerValue - 1)
        end
    end

    C_Timer.After(1, function()
        if not SA:IsEnabled() then
            SA:StopSession()
            return
        end

        if not SA.state.active then
            SA:StopSession()
            return
        end

        if C_TradeSkillUI.IsRecipeRepeating() then
            SA:InitializeCountdown(true)
        else
            SA:StopSession()
        end
    end)
end

function SA:ApplyEnabledState()
    self.state.token = (self.state.token or 0) + 1
    self.state.combining = false

    if not self:IsEnabled() then
        self:StopSession()
    end
end

SA.eventFrame = SA.eventFrame or CreateFrame("Frame")
SA.eventFrame:RegisterEvent("TRADE_SKILL_CRAFT_BEGIN")
SA.eventFrame:RegisterEvent("TRADE_SKILL_ITEM_CRAFTED_RESULT")
SA.eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
SA.eventFrame:RegisterEvent("UPDATE_TRADESKILL_CAST_STOPPED")

SA.eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
    if not SA:IsEnabled() then
        SA:StopSession()
        return
    end

    if event == "TRADE_SKILL_CRAFT_BEGIN" then
        local selected = SA:GetSelectedSalvageItem()
        if selected then
            local recipeID = ResolveRecipeID(arg1)
            local itemID = selected.itemID or nil

            SA:StartSession(recipeID, itemID, true)
            SA:RecordCraftBegin(recipeID)

            SA.state.timerCraftID = recipeID
            if not SA.state.countdownRunning then
                SA:InitializeCountdown()
            end

            SA:CraftListener(recipeID)
        end

    elseif event == "TRADE_SKILL_ITEM_CRAFTED_RESULT" then
        local recipeID = ResolveRecipeID(SA.state.recipeID)
        if SA.state.active and SA.state.isSalvage then
            SA:RecordActualSpend(recipeID)
            SA:CraftListener(recipeID)
        end

    elseif event == "UNIT_SPELLCAST_FAILED" then
        local unitTarget = ScrubSecret(arg1)
        if unitTarget ~= "player" then
            return
        end

        if SA.state.active and SA.state.isSalvage and not SA.state.combining then
            local failedID = ResolveRecipeID(SA.state.recipeID) or ResolveRecipeID(arg3)
            local needsToStack, moreToCraft = SA:IsMoreToCraft(failedID)

            if needsToStack then
                SA:CombineStacks(nil, nil, nil, true, failedID)
            elseif moreToCraft and not SA.state.restartNoticeShown then
                SA.state.restartNoticeShown = true
                Chat(L["STACK_ASSIST_RESTART"] or "Crafting ended early. Restart it and it should continue.")
                C_Timer.After(1, function()
                    SA.state.restartNoticeShown = false
                end)
            else
                SA:StopSession()
            end
        end

    elseif event == "UPDATE_TRADESKILL_CAST_STOPPED" then
        SA.state.restartNoticeShown = false

        local stopToken = (SA.state.stopToken or 0) + 1
        SA.state.stopToken = stopToken

        C_Timer.After(0.3, function()
            if not SA:IsEnabled() then
                SA:StopSession()
                return
            end

            if stopToken ~= SA.state.stopToken then
                return
            end

            if not C_TradeSkillUI.IsRecipeRepeating() then
                SA:StopSession()
            end
        end)
    end
end)
