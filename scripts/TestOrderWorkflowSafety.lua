-- Full workflow invariants, using fake game APIs and a deterministic clock.
-- No protected call is made by a timer or an event in this harness.
local function noop() end
local function wipe(t) for k in pairs(t) do t[k]=nil end end
local now, timers, claimed, submissions = 100, {}, nil, 0
local bags, schema = {}, nil
local db = {queue={reagentMode='manual'}}
SlashCmdList={}
local CO = {rowStates={}, selectedOrders={}, selectedReagents={}, useConcentration={}, orderIssues={},
    displayReagentsCache={}, craftingReagentInfoCache={}, orderCacheRevision={}}
local function frame(shown)
    return {shown=shown, IsShown=function(self) return self.shown end,
        Show=function(self) self.shown=true end, Hide=function(self) self.shown=false end}
end
local page=frame(true)
page.orderType, page.professionInfo, page.ahuiCustomList=4,{profession=1},{}
page.BrowseFrame, page.OrderView=frame(true),frame(false)
page.OrderView.SetOrder=function(self,order) self.order=order end
local E=setmetatable({CO=CO,PT={},SlashCmdList={},
    T=function(_,fallback) return fallback end, GetTime=function() return now end,
    CacheNow=function() return now end, GetDB=function() return db end,
    GetOrderRevision=function() return 0 end, REAGENT_CACHE_TTL=1,
    OrderKey=function(id) return id and tostring(id) end,
    SameOrderID=function(a,b) return a~=nil and b~=nil and tostring(a)==tostring(b) end,
    GetProfessionFromPage=function() return 1 end, UnitGUID=function() return 'Player-A' end,
    SafeCall=function(_,fn) return pcall(fn) end, wipe=wipe,
    CreateFrame=function() return {RegisterEvent=noop,SetScript=noop} end,
    Enum={CraftingOrderState={Created=1,Claimed=2},CraftingOrderType={Npc=4,Personal=3},
        CraftingOrderResult={Ok=0},CraftingOrderReagentSource={Customer=1,Crafter=2},
        TradeskillSlotDataType={Reagent=0,ModifiedReagent=1},CraftingReagentType={Basic=1,Finishing=2}},
    C_Timer={After=function(delay,fn) timers[#timers+1]={at=now+delay,fn=fn} end},
    C_CraftingOrders={GetClaimedOrder=function() return claimed end,
        ClaimOrder=function() submissions=submissions+1 end,
        ReleaseOrder=function() submissions=submissions+1 end,
        FulfillOrder=function() submissions=submissions+1 end},
    C_TradeSkillUI={GetRecipeSchematic=function() return schema end},
}, {__index=_G})
HironCraftProfitCraftingOrdersEnv=E
for _,file in ipairs({'State','QualityReagents','QueueShopping','Actions'}) do
    dofile('Workflow/Orders/CraftingOrders/'..file..'.lua')
end
CO.CreateHotkeyProxy,CO.HookBlizzardProfessions,CO.ApplyEnabledState=noop,noop,noop
dofile('Workflow/Orders/CraftingOrders/HooksEvents.lua')
CO.activePageFrame=page
CO.IsEnabled=function() return true end
CO.FindOrderPageFrame=function(_,value) return value or page end
CO.IsAtUsableCraftingOrderTable=function() return true end
CO.GetRecipeKnownState=function() return true end
CO.ShouldRejectForMissingCustomerReagents=function() return false end
CO.OrderRequiresConcentrationForQueue=function() return false end
CO.GetItemCountForShopping=function(_,id) return bags[id] or 0 end
CO.GetQueueReagentCandidateTier=function() return 1 end
CO.GetQueueReagentAuctionatorPrice=function() return 1 end
CO.SetStatus=function(_,value) CO.status=value end
CO.HasSelectedOrders=function() return true end
CO.SetActiveRowButton=function() error('early press changed active target') end
CO.IsOrderSelected=function(_,id) return CO.selectedOrders[tostring(id)]==true end
CO.GetVisibleButtonForOrder=function() return nil end
CO.StopRowProgress=function() CO.progressActive=nil; CO.progressOrderID=nil end
for _,name in ipairs({'RefreshVisibleRows','RefreshVisibleRowsSoon','UpdateControlPanel',
    'RefreshPageSoon','EnsurePageBindingHooks','EnsureControlPanel','UpdateControlPanelVisibility'}) do CO[name]=noop end
CO.InvalidateOrderCaches=function() wipe(CO.displayReagentsCache); wipe(CO.craftingReagentInfoCache) end
local function advance(seconds)
    local finish=now+seconds
    for _=1,1000 do
        table.sort(timers,function(a,b) return a.at<b.at end)
        if not timers[1] or timers[1].at>finish then now=finish;return end
        local timer=table.remove(timers,1); now=timer.at;timer.fn()
    end
    error('unbounded recovery loop')
end
local a={orderID=1,spellID=501,orderState=1,orderType=4,minQuality=0}
local button={orderID=1,order=a,pageFrame=page}

-- Early hardware presses are harmless at every stage, including the gap
-- between the server answer and the delayed automatic checkbox pass.
for _,stage in ipairs({'search','request','selection','automatic','combined'}) do
    page.ahuiCustomList._freshSearchPending=stage=='search' or nil
    page.ahuiOrderRequestPending=stage=='request' or nil
    CO.queueSelectionRunning=stage=='selection' or nil
    CO._autoQueueStamp=11; CO._orderSelectionContext='scope'
    CO._autoQueuePending=stage=='automatic' and {page=page,stamp=11,context='scope'} or nil
    CO.IsCombinedPatronListReady=function() return stage~='combined' end
    CO:RunRowButtonAction(button); CO:RunActiveRowAction()
    assert(not CO:ClaimOrder(a,page) and submissions==0, 'early '..stage..' press submitted an action')
end
page.ahuiCustomList._freshSearchPending=nil;page.ahuiOrderRequestPending=nil
CO.queueSelectionRunning=nil;CO._autoQueuePending=nil;CO.IsCombinedPatronListReady=nil
assert(CO:IsOrderListReadyForAction(page))

-- An Ok response with no authoritative claim must not invent a craft-ready
-- cached row. A timeout permits a new user decision, not a background retry.
assert(CO:ClaimOrder(a,page))
CO:OnEvent('CRAFTINGORDERS_CLAIM_ORDER_RESPONSE',0,1)
advance(8.2)
assert(not CO.pendingClaimOrderID and a.orderState==1 and submissions==1)

-- Results from normal reagent crafts, and delayed callbacks for the same
-- recipe on an earlier order, cannot turn the current job into Complete.
local b={orderID=2,spellID=501,orderState=2,isFulfillable=false}
claimed=a; a.orderState=2; a.isFulfillable=false
CO.pendingCraftOrderID=1;CO.pendingCraftSpellID=501;CO.pendingCraftCastGUID='cast-A';CO._craftWatchToken=1
CO:OnEvent('UNIT_SPELLCAST_SUCCEEDED','player','cast-A',501)
CO:OnEvent('UNIT_SPELLCAST_INTERRUPTED','player','cast-A',501)
claimed=b;CO.pendingCraftOrderID=2;CO.pendingCraftCastGUID='cast-B';CO._craftWatchToken=2
CO.progressOrderID=2;CO.progressActive=true
CO:OnEvent('TRADE_SKILL_CRAFT_BEGIN',999)
CO:OnEvent('TRADE_SKILL_ITEM_CRAFTED_RESULT',{recipeID=999})
CO:OnEvent('UNIT_SPELLCAST_FAILED','player','cast-A',501)
advance(1.2)
assert(CO.pendingCraftOrderID==2 and CO.progressOrderID==2 and CO.progressActive)
assert(not CO.craftedOrderID and not b.isFulfillable and not CO.craftSubmissionAcknowledgedOrderID)
CO:OnEvent('TRADE_SKILL_ITEM_CRAFTED_RESULT',{recipeID=501})
advance(0.1)
assert(CO.pendingCraftOrderID==2, 'craft result fabricated fulfillment before the server update')
b.isFulfillable=true;advance(0.2)
assert(CO.craftedOrderID==2 and not CO.pendingCraftOrderID and not CO.progressActive)

-- Both a missing removal and a missing response have a bounded recovery.
assert(CO:FulfillOrder(b,page));local before=submissions
CO:OnEvent('CRAFTINGORDERS_FULFILL_ORDER_RESPONSE',0,2)
claimed=nil;advance(10.1)
assert(not CO:IsOrderSubmissionPending() and submissions==before)
CO.fulfilledOrderIDs={};claimed=b;assert(CO:FulfillOrder(b,page))
before=submissions;advance(10.1)
assert(not CO:IsOrderSubmissionPending() and submissions==before)
-- Old responses must not change the lock or status of a newer order.
local c={orderID=3,spellID=503,orderState=2,isFulfillable=true}
claimed=c;assert(CO:FulfillOrder(c,page));local terminal=CO.terminalAction;local status=CO.status
CO:OnEvent('CRAFTINGORDERS_FULFILL_ORDER_RESPONSE',0,2)
assert(CO.terminalAction==terminal and CO.pendingFulfillOrderID==3 and CO.status==status)
claimed=nil;CO:OnEvent('CRAFTINGORDERS_CLAIMED_ORDER_REMOVED')
CO:OnEvent('CRAFTINGORDERS_FULFILL_ORDER_RESPONSE',0,3)
claimed=b;assert(CO:ReleaseOrder(b,page));before=submissions;advance(10.1)
assert(not CO:IsOrderSubmissionPending() and submissions==before)
claimed=nil

-- Use the matching native schematic and each reagent's quantity, not an
-- older 32-unit slot/allocation when this recipe now requires 20.
schema={recipeID=501,reagentSlotSchematics={{slotIndex=1,dataSlotIndex=1,dataSlotType=1,
    reagentType=1,required=true,quantityRequired=32,reagents={{itemID=101},{itemID=103}},
    variableQuantities={{reagent={itemID=103},quantity=20}}}}}
CO.rowStates={};CO.craftedOrderID=nil;CO.selectedReagents={}
local entry=CO:BuildDisplayReagents(a,true)[1]
local key=E.MakeReagentSelectionKeyForEntry(1,entry)
CO.selectedReagents[key]={itemID=103,quantity=32,slotIndex=1,qualityTier=3}
bags[103]=20;CO:InvalidateOrderCaches()
assert(CO:BuildDisplayReagents(a,true)[1].quantity==20)
assert(CO:CanSupplyCrafterReagentsForQueue(a,true))
assert(CO.selectedReagents[key].quantity==20)
local allocation
page.OrderView.order=a
local transaction={GetRecipeSchematic=function() return schema end,
    OverwriteAllocation=function(_,slot,reagent,quantity) allocation=quantity end}
page.OrderView.OrderDetails={SchematicForm={transaction=transaction}}
CO:ApplySelectedReagentsToEngine(page.OrderView,a)
assert(allocation==20, 'stale selected quantity reached the live transaction')
assert(CO:IsCompleteOperationReagentInfoTbl(a,{{dataSlotIndex=1,reagent={itemID=103},quantity=20}},schema))
assert(not CO:IsCompleteOperationReagentInfoTbl(a,{{dataSlotIndex=1,reagent={itemID=101},quantity=16},
    {dataSlotIndex=1,reagent={itemID=103},quantity=4}},schema), 'variable quantities allowed a mixture')
assert(not CO:IsCompleteOperationReagentInfoTbl(a,{{dataSlotIndex=1,reagent={itemID=103},quantity=20},
    {dataSlotIndex=1,reagent={itemID=101},quantity=1}},schema), 'a complete grade hid an illegal extra grade')
assert(CO:IsCompleteOperationReagentInfoTbl(a,{{dataSlotIndex=1,reagent={itemID=103},quantity=10},
    {dataSlotIndex=1,reagent={itemID=103},quantity=10}},schema), 'same-grade partial contributions were not summed')

local customer={orderID=9,spellID=501,orderType=3,reagentState=1,reagents={{slotIndex=1,source=1,
    reagentInfo={dataSlotIndex=1,quantity=20,reagent={itemID=103}}}}}
assert(#CO:BuildDisplayReagents(customer,true)==0,
    'full customer-provided variable reagent was compared to another grade quantity')
customer.reagents[1].reagentInfo.quantity=10
local remainder=CO:BuildDisplayReagents(customer,true)[1]
assert(remainder.itemID==103 and remainder.quantity==10 and #remainder.candidates==1,
    'partial customer variable allocation lost its grade or remaining quantity')
assert(CO:CanSupplyCrafterReagentsForQueue(customer,true))
local pick=CO:GetSelectedReagentForEntry(9,remainder)
assert(pick.itemID==103 and pick.quantity==10)

-- Never count the same bag stack separately for two crafter slots; and a
-- later failure must not partially publish new choices for earlier slots.
schema={recipeID=501,reagentSlotSchematics={}}
for i=1,2 do schema.reagentSlotSchematics[i]={slotIndex=i,dataSlotIndex=i,dataSlotType=1,
    reagentType=1,required=true,quantityRequired=5,reagents={{itemID=101}}} end
CO.selectedReagents={};bags[101]=5;CO:InvalidateOrderCaches()
assert(not CO:CanSupplyCrafterReagentsForQueue(a,true) and not next(CO.selectedReagents))
bags[101]=10;assert(CO:CanSupplyCrafterReagentsForQueue(a,true))
assert(E.GetSlotRequiredQuantity(schema.reagentSlotSchematics[1],{itemID=101},nil)==5)
print('Workflow safety passed: early presses, authoritative craft state, stale callbacks, request recovery, live quantities and shared inventory.')
