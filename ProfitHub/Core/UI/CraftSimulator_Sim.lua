local PT = HironCraftProfit
local S = PT and PT.CraftSimulator
local UI = S and S.UI
if not UI then return end

-- What the skill panel shows: the selected recipe tried with any reagents and
-- another skill, without spending or owning anything. It starts as the craft
-- is set up in the window; the game's own window already shows skill and
-- difficulty, so the panel adds what that does not: where every quality's
-- threshold lies, what is missing for the top one, and what other reagents
-- or more skill would change.
--
-- One question to the game per recount or change of reagents; another skill
-- is arithmetic on the last answer; what each optional reagent does is asked
-- only when its list is opened.
local Text, T, Tier = UI.Text, UI.T, UI.Tier
local INNER, GOLD, GREEN, GREY, WHITE = UI.INNER, UI.GOLD, UI.GREEN, UI.GREY, UI.WHITE

local panel, body
-- The choices made for the recipe they belong to.
local choice = { mixes = {}, items = {}, extraSkill = 0 }
local recipeOf, basics, windowReagents
local simulation

-- An item's name; asked from the server once when the game does not have it.
local requested = {}
local function ItemName(itemID)
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
    if name then return name end
    if itemID and not requested[itemID] and C_Item and C_Item.RequestLoadItemDataByID then
        requested[itemID] = true
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    end
    return "#" .. tostring(itemID)
end

-- A reagent's name: an item, or a currency such as a crest.
local function ReagentName(option)
    if type(option) ~= "table" then return ItemName(option) end
    if option.itemID then return ItemName(option.itemID) end
    if option.currencyID then
        local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(option.currencyID)
        return type(info) == "table" and info.name or ("#" .. tostring(option.currencyID))
    end
    return "?"
end

local function OptionItem(option)
    return type(option) == "table" and option.itemID or tonumber(option)
end

local function Money(copper, complete)
    local gold = math.floor((tonumber(copper) or 0) / 10000 + 0.5)
    local text = (BreakUpLargeNumbers and BreakUpLargeNumbers(gold) or tostring(gold)) .. "g"
    if not complete then text = text .. " " .. T("CRAFTSIM_COST_PARTIAL", "(some prices unknown)") end
    return text
end

-- The name a slot has in the recipe window ("Embellishment", ...).
local function SlotLabel(slot, fallback)
    local schematic = basics and basics.schematic
    for _, entry in ipairs(schematic and schematic.reagentSlotSchematics or {}) do
        if (entry.dataSlotIndex or entry.slotIndex) == slot.dataSlotIndex and entry.slotIndex == slot.slotIndex then
            local text = type(entry.slotInfo) == "table" and entry.slotInfo.slotText
            if type(text) == "string" and text ~= "" then return text end
        end
    end
    return fallback
end

-- What a row with a list is called: its slot's name in the recipe window,
-- or its first reagent's name for a required slot the window does not name.
local function RowLabel(row)
    return row.label or ReagentName(row.slot.options and row.slot.options[1])
end

-- What a row with a list says: the slot and its choice.
local function ChoiceText(row)
    local value = choice.items[row.slot.dataSlotIndex]
    local text
    if value == nil then
        text = T("CRAFTSIM_AS_WINDOW", "as in the window")
    elseif value == false then
        text = T("CRAFTSIM_EMPTY", "empty")
    else
        text = ReagentName(value)
    end
    return RowLabel(row) .. ": " .. text
end

-- The reagent quality all of a group's reagents share, if they do.
local function SharedQuality(group)
    if not (C_TradeSkillUI and C_TradeSkillUI.GetItemReagentQualityByItemInfo) then return nil end
    local shared
    for _, option in ipairs(group.options) do
        local itemID = OptionItem(option)
        if not itemID then return nil end
        local ok, quality = pcall(C_TradeSkillUI.GetItemReagentQualityByItemInfo, itemID)
        quality = ok and tonumber(quality) or nil
        if not quality or (shared and shared ~= quality) then return nil end
        shared = quality
    end
    return shared
end

-- One line for reagents that do the same to the craft:
-- "Missive of the Aurora and 5 more (quality 1): difficulty +25".
local function GroupText(group)
    local text = ReagentName(group.options[1])
    if #group.options > 1 then
        text = string.format(T("CRAFTSIM_GROUP_MORE", "%s and %d more"), text, #group.options - 1)
    end
    local quality = SharedQuality(group)
    if quality then text = text .. " (" .. string.format(T("CRAFTSIM_GROUP_QUALITY", "quality %d"), quality) .. ")" end
    local effect, parts = group.effect, {}
    if not effect then return text end
    if effect.difficulty ~= 0 then
        parts[#parts + 1] = string.format(T("CRAFTSIM_EFFECT_DIFFICULTY", "difficulty %+d"), effect.difficulty)
    end
    if effect.skill ~= 0 then
        parts[#parts + 1] = string.format(T("CRAFTSIM_EFFECT_SKILL", "skill %+d"), effect.skill)
    end
    if #parts == 0 then parts[1] = T("CRAFTSIM_EFFECT_NONE", "no effect on skill") end
    return text .. ": " .. table.concat(parts, ", ")
end

-- The bar: filled up to the skill, a tick for each quality with its name
-- above and the skill it needs below.
local function UpdateScale(outcome)
    local scale, thresholds = body.scale, outcome.thresholds
    if not thresholds then
        scale:Hide()
        return
    end
    local range = math.max(outcome.difficulty, outcome.skill, 1)
    local width = scale.bar:GetWidth()
    scale.fill:SetWidth(math.max(1, math.min(width, width * math.max(0, outcome.skill) / range)))
    for quality = 2, 5 do
        local tick, name, need = scale.ticks[quality], scale.names[quality], scale.needs[quality]
        local threshold = thresholds[quality]
        if threshold and quality <= outcome.maxQuality then
            local x = math.min(width, width * threshold / range)
            local color = outcome.skill >= threshold and GREEN or GREY
            tick:ClearAllPoints()
            tick:SetPoint("TOP", scale.bar, "TOPLEFT", x, 2)
            tick:SetColorTexture(color[1], color[2], color[3], 1)
            tick:Show()
            name:ClearAllPoints()
            name:SetPoint("BOTTOM", scale.bar, "TOPLEFT", x, 3)
            name:SetText(Tier(quality))
            name:SetTextColor(color[1], color[2], color[3])
            name:Show()
            need:ClearAllPoints()
            need:SetPoint("TOP", scale.bar, "BOTTOMLEFT", x, -3)
            need:SetText(tostring(threshold))
            need:SetTextColor(color[1], color[2], color[3])
            need:Show()
        else
            tick:Hide()
            name:Hide()
            need:Hide()
        end
    end
    scale:Show()
end

local function ShowOutcome()
    local outcome = S.Outcome(simulation, choice.extraSkill)
    if not outcome then return end
    UpdateScale(outcome)
    if (outcome.missingToMax or 0) > 0 then
        body.status:SetText(string.format(T("CRAFTSIM_STATUS_MISSING", "Skill %d: %s, %s needs %d more"),
            outcome.skill, Tier(outcome.quality), Tier(outcome.maxQuality), outcome.missingToMax))
        body.status:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    else
        body.status:SetText(string.format(T("CRAFTSIM_STATUS_MAX", "Skill %d: %s"), outcome.skill, Tier(outcome.quality)))
        body.status:SetTextColor(GREEN[1], GREEN[2], GREEN[3])
    end

    local concentration
    if outcome.quality and outcome.quality >= outcome.maxQuality then
        concentration = T("CRAFTSIM_CONC_NONE", "not needed")
    elseif choice.extraSkill ~= 0 then
        -- The game prices it for the real skill only.
        concentration = T("CRAFTSIM_CONC_REAL_ONLY", "known for your real skill only")
    elseif outcome.concentrationCost then
        concentration = string.format(T("CRAFTSIM_CONC_COST", "%d for %s"), outcome.concentrationCost, Tier(outcome.nextQuality))
    else
        concentration = "-"
    end
    body.concentration:SetText(T("CRAFTSIM_CONCENTRATION", "Concentration") .. ": " .. concentration)
    body.cost:SetText(T("CRAFTSIM_COST", "Reagents") .. ": " .. Money(simulation.cost, simulation.costComplete))

    -- What the chosen reagents lack for the top quality, one click away.
    local real = S.Outcome(simulation, 0)
    local missing = real and real.missingToMax or 0
    if missing > 0 then
        body.fill.amount = missing
        body.fill.label:SetText(string.format("+%d", missing))
        body.fill:Show()
    else
        body.fill:Hide()
    end
end

-- How a quality slot is filled in what is tried: the mix chosen here, or the
-- window's. Units not chosen in the window are shown as the lowest quality,
-- which is what they count as.
local function SlotMix(slot)
    local mix = choice.mixes[slot.dataSlotIndex]
    if mix then return mix end
    local window, allocated = S.WindowMix(slot, windowReagents)
    local shown = {}
    for tier = 1, slot.qualityCount do shown[tier] = window[tier] or 0 end
    shown[1] = shown[1] + math.max(0, (tonumber(slot.quantity) or 0) - allocated)
    return shown
end

-- Text put into a box by the panel itself is not the player typing.
local filling = false

local function UpdateControls()
    filling = true
    for _, row in ipairs(body.slotRows) do
        if row.shown then
            local mix, total = SlotMix(row.slot), tonumber(row.slot.quantity) or 0
            for tier = 1, row.slot.qualityCount do
                local count = mix[tier] or 0
                row.boxes[tier]:SetText(tostring(count))
                -- The whole slot at one quality is marked on that quality's button.
                local color = (total > 0 and count == total) and GOLD or GREY
                row.buttons[tier].label:SetTextColor(color[1], color[2], color[3])
            end
        end
    end
    filling = false
    for _, row in ipairs(body.choiceRows) do
        if row.shown then row.text:SetText(ChoiceText(row)) end
    end
end

-- After a change of the reagents chosen here: one question to the game.
function UI.RefreshSimulation()
    if not body or not basics or not recipeOf then return end
    local fresh = S.Simulate(recipeOf, basics, windowReagents, choice)
    if not fresh then return end
    simulation = fresh
    UpdateControls()
    ShowOutcome()
end

local PAIR = 54 -- a quality's button and the box with how many of it

local function Tip(owner, key, fallback, quality)
    owner:SetScript("OnEnter", function()
        local tooltip = PT.Tooltip
        if not tooltip then return end
        tooltip:Clear()
        tooltip:AddLine(string.format(T(key, fallback), quality), 11, 1, 1, 1)
        tooltip:ShowCursorRightOrBelow()
    end)
    owner:SetScript("OnLeave", function()
        if PT.Tooltip then PT.Tooltip:Clear() end
    end)
end

-- A quality slot: its reagent's name, and for each quality a button (the
-- whole slot at that quality) and a box (how many of the slot are of it), so
-- a slot can be tried partly at one quality and partly at another.
local function SlotRow(index)
    local row = body.slotRows[index]
    if row then return row end
    row = CreateFrame("Frame", nil, body)
    row:SetSize(INNER, 20)
    row.name = Text(row, 11, "LEFT")
    row.name:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.buttons, row.boxes = {}, {}
    for tier = 1, 3 do
        local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        button:SetSize(20, 18)
        button.label = Text(button, 10, "CENTER", GREY)
        button.label:SetPoint("CENTER", 0, 0)
        button.label:SetText(tostring(tier))
        button:SetScript("OnClick", function()
            choice.mixes[row.dataSlotIndex] = { [tier] = tonumber(row.slot.quantity) or 0 }
            UI.RefreshSimulation()
        end)
        Tip(button, "CRAFTSIM_ALL_OF_QUALITY", "The whole slot at quality %d", tier)
        row.buttons[tier] = button

        local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        box:SetSize(26, 18)
        box:SetAutoFocus(false)
        box:SetNumeric(true)
        box:SetMaxLetters(3)
        box:SetJustifyH("CENTER")
        box:SetScript("OnTextChanged", function(self, userInput)
            if filling or not userInput then return end
            local slot = row.slot
            choice.mixes[slot.dataSlotIndex] = S.Rebalance(SlotMix(slot), slot.qualityCount, slot.quantity,
                tier, tonumber(self:GetText()) or 0)
            UI.RefreshSimulation()
        end)
        box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        Tip(box, "CRAFTSIM_COUNT_OF_QUALITY", "How many of the slot are quality %d", tier)
        row.boxes[tier] = box
    end
    body.slotRows[index] = row
    return row
end

-- A button per slot that takes a reagent by choice (optional, finishing, or
-- required with several to choose from); its list is built when it is opened,
-- and only then is the game asked what each reagent does.
local function OpenChoiceMenu(row)
    local slot = row.slot
    if not slot or not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(row, function(_, root)
        local dataSlotIndex = slot.dataSlotIndex
        local function Pick(value)
            return function()
                choice.items[dataSlotIndex] = value
                UI.RefreshSimulation()
            end
        end
        root:CreateTitle(RowLabel(row))
        root:CreateRadio(T("CRAFTSIM_AS_WINDOW", "as in the window"),
            function() return choice.items[dataSlotIndex] == nil end, Pick(nil))
        root:CreateRadio(T("CRAFTSIM_EMPTY", "empty"),
            function() return choice.items[dataSlotIndex] == false end, Pick(false))
        -- Reagents that do the same to the craft are one line.
        for _, group in ipairs(S.OptionGroups(recipeOf, basics, windowReagents, choice, slot)) do
            root:CreateRadio(GroupText(group), function()
                local chosen = S.OptionKey(choice.items[dataSlotIndex])
                for _, key in ipairs(group.keys) do
                    if key == chosen then return true end
                end
                return false
            end, Pick(group.options[1]))
        end
    end)
end

local function ChoiceRow(index)
    local row = body.choiceRows[index]
    if row then return row end
    row = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
    row:SetSize(INNER, 20)
    row.text = Text(row, 10, "LEFT", WHITE)
    row.text:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.text:SetWidth(INNER - 16)
    row:SetScript("OnClick", OpenChoiceMenu)
    body.choiceRows[index] = row
    return row
end

-- Everything top to bottom for the recipe's slots; returns the height used.
local function Layout()
    local y = 0
    local function Put(frame, height, gap)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
        frame:Show()
        y = y + height + (gap or 2)
    end
    Put(body.recipe, 16, 4)
    Put(body.scale, 36, 6)
    Put(body.status, 14, 2)
    Put(body.concentration, 13, 2)
    Put(body.cost, 13, 10)

    -- Required slots are of two kinds: the qualities of one reagent (a row
    -- with a count per quality) and one of several reagents (a list).
    local qualitySlots, lists = {}, {}
    for _, slot in ipairs(basics.basicSlots or {}) do
        if S.IsChoiceSlot(slot) then
            lists[#lists + 1] = { slot = slot, label = SlotLabel(slot, nil) }
        else
            qualitySlots[#qualitySlots + 1] = slot
        end
    end
    for _, group in ipairs({
        { slots = basics.optionalSlots or {}, label = T("CRAFTSIM_OPTIONAL", "Optional") },
        { slots = basics.finishingSlots or {}, label = T("CRAFTSIM_FINISHING", "Finishing") },
    }) do
        for _, slot in ipairs(group.slots) do
            -- A slot the character cannot use yet is left out.
            if not slot.locked then lists[#lists + 1] = { slot = slot, label = SlotLabel(slot, group.label) } end
        end
    end

    local used = 0
    if #qualitySlots > 0 then
        Put(body.presetLabel, 12, 3)
        Put(body.presets, 20, 4)
    else
        body.presetLabel:Hide()
        body.presets:Hide()
    end
    for _, slot in ipairs(qualitySlots) do
        used = used + 1
        local row = SlotRow(used)
        row.slot, row.dataSlotIndex, row.shown = slot, slot.dataSlotIndex, true
        row.firstItem = OptionItem(slot.options and slot.options[1])
        row.name:SetText(ItemName(row.firstItem))
        -- The pairs keep to the right; the name has what is left of the row.
        local left = INNER - slot.qualityCount * PAIR
        row.name:SetWidth(left - 4)
        for tier = 1, 3 do
            local used = tier <= slot.qualityCount
            row.buttons[tier]:SetShown(used)
            row.boxes[tier]:SetShown(used)
            if used then
                local x = left + (tier - 1) * PAIR
                row.buttons[tier]:ClearAllPoints()
                row.buttons[tier]:SetPoint("LEFT", row, "LEFT", x, 0)
                row.boxes[tier]:ClearAllPoints()
                row.boxes[tier]:SetPoint("LEFT", row, "LEFT", x + 26, 0)
            end
        end
        Put(row, 20)
    end
    for index = used + 1, #body.slotRows do
        body.slotRows[index].shown = false
        body.slotRows[index]:Hide()
    end
    if used > 0 then y = y + 4 end

    used = 0
    for _, list in ipairs(lists) do
        used = used + 1
        local row = ChoiceRow(used)
        row.slot, row.label, row.shown = list.slot, list.label, true
        Put(row, 20, 3)
    end
    for index = used + 1, #body.choiceRows do
        body.choiceRows[index].shown = false
        body.choiceRows[index]:Hide()
    end
    if used > 0 then y = y + 4 end

    Put(body.extraRow, 20, 0)
    return y
end

-- Names that have arrived are put in without asking the game about the craft.
local function Relabel()
    if not body:IsShown() or not basics then return end
    for _, row in ipairs(body.slotRows) do
        if row.shown and row.firstItem then row.name:SetText(ItemName(row.firstItem)) end
    end
    for _, row in ipairs(body.choiceRows) do
        if row.shown then row.text:SetText(ChoiceText(row)) end
    end
end

-- Called on every recount of the panel with the recipe on screen. Returns
-- false when the game gives no answer for it.
function UI.ShowCraft(recipeID, recipeBasics, reagents, name)
    if not body then return false end
    -- Another recipe: its own choices, starting from the window's.
    if recipeOf ~= recipeID then
        choice.mixes, choice.items, choice.extraSkill = {}, {}, 0
        body.extra:SetText("")
    end
    recipeOf, basics, windowReagents = recipeID, recipeBasics, reagents
    simulation = S.Simulate(recipeOf, basics, windowReagents, choice)
    if not simulation then return false end
    body.recipe:SetText(name or "")
    local height = Layout()
    body:SetHeight(height)
    panel:SetHeight(UI.TOP + height + 14)
    UpdateControls()
    ShowOutcome()
    return true
end

function UI.BuildCraft(owner)
    panel, body = owner, owner.body
    body.slotRows, body.choiceRows = {}, {}

    body.recipe = Text(body, 13, "LEFT", GOLD)
    body.recipe:SetWidth(INNER)

    -- The scale: quality names above the bar, the skill each needs below it.
    local scale = CreateFrame("Frame", nil, body)
    scale:SetSize(INNER, 36)
    scale.bar = CreateFrame("Frame", nil, scale)
    scale.bar:SetSize(INNER, 10)
    scale.bar:SetPoint("TOPLEFT", scale, "TOPLEFT", 0, -13)
    local background = scale.bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 0.7)
    scale.fill = scale.bar:CreateTexture(nil, "ARTWORK")
    scale.fill:SetPoint("TOPLEFT", scale.bar, "TOPLEFT", 0, 0)
    scale.fill:SetPoint("BOTTOMLEFT", scale.bar, "BOTTOMLEFT", 0, 0)
    scale.fill:SetColorTexture(0.78, 0.58, 0.12, 1)
    scale.ticks, scale.names, scale.needs = {}, {}, {}
    for quality = 2, 5 do
        local tick = scale.bar:CreateTexture(nil, "OVERLAY")
        tick:SetSize(2, 14)
        scale.ticks[quality] = tick
        scale.names[quality] = Text(scale, 9, "CENTER", GREY)
        scale.needs[quality] = Text(scale, 9, "CENTER", GREY)
    end
    body.scale = scale

    body.status = Text(body, 12, "LEFT", GOLD)
    body.status:SetWidth(INNER)
    body.concentration = Text(body, 11, "LEFT", GREY)
    body.concentration:SetWidth(INNER)
    body.cost = Text(body, 11, "LEFT", GREY)
    body.cost:SetWidth(INNER)

    -- Every quality slot at once.
    body.presetLabel = Text(body, 11, "LEFT", GREY)
    body.presetLabel:SetWidth(INNER)
    body.presetLabel:SetText(T("CRAFTSIM_PRESET_LABEL", "Quality of all reagents"))
    local presets = CreateFrame("Frame", nil, body)
    presets:SetSize(INNER, 20)
    presets.buttons = {}
    local function Preset(index, key, fallback, pick)
        local button = CreateFrame("Button", nil, presets, "UIPanelButtonTemplate")
        button:SetSize((INNER - 8) / 3, 20)
        button:SetPoint("LEFT", presets, "LEFT", (index - 1) * ((INNER - 8) / 3 + 4), 0)
        button.label = Text(button, 10, "CENTER", WHITE)
        button.label:SetPoint("CENTER", 0, 0)
        button.label:SetText(T(key, fallback))
        button:SetScript("OnClick", function()
            choice.mixes = {}
            for _, slot in ipairs(basics and basics.basicSlots or {}) do
                -- A slot that takes one of several reagents has no quality.
                local tier = not S.IsChoiceSlot(slot) and pick(slot)
                if tier then choice.mixes[slot.dataSlotIndex] = { [tier] = tonumber(slot.quantity) or 0 } end
            end
            UI.RefreshSimulation()
        end)
        presets.buttons[index] = button
    end
    Preset(1, "CRAFTSIM_PRESET_WINDOW", "As in window", function() return nil end)
    Preset(2, "CRAFTSIM_PRESET_BEST", "Highest", function(slot) return slot.qualityCount end)
    Preset(3, "CRAFTSIM_PRESET_PLAIN", "Lowest", function() return 1 end)
    body.presets = presets

    -- "+N skill": what if the skill were different.
    local extraRow = CreateFrame("Frame", nil, body)
    extraRow:SetSize(INNER, 20)
    local extraLabel = Text(extraRow, 12, "LEFT", WHITE)
    extraLabel:SetPoint("LEFT", extraRow, "LEFT", 0, 0)
    extraLabel:SetText(T("CRAFTSIM_EXTRA_SKILL", "Skill +/-"))
    local extra = CreateFrame("EditBox", nil, extraRow, "InputBoxTemplate")
    extra:SetSize(52, 20)
    extra:SetPoint("LEFT", extraRow, "LEFT", 96, 0)
    extra:SetAutoFocus(false)
    extra:SetMaxLetters(5)
    extra:SetScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText()) or 0
        value = math.max(-9999, math.min(9999, math.floor(value)))
        if value == choice.extraSkill then return end
        choice.extraSkill = value
        if simulation then ShowOutcome() end
    end)
    extra:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    extra:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    body.extra, body.extraRow = extra, extraRow
    -- Puts in what the chosen reagents lack for the top quality.
    local fill = CreateFrame("Button", nil, extraRow, "UIPanelButtonTemplate")
    fill:SetSize(58, 20)
    fill:SetPoint("LEFT", extra, "RIGHT", 8, 0)
    fill.label = Text(fill, 10, "CENTER", GOLD)
    fill.label:SetPoint("CENTER", 0, 0)
    fill:SetScript("OnClick", function(self)
        if self.amount then extra:SetText(tostring(self.amount)) end
    end)
    fill:Hide()
    body.fill = fill

    -- Item names arrive from the server a moment after they are first asked:
    -- the ones asked for here are put in, several at once.
    local pending = false
    body:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    body:SetScript("OnEvent", function(_, _, itemID, success)
        if not requested[itemID] or not success or pending then return end
        pending = true
        local function Later()
            pending = false
            Relabel()
        end
        if C_Timer and C_Timer.After then C_Timer.After(0.3, Later) else Later() end
    end)
end
