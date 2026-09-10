local E = _G.HironCraftProfitCraftingOrdersEnv
if not E then return end
setfenv(1, E)
if not PT or not CO then return end

local function Now()
    return GetServerTime and GetServerTime() or time()
end

function CO:GetOrderSelectionContext(pageFrame)
    pageFrame = pageFrame or self.activePageFrame or self:FindOrderPageFrame()
    local owner = UnitGUID and UnitGUID('player')
    local profession = pageFrame and GetProfessionFromPage(pageFrame)
    if not owner or not profession or not pageFrame.orderType then return end
    local expansion = self.GetSelectedProfessionExpansionKey and self:GetSelectedProfessionExpansionKey() or 'current'
    local scope = table.concat({tostring(profession), tostring(pageFrame.orderType), expansion}, ':')
    return owner .. ':' .. scope, owner, scope
end

function CO:EnsureOrderSelectionContext(pageFrame)
    local context, owner, scope = self:GetOrderSelectionContext(pageFrame)
    if not context then return end
    if context == self._orderSelectionContext then return self._orderSelectionBucket end
    if self.CancelQueueSelection then self:CancelQueueSelection() end
    self._autoRanForOpen = false
    self._autoQueueStamp = (self._autoQueueStamp or 0) + 1
    local db = GetDB()
    db.orderSelections = db.orderSelections or {}
    db.orderSelections[owner] = db.orderSelections[owner] or {}
    local scopes = db.orderSelections[owner]
    scopes[scope] = scopes[scope] or { choices={} }
    local bucket = scopes[scope]
    bucket.choices = bucket.choices or {}
    -- Missing/expired orders never enter the active selection. Keep their
    -- decisions briefly in case a filtered or still-loading list omitted them.
    local cutoff = Now() - 30 * 24 * 60 * 60
    for _, saved in pairs(scopes) do
        for id, choice in pairs(saved.choices or {}) do
            if type(choice) ~= 'table' or (tonumber(choice.updatedAt) or 0) < cutoff then
                saved.choices[id] = nil
            end
        end
    end
    self._orderSelectionContext, self._orderSelectionBucket = context, bucket
    wipe(self.selectedOrders)
    self.currentQueueOrderID, self.currentQueueStep = nil, nil
    return bucket
end

function CO:RememberOrderSelection(orderID, checked, order)
    local bucket = self._orderSelectionBucket
    local key = OrderKey(orderID)
    if not bucket or not key then return end
    local previous = bucket.choices[key]
    local state = self.rowStates and (self.rowStates[orderID] or self.rowStates[tonumber(orderID)])
    order = order or (state and state.order)
    bucket.choices[key] = {
        checked=checked == true,
        spellID=order and order.spellID or (previous and previous.spellID),
        updatedAt=Now(),
    }
end

function CO:IsOrderManuallyExcluded(orderID)
    local choice = self._orderSelectionBucket and self._orderSelectionBucket.choices[OrderKey(orderID)]
    return choice and choice.checked == false or false
end

function CO:RestoreOrderSelection(pageFrame, orders)
    local bucket = self:EnsureOrderSelectionContext(pageFrame)
    if not bucket or type(orders) ~= 'table' then return end
    local present = {}
    for _, order in ipairs(orders) do
        local key = OrderKey(order.orderID)
        if key and (not order.orderType or order.orderType == pageFrame.orderType)
            and not (self.fulfilledOrderIDs and self.fulfilledOrderIDs[order.orderID]) then
            present[key] = true
            local choice = bucket.choices[key]
            if choice and choice.spellID and order.spellID and choice.spellID ~= order.spellID then
                bucket.choices[key], choice = nil, nil
                self.selectedOrders[key] = nil
            end
            if choice then
                choice.updatedAt = Now()
                self.selectedOrders[key] = choice.checked == true or nil
            end
        end
    end
    for key in pairs(self.selectedOrders) do
        if not present[key] then self.selectedOrders[key] = nil end
    end
    if self.currentQueueOrderID and not self:IsOrderSelected(self.currentQueueOrderID) then
        self.currentQueueOrderID = nil
    end
end

function CO:ForgetCompletedOrderSelection(orderID)
    local key = OrderKey(orderID)
    local owner = UnitGUID and UnitGUID('player')
    local all = GetDB().orderSelections
    if not key or not owner or not all or not all[owner] then return end
    -- Completion can arrive just after a tab switch. Clear its original saved
    -- choice as well; never resurrect it when returning to that tab.
    for _, bucket in pairs(all[owner]) do
        local choice = bucket.choices and bucket.choices[key]
        if choice then choice.checked=false; choice.updatedAt=Now() end
    end
end
