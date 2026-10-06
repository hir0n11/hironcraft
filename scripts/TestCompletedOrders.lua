-- Successful completion must beat stale list/claimed-order snapshots. Real
-- action/event handlers run against fake APIs: no in-game action is performed.
if not setfenv then
    function setfenv(fn, env)
        if type(fn) == 'number' then fn = debug.getinfo(fn + 1, 'f').func end
        for i = 1, 100 do
            local name = debug.getupvalue(fn, i)
            if not name then return fn end
            if name == '_ENV' then
                debug.upvaluejoin(fn, i, function() return env end, 1)
                return fn
            end
        end
    end
end
local function noop() end
local CO = {rowStates={}, orderIssues={}, selectedOrders={}}
local page, claimed, sent, touched = {}, nil, 0, 0
SlashCmdList={}
local E = setmetatable({
    CO=CO, PT={},
    T=function(_, fallback) return fallback end,
    SameOrderID=function(a,b) return a ~= nil and b ~= nil and tostring(a) == tostring(b) end,
    OrderKey=function(id) return id and tostring(id) end,
    IsOrderCreated=function(order) return order and order.orderState == 1 end,
    IsOrderClaimed=function(order) return order and order.orderState == 2 end,
    GetProfessionFromPage=function() return 164 end,
    SafeCall=function(_, fn) return pcall(fn) end,
    GetTime=function() return 100 end,
    Enum={CraftingOrderResult={Ok=0}},
    C_Timer={After=noop},
    CreateFrame=function() return {RegisterEvent=noop, SetScript=noop} end,
    C_CraftingOrders={
        GetClaimedOrder=function() return claimed end,
        FulfillOrder=function() sent=sent+1 end,
    },
}, {__index=_G})
HironCraftProfitCraftingOrdersEnv=E
dofile('ProfitHub/Orders/CraftingOrders/QualityReagents.lua')
dofile('ProfitHub/Orders/CraftingOrders/Actions.lua')
CO.CreateHotkeyProxy, CO.HookBlizzardProfessions, CO.ApplyEnabledState=noop, noop, noop
dofile('ProfitHub/Orders/CraftingOrders/HooksEvents.lua')
CO.FindOrderPageFrame=function() return page end
CO.GetRecipeKnownState=function() return true end
CO.IsAtUsableCraftingOrderTable=function() return true end
CO.ShouldRejectForMissingCustomerReagents=function() return false end
CO.IsOrderReadyForQualityRejection=function() return false end
CO.SetStatus=function(_, value) CO.lastStatus=value end
CO.SetActiveRowButton=function() touched=touched+1 end
CO.HasSelectedOrders=function() return next(CO.selectedOrders) ~= nil end
for _, name in ipairs({'InvalidateOrderCaches','RefreshVisibleRows','RefreshVisibleRowsSoon',
    'StopRowProgress','UpdateControlPanel','RefreshPageSoon','DiagnoseRowAction',
    'RefreshHoveredRowButtonTooltip'}) do CO[name]=noop end

for _, orderType in ipairs({1,2,3,4}) do
    for _, removalFirst in ipairs({false,true}) do
        local id=880000+orderType
        local order={orderID=id, orderState=2, isFulfillable=true, orderType=orderType}
        local button={orderID=id, order=order, pageFrame=page}
        page.orderType=orderType
        claimed=order
        CO.rowStates={[id]={order=order}}
        CO.fulfilledOrderIDs={}
        CO.selectedOrders={[tostring(id)]=true}
        local previous=sent
        assert(CO:FulfillOrder(order,page))
        assert(sent==previous+1 and CO.pendingFulfillOrderID==id)
        assert(not CO:FulfillOrder(order,page) and sent==previous+1,
            'direct repeat while completion was pending sent a second request')
        local pendingTouched=touched
        CO:RunRowButtonAction(button)
        assert(sent==previous+1 and touched==pendingTouched,
            'repeat button press while pending changed the active target')

        -- A failed response is not final: a new hardware click may retry.
        CO:OnEvent('CRAFTINGORDERS_FULFILL_ORDER_RESPONSE', 1, id)
        assert(not CO.pendingFulfillOrderID and not CO.fulfilledOrderIDs[id])
        assert(CO:FulfillOrder(order,page) and sent==previous+2)
        claimed=nil
        if removalFirst then CO:OnEvent('CRAFTINGORDERS_CLAIMED_ORDER_REMOVED') end
        CO:OnEvent('CRAFTINGORDERS_FULFILL_ORDER_RESPONSE', 0, id)
        if not removalFirst then CO:OnEvent('CRAFTINGORDERS_CLAIMED_ORDER_REMOVED') end
        assert(CO.fulfilledOrderIDs[id] and not CO.pendingFulfillOrderID)

        for _, staleClaim in ipairs({false,true}) do
            claimed=staleClaim and order or nil
            for _, lookupID in ipairs({id,tostring(id)}) do
                local _,_,_,enabled=CO:GetRowAction(lookupID,order)
                assert(not enabled, 'completed order exposed another action from a stale snapshot')
            end
            local priorTouched=touched
            CO:RunRowButtonAction(button)
            assert(sent==previous+2 and touched==priorTouched,
                'a stale row click changed the active target or sent another completion')
            assert(not CO:FulfillOrder(order,page) and sent==previous+2,
                'completed order reached the API through a direct call')
        end
        -- Accept the normalized string-key form used by other order state.
        CO.fulfilledOrderIDs={[tostring(id)]=true}
        assert(not select(4,CO:GetRowAction(id,order)))
        assert(not CO:FulfillOrder(order,page))
        claimed=nil
        local nextOrder={orderID=id+100,orderState=1,orderType=orderType}
        local action,_,_,enabled=CO:GetRowAction(nextOrder.orderID,nextOrder)
        assert(action=='claim' and enabled, 'completion disabled an unrelated fresh order')
    end
end
-- A synchronous API exception produces no response event to clear pending
-- state. It must also leave the next explicit retry available.
local failedOrder={orderID=889999,orderState=2,isFulfillable=true}
local submit=E.C_CraftingOrders.FulfillOrder
E.C_CraftingOrders.FulfillOrder=function() error('submission failed') end
assert(not CO:FulfillOrder(failedOrder,page) and not CO.pendingFulfillOrderID,
    'API exception left completion permanently pending')
assert(not CO:IsOrderFulfilled(failedOrder.orderID))
E.C_CraftingOrders.FulfillOrder=submit
local beforeRetry=sent
assert(CO:FulfillOrder(failedOrder,page) and sent==beforeRetry+1,
    'an API exception disabled the next explicit retry')
print('Completed order action/event checks passed (all tabs, both event orders, stale data, retry).')
