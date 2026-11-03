-- Exercise real attention and page cleanup through the normal page/timer
-- entry points. Only the WoW UI boundary is mocked; saved history is untouched.
local function noop() end
local now=10000
time=function() return now end
local loaded,timers={},{}
local Scan={DB={settings={customer_timeout=10,my_uuid='local'},customers={},listed_orders={}},
    Utils={onLoad=function(fn) loaded[#loaded+1]=fn end,FitsScreen=function() return true end,
        ChatHistoryTooltip={new=function() return {} end}},
    CONST={TEXT=setmetatable({},{__index=function(_,s) return s end}),PROFESSIONS={}},
    State={},Frames={},LOCAL={GetText=function(_,s) return s end}}
Scan.Utils.GetSetting=function(key) return Scan.DB.settings[key] end
Scan.OrderToCustomerInfo=function(o) return Scan.DB.customers[o.customerName] end
Scan.OrderToResponse=function(o)
    local info=Scan.OrderToCustomerInfo(o)
    return info and info.responses[o.responseID]
end
Scan.OrderToOrderID=function(o) return o.customerName..':'..o.responseID end
Scan.IsHiddenOtherSideOrder=function() return false end
local status={}
Scan.OrderFulfillment={GetStatus=function(_,o) return status[Scan.OrderToOrderID(o)] end}
CreateFromMixins=function() return {} end
C_Timer={After=function(delay,fn)
    if delay==0 then fn() else timers[#timers+1]={at=now+delay,fn=fn} end
end}
SortUtil={CompareNumeric=function(a,b) return a==b and 0 or a<b and -1 or 1 end}
ScrollUtil={AddManagedScrollBarVisibilityBehavior=noop}
ScrollBoxConstants={RetainScrollPosition=true}
CreateDataProvider=function() return {Insert=noop} end
UISpecialFrames,UIPanelWindows,StaticPopupDialogs={},{},{}
ProfessionsFrame={HookScript=noop}
local button={Init=noop,SetButtonText=noop}
local results={Show=noop,Hide=noop,SetText=noop}
local scroll={Show=noop,SetDataProvider=noop,IsShown=function() return false end}
local page={EnableMouse=noop,IsShown=function() return false end,
    BrowseFrame={AddonToggleButton=button,CustomExplanationsButton=button,
        HoldStingyCheckButton=button,QuietGreetingsCheckButton=button,
        LeftPanel={LinkedAccountList=button},OrderList={ScrollBox=scroll,ResultsText=results}}}
HironCraftScanCraftingOrderPage=page
assert(loadfile('Customer/RequestTracking.lua'))('HironCraft',Scan)
assert(loadfile('Customer/CustomerAttention.lua'))('HironCraft',Scan)
assert(loadfile('Customer/OrderPage.lua'))('HironCraft',Scan)
local A,M=Scan.CustomerAttention,Scan.RequestTracking
setmetatable(page,{__index=HironCraftScanCraftingOrderPageMixin})
Scan.ChatOrderSortOrder={Time='time',ItemName='item',CustomerName='customer',CrafterName='crafter',ProfessionName='profession'}
page.primarySort={order='time',ascending=true}
local function Add(name,id,at,answered,state)
    local info=Scan.DB.customers[name] or {responses={},chat_history={'history'}}
    Scan.DB.customers[name]=info
    local r={responseID=id,requestToken=name..id,time=at,customer_answered=answered,
        greeting_sent=true,greetingSentAt=at,inquiryID=name..id,
        firstAnsweredAt=answered and at or nil,customerState=state}
    info.responses[id]=r
    info.activeInquiryID,info.activeInquiryAt=r.inquiryID,at
    local o={customerName=name,responseID=id}
    Scan.DB.listed_orders[Scan.OrderToOrderID(o)]=o
    return info,r,o
end
local yi,yr,yo=Add('Yellow',1,now,true,'attention')
local _,gr,go=Add('Green',1,now,true,'sent')
local _,qr,qo=Add('Quiet',1,now,true,'waiting')
assert(A.Acknowledge(qo) and qr.customer_answered)
local _,ur,uo=Add('Unanswered',1,now,false)
local _,tr,to=Add('Completed',1,now,true,'sent')
status[Scan.OrderToOrderID(to)]={status='fulfilled'}
for _,fn in ipairs(loaded) do fn() end
assert(#timers==1,'login did not start one cleanup timer before opening the scanner')
now=10601
page:ShowGeneric()
assert(not Scan.OrderToResponse(uo) and not Scan.OrderToResponse(to),
    'unanswered or completed rows bypassed the ordinary timeout')
assert(Scan.OrderToResponse(yo)==yr and Scan.OrderToResponse(go)==gr and Scan.OrderToResponse(qo)==qr,
    'answered rows expired at the ordinary short timeout')
assert(#timers==1,'opening/refreshing the page duplicated the cleanup timer')
assert(A.KeepAlive(yo,yr) and A.KeepAlive(go,gr) and A.KeepAlive(qo,qr))
-- Every kind of activity just before expiry must preserve the original cap.
now=13599
M.MarkReply(yi,{body='hello again',receivedAt=now,syncID='latest-message'})
A.Outgoing('Yellow')
A.SetState(go,'sent')
A.Snooze(go)
assert(A.KeepAlive(yo,yr) and A.KeepAlive(go,gr) and A.KeepAlive(qo,qr))
assert(yr.time==10000 and gr.time==10000 and qr.time==10000)
-- A longer generic timeout cannot override the hard cap, but still applies
-- to unanswered rows. Another request by the same customer must survive.
Scan.DB.settings.customer_timeout=120
local _,long,lo=Add('LongUnanswered',1,10000,false)
local _,fresh,fo=Add('Yellow',2,now,true,'attention')
yr.less_granular={164};yi.responses[164]=yr
Scan.State.activeOrder=yo
-- Reload retains original ages and explicit manual acknowledgement.
assert(loadfile('Customer/CustomerAttention.lua'))('HironCraft',Scan)
A=Scan.CustomerAttention
assert(A.State(qo,qr)=='quiet' and A.KeepAlive(qo,qr))
now=13600
for _,pair in ipairs({{yo,yr},{go,gr},{qo,qr}}) do
    assert(A.IsExpired(pair[2]) and not A.KeepAlive(pair[1],pair[2])
        and not A.NeedsAttention(pair[1],pair[2]),'a checked row bypassed its exact hour boundary')
end
assert(A.Collect(now)==0,'an expired row reminded before page cleanup ran')
local timer=table.remove(timers,1)
assert(timer.at<=now)
timer.fn() -- hidden scanner, reminders disabled, no UI opening required
assert(not Scan.OrderToResponse(yo) and not Scan.OrderToResponse(go) and not Scan.OrderToResponse(qo),
    'hidden-page cleanup retained an expired answered row')
assert(not yi.responses[164] and not Scan.State.activeOrder,'expiry left a stale alias/active order')
assert(Scan.OrderToResponse(fo)==fresh and yi.chat_history[1]=='history',
    'expiry deleted a different request or its shared chat history')
assert(Scan.OrderToResponse(lo)==long,'the answered-row cap affected an unanswered row')
assert(#timers==1,'expiry stopped or duplicated the existing cleanup chain')
assert(A.Collect(now+59)==1,'fresh replacement did not receive its normal minute grace')
-- Corrupted saved times cannot create another immortal answered row.
for _,bad in ipairs({0/0,math.huge,-math.huge}) do
    assert(A.IsExpired({customer_answered=true,time=bad}))
end
assert(A.IsExpired({customer_answered=true}) and not A.IsExpired({time=1}))
print('Customer expiry passed: ordinary timeout, all colours, manual quiet, exact hour, recent chat/snooze, hidden cleanup, disabled reminders, reload, aliases and independent newer requests.')
