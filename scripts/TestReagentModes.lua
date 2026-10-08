-- The five reagent modes of the order queue (Auto, T1, T2, Profit, Manual):
-- which grade each one names for a slot, where each exists, what the craft is
-- made of, what a mix costs, and what a switch of the mode brings up to date.
local function noop() end
local function wipe(t) for k in pairs(t) do t[k]=nil end end
local clock,timers=1000,{}
local db={queue={minProfitCopper=200}}
local page={orderType=4,professionInfo={profession=1},shown=true}
function page:IsShown() return self.shown end
local CO={activePageFrame=page,selectedOrders={},selectedReagents={},useConcentration={},rowStates={},orderIssues={},
    orderCacheRevision={},qualityCache={},displayReagentsCache={},craftingReagentInfoCache={}}
-- One slot of five, sold in three grades.
local tiers={[101]=1,[102]=2,[103]=3}
local prices={[101]=10,[102]=100,[103]=40}
local bags={}
local orders={{orderID=1,spellID=501,orderType=4,tipAmount=600,minQuality=3}}
local enginePlan
SlashCmdList={}
local E=setmetatable({CO=CO,PT={},T=function(_,fallback) return fallback end,
    GetDB=function() return db end,OrderKey=function(id) return id and tostring(id) end,
    SameOrderID=function(a,b) return tostring(a)==tostring(b) end,
    UnitGUID=function() return 'Player-A' end,GetServerTime=function() return clock end,GetTime=function() return clock end,
    wipe=wipe,CreateFrame=function() return setmetatable({},{__index=function() return noop end}) end,
    Enum={CraftingOrderType={Npc=4,Personal=3,Public=1},CraftingOrderResult={Ok=0}},
    C_TradeSkillUI={GetItemReagentQualityByItemInfo=function(id) return tiers[id] end},
    C_CraftingOrders={GetCrafterOrders=function() return orders end},
    C_Timer={After=function(delay,callback) timers[#timers+1]={at=clock+delay,callback=callback} end},
    HironCraft={CraftEngine={NeedsConcentrationCached=function() return enginePlan end}},
    FormatProfitCopper=function(copper) return tostring(copper) end,
}, {__index=_G})
HironCraftProfitCraftingOrdersEnv=E
dofile('ProfitHub/Orders/CraftingOrders/State.lua')
dofile('ProfitHub/Orders/CraftingOrders/SelectionMemory.lua')
dofile('ProfitHub/Orders/CraftingOrders/QualityReagents.lua')
dofile('ProfitHub/Orders/CraftingOrders/QueueShopping.lua')
E.GetAuctionatorItemPrice=function(itemID) return prices[itemID] end
CO.GetSelectedProfessionExpansionKey=function() return 'midnight' end
CO.FindOrderPageFrame=function() return page end
CO.IsEnabled=function() return true end
CO.SetStatus=function(_,text) CO.status=text end
CO.RefreshVisibleRows,CO.RefreshVisibleRowsSoon,CO.UpdateControlPanel=noop,noop,noop
CO.InvalidateOrderCaches=noop
CO.GetClaimedOrder=function() return nil end
CO.IsOrderActionInProgress=function() return false end
CO.GetItemCountForShopping=function(_,itemID) return bags[itemID] or 0 end
local entry={itemID=101,quantity=5,slotIndex=1,dataSlotIndex=1,schematicIndex=1,selectionToken='schematic:1',
    source=2,crafterRequired=true,candidates={{itemID=101},{itemID=102},{itemID=103}}}
CO.BuildDisplayReagents=function() return {entry} end
local order=orders[1]
-- The order is checked: a switch of the mode reaches it at once.
CO.selectedOrders['1']=true
local function picked()
    local selected=CO:GetSelectedReagentForEntry(order.orderID,entry)
    return selected and selected.itemID, selected
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

-- Where each mode exists: all five for patrons, three elsewhere, and the two
-- settings are kept apart.
for _,mode in ipairs({'auto','t1','t2','profit','manual'}) do
    assert(CO:IsQueueReagentModeAvailable(mode),mode..' is missing on the Patron tab')
end
CO:SetQueueReagentMode('profit');assert(CO:GetQueueReagentMode()=='profit')
page.orderType=3
assert(CO:GetQueueReagentMode()=='t1','the other tabs did not start on T1')
assert(not CO:IsQueueReagentModeAvailable('auto') and not CO:IsQueueReagentModeAvailable('profit')
    and CO:IsQueueReagentModeAvailable('t1') and CO:IsQueueReagentModeAvailable('t2')
    and CO:IsQueueReagentModeAvailable('manual'),'a mode that does not exist off the Patron tab is offered there')
CO:SetQueueReagentMode('t2');assert(CO:GetQueueReagentMode()=='t2')
page.orderType=4
assert(CO:GetQueueReagentMode()=='profit','the Patron setting was changed from another tab')
page.orderType=3;CO:SetQueueReagentMode('t1');page.orderType=4

-- Which grade a mode names for the slot.
CO:SetQueueReagentMode('t1');assert(picked()==101)
CO:SetQueueReagentMode('t2');assert(picked()==102)
CO:SetQueueReagentMode('auto');assert(picked()==101,'auto did not take the cheapest grade')
prices[103]=4;CO:SetQueueReagentMode('auto');assert(picked()==103,'auto did not follow the price')
prices[103]=40
-- Profit takes the grades the engine found for the requested quality...
enginePlan={tierByDataSlot={[1]=2}}
CO:SetQueueReagentMode('profit');assert(picked()==102,'profit ignored the engine')
-- ...and the cheapest where no quality is asked for.
order.minQuality=nil;CO:ApplyQueueReagentModeToOrder(order);assert(picked()==101)
order.minQuality=3
-- Manual changes nothing by itself.
CO:SetQueueReagentMode('t2')
CO:SetQueueReagentMode('manual');assert(picked()==102,'manual changed a choice')
CO:ApplyQueueReagentModeToOrder(order);assert(picked()==102)

-- A switch brings the checked orders to the new mode at once, without
-- waiting for their rows to be drawn; an unchecked one waits for its row.
CO:SetQueueReagentMode('t1')
wipe(CO.selectedReagents)
CO:SetQueueReagentMode('t2');assert(picked()==102,'a checked order kept the grades of the mode before')
CO.selectedOrders['1']=nil
wipe(CO.selectedReagents)
CO:SetQueueReagentMode('t1');assert(picked()==nil,'an unchecked order was priced on the click')
CO:ApplyQueueReagentModeToOrder(order);assert(picked()==101)
CO.selectedOrders['1']=true

-- A mix is not a mode's choice, even when it starts with the right grade.
CO:SetQueueReagentMode('manual')
CO:SetSelectedReagentForEntry(order.orderID,entry,{itemID=101,quantity=5,slotIndex=1,dataSlotIndex=1,qualityTier=1,
    mix={{itemID=101,quantity=3},{itemID=102,quantity=2}}})
-- What a mix costs: each grade its own price (3 x 10 + 2 x 100), not the
-- first grade for all five.
local info=CO:GetOrderProfitInfo(order)
assert(info.reagentCost==230 and info.profit==370,'a mix was priced as its first grade: '..tostring(info.reagentCost))
-- The engine cannot price a mix: it is not asked.
assert(CO:BuildManualReagentsForEngine(order)==nil)
CO:SetQueueReagentMode('t1')
local id,selection=picked()
assert(id==101 and selection.mix==nil,'T1 kept a mix picked by hand')
assert(CO:GetOrderProfitInfo(order).reagentCost==50)

-- Manual for the engine: every crafter slot is the grade the craft will use.
CO:SetQueueReagentMode('manual')
wipe(CO.selectedReagents)
local locked,name=CO:BuildManualReagentsForEngine(order)
assert(locked[1].itemID==101 and locked[1].quantity==5 and name=='manual:1=101','a slot nothing was picked for is not its first grade')
CO:SetSelectedReagentForEntry(order.orderID,entry,{itemID=103,quantity=5,slotIndex=1,dataSlotIndex=1,qualityTier=3})
locked,name=CO:BuildManualReagentsForEngine(order)
assert(locked[1].itemID==103 and name=='manual:1=103','the engine is not asked about the grade picked by hand')

-- What the craft is made of. T2 is named, only T1 is in the bags: a worse
-- grade does not stand in for the chosen one (the craft would come out below
-- the quality the order was judged at), and the craft is not sent with the T2
-- nobody owns either. The order lacks reagents.
CO:SetQueueReagentMode('t2');assert(picked()==102)
bags={[101]=5}
assert(not CO:CanSupplyCrafterReagentsForQueue(order,false) and not CO:CanSupplyCrafterReagentsForQueue(order,true),
    'a worse grade stood in for the chosen one')
assert(picked()==102)
-- A better grade does stand in: T3 for T2. Asking changes nothing, the craft
-- takes what is in the bags.
bags={[103]=5}
assert(CO:CanSupplyCrafterReagentsForQueue(order,false) and picked()==102,'asking changed the choice')
assert(CO:CanSupplyCrafterReagentsForQueue(order,true))
id,selection=picked()
assert(id==103 and selection.quantity==5,'the craft would be sent with a reagent the bags do not hold: '..tostring(id))
-- T3 for T1 as well.
CO:SetQueueReagentMode('t1');assert(picked()==101)
assert(CO:CanSupplyCrafterReagentsForQueue(order,true))
id,selection=picked()
assert(id==103 and selection.quantity==5)
-- The named grade is owned: nothing changes, whatever else is there.
CO:SetQueueReagentMode('t2');bags={[102]=5,[101]=5,[103]=5}
assert(CO:CanSupplyCrafterReagentsForQueue(order,true) and picked()==102)
-- By hand: nothing picked is the slot's first grade, and a better one stands in.
CO:SetQueueReagentMode('manual');wipe(CO.selectedReagents);bags={[102]=5}
assert(CO:CanSupplyCrafterReagentsForQueue(order,true) and picked()==102)
-- T3 picked by hand, T2 owned: not the craft that was asked for.
CO:SetSelectedReagentForEntry(order.orderID,entry,{itemID=103,quantity=5,slotIndex=1,dataSlotIndex=1,qualityTier=3})
assert(not CO:CanSupplyCrafterReagentsForQueue(order,true) and picked()==103,'a grade picked by hand was replaced by a worse one')
-- Not enough of anything: no craft.
CO:SetQueueReagentMode('t2');bags={[101]=4,[102]=4,[103]=4}
assert(not CO:CanSupplyCrafterReagentsForQueue(order,true))
bags={[101]=4,[102]=4}
-- Auto mixes what is owned, cheapest first.
CO:SetQueueReagentMode('auto')
assert(CO:CanSupplyCrafterReagentsForQueue(order,true))
id,selection=picked()
assert(selection.mix and #selection.mix==2 and selection.mix[1].itemID==101 and selection.mix[1].quantity==4
    and selection.mix[2].itemID==102 and selection.mix[2].quantity==1,'auto did not mix the owned grades')
bags={}

-- A switch of the mode reaches the checks and the shopping list: T1 leaves
-- 550 of the tip, T2 leaves 100, and the minimum is 200.
CO:SetQueueReagentMode('t1')
CO:EnsureOrderSelectionContext(page)
CO.selectedOrders['1']=true
CO:RememberOrderSelection(1,true,order,'profit',550)
local rebuilt,emptied=0,0
CO.BuildShoppingMaterialsForSelectedOrders=function() return {{itemID=101}},1 end
CO.CreateShoppingListForSelectedOrders=function() rebuilt=rebuilt+1;return true end
E.PT.ShoppingList={session={active=true,temporary=true,sourceKind='crafting_orders'},
    CreateTemporaryImportedList=function(_,_,list,kind,allowEmpty)
        assert(#list==0 and kind=='crafting_orders' and allowEmpty==true);emptied=emptied+1;return true
    end}
CO.visibleRowButtons={[{orderID=1,IsShown=function() return true end}]=true}
timers={}
-- Same threshold, other grades of the same price class: the check stays and
-- the list is rebuilt for the new grades.
prices[102]=11
CO:SetQueueReagentMode('t2');drain(.2)
assert(CO:IsOrderSelected(1) and rebuilt==1 and emptied==0,'the shopping list kept the grades of the mode before')
-- Now the new grades cost the profit: the check goes, the list is emptied.
prices[102]=100
CO:SetQueueReagentMode('t1');drain(.2)
assert(CO:IsOrderSelected(1) and rebuilt==2)
CO:SetQueueReagentMode('t2');drain(.2)
assert(not CO:IsOrderSelected(1),'an order below the minimum in the new mode kept its check')
assert(rebuilt==2 and emptied==1,'the shopping list kept an order that lost its check')

print('Reagent mode tests passed (where modes exist, grade per mode, mix cost, manual for the engine, craft from the bags, mode switch).')
