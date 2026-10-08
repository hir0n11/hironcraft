-- Which expansions of the open profession the orders page offers to switch to:
-- those the character has, the newest first, from a given expansion on.
local function eq(actual, expected, what)
    if actual ~= expected then
        error((what or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
    end
end

local BLACKSMITHING, FISHING = 1, 9
local CO, PT = {}, {}
local E = setmetatable({ CO = CO, PT = PT }, { __index = _G })
HironCraftProfitCraftingOrdersEnv = E
E.EXPANSION_MIDNIGHT, E.EXPANSION_TWW, E.EXPANSION_DF = 11, 10, 9
E.EXPANSION_DEFAULT_KEY = 'midnight'
E.EXPANSION_OPTIONS = {
    { key = 'midnight', expansionID = 11, labelKey = 'COA_EXPANSION_MIDNIGHT', fallback = 'Midnight' },
    { key = 'tww', expansionID = 10, labelKey = 'COA_EXPANSION_TWW', fallback = 'TWW' },
    { key = 'df', expansionID = 9, labelKey = 'COA_EXPANSION_DF', fallback = 'DF' },
}
E.TRADE_SKILL_LINE_IDS_BY_EXPANSION = {
    [BLACKSMITHING] = { [9] = 2822, [10] = 2872, [11] = 2907 },
    -- A profession the table knows in one expansion only.
    [FISHING] = { [11] = 2911 },
}

local base, children = BLACKSMITHING, nil
C_TradeSkillUI = {
    GetBaseProfessionInfo = function() return { profession = base } end,
    GetChildProfessionInfos = function() return children end,
}
dofile('Workflow/Orders/CraftingOrders/ExpansionQuest.lua')
assert(CO.GetAvailableProfessionExpansions, 'the list of expansions did not load')

local function keys(minExpansionID)
    local list = {}
    for _, option in ipairs(CO:GetAvailableProfessionExpansions(nil, minExpansionID)) do list[#list + 1] = option.key end
    return table.concat(list, ',')
end

-- Every expansion the character has trained, the newest first.
children = {
    { professionID = 2822, maxSkillLevel = 100 },
    { professionID = 2907, maxSkillLevel = 100 },
    { professionID = 2872, maxSkillLevel = 100 },
    { professionID = 2437, maxSkillLevel = 175 }, -- an older expansion, not offered
}
eq(keys(), 'midnight,tww,df', 'all three')
-- Patron orders begin with TWW.
eq(keys(E.EXPANSION_TWW), 'midnight,tww', 'from TWW on')
eq(keys(E.EXPANSION_MIDNIGHT), 'midnight', 'the newest alone')

-- An expansion that was never trained is not offered.
children = { { professionID = 2907, maxSkillLevel = 100 }, { professionID = 2872, maxSkillLevel = 0 },
    { professionID = 2822, maxSkillLevel = 100 } }
eq(keys(), 'midnight,df', 'without the untrained one')
eq(keys(E.EXPANSION_TWW), 'midnight', 'nothing to switch to among patron orders')
children = { { professionID = 2907 } }
eq(keys(), 'midnight', 'an entry without a skill cap counts as trained')

-- The game does not say which are trained: every expansion of the profession.
children = {}
eq(keys(), 'midnight,tww,df', 'an empty list')
children = nil
eq(keys(E.EXPANSION_TWW), 'midnight,tww', 'no list')
C_TradeSkillUI.GetChildProfessionInfos = function() error('secret') end
eq(keys(), 'midnight,tww,df', 'a list that fails')
C_TradeSkillUI.GetChildProfessionInfos = function() return children end

-- Another profession: only what it has; an unknown one: nothing.
base = FISHING
eq(keys(), 'midnight', 'a profession of one expansion')
base = 99
eq(keys(), '', 'an unknown profession')

print('Expansion switch passed (trained expansions, patron orders from TWW, missing data, other professions).')
