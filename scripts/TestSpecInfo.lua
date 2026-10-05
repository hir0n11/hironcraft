-- What a recipe gets from the specializations: counted from CraftSim's data
-- and the character's ranks, the way CraftSim counts it.
local function eq(actual, expected, what)
    if actual ~= expected then
        error((what or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
    end
end

-- A small model of the game's specializations -----------------------------------

local SKILL_LINE, CONFIG = 2900, 7
local skillLine = SKILL_LINE
-- activeRank and maxRanks as the game counts them: one more than the ranks.
local ranks = {
    [10] = { 16, 31 }, -- rank 15 of 30
    [20] = { 41, 41 }, -- maxed
    [30] = { 0, 21 },  -- not unlocked
    [40] = { 1, 11 },  -- unlocked, no rank; not in the data
    [60] = { 6, 11 },  -- rank 5 of 10
    -- 50 belongs to another profession: the game does not know it here.
}
local thresholds = { [11] = 0, [12] = 10, [13] = 20, [21] = 5, [31] = 0, [41] = 0, [51] = 0, [61] = 5 }
local asked = { node = 0, threshold = 0, definition = 0, operation = 0 }
C_ProfSpecs = {
    GetConfigIDForSkillLine = function(line) return line == SKILL_LINE and CONFIG or 0 end,
    GetUnlockRankForPerk = function(perkID)
        asked.threshold = asked.threshold + 1
        return thresholds[perkID]
    end,
}
C_Traits = {
    GetNodeInfo = function(configID, nodeID)
        asked.node = asked.node + 1
        local rank = configID == CONFIG and ranks[nodeID]
        if not rank then return { ID = 0, activeRank = 0, maxRanks = 0, entryIDs = {} } end
        return { ID = nodeID, activeRank = rank[1], maxRanks = rank[2], entryIDs = { nodeID + 100 } }
    end,
    GetEntryInfo = function(_, entryID) return { definitionID = entryID + 1000 } end,
    GetDefinitionInfo = function(definitionID)
        asked.definition = asked.definition + 1
        return { overrideName = 'Node ' .. (definitionID - 1100) }
    end,
}
-- The stats a recipe has at all; nil is a game that does not answer.
local bonusStats = {
    [1000] = { 'Multicraft', 'Resourcefulness', 'Ingenuity' },
    [1001] = { 'Resourcefulness', 'Ingenuity' }, -- a piece of gear
    [1003] = { 'Перепроизводство', 'Находчивость' },
}
C_TradeSkillUI = {
    GetCraftingOperationInfo = function(recipeID)
        asked.operation = asked.operation + 1
        local names = bonusStats[recipeID]
        if not names then return nil end
        local stats = {}
        for _, name in ipairs(names) do stats[#stats + 1] = { bonusStatName = name, bonusStatValue = 10 } end
        return { bonusStats = stats }
    end,
}

HironCraftProfit = { L = {}, CraftEngine = { ResolveSpecSkillLine = function() return skillLine end } }
local PT = HironCraftProfit
local list = { 10, 20, 30, 50, 60, 11, 12, 13, 21, 31, 41, 51, 61 }
PT.SpecStats = {
    nodes = {
        [10] = { 10, 30, { skill = 1 } },
        [11] = { 10, 1, { skill = 5 } },
        [12] = { 10, 1, { skill = 10, reduceconcentrationcost = 3 } },
        [13] = { 10, 1, { multicraft = 20, additionalitemscraftedwithmulticraft = 25 } },
        [20] = { 20, 40, { resourcefulness = 2 } },
        [21] = { 20, 1, { reagentssavedfromresourcefulness = 10, craftingspeed = 15 } },
        [30] = { 30, 20, {} },
        [31] = { 30, 1, { ingenuity = 12, ingenuityrefundincrease = 5 } },
        [41] = { 40, 1, { skill = 7 } },
        [50] = { 50, 10, { skill = 3 } },
        [51] = { 50, 1, { skill = 9 } },
        [60] = { 60, 10, { multicraft = 4 } },
        [61] = { 60, 1, { multicraft = 10 } },
    },
    recipes = { [1000] = list, [1001] = list, [1002] = list, [1003] = list, [2000] = { 50, 51 } },
    icons = { [10] = 111, [20] = 222 },
}
assert(loadfile('ProfitHub/Core/CraftEngine/SpecInfo.lua'))()
local I = assert(PT.SpecInfo, 'the module did not load')

local function Stats(info)
    local parts = {}
    for _, stat in ipairs(info.stats) do
        parts[#parts + 1] = stat.key .. '=' .. stat.current .. '/' .. stat.max .. (stat.percent and '%' or '')
    end
    return table.concat(parts, ' ')
end
local function Nodes(info)
    local parts = {}
    for _, node in ipairs(info.nodes) do
        parts[#parts + 1] = node.nodeID .. ':' .. (node.active and node.rank or '-') .. '/' .. node.maxRank
    end
    return table.concat(parts, ' ')
end

-- Every stat of a recipe that has them all ------------------------------------------

local info = assert(I.For(1000), 'nothing for a recipe the specializations affect')
eq(Stats(info), 'skill=37/52 multicraft=30/70 additionalitemscraftedwithmulticraft=0/25% '
    .. 'resourcefulness=80/80 reagentssavedfromresourcefulness=10/10% ingenuity=0/12 '
    .. 'ingenuityrefundincrease=0/5% reduceconcentrationcost=3/3% craftingspeed=15/15', 'stats now and maxed')
-- Maxed first, then by rank, the ones not unlocked last; another profession's is left out.
eq(Nodes(info), '20:40/40 10:15/30 60:5/10 40:0/10 30:-/20', 'the nodes with their ranks')
eq(info.nodes[2].name, 'Node 10', 'named as in the tree')
eq(info.nodes[2].icon, 111, 'with the icon from the data')
eq(info.nodes[4].icon, nil, 'no icon for a node the data does not have')
eq(info.nodes[4].maxRank, 10, 'whose ranks come from the game')
eq(info.nodes[5].active, false, 'a node not unlocked is marked')
eq(info.nodes[5].rank, 0, 'and has no rank')

-- Asked again: only the ranks, which can change.
local thresholdsAsked, definitionsAsked, operationsAsked = asked.threshold, asked.definition, asked.operation
asked.node = 0
I.For(1000)
eq(asked.threshold, thresholdsAsked, 'perk ranks asked again')
eq(asked.definition, definitionsAsked, 'names asked again')
eq(asked.operation, operationsAsked, 'the recipe\'s stats asked again')
eq(asked.node, 6, 'each node asked once per count')

-- More ranks: the node's perks follow.
ranks[10] = { 31, 31 }
ranks[30] = { 1, 21 }
info = I.For(1000)
eq(Stats(info), 'skill=52/52 multicraft=50/70 additionalitemscraftedwithmulticraft=25/25% '
    .. 'resourcefulness=80/80 reagentssavedfromresourcefulness=10/10% ingenuity=12/12 '
    .. 'ingenuityrefundincrease=5/5% reduceconcentrationcost=3/3% craftingspeed=15/15', 'after more ranks')
eq(Nodes(info), '20:40/40 10:30/30 60:5/10 30:0/20 40:0/10', 'and the order follows')
ranks[10] = { 16, 31 }
ranks[30] = { 0, 21 }

-- A recipe without multicraft: what gives only that does not count -----------------

info = I.For(1001)
eq(Stats(info), 'skill=37/52 resourcefulness=80/80 reagentssavedfromresourcefulness=10/10% ingenuity=0/12 '
    .. 'ingenuityrefundincrease=0/5% reduceconcentrationcost=3/3% craftingspeed=15/15', 'no multicraft for gear')
eq(Nodes(info), '20:40/40 10:15/30 40:0/10 30:-/20', 'nor the node that gives only multicraft')

-- The game names the stats in its own language.
info = I.For(1003)
eq(Stats(info), 'skill=37/52 multicraft=30/70 additionalitemscraftedwithmulticraft=0/25% '
    .. 'resourcefulness=80/80 reagentssavedfromresourcefulness=10/10% craftingspeed=15/15', 'stats named in Russian')
eq(Nodes(info), '20:40/40 10:15/30 60:5/10 40:0/10', 'the ingenuity node is left out')

-- A game that does not answer about the recipe: everything is shown, and it is asked again.
asked.operation = 0
info = I.For(1002)
eq(#info.stats, 9, 'all stats without the game\'s answer')
I.For(1002)
eq(asked.operation, 2, 'asked again until the game answers')

-- Nothing to show ------------------------------------------------------------------

eq(I.For(2000), nil, 'only another profession\'s nodes')
eq(I.For(9999), nil, 'a recipe the data does not have')
eq(I.For(nil), nil, 'no recipe')
skillLine = 1
eq(I.For(1000), nil, 'a profession without specializations')
skillLine = nil
eq(I.For(1000), nil, 'no profession')
skillLine = SKILL_LINE
local traits = C_Traits
C_Traits = nil
eq(I.For(1000), nil, 'a game without specializations')
C_Traits = traits
-- A game that fails does not break the panel.
C_Traits.GetNodeInfo = function() error('boom') end
eq(I.For(1000), nil, 'the game failing')

print('Specialization info passed (stats now and maxed, perks by rank, recipe stats, order, caches, nothing to show).')

-- The data generated from CraftSim ---------------------------------------------------

PT.SpecStats = nil
assert(loadfile('ProfitHub/Core/DB/SpecStats_MID.lua'))()
local data = assert(PT.SpecStats, 'the data did not load')
assert(tostring(data.source):match('^CraftSim %d'), 'the data does not say where it is from')
local nodeCount, perkCount = 0, 0
for id, raw in pairs(data.nodes) do
    assert(type(raw[1]) == 'number' and type(raw[2]) == 'number' and type(raw[3]) == 'table', 'node ' .. id .. ' is malformed')
    if id == raw[1] then
        nodeCount = nodeCount + 1
        assert(raw[2] > 1, 'node ' .. id .. ' has a single rank')
    else
        perkCount = perkCount + 1
        eq(raw[2], 1, 'ranks of perk ' .. id)
        assert(next(raw[3]) ~= nil, 'perk ' .. id .. ' gives nothing')
    end
    for stat, value in pairs(raw[3]) do
        local known = false
        for _, definition in ipairs(I.STATS) do known = known or definition.key == stat end
        assert(known, 'node ' .. id .. ' has an unknown stat ' .. tostring(stat))
        assert(type(value) == 'number' and value > 0, 'node ' .. id .. ' has a bad ' .. stat)
    end
end
assert(nodeCount > 100 and perkCount > 500, 'too little data: ' .. nodeCount .. ' nodes, ' .. perkCount .. ' perks')
for node in pairs(data.icons) do
    assert(data.nodes[node] and data.nodes[node][1] == node, 'an icon for ' .. node .. ', which is not a node')
end
local recipeCount = 0
for recipeID, recipeList in pairs(data.recipes) do
    recipeCount = recipeCount + 1
    assert(#recipeList > 0, 'recipe ' .. recipeID .. ' lists nothing')
    local perksStarted, seen = false, {}
    for _, id in ipairs(recipeList) do
        local raw = assert(data.nodes[id], 'recipe ' .. recipeID .. ' lists ' .. id .. ', which has no data')
        assert(not seen[id], 'recipe ' .. recipeID .. ' lists ' .. id .. ' twice')
        seen[id] = true
        if id == raw[1] then
            assert(not perksStarted, 'recipe ' .. recipeID .. ' lists node ' .. id .. ' after perks')
        else
            perksStarted = true
            -- A perk's node is listed before it, unless the data does not have the node.
            assert(seen[raw[1]] or not data.nodes[raw[1]], 'recipe ' .. recipeID .. ' lists perk ' .. id .. ' without its node')
        end
    end
end
assert(recipeCount > 500, 'too few recipes: ' .. recipeCount)

-- Every recipe with everything maxed gives all it can.
C_Traits.GetNodeInfo = function(_, nodeID)
    local raw = data.nodes[nodeID]
    local maxRank = raw and raw[2] or 10
    return { ID = nodeID, activeRank = maxRank + 1, maxRanks = maxRank + 1, entryIDs = {} }
end
C_ProfSpecs.GetUnlockRankForPerk = function() return 0 end
C_TradeSkillUI.GetCraftingOperationInfo = function() return nil end
local counted = 0
for recipeID in pairs(data.recipes) do
    local maxed = I.For(recipeID)
    if maxed then
        counted = counted + 1
        for _, stat in ipairs(maxed.stats) do
            eq(stat.current, stat.max, 'recipe ' .. recipeID .. ' maxed: ' .. stat.key)
        end
        for _, node in ipairs(maxed.nodes) do
            eq(node.rank, node.maxRank, 'recipe ' .. recipeID .. ' maxed: node ' .. node.nodeID)
        end
    end
end
assert(counted > 500, 'only ' .. counted .. ' recipes get anything from the specializations')

print(string.format('Specialization data passed (%d nodes, %d perks, %d recipes; every list is consistent and counts).',
    nodeCount, perkCount, recipeCount))
