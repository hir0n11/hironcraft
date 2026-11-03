local now=1000
time=function() return now end
local packets={}
local Scan={DB={settings={my_uuid='local'},customers={},listed_orders={}},Utils={onLoad=function() end}}
Scan.OrderToCustomerInfo=function(o) return Scan.DB.customers[o.customerName] end
Scan.OrderToResponse=function(o)
    local info=Scan.OrderToCustomerInfo(o)
    return info and info.responses[o.responseID]
end
HironCraftScanComm={ShareCustomerAttention=function(_,packet) packets[#packets+1]=packet end}
assert(loadfile('Customer/RequestTracking.lua'))('HironCraft',Scan)
assert(loadfile('ChatFilter/FilterEngine.lua'))('HironCraft',Scan)
assert(loadfile('Customer/CustomerAttention.lua'))('HironCraft',Scan)
local A,M=Scan.CustomerAttention,Scan.RequestTracking
local function Add(name,id)
    local info=Scan.DB.customers[name] or {responses={}}
    Scan.DB.customers[name]=info
    local r={responseID=id,requestToken='job-'..id,time=now,inquiryID='inquiry-'..id,
        greeting_sent=true,greetingSentAt=now}
    info.responses[id]=r
    info.activeInquiryID,info.activeInquiryAt=r.inquiryID,now
    local order={customerName=name,responseID=id}
    Scan.DB.listed_orders[name..':'..id]=order
    return info,r,order
end
local info,r,o=Add('Buyer',1)
local _,other,otherOrder=Add('Other',2)
local function Incoming(text,at,id)
    now=at
    M.MarkReply(info,{body=text,receivedAt=at,syncID=id})
end
Incoming('what do you mean?',1001,'question-1')
assert(A.State(o,r)=='attention' and A.Collect(1061)==1)
assert(A.Acknowledge(o) and r.customer_answered,'acknowledgement removed the reply check')
assert(A.State(o,r)=='quiet' and not A.NeedsAttention(o,r) and A.Collect(1200)==0)
assert(A.KeepAlive(o,r),'silencing the reminder expired a still-pending customer row')
assert(Scan.OrderToResponse(o)==r and not other.customer_answered and A.State(otherOrder,other)==nil)
local acknowledged=packets[#packets]
assert(acknowledged.handled==true and acknowledged.answered==nil and acknowledged.handledReplyID=='question-1')
-- Same message replay cannot undo a human acknowledgement.
Incoming('what do you mean?',1001,'question-1')
assert(A.State(o,r)=='quiet')
-- A genuinely different reply in the same second must still wake attention.
Incoming('where do I send it?',1001,'question-2')
assert(A.State(o,r)=='attention' and r.firstAnsweredAt==1001)
local context=A.ReplyContext(o)
assert(not A.Resolve(o,context,true) and A.State(o,r)=='attention',
    'a quick reply still silenced a yellow reminder')
local marker=A.Resolve(o,context,false)
assert(marker and r.customer_answered and A.State(o,r)=='quiet')
assert(A.Collect(1500)==0 and A.KeepAlive(o,r))
Incoming('is the quality guaranteed?',1200,'question-3')
assert(A.State(o,r)=='attention' and r.firstAnsweredAt==1200)
assert(A.Collect(1259)==0 and A.Collect(1260)==1,'a new unresolved question rang before its minute')
assert(not A.Resolve(o,context,false),'an old context silenced a newer question')
-- No future/stale completion/duplicate resolution may mark a replacement row.
local stale=A.ReplyContext(o)
r.requestToken='replacement'
assert(not A.Resolve(o,stale,false))
r.requestToken='job-1'
local obsolete={token='old-token',replyAt=1000}
r.attentionResolved=obsolete
local corrected,previous=A.Resolve(o,A.ReplyContext(o),false)
assert(corrected and previous==nil and A.UndoResolution(o,corrected,previous)
    and A.State(o,r)=='attention','rollback restored obsolete request metadata')
Incoming('sent',1201,'send-1')
assert(A.State(o,r)=='sent')
assert(not A.Resolve(o,A.ReplyContext(o),true),'quick reply to sent incorrectly removed the green order')
assert(A.Collect(1260)==1)
assert(A.Acknowledge(o) and A.State(o,r)=='quiet' and r.customer_answered,
    'manual right-click acknowledgement could not silence a false sent claim')
assert(A.Collect(1500)==0)
Incoming('hello again',1300,'new-question')
assert(A.State(o,r)=='attention','acknowledged old green leaked into a new ordinary reply')
assert(A.Collect(1359)==0 and A.Collect(1360)==1)
Incoming('sent now',1301,'send-2')
assert(A.State(o,r)=='sent')
assert(A.Acknowledge(o))
assert(loadfile('Customer/CustomerAttention.lua'))('HironCraft',Scan)
A=Scan.CustomerAttention
assert(A.State(o,r)=='quiet' and r.customer_answered,'reload lost resolution or the reply check')
local snapshot
for _,packet in ipairs(A.Snapshot()) do
    if packet.customer=='Buyer' and not packet.reply then snapshot=packet end
end
assert(snapshot and snapshot.handled and snapshot.handledReplyID=='send-2')
r.attentionResolved=nil;r.attentionRevision=0;r.attentionActor=nil
assert(A.Receive(snapshot) and A.State(o,r)=='quiet','linked snapshot did not restore resolution')
Incoming('please explain',1400,'fresh-question')
local stalePacket={}
for key,value in pairs(snapshot) do stalePacket[key]=value end
stalePacket.n=(r.attentionRevision or 0)+1;stalePacket.by='peer';stalePacket.at=now
assert(A.Receive(stalePacket) and A.State(o,r)=='attention','delayed remote acknowledgement hid a newer question')
-- Undo is bound to one exact manual marker and cannot override a later
-- manual decision or new request.
local rollback=A.Resolve(o,A.ReplyContext(o),false)
assert(rollback and A.State(o,r)=='quiet')
assert(A.UndoResolution(o,rollback,nil) and A.State(o,r)=='attention')
rollback=A.Resolve(o,A.ReplyContext(o),false)
Incoming('sent',1401,'new-send')
assert(A.Acknowledge(o))
assert(not A.UndoResolution(o,rollback,nil) and A.State(o,r)=='quiet','old undo affected a later manual decision')
A.SetState(o,'attention')
assert(A.State(o,r)=='attention' and A.Collect(1460)==0 and A.Collect(1461)==1)
-- Bad metadata is rejected without touching the second check or resolution.
for _,invalid in ipairs({{handled=true},{handled='yes',handledReplyAt=0},
    {handled=true,handledReplyAt=0/0},{handled=true,handledReplyAt=math.huge},
    {handled=true,handledReplyAt=now,handledReplyID={}},{handledReplyID='without-a-flag'},
    {handledManually=true},{handled=true,handledReplyAt=now,handledManually='yes'}}) do
    local packet={customer='Buyer',responseID=1,token='job-1',by='peer',n=999,at=now}
    for key,value in pairs(invalid) do packet[key]=value end
    assert(not A.Receive(packet),'invalid handled metadata was accepted')
end
assert(r.customer_answered)
-- A metadata packet may arrive before the row/chat it acknowledges. Its exact
-- old message remains quiet; the next message with a different identity wakes.
now=1500
local pending={customer='Late',responseID=3,token='job-3',by='peer',n=1,at=1500,
    handled=true,handledManually=true,handledReplyAt=1500,handledReplyID='late-message'}
assert(not A.Receive(pending))
local late,lr,lo=Add('Late',3)
A.ProcessPending()
M.MarkReply(late,{body='where?',receivedAt=1500,syncID='late-message'})
assert(A.State(lo,lr)=='quiet' and lr.customer_answered)
now=1501;M.MarkReply(late,{body='sent',receivedAt=now,syncID='late-new-message'})
assert(A.State(lo,lr)=='sent' and A.Collect(1560)==1 and A.Collect(1561)==2)
-- An acknowledgement is only attention metadata, never order fulfillment.
Scan.OrderFulfillment={GetStatus=function(_,order)
    if order==o then return {status='fulfilled'} end
end}
Incoming('hello',1600,'after-completion')
assert(A.State(o,r)=='done' and not A.Acknowledge(o))
-- Fresh request setup reuses the row table, but not its old attention epoch.
Scan.OrderFulfillment=nil
r.requestToken='next-request';r.time=1700
A.ResetRequest(r)
assert(r.customer_answered and r.greeting_sent and not r.attentionResolved and not r.lastCustomerReplyAt
    and not r.firstAnsweredAt and not r.customerState and not r.reminderSnoozeUntil)
now=1701;M.MarkReply(info,{body='where?',receivedAt=now,syncID='next-request-question'})
assert(A.State(o,r)=='attention' and A.Collect(1760)==1 and A.Collect(1761)==2,
    'replacement request inherited old attention or an old reminder clock')
-- Legacy auto-handled state and packets must no longer hide reminders. A
-- current manual acknowledgement survives legacy peer snapshots/rollbacks.
local legacy={token=r.requestToken,at=now,replyAt=r.lastCustomerReplyAt,replyID=r.lastCustomerReplyID}
r.attentionResolved=legacy
assert(A.State(o,r)=='attention' and A.Collect(1761)==2,'legacy auto-handled state still muted reminders')
assert(A.Acknowledge(o) and r.attentionResolved.manual)
local function LegacyPacket(handled,n)
    return {customer='Buyer',responseID=1,token=r.requestToken,by='old-peer',n=n,at=now,
        handled=handled,handledReplyAt=r.lastCustomerReplyAt,handledReplyID=r.lastCustomerReplyID}
end
assert(A.Receive(LegacyPacket(false,999)) and A.State(o,r)=='quiet','old peer rollback undid manual acknowledgement')
Incoming('where now?',1702,'after-legacy-rollback')
assert(A.Receive(LegacyPacket(true,1000)) and A.State(o,r)=='attention',
    'old peer automatic handling silenced a new question')
assert(A.Acknowledge(o))
for _,packet in ipairs(A.Snapshot()) do
    if packet.customer=='Buyer' and not packet.reply then
        assert(packet.handled and packet.handledManually,'manual origin was lost in a linked snapshot')
    end
end
print('Attention resolution passed: manual yellow/green acknowledgement, second check retained, quick replies ignored, stale contexts, exact sync, reload and legacy automatic markers.')
