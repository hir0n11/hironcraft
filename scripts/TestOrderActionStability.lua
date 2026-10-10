-- Fast hardware presses, hidden analysis transactions and late server/UI
-- callbacks must not change the order currently being processed.
local function noop() end
SlashCmdList={}
local CO = { rowStates={}, orderIssues={}, selectedOrders={}, useConcentration={} }
local now, timers, claimed, claims, completions, binds = 100, {}, nil, 0, 0, 0
local function frame(shown)
    return {
        shown=shown, IsShown=function(self) return self.shown end,
        Show=function(self) self.shown=true end, Hide=function(self) self.shown=false end,
    }
end
local page = frame(true)
page.orderType=4
page.BrowseFrame=frame(true)
page.OrderView=frame(false)
local sets=0
page.OrderView.SetOrder=function(self, order) self.order=order; sets=sets+1 end
local E = setmetatable({
    CO=CO, PT={}, SlashCmdList={},
    T=function(_, fallback) return fallback end,
    OrderKey=function(id) return id and tostring(id) end,
    SameOrderID=function(a,b) return a~=nil and b~=nil and tostring(a)==tostring(b) end,
    IsOrderCreated=function(order) return order and order.orderState==1 end,
    IsOrderClaimed=function(order) return order and order.orderState==2 end,
    IsResultOk=function(result) return result==0 end,
    GetProfessionFromPage=function() return 11 end,
    GetTime=function() return now end, UnitGUID=function() return 'player' end,
    SafeCall=function(_, fn) return pcall(fn) end,
    Enum={CraftingOrderType={Npc=4}, CraftingOrderResult={Ok=0}},
    C_Timer={After=function(delay, fn) timers[#timers+1]={at=now+delay, fn=fn} end},
    C_CraftingOrders={
        GetClaimedOrder=function() return claimed end,
        ClaimOrder=function() claims=claims+1 end,
        FulfillOrder=function() completions=completions+1 end,
        ReleaseOrder=noop,
    },
    CreateFrame=function() return {RegisterEvent=noop, SetScript=noop} end,
    wipe=function(t) for k in pairs(t) do t[k]=nil end end,
}, {__index=_G})
HironCraftProfitCraftingOrdersEnv=E
dofile('Workflow/Orders/CraftingOrders/QualityReagents.lua')
dofile('Workflow/Orders/CraftingOrders/QueueShopping.lua')
dofile('Workflow/Orders/CraftingOrders/Actions.lua')
CO.CreateHotkeyProxy, CO.HookBlizzardProfessions, CO.ApplyEnabledState=noop,noop,noop
dofile('Workflow/Orders/CraftingOrders/HooksEvents.lua')
CO.activePageFrame=page
CO.IsEnabled=function() return true end
CO.FindOrderPageFrame=function(_, candidate) return candidate or page end
CO.GetRecipeKnownState=function() return true end
CO.IsAtUsableCraftingOrderTable=function() return true end
CO.ShouldRejectForMissingCustomerReagents=function() return false end
CO.IsOrderReadyForQualityRejection=function() return false end
CO.OrderRequiresConcentrationForQueue=function() return false end
CO.IsOrderSelected=function(self,id) return self.selectedOrders[tostring(id)]==true end
CO.SetStatus=function(_,value) CO.lastStatus=value end
CO.SetActiveRowButton=function(_,btn) binds=binds+1; CO.activeOrderID=btn.orderID end
CO.HasSelectedOrders=function() return next(CO.selectedOrders)~=nil end
for _,name in ipairs({'InvalidateOrderCaches','RefreshVisibleRows','RefreshVisibleRowsSoon',
    'UpdateControlPanel','UpdateControlPanelVisibility','RefreshPageSoon',
    'DiagnoseRowAction','RefreshHoveredRowButtonTooltip','EnsurePageBindingHooks',
    'EnsureControlPanel','ApplySelectedReagentsToEngine','SetEngineConcentration'}) do CO[name]=noop end
CO.StopRowProgress=function() CO.progressActive=nil; CO.progressOrderID=nil end
local a={orderID=101,spellID=901,orderState=1,orderType=4}
local b={orderID=102,spellID=902,orderState=1,orderType=4}
local buttons={}
for index,order in ipairs({a,b}) do
    local btn={orderID=order.orderID,order=order,pageFrame=page,
        IsShown=function() return page.BrowseFrame:IsShown() end,
        GetTop=function() return 1000-index*30 end}
    buttons[tostring(order.orderID)]=btn
    CO.selectedOrders[tostring(order.orderID)]=true
end
CO.visibleRowButtons={[buttons['101']]=true,[buttons['102']]=true}
CO.GetVisibleButtonForOrder=function(_,id) return buttons[tostring(id)] end
local function advance(delta)
    local untilTime=now+delta
    while true do
        table.sort(timers,function(x,y) return x.at<y.at end)
        if not timers[1] or timers[1].at>untilTime then break end
        local timer=table.remove(timers,1); now=timer.at; timer.fn()
    end
    now=untilTime
end

-- Neither the same row nor another row may rebind / submit a duplicate while
-- the authoritative claimed order has not arrived.
CO:RunRowButtonAction(buttons['101'])
assert(claims==1 and CO.pendingClaimOrderID==101)
local before=binds
CO:RunRowButtonAction(buttons['101'])
CO:RunRowButtonAction(buttons['102'])
assert(claims==1 and binds==before, 'pending claim allowed a duplicate/target change')
assert(not CO:ClaimOrder(b,page) and claims==1, 'direct claim bypassed the pending guard')

-- An automatic Blizzard view opening during a list action must not strand
-- the hotkey on an unrelated prepared order. This does not submit an action.
page.BrowseFrame:Hide(); page.OrderView:Show(); page.OrderView.order=b
assert(CO:RestoreListActionView(page), 'list action did not recover its browse view')
assert(page.BrowseFrame:IsShown() and not page.OrderView:IsShown())
assert(claims==1 and completions==0, 'view recovery submitted a protected action')

claimed={orderID=101,spellID=901,orderState=2,orderType=4,isFulfillable=true}
CO:OnEvent('CRAFTINGORDERS_CLAIMED_ORDER_ADDED')
assert(not CO.pendingClaimOrderID)
-- Analysis must not replace a claimed transaction, even when called directly
-- by concentration revalidation rather than the background warming runner.
page.OrderView.order=claimed
local previousSets=sets
assert(not CO:PrepareOrderForQueueAnalysis(b,page))
assert(sets==previousSets and page.OrderView.order==claimed, 'analysis replaced the live claim')
CO:RunRowButtonAction(buttons['101'])
assert(completions==1 and CO.pendingFulfillOrderID==101)
before=binds
CO:RunRowButtonAction(buttons['102'])
assert(binds==before and completions==1, 'pending fulfillment changed the target')
assert(not CO:FulfillOrder(b,page), 'direct fulfillment accepted another order')

-- Success can precede removal. Keep the transition locked until its removal
-- event; a stale claimed snapshot must never resurrect the completed row.
CO:OnEvent('CRAFTINGORDERS_FULFILL_ORDER_RESPONSE',0,101)
CO:RunRowButtonAction(buttons['102'])
assert(claims==1, 'next order was claimed before completion removal')
claimed=nil
CO:OnEvent('CRAFTINGORDERS_CLAIMED_ORDER_REMOVED')
CO:RunRowButtonAction(buttons['102'])
assert(claims==2 and CO.pendingClaimOrderID==102, 'next hardware press could not advance')
-- Removal before response must not unlock the next order prematurely either.
claimed={orderID=102,spellID=902,orderState=2,orderType=4,isFulfillable=true}
CO:OnEvent('CRAFTINGORDERS_CLAIMED_ORDER_ADDED')
assert(CO:FulfillOrder(claimed,page))
claimed=nil
CO:OnEvent('CRAFTINGORDERS_CLAIMED_ORDER_REMOVED')
assert(CO:IsOrderActionInProgress(), 'removal unlocked before fulfillment response')
CO:OnEvent('CRAFTINGORDERS_FULFILL_ORDER_RESPONSE',0,102)
assert(not CO:IsOrderActionInProgress())

-- A preparation cache refers to the actual live engine binding, not just to
-- an order which happened to be analyzed earlier in this session.
CO.rowStates={}; CO.craftedOrderID=nil; CO.currentQueueOrderID=nil
assert(CO:PrepareOrderForQueueAnalysis(a,page))
assert(CO:PrepareOrderForQueueAnalysis(b,page))
previousSets=sets
assert(CO:PrepareOrderForQueueAnalysis(a,page))
assert(page.OrderView.order==a and sets==previousSets+1, 'stale preparation reused another transaction')
previousSets=sets
assert(CO:PrepareOrderForQueueAnalysis(a,page) and sets==previousSets, 'same transaction rebuilt unnecessarily')
-- Explicit inspection is owned by the user, not by the list workflow.
CO.listActionContext=nil
page.BrowseFrame:Hide(); page.OrderView:Show()
assert(not CO:RestoreListActionView(page) and page.OrderView:IsShown())
page.BrowseFrame:Show(); page.OrderView:Hide()
-- Late cast-stop timers must not cancel a newer craft/progress indicator.
CO.pendingCraftOrderID=101; CO.pendingCraftSpellID=901; CO._craftWatchToken=10
CO:OnEvent('UNIT_SPELLCAST_STOP','player',nil,901)
CO:OnEvent('UPDATE_TRADESKILL_CAST_STOPPED')
CO.pendingCraftOrderID=102; CO.pendingCraftSpellID=902; CO._craftWatchToken=11
CO.progressOrderID=102; CO.progressActive=true
advance(0.3)
assert(CO.pendingCraftOrderID==102 and CO.progressOrderID==102 and CO.progressActive,
    'late cast-stop callback stopped a newer craft')
CO:OnEvent('CRAFTINGORDERS_CLAIMED_ORDER_REMOVED')
assert(CO.pendingCraftOrderID==102 and CO.progressOrderID==102,
    'duplicate removal stopped a newer craft')
assert(not CO:CraftOrderFromRow(a,page,buttons['101']), 'direct craft bypassed a pending submission')
-- A failed release has no removal event. It must unlock an explicit retry.
CO.pendingCraftOrderID=nil; CO.progressOrderID=nil; CO.progressActive=nil
claimed={orderID=102,spellID=902,orderState=2,orderType=4}
assert(CO:ReleaseOrder(claimed,page))
assert(not CO:ReleaseOrder(claimed,page), 'duplicate release reached the API')
CO:OnEvent('CRAFTINGORDERS_RELEASE_ORDER_RESPONSE',1,102)
assert(not CO.pendingReleaseOrderID and not CO:IsOrderSubmissionPending(), 'failed release left the workflow locked')
claimed=nil
-- Scope/close changes invalidate delayed view restoration.
CO.pendingCraftOrderID=nil; CO.progressActive=nil
CO:BeginListAction(page)
page.orderType=3; page.BrowseFrame:Hide(); page.OrderView:Show()
assert(not CO:RestoreListActionView(page) and page.OrderView:IsShown())
print('Order action stability passed: fast presses, both terminal event orders, view ownership, analysis cache and stale timers.')
