local PT = HironCraftProfit
if not PT then return end

local FC = {}
PT.FirstCraft = FC

local ICON_ATLAS = "Professions_Icon_FirstTimeCraft"
local ICON_W     = 10
local ICON_H     = 13
local ICON_X     = -2

local function IsEnabled()
    return not (PT.config and PT.config.showFirstCraftIcons == false)
end

local function GetRowRecipeInfo(frame)
    if not frame or not frame.GetElementData then return nil end

    local ok, node = pcall(frame.GetElementData, frame)
    if not ok or type(node) ~= "table" then return nil end

    local data = node
    if node.GetData then
        local ok2, d = pcall(node.GetData, node)
        if ok2 and type(d) == "table" then data = d end
    elseif type(node.data) == "table" then
        data = node.data
    end

    return data and data.recipeInfo
end

local function EnsureIcon(frame)
    if frame.ahuiFirstCraftIcon then return frame.ahuiFirstCraftIcon end

    local t = frame:CreateTexture(nil, "OVERLAY")
    t:SetSize(ICON_W, ICON_H)
    t:SetPoint("RIGHT", frame, "RIGHT", ICON_X, 0)
    if t.SetAtlas then t:SetAtlas(ICON_ATLAS, false) end

    frame.ahuiFirstCraftIcon = t
    return t
end

local function UpdateFrame(frame)
    local show = false

    if IsEnabled() then
        local ri = GetRowRecipeInfo(frame)
        if ri and ri.learned and ri.firstCraft then
            show = true
        end
    end

    if show then
        EnsureIcon(frame):Show()
    elseif frame.ahuiFirstCraftIcon then
        frame.ahuiFirstCraftIcon:Hide()
    end
end

local function GetScrollBox()
    local cp = ProfessionsFrame and ProfessionsFrame.CraftingPage
    local rl = cp and cp.RecipeList
    return rl and rl.ScrollBox
end

function FC:UpdateAll()
    local sb = GetScrollBox()
    if not sb or not sb.GetFrames then return end

    local ok, frames = pcall(sb.GetFrames, sb)
    if not ok or type(frames) ~= "table" then return end

    for _, frame in ipairs(frames) do
        pcall(UpdateFrame, frame)
    end
end

local function TryHook()
    local sb = GetScrollBox()
    if not sb or sb.__ahuiFirstCraftHooked then return end

    sb.__ahuiFirstCraftHooked = true
    if hooksecurefunc and sb.Update then
        hooksecurefunc(sb, "Update", function() FC:UpdateAll() end)
    end

    FC:UpdateAll()
end

function FC:SetEnabled(on)
    PT.config = PT.config or {}
    PT.config.showFirstCraftIcons = on and true or false
    self:UpdateAll()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("TRADE_SKILL_SHOW")
ev:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
ev:RegisterEvent("NEW_RECIPE_LEARNED")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_Professions" then TryHook() end
    else
        TryHook()
        FC:UpdateAll()
    end
end)

SLASH_HIRONCRAFT_PROFITFIRSTCRAFT1 = "/ahfirstcraft"
SlashCmdList["HIRONCRAFT_PROFITFIRSTCRAFT"] = function()
    FC:SetEnabled(not IsEnabled())
    print("|cffb19cd9HironCraft:|r first-craft icons " .. (IsEnabled() and "ON" or "OFF"))
end
