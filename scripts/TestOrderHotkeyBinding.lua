-- The configured order hotkey must be restored from page lifecycle/row setup;
-- moving the mouse over an action button must not be required.
if not setfenv then
    function setfenv(fn, env)
        if type(fn) == 'number' then fn = debug.getinfo(fn + 1, 'f').func end
        for i = 1, 100 do
            local name = debug.getupvalue(fn, i)
            if not name then break end
            if name == '_ENV' then
                debug.upvaluejoin(fn, i, function() return env end, 1)
                break
            end
        end
        return fn
    end
end

local CO = { visibleRowButtons = {}, orderIssues = {} }
local E = setmetatable({
    PT = {},
    CO = CO,
    SlashCmdList = {},
    GetTime = function() return 100 end,
    wipe = function(tbl) for key in pairs(tbl) do tbl[key] = nil end end,
}, { __index = _G })
_G.HironCraftProfitCraftingOrdersEnv = E
dofile('ProfitHub/Orders/CraftingOrders/QualityReagents.lua')
dofile('ProfitHub/Orders/CraftingOrders/State.lua')

local bindingCalls = 0
CO.ApplyTemporaryBinding = function()
    bindingCalls = bindingCalls + 1
    CO.bindingOwner = {}
    return true
end

local page = {
    ahuiCraftingOrdersBindingHooked = true,
    IsShown = function() return true end,
}
CO:EnsurePageBindingHooks(page)
assert(bindingCalls == 1, 'an already visible hooked page did not restore its hotkey')
assert(CO.activePageFrame == page, 'binding recovery did not restore the active page')

CO:EnsurePageBindingHooks(page)
assert(bindingCalls == 1, 'an intact binding was needlessly rebuilt')

CO.bindingOwner = nil
CO.EnsurePageBindingHooks = function() end
CO.EnsureControlPanel = function() end
CO.UpdateControlPanelVisibility = function() end
CO.RefreshVisibleRowsSoon = function() end
CO.WarmVisibleOrderQualitySoon = function() end
CO:SetOrderTablePresence(true, page)
assert(bindingCalls == 2, 'crafting-table presence did not apply the hotkey')

print('Order hotkey binding tests passed.')
