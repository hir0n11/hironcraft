local E = _G.HironCraftProfitCraftingOrdersEnv
if not E then
    E = {}
    _G.HironCraftProfitCraftingOrdersEnv = E
    setmetatable(E, { __index = _G })
end
setfenv(1, E)
if not PT or not CO then return end

function CO:SyncRowActionButtonLayers(row, btn)
    btn = btn or (row and row.ahuiOrderActionButton)
    if not btn then return end

    row = row or (btn.GetParent and btn:GetParent())
    local rowLevel = row and row.GetFrameLevel and row:GetFrameLevel() or 1

    if btn.SetFrameLevel then
        btn:SetFrameLevel(rowLevel + 80)
    end

    local btnLevel = btn.GetFrameLevel and btn:GetFrameLevel() or (rowLevel + 80)

    if btn.check and btn.check.SetFrameLevel then
        btn.check:SetFrameLevel(btnLevel + 1)
    end

    if btn.bar then
        if btn.bar.SetFrameStrata and btn.GetFrameStrata then
            btn.bar:SetFrameStrata(btn:GetFrameStrata())
        end
        if btn.bar.SetFrameLevel then
            btn.bar:SetFrameLevel(btnLevel + 8)
        end

        local texture = btn.bar.GetStatusBarTexture and btn.bar:GetStatusBarTexture()
        if texture and texture.SetDrawLayer then
            texture:SetDrawLayer("OVERLAY", 7)
        end
    end

    if self.progressActive and self.progressButton == btn and self.rowProgressOverlay and self.rowProgressOverlay:IsShown() then
        self:PositionRowProgressOverlay(btn)
    end
end


function CO:EnsureRowProgressOverlay()
    if self.rowProgressOverlay then
        return self.rowProgressOverlay
    end

    local bar = CreateFrame("StatusBar", nil, UIParent, "BackdropTemplate")
    bar.ahuiCraftingOrdersOwned = true
    bar:SetFrameStrata("TOOLTIP")
    bar:SetFrameLevel(10000)
    bar:SetHeight(4)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetStatusBarColor(0.95, 0.78, 0.35, 1)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:EnableMouse(false)
    if bar.SetBackdrop then
        bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        bar:SetBackdropColor(0, 0, 0, 0.45)
    end

    local texture = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if texture and texture.SetDrawLayer then
        texture:SetDrawLayer("OVERLAY", 7)
    end

    bar:Hide()
    self.rowProgressOverlay = bar
    return bar
end

function CO:PositionRowProgressOverlay(btn)
    local bar = self.rowProgressOverlay or self:EnsureRowProgressOverlay()
    if not bar or not btn then return false end

    local visible = btn.IsVisible and btn:IsVisible() or (btn.IsShown and btn:IsShown())
    if not visible then
        bar:Hide()
        return false
    end

    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 1, 1)
    bar:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    bar:SetHeight(4)
    bar:SetFrameStrata("TOOLTIP")
    bar:SetFrameLevel(10000)
    return true
end

function CO:ShowRowProgressVisual(btn, value)
    if not btn then return end

    value = tonumber(value) or 0.02
    if value < 0.02 then value = 0.02 elseif value > 1 then value = 1 end

    self.progressButton = btn
    btn.ahuiProgressValue = value

    if btn.bar then
        btn.bar:SetValue(value)
        btn.bar:Hide()
    end

    local bar = self:EnsureRowProgressOverlay()
    if self:PositionRowProgressOverlay(btn) then
        bar.ahuiOrderButton = btn
        bar:SetValue(value)
        bar:Show()
    end
end

function CO:HideRowProgressVisual(btn)
    if btn and btn.bar then
        btn.bar:SetValue(0)
        btn.bar:Hide()
    end

    local bar = self.rowProgressOverlay
    if bar and ((not btn) or bar.ahuiOrderButton == btn) then
        bar.ahuiOrderButton = nil
        bar:SetValue(0)
        bar:Hide()
    end
end

function CO:EnsureRowProgressTicker()
    if self.rowProgressTicker then
        return self.rowProgressTicker
    end

    local ticker = CreateFrame("Frame", nil, UIParent)
    ticker.ahuiCraftingOrdersOwned = true
    ticker:SetScript("OnUpdate", function(tickerFrame, elapsed)
        tickerFrame.ahuiAccum = (tickerFrame.ahuiAccum or 0) + (elapsed or 0)
        if tickerFrame.ahuiAccum < 0.05 then return end
        tickerFrame.ahuiAccum = 0
        CO:UpdateRowProgress()
    end)
    ticker:Hide()
    self.rowProgressTicker = ticker
    return ticker
end

function CO:StartRowProgressTicker()
    local ticker = self:EnsureRowProgressTicker()
    ticker:Show()
end

function CO:StopRowProgressTicker()
    if self.rowProgressTicker then
        self.rowProgressTicker:Hide()
    end
end

function CO:GetQueueButton()
    local claimed = self:GetClaimedOrder()
    if claimed and self:IsOrderSelected(claimed.orderID) then
        local claimedBtn = self:GetVisibleButtonForOrder(claimed.orderID)
        if claimedBtn then return claimedBtn end
    end

    if self.currentQueueOrderID and self:IsOrderSelected(self.currentQueueOrderID) then
        local currentBtn = self:GetVisibleButtonForOrder(self.currentQueueOrderID)
        if currentBtn then return currentBtn end
    end

    local buttons = {}
    for btn in pairs(self.visibleRowButtons or {}) do
        if btn and btn:IsShown() and btn.orderID and self:IsOrderSelected(btn.orderID) then
            buttons[#buttons + 1] = btn
        end
    end

    table.sort(buttons, function(a, b)
        return (a:GetTop() or 0) > (b:GetTop() or 0)
    end)

    local btn = buttons[1]
    if btn then
        self.currentQueueOrderID = btn.orderID
    end
    return btn
end

function CO:GetOrderEngine(pageFrame, order)
    if not order then
        return nil, T("COA_STATUS_NO_ENGINE", "Crafting order view is not available.")
    end

    pageFrame = self:FindOrderPageFrame(pageFrame)
    if pageFrame then
        self.activePageFrame = pageFrame
        self:EnsurePageBindingHooks(pageFrame)
        self:EnsureControlPanel(pageFrame)
    end

    if not pageFrame or not pageFrame.OrderView then
        return nil, T("COA_STATUS_NO_ENGINE", "Crafting order view is not available.")
    end

    local orderView = pageFrame.OrderView
    if not orderView.SetOrder then
        return nil, T("COA_STATUS_NO_ENGINE", "Crafting order view is not available.")
    end

    local browseShown = pageFrame.BrowseFrame and pageFrame.BrowseFrame:IsShown()
    local orderShown = orderView:IsShown()

    local ok = SafeCall("SetOrder", function()
        orderView:SetOrder(order)
    end)

    if ok then
        self:InvalidateOrderCaches(order.orderID)
    end

    if browseShown and pageFrame.BrowseFrame then
        pageFrame.BrowseFrame:Show()
    end
    if not orderShown then
        orderView:Hide()
    end

    if not ok then
        return nil, T("COA_STATUS_PREPARE_FAILED", "Could not prepare the order.")
    end

    return orderView
end

function CO:ReleaseOrder(order, pageFrame, continuation)
    order = order or self:GetClaimedOrder()
    pageFrame = self:FindOrderPageFrame(pageFrame) or self.activePageFrame or pageFrame
    if not order or not order.orderID then
        self:SetStatus(T("COA_STATUS_NO_ORDER", "Select an order first."))
        return false
    end

    if not self:IsAtUsableCraftingOrderTable(pageFrame) then
        self:SetStatus(T("COA_STATUS_TABLE_REQUIRED", "Crafting order table is required for this action."))
        return false
    end

    local claimed = self:GetClaimedOrder()
    if not claimed or not SameOrderID(claimed.orderID, order.orderID) then
        self:SetStatus(T("COA_STATUS_NOT_CLAIMED", "This order is not claimed."))
        return false
    end

    local profession = GetProfessionFromPage(pageFrame or self.activePageFrame)
    if not profession then
        self:SetStatus(T("COA_STATUS_NO_PROFESSION", "Profession is not available."))
        return false
    end

    self.pendingReleaseOrderID = order.orderID
    self.pendingReleaseContinuation = type(continuation) == "function" and {
        orderID = order.orderID,
        callback = continuation,
    } or nil
    self.pendingClaimOrderID = nil
    self.pendingCraftOrderID = nil
    self.pendingFulfillOrderID = nil
    self:SetStatus(T("COA_STATUS_RELEASING", "Releasing order..."))
    self:StopRowProgress()
    self:RefreshVisibleRows()

    local ok = SafeCall("ReleaseOrder", function()
        C_CraftingOrders.ReleaseOrder(order.orderID, profession)
    end)

    if not ok then
        self.pendingReleaseOrderID = nil
        self.pendingReleaseContinuation = nil
        self:RefreshVisibleRowsSoon()
    end

    return ok
end

function CO:RejectOrder(order, pageFrame, releasedForReject, rejectionReason)
    pageFrame = self:FindOrderPageFrame(pageFrame) or self.activePageFrame or pageFrame
    if not order or not order.orderID then
        self:SetStatus(T("COA_STATUS_NO_ORDER", "Select an order first."))
        return false
    end

    if not self:IsAtUsableCraftingOrderTable(pageFrame) then
        self:SetStatus(T("COA_STATUS_TABLE_REQUIRED", "Crafting order table is required for this action."))
        return false
    end

    if
        not self:IsPersonalCraftingOrder(order, pageFrame)
        or not C_CraftingOrders
        or type(C_CraftingOrders.RejectOrder) ~= "function"
    then
        self:SetStatus(T("COA_STATUS_REJECT_UNAVAILABLE", "This order cannot be declined."))
        return false
    end

    rejectionReason = rejectionReason or "missing_customer_reagents"
    local qualityRejection = rejectionReason == "insufficient_quality"
    local shouldReject
    if qualityRejection then
        -- A quality rejection is armed only by a fresh, authoritative check of
        -- the claimed order's transaction. This prevents a stale row or a
        -- direct button action from declining a valid customer order.
        shouldReject = self.IsOrderReadyForQualityRejection
            and self:IsOrderReadyForQualityRejection(order)
    else
        shouldReject = self.ShouldRejectForMissingCustomerReagents
            and self:ShouldRejectForMissingCustomerReagents(order, pageFrame)
    end
    if not shouldReject then
        if qualityRejection then
            self:SetStatus(T("COA_STATUS_REJECT_NOT_NEEDED_QUALITY", "The order no longer requires a quality rejection."))
        else
            self:SetStatus(T("COA_STATUS_REJECT_NOT_NEEDED", "The customer provided all required reagents."))
        end
        return false
    end

    local profession = GetProfessionFromPage(pageFrame)
    if not profession then
        self:SetStatus(T("COA_STATUS_NO_PROFESSION", "Profession is not available."))
        return false
    end

    local claimed = self:GetClaimedOrder()
    if not releasedForReject and claimed and SameOrderID(claimed.orderID, order.orderID) then
        if qualityRejection then
            self:SetStatus(T("COA_STATUS_RELEASING_FOR_REJECT_QUALITY", "Releasing order before declining it for insufficient quality..."))
        else
            self:SetStatus(T("COA_STATUS_RELEASING_FOR_REJECT", "Releasing order before declining it..."))
        end
        return self:ReleaseOrder(order, pageFrame, function()
            CO:RejectOrder(order, pageFrame, true, rejectionReason)
        end)
    end

    local key = OrderKey(order.orderID)
    self.rejectedOrderIDs = self.rejectedOrderIDs or {}
    self.rejectedOrderIDs[key] = (GetTime and GetTime() or 0) + 5
    if qualityRejection then
        self:SetStatus(T("COA_STATUS_REJECTING_QUALITY", "Declining order: the requested quality is unavailable within the finishing-reagent limit..."))
    else
        self:SetStatus(T("COA_STATUS_REJECTING_MISSING_REAGENTS", "Declining order: customer reagents are missing..."))
    end
    self:RefreshVisibleRows()

    local ok = SafeCall("RejectOrder", function()
        C_CraftingOrders.RejectOrder(order.orderID, "", profession)
    end)
    if not ok then
        self.rejectedOrderIDs[key] = nil
        self:SetStatus(T("COA_STATUS_REJECT_FAILED", "Could not decline the order."))
        self:RefreshVisibleRowsSoon()
        return false
    end

    self.selectedOrders[key] = nil
    self.orderIssues[key] = nil
    if self.currentQueueOrderID and SameOrderID(self.currentQueueOrderID, order.orderID) then
        self.currentQueueOrderID = nil
    end

    local recordRejected = _G.HironCraft
        and _G.HironCraft.RecordRejectedCraftingOrder
    if type(recordRejected) == "function" then
        local recorded, err = pcall(
            recordRejected,
            order,
            rejectionReason
        )
        if not recorded then
            self:DActionPrint("CraftScan rejection status failed:", err)
        end
    end

    if self.ClearOrderQualityRejection then
        self:ClearOrderQualityRejection(order)
    end
    if qualityRejection then
        self:SetStatus(T("COA_STATUS_REJECTED_QUALITY", "Order declined: the requested quality required a stronger finishing reagent."))
    else
        self:SetStatus(T("COA_STATUS_REJECTED_MISSING_REAGENTS", "Order declined: customer reagents were missing."))
    end
    self:UpdateControlPanel()
    self:RefreshPageSoon(0.35, not self:HasSelectedOrders())
    return true
end

function CO:ClaimOrder(order, pageFrame)
    if not order or not order.orderID then return false end
    pageFrame = self:FindOrderPageFrame(pageFrame) or self.activePageFrame or pageFrame
    if not self:IsAtUsableCraftingOrderTable(pageFrame) then
        self:SetStatus(T("COA_STATUS_TABLE_REQUIRED", "Crafting order table is required for this action."))
        return false
    end
    if self:GetRecipeKnownState(order) == false then
        self:SetStatus(T("COA_STATUS_UNKNOWN_RECIPE", "This recipe is not known by this character."))
        return false
    end

    -- Keep the destructive safety rule at the API boundary as well as in the
    -- row label. Queue refreshes and stale button state must never be able to
    -- claim an order that should have been declined.
    if self.ShouldRejectForMissingCustomerReagents
        and self:ShouldRejectForMissingCustomerReagents(order, pageFrame)
    then
        return self:RejectOrder(order, pageFrame)
    end

    local profession = GetProfessionFromPage(pageFrame)
    if not profession then
        self:SetStatus(T("COA_STATUS_NO_PROFESSION", "Profession is not available."))
        return false
    end

    self.rowStates[order.orderID] = self.rowStates[order.orderID] or {}
    self.rowStates[order.orderID].order = order
    self.rowStates[order.orderID].pageFrame = pageFrame
    self.orderIssues[OrderKey(order.orderID)] = nil
    self.currentQueueOrderID = order.orderID
    self.pendingClaimOrderID = order.orderID
    self.activeOrderID = order.orderID
    self.activePageFrame = pageFrame
    self:SetStatus(T("COA_STATUS_CLAIMING", "Claiming order..."))
    self:RefreshVisibleRows()

    local ok = SafeCall("ClaimOrder", function()
        C_CraftingOrders.ClaimOrder(order.orderID, profession)
    end)

    if not ok then
        self.pendingClaimOrderID = nil
        self:RefreshVisibleRowsSoon()
        return false
    end

    local requestedOrderID = order.orderID
    C_Timer.After(1.25, function()
        if not CO.pendingClaimOrderID or not SameOrderID(CO.pendingClaimOrderID, requestedOrderID) then
            return
        end

        local claimed = CO:GetClaimedOrder()
        if claimed and SameOrderID(claimed.orderID, requestedOrderID) then
            CO.pendingClaimOrderID = nil
            CO.rowStates[requestedOrderID] = CO.rowStates[requestedOrderID] or {}
            CO.rowStates[requestedOrderID].order = claimed
            CO:SetStatus(T("COA_STATUS_CLAIMED", "Order claimed."))
        else


            CO.pendingClaimOrderID = nil
            local state = CO.rowStates[requestedOrderID]
            if state and state.order then
                SetCachedOrderStateClaimed(state.order)
            end
        end

        CO:RefreshVisibleRows()
    end)

    return true
end

function CO:CraftOrderFromRow(order, pageFrame, btn)
    if not order or not order.orderID then return false end
    if self.GetEffectiveOrder then
        order = self:GetEffectiveOrder(order.orderID, order) or order
    end
    self:InvalidateOrderCaches(order.orderID)
    pageFrame = self:FindOrderPageFrame(pageFrame) or self.activePageFrame or pageFrame
    if not self:IsAtUsableCraftingOrderTable(pageFrame) then
        self:SetStatus(T("COA_STATUS_TABLE_REQUIRED", "Crafting order table is required for this action."))
        return false
    end
    if self:GetRecipeKnownState(order) == false then
        self:SetStatus(T("COA_STATUS_UNKNOWN_RECIPE", "This recipe is not known by this character."))
        return false
    end

    if self.CanSupplyCrafterReagentsForQueue and not self:CanSupplyCrafterReagentsForQueue(order, true) then
        local key = OrderKey(order.orderID)
        self.orderIssues[key] = T("COA_ACTION_NO_REAGENTS", "Missing reagents")
        self:SetStatus(T("COA_STATUS_NO_REAGENTS", "Cannot craft: missing reagents."))
        self:RefreshVisibleRowsSoon()
        return false
    end

    -- The craft only binds while C_CraftingOrders.GetClaimedOrder() actually returns this order.
    -- Right after claiming (fresh login / fast key presses) the claim is not yet registered
    -- server-side, GetClaimedOrder() is nil, and CraftOrder()/CraftRecipe() silently no-op —
    -- the row would then jam as "Crafting". Don't jam: bail cleanly and let the user retry once
    -- the claim lands (we nudge a refresh so the row keeps offering "craft").
    local claimed = self:GetClaimedOrder()
    if not (claimed and SameOrderID(claimed.orderID, order.orderID)) then
        self:DActionPrint("craft deferred: claim not registered yet (GetClaimedOrder="
            .. tostring(claimed and claimed.orderID) .. ")")
        self.orderIssues[OrderKey(order.orderID)] = nil
        self:SetStatus(T("COA_STATUS_CLAIM_NOT_READY", "Order is still being claimed — press craft again in a moment."))
        self:RefreshVisibleRowsSoon()
        return false
    end

    local engine, err = self:GetOrderEngine(pageFrame, order)
    if not engine then
        self:SetStatus(err)
        return false
    end

    self:ApplySelectedReagentsToEngine(engine, order)
    local useConcentration = self.useConcentration[OrderKey(order.orderID)] == true
    self:SetEngineConcentration(engine, useConcentration)

    if self.PrepareAutoFinishingReagent then
        local finisherResult, finisher = self:PrepareAutoFinishingReagent(
            engine,
            order,
            useConcentration,
            pageFrame
        )
        if finisherResult == "reject" then
            return self:RejectOrder(order, pageFrame, false, "insufficient_quality")
        elseif finisherResult == "applied" and finisher then
            self:SetStatus(string.format(
                T("COA_STATUS_FINISHER_APPLIED", "Finishing reagent +%d selected."),
                finisher.skillBonus or 0
            ))
        end
    end

    self.pendingCraftOrderID = order.orderID
    self.orderIssues[OrderKey(order.orderID)] = nil
    self.activeOrderID = order.orderID
    self.activePageFrame = pageFrame
    self.pendingCraftButton = btn
    self:SetStatus(T("COA_STATUS_CRAFTING", "Crafting order..."))
    self:StartRowProgress(btn, order.orderID)
    self:RefreshVisibleRows()

    -- Watchdog: self-heal a stuck "crafting" state if no completion event ever resolves it
    -- (otherwise the row is jammed as "Crafting" and reports "no available action" forever).
    do
        local co = self
        local watchID = order.orderID
        co._craftWatchToken = (co._craftWatchToken or 0) + 1
        local token = co._craftWatchToken
        if C_Timer then
            C_Timer.After(10, function()
                if co._craftWatchToken == token
                   and co.pendingCraftOrderID and SameOrderID(co.pendingCraftOrderID, watchID) then
                    co:DActionPrint("craft watchdog: clearing stuck 'crafting' state for order", watchID)
                    co.pendingCraftOrderID = nil
                    co.pendingCraftButton = nil
                    if co.progressOrderID and SameOrderID(co.progressOrderID, watchID) then
                        co.progressOrderID = nil
                    end
                    if co.StopRowProgress then co:StopRowProgress() end
                    if co.RefreshVisibleRowsSoon then co:RefreshVisibleRowsSoon() end
                    if co.UpdateControlPanel then co:UpdateControlPanel() end
                end
            end)
        end
    end


    local ok
    if order.isRecraft and engine.RecraftOrder then
        ok = SafeCall("RecraftOrder", function() engine:RecraftOrder() end)
    elseif engine.CraftOrder then
        ok = SafeCall("CraftOrder", function() engine:CraftOrder() end)
    end

    if not ok then
        local form = engine.OrderDetails and engine.OrderDetails.SchematicForm
        local transaction = form and ((form.GetTransaction and form:GetTransaction()) or form.transaction)
        local reagentTbl = transaction and transaction.CreateCraftingReagentInfoTbl and transaction:CreateCraftingReagentInfoTbl()
        local recipeLevel = form and form.GetCurrentRecipeLevel and form:GetCurrentRecipeLevel()

        if order.isRecraft and C_TradeSkillUI.RecraftRecipeForOrder then
            local itemGUID = order.outputItemGUID or order.recraftItemGUID or order.outputItemGUIDString
            ok = SafeCall("RecraftRecipeForOrder", function()
                C_TradeSkillUI.RecraftRecipeForOrder(order.orderID, itemGUID, reagentTbl, nil, useConcentration)
            end)
        elseif C_TradeSkillUI.CraftRecipe then
            ok = SafeCall("CraftRecipe", function()
                C_TradeSkillUI.CraftRecipe(order.spellID, 1, reagentTbl, recipeLevel, order.orderID, useConcentration)
            end)
        end
    end

    if (not ok) and engine.CreateButton and engine.CreateButton.GetScript then
        local script = engine.CreateButton:GetScript("OnClick")
        if script then
            ok = SafeCall("CreateButton", function()
                script(engine.CreateButton, "LeftButton")
            end)
        end
    end

    if not ok then
        self.pendingCraftOrderID = nil
        self.pendingCraftButton = nil
        self:StopRowProgress()
        self:SetStatus(T("COA_STATUS_NO_ENGINE", "Crafting order view is not available."))
        self:RefreshVisibleRowsSoon()
        return false
    end

    return true
end

function CO:FulfillOrder(order, pageFrame)
    if not order or not order.orderID then return false end
    pageFrame = self:FindOrderPageFrame(pageFrame) or self.activePageFrame or pageFrame
    if not self:IsAtUsableCraftingOrderTable(pageFrame) then
        self:SetStatus(T("COA_STATUS_TABLE_REQUIRED", "Crafting order table is required for this action."))
        return false
    end

    local profession = GetProfessionFromPage(pageFrame)
    if not profession then
        self:SetStatus(T("COA_STATUS_NO_PROFESSION", "Profession is not available."))
        return false
    end

    self.pendingFulfillOrderID = order.orderID
    self.currentQueueOrderID = order.orderID
    self.activeOrderID = order.orderID
    self.activePageFrame = pageFrame
    self:SetStatus(T("COA_STATUS_FULFILLING", "Completing order..."))
    self:RefreshVisibleRows()

    return SafeCall("FulfillOrder", function()
        C_CraftingOrders.FulfillOrder(order.orderID, "", profession)
    end)
end

function CO:RunRowButtonAction(btn)
    if not btn or not btn.orderID then return end

    self:SetActiveRowButton(btn)

    local action, _, order, enabled = self:GetRowAction(btn.orderID, btn.order)
    if not enabled then
        self:SetStatus(T("COA_STATUS_NO_ACTION", "No available action."))
        self:DiagnoseRowAction(btn)
        self:RefreshHoveredRowButtonTooltip(btn)
        return
    end

    if action == "reject" then
        self:RejectOrder(order, btn.pageFrame)
        return
    end

    if action == "claim" then
        self:ClaimOrder(order, btn.pageFrame)
        return
    end

    if action == "craft" then
        local pageFrame = self:FindOrderPageFrame(btn.pageFrame or btn:GetParent() or self.activePageFrame)
        btn.pageFrame = pageFrame or btn.pageFrame
        self:CraftOrderFromRow(order, pageFrame or btn.pageFrame, btn)
        return
    end

    if action == "fulfill" then
        self:FulfillOrder(order, btn.pageFrame)
        return
    end

    self:SetStatus(T("COA_STATUS_NO_ACTION", "No available action."))
    self:DiagnoseRowAction(btn)
end

function CO:RunActiveRowAction()


    if not self:HasSelectedOrders() then
        if self.HandleEmptyPersonalOrdersHotkey and self:HandleEmptyPersonalOrdersHotkey() then
            return
        end
        self:SetStatus(T("COA_STATUS_NO_SELECTED_ROW", "Check an order first."))
        return
    end

    local btn = self:GetQueueButton()
    if not btn then
        if self.HandleEmptyPersonalOrdersHotkey and self:HandleEmptyPersonalOrdersHotkey() then
            return
        end
        self:SetStatus(T("COA_STATUS_NO_SELECTED_ROW", "No selected visible order."))
        return
    end

    if not self:IsOrderSelected(btn.orderID) then
        self:SetStatus(T("COA_STATUS_NO_SELECTED_ROW", "Check an order first."))
        return
    end

    self:RunRowButtonAction(btn)
end

function CO:StartRowProgress(btn, orderID)
    if not orderID then return end

    if btn and btn.orderID and not SameOrderID(btn.orderID, orderID) then
        btn = self:GetVisibleButtonForOrder(orderID)
    end

    if self.pendingCraftOrderID and SameOrderID(self.pendingCraftOrderID, orderID) then
        self.pendingCraftButton = btn
    end

    if self.progressButton and self.progressButton ~= btn then
        self.progressButton:SetScript("OnUpdate", nil)
        self:HideRowProgressVisual(self.progressButton)
    end

    self.progressButton = btn
    self.progressOrderID = orderID
    self.currentQueueOrderID = orderID
    self.activeOrderID = orderID
    self.progressStartedAt = GetTime()
    self.progressActive = true

    if btn then
        self:SyncRowActionButtonLayers(nil, btn)
        self:ShowRowProgressVisual(btn, 0.02)
        self:StartRowProgressTicker()
        self:UpdateRowButton(btn)
    else
        self:StartRowProgressTicker()
    end
end

function CO:StopRowProgress()
    local btn = self.progressButton
    local orderID = self.progressOrderID
    self.progressActive = false
    self.progressOrderID = nil
    self.progressButton = nil
    self:StopRowProgressTicker()
    self:HideRowProgressVisual(btn)

    local function clearButton(b)
        if not b then return end
        b:SetScript("OnUpdate", nil)
        CO:HideRowProgressVisual(b)
    end

    clearButton(btn)

    if orderID then
        for visibleBtn in pairs(self.visibleRowButtons or {}) do
            if visibleBtn and visibleBtn ~= btn and visibleBtn.orderID and SameOrderID(visibleBtn.orderID, orderID) then
                clearButton(visibleBtn)
            end
        end
    end
end

function CO:FindProgressButton()
    if self.progressButton then
        local visible = self.progressButton.IsVisible and self.progressButton:IsVisible() or self.progressButton:IsShown()
        local sameOrder = self.progressOrderID
            and self.progressButton.orderID
            and SameOrderID(self.progressButton.orderID, self.progressOrderID)
        if visible and sameOrder then
            return self.progressButton
        end

        self:HideRowProgressVisual(self.progressButton)
        self.progressButton = nil
    end

    if not self.progressOrderID then return nil end

    local btn = self:GetVisibleButtonForOrder(self.progressOrderID)
    if btn then
        self.progressButton = btn
        self:SyncRowActionButtonLayers(nil, btn)
        return btn
    end

    self:HideRowProgressVisual()
    return nil
end

function CO:UpdateRowProgress()
    local btn = self:FindProgressButton()
    if not btn then
        local keep = self.progressStartedAt and (GetTime() - self.progressStartedAt) < 30
        if not keep and self.progressOrderID then
            keep = (self.pendingCraftOrderID and SameOrderID(self.pendingCraftOrderID, self.progressOrderID))
                or (self.pendingCraftButton and self.pendingCraftButton.orderID and SameOrderID(self.pendingCraftButton.orderID, self.progressOrderID))
        end
        if not keep then
            self:StopRowProgress()
        end
        return
    end

    local name, _, _, startMS, endMS = UnitCastingInfo("player")
    if not name then
        name, _, _, startMS, endMS = UnitChannelInfo("player")
    end

    if name and startMS and endMS and endMS > startMS then
        local nowMS = GetTime() * 1000
        local value = (nowMS - startMS) / (endMS - startMS)
        if value < 0 then value = 0 elseif value > 1 then value = 1 end
        self:SyncRowActionButtonLayers(nil, btn)
        self:ShowRowProgressVisual(btn, value)
        return
    end

    local keepFallback = self.progressStartedAt and (GetTime() - self.progressStartedAt) < 30
    if not keepFallback and self.progressOrderID then
        keepFallback = (self.pendingCraftOrderID and SameOrderID(self.pendingCraftOrderID, self.progressOrderID))
            or (self.pendingCraftButton and self.pendingCraftButton.orderID and SameOrderID(self.pendingCraftButton.orderID, self.progressOrderID))
    end

    if keepFallback then
        self:SyncRowActionButtonLayers(nil, btn)
        self:ShowRowProgressVisual(btn, btn.ahuiProgressValue or 0.02)
        return
    end

    self:StopRowProgress()
end

function CO:ProtectOrderRowSoon(row, btn)
    if not row or not btn then return end

    local function protect()
        if not CO:IsEnabled() then return end
        if row and row.ahuiOrderActionButton == btn and btn:IsShown() then
            CO:HideBlizzardColumnsUnderHironCraftProfit(row)
            CO:SyncRowActionButtonLayers(row, btn)
            if row.ahuiOrderReagentsFrame then row.ahuiOrderReagentsFrame:SetFrameLevel((row:GetFrameLevel() or 1) + 75) end
            if row.ahuiOrderRewardsFrame then row.ahuiOrderRewardsFrame:SetFrameLevel((row:GetFrameLevel() or 1) + 75) end
            if row.ahuiOrderFocusFrame then row.ahuiOrderFocusFrame:SetFrameLevel((row:GetFrameLevel() or 1) + 75) end
            if row.ahuiOrderProfitFrame then row.ahuiOrderProfitFrame:SetFrameLevel((row:GetFrameLevel() or 1) + 75) end
            if CO.SyncRowStateBackgroundLayers then CO:SyncRowStateBackgroundLayers(row) end
        end
    end

    protect()
    if C_Timer and not row.ahuiOrderProtectQueued then
        row.ahuiOrderProtectQueued = true
        C_Timer.After(0.06, function()
            row.ahuiOrderProtectQueued = nil
            protect()
        end)
    end
end

function CO:EnsureRowHoverHighlight(row)
    if not row then return nil end
    if row.ahuiOrderHoverHighlight then return row.ahuiOrderHoverHighlight end

    local h = CreateFrame("Frame", nil, row, "BackdropTemplate")
    h.ahuiCraftingOrdersOwned = true
    h:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    h:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    h:SetFrameLevel((row:GetFrameLevel() or 1) + 21)
    h:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    h:SetBackdropColor(0.95, 0.78, 0.35, ROW_HOVER_ALPHA)
    h:SetBackdropBorderColor(0.95, 0.78, 0.35, ROW_HOVER_BORDER_ALPHA)
    h:Hide()

    row.ahuiOrderHoverHighlight = h
    return h
end

function CO:SetRowHover(row, shown)
    local h = self:EnsureRowHoverHighlight(row)
    if h then h:SetShown(shown == true) end
end

function CO:DecorateOrderRow(row, elementData)
    if not row then return end
    if self:IsEnabled() then self:LockOrderTableColumns() end

    if not self:IsEnabled() then
        self:HideOrderRowOverlays(row)
        return
    end

    if self.CustomList and self.CustomList._listActive then
        self:HideOrderRowOverlays(row)
        return
    end

    local order = elementData and elementData.option or row.option
    if not order or not order.orderID then
        RestoreHiddenOrderRowRegions(row)
        if row.ahuiOrderOriginalHeight and row.SetHeight then row:SetHeight(row.ahuiOrderOriginalHeight); row.ahuiOrderTallRow = false end
        if row.cells then
            for _, cell in ipairs(row.cells) do
                if cell and cell.ahuiOrderOriginalHeight and cell.SetHeight then
                    cell:SetHeight(cell.ahuiOrderOriginalHeight)
                end
            end
        end
        if row.ahuiOrderActionButton then
            local oldKey = OrderKey(row.ahuiOrderActionButton.orderID)
            if oldKey and self.rowButtonsByOrderID and self.rowButtonsByOrderID[oldKey] == row.ahuiOrderActionButton then
                self.rowButtonsByOrderID[oldKey] = nil
            end
            if self.pendingCraftButton == row.ahuiOrderActionButton then
                self.pendingCraftButton = nil
            end
            if self.progressButton == row.ahuiOrderActionButton then
                self:HideRowProgressVisual(row.ahuiOrderActionButton)
                self.progressButton = nil
            end
            row.ahuiOrderActionButton.orderID = nil
            row.ahuiOrderActionButton.order = nil
            row.ahuiOrderActionButton:Hide()
        end
        if row.ahuiOrderReagentsFrame then row.ahuiOrderReagentsFrame:Hide() end
        if row.ahuiOrderRewardsFrame then row.ahuiOrderRewardsFrame:Hide() end
        if row.ahuiOrderFocusFrame then row.ahuiOrderFocusFrame:Hide() end
        if row.ahuiOrderProfitFrame then row.ahuiOrderProfitFrame:Hide() end
        if row.ahuiUnknownRecipeBorder then row.ahuiUnknownRecipeBorder:Hide() end
        if row.ahuiCraftableOrderBorder then row.ahuiCraftableOrderBorder:Hide() end
        if row.ahuiConcentrationRequiredBorder then row.ahuiConcentrationRequiredBorder:Hide() end
        return
    end

    self.activePageFrame = row.pageFrame or (elementData and elementData.pageFrame) or self.activePageFrame
    self:EnsurePageBindingHooks(self.activePageFrame)
    self:EnsureControlPanel(self.activePageFrame)
    self:UpdateControlPanelVisibility(self.activePageFrame)
    self:ProtectOrderHeaderLabels(self.activePageFrame)

    local btn = row.ahuiOrderActionButton
    if not btn then
        btn = self:CreateTextButton(row, nil, ROW_BUTTON_W, ROW_BUTTON_H, "")
        btn.ahuiCraftingOrdersOwned = true
        if btn.text then btn.text.ahuiCraftingOrdersOwned = true end
        btn:SetPoint("RIGHT", row, "RIGHT", -5, 0)
        btn:SetFrameLevel((row:GetFrameLevel() or 1) + 30)

        local check = CreateFrame("CheckButton", nil, btn, "UICheckButtonTemplate")
        check.ahuiCraftingOrdersOwned = true
        check:SetSize(ROW_CHECKBOX_SIZE, ROW_CHECKBOX_SIZE)
        check:SetPoint("LEFT", btn, "LEFT", 1, 0)
        check:SetFrameLevel((btn:GetFrameLevel() or 1) + 2)
        if check.SetHitRectInsets then
            local pad = ROW_CHECKBOX_HIT_PAD or 0
            check:SetHitRectInsets(-pad, -pad, -pad, -pad)
        end
        btn.text:ClearAllPoints()
        btn.text:SetPoint("LEFT", check, "RIGHT", -1, 0)
        btn.text:SetPoint("RIGHT", btn, "RIGHT", -3, 0)
        btn.text:SetJustifyH("CENTER")
        btn.text:SetWidth(math.max(1, ROW_BUTTON_W - ROW_CHECKBOX_SIZE - 4))
        btn:SetScript("OnMouseDown", nil)
        btn:SetScript("OnMouseUp", nil)
        check:SetScript("OnClick", function(self)
            local parentBtn = self.ahuiOrderButton
            if parentBtn and parentBtn.orderID then
                CO:SetOrderSelected(parentBtn.orderID, self:GetChecked())
                CO:ShowRowButtonTooltip(parentBtn)
            end
        end)
        check:SetScript("OnEnter", function(self)
            local parentBtn = self.ahuiOrderButton
            if parentBtn then
                CO:SetActiveRowButton(parentBtn)
                CO:SetRowHover(parentBtn:GetParent(), true)
                CO:ShowRowButtonTooltip(parentBtn)
            end
        end)
        check:SetScript("OnLeave", function(self)
            local parentBtn = self.ahuiOrderButton
            if parentBtn then CO:SetRowHover(parentBtn:GetParent(), false) end
            HideStyledTooltip()
        end)
        check:HookScript("OnHide", HideStyledTooltip)
        check.ahuiOrderButton = btn
        btn.check = check

        btn.bar = CreateFrame("StatusBar", nil, btn)
        btn.bar.ahuiCraftingOrdersOwned = true
        btn.bar:SetPoint("BOTTOMLEFT", 1, 1)
        btn.bar:SetPoint("BOTTOMRIGHT", -1, 1)
        btn.bar:SetHeight(3)
        btn.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
        btn.bar:SetStatusBarColor(0.95, 0.78, 0.35, 0.95)
        btn.bar:SetMinMaxValues(0, 1)
        btn.bar:SetValue(0)
        btn.bar:EnableMouse(false)
        self:SyncRowActionButtonLayers(row, btn)
        btn.bar:Hide()

        btn:SetScript("OnClick", function(self, mouseButton)
            CO:SetActiveRowButton(self)
            HideStyledTooltip()

            if mouseButton == "RightButton" then
                CO:ReleaseOrder(self.order, self.pageFrame)
                C_Timer.After(0.05, function()
                    if self and self:IsShown() and IsFrameMouseOver(self) then
                        CO:ShowRowButtonTooltip(self)
                    end
                end)
                return
            end

            CO:RunRowButtonAction(self)
            C_Timer.After(0.05, function()
                if self and self:IsShown() and IsFrameMouseOver(self) then
                    CO:ShowRowButtonTooltip(self)
                end
            end)
        end)

        btn:SetScript("OnEnter", function(self)
            CO:SetActiveRowButton(self)
            CO:SetRowHover(self:GetParent(), true)
            CO:ShowRowButtonTooltip(self)
        end)

        btn:SetScript("OnLeave", function(self)
            CO:SetRowHover(self:GetParent(), false)
            HideStyledTooltip()
        end)
        btn:HookScript("OnHide", HideStyledTooltip)
        row.ahuiOrderActionButton = btn
    end

    local oldOrderID = btn.orderID
    if oldOrderID and not SameOrderID(oldOrderID, order.orderID) then
        local oldKey = OrderKey(oldOrderID)
        if oldKey and self.rowButtonsByOrderID and self.rowButtonsByOrderID[oldKey] == btn then
            self.rowButtonsByOrderID[oldKey] = nil
        end

        if self.pendingCraftButton == btn then
            self.pendingCraftButton = nil
        end

        if self.progressButton == btn then
            self:HideRowProgressVisual(btn)
            self.progressButton = nil
        end
    end

    btn.orderID = order.orderID
    btn.order = order
    btn.pageFrame = row.pageFrame or (elementData and elementData.pageFrame)

    self:EnsureOrderColumnFrames(row, btn, order)
    if btn.check then
        btn.check.ahuiOrderButton = btn
        btn.check:SetChecked(self:IsOrderSelected(order.orderID))
    end
    self.rowButtonsByOrderID[OrderKey(order.orderID)] = btn
    self:EnsurePageBindingHooks(btn.pageFrame)
    self.visibleRowButtons[btn] = true
    self.rowStates[order.orderID] = self.rowStates[order.orderID] or {}
    self.rowStates[order.orderID].order = self.rowStates[order.orderID].order or order
    self.rowStates[order.orderID].pageFrame = btn.pageFrame
    self:EnsureRowHoverHighlight(row)
    self:UpdateUnknownRecipeBorder(row, order)

    btn:Show()
    self:SyncRowActionButtonLayers(row, btn)
    self:UpdateRowButton(btn)
    self:ProtectOrderRowSoon(row, btn)
end


function CO:GetOrderViewAction(orderView)
    if not orderView or not orderView.order then
        return "none", T("COA_ACTION_NONE", "No action"), nil
    end

    if orderView.CompleteOrderButton and orderView.CompleteOrderButton:IsShown() then
        return "fulfill", T("COA_ACTION_FULFILL", "Complete"), orderView.CompleteOrderButton
    end

    if orderView.CreateButton and orderView.CreateButton:IsShown() then
        if orderView.order and orderView.order.isRecraft then
            return "craft", T("COA_ACTION_RECRAFT", "Recraft"), orderView.CreateButton
        end
        return "craft", T("COA_ACTION_CRAFT", "Craft"), orderView.CreateButton
    end

    if orderView.OrderInfo and orderView.OrderInfo.StartOrderButton and orderView.OrderInfo.StartOrderButton:IsShown() then
        return "claim", T("COA_ACTION_CLAIM", "Claim"), orderView.OrderInfo.StartOrderButton
    end

    return "none", T("COA_ACTION_NONE", "No action"), nil
end

function CO:DecorateOrderView(orderView)
    if not orderView or orderView.ahuiCraftingOrdersReady then return end
    orderView.ahuiCraftingOrdersReady = true

    local btn = self:CreateTextButton(orderView, "HironCraftProfitCraftingOrdersActionButton", 154, 30, T("COA_ACTION_NONE", "No action"))
    btn:SetPoint("BOTTOMRIGHT", orderView, "BOTTOMRIGHT", -28, 22)
    btn:SetFrameLevel((orderView:GetFrameLevel() or 1) + 20)
    btn:SetScript("OnClick", function()
        if not orderView.order then return end
        local fake = {
            orderID = orderView.order.orderID,
            order = orderView.order,
            pageFrame = orderView:GetParent(),
            IsShown = function() return true end,
        }
        CO:RunRowButtonAction(fake)
    end)

    btn:Hide()
end

function HironCraftProfitGetCraftingOrderBrowseType(pageFrame)
    if pageFrame and pageFrame.GetBrowseType then
        return pageFrame:GetBrowseType()
    end
    return nil
end
