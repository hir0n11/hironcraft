dofile('scripts/TestKnowledgeQueue.lua')
local E=HironCraftProfitCraftingOrdersEnv
local CO=E.CO
local db=E.GetDB(); E.GetDB=function() return db end
E.UnitGUID=function() return 'Player-A' end
CO.GetActiveBaseProfessionID=function() return 164 end
db.queue.minProfitCopper=0
db.queue.knowledgeMinProfitCopper=nil
db.queue.knowledgeIgnoreProfit=true
dofile('Workflow/Orders/CraftingOrders/Equipment.lua')
CO._orderSelectionContext='combined-character-profession'
CO.IsOrderSubmissionPending=function() return false end
CO:SetOrderEquipmentOn(true)
local equipment='swap'
CO.GetOrderEquipmentPlan=function() return equipment,'equipment unavailable' end
local order={orderID=999,spellID=1999,orderType=4,minQuality=5,profit=500,needsConcentration=true,npcOrderRewards={{itemID=900}}}
CO.GetOrderQualityInfo=function(_,candidate,concentration)
    return {quality=(not candidate.needsConcentration or concentration) and 5 or 3,concentrationCost=0}
end
local opts={knowledgeOnly=true,allowConcentration=true}
local analysis=CO:GetAvailabilityQueueAnalysis(order,4,opts,CO.activePageFrame)
assert(analysis and analysis.queued and analysis.needsEquipment)
assert(not analysis.useConcentration, 'pre-swap estimate authorized concentration')
CO:MarkOrderQueuedForCheckbox(order,analysis,CO.activePageFrame)
assert(CO.selectedOrders['999'] and CO:NeedsEquipmentQueueRecheck(order))
assert(not CO:IsOrderEquipmentReadyForSubmission(order,CO.activePageFrame))
equipment='ready'
-- A knowledge queue must still refuse concentration even if the global queue
-- allows it and the wrong-set candidate was initially selected.
assert(not CO:PrepareOrderEquipment(order,CO.activePageFrame))
assert(CO:NeedsEquipmentQueueRecheck(order) and not CO.useConcentration['999'])
order.needsConcentration=false
assert(CO:PrepareOrderEquipment(order,CO.activePageFrame))
assert(not CO:NeedsEquipmentQueueRecheck(order) and not CO.useConcentration['999'])
assert(CO:IsOrderEquipmentReadyForSubmission(order,CO.activePageFrame))

-- Normal queues recheck their original allow-concentration option too.
equipment='swap';order.needsConcentration=true
opts={allowConcentration=true}
analysis=CO:GetAvailabilityQueueAnalysis(order,4,opts,CO.activePageFrame)
assert(analysis and analysis.needsEquipment)
CO:MarkOrderQueuedForCheckbox(order,analysis,CO.activePageFrame)
equipment='ready'
assert(CO:PrepareOrderEquipment(order,CO.activePageFrame))
assert(CO.useConcentration['999']==true)

-- If the real profit no longer passes with this set, do not claim/craft.
equipment='swap';order.needsConcentration=false;order.profit=500
analysis=CO:GetAvailabilityQueueAnalysis(order,4,{allowConcentration=false},CO.activePageFrame)
CO:MarkOrderQueuedForCheckbox(order,analysis,CO.activePageFrame)
equipment='ready';order.profit=-1
assert(not CO:PrepareOrderEquipment(order,CO.activePageFrame))
equipment='blocked'
assert(CO:GetAvailabilityQueueAnalysis(order,4,opts,CO.activePageFrame)==nil)
assert(CO.queueSkipReasons['999'].code=='equipment')
print('Equipment queue integration passed (preparation-only checks, real post-swap quality/concentration/profit gates).')
