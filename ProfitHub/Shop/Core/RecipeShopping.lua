local PT = HironCraftProfit
if not PT then return end

PT.RecipeShopping = PT.RecipeShopping or {}
local RS = PT.RecipeShopping

local SOURCE_KIND = "profession_recipes"
local MAX_CRAFT_COUNT = 9999
local Unpack = unpack or table.unpack

RS.plan = RS.plan or {
    materials = {},
    recipes = {},
    totalCrafts = 0,
}

local function T(key, fallback)
    local value = PT.L and PT.L[key]
    if value and value ~= "" then return value end
    return fallback or key
end

local function SafeCall(method, owner, ...)
    if type(method) ~= "function" then return nil end
    local ok, value = pcall(method, owner, ...)
    if ok then return value end
    return nil
end

local function GetReagentItemID(reagent)
    if type(reagent) == "number" then return reagent end
    if type(reagent) ~= "table" then return nil end

    local itemID = tonumber(reagent.itemID or reagent.debugItemID)
    if itemID then return itemID end

    itemID = tonumber(SafeCall(reagent.GetItemID, reagent))
    if itemID then return itemID end

    local item = reagent.item or reagent.reagent
    if item and item ~= reagent then
        return GetReagentItemID(item)
    end
    return nil
end

local function GetItemCountForShopping(itemID)
    itemID = tonumber(itemID)
    if not itemID then return 0 end

    local function Try(fn)
        if type(fn) ~= "function" then return nil end
        local attempts = {
            { itemID, true, false, true, true },
            { itemID, true, false, true },
            { itemID, true },
            { itemID },
        }
        for _, args in ipairs(attempts) do
            local ok, count = pcall(fn, Unpack(args))
            count = ok and tonumber(count) or nil
            if count then return math.max(0, count) end
        end
        return nil
    end

    return Try(C_Item and C_Item.GetItemCount) or Try(GetItemCount) or 0
end

local function GetItemMetadata(itemID, candidateCount)
    local label, expansionID
    if type(GetItemInfo) == "function" then
        label = GetItemInfo(itemID)
        expansionID = select(15, GetItemInfo(itemID))
    end

    local qualityTier
    if C_TradeSkillUI and type(C_TradeSkillUI.GetItemReagentQualityByItemInfo) == "function" then
        local ok, value = pcall(C_TradeSkillUI.GetItemReagentQualityByItemInfo, itemID)
        qualityTier = ok and tonumber(value) or nil
    end

    return {
        label = label,
        qualityTier = qualityTier,
        maxTier = candidateCount and candidateCount > 1 and candidateCount or nil,
        expansionID = tonumber(expansionID),
    }
end

local function AddMaterial(target, itemID, quantity, candidateCount)
    itemID = tonumber(itemID)
    quantity = tonumber(quantity) or 0
    if not itemID or quantity <= 0 then return false end

    local row = target[itemID]
    if not row then
        local meta = GetItemMetadata(itemID, candidateCount)
        row = {
            itemID = itemID,
            quantity = 0,
            label = meta.label,
            maxTier = meta.maxTier,
            expansionID = meta.expansionID,
        }
        if meta.qualityTier then
            row.tier = meta.qualityTier
            row.chosenTier = meta.qualityTier
            row.materialQuality = meta.qualityTier
            row.professionQuality = meta.qualityTier
        end
        target[itemID] = row
    end

    row.quantity = row.quantity + quantity
    return true
end

local function AddAllocation(parts, allocation)
    if type(allocation) ~= "table" then return end
    local reagent = SafeCall(allocation.GetReagent, allocation) or allocation.reagent or allocation.item
    local itemID = GetReagentItemID(reagent)
    local quantity = tonumber(SafeCall(allocation.GetQuantity, allocation) or allocation.quantity)
    if itemID and quantity and quantity > 0 then
        parts[#parts + 1] = { itemID = itemID, quantity = quantity }
    end
end

local function GetAllocatedParts(transaction, slotIndex, dataSlotIndex)
    local parts = {}
    if not transaction then return parts end

    local allocations = SafeCall(transaction.GetAllocations, transaction, slotIndex)
    if not allocations and type(transaction.allocationTbls) == "table" then
        allocations = transaction.allocationTbls[slotIndex]
            or (dataSlotIndex and transaction.allocationTbls[dataSlotIndex])
    end
    if not allocations then return parts end

    if type(allocations.Enumerate) == "function" then
        local ok = pcall(function()
            for _, allocation in allocations:Enumerate() do
                AddAllocation(parts, allocation)
            end
        end)
        if ok then return parts end
        wipe(parts)
    end

    local list = allocations.allocs or allocations
    if type(list) == "table" then
        for _, allocation in pairs(list) do
            AddAllocation(parts, allocation)
        end
    end
    return parts
end

local function IsRequiredSlot(transaction, slot, slotIndex)
    if transaction and type(transaction.IsSlotRequired) == "function" then
        local ok, required = pcall(transaction.IsSlotRequired, transaction, slotIndex)
        if ok then return required == true end
    end

    local basicType = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic
    if basicType ~= nil and slot.reagentType ~= nil then
        return slot.reagentType == basicType
    end
    if slot.isRequired ~= nil then return slot.isRequired == true end
    return (tonumber(slot.quantityRequired or slot.requiredQuantity) or 0) > 0
end

local function GetPreferredCandidate(slot, parts, form)
    if #parts > 0 then return parts[#parts].itemID end

    local candidates = slot.reagents or {}
    local useBest = form and form.AllocateBestQualityCheckbox
        and SafeCall(form.AllocateBestQualityCheckbox.GetChecked, form.AllocateBestQualityCheckbox) == true
    local candidate = useBest and candidates[#candidates] or candidates[1]
    return GetReagentItemID(candidate)
end

function RS:CollectRecipeMaterials(recipeID, craftCount, transaction, form)
    recipeID = tonumber(recipeID)
    craftCount = math.floor(tonumber(craftCount) or 0)
    if not recipeID or craftCount <= 0 then return nil, "bad_quantity" end

    local schematic
    if transaction and type(transaction.GetRecipeSchematic) == "function" then
        schematic = SafeCall(transaction.GetRecipeSchematic, transaction)
    end
    if not schematic and C_TradeSkillUI and type(C_TradeSkillUI.GetRecipeSchematic) == "function" then
        local ok, value = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
        schematic = ok and value or nil
    end
    if not schematic then return nil, "no_schematic" end

    local salvageType = Enum and Enum.TradeskillRecipeType and Enum.TradeskillRecipeType.Salvage or 2
    if schematic.recipeType == salvageType then return nil, "unsupported_recipe" end

    local materials = {}
    local unresolved = 0
    local slots = schematic.reagentSlotSchematics or {}

    for schematicIndex, slot in ipairs(slots) do
        local slotIndex = slot.slotIndex or slot.dataSlotIndex or schematicIndex
        local dataSlotIndex = slot.dataSlotIndex
        local required = IsRequiredSlot(transaction, slot, slotIndex)
        local requiredQuantity = tonumber(slot.quantityRequired or slot.requiredQuantity) or 0
        local candidates = slot.reagents or {}
        local parts = GetAllocatedParts(transaction, slotIndex, dataSlotIndex)

        if required and requiredQuantity > 0 then
            local remaining = requiredQuantity
            for _, part in ipairs(parts) do
                if remaining <= 0 then break end
                local used = math.min(remaining, part.quantity)
                AddMaterial(materials, part.itemID, used * craftCount, #candidates)
                remaining = remaining - used
            end

            if remaining > 0 then
                local itemID = GetPreferredCandidate(slot, parts, form)
                if itemID then
                    AddMaterial(materials, itemID, remaining * craftCount, #candidates)
                else
                    unresolved = unresolved + 1
                end
            end
        elseif #parts > 0 then
            -- Optional and finishing reagents enter the plan only when the
            -- player explicitly selected them in the current transaction.
            for _, part in ipairs(parts) do
                AddMaterial(materials, part.itemID, part.quantity * craftCount, #candidates)
            end
        end
    end

    if unresolved > 0 then return nil, "unresolved_reagent" end
    if not next(materials) then return nil, "no_reagents" end
    return materials
end

function RS:BuildMissingMaterials()
    local materials = {}
    for itemID, planned in pairs(self.plan.materials or {}) do
        local missing = math.max(0, math.floor((tonumber(planned.quantity) or 0) - GetItemCountForShopping(itemID)))
        if missing > 0 then
            local row = {}
            for key, value in pairs(planned) do row[key] = value end
            row.quantity = missing
            materials[#materials + 1] = row
        end
    end

    table.sort(materials, function(a, b)
        local an = tostring(a.label or a.itemID or "")
        local bn = tostring(b.label or b.itemID or "")
        if an == bn then return (a.itemID or 0) < (b.itemID or 0) end
        return an < bn
    end)
    return materials
end

function RS:RefreshShoppingList()
    local shop = PT.ShoppingList
    if not shop or type(shop.CreateTemporaryImportedList) ~= "function" then
        return false, "shopping_unavailable"
    end

    local materials = self:BuildMissingMaterials()
    local allowEmpty = true
    local ok, reason = shop:CreateTemporaryImportedList(
        T("PG_RECIPE_SHOP_LIST_NAME", "Profession recipes"),
        materials,
        SOURCE_KIND,
        allowEmpty)
    return ok, reason, #materials
end

function RS:AddRecipe(recipeID, craftCount, transaction, form)
    craftCount = math.max(1, math.min(MAX_CRAFT_COUNT, math.floor(tonumber(craftCount) or 1)))
    local materials, reason = self:CollectRecipeMaterials(recipeID, craftCount, transaction, form)
    if not materials then return false, reason end

    self.plan.materials = self.plan.materials or {}
    self.plan.recipes = self.plan.recipes or {}
    for itemID, material in pairs(materials) do
        local existing = self.plan.materials[itemID]
        if not existing then
            existing = {}
            for key, value in pairs(material) do existing[key] = value end
            existing.quantity = 0
            self.plan.materials[itemID] = existing
        end
        existing.quantity = (tonumber(existing.quantity) or 0) + (tonumber(material.quantity) or 0)
    end

    recipeID = tonumber(recipeID)
    self.plan.recipes[recipeID] = (tonumber(self.plan.recipes[recipeID]) or 0) + craftCount
    self.plan.totalCrafts = (tonumber(self.plan.totalCrafts) or 0) + craftCount

    local refreshed, refreshReason, missingTypes = self:RefreshShoppingList()
    if not refreshed then return false, refreshReason end
    return true, missingTypes or 0
end

function RS:ClearPlan(refresh)
    self.plan = { materials = {}, recipes = {}, totalCrafts = 0 }
    if refresh ~= false then
        return self:RefreshShoppingList()
    end
    return true
end

local function Notify(message, isError)
    local color = isError and RED_FONT_COLOR or GREEN_FONT_COLOR
    if UIErrorsFrame and type(UIErrorsFrame.AddMessage) == "function" then
        local r, g, b = 1, 1, 1
        if color and type(color.GetRGB) == "function" then r, g, b = color:GetRGB() end
        UIErrorsFrame:AddMessage(message, r, g, b)
    elseif DEFAULT_CHAT_FRAME and type(DEFAULT_CHAT_FRAME.AddMessage) == "function" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd200HironCraft:|r " .. message)
    end
end

local function GetCraftingPage()
    return ProfessionsFrame and ProfessionsFrame.CraftingPage
end

local function NormalizeQuantity(editBox)
    local quantity = math.floor(tonumber(editBox and editBox:GetNumber()) or 1)
    quantity = math.max(1, math.min(MAX_CRAFT_COUNT, quantity))
    if editBox then
        editBox:SetNumber(quantity)
        editBox:SetCursorPosition(0)
    end
    return quantity
end

function RS:GetSelectedRecipe()
    local page = GetCraftingPage()
    local form = page and page.SchematicForm
    local recipeInfo = form and form.GetRecipeInfo and form:GetRecipeInfo()
    if not recipeInfo or not recipeInfo.recipeID then return nil end
    return recipeInfo, form, form.GetTransaction and form:GetTransaction()
end

function RS:AddSelectedRecipe()
    local recipeInfo, form, transaction = self:GetSelectedRecipe()
    if not recipeInfo or not recipeInfo.learned then
        return false, "unlearned"
    end

    local quantity = NormalizeQuantity(self.controls and self.controls.quantity)
    local ok, value = self:AddRecipe(recipeInfo.recipeID, quantity, transaction, form)
    if ok then
        Notify(string.format(T("PG_RECIPE_SHOP_ADDED", "Added %d craft(s) to the shopping list."), quantity))
    else
        Notify(T("PG_RECIPE_SHOP_ERROR_" .. string.upper(tostring(value or "unknown")),
            "Could not add the recipe reagents."), true)
    end
    return ok, value
end

function RS:UpdateTooltip(owner)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(T("PG_RECIPE_SHOP_BUTTON", "Add to shopping"), 1, 0.82, 0)
    GameTooltip:AddLine(T("PG_RECIPE_SHOP_TOOLTIP", "Adds the missing reagents for this recipe and quantity to one accumulating shopping list."), 1, 1, 1, true)
    GameTooltip:AddLine(string.format(T("PG_RECIPE_SHOP_TOTAL", "Planned crafts: %d"), tonumber(self.plan.totalCrafts) or 0), 0.65, 0.85, 1)
    GameTooltip:AddLine(T("PG_RECIPE_SHOP_CLEAR_HINT", "Right click: clear this recipe shopping list."), 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
end

function RS:EnsureControls()
    if self.controls then return self.controls end
    local page = GetCraftingPage()
    local form = page and page.SchematicForm
    if not page or not form or type(CreateFrame) ~= "function" then return nil end

    local controls = CreateFrame("Frame", "HironCraftRecipeShoppingControls", page)
    controls:SetSize(142, 22)
    controls:SetPoint("TOPLEFT", form, "BOTTOMLEFT", 144, -4)
    controls:SetFrameLevel((page:GetFrameLevel() or 0) + 20)

    local quantity = CreateFrame("EditBox", nil, controls, "InputBoxTemplate")
    quantity:SetSize(32, 20)
    quantity:SetPoint("LEFT", controls, "LEFT", 0, 0)
    quantity:SetAutoFocus(false)
    quantity:SetNumeric(true)
    quantity:SetMaxLetters(4)
    quantity:SetNumber(1)
    quantity:SetJustifyH("CENTER")
    quantity:SetScript("OnEnterPressed", function(self)
        NormalizeQuantity(self)
        self:ClearFocus()
    end)
    quantity:SetScript("OnEscapePressed", function(self)
        self:SetNumber(1)
        self:ClearFocus()
    end)
    quantity:SetScript("OnEditFocusLost", function(self) NormalizeQuantity(self) end)

    local button = CreateFrame("Button", nil, controls, "UIPanelButtonTemplate")
    button:SetSize(106, 22)
    button:SetPoint("LEFT", quantity, "RIGHT", 4, 0)
    button:SetText(T("PG_RECIPE_SHOP_BUTTON", "Add to shopping"))
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            RS:ClearPlan()
            Notify(T("PG_RECIPE_SHOP_CLEARED", "Recipe shopping list cleared."))
        else
            RS:AddSelectedRecipe()
        end
    end)
    button:SetScript("OnEnter", function(self) RS:UpdateTooltip(self) end)
    button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    controls.quantity = quantity
    controls.button = button
    self.controls = controls
    return controls
end

function RS:UpdatePosition(offset)
    local controls = self:EnsureControls()
    local page = GetCraftingPage()
    local form = page and page.SchematicForm
    if not controls or not form then return end
    controls:ClearAllPoints()
    controls:SetPoint("TOPLEFT", form, "BOTTOMLEFT", 144, -4 + (tonumber(offset) or 0))
end

function RS:AttachScannerLabel(label)
    local controls = self:EnsureControls()
    if not controls or not label then return end
    label:ClearAllPoints()
    label:SetPoint("LEFT", controls, "RIGHT", 4, 0)
    label:SetWidth(96)
end

function RS:OnRecipeSelected()
    local controls = self:EnsureControls()
    if not controls then return end

    local recipeInfo, form, transaction = self:GetSelectedRecipe()
    if not recipeInfo or not form or (form.IsShown and not form:IsShown()) then
        controls:Hide()
        return
    end

    local schematic
    if transaction and type(transaction.GetRecipeSchematic) == "function" then
        schematic = SafeCall(transaction.GetRecipeSchematic, transaction)
    end
    if not schematic and C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic then
        local ok, value = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeInfo.recipeID, false)
        schematic = ok and value or nil
    end

    local salvageType = Enum and Enum.TradeskillRecipeType and Enum.TradeskillRecipeType.Salvage or 2
    local supported = schematic and schematic.recipeType ~= salvageType
        and schematic.reagentSlotSchematics and #schematic.reagentSlotSchematics > 0
        and not recipeInfo.isRecraft and not recipeInfo.isDummyRecipe and not recipeInfo.isGatheringRecipe

    controls:SetShown(supported == true)
    if not supported then return end

    controls.button:SetEnabled(recipeInfo.learned == true)
    if controls.recipeID ~= recipeInfo.recipeID then
        controls.recipeID = recipeInfo.recipeID
        controls.quantity:SetNumber(1)
        controls.quantity:SetCursorPosition(0)
    end
end

RS.SOURCE_KIND = SOURCE_KIND
RS.GetItemCountForShopping = GetItemCountForShopping
