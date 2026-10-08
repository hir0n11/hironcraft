local PT = HironCraftProfit
local S = PT and PT.CraftSimulator
local UI = S and S.UI
if not UI then return end

-- The second view of the skill panel: what the selected recipe gets from the
-- specializations, and what it would get with other ranks (CraftEngine/
-- SpecInfo.lua counts both). On top, the craft as the other view has it, at
-- the skill the ranks tried would give; then the stats now against what the
-- nodes give when maxed; then the nodes, each with a box for its rank. A rank
-- typed there is tried in place of the character's own, to see how many
-- knowledge points the top quality takes and where they can be saved.
-- Counted only while this view is the one shown.
local Text, T = UI.Text, UI.T
local INNER, GOLD, GREEN, GREY, WHITE = UI.INNER, UI.GOLD, UI.GREEN, UI.GREY, UI.WHITE

-- More nodes than a recipe has in one profession; beyond it they are counted, not listed.
local MAX_NODES = 16

local panel, view
local shown -- what the view shows now, as SpecInfo.For gave it

-- The names are CraftSim's, for whoever compares the two.
local STAT_NAMES = {
    skill = { "CRAFTSIM_SPEC_SKILL", "Skill" },
    multicraft = { "CRAFTSIM_SPEC_MULTICRAFT", "Multicraft" },
    additionalitemscraftedwithmulticraft = { "CRAFTSIM_SPEC_MULTICRAFT_ITEMS", "Multicraft extra items" },
    resourcefulness = { "CRAFTSIM_SPEC_RESOURCEFULNESS", "Resourcefulness" },
    reagentssavedfromresourcefulness = { "CRAFTSIM_SPEC_RESOURCEFULNESS_ITEMS", "Resourcefulness extra items" },
    ingenuity = { "CRAFTSIM_SPEC_INGENUITY", "Ingenuity" },
    ingenuityrefundincrease = { "CRAFTSIM_SPEC_INGENUITY_REFUND", "Ingenuity refund" },
    reduceconcentrationcost = { "CRAFTSIM_SPEC_LESS_CONCENTRATION", "Less concentration use" },
    craftingspeed = { "CRAFTSIM_SPEC_SPEED", "Crafting speed" },
}

local function Round(value)
    return math.floor(value + 0.5)
end

local function Number(value, percent)
    local text = tostring(Round(value))
    return percent and (text .. "%") or text
end

-- "+5 Skill, +3% Less concentration use"
local function StatsText(stats)
    local parts = {}
    for _, definition in ipairs(PT.SpecInfo.STATS) do
        local value = stats[definition.key]
        if value then
            local names = STAT_NAMES[definition.key]
            parts[#parts + 1] = "+" .. Number(value, definition.percent) .. " " .. T(names[1], names[2])
        end
    end
    return table.concat(parts, ", ")
end

-- A rank as it is written: "-" for a node that is not unlocked.
local function RankText(rank)
    return rank >= 0 and tostring(rank) or "-"
end

-- The rank a node counts with: the one tried, or the character's own.
local function Effective(node)
    return node.tried or (node.active and node.rank or -1)
end

-- What a node gives and at which ranks, with what the rank shown has reached.
local function NodeTip(row)
    local node, tooltip = row.node, PT.Tooltip
    if not node or not tooltip then return end
    local rank = Effective(node)
    tooltip:Clear()
    tooltip:AddLine((node.name or ("#" .. tostring(node.nodeID))) .. "  " .. RankText(rank) .. " / " .. tostring(node.maxRank),
        13, 1, 1, 1)
    if node.tried then
        tooltip:AddLine(string.format(T("CRAFTSIM_SPEC_TIP_OWN", "Your rank: %s"),
            RankText(node.active and node.rank or -1)), 11, GOLD[1], GOLD[2], GOLD[3])
    end
    if node.perRank then
        tooltip:AddLine(T("CRAFTSIM_SPEC_TIP_EACH", "Each rank") .. ": " .. StatsText(node.perRank), 11, 0.85, 0.85, 0.85)
    end
    for _, step in ipairs(node.steps) do
        local color = (step.rank and rank >= step.rank) and GREEN or GREY
        tooltip:AddLine(string.format(T("CRAFTSIM_SPEC_TIP_RANK", "Rank %s"), step.rank and tostring(step.rank) or "?")
            .. ": " .. StatsText(step.stats), 11, color[1], color[2], color[3])
    end
    tooltip:AddLine(T("CRAFTSIM_SPEC_TIP_BOX", "Type a rank to try it; \"-\" is a node not unlocked."), 10, 0.6, 0.6, 0.6)
    tooltip:ShowCursorRightOrBelow()
end

local function ClearTip()
    if PT.Tooltip then PT.Tooltip:Clear() end
end

local function StatRow(index)
    local row = view.statRows[index]
    if row then return row end
    row = CreateFrame("Frame", nil, view)
    row:SetSize(INNER, 15)
    row.label = Text(row, 11, "LEFT", GREY)
    row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.label:SetWidth(INNER - 96)
    row.value = Text(row, 11, "RIGHT", WHITE)
    row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    view.statRows[index] = row
    return row
end

-- Text put into a box by the panel itself is not the player typing.
local filling = false

local function NodeRow(index)
    local row = view.nodeRows[index]
    if row then return row end
    row = CreateFrame("Frame", nil, view)
    row:SetSize(INNER, 20)
    row:EnableMouse(true)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.name = Text(row, 11, "LEFT", WHITE)
    row.name:SetPoint("LEFT", row, "LEFT", 20, 0)
    row.name:SetWidth(INNER - 20 - 76)
    -- "/ 30" after the box with the rank.
    row.max = Text(row, 11, "LEFT", WHITE)
    row.max:SetPoint("LEFT", row, "RIGHT", -34, 0)
    local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    box:SetSize(30, 18)
    box:SetPoint("RIGHT", row, "RIGHT", -38, 0)
    box:SetAutoFocus(false)
    box:SetMaxLetters(3)
    box:SetJustifyH("CENTER")
    box:SetScript("OnTextChanged", function(self, userInput)
        local node = row.node
        if filling or not userInput or not node then return end
        local text = self:GetText() or ""
        local rank = text == "-" and -1 or tonumber(text)
        -- Emptied to type another: nothing to try yet.
        if not rank then return end
        rank = math.max(-1, math.min(node.maxRank, math.floor(rank)))
        local own = node.active and node.rank or -1
        PT.SpecInfo.Try(node.nodeID, rank ~= own and rank or nil)
        UI.MarkDirty()
    end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    -- A box left empty gets its rank back.
    box:SetScript("OnEditFocusLost", function() UI.MarkDirty() end)
    box:SetScript("OnTabPressed", function()
        local following = view.nodeRows[index + 1]
        if not (following and following.shown) then following = view.nodeRows[1] end
        if following and following.box.SetFocus then following.box:SetFocus() end
    end)
    box:SetScript("OnEnter", function() NodeTip(row) end)
    box:SetScript("OnLeave", ClearTip)
    row:SetScript("OnEnter", NodeTip)
    row:SetScript("OnLeave", ClearTip)
    row.box = box
    view.nodeRows[index] = row
    return row
end

-- Called on every recount of the panel while this view is the one shown.
-- basics and reagents are the recipe's slots and the window's reagents, nil
-- for a recipe whose craft is not counted (no quality, a recraft). Returns
-- false when no specialization affects the recipe.
function UI.ShowSpec(recipeID, name, basics, reagents)
    if not view then return false end
    local info = PT.SpecInfo and PT.SpecInfo.For(recipeID)
    if not info then return false end
    shown = info
    view.recipe:SetText(name or "")
    local y = 20
    local function Put(row, height)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", view, "TOPLEFT", 0, -y)
        row:Show()
        y = y + height
    end

    -- The craft, at the skill the ranks tried would give.
    local outcome = basics and UI.CraftOutcome(recipeID, basics, reagents, info.skillChange)
    if outcome and outcome.thresholds then
        Put(view.scale, 42)
        view.scale:Update(outcome)
        local status, color = UI.Status(outcome)
        view.status:SetText(status)
        view.status:SetTextColor(color[1], color[2], color[3])
        Put(view.status, 16)
    else
        view.scale:Hide()
        view.status:Hide()
    end

    -- What is tried and what it takes.
    if info.anyTried then
        local text = string.format(T("CRAFTSIM_SPEC_TRIED", "Tried: %+d skill, %+d points"),
            Round(info.skillChange), info.points)
        if info.points > 0 and info.unspent then
            text = text .. " " .. string.format(T("CRAFTSIM_SPEC_UNSPENT", "(%d unspent)"), info.unspent)
        end
        view.note:SetText(text)
        view.note:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    else
        view.note:SetText(T("CRAFTSIM_SPEC_HINT", "Change a rank below to try it"))
        view.note:SetTextColor(GREY[1], GREY[2], GREY[3])
    end
    Put(view.note, 15)
    Put(view.presets, 26)

    for index, stat in ipairs(info.stats) do
        local row = StatRow(index)
        local names = STAT_NAMES[stat.key] or { stat.key, stat.key }
        row.label:SetText(T(names[1], names[2]))
        local change = Round(stat.tried) - Round(stat.current)
        local value = Number(stat.tried, stat.percent)
        if change ~= 0 then value = value .. string.format(" (%+d%s)", change, stat.percent and "%" or "") end
        row.value:SetText(value .. " / " .. Number(stat.max, stat.percent))
        -- All of it is green; a number that is tried, not real, is gold.
        local color = WHITE
        if stat.tried >= stat.max then
            color = GREEN
        elseif change ~= 0 then
            color = GOLD
        end
        row.value:SetTextColor(color[1], color[2], color[3])
        Put(row, 15)
    end
    for index = #info.stats + 1, #view.statRows do view.statRows[index]:Hide() end
    if #info.stats > 0 then y = y + 6 end

    filling = true
    local listed = math.min(#info.nodes, MAX_NODES)
    for index = 1, listed do
        local node, row = info.nodes[index], NodeRow(index)
        local rank = Effective(node)
        row.node, row.shown = node, true
        row.icon:SetTexture(node.icon or 134400)
        row.icon:SetDesaturated(rank < 0)
        row.name:SetText(node.name or ("#" .. tostring(node.nodeID)))
        -- A node not unlocked is greyed, a maxed one is green.
        local color = WHITE
        if rank < 0 then
            color = GREY
        elseif rank >= node.maxRank then
            color = GREEN
        end
        row.name:SetTextColor(color[1], color[2], color[3])
        row.max:SetText("/ " .. tostring(node.maxRank))
        row.max:SetTextColor(color[1], color[2], color[3])
        row.box:SetText(RankText(rank))
        -- A rank that is tried, not the character's own, is gold.
        local boxColor = node.tried and GOLD or WHITE
        row.box:SetTextColor(boxColor[1], boxColor[2], boxColor[3])
        Put(row, 20)
    end
    filling = false
    for index = listed + 1, #view.nodeRows do
        view.nodeRows[index].shown = false
        view.nodeRows[index]:Hide()
    end
    if #info.nodes > listed then
        view.more:SetText(string.format(T("CRAFTSIM_SPEC_MORE", "and %d more"), #info.nodes - listed))
        Put(view.more, 14)
    else
        view.more:Hide()
    end
    view:SetHeight(y)
    panel:SetHeight(UI.TOP + y + 14)
    return true
end

function UI.BuildSpec(owner)
    panel = owner
    view = CreateFrame("Frame", nil, panel)
    view:SetPoint("TOPLEFT", panel, "TOPLEFT", UI.PAD, -UI.TOP)
    view:SetSize(INNER, 80)
    view.statRows, view.nodeRows = {}, {}
    view.recipe = Text(view, 13, "LEFT", GOLD)
    view.recipe:SetPoint("TOPLEFT", view, "TOPLEFT", 0, 0)
    view.recipe:SetWidth(INNER)
    view.scale = UI.NewScale(view)
    view.status = Text(view, 12, "LEFT", GOLD)
    view.status:SetWidth(INNER)
    view.note = Text(view, 11, "LEFT", GREY)
    view.note:SetWidth(INNER)
    view.more = Text(view, 11, "LEFT", GREY)
    view.more:SetWidth(INNER)

    -- Every node of the recipe at once.
    local presets = CreateFrame("Frame", nil, view)
    presets:SetSize(INNER, 20)
    presets.buttons = {}
    local function Preset(index, key, fallback, apply)
        local width = (INNER - 4) / 2
        local button = CreateFrame("Button", nil, presets, "UIPanelButtonTemplate")
        button:SetSize(width, 20)
        button:SetPoint("LEFT", presets, "LEFT", (index - 1) * (width + 4), 0)
        button.label = Text(button, 10, "CENTER", WHITE)
        button.label:SetPoint("CENTER", 0, 0)
        button.label:SetText(T(key, fallback))
        button:SetScript("OnClick", function()
            apply()
            UI.MarkDirty()
        end)
        presets.buttons[index] = button
    end
    -- Back to the character's own ranks, for every recipe.
    Preset(1, "CRAFTSIM_SPEC_OWN", "Your ranks", function() PT.SpecInfo.ForgetTried() end)
    Preset(2, "CRAFTSIM_SPEC_MAXED", "All maxed", function()
        for _, node in ipairs(shown and shown.nodes or {}) do
            local own = node.active and node.rank or -1
            PT.SpecInfo.Try(node.nodeID, node.maxRank ~= own and node.maxRank or nil)
        end
    end)
    view.presets = presets

    view:Hide()
    panel.spec = view
end
