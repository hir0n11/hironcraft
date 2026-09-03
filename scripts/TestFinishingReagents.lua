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

Enum = {
    CraftingReagentType = { Finishing = 3 },
    CraftingOrderType = { Personal = 2 },
}

C_Item = {
    GetItemCount = function(itemID)
        return owned[itemID] or 0
    end,
}

C_TradeSkillUI = {
    GetRecipeSchematic = function()
        return {
            reagentSlotSchematics = {
                {
                    reagentType = Enum.CraftingReagentType.Finishing,
                    dataSlotIndex = 1,
                    quantityRequired = 1,
                    reagents = {
                        -- A non-skill finishing reagent must never be simulated.
                        { itemID = 999999 },
                        { itemID = 246447 },
                        { itemID = 246448 },
                        { itemID = 246449 },
                        { itemID = 246450 },
                    },
                },
            },
        }
    end,
    GetCraftingOperationInfoForOrder = function()
        operationCalls = operationCalls + 1
        local itemID = activeAllocations[1]
        local bonus = itemBonuses[itemID] or 0
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
    activeAllocations[slotIndex] = reagent.itemID
end
function transaction:GetAllocations(slotIndex)
    return {
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

function CO:IsAutoFinishingEnabled() return enabled end
function CO:GetAutoFinishingMaxSkillBonus() return maxAllowed end
function CO:IsPersonalCraftingOrder() return true end
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
    invalidatedOrderID = nil
    operationCalls = 0
    detailsRefreshCalls = 0
    createRefreshCalls = 0
    for itemID in pairs(itemBonuses) do owned[itemID] = 1 end
    owned[999999] = 1
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

print("Finishing reagent tests passed.")
