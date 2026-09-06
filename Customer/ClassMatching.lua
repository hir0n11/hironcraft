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

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

function M.ResolveClass(guid, sharedClass)
    if not IsSecret(guid) and type(guid) == 'string' and guid ~= ''
        and type(GetPlayerInfoByGUID) == 'function' then
        local ok, _, class = pcall(GetPlayerInfoByGUID, guid)
        if ok and not IsSecret(class) and type(class) == 'string' and armorByClass[class] then
            return class
        end
    end
    if not IsSecret(sharedClass) and type(sharedClass) == 'string' and armorByClass[sharedClass] then
        return sharedClass
    end
end

function M.GetContext(message, guid, sharedClass)
    if Scan.DB.settings.match_customer_class == false or IsSecret(message)
        or type(message) ~= 'string' then return nil end
    message = (strlower or string.lower)(message)
    -- Links are authoritative, including an unmonitored item/recipe link.
    if message:find('|hitem:', 1, true) or message:find('|henchant:', 1, true)
        or message:find('|hrecipe:', 1, true) then return nil end
    local slots = {}
    for word in message:gmatch('[^%s%p]+') do
        if explicitWords[word] then return nil end
        if slotWords[word] then slots[slotWords[word]] = true end
    end
    if not next(slots) then return nil end
    local class = M.ResolveClass(guid, sharedClass)
    if not class then return nil end
    local armor = armorByClass[class]
    return { class=class, armor=armor, parentProfID=professionByArmor[armor], slots=slots }
end

function M.MatchesRecipe(context, recipeInfo)
    if not context then return true end
    if type(recipeInfo) ~= 'table' then return false end
    local getInfo = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if type(getInfo) ~= 'function' then return false end
    local loaded, outputs = pcall(Scan.Utils.GetOutputItems, recipeInfo)
    if not loaded or type(outputs) ~= 'table' then return false end
    for _, itemID in ipairs(outputs) do
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
