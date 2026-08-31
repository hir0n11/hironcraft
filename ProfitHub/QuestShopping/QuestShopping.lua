local PT = HironCraftProfit
if not PT then return end

PT.QuestShopping = PT.QuestShopping or {}
local M = PT.QuestShopping

local L = PT.L or {}
local BUTTON_SIZE = 20
local BUTTON_FRAME_STRATA = "MEDIUM"
local BUTTON_FRAME_LEVEL_OFFSET = 8
local UPDATE_DELAY = 0.12
local MAX_REQUIRED_ITEMS = 12
local SOURCE_KIND = "quest_shopping"

M.buttons = M.buttons or {}
M.questData = M.questData or {}
M.allMaterials = M.allMaterials or {}
M.debug = M.debug == true
M.lastDebugDump = M.lastDebugDump or 0

local function T(key, default)
    return L[key] or default or key
end

local function GetBlacklist()
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB.questShopping = HironCraftProfit_DB.questShopping or {}
    HironCraftProfit_DB.questShopping.blacklist = HironCraftProfit_DB.questShopping.blacklist or {}
    return HironCraftProfit_DB.questShopping.blacklist
end

local function GetBlacklistNames()
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB.questShopping = HironCraftProfit_DB.questShopping or {}
    HironCraftProfit_DB.questShopping.blacklistNames = HironCraftProfit_DB.questShopping.blacklistNames or {}
    return HironCraftProfit_DB.questShopping.blacklistNames
end

function M:IsQuestBlacklisted(questID)
    questID = tonumber(questID)
    if not questID then return false end
    return GetBlacklist()[questID] == true
end

function M:BlacklistQuest(questID)
    questID = tonumber(questID)
    if not questID then return end
    GetBlacklist()[questID] = true
    local title = self:GetQuestTitle(questID)
    if title and not title:match("^#%d+$") then
        GetBlacklistNames()[questID] = title
    end
    if self.questData then
        self.questData[questID] = nil
    end
    if self.ScheduleVisualRefresh then
        self:ScheduleVisualRefresh()
    end
end

function M:UnblacklistQuest(questID)
    questID = tonumber(questID)
    if not questID then return end
    GetBlacklist()[questID] = nil
    GetBlacklistNames()[questID] = nil
    if self.ScheduleDataUpdate then
        self:ScheduleDataUpdate()
    end
end

function M:GetBlacklistedQuestIDs()
    local out = {}
    for questID, hidden in pairs(GetBlacklist()) do
        if hidden then
            out[#out + 1] = tonumber(questID) or questID
        end
    end
    table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
    return out
end

function M:ClearBlacklist()
    local bl = GetBlacklist()
    for questID in pairs(bl) do
        bl[questID] = nil
    end
    wipe(GetBlacklistNames())
    if self.ScheduleDataUpdate then
        self:ScheduleDataUpdate()
    end
end

local function GetSavedQuests()
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB.questShopping = HironCraftProfit_DB.questShopping or {}
    HironCraftProfit_DB.questShopping.saved = HironCraftProfit_DB.questShopping.saved or {}
    return HironCraftProfit_DB.questShopping.saved
end

local function GetSavedQuestNames()
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB.questShopping = HironCraftProfit_DB.questShopping or {}
    HironCraftProfit_DB.questShopping.savedNames = HironCraftProfit_DB.questShopping.savedNames or {}
    return HironCraftProfit_DB.questShopping.savedNames
end

function M:IsQuestSaved(questID)
    questID = tonumber(questID)
    if not questID then return false end
    return GetSavedQuests()[questID] == true
end

function M:SaveQuest(questID)
    questID = tonumber(questID)
    if not questID then return end
    if GetSavedQuests()[questID] then return end
    GetSavedQuests()[questID] = true
    local title = self:GetQuestTitle(questID)
    if title and not title:match("^#%d+$") then
        GetSavedQuestNames()[questID] = title
    end
    GetBlacklist()[questID] = nil
    GetBlacklistNames()[questID] = nil
    print("|cffb19cd9HironCraft|r " .. string.format(T("QS_QUEST_SAVED", "quest cart enabled: %s"), title or ("#" .. tostring(questID))))
    if self.ScheduleDataUpdate then
        self:ScheduleDataUpdate(0.1)
    end
end

function M:UnsaveQuest(questID)
    questID = tonumber(questID)
    if not questID then return end
    if not GetSavedQuests()[questID] then return end
    local title = GetSavedQuestNames()[questID] or self:GetQuestTitle(questID)
    GetSavedQuests()[questID] = nil
    GetSavedQuestNames()[questID] = nil
    if self.questData then
        self.questData[questID] = nil
    end
    print("|cffb19cd9HironCraft|r " .. string.format(T("QS_QUEST_UNSAVED", "quest cart removed: %s"), title or ("#" .. tostring(questID))))
    if self.ScheduleDataUpdate then
        self:ScheduleDataUpdate(0.1)
    end
end

function M:GetSavedQuestIDs()
    local out = {}
    for questID, saved in pairs(GetSavedQuests()) do
        if saved then
            out[#out + 1] = tonumber(questID) or questID
        end
    end
    table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
    return out
end

function M:GetSavedQuestTitle(questID)
    questID = tonumber(questID)
    if not questID then return nil end
    return GetSavedQuestNames()[questID]
end

function M:ClearSavedQuests()
    local saved = GetSavedQuests()
    for questID in pairs(saved) do
        saved[questID] = nil
    end
    wipe(GetSavedQuestNames())
    if self.ScheduleDataUpdate then
        self:ScheduleDataUpdate()
    end
end

local function IsUtf8ContinuationByte(byteValue)
    return byteValue and byteValue >= 0x80 and byteValue <= 0xBF
end

local function IsValidUTF8(text)
    if type(text) ~= "string" then return true end

    if string.utf8len then
        local ok = pcall(string.utf8len, text)
        if ok then return true end
        return false
    end

    local i = 1
    local len = #text
    while i <= len do
        local c1 = text:byte(i)
        if not c1 then
            return true
        elseif c1 < 0x80 then
            i = i + 1
        elseif c1 >= 0xC2 and c1 <= 0xDF then
            if i + 1 > len or not IsUtf8ContinuationByte(text:byte(i + 1)) then return false end
            i = i + 2
        elseif c1 >= 0xE0 and c1 <= 0xEF then
            local c2, c3 = text:byte(i + 1), text:byte(i + 2)
            if i + 2 > len or not IsUtf8ContinuationByte(c2) or not IsUtf8ContinuationByte(c3) then return false end
            if c1 == 0xE0 and c2 < 0xA0 then return false end
            if c1 == 0xED and c2 > 0x9F then return false end
            i = i + 3
        elseif c1 >= 0xF0 and c1 <= 0xF4 then
            local c2, c3, c4 = text:byte(i + 1), text:byte(i + 2), text:byte(i + 3)
            if i + 3 > len or not IsUtf8ContinuationByte(c2) or not IsUtf8ContinuationByte(c3) or not IsUtf8ContinuationByte(c4) then return false end
            if c1 == 0xF0 and c2 < 0x90 then return false end
            if c1 == 0xF4 and c2 > 0x8F then return false end
            i = i + 4
        else
            return false
        end
    end

    return true
end

local function SanitizeUTF8(value)
    if value == nil then return "" end

    local text = tostring(value)
    if text == "" or IsValidUTF8(text) then
        return text
    end

    local out = {}
    local i = 1
    local len = #text

    while i <= len do
        local c1 = text:byte(i)
        if not c1 then
            break
        elseif c1 < 0x80 then
            out[#out + 1] = text:sub(i, i)
            i = i + 1
        elseif c1 >= 0xC2 and c1 <= 0xDF then
            local c2 = text:byte(i + 1)
            if i + 1 <= len and IsUtf8ContinuationByte(c2) then
                out[#out + 1] = text:sub(i, i + 1)
                i = i + 2
            else
                out[#out + 1] = "?"
                i = i + 1
            end
        elseif c1 >= 0xE0 and c1 <= 0xEF then
            local c2, c3 = text:byte(i + 1), text:byte(i + 2)
            local ok = i + 2 <= len and IsUtf8ContinuationByte(c2) and IsUtf8ContinuationByte(c3)
            ok = ok and not (c1 == 0xE0 and c2 < 0xA0)
            ok = ok and not (c1 == 0xED and c2 > 0x9F)
            if ok then
                out[#out + 1] = text:sub(i, i + 2)
                i = i + 3
            else
                out[#out + 1] = "?"
                i = i + 1
            end
        elseif c1 >= 0xF0 and c1 <= 0xF4 then
            local c2, c3, c4 = text:byte(i + 1), text:byte(i + 2), text:byte(i + 3)
            local ok = i + 3 <= len and IsUtf8ContinuationByte(c2) and IsUtf8ContinuationByte(c3) and IsUtf8ContinuationByte(c4)
            ok = ok and not (c1 == 0xF0 and c2 < 0x90)
            ok = ok and not (c1 == 0xF4 and c2 > 0x8F)
            if ok then
                out[#out + 1] = text:sub(i, i + 3)
                i = i + 4
            else
                out[#out + 1] = "?"
                i = i + 1
            end
        else
            out[#out + 1] = "?"
            i = i + 1
        end
    end

    return table.concat(out)
end

local function PrintStatus(text)
    text = SanitizeUTF8(text)
    if DEFAULT_CHAT_FRAME and text ~= "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffb19cd9HironCraft|r " .. text)
    end
end

local function DebugLine(text, force)
    if not force and not M.debug then return end
    text = SanitizeUTF8(text)
    if DEFAULT_CHAT_FRAME and text ~= "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffb19cd9HironCraft QS DBG:|r " .. text)
    end
end

local function DebugValue(value)
    if value == nil then return "nil" end
    if value == true then return "true" end
    if value == false then return "false" end
    return SanitizeUTF8(value)
end

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

local function RequestItemData(itemID)
    itemID = tonumber(itemID)
    if not itemID then return end

    if C_Item and C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    end
end

local _itemInfoCache = {}
local _itemInfoCacheOrder = {}
local _ITEM_CACHE_MAX = 300

local function GetItemInfoSafe(itemID)
    if _itemInfoCache[itemID] ~= nil then
        return _itemInfoCache[itemID] or nil  
    end

    local fn = C_Item and C_Item.GetItemInfo or GetItemInfo
    if type(fn) ~= "function" then return nil end

    local ok, name, link, quality, itemLevel, minLevel, itemType, itemSubType, stackCount, equipLoc, icon, sellPrice, classID, subClassID, bindType = pcall(fn, itemID)
    if not ok then return nil end

    if not name then
        return nil
    end

    if #_itemInfoCacheOrder >= _ITEM_CACHE_MAX then
        local oldest = table.remove(_itemInfoCacheOrder, 1)
        _itemInfoCache[oldest] = nil
    end

    local info = {
        name = name,
        link = link,
        quality = quality,
        itemLevel = itemLevel,
        minLevel = minLevel,
        itemType = itemType,
        itemSubType = itemSubType,
        stackCount = stackCount,
        equipLoc = equipLoc,
        icon = icon,
        sellPrice = sellPrice,
        classID = classID,
        subClassID = subClassID,
        bindType = bindType,
    }
    _itemInfoCache[itemID] = info
    _itemInfoCacheOrder[#_itemInfoCacheOrder + 1] = itemID
    return info
end

local function InvalidateItemInfoCache(itemID)
    if itemID then
        if _itemInfoCache[itemID] ~= nil then
            _itemInfoCache[itemID] = nil
            for i = #_itemInfoCacheOrder, 1, -1 do
                if _itemInfoCacheOrder[i] == itemID then
                    table.remove(_itemInfoCacheOrder, i)
                    break
                end
            end
        end
    else
        _itemInfoCache = {}
        _itemInfoCacheOrder = {}
    end
end

local function ExtractItemID(link)
    if type(link) == "number" then
        return link
    end
    if type(link) ~= "string" then
        return nil
    end

    return tonumber(link:match("item:(%d+)"))
end

local function LowerText(text)
    text = SanitizeUTF8(text)
    if string.utf8lower then
        local ok, lowered = pcall(string.utf8lower, text)
        if ok and lowered then
            return lowered
        end
    end
    return string.lower(text)
end

local function StripTextureCodes(text)
    text = SanitizeUTF8(text)
    text = text:gsub("|T.-|t", "")
    text = text:gsub("|A.-|a", "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    return text
end

local function ObjectiveTextMatchesItem(text, itemName)
    text = StripTextureCodes(text)
    itemName = StripTextureCodes(itemName)
    if text == "" or itemName == "" then return false end

    return LowerText(text):find(LowerText(itemName), 1, true) ~= nil
end

local function ParseObjectiveCount(text)
    text = StripTextureCodes(text)
    local fulfilled, required = text:match("(%d+)%s*/%s*(%d+)")
    fulfilled = tonumber(fulfilled)
    required = tonumber(required)

    if fulfilled and required then
        return fulfilled, required
    end

    return nil, nil
end

local function IsObjectiveItemType(objectiveType)
    objectiveType = LowerText(objectiveType or "")
    return objectiveType:find("item", 1, true) ~= nil
end

local function TrimText(text)
    text = SanitizeUTF8(text)
    text = text:gsub("\194\160", " ")
    text = text:gsub("%s+", " ")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    return text
end

local function ParseObjectiveItemName(text)
    text = TrimText(StripTextureCodes(text))
    if text == "" then return nil end

    text = text:gsub("^[-–—•]+%s*", "")

    text = text:gsub("%s*[:：]?%s*%d+%s*/%s*%d+%s*$", "")
    text = text:gsub("^%s*%d+%s*/%s*%d+%s*", "")
    text = text:gsub("%s*[:：]%s*$", "")
    text = text:gsub("%s*[%?？]+%s*$", "")
    text = TrimText(text)

    if text == "" or text:match("^%d+$") then
        return nil
    end

    return text
end

local function GetQuestLogIndex(questID)
    questID = tonumber(questID)
    if not questID then return nil end

    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local ok, index = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
        if ok and tonumber(index) then
            return tonumber(index)
        end
    end

    local total = nil
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        local ok, n = pcall(C_QuestLog.GetNumQuestLogEntries)
        if ok then total = tonumber(n) end
    end
    if not total and GetNumQuestLogEntries then
        local ok, n = pcall(GetNumQuestLogEntries)
        if ok then total = tonumber(n) end
    end
    total = total or 0

    for i = 1, total do
        local id = nil
        if C_QuestLog and C_QuestLog.GetQuestIDForLogIndex then
            local ok, value = pcall(C_QuestLog.GetQuestIDForLogIndex, i)
            if ok then id = tonumber(value) end
        end

        if not id and GetQuestLogTitle then
            local ok, _, _, _, _, _, _, _, value = pcall(GetQuestLogTitle, i)
            if ok then id = tonumber(value) end
        end

        if id == questID then
            return i
        end
    end

    return nil
end

local function GetQuestTitle(questID)
    questID = tonumber(questID)
    if not questID then return "?" end

    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local ok, title = pcall(C_QuestLog.GetTitleForQuestID, questID)
        if ok and title and title ~= "" then
            return title
        end
    end

    if C_QuestLog and C_QuestLog.GetQuestInfo then
        local ok, info = pcall(C_QuestLog.GetQuestInfo, questID)
        if ok and type(info) == "table" and info.title and info.title ~= "" then
            return info.title
        end
    end

    local index = GetQuestLogIndex(questID)
    if index and GetQuestLogTitle then
        local ok, title = pcall(GetQuestLogTitle, index)
        if ok and title and title ~= "" then
            return title
        end
    end

    if C_TaskQuest and C_TaskQuest.GetQuestInfoByQuestID then
        local ok, title = pcall(C_TaskQuest.GetQuestInfoByQuestID, questID)
        if ok and title and title ~= "" then
            return title
        end
    end

    return "#" .. tostring(questID)
end

function M:GetQuestTitle(questID)
    local title = GetQuestTitle(questID)
    if not title or title == "" or title:match("^#%d+$") then
        local cached = GetBlacklistNames()[tonumber(questID) or questID]
        if cached and cached ~= "" then
            return cached
        end
    end
    return title
end

local function WithSelectedQuest(questID, callback)
    if type(callback) ~= "function" then return end

    local oldQuestID = nil
    local oldIndex = nil

    if C_QuestLog and C_QuestLog.GetSelectedQuest then
        local ok, value = pcall(C_QuestLog.GetSelectedQuest)
        if ok then oldQuestID = value end
    end
    if GetQuestLogSelection then
        local ok, value = pcall(GetQuestLogSelection)
        if ok then oldIndex = value end
    end

    local selected = false
    if C_QuestLog and C_QuestLog.SetSelectedQuest then
        local ok = pcall(C_QuestLog.SetSelectedQuest, questID)
        selected = ok == true
    end

    if not selected and SelectQuestLogEntry then
        local index = GetQuestLogIndex(questID)
        if index then
            local ok = pcall(SelectQuestLogEntry, index)
            selected = ok == true
        end
    end

    if not selected then
        return
    end

    callback()

    if oldQuestID and C_QuestLog and C_QuestLog.SetSelectedQuest then
        pcall(C_QuestLog.SetSelectedQuest, oldQuestID)
    elseif oldIndex and SelectQuestLogEntry then
        pcall(SelectQuestLogEntry, oldIndex)
    end
end

local function CallQuestLogItemLink(kind, index, questID)
    if type(_G.GetQuestLogItemLink) == "function" then
        local ok, v = pcall(_G.GetQuestLogItemLink, kind, index, questID)
        if ok and v then return v, "GetQuestLogItemLink(kind,index,questID)" end
        ok, v = pcall(_G.GetQuestLogItemLink, kind, index)
        if ok and v then return v, "GetQuestLogItemLink(kind,index)" end
    end
    if type(_G.GetQuestItemLink) == "function" then
        local ok, v = pcall(_G.GetQuestItemLink, kind, index)
        if ok and v then return v, "GetQuestItemLink(kind,index)" end
    end
    return nil, nil
end

local function CallQuestItemInfo(kind, index, questID)
    local function tryFn(fn, ...)
        if type(fn) ~= "function" then return end
        local ok, name, texture, count, quality, isUsable, itemID, itemLevel = pcall(fn, ...)
        if ok and (name or itemID or count or texture) then
            return name, texture, count, quality, isUsable, itemID, itemLevel
        end
    end
    local name, texture, count, quality, isUsable, itemID, itemLevel
    name, texture, count, quality, isUsable, itemID, itemLevel = tryFn(_G.GetQuestLogItemInfo, kind, index, questID)
    if not name and not itemID then
        name, texture, count, quality, isUsable, itemID, itemLevel = tryFn(_G.GetQuestLogItemInfo, kind, index)
    end
    if not name and not itemID then
        name, texture, count, quality, isUsable, itemID, itemLevel = tryFn(_G.GetQuestItemInfo, kind, index)
    end
    if name or itemID or count or texture then
        return {
            name = name,
            texture = texture,
            count = tonumber(count),
            quality = quality,
            isUsable = isUsable,
            itemID = tonumber(itemID),
            itemLevel = itemLevel,
        }
    end
    return nil
end

local function GetNumQuestItemsSafe(kind, questID)
    if type(_G.GetNumQuestLogItems) == "function" then
        local ok, n = pcall(_G.GetNumQuestLogItems, kind, questID)
        if ok and tonumber(n) then return tonumber(n), "GetNumQuestLogItems(kind,questID)" end
        ok, n = pcall(_G.GetNumQuestLogItems, kind)
        if ok and tonumber(n) then return tonumber(n), "GetNumQuestLogItems(kind)" end
    end
    if type(_G.GetNumQuestItems) == "function" then
        local ok, n = pcall(_G.GetNumQuestItems, kind, questID)
        if ok and tonumber(n) then return tonumber(n), "GetNumQuestItems(kind,questID)" end
        ok, n = pcall(_G.GetNumQuestItems, kind)
        if ok and tonumber(n) then return tonumber(n), "GetNumQuestItems(kind)" end
    end
    return nil, nil
end

local function ReadRequiredItemsFromSelectedQuest(questID)
    local out = {}
    local knownCount, countMethod = GetNumQuestItemsSafe("required", questID)
    local scanMax = math.max(tonumber(knownCount) or 0, MAX_REQUIRED_ITEMS)

    for i = 1, scanMax do
        local link, linkMethod = CallQuestLogItemLink("required", i, questID)
        local info = CallQuestItemInfo("required", i, questID)
        local itemID = ExtractItemID(link) or (info and info.itemID)

        local hasRealItemID = itemID and tonumber(itemID) and tonumber(itemID) > 0
        local hasName = info and info.name and info.name ~= ""
        if link or hasRealItemID or hasName then
            local itemInfo = hasRealItemID and GetItemInfoSafe(itemID) or nil
            table.insert(out, {
                source = "required",
                index = i,
                itemID = hasRealItemID and itemID or nil,
                link = link,
                name = (info and info.name) or (itemInfo and itemInfo.name),
                count = info and info.count,
                countMethod = countMethod,
                linkMethod = linkMethod,
                infoMethod = info and info.method,
            })
        elseif knownCount and i >= knownCount then
            break
        end
    end

    return out, knownCount, countMethod
end

local _requiredItemsCache = {}

local function ReadRequiredItemsForQuest(questID)
    if _requiredItemsCache[questID] then
        return _requiredItemsCache[questID]
    end
    local out = {}
    WithSelectedQuest(questID, function()
        out = ReadRequiredItemsFromSelectedQuest(questID)
    end)
    _requiredItemsCache[questID] = out
    return out
end

local _materialsCache = {}
local _itemToQuests = {}

local function InvalidateMaterialsCache(questID)
    if questID then
        _materialsCache[questID] = nil
    else
        wipe(_materialsCache)
        wipe(_itemToQuests)
    end
end

local function RegisterItemQuestMapping(itemID, questID)
    itemID = tonumber(itemID)
    if not itemID or not questID then return end
    if not _itemToQuests[itemID] then
        _itemToQuests[itemID] = {}
    end
    _itemToQuests[itemID][questID] = true
end

local function InvalidateMaterialsCacheForItem(itemID)
    itemID = tonumber(itemID)
    if not itemID then return end
    local quests = _itemToQuests[itemID]
    if quests then
        for questID in pairs(quests) do
            _materialsCache[questID] = nil
        end
    end
end

local function ReadRequiredItemsForQuestDebug(questID)
    local out = {}
    local knownCount = nil
    local countMethod = nil

    WithSelectedQuest(questID, function()
        out, knownCount, countMethod = ReadRequiredItemsFromSelectedQuest(questID)
    end)

    return out, knownCount, countMethod
end

local _objectivesCache = {}

local function GetCachedObjectives(questID)
    if _objectivesCache[questID] ~= nil then
        return _objectivesCache[questID]
    end
    if not C_QuestLog or not C_QuestLog.GetQuestObjectives then
        _objectivesCache[questID] = false
        return false
    end
    local ok, objectives = pcall(C_QuestLog.GetQuestObjectives, questID)
    local result = (ok and type(objectives) == "table") and objectives or false
    _objectivesCache[questID] = result
    return result
end

local function ReadObjectiveItemIDs(questID)
    local out = {}
    local objectives = GetCachedObjectives(questID)
    if not objectives then
        return out
    end

    for index, objective in ipairs(objectives) do
        if type(objective) == "table" then
            local objectiveType = objective.type or objective.objectiveType
            local isItemObjective = IsObjectiveItemType(objectiveType)
            local itemID = tonumber(objective.itemID or objective.itemId)

            if not itemID and isItemObjective then
                itemID = tonumber(objective.objectID)
            end

            local text = objective.text or ""
            local fulfilled = tonumber(objective.numFulfilled)
            local required = tonumber(objective.numRequired)

            if (not fulfilled or not required) and text ~= "" then
                local f, r = ParseObjectiveCount(text)
                fulfilled = fulfilled or f
                required = required or r
            end

            local name = objective.itemName
            if (not name or name == "") and isItemObjective then
                name = ParseObjectiveItemName(text)
            end

            if itemID or (isItemObjective and name and name ~= "" and required and required > 0) then
                table.insert(out, {
                    source = itemID and "objective" or "objective_name",
                    index = index,
                    itemID = itemID,
                    name = name,
                    count = required,
                    fulfilled = fulfilled,
                    text = text,
                    objectiveType = objectiveType,
                    nameOnly = itemID == nil,
                })
            end
        end
    end

    return out
end

local function GetObjectiveCountsForItem(questID, itemID, itemName)
    local objectives = GetCachedObjectives(questID)
    if not objectives then
        return nil, nil
    end

    local fallbackFulfilled, fallbackRequired = nil, nil

    for _, objective in ipairs(objectives) do
        if type(objective) == "table" then
            local text = objective.text or ""
            local objItemID = tonumber(objective.itemID or objective.itemId or objective.objectID)
            local fulfilled = tonumber(objective.numFulfilled)
            local required = tonumber(objective.numRequired)

            if (not fulfilled or not required) and text ~= "" then
                local f, r = ParseObjectiveCount(text)
                fulfilled = fulfilled or f
                required = required or r
            end

            local matched = false
            if objItemID and tonumber(itemID) and objItemID == tonumber(itemID) then
                matched = true
            elseif itemName and itemName ~= "" and ObjectiveTextMatchesItem(text, itemName) then
                matched = true
            end

            local objectiveType = LowerText(objective.type or objective.objectiveType or "")
            if not fallbackRequired and objectiveType:find("item", 1, true) then
                fallbackFulfilled = fulfilled
                fallbackRequired = required
            end

            if matched then
                return fulfilled, required
            end
        end
    end

    return fallbackFulfilled, fallbackRequired
end

local function IsAuctionableQuestItem(itemID)
    local info = GetItemInfoSafe(itemID)
    if not info or not info.name then
        RequestItemData(itemID)
        return false, "loading", info
    end

    local bindType = tonumber(info.bindType) or 0
    if bindType ~= 0 and bindType ~= 2 and bindType ~= 3 then
        return false, "bound", info
    end

    local questItemClass = Enum and Enum.ItemClass and Enum.ItemClass.Questitem or 12
    if tonumber(info.classID) == questItemClass then
        return false, "quest_item", info
    end

    if C_AuctionHouse and C_AuctionHouse.MakeItemKey then
        local ok, key = pcall(C_AuctionHouse.MakeItemKey, tonumber(itemID))
        if not ok or not key then
            return false, "no_auction_key", info
        end
    end

    return true, nil, info
end

local function ResolveCachedItemByExactName(itemName)
    itemName = TrimText(itemName or "")
    if itemName == "" then
        return nil, "empty_name"
    end

    local info = GetItemInfoSafe(itemName)
    if not info or not info.name or not info.link then
        return nil, "unresolved_name"
    end

    if LowerText(info.name) ~= LowerText(itemName) then
        return nil, "name_mismatch"
    end

    local itemID = ExtractItemID(info.link)
    if not itemID then
        return nil, "no_item_id_from_name"
    end

    info.itemID = itemID
    return info, nil
end

local LOOT_WINDOW = 3.0  
local _recentLoot = {}   

local function PruneRecentLoot()
    local now = GetTime()
    local kept = {}
    for _, entry in ipairs(_recentLoot) do
        if now - entry.ts <= LOOT_WINDOW then
            kept[#kept + 1] = entry
        end
    end
    _recentLoot = kept
end

local function RecordRecentLoot(itemID)
    itemID = tonumber(itemID)
    if not itemID then return end
    PruneRecentLoot()
    _recentLoot[#_recentLoot + 1] = { itemID = itemID, ts = GetTime() }
end

local function GetMostRecentLootItemID()
    PruneRecentLoot()
    local last = _recentLoot[#_recentLoot]
    return last and last.itemID or nil
end

local function GetQuestItemMap()
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB.questItemMap = HironCraftProfit_DB.questItemMap or {}
    return HironCraftProfit_DB.questItemMap
end

local function GetMappedItemID(questID, objIndex)
    questID = tonumber(questID)
    objIndex = tonumber(objIndex)
    if not questID or not objIndex then return nil end
    local map = GetQuestItemMap()
    local quest = map[questID]
    if type(quest) ~= "table" then return nil end
    return tonumber(quest[objIndex])
end

local function SetMappedItemID(questID, objIndex, itemID)
    questID = tonumber(questID)
    objIndex = tonumber(objIndex)
    itemID = tonumber(itemID)
    if not questID or not objIndex or not itemID then return end
    local map = GetQuestItemMap()
    map[questID] = map[questID] or {}
    map[questID][objIndex] = itemID
end

local _prevFulfilled = {}

local function SnapshotQuestFulfilled(questID, objectives)
    if not questID or type(objectives) ~= "table" then return end
    _prevFulfilled[questID] = _prevFulfilled[questID] or {}
    for idx, obj in ipairs(objectives) do
        _prevFulfilled[questID][idx] = tonumber(obj.numFulfilled) or 0
    end
end

local function GetPlayerItemCount(itemID)
    if not itemID or not GetItemCount then return 0 end
    local ok, count = pcall(GetItemCount, itemID, true)
    if ok then return tonumber(count) or 0 end
    return 0
end

local function GetMaterialMergeKey(itemID, label)
    itemID = tonumber(itemID)
    if itemID then
        return "i:" .. tostring(itemID)
    end

    label = TrimText(StripTextureCodes(label or ""))
    if label == "" then
        return nil
    end

    return "n:" .. LowerText(label)
end

local function AddMaterial(materials, byItemID, itemID, quantity, label)
    itemID = tonumber(itemID)
    quantity = tonumber(quantity) or 0
    label = TrimText(label or "")

    if quantity <= 0 then return end
    if not itemID and label == "" then return end

    local key = GetMaterialMergeKey(itemID, label)
    if not key then return end

    local existing = byItemID[key]
    if existing then
        existing.quantity = (tonumber(existing.quantity) or 0) + quantity
        return
    end

    local info = itemID and GetItemInfoSafe(itemID) or nil
    local name = label ~= "" and label or (info and info.name) or (itemID and GetItemInfo and GetItemInfo(itemID)) or (itemID and ("#" .. tostring(itemID)))
    if not name or name == "" then return end

    local material = {
        itemID = itemID,
        quantity = quantity,
        label = name,
        importSearchName = name,
        importExpandGrades = true,
        auctionatorIsExact = true,
    }

    if not itemID then
        material.unresolvedName = name
        material.importName = name
    end

    table.insert(materials, material)
    byItemID[key] = material
end

function M:IsEnabled()
    return PT and PT.config and PT.config.questShoppingEnabled == true
end

local _trackedCache = nil
local _trackedDirty = true   

local function BuildTrackedQuestIDs()
    local out = {}
    local seen = {}

    local function add(questID)
        questID = tonumber(questID)
        if questID and questID > 0 and not seen[questID] then
            seen[questID] = true
            table.insert(out, questID)
        end
    end

    if C_QuestLog and C_QuestLog.GetNumQuestWatches and C_QuestLog.GetQuestIDForQuestWatchIndex then
        local ok, n = pcall(C_QuestLog.GetNumQuestWatches)
        n = ok and tonumber(n) or 0
        for i = 1, n do
            local okID, questID = pcall(C_QuestLog.GetQuestIDForQuestWatchIndex, i)
            if okID then add(questID) end
        end
    end

    if #out == 0 and GetNumQuestWatches and GetQuestIndexForWatch then
        local ok, n = pcall(GetNumQuestWatches)
        n = ok and tonumber(n) or 0
        for i = 1, n do
            local okIndex, questIndex = pcall(GetQuestIndexForWatch, i)
            if okIndex and questIndex then
                local questID = nil
                if C_QuestLog and C_QuestLog.GetQuestIDForLogIndex then
                    local okID, value = pcall(C_QuestLog.GetQuestIDForLogIndex, questIndex)
                    if okID then questID = value end
                end
                if not questID and GetQuestLogTitle then
                    local okTitle, _, _, _, _, _, _, _, value = pcall(GetQuestLogTitle, questIndex)
                    if okTitle then questID = value end
                end
                add(questID)
            end
        end
    end

    local total = nil
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        local ok, n = pcall(C_QuestLog.GetNumQuestLogEntries)
        if ok then total = tonumber(n) end
    end
    if not total and GetNumQuestLogEntries then
        local ok, n = pcall(GetNumQuestLogEntries)
        if ok then total = tonumber(n) end
    end
    total = total or 0

    for i = 1, total do
        local questID = nil
        local isHeader = false

        if C_QuestLog and C_QuestLog.GetInfo then
            local ok, info = pcall(C_QuestLog.GetInfo, i)
            if ok and type(info) == "table" then
                questID = tonumber(info.questID)
                isHeader = info.isHeader == true
            end
        end

        if not questID and C_QuestLog and C_QuestLog.GetQuestIDForLogIndex then
            local ok, value = pcall(C_QuestLog.GetQuestIDForLogIndex, i)
            if ok then questID = tonumber(value) end
        end

        if not isHeader and questID then
            local watched = false
            if C_QuestLog and C_QuestLog.GetQuestWatchType then
                local ok, watchType = pcall(C_QuestLog.GetQuestWatchType, questID)
                watched = ok and watchType ~= nil
            elseif IsQuestWatched then
                local ok, value = pcall(IsQuestWatched, i)
                watched = ok and value == true
            end

            if watched then
                add(questID)
            end
        end
    end

    return out
end

function M:GetTrackedQuestIDs()
    if not _trackedDirty and _trackedCache then
        return _trackedCache
    end
    _trackedCache = BuildTrackedQuestIDs()
    _trackedDirty = false
    return _trackedCache
end

function M:InvalidateTrackedCache()
    _trackedDirty = true
    _trackedCache = nil
end

local function CollectKnowledgeDbReqs(itemRequirements, out)
    if type(itemRequirements) ~= "table" then return end

    local hasVariant = false
    for _, option in ipairs(itemRequirements) do
        if type(option) == "table" and not option.id and option[1] and type(option[1]) == "table" then
            hasVariant = true
            break
        end
    end

    local function addReq(req)
        if type(req) ~= "table" then return end
        local id = tonumber(req.id)
        local qty = tonumber(req.quantity) or 0
        if id and qty > 0 then
            out[id] = (out[id] or 0) + qty
        end
    end

    if hasVariant then
        local option = itemRequirements[1]
        if type(option) == "table" then
            if option.id then addReq(option) else
                for _, req in ipairs(option) do addReq(req) end
            end
        end
    else
        for _, req in ipairs(itemRequirements) do addReq(req) end
    end
end

local function ReadKnowledgeDbMaterials(questID)
    if type(PT.FindEntryByQuestId) ~= "function" then return nil end
    local entry = PT.FindEntryByQuestId(tonumber(questID))
    if not entry or not entry.IsDarkmoonQuest then return nil end

    local materials = {}
    if entry.itemRequirements then
        local needById = {}
        CollectKnowledgeDbReqs(entry.itemRequirements, needById)

        local byItemID = {}
        for itemID, qty in pairs(needById) do
            RegisterItemQuestMapping(itemID, questID)
            local ok, reason = IsAuctionableQuestItem(itemID)
            if reason == "loading" then
                M.waitingItemData = true
            end
            if ok then
                local missing = qty - GetPlayerItemCount(itemID)
                if missing > 0 then
                    AddMaterial(materials, byItemID, itemID, missing, nil)
                end
            end
        end
    end

    return materials
end

local function IsDarkmoonQuestID(questID)
    if type(PT.FindEntryByQuestId) ~= "function" then return false end
    local entry = PT.FindEntryByQuestId(tonumber(questID))
    return entry ~= nil and entry.IsDarkmoonQuest == true
end

local function CandidateMergeName(item)
    local name = item.name or item.itemName
    if (not name or name == "") and item.text then
        name = ParseObjectiveItemName(item.text)
    end
    name = TrimText(StripTextureCodes(name or ""))
    if name == "" then return nil end
    return LowerText(name)
end

function M:GetQuestMaterials(questID, debugRows)
    if not debugRows and _materialsCache[questID] then
        return _materialsCache[questID]
    end

    local kpMaterials = ReadKnowledgeDbMaterials(questID)
    if kpMaterials then
        if debugRows then
            debugRows.source = "knowledge_db"
            debugRows.materialCount = #kpMaterials
            debugRows.materials = {}
            for _, material in ipairs(kpMaterials) do
                table.insert(debugRows.materials, {
                    itemID = material.itemID,
                    quantity = material.quantity,
                    label = material.label,
                })
            end
        else
            _materialsCache[questID] = kpMaterials
            for _, mat in ipairs(kpMaterials) do
                if mat.itemID then
                    RegisterItemQuestMapping(mat.itemID, questID)
                end
            end
        end
        return kpMaterials
    end

    local candidates = {}
    for _, item in ipairs(ReadRequiredItemsForQuest(questID)) do
        candidates[#candidates + 1] = item
    end
    local objectiveItems = ReadObjectiveItemIDs(questID)

    for _, item in ipairs(objectiveItems) do
        local exists = false
        local itemName = CandidateMergeName(item)
        for _, existing in ipairs(candidates) do
            local sameID = tonumber(existing.itemID) and tonumber(item.itemID)
                and tonumber(existing.itemID) == tonumber(item.itemID)
            local sameName = itemName and itemName == CandidateMergeName(existing)
            if sameID or sameName then
                exists = true
                if not existing.itemID and item.itemID then existing.itemID = item.itemID end
                if not existing.count and item.count then existing.count = item.count end
                if not existing.fulfilled and item.fulfilled then existing.fulfilled = item.fulfilled end
                if not existing.name and item.name then existing.name = item.name end
                if not existing.text and item.text then existing.text = item.text end
                break
            end
        end
        if not exists then
            table.insert(candidates, item)
        end
    end

    local materials = {}
    local byItemID = {}
    local pendingItemIDs = {}

    if debugRows then
        debugRows.candidateCount = #candidates
        debugRows.objectiveItemCount = #objectiveItems
        debugRows.items = debugRows.items or {}
    end

    for _, item in ipairs(candidates) do
        local itemID = tonumber(item.itemID)
        local row = nil
        if debugRows then
            row = {
                source = item.source or "unknown",
                index = item.index,
                text = item.text,
                itemID = itemID,
                rawName = item.name,
                rawCount = item.count,
                rawFulfilled = item.fulfilled,
                objectiveType = item.objectiveType,
            }
            table.insert(debugRows.items, row)
        end

        if not itemID then
            local itemName = item.name or item.unresolvedName or ParseObjectiveItemName(item.text)
            local fulfilled = tonumber(item.fulfilled)
            local required = tonumber(item.count)

            if (not fulfilled or not required) and item.text then
                local f, r = ParseObjectiveCount(item.text)
                fulfilled = fulfilled or f
                required = required or r
            end

            if itemName and itemName ~= "" and required and required > 0 then
                local resolvedInfo, resolveReason = ResolveCachedItemByExactName(itemName)
                local resolvedItemID = resolvedInfo and tonumber(resolvedInfo.itemID) or nil

                if row then
                    row.name = itemName
                    row.fulfilled = fulfilled
                    row.required = required
                    row.infoName = resolvedInfo and resolvedInfo.name
                    row.itemID = resolvedItemID
                end

                if not resolvedItemID then
                    if item.index then
                        resolvedItemID = GetMappedItemID(questID, item.index)
                    end
                end

                if not resolvedItemID then
                    local missing = required - math.max(tonumber(fulfilled) or 0, 0)
                    if row then
                        row.have = nil
                        row.missing = missing
                        row.auctionable = nil
                        row.reason = resolveReason or "unresolved_no_loot_map"
                    end
                    if missing and missing > 0 then
                        AddMaterial(materials, byItemID, nil, missing, itemName)
                        if row then row.result = "added_name_only" end
                    elseif row then
                        row.result = "not_missing"
                    end
                else
                    pendingItemIDs[resolvedItemID] = true
                    local ok, reason, itemInfo = IsAuctionableQuestItem(resolvedItemID)
                    if reason == "loading" then
                        self.waitingItemData = true
                    end

                    if row then
                        row.classID = itemInfo and itemInfo.classID
                        row.subClassID = itemInfo and itemInfo.subClassID
                        row.bindType = itemInfo and itemInfo.bindType
                        row.auctionable = ok == true
                        row.reason = reason or "auctionable_resolved_from_name"
                    end

                    if ok then
                        local have = GetPlayerItemCount(resolvedItemID)
                        local missing = required - math.max(tonumber(fulfilled) or 0, 0)

                        if row then
                            row.have = have
                            row.missing = missing
                        end

                        if missing and missing > 0 then
                            AddMaterial(materials, byItemID, resolvedItemID, missing, itemName)
                            if row then row.result = "added_resolved_name" end
                        elseif row then
                            row.result = "not_missing"
                            row.reason = "not_missing"
                        end
                    elseif row then
                        row.result = "skipped"
                    end
                end
            elseif row then
                row.result = "skipped"
                row.reason = itemName and "no_required_count" or "no_item_id_or_name"
            end
        else
            pendingItemIDs[itemID] = true
            local ok, reason, itemInfo = IsAuctionableQuestItem(itemID)
            if reason == "loading" then
                self.waitingItemData = true
            end

            if row then
                row.infoName = itemInfo and itemInfo.name
                row.classID = itemInfo and itemInfo.classID
                row.subClassID = itemInfo and itemInfo.subClassID
                row.bindType = itemInfo and itemInfo.bindType
                row.auctionable = ok == true
                row.reason = reason or "auctionable"
            end

            if ok then
                local itemName = item.name or (itemInfo and itemInfo.name)
                local fulfilled, required = item.fulfilled, item.count
                local objFulfilled, objRequired = GetObjectiveCountsForItem(questID, itemID, itemName)
                fulfilled = tonumber(fulfilled) or tonumber(objFulfilled)
                required = tonumber(required) or tonumber(objRequired)

                local have = GetPlayerItemCount(itemID)
                local missing = nil

                if required and required > 0 then
                    missing = required - math.max(have, tonumber(fulfilled) or 0)
                else
                    missing = 1 - have
                end

                if row then
                    row.name = itemName
                    row.fulfilled = fulfilled
                    row.required = required
                    row.have = have
                    row.missing = missing
                end

                if missing and missing > 0 then
                    AddMaterial(materials, byItemID, itemID, missing, itemName)
                    if row then row.result = "added" end
                elseif row then
                    row.result = "not_missing"
                    row.reason = "not_missing"
                end
            end
        end
    end

    if debugRows then
        debugRows.materialCount = #materials
        debugRows.materials = {}
        for _, material in ipairs(materials or {}) do
            table.insert(debugRows.materials, {
                itemID = material.itemID,
                quantity = material.quantity,
                label = material.label,
            })
        end
    end

    if not debugRows then
        _materialsCache[questID] = materials
        for _, mat in ipairs(materials) do
            if mat.itemID then
                RegisterItemQuestMapping(mat.itemID, questID)
            end
        end
        for itemID in pairs(pendingItemIDs) do
            RegisterItemQuestMapping(itemID, questID)
        end
    end

    return materials
end

local function IsFrameObject(obj)
    return type(obj) == "table"
       and type(obj.GetObjectType) == "function"
       and type(obj.IsShown) == "function"
end

local function FrameMatchesQuest(frame, questID)
    if not IsFrameObject(frame) then return false end
    questID = tonumber(questID)
    if not questID then return false end

    local keys = {
        "questID",
        "questId",
        "id",
        "questLogIndex",
        "trackedQuestID",
        "objectiveID",
    }

    for _, key in ipairs(keys) do
        local value = tonumber(frame[key])
        if value == questID then
            return true
        end
    end

    if type(frame.GetID) == "function" then
        local ok, value = pcall(frame.GetID, frame)
        if ok and tonumber(value) == questID then
            return true
        end
    end

    return false
end

local function SearchBlockTable(tbl, questID, depth, seen)
    if type(tbl) ~= "table" or depth > 4 then return nil end
    seen = seen or {}
    if seen[tbl] then return nil end
    seen[tbl] = true

    if IsFrameObject(tbl) and FrameMatchesQuest(tbl, questID) then
        return tbl
    end

    for key, value in pairs(tbl) do
        if tonumber(key) == tonumber(questID) and IsFrameObject(value) then
            return value
        end

        if IsFrameObject(value) and FrameMatchesQuest(value, questID) then
            return value
        end
    end

    for _, value in pairs(tbl) do
        if type(value) == "table" and not IsFrameObject(value) then
            local found = SearchBlockTable(value, questID, depth + 1, seen)
            if found then return found end
        end
    end

    return nil
end

local function SearchFrameChildren(root, questID, depth, seen)
    if not IsFrameObject(root) or depth > 5 then return nil end
    seen = seen or {}
    if seen[root] then return nil end
    seen[root] = true

    if FrameMatchesQuest(root, questID) then
        return root
    end

    if type(root.GetChildren) ~= "function" then return nil end

    local children = { root:GetChildren() }
    for _, child in ipairs(children) do
        if IsFrameObject(child) then
            if FrameMatchesQuest(child, questID) then
                return child
            end

            local found = SearchFrameChildren(child, questID, depth + 1, seen)
            if found then return found end
        end
    end

    return nil
end

local _questBlockCache = {}

function M:InvalidateQuestBlockCache(questID)
    if questID then
        _questBlockCache[questID] = nil
    else
        wipe(_questBlockCache)
    end
end

function M:FindQuestBlock(questID)
    questID = tonumber(questID)
    if not questID then return nil end

    local cached = _questBlockCache[questID]
    if cached ~= nil then
        if cached and IsFrameObject(cached) and cached:IsShown() and FrameMatchesQuest(cached, questID) then
            return cached
        end
        _questBlockCache[questID] = nil
    end

    local modules = {
        _G.QuestObjectiveTracker,
        _G.CampaignQuestObjectiveTracker,
        _G.BonusObjectiveTracker,
    }

    if _G.ObjectiveTrackerFrame then
        table.insert(modules, _G.ObjectiveTrackerFrame)

        local managerModules = _G.ObjectiveTrackerFrame.MODULES or _G.ObjectiveTrackerFrame.modules
        if type(managerModules) == "table" then
            for _, module in pairs(managerModules) do
                if type(module) == "table" then
                    table.insert(modules, module)
                end
            end
        end
    end

    local seenModules = {}
    for _, module in ipairs(modules) do
        if type(module) == "table" and not seenModules[module] then
            seenModules[module] = true

            for _, key in ipairs({ "usedBlocks", "activeBlocks", "blocks", "blockTable", "questBlocks" }) do
                local block = SearchBlockTable(module[key], questID, 0, {})
                if block then
                    _questBlockCache[questID] = block
                    return block
                end
            end

            for _, key in ipairs({ "firstBlock", "lastBlock", "currentBlock", "block" }) do
                local block = module[key]
                if IsFrameObject(block) and FrameMatchesQuest(block, questID) then
                    _questBlockCache[questID] = block
                    return block
                end
            end

            local contents = module.ContentsFrame or module.contentsFrame or module.ScrollContents or module.ScrollChild
            local block = SearchFrameChildren(contents, questID, 0, {})
            if block then
                _questBlockCache[questID] = block
                return block
            end
        end
    end

    local root = _G.ObjectiveTrackerFrame
    local block = SearchFrameChildren(root, questID, 0, {})
    if block then
        _questBlockCache[questID] = block
        return block
    end

    _questBlockCache[questID] = false
    return nil
end

local function GetBlockQuestID(block)
    if not IsFrameObject(block) then return nil end
    for _, key in ipairs({ "questID", "questId", "id", "trackedQuestID" }) do
        local value = tonumber(block[key])
        if value and value > 0 then return value end
    end
    if type(block.GetID) == "function" then
        local ok, value = pcall(block.GetID, block)
        if ok and tonumber(value) and tonumber(value) > 0 then return tonumber(value) end
    end
    return nil
end

function M:HookQuestBlock(block)
    if not IsFrameObject(block) then return end

    local header = block.HeaderButton
    if not IsFrameObject(header) or type(header.HookScript) ~= "function" then
        header = (type(block.HookScript) == "function") and block or nil
    end
    if not header or header._ahuiQsHooked then return end

    header._ahuiQsHooked = true
    header._ahuiQsBlock = block

    header:HookScript("OnMouseUp", function(self, mouseButton)
        if mouseButton ~= "LeftButton" then return end
        if not IsAltKeyDown() then return end

        local qid = GetBlockQuestID(self._ahuiQsBlock) or GetBlockQuestID(self:GetParent())
        if not qid then return end

        if IsDarkmoonQuestID(qid) then
            return
        end

        if M:IsQuestSaved(qid) then
            M:UnsaveQuest(qid)
        else
            M:SaveQuest(qid)
        end
    end)
end

local function GetFrameDebugName(frame)
    if not IsFrameObject(frame) then return "nil" end

    local name = nil
    if type(frame.GetName) == "function" then
        local ok, value = pcall(frame.GetName, frame)
        if ok then name = value end
    end
    if name and name ~= "" then return name end

    local objectType = "Frame"
    if type(frame.GetObjectType) == "function" then
        local ok, value = pcall(frame.GetObjectType, frame)
        if ok and value then objectType = value end
    end

    return "<" .. tostring(objectType) .. ">"
end

local function ReadQuestObjectivesRaw(questID)
    local out = {}
    if not C_QuestLog or not C_QuestLog.GetQuestObjectives then
        return out, "C_QuestLog.GetQuestObjectives unavailable"
    end

    local ok, objectives = pcall(C_QuestLog.GetQuestObjectives, questID)
    if not ok then
        return out, "GetQuestObjectives error"
    end
    if type(objectives) ~= "table" then
        return out, "GetQuestObjectives returned " .. type(objectives)
    end

    for i, objective in ipairs(objectives) do
        if type(objective) == "table" then
            table.insert(out, {
                index = i,
                text = objective.text,
                itemID = tonumber(objective.itemID or objective.itemId or objective.objectID),
                itemName = objective.itemName,
                parsedName = IsObjectiveItemType(objective.type or objective.objectiveType) and ParseObjectiveItemName(objective.text) or nil,
                fulfilled = tonumber(objective.numFulfilled),
                required = tonumber(objective.numRequired),
                objectiveType = objective.type or objective.objectiveType,
                finished = objective.finished,
            })
        else
            table.insert(out, {
                index = i,
                text = tostring(objective),
            })
        end
    end

    return out, nil
end

local function DebugRowToLine(row)
    local name = row.name or row.infoName or row.rawName or "?"
    return string.format(
        "  item source=%s idx=%s text=%s itemID=%s name=%s classID=%s subClassID=%s bindType=%s have=%s fulfilled=%s required=%s missing=%s result=%s reason=%s",
        DebugValue(row.source),
        DebugValue(row.index),
        DebugValue(row.text),
        DebugValue(row.itemID),
        DebugValue(name),
        DebugValue(row.classID),
        DebugValue(row.subClassID),
        DebugValue(row.bindType),
        DebugValue(row.have),
        DebugValue(row.fulfilled),
        DebugValue(row.required),
        DebugValue(row.missing),
        DebugValue(row.result),
        DebugValue(row.reason)
    )
end

local function DebugRequiredItemToLine(item)
    local itemID = tonumber(item and item.itemID)
    local itemInfo = itemID and GetItemInfoSafe(itemID) or nil
    local auctionable = nil
    local reason = nil

    if itemID then
        auctionable, reason, itemInfo = IsAuctionableQuestItem(itemID)
    end

    return string.format(
        "  required #%s name=%s itemID=%s count=%s classID=%s subClassID=%s bindType=%s auctionable=%s reason=%s countMethod=%s linkMethod=%s infoMethod=%s link=%s",
        DebugValue(item and item.index),
        DebugValue((item and item.name) or (itemInfo and itemInfo.name)),
        DebugValue(itemID),
        DebugValue(item and item.count),
        DebugValue(itemInfo and itemInfo.classID),
        DebugValue(itemInfo and itemInfo.subClassID),
        DebugValue(itemInfo and itemInfo.bindType),
        DebugValue(auctionable),
        DebugValue(reason or (itemID and "auctionable" or "no_item_id")),
        DebugValue(item and item.countMethod),
        DebugValue(item and item.linkMethod),
        DebugValue(item and item.infoMethod),
        DebugValue(item and item.link)
    )
end

function M:DebugRequiredItems()
    local tracked = self:GetTrackedQuestIDs()
    DebugLine("=== QuestShopping required API ===", true)
    DebugLine("tracked=" .. tostring(#tracked), true)

    if #tracked == 0 then
        DebugLine("no tracked quests found", true)
        DebugLine("=== end ===", true)
        return
    end

    for _, questID in ipairs(tracked) do
        local title = GetQuestTitle(questID)
        local requiredItems, knownCount, countMethod = ReadRequiredItemsForQuestDebug(questID)
        DebugLine("--- questID=" .. tostring(questID) .. " title=" .. tostring(title) .. " requiredCount=" .. DebugValue(knownCount) .. " countMethod=" .. DebugValue(countMethod) .. " found=" .. tostring(#(requiredItems or {})) .. " ---", true)

        if requiredItems and #requiredItems > 0 then
            for _, item in ipairs(requiredItems) do
                DebugLine(DebugRequiredItemToLine(item), true)
            end
        else
            DebugLine("  required: none", true)
        end
    end

    DebugLine("=== end ===", true)
end

function M:DebugDump()
    local tracked = self:GetTrackedQuestIDs()
    DebugLine("=== QuestShopping dump ===", true)
    DebugLine("enabled=" .. DebugValue(self:IsEnabled()) .. " tracked=" .. tostring(#tracked) .. " buttons=" .. tostring(#(self.buttons or {})), true)

    if #tracked == 0 then
        DebugLine("no tracked quests found", true)
        return
    end

    for _, questID in ipairs(tracked) do
        local title = GetQuestTitle(questID)
        local block = self:FindQuestBlock(questID)
        local objectives, objectiveError = ReadQuestObjectivesRaw(questID)
        local rows = {}
        local materials = self:GetQuestMaterials(questID, rows)

        DebugLine("--- questID=" .. tostring(questID) .. " title=" .. tostring(title) .. " block=" .. GetFrameDebugName(block) .. " blockShown=" .. DebugValue(block and block.IsShown and block:IsShown()) .. " ---", true)

        if objectiveError then
            DebugLine("  objectives: " .. objectiveError, true)
        elseif #objectives == 0 then
            DebugLine("  objectives: none", true)
        else
            for _, objective in ipairs(objectives) do
                DebugLine(string.format(
                    "  objective #%s type=%s text=%s itemID=%s itemName=%s parsedName=%s fulfilled=%s required=%s finished=%s",
                    DebugValue(objective.index),
                    DebugValue(objective.objectiveType),
                    DebugValue(objective.text),
                    DebugValue(objective.itemID),
                    DebugValue(objective.itemName),
                    DebugValue(objective.parsedName),
                    DebugValue(objective.fulfilled),
                    DebugValue(objective.required),
                    DebugValue(objective.finished)
                ), true)
            end
        end

        local rawRequired = ReadRequiredItemsForQuest(questID)
        DebugLine("  RAW required (" .. tostring(#rawRequired) .. "):", true)
        for _, it in ipairs(rawRequired) do
            DebugLine(string.format("    src=%s name=%s itemID=%s count=%s fulfilled=%s text=%s",
                DebugValue(it.source), DebugValue(it.name), DebugValue(it.itemID),
                DebugValue(it.count), DebugValue(it.fulfilled), DebugValue(it.text)), true)
        end

        local rawObjective = ReadObjectiveItemIDs(questID)
        DebugLine("  RAW objectiveItems (" .. tostring(#rawObjective) .. "):", true)
        for _, it in ipairs(rawObjective) do
            DebugLine(string.format("    src=%s name=%s itemID=%s count=%s fulfilled=%s nameOnly=%s text=%s",
                DebugValue(it.source), DebugValue(it.name), DebugValue(it.itemID),
                DebugValue(it.count), DebugValue(it.fulfilled), DebugValue(it.nameOnly), DebugValue(it.text)), true)
        end

        DebugLine("  candidates=" .. DebugValue(rows.candidateCount) .. " objectiveItems=" .. DebugValue(rows.objectiveItemCount) .. " materials=" .. tostring(#(materials or {})), true)
        if rows.items and #rows.items > 0 then
            for _, row in ipairs(rows.items) do
                DebugLine(DebugRowToLine(row), true)
            end
        else
            DebugLine("  items: none", true)
        end

        if materials and #materials > 0 then
            for _, material in ipairs(materials) do
                DebugLine("  BUY itemID=" .. DebugValue(material.itemID) .. " label=" .. DebugValue(material.label) .. " qty=" .. DebugValue(material.quantity), true)
            end
        end
    end

    DebugLine("=== end ===", true)
end

function M:DebugVisible()
    DebugLine("=== QuestShopping visible ===", true)
    DebugLine("enabled=" .. DebugValue(self:IsEnabled()) .. " allMaterials=" .. tostring(#(self.allMaterials or {})), true)
    for index, btn in pairs(self.buttons or {}) do
        if tonumber(index) then
            local parent = btn.GetParent and btn:GetParent() or nil
            local left = btn.GetLeft and btn:GetLeft() or nil
            local right = btn.GetRight and btn:GetRight() or nil
            local top = btn.GetTop and btn:GetTop() or nil
            local bottom = btn.GetBottom and btn:GetBottom() or nil
            local cx, cy = nil, nil
            if btn.GetCenter then
                cx, cy = btn:GetCenter()
            end
            DebugLine("button #" .. tostring(index)
                .. " shown=" .. DebugValue(btn:IsShown())
                .. " questID=" .. DebugValue(btn.questID)
                .. " aggregate=" .. DebugValue(btn.aggregate)
                .. " parent=" .. GetFrameDebugName(parent)
                .. " strata=" .. DebugValue(btn.GetFrameStrata and btn:GetFrameStrata())
                .. " level=" .. DebugValue(btn.GetFrameLevel and btn:GetFrameLevel())
                .. " alpha=" .. DebugValue(btn.GetAlpha and btn:GetAlpha())
                .. " center=" .. DebugValue(cx) .. "," .. DebugValue(cy)
                .. " rect=" .. DebugValue(left) .. "," .. DebugValue(right) .. "," .. DebugValue(top) .. "," .. DebugValue(bottom)
                .. " screen=" .. DebugValue(btn.ahui_qs_screenX) .. "," .. DebugValue(btn.ahui_qs_screenY), true)
        end
    end
    DebugLine("=== end ===", true)
end

local function CopyMaterials(materials)
    local out = {}
    for _, material in ipairs(materials or {}) do
        table.insert(out, {
            itemID = material.itemID,
            quantity = material.quantity,
            label = material.label,
            unresolvedName = material.unresolvedName,
            importName = material.importName,
            importSearchName = material.importSearchName,
            importExpandGrades = material.importExpandGrades == true,
            importResolveAttempted = material.importResolveAttempted == true,
            auctionatorSearchString = material.auctionatorSearchString,
            auctionatorTier = material.auctionatorTier,
            auctionatorIsExact = material.auctionatorIsExact,
            itemKey = material.itemKey,
            itemLevel = material.itemLevel,
            itemSuffix = material.itemSuffix,
            quality = material.quality,
            itemClassID = material.itemClassID,
            itemSubClassID = material.itemSubClassID,
            expansionID = material.expansionID,
        })
    end
    return out
end

local function MergeMaterialList(target, byItemID, materials)
    for _, material in ipairs(materials or {}) do
        AddMaterial(target, byItemID, material.itemID, material.quantity, material.label)
    end
end

function M:OpenShop(listName, materials)
    materials = CopyMaterials(materials)
    if not materials or #materials == 0 then
        PrintStatus(T("QS_STATUS_EMPTY", "No missing items to buy."))
        return false
    end

    if not PT.ShoppingList then
        PrintStatus(T("QS_STATUS_SHOP_UNAVAILABLE", "HironCraftProfitshop is unavailable."))
        return false
    end

    local ok, status, count
    if PT.ShoppingList.CreateTemporaryImportedList then
        ok, status, count = PT.ShoppingList:CreateTemporaryImportedList(listName, materials, SOURCE_KIND)
    elseif PT.ShoppingList.CreateShoppingSession then
        ok, status = PT.ShoppingList:CreateShoppingSession(materials, nil)
        count = #materials
    else
        PrintStatus(T("QS_STATUS_SHOP_UNAVAILABLE", "HironCraftProfitshop is unavailable."))
        return false
    end

    if ok then
        PrintStatus(string.format(T("QS_STATUS_CREATED", "HironCraftProfitshop list created: %d items."), tonumber(count) or #materials))
        return true
    end

    if status == "empty" then
        PrintStatus(T("QS_STATUS_EMPTY", "No missing items to buy."))
    else
        PrintStatus(T("QS_STATUS_SHOP_FAILED", "Could not create a temporary HironCraftProfitshop list."))
    end

    return false
end

function M:OpenQuestShop(questID)
    local data = self.questData and self.questData[questID]
    local materials = data and data.materials or self:GetQuestMaterials(questID)
    local title = data and data.title or GetQuestTitle(questID)
    local listName = string.format(T("QS_SHOP_LIST_NAME", "Quest: %s"), title or "?")
    return self:OpenShop(listName, materials)
end

function M:OpenAllShop()
    return self:OpenShop(T("QS_SHOP_LIST_ALL", "Quest items"), self.allMaterials or {})
end

function M:CreateButton(index)
    local btn = CreateFrame("Button", "HironCraftProfitQuestShoppingButton" .. tostring(index), UIParent)
    btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    btn:SetFrameStrata(BUTTON_FRAME_STRATA)
    if btn.SetToplevel then
        btn:SetToplevel(false)
    end
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:Hide()

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER")
    icon:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    if icon.SetAtlas then
        icon:SetAtlas("Perks-ShoppingCart")
    end
    btn.icon = icon

    btn:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            if IsAltKeyDown() then
                local function removeOne(qid)
                    if M:IsQuestSaved(qid) then
                        M:UnsaveQuest(qid)
                    else
                        M:BlacklistQuest(qid)
                    end
                end
                if self.questID then
                    removeOne(self.questID)
                elseif self.aggregate and M.questData then
                    local ids = {}
                    for qid in pairs(M.questData) do ids[#ids + 1] = qid end
                    for _, qid in ipairs(ids) do removeOne(qid) end
                end
                if GameTooltip then GameTooltip:Hide() end
            end
            return
        end

        if self.questID then
            M:OpenQuestShop(self.questID)
        elseif self.aggregate then
            M:OpenAllShop()
        end
    end)

    btn:SetScript("OnEnter", function(self)
        local TT = PT and PT.Tooltip
        if not TT then return end

        TT:Clear()

        local function MaterialLine(material)
            local name = material.label or ("#" .. tostring(material.itemID))
            local qty = tostring(material.quantity or 0)
            return string.format("%s  |cffaaffaa× %s|r", name, qty)
        end

        if self.questID and M.questData and M.questData[self.questID] then
            local data = M.questData[self.questID]
            TT:AddLine(data.title or T("QS_TOOLTIP_TITLE", "Quest Shopping"), 14, 1, 1, 1)
            TT:AddLine(T("QS_TOOLTIP_DESC", "Open a temporary HironCraftProfitshop list for missing items."), 12, 0.8, 0.8, 0.8)
            TT:AddLine(" ", 6)
            for _, material in ipairs(data.materials or {}) do
                TT:AddLine(MaterialLine(material), 12, 1, 1, 1)
            end
            TT:AddLine(" ", 6)
            TT:AddLine(T("QS_TOOLTIP_HINT_LMB", "Left click: open shopping list."), 11, 0.7, 0.7, 0.7)
            TT:AddLine(T("QS_TOOLTIP_HINT_ALT_RMB", "Alt + right click: remove the cart for this quest."), 11, 0.7, 0.7, 0.7)
            TT:AddLine(T("QS_TOOLTIP_HINT_ALT_LMB", "Alt + left click a quest in the tracker: add/remove its cart."), 11, 0.7, 0.7, 0.7)
        else
            TT:AddLine(T("QS_TOOLTIP_ALL_TITLE", "Quest Shopping"), 14, 1, 1, 1)
            TT:AddLine(T("QS_TOOLTIP_ALL_DESC", "Open a temporary HironCraftProfitshop list for all tracked quests with matching items."), 12, 0.8, 0.8, 0.8)
            TT:AddLine(" ", 6)
            for _, material in ipairs(M.allMaterials or {}) do
                TT:AddLine(MaterialLine(material), 12, 1, 1, 1)
            end
            TT:AddLine(" ", 6)
            TT:AddLine(T("QS_TOOLTIP_HINT_LMB", "Left click: open shopping list."), 11, 0.7, 0.7, 0.7)
            TT:AddLine(T("QS_TOOLTIP_HINT_ALT_RMB_ALL", "Alt + right click: remove carts for all these quests (manage them in settings)."), 11, 0.7, 0.7, 0.7)
        end

        TT:ShowCursorRightOrBelow()
    end)

    btn:SetScript("OnLeave", function()
        if PT and PT.Tooltip then PT.Tooltip:Clear() end
    end)

    self.buttons[index] = btn
    return btn
end

function M:GetButton(index)
    return self.buttons[index] or self:CreateButton(index)
end

function M:HideButtons()
    for _, btn in pairs(self.buttons or {}) do
        btn.questID = nil
        btn.aggregate = nil
        btn:Hide()
    end
end

function M:GetAggregateAnchor()
    return _G.QuestObjectiveTracker
        or (_G.ObjectiveTrackerFrame and _G.ObjectiveTrackerFrame.ContentsFrame)
        or _G.ObjectiveTrackerFrame
        or UIParent
end

local function Clamp(value, minValue, maxValue)
    value = tonumber(value)
    if not value then return nil end
    if minValue and value < minValue then return minValue end
    if maxValue and value > maxValue then return maxValue end
    return value
end

local function GetUsableFrameRect(frame)
    if not IsFrameObject(frame) then return nil end
    if frame.GetLeft and frame.GetRight and frame.GetTop and frame.GetBottom then
        local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
        if left and right and top and bottom and right > left and top > bottom then
            return left, right, top, bottom
        end
    end
    return nil
end

local function PlaceButtonAtScreenPoint(btn, x, y)
    if not btn or not x or not y then return false end

    local parent = UIParent
    local w = (parent.GetWidth and parent:GetWidth()) or 0
    local h = (parent.GetHeight and parent:GetHeight()) or 0
    local half = BUTTON_SIZE * 0.5

    if w and w > 0 then
        x = Clamp(x, half, w - half)
    end
    if h and h > 0 then
        y = Clamp(y, half, h - half)
    end

    if not x or not y then return false end

    btn:ClearAllPoints()
    btn:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    btn.ahui_qs_screenX = x
    btn.ahui_qs_screenY = y
    return true
end

local function AnchorQuestButton(btn, block)
    if not btn or not IsFrameObject(block) then return false end

    local numberAnchor = block.poiButton or block.POIButton or block.HeaderButton
    local headerAnchor = block.HeaderText or block.HeaderButton or block

    local nLeft, nRight, nTop, nBottom = GetUsableFrameRect(numberAnchor)
    local hLeft, hRight, hTop, hBottom = GetUsableFrameRect(headerAnchor)
    local bLeft, bRight, bTop, bBottom = GetUsableFrameRect(block)

    local x = nil
    local y = nil

    if nLeft and nRight then
        x = (nLeft + nRight) * 0.5
    elseif bLeft then
        x = bLeft + BUTTON_SIZE * 0.5
    elseif hLeft then
        x = hLeft - BUTTON_SIZE * 0.75
    end

    if nBottom then
        y = nBottom - BUTTON_SIZE * 0.5 - 2
    elseif hTop and hBottom then
        y = hBottom - BUTTON_SIZE * 0.5 - 2
    elseif bTop then
        y = bTop - BUTTON_SIZE * 1.5 - 2
    end

    return PlaceButtonAtScreenPoint(btn, x, y)
end

local function AnchorAggregateButton(btn, anchor)
    if not btn then return false end

    local left, right, top, bottom = GetUsableFrameRect(anchor)
    if left and top then
        return PlaceButtonAtScreenPoint(btn, left - BUTTON_SIZE * 0.5 - 4, top - BUTTON_SIZE * 0.5 - 4)
    end

    local parent = UIParent
    local w = (parent.GetWidth and parent:GetWidth()) or 0
    local h = (parent.GetHeight and parent:GetHeight()) or 0
    if w and h and w > 0 and h > 0 then
        return PlaceButtonAtScreenPoint(btn, w - 280, h - 240)
    end

    return false
end

local function GetQuestButtonParent(anchor)
    if _G.ObjectiveTrackerFrame then
        return _G.ObjectiveTrackerFrame
    end

    if IsFrameObject(anchor) and anchor.parentModule and IsFrameObject(anchor.parentModule) then
        return anchor.parentModule
    end

    if _G.QuestObjectiveTracker then
        return _G.QuestObjectiveTracker
    end

    return UIParent
end

local function ApplyButtonLayer(btn, anchor)
    if not btn then return end

    local parent = GetQuestButtonParent(anchor)
    btn:SetParent(parent or UIParent)

    local strata = BUTTON_FRAME_STRATA
    if IsFrameObject(parent) and parent.GetFrameStrata then
        strata = parent:GetFrameStrata() or strata
    elseif IsFrameObject(anchor) and anchor.GetFrameStrata then
        strata = anchor:GetFrameStrata() or strata
    end

    btn:SetFrameStrata(strata or BUTTON_FRAME_STRATA)

    local baseLevel = 1
    if IsFrameObject(anchor) and anchor.GetFrameLevel then
        baseLevel = anchor:GetFrameLevel() or baseLevel
    elseif IsFrameObject(parent) and parent.GetFrameLevel then
        baseLevel = parent:GetFrameLevel() or baseLevel
    end

    btn:SetFrameLevel((tonumber(baseLevel) or 1) + BUTTON_FRAME_LEVEL_OFFSET)

    if btn.SetToplevel then
        btn:SetToplevel(false)
    end
end

function M:RefreshVisuals()
    if not self:IsEnabled() then
        self:HideButtons()
        return
    end

    local hasData = next(self.questData) ~= nil
        or (self.allMaterials and #self.allMaterials > 0)
    if not hasData then
        self:HideButtons()
        return
    end

    for qid, frame in pairs(_questBlockCache) do
        if frame and (not IsFrameObject(frame) or not frame:IsShown() or not FrameMatchesQuest(frame, qid)) then
            _questBlockCache[qid] = nil
        end
    end

    local used = 0
    local shownQuestButtons = 0

    for questID, entry in pairs(self.questData) do
        local block = self:FindQuestBlock(questID)
        if block and block:IsShown() then
            used = used + 1
            shownQuestButtons = shownQuestButtons + 1
            local btn = self:GetButton(used)
            btn.questID = questID
            btn.aggregate = nil
            ApplyButtonLayer(btn, block)
            if not AnchorQuestButton(btn, block) then
                btn:ClearAllPoints()
                btn:SetPoint("TOPRIGHT", block, "TOPRIGHT", -2, -2)
                btn.ahui_qs_screenX = nil
                btn.ahui_qs_screenY = nil
            end
            btn:Show()
        end
    end

    if shownQuestButtons == 0 and self.allMaterials and #self.allMaterials > 0 then
        used = used + 1
        local btn = self:GetButton(used)
        local anchor = self:GetAggregateAnchor()
        btn.questID = nil
        btn.aggregate = true
        ApplyButtonLayer(btn, anchor)
        if not AnchorAggregateButton(btn, anchor) then
            btn:ClearAllPoints()
            btn:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -280, -240)
            btn.ahui_qs_screenX = nil
            btn.ahui_qs_screenY = nil
        end
        btn:Show()
    end

    for index, btn in pairs(self.buttons or {}) do
        if tonumber(index) and tonumber(index) > used then
            btn.questID = nil
            btn.aggregate = nil
            btn:Hide()
        end
    end
end

function M:UpdateButtons()
    if not self:IsEnabled() then
        self:HideButtons()
        return
    end

    self.dataUpdatePending = true

    wipe(_objectivesCache)

    local allMaterialsByID = {}
    wipe(self.questData)
    wipe(self.allMaterials)

    for _, questID in ipairs(self:GetTrackedQuestIDs()) do
        local block = self:FindQuestBlock(questID)
        if block then
            self:HookQuestBlock(block)
        end

        local include = not self:IsQuestBlacklisted(questID)
            and (IsDarkmoonQuestID(questID) or self:IsQuestSaved(questID))

        if include then
            local materials = self:GetQuestMaterials(questID)
            if materials and #materials > 0 then
                local entry = {
                    questID = questID,
                    title = GetQuestTitle(questID),
                    materials = materials,
                }
                self.questData[questID] = entry
                MergeMaterialList(self.allMaterials, allMaterialsByID, materials)
            end
        end
    end

    self.dataUpdatePending = false

    DebugLine("UpdateButtons: quests=" .. tostring(#self:GetTrackedQuestIDs()) .. " allMaterials=" .. tostring(#self.allMaterials))

    self:RefreshVisuals()
end

function M:ScheduleDataUpdate(delay)
    if not self:IsEnabled() then
        self:HideButtons()
        return
    end
    if self.dataUpdatePending then return end
    self.dataUpdatePending = true
    local function run()
        M.dataUpdatePending = false
        M:UpdateButtons()
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(delay or 0.3, run)
    else
        run()
    end
end

function M:ScheduleVisualRefresh()
    if not self:IsEnabled() then return end
    local hasData = next(self.questData) ~= nil
        or (self.allMaterials and #self.allMaterials > 0)
    if not hasData then return end
    if self.visualRefreshPending then return end
    self.visualRefreshPending = true
    local function run()
        M.visualRefreshPending = false
        M:RefreshVisuals()
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.2, run)
    else
        run()
    end
end

function M:ApplyEnabledState()
    if self:IsEnabled() then
        self:ScheduleDataUpdate(0.5)
    else
        self:HideButtons()
    end
end

function M:HandleDebugCommand(msg)
    msg = LowerText(msg or "")
    msg = msg:gsub("^%s+", ""):gsub("%s+$", "")

    if msg == "on" or msg == "1" or msg == "true" then
        self.debug = true
        DebugLine("debug ON. /ahuiqsdbg dump = one-time dump, /ahuiqsdbg visible = button state, /ahuiqsdbg off = disable live logs.", true)
        self:DebugDump()
        return
    end

    if msg == "off" or msg == "0" or msg == "false" then
        self.debug = false
        DebugLine("debug OFF", true)
        return
    end

    if msg == "toggle" then
        self.debug = not self.debug
        DebugLine("debug " .. (self.debug and "ON" or "OFF"), true)
        if self.debug then self:DebugDump() end
        return
    end

    if msg == "visible" or msg == "buttons" then
        self:DebugVisible()
        return
    end

    if msg == "required" or msg == "req" or msg == "items" then
        self:DebugRequiredItems()
        return
    end

    if msg == "refresh" or msg == "update" then
        self:UpdateButtons()
        self:DebugVisible()
        return
    end

    if msg == "help" or msg == "?" then
        DebugLine("/ahuiqsdbg - dump tracked quests now", true)
        DebugLine("/ahuiqsdbg on - enable live update logs and dump now", true)
        DebugLine("/ahuiqsdbg off - disable live update logs", true)
        DebugLine("/ahuiqsdbg visible - print current button state", true)
        DebugLine("/ahuiqsdbg required - print Blizzard required-item API result", true)
        DebugLine("/ahuiqsdbg refresh - rebuild buttons now and print their state", true)
        return
    end

    self:DebugDump()
end

SLASH_HIRONCRAFT_PROFITQUESTSHOPPINGDEBUG1 = "/ahuiqsdbg"
SLASH_HIRONCRAFT_PROFITQUESTSHOPPINGDEBUG2 = "/ahuiqsd"
SlashCmdList["HIRONCRAFT_PROFITQUESTSHOPPINGDEBUG"] = function(msg)
    M:HandleDebugCommand(msg)
end

local eventFrame = M.eventFrame or CreateFrame("Frame")
M.eventFrame = eventFrame

local function SnapshotAllTrackedQuestsFulfilled()
    for _, questID in ipairs(M:GetTrackedQuestIDs()) do
        local objectives = GetCachedObjectives(questID)
        if objectives then
            SnapshotQuestFulfilled(questID, objectives)
        end
    end
end

local function TryLearnFromLoot()
    wipe(_objectivesCache)

    local advanced = {}
    for _, questID in ipairs(M:GetTrackedQuestIDs()) do
        local objectives = GetCachedObjectives(questID)
        if objectives then
            local prev = _prevFulfilled[questID] or {}
            for idx, obj in ipairs(objectives) do
                local cur = tonumber(obj.numFulfilled) or 0
                local p = prev[idx] or 0
                if cur > p and IsObjectiveItemType(obj.type or obj.objectiveType) then
                    advanced[#advanced + 1] = { questID = questID, objIndex = idx }
                end
            end
            SnapshotQuestFulfilled(questID, objectives)
        end
    end

    if #advanced == 1 then
        local info = advanced[1]
        if not GetMappedItemID(info.questID, info.objIndex) then
            local itemID = GetMostRecentLootItemID()
            if itemID then
                SetMappedItemID(info.questID, info.objIndex, itemID)
                _materialsCache[info.questID] = nil
                _requiredItemsCache[info.questID] = nil
                DebugLine("Learned itemID=" .. tostring(itemID) .. " for questID=" .. tostring(info.questID) .. " obj=" .. tostring(info.objIndex))
            end
        end
    end
end

local function HandleLootMessage(msg)
    if type(msg) ~= "string" or msg == "" then return end
    local itemID = tonumber(msg:match("|Hitem:(%d+)"))
    if itemID then
        RecordRecentLoot(itemID)
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        M:ApplyEnabledState()
        return
    end

    if not M:IsEnabled() then return end

    if event == "CHAT_MSG_LOOT" then
        HandleLootMessage((...))
        return
    end

    if event == "QUEST_ACCEPTED"
    or event == "QUEST_REMOVED"
    or event == "QUEST_TURNED_IN"
    or event == "QUEST_WATCH_LIST_CHANGED"
    or event == "PLAYER_ENTERING_WORLD" then
        M:InvalidateTrackedCache()
        M:InvalidateQuestBlockCache()
        wipe(_requiredItemsCache)
        wipe(_materialsCache)
        wipe(_itemToQuests)
        wipe(_objectivesCache)
        SnapshotAllTrackedQuestsFulfilled()
        M:ScheduleDataUpdate()
        return
    end

    if event == "QUEST_LOG_CRITERIA_UPDATE" then
        TryLearnFromLoot()
        wipe(_materialsCache)
        wipe(_itemToQuests)
        wipe(_objectivesCache)
        M:ScheduleDataUpdate(0.2)
        return
    end

    if event == "ITEM_DATA_LOAD_RESULT" then
        local itemID = tonumber((...))
        InvalidateItemInfoCache(itemID)
        InvalidateMaterialsCacheForItem(itemID)
        M:ScheduleDataUpdate(0.2)
        return
    end

    if event == "QUEST_WATCH_UPDATE"
    or event == "QUEST_DATA_LOAD_RESULT"
    or event == "OBJECTIVE_TRACKER_UPDATE" then
        M:ScheduleVisualRefresh()
        return
    end
end)

local function RegisterEventSafe(eventName)
    if eventFrame and eventFrame.RegisterEvent then
        pcall(eventFrame.RegisterEvent, eventFrame, eventName)
    end
end

RegisterEventSafe("PLAYER_LOGIN")
RegisterEventSafe("PLAYER_ENTERING_WORLD")
RegisterEventSafe("OBJECTIVE_TRACKER_UPDATE")
RegisterEventSafe("QUEST_WATCH_LIST_CHANGED")
RegisterEventSafe("QUEST_WATCH_UPDATE")
RegisterEventSafe("QUEST_LOG_CRITERIA_UPDATE")
RegisterEventSafe("QUEST_ACCEPTED")
RegisterEventSafe("QUEST_REMOVED")
RegisterEventSafe("QUEST_TURNED_IN")
RegisterEventSafe("QUEST_DATA_LOAD_RESULT")
RegisterEventSafe("ITEM_DATA_LOAD_RESULT")
RegisterEventSafe("CHAT_MSG_LOOT")
