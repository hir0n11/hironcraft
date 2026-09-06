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
    Events={Register=noop}, LOCAL={GetText=function(_, text) return text end},
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
        profession=response.professionName}
end
function GetItemInfo(id) return id==1 and 'Bracers' or 'Belt' end
local now=100
function GetTime() return now end
C_TradeSkillUI={GetTradeSkillTexture=function() return 42 end}
HironCraftScanScannerMenu={PageButton={}}
local sent, frames={}, {}
Scan.Utils.SendResponses=function(messages, customer, userInitiated)
    assert(userInitiated == true, 'quick reply bypassed the explicit-click sender')
    assert(#messages==1, 'one quick-reply click sent several messages')
    sent[#sent+1]={text=messages[1], customer=customer}
    return true
end
local function surface()
    local value={scripts={}, shown=false}
    function value:Show() self.shown=true end
    function value:Hide() self.shown=false end
    function value:IsShown() return self.shown end
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
    local customer={guid='test-guid', responses={[101]=first, [102]=second, [2918]=first}}
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

-- The event-only rejection answer must stay attached to its specific order.
for _, id in ipairs({101,102}) do
    QuickReplies:OnOrderFulfillmentUpdated({customerName='Geete', responseID=id},
        {status='rejected', requestToken='rejection-'..id})
end
assert(#visible()==2, 'distinct rejected orders lost their individual actions')
click(visible()[1])
assert(#visible()==1 and #sent==7, 'sending one rejection dismissed the other order\'s action')
dismissAll()
print('Quick-reply toast tests passed (one answer per customer/text, clicks, stale sources, distinct contexts).')
