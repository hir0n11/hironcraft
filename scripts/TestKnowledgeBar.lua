-- The knowledge bar on the Specializations page: counting spent, unspent and
-- total points over every tab, and drawing them.
local function eq(actual, expected, what)
    if actual ~= expected then
        error((what or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
    end
end

-- Two tabs. Tab 10: root 100 (unlock tier of 1 rank, 30 points) with children
-- 101 (unlock 1, 15 points) and 102 (unlock 0, 10 points, locked). Tab 20:
-- root 200 (unlock 1, 25 points, locked).
local nodes = {
    [100] = { currentRank = 31, maxRanks = 31, unlock = 1, children = { 101, 102 } },
    [101] = { currentRank = 6, maxRanks = 16, unlock = 1 },
    [102] = { currentRank = 0, maxRanks = 10, unlock = 0 },
    [200] = { currentRank = 0, maxRanks = 26, unlock = 1 },
}
local tabs = { [10] = 100, [20] = 200 }
local treeCurrency = { [10] = { { traitCurrencyID = 7, quantity = 20 } }, [20] = { { traitCurrencyID = 7, quantity = 20 } } }
local skillTabs = { 10, 20 }
local numAvailable = 9

C_ProfSpecs = {
    GetConfigIDForSkillLine = function(skillLine) return skillLine == 2906 and 555 or 0 end,
    GetSpecTabIDsForSkillLine = function(skillLine) return skillLine == 2906 and skillTabs or {} end,
    GetTabInfo = function(tabID) return tabs[tabID] and { rootNodeID = tabs[tabID] } or nil end,
    GetChildrenForPath = function(pathID) return nodes[pathID] and nodes[pathID].children or {} end,
    GetUnlockEntryForPath = function(pathID) return pathID * 10 end,
    GetSpendCurrencyForPath = function() return 7 end,
    GetCurrencyInfoForSkillLine = function() return { numAvailable = numAvailable } end,
}
C_Traits = {
    GetNodeInfo = function(configID, pathID)
        assert(configID == 555, 'config')
        local node = nodes[pathID]
        return node and { currentRank = node.currentRank, maxRanks = node.maxRanks } or nil
    end,
    GetEntryInfo = function(_, entryID)
        local node = nodes[entryID / 10]
        return node and { maxRanks = node.unlock } or nil
    end,
    GetTreeCurrencyInfo = function(configID, tabID, excludeStaged)
        assert(configID == 555 and excludeStaged == false, 'currency arguments')
        return treeCurrency[tabID]
    end,
}

HironCraftProfit = { L = { KNOWLEDGE_BAR_LABEL = 'Knowledge Points' } }

-- Frames: just enough to build the bar and read back what it shows.
local frames, events = {}, {}
local function NewFrame(kind, _, parent)
    local frame = { kind = kind, parent = parent, shown = true, scripts = {}, level = 0 }
    function frame:SetSize() end
    function frame:SetPoint(...) self.point = { ... } end
    function frame:SetAllPoints() end
    function frame:SetFrameLevel(level) self.level = level end
    function frame:GetFrameLevel() return self.level end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:IsShown() return self.shown end
    function frame:SetScript(name, fn) self.scripts[name] = fn end
    function frame:RegisterEvent(event) events[event] = self end
    function frame:UnregisterAllEvents() self.unregistered = true end
    function frame:SetStatusBarTexture() end
    function frame:SetStatusBarColor() end
    function frame:SetMinMaxValues(low, high) self.min, self.max = low, high end
    function frame:SetValue(value) self.value = value end
    function frame:CreateTexture()
        return { SetPoint = function() end, SetAllPoints = function() end, SetColorTexture = function() end }
    end
    function frame:CreateFontString()
        local text = {}
        function text:SetPoint() end
        function text:GetFont() return 'Fonts/FRIZQT__.TTF', 10 end
        function text:SetFont(_, _, flags) self.flags = flags end
        function text:SetText(value) self.text = value end
        frame.fontString = text
        return text
    end
    frames[#frames + 1] = frame
    return frame
end
CreateFrame = NewFrame
local hooks = {}
function hooksecurefunc(target, name, fn) hooks[#hooks + 1] = { target = target, name = name, fn = fn } end

assert(loadfile('ProfitHub/Core/UI/KnowledgeBar.lua'))()
local KB = HironCraftProfit.KnowledgeBar

-- Counting ------------------------------------------------------------------

do
    local spent, unspent, total = KB.Count(2906)
    eq(total, 30 + 15 + 10 + 25, 'total over both tabs without unlock tiers')
    eq(spent, 30 + 5, 'spent: unlock tiers are not points')
    eq(unspent, 20, 'unspent from the tree currency')
    eq(KB.Text(spent, unspent, total), 'Knowledge Points  55 / 80', 'text')
end

-- The spec page's own config is used when it is given.
do
    local spent = KB.Count(2906, 555)
    eq(spent, 35, 'explicit config')
end

-- No tree currency reported: the skill line's own counter.
do
    local saved = treeCurrency
    treeCurrency = {}
    local _, unspent = KB.Count(2906)
    eq(unspent, 9, 'fallback to numAvailable')
    treeCurrency = saved
end

-- More unspent points than there is left to spend never overfills the bar.
do
    local saved = treeCurrency
    treeCurrency = { [10] = { { traitCurrencyID = 7, quantity = 500 } } }
    local spent, unspent, total = KB.Count(2906)
    eq(spent + unspent, total, 'clamped to the total')
    treeCurrency = saved
end

-- Another currency in the tree is not the knowledge counter.
do
    local saved = treeCurrency
    treeCurrency = { [10] = { { traitCurrencyID = 8, quantity = 400 }, { traitCurrencyID = 7, quantity = 3 } } }
    local _, unspent = KB.Count(2906)
    eq(unspent, 3, 'only the spend currency')
    treeCurrency = saved
end

-- A path reachable twice is counted once.
do
    nodes[101].children = { 102 }
    local _, _, total = KB.Count(2906)
    eq(total, 80, 'shared child counted once')
    nodes[101].children = nil
end

-- A profession without specializations has no bar.
eq(KB.Count(999), nil, 'no config')
eq(KB.Count(nil), nil, 'no skill line')
do
    local saved = skillTabs
    skillTabs = {}
    eq(KB.Count(2906), nil, 'no tabs')
    skillTabs = saved
end

-- An API that throws is treated as no data, not as an error.
do
    local saved = C_Traits.GetNodeInfo
    C_Traits.GetNodeInfo = function() error('secret') end
    eq(KB.Count(2906), nil, 'throwing API')
    C_Traits.GetNodeInfo = saved
end

-- The bar ---------------------------------------------------------------------

-- Nothing is built before the professions window exists.
local loader = events.ADDON_LOADED
assert(loader, 'waits for Blizzard_Professions')
loader.scripts.OnEvent(loader, 'ADDON_LOADED', 'SomethingElse')
eq(#frames, 1, 'no frames for another addon')

local professionID = 2906
local page = NewFrame('Frame')
page.level = 100
function page:GetProfessionID() return professionID end
function page:GetConfigID() return 555 end
function page:Refresh() end
ProfessionsFrame = { SpecPage = page }
local before = #frames
loader.scripts.OnEvent(loader, 'ADDON_LOADED', 'Blizzard_Professions')
assert(loader.unregistered, 'the loader is done after building')
local driver, holder, earned, spentBar = frames[before + 1], frames[before + 2], frames[before + 3], frames[before + 4]
eq(driver.parent, page, 'driver lives on the page')
eq(holder.shown, false, 'hidden until counted')
eq(holder.point[1], 'TOPRIGHT', 'anchored to the top right')
eq(holder.point[2], page, 'anchored to the page')
assert(holder.level > page.level and spentBar.level > earned.level, 'drawn above the page, spent above earned')

-- Building twice makes nothing new.
loader.scripts.OnEvent(loader, 'ADDON_LOADED', 'Blizzard_Professions')
eq(#frames, before + 5, 'built once')

driver.scripts.OnUpdate(driver)
eq(holder.shown, true, 'shown once counted')
eq(spentBar.max, 80, 'range')
eq(spentBar.value, 35, 'solid part: spent')
eq(earned.value, 55, 'pale part: earned')
local overlay = frames[before + 5]
eq(overlay.fontString.text, 'Knowledge Points  55 / 80', 'label')
eq(overlay.fontString.flags, 'OUTLINE', 'readable over the fill')

-- Nothing is recounted until something changes.
local calls = 0
local savedTabs = C_ProfSpecs.GetSpecTabIDsForSkillLine
C_ProfSpecs.GetSpecTabIDsForSkillLine = function(...) calls = calls + 1 return savedTabs(...) end
driver.scripts.OnUpdate(driver)
eq(calls, 0, 'idle frames do not count')

-- A point is spent: the solid part grows, what is earned stays.
nodes[101].currentRank = 7
treeCurrency = { [10] = { { traitCurrencyID = 7, quantity = 19 } } }
assert(events.TRAIT_NODE_CHANGED == driver, 'listens to trait changes')
driver.scripts.OnEvent(driver, 'TRAIT_NODE_CHANGED', 101)
driver.scripts.OnUpdate(driver)
eq(calls, 1, 'recounted after the event')
eq(spentBar.value, 36, 'spent after the purchase')
eq(earned.value, 55, 'earned after the purchase')
eq(overlay.fontString.text, 'Knowledge Points  55 / 80', 'label after the purchase')

-- Another profession in the same window, one without specializations.
eq(hooks[1].target, page, 'hooked the page')
eq(hooks[1].name, 'Refresh', 'hooked its Refresh')
professionID = 999
hooks[1].fn()
driver.scripts.OnUpdate(driver)
eq(holder.shown, false, 'hidden for a profession without specializations')

-- And back.
professionID = 2906
driver.scripts.OnShow(driver)
driver.scripts.OnUpdate(driver)
eq(holder.shown, true, 'shown again')

print('TestKnowledgeBar: OK')
