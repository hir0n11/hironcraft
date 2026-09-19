local PT = HironCraftProfit
if not PT then return end

PT.RecipeShopping = PT.RecipeShopping or {}
local RS = PT.RecipeShopping

local SOURCE_KIND = "profession_recipes"
local MAX_CRAFT_COUNT = 9999
local Unpack = unpack or table.unpack

RS.plan = RS.plan or {
    entries = {},
    materials = {},
    recipes = {},
    recipeItems = {},
    totalCrafts = 0,
}

local function T(key, fallback)
    local value = PT.L and PT.L[key]
    if value and value ~= "" then return value end
    return fallback or key
end

function RS:GetSettings()
    self:EnsurePlanLoaded()
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB.recipeShopping = HironCraftProfit_DB.recipeShopping or {}
    local settings = HironCraftProfit_DB.recipeShopping
    settings.quality = tonumber(settings.quality) == 2 and 2 or 1
    settings.useInventory = true
    return settings
end

function RS:GetQualityLabel(quality)
    quality = tonumber(quality) or 0
    return quality == 0 and T("PG_RECIPE_PLAN_AS_SELECTED", "As in recipe") or ("T" .. quality)
end

function RS:SetQuality(quality)
    self:GetSettings().quality = tonumber(quality) == 2 and 2 or 1
    self:UpdatePlanDisplay()
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
        if qualityTier and qualityTier <= 0 then qualityTier = nil end
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

-- Sparks, crests and other bound reagents cannot be bought on the AH. Do not
-- confuse several interchangeable sparks with the quality tiers of a material.
local function IsPurchasableReagent(itemID)
    local info = C_Item and C_Item.GetItemInfo or GetItemInfo
    if type(info) ~= "function" then return nil end
    local ok, name, _, _, _, _, _, _, _, _, _, _, _, _, bindType = pcall(info, itemID)
    if not ok or not name then
        if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
        return nil
    end
    return bindType == nil or bindType == 0 or bindType == 2 or bindType == 3
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

local function GetExactQualityCandidate(slot, quality)
    local candidates = slot.reagents or {}
    -- Bound alternatives were excluded by the caller. Multiple buyable
    -- candidates with no loaded quality data must not silently pick T2/T3.
    local tiered = #candidates > 1
    for _, candidate in ipairs(candidates) do
        local itemID = GetReagentItemID(candidate)
        local tier = itemID and GetItemMetadata(itemID).qualityTier
        if tier then tiered = true end
        if tier == quality then return itemID, true end
    end
    -- A reagent without quality (e.g. thread) keeps its normal selection.
    -- Never silently substitute T2/T3 when the requested tier is unavailable.
    return nil, tiered
end

function RS:CollectRecipeMaterials(recipeID, craftCount, transaction, form, quality)
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
    quality = tonumber(quality) or 0

    for schematicIndex, slot in ipairs(slots) do
        local slotIndex = slot.slotIndex or slot.dataSlotIndex or schematicIndex
        local dataSlotIndex = slot.dataSlotIndex
        local required = IsRequiredSlot(transaction, slot, slotIndex)
        local requiredQuantity = tonumber(slot.quantityRequired or slot.requiredQuantity) or 0
        local candidates = slot.reagents or {}
        local parts = GetAllocatedParts(transaction, slotIndex, dataSlotIndex)

        if required and requiredQuantity > 0 and #candidates == 0 then
            return nil, "unresolved_reagent"
        end

        local purchasable, unknown = false, false
        for _, candidate in ipairs(candidates) do
            local id = GetReagentItemID(candidate)
            local allowed = id and IsPurchasableReagent(id)
            if not id and type(candidate) == "table" and candidate.currencyID then allowed = false end
            if allowed then purchasable = true elseif allowed == nil then unknown = true end
        end
        -- An unallocated optional slot does not need item data at all.
        local needed = (required and requiredQuantity > 0) or #parts > 0
        if needed and unknown then return nil, "unresolved_reagent" end
        if purchasable and required and requiredQuantity > 0 then
            if quality > 0 then
                local itemID, tiered = GetExactQualityCandidate(slot, quality)
                if tiered then
                    if not itemID then return nil, "quality_unavailable" end
                    parts = { { itemID = itemID, quantity = requiredQuantity } }
                end
            end
            local remaining = requiredQuantity
            for _, part in ipairs(parts) do
                if remaining <= 0 then break end
                local used = math.min(remaining, part.quantity)
                if IsPurchasableReagent(part.itemID) then
                    AddMaterial(materials, part.itemID, used * craftCount, #candidates)
                end
                remaining = remaining - used
            end

            if remaining > 0 then
                local itemID = GetPreferredCandidate(slot, parts, form)
                if itemID and IsPurchasableReagent(itemID) then
                    AddMaterial(materials, itemID, remaining * craftCount, #candidates)
                else
                    unresolved = unresolved + 1
                end
            end
        elseif purchasable and #parts > 0 then
            -- Optional and finishing reagents enter the plan only when the
            -- player explicitly selected them in the current transaction.
            for _, part in ipairs(parts) do
                if IsPurchasableReagent(part.itemID) then
                    AddMaterial(materials, part.itemID, part.quantity * craftCount, #candidates)
                end
            end
        end
    end

    if unresolved > 0 then return nil, "unresolved_reagent" end
    if not next(materials) then return nil, "no_reagents" end
    return materials
end

function RS:BuildMissingMaterials()
    local materials = {}
    self:GetSettings()
    for itemID, planned in pairs(self.plan.materials or {}) do
        -- Each quality has its own itemID. Reserve its stock once across the
        -- entire plan, never by item name or by summing other quality tiers.
        local owned = GetItemCountForShopping(itemID)
        local missing = math.max(0, math.floor((tonumber(planned.quantity) or 0) - owned))
        if missing > 0 then
            local row = {}
            for key, value in pairs(planned) do row[key] = value end
            row.quantity = missing
            materials[#materials + 1] = row
        end
    end

    for _, planned in pairs(self.plan.recipeItems or {}) do
        local row = {}
        for key, value in pairs(planned) do row[key] = value end

        if row.itemID then
            row.quantity = math.max(0,
                math.floor((tonumber(row.quantity) or 1) - GetItemCountForShopping(row.itemID)))
        else
            row.quantity = math.max(1, math.floor(tonumber(row.quantity) or 1))
        end

        if row.quantity > 0 then
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

function RS:ClampShoppingRowToStock(row)
    local shop = PT.ShoppingList
    if not row or not shop or not shop.session or shop.session.sourceKind ~= SOURCE_KIND then return false end
    self:EnsurePlanLoaded()
    local itemID = tonumber(row.chosenItemID or row.itemID)
    local material = itemID and self.plan.materials[itemID]
    if not material then return false end
    local missing = math.max(0, math.floor(material.quantity - GetItemCountForShopping(itemID)))
    if IsPurchasableReagent(itemID) == false then missing = 0 end
    local remaining = tonumber(row.remainingQuantity) or tonumber(row.quantity) or 0
    -- Never increase a live shopping row: bought reagents may still be in mail.
    if missing >= remaining then return false end
    row.quantity, row.remainingQuantity = missing, missing
    return true
end

local function CopyTable(source)
    local copy = {}
    for key, value in pairs(source or {}) do copy[key] = value end
    return copy
end

local function CopyPlan(plan)
    local copy = { entries = {}, recipeItems = CopyTable(plan.recipeItems) }
    for _, entry in ipairs(plan.entries or {}) do
        -- Per-craft reagent snapshots are immutable; only counts are edited.
        copy.entries[#copy.entries + 1] = CopyTable(entry)
    end
    return copy
end

local function RebuildPlan(plan)
    plan.materials, plan.recipes, plan.totalCrafts = {}, {}, 0
    for _, entry in ipairs(plan.entries or {}) do
        plan.recipes[entry.recipeID] = (plan.recipes[entry.recipeID] or 0) + entry.count
        plan.totalCrafts = plan.totalCrafts + entry.count
        for itemID, material in pairs(entry.materials) do
            local total = plan.materials[itemID]
            if not total then
                total = CopyTable(material)
                total.quantity = 0
                plan.materials[itemID] = total
            end
            total.quantity = total.quantity + material.quantity * entry.count
        end
    end
end

function RS:EnsurePlanLoaded()
    if self.planLoaded then return end
    self.planLoaded = true
    local saved = HironCraftProfit_DB and HironCraftProfit_DB.recipeShoppingPlan
    if type(saved) ~= "table" then return end
    local plan = { entries = {}, recipeItems = {} }
    for _, source in ipairs(type(saved.entries) == "table" and saved.entries or {}) do
        if type(source) == "table" and type(source.materials) == "table" then
            local recipeID, count = tonumber(source.recipeID), tonumber(source.count)
            local materials, valid = {}, true
            for id, material in pairs(source.materials) do
                local itemID = tonumber(id)
                local amount = type(material) == "table" and tonumber(material.quantity)
                if not itemID or itemID <= 0 or not amount or amount <= 0 or amount ~= math.floor(amount) then
                    valid = false; break
                end
                materials[itemID] = CopyTable(material)
            end
            if valid and next(materials) and recipeID and recipeID > 0 and count
                and count >= 1 and count <= MAX_CRAFT_COUNT and count == math.floor(count) then
                local entry = CopyTable(source)
                self.nextEntryID = (self.nextEntryID or 0) + 1
                entry.id, entry.recipeID, entry.count = self.nextEntryID, recipeID, count
                entry.name = type(source.name) == "string" and source.name or ("#" .. recipeID)
                entry.materials = materials
                plan.entries[#plan.entries + 1] = entry
            end
        end
    end
    for id, item in pairs(type(saved.recipeItems) == "table" and saved.recipeItems or {}) do
        local recipeID = tonumber(id)
        if recipeID and type(item) == "table" and (tonumber(item.itemID)
            or (type(item.unresolvedName) == "string" and item.unresolvedName ~= "")) then
            plan.recipeItems[recipeID] = CopyTable(item)
        end
    end
    RebuildPlan(plan)
    self.plan = plan
end

function RS:ApplyPlan(plan, refresh)
    self:EnsurePlanLoaded()
    local previous = self.plan
    RebuildPlan(plan)
    self.plan = plan
    local ok, reason, missingTypes = true, nil, 0
    if refresh ~= false then
        local called
        called, ok, reason, missingTypes = pcall(self.RefreshShoppingList, self)
        if not called then
            if geterrorhandler then geterrorhandler()(ok) end
            ok, reason = false, "shopping_unavailable"
        end
    end
    if not ok then self.plan = previous else
        HironCraftProfit_DB = HironCraftProfit_DB or {}
        HironCraftProfit_DB.recipeShoppingPlan = plan
    end
    self:UpdatePlanDisplay()
    if not ok then return false, reason end
    return true, missingTypes
end

function RS:AddRecipe(recipeID, craftCount, transaction, form, quality)
    self:EnsurePlanLoaded()
    craftCount = math.max(1, math.min(MAX_CRAFT_COUNT, math.floor(tonumber(craftCount) or 1)))
    quality = tonumber(quality) or self:GetSettings().quality
    local materials, reason = self:CollectRecipeMaterials(recipeID, 1, transaction, form, quality)
    if not materials then return false, reason end
    recipeID = tonumber(recipeID)

    local parts = {}
    for itemID, material in pairs(materials) do
        parts[#parts + 1] = tostring(itemID) .. ":" .. tostring(material.quantity)
    end
    table.sort(parts)
    local signature = recipeID .. "/" .. quality .. "/" .. table.concat(parts, ",")
    local plan = CopyPlan(self.plan)
    local entry
    for _, existing in ipairs(plan.entries) do
        if existing.signature == signature then entry = existing; break end
    end
    if not entry then
        local recipeInfo = form and SafeCall(form.GetRecipeInfo, form)
        if not recipeInfo and C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
            local ok, info = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
            if ok then recipeInfo = info end
        end
        self.nextEntryID = (self.nextEntryID or 0) + 1
        entry = {
            id = self.nextEntryID, recipeID = recipeID, signature = signature,
            name = recipeInfo and recipeInfo.name or ("#" .. recipeID),
            count = 0, quality = quality, materials = materials,
        }
        plan.entries[#plan.entries + 1] = entry
    end
    if entry.count + craftCount > MAX_CRAFT_COUNT then return false, "bad_quantity" end
    entry.count = entry.count + craftCount
    return self:ApplyPlan(plan)
end

function RS:GetPlanEntries()
    self:EnsurePlanLoaded()
    local entries = {}
    for _, entry in ipairs(self.plan.entries or {}) do entries[#entries + 1] = entry end
    local recipeIDs = {}
    for recipeID in pairs(self.plan.recipeItems or {}) do recipeIDs[#recipeIDs + 1] = recipeID end
    table.sort(recipeIDs)
    for _, recipeID in ipairs(recipeIDs) do
        local item = self.plan.recipeItems[recipeID]
        entries[#entries + 1] = {
            id = "recipe:" .. recipeID, recipeID = recipeID, count = 1,
            name = item.label, kind = "recipe_item",
        }
    end
    return entries
end

function RS:SetEntryQuantity(entryID, quantity)
    self:EnsurePlanLoaded()
    quantity = tonumber(quantity)
    if not quantity or quantity ~= quantity or quantity < 0 or quantity > MAX_CRAFT_COUNT
        or quantity ~= math.floor(quantity) then return false, "bad_quantity" end
    local plan = CopyPlan(self.plan)
    for index, entry in ipairs(plan.entries) do
        if entry.id == entryID then
            if quantity == 0 then table.remove(plan.entries, index) else entry.count = quantity end
            return self:ApplyPlan(plan)
        end
    end
    local recipeID = type(entryID) == "string" and tonumber(entryID:match("^recipe:(%d+)$"))
    if recipeID and plan.recipeItems[recipeID] then
        if quantity > 1 then return false, "bad_quantity" end
        if quantity == 0 then plan.recipeItems[recipeID] = nil end
        return self:ApplyPlan(plan)
    end
    return false, "entry_missing"
end

function RS:ClearPlan(refresh)
    return self:ApplyPlan({ entries = {}, recipeItems = {} }, refresh)
end

local function GetRecipeSourceItem(recipeInfo)
    local recipeID = recipeInfo and tonumber(recipeInfo.recipeID)
    local recipeName = recipeInfo and recipeInfo.name
    if not recipeID or not recipeName or recipeName == "" then return nil end

    local sourceText
    if C_TradeSkillUI and type(C_TradeSkillUI.GetRecipeSourceText) == "function" then
        local ok, value = pcall(C_TradeSkillUI.GetRecipeSourceText, recipeID)
        sourceText = ok and value or nil
    end

    local itemID = type(sourceText) == "string" and tonumber(sourceText:match("|Hitem:(%d+)")) or nil
    if itemID then
        return {
            itemID = itemID,
            quantity = 1,
            label = (type(GetItemInfo) == "function" and GetItemInfo(itemID)) or recipeName,
            recipeID = recipeID,
        }
    end

    return {
        unresolvedName = recipeName,
        importName = recipeName,
        importSearchName = recipeName,
        importExpandGrades = true,
        itemClassID = Enum and Enum.ItemClass and Enum.ItemClass.Recipe,
        quantity = 1,
        label = recipeName,
        recipeID = recipeID,
    }
end

function RS:AddUnlearnedRecipe(recipeInfo)
    self:EnsurePlanLoaded()
    local purchase = GetRecipeSourceItem(recipeInfo)
    if not purchase then return false, "no_recipe_item" end

    self.plan.recipeItems = self.plan.recipeItems or {}
    local recipeID = tonumber(recipeInfo.recipeID)
    if self.plan.recipeItems[recipeID] then
        return true, "already_added"
    end

    local plan = CopyPlan(self.plan)
    plan.recipeItems[recipeID] = purchase
    local refreshed, reason = self:ApplyPlan(plan)
    if not refreshed then return false, reason end
    return true, "added"
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

function RS:NotifyPlanError(reason)
    Notify(T("PG_RECIPE_SHOP_ERROR_" .. string.upper(tostring(reason or "unknown")),
        "Could not update the recipe shopping list."), true)
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

function RS:AddSelectedUnlearnedRecipe()
    local recipeInfo = self:GetSelectedRecipe()
    if not recipeInfo or recipeInfo.learned then
        return false, "not_unlearned"
    end

    local ok, value = self:AddUnlearnedRecipe(recipeInfo)
    if ok then
        if value == "already_added" then
            Notify(T("PG_RECIPE_ITEM_ALREADY_ADDED", "This recipe is already in the shopping list."))
        else
            Notify(T("PG_RECIPE_ITEM_ADDED", "Recipe added to the shopping list."))
        end
    else
        Notify(T("PG_RECIPE_SHOP_ERROR_" .. string.upper(tostring(value or "unknown")),
            "Could not add the recipe item."), true)
    end
    return ok, value
end

function RS:GetPlannedRecipeItemCount()
    self:EnsurePlanLoaded()
    local count = 0
    for _ in pairs(self.plan.recipeItems or {}) do count = count + 1 end
    return count
end

function RS:GetPlanSummary()
    self:EnsurePlanLoaded()
    local recipeInfo = self:GetSelectedRecipe()
    local isUnlearned = recipeInfo and recipeInfo.learned ~= true
    if isUnlearned then
        return string.format(T("PG_RECIPE_ITEM_TOTAL", "Planned recipes: %d"), self:GetPlannedRecipeItemCount())
    end
    return string.format(T("PG_RECIPE_SHOP_TOTAL", "Planned crafts: %d"), tonumber(self.plan.totalCrafts) or 0)
end

function RS:UpdatePlanDisplay()
    if self.RefreshPlanWindow then self:RefreshPlanWindow() end
    local controls = self.controls
    if not controls then return end
    controls.counter:SetText(self:GetPlanSummary())
    if controls.quality then controls.quality:SetText(self:GetQualityLabel(self:GetSettings().quality)) end
    if controls.button.recipeShoppingHovered then self:UpdateTooltip(controls.button) end
end

function RS:UpdateTooltip(owner)
    if not GameTooltip then return end
    local recipeInfo = self:GetSelectedRecipe()
    local isUnlearned = recipeInfo and recipeInfo.learned ~= true

    -- Keep the same visible tooltip alive when its count changes. SetOwner
    -- resets the tooltip; only establish ownership when opening it.
    if GameTooltip:GetOwner() ~= owner then GameTooltip:SetOwner(owner, "ANCHOR_TOP") end
    GameTooltip:ClearLines()
    if isUnlearned then
        GameTooltip:SetText(T("PG_RECIPE_ITEM_BUTTON", "Add recipe"), 1, 0.82, 0)
        GameTooltip:AddLine(T("PG_RECIPE_ITEM_TOOLTIP", "Adds the item that teaches this recipe to the accumulating shopping list."), 1, 1, 1, true)
    else
        GameTooltip:SetText(T("PG_RECIPE_SHOP_BUTTON", "Add to shopping"), 1, 0.82, 0)
        GameTooltip:AddLine(T("PG_RECIPE_SHOP_TOOLTIP", "Adds the missing reagents for this recipe and quantity to one accumulating shopping list."), 1, 1, 1, true)
    end
    GameTooltip:AddLine(self:GetPlanSummary(), 0.65, 0.85, 1)
    GameTooltip:AddLine(T("PG_RECIPE_SHOP_CLEAR_HINT", "Right click: clear this recipe shopping list."), 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
end

function RS:EnsureControls()
    if self.controls then return self.controls end
    local page = GetCraftingPage()
    local form = page and page.SchematicForm
    if not page or not form or type(CreateFrame) ~= "function" then return nil end

    local controls = CreateFrame("Frame", "HironCraftRecipeShoppingControls", page)
    controls:SetSize(186, 22)
    controls:SetPoint("TOPRIGHT", form, "TOPRIGHT", -8, -44)
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
    -- GameTooltip's native update loop calls this on the owner while shown.
    button.UpdateTooltip = function(self) RS:UpdateTooltip(self) end
    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            if RS.ShowPlanWindow then RS:ShowPlanWindow() end
        else
            local recipeInfo = RS:GetSelectedRecipe()
            local added
            if recipeInfo and recipeInfo.learned ~= true then
                added = RS:AddSelectedUnlearnedRecipe()
            else
                added = RS:AddSelectedRecipe()
            end
            if added and RS.ShowPlanWindow then RS:ShowPlanWindow() end
        end
        RS:UpdatePlanDisplay()
    end)
    button:SetScript("OnEnter", function(self)
        self.recipeShoppingHovered = true
        self:UpdateTooltip()
    end)
    button:SetScript("OnLeave", function(self)
        self.recipeShoppingHovered = false
        if GameTooltip and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
    end)
    button:SetScript("OnHide", function(self)
        self.recipeShoppingHovered = false
        if GameTooltip and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
    end)

    local counter = controls:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    counter:SetPoint("TOPLEFT", controls, "BOTTOMLEFT", 0, -8)
    counter:SetWidth(186)
    counter:SetJustifyH("LEFT")
    counter:SetTextColor(0.65, 0.85, 1)
    local list = CreateFrame("Button", nil, controls, "UIPanelButtonTemplate")
    list:SetSize(56, 18)
    list:SetPoint("TOPRIGHT", controls, "BOTTOMRIGHT", 0, -24)
    list:SetText(T("PG_RECIPE_PLAN_OPEN", "List"))
    list:SetPushedTextOffset(0, 0)
    list:SetScript("OnClick", function() if RS.ShowPlanWindow then RS:ShowPlanWindow() end end)
    controls.list = list
    controls.counter = counter
    controls.quantity = quantity
    controls.button = button
    self.controls = controls
    return controls
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
    local regularRecipe = not recipeInfo.isRecraft and not recipeInfo.isDummyRecipe and not recipeInfo.isGatheringRecipe
    local supported = regularRecipe and (recipeInfo.learned ~= true or (
        schematic and schematic.recipeType ~= salvageType
        and schematic.reagentSlotSchematics and #schematic.reagentSlotSchematics > 0))

    controls:SetShown(supported == true)
    if not supported then return end

    if recipeInfo.learned == true then
        controls.quantity:Show()
        controls.button:ClearAllPoints()
        controls.button:SetSize(150, 22)
        controls.button:SetPoint("LEFT", controls.quantity, "RIGHT", 4, 0)
        controls.button:SetText(T("PG_RECIPE_SHOP_BUTTON", "Add to shopping"))
    else
        controls.quantity:Hide()
        controls.button:ClearAllPoints()
        controls.button:SetSize(142, 22)
        controls.button:SetPoint("LEFT", controls, "LEFT", 0, 0)
        controls.button:SetText(T("PG_RECIPE_ITEM_BUTTON", "Add recipe"))
    end
    controls.button:SetEnabled(true)
    if controls.recipeID ~= recipeInfo.recipeID then
        controls.recipeID = recipeInfo.recipeID
        controls.quantity:SetNumber(1)
        controls.quantity:SetCursorPosition(0)
    end
    self:UpdatePlanDisplay()
end

RS.SOURCE_KIND = SOURCE_KIND
RS.GetItemCountForShopping = GetItemCountForShopping
