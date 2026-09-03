-- Regression coverage for linked-account status ordering. Revisions are local
-- to each account, so terminal progress and request identity must decide before
-- a raw revision number does.
local callbacks = {}
local now = 1000

local CraftScan = {
    DB = {
        settings = { my_uuid = "test-account" },
        realm = {},
        listed_orders = {},
        customers = {},
    },
    Utils = {},
    Events = { Emit = function() end },
}

function CraftScan.Utils.saved(parent, key, default)
    if parent[key] == nil then parent[key] = default end
    return parent[key]
end

function CraftScan.Utils.onLoad(callback)
    callback()
end

function CraftScan.GetPlayerName()
    return "Crafter-Realm"
end

function CraftScan.OrderToOrderID(order)
    return order.customerName .. "-" .. tostring(order.responseID)
end

function CraftScan.OrderToResponse(order)
    local customer = CraftScan.DB.customers[order.customerName]
    return customer and customer.responses[order.responseID]
end

function CraftScan.OrderToLiveResponse()
    return nil
end

function time()
    return now
end

function issecretvalue()
    return false
end

HironCraftScanScannerMenu = {
    RegisterEventCallback = function(_, event, callback)
        callbacks[event] = callback
    end,
}

C_Timer = {
    After = function(_, callback) callback() end,
}

C_CraftingOrders = {
    GetClaimedOrder = function() return nil end,
}

local sourcePath = arg[1]
assert(sourcePath, "OrderFulfillment.lua path required")
assert(loadfile(sourcePath))("HironCraft", CraftScan)

local order = { customerName = "Buyer-Realm", responseID = 1234 }
CraftScan.DB.listed_orders[CraftScan.OrderToOrderID(order)] = order
CraftScan.DB.customers[order.customerName] = {
    responses = {
        [order.responseID] = {
            requestToken = "request-one",
            time = 100,
            crafterFullName = "Crafter-Realm",
        },
    },
}

local claimed = {
    customerName = order.customerName,
    responseID = order.responseID,
    status = "claimed",
    requestToken = "request-one",
    requestTime = 100,
    craftingOrderID = 5001,
    origin = "account-a",
    rev = 9,
    updatedAt = 110,
}
local changed, accepted = CraftScan.OrderFulfillment:ApplyRemoteStatus(claimed)
assert(changed and accepted, "initial claimed state should be accepted")

local fulfilled = {
    customerName = order.customerName,
    responseID = order.responseID,
    status = "fulfilled",
    requestToken = "request-one",
    requestTime = 100,
    craftingOrderID = 5001,
    origin = "account-b",
    rev = 3,
    updatedAt = 120,
}
changed, accepted = CraftScan.OrderFulfillment:ApplyRemoteStatus(fulfilled)
assert(changed and accepted, "fulfilled must beat a larger claimed revision")

local staleClaimed = {
    customerName = order.customerName,
    responseID = order.responseID,
    status = "claimed",
    requestToken = "request-one",
    requestTime = 100,
    craftingOrderID = 5001,
    origin = "account-a",
    rev = 10,
    updatedAt = 130,
}
local current
changed, accepted, current = CraftScan.OrderFulfillment:ApplyRemoteStatus(staleClaimed)
assert(not changed and not accepted, "a conflicting regression must not be ACKed")
assert(current and current.status == "fulfilled", "current terminal state must be returned for repair")

changed, accepted = CraftScan.OrderFulfillment:ApplyRemoteStatus(fulfilled)
assert(not changed and accepted, "an exact idempotent replay should be ACKed")

local nextRequest = {
    customerName = order.customerName,
    responseID = order.responseID,
    status = "claimed",
    requestToken = "request-two",
    requestTime = 200,
    craftingOrderID = 5002,
    origin = "account-a",
    rev = 1,
    updatedAt = 210,
}
changed, accepted = CraftScan.OrderFulfillment:ApplyRemoteStatus(nextRequest)
assert(changed and accepted, "a newer request must replace an old terminal row")

local oldRequestReplay = {
    customerName = order.customerName,
    responseID = order.responseID,
    status = "fulfilled",
    requestToken = "request-one",
    requestTime = 100,
    craftingOrderID = 5001,
    origin = "account-b",
    rev = 20,
    updatedAt = 300,
}
changed, accepted, current = CraftScan.OrderFulfillment:ApplyRemoteStatus(oldRequestReplay)
assert(not changed and not accepted, "an old request must not overwrite the newer job")
assert(current and current.requestToken == "request-two")

local batchChanged, batchAccepted, batchConflicts =
    CraftScan.OrderFulfillment:ApplyRemoteStatuses({ nextRequest, oldRequestReplay })
assert(not batchChanged)
assert(#batchAccepted == 1, "only the exact replay should be acknowledged")
assert(#batchConflicts == 1 and batchConflicts[1].requestToken == "request-two")

print("Order status merge tests passed.")
