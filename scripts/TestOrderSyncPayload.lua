-- Exercise the real communication module with transport and timers mocked.
-- Marks travel alone on the urgent prefix and are ACKed at once; material
-- lists follow on the bulk prefix, one batch in flight, with their own ACK.
local function copy(value)
    if type(value)~='table' then return value end
    local result={};for k,v in pairs(value) do result[k]=copy(v) end;return result
end
local function noop() end
local sent,frames,timers={},{},{}
local comm={RegisterComm=noop,SendCommMessage=function(_,prefix,data,channel,target,priority,callback)
    sent[#sent+1]={prefix=prefix,data=copy(data),target=target,priority=priority,callback=callback}
end}
local serialize={Serialize=function(_,data) return copy(data) end,
    SerializeAsync=function(_,data) return function() return true,copy(data) end end,
    DeserializeAsync=function(_,data) return function() return true,true,copy(data) end end}
local identity=function(_,value) return value end
local libs={['AceAddon-3.0']={NewAddon=function() return comm end},LibSerialize=serialize,
    LibDeflate={CompressDeflate=identity,EncodeForWoWAddonChannel=identity,
        DecodeForWoWAddonChannel=identity,DecompressDeflate=identity}}
function LibStub(name) return assert(libs[name],name) end
function CreateFramePool()
    return {Release=noop,Acquire=function()
        local frame={SetScript=function(self,_,callback) self.callback=callback end,Show=noop}
        frames[#frames+1]=frame;return frame
    end}
end
function time() return 2000000000 end
function GetTime() return 10 end
function ChatFrame_AddMessageEventFilter() end
function issecretvalue() return false end
C_Timer={After=function(delay,callback) timers[#timers+1]={delay=delay,callback=callback} end}
C_AddOns={GetAddOnMetadata=function(name,field) return name=='HironCraft' and field=='Version' and '0.4.45' or nil end}

local Scan={CONST={TEXT={},CURRENT_VERSION=1},LOCAL={GetText=function(_,key) return key end},
    DB={settings={},realm={},customers={},listed_orders={}},State={realmID=1},
    Events={Register=noop,Emit=noop},OnLinkedAccountStateChange=noop,OrderToLiveResponse=noop,
    Utils={DeepCopy=copy,printTable=noop,onLoad=noop,
        Contains=function(values,value) for _,v in pairs(values) do if v==value then return true end end end,
        saved=function(parent,key,value) if parent[key]==nil then parent[key]=value end;return parent[key] end},
    GetPlayerName=function() return 'Crafter-Realm' end,
    OrderToOrderID=function(order) return order.customerName..':'..order.responseID end,
    OrderToResponse=function() return nil end}
assert(loadfile('Utils/Comm.lua'))('HironCraft',Scan)
assert(loadfile('Customer/ReagentAudit.lua'))('HironCraft',Scan)
assert(loadfile('Customer/OrderFulfillment.lua'))('HironCraft',Scan)
local op=comm.Operations
local fulfillment=Scan.OrderFulfillment

-- Run every queued timer whose delay is at most maxDelay (one pass).
local function runTimers(maxDelay)
    local due,rest={},{}
    for _,timer in ipairs(timers) do
        if timer.delay<=maxDelay then due[#due+1]=timer else rest[#rest+1]=timer end
    end
    timers=rest
    for _,timer in ipairs(due) do timer.callback() end
end
local function flushFrames()
    local pending=frames;frames={}
    for _,frame in ipairs(pending) do if frame.callback then frame.callback() end end
end
local function actAs(me,peer)
    Scan.DB.settings.my_uuid=me
    Scan.DB.realm.linked_accounts={[peer]={permissions={1}}}
end
local function receive(packet,from)
    sent={}
    comm:OnCommReceived(packet.prefix,packet.data,'WHISPER',from);flushFrames()
end
local function find(operation)
    local found
    for _,packet in ipairs(sent) do
        if packet.data.operation==operation then assert(not found,'duplicate '..operation);found=packet end
    end
    return found
end
local function only(operation)
    assert(#sent==1,('expected one packet, got %d'):format(#sent))
    return assert(find(operation),'expected '..operation)
end
local function markSent(packet) packet.callback(nil,1,1) end
local function hasKey(value,key)
    if type(value)~='table' then return false end
    if value[key]~=nil then return true end
    for _,child in pairs(value) do if hasKey(child,key) then return true end end
    return false
end

local audit={version=1,orderID=42,capturedAt=time(),complete=true,
    rows={{itemID=11,name='Alloy',required=20,known=true,supplied={{itemID=11,quantity=20,quality=1}}}}}
local entry={customerName='Buyer-Realm',responseID=123,craftingOrderID=42,status='fulfilled',
    rev=7,origin='source',updatedAt=time(),automatic=true,reagentAudit=audit}
local key=Scan.OrderToOrderID(entry)

-- Marks never carry material lists, but keep their ACK request.
actAs('source','receiver')
for _,operation in ipairs({op.ShareOrderStatus,op.ShareOrderCompletion,op.ShareOrderOutcome,op.OrderStatusRepair}) do
    sent={};frames={}
    local pending=copy(entry);pending.deliveryPending={receiver=true};pending.materialsPending={receiver=true}
    comm:Transmit({statuses={pending}},operation,'Receiver-Realm')
    assert(#sent==1 and #frames==0 and sent[1].priority=='ALERT' and sent[1].prefix=='HIRONCRAFT_SCAN',
        'mark waited or left the urgent prefix')
    local wire=sent[1].data.data.statuses[1]
    assert(not hasKey(sent[1].data,'reagentAudit') and not wire.materialsPending,'material list travelled with the mark')
    assert(wire.deliveryPending.receiver,'mark lost its ACK request')
    assert(pending.reagentAudit and pending.materialsPending,'send mutated durable evidence')
end

-- Bulky traffic has its own prefix; public operations keep the shared one.
sent={};frames={}
comm:Transmit({characters={}},op.ShareCharacterData,'Receiver-Realm');flushFrames()
assert(sent[1].prefix=='HIRONCRAFT_BULK' and sent[1].priority=='BULK')
sent={};frames={}
comm:Transmit({i=1},op.FindCrafter,'Receiver-Realm');flushFrames()
assert(sent[1].prefix=='HIRONCRAFT_SCAN','public operation left the prefix other clients listen on')

-- Only final marks schedule a list, and never an echo of a remote notice.
local prepared=copy(entry);comm:PrepareOrderStatusDelivery(prepared)
assert(prepared.deliveryPending.receiver and prepared.materialsPending.receiver)
local claimed=copy(entry);claimed.status='claimed';comm:PrepareOrderStatusDelivery(claimed)
assert(claimed.deliveryPending.receiver and not claimed.materialsPending,'progress mark scheduled a material list')
local echoed=copy(entry);echoed.result='completion_notice';comm:PrepareOrderStatusDelivery(echoed)
assert(echoed.deliveryPending.receiver and not echoed.materialsPending,'materialized row echoed the list back')

-- The receiver's current character answers a ping, so it is a fresh target.
receive({prefix='HIRONCRAFT_SCAN',data={operation=op.Ping,version=1,senderID='receiver',data={state=2}}},'Receiver-Realm')
local senderStatuses=fulfillment:GetStatuses()
local live=copy(entry);comm:PrepareOrderStatusDelivery(live);senderStatuses[key]=live
sent={};timers={}
comm:ShareOrderStatus(live)
assert(#sent==0,'mark bypassed the coalescing flush')
runTimers(0.3)
local markPacket=only(op.ShareOrderCompletion)
assert(markPacket.prefix=='HIRONCRAFT_SCAN' and markPacket.priority=='ALERT')
assert(markPacket.data.data.statuses[1].deliveryPending.receiver and not hasKey(markPacket.data,'reagentAudit'))
sent={};comm:ShareOrderStatus(live);runTimers(0.3)
assert(#sent==0,'a mark still waiting in the local queue was queued again')

markSent(markPacket)
sent={};runTimers(1.5)
live.reagentAudit.rows[1].supplied[1].quantity=999
flushFrames()
local materialPacket=only(op.ShareOrderMaterials)
assert(materialPacket.prefix=='HIRONCRAFT_BULK' and materialPacket.priority=='NORMAL')
local wireList=materialPacket.data.data
assert(wireList.batch and wireList.statuses[1].reagentAudit.rows[1].supplied[1].quantity==20,
    'queued list followed a later mutation')
assert(not wireList.statuses[1].deliveryPending and not wireList.statuses[1].materialsPending)
live.reagentAudit.rows[1].supplied[1].quantity=20
sent={};comm:ShareOrderStatus(live);runTimers(1.5);flushFrames()
assert(#sent==0,'a second material batch or mark was queued while the first was in flight')

-- Receiver: the mark lands first and is ACKed on the urgent prefix.
actAs('receiver','source');Scan.DB.realm.order_statuses={}
receive(markPacket,'Sender-Realm')
local stored=fulfillment:GetStatuses()[key]
assert(stored and stored.status=='fulfilled' and not stored.reagentAudit)
local statusAck=only(op.OrderStatusAck)
assert(statusAck.prefix=='HIRONCRAFT_SCAN' and statusAck.priority=='ALERT','mark ACK waited for the material list')
receive(materialPacket,'Sender-Realm')
stored=fulfillment:GetStatuses()[key]
assert(stored.status=='fulfilled' and stored.reagentAudit.rows[1].supplied[1].quantity==20)
local materialAck=only(op.OrderMaterialsAck)
assert(materialAck.prefix=='HIRONCRAFT_SCAN' and materialAck.data.data.batch==wireList.batch)
receive(markPacket,'Sender-Realm')
assert(fulfillment:GetStatuses()[key].reagentAudit,'reordered mark erased material details')
local newer=copy(entry);newer.craftingOrderID=43;newer.rev=8;newer.updatedAt=time()+1
newer.status='claimed';newer.reagentAudit=nil
assert(fulfillment:ApplyRemoteStatus(newer))
receive(materialPacket,'Sender-Realm')
stored=fulfillment:GetStatuses()[key]
assert(stored.status=='claimed' and stored.craftingOrderID==43 and not stored.reagentAudit,
    'late list completed or contaminated a newer order')
only(op.OrderMaterialsAck)

-- Sender: each ACK clears only its own delivery flag.
actAs('source','receiver');Scan.DB.realm.order_statuses=senderStatuses
receive(statusAck,'Receiver-Realm')
assert(not live.deliveryPending and live.deliveryConfirmedAt,'mark ACK did not confirm delivery')
assert(live.materialsPending and live.materialsPending.receiver,'mark ACK cleared the undelivered list')
receive(materialAck,'Receiver-Realm')
assert(not live.materialsPending,'material ACK did not clear the list')
sent={}
for _=1,3 do runTimers(60);flushFrames() end
assert(#sent==0,'delivered data was sent again')

-- A lost list is retried once its ACK timeout expires, not before.
local second=copy(entry);second.responseID=124;second.craftingOrderID=50;second.reagentAudit.orderID=50
comm:PrepareOrderStatusDelivery(second);senderStatuses[Scan.OrderToOrderID(second)]=second
sent={};timers={}
comm:ShareOrderStatus(second);runTimers(0.3)
markSent(only(op.ShareOrderCompletion))
sent={};runTimers(1.5);flushFrames()
local lost=only(op.ShareOrderMaterials);markSent(lost)
sent={};runTimers(9);flushFrames()
assert(not find(op.ShareOrderMaterials),'material list retried before its ACK timeout')
sent={};runTimers(10);flushFrames()
local retry=find(op.ShareOrderMaterials)
assert(retry and retry.data.data.batch~=lost.data.data.batch
    and retry.data.data.statuses[1].craftingOrderID==50,'lost material list was not retried')
print('Order sync payload tests passed (lean marks, bulk prefix, coalescing, single material batch, separate ACKs, reordering, isolation, retry).')

-- Every message says which HironCraft sent it, and the receiver keeps it per
-- account; analytics travels on a prefix of its own.
sent={}
actAs('source','receiver')
comm:Transmit({seq=1},op.AnalyticsOffer,'Receiver-Realm');flushFrames()
local offer=only(op.AnalyticsOffer)
assert(offer.prefix=='HIRONCRAFT_ANLT' and offer.data.addon=='0.4.45','an analytics offer went out wrong')
actAs('receiver','source')
local fromNew=copy(offer);fromNew.data.operation=op.Ping;fromNew.data.data={state=2}
receive(fromNew,'Source-Realm')
assert(Scan.DB.realm.linked_accounts.source.addon_version=='0.4.45','the sender version was not kept')
local fromOld=copy(fromNew);fromOld.data.addon=nil
receive(fromOld,'Source-Realm')
assert(Scan.DB.realm.linked_accounts.source.addon_version=='old','a sender without a version was not marked old')
print('Linked account versions passed.')

