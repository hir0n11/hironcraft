local PT = HironCraftProfit
if not PT then return end
local L = PT.L
local Welcome = {}
PT.WelcomeUI = Welcome

local ADDON_NAME = "HironCraft"
local FONT = HironCraftProfit.FONT

function Welcome:Create()
    if self.frame then return self.frame end
    PT.config = PT.config or {}

    local defaults = {
        showConcentration     = true,
        skinningCheckEnabled  = false,
        showProfessionsWindow = true,
        confirmOK             = true,
        confirmReload         = false,
        stackAssistEnabled    = false,
    }
    for k, v in pairs(defaults) do
        if PT.config[k] == nil then
            PT.config[k] = v
        end
    end

    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_CharConfig = HironCraftProfit_CharConfig or {}

    local f = CreateFrame("Frame", "HironCraftProfitWelcomeFrame", UIParent, "BackdropTemplate")
    f:SetSize(480, 372)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 3,
    })
    f:SetBackdropColor(0, 0, 0, 0.95)
    f:SetBackdropBorderColor(0.694, 0.612, 0.851, 1)
    f:Hide()
    if HironCraftProfit.RegisterEscClose then HironCraftProfit:RegisterEscClose(f) end

    local logo = f:CreateTexture(nil, "ARTWORK")
    logo:SetSize(165, 128)
    logo:SetPoint("TOP", 0, -24)
    logo:SetTexture("Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\media\\logo_big.tga")

    local text = f:CreateFontString(nil, "OVERLAY")
    text:SetFont(FONT, 14, "")
    text:SetWidth(420)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("TOP")
    text:SetPoint("TOP", logo, "BOTTOM", 0, -16)
    text:SetText(L["WELCOME_TEXT"])

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function()
        HironCraftProfit_DB.welcomeShown = true
        f:Hide()
    end)

    local openOptions = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    openOptions:SetSize(280, 36)
    openOptions:SetPoint("BOTTOM", 0, 28)
    openOptions:SetText(L["WELCOME_OPEN_SETTINGS"])
    do
        local fs = openOptions:GetFontString()
        if fs then fs:SetFont(FONT, 15, "") end
    end
    openOptions:SetScript("OnClick", function()
        HironCraftProfit_DB.welcomeShown = true
        HironCraftProfit_CharConfig.__welcomeApplied = true
        if PT.ConfirmButtons then
            local bc = PT.ConfirmButtons:GetButtonsConfig()
            PT.ConfirmButtons:SetOKEnabled(bc.confirmOK ~= false)
            PT.ConfirmButtons:SetReloadEnabled(bc.confirmReload ~= false)
        end
        f:Hide()
        if PT.Settings and PT.Settings.category then
            Settings.OpenToCategory(PT.Settings.category:GetID())
        end
    end)

    self.frame = f
    return f
end

function Welcome:Refresh()
end

function Welcome:Show()
    self:Create():Show()
end

SLASH_HIRONCRAFT_PROFITWELCOME1 = "/phwelcome"
SLASH_HIRONCRAFT_PROFITWELCOME2 = "/phwel"
SLASH_HIRONCRAFT_PROFITWELCOME3 = "/ahuiwelcome"
SLASH_HIRONCRAFT_PROFITWELCOME4 = "/ahwelcome"

SlashCmdList["HIRONCRAFT_PROFITWELCOME"] = function()
    if PT.WelcomeUI then
        PT.WelcomeUI:Show()
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    HironCraftProfit_DB = HironCraftProfit_DB or {}

    if not HironCraftProfit_DB.welcomeShown then
        HironCraftProfit_DB.welcomeShown = true
        C_Timer.After(0.5, function()
            Welcome:Create():Show()
        end)
    end
end)
