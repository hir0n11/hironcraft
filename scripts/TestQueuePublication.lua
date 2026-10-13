-- Real queue dispatch, staged publication and selection memory. No protected
-- action is available: every response and scheduled frame is controlled here.
local CO = { selectedOrders = {}, selectedReagents = {}, useConcentration = {}, rowStates = {} }
local db, scope = { queue = { includeNpc = true } }, 'Player-A:1:4:midnight'
local timers, requests, buffer, remembered, snapshots = {}, {}, {}, {}, {}
local page = { orderType = 4, shown = true, professionInfo = { profession = 1 } }
function page:IsShown() return self.shown end
local function wipe(t) for k in pairs(t) do t[k] = nil end end
local E = setmetatable({ CO = CO, PT = {},
    T = function(_, fallback) return fallback end,
    GetDB = function() return db end, UnitGUID = function() return 'Player-A' end,
    CacheNow = function() return 100 end, GetServerTime = function() return 100 end,
    OrderKey = function(id) return id and tostring(id) end,
    SameOrderID = function(a, b) return tostring(a) == tostring(b) end,
    GetProfessionFromPage = function() return 1 end,
    wipe = wipe, Enum = { CraftingOrderType = { Npc = 4, Personal = 3 }, CraftingOrderResult = { Ok = 0 } },
    C_Timer = { After = function(delay, callback) timers[#timers + 1] = { delay = delay, callback = callback } end },
    C_CraftingOrders = {
        GetCrafterOrders = function() return buffer end,
        RequestCrafterOrders = function(request) requests[#requests + 1] = request end,
    },
}, { __index = _G })
HironCraftProfitCraftingOrdersEnv = E
for _, name in ipairs({ 'State', 'SelectionMemory', 'QueueShopping' }) do
    dofile('Workflow/Orders/CraftingOrders/' .. name .. '.lua')
end
CO.activePageFrame = page
CO.GetOrderSelectionContext = function() return scope, 'Player-A', '1:4:midnight' end
CO.FindOrderPageFrame = function() return page end
CO.GetClaimedOrder = function() return nil end
CO.RefreshVisibleRowsSoon = function() end
CO.GetQueueOptions = function() return db.queue end
CO.GetQueueOrderTypes = function() return { 4 } end
CO.GetAvailabilityQueueAnalysis = function(_, order)
    return { queued = order.orderID ~= 3, profitRule = 'normal', profit = 500, useConcentration = order.orderID == 2 }
end
CO.ApplyQueueReagentModeToOrder = function() return true end
CO.RefreshVisibleRows = function()
    local keys = {}
    for key in pairs(CO.selectedOrders) do keys[#keys + 1] = key end
    table.sort(keys)
    snapshots[#snapshots + 1] = table.concat(keys, ',')
end
local costCalls = 0
CO.BuildShoppingMaterialsForSelectedOrders = function() costCalls = costCalls + 1; return {}, 0 end
CO.GetShoppingMaterialsCostInfo = function() return { text = 'ready' } end
CO.UpdateControlPanel = function() CO:GetSelectedShoppingCostInfo() end
CO.SetStatus = function(_, text) CO.status = text end
CO.CustomList = { AcceptScopeAnswer = function() end }
local function tick()
    table.sort(timers, function(a, b) return a.delay < b.delay end)
    local timer = table.remove(timers, 1)
    assert(timer, 'missing frame'); timer.callback()
end
local function settle()
    for _ = 1, 100 do if not CO.queueSelectionRunning then return end; tick() end
    error('preparation did not finish')
end
local function answer()
    local request = table.remove(requests, 1)
    assert(request, 'missing request'); request.callback(0, 4, false, false, 0)
    return request
end
CO:EnsureOrderSelectionContext(page)
CO.selectedOrders['90'], CO.currentQueueOrderID = true, 90
CO:RememberOrderSelection(90, true, { orderID = 90, spellID = 190 })
for i = 1, 12 do buffer[i] = { orderID = i, spellID = 100 + i, orderType = 4 } end

CO:QueueWorkOrdersSelection()
local firstSession = CO._queueSelectionPublication
local costsBefore = costCalls
assert(CO.selectedOrders['90'] and CO:GetQueuePreparationText() == 'Preparing queue...')
assert(CO:GetSelectedShoppingCostInfo().preparing and costCalls == costsBefore, 'priced an intermediate queue')
assert(CO:CreateShoppingListForSelectedOrders() == false, 'imported an intermediate shopping list')
local firstRequest = answer() -- Only the first four rows are analysed now.
assert(firstSession.pendingChecks['1'] and not firstSession.pendingChecks['12'])
assert(CO.selectedOrders['1'] == nil and CO.selectedOrders['90'], 'exposed partial checks')
assert(CO._orderSelectionBucket.choices['1'] == nil, 'saved an intermediate check')
assert(CO.useConcentration['2'] == nil, 'published a partial concentration choice')
CO:RestoreOrderSelection(page, buffer)
assert(CO.selectedOrders['90'], 'background list refresh changed checks during preparation')
CO:SetOrderSelected(90, false)
assert(CO.selectedOrders['90'], 'manual click modified a locked calculation')
CO:CancelQueueSelection()
assert(CO.selectedOrders['90'] and CO._queueSelectionPublication == nil, 'cancel lost previous checks')
assert(CO._orderSelectionBucket.choices['1'] == nil, 'cancel saved pending checks')

CO:QueueWorkOrdersSelection()
local secondSession = CO._queueSelectionPublication
firstRequest.callback(0, 4, false, false, 0)
assert(CO:FinishQueueWorkOrdersSelection(firstSession) == false, 'old finish published into a new calculation')
assert(CO.queueSelectionRunning and CO._queueSelectionPublication == secondSession)
answer(); settle()
assert(CO.selectedOrders['90'] == nil and CO.selectedOrders['12'] and not CO.selectedOrders['3'])
assert(CO.useConcentration['2'] == true and CO._orderSelectionBucket.choices['12'].checked)
assert(not CO.queueSelectionRunning and CO:GetQueuePreparationText() == nil)
assert(CO:GetSelectedShoppingCostInfo().text == 'ready')
for _, snapshot in ipairs(snapshots) do
    assert(snapshot == '90' or snapshot == '1,10,11,12,2,4,5,6,7,8,9', 'rendered partial checks: ' .. snapshot)
end

-- Even a direct stale finisher cannot write into a different selection scope.
local session = {}
CO:BeginQueueSelectionPublication(session, page, false)
CO:MarkOrderQueuedForCheckbox({ orderID = 91, spellID = 191 }, {}, page)
scope = 'Player-A:1:3:midnight'; CO._orderSelectionContext = scope
assert(CO:FinishQueueWorkOrdersSelection(session) == false)
assert(CO.selectedOrders['91'] == nil)
CO:CancelQueueSelection()
-- A settings change discards the staged result, rather than combining old
-- analysis with newly selected reagent/concentration rules.
session = {}
CO:BeginQueueSelectionPublication(session, page, false)
CO:MarkOrderQueuedForCheckbox({ orderID = 92, spellID = 192 }, {}, page)
CO:SetQueueConcMode('off')
assert(not CO.queueSelectionRunning and CO.selectedOrders['92'] == nil)
assert(CO:FinishQueueWorkOrdersSelection(session) == false)

-- The synchronous fallback also stages checks. Exceptions in one row's
-- analysis or reagent plan must not strand all controls in preparing state.
CO.GetVisibleOrderButtonsSorted = function()
    local buttons = {}; for _, order in ipairs(buffer) do buttons[#buttons + 1] = { order = order } end
    return buttons
end
CO.GetAvailabilityQueueAnalysis = function(_, order)
    if order.orderID == 1 then error('unavailable recipe data') end
    return { queued = order.orderID ~= 3 }
end
CO.ApplyQueueReagentModeToOrder = function(_, order)
    if order.orderID == 2 then error('unavailable allocation data') end
    return true
end
CO:QueueVisibleWorkOrdersSelection()
assert(not CO.queueSelectionRunning and CO._queueSelectionPublication == nil)
assert(CO.selectedOrders['4'] and not CO.selectedOrders['1'] and not CO.selectedOrders['2'])
-- Native preparation can synchronously fire page/settings callbacks. A
-- cancellation inside analysis or allocation must stop the same batch too.
CO.GetAvailabilityQueueAnalysis = function(_, order)
    if order.orderID == 2 then CO:CancelQueueSelection() end
    return { queued = true }
end
CO.ApplyQueueReagentModeToOrder = function() return true end
CO:QueueWorkOrdersSelection(); answer()
assert(not CO.queueSelectionRunning and not CO.selectedOrders['1'] and not CO.selectedOrders['2'],
    'synchronous cancellation published the rest of a batch')
session = {}
CO:BeginQueueSelectionPublication(session, page, false)
CO.ApplyQueueReagentModeToOrder = function() CO:CancelQueueSelection(); return true end
assert(CO:MarkOrderQueuedForCheckbox({ orderID = 93, spellID = 193 }, {}, page) == false)
assert(CO.selectedOrders['93'] == nil and not CO.queueSelectionRunning)
print('Queue publication tests passed: atomic checks, memory, shopping, cancellation and stale scopes.')
