-- Extend the real queue's pagination/knowledge baseline with expansion rules.
dofile('scripts/TestKnowledgeQueue.lua')
local E=HironCraftProfitCraftingOrdersEnv
local CO=E.CO
local db=E.GetDB()
E.GetDB=function() return db end
local owner,profession='Player-A',164
E.UnitGUID=function() return owner end
E.GetServerTime=function() return 10000000 end
E.GetProfessionFromPage=function() return profession end
E.SameOrderID=function(a,b) return tostring(a)==tostring(b) end
E.FindExpansionOptionByExpansionID=function(id) if id then return {key=id==10 and 'tww' or 'midnight'} end end
CO.GetActiveBaseProfessionID=function() return profession end
CO.GetOrderProfessionExpansionID=function(_,order) return order.expansionID end
CO.GetPatronExpansionScope=nil
CO.GetSelectedProfessionExpansionKey=function() return 'midnight' end
CO.RefreshVisibleRowsSoon=function() end
dofile('Workflow/Orders/CraftingOrders/Equipment.lua')
dofile('Workflow/Orders/CraftingOrders/SelectionMemory.lua')
local rows={
    {orderID=101,spellID=201,orderType=4,profit=-500,expansionID=11,npcOrderRewards={{itemID=900}}},
    {orderID=102,spellID=202,orderType=4,profit=-500,hironPatronExpansionKey='tww',expansionID=11,npcOrderRewards={{itemID=900}}},
    {orderID=103,spellID=203,orderType=4,profit=0,expansionID=10,npcOrderRewards={{itemID=900}}},
    {orderID=104,spellID=204,orderType=4,profit=-500,expansionID=10},
    {orderID=105,spellID=205,orderType=4,profit=500,expansionID=10},
    {orderID=106,spellID=206,orderType=4,profit=-100,expansionID=10,npcOrderRewards={{itemID=900}},needsConcentration=true},
}
E.C_CraftingOrders.RequestCrafterOrders=nil
E.C_CraftingOrders.GetCrafterOrders=function() return rows end
CO.CustomList=nil
CO.GetVisibleOrderButtonsSorted=function()
    local result={};for _,order in ipairs(rows) do result[#result+1]={order=order} end;return result
end
CO:EnsureOrderSelectionContext(CO.activePageFrame)
db.queue.minProfitCopper=100
db.queue.knowledgeIgnoreProfit=true
db.queue.knowledgeMinProfitCopper=-1000
CO:SetKnowledgeExpansionProfitOverride('tww',0)
assert(CO:GetKnowledgeMinProfitCopper(rows[1])==-1000)
assert(CO:GetKnowledgeMinProfitCopper(rows[2])==0, 'combined metadata lost to selected expansion')
assert(CO:GetKnowledgeMinProfitCopper(rows[3])==0, 'zero became empty')
assert(CO:GetKnowledgeMinProfitCopper({})==-1000, 'unknown expansion must inherit')
assert(not CO:OrderPassesQueueProfitRule(rows[2],true,{}))
assert(CO:OrderPassesQueueProfitRule(rows[3],true,{}))
assert(not CO:OrderPassesQueueProfitRule(rows[4],false,{}), 'normal profit rule changed')
CO.selectedOrders={}
CO:QueueWorkOrdersSelection(true)
assert(CO.selectedOrders['101'] and CO.selectedOrders['103'])
assert(not CO.selectedOrders['102'] and not CO.selectedOrders['106'])

-- Automatic checks obey the same expansion threshold on a later strict
-- recheck, while manual choices remain manual and survive any new threshold.
CO:SetKnowledgeExpansionProfitOverride('tww',-1000)
CO:QueueWorkOrdersSelection(true)
assert(CO.selectedOrders['102'])
CO:RememberOrderSelection(rows[3].orderID,true,rows[3])
CO:SetKnowledgeExpansionProfitOverride('tww',100)
assert(not CO.selectedOrders['102'], 'strict recheck kept the old knowledge rule')
assert(CO.selectedOrders['101'] and CO.selectedOrders['103'], 'another expansion/manual check changed')
CO:SetKnowledgeExpansionProfitOverride('tww',nil)
assert(CO:GetKnowledgeMinProfitCopper(rows[2])==-1000, 'empty did not restore the common rule')
CO:SetKnowledgeExpansionProfitOverride('tww',0)
owner='Player-B';assert(CO:GetKnowledgeExpansionProfitOverride('tww')==nil)
CO:SetKnowledgeExpansionProfitOverride('tww',300)
owner='Player-A';assert(CO:GetKnowledgeExpansionProfitOverride('tww')==0)
profession=333;assert(CO:GetKnowledgeExpansionProfitOverride('tww')==nil)
profession=164;assert(CO:GetKnowledgeExpansionProfitOverride('tww')==0)
assert(not CO:SetKnowledgeExpansionProfitOverride('unknown',123))
print('Knowledge expansion tests passed (mixed list, zero/inherit, strict recheck, manual checks and character/profession isolation).')
