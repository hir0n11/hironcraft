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
local createButtonCalls = 0
local prepareCalls = 0
local createEnabled = false
local engine = {
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
order = { orderID = 77, spellID = 1234, isRecraft = false }

CO.GetEffectiveOrder = function(_, _, fallback) return fallback end
CO.FindOrderPageFrame = function(_, candidate) return candidate end
CO.IsAtUsableCraftingOrderTable = function() return true end
CO.GetRecipeKnownState = function() return true end
CO.CanSupplyCrafterReagentsForQueue = function() return true end
CO.GetClaimedOrder = function() return order end
CO.GetOrderEngine = function() return engine end
CO.ApplySelectedReagentsToEngine = function() end
CO.SetEngineConcentration = function() end
CO.PrepareAutoFinishingReagent = function()
    prepareCalls = prepareCalls + 1
    if prepareCalls == 1 then
        return "applied", { skillBonus = 20 }
    end
    return "not_needed"
end
CO.SetStatus = function(_, value) CO.lastStatus = value end
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
assert(createButtonCalls == 1, "prepared transaction did not use Blizzard's Create button")
assert(craftCalls == 0, "prepared transaction fell back to the rebuilding view method")

print("Finisher craft staging tests passed.")
