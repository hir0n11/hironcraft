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
}
Scan.LOCAL = {GetText=function(_, key) return greetings[key] or key end}
local function loadSource(path) return assert(loadfile(path))('HironCraft', Scan) end
function CreateFrame() return {SetScript=noop, RegisterEvent=noop, UnregisterEvent=noop} end
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
    settings={inclusions='lf,need craft', exclusions='wts,crafting services', auto_reply_delay=1000},
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

-- The manual menu is a real synchronous click-to-send path. It must use the
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
local root={CreateDivider=noop,CreateTitle=function() return {SetTooltip=noop} end,
    CreateButton=function(_,label,click) buttons[#buttons+1]={label=label,click=click};return {SetTooltip=noop} end}
local chatReads=0
C_ChatInfo={GetChatLineText=function(id) assert(id==44);chatReads=chatReads+1;return 'LF '..a end,
    GetChatLineSenderGUID=function() return 'Manual-GUID' end}
menus.MENU_UNIT_FRIEND(nil,root,{chatTarget='ManualBuyer-Realm',lineID='44'})
assert(#sent==0 and countRows()==0, 'opening the manual menu took an action')
buttons[2].click()
assert(#sent==1 and sent[1].customer=='ManualBuyer-Realm' and chatReads==1)
local manualResponse=Scan.DB.customers['ManualBuyer-Realm'].responses[197]
assert(manualResponse.crafterFullName=='Tailor-Realm' and not manualResponse.itemID and manualResponse.greeting_sent)
buttons={};menus.MENU_UNIT_FRIEND(nil,root,{chatTarget='Expired-Realm'})
buttons[1].click()
assert(#sent==2 and sent[2].customer=='Expired-Realm' and chatReads==1, 'expired line blocked the clicked profession greeting')
flushTimers();assert(#sent==2, 'manual matching scheduled more messages')
Scan.GetSortedCrafters, Scan.ColorizeCrafterName, Scan.Utils.ColorizeProfessionName, Scan.Utils.ProfessionNameByID=
    getSorted, colorCrafter, colorProfession, professionName
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
        if info then return id,'Armor','Armor',info.slot,0,4,info.armor end
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
for _,text in ipairs({'need wrist for alt',
    'need ring','need weapon','need tool','need bag','need necklace','need shield'}) do
    assert(not Scan.ClassMatching.GetContext(text,'Class-WARRIOR'), 'class overrode explicit/non-armor request')
end
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

reset()
Scan.OnMessage('CHAT_MSG_CHANNEL','need wrist','LateClass','Late-GUID')
assert(countRows()==0 and #sent==0 and #timers==1, 'unknown class guessed or sent a response')
classByGUID['Late-GUID']='WARRIOR';flushTimers()
assert(countRows()==1 and Scan.DB.customers.LateClass.responses[201].crafterFullName=='Smith-Realm')
assert(#sent==0, 'class-cache retry sent player chat')
reset();Scan.OnMessage('CHAT_MSG_CHANNEL','need wrist','NeverClass','Never-GUID')
for i=1,4 do flushTimers() end
assert(countRows()==0 and #timers==0 and #sent==0, 'unknown class retries did not stop safely')

reset()
classByGUID['Buyer-GUID']='WARRIOR'
scan('need wrist')
assert(countRows()==1 and response(201).crafterFullName=='Smith-Realm' and #sent==0)
flushTimers()
assert(#sent==0, 'class routing introduced auto replies')
Scan.GreetCustomer('LeftButton',order(201))
assert(#sent==1 and response(201).greeting_sent, 'class-routed greeting did not send on click')
reset()
classByGUID['Buyer-GUID']='HUNTER'
scan('LF lw')
Scan.OnMessage('CHAT_MSG_WHISPER','need wrist','Buyer','Buyer-GUID')
assert(response(204) and not response(203), 'existing whisper conversation lost the sender class')
print('Customer-class matching tests passed (13 classes, armor slots, links, exclusions, opt-out, unknown data, whispers, manual sends).')

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
