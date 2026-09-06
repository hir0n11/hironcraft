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
    sent[#sent+1] = {message=message, customer=customer}
end
RobotsDotTxtAPI = {NotifyCustomer=noop}
C_Timer = {After=function(_, callback) timers[#timers+1]=callback end}
HironCraftScanComm = {applying_remote_state=false, ShareCustomerOrder=function(_, ...)
    shared[#shared+1] = {...}
end}
HironCraftScanCraftingOrderPage = {ShowGeneric=function() refreshes=refreshes+1 end, IsShown=function() return true end}
HironCraftScanScannerMenu = {ClearAlert=noop}
function ChatFrame_SendTell() opened=opened+1 end
Scan.QuickReplies = {
    ApplyConversationOwners=noop, GetConversationOwners=function() return {} end,
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

-- Respect the existing auto-reply policy and cancel stale delayed sends.
reset(); Scan.auto_replies_enabled=true
scan(a .. a .. c)
assert(#timers==1 and #sent==0)
scan(a .. c) -- Repeated incoming messages may queue checks, but cannot send twice.
flushTimers()
assert(#sent==2 and response(101).greeting_sent and response(103).greeting_sent)
reset(); Scan.auto_replies_enabled=true
scan(a .. b)
assert(#timers==0, 'mixed local/alt batch must not bypass manual alt greeting policy')
reset(); Scan.auto_replies_enabled=true
scan(a)
Scan.DismissOrder(order(101))
flushTimers()
assert(#sent==0, 'dismissed auto reply was sent')
reset(); Scan.auto_replies_enabled=true
scan(a)
local oldTimer=timers[1]
Scan.DismissOrder(order(101))
scan(a)
oldTimer()
assert(#sent==0, 'old timer sent a replacement request')
flushTimers()
assert(#sent==1)
reset()
Scan.DB.settings.ignored={Buyer=true}
scan(a .. b)
assert(countRows()==0 and #shared==0, 'ignored customer bypassed exclusion')
print('Item-link request tests passed (filters, unique rows, grouped replies, tokens, stale timers).')
