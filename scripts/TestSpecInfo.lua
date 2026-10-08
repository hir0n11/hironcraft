-- What a recipe gets from the specializations: counted from CraftSim's data
-- and the character's ranks, the way CraftSim counts it, and what it would
-- get with other ranks tried in their place.
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
    GetCurrencyInfoForSkillLine = function(line) return line == SKILL_LINE and { numAvailable = 4 } or nil end,
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
assert(loadfile('Workflow/Core/CraftEngine/SpecInfo.lua'))()
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

-- Other ranks tried in place of the character's own -----------------------------------

do
    local function Stat(tryInfo, key)
        for _, stat in ipairs(tryInfo.stats) do
            if stat.key == key then return stat end
        end
    end
    local function NodeOf(tryInfo, nodeID)
        for _, node in ipairs(tryInfo.nodes) do
            if node.nodeID == nodeID then return node end
        end
    end
    local own = I.For(1000)
    eq(I.AnyTried(), false, 'nothing tried at first')
    eq(own.anyTried, false, 'nor for this recipe')
    eq(own.points, 0, 'no points')
    eq(own.skillChange, 0, 'no change of skill')
    eq(own.unspent, 4, 'the knowledge points left')
    eq(Stat(own, 'skill').tried, 37, 'what is tried is what there is')
    eq(NodeOf(own, 10).tried, nil, 'no rank tried for a node')
    -- What a node gives and at which ranks.
    local blades = NodeOf(own, 10)
    eq(blades.perRank.skill, 1, 'what each rank gives')
    eq(#blades.steps, 3, 'and its three perks')
    eq(blades.steps[1].rank .. ':' .. blades.steps[1].stats.skill, '0:5', 'in the order of their ranks')
    eq(blades.steps[2].rank .. ':' .. blades.steps[2].stats.skill, '10:10', 'the second')
    eq(blades.steps[2].stats.reduceconcentrationcost, 3, 'with everything it gives')
    eq(blades.steps[3].rank .. ':' .. blades.steps[3].stats.multicraft, '20:20', 'the third')
    eq(NodeOf(own, 30).perRank, nil, 'a node whose ranks give nothing by themselves')
    eq(NodeOf(own, 60).perRank.multicraft, 4, 'another node\'s ranks')

    -- More ranks in one node: its ranks and the perk they reach.
    asked.node = 0
    eq(I.SkillChange(1000), 0, 'no skill from nothing tried')
    eq(asked.node, 0, 'and nothing asked for it')
    I.Try(10, 25)
    eq(I.AnyTried(), true, 'a rank is tried')
    local more = I.For(1000)
    eq(more.anyTried, true, 'for this recipe')
    eq(Stat(more, 'skill').current, 37, 'the skill now is what it was')
    eq(Stat(more, 'skill').tried, 47, 'ten more ranks, ten more skill')
    eq(Stat(more, 'skill').max, 52, 'the most is what it was')
    eq(Stat(more, 'multicraft').tried, 50, 'the perk the ranks reach')
    eq(Stat(more, 'additionalitemscraftedwithmulticraft').tried, 25, 'with all it gives')
    eq(Stat(more, 'resourcefulness').tried, 80, 'other nodes as they are')
    eq(more.skillChange, 10, 'the change of skill')
    eq(more.points, 10, 'for ten points')
    eq(I.SkillChange(1000), 10, 'asked by itself')
    eq(Nodes(more), '20:40/40 10:15/30 60:5/10 40:0/10 30:-/20', 'the rows stay where they were')
    eq(NodeOf(more, 10).tried, 25, 'the node has its tried rank')
    eq(NodeOf(more, 10).rank, 15, 'beside its own')

    -- Unlocking a node takes no points.
    I.Try(30, 0)
    local unlocked = I.For(1000)
    eq(Stat(unlocked, 'ingenuity').tried, 12, 'what unlocking gives')
    eq(Stat(unlocked, 'ingenuity').current, 0, 'which is not there now')
    eq(unlocked.points, 10, 'for no points more')
    eq(NodeOf(unlocked, 30).tried, 0, 'unlocked, without ranks')

    -- Fewer ranks than the character has, and a node locked.
    I.Try(20, 3)
    I.Try(60, -1)
    local fewer = I.For(1000)
    eq(Stat(fewer, 'resourcefulness').tried, 6, 'three ranks of forty')
    eq(Stat(fewer, 'reagentssavedfromresourcefulness').tried, 0, 'short of the perk')
    eq(Stat(fewer, 'craftingspeed').tried, 0, 'and all of it')
    eq(Stat(fewer, 'multicraft').tried, 20, 'nothing from the locked node')
    eq(NodeOf(fewer, 60).tried, -1, 'which is marked as locked')
    eq(fewer.points, 10 - 37 - 5, 'the points that would be saved')

    -- Kept within what a node has.
    I.Try(10, 99)
    eq(NodeOf(I.For(1000), 10).tried, 30, 'no more ranks than the node has')
    I.Try(10, -7)
    eq(NodeOf(I.For(1000), 10).tried, -1, 'and no less than locked')
    I.Try(10, 15)
    eq(NodeOf(I.For(1000), 10).tried, nil, 'the character\'s own rank is not a try')
    I.Try(10, 25)
    I.Try(10, nil)
    eq(NodeOf(I.For(1000), 10).tried, nil, 'a try taken back')
    eq(I.AnyTried(), true, 'the others stay')

    -- A try stays with its node for every recipe, until forgotten.
    eq(NodeOf(I.For(1001), 20).tried, 3, 'another recipe of the same node')
    I.ForgetTried()
    eq(I.AnyTried(), false, 'all forgotten')
    local again = I.For(1000)
    eq(again.anyTried, false, 'nothing tried again')
    eq(Stat(again, 'skill').tried, 37, 'and the numbers as they are')
    eq(again.points, 0, 'no points')
end

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

print('Specialization info passed (stats now and maxed, perks by rank, ranks tried, recipe stats, order, caches, nothing to show).')

-- The data generated from CraftSim ---------------------------------------------------

PT.SpecStats = nil
assert(loadfile('Workflow/Core/DB/SpecStats_MID.lua'))()
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
            eq(stat.tried, stat.max, 'recipe ' .. recipeID .. ' maxed, nothing tried: ' .. stat.key)
        end
        for _, node in ipairs(maxed.nodes) do
            eq(node.rank, node.maxRank, 'recipe ' .. recipeID .. ' maxed: node ' .. node.nodeID)
        end
    end
end
assert(counted > 500, 'only ' .. counted .. ' recipes get anything from the specializations')

print(string.format('Specialization data passed (%d nodes, %d perks, %d recipes; every list is consistent and counts).',
    nodeCount, perkCount, recipeCount))
