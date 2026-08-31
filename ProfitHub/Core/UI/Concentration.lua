local PT = HironCraftProfit
PT.config = PT.config or {}

PT.ConcentrationUI = {}
local UI = PT.ConcentrationUI

HironCraftProfit_CharConfig = HironCraftProfit_CharConfig or {}
HironCraftProfit_CharConfig.concActiveDB = HironCraftProfit_CharConfig.concActiveDB or "MID"
HironCraftProfit_CharConfig.concRotation = HironCraftProfit_CharConfig.concRotation or { "MID", "TWW", "DF" }

if not HironCraftProfit_CharConfig.concActiveDB then
    HironCraftProfit_CharConfig.concActiveDB = HironCraftProfit_CharConfig.activeDB or "MID"
end

local function GetMode()
    return HironCraftProfit_CharConfig.concActiveDB or "MID"
end

local function GetConcCustomization()
    local c = PT.config and PT.config.customization
    return c and c.concentration
end

local function IsCompact()
    return HironCraftProfit_Config and HironCraftProfit_Config.concentrationCompact == true
end

local L = PT.L
local Tooltip = PT.Tooltip

local FONT          = HironCraftProfit.FONT
local DEFAULT_SCALE = HironCraftProfit.SCALE_DEFAULT
local SCALE_STEP    = HironCraftProfit.SCALE_STEP
local SCALE_MIN     = HironCraftProfit.SCALE_MIN
local SCALE_MAX     = HironCraftProfit.SCALE_MAX
local MAX_CONCENTRATION = 1000
local TIME_TO_MAX = 6000
local FILL_RATE = MAX_CONCENTRATION / TIME_TO_MAX

local NUM_SEGMENTS = 5
local SEGMENT_VALUE = MAX_CONCENTRATION / NUM_SEGMENTS
local DFConcentrationCurrencyId = {
    [755] = 3047, -- ювелирное дело
    [197] = 3048, -- портняжное дело
    [165] = 3049, -- кожевничество
    [164] = 3050, -- кузнечное дело
    [333] = 3051, -- наложение чар
    [202] = 3052, -- инженерное дело
    [773] = 3053, -- начертание
    [171] = 3054, -- алхимия
}
local TWWConcentrationCurrencyId = {
	[755] = 3013, --ювелирное
    [164] = 3040, --кузнечное дело
	[197] = 3041, --портняжное дело
	[165] = 3042, --кожевничество
	[773] = 3043, --начертание
	[202] = 3044, --инженерное дело
    [171] = 3045, --алхимия
    [333] = 3046, --наложение чар
}
local MIDConcentrationCurrencyId = {
    [171] = 3161, -- алхимия
    [164] = 3162, -- кузнечное
    [333] = 3163, -- наложение чар
    [202] = 3164, -- инженерное
    [773] = 3165, -- начертание
    [755] = 3166, -- ювелирное
    [165] = 3167, -- кожевничество
    [197] = 3168, -- портняжное
}
local function FormatTime(minutes)
    if minutes < 60 then
        return string.format(L["TIME_MIN"], minutes)
    elseif minutes < 1440 then
        return string.format(
            L["TIME_HOUR"],
            math.floor(minutes / 60),
            minutes % 60
        )
    else
        return string.format(
            L["TIME_DAY"],
            math.floor(minutes / 1440),
            math.floor((minutes % 1440) / 60)
        )
    end
end

local lastOpenedSkillLine = nil

local function OpenProfessions(profData)
    if not profData or not profData.skillLine then
        return
    end

    if ProfessionsFrame
       and ProfessionsFrame:IsShown()
       and lastOpenedSkillLine == profData.skillLine
    then
        HideUIPanel(ProfessionsFrame)
        lastOpenedSkillLine = nil
        return
    end

    if ProfessionsFrame then
        ShowUIPanel(ProfessionsFrame)
    end

    if C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill then
        C_TradeSkillUI.OpenTradeSkill(profData.skillLine)
        lastOpenedSkillLine = profData.skillLine
    end
end

local function SavePosition(frame)
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB.positions = HironCraftProfit_DB.positions or {}

    local point, _, relPoint, x, y = frame:GetPoint()
    HironCraftProfit_DB.positions.concentration = {
        point = point,
        relPoint = relPoint,
        x = x,
        y = y,
    }
end

local function LoadPosition(frame)
    frame:ClearAllPoints()

    if HironCraftProfit_DB
       and HironCraftProfit_DB.positions
       and HironCraftProfit_DB.positions.concentration
    then
        local p = HironCraftProfit_DB.positions.concentration
        frame:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    end
end

function UI:ResetPosition()
    if not self.frame then return end

    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB.positions = HironCraftProfit_DB.positions or {}

    HironCraftProfit_DB.positions.concentration = nil

    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
end

local function CreateIconBorder(icon)
    local parent = icon:GetParent()

    local holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    holder:SetFrameLevel(parent:GetFrameLevel() + 10)

    holder:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2)
    holder:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)

    holder:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })

    holder:SetBackdropBorderColor(0, 0, 0, 1)
	icon.border = holder
end

local function CreateBarBorder(bar)
    local f = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    f:SetFrameLevel(bar:GetFrameLevel() + 5)

    f:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 2)
    f:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2)

    f:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })

    f:SetBackdropBorderColor(0, 0, 0, 1)
	bar.border = f
end

function UI:ApplyCustomization()
    if not self.frame then return end

    local cfg = GetConcCustomization()
    if not cfg then return end

    if cfg.barAlpha then
        self.frame:SetAlpha(cfg.barAlpha)
    end

    for _, bar in ipairs(self.frame.bars or {}) do

        local profData = bar.iconHolder and bar.iconHolder.profData

        local hasConcentration = (bar.hasConcentration ~= false)

        if not hasConcentration then
            bar:SetValue(0)

            if bar.bg then bar.bg:Hide() end
            if bar.border then bar.border:Hide() end

            if bar.timers then
                for _, fs in ipairs(bar.timers) do
                    fs:SetText("")
                    fs:Hide()
                end
            end

            if bar.dividers then
                for _, d in ipairs(bar.dividers) do
                    d:Hide()
                end
            end
        end

        if bar.iconHolder and bar.iconHolder.border then
            local icfg = cfg.iconBorder
            local iconBorderColor = (cfg.__preview and cfg.__preview.iconBorderColor) or (icfg and icfg.color)

            if icfg and icfg.enabled == false then
                bar.iconHolder.border:Hide()
            else
                bar.iconHolder.border:Show()
                if iconBorderColor then
                    bar.iconHolder.border:SetBackdropBorderColor(
                        iconBorderColor.r or 1,
                        iconBorderColor.g or 1,
                        iconBorderColor.b or 1,
                        iconBorderColor.a or 1
                    )
                end
            end
        end

        if not hasConcentration then
        else
            if cfg.barTexture and bar.SetStatusBarTexture then
                bar:SetStatusBarTexture(cfg.barTexture)
            end

			if bar.bg then
				local bgc =
					(cfg.__preview and cfg.__preview.backgroundColor)
					or cfg.backgroundColor

				if bgc and (bgc.a or 0) > 0 then
					bar.bg:SetColorTexture(
						bgc.r or 0,
						bgc.g or 0,
						bgc.b or 0,
						bgc.a or 0
					)
					bar.bg:Show()
				else
					bar.bg:Hide()
				end
			end

            local barColor = (cfg.__preview and cfg.__preview.barColor) or cfg.barColor
            if barColor and bar.GetStatusBarTexture then
                local t = bar:GetStatusBarTexture()
                if t then
                    t:SetVertexColor(
                        barColor.r or 1,
                        barColor.g or 1,
                        barColor.b or 1,
                        barColor.a or 1
                    )
                end
            end

			local timerColor = (cfg.__preview and cfg.__preview.timerTextColor) or cfg.timerTextColor
			local timerFont     = FONT
			local timerFontSize = cfg.timerFontSize

			if bar.timers then
				for _, fs in ipairs(bar.timers) do
					if timerFont then
						local _, _, flags = fs:GetFont()
						fs:SetFont(
							timerFont,
							timerFontSize or 11,
							flags
						)
					end

					if timerColor then
						fs:SetTextColor(
							timerColor.r or 1,
							timerColor.g or 1,
							timerColor.b or 1,
							timerColor.a or 1
						)
					end
				end
			end

			if bar.iconText and timerFont then
				local _, _, flags = bar.iconText:GetFont()
				bar.iconText:SetFont(
					timerFont,
					timerFontSize or 12,
					flags
				)
			end

            local divColor = (cfg.__preview and cfg.__preview.dividerColor) or cfg.dividerColor
            if divColor and bar.dividers then
                for _, fs in ipairs(bar.dividers) do
                    fs:SetTextColor(
                        divColor.r or 1,
                        divColor.g or 1,
                        divColor.b or 1,
                        divColor.a or 1
                    )
                end
            end

            if bar.border then
                local bcfg = cfg.border
                local borderColor = (cfg.__preview and cfg.__preview.borderColor) or (bcfg and bcfg.color)

                if bcfg and bcfg.enabled == false then
                    bar.border:Hide()
                else
                    bar.border:Show()
                    if borderColor then
                        bar.border:SetBackdropBorderColor(
                            borderColor.r or 1,
                            borderColor.g or 1,
                            borderColor.b or 1,
                            borderColor.a or 1
                        )
                    end
                end
            end
        end 
    end 
end 

function UI:ApplyCompactMode()
    if not self.frame then return end

    local compact = IsCompact()

    if compact then
        self.frame:RegisterForDrag()
    else
        self.frame:RegisterForDrag("LeftButton")
    end

    for _, bar in ipairs(self.frame.bars or {}) do
        local t = bar.GetStatusBarTexture and bar:GetStatusBarTexture()

        if compact then
            if t then t:SetAlpha(0) end
            if bar.bg then bar.bg:Hide() end
            if bar.border then bar.border:Hide() end

            if bar.timers then
                for _, fs in ipairs(bar.timers) do fs:Hide() end
            end
            if bar.dividers then
                for _, d in ipairs(bar.dividers) do d:Hide() end
            end

            bar:EnableMouse(false)
            bar:RegisterForDrag()
        else
            if t then t:SetAlpha(1) end

            bar:EnableMouse(true)
            bar:RegisterForDrag("LeftButton")
        end
    end
end

local function CreateCompactToggleButton(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(15, 15)
    b:SetFrameLevel(parent:GetFrameLevel() + 20)
    b:RegisterForClicks("LeftButtonUp")

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()

    function b:Update()
        if IsCompact() then
            b.icon:SetAtlas("uitools-icon-external-window")
        else
            b.icon:SetAtlas("uitools-icon-collapse-window")
        end
    end

    function b:UpdateTooltip()
        Tooltip:Clear()
        Tooltip:AddLine(L["CONC_COMPACT_TITLE"] or "Compact mode", 14, 1, 1, 1)
        Tooltip:AddLine(" ")
        if IsCompact() then
            Tooltip:AddLine(L["CONC_COMPACT_ON"] or "On", 12, 1, 0.82, 0)
        else
            Tooltip:AddLine(L["CONC_COMPACT_OFF"] or "Off", 12, 1, 0.82, 0)
        end
        Tooltip:AddLine(" ")
        Tooltip:AddLine(L["CONC_COMPACT_HINT"] or "Click — toggle", 11, 0.6, 0.6, 0.6)
        Tooltip:ShowAtCursor()
    end

    b:SetScript("OnClick", function(self)
        UI:ToggleCompact()
        b:Update()
        if b:IsMouseOver() then b:UpdateTooltip() end
    end)

    b:SetScript("OnEnter", function() b:UpdateTooltip() end)
    b:SetScript("OnLeave", function() Tooltip:Clear() end)

    b:Update()
    return b
end

local function CreateModeToggleButton(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(15, 15)
    b:SetFrameLevel(parent:GetFrameLevel() + 20)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
function b:UpdateTooltip()
    Tooltip:Clear()

    Tooltip:AddLine(L["CONCENTRATION_MODE"], 14, 1, 1, 1)
    Tooltip:AddLine(" ")

    local labels = PT.DB_LABELS or { DF = "Dragonflight", TWW = "The War Within", MID = "Midnight" }
    Tooltip:AddLine(labels[GetMode()] or GetMode(), 12, 1, 0.82, 0)

    local rot = PT.GetDBRotation and PT.GetDBRotation("concRotation") or { "DF", "TWW", "MID" }
    if #rot > 1 then
        Tooltip:AddLine(" ")
        Tooltip:AddLine(L["DB_Rotation_LMB"]:format(table.concat(rot, " > ")), 11, 0.6, 0.6, 0.6)
    end
    Tooltip:AddLine(L["DB_Rotation_RMB"], 11, 0.6, 0.6, 0.6)

    Tooltip:AddLine(" ")
    Tooltip:AddLine(L["UI_SCALE_ALT_WHEEL"] or "Alt + Mouse Wheel — change scale", 11, 0.6, 0.6, 0.6)
    Tooltip:AddLine(L["UI_SCALE_ALT_MMB"] or "Alt + Middle Mouse Button — reset scale", 11, 0.6, 0.6, 0.6)

    Tooltip:ShowAtCursor()
end

function b:Update()
    b.icon:SetAtlas(PT.DB_SELECTOR_ATLAS)
    local c = (PT.DB_COLORS and PT.DB_COLORS[GetMode()]) or { 1, 1, 1 }
    b.icon:SetVertexColor(c[1], c[2], c[3])
end

b:SetScript("OnClick", function(self, mouseButton)
    if mouseButton == "RightButton" then
        if PT.ShowDBRotationMenu then
            PT.ShowDBRotationMenu(self, "concRotation", "concActiveDB", function()
                b:Update()
                if UI.frame and UI.frame.compactToggle then
                    UI.frame.compactToggle:Update()
                end
                if b:IsMouseOver() then b:UpdateTooltip() end
            end)
        end
        return
    end

    UI:ToggleConcentrationMode()
    b:Update()

    if b:IsMouseOver() then
        b:UpdateTooltip()
    end
end)

b:SetScript("OnEnter", function()
	b:UpdateTooltip()
end)

b:SetScript("OnLeave", function()
    Tooltip:Clear()
end)

    b:Update()
    return b
end

local function CreateBar(parent, index)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(230, 30)
    bar:SetFrameLevel(parent:GetFrameLevel() + 1)

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(0, 0, 0, 0)

bar:SetMinMaxValues(0, MAX_CONCENTRATION)
bar:SetValue(0)

bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
bar:GetStatusBarTexture():SetVertexColor(64/255, 186/255, 255/255, 1)

bar.iconHolder = CreateFrame("Frame", nil, bar, "BackdropTemplate")
bar.iconHolder:SetSize(30, 30)
bar.iconHolder:SetPoint("LEFT", bar, "LEFT", -32, 0)

local BAR_BORDER_SIZE = 2
local borderSize = BAR_BORDER_SIZE

local cfg = GetConcCustomization()
if cfg and cfg.border and cfg.border.enabled == false then
    borderSize = 0
end

bar.iconHolder:SetPoint("LEFT", bar, "LEFT", -(32 + borderSize), 0)
bar.iconHolder:SetFrameLevel(bar:GetFrameLevel() + 5)

bar.icon = bar.iconHolder:CreateTexture(nil, "ARTWORK", nil, 5)
bar.icon:SetPoint("CENTER")
bar.icon:SetSize(32, 32)
bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

CreateIconBorder(bar.iconHolder)

    bar.iconHolder:SetScript("OnEnter", function(self)
        if self.profData then
            Tooltip:Clear()

            Tooltip:AddLine(self.profData.name, 14, 1, 1, 1)

            Tooltip:AddLine(" ")

            Tooltip:AddLine(L["CLICK_TO_TOGGLE_PROFESSIONS"], 12, 1, 0.8, 0)

            Tooltip:ShowAtCursor()
        end
    end)

    bar.iconHolder:SetScript("OnLeave", function()
        Tooltip:Clear()
    end)

bar.iconHolder:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
        self._dragged = false
        bar.icon:SetPoint("CENTER", 1, -1)
    end
end)

    bar.iconHolder:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            bar.icon:SetPoint("CENTER", 0, 0)

            if not self._dragged and self.profData then
                OpenProfessions(self.profData)
            end
        end
    end)
	
    bar.iconText = bar.iconHolder:CreateFontString(nil, "OVERLAY", nil, 7)
    bar.iconText:SetFont(FONT, 13, "OUTLINE")
    bar.iconText:SetTextColor(1, 1, 1)
    bar.iconText:SetPoint("CENTER")

    bar.timers = {}
    local segmentWidth = bar:GetWidth() / NUM_SEGMENTS

    for s = 1, NUM_SEGMENTS do
        local fs = bar:CreateFontString(nil, "OVERLAY", nil, 8)
        fs:SetFont(FONT, 11)
        fs:SetTextColor(1, 1, 1)
		fs:SetShadowOffset(1, -1)
        fs:SetPoint("CENTER", bar, "LEFT", (s - 0.5) * segmentWidth, 0)
        bar.timers[s] = fs
    end
	
bar.dividers = {}

local barWidth = bar:GetWidth()

for s = 1, NUM_SEGMENTS - 1 do
    local fs = bar:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, 35)
    fs:SetText("|")
    fs:SetTextColor(1,1,1,1)

    local x = (barWidth / NUM_SEGMENTS) * s
    fs:SetPoint("CENTER", bar, "LEFT", x, -1)

    bar.dividers[s] = fs
end

    CreateBarBorder(bar)

    if index == 1 then
        bar:SetPoint("TOP", parent, "TOP", 0, -10)
    else
        bar:SetPoint("TOP", parent.bars[1], "BOTTOM", 0, -1)
    end

    return bar
end

local function IsWindowLocked()
    return (InCombatLockdown and InCombatLockdown())
        or (PT.config and PT.config.lockWindows == true)
end

local function StartWindowMove(root)
    if not root or IsWindowLocked() then return end
    root:StartMoving()
end

local function StopWindowMove(root)
    if not root then return end

    root:StopMovingOrSizing()
    SavePosition(root)
end

local function MakeDraggable(child, root)
    if not child or not root or not child.RegisterForDrag then return end

    child:EnableMouse(true)
    child:RegisterForDrag("LeftButton")

    child:SetScript("OnDragStart", function()
        child._dragged = true
        StartWindowMove(root)
    end)

    child:SetScript("OnDragStop", function()
        StopWindowMove(root)
    end)
end

local function GetPlayerConcentrationProfessions()
    local list = {}
    local p1, p2 = GetProfessions()

local map = DFConcentrationCurrencyId

if GetMode() == "TWW" then
    map = TWWConcentrationCurrencyId
elseif GetMode() == "MID" then
    map = MIDConcentrationCurrencyId
end

    for _, slot in ipairs({ p1, p2 }) do
        if slot then
            local name, icon, _, _, _, _, skillLine = GetProfessionInfo(slot)
            local cid = map[skillLine]
            
                table.insert(list, {
                    name       = name,
                    icon       = icon,
                    skillLine  = skillLine,
                    currencyId = cid,
                })       
        end
    end

    return list
end


local function UpdateBars(self)
	if not C_CurrencyInfo
		or not C_CurrencyInfo.GetCurrencyInfo
		or not GetProfessions
	then
		return
	end

    local profs = GetPlayerConcentrationProfessions()
	if not profs then return end
    if self.modeToggle then
        self.modeToggle:SetShown(#profs > 0)
    end

if #profs == 0 then
    for i = 1, 2 do
        self.bars[i]:Hide()
    end
    return
end

    for i = 1, 2 do
        local bar = self.bars[i]
        local prof = profs[i]

        if not prof then
            bar:Hide()
        else
            bar.icon:SetTexture(prof.icon)
            bar.hasConcentration = (prof.currencyId ~= nil)
            bar.iconHolder.profData = prof

            if not prof.currencyId then
                bar.iconText:SetText("")
                bar:SetValue(0)

                bar.bg:Hide()

                for s = 1, NUM_SEGMENTS do
                    bar.timers[s]:SetText("")
                    bar.timers[s]:Hide()
                end

                if bar.dividers then
                    for _, d in ipairs(bar.dividers) do
                        d:Hide()
                    end
                end

                if bar.border then
                    bar.border:Hide()
                end

                bar:Show()
            else
                local info = C_CurrencyInfo.GetCurrencyInfo(prof.currencyId)
                local value = info.quantity or 0

                bar.iconText:SetText(value)
                bar:SetValue(value)

                if bar.border then
                    bar.border:Show()
                end

                for s = 1, NUM_SEGMENTS do
                    local required = s * SEGMENT_VALUE
                    if value >= required then
                        bar.timers[s]:SetText("")
                    else
                        local minutes = math.floor((required - value) / FILL_RATE)
                        bar.timers[s]:SetText(FormatTime(minutes))
                    end
                    bar.timers[s]:Show()
                end

                if bar.dividers then
                    for _, d in ipairs(bar.dividers) do
                        d:Show()
                    end
                end

                bar:Show()
            end
        end
    end

    if PT.ConcentrationUI and PT.ConcentrationUI.ApplyCustomization then
        PT.ConcentrationUI:ApplyCustomization()
    end
    if PT.ConcentrationUI and PT.ConcentrationUI.ApplyCompactMode then
        PT.ConcentrationUI:ApplyCompactMode()
    end
end

function UI:ToggleCompact()
    HironCraftProfit_Config = HironCraftProfit_Config or {}
    HironCraftProfit_Config.concentrationCompact = not HironCraftProfit_Config.concentrationCompact

    if self.frame then
        UpdateBars(self.frame)
    end
end

function UI:SetScale(delta)
    HironCraftProfit_Config = HironCraftProfit_Config or {}
    HironCraftProfit_Config.concentrationScale =
        HironCraftProfit_Config.concentrationScale or DEFAULT_SCALE

    local nextScale = HironCraftProfit_Config.concentrationScale + delta
    nextScale = math.max(SCALE_MIN, math.min(SCALE_MAX, nextScale))

    HironCraftProfit_Config.concentrationScale = nextScale

    if self.frame then
        self.frame:SetScale(nextScale)
    end
end

function UI:ResetScale()
    HironCraftProfit_Config = HironCraftProfit_Config or {}
    HironCraftProfit_Config.concentrationScale = DEFAULT_SCALE

    if self.frame then
        self.frame:SetScale(DEFAULT_SCALE)
    end
end

function UI:CreateFrame()
    if self.frame then return self.frame end

    local f = CreateFrame("Frame", "HironCraftProfitConcentrationFrame", UIParent)
    f:SetSize(300, 100)
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetClampRectInsets(0, -35, -20, 30)
	HironCraftProfit_Config = HironCraftProfit_Config or {}
	local scale = HironCraftProfit_Config.concentrationScale or DEFAULT_SCALE
	f:SetScale(scale)
    LoadPosition(f)
    f:SetMovable(true)
    f:EnableMouse(true)
	f:EnableMouseWheel(true)
    MakeDraggable(f, f)

	f:SetScript("OnMouseUp", function(self, button)
		if button == "MiddleButton" and IsAltKeyDown() then
			UI:ResetScale()
		end
	end)

	f:SetScript("OnMouseWheel", function(self, delta)
		if not IsAltKeyDown() then
			return
		end

		if delta > 0 then
			UI:SetScale(SCALE_STEP)
		else
			UI:SetScale(-SCALE_STEP)
		end
	end)

    f.bars = {}
    f.bars[1] = CreateBar(f, 1)
    f.bars[2] = CreateBar(f, 2)

	f.modeToggle = CreateModeToggleButton(f)
	for _, bar in ipairs(f.bars) do
		MakeDraggable(bar, f)
		MakeDraggable(bar.iconHolder, f)
	end

	f.modeToggle:SetPoint("BOTTOMLEFT", f.bars[1].iconHolder, "TOPLEFT", 0, 4)

	f.modeToggle:Update()

	f.compactToggle = CreateCompactToggleButton(f)
	f.compactToggle:SetPoint("LEFT", f.modeToggle, "RIGHT", 4, 0)
	f.compactToggle:Update()

    local function SetModeToggleVisible(visible)
        if f.modeToggle then
            f.modeToggle:SetAlpha(visible and 1 or 0)
            f.modeToggle:EnableMouse(visible)
        end
        if f.compactToggle then
            f.compactToggle:SetAlpha(visible and 1 or 0)
            f.compactToggle:EnableMouse(visible)
        end
    end

    f._ahuiModeToggleShown = false
    SetModeToggleVisible(false)

    f:SetScript("OnUpdate", function(self, dt)
        self.t = (self.t or 0) + dt
        if self.t > 1 then
            UpdateBars(self)
            self.t = 0
        end

        self.hoverT = (self.hoverT or 0) + dt
        if self.hoverT > 0.05 then
            local hovered =
                self:IsMouseOver() or
                (self.modeToggle and self.modeToggle:IsMouseOver()) or
                (self.compactToggle and self.compactToggle:IsMouseOver())

            if hovered ~= self._ahuiModeToggleShown then
                self._ahuiModeToggleShown = hovered
                SetModeToggleVisible(hovered)
            end

            self.hoverT = 0
        end
    end)

	self.frame = f

	self:ApplyCustomization()
	self:ApplyCompactMode()

    PT:RegisterVisibilityFrame(
        f,
        "hideConcentrationInCombat",
        "hideConcentrationInInstance",
        "showConcentration"
    )

    PT:UpdateVisibility()
	return f

end

function UI:Show()
    self:CreateFrame()
    if PT.UpdateVisibility then
        PT:UpdateVisibility()
    end
end

function UI:Hide()
    if self.frame then self.frame:Hide() end
end

function UI:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function UI:SetConcentrationMode(mode)
    if mode ~= "DF" and mode ~= "TWW" and mode ~= "MID" then
        return
    end

    HironCraftProfit_CharConfig.concActiveDB = mode

    if self.frame then
        UpdateBars(self.frame)
        if self.frame.modeToggle then
            self.frame.modeToggle:Update()
        end
        if self.frame.compactToggle then
            self.frame.compactToggle:Update()
        end
    end
end

function UI:ToggleConcentrationMode()
    local rot = HironCraftProfit_CharConfig.concRotation
    if type(rot) ~= "table" or #rot == 0 then
        rot = { "MID", "TWW", "DF" }
    end

    local current = GetMode()
    for i, v in ipairs(rot) do
        if v == current then
            HironCraftProfit_CharConfig.concActiveDB = rot[i + 1] or rot[1]

            if self.frame then
                UpdateBars(self.frame)
                self.frame.modeToggle:Update()
                if self.frame.compactToggle then
                    self.frame.compactToggle:Update()
                end
            end
            return
        end
    end

    HironCraftProfit_CharConfig.concActiveDB = rot[1]
    if self.frame then
        UpdateBars(self.frame)
        self.frame.modeToggle:Update()
        if self.frame.compactToggle then
            self.frame.compactToggle:Update()
        end
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LOGOUT")

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        UI:Show()
    end
end)

SLASH_HIRONCRAFT_PROFITCONC1 = "/ahuiconc"
SlashCmdList["HIRONCRAFT_PROFITCONC"] = function(msg)
    msg = msg and msg:lower() or ""

    if msg == "reset" then
        if HironCraftProfit and HironCraftProfit.ConcentrationUI then
            HironCraftProfit.ConcentrationUI:ResetPosition()
            print("|cffb19cd9HironCraft:|r Concentration position reset")
        end
    else
        print("|cffb19cd9HironCraft:|r /ahuiconc reset")
    end
end