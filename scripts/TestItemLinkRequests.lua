-- Exercise the real matcher, response storage, row actions and whisper sender.
-- Only the WoW API boundary is mocked; no live chat messages are sent.
local function noop() end
local Scan = {
    CONST = {
        TEXT = setmetatable({}, {__index=function(_, key) return key end}),
        RECIPE_STATES = { SCANNING_ON=1, SCANNING_OFF=0 },
        DEFAULT_SETTINGS = { auto_reply_delay=1000 },
    },
    Events = {Register=noop}, Debug = {Print=noop}, State = {},
    Config = {SubstituteTags=function(text) return text end},
}
local greetings = {
    GREETING_I_CAN_CRAFT_ITEM='Hi! Send {item} to {crafter}.',
    GREETING_ALT_CAN_CRAFT_ITEM='Hi! Send {item} to {crafter}.',
    GREETING_I_HAVE_PROF='Hi! {profession}.', GREETING_ALT_HAS_PROF='Hi! {profession}.',
    GREETING_ALT_SUFFIX='',
    GREETING_GENERIC_REQUEST="Hi! Tell me what you need and I'll name the crafter.",
}
Scan.LOCAL = {GetText=function(_, key) return greetings[key] or key end}
local function loadSource(path) return assert(loadfile(path))('HironCraft', Scan) end
local createdFrames={}
function CreateFrame()
    local frame={events={},scripts={}}
    function frame:SetScript(name,callback) self.scripts[name]=callback end
    function frame:RegisterEvent(event) self.events[event]=true end
    function frame:UnregisterEvent(event) self.events[event]=nil end
    createdFrames[#createdFrames+1]=frame
    return frame
end
local function frameForEvent(event)
    for index=#createdFrames,1,-1 do
        if createdFrames[index].events[event] and createdFrames[index].scripts.OnEvent then
            return createdFrames[index]
        end
    end
end
function CreateFromMixins() return {} end
EnumUtil = {MakeEnum=function(...) local e={}; for i,k in ipairs({...}) do e[k]=i end; return e end}
StaticPopupDialogs, UISpecialFrames, UIPanelWindows = {}, {}, {}
bit = {bxor=function() return 0 end, band=function() return 0 end}
function UnitName() return 'Seller' end
function GetRealmName() return 'Realm' end
function GetTime() return 100 end
local now=1000
function time() return now end
function issecretvalue() return false end
function strsplit(separator, value)
    local lines = {}; for line in (value .. separator):gmatch('(.-)' .. separator) do lines[#lines+1]=line end
    return table.unpack(lines)
end
function FlashClientIcon() end
local sent, shared, timers, refreshes, opened = {}, {}, {}, 0, 0
function GetDefaultLanguage() return 'Common', 7 end
function SendChatMessage(message, kind, language, customer)
    assert(kind=='WHISPER' and language==7)
    assert(#message<=255, 'outgoing whisper exceeds 255 bytes')
    local text=message:gsub('|H[^|]+|h.-|h', '')
    assert(not text:find('|H', 1, true) and not text:find('|h', 1, true),
        'outgoing whisper contains a split hyperlink')
    sent[#sent+1] = {message=message, customer=customer}
end
RobotsDotTxtAPI = {NotifyCustomer=function() error('obsolete robots.txt traffic') end}
C_Timer = {After=function(_, callback) timers[#timers+1]=callback end}
HironCraftScanComm = {applying_remote_state=false, ShareCustomerOrder=function(_, ...)
    shared[#shared+1] = {...}
end}
HironCraftScanCraftingOrderPage = {ShowGeneric=function() refreshes=refreshes+1 end, IsShown=function() return true end}
HironCraftScanScannerMenu = {ClearAlert=noop}
function ChatFrame_SendTell() opened=opened+1 end
Scan.QuickReplies = {
    ApplyConversationOwners=noop, GetConversationOwners=function() return {} end,
    RememberCustomerConversation=function() return {} end, OnWhisper=noop,
    RememberConversationCharacter=function(_, response) response.conversationCharacter='Seller-Realm' end,
}
local function link(id, variant)
    return '|cffa335ee|Hitem:' .. id .. ':' .. (variant or '0') .. '|h[Item ' .. id .. ']|h|r'
end
local recipes = {
    [101]={recipeID=101, qualityItemIDs={1001,1004}},
    [102]={recipeID=102, qualityItemIDs={1002}},
    [103]={recipeID=103, qualityItemIDs={1003}},
    [104]={recipeID=104, qualityItemIDs={1005}},
}
C_TradeSkillUI = {
    GetRecipeInfo=function(id) return recipes[id] end,
    GetProfessionInfoBySkillLineID=function(id)
        return {parentProfessionID=id, parentProfessionName='Profession ' .. id}
    end,
}
C_SpellBook = {GetSkillLineIndexByID=function() return nil end}
function GetItemInfo(id) return 'Item ' .. id, link(id) end
Item = {CreateFromItemID=function(_, id) return {
    GetItemLink=function() return link(id) end,
    ContinueOnItemLoad=function(_, callback) callback() end,
} end}
Scan.ConcentrationData = {Deserialize=function(_, amount) return {
    GetCurrentAmount=function() return amount end, GetTimeUntil=function() return 5 end,
} end}
Scan.TimeSlice = function(entries, _, callback, done)
    for id, entry in pairs(entries) do callback(id, entry) end
    done()
end
loadSource('Libs/classic.lua')
loadSource('Utils/WaitGroup.lua')
loadSource('Utils/Utils.lua')
Scan.Utils.onLoad = noop
loadSource('Utils/FStrings.lua')
loadSource('Customer/ChatHistory.lua')
loadSource('Customer/RequestTracking.lua')
loadSource('Customer/ClassMatching.lua')
loadSource('Customer/ChatScanner.lua')
loadSource('Customer/OrderGreetings.lua')
loadSource('Customer/OrderPage.lua')
local function character(profID, keywords, recipeConfigs)
    return {
        parent_professions = {[profID]={keywords=keywords, scanning_enabled=true}},
        professions = {[profID]={parentProfID=profID, recipes=recipeConfigs}},
    }
end
Scan.DB = {
    settings={inclusions='lf,need craft', exclusions='wts,crafting services', auto_reply_delay=1000,
        generic_request_keywords='lf crafter,lf craft,lf recraft'},
    analytics={enabled=false}, customers={}, listed_orders={},
    characters={
        ['Seller-Realm']=character(164, 'bs,blacksmith', {
            [101]={scan_state=1}, [103]={scan_state=1}, [104]={scan_state=0},
        }),
        ['Tailor-Realm']=character(197, 'tailor', {[102]={scan_state=1}}),
    },
}
local function reloadConfig() Scan.Scanner.LoadConfig(); timers={} end
local function match(message) return Scan.Scanner.GetCrafterForMessage('Buyer', message) end
local function countRows()
    local n=0; for _ in pairs(Scan.DB.listed_orders) do n=n+1 end; return n
end
local function order(id, customer) return {customerName=customer or 'Buyer', responseID=id} end
local function response(id) return Scan.OrderToResponse(order(id)) end
local function reset()
    now=1000
    Scan.DB.customers, Scan.DB.listed_orders, Scan.LIVE.customers = {}, {}, {}
    sent, shared, timers, refreshes, opened = {}, {}, {}, 0, 0
    Scan.auto_replies_enabled=false
end
local function scan(message, options, customer)
    Scan.OnMessage('CHAT_MSG_CHANNEL', message, customer or 'Buyer', 'Buyer-GUID', options)
end
local function flushTimers()
    local pending=timers; timers={}; for _, callback in ipairs(pending) do callback() end
end
local a,b,c=link(1001),link(1002),link(1003)
reloadConfig()

-- Unsolicited service replies must not become new requests or quick replies.
do
    local isAd=Scan.Scanner.IsCrafterAdvertisement
    local offers={
        'Send to, Scalescd, can craft '..a..'. Can log now. Kind tips please.',
        'Hi Mate, Send Order To : Unzalor - Commission Around 3k-15k '..a..' Max Quality - instant Craft',
        'Hi! I can craft/recraft '..a..' to max. You choose price.',
        'Can craft '..a..' for you', 'WTS '..a,
        'привет! могу скрафтить '..a, 'отправляйте заказ на Мастер '..a,
    }
    local previousWhisper,previousGreeting=Scan.QuickReplies.OnWhisper,Scan.QuickReplies.ShowOrderGreeting
    local offered=0
    Scan.QuickReplies.OnWhisper=function() offered=offered+1 end
    Scan.QuickReplies.ShowOrderGreeting=Scan.QuickReplies.OnWhisper
    for _, message in ipairs(offers) do
        reset()
        assert(isAd(message) and not match(message), 'crafter offer accepted: '..message)
        -- "Can craft [item]" whispered to us is a customer's question.
        local events = message:find('^Can craft') and {'CHAT_MSG_CHANNEL'}
            or {'CHAT_MSG_CHANNEL','CHAT_MSG_WHISPER','CHAT_MSG_BN_WHISPER'}
        for _, event in ipairs(events) do
            Scan.OnMessage(event,message,'Advertiser','Other-GUID')
        end
        flushTimers()
        assert(countRows()==0 and #sent==0 and offered==0, 'advertisement created a row/reply')
    end
    for _, message in ipairs({
        a, 'LF '..a, 'Need '..a, 'Can you craft '..a..'?', 'Hi, can u craft '..a..'?',
        'Can craft '..a..'?', 'Who can craft '..a..'?', 'I need someone who can craft '..a,
        'Send to who?', 'send to who', 'send order to which character',
        'Send order to Seller?', 'Where do I send '..a..'?',
        'Can you craft '..link(1001):gsub('Item 1001','I can craft')..'?',
    }) do
        assert(not isAd(message), 'customer question filtered: '..message)
        if message:find('|Hitem:',1,true) then
            assert(match(message), 'valid linked request stopped matching: '..message)
        end
    end
    reset()
    scan('LF '..a)
    local previousRows,previousHistory=countRows(),#Scan.DB.customers.Buyer.chat_history
    offered=0
    Scan.OnMessage('CHAT_MSG_WHISPER',offers[1],'Buyer','Buyer-GUID')
    assert(countRows()==previousRows and #Scan.DB.customers.Buyer.chat_history==previousHistory+1
        and #sent==0 and offered==0, 'existing customer advertisement offered an answer or lost history')
    local manual=Scan.OnMessage(nil,offers[1],'ManualBuyer',nil,
        {manualMatch=true,forceCrafterInfo={crafter='Seller-Realm',parentProfID=164}})
    assert(type(manual)=='table' and #sent==0, 'explicit manual matching was blocked/sent chat')
    Scan.QuickReplies.OnWhisper,Scan.QuickReplies.ShowOrderGreeting=previousWhisper,previousGreeting
end

-- Real scanner + banner + greeting integration. Binding code calls OnClick
-- directly; the frame can be hidden or refer to an older request by then.
do
    loadSource('Customer/AlertIcon.lua')
    local savedMenu=HironCraftScanScannerMenu
    local savedSetting,savedPlayerColor,savedCrafterColor=
        Scan.Utils.GetSetting,Scan.ColorizePlayerName,Scan.ColorizeCrafterName
    Scan.Utils.GetSetting=function(key) return key=='banner_timeout' and 60 or 0 end
    Scan.ColorizePlayerName=function(name) return name end
    Scan.ColorizeCrafterName=function(name) return name end
    local menu=setmetatable({pulseLocks={},shown=true},{__index=HironCraftScanScannerMenuMixin})
    local banner=setmetatable({shown=false,HighlightTexture={Hide=noop},SetPoint=noop,ClearAllPoints=noop},
        {__index=HironCraftScanBannerMixin})
    function banner:IsVisible() return self.shown and menu.shown end
    function banner:GetParent() return menu end
    function banner:Hide() self.shown=false; self:OnHide() end
    local anim={AlertTextFade={SetStartDelay=noop},AlertBGFade={SetStartDelay=noop},
        AlertBGShrink={SetStartDelay=noop}}
    function anim:Stop() banner:Hide() end
    function anim:Play() banner.shown=true end
    local display={SetText=noop,ClearAllPoints=noop,SetPoint=noop,SetJustifyH=noop}
    menu.PageButton={UpdateIcon=noop,AlertText=display,AlertBG=display,
        MinimapAlertAnim=anim,MinimapLoopPulseAnim={Stop=noop}}
    menu.AlertBGButton=banner
    HironCraftScanScannerMenu=menu
    local parent=Scan.DB.characters['Seller-Realm'].parent_professions[164]
    parent.visual_alert_enabled=true
    local function fresh()
        banner:Hide(); reset(); Scan.State.activeOrder=nil; menu.shown=true
    end
    local function key(button) banner:OnClick(button or 'LeftButton') end
    fresh()
    Scan.OnMessage('CHAT_MSG_WHISPER',a,'WhisperBuyer','Whisper-GUID')
    assert(countRows()==1 and not banner:IsVisible())
    key();key('MiddleButton');key('RightButton')
    assert(#sent==0 and opened==0 and countRows()==1,'hidden banner key acted on a whisper request')

    fresh()
    scan('LF '..a)
    assert(banner:GetOrder().customerName=='Buyer')
    Scan.OnMessage('CHAT_MSG_WHISPER',a,'WhisperBuyer','Whisper-GUID')
    assert(Scan.State.activeOrder.customerName=='WhisperBuyer')
    key()
    assert(#sent==1 and sent[1].customer=='Buyer', 'whisper retargeted an already displayed banner')
    assert(not banner:GetOrder(), 'sent banner kept an actionable request')
    key()
    assert(#sent==1,'repeated hidden-banner key sent another greeting')

    for _, invalidate in ipairs({
        function() banner:Hide() end,
        function() menu.shown=false end,
        function() response(101).requestToken='new-request' end,
        function() Scan.DB.listed_orders['Buyer-101']=nil end,
        function() Scan.DB.customers.Buyer.responses[101]={requestToken=response(101).requestToken} end,
        function()
            response(101).requestToken=nil
            menu:TriggerAlert('legacy',order(101))
            response(101).time=response(101).time+1
        end,
    }) do
        fresh();scan('LF '..a);invalidate();key()
        assert(#sent==0,'hidden/deleted/reused request was sent by an old banner')
    end
    -- Two requests in the same second: the first keeps the banner, the
    -- second waits its turn instead of replacing it.
    fresh()
    scan('LF '..a)
    scan('LF '..a,nil,'Second')
    assert(banner:GetOrder().customerName=='Buyer','the second request replaced the first banner')
    assert(Scan.State.activeOrder.customerName=='Buyer','a key press would act on the hidden request')
    assert(menu:GetQueuedAlertCount()==1,'the second request was not kept for later')
    key()
    assert(#sent==1 and sent[1].customer=='Buyer','the first banner did not answer the first customer')
    assert(banner:GetOrder() and banner:GetOrder().customerName=='Second',
        'the waiting request did not get the banner after the first was answered')
    key()
    assert(#sent==2 and sent[2].customer=='Second','the second banner did not answer the second customer')
    assert(not banner:GetOrder() and menu:GetQueuedAlertCount()==0)
    -- A banner that timed out passes the turn on as well.
    fresh()
    scan('LF '..a)
    scan('LF '..a,nil,'Second')
    banner:Hide();menu:ShowNextAlert()
    assert(banner:GetOrder() and banner:GetOrder().customerName=='Second','a timed-out banner kept the next one waiting')
    -- A waiting request answered from the order list does not come back.
    fresh()
    scan('LF '..a)
    scan('LF '..a,nil,'Second')
    menu:ClearAlert(order(101,'Second'))
    assert(menu:GetQueuedAlertCount()==0,'an answered request stayed in the queue')
    key()
    assert(not banner:GetOrder(),'an answered request came back on the banner')
    fresh();scan('LF '..a);key('MiddleButton')
    assert(#sent==0 and opened==1,'visible banner could not open chat without sending')
    fresh();scan('LF '..a);key('RightButton')
    assert(#sent==0 and countRows()==0,'visible banner could not dismiss its order')
    fresh()
    parent.visual_alert_enabled=nil
    HironCraftScanScannerMenu=savedMenu
    Scan.Utils.GetSetting,Scan.ColorizePlayerName,Scan.ColorizeCrafterName=
        savedSetting,savedPlayerColor,savedCrafterColor
end
print('Reply safety tests passed (crafter ads, hidden banners, whisper retargeting, stale requests).')

-- A broad request creates one click-only placeholder row. A later profession
-- or item clarification replaces it even when the customer does not repeat LF.
reset()
scan('LF CRAFTER')
local generalID=Scan.Scanner.GENERAL_REQUEST_ID
local general=response(generalID)
assert(general and general.generic_request and countRows()==1,
    'generic craft request did not create its placeholder row')
assert(#sent==0, 'generic craft request sent a greeting without a click')
Scan.GreetCustomer('LeftButton',order(generalID))
assert(#sent==1 and sent[1].message==greetings.GREETING_GENERIC_REQUEST
    and general.greeting_sent, 'generic greeting was not sent by the row click')
Scan.OnMessage('CHAT_MSG_WHISPER','bs','Buyer','Buyer-GUID')
assert(not response(generalID) and response(164) and countRows()==1,
    'profession clarification did not replace the generic row')
assert(response(164).destination_only_greeting,
    'generic-request clarification was offered another full introduction')
Scan.GreetCustomer('LeftButton',order(164))
assert(#sent==2 and sent[2].message=='Profession 164 Send to Seller.',
    'generic-request clarification did not use the compact destination reply')

reset()
scan('LF RECRAFT')
Scan.OnMessage('CHAT_MSG_WHISPER',a..b,'Buyer','Buyer-GUID')
assert(not response(generalID) and response(101) and response(102) and countRows()==2,
    'multi-item clarification did not replace the generic row with item rows')

reset()
scan('WTS LF CRAFTER')
assert(countRows()==0 and next(Scan.DB.customers)==nil,
    'generic request bypassed the global exclusions')
scan('LF')
assert(countRows()==0, 'ordinary inclusion without a generic phrase created a row')
scan('LF crafting')
assert(countRows()==0, 'generic phrase matched a longer non-request word')
scan('LF CRAFTER?')
assert(countRows()==1, 'punctuation prevented a generic request match')

-- An explicit item never falls back to the broad placeholder when its recipe
-- is unknown or is not enabled for scanning.
for _, explicitLink in ipairs({link(9999), link(1005)}) do
    reset()
    local message = 'LF craft ' .. explicitLink
    assert(not Scan.Scanner.IsGenericRequest(message),
        'linked item was classified as a generic request: ' .. message)
    scan(message)
    assert(countRows()==0 and next(Scan.DB.customers)==nil,
        'unmatched linked item created a generic request: ' .. message)
end

for _, message in ipairs({a, 'LW ' .. a, 'LF ' .. a, 'need craft ' .. a}) do
    local crafter,id,recipe=match(message)
    assert(crafter and id==1001 and recipe.recipeID==101, 'tracked link was not recognized: ' .. message)
end
assert(match('LF bs'), 'legacy keyword-only matching must remain available')
for _, message in ipairs({'LW', 'bs', '[Item 1001]', 'item:1001:0', link(9999), link(1005),
    'WTS ' .. a, 'LF crafting services ' .. a}) do
    assert(not match(message), 'untracked/non-link/excluded request accepted: ' .. message)
end
Scan.DB.settings.scan_item_links_without_keywords=false
assert(not match(a) and match('LF ' .. a), 'opt-out must preserve legacy LF scanning')
Scan.DB.settings.scan_item_links_without_keywords=true
assert(match(a), 'setting must take effect without reload')
local parent=Scan.DB.characters['Seller-Realm'].parent_professions[164]
parent.exclusions='selling'
assert(not match('selling ' .. a) and not match('LF selling ' .. a), 'profession exclusions bypassed')
parent.exclusions=nil
parent.scanning_enabled=false
assert(not match(a), 'disabled profession accepted')
parent.scanning_enabled=true
local prof=Scan.DB.characters['Seller-Realm'].professions[164]
prof.recipes[101].scan_state=0
assert(not match(a), 'disabled recipe accepted from stale index')
prof.recipes[101].scan_state=1
prof.recipes[101].required_concentration=50; prof.concentration=10
assert(not match(a), 'concentration requirement bypassed')
prof.concentration=50
assert(match(a))
prof.recipes[101].required_concentration=nil; prof.concentration=nil
local _,_,_, matches=match(link(9999) .. a .. a .. link(1001, '12:34') .. b .. link(1004))
assert(#matches==2 and matches[1].itemID==1001 and matches[2].itemID==1002,
    'deduplicate item variants/quality outputs and preserve first-link order')
assert(matches[1].itemLink==a and matches[2].itemLink==b, 'original link markup changed')
assert(not match('WTS ' .. a .. b), 'multi-item scan bypassed global exclusions')
parent.character_disabled=true
reloadConfig()
assert(not match(a), 'disabled character entered the item index')
parent.character_disabled=nil
reloadConfig()

-- Multiple copies and bonus variants of the same item still mean one request.
reset()
scan(a .. a .. link(1001, '12:34'))
assert(countRows()==1 and #shared==1)
Scan.GreetCustomer('LeftButton', order(101))
assert(#sent==1 and response(101).greeting_sent)
scan(a .. a); scan('LW ' .. link(1001, '12:34'))
assert(countRows()==1 and #sent==1, 'repeated request resent a greeting or made a row')

-- One row per unique craft, one history entry / sync packet for the whole request.
reset()
scan(a .. a .. b .. b .. c)
assert(countRows()==3 and #shared==1 and refreshes==1)
assert(#Scan.DB.customers.Buyer.chat_history==1, 'multi-item request duplicated chat history')
assert(shared[1][7][101]==response(101).requestToken and shared[1][7][102]==response(102).requestToken)
assert(response(101).requestToken~=response(102).requestToken, 'requests must have distinct identities')
scan(a .. b .. c)
assert(countRows()==3 and #Scan.DB.customers.Buyer.chat_history==2, 'repeat duplicated rows or lost the new chat message')
Scan.GreetCustomer('LeftButton', order(102)) -- Clicking any row sends the block in source order.
assert(#sent==3)
assert(sent[1].message=='Hi! Send ' .. a .. ' to Seller.')
assert(sent[2].message==b .. ' Send to Tailor.')
assert(sent[3].message==c .. ' Send to Seller.')
for _, id in ipairs({101,102,103}) do
    assert(response(id).greeting_sent and response(id).conversationCharacter=='Seller-Realm')
    Scan.GreetCustomer('LeftButton', order(id))
end
assert(#sent==3 and opened==3, 'already answered rows must open chat, not resend the block')
scan(a .. a .. b .. c)
assert(countRows()==3 and #sent==3)

-- "send to Lavu" looks like a crafter's pitch, but from a customer we greeted
-- it is their answer: the second mark is set, and no request is made of it.
reset()
scan(a)
Scan.GreetCustomer('LeftButton', order(101))
assert(response(101).greeting_sent and not response(101).customer_answered)
Scan.OnMessage('CHAT_MSG_WHISPER','send to seller','Buyer','Buyer-GUID')
assert(response(101).customer_answered, 'a customer answering "send to <crafter>" got no second mark')
assert(countRows()==1 and #sent==1, 'the answer made a request or sent something')
-- A stranger saying the same is still an ad and leaves nothing behind.
Scan.OnMessage('CHAT_MSG_WHISPER','send to seller','Stranger','Stranger-GUID')
assert(not Scan.DB.customers.Stranger, 'an ad from a stranger created a customer')

-- "can craft [link]" whispered without its "?" (sent as the next line) is a
-- customer's question and makes the row, from anyone.
reset()
scan(a)
Scan.GreetCustomer('LeftButton', order(101))
Scan.OnMessage('CHAT_MSG_WHISPER','can craft '..b,'Buyer','Buyer-GUID')
assert(response(102), 'a customer asking "can craft [item]" got no row')
Scan.OnMessage('CHAT_MSG_WHISPER','can craft '..b,'Newcomer','Newcomer-GUID')
assert(Scan.DB.customers.Newcomer and Scan.DB.customers.Newcomer.responses[102],
    'a first whisper "can craft [item]" got no row')
-- In trade chat the same words are a crafter's pitch.
scan('Can craft '..b,nil,'Pitcher')
assert(not Scan.DB.customers.Pitcher, 'a "can craft [item]" pitch in trade became a customer')

-- Old default keywords that are everyday words ("no crest") are retired;
-- a list the crafter edited stays as it is.
Scan.DB.characters['Seller-Realm'].parent_professions[164].keywords='Enchanter, Crest'
Scan.DB.characters['Tailor-Realm'].parent_professions[197].keywords='Tailor, Crest'
assert(Scan.Scanner.RetireOldDefaultKeywords()==1)
assert(Scan.DB.characters['Seller-Realm'].parent_professions[164].keywords==nil
    and Scan.DB.characters['Tailor-Realm'].parent_professions[197].keywords=='Tailor, Crest')
Scan.DB.characters['Seller-Realm'].parent_professions[164].keywords='bs,blacksmith'
Scan.DB.characters['Tailor-Realm'].parent_professions[197].keywords='tailor'
reloadConfig()

-- Rows in progress - the customer answered, the order is not delivered - carry
-- a soft yellow wash; nothing else does.
reset()
scan(a)
do
    local previousStatus=Scan.OrderFulfillment
    local status=nil
    Scan.OrderFulfillment={GetStatus=function() return status end}
    local textures=0
    local rowFrame=setmetatable({order=order(101)},{__index=HironCraftScanCrafterOrderListElementMixin})
    function rowFrame:CreateTexture()
        textures=textures+1
        local t={shown=true}
        function t:SetAllPoints() end
        function t:SetColorTexture(...) self.color={...} end
        function t:SetShown(v) self.shown=v end
        return t
    end
    rowFrame:UpdateProgressHighlight()
    assert(textures==0 and not Scan.IsOrderInProgress(order(101)), 'a row nobody answered was highlighted')
    response(101).customer_answered=true
    rowFrame:UpdateProgressHighlight()
    assert(rowFrame.ProgressTexture.shown and rowFrame.ProgressTexture.color[1]==1
        and rowFrame.ProgressTexture.color[4]<=0.15, 'an answered row was not softly highlighted')
    status={status='claimed'}
    rowFrame:UpdateProgressHighlight()
    assert(rowFrame.ProgressTexture.shown, 'an order being crafted lost its highlight')
    status={status='fulfilled'}
    rowFrame:UpdateProgressHighlight()
    assert(not rowFrame.ProgressTexture.shown and textures==1, 'a delivered order stayed highlighted')
    Scan.OrderFulfillment=previousStatus
end

-- A link turned into plain text by a chat addon or a paste still names the
-- craft: "[Silvermoon Agent's Deflectors |A:...|a]". In brackets it counts
-- like a link; bare names only when the message asks for a craft.
recipes[101].name="Silvermoon Agent's Deflectors"
reloadConfig()
reset()
scan("LFC [Silvermoon Agent's Deflectors ||A:Professions-ChatIcon-Quality-Tier1:17:15::1||a]")
assert(countRows()==1 and response(101), 'a pasted item name in brackets made no row')
reset()
scan("LF silvermoon agent's deflectors pls")
assert(countRows()==1 and response(101), 'an item name after LF made no row')
reset()
scan("my Silvermoon Agent's Deflectors look great")
assert(countRows()==0, 'talk about an item became a request')
reset()
scan("LF [Silvermoon Agent's Deflectorsxx]")
assert(countRows()==0, 'part of a longer word was taken for the item')
reset()
scan("LF [Silvermoon Agent's Deflectors] " .. a)
assert(countRows()==1 and response(101), 'the same craft by name and by link made two rows')
recipes[101].name=nil
reloadConfig()

-- One machine, two sides: requests of the other faction stay in the data (so
-- statuses still reach the account that talked) but are not listed or
-- announced on a character that cannot whisper them.
reset()
scan('LF '..a,nil,'HordeBuyer')
do
    local previousSide=Scan.QuickReplies.IsOtherSide
    Scan.QuickReplies.IsOtherSide=function(_,info) return info==Scan.DB.customers.HordeBuyer end
    local hordeRow=order(101,'HordeBuyer')
    assert(not Scan.IsHiddenOtherSideOrder(hordeRow), 'the other side was hidden without the setting')
    Scan.DB.settings.hide_other_faction_orders=true
    assert(Scan.IsHiddenOtherSideOrder(hordeRow), 'the other side was not hidden')
    assert(Scan.DB.listed_orders[Scan.OrderToOrderID(hordeRow)], 'hiding removed the row underneath')
    assert(not Scan.IsHiddenOtherSideOrder(order(101)), 'a customer of this side was hidden')
    Scan.DB.settings.hide_other_faction_orders=false
    assert(not Scan.IsHiddenOtherSideOrder(hordeRow), 'the setting did not show the other side again')
    Scan.DB.settings.hide_other_faction_orders=nil
    Scan.QuickReplies.IsOtherSide=previousSide
end
-- The linked account tells the customer's side along with the request, so a
-- race that picks its side is known here too.
reset()
HironCraftScanComm.applying_remote_state=true
Scan.OnMessage('CHAT_MSG_CHANNEL','LF '..a,'SharedBuyer','Shared-GUID',{customerFaction='Horde'})
HironCraftScanComm.applying_remote_state=false
assert(Scan.DB.customers.SharedBuyer and Scan.DB.customers.SharedBuyer.faction=='Horde',
    'the side told by the linked account was lost')

-- "lf bs/tailor" names two professions: a row for each, answered together.
reset()
scan('lf bs/tailor')
assert(countRows()==2 and response(164) and response(197), 'a list of professions made one row')
assert(response(164).crafterFullName=='Seller-Realm' and response(197).crafterFullName=='Tailor-Realm')
assert(#shared==1, 'one message was shared as two requests')
Scan.GreetCustomer('LeftButton', order(164))
assert(#sent==2 and sent[2].message=='Profession 197 Send to Tailor.',
    'the professions were not answered together: '..tostring(sent[2] and sent[2].message))
-- Commas, "&" and a question mark separate words like spaces do.
reset()
scan('LF bs, tailor?')
assert(countRows()==2, 'a comma or a question mark hid a profession')
-- The screenshot's message: "tailor" and "jc" are also words that name a
-- profession for equipment; with no slot they must not narrow to one.
reset()
scan('lf bs/tailor/jc')
assert(countRows()==2 and response(164) and response(197), '"lf bs/tailor/jc" did not make a row per profession')
reset()
scan('LF tailoring')
assert(countRows()==1 and response(197), 'a profession named in full lost its row')
-- "a tailor who can craft me a smith tool": the second profession names the
-- item, not another crafter to ask.
reset()
scan('LF tailor that can craft me bs tool for a low price!')
assert(countRows()==1 and response(197) and not response(164), 'a tool of a profession became a second request')
reset()
scan('LF tailor, need a tool for bs')
assert(countRows()==1 and response(197), '"tool for <profession>" became a second request')
-- One profession stays one row.
reset()
scan('LF bs/blacksmith')
assert(countRows()==1 and response(164), 'two words for one profession made two rows')
-- A keyword inside another word still does not count.
reset()
scan('LF absolutely nothing')
assert(countRows()==0, 'a keyword inside a word was matched')

-- Recipe links count like item links: "LF crafter [Leatherworking: X] and
-- [Inscription: Y]" is two requests, not the first one only. A recipe this
-- account knows gets its exact row, an unknown one a profession row.
reset()
local function recipeLink(id, text)
    return '|cffffd000|Henchant:' .. id .. '|h[' .. text .. ']|h|r'
end
local previousProfessionByRecipe=C_TradeSkillUI.GetProfessionInfoByRecipeID
C_TradeSkillUI.GetProfessionInfoByRecipeID=function(id)
    if id==999 then return {parentProfessionID=197, professionID=197} end
end
scan('LF crafter ' .. recipeLink(101, 'Blacksmithing: Item 1001') .. ' and '
    .. recipeLink(999, 'Tailoring: Unknown Robe'))
assert(countRows()==2 and response(101) and response(197),
    'only the first recipe link of the message made a row')
assert(response(101).crafterFullName=='Seller-Realm' and response(197).crafterFullName=='Tailor-Realm')
assert(#shared==1, 'two recipe links were shared as two requests')
Scan.GreetCustomer('LeftButton', order(101))
assert(#sent==2 and sent[2].message=='Profession 197 Send to Tailor.',
    'the second recipe was not answered with the first: '..tostring(sent[2] and sent[2].message))
assert(response(101).greeting_sent and response(197).greeting_sent)
-- A recipe link and an item link of the same craft are one request.
reset()
scan('LF ' .. recipeLink(101, 'Blacksmithing: Item 1001') .. ' ' .. a)
assert(countRows()==1 and response(101), 'the same craft linked twice made two rows')
-- A bare recipe link is a request too, known to us or not: people often post
-- just the recipe of the gear they want.
reset()
scan(recipeLink(999, 'Tailoring: Unknown Robe'))
assert(countRows()==1 and response(197), 'a bare unknown recipe link asked for nothing')
reset()
scan(recipeLink(101, 'Blacksmithing: Item 1001'))
assert(countRows()==1 and response(101), 'a bare known recipe link asked for nothing')
-- A crafter showing off what they make is not a customer.
reset()
scan('Can craft ' .. recipeLink(999, 'Tailoring: Unknown Robe'))
scan('WTS ' .. recipeLink(999, 'Tailoring: Unknown Robe'))
assert(countRows()==0, 'a crafter ad with a recipe link became a request')
-- Without the setting for bare links, LF is still needed.
reset()
Scan.DB.settings.scan_item_links_without_keywords=false
scan(recipeLink(999, 'Tailoring: Unknown Robe'))
assert(countRows()==0, 'a bare link was taken with bare links turned off')
Scan.DB.settings.scan_item_links_without_keywords=nil
C_TradeSkillUI.GetProfessionInfoByRecipeID=previousProfessionByRecipe

reset()
scan(a .. b)
Scan.DismissOrder(order(101))
Scan.GreetCustomer('LeftButton', order(102))
assert(#sent==1 and sent[1].message=='Hi! Send ' .. b .. ' to Tailor.', 'dismissed row was sent')

reset()
scan(a .. b)
Scan.DismissOrder(order(101))
scan(a) -- A new job now occupies the old response ID; its token must not join B's old group.
Scan.GreetCustomer('LeftButton', order(102))
assert(#sent==1 and not response(101).greeting_sent and response(102).greeting_sent)

reset()
scan(a .. b)
response(101).greetingGroup=false -- A malformed legacy saved field must not crash the click.
Scan.GreetCustomer('LeftButton', order(101))
assert(#sent==1 and response(101).greeting_sent and not response(102).greeting_sent)
table.insert(response(102).greetingGroup, false)
Scan.GreetCustomer('LeftButton', order(102))
assert(#sent==2 and response(102).greeting_sent)

-- Linked accounts retain the identity of each row, even if they monitor only a subset.
reset()
scan(a .. b, {requestTokens={[101]='peer-a', ['102']='peer-b'}})
assert(response(101).requestToken=='peer-a' and response(102).requestToken=='peer-b')
reset()
scan(a, {requestTokens={[101]='peer-a', [102]='peer-b'}})
assert(response(101).requestToken=='peer-a')
reset()
scan(a .. b, {requestToken='peer-a', requestTokens={[101]='peer-a'}})
assert(response(101).requestToken=='peer-a' and response(102).requestToken~='peer-a',
    'item missing from a peer token map reused the first item identity')

-- Obsolete flags cannot enable automatic sending, including proxied and
-- multi-item requests. Only a later explicit row click may greet the customer.
for _, message in ipairs({a, a .. a .. c, a .. b}) do
    reset(); Scan.auto_replies_enabled=true
    scan(message)
    scan(message)
    flushTimers()
    assert(#sent==0 and #timers==0, 'scanner scheduled/sent an automatic greeting')
    assert(Scan.SendOrderGreeting(order(101))==false, 'unguarded greeting call was accepted')
    assert(not response(101).greeting_sent)
    Scan.GreetCustomer('LeftButton', order(101))
    assert(#sent>0 and response(101).greeting_sent)
end
reset(); Scan.auto_replies_enabled=true
scan(a .. c, {requestTokens={[101]='remote-a', [103]='remote-c'}})
flushTimers()
assert(#sent==0, 'linked-account data caused a player whisper')
Scan.DismissOrder(order(101))
flushTimers()
assert(#sent==0, 'dismissed request sent without a click')
reset()
-- Real-world recraft links carry bonuses, modifiers, a crafter GUID and a
-- quality atlas. The old whitespace splitter cut inside the first hyperlink.
local recraftLink='|cnIQ4:|Hitem:1001::::::::90:63::13:6:12245:13760:12497:13766:13658:8792:7:28:3615:29:36:30:32:38:8:40:2604:44:275385:46:245782::::Player-0000-00000000:|h[Thalassian Competitor\'s Cloth Cloak |A:Professions-ChatIcon-Quality-Tier5:17:15::1|a]|h|r'
local secondRecraft=recraftLink:gsub('item:1001:', 'item:1003:'):gsub('Cloth Cloak', 'Cloth Treads')
greetings.GREETING_I_CAN_CRAFT_ITEM='Hi! Send order on this char. I can craft/recraft {item}. You choose the price.'
scan('LRC' .. recraftLink .. secondRecraft)
assert(countRows()==2)
-- Reproduce the already persisted fragments from the affected version, even
-- though the active character has not changed since those replies were built.
response(101).message={'Hi! ' .. recraftLink:sub(1,230), recraftLink:sub(231) .. ' You choose the price.'}
response(101).itemLink=recraftLink
response(103).itemLink=secondRecraft
Scan.GreetCustomer('LeftButton', order(101))
assert(#sent==2 and response(101).greeting_sent and response(103).greeting_sent)
assert(sent[1].message:find(a, 1, true) and sent[2].message==c .. ' Send to Seller.',
    'saved broken replies were not rebuilt using complete base-item links')

reset(); Scan.auto_replies_enabled=true
local createItem=Item.CreateFromItemID
local pendingLoads={}
Item.CreateFromItemID=function(_, id) return {ContinueOnItemLoad=function(_, callback)
    assert(not pendingLoads[id], 'duplicate link caused another item-cache load')
    pendingLoads[id]=callback
end} end
scan('LRC' .. recraftLink .. recraftLink .. secondRecraft)
assert(countRows()==0 and #timers==0)
pendingLoads[1003]()
assert(countRows()==0 and #timers==0, 'partially loaded group was sent or listed')
pendingLoads[1001]()
assert(countRows()==2 and #timers==0)
flushTimers()
assert(#sent==0, 'item-cache completion sent a greeting without a click')
Scan.GreetCustomer('LeftButton', order(101))
assert(#sent==2 and response(101).greeting_sent and response(103).greeting_sent,
    'loaded long-link batch did not send exactly once on click')
Item.CreateFromItemID=createItem

-- Deferred linked scans must retain the remote context after the receive
-- handler returns, including replacement identities and multi-item batches.
local originalShare=HironCraftScanComm.ShareCustomerOrder
for _,message in ipairs({a,a..b}) do
    reset();scan(message);Scan.GreetCustomer('LeftButton',order(101))
    now=1031
    local callbacks={}
    Item.CreateFromItemID=function(_,id) return {
        GetItemLink=function() return link(id) end,
        ContinueOnItemLoad=function(_,callback) callbacks[#callbacks+1]=callback end,
    } end
    HironCraftScanComm.ShareCustomerOrder=function()
        assert(HironCraftScanComm.applying_remote_state, 'deferred linked order escaped its remote context')
    end
    HironCraftScanComm.applying_remote_state=true
    scan(message,{requestTokens={[101]='linked-retry-a',[102]='linked-retry-b'},
        chatEntry={message=message,receivedAt=1031,syncID='linked-retry',inquiry={id='linked-retry-a',startedAt=1031}}})
    HironCraftScanComm.applying_remote_state=false
    local sentBefore=#sent
    for _,callback in ipairs(callbacks) do callback() end
    assert(response(101).requestToken=='linked-retry-a' and not response(101).greeting_sent)
    if message~=a then assert(response(102).requestToken=='linked-retry-b') end
    assert(not HironCraftScanComm.applying_remote_state and #sent==sentBefore)
    Item.CreateFromItemID=createItem
    HironCraftScanComm.ShareCustomerOrder=originalShare
end

-- A long greeting may require extra whispers, but never an incomplete link.
reset()
local namedLink='|cnIQ4:|Hitem:1001:0|h[A long item name with spaces]|h|r'
local text=string.rep('word ',43) .. namedLink .. ' suffix\n' .. a .. b
local pieces=Scan.Utils.SplitResponse(text)
assert(#pieces==3 and pieces[2]:find(namedLink, 1, true), 'named-color link was split at a display-name space')
assert(Scan.Utils.SendResponses(pieces, 'Buyer')==false and #sent==0,
    'player whisper did not require an explicit user action')
assert(Scan.Utils.SendResponses(pieces, 'Buyer', true))
assert(#sent==3)
local unicode=string.rep('я',300)
local unicodePieces=Scan.Utils.SplitResponse(unicode)
assert(table.concat(unicodePieces)==unicode)
for _, piece in ipairs(unicodePieces) do
    assert(#piece<=255 and utf8.len(piece), 'split cut through a UTF-8 character')
end
local before=#sent
assert(Scan.Utils.SendResponses({'valid first line', '|Hitem:1001:0|h[broken'}, 'Buyer', true)==false)
assert(#sent==before, 'invalid later line was detected only after partially sending the group')
local oversizedLink=recraftLink:gsub('Player%-0000%-00000000', string.rep('9',120))
assert(Scan.Utils.SendResponses(Scan.Utils.SplitResponse(oversizedLink), 'Buyer', true)==false)
assert(#sent==before, 'oversized indivisible link was sent')

reset()
Scan.DB.settings.ignored={Buyer=true}
scan(a .. b)
assert(countRows()==0 and #shared==0, 'ignored customer bypassed exclusion')
print('Item-link request tests passed (filters, unique rows, grouped replies, tokens, timers, long links, saved repair).')

-- Retry the SAME unanswered craft after 30 seconds from the actual greeting,
-- not the initial channel request. Replace the row identity without sending.
reset();Scan.DB.settings.ignored=nil
scan(a);now=1010;Scan.GreetCustomer('LeftButton',order(101))
local originalToken=response(101).requestToken
now=1039;scan(a)
assert(response(101).requestToken==originalToken and response(101).greeting_sent)
now=1040;scan(a)
assert(countRows()==1 and not response(101).greeting_sent and not response(101).customer_answered)
assert(response(101).requestToken~=originalToken and response(101).time==1040)
assert(#Scan.DB.customers.Buyer.chat_history==3, 'repeat history was lost')
flushTimers();assert(#sent==1, 'repeat search sent a greeting automatically')
Scan.GreetCustomer('LeftButton',order(101));assert(#sent==2 and response(101).greetingSentAt==1040)
Scan.OnMessage('CHAT_MSG_WHISPER','sent','Buyer','Buyer-GUID')
now=1080;local answeredToken=response(101).requestToken;scan(a)
assert(response(101).requestToken==answeredToken and response(101).customer_answered,
    'an active answered conversation was reopened as unanswered')

reset();scan(a);Scan.GreetCustomer('LeftButton',order(101))
now=1031;scan(a)
assert(not response(101).greeting_sent)
Scan.OnMessage('CHAT_MSG_WHISPER','sent','Buyer','Buyer-GUID')
assert(response(101).customer_answered and response(101).greeting_sent and #sent==1,
    'late answer to the first greeting was lost while its replacement was only proposed')

reset();scan(a);Scan.GreetCustomer('LeftButton',order(101))
now=1031;scan(b);Scan.GreetCustomer('LeftButton',order(102))
Scan.OnMessage('CHAT_MSG_WHISPER','hi','Buyer','Buyer-GUID')
assert(not response(101).customer_answered and response(102).customer_answered, 'reply checked an older inquiry')
local replyEntry=Scan.DB.customers.Buyer.chat_history[#Scan.DB.customers.Buyer.chat_history]
assert(#replyEntry.replyContext.members==1 and replyEntry.replyContext.members[1].responseID==102)
Scan.OnMessage('CHAT_MSG_WHISPER','hi','Buyer','Buyer-GUID')
Scan.OnMessage('CHAT_MSG_WHISPER','sent','Buyer','Buyer-GUID')
assert(#Scan.Utils.GetUniqueChatHistory(Scan.DB.customers.Buyer.chat_history)==5, 'short/repeated replies disappeared')

reset();scan(a);Scan.GreetCustomer('LeftButton',order(101))
now=1029;scan(b);Scan.GreetCustomer('LeftButton',order(102))
Scan.OnMessage('CHAT_MSG_WHISPER','sent both','Buyer','Buyer-GUID')
assert(response(101).customer_answered and response(102).customer_answered, 'nearby related requests split too early')
reset();scan(a..b);Scan.GreetCustomer('LeftButton',order(102))
Scan.OnMessage('CHAT_MSG_WHISPER','sent both','Buyer','Buyer-GUID')
assert(response(101).customer_answered and response(102).customer_answered, 'multi-item inquiry was not answered together')
reset();scan(a);Scan.GreetCustomer('LeftButton',order(101))
now=1031;scan(b) -- no greeting for the later inquiry
Scan.OnMessage('CHAT_MSG_WHISPER','sent','Buyer','Buyer-GUID')
assert(response(101).customer_answered and not response(102).customer_answered, 'ungreeted search stole the active reply')

-- A craft request whispered after an earlier completed job must create the new
-- row first and only then offer its generated greeting. This reproduces the
-- real wording that used to leave the row without a Quick Reply.
local previousFulfillment=Scan.OrderFulfillment
local previousShowGreeting=Scan.QuickReplies.ShowOrderGreeting
local previousInclusions=Scan.DB.settings.inclusions
local previousPermissive=Scan.DB.settings.permissive_matching
local previousClassMatching=Scan.DB.settings.match_customer_class
local previousKeywords=Scan.DB.characters['Seller-Realm'].parent_professions[164].keywords
reset()
Scan.DB.settings.inclusions='lf,can'
Scan.DB.settings.permissive_matching=true
Scan.DB.settings.match_customer_class=false
Scan.DB.characters['Seller-Realm'].parent_professions[164].keywords='bs,blacksmith,wrist'
Scan.UpdateHasMatchStyle()
reloadConfig()
scan('LF bs')
local completedToken=response(164).requestToken
Scan.OrderFulfillment={
    Status={Fulfilled='fulfilled',Rejected='rejected',Failed='failed'},
    GetStatus=function() return {status='fulfilled'} end,
}
local offered=0
Scan.QuickReplies.ShowOrderGreeting=function(_,customer,message,customerInfo,responses)
    offered=offered+1
    assert(customer=='Buyer' and message=='can you also do wrist?')
    assert(customerInfo==Scan.DB.customers.Buyer and #responses==1)
    local current=response(164)
    assert(responses[1]==current and current.requestToken~=completedToken,
        'Quick Reply received the completed response instead of the new row')
    assert(not current.greeting_sent and current.customer_answered,
        'incoming new request consumed its pending greeting')
    assert(current.destination_only_greeting,
        'follow-up craft request was offered another full introduction')
    return true
end
now=1100
Scan.OnMessage('CHAT_MSG_WHISPER','can you also do wrist?','Buyer','Buyer-GUID')
assert(offered==1 and countRows()==1, 'new whisper row did not trigger its Quick Reply')
assert(Scan.SendOrderGreeting(order(164),true))
assert(#sent==1 and sent[1].message=='Profession 164 Send to Seller.',
    'follow-up profession request did not use the compact destination reply')
assert(response(164).greeting_sent and not response(164).destination_only_greeting,
    'compact destination reply did not finish greeting state')
Scan.OrderFulfillment=previousFulfillment
Scan.QuickReplies.ShowOrderGreeting=previousShowGreeting
Scan.DB.settings.inclusions=previousInclusions
Scan.DB.settings.permissive_matching=previousPermissive
Scan.DB.settings.match_customer_class=previousClassMatching
Scan.DB.characters['Seller-Realm'].parent_professions[164].keywords=previousKeywords
Scan.UpdateHasMatchStyle()
reloadConfig()

-- The manual menu proposes a greeting without sending. It must use the
-- chosen crafter even when the selected text matches a different profession.
reset()
Scan.DB.settings.explanations={}
local getSorted, colorCrafter, colorProfession, professionName=Scan.GetSortedCrafters, Scan.ColorizeCrafterName,
    Scan.Utils.ColorizeProfessionName, Scan.Utils.ProfessionNameByID
Scan.ColorizeCrafterName=function(name) return name end
Scan.Utils.ColorizeProfessionName=function(_,name) return name end
Scan.Utils.ProfessionNameByID=function(id) return tostring(id) end
Scan.GetSortedCrafters=function() return {{name='Seller-Realm',parentProfessionID=164},
    {name='Tailor-Realm',parentProfessionID=197}} end
local menus={}
Menu={ModifyMenu=function(name,callback) menus[name]=callback end}
loadSource('Customer/CustomExplanations.lua')
Scan.CONST.TEXT.MANUAL_MATCH='Match %s %s'
HironCraftScan_CustomExplanationsButtonMixin.Init({SetupMenu=noop})
local buttons={}
local root={CreateDivider=noop,CreateTitle=function() return {SetTooltip=noop} end}
function root:CreateButton(label,click)
    buttons[#buttons+1]={label=label,click=click}
    return {SetTooltip=noop,CreateButton=root.CreateButton,CreateDivider=noop,CreateTitle=root.CreateTitle}
end
local chatReads=0
local manualOffers={}
local manualBanners=0
local oldManualColor=Scan.ColorizePlayerName
Scan.ColorizePlayerName=function(name) return name end
local oldManualTrigger,oldManualConfig=HironCraftScanScannerMenu.TriggerAlert,Scan.QuickReplies.GetConfig
HironCraftScanScannerMenu.TriggerAlert=function() manualBanners=manualBanners+1 end
Scan.DB.characters['Seller-Realm'].parent_professions[164].visual_alert_enabled=true
Scan.DB.characters['Tailor-Realm'].parent_professions[197].visual_alert_enabled=true
Scan.QuickReplies.ShowOrderGreeting=function(_,customer,_,_,responses)
    manualOffers[#manualOffers+1]={customer=customer,response=responses[1]}
    return true
end
C_ChatInfo={GetChatLineText=function(id) assert(id==44);chatReads=chatReads+1;return 'LF '..a end,
    GetChatLineSenderGUID=function() return 'Manual-GUID' end}
menus.MENU_UNIT_FRIEND(nil,root,{chatTarget='ManualBuyer-Realm',lineID='44'})
assert(#sent==0 and countRows()==0, 'opening the manual menu took an action')
-- Pick menu entries by what they say, not by where they sit.
local function menuButton(text)
    for _,entry in ipairs(buttons) do
        if tostring(entry.label):find(text,1,true) then return entry end
    end
end
menuButton('Tailor-Realm').click()
-- A line the crafter linked by hand raises the normal request banner; the
-- greeting card belongs to whispers the customer actually sent.
assert(#sent==0 and chatReads==1)
assert(#manualOffers==0,'a hand-linked line was answered with a quick reply')
assert(manualBanners==1,'a hand-linked line raised no request banner')
local manualResponse=Scan.DB.customers['ManualBuyer-Realm'].responses[197]
assert(manualResponse.crafterFullName=='Tailor-Realm' and not manualResponse.itemID and not manualResponse.greeting_sent)
assert(Scan.SendOrderGreeting({customerName='ManualBuyer-Realm',responseID=197},true))
assert(#sent==1 and manualResponse.greeting_sent)
buttons={};menus.MENU_UNIT_FRIEND(nil,root,{chatTarget='Expired-Realm'})
menuButton('Seller-Realm').click()
assert(#sent==1 and #manualOffers==0 and chatReads==1,
    'expired line blocked the profession suggestion or sent it immediately')
flushTimers();assert(#sent==1, 'manual matching scheduled more messages')
assert(manualBanners==2,'the expired line raised no banner of its own')
Scan.QuickReplies.GetConfig=function() return {enabled=false} end
buttons={};menus.MENU_UNIT_FRIEND(nil,root,{chatTarget='NoQuick-Realm'})
menuButton('Seller-Realm').click()
assert(manualBanners==3 and #manualOffers==0 and #sent==1,'disabled quick replies changed manual matching')

-- Shift+click on an entry only adds the row: no banner, no greeting card,
-- nothing sent. The greeting stays one click on the row.
Scan.QuickReplies.GetConfig=oldManualConfig
buttons={};menus.MENU_UNIT_FRIEND(nil,root,{chatTarget='QuietBuyer-Realm',lineID='44'})
local bannersBeforeQuiet,sentBeforeQuiet=manualBanners,#sent
IsShiftKeyDown=function() return true end
menuButton('Tailor-Realm').click(nil,{buttonName='LeftButton'})
IsShiftKeyDown=nil
local quietRow=Scan.DB.customers['QuietBuyer-Realm'] and Scan.DB.customers['QuietBuyer-Realm'].responses[197]
assert(quietRow and quietRow.greeting_sent,'a quiet row did not get its first mark')
-- The next message of the customer answers this row.
Scan.RequestTracking.MarkReply(Scan.DB.customers['QuietBuyer-Realm'],{})
assert(quietRow.customer_answered,'a reply to a quiet row got no second mark')
assert(manualBanners==bannersBeforeQuiet and #manualOffers==0 and #sent==sentBeforeQuiet,
    'a quiet pick raised a banner, a card or sent something')
IsShiftKeyDown=function() return true end
buttons={};menus.MENU_UNIT_FRIEND(nil,root,{chatTarget='ShiftBuyer-Realm',lineID='44'})
menuButton('Seller-Realm').click(nil,{buttonName='LeftButton'})
assert(Scan.DB.customers['ShiftBuyer-Realm'].responses[164] and manualBanners==bannersBeforeQuiet,
    'Shift+click was not quiet')
buttons={};menus.MENU_UNIT_FRIEND(nil,root,{chatTarget='QuietGeneral-Realm',lineID='44'})
menuButton(tostring(Scan.CONST.TEXT.MANUAL_GENERAL_GREETING)).click(nil,{buttonName='LeftButton'})
IsShiftKeyDown=nil
assert(Scan.DB.customers['QuietGeneral-Realm'].responses[Scan.Scanner.GENERAL_REQUEST_ID]
    and manualBanners==bannersBeforeQuiet,'a quiet general request raised a banner')
-- A left click still raises the banner as before.
buttons={};menus.MENU_UNIT_FRIEND(nil,root,{chatTarget='LoudBuyer-Realm',lineID='44'})
menuButton('Tailor-Realm').click(nil,{buttonName='LeftButton'})
assert(manualBanners==bannersBeforeQuiet+1,'a left click lost its banner')
Scan.QuickReplies.GetConfig=function() return {enabled=false} end

-- "LF crafter" names no profession: the menu offers the general greeting, and
-- the row it creates answers for every crafter rather than one of them.
buttons={};menus.MENU_UNIT_FRIEND(nil,root,{chatTarget='GeneralBuyer-Realm',lineID='44'})
local general=menuButton(tostring(Scan.CONST.TEXT.MANUAL_GENERAL_GREETING))
assert(general,'the general greeting is missing from the chat menu')
general.click()
local generalResponses=Scan.DB.customers['GeneralBuyer-Realm'].responses
local generalRow=generalResponses[Scan.Scanner.GENERAL_REQUEST_ID]
assert(generalRow and generalRow.generic_request and not generalRow.greeting_sent,
    'the general greeting created no row to send')
assert(not generalResponses[197] and not generalResponses[164],
    'the general greeting created a request for one profession')
assert(#sent==1,'the general greeting sent itself')
assert(Scan.SendOrderGreeting({customerName='GeneralBuyer-Realm',
    responseID=Scan.Scanner.GENERAL_REQUEST_ID},true))
assert(#sent==2 and generalRow.greeting_sent,'the general greeting could not be sent')
-- Ignore for a while: the player's requests are skipped until it runs out,
-- and the entry removes itself afterwards.
buttons={};menus.MENU_UNIT_FRIEND(nil,root,{chatTarget='Spammer',lineID='44'})
menuButton('Ignore for 1 hour').click()
local ignoredUntil=Scan.DB.settings.ignored.Spammer
assert(ignoredUntil and ignoredUntil>now, 'a timed ignore stored no end time')
scan('LF '..a,nil,'Spammer')
assert(not Scan.DB.customers.Spammer, 'an ignored player made a request')
buttons={};menus.MENU_UNIT_FRIEND(nil,root,{chatTarget='Spammer',lineID='44'})
assert(menuButton(tostring(Scan.CONST.TEXT.UNIGNORE)), 'an ignored player offered no way back')
local savedNow=now
now=now+2*60*60
scan('LF '..a,nil,'Spammer')
assert(Scan.DB.customers.Spammer and not Scan.DB.settings.ignored.Spammer,
    'the ignore did not end after its time')
now=savedNow
Scan.DB.settings.ignored.Spammer=nil
Scan.DB.characters['Seller-Realm'].parent_professions[164].visual_alert_enabled=nil
Scan.DB.characters['Tailor-Realm'].parent_professions[197].visual_alert_enabled=nil
HironCraftScanScannerMenu.TriggerAlert,Scan.QuickReplies.GetConfig=oldManualTrigger,oldManualConfig
Scan.ColorizePlayerName=oldManualColor
Scan.QuickReplies.ShowOrderGreeting=previousShowGreeting
Scan.GetSortedCrafters, Scan.ColorizeCrafterName, Scan.Utils.ColorizeProfessionName, Scan.Utils.ProfessionNameByID=
    getSorted, colorCrafter, colorProfession, professionName
-- The server can swallow a whisper it considers too fast and say so a moment
-- later. The greeting was already marked as sent, which leaves the row
-- looking answered while the customer heard nothing.
reset()
scan(a)
local realGetTime=GetTime
local clock=100
GetTime=function() return clock end
local throttled=order(101)
Scan.GreetCustomer('LeftButton', throttled)
local sentBeforeThrottle=#sent
assert(response(101).greeting_sent, 'the greeting was not marked as sent')
local offeredAgain={}
local previousShow=Scan.QuickReplies.ShowOrderGreeting
Scan.QuickReplies.ShowOrderGreeting=function(_,customer,_,_,responses)
    offeredAgain[#offeredAgain+1]={customer=customer,count=#responses}
    return true
end
local throttleTimers={}
local previousAfter=C_Timer.After
C_Timer.After=function(delay,callback) throttleTimers[#throttleTimers+1]=callback end
-- The server refuses either with a red error or with a line in the chat
-- frame; both mean the whisper was swallowed.
ERR_CHAT_THROTTLED='The number of messages that can be sent is limited, please wait to send another message.'
local errorFrame=frameForEvent('UI_ERROR_MESSAGE')
assert(errorFrame and errorFrame.events.CHAT_MSG_SYSTEM, 'system chat lines are not watched')
errorFrame.scripts.OnEvent(errorFrame,'CHAT_MSG_SYSTEM',ERR_CHAT_THROTTLED)
assert(not Scan.Utils.CanSendMessages(), 'a system line about the limit was ignored')
assert(not response(101).greeting_sent, 'a swallowed greeting stayed marked as sent')
clock=clock+10
response(101).greeting_sent=true
errorFrame.scripts.OnEvent(errorFrame,'UI_ERROR_MESSAGE',0,ERR_CHAT_THROTTLED)
assert(not Scan.Utils.CanSendMessages(), 'the red error about the limit was ignored')
clock=clock+10
errorFrame.scripts.OnEvent(errorFrame,'CHAT_MSG_SYSTEM','You are now AFK.')
assert(Scan.Utils.CanSendMessages(), 'an unrelated system line was taken for the limit')
-- Greet again so the next refusal has something to take back.
response(101).greeting_sent=false
Scan.GreetCustomer('LeftButton', throttled)
sentBeforeThrottle=#sent
assert(response(101).greeting_sent, 'the row could not be greeted again')
throttleTimers={}
Scan.Utils.NoteChatThrottled()
assert(not response(101).greeting_sent, 'a swallowed greeting stayed marked as sent')
assert(#sent==sentBeforeThrottle, 'the undo resent the greeting by itself')
-- The greeting comes back as a card once the server lets us speak again.
assert(#throttleTimers==1, 'nothing was scheduled to offer the greeting again')
throttleTimers[1]()
assert(#offeredAgain==0 and #throttleTimers==2,
    'the greeting was offered while the server was still holding us back')
clock=clock+10
throttleTimers[2]()
assert(#offeredAgain==1 and offeredAgain[1].customer=='Buyer' and offeredAgain[1].count==1,
    'the greeting was never offered again')
assert(#sent==sentBeforeThrottle, 'offering the greeting again sent it by itself')
-- While the server is holding us back, nothing else is handed to it.
Scan.Utils.NoteChatThrottled()
assert(Scan.Utils.SendResponses({'hello'}, 'Someone-Realm', true)==false,
    'a message was sent during the server back-off')
-- The row can be greeted again by hand once the hold passes.
clock=clock+10
assert(Scan.Utils.CanSendMessages(), 'the back-off never ended')
Scan.GreetCustomer('LeftButton', throttled)
assert(#sent==sentBeforeThrottle+1 and response(101).greeting_sent,
    'the row could not be greeted again after the back-off')
-- A greeting the crafter sent by hand in the meantime is not offered again.
throttleTimers={}
Scan.Utils.NoteChatThrottled()
assert(#throttleTimers==1 and not response(101).greeting_sent)
response(101).greeting_sent=true
clock=clock+10
throttleTimers[1]()
assert(#offeredAgain==1, 'a greeting already sent by hand was offered again')
C_Timer.After=previousAfter
Scan.QuickReplies.ShowOrderGreeting=previousShow
-- A complaint that arrives long after the greeting belongs to something else.
clock=clock+10
Scan.Utils.NoteChatThrottled()
assert(response(101).greeting_sent, 'an unrelated complaint undid an older greeting')
-- Leave the clock past the back-off so the rest of the file can send again.
clock=clock+10
assert(Scan.Utils.CanSendMessages(), 'the back-off outlived its window')
realGetTime=nil

print('Request lifecycle tests passed (30-second reoffer, independent inquiries, latest greeted reply, full history, synchronous manual matching).')

-- Generic armor requests: deliberately put the WRONG armor crafter first.
-- Exercise matching, actual order creation, whisper follow-ups and manual send.
reset()
Scan.DB.settings.ignored=nil
Scan.DB.settings.inclusions='lf,need,нужны'
Scan.DB.settings.exclusions='wts,selling'
Scan.DB.characters={
    ['Seller-Realm']=character(197, 'tailor,wrist,bracers,cloak,ring', {
        [202]={scan_state=1, keywords='wrist,bracers'}, [206]={scan_state=1,keywords='cloak'},
    }),
    ['Smith-Realm']=character(164, 'bs,wrist,bracers', {
        [201]={scan_state=1,keywords='wrist,bracers'}, [205]={scan_state=1,keywords='wrist'},
    }),
    ['Leather-Realm']=character(165, 'lw,wrist,bracers', {
        [203]={scan_state=1,keywords='wrist,bracers'}, [204]={scan_state=1,keywords='wrist,bracers'},
    }),
}
local armorItems={}
for index,armor in ipairs({4,1,2,3,4,1}) do
    local id=200+index
    recipes[id]={recipeID=id, qualityItemIDs={id+1000}}
    armorItems[id+1000]={armor=armor,slot=index==5 and 'INVTYPE_HEAD'
        or (index==6 and 'INVTYPE_CLOAK' or 'INVTYPE_WRIST')}
end
Enum={ItemQuality={Epic=4}}
C_Item={
    GetItemQualityByID=function() return 4 end,
    GetItemInfoInstant=function(id)
        local info=armorItems[id]
        if info then return id,'Item','Item',info.slot,0,info.class or 4,info.subclass or info.armor end
    end,
}
local classByGUID={}
local classReads=0
GetPlayerInfoByGUID=function(guid) classReads=classReads+1; return 'Localized',classByGUID[guid] end
reloadConfig()
local function forClass(text,class,options)
    local guid='Class-'..class; classByGUID[guid]=class
    return Scan.Scanner.GetCrafterForMessage('ClassBuyer',text,options,guid)
end
for class,id in pairs({WARRIOR=201,PALADIN=201,DEATHKNIGHT=201,
    MAGE=202,PRIEST=202,WARLOCK=202,ROGUE=203,DRUID=203,MONK=203,DEMONHUNTER=203,
    HUNTER=204,SHAMAN=204,EVOKER=204}) do
    local crafter,_,recipe=forClass('need wrist',class)
    assert(crafter and recipe and recipe.recipeID==id, 'wrong armor for '..class)
end
local preferred,_,preferredRecipe=forClass('need wrist','WARRIOR')
assert(preferred.crafter=='Smith-Realm' and preferredRecipe.recipeID==201,
    'local tailor or wrong-slot plate recipe took precedence')
for _,text in ipairs({'need plate wrist','LF plate bracers','need wristguards','need armguards',
    'need shoulderpads','need gauntlets','need sabatons','need greaves'}) do
    assert(forClass(text,'WARRIOR').crafter=='Smith-Realm', 'armor/slot alias picked a tailor: '..text)
end
assert(forClass('need plate wrist','MAGE').crafter=='Smith-Realm', 'explicit plate lost to mage class')
assert(forClass('LF leather craft','WARRIOR').crafter=='Leather-Realm', 'explicit material without a slot was ignored')
assert(forClass('need bs wrist','MAGE').crafter=='Smith-Realm', 'explicit profession lost to generic slot keywords')
for _,text in ipairs({'need wrist!','NEED WRIST','нужны наручи','need boots','need gloves',
    'need shoulders','need chest','need belt','need pants','need helm'}) do
    local crafter=forClass(text,'WARRIOR')
    assert(crafter and crafter.crafter=='Smith-Realm','generic slot not routed: '..text)
end
-- The class does not invent a request or bypass global/profession exclusions.
assert(not forClass('wrist','WARRIOR'))
assert(not forClass('wts need wrist','WARRIOR'))
Scan.DB.characters['Smith-Realm'].parent_professions[164].exclusions='selling'
assert(not forClass('need wrist selling','WARRIOR'))
Scan.DB.characters['Smith-Realm'].parent_professions[164].exclusions=nil
Scan.DB.characters['Smith-Realm'].parent_professions[164].scanning_enabled=false
assert(not forClass('need wrist','WARRIOR'), 'disabled smith fell back to incompatible tailor')
Scan.DB.characters['Smith-Realm'].parent_professions[164].scanning_enabled=true
local crafters=Scan.DB.characters
crafters['Smith-Realm'].parent_professions[164].keywords='bs'
reloadConfig()
assert(forClass('need wrist','WARRIOR').crafter=='Smith-Realm',
    'armor intent required redundant profession-level slot keywords')

-- Item/recipe links are authoritative even if a warrior orders cloth.
local reads=classReads
local linked,_,linkedRecipe=forClass(link(1202),'WARRIOR')
assert(linked and linkedRecipe.recipeID==202 and classReads==reads)
local recipeLink='|Henchant:202|h[Cloth wrists]|h'
linked,_,linkedRecipe=forClass('LF '..recipeLink,'WARRIOR')
assert(linked and linkedRecipe.recipeID==202)
assert(not forClass('need wrist '..link(9999),'WARRIOR'))
assert(forClass('need tailor wrist','WARRIOR').crafter=='Seller-Realm')
assert(forClass('need wrist','WARRIOR',{forceCrafterInfo={crafter='Seller-Realm',parentProfID=197}}).crafter=='Seller-Realm')
assert(forClass('need cloak','WARRIOR').crafter=='Seller-Realm')
assert(Scan.ClassMatching.GetContext('need wrist enchant','Class-WARRIOR').parentProfID==333)
assert(Scan.ClassMatching.GetContext('need cloth wrist','Class-WARRIOR').armor==1)
for _,text in ipairs({'need wrist for alt','need weapon','need tool','need bag'}) do
    assert(not Scan.ClassMatching.GetContext(text,'Class-WARRIOR'), 'class overrode explicit/non-armor request')
end
assert(Scan.ClassMatching.GetContext('need ring','Class-WARRIOR').parentProfID==755)
assert(Scan.ClassMatching.GetContext('need necklace','Class-WARRIOR').parentProfID==755)
assert(not Scan.ClassMatching.GetContext('need wristwatch','Class-WARRIOR'), 'substring matched as an armor slot')
assert(not forClass('need wrist','UNKNOWN'), 'unknown class guessed an armor crafter')
Scan.DB.settings.match_customer_class=false
assert(forClass('need wrist','WARRIOR').crafter=='Seller-Realm', 'opt-out ignored')
Scan.DB.settings.match_customer_class=true
local getClass=GetPlayerInfoByGUID
GetPlayerInfoByGUID=function() error('unavailable') end
assert(forClass('need wrist','WARRIOR').crafter=='Smith-Realm', 'cached class was discarded after an API error')
GetPlayerInfoByGUID=getClass
local classAPI=GetPlayerInfoByGUID
GetPlayerInfoByGUID=nil
HironCraftScanComm.applying_remote_state=true
assert(forClass('need wrist','UNKNOWN',{customerClass='WARRIOR'}).crafter=='Smith-Realm',
    'linked request lost its known class when the receiving client lacked GUID data')
assert(not forClass('need wrist','UNKNOWN',{customerClass='INVALID'}))
HironCraftScanComm.applying_remote_state=false
assert(not forClass('need wrist','UNKNOWN',{customerClass='WARRIOR'}),
    'local override was accepted as remote class metadata')
GetPlayerInfoByGUID=classAPI
local getItemInfo=C_Item.GetItemInfoInstant
C_Item.GetItemInfoInstant=function() return nil end
local generic,_,unknownRecipe=forClass('need wrist','WARRIOR')
assert(generic.crafter=='Smith-Realm' and not unknownRecipe, 'unknown item metadata guessed an exact craft')
C_Item.GetItemInfoInstant=getItemInfo
local classContext=Scan.ClassMatching.GetContext('need wrist','Class-WARRIOR')
assert(not Scan.ClassMatching.MatchesRecipe(classContext,nil))
local getOutputs=Scan.Utils.GetOutputItems
Scan.Utils.GetOutputItems=function() error('item data unavailable') end
assert(not Scan.ClassMatching.MatchesRecipe(classContext,recipes[201]))
Scan.Utils.GetOutputItems=getOutputs
Scan.DB.customers.ClassBuyer={guid='Class-WARRIOR'}
assert(Scan.Scanner.GetCrafterForMessage('ClassBuyer','need wrist').crafter=='Smith-Realm',
    'stored GUID was not used when the current event omitted it')

local originalInclusions=Scan.DB.settings.inclusions
Scan.DB.settings.inclusions=originalInclusions..',looking for'
reloadConfig()
for _,inferClass in ipairs({true,false}) do
    reset();Scan.DB.settings.match_customer_class=inferClass
    Scan.OnMessage('CHAT_MSG_CHANNEL','looking for wrist cloth crafter please','Buyer','Uncached-Cloth-GUID')
    local clothWrist=response('equipment:197:INVTYPE_WRIST')
    assert(countRows()==1 and clothWrist and clothWrist.equipmentRequest.armor==1
        and clothWrist.crafterFullName=='Seller-Realm' and not response(197),
        'explicit cloth wrist became a generic Tailoring row')
    assert(Scan.SendOrderGreeting(order('equipment:197:INVTYPE_WRIST'),true))
    assert(countRows()==1 and response('equipment:197:INVTYPE_WRIST')==clothWrist,
        'greeting click changed the explicit Wrist row')
    Scan.OnMessage('CHAT_MSG_WHISPER',link(1202),'Buyer','Uncached-Cloth-GUID')
    assert(countRows()==1 and response(202) and not response('equipment:197:INVTYPE_WRIST'))
end
Scan.DB.settings.match_customer_class=true
Scan.DB.settings.inclusions=originalInclusions;reloadConfig()
print('Explicit cloth wrist scenario passed (no class data, class inference disabled, manual send, link replacement).')

reset()
Scan.OnMessage('CHAT_MSG_CHANNEL','need wrist','LateClass','Late-GUID')
assert(countRows()==0 and #sent==0 and #timers==1, 'unknown class guessed or sent a response')
classByGUID['Late-GUID']='WARRIOR';flushTimers()
assert(countRows()==1 and Scan.DB.customers.LateClass.responses['equipment:164:INVTYPE_WRIST'].crafterFullName=='Smith-Realm')
assert(#sent==0, 'class-cache retry sent player chat')
reset();Scan.OnMessage('CHAT_MSG_CHANNEL','need wrist','NeverClass','Never-GUID')
for i=1,4 do flushTimers() end
assert(countRows()==0 and #timers==1 and #sent==0, 'the request stopped waiting for the class too early')
now=now+11*60;flushTimers()
assert(countRows()==0 and #timers==0 and #sent==0, 'unknown class retries did not stop safely')
-- The class turns up only minutes later (the customer left an instance): the
-- row is added then, and nothing is said by itself.
reset();Scan.OnMessage('CHAT_MSG_CHANNEL','need wrist','SlowClass','Slow-GUID')
for i=1,4 do flushTimers() end
now=now+3*60;flushTimers()
assert(countRows()==0 and #timers==1, 'waiting for the class gave up or guessed')
-- The wait is saved: a relog in between drops the timer, and the next
-- character picks the wait up where it was.
local waits=Scan.DB.settings.class_waits
assert(waits and next(waits) and type(select(2,next(waits)).options)=='table',
    'the wait for the class is not saved')
classByGUID['Slow-GUID']='WARRIOR';flushTimers()
assert(countRows()==1 and Scan.DB.customers.SlowClass.responses['equipment:164:INVTYPE_WRIST'],
    'the wrist never appeared once the class was known')
assert(#timers==0 and #sent==0, 'a late class kept polling or sent chat')
classByGUID['Slow-GUID']=nil

-- "LF shield & sword": the greeting names no item, so with several items it
-- opens with what this crafter makes, and the same crafter's items are not
-- repeated one line each.
reset()
classByGUID['Buyer-GUID']='WARRIOR'
scan('LF wrist and chest')
assert(response('equipment:164:INVTYPE_WRIST') and response('equipment:164:INVTYPE_CHEST') and countRows()==2)
Scan.GreetCustomer('LeftButton',order('equipment:164:INVTYPE_WRIST'))
assert(#sent==1, 'the same crafter items were sent one line each')
assert(sent[1].message:find('^Chest and Wrist: ') or sent[1].message:find('^Wrist and Chest: '),
    'a multi-item greeting did not say which items go to the crafter: '..tostring(sent[1].message))
-- The customer wrote first: one short line for both, not one per item.
reset()
scan('LF wrist and chest')
response('equipment:164:INVTYPE_WRIST').destination_only_greeting=true
response('equipment:164:INVTYPE_CHEST').destination_only_greeting=true
Scan.GreetCustomer('LeftButton',order('equipment:164:INVTYPE_WRIST'))
assert(#sent==1 and (sent[1].message=='Chest and Wrist Send to Smith.'
    or sent[1].message=='Wrist and Chest Send to Smith.'), 'short lines were not joined: '..tostring(sent[1].message))
classByGUID['Buyer-GUID']=nil

-- Requests narrow down: "LF tailor" then "can you craft chest?" is one
-- request that got more specific, not a second one.
reset()
classByGUID['Buyer-GUID']='WARRIOR'
scan('LF bs')
assert(response(164) and countRows()==1,'the profession request made no row')
scan('LF wrist')
assert(response('equipment:164:INVTYPE_WRIST') and not response(164) and countRows()==1,
    'the slot did not replace the profession row')
-- Going broad again does not push the narrower row aside.
scan('LF bs')
assert(response('equipment:164:INVTYPE_WRIST') and not response(164) and countRows()==1,
    'a profession request replaced or duplicated the slot row')
-- Another profession is another request: after the wrist, "do you have a
-- tailor too?" gets its own row next to it.
scan('LF tailor')
assert(response('equipment:164:INVTYPE_WRIST') and response(197) and countRows()==2,
    'a request for another profession did not get its own row')
assert(#sent==0,'narrowing a request sent something by itself')

reset()
classByGUID['Buyer-GUID']='WARRIOR'
scan('need wrist')
local wristID='equipment:164:INVTYPE_WRIST'
assert(countRows()==1 and response(wristID).crafterFullName=='Smith-Realm' and #sent==0)
assert(response(wristID).equipmentLabel=='Wrist' and not response(wristID).itemID,
    'slot request guessed an exact item before the customer linked it')
flushTimers()
assert(#sent==0, 'class routing introduced auto replies')
Scan.GreetCustomer('LeftButton',order(wristID))
assert(#sent==1 and response(wristID).greeting_sent, 'class-routed greeting did not send on click')
Scan.OnMessage('CHAT_MSG_WHISPER',link(1205),'Buyer','Buyer-GUID') -- head, not wrist
assert(response(wristID) and response(205) and countRows()==2, 'unrelated head item replaced wrists')
Scan.OnMessage('CHAT_MSG_WHISPER',link(1201),'Buyer','Buyer-GUID')
assert(not response(wristID) and response(201) and response(205) and countRows()==2,
    'linked wrists did not replace just the compatible placeholder')
assert(response(201).destination_only_greeting and not response(201).greeting_sent)
assert(Scan.SendOrderGreeting(order(201),true))
assert(sent[#sent].message==link(1201)..' Send to Smith.', 'replacement item repeated the full greeting')
scan('need wrist')
assert(not response(wristID) and countRows()==2, 'known item was downgraded to a generic slot')
-- Once that item is delivered the slot is done for a while: "it is ur wrist
-- :d" after the craft is talk about it, not a new request.
local previousFulfillmentForSlot=Scan.OrderFulfillment
local deliveredAt=now
Scan.OrderFulfillment={Status={Fulfilled='fulfilled',Rejected='rejected',Failed='failed'},
    GetStatus=function(_,listed)
        if listed.responseID==201 then return {status='fulfilled',updatedAt=deliveredAt} end
    end}
scan('need wrist')
assert(not response(wristID) and countRows()==2, 'a slot just delivered made a new row')
-- An hour later it may be for another set.
now=now+2*60*60
scan('need wrist')
assert(response(wristID) and countRows()==3, 'a delivered slot blocked requests for good')
Scan.OrderFulfillment=previousFulfillmentForSlot
reset(); classByGUID['Buyer-GUID']='WARRIOR'
scan('need wrist and belt')
assert(countRows()==2 and response(wristID) and response('equipment:164:INVTYPE_WAIST'),
    'different armor slots were merged')
local sharedTokens=shared[#shared][7]
assert(sharedTokens[wristID]==response(wristID).requestToken
    and sharedTokens['equipment:164:INVTYPE_WAIST']==response('equipment:164:INVTYPE_WAIST').requestToken,
    'equipment batch did not share individual request identities')
reset();HironCraftScanComm.applying_remote_state=true
Scan.OnMessage('CHAT_MSG_CHANNEL','need wrist and belt','Buyer','Buyer-GUID',{
    requestToken='legacy-first',requestTokens=sharedTokens,customerClass='WARRIOR'})
HironCraftScanComm.applying_remote_state=false
assert(response(wristID).requestToken==sharedTokens[wristID]
    and response('equipment:164:INVTYPE_WAIST').requestToken==sharedTokens['equipment:164:INVTYPE_WAIST'],
    'linked batch collapsed two different request tokens')
reset()
Scan.DB.characters['Engineer-Realm']=character(202,'engineering',{})

-- Exact user scenario: three typed rows, then independent link replacements.
for id,slot in pairs({[207]='INVTYPE_WAIST',[208]='INVTYPE_HAND'}) do
    recipes[id]={recipeID=id,qualityItemIDs={id+1000}}
    armorItems[id+1000]={slot=slot,armor=4}
    Scan.DB.characters['Smith-Realm'].professions[164].recipes[id]={scan_state=1,keywords=''}
end
reloadConfig()
local multiText='Hey, i need also belt, hands and back can you craft?'
for class,profession in pairs({WARRIOR=164,HUNTER=165,MAGE=197}) do
    reset();classByGUID['Buyer-GUID']=class
    Scan.DB.customers.Buyer={guid='Buyer-GUID',responses={},chat_history={}}
    Scan.OnMessage('CHAT_MSG_WHISPER',multiText,'Buyer','Buyer-GUID')
    assert(countRows()==3 and response('equipment:'..profession..':INVTYPE_WAIST')
        and response('equipment:'..profession..':INVTYPE_HAND') and response('equipment:197:INVTYPE_CLOAK'),
        'belt/hands/back did not produce three correctly routed rows for '..class)
    assert(#sent==0,'multi-slot whisper sent without a click')
end
reset();classByGUID['Buyer-GUID']='WARRIOR'
Scan.OnMessage('CHAT_MSG_WHISPER',multiText,'Buyer','Buyer-GUID')
local beltID,handID,backID='equipment:164:INVTYPE_WAIST','equipment:164:INVTYPE_HAND','equipment:197:INVTYPE_CLOAK'
local handToken,backToken=response(handID).requestToken,response(backID).requestToken
Scan.OnMessage('CHAT_MSG_WHISPER',link(1207),'Buyer','Buyer-GUID')
assert(countRows()==3 and not response(beltID) and response(207)
    and response(handID).requestToken==handToken and response(backID).requestToken==backToken,
    'belt link changed hands/back or added a fourth row')
Scan.OnMessage('CHAT_MSG_WHISPER',link(1208),'Buyer','Buyer-GUID')
assert(countRows()==3 and response(207) and response(208) and not response(handID) and response(backID))
Scan.OnMessage('CHAT_MSG_WHISPER',link(1206),'Buyer','Buyer-GUID')
assert(countRows()==3 and response(207) and response(208) and response(206) and not response(backID),
    'cloak link used warrior armor class or failed to replace Back')
Scan.OnMessage('CHAT_MSG_WHISPER',multiText,'Buyer','Buyer-GUID')
assert(countRows()==3 and not response(beltID) and not response(handID) and not response(backID),
    'repeated slot names downgraded linked items')
assert(#sent==0,'link replacement automatically sent a greeting')
print('Belt/hands/back scenario passed (three classes, three rows, independent link replacement, no auto send).')

-- Public scanner -> typed row -> manual greeting -> exact item replacement.
recipes[209]={recipeID=209,qualityItemIDs={1209}}
recipes[210]={recipeID=210,qualityItemIDs={1210}}
armorItems[1209]={slot='INVTYPE_WEAPON',class=2,subclass=7}
armorItems[1210]={slot='INVTYPE_SHIELD',class=4,subclass=6}
Scan.DB.characters['Smith-Realm'].professions[164].recipes[209]={scan_state=1,keywords=''}
Scan.DB.characters['Smith-Realm'].professions[164].recipes[210]={scan_state=1,keywords=''}
local savedInclusions=Scan.DB.settings.inclusions
Scan.DB.settings.inclusions=savedInclusions..',crafter'
reloadConfig()
local swordID,shieldID='equipment:164:Sword','equipment:164:INVTYPE_SHIELD'
for _,modifier in ipairs({'one hand','two hand','1h','2h','one-handed','two-handed'}) do
    reset();classByGUID['Buyer-GUID']='WARRIOR'
    scan('sword '..modifier..' crafter')
    assert(countRows()==1 and response(swordID) and not response(handID),
        'weapon qualifier created a glove/profession row: '..modifier)
    flushTimers();assert(#sent==0,'weapon request sent without a click')
    assert(Scan.SendOrderGreeting(order(swordID),true))
    assert(#sent==1,'weapon greeting produced a second message')
    Scan.OnMessage('CHAT_MSG_WHISPER',link(1209),'Buyer','Buyer-GUID')
    assert(countRows()==1 and response(209) and not response(swordID),'sword link did not replace Sword')
    assert(#sent==1,'sword replacement sent automatically')
end
reset();classByGUID['Buyer-GUID']='WARRIOR'
scan('need hands and one hand sword')
assert(countRows()==2 and response(handID) and response(swordID),'real gloves were suppressed')
Scan.OnMessage('CHAT_MSG_WHISPER',link(1209),'Buyer','Buyer-GUID')
assert(countRows()==2 and response(handID) and response(209) and not response(swordID))
reset();classByGUID['Buyer-GUID']='MAGE'
scan('need shield and hands')
local clothHands='equipment:197:INVTYPE_HAND'
assert(countRows()==2 and response(shieldID) and response(clothHands),'Shield inherited customer armor profession')
Scan.OnMessage('CHAT_MSG_WHISPER',link(1210),'Buyer','Buyer-GUID')
assert(countRows()==2 and response(210) and not response(shieldID) and response(clothHands),
    'shield link replaced the wrong request')
assert(#sent==0,'shield request sent automatically')
Scan.DB.settings.inclusions=savedInclusions;reloadConfig()
print('Sword/shield scanner tests passed (qualifiers, single greeting, real gloves, typed link replacement).')

-- Jewelry/off-hand use fixed professions. Trinkets are intentionally dynamic:
-- create rows only for professions with a monitored trinket output.
Scan.DB.characters['Jewel-Realm']=character(755,'jc',{
    [211]={scan_state=1,keywords=''},[212]={scan_state=1,keywords=''},
})
Scan.DB.characters['Scribe-Realm']=character(773,'inscription',{
    [213]={scan_state=1,keywords=''},[214]={scan_state=1,keywords=''},
})
Scan.DB.characters['Alchemist-Realm']=character(171,'alchemy',{
    [215]={scan_state=1,keywords=''},
})
for id,slot in pairs({[211]='INVTYPE_FINGER',[212]='INVTYPE_NECK',
    [213]='INVTYPE_HOLDABLE',[214]='INVTYPE_TRINKET',[215]='INVTYPE_TRINKET'}) do
    recipes[id]={recipeID=id,qualityItemIDs={id+1000}}
    armorItems[id+1000]={slot=slot,class=4,subclass=0}
end
reloadConfig();reset()
scan('need ring neck offhand trinket')
local ringID,neckID,offhandID='equipment:755:INVTYPE_FINGER',
    'equipment:755:INVTYPE_NECK','equipment:773:INVTYPE_HOLDABLE'
local scribeTrinketID,alchemyTrinketID='equipment:773:INVTYPE_TRINKET','equipment:171:INVTYPE_TRINKET'
assert(countRows()==5 and response(ringID) and response(neckID) and response(offhandID)
    and response(scribeTrinketID) and response(alchemyTrinketID),
    'jewelry/off-hand or monitored trinket rows were missing')
assert(not response('equipment:202:INVTYPE_TRINKET') and not response('equipment:755:INVTYPE_TRINKET'),
    'profession without a monitored trinket recipe claimed the request')
assert(#sent==0,'new equipment categories sent without a click')
Scan.OnMessage('CHAT_MSG_WHISPER',link(1214),'Buyer','Buyer-GUID')
assert(countRows()==5 and response(214) and not response(scribeTrinketID)
    and response(alchemyTrinketID),'scribe trinket link removed another profession placeholder')
Scan.OnMessage('CHAT_MSG_WHISPER',link(1211),'Buyer','Buyer-GUID')
assert(countRows()==5 and response(211) and not response(ringID) and response(neckID),
    'ring link replaced Neck or failed to replace Ring')
assert(#sent==0,'exact jewelry/trinket link sent automatically')
reset();scan('need tailoring trinket')
assert(countRows()==0,'unsupported explicit trinket profession produced a row')
-- A conversation that is already about an order: "dagger for Favu, wrist for
-- ? and ring for ?" asks for more items without saying LF again.
reset()
Scan.QuickReplies.HasUnfinishedOrders=function(_,customer) return customer=='Buyer' end
classByGUID['Buyer-GUID']='WARRIOR'
Scan.OnMessage('CHAT_MSG_WHISPER','wrist for ? and ring for ?','Buyer','Buyer-GUID')
assert(response('equipment:755:INVTYPE_FINGER'),'the ring in a follow-up whisper made no row')
assert(response('equipment:164:INVTYPE_WRIST'),'the wrist in a follow-up whisper made no row')
assert(#sent==0,'a follow-up whisper sent something by itself')
-- Small talk in that conversation is not read through typos: "writs" alone
-- makes no row, "LF writs" does.
reset()
Scan.QuickReplies.HasUnfinishedOrders=function(_,customer) return customer=='Buyer' end
classByGUID['Buyer-GUID']='WARRIOR'
Scan.OnMessage('CHAT_MSG_WHISPER','writs','Buyer','Buyer-GUID')
assert(not response('equipment:164:INVTYPE_WRIST'), 'a typo in small talk made a row')
Scan.OnMessage('CHAT_MSG_WHISPER','LF writs','Buyer','Buyer-GUID')
assert(response('equipment:164:INVTYPE_WRIST'), 'a typo after LF lost its row')
-- Outside a conversation with something open, the same words are no request.
reset()
Scan.QuickReplies.HasUnfinishedOrders=function() return false end
Scan.OnMessage('CHAT_MSG_WHISPER','wrist for ? and ring for ?','Buyer','Buyer-GUID')
assert(countRows()==0,'a whisper without LF became a request outside a conversation')
-- The customer's class is not known yet: the ring needs no class and is
-- routed at once, the wrist waits for it instead of losing the whole message.
reset()
Scan.QuickReplies.HasUnfinishedOrders=function(_,customer) return customer=='Stranger' end
local function strangerRow(id)
    local customer=Scan.DB.customers.Stranger
    return customer and customer.responses and customer.responses[id]
end
Scan.OnMessage('CHAT_MSG_WHISPER','wrist for ? and ring for ?','Stranger','Stranger-GUID')
assert(strangerRow('equipment:755:INVTYPE_FINGER'),'an unknown class threw away the ring')
assert(not strangerRow('equipment:164:INVTYPE_WRIST'),'an armor slot was guessed without the class')
classByGUID['Stranger-GUID']='WARRIOR'
flushTimers()
assert(strangerRow('equipment:164:INVTYPE_WRIST'),'the wrist never followed once the class was known')
assert(strangerRow('equipment:755:INVTYPE_FINGER'),'looking again lost the ring')
-- The same when the class takes minutes instead of a moment.
reset()
Scan.OnMessage('CHAT_MSG_WHISPER','wrist for ? and ring for ?','Stranger','Slow-Stranger-GUID')
for i=1,4 do flushTimers() end
now=now+5*60;flushTimers()
assert(strangerRow('equipment:755:INVTYPE_FINGER') and not strangerRow('equipment:164:INVTYPE_WRIST'),
    'the ring was lost or the wrist guessed while the class was unknown')
classByGUID['Slow-Stranger-GUID']='WARRIOR';flushTimers()
assert(strangerRow('equipment:164:INVTYPE_WRIST') and strangerRow('equipment:755:INVTYPE_FINGER'),
    'the wrist was not added when the class arrived minutes later')
assert(countRows()==2 and #sent==0 and #timers==0,'a late class duplicated rows, sent chat or kept polling')
Scan.QuickReplies.HasUnfinishedOrders=nil

print('Jewelry/off-hand/trinket scanner tests passed (fixed routing, monitored dynamic professions, exact replacement).')

-- Less common weapon families are also recipe-driven so an expansion can
-- move them between professions without generating a false craft claim.
Scan.DB.characters['Leather-Realm'].professions[165].recipes[216]={scan_state=1,keywords=''}
Scan.DB.characters['Engineer-Realm'].professions[202].recipes[217]={scan_state=1,keywords=''}
Scan.DB.characters['Smith-Realm'].professions[164].recipes[218]={scan_state=1,keywords=''}
Scan.DB.characters['Enchanter-Realm']=character(333,'enchanting',{
    [219]={scan_state=1,keywords=''},
})
for id,data in pairs({[216]={'INVTYPE_RANGEDRIGHT',2},[217]={'INVTYPE_RANGEDRIGHT',18},
    [218]={'INVTYPE_WEAPON',13},[219]={'INVTYPE_RANGEDRIGHT',19}}) do
    recipes[id]={recipeID=id,qualityItemIDs={id+1000}}
    armorItems[id+1000]={slot=data[1],class=2,subclass=data[2]}
end
reloadConfig();reset()
scan('need bow crossbow fist weapon wand')
local bowID,crossbowID,fistID,wandID='equipment:165:Bow','equipment:202:Crossbow',
    'equipment:164:Fist weapon','equipment:333:Wand'
assert(countRows()==4 and response(bowID) and response(crossbowID)
    and response(fistID) and response(wandID),'recipe-backed weapon categories routed incorrectly')
assert(not response('equipment:164:Bow') and not response('equipment:202:Wand'),
    'unmonitored profession claimed a dynamic weapon')
Scan.OnMessage('CHAT_MSG_WHISPER',link(1216),'Buyer','Buyer-GUID')
assert(countRows()==4 and response(216) and not response(bowID)
    and response(crossbowID) and response(fistID) and response(wandID),
    'bow link replaced another weapon category')
assert(#sent==0,'dynamic weapon request sent automatically')
print('Dynamic weapon scanner tests passed (bow, crossbow, fist weapon, wand, recipe-backed routing).')

reset()
recipes[301]={recipeID=301,qualityItemIDs={1501}}
recipes[303]={recipeID=303,qualityItemIDs={1503}}
armorItems[1501]={slot='INVTYPE_WEAPON',class=2,subclass=0}
armorItems[1503]={slot='INVTYPE_RANGEDRIGHT',class=2,subclass=3}
Scan.DB.characters['Smith-Realm'].professions[164].recipes[301]={scan_state=1,keywords='axe'}
Scan.DB.characters['Engineer-Realm'].professions[202].recipes[303]={scan_state=1,keywords='gun'}
reloadConfig()
scan('need axe and sword and gun')
assert(countRows()==3 and response('equipment:164:Axe') and response('equipment:164:Sword')
    and response('equipment:202:Gun').crafterFullName=='Engineer-Realm','weapon placeholders routed incorrectly')
Scan.OnMessage('CHAT_MSG_WHISPER',link(1503),'Buyer','Buyer-GUID')
assert(countRows()==3 and response(303) and not response('equipment:202:Gun')
    and response('equipment:164:Axe') and response('equipment:164:Sword'), 'gun link replaced another weapon')
Scan.OnMessage('CHAT_MSG_WHISPER',link(1501),'Buyer','Buyer-GUID')
assert(countRows()==3 and response(301) and not response('equipment:164:Axe')
    and response('equipment:164:Sword'), 'axe link did not replace the Axe placeholder')
assert(Scan.ClassMatching.MatchesItem({subclasses={[3]=true}},999)==false)
reset();classByGUID['Buyer-GUID']='WARRIOR'
scan('need wrist and gun')
assert(countRows()==2 and response(wristID) and response('equipment:202:Gun'),
    'mixed armor and weapon request dropped one type')
reset()
classByGUID['Buyer-GUID']='HUNTER'
scan('LF lw')
Scan.OnMessage('CHAT_MSG_WHISPER','need wrist','Buyer','Buyer-GUID')
assert(response('equipment:165:INVTYPE_WRIST').equipmentRequest.armor==3 and not response(203),
    'existing whisper conversation lost the sender class')
print('Customer-class matching tests passed (13 classes, armor slots, links, exclusions, opt-out, unknown data, whispers, manual sends).')

reset()
Scan.OnMessage('CHAT_MSG_WHISPER',link(1201),'Buyer','Buyer-GUID')
assert(response(201).destination_only_greeting and not response(201).greeting_sent,
    'first customer-initiated whisper was offered a full greeting')
assert(Scan.SendOrderGreeting(order(201),true))
assert(sent[1].message==link(1201)..' Send to Smith.', 'first whisper greeting still contained Hi')

-- Battle.net event -> matcher -> rows -> manual greeting -> same transport.
loadSource('Customer/BattleNet.lua')
reset()
Scan.DB.settings.my_uuid='local-account'
Scan.DB.settings.ignored=nil
Scan.DB.characters={
    ['Seller-Realm']=character(164,'bs',{[101]={scan_state=1}}),
    ['Tailor-Realm']=character(197,'tailor',{[102]={scan_state=1}}),
}
reloadConfig()
local friends={
    {bnetAccountID=70,battleTag='Friend#1234',accountName='Friend',isFriend=true},
    {bnetAccountID=71,battleTag='Friend#5678',accountName='Friend',isFriend=true},
}
WOW_PROJECT_ID=1
friends[1].gameAccountInfo={characterName='Friendbuyer',realmName='Realm',clientProgram='WoW',
    isOnline=true,wowProjectID=1,isInCurrentRegion=true}
local bnetSent, bnetOpened, sendOK={},0,true
function BNGetNumFriends() return #friends end
C_BattleNet={
    GetAccountInfoByID=function(id) for _,friend in ipairs(friends) do if friend.bnetAccountID==id then return friend end end end,
    GetFriendAccountInfo=function(index) return friends[index] end,
    SendWhisper=function(id,text)
        if sendOK then bnetSent[#bnetSent+1]={id=id,text=text} end
        return sendOK
    end,
}
function BNet_GetBNetIDAccount() return friends[1] and friends[1].bnetAccountID end
ChatFrameUtil={SendBNetTell=function() bnetOpened=bnetOpened+1 end}
local BNet=Scan.BattleNet
local key=BNet.FromID(70)
local function bn(message,id,event)
    BNet.HandleEvent(event or 'CHAT_MSG_BN_WHISPER', message, 'Real name must not be saved',
        '', '', '', '', 0, 0, '', 0, 601, 'BNet-GUID', id or 70)
end
bn('hihi');bn('WTS '..a);bn(link(9999))
assert(countRows()==0 and next(Scan.DB.customers)==nil, 'irrelevant friend chat created an order')
bn(a..a..b)
assert(countRows()==2 and #bnetSent==0 and #sent==0, 'BN scan sent chat or duplicated items')
local info=Scan.DB.customers[key]
local firstOrder=order(101,key)
assert(info and not info.guid and not info.responses[101].greeting_sent)
assert(info.responses[101].customer_answered and info.responses[101].battleNetCharacters['friendbuyer-realm'])
assert(info.responses[102].battleNetCharacters['friendbuyer-realm'], 'second item lost the verified buyer')
assert(#info.chat_history==1 and info.chat_history[1].chatType=='BN_WHISPER')
assert(not info.chat_history[1].message:find('Real name',1,true))
assert(Scan.NameAndRealmToName(key)=='friend#1234 (Battle.net)')
assert(Scan.ColorizePlayerName(key):find('friend#1234',1,true))
assert(Scan.Utils.SendResponses({'hi'},key)==false and #bnetSent==0)
Scan.GreetCustomer('LeftButton',firstOrder)
assert(#bnetSent==2 and #sent==0 and bnetSent[1].id==70 and bnetSent[2].id==70)
assert(bnetSent[2].text:find('Send to Tailor.',1,true) and info.responses[101].greeting_sent)
bn('our reply',70,'CHAT_MSG_BN_WHISPER_INFORM')
assert(info.chat_history[#info.chat_history].chatType=='BN_WHISPER_INFORM')
local quickCount=0
Scan.QuickReplies.OnWhisper=function(_,who,text)
    assert(who==key and text=='yo');quickCount=quickCount+1
end
bn('yo')
assert(quickCount==1 and countRows()==2 and #bnetSent==2, 'follow-up did not reach the quick-reply classifier once')
Scan.GreetCustomer('LeftButton',firstOrder)
assert(bnetOpened==1 and opened==0, 'row opened character whisper for a BNet conversation')
bn(a,71)
assert(countRows()==3 and Scan.DB.customers[BNet.FromID(71)]~=info, 'same display name merged different friends')
assert(not BNet.OpenChat(BNet.FromID(71)) and bnetOpened==1, 'ambiguous name opened wrong BNet editor')
friends[1].bnetAccountID=99
assert(Scan.Utils.SendResponses({'after reload'},key,true) and bnetSent[#bnetSent].id==99,
    'cached session ID was used after it changed')
Scan.DB.settings.my_uuid='other-account'
assert(not Scan.Utils.SendResponses({'wrong account'},key,true))
Scan.DB.settings.my_uuid='local-account'
sendOK=false
local other=order(101,BNet.FromID(71))
Scan.GreetCustomer('LeftButton',other)
assert(not Scan.OrderToResponse(other).greeting_sent, 'rejected BNet send marked greeting as sent')
local modern=C_BattleNet.SendWhisper;C_BattleNet.SendWhisper=nil
BNSendWhisper=function(id,text) bnetSent[#bnetSent+1]={id=id,text=text} end
assert(Scan.Utils.SendResponses({'legacy'},key,true), 'legacy BNet sender did not work')
BNSendWhisper=nil;C_BattleNet.SendWhisper=modern;sendOK=true
friends[1].isFriend=false
assert(not Scan.Utils.SendResponses({'removed friend'},key,true) and #sent==0)
friends[1].isFriend=true
local previous=countRows()
Scan.DB.settings.scan_bnet_whispers=false;bn(b,71)
assert(countRows()==previous, 'disabled BNet scanner still created rows')
Scan.DB.settings.scan_bnet_whispers=true
Scan.DB.settings.ignored={[BNet.FromID(71)]=1};bn(b,71)
assert(countRows()==previous, 'BNet ignore was bypassed')
Scan.DB.settings.ignored=nil
local secret={};issecretvalue=function(value) return value==secret end
bn(secret);bn(a,secret);friends[1].battleTag=secret;bn(a,99)
assert(countRows()==previous, 'secret event payload was consumed')
friends[1].battleTag='Friend#1234'
issecretvalue=function() return false end
HironCraftScanComm.applying_remote_state=true
Scan.OnMessage('CHAT_MSG_CHANNEL',b,key,nil,{battleNet=true})
assert(countRows()==previous, 'linked packet injected a private BNet conversation')
HironCraftScanComm.applying_remote_state=false
-- Reusing a completed item's row must start a new character snapshot too.
Scan.QuickReplies.OnWhisper=function() end
Scan.OrderFulfillment={Status={Fulfilled='fulfilled',Rejected='rejected',Failed='failed'},
    GetStatus=function() return {status='fulfilled'} end}
friends[1].gameAccountInfo.characterName='Nextbuyer'
local beforeRestart=#bnetSent
bn(a,99)
assert(info.responses[101].battleNetCharacters['nextbuyer-realm']
    and not info.responses[101].battleNetCharacters['friendbuyer-realm'], 'new request kept the old buyer snapshot')
assert(not info.responses[101].greeting_sent and #bnetSent==beforeRestart, 'new friend request sent or consumed a greeting')
print('Battle.net scanner tests passed (filters, unique rows, history, manual replies, transport, ID reuse, friends, secrets, opt-out, isolation).')
