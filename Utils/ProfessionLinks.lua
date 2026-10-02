local _, Scan = ...
local Links = {}
Scan.ProfessionLinks = Links

local function PublicString(value)
    return (not issecretvalue or not issecretvalue(value)) and type(value) == 'string'
end

-- Cache only a complete Retail trade link, never a recipe link or chat text.
-- The GUID and base skill line inside it must match the captured owner/skill.
function Links.Valid(link, guid, parentID)
    if not PublicString(link) or not PublicString(guid) or #link > 255
        or link:find('[\r\n]') then return false end
    local body = link:gsub('^|c%x%x%x%x%x%x%x%x', ''):gsub('|r$', '')
    local owner, _, skill = body:match('^|Htrade:(Player%-%d+%-%x+):(%d+):(%d+)|h[^|]+|h$')
    return owner == guid and tonumber(skill) == parentID
end

local function ReadCurrent(parentID)
    if not C_SpellBook or not C_Spell or not Enum or not Enum.SpellBookSpellBank then return end
    local ok, link = pcall(function()
        local index = C_SpellBook.GetSkillLineIndexByID(parentID)
        local info = index and C_SpellBook.GetSpellBookSkillLineInfo(index)
        if not info then return end
        local _, spellID = C_SpellBook.GetSpellBookItemType(info.itemIndexOffset + 1, Enum.SpellBookSpellBank.Player)
        return spellID and C_Spell.GetSpellTradeSkillLink(spellID)
    end)
    local guid = UnitGUID and UnitGUID('player')
    if ok and Links.Valid(link, guid, parentID) then return link, guid end
end

local function ParentConfig(crafter, professionID, info)
    local characters = Scan.DB and Scan.DB.characters
    local character = characters and characters[crafter]
    if not character then return end
    local child = character.professions and character.professions[professionID]
    local parentID = child and child.parentProfID
        or (info and (info.parentProfessionID or info.professionID)) or professionID
    return character.parent_professions and character.parent_professions[parentID], parentID
end

function Links.Get(crafter, professionID, info)
    local parent, parentID = ParentConfig(crafter, professionID, info)
    if parent and parent.character_disabled then return end
    local current = crafter == Scan.GetPlayerName(true)
    if current then
        local link = ReadCurrent(parentID)
        if link then return link end
    end
    local cached = parent and parent.profession_link
    if type(cached) ~= 'table' or cached.crafter ~= crafter
        or not Links.Valid(cached.link, cached.guid, parentID) then return end
    if current and (not UnitGUID or cached.guid ~= UnitGUID('player')) then return end
    return cached.link
end

function Links.Revision(crafter, professionID)
    local parent = ParentConfig(crafter, professionID)
    return parent and parent.rev or 0
end

local function ShareChange(crafter, parentID, parent)
    -- A parent-only update is tiny: no recipe catalog, no extra sync channel.
    if HironCraftScanComm and HironCraftScanComm.ShareCharacterModification then
        HironCraftScanComm:ShareCharacterModification(crafter, parentID, true)
    else
        parent.rev = (parent.rev or 0) + 1
    end
end

function Links.Capture()
    local db = Scan.DB
    local crafter = Scan.GetPlayerName(true)
    local character = db and db.characters and db.characters[crafter]
    if not character or not character.parent_professions or not db.settings
        or (character.sourceID and character.sourceID ~= db.settings.my_uuid)
        or not GetProfessions or not GetProfessionInfo then return end
    local ok, learned = pcall(function()
        local result = {}
        for _, index in pairs({ GetProfessions() }) do
            local _, _, _, _, _, _, parentID = GetProfessionInfo(index)
            if type(parentID) ~= 'number' then return end
            result[parentID] = true
        end
        return result
    end)
    -- Loading spell/profession data can transiently produce an empty list.
    -- Don't erase good links on that incomplete snapshot.
    if not ok or not learned or not next(learned) then return end
    for parentID, parent in pairs(character.parent_professions) do
        if learned[parentID] then
            local link, guid = ReadCurrent(parentID)
            local old = parent.profession_link
            if link and (type(old) ~= 'table' or old.link ~= link
                or old.guid ~= guid or old.crafter ~= crafter) then
                parent.profession_link = { link = link, guid = guid, crafter = crafter }
                ShareChange(crafter, parentID, parent)
            end
        elseif parent.profession_link then
            -- A known snapshot no longer contains this profession.
            parent.profession_link = nil
            ShareChange(crafter, parentID, parent)
        end
    end
end

local queued = false
local function Schedule()
    if queued then return end
    queued = true
    C_Timer.After(1, function()
        queued = false
        Links.Capture()
    end)
end
Scan.Utils.onLoad(Schedule)
Scan.Events:Register({ 'PROFESSION_SCAN_COMPLETE', 'CHARACTER_ENABLED' }, Schedule)
local events = CreateFrame('Frame')
for _, event in ipairs({ 'PLAYER_ENTERING_WORLD', 'SKILL_LINES_CHANGED', 'SPELLS_CHANGED',
    'TRADE_SKILL_SHOW', 'TRADE_SKILL_LIST_UPDATE' }) do events:RegisterEvent(event) end
events:SetScript('OnEvent', Schedule)
