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
-- for another original member of the same suggestion. Each of these uses its
-- own customer: the same answer is not offered twice in a row to one person.
local merged=addCustomer('MergedBuyer')
whisper('MergedBuyer', 'sent')
toast=visible()[1]
local removed=toast.option.responseID
Scan.DB.listed_orders['MergedBuyer-'..removed]=nil
merged.responses[removed]=nil
click(toast)
assert(#sent==3 and sent[3].text=='omw', 'remaining original row could not send the merged reply')

addCustomer('ReplacedBuyer')
whisper('ReplacedBuyer', 'sent')
toast=visible()[1]
addCustomer('ReplacedBuyer') -- Replaced tables, same customer/recipe/answer text.
click(toast)
assert(#sent==3 and #visible()==0, 'old suggestion attached to replacement response tables')
local _,retokenFirst,retokenSecond=addCustomer('RetokenBuyer')
whisper('RetokenBuyer', 'sent')
toast=visible()[1]
retokenFirst.requestToken='new-first'; retokenSecond.requestToken='new-second'
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
addCustomer('ChangedTextBuyer')
whisper('ChangedTextBuyer', 'yo')
toast=visible('ChangedTextBuyer')[1]
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
assert(#sent==baseline+1 and #visible('CooldownBuyer')==0,
    'the answer just sent was offered again right away')
propose('OtherCooldownBuyer','sent'); HironCraftScanSendQuickReply()
assert(#sent==baseline+2 and sent[#sent].customer=='OtherCooldownBuyer','cooldown leaked to another customer')
propose('CooldownBuyer','yo'); HironCraftScanSendQuickReply()
assert(#sent==baseline+3 and sent[#sent].text=='hey hey','cooldown blocked another reply')
now=now+0.01
propose('CooldownBuyer','sending orders')
HironCraftScanSendQuickReply()
assert(#sent==baseline+4 and sent[#sent].text=='omw',
    'the answer stayed blocked after the talk moved on')
assert(not QuickReplies:SendTopReply(false),'unguarded keyboard entry point')
local send=Scan.Utils.SendResponses
Scan.Utils.SendResponses=function() return false end
now=now+10;propose('CooldownBuyer','yo');HironCraftScanSendQuickReply()
Scan.Utils.SendResponses=send
HironCraftScanSendQuickReply()
assert(#sent==baseline+5 and sent[#sent].text=='hey hey','failed send consumed the cooldown')
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
-- A check mark set by hand is the crafter's own bookkeeping: announcing it
-- is their call. The decline reply is not affected, it carries the materials.
local manualDone={status='fulfilled',craftingOrderID=81102,automatic=false}
Scan.OrderFulfillment.GetStatus=function() return manualDone end
QuickReplies:OnOrderFulfillmentUpdated({customerName='AuditBuyer',responseID=102},manualDone)
assert(#visible('AuditBuyer')==0,'a check mark set by hand offered the completion reply')
local manualDecline={status='rejected',craftingOrderID=81103,automatic=false,
    requestToken=auditResponse.requestToken}
Scan.OrderFulfillment.GetStatus=function() return manualDecline end
QuickReplies:OnOrderFulfillmentUpdated(auditOrder,manualDecline)
assert(#visible('AuditBuyer')==1,'a decline recorded by hand lost its reply')
dismissAll()

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
-- Long enough after the last "omw" that saying it again is natural.
now=now+400
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
-- Per quick reply: after it is sent, the same answer stays out of the way for
-- that one person. Two "omw" a few seconds apart help nobody.
dismissAll()
assert(QuickReplies.NormalizeRepeatSeconds('45')==45 and QuickReplies.NormalizeRepeatSeconds(-3)==0
    and QuickReplies.NormalizeRepeatSeconds(99999)==86400 and QuickReplies.NormalizeRepeatSeconds('later')==0,
    'the repeat delay accepted a value outside its range')
local repeatKey=QuickReplies:CreateCustomTemplate('Coming back','omw now','omw')
-- Longer than the few minutes in which nobody repeats themselves anyway, so
-- this measures the configured delay and nothing else.
QuickReplies:GetConfig().templates[repeatKey].repeat_seconds=600
addCustomer('RepeatBuyer');addCustomer('OtherRepeatBuyer')
local beforeRepeat=#sent
whisper('RepeatBuyer','omw now')
assert(#visible('RepeatBuyer')==1,'the reply was not offered the first time')
click(visible('RepeatBuyer')[1])
assert(#sent==beforeRepeat+1 and sent[#sent].text=='omw','the reply was not sent')
now=now+400
whisper('RepeatBuyer','omw now')
assert(#visible('RepeatBuyer')==0,'the same reply was offered again inside its own delay')
whisper('OtherRepeatBuyer','omw now')
assert(#visible('OtherRepeatBuyer')==1,'the delay reached another person')
dismissAll()
now=now+300
whisper('RepeatBuyer','omw now')
assert(#visible('RepeatBuyer')==1,'the reply never came back after its delay')
dismissAll()
-- A delay of zero is the old behaviour: offer it whenever it fits.
QuickReplies:GetConfig().templates[repeatKey].repeat_seconds=0
whisper('RepeatBuyer','omw now');click(visible('RepeatBuyer')[1])
now=now+400
whisper('RepeatBuyer','omw now')
assert(#visible('RepeatBuyer')==1,'a reply without a delay was withheld')
dismissAll()
-- A delay configured in minutes by 0.3.70 keeps its real length in seconds.
local legacyKey=QuickReplies:CreateCustomTemplate('Legacy delay','legacy delay','omw')
local legacyTemplate=QuickReplies:GetConfig().templates[legacyKey]
legacyTemplate.repeat_seconds=nil
legacyTemplate.repeat_minutes=3
Scan.DB.settings.quick_replies.schema_version=8
assert(QuickReplies:GetTemplateRepeatDelay(legacyKey)==180,'a delay set in minutes changed length')
assert(QuickReplies:GetConfig().templates[legacyKey].repeat_minutes==nil,'the old field survived the upgrade')
assert(QuickReplies:DeleteTemplate(legacyKey))
assert(QuickReplies:DeleteTemplate(repeatKey))

-- One "your order is done" per batch. A customer with several orders in
-- flight is told once, when the last of them is finished, instead of after
-- every third check mark.
dismissAll()
local previousStatusLookup=Scan.OrderFulfillment.GetStatus
local batchStatuses={}
Scan.OrderFulfillment.GetStatus=function(_,order) return batchStatuses[tostring(order.responseID)] end
local _,batchFirst,batchSecond=addCustomer('BatchBuyer')
batchFirst.conversationCharacter='Seller-Realm'
batchSecond.conversationCharacter='Seller-Realm'
local firstDone={status='fulfilled',craftingOrderID=91001,requestToken=batchFirst.requestToken}
local secondDone={status='fulfilled',craftingOrderID=91002,requestToken=batchSecond.requestToken}
batchStatuses['101']=firstDone
batchStatuses['102']={status='claimed',craftingOrderID=91002,requestToken=batchSecond.requestToken}
QuickReplies:OnOrderFulfillmentUpdated({customerName='BatchBuyer',responseID=101},firstDone)
assert(#visible('BatchBuyer')==0,'the first of several orders already offered the done reply')
batchStatuses['102']={status='crafted',craftingOrderID=91002,requestToken=batchSecond.requestToken}
QuickReplies:OnOrderFulfillmentUpdated({customerName='BatchBuyer',responseID=101},firstDone)
assert(#visible('BatchBuyer')==0,'an order still being crafted did not hold the done reply')
batchStatuses['102']=secondDone
QuickReplies:OnOrderFulfillmentUpdated({customerName='BatchBuyer',responseID=102},secondDone)
local batchCard=visible('BatchBuyer')[1]
assert(batchCard and batchCard.option.templateKey=='COMPLETED_ORDER',
    'the last order of the batch offered no done reply')
assert(#visible('BatchBuyer')==1,'the batch offered more than one done reply')

-- Two orders can finish in the same moment and each ask to announce itself.
-- One "your order is done" answers for both: the second card disappears when
-- the first is sent, and a click on one that slipped through sends nothing.
Scan.DB.settings.status_replies_sent=nil
batchStatuses['101']=firstDone
QuickReplies:OnOrderFulfillmentUpdated({customerName='BatchBuyer',responseID=101},firstDone)
local batchCards=visible('BatchBuyer')
assert(#batchCards==2,'the second finished order offered no card of its own')
local sentBeforeBatch=#sent
click(batchCards[1])
assert(#sent==sentBeforeBatch+1,'the done reply was not sent')
assert(#visible('BatchBuyer')==0,'the second done reply stayed on screen')
click(batchCards[2])
assert(#sent==sentBeforeBatch+1,'the second done reply was sent as well')
-- It is not offered again either, including after a reload.
QuickReplies:OnOrderFulfillmentUpdated({customerName='BatchBuyer',responseID=101},firstDone)
QuickReplies:OnOrderFulfillmentUpdated({customerName='BatchBuyer',responseID=102},secondDone)
assert(#visible('BatchBuyer')==0,'an answered batch offered the done reply again')
Scan.DB.settings.status_replies_sent=nil
dismissAll()
-- A declined order is a finished one: it does not hold the reply back, and a
-- decline is still reported per order.
local _,declFirst,declSecond=addCustomer('DeclineBatchBuyer')
declFirst.conversationCharacter='Seller-Realm'
declSecond.conversationCharacter='Seller-Realm'
batchStatuses['101']={status='rejected',craftingOrderID=92001,requestToken=declFirst.requestToken}
local declDone={status='fulfilled',craftingOrderID=92002,requestToken=declSecond.requestToken}
batchStatuses['102']=declDone
QuickReplies:OnOrderFulfillmentUpdated({customerName='DeclineBatchBuyer',responseID=102},declDone)
assert(#visible('DeclineBatchBuyer')==1,'a declined order held back the done reply')
dismissAll()
-- An old request that never became an order must not mute the reply forever.
local _,staleFirst=addCustomer('StaleBuyer')
staleFirst.conversationCharacter='Seller-Realm'
batchStatuses['101']={status='fulfilled',craftingOrderID=93001,requestToken=staleFirst.requestToken}
batchStatuses['102']=nil
time=function() return 100+13*60*60 end
QuickReplies:OnOrderFulfillmentUpdated({customerName='StaleBuyer',responseID=101},batchStatuses['101'])
assert(#visible('StaleBuyer')==1,'a stale request from the same customer muted the done reply')
dismissAll()
time=nil
Scan.OrderFulfillment.GetStatus=previousStatusLookup

-- A decline made while its conversation character was logged out, or while
-- the crafting happened on the linked account, must still be offered when
-- that character comes back. The live event is long gone by then.
dismissAll()
Scan.DB.settings.status_replies_sent=nil
local storedStatuses={}
Scan.OrderFulfillment.GetStatuses=function() return storedStatuses end
local catchupCustomer,catchupFirst=addCustomer('CatchupBuyer')
catchupFirst.conversationCharacter='Seller-Realm'
local catchupStatus={customerName='CatchupBuyer',responseID=101,status='rejected',
    craftingOrderID=95001,requestToken=catchupFirst.requestToken,updatedAt=(now or 0)}
storedStatuses['CatchupBuyer-101']=catchupStatus
Scan.OrderFulfillment.GetStatus=function() return catchupStatus end
Scan.ReagentAudit={GetForOrder=function() return {rows={},complete=true} end}
local beforeCatchup=#sent
assert(QuickReplies:OfferPendingOrderStatusReplies()>0,'no pending reply was found at login')
local catchupCard=visible('CatchupBuyer')[1]
assert(catchupCard and catchupCard.option.templateKey=='REJECTED_ORDER',
    'a decline made while this character was away offered no reply')
assert(#sent==beforeCatchup,'the catch-up sent the reply by itself')
click(catchupCard)
assert(#sent==beforeCatchup+1,'the caught-up reply could not be sent')
-- Once it is sent it is finished, including after a reload.
assert(QuickReplies:WasStatusReplySent({customerName='CatchupBuyer',responseID=101},catchupStatus),
    'the sent reply was not remembered')
dismissAll()
assert(QuickReplies:OfferPendingOrderStatusReplies()==0,'an answered decline was offered again')
assert(#visible('CatchupBuyer')==0)
-- A reply for another character stays hers, and is not silently dropped.
storedStatuses={}
Scan.DB.settings.status_replies_sent=nil
local _,otherFirst=addCustomer('OtherCharBuyer')
otherFirst.conversationCharacter='Someone-Else'
local otherStatus={customerName='OtherCharBuyer',responseID=101,status='rejected',
    craftingOrderID=95002,requestToken=otherFirst.requestToken,updatedAt=(now or 0)}
storedStatuses['OtherCharBuyer-101']=otherStatus
Scan.OrderFulfillment.GetStatus=function() return otherStatus end
local printed={}
local realPrint=print
print=function(text) printed[#printed+1]=tostring(text) end
QuickReplies:OfferPendingOrderStatusReplies()
print=realPrint
assert(#visible('OtherCharBuyer')==0,'a reply was offered on the wrong character')
assert(#printed==1 and printed[1]:find('Someone-Else',1,true),
    'the crafter was not told which character owns the reply')
storedStatuses={}
Scan.OrderFulfillment.GetStatuses=nil

-- "omw" after the item was already handed over reads as if nothing happened.
-- A reply can be kept for customers who still have something in the works.
dismissAll()
local openStatuses={}
Scan.OrderFulfillment.GetStatus=function(_,order) return openStatuses[tostring(order.responseID)] end
local _,openFirst,openSecond=addCustomer('OpenOrderBuyer')
openFirst.conversationCharacter='Seller-Realm'
openSecond.conversationCharacter='Seller-Realm'
local omwKey=QuickReplies:CreateCustomTemplate('On my way','sending it','omw')
QuickReplies:GetConfig().templates[omwKey].active_orders_only=true
-- Nothing decided yet: the order is open, so the reply is offered.
whisper('OpenOrderBuyer','sending it')
assert(#visible('OpenOrderBuyer')==1,'an open order did not offer the reply')
dismissAll()
-- Being crafted still counts as open.
openStatuses['101']={status='crafted',craftingOrderID=96001}
openStatuses['102']={status='rejected',craftingOrderID=96002}
whisper('OpenOrderBuyer','sending it')
assert(#visible('OpenOrderBuyer')==1,'an order being crafted did not count as open')
dismissAll()
-- Everything finished: a repeated "sent" must not bring "omw" back.
openStatuses['101']={status='fulfilled',craftingOrderID=96001}
whisper('OpenOrderBuyer','sending it')
assert(#visible('OpenOrderBuyer')==0,'a finished order still offered the reply')
-- Other replies for the same customer are untouched.
assert(QuickReplies:GetConfig().templates.CUSTOM_1.enabled)
whisper('OpenOrderBuyer','yo')
assert(#visible('OpenOrderBuyer')==1,'the setting muted an unrelated reply')
dismissAll()
-- Without the setting the reply behaves as before.
QuickReplies:GetConfig().templates[omwKey].active_orders_only=false
whisper('OpenOrderBuyer','sending it')
assert(#visible('OpenOrderBuyer')==1,'a reply without the setting was withheld')
dismissAll()
-- A card offered while the order was open must go away the moment the order
-- is finished, and a blind click on one that slipped through sends nothing.
QuickReplies:GetConfig().templates[omwKey].active_orders_only=true
QuickReplies:GetConfig().templates.COMPLETED_ORDER.enabled=false
openStatuses['101']={status='crafted',craftingOrderID=96001}
whisper('OpenOrderBuyer','sending it')
assert(#visible('OpenOrderBuyer')==1,'the open order offered no reply to go stale')
local staleSends=#sent
local doneStatus={status='fulfilled',craftingOrderID=96001}
openStatuses['101']=doneStatus
QuickReplies:OnOrderFulfillmentUpdated({customerName='OpenOrderBuyer',responseID=101},doneStatus)
for _,card in ipairs(visible('OpenOrderBuyer')) do
    assert(card.option.templateKey~=omwKey,'the reply stayed on screen after the order was finished')
end
QuickReplies:GetConfig().templates.COMPLETED_ORDER.enabled=true

-- The order can also finish between the card appearing and the click.
dismissAll()
openStatuses['101']={status='crafted',craftingOrderID=96001}
whisper('OpenOrderBuyer','sending it')
local staleCard=visible('OpenOrderBuyer')[1]
assert(staleCard and staleCard.option.templateKey==omwKey)
openStatuses['101']=doneStatus
click(staleCard)
assert(#sent==staleSends,'a click after the order was finished still sent the reply')

dismissAll()
assert(QuickReplies:DeleteTemplate(omwKey))
Scan.OrderFulfillment.GetStatus=nil

-- Nobody repeats themselves back to back: while the last thing said to this
-- customer is exactly this answer, it is not offered again. Saying anything
-- else moves the talk on and the answer is available once more.
dismissAll()
QuickReplies:GetConfig().templates.CUSTOM_1.enabled=true
QuickReplies:GetConfig().templates.CUSTOM_1.keywords='yo,hello'
QuickReplies:GetConfig().templates.CUSTOM_1.response='hey hey'
local repeatKey2=QuickReplies:CreateCustomTemplate('Coming','sending it now','omw')
addCustomer('NoRepeatBuyer')
local beforeRepeat2=#sent
whisper('NoRepeatBuyer','sending it now')
assert(#visible('NoRepeatBuyer')==1,'the answer was not offered the first time')
click(visible('NoRepeatBuyer')[1])
assert(#sent==beforeRepeat2+1 and sent[#sent].text=='omw')
whisper('NoRepeatBuyer','sending it now')
assert(#visible('NoRepeatBuyer')==0,'the same answer was offered twice in a row')
whisper('NoRepeatBuyer','yo')
assert(#visible('NoRepeatBuyer')==1,'a different answer was blocked as a repeat')
click(visible('NoRepeatBuyer')[1])
assert(#sent==beforeRepeat2+2 and sent[#sent].text=='hey hey')
whisper('NoRepeatBuyer','sending it now')
assert(#visible('NoRepeatBuyer')==1,'the answer stayed blocked after the talk moved on')
dismissAll()
-- Another customer is another conversation.
addCustomer('OtherRepeatBuyer2')
whisper('OtherRepeatBuyer2','sending it now')
assert(#visible('OtherRepeatBuyer2')==1,'the block reached another customer')
dismissAll()
assert(QuickReplies:DeleteTemplate(repeatKey2))

print('Visible reply editing tests passed (built-in deletion, rename, stale clicks, keyboard, no auto-send, per-reply repeat delay).')
