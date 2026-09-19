-- Lightweight regression test for the finishing-reagent selector. It runs in
-- Fengari during development and mocks only the Blizzard transaction surface
-- used by FinishingReagents.lua.
if not setfenv then
    function setfenv(fn, env)
        if type(fn) == "number" then
            fn = debug.getinfo(fn + 1, "f").func
        end
        local index = 1
        while true do
            local name = debug.getupvalue(fn, index)
            if not name then return fn end
            if name == "_ENV" then
                debug.upvaluejoin(fn, index, function() return env end, 1)
                return fn
            end
            index = index + 1
        end
    end
end

unpack = unpack or table.unpack

local owned = {}
local itemBonuses = {
    [246447] = 5,
    [246448] = 10,
    [246449] = 20,
    [246450] = 50,
}
local activeAllocations = {}
local baseSkill = 408
local enabled = true
local maxAllowed = 5
local invalidatedOrderID
local operationCalls = 0
local detailsRefreshCalls = 0
local createRefreshCalls = 0
local finishingDataSlotIndex = 1
local preferredDB = {}
local unavailableSchematic, unavailableOperation, allocationFails, statPenalty = false, false, false, false
local bonusIDs = {247725, 247726, 247719, 247724, 260630, 247788}

Enum = {
    CraftingReagentType = { Finishing = 3 },
    CraftingOrderType = { Personal = 2, Npc = 4 },
}

C_Item = {
    GetItemNameByID = function(id) return 'Finisher '..id end,
    GetItemCount = function(itemID)
        return owned[itemID] or 0
    end,
}

C_TradeSkillUI = {
    GetRecipeSchematic = function()
        if unavailableSchematic then return nil end
        local reagents = {{itemID=999999}}
        for _, id in ipairs(bonusIDs) do reagents[#reagents+1]={itemID=id} end
        for _, id in ipairs({246447,246448,246449,246450}) do reagents[#reagents+1]={itemID=id} end
        return {
            reagentSlotSchematics = {
                {
                    reagentType = Enum.CraftingReagentType.Finishing,
                    dataSlotIndex = finishingDataSlotIndex,
                    quantityRequired = 1,
                    reagents = reagents,
                },
            },
        }
    end,
    GetCraftingOperationInfoForOrder = function()
        operationCalls = operationCalls + 1
        local itemID = activeAllocations[1]
        if (unavailableOperation==true and itemID)
            or (unavailableOperation=='skill' and itemBonuses[itemID]) then return nil end
        local bonus = itemBonuses[itemID] or 0
        if statPenalty and itemID == 247726 then bonus = -50 end
        return {
            baseSkill = baseSkill,
            bonusSkill = bonus,
            baseDifficulty = 410,
            bonusDifficulty = 0,
            craftingQuality = baseSkill + bonus >= 410 and 5 or 4,
        }
    end,
}

function GetTime() return 100 end
function GetDB() return preferredDB end
function OrderKey(orderID) return tostring(orderID) end
function SafeNum(value) return tonumber(value) or 0 end
function SafeCall(_, callback)
    local ok = pcall(callback)
    return ok
end
function GetSlotReagentType(slot) return slot and slot.reagentType end
function GetOrderReagentItemID(reagent) return reagent and reagent.itemID end

local transaction = {}
function transaction:OverwriteAllocation(slotIndex, reagent)
    if allocationFails then error('allocation failed') end
    activeAllocations[slotIndex] = reagent.itemID
end
function transaction:GetAllocations(slotIndex)
    return {
        GetFirstAllocation = function()
            local itemID = activeAllocations[slotIndex]
            if not itemID then return nil end
            return {GetReagent=function() return {itemID=itemID} end, GetQuantity=function() return 1 end}
        end,
        Clear = function()
            activeAllocations[slotIndex] = nil
        end,
    }
end
function transaction:OverwriteAllocations() end
function transaction:SetManuallyAllocated() end
function transaction:CreateCraftingReagentInfoTbl()
    return activeAllocations
end

local form = { UpdateDetailsStats = function() detailsRefreshCalls = detailsRefreshCalls + 1 end }
local engine = { UpdateCreateButton = function() createRefreshCalls = createRefreshCalls + 1 end }

HironCraftProfitCraftingOrdersEnv = {
    PT = {},
    CO = {},
}
setmetatable(HironCraftProfitCraftingOrdersEnv, { __index = _G })
local CO = HironCraftProfitCraftingOrdersEnv.CO
dofile("ProfitHub/Orders/CraftingOrders/QueueShopping.lua")

function CO:IsAutoFinishingEnabled() return enabled end
function CO:GetAutoFinishingMaxSkillBonus() return maxAllowed end
function CO:IsPersonalCraftingOrder(order) return order.orderType == Enum.CraftingOrderType.Personal end
function CO:GetOrderRequestedQuality(order) return order.minQuality end
function CO:GetTransactionFromEngine() return transaction, form end
function CO:BuildQualityInfoFromOperationInfo(_, info)
    if not info then return nil end
    return {
        quality = info.craftingQuality,
        skill = (info.baseSkill or 0) + (info.bonusSkill or 0),
        upper = (info.baseDifficulty or 0) + (info.bonusDifficulty or 0),
    }
end
function CO:InvalidateOrderCaches(orderID) invalidatedOrderID = orderID end

dofile("ProfitHub/Orders/CraftingOrders/FinishingReagents.lua")

local order = {
    orderID = 42,
    spellID = 7,
    minQuality = 5,
    orderType = Enum.CraftingOrderType.Personal,
}

local function Reset(skill, limit)
    baseSkill = skill
    maxAllowed = limit
    activeAllocations = {}
    preferredDB = {}
    unavailableSchematic, unavailableOperation, allocationFails, statPenalty = false, false, false, false
    order.orderType, order.isRecraft, order.minQuality, order.reagents = Enum.CraftingOrderType.Personal, false, 5, nil
    engine.reagentSlotProvidedByCustomer = nil
    invalidatedOrderID = nil
    operationCalls = 0
    detailsRefreshCalls = 0
    createRefreshCalls = 0
    for itemID in pairs(itemBonuses) do owned[itemID] = 1 end
    owned[999999] = 1
    for _, id in ipairs(bonusIDs) do owned[id] = 1 end
    CO:ClearOrderQualityRejection(order)
end

Reset(408, 5)
local result, candidate = CO:PrepareAutoFinishingReagent(engine, order, false)
assert(result == "applied" and candidate.skillBonus == 5 and activeAllocations[1] == 246447)
assert(invalidatedOrderID == order.orderID)
assert(operationCalls == 2, "only base and the selected +5 finisher should be evaluated")
assert(detailsRefreshCalls == 1 and createRefreshCalls == 1, "intermediate candidates must not refresh the UI")

Reset(400, 10)
result, candidate = CO:PrepareAutoFinishingReagent(engine, order, false)
assert(result == "applied" and candidate.skillBonus == 10 and activeAllocations[1] == 246448)
assert(operationCalls == 2, "finishers below the required skill gap must be skipped")

Reset(399, 10)
result = CO:PrepareAutoFinishingReagent(engine, order, false)
assert(result == "reject" and activeAllocations[1] == nil)
assert(CO:IsOrderReadyForQualityRejection(order))
assert(operationCalls == 1, "an impossible configured limit should be rejected without simulations")

Reset(390, 20)
result, candidate = CO:PrepareAutoFinishingReagent(engine, order, false)
assert(result == "applied" and candidate.skillBonus == 20 and activeAllocations[1] == 246449)
assert(operationCalls == 2)

Reset(360, 50)
result, candidate = CO:PrepareAutoFinishingReagent(engine, order, false)
assert(result == "applied" and candidate.skillBonus == 50 and activeAllocations[1] == 246450)
assert(operationCalls == 2)

Reset(408, 5)
owned[246447] = 0
result, candidate = CO:PrepareAutoFinishingReagent(engine, order, false)
assert(result == "reject" and candidate.currentQuality == 4 and activeAllocations[1] == nil)
assert(operationCalls == 1, "unowned and unrelated finishers must not be simulated")

enabled = false
Reset(408, 5)
assert(CO:PrepareAutoFinishingReagent(engine, order, false) == "disabled")

-- Transaction allocation keys are schematic positions, not dataSlotIndex.
-- Recraft schematics can give the finishing slot a different payload index.
enabled = true
finishingDataSlotIndex = 9
order.isRecraft = true
Reset(400, 10)
order.isRecraft = true
result, candidate = CO:PrepareAutoFinishingReagent(engine, order, false)
assert(result == "applied" and candidate.slotIndex == 1 and candidate.dataSlotIndex == 9,
    "recraft finisher used the API dataSlotIndex as a transaction slot")
assert(activeAllocations[1] == 246448 and activeAllocations[9] == nil)

-- Exact item and separate craft/recraft scope; skill priority remains independent.
Reset(410, 10)
CO:SetPreferredFinishingItemID(247726)
assert(CO:ShouldUsePreferredFinisher(order))
order.isRecraft = true
assert(not CO:ShouldUsePreferredFinisher(order), 'bonus recrafting was enabled by default')
CO:SetPreferredFinishingScope(true, true)
assert(CO:ShouldUsePreferredFinisher(order))
CO:SetPreferredFinishingScope(false, false)
order.isRecraft = false
assert(not CO:ShouldUsePreferredFinisher(order))
CO:SetPreferredFinishingScope(false, true)
result, candidate = CO:PrepareAutoFinishingReagent(engine, order, false)
assert(result=='applied' and candidate.itemID==247726 and not candidate.skillBonus)
assert(operationCalls==2, 'bonus finisher evaluated unrelated items')

for _, itemID in ipairs(bonusIDs) do
    Reset(410, 10)
    CO:SetPreferredFinishingItemID(itemID)
    result,candidate=CO:PrepareAutoFinishingReagent(engine,order,false)
    assert(result=='applied' and candidate.itemID==itemID, 'a Midnight bonus variant was omitted')
end

Reset(408, 5)
CO:SetPreferredFinishingItemID(247726)
result,candidate=CO:PrepareAutoFinishingReagent(engine,order,false)
assert(result=='applied' and candidate.itemID==246447, 'resource bonus outranked required skill')
Reset(399, 10)
CO:SetPreferredFinishingItemID(247726)
local rejectedResult,rejectedDetails=CO:PrepareAutoFinishingReagent(engine,order,false)
assert(rejectedResult=='reject')
assert(rejectedDetails.currentQuality and rejectedDetails.requestedQuality
    and CO.qualityRejectDetails[tostring(order.orderID)]==rejectedDetails,'quality decline lost its diagnostic context')
assert(not activeAllocations[1], 'bonus reagent was used when skill requirement was impossible')

Reset(408, 5)
order.isRecraft=true
CO:SetPreferredFinishingItemID(247726)
result,candidate=CO:PrepareAutoFinishingReagent(engine,order,false)
assert(result=='applied' and candidate.skillBonus==5, 'bonus recraft opt-out disabled required skill')
Reset(410, 5)
CO:SetPreferredFinishingItemID(247726)
order.orderType=Enum.CraftingOrderType.Npc
assert(CO:PrepareAutoFinishingReagent(engine,order,false)=='disabled' and operationCalls==0)

Reset(410, 5)
CO:SetPreferredFinishingItemID(247726)
owned[247726],owned[247725]=0,5
assert(CO:PrepareAutoFinishingReagent(engine,order,false)=='not_needed')
assert(not activeAllocations[1], 'five green items replaced/combined into the selected blue one')
CO:SetPreferredFinishingItemID(888888)
assert(CO:PrepareAutoFinishingReagent(engine,order,false)=='not_needed', 'incompatible item was allocated')

Reset(410, 5)
CO:SetPreferredFinishingItemID(247726)
engine.reagentSlotProvidedByCustomer={[1]=true}
assert(CO:PrepareAutoFinishingReagent(engine,order,false)=='not_needed')
engine.reagentSlotProvidedByCustomer=nil
order.reagents={{dataSlotIndex=finishingDataSlotIndex,itemID=247725}}
assert(CO:PrepareAutoFinishingReagent(engine,order,false)=='not_needed', 'customer finisher was overwritten')
order.reagents=nil
activeAllocations[1]=247725
assert(CO:PrepareAutoFinishingReagent(engine,order,false)=='not_needed' and activeAllocations[1]==247725)

Reset(408, 5)
activeAllocations[1],activeAllocations[2]=247726,999999
unavailableOperation=true
-- Base info is unavailable too: fail closed without modifying anything.
assert(CO:PrepareAutoFinishingReagent(engine,order,false)=='unknown')
assert(activeAllocations[1]==247726 and activeAllocations[2]==999999)
activeAllocations[1]=nil
assert(CO:PrepareAutoFinishingReagent(engine,order,false)=='unknown')
assert(not activeAllocations[1] and activeAllocations[2]==999999 and not CO:IsOrderReadyForQualityRejection(order))
Reset(408,5)
activeAllocations[1],activeAllocations[2]=247726,999999
unavailableOperation='skill'
assert(CO:PrepareAutoFinishingReagent(engine,order,false)=='unknown')
assert(activeAllocations[1]==247726 and activeAllocations[2]==999999,
    'failed skill simulation erased the original finishing allocations')
Reset(399,10)
activeAllocations[1],activeAllocations[2]=247726,999999
assert(CO:PrepareAutoFinishingReagent(engine,order,false)=='reject')
assert(activeAllocations[1]==247726 and activeAllocations[2]==999999,
    'quality rejection erased existing finishing allocations')

Reset(410, 5)
CO:SetPreferredFinishingItemID(247726)
statPenalty=true
assert(CO:PrepareAutoFinishingReagent(engine,order,false)=='not_needed' and not activeAllocations[1],
    'bonus finisher lowered the guaranteed quality')
statPenalty=false
unavailableSchematic=true
assert(CO:PrepareAutoFinishingReagent(engine,order,false)=='unknown')
unavailableSchematic=false
allocationFails=true
assert(CO:PrepareAutoFinishingReagent(engine,order,false)=='unknown')

enabled=false
Reset(410, 5)
CO:SetPreferredFinishingItemID(247726)
order.minQuality=0
result,candidate=CO:PrepareAutoFinishingReagent(engine,order,false)
assert(result=='applied' and candidate.itemID==247726 and operationCalls==0,
    'ordinary finisher requires skill mode or a quality minimum')
CO.preparedFinisherOrderID,CO.preparedFinisherReagent=42,candidate
CO:MarkOrderReadyForQualityRejection(order)
CO:SetPreferredFinishingScope(false,false)
assert(not CO.preparedFinisherOrderID and not CO:IsOrderReadyForQualityRejection(order), 'settings retained stale preparation/rejection')

CO.CustomList={GetOrders=function() return {order} end}
local listed={}
for _,item in ipairs(CO:GetPreferredFinishingMenuItems()) do listed[item.itemID]=true end
for _,id in ipairs(bonusIDs) do assert(listed[id]) end
assert(listed[999999] and not listed[246447], 'picker is not extensible or mixes in skill finishers')

-- Respect actual recipe-slot unlocks rather than inferring them from ownership.
enabled=true
Reset(410,5)
CO:SetPreferredFinishingItemID(247726)
C_TradeSkillUI.GetRecipeInfo=function() return {recipeID=7} end
Professions={GetReagentSlotStatus=function() return true,'Locked' end}
assert(CO:PrepareAutoFinishingReagent(engine,order,false)=='not_needed' and not activeAllocations[1])
Professions.GetReagentSlotStatus=function() error('Unavailable slot status') end
assert(CO:PrepareAutoFinishingReagent(engine,order,false)=='unknown')
assert(not CO:IsOrderReadyForQualityRejection(order))

print("Finishing reagent tests passed.")
