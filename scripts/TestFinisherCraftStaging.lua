-- Regression coverage for the two-click finishing-reagent handoff. The first
-- hardware click changes the Blizzard transaction; the next one crafts it.
if not setfenv then
    function setfenv(fn, env)
        if type(fn) == "number" then
            fn = debug.getinfo(fn + 1, "f").func
        end
        local index = 1
        while true do
            local name = debug.getupvalue(fn, index)
            if not name then return fn end
            if name == "_ENV" then
                debug.upvaluejoin(fn, index, function() return env end, 1)
                return fn
            end
            index = index + 1
        end
    end
end

local CO = {}
local now = 100
local E = setmetatable({
    PT = {},
    CO = CO,
    T = function(_, fallback) return fallback end,
    OrderKey = function(value) return value and tostring(value) end,
    SameOrderID = function(a, b) return a ~= nil and b ~= nil and tostring(a) == tostring(b) end,
    SafeCall = function(_, callback)
        local ok = pcall(callback)
        return ok
    end,
    GetTime = function() return now end,
}, { __index = _G })
_G.HironCraftProfitCraftingOrdersEnv = E

dofile("ProfitHub/Orders/CraftingOrders/Actions.lua")
dofile("ProfitHub/Orders/CraftingOrders/FinishingReagents.lua")

-- GetOrderEngine must preserve only an explicitly staged transaction.
local setOrderCalls = 0
local orderView = {
    order = nil,
    SetOrder = function(self, order)
        setOrderCalls = setOrderCalls + 1
        self.order = order
    end,
    IsShown = function() return false end,
    Hide = function() end,
}
local page = {
    OrderView = orderView,
    BrowseFrame = {
        IsShown = function() return true end,
        Show = function() end,
    },
}

CO.FindOrderPageFrame = function(_, candidate) return candidate end
CO.EnsurePageBindingHooks = function() end
CO.EnsureControlPanel = function() end
CO.InvalidateOrderCaches = function() end

local order = { orderID = 42 }
assert(CO:GetOrderEngine(page, order) == orderView)
assert(setOrderCalls == 1)

CO.preparedFinisherOrderID = order.orderID
assert(CO:GetOrderEngine(page, order) == orderView)
assert(setOrderCalls == 1, "staged finisher transaction was rebuilt")

assert(CO:GetOrderEngine(page, { orderID = 43 }) == orderView)
assert(setOrderCalls == 2)
assert(CO.preparedFinisherOrderID == nil)

-- CraftOrderFromRow must stop after selecting the finisher, remain actionable,
-- and craft on the following press instead of entering a stuck pending state.
local craftCalls = 0
local apiCraftCalls = 0
local apiCraftReagents
local createButtonCalls = 0
local prepareCalls = 0
local scheduled = {}
E.C_Timer = {
    After = function(delay, callback)
        scheduled[#scheduled + 1] = { delay = delay, callback = callback }
    end,
}
E.C_TradeSkillUI = {
    CraftRecipe = function(_, _, reagents)
        apiCraftCalls = apiCraftCalls + 1
        apiCraftReagents = reagents
    end,
}
E.GetOrderReagentItemID = function(reagentInfo)
    local reagent = reagentInfo and (reagentInfo.reagent or reagentInfo.reagentInfo or reagentInfo)
    return reagent and reagent.itemID
end
E.IsResultOk = function(result) return result == 0 end
E.UnitCastingInfo = function() return nil end
E.UnitChannelInfo = function() return nil end
local createEnabled = false
local liveReagents = {
    { reagent = { itemID = 100 }, dataSlotIndex = 1, quantity = 10 },
    { reagent = { itemID = 246447 }, dataSlotIndex = 9, quantity = 1 },
}
local transaction = {
    CreateCraftingReagentInfoTbl = function() return liveReagents end,
}
local engine = {
    OrderDetails = {
        SchematicForm = {
            GetTransaction = function()
                return transaction
            end,
        },
    },
    CreateButton = {
        IsEnabled = function() return createEnabled end,
        GetScript = function(_, scriptName)
            if scriptName ~= "OnClick" then return nil end
            return function()
                createButtonCalls = createButtonCalls + 1
            end
        end,
    },
    CraftOrder = function()
        craftCalls = craftCalls + 1
    end,
}
local button = {}
order = {
    orderID = 77,
    spellID = 1234,
    isRecraft = false,
    reagents = {
        { reagent = { itemID = 100 }, quantity = 10 },
    },
}

CO.GetEffectiveOrder = function(_, _, fallback) return fallback end
CO.FindOrderPageFrame = function(_, candidate) return candidate end
CO.IsAtUsableCraftingOrderTable = function() return true end
CO.GetRecipeKnownState = function() return true end
CO.CanSupplyCrafterReagentsForQueue = function() return true end
CO.GetClaimedOrder = function() return order end
CO.GetOrderEngine = function() return engine end
CO.GetTransactionFromEngine = function() return transaction, engine.OrderDetails.SchematicForm end
CO.ApplySelectedReagentsToEngine = function() end
CO.SetEngineConcentration = function() end
CO.PrepareAutoFinishingReagent = function()
    prepareCalls = prepareCalls + 1
    liveReagents[2] = { reagent = { itemID = 246447 }, dataSlotIndex = 9, quantity = 1 }
    return "applied", { skillBonus = 5, itemID = 246447, slotIndex = 2, dataSlotIndex = 9, quantity = 1 }
end
CO.SetStatus = function(_, value) CO.lastStatus = value end
CO.DActionPrint = function() end
CO.RefreshVisibleRowsSoon = function() end
CO.RefreshVisibleRows = function() end
CO.StartRowProgress = function() end
CO.StopRowProgress = function() end
CO.useConcentration = {}
CO.orderIssues = {}

assert(CO:CraftOrderFromRow(order, page, button) == true)
assert(CO.preparedFinisherOrderID == order.orderID)
assert(CO.pendingCraftOrderID == nil)
assert(craftCalls == 0)

-- Rapid clicks during the transaction-settle window are absorbed.
assert(CO:CraftOrderFromRow(order, page, button) == true)
assert(CO.preparedFinisherOrderID == order.orderID)
assert(CO.pendingCraftOrderID == nil)
assert(craftCalls == 0)
assert(prepareCalls == 1, "rapid click reapplied the finishing reagent")

now = now + 0.30
createEnabled = true
assert(CO:CraftOrderFromRow(order, page, button) == true)
assert(CO.preparedFinisherOrderID == order.orderID)
assert(CO.pendingCraftOrderID == order.orderID)
assert(CO.pendingCraftSpellID == order.spellID)
assert(createButtonCalls == 0, "prepared transaction opened Blizzard's own-reagents confirmation")
assert(apiCraftCalls == 1, "prepared transaction was not submitted through the direct crafting API")
assert(#apiCraftReagents == 1 and apiCraftReagents[1].reagent.itemID == 246447,
    "customer-supplied reagents were sent back with the crafter finishing reagent")
assert(craftCalls == 0, "first prepared-finisher submission did not prefer the direct API")
assert(prepareCalls == 1, "staged finisher was recalculated before crafting")

-- A successful order response is not proof that the profession cast began.
-- It must leave the short start watchdog armed.
assert(CO:HandleCraftOrderResponse(0, order.orderID) == true)
assert(not CO:IsCraftSubmissionAcknowledged(order.orderID),
    "server request response incorrectly acknowledged the craft start")

-- A protected API call can return successfully without actually starting a
-- craft. The short acknowledgement watchdog must unblock the same staged
-- transaction and switch the following hardware press to the alternate path.
local startWatchdog
for _, timer in ipairs(scheduled) do
    if timer.delay == 4.0 then startWatchdog = timer.callback end
end
assert(startWatchdog, "craft-start acknowledgement watchdog was not scheduled")
startWatchdog()
assert(CO.pendingCraftOrderID == nil, "unacknowledged craft stayed blocked")
assert(CO.preparedFinisherOrderID == order.orderID, "retry discarded the staged finisher")
assert(CO.preparedFinisherUseEngineOrderID == order.orderID, "retry path did not switch submission method")

assert(CO:CraftOrderFromRow(order, page, button) == true)
assert(craftCalls == 1, "alternate order-view submission was not used on retry")
assert(apiCraftCalls == 1, "retry repeated the silently ignored API path")
assert(prepareCalls == 1, "retry recalculated the staged finisher")

-- A server update can rebuild the same order's transaction between presses.
-- A remembered order ID is not proof that the finisher is still allocated.
CO:ClearPendingCraftAttempt(order.orderID, true)
liveReagents[2] = nil
assert(CO:CraftOrderFromRow(order, page, button) == true)
assert(CO.pendingCraftOrderID == nil and prepareCalls == 2)
assert(apiCraftCalls == 1 and craftCalls == 1, 'crafted after the staged finisher disappeared')
assert(liveReagents[2].reagent.itemID == 246447, 'lost finisher was not restored')

-- Recraft submission must use native slot ownership and prepare unchanged
-- modifications, while retaining the crafter finishing reagent.
now = now + 0.30
order.isRecraft = true
order.outputItemGUID = 'Item-Recraft-Test'
engine.reagentSlotProvidedByCustomer = { [1] = true }
E.Enum = { TradeskillSlotDataType = { ModifiedReagent = 7 } }
transaction.CreateCraftingReagentInfoTblIf = function(_, predicate)
    assert(not predicate({reagentSlotSchematic={dataSlotType=7}}, 1))
    assert(predicate({reagentSlotSchematic={dataSlotType=7}}, 2))
    assert(not predicate({reagentSlotSchematic={dataSlotType=0}}, 3))
    return {
        liveReagents[2],
        {reagent={itemID=222}, dataSlotIndex=4, quantity=1}, -- existing modification
    }
end
local recraftPrepared, recraftCalls = 0, 0
E.Professions = { PrepareRecipeRecraft = function(txn, reagents)
    assert(txn == transaction)
    assert(#reagents == 2 and reagents[2].reagent.itemID == 222)
    table.remove(reagents, 2)
    recraftPrepared = recraftPrepared + 1
end }
E.C_TradeSkillUI.RecraftRecipeForOrder = function(id, guid, reagents, removed, concentration)
    assert(recraftPrepared == 1, 'recraft submitted before preparing item modifications')
    assert(id == order.orderID and guid == order.outputItemGUID)
    assert(removed == nil and concentration == false)
    assert(#reagents == 1 and reagents[1].reagent.itemID == 246447 and reagents[1].dataSlotIndex == 9)
    recraftCalls = recraftCalls + 1
end
assert(CO:CraftOrderFromRow(order, page, button) == true)
assert(recraftCalls == 1 and craftCalls == 1 and apiCraftCalls == 1)

-- If ownership/filtering drops the staged finisher, fail closed: no cast and
-- no progress bar. A raw transaction allocation alone is not sufficient.
CO:ClearPendingCraftAttempt(order.orderID, true)
transaction.CreateCraftingReagentInfoTblIf = function() return {} end
E.Professions.PrepareRecipeRecraft = function() end
assert(CO:CraftOrderFromRow(order, page, button) == false)
assert(CO.pendingCraftOrderID == nil and CO.preparedFinisherOrderID == nil)
assert(recraftCalls == 1 and craftCalls == 1)
assert(CO.lastStatus:find('Finishing reagent is missing', 1, true))

print("Finisher craft staging tests passed.")
