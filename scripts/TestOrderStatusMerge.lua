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

assert(loadfile('Customer/ClassMatching.lua'))('HironCraft',CraftScan)
C_Item={GetItemInfoInstant=function(id)
    return id,nil,nil,id==1 and 'INVTYPE_WRIST' or 'INVTYPE_WAIST',nil,4,4
end}
local slots={wrist={key='INVTYPE_WRIST',slot='INVTYPE_WRIST',armor=4},
    belt={key='INVTYPE_WAIST',slot='INVTYPE_WAIST',armor=4}}
local buyer='SlotBuyer-Realm'
CraftScan.DB.customers[buyer]={responses={}}
for key,request in pairs(slots) do
    local slotOrder={customerName=buyer,responseID=key}
    CraftScan.DB.listed_orders[CraftScan.OrderToOrderID(slotOrder)]=slotOrder
    CraftScan.DB.customers[buyer].responses[key]={equipmentRequest=request,
        crafterFullName='Crafter-Realm',parentProfID=164,requestToken=key,time=now}
end
local claim={customerName=buyer,itemID=1,parentProfessionID=164}
assert(CraftScan.OrderFulfillment:FindMatchingOrder(claim).responseID=='wrist',
    'slot order fulfillment matched the wrong generic row')
local generic=CraftScan.OrderFulfillment:FindGenericOrders(claim)
assert(#generic==1 and generic[1].responseID=='wrist','wrist completion also selected Belt')
claim.itemID=nil
assert(not CraftScan.OrderFulfillment:FindMatchingOrder(claim)
    and #CraftScan.OrderFulfillment:FindGenericOrders(claim)==0,'unknown item marked a typed order complete')
print('Equipment placeholder fulfillment matching tests passed.')

assert(loadfile('Customer/ReagentAudit.lua'))('HironCraft',CraftScan)
local auditOrder={customerName='AuditBuyer-Realm',responseID=77123}
local auditKey=CraftScan.OrderToOrderID(auditOrder)
CraftScan.DB.customers[auditOrder.customerName]={responses={[77123]={recipeID=77123,itemID=8123,
    crafterFullName='Crafter-Realm',requestToken='audit-request',time=now}}}
CraftScan.DB.listed_orders[auditKey]=auditOrder
local audit={version=1,orderID=88001,recipeID=77123,capturedAt=now,complete=true,rows={
    {itemID=12,name='Alloy',required=40,known=true,supplied={{itemID=12,quantity=20,quality=1,maxQuality=3}}},
}}
local auditEntry=CraftScan.OrderFulfillment:SetStatus(auditOrder,'rejected',{craftingOrderID=88001})
local notice={customerName=auditOrder.customerName,orderID=88001,spellID=77123,itemID=8123,
    crafterFullName='Crafter-Realm',updatedAt=now,status='rejected',requestToken='audit-request',requestTime=now}
assert(CraftScan.OrderFulfillment:ApplyRemoteCompletion(notice))
assert(not CraftScan.ReagentAudit.GetForOrder(auditOrder))
notice.reagentAudit=audit
assert(CraftScan.OrderFulfillment:ApplyRemoteCompletion(notice),'same-time journal metadata was discarded')
local savedAudit=CraftScan.ReagentAudit.GetForOrder(auditOrder)
assert(savedAudit and savedAudit.orderID==88001,'linked rejection failed to enrich an existing status')
audit.rows[1].supplied[1].quantity=1000
assert(savedAudit.rows[1].supplied[1].quantity==20,'linked payload remained mutable')
assert(not CraftScan.OrderFulfillment:ApplyRemoteCompletion(notice),'audit replay counted as fresh decline')
local savedSettings,savedRealm=CraftScan.DB.settings,CraftScan.DB.realm
assert(loadfile('Customer/OrderFulfillment.lua'))('HironCraft',CraftScan)
assert(CraftScan.DB.settings==savedSettings and CraftScan.DB.realm==savedRealm)
assert(CraftScan.ReagentAudit.GetForOrder(auditOrder).rows[1].supplied[1].quantity==20,'reload lost snapshot')
now=now+1
CraftScan.OrderFulfillment:SetStatus(auditOrder,'claimed',{craftingOrderID=88002})
assert(not CraftScan.ReagentAudit.GetForOrder(auditOrder),'old audit attached to replacement order')
CraftScan.OrderFulfillment:ApplyRemoteCompletion(notice)
assert(not CraftScan.ReagentAudit.GetForOrder(auditOrder),'delayed old notice revived an audit')
local newAudit=CraftScan.ReagentAudit.Sanitize(audit);newAudit.orderID=88002;newAudit.capturedAt=now
assert(CraftScan.OrderFulfillment:RecordRejection({customerName=auditOrder.customerName,
    spellID=77123,itemID=8123,orderID=88002},88002,'missing_customer_reagents',newAudit))
assert(CraftScan.ReagentAudit.GetForOrder(auditOrder).orderID==88002)
local remote=copyEntry(CraftScan.OrderFulfillment:GetStatus(auditOrder))
CraftScan.DB.realm.order_statuses[auditKey].reagentAudit=nil
assert(CraftScan.OrderFulfillment:ApplyRemoteStatus(remote),'exact replay did not enrich status metadata')
remote=copyEntry(CraftScan.OrderFulfillment:GetStatus(auditOrder));remote.rev=remote.rev+1;remote.reagentAudit=nil
assert(CraftScan.OrderFulfillment:ApplyRemoteStatus(remote))
assert(CraftScan.ReagentAudit.GetForOrder(auditOrder),'peer without audit erased a recorded snapshot')
local wrong=copyEntry(remote);wrong.rev=wrong.rev+1;wrong.craftingOrderID=88003;wrong.reagentAudit=newAudit
CraftScan.OrderFulfillment:ApplyRemoteStatus(wrong)
assert(not CraftScan.OrderFulfillment:GetStatuses()[auditKey].reagentAudit,'mismatched game ID accepted')
print('Reagent audit persistence tests passed (journal enrichment, reload, resend, legacy peer, payload isolation).')

-- The crafter's computer clock runs behind: its decline is stamped earlier
-- than the request it answers on this computer. Compared on the game
-- server's clock it is newer, and the row gets its cross.
local serverNow = 5000
GetServerTime = function() return serverNow end
now = 5000 -- this computer's clock matches the server
CraftScan.DB.customers.Skewed = {
    responses = {
        [4242] = { responseID = 4242, requestToken = "local-token", time = 4990,
            crafterFullName = "RemoteCrafter-Realm", recipeID = 4242, itemID = 2424 },
    },
}
local skewedOrder = { customerName = "Skewed", responseID = 4242 }
CraftScan.DB.listed_orders[CraftScan.OrderToOrderID(skewedOrder)] = skewedOrder
local lateClock = {
    orderID = 9901, customerName = "Skewed", spellID = 4242, itemID = 2424,
    crafterFullName = "RemoteCrafter-Realm", origin = "remote-account",
    updatedAt = 4930, status = "rejected", requestToken = "order:9901",
}
-- Without knowing the other clock, the decline looks older than the request.
assert(CraftScan.OrderFulfillment:ApplyRemoteCompletion(lateClock))
local seen = CraftScan.OrderFulfillment:GetStatus(skewedOrder)
assert(not (seen and seen.status == "rejected"), "the test does not reproduce the clock problem")
-- The same notice again, now with its clock 90 seconds behind the server.
local withClock = {}
for key, value in pairs(lateClock) do withClock[key] = value end
withClock.clockOffset = 90
CraftScan.OrderFulfillment:ApplyRemoteCompletion(withClock)
seen = CraftScan.OrderFulfillment:GetStatus(skewedOrder)
assert(seen and seen.status == "rejected", "a decline from a computer with a slow clock was dropped")
-- A decline that really is older than the request still stays off the row.
CraftScan.DB.customers.Older = {
    responses = {
        [4343] = { responseID = 4343, requestToken = "local-token-2", time = 4990,
            crafterFullName = "RemoteCrafter-Realm", recipeID = 4343, itemID = 3434 },
    },
}
local olderOrder = { customerName = "Older", responseID = 4343 }
CraftScan.DB.listed_orders[CraftScan.OrderToOrderID(olderOrder)] = olderOrder
CraftScan.OrderFulfillment:ApplyRemoteCompletion({
    orderID = 9902, customerName = "Older", spellID = 4343, itemID = 3434,
    crafterFullName = "RemoteCrafter-Realm", origin = "remote-account",
    updatedAt = 4930, clockOffset = 0, status = "rejected", requestToken = "order:9902",
})
seen = CraftScan.OrderFulfillment:GetStatus(olderOrder)
assert(not (seen and seen.status == "rejected"), "an old decline leaked onto a newer request")
-- Records made here carry this computer's clock.
local stamped = CraftScan.OrderFulfillment:SetStatus(olderOrder, "claimed", { craftingOrderID = 9903 })
assert(stamped and stamped.clockOffset == 0, "a new status does not say how its clock stood")
GetServerTime = nil
print('Clock tests passed (slow crafter clock, genuinely old decline, stamped records).')

-- A result that fits none of the customer's rows says why, once, and keeps it.
local printed = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) printed[#printed + 1] = text end }
now = 6000
CraftScan.DB.customers["Mismatch-Realm"] = {
    responses = {
        [5151] = { responseID = 5151, requestToken = "mm-token", time = 5990,
            crafterFullName = "RemoteCrafter-Realm", recipeID = 5151, itemID = 1515 },
    },
}
local mismatchOrder = { customerName = "Mismatch-Realm", responseID = 5151 }
CraftScan.DB.listed_orders[CraftScan.OrderToOrderID(mismatchOrder)] = mismatchOrder
local foreign = {
    orderID = 9950, customerName = "Mismatch", spellID = 7777, itemID = 8888,
    crafterFullName = "OtherCrafter-Realm", origin = "remote-account",
    updatedAt = 5995, status = "rejected",
}
CraftScan.OrderFulfillment:ApplyRemoteCompletion(foreign)
assert(#printed == 1 and printed[1]:find("5151", 1, true) and printed[1]:find("7777", 1, true),
    "an unmatched result did not say why")
local mismatchLog = CraftScan.DB.settings.notice_mismatch_log
assert(mismatchLog and mismatchLog[1].customerName == "Mismatch" and #mismatchLog[1].reasons == 1,
    "the reason was not kept")
local again = {}
for key, value in pairs(foreign) do again[key] = value end
again.updatedAt = 5996
CraftScan.OrderFulfillment:ApplyRemoteCompletion(again)
assert(#printed == 1, "the same order was explained twice")
-- A result for a customer this account never talked to is normal and silent.
CraftScan.OrderFulfillment:ApplyRemoteCompletion({
    orderID = 9951, customerName = "Stranger", spellID = 1, itemID = 2,
    crafterFullName = "RemoteCrafter-Realm", origin = "remote-account",
    updatedAt = 5995, status = "rejected",
})
assert(#printed == 1, "a customer without a row was reported")
DEFAULT_CHAT_FRAME = nil
print('Unmatched result diagnosis passed.')

-- The customer asked for one recipe and ordered its neighbour from the same
-- crafter (without materials). Their one row with that crafter is still the
-- conversation the order came from.
now = 7000
CraftScan.DB.customers["Neighbour-Realm"] = {
    responses = {
        [1228944] = { responseID = 1228944, requestToken = "nb-token", time = 6900,
            crafterFullName = "Vamo-Realm", recipeID = 1228944, itemID = 239653, parentProfID = 197 },
    },
}
local neighbourRow = { customerName = "Neighbour-Realm", responseID = 1228944 }
CraftScan.DB.listed_orders[CraftScan.OrderToOrderID(neighbourRow)] = neighbourRow
CraftScan.OrderFulfillment:ApplyRemoteCompletion({
    orderID = 9960, customerName = "Neighbour", spellID = 1228946, itemID = 239655,
    parentProfessionID = 197, crafterFullName = "Vamo-Realm", origin = "remote-account",
    updatedAt = 6950, clockOffset = 0, status = "rejected", requestToken = "order:9960",
})
local neighbourStatus = CraftScan.OrderFulfillment:GetStatus(neighbourRow)
assert(neighbourStatus and neighbourStatus.status == "rejected",
    "a decline of a neighbouring recipe left the customer's only row without its cross")
-- With two rows at that crafter, which one it was is not guessed.
CraftScan.DB.customers["Two-Realm"] = {
    responses = {
        [1228944] = { responseID = 1228944, requestToken = "two-a", time = 6900,
            crafterFullName = "Vamo-Realm", recipeID = 1228944, itemID = 239653, parentProfID = 197 },
        [1228947] = { responseID = 1228947, requestToken = "two-b", time = 6900,
            crafterFullName = "Vamo-Realm", recipeID = 1228947, itemID = 239657, parentProfID = 197 },
    },
}
local twoA = { customerName = "Two-Realm", responseID = 1228944 }
local twoB = { customerName = "Two-Realm", responseID = 1228947 }
CraftScan.DB.listed_orders[CraftScan.OrderToOrderID(twoA)] = twoA
CraftScan.DB.listed_orders[CraftScan.OrderToOrderID(twoB)] = twoB
CraftScan.OrderFulfillment:ApplyRemoteCompletion({
    orderID = 9961, customerName = "Two", spellID = 1228946, itemID = 239655,
    parentProfessionID = 197, crafterFullName = "Vamo-Realm", origin = "remote-account",
    updatedAt = 6950, clockOffset = 0, status = "rejected", requestToken = "order:9961",
})
for _, row in ipairs({ twoA, twoB }) do
    local seenTwo = CraftScan.OrderFulfillment:GetStatus(row)
    assert(not (seenTwo and seenTwo.status == "rejected"), "a decline was guessed onto one of two rows")
end
-- Another crafter's order is not this row's.
CraftScan.DB.customers["Elsewhere-Realm"] = {
    responses = {
        [1228944] = { responseID = 1228944, requestToken = "else-token", time = 6900,
            crafterFullName = "Vamo-Realm", recipeID = 1228944, itemID = 239653, parentProfID = 197 },
    },
}
local elsewhereRow = { customerName = "Elsewhere-Realm", responseID = 1228944 }
CraftScan.DB.listed_orders[CraftScan.OrderToOrderID(elsewhereRow)] = elsewhereRow
CraftScan.OrderFulfillment:ApplyRemoteCompletion({
    orderID = 9962, customerName = "Elsewhere", spellID = 1228946, itemID = 239655,
    parentProfessionID = 197, crafterFullName = "Favu-Realm", origin = "remote-account",
    updatedAt = 6950, clockOffset = 0, status = "rejected", requestToken = "order:9962",
})
local elsewhereStatus = CraftScan.OrderFulfillment:GetStatus(elsewhereRow)
assert(not (elsewhereStatus and elsewhereStatus.status == "rejected"),
    "another crafter's decline landed on this row")
print('Neighbouring recipe tests passed (only row with the crafter, two rows, another crafter).')
