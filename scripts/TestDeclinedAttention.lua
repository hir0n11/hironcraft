local now,serverOffset=1000,0
time=function() return now end
GetServerTime=function() return now+serverOffset end
issecretvalue=function() return false end
local Scan={DB={settings={my_uuid='local'},realm={},customers={},listed_orders={}},Utils={}}
Scan.Utils.saved=function(parent,key,value)
    if parent[key]==nil then parent[key]=value end
    return parent[key]
end
Scan.Utils.onLoad=function() end
Scan.GetPlayerName=function() return 'Crafter-Realm' end
Scan.OrderToOrderID=function(o) return o.customerName..':'..o.responseID end
Scan.OrderToCustomerInfo=function(o) return Scan.DB.customers[o.customerName] end
Scan.OrderToResponse=function(o)
    local info=Scan.OrderToCustomerInfo(o)
    return info and info.responses[o.responseID]
end
Scan.OrderToLiveResponse=function() end
Scan.ReportError=function(_,err) error(err) end
assert(loadfile('Utils/EventBus.lua'))('HironCraft',Scan)
assert(loadfile('ChatFilter/FilterEngine.lua'))('HironCraft',Scan)
assert(loadfile('Customer/RequestTracking.lua'))('HironCraft',Scan)
assert(loadfile('Customer/CustomerAttention.lua'))('HironCraft',Scan)
assert(loadfile('Customer/OrderFulfillment.lua'))('HironCraft',Scan)
local A,M,F=Scan.CustomerAttention,Scan.RequestTracking,Scan.OrderFulfillment
local function Add(name,id)
    local info=Scan.DB.customers[name] or {responses={}}
    Scan.DB.customers[name]=info
    local r={responseID=id,requestToken='request-'..id,inquiryID='inquiry-'..id,
        time=now,greeting_sent=true,greetingSentAt=now,crafterFullName='Crafter-Realm'}
    info.responses[id]=r
    info.activeInquiryID,info.activeInquiryAt=r.inquiryID,now
    local order={customerName=name,responseID=id}
    Scan.DB.listed_orders[Scan.OrderToOrderID(order)]=order
    return info,r,order
end
local info,r,o=Add('Buyer-Realm',1)
local otherInfo,other,otherOrder=Add('Other-Realm',2)
now=1001;M.MarkReply(info,{body='sent',receivedAt=now})
assert(A.State(o,r)=='sent' and A.KeepAlive(o,r))
now=1100
local rejected=F:SetStatus(o,'rejected',{craftingOrderID=9001})
assert(A.State(o,r)=='done' and A.Collect(now)==0,'decline did not immediately stop attention/reminders')
assert(r.customer_answered,'decline changed the second check')
now=1101;A.Record(info,{body='please resend with the materials',receivedAt=now},false)
assert(A.State(o,r)=='done','an outgoing decline explanation reopened attention')
M.MarkReply(info,{body='sent',receivedAt=1099})
assert(A.State(o,r)=='done','a delayed pre-decline reply reopened attention')
now=1102;M.MarkReply(info,{body='why?',receivedAt=now})
assert(A.State(o,r)=='attention','a new ordinary answer did not restore yellow, or inherited old green')
assert(F:GetStatus(o).status=='rejected' and F:GetStatus(o).craftingOrderID==9001,
    'attention reset the actual rejection/cross')
assert(r.firstAnsweredAt==1102 and A.Collect(1161)==0 and A.Collect(1162)==1,
    'post-decline attention did not get a full minute before its reminder')
now=1103;M.MarkReply(info,{body='both should be there now',receivedAt=now})
assert(A.State(o,r)=='sent' and r.firstAnsweredAt==1102,'resend confirmation did not turn green or reset the timer')
assert(not other.customer_answered and A.State(otherOrder,other)==nil,'another customer was highlighted')
-- A replay/audit update for the same game order must not silence the reply.
now=1104;F:NotifyDeliveryUpdated(rejected)
assert(A.State(o,r)=='sent','duplicate decline notification cleared restored attention')
local replay={}
for key,value in pairs(rejected) do replay[key]=value end
replay.rev=replay.rev+1;replay.updatedAt=now
F:ApplyRemoteStatus(replay)
assert(A.State(o,r)=='sent','enrichment of one rejected game order acted as another decline')
-- Marker and first-answer time survive an addon reload.
assert(loadfile('Customer/CustomerAttention.lua'))('HironCraft',Scan)
A=Scan.CustomerAttention
assert(A.State(o,r)=='sent' and r.firstAnsweredAt==1102)
now=1105;F:SetStatus(o,'rejected',{craftingOrderID=9002})
assert(A.State(o,r)=='done' and A.Collect(1200)==0,'a second real decline did not silence attention')
now=1106;M.MarkReply(info,{body='getting mats',receivedAt=now})
assert(A.State(o,r)=='waiting' and r.firstAnsweredAt==1106,'a second decline did not start a new reply cycle')
now=1107;M.MarkReply(info,{body='palced',receivedAt=now})
assert(A.State(o,r)=='sent' and F:GetStatus(o).craftingOrderID==9002)
now=1108;F:SetStatus(o,'claimed',{craftingOrderID=9003})
assert(A.State(o,r)=='sent' and r.rejectedAttention==nil,'a new game order inherited the old decline marker')
now=1109;F:SetStatus(o,'crafted',{craftingOrderID=9003})
now=1110;M.MarkReply(info,{body='sent',receivedAt=now})
assert(A.State(o,r)=='done' and not A.KeepAlive(o,r),'a reply reopened an already crafted order')
now=1111;F:SetStatus(o,'fulfilled',{craftingOrderID=9003})
now=1112;M.MarkReply(info,{body='hello',receivedAt=now})
assert(A.State(o,r)=='done','a reply reopened a fulfilled order')
-- A non-active older inquiry must not be painted by a new inquiry's reply.
now=2000
local multi,old,oldOrder=Add('Multi-Realm',3)
F:SetStatus(oldOrder,'rejected',{craftingOrderID=9004})
local _,latest,latestOrder=Add('Multi-Realm',4)
now=2001;M.MarkReply(multi,{body='sent',receivedAt=now})
assert(A.State(oldOrder,old)=='done' and A.State(latestOrder,latest)=='sent')
-- Stale request identities and a manually removed check stay protected.
now=2002;M.ToggleAnswered(latest,latestOrder)
now=2003;M.MarkReply(multi,{body='hello',receivedAt=1999,replyContext={id='old',at=1999,
    members={{responseID=4,requestToken='old-token'}}}})
assert(not latest.customer_answered,'stale reply restored a manually removed check')
-- Slow/fast peer clocks: compare the source status on the server clock.
for _,peerOffset in ipairs({-90,90}) do
    now=3000;serverOffset=25
    local ci,cr,co=Add('Clock'..peerOffset..'-Realm',10+peerOffset)
    now=3001;M.MarkReply(ci,{body='sent',receivedAt=now})
    now=3010
    local status={customerName=co.customerName,responseID=co.responseID,requestToken=cr.requestToken,
        requestTime=3000,status='rejected',craftingOrderID=9100+peerOffset,origin='peer',rev=1,
        updatedAt=3010+25-peerOffset,clockOffset=peerOffset}
    assert(F:ApplyRemoteStatus(status))
    assert(A.State(co,cr)=='done','a peer clock mistook an older reply for a post-decline answer')
    now=3011;M.MarkReply(ci,{body='resent',receivedAt=now})
    assert(A.State(co,cr)=='attention','post-decline reply was lost with a different peer clock')
    now=3012;M.MarkReply(ci,{body='sent',receivedAt=now})
    assert(A.State(co,cr)=='sent')
end
-- Late status arrival: retain a reply already recorded after the real decline,
-- but reset a sticky pre-decline green state to that reply's actual meaning.
now=4000;serverOffset=0
local late,lr,lo=Add('Late-Realm',30)
now=4001;M.MarkReply(late,{body='sent',receivedAt=now})
now=4020;M.MarkReply(late,{body='why?',receivedAt=now})
now=4030
local lateStatus={customerName=lo.customerName,responseID=lo.responseID,requestToken=lr.requestToken,
    requestTime=4000,status='rejected',craftingOrderID=9200,origin='peer',rev=1,updatedAt=4010,clockOffset=0}
F:ApplyRemoteStatus(lateStatus)
assert(A.State(lo,lr)=='attention' and lr.firstAnsweredAt==4020,'late decline hid a genuinely later reply')
assert(F:GetStatus(lo).status=='rejected' and A.KeepAlive(lo,lr))
-- Legacy peers without clock metadata use a fixed local receipt, not a moving
-- cutoff on every refresh. Reload, old replay and repeated UI reads are safe.
now=5000
local legacy,lg,lgOrder=Add('Legacy-Realm',31)
local legacyStatus={customerName=lgOrder.customerName,responseID=lgOrder.responseID,requestToken=lg.requestToken,
    requestTime=5000,status='rejected',craftingOrderID=9201,origin='old-peer',rev=1,updatedAt=5100}
F:ApplyRemoteStatus(legacyStatus)
now=5001;assert(A.State(lgOrder,lg)=='done')
now=5002;M.MarkReply(legacy,{body='sent',receivedAt=now})
assert(A.State(lgOrder,lg)=='sent','legacy clock fallback moved forward with UI refreshes')
-- Notice-only GetStatus must retain the clock information used by attention.
now=6000
local ni,nr,no=Add('Notice-Realm',32)
Scan.DB.settings.order_completion_notices.notice={customerName=no.customerName,spellID=123,itemID=321,
    crafterFullName='Crafter-Realm',orderID=9300,updatedAt=6080,clockOffset=-80,origin='notice-peer',
    status='rejected',requestToken=nr.requestToken,requestTime=6000}
nr.recipeID,nr.itemID=123,321
local notice=F:GetStatus(no)
assert(notice and notice.completionNotice and notice.clockOffset==-80 and notice.origin=='notice-peer')
assert(A.State(no,nr)=='done')
now=6001;M.MarkReply(ni,{body='sent',receivedAt=now})
assert(A.State(no,nr)=='sent','notice-only rejection lost its peer clock')
-- Screenshot: one greeting covered two items; "both should be there now"
-- confirms exactly that group, not a separate older item for the same person.
now=7000
local group,gr1,go1=Add('Stormxwin-Realm',40)
local _,gr2,go2=Add('Stormxwin-Realm',41)
local _,grOld,goOld=Add('Stormxwin-Realm',42)
gr2.inquiryID=gr1.inquiryID
M.GreetingSent(group,{gr1,gr2},now)
now=7001;M.MarkReply(group,{body='both should be there now',receivedAt=now})
assert(A.State(go1,gr1)=='sent' and A.State(go2,gr2)=='sent',
    'screenshot both-items confirmation did not turn both greeted rows green')
assert(not grOld.customer_answered and A.State(goOld,grOld)==nil,
    'a both-items confirmation checked another inquiry')
-- Newer manual state/answer changes cannot be undone by a delayed reply.
now=7100;F:SetStatus(go1,'rejected',{craftingOrderID=9400})
now=7105;A.SetState(go1,'waiting')
now=7106;M.MarkReply(group,{body='sent',receivedAt=7102})
assert(A.State(go1,gr1)=='done' and gr1.customerState=='waiting',
    'an older reply reopened attention ahead of a newer manual state')
print('Declined attention passed: new replies, colours, preserved rejection, minute delay, repeated declines, replay, reload, identities, completions and peer clocks.')
