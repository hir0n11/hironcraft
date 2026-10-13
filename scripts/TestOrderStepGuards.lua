-- Guards between the steps of the order workflow. A decline answered from its
-- dialog, a search asked for a moment ago, the automatic queue pass of an
-- opening and a removal that carries no order ID all arrive later than the
-- click or event that caused them, and must look at what is going on by then.
local function noop() end
local function wipe(t) for k in pairs(t) do t[k] = nil end end
local function eq(actual, expected, label)
    assert(actual == expected, (label or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
local now, timers, claimed, listed = 100, {}, nil, {}
local api = { claim = 0, reject = 0, craft = 0 }
local db = { queue = { reagentMode = 'manual' } }
SlashCmdList = {}
local CO = { rowStates = {}, selectedOrders = {}, selectedReagents = {}, useConcentration = {}, orderIssues = {},
    displayReagentsCache = {}, craftingReagentInfoCache = {}, orderCacheRevision = {} }
local function frame(shown)
    return { shown = shown, IsShown = function(self) return self.shown end,
        Show = function(self) self.shown = true end, Hide = function(self) self.shown = false end }
end
local page = frame(true)
page.orderType, page.professionInfo, page.ahuiCustomList = 4, { profession = 1 }, {}
page.BrowseFrame, page.OrderView = frame(true), frame(false)
page.OrderView.SetOrder = function(self, order) self.order = order end
page.OrderView.CraftOrder = function() api.craft = api.craft + 1 end
local searches = 0
page.StartDefaultSearch = function() searches = searches + 1 end
local mixin = { ShowGeneric = noop, ViewOrder = noop, CloseOrder = noop }
local popup
local E = setmetatable({ CO = CO, PT = {}, SlashCmdList = {},
    T = function(_, fallback) return fallback end, GetTime = function() return now end,
    CacheNow = function() return now end, GetDB = function() return db end,
    GetOrderRevision = function() return 0 end, REAGENT_CACHE_TTL = 1,
    OrderKey = function(id) return id and tostring(id) end,
    SameOrderID = function(a, b) return a ~= nil and b ~= nil and tostring(a) == tostring(b) end,
    IsOrderCreated = function(order) return order and order.orderState == 1 end,
    IsOrderClaimed = function(order) return order and order.orderState == 2 end,
    GetProfessionFromPage = function() return 1 end, UnitGUID = function() return 'Player-A' end,
    SafeCall = function(_, fn) return pcall(fn) end, wipe = wipe,
    CreateFrame = function() return { RegisterEvent = noop, SetScript = noop, Show = noop, Hide = noop } end,
    UnitCastingInfo = noop, UnitChannelInfo = noop,
    Enum = { CraftingOrderState = { Created = 1, Claimed = 2 }, CraftingOrderType = { Npc = 4, Personal = 3 },
        CraftingOrderResult = { Ok = 0 }, CraftingOrderReagentSource = { Customer = 1, Crafter = 2 },
        TradeskillSlotDataType = { Reagent = 0, ModifiedReagent = 1 }, CraftingReagentType = { Basic = 1, Finishing = 2 } },
    C_Timer = { After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end },
    C_CraftingOrders = { GetClaimedOrder = function() return claimed end,
        GetCrafterOrders = function() return listed end,
        ClaimOrder = function() api.claim = api.claim + 1 end,
        RejectOrder = function() api.reject = api.reject + 1 end,
        ReleaseOrder = noop, FulfillOrder = noop },
    C_TradeSkillUI = { GetRecipeSchematic = noop },
    StaticPopupDialogs = {},
    StaticPopup_Show = function(which, text, _, data) popup = { which = which, data = data } end,
    ProfessionsCrafterOrderListElementMixin = { Init = noop }, ProfessionsCraftingOrderPageMixin = mixin,
    hooksecurefunc = function(target, name, callback)
        local old = target[name]
        target[name] = function(...) if old then old(...) end; return callback(...) end
    end,
}, { __index = _G })
HironCraftProfitCraftingOrdersEnv = E
for _, file in ipairs({ 'State', 'QualityReagents', 'QueueShopping', 'Actions' }) do
    dofile('Workflow/Orders/CraftingOrders/' .. file .. '.lua')
end
for _, name in ipairs({ 'CreateHotkeyProxy', 'InstallProfitSortHooks', 'ApplyEnabledState', 'ProtectExternalOrderPageSoon',
    'EnsureControlPanel', 'UpdatePageBackground', 'UpdateControlPanelVisibility', 'WarmVisibleOrderQualitySoon',
    'EnsurePageBindingHooks', 'UpdateControlPanel', 'ProtectVisibleRows', 'RefreshVisibleRowsSoon',
    'ReapplyOrderNameFontsAfterProfessionRefresh', 'ReprotectOrderListAfterProfessionRefresh',
    'ApplySelectedReagentsToEngine', 'SetEngineConcentration', 'DActionPrint', 'SetActiveRowButton',
    'DiagnoseRowAction', 'RefreshHoveredRowButtonTooltip' }) do CO[name] = noop end
dofile('Workflow/Orders/CraftingOrders/HooksEvents.lua')
CO.activePageFrame = page
CO.IsEnabled = function() return true end
CO.FindOrderPageFrame = function(_, value) return value or page end
CO.IsAtUsableCraftingOrderTable = function() return true end
CO.GetRecipeKnownState = function() return true end
CO.IsPersonalCraftingOrder = function() return true end
CO.CanSupplyCrafterReagentsForQueue = function() return true end
CO.OrderRequiresConcentrationForQueue = function() return false end
CO.IsOrderReadyForQualityRejection = function() return false end
CO.SetStatus = function(_, value) CO.status = value end
CO.HasSelectedOrders = function() return next(CO.selectedOrders) ~= nil end
CO.GetVisibleButtonForOrder = function() return nil end
CO.StartRowProgress = function(_, _, id) CO.progressActive, CO.progressOrderID = true, id end
CO.StopRowProgress = function() CO.progressActive, CO.progressOrderID = nil, nil end
local redraws, invalidated = 0, {}
CO.RefreshVisibleRows = function() redraws = redraws + 1 end
CO.InvalidateOrderCaches = function(_, id, keep) invalidated[#invalidated + 1] = { id = id, keep = keep } end
HironCraft = { RecordRejectedCraftingOrder = function() return true end }
local function advance(seconds)
    local finish = now + seconds
    for _ = 1, 1000 do
        table.sort(timers, function(a, b) return a.at < b.at end)
        if not timers[1] or timers[1].at > finish then now = finish; return end
        local timer = table.remove(timers, 1); now = timer.at; timer.fn()
    end
    error('unbounded timer loop')
end
local function idle()
    CO.pendingClaimOrderID, CO.pendingCraftOrderID, CO.pendingFulfillOrderID, CO.pendingReleaseOrderID = nil, nil, nil, nil
    CO.progressActive, CO.progressOrderID, CO.terminalAction, CO._removalDuringCraft = nil, nil, nil, nil
    timers = {}
end

-- A decline answered from its dialog obeys the same lock as a click. The
-- dialog stays up for as long as the player likes: by the time it is
-- answered another order may be in the middle of its craft.
local missing = true
CO.ShouldRejectForMissingCustomerReagents = function() return missing end
local personal = { orderID = 40, spellID = 540, orderState = 1, orderType = 3, customerName = 'Buyer-Realm', tipAmount = 9000 * 10000 }
eq(CO:RejectOrder(personal, page), false, 'a large tip asks first')
eq(popup and popup.which, 'HIRONCRAFT_CONFIRM_REJECT_ORDER')
local dialog = E.StaticPopupDialogs.HIRONCRAFT_CONFIRM_REJECT_ORDER
for _, step in ipairs({ 'pendingClaimOrderID', 'pendingCraftOrderID', 'pendingFulfillOrderID', 'pendingReleaseOrderID' }) do
    idle(); CO[step] = 77; CO.status = nil
    dialog.OnAccept(nil, popup.data)
    eq(api.reject, 0, 'the dialog declined an order during ' .. step)
    eq(#timers, 0, 'the dialog asked for a list search during ' .. step)
    eq(CO.status and CO.status:find('Nothing was declined', 1, true) ~= nil, true, 'a refused decline says nothing')
end
idle(); CO.progressActive = true
eq(CO:RejectOrder(personal, page), false, 'declined under a craft in progress')
idle(); CO.terminalAction = { kind = 'fulfill', orderID = 77 }
eq(CO:RejectOrder(personal, page), false, 'declined under a completion in flight')
eq(api.reject, 0)
-- Once that step is over the same answer still stands, and the press declines.
idle()
eq(CO:RejectOrder(personal, page), true, 'an answered decline was lost')
eq(api.reject, 1)
CO.rejectedOrderIDs, missing = {}, false

-- A search asked for a moment ago does not start under a step that began in
-- the meantime; the rows are redrawn instead. A completion whose removal has
-- been seen is over as far as the list goes, and its refresh still searches.
local function refresh(expectSearch, label, force)
    local before, drawn = searches, redraws
    CO:RefreshPageSoon(0.35, force ~= false)
    advance(0.4)
    eq(searches - before, expectSearch and 1 or 0, label)
    eq(redraws - drawn, expectSearch and 0 or 1, label .. ' (rows)')
end
idle(); refresh(true, 'idle search')
refresh(false, 'a search nobody asked for', false)
for _, step in ipairs({ 'pendingClaimOrderID', 'pendingCraftOrderID', 'pendingFulfillOrderID', 'pendingReleaseOrderID' }) do
    idle(); CO[step] = 77
    refresh(false, 'searched during ' .. step)
end
idle(); CO.progressActive = true; refresh(false, 'searched during a craft in progress')
idle(); CO.terminalAction = { kind = 'fulfill', orderID = 77, removalSeen = false }
refresh(false, 'searched under a completion in flight')
CO.terminalAction.removalSeen, CO.pendingFulfillOrderID = true, 77
refresh(true, 'a completion whose removal was seen lost its search')
idle(); page.shown = false; refresh(false, 'searched on a hidden page'); page.shown = true

-- The automatic pass of an opening stays owed while an order is in hand. It
-- would only be refused, and counting it as made left the queue to be built
-- by hand after that order was done.
idle()
local passes = 0
CO.IsAutoQueueOnOpen = function() return true end
CO.QueueWorkOrdersSelection = function(_, _, mode) assert(mode and mode.automatic); passes = passes + 1 end
CO._orderSelectionContext = 'scope'
listed = { { orderID = 1, orderType = 4 } }
claimed = { orderID = 9, spellID = 509, orderState = 2, orderType = 4 }
CO._autoRanForOpen = false
mixin.ShowGeneric(page)
eq(CO._autoQueuePending, nil, 'a claimed order armed the automatic pass and its lock')
eq(CO:IsOrderListReadyForAction(page), true, 'presses were held up for a pass that cannot run')
advance(1)
eq(passes, 0); eq(CO._autoRanForOpen, false, 'a pass that could not run was counted as made')
claimed = nil
mixin.ShowGeneric(page)
eq(CO._autoQueuePending ~= nil, true, 'the owed pass was not armed once the order was done')
advance(0.7)
eq(passes, 1, 'the owed pass was not made'); eq(CO._autoRanForOpen, true)
mixin.ShowGeneric(page); advance(1)
eq(passes, 1, 'the pass was made twice for one opening')
-- Claimed, or the list asked again, between the arming and the pass itself.
for _, case in ipairs({ 'claim', 'step', 'request', 'search' }) do
    CO._autoRanForOpen = false
    mixin.ShowGeneric(page)
    if case == 'claim' then claimed = { orderID = 9, orderState = 2 }
    elseif case == 'step' then CO.pendingClaimOrderID = 9
    elseif case == 'request' then page.ahuiOrderRequestPending = true
    else page.ahuiCustomList._freshSearchPending = true end
    advance(0.7)
    eq(passes, 1, 'the pass ran into: ' .. case); eq(CO._autoRanForOpen, false, 'counted as made: ' .. case)
    claimed, CO.pendingClaimOrderID, page.ahuiOrderRequestPending, page.ahuiCustomList._freshSearchPending = nil, nil, nil, nil
end
mixin.ShowGeneric(page); advance(0.7)
eq(passes, 2, 'the pass was lost for good after a refusal')
CO.IsAutoQueueOnOpen, CO._autoRanForOpen = nil, true

-- An order that disappears under its own craft. The removal has no order ID
-- and looks like a late duplicate of the previous job, so the craft is left
-- alone; when that attempt is given up and nothing is claimed any more, the
-- order is gone and its row must not stay at "Craft" for ever.
local function crafting(id)
    idle()
    claimed = { orderID = id, spellID = 500 + id, orderState = 2, orderType = 4, isFulfillable = false }
    CO.rowStates[id] = { order = claimed, pageFrame = page }
    CO.selectedOrders[tostring(id)], CO.currentQueueOrderID = true, id
    api.craft, CO.status = 0, nil
    eq(CO:CraftOrderFromRow(claimed, page, nil), true, 'craft did not start')
    eq(api.craft, 1); eq(CO.pendingCraftOrderID, id)
end
crafting(21)
claimed = nil
CO:OnEvent('CRAFTINGORDERS_CLAIMED_ORDER_REMOVED')
eq(CO.pendingCraftOrderID, 21, 'a removal without an order ID stopped the craft at once')
eq(CO.progressActive, true)
local before = searches
advance(4.1)
eq(CO.pendingCraftOrderID, nil)
eq(CO.status, 'The order is no longer claimed: it was cancelled or has expired. Refreshing the list.', 'a lost order was reported as a craft that did not start')
eq(CO.rowStates[21].order, nil, 'the claimed snapshot of a lost order was kept')
eq(CO.selectedOrders['21'], nil, 'a lost order stayed in the queue')
eq(CO.currentQueueOrderID, nil)
advance(0.4)
eq(searches - before, 1, 'the list was not asked again after an order was lost')
local action = CO:GetRowAction(21, { orderID = 21, spellID = 521, orderState = 1, orderType = 4 })
eq(action, 'claim', 'the row of a lost order does not follow the fresh list')
-- The same removal while the order is in fact still claimed: a duplicate.
crafting(22)
local kept = claimed
claimed = nil
CO:OnEvent('CRAFTINGORDERS_CLAIMED_ORDER_REMOVED')
claimed = kept
before = searches
advance(4.1)
eq(CO.status, 'Craft did not start. Press Action again.', 'a duplicate removal lost a claimed order')
eq(CO.rowStates[22].order, kept); eq(CO.selectedOrders['22'], true)
advance(1); eq(searches, before, 'a duplicate removal asked for the list')
-- No removal at all: the watchdog says what it always said.
crafting(23)
advance(4.1)
eq(CO.status, 'Craft did not start. Press Action again.')
eq(CO.selectedOrders['23'], true)
-- A removal noted for an earlier attempt does not condemn the next one.
crafting(24)
kept = claimed; claimed = nil
CO:OnEvent('CRAFTINGORDERS_CLAIMED_ORDER_REMOVED')
claimed = kept
CO.pendingCraftOrderID, CO.progressActive, CO.progressOrderID = nil, nil, nil
timers = {}
eq(CO._removalDuringCraft ~= nil, true)
eq(CO:CraftOrderFromRow(claimed, page, nil), true, 'the next attempt did not start')
eq(CO._removalDuringCraft, nil, 'a new attempt inherited the removal noted for the last one')
CO._removalDuringCraft = { orderID = 24, token = CO._craftWatchToken - 1 }
claimed = nil
local cleared, lost = CO:ClearPendingCraftAttempt(24, false)
eq(cleared, true); eq(lost, false, 'the removal of an earlier attempt was held against the next')
eq(CO.selectedOrders['24'], true)
eq(CO._removalDuringCraft, nil, 'a settled removal was kept')
-- The server refuses the craft of an order that is gone.
crafting(25)
claimed = nil
CO:OnEvent('CRAFTINGORDERS_CLAIMED_ORDER_REMOVED')
CO:OnEvent('CRAFTINGORDERS_CRAFT_ORDER_RESPONSE', 7, 25)
eq(CO.pendingCraftOrderID, nil)
eq(CO.status, 'The order is no longer claimed: it was cancelled or has expired. Refreshing the list.')
eq(CO.selectedOrders['25'], nil)
-- A cast that did begin is watched for 30 seconds; the order can go then too.
crafting(27)
CO:MarkCraftSubmissionAcknowledged(27)
claimed = nil
CO:OnEvent('CRAFTINGORDERS_CLAIMED_ORDER_REMOVED')
advance(4.1)
eq(CO.pendingCraftOrderID, 27, 'a craft that had begun was given up after 4 seconds')
advance(26)
eq(CO.pendingCraftOrderID, nil)
eq(CO.status, 'The order is no longer claimed: it was cancelled or has expired. Refreshing the list.',
    'the last watchdog reported a lost order as a craft that did not start')
eq(CO.selectedOrders['27'], nil)
-- A crafted order is not lost, whatever was noted while it was being made.
crafting(26)
kept = claimed; claimed = nil
CO:OnEvent('CRAFTINGORDERS_CLAIMED_ORDER_REMOVED')
claimed = kept; kept.isFulfillable = true
eq(CO:MarkOrderCraftedReady(26), true)
eq(CO._removalDuringCraft, nil); eq(CO.selectedOrders['26'], true)
idle(); claimed = nil

-- A craft that cannot start says why, also when it is the order's expansion
-- or another order that stands in the way.
local order = { orderID = 31, spellID = 531, orderState = 2, orderType = 4, isFulfillable = false }
claimed = order
CO.IsInactivePatronOrder = function() return true end
local engine, reason = CO:GetOrderEngine(page, order)
eq(engine, nil); eq(reason, "The order's expansion is not selected. Press Action again.")
CO.status = 'stale'
eq(CO:CraftOrderFromRow(order, page, nil), false)
eq(CO.status, "The order's expansion is not selected. Press Action again.", 'a craft that did not start cleared the status line')
CO.IsInactivePatronOrder = nil
CO.pendingClaimOrderID = 32
engine, reason = CO:GetOrderEngine(page, order)
eq(engine, nil); eq(reason, 'Another order is being worked on. Finish it first.')
CO.pendingClaimOrderID = nil
eq(CO:GetOrderEngine(page, order), page.OrderView, 'the engine of the claimed order is refused')
claimed = nil

-- The exact reason for a row that has to wait comes before the general one.
local row = { orderID = 1, spellID = 501, orderState = 1, orderType = 4 }
local function waiting() local _, text = CO:GetRowAction(1, row); return text end
idle()
CO.queueSelectionRunning = true
eq(waiting(), 'Wait for the order list and queue calculation to finish.')
CO.combinedPatronQueue = {}
eq(waiting(), 'Building work order queue...', 'the combined queue hides behind the general reason')
CO.queueSelectionRunning, CO.combinedPatronQueue = nil, nil
CO.IsCombinedPatronListReady = function() return false end
CO.combinedPatrons = { loading = true, page = page }
eq(waiting(), 'Loading patron orders from selected expansions...', 'the patron load hides behind the general reason')
CO.combinedPatrons = { loading = false, ready = false, page = page }
eq(waiting(), 'Wait for the order list and queue calculation to finish.', 'a list that is not loading says it is')
CO.combinedPatrons, CO.IsCombinedPatronListReady = nil, nil

-- The game answers every expansion switch of the combined list with a list
-- update. The reasons the queue pass has just noted are kept through its own
-- switches, and dropped on an update of any other origin.
local function listUpdate()
    invalidated = {}
    CO:OnEvent('TRADE_SKILL_LIST_UPDATE')
    eq(#invalidated, 1); eq(invalidated[1].id, nil)
    return invalidated[1].keep == true
end
eq(listUpdate(), false, 'an ordinary list update kept the queue reasons')
CO.combinedPatronQueue = {}
eq(listUpdate(), true, 'a switch of the queue pass dropped its reasons')
CO.combinedPatronQueue = nil
CO._patronSwitchSettlesAt = now + 0.5
eq(listUpdate(), true, 'the answer to the last switch dropped the reasons')
now = now + 0.6
eq(listUpdate(), false, 'a later list update kept the queue reasons')

-- The identity of an order is asked for with every row at every refresh: it
-- is kept up to date in place, and copied only for the caller that keeps it.
local identity = { orderID = 51, customerName = 'Buyer-Realm', spellID = 551, isRecraft = true }
eq(CO:RememberOrderIdentity(identity), nil, 'a copy was made for a caller that does not keep it')
local saved = CO.rejectionReagentSnapshots['51'].order
eq(saved.customerName, 'Buyer-Realm')
CO:RememberOrderIdentity({ orderID = 51, customerName = ' ', isRecraft = false, itemID = 7 })
eq(CO.rejectionReagentSnapshots['51'].order, saved, 'the saved identity was rebuilt instead of updated')
eq(saved.customerName, 'Buyer-Realm', 'a blank name erased a known one')
eq(saved.isRecraft, false); eq(saved.itemID, 7); eq(saved.spellID, 551)
local copy = CO:RememberOrderIdentity(identity, true)
eq(copy ~= saved and copy.customerName == 'Buyer-Realm' and copy.itemID == 7 and copy.isRecraft == true, true, 'the kept copy is not a copy')
copy.customerName = 'changed'
eq(saved.customerName, 'Buyer-Realm', 'the kept copy shares the saved identity')
collectgarbage(); collectgarbage('stop')
local memory = collectgarbage('count')
for _ = 1, 2000 do CO:RememberOrderIdentity(identity) end
local grown = collectgarbage('count') - memory
collectgarbage('restart')
eq(grown < 8, true, 'looking at a row still makes tables: ' .. grown .. ' KB for 2000 rows')
now = now + 301
CO:RememberOrderIdentity({ orderID = 51, spellID = 551 })
eq(CO.rejectionReagentSnapshots['51'].order ~= saved and CO.rejectionReagentSnapshots['51'].order.customerName == nil, true,
    'an expired identity was reused')
-- The sweep of old entries runs once a minute; an entry that expires between
-- two sweeps is not used either.
CO:RememberOrderIdentity({ orderID = 52, customerName = 'Old-Realm', spellID = 552 })
now = now + 250
CO:RememberOrderIdentity({ orderID = 53, customerName = 'Other-Realm', spellID = 553 })
eq(CO.rejectionReagentSnapshots['52'].order.customerName, 'Old-Realm')
now = now + 51
eq(CO:RememberOrderIdentity({ orderID = 52, spellID = 552 }, true).customerName, nil, 'an identity that expired between sweeps was reused')

-- The real cache reset: one order's reason, all of them, or none.
do
    local core = setmetatable({ wipe = wipe, GetTime = function() return now end,
        HironCraftProfit = {}, C_CraftingOrders = {}, C_TradeSkillUI = {} }, { __index = _G })
    HironCraftProfitCraftingOrdersEnv = core
    dofile('Workflow/Orders/Core/CraftingOrders_Core.lua')
    HironCraftProfitCraftingOrdersEnv = E
    local real = core.CO
    local function reasons() real.queueSkipReasons = { ['1'] = { code = 'profit' }, ['2'] = { code = 'quality' } } end
    reasons(); real:InvalidateOrderCaches(nil, true)
    eq(real.queueSkipReasons['1'] ~= nil and real.queueSkipReasons['2'] ~= nil, true, 'kept reasons were dropped')
    real:InvalidateOrderCaches()
    eq(next(real.queueSkipReasons), nil, 'a full reset kept the reasons')
    reasons(); real:InvalidateOrderCaches(1, true)
    eq(real.queueSkipReasons['1'] == nil and real.queueSkipReasons['2'] ~= nil, true, 'the reset of one order is not its own')
end

print('Order step guards passed: decline from the dialog, delayed search, owed automatic pass, order lost under its craft, refusal reasons, queue reasons and order identity.')
