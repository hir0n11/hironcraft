-- Reproduce the first-open race: Personal retries must yield to a manual tab.
if not setfenv then
    function setfenv(fn, env)
        if type(fn) == 'number' then fn = debug.getinfo(fn + 1, 'f').func end
        for i = 1, 100 do
            local name = debug.getupvalue(fn, i)
            if not name then break end
            if name == '_ENV' then
                debug.upvaluejoin(fn, i, function() return env end, 1)
                break
            end
        end
        return fn
    end
end
local function noop() end
local CO, timers, events = {}, {}, {}
local now, personalClicks, selected, searches = 0, 0, 0, 0
local orders = {}
local types = {Public=1, Guild=2, Personal=3, Npc=4}
local page = {
    shown=true, orderType=types.Public,
    IsShown=function(self) return self.shown end,
    IsVisible=function(self) return self.shown end,
    SetCraftingOrderType=function(self, value) self.orderType=value end,
    StartDefaultSearch=function() searches=searches+1 end,
    ClearCachedRequests=noop,
    ShowGeneric=noop,
    BrowseFrame={},
}
page.BrowseFrame.PersonalOrdersButton={Click=function()
    personalClicks=personalClicks+1
    page:SetCraftingOrderType(types.Personal)
    page:StartDefaultSearch()
end}
ProfessionsFrame={
    OrdersPage=page, craftingOrdersTabID=3,
    IsShown=function() return true end,
    SetTab=function()
        page.shown=true
        -- Initial Blizzard page setup is programmatic, not a user choice.
        page:SetCraftingOrderType(types.Public)
    end,
}
local E=setmetatable({
    PT={}, CO=CO, Enum={CraftingOrderType=types},
    GetTime=function() return now end,
    T=function(_, fallback) return fallback end,
    C_CraftingOrders={GetCrafterOrders=function() return orders end},
    C_Timer={After=function(delay, callback) timers[#timers+1]={delay=delay,callback=callback} end},
    CreateFrame=function()
        return {RegisterEvent=noop, SetScript=function(_, event, callback) events[event]=callback end}
    end,
    hooksecurefunc=function(target, key, callback)
        local original=target[key]
        target[key]=function(...)
            local result=original(...)
            callback(...)
            return result
        end
    end,
}, {__index=_G})
HironCraftProfitCraftingOrdersEnv=E
CO.IsEnabled=function() return true end
CO.IsAutoQueueOnOpen=function() return true end
CO.ClearSelectedOrders=noop
CO.SetStatus=noop
CO.EnsurePageBindingHooks=noop
CO.EnsureControlPanel=noop
CO.UpdateControlPanelVisibility=noop
CO.UpdateControlPanel=noop
CO.ApplyTemporaryBinding=noop
CO.SelectAllVisibleOrders=function() selected=selected+1 end
dofile('ProfitHub/Orders/CraftingOrders/OneButton.lua')

local function tick()
    local timer=table.remove(timers,1)
    assert(timer, 'missing retry')
    now=now+(timer.delay or 0)
    timer.callback()
end
local function drainCancelled()
    local count=0
    while #timers>0 do count=count+1; assert(count<20,'startup kept rescheduling'); tick() end
end
local function reopen()
    CO:CancelOneButtonPersonalFlow(true)
    timers={}
    page.shown=true
    page.orderType=types.Public
    CO:BeginOneButtonPersonalFlow()
end

for _, chosenType in ipairs({types.Npc,types.Guild,types.Public}) do
    reopen()
    tick()
    assert(page.orderType==types.Personal and CO._oneButtonFlowRunning, 'auto Personal startup failed')
    local opened=personalClicks
    page:SetCraftingOrderType(chosenType)
    assert(not CO._oneButtonFlowRunning and CO._oneButtonPreparedForOpen, 'manual tab did not cancel startup')
    drainCancelled()
    events.OnEvent(nil,'CRAFTINGORDERS_UPDATE_ORDER_COUNT')
    CO:BeginOneButtonPersonalFlow()
    assert(page.orderType==chosenType and personalClicks==opened and #timers==0,
        'late event or restart switched back to Personal')
end

-- A click before the very first scheduled step must also win.
reopen()
local opened=personalClicks
page:SetCraftingOrderType(types.Npc)
drainCancelled()
assert(personalClicks==opened and page.orderType==types.Npc,'first timer overrode an early Patron click')

-- Defensive check when another caller changes orderType without the hook.
reopen()
tick()
opened=personalClicks
page.orderType=types.Npc
tick()
drainCancelled()
assert(personalClicks==opened and page.orderType==types.Npc,'retry ignored changed order type')

-- A pending empty-Personal refresh must yield too.
CO._oneButtonEmptyRefreshRunning=true
CO._oneButtonEmptyRefreshToken=50
page:SetCraftingOrderType(types.Guild)
assert(not CO._oneButtonEmptyRefreshRunning and CO._oneButtonEmptyRefreshToken==51)

-- Normal auto-opening and selecting Personal still works next time.
reopen()
page.shown=false
orders={{orderID=1001,orderType=types.Personal}}
tick()
assert(page.orderType==types.Personal and selected==1 and not CO._oneButtonFlowRunning,
    'manual choice permanently disabled the next automatic opening')
assert(CO:IsAutoQueueOnOpen(),'manual tab changed the saved auto-open setting')

print('Manual order-tab tests passed.')
