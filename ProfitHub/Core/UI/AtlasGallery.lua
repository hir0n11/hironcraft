local PT = HironCraftProfit
if not PT then return end

local USED = {
    "128-RedButton-Minus",
    "128-RedButton-Plus",
    "128-RedButton-Refresh",
    "Adventures-Parchment-Tile-Left",
    "Coin-Gold",
    "CreditsScreen-Assets-Buttons-Play",
    "CreditsScreen-Assets-Buttons-Pause",
    "GM-icon-settings",
    "Levelup-Icon-Bag",
    "Pencil-Icon",
    "Perks-ShoppingCart",
    "Profession",
    "Professions-ChatIcon-Quality-Tier5-Cap",
    "Professions_Icon_FirstTimeCraft",
    "StreamCinematic-Midnight-Large-Down",
    "UI-ChatIcon-Discord",
    "UI-QuestPoiLegendary-QuestBang-minimap-TurnIn",
    "UI_Icon_Chest_NPCreward",
    "Vehicle-Trap-Gold",
    "Warfronts-BaseMapIcons-Empty-Armory-Minimap",
    "Warfronts-BaseMapIcons-Empty-Heroes-Minimap",
    "Warfronts-FieldMapIcons-Empty-Banner-Minimap",
    "azsharawards-state2-zone4",
    "azsharawards-state2-zone4-cap",
    "charactercreate-customize-backbutton",
    "charactercreate-customize-nextbutton",
    "common-icon-checkmark",
    "common-icon-forwardarrow",
    "common-icon-redx",
    "glues-characterSelect-GS-TopHUD-iconShop",
    "housing-floor-arrow-down-default",
    "housing-floor-arrow-down-disabled",
    "housing-floor-arrow-up-default",
    "housing-floor-arrow-up-disabled",
    "poi-islands-table",
    "quest-recurring-available",
    "transmog-icon-chat",
    "transmog-icon-revert-small",
    "uitools-icon-close",
    "uitools-icon-refresh",
    "uitools-icon-search",
    "uitools-icon-settings",
    "Crosshair_unableinteract_32",
    "accountupgradebanner-classic",
    "accountupgradebanner-bc",
    "accountupgradebanner-wotlk",
    "accountupgradebanner-cataclysm",
    "accountupgradebanner-mop",
    "accountupgradebanner-wod",
    "accountupgradebanner-legion",
    "accountupgradebanner-bfa",
    "accountupgradebanner-shadowlands",
    "accountupgradebanner-dragonflight",
    "accountupgradebanner-thewarwithin",
}

local CANDIDATES = {
    "uitools-icon-close",
    "uitools-icon-minimize",
    "uitools-icon-collapse-window",
    "uitools-icon-external-window",
    "uitools-icon-settings",
    "uitools-icon-search",
    "uitools-icon-refresh",
    "uitools-icon-minus",
    "uitools-icon-plus",
    "uitools-icon-checkbox",
    "uitools-icon-checkmark",
    "uitools-icon-chevron-down",
    "uitools-icon-chevron-left",
    "uitools-icon-chevron-right",
    "uitools-icon-error",
    "uitools-icon-error-fill",
    "uitools-icon-warning",
    "uitools-icon-warning-fill",
    "uitools-icon-highlight",
    "uitools-icon-bar-fill",
    "uitools-icon-window-resize",
    "uitools-icon-window-resize-over",
    "uitools-icon-window-resize-down",
    "uitools-tab-background-default",
    "uitools-tab-background-default-hover",
    "uitools-tab-background-default-down",
    "uitools-tab-background-active",
    "uitools-tab-background-active-hover",
    "uitools-tab-background-active-down",
    "uitools-tab-gradient",
    "uitools-button-background-default",
    "uitools-button-background-default-hover",
    "uitools-button-background-default-down",
    "uitools-button-background-active",
    "uitools-button-background-active-hover",
    "uitools-button-background-active-down",
    "uitools-button-background-accent",
    "uitools-button-background-accent-hover",
    "uitools-button-background-accent-down",
    "uitools-button-background-disabled",
    "uitools-window-background",
    "uitools-window-background-shadow",
    "uitools-title-bar-background",
    "uitools-tooltip-background",
    "uitools-search-frame",
    "uitools-search-background",
    "uitools-row-background-01",
    "uitools-row-background-02",
    "uitools-row-background-hover",
    "uitools-scrollbar-track",
    "uitools-scrollbar-thumb",
    "uitools-scrollbar-thumb-over",
    "uitools-scrollbar-thumb-down",
    "uitools-scrollbar-chevron-top",
    "uitools-scrollbar-chevron-top-over",
    "uitools-scrollbar-chevron-top-down",
    "uitools-scrollbar-chevron-top-disabled",
    "uitools-scrollbar-chevron-bottom",
    "uitools-scrollbar-chevron-bottom-over",
    "uitools-scrollbar-chevron-bottom-down",
    "uitools-scrollbar-chevron-bottom-disabled",
}

local USAGE = {
    ["uitools-icon-settings"]   = "UI.lua:838 · filterBtn — фильтр окна знаний",
    ["uitools-icon-close"]      = "UI.lua:1525 · cx — кнопка закрытия (окно знаний)",
    ["uitools-icon-refresh"]    = "Panel:795 (CO «обновить»)\nSimulator:725 (auto-tool)\nShoppingList_UI:2965",
    ["uitools-icon-search"]     = "RecipeList_UI:1496/3635/4783 · trackIcon — трекер/поиск",
    ["GM-icon-settings"]        = "AccountOverview_UI:1535 · filterIcon — фильтр обзора",
    ["common-icon-checkmark"]   = "Галочка (чекбоксы/выполнено):\nAccountOverview, ClockBox/FarmTracker настройки,\nCO CustomList:396, RecipeList, ShoppingList",
    ["common-icon-redx"]        = "Красный X / удалить:\nAccountOverview, DisenchantSuper, FarmTracker,\nSimulator, RecipeList, ShoppingList_Selling",
    ["common-icon-forwardarrow"]= "ClockBox/FarmTracker настройки · play (запуск таймера)",
    ["Pencil-Icon"]             = "AccountOverview:3038 · noteBtn (заметка)\nCellGrid:114",
    ["Levelup-Icon-Bag"]        = "Gold.lua:277/285 — иконка золотодепозита",
    ["glues-characterSelect-GS-TopHUD-iconShop"] = "Token:117 + переключатель БД (UI/Concentration)",
    ["Coin-Gold"]               = "State.lua:305 — маркап золота",
    ["Perks-ShoppingCart"]      = "QuestShopping:1882\nShoppingList_Selling:265/762 — «купить»",
    ["housing-floor-arrow-down-default"] = "RecipeList_UI:860/862 · sortIcon — стрелки сортировки",
    ["housing-floor-arrow-up-default"]   = "RecipeList_UI:860/862 · sortIcon — стрелки сортировки",
    ["housing-floor-arrow-down-disabled"]= "RecipeList_UI · sortIcon (неактивная)",
    ["housing-floor-arrow-up-disabled"]  = "RecipeList_UI · sortIcon (неактивная)",
    ["128-RedButton-Plus"]      = "RecipeList_UI:1184 · qtyPlus",
    ["128-RedButton-Minus"]     = "RecipeList_UI:1241 · qtyMinus",
    ["128-RedButton-Refresh"]   = "ShoppingList_UI:2091 · refresh",
    ["transmog-icon-revert-small"] = "ShoppingList_Selling:555 · flipReset",
    ["transmog-icon-chat"]      = "AccountOverview:1767 · notifyChat",
    ["Crosshair_unableinteract_32"] = "UI.lua · filterBtn — фильтр окна знаний (новый)",
    ["UI-QuestPoiLegendary-QuestBang-minimap-TurnIn"] = "RecipeList · routeBtn — экспорт маршрута",
    ["Professions_Icon_FirstTimeCraft"] = "знания / первый крафт",
}

local function GetUsage(name)
    if USAGE[name] then return USAGE[name] end
    if name:find("^accountupgradebanner%-") then
        return "AccountOverview — баннер дополнения"
    end
    return nil
end

local gallery

local function MakeColumn(f, leftX, headerText, atlasList, getBox)
    local hdr = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontNormal")
    hdr:SetPoint("TOPLEFT", leftX, -64)
    hdr:SetText(headerText)

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", leftX, -82)
    scroll:SetPoint("BOTTOMLEFT", leftX, 120)
    scroll:SetWidth(282)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(262, 1)
    scroll:SetScrollChild(content)

    local rows = {}

    local function Refresh(filter)
        filter = (filter or ""):lower()
        local y = -2
        local shown = 0
        for _, name in ipairs(atlasList) do
            if filter == "" or name:lower():find(filter, 1, true) then
                shown = shown + 1
                local row = rows[shown]
                if not row then
                    row = CreateFrame("Button", nil, content)
                    row:SetHeight(40)
                    row.bg = row:CreateTexture(nil, "BACKGROUND")
                    row.bg:SetAllPoints()
                    row.bg:SetColorTexture(1, 1, 1, 0.04)
                    row.cell = row:CreateTexture(nil, "BORDER")
                    row.cell:SetSize(34, 34)
                    row.cell:SetPoint("LEFT", 3, 0)
                    row.cell:SetColorTexture(0.15, 0.15, 0.18, 1)
                    row.tex = row:CreateTexture(nil, "ARTWORK")
                    row.tex:SetSize(32, 32)
                    row.tex:SetPoint("CENTER", row.cell, "CENTER", 0, 0)
                    row.label = row:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontHighlightSmall")
                    row.label:SetPoint("LEFT", row.cell, "RIGHT", 6, 0)
                    row.label:SetPoint("RIGHT", -4, 0)
                    row.label:SetJustifyH("LEFT")
                    row.label:SetWordWrap(false)
                    row:SetScript("OnEnter", function(self)
                        self.bg:SetColorTexture(1, 1, 1, 0.14)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:AddLine(self.atlasName, 1, 1, 1)
                        local u = GetUsage(self.atlasName)
                        GameTooltip:AddLine(" ")
                        if u then
                            for line in (u .. "\n"):gmatch("(.-)\n") do
                                if line ~= "" then GameTooltip:AddLine(line, 0.80, 0.86, 1, true) end
                            end
                        else
                            GameTooltip:AddLine("контекст не собран (задаётся переменной или редко)", 0.6, 0.6, 0.6, true)
                        end
                        GameTooltip:Show()
                    end)
                    row:SetScript("OnLeave", function(self)
                        self.bg:SetColorTexture(1, 1, 1, 0.04)
                        GameTooltip:Hide()
                    end)
                    row:SetScript("OnClick", function(self)
                        local box = getBox()
                        box:SetText(self.atlasName)
                        box:HighlightText()
                        box:SetFocus()
                    end)
                    rows[shown] = row
                end

                row.atlasName = name
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, y)
                row:SetPoint("TOPRIGHT", 0, y)

                if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) then
                    row.tex:SetTexture(nil)
                    row.tex:SetAtlas(name)
                    row.tex:Show()
                    row.label:SetText(name)
                    row.label:SetTextColor(1, 1, 1)
                else
                    row.tex:Hide()
                    row.label:SetText(name .. " |cffff5555(нет)|r")
                    row.label:SetTextColor(0.7, 0.7, 0.7)
                end

                row:Show()
                y = y - 42
            end
        end
        for j = shown + 1, #rows do rows[j]:Hide() end
        content:SetHeight(math.max(1, -y + 4))
    end

    return Refresh
end

local function BuildGallery()
    if gallery then return gallery end

    local f = CreateFrame("Frame", "HironCraftProfit_AtlasGallery", UIParent, "BackdropTemplate")
    f:SetSize(640, 560)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    f:SetBackdropColor(0.04, 0.04, 0.06, 0.95)
    f:SetBackdropBorderColor(0.45, 0.40, 0.60, 1)

    local title = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontNormalLarge")
    title:SetPoint("TOP", 0, -8)
    title:SetText("HironCraft Atlas Gallery")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    local search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    search:SetPoint("TOPLEFT", 16, -34)
    search:SetPoint("TOPRIGHT", -28, -34)
    search:SetHeight(20)
    search:SetAutoFocus(false)

    -- mapping fields + export (bottom, full width)
    local exportBG = CreateFrame("Frame", nil, f, "BackdropTemplate")
    exportBG:SetPoint("BOTTOMLEFT", 14, 10)
    exportBG:SetPoint("BOTTOMRIGHT", -14, 10)
    exportBG:SetHeight(64)
    exportBG:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    exportBG:SetBackdropColor(0, 0, 0, 0.55)
    exportBG:SetBackdropBorderColor(0.30, 0.30, 0.42, 1)

    local exportBox = CreateFrame("EditBox", nil, exportBG)
    exportBox:SetPoint("TOPLEFT", 5, -5)
    exportBox:SetPoint("BOTTOMRIGHT", -5, 5)
    exportBox:SetMultiLine(true)
    exportBox:SetAutoFocus(false)
    exportBox:SetFontObject("HironCraftProfit_GameFontHighlightSmall")
    exportBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.exportBox = exportBox

    local srcBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    srcBox:SetPoint("BOTTOMLEFT", 14, 82)
    srcBox:SetSize(220, 20)
    srcBox:SetAutoFocus(false)
    srcBox:SetFontObject("HironCraftProfit_GameFontHighlightSmall")
    srcBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.srcBox = srcBox

    local arrow = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontNormal")
    arrow:SetPoint("LEFT", srcBox, "RIGHT", 5, 0)
    arrow:SetText("→")

    local tgtBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    tgtBox:SetPoint("LEFT", arrow, "RIGHT", 7, 0)
    tgtBox:SetSize(220, 20)
    tgtBox:SetAutoFocus(false)
    tgtBox:SetFontObject("HironCraftProfit_GameFontHighlightSmall")
    tgtBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.tgtBox = tgtBox

    local addBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    addBtn:SetSize(28, 20)
    addBtn:SetPoint("LEFT", tgtBox, "RIGHT", 7, 0)
    addBtn:SetText("+")
    addBtn:SetScript("OnClick", function()
        local s, t = srcBox:GetText(), tgtBox:GetText()
        if s == "" or t == "" then return end
        local cur = exportBox:GetText()
        local line = string.format('["%s"] = "%s",', s, t)
        exportBox:SetText((cur ~= "" and cur .. "\n" or "") .. line)
    end)

    local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearBtn:SetSize(28, 20)
    clearBtn:SetPoint("LEFT", addBtn, "RIGHT", 4, 0)
    clearBtn:SetText("X")
    clearBtn:SetScript("OnClick", function() exportBox:SetText("") end)

    local maplabel = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontDisableSmall")
    maplabel:SetPoint("BOTTOMLEFT", 14, 104)
    maplabel:SetText("Слева — что менять, справа — на что. [+] добавить пару в экспорт (Ctrl+A / Ctrl+C).")

    local refreshLeft  = MakeColumn(f, 16,  "Используется в HironCraft", USED, function() return f.srcBox end)
    local refreshRight = MakeColumn(f, 330, "Кандидаты (uitools)",      CANDIDATES, function() return f.tgtBox end)

    search:SetScript("OnTextChanged", function(self)
        local txt = self:GetText()
        refreshLeft(txt)
        refreshRight(txt)
    end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    refreshLeft("")
    refreshRight("")
    f:Hide()

    gallery = f
    return f
end

SLASH_HIRONCRAFT_PROFITATLAS1 = "/ahatlas"
SlashCmdList["HIRONCRAFT_PROFITATLAS"] = function()
    local f = BuildGallery()
    f:SetShown(not f:IsShown())
end
