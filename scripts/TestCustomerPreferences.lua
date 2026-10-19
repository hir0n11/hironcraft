local now,printed,sent=1000,{},0
time=function() return now end
GetTime=time
GetNormalizedRealmName=function() return 'Realm' end
DEFAULT_CHAT_FRAME={AddMessage=function(_,s) printed[#printed+1]=s end}
SendChatMessage=function() sent=sent+1 end
local function Make(actor)
    local root={}
    local Scan={DB={settings={my_uuid=actor}},Utils={},LOCAL={GetText=function(_,s) return s end}}
    Scan.Utils.onLoad=function() end
    Scan.ChatFilter={DB=function() return root end,Changed=function() end}
    assert(loadfile('ChatFilter/FilterEngine.lua'))('HironCraft',Scan)
    assert(loadfile('ChatFilter/IgnoreList.lua'))('HironCraft',Scan)
    assert(loadfile('Customer/CustomerPreferences.lua'))('HironCraft',Scan)
    return Scan,Scan.ChatIgnore,Scan.CustomerPreferences
end
local S,I,P=Make('laptop')
local S2,I2,P2=Make('pc')
I.Add('Buyer',{seconds=3600,source='menu'})
assert(I.IsIgnored('Buyer-Realm') and not I.IsIgnored('Buyer-OtherRealm'))
assert(I.SecondsLeft('Buyer')==3600)
assert(#P.Snapshot()==1)
P2.Merge(P.Snapshot());assert(I2.IsIgnored('Buyer'))
local before=#printed
assert(I.Attempt('Buyer') and not I.Attempt('Buyer'))
assert(#printed==before+1 and I.Entry('Buyer').notified)
-- Notice flag is saved on the entry: reloading only the module cannot repeat it.
assert(loadfile('ChatFilter/IgnoreList.lua'))('HironCraft',S)
I=S.ChatIgnore
assert(not I.Attempt('Buyer'))
I.Settings().reply=true
assert(not I.ReplyTo('Buyer') and sent==0,'legacy GIL auto-reply is still active')
local old=P.Snapshot()[1]
now=4600
assert(not I.IsIgnored('Buyer') and not I2.IsIgnored('Buyer'))
P2.Merge(P.Snapshot())
P.Merge({old});assert(not I.IsIgnored('Buyer'),'expired ignore was resurrected')
I.Add('Buyer',{seconds=86400,replace=true})
assert(I.SecondsLeft('Buyer')==86400 and not I.Entry('Buyer').notified)
P2.Merge(P.Snapshot());assert(I2.IsIgnored('Buyer'))
I.Remove('Buyer')
local tombstone=P.Snapshot()[1]
assert(tombstone.removed)
P2.Merge({tombstone});P2.Merge({old})
assert(not I2.IsIgnored('Buyer'),'old offline snapshot undid an explicit unignore')
I.Add('Forever',{seconds=false,replace=true})
assert(I.IsIgnored('Forever') and I.SecondsLeft('Forever')==nil)
P.SetMuted('Quiet-Realm',true)
assert(P.IsMuted('quiet-realm') and not I.IsIgnored('Quiet'))
assert(not P.IsMuted('Quiet-OtherRealm'))
P.SetMuted('BNET:laptop:Friend#1234',true)
assert(P.IsMuted('BNET:pc:Friend#1234') and not P.IsMuted('BNET:pc:Friend#1235'))
I.Add('BNET:laptop:Ignored#1234',{seconds=3600,replace=true})
P2.Merge(P.Snapshot())
assert(I2.IsIgnored('BNET:pc:Ignored#1234'),'BattleTag block did not cross linked accounts')
P2.Merge(P.Snapshot());assert(P2.IsMuted('Quiet-Realm'))
P.SetMuted('Quiet-Realm',false)
P2.Merge(P.Snapshot());assert(not P2.IsMuted('Quiet-Realm'))
local state=P.Revisions();assert(#P.Delta(state)==0,'identical revisions kept exchanging')
assert(not P.Merge(P.Snapshot()),'identical records applied again')
local count=#P.Snapshot()
for _,bad in ipairs({{}, {id='ignore:x-realm',kind='ignore',name='X-Realm',n=0/0,by='p',expires=0,removed=false,at=now},
    {id='ignore:x-realm',kind='ignore',name='X-Realm',n=1,by='p',expires=-1,removed=false,at=now},
    {id='wrong',kind='ignore',name='X-Realm',n=1,by='p',expires=0,removed=false,at=now}}) do
    P.Merge({bad})
end
assert(#P.Snapshot()==count,'invalid records entered the database')
-- A subsequent GIL/game-list import must not turn a timed entry permanent.
I.Add('Timed',{seconds=60,replace=true})
I.Add('Timed',{source='game',fromGame=true,quiet=true})
assert(I.SecondsLeft('Timed')==60)
now=now+61;assert(not I.IsIgnored('Timed'))
-- Several accounts forwarding the same records converge without echo loops.
for _=1,3 do P.Merge(P2.Snapshot());P2.Merge(P.Snapshot()) end
assert(#P.Delta(P2.Revisions())==0 and #P2.Delta(P.Revisions())==0)
print('Customer preferences passed: timed/global ignore, no auto-reply, one persisted notice, independent whisper mute, realm identity, tombstones, offline expiry, convergence and validation.')
