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
    local result = {
        maxQuality = maxQuality,
        difficulty = answer.difficulty,
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

-- A reagent the way the game describes it: { itemID = n } for an item,
-- { currencyID = n } for a currency (crests are currencies, not items).
local function AsOption(option)
    if type(option) == "table" then return option end
    local itemID = tonumber(option)
    return itemID and { itemID = itemID } or nil
end

-- What tells two reagents apart: "i123" for an item, "c45" for a currency.
function S.OptionKey(option)
    option = AsOption(option)
    if not option then return nil end
    if option.itemID then return "i" .. tostring(option.itemID) end
    if option.currencyID then return "c" .. tostring(option.currencyID) end
    return nil
end

-- The option of a slot that a choice means, as the schematic has it.
local function OptionOf(slot, value)
    local key = S.OptionKey(value)
    for _, option in ipairs(type(slot.options) == "table" and slot.options or {}) do
        if S.OptionKey(option) == key then return AsOption(option) end
    end
    return AsOption(value)
end

-- A required slot that takes one of several different reagents (a spark, a
-- heraldry) and not the qualities of one reagent: it is filled by choosing
-- the reagent, the way an optional slot is. No reagent has more than three
-- qualities, so a longer list is a choice too.
function S.IsChoiceSlot(slot)
    if type(slot) ~= "table" then return false end
    local types = Enum and Enum.CraftingReagentType
    if types and types.Modifying ~= nil and slot.reagentType == types.Modifying then return true end
    return (tonumber(slot.qualityCount) or 0) > 3
end

-- How a quality slot is filled in the window: mix[quality] = how many, and
-- how many in all (fewer than the slot holds when not all are chosen there).
function S.WindowMix(slot, current)
    local mix, allocated = {}, 0
    for _, entry in ipairs(type(current) == "table" and current or {}) do
        if type(entry) == "table" and entry.dataSlotIndex == slot.dataSlotIndex then
            local key = S.OptionKey(entry.reagent)
            for tier, option in ipairs(type(slot.options) == "table" and slot.options or {}) do
                if S.OptionKey(option) == key then
                    local quantity = tonumber(entry.quantity) or 0
                    mix[tier] = (mix[tier] or 0) + quantity
                    allocated = allocated + quantity
                end
            end
        end
    end
    return mix, allocated
end

-- A slot's mix after one quality was set to a number: the slot stays full.
-- The other qualities keep what they had, the highest first, and the lowest
-- of them takes what is left.
function S.Rebalance(mix, qualityCount, total, tier, value)
    total = math.max(0, math.floor(tonumber(total) or 0))
    value = math.max(0, math.min(total, math.floor(tonumber(value) or 0)))
    local new, rest, others = { [tier] = value }, total - value, {}
    for other = qualityCount, 1, -1 do
        if other ~= tier then others[#others + 1] = other end
    end
    for index, other in ipairs(others) do
        if index == #others then
            new[other] = rest
        else
            local keep = math.min(math.max(0, tonumber(type(mix) == "table" and mix[other]) or 0), rest)
            new[other] = keep
            rest = rest - keep
        end
    end
    return new
end

-- The window's reagents with a simulation's choices put in:
--   choice.tiers[dataSlotIndex] = the quality for a whole quality slot;
--   choice.mixes[dataSlotIndex] = { [quality] = how many } for a slot filled
--   with several qualities at once;
--   choice.items[dataSlotIndex] = the reagent for an optional or finishing
--   slot, or for a required one that takes one of several (S.IsChoiceSlot):
--   an item's ID or the slot's option, which may be a currency; false to
--   leave it empty.
-- A slot without a choice stays as it is in the window.
function S.SimulatedReagents(basics, current, choice)
    local tiers = type(choice) == "table" and type(choice.tiers) == "table" and choice.tiers or {}
    local mixes = type(choice) == "table" and type(choice.mixes) == "table" and choice.mixes or {}
    local items = type(choice) == "table" and type(choice.items) == "table" and choice.items or {}
    local out, replaced = {}, {}
    for dataSlotIndex in pairs(tiers) do replaced[dataSlotIndex] = true end
    for dataSlotIndex in pairs(mixes) do replaced[dataSlotIndex] = true end
    for dataSlotIndex in pairs(items) do replaced[dataSlotIndex] = true end
    for _, entry in ipairs(type(current) == "table" and current or {}) do
        if type(entry) == "table" and not replaced[entry.dataSlotIndex] then out[#out + 1] = entry end
    end
    for _, slot in ipairs(basics.basicSlots or {}) do
        local tier, mix = tonumber(tiers[slot.dataSlotIndex]), mixes[slot.dataSlotIndex]
        local value = items[slot.dataSlotIndex]
        if value ~= nil then
            -- A reagent chosen for the whole slot.
            local reagent = value and OptionOf(slot, value)
            if reagent then
                out[#out + 1] = {
                    reagent = reagent, dataSlotIndex = slot.dataSlotIndex,
                    quantity = math.max(1, tonumber(slot.quantity) or 1),
                }
            end
        elseif type(mix) == "table" then
            -- No more than the slot holds, the higher qualities first.
            local left = tonumber(slot.quantity) or 0
            for quality = slot.qualityCount, 1, -1 do
                local count = math.min(left, math.max(0, math.floor(tonumber(mix[quality]) or 0)))
                local option = AsOption(slot.options and slot.options[quality])
                if count > 0 and option then
                    out[#out + 1] = { reagent = option, dataSlotIndex = slot.dataSlotIndex, quantity = count }
                    left = left - count
                end
            end
        elseif tier then
            tier = math.max(1, math.min(slot.qualityCount, tier))
            local option = AsOption(slot.options and slot.options[tier])
            if option and (slot.quantity or 0) > 0 then
                out[#out + 1] = { reagent = option, dataSlotIndex = slot.dataSlotIndex, quantity = slot.quantity }
            end
        end
    end
    for _, group in ipairs({ basics.optionalSlots or {}, basics.finishingSlots or {} }) do
        for _, slot in ipairs(group) do
            local value = items[slot.dataSlotIndex]
            local reagent = value and OptionOf(slot, value)
            if reagent then
                out[#out + 1] = {
                    reagent = reagent, dataSlotIndex = slot.dataSlotIndex,
                    quantity = math.max(1, tonumber(slot.quantity) or 1),
                }
            end
        end
    end
    return out
end

-- What the reagents of a craft cost by HironCraft's prices: the given ones
-- plus the recipe's reagents that have no choice. The second value is false
-- when a price is not known and the sum is therefore too low. Currencies
-- (crests) are not bought and are left out.
function S.Cost(basics, reagents)
    local total, complete = 0, true
    local function Add(itemID, quantity)
        local price = type(itemID) == "number" and CE:DefaultPrice(itemID) or nil
        if price and price > 0 then
            total = total + price * (quantity or 1)
        else
            complete = false
        end
    end
    for _, entry in ipairs(reagents or {}) do
        local reagent = type(entry.reagent) == "table" and entry.reagent or {}
        if reagent.itemID or not reagent.currencyID then Add(reagent.itemID, entry.quantity) end
    end
    for _, fixed in ipairs(basics.fixedReagents or {}) do Add(fixed.itemID, fixed.quantity) end
    return total, complete
end

-- A simulated craft: the game's answer for the chosen reagents (one
-- question), kept so that another skill can be tried without asking again.
-- nil when the game does not answer for the recipe.
function S.Simulate(recipeID, basics, current, choice)
    local reagents = S.SimulatedReagents(basics, current, choice)
    local answer = CE:Evaluate(recipeID, reagents, { useConcentration = false })
    if not answer or not tonumber(answer.skill) or not tonumber(answer.difficulty) then return nil end
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
-- recipe and reagent: { difficulty = change, skill = change }, false when the
-- game did not answer. Asked once and kept for the session.
local effects = {}

function S.ForgetEffects()
    effects = {}
end

-- The reagents of one slot that takes a reagent by choice (optional,
-- finishing, or required with several to choose from) gathered by what they do:
-- those that change difficulty and skill by the same amounts are one group
-- (a dozen missives that differ only in the stats they give become one line
-- per quality). Returns a list of
--   { options = { reagent, ... }, keys = { key, ... }, effect = { difficulty, skill } }
-- in the slot's own order; effect is nil when the game did not answer. The
-- first time for a recipe this asks the game once per reagent and once for
-- the slot left empty; later it asks nothing.
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
        local reagents = S.SimulatedReagents(basics, current,
            { tiers = choice and choice.tiers, mixes = choice and choice.mixes, items = items })
        return CE:Evaluate(recipeID, reagents, { useConcentration = false })
    end
    local empty, asked = nil, false
    local groups, byEffect = {}, {}
    for _, raw in ipairs(type(slot.options) == "table" and slot.options or {}) do
        local option = AsOption(raw)
        local key = S.OptionKey(option)
        if key then
            local effect = known[key]
            if effect == nil then
                if not asked then
                    empty, asked = With(false), true
                end
                local answer = empty and With(option)
                effect = answer and tonumber(answer.difficulty) and tonumber(answer.skill)
                    and tonumber(empty.difficulty) and tonumber(empty.skill)
                    and { difficulty = answer.difficulty - empty.difficulty, skill = answer.skill - empty.skill } or false
                known[key] = effect
            end
            local effectKey = effect and (effect.difficulty .. ":" .. effect.skill) or "?"
            local group = byEffect[effectKey]
            if not group then
                group = { options = {}, keys = {}, effect = effect or nil }
                byEffect[effectKey] = group
                groups[#groups + 1] = group
            end
            group.options[#group.options + 1] = option
            group.keys[#group.keys + 1] = key
        end
    end
    return groups
end
