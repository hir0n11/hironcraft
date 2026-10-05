-- The craft simulator: the skill a recipe needs for each quality, what the
-- window's, the best and the plainest reagents give, and the panel that
-- shows it without costing anything while it is closed.
local function eq(actual, expected, what)
    if actual ~= expected then
        error((what or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
    end
end

-- A small model of the game's crafting -------------------------------------------

Enum = { CraftingReagentType = { Modifying = 0, Basic = 1, Finishing = 2, Automatic = 3 } }
local BASIC, OPTIONAL, FINISHING = 1, 0, 2

-- Skill a full slot of an item adds, and difficulty an optional reagent adds.
local SKILL = { [12] = 30, [22] = 10, [23] = 20, [41] = 15, [51] = 5 }
local DIFFICULTY = { [42] = 40 }
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
                reagents = { { itemID = 41 }, { itemID = 42 } } },
            { slotIndex = 5, dataSlotIndex = 5, required = false, quantityRequired = 1, reagentType = FINISHING,
                reagents = { { itemID = 51 } } },
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
    GetCraftingOperationInfo = function(recipeID, reagents, _, applyConcentration)
        calls.operation = calls.operation + 1
        local recipe = recipes[recipeID]
        if not recipe or recipe.silent then return nil end
        local bonusSkill, bonusDifficulty = 0, 0
        for _, entry in ipairs(reagents or {}) do
            local itemID = entry.reagent and entry.reagent.itemID
            local slotQuantity = SLOT_QUANTITY[entry.dataSlotIndex] or entry.quantity or 1
            bonusSkill = bonusSkill + (SKILL[itemID] or 0) * (entry.quantity or 1) / slotQuantity
            bonusDifficulty = bonusDifficulty + (DIFFICULTY[itemID] or 0)
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
HironCraftProfit = { L = {}, FONT = 'Addon/default.ttf',
    Prices = { GetItemPrice = function(_, itemID) return prices[itemID] end } }
SlashCmdList = {}
assert(loadfile('ProfitHub/Core/CraftEngine/Engine.lua'))()
assert(loadfile('ProfitHub/Core/CraftEngine/Simulator.lua'))()
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

-- One recipe: the window's reagents, the best, the plainest ------------------------

local window = {
    { reagent = { itemID = 12 }, dataSlotIndex = 1, quantity = 10 }, -- slot 1 at quality 2
    { reagent = { itemID = 21 }, dataSlotIndex = 2, quantity = 5 },  -- slot 2 at quality 1
    { reagent = { itemID = 41 }, dataSlotIndex = 4, quantity = 1 },  -- an optional reagent
}
do
    calls.operation = 0
    local summary = assert(S.Summary(100, window))
    eq(calls.operation, 3, 'three questions to the game')
    local current, best, plain = summary.current, summary.best, summary.plain
    eq(summary.maxQuality, 5, 'qualities')
    eq(current.difficulty, 400, 'difficulty')
    eq(current.skill, 345, 'skill with the window\'s reagents')
    eq(current.ownSkill, 300, 'own skill')
    eq(current.reagentSkill, 45, 'skill from reagents')
    eq(current.quality, 4, 'quality now')
    eq(current.missingToMax, 55, 'short of the top quality')
    eq(current.nextQuality, 5, 'next quality')
    eq(current.missingToNext, 55, 'short of the next quality')
    eq(current.concentrationCost, 275, 'concentration for the next quality')
    eq(table.concat(current.thresholds, ','), '0,80,200,320,400', 'thresholds')
    -- The best reagents: both slots at their top quality, the optional one kept.
    eq(best.skill, 365, 'skill with the best reagents')
    eq(best.quality, 4, 'still not the top')
    eq(best.missingToMax, 35, 'what even the best lack')
    -- The plainest: both at quality 1, the optional one kept.
    eq(plain.skill, 315, 'skill with the plainest reagents')
    eq(plain.quality, 3, 'one quality lower')
    eq(plain.missingToMax, 85, 'short of the top with the plainest')
    eq(plain.concentrationCost, 25, 'concentration from the plainest')
end

-- A slot filled with two qualities at once is taken as it is for "now".
do
    local mixed = {
        { reagent = { itemID = 11 }, dataSlotIndex = 1, quantity = 5 },
        { reagent = { itemID = 12 }, dataSlotIndex = 1, quantity = 5 },
        { reagent = { itemID = 23 }, dataSlotIndex = 2, quantity = 5 },
    }
    local summary = assert(S.Summary(100, mixed))
    eq(summary.current.skill, 335, 'half a slot of the better reagent counts half')
    eq(summary.best.skill, 350, 'the best replaces the mix')
    eq(summary.plain.skill, 300, 'the plainest replaces it too')
end

-- An optional reagent that makes the recipe harder moves every threshold.
do
    local harder = { { reagent = { itemID = 42 }, dataSlotIndex = 4, quantity = 1 } }
    local summary = assert(S.Summary(100, harder))
    eq(summary.current.difficulty, 440, 'difficulty with the optional reagent')
    eq(summary.current.thresholds[5], 440, 'the top quality needs all of it')
    eq(summary.best.difficulty, 440, 'the comparison keeps the optional reagent')
    eq(summary.best.skill, 350, 'best reagents under the harder recipe')
    eq(summary.best.missingToMax, 90, 'short of the top')
end

-- Nothing chosen in the window.
do
    local summary = assert(S.Summary(100, nil))
    eq(summary.current.skill, 300, 'bare skill')
    eq(summary.current.quality, 3, 'quality with nothing chosen')
end

-- The top quality reached: nothing is missing and no concentration is needed.
do
    recipes[100].baseSkill = 380
    local summary = assert(S.Summary(100, window))
    eq(summary.current.quality, 5, 'top quality')
    eq(summary.current.missingToMax, 0, 'nothing missing')
    eq(summary.current.nextQuality, nil, 'no next quality')
    eq(summary.current.concentrationCost, nil, 'no concentration')
    recipes[100].baseSkill = 300
end

-- Where the game's own thresholds differ, they are the ones shown.
do
    upperShift = 3
    local summary = assert(S.Summary(100, window))
    eq(summary.current.thresholds[5], 403, 'the game\'s threshold for the next quality')
    eq(summary.current.missingToMax, 58, 'counted from the game\'s threshold')
    upperShift = 0
end

-- A different skill: only arithmetic, no concentration price.
do
    local answer = CE:Evaluate(100, window, { useConcentration = false })
    calls.operation = 0
    local more = S.Describe(5, answer, 55)
    eq(more.skill, 400, 'skill with +55')
    eq(more.quality, 5, 'reaches the top')
    eq(more.missingToMax, 0, 'nothing missing')
    eq(more.concentrationCost, nil, 'no concentration price for a made-up skill')
    local almost = S.Describe(5, answer, 54)
    eq(almost.quality, 4, 'one short stays below')
    eq(almost.missingToMax, 1, 'one missing')
    local less = S.Describe(5, answer, -30)
    eq(less.skill, 315, 'skill with -30')
    eq(less.quality, 3, 'drops a quality')
    eq(less.missingToNext, 5, 'short of the next one')
    eq(calls.operation, 0, 'the game was not asked')
    eq(S.Describe(5, nil), nil, 'no answer, no result')
    eq(S.Describe(5, { skill = 10 }), nil, 'an answer without difficulty')
end

-- Recipes with nothing to show.
do
    local summary, reason = S.Summary(200, {})
    eq(summary, nil, 'a recipe without quality')
    eq(reason, 'no_quality', 'and why')
    summary, reason = S.Summary(400, {})
    eq(summary, nil, 'a recipe the game is silent about')
    eq(reason, 'no_data', 'and why')
    summary, reason = S.Summary(999, {})
    eq(reason, 'no_data', 'an unknown recipe')
    eq(select(2, S.Summary(nil)), 'no_data', 'no recipe')
    -- Nothing to choose: one question, no comparison.
    calls.operation = 0
    summary = assert(S.Summary(300, {}))
    eq(calls.operation, 1, 'one question when there is no choice of reagents')
    eq(summary.best, nil, 'no comparison')
    eq(summary.current.quality, 2, 'three-quality recipe')
    eq(summary.current.thresholds[3], 301, 'its top threshold')
    eq(summary.current.missingToMax, 101, 'short of its top')
end

-- A simulated craft: chosen qualities and optional reagents over the window's.
do
    local basics = CE:GetRecipeBasics(100)
    local function ids(reagents)
        local list = {}
        for _, entry in ipairs(reagents) do
            list[#list + 1] = entry.dataSlotIndex .. ':' .. entry.reagent.itemID .. 'x' .. entry.quantity
        end
        table.sort(list)
        return table.concat(list, ' ')
    end
    eq(ids(S.SimulatedReagents(basics, window, {})), '1:12x10 2:21x5 4:41x1', 'no choices: the window as it is')
    eq(ids(S.SimulatedReagents(basics, window, { tiers = { [2] = 3 } })), '1:12x10 2:23x5 4:41x1', 'one slot at another quality')
    eq(ids(S.SimulatedReagents(basics, window, { tiers = { [1] = 9, [2] = 0 } })), '1:12x10 2:21x5 4:41x1', 'qualities kept within the slot\'s range')
    eq(ids(S.SimulatedReagents(basics, window, { items = { [4] = 42, [5] = 51 } })), '1:12x10 2:21x5 4:42x1 5:51x1', 'optional and finishing reagents chosen')
    eq(ids(S.SimulatedReagents(basics, window, { items = { [4] = false } })), '1:12x10 2:21x5', 'an optional slot emptied')
    eq(ids(S.SimulatedReagents(basics, nil, { tiers = { [1] = 1 } })), '1:11x10', 'nothing in the window')

    -- Cost: the chosen reagents and the one without a choice (item 31).
    local total, complete = S.Cost(basics, window)
    eq(total, 500000 + 100000 + 1000000 + 30000, 'cost of the window\'s reagents')
    eq(complete, true, 'every price known')
    prices[41] = nil
    total, complete = S.Cost(basics, window)
    eq(total, 630000, 'cost without the unknown price')
    eq(complete, false, 'marked as incomplete')
    prices[41] = 1000000

    calls.operation = 0
    local simulation = assert(S.Simulate(100, basics, window, { tiers = { [2] = 3 }, items = { [5] = 51 } }))
    eq(calls.operation, 1, 'one question for a simulated craft')
    eq(simulation.cost, 500000 + 400000 + 1000000 + 500000 + 30000, 'its cost')
    local real = S.Outcome(simulation, 0)
    eq(real.skill, 370, 'its skill')
    eq(real.quality, 4, 'its quality')
    eq(real.missingToMax, 30, 'what it lacks')
    eq(real.concentrationCost, 150, 'its concentration')
    local more = S.Outcome(simulation, 30)
    eq(more.quality, 5, 'with the missing skill added')
    eq(more.concentrationCost, nil, 'no concentration price for a made-up skill')
    eq(calls.operation, 1, 'another skill asks nothing')
    eq(S.Outcome(nil, 5), nil, 'no simulation, no outcome')
    eq(S.Simulate(400, CE:GetRecipeBasics(400), {}, {}), nil, 'a recipe the game is silent about')
end

print('Craft simulator passed (thresholds, window/best/plain reagents, mixes, optional reagents, top quality, game thresholds, +N skill, empty cases, simulated crafts, cost).')

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
    function methods:SetupMenu(fn) self.menu = fn end
    function methods:GenerateMenu() self.generated = (self.generated or 0) + 1 end
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
HironCraftProfit_DB = nil

local before = #frames
assert(loadfile('ProfitHub/Core/UI/CraftSimulator_UI.lua'))()
local UI = S.UI
eq(#frames, before + 1, 'only the event frame exists after loading')
assert(loadfile('ProfitHub/Core/UI/CraftSimulator_Sim.lua'))()
eq(#frames, before + 1, 'the simulation builds nothing at load')
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
local form = Frame('Frame', nil, page)
ProfessionsFrame.CraftingPage, page.SchematicForm = page, form
function page:SelectRecipe() end
function form:UpdateDetailsStats() end
function form:GetRecipeInfo() return selected and recipes[selected].info or nil end
function form:GetTransaction()
    return { CreateCraftingReagentInfoTbl = function() return allocation end }
end
function form:RegisterCallback(event, fn, owner) callbacks[event] = fn end

calls.operation, calls.schematic = 0, 0
fire('ADDON_LOADED', 'Blizzard_Professions')
local toggle
for index = before + 2, #frames do
    if frames[index].kind == 'Button' and frames[index].parent == page then toggle = frames[index] end
end
assert(toggle, 'no button to open the panel')
eq(toggle.points.TOPLEFT[1], ProfessionsFrame, 'the button hangs on the profession window')
eq(toggle.points.TOPLEFT[2], 'TOPRIGHT', 'outside its right edge')
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
eq(panel.shown, true, 'shown')
eq(HironCraftProfit_DB.craftSimulator.shown, true, 'remembered as open')
eq(panel.points.TOPLEFT[1], ProfessionsFrame, 'beside the profession window')
eq(panel.points.TOPLEFT[3], 6, 'default place')
eq(calls.operation, 0, 'counted before the frame is drawn')
panel.scripts.OnUpdate(panel)
eq(calls.operation, 3, 'three questions for the selected recipe')
eq(calls.schematic, 1, 'the recipe looked up once')
eq(panel.recipe.text, 'Blade', 'recipe name')
eq(panel.difficulty.value.text, '400', 'difficulty shown')
eq(panel.skill.value.text, '345', 'skill shown')
eq(panel.parts.text, 'own 300 + reagents 45', 'skill parts')
eq(panel.status.text, 'Now T4. T5 needs 55 more skill.', 'what is missing')
eq(panel.best.value.text, '365, T4 (T5 needs 35 more)', 'best reagents')
eq(panel.plain.value.text, '315, T3 (T5 needs 85 more)', 'plainest reagents')
eq(panel.concentration.value.text, '275 for T5', 'concentration')
eq(panel.body.shown, true, 'numbers visible')
eq(panel.message.shown, false, 'no message')
eq(panel.scale.shown, true, 'scale visible')
eq(panel.scale.names[5].text, 'T5 400', 'top threshold named on the scale')
eq(panel.scale.names[2].text, 'T2 80', 'first threshold named')
eq(panel.recipe.font, 'Addon/default.ttf', 'the addon\'s font')
assert(HironCraftProfit_DB.craftSimulator.lastMs and HironCraftProfit_DB.craftSimulator.lastMs > 0, 'the time was not recorded')

-- Idle frames ask nothing.
panel.scripts.OnUpdate(panel)
panel.scripts.OnUpdate(panel)
eq(calls.operation, 3, 'asked again without a change')

-- Reagents changed in the window: one recount, however many signals.
allocation = { { reagent = { itemID = 12 }, dataSlotIndex = 1, quantity = 10 },
    { reagent = { itemID = 23 }, dataSlotIndex = 2, quantity = 5 } }
callbacks.alloc()
for _, hook in ipairs(hooks) do hook.fn() end
panel.scripts.OnUpdate(panel)
eq(calls.operation, 6, 'one recount for several signals')
eq(calls.schematic, 1, 'the same recipe is not looked up again')
eq(panel.skill.value.text, '350', 'skill after the change')

-- The top quality.
recipes[100].baseSkill = 380
fire('PLAYER_EQUIPMENT_CHANGED')
panel.scripts.OnUpdate(panel)
eq(panel.status.text, 'T5 is reached.', 'top quality reached')
eq(panel.concentration.value.text, 'not needed', 'no concentration at the top')
eq(panel.best.value.text, '430, T5', 'best reagents at the top')
recipes[100].baseSkill = 300

-- Another recipe without a choice of reagents: no comparison rows.
selected, allocation = 300, {}
hooks[1].fn()
panel.scripts.OnUpdate(panel)
eq(panel.recipe.text, 'Thread', 'the other recipe')
eq(panel.best.shown, false, 'no best row')
eq(panel.plain.shown, false, 'no plain row')
eq(panel.status.text, 'Now T2. T3 needs 101 more skill.', 'three-quality recipe')
eq(panel.scale.names[4].shown, false, 'no fourth quality on its scale')

-- Recipes with nothing to show give a message instead of numbers.
selected = 200
hooks[1].fn()
panel.scripts.OnUpdate(panel)
eq(panel.message.shown, true, 'a message for a recipe without quality')
eq(panel.message.text, 'This recipe has no quality.', 'which says so')
eq(panel.body.shown, false, 'numbers hidden')
selected = 400
hooks[1].fn()
panel.scripts.OnUpdate(panel)
eq(panel.message.text, 'No data for this recipe.', 'no answer from the game')
selected = nil
hooks[1].fn()
panel.scripts.OnUpdate(panel)
eq(panel.message.text, 'Select a recipe.', 'nothing selected')
-- A recraft is not counted.
selected, allocation = 100, window
recipes[100].info.isRecraft = true
hooks[1].fn()
panel.scripts.OnUpdate(panel)
eq(panel.message.text, 'No data for this recipe.', 'a recraft')
recipes[100].info.isRecraft = nil
hooks[1].fn()
panel.scripts.OnUpdate(panel)
eq(panel.body.shown, true, 'numbers back')

-- The simulation ------------------------------------------------------------------

do
    local saved = HironCraftProfit_DB.craftSimulator
    local simToggle, section = panel.simulationToggle, panel.simulation
    assert(simToggle and section, 'the simulation part was not built with the panel')
    eq(section.shown, false, 'closed until asked for')
    eq(simToggle.shown, true, 'its button is there')
    eq(simToggle.label.text, 'Simulate other reagents and skill', 'the button says what it opens')
    local function Recount()
        calls.operation = 0
        hooks[1].fn()
        panel.scripts.OnUpdate(panel)
        return calls.operation
    end
    eq(Recount(), 3, 'a closed simulation asks nothing')

    -- Opened: one more question, the window's reagents to begin with.
    simToggle.scripts.OnClick(simToggle)
    eq(saved.simulation, true, 'remembered as open')
    calls.operation = 0
    panel.scripts.OnUpdate(panel)
    eq(calls.operation, 4, 'three questions for the panel and one for the simulation')
    eq(section.shown, true, 'shown')
    eq(simToggle.label.text, 'Hide simulation', 'the button says what it closes')
    eq(section.slotRows[1].name.text, 'Item 11', 'first quality slot')
    eq(section.slotRows[2].name.text, 'Item 21', 'second quality slot')
    eq(section.slotRows[1].buttons[3].shown, false, 'no third quality for a two-quality reagent')
    eq(section.slotRows[2].buttons[3].shown, true, 'three qualities for the other')
    eq(#section.choiceRows, 2, 'one list each for the optional and the finishing slot')
    eq(section.choiceRows[1].label, 'Optional', 'a slot without a name of its own')
    eq(section.choiceRows[2].label, 'Finishing', 'the finishing slot')
    eq(section.result.text, 'Result: 345, T4 (T5 needs 55 more)', 'starts as the window')
    eq(section.concentration.text, 'Concentration: 275 for T5', 'its concentration')
    eq(section.cost.text, 'Reagents: 163g', 'its cost')
    eq(section.fill.shown, true, 'the missing skill is offered')
    eq(section.fill.label.text, '+55', 'as a number')
    assert(panel.height > panel.baseHeight + 28, 'the panel did not grow for the simulation')

    -- One reagent at another quality: one question.
    calls.operation = 0
    local third = section.slotRows[2].buttons[3]
    third.scripts.OnClick(third)
    eq(calls.operation, 1, 'one question per change')
    eq(section.result.text, 'Result: 365, T4 (T5 needs 35 more)', 'better reagent in the second slot')
    eq(section.cost.text, 'Reagents: 193g', 'and what it costs')
    eq(third.label.color[1], 1, 'the chosen quality is marked')
    eq(section.slotRows[2].buttons[0].label.color[1] < 1, true, 'the others are not')

    -- Every slot at once.
    local presets = section.presets.buttons
    presets[3].scripts.OnClick(presets[3])
    eq(section.result.text, 'Result: 315, T3 (T5 needs 85 more)', 'plainest reagents')
    eq(section.cost.text, 'Reagents: 123g', 'are the cheapest here')
    presets[2].scripts.OnClick(presets[2])
    eq(section.result.text, 'Result: 365, T4 (T5 needs 35 more)', 'best reagents')
    presets[1].scripts.OnClick(presets[1])
    eq(section.result.text, 'Result: 345, T4 (T5 needs 55 more)', 'back to the window')

    -- Optional and finishing reagents from their lists.
    local function Menu(row)
        local radios = {}
        row.menu(row, { CreateRadio = function(_, text, isSelected, setSelected)
            radios[#radios + 1] = { text = text, selected = isSelected, pick = setSelected }
            radios[text] = radios[#radios]
        end })
        return radios
    end
    local optional = Menu(section.choiceRows[1])
    eq(#optional, 4, 'as in the window, empty, and the two reagents')
    assert(optional['Optional: as in the window'].selected(), 'the window\'s choice is the default')
    calls.operation = 0
    optional['Optional: Item 42'].pick()
    eq(calls.operation, 1, 'one question for an optional reagent')
    eq(section.result.text, 'Result: 330, T3 (T5 needs 110 more)', 'the harder optional reagent')
    eq(section.cost.text, 'Reagents: 263g', 'its cost')
    assert(Menu(section.choiceRows[1])['Optional: Item 42'].selected(), 'the list shows the choice')
    assert(section.choiceRows[1].generated > 0, 'the list\'s own text was refreshed')
    optional['Optional: empty'].pick()
    eq(section.result.text, 'Result: 330, T4 (T5 needs 70 more)', 'without the optional reagent')
    eq(section.cost.text, 'Reagents: 63g', 'cheaper without it')
    optional['Optional: as in the window'].pick()
    eq(section.result.text, 'Result: 345, T4 (T5 needs 55 more)', 'the window again')
    Menu(section.choiceRows[2])['Finishing: Item 51'].pick()
    eq(section.result.text, 'Result: 350, T4 (T5 needs 50 more)', 'a finishing reagent')
    eq(section.fill.label.text, '+50', 'the offer follows')

    -- Another skill: arithmetic only.
    calls.operation = 0
    section.extra:SetText('10')
    eq(section.result.text, 'Result: 360, T4 (T5 needs 40 more)', 'ten more skill')
    eq(section.concentration.text, 'Concentration: known for your real skill only', 'no price for a made-up skill')
    section.extra:SetText('-40')
    eq(section.result.text, 'Result: 310, T3 (T5 needs 90 more)', 'less skill')
    section.fill.scripts.OnClick(section.fill)
    eq(section.extra.text, '50', 'the missing skill put in')
    eq(section.result.text, 'Result: 400, T5', 'reaches the top')
    eq(section.concentration.text, 'Concentration: not needed', 'no concentration at the top')
    eq(section.fill.label.text, '+50', 'the offer stays what the reagents lack')
    section.extra:SetText('nonsense')
    eq(section.result.text, 'Result: 350, T4 (T5 needs 50 more)', 'nonsense is no change')
    eq(calls.operation, 0, 'the game was not asked about another skill')

    -- A price that is not known is said so.
    prices[51] = nil
    presets[1].scripts.OnClick(presets[1])
    eq(section.cost.text, 'Reagents: 163g (some prices unknown)', 'an incomplete cost')
    prices[51] = 500000

    -- Reagents changed in the window: the simulation follows what was not chosen.
    allocation = { { reagent = { itemID = 11 }, dataSlotIndex = 1, quantity = 10 } }
    eq(Recount(), 4, 'recounted with the window')
    eq(section.result.text, 'Result: 305, T3 (T5 needs 95 more)', 'the window\'s new reagents with the chosen finishing one')
    allocation = window

    -- Another recipe starts with its own, empty choices.
    selected, allocation = 300, {}
    Recount()
    eq(section.presets.shown, false, 'no presets without quality slots')
    eq(section.slotRows[1].shown, false, 'no quality rows')
    eq(section.choiceRows[1].shown, false, 'no optional lists')
    eq(section.extra.text, '', 'the other skill starts empty')
    eq(section.result.text, 'Result: 200, T2 (T3 needs 101 more)', 'the other recipe')
    selected, allocation = 100, window
    Recount()
    eq(section.result.text, 'Result: 345, T4 (T5 needs 55 more)', 'earlier choices are not carried back')
    eq(section.choiceRows[1].label, 'Optional', 'its lists are back')

    -- A slot named by the game keeps that name.
    recipes[100].slots[4].slotInfo = { slotText = 'Embellishment' }
    selected = 300; Recount(); selected = 100; Recount()
    eq(section.choiceRows[1].label, 'Embellishment', 'the game\'s name for the slot')
    assert(Menu(section.choiceRows[1])['Embellishment: Item 41'], 'used in its list')

    -- A name the game does not have yet is asked for once and put in when it comes.
    unloaded[11] = true
    selected = 300; Recount(); selected = 100; Recount()
    eq(section.slotRows[1].name.text, '#11', 'a placeholder meanwhile')
    Recount()
    eq(nameRequests[11], 1, 'asked once')
    unloaded[11] = nil
    calls.operation = 0
    section.scripts.OnEvent(section, 'ITEM_DATA_LOAD_RESULT', 999, true)
    eq(section.slotRows[1].name.text, '#11', 'another item\'s name changes nothing')
    section.scripts.OnEvent(section, 'ITEM_DATA_LOAD_RESULT', 11, true)
    eq(section.slotRows[1].name.text, 'Item 11', 'the name was put in')
    eq(calls.operation, 0, 'without asking about the craft')

    -- A recipe with nothing to show hides the simulation with the numbers.
    selected = 200
    Recount()
    eq(section.shown, false, 'no simulation without numbers')
    eq(simToggle.shown, false, 'nor its button')
    selected = 100
    Recount()
    eq(section.shown, true, 'back with the recipe')

    -- Closed again: three questions per recount, as before.
    simToggle.scripts.OnClick(simToggle)
    eq(saved.simulation, false, 'remembered as closed')
    calls.operation = 0
    panel.scripts.OnUpdate(panel)
    eq(calls.operation, 3, 'a closed simulation asks nothing')
    eq(section.shown, false, 'hidden')
    eq(panel.height, panel.baseHeight + 28, 'the panel is its own size again, with the button')
end
print('Craft simulation passed (lazy, one question per change, qualities, presets, optional and finishing lists, +N skill, cost, recipe changes, names).')

-- Moved: remembered relative to the profession window.
local drag
for _, frame in ipairs(frames) do
    if frame.parent == panel and frame.scripts.OnDragStop then drag = frame end
end
assert(drag, 'the panel cannot be moved')
panel.left, panel.top = 950, 600
drag.scripts.OnDragStop(drag)
eq(HironCraftProfit_DB.craftSimulator.x, 50, 'horizontal offset saved')
eq(HironCraftProfit_DB.craftSimulator.y, -100, 'vertical offset saved')
eq(panel.points.TOPLEFT[3], 50, 'placed by the saved offset')

-- Closed again: nothing is counted, and it stays closed.
local close
for _, frame in ipairs(frames) do
    if frame.parent == panel and frame.template == 'UIPanelCloseButton' then close = frame end
end
close.scripts.OnClick(close)
eq(panel.shown, false, 'closed')
eq(HironCraftProfit_DB.craftSimulator.shown, false, 'remembered as closed')
local asked = calls.operation
callbacks.alloc()
for _, hook in ipairs(hooks) do hook.fn() end
eq(calls.operation, asked, 'asked while closed')
toggle.scripts.OnShow(toggle)
eq(panel.shown, false, 'reopened by itself though it was closed')

-- Left open: comes back with the crafting page.
toggle.scripts.OnClick(toggle)
eq(panel.shown, true, 'opened again')
panel.shown = false
toggle.scripts.OnShow(toggle)
eq(panel.shown, true, 'not reopened with the crafting page')

print('Craft simulator panel passed (lazy build, idle cost, numbers, changes, messages, moving, closing).')
