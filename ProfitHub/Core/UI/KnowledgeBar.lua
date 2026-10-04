local PT = HironCraftProfit
if not PT then return end

-- A bar on the Specializations page: knowledge points earned out of what the
-- whole profession takes. The solid part is spent, the pale part is earned
-- and not spent yet.
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

if not CreateFrame then return end

local driver, holder, spentBar, earnedBar, label
local dirty = true

function KB.Refresh()
    local page = ProfessionsFrame and ProfessionsFrame.SpecPage
    if not holder or not page then return end
    local skillLineID = page.GetProfessionID and page:GetProfessionID()
    local configID = page.GetConfigID and page:GetConfigID()
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
    local font, size = label:GetFont()
    if font then label:SetFont(font, size, "OUTLINE") end
    holder:Hide()

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
