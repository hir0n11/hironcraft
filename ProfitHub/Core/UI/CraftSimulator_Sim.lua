local PT = HironCraftProfit
local S = PT and PT.CraftSimulator
local UI = S and S.UI
if not UI then return end

-- The lower part of the skill panel: a craft tried with other reagents and
-- another skill, without spending or owning anything. Switched on by its
-- button; while it is off, nothing here is built or asked.
--
-- One question to the game per change of reagents; a change of the "+N
-- skill" is arithmetic on the last answer.
local Text, T, Tier, Saved = UI.Text, UI.T, UI.Tier, UI.Saved
local INNER, GOLD, GREEN, GREY, WHITE = UI.INNER, UI.GOLD, UI.GREEN, UI.GREY, UI.WHITE

local panel, section
-- The choices made for the recipe they belong to.
local choice = { tiers = {}, items = {}, extraSkill = 0 }
local recipeOf, basics, windowReagents
local simulation

local function IsOn()
    return Saved().simulation == true
end
UI.IsSimulationOn = IsOn

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

local function ShowOutcome()
    local outcome = S.Outcome(simulation, choice.extraSkill)
    if not outcome then
        section.result:SetText(T("CRAFTSIM_NO_DATA", "No data for this recipe."))
        section.concentration:SetText("")
        section.cost:SetText("")
        section.fill:Hide()
        return
    end
    local text
    if (outcome.missingToMax or 0) > 0 then
        text = string.format(T("CRAFTSIM_RESULT_MISSING", "%d, %s (%s needs %d more)"),
            outcome.skill, Tier(outcome.quality), Tier(outcome.maxQuality), outcome.missingToMax)
        section.result:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    else
        text = string.format(T("CRAFTSIM_RESULT_MAX", "%d, %s"), outcome.skill, Tier(outcome.quality))
        section.result:SetTextColor(GREEN[1], GREEN[2], GREEN[3])
    end
    section.result:SetText(T("CRAFTSIM_OUTCOME", "Result") .. ": " .. text)

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
    section.concentration:SetText(T("CRAFTSIM_CONCENTRATION", "Concentration") .. ": " .. concentration)
    section.cost:SetText(T("CRAFTSIM_COST", "Reagents") .. ": " .. Money(simulation.cost, simulation.costComplete))

    -- What the chosen reagents lack for the top quality, one click away.
    local real = S.Outcome(simulation, 0)
    local missing = real and real.missingToMax or 0
    if missing > 0 then
        section.fill.amount = missing
        section.fill.label:SetText(string.format("+%d", missing))
        section.fill:Show()
    else
        section.fill:Hide()
    end
end

local function UpdateControls()
    for _, row in ipairs(section.slotRows) do
        if row.shown then
            local chosen = choice.tiers[row.dataSlotIndex] or 0
            for tier, button in pairs(row.buttons) do
                local color = tier == chosen and GOLD or GREY
                button.label:SetTextColor(color[1], color[2], color[3])
            end
        end
    end
    for _, row in ipairs(section.choiceRows) do
        if row.shown and row.GenerateMenu then row:GenerateMenu() end
    end
end

function UI.RefreshSimulation()
    if not section or not IsOn() or not basics or not recipeOf then return end
    simulation = S.Simulate(recipeOf, basics, windowReagents, choice)
    UpdateControls()
    ShowOutcome()
end

local function SlotRow(index)
    local row = section.slotRows[index]
    if row then return row end
    row = CreateFrame("Frame", nil, section)
    row:SetSize(INNER, 20)
    row.name = Text(row, 11, "LEFT")
    row.name:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.name:SetWidth(INNER - 100)
    row.buttons = {}
    -- "=" keeps what is in the window; the numbers are the reagent's qualities.
    for tier = 0, 3 do
        local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        button:SetSize(22, 18)
        button:SetPoint("LEFT", row, "LEFT", INNER - 94 + tier * 24, 0)
        button.label = Text(button, 10, "CENTER", GREY)
        button.label:SetPoint("CENTER", 0, 0)
        button.label:SetText(tier == 0 and "=" or tostring(tier))
        button:SetScript("OnClick", function()
            choice.tiers[row.dataSlotIndex] = tier > 0 and tier or nil
            UI.RefreshSimulation()
        end)
        row.buttons[tier] = button
    end
    section.slotRows[index] = row
    return row
end

local function ChoiceRow(index)
    local row = section.choiceRows[index]
    if row then return row end
    row = CreateFrame("DropdownButton", nil, section, "WowStyle1DropdownTemplate")
    row:SetWidth(INNER)
    row:SetupMenu(function(_, root)
        local slot = row.slot
        if not slot then return end
        local dataSlotIndex, prefix = slot.dataSlotIndex, row.label .. ": "
        local function Pick(value)
            return function()
                choice.items[dataSlotIndex] = value
                UI.RefreshSimulation()
            end
        end
        root:CreateRadio(prefix .. T("CRAFTSIM_AS_WINDOW", "as in the window"),
            function() return choice.items[dataSlotIndex] == nil end, Pick(nil))
        root:CreateRadio(prefix .. T("CRAFTSIM_EMPTY", "empty"),
            function() return choice.items[dataSlotIndex] == false end, Pick(false))
        for _, option in ipairs(type(slot.options) == "table" and slot.options or {}) do
            local itemID = OptionItem(option)
            if itemID then
                root:CreateRadio(prefix .. ItemName(itemID),
                    function() return choice.items[dataSlotIndex] == itemID end, Pick(itemID), itemID)
            end
        end
    end)
    section.choiceRows[index] = row
    return row
end

-- Rows for the recipe's slots, top to bottom; returns the section's height.
local function Layout()
    local y = 0
    local function Put(frame, height, gap)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", section, "TOPLEFT", 0, -y)
        frame:Show()
        y = y + height + (gap or 2)
    end
    Put(section.presets, 20, 6)

    local used = 0
    for _, slot in ipairs(basics.basicSlots or {}) do
        used = used + 1
        local row = SlotRow(used)
        row.dataSlotIndex, row.shown = slot.dataSlotIndex, true
        row.firstItem = OptionItem(slot.options and slot.options[1])
        row.name:SetText(ItemName(row.firstItem))
        for tier = 1, 3 do row.buttons[tier]:SetShown(tier <= slot.qualityCount) end
        Put(row, 20)
    end
    for index = used + 1, #section.slotRows do
        section.slotRows[index].shown = false
        section.slotRows[index]:Hide()
    end
    section.presets:SetShown(used > 0)
    if used == 0 then y = 0 end

    used = 0
    for _, group in ipairs({
        { slots = basics.optionalSlots or {}, label = T("CRAFTSIM_OPTIONAL", "Optional") },
        { slots = basics.finishingSlots or {}, label = T("CRAFTSIM_FINISHING", "Finishing") },
    }) do
        for _, slot in ipairs(group.slots) do
            -- A slot the character cannot use yet is left out.
            if not slot.locked then
                used = used + 1
                local row = ChoiceRow(used)
                row.slot, row.label, row.shown = slot, SlotLabel(slot, group.label), true
                Put(row, 24, 4)
            end
        end
    end
    for index = used + 1, #section.choiceRows do
        section.choiceRows[index].shown = false
        section.choiceRows[index]:Hide()
    end

    y = y + 4
    Put(section.extraRow, 20, 6)
    Put(section.result, 14, 2)
    Put(section.concentration, 14, 2)
    Put(section.cost, 14, 0)
    return y
end

-- The panel's own height, the button's row and, when open, the section.
local function Resize()
    local height = (panel.baseHeight or 0) + 28
    if section:IsShown() then height = height + section.height + 8 end
    panel:SetHeight(height)
end

-- Names that have arrived are put in without asking the game about the craft.
local function Relabel()
    if not section:IsShown() or not basics then return end
    for _, row in ipairs(section.slotRows) do
        if row.shown and row.firstItem then row.name:SetText(ItemName(row.firstItem)) end
    end
    for _, row in ipairs(section.choiceRows) do
        if row.shown and row.GenerateMenu then row:GenerateMenu() end
    end
end

function UI.HideSimulation()
    if not section then return end
    section:Hide()
    panel.simulationToggle:Hide()
end

-- Called after every recount of the panel with the recipe on screen.
function UI.UpdateSimulation(recipeID, recipeBasics, reagents)
    if not section then return end
    panel.simulationToggle:Show()
    panel.simulationToggle.label:SetText(T(IsOn() and "CRAFTSIM_SIM_HIDE" or "CRAFTSIM_SIM_SHOW",
        IsOn() and "Hide simulation" or "Simulate other reagents and skill"))
    if not IsOn() then
        section:Hide()
        Resize()
        return
    end
    -- Another recipe: its own choices, starting from the window's.
    if recipeOf ~= recipeID then
        choice.tiers, choice.items, choice.extraSkill = {}, {}, 0
        section.extra:SetText("")
    end
    recipeOf, basics, windowReagents = recipeID, recipeBasics, reagents
    section:Show()
    section.height = Layout()
    section:SetHeight(section.height)
    UI.RefreshSimulation()
    Resize()
end

function UI.BuildSimulation(owner)
    panel = owner
    local toggle = CreateFrame("Button", nil, panel.body, "UIPanelButtonTemplate")
    toggle:SetSize(INNER, 20)
    toggle:SetPoint("TOPLEFT", panel.concentration, "BOTTOMLEFT", 0, -8)
    toggle.label = Text(toggle, 11, "CENTER", GOLD)
    toggle.label:SetPoint("CENTER", 0, 0)
    toggle:SetScript("OnClick", function()
        UI.DB().simulation = not IsOn()
        UI.MarkDirty()
    end)
    panel.simulationToggle = toggle

    section = CreateFrame("Frame", nil, panel.body)
    section:SetPoint("TOPLEFT", toggle, "BOTTOMLEFT", 0, -8)
    section:SetSize(INNER, 10)
    section.slotRows, section.choiceRows, section.height = {}, {}, 0
    section:Hide()
    panel.simulation = section

    -- Every quality slot at once.
    local presets = CreateFrame("Frame", nil, section)
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
            choice.tiers = {}
            for _, slot in ipairs(basics and basics.basicSlots or {}) do
                choice.tiers[slot.dataSlotIndex] = pick(slot)
            end
            UI.RefreshSimulation()
        end)
        presets.buttons[index] = button
    end
    Preset(1, "CRAFTSIM_PRESET_WINDOW", "As in window", function() return nil end)
    Preset(2, "CRAFTSIM_PRESET_BEST", "Best", function(slot) return slot.qualityCount end)
    Preset(3, "CRAFTSIM_PRESET_PLAIN", "Plain", function() return 1 end)
    section.presets = presets

    -- "+N skill": what if the skill were different.
    local extraRow = CreateFrame("Frame", nil, section)
    extraRow:SetSize(INNER, 20)
    local extraLabel = Text(extraRow, 12, "LEFT", GREY)
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
    section.extra, section.extraRow = extra, extraRow
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
    section.fill = fill

    section.result = Text(section, 12, "LEFT", GOLD)
    section.result:SetWidth(INNER)
    section.concentration = Text(section, 11, "LEFT", GREY)
    section.concentration:SetWidth(INNER)
    section.cost = Text(section, 11, "LEFT", GREY)
    section.cost:SetWidth(INNER)

    -- Item names arrive from the server a moment after they are first asked:
    -- the ones asked for here are put in, several at once.
    local pending = false
    section:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    section:SetScript("OnEvent", function(_, _, itemID, success)
        if not requested[itemID] or not success or pending then return end
        pending = true
        local function Later()
            pending = false
            Relabel()
        end
        if C_Timer and C_Timer.After then C_Timer.After(0.3, Later) else Later() end
    end)
end
