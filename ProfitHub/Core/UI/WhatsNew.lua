local PT = HironCraftProfit
if not PT then return end

local L = PT.L
local WhatsNew = {}
PT.WhatsNewUI = WhatsNew

local ADDON_NAME = "HironCraft"
local FONT = HironCraftProfit.FONT

local YOUTUBE_LINK = "https://www.youtube.com/@HironCrafts"
local BOT_LINK     = "https://discord.gg/MFCJpgukUa"

StaticPopupDialogs["HIRONCRAFT_PROFIT_COPY_YOUTUBE_LINK"] = {
    text = "Copy YouTube link:",
    button1 = OKAY,
    hasEditBox = true,
    editBoxWidth = 350,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,

    OnShow = function(self)
        self.EditBox:SetText(YOUTUBE_LINK)
        self.EditBox:SetFocus()
        self.EditBox:HighlightText()
    end,
}

StaticPopupDialogs["HIRONCRAFT_PROFIT_COPY_BOT_LINK"] = {
    text = "Copy Discord link:",
    button1 = OKAY,
    hasEditBox = true,
    editBoxWidth = 350,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,

    OnShow = function(self)
        self.EditBox:SetText(BOT_LINK)
        self.EditBox:SetFocus()
        self.EditBox:HighlightText()
    end,
}

local function CopyYoutubeLink()
    StaticPopup_Hide("HIRONCRAFT_PROFIT_COPY_BOT_LINK")
    StaticPopup_Show("HIRONCRAFT_PROFIT_COPY_YOUTUBE_LINK")
end

local function CopyBotLink()
    StaticPopup_Hide("HIRONCRAFT_PROFIT_COPY_YOUTUBE_LINK")
    StaticPopup_Show("HIRONCRAFT_PROFIT_COPY_BOT_LINK")
end

local function GetAddonVersion()
    return C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "0.0.0"
end

local function ParseVersion(v)
    local a,b,c,d = string.match(v, "(%d+)%.(%d+)%.?(%d*)%.?(%d*)")
    return tonumber(a) or 0,
           tonumber(b) or 0,
           tonumber(c) or 0,
           tonumber(d) or 0
end

local function IsVersionGreater(a, b)
    local a1,a2,a3,a4 = ParseVersion(a)
    local b1,b2,b3,b4 = ParseVersion(b)

    if a1 ~= b1 then return a1 > b1 end
    if a2 ~= b2 then return a2 > b2 end
    if a3 ~= b3 then return a3 > b3 end
    return a4 > b4
end

local CATEGORY_STYLES = {
    NEW      = "|cff3cff00[NEW]|r ",
    FIX      = "|cffff3c3c[FIX]|r ",
    IMPROVED = "|cff00bfff[IMPROVED]|r ",
    CHANGED  = "|cffffa500[CHANGED]|r ",
}

local CHANGELOG = {
    ["2.0.0"] = {

        {
            type = "CHANGED",
            ru = "HironCraftProfit -> HironCraft: аддон переезжает на новое имя HironCraft и разбивается на модули (кор + дополнения). Настройки и данные переносятся автоматически.",
            en = "HironCraftProfit -> HironCraft: the addon is moving to the new name HironCraft and is being split into modules (core + add-ons). Your settings and data are migrated automatically.",
        },
    },
}

local function BuildFullChangelog()

    local versions = {}

    for v in pairs(CHANGELOG) do
        table.insert(versions, v)
    end

    table.sort(versions, function(a,b)
        return IsVersionGreater(a,b)
    end)

    local result = ""

    for _, version in ipairs(versions) do

        result = result ..
            "|cffFFD100VERSION " .. version .. "|r\n\n"

        for _, entry in ipairs(CHANGELOG[version]) do

            local tag = entry.type ~= "" and CATEGORY_STYLES[entry.type] or ""

            result = result ..
                tag .. "|cffFFFFFF" .. entry.ru .. "|r\n" ..
                tag .. "|cffaaaaaa" .. entry.en .. "|r\n\n"
        end

        result = result .. "\n"
    end

    return result
end

function WhatsNew:Create()
    if self.frame then return self.frame end

    HironCraftProfit_DB = HironCraftProfit_DB or {}

    local f = CreateFrame("Frame", "HironCraftProfitWhatsNewFrame", UIParent, "BackdropTemplate")
    f:SetSize(520, 520)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")

    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 3,
    })

    f:SetBackdropColor(0,0,0,0.95)
    f:SetBackdropBorderColor(0.694, 0.612, 0.851, 1)

    f:Hide()
    if HironCraftProfit.RegisterEscClose then HironCraftProfit:RegisterEscClose(f) end

    local logo = f:CreateTexture(nil, "ARTWORK")
    logo:SetSize(165, 128)
    logo:SetPoint("TOP",0,-18)
    logo:SetTexture("Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\media\\logo.png")

    local title = f:CreateFontString(nil,"OVERLAY")
    title:SetFont(FONT,16,"OUTLINE")
    title:SetPoint("TOP",logo,"BOTTOM",0,-10)
    title:SetText("What's New?")

    local scrollFrame = CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",40,-180)
    scrollFrame:SetPoint("BOTTOMRIGHT",-40,105)

    local content = CreateFrame("Frame",nil,scrollFrame)
    content:SetSize(420,1200)
    scrollFrame:SetScrollChild(content)

    local text = content:CreateFontString(nil,"OVERLAY")
    text:SetFont(FONT,14,"")
    text:SetPoint("TOPLEFT")
    text:SetWidth(400)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetWordWrap(true)

    text:SetText(BuildFullChangelog())

    local youtubeBtn = CreateFrame("Button", nil, f)
    youtubeBtn:SetSize(420, 22)
    youtubeBtn:SetPoint("BOTTOM", 0, 76)

    local youtubeText = youtubeBtn:CreateFontString(nil, "OVERLAY")
    youtubeText:SetFont(FONT, 12, "")
    youtubeText:SetPoint("CENTER")
    youtubeText:SetText("|cff00ccffYouTube: " .. YOUTUBE_LINK .. "|r")

    local youtubeHover = youtubeBtn:CreateTexture(nil, "BACKGROUND")
    youtubeHover:SetAllPoints()
    youtubeHover:SetTexture("Interface\\Buttons\\WHITE8x8")
    youtubeHover:SetColorTexture(1, 1, 1, 0)

    youtubeBtn:SetScript("OnEnter", function(self)
        youtubeHover:SetColorTexture(1, 1, 1, 0.08)
        youtubeText:SetText("|cff66ddffYouTube: " .. YOUTUBE_LINK .. "|r")

        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Click to copy link", 1, 1, 1)
        GameTooltip:AddLine(YOUTUBE_LINK, 0, 0.8, 1)
        GameTooltip:Show()
    end)

    youtubeBtn:SetScript("OnLeave", function()
        youtubeHover:SetColorTexture(1, 1, 1, 0)
        youtubeText:SetText("|cff00ccffYouTube: " .. YOUTUBE_LINK .. "|r")
        GameTooltip:Hide()
    end)

    youtubeBtn:SetScript("OnClick", function()
        CopyYoutubeLink()
    end)


    local botBtn = CreateFrame("Button", nil, f)
    botBtn:SetSize(420, 22)
    botBtn:SetPoint("BOTTOM", 0, 52)

    local botText = botBtn:CreateFontString(nil, "OVERLAY")
    botText:SetFont(FONT, 12, "")
    botText:SetPoint("CENTER")
    botText:SetText("|cff00ccffFDiscord: " .. BOT_LINK .. "|r")

    local botHover = botBtn:CreateTexture(nil, "BACKGROUND")
    botHover:SetAllPoints()
    botHover:SetTexture("Interface\\Buttons\\WHITE8x8")
    botHover:SetColorTexture(1, 1, 1, 0)

    botBtn:SetScript("OnEnter", function(self)
        botHover:SetColorTexture(1, 1, 1, 0.08)
        botText:SetText("|cff66ddffDiscord: " .. BOT_LINK .. "|r")

        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Click to copy link", 1, 1, 1)
        GameTooltip:AddLine(BOT_LINK, 0, 0.8, 1)
        GameTooltip:Show()
    end)

    botBtn:SetScript("OnLeave", function()
        botHover:SetColorTexture(1, 1, 1, 0)
        botText:SetText("|cff00ccffDiscord: " .. BOT_LINK .. "|r")
        GameTooltip:Hide()
    end)

    botBtn:SetScript("OnClick", function()
        CopyBotLink()
    end)

    local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btn:SetSize(140,26)
    btn:SetPoint("BOTTOM",0,20)
    btn:SetText("Close")

    local fs = btn:GetFontString()
    if fs then fs:SetFont(FONT,13,"") end

    btn:SetScript("OnClick", function()
        HironCraftProfit_DB.lastShownVersion = GetAddonVersion()
        f:Hide()
    end)

    self.frame = f
    return f
end

function WhatsNew:Show()
    self:Create():Show()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    HironCraftProfit_DB = HironCraftProfit_DB or {}

    local current = GetAddonVersion()
    local last    = HironCraftProfit_DB.lastShownVersion

    if not last or last == "" then
        HironCraftProfit_DB.lastShownVersion = current
        return
    end

    if IsVersionGreater(current, last) then
        C_Timer.After(0.8, function()
            WhatsNew:Show()
        end)
    end
end)

SLASH_HIRONCRAFT_PROFITWHATSNEW1 = "/phwhatsnew"
SLASH_HIRONCRAFT_PROFITWHATSNEW2 = "/phwn"
SLASH_HIRONCRAFT_PROFITWHATSNEW3 = "/ahuiwhatsnew"
SLASH_HIRONCRAFT_PROFITWHATSNEW4 = "/ahwn"

SlashCmdList["HIRONCRAFT_PROFITWHATSNEW"] = function()
    WhatsNew:Show()
end
