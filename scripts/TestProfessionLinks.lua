local function noop() end
local current,guid='Mavu-Realm','Player-1-ABC'
local learned={773,164}
local links={}
local function trade(owner,skill)
    return '|cffffd000|Htrade:'..owner..':45357:'..skill..'|h[Profession '..skill..']|h|r'
end
links[773],links[164]=trade(guid,773),trade(guid,164)
local timers,events,frames,shared={},{},{},{}
local Scan={DB={settings={my_uuid='pc'},characters={}},Utils={},Events={}}
Scan.GetPlayerName=function() return current end
Scan.Utils.onLoad=function(fn) fn() end
function Scan.Events:Register(names,fn)
    if type(names)=='string' then names={names} end
    for _,name in ipairs(names) do events[name]=fn end
end
function CreateFrame()
    local f={RegisterEvent=noop,SetScript=function(self,_,fn) self.callback=fn end}
    frames[#frames+1]=f;return f
end
C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
function UnitGUID() return guid end
function GetProfessions() return table.unpack(learned) end
function GetProfessionInfo(index) return 'Profession',nil,nil,nil,nil,nil,index end
Enum={SpellBookSpellBank={Player=0}}
local apiCalls=0
C_SpellBook={
    GetSkillLineIndexByID=function(id) apiCalls=apiCalls+1;return id end,
    GetSpellBookSkillLineInfo=function(id) return {itemIndexOffset=id-1} end,
    GetSpellBookItemType=function(index) return 'SPELL',index end,
}
C_Spell={GetSpellTradeSkillLink=function(id) return links[id] end}
HironCraftScanComm={ShareCharacterModification=function(_,name,id,parentOnly)
    assert(parentOnly,'link update included a recipe catalog')
    local parent=Scan.DB.characters[name].parent_professions[id]
    parent.rev=(parent.rev or 0)+1
    shared[#shared+1]={name=name,id=id,link=parent.profession_link}
end}
local function load() assert(loadfile('Utils/ProfessionLinks.lua'))('HironCraft',Scan);return Scan.ProfessionLinks end
local function flush()
    local pending=timers;timers={};for _,fn in ipairs(pending) do fn() end
end
local function profile(owner)
    return {sourceID=owner,parent_professions={[773]={},[164]={}},
        professions={[2828]={parentProfID=773},[2822]={parentProfID=164}}}
end
local P=load()
flush();assert(#shared==0,'login invented an unconfigured character')
Scan.DB.characters[current]=profile('pc')
events.PROFESSION_SCAN_COMPLETE();flush()
local mavu=Scan.DB.characters[current]
assert(#shared==2 and mavu.parent_professions[773].profession_link.link==links[773])
assert(P.Get(current,2828)==links[773] and P.Get(current,164)==links[164])
local rev=P.Revision(current,2828)
for _=1,10 do frames[1].callback() end
assert(#timers==1,'profession events were not coalesced')
flush();assert(#shared==2 and P.Revision(current,2828)==rev,'unchanged links generated sync traffic')
local saved=links[773]
links[773]=nil;P.Capture()
assert(#shared==2 and P.Get(current,2828)==saved,'temporary API miss erased cached link')
links[773]=trade('Player-2-FFF',773);P.Capture()
assert(#shared==2 and P.Get(current,2828)==saved,'foreign linked window poisoned the cache')
links[773]=saved
local oldGUID=guid;guid='Player-2-FFF'
assert(not P.Get(current,2828),'cache from a different character GUID was reused')
guid=oldGUID

-- A collector never consults its own spellbook for another crafter's link.
current,guid='LaptopMin-Realm','Player-3-EEE'
local before=apiCalls
assert(P.Get('Mavu-Realm',2828)==saved and apiCalls==before)
P=load();assert(P.Get('Mavu-Realm',773)==saved,'reload lost the durable link')
Scan.DB.characters['Mavu-OtherRealm']=profile('pc')
Scan.DB.characters['Mavu-OtherRealm'].parent_professions[773].profession_link=
    mavu.parent_professions[773].profession_link
assert(not P.Get('Mavu-OtherRealm',773),'same-name characters on different realms shared a cache')
assert(not P.Get('Unknown-Realm',773) and apiCalls==before,'missing crafter used the collector link')
local parent=mavu.parent_professions[773]
parent.character_disabled=true;assert(not P.Get('Mavu-Realm',773));parent.character_disabled=nil
local cache=parent.profession_link
parent.profession_link={crafter='Mavu-Realm',guid=cache.guid,link=trade(cache.guid,164)}
assert(not P.Get('Mavu-Realm',2828),'wrong profession link was accepted')
parent.profession_link=cache

local secret={};issecretvalue=function(v) return v==secret end
for _,bad in ipairs({'hello',saved..' extra',saved..'\n',saved..saved,
    '|Hitem:1|h[item]|h',string.rep('x',256),secret}) do
    assert(not P.Valid(bad,cache.guid,773),'invalid trade link was accepted')
end
assert(not P.Valid(saved,secret,773))
issecretvalue=nil

-- Changed links are refreshed; snapshots from an unready API are retained.
current,guid='Mavu-Realm',oldGUID
links[773]=saved:gsub('Profession 773','Updated profession')
P.Capture();assert(#shared==3 and parent.profession_link.link==links[773])
learned={};P.Capture();assert(parent.profession_link,'empty loading snapshot erased links')
learned={773,164}
local savedInfo=GetProfessionInfo
GetProfessionInfo=function(index) if index~=773 then return savedInfo(index) end end
P.Capture();assert(parent.profession_link,'partially loaded profession info erased a good link')
GetProfessionInfo=savedInfo
learned={164};P.Capture();assert(not parent.profession_link and #shared==4,'forgotten profession was not cleared')
learned={773,164};mavu.sourceID='other-account'
P.Capture();assert(not parent.profession_link,'capture modified another account\'s profile')
mavu.sourceID='pc';P.Capture();assert(parent.profession_link and #shared==5)
print('Profession links passed (capture, owner/skill/realm isolation, persistence, transient API failures, changes, coalescing, validation).')
