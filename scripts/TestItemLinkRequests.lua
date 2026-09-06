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
function time() return 1000 end
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
assert(countRows()==3 and #Scan.DB.customers.Buyer.chat_history==1, 'repeat changed row/history count')
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
for _,text in ipairs({'need wrist enchant','need cloth wrist','need wrist for alt',
    'need ring','need weapon','need tool','need bag','need necklace','need shield'}) do
    assert(not Scan.ClassMatching.GetContext(text,'Class-WARRIOR'), 'class overrode explicit/non-armor request')
end
assert(not Scan.ClassMatching.GetContext('need wristwatch','Class-WARRIOR'), 'substring matched as an armor slot')
assert(forClass('need wrist','UNKNOWN').crafter=='Seller-Realm', 'unknown class changed normal matching')
Scan.DB.settings.match_customer_class=false
assert(forClass('need wrist','WARRIOR').crafter=='Seller-Realm', 'opt-out ignored')
Scan.DB.settings.match_customer_class=true
local getClass=GetPlayerInfoByGUID
GetPlayerInfoByGUID=function() error('unavailable') end
assert(forClass('need wrist','WARRIOR').crafter=='Seller-Realm', 'API error did not fall back safely')
GetPlayerInfoByGUID=getClass
local classAPI=GetPlayerInfoByGUID
GetPlayerInfoByGUID=nil
HironCraftScanComm.applying_remote_state=true
assert(forClass('need wrist','UNKNOWN',{customerClass='WARRIOR'}).crafter=='Smith-Realm',
    'linked request lost its known class when the receiving client lacked GUID data')
assert(forClass('need wrist','UNKNOWN',{customerClass='INVALID'}).crafter=='Seller-Realm')
HironCraftScanComm.applying_remote_state=false
assert(forClass('need wrist','UNKNOWN',{customerClass='WARRIOR'}).crafter=='Seller-Realm',
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
