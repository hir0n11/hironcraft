-- Exercise the real communication module with serialization/transport mocked.
-- Large material details must never hold the final checkmark in the ALERT queue.
local function copy(value)
    if type(value)~='table' then return value end
    local result={};for k,v in pairs(value) do result[k]=copy(v) end;return result
end
local function noop() end
local sent,frames={},{}
local comm={SendCommMessage=function(_,prefix,data,channel,target,priority)
    sent[#sent+1]={prefix=prefix,data=copy(data),target=target,priority=priority}
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
local Scan={CONST={TEXT={},CURRENT_VERSION=1},LOCAL={GetText=function(_,key) return key end},
    DB={settings={my_uuid='source'},realm={linked_accounts={source={permissions={1}}}}},
    Events={Register=noop},Utils={DeepCopy=copy,printTable=noop,onLoad=noop,
        Contains=function(values,value) for _,v in pairs(values) do if v==value then return true end end end}}
assert(loadfile('Utils/Comm.lua'))('HironCraft',Scan)
local op=comm.Operations
local function flush()
    local pending=frames;frames={}
    for _,frame in ipairs(pending) do if frame.callback then frame.callback() end end
end
local entry={customerName='Buyer-Realm',responseID=123,craftingOrderID=42,status='fulfilled',
    rev=7,origin='source',updatedAt=time(),deliveryPending={receiver=true},
    reagentAudit={version=1,orderID=42,rows={{name='Alloy',supplied={{quantity=20,quality=1}}}}}}
local function noMaterials(value)
    if type(value)~='table' then return end
    assert(not value.reagentAudit and not value.deliveryPending)
    for _,child in pairs(value) do noMaterials(child) end
end
for _,operation in ipairs({op.ShareOrderStatus,op.ShareOrderCompletion,op.ShareOrderOutcome,op.OrderStatusRepair}) do
    sent={};frames={}
    local payload=operation==op.OrderStatusRepair and {statuses={entry}} or entry
    comm:Transmit(payload,operation,'Receiver-Realm')
    assert(#sent==1 and sent[1].priority=='ALERT','status waited for async material serialization')
    local full
    if operation==op.OrderStatusRepair then
        noMaterials(sent[1].data.data)
        assert(sent[1].data.data.statuses[1].status=='fulfilled')
        flush()
        assert(#sent==2 and sent[2].priority=='NORMAL')
        full=sent[2].data.data.statuses[1]
    else
        assert(#frames==0,'small live materials waited for the background queue')
        full=sent[1].data.data
        assert(full.status=='fulfilled' and full.rev==7 and full.craftingOrderID==42)
    end
    assert(full.reagentAudit.rows[1].supplied[1].quantity==20 and full.deliveryPending.receiver)
    assert(entry.reagentAudit and entry.deliveryPending.receiver,'send mutated durable evidence')
end

for _,status in ipairs({'claimed','crafted'}) do
    local progress=copy(entry);progress.status=status
    sent={};frames={}
    comm:Transmit(progress,op.ShareOrderStatus,'Receiver-Realm')
    assert(#sent==1 and #frames==0 and sent[1].priority=='ALERT')
    assert(not sent[1].data.data.reagentAudit and sent[1].data.data.deliveryPending.receiver,
        'intermediate progress resent the material list or lost its ACK')
    assert(progress.reagentAudit,'intermediate transmission erased the durable snapshot')
end

-- Login batches and repeated orders keep ALL material lists out of ALERT.
sent={};frames={}
comm:Transmit({recent={entry,entry},statuses={entry}},op.ShareOrderCompletion,'Receiver-Realm')
noMaterials(sent[1].data.data)
entry.reagentAudit.rows[1].supplied[1].quantity=999
flush()
assert(sent[2].data.data.recent[1].reagentAudit.rows[1].supplied[1].quantity==20,
    'later craft mutation changed a queued snapshot')
entry.reagentAudit.rows[1].supplied[1].quantity=20

-- Ordinary status and ACK packets remain immediate single messages.
sent={};frames={}
comm:Transmit({status='fulfilled'},op.ShareOrderStatus,'Receiver-Realm')
comm:Transmit({statuses={}},op.OrderStatusAck,'Receiver-Realm')
assert(#sent==2 and #frames==0 and sent[1].priority=='ALERT' and sent[2].priority=='ALERT')

-- Receive both stages through real Comm handlers and the real status merger.
function issecretvalue() return false end
Scan.State={realmID=1};Scan.OnLinkedAccountStateChange=noop;Scan.Events.Emit=noop
Scan.Utils.saved=function(parent,key,value) if parent[key]==nil then parent[key]=value end;return parent[key] end
Scan.GetPlayerName=function() return 'Receiver-Realm' end
Scan.OrderToOrderID=function(order) return order.customerName..':'..order.responseID end
Scan.OrderToResponse=function() return nil end
Scan.OrderToLiveResponse=noop
Scan.DB.customers={};Scan.DB.listed_orders={}
assert(loadfile('Customer/ReagentAudit.lua'))('HironCraft',Scan)
assert(loadfile('Customer/OrderFulfillment.lua'))('HironCraft',Scan)
entry.reagentAudit.capturedAt=time();entry.reagentAudit.complete=true
entry.reagentAudit.rows[1].supplied[1].itemID=11
-- Only oversized snapshots retain the two-stage transport.
for i=2,13 do entry.reagentAudit.rows[i]=copy(entry.reagentAudit.rows[1]) end
sent={};frames={}
comm:Transmit(entry,op.ShareOrderStatus,'Receiver-Realm');flush()
local compactPacket,fullPacket=sent[1],sent[2]
Scan.DB.settings.my_uuid='receiver'
local function receive(packet)
    sent={};frames={}
    comm:OnCommReceived(packet.prefix,packet.data,'WHISPER','Sender-Realm');flush()
end
receive(compactPacket)
local stored=Scan.OrderFulfillment:GetStatuses()[Scan.OrderToOrderID(entry)]
assert(stored and stored.status=='fulfilled' and not stored.reagentAudit)
assert(#sent==0,'compact status acknowledged evidence before its delivery')
receive(fullPacket)
stored=Scan.OrderFulfillment:GetStatuses()[Scan.OrderToOrderID(entry)]
assert(stored.status=='fulfilled' and stored.reagentAudit.rows[1].supplied[1].quantity==20)
assert(#sent==1 and sent[1].data.operation==op.OrderStatusAck,'full evidence was not acknowledged')
receive(compactPacket)
assert(Scan.OrderFulfillment:GetStatuses()[Scan.OrderToOrderID(entry)].reagentAudit,
    'reordered compact packet erased material details')
local newer=copy(entry);newer.craftingOrderID=43;newer.rev=8;newer.updatedAt=time()+1
newer.status='claimed';newer.reagentAudit=nil
assert(Scan.OrderFulfillment:ApplyRemoteStatus(newer))
receive(fullPacket)
stored=Scan.OrderFulfillment:GetStatuses()[Scan.OrderToOrderID(entry)]
assert(stored.status=='claimed' and stored.craftingOrderID==43 and not stored.reagentAudit,
    'late evidence completed or contaminated a newer order')
local live=copy(entry);live.craftingOrderID=44;live.rev=9;live.updatedAt=time()+2
live.reagentAudit.orderID=44;live.reagentAudit.rows={live.reagentAudit.rows[1]}
Scan.DB.settings.my_uuid='source';sent={};frames={}
comm:Transmit(live,op.ShareOrderStatus,'Receiver-Realm')
assert(#sent==1 and #frames==0 and sent[1].priority=='ALERT')
local livePacket=sent[1];Scan.DB.settings.my_uuid='receiver'
receive(livePacket)
stored=Scan.OrderFulfillment:GetStatuses()[Scan.OrderToOrderID(entry)]
assert(stored.status=='fulfilled' and stored.craftingOrderID==44 and stored.reagentAudit.orderID==44)
assert(#sent==1 and sent[1].data.operation==op.OrderStatusAck)
print('Order sync payload tests passed (immediate live evidence, lean progress, bounded history, ACKs, reordering, isolation).')
