-- Exercise actual OnWhisper -> toast -> click behavior, not only option counts.
-- Mock the WoW UI/whisper boundary; no real messages are sent.
local function noop() end
local Scan = {
    DB={settings={quick_replies={templates={
        CUSTOM_1={custom=true, enabled=true, label='Hello', keywords='yo,hello', response='hey hey'},
        CUSTOM_2={custom=true, enabled=true, label='Coming', keywords='sent,sending orders', response='omw'},
        CUSTOM_3={custom=true, enabled=true, label='Greeting', keywords='yo,hello', response='hey hey'},
    }}}, customers={}, listed_orders={}},
    Utils={}, Frames={flipTextureHorizontally=noop}, State={}, CONST={LEFT=0},
    Events={Register=noop,Emit=noop}, LOCAL={GetText=function(_, text) return text end},
    Config={SubstituteTags=function(text) return text end},
    OrderFulfillment={Status={Rejected='rejected'}},
}
function Scan.Utils.saved(parent, key, default)
    if parent[key]==nil then parent[key]=default end
    return parent[key]
end
Scan.Utils.onLoad=function(callback) callback() end
Scan.Utils.GetSetting=function() return 1 end
Scan.GetPlayerName=function() return 'Seller-Realm' end
Scan.NameAndRealmToName=function(name) return name:match('^[^-]+') end
Scan.ColorizePlayerName=function(name) return name end
Scan.OrderToOrderID=function(order) return order.customerName..'-'..order.responseID end
function Scan.OrderToResponse(order)
    local customer=Scan.DB.customers[order.customerName]
    return customer and customer.responses[order.responseID]
end
function Scan.BuildResponseContext(response)
    return {crafter=response.crafterName, item=response.itemName, commission=response.commission,
        profession=response.professionName, reagent_issues=response.reagentIssues or 'Recorded material issues'}
end
function Scan.BuildOrderDestinationMessage(response)
    return response.itemName .. ' Send to ' .. response.crafterName .. '.'
end
function GetItemInfo(id) return id==1 and 'Bracers' or 'Belt' end
local now=100
function GetTime() return now end
C_TradeSkillUI={GetTradeSkillTexture=function() return 42 end}
HironCraftScanScannerMenu={PageButton={}}
local sent, frames, greetingClicks, orderListRefreshes={}, {}, {}, 0
HironCraftScanCraftingOrderPage={ShowGeneric=function() orderListRefreshes=orderListRefreshes+1 end}
Scan.Utils.SendResponses=function(messages, customer, userInitiated)
    assert(userInitiated == true, 'quick reply bypassed the explicit-click sender')
    assert(#messages==1, 'one quick-reply click sent several messages')
    sent[#sent+1]={text=messages[1], customer=customer}
    return true
end
Scan.SendOrderGreeting=function(order, userInitiated)
    assert(userInitiated==true, 'new-order quick reply bypassed the explicit-click greeting guard')
    local response=Scan.OrderToResponse(order)
    if not response or response.greeting_sent then return false end
    response.greeting_sent=true
    response.destination_only_greeting=nil
    greetingClicks[#greetingClicks+1]={
        customerName=order.customerName,
        responseID=order.responseID,
        requestToken=response.requestToken,
    }
    return true
end
local parentVisible=true
local function surface()
    local value={scripts={}, shown=false}
    function value:Show() self.shown=true end
    function value:Hide() self.shown=false end
    function value:IsShown() return self.shown end
    function value:IsVisible() return self.shown and parentVisible end
    function value:SetScript(event, callback) self.scripts[event]=callback end
    function value:SetText(text) self.text=text end
    function value:CreateTexture() return surface() end
    function value:CreateMaskTexture() return surface() end
    function value:CreateFontString() return surface() end
    return setmetatable(value, {__index=function() return noop end})
end
function CreateFrame()
    local frame=surface(); frames[#frames+1]=frame; return frame
end
assert(loadfile('Utils/FStrings.lua'))('HironCraft', Scan)
assert(loadfile('Customer/QuickReplies.lua'))('HironCraft', Scan)
local QuickReplies=Scan.QuickReplies
local function response(id, crafter)
    return {responseID=id, requestToken='request-'..id, time=100, customer_answered=true,
        crafterName=crafter or 'Leathloring', crafterFullName=(crafter or 'Leathloring')..'-Realm',
        professionID=2918, professionName='Tailoring', itemID=id==101 and 1 or 2,
        itemName=id==101 and '[Bracers]' or '[Belt]', commission=id==101 and '500g' or '900g',
        conversationCharacter='Seller-Realm'}
end
local function addCustomer(name)
    local first, second=response(101), response(102)
    local customer={guid='test-guid-'..name, responses={[101]=first, [102]=second, [2918]=first}}
    Scan.DB.customers[name]=customer
    for _, id in ipairs({101,102}) do
        Scan.DB.listed_orders[name..'-'..id]={customerName=name, responseID=id}
    end
    return customer, first, second
end
local function visible(customer)
    local result={}
    for _, frame in ipairs(frames) do
        if frame:IsShown() and (not customer or frame.option.customer==customer) then result[#result+1]=frame end
    end
    return result
end
local function whisper(customer, message)
    now=now+10
    QuickReplies:OnWhisper(customer, message, Scan.DB.customers[customer])
end
local function click(frame, button) frame.scripts.OnClick(frame, button or 'LeftButton') end
local function dismissAll() for _, frame in ipairs(visible()) do click(frame, 'RightButton') end end
local geete, first, second=addCustomer('Geete')
whisper('Geete', 'yo')
assert(#visible()==1, 'two items / two identical templates produced duplicate greetings')
local toast=visible()[1]
assert(toast.Reply.text=='hey hey' and #toast.option.contextLabels==2)
local staleClick=toast.scripts.OnClick
whisper('Geete', 'hello')
assert(#visible()==1, 'differently worded follow-up stacked the same answer')
staleClick(toast, 'LeftButton')
assert(#sent==0, 'a recycled toast callback sent an old option')
local current=visible()[1]
local currentClick=current.scripts.OnClick
click(current)
currentClick(current, 'LeftButton')
assert(#sent==1 and sent[1].text=='hey hey' and #visible()==0, 'duplicate click resent the answer')

addCustomer('AnotherBuyer')
whisper('Geete', 'sending orders'); whisper('AnotherBuyer', 'sent')
assert(#visible()==2 and #visible('Geete')==1, 'deduplication crossed customer boundaries')
click(visible('Geete')[1])
assert(#sent==2 and sent[2].text=='omw' and sent[2].customer=='Geete')
assert(#visible('AnotherBuyer')==1, 'sending hid another customer\'s reply')
dismissAll()

-- Removing the representative item must not invalidate an identical answer
-- for another original member of the same suggestion.
whisper('Geete', 'sent')
toast=visible()[1]
local removed=toast.option.responseID
Scan.DB.listed_orders['Geete-'..removed]=nil
geete.responses[removed]=nil
click(toast)
assert(#sent==3 and sent[3].text=='omw', 'remaining original row could not send the merged reply')

geete, first, second=addCustomer('Geete')
whisper('Geete', 'sent')
toast=visible()[1]
addCustomer('Geete') -- Replaced tables, same customer/recipe/answer text.
click(toast)
assert(#sent==3 and #visible()==0, 'old suggestion attached to replacement response tables')
geete, first, second=addCustomer('Geete')
whisper('Geete', 'sent')
toast=visible()[1]
first.requestToken='new-first'; second.requestToken='new-second'
click(toast)
assert(#sent==3, 'old suggestion survived in-place request identity changes')

-- Rendered values matter: item links, distinct prices and different crafters
-- still produce separate alternatives, whereas identical generic text does not.
geete, first, second=addCustomer('Geete')
whisper('Geete', 'price')
assert(#visible()==2, 'distinct commissions were merged')
click(visible()[1]); assert(#visible()==1); click(visible()[1])
assert(#sent==5 and sent[4].text~=sent[5].text)
second.crafterName='Tailor'; second.crafterFullName='Tailor-Realm'
whisper('Geete', 'where to send')
assert(#visible()==2, 'different send-to names were merged')
dismissAll()
whisper('Geete', 'sent')
assert(#visible()==1, 'generic answer unnecessarily depended on crafter name')
dismissAll()
QuickReplies:GetConfig().templates.CUSTOM_2.response='{item}'
whisper('Geete', 'sent')
assert(#visible()==2, 'different linked-item answers were merged')
dismissAll()
QuickReplies:GetConfig().templates.CUSTOM_2.response='omw'

-- A merged option also tracks the original template for each source.
whisper('Geete', 'yo')
toast=visible()[1]
QuickReplies:GetConfig().templates.CUSTOM_1.enabled=false
click(toast)
assert(#sent==6 and sent[6].text=='hey hey', 'disabling one duplicate template killed all equivalent sources')
QuickReplies:GetConfig().templates.CUSTOM_1.enabled=true
whisper('Geete', 'yo')
toast=visible()[1]
QuickReplies:GetConfig().templates.CUSTOM_1.response='changed'
QuickReplies:GetConfig().templates.CUSTOM_3.response='changed'
click(toast)
assert(#sent==6, 'click sent changed text different from the visible suggestion')

whisper('Geete', 'sent')
toast=visible()[1]
local sendResponses=Scan.Utils.SendResponses
Scan.Utils.SendResponses=function() return false end
click(toast)
assert(toast:IsShown() and #sent==6, 'failed send dismissed the only usable suggestion')
Scan.Utils.SendResponses=sendResponses
click(toast, 'RightButton')
assert(#visible()==0 and #sent==6, 'dismissal sent the merged reply')

-- A newly matched whisper request gets its generated greeting only after the
-- new row exists. Repeated setup replaces the same toast, and an in-place
-- request-token change makes the old click harmless.
local returning, newOrder=addCustomer('ReturningBuyer')
newOrder.greeting_sent=false
newOrder.destination_only_greeting=true
newOrder.message={'Hi! I can craft [Bracers].'}
returning.responses[102].greeting_sent=true
assert(QuickReplies:ShowOrderGreeting('ReturningBuyer','can you also do wrist?',returning,{newOrder}))
assert(#visible('ReturningBuyer')==1 and #greetingClicks==0)
assert(visible('ReturningBuyer')[1].option.reply=='[Bracers] Send to Leathloring.',
    'follow-up toast still displays a full introduction')
assert(QuickReplies:ShowOrderGreeting('ReturningBuyer','can you also do wrist?',returning,{newOrder}))
assert(#visible('ReturningBuyer')==1, 'same new request stacked greeting quick replies')
click(visible('ReturningBuyer')[1])
assert(#greetingClicks==1 and greetingClicks[1].responseID==101
    and greetingClicks[1].requestToken=='request-101', 'new-order quick reply targeted the wrong request')
assert(orderListRefreshes==1, 'greeting toast did not refresh the first status checkmark')

newOrder.greeting_sent=false
newOrder.requestToken='request-before-reuse'
assert(QuickReplies:ShowOrderGreeting('ReturningBuyer','another wrist?',returning,{newOrder}))
local staleGreeting=visible('ReturningBuyer')[1]
newOrder.requestToken='request-after-reuse'
click(staleGreeting)
assert(#greetingClicks==1 and #visible('ReturningBuyer')==0,
    'stale new-order quick reply followed a reused row')

-- A generic request has no profession ID yet, but still gets one safe
-- click-to-send greeting. Replacing the row dismisses that obsolete action.
local broadResponse={responseID='__hironcraft_general_request__',
    requestToken='generic-request',time=now,generic_request=true,
    crafterName='All crafters',professionName='Any profession',
    message={"Hi! Tell me what you need."},greeting_sent=false}
local broad={guid='broad-guid',responses={
    ['__hironcraft_general_request__']=broadResponse}}
Scan.DB.customers.BroadBuyer=broad
Scan.DB.listed_orders['BroadBuyer-__hironcraft_general_request__']={
    customerName='BroadBuyer',responseID='__hironcraft_general_request__'}
assert(QuickReplies:ShowOrderGreeting(
    'BroadBuyer','LF crafter',broad,{broadResponse}))
assert(#visible('BroadBuyer')==1, 'generic request did not create one Quick Reply')
assert(QuickReplies:DismissOrderGreeting(
    'BroadBuyer','__hironcraft_general_request__','generic-request'))
assert(#visible('BroadBuyer')==0, 'replaced generic row left its old Quick Reply visible')

-- The event-only rejection answer must stay attached to its specific order.
for _, id in ipairs({101,102}) do
    QuickReplies:OnOrderFulfillmentUpdated({customerName='Geete', responseID=id},
        {status='rejected', requestToken='rejection-'..id})
end
assert(#visible()==2, 'distinct rejected orders lost their individual actions')
click(visible()[1])
assert(#visible()==1 and #sent==7, 'sending one rejection dismissed the other order\'s action')
dismissAll()
-- A Battle.net customer keeps its transport identity through grouping/clicks.
for _,frame in ipairs(visible()) do click(frame,'RightButton') end
local bnetCustomer='BNET:local-account:friend#1234'
addCustomer(bnetCustomer)
local beforeBNet=#sent
whisper(bnetCustomer,'sent')
assert(#visible(bnetCustomer)==1 and #sent==beforeBNet, 'BN message auto-sent or duplicated quick replies')
click(visible(bnetCustomer)[1])
assert(#sent==beforeBNet+1 and sent[#sent].customer==bnetCustomer and sent[#sent].text=='omw',
    'BN quick reply lost its account-scoped transport identity')
print('Quick-reply toast tests passed (one answer per customer/text, clicks, stale sources, distinct contexts, Battle.net).')

dismissAll()
addCustomer('CooldownBuyer');addCustomer('OtherCooldownBuyer')
QuickReplies:GetConfig().templates.CUSTOM_1.response='hey hey'
QuickReplies:GetConfig().templates.CUSTOM_3.response='hey hey'
local baseline=#sent
local function propose(name,message)
    QuickReplies:OnWhisper(name,message,Scan.DB.customers[name])
end
propose('CooldownBuyer','sent'); HironCraftScanSendQuickReply()
assert(#sent==baseline+1 and #visible()==0,'keyboard did not click the top quick reply')
propose('CooldownBuyer','sending orders'); now=now+5.99
HironCraftScanSendQuickReply()
assert(#sent==baseline+1 and #visible('CooldownBuyer')==1,'same reply bypassed six-second cooldown')
propose('OtherCooldownBuyer','sent'); HironCraftScanSendQuickReply()
assert(#sent==baseline+2 and sent[#sent].customer=='OtherCooldownBuyer','cooldown leaked to another customer')
propose('CooldownBuyer','yo'); HironCraftScanSendQuickReply()
assert(#sent==baseline+3 and sent[#sent].text=='hey hey','cooldown blocked another reply')
now=now+0.01
HironCraftScanSendQuickReply()
assert(#sent==baseline+4 and sent[#sent].text=='omw','reply did not unlock after six seconds')
assert(not QuickReplies:SendTopReply(false),'unguarded keyboard entry point')
local send=Scan.Utils.SendResponses
Scan.Utils.SendResponses=function() return false end
now=now+10;propose('CooldownBuyer','sent');HironCraftScanSendQuickReply()
Scan.Utils.SendResponses=send
HironCraftScanSendQuickReply()
assert(#sent==baseline+5,'failed send consumed the cooldown')
assert(not QuickReplies:SendTopReply(true),'empty stack consumed keyboard action')
print('Quick reply cooldown and keyboard tests passed (6s, independent recipients/text, failure retry).')

now=now+10
propose('CooldownBuyer','sent')
local hidden=visible()[1]
local beforeHidden=#sent
parentVisible=false
assert(not QuickReplies:SendTopReply(true), 'hidden parent left its quick reply hotkey active')
click(hidden)
assert(#sent==beforeHidden, 'invisible quick reply sent chat')
parentVisible=true
HironCraftScanSendQuickReply()
assert(#sent==beforeHidden+1, 'visible quick reply stopped working')
-- Also guard direct whisper classification callers, not just the scanner.
Scan.Scanner={IsCrafterAdvertisement=function(message) return message=='hello ad' end}
now=now+10
propose('CooldownBuyer','hello ad')
assert(#visible()==0 and #sent==beforeHidden+1,'advertisement made a conversational reply card')
print('Quick reply visibility and advertisement guards passed.')

-- A new Blizzard order ID can be declined again; ACKs are not fresh declines.
dismissAll()
local auditCustomer,auditResponse=addCustomer('AuditBuyer')
auditResponse.conversationCharacter='Seller-Realm'
local auditOrder={customerName='AuditBuyer',responseID=101}
local auditStatus={status='rejected',craftingOrderID=81001,requestToken=auditResponse.requestToken}
Scan.OrderFulfillment.GetStatus=function() return auditStatus end
local beforeAudit=#sent
QuickReplies:OnOrderFulfillmentUpdated(auditOrder,auditStatus)
assert(#visible('AuditBuyer')==1 and #sent==beforeAudit,'decline auto-sent its audit')
QuickReplies:OnOrderFulfillmentUpdated(auditOrder,auditStatus)
assert(#visible('AuditBuyer')==1,'ACK repeated the decline suggestion')
local staleOption=visible('AuditBuyer')[1].option
auditStatus.craftingOrderID=81002
assert(not QuickReplies:ResolvePopupResponse(staleOption),'old decline reply followed the resent order')
QuickReplies:OnOrderFulfillmentUpdated(auditOrder,auditStatus)
assert(#visible('AuditBuyer')==1 and visible('AuditBuyer')[1].option.rejectionOrderID==81002)
auditStatus.status='fulfilled'
click(visible('AuditBuyer')[1])
assert(#sent==beforeAudit,'completed order sent a stale decline reply')
auditStatus.status='rejected';auditStatus.craftingOrderID=81003
auditResponse.reagentIssues=string.rep('Missing: 20x Alloy; ',25)
local splits,batches=0,0
Scan.Utils.SplitResponse=function(text)
    splits=splits+1
    local result={}
    while #text>0 do result[#result+1]=text:sub(1,255);text=text:sub(256) end
    return result
end
Scan.Utils.SendResponses=function(messages,customer,manual)
    assert(manual==true and customer=='AuditBuyer' and #messages>1)
    for _,message in ipairs(messages) do assert(#message<=255) end
    batches=batches+1
    return true
end
QuickReplies:OnOrderFulfillmentUpdated(auditOrder,auditStatus)
assert(#visible('AuditBuyer')==1 and splits==0 and batches==0,'long audit auto-split/sent')
click(visible('AuditBuyer')[1])
assert(splits==1 and batches==1)
auditStatus.craftingOrderID=81004
QuickReplies:OnOrderFulfillmentUpdated(auditOrder,auditStatus)
click(visible('AuditBuyer')[1])
assert(batches==1,'multi-message audit bypassed cooldown')
now=now+6;click(visible('AuditBuyer')[1])
assert(batches==2)
print('Reagent reply tests passed (manual batches, cooldown, resend identity, completed order guard).')

-- Completing an order offers its own reply, once, and only while enabled.
dismissAll()
local doneOrder={customerName='AuditBuyer',responseID=102}
local doneStatus={status='fulfilled',craftingOrderID=81100}
Scan.OrderFulfillment.GetStatus=function() return doneStatus end
Scan.Utils.SendResponses=sendResponses
local beforeDone=#sent
QuickReplies:OnOrderFulfillmentUpdated(doneOrder,doneStatus)
local doneCard=visible('AuditBuyer')[1]
assert(doneCard and doneCard.option.templateKey=='COMPLETED_ORDER'
    and doneCard.option.reply=='Your order is done, thank you!','completed order offered no reply')
assert(#sent==beforeDone,'completed order auto-sent its reply')
click(doneCard);assert(#sent==beforeDone+1,'completed-order reply was not sent on click')
QuickReplies:OnOrderFulfillmentUpdated(doneOrder,doneStatus)
assert(#visible('AuditBuyer')==0,'a status update repeated the completed-order offer')
Scan.DB.settings.quick_replies.templates.COMPLETED_ORDER.enabled=false
QuickReplies:OnOrderFulfillmentUpdated({customerName='AuditBuyer',responseID=101},
    {status='fulfilled',craftingOrderID=81101})
assert(#visible('AuditBuyer')==0,'a disabled completed-order reply was still offered')
Scan.DB.settings.quick_replies.templates.COMPLETED_ORDER.enabled=true

-- A decline recorded before its material list waits for the list instead of
-- replying that the details could not be found.
dismissAll()
local timers={}
C_Timer={After=function(_,callback) timers[#timers+1]=callback end}
local snapshot=nil
Scan.ReagentAudit={GetForOrder=function() return snapshot end}
local waitStatus={status='rejected',craftingOrderID=81200,requestToken=auditResponse.requestToken}
Scan.OrderFulfillment.GetStatus=function() return waitStatus end
QuickReplies:OnOrderFulfillmentUpdated(auditOrder,waitStatus)
assert(#visible('AuditBuyer')==0 and #timers==1,'decline offered a reply before its material list')
snapshot={rows={},complete=true}
timers[1]()
assert(#visible('AuditBuyer')==1,'decline never offered its reply after the list arrived')
-- A list that never arrives still offers the reply after the last attempt.
dismissAll();timers={};snapshot=nil
local lateStatus={status='rejected',craftingOrderID=81201,requestToken=auditResponse.requestToken}
Scan.OrderFulfillment.GetStatus=function() return lateStatus end
QuickReplies:OnOrderFulfillmentUpdated(auditOrder,lateStatus)
for index=1,8 do if timers[index] then timers[index]() end end
assert(#visible('AuditBuyer')==1,'decline without a material list never offered any reply')
C_Timer=nil
print('Order status reply tests passed (completed reply with switch, decline waits for materials).')

-- Deleting or renaming a template invalidates already visible callbacks as well
-- as the keyboard action. Neither editing nor deletion may send anything.
dismissAll()
Scan.Utils.SendResponses=sendResponses
local beforeEdits=#sent
whisper('CooldownBuyer','price')
assert(#visible()==2)
local oldPrice=visible()[1]
local oldPriceClick=oldPrice.scripts.OnClick
assert(QuickReplies:DeleteTemplate('PRICE'))
assert(#visible()==0 and not QuickReplies:SendTopReply(true))
oldPriceClick(oldPrice,'LeftButton')
whisper('CooldownBuyer','price')
assert(#visible()==0 and #sent==beforeEdits,'deleted default sent or proposed an answer')
whisper('CooldownBuyer','sent')
local oldCustom=visible()[1]
local oldCustomClick=oldCustom.scripts.OnClick
assert(QuickReplies:RenameTemplate('CUSTOM_2','On my way'))
assert(#visible()==0)
oldCustomClick(oldCustom,'LeftButton')
whisper('CooldownBuyer','sent')
assert(#visible()==1 and visible()[1].option.templateLabel=='On my way')
assert(QuickReplies:DeleteTemplate('CUSTOM_2'))
assert(#visible()==0 and not QuickReplies:SendTopReply(true) and #sent==beforeEdits)
print('Visible reply editing tests passed (built-in deletion, rename, stale clicks, keyboard, no auto-send).')
