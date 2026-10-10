-- Real loader, selection memory, queue dispatch, shopping aggregation and row
-- action entry point. All server buffers and callbacks are intentionally fake.
local function noop() end
local function eq(actual, expected, label)
    assert(actual == expected, (label or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
local function wipe(value) for key in pairs(value) do value[key] = nil end end
local clock, character, profession, child = 10000000, 'Player-A', 1, 2907
local timers, requests, buffer, published, switches = {}, {}, {}, {}, {}
local db = { queue = { minProfitCopper = 100, knowledgeIgnoreProfit = true } }
local trained = { { professionID = 2907, maxSkillLevel = 100 }, { professionID = 2872, maxSkillLevel = 100 } }
local page = { orderType = 4, professionInfo = { profession = 1, professionID = 2907 }, shown = true,
    ahuiCustomList = {} }
function page:IsShown() return self.shown end
function page:HookScript(event, callback) self[event] = callback end
local CO = { activePageFrame = page, selectedOrders = {}, selectedReagents = {}, useConcentration = {},
    rowStates = {}, orderIssues = {}, visibleRowButtons = {}, fulfilledOrderIDs = {} }
local E = setmetatable({ CO = CO, PT = {}, SlashCmdList = {},
    GetDB = function() return db end, CacheNow = function() return clock end,
    UnitGUID = function() return character end, GetServerTime = function() return clock end,
    T = function(_, fallback) return fallback end, wipe = wipe,
    OrderKey = function(id) return id and tostring(id) end,
    SameOrderID = function(a, b) return tostring(a) == tostring(b) end,
    Enum = { CraftingOrderType = { Npc = 4, Personal = 3, Public = 1, Guild = 2 },
        CraftingOrderResult = { Ok = 0 }, CraftingOrderSortType = { ItemName = 1, MaxTip = 2 } },
    EXPANSION_MIDNIGHT = 11, EXPANSION_TWW = 10, EXPANSION_DF = 9, EXPANSION_DEFAULT_KEY = 'midnight',
    EXPANSION_OPTIONS = {
        { key = 'midnight', expansionID = 11, fallback = 'Midnight' },
        { key = 'tww', expansionID = 10, fallback = 'TWW' },
        { key = 'df', expansionID = 9, fallback = 'DF' },
    },
    TRADE_SKILL_LINE_IDS_BY_EXPANSION = { [1] = { [11] = 2907, [10] = 2872 }, [2] = { [11] = 2906, [10] = 2871 } },
    C_Timer = { After = function(delay, callback) timers[#timers + 1] = { at = clock + delay, callback = callback } end },
    C_FunctionContainers = { CreateCallback = function(callback)
        return setmetatable({ Cancel = function(self) self.cancelled = true end },
            { __call = function(self, ...) if not self.cancelled then callback(...) end end })
    end },
    C_TradeSkillUI = {
        GetBaseProfessionInfo = function() return { profession = profession } end,
        GetChildProfessionInfos = function() return trained end,
        GetProfessionChildSkillLineID = function() return child end,
        SetProfessionChildSkillLineID = function(id) child = id; switches[#switches + 1] = id end,
        GetRecipeInfo = function(id) return { name = 'Recipe ' .. id, learned = true } end,
    },
    C_CraftingOrders = {
        GetCrafterOrders = function() return buffer end,
        RequestCrafterOrders = function(request) requests[#requests + 1] = { query = request, child = child } end,
        ClaimOrder = function() error('background claim') end,
        FulfillOrder = function() error('background fulfil') end,
    },
    GetRewardItemID = function(reward) return reward.itemID end,
    IsKnowledgePointRewardItem = function(id) return id == 900 end,
    IsCrafterProvidedReagent = function(entry) return entry.crafter == true end,
    IsCustomerProvidedReagent = function(entry) return entry.customer == true end,
    GetItemInfo = function(id) return 'Item ' .. id end,
}, { __index = _G })
HironCraftProfitCraftingOrdersEnv = E
for _, file in ipairs({ 'State', 'SelectionMemory', 'QualityReagents', 'ExpansionQuest', 'QueueShopping', 'CombinedPatrons', 'Actions' }) do
    dofile('Workflow/Orders/CraftingOrders/' .. file .. '.lua')
end
CO.IsEnabled = function() return true end
CO.FindOrderPageFrame = function() return page end
CO.GetClaimedOrder = function() return nil end
CO.IsOrderFulfilled = function(_, id) return CO.fulfilledOrderIDs[tostring(id)] == true end
CO.SetStatus = function(_, value) CO.status = value end
CO.UpdateQueueSettingWidgets, CO.RefreshVisibleRows, CO.UpdateControlPanel = noop, noop, noop
CO.CustomList = { ScopeKey = function(_, p) return '1:' .. p.orderType .. ':' .. tostring(CO:GetPatronExpansionScope(p)) end }
CO.IsActionSortRequest, CO.IsProfitSortRequest = function() return false end, function() return false end
CO.MaybePinPendingToFront = function(_, orders) return orders end
CO:InstallProfitSortHooks()
function page:ShowOrders()
    published = E.C_CraftingOrders.GetCrafterOrders()
    self.ahuiScopedOrders = { scope = CO.CustomList:ScopeKey(self), orders = published }
end
local function tick()
    assert(#timers > 0, 'no scheduled work')
    table.sort(timers, function(a, b) return a.at < b.at end)
    local timer = table.remove(timers, 1)
    clock = timer.at
    timer.callback()
end
local function nextRequest()
    local limit = 100
    while #requests == 0 and #timers > 0 and limit > 0 do tick(); limit = limit - 1 end
    assert(#requests > 0, 'expected request; status=' .. tostring(CO.status))
    return table.remove(requests, 1)
end
local function answer(rows, more, result)
    local request = nextRequest()
    buffer = rows
    request.query.callback(result or 0, 4, false, more == true, request.query.offset, true)
    return request
end
local function settle()
    for _ = 1, 100 do
        if CO.combinedPatrons and not CO.combinedPatrons.loading then return end
        tick()
    end
    error('load never settled')
end
local function begin()
    local request = { orderType = page.orderType, profession = profession, forCrafter = true, offset = 0 }
    return CO:HandleCombinedPatronRequest(page, request)
end
local function order(id, profit, itemID, quantity)
    return { orderID = id, spellID = id + 100, orderType = 4, profit = profit or 500, minQuality = 0,
        materials = { { itemID = itemID or 1000, quantity = quantity or 4, crafter = true, qualityTier = 1 } } }
end

-- No surprise change for existing users, or for non-patron tabs.
eq(begin(), false, 'unconfigured default')
eq(CO:IsPatronExpansionSelected('midnight'), true)
eq(CO:IsPatronExpansionSelected('tww'), false)
db.queue.patronExpansions = { midnight = true, tww = true }
for _, tab in ipairs({ 1, 2, 3 }) do page.orderType = tab; eq(begin(), false, 'other tab') end
page.orderType = 4

-- A complete union, deep copies, sequential requests and pagination.
eq(begin(), true)
eq(CO:IsCombinedPatronListReady(page), false)
eq(#E.C_CraftingOrders.GetCrafterOrders(), 0, 'no partial API view')
CO:CreateShoppingListForSelectedOrders() -- Must stop before touching ShoppingList.
local first = order(1)
eq(answer({ first }, true).child, 2907, 'first expansion')
eq(#E.C_CraftingOrders.GetCrafterOrders(), 0, 'no partial union after first page')
first.materials[1].quantity = 999 -- Blizzard may reuse/mutate its result objects.
local nextPage = answer({ order(1), order(2) })
eq(nextPage.query.offset, 1, 'pagination offset')
eq(nextPage.child, 2907)
eq(answer({ order(3), order(4, -500) }).child, 2872, 'second expansion')
settle()
eq(#published, 4, 'merged and deduplicated')
eq(published[1].materials[1].quantity, 4, 'owned deep snapshot')
eq(published[3].hironPatronExpansionKey, 'tww')
eq(child, 2907, 'restored original child')
eq(CO:OrderMatchesSelectedProfessionExpansion(published[3], false), true, 'both expansions match queue')
CO.fulfilledOrderIDs['4'] = true
eq(#E.C_CraftingOrders.GetCrafterOrders(), 3, 'completed order not resurrected')
CO.fulfilledOrderIDs['4'] = nil

-- A single selection context spans child switches; old manual exclusions
-- migrate without copying another character, profession or personal tab.
db.orderSelections = { [character] = {
    ['1:4:midnight'] = { choices = { ['1'] = { checked = false, updatedAt = clock, spellID = 101 } } },
    ['1:3:midnight'] = { choices = { ['2'] = { checked = false, updatedAt = clock, spellID = 102 } } },
} }
CO._orderSelectionContext = nil
CO:EnsureOrderSelectionContext(page)
eq(CO._orderSelectionBucket.choices['1'].checked, false, 'manual exclusion migration')
eq(CO._orderSelectionBucket.choices['2'], nil, 'personal choices isolated')
local context = CO:GetOrderSelectionContext(page)
child = 2872
eq(CO:GetOrderSelectionContext(page), context, 'scope independent of child')
child = 2907

-- Existing automatic rules on the complete union, without another server
-- request that would overwrite the single shared API buffer.
CO.GetVisibleOrderButtonsSorted = function()
    local buttons = {}
    wipe(CO.visibleRowButtons)
    for _, value in ipairs(published) do
        local button = { orderID = value.orderID, order = value, pageFrame = page, IsShown = function() return true end }
        buttons[#buttons + 1] = button; CO.visibleRowButtons[button] = true
    end
    return buttons
end
CO.GetOrderProfitInfo = function(_, value) return { profit = value.profit } end
CO.PrepareOrderForQueueAnalysis = function() return false end
CO.CanSupplyCrafterReagentsForQueue = function() return true end
CO.OrderRequiresConcentrationForQueue = function() return false end
CO.GetOrderQualityInfo = function() return { quality = 5 } end
CO.ApplyQueueReagentModeToOrder = function() return true end
CO.GetOrderActionAvailabilitySortRank = function() return 1 end
CO:RestoreOrderSelection(page, published)
CO:QueueWorkOrdersSelection(false, { automatic = true, includeProfit = true })
eq(CO.selectedOrders['1'], nil, 'manual exclusion retained')
eq(CO.selectedOrders['2'], true)
eq(CO.selectedOrders['3'], true, 'inactive expansion auto-selected')
eq(CO.selectedOrders['4'], nil, 'negative profit excluded')
eq(#requests, 0, 'selection uses union, not another request')

-- One global inventory reservation, not one subtraction per expansion.
CO.BuildDisplayReagents = function(_, value) return value.materials end
CO.GetSelectedReagentForEntry = function() return nil end
CO.GetItemCountForShopping = function() return 3 end
local materials, count = CO:BuildShoppingMaterialsForSelectedOrders()
eq(count, 2)
eq(#materials, 1)
eq(materials[1].quantity, 5, 'two orders need 8, bag has 3 once')

-- Only a user action switches the target child and enters the old action
-- path. Pending operations prevent both refresh switches and setting changes.
CO.SetActiveRowButton = noop
local manual, claims = false, 0
CO.GetRowAction = function(_, _, value)
    eq(child, value.hironPatronChildID, 'live action uses correct profession')
    return 'claim', 'Claim', value, true
end
CO.ClaimOrder = function() assert(manual, 'claim without player input'); claims = claims + 1 end
manual = true
CO:RunRowButtonAction({ orderID = 3, order = published[3], pageFrame = page })
eq(claims, 0, 'switch click does not craft or claim')
clock = clock + 0.3
CO:RunRowButtonAction({ orderID = 3, order = published[3], pageFrame = page })
manual = false
eq(child, 2872)
eq(claims, 1)
eq(CO:GetOrderSelectionContext(page), context)
CO.pendingCraftOrderID = 3
local switchCount = #switches
eq(begin(), true)
eq(#switches, switchCount, 'do not switch during a craft')
CO:SetPatronExpansionSelected('tww', false)
eq(db.queue.patronExpansions.tww, true, 'no scope change during craft')
CO.pendingCraftOrderID = nil

-- A delayed profession-page Init must reuse the complete union rather than
-- recursively reload both expansions after every internal child switch.
CO._patronPageInitializing = true
eq(begin(), true)
eq(#requests, 0, 'delayed Init does not start another load')
CO._patronPageInitializing = nil

-- Closed/changed scopes ignore even callbacks delivered after cancellation.
begin()
local stale = nextRequest()
page.shown = false
page:OnHide()
buffer = { order(99) }
stale.query.callback(0, 4, false, false)
eq(CO.combinedPatrons, nil, 'closed page cancelled before first answer')
page.shown = true
begin()
stale = nextRequest()
profession, page.professionInfo.profession = 2, 2
stale.query.callback(0, 4, false, false)
eq(CO.combinedPatrons.ready, nil, 'profession changed')
CO:CancelCombinedPatronLoad()
profession, page.professionInfo.profession, child = 1, 1, 2907
begin()
stale = nextRequest()
character = 'Player-B'
stale.query.callback(0, 4, false, false)
eq(CO.combinedPatrons.ready, nil, 'character changed')
CO:CancelCombinedPatronLoad()
character = 'Player-A'

-- Failed second expansion must not expose a successful first one. Retries
-- are bounded; a later refresh can start a completely new successful load.
begin()
answer({ order(1) })
for _ = 1, 3 do answer({}, false, 7) end
settle()
eq(CO.combinedPatrons.ready, false)
eq(#published, 0, 'failed load is not a partial list')
CO:CreateShoppingListForSelectedOrders()
begin()
answer({ order(5) }); answer({ order(6) }); settle()
eq(#published, 2, 'refresh after failure')

-- Missing callbacks time out, and callback closures cannot publish stale data.
begin()
nextRequest()
for _ = 1, 2 do
    local retry = nextRequest()
    eq(retry.child, 2907, 'timeout retry child')
end
settle()
eq(CO.combinedPatrons.ready, false, 'bounded timeout')

-- Single configured expansion and settings valid on a less-trained character.
db.queue.patronExpansions = { tww = true }
child = 2907
begin(); eq(answer({ order(7) }).child, 2872); settle()
eq(#published, 1)
eq(child, 2872, 'single expansion stays active')
eq(#requests, 0)
CO:SetPatronExpansionSelected('tww', false)
eq(db.queue.patronExpansions.tww, true, 'at least one selected')
trained = { { professionID = 2907, maxSkillLevel = 100 } }
eq(#CO:GetSelectedPatronExpansions(page), 0, 'do not substitute an excluded expansion')
begin(); settle()
eq(#published, 0, 'untrained selection has no orders')
eq(#requests, 0, 'no request for an untrained profession')

print('Combined patrons passed: sequential/paged union, snapshots, automatic rules, manual exclusions, shared inventory, manual actions, scope cancellation, failures/timeouts and settings.')
