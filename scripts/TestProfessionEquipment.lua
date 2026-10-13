-- Full-set planning is read-only; only an explicit row action may move items.
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
local now, owner, profession, combat, cursor, pending, claimed = 10, 'Player-A', 164, false, nil, false, nil
local page = {orderType=3}
local db = {queue={}}
local equipped, bag, pickups = {}, {}, 0
local function item(id, suffix) return {itemID=id, link='item:'..id..':'..suffix, guid='GUID-'..suffix} end
local midnight = {item(101,'m1'), item(102,'m2'), item(103,'m3')}
local tww = {item(201,'t1'), item(202,'t2'), item(203,'t3')}
local slots = {20,21,22}
for i, slot in ipairs(slots) do equipped[slot]=midnight[i] end
local CO = {activePageFrame=page, useConcentration={}, _orderSelectionContext='scope', selectedOrders={}}
local E = setmetatable({CO=CO, PT={},
    T=function(_,fallback) return fallback end, GetDB=function() return db end,
    GetTime=function() return now end, UnitGUID=function() return owner end,
    OrderKey=function(id) return id and tostring(id) end,
    SameOrderID=function(a,b) return tostring(a)==tostring(b) end,
    GetProfessionFromPage=function() return profession end,
    FindExpansionOptionByKey=function(key)
        if key=='midnight' or key=='tww' or key=='df' then return {key=key, fallback=key} end
    end,
    FindExpansionOptionByExpansionID=function(id) return {key=id==10 and 'tww' or 'midnight'} end,
    InCombatLockdown=function() return combat end,
    CursorHasItem=function() return cursor~=nil end,
    GetInventoryItemID=function(_,slot) return equipped[slot] and equipped[slot].itemID end,
    GetInventoryItemLink=function(_,slot) return equipped[slot] and equipped[slot].link end,
    C_TradeSkillUI={GetProfessionSlots=function() return slots end},
    ItemLocation={CreateFromEquipmentSlot=function(_,slot) return {inventorySlot=slot} end,
        CreateFromBagAndSlot=function(_,b,slot) return {bag=b,slot=slot} end},
    C_Item={GetItemGUID=function(location)
        local i=location.inventorySlot and equipped[location.inventorySlot] or bag[location.slot]
        return i and i.guid
    end},
    C_Container={GetContainerNumSlots=function(b) return b==0 and 4 or 0 end,
        GetContainerItemInfo=function(_,slot)
            local i=bag[slot]; if i then return {itemID=i.itemID,hyperlink=i.link,isLocked=i.locked} end
        end,
        PickupContainerItem=function(_,slot) pickups=pickups+1; cursor,bag[slot]=bag[slot],cursor end},
    PickupInventoryItem=function(slot) pickups=pickups+1; cursor,equipped[slot]=equipped[slot],cursor end,
    ClearCursor=function() cursor=nil end,
}, {__index=_G})
HironCraftProfitCraftingOrdersEnv=E
dofile('Workflow/Orders/CraftingOrders/Equipment.lua')
CO.GetActiveBaseProfessionID=function() return profession end
CO.GetOrderProfessionExpansionID=function(_,order) return order.expansionID end
CO.IsOrderSubmissionPending=function() return pending end
CO.IsAtUsableCraftingOrderTable=function() return true end
CO.GetRecipeKnownState=function(_,order) return not order.unknown end
CO.GetClaimedOrder=function() return claimed end
CO.SetStatus=function(_,text) CO.status=text end
CO.RefreshVisibleRowsSoon, CO.UpdateQueueSettingWidgets, CO.RecheckQueuedSelections=noop,noop,noop
local invalidations=0
CO.InvalidateOrderCaches=function() invalidations=invalidations+1 end
CO.ClearOrderQualityRejection=noop
assert(CO:SaveProfessionEquipmentProfile('midnight'))
for i,slot in ipairs(slots) do equipped[slot]=tww[i] end
assert(CO:SaveProfessionEquipmentProfile('tww'))
for i,slot in ipairs(slots) do equipped[slot]=midnight[i];bag[i]=tww[i] end
local order={orderID=1,spellID=1001,expansionID=10,orderType=3}
assert(CO:GetOrderEquipmentPlan(order)=='ready', 'new feature must default off')
CO:SetOrderEquipmentOn(true)
assert(CO:GetOrderEquipmentPlan(order)=='swap')
assert(pickups==0, 'planning moved equipment')
assert(not CO:IsOrderEquipmentReadyForSubmission(order,page))

-- Every required item is preflighted before the first slot is moved.
bag[3]=nil
assert(CO:GetOrderEquipmentPlan(order,page,true)=='blocked')
assert(not CO:PrepareOrderEquipment(order,page) and pickups==0)
bag[3]=item(203,'other-quality-or-enchant')
assert(CO:GetOrderEquipmentPlan(order,page,true)=='blocked', 'same itemID was treated as the saved item')
bag[3]=tww[3]; bag[2].locked=true
assert(CO:GetOrderEquipmentPlan(order,page,true)=='waiting')
assert(not CO:PrepareOrderEquipment(order,page) and pickups==0)
bag[2].locked=nil
for _, guard in ipairs({'combat','cursor','pending','claimed','cached','table','unknown'}) do
    combat=guard=='combat'; cursor=guard=='cursor' and item(999,'cursor') or nil
    pending=guard=='pending'; claimed=guard=='claimed' and {orderID=99} or nil
    CO.viewingCachedOrders=guard=='cached'
    CO.IsAtUsableCraftingOrderTable=function() return guard~='table' end
    order.unknown=guard=='unknown'
    assert(not CO:PrepareOrderEquipment(order,page), 'unguarded swap: '..guard)
    assert(pickups==0, 'guard still moved equipment: '..guard)
end
combat,cursor,pending,claimed,CO.viewingCachedOrders,order.unknown=false,nil,false,nil,false,false
CO.IsAtUsableCraftingOrderTable=function() return true end

-- Swap cannot submit the order on the same press; a fast second press waits.
CO.preparedFinisherUseEngineOrderID=order.orderID
local beforeSwapInvalidations=invalidations
assert(not CO:PrepareOrderEquipment(order,page))
for i,slot in ipairs(slots) do assert(equipped[slot]==tww[i] and bag[i]==midnight[i]) end
assert(pickups==9 and invalidations==beforeSwapInvalidations+1 and CO.preparedFinisherUseEngineOrderID==nil)
assert(CO:GetOrderEquipmentPlan(order,page,true)=='waiting')
assert(not CO:PrepareOrderEquipment(order,page))
assert(pickups==9)
now=11
assert(CO:GetOrderEquipmentPlan(order,page,true)=='ready')

-- Deferred automatic choices are checked using the worn set and original
-- concentration/profit rules; no optimistic pre-swap quality may authorize it.
CO:RememberEquipmentQueueAnalysis(order,{needsEquipment=true,equipmentOptions={knowledgeOnly=true}})
local qualityReady=false
CO.GetAvailabilityQueueAnalysis=function(_,candidate,_,opts)
    assert(candidate==order and opts.knowledgeOnly and equipped[20]==tww[1])
    if qualityReady then return {queued=true,useConcentration=false} end
end
assert(CO:NeedsEquipmentQueueRecheck(order))
assert(not CO:PrepareOrderEquipment(order,page))
assert(not CO:IsOrderEquipmentReadyForSubmission(order,page))
qualityReady=true
assert(CO:PrepareOrderEquipment(order,page))
assert(CO:IsOrderEquipmentReadyForSubmission(order,page) and not CO.useConcentration['1'])

-- Accessories exchanged between slots are found, not reported missing.
equipped[21],equipped[22]=equipped[22],equipped[21]
assert(CO:GetOrderEquipmentPlan(order,page,true)=='swap')
assert(not CO:PrepareOrderEquipment(order,page))
assert(equipped[21]==tww[2] and equipped[22]==tww[3])
now=12

-- Saving an incomplete set does not overwrite the previous good set.
local saved=CO:GetProfessionEquipmentProfile('tww')
equipped[22]=nil
assert(not CO:SaveProfessionEquipmentProfile('tww'))
assert(CO:GetProfessionEquipmentProfile('tww')==saved)
equipped[22]=tww[3]
owner='Player-B';assert(not CO:GetProfessionEquipmentProfile('tww') and not CO:IsOrderEquipmentOn())
owner='Player-A';profession=333;assert(not CO:GetProfessionEquipmentProfile('tww') and not CO:IsOrderEquipmentOn())
profession=164
assert(CO:GetProfessionEquipmentProfile('tww')==saved and CO:IsOrderEquipmentOn())
assert(CO:GetOrderExpansionKey({hironPatronExpansionKey='tww',expansionID=11})=='tww')

-- Even a legacy delayed retry must not replace a saved set's instrument.
dofile('Workflow/Orders/CraftingOrders/Panel.lua')
CO.IsEnabled=function() error('legacy auto tool did not yield to saved sets') end
CO:AutoEquipResourcefulnessTool(page,8)

-- The real row dispatcher does not prepare equipment for a blocked/rejecting
-- row or a completed craft; it routes a preparation action back through gates.
dofile('Workflow/Orders/CraftingOrders/Actions.lua')
CO.IsOrderSubmissionPending=function() return pending end
CO.IsOrderListReadyForAction=function() return true end
CO.BeginListAction,CO.SetActiveRowButton,CO.DiagnoseRowAction,CO.RefreshHoveredRowButtonTooltip=noop,noop,noop,noop
CO.IsOrderFulfilled=function() return false end
local action, enabled, preparations, submissions='blocked',false,0,0
CO.GetRowAction=function() return action,'reason',order,enabled end
CO.PrepareOrderEquipment=function() preparations=preparations+1;action='claim';return true end
CO.ClaimOrder,CO.RejectOrder,CO.FulfillOrder=function() submissions=submissions+1 end,
    function() submissions=submissions+1 end,function() submissions=submissions+1 end
local btn={orderID=1,order=order,pageFrame=page}
CO:RunRowButtonAction(btn);assert(preparations==0 and submissions==0)
action,enabled='reject',true;CO:RunRowButtonAction(btn);assert(preparations==0 and submissions==1)
action='fulfill';CO:RunRowButtonAction(btn);assert(preparations==0 and submissions==2)
action='equip';CO:RunRowButtonAction(btn);assert(preparations==1 and submissions==3)
pending=true;CO:RunRowButtonAction(btn);assert(preparations==1 and submissions==3)
print('Profession equipment tests passed (exact sets, guards, settle window, quality recheck and row dispatch).')
