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
-- "Claimed" and "crafted" stay on the crafter's own list: nothing is queued
-- for a linked account, so the final mark has the channel to itself.
for _,progress in ipairs({'claimed','crafted'}) do
    local step=copy(entry);step.status=progress;step.deliveryPending={receiver=true};step.materialsPending={receiver=true}
    step.deliveryConfirmedAt=5
    assert(comm:PrepareOrderStatusDelivery(step)==false and step.deliveryPending==nil and step.materialsPending==nil
        and step.deliveryConfirmedAt==nil, 'a '..progress..' mark is still queued for the linked account')
end
for _,final in ipairs({'fulfilled','rejected','failed','unknown'}) do
    local mark=copy(entry);mark.status=final
    assert(comm:PrepareOrderStatusDelivery(mark)==true and mark.deliveryPending.receiver, 'a '..final..' mark is not delivered')
end
local echoed=copy(entry);echoed.result='completion_notice';comm:PrepareOrderStatusDelivery(echoed)
assert(echoed.deliveryPending.receiver and not echoed.materialsPending,'materialized row echoed the list back')

-- The receiver's current character answers a ping, so it is a fresh target.
receive({prefix='HIRONCRAFT_SCAN',data={operation=op.Ping,version=1,senderID='receiver',data={state=2}}},'Receiver-Realm')
local senderStatuses=fulfillment:GetStatuses()
-- A progress mark goes nowhere when it is shared, also one that an older
-- version had saved as waiting for delivery.
for _,progress in ipairs({'claimed','crafted'}) do
    local step=copy(entry);step.status=progress;comm:PrepareOrderStatusDelivery(step);senderStatuses[key]=step
    sent={};timers={}
    comm:ShareOrderStatus(step);runTimers(0.3)
    assert(#sent==0,'a '..progress..' mark was sent to the linked account')
    step.deliveryPending={receiver=true}
    sent={};timers={}
    comm:ShareOrderStatus(step);runTimers(0.3)
    -- Let what the flush scheduled (the material pump) run out, as it would.
    runTimers(10);flushFrames()
    for _,packet in ipairs(sent) do
        assert(packet.data.operation~=op.ShareOrderCompletion and packet.data.operation~=op.ShareOrderStatus
            and packet.data.operation~=op.ShareOrderMaterials, 'a '..progress..' mark saved as pending was sent')
    end
end
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

-- One crafter and two collectors: an ACK from one collector must not consume
-- the other's rejected-order mark or its independent material delivery.
Scan.DB={settings={my_uuid='craft-three'},realm={linked_accounts={
    ['lap-horde']={permissions={1}},['lap-alliance']={permissions={1}},
}},customers={},listed_orders={}}
Scan.OrderToResponse=function(row)
    local customer=Scan.DB.customers[row.customerName]
    return customer and customer.responses[row.responseID]
end
Scan.QuickReplies={IsOtherSide=function() return true end}
for _,peer in ipairs({'lap-horde','lap-alliance'}) do
    receive({prefix='HIRONCRAFT_SCAN',data={operation=op.Ping,version=1,senderID=peer,data={state=2}}},peer..'-Realm')
end
sent={};timers={};frames={}
local rejectionAudit={version=1,orderID=888,recipeID=1230061,capturedAt=time(),complete=true,
    rows={{itemID=11,name='Ink',required=20,known=true,supplied={{itemID=11,quantity=15,quality=1}}}}}
assert(fulfillment:RecordRejection({orderID=888,customerName='Three-Realm',spellID=1230061,itemID=245769,
    parentProfessionID=773},888,'missing_customer_reagents',rejectionAudit))
local sourceDB=Scan.DB
local notice
for _,value in pairs(fulfillment:GetCompletionNotices()) do if value.orderID==888 then notice=value end end
assert(notice and notice.deliveryPending['lap-horde'] and notice.deliveryPending['lap-alliance'])
runTimers(0.3)
local markPackets={}
for _,packet in ipairs(sent) do if packet.data.operation==op.ShareOrderCompletion then markPackets[packet.target]=packet end end
assert(markPackets['lap-horde-Realm'] and markPackets['lap-alliance-Realm'],'one of two collectors received no decline packet')
for _,packet in pairs(markPackets) do markSent(packet) end
sent={};runTimers(1.5);flushFrames()
local materialPackets={}
for _,packet in ipairs(sent) do if packet.data.operation==op.ShareOrderMaterials then materialPackets[packet.target]=packet end end
assert(materialPackets['lap-horde-Realm'] and materialPackets['lap-alliance-Realm'],'one collector received no material packet')

-- Deliver Alliance's ACK first, while Horde has received nothing yet.
local ack={orderID=888,customerName=notice.customerName,spellID=notice.spellID,itemID=notice.itemID,
    status='rejected',origin=notice.origin,updatedAt=notice.updatedAt}
receive({prefix='HIRONCRAFT_SCAN',data={operation=op.OrderCompletionAck,version=1,senderID='lap-alliance',
    data={notices={ack}}}},'lap-alliance-Realm')
assert(notice.deliveryPending['lap-horde'] and not notice.deliveryPending['lap-alliance'],
    'one collector ACK cleared the other collector decline')
assert(notice.materialsPending['lap-horde'],'one collector ACK cleared the other material list')

local row={customerName='Three-Realm',responseID=1230061}
Scan.DB={settings={my_uuid='lap-horde'},realm={linked_accounts={['craft-three']={permissions={1}}}},
    customers={['Three-Realm']={responses={[1230061]={recipeID=1230061,itemID=245769,parentProfID=773,
        time=time()-60,requestToken='horde-request',crafterFullName='Crafter-Realm'}}}},
    listed_orders={['Three-Realm:1230061']=row}}
receive(markPackets['lap-horde-Realm'],'Crafter-Realm')
local completionACK=find(op.OrderCompletionAck)
local received=fulfillment:GetStatus(row)
assert(received and received.status=='rejected','the Horde collector did not display its rejection')
receive(materialPackets['lap-horde-Realm'],'Crafter-Realm')
local materialACK=find(op.OrderMaterialsAck)
received=fulfillment:GetStatus(row)
assert(received.reagentAudit and received.reagentAudit.recipeID==1230061
    and received.reagentAudit.rows[1].supplied[1].quantity==15,'the Horde collector lost the supplied material quantities')
Scan.DB=sourceDB
receive(completionACK,'lap-horde-Realm')
assert(not notice.deliveryPending,'both collectors ACKed, but the mark is still pending')
receive(materialACK,'lap-horde-Realm')
assert(not notice.materialsPending['lap-horde'] and notice.materialsPending['lap-alliance'],
    'material ACK was not scoped to its collector')
print('Three-account rejection passed (independent recipients, cross-faction notice, material quantities and ACKs).')

-- Chat rules use their own versioned payload on BULK and full links only.
local merges=0
Scan.ChatFilterSync={Merge=function(rules) assert(rules[1].id=='rule'); merges=merges+1 end}
local packet={prefix='HIRONCRAFT_BULK',data={operation=op.ShareChatFilterRules,version=1,senderID='peer',
    data={version=1,rules={{id='rule'}}}}}
actAs('me','peer'); receive(packet,'Peer-Realm'); assert(merges==1)
Scan.DB.realm.linked_accounts.peer.permissions={2}
receive(packet,'Peer-Realm'); assert(merges==1, 'analytics-only peer changed chat rules')
Scan.DB.realm.linked_accounts={}
receive(packet,'Peer-Realm'); assert(merges==1, 'unlinked sender changed chat rules')
actAs('me','peer'); packet.data.data.version=99
receive(packet,'Peer-Realm'); assert(merges==1, 'unknown rule payload version was accepted')
local records={}; for i=1,81 do records[i]={id='rule'..i,n=i,by='me'} end
sent={};frames={};comm:ShareChatFilterRules(records,'Peer-Realm');flushFrames()
assert(#sent==3 and #sent[1].data.data.rules==40 and #sent[3].data.data.rules==1)
for _,p in ipairs(sent) do assert(p.priority=='BULK' and p.prefix=='HIRONCRAFT_BULK') end
print('Chat rule transport passed (full links only, version validation, bulk priority and bounded batches).')

-- Profession links ride on existing parent-profession revisions. Immediate
-- changes exclude the recipe catalog; reconnect uses the normal delta repair.
do
    local crafter='Mavu-Realm'
    local cached={crafter=crafter,guid='Player-1-ABC',
        link='|cffffd000|Htrade:Player-1-ABC:45357:773|h[Inscription]|h|r'}
    Scan.OnCrafterListModified=noop
    Scan.ChatFilterSync=nil
    Scan.DB={settings={my_uuid='pc-links'},realm={linked_accounts={}},
        characters={[crafter]={sourceID='pc-links',parent_professions={[773]={rev=2,profession_link=cached}},
            professions={[2828]={parentProfID=773,recipes={[1]={scan_state=1}}}}}},customers={},listed_orders={}}
    local pc=Scan.DB
    sent={};frames={};comm:ShareCharacterModification(crafter,773,true);flushFrames()
    assert(#sent==0 and pc.characters[crafter].parent_professions[773].rev==3,
        'offline link capture did not advance its durable revision')
    pc.realm.linked_accounts['lap-links']={permissions={1}}
    pc.realm.linked_accounts['analytics-only']={permissions={2}}
    receive({prefix='HIRONCRAFT_SCAN',data={operation=op.Ping,version=1,senderID='lap-links',data={state=2}}},'LaptopMin-Realm')
    sent={};frames={};comm:ShareCharacterModification(crafter,773,true);flushFrames()
    local update=only(op.ShareCharacterData)
    assert(update.prefix=='HIRONCRAFT_BULK' and update.priority=='BULK')
    local payload=update.data.data.characters[crafter]
    assert(not payload.professions and payload.parent_professions[773].profession_link.link==cached.link,
        'link update lost its cache or included recipes')
    Scan.DB={settings={my_uuid='lap-links'},realm={linked_accounts={['pc-links']={permissions={1}}}},
        characters={[crafter]={sourceID='pc-links',parent_professions={[773]={rev=2}},
            professions={[2828]={parentProfID=773,recipes={[1]={scan_state=1}}}}}},customers={},listed_orders={}}
    local laptop=Scan.DB
    receive(update,'Mavu-Realm')
    assert(laptop.characters[crafter].parent_professions[773].profession_link.link==cached.link)
    assert(laptop.characters[crafter].professions[2828].recipes[1].scan_state==1,'parent-only link update erased recipes')
    local stale=copy(update);stale.data.data.characters[crafter].parent_professions[773]={rev=3}
    receive(stale,'Mavu-Realm')
    assert(laptop.characters[crafter].parent_professions[773].profession_link.link==cached.link,'older profile erased link')
    -- Both analytics-only and unknown peers must be excluded by transport.
    laptop.characters[crafter].parent_professions[773]={rev=1}
    laptop.realm.linked_accounts['pc-links'].permissions={2};receive(update,'Mavu-Realm')
    assert(not laptop.characters[crafter].parent_professions[773].profession_link)
    laptop.realm.linked_accounts={};receive(update,'Mavu-Realm')
    assert(not laptop.characters[crafter].parent_professions[773].profession_link)
    laptop.realm.linked_accounts['pc-links']={permissions={1}}
    -- Miss the push, reconnect with the old revision, then receive the cache.
    Scan.DB=pc
    receive({prefix='HIRONCRAFT_BULK',data={operation=op.ShareCharacterData,version=1,senderID='lap-links',
        data={state=2,revisions={[crafter]={[773]=1}},peers={'pc-links'}}}},'LaptopMin-Realm')
    flushFrames() -- The reply serializes after the receive frame completed.
    local repair=only(op.ShareCharacterData)
    Scan.DB=laptop;receive(repair,'Mavu-Realm')
    assert(laptop.characters[crafter].parent_professions[773].profession_link.link==cached.link,
        'reconnect revision exchange did not repair a missed link')
    -- A first small update may beat the full profile onto a fresh laptop.
    laptop.characters={};receive(update,'Mavu-Realm')
    assert(type(laptop.characters[crafter].professions)=='table')
    receive({prefix='HIRONCRAFT_BULK',data={operation=op.ShareCharacterData,version=1,senderID='pc-links',
        data={state=1,revisions={[crafter]={[773]=4}},peers={'lap-links'}}}},'Mavu-Realm')
    flushFrames()
    local inquiry=only(op.ShareCharacterData)
    assert(inquiry.data.data.revisions[crafter][773]==-1,'parent-only profile claimed a complete recipe catalog')
    Scan.DB=pc;receive(inquiry,'LaptopMin-Realm');flushFrames()
    repair=only(op.ShareCharacterData)
    Scan.DB=laptop;receive(repair,'Mavu-Realm')
    assert(laptop.characters[crafter].professions[2828].recipes[1].scan_state==1,
        'same-revision full snapshot did not complete the parent-only profile')
    local noNewer=copy(update);noNewer.data.data.characters[crafter].parent_professions[773].profession_link=nil
    noNewer.data.data.characters[crafter].parent_professions[773].rev=5
    receive(noNewer,'Mavu-Realm')
    assert(not laptop.characters[crafter].parent_professions[773].profession_link,
        'removing a forgotten profession link did not sync')
end
print('Profession link transport passed (parent-only bulk push, offline revisions, stale packets, reconnect, permissions, deletion).')

