-- Regression coverage for Personal orders arriving while another order is
-- being crafted. A completed order may remain in Blizzard's cached result for
-- a short time; it must not block a fresh search or selection of the new row.
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
local timers = {}
local personalType = 3
local orders = {
    { orderID = 1001, orderType = personalType },
    { orderID = 1002, orderType = personalType },
}

local frame = {
    RegisterEvent = function() end,
    SetScript = function() end,
}
local E = setmetatable({
    PT = {},
    CO = CO,
    T = function(_, fallback) return fallback end,
    OrderKey = function(value) return value and tostring(value) end,
    SameOrderID = function(lhs, rhs)
        return lhs ~= nil and rhs ~= nil and tostring(lhs) == tostring(rhs)
    end,
    GetTime = function() return 100 end,
    Enum = { CraftingOrderType = { Personal = personalType } },
    C_CraftingOrders = {
        GetCrafterOrders = function() return orders end,
    },
    C_Timer = {
        After = function(_, callback)
            table.insert(timers, callback)
        end,
    },
    CreateFrame = function() return frame end,
    hooksecurefunc = function() end,
}, { __index = _G })
_G.HironCraftProfitCraftingOrdersEnv = E

dofile("ProfitHub/Orders/CraftingOrders/OneButton.lua")

CO.fulfilledOrderIDs = { [1001] = true }
local returned, count = CO:GetOneButtonPersonalOrders()
assert(returned == orders)
assert(count == 1, "cached fulfilled order was counted as an available Personal order")

local page = {
    orderType = personalType,
    IsShown = function() return true end,
}
local refreshCalls = 0
local actionCalls = 0
local selected = {}
CO.activePageFrame = page
CO.IsOneButtonPersonalEnabled = function() return true end
CO.IsOrderListOpen = function() return true end
CO.ClearSelectedOrders = function() selected = {} end
CO.CustomList = {
    Refresh = function(_, candidate)
        assert(candidate == page)
        refreshCalls = refreshCalls + 1
    end,
}
CO.SelectAllVisibleOrders = function()
    selected["1002"] = true
end
CO.RefreshVisibleRowsSoon = function() end
CO.UpdateControlPanel = function() end
CO.GetQueueButton = function() return { orderID = 1002 } end
CO.IsOrderSelected = function(_, orderID) return selected[tostring(orderID)] == true end
CO.RunRowButtonAction = function(_, button)
    assert(button.orderID == 1002)
    actionCalls = actionCalls + 1
end
CO.SetStatus = function() end

assert(CO:HandleEmptyPersonalOrdersHotkey() == true)
assert(refreshCalls == 1, "new Personal order did not refresh the visible list")
assert(actionCalls == 1, "the same hardware press did not advance the new Personal order")

local refreshedPage
CO.StartEmptyPersonalOrdersRefresh = function(_, candidate)
    refreshedPage = candidate
    return true
end
assert(CO:RefreshPersonalOrdersAfterTerminalAction(page) == true)
assert(#timers == 1, "terminal refresh was not scheduled")
timers[1]()
assert(refreshedPage == page, "terminal refresh did not target the open Personal page")

print("One-button refresh tests passed.")
