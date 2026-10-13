local now,timers,owner,child=100,{},'Player-A',1001
local function noop() end
local CO={}
HironCraftProfit={CraftingOrders=CO}
SlashCmdList={}
Enum={CraftingOrderResult={Ok=0}}
GetTime=function() return now end
UnitGUID=function() return owner end
CreateFrame=function() return {RegisterEvent=noop,SetScript=noop} end
C_Timer={After=function(delay,fn) timers[#timers+1]={at=now+delay,fn=fn} end}
C_FunctionContainers={CreateCallback=function(fn)
    -- WoW containers are userdata, not callable tables or Lua functions.
    local container, cancelled = newproxy(true), false
    getmetatable(container).__index = {
        Cancel=function() cancelled=true end,
        IsCancelled=function() return cancelled end,
        Invoke=function(_,...) if not cancelled then fn(...) end end,
    }
    return container
end}
C_TradeSkillUI={GetProfessionChildSkillLineID=function() return child end}
CO.IsEnabled=function() return true end
CO.SetStatus=noop
CO.GetSelectedProfessionExpansionKey=function() return 'tww' end
dofile('Workflow/Orders/CraftingOrders/CustomList.lua')
local CL=CO.CustomList
CL.Refresh=noop
local page={orderType=4,professionInfo={profession=1},IsShown=function() return true end}
CO.activePageFrame=page
page.lastRequest={orderType=4,profession=1}
local source={orderID=1,reagents={{quantity=20,reagent={itemID=101}}}}
CL:AcceptScopeAnswer(page,{source},0)
source.reagents[1].quantity=999;source.reagents[1].reagent.itemID=888
assert(CL:GetOrders(page)[1].reagents[1].quantity==20 and CL:GetOrders(page)[1].reagents[1].reagent.itemID==101)
CL:AcceptScopeAnswer(page,{{orderID='1',reagents={{quantity=21}}}},1)
assert(#CL:GetOrders(page)==1 and CL:GetOrders(page)[1].reagents[1].quantity==21, 'duplicate ID was appended or stale data retained')
local accepted=0
local function request()
    local query={callback=C_FunctionContainers.CreateCallback(function() accepted=accepted+1 end)}
    page.requestCallback=query.callback
    CL:GuardOrderRequest(page,query)
    return query.callback
end
local old=request();local current=request()
old:Invoke(0)
assert(accepted==0 and page.ahuiOrderRequestPending, 'old same-scope request released the current search')
current:Invoke(0);current:Invoke(0)
assert(accepted==1 and not page.ahuiOrderRequestPending, 'duplicate callback republished a list')
old=request();CL:ClearScope(page);old:Invoke(0)
assert(accepted==1, 'cancelled request was accepted')
-- A change of tab or profession ends here too: the patron list is asked to
-- step aside, not dropped outright (it stays while an order is claimed).
local suspended,cancelled=0,0
CO.SuspendCombinedPatronLoad=function() suspended=suspended+1 end
CO.CancelCombinedPatronLoad=function() cancelled=cancelled+1 end
CL:ClearScope(page)
assert(suspended==1 and cancelled==0, 'clearing a scope dropped the patron list of a claimed order')
CO.SuspendCombinedPatronLoad,CO.CancelCombinedPatronLoad=nil,nil
old=request();owner='Player-B';old:Invoke(0)
assert(accepted==1, 'old character request was accepted')
owner='Player-A';old=request();child=1002;old:Invoke(0)
assert(accepted==1, 'old child-profession request was accepted')
child=1001
page.ahuiCustomList={_freshSearchPending=true}
old=request()
now=111
for _,timer in ipairs(timers) do if timer.at<=now then timer.fn() end end
assert(not page.ahuiOrderRequestPending and not page.ahuiCustomList._freshSearchPending)
assert(#CL:GetOrders(page)==0 and accepted==1, 'timeout published the stale game buffer')
old:Invoke(0);assert(accepted==1, 'timed-out request published a late answer')
print('Order request snapshots passed: deep copies, updated duplicate IDs, per-request generation, character/child isolation, failure and timeout.')

-- Integrate the guarded native callback with the actual fresh-search hooks.
-- A callback is never invoked through __call: this reproduces the spinner
-- regression that a callable-table mock previously hid.
Enum.CraftingOrderType={Public=1,Personal=3}
HironCraftProfitCraftingOrdersEnv=setmetatable({PT=HironCraftProfit,CO=CO},{__index=_G})
hooksecurefunc=function(target,key,hook)
    local original=target[key]
    target[key]=function(...) original(...);hook(...) end
end
local spinning, buffer, query, localSearch, callbackError = false, {}, nil, false, nil
page.BrowseFrame={OrderList={LoadingSpinner={Hide=function() spinning=false end}}}
page.orderType=3
page.ClearCachedRequests=function(self) self.lastRequest=nil end
page.ShowGeneric=function(self,orders,_,offset)
    spinning=false
    CL:AcceptScopeAnswer(self,orders,offset)
end
page.OrderRequestCallback=function(self,result,responseType,buckets,more,offset)
    assert(responseType==self.orderType)
    self:ShowGeneric(buffer,nil,offset)
    self.requestCallback=nil
end
page.StartDefaultSearch=function(self)
    if localSearch then spinning=false;return end
    spinning=true
    query={orderType=self.orderType,profession=1,offset=0}
    self.lastRequest=query
    self.requestCallback=C_FunctionContainers.CreateCallback(function(...) self:OrderRequestCallback(...) end)
    query.callback=self.requestCallback
    CL:GuardOrderRequest(self,query)
end
ProfessionsFrame={OrdersPage=page}
dofile('Workflow/Orders/CraftingOrders/OneButton.lua')
local function start(rows)
    buffer=rows
    page:StartDefaultSearch()
    assert(spinning and page.ahuiOrderRequestPending and page.ahuiCustomList._freshSearchPending)
end
start({})
query.callback:Invoke(0,3,false,false,0)
assert(not spinning and not page.ahuiOrderRequestPending and not page.ahuiCustomList._freshSearchPending)
assert(#CL:GetOrders(page)==0)
start({{orderID=77,orderType=3,reagents={{quantity=20}}}})
query.callback:Invoke(0,3,false,false,0)
assert(#CL:GetOrders(page)==1 and CL:GetOrders(page)[1].orderID==77 and not spinning,
    'accepted Personal order stayed invisible or spinning')
start({})
query.callback:Invoke(0,4,false,false,0)
assert(spinning and page.ahuiOrderRequestPending, 'wrong-tab response released the current request')
query.callback:Invoke(7,3,false,false,0)
assert(not spinning and not page.ahuiOrderRequestPending and not page.ahuiCustomList._freshSearchPending)
start({})
now=now+11
for _,timer in ipairs(timers) do if timer.at<=now then timer.fn() end end
assert(not spinning and not page.ahuiOrderRequestPending and not page.ahuiCustomList._freshSearchPending,
    'timed-out request left the spinner or action lock behind')
geterrorhandler=function() return function(err) callbackError=err end end
local original=page.OrderRequestCallback
page.OrderRequestCallback=function() error('test native UI error') end
start({})
query.callback:Invoke(0,3,false,false,0)
assert(callbackError and not spinning and not page.ahuiCustomList._freshSearchPending,
    'native display error was swallowed or left the list locked')
page.OrderRequestCallback=original
localSearch=true;page.orderType=1;CL:ClearScope(page)
page:StartDefaultSearch()
assert(not spinning and not page.ahuiCustomList._freshSearchPending,
    'Public without favourites left a lock with no request')
print('Order loading passed: native userdata callbacks, empty/nonempty Personal answers, wrong-tab answers, errors, timeouts and no-request Public search.')

localSearch=false;page.orderType=3;page.ahuiRequestedScope=nil
local stale={}
for i=1,200 do
    start({{orderID=i,orderType=3}})
    local active=query.callback
    for _,previous in ipairs(stale) do previous:Invoke(0,3,false,false,0) end
    assert(spinning and page.ahuiOrderRequestPending, 'stale callback unlocked an unanswered fresh search')
    active:Invoke(0,3,false,false,0)
    active:Invoke(0,3,false,false,0)
    assert(not spinning and not page.ahuiCustomList._freshSearchPending and CL:GetOrders(page)[1].orderID==i)
    stale[#stale+1]=active
end
now=now+11
for _,timer in ipairs(timers) do if timer.at<=now then timer.fn() end end
assert(not spinning and CL:GetOrders(page)[1].orderID==200, 'old timeout cleared the newest completed list')
print('Order loading stress passed: 200 generations and over 20,000 repeated/stale callbacks.')
