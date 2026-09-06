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

local noticeOrder = { customerName = "Asuna-Realm", responseID = 4321 }
CraftScan.DB.listed_orders[CraftScan.OrderToOrderID(noticeOrder)] = noticeOrder
CraftScan.DB.customers[noticeOrder.customerName] = {
    responses = {
        [noticeOrder.responseID] = {
            requestToken = "asuna-request",
            time = 400,
            crafterFullName = "RemoteCrafter-Realm",
            recipeID = 9876,
            itemID = 6789,
        },
    },
}
now = 410
local notice = {
    orderID = 7001,
    customerName = "Asuna",
    spellID = 9876,
    itemID = 6789,
    crafterFullName = "RemoteCrafter-Realm",
    origin = "remote-account",
    updatedAt = now,
    status = "fulfilled",
}
assert(CraftScan.OrderFulfillment:ApplyRemoteCompletion(notice))
local materialized = CraftScan.OrderFulfillment:GetStatuses()[CraftScan.OrderToOrderID(noticeOrder)]
assert(materialized and materialized.status == "fulfilled", "completion notice should materialize an exact row status")
assert(materialized.craftingOrderID == 7001, "materialized status should retain Blizzard order ID")

local noticeKey = CraftScan.OrderFulfillment:CompletionNoticeKey(notice)
local storedNotice = CraftScan.OrderFulfillment:GetCompletionNotices()[noticeKey]
storedNotice.deliveryPending = { ["linked-account"] = true }
assert(CraftScan.OrderFulfillment:AcknowledgeCompletion(notice, "linked-account"))
assert(not storedNotice.deliveryPending and storedNotice.deliveryConfirmedAt == now)

-- A client can reject an order, then fulfill its replacement under a new
-- Blizzard ID while retaining the same chat request. Periodic journal replay
-- must not promote the old rejection to a new event just because it arrived now.
local retryOrder = {customerName='RetryBuyer-Realm', responseID=8765}
local retryKey = CraftScan.OrderToOrderID(retryOrder)
CraftScan.DB.listed_orders[retryKey] = retryOrder
CraftScan.DB.customers[retryOrder.customerName] = {responses={
    [retryOrder.responseID]={requestToken='retry-request', time=500,
        crafterFullName='Crafter-Realm', recipeID=8765, itemID=5678},
}}
local rejectedNotice = {
    customerName='RetryBuyer', requestToken='retry-request', requestTime=500,
    spellID=8765, itemID=5678, orderID=8001, status='rejected',
    crafterFullName='Crafter-Realm', origin='reject-account', updatedAt=510,
}
local completedNotice = {
    customerName='RetryBuyer', requestToken='retry-request', requestTime=500,
    spellID=8765, itemID=5678, orderID=8002, status='fulfilled',
    crafterFullName='Crafter-Realm', origin='craft-account', updatedAt=520,
}
now=510
CraftScan.OrderFulfillment:ApplyRemoteCompletion(rejectedNotice)
assert(CraftScan.OrderFulfillment:GetStatus(retryOrder).status=='rejected')
now=520
CraftScan.OrderFulfillment:ApplyRemoteCompletion(completedNotice)
assert(CraftScan.OrderFulfillment:GetStatus(retryOrder).status=='fulfilled')
now=900
CraftScan.OrderFulfillment:ApplyRemoteCompletion(rejectedNotice)
assert(CraftScan.OrderFulfillment:GetStatus(retryOrder).status=='fulfilled',
    'replayed old rejection changed the successful replacement back to a cross')
assert(CraftScan.OrderFulfillment:GetStatuses()[retryKey].status=='fulfilled',
    'journal replay persisted a stale rejection for the completed request')
local completionEntry=CraftScan.OrderFulfillment:GetStatuses()[retryKey]
local completionRevision=completionEntry.rev
for pass=1,5 do
    now=now+60
    local firstNotice=pass%2==0 and completedNotice or rejectedNotice
    local secondNotice=pass%2==0 and rejectedNotice or completedNotice
    CraftScan.OrderFulfillment:ApplyRemoteCompletionNotices({firstNotice, secondNotice})
    assert(CraftScan.OrderFulfillment:GetStatus(retryOrder).status=='fulfilled')
    assert(completionEntry==CraftScan.OrderFulfillment:GetStatuses()[retryKey],
        'idempotent replay replaced the exact status and delivery tracking')
    assert(completionEntry.updatedAt==520 and completionEntry.rev==completionRevision,
        'replayed history was assigned a fresh timestamp or revision')
end

-- A raw status from an older client may already have had its clock/revision
-- inflated by a replay. Return the successful revision for repair, not an ACK.
local inflatedRejection={customerName=retryOrder.customerName, responseID=retryOrder.responseID,
    requestToken='retry-request', requestTime=500, craftingOrderID=8001,
    status='rejected', updatedAt=now+100, rev=99, origin='old-client'}
changed, accepted, current=CraftScan.OrderFulfillment:ApplyRemoteStatus(inflatedRejection)
assert(not changed and not accepted and current.status=='fulfilled',
    'inflated remote rejection overrode a successful request')
local previous=CraftScan.OrderFulfillment:SetStatus(retryOrder, 'rejected', {craftingOrderID=8001})
assert(previous.status=='fulfilled', 'late local reject callback replaced success')

-- Repair a cross already persisted by the old build, before and after replay.
CraftScan.DB.realm.order_statuses[retryKey]=inflatedRejection
assert(CraftScan.OrderFulfillment:GetStatus(retryOrder).status=='fulfilled',
    'the successful journal evidence did not repair the displayed stale cross')
CraftScan.OrderFulfillment:ApplyRemoteCompletion(rejectedNotice)
assert(CraftScan.OrderFulfillment:GetStatuses()[retryKey].status=='fulfilled',
    'replay did not repair persisted corruption')
assert(CraftScan.OrderFulfillment:GetStatuses()[retryKey].updatedAt==520)

-- With no journal at all, a success still beats a re-stamped rejection of
-- the same request, even though it has a lower local revision and timestamp.
CraftScan.DB.realm.order_statuses[retryKey]=inflatedRejection
local lowRevisionSuccess={customerName=retryOrder.customerName, responseID=retryOrder.responseID,
    requestToken='retry-request', requestTime=500, craftingOrderID=8002,
    status='fulfilled', updatedAt=520, rev=1, origin='craft-account'}
changed, accepted=CraftScan.OrderFulfillment:ApplyRemoteStatus(lowRevisionSuccess)
assert(changed and accepted and CraftScan.OrderFulfillment:GetStatuses()[retryKey].status=='fulfilled')

-- A late-delivered first notice must keep the event's time, not arrival time.
local lateOrder={customerName='LateBuyer-Realm', responseID=9012}
local lateKey=CraftScan.OrderToOrderID(lateOrder)
CraftScan.DB.listed_orders[lateKey]=lateOrder
CraftScan.DB.customers[lateOrder.customerName]={responses={
    [lateOrder.responseID]={requestToken='late-request', time=500, recipeID=9012},
}}
local lateCompletion={customerName='LateBuyer', spellID=9012, orderID=9013,
    status='fulfilled', updatedAt=550, requestToken='late-request', origin='peer'}
CraftScan.OrderFulfillment:ApplyRemoteCompletion(lateCompletion)
assert(CraftScan.OrderFulfillment:GetStatuses()[lateKey].updatedAt==550,
    'first materialization used receipt time instead of event time')
local lateReject={customerName='LateBuyer', spellID=9012, orderID=9011,
    status='rejected', updatedAt=560, requestToken='late-request', origin='other-peer'}
CraftScan.OrderFulfillment:ApplyRemoteCompletion(lateReject)
assert(CraftScan.OrderFulfillment:GetStatus(lateOrder).status=='fulfilled',
    'journal selection preferred a later-dated rejection over success of the same request')

-- Do not make success sticky across distinct new requests for the same item.
local retryResponse=CraftScan.OrderToResponse(retryOrder)
retryResponse.requestToken='new-retry-request'; retryResponse.time=now+200
now=retryResponse.time+10
local newRejection={customerName='RetryBuyer', requestToken='new-retry-request',
    requestTime=retryResponse.time, spellID=8765, itemID=5678, orderID=8003,
    status='rejected', updatedAt=now, origin='reject-account'}
CraftScan.OrderFulfillment:ApplyRemoteCompletion(newRejection)
assert(CraftScan.OrderFulfillment:GetStatus(retryOrder).status=='rejected',
    'an old fulfillment hid a genuinely new rejected request')
CraftScan.OrderFulfillment:ApplyRemoteCompletionNotices({completedNotice, rejectedNotice})
assert(CraftScan.OrderFulfillment:GetStatus(retryOrder).status=='rejected')
changed, accepted=CraftScan.OrderFulfillment:ApplyRemoteStatus(lowRevisionSuccess)
assert(not changed and not accepted, 'an old exact success leaked onto the newer request')

-- Preserve manual clearing and real failures of an optimistic fulfillment.
now=now+10
CraftScan.OrderFulfillment:ToggleManual(lateOrder)
assert(CraftScan.OrderFulfillment:GetStatus(lateOrder)==nil)
CraftScan.OrderFulfillment:ApplyRemoteCompletionNotices({lateCompletion, lateReject})
assert(CraftScan.OrderFulfillment:GetStatus(lateOrder)==nil,
    'replaying history undid an explicit manual clear')
CraftScan.OrderFulfillment:ToggleManual(lateOrder)
assert(CraftScan.OrderFulfillment:GetStatus(lateOrder).status=='fulfilled')
now=now+10
CraftScan.OrderFulfillment:SetStatus(lateOrder, 'failed', {
    craftingOrderID=9013, force=true, automatic=true, result=17,
})
assert(CraftScan.OrderFulfillment:GetStatus(lateOrder).status=='failed')
CraftScan.OrderFulfillment:ApplyRemoteCompletion(lateCompletion)
assert(CraftScan.OrderFulfillment:GetStatus(lateOrder).status=='failed',
    'old optimistic completion erased an authoritative server error')

print("Order status merge tests passed.")
