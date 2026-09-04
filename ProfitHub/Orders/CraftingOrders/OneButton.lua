local E = _G.HironCraftProfitCraftingOrdersEnv
if not E then
    E = {}
    _G.HironCraftProfitCraftingOrdersEnv = E
    setmetatable(E, { __index = _G })
end
setfenv(1, E)
if not PT or not CO then return end

local RETRY_DELAY = 0.15
local FLOW_TIMEOUT = 8.0
local EMPTY_LIST_GRACE = 3.0
local EMPTY_REFRESH_POLL = 0.20
local EMPTY_REFRESH_TIMEOUT = 6.0
local EMPTY_REFRESH_THROTTLE = 1.0
local EMPTY_REFRESH_SETTLE = 0.50

local function IsShown(frame)
    return frame and frame.IsShown and frame:IsShown()
end

local function ClickFrame(frame)
    if not frame or type(frame.Click) ~= "function" then return false end
    if frame.IsEnabled and not frame:IsEnabled() then return false end
    return pcall(frame.Click, frame, "LeftButton")
end

local function TryCall(object, methodName, ...)
    local method = object and object[methodName]
    if type(method) ~= "function" then return false end
    return pcall(method, object, ...)
end

local function Now()
    return GetTime and GetTime() or 0
end

function CO:IsOneButtonPersonalEnabled()
    -- Reuse the existing "Queue" checkbox under "Auto on open" so the new
    -- workflow has an obvious opt-out and does not add more panel clutter.
    return self.IsAutoQueueOnOpen and self:IsAutoQueueOnOpen()
end

function CO:GetInteractTargetBindings()
    if type(GetBindingKey) ~= "function" then return {} end

    local keys = { GetBindingKey("INTERACTTARGET") }
    local result, seen = {}, {}
    for _, key in ipairs(keys) do
        if type(key) == "string" and key ~= "" and not seen[key] then
            seen[key] = true
            result[#result + 1] = key
        end
    end
    return result
end

function CO:ApplyOneButtonInteractBindings(proxy)
    if not proxy or not self:IsOneButtonPersonalEnabled() then return false end
    if not self:HasVisibleOrderContext() then return false end

    local applied = false
    for _, key in ipairs(self:GetInteractTargetBindings()) do
        SetOverrideBindingClick(proxy, false, key, HOTKEY_PROXY_NAME, "LeftButton")
        applied = true
    end
    return applied
end

function CO:GetOneButtonOrdersPage()
    local professionsFrame = _G.ProfessionsFrame
    if not professionsFrame then return nil end

    local pageFrame = professionsFrame.OrdersPage
    self:InstallFreshOrderSearchHooks()
    if IsShown(pageFrame) then return pageFrame end

    local tabID = professionsFrame.craftingOrdersTabID
    local tabButton
    if tabID and professionsFrame.TabSystem and professionsFrame.TabSystem.GetTabButton then
        local ok, button = pcall(professionsFrame.TabSystem.GetTabButton, professionsFrame.TabSystem, tabID)
        if ok then tabButton = button end
    end
    if not tabButton and tabID and professionsFrame.GetTabButton then
        local ok, button = pcall(professionsFrame.GetTabButton, professionsFrame, tabID)
        if ok then tabButton = button end
    end

    ClickFrame(tabButton)
    if not IsShown(pageFrame) and tabID then
        TryCall(professionsFrame, "SetTab", tabID, true)
    end

    return IsShown(pageFrame) and pageFrame or nil
end

function CO:PrepareFreshOrderSearch(pageFrame)
    local container = pageFrame and pageFrame.ahuiCustomList
    if not container then return end

    -- CustomList normally holds the last non-empty response to hide the short
    -- empty gap between requests. A deliberate Search must drop that fallback,
    -- otherwise an old row can survive the real server response indefinitely.
    container._lastGoodOrders = nil
    container._lastGoodType = nil
    container._lastOrderCount = 0
    container._allowEmptyOnce = true
    container._orderType = pageFrame.orderType
    container._freshSearchPending = true

    for _, row in ipairs(container.rows or {}) do
        local action = row and row.action
        if action then
            if self.visibleRowButtons then self.visibleRowButtons[action] = nil end
            local key = action.orderID and tostring(action.orderID)
            if key and self.rowButtonsByOrderID and self.rowButtonsByOrderID[key] == action then
                self.rowButtonsByOrderID[key] = nil
            end
        end
        if row and row.Hide then row:Hide() end
    end
end

function CO:InstallFreshOrderSearchHooks()
    local function Wrap(target)
        if not target or target.ahuiFreshOrderSearchWrapped then return end
        if type(target.StartDefaultSearch) ~= "function" then return end

        target.ahuiFreshOrderSearchWrapped = true
        target.ahuiOriginalStartDefaultSearch = target.StartDefaultSearch
        target.StartDefaultSearch = function(pageFrame, ...)
            if CO:IsEnabled() then
                CO:PrepareFreshOrderSearch(pageFrame)
                TryCall(pageFrame, "ClearCachedRequests")
            end
            return target.ahuiOriginalStartDefaultSearch(pageFrame, ...)
        end
    end

    Wrap(_G.ProfessionsCraftingOrderPageMixin)
    if _G.ProfessionsFrame then
        Wrap(ProfessionsFrame.OrdersPage)
    end

    local function HookShowGeneric(target)
        if not target or target.ahuiFreshOrderShowGenericHooked then return end
        if type(target.ShowGeneric) ~= "function" then return end
        target.ahuiFreshOrderShowGenericHooked = true
        hooksecurefunc(target, "ShowGeneric", function(pageFrame)
            CO:MarkFreshOrderSearchComplete(pageFrame)
        end)
    end

    HookShowGeneric(_G.ProfessionsCraftingOrderPageMixin)
    if _G.ProfessionsFrame then
        HookShowGeneric(ProfessionsFrame.OrdersPage)
    end
end

function CO:MarkFreshOrderSearchComplete(pageFrame)
    local container = pageFrame and pageFrame.ahuiCustomList
    if container then container._freshSearchPending = nil end

    if self._oneButtonEmptyRefreshRunning then
        self._oneButtonEmptyRefreshResponseSeen = true
        self._oneButtonEmptyRefreshResponseAt = Now()
        self:ContinueEmptyPersonalOrdersRefresh()
    end
end

function CO:OpenOneButtonPersonalTab(pageFrame)
    local orderTypes = Enum and Enum.CraftingOrderType
    local personalType = orderTypes and orderTypes.Personal
    if not pageFrame or personalType == nil then return false end

    if pageFrame.orderType == personalType then return true end

    local browseFrame = pageFrame.BrowseFrame
    local personalButton = browseFrame and browseFrame.PersonalOrdersButton
    ClickFrame(personalButton)

    if pageFrame.orderType ~= personalType and pageFrame.SetCraftingOrderType then
        local changed = TryCall(pageFrame, "SetCraftingOrderType", personalType)
        if changed then
            TryCall(pageFrame, "ClearCachedRequests")
            TryCall(pageFrame, "StartDefaultSearch")
        end
    end

    return pageFrame.orderType == personalType
end

function CO:GetOneButtonPersonalOrders()
    if not C_CraftingOrders or type(C_CraftingOrders.GetCrafterOrders) ~= "function" then
        return nil, 0
    end

    local ok, orders = pcall(C_CraftingOrders.GetCrafterOrders)
    if not ok or type(orders) ~= "table" then return nil, 0 end

    local personalType = Enum and Enum.CraftingOrderType and Enum.CraftingOrderType.Personal
    local count = 0
    for _, order in ipairs(orders) do
        local fulfilled = type(order) == "table"
            and order.orderID
            and self.fulfilledOrderIDs
            and self.fulfilledOrderIDs[order.orderID]
        if type(order) == "table" and order.orderID
            and (personalType == nil or order.orderType == nil or order.orderType == personalType)
            and not fulfilled
        then
            count = count + 1
        end
    end
    return orders, count
end

function CO:FinishOneButtonPersonalFlow(pageFrame, count)
    self:SelectAllVisibleOrders(pageFrame)
    self._oneButtonFlowRunning = false
    self._oneButtonPreparedForOpen = true
    self._oneButtonRetryScheduled = false

    -- The page was not necessarily visible when its normal OnShow binding
    -- hook ran, so refresh the overrides after the Personal list is ready.
    self.activePageFrame = pageFrame
    self:ApplyTemporaryBinding()
    self:UpdateControlPanel()
    self:SetStatus(string.format(T("COA_ONE_BUTTON_READY", "Personal orders selected: %d."), count or 0))
end

function CO:ScheduleOneButtonPersonalStep(delay)
    if not self._oneButtonFlowRunning or self._oneButtonRetryScheduled then return end
    if not C_Timer or not C_Timer.After then return end

    local token = self._oneButtonFlowToken
    self._oneButtonRetryScheduled = true
    C_Timer.After(delay or RETRY_DELAY, function()
        if CO._oneButtonFlowToken ~= token then return end
        CO._oneButtonRetryScheduled = false
        CO:ContinueOneButtonPersonalFlow()
    end)
end

function CO:ContinueOneButtonPersonalFlow()
    if not self._oneButtonFlowRunning then return end
    if not self:IsOneButtonPersonalEnabled() then
        self:CancelOneButtonPersonalFlow()
        return
    end

    local elapsed = Now() - (self._oneButtonFlowStartedAt or Now())
    if elapsed >= FLOW_TIMEOUT then
        self._oneButtonFlowRunning = false
        self._oneButtonRetryScheduled = false
        self:SetStatus(T("COA_ONE_BUTTON_TIMEOUT", "Could not prepare personal orders automatically."))
        return
    end

    local pageFrame = self:GetOneButtonOrdersPage()
    if not pageFrame or not self:OpenOneButtonPersonalTab(pageFrame) then
        self:ScheduleOneButtonPersonalStep()
        return
    end

    self.activePageFrame = pageFrame
    self:EnsurePageBindingHooks(pageFrame)
    self:EnsureControlPanel(pageFrame)
    self:UpdateControlPanelVisibility(pageFrame)
    self:ApplyTemporaryBinding()

    if pageFrame.ahuiCustomList and pageFrame.ahuiCustomList._freshSearchPending then
        self:ScheduleOneButtonPersonalStep()
        return
    end

    local orders, personalCount = self:GetOneButtonPersonalOrders()
    if not orders then
        self:ScheduleOneButtonPersonalStep()
        return
    end

    if personalCount > 0 then
        self:FinishOneButtonPersonalFlow(pageFrame, personalCount)
        return
    end

    -- An empty result is legitimate, but immediately after changing tabs it
    -- is also how the API represents a request that has not completed yet.
    if elapsed < EMPTY_LIST_GRACE then
        self:ScheduleOneButtonPersonalStep()
        return
    end

    self._oneButtonFlowRunning = false
    self._oneButtonPreparedForOpen = true
    self._oneButtonRetryScheduled = false
    self:ApplyTemporaryBinding()
    self:SetStatus(T("COA_ONE_BUTTON_EMPTY", "There are no personal orders."))
end

function CO:BeginOneButtonPersonalFlow()
    if not self:IsOneButtonPersonalEnabled() or self._oneButtonPreparedForOpen then return end

    self._oneButtonFlowToken = (self._oneButtonFlowToken or 0) + 1
    self._oneButtonFlowStartedAt = Now()
    self._oneButtonFlowRunning = true
    self._oneButtonRetryScheduled = false
    self:ClearSelectedOrders()
    self:SetStatus(T("COA_ONE_BUTTON_OPENING", "Opening personal crafting orders..."))
    self:ScheduleOneButtonPersonalStep(0)
end

function CO:CancelOneButtonPersonalFlow(resetForNextOpen)
    self._oneButtonFlowToken = (self._oneButtonFlowToken or 0) + 1
    self._oneButtonFlowRunning = false
    self._oneButtonRetryScheduled = false
    self._oneButtonEmptyRefreshToken = (self._oneButtonEmptyRefreshToken or 0) + 1
    self._oneButtonEmptyRefreshRunning = false
    self._oneButtonEmptyRefreshScheduled = false
    self._oneButtonEmptyRefreshResponseSeen = false
    self._oneButtonEmptyRefreshResponseAt = nil
    if resetForNextOpen then
        self._oneButtonPreparedForOpen = false
    end
end

function CO:ScheduleEmptyPersonalOrdersRefresh(delay)
    if not self._oneButtonEmptyRefreshRunning or self._oneButtonEmptyRefreshScheduled then return end
    if not C_Timer or not C_Timer.After then return end

    local token = self._oneButtonEmptyRefreshToken
    self._oneButtonEmptyRefreshScheduled = true
    C_Timer.After(delay or EMPTY_REFRESH_POLL, function()
        if CO._oneButtonEmptyRefreshToken ~= token then return end
        CO._oneButtonEmptyRefreshScheduled = false
        CO:ContinueEmptyPersonalOrdersRefresh()
    end)
end

function CO:ContinueEmptyPersonalOrdersRefresh()
    if not self._oneButtonEmptyRefreshRunning then return end

    if self.IsOrderActionInProgress and self:IsOrderActionInProgress() then
        self._oneButtonEmptyRefreshToken = (self._oneButtonEmptyRefreshToken or 0) + 1
        self._oneButtonEmptyRefreshRunning = false
        self._oneButtonEmptyRefreshScheduled = false
        self._oneButtonEmptyRefreshResponseSeen = false
        self._oneButtonEmptyRefreshResponseAt = nil
        return
    end

    local pageFrame = self.activePageFrame or self:FindOrderPageFrame()
    local elapsed = Now() - (self._oneButtonEmptyRefreshStartedAt or Now())
    if not pageFrame or not IsShown(pageFrame) then
        self:CancelOneButtonPersonalFlow()
        return
    end
    local personalType = Enum and Enum.CraftingOrderType and Enum.CraftingOrderType.Personal
    if personalType == nil or pageFrame.orderType ~= personalType then
        self:CancelOneButtonPersonalFlow()
        return
    end

    if not self._oneButtonEmptyRefreshResponseSeen then
        if elapsed >= EMPTY_REFRESH_TIMEOUT then
            self._oneButtonEmptyRefreshRunning = false
            self._oneButtonEmptyRefreshScheduled = false
            local container = pageFrame.ahuiCustomList
            if container then container._freshSearchPending = nil end
            self:SetStatus(T("COA_ONE_BUTTON_TIMEOUT", "Could not refresh personal orders automatically."))
            return
        end
        self:ScheduleEmptyPersonalOrdersRefresh()
        return
    end

    local _, personalCount = self:GetOneButtonPersonalOrders()
    if personalCount > 0 then
        self._oneButtonEmptyRefreshRunning = false
        self._oneButtonEmptyRefreshScheduled = false
        if self.CustomList and self.CustomList.Refresh then
            self.CustomList:Refresh(pageFrame)
        end
        self:SelectAllVisibleOrders(pageFrame)
        self:RefreshVisibleRowsSoon(0.05)
        self:UpdateControlPanel()
        self:SetStatus(string.format(T("COA_ONE_BUTTON_REFRESHED", "New personal orders selected: %d."), personalCount))
        return
    end

    if self.CustomList and self.CustomList.Refresh then
        self.CustomList:Refresh(pageFrame)
    end

    local responseAge = Now() - (self._oneButtonEmptyRefreshResponseAt or Now())
    if responseAge >= EMPTY_REFRESH_SETTLE then
        self._oneButtonEmptyRefreshRunning = false
        self._oneButtonEmptyRefreshScheduled = false
        self:SetStatus(T("COA_ONE_BUTTON_REFRESH_EMPTY", "Personal orders refreshed. No orders found."))
        return
    end

    self:ScheduleEmptyPersonalOrdersRefresh()
end

function CO:StartEmptyPersonalOrdersRefresh(pageFrame)
    -- A delayed post-completion refresh can collide with the next hardware
    -- press. Never clear Blizzard's order cache after a claim/craft/fulfill has
    -- already started; doing so can leave the row marked as claimed while
    -- GetClaimedOrder() is still empty.
    if self.IsOrderActionInProgress and self:IsOrderActionInProgress() then
        return true
    end

    if self._oneButtonEmptyRefreshRunning then
        self:SetStatus(T("COA_ONE_BUTTON_REFRESHING", "Refreshing personal orders..."))
        return true
    end

    local now = Now()
    if self._oneButtonLastEmptyRefreshAt
        and (now - self._oneButtonLastEmptyRefreshAt) < EMPTY_REFRESH_THROTTLE
    then
        return true
    end

    self._oneButtonLastEmptyRefreshAt = now
    self._oneButtonEmptyRefreshToken = (self._oneButtonEmptyRefreshToken or 0) + 1
    self._oneButtonEmptyRefreshStartedAt = now
    self._oneButtonEmptyRefreshRunning = true
    self._oneButtonEmptyRefreshScheduled = false
    self._oneButtonEmptyRefreshResponseSeen = false
    self._oneButtonEmptyRefreshResponseAt = nil
    self:ClearSelectedOrders()
    self:PrepareFreshOrderSearch(pageFrame)
    self:SetStatus(T("COA_ONE_BUTTON_REFRESHING", "Refreshing personal orders..."))

    TryCall(pageFrame, "ClearCachedRequests")
    local requested = TryCall(pageFrame, "StartDefaultSearch")
    if not requested then
        self._oneButtonEmptyRefreshRunning = false
        self:SetStatus(T("COA_ONE_BUTTON_TIMEOUT", "Could not refresh personal orders automatically."))
        return true
    end

    self:ScheduleEmptyPersonalOrdersRefresh(0)
    return true
end

function CO:RefreshPersonalOrdersAfterTerminalAction(pageFrame)
    if not self:IsOneButtonPersonalEnabled() or not C_Timer or not C_Timer.After then
        return false
    end

    pageFrame = pageFrame or self.activePageFrame or self:FindOrderPageFrame()
    local personalType = Enum and Enum.CraftingOrderType and Enum.CraftingOrderType.Personal
    if not pageFrame or personalType == nil or pageFrame.orderType ~= personalType then
        return false
    end

    -- Blizzard transitions from the completed order view back to Browse on
    -- the same event. Let that transition settle, then perform the same fresh
    -- request used for an empty Personal page. The token coalesces the fulfill
    -- response and claimed-order removal when both schedule this repair.
    self._oneButtonTerminalRefreshToken = (self._oneButtonTerminalRefreshToken or 0) + 1
    local token = self._oneButtonTerminalRefreshToken
    C_Timer.After(0.12, function()
        if CO._oneButtonTerminalRefreshToken ~= token then return end
        local currentPage = CO.activePageFrame or pageFrame or CO:FindOrderPageFrame()
        if not currentPage or not IsShown(currentPage) or currentPage.orderType ~= personalType then
            return
        end
        if CO.IsOrderActionInProgress and CO:IsOrderActionInProgress() then
            return
        end
        CO._oneButtonLastEmptyRefreshAt = nil
        CO:StartEmptyPersonalOrdersRefresh(currentPage)
    end)
    return true
end

function CO:HandleEmptyPersonalOrdersHotkey()
    if not self:IsOneButtonPersonalEnabled() then return false end

    local pageFrame = self.activePageFrame or self:FindOrderPageFrame()
    local personalType = Enum and Enum.CraftingOrderType and Enum.CraftingOrderType.Personal
    if not pageFrame or personalType == nil or pageFrame.orderType ~= personalType then return false end
    if self.IsOrderListOpen and not self:IsOrderListOpen(pageFrame) then return false end

    local orders, personalCount = self:GetOneButtonPersonalOrders()
    if not orders then return false end
    if personalCount > 0 then
        -- A new order can already be present in the API while the custom list
        -- and selection still reflect the just-completed order. Rebind the
        -- visible rows, select the current Personal orders and, when possible,
        -- spend this same hardware press on their first action.
        self:ClearSelectedOrders()
        if self.CustomList and self.CustomList.Refresh then
            self.CustomList:Refresh(pageFrame)
        end
        self:SelectAllVisibleOrders(pageFrame)
        self:RefreshVisibleRowsSoon(0.01)
        self:UpdateControlPanel()

        local btn = self:GetQueueButton()
        if btn and self:IsOrderSelected(btn.orderID) then
            self:RunRowButtonAction(btn)
        else
            self:SetStatus(string.format(T("COA_ONE_BUTTON_REFRESHED", "New personal orders selected: %d."), personalCount))
        end
        return true
    end
    return self:StartEmptyPersonalOrdersRefresh(pageFrame)
end

local eventFrame = CreateFrame("Frame")
local function RegisterEvent(eventName)
    pcall(eventFrame.RegisterEvent, eventFrame, eventName)
end

RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
RegisterEvent("ADDON_LOADED")
RegisterEvent("TRADE_SKILL_SHOW")
RegisterEvent("TRADE_SKILL_CLOSE")
RegisterEvent("CRAFTINGORDERS_CRAFTER_ORDERS_UPDATED")
RegisterEvent("CRAFTINGORDERS_UPDATE_PERSONAL_ORDER_COUNTS")
RegisterEvent("CRAFTINGORDERS_UPDATE_ORDER_COUNT")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "Blizzard_Professions" then
            CO:InstallFreshOrderSearchHooks()
        end
        return
    end

    if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        local interactionType = ...
        if CO:IsCraftingOrderInteractionType(interactionType) then
            CO._oneButtonPreparedForOpen = false
            CO:BeginOneButtonPersonalFlow()
        end
        return
    end

    if event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        local interactionType = ...
        if CO:IsCraftingOrderInteractionType(interactionType) then
            CO:CancelOneButtonPersonalFlow(true)
        end
        return
    end

    if event == "TRADE_SKILL_CLOSE" then
        CO:CancelOneButtonPersonalFlow(true)
        return
    end

    if event == "TRADE_SKILL_SHOW" then
        if CO._oneButtonFlowRunning then CO:ContinueOneButtonPersonalFlow() end
        return
    end

    if CO._oneButtonFlowRunning then
        CO:ContinueOneButtonPersonalFlow()
    end
    if CO._oneButtonEmptyRefreshRunning then
        if event == "CRAFTINGORDERS_CRAFTER_ORDERS_UPDATED" then
            CO:MarkFreshOrderSearchComplete(CO.activePageFrame or CO:FindOrderPageFrame())
        end
        CO:ContinueEmptyPersonalOrdersRefresh()
    end
end)

CO:InstallFreshOrderSearchHooks()

-- /reload can happen with the profession window already open.
if CO.atOrderTable and _G.ProfessionsFrame and ProfessionsFrame:IsShown() then
    CO._oneButtonPreparedForOpen = false
    CO:BeginOneButtonPersonalFlow()
end
