local PT = HironCraftProfit
local L = PT.L
local OR_SEPARATOR = " " .. (L["OR"] or "OR") .. " "

local function GetStandingByFactionID(factionId)
    if C_Reputation and C_Reputation.GetFactionDataByID then
        local data = C_Reputation.GetFactionDataByID(factionId)
        if data then
            return data.name, data.reaction
        end
    end
    return nil, nil
end

PT.spellIdIdx                      = PT.spellIdIdx or {}
PT.questIdIdx                      = PT.questIdIdx or {}
PT.idIdx                           = PT.idIdx or {}
PT.professionSpellIdIdx            = PT.professionSpellIdIdx or {}
PT.professionCatchUpCurrencyIdIdx  = PT.professionCatchUpCurrencyIdIdx or {}

PT.professionCache = PT.professionCache or {}
PT.dbList = PT.dbList or { "DF", "TWW", "MID" }

local spellIdIdx                   = PT.spellIdIdx
local questIdIdx                   = PT.questIdIdx
local idIdx                        = PT.idIdx
local professionSpellIdIdx         = PT.professionSpellIdIdx
local professionCatchUpCurrencyIdIdx = PT.professionCatchUpCurrencyIdIdx

local HironCraftProfit_Item = {}
HironCraftProfit_Item.__index = HironCraftProfit_Item
PT.HironCraftProfit_Item = HironCraftProfit_Item

PT.MID_FALLBACK_NAMES = {
    [2912] = "Midnight Herbalism",
	[2915] = "Midnight Leatherworking",
	[2916] = "Midnight Mining",
	[2917] = "Midnight Skinning",
	[2918] = "Midnight Tailoring",
	[2906] = "Midnight Alchemy",
	[2907] = "Midnight Blacksmithing",
	[2909] = "Midnight Enchanting",
	[2910] = "Midnight Engineering",
	[2913] = "Midnight Inscription",
	[2914] = "Midnight Jewelcrafting"
}

local STANDING_LABELS = {
    [1] = L["Hated"],
    [2] = L["Hostile"],
    [3] = L["Unfriendly"],
    [4] = L["Neutral"],
    [5] = L["Preferred"],
    [6] = L["Esteemed"],
    [7] = L["Revered"],
    [8] = L["Exalted"],
}

function HironCraftProfit_Item:New(item)
    item = item or {}
    setmetatable(item, self)
    return item
end

local function NormalizeItemId(v)
    return PT.NormalizeItemId(v)
end

function HironCraftProfit_Item:GetId()
    return NormalizeItemId(self.itemId)
end

function HironCraftProfit_Item:IsUnique()
    return false
end

function HironCraftProfit_Item:IsCatchUp()
    return false
end

function HironCraftProfit_Item:Show()
    local prof = self.profession
    if not prof then
        return false
    end

    if prof.expansion == "DF" then
        local skillInfo = prof:GetSkillLevel()
        local skill = skillInfo and skillInfo.skillLevel or 0
        if skill < 25 then
            return false
        end
    end

    return prof.expanded
       and self:GetRemainingKnowledgePoints() > 0
end


function HironCraftProfit_Item:GetName()
    local id = NormalizeItemId(self.itemId)

    if self.name and self.name ~= L["Not loaded yet"] then
        return self.name
    end

    if id then
        local name = C_Item.GetItemNameByID(id) or GetItemInfo(id)
        if name then
            self.name = name
            return name
        end
    end

    return self.text or L["Not loaded yet"]
end

function HironCraftProfit_Item:GetIcon()
    if self.icon then
        return self.icon, false
    end

    local id = NormalizeItemId(self.itemId)
    if id and id > 0 then
        local icon = select(5, C_Item.GetItemInfoInstant(id))
        if icon then
            self.icon = icon
            return icon, false
        end
    end

    if self.atlasIcon then
        return self.atlasIcon, true
    end

    return 134400, false
end

function HironCraftProfit_Item:IsOnSameMap()
    if not self.waypoint or not self.waypoint.map then
        return false
    end

    local playerMap = C_Map.GetBestMapForUnit("player")
    if not playerMap then return false end

    local function NormalizeMap(mapID)
        local info = C_Map.GetMapInfo(mapID)
        if info and info.parentMapID then
            local parentInfo = C_Map.GetMapInfo(info.parentMapID)
            if parentInfo and parentInfo.mapType == 3 then
                return parentInfo.mapID
            end
        end
        return mapID
    end

    return NormalizeMap(playerMap) == NormalizeMap(self.waypoint.map)
end

function HironCraftProfit_Item:GetCategoryIcon()
    return CreateAtlasMarkup(self.atlasIcon , 16, 16)
end

function HironCraftProfit_Item:GetRemainingKnowledgePoints()
    local questCount = #(self.questId or {})
    for _, questId in ipairs(self.questId or {}) do
        if C_QuestLog.IsQuestFlaggedCompleted(questId) then
            questCount = questCount - 1
        end
    end
    return questCount * (self.kp or 0)
end

function HironCraftProfit_Item:MeetReputationRequirements()
    if self.renown then
        if not C_Reputation.IsMajorFaction(self.renown.majorFactionId) then
            return false
        end

        local level =
            C_MajorFactions.GetCurrentRenownLevel(self.renown.majorFactionId) or 0

        return level >= (self.renown.levelRequired or 0)
    end

    if self.reputation then
        local _, standingID = GetStandingByFactionID(self.reputation.factionId)
        if not standingID then
            return false
        end

        local need = self.reputation.standingRequired or 0
        return standingID >= need
    end

    return true
end

function HironCraftProfit_Item:MeetItemRequirements()
    if not self.itemRequirements then return true end

    local function OptionOk(option)
        local list = option

        if type(option) == "table" and option.id then
            list = { option }
        elseif type(option) == "table" and option[1] and type(option[1]) == "table" and option[1].id and #option == 1 then
            list = option
        end

        for _, req in ipairs(list) do
            if type(req) == "table" and req.id then
                local need = req.quantity or 0
                if C_Item.GetItemCount(req.id) < need then
                    return false
                end
            end
        end
        return true
    end

    local hasVariant = false
    for _, option in ipairs(self.itemRequirements) do
        if type(option) == "table" and not option.id and option[1] and type(option[1]) == "table" then
            hasVariant = true
            break
        end
    end

    if hasVariant then
        for _, option in ipairs(self.itemRequirements) do
            if OptionOk(option) then
                return true
            end
        end
        return false
    end

    for _, req in ipairs(self.itemRequirements) do
        if not OptionOk(req) then
            return false
        end
    end
    return true
end

function HironCraftProfit_Item:MeetItemRequirementsOR()
    if not self.itemRequirementsOR then return true end

    for _, option in ipairs(self.itemRequirementsOR) do
        local list = (option and option.id) and { option } or option
        local ok = true

        for _, req in ipairs(list or {}) do
            if req and req.id then
                local need = req.quantity or 0
                if C_Item.GetItemCount(req.id) < need then
                    ok = false
                    break
                end
            end
        end

        if ok then
            return true
        end
    end

    return false
end

function HironCraftProfit_Item:MeetQuestRequirements()
    if not self.requiresQuestId then return true end

    for _, questId in ipairs(self.requiresQuestId) do
        if C_QuestLog.IsQuestFlaggedCompleted(questId) then
            return true
        end
    end

    return false
end

function HironCraftProfit_Item:MeetUnlockRequirements()
    if self.IsCatchUp and self:IsCatchUp()
       and self.profession
       and self.profession.catchUpCurrencyId
       and not next(self.unlockRequirements or {})
    then
        return true
    end

    if not self.unlockRequirements then
        return true
    end

    for _, v in pairs(self.unlockRequirements) do
        if v:GetRemainingKnowledgePoints() > 0 then
            return false
        end
    end

    return true
end

function HironCraftProfit_Item:MeetCurrencyRequirements()
    if not self.currency then return true end

    local list = self.currency.id and { self.currency } or self.currency
    for _, v in ipairs(list) do
        local info = C_CurrencyInfo.GetCurrencyInfo(v.id)
        if not info or info.quantity < (v.quantity or 0) then
            return false
        end
    end

    return true
end

function HironCraftProfit_Item:MeetProfessionSkillRequirement()
    if not self.professionSkill then
        return true
    end

    local prof = self.profession
    if not prof then
        return true
    end

    if self.professionSkill.expansion
       and prof.expansion ~= self.professionSkill.expansion
    then
        return true
    end

    local skillInfo = prof:GetSkillLevel()
    local have = skillInfo and skillInfo.skillLevel or 0
    local need = self.professionSkill.level or 0

    return have >= need
end

function HironCraftProfit_Item:MeetRequirements()
    return self:MeetReputationRequirements()
       and self:MeetQuestRequirements()
       and self:MeetItemRequirements()
       and self:MeetItemRequirementsOR()
       and self:MeetCurrencyRequirements()
       and self:MeetProfessionSkillRequirement()
       and self:MeetUnlockRequirements()
end

function HironCraftProfit_Item:GetRequirementsText()
    local lines = {}
	
    if self.IsCatchUp and self:IsCatchUp()
       and self.profession
       and self.profession.catchUpCurrencyId
       and not next(self.unlockRequirements or {})
    then
        return nil
    end
	
    if self.renown then
        local info = C_MajorFactions.GetMajorFactionData(self.renown.majorFactionId)
        if info then
            local have = info.renownLevel or 0
            local need = self.renown.levelRequired or 0
            local ok = have >= need

            local color = ok and "ff33ff33" or "ffff3333"
            table.insert(lines,
                WrapTextInColorCode(
                    string.format("%s: %d / %d", info.name, have, need),
                    color
                )
            )
        end
    end

    if self.reputation then
        local name, standingID = GetStandingByFactionID(self.reputation.factionId)
        if name and standingID then
            local have = standingID
            local need = self.reputation.standingRequired or 0
            local ok = have >= need

            local color = ok and "ff33ff33" or "ffff3333"
            table.insert(lines,
                WrapTextInColorCode(
                    string.format(
                        "%s: %s / %s",
                        name,
                        STANDING_LABELS[have] or have,
                        STANDING_LABELS[need] or need
                    ),
                    color
                )
            )
        end
    end

if self.itemRequirements then
    for _, option in ipairs(self.itemRequirements) do
        local optionText = {}
        local requirementsList = (option.id and {option}) or option
        for _, req in ipairs(requirementsList) do
            local name = C_Item.GetItemNameByID(req.id) or ("ItemID " .. req.id)
            local have = C_Item.GetItemCount(req.id)
            local need = req.quantity or 0
            local color = have >= need and "ff33ff33" or "ffff3333"
            table.insert(optionText, WrapTextInColorCode(string.format("%d/%d %s", have, need, name), color))
        end
        table.insert(lines, table.concat(optionText, OR_SEPARATOR)) 
    end
end

if self.itemRequirementsOR then
    local first = true

    for _, option in ipairs(self.itemRequirementsOR) do
        if not first then
            table.insert(lines, OR_SEPARATOR:sub(2, -2)) 
        end
        first = false

        local optionText = {}
        local requirementsList = (option.id and { option }) or option

        for _, req in ipairs(requirementsList) do
            local name = C_Item.GetItemNameByID(req.id) or ("ItemID " .. req.id)
            local have = C_Item.GetItemCount(req.id)
            local need = req.quantity or 0
            local color = have >= need and "ff33ff33" or "ffff3333"
            table.insert(
                optionText,
                WrapTextInColorCode(string.format("%d/%d %s", have, need, name), color)
            )
        end

        table.insert(lines, table.concat(optionText, ", "))
    end
end

    if self.currency then
        local list = self.currency.id and { self.currency } or self.currency
        for _, v in ipairs(list) do
            local info = C_CurrencyInfo.GetCurrencyInfo(v.id)
            if info then
                local have = info.quantity or 0
                local need = v.quantity or 0
                local ok = have >= need

                local color = ok and "ff33ff33" or "ffff3333"
                table.insert(lines,
                    WrapTextInColorCode(
                        string.format("%d / %d %s", have, need, info.name),
                        color
                    )
                )
            end
        end
    end

if self.professionSkill then
    local prof = self.profession
    if prof then
        local skillInfo = prof:GetSkillLevel()
        local have = skillInfo and skillInfo.skillLevel or 0
        local need = self.professionSkill.level or 0
        local ok = have >= need

        local color = ok and "ff33ff33" or "ffff3333"

        table.insert(lines,
            WrapTextInColorCode(
                string.format(
                    "%s: %d / %d",
                    L["PROFESSION_SKILL"] or "Profession skill",
                    have,
                    need
                ),
                color
            )
        )
    end
end

    if #lines == 0 then
        return nil
    end

    return table.concat(lines, "\n")
end

function HironCraftProfit_Item:GetDescription()
    if not self.waypoint or not self.waypoint.map then
        return self.text
    end

    local renownText = ""
    local reputationText = ""

    if self.renown then
        local info = C_MajorFactions.GetMajorFactionData(self.renown.majorFactionId)
        if info then
            local have = info.renownLevel or 0
            local need = self.renown.levelRequired or 0
            local color = (have >= need) and "ff33ff33" or "ffff0000"
            renownText =
                info.name .. ": " ..
                WrapTextInColorCode(tostring(have), color) ..
                " / " ..
                tostring(need) ..
                "\n"
        end
    end

    if self.reputation then
        local name, standingID = GetStandingByFactionID(self.reputation.factionId)
        if name and standingID then
            local need = self.reputation.standingRequired or 0
            local color = (standingID >= need) and "ff33ff33" or "ffff0000"
            reputationText =
                name .. ": " ..
                WrapTextInColorCode(STANDING_LABELS[standingID] or tostring(standingID), color) ..
                " / " ..
                (STANDING_LABELS[need] or need) ..
                "\n"
        end
    end

local itemRequirements = ""
if self.itemRequirements then
    for _, option in ipairs(self.itemRequirements) do
        local optionText = {}
        local requirementsList = (option.id and {option}) or option
        for _, req in ipairs(requirementsList) do
            local itemName = C_Item.GetItemNameByID(req.id) or L["item not loaded"]
            local itemCount = C_Item.GetItemCount(req.id)
            local need = req.quantity or 0
            local ok = itemCount >= need
            local countStr = WrapTextInColorCode(tostring(itemCount), ok and "ff33ff33" or "ffff0000")
            table.insert(optionText, countStr .. "/" .. need .. " " .. itemName)
        end
        itemRequirements = itemRequirements .. table.concat(optionText, OR_SEPARATOR) .. "\n"
    end
end

local itemRequirementsOR = ""
if self.itemRequirementsOR then
    local first = true

    for _, option in ipairs(self.itemRequirementsOR) do
        if not first then
            itemRequirementsOR = itemRequirementsOR .. (L["OR"] or "OR") .. "\n"
        end
        first = false

        local optionText = {}
        local requirementsList = (option.id and { option }) or option

        for _, req in ipairs(requirementsList) do
            local itemName = C_Item.GetItemNameByID(req.id) or L["item not loaded"]
            local itemCount = C_Item.GetItemCount(req.id)
            local need = req.quantity or 0
            local ok = itemCount >= need
            local countStr = WrapTextInColorCode(tostring(itemCount), ok and "ff33ff33" or "ffff0000")

            table.insert(optionText, countStr .. "/" .. need .. " " .. itemName)
        end

        itemRequirementsOR = itemRequirementsOR .. table.concat(optionText, ", ") .. "\n"
    end
end

    local currencyRequirements = ""
    if self.currency then
        local list = self.currency.id and { self.currency } or self.currency
        for _, v in ipairs(list) do
            local info = C_CurrencyInfo.GetCurrencyInfo(v.id)
            if info then
                local have = info.quantity or 0
                local need = v.quantity or 0
                local ok = have >= need

                local currentStr = WrapTextInColorCode(tostring(have), ok and "ff33ff33" or "ffff0000")

                currencyRequirements =
                    currencyRequirements ..
                    CreateSimpleTextureMarkup(info.iconFileID, 16, 16) ..
                    " " .. info.name .. ": " ..
                    currentStr .. "/" .. tostring(need) .. "\n"
            end
        end
    end

    local mapInfo = C_Map.GetMapInfo(self.waypoint.map)
    local mapName = mapInfo and mapInfo.name or L["Unknown"]

	local x = (self.waypoint.x or 0) * 100
	local y = (self.waypoint.y or 0) * 100

	return string.format(
		"%s%s\n%s - %.2f, %.2f",
		renownText .. reputationText .. itemRequirements .. itemRequirementsOR .. currencyRequirements,
		self.text or self.name or L["Not loaded yet"],
		mapName,
		x,
		y
	)

end

local HironCraftProfit_CatchUp = HironCraftProfit_Item:New()
HironCraftProfit_CatchUp.__index = HironCraftProfit_CatchUp
PT.HironCraftProfit_CatchUp = HironCraftProfit_CatchUp

local function IsTreatiseEntry(entry)
    return entry
       and PT.HironCraftProfit_Treatise
       and entry.__index == PT.HironCraftProfit_Treatise
end

local function IsCurrencyCoveredWeeklyEntry(entry)
    if not entry or not entry.GetType then
        return false
    end

    if IsTreatiseEntry(entry) then
        return false
    end

    return entry:GetType() == 2
end

function HironCraftProfit_CatchUp:GetRemainingKnowledgePoints()
    local prof = self.profession
    if not prof then
        return 0
    end

    local raw = prof:GetCatchUpCurrencyLeft() or 0

    for _, entry in ipairs(prof.entries or {}) do
        if entry ~= self
           and IsCurrencyCoveredWeeklyEntry(entry)
           and entry.GetRemainingKnowledgePoints
        then
            raw = raw - (entry:GetRemainingKnowledgePoints() or 0)
        end
    end

    return math.max(0, raw)
end

function HironCraftProfit_CatchUp:GetType()
    return 4
end

function HironCraftProfit_CatchUp:GetName()
    if self.text then return self.text end
    return HironCraftProfit_Item.GetName(self)
end

function HironCraftProfit_CatchUp:IsCatchUp()
    return true
end

function HironCraftProfit_CatchUp:Show()
    return not PT.config.hideCatchUp and HironCraftProfit_Item.Show(self)
end

function HironCraftProfit_CatchUp:MeetRequirements()
    return self.text ~= nil or HironCraftProfit_Item.MeetRequirements(self)
end

local HironCraftProfit_DarkmoonQuest = HironCraftProfit_Item:New()
HironCraftProfit_DarkmoonQuest.__index = HironCraftProfit_DarkmoonQuest
HironCraftProfit_DarkmoonQuest.IsDarkmoonQuest = true
PT.HironCraftProfit_DarkmoonQuest = HironCraftProfit_DarkmoonQuest

function HironCraftProfit_DarkmoonQuest:GetId()
    return self.questId[1]
end

function HironCraftProfit_DarkmoonQuest:GetName()
    if self.name then return self.name end
    self.name = C_QuestLog.GetTitleForQuestID(self:GetId())
    return self.name
end

function HironCraftProfit_DarkmoonQuest:GetIcon()
    return 1100023
end

local function GetResetAwareDateInfo()
    local now = time()

    local secUntilReset = C_DateAndTime
        and C_DateAndTime.GetSecondsUntilDailyReset
        and C_DateAndTime.GetSecondsUntilDailyReset()

    if type(secUntilReset) == "number" and secUntilReset >= 0 then
        local lastReset = now + secUntilReset - (24 * 60 * 60)
        local info = date("*t", lastReset)

        if info and info.year and info.month and info.day then
            return info
        end
    end

    local info = date("*t", now)
    if info and info.year and info.month and info.day then
        return info
    end

    return nil
end

function HironCraftProfit_DarkmoonQuest:IsDmfUp()
    local info = GetResetAwareDateInfo()
    if not info then
        return false
    end

    local dayOfWeek = (tonumber(info.wday) or 1) - 1
    local dayOfMonth = tonumber(info.day)

    if not dayOfWeek or not dayOfMonth then
        return false
    end

    local firstSundayOfMonth = ((dayOfMonth - (dayOfWeek + 1)) % 7) + 1
    local daysSinceFirstSunday = dayOfMonth - firstSundayOfMonth

    return daysSinceFirstSunday >= 0 and daysSinceFirstSunday <= 6
end

function HironCraftProfit_DarkmoonQuest:GetRemainingKnowledgePoints()
    return not self:IsDmfUp() and 0 or HironCraftProfit_Item.GetRemainingKnowledgePoints(self)
end

function HironCraftProfit_DarkmoonQuest:GetCategoryIcon()
    return CreateAtlasMarkup("quest-recurring-available", 16, 16)
end

function HironCraftProfit_DarkmoonQuest:GetType()
    return 3
end

local HironCraftProfit_UniqueBook = HironCraftProfit_Item:New()
HironCraftProfit_UniqueBook.__index = HironCraftProfit_UniqueBook
PT.HironCraftProfit_UniqueBook = HironCraftProfit_UniqueBook

HironCraftProfit_UniqueBook.IsUniqueBook = true

function HironCraftProfit_UniqueBook:IsUnique()
    return true
end

function HironCraftProfit_UniqueBook:GetRemainingKnowledgePoints()
    if self._done then return 0 end
    local remainingKp = HironCraftProfit_Item.GetRemainingKnowledgePoints(self)
    self._done = remainingKp == 0
    return remainingKp
end

function HironCraftProfit_UniqueBook:GetCategoryIcon()
    local atlasIcon = self.atlasIcon or "Levelup-Icon-Bag"

    if self:IsOnSameMap() then
        return CreateAtlasMarkup(atlasIcon, 16, 16)
    end

    return CreateAtlasMarkup(atlasIcon, 16, 16, 0, 0, 64, 64, 64)
end


function HironCraftProfit_UniqueBook:GetType()
    return 1
end

function HironCraftProfit_UniqueBook:Show()
    return HironCraftProfit_Item.Show(self)
end

local HironCraftProfit_UniqueTreasure = HironCraftProfit_Item:New()
HironCraftProfit_UniqueTreasure.__index = HironCraftProfit_UniqueTreasure
PT.HironCraftProfit_UniqueTreasure = HironCraftProfit_UniqueTreasure

HironCraftProfit_UniqueTreasure.IsUniqueTreasure = true

function HironCraftProfit_UniqueTreasure:GetType()
    return 1
end

function HironCraftProfit_UniqueTreasure:GetCategoryIcon()
    local atlasIcon = self.atlasIcon or "poi-islands-table"
    local waypoint = self.waypoint
    local playerMap = C_Map.GetBestMapForUnit("player")

    if waypoint and playerMap then
        local parentMapInfo = C_Map.GetMapInfo(
            C_Map.GetMapInfo(playerMap).parentMapID or playerMap
        )
        local parentMap = parentMapInfo and parentMapInfo.mapID or playerMap
        if parentMapInfo and parentMapInfo.mapType == 3 then
            playerMap = parentMap
        end

        local waypointMap = waypoint.map
        local parentWaypointInfo = C_Map.GetMapInfo(
            C_Map.GetMapInfo(waypointMap).parentMapID or waypointMap
        )
        local parentWaypointMap =
            parentWaypointInfo and parentWaypointInfo.mapID or waypointMap
        if parentWaypointInfo and parentWaypointInfo.mapType == 3 then
            waypointMap = parentWaypointMap
        end

        if waypointMap == playerMap then
            return CreateAtlasMarkup(atlasIcon, 16, 16)
        end
    end
    return CreateAtlasMarkup(atlasIcon, 16, 16, 0, 0, 64, 64, 64)
end


local HironCraftProfit_WeeklyTreasure = HironCraftProfit_Item:New()
HironCraftProfit_WeeklyTreasure.__index = HironCraftProfit_WeeklyTreasure
PT.HironCraftProfit_WeeklyTreasure = HironCraftProfit_WeeklyTreasure

function HironCraftProfit_WeeklyTreasure:GetCategoryIcon()
    local atlasIcon = self.atlasIcon or "VignetteLoot"
    return CreateAtlasMarkup(atlasIcon, 16, 16)
end

function HironCraftProfit_WeeklyTreasure:GetType()
    return 2
end

local HironCraftProfit_WeeklyQuestItem = HironCraftProfit_Item:New()
HironCraftProfit_WeeklyQuestItem.__index = HironCraftProfit_WeeklyQuestItem
PT.HironCraftProfit_WeeklyQuestItem = HironCraftProfit_WeeklyQuestItem

function HironCraftProfit_WeeklyQuestItem:MeetRequirements()
    if not HironCraftProfit_Item.MeetRequirements(self) then
        return false
    end

    local prof = self.profession
    if not prof then
        return true
    end

    if prof.expansion == "DF"
       and self.text
       and self.text:find("Instructor Quest")
    then
        local skillInfo = prof:GetSkillLevel()
        local skill = skillInfo and skillInfo.skillLevel or 0
        if skill < 50 then
            return false
        end
    end

    return true
end

function HironCraftProfit_Item:MeetProfessionSkillRequirement()
    if not self.professionSkill then
        return true
    end

    local prof = self.profession
    if not prof then
        return true
    end

    if self.professionSkill.expansion
       and prof.expansion ~= self.professionSkill.expansion
    then
        return true
    end

    local skillInfo = prof:GetSkillLevel()
    local have = skillInfo and skillInfo.skillLevel or 0
    local need = self.professionSkill.level or 0

    return have >= need
end

function HironCraftProfit_WeeklyQuestItem:GetRemainingKnowledgePoints()
    for _, questId in ipairs(self.questId or {}) do
        if C_QuestLog.IsQuestFlaggedCompleted(questId) then
            return 0
        end
    end
    return self.kp or 0
end

function HironCraftProfit_WeeklyQuestItem:GetCategoryIcon()
    return CreateAtlasMarkup("quest-recurring-available", 16, 16)
end

function HironCraftProfit_WeeklyQuestItem:GetType()
    return 2
end

local HironCraftProfit_Instructor = HironCraftProfit_WeeklyQuestItem:New()
HironCraftProfit_Instructor.__index = HironCraftProfit_Instructor
PT.HironCraftProfit_Instructor = HironCraftProfit_Instructor

function HironCraftProfit_Instructor:GetName()
    return self.text or L["Instructor Quest"]
end

function HironCraftProfit_Instructor:GetId()
    if self.questId and self.questId[1] then
        return self.questId[1]
    end
    return self.itemId or 0
end

function HironCraftProfit_Instructor:GetIcon()
    if self.profession and self.profession.icon then
        return self.profession.icon
    end
    return 134400
end

local HironCraftProfit_Consortium = HironCraftProfit_WeeklyQuestItem:New()
HironCraftProfit_Consortium.__index = HironCraftProfit_Consortium
PT.HironCraftProfit_Consortium = HironCraftProfit_Consortium

function HironCraftProfit_Consortium:GetName()
    return self.text or L["Consortium Quest"]
end

function HironCraftProfit_Consortium:GetId()
    if self.questId and self.questId[1] then
        return self.questId[1]
    end
    return self.itemId or 0
end

function HironCraftProfit_Consortium:GetIcon()
    if self.profession and self.profession.icon then
        return self.profession.icon
    end
    return 134400
end

local HironCraftProfit_Expedition = HironCraftProfit_UniqueTreasure:New()
HironCraftProfit_Expedition.__index = HironCraftProfit_Expedition
PT.HironCraftProfit_Expedition = HironCraftProfit_Expedition

function HironCraftProfit_Expedition:GetId()
    if self.questId and self.questId[1] then
        return self.questId[1]
    end
    return self.itemId or 0
end

local HironCraftProfit_ProfMaster = HironCraftProfit_UniqueTreasure:New()
HironCraftProfit_ProfMaster.__index = HironCraftProfit_ProfMaster
PT.HironCraftProfit_ProfMaster = HironCraftProfit_ProfMaster

function HironCraftProfit_ProfMaster:GetId()
    if self.questId and self.questId[1] then
        return self.questId[1]
    end
    return self.itemId or 0
end

function HironCraftProfit_ProfMaster:GetIcon()
    if self.profession and self.profession.icon then
        return self.profession.icon
    end
    return 134400
end

local HironCraftProfit_Treatise = HironCraftProfit_WeeklyTreasure:New()
HironCraftProfit_Treatise.__index = HironCraftProfit_Treatise
PT.HironCraftProfit_Treatise = HironCraftProfit_Treatise

function HironCraftProfit_Treatise:Show()
    return not PT.config.hideTreatise and HironCraftProfit_Item.Show(self)
end

local HironCraftProfit_Profession = {}
HironCraftProfit_Profession.__index = HironCraftProfit_Profession
PT.HironCraftProfit_Profession = HironCraftProfit_Profession

function PT.GetWeeklyEntryType(entry)
    if entry.__index == PT.HironCraftProfit_Treatise then
        return "treatise"
    end

    if entry.__index == PT.HironCraftProfit_Instructor
       or entry.__index == PT.HironCraftProfit_Consortium
    then
        return "trainer"
    end

    if entry.__index == PT.HironCraftProfit_WeeklyTreasure then
        return "treasure"
    end

    return nil
end

function PT.IsWeeklyEntryCompleted(entry, completedQuests)
    if not entry.questId or #entry.questId == 0 then
        return false
    end

    for _, q in ipairs(entry.questId) do
        if completedQuests[q] then
            return true
        end
    end

    return false
end

function PT.GetWeeklyStatusForProfession(profession, completedQuests)
    local status = {
        trainer  = true,
        treasure = true,
        treatise = true,
    }

    local hasAny = {
        trainer  = false,
        treasure = false,
        treatise = false,
    }

    for _, entry in ipairs(profession.entries or {}) do
        local t = PT.GetWeeklyEntryType(entry)
        if t then
            hasAny[t] = true

            if not PT.IsWeeklyEntryCompleted(entry, completedQuests) then
                status[t] = false
            end
        end
    end

    for k, v in pairs(hasAny) do
        if not v then
            status[k] = nil
        end
    end

    return status
end

function HironCraftProfit_Profession:New(professionId, spellId, catchUpCurrencyId)
    local profession = {}
    setmetatable(profession, HironCraftProfit_Profession)

    profession.id = professionId
    profession.spellId = spellId
    profession.catchUpCurrencyId = catchUpCurrencyId

    HironCraftProfit.professions = HironCraftProfit.professions or {}
    HironCraftProfit.professions[profession.id] = profession

    if spellId then
        professionSpellIdIdx[spellId] = profession
    end
    if catchUpCurrencyId then
        professionCatchUpCurrencyIdIdx[catchUpCurrencyId] = profession
    end

    if C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID then
        local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(profession.id)
        if info then

            profession.name = info.professionName
                           or info.parentProfessionName
                           or info.skillLineName
                           or ("Profession " .. tostring(profession.id))

profession.skillLine =
    (info.parentProfessionID and info.parentProfessionID > 0 and info.parentProfessionID)
    or (info.professionID and info.professionID > 0 and info.professionID)
    or profession.id

            profession.icon = info.icon
                           or (C_TradeSkillUI.GetTradeSkillTexture and C_TradeSkillUI.GetTradeSkillTexture(profession.id))
                           or 134400
        else
            profession.name      = "Profession " .. tostring(profession.id)
            profession.skillLine = profession.id
            profession.icon      = 134400
        end
    else
        profession.name      = "Profession " .. tostring(profession.id)
        profession.skillLine = profession.id
        profession.icon      = 134400
    end
	
if not profession.name or profession.name == "" then
    if profession.isMID and PT.MID_FALLBACK_NAMES then
        local fallback = PT.MID_FALLBACK_NAMES[profession.id]
        if fallback then
            profession.name = fallback
        end
    end

    profession.name = profession.name or ("Profession " .. tostring(profession.id))
end

    profession.expanded = false
    profession.entries = {}
    profession.index = profession.id * 1000
    return profession
end

function HironCraftProfit_Profession:RefreshInfo()
    local id = self.id
local cached = PT.professionCache[id]
if cached and cached.name then
    self.name = cached.name
    self.icon = cached.icon
    if cached.skillLine then
        self.skillLine = cached.skillLine
    end
    return
end

if C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID then
    local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(id)
    if info and (info.professionName or info.parentProfessionName or info.skillLineName) then
        self.name = info.professionName or info.parentProfessionName or info.skillLineName
        self.icon = info.icon or self.icon

        self.skillLine =
            (info.parentProfessionID and info.parentProfessionID > 0 and info.parentProfessionID)
            or (info.professionID and info.professionID > 0 and info.professionID)
            or self.id

        PT.professionCache[id] = {
            name = self.name,
            icon = self.icon,
            skillLine = self.skillLine,
        }

        return
    end
end

if self.isMID and PT.MID_FALLBACK_NAMES then
    local fallback = PT.MID_FALLBACK_NAMES[self.id]
    if fallback then
        self.name = fallback
    end
end

end

function PT.UpdateAllProfessionNames()
    for _, dbKey in ipairs(PT.dbList) do
        local db = PT.DB[dbKey]
        if db then
            for _, prof in pairs(db) do
                if type(prof) == "table" then
                    prof:RefreshInfo()
                end
            end
        end
    end
end

function HironCraftProfit_Profession:AddEntry(entry)
    entry.profession = self

    if entry:IsUnique() and entry:GetRemainingKnowledgePoints() == 0 then
        return self
    end

    if entry.spell then
        spellIdIdx[entry.spell] = entry
    end

    idIdx[entry:GetId()] = entry

    for _, questId in ipairs(entry.questId or {}) do
        questIdIdx[questId] = entry
    end

    table.insert(self.entries, entry)
    entry.index = self.index + #self.entries

    return self
end

function HironCraftProfit_Profession:GetSkillLevel()

    local prof1, prof2 = GetProfessions()

    if prof1 then
        local _, _, skillLevel, maxSkillLevel, _, _, skillLine, bonusSkill, _, _, professionName =
            GetProfessionInfo(prof1)

        local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(self.id)

        if info and professionName == info.professionName then
            return {
                skillLevel = skillLevel or 0,
                maxSkillLevel = maxSkillLevel or 100,
                bonusSkill = bonusSkill or 0
            }
        end
    end

    if prof2 then
        local _, _, skillLevel, maxSkillLevel, _, _, skillLine, bonusSkill, _, _, professionName =
            GetProfessionInfo(prof2)

        local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(self.id)

        if info and professionName == info.professionName then
            return {
                skillLevel = skillLevel or 0,
                maxSkillLevel = maxSkillLevel or 100,
                bonusSkill = bonusSkill or 0
            }
        end
    end

    local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(self.id)

    if info and info.skillLevel and info.skillLevel > 0 then
        return {
            skillLevel = info.skillLevel,
            maxSkillLevel = info.maxSkillLevel or 100,
            bonusSkill = info.skillModifier or 0
        }
    end

    return { skillLevel = 0, maxSkillLevel = 0, bonusSkill = 0 }
end

function HironCraftProfit_Profession:CalculateRemainingKps()
    local weekly, unique, catchUp = 0, 0, 0
    for _, item in pairs(self.entries) do
        local remaining = item:GetRemainingKnowledgePoints()
        if item:IsUnique() then
            unique = unique + remaining
        elseif item:IsCatchUp() then
            catchUp = catchUp + remaining
        else
            weekly = weekly + remaining
        end
    end
    return { weekly=weekly, unique=unique, catchUp=catchUp }
end

function HironCraftProfit_Profession:GetCatchUpCurrencyLeft()
    if not self.catchUpCurrencyId then return 0 end
    local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(self.catchUpCurrencyId)
    if not currencyInfo then return 0 end
    return (currencyInfo.maxQuantity or 0) - (currencyInfo.quantity or 0)
end

local function GetPointsMissingForTree(configID, nodeID)
    local todo = { nodeID }
    local missing = 0
    while next(todo) do
        local nodeID2 = table.remove(todo)
        tAppendAll(todo, C_ProfSpecs.GetChildrenForPath(nodeID2))
        local info = C_Traits.GetNodeInfo(configID, nodeID2)
        if info then
            local enableFix = info.activeRank == 0 and 1 or 0
            missing = missing + info.maxRanks - info.activeRank - enableFix
        end
    end
    return missing
end

function HironCraftProfit_Profession:CalculateSpendableKps()
    local configID = C_ProfSpecs.GetConfigIDForSkillLine(self.id)
    if not configID then return 0 end

    local traitTreeIDs = C_ProfSpecs.GetSpecTabIDsForSkillLine(self.id) or {}
    local totalMissing = 0
    for _, traitTreeID in ipairs(traitTreeIDs) do
        local tabInfo = C_ProfSpecs.GetTabInfo(traitTreeID)
        if tabInfo then
            totalMissing = totalMissing + GetPointsMissingForTree(configID, tabInfo.rootNodeID)
        end
    end
    local currencyInfo = C_ProfSpecs.GetCurrencyInfoForSkillLine(self.id) or {numAvailable = 0}
    return totalMissing - currencyInfo.numAvailable
end

function PT.GetRemainingKPByExpansion(expansion)
    if not expansion then return 0 end

    local total = 0

    local prevDB = PT.config.activeDB
    if prevDB ~= expansion then
        HironCraftProfit_CharConfig.activeDB = expansion
        PT.config.activeDB = expansion
        PT.LoadActiveDB()
    end

    local profs = PT.GetProfessions(true)
    for _, profession in pairs(profs or {}) do
        for _, entry in ipairs(profession.entries or {}) do
            if entry.GetRemainingKnowledgePoints
               and entry.MeetRequirements
               and entry:MeetRequirements()
            then
                local v = entry:GetRemainingKnowledgePoints()
                if v and v > 0 then
                    total = total + v
                end
            end
        end
    end

    if prevDB ~= expansion then
        HironCraftProfit_CharConfig.activeDB = prevDB
        PT.config.activeDB = prevDB
        PT.LoadActiveDB()
    end

    return total
end

function PT.GetRemainingKPByProfession(expansion)
    if not expansion then return nil end

    local result = {}

    local prevDB = PT.config.activeDB
    if prevDB ~= expansion then
        HironCraftProfit_CharConfig.activeDB = expansion
        PT.config.activeDB = expansion
        PT.LoadActiveDB()
    end

    local profs = PT.GetProfessions(true)
    for _, profession in pairs(profs or {}) do
        local sum = 0

        for _, entry in ipairs(profession.entries or {}) do
            if entry.GetRemainingKnowledgePoints
               and entry.MeetRequirements
               and entry:MeetRequirements()
            then
                local v = entry:GetRemainingKnowledgePoints()
                if v and v > 0 then
                    sum = sum + v
                end
            end
        end

        if sum > 0 then
            result[profession.id] = {
                value = sum,
                name  = profession.name,
                icon  = profession.icon,
            }
        end
    end

    if prevDB ~= expansion then
        HironCraftProfit_CharConfig.activeDB = prevDB
        PT.config.activeDB = prevDB
        PT.LoadActiveDB()
    end

    return next(result) and result or nil
end

function HironCraftProfit_Profession:IsLearned()
        return true
end

function HironCraftProfit_Profession:GetAvailableItems()
    return self.entries
end

function PT.FindEntryById(entryId)
    return idIdx[entryId]
end

function PT.FindEntryByQuestId(questId)
    return questIdIdx[questId]
end

function PT.FindItemBySpellId(spellId)
    return spellIdIdx[spellId]
end

function PT.FindProfessionById(professionId)
    if PT.GetProfessions then
        return PT.GetProfessions()[professionId]
    end
end

function PT.FindProfessionBySpellId(spellId)
    return professionSpellIdIdx[spellId]
end

function PT.FindProfessionByCatchUpCurrencyId(catchUpCurrencyId)
    return professionCatchUpCurrencyIdIdx[catchUpCurrencyId]
end


local function TryEnableShiftSpendToNextPerk()
    if PT._professionShiftSpendHooked then
        return
    end

    if type(ProfessionsSpecPathMixin) ~= "table"
       or type(ProfessionsSpecPathMixin.PurchaseRank) ~= "function"
    then
        return
    end

    hooksecurefunc(ProfessionsSpecPathMixin, "PurchaseRank", function(self)
        if PT._professionShiftSpendBusy then
            return
        end

        if not IsShiftKeyDown() then
            return
        end

        if C_TradeSkillUI.IsTradeSkillLinked()
           or C_TradeSkillUI.IsTradeSkillGuild()
        then
            return
        end

        local nodeID = self and self.GetNodeID and self:GetNodeID()
        if not nodeID then
            return
        end

        local skillLineID = C_TradeSkillUI.GetProfessionChildSkillLineID()
        if not skillLineID then
            return
        end

        local configID = C_ProfSpecs.GetConfigIDForSkillLine(skillLineID)
        if not configID then
            return
        end

        local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
        if not nodeInfo then
            return
        end

        local currentRank = tonumber(nodeInfo.ranksPurchased or nodeInfo.activeRank)
        local maxRanks = tonumber(nodeInfo.maxRanks)
        if not currentRank or not maxRanks then
            return
        end

        if currentRank <= 0 or currentRank >= maxRanks then
            return
        end

        local spend = 5 - ((currentRank - 1) % 5)
        if spend <= 0 or spend >= 5 then
            return
        end

        PT._professionShiftSpendBusy = true

        local ok, err = pcall(function()
            for _ = 1, spend do
                local info = C_Traits.GetNodeInfo(configID, nodeID)
                if not info then
                    break
                end

                local rank = tonumber(info.ranksPurchased or info.activeRank)
                local maxRank = tonumber(info.maxRanks)
                if not rank or not maxRank or rank >= maxRank then
                    break
                end

                local purchased = C_Traits.PurchaseRank(configID, nodeID)
                if purchased == false then
                    break
                end
            end
        end)

        PT._professionShiftSpendBusy = false

        if not ok and PT.Debug then
            PT:Debug("profession shift-spend error: " .. tostring(err))
        end
    end)

    PT._professionShiftSpendHooked = true
end

local spendHookFrame = CreateFrame("Frame")
spendHookFrame:RegisterEvent("ADDON_LOADED")
spendHookFrame:RegisterEvent("TRADE_SKILL_SHOW")
spendHookFrame:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" and addonName ~= "Blizzard_Professions" then
        return
    end

    TryEnableShiftSpendToNextPerk()
end)

local f = CreateFrame("Frame")
f:RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")
f:RegisterEvent("SKILL_LINES_CHANGED")

f:SetScript("OnEvent", function()
    PT.UpdateAllProfessionNames()
    PT:RefreshData()
    PT:RefreshUI()
end)

return PT