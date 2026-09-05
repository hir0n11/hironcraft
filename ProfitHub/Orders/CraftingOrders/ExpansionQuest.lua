local E = _G.HironCraftProfitCraftingOrdersEnv
if not E then
    E = {}
    _G.HironCraftProfitCraftingOrdersEnv = E
    setmetatable(E, { __index = _G })
end
setfenv(1, E)
if not PT or not CO then return end

function FindExpansionOptionByKey(key)
    for _, option in ipairs(EXPANSION_OPTIONS) do
        if option.key == key then return option end
    end
    return nil
end

function GetExpansionOptionByKey(key)
    return FindExpansionOptionByKey(key) or EXPANSION_OPTIONS[1]
end

function CO:GetSelectedProfessionExpansionKey()
    local db = GetDB()
    if type(db.professionExpansionKey) ~= "string" or not FindExpansionOptionByKey(db.professionExpansionKey) then
        db.professionExpansionKey = EXPANSION_DEFAULT_KEY
    end
    return db.professionExpansionKey
end

function CO:GetSelectedProfessionExpansionID()
    local option = GetExpansionOptionByKey(self:GetSelectedProfessionExpansionKey())
    return option and option.expansionID or EXPANSION_MIDNIGHT
end

function CO:GetSelectedProfessionExpansionLabel()
    local option = GetExpansionOptionByKey(self:GetSelectedProfessionExpansionKey())
    return option and T(option.labelKey, option.fallback) or T("COA_EXPANSION_MIDNIGHT", "Midnight")
end

function FindExpansionOptionByExpansionID(expansionID)
    expansionID = tonumber(expansionID)
    if not expansionID then return nil end

    for _, option in ipairs(EXPANSION_OPTIONS) do
        if tonumber(option.expansionID) == expansionID then
            return option
        end
    end

    return nil
end

function GetExpansionSkillLineIDForProfession(profession, expansionID)
    profession = tonumber(profession)
    expansionID = tonumber(expansionID)
    if not profession or not expansionID then return nil end

    local expansionMap = TRADE_SKILL_LINE_IDS_BY_EXPANSION[profession]
    return expansionMap and tonumber(expansionMap[expansionID]) or nil
end

function CO:GetActiveBaseProfessionID(pageFrame)
    local candidates = {}

    if C_TradeSkillUI and type(C_TradeSkillUI.GetBaseProfessionInfo) == "function" then
        local ok, info = pcall(C_TradeSkillUI.GetBaseProfessionInfo)
        if ok and type(info) == "table" then
            candidates[#candidates + 1] = info.professionID
            candidates[#candidates + 1] = info.profession
        end
    end

    if pageFrame and type(pageFrame.professionInfo) == "table" then
        candidates[#candidates + 1] = pageFrame.professionInfo.professionID
        candidates[#candidates + 1] = pageFrame.professionInfo.profession
    end

    if C_TradeSkillUI and type(C_TradeSkillUI.GetChildProfessionInfo) == "function" then
        local ok, info = pcall(C_TradeSkillUI.GetChildProfessionInfo)
        if ok and type(info) == "table" then
            candidates[#candidates + 1] = info.parentProfessionID
            candidates[#candidates + 1] = info.parentProfession
            candidates[#candidates + 1] = info.professionID
            candidates[#candidates + 1] = info.profession
        end
    end

    if Professions and type(Professions.GetProfessionInfo) == "function" then
        local ok, info = pcall(Professions.GetProfessionInfo)
        if ok and type(info) == "table" then
            candidates[#candidates + 1] = info.professionID
            candidates[#candidates + 1] = info.profession
        end
    end

    for _, profession in ipairs(candidates) do
        profession = tonumber(profession)
        if profession and TRADE_SKILL_LINE_IDS_BY_EXPANSION[profession] then
            return profession
        end
    end

    return nil
end

function CO:StoreSelectedProfessionExpansion(option)
    option = type(option) == "table" and option or GetExpansionOptionByKey(option)
    local db = GetDB()
    db.professionExpansionKey = option.key
end

function CO:SyncSelectedProfessionExpansionFromBlizzard(pageFrame)
    if self.suppressExpansionSyncUntil and CacheNow() < self.suppressExpansionSyncUntil then
        return
    end

    if not C_TradeSkillUI or type(C_TradeSkillUI.GetProfessionChildSkillLineID) ~= "function" then
        return
    end

    local ok, childSkillLineID = pcall(C_TradeSkillUI.GetProfessionChildSkillLineID)
    childSkillLineID = ok and tonumber(childSkillLineID) or nil
    if not childSkillLineID then return end

    local profession = self:GetActiveBaseProfessionID(pageFrame)
    local expansionID = self:GetProfessionExpansionIDBySkillLineID(childSkillLineID, profession)
    local option = FindExpansionOptionByExpansionID(expansionID)
    if option then
        self:StoreSelectedProfessionExpansion(option)
    end
end

function CO:SelectProfessionExpansion(option, owner)
    option = type(option) == "table" and option or GetExpansionOptionByKey(option)
    if not option then return false end

    local pageFrame = self:FindOrderPageFrame(owner) or self.activePageFrame
    local profession = self:GetActiveBaseProfessionID(pageFrame)
    local childSkillLineID = GetExpansionSkillLineIDForProfession(profession, option.expansionID)

    if not childSkillLineID then
        self:SetStatus(string.format(T("COA_STATUS_EXPANSION_UNAVAILABLE", "Profession expansion is unavailable for the current profession: %s."), T(option.labelKey, option.fallback)))
        return false
    end

    local switched = false
    local usedSelectEvent = false

    if EventRegistry and type(EventRegistry.TriggerEvent) == "function"
    and C_TradeSkillUI and type(C_TradeSkillUI.GetProfessionInfoBySkillLineID) == "function" then
        local ok, skillLineInfo = pcall(C_TradeSkillUI.GetProfessionInfoBySkillLineID, childSkillLineID)
        if ok and skillLineInfo then
            switched = SafeCall("Professions.SelectSkillLine", function()
                EventRegistry:TriggerEvent("Professions.SelectSkillLine", skillLineInfo)
            end)
            usedSelectEvent = switched
        end
    end

    if not switched and C_TradeSkillUI and type(C_TradeSkillUI.SetProfessionChildSkillLineID) == "function" then
        switched = SafeCall("SetProfessionChildSkillLineID", function()
            C_TradeSkillUI.SetProfessionChildSkillLineID(childSkillLineID)
        end)
    end


    if switched and not usedSelectEvent and profession
    and C_TradeSkillUI and type(C_TradeSkillUI.CloseTradeSkill) == "function" and type(C_TradeSkillUI.OpenTradeSkill) == "function" then
        SafeCall("CloseTradeSkill", function() C_TradeSkillUI.CloseTradeSkill() end)
        SafeCall("OpenTradeSkill", function() C_TradeSkillUI.OpenTradeSkill(profession) end)
    end

    if not switched then
        self:SetStatus(string.format(T("COA_STATUS_EXPANSION_SWITCH_FAILED", "Could not switch profession expansion: %s."), T(option.labelKey, option.fallback)))
        return false
    end

    self.suppressExpansionSyncUntil = CacheNow() + 0.5
    self:StoreSelectedProfessionExpansion(option)
    wipe(self.selectedOrders)
    self.currentQueueOrderID = nil
    self.currentQueueStep = nil
    self.orderExpansionCache = {}

    self:UpdateControlPanel()
    self:RefreshPageSoon(0.05, true)
    self:RefreshVisibleRowsSoon(0.12)
    self:ReapplyOrderNameFontsAfterProfessionRefresh(pageFrame)
    self:ReprotectOrderListAfterProfessionRefresh(pageFrame)
    self:SetStatus(string.format(T("COA_STATUS_EXPANSION_SELECTED", "Profession expansion: %s."), T(option.labelKey, option.fallback)))
    return true
end

function CO:SetSelectedProfessionExpansionKey(key, owner)
    return self:SelectProfessionExpansion(GetExpansionOptionByKey(key), owner)
end

function IsQuestCompletedForWeeklyIndicator(questID)
    questID = tonumber(questID)
    if not questID or not C_QuestLog or type(C_QuestLog.IsQuestFlaggedCompleted) ~= "function" then
        return false
    end

    local ok, completed = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
    return ok and completed == true
end

function IsQuestAcceptedForWeeklyIndicator(questID)
    questID = tonumber(questID)
    if not questID or not C_QuestLog then return false end

    if type(C_QuestLog.IsOnQuest) == "function" then
        local ok, active = pcall(C_QuestLog.IsOnQuest, questID)
        if ok and active == true then
            return true
        end
    end

    if type(C_QuestLog.GetLogIndexForQuestID) == "function" then
        local ok, logIndex = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
        if ok and tonumber(logIndex) and tonumber(logIndex) > 0 then
            return true
        end
    end

    return false
end

function GetWeeklyIndicatorQuestTitle(questID)
    questID = tonumber(questID)
    if not questID or not C_QuestLog or type(C_QuestLog.GetTitleForQuestID) ~= "function" then
        return nil
    end

    local ok, title = pcall(C_QuestLog.GetTitleForQuestID, questID)
    if ok and type(title) == "string" and title ~= "" then
        return title
    end

    return nil
end

function IsProfessionWeeklyQuestEntry(entry)
    if type(entry) ~= "table" then return false end
    local mt = getmetatable(entry)

    return (PT.HironCraftProfit_WeeklyQuestItem and mt == PT.HironCraftProfit_WeeklyQuestItem)
        or (PT.HironCraftProfit_Instructor and mt == PT.HironCraftProfit_Instructor)
        or (PT.HironCraftProfit_Consortium and mt == PT.HironCraftProfit_Consortium)
end

function JoinQuestIDs(entry)
    local parts = {}
    for _, questID in ipairs(entry and entry.questId or {}) do
        parts[#parts + 1] = tostring(questID)
    end
    return table.concat(parts, ", ")
end

function GetEntryNameForWeeklyIndicator(entry, preferredQuestID)
    local title = GetWeeklyIndicatorQuestTitle(preferredQuestID)
    if title then return title end

    if entry and type(entry.GetName) == "function" then
        local ok, name = pcall(entry.GetName, entry)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end

    if type(entry and entry.text) == "string" and entry.text ~= "" then
        return entry.text
    end

    return T("COA_WEEKLY_QUEST_FALLBACK_NAME", "Weekly profession quest")
end

function GetEntryWeeklyQuestState(entry)
    local questIDs = entry and entry.questId
    if type(questIDs) ~= "table" or #questIDs == 0 then
        return "unknown", nil
    end

    local completedQuestID
    for _, questID in ipairs(questIDs) do
        if IsQuestCompletedForWeeklyIndicator(questID) then
            completedQuestID = questID
            break
        end
    end

    local acceptedQuestID
    for _, questID in ipairs(questIDs) do
        if IsQuestAcceptedForWeeklyIndicator(questID) then
            acceptedQuestID = questID
            break
        end
    end

    if acceptedQuestID then
        return "taken", acceptedQuestID
    end

    if completedQuestID then
        return "completed", completedQuestID
    end

    return "not_taken", questIDs[1]
end

function CO:GetSelectedProfessionKnowledgeQuestEntries(pageFrame)
    pageFrame = pageFrame or self.activePageFrame or self:FindOrderPageFrame()
    self:SyncSelectedProfessionExpansionFromBlizzard(pageFrame)

    local option = GetExpansionOptionByKey(self:GetSelectedProfessionExpansionKey())
    local profession = self:GetActiveBaseProfessionID(pageFrame)
    local childSkillLineID = GetExpansionSkillLineIDForProfession(profession, option and option.expansionID)
    local dbKey = option and EXPANSION_DBKEY_BY_ID[tonumber(option.expansionID)]
    local profDB = dbKey and PT.DB and PT.DB[dbKey] and childSkillLineID and PT.DB[dbKey][childSkillLineID]

    if not profDB then
        return nil, option, childSkillLineID
    end

    local entries = {}
    for _, entry in ipairs(profDB.entries or {}) do
        if IsProfessionWeeklyQuestEntry(entry) then
            entries[#entries + 1] = entry
        end
    end

    return entries, option, childSkillLineID, profDB
end

function CO:GetSelectedProfessionWeeklyQuestStatus(pageFrame)
    local entries, option, childSkillLineID, profDB = self:GetSelectedProfessionKnowledgeQuestEntries(pageFrame)
    if not entries then
        return { state = "unknown", option = option, childSkillLineID = childSkillLineID }
    end

    if #entries == 0 then
        return { state = "none", option = option, childSkillLineID = childSkillLineID, profession = profDB }
    end

    local details = {}
    local takenDetail
    local completedDetail

    for _, entry in ipairs(entries) do
        local state, questID = GetEntryWeeklyQuestState(entry)
        local detail = {
            entry = entry,
            state = state,
            questID = questID,
            questIDs = JoinQuestIDs(entry),
            name = GetEntryNameForWeeklyIndicator(entry, questID),
        }
        details[#details + 1] = detail

        if state == "taken" and not takenDetail then
            takenDetail = detail
        elseif state == "completed" and not completedDetail then
            completedDetail = detail
        end
    end

    local state = "not_taken"
    local bestDetail = details[1]

    if takenDetail then
        state = "taken"
        bestDetail = takenDetail
    elseif completedDetail then
        state = "completed"
        bestDetail = completedDetail
    end

    return {
        state = state,
        detail = bestDetail,
        details = details,
        option = option,
        childSkillLineID = childSkillLineID,
        profession = profDB,
    }
end

function CO:GetWeeklyQuestIndicatorTextAndColor(status)
    local state = status and status.state or "unknown"

    if state == "taken" then
        return T("COA_WEEKLY_QUEST_TAKEN_SHORT", "Quest: taken"), 0.30, 1.00, 0.40, 1
    elseif state == "completed" then
        return T("COA_WEEKLY_QUEST_DONE_SHORT", "Quest: done"), 0.35, 0.82, 1.00, 1
    elseif state == "not_taken" then
        return T("COA_WEEKLY_QUEST_NOT_TAKEN_SHORT", "Quest: no"), 1.00, 0.28, 0.28, 1
    end

    return T("COA_WEEKLY_QUEST_UNKNOWN_SHORT", "Quest: —"), 0.85, 0.85, 0.88, 1
end

function CO:UpdateWeeklyQuestIndicator()
    local panel = self.controlPanel
    local indicator = panel and panel.weeklyQuestIndicator
    if not indicator or not indicator.text then return end

    local status = self:GetSelectedProfessionWeeklyQuestStatus(panel.pageFrame or self.activePageFrame)
    indicator.ahuiWeeklyQuestStatus = status

    indicator.text:SetText(T("COA_WEEKLY_QUEST_LABEL", "Квест"))
    if indicator.hironClassic then
        self:StyleClassicButton(indicator)
        local _, r, g, b = self:GetWeeklyQuestIndicatorTextAndColor(status)
        indicator.text:SetTextColor(r, g, b)
        return
    end

    if HironCraftProfit.IsFantasyDesign and HironCraftProfit:IsFantasyDesign() then
        local _, tr, tg, tb = self:GetWeeklyQuestIndicatorTextAndColor(status)
        if HironCraftProfit.ApplyPanelButtonSkin then
            HironCraftProfit:ApplyPanelButtonSkin(indicator, { tr, tg, tb })
            HironCraftProfit:SetPanelButtonForced(indicator, "disabled")
        end
        indicator.text:SetTextColor(1, 1, 1, 1)
        return
    end

    indicator.text:SetTextColor(1, 1, 1, 1)

    local state = status and status.state or "unknown"
    local r, g, b
    if state == "taken" then
        r, g, b = 0.20, 0.60, 0.24
    elseif state == "completed" then
        r, g, b = 0.22, 0.46, 0.78
    elseif state == "not_taken" then
        r, g, b = 0.68, 0.20, 0.20
    else
        r, g, b = 0.28, 0.28, 0.33
    end
    if indicator.SetBackdropColor then
        indicator:SetBackdropColor(r, g, b, 0.92)
    end
    if indicator.SetBackdropBorderColor then
        indicator:SetBackdropBorderColor(math.min(1, r + 0.22), math.min(1, g + 0.22), math.min(1, b + 0.22), 1)
    end
end

function CO:ShowWeeklyQuestIndicatorTooltip(owner)
    if not Tooltip then return end

    local status = owner and owner.ahuiWeeklyQuestStatus or self:GetSelectedProfessionWeeklyQuestStatus(self.activePageFrame)
    Tooltip:Clear()
    Tooltip:AddLine(T("COA_WEEKLY_QUEST_TOOLTIP_TITLE", "Weekly profession quest"), 13, 1, 0.82, 0.35)

    local state = status and status.state or "unknown"
    if state == "taken" then
        Tooltip:AddLine(T("COA_WEEKLY_QUEST_TOOLTIP_TAKEN", "The weekly profession quest is in your quest log."), 11, 0.35, 0.95, 0.45)
    elseif state == "completed" then
        Tooltip:AddLine(T("COA_WEEKLY_QUEST_TOOLTIP_DONE", "The weekly profession quest is already completed this week."), 11, 0.40, 0.80, 1.00)
    elseif state == "not_taken" then
        Tooltip:AddLine(T("COA_WEEKLY_QUEST_TOOLTIP_NOT_TAKEN", "The weekly profession quest is not in your quest log."), 11, 1.00, 0.35, 0.35)
    elseif state == "none" then
        Tooltip:AddLine(T("COA_WEEKLY_QUEST_TOOLTIP_NONE", "No weekly quest entry was found for this profession in HironCraftProfit knowledge data."), 11, 0.72, 0.72, 0.72)
    else
        Tooltip:AddLine(T("COA_WEEKLY_QUEST_TOOLTIP_UNKNOWN", "Could not match the current profession expansion to HironCraftProfit knowledge data."), 11, 0.72, 0.72, 0.72)
    end

    if status and status.option then
        Tooltip:AddLine(string.format(T("COA_EXPANSION_CURRENT_FMT", "Expansion: %s"), T(status.option.labelKey, status.option.fallback)), 11, 0.70, 0.90, 1)
    end

    if status and status.details then
        Tooltip:AddLine(" ", 4, 1, 1, 1)
        for _, detail in ipairs(status.details) do
            local stateLabel
            local rr, gg, bb = 0.85, 0.85, 0.85
            if detail.state == "taken" then
                stateLabel = T("COA_WEEKLY_QUEST_STATE_TAKEN", "taken")
                rr, gg, bb = 0.35, 0.95, 0.45
            elseif detail.state == "completed" then
                stateLabel = T("COA_WEEKLY_QUEST_STATE_DONE", "done")
                rr, gg, bb = 0.40, 0.80, 1.00
            elseif detail.state == "not_taken" then
                stateLabel = T("COA_WEEKLY_QUEST_STATE_NOT_TAKEN", "not taken")
                rr, gg, bb = 1.00, 0.35, 0.35
            else
                stateLabel = T("COA_WEEKLY_QUEST_STATE_UNKNOWN", "unknown")
            end

            local ids = detail.questIDs and detail.questIDs ~= "" and (" #" .. detail.questIDs) or ""
            Tooltip:AddLine((detail.name or T("COA_WEEKLY_QUEST_FALLBACK_NAME", "Weekly profession quest")) .. ids .. ": " .. stateLabel, 10, rr, gg, bb)
        end
    end

    ShowStyledTooltip(owner)
end

function CO:GetProfessionExpansionIDBySkillLineID(skillLineID, profession)
    skillLineID = tonumber(skillLineID)
    if not skillLineID then return nil end
    if skillLineID == 2950 then return EXPANSION_MIDNIGHT end

    if profession and TRADE_SKILL_LINE_IDS_BY_EXPANSION[profession] then
        for expansionID, mappedSkillLineID in pairs(TRADE_SKILL_LINE_IDS_BY_EXPANSION[profession]) do
            if tonumber(mappedSkillLineID) == skillLineID then return expansionID end
        end
    end

    for _, expansionMap in pairs(TRADE_SKILL_LINE_IDS_BY_EXPANSION) do
        for expansionID, mappedSkillLineID in pairs(expansionMap) do
            if tonumber(mappedSkillLineID) == skillLineID then return expansionID end
        end
    end

    return nil
end

function CO:GetOrderProfessionExpansionID(order)
    if not order or not order.spellID then return nil end
    self.orderExpansionCache = self.orderExpansionCache or {}
    local key = OrderKey(order.orderID) or tostring(order.spellID)
    if key and self.orderExpansionCache[key] then return self.orderExpansionCache[key] end

    local expansionID

    if C_TradeSkillUI and type(C_TradeSkillUI.GetProfessionInfoByRecipeID) == "function" then
        local ok, professionInfo = pcall(C_TradeSkillUI.GetProfessionInfoByRecipeID, order.spellID)
        if ok and professionInfo then
            expansionID = self:GetProfessionExpansionIDBySkillLineID(professionInfo.professionID, professionInfo.profession)
        end
    end

    if not expansionID and C_TradeSkillUI and type(C_TradeSkillUI.GetRecipeSchematic) == "function" then
        local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, order.spellID, false)
        if ok and schematic then
            expansionID = tonumber(schematic.expansionID or schematic.expansion or schematic.expansionLevel or schematic.sourceExpansionID)
        end
    end

    if not expansionID then
        local maxExpansion
        for _, reagentEntry in ipairs(self:BuildDisplayReagents(order)) do
            local reagentExpansionID = tonumber(reagentEntry.expansionID) or ReadPayloadExpansionID(reagentEntry, reagentEntry.itemID)
            if reagentExpansionID and (not maxExpansion or reagentExpansionID > maxExpansion) then
                maxExpansion = reagentExpansionID
            end
        end
        if maxExpansion and maxExpansion >= EXPANSION_DF then
            if maxExpansion >= EXPANSION_MIDNIGHT then expansionID = EXPANSION_MIDNIGHT
            elseif maxExpansion >= EXPANSION_TWW then expansionID = EXPANSION_TWW
            else expansionID = EXPANSION_DF end
        end
    end

    if key and expansionID then self.orderExpansionCache[key] = expansionID end
    return expansionID
end

function CO:OrderMatchesSelectedProfessionExpansion(order, allowUnknown)
    local selectedExpansionID = self:GetSelectedProfessionExpansionID()
    local orderExpansionID = self:GetOrderProfessionExpansionID(order)
    if not orderExpansionID then return allowUnknown == true end
    return tonumber(orderExpansionID) == tonumber(selectedExpansionID)
end

function CO:OpenProfessionExpansionMenu(owner)
    if not owner then return end
    self:SyncSelectedProfessionExpansionFromBlizzard(self:FindOrderPageFrame(owner) or self.activePageFrame)
    local currentKey = self:GetSelectedProfessionExpansionKey()
    local items = {}

    for _, option in ipairs(EXPANSION_OPTIONS) do
        local optionCopy = option
        items[#items + 1] = {
            text = T(optionCopy.labelKey, optionCopy.fallback),
            checked = currentKey == optionCopy.key,
            onClick = function()
                CO:SetSelectedProfessionExpansionKey(optionCopy.key, owner)
            end,
        }
    end

    if PT.Dropdown and PT.Dropdown.Show then
        PT.Dropdown:Show({ owner = owner, items = items })
        return
    end

    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
            rootDescription:SetTag("HIRONCRAFT_PROFIT_CRAFTING_ORDER_EXPANSION")
            for _, item in ipairs(items) do
                local text, onClick = item.text, item.onClick
                rootDescription:CreateButton(text, onClick)
            end
        end)
    end
end
