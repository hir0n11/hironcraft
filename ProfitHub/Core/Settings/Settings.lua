local PT = HironCraftProfit
local UI = {}
local L = PT.L
PT.Settings = UI

function PT:GetDesignStyle()
    local c = self.config
    if c and c.designStyle == "fantasy" then return "fantasy" end
    return "soulless"
end

function PT:IsFantasyDesign()
    return self:GetDesignStyle() == "fantasy"
end

function PT:ApplyStyleLayout(frame, layoutByStyle)
    if not frame or not layoutByStyle then return end
    local style = self:IsFantasyDesign() and "fantasy" or "soulless"
    local layout = layoutByStyle[style] or layoutByStyle.soulless or layoutByStyle.fantasy
    if not layout then return end
    for key, c in pairs(layout) do
        local region = frame[key]
        if region then
            if c.w and c.h and region.SetSize then region:SetSize(c.w, c.h) end
            if (c.p or c.x or c.y or c.rel) and region.SetPoint then
                region:ClearAllPoints()
                local relTo = (c.rel and frame[c.rel]) or frame
                region:SetPoint(c.p or "TOPRIGHT", relTo, c.rp or c.p or "TOPRIGHT", c.x or 0, c.y or 0)
            end
        end
    end
end

local PANEL_BTN_UP  = "Interface\\Buttons\\UI-Panel-Button-Up"
local PANEL_BTN_DN  = "Interface\\Buttons\\UI-Panel-Button-Down"
local PANEL_BTN_DIS = "Interface\\Buttons\\UI-Panel-Button-Disabled"
local PANEL_BTN_HL  = "Interface\\Buttons\\UI-Panel-Button-Highlight"

function PT:ApplyPanelButtonSkin(button, color, texSet)
    if not button then return end
    if color then button._pgPanelColor = color end

    if not button._pgPanel then
        local pnl = {}
        pnl.left   = button:CreateTexture(nil, "ARTWORK")
        pnl.middle = button:CreateTexture(nil, "ARTWORK")
        pnl.right  = button:CreateTexture(nil, "ARTWORK")

        pnl.left:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        pnl.left:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
        pnl.left:SetWidth(12)
        pnl.left:SetTexCoord(0, 0.09375, 0, 0.6875)

        pnl.right:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
        pnl.right:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        pnl.right:SetWidth(12)
        pnl.right:SetTexCoord(0.53125, 0.625, 0, 0.6875)

        pnl.middle:SetPoint("TOPLEFT", pnl.left, "TOPRIGHT", 0, 0)
        pnl.middle:SetPoint("BOTTOMRIGHT", pnl.right, "BOTTOMLEFT", 0, 0)
        pnl.middle:SetTexCoord(0.09375, 0.53125, 0, 0.6875)

        button._pgPanel = pnl
    end
    local pnl = button._pgPanel

    button._pgPanelUp   = (texSet and texSet.up)   or PANEL_BTN_UP
    button._pgPanelDown = (texSet and texSet.down) or PANEL_BTN_DN
    button._pgPanelDis  = (texSet and texSet.dis)  or PANEL_BTN_DIS

    local function skin(file)
        local c = button._pgPanelColor or { 1, 1, 1 }
        pnl.left:SetTexture(file);   pnl.left:SetVertexColor(c[1], c[2], c[3])
        pnl.middle:SetTexture(file); pnl.middle:SetVertexColor(c[1], c[2], c[3])
        pnl.right:SetTexture(file);  pnl.right:SetVertexColor(c[1], c[2], c[3])
    end
    button._pgPanelSkin = skin

    local function refresh()
        local forced = button._pgPanelForced
        if forced == "disabled" then skin(button._pgPanelDis); return end
        if forced == "down" then skin(button._pgPanelDown); return end
        local en = (not button.IsEnabled) or button:IsEnabled()
        skin(en and button._pgPanelUp or button._pgPanelDis)
    end
    button._pgPanelRefresh = refresh
    refresh()

    if not button._pgPanelHooked then
        button._pgPanelHooked = true
        button:HookScript("OnMouseDown", function(self)
            if self._pgPanelForced == nil and self._pgPanelSkin and ((not self.IsEnabled) or self:IsEnabled()) then
                self._pgPanelSkin(self._pgPanelDown)
            end
        end)
        button:HookScript("OnMouseUp", function(self)
            if self._pgPanelRefresh then self._pgPanelRefresh() end
        end)
        button:HookScript("OnDisable", function(self)
            if self._pgPanelRefresh then self._pgPanelRefresh() end
        end)
        button:HookScript("OnEnable", function(self)
            if self._pgPanelRefresh then self._pgPanelRefresh() end
        end)
    end

    if button.SetHighlightTexture then
        button:SetHighlightTexture(PANEL_BTN_HL, "ADD")
        local ht = button:GetHighlightTexture()
        if ht then
            ht:ClearAllPoints()
            ht:SetAllPoints(button)
            ht:SetTexCoord(0, 0.625, 0, 0.6875)
        end
    end
end

function PT:SetPanelButtonForced(button, state)
    if not button then return end
    button._pgPanelForced = state
    if button._pgPanelRefresh then button._pgPanelRefresh() end
end

local copyLinkValue = "https://discord.gg/MFCJpgukUa"

StaticPopupDialogs["HIRONCRAFT_PROFIT_COPY_LINK"] = {
    text = "Copy link:",
    button1 = OKAY,
    hasEditBox = true,
    editBoxWidth = 350,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnShow = function(self)
        self.EditBox:SetText(copyLinkValue or "")
        self.EditBox:SetFocus()
        self.EditBox:HighlightText()
    end,
}

StaticPopupDialogs["HIRONCRAFT_PROFIT_LANG_RELOAD"] = {
    text = "%s",
    button1 = YES,
    button2 = NO,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function() ReloadUI() end,
}

local function CopyLink(link)
    copyLinkValue = link or ""
    StaticPopup_Show("HIRONCRAFT_PROFIT_COPY_LINK")
end

local function CopyFeedbackLink()
    CopyLink("https://discord.gg/MFCJpgukUa")
end

local function CopyYoutubeLink()
    CopyLink("https://www.youtube.com/@HironCrafts")
end

local function EffLocale()
    return (PT.EffectiveLocale and PT.EffectiveLocale()) or GetLocale()
end

local function AHText(ru, en)
    return EffLocale() == "ruRU" and ru or en
end

local function AHHelpHeader(ru, en)
    if EffLocale() == "ruRU" then
        return (ru or "") .. " / " .. (en or "")
    end
    return (en or "") .. " / " .. (ru or "")
end

local function AHHelpDescription(ru, en)
    if EffLocale() == "ruRU" then
        return (ru or "") .. "\n|cffb8b8b8" .. (en or "") .. "|r"
    end
    return (en or "") .. "\n|cffb8b8b8" .. (ru or "") .. "|r"
end
--[[
local HIRONCRAFT_PROFIT_HELP_COMMANDS = {
    {
        header = true,
        ru = "Основное",
        en = "General",
    },
    { cmd = "/profithub, /ph", ru = "Открыть настройки HironCraft.", en = "Open HironCraft settings." },
    { cmd = "/ph ?", ru = "Открыть это окно со списком команд.", en = "Open this command list." },
    { cmd = "/phwel", ru = "Показать приветственное окно.", en = "Show the welcome window." },
    { cmd = "/phwn", ru = "Показать список изменений.", en = "Show the What's New window." },

    {
        header = true,
        ru = "Профессии",
        en = "Professions",
    },
    { cmd = "/pg", ru = "Открыть новые руководства профессий.", en = "Open the new profession guides." },
    { cmd = "/phshop", ru = "Открыть список покупок HironCraft.", en = "Open the HironCraft shopping list." },
    { cmd = "/phrl", ru = "Открыть/закрыть окно RecipeList.", en = "Toggle the RecipeList window." },
    { cmd = "/phtrack", ru = "Открыть трекер ресурсов RecipeList.", en = "Open the RecipeList resource tracker." },

    {
        header = true,
        ru = "Модули",
        en = "Modules",
    },
    { cmd = "/phgd", ru = "Открыть помощник распределения золота.", en = "Open the gold depositor helper." },
    { cmd = "/phdes", ru = "Открыть модуль распыления.", en = "Open the disenchant module." },

    {
        header = true,
        ru = "Фарм-трекер",
        en = "Farm tracker",
    },
    { cmd = "/ph ft", ru = "Показать/скрыть фарм-трекер.", en = "Toggle the farm tracker." },
    { cmd = "/ph farm start", ru = "Начать сессию фарма.", en = "Start a farming session." },
    { cmd = "/ph farm pause", ru = "Поставить сессию на паузу.", en = "Pause the session." },
    { cmd = "/ph farm resume", ru = "Продолжить сессию.", en = "Resume the session." },
    { cmd = "/ph farm stop", ru = "Остановить сессию.", en = "Stop the session." },
    { cmd = "/ph farm reset", ru = "Сбросить текущую сессию.", en = "Reset the current session." },
    { cmd = "/ph farm history", ru = "Открыть историю фарма.", en = "Open farming history." },

    {
        header = true,
        ru = "Часы",
        en = "Clock",
    },
    { cmd = "/phclock", ru = "Открыть настройки часов.", en = "Open the clock settings." },
    { cmd = "/phclock timer", ru = "Открыть окно таймера.", en = "Open the timer popup." },
    { cmd = "/phclock stopwatch, /phclock sw", ru = "Открыть окно секундомера.", en = "Open the stopwatch popup." },
    { cmd = "/phclock toggle", ru = "Показать/скрыть часы.", en = "Toggle the clock." },

}
]]
local function CreateHelpCommandEditBox(parent, command)
    local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    edit:SetAutoFocus(false)
    edit:SetFontObject(HironCraftProfit_GameFontHighlightSmall)
    edit:SetSize(205, 20)
    edit:SetText(command or "")
    edit:SetCursorPosition(0)
    edit:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    edit:SetScript("OnMouseUp", function(self)
        self:SetFocus()
        self:HighlightText()
    end)
    edit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        local helpFrame = _G.HironCraftProfitHelpFrame
        if helpFrame then
            helpFrame:Hide()
        end
    end)
    return edit
end

function UI:ShowHelp()
    if self.helpFrame then
        if self.helpFrame:IsShown() then
            self.helpFrame:Hide()
        else
            self.helpFrame:Show()
            self.helpFrame:Raise()
        end
        return
    end

    local f = CreateFrame("Frame", "HironCraftProfitHelpFrame", UIParent, "BackdropTemplate")
    f:SetSize(650, 540)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(60)
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0, 0, 0, 0.92)
    f:SetBackdropBorderColor(0.694, 0.612, 0.851, 1)
    f:SetScript("OnMouseDown", function(self)
        self:Raise()
    end)
    f:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    if HironCraftProfit.RegisterEscClose then HironCraftProfit:RegisterEscClose(f) end

    local title = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText(AHText("Команды HironCraft", "HironCraft Commands"))

    local hint = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    hint:SetText(AHText("Кликните по строке команды, чтобы выделить её для копирования.", "Click a command field to select it for copying."))

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function()
        f:Hide()
    end)

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -62)
    scroll:SetPoint("BOTTOMRIGHT", -34, 16)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    local y = 0
    local rowWidth = 580
    for _, item in ipairs(HIRONCRAFT_PROFIT_HELP_COMMANDS) do
        if item.header then
            y = y + 12
            local header = content:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontNormal")
            header:SetPoint("TOPLEFT", 0, -y)
            header:SetText(AHHelpHeader(item.ru, item.en))
            y = y + 24
        else
            local row = CreateFrame("Frame", nil, content)
            row:SetSize(rowWidth, 34)
            row:SetPoint("TOPLEFT", 0, -y)

            local cmd = CreateHelpCommandEditBox(row, item.cmd)
            cmd:SetPoint("TOPLEFT", 0, -2)

            local desc = row:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontHighlightSmall")
            desc:SetPoint("TOPLEFT", cmd, "TOPRIGHT", 16, -1)
            desc:SetWidth(rowWidth - 225)
            desc:SetJustifyH("LEFT")
            desc:SetWordWrap(true)
            desc:SetText(AHHelpDescription(item.ru, item.en))

            local descHeight = math.max(20, desc:GetStringHeight() or 20)
            row:SetHeight(math.max(32, descHeight + 6))
            y = y + row:GetHeight() + 4
        end
    end

    content:SetSize(rowWidth, y + 8)
    self.helpFrame = f
    f:Show()
end

function UI:Create()
    if self.panel then
        return self.panel
    end
    self.checkboxes = {}

    local function RefreshWelcome()
        if PT.WelcomeUI and PT.WelcomeUI.Refresh then
            PT.WelcomeUI:Refresh()
        end
    end

    local f = CreateFrame("Frame", "HironCraftProfitSettingsMain", UIParent)
    f:SetSize(500, 440)

    local title = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L["Settings_Title"])

    local saveLabel = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontHighlight")
    saveLabel:SetPoint("TOPLEFT", title, "TOPLEFT", 440, 0)
    saveLabel:SetText(L["Settings_SaveMode"] or "Save settings")

    local cbChar = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    cbChar:SetPoint("TOPLEFT", saveLabel, "BOTTOMLEFT", 6, -14)
    cbChar.text:SetText(L["Settings_SaveCharacter"] or "Save per character")

    local cbAcc = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    cbAcc:SetPoint("TOPLEFT", cbChar, "BOTTOMLEFT", 0, -10)
    cbAcc.text:SetText(L["Settings_SaveAccount"] or "Save for account")

    local function UpdateSaveModeUI()
        cbChar:SetChecked(HironCraftProfit_DB.saveMode == "character")
        cbAcc:SetChecked(HironCraftProfit_DB.saveMode == "account")
    end

    local function SetSaveMode(mode)
        if HironCraftProfit_DB.saveMode == mode then return end

        HironCraftProfit_DB.saveMode = mode
        PT.config = PT:GetConfigDB()

        UpdateSaveModeUI()

        if PT.RefreshData then
            PT:RefreshData()
        end

        if PT.ConcentrationUI and PT.ConcentrationUI.ApplyCustomization then
            PT.ConcentrationUI:ApplyCustomization()
        end

        if PT.UI and PT.UI.ApplyCustomization then
            PT.UI:ApplyCustomization()
        end

        if PT.ConfirmButtons then
            if PT.ConfirmButtons.RefreshButtonsFromConfig then
                PT.ConfirmButtons:RefreshButtonsFromConfig()
            end
        end

        if PT.RefreshUI then
            PT:RefreshUI()
        end

        RefreshWelcome()
    end

    cbChar:SetScript("OnClick", function(self)
        if HironCraftProfit_DB.saveMode ~= "character" then
            SetSaveMode("character")
        else
            UpdateSaveModeUI()
        end
    end)

    cbAcc:SetScript("OnClick", function(self)
        if HironCraftProfit_DB.saveMode ~= "account" then
            SetSaveMode("account")
        else
            UpdateSaveModeUI()
        end
    end)

    UpdateSaveModeUI()

    local langLabel = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontHighlight")
    langLabel:SetPoint("TOPLEFT", cbAcc, "BOTTOMLEFT", -6, -16)
    langLabel:SetText(AHText("Язык", "Language"))

    local function CurrentLang() return HironCraftProfit_DB.language or "auto" end
    local function LangName(key)
        if key == "enUS" then return "English" end
        if key == "ruRU" then return "Русский" end
        return AHText("Авто (клиент)", "Auto (client)")
    end

    local langDrop = PT:CreateDropdownLikeButton(f, 120, 26)
    langDrop:SetPoint("TOPLEFT", langLabel, "BOTTOMLEFT", -6, -4)
    langDrop:SetText(LangName(CurrentLang()))

    local langHint = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontDisableSmall")
    langHint:SetPoint("TOPLEFT", langLabel, "BOTTOMLEFT", 14, -38)
    langHint:SetText("|cff888888" .. AHText("Применится после /reload", "Applies after /reload") .. "|r")

    local function SetLang(key)
        local prev = CurrentLang()
        HironCraftProfit_DB.language = key
        langDrop:SetText(LangName(key))
        if PT.ConfirmButtons and PT.ConfirmButtons.ShowReload then PT.ConfirmButtons:ShowReload() end
        if key ~= prev then
            StaticPopup_Show("HIRONCRAFT_PROFIT_LANG_RELOAD", AHText(
                "Язык интерфейса изменён. Перезагрузить интерфейс сейчас?",
                "Interface language changed. Reload UI now?"))
        end
    end

    langDrop:SetOnClick(function()
        if not PT.Dropdown then return end
        local cur = CurrentLang()
        PT.Dropdown:Show({
            owner = langDrop,
            items = {
                { text = LangName("auto"), checked = cur == "auto", onClick = function() SetLang("auto") end },
                { text = "English",        checked = cur == "enUS", onClick = function() SetLang("enUS") end },
                { text = "Русский",        checked = cur == "ruRU", onClick = function() SetLang("ruRU") end },
            },
        })
    end)

    local designLabel = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontHighlight")
    designLabel:SetPoint("TOPLEFT", langHint, "BOTTOMLEFT", -14, -14)
    designLabel:SetText(AHText("Дизайн интерфейса", "Interface design"))

    local function DesignName(key)
        if key == "soulless" then return AHText("Бездушный", "Soulless") end
        return AHText("Фэнтези", "Fantasy")
    end

    local designDrop = PT:CreateDropdownLikeButton(f, 140, 26)
    designDrop:SetPoint("TOPLEFT", designLabel, "BOTTOMLEFT", -6, -4)
    designDrop:SetText(DesignName(PT:GetDesignStyle()))

    local designHint = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontDisableSmall")
    designHint:SetPoint("TOPLEFT", designLabel, "BOTTOMLEFT", 14, -38)
    designHint:SetText("|cff888888" .. AHText("Применится после /reload", "Applies after /reload") .. "|r")

    local function SetDesign(key)
        local prev = PT:GetDesignStyle()
        PT.config.designStyle = key
        designDrop:SetText(DesignName(key))
        if key ~= prev then
            StaticPopup_Show("HIRONCRAFT_PROFIT_LANG_RELOAD", AHText(
                "Дизайн изменён. Перезагрузить интерфейс сейчас?",
                "Design changed. Reload UI now?"))
        end
    end

    designDrop:SetOnClick(function()
        if not PT.Dropdown then return end
        local cur = PT:GetDesignStyle()
        PT.Dropdown:Show({
            owner = designDrop,
            items = {
                { text = DesignName("fantasy"),  checked = cur == "fantasy",  onClick = function() SetDesign("fantasy") end },
                { text = DesignName("soulless"), checked = cur == "soulless", onClick = function() SetDesign("soulless") end },
            },
        })
    end)

    local feedbackBtn = CreateFrame("Button", nil, f)
    feedbackBtn:SetSize(160, 22)
    feedbackBtn:SetPoint("TOPLEFT", designHint, "BOTTOMLEFT", 0, -14)

    local feedbackIcon = feedbackBtn:CreateTexture(nil, "OVERLAY")
    feedbackIcon:SetSize(16, 16)
    feedbackIcon:SetPoint("LEFT", 1, 0)
    feedbackIcon:SetAtlas("UI-ChatIcon-Discord", false)
    feedbackIcon:SetVertexColor(0.694, 0.612, 0.851, 1)

    local text = feedbackBtn:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontHighlightSmall")
    text:SetPoint("LEFT", feedbackIcon, "RIGHT", 10, 0)
    text:SetText("|cffb19cd9Send Feedback / Report Bug|r")

    local hover = feedbackBtn:CreateTexture(nil, "BACKGROUND")
    hover:SetAllPoints()
    hover:SetTexture("Interface\\Buttons\\WHITE8x8")
    hover:SetColorTexture(1, 1, 1, 0)

    feedbackBtn:SetScript("OnEnter", function()
        hover:SetColorTexture(1, 1, 1, 0.08)
        text:SetText("|cffd0b8f0Send Feedback / Report Bug|r")

        GameTooltip:SetOwner(feedbackBtn, "ANCHOR_RIGHT")
        GameTooltip:SetText("Send feedback or suggestions", 1, 1, 1)
        GameTooltip:AddLine("@ProhitHUB Discord", 0, 0.8, 1)
        GameTooltip:Show()
    end)

    feedbackBtn:SetScript("OnLeave", function()
        hover:SetColorTexture(1, 1, 1, 0)
        text:SetText("|cffb19cd9Send Feedback / Report Bug|r")
        GameTooltip:Hide()
    end)

    feedbackBtn:SetScript("OnMouseUp", function()
        CopyFeedbackLink()
    end)

    local youtubeBtn = CreateFrame("Button", nil, f)
    youtubeBtn:SetSize(160, 22)
    youtubeBtn:SetPoint("TOPLEFT", feedbackBtn, "BOTTOMLEFT", -3, -6)

    local youtubeIconBg = youtubeBtn:CreateTexture(nil, "ARTWORK")
    youtubeIconBg:SetSize(22, 14)
    youtubeIconBg:SetPoint("LEFT", 2, 0)
    youtubeIconBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    youtubeIconBg:SetColorTexture(0.85, 0.02, 0.02, 1)

    local youtubeIcon = youtubeBtn:CreateTexture(nil, "OVERLAY")
    youtubeIcon:SetSize(15, 11)
    youtubeIcon:SetPoint("CENTER", youtubeIconBg, "CENTER", 0, 0)
    youtubeIcon:SetAtlas("CreditsScreen-Assets-Buttons-Play", false)
    youtubeIcon:SetVertexColor(1, 1, 1, 1)

    local youtubeText = youtubeBtn:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontHighlightSmall")
    youtubeText:SetPoint("LEFT", youtubeIconBg, "RIGHT", 7, 0)
    youtubeText:SetText(L["Settings_YoutubeChannel"] or "|cffff5555HironCraft YouTube Channel|r")

    local youtubeHover = youtubeBtn:CreateTexture(nil, "BACKGROUND")
    youtubeHover:SetAllPoints()
    youtubeHover:SetTexture("Interface\\Buttons\\WHITE8x8")
    youtubeHover:SetColorTexture(1, 1, 1, 0)

    youtubeBtn:SetScript("OnEnter", function()
        youtubeHover:SetColorTexture(1, 1, 1, 0.08)
        youtubeText:SetText(L["Settings_YoutubeChannel_Hover"] or "|cffff7777HironCraft YouTube Channel|r")

        GameTooltip:SetOwner(youtubeBtn, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Settings_YoutubeChannel_Tooltip"] or "HironCraft addon YouTube channel", 1, 1, 1)
        GameTooltip:AddLine("youtube.com/@HironCrafts", 1, 0.25, 0.25)
        GameTooltip:Show()
    end)

    youtubeBtn:SetScript("OnLeave", function()
        youtubeHover:SetColorTexture(1, 1, 1, 0)
        youtubeText:SetText(L["Settings_YoutubeChannel"] or "|cffff5555HironCraft YouTube Channel|r")
        GameTooltip:Hide()
    end)

    youtubeBtn:SetScript("OnMouseUp", function()
        CopyYoutubeLink()
    end)

    local cbMapPins = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    cbMapPins:SetPoint("TOPLEFT", youtubeBtn, "BOTTOMLEFT", -6, -24)
    cbMapPins.text:SetText(L["Settings_Enable"] or "Enable")

    cbMapPins.GetValue = function()
        return PT.config.enableMapPins ~= false
    end
    cbMapPins:SetChecked(cbMapPins.GetValue())
    self.checkboxes.enableMapPins = cbMapPins

    cbMapPins:SetScript("OnClick", function(self)
        PT.config.enableMapPins = self:GetChecked()

        if PT.SkinningWorldMapDataProvider then
            if PT.config.enableMapPins then
                if WorldMapFrame and WorldMapFrame.dataProviders
                    and not WorldMapFrame.dataProviders[PT.SkinningWorldMapDataProvider]
                then
                    WorldMapFrame:AddDataProvider(PT.SkinningWorldMapDataProvider)
                end

                if PT.MapPinsButton then
                    PT.MapPinsButton:Show()
                end

                if PT.SkinningWorldMapDataProvider.RefreshAllData then
                    PT.SkinningWorldMapDataProvider:RefreshAllData()
                end
            else
                if PT.SkinningWorldMapDataProvider.RemoveAllData then
                    PT.SkinningWorldMapDataProvider:RemoveAllData()
                end

                if PT.MapPinsButton then
                    PT.MapPinsButton:Hide()
                end

                if PT.HideMapPinsMenu then
                    PT.HideMapPinsMenu()
                end
            end
        end
    end)

    local cbFirstCraft = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    cbFirstCraft:SetPoint("TOPLEFT", cbMapPins, "BOTTOMLEFT", 0, -8)
    cbFirstCraft.text:SetText(L["Settings_FirstCraft"] or "First-craft icons")

    cbFirstCraft.GetValue = function()
        return PT.config.showFirstCraftIcons ~= false
    end
    cbFirstCraft:SetChecked(cbFirstCraft.GetValue())
    self.checkboxes.showFirstCraftIcons = cbFirstCraft

    cbFirstCraft:SetScript("OnClick", function(self)
        if PT.FirstCraft then
            PT.FirstCraft:SetEnabled(self:GetChecked())
        else
            PT.config.showFirstCraftIcons = self:GetChecked()
        end
    end)

    local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    cb.text:SetText(L["Settings_Concentration"])
    cb.GetValue = function()
        return PT.config.showConcentration ~= false
    end
    cb:SetChecked(cb.GetValue())
    self.checkboxes.showConcentration = cb

    cb:SetScript("OnClick", function(self)
        PT.config.showConcentration = self:GetChecked()

        if PT.UpdateVisibility then
            PT:UpdateVisibility()
        end

        RefreshWelcome()
    end)

    local cbConcHide = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    cbConcHide:SetPoint("LEFT", cb.text, "RIGHT", 20, 0)
    cbConcHide.text:SetText(L["Settings_HideInCombat"] or "Hide in combat")

    cbConcHide.GetValue = function()
        return PT.config.hideConcentrationInCombat ~= false
    end
    cbConcHide:SetChecked(cbConcHide.GetValue())
    self.checkboxes.hideConcentrationInCombat = cbConcHide

    cbConcHide:SetScript("OnClick", function(self)
        PT.config.hideConcentrationInCombat = self:GetChecked()
    end)

    local cbConcInstance = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    cbConcInstance:SetPoint("LEFT", cbConcHide.text, "RIGHT", 12, 0)
    cbConcInstance.text:SetText(L["Settings_HideInInstance"] or "Hide in instances")

    cbConcInstance.GetValue = function()
        return PT.config.hideConcentrationInInstance == true
    end
    cbConcInstance:SetChecked(cbConcInstance.GetValue())
    self.checkboxes.hideConcentrationInInstance = cbConcInstance

    cbConcInstance:SetScript("OnClick", function(self)
        PT.config.hideConcentrationInInstance = self:GetChecked()
    end)

    local cb2 = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    cb2:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 0, -10)
    cb2.text:SetText(L["Settings_ProfWindow"])
    cb2.GetValue = function()
        return PT.config.showProfessionsWindow ~= false
    end
    cb2:SetChecked(cb2.GetValue())
    self.checkboxes.showProfessionsWindow = cb2

    cb2:SetScript("OnClick", function(self)
        local enabled = self:GetChecked()
        PT.config.showProfessionsWindow = enabled

        if PT.UpdateVisibility then
            PT:UpdateVisibility()
        end

        RefreshWelcome()
    end)

    local cbProfHide = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    cbProfHide:SetPoint("TOPLEFT", cbConcHide, "BOTTOMLEFT", 0, -10)
    cbProfHide.text:SetText(L["Settings_HideInCombat"] or "Hide in combat")

    cbProfHide.GetValue = function()
        return PT.config.hideProfessionsInCombat ~= false
    end
    cbProfHide:SetChecked(cbProfHide.GetValue())
    self.checkboxes.hideProfessionsInCombat = cbProfHide

    cbProfHide:SetScript("OnClick", function(self)
        PT.config.hideProfessionsInCombat = self:GetChecked()
    end)

    local cbProfInstance = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    cbProfInstance:SetPoint("LEFT", cbProfHide.text, "RIGHT", 12, 0)
    cbProfInstance.text:SetText(L["Settings_HideInInstance"] or "Hide in instances")

    cbProfInstance.GetValue = function()
        return PT.config.hideProfessionsInInstance == true
    end
    cbProfInstance:SetChecked(cbProfInstance.GetValue())
    self.checkboxes.hideProfessionsInInstance = cbProfInstance

    cbProfInstance:SetScript("OnClick", function(self)
        PT.config.hideProfessionsInInstance = self:GetChecked()
    end)

    local cb3 = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    cb3:SetPoint("TOPLEFT", cb2, "BOTTOMLEFT", 0, -10)
    cb3.text:SetText(L["Settings_LockWindows"])
    cb3:SetChecked(PT.config.lockWindows)

    cb3:SetScript("OnClick", function(self)
        PT.config.lockWindows = self:GetChecked()
        local windows = {
            PT.UI and PT.UI.frame,
            PT.ConcentrationUI and PT.ConcentrationUI.frame,
        }
        for _, w in ipairs(windows) do
            if w then
                w:SetMovable(not PT.config.lockWindows)
                w:EnableMouse(not PT.config.lockWindows)
            end
        end
    end)

    PT.config.skinningCheckEnabled = PT.config.skinningCheckEnabled ~= false
    PT.config.skinningIconSize = PT.config.skinningIconSize or 50

    local scb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    scb:SetPoint("TOPLEFT", cb3, "BOTTOMLEFT", 0, -10)
    scb.GetValue = function()
        return PT.config.skinningCheckEnabled ~= false
    end
    scb:SetChecked(scb.GetValue())
    self.checkboxes.skinningCheckEnabled = scb

    scb.text = scb:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontNormal")
    scb.text:SetPoint("LEFT", scb, "RIGHT", 0, 0)
    scb.text:SetText(L["Settings_SkinningCheck"])

    scb:SetScript("OnClick", function(self)
        PT.config.skinningCheckEnabled = self:GetChecked()

        if PT.UpdateVisibility then
            PT:UpdateVisibility()
        end

        RefreshWelcome()
    end)

    local cbSkinHide = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    cbSkinHide:SetPoint("LEFT", scb.text, "RIGHT", 16, 0)
    cbSkinHide.text:SetText(L["Settings_HideInCombat"] or "Hide in combat")

    cbSkinHide.GetValue = function()
        return PT.config.hideSkinningInCombat ~= false
    end
    cbSkinHide:SetChecked(cbSkinHide.GetValue())
    self.checkboxes.hideSkinningInCombat = cbSkinHide

    cbSkinHide:SetScript("OnClick", function(self)
        PT.config.hideSkinningInCombat = self:GetChecked()
    end)

    local cbSkinInstance = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    cbSkinInstance:SetPoint("LEFT", cbSkinHide.text, "RIGHT", 12, 0)
    cbSkinInstance.text:SetText(L["Settings_HideInInstance"] or "Hide in instances")

    cbSkinInstance.GetValue = function()
        return PT.config.hideSkinningInInstance == true
    end
    cbSkinInstance:SetChecked(cbSkinInstance.GetValue())
    self.checkboxes.hideSkinningInInstance = cbSkinInstance

    cbSkinInstance:SetScript("OnClick", function(self)
        PT.config.hideSkinningInInstance = self:GetChecked()
    end)

    local sizeLabel = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontNormal")
    sizeLabel:SetPoint("TOPLEFT", scb, "BOTTOMLEFT", 6, -18)
    sizeLabel:SetText(L["Settings_SkinningIconSize"])

    local sizeInput = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    sizeInput:SetSize(30, 20)
    sizeInput:SetPoint("LEFT", sizeLabel, "RIGHT", 8, 0)
    sizeInput:SetAutoFocus(false)
    sizeInput:SetNumeric(true)
    sizeInput:SetMaxLetters(3)
    sizeInput:SetText(PT.config.skinningIconSize)
    sizeInput:SetCursorPosition(0)

    sizeInput:SetScript("OnEnterPressed", function(self)
        local v = tonumber(self:GetText())
        if not v then
            self:SetText(PT.config.skinningIconSize)
            self:ClearFocus()
            return
        end
        v = math.max(20, math.min(300, math.floor(v)))
        PT.config.skinningIconSize = v
        self:SetText(v)
        self:SetCursorPosition(0)
        if PT.UI_SkinningCheck then
            PT.UI_SkinningCheck:Update()
        end
        self:ClearFocus()
    end)

    local targetsLabel = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontNormal")
    targetsLabel:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 0, -16)
    targetsLabel:SetText(L["Settings_SkinningTargets"])

    local targetsFrame = CreateFrame("Frame", nil, f, "BackdropTemplate")
    targetsFrame:SetPoint("TOPLEFT", targetsLabel, "BOTTOMLEFT", 0, -10)
    targetsFrame:SetSize(300, 200)
    targetsFrame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    targetsFrame:SetBackdropColor(0, 0, 0, 0.6)
    targetsFrame:SetBackdropBorderColor(0.694, 0.612, 0.851, 1)

    local targetsScroll = CreateFrame("ScrollFrame", nil, targetsFrame)
    targetsScroll:SetPoint("TOPLEFT", 4, -4)
    targetsScroll:SetPoint("BOTTOMRIGHT", -4, 4)
    targetsScroll:EnableMouseWheel(true)

    local targetsContent = CreateFrame("Frame", nil, targetsScroll)
    targetsContent:SetSize(1, 1)
    targetsScroll:SetScrollChild(targetsContent)

    local targetsRowH = 24
    targetsScroll:SetScript("OnMouseWheel", function(self, delta)
        self:SetVerticalScroll(math.max(0, self:GetVerticalScroll() - delta * targetsRowH))
    end)

    local function RebuildSkinningTargets()
        local children = { targetsContent:GetChildren() }
        for _, ch in ipairs(children) do
            ch:Hide()
            ch:SetParent(nil)
        end

        local SC = PT.SkinningCheck
        if not SC then
            targetsFrame:Hide()
            targetsLabel:Hide()
            return
        end

        targetsFrame:Show()
        targetsLabel:Show()

        PT.config.skinningDisabledTargets = PT.config.skinningDisabledTargets or {}
        local disabledDB = PT.config.skinningDisabledTargets

        local y = -2
        for _, target in ipairs(SC.TARGETS or {}) do
            if SC:IsTargetAvailable(target) then
                local row = CreateFrame("Frame", nil, targetsContent)
                row:SetSize(276, targetsRowH)
                row:SetPoint("TOPLEFT", 0, y)
                row:EnableMouse(true)

                local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
                cb:SetPoint("LEFT", 2, 0)
                cb:SetSize(22, 22)
                cb:SetChecked(not disabledDB[target.id])

                local lbl = row:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontNormal")
                lbl:SetPoint("LEFT", cb, "RIGHT", 4, 0)
                lbl:SetPoint("RIGHT", row, "RIGHT", -4, 0)
                lbl:SetJustifyH("LEFT")
                lbl:SetText(SC:GetTargetName(target))

                cb:SetScript("OnClick", function(self)
                    disabledDB[target.id] = not self:GetChecked()

                    if PT.UI_SkinningCheck and PT.UI_SkinningCheck.Update then
                        PT.UI_SkinningCheck:Update()
                    end
                    if PT.UI_SkinningTargets and PT.UI_SkinningTargets.Build then
                        PT.UI_SkinningTargets:Build()
                    end
                    if PT.AccountOverview_Data
                       and PT.AccountOverview_Data.SaveCurrentCharacterSkinningSnapshot
                    then
                        PT.AccountOverview_Data:SaveCurrentCharacterSkinningSnapshot()
                    end
                    if PT.AccountOverview and PT.AccountOverview.Refresh then
                        PT.AccountOverview:Refresh()
                    end
                end)

                row:SetScript("OnEnter", function()
                    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                    GameTooltip:SetText(SC:GetTargetName(target), 1, 1, 1)
                    local guide = SC.GetGuideTooltip and SC:GetGuideTooltip(target)
                    if guide then
                        GameTooltip:AddLine(guide, 0.85, 0.85, 0.85, true)
                    end
                    GameTooltip:Show()
                end)

                row:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)

                y = y - targetsRowH
            end
        end

        targetsContent:SetHeight(math.max(1, -y + 4))
    end

    self.RebuildSkinningTargets = RebuildSkinningTargets
    RebuildSkinningTargets()

    self.panel = f
    return f
end

function UI:Refresh()
    if not self.checkboxes then return end

    for _, cb in pairs(self.checkboxes) do
        if cb.GetValue then
            cb:SetChecked(cb.GetValue())
        end
    end

    if self.RefreshDebugButtonText then
        self:RefreshDebugButtonText()
    end

    if self.RebuildSkinningTargets then
        self:RebuildSkinningTargets()
    end

    if PT.WelcomeUI and PT.WelcomeUI.Refresh then
        PT.WelcomeUI:Refresh()
    end
end

function UI:Register()
    if self.category then return end

    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_LOGIN")
    ev:SetScript("OnEvent", function()
        if self.category then return end

        local panel = UI:Create()
        local category = Settings.RegisterCanvasLayoutCategory(panel, "HironCraft")
        Settings.RegisterAddOnCategory(category)

        UI.category = category
        if UI.RegisterInfoPanelSubcategory then
            UI:RegisterInfoPanelSubcategory()
        end
        if UI.RegisterFarmTrackerSubcategory then
            UI:RegisterFarmTrackerSubcategory()
        end
        if UI.RegisterClockBoxSubcategory then
            UI:RegisterClockBoxSubcategory()
        end
        if UI.RegisterButtonsSubcategory then
            UI:RegisterButtonsSubcategory()
        end
        if UI.RegisterQuestShoppingSubcategory then
            UI:RegisterQuestShoppingSubcategory()
        end
        if UI.RegisterItemMarksSubcategory then
            UI:RegisterItemMarksSubcategory()
        end
    end)
end

SLASH_HIRONCRAFT_PROFIT1 = "/ahui"
SLASH_HIRONCRAFT_PROFIT2 = "/profithub"
SLASH_HIRONCRAFT_PROFIT3 = "/ph"
SLASH_HIRONCRAFT_PROFIT4 = "/hc"
SLASH_HIRONCRAFT_PROFIT5 = "/hironcraft"
SlashCmdList["HIRONCRAFT_PROFIT"] = function(msg)
    local cmd = tostring(msg or ""):match("^(%S+)")
    cmd = cmd and string.lower(cmd) or ""

    if cmd == "help" or cmd == "?" then
        if PT.Settings and PT.Settings.ShowHelp then
            PT.Settings:ShowHelp()
        end
        return
    end

    if PT.Settings and PT.Settings.category then
        Settings.OpenToCategory(PT.Settings.category:GetID())
    end
end
