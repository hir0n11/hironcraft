local PT = HironCraftProfit
if not PT then return end

-- What a recipe gets from the profession's specializations: the nodes that
-- affect it with their ranks, and the stats they give now against what they
-- would give with every one of them maxed, or with other ranks tried in
-- their place. Which nodes and perks affect a recipe and what each gives
-- comes from CraftSim's data (DB/SpecStats_MID.lua, MIT, see
-- LICENSE-CraftSim.txt) and is counted the way CraftSim counts it; the ranks
-- are the character's own, read from the game when the panel that shows this
-- asks.
PT.CraftEngine = PT.CraftEngine or {}
local CE = PT.CraftEngine
local I = {}
PT.SpecInfo = I

-- The stats in the order they are shown. The percent ones are whole percents.
-- A stat with a family counts only for a recipe that has that stat at all.
I.STATS = {
    { key = "skill" },
    { key = "multicraft", family = "multicraft" },
    { key = "additionalitemscraftedwithmulticraft", family = "multicraft", percent = true },
    { key = "resourcefulness", family = "resourcefulness" },
    { key = "reagentssavedfromresourcefulness", family = "resourcefulness", percent = true },
    { key = "ingenuity", family = "ingenuity" },
    { key = "ingenuityrefundincrease", family = "ingenuity", percent = true },
    { key = "reduceconcentrationcost", family = "ingenuity", percent = true },
    { key = "craftingspeed" },
}
local FAMILY = {}
for _, definition in ipairs(I.STATS) do FAMILY[definition.key] = definition.family or false end

-- How the game names the stats a recipe can have: its own text for the name,
-- then parts of the English and Russian names (without the first letter,
-- which is not lowered in Russian).
local FAMILY_NAMES = {
    multicraft = { "ITEM_MOD_MULTICRAFT_SHORT", "multicraft", "ерепроизводств" },
    resourcefulness = { "ITEM_MOD_RESOURCEFULNESS_SHORT", "resourcefulness", "аходчивост" },
    ingenuity = { "ITEM_MOD_INGENUITY_SHORT", "ingenuity", "зобретательност" },
}

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if ok then return result end
    return nil
end

-- Ranks tried in place of the character's own: tried[nodeID] = rank, -1 for a
-- node left locked. A node keeps its tried rank for every recipe it affects,
-- for as long as the game runs or until they are forgotten.
local tried = {}

-- nil for rank returns the node to the character's own rank.
function I.Try(nodeID, rank)
    nodeID, rank = tonumber(nodeID), tonumber(rank)
    if not nodeID then return end
    tried[nodeID] = rank and math.max(-1, math.floor(rank)) or nil
end

function I.AnyTried()
    return next(tried) ~= nil
end

function I.ForgetTried()
    tried = {}
end

-- Which of multicraft, resourcefulness and ingenuity the recipe has: a piece
-- of gear cannot be multicrafted, whatever the nodes give. Does not change
-- for a recipe, so it is asked once; nil while the game does not answer.
local supportOf = {}
local function Support(recipeID)
    if supportOf[recipeID] then return supportOf[recipeID] end
    local operation = C_TradeSkillUI and Call(C_TradeSkillUI.GetCraftingOperationInfo, recipeID, {}, nil, false)
    if type(operation) ~= "table" or type(operation.bonusStats) ~= "table" then return nil end
    local support = {}
    for _, stat in ipairs(operation.bonusStats) do
        local name = string.lower(tostring(stat.bonusStatName or ""))
        for family, names in pairs(FAMILY_NAMES) do
            local global = _G[names[1]]
            if type(global) == "string" and name == string.lower(global) then support[family] = true end
            for index = 2, #names do
                if name:find(names[index], 1, true) then support[family] = true end
            end
        end
    end
    supportOf[recipeID] = support
    return support
end

-- Neither changes while the game runs.
local nameOf, thresholdOf = {}, {}

-- The name a node has in the specialization tree.
local function NodeName(configID, nodeID, info)
    if nameOf[nodeID] then return nameOf[nodeID] end
    for _, entryID in ipairs(type(info.entryIDs) == "table" and info.entryIDs or {}) do
        local entry = Call(C_Traits.GetEntryInfo, configID, entryID)
        local definition = type(entry) == "table" and entry.definitionID
            and Call(C_Traits.GetDefinitionInfo, entry.definitionID)
        if type(definition) == "table" and type(definition.overrideName) == "string" and definition.overrideName ~= "" then
            nameOf[nodeID] = definition.overrideName
            return definition.overrideName
        end
    end
    return nil
end

-- The rank of its node at which a perk is gained.
local function Threshold(perkID)
    local threshold = thresholdOf[perkID]
    if threshold == nil then
        threshold = tonumber(Call(C_ProfSpecs.GetUnlockRankForPerk, perkID))
        if threshold then thresholdOf[perkID] = threshold end
    end
    return threshold
end

-- For a recipe, nil when no specialization of this character's affects it:
--   stats = { { key, percent, current, tried, max }, ... }
--     what the nodes give now, with the ranks tried, and when maxed;
--   nodes = { { nodeID, name, icon, active, rank, maxRank, tried, perRank, steps }, ... }
--     rank is the character's own (0 for a node not unlocked, which has
--     active = false); tried is the rank tried in its place (-1 for locked),
--     nil when none is; perRank is what each rank gives and steps what is
--     gained at which rank: { { rank, stats }, ... };
--   anyTried, skillChange (skill with the ranks tried less skill now),
--   points (knowledge points the ranks tried take more than the ranks now),
--   unspent (knowledge points the character has left, when the game says).
function I.For(recipeID)
    recipeID = tonumber(recipeID) or 0
    local data = PT.SpecStats
    local list = data and data.recipes and data.recipes[recipeID]
    if not list or not (C_ProfSpecs and C_Traits) then return nil end
    local skillLine = CE.ResolveSpecSkillLine and CE:ResolveSpecSkillLine(recipeID)
    local configID = skillLine and Call(C_ProfSpecs.GetConfigIDForSkillLine, skillLine)
    if not configID or configID == 0 then return nil end
    local support = Support(recipeID)
    local function Counts(stat)
        local family = FAMILY[stat]
        if family == nil then return false end
        return not family or not support or support[family] == true
    end

    local found, nodes, totals = {}, {}, {}
    -- A node of this character's trees with its rank; nil for another profession's.
    local function Node(nodeID)
        if found[nodeID] ~= nil then return found[nodeID] or nil end
        local info = Call(C_Traits.GetNodeInfo, configID, nodeID)
        local maxRanks = type(info) == "table" and tonumber(info.maxRanks) or 0
        if maxRanks <= 0 then
            found[nodeID] = false
            return nil
        end
        local raw = data.nodes[nodeID]
        local maxRank = raw and raw[2] or (maxRanks - 1)
        -- The first rank of a node is unlocking it: below that it gives nothing.
        local rank = math.min(maxRank, (tonumber(info.activeRank) or 0) - 1)
        local try = tried[nodeID]
        if try then try = math.max(-1, math.min(maxRank, try)) end
        if try == rank then try = nil end
        local node = {
            nodeID = nodeID,
            active = rank >= 0,
            rank = rank,
            maxRank = maxRank,
            tried = try,
            name = NodeName(configID, nodeID, info),
            icon = data.icons and data.icons[nodeID],
            steps = {},
            relevant = false,
        }
        found[nodeID] = node
        nodes[#nodes + 1] = node
        return node
    end
    -- Adds what counts for this recipe and returns it, nil when nothing does.
    local function Add(node, stats, now, try, atMax)
        local counted
        for stat, value in pairs(type(stats) == "table" and stats or {}) do
            if Counts(stat) and value * atMax > 0 then
                local total = totals[stat]
                if not total then
                    total = { 0, 0, 0 }
                    totals[stat] = total
                end
                total[1], total[2], total[3] = total[1] + value * now, total[2] + value * try, total[3] + value * atMax
                node.relevant = true
                counted = counted or {}
                counted[stat] = value
            end
        end
        return counted
    end
    for _, id in ipairs(list) do
        local raw = data.nodes[id]
        local node = raw and Node(raw[1])
        if node then
            local try = node.tried or node.rank
            if id == raw[1] then
                -- The node itself: its stats are per rank.
                node.perRank = Add(node, raw[3], math.max(0, node.rank), math.max(0, try), node.maxRank)
            else
                -- A perk: its stats come at the rank that gains it.
                local threshold = Threshold(id)
                local counted = Add(node, raw[3], (threshold and node.rank >= threshold) and 1 or 0,
                    (threshold and try >= threshold) and 1 or 0, 1)
                if counted then node.steps[#node.steps + 1] = { rank = threshold, stats = counted } end
            end
        end
    end

    -- Only the nodes that give this recipe something, the furthest first.
    local shown, points, anyTried = {}, 0, false
    for _, node in ipairs(nodes) do
        if node.relevant then
            node.relevant = nil
            node.rank = math.max(0, node.rank)
            if node.tried then
                anyTried = true
                points = points + math.max(0, node.tried) - node.rank
            end
            table.sort(node.steps, function(a, b) return (a.rank or math.huge) < (b.rank or math.huge) end)
            shown[#shown + 1] = node
        end
    end
    if #shown == 0 then return nil end
    -- By the character's own ranks, so that trying ranks does not move the rows.
    table.sort(shown, function(a, b)
        if a.active ~= b.active then return a.active end
        local aMax, bMax = a.rank >= a.maxRank, b.rank >= b.maxRank
        if aMax ~= bMax then return aMax end
        if a.rank ~= b.rank then return a.rank > b.rank end
        return a.nodeID < b.nodeID
    end)

    local stats = {}
    for _, definition in ipairs(I.STATS) do
        local total = totals[definition.key]
        if total then
            stats[#stats + 1] = { key = definition.key, percent = definition.percent,
                current = total[1], tried = total[2], max = total[3] }
        end
    end
    local skill = totals.skill
    local currency = Call(C_ProfSpecs.GetCurrencyInfoForSkillLine, skillLine)
    return {
        stats = stats, nodes = shown,
        anyTried = anyTried, points = points,
        skillChange = skill and (skill[2] - skill[1]) or 0,
        unspent = type(currency) == "table" and tonumber(currency.numAvailable) or nil,
    }
end

-- The skill the ranks tried give the recipe over the ranks now; nothing is
-- asked from the game while no rank is tried.
function I.SkillChange(recipeID)
    if not I.AnyTried() then return 0 end
    local info = I.For(recipeID)
    return info and info.skillChange or 0
end
