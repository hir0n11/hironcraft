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
order.reagents={}
assert(CO:GetOrderProblemReason(order)=='COA_PROBLEM_CUSTOMER_REAGENTS')
assert(not CO:GetOrderProblemReason(order,nil,'fulfill'), 'finished row retained a warning')
order=reset();order.reagentState=1
assert(CO:GetOrderProblemReason(order)=='COA_PROBLEM_CUSTOMER_REAGENTS')
order.orderType=4
assert(not CO:GetOrderProblemReason(order), 'patron missing customer mats was treated as a decline')
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
print('Order problem tests passed (missing customer/crafter reagents, quality/limits, concentration, unknown data, terminal rows, no actions).')
