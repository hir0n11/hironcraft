local E = _G.HironCraftProfitCraftingOrdersEnv
if not E then
    E = {}
    _G.HironCraftProfitCraftingOrdersEnv = E
    setmetatable(E, { __index = _G })
end
setfenv(1, E)
if not PT or not CO then return end

function CO:BuildHironCraftProfitOrderTable(pageFrame)
    if self.CustomList and self.CustomList._listActive then return false end
    if not pageFrame or not pageFrame.BrowseFrame or not pageFrame.BrowseFrame.OrderList then return false end
    if not CreateTableBuilder or not ScrollUtil or not ProfessionsTableBuilderMixin then return false end
    if not ProfessionsTableConstants or not ProfessionsSortOrder then return false end
    if not OrderBrowseType or HironCraftProfitGetCraftingOrderBrowseType(pageFrame) ~= OrderBrowseType.Flat then return false end

    self:LockOrderTableColumns()
    local PTC = ProfessionsTableConstants

    if not pageFrame.tableBuilder then
        pageFrame.tableBuilder = CreateTableBuilder(nil, ProfessionsTableBuilderMixin)
        local function ElementDataTranslator(elementData)
            return elementData
        end
        ScrollUtil.RegisterTableBuilder(pageFrame.BrowseFrame.OrderList.ScrollBox, pageFrame.tableBuilder, ElementDataTranslator)

        local function ElementDataProvider(elementData)
            return elementData
        end
        pageFrame.tableBuilder:SetDataProvider(ElementDataProvider)
    end

    local tableBuilder = pageFrame.tableBuilder
    tableBuilder:Reset()
    tableBuilder:SetColumnHeaderOverlap(2)
    tableBuilder:SetHeaderContainer(pageFrame.BrowseFrame.OrderList.HeaderContainer)
    tableBuilder:SetTableMargins(-3, 5)
    tableBuilder:SetTableWidth(GetOrderListTableWidth(pageFrame))

    tableBuilder:AddFillColumn(pageFrame, PTC.NoPadding, 1.0,
        PTC.ItemName.LeftCellPadding or 8, PTC.ItemName.RightCellPadding or 0,
        ProfessionsSortOrder.ItemName, "ProfessionsCrafterTableCellItemNameTemplate")

    local customerColumnName = pageFrame.orderType == Enum.CraftingOrderType.Npc
        and CRAFTING_ORDERS_BROWSE_HEADER_NPC_NAME
        or CRAFTING_ORDERS_BROWSE_HEADER_CUSTOMER_NAME

    tableBuilder:AddUnsortableFixedWidthColumn(pageFrame, PTC.NoPadding,
        PTC.CustomerName.Width, PTC.CustomerName.LeftCellPadding or 0, PTC.CustomerName.RightCellPadding or 0,
        customerColumnName, "ProfessionsCrafterTableCellCustomerNameTemplate")

    tableBuilder:AddFixedWidthColumn(pageFrame, PTC.NoPadding,
        PTC.Tip.Width, PTC.Tip.LeftCellPadding or 0, PTC.Tip.RightCellPadding or 0,
        ProfessionsSortOrder.Tip, "ProfessionsCrafterTableCellActualCommissionTemplate")

    tableBuilder:AddFixedWidthColumn(pageFrame, PTC.NoPadding,
        PTC.Reagents.Width, PTC.Reagents.LeftCellPadding or 0, PTC.Reagents.RightCellPadding or 0,
        ProfessionsSortOrder.Reagents, "ProfessionsCrafterTableCellReagentsTemplate")


    local actionSortOrder = self:GetActionSortOrder()
    if actionSortOrder then
        tableBuilder:AddFixedWidthColumn(pageFrame, PTC.NoPadding,
            PTC.Expiration.Width, PTC.Expiration.LeftCellPadding or 0, PTC.Expiration.RightCellPadding or 0,
            actionSortOrder, "ProfessionsCrafterTableCellStringTemplate")
    else
        tableBuilder:AddUnsortableFixedWidthColumn(pageFrame, PTC.NoPadding,
            PTC.Expiration.Width, PTC.Expiration.LeftCellPadding or 0, PTC.Expiration.RightCellPadding or 0,
            T("COA_HDR_ACTION", "Action"), "ProfessionsCrafterTableCellStringTemplate")
    end

    tableBuilder:Arrange()
    self:ApplyRealOrderTableLayout(pageFrame)
    return true
end

function WrapOrderPageSetupTable(pageFrame)
    if not pageFrame or pageFrame.ahuiCraftingOrdersSetupTableWrapped or not pageFrame.SetupTable then return end
    pageFrame.ahuiCraftingOrdersSetupTableWrapped = true
    pageFrame.ahuiCraftingOrdersOriginalSetupTable = pageFrame.SetupTable
    pageFrame.SetupTable = function(self, ...)
        if CO:IsEnabled() and CO:BuildHironCraftProfitOrderTable(self) then
            return
        end
        return pageFrame.ahuiCraftingOrdersOriginalSetupTable(self, ...)
    end
end

function CO:InstallOrderTableSetupHook()
    if self.orderTableSetupHooked or not ProfessionsCraftingOrderPageMixin or not ProfessionsCraftingOrderPageMixin.SetupTable then return end
    self.orderTableSetupHooked = true
    self.originalBlizzardOrderSetupTable = ProfessionsCraftingOrderPageMixin.SetupTable

    ProfessionsCraftingOrderPageMixin.SetupTable = function(pageFrame, ...)
        if CO:IsEnabled() and CO:BuildHironCraftProfitOrderTable(pageFrame) then
            return
        end
        return CO.originalBlizzardOrderSetupTable(pageFrame, ...)
    end

    if _G.ProfessionsFrame then
        WrapOrderPageSetupTable(ProfessionsFrame.OrdersPage)
        WrapOrderPageSetupTable(ProfessionsFrame.OrdersPageOffline)
    end
end

function CO:RearrangeOrderTableSafely(pageFrame)
    if not self:IsEnabled() then return end
    pageFrame = pageFrame or self.activePageFrame
    local tableBuilder = pageFrame and pageFrame.tableBuilder
    if tableBuilder and tableBuilder.Arrange then
        pcall(tableBuilder.Arrange, tableBuilder)
    end
    self:ApplyRealOrderTableLayout(pageFrame)
end

function CO:HookBlizzardProfessions()
    if self.hookedBlizzard then return true end

    if not ProfessionsCrafterOrderListElementMixin or not ProfessionsCraftingOrderPageMixin then
        return false
    end

    self:InstallOrderTableSetupHook()
    self:InstallProfitSortHooks()

    hooksecurefunc(ProfessionsCrafterOrderListElementMixin, "Init", function(row, elementData)
        CO:DecorateOrderRow(row, elementData)
    end)

    local function afterExternalPageRefresh(pageFrame)
        if not CO:IsEnabled() then return end
        pageFrame = pageFrame or CO:FindOrderPageFrame()
        CO:ProtectExternalOrderPageSoon(pageFrame)
        CO:EnsureControlPanel(pageFrame)
        CO:UpdatePageBackground(pageFrame)
        CO:UpdateControlPanelVisibility(pageFrame)
        if C_Timer then
            C_Timer.After(0, function() CO:UpdateControlPanelVisibility(pageFrame) end)
        end
        CO:WarmVisibleOrderQualitySoon(pageFrame, QUALITY_WARM_START_DELAY)

        local CraftingOrderType = Enum and Enum.CraftingOrderType
        local function onClientsTab(pf)
            if not (CraftingOrderType and CraftingOrderType.Npc) then return true end
            return pf ~= nil and pf.orderType == CraftingOrderType.Npc
        end

        if CO.IsAutoToolOn and CO:IsAutoToolOn() and CO.AutoEquipResourcefulnessTool and not CO._autoToolRanForOpen then
            CO._autoToolRanForOpen = true
            if C_Timer then
                C_Timer.After(0.5, function() CO:AutoEquipResourcefulnessTool(pageFrame) end)
            else
                CO:AutoEquipResourcefulnessTool(pageFrame)
            end
        end

        if onClientsTab(pageFrame) and CO.IsAutoQueueOnOpen and CO:IsAutoQueueOnOpen() and CO.QueueWorkOrdersSelection
            and not CO._autoRanForOpen
        then
            local stamp = (CO._autoQueueStamp or 0) + 1
            CO._autoQueueStamp = stamp
            C_Timer.After(0.6, function()
                if CO._autoQueueStamp ~= stamp then return end
                if CO._autoRanForOpen then return end
                if not CO:IsAutoQueueOnOpen() then return end
                if not onClientsTab(pageFrame) then return end
                if pageFrame and pageFrame.ahuiCraftingOrdersOrderOpen then return end

                local haveOrders = false
                if C_CraftingOrders and C_CraftingOrders.GetCrafterOrders then
                    local ok, list = pcall(C_CraftingOrders.GetCrafterOrders)
                    haveOrders = ok and type(list) == "table" and #list > 0
                end
                if not haveOrders then return end

                CO._autoRanForOpen = true
                pcall(function() CO:QueueWorkOrdersSelection() end)

                if CO.IsAutoShoppingOnOpen and CO:IsAutoShoppingOnOpen() and CO.CreateShoppingListForSelectedOrders then
                    local startedAt = GetTime()
                    local function whenReady()
                        if not CO:IsAutoShoppingOnOpen() then return end
                        if pageFrame and pageFrame.ahuiCraftingOrdersOrderOpen then return end
                        if CO.queueSelectionRunning and (GetTime() - startedAt) < 5 then
                            C_Timer.After(0.2, whenReady)
                            return
                        end
                        if CO.HasSelectedOrders and not CO:HasSelectedOrders() then return end
                        pcall(function() CO:CreateShoppingListForSelectedOrders() end)
                    end
                    C_Timer.After(0.4, whenReady)
                end
            end)
        end
    end

    if ProfessionsCraftingOrderPageMixin.ShowGeneric then
        hooksecurefunc(ProfessionsCraftingOrderPageMixin, "ShowGeneric", function(pageFrame)
            afterExternalPageRefresh(pageFrame)
        end)
    end

    if _G.ProfessionsFrame and ProfessionsFrame.OrdersPage and ProfessionsFrame.OrdersPage.ShowGeneric then
        hooksecurefunc(ProfessionsFrame.OrdersPage, "ShowGeneric", function(pageFrame)
            afterExternalPageRefresh(pageFrame or ProfessionsFrame.OrdersPage)
        end)
    end

    if _G.ProfessionsFrame and ProfessionsFrame.OrdersPageOffline and ProfessionsFrame.OrdersPageOffline.ShowGeneric then
        hooksecurefunc(ProfessionsFrame.OrdersPageOffline, "ShowGeneric", function(pageFrame)
            afterExternalPageRefresh(pageFrame or ProfessionsFrame.OrdersPageOffline)
        end)
    end

    hooksecurefunc(ProfessionsCraftingOrderPageMixin, "ViewOrder", function(pageFrame)
        if pageFrame then
            CO.activePageFrame = pageFrame
            CO:EnsurePageBindingHooks(pageFrame)
            pageFrame.ahuiCraftingOrdersOrderOpen = true
            CO:EnsureControlPanel(pageFrame)
            if CO.controlPanel then
                CO.controlPanel:Hide()
                if CO.controlPanel.shopButton then CO.controlPanel.shopButton:Hide() end
            end
            CO:ApplyTemporaryBinding()
            if pageFrame.OrderView then
                CO:DecorateOrderView(pageFrame.OrderView)
            end
            C_Timer.After(0, function() if CO.controlPanel then CO.controlPanel:Hide(); if CO.controlPanel.shopButton then CO.controlPanel.shopButton:Hide() end end end)
            C_Timer.After(0.1, function() if CO.controlPanel then CO.controlPanel:Hide(); if CO.controlPanel.shopButton then CO.controlPanel.shopButton:Hide() end end end)
        end
    end)

    hooksecurefunc(ProfessionsCraftingOrderPageMixin, "CloseOrder", function(pageFrame)
        if pageFrame then
            pageFrame.ahuiCraftingOrdersOrderOpen = false
            CO.activePageFrame = pageFrame
            CO:EnsurePageBindingHooks(pageFrame)
            CO:EnsureControlPanel(pageFrame)
            CO:UpdateControlPanelVisibility(pageFrame)
            CO:ApplyTemporaryBinding()
            C_Timer.After(0, function() CO:UpdateControlPanelVisibility(pageFrame) end)
            C_Timer.After(0.1, function() CO:UpdateControlPanelVisibility(pageFrame) end)
        end
        CO:StopRowProgress()
    end)

    local function markOrderOpen(pageFrame)
        if pageFrame then
            pageFrame.ahuiCraftingOrdersOrderOpen = true
            CO.activePageFrame = pageFrame
            CO:UpdateControlPanelVisibility(pageFrame)
            if CO.controlPanel then
                CO.controlPanel:Hide()
                if CO.controlPanel.shopButton then CO.controlPanel.shopButton:Hide() end
            end
        end
    end

    for _, methodName in ipairs({ "ShowOrder", "SelectOrder", "OpenOrder", "SetOrder" }) do
        if ProfessionsCraftingOrderPageMixin[methodName] and methodName ~= "ViewOrder" then
            hooksecurefunc(ProfessionsCraftingOrderPageMixin, methodName, markOrderOpen)
        end
    end

    self.hookedBlizzard = true
    return true
end

function CO:MarkOrderCraftedReady(orderID)
    if not orderID then return end

    local claimed = self:GetClaimedOrder()
    local order = claimed and SameOrderID(claimed.orderID, orderID) and claimed or nil
    local state = self.rowStates and self.rowStates[orderID]
    if not order and state then
        order = state.order
    end

    if order then
        order.isFulfillable = true
        self.rowStates[orderID] = self.rowStates[orderID] or {}
        self.rowStates[orderID].order = order
        self.rowStates[orderID].pageFrame = self.rowStates[orderID].pageFrame or self.activePageFrame
    end

    self.craftedOrderID = orderID
    self.pendingCraftOrderID = nil
    self.pendingCraftButton = nil
    self:StopRowProgress()
    self:InvalidateOrderCaches(orderID)
    self:SetStatus(T("COA_STATUS_CRAFTED_READY", "Order crafted. Complete it."))
    self:RefreshVisibleRowsSoon(0.05)
end

function CO:OnEvent(event, ...)
    if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        local interactionType = ...
        if self:IsCraftingOrderInteractionType(interactionType) then
            self:SetOrderTablePresence(true)
        end
        return
    end

    if event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        local interactionType = ...
        if self:IsCraftingOrderInteractionType(interactionType) then
            self:SetOrderTablePresence(false)
            self:RefreshVisibleRowsSoon(0.05)
        end
        return
    end

    if event == "TRADE_SKILL_SHOW" then
        local pageFrame = self:FindOrderPageFrame()
        if pageFrame then
            self:SetOrderTablePresence(true, pageFrame)
        end
        return
    end

    if event == "TRADE_SKILL_CLOSE" then
        self.qualityWarmSerial = (tonumber(self.qualityWarmSerial) or 0) + 1
        if self.StopPageProtector then self:StopPageProtector() end
        if self.StopRowProgress then self:StopRowProgress() end
        self:SetOrderTablePresence(false)
        self:RefreshVisibleRowsSoon(0.05)
        return
    end

    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "Blizzard_Professions" then
            self:HookBlizzardProfessions()
            self:ApplyEnabledState()
        elseif addonName == "HironCraft" then
            PT.config = PT.config or {}
            if PT.config.craftingOrdersEnabled == nil then
                PT.config.craftingOrdersEnabled = true
            end
        elseif addonName == "PublicOrdersReagentsColumn" then
            self:ProtectExternalOrderPageSoon(self.activePageFrame or self:FindOrderPageFrame())
        end
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if self.pendingBindingRefresh then
            if self:HasVisibleOrderContext() then
                self:ApplyTemporaryBinding()
            else
                self:ClearTemporaryBinding()
            end
        end
        return
    end

    if event == "CRAFTINGORDERS_CLAIM_ORDER_RESPONSE" then
        local result, orderID = ...
        if self.pendingClaimOrderID and (not orderID or SameOrderID(orderID, self.pendingClaimOrderID)) then
            if IsResultOk(result) then
                local pendingID = self.pendingClaimOrderID
                self.pendingClaimOrderID = nil

                local claimed = self:GetClaimedOrder()
                if claimed and SameOrderID(claimed.orderID, pendingID) then
                    self.rowStates[pendingID] = self.rowStates[pendingID] or {}
                    self.rowStates[pendingID].order = claimed
                elseif self.rowStates[pendingID] and self.rowStates[pendingID].order then
                    SetCachedOrderStateClaimed(self.rowStates[pendingID].order)
                end

                self.currentQueueOrderID = pendingID
                self:InvalidateOrderCaches(pendingID)
                self:SetStatus(T("COA_STATUS_CLAIMED", "Order claimed."))
            else
                self.pendingClaimOrderID = nil
                self:SetStatus(T("COA_STATUS_CLAIM_FAILED", "Could not claim the order."))
            end
        end
        self:RefreshVisibleRowsSoon()
        return
    end

    if event == "CRAFTINGORDERS_CLAIMED_ORDER_ADDED" then
        local order = self:GetClaimedOrder()
        if order then
            self.activeOrderID = order.orderID
            self.currentQueueOrderID = order.orderID
            self.rowStates[order.orderID] = self.rowStates[order.orderID] or {}
            self.rowStates[order.orderID].order = order
            self:InvalidateOrderCaches(order.orderID)
            if self.pendingClaimOrderID and SameOrderID(self.pendingClaimOrderID, order.orderID) then
                self.pendingClaimOrderID = nil
            end
        else
            self.pendingClaimOrderID = nil
        end
        self:SetStatus(T("COA_STATUS_CLAIMED", "Order claimed."))
        self:RefreshVisibleRowsSoon()
        return
    end

    if event == "CRAFTINGORDERS_CLAIMED_ORDER_UPDATED" then
        local orderID = ...
        local order = self:GetClaimedOrder()
        local isCurrentCraftUpdate = false
        local currentCraftOrderID = self.pendingCraftOrderID or self.progressOrderID or (self.pendingCraftButton and self.pendingCraftButton.orderID)

        if currentCraftOrderID then
            if (not orderID) or SameOrderID(orderID, currentCraftOrderID) then
                isCurrentCraftUpdate = true
            elseif order and SameOrderID(order.orderID, currentCraftOrderID) then
                isCurrentCraftUpdate = true
            end
        end

        if order then
            self.rowStates[order.orderID] = self.rowStates[order.orderID] or {}
            self.rowStates[order.orderID].order = order
            self:InvalidateOrderCaches(order.orderID)

            if isCurrentCraftUpdate and order.isFulfillable then
                self:MarkOrderCraftedReady(order.orderID)
                return
            end
        elseif orderID and self.rowStates[orderID] then
            self.rowStates[orderID].order = nil
            self:InvalidateOrderCaches(orderID)
        end

        if not isCurrentCraftUpdate then
            self.pendingCraftOrderID = nil
            self.pendingFulfillOrderID = nil
            self:StopRowProgress()
        end

        self:RefreshVisibleRowsSoon()
        return
    end

    if event == "CRAFTINGORDERS_CLAIMED_ORDER_REMOVED" then
        local orderID = self.pendingReleaseOrderID or self.pendingFulfillOrderID
        if orderID and self.rowStates[orderID] then
            self.rowStates[orderID].order = nil
        end
        if orderID then
            self:InvalidateOrderCaches(orderID)
            self.selectedOrders[OrderKey(orderID)] = nil
            self.orderIssues[OrderKey(orderID)] = nil
        end
        if self.currentQueueOrderID and orderID and SameOrderID(self.currentQueueOrderID, orderID) then
            self.currentQueueOrderID = nil
        end
        if orderID then
            if self.pendingClaimOrderID and SameOrderID(self.pendingClaimOrderID, orderID) then
                self.pendingClaimOrderID = nil
            end
            if self.pendingCraftOrderID and SameOrderID(self.pendingCraftOrderID, orderID) then
                self.pendingCraftOrderID = nil
            end
            if self.pendingFulfillOrderID and SameOrderID(self.pendingFulfillOrderID, orderID) then
                self.pendingFulfillOrderID = nil
            end
            if self.pendingReleaseOrderID and SameOrderID(self.pendingReleaseOrderID, orderID) then
                self.pendingReleaseOrderID = nil
            end
            if self.craftedOrderID and SameOrderID(self.craftedOrderID, orderID) then
                self.craftedOrderID = nil
            end
        end
        self:SetStatus(T("COA_STATUS_DONE", "Order completed or released."))
        self:StopRowProgress()
        self:UpdateControlPanel()
        self:RefreshPageSoon(0.35, not self:HasSelectedOrders())
        return
    end

    if event == "CRAFTINGORDERS_CRAFT_ORDER_RESPONSE" then
        local result, orderID = ...
        local matchesPending = self.pendingCraftOrderID and (not orderID or SameOrderID(orderID, self.pendingCraftOrderID))

        if matchesPending then
            if not IsResultOk(result) then
                self:SetStatus(T("COA_STATUS_CRAFT_FAILED", "Could not craft the order."))
                self.pendingCraftOrderID = nil
                self.pendingCraftButton = nil
                self:StopRowProgress()
            else
                local pendingID = self.pendingCraftOrderID
                if self.pendingCraftButton then
                    self:StartRowProgress(self.pendingCraftButton, pendingID)
                end
                C_Timer.After(30, function()
                    local name = UnitCastingInfo("player") or UnitChannelInfo("player")
                    if not name and CO.pendingCraftOrderID and pendingID and SameOrderID(CO.pendingCraftOrderID, pendingID) then
                        CO.pendingCraftOrderID = nil
                        CO.pendingCraftButton = nil
                        CO:StopRowProgress()
                        CO:RefreshVisibleRowsSoon()
                    end
                end)
            end
        end

        self:RefreshVisibleRowsSoon(0.15)
        return
    end

    if event == "CRAFTINGORDERS_FULFILL_ORDER_RESPONSE" then
        local result, orderID = ...
        if self.pendingFulfillOrderID and (not orderID or SameOrderID(orderID, self.pendingFulfillOrderID)) then
            self.pendingFulfillOrderID = nil
        end
        if orderID then self:InvalidateOrderCaches(orderID) end
        if Enum and Enum.CraftingOrderResult and result == Enum.CraftingOrderResult.Ok then
            if orderID then
                self.fulfilledOrderIDs = self.fulfilledOrderIDs or {}
                self.fulfilledOrderIDs[orderID] = true
                self.selectedOrders[OrderKey(orderID)] = nil
                self.orderIssues[OrderKey(orderID)] = nil
                if self.currentQueueOrderID and SameOrderID(self.currentQueueOrderID, orderID) then
                    self.currentQueueOrderID = nil
                end
                if self.craftedOrderID and SameOrderID(self.craftedOrderID, orderID) then
                    self.craftedOrderID = nil
                end
            end
            self:UpdateControlPanel()
            self:SetStatus(T("COA_STATUS_FULFILLED", "Order completed."))
        else
            self:SetStatus(T("COA_STATUS_FULFILL_FAILED", "Could not complete the order."))
        end
        self:RefreshVisibleRowsSoon()
        return
    end

    if event == "UNIT_SPELLCAST_START" then
        local unit = ...
        if unit == "player" then
            local btn = self.pendingCraftButton or self.progressButton
            local orderID = self.pendingCraftOrderID or self.progressOrderID or (btn and btn.orderID)
            if orderID and (not btn) then
                btn = self:GetVisibleButtonForOrder(orderID)
            end
            if orderID and btn then
                self.pendingCraftButton = btn
                self.pendingCraftOrderID = self.pendingCraftOrderID or orderID
                self:StartRowProgress(btn, orderID)
            end
        end
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit = ...
        if unit ~= "player" then return end
        local orderID = self.pendingCraftOrderID or self.progressOrderID or (self.pendingCraftButton and self.pendingCraftButton.orderID)
        if orderID then
            C_Timer.After(0.20, function()
                CO:MarkOrderCraftedReady(orderID)
            end)
        end
        return
    end

    if event == "UNIT_SPELLCAST_INTERRUPTED"
    or event == "UNIT_SPELLCAST_FAILED" then
        local unit = ...
        if unit ~= "player" then return end
        C_Timer.After(0.25, function()
            CO:StopRowProgress()
            CO.pendingCraftButton = nil
            CO.pendingCraftOrderID = nil
            CO:RefreshVisibleRowsSoon()
        end)
        return
    end

    if event == "UNIT_SPELLCAST_STOP" then
        local unit = ...
        if unit ~= "player" then return end
        local pendingID = self.pendingCraftOrderID or self.progressOrderID
        C_Timer.After(0.25, function()
            CO:StopRowProgress()
            if pendingID and CO.pendingCraftOrderID and SameOrderID(CO.pendingCraftOrderID, pendingID) then
                C_Timer.After(5.0, function()
                    if CO.pendingCraftOrderID and SameOrderID(CO.pendingCraftOrderID, pendingID) then
                        CO.pendingCraftButton = nil
                        CO.pendingCraftOrderID = nil
                        CO:RefreshVisibleRowsSoon()
                    end
                end)
            else
                CO:RefreshVisibleRowsSoon()
            end
        end)
        return
    end

    if event == "UPDATE_TRADESKILL_CAST_STOPPED" then
        local pendingID = self.pendingCraftOrderID or self.progressOrderID
        C_Timer.After(0.25, function()
            CO:StopRowProgress()
            if not pendingID then
                CO.pendingCraftButton = nil
                CO.pendingCraftOrderID = nil
            end
            CO:RefreshVisibleRowsSoon()
        end)
        return
    end

    if event == "QUEST_ACCEPTED"
    or event == "QUEST_REMOVED"
    or event == "QUEST_TURNED_IN"
    or event == "QUEST_LOG_UPDATE" then
        self:UpdateControlPanel()
        return
    end

    if event == "TRADE_SKILL_LIST_UPDATE" then
        wipe(self.orderIssues)
        self:InvalidateOrderCaches()
        self:UpdateControlPanel()
        self:RefreshVisibleRowsSoon()
        return
    end

    if event == "BAG_UPDATE_DELAYED" then
        if self._bagUpdateQueued then return end
        self._bagUpdateQueued = true
        C_Timer.After(0.3, function()
            CO._bagUpdateQueued = false
            wipe(CO.orderIssues)
            if CO.craftableOrderVisualCache then wipe(CO.craftableOrderVisualCache) end
            CO:UpdateControlPanel()
            CO:RefreshVisibleRowsSoon()
        end)
        return
    end

    if event == "UNIT_INVENTORY_CHANGED" then
        local unit = ...
        if unit == "player" then
            self:UpdateControlPanel()
        end
        return
    end

    if event == "PLAYER_EQUIPMENT_CHANGED" then
        self:UpdateControlPanel()
        return
    end

    if event == "GET_ITEM_INFO_RECEIVED" then
        if self._ctrlPanelQueued then return end
        self._ctrlPanelQueued = true
        C_Timer.After(0.2, function()
            CO._ctrlPanelQueued = false
            CO:UpdateControlPanel()
        end)
        return
    end
end

eventFrame = CreateFrame("Frame")
function SafeRegisterEvent(frame, eventName)
    if not frame or not eventName then return end
    pcall(frame.RegisterEvent, frame, eventName)
end

SafeRegisterEvent(eventFrame, "ADDON_LOADED")
SafeRegisterEvent(eventFrame, "PLAYER_REGEN_ENABLED")
SafeRegisterEvent(eventFrame, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
SafeRegisterEvent(eventFrame, "PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
SafeRegisterEvent(eventFrame, "TRADE_SKILL_SHOW")
SafeRegisterEvent(eventFrame, "TRADE_SKILL_CLOSE")
SafeRegisterEvent(eventFrame, "CRAFTINGORDERS_CLAIM_ORDER_RESPONSE")
SafeRegisterEvent(eventFrame, "CRAFTINGORDERS_CLAIMED_ORDER_ADDED")
SafeRegisterEvent(eventFrame, "CRAFTINGORDERS_CLAIMED_ORDER_REMOVED")
SafeRegisterEvent(eventFrame, "CRAFTINGORDERS_CLAIMED_ORDER_UPDATED")
SafeRegisterEvent(eventFrame, "CRAFTINGORDERS_CRAFT_ORDER_RESPONSE")
SafeRegisterEvent(eventFrame, "CRAFTINGORDERS_FULFILL_ORDER_RESPONSE")
SafeRegisterEvent(eventFrame, "UNIT_SPELLCAST_START")
SafeRegisterEvent(eventFrame, "UNIT_SPELLCAST_STOP")
SafeRegisterEvent(eventFrame, "UNIT_SPELLCAST_SUCCEEDED")
SafeRegisterEvent(eventFrame, "UNIT_SPELLCAST_INTERRUPTED")
SafeRegisterEvent(eventFrame, "UNIT_SPELLCAST_FAILED")
SafeRegisterEvent(eventFrame, "UPDATE_TRADESKILL_CAST_STOPPED")
SafeRegisterEvent(eventFrame, "TRADE_SKILL_LIST_UPDATE")
SafeRegisterEvent(eventFrame, "BAG_UPDATE_DELAYED")
SafeRegisterEvent(eventFrame, "UNIT_INVENTORY_CHANGED")
SafeRegisterEvent(eventFrame, "PLAYER_EQUIPMENT_CHANGED")
SafeRegisterEvent(eventFrame, "GET_ITEM_INFO_RECEIVED")
SafeRegisterEvent(eventFrame, "QUEST_ACCEPTED")
SafeRegisterEvent(eventFrame, "QUEST_REMOVED")
SafeRegisterEvent(eventFrame, "QUEST_TURNED_IN")
SafeRegisterEvent(eventFrame, "QUEST_LOG_UPDATE")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    CO:OnEvent(event, ...)
end)

CO:CreateHotkeyProxy()
CO:HookBlizzardProfessions()
CO:ApplyEnabledState()

_G.SLASH_HIRONCRAFT_PROFITCO1 = "/ahuico"
_G.SlashCmdList["HIRONCRAFT_PROFITCO"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "off" or msg == "disable" then
        CO:SetEnabled(false)
        DEFAULT_CHAT_FRAME:AddMessage("|cffb19cd9HironCraft Crafting Orders:|r module disabled.")
    elseif msg == "on" or msg == "enable" then
        CO:SetEnabled(true)
        DEFAULT_CHAT_FRAME:AddMessage("|cffb19cd9HironCraft Crafting Orders:|r module enabled.")
    elseif msg == "dismiss" then
        CO:DismissConflictWarning()
        DEFAULT_CHAT_FRAME:AddMessage("|cffb19cd9HironCraft Crafting Orders:|r conflict warning dismissed.")
    elseif msg == "reset-warning" or msg == "resetwarning" then
        CO:ResetConflictWarning()
        DEFAULT_CHAT_FRAME:AddMessage("|cffb19cd9HironCraft Crafting Orders:|r conflict warning re-enabled.")
    elseif msg == "check" or msg == "conflicts" then
        local detected = CO:DetectConflictingAddons()
        if #detected == 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cffb19cd9HironCraft Crafting Orders:|r no known conflicting addons detected.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffb19cd9HironCraft Crafting Orders:|r detected: |cffffd200" .. table.concat(detected, ", ") .. "|r")
        end
    elseif msg == "dbgshop" then
        CO.shoppingDebug = not (CO.shoppingDebug == true)
        DEFAULT_CHAT_FRAME:AddMessage("|cffb19cd9HironCraft Crafting Orders:|r shopping debug " .. (CO.shoppingDebug and "ON" or "OFF") .. ". Press the shopping button to see per-reagent dump.")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffb19cd9HironCraft Crafting Orders:|r commands: on, off, dismiss, reset-warning, check, dbgshop. Module is currently " .. (CO:IsEnabled() and "ON" or "OFF") .. ".")
    end
end

_G.SLASH_HIRONCRAFT_PROFITSHOPDBG1 = "/ahuishopdbg"
_G.SlashCmdList["HIRONCRAFT_PROFITSHOPDBG"] = function()
    CO.shoppingDebug = not (CO.shoppingDebug == true)
    DEFAULT_CHAT_FRAME:AddMessage("|cffb19cd9HironCraft Crafting Orders:|r shopping debug " .. (CO.shoppingDebug and "ON" or "OFF") .. ".")
end
