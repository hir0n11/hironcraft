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
    [1005] = 5,
    [1010] = 10,
    [1020] = 20,
    [1050] = 50,
}
local activeAllocations = {}
local baseSkill = 408
local enabled = true
local maxAllowed = 5
local invalidatedOrderID

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
                        { itemID = 1005 },
                        { itemID = 1010 },
                        { itemID = 1020 },
                        { itemID = 1050 },
                    },
                },
            },
        }
    end,
    GetCraftingOperationInfoForOrder = function()
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

local form = { UpdateDetailsStats = function() end }
local engine = { UpdateCreateButton = function() end }

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
    return { quality = info.craftingQuality }
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
    for itemID in pairs(itemBonuses) do owned[itemID] = 1 end
    CO:ClearOrderQualityRejection(order)
end

Reset(408, 5)
local result, candidate = CO:PrepareAutoFinishingReagent(engine, order, false)
assert(result == "applied" and candidate.skillBonus == 5 and activeAllocations[1] == 1005)
assert(invalidatedOrderID == order.orderID)

Reset(400, 10)
result, candidate = CO:PrepareAutoFinishingReagent(engine, order, false)
assert(result == "applied" and candidate.skillBonus == 10 and activeAllocations[1] == 1010)

Reset(399, 10)
result = CO:PrepareAutoFinishingReagent(engine, order, false)
assert(result == "reject" and activeAllocations[1] == nil)
assert(CO:IsOrderReadyForQualityRejection(order))

Reset(390, 20)
result, candidate = CO:PrepareAutoFinishingReagent(engine, order, false)
assert(result == "applied" and candidate.skillBonus == 20 and activeAllocations[1] == 1020)

Reset(360, 50)
result, candidate = CO:PrepareAutoFinishingReagent(engine, order, false)
assert(result == "applied" and candidate.skillBonus == 50 and activeAllocations[1] == 1050)

Reset(408, 5)
owned[1005] = 0
result, candidate = CO:PrepareAutoFinishingReagent(engine, order, false)
assert(result == "reject" and candidate.currentQuality == 4 and activeAllocations[1] == nil)

enabled = false
Reset(408, 5)
assert(CO:PrepareAutoFinishingReagent(engine, order, false) == "disabled")

print("Finishing reagent tests passed.")
