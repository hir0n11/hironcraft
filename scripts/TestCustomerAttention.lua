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
A.Tick() -- First enable starts the saved grace period, before any rows exist.
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
local variants={'sent','send','sending','sendin','sended','sented','sendt','sendet',
    'senting','sendig','sendingg','sends','sned','sedn','snt','snd','done',
    'senidng','sendign','sedning','sendnig'}
for _,word in ipairs(variants) do
    for _,message in ipairs({word,word:upper()..'!','I '..word..' the order to Favu',word..' ty'}) do
        assert(A.Classify(message)=='sent','unrecognized confirmation: '..message)
    end
    for _,message in ipairs({'not yet '..word,'I will '..word,"I haven't "..word,"I won't "..word,
        "I couldn't "..word,"it wasn't "..word,'where should I '..word,
        'please '..word..' to Favu',word..' me the name',word..' later',word..' in 5 minutes',
        word..' in a few seconds',word..' in 2 hours',word..'?'}) do
        assert(A.Classify(message)~='sent','false confirmation: '..message)
    end
end
assert(A.Classify('send to Favu')=='sent')
assert(A.Classify('i send you the order')=='sent')
assert(A.Classify('send pls')~='sent' and A.Classify('send please')~='sent')
for _,prefix in ipairs({'I will send ',"I'll send ",'I’ll send ','ill send ','will send '}) do
    for _,tail in ipairs({'now','right now','it now','it right now','the order now','the order right now',
        'order now','order right now','now, thanks','right now ty'}) do
        local message=prefix..tail
        assert(A.Classify(message)=='sent','immediate sending confirmation was missed: '..message)
        assert(A.Classify(message:upper()..'!')=='sent','immediate confirmation lost case/punctuation: '..message)
    end
end
for _,message in ipairs({'I will send','I will send soon',"I'll send later",'I will send tomorrow',
    'I will send in a minute','I will send now?','I will send right now?',
    'I will not send now',"I won't send now",'not I will send now',
    'can I send now','should I send now','please send now','I will send now if I have mats',
    'I will send now after getting mats','I will send now or later','I will send now but not yet',
    'I will send now, getting mats','I will send now, buying mats'}) do
    assert(A.Classify(message)~='sent','non-confirmation became immediate sending: '..message)
end
for _,message in ipairs({'sender','sendingly','resent','unsent','present','undone','redone','ready','okay'}) do
    assert(A.Classify(message)~='sent','unrelated word became a confirmation: '..message)
end
for _,message in ipairs({"done'",'DONE!','done’','all done',"I'm done",'done, thanks'}) do
    assert(A.Classify(message)=='sent','done confirmation was missed: '..message)
end
for _,message in ipairs({'not done','not done yet','almost done','nearly done','will be done',
    'done?','done getting mats','done buying mats','done later'}) do
    assert(A.Classify(message)~='sent','unfinished work became a done confirmation: '..message)
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

-- A greeting older than a minute must not produce an immediate first alarm
-- when the customer finally replies and activates the second check.
now=3000
Scan.DB.customers={};Scan.DB.listed_orders={}
local graceInfo,graceRow,graceOrder=Add('Grace-Realm',6,'grace')
now=3010;A.Record(graceInfo,{receivedAt=now},false)
now=3120;M.MarkReply(graceInfo,{message='sending now',receivedAt=now})
assert(graceRow.firstAnsweredAt==3120 and graceRow.customerState=='sent')
local sounded=alerts
A.Tick();assert(alerts==sounded,'old greeting caused an immediate first alarm')
now=3179;A.Tick();assert(alerts==sounded,'first alarm rang before a full minute')
now=3180;A.Tick();assert(alerts==sounded+1,'first alarm did not ring after a minute')
now=3190;A.Outgoing('Grace-Realm')
now=3249;assert(A.Collect(now)==0,'later actual reply did not restart the minute')
now=3250;assert(A.Collect(now)==1)
M.ToggleAnswered(graceRow,graceOrder)
now=3400;M.MarkReply(graceInfo,{message='hello again',receivedAt=now})
assert(graceRow.firstAnsweredAt==3400 and A.Collect(now)==0,'reactivated check inherited an old first-answer time')
assert(A.Collect(3459)==0 and A.Collect(3460)==1)
-- Old checked rows also get a minute after switching the feature on. The
-- persisted enable timestamp survives reload instead of delaying forever.
now=3500
Scan.DB.settings.customer_reminders_enabled=false;A.RemindersChanged()
now=3600
Scan.DB.settings.customer_reminders_enabled=true;A.RemindersChanged()
sounded=alerts;A.Tick();assert(alerts==sounded,'enabling reminders rang immediately')
now=3659;A.Tick();assert(alerts==sounded)
assert(loadfile('Customer/CustomerAttention.lua'))('HironCraft',Scan)
A=Scan.CustomerAttention
now=3660;A.Tick();assert(alerts==sounded+1,'reload restarted the enable grace period')
now=3700;Scan.DB.settings.customer_reminder_enabled_at=nil
sounded=alerts;A.Tick();assert(alerts==sounded,'upgrade without enable timestamp rang immediately')
now=3759;A.Tick();assert(alerts==sounded)
now=3760;A.Tick();assert(alerts==sounded+1)
-- Screenshot: the customer asks about quality, the crafter answers, and
-- "done'" confirms sending the order. It is not a crafted/fulfilled mark.
now=3800
Scan.DB.customers={};Scan.DB.listed_orders={}
local doneInfo,doneRow,doneOrder=Add('Screenshot-Realm',7,'done-scenario')
M.MarkReply(doneInfo,{message='max lvl?',body='max lvl?',receivedAt=now})
assert(A.State(doneOrder,doneRow)=='attention')
now=3801;A.Record(doneInfo,{message='max q',receivedAt=now},false)
now=3803;M.MarkReply(doneInfo,{message="Customer: done'",body="done'",receivedAt=now})
assert(doneRow.customer_answered and A.State(doneOrder,doneRow)=='sent')
assert(A.KeepAlive(doneOrder,doneRow),'customer done was treated as crafted/fulfilled')
assert(A.Collect(3860)==0 and A.Collect(3861)==1,'done confirmation stopped or prematurely rang the reminder')
-- Screenshot: customer checks the character name, receives it, then says
-- "i will send now". Green is still unfinished and keeps the normal reminder.
now=3900
Scan.DB.customers={};Scan.DB.listed_orders={}
local sendInfo,sendRow,sendOrder=Add('Mohma-Realm',8,'send-now-scenario')
M.MarkReply(sendInfo,{body='yoo',receivedAt=now})
now=3901;M.MarkReply(sendInfo,{body='in this name?',receivedAt=now})
assert(A.State(sendOrder,sendRow)=='attention')
now=3902;A.Record(sendInfo,{message='Lavu',receivedAt=now},false)
now=3903;M.MarkReply(sendInfo,{body='okay',receivedAt=now})
assert(A.State(sendOrder,sendRow)=='attention')
now=3904;M.MarkReply(sendInfo,{body='i will send now',receivedAt=now})
assert(sendRow.customer_answered and A.State(sendOrder,sendRow)=='sent')
assert(A.KeepAlive(sendOrder,sendRow),'immediate send was treated as crafted/fulfilled')
assert(A.Collect(3961)==0 and A.Collect(3962)==1,'immediate send changed the reminder delay')
-- Screenshot: after the crafter says where to send the order, the customer
-- replies with a standalone +. It activates the reply mark/green state, not
-- a completed craft or an immediate reminder.
now=4000
Scan.DB.customers={};Scan.DB.listed_orders={}
local plusInfo,plusRow,plusOrder=Add('Xenious-Realm',9,'plus-scenario')
A.Record(plusInfo,{body="Send to Favu. You choose the price. I'll do it now.",receivedAt=now},false)
now=4001;M.MarkReply(plusInfo,{body='+',receivedAt=now})
assert(plusRow.customer_answered and plusRow.firstAnsweredAt==4001 and A.State(plusOrder,plusRow)=='sent')
now=4002;M.MarkReply(plusInfo,{body='++',receivedAt=now})
assert(plusRow.firstAnsweredAt==4001 and A.KeepAlive(plusOrder,plusRow))
assert(A.Collect(4060)==0 and A.Collect(4061)==1,'plus confirmation stopped or prematurely rang the reminder')
-- Screenshot: hi -> check from the customer, followed by omw -> hey from the
-- crafter. Only check turns the row green; outgoing replies reset the reminder.
now=4100
Scan.DB.customers={};Scan.DB.listed_orders={}
local checkInfo,checkRow,checkOrder=Add('Oldnova-Realm',10,'check-scenario')
A.Record(checkInfo,{body="Send to Mavu. You choose the price. I'll do it now.",receivedAt=now},false)
now=4101;M.MarkReply(checkInfo,{body='hi',receivedAt=now})
assert(checkRow.customer_answered and A.State(checkOrder,checkRow)=='attention')
now=4102;M.MarkReply(checkInfo,{body='check',receivedAt=now})
assert(A.State(checkOrder,checkRow)=='sent' and checkRow.firstAnsweredAt==4101)
now=4103;A.Record(checkInfo,{body='omw',receivedAt=now},false)
now=4104;A.Record(checkInfo,{body='hey',receivedAt=now},false)
assert(A.State(checkOrder,checkRow)=='sent' and A.KeepAlive(checkOrder,checkRow))
assert(checkInfo.lastCrafterReplyAt==4104 and A.Collect(4163)==0 and A.Collect(4164)==1,
    'check/outgoing replies changed the green state or reminder delay')
-- Screenshot: "2 order placed" confirms the active inquiry, not every row
-- belonging to this customer, and never creates/completes a crafting order.
now=4200
Scan.DB.settings.order_sent_keywords=nil
Scan.DB.customers={};Scan.DB.listed_orders={}
local _,unrelatedRow,unrelatedOrder=Add('Other-Realm',11,'unrelated')
local countedInfo,olderRow,olderOrder=Add('Soggo-Realm',12,'older-inquiry')
local _,countedRow,countedOrder=Add('Soggo-Realm',13,'counted-inquiry')
A.Record(countedInfo,{body="Send to Favu. You choose the price. I'll do it now.",receivedAt=now},false)
now=4201;M.MarkReply(countedInfo,{body='2 order placed',receivedAt=now})
assert(countedRow.customer_answered and A.State(countedOrder,countedRow)=='sent',
    'numeric order-placed screenshot did not turn the active row green')
assert(not olderRow.customer_answered and not unrelatedRow.customer_answered,
    'an order quantity checked another inquiry or customer')
local listedCount=0
for _ in pairs(Scan.DB.listed_orders) do listedCount=listedCount+1 end
assert(listedCount==3 and Scan.OrderToResponse(olderOrder)==olderRow
    and Scan.OrderToResponse(unrelatedOrder)==unrelatedRow,'order quantity changed scanner rows')
assert(A.KeepAlive(countedOrder,countedRow),'numeric confirmation was treated as a completed craft')
assert(A.Collect(4260)==0 and A.Collect(4261)==1,'numeric confirmation changed the minute reminder delay')
-- Screenshot: a misspelled "senidng" followed by the crafter's outgoing
-- "omw" keeps the row green and restarts only the normal reminder clock.
now=4300
Scan.DB.customers={};Scan.DB.listed_orders={}
local typoInfo,typoRow,typoOrder=Add('Eminooni-Realm',14,'sending-typo')
A.Record(typoInfo,{body="Send to Lavu. You choose the price. I'll do it now.",receivedAt=now},false)
now=4301;M.MarkReply(typoInfo,{body='senidng',receivedAt=now})
assert(typoRow.customer_answered and A.State(typoOrder,typoRow)=='sent',
    'screenshot sending typo did not turn the active row green')
now=4302;A.Record(typoInfo,{body='omw',receivedAt=now},false)
assert(A.State(typoOrder,typoRow)=='sent' and A.KeepAlive(typoOrder,typoRow),
    'outgoing omw cleared the sending confirmation or completed the craft')
assert(typoInfo.lastCrafterReplyAt==4302 and A.Collect(4361)==0 and A.Collect(4362)==1,
    'sending typo or outgoing omw changed the one-minute reminder delay')
print('Customer attention passed: classification, two colours, last actual reply, cadence, aliases, snooze, stop conditions, reload, late packets and request replacement.')
