local function noop() end
time = function() return 1000 end
CreateFrame = function() return {RegisterEvent=noop, SetScript=noop} end
ChatFrame_AddMessageEventFilter = noop
local function Copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}; for k,v in pairs(value) do result[k]=Copy(v) end; return result
end
local function Use(account)
    HironCraftScan_DB = account.root
    C_Timer = {After=function(_,fn) account.timers[#account.timers+1]=fn end}
    HironCraftScanComm = {ShareChatFilterRules=function(_,records)
        account.sent[#account.sent+1]=Copy(records)
    end}
    return account.Scan.ChatFilter, account.Scan.ChatFilterSync
end
local function New(actor, root)
    local a = {root=root or {}, timers={}, sent={}, Scan={DB={settings={my_uuid=actor}}, Utils={onLoad=noop}}}
    Use(a)
    assert(loadfile('ChatFilter/FilterEngine.lua'))('HironCraft', a.Scan)
    assert(loadfile('ChatFilter/ChatFilter.lua'))('HironCraft', a.Scan)
    assert(loadfile('ChatFilter/RuleSync.lua'))('HironCraft', a.Scan)
    return a
end
local function Flush(a)
    Use(a); local list=a.timers; a.timers={}; for _,fn in ipairs(list) do fn() end
end
local function Exchange(a,b)
    local _,bs=Use(b); local revisions=bs.Revisions()
    local _,as=Use(a); local delta=as.Delta(revisions)
    Use(b); bs.Merge(delta)
end
local function Converge(a,b) Exchange(a,b); Exchange(b,a); Exchange(a,b) end
local function ByKey(a,key)
    local f=Use(a); for _,r in ipairs(f.Rules()) do if r.key==key then return r end end
end
local a,b,c=New('a'),New('b'),New('c')
local f,s=Use(a)
f.AddKey('spam', true); f.AddExpression('[contains=boost]', 'Boosts')
f.Rules()[1].count=17; f.Rules()[1].history={{m='private'}}
local f2=Use(b); f2.AddKey('spam',true); f2.AddKey('gold',false)
f2.DB().enabled=false; f2.DB().log={{m='local'}}
Converge(a,b)
f,s=Use(a); assert(#f.Rules()==3 and ByKey(a,'spam').count==17)
f2=Use(b); assert(#f2.Rules()==3 and ByKey(b,'spam').count==0)
assert(not f2.DB().enabled and f2.DB().log[1].m=='local', 'sync replaced account-local state')
Converge(b,c); assert(ByKey(c,'gold'), 'third linked account did not receive the library')

-- Rename, content, whole-word and enable switches travel, not hit counters.
f,s=Use(a); local rule=ByKey(a,'spam'); local id=rule.syncID
rule.name,rule.key,rule.whole,rule.on='Renamed','new spam',false,false
f.Changed(); Converge(a,b)
local r=ByKey(b,'new spam'); assert(r and r.syncID==id and not r.on and not r.whole and r.name=='Renamed')
assert(not ByKey(b,'spam'))
f,s=Use(a); local before=s.Revisions(); rule.count=99; rule.history={{m='another private'}}; f.Changed()
assert(#s.Delta(before)==0, 'local hits generated shared updates')
Flush(a)
for _,batch in ipairs(a.sent) do for _,record in ipairs(batch) do
    assert(not record.history and not record.count and not record.at, 'local statistics escaped onto the wire')
end end

-- Removed rules stay removed when an offline account reconnects/relogs.
f,s=Use(a); f.RemoveRule(ByKey(a,'gold').id)
Converge(a,b); Converge(c,b); Converge(a,b)
assert(not ByKey(a,'gold') and not ByKey(b,'gold') and not ByKey(c,'gold'))
b=New('b',Copy(b.root)); Converge(a,b); assert(not ByKey(b,'gold'), 'reload forgot a tombstone')

-- Re-adding an old keyword doesn't overwrite the edited original identity.
f,s=Use(a); f.AddKey('spam',true); Converge(a,b)
assert(ByKey(b,'new spam') and ByKey(b,'spam') and ByKey(b,'spam').syncID~=id)

-- Simultaneous edits converge deterministically independent of packet order.
Converge(a,b)
f,s=Use(a); ByKey(a,'new spam').name='A edit'; f.Changed(); local pa=s.Delta({})
f2,s=Use(b); ByKey(b,'new spam').name='B edit'; f2.Changed(); local pb=s.Delta({})
Use(a); a.Scan.ChatFilterSync.Merge(pb)
Use(b); b.Scan.ChatFilterSync.Merge(pa)
Converge(a,b)
assert(ByKey(a,'new spam').name==ByKey(b,'new spam').name, 'conflicts oscillate')
Flush(a); Flush(b)
local out=#b.sent
Use(b); assert(not b.Scan.ChatFilterSync.Merge(a.Scan.ChatFilterSync.Delta(nil)))
Exchange(a,b); Flush(b); assert(#b.sent==out, 'unchanged state was echoed again')

-- Invalid payloads are ignored. Definitions are whitelisted.
f,s=Use(b); local n=#f.Rules()
for _,bad in ipairs({{}, {id='x',n=0,by='a',deleted=true}, {id='x',n=1/0,by='a',deleted=true},
    {id='x',n=999,by='a',name='bad',expr='[unknown=x]',on=true}}) do assert(not s.Merge({bad})) end
assert(#f.Rules()==n)
assert(s.Merge({{id='clean',n=999,by='a',name='clean',key='clean',whole=false,on=true,
    history={{m='injected'}},count=123,at=555}}))
r=ByKey(b,'clean'); assert(r.count==0 and not r.history and r.at==1000)
print('Chat filter sync passed (union, three accounts, edits, deletion, offline/reload, local history, conflicts, no echoes, validation).')
