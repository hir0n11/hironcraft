-- Engraved Gemcutter / Marbled Stone: fixed and ranked reagents share numeric
-- dataSlotIndex values, but only modified slots belong in operation requests.
local clock, child, calls, unavailable = 100, 2879, 0, false
local function noop() end
local function wipe(t) for k in pairs(t) do t[k] = nil end end
local db = { queue = { reagentMode = 'profit', minProfitCopper = 10000, allowConcentration = false } }
local CO = { selectedOrders = {}, selectedReagents = {}, useConcentration = {}, rowStates = {},
    craftingReagentInfoCache = {}, qualityCache = {}, concentrationRequirementCache = {} }
local PT = { Prices = { GetItemPrice = function() return 10 end } }
HironCraft, HironCraftProfit = PT, PT
SlashCmdList = {}
GetTime = function() return clock end
Enum = { TradeskillSlotDataType = { Reagent = 0, ModifiedReagent = 1, Currency = 2 },
    CraftingReagentType = { Basic = 1, Finishing = 2 }, CraftingOrderType = { Npc = 4, Personal = 3 } }
local schematics = {
    [435324] = { reagentSlotSchematics = {
        { slotIndex = 1, dataSlotIndex = 1, dataSlotType = 0, reagentType = 1, required = true, quantityRequired = 5, reagents = { { itemID = 213398 } } },
        { slotIndex = 2, dataSlotIndex = 2, dataSlotType = 0, reagentType = 1, required = true, quantityRequired = 1, reagents = { { itemID = 213399 } } },
        { slotIndex = 3, dataSlotIndex = 1, dataSlotType = 1, reagentType = 1, required = true, quantityRequired = 5,
            reagents = { { itemID = 210930 }, { itemID = 210931 }, { itemID = 210932 } } },
    } },
    [435326] = { reagentSlotSchematics = {
        { slotIndex = 1, dataSlotIndex = 1, dataSlotType = 0, reagentType = 1, required = true, quantityRequired = 4, reagents = { { itemID = 213398 } } },
        { slotIndex = 2, dataSlotIndex = 1, dataSlotType = 1, reagentType = 1, required = true, quantityRequired = 3,
            reagents = { { itemID = 210930 }, { itemID = 210931 }, { itemID = 210932 } } },
    } },
}
C_TradeSkillUI = {
    GetRecipeSchematic = function(id) return schematics[id] end,
    GetRecipeInfo = function() return { learned = true, maxQuality = 3 } end,
    GetProfessionChildSkillLineID = function() return child end,
    GetCraftingOperationInfoForOrder = function(id, reagents, orderID, applied)
        calls = calls + 1
        assert(type(reagents) == 'table', 'quality request used a nil allocation')
        if #reagents == 0 then return { craftingQuality = 1, concentrationCost = 71 } end
        local quantity, quality = 0, 3
        for _, entry in ipairs(reagents) do
            assert(entry.dataSlotIndex == 1 and entry.reagent.itemID >= 210930 and entry.reagent.itemID <= 210932,
                'fixed reagent / absolute slot index polluted the operation request')
            quantity = quantity + entry.quantity
            quality = math.min(quality, entry.reagent.itemID - 210929)
        end
        assert(quantity == (id == 435324 and 5 or 3), 'allocation lost a grade or a quantity')
        if unavailable then return nil end
        return { craftingQuality = math.min(3, quality + (applied and 1 or 0)), concentrationCost = quality == 1 and 71 or 0 }
    end,
}
local E = setmetatable({ CO = CO, PT = PT, HironCraft = PT, Enum = Enum, C_TradeSkillUI = C_TradeSkillUI,
    T = function(_, fallback) return fallback end, SlashCmdList = {}, wipe = wipe,
    GetDB = function() return db end, CacheNow = GetTime, GetOrderRevision = function() return 0 end,
    REAGENT_CACHE_TTL = 1, QUALITY_CACHE_TTL = 1, QUALITY_MISS_CACHE_TTL = 0.1,
    OrderKey = function(id) return id and tostring(id) end,
    SameOrderID = function(a, b) return tostring(a) == tostring(b) end,
    GetAuctionatorItemPrice = function() return 10 end,
}, { __index = _G })
HironCraftProfitCraftingOrdersEnv = E
dofile('Workflow/Core/CraftEngine/Engine.lua')
for _, file in ipairs({ 'State', 'QualityReagents', 'QueueShopping' }) do
    dofile('Workflow/Orders/CraftingOrders/' .. file .. '.lua')
end
CO.PrepareOrderForQueueAnalysis = function() return false end
CO.OrderMatchesSelectedProfessionExpansion = function() return true end
CO.CanSupplyCrafterReagentsForQueue = function() return true end
CO.GetOrderProfitInfo = function() return { profit = 393300 } end
CO.GetOrderActionAvailabilitySortRank = function() return 1 end
CO.IsOrderManuallyExcluded = function() return false end
CO.GetCachedConcentrationRequirementVisualState = function() return true, true end -- stale visual hold
CO.InvalidateOrderCaches = function()
    wipe(CO.craftingReagentInfoCache); wipe(CO.qualityCache); wipe(CO.concentrationRequirementCache)
end
local function provided(itemID, slotIndex, ds, qty)
    return { slotIndex = slotIndex, source = 1, reagentInfo = { reagent = { itemID = itemID }, dataSlotIndex = ds, quantity = qty } }
end
local currentDisplay
CO.BuildDisplayReagents = function() return currentDisplay end
local options = { automatic = true, includeProfit = true, allowConcentration = false }
for _, recipeID in ipairs({ 435324, 435326 }) do
    local slot = recipeID == 435324 and 3 or 2
    local qty = recipeID == 435324 and 5 or 3
    local order = { orderID = recipeID, spellID = recipeID, minQuality = 2, orderType = 4,
        reagents = { provided(210931, slot, 1, qty) } }
    if recipeID == 435324 then order.reagents[#order.reagents + 1] = provided(213399, 2, 2, 1) end
    currentDisplay = { { itemID = 213398, slotIndex = 1, dataSlotIndex = 1, quantity = qty,
        crafterRequired = true }, ahuiSchematicReady = true }
    CO:InvalidateOrderCaches()
    local locked = CO:BuildLockedReagentsForEngine(order)
    assert(locked[1].itemID == 210931 and not locked[slot], 'customer rank locked at absolute slot index')
    assert(not locked[2], 'regular customer reagent overwrote a modified slot')
    local manualLocked = CO:BuildManualReagentsForEngine(order)
    assert(manualLocked[1].itemID == 210931, 'manual mode let fixed reagents overwrite the supplied rank')
    local full = CO:BuildCraftingReagentInfoTbl(order)
    assert(#full == 1 and full[1].reagent.itemID == 210931 and full[1].dataSlotIndex == 1)
    assert(#CO:BuildOrderOnlyCraftingReagentInfoTbl(order) == 1)
    assert(#CO:BuildSchematicCraftingReagentInfoTbl(order) == 1)
    local plan = PT.CraftEngine:NeedsConcentrationCached(recipeID, 2, order.orderID, 'profit', locked)
    assert(plan and plan.needs == false, 'profit engine ignored the customer rank')
    assert(CO:OrderRequiresConcentrationForQueue(order) == false, 'visual hold overrode actual reagent quality')
    local result = CO:GetAvailabilityQueueAnalysis(order, 4, options)
    assert(result and result.queued and result.useConcentration == false, 'profitable attainable order was skipped')
    assert(not CO:GetQueueSkipReason(order))

    -- A real low-grade allocation must still be rejected without permission.
    order.reagents[1] = provided(210930, slot, 1, qty)
    assert(CO:OrderRequiresConcentrationForQueue(order) == true, 'quality cache reused different customer reagents')
    CO:InvalidateOrderCaches()
    local lowPlan = PT.CraftEngine:NeedsConcentrationCached(recipeID, 2, order.orderID, 'profit', CO:BuildLockedReagentsForEngine(order))
    assert(lowPlan and lowPlan.needs == true, 'engine reused a different customer allocation')
    assert(not CO:GetAvailabilityQueueAnalysis(order, 4, options))
    assert(CO.queueSkipReasons[tostring(order.orderID)].code == 'concentration')
    assert(CO:GetQueueSkipReason(order):find('concentration'))

    -- If the actual request is unanswered, an empty allocation's "quality 1,
    -- 71 concentration" must not become evidence for queue admission/rejection.
    unavailable = true; CO:InvalidateOrderCaches()
    local before = calls
    assert(CO:GetOrderOperationInfo(order, true) == nil and calls == before + 1,
        'quality calculation silently retried with an empty allocation or dropped concentration')
    assert(not CO:GetAvailabilityQueueAnalysis(order, 4, options))
    assert(CO.queueSkipReasons[tostring(order.orderID)].code == 'quality_unknown')
    unavailable = false

    -- Several customer ranks in one modified slot must all survive.
    order.reagents = { provided(210931, slot, 1, qty - 1), provided(210932, slot, 1, 1) }
    CO:InvalidateOrderCaches()
    full = CO:BuildCraftingReagentInfoTbl(order)
    assert(#full == 2 and full[1].quantity + full[2].quantity == qty, 'customer mix lost a grade')
    locked = CO:BuildLockedReagentsForEngine(order)
    assert(#PT.CraftEngine:MakeReagents(PT.CraftEngine:GetRecipeBasics(recipeID), function() return 1 end, locked) == 2)
    assert(#CO:BuildOrderOnlyCraftingReagentInfoTbl(order) == 2)
    assert(CO:GetOrderQualityInfo(order, false, false).quality == 2)
    assert(not CO:IsCompleteOperationReagentInfoTbl(order, {}), 'missing modified reagent was accepted as a complete allocation')
end

-- A crafter's selected mixed grades are also priced as the actual mix.
local order = { orderID = 999, spellID = 435326, minQuality = 2, orderType = 4, reagents = {} }
currentDisplay = { { itemID = 210930, slotIndex = 2, dataSlotIndex = 1, quantity = 3,
    crafterRequired = true }, ahuiSchematicReady = true }
CO.selectedReagents['999:1'] = { itemID = 210931, slotIndex = 2, dataSlotIndex = 1, quantity = 3,
    mix = { { itemID = 210931, quantity = 2 }, { itemID = 210932, quantity = 1 } } }
CO:InvalidateOrderCaches()
local full = CO:BuildCraftingReagentInfoTbl(order)
assert(#full == 2 and full[1].quantity == 2 and full[2].quantity == 1, 'manual mix was replaced by its first grade')
CO:SetQueueSkipReason(order, 'quality_unknown')
CO.selectedOrders['999'] = true
assert(not CO:GetQueueSkipReason(order), 'checked order retained a skip tooltip')

-- A hidden native transaction must be matched to this order/recipe. Its
-- unanswered operation must not be replaced by a leftover quality meter.
unavailable = true
local form = { transaction = { GetRecipeID = function() return order.spellID end,
    CreateCraftingReagentInfoTbl = function() return full end },
    GetRecipeOperationInfo = function() return nil end,
    Details = { GetProjectedQualityInfo = function() error('stale quality meter was used') end } }
local page = { OrderView = { order = order, OrderDetails = { SchematicForm = form } } }
CO.activePageFrame = page
CO.FindOrderPageFrame = function() return page end
CO.IsCraftingOrdersPageOpen, CO.IsSafeToPrepareOrderViewForAnalysis = function() return true end, function() return true end
CO.PrepareOrderForQueueAnalysis = function() return true end
CO.ApplySelectedReagentsToEngine, CO.SetEngineConcentration = noop, noop
assert(CO:GetOrderQualityInfoFromPreparedOrderView(order, false) == nil)
page.OrderView.order = { orderID = 123 }
local before = calls
assert(CO:GetOrderQualityInfoFromPreparedOrderView(order, false) == nil and calls == before,
    'a different hidden order was used for the quality fallback')
-- No automatic action is part of the analysis path.
print('Actual order reagent and queue reason tests passed.')
