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
local beforeManualClear=CraftScan.OrderFulfillment:GetStatuses()[lateKey]
local manualClear=CraftScan.OrderFulfillment:ToggleManual(lateOrder)
assert(CraftScan.OrderFulfillment:GetStatus(lateOrder)==nil)
changed, accepted, current=CraftScan.OrderFulfillment:ApplyRemoteStatus(beforeManualClear)
assert(not changed and not accepted and current.automatic==false and current.status=='unknown',
    'older automatic status echoed by a linked account restored the manually cleared checkmark')
assert(CraftScan.OrderFulfillment:GetStatus(lateOrder)==nil)
CraftScan.OrderFulfillment:ApplyRemoteCompletionNotices({lateCompletion, lateReject})
assert(CraftScan.OrderFulfillment:GetStatus(lateOrder)==nil,
    'replaying history undid an explicit manual clear')

local function copyEntry(entry)
    local result={}; for key,value in pairs(entry) do result[key]=value end; return result
end
-- The other account must accept the clear, not reject it as lost automatic
-- progress and send its old green check back as a "repair" packet.
CraftScan.DB.realm.order_statuses[lateKey]=beforeManualClear
changed, accepted=CraftScan.OrderFulfillment:ApplyRemoteStatus(manualClear)
assert(changed and accepted and CraftScan.OrderFulfillment:GetStatus(lateOrder)==nil,
    'peer rejected a newer manual clear instead of accepting it')
changed, accepted=CraftScan.OrderFulfillment:ApplyRemoteStatus(manualClear)
assert(not changed and accepted, 'idempotent manual replay was not acknowledged')
for _, status in ipairs({'claimed','crafted','fulfilled','rejected','failed'}) do
    local stale=copyEntry(beforeManualClear)
    stale.status=status; stale.origin='peer-account'; stale.rev=999
    stale.updatedAt=manualClear.updatedAt-1
    changed, accepted, current=CraftScan.OrderFulfillment:ApplyRemoteStatus(stale)
    assert(not changed and not accepted and current.status=='unknown' and current.automatic==false,
        'old automatic '..status..' overrode the manual clear')
end

-- Different clocks/revision counters can produce a same-second tie. Prefer
-- the manual action across accounts, independently of message arrival order.
local tiedAutomatic=copyEntry(beforeManualClear)
tiedAutomatic.updatedAt=manualClear.updatedAt; tiedAutomatic.rev=999
tiedAutomatic.origin='other-account'
changed, accepted=CraftScan.OrderFulfillment:ApplyRemoteStatus(tiedAutomatic)
assert(not changed and not accepted, 'large peer revision won a same-second tie over a manual clear')
CraftScan.DB.realm.order_statuses[lateKey]=tiedAutomatic
changed, accepted=CraftScan.OrderFulfillment:ApplyRemoteStatus(manualClear)
assert(changed and accepted, 'same-second merge depends on delivery order')

-- Within one origin the revision establishes causal order even within a
-- second: a genuine later event may still replace the manual mark.
local laterAutomatic=copyEntry(beforeManualClear)
laterAutomatic.updatedAt=manualClear.updatedAt; laterAutomatic.origin=manualClear.origin
laterAutomatic.rev=manualClear.rev+1
changed, accepted=CraftScan.OrderFulfillment:ApplyRemoteStatus(laterAutomatic)
assert(changed and accepted, 'later same-origin automatic result was suppressed forever')
changed, accepted=CraftScan.OrderFulfillment:ApplyRemoteStatus(manualClear)
assert(not changed and not accepted, 'old manual clear undid a later same-origin result')
CraftScan.DB.realm.order_statuses[lateKey]=manualClear
local manualMark=CraftScan.OrderFulfillment:ToggleManual(lateOrder)
assert(manualMark.automatic==false and manualMark.status=='fulfilled')
changed, accepted=CraftScan.OrderFulfillment:ApplyRemoteStatus(manualClear)
assert(not changed and not accepted, 'older clear undid the next manual check in the same second')
local wrongMode=copyEntry(manualMark); wrongMode.automatic=true
changed, accepted=CraftScan.OrderFulfillment:ApplyRemoteStatus(wrongMode)
assert(not changed and not accepted, 'different automatic/manual modes were ACKed as equivalent')

-- Manual overrides belong to one request, not every future craft of this item.
local lateResponse=CraftScan.OrderToResponse(lateOrder)
local originalToken, originalTime=lateResponse.requestToken, lateResponse.time
lateResponse.requestToken='next-late-request'; lateResponse.time=now+100
local newJob=copyEntry(beforeManualClear)
newJob.requestToken=lateResponse.requestToken; newJob.requestTime=lateResponse.time
newJob.status='claimed'; newJob.updatedAt=now+101; newJob.rev=1; newJob.craftingOrderID=9014
changed, accepted=CraftScan.OrderFulfillment:ApplyRemoteStatus(newJob)
assert(changed and accepted and CraftScan.OrderFulfillment:GetStatus(lateOrder).status=='claimed')
local delayedClear=copyEntry(manualClear); delayedClear.updatedAt=now+999
changed, accepted=CraftScan.OrderFulfillment:ApplyRemoteStatus(delayedClear)
assert(not changed and not accepted, 'old request\'s manual clear affected a newer job')
lateResponse.requestToken, lateResponse.time=originalToken, originalTime
CraftScan.DB.realm.order_statuses[lateKey]=manualClear
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

-- A delayed packet after a rename must use the new crafter name without
-- changing a legacy completion's journal key or its request identity.
assert(loadfile('Utils/CharacterRenames.lua'))('HironCraft',CraftScan)
HironCraftScan_DB={settings={character_renames={
    ['Oldsmith-Realm']={to='Newsmith-Realm',sourceID='rename-owner'},
}},realms={}}
CraftScan.CharacterRenames.Apply(HironCraftScan_DB)
local renamedNotice={orderID=99001,customerName='RenameBuyer',spellID=98765,itemID=87654,
    crafterFullName='Oldsmith-Realm',updatedAt=now,status='fulfilled'}
local legacyKey=CraftScan.OrderFulfillment:CompletionNoticeKey(renamedNotice)
assert(CraftScan.OrderFulfillment:ApplyRemoteCompletion(renamedNotice))
local canonicalNotice=CraftScan.OrderFulfillment:GetCompletionNotices()[legacyKey]
assert(canonicalNotice and canonicalNotice.crafterFullName=='Newsmith-Realm'
    and canonicalNotice.origin=='Oldsmith-Realm', 'rename changed a legacy journal identity')
assert(not CraftScan.OrderFulfillment:ApplyRemoteCompletion(renamedNotice), 'replay created another completion')
local renamedStatus={customerName='RenameBuyer',responseID=98765,status='fulfilled',
    crafterFullName='Oldsmith-Realm',origin='rename-owner',rev=1,updatedAt=now,
    requestToken='rename-request',requestTime=now-5}
assert(CraftScan.OrderFulfillment:ApplyRemoteStatus(renamedStatus))
local canonicalStatus=CraftScan.OrderFulfillment:GetStatuses()['RenameBuyer-98765']
assert(canonicalStatus.crafterFullName=='Newsmith-Realm' and canonicalStatus.requestToken=='rename-request')

assert(loadfile('Customer/BattleNet.lua'))('HironCraft',CraftScan)
local bnOrders={}
for _,tag in ipairs({'friend#1234','friend#5678'}) do
    local name='BNET:test-account:'..tag
    local bnOrder={customerName=name,responseID=9998}
    CraftScan.DB.customers[name]={responses={[9998]={requestToken=tag,time=now,recipeID=9998}}}
    CraftScan.DB.listed_orders[CraftScan.OrderToOrderID(bnOrder)]=bnOrder
    bnOrders[#bnOrders+1]=bnOrder
end
local bnMarked=CraftScan.OrderFulfillment:ToggleManual(bnOrders[1])
assert(bnMarked.status=='fulfilled' and not CraftScan.OrderFulfillment:GetStatus(bnOrders[2]),
    'manual BNet mark leaked to another friend sharing the same account prefix')
assert(not CraftScan.OrderFulfillment:ApplyRemoteStatus(bnMarked), 'remote status overwrote a private BNet row')
assert(not CraftScan.OrderFulfillment:ApplyRemoteCompletion({customerName=bnOrders[1].customerName}),
    'remote journal injected a BNet identity')
print("Order status merge tests passed.")
