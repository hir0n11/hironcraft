local PT = HironCraftProfit
local L = PT.L
PT.ConfirmButtons = PT.ConfirmButtons or {}
local M = PT.ConfirmButtons

local BUTTON_CONFIG_KEYS = { "confirmOK", "confirmReload", "confirmButtonStyle", "confirmAuctionator", "confirmReloadSize" }

function M:IsButtonsPerChar()
    return HironCraftProfit_CharConfig and HironCraftProfit_CharConfig.buttonsPerChar == true
end

function M:GetButtonsConfig()
    if HironCraftProfit_CharConfig and HironCraftProfit_CharConfig.buttonsPerChar then
        HironCraftProfit_CharConfig.buttons = HironCraftProfit_CharConfig.buttons or {}
        return HironCraftProfit_CharConfig.buttons
    end
    PT.config = PT.config or {}
    return PT.config
end

function M:SetButtonsPerChar(enabled)
    HironCraftProfit_CharConfig = HironCraftProfit_CharConfig or {}
    enabled = enabled == true
    if (HironCraftProfit_CharConfig.buttonsPerChar == true) == enabled then return end

    local from = self:GetButtonsConfig()
    HironCraftProfit_CharConfig.buttonsPerChar = enabled or nil
    local to = self:GetButtonsConfig()
    if to ~= from then
        for _, k in ipairs(BUTTON_CONFIG_KEYS) do
            if to[k] == nil then to[k] = from[k] end
        end
    end

    self:RefreshButtonsFromConfig()
end

local function BCFG()
    return M:GetButtonsConfig()
end

local MEDIA = "Interface\\AddOns\\HironCraft\\ProfitHub\\Buttons\\media\\"

M.STYLES = {
    default = {
        name   = L["CONFIRM_STYLE_DEFAULT"],
        ok     = MEDIA .. "confirm_ok.tga",
        reload = MEDIA .. "confirm_reload.tga",
    },
    horde = {
        name   = L["CONFIRM_STYLE_HORDE"],
        ok     = MEDIA .. "horde\\confirm_ok.tga",
        reload = MEDIA .. "horde\\confirm_reload.tga",
    },
    alliance = {
        name   = L["CONFIRM_STYLE_ALLIANCE"],
        ok     = MEDIA .. "alliance\\confirm_ok.tga",
        reload = MEDIA .. "alliance\\confirm_reload.tga",
    },
    midnight = {
        name   = L["CONFIRM_STYLE_MIDNIGHT"],
        ok     = MEDIA .. "midnight\\confirm_ok.tga",
        reload = MEDIA .. "midnight\\confirm_reload.tga",
    },
}

-- Themed skin sets: media\<key>\<key>_ok.tga / <key>_reload.tga
local THEMES = {
    { key = "MLP",        name = L["CONFIRM_STYLE_MLP"]        or "MLP" },
    { key = "sovet",      name = L["CONFIRM_STYLE_SOVET"]      or "Soviet" },
    { key = "druid",      name = L["CONFIRM_STYLE_DRUID"]      or "Druid" },
    { key = "murloc",     name = L["CONFIRM_STYLE_MURLOC"]     or "Murloc" },
    { key = "d4",         name = L["CONFIRM_STYLE_D4"]         or "Diablo IV" },
    { key = "summer",     name = L["CONFIRM_STYLE_SUMMER"]     or "Summer" },
    { key = "minecraft",  name = L["CONFIRM_STYLE_MINECRAFT"]  or "Minecraft" },
    { key = "maldraxxus", name = L["CONFIRM_STYLE_MALDRAXXUS"] or "Maldraxxus" },
    { key = "midnight2",  name = L["CONFIRM_STYLE_MIDNIGHT2"]  or "Midnight 2" },
    { key = "dog",        name = L["CONFIRM_STYLE_DOG"]        or "Dog" },
    { key = "hearthstone",name = L["CONFIRM_STYLE_HEARTHSTONE"] or "Hearthstone" },
}

for _, t in ipairs(THEMES) do
    M.STYLES[t.key] = {
        name   = t.name,
        ok     = MEDIA .. t.key .. "\\" .. t.key .. "_ok.tga",
        reload = MEDIA .. t.key .. "\\" .. t.key .. "_reload.tga",
    }
end

M.EXCLUDED_POPUPS = {
    ADDON_ACTION_FORBIDDEN = true,
    ADD_GUILDMEMBER_WITH_FINDER_LINK = true,
    HIRONCRAFT_PROFIT_COPY_LINK = true,
    AREA_SPIRIT_HEAL = true,
    CAMP = true,
    CMC_RELOAD_UI_ASK = true,
    CONFIRM_BATTLEFIELD_ENTRY = true,
    CONFIRM_BUY_BANK_TAB = true,
    CONFIRM_BUY_OUTFIT_SLOT = true,
    CONFIRM_GUILD_LEAVE = true,
    CONFIRM_GUILD_PROMOTE = true,
    CONFIRM_LEAVE_AND_DESTROY_COMMUNITY = true,
    CONFIRM_LEAVE_BATTLEFIELD = true,
    CONFIRM_LEAVE_COMMUNITY = true,
    CONFIRM_LEAVE_RESTRICTED_CHALLENGE_MODE = true,
    CONFIRM_SUMMON = true,
    CONFIRM_UNLEARN_AND_SWITCH_TALENT = true,
    CONFIRM_UPGRADE_ITEM = true,
    DEATH = true,
    END_BOUND_TRADEABLE = true,
    EQUIP_BIND_TRADEABLE = true,
    GAME_SETTINGS_APPLY_DEFAULTS = true,
    GUILD_INVITE = true,
    INSTANCE_BOOT = true,
    ITEM_INTERACTION_CONFIRMATION_DELAYED = true,
    KEYSTONE_DESERTER_NOTIFICATION = true,
    PARTY_INVITE = true,
    QUIT = true,
    RECOVER_CORPSE = true,
    REPLACE_ENCHANT = true,
    REPLACE_TRADESKILL_ENCHANT = true,
    RESURRECT = true,
    RESURRECT_NO_SICKNESS = true,
    RESURRECT_NO_TIMER = true,
    SET_GUILD_COMMUNITIY_NOTE = true,
    SPELL_CONFIRMATION_PROMPT = true,
    SPELL_CONFIRMATION_PROMPT_ALERT = true,
    TRADE_REPLACE_ENCHANT = true,
    USE_BIND = true,
    USE_NO_REFUND_CONFIRM = true,
    VOTE_ABANDON_INSTANCE_VOTE = true,
    VOTE_ABANDON_INSTANCE_WAIT = true,
    VOTE_BOOT_PLAYER = true,
}

local function DebugPrint(...)
    if not debugPopupsRuntime then return end
    print("|cffffd700[HironCraft Confirm]|r", ...)
end

function M:SetDebugEnabled(v)
    debugPopupsRuntime = v and true or false

    if debugPopupsRuntime then
        print("|cffffd700HironCraft Confirm:|r popup debug |cff00ff00enabled|r")
    else
        print("|cffffd700HironCraft Confirm:|r popup debug |cffff4040disabled|r")
    end
end

function M:IsDebugEnabled()
    return debugPopupsRuntime == true
end

local okBtn, okText
local reloadBar
local currentPopup
local okEnabledRuntime = false
local escCatcher
local debugPopupsRuntime = false
local auctionatorDialogFrame
local auctionatorDialogAction
local auctionatorHooksInstalled = false

local function EnsureDB()
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB.confirmUserExcludedPopups =
        HironCraftProfit_DB.confirmUserExcludedPopups or {}

    HironCraftProfit_CharConfig = HironCraftProfit_CharConfig or {}

    local c = M:GetButtonsConfig()
    if M:IsButtonsPerChar() and PT.config then
        for _, k in ipairs(BUTTON_CONFIG_KEYS) do
            if c[k] == nil then c[k] = PT.config[k] end
        end
    end
    c.confirmOK = c.confirmOK ~= false
    c.confirmReload = c.confirmReload ~= false
    c.confirmButtonStyle = c.confirmButtonStyle or "default"
    c.confirmAuctionator = c.confirmAuctionator == true
    c.confirmReloadSize = tonumber(c.confirmReloadSize) or 50
end

local RELOAD_MIN, RELOAD_MAX, RELOAD_DEFAULT = 24, 160, 50

function M:IsSystemExcluded(which)
    return which and M.EXCLUDED_POPUPS[which] == true
end

function M:IsUserExcluded(which)
    EnsureDB()
    return which and HironCraftProfit_DB.confirmUserExcludedPopups
        and HironCraftProfit_DB.confirmUserExcludedPopups[which] == true
end

function M:IsExcluded(which)
    if not which then return true end
    if M:IsSystemExcluded(which) then return true end
    if M:IsUserExcluded(which) then return true end
    return false
end

function M:AddUserExcludedPopup(which)
    EnsureDB()

    if type(which) ~= "string" then return false end
    which = strtrim(which)
    if which == "" then return false end

    HironCraftProfit_DB.confirmUserExcludedPopups[which] = true
    return true
end

function M:RemoveUserExcludedPopup(which)
    EnsureDB()

    if type(which) ~= "string" then return false end
    which = strtrim(which)
    if which == "" then return false end

    HironCraftProfit_DB.confirmUserExcludedPopups[which] = nil
    return true
end

function M:ResetUserExcludedPopups()
    EnsureDB()
    HironCraftProfit_DB.confirmUserExcludedPopups = {}
    print(L["CONFIRM_RESET_OK"])
end

function M:GetUserExcludedPopupList()
    EnsureDB()

    local list = {}
    for which in pairs(HironCraftProfit_DB.confirmUserExcludedPopups or {}) do
        table.insert(list, which)
    end

    table.sort(list)
    return list
end

local function NormalizePopupText(text)
    if type(text) ~= "string" then
        return nil
    end

    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("\n", " ")
    text = text:gsub("%%.-[sd]", " ")
    text = text:gsub("%s+", " ")
    text = strtrim(text)

    if text == "" then
        return nil
    end

    return text:lower()
end

local function SplitSearchWords(text)
    local words = {}
    text = NormalizePopupText(text)
    if not text then
        return words
    end

    for word in text:gmatch("%S+") do
        if #word >= 4 then
            table.insert(words, word)
        end
    end

    return words
end

function M:FindPopupByText(searchText)
    local needle = NormalizePopupText(searchText)
    if not needle then
        print("|cffffd700HironCraft:|r /findpopup text")
        return
    end

    local words = SplitSearchWords(searchText)
    local results = {}

    for which, dialog in pairs(StaticPopupDialogs or {}) do
        local text = dialog and dialog.text

        if type(text) == "function" then
            local ok, result = pcall(text)
            if ok then
                text = result
            else
                text = nil
            end
        end

        text = NormalizePopupText(text)

        if text then
            local score = 0

            if text:find(needle, 1, true) then
                score = score + 100
            end

            for _, word in ipairs(words) do
                if text:find(word, 1, true) then
                    score = score + 1
                end
            end

            if score > 0 then
                table.insert(results, {
                    which = which,
                    text = text,
                    score = score,
                })
            end
        end
    end

    table.sort(results, function(a, b)
        if a.score == b.score then
            return a.which < b.which
        end
        return a.score > b.score
    end)

    if #results == 0 then
        print("|cffffd700HironCraft:|r no popup match found")
        return
    end

    print("|cffffd700HironCraft popup search:|r " .. needle)

    local limit = math.min(#results, 10)
    for i = 1, limit do
        local r = results[i]
        print("|cffffd700HironCraft popup:|r |cff00ff00" .. r.which .. "|r -> " .. r.text)
    end
end

SLASH_HIRONCRAFT_PROFITOKEXCLUDE1 = "/ahuiokexclude"
SlashCmdList.HIRONCRAFT_PROFITOKEXCLUDE = function(msg)
    msg = strtrim(msg or "")
    if msg == "" then
        print("|cffffd700HironCraft:|r /ahuiokexclude POPUP_NAME")
        return
    end

    if M:AddUserExcludedPopup(msg) then
        print("|cffffd700HironCraft:|r added popup exclusion |cff00ff00" .. msg .. "|r")
    end
end

SLASH_HIRONCRAFT_PROFITOKUNEXCLUDE1 = "/ahuiokunexclude"
SlashCmdList.HIRONCRAFT_PROFITOKUNEXCLUDE = function(msg)
    msg = strtrim(msg or "")
    if msg == "" then
        print("|cffffd700HironCraft:|r /ahuiokunexclude POPUP_NAME")
        return
    end

    if M:RemoveUserExcludedPopup(msg) then
        print("|cffffd700HironCraft:|r removed popup exclusion |cff00ff00" .. msg .. "|r")
    end
end

SLASH_HIRONCRAFT_PROFITPOPUPFIND1 = "/findpopup"
SlashCmdList.HIRONCRAFT_PROFITPOPUPFIND = function(msg)
    M:FindPopupByText(msg)
end

SLASH_HIRONCRAFT_PROFITCONFIRMDEBUG1 = "/ahuiconfirmdebug"
SLASH_HIRONCRAFT_PROFITCONFIRMDEBUG2 = "/acdebug"

SlashCmdList.HIRONCRAFT_PROFITCONFIRMDEBUG = function(msg)
    msg = strtrim((msg or ""):lower())

    if msg == "1" or msg == "on" or msg == "enable" then
        M:SetDebugEnabled(true)
    elseif msg == "0" or msg == "off" or msg == "disable" then
        M:SetDebugEnabled(false)
    elseif msg == "toggle" or msg == "" then
        M:SetDebugEnabled(not M:IsDebugEnabled())
    else
        print("|cffffd700HironCraft:|r /ahuiconfirmdebug on|off|toggle")
    end
end

local function EnsureEscCatcher()
    if escCatcher then return end

    escCatcher = CreateFrame("Frame", "HironCraftProfit_OK_ESC_Catcher", UIParent)
    escCatcher:Hide()

    tinsert(UISpecialFrames, escCatcher:GetName())
end

function M:GetActiveStyle()
    EnsureDB()
    local key = BCFG().confirmButtonStyle or "default"
    return M.STYLES[key] or M.STYLES.default
end

function M:ApplyStyleToButton(frame, kind)
    if not frame or not frame.icon then return end
    local style = M:GetActiveStyle()
    local tex = (kind == "ok") and style.ok or style.reload
    if not tex then return end
    frame.icon:SetTexture(tex)
    frame.icon:SetTexCoord(0, 1, 0, 1)
    frame.icon:SetAlpha(1)
    frame.icon:Show()
end

function M:ApplyStyle()
    if okBtn then M:ApplyStyleToButton(okBtn, "ok") end
    if reloadBar then M:ApplyStyleToButton(reloadBar, "reload") end
end

function M:RefreshButtonsFromConfig()
    EnsureDB()
    local c = M:GetButtonsConfig()
    M:SetReloadSize(c.confirmReloadSize)
    M:SetOKEnabled(c.confirmOK ~= false)
    M:SetReloadEnabled(c.confirmReload ~= false)
    M:SetAuctionatorEnabled(c.confirmAuctionator == true)
    M:ApplyStyle()
end

function M:IsOKEnabled()
    return BCFG().confirmOK == true
end

function M:IsReloadEnabled()
    return BCFG().confirmReload == true
end

function M:SetOKEnabled(v)
    if v then
        M:EnableOK()
    else
        M:DisableOK()
    end
end

function M:SetReloadEnabled(v)
    if v then
        M:ShowReload()
    else
        M:HideReload()
    end
end

function M:ResetOKExclusions()
    M:ResetUserExcludedPopups()
end

function M:GetPopupList()
    return M:GetUserExcludedPopupList()
end

function M:GetPopupLabel(which)
    if not which then return "" end

    local dialog = StaticPopupDialogs and StaticPopupDialogs[which]
    if dialog and type(dialog.text) == "string" then
        local text = dialog.text

        text = text:gsub("\n", " ")
        text = text:gsub("%%.-[sd]", "...")
        text = text:gsub("%s+", " ")

        if #text > 70 then
            text = text:sub(1, 67) .. "..."
        end

        return text
    end

    return which
end

function M:GetPopupFullText(which)
    if not which then return "" end

    local dialog = StaticPopupDialogs and StaticPopupDialogs[which]
    if not dialog then return which end

    local text = dialog.text

    if type(text) == "function" then
        local ok, result = pcall(text)
        if ok and type(result) == "string" then
            text = result
        else
            return which
        end
    end

    if type(text) ~= "string" then
        return which
    end

    return text
end

function M:IsPopupEnabled(which)
    return not M:IsExcluded(which)
end

function M:SetPopupEnabled(which, enabled)
    EnsureDB()
    if not which then return end

    if enabled then
        if not M:IsSystemExcluded(which) then
            HironCraftProfit_DB.confirmUserExcludedPopups[which] = nil
        end
    else
        if not M:IsSystemExcluded(which) then
            HironCraftProfit_DB.confirmUserExcludedPopups[which] = true
        end
    end
end

local function ShouldExclude(which)
    return M:IsExcluded(which)
end

local function CreateOKButton()
    if okBtn then return okBtn end

    local b = CreateFrame("Button", "HironCraftProfit_OKConfirmButton", UIParent, "BackdropTemplate")
    b:SetSize(44, 44)
    b:SetFrameStrata("TOOLTIP")
    b:SetFrameLevel(1000)
    b:Hide()

    b:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        tile = true, tileSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    b:SetBackdropColor(0, 0, 0, 0)

    b.icon = b:CreateTexture(nil, "OVERLAY")
    b.icon:SetAllPoints()

    okText = b:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontNormal")
    okText:SetPoint("CENTER")

    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    b:SetScript("OnClick", function(self, mouseButton)
        if auctionatorDialogFrame and auctionatorDialogFrame:IsShown() then
            if mouseButton == "RightButton" then
                auctionatorDialogFrame:Hide()

                self:Hide()
                if escCatcher then escCatcher:Hide() end
                currentPopup = nil
                auctionatorDialogFrame = nil
                auctionatorDialogAction = nil
                return
            end

            if auctionatorDialogAction
               and type(auctionatorDialogFrame[auctionatorDialogAction]) == "function"
            then
                auctionatorDialogFrame[auctionatorDialogAction](auctionatorDialogFrame)
            end

            self:Hide()
            if escCatcher then escCatcher:Hide() end
            currentPopup = nil
            auctionatorDialogFrame = nil
            auctionatorDialogAction = nil
            return
        end

        if not currentPopup then return end

        local popupName = currentPopup:GetName()

        if mouseButton == "RightButton" then
            local cancel = _G[popupName .. "Button2"] or currentPopup.button2

            if cancel and cancel:IsShown() then
                cancel:Click()
            end

            self:Hide()
            currentPopup = nil
            return
        end

        if not currentPopup.button1 then return end

        local editBox = _G[popupName .. "EditBox"]
        if editBox then
            local locale = GetLocale()
            if currentPopup.which == "DELETE_GOOD_ITEM"
            or currentPopup.which == "DELETE_GOOD_QUEST_ITEM" then
                editBox:SetText(DELETE_ITEM_CONFIRM_STRING
                    or (locale == "ruRU" and "удалить" or "DELETE"))
            elseif currentPopup.which == "UNLEARN_SKILL" then
                editBox:SetText(locale == "ruRU" and "забыть" or "unlearn")
            end
        end

        currentPopup.button1:Click()

        self:Hide()
        currentPopup = nil
    end)

    b:SetScript("OnUpdate", function(self)
        if not self:IsShown() then return end

        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()

        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    end)

    okBtn = b
    M:ApplyStyle()
    return b
end

local function ShowOKUnderCursor()
    if not okBtn then CreateOKButton() end
    EnsureEscCatcher()
    escCatcher:Show()
    okBtn:Show()
end

local function HideOK()
    if okBtn then okBtn:Hide() end
    if escCatcher then escCatcher:Hide() end
    currentPopup = nil
    auctionatorDialogFrame = nil
    auctionatorDialogAction = nil
end

local function IsAuctionatorEnabled()
    return BCFG().confirmAuctionator == true
end

local function ShowAuctionatorConfirm(dialog, action)
    if not okEnabledRuntime then return end
    if not IsAuctionatorEnabled() then return end
    if not dialog or not dialog:IsShown() then return end

    currentPopup = nil
    auctionatorDialogFrame = dialog
    auctionatorDialogAction = action
    ShowOKUnderCursor()
end

local function HookAuctionatorDialog(dialog, action)
    if not dialog or dialog.__HironCraftProfitHooked then return end
    dialog.__HironCraftProfitHooked = true

    dialog:HookScript("OnShow", function(self)
        ShowAuctionatorConfirm(self, action)
    end)

    dialog:HookScript("OnHide", function(self)
        if auctionatorDialogFrame == self then
            HideOK()
        end
    end)
end

function M:TryHookAuctionator(attempt)
    attempt = attempt or 0

    if auctionatorHooksInstalled then
        return true
    end

    if not AuctionatorBuyItemFrame or not AuctionatorBuyCommodityFrame then
        if attempt < 10 then
            C_Timer.After(0.2, function()
                M:TryHookAuctionator(attempt + 1)
            end)
        end
        return false
    end

    HookAuctionatorDialog(AuctionatorBuyItemFrame.BuyDialog, "BuyClicked")
    HookAuctionatorDialog(AuctionatorBuyCommodityFrame.FinalConfirmationDialog, "ConfirmPurchase")
    HookAuctionatorDialog(AuctionatorBuyCommodityFrame.QuantityCheckConfirmationDialog, "ConfirmPurchase")
    HookAuctionatorDialog(AuctionatorBuyCommodityFrame.WidePriceRangeWarningDialog, "StartPurchase")

    auctionatorHooksInstalled = true
    return true
end

function M:SetAuctionatorEnabled(v)
    EnsureDB()
    BCFG().confirmAuctionator = (v == true)

    if BCFG().confirmAuctionator then
        M:TryHookAuctionator(0)
    elseif auctionatorDialogFrame then
        HideOK()
    end
end

local function TryAutoFillConfirmText(popup, which)
    local editBox = _G[popup:GetName() .. "EditBox"]
    if not editBox then return end

    local locale = GetLocale()

    if which == "DELETE_GOOD_ITEM"
    or which == "DELETE_GOOD_QUEST_ITEM" then
        editBox:SetText(DELETE_ITEM_CONFIRM_STRING
            or (locale == "ruRU" and "удалить" or "DELETE"))
    elseif which == "UNLEARN_SKILL" then
        editBox:SetText(locale == "ruRU" and "забыть" or "unlearn")
    end
end

local function FindVisiblePopupByWhich(which)
    local numDialogs = STATICPOPUP_NUMDIALOGS or 4

    for i = 1, numDialogs do
        local popup = _G["StaticPopup" .. i]
        if popup and popup:IsShown() and popup.which == which then
            return popup
        end
    end
end

local function TryShowForPopup(which, attempt)
    if not okEnabledRuntime then return end
    if not which then return end
    if ShouldExclude(which) then return end

    attempt = attempt or 0

    local popup = FindVisiblePopupByWhich(which) or StaticPopup_FindVisible(which)
    local button1 = popup and (_G[popup:GetName() .. "Button1"] or popup.button1)

    if not (popup and popup:IsShown() and button1) then
        if attempt < 5 then
            C_Timer.After(0, function()
                TryShowForPopup(which, attempt + 1)
            end)
        end
        return
    end

    if not button1.__HironCraftProfitEnableHooked then
        button1.__HironCraftProfitEnableHooked = true
        hooksecurefunc(button1, "Enable", function()
            if okEnabledRuntime and currentPopup == popup and popup:IsShown() then
                ShowOKUnderCursor()
            end
        end)
    end

    currentPopup = popup
    currentPopup.which = which
    currentPopup.button1 = button1

    TryAutoFillConfirmText(popup, which)
    ShowOKUnderCursor()
end

hooksecurefunc("StaticPopup_Show", function(which)
    EnsureDB()
    if not BCFG().confirmOK then return end

    if not M.EXCLUDED_POPUPS[which] then
        DebugPrint("Popup: |cff00ff00" .. tostring(which) .. "|r")
    end

    TryShowForPopup(which)
end)

hooksecurefunc("StaticPopupSpecial_Show", function(frame)
    EnsureDB()
    if not BCFG().confirmOK then return end
    if not frame then return end

    DebugPrint("Special popup: |cff00ff00" .. tostring(frame.which) .. "|r")

    TryShowForPopup(frame.which or "UNKNOWN")
end)

hooksecurefunc("StaticPopup_Hide", function(which)
    if currentPopup and currentPopup.which == which then
        HideOK()
    end
end)

function M:EnableOK()
    EnsureDB()
    okEnabledRuntime = true
    CreateOKButton()
    M:ApplyStyle()
end

function M:DisableOK()
    okEnabledRuntime = false
    HideOK()
end

local function SaveReloadPos()
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB.positions = HironCraftProfit_DB.positions or {}

    local point, _, relPoint, x, y = reloadBar:GetPoint()
    HironCraftProfit_DB.positions.reload = {
        point = point,
        relPoint = relPoint,
        x = x,
        y = y,
    }
end

local function LoadReloadPos()
    reloadBar:ClearAllPoints()

    if HironCraftProfit_DB
       and HironCraftProfit_DB.positions
       and HironCraftProfit_DB.positions.reload
    then
        local p = HironCraftProfit_DB.positions.reload
        reloadBar:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
    else
        reloadBar:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
    end
end

local function CreateReload()
    if reloadBar then return reloadBar end

    local b = CreateFrame("Button", "HironCraftProfit_ReloadButton", UIParent, "BackdropTemplate")
    local sz = tonumber(BCFG().confirmReloadSize) or RELOAD_DEFAULT
    b:SetSize(sz, sz)
    b:SetFrameStrata("TOOLTIP")
    b:SetFrameLevel(900)
    b:SetMovable(true)
    b:SetClampedToScreen(true)

    b:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        tile = true, tileSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    b:SetBackdropColor(0, 0, 0, 0)

    b.icon = b:CreateTexture(nil, "OVERLAY")
    b.icon:SetAllPoints()

    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", b.StartMoving)
    b:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveReloadPos()
    end)

    b:SetScript("OnClick", ReloadUI)

    reloadBar = b
    LoadReloadPos()
    M:ApplyStyle()
    return b
end

function M:GetReloadSize()
    EnsureDB()
    return tonumber(BCFG().confirmReloadSize) or RELOAD_DEFAULT
end

function M:SetReloadSize(size)
    EnsureDB()
    size = tonumber(size) or RELOAD_DEFAULT
    size = math.max(RELOAD_MIN, math.min(RELOAD_MAX, math.floor(size + 0.5)))
    BCFG().confirmReloadSize = size
    if reloadBar then reloadBar:SetSize(size, size) end
    return size
end

function M:ShowReload()
    EnsureDB()
    CreateReload():Show()
end

function M:HideReload()
    if reloadBar then reloadBar:Hide() end
end

local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:RegisterEvent("ADDON_LOADED")
init:RegisterEvent("AUCTION_HOUSE_SHOW")

init:SetScript("OnEvent", function(_, event, addonName)
    if event == "PLAYER_LOGIN" then
        EnsureDB()

        if BCFG().confirmOK then
            M:EnableOK()
        else
            M:DisableOK()
        end

        if BCFG().confirmReload then
            M:ShowReload()
        else
            M:HideReload()
        end

        if BCFG().confirmAuctionator then
            M:TryHookAuctionator(0)
        end

        M:ApplyStyle()

    elseif event == "ADDON_LOADED" and addonName == "Auctionator" then
        if BCFG().confirmAuctionator then
            C_Timer.After(0, function()
                M:TryHookAuctionator(0)
            end)
        end

    elseif event == "AUCTION_HOUSE_SHOW" then
        if BCFG().confirmAuctionator then
            C_Timer.After(0, function()
                M:TryHookAuctionator(0)
            end)
        end
    end
end)