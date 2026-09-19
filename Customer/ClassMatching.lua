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
local slotWords = {}
local function AddSlot(slot, words)
    for word in words:gmatch('%S+') do slotWords[word] = slot end
end
AddSlot('INVTYPE_WRIST', 'wrist wrists bracer bracers cuff cuffs наручи наруч наручей запястье запястья')
AddSlot('INVTYPE_HEAD', 'head helm helms helmet helmets hat hats шлем шлемы голова голову')
AddSlot('INVTYPE_SHOULDER', 'shoulder shoulders pauldron pauldrons плечи плечо наплечники наплечник')
AddSlot('INVTYPE_CHEST', 'chest chestpiece chestpieces нагрудник нагрудники грудь')
AddSlot('INVTYPE_HAND', 'hand hands glove gloves перчатки перчатку')
AddSlot('INVTYPE_WAIST', 'waist belt belts пояс пояса ремень')
AddSlot('INVTYPE_LEGS', 'leg legs leggings pants штаны поножи ноги')
AddSlot('INVTYPE_FEET', 'feet boot boots shoe shoes сапоги ботинки обувь')
AddSlot('INVTYPE_WRIST', 'wristguard wristguards armguard armguards wristwrap wristwraps bindings manacles')
AddSlot('INVTYPE_SHOULDER', 'shoulderpad shoulderpads spaulder spaulders mantle')
AddSlot('INVTYPE_CHEST', 'chestguard chestplate breastplate vest robe robes tunic')
AddSlot('INVTYPE_HAND', 'gauntlet gauntlets grips handguards')
AddSlot('INVTYPE_WAIST', 'waistguard waistguards girdle girdles sash')
AddSlot('INVTYPE_LEGS', 'legguard legguards legplates trousers')
AddSlot('INVTYPE_FEET', 'sabatons treads slippers greaves footwraps')

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
cloak cape back bag bags neck necklace ring rings shield weapon sword dagger axe
staff tool tools profession transmog mog alt alts плащ сумка сумки кольцо шея щит
оружие инструмент инструменты трансмог альт альта]=]):gmatch('%S+') do
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
    INVTYPE_WRIST='Wrist', INVTYPE_HEAD='Head', INVTYPE_SHOULDER='Shoulders',
    INVTYPE_CHEST='Chest', INVTYPE_HAND='Gloves', INVTYPE_WAIST='Belt',
    INVTYPE_LEGS='Legs', INVTYPE_FEET='Boots',
}
local weaponWords, weapons = {}, {}
local function Weapon(key, profession, subclasses, words)
    weapons[key] = {key=key, label=key, parentProfID=profession, subclasses=subclasses}
    for word in words:gmatch('%S+') do weaponWords[word]=key; explicitWords[word]=nil end
end
Weapon('Axe', 164, {[0]=true,[1]=true}, 'axe axes топор топоры')
Weapon('Sword', 164, {[7]=true,[8]=true}, 'sword swords меч мечи')
Weapon('Gun', 202, {[3]=true}, 'gun guns rifle rifles ружье ружьё винтовка')
Weapon('Mace', 164, {[4]=true,[5]=true}, 'mace maces молот булава')
Weapon('Dagger', 164, {[15]=true}, 'dagger daggers кинжал кинжалы')
Weapon('Polearm', 164, {[6]=true}, 'polearm polearms spear spears копье копьё')
Weapon('Staff', 773, {[10]=true}, 'staff staves посох посохи')
Weapon('Warglaive', 164, {[9]=true}, 'warglaive warglaives glaive glaives глефа глефы')

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
    if Scan.DB.settings.match_customer_class == false or IsSecret(message)
        or type(message) ~= 'string' then return nil end
    message = (strlower or string.lower)(message)
    -- Links are authoritative, including an unmonitored item/recipe link.
    if message:find('|hitem:', 1, true) or message:find('|henchant:', 1, true)
        or message:find('|hrecipe:', 1, true) then return nil end
    local slots, armor, profession, bypass, requestedWeapons = {}, nil, nil, false, {}
    for word in message:gmatch('[^%s%p]+') do
        if explicitArmor[word] then armor = explicitArmor[word] end
        if explicitProfessions[word] then profession = explicitProfessions[word] end
        if explicitWords[word] then bypass = true end
        if slotWords[word] then slots[slotWords[word]] = true end
        if weaponWords[word] then requestedWeapons[weaponWords[word]] = true end
    end
    if profession then
        return {parentProfID=profession, explicitProfession=true, slots=slots,
            weapons=next(requestedWeapons) and requestedWeapons or nil}
    end
    if bypass then return nil end
    if next(requestedWeapons) then
        -- Mixed professions are split into independent request contexts below.
        local keys = {}; for key in pairs(requestedWeapons) do keys[#keys+1]=key end
        table.sort(keys)
        local class = M.ResolveClass(guid, sharedClass)
        if next(slots) and not armor and not class then return {unknownClass=true,slots=slots} end
        armor = armor or (class and armorByClass[class])
        return {parentProfID=weapons[keys[1]].parentProfID, slots=slots, weapons=requestedWeapons,
            class=class, armor=armor, armorParentProfID=armor and professionByArmor[armor]}
    end
    if armor then return {armor=armor, parentProfID=professionByArmor[armor], slots=slots} end
    if not next(slots) then return nil end
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
            -- An explicit incompatible profession is not permission to route
            -- the request to another one (e.g. weapon enchants).
            if not context.explicitProfession or weapons[key].parentProfID == context.parentProfID then
                requests[#requests+1]=weapons[key]
            end
        end
    end
    local armorProfession = context.armorParentProfID or context.parentProfID
    if armorProfession == 164 or armorProfession == 165 or armorProfession == 197 then
        for slot in pairs(context.slots or {}) do
            requests[#requests+1] = {key=slot, label=slotLabels[slot], slot=slot,
                armor=context.armor, parentProfID=armorProfession}
        end
    end
    table.sort(requests, function(a,b) return a.key < b.key end)
    return requests
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
    if context.unknownClass or (context.explicitProfession and not context.armor and next(context.slots)) then return false end
    if context.explicitProfession and not next(context.slots) then return true end
    if type(recipeInfo) ~= 'table' then return false end
    local getInfo = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if type(getInfo) ~= 'function' then return false end
    local loaded, outputs = pcall(Scan.Utils.GetOutputItems, recipeInfo)
    if not loaded or type(outputs) ~= 'table' then return false end
    for _, itemID in ipairs(outputs) do
        if context.weapons then
            for _, request in ipairs(M.GetRequests(context)) do
                if M.MatchesItem(request, itemID) then return true end
            end
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
