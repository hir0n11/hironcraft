-- Pure, data-only rename tests. No chat or game mutation APIs are available.
local Scan = {}
assert(loadfile('Utils/CharacterRenames.lua'))('HironCraft',Scan)
local M = Scan.CharacterRenames
local owner = 'account-owner'
local from, target = 'Oldsmith-Realm', 'Newsmith-Realm'
local function profile(rev, keyword)
    return {sourceID=owner,parent_professions={[164]={rev=rev,keywords=keyword,scanning_enabled=true}},
        professions={[100]={parentProfID=164,concentration={amount=20},recipes={
            [1]={scan_state=1,keywords=keyword,greeting='Send to Oldsmith.'},
        }}}}
end
local function database()
    return {settings={my_uuid=owner,character_renames={
        [from]={to=target,sourceID=owner},
    }},realms={Realm={characters={[from]=profile(5,'old monitored wrist')},customers={},
        listed_orders={},order_statuses={},order_completion_notices={},linked_accounts={}}}}
end
local db = database()
local realm = db.realms.Realm
local fresh = profile(2,'fresh default')
fresh.professions[100].concentration.amount=88
fresh.professions[100].recipes[2]={scan_state=0,keywords='new recipe'}
realm.characters[target]=fresh
local notice={crafterFullName=from,orderID=123,status='fulfilled',requestToken='immutable-token',rev=8}
realm.order_completion_notices['original-journal-key']=notice
local response={crafterFullName=from,crafterName='Oldsmith',conversationCharacter=from,
    requestToken='immutable-token',greeting_sent=true,customer_answered=true,message={'Sent to Oldsmith earlier'}}
realm.customers['Oldsmith-Realm']={customerName=from,responses={[1]=response},
    chat_history={{message='Actual old chat: Oldsmith',conversationOwners={{character=from,responseID=1}}}}}
local history=realm.customers[from].chat_history
realm.order_statuses['customer-1']={crafterFullName=from,origin=owner,status='fulfilled',rev=9}
db.settings.linked_accounts={peer={backup_chars={from,target,'Other-Realm'},last_active_char=from}}
db.settings.greeting={rev=4,text='Oldsmith Oldsmith-Realm Oldsmith-Elsewhere OldsmithLong'}
db.settings.explanations={rev=1,text='Ask Oldsmith |Hitem:100:0|h[Oldsmith item]|h'}
db.settings.quick_replies={rev=10,templates={{id='stable-id',text='send to Oldsmith'}}}
db.settings.substitution_tags={crafter='Oldsmith'}
local count,errors=M.Apply(db)
assert(count==1 and #errors==0)
local renamed=realm.characters[target]
assert(not realm.characters[from] and renamed.sourceID==owner)
assert(renamed.parent_professions[164].rev==6 and renamed.parent_professions[164].keywords=='old monitored wrist')
assert(renamed.professions[100].recipes[1].scan_state==1 and renamed.professions[100].recipes[2].scan_state==0)
assert(renamed.professions[100].concentration.amount==88, 'fresh concentration was overwritten')
assert(renamed.professions[100].recipes[1].greeting=='Send to Newsmith.')
local backup=db.settings.character_rename_backups.Realm[from]
assert(backup.old.parent_professions[164].keywords=='old monitored wrist')
assert(backup.previousTarget.parent_professions[164].keywords=='fresh default')
assert(response.crafterFullName==target and response.crafterName=='Newsmith' and response.conversationCharacter==target)
assert(response.greeting_sent and response.customer_answered and response.requestToken=='immutable-token')
assert(response.message[1]=='Sent to Oldsmith earlier' and history[1].message=='Actual old chat: Oldsmith')
assert(history[1].conversationOwners[1].character==target and realm.customers[from].customerName==from)
assert(notice.crafterFullName==target and notice.origin==from and notice.rev==8 and notice.requestToken=='immutable-token')
assert(realm.order_completion_notices['original-journal-key']==notice, 'journal identity changed')
assert(realm.order_statuses['customer-1'].origin==owner and realm.order_statuses['customer-1'].rev==9)
assert(#db.settings.linked_accounts.peer.backup_chars==2 and db.settings.linked_accounts.peer.last_active_char==target)
assert(db.settings.greeting.text=='Newsmith Newsmith-Realm Oldsmith-Elsewhere OldsmithLong')
assert(db.settings.explanations.text=='Ask Newsmith |Hitem:100:0|h[Oldsmith item]|h')
assert(db.settings.quick_replies.templates[1].id=='stable-id' and db.settings.quick_replies.templates[1].text=='send to Newsmith')
assert(db.settings.greeting.rev==5 and db.settings.substitution_tags.crafter=='Newsmith')
assert(M.Resolve(from,db)==target and M.Resolve('Oldsmith-Elsewhere',db)=='Oldsmith-Elsewhere')
assert(M.Apply(db)==0 and renamed.parent_professions[164].rev==6 and db.settings.greeting.rev==5)
assert(db.settings.character_rename_backups.Realm[from]==backup, 'idempotent replay replaced backup')
local lateConfig={rev=99,text='Oldsmith Oldsmith-Realm'}
M.NormalizeEditable(lateConfig,db)
assert(lateConfig.rev==100 and lateConfig.text=='Newsmith Newsmith-Realm')
M.NormalizeEditable(lateConfig,db)
assert(lateConfig.rev==100, 'replayed normalized config keeps bumping revision')

local shared=M.ExportOwn(db)
assert(shared[from].to==target and shared[from].sourceID==owner and not shared[from].active)
local remote=database()
remote.settings.my_uuid='other-account';remote.settings.character_renames={}
M.AcceptRemote(remote,shared,'forged-account')
assert(remote.realms.Realm.characters[from] and not remote.realms.Realm.characters[target])
M.AcceptRemote(remote,shared,owner)
assert(not remote.realms.Realm.characters[from] and remote.realms.Realm.characters[target])
assert(not M.ExportOwn(remote), 'peer re-exported someone else\'s rename as its own')
M.AcceptRemote(remote,{[from]={to='Wrong-Realm',sourceID=owner}},owner)
assert(M.Resolve(from,remote)==target, 'conflicting rename replaced accepted mapping')
local incoming={[from]=profile(99,'stale'),[target]=profile(6,'current')}
local filtered=M.FilterIncomingCharacters(incoming,remote)
assert(not filtered[from] and filtered[target] and incoming[from], 'old profile resurrected or input was modified')
incoming[from].sourceID='unrelated-owner'
assert(M.FilterIncomingCharacters(incoming,remote)[from], 'unrelated account character was suppressed')

local conflict=database()
conflict.realms.Realm.characters[target]=profile(2,'do not overwrite')
conflict.realms.Realm.characters[target].sourceID='unrelated-owner'
count,errors=M.Apply(conflict)
assert(count==0 and #errors==1 and conflict.realms.Realm.characters[from])
assert(M.Resolve(from,conflict)==from and not conflict.settings.character_rename_backups)
local cycle=database()
cycle.settings.character_renames[target]={to=from,sourceID=owner}
assert(M.Apply(cycle)==0 and M.Resolve(from,cycle)==from)
local malformed=database();malformed.settings.character_renames=false
assert(M.Apply(malformed)==0 and M.Resolve(from,malformed)==from)

-- Exercise the actual Comm receive/send integration, including an alias-only
-- packet and an old profile bundled with the first rename announcement.
local noop=function() end
local comm, refreshes, sent={},0,{}
LibStub=function() return {NewAddon=function() return comm end} end
CreateFramePool=function() return {} end
HironCraftScanScannerMenu={RegisterEventCallback=noop}
Scan.CONST={TEXT={}};Scan.LOCAL={GetText=function() return '' end}
Scan.Events={Register=noop}
Scan.Utils={onLoad=noop}
Scan.OnCrafterListModified=function() refreshes=refreshes+1 end
assert(loadfile('Utils/Comm.lua'))('HironCraft',Scan)
comm.Transmit=function(_,data) sent[#sent+1]=data end
local function findUpvalue(fn,wanted,seen)
    seen=seen or {};if seen[fn] then return end;seen[fn]=true
    for i=1,100 do
        local name,value=debug.getupvalue(fn,i)
        if not name then break end
        if name==wanted then return value end
        if type(value)=='function' then
            local result=findUpvalue(value,wanted,seen)
            if result then return result end
        end
    end
end
local receive=assert(findUpvalue(comm.OnCommReceived,'ReceiveShareCharacterData'))
local send=assert(findUpvalue(receive,'SendShareCharacterData'))
local function preparePeer()
    local data=database();data.settings.my_uuid='peer';data.settings.character_renames={}
    HironCraftScan_DB=data
    Scan.DB={settings=data.settings,realm=data.realms.Realm,characters=data.realms.Realm.characters}
    return data
end
local peer=preparePeer()
receive(target,{state=3,character_renames=shared},owner)
assert(refreshes==1 and Scan.DB.characters[target] and not Scan.DB.characters[from],
    'alias-only packet did not migrate and refresh the live scanner')
peer=preparePeer()
receive(target,{state=3,character_renames=shared,characters={[from]=profile(99,'stale packet')}},owner)
assert(not Scan.DB.characters[from] and Scan.DB.characters[target].parent_professions[164].rev==6)
assert(Scan.DB.characters[target].parent_professions[164].keywords=='old monitored wrist',
    'first-packet stale profile replaced migrated settings')
receive(target,{state=3,greeting={rev=101,text='Send to Oldsmith'}},owner)
assert(Scan.DB.settings.greeting.text=='Send to Newsmith' and Scan.DB.settings.greeting.rev==102)
HironCraftScan_DB=db
send('Peer-Realm',{})
assert(sent[#sent].character_renames[from].to==target and not sent[#sent].character_renames[from].active,
    'owner packet did not export the safe rename record')
print('Character rename tests passed (profile merge, snapshots, templates, history, ownership, sync, stale packets, conflicts, idempotence).')
