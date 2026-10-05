local PT = HironCraftProfit
local S = PT and PT.CraftSimulator
local UI = S and S.UI
if not UI then return end

-- The second view of the skill panel: what the selected recipe gets from the
-- specializations (CraftEngine/SpecInfo.lua counts it). Stats now against
-- what the nodes would give when maxed, then the nodes with their ranks.
-- Counted only while this view is the one shown.
local Text, T = UI.Text, UI.T
local INNER, GOLD, GREEN, GREY, WHITE = UI.INNER, UI.GOLD, UI.GREEN, UI.GREY, UI.WHITE

-- More nodes than a recipe has in one profession; beyond it they are counted, not listed.
local MAX_NODES = 16

local panel, view

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

local function Number(value, percent)
    local text = tostring(math.floor(value + 0.5))
    return percent and (text .. "%") or text
end

local function StatRow(index)
    local row = view.statRows[index]
    if row then return row end
    row = CreateFrame("Frame", nil, view)
    row:SetSize(INNER, 15)
    row.label = Text(row, 11, "LEFT", GREY)
    row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.label:SetWidth(INNER - 68)
    row.value = Text(row, 11, "RIGHT", WHITE)
    row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    view.statRows[index] = row
    return row
end

local function NodeRow(index)
    local row = view.nodeRows[index]
    if row then return row end
    row = CreateFrame("Frame", nil, view)
    row:SetSize(INNER, 18)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.name = Text(row, 11, "LEFT", WHITE)
    row.name:SetPoint("LEFT", row, "LEFT", 20, 0)
    row.name:SetWidth(INNER - 20 - 54)
    row.rank = Text(row, 11, "RIGHT", WHITE)
    row.rank:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    view.nodeRows[index] = row
    return row
end

-- Called on every recount of the panel while this view is the one shown.
-- Returns false when no specialization affects the recipe.
function UI.ShowSpec(recipeID, name)
    if not view then return false end
    local info = PT.SpecInfo and PT.SpecInfo.For(recipeID)
    if not info then return false end
    view.recipe:SetText(name or "")
    local y = 20
    local function Put(row, height)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", view, "TOPLEFT", 0, -y)
        row:Show()
        y = y + height
    end
    for index, stat in ipairs(info.stats) do
        local row = StatRow(index)
        local names = STAT_NAMES[stat.key] or { stat.key, stat.key }
        row.label:SetText(T(names[1], names[2]))
        row.value:SetText(Number(stat.current, stat.percent) .. " / " .. Number(stat.max, stat.percent))
        local color = stat.current >= stat.max and GREEN or WHITE
        row.value:SetTextColor(color[1], color[2], color[3])
        Put(row, 15)
    end
    for index = #info.stats + 1, #view.statRows do view.statRows[index]:Hide() end
    if #info.stats > 0 then y = y + 6 end

    local listed = math.min(#info.nodes, MAX_NODES)
    for index = 1, listed do
        local node, row = info.nodes[index], NodeRow(index)
        row.icon:SetTexture(node.icon or 134400)
        row.icon:SetDesaturated(not node.active)
        row.name:SetText(node.name or ("#" .. tostring(node.nodeID)))
        -- A node not unlocked yet is greyed and has no rank; a maxed one is green.
        local color = WHITE
        if not node.active then
            color = GREY
        elseif node.rank >= node.maxRank then
            color = GREEN
        end
        row.name:SetTextColor(color[1], color[2], color[3])
        row.rank:SetText((node.active and tostring(node.rank) or "-") .. " / " .. tostring(node.maxRank))
        row.rank:SetTextColor(color[1], color[2], color[3])
        Put(row, 18)
    end
    for index = listed + 1, #view.nodeRows do view.nodeRows[index]:Hide() end
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
    view.more = Text(view, 11, "LEFT", GREY)
    view.more:SetWidth(INNER)
    view:Hide()
    panel.spec = view
end
