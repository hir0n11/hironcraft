local PT = HironCraftProfit
if not PT or not PT.CraftSimulator then return end

-- The skill panel beside the profession window: its frame, its button above
-- Create, and when it recounts. What it shows is in CraftSimulator_Sim.lua;
-- the counting is in CraftEngine/Simulator.lua.
--
-- It must never make the profession window slow. Nothing is built or asked
-- until the panel is first shown; while it is hidden the hooks only set a
-- flag; shown, it recounts the selected recipe at most once a frame.
local S = PT.CraftSimulator
local CE = PT.CraftEngine
local UI = {}
S.UI = UI

local WIDTH, PAD = 270, 12
local INNER = WIDTH - 2 * PAD
local GOLD = { 1, 0.82, 0 }
local GREEN = { 0.35, 0.9, 0.45 }
local GREY = { 0.62, 0.62, 0.62 }
local WHITE = { 1, 1, 1 }

local function T(key, fallback)
    local text = PT.L and PT.L[key]
    return type(text) == "string" and text ~= "" and text or fallback
end

-- Saved for the account; read only once the game has loaded saved variables.
local function DB()
    _G.HironCraftProfit_DB = _G.HironCraftProfit_DB or {}
    local db = _G.HironCraftProfit_DB
    if type(db.craftSimulator) ~= "table" then db.craftSimulator = {} end
    return db.craftSimulator
end
UI.DB = DB

-- What is saved, without creating anything: for looking only.
local function Saved()
    local db = _G.HironCraftProfit_DB
    local saved = type(db) == "table" and db.craftSimulator
    return type(saved) == "table" and saved or {}
end

local function Page()
    return ProfessionsFrame and ProfessionsFrame.CraftingPage
end

local function Form()
    local page = Page()
    return page and page.SchematicForm
end

local toggle, panel
local dirty = true
local basicsOf, basics

local function MarkDirty()
    dirty = true
end
UI.MarkDirty = MarkDirty

local function Text(parent, size, justify, color)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    if PT.FONT then text:SetFont(PT.FONT, size or 12, "") end
    text:SetJustifyH(justify or "LEFT")
    text:SetWordWrap(false)
    color = color or WHITE
    text:SetTextColor(color[1], color[2], color[3])
    return text
end

local function Tier(quality)
    return "T" .. tostring(quality)
end

-- For the part of the panel that shows the craft.
UI.Text, UI.T, UI.Tier = Text, T, Tier
UI.INNER, UI.PAD, UI.GOLD, UI.GREEN, UI.GREY, UI.WHITE = INNER, PAD, GOLD, GREEN, GREY, WHITE

local function ShowMessage(text)
    panel.message:SetText(text)
    panel.message:Show()
    panel.body:Hide()
    panel:SetHeight(36 + 34)
end

-- The reagents chosen in the window, as the game wants them.
local function WindowReagents(form)
    local transaction = form and form.GetTransaction and form:GetTransaction()
    if not transaction or type(transaction.CreateCraftingReagentInfoTbl) ~= "function" then return {} end
    local ok, reagents = pcall(transaction.CreateCraftingReagentInfoTbl, transaction)
    return ok and type(reagents) == "table" and reagents or {}
end

function UI.Refresh()
    if not panel then return end
    local started = debugprofilestop and debugprofilestop()
    local form = Form()
    local recipeInfo = form and form.GetRecipeInfo and form:GetRecipeInfo()
    local recipeID = type(recipeInfo) == "table" and tonumber(recipeInfo.recipeID)
    if not recipeID or (form.IsShown and not form:IsShown()) then
        ShowMessage(T("CRAFTSIM_NO_RECIPE", "Select a recipe."))
        return
    end
    -- A recraft is counted from the item being recrafted, which is not asked here.
    if recipeInfo.isRecraft then
        ShowMessage(T("CRAFTSIM_NO_DATA", "No data for this recipe."))
        return
    end
    -- The recipe's slots do not change: looked up once per recipe.
    if basicsOf ~= recipeID then
        basicsOf, basics = recipeID, CE:GetRecipeBasics(recipeID)
    end
    if type(basics) ~= "table" then
        ShowMessage(T("CRAFTSIM_NO_DATA", "No data for this recipe."))
    elseif (tonumber(basics.maxQuality) or 0) < 2 then
        ShowMessage(T("CRAFTSIM_NO_QUALITY", "This recipe has no quality."))
    else
        -- Shown first: the craft sizes the panel around its rows.
        panel.message:Hide()
        panel.body:Show()
        if not UI.ShowCraft(recipeID, basics, WindowReagents(form), recipeInfo.name) then
            ShowMessage(T("CRAFTSIM_NO_DATA", "No data for this recipe."))
        end
    end
    if started then DB().lastMs = math.floor((debugprofilestop() - started) * 100 + 0.5) / 100 end
end

local function Place()
    local db = Saved()
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", tonumber(db.x) or 6, tonumber(db.y) or -240)
end

local function BuildPanel()
    local page = Page()
    panel = CreateFrame("Frame", "HironCraftCraftSimulator", page, "BackdropTemplate")
    panel:SetSize(WIDTH, 120)
    panel:SetFrameStrata("HIGH")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true,
        tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    panel:SetBackdropColor(0.06, 0.05, 0.04, 0.96)
    panel:SetBackdropBorderColor(0.65, 0.55, 0.35, 1)
    panel:Hide()
    Place()

    local drag = CreateFrame("Frame", nil, panel)
    drag:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -4)
    drag:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -28, -4)
    drag:SetHeight(24)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() panel:StartMoving() end)
    drag:SetScript("OnDragStop", function()
        panel:StopMovingOrSizing()
        -- Kept relative to the profession window, wherever that is opened.
        local left, top = panel:GetLeft(), panel:GetTop()
        local right, frameTop = ProfessionsFrame:GetRight(), ProfessionsFrame:GetTop()
        if left and top and right and frameTop then
            local db = DB()
            db.x, db.y = math.floor(left - right + 0.5), math.floor(top - frameTop + 0.5)
            Place()
        end
    end)
    local title = Text(drag, 13, "CENTER", GOLD)
    title:SetPoint("CENTER", drag, "CENTER", 11, 0)
    title:SetText(T("CRAFTSIM_TITLE", "Skill for quality"))

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function() UI.SetShown(false) end)

    panel.message = Text(panel, 12, "CENTER", GREY)
    panel.message:SetPoint("TOP", panel, "TOP", 0, -40)
    panel.message:SetWidth(INNER)

    local body = CreateFrame("Frame", nil, panel)
    body:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -32)
    body:SetSize(INNER, 80)
    panel.body = body
    UI.BuildCraft(panel)

    panel:SetScript("OnShow", MarkDirty)
    panel:SetScript("OnUpdate", function()
        if not dirty then return end
        dirty = false
        UI.Refresh()
    end)
end

function UI.IsShown()
    return panel ~= nil and panel:IsShown()
end

function UI.SetShown(on)
    DB().shown = on and true or false
    if on and not panel then BuildPanel() end
    if panel then panel:SetShown(on and true or false) end
    if on then MarkDirty() end
end

local hooked = false
local function Hook()
    local page, form = Page(), Form()
    if hooked or not page or not form then return end
    hooked = true
    -- All of these only set a flag; the panel recounts when it is shown.
    if hooksecurefunc then
        if page.SelectRecipe then hooksecurefunc(page, "SelectRecipe", MarkDirty) end
        if form.UpdateDetailsStats then hooksecurefunc(form, "UpdateDetailsStats", MarkDirty) end
    end
    local events = ProfessionsRecipeSchematicFormMixin and ProfessionsRecipeSchematicFormMixin.Event
    if events and form.RegisterCallback then
        for _, name in ipairs({ "AllocationsModified", "UseBestQualityModified" }) do
            if events[name] then pcall(form.RegisterCallback, form, events[name], MarkDirty, UI) end
        end
    end
end

local function BuildToggle()
    local page = Page()
    if toggle or not page then return end
    -- Inside the window, right above its Create button.
    toggle = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    toggle:SetSize(80, 22)
    if page.CreateButton then
        toggle:SetPoint("BOTTOMRIGHT", page.CreateButton, "TOPRIGHT", 0, 10)
    else
        toggle:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -10, 38)
    end
    toggle:SetFrameLevel((page:GetFrameLevel() or 0) + 20)
    toggle.label = Text(toggle, 11, "CENTER", GOLD)
    toggle.label:SetPoint("CENTER", 0, 0)
    toggle.label:SetText(T("CRAFTSIM_TOGGLE", "Skill"))
    toggle:SetScript("OnClick", function() UI.SetShown(not UI.IsShown()) end)
    toggle:SetScript("OnEnter", function()
        local tooltip = PT.Tooltip
        if not tooltip then return end
        tooltip:Clear()
        tooltip:AddLine(T("CRAFTSIM_TITLE", "Skill for quality"), 13, 1, 1, 1)
        tooltip:AddLine(T("CRAFTSIM_TOGGLE_TIP",
            "The skill each quality of the selected recipe needs, tried with any reagents and skill."),
            11, 0.8, 0.8, 0.8)
        tooltip:ShowCursorRightOrBelow()
    end)
    toggle:SetScript("OnLeave", function()
        if PT.Tooltip then PT.Tooltip:Clear() end
    end)
    -- Left open last time: open again with the crafting page. The label is
    -- set again here: the button can be made before the addon's language is.
    toggle:SetScript("OnShow", function()
        toggle.label:SetText(T("CRAFTSIM_TOGGLE", "Skill"))
        if Saved().shown and not UI.IsShown() then UI.SetShown(true) end
    end)
    Hook()
    if toggle:IsVisible() and Saved().shown then UI.SetShown(true) end
end

if not CreateFrame then return end

local events = CreateFrame("Frame")
for _, event in ipairs({ "ADDON_LOADED", "TRADE_SKILL_SHOW", "PLAYER_EQUIPMENT_CHANGED", "TRAIT_CONFIG_UPDATED",
    "SKILL_LINES_CHANGED", "TRADE_SKILL_ITEM_CRAFTED_RESULT" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == "Blizzard_Professions" then BuildToggle() end
    elseif event == "TRADE_SKILL_SHOW" then
        BuildToggle()
        MarkDirty()
    else
        -- Gear, specialization or skill changed: the numbers may have too.
        MarkDirty()
    end
end)
