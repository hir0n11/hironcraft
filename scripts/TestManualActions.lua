-- Real action functions against mocked APIs: events may update state, but
-- must not send player chat, confirm a purchase or chain an order decline.
local function noop() end
if not setfenv then
    function setfenv(fn, env)
        if type(fn)=='number' then fn=debug.getinfo(fn+1,'f').func end
        for i=1,100 do
            local name=debug.getupvalue(fn,i)
            if not name then return fn end
            if name=='_ENV' then
                debug.upvaluejoin(fn,i,function() return env end,1)
                return fn
            end
        end
    end
end

local now, started, confirmed, cancelled = 100, 0, 0, 0
local eventHandler
local S={RefreshSellUI=noop}
local E=setmetatable({PT={},S=S,GetTime=function() return now end,
    T=function(_,fallback) return fallback end,
    CreateFrame=function() return {RegisterEvent=noop,SetScript=function(_,_,fn) eventHandler=fn end} end,
    C_Timer={After=noop},
    C_AuctionHouse={
        StartCommoditiesPurchase=function() started=started+1 end,
        ConfirmCommoditiesPurchase=function() confirmed=confirmed+1 end,
        CancelCommoditiesPurchase=function() cancelled=cancelled+1 end,
    },
},{__index=_G})
HironCraftProfitShoppingListEnv=E
dofile('ProfitHub/Shop/Core/ShoppingList_Selling.lua')
S.isAuctionHouseOpen=true
S.sell.selected={itemID=1001,isCommodity=true,itemName='Reagent'}
local tier={price=100,qty=4}
S:BuySellTier(tier)
assert(started==1 and confirmed==0)
S:BuySellTier(tier)
assert(started==1 and confirmed==0, 'second click before price response submitted a purchase')
eventHandler(nil,'COMMODITY_PRICE_UPDATED',100,400)
assert(confirmed==0 and S.sell.pendingBuy.ready, 'price event confirmed without a click')
S:BuySellTier({price=200,qty=4})
assert(confirmed==0, 'a different tier confirmed the pending purchase')
S:BuySellTier(tier)
assert(confirmed==1 and S.sell.pendingBuy.confirming)
S:BuySellTier(tier)
eventHandler(nil,'COMMODITY_PRICE_UPDATED',100,400)
assert(confirmed==1, 'repeat click/event submitted a duplicate confirmation')
eventHandler(nil,'COMMODITY_PURCHASE_FAILED')
S:BuySellTier(tier)
eventHandler(nil,'COMMODITY_PRICE_UPDATED',200,800)
assert(cancelled==1 and not S.sell.pendingBuy and confirmed==1, 'price increase was silently accepted')
S:BuySellTier(tier)
eventHandler(nil,'COMMODITY_PRICE_UPDATED',100,400)
now=now+11
S:BuySellTier(tier)
assert(cancelled==2 and not S.sell.pendingBuy and confirmed==1, 'expired quote was confirmed')
S:BuySellTier(tier)
now=now+11
eventHandler(nil,'COMMODITY_PRICE_UPDATED',100,400)
assert(cancelled==3 and not S.sell.pendingBuy and confirmed==1, 'late quote enabled a purchase')
S:BuySellTier(tier)
eventHandler(nil,'AUCTION_HOUSE_CLOSED')
assert(not S.sell.pendingBuy)

-- Exercise the real bank helpers with old enabled settings. Walk closure
-- upvalues instead of constructing unrelated bank-window widgets.
local function findHelper(fn, wanted, seen)
    seen=seen or {}; if seen[fn] then return end; seen[fn]=true
    local nested={}
    for i=1,200 do
        local name,value=debug.getupvalue(fn,i)
        if not name then break end
        if name==wanted then return value end
        if type(value)=='function' then nested[#nested+1]=value end
    end
    for _,child in ipairs(nested) do
        local found=findHelper(child,wanted,seen); if found then return found end
    end
end
local bankFrames, bankTimers, bankActions = {}, {}, 0
local GE=setmetatable({HironCraftProfit={config={_forceEnableGoldDepositorV2=true}},
    HironCraftProfit_DB={goldDepositor={autoDepositGuild=true,autoDepositAccount=true}},
    CreateFrame=function()
        local f={RegisterEvent=noop, SetScript=function(self,key,fn) self[key]=fn end}
        bankFrames[#bankFrames+1]=f; return f
    end,
    C_Timer={After=function(_,fn) bankTimers[#bankTimers+1]=fn end},
    DepositGuildBankMoney=function() bankActions=bankActions+1 end,
    GetTime=function() return now end,
    UnitName=function() return 'Crafter' end, GetRealmName=function() return 'Realm' end,
},{__index=_G})
SlashCmdList={}
local bankModule=assert(loadfile('ProfitHub/GoldDeposit/GoldDepositor.lua'))
setfenv(bankModule,GE); bankModule('HironCraft')
local GD=GE.HironCraftProfit.GoldDepositor
local isAuto=assert(findHelper(GD.HandleCommand,'IsAutoDepositEnabled'))
local queueAuto=assert(findHelper(bankFrames[1].OnEvent,'QueueAutoDeposit'))
for _,bank in ipairs({'guild','account'}) do
    assert(isAuto(bank)==false, 'old settings enabled bank automation')
    queueAuto(bank)
end
assert(bankActions==0 and #bankTimers==0, 'bank event scheduled a transfer')

local CO={rowStates={},orderIssues={},selectedOrders={}}
local claimed, quality, missing = nil, false, true
local released, rejected, timers = 0,0,{}
local page={}
local order={orderID=7001,orderState='created'}
local OE=setmetatable({PT={},CO=CO,T=function(_,fallback) return fallback end,
    OrderKey=function(id) return id and tostring(id) end,
    SameOrderID=function(a,b) return a and b and tostring(a)==tostring(b) end,
    GetTime=function() return now end,
    GetProfessionFromPage=function() return 164 end,
    IsOrderCreated=function(o) return o and o.orderState=='created' end,
    IsOrderClaimed=function(o) return o and o.orderState=='claimed' end,
    SafeCall=function(_,fn) return pcall(fn) end,
    C_CraftingOrders={ReleaseOrder=function() released=released+1 end,RejectOrder=function() rejected=rejected+1 end},
    C_Timer={After=function(_,fn) timers[#timers+1]=fn end},
    CreateFrame=function() return {RegisterEvent=noop,SetScript=noop} end,
},{__index=_G})
HironCraftProfitCraftingOrdersEnv=OE
SlashCmdList={}
dofile('ProfitHub/Orders/CraftingOrders/QualityReagents.lua')
dofile('ProfitHub/Orders/CraftingOrders/Actions.lua')
CO.CreateHotkeyProxy=noop; CO.HookBlizzardProfessions=noop; CO.ApplyEnabledState=noop
dofile('ProfitHub/Orders/CraftingOrders/HooksEvents.lua')

CO.FindOrderPageFrame=function() return page end
CO.GetClaimedOrder=function() return claimed end
CO.GetEffectiveOrder=function() return order end
CO.GetRecipeKnownState=function() return true end
CO.IsAtUsableCraftingOrderTable=function() return true end
CO.IsPersonalCraftingOrder=function() return true end
OE.GetProfessionFromPage=function() return 164 end
CO.ShouldRejectForMissingCustomerReagents=function() return missing end
CO.IsOrderReadyForQualityRejection=function() return quality end
CO.ClearOrderQualityRejection=function() quality=false end
CO.InvalidateOrderCaches=noop; CO.RefreshVisibleRows=noop; CO.RefreshVisibleRowsSoon=noop
CO.StopRowProgress=noop; CO.UpdateControlPanel=noop; CO.RefreshPageSoon=noop
CO.SetStatus=function(_,text) CO.lastStatus=text end
CO.SetActiveRowButton=noop
CO.HasSelectedOrders=function() return next(CO.selectedOrders)~=nil end
local row={orderID=7001,order=order,pageFrame=page}
local auditRecordCount=0
HironCraft={CaptureCraftingOrderReagents=function(source,details)
    return {complete=true,orderID=source.orderID,provided=source.provided or 0,reason=details.reason}
end,RecordRejectedCraftingOrder=function(source,reason,audit)
    assert(audit.provided==17 and audit.reason==reason,'pre-release snapshot lost or changed')
    auditRecordCount=auditRecordCount+1
end}
for _,reason in ipairs({'missing_customer_reagents','insufficient_quality'}) do
    claimed={orderID=7001,orderState='claimed',provided=17}
    quality=reason=='insufficient_quality'; missing=not quality
    CO.selectedOrders['7001']=true
    CO.rejectedOrderIDs={}
    local previous=rejected
    assert(CO:RejectOrder(order,page,false,reason), CO.lastStatus)
    assert(rejected==previous and CO.pendingReleaseForReject, 'release also declined the order')
    local pendingAction, _, _, pendingEnabled=CO:GetRowAction(7001,order)
    assert(pendingAction=='pending' and not pendingEnabled, 'release in flight permits duplicate submission')
    claimed=nil
    CO:OnEvent('CRAFTINGORDERS_CLAIMED_ORDER_REMOVED')
    for _,fn in ipairs(timers) do fn() end
    assert(rejected==previous and #timers==0, 'release event scheduled/submitted a decline')
    assert(CO.selectedOrders['7001'], 'release lost the row needed for the next click')
    local action=CO:GetRowAction(7001,order)
    assert(action=='reject', 'next click is not a manual decline')
    CO:RunRowButtonAction(row)
    assert(rejected==previous+1, 'manual decline did not execute exactly once')
end
assert(released==2 and rejected==2)
assert(auditRecordCount==2,'decline failed to record a reagent snapshot')

-- Even a manually requested craft must not send from a later item-cache event.
local comm, whispers, packets, cacheCallbacks, cached = {}, 0, 0, {}, false
local Scan={CONST={TEXT={}}, LOCAL={GetText=function() return 'Please craft %s' end},
    Events={Register=noop}, Utils={onLoad=noop, SendResponses=function(_,_,manual)
        assert(manual==true); whispers=whispers+1; return true
    end}}
local CE=setmetatable({
    LibStub=function() return {NewAddon=function() return comm end} end,
    CreateFramePool=function() return {} end,
    HironCraftScanScannerMenu={RegisterEventCallback=noop},
    GetLocale=function() return 'enUS' end, print=noop,
    UnitGUID=function() return 'Player-1' end,
    Item={CreateFromItemID=function() return {
        GetItemLink=function() return cached and '[Item]' or nil end,
        ContinueOnItemLoad=function(_,fn) cacheCallbacks[#cacheCallbacks+1]=fn end,
    } end},
},{__index=_G})
local commModule=assert(loadfile('Utils/Comm.lua'))
setfenv(commModule,CE); commModule('HironCraft',Scan)
comm.Transmit=function() packets=packets+1 end
local customerModule=assert(loadfile('Customer/CustomerPage.lua'))
setfenv(customerModule,CE); customerModule('HironCraft',Scan)
local crafterRow={info={player='Crafter',itemID=1001}}
assert(comm:RequestCraft('Crafter',1001)==false and #cacheCallbacks==0)
CE.HironCraftScan_FoundCrafterListElementMixin.OnClick(crafterRow,'LeftButton')
assert(whispers==0 and packets==0 and not crafterRow.info.sent and #cacheCallbacks==1)
cached=true
for _,fn in ipairs(cacheCallbacks) do fn() end
assert(whispers==0 and packets==0, 'item-cache event sent chat')
CE.HironCraftScan_FoundCrafterListElementMixin.OnClick(crafterRow,'LeftButton')
assert(whispers==1 and packets==1 and crafterRow.info.sent, 'next click did not send the cached request')

print('Manual action tests passed (auction quotes, bank legacy flags, release/decline, craft-request cache events).')
