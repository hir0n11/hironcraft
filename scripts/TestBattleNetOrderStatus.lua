-- Real Battle.net identity, fulfillment events and row rendering. No live API,
-- chat sending, crafting or addon transport is available in this harness.
local noop = function() end
local now, callbacks, timers = 1000, {}, {}
local Scan = {
    DB={settings={my_uuid='local'}, realm={}, listed_orders={}, customers={}},
    Utils={onLoad=function(callback) callback() end,
        saved=function(t,k,v) if t[k]==nil then t[k]=v end; return t[k] end},
    Events={Emit=noop}, CONST={TEXT={}}, LOCAL={GetText=function(_,k) return k end},
    GetPlayerName=function() return 'Crafter-Realm' end,
}
Scan.OrderToOrderID=function(order) return order.customerName..':'..order.responseID end
Scan.OrderToResponse=function(order) return Scan.DB.customers[order.customerName].responses[order.responseID] end
Scan.OrderToLiveResponse=function() return {} end
function time() return now end
local secret={}
function issecretvalue(value) return value==secret end
function GetNormalizedRealmName() return 'Realm' end
WOW_PROJECT_ID=1
local function character(name,realm)
    return {characterName=name, realmName=realm or 'Realm', clientProgram='WoW',
        isOnline=true, wowProjectID=1, isInCurrentRegion=true}
end
local games={character('Buyer'), character('Altbuyer','Other Realm')}
games[1].playerGuid='Player-1-AAAA'
games[2].playerGuid='Player-2-BBBB'
local friend={isFriend=true,bnetAccountID=40,battleTag='Friend#1234',accountName='Buyer'}
function BNGetNumFriends() return 1 end
C_BattleNet={GetFriendAccountInfo=function() return friend end,
    GetAccountInfoByID=function(id) if id==friend.bnetAccountID then return friend end end,
    GetFriendNumGameAccounts=function() return #games end,
    GetFriendGameAccountInfo=function(_,index) return games[index] end}
C_Timer={After=function(_,callback) timers[#timers+1]=callback end}
HironCraftScanScannerMenu={RegisterEventCallback=function(_,event,callback) callbacks[event]=callback end}
local claimed
C_CraftingOrders={GetClaimedOrder=function() return claimed end}
local function load(path) assert(loadfile(path))('HironCraft',Scan) end
load('Customer/BattleNet.lua')
load('Customer/OrderFulfillment.lua')
local BNet, Status = Scan.BattleNet, Scan.OrderFulfillment
local key=BNet.FromID(40)
local function row(customer,id,item)
    local order={customerName=customer,responseID=id}
    local info=Scan.DB.customers[customer] or {responses={}}
    Scan.DB.customers[customer]=info
    info.responses[id]={time=now-10,requestToken='private-'..id,recipeID=id,itemID=item,
        crafterFullName='Crafter-Realm',parentProfID=164,greeting_sent=false,customer_answered=true}
    Scan.DB.listed_orders[Scan.OrderToOrderID(order)]=order
    return order,info.responses[id]
end
local order,response=row(key,101,1001)
BNet.RememberCharacters(key,response)
assert(response.battleNetCharacters['buyer-realm'] and response.battleNetCharacters['altbuyer-otherrealm'])
assert(BNet.MatchesCraftingCustomer(key,'Buyer',response))
assert(BNet.MatchesCraftingCustomer(key,'Altbuyer-OtherRealm',response))
assert(BNet.MatchesCraftingCustomer(key,'Altbuyer',response,'Smith-Other Realm'))
assert(BNet.MatchesCraftingCustomer(key,'Altbuyer',response,'Smith-Realm','Player-2-BBBB'), 'GUID did not resolve an unqualified cross-realm buyer')
assert(not BNet.MatchesCraftingCustomer(key,'Buyer',response,nil,'Player-9-FFFF'), 'wrong GUID overrode a matching full name')
assert(not BNet.MatchesCraftingCustomer(key,'Altbuyer',response,'Smith-Realm'))
assert(not BNet.MatchesCraftingCustomer(key,'Buyer-DifferentRealm',response))
assert(not BNet.MatchesCraftingCustomer(key,'Friend',response), 'BattleTag was treated as a character')
assert(not BNet.MatchesCraftingCustomer(key,secret,response))
assert(not BNet.MatchesCraftingCustomer(key,'Buyer',response,secret))
assert(not BNet.MatchesCraftingCustomer(key,'Buyer',response,'Smith'), 'unknown source realm guessed')
friend.bnetAccountID=99
assert(BNet.MatchesCraftingCustomer(key,'Buyer',response), 'session ID change broke durable identity')
Scan.DB.settings.my_uuid='other'
assert(not BNet.MatchesCraftingCustomer(key,'Buyer',response), 'another account inherited private aliases')
Scan.DB.settings.my_uuid='local'
friend.isFriend=false
assert(not BNet.MatchesCraftingCustomer(key,'Buyer',response), 'removed friend kept an active mapping')
friend.isFriend=true
friend.battleTag='Friend#5678'
assert(not BNet.MatchesCraftingCustomer(key,'Buyer',response), 'same display name merged friends')
friend.battleTag='Friend#1234'
games={character('Newalt')}
assert(BNet.MatchesCraftingCustomer(key,'Buyer',response), 'switching alts discarded request identity')
local fresh={}
BNet.RememberCharacters(key,fresh)
assert(not BNet.MatchesCraftingCustomer(key,'Buyer',fresh), 'new request inherited an old character')
games={}
assert(BNet.MatchesCraftingCustomer(key,'Buyer',response), 'offline friend lost verified request identity')
assert(not BNet.MatchesCraftingCustomer(key,'Buyer',{}), 'offline friend without evidence was guessed')

for _,field in ipairs({'characterName','realmName','clientProgram','isOnline','wowProjectID','isInCurrentRegion'}) do
    local invalid=character('Secretbuyer');invalid[field]=secret;games={invalid}
    local unseen={};BNet.RememberCharacters(key,unseen)
    assert(not unseen.battleNetCharacters, 'secret '..field..' was persisted')
end
for _,override in ipairs({{wowProjectID=2},{clientProgram='D3'},{isOnline=false},{isInCurrentRegion=false}}) do
    local invalid=character('Wrongbuyer');for k,v in pairs(override) do invalid[k]=v end;games={invalid}
    local unseen={};BNet.RememberCharacters(key,unseen)
    assert(not unseen.battleNetCharacters, 'wrong game/region/offline character accepted')
end
games={}
friend.gameAccountInfo=character('Fallbackbuyer')
local numAccounts=C_BattleNet.GetFriendNumGameAccounts
C_BattleNet.GetFriendNumGameAccounts=nil
assert(BNet.MatchesCraftingCustomer(key,'Fallbackbuyer',{}), 'representative WoW account fallback failed')
C_BattleNet.GetFriendNumGameAccounts=function() error('API unavailable') end
assert(not BNet.MatchesCraftingCustomer(key,'Missing',{}), 'API failure guessed a name')
C_BattleNet.GetFriendNumGameAccounts=numAccounts
friend.gameAccountInfo=nil

-- Actual interaction-cell renderer: incoming contact must not set greeting_sent.
function CreateFromMixins(...) local t={};for _,m in ipairs({...}) do for k,v in pairs(m) do t[k]=v end end;return t end
TableBuilderCellMixin,TableBuilderElementMixin={},{}
EnumUtil={MakeEnum=function(...) local t={};for i,k in ipairs({...}) do t[k]=i end;return t end}
load('Customer/OrderTableTemplate.lua')
local function icon() return {SetAtlas=function(self,atlas) self.atlas=atlas end} end
local cell=CreateFromMixins(HironCraftScanCrafterTableCellInteractionMixin)
cell.PlayerIcon,cell.CustomerIcon=icon(),icon()
cell.OrderStatus={Refresh=function(self) self.entry=Status:GetStatus(self.order) end}
cell:Populate({order=order})
assert(cell.PlayerIcon.atlas=='common-icon-checkmark' and cell.CustomerIcon.atlas=='common-icon-checkmark')
assert(not response.greeting_sent, 'rendering consumed the click-only greeting')
assert(not cell.OrderStatus.entry)
local normal,normalResponse=row('Normal-Realm',102,1002)
cell:Populate({order=normal})
assert(cell.PlayerIcon.atlas=='common-icon-redx', 'ordinary greeting indicator changed')
normalResponse.greeting_sent=true;cell:Populate({order=normal})
assert(cell.PlayerIcon.atlas=='common-icon-checkmark')
response.customer_answered=false;cell:Populate({order=order})
assert(cell.PlayerIcon.atlas=='common-icon-redx', 'contact shown without incoming or outgoing interaction')
response.customer_answered=true

-- Event-backed fulfillment matches the game character to the private row.
claimed={orderID=501,customerName='Altbuyer',customerGuid='Player-2-BBBB',spellID=101,itemID=1001,parentProfessionID=164}
assert(Status:FindMatchingOrder(claimed)==order)
callbacks.CRAFTINGORDERS_CLAIMED_ORDER_ADDED(nil,501)
assert(Status:GetStatus(order).status=='claimed')
callbacks.CRAFTINGORDERS_CRAFT_ORDER_RESPONSE(nil,0,501)
assert(Status:GetStatus(order).status=='crafted')
claimed=nil -- Blizzard clears the live order before the final event.
callbacks.CRAFTINGORDERS_FULFILL_ORDER_RESPONSE(nil,0,501)
cell:Populate({order=order})
assert(cell.OrderStatus.entry.status=='fulfilled', 'completion did not update the Battle.net row')
for _,notice in pairs(Status:GetCompletionNotices()) do
    assert(notice.customerGuid=='Player-2-BBBB', 'game-order GUID lost between capture and completion journal')
    assert(not BNet.IsCustomer(notice.customerName) and not notice.requestToken and not notice.requestTime,
        'private request metadata entered the shared completion journal')
end
assert(not Status:GetStatus(normal))

-- An ordinary game-order notice from another linked crafter updates locally.
local second,secondResponse=row(key,103,1003)
secondResponse.battleNetCharacters={['buyer-realm']=true}
secondResponse.crafterFullName='Linkedcrafter-Realm'
local notice={orderID=502,customerName='Buyer',spellID=103,itemID=1003,
    updatedAt=now,origin='linked',crafterFullName='Linkedcrafter-Realm',status='fulfilled'}
assert(Status:ApplyRemoteCompletion(notice))
assert(Status:GetStatus(second).status=='fulfilled')
assert(Status:GetStatuses()[Scan.OrderToOrderID(second)].requestToken==secondResponse.requestToken)
now=now+1
assert(Status:ToggleManual(second).status=='unknown')
Status:ApplyRemoteCompletion(notice)
assert(not Status:GetStatus(second), 'journal replay resurrected a manually cleared check')
now=now+1;secondResponse.time=now;secondResponse.requestToken='new-private-request'
assert(not Status:GetStatus(second), 'old completion marked a new request')

-- Fail closed on recipe, character and realm mismatches, including generic rows.
local third,thirdResponse=row(key,104,1004)
thirdResponse.battleNetCharacters={['buyer-realm']=true}
Status:ApplyRemoteCompletion({orderID=503,customerName='Buyer-OtherRealm',spellID=104,
    updatedAt=now,origin='linked',crafterFullName='Linkedcrafter-Realm'})
assert(not Status:GetStatus(third), 'same character name on another realm matched')
Status:ApplyRemoteCompletion({orderID=504,customerName='Buyer',spellID=104,
    updatedAt=now,origin='linked',crafterFullName='Linkedcrafter-OtherRealm'})
assert(not Status:GetStatus(third), 'unqualified remote name used the receiving realm')
Status:ApplyRemoteCompletion({orderID=505,customerName='Buyer-Realm',spellID=999,
    updatedAt=now,origin='linked',crafterFullName='Linkedcrafter-Realm'})
assert(not Status:GetStatus(third), 'different item completion matched')
local fourth,fourthResponse=row(key,105,1005)
fourthResponse.battleNetCharacters={['buyer-realm']='Player-1-AAAA'}
Status:ApplyRemoteCompletion({orderID=506,customerName='Buyer',customerGuid='Player-1-AAAA',spellID=105,
    updatedAt=now,origin='linked',crafterFullName='Linkedcrafter-OtherRealm'})
assert(Status:GetStatus(fourth).status=='fulfilled', 'linked cross-realm GUID completion did not match')
Status:ApplyRemoteCompletion({orderID=507,customerName='Unknown',customerGuid=secret,spellID=105,
    updatedAt=now,origin='linked',crafterFullName='Linkedcrafter-Realm'})
for _,stored in pairs(Status:GetCompletionNotices()) do assert(stored.customerGuid~=secret) end
local generic,genericResponse=row(key,164)
genericResponse.recipeID=nil;genericResponse.battleNetCharacters={['buyer-realm']=true}
assert(#Status:FindGenericOrders({customerName='Buyer-Realm',parentProfessionID=164})==1)
assert(#Status:FindGenericOrders({customerName='Buyer-OtherRealm',parentProfessionID=164})==0)
assert(#Status:FindGenericOrders({customerName='Buyer-Realm',parentProfessionID=197})==0)
assert(not Status:ApplyRemoteCompletion({customerName=key,updatedAt=now,origin='linked'}))
assert(not Status:ApplyRemoteStatus({customerName=key,responseID=101,status='failed',updatedAt=now}))
print('Battle.net order status tests passed (contact, identities, realms, snapshots, completion events, linked notices, manual override, privacy).')
