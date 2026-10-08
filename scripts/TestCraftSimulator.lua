-- The craft simulator: the skill a recipe needs for each quality, what any
-- reagents or another skill would give, and the panel that shows it without
-- costing anything while it is closed. The panel's other view, what the
-- specializations give the recipe and what other ranks would, is further
-- down; its counting has a test of its own (TestSpecInfo.lua).
local function eq(actual, expected, what)
    if actual ~= expected then
        error((what or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
    end
end

-- A small model of the game's crafting -------------------------------------------

Enum = { CraftingReagentType = { Modifying = 0, Basic = 1, Finishing = 2, Automatic = 3 } }
local BASIC, OPTIONAL, FINISHING = 1, 0, 2

-- Skill a full slot of an item adds, and difficulty an optional reagent adds.
local SKILL = { [12] = 30, [22] = 10, [23] = 20, [41] = 15, [51] = 5, [102] = 20 }
local DIFFICULTY = { [42] = 40, [43] = 40, [44] = 40, [94] = 30, [95] = 30, [96] = 30 }
-- Crests are currencies, not items.
local CURRENCY_DIFFICULTY = { [3001] = 50, [3002] = 80 }
-- The reagent quality the game reports for an item.
local REAGENT_QUALITY = { [42] = 1, [43] = 1, [44] = 1 }
local SLOT_QUANTITY = { [1] = 10, [2] = 5 }

local recipes = {
    [100] = {
        info = { recipeID = 100, name = 'Blade', maxQuality = 5, learned = true, supportsQualities = true },
        difficulty = 400, baseSkill = 300,
        slots = {
            { slotIndex = 1, dataSlotIndex = 1, required = true, quantityRequired = 10, reagentType = BASIC,
                reagents = { { itemID = 11 }, { itemID = 12 } } },
            { slotIndex = 2, dataSlotIndex = 2, required = true, quantityRequired = 5, reagentType = BASIC,
                reagents = { { itemID = 21 }, { itemID = 22 }, { itemID = 23 } } },
            { slotIndex = 3, dataSlotIndex = 3, required = true, quantityRequired = 1, reagentType = BASIC,
                reagents = { { itemID = 31 } } },
            { slotIndex = 4, dataSlotIndex = 4, required = false, quantityRequired = 1, reagentType = OPTIONAL,
                reagents = { { itemID = 41 }, { itemID = 42 }, { itemID = 43 }, { itemID = 44 } } },
            { slotIndex = 5, dataSlotIndex = 5, required = false, quantityRequired = 1, reagentType = FINISHING,
                reagents = { { itemID = 51 } } },
            { slotIndex = 6, dataSlotIndex = 6, required = false, quantityRequired = 30, reagentType = OPTIONAL,
                slotInfo = { slotText = 'Infuse with Power' },
                reagents = { { currencyID = 3001 }, { currencyID = 3002 } } },
        },
    },
    -- No quality at all.
    [200] = {
        info = { recipeID = 200, name = 'Bandage', maxQuality = 0, learned = true },
        difficulty = 0, baseSkill = 100,
        slots = { { slotIndex = 1, dataSlotIndex = 1, required = true, quantityRequired = 2, reagentType = BASIC,
            reagents = { { itemID = 61 } } } },
    },
    -- Three qualities, nothing to choose.
    [300] = {
        info = { recipeID = 300, name = 'Thread', maxQuality = 3, learned = true },
        difficulty = 301, baseSkill = 200,
        slots = { { slotIndex = 1, dataSlotIndex = 1, required = true, quantityRequired = 2, reagentType = BASIC,
            reagents = { { itemID = 71 } } } },
    },
    -- A required slot that takes one of six different reagents (a heraldry),
    -- a quality reagent, and a required slot with more options than a reagent
    -- has qualities.
    [500] = {
        info = { recipeID = 500, name = 'Amulet', maxQuality = 5, learned = true },
        difficulty = 170, baseSkill = 180,
        slots = {
            { slotIndex = 1, dataSlotIndex = 11, required = true, quantityRequired = 3, reagentType = OPTIONAL,
                reagents = { { itemID = 91 }, { itemID = 92 }, { itemID = 93 }, { itemID = 94 }, { itemID = 95 }, { itemID = 96 } } },
            { slotIndex = 2, dataSlotIndex = 12, required = true, quantityRequired = 5, reagentType = BASIC,
                reagents = { { itemID = 101 }, { itemID = 102 } } },
            { slotIndex = 3, dataSlotIndex = 13, required = true, quantityRequired = 1, reagentType = BASIC,
                slotInfo = { slotText = 'Setting' },
                reagents = { { itemID = 111 }, { itemID = 112 }, { itemID = 113 }, { itemID = 114 } } },
        },
    },
    -- The game does not answer for this one.
    [400] = {
        info = { recipeID = 400, name = 'Mystery', maxQuality = 5, learned = true }, silent = true,
        difficulty = 100, baseSkill = 100,
        slots = { { slotIndex = 1, dataSlotIndex = 1, required = true, quantityRequired = 1, reagentType = BASIC,
            reagents = { { itemID = 81 }, { itemID = 82 } } } },
    },
}
local SHARES = { [2] = { 1 }, [3] = { 0.5, 1 }, [5] = { 0.2, 0.5, 0.8, 1 } }
local calls = { operation = 0, schematic = 0 }
local upperShift = 0 -- lets the game disagree with the arithmetic

C_TradeSkillUI = {
    GetRecipeSchematic = function(recipeID)
        calls.schematic = calls.schematic + 1
        local recipe = recipes[recipeID]
        return recipe and { recipeID = recipeID, reagentSlotSchematics = recipe.slots, quantityMin = 1, recipeType = 1 } or nil
    end,
    GetRecipeInfo = function(recipeID) return recipes[recipeID] and recipes[recipeID].info or nil end,
    GetItemReagentQualityByItemInfo = function(itemID) return REAGENT_QUALITY[itemID] end,
    GetCraftingOperationInfo = function(recipeID, reagents, _, applyConcentration)
        calls.operation = calls.operation + 1
        calls.last = reagents
        local recipe = recipes[recipeID]
        if not recipe or recipe.silent then return nil end
        local bonusSkill, bonusDifficulty = 0, 0
        for _, entry in ipairs(reagents or {}) do
            local itemID, currencyID = entry.reagent and entry.reagent.itemID, entry.reagent and entry.reagent.currencyID
            local slotQuantity = SLOT_QUANTITY[entry.dataSlotIndex] or entry.quantity or 1
            bonusSkill = bonusSkill + (SKILL[itemID] or 0) * (entry.quantity or 1) / slotQuantity
            bonusDifficulty = bonusDifficulty + (DIFFICULTY[itemID] or 0) + (CURRENCY_DIFFICULTY[currencyID] or 0)
        end
        local difficulty, skill = recipe.difficulty + bonusDifficulty, recipe.baseSkill + bonusSkill
        local maxQuality = recipe.info.maxQuality
        local shares, quality, lower, upper = SHARES[maxQuality] or {}, 1, 0, nil
        for index, share in ipairs(shares) do
            local need = math.ceil(difficulty * share)
            if skill >= need then quality, lower = index + 1, need elseif not upper then upper = need end
        end
        if upper then upper = upper + upperShift end
        local cost = upper and (upper - skill) * 5 or 0
        if applyConcentration and quality < maxQuality then quality = quality + 1 end
        return {
            recipeID = recipeID, baseSkill = recipe.baseSkill, bonusSkill = bonusSkill,
            baseDifficulty = recipe.difficulty, bonusDifficulty = bonusDifficulty,
            craftingQuality = quality, quality = quality, isQualityCraft = maxQuality > 1,
            lowerSkillThreshold = lower, upperSkillTreshold = upper or difficulty, concentrationCost = cost,
            bonusStats = { { bonusStatName = 'Ingenuity', bonusStatValue = 10 } },
        }
    end,
}

-- Prices in copper, by HironCraft's own price list.
local prices = { [11] = 10000, [12] = 50000, [21] = 20000, [22] = 40000, [23] = 80000, [31] = 30000,
    [41] = 1000000, [42] = 2000000, [51] = 500000 }
local unloaded, nameRequests = {}, {}
C_Item = {
    GetItemNameByID = function(itemID) if not unloaded[itemID] then return 'Item ' .. itemID end end,
    RequestLoadItemDataByID = function(itemID) nameRequests[itemID] = (nameRequests[itemID] or 0) + 1 end,
}
C_CurrencyInfo = { GetCurrencyInfo = function(currencyID) return { name = 'Crest ' .. currencyID } end }
HironCraftProfit = { L = {}, FONT = 'Addon/default.ttf',
    Prices = { GetItemPrice = function(_, itemID) return prices[itemID] end } }
SlashCmdList = {}
assert(loadfile('Workflow/Core/CraftEngine/Engine.lua'))()
assert(loadfile('Workflow/Core/CraftEngine/Simulator.lua'))()
assert(loadfile('Workflow/Core/CraftEngine/SpecInfo.lua'))()
local PT = HironCraftProfit
local S, CE = PT.CraftSimulator, PT.CraftEngine
assert(S and CE and CE.Evaluate, 'the engine or the simulator did not load')

-- Thresholds --------------------------------------------------------------------

do
    local five = S.Thresholds(5, 400)
    eq(table.concat(five, ','), '0,80,200,320,400', 'five qualities')
    eq(table.concat(S.Thresholds(3, 301), ','), '0,151,301', 'three qualities, rounded up')
    eq(table.concat(S.Thresholds(2, 50), ','), '0,50', 'two qualities')
    eq(S.Thresholds(4, 100), nil, 'an unknown number of qualities')
    eq(S.Thresholds(5, 0), nil, 'no difficulty')
    eq(S.Thresholds(5, nil), nil, 'nothing')
    eq(S.QualityFor(five, 79), 1, 'below the first threshold')
    eq(S.QualityFor(five, 80), 2, 'exactly on a threshold')
    eq(S.QualityFor(five, 399), 4, 'just short of the last')
    eq(S.QualityFor(five, 900), 5, 'far above')
end

-- A craft with the window's reagents and with others -------------------------------

local window = {
    { reagent = { itemID = 12 }, dataSlotIndex = 1, quantity = 10 }, -- slot 1 at quality 2
    { reagent = { itemID = 21 }, dataSlotIndex = 2, quantity = 5 },  -- slot 2 at quality 1
    { reagent = { itemID = 41 }, dataSlotIndex = 4, quantity = 1 },  -- an optional reagent
}
local basics100 = CE:GetRecipeBasics(100)
local function outcome(reagents, choice, extra)
    local simulation = S.Simulate(100, basics100, reagents, choice or {})
    return simulation and S.Outcome(simulation, extra or 0), simulation
end

do
    calls.operation = 0
    local now, simulation = outcome(window)
    eq(calls.operation, 1, 'one question to the game')
    eq(now.maxQuality, 5, 'qualities')
    eq(now.difficulty, 400, 'difficulty')
    eq(now.skill, 345, 'skill with the window\'s reagents')
    eq(now.quality, 4, 'quality now')
    eq(now.missingToMax, 55, 'short of the top quality')
    eq(now.nextQuality, 5, 'next quality')
    eq(now.missingToNext, 55, 'short of the next quality')
    eq(now.concentrationCost, 275, 'concentration for the next quality')
    eq(table.concat(now.thresholds, ','), '0,80,200,320,400', 'thresholds')
    eq(simulation.cost, 500000 + 100000 + 1000000 + 30000, 'cost: the chosen reagents and the one without a choice')
    eq(simulation.costComplete, true, 'every price known')

    -- Every quality slot at its highest and at its lowest, the optional one kept.
    local highest = outcome(window, { tiers = { [1] = 2, [2] = 3 } })
    eq(highest.skill, 365, 'skill with the highest qualities')
    eq(highest.quality, 4, 'still not the top')
    eq(highest.missingToMax, 35, 'what even those lack')
    local lowest = outcome(window, { tiers = { [1] = 1, [2] = 1 } })
    eq(lowest.skill, 315, 'skill with the lowest qualities')
    eq(lowest.quality, 3, 'one quality lower')
    eq(lowest.missingToMax, 85, 'short of the top')
    eq(lowest.concentrationCost, 25, 'concentration from there')
end

-- A slot filled with two qualities at once in the window is taken as it is.
do
    local mixed = {
        { reagent = { itemID = 11 }, dataSlotIndex = 1, quantity = 5 },
        { reagent = { itemID = 12 }, dataSlotIndex = 1, quantity = 5 },
        { reagent = { itemID = 23 }, dataSlotIndex = 2, quantity = 5 },
    }
    eq(outcome(mixed).skill, 335, 'half a slot of the better reagent counts half')
    eq(outcome(mixed, { tiers = { [1] = 2 } }).skill, 350, 'a chosen quality replaces the mix')
end

-- An optional reagent that makes the recipe harder moves every threshold.
do
    local harder = outcome({ { reagent = { itemID = 42 }, dataSlotIndex = 4, quantity = 1 } })
    eq(harder.difficulty, 440, 'difficulty with the optional reagent')
    eq(harder.thresholds[5], 440, 'the top quality needs all of it')
    eq(harder.thresholds[4], 352, 'and the others their share')
end

-- Nothing chosen in the window; the top quality; the game's own thresholds.
do
    local bare = outcome(nil)
    eq(bare.skill, 300, 'bare skill')
    eq(bare.quality, 3, 'quality with nothing chosen')

    recipes[100].baseSkill = 380
    local top = outcome(window)
    eq(top.quality, 5, 'top quality')
    eq(top.missingToMax, 0, 'nothing missing')
    eq(top.nextQuality, nil, 'no next quality')
    eq(top.concentrationCost, nil, 'no concentration')
    recipes[100].baseSkill = 300

    upperShift = 3
    local shifted = outcome(window)
    eq(shifted.thresholds[5], 403, 'the game\'s threshold for the next quality')
    eq(shifted.missingToMax, 58, 'counted from the game\'s threshold')
    upperShift = 0
end

-- A different skill: only arithmetic, no concentration price.
do
    local _, simulation = outcome(window)
    calls.operation = 0
    local more = S.Outcome(simulation, 55)
    eq(more.skill, 400, 'skill with +55')
    eq(more.quality, 5, 'reaches the top')
    eq(more.missingToMax, 0, 'nothing missing')
    eq(more.concentrationCost, nil, 'no concentration price for a made-up skill')
    local almost = S.Outcome(simulation, 54)
    eq(almost.quality, 4, 'one short stays below')
    eq(almost.missingToMax, 1, 'one missing')
    local less = S.Outcome(simulation, -30)
    eq(less.skill, 315, 'skill with -30')
    eq(less.quality, 3, 'drops a quality')
    eq(less.missingToNext, 5, 'short of the next one')
    eq(calls.operation, 0, 'the game was not asked')
    eq(S.Outcome(nil, 5), nil, 'no simulation, no outcome')
    eq(S.Describe(5, nil), nil, 'no answer, no result')
    eq(S.Describe(5, { skill = 10 }), nil, 'an answer without difficulty')
    eq(S.Simulate(400, CE:GetRecipeBasics(400), {}, {}), nil, 'a recipe the game is silent about')
end

-- The reagents a choice leads to, items and currencies alike.
do
    local function ids(reagents)
        local list = {}
        for _, entry in ipairs(reagents) do
            list[#list + 1] = entry.dataSlotIndex .. ':' .. S.OptionKey(entry.reagent) .. 'x' .. entry.quantity
        end
        table.sort(list)
        return table.concat(list, ' ')
    end
    local function made(current, choice) return ids(S.SimulatedReagents(basics100, current, choice)) end
    eq(made(window, {}), '1:i12x10 2:i21x5 4:i41x1', 'no choices: the window as it is')
    eq(made(window, { tiers = { [2] = 3 } }), '1:i12x10 2:i23x5 4:i41x1', 'one slot at another quality')
    eq(made(window, { tiers = { [1] = 9, [2] = 0 } }), '1:i12x10 2:i21x5 4:i41x1', 'qualities kept within the slot\'s range')
    eq(made(window, { items = { [4] = 42, [5] = 51 } }), '1:i12x10 2:i21x5 4:i42x1 5:i51x1', 'optional and finishing reagents chosen')
    eq(made(window, { items = { [4] = false } }), '1:i12x10 2:i21x5', 'an optional slot emptied')
    eq(made(nil, { tiers = { [1] = 1 } }), '1:i11x10', 'nothing in the window')
    -- A slot filled partly at one quality and partly at another.
    eq(made(window, { mixes = { [1] = { [1] = 6, [2] = 4 } } }), '1:i11x6 1:i12x4 2:i21x5 4:i41x1', 'a slot at two qualities')
    eq(made(window, { mixes = { [2] = { [3] = 9 } } }), '1:i12x10 2:i23x5 4:i41x1', 'no more than the slot holds')
    eq(made(window, { mixes = { [2] = { [1] = 0, [2] = 0, [3] = 0 } } }), '1:i12x10 4:i41x1', 'a slot left empty by its mix')
    eq(outcome(window, { mixes = { [1] = { [1] = 6, [2] = 4 } } }).skill, 327, 'part of a slot counts for its part')

    -- How the window fills a slot, and a slot kept full when one quality is set.
    local mix, allocated = S.WindowMix(basics100.basicSlots[1], window)
    eq(mix[2], 10, 'the window\'s quality')
    eq(mix[1], nil, 'none of the other')
    eq(allocated, 10, 'the whole slot chosen in the window')
    mix, allocated = S.WindowMix(basics100.basicSlots[1], { { reagent = { itemID = 11 }, dataSlotIndex = 1, quantity = 3 },
        { reagent = { itemID = 12 }, dataSlotIndex = 1, quantity = 4 }, { reagent = { itemID = 23 }, dataSlotIndex = 2, quantity = 5 } })
    eq(mix[1] .. '+' .. mix[2], '3+4', 'a mix in the window')
    eq(allocated, 7, 'not all of the slot chosen')
    eq(select(2, S.WindowMix(basics100.basicSlots[2], nil)), 0, 'nothing in the window')
    local function balanced(old, qualities, total, tier, value)
        local new, parts = S.Rebalance(old, qualities, total, tier, value), {}
        for quality = 1, qualities do parts[quality] = tostring(new[quality]) end
        return table.concat(parts, '/')
    end
    eq(balanced({ [1] = 10 }, 2, 10, 2, 4), '6/4', 'two qualities: the other takes the rest')
    eq(balanced({ [1] = 3, [3] = 2 }, 3, 5, 2, 2), '1/2/2', 'three qualities: the highest keeps its own')
    eq(balanced({ [1] = 1, [2] = 2, [3] = 2 }, 3, 5, 2, 5), '0/5/0', 'a whole slot at the edited quality')
    eq(balanced({ [3] = 5 }, 3, 5, 2, 2), '0/2/3', 'the highest gives way only as far as needed')
    eq(balanced({ [2] = 10 }, 2, 10, 1, 99), '10/0', 'no more than the slot holds')
    eq(balanced({ [2] = 10 }, 2, 10, 2, -3), '10/0', 'and no less than none')
    eq(balanced(nil, 2, 10, 2, 3), '7/3', 'from nothing')
    -- A crest: a currency, in the amount its slot asks for.
    eq(made(window, { items = { [6] = { currencyID = 3001 } } }), '1:i12x10 2:i21x5 4:i41x1 6:c3001x30', 'a currency reagent')
    eq(S.OptionKey(41), 'i41', 'an item\'s key')
    eq(S.OptionKey({ currencyID = 7 }), 'c7', 'a currency\'s key')
    eq(S.OptionKey(nil), nil, 'nothing has no key')
    eq(S.OptionKey({}), nil, 'nor does an empty reagent')

    -- A crest makes the recipe harder and costs nothing at the auction.
    local crested, simulation = outcome(window, { items = { [6] = { currencyID = 3002 } } })
    eq(crested.difficulty, 480, 'difficulty with the crest')
    eq(crested.missingToMax, 135, 'what it takes then')
    eq(simulation.cost, 1630000, 'the crest is not priced')
    eq(simulation.costComplete, true, 'and its missing price is not a gap')
    prices[41] = nil
    local _, unpriced = outcome(window)
    eq(unpriced.cost, 630000, 'cost without an unknown price')
    eq(unpriced.costComplete, false, 'marked as incomplete')
    prices[41] = 1000000
end

-- The reagents of an optional slot gathered by what they do to the craft.
do
    local optionalSlot, crestSlot, finishingSlot = basics100.optionalSlots[1], basics100.optionalSlots[2], basics100.finishingSlots[1]
    S.ForgetEffects()
    calls.operation = 0
    local groups = S.OptionGroups(100, basics100, window, {}, optionalSlot)
    eq(calls.operation, 5, 'the slot left empty and each of its four reagents')
    eq(#groups, 2, 'two different effects')
    eq(table.concat(groups[1].keys, ','), 'i41', 'the reagent that adds skill')
    eq(groups[1].effect.skill, 15, 'its skill')
    eq(groups[1].effect.difficulty, 0, 'and no difficulty')
    eq(table.concat(groups[2].keys, ','), 'i42,i43,i44', 'the three that only differ in name')
    eq(groups[2].effect.difficulty, 40, 'their difficulty')
    eq(groups[2].effect.skill, 0, 'and no skill')
    eq(groups[2].options[1].itemID, 42, 'the first of them stands for the group')
    -- Known now: nothing is asked again, whatever else is chosen.
    calls.operation = 0
    groups = S.OptionGroups(100, basics100, window, { tiers = { [1] = 1 }, items = { [4] = 42 } }, optionalSlot)
    eq(calls.operation, 0, 'known effects are not asked again')
    eq(#groups, 2, 'the same groups')
    -- Crests are listed too, each with its own effect.
    groups = S.OptionGroups(100, basics100, window, {}, crestSlot)
    eq(calls.operation, 3, 'the crest slot: empty and its two crests')
    eq(#groups, 2, 'two crests, two effects')
    eq(table.concat(groups[1].keys, ','), 'c3001', 'the first crest')
    eq(groups[1].effect.difficulty, 50, 'its difficulty')
    eq(groups[2].effect.difficulty, 80, 'the second crest\'s')
    calls.operation = 0
    groups = S.OptionGroups(100, basics100, window, {}, finishingSlot)
    eq(calls.operation, 2, 'the finishing slot: empty and its one reagent')
    eq(groups[1].effect.skill, 5, 'the finishing reagent\'s skill')
    -- A recipe the game is silent about: the reagents are listed without an effect.
    local slot = { dataSlotIndex = 9, slotIndex = 9, quantity = 1, options = { { itemID = 91 }, { itemID = 92 } } }
    groups = S.OptionGroups(400, CE:GetRecipeBasics(400), {}, {}, slot)
    eq(#groups, 1, 'one group when nothing is known')
    eq(groups[1].effect, nil, 'without an effect')
    eq(#groups[1].options, 2, 'holding every reagent')
    S.ForgetEffects()
end

-- A required slot that takes one of several reagents is a choice, not a quality.
do
    local basics500 = CE:GetRecipeBasics(500)
    local heraldry, stone, setting = basics500.basicSlots[1], basics500.basicSlots[2], basics500.basicSlots[3]
    eq(#heraldry.options, 6, 'the slot with six reagents')
    eq(S.IsChoiceSlot(heraldry), true, 'a required slot that is not a quality reagent')
    eq(S.IsChoiceSlot(stone), false, 'a quality reagent')
    eq(S.IsChoiceSlot(setting), true, 'more options than a reagent has qualities')
    eq(S.IsChoiceSlot(basics100.basicSlots[2]), false, 'three qualities')
    eq(S.IsChoiceSlot(nil), false, 'nothing')
    local function made(current, choice)
        local list = {}
        for _, entry in ipairs(S.SimulatedReagents(basics500, current, choice)) do
            list[#list + 1] = entry.dataSlotIndex .. ':' .. S.OptionKey(entry.reagent) .. 'x' .. entry.quantity
        end
        table.sort(list)
        return table.concat(list, ' ')
    end
    local chosen = { { reagent = { itemID = 92 }, dataSlotIndex = 11, quantity = 3 },
        { reagent = { itemID = 101 }, dataSlotIndex = 12, quantity = 5 } }
    eq(made(chosen, {}), '11:i92x3 12:i101x5', 'the window as it is')
    eq(made(chosen, { items = { [11] = 94 } }), '11:i94x3 12:i101x5', 'another reagent for the whole slot')
    eq(made(chosen, { items = { [11] = false } }), '12:i101x5', 'the slot emptied')
    eq(made({}, { items = { [11] = { itemID = 96 }, [13] = 112 }, mixes = { [12] = { [2] = 5 } } }),
        '11:i96x3 12:i102x5 13:i112x1', 'beside a quality slot')
    S.ForgetEffects()
    calls.operation = 0
    local groups = S.OptionGroups(500, basics500, {}, {}, heraldry)
    eq(calls.operation, 7, 'the slot left empty and each of its six reagents')
    eq(#groups, 2, 'two effects among the six')
    eq(table.concat(groups[1].keys, ','), 'i91,i92,i93', 'those that change nothing')
    eq(table.concat(groups[2].keys, ','), 'i94,i95,i96', 'those that make the recipe harder')
    eq(groups[2].effect.difficulty, 30, 'by this much')
    local harder = S.Outcome(S.Simulate(500, basics500, {}, { items = { [11] = 94 } }), 0)
    eq(harder.difficulty, 200, 'difficulty with the chosen reagent')
    eq(harder.quality, 4, 'and the quality it leaves')
    S.ForgetEffects()
end

print('Craft simulator passed (thresholds, reagents, mixes, optional reagents, crests, top quality, game thresholds, +N skill, cost, reagent groups, slots with a choice of reagents).')

-- The panel ----------------------------------------------------------------------

local frames, named = {}, {}
local function Region()
    local region = { shown = true, points = {} }
    local methods = {}
    function methods:SetText(text) self.text = text end
    function methods:GetText() return self.text end
    function methods:SetShown(on) self.shown = on and true or false end
    function methods:Show() self.shown = true end
    function methods:Hide() self.shown = false end
    function methods:IsShown() return self.shown end
    function methods:SetWidth(width) self.width = width end
    function methods:GetWidth() return self.width or 0 end
    function methods:SetSize(width, height) self.width, self.height = width, height end
    function methods:SetHeight(height) self.height = height end
    function methods:SetFont(path, size) self.font, self.size = path, size end
    function methods:SetTextColor(r, g, b) self.color = { r, g, b } end
    function methods:SetPoint(point, ...) self.points[point] = { ... } end
    function methods:ClearAllPoints() self.points = {} end
    return setmetatable(region, { __index = function(_, key)
        if methods[key] then return methods[key] end
        if type(key) == 'string' and key:match('^%u') then return function() end end
    end })
end
local function Frame(kind, name, parent, template)
    local frame = Region()
    frame.kind, frame.name, frame.parent, frame.template = kind, name, parent, template
    frame.scripts, frame.events = {}, {}
    local base = getmetatable(frame).__index
    local methods = {}
    function methods:SetScript(script, fn) self.scripts[script] = fn end
    function methods:RegisterEvent(event) self.events[event] = true end
    -- A text box tells its script about a new text, like the game does.
    function methods:SetText(text)
        self.text = text
        if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
    end
    function methods:CreateFontString() return Region() end
    function methods:CreateTexture() return Region() end
    function methods:SetShown(on)
        local was = self.shown
        self.shown = on and true or false
        if self.shown and not was and self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function methods:Show() self:SetShown(true) end
    function methods:Hide() self:SetShown(false) end
    function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function methods:GetLeft() return self.left end
    function methods:GetTop() return self.top end
    function methods:GetRight() return self.right end
    setmetatable(frame, { __index = function(_, key)
        if methods[key] then return methods[key] end
        return base(frame, key)
    end })
    frames[#frames + 1] = frame
    if name then named[name] = frame end
    return frame
end
UIParent = Frame('Frame', 'UIParent')
function CreateFrame(kind, name, parent, template) return Frame(kind, name, parent, template) end
local hooks = {}
function hooksecurefunc(target, method, fn) hooks[#hooks + 1] = { target = target, method = method, fn = fn } end
local clock = 0
function debugprofilestop() clock = clock + 0.25 return clock end
local tips = {}
PT.Tooltip = {
    Clear = function() tips = {} end,
    AddLine = function(_, text) tips[#tips + 1] = text end,
    ShowCursorRightOrBelow = function() end,
}
local opened
MenuUtil = { CreateContextMenu = function(owner, generator) opened = { owner = owner, generator = generator } end }
HironCraftProfit_DB = nil

local before = #frames
assert(loadfile('Workflow/Core/UI/CraftSimulator_UI.lua'))()
local UI = S.UI
eq(#frames, before + 1, 'only the event frame exists after loading')
assert(loadfile('Workflow/Core/UI/CraftSimulator_Sim.lua'))()
assert(loadfile('Workflow/Core/UI/CraftSimulator_Spec.lua'))()
eq(#frames, before + 1, 'what the panel shows builds nothing at load')
eq(HironCraftProfit_DB, nil, 'saved variables created at load')
local events = frames[#frames]
assert(events.events.ADDON_LOADED and events.events.TRADE_SKILL_SHOW, 'not waiting for the profession window')
local function fire(event, ...) events.scripts.OnEvent(events, event, ...) end

-- Without the profession window nothing is built.
fire('ADDON_LOADED', 'SomethingElse')
fire('TRADE_SKILL_SHOW')
eq(#frames, before + 1, 'built without the profession window')

-- The profession window with a recipe selected.
local selected, allocation = 100, window
local callbacks = {}
ProfessionsRecipeSchematicFormMixin = { Event = { AllocationsModified = 'alloc', UseBestQualityModified = 'best' } }
ProfessionsFrame = Frame('Frame', 'ProfessionsFrame', UIParent)
ProfessionsFrame.right, ProfessionsFrame.top = 900, 700
local page = Frame('Frame', nil, ProfessionsFrame)
page.CreateButton = Frame('GameButton', nil, page)
local form = Frame('Frame', nil, page)
ProfessionsFrame.CraftingPage, page.SchematicForm = page, form
function page:SelectRecipe() end
function form:UpdateDetailsStats() end
function form:GetRecipeInfo() return selected and recipes[selected].info or nil end
function form:GetTransaction()
    return { CreateCraftingReagentInfoTbl = function() return allocation end }
end
function form:RegisterCallback(event, fn) callbacks[event] = fn end

calls.operation, calls.schematic = 0, 0
fire('ADDON_LOADED', 'Blizzard_Professions')
local toggle
for index = before + 2, #frames do
    if frames[index].kind == 'Button' and frames[index].parent == page then toggle = frames[index] end
end
assert(toggle, 'no button to open the panel')
eq(toggle.points.BOTTOMRIGHT[1], page.CreateButton, 'the button sits by the Create button')
eq(toggle.points.BOTTOMRIGHT[2], 'TOPRIGHT', 'right above it')
-- Made before the addon's language was set: the label follows when shown.
eq(toggle.label.text, 'Skill', 'label at creation')
PT.L.CRAFTSIM_TOGGLE = 'Навык'
toggle.scripts.OnShow(toggle)
eq(toggle.label.text, 'Навык', 'label in the addon\'s language once shown')
PT.L.CRAFTSIM_TOGGLE = nil
toggle.scripts.OnShow(toggle)
eq(named.HironCraftCraftSimulator, nil, 'the panel is not built until asked for')
eq(#hooks, 2, 'follows recipe selection and the window\'s own recount')
assert(callbacks.alloc and callbacks.best, 'follows reagent changes')
local builtToggles = 0
fire('TRADE_SKILL_SHOW')
fire('ADDON_LOADED', 'Blizzard_Professions')
for index = before + 2, #frames do
    if frames[index].kind == 'Button' and frames[index].parent == page then builtToggles = builtToggles + 1 end
end
eq(builtToggles, 1, 'one button')
eq(#hooks, 2, 'hooked once')

-- Closed: whatever happens in the window costs nothing.
for _, hook in ipairs(hooks) do hook.fn() end
callbacks.alloc()
fire('PLAYER_EQUIPMENT_CHANGED')
fire('TRAIT_CONFIG_UPDATED')
eq(calls.operation, 0, 'the game was asked while the panel is closed')
eq(calls.schematic, 0, 'recipes were looked up while the panel is closed')
eq(HironCraftProfit_DB, nil, 'nothing saved before the panel is used')
toggle.scripts.OnEnter(toggle)
assert(#tips >= 2, 'no tooltip on the button')

-- Opened: built, placed beside the window, counted once.
toggle.scripts.OnClick(toggle)
local panel = assert(named.HironCraftCraftSimulator, 'the panel was not built')
local body = panel.body
local saved = HironCraftProfit_DB.craftSimulator
eq(panel.shown, true, 'shown')
eq(saved.shown, true, 'remembered as open')
eq(panel.points.TOPLEFT[1], ProfessionsFrame, 'beside the profession window')
eq(panel.points.TOPLEFT[3], 6, 'default place')
eq(calls.operation, 0, 'counted before the frame is drawn')
local function Recount()
    calls.operation = 0
    hooks[1].fn()
    panel.scripts.OnUpdate(panel)
    return calls.operation
end
panel.scripts.OnUpdate(panel)
eq(calls.operation, 1, 'one question for the selected recipe')
eq(calls.schematic, 1, 'the recipe looked up once')
eq(body.shown, true, 'numbers visible')
eq(panel.message.shown, false, 'no message')
eq(body.recipe.text, 'Blade', 'recipe name')
eq(body.status.text, 'Skill 345: T4, T5 needs 55 more', 'skill, quality and what is missing')
eq(body.concentration.text, 'Concentration: 275 for T5', 'concentration')
eq(body.cost.text, 'Reagents: 163g', 'cost of the reagents')
eq(body.scale.shown, true, 'the scale is there')
eq(body.scale.names[5].text, 'T5', 'top quality named above the bar')
eq(body.scale.needs[5].text, '400', 'with the skill it needs below')
eq(body.scale.names[2].text, 'T2', 'first threshold named')
eq(body.scale.needs[2].text, '80', 'and numbered')
eq(body.scale.names[4].color[2] > 0.8, true, 'a reached quality is marked')
eq(body.scale.names[5].color[2] < 0.8, true, 'an unreached one is not')
eq(body.fill.shown, true, 'the missing skill is offered')
eq(body.fill.label.text, '+55', 'as a number')
eq(body.recipe.font, 'Addon/default.ttf', 'the addon\'s font')
assert(saved.lastMs and saved.lastMs > 0, 'the time was not recorded')
assert(panel.height > 200, 'the panel is not sized around its rows')

-- Idle frames ask nothing.
panel.scripts.OnUpdate(panel)
panel.scripts.OnUpdate(panel)
eq(calls.operation, 1, 'asked again without a change')

-- Reagents changed in the window: one recount, however many signals.
allocation = { { reagent = { itemID = 12 }, dataSlotIndex = 1, quantity = 10 },
    { reagent = { itemID = 23 }, dataSlotIndex = 2, quantity = 5 } }
callbacks.alloc()
for _, hook in ipairs(hooks) do hook.fn() end
calls.operation = 0
panel.scripts.OnUpdate(panel)
eq(calls.operation, 1, 'one recount for several signals')
eq(calls.schematic, 1, 'the same recipe is not looked up again')
eq(body.status.text, 'Skill 350: T4, T5 needs 50 more', 'follows the window')
allocation = window

-- The top quality.
recipes[100].baseSkill = 380
fire('PLAYER_EQUIPMENT_CHANGED')
panel.scripts.OnUpdate(panel)
eq(body.status.text, 'Skill 425: T5', 'top quality reached')
eq(body.status.color[1] < 0.5, true, 'shown as reached')
eq(body.concentration.text, 'Concentration: not needed', 'no concentration at the top')
eq(body.fill.shown, false, 'nothing to offer')
recipes[100].baseSkill = 300
eq(Recount(), 1, 'one question per recount')

-- Reagents and skill tried in the panel ----------------------------------------------

do
    eq(body.presetLabel.shown, true, 'the presets are labelled')
    eq(body.slotRows[1].name.text, 'Item 11', 'first quality slot')
    eq(body.slotRows[2].name.text, 'Item 21', 'second quality slot')
    eq(body.slotRows[1].buttons[3].shown, false, 'no third quality for a two-quality reagent')
    eq(body.slotRows[2].buttons[3].shown, true, 'three qualities for the other')
    eq(#body.choiceRows, 3, 'a button each for the two optional slots and the finishing one')
    eq(body.choiceRows[1].label, 'Optional', 'a slot without a name of its own')
    eq(body.choiceRows[2].label, 'Infuse with Power', 'a slot named by the game')
    eq(body.choiceRows[3].label, 'Finishing', 'the finishing slot')
    eq(body.choiceRows[1].text.text, 'Optional: as in the window', 'the button names its slot and choice')

    -- Each quality has a button and a box; the boxes start as the window is filled.
    local first, second = body.slotRows[1], body.slotRows[2]
    eq(first.buttons[0], nil, 'no button per slot for "as in the window"')
    eq(first.boxes[1].text .. '/' .. first.boxes[2].text, '0/10', 'the first slot as in the window')
    eq(second.boxes[1].text .. '/' .. second.boxes[2].text .. '/' .. second.boxes[3].text, '5/0/0', 'the second slot')
    eq(first.boxes[3].shown, false, 'no third box for a two-quality reagent')
    eq(first.buttons[2].label.color[1], 1, 'the quality a whole slot is at is marked')
    eq(first.buttons[1].label.color[1] < 1, true, 'the other is not')

    -- A whole slot at another quality: one question.
    calls.operation = 0
    local third = second.buttons[3]
    third.scripts.OnClick(third)
    eq(calls.operation, 1, 'one question per change')
    eq(body.status.text, 'Skill 365: T4, T5 needs 35 more', 'better reagent in the second slot')
    eq(body.cost.text, 'Reagents: 193g', 'and what it costs')
    eq(third.label.color[1], 1, 'the chosen quality is marked')
    eq(second.buttons[1].label.color[1] < 1, true, 'the others are not')
    eq(second.boxes[1].text .. '/' .. second.boxes[2].text .. '/' .. second.boxes[3].text, '0/0/5', 'the boxes follow')
    eq(body.scale.needs[5].text, '400', 'the scale follows')

    -- Part of a slot at another quality: typed into a box.
    local function Type(box, text)
        box.text = text
        box.scripts.OnTextChanged(box, true)
    end
    calls.operation = 0
    Type(first.boxes[2], '4')
    eq(calls.operation, 1, 'one question for a typed number')
    eq(first.boxes[1].text, '6', 'the rest of the slot stays at the other quality')
    eq(body.status.text, 'Skill 347: T4, T5 needs 53 more', 'four of ten at the better quality')
    eq(body.cost.text, 'Reagents: 169g', 'and their cost')
    eq(first.buttons[2].label.color[1] < 1, true, 'a mixed slot marks no quality')
    Type(second.boxes[2], '2')
    eq(second.boxes[1].text .. '/' .. second.boxes[2].text .. '/' .. second.boxes[3].text, '0/2/3', 'three qualities share a slot')
    eq(body.status.text, 'Skill 343: T4, T5 needs 57 more', 'counted by their shares')
    Type(second.boxes[1], '99')
    eq(second.boxes[1].text, '5', 'no more than the slot holds')
    eq(second.boxes[2].text .. '/' .. second.boxes[3].text, '0/0', 'the others give way')
    eq(body.status.text, 'Skill 327: T4, T5 needs 73 more', 'the second slot at its lowest quality')
    -- The panel filling its own boxes is not the player typing.
    calls.operation = 0
    first.boxes[1]:SetText('1')
    eq(calls.operation, 0, 'a box filled by the panel asked the game')

    -- Every slot at once.
    local presets = body.presets.buttons
    eq(presets[2].label.text, 'Highest', 'the preset for the highest quality')
    eq(presets[3].label.text, 'Lowest', 'and for the lowest')
    presets[3].scripts.OnClick(presets[3])
    eq(body.status.text, 'Skill 315: T3, T5 needs 85 more', 'lowest qualities')
    eq(body.cost.text, 'Reagents: 123g', 'are the cheapest here')
    presets[2].scripts.OnClick(presets[2])
    eq(body.status.text, 'Skill 365: T4, T5 needs 35 more', 'highest qualities')
    presets[1].scripts.OnClick(presets[1])
    eq(body.status.text, 'Skill 345: T4, T5 needs 55 more', 'back to the window')
    eq(first.boxes[1].text .. '/' .. first.boxes[2].text, '0/10', 'the boxes show the window again')

    -- Optional and finishing reagents from their lists.
    local function Menu(row)
        opened = nil
        row.scripts.OnClick(row)
        assert(opened and opened.owner == row, 'no list was opened')
        local radios = {}
        opened.generator(row, {
            CreateTitle = function(_, text) radios.title = text end,
            CreateRadio = function(_, text, isSelected, setSelected)
                radios[#radios + 1] = { text = text, selected = isSelected, pick = setSelected }
                radios[text] = radios[#radios]
            end,
        })
        return radios
    end
    local sameThree = 'Item 42 and 2 more (quality 1): difficulty +40'
    -- Until a list is opened the game is not asked about its reagents.
    S.ForgetEffects()
    calls.operation = 0
    local optional = Menu(body.choiceRows[1])
    eq(calls.operation, 5, 'opening a list asks once per reagent and once for the empty slot')
    eq(optional.title, 'Optional', 'the list is headed by its slot')
    eq(#optional, 4, 'as in the window, empty, and one line per effect instead of four reagents')
    eq(optional[3].text, 'Item 41: skill +15', 'a reagent of its own')
    eq(optional[4].text, sameThree, 'three reagents that do the same, as one line')
    assert(optional['as in the window'].selected(), 'the window\'s choice is the default')
    calls.operation = 0
    Menu(body.choiceRows[1])
    eq(calls.operation, 0, 'opening it again asks nothing')
    optional[sameThree].pick()
    eq(calls.operation, 1, 'one question for an optional reagent')
    eq(body.status.text, 'Skill 330: T3, T5 needs 110 more', 'the harder optional reagent')
    eq(body.scale.needs[5].text, '440', 'the scale shows the new threshold')
    eq(body.cost.text, 'Reagents: 263g', 'its cost')
    eq(body.choiceRows[1].text.text, 'Optional: Item 42', 'the button shows the choice')
    assert(Menu(body.choiceRows[1])[sameThree].selected(), 'and the list marks its line')
    optional['empty'].pick()
    eq(body.status.text, 'Skill 330: T4, T5 needs 70 more', 'without the optional reagent')
    eq(body.cost.text, 'Reagents: 63g', 'cheaper without it')
    eq(body.choiceRows[1].text.text, 'Optional: empty', 'the button says so')
    optional['as in the window'].pick()
    eq(body.status.text, 'Skill 345: T4, T5 needs 55 more', 'the window again')

    -- Crests are currencies: listed and usable like the rest.
    local crests = Menu(body.choiceRows[2])
    eq(crests.title, 'Infuse with Power', 'the crest list')
    eq(#crests, 4, 'as in the window, empty and the two crests')
    eq(crests[3].text, 'Crest 3001: difficulty +50', 'a crest with what it does')
    eq(crests[4].text, 'Crest 3002: difficulty +80', 'the other crest')
    crests[3].pick()
    eq(body.status.text, 'Skill 345: T3, T5 needs 105 more', 'the crest makes the recipe harder')
    eq(body.scale.needs[5].text, '450', 'on the scale too')
    eq(body.cost.text, 'Reagents: 163g', 'and costs nothing at the auction')
    eq(body.choiceRows[2].text.text, 'Infuse with Power: Crest 3001', 'the button names the crest')
    assert(Menu(body.choiceRows[2])['Crest 3001: difficulty +50'].selected(), 'the list marks it')
    assert(not Menu(body.choiceRows[2])['Crest 3002: difficulty +80'].selected(), 'and only it')
    crests['as in the window'].pick()

    Menu(body.choiceRows[3])['Item 51: skill +5'].pick()
    eq(body.status.text, 'Skill 350: T4, T5 needs 50 more', 'a finishing reagent')
    eq(body.fill.label.text, '+50', 'the offer follows')

    -- Another skill: arithmetic only.
    calls.operation = 0
    body.extra:SetText('10')
    eq(body.status.text, 'Skill 360: T4, T5 needs 40 more', 'ten more skill')
    eq(body.concentration.text, 'Concentration: known for your real skill only', 'no price for a made-up skill')
    body.extra:SetText('-40')
    eq(body.status.text, 'Skill 310: T3, T5 needs 90 more', 'less skill')
    eq(body.scale.names[4].color[2] < 0.8, true, 'the scale unmarks what is no longer reached')
    body.fill.scripts.OnClick(body.fill)
    eq(body.extra.text, '50', 'the missing skill put in')
    eq(body.status.text, 'Skill 400: T5', 'reaches the top')
    eq(body.concentration.text, 'Concentration: not needed', 'no concentration at the top')
    eq(body.fill.label.text, '+50', 'the offer stays what the reagents lack')
    body.extra:SetText('nonsense')
    eq(body.status.text, 'Skill 350: T4, T5 needs 50 more', 'nonsense is no change')
    eq(calls.operation, 0, 'the game was not asked about another skill')

    -- A price that is not known is said so.
    prices[51] = nil
    presets[1].scripts.OnClick(presets[1])
    eq(body.cost.text, 'Reagents: 163g (some prices unknown)', 'an incomplete cost')
    prices[51] = 500000

    -- Reagents changed in the window: what was not chosen here follows.
    allocation = { { reagent = { itemID = 11 }, dataSlotIndex = 1, quantity = 10 } }
    eq(Recount(), 1, 'recounted with the window')
    eq(body.status.text, 'Skill 305: T3, T5 needs 95 more', 'the window\'s new reagents with the chosen finishing one')
    allocation = window

    -- Another recipe starts with its own, empty choices.
    selected, allocation = 300, {}
    Recount()
    eq(body.recipe.text, 'Thread', 'the other recipe')
    eq(body.presets.shown, false, 'no presets without quality slots')
    eq(body.presetLabel.shown, false, 'nor their label')
    eq(body.slotRows[1].shown, false, 'no quality rows')
    eq(body.choiceRows[1].shown, false, 'no optional lists')
    eq(body.extra.text, '', 'the other skill starts empty')
    eq(body.status.text, 'Skill 200: T2, T3 needs 101 more', 'a three-quality recipe')
    eq(body.scale.names[4].shown, false, 'no fourth quality on its scale')
    eq(body.scale.needs[3].text, '301', 'its top threshold')
    local shortPanel = panel.height
    selected, allocation = 100, window
    Recount()
    eq(body.status.text, 'Skill 345: T4, T5 needs 55 more', 'earlier choices are not carried back')
    eq(body.choiceRows[1].label, 'Optional', 'its lists are back')
    assert(panel.height > shortPanel, 'the panel grows with the recipe\'s rows')

    -- A name the game does not have yet is asked for once and put in when it comes.
    unloaded[11] = true
    selected = 300; Recount(); selected = 100; Recount()
    eq(body.slotRows[1].name.text, '#11', 'a placeholder meanwhile')
    Recount()
    eq(nameRequests[11], 1, 'asked once')
    unloaded[11] = nil
    calls.operation = 0
    body.scripts.OnEvent(body, 'ITEM_DATA_LOAD_RESULT', 999, true)
    eq(body.slotRows[1].name.text, '#11', 'another item\'s name changes nothing')
    body.scripts.OnEvent(body, 'ITEM_DATA_LOAD_RESULT', 11, true)
    eq(body.slotRows[1].name.text, 'Item 11', 'the name was put in')
    eq(calls.operation, 0, 'without asking about the craft')
end
print('Craft simulation passed (one question per change, scale, qualities, presets, lists by effect, crests, +N skill, cost, recipe changes, names).')

-- Recipes with nothing to show give a message instead of numbers.
selected = 200
Recount()
eq(panel.message.shown, true, 'a message for a recipe without quality')
eq(panel.message.text, 'This recipe has no quality.', 'which says so')
eq(body.shown, false, 'numbers hidden')
eq(calls.operation, 0, 'and the game is not asked')
selected = 400
Recount()
eq(panel.message.text, 'No data for this recipe.', 'no answer from the game')
eq(body.shown, false, 'numbers hidden again')
selected = nil
Recount()
eq(panel.message.text, 'Select a recipe.', 'nothing selected')
-- A recraft is not counted.
selected, allocation = 100, window
recipes[100].info.isRecraft = true
Recount()
eq(panel.message.text, 'No data for this recipe.', 'a recraft')
recipes[100].info.isRecraft = nil
Recount()
eq(body.shown, true, 'numbers back')
eq(panel.message.shown, false, 'message gone')

-- Moved: remembered relative to the profession window.
local drag
for _, frame in ipairs(frames) do
    if frame.parent == panel and frame.scripts.OnDragStop then drag = frame end
end
assert(drag, 'the panel cannot be moved')
panel.left, panel.top = 950, 600
drag.scripts.OnDragStop(drag)
eq(saved.x, 50, 'horizontal offset saved')
eq(saved.y, -100, 'vertical offset saved')
eq(panel.points.TOPLEFT[3], 50, 'placed by the saved offset')

-- Closed again: nothing is counted, and it stays closed.
local close
for _, frame in ipairs(frames) do
    if frame.parent == panel and frame.template == 'UIPanelCloseButton' then close = frame end
end
close.scripts.OnClick(close)
eq(panel.shown, false, 'closed')
eq(saved.shown, false, 'remembered as closed')
calls.operation = 0
callbacks.alloc()
for _, hook in ipairs(hooks) do hook.fn() end
eq(calls.operation, 0, 'asked while closed')
toggle.scripts.OnShow(toggle)
eq(panel.shown, false, 'reopened by itself though it was closed')

-- Left open: comes back with the crafting page.
toggle.scripts.OnClick(toggle)
eq(panel.shown, true, 'opened again')
panel.shown = false
toggle.scripts.OnShow(toggle)
eq(panel.shown, true, 'not reopened with the crafting page')

print('Craft simulator panel passed (lazy build, idle cost, messages, moving, closing).')

-- The other view: what the specializations give the recipe -------------------------

local traitCalls = 0
local bladesRank = 16 -- as the game counts: one more than the ranks
C_TradeSkillUI.GetProfessionChildSkillLineID = function() return 2900 end
C_ProfSpecs = {
    GetConfigIDForSkillLine = function(skillLine) return skillLine == 2900 and 7 or 0 end,
    GetUnlockRankForPerk = function(perkID) return ({ [12] = 10, [14] = 25 })[perkID] or 0 end,
    GetCurrencyInfoForSkillLine = function() return { numAvailable = 3 } end,
}
C_Traits = {
    GetNodeInfo = function(_, nodeID)
        traitCalls = traitCalls + 1
        if nodeID == 10 then return { activeRank = bladesRank, maxRanks = 31, entryIDs = { 1 } } end
        if nodeID == 20 then return { activeRank = 0, maxRanks = 21, entryIDs = { 2 } } end
        return { activeRank = 0, maxRanks = 0 }
    end,
    GetEntryInfo = function(_, entryID) return { definitionID = entryID } end,
    GetDefinitionInfo = function(definitionID) return { overrideName = definitionID == 1 and 'Blades' or 'Hilts' } end,
}
PT.SpecStats = {
    nodes = {
        [10] = { 10, 30, { skill = 1 } }, [11] = { 10, 1, { skill = 5 } }, [12] = { 10, 1, { skill = 10 } },
        [13] = { 10, 1, { multicraft = 20 } }, [14] = { 10, 1, { skill = 40 } },
        [20] = { 20, 20, {} }, [21] = { 20, 1, { reduceconcentrationcost = 4 } },
    },
    recipes = { [100] = { 10, 20, 11, 12, 13, 14, 21 }, [200] = { 10, 11 } },
    icons = { [10] = 111 },
}

selected, allocation = 100, window
eq(Recount(), 1, 'the craft view counts as before')
eq(traitCalls, 0, 'the specializations were asked while the other view is shown')
eq(body.specNote.shown, false, 'no ranks are tried')
local tabs, spec = panel.tabs, panel.spec
assert(tabs and tabs.craft and tabs.spec, 'no tabs for the two views')
eq(tabs.craft.label.text, 'Simulation', 'first tab')
eq(tabs.spec.label.text, 'Specialization', 'second tab')
eq(tabs.craft.label.color[2], 0.82, 'the view shown is marked')
eq(tabs.spec.label.color[2], 0.62, 'the other is not')
eq(spec.shown, false, 'the other view is hidden')

tabs.spec.scripts.OnClick(tabs.spec)
eq(saved.tab, 'spec', 'the view is remembered')
eq(tabs.spec.label.color[2], 0.82, 'the tab is marked')
eq(tabs.craft.label.color[2], 0.62, 'and the other unmarked')
calls.operation = 0
panel.scripts.OnUpdate(panel)
eq(spec.shown, true, 'the specialization view is shown')
eq(body.shown, false, 'instead of the craft')
eq(panel.message.shown, false, 'without a message')
eq(calls.operation, 2, 'two questions the first time: which stats the recipe has, and the craft')
eq(spec.recipe.text, 'Blade', 'recipe name')
eq(spec.recipe.font, 'Addon/default.ttf', 'the addon\'s font')
-- The craft as the other view has it.
eq(spec.scale.shown, true, 'the scale of the craft')
eq(spec.scale.needs[5].text, '400', 'with the top quality\'s threshold')
eq(spec.status.text, 'Skill 345: T4, T5 needs 55 more', 'and what the craft comes to')
eq(spec.note.text, 'Change a rank below to try it', 'a hint while nothing is tried')
eq(spec.statRows[1].label.text, 'Skill', 'first stat')
eq(spec.statRows[1].value.text, '30 / 85', 'now and with everything maxed')
eq(spec.statRows[1].value.color[2], 1, 'not all of it yet')
eq(spec.statRows[2].label.text, 'Less concentration use', 'a percent stat')
eq(spec.statRows[2].value.text, '0% / 4%', 'as percents')
eq(spec.statRows[3], nil, 'no multicraft for a recipe without it')
local blades, hilts = spec.nodeRows[1], spec.nodeRows[2]
eq(blades.name.text, 'Blades', 'the node furthest along')
eq(blades.box.text, '15', 'its rank in a box')
eq(blades.max.text, '/ 30', 'out of how many')
eq(blades.box.color[2], 1, 'the character\'s own rank')
eq(hilts.name.text, 'Hilts', 'a node not unlocked')
eq(hilts.box.text, '-', 'has no rank')
eq(hilts.name.color[1], 0.62, 'and is greyed')
eq(spec.more.shown, false, 'nothing left out')
assert(panel.height > 58 + 120, 'the panel is not sized around the view')
eq(Recount(), 1, 'a recount asks once, about the craft')

-- What a node gives and where.
tips = {}
blades.scripts.OnEnter(blades)
eq(tips[1], 'Blades  15 / 30', 'the node and its rank')
eq(tips[2], 'Each rank: +1 Skill', 'what a rank gives')
eq(tips[3], 'Rank 0: +5 Skill', 'what is gained at which rank')
eq(tips[4], 'Rank 10: +10 Skill', 'in order')
eq(tips[5], 'Rank 25: +40 Skill', 'the one not reached yet too')
eq(#tips, 6, 'and how to try a rank; nothing about stats the recipe does not have')

-- A rank typed in the box is tried in place of the character's own.
local function Type(row, text)
    row.box.text = text
    row.box.scripts.OnTextChanged(row.box, true)
    panel.scripts.OnUpdate(panel)
end
Type(blades, '25')
eq(spec.statRows[1].value.text, '80 (+50) / 85', 'the skill with the rank tried')
eq(spec.statRows[1].value.color[2], 0.82, 'marked as tried')
eq(spec.status.text, 'Skill 395: T4, T5 needs 5 more', 'the craft with that skill')
eq(spec.scale.names[4].color[2] > 0.8, true, 'the scale follows')
eq(spec.note.text, 'Tried: +50 skill, +10 points (3 unspent)', 'what is tried and what it takes')
eq(blades.box.text, '25', 'the box keeps the rank')
eq(blades.box.color[2], 0.82, 'marked as tried')
tips = {}
blades.scripts.OnEnter(blades)
eq(tips[1], 'Blades  25 / 30', 'the tooltip shows the rank tried')
eq(tips[2], 'Your rank: 15', 'and the character\'s own')
Type(blades, '30')
eq(spec.status.text, 'Skill 400: T5', 'enough ranks for the top quality')
eq(spec.statRows[1].value.text, '85 (+55) / 85', 'all the skill')
eq(spec.statRows[1].value.color[1], 0.35, 'marked as all of it')
eq(spec.note.text, 'Tried: +55 skill, +15 points (3 unspent)', 'for this many points')
eq(blades.name.color[1], 0.35, 'the node shown as maxed')
Type(blades, '99')
eq(blades.box.text, '30', 'no more ranks than the node has')
-- A box emptied to type another rank changes nothing, and gets its rank back.
blades.box.text = ''
blades.box.scripts.OnTextChanged(blades.box, true)
panel.scripts.OnUpdate(panel)
eq(spec.status.text, 'Skill 400: T5', 'an empty box is not a rank')
blades.box.scripts.OnEditFocusLost(blades.box)
panel.scripts.OnUpdate(panel)
eq(blades.box.text, '30', 'the rank is put back')
Type(blades, 'x')
eq(spec.status.text, 'Skill 400: T5', 'nor is nonsense')

-- A node unlocked for a try costs no points; "-" locks it again.
Type(hilts, '0')
eq(spec.statRows[2].value.text, '4% (+4%) / 4%', 'what unlocking gives')
eq(spec.note.text, 'Tried: +55 skill, +15 points (3 unspent)', 'for free')
eq(hilts.name.color[2], 1, 'no longer greyed')
Type(hilts, '-')
eq(spec.statRows[2].value.text, '0% / 4%', 'locked again')
eq(hilts.box.color[2], 1, 'which is how it is')

-- Fewer ranks than the character has: where points could have been saved.
Type(blades, '9')
eq(spec.status.text, 'Skill 329: T4, T5 needs 71 more', 'the craft with fewer ranks')
eq(spec.note.text, 'Tried: -16 skill, -6 points', 'what it would save')

-- The ranks tried count in the craft view too.
Type(blades, '25')
tabs.craft.scripts.OnClick(tabs.craft)
traitCalls = 0
panel.scripts.OnUpdate(panel)
eq(body.shown, true, 'the craft view')
eq(body.status.text, 'Skill 395: T4, T5 needs 5 more', 'with the ranks tried')
eq(body.specNote.shown, true, 'and it says so')
eq(body.specNote.text, 'With the ranks tried: +50 skill', 'by how much')
eq(body.concentration.text, 'Concentration: known for your real skill only', 'no price for a skill that is not real')
eq(body.fill.label.text, '+5', 'the offer counts from the tried skill')
assert(traitCalls > 0, 'the ranks were not read')
body.extra:SetText('5')
eq(body.status.text, 'Skill 400: T5', 'more skill on top of the ranks')
tabs.spec.scripts.OnClick(tabs.spec)
panel.scripts.OnUpdate(panel)
eq(spec.status.text, 'Skill 400: T5', 'which the other view counts as well')
tabs.craft.scripts.OnClick(tabs.craft)
panel.scripts.OnUpdate(panel)
body.extra:SetText('')
tabs.spec.scripts.OnClick(tabs.spec)
panel.scripts.OnUpdate(panel)
eq(spec.status.text, 'Skill 395: T4, T5 needs 5 more', 'back to the ranks alone')

-- All of the recipe's nodes at once, and back.
local specPresets = spec.presets.buttons
eq(specPresets[1].label.text, 'Your ranks', 'first preset')
eq(specPresets[2].label.text, 'All maxed', 'second preset')
specPresets[2].scripts.OnClick(specPresets[2])
panel.scripts.OnUpdate(panel)
eq(blades.box.text, '30', 'every node maxed')
eq(hilts.box.text, '20', 'the locked one too')
eq(spec.note.text, 'Tried: +55 skill, +35 points (3 unspent)', 'and what that takes')
eq(spec.status.text, 'Skill 400: T5', 'the craft with everything')
specPresets[1].scripts.OnClick(specPresets[1])
panel.scripts.OnUpdate(panel)
eq(blades.box.text, '15', 'the character\'s own ranks again')
eq(hilts.box.text, '-', 'locked as it is')
eq(spec.note.text, 'Change a rank below to try it', 'nothing tried')
eq(spec.statRows[1].value.text, '30 / 85', 'the stats as they are')
eq(spec.status.text, 'Skill 345: T4, T5 needs 55 more', 'and the craft')
tabs.craft.scripts.OnClick(tabs.craft)
traitCalls = 0
panel.scripts.OnUpdate(panel)
eq(body.specNote.shown, false, 'nothing tried in the craft view either')
eq(body.status.text, 'Skill 345: T4, T5 needs 55 more', 'the craft as it is')
eq(traitCalls, 0, 'and the specializations are not asked')
tabs.spec.scripts.OnClick(tabs.spec)
panel.scripts.OnUpdate(panel)

-- Ranks gained for real: the view follows.
bladesRank = 31
fire('TRAIT_CONFIG_UPDATED')
panel.scripts.OnUpdate(panel)
eq(spec.statRows[1].value.text, '85 / 85', 'all the skill')
eq(spec.statRows[1].value.color[1], 0.35, 'marked as reached')
eq(blades.box.text, '30', 'the node maxed')
eq(blades.max.color[1], 0.35, 'and marked')
bladesRank = 16

-- Quality does not matter here: without it there is no craft to show.
selected = 200
Recount()
eq(spec.shown, true, 'a recipe without quality has specializations too')
eq(spec.recipe.text, 'Bandage', 'its name')
eq(spec.scale.shown, false, 'no scale')
eq(spec.status.shown, false, 'and no craft')
eq(spec.statRows[1].value.text, '20 / 35', 'its skill')
eq(spec.statRows[2].shown, false, 'rows it does not have are hidden')
eq(hilts.shown, false, 'nodes too')

-- A long list is cut short and says so.
do
    local many = {}
    for index = 1, 20 do
        PT.SpecStats.nodes[1000 + index] = { 1000 + index, 10, { skill = 1 } }
        PT.SpecStats.nodes[2000 + index] = { 1000 + index, 1, { skill = 1 } }
        many[#many + 1] = 1000 + index
    end
    for index = 1, 20 do many[#many + 1] = 2000 + index end
    PT.SpecStats.recipes[200] = many
    local nodeInfo = C_Traits.GetNodeInfo
    C_Traits.GetNodeInfo = function(_, nodeID) return { activeRank = 1, maxRanks = 11, entryIDs = { nodeID } } end
    Recount()
    eq(#spec.nodeRows, 16, 'no more rows than fit')
    eq(spec.more.shown, true, 'the rest is mentioned')
    eq(spec.more.text, 'and 4 more', 'by number')
    eq(spec.statRows[1].value.text, '20 / 220', 'but all of them are counted')
    -- The preset reaches the ones not listed as well.
    specPresets[2].scripts.OnClick(specPresets[2])
    panel.scripts.OnUpdate(panel)
    eq(spec.statRows[1].value.text, '220 (+200) / 220', 'every node maxed, listed or not')
    eq(spec.note.text, 'Tried: +200 skill, +200 points (3 unspent)', 'and what it takes')
    specPresets[1].scripts.OnClick(specPresets[1])
    C_Traits.GetNodeInfo = nodeInfo
    PT.SpecStats.recipes[200] = { 10, 11 }
end

-- Nothing to show says so.
selected = 300
Recount()
eq(panel.message.shown, true, 'a message for a recipe the specializations do not affect')
eq(panel.message.text, 'No specialization of yours affects this recipe.', 'which says so')
eq(spec.shown, false, 'the view is hidden')
eq(body.shown, false, 'and so is the craft')
selected = nil
Recount()
eq(panel.message.text, 'Select a recipe.', 'nothing selected')

-- Back to the craft: the specializations are not asked.
selected = 100
tabs.craft.scripts.OnClick(tabs.craft)
eq(saved.tab, 'craft', 'the craft view is remembered')
traitCalls, calls.operation = 0, 0
panel.scripts.OnUpdate(panel)
eq(body.shown, true, 'the craft is back')
eq(spec.shown, false, 'the specialization view is hidden')
eq(panel.message.shown, false, 'no message')
eq(calls.operation, 1, 'one question for the craft')
eq(traitCalls, 0, 'the specializations were asked for the craft view')
eq(body.status.text, 'Skill 345: T4, T5 needs 55 more', 'the craft as it was')

print('Specialization view passed (tabs, the craft, stats, nodes, ranks tried in both views, presets, tooltip, long lists, messages, counted only when shown).')

-- The panel is in English whatever the addon's language is.
do
    local function Slurp(path)
        local file = assert(io.open(path, 'rb'))
        local text = file:read('*a')
        file:close()
        return text
    end
    assert(not Slurp('Workflow/Core/Locales/ruRU.lua'):find('L%["CRAFTSIM_'), 'the panel has Russian strings again')
    local english = Slurp('Workflow/Core/Locales/enUS.lua')
    for _, key in ipairs({ 'CRAFTSIM_TITLE', 'CRAFTSIM_TAB_SPEC', 'CRAFTSIM_SPEC_TRIED', 'CRAFTSIM_SPEC_OWN' }) do
        assert(english:find('L["' .. key .. '"]', 1, true), key .. ' is missing from the English strings')
    end
end

-- A recipe with a required slot that takes one of several reagents ---------------------

do
    local function Menu(row)
        opened = nil
        row.scripts.OnClick(row)
        assert(opened and opened.owner == row, 'no list was opened')
        local radios = {}
        opened.generator(row, {
            CreateTitle = function(_, text) radios.title = text end,
            CreateRadio = function(_, text, isSelected, setSelected)
                radios[#radios + 1] = { text = text, selected = isSelected, pick = setSelected }
                radios[text] = radios[#radios]
            end,
        })
        return radios
    end
    S.ForgetEffects()
    selected, allocation = 500, {}
    eq(Recount(), 1, 'one question for such a recipe')
    eq(body.shown, true, 'it is counted')
    eq(panel.message.shown, false, 'without a message')
    eq(body.recipe.text, 'Amulet', 'its name')
    eq(body.status.text, 'Skill 180: T5', 'and its own numbers, not the last recipe\'s')
    eq(body.scale.needs[5].text, '170', 'on the scale too')
    eq(body.presets.shown, true, 'presets for its quality reagent')
    eq(body.slotRows[1].shown, true, 'which has a row')
    eq(body.slotRows[1].name.text, 'Item 101', 'under its name')
    eq(body.slotRows[1].boxes[1].text, '5', 'counted at the lowest quality while nothing is chosen')
    eq(body.slotRows[2].shown, false, 'the other required slots have no quality row')
    eq(body.choiceRows[1].shown, true, 'but a list each')
    eq(body.choiceRows[1].text.text, 'Item 91: as in the window', 'named after its first reagent')
    eq(body.choiceRows[2].text.text, 'Setting: as in the window', 'or as the game names the slot')
    eq(body.choiceRows[3].shown, false, 'and no other lists')

    local list = Menu(body.choiceRows[1])
    eq(list.title, 'Item 91', 'the list is headed like its button')
    eq(#list, 4, 'as in the window, empty, and one line per effect instead of six reagents')
    eq(list[3].text, 'Item 91 and 2 more: no effect on skill', 'the reagents that change nothing')
    eq(list[4].text, 'Item 94 and 2 more: difficulty +30', 'and those that make the recipe harder')
    list[4].pick()
    eq(body.status.text, 'Skill 180: T4, T5 needs 20 more', 'the chosen reagent makes it harder')
    eq(body.scale.needs[5].text, '200', 'the scale follows')
    eq(body.choiceRows[1].text.text, 'Item 91: Item 94', 'the button names the choice')
    local quantity
    for _, entry in ipairs(calls.last) do
        if entry.dataSlotIndex == 11 then quantity = entry.quantity end
    end
    eq(quantity, 3, 'in the amount the slot asks for')

    -- The presets are about qualities: the chosen reagent stays.
    local presets = body.presets.buttons
    presets[2].scripts.OnClick(presets[2])
    eq(body.status.text, 'Skill 200: T5', 'the highest quality with the chosen reagent')
    eq(body.choiceRows[1].text.text, 'Item 91: Item 94', 'which is kept')
    presets[1].scripts.OnClick(presets[1])
    eq(body.status.text, 'Skill 180: T4, T5 needs 20 more', 'back to the window\'s qualities')
    Menu(body.choiceRows[1])['empty'].pick()
    eq(body.status.text, 'Skill 180: T5', 'the slot left empty')
    S.ForgetEffects()
end

-- A view that fails reports it and says there is no data: it does not leave
-- the numbers of the recipe shown before.
do
    local reported = {}
    geterrorhandler = function() return function(message) reported[#reported + 1] = message end end
    local showCraft = UI.ShowCraft
    UI.ShowCraft = function() error('broken view') end
    selected, allocation = 100, window
    Recount()
    eq(#reported, 1, 'the failure is reported')
    assert(tostring(reported[1]):find('broken view', 1, true), 'with what went wrong')
    eq(panel.message.shown, true, 'a message instead')
    eq(panel.message.text, 'No data for this recipe.', 'saying there is no data')
    eq(body.shown, false, 'and no numbers of another recipe')
    UI.ShowCraft = showCraft
    Recount()
    eq(#reported, 1, 'nothing more to report')
    eq(body.shown, true, 'counted again once it works')
    eq(body.status.text, 'Skill 345: T4, T5 needs 55 more', 'with the right numbers')
    geterrorhandler = nil
end

print('Slots with a choice of reagents passed (a list instead of quality boxes, presets leave it alone); a failing view shows no stale numbers.')
