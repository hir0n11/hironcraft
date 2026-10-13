-- Native buttons and addon buttons receive the same server responses. Retire
-- only the successful ID, even with two identical items for one customer.
dofile('scripts/TestCompletedOrders.lua')
local E = HironCraftProfitCraftingOrdersEnv
local CO = E.CO
local refreshed = 0
CO.RefreshPersonalOrdersAfterTerminalAction = function() refreshed = refreshed + 1 end
local function order(id)
    return {orderID=id,spellID=501,customerName='Same-Realm',orderState=1,orderType=3}
end
local a,b=order(100001),order(100002)
E.C_CraftingOrders.GetClaimedOrder=function() return nil end
CO.pendingFulfillOrderID,CO.terminalAction=nil,nil
CO.rowStates={[a.orderID]={order=a},[b.orderID]={order=b}}
CO.selectedOrders={['100001']=true,['100002']=true}
CO.currentQueueOrderID=a.orderID
CO:OnEvent('CRAFTINGORDERS_REJECT_ORDER_RESPONSE',1,a.orderID)
assert(CO.selectedOrders['100001'] and CO.rowStates[a.orderID], 'failed decline removed a valid order')
CO:OnEvent('CRAFTINGORDERS_REJECT_ORDER_RESPONSE',0,tostring(a.orderID))
assert(not CO.selectedOrders['100001'] and CO.selectedOrders['100002'], 'native decline kept its selection or removed its sibling')
assert(not select(4,CO:GetRowAction(a.orderID,a)), 'successful native decline remained actionable')
assert(select(4,CO:GetRowAction(b.orderID,b)), 'decline disabled the other identical order')
assert(not CO.rowStates[a.orderID] and CO.rowStates[b.orderID], 'native decline kept a stale row state')
assert(not CO.currentQueueOrderID and refreshed==1, 'native decline did not refresh the remaining orders')

-- A delayed response for A cannot disturb an ongoing craft of B.
CO.pendingCraftOrderID=b.orderID;CO.progressOrderID=b.orderID;CO.progressActive=true
CO.currentQueueOrderID=b.orderID;CO.lastStatus='crafting B'
CO:OnEvent('CRAFTINGORDERS_REJECT_ORDER_RESPONSE',0,a.orderID)
assert(CO.pendingCraftOrderID==b.orderID and CO.progressActive and CO.currentQueueOrderID==b.orderID)
assert(CO.lastStatus=='crafting B' and refreshed==1, 'duplicate decline interrupted the next order')
CO.pendingCraftOrderID,CO.progressOrderID,CO.progressActive=nil,nil,nil

-- Completion through Blizzard has no addon-owned terminalAction. It must
-- still retire B, and failure must keep retry possible.
CO:OnEvent('CRAFTINGORDERS_FULFILL_ORDER_RESPONSE',1,b.orderID)
assert(CO.selectedOrders['100002'] and not CO:IsOrderFulfilled(b.orderID))
CO:OnEvent('CRAFTINGORDERS_FULFILL_ORDER_RESPONSE',0,b.orderID)
assert(CO:IsOrderFulfilled(b.orderID) and not CO.selectedOrders['100002'], 'native completion was ignored')
assert(not select(4,CO:GetRowAction(b.orderID,b)), 'native completion revived an actionable row')
assert(not CO.rowStates[b.orderID], 'native completion kept a stale row state')
assert(refreshed==2, 'native completion did not refresh the remaining orders')

-- Releasing is not declining: clear the old Claimed cache so a fresh Created
-- snapshot offers Claim again, without marking the ID terminal or touching B.
dofile('Workflow/Orders/CraftingOrders/State.lua') -- real result predicate
CO.IsAtUsableCraftingOrderTable=function() return true end -- fixture is at the crafting table
local released, fresh=order(100003),order(100003)
released.orderState=2
CO.rowStates[100003]={order=released}
CO.rowStates[100004]={order=order(100004)}
CO:OnEvent('CRAFTINGORDERS_RELEASE_ORDER_RESPONSE',1,'100003')
assert(CO.rowStates[100003], 'failed release cleared the claimed cache')
CO:OnEvent('CRAFTINGORDERS_RELEASE_ORDER_RESPONSE',0,'100003')
assert(not CO.rowStates[100003] and CO.rowStates[100004], 'native release kept a stale Claimed state or cleared a sibling')
assert(not CO:IsOrderUnavailable(100003), 'release was confused with a decline')
local action,reason,_,enabled=CO:GetRowAction(100003,fresh)
assert(action=='claim' and enabled, 'released order cannot be claimed again from a fresh server snapshot: '..tostring(action)..' / '..tostring(reason))
CO:SetOrderSelected(a.orderID,true)
assert(not CO.selectedOrders[tostring(a.orderID)], 'a stale checkbox reselected the declined order')
E.C_CraftingOrders.GetCrafterOrders=function() return {a,b,fresh} end
CO:SelectAllVisibleOrders({orderType=3},false)
assert(CO.selectedOrders['100003'] and not CO.selectedOrders['100001'] and not CO.selectedOrders['100002'],
    'select-all revived a finished order or skipped the released one')
print('Native terminal actions passed: exact IDs, failure, duplicate/late responses, manual fulfillment.')
