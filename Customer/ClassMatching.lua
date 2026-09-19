local Scan = select(2, ...)
local M = {}
Scan.ClassMatching = M

-- Native armor type, not every weaker armor type the class can equip.
local armorByClass = {
    WARRIOR=4, PALADIN=4, DEATHKNIGHT=4,
    HUNTER=3, SHAMAN=3, EVOKER=3,
    ROGUE=2, DRUID=2, MONK=2, DEMONHUNTER=2,
    MAGE=1, PRIEST=1, WARLOCK=1,
}
local professionByArmor = { [1]=197, [2]=165, [3]=165, [4]=164 }
local craftingProfessions = {
    [164]=true,[165]=true,[171]=true,[197]=true,
    [202]=true,[333]=true,[755]=true,[773]=true,
}
local aliasDefinitions, aliasByKey = {}, {}
local function AddAliases(key, words, fixedProfession, alternativeProfessions)
    local definition=aliasByKey[key]
    if not definition then
        definition={key=key, defaults='', parentProfID=fixedProfession,
            parentProfIDs=alternativeProfessions}
        aliasDefinitions[#aliasDefinitions+1]=definition; aliasByKey[key]=definition
    end
    for word in words:gmatch('%S+') do
        definition.defaults=definition.defaults=='' and word or definition.defaults..', '..word
    end
end
local AddSlot=AddAliases
AddSlot('INVTYPE_WRIST', 'wrist wrists bracer bracers cuff cuffs наручи наруч наручей запястье запястья')
AddSlot('INVTYPE_HEAD', 'head helm helms helmet helmets hat hats шлем шлемы голова голову')
AddSlot('INVTYPE_NECK', 'neck necks necklace necklaces neckpiece neckpieces amulet amulets pendant pendants нек ожерелье ожерелья амулет амулеты подвеска подвески кулон кулоны шея шею', 755)
AddSlot('INVTYPE_SHOULDER', 'shoulder shoulders pauldron pauldrons плечи плечо наплечники наплечник')
AddSlot('INVTYPE_CHEST', 'chest chestpiece chestpieces нагрудник нагрудники грудь')
AddSlot('INVTYPE_HAND', 'hand hands glove gloves перчатки перчатку')
AddSlot('INVTYPE_WAIST', 'waist belt belts пояс пояса ремень')
AddSlot('INVTYPE_LEGS', 'leg legs leggings pants штаны поножи ноги')
AddSlot('INVTYPE_FEET', 'feet boot boots shoe shoes сапоги ботинки обувь')
AddSlot('INVTYPE_FINGER', 'ring rings finger ringfinger ринг ринги кольцо кольца колец перстень перстни перстня', 755)
AddSlot('INVTYPE_WRIST', 'wristguard wristguards armguard armguards wristwrap wristwraps bindings manacles')
AddSlot('INVTYPE_SHOULDER', 'shoulderpad shoulderpads spaulder spaulders mantle')
AddSlot('INVTYPE_CHEST', 'chestguard chestplate breastplate vest robe robes tunic')
AddSlot('INVTYPE_HAND', 'gauntlet gauntlets grips handguards')
AddSlot('INVTYPE_WAIST', 'waistguard waistguards girdle girdles sash')
AddSlot('INVTYPE_LEGS', 'legguard legguards legplates trousers')
AddSlot('INVTYPE_FEET', 'sabatons treads slippers greaves footwraps')
AddSlot('INVTYPE_CLOAK', 'back cloak cloaks cape capes drape drapes плащ плащи плаща накидка накидки спина спину', 197)
AddSlot('INVTYPE_SHIELD', 'shield shields buckler bucklers щит щиты щита щитов', 164)
AddSlot('INVTYPE_HOLDABLE', 'offhand off-hand tome tomes codex codices focus foci оффхенд офф-хенд фолиант фолианты кодекс кодексы сфера сферы', nil, craftingProfessions)
AddSlot('INVTYPE_TRINKET', 'trinket trinkets accessory accessories тринкет тринкеты брелок брелоки аксессуар аксессуары', nil,
    craftingProfessions)

-- Explicit professions/materials and non-armor requests must not be inferred
-- from the speaker's class (alts, transmogs, enchants and profession tools).
local explicitWords = {}
for word in ([=[bs blacksmith blacksmithing smith lw leatherworker leatherworking
tailor tailoring jc jewelcraft jewelcrafter jewelcrafting enchanter enchanting enchant
ench enchants engineer engineering engi inscription inscriber scribe alchemy alchemist
plate cloth leather mail кузнец кузнеца кузня кузнечка кузнечное портной портного портняга
портняжка портняжное кожевник кожевника кожевничество ювелир ювелира ювелирка
инженер инженера начертатель алхимик чантер чант чары зачарование зачарователь
латы латные латный ткань тканевые тканевый кожа кожаные кожаный кольчуга кольчужные
cloak cape back bag bags neck necklace ring rings trinket offhand shield weapon sword dagger axe
staff tool tools profession transmog mog alt alts плащ сумка сумки кольцо шея щит
брелок аксессуар оружие инструмент инструменты трансмог альт альта]=]):gmatch('%S+') do
    explicitWords[word] = true
end

local explicitArmor = {}
local function ArmorWords(armor, words)
    for word in words:gmatch('%S+') do explicitArmor[word]=armor; explicitWords[word]=nil end
end
ArmorWords(4, 'plate plates латы латные латный латная латное')
ArmorWords(3, 'mail chainmail кольчуга кольчужные кольчужный кольчужная')
ArmorWords(2, 'leather кожа кожаные кожаный кожаная')
ArmorWords(1, 'cloth ткань тканевые тканевый тканевая')
local explicitProfessions = {}
local function ProfessionWords(id, words)
    for word in words:gmatch('%S+') do explicitProfessions[word]=id end
end
ProfessionWords(164, 'bs blacksmith blacksmithing smith кузнец кузнеца кузня кузнечка кузнечное')
ProfessionWords(165, 'lw leatherworker leatherworking кожевник кожевника кожевничество')
ProfessionWords(197, 'tailor tailoring портной портного портняга портняжка портняжное')
ProfessionWords(755, 'jc jewelcraft jewelcrafter jewelcrafting ювелир ювелира ювелирка')
ProfessionWords(333, 'enchanter enchanting enchant ench enchants чантер чант чары зачарование зачарователь')
ProfessionWords(202, 'engineer engineering engi инженер инженера')
ProfessionWords(773, 'inscription inscriber scribe начертатель')
ProfessionWords(171, 'alchemy alchemist алхимик')
local classCache = {}
local slotLabels = {
    INVTYPE_WRIST='Wrist', INVTYPE_HEAD='Head', INVTYPE_NECK='Neck', INVTYPE_SHOULDER='Shoulders',
    INVTYPE_CHEST='Chest', INVTYPE_HAND='Gloves', INVTYPE_WAIST='Belt',
    INVTYPE_LEGS='Legs', INVTYPE_FEET='Boots', INVTYPE_FINGER='Ring',
    INVTYPE_CLOAK='Cloak', INVTYPE_SHIELD='Shield', INVTYPE_HOLDABLE='Off-hand',
    INVTYPE_TRINKET='Trinket',
}
local weapons = {}
local function Weapon(key, profession, subclasses, words, alternativeProfessions)
    weapons[key] = {key=key, label=key, parentProfID=profession, subclasses=subclasses,
        parentProfIDs=alternativeProfessions}
    AddAliases(key,words)
    for word in words:gmatch('%S+') do explicitWords[word]=nil end
end
Weapon('Axe', 164, {[0]=true,[1]=true}, 'axe axes топор топоры')
Weapon('Sword', 164, {[7]=true,[8]=true}, 'sword swords меч мечи')
Weapon('Gun', 202, {[3]=true}, 'gun guns rifle rifles ружье ружьё винтовка')
Weapon('Mace', 164, {[4]=true,[5]=true}, 'mace maces молот булава')
Weapon('Dagger', 164, {[15]=true}, 'dagger daggers кинжал кинжалы')
Weapon('Polearm', 164, {[6]=true}, 'polearm polearms spear spears копье копьё')
Weapon('Staff', 773, {[10]=true}, 'staff staves посох посохи')
Weapon('Warglaive', 164, {[9]=true}, 'warglaive warglaives glaive glaives глефа глефы')
Weapon('Bow', nil, {[2]=true}, 'bow bows лук луки', craftingProfessions)
Weapon('Crossbow', nil, {[18]=true}, 'crossbow crossbows арбалет арбалеты', craftingProfessions)
Weapon('Fist weapon', nil, {[13]=true}, 'fistweapon fistweapons fist-weapon fist-weapons knuckle knuckles кастет кастеты', craftingProfessions)
Weapon('Wand', nil, {[19]=true}, 'wand wands жезл жезлы', craftingProfessions)

local function NormalizeAliases(text)
    return (strlower or string.lower)(text):gsub('[%c%p]', ' '):gsub('%s+', ' ')
        :gsub('^%s+', ''):gsub('%s+$', '')
end
local function ParseAliases(text)
    local values,seen={},{}
    for entry in text:gmatch('[^,;\r\n]+') do
        local value=NormalizeAliases(entry)
        if value~='' and not seen[value] then values[#values+1]=value; seen[value]=true end
    end
    return values
end
function M.GetSynonymDefinitions()
    local result={}
    for _,definition in ipairs(aliasDefinitions) do
        result[#result+1]={key=definition.key,label=slotLabels[definition.key] or definition.key}
    end
    return result
end
function M.GetSynonyms(key)
    local definition=aliasByKey[key]
    if not definition then return '' end
    local settings=Scan.DB.settings.equipment_synonyms
    local saved=settings and settings[key]
    return type(saved)=='string' and saved or definition.defaults
end
function M.ValidateSynonyms(key,value)
    if not aliasByKey[key] or type(value)~='string' or #value>2000 or value:find('[|{}]') then
        return false,'Equipment aliases invalid'
    end
    local values=ParseAliases(value)
    if #values>96 or (#values==0 and value:find('%S')) then return false,'Equipment aliases invalid' end
    local used={}
    for _,definition in ipairs(aliasDefinitions) do
        if definition.key~=key then
            for _,alias in ipairs(ParseAliases(M.GetSynonyms(definition.key))) do used[alias]=definition.key end
        end
    end
    for _,alias in ipairs(values) do
        if #alias<2 or #alias>80 then return false,'Equipment aliases invalid' end
        if used[alias] then return false,'Equipment alias already assigned',alias,slotLabels[used[alias]] or used[alias] end
    end
    return true,nil,table.concat(values,', ')
end
function M.SetSynonyms(key,value)
    local valid,reason,normalized,other=M.ValidateSynonyms(key,value)
    if not valid then return false,reason,normalized,other end
    Scan.DB.settings.equipment_synonyms=Scan.DB.settings.equipment_synonyms or {}
    Scan.DB.settings.equipment_synonyms[key]=normalized
    return true
end
function M.ResetSynonyms(key)
    if not aliasByKey[key] then return false end
    -- Check collisions before restoring defaults that the user moved elsewhere.
    return M.SetSynonyms(key,aliasByKey[key].defaults)
end

local aliasCache,aliasSignature={},nil
local weaponHandPhrases={
    'one handed','two handed','single handed','double handed','one hand','two hands','two hand',
    '1 handed','2 handed','1 hand','2 hands','2 hand','main hand','off hand',
    'onehanded','twohanded','onehand','twohand','1handed','2handed','1hand','2hand','1h','2h',
}
local function MatchAliases(message)
    local signature={}
    for _,definition in ipairs(aliasDefinitions) do signature[#signature+1]=M.GetSynonyms(definition.key) end
    signature=table.concat(signature,'\31')
    if signature~=aliasSignature then
        local owners={}
        aliasCache={};aliasSignature=signature
        for _,definition in ipairs(aliasDefinitions) do
            for _,alias in ipairs(ParseAliases(M.GetSynonyms(definition.key))) do
                if owners[alias] and owners[alias]~=definition.key then owners[alias]=false
                elseif owners[alias]==nil then owners[alias]=definition.key end
            end
        end
        for alias,key in pairs(owners) do if key then aliasCache[#aliasCache+1]={text=alias,key=key} end end
        table.sort(aliasCache,function(a,b)
            if #a.text==#b.text then return a.text<b.text end
            return #a.text>#b.text
        end)
    end
    local remaining=' '..NormalizeAliases(message)..' '
    local weaponRanges={}
    for _,alias in ipairs(aliasCache) do
        if weapons[alias.key] or alias.key=='INVTYPE_SHIELD' then
            local pattern=' '..alias.text..' '
            local first,last=remaining:find(pattern,1,true)
            while first do
                weaponRanges[#weaponRanges+1]={first+1,last-1}
                first,last=remaining:find(pattern,last,true)
            end
        end
    end
    if #weaponRanges>0 then
        for _,phrase in ipairs(weaponHandPhrases) do
            local pattern=' '..phrase..' '
            local first,last=remaining:find(pattern,1,true)
            while first do
                local insideAlias=false
                local phraseStart,phraseEnd=first+1,last-1
                local besideWeapon=false
                for _,range in ipairs(weaponRanges) do
                    if phraseStart<=range[2] and phraseEnd>=range[1] then insideAlias=true end
                    if math.abs(range[1]-phraseEnd)<=2 or math.abs(phraseStart-range[2])<=2 then
                        besideWeapon=true
                    end
                end
                -- Mask only the weapon modifier, not other mentions of hands:
                -- "one hand sword and gloves" still requests two items. Keep
                -- custom aliases such as "one hand blade" intact as well. A
                -- separated "sword and off hand" is its own equipment request.
                if besideWeapon and not insideAlias then
                    remaining=remaining:sub(1,first)..string.rep(' ',last-first-1)..remaining:sub(last)
                end
                first,last=remaining:find(pattern,last,true)
            end
        end
    end
    local matches={}
    for _,alias in ipairs(aliasCache) do
        local pattern=' '..alias.text..' '
        local start,finish=remaining:find(pattern,1,true)
        while start do
            matches[alias.key]=true
            -- Longest phrases win, without interpreting user text as Lua patterns.
            remaining=remaining:sub(1,start)..string.rep(' ',finish-start-1)..remaining:sub(finish)
            start,finish=remaining:find(pattern,1,true)
        end
    end
    return matches,remaining
end

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

function M.ResolveClass(guid, sharedClass)
    if not IsSecret(guid) and type(guid) == 'string' and guid ~= ''
        and type(GetPlayerInfoByGUID) == 'function' then
        local ok, _, class = pcall(GetPlayerInfoByGUID, guid)
        if ok and not IsSecret(class) and type(class) == 'string' and armorByClass[class] then
            classCache[guid] = class
            return class
        end
    end
    if not IsSecret(sharedClass) and type(sharedClass) == 'string' and armorByClass[sharedClass] then
        return sharedClass
    end
    if not IsSecret(guid) and type(guid) == 'string' then return classCache[guid] end
end

function M.GetContext(message, guid, sharedClass)
    if IsSecret(message) or type(message) ~= 'string' then return nil end
    message = (strlower or string.lower)(message)
    -- Links are authoritative, including an unmonitored item/recipe link.
    if message:find('|hitem:', 1, true) or message:find('|henchant:', 1, true)
        or message:find('|hrecipe:', 1, true) then return nil end
    local matched,remaining=MatchAliases(message)
    local slots, armor, profession, bypass, requestedWeapons = {}, nil, nil, false, {}
    local needsArmor,fixedProfession=false,nil
    for key in pairs(matched) do
        if weapons[key] then requestedWeapons[key]=true
        else
            slots[key]=true
            if aliasByKey[key].parentProfID then fixedProfession=aliasByKey[key].parentProfID
            elseif aliasByKey[key].parentProfIDs then
                -- The concrete monitored recipe selects among these professions.
            else needsArmor=true end
        end
    end
    for word in message:gmatch('[^%s%p]+') do
        if explicitArmor[word] then armor = explicitArmor[word] end
        if explicitProfessions[word] then profession = explicitProfessions[word] end
    end
    for word in remaining:gmatch('%S+') do if explicitWords[word] then bypass=true end end
    if profession then
        return {parentProfID=profession, explicitProfession=true, slots=slots,
            weapons=next(requestedWeapons) and requestedWeapons or nil}
    end
    if bypass then return nil end
    -- Explicit material/slot requests and fixed-profession items do not need
    -- class inference. Opting out of class guessing must not erase "cloth wrist".
    if needsArmor and not armor and Scan.DB.settings.match_customer_class==false then return nil end
    if next(requestedWeapons) then
        -- Mixed professions are split into independent request contexts below.
        local keys = {}; for key in pairs(requestedWeapons) do keys[#keys+1]=key end
        table.sort(keys)
        local class = M.ResolveClass(guid, sharedClass)
        if needsArmor and not armor and not class then return {unknownClass=true,slots=slots} end
        armor = armor or (class and armorByClass[class])
        return {parentProfID=weapons[keys[1]].parentProfID, slots=slots, weapons=requestedWeapons,
            class=class, armor=armor, armorParentProfID=armor and professionByArmor[armor]}
    end
    if armor then return {armor=armor, parentProfID=professionByArmor[armor], slots=slots} end
    if not next(slots) then return nil end
    if not needsArmor then return {parentProfID=fixedProfession,slots=slots} end
    local class = M.ResolveClass(guid, sharedClass)
    if not class then return {unknownClass=true, slots=slots} end
    armor = armorByClass[class]
    return { class=class, armor=armor, parentProfID=professionByArmor[armor], slots=slots }
end

function M.GetRequests(context)
    local requests = {}
    if not context or context.unknownClass then return requests end
    if context.weapons then
        for key in pairs(context.weapons) do
            local weapon=weapons[key]
            -- An explicit incompatible profession is not permission to route
            -- the request to another one (e.g. weapon enchants).
            if weapon.parentProfIDs then
                for profession in pairs(weapon.parentProfIDs) do
                    if not context.explicitProfession or profession==context.parentProfID then
                        requests[#requests+1]={key=weapon.key,label=weapon.label,
                            subclasses=weapon.subclasses,parentProfID=profession,dynamicProfession=true}
                    end
                end
            elseif not context.explicitProfession or weapon.parentProfID == context.parentProfID then
                requests[#requests+1]=weapon
            end
        end
    end
    local armorProfession = context.armorParentProfID or context.parentProfID
    for slot in pairs(context.slots or {}) do
        local definition=aliasByKey[slot]
        local fixedProfession=definition and definition.parentProfID
        if definition and definition.parentProfIDs then
            for profession in pairs(definition.parentProfIDs) do
                if not context.explicitProfession or profession==context.parentProfID then
                    requests[#requests+1] = {key=slot,label=slotLabels[slot],slot=slot,
                        parentProfID=profession,dynamicProfession=true}
                end
            end
        else
            local profession=fixedProfession or armorProfession
            local armorProfessionValid=profession==164 or profession==165 or profession==197
            if profession and (fixedProfession or armorProfessionValid)
                and (not context.explicitProfession or not fixedProfession or fixedProfession==context.parentProfID) then
                requests[#requests+1] = {key=slot, label=slotLabels[slot], slot=slot,
                    armor=not fixedProfession and context.armor or nil, parentProfID=profession}
            end
        end
    end
    table.sort(requests, function(a,b)
        if a.key==b.key then return (a.parentProfID or 0)<(b.parentProfID or 0) end
        return a.key < b.key
    end)
    return requests
end

function M.RequestSupportsProfession(request,parentProfID)
    return type(request)=='table' and request.parentProfID==parentProfID
end

function M.MatchesItem(request, itemID)
    local getInfo = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if not request or not itemID or type(getInfo) ~= 'function' then return false end
    local ok, _, _, _, slot, _, itemClass, subClass = pcall(getInfo, itemID)
    if not ok or IsSecret(slot) or IsSecret(itemClass) or IsSecret(subClass) then return false end
    if request.subclasses then return itemClass == 2 and request.subclasses[subClass] == true end
    if slot == 'INVTYPE_ROBE' then slot = 'INVTYPE_CHEST' end
    return itemClass == 4 and slot == request.slot and (not request.armor or subClass == request.armor)
end

function M.MatchesRecipe(context, recipeInfo)
    if not context then return true end
    if context.unknownClass then return false end
    if context.explicitProfession and not context.armor then
        for slot in pairs(context.slots) do
            local definition=aliasByKey[slot]
            if not definition or (definition.parentProfID~=context.parentProfID
                and not (definition.parentProfIDs and definition.parentProfIDs[context.parentProfID])) then
                return false
            end
        end
    end
    if context.explicitProfession and not next(context.slots) and not context.weapons then return true end
    if type(recipeInfo) ~= 'table' then return false end
    local getInfo = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if type(getInfo) ~= 'function' then return false end
    local loaded, outputs = pcall(Scan.Utils.GetOutputItems, recipeInfo)
    if not loaded or type(outputs) ~= 'table' then return false end
    for _, itemID in ipairs(outputs) do
        for _, request in ipairs(M.GetRequests(context)) do
            if M.MatchesItem(request, itemID) then return true end
        end
        local ok, _, _, _, slot, _, itemClass, armor = pcall(getInfo, itemID)
        if ok and not IsSecret(slot) and not IsSecret(itemClass) and not IsSecret(armor) then
            if slot == 'INVTYPE_ROBE' then slot = 'INVTYPE_CHEST' end
            if itemClass == 4 and armor == context.armor and context.slots[slot] then
                return true
            end
        end
    end
    -- Unknown metadata is not evidence that a crafter can make this exact item.
    -- The scanner can still offer the matching profession-level response.
    return false
end
