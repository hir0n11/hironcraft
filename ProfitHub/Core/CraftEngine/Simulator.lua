local PT = HironCraftProfit
if not PT then return end

-- What a craft would give: the skill a recipe needs for each quality and what
-- a set of reagents (or a different skill) leads to. Everything about a set
-- of reagents is asked from the game through the craft engine (CE:Evaluate);
-- only the quality thresholds and the "what if my skill were N higher" are
-- arithmetic. Nothing here runs unless the panel that shows it asks.
PT.CraftEngine = PT.CraftEngine or {}
local CE = PT.CraftEngine
local S = {}
PT.CraftSimulator = S

-- The skill needed for each quality above the first, as a share of the
-- recipe's difficulty (the shares CraftSim uses as well).
local SHARES = {
    [2] = { 1 },
    [3] = { 0.5, 1 },
    [5] = { 0.2, 0.5, 0.8, 1 },
}

-- thresholds[q] is the skill needed for quality q; nil for a recipe whose
-- number of qualities is not known here.
function S.Thresholds(maxQuality, difficulty)
    local shares = SHARES[maxQuality]
    difficulty = tonumber(difficulty)
    if not shares or not difficulty or difficulty <= 0 then return nil end
    local thresholds = { 0 }
    for index, share in ipairs(shares) do
        thresholds[index + 1] = math.ceil(difficulty * share - 1e-6)
    end
    return thresholds
end

function S.QualityFor(thresholds, skill)
    local quality = 1
    for candidate = 2, #thresholds do
        if skill >= thresholds[candidate] then quality = candidate end
    end
    return quality
end

-- What one set of reagents gives. answer is CE:Evaluate's (asked without
-- concentration); extraSkill is the simulated "+N". For the real skill the
-- game's own quality and thresholds are taken over the arithmetic.
function S.Describe(maxQuality, answer, extraSkill)
    if type(answer) ~= "table" or not tonumber(answer.skill) or not tonumber(answer.difficulty) then return nil end
    maxQuality = tonumber(maxQuality) or 0
    extraSkill = tonumber(extraSkill) or 0
    local raw = type(answer.raw) == "table" and answer.raw or {}
    local result = {
        maxQuality = maxQuality,
        difficulty = answer.difficulty,
        ownSkill = tonumber(raw.baseSkill),
        reagentSkill = tonumber(raw.bonusSkill),
        extraSkill = extraSkill,
        skill = answer.skill + extraSkill,
    }
    local thresholds = S.Thresholds(maxQuality, answer.difficulty)
    local gameQuality = tonumber(answer.quality)
    if thresholds and gameQuality then
        -- The game's own numbers for the quality it reports.
        local lower, upper = tonumber(answer.lowerThreshold), tonumber(answer.upperThreshold)
        if lower and lower > 0 and gameQuality >= 2 and gameQuality <= maxQuality then
            thresholds[gameQuality] = math.ceil(lower - 1e-6)
        end
        if upper and upper > 0 and gameQuality < maxQuality then
            thresholds[gameQuality + 1] = math.ceil(upper - 1e-6)
        end
    end
    result.thresholds = thresholds
    if extraSkill == 0 and gameQuality then
        result.quality = gameQuality
    elseif thresholds then
        result.quality = S.QualityFor(thresholds, result.skill)
    else
        result.quality = gameQuality
    end
    if thresholds and result.quality then
        result.missingToMax = math.max(0, thresholds[maxQuality] - result.skill)
        if result.quality < maxQuality then
            result.nextQuality = result.quality + 1
            result.missingToNext = math.max(1, thresholds[result.nextQuality] - result.skill)
        end
    end
    -- The game prices concentration for the real skill only.
    if extraSkill == 0 and result.quality and result.quality < maxQuality then
        local cost = tonumber(answer.concentrationCost)
        result.concentrationCost = cost and cost > 0 and cost or nil
    end
    return result
end

-- The reagents of the window with every quality reagent replaced by one
-- quality: pickTier(slot) gives it per slot. Optional and finishing reagents
-- stay as they are in the window.
function S.Reagents(basics, current, pickTier)
    local out, quality = {}, {}
    for _, slot in ipairs(basics.basicSlots or {}) do quality[slot.dataSlotIndex] = true end
    for _, entry in ipairs(type(current) == "table" and current or {}) do
        if type(entry) == "table" and not quality[entry.dataSlotIndex] then out[#out + 1] = entry end
    end
    for _, entry in ipairs(CE:MakeReagents(basics, pickTier)) do out[#out + 1] = entry end
    return out
end

-- The option of a slot that is a given item, as the schematic has it.
local function OptionOf(slot, itemID)
    for _, option in ipairs(type(slot.options) == "table" and slot.options or {}) do
        if type(option) == "table" and option.itemID == itemID then return option end
        if option == itemID then return { itemID = itemID } end
    end
    return { itemID = itemID }
end

-- The window's reagents with a simulation's choices put in:
--   choice.tiers[dataSlotIndex] = the quality for a quality slot;
--   choice.items[dataSlotIndex] = the item for an optional or finishing slot,
--   false to leave it empty.
-- A slot without a choice stays as it is in the window.
function S.SimulatedReagents(basics, current, choice)
    local tiers = type(choice) == "table" and type(choice.tiers) == "table" and choice.tiers or {}
    local items = type(choice) == "table" and type(choice.items) == "table" and choice.items or {}
    local out, replaced = {}, {}
    for dataSlotIndex in pairs(tiers) do replaced[dataSlotIndex] = true end
    for dataSlotIndex in pairs(items) do replaced[dataSlotIndex] = true end
    for _, entry in ipairs(type(current) == "table" and current or {}) do
        if type(entry) == "table" and not replaced[entry.dataSlotIndex] then out[#out + 1] = entry end
    end
    for _, slot in ipairs(basics.basicSlots or {}) do
        local tier = tonumber(tiers[slot.dataSlotIndex])
        if tier then
            tier = math.max(1, math.min(slot.qualityCount, tier))
            local option = slot.options and slot.options[tier]
            if option and (slot.quantity or 0) > 0 then
                out[#out + 1] = {
                    reagent = type(option) == "table" and option or { itemID = option },
                    dataSlotIndex = slot.dataSlotIndex, quantity = slot.quantity,
                }
            end
        end
    end
    for _, group in ipairs({ basics.optionalSlots or {}, basics.finishingSlots or {} }) do
        for _, slot in ipairs(group) do
            local itemID = items[slot.dataSlotIndex]
            if itemID then
                out[#out + 1] = {
                    reagent = OptionOf(slot, itemID), dataSlotIndex = slot.dataSlotIndex,
                    quantity = math.max(1, tonumber(slot.quantity) or 1),
                }
            end
        end
    end
    return out
end

-- What the reagents of a craft cost by HironCraft's prices: the given ones
-- plus the recipe's reagents that have no choice. The second value is false
-- when a price is not known and the sum is therefore too low.
function S.Cost(basics, reagents)
    local total, complete = 0, true
    local function Add(itemID, quantity)
        local price = itemID and CE:DefaultPrice(itemID)
        if price and price > 0 then
            total = total + price * (quantity or 1)
        else
            complete = false
        end
    end
    for _, entry in ipairs(reagents or {}) do
        Add(type(entry.reagent) == "table" and entry.reagent.itemID, entry.quantity)
    end
    for _, fixed in ipairs(basics.fixedReagents or {}) do Add(fixed.itemID, fixed.quantity) end
    return total, complete
end

-- A simulated craft: the game's answer for the chosen reagents (one
-- question), kept so that another skill can be tried without asking again.
function S.Simulate(recipeID, basics, current, choice)
    local reagents = S.SimulatedReagents(basics, current, choice)
    local answer = CE:Evaluate(recipeID, reagents, { useConcentration = false })
    if not answer then return nil end
    local cost, complete = S.Cost(basics, reagents)
    return { answer = answer, reagents = reagents, cost = cost, costComplete = complete,
        maxQuality = tonumber(basics.maxQuality) or 0 }
end

-- The outcome of a simulation at a skill "extraSkill" higher (or lower).
function S.Outcome(simulation, extraSkill)
    if type(simulation) ~= "table" then return nil end
    return S.Describe(simulation.maxQuality, simulation.answer, extraSkill)
end

-- What each reagent of an optional or finishing slot does to the craft, per
-- recipe: { difficulty = change, skill = change }, false when the game did
-- not answer. Asked once and kept for the session.
local effects = {}

function S.ForgetEffects()
    effects = {}
end

-- The reagents of one optional or finishing slot gathered by what they do:
-- those that change difficulty and skill by the same amounts are one group
-- (a dozen missives that differ only in the stats they give become one line
-- per quality). Returns a list of { items = { itemID, ... }, effect = { difficulty, skill } }
-- in the slot's own order. The first time for a recipe this asks the game
-- once per reagent and once for the slot left empty; later it asks nothing.
function S.OptionGroups(recipeID, basics, current, choice, slot)
    local known = effects[recipeID]
    if not known then
        known = {}
        effects[recipeID] = known
    end
    local dataSlotIndex = slot.dataSlotIndex
    local function With(value)
        local items = {}
        for key, item in pairs(type(choice) == "table" and type(choice.items) == "table" and choice.items or {}) do
            items[key] = item
        end
        items[dataSlotIndex] = value
        local reagents = S.SimulatedReagents(basics, current, { tiers = choice and choice.tiers, items = items })
        return CE:Evaluate(recipeID, reagents, { useConcentration = false })
    end
    local empty, asked = nil, false
    local groups, byEffect = {}, {}
    for _, option in ipairs(type(slot.options) == "table" and slot.options or {}) do
        local itemID = type(option) == "table" and option.itemID or tonumber(option)
        if itemID then
            local effect = known[itemID]
            if effect == nil then
                if not asked then
                    empty, asked = With(false), true
                end
                local answer = empty and With(itemID)
                effect = answer and tonumber(answer.difficulty) and tonumber(answer.skill)
                    and { difficulty = answer.difficulty - empty.difficulty, skill = answer.skill - empty.skill } or false
                known[itemID] = effect
            end
            local key = effect and (effect.difficulty .. ":" .. effect.skill) or "?"
            local group = byEffect[key]
            if not group then
                group = { items = {}, effect = effect or nil }
                byEffect[key] = group
                groups[#groups + 1] = group
            end
            group.items[#group.items + 1] = itemID
        end
    end
    return groups
end

local function Best(slot) return slot.qualityCount end
local function Plain() return 1 end

local function Ask(recipeID, maxQuality, reagents)
    return S.Describe(maxQuality, CE:Evaluate(recipeID, reagents, { useConcentration = false }))
end

-- Everything the skill panel shows for a recipe: with the window's reagents,
-- with the best and with the plainest ones. Returns nil and a reason
-- ("no_quality", "no_data") when there is nothing to show.
function S.Summary(recipeID, currentReagents, basics)
    recipeID = tonumber(recipeID)
    if not recipeID then return nil, "no_data" end
    basics = basics or CE:GetRecipeBasics(recipeID)
    if type(basics) ~= "table" then return nil, "no_data" end
    local maxQuality = tonumber(basics.maxQuality) or 0
    if maxQuality < 2 then return nil, "no_quality" end
    currentReagents = type(currentReagents) == "table" and currentReagents or {}
    local current = Ask(recipeID, maxQuality, currentReagents)
    if not current then return nil, "no_data" end
    local summary = { recipeID = recipeID, maxQuality = maxQuality, current = current, basics = basics }
    if #(basics.basicSlots or {}) > 0 then
        summary.best = Ask(recipeID, maxQuality, S.Reagents(basics, currentReagents, Best))
        summary.plain = Ask(recipeID, maxQuality, S.Reagents(basics, currentReagents, Plain))
    end
    return summary
end
