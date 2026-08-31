local PT = HironCraftProfit
if not PT then return end

PT.AccountOverview_Data = PT.AccountOverview_Data or {}
local D = PT.AccountOverview_Data

local function GetCurrentCharKey()
    local name = UnitName("player")
    local realm = GetNormalizedRealmName()
    if not name then return nil end
    return name .. "-" .. (realm or "")
end

local function EnsureDB()
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB.accountOverview = HironCraftProfit_DB.accountOverview or {}
    HironCraftProfit_DB.accountOverview.chars = HironCraftProfit_DB.accountOverview.chars or {}
    return HironCraftProfit_DB.accountOverview.chars
end

local function CleanupInvalidCharacterKeys()
    local db = EnsureDB()

    for key in pairs(db) do
        if type(key) == "string" then
            local name, realm = strsplit("-", key)

            if not name or not realm or realm == "" then
                db[key] = nil
            end
        end
    end
end

local function NormalizeCharacterKeys()
    local db = EnsureDB()
    local realm = GetNormalizedRealmName()
    if not realm then return end

    for key, entry in pairs(db) do
        if type(key) == "string" then
            local n, r = strsplit("-", key)

            if n and (not r or r == "") then
                local newKey = n .. "-" .. realm

                if not db[newKey] then
                    db[newKey] = entry
                else

                    local a = db[newKey]
                    local aUpd = a and a.updated or 0
                    local bUpd = entry and entry.updated or 0
                    if bUpd > aUpd then
                        db[newKey] = entry
                    end
                end

                db[key] = nil
            end
        end
    end
end

local function CleanupLegacyConcentrationData()
    local db = EnsureDB()

    for _, entry in pairs(db) do
        if entry.concentration then
            for exp, snap in pairs(entry.concentration) do
				if type(snap) ~= "table"
				   or type(snap.profs) ~= "table"
				then
					entry.concentration[exp] = nil
				end
            end
        end
    end
end

local CONCENTRATION_MAX = 1000
local CONCENTRATION_NOTIFY_THRESHOLD = 995
local CONCENTRATION_REGEN_SEC = 6 * 60
local DUNDUN_CURRENCY_ID = 3376
local DUNDUN_WEEKLY_MAX  = 8
local DMF_EVENT_ID       = 479

local DMF_PROF_QUESTS = {
    [171] = 29506, -- Alchemy
    [164] = 29508, -- Blacksmithing
    [333] = 29510, -- Enchanting
    [202] = 29511, -- Engineering
    [182] = 29514, -- Herbalism
    [773] = 29515, -- Inscription
    [755] = 29516, -- Jewelcrafting
    [165] = 29517, -- Leatherworking
    [186] = 29518, -- Mining
    [393] = 29519, -- Skinning
    [197] = 29520, -- Tailoring
}

local function ApplyConcentrationRegen(value, lastUpdate)
    if type(value) ~= "number" or not lastUpdate then
        return value, lastUpdate
    end

    local now = time()
    local elapsed = now - lastUpdate
    if elapsed <= 0 then
        return value, lastUpdate
    end

    local regen = math.floor(elapsed / CONCENTRATION_REGEN_SEC)
    if regen <= 0 then
        return value, lastUpdate
    end

    local newValue = math.min(CONCENTRATION_MAX, value + regen)

    local used = regen * CONCENTRATION_REGEN_SEC
    local newUpdate = lastUpdate + used

    return newValue, newUpdate
end

local function GetCurrencyMap(expansion)
    if not PT.ConcentrationCurrencyMap then
        return nil
    end
    return PT.ConcentrationCurrencyMap[expansion:upper()]
end

local function GetPlayerConcentrationByProfession(expansion)
	if InCombatLockdown() then
		return nil
	end
    local map = PT.ConcentrationCurrencyMap
        and PT.ConcentrationCurrencyMap[expansion:upper()]
    if not map then return nil end

    local result = {}

    local p1, p2 = GetProfessions()
    for _, slot in ipairs({ p1, p2 }) do
        if slot then
            local name, icon, _, _, _, _, skillLine = GetProfessionInfo(slot)
            local currencyId = map[skillLine]

			if currencyId then
				local info = C_CurrencyInfo.GetCurrencyInfo(currencyId)

				result[skillLine] = {
					value = info and info.quantity or nil,
					name  = name,
					icon  = icon,
				}
			end
        end
    end

    return next(result) and result or nil
end

local function GetPlayerZealByProfession()
    if InCombatLockdown() then return nil end
    local map = PT.MID_ZEAL_CURRENCY_BY_PARENT_PROFESSION
    if not map then return nil end

    local result = {}

    local p1, p2 = GetProfessions()
    for _, slot in ipairs({ p1, p2 }) do
        if slot then
            local name, icon, _, _, _, _, skillLine = GetProfessionInfo(slot)
            local currencyId = map[skillLine]
            if currencyId then
                local info = C_CurrencyInfo.GetCurrencyInfo(currencyId)
                if info then
                    result[skillLine] = {
                        value = info.quantity or 0,
                        name  = name,
                        icon  = icon,
                    }
                end
            end
        end
    end

    return next(result) and result or nil
end

local function HasConcentrationProfession_Live(expansion)
    local map = PT.ConcentrationCurrencyMap
        and PT.ConcentrationCurrencyMap[expansion:upper()]
    if not map then return false end

    local p1, p2 = GetProfessions()
    for _, slot in ipairs({ p1, p2 }) do
        if slot then
            local _, _, _, _, _, _, skillLine = GetProfessionInfo(slot)
            if skillLine and map[skillLine] then
                return true
            end
        end
    end

    return false
end

local function GetCompletedWeeklyQuests_Live(expansion)
    local completed = {}

    local db = PT.DB and (PT.DB[expansion] or PT.DB[expansion:upper()])
    if not db then return completed end

    for _, prof in pairs(db) do
        for _, entry in ipairs(prof.entries or {}) do
            local qid = entry.questId
            if qid then
                if type(qid) == "number" then
                    if C_QuestLog.IsQuestFlaggedCompleted(qid) then
                        completed[qid] = true
                    end
                elseif type(qid) == "table" then
                    for _, q in ipairs(qid) do
                        if C_QuestLog.IsQuestFlaggedCompleted(q) then
                            completed[q] = true
                        end
                    end
                end
            end
        end
    end

    return completed
end

local function GetLearnedProfessions_Live(expansion)
    local result = {}

	local db = PT.DB and (PT.DB[expansion] or PT.DB[expansion:upper()])
	if not db then return {} end

    local learned = {}
    local p1, p2 = GetProfessions()

    for _, slot in ipairs({ p1, p2 }) do
        if slot then
            local name, icon, _, _, _, _, skillLine = GetProfessionInfo(slot)
            if skillLine then
                learned[skillLine] = {
                    name = name,
                    icon = icon,
                }
            end
        end
    end

    for profId, prof in pairs(db) do
        if prof.skillLine and learned[prof.skillLine] then
            result[profId] = {
                name = learned[prof.skillLine].name or prof.name,
                icon = learned[prof.skillLine].icon or prof.icon,
            }
        end
    end

    return result
end

local function GetWeeklyKeyFromEntry(entry)
    if not entry then return nil end

    if getmetatable(entry) == PT.HironCraftProfit_Treatise then
        return "treatise"
    end

    if getmetatable(entry) == PT.HironCraftProfit_WeeklyTreasure
       or getmetatable(entry) == PT.HironCraftProfit_WeeklyQuestItem
    then
        return "treasure"
    end

    if getmetatable(entry) == PT.HironCraftProfit_Instructor
       or getmetatable(entry) == PT.HironCraftProfit_Consortium
       or getmetatable(entry) == PT.HironCraftProfit_WorkOrder
       or getmetatable(entry) == PT.HironCraftProfit_CraftingOrder
    then
        return "trainer"
    end

    return nil
end

local function IsEntryDone(entry, isQuestDone)
    local qid = entry.questId
    if not qid then return false end

    if type(qid) == "number" then
        return isQuestDone(qid)
    elseif type(qid) == "table" then
        for _, q in ipairs(qid) do
            if isQuestDone(q) then
                return true
            end
        end
    end

    return false
end

local function BuildWeeklyStatusForProfession(prof, isQuestDone)
    local trainer = {
        instructor = nil,
        consortium = nil,
        questitem  = nil,
    }

    local treasure = {
        total = 0,
        done  = 0,
    }

    local treatise = {
        exists = false,
        done   = false,
    }

    for _, entry in ipairs(prof.entries or {}) do
        local done = IsEntryDone(entry, isQuestDone)
        local mt = getmetatable(entry)

        if mt == PT.HironCraftProfit_Instructor then
            trainer.instructor = done
        elseif mt == PT.HironCraftProfit_Consortium then
            trainer.consortium = done
        elseif mt == PT.HironCraftProfit_WeeklyQuestItem then
            trainer.questitem = done

        elseif mt == PT.HironCraftProfit_WeeklyTreasure then
            treasure.total = treasure.total + 1
            if done then
                treasure.done = treasure.done + 1
            end

        elseif mt == PT.HironCraftProfit_Treatise then
            treatise.exists = true
            treatise.done   = done
        end
    end

    local trainerDone = true
    for _, v in pairs(trainer) do
        if v == false then
            trainerDone = false
            break
        end
    end

    return {
        trainer  = trainerDone and next(trainer) ~= nil,
        treasure = (treasure.total > 0) and (treasure.done == treasure.total),
        treatise = treatise.exists and treatise.done,
    }
end

D.TIMEWALKING = {
    CLASSIC = {
        quests = { 83285 },
        atlas  = "accountupgradebanner-classic",
    },
    TBC = {
        quests = { 40168 },
        atlas  = "accountupgradebanner-bc",
    },
    WOTLK = {
        quests = { 40173 },
        atlas  = "accountupgradebanner-wotlk",
    },
    CATA = {
        quests = { 40787, 40786 },
        atlas  = "accountupgradebanner-cataclysm",
    },
    MOP = {
        quests = { 45563 },
        atlas  = "accountupgradebanner-mop",
    },
    WOD = {
        quests = { 55498, 55499 },
        atlas  = "accountupgradebanner-wod",
    },
    LEGION = {
        quests = { 64710 },
        atlas  = "accountupgradebanner-legion",
    },
    BFA = {
        quests = { 89223 },
        atlas  = "accountupgradebanner-bfa",
    },
    SL = {
        quests = { 92650 },
        atlas  = "accountupgradebanner-shadowlands",
    },
    DF = {
        quests = { 93852 },
        atlas  = "accountupgradebanner-dragonflight",
    },
}

local EVENT_TO_TW = {
    [167] = "CLASSIC",
    [168] = "TBC",
    [169] = "WOTLK",
    [170] = "CATA",
    [171] = "MOP",
    [172] = "WOD",
    [173] = "LEGION",
    [174] = "BFA",
    [175] = "SL",
    [176] = "DF",
}

local TIMEWALKING_EVENT_IDS = {
    167, -- Classic Timewalking
    168, -- Burning Crusade
    169, -- Wrath of the Lich King
    170, -- Cataclysm
    171, -- Mists of Pandaria
    172, -- Warlords of Draenor
    173, -- Legion
    174, -- Battle for Azeroth
    175, -- Shadowlands
    176, -- Dragonflight
}

local TW_AURA_TO_KEY = {
    [452307]  = "CLASSIC", -- Sign of the Past
    [335148]  = "TBC",     -- Sign of the Twisting Nether
    [335149]  = "WOTLK",   -- Sign of the Scourge
    [335150]  = "CATA",    -- Sign of the Destroyer
    [335151]  = "MOP",     -- Sign of the Mists
    [335152]  = "WOD",     -- Sign of Iron
    [359082]  = "LEGION",  -- Sign of the Legion
    [1223878] = "BFA",     -- Sign of Azeroth 
    [1256081] = "SL",  	   -- Sign of Azeroth(Shadowlands)
    [1305981] = "DF",      -- Sign of the Dragonflights
}

local function GetActiveTimewalkingFromAura()
	if InCombatLockdown() then
		return nil
	end
	
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then
        return nil
    end

    local index = 1
    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")
        if not aura then
            break
        end

		local spellId = aura.spellId
		if type(spellId) == "number" then
			local key = TW_AURA_TO_KEY[spellId]
			if key then
				return key
			end
		end

        index = index + 1
    end

    return nil
end

local function GetActiveTimewalking()
    local twKey = GetActiveTimewalkingFromAura()
    if twKey then
        return twKey
    end

    local today = C_DateAndTime.GetCurrentCalendarTime().monthDay
    local num = C_Calendar.GetNumDayEvents(0, today)

    for i = 1, num do
        local ev = C_Calendar.GetDayEvent(0, today, i)
        if ev and ev.calendarType == "HOLIDAY" and ev.eventID then
            for _, id in ipairs(TIMEWALKING_EVENT_IDS) do
                if ev.eventID == id then
                    return EVENT_TO_TW[ev.eventID]
                end
            end
        end
    end

    return nil
end

local function GetResetPeriodKey(secondsUntilReset, fallbackSeconds)
    if type(secondsUntilReset) ~= "number" or secondsUntilReset < 0 then
        secondsUntilReset = fallbackSeconds
    end

    local nextReset = time() + secondsUntilReset

    return math.floor(nextReset / 60)
end

local function GetServerDayKey()
    local sec = C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset
        and C_DateAndTime.GetSecondsUntilDailyReset()

    return GetResetPeriodKey(sec, 24 * 60 * 60)
end

local function GetServerWeekKey()
    local sec = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
        and C_DateAndTime.GetSecondsUntilWeeklyReset()

    return GetResetPeriodKey(sec, 7 * 24 * 60 * 60)
end

local function GetDarkmoonMonthKey()
    local cal = C_DateAndTime
        and C_DateAndTime.GetCurrentCalendarTime
        and C_DateAndTime.GetCurrentCalendarTime()

    local anchorTime
    if cal and cal.year and cal.month and cal.monthDay then
        anchorTime = time({
            year  = cal.year,
            month = cal.month,
            day   = cal.monthDay,
            hour  = 12,
            min   = 0,
            sec   = 0,
        })
    else
        local now = date("*t")
        anchorTime = time({
            year  = now.year,
            month = now.month,
            day   = now.day,
            hour  = 12,
            min   = 0,
            sec   = 0,
        })
    end

    anchorTime = anchorTime + (3 * 24 * 60 * 60)

    local info = date("*t", anchorTime)
    if not info then
        return nil
    end

    return string.format("%04d-%02d", info.year, info.month)
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

local function IsDarkmoonFaireActiveByReset()
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

local function MakeDarkmoonActiveInfo(eventID)
    local monthKey = GetDarkmoonMonthKey()
    if not monthKey then
        return nil
    end

    return {
        eventID  = eventID or DMF_EVENT_ID,
        monthKey = monthKey,
    }
end

local function GetActiveDarkmoonInfo()
    if not IsDarkmoonFaireActiveByReset() then
        return nil
    end

    if C_Calendar
       and C_Calendar.GetNumDayEvents
       and C_Calendar.GetDayEvent
       and C_DateAndTime
       and C_DateAndTime.GetCurrentCalendarTime
    then
        local cal = C_DateAndTime.GetCurrentCalendarTime()

        if cal and cal.monthDay then
            local num = C_Calendar.GetNumDayEvents(0, cal.monthDay) or 0

            for i = 1, num do
                local ev = C_Calendar.GetDayEvent(0, cal.monthDay, i)

                if ev
                   and ev.calendarType == "HOLIDAY"
                   and ev.eventID == DMF_EVENT_ID
                then
                    return MakeDarkmoonActiveInfo(ev.eventID)
                end
            end
        end
    end

    return MakeDarkmoonActiveInfo(DMF_EVENT_ID)
end

local function GetDarkmoonProfessions_Live()
    local active = GetActiveDarkmoonInfo()
    if not active then
        return nil, nil
    end

    local result = {}
    local p1, p2 = GetProfessions()

    for _, slot in ipairs({ p1, p2 }) do
        if slot then
            local name, icon, _, _, _, _, skillLine = GetProfessionInfo(slot)
            local questID = DMF_PROF_QUESTS[skillLine]

            if skillLine and questID then
                result[skillLine] = {
                    name    = name,
                    icon    = icon,
                    questID = questID,
                    done    = C_QuestLog.IsQuestFlaggedCompleted(questID) == true,
                }
            end
        end
    end

    return next(result) and result or nil, active.monthKey
end

local function GetPlayerDundunWeekly_Live()
    if not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyInfo then
        return nil
    end

    local info = C_CurrencyInfo.GetCurrencyInfo(DUNDUN_CURRENCY_ID)
    if not info then
        return nil
    end

    local weekly = nil

    if type(info.quantityEarnedThisWeek) == "number" then
        weekly = info.quantityEarnedThisWeek
    elseif type(info.totalEarnedThisWeek) == "number" then
        weekly = info.totalEarnedThisWeek
    elseif type(info.earnedThisWeek) == "number" then
        weekly = info.earnedThisWeek
    end

    if type(weekly) ~= "number" then
        return nil
    end

    weekly = math.max(0, math.min(DUNDUN_WEEKLY_MAX, weekly))

    local quantity = 0
    if type(info.quantity) == "number" then
        quantity = math.max(0, info.quantity)
    end

    local maxWeekly = DUNDUN_WEEKLY_MAX
    if type(info.maxWeeklyQuantity) == "number" and info.maxWeeklyQuantity > 0 then
        maxWeekly = info.maxWeeklyQuantity
    end

    return {
        value    = weekly,
        quantity = quantity,
        max      = maxWeekly,
    }
end

local function IsSafeEnvironment()
    if InCombatLockdown() then
        return false
    end

    local inInstance = IsInInstance()
    if inInstance then
        return false
    end

    return true
end

local function SaveSkinningSnapshotForEntry(entry)
    if not entry then
        return
    end

    if PT.SkinningCheck and PT.SkinningCheck:IsAvailable() then
        local done, total = PT.SkinningCheck:GetProgress()
        if done and total then
            local currentDayKey = GetServerDayKey()
            local prevSnap = entry.skinning

            if prevSnap and prevSnap.dayKey ~= currentDayKey then
                done = 0
            elseif prevSnap and prevSnap.dayKey == currentDayKey then
                done = math.max(done or 0, prevSnap.done or 0)
            end

            entry.skinning = {
                done    = done,
                total   = total,
                updated = time(),
                dayKey  = currentDayKey,
            }
            return
        end
    end

    entry.skinning = nil
end


local PROFESSION_EQUIP_LOCS = {
    INVTYPE_PROFESSION_TOOL = true,
    INVTYPE_PROFESSION_GEAR = true,
}

local PROF_EQUIP_FILTER_VERSION = 9

local PRIMARY_PROFESSION_SKILL_LINES = {
    [164] = true, -- Blacksmithing
    [165] = true, -- Leatherworking
    [171] = true, -- Alchemy
    [182] = true, -- Herbalism
    [186] = true, -- Mining
    [197] = true, -- Tailoring
    [202] = true, -- Engineering
    [333] = true, -- Enchanting
    [393] = true, -- Skinning
    [755] = true, -- Jewelcrafting
    [773] = true, -- Inscription
}

local SECONDARY_PROFESSION_SKILL_LINES = {
    [129] = true, -- First Aid / legacy
    [185] = true, -- Cooking
    [356] = true, -- Fishing
    [794] = true, -- Archaeology
}

local PROFESSION_SKILL_TO_ENUM = {
    [129] = 0,  -- First Aid / legacy
    [164] = 1,  -- Blacksmithing
    [165] = 2,  -- Leatherworking
    [171] = 3,  -- Alchemy
    [182] = 4,  -- Herbalism
    [185] = 5,  -- Cooking
    [186] = 6,  -- Mining
    [197] = 7,  -- Tailoring
    [202] = 8,  -- Engineering
    [333] = 9,  -- Enchanting
    [356] = 10, -- Fishing
    [393] = 11, -- Skinning
    [755] = 12, -- Jewelcrafting
    [773] = 13, -- Inscription
    [794] = 14, -- Archaeology
}

local PRIMARY_PROFESSION_ENUMS = {
    [1]  = true, -- Blacksmithing
    [2]  = true, -- Leatherworking
    [3]  = true, -- Alchemy
    [4]  = true, -- Herbalism
    [6]  = true, -- Mining
    [7]  = true, -- Tailoring
    [8]  = true, -- Engineering
    [9]  = true, -- Enchanting
    [11] = true, -- Skinning
    [12] = true, -- Jewelcrafting
    [13] = true, -- Inscription
}

local SECONDARY_PROFESSION_ENUMS = {
    [0]  = true, -- First Aid / legacy
    [5]  = true, -- Cooking
    [10] = true, -- Fishing
    [14] = true, -- Archaeology
}

local function AddEnumValue(map, key)
    if Enum and Enum.Profession and Enum.Profession[key] ~= nil then
        map[tonumber(Enum.Profession[key])] = true
    end
end

AddEnumValue(PRIMARY_PROFESSION_ENUMS, "Blacksmithing")
AddEnumValue(PRIMARY_PROFESSION_ENUMS, "Leatherworking")
AddEnumValue(PRIMARY_PROFESSION_ENUMS, "Alchemy")
AddEnumValue(PRIMARY_PROFESSION_ENUMS, "Herbalism")
AddEnumValue(PRIMARY_PROFESSION_ENUMS, "Mining")
AddEnumValue(PRIMARY_PROFESSION_ENUMS, "Tailoring")
AddEnumValue(PRIMARY_PROFESSION_ENUMS, "Engineering")
AddEnumValue(PRIMARY_PROFESSION_ENUMS, "Enchanting")
AddEnumValue(PRIMARY_PROFESSION_ENUMS, "Skinning")
AddEnumValue(PRIMARY_PROFESSION_ENUMS, "Jewelcrafting")
AddEnumValue(PRIMARY_PROFESSION_ENUMS, "Inscription")

AddEnumValue(SECONDARY_PROFESSION_ENUMS, "FirstAid")
AddEnumValue(SECONDARY_PROFESSION_ENUMS, "Cooking")
AddEnumValue(SECONDARY_PROFESSION_ENUMS, "Fishing")
AddEnumValue(SECONDARY_PROFESSION_ENUMS, "Archaeology")

local GetItemInstantInfo

local function AddUniqueSlot(list, seen, slot, source, profession, displayIndex, profOrder, slotOrder, professionName)
    slot = tonumber(slot)
    if not slot then
        return
    end

    local seenKey = tostring(slot)

    if source == "primary" and profession then
        seenKey = tostring(profession) .. ":" .. tostring(slot)
    end

    if seen[seenKey] then
        return
    end

    seen[seenKey] = true

    table.insert(list, {
        slot         = slot,
        source       = source,
        profession   = tonumber(profession),
        displayIndex = tonumber(displayIndex),
        profOrder    = tonumber(profOrder),
        slotOrder    = tonumber(slotOrder),
        professionName = professionName,
    })
end

local function ExtractSlotNumber(value)
    if type(value) == "number" then
        return value
    end

    if type(value) == "table" then
        return value.slot
            or value.slotID
            or value.slotId
            or value.inventorySlot
            or value.inventorySlotID
            or value.inventorySlotId
            or value.inventorySlotIndex
            or value.invSlot
    end

    return nil
end

local function GetProfessionByInventorySlotSafe(slot)
    slot = tonumber(slot)
    if not slot then
        return nil
    end

    if C_TradeSkillUI and C_TradeSkillUI.GetProfessionByInventorySlot then
        local ok, profession = pcall(C_TradeSkillUI.GetProfessionByInventorySlot, slot)
        profession = tonumber(profession)

        if ok and profession then
            return profession
        end
    end

    return nil
end

GetItemInstantInfo = function(item)
    if C_Item and C_Item.GetItemInfoInstant then
        local ok, itemID, itemType, itemSubType, equipLoc, icon, classID, subClassID =
            pcall(C_Item.GetItemInfoInstant, item)
        if ok then
            return itemID, itemType, itemSubType, equipLoc, icon, classID, subClassID
        end
    end

    if GetItemInfoInstant then
        local ok, itemID, itemType, itemSubType, equipLoc, icon, classID, subClassID =
            pcall(GetItemInfoInstant, item)
        if ok then
            return itemID, itemType, itemSubType, equipLoc, icon, classID, subClassID
        end
    end
end

local function GetItemNameSafe(itemID, link)
    if C_Item and C_Item.GetItemNameByID and itemID then
        local ok, name = pcall(C_Item.GetItemNameByID, itemID)
        if ok and name then
            return name
        end
    end

    if GetItemInfo then
        local ok, name = pcall(GetItemInfo, link or itemID)
        if ok and name then
            return name
        end
    end
end

local function GetCraftedQualitySafe(itemInfo)
    if not itemInfo
       or not C_TradeSkillUI
       or not C_TradeSkillUI.GetItemCraftedQualityByItemInfo
    then
        return nil
    end

    local ok, quality = pcall(C_TradeSkillUI.GetItemCraftedQualityByItemInfo, itemInfo)
    quality = tonumber(quality)

    if ok and quality and quality > 0 then
        return quality
    end

    return nil
end

local function AddSkillLineAliases(skillLine, map)
    skillLine = tonumber(skillLine)
    if not skillLine then
        return nil
    end

    map[skillLine] = true

    if C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID then
        local ok, info = pcall(C_TradeSkillUI.GetProfessionInfoBySkillLineID, skillLine)

        if ok and type(info) == "table" then
            for _, key in ipairs({
                "professionID",
                "parentProfessionID",
                "skillLineID",
                "parentSkillLineID",
            }) do
                local value = tonumber(info[key])
                if value and value > 0 then
                    map[value] = true
                end
            end

            return tonumber(info.profession) or PROFESSION_SKILL_TO_ENUM[skillLine]
        end
    end

    return PROFESSION_SKILL_TO_ENUM[skillLine]
end

local function GetProfessionEnumForSkillLine(skillLine)
    local aliases = {}
    local profession = AddSkillLineAliases(skillLine, aliases)

    if profession then
        return tonumber(profession)
    end

    skillLine = tonumber(skillLine)
    return skillLine and PROFESSION_SKILL_TO_ENUM[skillLine] or nil
end

local function AddProfessionIndexToMaps(profIndex, skillLines, professions)
    if not profIndex then
        return
    end

    local _, _, _, _, _, _, skillLine = GetProfessionInfo(profIndex)
    skillLine = tonumber(skillLine)

    if not skillLine then
        return
    end

    local profession = AddSkillLineAliases(skillLine, skillLines)
    profession = tonumber(profession) or GetProfessionEnumForSkillLine(skillLine)

    if profession then
        professions[profession] = true
    end
end

local function GetProfessionGearFilterMaps()
    local primarySkillLines = {}
    local primaryProfessions = {}
    local secondarySkillLines = {}
    local secondaryProfessions = {}

    for skillLine in pairs(SECONDARY_PROFESSION_SKILL_LINES) do
        secondarySkillLines[skillLine] = true
        local profession = PROFESSION_SKILL_TO_ENUM[skillLine]
        if profession then
            secondaryProfessions[profession] = true
        end
    end

    for profession in pairs(SECONDARY_PROFESSION_ENUMS) do
        secondaryProfessions[profession] = true
    end

    local p1, p2, archaeology, fishing, cooking, firstAid = GetProfessions()

    AddProfessionIndexToMaps(p1, primarySkillLines, primaryProfessions)
    AddProfessionIndexToMaps(p2, primarySkillLines, primaryProfessions)

    AddProfessionIndexToMaps(archaeology, secondarySkillLines, secondaryProfessions)
    AddProfessionIndexToMaps(fishing, secondarySkillLines, secondaryProfessions)
    AddProfessionIndexToMaps(cooking, secondarySkillLines, secondaryProfessions)
    AddProfessionIndexToMaps(firstAid, secondarySkillLines, secondaryProfessions)

    for profession in pairs(secondaryProfessions) do
        primaryProfessions[profession] = nil
    end

    return primarySkillLines, primaryProfessions, secondarySkillLines, secondaryProfessions,
        next(primarySkillLines) ~= nil or next(primaryProfessions) ~= nil
end

local function BuildPrimaryProfessionRows()
    local rows = {}
    local p1, p2 = GetProfessions()

    for rawOrder, profIndex in ipairs({ p1, p2 }) do
        if profIndex then
            local name, icon, _, _, _, _, skillLine = GetProfessionInfo(profIndex)
            skillLine = tonumber(skillLine)

            if skillLine then
                local aliases = {}
                local profession = AddSkillLineAliases(skillLine, aliases)
                profession = tonumber(profession) or GetProfessionEnumForSkillLine(skillLine)

                if profession and not SECONDARY_PROFESSION_ENUMS[profession] then
                    table.insert(rows, {
                        name       = tostring(name or ""),
                        icon       = tonumber(icon),
                        skillLine  = skillLine,
                        aliases    = aliases,
                        profession = profession,
                        rawOrder   = rawOrder,
                    })
                end
            end
        end
    end

    table.sort(rows, function(a, b)
        local aName = a.name or ""
        local bName = b.name or ""

        if aName ~= bName then
            return aName < bName
        end

        return (tonumber(a.rawOrder) or 0) < (tonumber(b.rawOrder) or 0)
    end)

    for displayOrder, row in ipairs(rows) do
        row.displayOrder = displayOrder
    end

    return rows
end

local function GetPrimaryProfessionOrderMaps()
    local skillLineOrder = {}
    local professionOrder = {}

    for _, row in ipairs(BuildPrimaryProfessionRows()) do
        local displayOrder = tonumber(row.displayOrder)

        if displayOrder then
            if row.profession then
                professionOrder[row.profession] = displayOrder
            end

            if row.skillLine and not SECONDARY_PROFESSION_SKILL_LINES[row.skillLine] then
                skillLineOrder[row.skillLine] = displayOrder
            end

            for alias in pairs(row.aliases or {}) do
                if not SECONDARY_PROFESSION_SKILL_LINES[alias] then
                    skillLineOrder[alias] = displayOrder
                end
            end
        end
    end

    return skillLineOrder, professionOrder
end

local function GetDisplayProfOrderForGear(skillLine, profession, fallbackProfOrder)
    local skillLineOrder, professionOrder = GetPrimaryProfessionOrderMaps()

    profession = tonumber(profession)
    if profession and professionOrder[profession] then
        return professionOrder[profession]
    end

    skillLine = tonumber(skillLine)
    if skillLine then
        if skillLineOrder[skillLine] then
            return skillLineOrder[skillLine]
        end

        local aliases = {}
        AddSkillLineAliases(skillLine, aliases)

        for alias in pairs(aliases) do
            if skillLineOrder[alias] then
                return skillLineOrder[alias]
            end
        end
    end

    return tonumber(fallbackProfOrder)
end

local function AddPrimaryProfessionSlots(slots, seen)
    if not C_TradeSkillUI or not C_TradeSkillUI.GetProfessionSlots then
        return
    end

    local primaryOrderByProfession = {}
    local primaryList = BuildPrimaryProfessionRows()

    for _, row in ipairs(primaryList) do
        if row.profession and row.displayOrder then
            primaryOrderByProfession[row.profession] = row.displayOrder
        end
    end

    for _, profInfo in ipairs(primaryList) do
        local ok, profSlots = pcall(C_TradeSkillUI.GetProfessionSlots, profInfo.profession)
        local displayProfOrder = tonumber(profInfo.displayOrder) or tonumber(profInfo.rawOrder) or 1

        if ok and type(profSlots) == "table" then
            for slotOrder, value in ipairs(profSlots) do
                if slotOrder <= 3 then
                    local slot = ExtractSlotNumber(value)
                    local ownerProfession = GetProfessionByInventorySlotSafe(slot)
                    local slotProfession = profInfo.profession

                    if ownerProfession
                       and primaryOrderByProfession[ownerProfession] == displayProfOrder
                    then
                        slotProfession = ownerProfession
                    end

                    AddUniqueSlot(
                        slots,
                        seen,
                        slot,
                        "primary",
                        slotProfession,
                        (displayProfOrder - 1) * 3 + slotOrder,
                        displayProfOrder,
                        slotOrder,
                        profInfo.name
                    )
                end
            end
        elseif ok then
            local slot = ExtractSlotNumber(profSlots)
            local ownerProfession = GetProfessionByInventorySlotSafe(slot)
            local slotProfession = profInfo.profession

            if ownerProfession
               and primaryOrderByProfession[ownerProfession] == displayProfOrder
            then
                slotProfession = ownerProfession
            end

            AddUniqueSlot(
                slots,
                seen,
                slot,
                "primary",
                slotProfession,
                (displayProfOrder - 1) * 3 + 1,
                displayProfOrder,
                1,
                profInfo.name
            )
        end
    end
end

local function AddFallbackProfessionSlots(slots, seen)
    if C_TradeSkillUI and C_TradeSkillUI.GetProfessionInventorySlots then
        local ok, invSlots = pcall(C_TradeSkillUI.GetProfessionInventorySlots)
        if ok and type(invSlots) == "table" then
            for _, value in ipairs(invSlots) do
                AddUniqueSlot(slots, seen, ExtractSlotNumber(value), "fallback")
            end
        end
    end

    AddUniqueSlot(slots, seen, _G.INVSLOT_PROFESSION_TOOL, "fallback")
    AddUniqueSlot(slots, seen, _G.INVSLOT_PROFESSION_GEAR_1, "fallback")
    AddUniqueSlot(slots, seen, _G.INVSLOT_PROFESSION_GEAR_2, "fallback")
    AddUniqueSlot(slots, seen, _G.INVSLOT_PROFESSION_GEAR1, "fallback")
    AddUniqueSlot(slots, seen, _G.INVSLOT_PROFESSION_GEAR2, "fallback")

    for slot = 0, 39 do
        if not seen[slot] then
            local itemID = GetInventoryItemID("player", slot)
            if itemID then
                local _, _, _, equipLoc = GetItemInstantInfo(itemID)
                if PROFESSION_EQUIP_LOCS[equipLoc] then
                    AddUniqueSlot(slots, seen, slot, "fallback")
                end
            end
        end
    end
end

local function GetProfessionEquipmentSlots()
    local slots = {}
    local seen = {}

    AddPrimaryProfessionSlots(slots, seen)

    if #slots == 0 then
        AddFallbackProfessionSlots(slots, seen)
    end

    table.sort(slots, function(a, b)
        local aIndex = tonumber(a.displayIndex) or 999
        local bIndex = tonumber(b.displayIndex) or 999

        if aIndex ~= bIndex then
            return aIndex < bIndex
        end

        return (tonumber(a.slot) or 0) < (tonumber(b.slot) or 0)
    end)

    return slots
end

local function GetProfessionSkillLineForGear(itemInfo, slot, knownProfession)
    local skillLine
    local profession = tonumber(knownProfession)

    if C_TradeSkillUI and C_TradeSkillUI.GetSkillLineForGear and itemInfo then
        local ok, value = pcall(C_TradeSkillUI.GetSkillLineForGear, itemInfo)
        if ok then
            skillLine = tonumber(value)
        end
    end

    if skillLine and not profession then
        local professionFromSkillLine = GetProfessionEnumForSkillLine(skillLine)
        if professionFromSkillLine then
            profession = professionFromSkillLine
        end
    end

    if not skillLine
       and profession
       and C_TradeSkillUI
       and C_TradeSkillUI.GetProfessionSkillLineID
    then
        local ok, value = pcall(C_TradeSkillUI.GetProfessionSkillLineID, profession)
        if ok then
            skillLine = tonumber(value)
        end
    end

    return skillLine, profession
end

local function SkillLineMatchesMap(skillLine, map)
    skillLine = tonumber(skillLine)
    if not skillLine then
        return false
    end

    if map[skillLine] then
        return true
    end

    local aliases = {}
    AddSkillLineAliases(skillLine, aliases)

    for alias in pairs(aliases) do
        if map[alias] then
            return true
        end
    end

    return false
end

local function IsPrimaryProfessionGear(itemInfo, slot, knownProfession, slotSource)
    local skillLine, profession = GetProfessionSkillLineForGear(itemInfo, slot, knownProfession)
    profession = tonumber(profession)

    local primarySkillLines, primaryProfessions, secondarySkillLines, secondaryProfessions, hasPrimary =
        GetProfessionGearFilterMaps()

    if profession and secondaryProfessions[profession] then
        return false, skillLine, profession
    end

    if skillLine and SkillLineMatchesMap(skillLine, secondarySkillLines) then
        return false, skillLine, profession
    end

    if profession and primaryProfessions[profession] then
        return true, skillLine, profession
    end

    if skillLine and SkillLineMatchesMap(skillLine, primarySkillLines) then
        return true, skillLine, profession
    end

    if slotSource == "primary" then
        return true, skillLine, profession or tonumber(knownProfession)
    end

    if not hasPrimary then
        return false, skillLine, profession
    end

    return false, skillLine, profession
end

local function IsSavedProfessionGearItemValid(item)
    if type(item) ~= "table" then
        return false
    end

    local profession = tonumber(item.profession)
    local skillLine = tonumber(item.skillLine)

    local primarySkillLines, primaryProfessions, secondarySkillLines, secondaryProfessions =
        GetProfessionGearFilterMaps()

    if profession and secondaryProfessions[profession] then
        return false
    end

    if skillLine and SkillLineMatchesMap(skillLine, secondarySkillLines) then
        return false
    end

    if item.slotSource == "primary" then
        return true
    end

    if profession and primaryProfessions[profession] then
        return true
    end

    if skillLine and SkillLineMatchesMap(skillLine, primarySkillLines) then
        return true
    end

    return false
end

local function FilterSavedProfessionGearItems(items, snap)
    if type(items) ~= "table" then
        return nil
    end

    if not snap or snap.version ~= PROF_EQUIP_FILTER_VERSION then
        return nil
    end

    local result = {}

    for _, item in ipairs(items) do
        if IsSavedProfessionGearItemValid(item) then
            table.insert(result, item)
        end
    end

    return next(result) and result or nil
end

local function GetProfessionNameForGear(skillLine, profession)
    skillLine = tonumber(skillLine)
    profession = tonumber(profession)

    if not skillLine
       and profession
       and C_TradeSkillUI
       and C_TradeSkillUI.GetProfessionSkillLineID
    then
        local ok, value = pcall(C_TradeSkillUI.GetProfessionSkillLineID, profession)
        if ok then
            skillLine = tonumber(value)
        end
    end

    if skillLine
       and C_TradeSkillUI
       and C_TradeSkillUI.GetProfessionInfoBySkillLineID
    then
        local ok, info = pcall(C_TradeSkillUI.GetProfessionInfoBySkillLineID, skillLine)
        if ok and type(info) == "table" and info.name then
            return tostring(info.name)
        end
    end

    return nil
end

local function GetEquippedProfessionGear_Live()
    if InCombatLockdown() then
        return nil
    end

    local items = {}

    for _, slotInfo in ipairs(GetProfessionEquipmentSlots()) do
        local slot = tonumber(slotInfo.slot or slotInfo)
        local itemID = slot and GetInventoryItemID("player", slot)
        local link = slot and GetInventoryItemLink("player", slot)

        if slot and (itemID or link) then
            local itemInfo = link or itemID
            local _, _, _, equipLoc, instantIcon = GetItemInstantInfo(itemInfo)

            if PROFESSION_EQUIP_LOCS[equipLoc] then
                local icon = GetInventoryItemTexture("player", slot) or instantIcon
                local isPrimaryGear, skillLine, profession = IsPrimaryProfessionGear(
                    itemInfo,
                    slot,
                    slotInfo.profession,
                    slotInfo.source
                )

                if isPrimaryGear then
                    local itemQuality = select(3, GetItemInfo(itemInfo))

                    local resolvedProfession = tonumber(slotInfo.profession) or profession
                    local professionName = slotInfo.professionName
                        or GetProfessionNameForGear(skillLine, resolvedProfession)
                    local displayProfOrder

                    if slotInfo.source == "primary" and tonumber(slotInfo.profOrder) then
                        displayProfOrder = tonumber(slotInfo.profOrder)
                    else
                        displayProfOrder = GetDisplayProfOrderForGear(
                            skillLine,
                            resolvedProfession,
                            slotInfo.profOrder
                        )
                    end

                    local slotOrder = tonumber(slotInfo.slotOrder)
                    local displayIndex = tonumber(slotInfo.displayIndex)

                    if displayProfOrder and slotOrder then
                        displayIndex = (displayProfOrder - 1) * 3 + slotOrder
                    end

                    table.insert(items, {
                        slot           = slot,
                        itemID         = tonumber(itemID),
                        link           = link,
                        name           = GetItemNameSafe(itemID, link) or "",
                        icon           = tonumber(icon),
                        equipLoc       = equipLoc,
                        itemQuality    = tonumber(itemQuality),
                        craftedQuality = GetCraftedQualitySafe(itemInfo),
                        skillLine      = skillLine,
                        profession     = resolvedProfession,
                        professionName = professionName,
                        slotSource     = slotInfo.source,
                        displayIndex   = displayIndex,
                        profOrder      = displayProfOrder or tonumber(slotInfo.profOrder),
                        slotOrder      = slotOrder,
                    })
                end
            end
        end
    end

    table.sort(items, function(a, b)
        local aIndex = tonumber(a.displayIndex) or 999
        local bIndex = tonumber(b.displayIndex) or 999

        if aIndex ~= bIndex then
            return aIndex < bIndex
        end

        local aProf = tonumber(a.profession) or 0
        local bProf = tonumber(b.profession) or 0
        if aProf ~= bProf then
            return aProf < bProf
        end

        local aSkill = tonumber(a.skillLine) or 0
        local bSkill = tonumber(b.skillLine) or 0
        if aSkill ~= bSkill then
            return aSkill < bSkill
        end

        local aSlot = tonumber(a.slot) or 0
        local bSlot = tonumber(b.slot) or 0
        if aSlot ~= bSlot then
            return aSlot < bSlot
        end

        return (a.name or "") < (b.name or "")
    end)

    return next(items) and items or nil
end

function D:SaveCurrentCharacterSnapshot()
    if not IsSafeEnvironment() then
        return
    end

    local charKey = GetCurrentCharKey()
    if not charKey then
        return
    end

    local now = time()
    local weekKey = GetServerWeekKey()
    local dayKey = GetServerDayKey()

    local db = EnsureDB()
    local entry = db[charKey] or {}
    db[charKey] = entry

    entry.updated = now
    local _, classFile = UnitClass("player")
    if classFile then entry.class = classFile end
    entry.concentration = entry.concentration or {}
    entry.dundun = entry.dundun or {}

    do
        local profGear = GetEquippedProfessionGear_Live()
        if type(profGear) == "table" and next(profGear) then
            entry.profEquip = {
                updated = now,
                version = PROF_EQUIP_FILTER_VERSION,
                items   = profGear,
            }
        else
            entry.profEquip = nil
        end
    end

    for _, exp in ipairs({ "df", "tww", "mid" }) do
        local data = GetPlayerConcentrationByProfession(exp)

        if type(data) ~= "table" or not next(data) then
            entry.concentration[exp] = nil
        else
            entry.concentration[exp] = entry.concentration[exp] or {
                updated = now,
                profs = {}
            }

            local snap = entry.concentration[exp]
            snap.updated = now
            snap.profs = snap.profs or {}

            for skillLine, info in pairs(data) do
                if type(skillLine) == "number" then
                    local key = tonumber(skillLine)
                    if key then
                        local prev = snap.profs[key]

                        snap.profs[key] = {
                            value       = tonumber(info.value),
                            name        = tostring(info.name or ""),
                            icon        = tonumber(info.icon),
                            hadCurrency = true,
                            lastUpdate  = prev and prev.lastUpdate or now,
                        }
                    end
                end
            end
        end
    end

    do
        local data = GetPlayerZealByProfession()
        if type(data) ~= "table" or not next(data) then
            entry.zeal = nil
        else
            entry.zeal = entry.zeal or { profs = {} }
            entry.zeal.updated = now
            entry.zeal.profs = {}
            for skillLine, info in pairs(data) do
                local key = tonumber(skillLine)
                if key then
                    entry.zeal.profs[key] = {
                        value = tonumber(info.value) or 0,
                        name  = tostring(info.name or ""),
                        icon  = tonumber(info.icon),
                    }
                end
            end
        end
    end

    entry.kp = entry.kp or {}

    for _, exp in ipairs({ "df", "tww", "mid" }) do
        local ok, value = pcall(PT.GetRemainingKPByExpansion, exp)
        if ok and type(value) == "number" then
            entry.kp[exp] = {
                value   = value,
                updated = now,
                weekKey = weekKey,
            }
        end
    end

    entry.kpByProf = entry.kpByProf or {}

    for _, exp in ipairs({ "df", "tww", "mid" }) do
        local data = PT.GetRemainingKPByProfession(exp)

        if type(data) == "table" then
            local safe = {}

            for k, v in pairs(data) do
                if type(k) == "number" then
                    safe[tonumber(k)] = v
                end
            end

            entry.kpByProf[exp] = {
                updated = now,
                weekKey = weekKey,
                profs   = safe,
            }
        else
            entry.kpByProf[exp] = nil
        end
    end

    local dundunValue = GetPlayerDundunWeekly_Live()

    entry.dundun = entry.dundun or {}

    if entry.dundun.weekKey ~= weekKey then
        entry.dundun.weekKey = weekKey
        entry.dundun.value = 0
        entry.dundun.max = DUNDUN_WEEKLY_MAX
        entry.dundun.updated = now
    end

    if type(dundunValue) == "table" then
        entry.dundun.value = tonumber(dundunValue.value) or 0
        entry.dundun.quantity = tonumber(dundunValue.quantity) or 0
        entry.dundun.max = tonumber(dundunValue.max) or DUNDUN_WEEKLY_MAX
        entry.dundun.updated = now
    end

    entry.weekly = entry.weekly or {}

    for _, exp in ipairs({ "df", "tww", "mid" }) do
        local prev = entry.weekly[exp]

        if not prev or prev.weekKey ~= weekKey then
            local liveProfs = GetLearnedProfessions_Live(exp) or {}
            local safeProfs = {}

            for k, v in pairs(liveProfs) do
                if type(k) == "number" then
                    safeProfs[tonumber(k)] = {
                        name = tostring(v.name or ""),
                        icon = tonumber(v.icon),
                    }
                end
            end

            entry.weekly[exp] = {
                updated = now,
                weekKey = weekKey,
                completedQuests = GetCompletedWeeklyQuests_Live(exp),
                profs = safeProfs,
            }
        else
            prev.completedQuests = prev.completedQuests or {}

            local live = GetCompletedWeeklyQuests_Live(exp)
            for qid, done in pairs(live) do
                if done then
                    prev.completedQuests[qid] = true
                end
            end

            local liveProfs = GetLearnedProfessions_Live(exp) or {}
            local safeProfs = {}

            for k, v in pairs(liveProfs) do
                if type(k) == "number" then
                    safeProfs[tonumber(k)] = {
                        name = tostring(v.name or ""),
                        icon = tonumber(v.icon),
                    }
                end
            end

            prev.profs = safeProfs
            prev.updated = now
        end
    end

    if PT.SkinningCheck and PT.SkinningCheck:IsAvailable() then
        local done, total = PT.SkinningCheck:GetProgress()
        if done and total then
            local prevSnap = entry.skinning

            if prevSnap and prevSnap.dayKey ~= dayKey then
                done = 0
            elseif prevSnap and prevSnap.dayKey == dayKey then
                done = math.max(done or 0, prevSnap.done or 0)
            end

            entry.skinning = {
                done    = done,
                total   = total,
                updated = now,
                dayKey  = dayKey,
            }
        else
            entry.skinning = nil
        end
    else
        entry.skinning = nil
    end

    do
        local liveDMF, darkmoonMonthKey = GetDarkmoonProfessions_Live()
        if darkmoonMonthKey then
            entry.darkmoon = {
                updated  = now,
                monthKey = darkmoonMonthKey,
                profs    = {},
            }

            if type(liveDMF) == "table" then
                for skillLine, info in pairs(liveDMF) do
                    if type(skillLine) == "number" then
                        entry.darkmoon.profs[tonumber(skillLine)] = {
                            name    = tostring(info.name or ""),
                            icon    = tonumber(info.icon),
                            questID = tonumber(info.questID),
                            done    = info.done == true,
                        }
                    end
                end
            end
        end
    end

    local twKey = GetActiveTimewalking()
    if twKey and D.TIMEWALKING[twKey] then
        entry.timewalking = entry.timewalking or {}

        local done = false
        for _, q in ipairs(D.TIMEWALKING[twKey].quests) do
            if C_QuestLog.IsQuestFlaggedCompleted(q) then
                done = true
                break
            end
        end

        entry.timewalking[twKey] = {
            done    = done,
            updated = now,
        }
    end
end

function D:SaveCurrentCharacterSkinningSnapshot()
    if not IsSafeEnvironment() then
        return
    end

    local charKey = GetCurrentCharKey()
    if not charKey then
        return
    end

    local db = EnsureDB()
    local entry = db[charKey] or {}
    db[charKey] = entry
    entry.updated = time()

    SaveSkinningSnapshotForEntry(entry)
end

function D:GetProfessionEquipment(charKey)
    if not charKey then
        return nil
    end

    local current = GetCurrentCharKey()
    if charKey == current and not InCombatLockdown() then
        return GetEquippedProfessionGear_Live()
    end

    local db = EnsureDB()
    local entry = db[charKey]
    local snap = entry and entry.profEquip

    if snap and type(snap.items) == "table" and next(snap.items) then
        local filtered = FilterSavedProfessionGearItems(snap.items, snap)

        if filtered then
            snap.items = filtered
            return filtered
        end

        entry.profEquip = nil
    end

    return nil
end

function D:GetRemainingKP(charKey, expansion)
    if not charKey or not expansion then
        return nil
    end

    local current = GetCurrentCharKey()

    if charKey == current then
        local ok, value = pcall(PT.GetRemainingKPByExpansion, expansion)
        if ok then
            return value
        end
        return nil
    end

    local db = EnsureDB()
    local entry = db[charKey]
    if not entry or not entry.kp then
        return nil
    end

    local snap = entry.kp[expansion]
    if not snap then
        return nil
    end

    if snap.weekKey ~= GetServerWeekKey() then
        return nil
    end

    return snap.value
end

function D:GetKPByProfession(charKey, expansion)
    if not charKey or not expansion then
        return nil
    end

    local current = GetCurrentCharKey()

    if charKey == current then
        return PT.GetRemainingKPByProfession(expansion)
    end

    local db = EnsureDB()
    local entry = db[charKey]
    if not entry or not entry.kpByProf then
        return nil
    end

    local snap = entry.kpByProf[expansion]
    if not snap then
        return nil
    end

    if snap.weekKey ~= GetServerWeekKey() then
        return nil
    end

    return snap
end

function D:GetWeeklyStatus(charKey, expansion)
    if not charKey or not expansion then
        return nil
    end

	local db = PT.DB and (PT.DB[expansion] or PT.DB[expansion:upper()])
	if type(db) ~= "table" then
		return nil
	end

    local current = GetCurrentCharKey()
    local completed = {}

    if charKey == current then
        completed = GetCompletedWeeklyQuests_Live(expansion)
    else
        local chars = EnsureDB()
        local snap = chars[charKey]
            and chars[charKey].weekly
            and chars[charKey].weekly[expansion]

        if snap then
			if snap.weekKey ~= GetServerWeekKey() then
				snap.weekKey = GetServerWeekKey()
				snap.completedQuests = {}
				snap.profs = {}
			end
            completed = snap.completedQuests or {}
        end
    end

	local learned = {}

	if charKey == current then
		learned = GetLearnedProfessions_Live(expansion) or {}
	else
		local chars = EnsureDB()
		local snap = chars[charKey]
			and chars[charKey].weekly
			and chars[charKey].weekly[expansion]

		learned = (snap and snap.profs) or {}
	end

    local result = {}

	for profId, meta in pairs(learned or {}) do
		local prof = db[profId]
		if prof then
			local function isQuestDone(qid)
				if charKey == current then
					return C_QuestLog.IsQuestFlaggedCompleted(qid)
				end
				return completed and completed[qid] == true
			end

			result[profId] = {
				name   = meta.name or prof.name,
				icon   = meta.icon or prof.icon,
				weekly = BuildWeeklyStatusForProfession(prof, isQuestDone),
			}
		end
	end

    return next(result) and result or nil
end

function D:GetSkinningProgress(charKey)
    if not charKey then return nil end

    local current = GetCurrentCharKey()

    if charKey == current then
        if PT.SkinningCheck then
            local db = EnsureDB()
            local entry = db[charKey]
            local snap = entry and entry.skinning
            local liveDone, liveTotal = PT.SkinningCheck:GetProgress()
            local todayKey = GetServerDayKey()

            if snap and snap.dayKey ~= todayKey then
                if liveTotal then
                    return 0, liveTotal
                end
                return 0, snap.total
            end

            if snap and snap.dayKey == todayKey then
                if liveDone and liveTotal then
                    return math.max(liveDone or 0, snap.done or 0), liveTotal
                end
                return snap.done, snap.total
            end

            return liveDone, liveTotal
        end
        return nil
    end

    local db = EnsureDB()
    local entry = db[charKey]
    local snap = entry and entry.skinning

    if not snap then
        return nil
    end

    if snap.dayKey ~= GetServerDayKey() then
        snap.dayKey = GetServerDayKey()
        snap.done = 0
    end

    return snap.done, snap.total
end

function D:GetZeal(charKey)
    if not charKey then return nil end

    local current = GetCurrentCharKey()
    if charKey == current and not InCombatLockdown() then
        local live = GetPlayerZealByProfession()
        if live then return live end
    end

    local db = EnsureDB()
    local entry = db[charKey]
    if not entry or not entry.zeal or type(entry.zeal.profs) ~= "table" then
        return nil
    end

    local result = {}
    for skillLine, info in pairs(entry.zeal.profs) do
        result[skillLine] = {
            value = info.value,
            name  = info.name,
            icon  = info.icon,
        }
    end

    return next(result) and result or nil
end

function D:GetConcentration(charKey, expansion)
    if not charKey or not expansion then return nil end

    local current = GetCurrentCharKey()

	if charKey == current and not InCombatLockdown() then
		local live = GetPlayerConcentrationByProfession(expansion)
		if live then
			return live
		end
	end

    local db = EnsureDB()
    local entry = db[charKey]
	
    if not entry or not entry.concentration then
        return nil
    end

    local snap = entry.concentration[expansion]
	
    if type(snap) ~= "table" then
        return nil
    end

    if not snap.updated then
        return nil
    end

    local result = {}
    for skillLine, info in pairs(snap.profs) do
		local v = info.value

		if info.hadCurrency
		   and type(v) == "number"
		   and v > 0
		   and type(info.lastUpdate) == "number"
		then
			local newValue, newUpdate = ApplyConcentrationRegen(v, info.lastUpdate)

            v = newValue
            info.lastUpdate = newUpdate
            info.value = newValue
		end
        result[skillLine] = {
            value = v,
            name  = info.name,
            icon  = info.icon,
        }
    end

    return next(result) and result or nil
end

function D:GetDundunWeekly(charKey)
    if not charKey then
        return nil
    end

    local current = GetCurrentCharKey()
    local weekKey = GetServerWeekKey()

    if charKey == current then
        local live = GetPlayerDundunWeekly_Live()
        if type(live) == "table" then
            return live
        end
    end

    local db = EnsureDB()
    local entry = db[charKey]
    local snap = entry and entry.dundun

    if not snap then
        return nil
    end

    if snap.weekKey ~= weekKey then
        snap.weekKey = weekKey
        snap.value = 0
        snap.max = DUNDUN_WEEKLY_MAX
        snap.updated = time()
    end

    return {
        value    = tonumber(snap.value) or 0,
        quantity = tonumber(snap.quantity) or 0,
        max      = tonumber(snap.max) or DUNDUN_WEEKLY_MAX,
    }
end

function D:GetDarkmoonStatus(charKey)
    if not charKey then
        return nil
    end

    local active = GetActiveDarkmoonInfo()
    if not active or not active.monthKey then
        return nil
    end

    local current = GetCurrentCharKey()

    if charKey == current then
        local live = GetDarkmoonProfessions_Live()
        return live
    end

    local db = EnsureDB()
    local entry = db[charKey]
    local snap = entry and entry.darkmoon

    if not snap or snap.monthKey ~= active.monthKey then
        return nil
    end

    local result = {}
    for skillLine, info in pairs(snap.profs or {}) do
        local key = tonumber(skillLine) or skillLine
        result[key] = {
            name    = info.name,
            icon    = info.icon,
            questID = info.questID,
            done    = info.done == true,
        }
    end

    return next(result) and result or nil
end

function D:GetTimewalkingStatus(charKey)
    local twKey = GetActiveTimewalking()
    if not twKey then
        return nil
    end

    local info = D.TIMEWALKING[twKey]
    if not info then
        return nil
    end

    local current = GetCurrentCharKey()
    local done = false

    if charKey == current then

        for _, q in ipairs(info.quests) do
            if C_QuestLog.IsQuestFlaggedCompleted(q) then
                done = true
                break
            end
        end
    else

        local db = EnsureDB()
        local entry = db[charKey]

        done = entry
            and entry.timewalking
            and entry.timewalking[twKey]
            and entry.timewalking[twKey].done
            or false
    end

    return {
        key  = twKey,
		atlas = info.atlas,
        done = done,
    }
end

function D:ResetAll()
    if HironCraftProfit_DB and HironCraftProfit_DB.accountOverview then
        HironCraftProfit_DB.accountOverview = {
            chars = {}
        }
    end

    if PT.AccountOverview and PT.AccountOverview.Refresh then
        PT.AccountOverview:Refresh()
    end
end

local pendingFullConc = {}
D.pendingFullConc = pendingFullConc
local notifiedFullConc = {}
D.notifiedFullConc = notifiedFullConc

function D:CheckFullConcentration(charKey)
    if not charKey then return end

    notifiedFullConc[charKey] = notifiedFullConc[charKey] or {}

    for _, exp in ipairs({ "df", "tww", "mid" }) do
            local data = self:GetConcentration(charKey, exp)

            if type(data) == "table" then
                notifiedFullConc[charKey][exp] =
                    notifiedFullConc[charKey][exp] or {}

				for skillLine, info in pairs(data) do
					local profKey = tostring(skillLine)
                    local wasNotified =
                        notifiedFullConc[charKey][exp][profKey]

                    if info.value
                       and info.value >= CONCENTRATION_NOTIFY_THRESHOLD
                       and not wasNotified
                       and D:IsConcentrationProfEnabled(charKey, exp, skillLine)
                    then
                        pendingFullConc[charKey] =
                            pendingFullConc[charKey] or {}

                        table.insert(pendingFullConc[charKey], {
                            charKey   = charKey,
                            exp       = exp,
                            value     = info.value,
                            name      = info.name,
                            icon      = info.icon,
                            skillLine = skillLine,
                        })

                        notifiedFullConc[charKey][exp][profKey] = true
                    end

                    if info.value
                       and info.value < CONCENTRATION_NOTIFY_THRESHOLD
                    then
                        notifiedFullConc[charKey][exp][profKey] = nil
                    end
                end
            end
    end
end

D._lastDayKey  = D._lastDayKey  or GetServerDayKey()
D._lastWeekKey = D._lastWeekKey or GetServerWeekKey()

function D:HandleResetBoundary()
    local newDayKey  = GetServerDayKey()
    local newWeekKey = GetServerWeekKey()

    local dayChanged  = (self._lastDayKey  ~= newDayKey)
    local weekChanged = (self._lastWeekKey ~= newWeekKey)

    if not dayChanged and not weekChanged then
        return false
    end

    self._lastDayKey  = newDayKey
    self._lastWeekKey = newWeekKey

    local chars = EnsureDB()

    for _, entry in pairs(chars) do
        if type(entry) == "table" then
            if dayChanged and entry.skinning then
                entry.skinning.dayKey = newDayKey
                entry.skinning.done = 0
                entry.skinning.updated = time()
            end

            if weekChanged then
                if entry.dundun then
                    entry.dundun.weekKey = newWeekKey
                    entry.dundun.value = 0
                    entry.dundun.max = DUNDUN_WEEKLY_MAX
                    entry.dundun.updated = time()
                end

                if entry.kp then
                    for _, snap in pairs(entry.kp) do
                        if type(snap) == "table" then
                            snap.weekKey = newWeekKey
                            snap.updated = time()
                        end
                    end
                end

                if entry.kpByProf then
                    for _, snap in pairs(entry.kpByProf) do
                        if type(snap) == "table" then
                            snap.weekKey = newWeekKey
                            snap.updated = time()
                        end
                    end
                end

                if entry.weekly then
                    for _, snap in pairs(entry.weekly) do
                        if type(snap) == "table" then
                            snap.weekKey = newWeekKey
                            snap.completedQuests = {}
                            snap.profs = {}
                            snap.updated = time()
                        end
                    end
                end
            end
        end
    end

    if IsSafeEnvironment() then
        self:SaveCurrentCharacterSnapshot()
    end

    if PT.AccountOverview and PT.AccountOverview.Refresh then
        PT.AccountOverview:Refresh()
    end

    return true
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:RegisterEvent("QUEST_TURNED_IN")
ev:RegisterEvent("SKILL_LINES_CHANGED")   
ev:RegisterEvent("TRADE_SKILL_SHOW")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:RegisterEvent("UNIT_INVENTORY_CHANGED")
ev:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_INVENTORY_CHANGED" and unit ~= "player" then
        return
    end

	if event == "PLAYER_LOGIN" then
        CleanupInvalidCharacterKeys()
        NormalizeCharacterKeys()
        CleanupLegacyConcentrationData()
        D:GetColumnFilters()

        D._lastDayKey  = GetServerDayKey()
        D._lastWeekKey = GetServerWeekKey()

        HironCraftProfit_Config = HironCraftProfit_Config or {}
        local profs = HironCraftProfit_Config.concNotifyProfs

        if type(profs) == "table" then
            for charKey, data in pairs(profs) do

                local isOld = false
                for k, v in pairs(data) do
                    if type(v) == "boolean" then
                        isOld = true
                        break
                    end
                end

                if isOld then
                    local new = {}

                    new.df = {}

                    for skillLine, enabled in pairs(data) do
                        if enabled == true then
                            new.df[tostring(skillLine)] = true
                        end
                    end

                    profs[charKey] = new
                end
            end
        end
	end
	if IsSafeEnvironment() then
		D:SaveCurrentCharacterSnapshot()
	end

	local chars = HironCraftProfit_DB
		and HironCraftProfit_DB.accountOverview
		and HironCraftProfit_DB.accountOverview.chars

	if chars then
		for charKey in pairs(chars) do
			D:CheckFullConcentration(charKey)
		end

        if PT.AccountOverview_UI and next(D.pendingFullConc) then
            PT.AccountOverview_UI:ShowConcentrationNotification()
        end
	end

    if event ~= "PLAYER_LOGOUT"
       and PT.AccountOverview
       and PT.AccountOverview.Refresh
    then
        PT.AccountOverview:Refresh()
    end
end)

if not D._concTicker then
	D._concTicker = C_Timer.NewTicker(CONCENTRATION_REGEN_SEC, function()
        if not IsSafeEnvironment() then
            return
        end

		local chars = HironCraftProfit_DB
			and HironCraftProfit_DB.accountOverview
			and HironCraftProfit_DB.accountOverview.chars

		if not chars then return end

		for charKey in pairs(chars) do
			D:CheckFullConcentration(charKey)
		end

        if PT.AccountOverview_UI and next(D.pendingFullConc) then
            PT.AccountOverview_UI:ShowConcentrationNotification()
        end
	end)
end

if not D._resetTicker then
    D._resetTicker = C_Timer.NewTicker(30, function()
        if not IsSafeEnvironment() then
            return
        end

        D:HandleResetBoundary()
    end)
end

function D:Reset()
    if HironCraftProfit_DB and HironCraftProfit_DB.accountOverview then
        wipe(HironCraftProfit_DB.accountOverview)
    end
end

local DEFAULT_COLUMN_FILTERS = {
    profgear = true,

    c_df    = true,
    c_tww   = true,
    c_mid   = true,

    kp_df   = true,
    kp_tww  = true,
    kp_mid  = true,

    skin    = true,
    dundun  = true,
    dmf     = true,
    tw      = true,
}

function D:GetColumnFilters()
    HironCraftProfit_Config = HironCraftProfit_Config or {}
    HironCraftProfit_Config.accountOverviewCols =
        HironCraftProfit_Config.accountOverviewCols or {}

    local filters = HironCraftProfit_Config.accountOverviewCols

    for key, def in pairs(DEFAULT_COLUMN_FILTERS) do
        if filters[key] == nil then
            filters[key] = def
        end
    end

    return filters
end

function D:GetConcentrationNotifyConfig()
    HironCraftProfit_Config = HironCraftProfit_Config or {}
    HironCraftProfit_Config.concNotifyProfs = HironCraftProfit_Config.concNotifyProfs or {}
    return HironCraftProfit_Config.concNotifyProfs
end

function D:IsConcentrationProfEnabled(charKey, expansion, skillLine)
    local profs = HironCraftProfit_Config and HironCraftProfit_Config.concNotifyProfs
    if not profs or not charKey or not expansion then
        return false
    end

    local charProfs = profs[charKey]
    if not charProfs then return false end

    local expProfs = charProfs[expansion]
    if not expProfs then return false end

    return expProfs[tostring(skillLine)] == true
end

function D:SetConcentrationProfEnabled(charKey, expansion, skillLine, enabled)
    HironCraftProfit_Config = HironCraftProfit_Config or {}
    HironCraftProfit_Config.concNotifyProfs = HironCraftProfit_Config.concNotifyProfs or {}

    HironCraftProfit_Config.concNotifyProfs[charKey] =
        HironCraftProfit_Config.concNotifyProfs[charKey] or {}

    HironCraftProfit_Config.concNotifyProfs[charKey][expansion] =
        HironCraftProfit_Config.concNotifyProfs[charKey][expansion] or {}

    if enabled then
        HironCraftProfit_Config.concNotifyProfs[charKey][expansion][tostring(skillLine)] = true
    else
        HironCraftProfit_Config.concNotifyProfs[charKey][expansion][tostring(skillLine)] = nil
    end
end

SLASH_HIRONCRAFT_PROFITCONC1 = "/ahuiconc"
SlashCmdList["HIRONCRAFT_PROFITCONC"] = function()
    local name = UnitName("player")
    local realm = GetNormalizedRealmName()
    if not name or not realm then return end

    local charKey = name .. "-" .. realm

	pendingFullConc[charKey] = {
		{
			charKey = charKey,
			exp     = "df",
			value   = 1000,
			name    = "Debug Profession",
			icon    = 136240,
		}
	}
end

SLASH_HIRONCRAFT_PROFITDUNDUN1 = "/dundun"
SlashCmdList["HIRONCRAFT_PROFITDUNDUN"] = function()
    local i = C_CurrencyInfo.GetCurrencyInfo(3376)
    if not i then
        print("No currency info")
        return
    end

    print("quantity:", i.quantity)
    print("totalEarned:", i.totalEarned)
    print("quantityEarnedThisWeek:", i.quantityEarnedThisWeek)
    print("totalEarnedThisWeek:", i.totalEarnedThisWeek)
    print("maxWeeklyQuantity:", i.maxWeeklyQuantity)
    print("earnedThisWeek:", i.earnedThisWeek)
end