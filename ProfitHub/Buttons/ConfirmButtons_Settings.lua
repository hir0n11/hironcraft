local PT = HironCraftProfit
if not PT then return end

local L = PT.L or {}
local UI = PT.Settings
if not UI then return end

local CB = PT.ConfirmButtons
if not CB then return end

local function BCFG()
    return CB:GetButtonsConfig()
end

local panel = CreateFrame("Frame", "HironCraftProfitButtonsSettingsPanel", UIParent)
panel:SetSize(700, 620)

local title = panel:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontHighlightLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText(L["Settings_Buttons"] or "Кнопки")

local cbOK = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
cbOK:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -14)
cbOK.text:SetText(L["Settings_ConfirmOK"])
cbOK:SetChecked(BCFG().confirmOK ~= false)
cbOK:SetScript("OnClick", function(self)
    BCFG().confirmOK = self:GetChecked()
    CB:SetOKEnabled(BCFG().confirmOK)
end)

local cbR = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
cbR:SetPoint("TOPLEFT", cbOK, "BOTTOMLEFT", 0, -10)
cbR.text:SetText(L["Settings_ConfirmReload"])
cbR:SetChecked(BCFG().confirmReload ~= false)
cbR:SetScript("OnClick", function(self)
    BCFG().confirmReload = self:GetChecked()
    CB:SetReloadEnabled(BCFG().confirmReload)
end)

local cbAuctionator = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
cbAuctionator:SetPoint("TOPLEFT", cbOK, "TOPRIGHT", 200, 0)
cbAuctionator.text:SetText(L["Settings_ConfirmAuctionator"] or "Confirm Auctionator purchases")
cbAuctionator:SetChecked(BCFG().confirmAuctionator == true)
cbAuctionator:SetScript("OnClick", function(self)
    BCFG().confirmAuctionator = self:GetChecked() == true
    if CB.SetAuctionatorEnabled then
        CB:SetAuctionatorEnabled(BCFG().confirmAuctionator)
    end
end)

local reloadSizeLabel = panel:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontNormal")
reloadSizeLabel:SetPoint("LEFT", cbR.text, "RIGHT", 12, 0)
reloadSizeLabel:SetText(L["Settings_ReloadSize"] or "Size")

local reloadSizeInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
reloadSizeInput:SetSize(36, 20)
reloadSizeInput:SetPoint("LEFT", reloadSizeLabel, "RIGHT", 8, 0)
reloadSizeInput:SetAutoFocus(false)
reloadSizeInput:SetNumeric(true)
reloadSizeInput:SetMaxLetters(3)
reloadSizeInput:SetText(CB:GetReloadSize())
reloadSizeInput:SetCursorPosition(0)
reloadSizeInput:SetScript("OnEnterPressed", function(self)
    local v = tonumber(self:GetText())
    if not v then
        self:SetText(CB:GetReloadSize())
        self:ClearFocus()
        return
    end
    local s = CB:SetReloadSize(v)
    self:SetText(s)
    self:SetCursorPosition(0)
    self:ClearFocus()
end)

local styleLabel = panel:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontHighlight")
styleLabel:SetPoint("TOPLEFT", cbAuctionator, "BOTTOMLEFT", 0, -14)
styleLabel:SetText(L["Settings_ConfirmStyle"])

local styles = {}
if CB.STYLES then
    for key, info in pairs(CB.STYLES) do
        table.insert(styles, { key = key, name = info.name or key })
    end
end
table.sort(styles, function(a, b) return a.name < b.name end)

local dd = CreateFrame("Frame", "HironCraftProfitConfirmStyleDropdown", panel, "UIDropDownMenuTemplate")
dd:SetPoint("TOPLEFT", styleLabel, "BOTTOMLEFT", -16, -4)
UIDropDownMenu_SetWidth(dd, 200)

UIDropDownMenu_Initialize(dd, function(_, level)
    for _, s in ipairs(styles) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = s.name
        info.checked = (BCFG().confirmButtonStyle == s.key)
        info.func = function()
            BCFG().confirmButtonStyle = s.key
            UIDropDownMenu_SetText(dd, s.name)
            if CB.ApplyStyle then CB:ApplyStyle() end
        end
        UIDropDownMenu_AddButton(info, level)
    end
end)

do
    local cur = BCFG().confirmButtonStyle
    local style = CB.STYLES and CB.STYLES[cur]
    UIDropDownMenu_SetText(dd, style and style.name or (L["Default"] or "Default"))
end

local cbScope = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
cbScope:SetPoint("LEFT", dd, "RIGHT", -6, 2)
cbScope.text:SetText(L["Settings_ButtonsPerChar"] or "Настройки кнопок для этого персонажа")
cbScope:SetChecked(CB:IsButtonsPerChar())
cbScope:SetScript("OnClick", function(self)
    CB:SetButtonsPerChar(self:GetChecked() == true)
    if UI.RefreshButtonsSubcategory then UI:RefreshButtonsSubcategory() end
end)
cbScope:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["Settings_ButtonsPerChar_TipTitle"] or "Where to save button settings", 1, 1, 1)
    GameTooltip:AddLine(L["Settings_ButtonsPerChar_Tip"] or "On: this character keeps its own buttons and style. Off: settings are shared across all characters.", nil, nil, nil, true)
    GameTooltip:Show()
end)
cbScope:SetScript("OnLeave", function() GameTooltip:Hide() end)

local addPopupLabel = panel:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontHighlight")
addPopupLabel:SetPoint("TOPLEFT", cbR, "BOTTOMLEFT", 10, -18)
addPopupLabel:SetText(L["Settings_AddPopupExclude"] or "Add popup exclusion")

local addPopupInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
addPopupInput:SetSize(180, 22)
addPopupInput:SetPoint("TOPLEFT", addPopupLabel, "BOTTOMLEFT", 0, -6)
addPopupInput:SetAutoFocus(false)
addPopupInput:SetMaxLetters(80)

local addPopupBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
addPopupBtn:SetSize(80, 22)
addPopupBtn:SetPoint("LEFT", addPopupInput, "RIGHT", 8, 0)
addPopupBtn:SetText(ADD or "Add")

local debugPopupBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
debugPopupBtn:SetSize(80, 22)
debugPopupBtn:SetPoint("LEFT", addPopupBtn, "RIGHT", 8, 0)

local function RefreshDebugButtonText()
    local enabled = CB.IsDebugEnabled and CB:IsDebugEnabled()
    if enabled then
        debugPopupBtn:SetText(L["Settings_ConfirmDebug_On"] or "Debug: ON")
    else
        debugPopupBtn:SetText(L["Settings_ConfirmDebug_Off"] or "Debug: OFF")
    end
end

debugPopupBtn:SetScript("OnClick", function()
    if CB.SetDebugEnabled and CB.IsDebugEnabled then
        CB:SetDebugEnabled(not CB:IsDebugEnabled())
        RefreshDebugButtonText()
    end
end)

debugPopupBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["Settings_ConfirmDebug_Tooltip_Title"] or "Popup debug mode", 1, 1, 1)
    GameTooltip:AddLine(L["Settings_ConfirmDebug_Tooltip_1"] or "Enables popup ID output in chat.", nil, nil, nil, true)
    GameTooltip:AddLine(L["Settings_ConfirmDebug_Tooltip_2"] or "When a popup appears, the addon prints its exact name to chat.", nil, nil, nil, true)
    GameTooltip:AddLine(L["Settings_ConfirmDebug_Tooltip_3"] or "Paste that name into the exclusion field exactly as it appears.", nil, nil, nil, true)
    GameTooltip:AddLine(" ", 1, 1, 1)
    GameTooltip:AddLine(L["Settings_ConfirmDebug_Tooltip_4"] or "Example: GUILD_INVITE", 1, 0.82, 0, true)
    GameTooltip:AddLine(L["Settings_ConfirmDebug_Tooltip_5"] or "After /reload, debug mode turns off automatically.", 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
end)

debugPopupBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local popupListLabel = panel:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontNormal")
popupListLabel:SetPoint("TOPLEFT", addPopupInput, "BOTTOMLEFT", 0, -12)
popupListLabel:SetText(L["Settings_PopupList"] or "User popup exclusions")

local popupListFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
popupListFrame:SetPoint("TOPLEFT", popupListLabel, "BOTTOMLEFT", 0, -4)
popupListFrame:SetSize(280, 150)
popupListFrame:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 2,
})
popupListFrame:SetBackdropColor(0, 0, 0, 0.6)
popupListFrame:SetBackdropBorderColor(0.694, 0.612, 0.851, 1)

local popupScroll = CreateFrame("ScrollFrame", nil, popupListFrame)
popupScroll:SetPoint("TOPLEFT", 4, -4)
popupScroll:SetPoint("BOTTOMRIGHT", -4, 4)
popupScroll:EnableMouseWheel(true)

local popupContent = CreateFrame("Frame", nil, popupScroll)
popupContent:SetSize(1, 1)
popupScroll:SetScrollChild(popupContent)

local popupRowH = 22
popupScroll:SetScript("OnMouseWheel", function(self, delta)
    self:SetVerticalScroll(math.max(0, self:GetVerticalScroll() - delta * popupRowH))
end)

local function RebuildPopupList()
    local children = { popupContent:GetChildren() }
    for _, ch in ipairs(children) do
        ch:Hide()
        ch:SetParent(nil)
    end

    if not CB then return end

    local list = CB:GetUserExcludedPopupList()
    local y = -2

    for _, which in ipairs(list) do
        local row = CreateFrame("Frame", nil, popupContent)
        row:SetSize(272, popupRowH)
        row:SetPoint("TOPLEFT", 0, y)

        local hover = row:CreateTexture(nil, "BACKGROUND")
        hover:SetAllPoints()
        hover:SetTexture("Interface\\Buttons\\WHITE8x8")
        hover:SetColorTexture(1, 1, 1, 0)

        row:EnableMouse(true)
        row:SetScript("OnEnter", function()
            hover:SetColorTexture(1, 1, 1, 0.10)
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:SetText(which, 1, 1, 1)
            local full = CB:GetPopupFullText(which)
            if full and full ~= which then
                GameTooltip:AddLine(full, nil, nil, nil, true)
            end
            GameTooltip:Show()
        end)

        row:SetScript("OnLeave", function()
            hover:SetColorTexture(1, 1, 1, 0)
            GameTooltip:Hide()
        end)

        local lbl = row:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontNormal")
        lbl:SetPoint("LEFT", 6, 0)
        lbl:SetPoint("RIGHT", row, "RIGHT", -60, 0)
        lbl:SetJustifyH("LEFT")
        lbl:SetText(which)

        local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        removeBtn:SetSize(70, 20)
        removeBtn:SetPoint("RIGHT", -4, 0)
        removeBtn:SetText(REMOVE or "Remove")
        if PT.StyleButton then PT:StyleButton(removeBtn) end
        removeBtn:SetScript("OnClick", function()
            CB:RemoveUserExcludedPopup(which)
            RebuildPopupList()
        end)

        y = y - popupRowH
    end

    popupContent:SetHeight(math.max(1, -y + 4))
end

local function AddPopupFromInput()
    local text = addPopupInput:GetText()
    if not text or text == "" then return end

    text = strtrim(text)
    if text == "" then return end

    if CB.AddUserExcludedPopup then
        CB:AddUserExcludedPopup(text)
    end

    addPopupInput:SetText("")
    addPopupInput:ClearFocus()
    RebuildPopupList()
end

addPopupBtn:SetScript("OnClick", AddPopupFromInput)
addPopupInput:SetScript("OnEnterPressed", function() AddPopupFromInput() end)

local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
reset:SetSize(280, 22)
reset:SetPoint("TOPLEFT", popupListFrame, "BOTTOMLEFT", 0, -6)
reset:SetText(L["Settings_ResetOK"])
reset:SetScript("OnClick", function()
    if CB.ResetUserExcludedPopups then
        CB:ResetUserExcludedPopups()
    elseif CB.ResetOKExclusions then
        CB:ResetOKExclusions()
    end
    RebuildPopupList()
end)

local function RefreshUI()
    cbScope:SetChecked(CB:IsButtonsPerChar())
    cbOK:SetChecked(BCFG().confirmOK ~= false)
    cbR:SetChecked(BCFG().confirmReload ~= false)
    cbAuctionator:SetChecked(BCFG().confirmAuctionator == true)
    if CB.GetReloadSize then
        reloadSizeInput:SetText(CB:GetReloadSize())
        reloadSizeInput:SetCursorPosition(0)
    end
    local cur = BCFG().confirmButtonStyle
    local style = CB.STYLES and CB.STYLES[cur]
    UIDropDownMenu_SetText(dd, style and style.name or (L["Default"] or "Default"))
    RefreshDebugButtonText()
    RebuildPopupList()
end

UI.RefreshDebugButtonText = RefreshDebugButtonText

function UI:RefreshButtonsSubcategory()
    RefreshUI()
end

function UI:RegisterButtonsSubcategory()
    if self.buttonsSubcategory then return end
    if not self.category then return end

    local sub = Settings.RegisterCanvasLayoutSubcategory(
        self.category,
        panel,
        L["Settings_Buttons"] or "Кнопки"
    )

    if sub and sub.SetOnRefresh then
        sub:SetOnRefresh(RefreshUI)
    elseif sub then
        sub.OnRefresh = RefreshUI
    end

    self.buttonsSubcategory = sub
    RefreshUI()

    if PT.RestyleButtons then PT:RestyleButtons(panel) end
end
