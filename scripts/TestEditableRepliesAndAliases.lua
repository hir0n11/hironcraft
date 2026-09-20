local Scan={DB={settings={quick_replies={templates={PRICE={enabled=false,keywords='fee',response='my price',priority=9}}}}},
    Utils={},Events={Emit=function() end,Register=function() end},
    LOCAL={GetText=function(_,key) return key:match('quick_reply%.(.-)%.enabled') or key end},Config={}}
Scan.Utils.saved=function(parent,key,value) if parent[key]==nil then parent[key]=value end;return parent[key] end
Scan.Utils.onLoad=function(fn) fn() end
Scan.Config.SubstituteTags=function(text) return text end
Scan.BuildResponseContext=function() return {crafter='Crafter'} end
assert(loadfile('Utils/FStrings.lua'))('HironCraft',Scan)
assert(loadfile('Customer/QuickReplies.lua'))('HironCraft',Scan)
local Q=Scan.QuickReplies
local templates=Q:GetConfig().templates
assert(not templates.PRICE.enabled and templates.PRICE.keywords=='fee' and templates.PRICE.priority==9)
assert(Q:RenameTemplate('PRICE','Commission'))
assert(templates.PRICE.label=='Commission' and templates.PRICE.response=='my price' and templates.PRICE.keywords=='fee')
assert(Q:GetTemplateLabel('PRICE')=='Commission' and Q:IsLabelAvailable('Commission','PRICE'))
assert(not Q:RenameTemplate('NAME','commission') and not Q:RenameTemplate('PRICE','  '))
assert(not Q:RenameTemplate('PRICE','|cffff0000bad') and not Q:RenameTemplate('PRICE',string.rep('a',129)))
assert(Q:DeleteTemplate('PRICE') and Q:GetConfig().templates.PRICE.deleted)
assert(not Q:BuildReply('PRICE',{}) and not Q:AddKeyword('PRICE','gold'))
local function hasKey(key) for _,d in ipairs(Q:GetDefinitions()) do if d.key==key then return true end end end
assert(not hasKey('PRICE') and Q:IsLabelAvailable('Commission'))
-- Reload uses the same SavedVariables table, without recreating defaults.
assert(loadfile('Customer/QuickReplies.lua'))('HironCraft',Scan);Q=Scan.QuickReplies
assert(Q:GetConfig().templates.PRICE.deleted and not Q:BuildReply('PRICE',{}))
local custom=assert(Q:CreateCustomTemplate('Commission','cost','new answer'))
assert(Q:RenameTemplate(custom,'Custom renamed') and Q:GetTemplateLabel(custom)=='Custom renamed')
assert(Q:DeleteTemplate(custom) and Q:GetConfig().templates[custom].deleted)
local remote={rev=Q:GetConfig().rev+100,templates={NAME={label='Who makes it',enabled=true,keywords='who',response='{crafter}'},
    PRICE={deleted=true,enabled=false,keywords='',response=''}}}
assert(Q:ApplyRemoteConfig(remote) and Q:GetTemplateLabel('NAME')=='Who makes it')
assert(Q:GetConfig().templates.PRICE.deleted and not Q:BuildReply('PRICE',{}))
assert(Q:DeleteTemplate('REJECTED_ORDER') and not Q:BuildReply('REJECTED_ORDER',{}))
assert(not Q:DeleteTemplate('REJECTED_ORDER') and not Q:RenameTemplate('REJECTED_ORDER','Declined'))
-- 0.3.85 rewrote three built-in answers and 0.3.86 put them back. An answer
-- the crafter wrote themselves is theirs and survives both.
local upgrade={quick_replies={schema_version=10,templates={
    NAME={enabled=true,keywords='who',response='{crafter} will craft it.'},
    PRICE={enabled=true,keywords='price',response='pay me {commission} pls'},
}}}
local previousDB=Scan.DB.settings
Scan.DB.settings=upgrade
assert(loadfile('Customer/QuickReplies.lua'))('HironCraft',Scan)
local upgraded=Scan.QuickReplies:GetConfig().templates
assert(upgraded.NAME.response=='{crafter}','the rewritten answer was not restored')
assert(upgraded.PRICE.response=='pay me {commission} pls','an edited answer was overwritten')
assert(Scan.QuickReplies:GetConfig().schema_version==11)
Scan.DB.settings=previousDB
assert(loadfile('Customer/QuickReplies.lua'))('HironCraft',Scan);Q=Scan.QuickReplies

print('Editable quick replies passed (built-in/custom CRUD, migration, reload, linked config, names, tombstones).')

assert(loadfile('Customer/ClassMatching.lua'))('HironCraft',Scan)
local M=Scan.ClassMatching
assert(#M.GetSynonymDefinitions()==26)
local function requests(text,class)
    return M.GetRequests(M.GetContext(text,nil,class))
end
local function contains(list,key) for _,r in ipairs(list) do if r.key==key then return r end end end
for _,word in ipairs({'hand','hands','glove','gloves','gauntlets','перчатки'}) do
    assert(contains(requests('need '..word,'WARRIOR'),'INVTYPE_HAND'),word)
end
for _,word in ipairs({'back','cloak','capes','плащ'}) do
    local r=contains(requests('need '..word),'INVTYPE_CLOAK')
    assert(r and r.parentProfID==197 and not r.armor,'cloak required a customer class')
end
for _,word in ipairs({'shield','shields','buckler','щит','щита'}) do
    local r=contains(requests('need '..word),'INVTYPE_SHIELD')
    assert(r and r.parentProfID==164 and not r.armor,'shield required armor class: '..word)
end
for _,case in ipairs({
    {'need ring','INVTYPE_FINGER',755}, {'need necklace','INVTYPE_NECK',755},
    {'нужен ринг','INVTYPE_FINGER',755}, {'нужен нек','INVTYPE_NECK',755},
    {'нужен амулет','INVTYPE_NECK',755}, {'нужно кольцо','INVTYPE_FINGER',755},
}) do
    local r=contains(requests(case[1]),case[2])
    assert(r and r.parentProfID==case[3] and not r.armor,'fixed equipment routed incorrectly: '..case[1])
end
local trinkets=requests('need trinket')
assert(#trinkets==8 and contains(trinkets,'INVTYPE_TRINKET'),
    'trinket did not expose its candidate crafting professions')
for _,request in ipairs(trinkets) do assert(request.dynamicProfession) end
local scribeTrinket=requests('need inscription trinket')
assert(#scribeTrinket==1 and scribeTrinket[1].parentProfID==773)
local offhands=requests('need offhand')
assert(#offhands==8 and contains(offhands,'INVTYPE_HOLDABLE'))
local scribeOffhand=requests('need inscription offhand')
assert(#scribeOffhand==1 and scribeOffhand[1].parentProfID==773)
for _,case in ipairs({{'bow','Bow'},{'crossbow','Crossbow'},{'fist weapon','Fist weapon'},{'wand','Wand'}}) do
    local list=requests('need '..case[1])
    assert(#list==8 and contains(list,case[2]),'dynamic weapon missing: '..case[1])
    for _,request in ipairs(list) do assert(request.dynamicProfession and request.subclasses) end
end
for _,phrase in ipairs({'one hand','one handed','one-handed','1 hand','1h','two hand','two hands','2h',
    'two-handed','off hand','main hand'}) do
    local list=requests('sword '..phrase..' crafter','WARRIOR')
    assert(#list==1 and list[1].key=='Sword','weapon modifier made gloves: '..phrase)
    assert(#requests('need '..phrase..' sword and hands','WARRIOR')==2,'real gloves were removed: '..phrase)
end
assert(#requests('need hands and sword','WARRIOR')==2)
local weaponAndOffhand=requests('need sword and off-hand','WARRIOR')
assert(#weaponAndOffhand==9 and contains(weaponAndOffhand,'Sword')
    and contains(weaponAndOffhand,'INVTYPE_HOLDABLE'),'separate off-hand request was masked as a sword modifier')
assert(#requests('need sword off-hand crafter','WARRIOR')==1,'adjacent weapon modifier became an off-hand request')
assert(#requests('need one hand','WARRIOR')==1,'weapon-only rule changed non-weapon matching')
local swordAliases=M.GetSynonyms('Sword')
assert(M.SetSynonyms('Sword','one hand blade'))
local customWeapon=requests('need one hand blade and hands','WARRIOR')
assert(#customWeapon==2 and contains(customWeapon,'Sword') and contains(customWeapon,'INVTYPE_HAND'),
    'weapon modifier destroyed a configured multi-word weapon alias')
assert(M.SetSynonyms('Sword',swordAliases))
local original=M.GetSynonyms('INVTYPE_HAND')
assert(M.SetSynonyms('INVTYPE_HAND',original..', mitts, fancy hand protectors, MITTS'))
assert(M.GetSynonyms('INVTYPE_HAND'):sub(-5)=='mitts' or M.GetSynonyms('INVTYPE_HAND'):find('mitts',1,true))
assert(contains(requests('Need FANCY HAND PROTECTORS, please','MAGE'),'INVTYPE_HAND'))
assert(not M.SetSynonyms('INVTYPE_WRIST','gloves'),'ambiguous synonym accepted')
assert(not M.SetSynonyms('INVTYPE_HAND','{gloves}') and not M.SetSynonyms('INVTYPE_HAND','.*'))
assert(not M.SetSynonyms('INVTYPE_HAND','a') and not M.SetSynonyms('INVTYPE_HAND',string.rep('x',2001)))
assert(M.SetSynonyms('INVTYPE_HAND',''))
assert(not contains(requests('need gloves and belt','WARRIOR'),'INVTYPE_HAND'),'cleared aliases restored themselves')
assert(contains(requests('need gloves and belt','WARRIOR'),'INVTYPE_WAIST'))
assert(M.SetSynonyms('INVTYPE_WRIST','gloves'))
assert(not M.ResetSynonyms('INVTYPE_HAND'),'reset stole an alias from another type')
assert(M.ResetSynonyms('INVTYPE_WRIST') and M.ResetSynonyms('INVTYPE_HAND'))
assert(not M.GetContext('need wristwatch',nil,'WARRIOR'))
assert(not M.GetContext('need wrist |Hitem:1|h[Gloves]|h',nil,'WARRIOR'))
local r=requests('Hey, i need also belt, hands and back can you craft?','HUNTER')
assert(#r==3 and contains(r,'INVTYPE_WAIST').parentProfID==165 and contains(r,'INVTYPE_CLOAK').parentProfID==197)
assert(M.SetSynonyms('INVTYPE_HAND',original..', hand cover'))
assert(M.SetSynonyms('INVTYPE_WRIST',M.GetSynonyms('INVTYPE_WRIST')..', reinforced hand cover'))
assert(#requests('need reinforced hand cover','WARRIOR')==1
    and contains(requests('need reinforced hand cover','WARRIOR'),'INVTYPE_WRIST'),'longest phrase did not win')
Scan.DB.settings.match_customer_class=false
assert(not M.GetContext('need wrist',nil,'WARRIOR'))
assert(contains(requests('looking for wrist cloth crafter please'),'INVTYPE_WRIST').parentProfID==197)
assert(contains(requests('need back'),'INVTYPE_CLOAK'))
assert(contains(requests('need gun'),'Gun').parentProfID==202)
assert(contains(requests('need shield'),'INVTYPE_SHIELD').parentProfID==164)
assert(loadfile('Customer/ClassMatching.lua'))('HironCraft',Scan);M=Scan.ClassMatching
Scan.DB.settings.match_customer_class=true
assert(contains(requests('need reinforced hand cover','WARRIOR'),'INVTYPE_WRIST'),'reload lost aliases')
-- Typos: the same switch that forgives misspelled quick-reply keywords also
-- forgives them in equipment aliases, and only where the guess is safe.
assert(contains(requests('need writs','WARRIOR'),'INVTYPE_WRIST'),'swapped letters lost the request')
assert(contains(requests('need bracerss','WARRIOR'),'INVTYPE_WRIST'),'a doubled letter lost the request')
assert(contains(requests('need glove s','WARRIOR'),'INVTYPE_HAND'))
-- A word that means something on its own is never read as a misspelling.
assert(contains(requests('need waist','WARRIOR'),'INVTYPE_WAIST'),'an exact alias changed meaning')
assert(not contains(requests('need waist','WARRIOR'),'INVTYPE_WRIST'),'an exact alias was read as a typo')
assert(not M.GetContext('need wristwatch',nil,'WARRIOR'),'a longer word became a typo')
assert(not contains(requests('need ring','WARRIOR'),'INVTYPE_WRIST'),'a short word was guessed at')
-- The switch turns it off again.
Scan.DB.settings.quick_replies.typo_tolerance=false
assert(not contains(requests('need writs','WARRIOR'),'INVTYPE_WRIST'),'the switch did not turn typos off')
assert(contains(requests('need wrist','WARRIOR'),'INVTYPE_WRIST'),'the switch broke exact matching')
Scan.DB.settings.quick_replies.typo_tolerance=nil

print('Equipment aliases passed (26 starter types, jewelry/off-hand/trinkets, complete craftable weapons, edits, reload, class opt-out, typos).')
