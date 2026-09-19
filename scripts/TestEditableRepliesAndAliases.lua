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
print('Editable quick replies passed (built-in/custom CRUD, migration, reload, linked config, names, tombstones).')

assert(loadfile('Customer/ClassMatching.lua'))('HironCraft',Scan)
local M=Scan.ClassMatching
assert(#M.GetSynonymDefinitions()==17)
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
assert(loadfile('Customer/ClassMatching.lua'))('HironCraft',Scan);M=Scan.ClassMatching
Scan.DB.settings.match_customer_class=true
assert(contains(requests('need reinforced hand cover','WARRIOR'),'INVTYPE_WRIST'),'reload lost aliases')
print('Equipment aliases passed (17 starter types, phrases, live edits, collisions, disable/reset, reload, class opt-out).')
