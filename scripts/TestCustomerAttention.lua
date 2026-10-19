local now, alerts, packets = 1000, 0, {}
time=function() return now end
local Scan={DB={settings={my_uuid='laptop',customer_reminders_enabled=true},customers={},listed_orders={}},Utils={}}
Scan.Utils.onLoad=function() end
Scan.LOCAL={GetText=function(_,s) return s end}
Scan.OrderToCustomerInfo=function(o) return Scan.DB.customers[o.customerName] end
Scan.OrderToResponse=function(o) local i=Scan.OrderToCustomerInfo(o);return i and i.responses[o.responseID] end
Scan.Notifications={Alert=function(kind) assert(kind=='reminder');alerts=alerts+1;return true end}
local ignored={}
Scan.IsIgnored=function(name) return ignored[name] end
HironCraftScanComm={ShareCustomerAttention=function(_,p) packets[#packets+1]=p end}
assert(loadfile('ChatFilter/FilterEngine.lua'))('HironCraft',Scan)
assert(loadfile('Customer/RequestTracking.lua'))('HironCraft',Scan)
assert(loadfile('Customer/CustomerAttention.lua'))('HironCraft',Scan)
local A,M=Scan.CustomerAttention,Scan.RequestTracking
for _,s in ipairs({'sent','SENT!','order sent','send','отправил','Заказ отправила','отправлено'}) do
    assert(A.Classify(s)=='sent',s)
end
for _,s in ipairs({'not sent yet',"haven't sent",'not send','will send soon','can I send','getting mats',
    'buying mats','не отправил','ещё не отправлено','отправлю позже','собираю реагенты'}) do
    assert(A.Classify(s)=='waiting',s)
end
assert(A.Classify('sent?')~='sent')
assert(A.Classify('present')~='sent')
assert(A.Classify('where to send?')~='sent')
for _,s in ipairs({'please send to Favu',"I'll send soon",'I haven’t sent yet','it needs to be sent','send me the name'}) do
    assert(A.Classify(s)~='sent',s)
end
Scan.DB.settings.order_sent_keywords='доставлено, placed'
assert(A.Classify('placed')=='sent')
assert(A.Classify('not sent, placed later')=='waiting')
local function Add(name,id,token)
    local info=Scan.DB.customers[name] or {responses={}}
    Scan.DB.customers[name]=info
    local r={responseID=id,requestToken=token,time=now,greeting_sent=true,inquiryID=token,greetingSentAt=now}
    info.responses[id]=r;info.activeInquiryID,info.activeInquiryAt=token,now
    local o={customerName=name,responseID=id}
    Scan.DB.listed_orders[name..id]=o
    return info,r,o
end
local info,r,o=Add('Buyer-Realm',1,'first')
M.MarkReply(info,{message='Buyer: sent',body='sent',receivedAt=now})
assert(r.customer_answered and A.State(o,r)=='sent')
now=1020;M.MarkReply(info,{message='ty',receivedAt=now})
assert(A.State(o,r)=='sent','small talk cleared confirmed send')
now=1030;M.MarkReply(info,{message='getting mats',receivedAt=now})
assert(A.State(o,r)=='waiting')
M.MarkReply(info,{message='sent',receivedAt=1005})
assert(A.State(o,r)=='waiting','older reply repainted a newer state')
-- The raw body prevents a character named Sent from checking every message.
M.MarkReply(info,{message='Sent: hello',body='hello',receivedAt=1031})
assert(A.State(o,r)~='sent')
now=1059;assert(A.Collect(now)==0)
now=1060;assert(A.Collect(now)==1,'incoming small talk restarted the first-answer clock')
A.Tick();assert(alerts==1)
now=1119;A.Tick();assert(alerts==1)
now=1120;A.Tick();assert(alerts==2)
A.Record(info,{receivedAt=1120},false)
now=1179;assert(A.Collect(now)==0)
now=1180;A.Tick();assert(alerts==3)
A.Record(info,{receivedAt=1000},false)
assert(info.lastCrafterReplyAt==1120,'old outgoing sync reset the clock')
-- Yellow and green both remind; aliases count once; many rows make one sound.
local info2,r2,o2=Add('Other-Realm',2,'second')
M.MarkReply(info2,{message='getting mats',receivedAt=1180})
now=1240;r.customerState='sent'
Scan.DB.listed_orders.alias=o
assert(A.Collect(now)==2)
A.Tick();assert(alerts==4,'one tick rang separately for each row')
M.ToggleAnswered(r,o)
assert(not r.customer_answered and A.Collect(now)==1)
assert(packets[#packets].answered==false)
M.MarkReply(info,{message='sent',receivedAt=1230})
assert(not r.customer_answered,'delayed old reply restored a manually removed check')
now=1241;M.MarkReply(info,{message='hello again',receivedAt=1241})
assert(r.customer_answered,'genuine new reply did not restore the check')
A.Snooze(o);assert(A.Collect(1300)==1)
now=1600;assert(A.Collect(now)==2)
ignored[o.customerName]=true;assert(A.Collect(now)==1)
ignored[o.customerName]=nil
local status={}
Scan.OrderFulfillment={GetStatus=function(_,order) return {status=status[order.responseID]} end}
for _,s in ipairs({'crafted','fulfilled','rejected'}) do
    status[1]=s;assert(A.Collect(now)==1 and not A.KeepAlive(o,r),s)
end
status[1]='claimed';assert(A.State(o,r)=='sent' and A.Collect(now)==2)
assert(A.KeepAlive(o,r),'active client would expire at the ordinary scanner timeout')
local savedStatus=Scan.OrderFulfillment.GetStatus
Scan.OrderFulfillment.GetStatus=function() error('temporarily unavailable') end
assert(A.State(o,r)~='done','unavailable status destroyed an active row')
Scan.OrderFulfillment.GetStatus=savedStatus
M.MarkReply(info,{message='sent',receivedAt=now,replyContext={id='bad',at=now,members={false}}})
-- Local disable, persisted cadence, and reload do not yield duplicate alarms.
Scan.DB.settings.customer_reminders_enabled=false
local before=alerts;A.Tick();assert(alerts==before)
Scan.DB.settings.customer_reminders_enabled=true
Scan.DB.settings.customer_reminder_last=now
assert(loadfile('Customer/CustomerAttention.lua'))('HironCraft',Scan)
A=Scan.CustomerAttention;A.Tick();assert(alerts==before)
-- Exact identities, revisions and message chronology guard manual sync.
local n=(r.attentionRevision or 0)+1
local data={customer=o.customerName,responseID=1,token='first',by='pc',n=n,at=now,state='waiting',answered=false}
assert(A.Receive(data) and not r.customer_answered)
assert(not A.Receive(data),'same packet applied twice')
assert(not A.Receive({customer=o.customerName,responseID=1,token='first',by='pc',n=n-1,at=now,answered=true}))
local future={customer='Future-Realm',responseID=3,token='future',by='pc',n=1,at=now,answered=true,state='sent'}
assert(not A.Receive(future))
local _,r3,o3=Add('Future-Realm',3,'future')
A.ProcessPending();assert(r3.customer_answered and r3.customerState=='sent','early packet was lost before the row arrived')
local replacement={responseID=1,requestToken='new',time=now,customer_answered=false}
info.responses[1]=replacement
data.n=n+5
assert(not A.Receive(data) and not replacement.customer_answered,'old request checked a replacement row')
for _,bad in ipairs({{},false,{customer='x',token='x',by='pc',n=0/0,at=now},
    {customer='x',token='x',by='pc',n=1,at=math.huge}}) do assert(not A.Receive(bad)) end
local beforeReply=info.lastCrafterReplyAt
assert(not A.ReceiveReply({customer=o.customerName,at=now,requests={{responseID=1,token='first'}}}))
assert(info.lastCrafterReplyAt==beforeReply,'old-request reply reset a replacement order')
local replyPacket={reply=true,customer=o.customerName,at=now,requests={{responseID=1,token='new'}}}
assert(A.Receive(replyPacket) and info.lastCrafterReplyAt==now)
replyPacket.at=now-100;assert(A.Receive(replyPacket) and info.lastCrafterReplyAt==now,'old clock rolled back a reply')
Scan.DB.settings.proxy_send_enabled=false
now=now+1;A.Outgoing(o.customerName)
assert(packets[#packets].reply and packets[#packets].at==now,'reply clock depended on proxy chat')
local packetCount=#packets;A.Outgoing(o.customerName);assert(#packets==packetCount,'same-second clock was broadcast twice')
local _,futureResponse=Add('LateClock-Realm',4,'late-clock')
Scan.DB.customers['LateClock-Realm']=nil
assert(not A.Receive({reply=true,customer='LateClock-Realm',at=now,requests={{responseID=4,token='late-clock'}}}))
Scan.DB.customers['LateClock-Realm']={responses={[4]=futureResponse}}
A.ProcessPending();assert(Scan.DB.customers['LateClock-Realm'].lastCrafterReplyAt==now)
local futureInfo=Scan.DB.customers['LateClock-Realm']
futureInfo.lastCrafterReplyAt=now-500;futureResponse.firstAnsweredAt=now;futureResponse.customer_answered=true
Scan.DB.listed_orders={test={customerName='LateClock-Realm',responseID=4}}
assert(A.Collect(now+59)==0,'a reply from an older request started a new request clock too early')
-- The actual event watcher does not depend on scanner event registration.
local outgoingFrame
CreateFrame=function()
    outgoingFrame={events={},RegisterEvent=function(self,event) self.events[event]=true end,
        SetScript=function(self,_,fn) self.callback=fn end}
    return outgoingFrame
end
assert(loadfile('Customer/CustomerAttention.lua'))('HironCraft',Scan)
A=Scan.CustomerAttention
now=now+1;outgoingFrame.callback(nil,'CHAT_MSG_WHISPER_INFORM','hello','LateClock-Realm')
assert(futureInfo.lastCrafterReplyAt==now and outgoingFrame.events.CHAT_MSG_WHISPER_INFORM)
Scan.BattleNet={IsCustomer=function(name) return type(name)=='string' and name:sub(1,5)=='BNET:' end,
    FromID=function(id) assert(id==77);return 'BNET:owner:friend#1234' end}
local bnInfo,bnResponse,bnOrder=Add('BNET:owner:friend#1234',5,'bn-job')
packetCount=#packets;now=now+1
outgoingFrame.callback(nil,'CHAT_MSG_BN_WHISPER_INFORM','hello','Display',nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,77)
assert(bnInfo.lastCrafterReplyAt==now and #packets==packetCount,'BN timing was forwarded to another account')
A.Share(bnOrder,{answered=false})
assert(#packets==packetCount,'private BN mark was forwarded')
for _,packet in ipairs(A.Snapshot()) do assert(packet.customer~=bnOrder.customerName) end
print('Customer attention passed: classification, two colours, last actual reply, cadence, aliases, snooze, stop conditions, reload, late packets and request replacement.')
