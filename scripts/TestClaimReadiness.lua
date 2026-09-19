-- Regression coverage for the short interval after ClaimOrder succeeds while
-- Blizzard's authoritative GetClaimedOrder result is not populated yet.
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

local CO = {
    rowStates = {},
    orderIssues = {},
    selectedOrders = {},
    useConcentration = {},
}
local timers = {}
local now = 100
local liveClaim
local claimCalls = 0
local E = setmetatable({
    PT = {},
    CO = CO,
    T = function(_, fallback) return fallback end,
    OrderKey = function(value) return value and tostring(value) end,
    SameOrderID = function(lhs, rhs)
        return lhs ~= nil and rhs ~= nil and tostring(lhs) == tostring(rhs)
    end,
    GetTime = function() return now end,
    GetProfessionFromPage = function() return 164 end,
    SafeCall = function(_, callback)
        local ok = pcall(callback)
        return ok
    end,
    C_CraftingOrders = {
        ClaimOrder = function()
            claimCalls = claimCalls + 1
        end,
    },
    C_Timer = {
        After = function(_, callback)
            timers[#timers + 1] = callback
        end,
    },
    Enum = { CraftingOrderType = { Npc = 4 } },
}, { __index = _G })
_G.HironCraftProfitCraftingOrdersEnv = E

dofile("ProfitHub/Orders/CraftingOrders/Actions.lua")

local page = {}
local order = { orderID = 7001, orderState = 1 }
CO.FindOrderPageFrame = function(_, candidate) return candidate end
CO.IsAtUsableCraftingOrderTable = function() return true end
CO.GetRecipeKnownState = function() return true end
CO.GetClaimedOrder = function() return liveClaim end
CO.InvalidateOrderCaches = function() end
CO.SetStatus = function(_, value) CO.lastStatus = value end
CO.RefreshVisibleRows = function() end
CO.RefreshVisibleRowsSoon = function() end
CO.UpdateControlPanel = function() end
CO.IsOrderSelected = function(self, orderID)
    return self.selectedOrders[tostring(orderID)] == true
end

-- A restored knowledge-queue checkbox must not claim an NPC order when the
-- late quality calculation reveals concentration (or remains unknown).
for _, concentrationState in ipairs({ true, "unknown" }) do
    local unsafe = { orderID = 6999, orderState = 1, orderType = 4 }
    CO.selectedOrders["6999"] = true
    CO.useConcentration["6999"] = nil
    CO.currentQueueOrderID = unsafe.orderID
    CO._orderSelectionBucket = { choices = { ["6999"] = { checked = true } } }
    CO.OrderRequiresConcentrationForQueue = function()
        if concentrationState == "unknown" then return nil end
        return concentrationState
    end
    assert(CO:ClaimOrder(unsafe, page) == false)
    assert(claimCalls == 0, "unsafe concentration order reached ClaimOrder API")
    assert(CO.selectedOrders["6999"] == true and CO.currentQueueOrderID == unsafe.orderID,
        "concentration revalidation silently unchecked the order")
    assert(CO._orderSelectionBucket.choices["6999"].checked == true,
        "concentration revalidation erased the saved selection")
end

CO.OrderRequiresConcentrationForQueue = function() return false end

assert(CO:ClaimOrder(order, page) == true)
assert(claimCalls == 1)
assert(CO.pendingClaimOrderID == order.orderID)
assert(#timers == 1)

-- A successful API call alone must not make the cached row craft-ready.
timers[1]()
assert(CO.pendingClaimOrderID == order.orderID)
assert(#timers == 2)

-- The poll releases the next hardware action only after Blizzard exposes the
-- real claimed order.
liveClaim = { orderID = order.orderID, spellID = 12345 }
timers[2]()
assert(CO.pendingClaimOrderID == nil)
assert(CO.rowStates[order.orderID].order == liveClaim)
assert(CO.currentQueueOrderID == order.orderID)

-- Missing bag reagents are transient. They must not create the sticky issue
-- that used to turn every later Tab press into "No available action".
local craftOrder = { orderID = 7002, orderState = 2 }
CO.CanSupplyCrafterReagentsForQueue = function() return false end
CO.orderIssues["7002"] = "old issue"
assert(CO:CraftOrderFromRow(craftOrder, page, {}) == false)
assert(CO.orderIssues["7002"] == nil, "missing reagents permanently blocked the row")
assert(CO.lastStatus == "Cannot craft: missing reagents.")

print("Claim readiness tests passed.")
