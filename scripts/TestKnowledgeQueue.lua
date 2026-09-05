-- Queue selection regression tests; no protected crafting actions are invoked.
if not setfenv then
    function setfenv(fn, env)
        if type(fn) == 'number' then fn = debug.getinfo(fn + 1, 'f').func end
        for i = 1, 100 do
            local name = debug.getupvalue(fn, i)
            if not name then break end
            if name == '_ENV' then
                debug.upvaluejoin(fn, i, function() return env end, 1)
                break
            end
        end
        return fn
    end
end
local function noop() end
local CO = { selectedOrders={}, selectedReagents={}, useConcentration={}, rowStates={} }
local opts = {minProfitCopper=100, allowConcentration=true}
local page = {orderType=4}
CO.activePageFrame = page
local orders = {
    {orderID=1, spellID=101, orderType=4, profit=500},
    {orderID=2, spellID=102, orderType=4, profit=-200, npcOrderRewards={{itemID=900}}},
    {orderID=3, spellID=103, orderType=4, profit=-300},
    {orderID=4, spellID=104, orderType=4, profit=-400, needsConcentration=true, npcOrderRewards={{itemID=900}}},
    {orderID=5, spellID=105, orderType=4, profit=-500, unknown=true, npcOrderRewards={{itemID=900}}},
    {orderID=6, spellID=106, orderType=4, profit=-600, missingReagents=true, npcOrderRewards={{itemID=900}}},
    {orderID=7, spellID=107, orderType=4, profit=700, npcOrderRewards={{itemID=900}}},
    {orderID=8, spellID=108, orderType=3, profit=800, npcOrderRewards={{itemID=900}}},
    {orderID=9, spellID=109, orderType=4, npcOrderRewards={{itemID=900}}}, -- unknown price
}
local timers, requests, applied = {}, {}, {}
local hasProfession = false
local E = setmetatable({
    PT={}, CO=CO,
    T=function(_, fallback) return fallback end,
    GetDB=function() return {queue=opts} end,
    OrderKey=function(id) return id and tostring(id) end,
    GetProfessionFromPage=function() return hasProfession and 1 end,
    GetRewardItemID=function(reward) return reward.itemID end,
    IsKnowledgePointRewardItem=function(id) return id == 900 end,
    IsResultOk=function(result) return result == 0 end,
    wipe=function(t) for key in pairs(t) do t[key] = nil end end,
    Enum={CraftingOrderType={Npc=4, Personal=3, Public=1}},
    C_CraftingOrders={
        GetCrafterOrders=function() return orders end,
        RequestCrafterOrders=function(request) requests[#requests+1] = request end,
    },
    C_Timer={After=function(delay, callback)
        if delay == 0 then callback() else timers[#timers+1] = callback end
    end},
}, {__index=_G})
HironCraftProfitCraftingOrdersEnv = E
dofile('ProfitHub/Orders/CraftingOrders/QueueShopping.lua')
CO.FindOrderPageFrame=function() return page end
CO.GetVisibleOrderButtonsSorted=function()
    local buttons={}
    for _, order in ipairs(orders) do buttons[#buttons+1]={order=order} end
    buttons[#buttons+1]={order=orders[2]} -- duplicate native row
    return buttons
end
CO.GetOrderProfitInfo=function(_, order) return {profit=order.profit} end
CO.PrepareOrderForQueueAnalysis=function() return true end
CO.GetRecipeKnownState=function(_, order) return not order.unknown end
CO.OrderMatchesSelectedProfessionExpansion=function() return true end
CO.CanSupplyCrafterReagentsForQueue=function(_, order) return not order.missingReagents end
CO.OrderRequiresConcentrationForQueue=function(_, order) return order.needsConcentration == true end
CO.GetOrderQualityInfo=function() return {quality=5} end
CO.ApplyQueueReagentModeToOrder=function(_, order)
    applied[order.orderID]=(applied[order.orderID] or 0)+1
    return true
end
CO.GetOrderActionAvailabilitySortRank=function(_, order)
    if order.unknown then return 4 end
    if order.needsConcentration then return 3 end
    return order.missingReagents and 2 or 1
end
CO.GetClaimedOrder=function() return nil end
CO.RefreshVisibleRows, CO.UpdateControlPanel = noop, noop
CO.SetStatus=function(_, status) CO.status=status end

local function assertSelection(expected)
    local actual={}
    for key, selected in pairs(CO.selectedOrders) do if selected then actual[#actual+1]=tonumber(key) end end
    table.sort(actual)
    assert(table.concat(actual, ',') == expected, 'wrong selection: '..table.concat(actual, ',')..'; expected '..expected)
end
local function completeRequest(result)
    local request=table.remove(requests, 1)
    assert(request, 'missing server request')
    request.callback(result or 0)
end

-- Both the visible-row fallback and server-backed path add knowledge to
-- profitable selections, including missing materials to buy and missing prices.
for _, serverBacked in ipairs({false,true}) do
    hasProfession=serverBacked
    CO.selectedOrders={}
    CO._knowledgeOnly=true -- a leftover field must no longer control selection
    CO:QueueWorkOrdersSelection()
    if serverBacked then completeRequest() end
    assertSelection('1,7')
    local previousApplied=applied[7]
    local previousCurrent=CO.currentQueueOrderID
    CO.useConcentration['7']=true
    CO.selectedReagents['7:1']={itemID=1234}
    local previousReagent=CO.selectedReagents['7:1']

    CO:QueueWorkOrdersSelection(true)
    if serverBacked then completeRequest() end
    assertSelection('1,2,6,7,9')
    assert(CO.useConcentration['7'] == true and CO.selectedReagents['7:1'] == previousReagent,
        'knowledge selection overwrote an existing order configuration')
    assert(applied[7] == previousApplied and CO.currentQueueOrderID == previousCurrent,
        'knowledge selection reprocessed an already selected order')
    assert(opts.minProfitCopper == 100 and opts.knowledgeOnly == nil and opts.allowConcentration == true,
        'selection mode mutated saved filters')
    assert(CO.status == 'Queued orders: 5.', 'status does not include existing selections')

    CO:QueueWorkOrdersSelection(true)
    if serverBacked then completeRequest() end
    assertSelection('1,2,6,7,9')

    CO:QueueWorkOrdersSelection()
    if serverBacked then completeRequest() end
    assertSelection('1,7') -- normal queue must still honor the profit filter
end

hasProfession=false
CO.selectedOrders={}
CO:QueueWorkOrdersSelection(true)
assertSelection('2,6,7,9') -- standalone knowledge selection remains possible

-- A failed request and a timeout must retain the additive mode on fallback.
hasProfession=true
CO.selectedOrders={['1']=true}
CO:QueueWorkOrdersSelection(true)
completeRequest(1)
assertSelection('1,2,6,7,9')
timers={}
CO.selectedOrders={['1']=true}
CO:QueueWorkOrdersSelection(true)
local staleRequest=table.remove(requests, 1)
assert(#timers == 1)
timers[1]()
assertSelection('1,2,6,7,9')
CO:QueueWorkOrdersSelection()
completeRequest()
assertSelection('1,7')
staleRequest.callback(0)
assertSelection('1,7') -- late knowledge response cannot affect a newer queue

print('Knowledge queue tests passed.')
