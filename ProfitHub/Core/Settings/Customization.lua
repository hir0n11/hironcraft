local PT = HironCraftProfit
if not PT then return end
local L = PT.L
local LABEL_W = 90
local TIMER_FONTS = {
    {
        key  = "Gotham",
        name = "Gotham Narrow",
        path = "Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\fonts\\default.ttf",
    },
    {
        key  = "Friz",
        name = "Friz Quadrata",
        path = "Fonts\\FRIZQT__.TTF",
    },
    {
        key  = "Arial",
        name = "Arial Narrow",
        path = "Fonts\\ARIALN.TTF",
    },
	{
		key  = "Broadsheet",
		name = "Broadsheet",
		path = "Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\fonts\\Broadsheet.ttf",
	},
	    {
        key  = "InterTight-Regular",
        name = "Inter Tight Regular",
        path = "Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\fonts\\InterTight-1.ttf",
    },
    {
        key  = "InterTight-Medium",
        name = "Inter Tight Medium",
        path = "Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\fonts\\InterTight-2.ttf",
    },
    {
        key  = "InterTight-SemiBold",
        name = "Inter Tight SemiBold",
        path = "Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\fonts\\InterTight-3.ttf",
    },
    {
        key  = "InterTight-Bold",
        name = "Inter Tight Bold",
        path = "Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\fonts\\InterTight-4.ttf",
    },
    {
        key  = "RobotoCondensed-Regular",
        name = "Roboto Condensed",
        path = "Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\fonts\\RobotoCondensed-1.ttf",
    },
    {
        key  = "RobotoCondensed-Bold",
        name = "Roboto Condensed Bold",
        path = "Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\fonts\\RobotoCondensed-2.ttf",
    },
    {
        key  = "RobotoCondensed-Black",
        name = "Roboto Condensed Black",
        path = "Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\fonts\\RobotoCondensed-3.ttf",
    },
	    {
        key  = "JetBrainsMono",
        name = "JetBrains Mono",
        path = "Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\fonts\\JetBrainsMono.ttf",
    },
    {
        key  = "CorrectionTape",
        name = "Correction Tape",
        path = "Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\fonts\\CorrectionTape.otf",
    },
    {
        key  = "KomPost",
        name = "Kompost",
        path = "Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\fonts\\kom-post.ttf",
    },
    {
        key  = "Neverwinter",
        name = "Neverwinter",
        path = "Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\fonts\\Neverwinter.ttf",
    },
    {
        key  = "RobotoCondensed-Light",
        name = "Roboto Condensed Light",
        path = "Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\fonts\\robotocondensedlight.ttf",
    },
    {
        key  = "SignPainter",
        name = "SignPainter HouseScript",
        path = "Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\fonts\\signpainter_housescript.otf",
    },
    {
        key  = "Unsightly",
        name = "Unsightly",
        path = "Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\fonts\\Unsightly.ttf",
    },
}

local DEFAULTS = {
    concentration = {
        barAlpha = 1,

        barColor       = { r = 64/255, g = 186/255, b = 255/255, a = 1 },

        timerTextColor = { r = 1, g = 1, b = 1, a = 1 },
		timerFont = "Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\fonts\\default.ttf",
		timerFontSize = 11,
        dividerColor   = { r = 1, g = 1, b = 1, a = 1 },
		backgroundColor = { r = 0, g = 0, b = 0, a = 0.5 },

        border     = { enabled = true, color = { r=0, g=0, b=0, a=1 } },
        iconBorder = { enabled = true, color = { r=0, g=0, b=0, a=1 } },
    },

    professionsWindow = {
        backgroundColor = { r=0, g=0, b=0, a=0 },
        borderColor     = { r=0, g=0, b=0, a=0 },

        headerColor     = { r=0.10, g=0.10, b=0.10, a=0.85 },

        font            = "Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\fonts\\default.ttf",
        fontSize        = 11,
        fontColor       = { r=1, g=1, b=1, a=1 },
    },

    farmTracker = {
        backgroundColor = { r=0.10, g=0.10, b=0.10, a=0.85 },
        borderColor     = { r=1,    g=1,    b=1,    a=0.35 },
        
        dividerColor    = { r=1,    g=1,    b=1,    a=0.30 },

        accentTextColor = { r=1,    g=0.84, b=0.20, a=1 },
        textColor       = { r=1,    g=1,    b=1,    a=1 },
        mutedTextColor  = { r=0.72, g=0.80, b=0.90, a=1 },
    },
}

local CUSTOMIZATION_DEFAULTS_VERSION = 2

local function DeepCopy(src)
    if type(src) ~= "table" then
        return src
    end

    local dst = {}

    for k, v in pairs(src) do
        dst[k] = DeepCopy(v)
    end

    return dst
end

local function ResetCustomizationToCurrentDefaults(c)
    c.concentration      = DeepCopy(DEFAULTS.concentration)
    c.professionsWindow  = DeepCopy(DEFAULTS.professionsWindow)
    c.farmTracker        = DeepCopy(DEFAULTS.farmTracker)

    c.__defaultsVersion = CUSTOMIZATION_DEFAULTS_VERSION
end

local function CopyColor(src)
    return { r=src.r, g=src.g, b=src.b, a=src.a }
end

local function EnsureCustomization()
    PT.config = PT.config or {}
    PT.config.customization = PT.config.customization or {}

    local c = PT.config.customization

    if c.__defaultsVersion ~= CUSTOMIZATION_DEFAULTS_VERSION then
        ResetCustomizationToCurrentDefaults(c)
    end

    c.concentration = c.concentration or {}
    local cc = c.concentration

    if cc.barAlpha == nil then cc.barAlpha = DEFAULTS.concentration.barAlpha end

    if cc.barColor == nil then cc.barColor = CopyColor(DEFAULTS.concentration.barColor) end
    if cc.timerTextColor == nil then cc.timerTextColor = CopyColor(DEFAULTS.concentration.timerTextColor) end
	if cc.timerFont == nil then
		cc.timerFont = DEFAULTS.concentration.timerFont
	end
	if cc.timerFontSize == nil then
		cc.timerFontSize = DEFAULTS.concentration.timerFontSize
	end
    if cc.dividerColor == nil then cc.dividerColor = CopyColor(DEFAULTS.concentration.dividerColor) end
	if cc.backgroundColor == nil then
		cc.backgroundColor = CopyColor(DEFAULTS.concentration.backgroundColor)
	end

    if cc.border == nil then
        cc.border = { enabled = DEFAULTS.concentration.border.enabled, color = CopyColor(DEFAULTS.concentration.border.color) }
    else
        if cc.border.enabled == nil then cc.border.enabled = DEFAULTS.concentration.border.enabled end
        cc.border.color = cc.border.color or CopyColor(DEFAULTS.concentration.border.color)
        if cc.border.color.a == nil then cc.border.color.a = 1 end
    end

    if cc.iconBorder == nil then
        cc.iconBorder = { enabled = DEFAULTS.concentration.iconBorder.enabled, color = CopyColor(DEFAULTS.concentration.iconBorder.color) }
    else
        if cc.iconBorder.enabled == nil then cc.iconBorder.enabled = DEFAULTS.concentration.iconBorder.enabled end
        cc.iconBorder.color = cc.iconBorder.color or CopyColor(DEFAULTS.concentration.iconBorder.color)
        if cc.iconBorder.color.a == nil then cc.iconBorder.color.a = 1 end
    end

	c.professionsWindow = c.professionsWindow or {}
	local pw = c.professionsWindow

	if pw.backgroundColor == nil then
		pw.backgroundColor = CopyColor(DEFAULTS.professionsWindow.backgroundColor)
	end

	if pw.borderColor == nil then
		pw.borderColor = CopyColor(DEFAULTS.professionsWindow.borderColor)
	end

	if pw.headerColor == nil then
		pw.headerColor = CopyColor(DEFAULTS.professionsWindow.headerColor)
	end

	if pw.font == nil then
		pw.font = DEFAULTS.professionsWindow.font
	end

	if pw.fontSize == nil then
		pw.fontSize = DEFAULTS.professionsWindow.fontSize
	end

	if pw.fontColor == nil then
		pw.fontColor = CopyColor(DEFAULTS.professionsWindow.fontColor)
	end

    c.farmTracker = c.farmTracker or {}
    local ft = c.farmTracker

    if ft.backgroundColor == nil then
        ft.backgroundColor = CopyColor(DEFAULTS.farmTracker.backgroundColor)
    end

    if ft.borderColor == nil then
        ft.borderColor = CopyColor(DEFAULTS.farmTracker.borderColor)
    end

    if ft.dividerColor == nil then
        ft.dividerColor = CopyColor(DEFAULTS.farmTracker.dividerColor)
    end

    if ft.accentTextColor == nil then
        ft.accentTextColor = CopyColor(DEFAULTS.farmTracker.accentTextColor)
    end

    if ft.textColor == nil then
        ft.textColor = CopyColor(DEFAULTS.farmTracker.textColor)
    end

    if ft.mutedTextColor == nil then
        ft.mutedTextColor = CopyColor(DEFAULTS.farmTracker.mutedTextColor)
    end

    return c
end

local function GetConcCfg()
    return EnsureCustomization().concentration
end

local function EnsurePreviewTable(cfg)
    cfg.__preview = cfg.__preview or {}
    return cfg.__preview
end

local function GetProfCfg()
    return EnsureCustomization().professionsWindow
end

local function OpenColorPicker(current, defaults, onPreview, onAccept, onCancel)
    local cr, cg, cb, ca = current.r or 1, current.g or 1, current.b or 1, current.a or 1
    local dr, dg, db, da = defaults.r or 1, defaults.g or 1, defaults.b or 1, defaults.a or 1

    local function GetRGBA()
        local r, g, b = ColorPickerFrame:GetColorRGB()

        local opacity = nil
        if ColorPickerFrame.GetColorAlpha then
            opacity = ColorPickerFrame:GetColorAlpha()
        end
        if opacity == nil and OpacitySliderFrame and OpacitySliderFrame.GetValue then
            opacity = OpacitySliderFrame:GetValue()
        end
        if opacity == nil then opacity = 0 end

        local a = 1 - opacity
        return r, g, b, a
    end

    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = cr, g = cg, b = cb,

            opacity = 1 - ca,
            hasOpacity = true,

            previousValues = { cr, cg, cb, 1 - ca },
            defaultValues  = { dr, dg, db, 1 - da },

            resetButtonText = L["DEFAULT"] or "По умолчанию",

            resetFunc = function()
                if onPreview then onPreview(dr, dg, db, da) end
            end,

            swatchFunc = function()
                local r, g, b, a = GetRGBA()
                if onPreview then onPreview(r, g, b, a) end
            end,

            opacityFunc = function()
                local r, g, b, a = GetRGBA()
                if onPreview then onPreview(r, g, b, a) end
            end,

            okayFunc = function()
                local r, g, b, a = GetRGBA()
                if onAccept then onAccept(r, g, b, a) end
            end,

            cancelFunc = function()
                if onAccept then onAccept(cr, cg, cb, ca) end
                if onCancel then onCancel() end
            end,
        })
    end
end

local function CreateColorButton(parent, x, y, labelText, previewKey, getColor, getDefault, setColor, getOwnerCfg, applyNow)
    local label = parent:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	label:SetWidth(LABEL_W)
	label:SetJustifyH("LEFT")
    label:SetText(labelText)

    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(24, 14)
    btn:SetPoint("LEFT", label, "RIGHT", 8, 0)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    btn.Update = function()
        local c = getColor()
        btn:SetBackdropColor(c.r or 1, c.g or 1, c.b or 1, c.a or 1)
        btn:SetBackdropBorderColor(0, 0, 0, 1)
    end

    local defaultSwatch = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    defaultSwatch:SetSize(24, 14)
    defaultSwatch:SetPoint("LEFT", btn, "RIGHT", 12, 0)   

    defaultSwatch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    do
        local def = getDefault()
        defaultSwatch:SetBackdropColor(def.r or 1, def.g or 1, def.b or 1, def.a or 1)
        defaultSwatch:SetBackdropBorderColor(1, 1, 1, 1)
    end

    defaultSwatch:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            local def = getDefault()
            setColor(def.r, def.g, def.b, def.a, false)
            btn:Update()

            local owner = getOwnerCfg and getOwnerCfg()
            if owner and owner.__preview then
                owner.__preview[previewKey] = nil
            end

            if applyNow then
                applyNow()
            else
                if PT.ConcentrationUI and PT.ConcentrationUI.ApplyCustomization then
                    PT.ConcentrationUI:ApplyCustomization()
                end
                if PT.UI and PT.UI.ApplyCustomization then
                    PT.UI:ApplyCustomization()
                end
            end
        end
    end)

    defaultSwatch:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Customization_ResetDefault"] or "Reset to default")
        GameTooltip:Show()
    end)

    defaultSwatch:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(1, 1, 1, 1)
        GameTooltip:Hide()
    end)

    btn:SetScript("OnClick", function()
        local cur = getColor()
        local def = getDefault()
        local originalColor = CopyColor(cur)

        OpenColorPicker(
            cur,
            def,

            function(r, g, b, a)
                setColor(r, g, b, a, true)
                btn:Update()
                if PT.ConcentrationUI and PT.ConcentrationUI.ApplyCustomization then
                    PT.ConcentrationUI:ApplyCustomization()
                end
				if PT.UI and PT.UI.ApplyCustomization then
					PT.UI:ApplyCustomization()
				end
            end,

            function(r, g, b, a)
                setColor(r, g, b, a, false)
                btn:Update()
                if PT.ConcentrationUI and PT.ConcentrationUI.ApplyCustomization then
                    PT.ConcentrationUI:ApplyCustomization()
                end
				if PT.UI and PT.UI.ApplyCustomization then
					PT.UI:ApplyCustomization()
				end
            end,

            function()
                setColor(originalColor.r, originalColor.g, originalColor.b, originalColor.a, false)

                local owner = getOwnerCfg and getOwnerCfg()
                if owner and owner.__preview then
                    owner.__preview[previewKey] = nil
                end

                btn:Update()

                if applyNow then
                    applyNow()
                else
                    if PT.ConcentrationUI and PT.ConcentrationUI.ApplyCustomization then
                        PT.ConcentrationUI:ApplyCustomization()
                    end
                    if PT.UI and PT.UI.ApplyCustomization then
                        PT.UI:ApplyCustomization()
                    end
                end
            end
        )
    end)

    btn:Update()
    btn.label = label
    return btn
end

local function PreviewOrSaved(cfg, key)
    return (cfg.__preview and cfg.__preview[key]) or cfg[key]
end

PT.Customization = PT.Customization or {}
PT.Customization.CreateColorButton  = CreateColorButton
PT.Customization.OpenColorPicker    = OpenColorPicker
PT.Customization.PreviewOrSaved     = PreviewOrSaved
PT.Customization.EnsurePreviewTable = EnsurePreviewTable
PT.Customization.EnsureCustomization = EnsureCustomization
PT.Customization.DEFAULTS           = DEFAULTS
PT.Customization._refreshers        = PT.Customization._refreshers or {}

function PT.Customization:OnRefresh(fn)
    if type(fn) == "function" then
        table.insert(self._refreshers, fn)
    end
end

local function MakePreviewSetter(key, commitSetter)
    return function(r, g, b, a, preview)
        local cfg = GetConcCfg()
        if preview then
            local p = EnsurePreviewTable(cfg)
            p[key] = { r=r, g=g, b=b, a=a }
        else
            commitSetter(cfg, { r=r, g=g, b=b, a=a })
            if cfg.__preview then
                cfg.__preview[key] = nil
            end
        end
    end
end

local f = CreateFrame("Frame", "HironCraftProfitSettingsCustomization", UIParent)
f:SetSize(520, 760)

local title = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontHighlightLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText(L["Customization_Title"] or "Customization")

local concTitle = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontHighlight")
concTitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
concTitle:SetText(L["Customization_Concentration"] or "Concentration")

local colorButtons = {}

local colorsFrame = CreateFrame("Frame", nil, f)
colorsFrame:SetPoint("TOPLEFT", concTitle, "BOTTOMLEFT", 0, -28)
colorsFrame:SetSize(120, 180)

local COL_W = 170
local ROW_H = 24
local START_X = 0
local START_Y = 0

local function Place(i)
    local idx = i - 1
    local col = idx % 3
    local row = math.floor(idx / 3)
    local x = START_X + col * COL_W
    local y = START_Y - row * ROW_H
    return x, y
end

do
    local x, y = Place(1)
    local btn = CreateColorButton(
        colorsFrame, x, y,
        L["Customization_BarColor"] or "Bar color",
        "barColor",
        function()
            local cfg = GetConcCfg()
            return PreviewOrSaved(cfg, "barColor")
        end,
        function()
            return DEFAULTS.concentration.barColor
        end,
        MakePreviewSetter("barColor", function(cfg, color) cfg.barColor = color end)
    )
    table.insert(colorButtons, btn)
end

do
    local x, y = Place(2)
    local btn = CreateColorButton(
        colorsFrame, x, y,
        L["Customization_TimerColor"] or "Timer text color",
        "timerTextColor",
        function()
            local cfg = GetConcCfg()
            return PreviewOrSaved(cfg, "timerTextColor")
        end,
        function()
            return DEFAULTS.concentration.timerTextColor
        end,
        MakePreviewSetter("timerTextColor", function(cfg, color) cfg.timerTextColor = color end)
    )
    table.insert(colorButtons, btn)
end

do
    local x, y = Place(3)
    local btn = CreateColorButton(
        colorsFrame, x, y,
        L["Customization_DividerColor"] or "Divider color",
        "dividerColor",
        function()
            local cfg = GetConcCfg()
            return PreviewOrSaved(cfg, "dividerColor")
        end,
        function()
            return DEFAULTS.concentration.dividerColor
        end,
        MakePreviewSetter("dividerColor", function(cfg, color) cfg.dividerColor = color end)
    )
    table.insert(colorButtons, btn)
end

do
    local x, y = Place(4)
    local btn = CreateColorButton(
        colorsFrame, x, y,
        L["Customization_BorderColor"] or "Bar border color",
        "borderColor",
        function()
            local cfg = GetConcCfg()
            return (cfg.__preview and cfg.__preview.borderColor)
                or (cfg.border and cfg.border.color)
                or DEFAULTS.concentration.border.color
        end,
        function()
            return DEFAULTS.concentration.border.color
        end,
        function(r, g, b, a, preview)
            local cfg = GetConcCfg()
            cfg.border = cfg.border or { enabled = true, color = CopyColor(DEFAULTS.concentration.border.color) }

            if preview then
                local p = EnsurePreviewTable(cfg)
                p.borderColor = { r=r, g=g, b=b, a=a }
            else
                cfg.border.color = { r=r, g=g, b=b, a=a }
                if cfg.__preview then
                    cfg.__preview.borderColor = nil
                end
            end
        end
    )
    table.insert(colorButtons, btn)
end

do
    local x, y = Place(5)
    local btn = CreateColorButton(
        colorsFrame, x, y,
        L["Customization_IconBorderColor"] or "Icon border color",
        "iconBorderColor",
        function()
            local cfg = GetConcCfg()
            return (cfg.__preview and cfg.__preview.iconBorderColor)
                or (cfg.iconBorder and cfg.iconBorder.color)
                or DEFAULTS.concentration.iconBorder.color
        end,
        function()
            return DEFAULTS.concentration.iconBorder.color
        end,
        function(r, g, b, a, preview)
            local cfg = GetConcCfg()
            cfg.iconBorder = cfg.iconBorder or { enabled = true, color = CopyColor(DEFAULTS.concentration.iconBorder.color) }

            if preview then
                local p = EnsurePreviewTable(cfg)
                p.iconBorderColor = { r=r, g=g, b=b, a=a }
            else
                cfg.iconBorder.color = { r=r, g=g, b=b, a=a }
                if cfg.__preview then
                    cfg.__preview.iconBorderColor = nil
                end
            end
        end
    )
    table.insert(colorButtons, btn)
end

do
    local x, y = Place(6)
    local btn = CreateColorButton(
        colorsFrame, x, y,
        L["Customization_BackgroundColor"] or "Background color",
        "backgroundColor",
        function()
            local cfg = GetConcCfg()
            return PreviewOrSaved(cfg, "backgroundColor")
        end,
        function()
            return DEFAULTS.concentration.backgroundColor
        end,
        MakePreviewSetter(
            "backgroundColor",
            function(cfg, color)
                cfg.backgroundColor = color
            end
        )
    )
    table.insert(colorButtons, btn)
end

local fontLabel = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontNormal")
fontLabel:SetPoint("TOPLEFT", concTitle, "BOTTOMLEFT", 0, -100)
fontLabel:SetText(L["Customization_TimerFontSize"] or "Timer font size")

local fontDropdown = CreateFrame("Frame", "HironCraftProfit_TimerFontDropdown", f, "UIDropDownMenuTemplate")
fontDropdown:SetPoint("LEFT", fontLabel, "RIGHT", -10, -2)
fontDropdown:Hide()

UIDropDownMenu_SetWidth(fontDropdown, 180)

UIDropDownMenu_Initialize(fontDropdown, function(self, level)
    local cfg = GetConcCfg()

    for _, fnt in ipairs(TIMER_FONTS) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = fnt.name
		info.value = fnt.path
        info.checked = (cfg.timerFont == fnt.path)
        info.func = function()
            cfg.timerFont = fnt.path
            UIDropDownMenu_SetText(fontDropdown, fnt.name)

            if PT.ConcentrationUI and PT.ConcentrationUI.ApplyCustomization then
                PT.ConcentrationUI:ApplyCustomization()
            end
			if PT.UI and PT.UI.ApplyCustomization then
				PT.UI:ApplyCustomization()
			end
        end
        UIDropDownMenu_AddButton(info, level)
    end
end)

local fontSizeSlider = CreateFrame("Slider", "HironCraftProfit_TimerFontSizeSlider", f, "OptionsSliderTemplate")
fontSizeSlider:SetPoint("LEFT", fontLabel, "RIGHT", 14, 0)
fontSizeSlider:SetWidth(120)
fontSizeSlider:SetMinMaxValues(8, 50)
fontSizeSlider:SetValueStep(1)
fontSizeSlider:SetObeyStepOnDrag(true)

_G[fontSizeSlider:GetName().."Low"]:SetText("8")
_G[fontSizeSlider:GetName().."High"]:SetText("50")
_G[fontSizeSlider:GetName().."Text"]:SetText("")

local fontSizeValue = fontSizeSlider:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontNormalSmall")
fontSizeValue:SetPoint("LEFT", fontSizeSlider, "RIGHT", 6, 0)

fontSizeSlider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value + 0.5)
    fontSizeValue:SetText(value .. " pt")

    local cfg = GetConcCfg()
    cfg.timerFontSize = value

    if PT.ConcentrationUI and PT.ConcentrationUI.ApplyCustomization then
        PT.ConcentrationUI:ApplyCustomization()
    end
	if PT.UI and PT.UI.ApplyCustomization then
		PT.UI:ApplyCustomization()
	end
end)

local profTitle = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontHighlight")
profTitle:SetPoint("TOPLEFT", concTitle, "BOTTOMLEFT", 0, -200)
profTitle:SetText(L["Customization_ProfessionsWindow"] or "Professions window")

local profColorButtons = {}

local profColorsFrame = CreateFrame("Frame", nil, f)
profColorsFrame:SetPoint("TOPLEFT", profTitle, "BOTTOMLEFT", 0, -16)
profColorsFrame:SetSize(520, 120)

local PROF_COL_W = 170
local PROF_ROW_H = 24

local function ProfPlace(i)
    local idx = i - 1
    local col = idx % 3
    local row = math.floor(idx / 3)
    return col * PROF_COL_W, -row * PROF_ROW_H
end

do
    local x, y = ProfPlace(1)
    local btn = CreateColorButton(
        profColorsFrame, x, y,
        L["Customization_Prof_Background"] or "Background",
        "prof_backgroundColor",
        function()
            return PreviewOrSaved(EnsureCustomization().professionsWindow, "backgroundColor")
        end,
        function()
            return DEFAULTS.professionsWindow.backgroundColor
        end,
        function(r, g, b, a, preview)
            local cfg = EnsureCustomization().professionsWindow
            if preview then
                EnsurePreviewTable(cfg).backgroundColor = { r=r, g=g, b=b, a=a }
            else
                cfg.backgroundColor = { r=r, g=g, b=b, a=a }
                if cfg.__preview then cfg.__preview.backgroundColor = nil end
            end
        end
    )
    table.insert(profColorButtons, btn)
end

do
    local x, y = ProfPlace(2)
    local btn = CreateColorButton(
        profColorsFrame, x, y,
        L["Customization_Prof_Border"] or "Window border",
        "prof_borderColor",
        function()
            return PreviewOrSaved(EnsureCustomization().professionsWindow, "borderColor")
        end,
        function()
            return DEFAULTS.professionsWindow.borderColor
        end,
        function(r, g, b, a, preview)
            local cfg = EnsureCustomization().professionsWindow
            if preview then
                EnsurePreviewTable(cfg).borderColor = { r=r, g=g, b=b, a=a }
            else
                cfg.borderColor = { r=r, g=g, b=b, a=a }
                if cfg.__preview then cfg.__preview.borderColor = nil end
            end
        end
    )
    table.insert(profColorButtons, btn)
end

do
    local x, y = ProfPlace(5)
    local btn = CreateColorButton(
        profColorsFrame, x, y,
        L["Customization_Prof_Header"] or "Profession header",
        "prof_headerColor",
        function()
            return PreviewOrSaved(EnsureCustomization().professionsWindow, "headerColor")
        end,
        function()
            return DEFAULTS.professionsWindow.headerColor
        end,
        function(r, g, b, a, preview)
            local cfg = EnsureCustomization().professionsWindow
            if preview then
                EnsurePreviewTable(cfg).headerColor = { r=r, g=g, b=b, a=a }
            else
                cfg.headerColor = { r=r, g=g, b=b, a=a }
                if cfg.__preview then cfg.__preview.headerColor = nil end
            end
        end
    )
    table.insert(profColorButtons, btn)
end

do
    local x, y = ProfPlace(4)
    local btn = CreateColorButton(
        profColorsFrame, x, y,
        L["Customization_Prof_FontColor"] or "Text color",
        "prof_fontColor",
        function()
            return PreviewOrSaved(EnsureCustomization().professionsWindow, "fontColor")
        end,
        function()
            return DEFAULTS.professionsWindow.fontColor
        end,
        function(r, g, b, a, preview)
            local cfg = EnsureCustomization().professionsWindow
            if preview then
                EnsurePreviewTable(cfg).fontColor = { r=r, g=g, b=b, a=a }
            else
                cfg.fontColor = { r=r, g=g, b=b, a=a }
                if cfg.__preview then cfg.__preview.fontColor = nil end
            end
        end
    )
    table.insert(profColorButtons, btn)
end
local profFontLabel = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontNormal")
profFontLabel:SetPoint("TOPLEFT", profTitle, "BOTTOMLEFT", 0, -90)
profFontLabel:SetText(L["Customization_ProfFontSize"] or "Font size")

local profFontDropdown = CreateFrame(
    "Frame",
    "HironCraftProfit_ProfFontDropdown",
    f,
    "UIDropDownMenuTemplate"
)
profFontDropdown:SetPoint("LEFT", profFontLabel, "RIGHT", -10, -2)
profFontDropdown:Hide()
UIDropDownMenu_SetWidth(profFontDropdown, 180)

UIDropDownMenu_Initialize(profFontDropdown, function(self, level)
    local cfg = GetProfCfg()

    for _, fnt in ipairs(TIMER_FONTS) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = fnt.name
		info.value = fnt.path
        info.checked = (cfg.font == fnt.path)
        info.func = function()
            cfg.font = fnt.path
            UIDropDownMenu_SetText(profFontDropdown, fnt.name)

            if PT.UI and PT.UI.ApplyCustomization then
                PT.UI:ApplyCustomization()
            end
        end
        UIDropDownMenu_AddButton(info, level)
    end
end)

local profFontSizeSlider = CreateFrame(
    "Slider",
    "HironCraftProfit_ProfFontSizeSlider",
    f,
    "OptionsSliderTemplate"
)
profFontSizeSlider:SetPoint("LEFT", profFontLabel, "RIGHT", 14, 0)
profFontSizeSlider:SetWidth(120)
profFontSizeSlider:SetMinMaxValues(5, 20)
profFontSizeSlider:SetValueStep(1)
profFontSizeSlider:SetObeyStepOnDrag(true)

_G[profFontSizeSlider:GetName().."Low"]:SetText("5")
_G[profFontSizeSlider:GetName().."High"]:SetText("20")
_G[profFontSizeSlider:GetName().."Text"]:SetText("")

local profFontSizeValue = profFontSizeSlider:CreateFontString(
    nil, "OVERLAY", "HironCraftProfit_GameFontNormalSmall"
)
profFontSizeValue:SetPoint("LEFT", profFontSizeSlider, "RIGHT", 6, 0)

profFontSizeSlider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value + 0.5)
    profFontSizeValue:SetText(value .. " pt")

    local cfg = GetProfCfg()
    cfg.fontSize = value

    if PT.UI and PT.UI.ApplyCustomization then
        PT.UI:ApplyCustomization()
    end
end)

PT.Customization.panel = f
PT.Customization.anchorBelow = profTitle

local localizedLabels = {
    { title,         "Customization_Title",             "Customization" },
    { concTitle,     "Customization_Concentration",     "Concentration" },
    { fontLabel,     "Customization_TimerFontSize",     "Timer font size" },
    { profTitle,     "Customization_ProfessionsWindow", "Professions window" },
    { profFontLabel, "Customization_ProfFontSize",      "Font size" },
    { colorButtons[1] and colorButtons[1].label, "Customization_BarColor",        "Bar color" },
    { colorButtons[2] and colorButtons[2].label, "Customization_TimerColor",      "Timer text color" },
    { colorButtons[3] and colorButtons[3].label, "Customization_DividerColor",    "Divider color" },
    { colorButtons[4] and colorButtons[4].label, "Customization_BorderColor",     "Bar border color" },
    { colorButtons[5] and colorButtons[5].label, "Customization_IconBorderColor", "Icon border color" },
    { colorButtons[6] and colorButtons[6].label, "Customization_BackgroundColor", "Background color" },
    { profColorButtons[1] and profColorButtons[1].label, "Customization_Prof_Background", "Background" },
    { profColorButtons[2] and profColorButtons[2].label, "Customization_Prof_Border",     "Window border" },
    { profColorButtons[3] and profColorButtons[3].label, "Customization_Prof_Header",     "Profession header" },
    { profColorButtons[4] and profColorButtons[4].label, "Customization_Prof_FontColor",  "Text color" },
}

local function RelocalizeLabels()
    for _, e in ipairs(localizedLabels) do
        if e[1] then e[1]:SetText(L[e[2]] or e[3]) end
    end
end

local function RefreshUI()
    RelocalizeLabels()
    local cfg = EnsureCustomization()

    for _, b in ipairs(colorButtons) do
        if b.Update then b:Update() end
    end

    for _, b in ipairs(profColorButtons) do
        if b.Update then b:Update() end
    end

    for _, fn in ipairs(PT.Customization._refreshers) do
        pcall(fn)
    end

    do
        local cc = cfg.concentration
        if cc and cc.timerFont and fontDropdown then
            for _, fnt in ipairs(TIMER_FONTS) do
                if fnt.path == cc.timerFont then
                    UIDropDownMenu_SetText(fontDropdown, fnt.name)
                    UIDropDownMenu_SetSelectedValue(fontDropdown, fnt.path)
                    break
                end
            end
        end
    end

    do
        local pw = cfg.professionsWindow
        if pw and pw.font and profFontDropdown then
            for _, fnt in ipairs(TIMER_FONTS) do
                if fnt.path == pw.font then
                    UIDropDownMenu_SetText(profFontDropdown, fnt.name)
                    UIDropDownMenu_SetSelectedValue(profFontDropdown, fnt.path)
                    break
                end
            end
        end
    end
end

local function TryRegister()
    if not (PT.Settings and PT.Settings.category) then return end

    local sub = Settings.RegisterCanvasLayoutSubcategory(
        PT.Settings.category,
        f,
        L["Customization"] or "Customization"
    )

    if sub and sub.SetOnRefresh then
        sub:SetOnRefresh(RefreshUI)
    else
        sub.OnRefresh = RefreshUI
    end

    RefreshUI()
end

C_Timer.After(0, TryRegister)

do
    local cfg = EnsureCustomization().concentration
    local name = cfg.timerFont

    for _, fnt in ipairs(TIMER_FONTS) do
        if fnt.path == name then
            UIDropDownMenu_SetText(fontDropdown, fnt.name)
            break
        end
    end
end
do
    local cfg = EnsureCustomization().concentration
    local size = cfg.timerFontSize or DEFAULTS.concentration.timerFontSize

    fontSizeSlider:SetValue(size)
    fontSizeValue:SetText(size .. " pt")
end
do
    local cfg = EnsureCustomization().professionsWindow
    local name = cfg.font

    for _, fnt in ipairs(TIMER_FONTS) do
        if fnt.path == name then
            UIDropDownMenu_SetText(profFontDropdown, fnt.name)
            break
        end
    end
end

do
    local cfg = EnsureCustomization().professionsWindow
    local size = cfg.fontSize or DEFAULTS.professionsWindow.fontSize

    profFontSizeSlider:SetValue(size)
    profFontSizeValue:SetText(size .. " pt")
end
