local E = _G.HironCraftProfitCraftingOrdersEnv
if not E then return end
setfenv(1, E)
if not PT or not CO then return end

-- The game owns a single crafter-order result buffer. Read each trained child
-- profession in sequence and publish only our complete, character-scoped copy.
-- This module never claims, crafts, releases or fulfils an order.
local function Copy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, entry in pairs(value) do
        if key ~= 'callback' then result[key] = Copy(entry, seen) end
    end
    return result
end

local function Child()
    if C_TradeSkillUI and C_TradeSkillUI.GetProfessionChildSkillLineID then
        local ok, value = pcall(C_TradeSkillUI.GetProfessionChildSkillLineID)
        if ok then return value end
    end
end

local function Later(delay, callback)
    if C_Timer and C_Timer.After then C_Timer.After(delay, callback)
    else callback() end
end

local function CancelCallback(session)
    local callback = session and session.callback
    if callback and type(callback) ~= 'function' and callback.Cancel then
        pcall(callback.Cancel, callback)
    end
    if session then session.callback = nil end
end

function CO:IsPatronExpansionSelected(key)
    local saved = self:GetQueueOptions().patronExpansions
    if type(saved) == 'table' then return saved[key] == true end
    return key == self:GetSelectedProfessionExpansionKey()
end

function CO:SetPatronExpansionSelected(key, checked)
    if key ~= 'midnight' and key ~= 'tww' then return end
    if self:IsCombinedPatronActionBusy() then
        self:SetStatus(T('COA_PATRON_WAIT_ACTION', 'Finish the current order before changing expansions.'))
        self:UpdateQueueSettingWidgets()
        return
    end
    local opts = self:GetQueueOptions()
    local saved = type(opts.patronExpansions) == 'table' and Copy(opts.patronExpansions)
        or { [self:GetSelectedProfessionExpansionKey()] = true }
    saved.df = nil
    saved[key] = checked == true or nil
    if not saved.midnight and not saved.tww then
        self:SetStatus(T('COA_PATRON_CHOOSE_ONE', 'Select at least one patron expansion.'))
        self:UpdateQueueSettingWidgets()
        return
    end
    opts.patronExpansions = saved
    local page = self:FindOrderPageFrame() or self.activePageFrame
    self:CancelCombinedPatronLoad()
    self._autoRanForOpen = false
    self._autoQueueStamp = (self._autoQueueStamp or 0) + 1
    if self.CustomList and page then self.CustomList:ClearScope(page) end
    if self.EnsureOrderSelectionContext then self:EnsureOrderSelectionContext(page) end
    self:UpdateQueueSettingWidgets()
    if self:GetPatronExpansionScope(page) and page.StartDefaultSearch then page:StartDefaultSearch() end
end

function CO:GetSelectedPatronExpansions(page)
    local saved = self:GetQueueOptions().patronExpansions
    if type(saved) ~= 'table' then return end -- Keep the existing single-expansion default.
    local available = self:GetAvailableProfessionExpansions(page, EXPANSION_TWW)
    local result = {}
    for _, option in ipairs(available) do
        if saved[option.key] then result[#result + 1] = option end
    end
    -- A global setting may name an expansion this character has not trained.
    -- Do not silently substitute an expansion the user explicitly excluded.
    return result
end

function CO:GetPatronExpansionScope(page)
    if not page or not Enum or not Enum.CraftingOrderType
        or page.orderType ~= Enum.CraftingOrderType.Npc then return end
    local options = self:GetSelectedPatronExpansions(page)
    if not options then return end
    local keys = {}
    for _, option in ipairs(options) do keys[#keys + 1] = option.key end
    if #keys == 0 then
        for _, key in ipairs({ 'midnight', 'tww' }) do
            if self:IsPatronExpansionSelected(key) then keys[#keys + 1] = key end
        end
    end
    return 'patrons-' .. table.concat(keys, '+'), options
end

local function Identity(page)
    local scope = CO:GetPatronExpansionScope(page)
    if not scope then return end
    return table.concat({ tostring(UnitGUID and UnitGUID('player') or ''),
        tostring(CO:GetActiveBaseProfessionID(page)), scope }, ':')
end

local function Current(session)
    return CO.combinedPatrons == session and Identity(session.page) == session.identity
        and (not session.page.IsShown or session.page:IsShown())
end

function CO:IsCombinedPatronActionBusy()
    if self.IsOrderSubmissionPending and self:IsOrderSubmissionPending() then return true end
    if self.pendingClaimOrderID or self.pendingCraftOrderID or self.pendingFulfillOrderID
        or self.pendingReleaseOrderID or self.progressOrderID then return true end
    local claimed = self.GetClaimedOrder and self:GetClaimedOrder()
    return claimed and not (self.IsOrderUnavailable and self:IsOrderUnavailable(claimed.orderID)) or false
end

function CO:SwitchCombinedPatronChild(childID)
    if Child() == childID then return true end
    if not childID or not C_TradeSkillUI or not C_TradeSkillUI.SetProfessionChildSkillLineID then return false end
    self._patronSwitching = true
    local ok = pcall(C_TradeSkillUI.SetProfessionChildSkillLineID, childID)
    self._patronSwitching = nil
    -- Suppress the ordinary expansion synchronizer: it must not change the
    -- aggregate selection scope, saved setting or queue on a transient switch.
    self.suppressExpansionSyncUntil = CacheNow() + 0.5
    return ok and Child() == childID
end

function CO:CancelCombinedPatronLoad()
    if self.CancelCombinedPatronSelection then self:CancelCombinedPatronSelection() end
    local session = self.combinedPatrons
    if not session then return end
    CancelCallback(session)
    self.combinedPatrons = nil
    -- Do not restore a child after the player has changed base profession.
    if session.loading and session.owner == (UnitGUID and UnitGUID('player'))
        and self:GetActiveBaseProfessionID(session.page) == session.profession
        and not self:IsCombinedPatronActionBusy() then
        self:SwitchCombinedPatronChild(session.originalChild)
    end
end

function CO:GetCombinedPatronOrders(page)
    page = page or self.activePageFrame or self:FindOrderPageFrame()
    if not self:GetPatronExpansionScope(page) then return nil end
    local session = self.combinedPatrons
    if not session or not Current(session) or session.page ~= page or not session.ready then return {} end
    local orders = {}
    for _, order in ipairs(session.orders) do
        if not (self.IsOrderUnavailable and self:IsOrderUnavailable(order.orderID)) then
            orders[#orders + 1] = self.GetEffectiveOrder and self:GetEffectiveOrder(order.orderID, order) or order
        end
    end
    return orders
end

function CO:IsCombinedPatronListReady(page)
    if not self:GetPatronExpansionScope(page or self.activePageFrame) then return true end
    local session = self.combinedPatrons
    return session and Current(session) and session.ready == true or false
end

function CO:IsInactivePatronOrder(order)
    return order and order.hironPatronChildID and Child() ~= order.hironPatronChildID
end

-- Called only from a user's row/queue action. Switching is never followed by
-- protected actions from a timer; the existing live validations still run.
function CO:PrepareCombinedPatronAction(order, page)
    if self.combinedPatronQueue then
        self:SetStatus(T('COA_STATUS_QUEUE_BUILDING', 'Building work order queue...'))
        return false
    end
    if not self:IsCombinedPatronListReady(page) then
        self:SetStatus(T('COA_PATRON_LOADING', 'Loading patron orders from selected expansions...'))
        return false
    end
    if not order or not order.hironPatronChildID then return true end
    if not self:IsInactivePatronOrder(order) then
        return not self._patronActionReadyAt or CacheNow() >= self._patronActionReadyAt
    end
    if self:IsCombinedPatronActionBusy() then return false end
    if not self:SwitchCombinedPatronChild(order.hironPatronChildID) then
        self:SetStatus(T('COA_PATRON_SWITCH_FAILED', 'Could not switch the order profession. Try again.'))
        return false
    end
    if self.InvalidateOrderCaches then self:InvalidateOrderCaches(order.orderID) end
    wipe(self.queuePreparedOrders or {})
    self._patronActionReadyAt = CacheNow() + 0.2
    self:SetStatus(T('COA_PATRON_SWITCH_READY', 'Order expansion selected. Press Action again to continue.'))
    return false
end

local OriginalCancelQueueSelection = CO.CancelQueueSelection

function CO:CancelCombinedPatronSelection()
    local selection = self.combinedPatronQueue
    if not selection then return end
    self.combinedPatronQueue = nil
    OriginalCancelQueueSelection(self)
    if selection.owner == (UnitGUID and UnitGUID('player'))
        and selection.profession == self:GetActiveBaseProfessionID(selection.page)
        and not self:IsCombinedPatronActionBusy() then
        self:SwitchCombinedPatronChild(selection.originalChild)
    end
end

function CO:CancelQueueSelection()
    self:CancelCombinedPatronSelection()
    OriginalCancelQueueSelection(self)
end

function CO:QueueCombinedPatronSelection(knowledgeOnly, mode, page)
    local combined = self.combinedPatrons
    if not combined or not self:IsCombinedPatronListReady(page) or self.queueSelectionRunning then return end
    if self:IsCombinedPatronActionBusy() then
        self:SetStatus(T('COA_PATRON_WAIT_ACTION', 'Finish the current order before changing expansions.'))
        return
    end
    OriginalCancelQueueSelection(self)
    local selection = { page = page, combined = combined, owner = UnitGUID and UnitGUID('player'),
        profession = self:GetActiveBaseProfessionID(page), originalChild = Child(),
        token = self._queueSelectionToken, context = self._orderSelectionContext, selected = 0, unknown = 0 }
    self.combinedPatronQueue = selection
    self:BeginQueueSelectionPublication(selection, page, not knowledgeOnly and not (mode and mode.automatic))
    self.qualityWarmSerial = (self.qualityWarmSerial or 0) + 1
    self.queueReagentPriceCache = {}
    wipe(self.queuePreparedOrders or {})
    self.queuePreparedOrders = self.queuePreparedOrders or {}
    local opts = self:GetQueueSelectionOptions(knowledgeOnly, mode)
    local orders, seen = {}, {}
    for _, order in ipairs(self:GetCombinedPatronOrders(page) or {}) do
        local key = OrderKey(order.orderID)
        if key and not seen[key] then orders[#orders + 1] = order; seen[key] = true end
    end
    -- Read the owned union, not pooled/visible row buttons. Keep each child
    -- contiguous so its recipes, quality and concentration are checked live.
    table.sort(orders, function(a, b)
        if a.hironPatronChildID ~= b.hironPatronChildID then
            return (a.hironPatronExpansionID or 0) > (b.hironPatronExpansionID or 0)
        end
        return tostring(a.orderID) < tostring(b.orderID)
    end)
    self:SetStatus(T('COA_STATUS_QUEUE_BUILDING', 'Building work order queue...'))
    if self.controlPanel and self.controlPanel.selectAllButton then self.controlPanel.selectAllButton:Disable() end

    local function Alive()
        if self.combinedPatronQueue ~= selection then return false end
        if not Current(combined) or self._queueSelectionToken ~= selection.token
            or self._orderSelectionContext ~= selection.context or self:IsCombinedPatronActionBusy() then
            self:CancelCombinedPatronSelection()
            return false
        end
        return true
    end
    local function Finish()
        if not Alive() then return end
        self:SwitchCombinedPatronChild(selection.originalChild)
        self.combinedPatronQueue = nil
        self:FinishQueueWorkOrdersSelection(selection)
        if selection.unknown > 0 then
            self:SetStatus(string.format(T('COA_PATRON_QUEUE_UNKNOWN', '%d orders still lack quality data. Press Queue again to retry.'), selection.unknown))
        end
    end
    local Step
    Step = function(index, retry)
        if not Alive() then return end
        self:UpdateQueueSelectionProgress(selection, index - 1, #orders)
        local order = orders[index]
        if not order then Finish(); return end
        if self:IsOrderSelectedForQueueAnalysis(order.orderID) or (opts.automatic and self:IsOrderManuallyExcluded(order.orderID)) then
            if not self:IsOrderSelectedForQueueAnalysis(order.orderID) then self:SetQueueSkipReason(order, "manual") end
            Later(0.02, function() Step(index + 1, 0) end)
            return
        end
        if self:IsInactivePatronOrder(order) then
            if not self:SwitchCombinedPatronChild(order.hironPatronChildID) then
                selection.unknown = selection.unknown + 1
                Later(0.02, function() Step(index + 1, 0) end)
            else
                Later(0.15, function() Step(index, retry) end)
            end
            return
        end
        -- Clear an "unknown" cached while this order's expansion was inactive.
        -- Preparing the matching order view may itself need another frame.
        if self.InvalidateOrderCaches then self:InvalidateOrderCaches(order.orderID) end
        wipe(self.queuePreparedOrders)
        if order.spellID and C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
            local found, info = pcall(C_TradeSkillUI.GetRecipeInfo, order.spellID)
            if found and info then order.recipeInfo = Copy(info) end
        end
        -- Stage the matching transaction before choosing reagent grades.
        -- Its operation data may arrive on the next frame even though the
        -- child-profession setter has already returned the correct child ID.
        pcall(self.PrepareOrderForQueueAnalysis, self, order, page)
        Later(0.05, function()
            if not Alive() then return end
            if self:IsInactivePatronOrder(order) then Step(index, retry); return end
            local ok, analysis = pcall(self.GetAvailabilityQueueAnalysis, self, order, order.orderType, opts, page)
            if not Alive() then return end
            if not ok then
                selection.unknown = selection.unknown + 1
                self:SetQueueSkipReason(order, "quality_unknown")
            elseif analysis and analysis.queued then
                local marked, result = pcall(self.MarkOrderQueuedForCheckbox, self, order, analysis, page)
                if marked and result then selection.selected = selection.selected + 1
                elseif not marked then selection.unknown = selection.unknown + 1 end
            elseif self:GetRecipeKnownState(order) ~= false
                and self:OrderRequiresConcentrationForQueue(order, page) == nil then
                if (retry or 0) < 3 then Later(0.15, function() Step(index, (retry or 0) + 1) end); return end
                selection.unknown = selection.unknown + 1
            end
            Later(0.02, function() Step(index + 1, 0) end)
        end)
    end
    Later(0.15, function() Step(1, 0) end)
end

function CO:HandleCombinedPatronRequest(page, request)
    if not self:IsEnabled() then return false end
    if self._patronSwitching then return true end
    local scope, options = self:GetPatronExpansionScope(page)
    if not scope or not request or request.orderType ~= page.orderType then
        self:CancelCombinedPatronLoad()
        return false
    end
    local identity = Identity(page)
    -- Install before the first answer, not only after ShowGeneric: leaving
    -- Orders for Recipes during the initial load must cancel that load too.
    if page.HookScript and not page.hironCombinedPatronHideHooked then
        page.hironCombinedPatronHideHooked = true
        page:HookScript('OnHide', function()
            if CO.combinedPatrons and CO.combinedPatrons.page == page then CO:CancelCombinedPatronLoad() end
        end)
    end
    local previous = self.combinedPatrons
    if previous and previous.identity == identity and previous.page == page and Current(previous) then
        if previous.loading then return true end
        if previous.ready and ((tonumber(request.offset) or 0) > 0 or self._patronPageInitializing or self.combinedPatronQueue
            or self:IsCombinedPatronActionBusy()) then
            page.lastRequest, page.expectMoreRows = Copy(request), false
            if page.ShowOrders then page:ShowOrders(0, true) end
            return true
        end
    end
    if self:IsCombinedPatronActionBusy() then
        self:SetStatus(T('COA_PATRON_WAIT_ACTION', 'Finish the current order before changing expansions.'))
        return true
    end
    local send = self.originalRequestCrafterOrders or (C_CraftingOrders and C_CraftingOrders.RequestCrafterOrders)
    local get = self.originalGetCrafterOrders or (C_CraftingOrders and C_CraftingOrders.GetCrafterOrders)
    if not send or not get then return false end
    self:CancelCombinedPatronLoad()
    self.activePageFrame = page
    page.ahuiOrderRequestSerial = (page.ahuiOrderRequestSerial or 0) + 1
    page.ahuiOrderRequestPending = nil
    if page.requestCallback and page.requestCallback.Cancel then page.requestCallback:Cancel() end
    page.requestCallback = nil
    local session = { page = page, identity = identity, profession = self:GetActiveBaseProfessionID(page),
        owner = UnitGUID and UnitGUID('player'), originalChild = Child(),
        orders = {}, seen = {}, loading = true, serial = 0 }
    session.displayChild = options[1] and GetExpansionSkillLineIDForProfession(session.profession, options[1].expansionID)
        or session.originalChild
    for _, option in ipairs(options) do
        if GetExpansionSkillLineIDForProfession(session.profession, option.expansionID) == session.originalChild then
            session.displayChild = session.originalChild
        end
    end
    self.combinedPatrons = session
    page.lastRequest = Copy(request)
    page.expectMoreRows = false
    page.ahuiScopedOrders = { scope = self.CustomList and self.CustomList:ScopeKey(page), orders = {} }
    local container = page.ahuiCustomList
    if container then
        container._freshSearchPending = true
        container._freshSearchStartedAt = GetTime and GetTime() or CacheNow()
    end
    self:SetStatus(T('COA_PATRON_LOADING', 'Loading patron orders from selected expansions...'))

    local function Publish(failed)
        if not Current(session) then return end
        CancelCallback(session)
        session.loading, session.ready = false, not failed
        session.failed = failed == true
        self:SwitchCombinedPatronChild(failed and session.originalChild or session.displayChild)
        if container then container._freshSearchPending = nil; container._allowEmptyOnce = true end
        if failed then
            session.orders = {}
            self:SetStatus(T('COA_PATRON_LOAD_FAILED', 'Could not load all patron expansions. Refresh the list to retry.'))
        elseif #options == 0 then
            self:SetStatus(T('COA_PATRON_NOT_TRAINED', 'The selected patron expansions are not trained for this profession.'))
        else
            self:SetStatus(string.format(T('COA_PATRON_LOADED', 'Patron orders loaded: %d.'), #self:GetCombinedPatronOrders(page)))
        end
        -- Blizzard's helper supplies its private Flat browse-type value.
        if page.ShowOrders then page:ShowOrders(0, true) end
        if self.UpdateQueueSettingWidgets then self:UpdateQueueSettingWidgets() end
    end

    local Fetch
    Fetch = function(index, offset, retry)
        if not Current(session) then return end
        local option = options[index]
        if not option then Publish(false); return end
        local childID = GetExpansionSkillLineIDForProfession(session.profession, option.expansionID)
        if not self:SwitchCombinedPatronChild(childID) then Publish(true); return end
        session.serial = session.serial + 1
        local serial = session.serial
        local answered = false
        local function Retry()
            if not Current(session) or answered or session.serial ~= serial then return end
            answered = true
            CancelCallback(session)
            if (retry or 0) < 2 then Later(0.75, function() Fetch(index, offset, (retry or 0) + 1) end)
            else Publish(true) end
        end
        local query = Copy(request)
        query.offset, query.profession = offset, session.profession
        query.searchFavorites, query.initialNonPublicSearch = request.searchFavorites == true, false
        query.primarySort = { sortType = Enum.CraftingOrderSortType.ItemName, reversed = false }
        query.secondarySort = { sortType = Enum.CraftingOrderSortType.MaxTip, reversed = false }
        local function Answer(result, orderType, displayBuckets, expectMoreRows, responseOffset)
            if not Current(session) or answered or session.serial ~= serial then return end
            if not IsResultOk(result) or orderType ~= page.orderType or displayBuckets or Child() ~= childID
                or (responseOffset ~= nil and tonumber(responseOffset) ~= offset) then Retry(); return end
            local ok, orders = pcall(get)
            if not ok or type(orders) ~= 'table' then Retry(); return end
            answered = true
            session.callback = nil
            local added, consumed = 0, 0
            for _, source in ipairs(orders) do
                consumed = consumed + 1
                local key = source.orderID and tostring(source.orderID)
                if key and not session.seen[key] and (source.orderType == nil or source.orderType == page.orderType) then
                    local order = Copy(source)
                    order.hironPatronExpansionKey, order.hironPatronExpansionID = option.key, option.expansionID
                    order.hironPatronChildID = childID
                    if order.spellID and C_TradeSkillUI.GetRecipeInfo then
                        local found, info = pcall(C_TradeSkillUI.GetRecipeInfo, order.spellID)
                        if found and info then order.recipeInfo = Copy(info) end
                    end
                    session.seen[key] = true
                    session.orders[#session.orders + 1] = order
                    added = added + 1
                end
            end
            -- An empty/repeated page with expectMoreRows must not spin forever.
            if expectMoreRows and (added == 0 or consumed <= offset) then Publish(true); return end
            Later(0.1, function()
                -- GetCrafterOrders is cumulative: Blizzard sets numOrders to
                -- its length and requests the next page at that offset. Do not
                -- add the previous offset again or later pages are skipped.
                if expectMoreRows then Fetch(index, consumed, 0)
                else Fetch(index + 1, 0, 0) end
            end)
        end
        query.callback = C_FunctionContainers and C_FunctionContainers.CreateCallback
            and C_FunctionContainers.CreateCallback(Answer) or Answer
        session.callback = query.callback
        -- Let the child-profession change settle before querying its orders.
        Later(0.1, function()
            if not Current(session) or answered or session.serial ~= serial then return end
            if not pcall(send, query) then Retry(); return end
            if C_Timer and C_Timer.After then Later(8, Retry) end
        end)
    end
    Fetch(1, 0, 0)
    return true
end
