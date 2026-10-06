local PT = HironCraftProfit
if not PT then return end

-- A bar on the Specializations page: knowledge points earned out of what the
-- whole profession takes. The solid part is spent, the pale part is earned
-- and not spent yet. To its left, a button for each expansion of the
-- profession that has specializations: the game shows one expansion's trees
-- at a time and changes it only by the dropdown on the recipe page.
local KB = {}
PT.KnowledgeBar = KB

local WIDTH, HEIGHT = 240, 18
local SPENT_COLOR = { 0.78, 0.58, 0.12, 1 }
local UNSPENT_COLOR = { 0.78, 0.58, 0.12, 0.38 }

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if ok then return result end
    return nil
end

-- Spent and maximum points of one path, counted the way the page counts
-- them: the first tier of a path is its unlock entry, not a knowledge point.
local function PathPoints(configID, pathID)
    local info = Call(C_Traits.GetNodeInfo, configID, pathID)
    if type(info) ~= "table" then return 0, 0 end
    local unlockEntry = Call(C_ProfSpecs.GetUnlockEntryForPath, pathID)
    local entryInfo = unlockEntry and Call(C_Traits.GetEntryInfo, configID, unlockEntry)
    local unlockPoints = type(entryInfo) == "table" and tonumber(entryInfo.maxRanks) or 0
    local current, maximum = tonumber(info.currentRank) or 0, tonumber(info.maxRanks) or 0
    if current > 0 then current = current - unlockPoints end
    return math.max(0, current), math.max(0, maximum - unlockPoints)
end

-- spent, unspent, total for a profession's skill line, over all of its
-- specialization tabs; nil when it has no specializations.
function KB.Count(skillLineID, configID)
    if not (C_ProfSpecs and C_Traits) or not skillLineID then return nil end
    configID = configID or Call(C_ProfSpecs.GetConfigIDForSkillLine, skillLineID)
    if not configID or configID == 0 then return nil end
    local tabs = Call(C_ProfSpecs.GetSpecTabIDsForSkillLine, skillLineID)
    if type(tabs) ~= "table" then return nil end

    local spent, total, unspent = 0, 0, nil
    local seen = {}
    for _, tabID in ipairs(tabs) do
        local tabInfo = Call(C_ProfSpecs.GetTabInfo, tabID)
        local root = type(tabInfo) == "table" and tabInfo.rootNodeID
        if root then
            local todo = { root }
            while #todo > 0 do
                local pathID = table.remove(todo)
                if not seen[pathID] then
                    seen[pathID] = true
                    local current, maximum = PathPoints(configID, pathID)
                    spent, total = spent + current, total + maximum
                    local children = Call(C_ProfSpecs.GetChildrenForPath, pathID)
                    for _, child in ipairs(type(children) == "table" and children or {}) do
                        todo[#todo + 1] = child
                    end
                end
            end
            -- The page's own counter: the tab's spend currency, with staged
            -- purchases taken off like the ranks above have them added.
            local currencyID = Call(C_ProfSpecs.GetSpendCurrencyForPath, root)
            local currencies = currencyID and Call(C_Traits.GetTreeCurrencyInfo, configID, tabID, false)
            for _, currency in ipairs(type(currencies) == "table" and currencies or {}) do
                if currency.traitCurrencyID == currencyID then
                    unspent = math.max(unspent or 0, tonumber(currency.quantity) or 0)
                end
            end
        end
    end
    if total <= 0 then return nil end
    if not unspent then
        local info = Call(C_ProfSpecs.GetCurrencyInfoForSkillLine, skillLineID)
        unspent = type(info) == "table" and tonumber(info.numAvailable) or 0
    end
    spent = math.min(spent, total)
    unspent = math.max(0, math.min(unspent, total - spent))
    return spent, unspent, total
end

function KB.Text(spent, unspent, total)
    local label = PT.L and PT.L["KNOWLEDGE_BAR_LABEL"] or "Knowledge Points"
    return string.format("%s  %d / %d", label, spent + unspent, total)
end

-- The expansions of the open profession that have specializations, the newest
-- first: the game's own entries, as that dropdown has them.
function KB.Expansions()
    local choices = {}
    if not (C_TradeSkillUI and C_ProfSpecs) then return choices end
    local infos = Call(C_TradeSkillUI.GetChildProfessionInfos)
    for _, info in ipairs(type(infos) == "table" and infos or {}) do
        local skillLineID = type(info) == "table" and tonumber(info.professionID)
        if skillLineID and Call(C_ProfSpecs.SkillLineHasSpecialization, skillLineID) == true then
            choices[#choices + 1] = info
        end
    end
    table.sort(choices, function(a, b) return tonumber(a.professionID) > tonumber(b.professionID) end)
    return choices
end

-- Takes the profession to another of its expansions the way the dropdown
-- does. True when the game was told.
function KB.SelectExpansion(info)
    if type(info) ~= "table" or not info.professionID then return false end
    if EventRegistry and type(EventRegistry.TriggerEvent) == "function" then
        if pcall(EventRegistry.TriggerEvent, EventRegistry, "Professions.SelectSkillLine", info) then return true end
    end
    if C_TradeSkillUI and type(C_TradeSkillUI.SetProfessionChildSkillLineID) == "function" then
        return (pcall(C_TradeSkillUI.SetProfessionChildSkillLineID, info.professionID))
    end
    return false
end

if not CreateFrame then return end

local driver, holder, spentBar, earnedBar, label, switch
local dirty = true

function KB.Refresh()
    local page = ProfessionsFrame and ProfessionsFrame.SpecPage
    if not holder or not page then return end
    local skillLineID = page.GetProfessionID and page:GetProfessionID()
    local configID = page.GetConfigID and page:GetConfigID()
    KB.RefreshSwitch(skillLineID)
    local spent, unspent, total = KB.Count(skillLineID, configID)
    if not spent then
        holder:Hide()
        return
    end
    earnedBar:SetMinMaxValues(0, total)
    earnedBar:SetValue(spent + unspent)
    spentBar:SetMinMaxValues(0, total)
    spentBar:SetValue(spent)
    label:SetText(KB.Text(spent, unspent, total))
    holder:Show()
end

local function MarkDirty()
    dirty = true
end

local function SwitchTip(owner)
    local tooltip = PT.Tooltip
    if not tooltip then return end
    tooltip:Clear()
    tooltip:AddLine(PT.L and PT.L["EXPANSION_SWITCH_TITLE"] or "Specializations of another expansion", 13, 1, 0.82, 0.35)
    tooltip:AddLine(PT.L and PT.L["EXPANSION_SWITCH_TIP"]
        or "Switches the profession to that expansion, like the dropdown on the recipe page, and shows its specializations and knowledge points.",
        11, 0.85, 0.85, 0.85)
    tooltip:ShowCursorRightOrBelow()
end

local function SwitchButton(index)
    local button = switch.buttons[index]
    if button then return button end
    button = CreateFrame("Button", nil, switch, "UIPanelButtonTemplate")
    button:SetSize(60, 20)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local font = PT.FONT or button.label:GetFont()
    if font then button.label:SetFont(font, 11, "") end
    button.label:SetPoint("CENTER", 0, 0)
    button:SetScript("OnClick", function(self)
        if self.info and not self.selected then KB.SelectExpansion(self.info) end
        MarkDirty()
    end)
    button:SetScript("OnEnter", SwitchTip)
    button:SetScript("OnLeave", function()
        if PT.Tooltip then PT.Tooltip:Clear() end
    end)
    switch.buttons[index] = button
    return button
end

-- The buttons beside the bar, with the expansion on screen marked. Nothing is
-- shown for a profession that has specializations in one expansion only, or
-- when the buttons are switched off in the settings.
function KB.RefreshSwitch(current)
    if not switch then return end
    -- Switched off in the settings ("Expansion buttons: specializations").
    local choices = (PT.config and PT.config.showExpansionSwitchSpec == false) and {} or KB.Expansions()
    if #choices < 2 then
        switch:Hide()
        return
    end
    current = tonumber(current)
        or tonumber(C_TradeSkillUI and Call(C_TradeSkillUI.GetProfessionChildSkillLineID))
    local x = 0
    for index, info in ipairs(choices) do
        local button = SwitchButton(index)
        button.info, button.selected = info, tonumber(info.professionID) == current
        button.label:SetText(info.expansionName or info.professionName or tostring(info.professionID))
        local width = math.max(60, math.floor((button.label.GetStringWidth and button.label:GetStringWidth() or 0) + 20))
        button:SetWidth(width)
        button:ClearAllPoints()
        button:SetPoint("LEFT", switch, "LEFT", x, 0)
        -- The expansion on screen is gold, the others are white.
        if button.selected then
            button.label:SetTextColor(1, 0.82, 0)
        else
            button.label:SetTextColor(1, 1, 1)
        end
        button:Show()
        x = x + width + 4
    end
    for index = #choices + 1, #switch.buttons do switch.buttons[index]:Hide() end
    switch:SetWidth(x - 4)
    switch:Show()
end

local function NewBar(parent, color, level)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetAllPoints()
    bar:SetFrameLevel(level)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(color[1], color[2], color[3], color[4])
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    return bar
end

local function Build()
    local page = ProfessionsFrame and ProfessionsFrame.SpecPage
    if driver or not page then return end

    -- Shown with the page: counts only while the page is on screen.
    driver = CreateFrame("Frame", nil, page)
    driver:SetSize(1, 1)
    driver:SetPoint("TOPRIGHT")

    -- In the free strip between the title bar and the tabs, on the right.
    holder = CreateFrame("Frame", nil, driver)
    holder:SetSize(WIDTH, HEIGHT)
    holder:SetPoint("TOPRIGHT", page, "TOPRIGHT", -16, -33)
    local level = (page:GetFrameLevel() or 0) + 50
    holder:SetFrameLevel(level)
    local border = holder:CreateTexture(nil, "BACKGROUND", nil, -2)
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0.45, 0.38, 0.22, 1)
    local background = holder:CreateTexture(nil, "BACKGROUND", nil, -1)
    background:SetAllPoints()
    background:SetColorTexture(0.04, 0.04, 0.04, 1)

    earnedBar = NewBar(holder, UNSPENT_COLOR, level + 1)
    spentBar = NewBar(holder, SPENT_COLOR, level + 2)
    local overlay = CreateFrame("Frame", nil, holder)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(level + 3)
    label = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER", 0, 0)
    -- The addon's own font: the label follows the addon's language, and the
    -- game's font on an English client has no Cyrillic.
    local font = label:GetFont()
    font = PT.FONT or font
    if font then label:SetFont(font, 11, "OUTLINE") end
    holder:Hide()

    -- To the left of the bar, in the same strip.
    switch = CreateFrame("Frame", nil, driver)
    switch:SetSize(10, 20)
    switch:SetPoint("TOPRIGHT", page, "TOPRIGHT", -16 - WIDTH - 10, -32)
    switch:SetFrameLevel(level)
    switch.buttons = {}
    switch:Hide()

    for _, event in ipairs({
        "TRAIT_NODE_CHANGED", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "TRAIT_CONFIG_UPDATED",
        "SKILL_LINE_SPECS_RANKS_CHANGED", "CURRENCY_DISPLAY_UPDATE", "TRADE_SKILL_SHOW",
    }) do
        pcall(driver.RegisterEvent, driver, event)
    end
    driver:SetScript("OnEvent", MarkDirty)
    driver:SetScript("OnShow", MarkDirty)
    driver:SetScript("OnUpdate", function()
        if not dirty then return end
        dirty = false
        KB.Refresh()
    end)
    -- Another profession in the same window.
    if hooksecurefunc and page.Refresh then
        hooksecurefunc(page, "Refresh", MarkDirty)
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("TRADE_SKILL_SHOW")
loader:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" and name ~= "Blizzard_Professions" then return end
    Build()
    if driver then self:UnregisterAllEvents() end
end)
