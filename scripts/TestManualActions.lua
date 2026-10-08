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
dofile('Workflow/Shop/Core/ShoppingList_Selling.lua')
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
local bankModule=assert(loadfile('Workflow/GoldDeposit/GoldDepositor.lua'))
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
local order={orderID=7001,orderState='created',customerName='Buyer-Realm',spellID=1237543}
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
dofile('Workflow/Orders/CraftingOrders/QualityReagents.lua')
dofile('Workflow/Orders/CraftingOrders/Actions.lua')
local realGetEffectiveOrder=CO.GetEffectiveOrder
CO.CreateHotkeyProxy=noop; CO.HookBlizzardProfessions=noop; CO.ApplyEnabledState=noop
dofile('Workflow/Orders/CraftingOrders/HooksEvents.lua')

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
    return true
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

-- An order with a large tip is not declined by a click: it asks first, and
-- only the answer in the dialog declines. Up to the limit nothing is asked.
do
    local options={}
    CO.GetQueueOptions=function() return options end
    assert(CO:GetRejectConfirmTipCopper()==5000*10000,'the limit is not 5,000 gold unless set')
    local shown
    StaticPopupDialogs={}
    StaticPopup_Show=function(which,text,_,data) shown={which=which,text=text,data=data} end
    local recordRejected=HironCraft.RecordRejectedCraftingOrder
    HironCraft.RecordRejectedCraftingOrder=function() return true end
    local function try(tip)
        -- Released already: the click declines at once.
        claimed=nil
        order.tipAmount=tip
        quality=false; missing=true
        CO.rejectedOrderIDs={}; CO.rejectConfirmedUntil=nil; CO.pendingReleaseForReject=nil
        shown=nil
        local before=rejected
        local result=CO:RejectOrder(order,page)
        return result,rejected-before
    end
    -- Exactly the limit and below: declined at once.
    local done,declined=try(5000*10000)
    assert(done and declined==1 and not shown,'an order at the limit asked first')
    -- Above it: nothing is sent, the dialog is up and names the tip.
    done,declined=try(5001*10000)
    assert(not done and declined==0 and shown and shown.which=='HIRONCRAFT_CONFIRM_REJECT_ORDER',
        'an order with a large tip was declined by a click')
    assert(shown.text:find('Buyer-Realm',1,true) and shown.text:find('5001',1,true),'the question does not name the customer and the tip: '..shown.text)
    assert(CO.lastStatus:find('5001',1,true),'the panel does not say that an answer is needed')
    -- Clicking the row again only asks again.
    local before=rejected
    CO:RejectOrder(order,page); CO:RejectOrder(order,page)
    assert(rejected==before,'clicking through declined the order')
    -- The answer in the dialog declines, once, and holds for the next step.
    local dialog=StaticPopupDialogs.HIRONCRAFT_CONFIRM_REJECT_ORDER
    assert(dialog and not dialog.enterClicksFirstButton and dialog.button1=='Decline','the dialog can be answered by a key press')
    dialog.OnAccept(nil,shown.data)
    assert(rejected==before+1,'the answer in the dialog did not decline')
    shown=nil
    CO.rejectedOrderIDs={}
    assert(CO:RejectOrder(order,page) and not shown and rejected==before+2,'a confirmed order asked a second time')
    -- The answer is for that order only, and not for ever.
    now=now+61
    CO.rejectedOrderIDs={}
    assert(not CO:RejectOrder(order,page) and shown,'an answer of a minute ago still declines')
    -- Cancelled (nothing accepted): nothing declined.
    before=rejected
    assert(rejected==before)
    -- Switched off with 0, and a limit of one's own.
    options.rejectConfirmTipCopper=0
    done,declined=try(900000*10000)
    assert(done and declined==1 and not shown,'a limit of 0 still asks')
    CO:SetRejectConfirmTipCopper(100*10000)
    done,declined=try(101*10000)
    assert(not done and declined==0 and shown,'an own limit is not used')
    CO:SetRejectConfirmTipCopper(nil)
    assert(CO:GetRejectConfirmTipCopper()==5000*10000,'an emptied limit did not return to the default')
    -- The click-through helper must leave this dialog alone.
    local source=assert(io.open('Workflow/Buttons/ConfirmButtons.lua','rb')):read('*a')
    assert(source:find('HIRONCRAFT_CONFIRM_REJECT_ORDER = true',1,true),'the click-through helper may cover the decline question')
    -- A claimed order asks before it is released, not after.
    options.rejectConfirmTipCopper=nil
    order.tipAmount=7000*10000
    claimed={orderID=7001,orderState='claimed',provided=17,tipAmount=order.tipAmount}
    CO.rejectedOrderIDs={}; CO.rejectConfirmedUntil=nil; CO.pendingReleaseForReject=nil
    shown=nil
    local releasedBefore=released
    assert(not CO:RejectOrder(order,page) and shown and released==releasedBefore,'a claimed order was released before the question')
    order.tipAmount=nil; claimed=nil
    CO.pendingReleaseForReject=nil
    CO.GetQueueOptions=nil
    HironCraft.RecordRejectedCraftingOrder=recordRejected
    StaticPopupDialogs,StaticPopup_Show=nil,nil
end

-- The rejection bridge must see immutable identity as well as immutable mats.
-- The game/row refresh can retire the very table passed to RejectOrder.
order={orderID=7010,orderState='created',customerName='Buyer-Realm',customerGuid='Player-1-ABCD',
    spellID=1230061,itemID=245769,parentProfessionID=773,provided=17}
claimed=nil;missing=true;quality=false
local capturedRejection, capturedAudit
HironCraft.RecordRejectedCraftingOrder=function(source,reason,audit)
    capturedRejection,capturedAudit=source,audit
    return true
end
OE.C_CraftingOrders.RejectOrder=function(id)
    assert(id==7010)
    for key in pairs(order) do order[key]=nil end
end
assert(CO:RejectOrder(order,page),'decline submission failed')
assert(capturedRejection.orderID==7010 and capturedRejection.customerName=='Buyer-Realm'
    and capturedRejection.spellID==1230061,'decline lost customer/recipe identity after the game removed the row')
assert(capturedAudit.provided==17,'decline lost pre-submit materials')
assert(capturedRejection and capturedRejection~=order,'rejection kept the mutable API table')

-- A sparse rowState used to win over the visible row, losing the customer
-- before the decline even took its snapshot (Hentihunter, order 1272696518).
-- Remember identity when first seen; Blizzard may clear that table later.
order={orderID=1272696518,orderState='created',spellID=1237543,provided=17}
local visible={orderID=1272696518,customerName='Hentihunter',spellID=1237543,itemID=244584}
CO.rowStates[order.orderID]={order=order}
assert(realGetEffectiveOrder(CO,order.orderID,visible)==order)
for key in pairs(visible) do visible[key]=nil end
capturedRejection=nil
OE.C_CraftingOrders.RejectOrder=noop
assert(CO:RejectOrder(order,page))
assert(capturedRejection.customerName=='Hentihunter' and capturedRejection.orderID==1272696518
    and capturedRejection.spellID==1237543,'sparse row lost the previously visible customer identity')

-- Release can leave a sparse list row for the second, explicit decline click.
order={orderID=7012,orderState='created'}
claimed={orderID=7012,orderState='claimed',customerName='Released-Realm',spellID=1230061,provided=17}
HironCraft.RecordRejectedCraftingOrder=function(source,reason,audit)
    capturedRejection,capturedAudit=source,audit
    return true
end
assert(CO:RejectOrder(order,page))
claimed=nil
CO:OnEvent('CRAFTINGORDERS_CLAIMED_ORDER_REMOVED')
OE.C_CraftingOrders.RejectOrder=noop
assert(CO:RejectOrder(order,page))
assert(capturedRejection.customerName=='Released-Realm' and capturedRejection.spellID==1230061
    and capturedAudit.provided==17,'release lost the customer identity or supplied materials')

-- A failed game call must never manufacture a rejected-order notice.
order={orderID=7013,orderState='created',customerName='NotDeclined-Realm',spellID=1237543,provided=17}
capturedRejection=nil
OE.C_CraftingOrders.RejectOrder=function() error('game call failed') end
assert(not CO:RejectOrder(order,page) and not capturedRejection,'a failed game action was recorded as a decline')

-- A normal Lua return of false is a failed recording, not a successful pcall.
order={orderID=7011,orderState='created',customerName='Unrecorded-Realm',spellID=1237543,provided=17}
OE.C_CraftingOrders.RejectOrder=noop
local rejectionErrors={}
CO.DActionPrint=noop
HironCraft.ReportError=function(context,err) rejectionErrors[#rejectionErrors+1]={context,err} end
HironCraft.RecordRejectedCraftingOrder=function() return false end
assert(CO:RejectOrder(order,page),'game decline did not run')
assert(#rejectionErrors==1 and tostring(rejectionErrors[1][2]):find('7011',1,true),
    'a failed rejection record was silently treated as success')

-- Leaving the crafting table closes the window also when the game only
-- takes the Orders tab away (a window that was not opened at the table).
do
    local near, shown, hidden, combat = true, true, 0, false
    local savedTimers = timers
    timers = {}
    ProfessionsFrame = { professionInfo = { profession = 5 }, IsShown = function() return shown end }
    C_TradeSkillUI = { IsNearProfessionSpellFocus = function(profession) assert(profession == 5); return near end }
    HideUIPanel = function(frame) assert(frame == ProfessionsFrame); hidden = hidden + 1; shown = false end
    InCombatLockdown = function() return combat end
    local function leave()
        local asked = CO:CloseAfterLeavingTable()
        local pending = timers; timers = {}
        for _, fn in ipairs(pending) do fn() end
        return asked
    end
    -- Another tab chosen at the table: the window stays.
    assert(leave() == false and hidden == 0, 'turning to another tab at the table closed the window')
    -- The table out of reach: closed, once, after the game's own change of tabs.
    near = false
    assert(CO:CloseAfterLeavingTable() == true and hidden == 0 and #timers == 1, 'the window was closed inside the change of tabs')
    timers[1](); timers = {}
    assert(hidden == 1, 'the window stayed open after leaving the table')
    -- Already closing: nothing to do.
    assert(leave() == false and hidden == 1)
    -- Back at the table before the moment came, or in a fight: left alone.
    shown = true
    CO:CloseAfterLeavingTable(); near = true
    timers[1](); timers = {}
    assert(hidden == 1, 'the window was closed although the table is in reach again')
    near, combat = false, true
    leave()
    assert(hidden == 1, 'the window was closed during a fight')
    combat = false
    -- The game does not say: nothing is guessed.
    ProfessionsFrame.professionInfo = nil
    assert(leave() == false and hidden == 1)
    ProfessionsFrame.professionInfo = { profession = 5 }
    C_TradeSkillUI.IsNearProfessionSpellFocus = function() error('not now') end
    assert(leave() == false and hidden == 1, 'an error of the game closed the window')
    ProfessionsFrame, C_TradeSkillUI, HideUIPanel, InCombatLockdown = nil, nil, nil, nil
    timers = savedTimers
end

-- Missing identity must fail *before* Release/Reject, without deselecting the
-- row or scheduling the destructive action for a later event/timer.
local identityDeclines, identityRecords = 0, 0
OE.C_CraftingOrders.RejectOrder=function() identityDeclines=identityDeclines+1 end
HironCraft.RecordRejectedCraftingOrder=function(source,reason,audit)
    identityRecords=identityRecords+1
    capturedRejection,capturedAudit=source,audit
    return true
end
local otherOrder={orderID=7100,customerName='OtherBuyer',spellID=1237543}
claimed=otherOrder
OE.C_CraftingOrders.GetCrafterOrders=function() return {otherOrder} end
order={orderID=7101,spellID=1237543,orderState='created',provided=0}
CO.selectedOrders['7101']=true
realGetEffectiveOrder(CO,7101,otherOrder)
local beforeRelease, beforeTimers=released,#timers
assert(not CO:RejectOrder(order,page), 'nameless order was declined')
assert(identityDeclines==0 and identityRecords==0 and released==beforeRelease and #timers==beforeTimers,
    'missing identity sent or scheduled an action')
assert(CO.selectedOrders['7101'] and not CO.rejectedOrderIDs['7101'], 'blocked decline cleared/marked the row')
assert(CO.lastStatus:find('Nothing was declined',1,true), 'blocked decline has no useful explanation')

-- The exact live API order can repair sparse identity. Merely loading it
-- must not send a decline; another hardware click is still required.
local fullOrder={orderID=7101,customerName='LoadedBuyer',spellID=1237543,itemID=244584}
OE.C_CraftingOrders.GetCrafterOrders=function() return {otherOrder,fullOrder} end
realGetEffectiveOrder(CO,7101,fullOrder)
for _,fn in ipairs(timers) do fn() end
assert(identityDeclines==0 and identityRecords==0, 'identity arrival auto-declined an order')
assert(CO:RejectOrder(order,page))
assert(identityDeclines==1 and identityRecords==1 and capturedRejection.customerName=='LoadedBuyer'
    and capturedRejection.orderID==7101 and capturedAudit.provided==0, 'wrong customer or materials after refresh')

-- Direct API enrichment also supplies recipe identity to material capture;
-- don't alter the original sparse row or substitute a neighbouring order.
claimed=nil
order={orderID=7102,orderState='created',provided=9}
fullOrder={orderID=7102,customerName='ApiBuyer',spellID=1237543,itemID=244584}
OE.C_CraftingOrders.GetCrafterOrders=function() return {otherOrder,fullOrder} end
local oldCapture=HironCraft.CaptureCraftingOrderReagents
HironCraft.CaptureCraftingOrderReagents=function(source,details)
    assert(source.customerName=='ApiBuyer' and source.spellID==1237543 and source.provided==9,
        'material capture did not receive the recovered identity with original reagents')
    return oldCapture(source,details)
end
assert(CO:RejectOrder(order,page))
assert(identityDeclines==2 and identityRecords==2 and capturedRejection.customerName=='ApiBuyer'
    and capturedAudit.provided==9 and order.customerName==nil and order.spellID==nil)
HironCraft.CaptureCraftingOrderReagents=oldCapture
OE.C_CraftingOrders.GetCrafterOrders=function() return {} end

-- Blank/secret names are absent, not usable recipients. Quality-based
-- declines and already-claimed orders obey the same pre-action guard.
for index,name in ipairs({'','   ','secret-name'}) do
    order={orderID=7110+index,customerName=name,spellID=1237543}
    OE.issecretvalue=function(value) return value=='secret-name' end
    claimed=order;quality=true;missing=false
    assert(not CO:RejectOrder(order,page,false,'insufficient_quality'))
    assert(identityDeclines==2 and identityRecords==2 and released==beforeRelease and #timers==beforeTimers)
end
OE.issecretvalue=nil;claimed=nil;quality=false;missing=true
order={orderID=7120,customerName='NoRecipe'}
assert(not CO:RejectOrder(order,page), 'unmatchable recipe was declined')
order={orderID=7121,customerName='NoBridge',spellID=1237543}
local oldRecord=HironCraft.RecordRejectedCraftingOrder
HironCraft.RecordRejectedCraftingOrder=nil
assert(not CO:RejectOrder(order,page), 'decline submitted without its status recorder')
HironCraft.RecordRejectedCraftingOrder=oldRecord

-- Empty partial fields must not erase good identity, but old cached rows
-- must expire instead of living indefinitely after a long tab/session gap.
CO:RememberOrderIdentity({orderID=7122,customerName='CachedBuyer',spellID=1237543})
order={orderID=7122,customerName=' ',spellID=1237543,provided=17}
assert(CO:RejectOrder(order,page) and capturedRejection.customerName=='CachedBuyer')
CO:RememberOrderIdentity({orderID=7123,customerName='ExpiredBuyer',spellID=1237543})
now=now+301
order={orderID=7123,spellID=1237543}
assert(not CO:RejectOrder(order,page), 'expired identity was reused')
assert(identityDeclines==3 and identityRecords==3)

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
