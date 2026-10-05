-- Natural reagent messages must enumerate every shortage/replacement and retain
-- uncertainty. Use real locale dictionaries, tag expansion and chat splitting.
local function noop() end
local nextID=0
local Scan={DB={settings={}},Config={SubstituteTags=function(value) return value end},
    Utils={onLoad=noop,DeepCopy=function(value) return value end},
    Events={Register=noop,Emit=noop},CONST={TEXT=setmetatable({}, {__index=function(t,key)
        nextID=nextID+10;t[key]=nextID;return nextID end})}}
function Scan.Utils.saved(parent,key,value) if parent[key]==nil then parent[key]=value end;return parent[key] end
Scan.LOCAL={GetText=function(_,key) return Scan.L[key] or key end}
EnumUtil={MakeEnum=function() return {} end};CreateFrame=function() return {} end
function GetLocale() return 'ruRU' end
function strsplit(delimiter,text)
    local parts,start={},1
    while true do
        local first,last=text:find(delimiter,start,true)
        parts[#parts+1]=text:sub(start,first and first-1)
        if not first then return table.unpack(parts) end
        start=last+1
    end
end
for _,file in ipairs({'Locales/enUS.lua','Locales/ruRU.lua','Utils/FStrings.lua',
    'Customer/ChatScanner.lua','Customer/ReagentAudit.lua','Customer/QuickReplies.lua'}) do
    assert(loadfile(file))('HironCraft',Scan)
end
local A,Q=Scan.ReagentAudit,Scan.QuickReplies
Scan.BuildResponseContext=function(response) return {reagent_issues=A.Issues(response.audit)} end
local function row(name,required,quantity,tier,maxTier)
    return {name=name,required=required,known=true,maxQuality=maxTier,supplied=quantity and {
        {name=name,quantity=quantity,quality=tier,maxQuality=maxTier,qualityKnown=true}} or {}}
end
local function snapshot(...) return {complete=true,rows={...}} end
assert(A.Issues(snapshot(row('Thread',1)))=="Looks like you're missing 1 Thread.")
assert(A.Issues(snapshot(row('Thread',2)))=="Looks like you're missing 2 Thread.")
local multi=snapshot(row('Alloy',40,20,1,2),row('Thread',3),row('Spark',2),
    row('Missive',1,1,1,2),row('Lining',1,1,2,3))
multi.rows[4].optional=true;multi.rows[5].optional=true
local expected="Looks like you're missing 20 Alloy (T2), 3 Thread and 2 Spark. "
    ..'Could you replace 20 T1 Alloy with T2, 1 T1 Missive with T2 and 1 T2 Lining with T3, please?'
assert(A.Issues(multi)==expected)
assert(not expected:find('Missing:',1,true) and not expected:find('Replace:',1,true))
local onlyQuality=snapshot(row('Alloy',40,40,1,2))
assert(A.Issues(onlyQuality)=='Could you replace 40 T1 Alloy with T2, please?')
assert(A.Issues(onlyQuality,true)=='Можешь заменить 40 шт. T1 Alloy на T2, пожалуйста?')
local russian=A.Issues(multi,true)
assert(russian:find('20 Alloy (T2), 3 Thread и 2 Spark',1,true)
    and russian:find('20 шт. T1 Alloy на T2, 1 шт. T1 Missive на T2 и 1 шт. T2 Lining на T3',1,true))
-- Unknown quantities must not invent a shortage, even alongside known problems.
multi.complete=false
multi.rows[#multi.rows+1]={name='Unknown',required=100,known=false,supplied={}}
assert(A.Issues(multi)==expected.." I couldn't check all of the materials, so please double-check the rest too.")
assert(A.Issues(nil)=="I couldn't find the material details for this order. Could you double-check them, please?")
assert(A.Issues(snapshot(row('Alloy',40,40,2,2)))==
    "I couldn't confirm which materials need changing. Could you double-check the order, please?")
local recraft=snapshot(row('Alloy',40,40,2,2))
recraft.reason='insufficient_quality';recraft.isRecraft=true
recraft.quality={currentQuality=4,requestedQuality=5}
assert(A.Issues(recraft)=='Your materials look fine, but the game is only showing T4 instead of T5 with my current setup. '
    .."This might be a recraft calculation issue, so there's no need to replace your materials.")
assert(A.Issues(recraft,true):find('T4 вместо T5',1,true))

local default='I checked your order. {reagent_issues}'
local function oldConfig(response,deleted,schema)
    Scan.DB.settings.quick_replies={schema_version=schema or 7,templates={
        REJECTED_ORDER={response=response,deleted=deleted,enabled=false,label='My resend',priority=7},
        CUSTOM_1={custom=true,label='Custom resend',response=response,keywords='test',enabled=true}}}
    return Q:GetConfig().templates
end
for _,old in ipairs({'{reagent_issues}','Resend. You missed {reagent_issues}',
    'Resend. You missed [reagent_issues]',
    'You need provide all mats and they all should be max tier (even missive and embelishment)'}) do
    local templates=oldConfig(old)
    assert(templates.REJECTED_ORDER.response==default)
    assert(templates.REJECTED_ORDER.enabled==false and templates.REJECTED_ORDER.label=='My resend'
        and templates.REJECTED_ORDER.priority==7 and templates.CUSTOM_1.response==old)
end
assert(oldConfig('My own paste: {reagent_issues}').REJECTED_ORDER.response=='My own paste: {reagent_issues}')
assert(oldConfig('{reagent_issues}',true).REJECTED_ORDER.response=='{reagent_issues}')
assert(oldConfig('{reagent_issues}',false,8).REJECTED_ORDER.response=='{reagent_issues}','migration repeated after upgrade')
Scan.DB.settings.quick_replies=nil
assert(Q:GetConfig().templates.REJECTED_ORDER.response==default)
assert(Q:BuildReply('REJECTED_ORDER',{audit=onlyQuality})==
    'I checked your order. Could you replace 40 T1 Alloy with T2, please?')

-- A long list must survive both tag expansion and the real UTF-8 chat splitter.
local many=snapshot()
for i=1,14 do many.rows[i]=row('Реагент '..i,i+2,1,1,2) end
local reply=assert(Q:BuildReply('REJECTED_ORDER',{audit=many}))
assert(#reply>255)
local messages=Scan.Utils.SplitResponse(reply)
assert(#messages>1 and table.concat(messages,' ')==reply,'message splitting lost a material or sentence')
for _,message in ipairs(messages) do assert(#message<=255 and utf8.len(message)) end
for i=1,14 do
    assert(reply:find((i+1)..' Реагент '..i..' (T2)',1,true))
    assert(reply:find('1 T1 Реагент '..i..' with T2',1,true))
end

-- In a reply that goes to chat an item is its link, wherever the game has one.
local function link(id,name,tier)
    return '|cnIQ1:|Hitem:'..id..'::::::::90:::::::::|h['..name
        ..(tier and (' |A:Professions-ChatIcon-Quality-12-Tier'..tier..':17:18::1|a') or '')..']|h|r'
end
local links={[5001]=link(5001,'Glimmering Gemdust',1),[5002]=link(5002,'Glimmering Gemdust',2),
    [5101]=link(5101,'Dusk-Shrouded Stone',1),[5102]=link(5102,'Dusk-Shrouded Stone',2),
    [5201]=link(5201,'Competitor\'s Heraldry'),[5301]=link(5301,'Sunfire Silk',1),[5302]=link(5302,'Sunfire Silk',2),
    [5401]='|cnIQ1:|Hitem:5401'..string.rep(':1234567',30)..'|h[Overlong]|h|r',[5501]='Just a name'}
local requested={}
C_Item={GetItemInfo=function(id) if links[id] then return 'name',links[id] end end,
    RequestLoadItemDataByID=function(id) requested[#requested+1]=id end}
local function item(name,itemID,bestItemID,required,quantity,tier,maxTier)
    return {name=name,itemID=itemID,bestItemID=bestItemID,required=required,known=true,maxQuality=maxTier,
        supplied=quantity and {{itemID=itemID,name=name,quantity=quantity,quality=tier,maxQuality=maxTier,
            qualityKnown=true}} or {}}
end
local gemdust=snapshot(item('Glimmering Gemdust',5001,5002,5,5,1,2))
assert(A.Issues(gemdust)=='Could you replace 5 T1 Glimmering Gemdust with T2, please?','links were used without being asked for')
assert(A.Issues(gemdust,nil,true)=='Could you replace 5 T1 '..links[5001]..' with T2, please?',
    'the item to replace is not its link')
-- A missing item is the one of the quality that is needed, not the lowest.
local short=snapshot(item('Glimmering Gemdust',5001,5002,5,2,1,2),item('Competitor\'s Heraldry',5201,nil,3))
assert(A.Issues(short,nil,true)=="Looks like you're missing 3 "..links[5002]..' (T2) and 3 '..links[5201]..'. '
    ..'Could you replace 2 T1 '..links[5001]..' with T2, please?','a missing item is not the link of the item needed')
-- A snapshot from before the needed item was recorded keeps the name: the
-- lowest quality's link would point at the wrong item.
assert(A.Issues(snapshot(item('Glimmering Gemdust',5001,nil,5,nil,nil,2)),nil,true)==
    "Looks like you're missing 5 Glimmering Gemdust (T2).",'an old snapshot linked the lowest quality')
-- No link yet, a link too long for a message, or something that is not a
-- link: the name, and the item's data is asked for once.
local unknown=snapshot(item('Unseen Ore',5999,nil,4,4,1,2))
assert(A.Issues(unknown,nil,true)=='Could you replace 4 T1 Unseen Ore with T2, please?')
assert(A.Issues(unknown,nil,true)=='Could you replace 4 T1 Unseen Ore with T2, please?')
assert(#requested==1 and requested[1]==5999,'the missing item data was not asked for exactly once')
assert(A.Issues(snapshot(item('Overlong',5401,nil,4,4,1,2)),nil,true)=='Could you replace 4 T1 Overlong with T2, please?',
    'a link too long for a message was used')
assert(A.Issues(snapshot(item('Plain',5501,nil,4,4,1,2)),nil,true)=='Could you replace 4 T1 Plain with T2, please?',
    'something that is not a link was sent as one')
assert(#requested==1,'data was asked for an item the game already has')
-- The link is made here, never taken from a snapshot.
local forged=A.Sanitize({version=1,orderID=1,capturedAt=1,complete=true,rows={
    {name='|cffff0000|Hitem:1|h[Forged]|h|r',itemID=5999,bestItemID=5002,required=2,known=true,maxQuality=2,supplied={}}}})
assert(forged.rows[1].bestItemID==5002 and not forged.rows[1].name:find('|',1,true),'a snapshot kept a link')

-- The real reply, in one whisper, and its short label without link markup.
Scan.BuildResponseContext=function(response) return {reagent_issues=A.Issues(response.audit,nil,true)} end
local linked=assert(Q:BuildReply('REJECTED_ORDER',{audit=gemdust}))
assert(linked=='I checked your order. Could you replace 5 T1 '..links[5001]..' with T2, please?')
assert(#linked<=255,'one linked item no longer fits one whisper')
assert(Q.DisplayText(linked)=='I checked your order. Could you replace 5 T1 [Glimmering Gemdust] with T2, please?',
    'the label of a linked reply shows link markup')
local source=assert(io.open('Customer/ChatScanner.lua','rb')):read('*a')
assert(source:find('ReagentAudit.ForResponse(response), nil, true)',1,true),'the chat reply does not ask for links')

-- Several linked items take several whispers: every link whole, every count
-- with its link, nothing lost.
local several=snapshot(item('Glimmering Gemdust',5001,5002,5,5,1,2),item('Dusk-Shrouded Stone',5101,5102,5,5,1,2),
    item('Sunfire Silk',5301,5302,12,12,1,2))
local long=assert(Q:BuildReply('REJECTED_ORDER',{audit=several}))
assert(#long>255)
local parts=Scan.Utils.SplitResponse(long)
assert(#parts==3 and table.concat(parts,' ')==long,'splitting a linked reply lost or reordered something')
for index,part in ipairs(parts) do
    assert(#part<=255,'a whisper is too long')
    local plain=part:gsub('|H[^|]+|h.-|h','')
    assert(not plain:find('|H',1,true) and not plain:find('|h',1,true),'a link was cut')
    assert(not part:find('%d$'),'a count was left behind without its link: '..part)
    if index>1 then assert(part:find('^%d+ T1 |cnIQ1:|Hitem:'),'a whisper does not start with its item: '..part) end
end
assert(parts[1]=='I checked your order. Could you replace 5 T1 '..links[5001]..' with T2,')
assert(parts[2]=='5 T1 '..links[5101]..' with T2 and')
assert(parts[3]=='12 T1 '..links[5301]..' with T2, please?')
-- A count is carried only for a link; plain text splits as before.
local plainSplit=Scan.Utils.SplitResponse(string.rep('word ',50)..'5 T1 '..string.rep('x',30))
assert(plainSplit[1]:find('5 T1$') and table.concat(plainSplit,' ')==string.rep('word ',50)..'5 T1 '..string.rep('x',30))

print('Natural reagent replies passed (multiple materials/ranks, optional mats, uncertainty, RU/EN, migration, complete long batches, item links).')
