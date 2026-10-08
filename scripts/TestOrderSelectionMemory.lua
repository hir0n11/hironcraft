-- Real selection, queue analysis and open/close hooks; no protected operations.
if not setfenv then
    function setfenv(fn, env)
        if type(fn)=='number' then fn=debug.getinfo(fn+1,'f').func end
        for i=1,100 do
            local name=debug.getupvalue(fn,i)
            if not name then break end
            if name=='_ENV' then debug.upvaluejoin(fn,i,function() return env end,1);break end
        end
        return fn
    end
end
local function noop() end
local function forbidden() error('selection invoked a protected action') end
local function wipe(t) for k in pairs(t) do t[k]=nil end end
local clock,character,expansion=10000000,'Player-A','midnight'
local db={queue={autoQueueOnOpen=true,minProfitCopper=100}}
local page={orderType=4,professionInfo={profession=1},shown=true}
function page:IsShown() return self.shown end
local CO={activePageFrame=page,selectedOrders={},selectedReagents={},useConcentration={},rowStates={},orderIssues={}}
local orders={
    {orderID=1,spellID=101,orderType=4,profit=500},
    {orderID=2,spellID=102,orderType=4,profit=-200,npcOrderRewards={{itemID=900}}},
    {orderID=3,spellID=103,orderType=4,profit=-400},
    {orderID=4,spellID=104,orderType=4,profit=-500,needsConcentration=true,npcOrderRewards={{itemID=900}}},
    {orderID=5,spellID=105,orderType=4,profit=-600,unknown=true,npcOrderRewards={{itemID=900}}},
    {orderID=6,spellID=106,orderType=4,profit=-700,missingReagents=true,npcOrderRewards={{itemID=900}}},
}
local timers,requests={},{}
local serverBacked=false
local E=setmetatable({CO=CO,PT={},T=function(_,fallback) return fallback end,
    GetDB=function() return db end,OrderKey=function(id) return id and tostring(id) end,
    SameOrderID=function(a,b) return tostring(a)==tostring(b) end,
    UnitGUID=function() return character end,
    GetServerTime=function() return clock end,GetTime=function() return clock end,
    GetRewardItemID=function(r) return r.itemID end,IsKnowledgePointRewardItem=function(id) return id==900 end,
    wipe=wipe,CreateFrame=function() return {RegisterEvent=noop,SetScript=noop} end,
    Enum={CraftingOrderType={Npc=4,Personal=3,Public=1},CraftingOrderResult={Ok=0}},
    C_TradeSkillUI={},C_CraftingOrders={GetCrafterOrders=function() return orders end,
        ClaimOrder=forbidden,CraftOrder=forbidden,FulfillOrder=forbidden},
    C_Timer={After=function(delay,callback) timers[#timers+1]={at=clock+delay,callback=callback} end},
}, {__index=_G})
HironCraftProfitCraftingOrdersEnv=E
dofile('ProfitHub/Orders/CraftingOrders/State.lua')
dofile('ProfitHub/Orders/CraftingOrders/SelectionMemory.lua')
dofile('ProfitHub/Orders/CraftingOrders/QueueShopping.lua')
CO.GetSelectedProfessionExpansionKey=function() return expansion end
CO.FindOrderPageFrame=function() return page end
CO.GetVisibleOrderButtonsSorted=function()
    local result={};for _,order in ipairs(orders) do result[#result+1]={order=order} end;return result
end
CO.GetOrderProfitInfo=function(_,order) return {profit=order.profit} end
CO.PrepareOrderForQueueAnalysis=function() return true end
CO.GetRecipeKnownState=function(_,order) return not order.unknown end
CO.OrderMatchesSelectedProfessionExpansion=function() return true end
CO.CanSupplyCrafterReagentsForQueue=function(_,order) return not order.missingReagents end
CO.OrderRequiresConcentrationForQueue=function(_,order) return order.needsConcentration==true end
CO.GetOrderQualityInfo=function() return {quality=5} end
CO.ApplyQueueReagentModeToOrder=function() return true end
CO.GetOrderActionAvailabilitySortRank=function(_,order)
    if order.unknown then return 4 end
    if order.needsConcentration then return 3 end
    return order.missingReagents and 2 or 1
end
CO.GetClaimedOrder=function() return nil end
CO.RefreshVisibleRows,CO.RefreshVisibleRowsSoon,CO.UpdateControlPanel=noop,noop,noop
CO.SetStatus=function(_,text) CO.status=text end
local function selected(expected)
    local ids={};for id in pairs(CO.selectedOrders) do ids[#ids+1]=tonumber(id) end;table.sort(ids)
    assert(table.concat(ids,',')==expected,'selection='..table.concat(ids,',')..'; expected='..expected)
end
local function auto()
    CO:RestoreOrderSelection(page,orders)
    CO:QueueWorkOrdersSelection(false,{automatic=true,includeProfit=CO:IsAutoQueueOnOpen(),includeKnowledge=CO:IsAutoKnowledgeOnOpen()})
end
local function drain(seconds)
    local untilTime=clock+seconds
    for _=1,1000 do
        table.sort(timers,function(a,b) return a.at<b.at end)
        if not timers[1] or timers[1].at>untilTime then clock=untilTime;return end
        local timer=table.remove(timers,1);clock=timer.at;timer.callback()
    end
    error('unbounded timer loop')
end
assert(CO:IsAutoKnowledgeOnOpen(),'existing auto-queue setting did not initialize knowledge selection')
CO:SetAutoKnowledgeOnOpen(false);assert(not CO:IsAutoKnowledgeOnOpen())
CO:SetAutoKnowledgeOnOpen(true)
auto();selected('1,2,6') -- one pass, including knowledge that needs shopping
CO:SetOrderSelected(1,false)
CO:SetOrderSelected(3,true) -- manually keep a negative-profit, non-knowledge order
CO.selectedReagents['3:1']={itemID=1234}
CO.useConcentration['3']=true
local previousReagent=CO.selectedReagents['3:1']
-- Temporary empty load and reopening cannot destroy persisted choices.
CO.IsOrderActionInProgress=function() return true end
CO:RestoreOrderSelection(page,{});selected('2,3,6')
CO.IsOrderActionInProgress=function() return false end
CO:RestoreOrderSelection(page,{});selected('')
page.shown=false;page.shown=true
auto();selected('2,3,6')
assert(CO.selectedReagents['3:1']==previousReagent and CO.useConcentration['3']==true)
-- New orders can be selected, but manually unchecked old ones cannot return.
orders[#orders+1]={orderID=7,spellID=107,orderType=4,profit=200}
auto();selected('2,3,6,7')

local patronOrders=orders
local function switch(typeID,profession,guid,key,newOrders)
    page.orderType,page.professionInfo.profession=typeID,profession
    character,expansion=guid,key
    orders=newOrders or patronOrders
    CO:RestoreOrderSelection(page,orders)
end
switch(3,1,'Player-A','midnight',{{orderID=8,spellID=108,orderType=3}});selected('')
CO:SelectAllVisibleOrders(page,true);selected('8')
CO:SetOrderSelected(8,false);CO:SelectAllVisibleOrders(page,true);selected('')
switch(4,1,'Player-A','midnight');selected('2,3,6,7')
switch(4,2,'Player-A','midnight');selected('')
switch(4,1,'Player-B','midnight');selected('')
switch(4,1,'Player-A','tww');selected('')
switch(4,1,'Player-A','midnight');selected('2,3,6,7')
-- Simulated /reload: only the saved table survives.
CO._orderSelectionContext,CO._orderSelectionBucket=nil,nil
CO.selectedOrders={};CO:RestoreOrderSelection(page,orders);selected('2,3,6,7')
auto();selected('2,3,6,7')
-- Expired/missing orders disappear from active counts; a transient/filtered
-- omission does not erase the decision. A reused ID for another recipe does.
orders={patronOrders[2],patronOrders[3]};CO:RestoreOrderSelection(page,orders);selected('2,3')
orders=patronOrders;CO:RestoreOrderSelection(page,orders);selected('2,3,6,7')
orders[2].spellID=999;CO:RestoreOrderSelection(page,orders)
assert(not CO:IsOrderSelected(2),'a reused order ID inherited another recipe selection')
orders[2].spellID=102
auto();selected('2,3,6,7')
switch(3,1,'Player-A','midnight',{})
CO:ForgetCompletedOrderSelection(2) -- completion arrived after a tab switch
switch(4,1,'Player-A','midnight');auto();selected('3,6,7')
CO:ClearSelectedOrders();auto();selected('')
CO:QueueWorkOrdersSelection(true);selected('2,6') -- explicit button can replace manual exclusions
CO:QueueWorkOrdersSelection();selected('1,7') -- explicit normal queue still rebuilds
CO:SetAutoQueueOnOpen(false);CO:SetAutoKnowledgeOnOpen(true)
CO:ResetQueueCheckboxes();wipe(CO._orderSelectionBucket.choices)
auto();selected('2,6') -- knowledge works independently of the normal queue
CO:SetAutoQueueOnOpen(true);CO:SetAutoKnowledgeOnOpen(false)
CO:ResetQueueCheckboxes();wipe(CO._orderSelectionBucket.choices)
auto();selected('1,7')
CO:SetAutoKnowledgeOnOpen(true)

CO:SetKnowledgeProfitIgnored(false)
CO:ResetQueueCheckboxes();wipe(CO._orderSelectionBucket.choices)
auto();selected('1,7') -- combined selection still respects the optional profit gate
CO:SetKnowledgeProfitIgnored(true)
auto();selected('1,2,6,7')
assert(db.queue.knowledgeIgnoreProfit==true)

-- A check the queue made is held to the threshold it passed. Prices move
-- after the check is made (the shopping scan brings today's), and so do the
-- thresholds: the order that no longer passes loses its check. A check made
-- by hand is never taken away.
do
    local bucket=CO._orderSelectionBucket
    E.FormatProfitCopper=function(copper) return tostring(copper) end
    local function toBuy(flag,...) for _,id in ipairs({...}) do patronOrders[id].missingReagents=flag end end
    assert(bucket.choices['1'].rule=='profit' and bucket.choices['1'].profit==500
        and bucket.choices['2'].rule=='knowledge' and bucket.choices['2'].profit==-200,
        'the queue did not record under which threshold it checked an order')
    -- The threshold moves: -700 does not pass -500.
    CO:SetKnowledgeMinProfitCopper(-500);selected('1,2,7')
    assert(bucket.choices['6']==nil,'a dropped check was remembered as unchecked by hand')
    assert(CO.status:find('1',1,true) and CO.status:find('below',1,true),'the dropped check was not reported: '..tostring(CO.status))
    -- Prices move before the reagents are bought: +500 became -50 and the
    -- knowledge order fell to -900.
    toBuy(true,1,2,7)
    CO:SetOrderSelected(3,true) -- by hand, at -400
    assert(bucket.choices['3'].rule==nil)
    patronOrders[1].profit,patronOrders[2].profit=-50,-900
    assert(CO:RecheckQueuedSelections()==2);selected('3,7')
    assert(CO:RecheckQueuedSelections()==0)
    -- A list refresh does the same for checks remembered from before.
    patronOrders[7].profit=-1
    CO:RestoreOrderSelection(page,orders);selected('3')
    -- Reagents already in the bags: buying them is what moved the price, and
    -- the check stays...
    toBuy(false,1,2,7)
    patronOrders[1].profit,patronOrders[2].profit,patronOrders[7].profit=500,-200,200
    CO:SetKnowledgeMinProfitCopper(nil)
    CO:ResetQueueCheckboxes();wipe(bucket.choices)
    auto();selected('1,2,6,7')
    patronOrders[1].profit=-50
    assert(CO:RecheckQueuedSelections()==0);selected('1,2,6,7')
    CO:RestoreOrderSelection(page,orders);selected('1,2,6,7')
    -- ...but a threshold the crafter changes applies to it as to any other,
    -- and reaches only the queue's own checks.
    CO:SetOrderSelected(3,true)
    CO:SetQueueMinProfitCopper(300);selected('2,3,6')
    CO:SetKnowledgeProfitIgnored(false);selected('3')
    CO:SetQueueMinProfitCopper(100000);selected('3')
    CO:SetKnowledgeProfitIgnored(true);CO:SetQueueMinProfitCopper(100)
    CO:SetOrderSelected(3,false)
    patronOrders[1].profit=500
    -- An order already claimed is not let go, and nothing is while an action runs.
    toBuy(true,1,7)
    auto();selected('1,2,6,7')
    patronOrders[1].profit,patronOrders[7].profit=-50,-50
    CO.GetClaimedOrder=function() return patronOrders[1] end
    CO.IsOrderActionInProgress=function() return true end
    assert(CO:RecheckQueuedSelections()==0);selected('1,2,6,7')
    CO.IsOrderActionInProgress=function() return false end
    assert(CO:RecheckQueuedSelections()==1);selected('1,2,6')
    CO.GetClaimedOrder=function() return nil end
    -- Once it passes again, a later automatic pass takes the dropped order back.
    patronOrders[1].profit,patronOrders[7].profit=500,200
    auto();selected('1,2,6,7')
    -- Other tabs have no profit threshold: nothing is dropped there.
    page.orderType=3
    patronOrders[7].profit=-50
    assert(CO:RecheckQueuedSelections()==0);selected('1,2,6,7')
    page.orderType=4

    -- The shopping list made for the checked orders follows them.
    local rebuilt,emptied,materials=0,0,{{itemID=1}}
    local realBuild,realCreate=CO.BuildShoppingMaterialsForSelectedOrders,CO.CreateShoppingListForSelectedOrders
    CO.BuildShoppingMaterialsForSelectedOrders=function() return materials,#materials end
    CO.CreateShoppingListForSelectedOrders=function() rebuilt=rebuilt+1;return true end
    E.PT.ShoppingList={session={active=true,temporary=true,sourceKind='crafting_orders'},
        CreateTemporaryImportedList=function(_,_,list,kind,allowEmpty)
            assert(#list==0 and kind=='crafting_orders' and allowEmpty==true);emptied=emptied+1;return true
        end}
    local rowShown=true
    CO.visibleRowButtons={[{orderID=1,IsShown=function() return rowShown end}]=true}
    timers={}
    assert(CO:RecheckQueuedSelections()==1);selected('1,2,6')
    assert(rebuilt==0,'the shopping list was rebuilt inside the list refresh');drain(.2)
    assert(rebuilt==1 and emptied==0,'the shopping list kept the reagents of an order that lost its check')
    -- Two drops in a row are one rebuild.
    patronOrders[1].profit=-50;assert(CO:RecheckQueuedSelections()==1)
    CO:SetKnowledgeMinProfitCopper(-100);selected('')
    materials={};drain(.2)
    assert(rebuilt==1 and emptied==1,'nothing is left to buy, but the list was not emptied')
    -- Somebody else's list, or no rows to build from: left as it is.
    CO:SetKnowledgeMinProfitCopper(nil)
    patronOrders[1].profit,patronOrders[7].profit=500,200
    auto();selected('1,2,6,7')
    patronOrders[7].profit=-50;rowShown=false
    assert(CO:RecheckQueuedSelections()==1);drain(.2)
    rowShown=true;E.PT.ShoppingList.session.sourceKind='quest'
    patronOrders[1].profit=-50
    assert(CO:RecheckQueuedSelections()==1);drain(.2)
    assert(rebuilt==1 and emptied==1,'a list that is not ours, or one with no rows behind it, was rebuilt')
    E.PT.ShoppingList=nil
    CO.BuildShoppingMaterialsForSelectedOrders,CO.CreateShoppingListForSelectedOrders=realBuild,realCreate
    CO.visibleRowButtons=nil
    toBuy(nil,1,2,7)
    patronOrders[1].profit,patronOrders[7].profit=500,200
    auto();selected('1,2,6,7')
end

-- Server-backed selection and late callbacks: closing/changing context must
-- not mutate another tab or a later selection, nor start shopping prematurely.
E.C_CraftingOrders.RequestCrafterOrders=function(request) requests[#requests+1]=request end
CO:ResetQueueCheckboxes();wipe(CO._orderSelectionBucket.choices)
auto();assert(CO.queueSelectionRunning and #requests==1)
requests[1].callback(0);drain(.01);selected('1,2,6,7')
requests={};auto();local stale=requests[1]
switch(3,1,'Player-A','midnight',{});stale.callback(0);drain(.01);selected('')
switch(4,1,'Player-A','midnight');selected('1,2,6,7')
requests={};auto();stale=requests[1];page.shown=false
stale.callback(0);assert(not CO.queueSelectionRunning);page.shown=true
CO:SetOrderSelected(1,false);stale.callback(0);selected('2,6,7')

-- Real ShowGeneric hook runs the combined pass before creating one shopping
-- list. The UI can close during either delay without background side effects.
timers,requests={},{}
local mixin={ShowGeneric=noop,ViewOrder=noop,CloseOrder=noop}
E.ProfessionsCrafterOrderListElementMixin={Init=noop}
E.ProfessionsCraftingOrderPageMixin=mixin
E.hooksecurefunc=function(target,name,callback)
    local old=target[name];target[name]=function(...) if old then old(...) end;return callback(...) end
end
SlashCmdList={}
for _,name in ipairs({'CreateHotkeyProxy','InstallProfitSortHooks','ApplyEnabledState','ProtectExternalOrderPageSoon',
    'EnsureControlPanel','UpdatePageBackground','UpdateControlPanelVisibility','WarmVisibleOrderQualitySoon'}) do CO[name]=noop end
CO.IsEnabled=function() return true end
local shopping=0
CO.CreateShoppingListForSelectedOrders=function() shopping=shopping+1;return true end
dofile('ProfitHub/Orders/CraftingOrders/HooksEvents.lua')
CO:SetAutoShoppingOnOpen(true)
CO._autoRanForOpen=false;mixin.ShowGeneric(page);drain(.7)
assert(#requests==1 and shopping==0)
requests[1].callback(0);drain(.5)
assert(shopping==1 and not CO.queueSelectionRunning);selected('2,6,7')
CO._autoRanForOpen=false;mixin.ShowGeneric(page);page.shown=false;drain(1)
assert(#requests==1 and shopping==1,'closed page started another queue/shopping pass')
page.shown=true;CO._autoRanForOpen=false;mixin.ShowGeneric(page);drain(.7)
requests[2].callback(0);page.shown=false;drain(1)
assert(shopping==1,'closed page created a shopping list after selection')

-- One-button mode: a Personal order arriving while the list is open is
-- selected like the ones present at opening; a manual uncheck still wins.
page.shown=true
CO.IsOneButtonPersonalEnabled=function() return true end
switch(3,1,'Player-A','midnight',{{orderID=8,spellID=108,orderType=3},{orderID=9,spellID=109,orderType=3}})
selected('9')
switch(4,1,'Player-A','midnight');assert(not CO:IsOrderSelected(10),'auto-selection leaked outside Personal')
CO.IsOneButtonPersonalEnabled=function() return false end
switch(3,1,'Player-A','midnight',{{orderID=11,spellID=111,orderType=3}});selected('')
print('Order selection memory tests passed (shopping/reopen, manual exclusions, characters/professions/tabs/expansions, reload, knowledge union, checks held to their threshold, stale callbacks).')
