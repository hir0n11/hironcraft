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

-- rule is given for a check the queue made: 'profit' or 'knowledge', the
-- threshold the order passed. A check made by hand has none. profit is what
-- the order showed at that moment, kept to tell afterwards why it was checked.
function CO:RememberOrderSelection(orderID, checked, order, rule, profit)
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
        rule=checked == true and rule or nil,
        profit=checked == true and rule and tonumber(profit) or nil,
    }
end

-- A check the queue made stands only while the order passes the rule it was
-- checked under, at the profit its row shows now. Both sides move after the
-- check is made. Prices: a saved price is the cheapest lot of the day it was
-- seen, on a thin market that lot is gone by the next visit, and the shopping
-- scan brings today's price right after the queue has been filled from the
-- old one. Thresholds: the crafter changes them. A check made by hand has no
-- rule and is never taken away, and neither is an order already claimed.
-- An order whose reagents are already in the bags keeps its check when it is
-- a price that moved: buying them is what takes the cheap lots away and
-- raises the price, and the purchase is made. A changed threshold (strict)
-- applies to it as to any other.
-- Returns how many checks were dropped. A dropped order is not remembered as
-- unchecked by hand, so a later automatic pass may take it again.
function CO:DropQueuedSelectionsBelowProfit(orders, strict)
    local bucket = self._orderSelectionBucket
    if not bucket or not self.OrderPassesQueueProfitRule then return 0 end
    if self.IsOrderActionInProgress and self:IsOrderActionInProgress() then return 0 end
    if type(orders) ~= 'table' and C_CraftingOrders and C_CraftingOrders.GetCrafterOrders then
        local ok, list = pcall(C_CraftingOrders.GetCrafterOrders)
        orders = ok and list or nil
    end
    if type(orders) ~= 'table' then return 0 end
    local claimed = self.GetClaimedOrder and self:GetClaimedOrder()
    local dropped = 0
    for _, order in ipairs(orders) do
        local key = type(order) == 'table' and OrderKey(order.orderID)
        local choice = key and bucket.choices[key]
        if choice and choice.checked == true and choice.rule and self.selectedOrders[key]
            and not (claimed and SameOrderID(claimed.orderID, order.orderID))
            and not self:OrderPassesQueueProfitRule(order, choice.rule == 'knowledge')
            and (strict or not (self.CanSupplyCrafterReagentsForQueue and self:CanSupplyCrafterReagentsForQueue(order, false)))
        then
            self.selectedOrders[key] = nil
            bucket.choices[key] = nil
            if self.currentQueueOrderID and SameOrderID(self.currentQueueOrderID, order.orderID) then
                self.currentQueueOrderID = nil
            end
            dropped = dropped + 1
        end
    end
    return dropped
end

function CO:IsOrderManuallyExcluded(orderID)
    local choice = self._orderSelectionBucket and self._orderSelectionBucket.choices[OrderKey(orderID)]
    return choice and choice.checked == false or false
end

function CO:RestoreOrderSelection(pageFrame, orders)
    local bucket = self:EnsureOrderSelectionContext(pageFrame)
    if not bucket or type(orders) ~= 'table' then return end
    local present = {}
    -- A Personal order that arrives while the list is already open used to
    -- stay unchecked (the automatic selection ran only when opening), so the
    -- queue skipped it. Select such new orders the same way; an explicit
    -- uncheck is remembered as checked=false and still wins.
    local personalType = Enum and Enum.CraftingOrderType and Enum.CraftingOrderType.Personal
    local autoSelectNew = personalType ~= nil and pageFrame and pageFrame.orderType == personalType
        and self.IsOneButtonPersonalEnabled and self:IsOneButtonPersonalEnabled()
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
            if not choice and autoSelectNew then
                self:RememberOrderSelection(order.orderID, true, order)
                choice = bucket.choices[key]
                self.currentQueueOrderID = self.currentQueueOrderID or order.orderID
            end
            if choice then
                choice.updatedAt = Now()
                self.selectedOrders[key] = choice.checked == true or nil
            end
        end
    end
    local inFlight = self.IsOrderActionInProgress and self:IsOrderActionInProgress()
    for key in pairs(self.selectedOrders) do
        -- Claim/craft refreshes can briefly expose an empty/partial API list.
        -- Completion handlers remove the actual finished order explicitly.
        if not present[key] and not inFlight then self.selectedOrders[key] = nil end
    end
    if self.currentQueueOrderID and not self:IsOrderSelected(self.currentQueueOrderID) then
        self.currentQueueOrderID = nil
    end
    -- A check remembered from an earlier look at the list was made at the
    -- prices and thresholds of that moment.
    if self.RecheckQueuedSelections then self:RecheckQueuedSelections(orders) end
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
