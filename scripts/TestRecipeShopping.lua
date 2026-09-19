HironCraftProfit = {
    L = {
        PG_RECIPE_SHOP_LIST_NAME = "Recipe test list",
    },
}

local itemCounts = {
    [101] = 3,
    [203] = 1,
    [301] = 0,
    [901] = 0,
}
local itemNames = {
    [101] = "Thread",
    [201] = "Cloth R1",
    [202] = "Cloth R2",
    [203] = "Cloth R3",
    [301] = "Finisher",
    [901] = "Plans: Test Recipe",
}
local qualities = { [201] = 1, [202] = 2, [203] = 3 }
local captured = {}
local shoppingUnavailable = false

C_Item = {
    GetItemCount = function(itemID) return itemCounts[itemID] or 0 end,
}
C_TradeSkillUI = {
    GetItemReagentQualityByItemInfo = function(itemID) return qualities[itemID] end,
    GetRecipeSourceText = function(recipeID)
        if recipeID == 2001 then
            return "Source: |Hitem:901::::::::|h[Plans: Test Recipe]|h"
        end
        return "World drop"
    end,
}
Enum = {
    CraftingReagentType = { Basic = 1, Finishing = 3 },
    TradeskillRecipeType = { Item = 1, Salvage = 2 },
    ItemClass = { Recipe = 9 },
}
function GetItemInfo(itemID) return itemNames[itemID] end
function wipe(tbl) for key in pairs(tbl) do tbl[key] = nil end end

HironCraftProfit.ShoppingList = {
    CreateTemporaryImportedList = function(_, name, materials, sourceKind, allowEmpty)
        if shoppingUnavailable then return false, "shopping_unavailable" end
        captured[#captured + 1] = {
            name = name,
            materials = materials,
            sourceKind = sourceKind,
            allowEmpty = allowEmpty,
        }
        return true, "created"
    end,
}

assert(loadfile("ProfitHub/Shop/Core/RecipeShopping.lua"))("HironCraft", {})
local RS = HironCraftProfit.RecipeShopping

local schematicOne = {
    recipeType = Enum.TradeskillRecipeType.Item,
    reagentSlotSchematics = {
        {
            slotIndex = 1,
            reagentType = Enum.CraftingReagentType.Basic,
            quantityRequired = 4,
            reagents = { { itemID = 101 } },
        },
        {
            slotIndex = 2,
            reagentType = Enum.CraftingReagentType.Basic,
            quantityRequired = 2,
            reagents = { { itemID = 201 }, { itemID = 202 }, { itemID = 203 } },
        },
        {
            slotIndex = 3,
            reagentType = Enum.CraftingReagentType.Finishing,
            quantityRequired = 1,
            reagents = { { itemID = 301 } },
        },
    },
}

local function Allocations(entries)
    return { allocs = entries or {} }
end

local transactionOne = {
    allocationTbls = {
        [2] = Allocations({ { reagent = { itemID = 203 }, quantity = 2 } }),
        [3] = Allocations({ { reagent = { itemID = 301 }, quantity = 1 } }),
    },
    GetRecipeSchematic = function() return schematicOne end,
    IsSlotRequired = function(_, slotIndex) return slotIndex == 1 or slotIndex == 2 end,
}

local function MaterialMap(materials)
    local result = {}
    for _, material in ipairs(materials or {}) do result[material.itemID] = material end
    return result
end

local ok, missingTypes = RS:AddRecipe(1001, 2, transactionOne)
assert(ok and missingTypes == 3, "first recipe was not added")
local first = captured[#captured]
local firstMap = MaterialMap(first.materials)
assert(first.name == "Recipe test list" and first.sourceKind == RS.SOURCE_KIND and first.allowEmpty == true)
assert(firstMap[101].quantity == 5, "owned base reagent was not subtracted once")
assert(firstMap[201].quantity == 4 and firstMap[201].tier == 1 and not firstMap[203], "default T1 did not override allocated T3")
assert(firstMap[301].quantity == 2, "selected finishing reagent was not included")

local schematicTwo = {
    recipeType = Enum.TradeskillRecipeType.Item,
    reagentSlotSchematics = {
        {
            slotIndex = 1,
            reagentType = Enum.CraftingReagentType.Basic,
            quantityRequired = 2,
            reagents = { { itemID = 101 } },
        },
    },
}
local transactionTwo = {
    GetRecipeSchematic = function() return schematicTwo end,
    IsSlotRequired = function() return true end,
}

assert(RS:AddRecipe(1002, 1, transactionTwo))
local secondMap = MaterialMap(captured[#captured].materials)
assert(secondMap[101].quantity == 7,
    "second recipe did not share inventory with the accumulated plan")

assert(RS:AddRecipe(1001, 1, transactionOne))
local repeatedMap = MaterialMap(captured[#captured].materials)
assert(repeatedMap[101].quantity == 11 and repeatedMap[201].quantity == 6,
    "repeated recipe click did not increase the same plan")
assert(RS.plan.recipes[1001] == 3 and RS.plan.recipes[1002] == 1 and RS.plan.totalCrafts == 4,
    "planned craft quantities were not accumulated")

assert(RS:ClearPlan())
local cleared = captured[#captured]
assert(#cleared.materials == 0 and cleared.allowEmpty == true,
    "clearing did not replace the temporary list with an empty list")

local bestQualityForm = {
    AllocateBestQualityCheckbox = { GetChecked = function() return true end },
}
local bestQualityTransaction = {
    GetRecipeSchematic = function()
        return {
            recipeType = Enum.TradeskillRecipeType.Item,
            reagentSlotSchematics = {
                {
                    slotIndex = 1,
                    reagentType = Enum.CraftingReagentType.Basic,
                    quantityRequired = 2,
                    reagents = { { itemID = 201 }, { itemID = 202 }, { itemID = 203 } },
                },
            },
        }
    end,
    IsSlotRequired = function() return true end,
}

assert(RS:AddRecipe(1003, 1, bestQualityTransaction, bestQualityForm))
local bestMap = MaterialMap(captured[#captured].materials)
assert(bestMap[201] and bestMap[201].quantity == 2 and not bestMap[203],
    "native best-quality checkbox overrode shopping tier")

RS:ClearPlan(false)
local badTransaction = {
    GetRecipeSchematic = function()
        return {
            recipeType = Enum.TradeskillRecipeType.Item,
            reagentSlotSchematics = {
                { slotIndex = 1, reagentType = Enum.CraftingReagentType.Basic, quantityRequired = 1, reagents = {} },
            },
        }
    end,
    IsSlotRequired = function() return true end,
}
local bad, reason = RS:AddRecipe(1004, 1, badTransaction)
assert(not bad and reason == "unresolved_reagent" and not next(RS.plan.materials),
    "unresolved reagent partially changed the shopping plan")

assert(RS:AddUnlearnedRecipe({ recipeID = 2001, name = "Test Recipe", learned = false }))
local recipeMap = MaterialMap(captured[#captured].materials)
assert(recipeMap[901] and recipeMap[901].quantity == 1,
    "linked unlearned recipe item was not added")

local duplicateOk, duplicateReason = RS:AddUnlearnedRecipe({ recipeID = 2001, name = "Test Recipe", learned = false })
assert(duplicateOk and duplicateReason == "already_added" and RS:GetPlannedRecipeItemCount() == 1,
    "duplicate unlearned recipe was added twice")

assert(RS:AddUnlearnedRecipe({ recipeID = 2002, name = "Fallback Recipe", learned = false }))
local fallbackRows = captured[#captured].materials
local fallback
for _, row in ipairs(fallbackRows) do
    if row.recipeID == 2002 then fallback = row end
end
assert(fallback and fallback.unresolvedName == "Fallback Recipe"
    and fallback.itemClassID == Enum.ItemClass.Recipe,
    "unlearned recipe without a source link did not retain a recipe-class auction lookup")
assert(RS:GetPlannedRecipeItemCount() == 2, "planned recipe count was not updated")

-- Exact-quality stock accounting and independently editable reagent snapshots.
RS:ClearPlan(false)
local function ClothTransaction(required)
    return {
        GetRecipeSchematic=function() return {recipeType=1,reagentSlotSchematics={
            {slotIndex=1,reagentType=1,quantityRequired=required,
                reagents={{itemID=201},{itemID=202},{itemID=203}}},
        }} end,
        IsSlotRequired=function() return true end,
        allocationTbls={[1]=Allocations({
            {reagent={itemID=202},quantity=15}, {reagent={itemID=201},quantity=20},
        })},
    }
end
itemCounts[201], itemCounts[202] = 20, 15
RS:SetQuality(1)
assert(RS:AddRecipe(3001,1,ClothTransaction(40)))
local exact=MaterialMap(captured[#captured].materials)
assert(exact[201].quantity==20 and exact[201].tier==1 and not exact[202],
    '40 T1 minus 20 T1 and 15 T2 must buy 20 T1, not 5 or T2')
local firstID=RS.plan.entries[1].id
assert(RS:AddRecipe(3002,1,ClothTransaction(10)))
assert(MaterialMap(captured[#captured].materials)[201].quantity==30,'shared stock was subtracted twice')
local secondID=RS.plan.entries[2].id
assert(RS:AddRecipe(3001,1,ClothTransaction(40)))
assert(#RS.plan.entries==2 and RS.plan.entries[1].count==2,'identical recipe additions did not merge')
assert(MaterialMap(captured[#captured].materials)[201].quantity==70)
assert(RS:SetEntryQuantity(firstID,1))
assert(MaterialMap(captured[#captured].materials)[201].quantity==30,'partial removal did not recalculate missing stock')
assert(RS:SetEntryQuantity(secondID,0))
assert(#RS.plan.entries==1 and MaterialMap(captured[#captured].materials)[201].quantity==20)
RS:SetQuality(2)
assert(RS.plan.entries[1].quality==1,'changing future quality rewrote an existing entry')
assert(RS:AddRecipe(3001,1,ClothTransaction(40)))
exact=MaterialMap(captured[#captured].materials)
assert(#RS.plan.entries==2 and exact[201].quantity==20 and exact[202].quantity==25,
    'different quality selections merged or consumed other-tier inventory')
RS:GetSettings().useInventory=false -- legacy setting cannot disable stock accounting
assert(RS:RefreshShoppingList())
exact=MaterialMap(captured[#captured].materials)
assert(exact[201].quantity==20 and exact[202].quantity==25,'stock accounting was disabled by legacy settings')
assert(RS:SetEntryQuantity(firstID,0))
assert(not MaterialMap(captured[#captured].materials)[201] and RS.plan.entries[1].quality==2,
    'removing T1 recipe affected the T2 entry')
assert(not RS:SetEntryQuantity(secondID,2),'stale removed row changed a different recipe')
assert(not RS:SetEntryQuantity(RS.plan.entries[1].id,-1))
assert(not RS:SetEntryQuantity(RS.plan.entries[1].id,1.5))
assert(not RS:SetEntryQuantity(RS.plan.entries[1].id,10000))
local before=RS.plan
shoppingUnavailable=true
assert(not RS:AddRecipe(3003,1,ClothTransaction(10)))
assert(RS.plan==before,'failed add left a phantom recipe in the plan')
assert(not RS:SetEntryQuantity(before.entries[1].id,0))
assert(RS.plan==before,'failed delete changed the plan')
assert(not RS:ClearPlan())
assert(RS.plan==before,'failed clear lost the plan')
shoppingUnavailable=false
local saved=HironCraftProfit_DB.recipeShoppingPlan
RS.plan={entries={},recipeItems={}}
RS.planLoaded=false
assert(#RS:GetPlanEntries()==1 and RS.plan.entries[1].count==1,'saved recipe plan did not restore')
assert(MaterialMap(RS:BuildMissingMaterials())[202].quantity==25,'restored plan lost its reagent snapshot')
assert(saved.entries[1].quality==2)
RS:ClearPlan(false)
local unavailable=ClothTransaction(40)
unavailable.GetRecipeSchematic=function() return {recipeType=1,reagentSlotSchematics={
    {slotIndex=1,reagentType=1,quantityRequired=40,reagents={{itemID=201},{itemID=202}}},
}} end
local qualityOK,qualityReason=RS:AddRecipe(3001,1,unavailable,nil,3)
assert(not qualityOK and qualityReason=='quality_unavailable' and #RS.plan.entries==0,
    'unavailable T3 silently substituted another quality')
RS:SetQuality(0)
itemCounts[201], itemCounts[202] = nil, nil

-- Sparks have multiple alternatives, but no quality and no auctionability.
local originalItemInfo=GetItemInfo
GetItemInfo=function(id)
    if id==800 or id==801 then
        return 'Spark',nil,4,nil,nil,nil,nil,nil,nil,nil,nil,7,0,1
    end
    return originalItemInfo(id)
end
local sparkTransaction={GetRecipeSchematic=function() return {recipeType=1,reagentSlotSchematics={
    {slotIndex=1,reagentType=1,quantityRequired=2,reagents={{itemID=800},{itemID=801}}},
    {slotIndex=2,reagentType=1,quantityRequired=4,reagents={{itemID=201},{itemID=202}}},
}} end,IsSlotRequired=function() return true end}
assert(RS:AddRecipe(4001,1,sparkTransaction),'spark alternatives blocked recipe addition')
local sparkMap=MaterialMap(captured[#captured].materials)
assert(not sparkMap[800] and not sparkMap[801] and sparkMap[201].quantity==4,
    'bound sparks entered the shopping list or replaced real reagents')
itemCounts[201]=3
assert(RS:RefreshShoppingList())
assert(MaterialMap(captured[#captured].materials)[201].quantity==1,'new stock did not reduce purchase quantities')
itemCounts[201]=nil
RS:ClearPlan(false)
GetItemInfo=originalItemInfo

-- UI regression: multiple clicks with one OnEnter and no timer/mouse movement.
-- Both the persistent label and the existing tooltip must change synchronously.
local function noop() end
local function MockFrame()
    return {
        scripts={}, shown=true,
        SetSize=noop, SetWidth=noop, SetPoint=noop, SetFrameLevel=noop, SetAutoFocus=noop,
        SetPushedTextOffset=noop,
        SetNumeric=noop, SetMaxLetters=noop, SetJustifyH=noop,
        SetCursorPosition=noop, ClearFocus=noop, ClearAllPoints=noop,
        RegisterForClicks=noop, SetEnabled=noop, SetTextColor=noop,
        SetNumber=function(self,n) self.number=n end,
        GetNumber=function(self) return self.number end,
        SetText=function(self,text) self.text=text end,
        SetScript=function(self,event,fn) self.scripts[event]=fn end,
        Show=function(self) self.shown=true end,
        Hide=function(self) self.shown=false end,
        SetShown=function(self,shown) self.shown=shown end,
        CreateFontString=function() return MockFrame() end,
    }
end
CreateFrame=MockFrame
local selectedRecipe={recipeID=1001,learned=true}
ProfessionsFrame={CraftingPage={
    GetFrameLevel=function() return 5 end,
    SchematicForm={
        GetRecipeInfo=function() return selectedRecipe end,
        GetTransaction=function() return transactionOne end,
        IsShown=function() return true end,
    },
}}
local ownerChanges=0
GameTooltip={
    GetOwner=function(self) return self.owner end,
    SetOwner=function(self,owner) self.owner=owner; ownerChanges=ownerChanges+1 end,
    ClearLines=function(self) self.lines={} end,
    SetText=function(self,text) self.lines={text} end,
    AddLine=function(self,text) table.insert(self.lines,text) end,
    Show=function(self) self.shown=true end,
    Hide=function(self) self.shown=false end,
}
RS:ClearPlan(false)
RS:OnRecipeSelected()
local controls=RS.controls
local button=controls.button
local function ExpectDisplay(text)
    assert(controls.counter.text==text,'persistent count is stale: '..tostring(controls.counter.text))
    assert(GameTooltip.shown and GameTooltip.lines[3]==text,
        'hovered tooltip count is stale: '..tostring(GameTooltip.lines[3]))
    assert(#GameTooltip.lines==4,'old tooltip lines accumulated')
end
button.scripts.OnEnter(button)
ExpectDisplay('Planned crafts: 0')
for count=1,3 do
    button.scripts.OnClick(button,'LeftButton')
    ExpectDisplay('Planned crafts: '..count)
end
controls.quantity:SetNumber(4)
button.scripts.OnClick(button,'LeftButton')
ExpectDisplay('Planned crafts: 7')
button:UpdateTooltip() -- Blizzard's normal tooltip update path.
ExpectDisplay('Planned crafts: 7')
button.scripts.OnClick(button,'RightButton')
ExpectDisplay('Planned crafts: 7') -- Right click now opens the non-destructive editor.
RS:ClearPlan()
ExpectDisplay('Planned crafts: 0')

selectedRecipe={recipeID=2001,name='Test Recipe',learned=false}
RS:OnRecipeSelected()
ExpectDisplay('Planned recipes: 0')
button.scripts.OnClick(button,'LeftButton')
ExpectDisplay('Planned recipes: 1')
button.scripts.OnClick(button,'LeftButton')
ExpectDisplay('Planned recipes: 1') -- Duplicate recipe stays deduplicated.
assert(RS:AddUnlearnedRecipe({recipeID=2002,name='Fallback Recipe',learned=false}))
ExpectDisplay('Planned recipes: 2') -- Non-button plan updates repaint too.
button.scripts.OnClick(button,'RightButton')
ExpectDisplay('Planned recipes: 2')
RS:ClearPlan()
ExpectDisplay('Planned recipes: 0')
assert(ownerChanges==1,'refresh reset tooltip ownership while continuously hovered')
button.scripts.OnHide(button)
assert(not GameTooltip.shown and not button.recipeShoppingHovered,'hidden button retained tooltip')

print("Recipe shopping tests passed (accumulation, inventory, qualities, unlearned recipes, live label and tooltip).")
