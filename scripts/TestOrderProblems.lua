-- The red row is a read-only warning, not permission to decline an order.
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
local CO={orderIssues={},useConcentration={}}
local now=100
local E=setmetatable({PT={},CO=CO,SlashCmdList={},
    T=function(key) return key end,GetTime=function() return now end,
    OrderKey=function(id) return id and tostring(id) end,
    GetOrderRevision=function() return 0 end,
    CacheNow=function() return now end,REAGENT_CACHE_TTL=1,
    unpack=table.unpack,
    Enum={CraftingOrderType={Personal=2,Npc=4},CraftingOrderReagentsType={None=0,Some=1,All=2}},
}, {__index=_G})
HironCraftProfitCraftingOrdersEnv=E
dofile('ProfitHub/Orders/CraftingOrders/QualityReagents.lua')
dofile('ProfitHub/Orders/CraftingOrders/FinishingReagents.lua')
local q, known, supply, enabled, candidates, ready, effective
local function forbidden() error('Painting an order took a crafting action') end
CO.GetOrderEngine,CO.MarkOrderReadyForQualityRejection=forbidden,forbidden
CO.RejectOrder,CO.CraftOrderFromRow,CO.ApplySelectedReagentsToEngine=forbidden,forbidden,forbidden
CO.GetRecipeKnownState=function() return known end
CO.CanSupplyCrafterReagentsForQueue=function(_,_,force) assert(force==false);return supply end
CO.GetOrderRequestedQuality=function(_,order) return order.minQuality or 0 end
CO.GetOrderQualityInfo=function(_,_,conc,prepared)
    assert(prepared==false, 'warning prepared the live order')
    if conc then return {quality=5,skill=410,upper=410} end
    return q
end
CO.IsAutoFinishingEnabled=function() return enabled end
CO.GetAutoFinishingMaxSkillBonus=function() return 10 end
CO.GetFinishingReagentCandidates=function() return candidates,ready end
CO.GetEffectiveOrder=function(_,_,fallback) return effective or fallback end
CO.FindOrderPageFrame=function(_,page) return page end
CO.BuildDisplayReagents=function() return {ahuiSchematicReady=false} end
local function reset()
    q={quality=5,skill=410,upper=410}
    known,supply,enabled,ready=true,true,true,true
    candidates,effective={},nil
    CO.orderIssues,CO.useConcentration,CO.qualityRejectOrderIDs={},{},{}
    return {orderID=42,spellID=7,orderType=2,minQuality=5,reagentState=2,
        reagents={{itemID=100,quantity=10}}}
end
local order=reset()
assert(not CO:GetOrderProblemReason(order))

-- WoW 12.x operation-info APIs require CraftingReagentInfo.reagent instead of
-- the pre-12.0 top-level itemID. Both the full and fallback concentration paths
-- must submit the current shape or concentrationCost is omitted.
CO.craftingReagentInfoCache={}
CO.BuildDisplayReagents=function() return {ahuiSchematicReady=true} end
local concentrationOrder={orderID=77,spellID=8,reagentState=2,reagents={{
    slotIndex=4,
    reagentInfo={reagent={itemID=12345},dataSlotIndex=4,quantity=2},
}}}
local fullReagents=CO:BuildCraftingReagentInfoTbl(concentrationOrder)
local fastReagents=CO:BuildFastCraftingReagentInfoTbl(concentrationOrder)
for _, reagents in ipairs({fullReagents,fastReagents}) do
    assert(#reagents==1 and reagents[1].reagent.itemID==12345
        and reagents[1].itemID==nil and reagents[1].dataSlotIndex==4
        and reagents[1].quantity==2,
        'operation-info reagents still use the pre-12.0 schema')
end
E.C_TradeSkillUI={GetCraftingOperationInfo=function(_,reagents,_,applyConcentration)
    assert(applyConcentration==false and reagents[1].reagent.itemID==12345,
        'concentration fallback did not request the unapplied operation cost')
    return {concentrationCosts={{amount=137}}}
end}
assert(CO:GetFastConcentrationCost(concentrationOrder)==137,
    'concentration fallback did not read the operation cost')
E.C_TradeSkillUI=nil
CO.BuildDisplayReagents=function() return {ahuiSchematicReady=false} end

order.reagents={}
assert(CO:GetOrderProblemReason(order)=='COA_PROBLEM_CUSTOMER_REAGENTS')
assert(not CO:GetOrderProblemReason(order,nil,'fulfill'), 'finished row retained a warning')
order=reset();order.reagentState=1
assert(CO:GetOrderProblemReason(order)=='COA_PROBLEM_CUSTOMER_REAGENTS')
order.orderType=4
assert(not CO:GetOrderProblemReason(order), 'patron missing customer mats was treated as a decline')
known=false;supply=false;CO.orderIssues['42']='Patron issue'
assert(not CO:GetOrderProblemReason(order), 'patron was painted red for another problem')
order=reset();known=false
assert(CO:GetOrderProblemReason(order)=='COA_ACTION_UNKNOWN_RECIPE')
known=true;supply=false
assert(CO:GetOrderProblemReason(order)=='COA_ACTION_NO_REAGENTS')
order=reset();CO.orderIssues['42']='Specific problem'
assert(CO:GetOrderProblemReason(order)=='Specific problem')
order=reset();q={quality=4,skill=408,upper=410}
assert(CO:GetOrderProblemReason(order)=='COA_PROBLEM_FINISHER_LIMIT')
candidates={{skillBonus=5,owned=1,quantity=1}}
assert(not CO:GetOrderProblemReason(order), 'available skill finisher was ignored')
candidates={{skillBonus=20,owned=1,quantity=1}}
assert(CO:GetOrderProblemReason(order)=='COA_PROBLEM_FINISHER_LIMIT')
candidates={{skillBonus=5,owned=0,quantity=1}}
assert(CO:GetOrderProblemReason(order)=='COA_PROBLEM_FINISHER_LIMIT')
CO.useConcentration['42']=true
assert(not CO:GetOrderProblemReason(order), 'enabled concentration did not clear quality warning')
CO.useConcentration={};enabled=false
assert(CO:GetOrderProblemReason(order)=='COA_PROBLEM_QUALITY')
enabled=true;ready=false
assert(not CO:GetOrderProblemReason(order), 'unloaded schematic was reported as impossible')
ready=true;q=nil
assert(not CO:GetOrderProblemReason(order), 'missing quality was reported as impossible')
q={quality=0}
assert(not CO:GetOrderProblemReason(order), 'unknown zero quality was reported as impossible')
order=reset();CO.qualityRejectOrderIDs['42']=now+30
assert(CO:GetOrderProblemReason(order)=='COA_PROBLEM_FINISHER_LIMIT')
now=now+31
assert(not CO:GetOrderProblemReason(order), 'expired rejection persisted')
order=reset();effective=reset();effective.reagents={}
assert(CO:GetOrderProblemReason(order)=='COA_PROBLEM_CUSTOMER_REAGENTS', 'warning ignored fresh order details')
assert(next(CO.qualityRejectOrderIDs)==nil, 'warning armed a destructive action')

-- Blizzard prices one reagent allocation at a time and refuses some of them.
-- When the allocation we planned goes unanswered the row printed "?", even
-- though the client happily prices the order as the customer left it.
CO._fastConcCostCache=nil
CO.craftingReagentInfoCache={}
CO.selectedReagents={}
CO.BuildDisplayReagents=function()
    return {{itemID=777,quantity=5,slotIndex=2,dataSlotIndex=2,crafterRequired=true},
        ahuiSchematicReady=true}
end
local ladder={orderID=91,spellID=9,reagentState=1,minQuality=5,orderType=2,
    reagents={{reagentInfo={reagent={itemID=555},dataSlotIndex=1,quantity=3}}}}
local tried={}
E.C_TradeSkillUI={
GetRecipeSchematic=function()
    return {reagentSlotSchematics={{slotIndex=2,dataSlotIndex=2,required=true,
        quantityRequired=5,reagents={{itemID=777}}}}}
end,
GetCraftingOperationInfoForOrder=function(_,reagents,orderID,applied)
    assert(orderID==91,'the order cost was asked for without its order')
    tried[#tried+1]=(reagents and #reagents or -1)..':'..tostring(applied)
    -- Only the order as placed is priced, exactly like Blizzard's order page.
    if reagents and #reagents==1 then return {concentrationCost=271} end
    return {concentrationCost=0}
end}
local cost,source=CO:ResolveConcentrationCost(ladder)
assert(cost==271 and source=='as-placed',
    'the cost Blizzard shows for the order as placed was never asked for')
assert(tried[1]=='2:false','the allocation we would craft with must be asked first')
assert(#tried==5,'the ladder kept asking after it had an answer')
CO._fastConcCostCache=nil
assert(CO:GetFastConcentrationCost(ladder)==271,'the row still has no number to print')
-- A cost read from an allocation we would not craft with is not evidence that
-- this order needs concentration.
CO._fastConcCostCache=nil
local _,fallbackSource=CO:ResolveConcentrationCost(ladder)
assert(fallbackSource~='planned' and fallbackSource~='cheapest',
    'an unplanned allocation was reported as our own')
E.C_TradeSkillUI=nil
CO._fastConcCostCache=nil

-- Row colour: a Personal order says what it is before it is claimed, and an
-- answer that has not arrived stays unknown instead of looking healthy.
CO.BuildDisplayReagents=function() return {ahuiSchematicReady=true} end
order=reset()
assert(CO:GetOrderReadinessState(order,nil,'claim',false,false)=='ready')
assert(CO:GetOrderReadinessState(order,nil,'claim',true,false)=='concentration')
q=nil;CO.concentrationRequirementCache={};CO.qualityCache={}
assert(CO:GetOrderReadinessState(order,nil,'claim',nil,false)==nil,
    'an order Blizzard has not answered for yet was painted as ready')
q={quality=5,skill=410,upper=410};CO.concentrationRequirementCache={}
CO.BuildDisplayReagents=function() return {ahuiSchematicReady=false} end
assert(CO:GetOrderReadinessState(order,nil,'claim',false,false)==nil,
    'an unloaded schematic was painted as ready')
CO.BuildDisplayReagents=function() return {ahuiSchematicReady=true} end
assert(CO:GetOrderReadinessState(order,nil,'claim',false,'Missing reagents')=='blocked')
order.reagents={}
assert(CO:GetOrderReadinessState(order,nil,'claim',false)=='blocked',
    'missing customer reagents were not red')
assert(CO:GetOrderReadinessState(order,nil,'fulfill',false)==nil,
    'a finished row kept a state colour')
order=reset();order.orderType=4
assert(CO:GetOrderReadinessState(order,nil,'claim',true,false)==nil,
    'patron orders must keep their plain rows')
CO.BuildDisplayReagents=function() return {ahuiSchematicReady=false} end

print('Order problem tests passed (missing customer/crafter reagents, quality/limits, concentration, unknown data, terminal rows, no actions, row states, concentration cost ladder).')
