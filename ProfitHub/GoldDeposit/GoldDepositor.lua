local PT = HironCraftProfit
if not PT then return end

PT.GoldDepositor = PT.GoldDepositor or {}
local GD = PT.GoldDepositor

local Tooltip = PT.Tooltip
local FONT = PT.FONT or "Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\fonts\\default.ttf"
local L = PT.L or {}

local function T(key, default, ruDefault)
    if L[key] then
        return L[key]
    end

    if ruDefault and GetLocale and GetLocale() == "ruRU" then
        return ruDefault
    end

    return default or key
end

if PT.config and not PT.config._forceEnableGoldDepositorV2 then
    PT.config._forceEnableGoldDepositorV2 = true
    PT.config.goldDepositorEnabled = true
end

local function IsModuleEnabled()
    return not (PT.config and PT.config.goldDepositorEnabled == false)
end


local ADDON_NAME = ... or "HironCraftProfit"

local DEFAULT_KEEP = 200
local BUTTON_SIZE = 44
local DEFAULT_POINT = "CENTER"
local DEFAULT_X = 0
local DEFAULT_Y = 0
local POSITION_VERSION = 1
local ACCOUNT_BANK_SIGNAL_GRACE = 2.0

local BANK_TYPE_GUILD = "guild"
local BANK_TYPE_ACCOUNT = "account"

local PREFIX = "|cff00ccff[" .. T("GD_TITLE", "Gold Depositor", "Депозит золота") .. "]|r"
local ERROR_PREFIX = "|cffff4444[" .. T("GD_TITLE", "Gold Depositor", "Депозит золота") .. "]|r"
local OK_PREFIX = "|cff00ff00[" .. T("GD_TITLE", "Gold Depositor", "Депозит золота") .. "]|r"

local KEY_COLOR = "|cffffd200"
local ON_COLOR = "|cff00ff00"
local OFF_COLOR = "|cffff4444"
local INFO_COLOR = "|cff00ccff"
local TEXT_COLOR = "|cffffffff"
local DIM_COLOR = "|cffaaaaaa"
local RESET_COLOR = "|r"

local button
local keepPopup
local settingsFrame
local depositInProgress = false
local autoDepositQueued = false
local autoDepositToken = 0
local bankSessionOpen = false
local currentBankType = nil
local lastBankSignalAt = 0
local accountBankHooksInstalled = false

local function Now()
    if GetTime then
        return GetTime()
    end

    return 0
end

local function Trim(value)
    value = value or ""

    if strtrim then
        return strtrim(value)
    end

    return tostring(value):match("^%s*(.-)%s*$") or ""
end

local function EnsureDB()
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB.goldDepositor = HironCraftProfit_DB.goldDepositor or {}

    local db = HironCraftProfit_DB.goldDepositor

    if not db._migratedStandalone then
        local legacy = rawget(_G, "GoldDepositorDB")

        if type(legacy) == "table" then
            if db.keepGold == nil and legacy.keepGold ~= nil then db.keepGold = legacy.keepGold end
            if db.autoDepositGuild == nil and legacy.autoDepositGuild ~= nil then db.autoDepositGuild = legacy.autoDepositGuild end
            if db.autoDepositAccount == nil and legacy.autoDepositAccount ~= nil then db.autoDepositAccount = legacy.autoDepositAccount end
            if db.buttonLocked == nil and legacy.buttonLocked ~= nil then db.buttonLocked = legacy.buttonLocked end
            if db.buttonPoint == nil and legacy.buttonPoint ~= nil then db.buttonPoint = legacy.buttonPoint end
            if db.buttonRelativePoint == nil and legacy.buttonRelativePoint ~= nil then db.buttonRelativePoint = legacy.buttonRelativePoint end
            if db.buttonX == nil and legacy.buttonX ~= nil then db.buttonX = legacy.buttonX end
            if db.buttonY == nil and legacy.buttonY ~= nil then db.buttonY = legacy.buttonY end
        end

        db._migratedStandalone = true
    end

    if db.keepGold == nil then db.keepGold = DEFAULT_KEEP end
    if db.autoDepositGuild == nil then db.autoDepositGuild = false end
    if db.autoDepositAccount == nil then db.autoDepositAccount = false end
    if db.buttonLocked == nil then db.buttonLocked = false end

    if db.buttonPositionVersion ~= POSITION_VERSION then
        db.buttonPoint = db.buttonPoint or DEFAULT_POINT
        db.buttonRelativePoint = db.buttonRelativePoint or db.buttonPoint or DEFAULT_POINT
        db.buttonX = db.buttonX or DEFAULT_X
        db.buttonY = db.buttonY or DEFAULT_Y
        db.buttonPositionVersion = POSITION_VERSION
    end

    db.rules = db.rules or {}
    db.ruleOrder = db.ruleOrder or {}
    db.characters = db.characters or {}

    if not db.rules.default then
        db.rules.default = {
            id = "default",
            name = T("GD_DEFAULT_RULE_NAME", "Default", "Базовое"),
            keepGold = db.keepGold or DEFAULT_KEEP,
            autoDepositGuild = db.autoDepositGuild == true,
            autoDepositAccount = db.autoDepositAccount == true,
            refill = false,
        }
    end

    local hasDefaultInOrder = false
    for _, ruleID in ipairs(db.ruleOrder) do
        if ruleID == "default" then
            hasDefaultInOrder = true
            break
        end
    end

    if not hasDefaultInOrder then
        table.insert(db.ruleOrder, 1, "default")
    end

    for i = #db.ruleOrder, 1, -1 do
        local ruleID = db.ruleOrder[i]
        if type(ruleID) ~= "string" or type(db.rules[ruleID]) ~= "table" then
            table.remove(db.ruleOrder, i)
        end
    end

    if #db.ruleOrder == 0 then
        db.ruleOrder[1] = "default"
    end

    db._ruleCounter = tonumber(db._ruleCounter) or 0

    return db
end

local function GetCharacterKey()
    local name = UnitName and UnitName("player")
    local realm = nil

    if GetNormalizedRealmName then
        realm = GetNormalizedRealmName()
    end

    if not realm or realm == "" then
        realm = GetRealmName and GetRealmName() or "UnknownRealm"
    end

    if not name or name == "" then
        name = "UnknownCharacter"
    end

    return tostring(name) .. "-" .. tostring(realm)
end

local function GetCharacterConfig()
    local db = EnsureDB()
    local key = GetCharacterKey()

    db.characters[key] = db.characters[key] or {}
    local cfg = db.characters[key]

    if cfg.ruleID == nil or not db.rules[cfg.ruleID] then
        cfg.ruleID = db.ruleOrder[1] or "default"
    end

    cfg.disabled = cfg.disabled == true

    return cfg, key
end

local function IsCharacterDepositDisabled()
    local cfg = GetCharacterConfig()
    return cfg and cfg.disabled == true
end

local function SetCharacterDepositDisabled(disabled)
    local cfg = GetCharacterConfig()
    cfg.disabled = disabled == true

    if cfg.disabled then
        autoDepositQueued = false
        autoDepositToken = autoDepositToken + 1
    end
end

local function GetRuleByID(ruleID)
    local db = EnsureDB()

    if type(ruleID) == "string" and db.rules[ruleID] then
        return db.rules[ruleID]
    end

    return db.rules.default or db.rules[db.ruleOrder[1]]
end

local function GetCurrentRuleID()
    local cfg = GetCharacterConfig()
    return cfg.ruleID or "default"
end

local function SetCurrentRuleID(ruleID)
    local db = EnsureDB()

    if not db.rules[ruleID] then
        return false
    end

    local cfg = GetCharacterConfig()
    cfg.ruleID = ruleID
    return true
end

local function GetCurrentRule()
    return GetRuleByID(GetCurrentRuleID())
end

local function GetCurrentKeepGold()
    local rule = GetCurrentRule()
    return tonumber(rule and rule.keepGold) or DEFAULT_KEEP
end

local function SetCurrentKeepGold(amount)
    local rule = GetCurrentRule()
    if not rule then return end

    rule.keepGold = tonumber(amount) or DEFAULT_KEEP

    local db = EnsureDB()
    if GetCurrentRuleID() == "default" then
        db.keepGold = rule.keepGold
    end
end

local function GetRuleDisplayName(rule)
    if not rule then
        return T("GD_NO", "none", "нет")
    end

    local name = Trim(rule.name or "")
    if name == "" then
        return T("GD_UNNAMED_RULE", "Unnamed rule", "Безымянное правило")
    end

    return name
end

local function NewRuleID(db)
    db._ruleCounter = (tonumber(db._ruleCounter) or 0) + 1
    return "rule_" .. tostring(db._ruleCounter)
end

local function GoldToCopper(gold)
    gold = tonumber(gold) or 0
    return math.floor(gold * 10000 + 0.5)
end

local function CopperToString(copper)
    copper = tonumber(copper) or 0

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperOnly = copper % 100

    return string.format("|cffffff00%dg|r |cffc0c0c0%ds|r |cffcd7f32%dc|r", gold, silver, copperOnly)
end

local function RunSoon(delay, callback)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay or 0, callback)
    else
        callback()
    end
end

local function SafeIsShown(frame)
    if not frame or type(frame.IsShown) ~= "function" then
        return false
    end

    local ok, shown = pcall(frame.IsShown, frame)
    return ok and shown
end

local function GetGuildBankerInteractionType()
    if Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.GuildBanker then
        return Enum.PlayerInteractionType.GuildBanker
    end

    return nil
end

local function GetAccountBankerInteractionType()
    if Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.AccountBanker then
        return Enum.PlayerInteractionType.AccountBanker
    end

    return nil
end

local function IsGuildBankerInteraction(interactionType)
    local guildBankerType = GetGuildBankerInteractionType()
    return guildBankerType ~= nil and interactionType == guildBankerType
end

local function IsAccountBankerInteraction(interactionType)
    local accountBankerType = GetAccountBankerInteractionType()
    return accountBankerType ~= nil and interactionType == accountBankerType
end

local function GetAccountBankType()
    if Enum and Enum.BankType and Enum.BankType.Account ~= nil then
        return Enum.BankType.Account
    end

    return 2
end

local function CanDepositAccountMoney()
    if not C_Bank or type(C_Bank.CanDepositMoney) ~= "function" then
        return false
    end

    local ok, canDeposit = pcall(C_Bank.CanDepositMoney, GetAccountBankType())
    return ok and canDeposit
end

local function IsAccountBankPanelShown()
    return SafeIsShown(_G.AccountBankPanel)
end

local function IsGuildBankFrameShown()
    return SafeIsShown(_G.GuildBankFrame)
end

local function GetCurrentBankType()
    if bankSessionOpen and currentBankType then
        if currentBankType == BANK_TYPE_GUILD then
            if IsGuildBankFrameShown() then
                return BANK_TYPE_GUILD
            end

            return nil
        end

        if currentBankType == BANK_TYPE_ACCOUNT then
            if IsAccountBankPanelShown()
               or CanDepositAccountMoney()
               or (Now() - (lastBankSignalAt or 0)) <= ACCOUNT_BANK_SIGNAL_GRACE
            then
                return BANK_TYPE_ACCOUNT
            end

            return nil
        end

        return currentBankType
    end

    if IsGuildBankFrameShown() then
        return BANK_TYPE_GUILD
    end

    if IsAccountBankPanelShown() then
        return BANK_TYPE_ACCOUNT
    end

    return nil
end

local function IsBankSessionOpen()
    return GetCurrentBankType() ~= nil
end

local function GetBankName(bankType)
    if bankType == BANK_TYPE_ACCOUNT then
        return T("GD_BANK_ACCOUNT", "Warband bank")
    end

    return T("GD_BANK_GUILD", "guild bank")
end

local function ResolveAutoBankType(arg)
    arg = Trim(arg):lower()

    if arg == "account" or arg == "warband" or arg == "warbank" or arg == "отряд" or arg == "отряда" or arg == "банкотряда" then
        return BANK_TYPE_ACCOUNT
    end

    if arg == "guild" or arg == "gbank" or arg == "guildbank" or arg == "гильд" or arg == "гильдбанк" or arg == "гильдейский" then
        return BANK_TYPE_GUILD
    end

    return GetCurrentBankType() or BANK_TYPE_GUILD
end

local function IsAutoDepositEnabled(bankType)
    local rule = GetCurrentRule()

    if not rule then
        return false
    end

    if bankType == BANK_TYPE_ACCOUNT then
        return rule.autoDepositAccount == true
    end

    return rule.autoDepositGuild == true
end

local function IsAutoDepositActive(bankType)
    return not IsCharacterDepositDisabled() and IsAutoDepositEnabled(bankType)
end

local function SetAutoDepositEnabled(bankType, enabled)
    local rule = GetCurrentRule()
    if not rule then return end

    if bankType == BANK_TYPE_ACCOUNT then
        rule.autoDepositAccount = enabled and true or false
    else
        rule.autoDepositGuild = enabled and true or false
    end

    local db = EnsureDB()
    if GetCurrentRuleID() == "default" then
        db.autoDepositGuild = rule.autoDepositGuild == true
        db.autoDepositAccount = rule.autoDepositAccount == true
    end
end

local function SaveButtonPosition()
    if not button then
        return
    end

    local point, _, relativePoint, x, y = button:GetPoint(1)
    local db = EnsureDB()

    db.buttonPoint = point or DEFAULT_POINT
    db.buttonRelativePoint = relativePoint or db.buttonPoint
    db.buttonX = x or DEFAULT_X
    db.buttonY = y or DEFAULT_Y
    db.buttonPositionVersion = POSITION_VERSION
end

local BANK_HOST_CANDIDATES = {
    [BANK_TYPE_GUILD] = {
        "GuildBankFrame",
        "BagnonFrameGuildbank",
        "BaganatorGuildView",
        "Baganator_GuildBankView",
        "Baganator_SingleViewGuildViewFrame1",
        "Baganator_SingleViewGuildViewFrame2",
        "ARKINV_Frame4",
        "CombuctorFrameGuildBank",
        "TBag_Frame_GuildBank",
        "LiteBagGuildBank",
        "EBGuildBankFrame",
    },
    [BANK_TYPE_ACCOUNT] = {
        "BankFrame",
        "AccountBankPanel",
        "BagnonFrameAccountbank",
        "Baganator_WarbandBankView",
        "BaganatorWarbandView",
        "Baganator_SingleViewBankViewFrame1",
        "Baganator_SingleViewBankViewFrame2",
        "Baganator_CategoryViewBankViewFrame1",
        "Baganator_CategoryViewBankViewFrame2",
        "ARKINV_Frame3",
        "CombuctorFrameBank",
        "TBag_Frame_Bank",
        "LiteBagBank",
        "Inventorian_BankFrame",
        "EBBankFrame",
    },
}

local function SafeIsFrameShown(frame)
    if type(frame) ~= "table" then return false end
    if type(frame.IsVisible) == "function" then
        local ok, visible = pcall(frame.IsVisible, frame)
        if ok then return visible == true end
    end
    if type(frame.IsShown) == "function" then
        local ok, shown = pcall(frame.IsShown, frame)
        return ok and shown == true
    end
    return false
end

local function ResolveCandidateFrame(name)
    local frame = _G[name]
    if SafeIsFrameShown(frame) then return frame end
    return nil
end

local HOST_FRAME_BLACKLIST = {
    UIParent = true, WorldFrame = true,
    HironCraftProfitGoldDepositorButton = true, HironCraftProfitTooltip = true,
    AlertFrame = true, UIErrorsFrame = true, RaidWarningFrame = true,
    EventToastManagerFrame = true, BossBanner = true,
    GameTooltip = true, ShoppingTooltip1 = true, ShoppingTooltip2 = true,
    GameTooltipDefaultContainer = true, EmbeddedItemTooltip = true,
    ChatFrame1 = true, ChatFrame2 = true, ChatFrame3 = true,
    ChatFrame4 = true, ChatFrame5 = true, ChatFrame6 = true,
    ChatFrame7 = true, ChatFrame8 = true, ChatFrame9 = true, ChatFrame10 = true,
    GeneralDockManager = true,
    MainMenuBar = true, MicroButtonAndBagsBar = true, BagsBar = true,
    StanceBar = true, PetActionBar = true,
    MultiBar1 = true, MultiBar2 = true, MultiBar3 = true,
    MultiBar4 = true, MultiBar5 = true, MultiBar6 = true, MultiBar7 = true,
    MultiBarBottomLeft = true, MultiBarBottomRight = true,
    MultiBarLeft = true, MultiBarRight = true,
    ObjectiveTrackerFrame = true, QuestObjectiveTracker = true,
    Minimap = true, MinimapCluster = true,
    UIParentBottomManagedFrameContainer = true,
    UIParentRightManagedFrameContainer = true,
    PlayerFrame = true, TargetFrame = true, FocusFrame = true,
    ContainerFrame1 = true, ContainerFrame2 = true, ContainerFrame3 = true,
    ContainerFrame4 = true, ContainerFrame5 = true, ContainerFrame6 = true,
    ContainerFrame7 = true, ContainerFrame8 = true, ContainerFrame9 = true,
    ContainerFrame10 = true, ContainerFrame11 = true, ContainerFrame12 = true,
    ContainerFrame13 = true,
    AccountStoreFrame = true, StoreFrame = true, SettingsPanel = true,
    EditModeManagerFrame = true,
}

local function IsLikelyBankHost(frame, name)
    if name and HOST_FRAME_BLACKLIST[name] then return false, 0 end
    if not SafeIsFrameShown(frame) then return false, 0 end

    local okW, w = pcall(frame.GetWidth, frame)
    local okH, h = pcall(frame.GetHeight, frame)
    if not okW or not okH then return false, 0 end
    if type(w) ~= "number" or type(h) ~= "number" then return false, 0 end
    if w < 240 or h < 220 then return false, 0 end

    local okCenter = pcall(function() return frame:GetCenter() end)
    if not okCenter then return false, 0 end

    return true, w * h
end

local function FindVisibleHostByPattern(bankType)
    local patterns
    if bankType == BANK_TYPE_GUILD then
        patterns = { "[Gg]uild.-[Bb]ank", "[Gg]uild.-[Vv]iew" }
    else
        patterns = { "[Bb]ank" }
    end

    local ok, children = pcall(function() return { UIParent:GetChildren() } end)
    if not ok or type(children) ~= "table" then return nil end

    for _, pattern in ipairs(patterns) do
        for _, child in ipairs(children) do
            if type(child) == "table" and type(child.GetName) == "function" then
                local okName, name = pcall(child.GetName, child)
                if okName and type(name) == "string" and name:find(pattern) then
                    if SafeIsFrameShown(child) then
                        return child
                    end
                end
            end
        end
    end

    local best, bestArea = nil, 0
    for _, child in ipairs(children) do
        if type(child) == "table" then
            local name
            if type(child.GetName) == "function" then
                local okName, value = pcall(child.GetName, child)
                if okName then name = value end
            end
            local ok2, area = IsLikelyBankHost(child, name)
            if ok2 and area > bestArea then
                best = child
                bestArea = area
            end
        end
    end
    return best
end

local function GetBankHostFrame(bankType)
    bankType = bankType or GetCurrentBankType()
    if not bankType then return nil end

    local list = BANK_HOST_CANDIDATES[bankType]
    if list then
        for _, name in ipairs(list) do
            local frame = ResolveCandidateFrame(name)
            if frame then
                if name == "AccountBankPanel" then
                    local parent
                    local okParent, result = pcall(frame.GetParent, frame)
                    if okParent then parent = result end
                    if SafeIsFrameShown(parent) then return parent end
                end
                return frame
            end
        end
    end

    if bankType == BANK_TYPE_ACCOUNT then
        local bankFrame = ResolveCandidateFrame("BankFrame")
        if bankFrame then return bankFrame end
    end

    return FindVisibleHostByPattern(bankType)
end

local function AnchorButtonToBank(bankType)
    if not button then return false end

    local host = GetBankHostFrame(bankType)
    if not host then return false end

    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", host, "TOPLEFT", -8, 10)
    button.ahuiAnchoredToBank = true
    button.ahuiAnchoredHost = host
    return true
end

local function RestoreButtonPosition()
    if not button then
        return
    end

    if AnchorButtonToBank() then
        return
    end

    button.ahuiAnchoredToBank = false

    local db = EnsureDB()

    button:ClearAllPoints()
    button:SetPoint(
        db.buttonPoint or DEFAULT_POINT,
        UIParent,
        db.buttonRelativePoint or db.buttonPoint or DEFAULT_POINT,
        db.buttonX or DEFAULT_X,
        db.buttonY or DEFAULT_Y
    )
end

local function UpdateButtonLockVisual()
    if not button then
        return
    end

    local db = EnsureDB()

    if button.LockTexture then
        button.LockTexture:SetShown(db.buttonLocked)
    end

    button:SetAlpha(IsCharacterDepositDisabled() and 0.55 or 1)
end

local function HideButton()
    if button then
        button:Hide()
    end
end

local function ShowButton()
    if not IsModuleEnabled() then
        HideButton()
        return
    end

    if not button then
        return
    end

    RestoreButtonPosition()
    button:SetFrameStrata("TOOLTIP")
    button:SetFrameLevel(9999)
    UpdateButtonLockVisual()
    button:Show()

    if button.Raise then
        button:Raise()
    end
end

local function UpdateButton()
    if not IsModuleEnabled() then
        HideButton()
        return
    end

    if IsBankSessionOpen() then
        ShowButton()
    else
        HideButton()
    end
end

local function IsRefillRule(rule)
    return rule and rule.refill == true
end

local function GetWithdrawableBankMoney(bankType)
    if bankType == BANK_TYPE_ACCOUNT then
        if C_Bank and type(C_Bank.FetchDepositedMoney) == "function" then
            local ok, money = pcall(C_Bank.FetchDepositedMoney, GetAccountBankType())
            if ok then return tonumber(money) end
        end
        return nil
    end

    local available
    if type(GetGuildBankMoney) == "function" then
        local ok, money = pcall(GetGuildBankMoney)
        if ok then available = tonumber(money) end
    end

    if type(GetGuildBankWithdrawMoney) == "function" then
        local ok, limit = pcall(GetGuildBankWithdrawMoney)
        if ok and tonumber(limit) and limit >= 0 then
            if available == nil or limit < available then
                available = limit
            end
        end
    end

    return available
end

local function WithdrawGold(bankType)
    if depositInProgress then
        print(PREFIX .. " " .. T("GD_TRANSFER_IN_PROGRESS", "Transfer is already in progress..."))
        return
    end

    if bankType == BANK_TYPE_GUILD and type(WithdrawGuildBankMoney) ~= "function" then
        print(ERROR_PREFIX .. " " .. T("GD_ERR_GUILD_WITHDRAW_API", "WithdrawGuildBankMoney API is not available in this client.", "API WithdrawGuildBankMoney недоступно в этом клиенте."))
        return
    end

    if bankType == BANK_TYPE_ACCOUNT and (not C_Bank or type(C_Bank.WithdrawMoney) ~= "function") then
        print(ERROR_PREFIX .. " " .. T("GD_ERR_ACCOUNT_WITHDRAW_API", "C_Bank.WithdrawMoney API is not available in this client.", "API C_Bank.WithdrawMoney недоступно в этом клиенте."))
        return
    end

    local targetGold = GetCurrentKeepGold()
    local targetCopper = GoldToCopper(targetGold)
    local currentMoney = GetMoney()

    if currentMoney >= targetCopper then
        print(string.format(
            "%s " .. T("GD_NOTHING_TO_REFILL", "Character has %s — not below %sg. Nothing to refill.", "У персонажа %s — не меньше %sз. Пополнять нечего."),
            PREFIX,
            CopperToString(currentMoney),
            tostring(targetGold)
        ))
        return
    end

    local needCopper = targetCopper - currentMoney
    local available = GetWithdrawableBankMoney(bankType)

    if available ~= nil and available <= 0 then
        print(string.format(
            "%s " .. T("GD_BANK_NOTHING_TO_WITHDRAW", "%s has no gold available to withdraw.", "В %s нет доступного золота для снятия."),
            ERROR_PREFIX,
            GetBankName(bankType)
        ))
        return
    end

    local withdrawAmount = needCopper
    if available ~= nil and withdrawAmount > available then
        withdrawAmount = available
    end

    if withdrawAmount <= 0 then
        return
    end

    depositInProgress = true

    print(string.format(
        "%s " .. T("GD_REFILLING", "Withdrawing from %s...", "Снимаю из %s..."),
        PREFIX,
        GetBankName(bankType)
    ))

    local ok, err

    if bankType == BANK_TYPE_ACCOUNT then
        ok, err = pcall(C_Bank.WithdrawMoney, GetAccountBankType(), withdrawAmount)
    else
        ok, err = pcall(WithdrawGuildBankMoney, withdrawAmount)
    end

    if not ok then
        depositInProgress = false
        print(ERROR_PREFIX .. " " .. T("GD_ERR_WITHDRAW_FAILED", "Withdrawal failed. Open the correct bank and try again.", "Снятие не удалось. Откройте нужный банк и попробуйте снова."))

        if err then
            print(ERROR_PREFIX .. " " .. string.format(T("GD_ERR_DETAIL", "Error: %s"), tostring(err)))
        end

        return
    end

    RunSoon(0.5, function()
        depositInProgress = false

        print(string.format(
            "%s " .. T("GD_REFILL_DONE", "Done!", "Готово!"),
            OK_PREFIX
        ))
    end)
end

local function DepositGold(requestedBankType)
    if not IsModuleEnabled() then
        print(ERROR_PREFIX .. " " .. T("GD_ERR_MODULE_DISABLED", "Gold Depositor is disabled in HironCraft settings."))
        return
    end

    EnsureDB()
    local bankType = requestedBankType or GetCurrentBankType()

    if IsCharacterDepositDisabled() then
        print(ERROR_PREFIX .. " " .. T("GD_ERR_CHARACTER_DISABLED", "Gold deposit is disabled on this character.", "Депозит золота отключен на этом персонаже."))
        return
    end

    if not bankType then
        print(ERROR_PREFIX .. " " .. T("GD_ERR_BANK_NOT_OPEN", "Bank is not open!"))
        return
    end

    if IsRefillRule(GetCurrentRule()) and GetMoney() < GoldToCopper(GetCurrentKeepGold()) then
        WithdrawGold(bankType)
        return
    end

    if bankType == BANK_TYPE_GUILD and type(DepositGuildBankMoney) ~= "function" then
        print(ERROR_PREFIX .. " " .. T("GD_ERR_GUILD_API", "DepositGuildBankMoney API is not available in this client."))
        return
    end

    if bankType == BANK_TYPE_ACCOUNT then
        if not C_Bank or type(C_Bank.DepositMoney) ~= "function" then
            print(ERROR_PREFIX .. " " .. T("GD_ERR_ACCOUNT_API", "C_Bank.DepositMoney API is not available in this client."))
            return
        end

        if not CanDepositAccountMoney() and not IsAccountBankPanelShown() then
            print(ERROR_PREFIX .. " " .. T("GD_ERR_ACCOUNT_BANK_UNAVAILABLE", "Warband bank is not open or cannot accept gold right now."))
            return
        end
    end

    if depositInProgress then
        print(PREFIX .. " " .. T("GD_TRANSFER_IN_PROGRESS", "Transfer is already in progress..."))
        return
    end

    local keepGold = GetCurrentKeepGold()
    local keepCopper = GoldToCopper(keepGold)
    local currentMoney = GetMoney()

    if currentMoney <= keepCopper then
        print(string.format(
            "%s " .. T("GD_NOTHING_TO_DEPOSIT", "Character has %s — less than or equal to %sg. Nothing to deposit."),
            PREFIX,
            CopperToString(currentMoney),
            tostring(keepGold)
        ))
        return
    end

    local depositAmount = currentMoney - keepCopper
    depositInProgress = true

    print(string.format(
        "%s " .. T("GD_DEPOSITING", "Depositing into %s..."),
        PREFIX,
        GetBankName(bankType)
    ))

    local ok, err

    if bankType == BANK_TYPE_ACCOUNT then
        ok, err = pcall(C_Bank.DepositMoney, GetAccountBankType(), depositAmount)
    else
        ok, err = pcall(DepositGuildBankMoney, depositAmount)
    end

    if not ok then
        depositInProgress = false
        print(ERROR_PREFIX .. " " .. T("GD_ERR_DEPOSIT_FAILED", "Transfer failed. Open the correct bank and try again."))

        if err then
            print(ERROR_PREFIX .. " " .. string.format(T("GD_ERR_DETAIL", "Error: %s"), tostring(err)))
        end

        return
    end

    RunSoon(0.5, function()
        depositInProgress = false

        print(string.format(
            "%s " .. T("GD_DONE", "Done!"),
            OK_PREFIX
        ))
    end)
end

local function QueueAutoDeposit(bankType)
    bankType = bankType or GetCurrentBankType()

    if not bankType then
        return
    end

    if not IsAutoDepositActive(bankType) then
        return
    end

    if autoDepositQueued then
        return
    end

    autoDepositQueued = true
    autoDepositToken = autoDepositToken + 1

    local token = autoDepositToken
    local attempts = 0

    local function TryAutoDeposit()
        if token ~= autoDepositToken then
            return
        end

        attempts = attempts + 1

        if not IsAutoDepositActive(bankType) then
            autoDepositQueued = false
            return
        end

        if GetCurrentBankType() == bankType then
            autoDepositQueued = false
            DepositGold(bankType)
            return
        end

        if attempts < 10 then
            RunSoon(0.25, TryAutoDeposit)
        else
            autoDepositQueued = false
        end
    end

    RunSoon(0.35, TryAutoDeposit)
end

local function ToggleAutoDeposit(bankType)
    bankType = bankType or GetCurrentBankType() or BANK_TYPE_GUILD

    local enabled = not IsAutoDepositEnabled(bankType)
    SetAutoDepositEnabled(bankType, enabled)

    if enabled then
        print(OK_PREFIX .. " " .. string.format(T("GD_AUTO_ON", "Auto-deposit for %s is ON."), GetBankName(bankType)))
        UpdateButtonLockVisual()

        if GetCurrentBankType() == bankType then
            QueueAutoDeposit(bankType)
        end
    else
        autoDepositQueued = false
        autoDepositToken = autoDepositToken + 1
        print(ERROR_PREFIX .. " " .. string.format(T("GD_AUTO_OFF", "Auto-deposit for %s is OFF."), GetBankName(bankType)))
        UpdateButtonLockVisual()
    end
end

local function ToggleButtonLock()
    local db = EnsureDB()
    db.buttonLocked = not db.buttonLocked
    UpdateButtonLockVisual()

    if db.buttonLocked then
        print(OK_PREFIX .. " " .. T("GD_BUTTON_LOCKED", "Button position locked."))
    else
        print(PREFIX .. " " .. T("GD_BUTTON_UNLOCKED", "Button position unlocked. Drag the button with left mouse button."))
    end
end

local function ApplyKeepGoldValue(value)
    local amount = tonumber(value)

    if amount and amount >= 0 then
        SetCurrentKeepGold(amount)
        print(string.format("%s " .. T("GD_KEEP_SET", "Now keeping %sg on the character.", "Теперь на персонаже остаётся %sз."), PREFIX, tostring(amount)))
        UpdateButton()

        if settingsFrame and settingsFrame.Refresh then
            settingsFrame:Refresh()
        end
    else
        print(ERROR_PREFIX .. " " .. T("GD_ERR_INVALID_AMOUNT", "Enter a valid gold amount.", "Введите корректное количество золота."))
    end
end

local function StyleButtonText(frame)
    if not frame or type(frame.GetFontString) ~= "function" then
        return
    end

    local fs = frame:GetFontString()
    if fs and type(fs.SetFont) == "function" then
        fs:SetFont(FONT, 12, "")
    end
end

local function CreateKeepGoldPopup()
    if keepPopup then
        return keepPopup
    end

    local f = CreateFrame("Frame", "HironCraftProfitGoldDepositorKeepPopup", UIParent, "BackdropTemplate")
    f:SetSize(340, 150)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(100)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0, 0, 0, 0.95)
    f:SetBackdropBorderColor(0.694, 0.612, 0.851, 1)
    f:Hide()

    f:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetFont(FONT, 16, "OUTLINE")
    title:SetTextColor(1, 1, 1)
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
    title:SetText(T("GD_TITLE", "Gold Depositor"))
    f.Title = title

    local text = f:CreateFontString(nil, "OVERLAY")
    text:SetFont(FONT, 13, "")
    text:SetTextColor(0.9, 0.9, 0.9)
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    text:SetText(T("GD_KEEP_POPUP_TEXT", "How much gold should remain in your bags?"))
    f.Text = text

    local editBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    editBox:SetSize(120, 28)
    editBox:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -10)
    editBox:SetAutoFocus(false)
    editBox:SetNumeric(false)
    editBox:SetFont(FONT, 15, "")
    editBox:SetTextColor(1, 1, 1)
    editBox:SetJustifyH("LEFT")
    f.EditBox = editBox

    local suffix = f:CreateFontString(nil, "OVERLAY")
    suffix:SetFont(FONT, 13, "")
    suffix:SetTextColor(1, 0.82, 0)
    suffix:SetPoint("LEFT", editBox, "RIGHT", 8, 0)
    suffix:SetText("g")
    f.Suffix = suffix

    local ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    ok:SetSize(96, 24)
    ok:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 14)
    ok:SetText(ACCEPT or "OK")
    StyleButtonText(ok)
    f.OkButton = ok

    local cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancel:SetSize(96, 24)
    cancel:SetPoint("RIGHT", ok, "LEFT", -8, 0)
    cancel:SetText(CANCEL or "Cancel")
    StyleButtonText(cancel)
    f.CancelButton = cancel

    local function AcceptValue()
        ApplyKeepGoldValue(editBox:GetText())
        f:Hide()
    end

    ok:SetScript("OnClick", AcceptValue)
    cancel:SetScript("OnClick", function()
        f:Hide()
    end)

    editBox:SetScript("OnEnterPressed", AcceptValue)
    editBox:SetScript("OnEscapePressed", function()
        f:Hide()
    end)

    f:SetScript("OnShow", function(self)
        editBox:SetText(tostring(GetCurrentKeepGold()))
        editBox:SetFocus()
        editBox:HighlightText()
    end)

    f:SetScript("OnHide", function()
        editBox:ClearFocus()
    end)

    keepPopup = f
    return keepPopup
end

local function OpenKeepGoldPopup()
    CreateKeepGoldPopup():Show()
end


local function CreateSettingsWindow()
    if settingsFrame then
        return settingsFrame
    end

    local f = CreateFrame("Frame", "HironCraftProfitGoldDepositorSettings", UIParent, "BackdropTemplate")
    f:SetSize(560, 478)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(110)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0, 0, 0, 0.94)
    f:SetBackdropBorderColor(0.694, 0.612, 0.851, 1)
    f:Hide()

    if HironCraftProfit.RegisterEscClose then HironCraftProfit:RegisterEscClose(f) end

    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetFont(FONT, 17, "OUTLINE")
    title:SetTextColor(1, 1, 1)
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
    title:SetText(T("GD_SETTINGS_TITLE", "Gold Depositor settings", "Настройки депозита золота"))
    f.Title = title

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    f.CloseButton = close

    local charLabel = f:CreateFontString(nil, "OVERLAY")
    charLabel:SetFont(FONT, 13, "")
    charLabel:SetTextColor(0.85, 0.85, 0.85)
    charLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    f.CharacterLabel = charLabel

    local charDisabled = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    charDisabled:SetPoint("TOPLEFT", charLabel, "BOTTOMLEFT", -2, -8)
    charDisabled.text:SetFont(FONT, 12, "")
    charDisabled.text:SetText(T("GD_SETTINGS_DISABLE_CHARACTER", "Disable gold deposit on this character", "Отключить депозит золота на этом персонаже"))
    f.CharacterDisabled = charDisabled

    local rulesTitle = f:CreateFontString(nil, "OVERLAY")
    rulesTitle:SetFont(FONT, 14, "OUTLINE")
    rulesTitle:SetTextColor(1, 0.82, 0)
    rulesTitle:SetPoint("TOPLEFT", charDisabled, "BOTTOMLEFT", 2, -16)
    rulesTitle:SetText(T("GD_SETTINGS_RULES", "Rules", "Правила"))
    f.RulesTitle = rulesTitle

    local listBg = CreateFrame("Frame", nil, f, "BackdropTemplate")
    listBg:SetSize(210, 245)
    listBg:SetPoint("TOPLEFT", rulesTitle, "BOTTOMLEFT", -2, -8)
    listBg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    listBg:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    listBg:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
    f.RuleListBg = listBg

    f.RuleButtons = {}
    for i = 1, 8 do
        local b = CreateFrame("Button", nil, listBg)
        b:SetSize(190, 24)
        b:SetPoint("TOPLEFT", listBg, "TOPLEFT", 10, -8 - ((i - 1) * 28))
        b.Text = b:CreateFontString(nil, "OVERLAY")
        b.Text:SetFont(FONT, 12, "")
        b.Text:SetJustifyH("LEFT")
        b.Text:SetPoint("LEFT", b, "LEFT", 6, 0)
        b.Text:SetPoint("RIGHT", b, "RIGHT", -6, 0)
        b.Highlight = b:CreateTexture(nil, "BACKGROUND")
        b.Highlight:SetTexture("Interface\\Buttons\\WHITE8x8")
        b.Highlight:SetAllPoints()
        b.Highlight:SetColorTexture(1, 1, 1, 0.08)
        b.Highlight:Hide()
        b:SetScript("OnEnter", function(self) self.Highlight:Show() end)
        b:SetScript("OnLeave", function(self)
            self.Highlight:Hide()
        end)
        b:SetScript("OnClick", function(self)
            if self.RuleID and SetCurrentRuleID(self.RuleID) then
                if f.Refresh then f:Refresh() end
                UpdateButtonLockVisual()
                local bankType = GetCurrentBankType()
                if bankType then
                    autoDepositQueued = false
                    autoDepositToken = autoDepositToken + 1
                    QueueAutoDeposit(bankType)
                end
            end
        end)
        f.RuleButtons[i] = b
    end

    local detailsTitle = f:CreateFontString(nil, "OVERLAY")
    detailsTitle:SetFont(FONT, 14, "OUTLINE")
    detailsTitle:SetTextColor(1, 0.82, 0)
    detailsTitle:SetPoint("TOPLEFT", listBg, "TOPRIGHT", 22, 0)
    detailsTitle:SetText(T("GD_SETTINGS_RULE_DETAILS", "Selected rule", "Выбранное правило"))
    f.DetailsTitle = detailsTitle

    local nameLabel = f:CreateFontString(nil, "OVERLAY")
    nameLabel:SetFont(FONT, 12, "")
    nameLabel:SetTextColor(0.85, 0.85, 0.85)
    nameLabel:SetPoint("TOPLEFT", detailsTitle, "BOTTOMLEFT", 0, -12)
    nameLabel:SetText(T("GD_SETTINGS_RULE_NAME", "Rule name", "Название правила"))
    f.NameLabel = nameLabel

    local nameEdit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    nameEdit:SetSize(220, 26)
    nameEdit:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -4)
    nameEdit:SetAutoFocus(false)
    nameEdit:SetFont(FONT, 13, "")
    nameEdit:SetTextColor(1, 1, 1)
    f.NameEdit = nameEdit

    local keepLabel = f:CreateFontString(nil, "OVERLAY")
    keepLabel:SetFont(FONT, 12, "")
    keepLabel:SetTextColor(0.85, 0.85, 0.85)
    keepLabel:SetPoint("TOPLEFT", nameEdit, "BOTTOMLEFT", 0, -12)
    keepLabel:SetText(T("GD_SETTINGS_KEEP_GOLD", "Gold to keep", "Сколько золота оставить"))
    f.KeepLabel = keepLabel

    local keepEdit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    keepEdit:SetSize(100, 26)
    keepEdit:SetPoint("TOPLEFT", keepLabel, "BOTTOMLEFT", 0, -4)
    keepEdit:SetAutoFocus(false)
    keepEdit:SetNumeric(false)
    keepEdit:SetFont(FONT, 13, "")
    keepEdit:SetTextColor(1, 1, 1)
    f.KeepEdit = keepEdit

    local keepSuffix = f:CreateFontString(nil, "OVERLAY")
    keepSuffix:SetFont(FONT, 12, "")
    keepSuffix:SetTextColor(1, 0.82, 0)
    keepSuffix:SetPoint("LEFT", keepEdit, "RIGHT", 8, 0)
    keepSuffix:SetText("g")
    f.KeepSuffix = keepSuffix

    local autoGuild = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    autoGuild:SetPoint("TOPLEFT", keepEdit, "BOTTOMLEFT", -2, -8)
    autoGuild.text:SetFont(FONT, 12, "")
    autoGuild.text:SetText(T("GD_SETTINGS_AUTO_GUILD", "Auto-deposit to guild bank", "Автодепозит в банк гильдии"))
    f.AutoGuild = autoGuild

    local autoAccount = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    autoAccount:SetPoint("TOPLEFT", autoGuild, "BOTTOMLEFT", 0, -4)
    autoAccount.text:SetFont(FONT, 12, "")
    autoAccount.text:SetText(T("GD_SETTINGS_AUTO_ACCOUNT", "Auto-deposit to warband bank", "Автодепозит в банк отряда"))
    f.AutoAccount = autoAccount

    local refillCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    refillCheck:SetPoint("TOPLEFT", autoAccount, "BOTTOMLEFT", 0, -10)
    refillCheck.text:SetFont(FONT, 12, "")
    refillCheck.text:SetText(T("GD_SETTINGS_REFILL", "Also withdraw to wallet if below the amount", "Пополнять кошелёк из банка, если ниже суммы"))
    refillCheck.text:SetTextColor(1, 0.82, 0)
    f.RefillCheck = refillCheck

    local refillHint = f:CreateFontString(nil, "OVERLAY")
    refillHint:SetFont(FONT, 11, "")
    refillHint:SetTextColor(0.7, 0.7, 0.7)
    refillHint:SetPoint("TOPLEFT", refillCheck, "BOTTOMLEFT", 26, 0)
    refillHint:SetWidth(250)
    refillHint:SetJustifyH("LEFT")
    refillHint:SetText(T("GD_SETTINGS_REFILL_HINT", "Excess is always deposited; with this on, missing gold is also withdrawn from the open bank up to the amount.", "Излишек всегда уходит в банк; с этим флажком недостающее ещё и снимается из открытого банка до суммы."))
    f.RefillHint = refillHint

    local selectedInfo = f:CreateFontString(nil, "OVERLAY")
    selectedInfo:SetFont(FONT, 12, "")
    selectedInfo:SetTextColor(0.7, 0.9, 1)
    selectedInfo:SetPoint("TOPLEFT", refillHint, "BOTTOMLEFT", -24, -12)
    selectedInfo:SetWidth(250)
    selectedInfo:SetJustifyH("LEFT")
    f.SelectedInfo = selectedInfo

    local function MakeButton(text, width)
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(width or 92, 24)
        b:SetText(text)
        StyleButtonText(b)
        return b
    end

    local newRule = MakeButton(T("GD_SETTINGS_NEW_RULE", "New", "Новое"), 82)
    newRule:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 14)
    f.NewRule = newRule

    local saveRule = MakeButton(T("GD_SETTINGS_SAVE_RULE", "Save", "Сохранить"), 96)
    saveRule:SetPoint("LEFT", newRule, "RIGHT", 8, 0)
    f.SaveRule = saveRule

    local deleteRule = MakeButton(T("GD_SETTINGS_DELETE_RULE", "Delete", "Удалить"), 96)
    deleteRule:SetPoint("LEFT", saveRule, "RIGHT", 8, 0)
    f.DeleteRule = deleteRule

    local closeButton = MakeButton(CLOSE or T("GD_SETTINGS_CLOSE", "Close", "Закрыть"), 96)
    closeButton:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 14)
    f.BottomClose = closeButton

    local function SaveCurrentRuleFromFields(silent)
        if f.isRefreshing then
            return true
        end

        local rule = GetCurrentRule()
        if not rule then return false end

        local name = Trim(nameEdit:GetText())
        local keepGold = tonumber(keepEdit:GetText())

        if name == "" then
            if not silent then
                print(ERROR_PREFIX .. " " .. T("GD_ERR_RULE_NAME", "Rule name cannot be empty.", "Название правила не может быть пустым."))
            end
            return false
        end

        if not keepGold or keepGold < 0 then
            if not silent then
                print(ERROR_PREFIX .. " " .. T("GD_ERR_INVALID_AMOUNT", "Enter a valid gold amount.", "Введите корректное количество золота."))
            end
            return false
        end

        rule.name = name
        rule.keepGold = keepGold
        rule.autoDepositGuild = autoGuild:GetChecked() == true
        rule.autoDepositAccount = autoAccount:GetChecked() == true
        rule.refill = refillCheck:GetChecked() == true

        local db = EnsureDB()
        if GetCurrentRuleID() == "default" then
            db.keepGold = rule.keepGold
            db.autoDepositGuild = rule.autoDepositGuild
            db.autoDepositAccount = rule.autoDepositAccount
        end

        if not silent then
            print(OK_PREFIX .. " " .. T("GD_RULE_SAVED", "Rule saved.", "Правило сохранено."))
        end

        UpdateButtonLockVisual()
        UpdateButton()
        return true
    end

    newRule:SetScript("OnClick", function()
        local db = EnsureDB()
        local id = NewRuleID(db)
        local base = GetCurrentRule()
        db.rules[id] = {
            id = id,
            name = string.format(T("GD_NEW_RULE_NAME", "Rule %d", "Правило %d"), db._ruleCounter),
            keepGold = tonumber(base and base.keepGold) or DEFAULT_KEEP,
            autoDepositGuild = base and base.autoDepositGuild == true or false,
            autoDepositAccount = base and base.autoDepositAccount == true or false,
            refill = base and base.refill == true or false,
        }
        table.insert(db.ruleOrder, id)
        SetCurrentRuleID(id)
        print(OK_PREFIX .. " " .. T("GD_RULE_CREATED", "Rule created.", "Правило создано."))
        f:Refresh()
    end)

    saveRule:SetScript("OnClick", function()
        if SaveCurrentRuleFromFields() then
            f:Refresh()
            UpdateButtonLockVisual()
        end
    end)

    deleteRule:SetScript("OnClick", function()
        local db = EnsureDB()
        local currentRuleID = GetCurrentRuleID()

        if currentRuleID == "default" or #db.ruleOrder <= 1 then
            print(ERROR_PREFIX .. " " .. T("GD_ERR_DELETE_DEFAULT_RULE", "The default rule cannot be deleted.", "Базовое правило нельзя удалить."))
            return
        end

        db.rules[currentRuleID] = nil

        for i = #db.ruleOrder, 1, -1 do
            if db.ruleOrder[i] == currentRuleID then
                table.remove(db.ruleOrder, i)
            end
        end

        local fallback = db.ruleOrder[1] or "default"
        for _, cfg in pairs(db.characters) do
            if type(cfg) == "table" and cfg.ruleID == currentRuleID then
                cfg.ruleID = fallback
            end
        end

        SetCurrentRuleID(fallback)
        print(OK_PREFIX .. " " .. T("GD_RULE_DELETED", "Rule deleted.", "Правило удалено."))
        f:Refresh()
        UpdateButtonLockVisual()
    end)

    close:SetScript("OnClick", function()
        SaveCurrentRuleFromFields(true)
        f:Hide()
    end)

    closeButton:SetScript("OnClick", function()
        SaveCurrentRuleFromFields(true)
        f:Hide()
    end)

    nameEdit:SetScript("OnEnterPressed", function(self)
        if SaveCurrentRuleFromFields() then
            self:ClearFocus()
            f:Refresh()
        end
    end)

    nameEdit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        f:Hide()
    end)

    nameEdit:SetScript("OnEditFocusLost", function()
        SaveCurrentRuleFromFields(true)
    end)

    keepEdit:SetScript("OnEnterPressed", function(self)
        if SaveCurrentRuleFromFields() then
            self:ClearFocus()
            f:Refresh()
        end
    end)

    keepEdit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        f:Hide()
    end)

    keepEdit:SetScript("OnEditFocusLost", function()
        SaveCurrentRuleFromFields(true)
    end)

    autoGuild:SetScript("OnClick", function()
        SaveCurrentRuleFromFields(true)
        f:Refresh()
    end)

    autoAccount:SetScript("OnClick", function()
        SaveCurrentRuleFromFields(true)
        f:Refresh()
    end)

    refillCheck:SetScript("OnClick", function()
        SaveCurrentRuleFromFields(true)
        f:Refresh()
        if not IsCharacterDepositDisabled() and GetCurrentBankType() then
            DepositGold()
        end
    end)

    charDisabled:SetScript("OnClick", function(self)
        SetCharacterDepositDisabled(self:GetChecked() == true)
        f:Refresh()
        UpdateButtonLockVisual()
        UpdateButton()
    end)

    f:SetScript("OnShow", function(self)
        self:Refresh()
    end)

    f:SetScript("OnHide", function()
        SaveCurrentRuleFromFields(true)
        nameEdit:ClearFocus()
        keepEdit:ClearFocus()
    end)

    f.Refresh = function(self)
        self.isRefreshing = true

        local db = EnsureDB()
        local cfg, charKey = GetCharacterConfig()
        local ruleID = GetCurrentRuleID()
        local rule = GetCurrentRule()

        charLabel:SetText(string.format(
            "%s: |cffffd200%s|r",
            T("GD_SETTINGS_CHARACTER", "Character", "Персонаж"),
            tostring(charKey)
        ))

        charDisabled:SetChecked(cfg.disabled == true)

        for i, b in ipairs(self.RuleButtons) do
            local id = db.ruleOrder[i]
            local r = id and db.rules[id]
            b.RuleID = id

            if r then
                b:Show()
                b.Selected = id == ruleID
                b.Text:SetText(GetRuleDisplayName(r))

                if b.Selected then
                    b.Text:SetTextColor(1, 0.82, 0)
                else
                    b.Text:SetTextColor(0.85, 0.85, 0.85)
                end

                b.Highlight:Hide()
            else
                b:Hide()
            end
        end

        nameEdit:SetText(rule and GetRuleDisplayName(rule) or "")
        keepEdit:SetText(tostring(tonumber(rule and rule.keepGold) or DEFAULT_KEEP))
        autoGuild:SetChecked(rule and rule.autoDepositGuild == true)
        autoAccount:SetChecked(rule and rule.autoDepositAccount == true)

        refillCheck:SetChecked(rule and rule.refill == true)

        selectedInfo:SetText(string.format(
            "%s: |cffffd200%s|r%s",
            T("GD_SETTINGS_SELECTED_FOR_CHAR", "Selected for this character", "Выбрано для этого персонажа"),
            GetRuleDisplayName(rule),
            cfg.disabled and ("\n|cffff4444" .. T("GD_SETTINGS_CHARACTER_DISABLED_NOTE", "Gold deposit is disabled on this character.", "Депозит золота отключен на этом персонаже.") .. "|r") or ""
        ))

        self.isRefreshing = false
    end

    settingsFrame = f
    return settingsFrame
end

local function OpenSettingsWindow()
    CreateSettingsWindow():Show()
end

local function ColorText(text, color)
    return color .. tostring(text) .. RESET_COLOR
end

local function KeyText(text)
    return ColorText(text, KEY_COLOR)
end

local function EnabledStatus(enabled)
    if enabled then
        return ColorText(T("GD_STATUS_ON", "ON"), ON_COLOR)
    end

    return ColorText(T("GD_STATUS_OFF", "OFF"), OFF_COLOR)
end

local function PositionStatus(locked)
    if locked then
        return ColorText(T("GD_POS_STATUS_LOCKED", "LOCKED"), OFF_COLOR)
    end

    return ColorText(T("GD_POS_STATUS_UNLOCKED", "UNLOCKED"), ON_COLOR)
end

local function TooltipLine(text, size, r, g, b)
    if Tooltip then
        Tooltip:AddLine(text, size, r, g, b)
    end
end

local function TooltipAction(keys, text)
    TooltipLine(KeyText(keys) .. ColorText(" — " .. text, TEXT_COLOR), 12, 1, 1, 1)
end

local function TooltipStatus(name, value)
    TooltipLine(ColorText(name .. ": ", DIM_COLOR) .. value, 12, 1, 1, 1)
end

local function ShowHironCraftProfitTooltip(owner)
    if not Tooltip then
        return
    end

    local rule = GetCurrentRule()
    local bankType = GetCurrentBankType()
    local bankName = bankType and GetBankName(bankType) or T("GD_BANK_NOT_OPEN", "bank is not open", "банк не открыт")
    local currentAutoText = ""

    if bankType then
        currentAutoText = " " .. ColorText("[" .. EnabledStatus(IsAutoDepositEnabled(bankType)) .. "]", DIM_COLOR)
    end

    local refill = IsRefillRule(rule)

    Tooltip:Clear()
    TooltipLine(T("GD_TITLE", "Gold Depositor"), 14, 1, 1, 1)
    TooltipStatus(T("GD_TT_CURRENT_BANK", "Current bank", "Текущий банк"), ColorText(bankName, INFO_COLOR))
    TooltipStatus(T("GD_TT_RULE", "Rule", "Правило"), ColorText(GetRuleDisplayName(rule), KEY_COLOR))
    TooltipStatus(T("GD_TT_MODE", "Mode", "Режим"), refill and ColorText(T("GD_MODE_BOTH", "deposit + refill", "депозит + пополнение"), INFO_COLOR) or ColorText(T("GD_MODE_DEPOSIT", "deposit", "депозит"), INFO_COLOR))
    TooltipStatus(T("GD_TT_CHARACTER", "Character", "Персонаж"), IsCharacterDepositDisabled() and ColorText(T("GD_DISABLED", "disabled", "отключён"), OFF_COLOR) or ColorText(T("GD_ENABLED", "enabled", "включён"), ON_COLOR))
    TooltipLine(" ", 4, 1, 1, 1)
    TooltipAction(T("GD_KEY_LMB", "LMB"), refill and T("GD_TT_BALANCE", "balance the wallet", "выровнять баланс") or T("GD_TT_DEPOSIT", "deposit gold", "положить золото"))
    TooltipAction(T("GD_KEY_MMB", "MMB"), T("GD_TT_SETTINGS", "open Gold Depositor settings", "открыть настройки депозита"))
    TooltipAction(T("GD_KEY_RMB", "RMB"), T("GD_TT_AUTO_CURRENT", "current bank auto-deposit", "автодепозит текущего банка") .. currentAutoText)
    TooltipLine(" ", 4, 1, 1, 1)
    TooltipStatus(T("GD_TT_AUTO_GUILD_STATUS", "Guild bank auto", "Авто банк гильдии"), EnabledStatus(IsAutoDepositEnabled(BANK_TYPE_GUILD)))
    TooltipStatus(T("GD_TT_AUTO_ACCOUNT_STATUS", "Warband bank auto", "Авто банк отряда"), EnabledStatus(IsAutoDepositEnabled(BANK_TYPE_ACCOUNT)))
    TooltipStatus(T("GD_TT_KEEP_STATUS", "Keep", "Оставить"), ColorText(tostring(GetCurrentKeepGold()) .. "g", KEY_COLOR))
    Tooltip:ShowSmart(owner, 10)
end

local function CreateButton()
    if not IsModuleEnabled() then
        HideButton()
        return nil
    end

    if button then
        UpdateButton()
        return button
    end

    button = CreateFrame("Button", "HironCraftProfitGoldDepositorButton", UIParent)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetClampedToScreen(true)
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    button:RegisterForDrag("LeftButton")
    button:Hide()

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()

    local iconOk = false

    if type(icon.SetAtlas) == "function" then
        iconOk = pcall(icon.SetAtlas, icon, "Mobile-TreasureIcon", true)
    end

    if not iconOk then
        icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
    end

    button.Icon = icon

    local lockTexture = button:CreateTexture(nil, "OVERLAY")
    lockTexture:SetSize(18, 18)
    lockTexture:SetPoint("TOPRIGHT", -3, -3)
    lockTexture:SetTexture("Interface\\Buttons\\LockButton-Locked-Up")
    lockTexture:Hide()
    button.LockTexture = lockTexture

    button:SetScript("OnDragStart", function(self)
        local db = EnsureDB()

        if db.buttonLocked then
            return
        end

        if self.ahuiAnchoredToBank then
            return
        end

        self.wasDragged = true
        self:StartMoving()
    end)

    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveButtonPosition()

        RunSoon(0.15, function()
            if self then
                self.wasDragged = false
            end
        end)
    end)

    button:SetScript("OnMouseDown", function(self)
        if self.Icon then
            self.Icon:SetScale(0.92)
        end
    end)

    button:SetScript("OnMouseUp", function(self)
        if self.Icon then
            self.Icon:SetScale(1)
        end
    end)

    button:SetScript("OnClick", function(self, mouseButton)
        if self.wasDragged then
            return
        end

        if mouseButton == "LeftButton" then
            DepositGold()
        elseif mouseButton == "MiddleButton" then
            OpenSettingsWindow()
        elseif mouseButton == "RightButton" then
            ToggleAutoDeposit(GetCurrentBankType() or BANK_TYPE_GUILD)
        end

        if self:IsMouseOver() then
            ShowHironCraftProfitTooltip(self)
        end
    end)

    button:SetScript("OnEnter", ShowHironCraftProfitTooltip)

    button:SetScript("OnLeave", function(self)
        UpdateButtonLockVisual()

        if self.Icon then
            self.Icon:SetScale(1)
        end

        if Tooltip then
            Tooltip:Clear()
        end
    end)

    RestoreButtonPosition()
    UpdateButtonLockVisual()
    UpdateButton()

    return button
end

local function EnsureButton()
    if not IsModuleEnabled() then
        HideButton()
        return
    end

    CreateButton()
    UpdateButton()
end

local function MarkBankOpen(bankType)
    bankSessionOpen = true
    currentBankType = bankType
    lastBankSignalAt = Now()
    EnsureButton()
end

local function MarkBankClosed(bankType)
    if bankType and currentBankType and bankType ~= currentBankType then
        return
    end

    bankSessionOpen = false
    currentBankType = nil
    autoDepositQueued = false
    autoDepositToken = autoDepositToken + 1
    HideButton()
end

local function OnBankSignal(bankType)
    if not IsModuleEnabled() then
        HideButton()
        return
    end

    MarkBankOpen(bankType)
    QueueAutoDeposit(bankType)

    RunSoon(0.10, EnsureButton)
    RunSoon(0.35, EnsureButton)
    RunSoon(0.75, EnsureButton)
end

local function OnGuildBankSignal()
    OnBankSignal(BANK_TYPE_GUILD)
end

local function OnAccountBankSignal()
    OnBankSignal(BANK_TYPE_ACCOUNT)
end

local function TryAccountBankSignal()
    if IsAccountBankPanelShown() or CanDepositAccountMoney() then
        OnAccountBankSignal()
    end
end

local function InstallAccountBankHooks()
    if accountBankHooksInstalled then
        return
    end

    local panel = _G.AccountBankPanel

    if not panel or type(panel.HookScript) ~= "function" then
        return
    end

    accountBankHooksInstalled = true

    panel:HookScript("OnShow", function()
        OnAccountBankSignal()
    end)

    panel:HookScript("OnHide", function()
        if currentBankType == BANK_TYPE_ACCOUNT then
            MarkBankClosed(BANK_TYPE_ACCOUNT)
        end
    end)

    local itemDepositFrame = panel.ItemDepositFrame
    local checkbox = itemDepositFrame and itemDepositFrame.IncludeReagentsCheckbox

    if checkbox and type(checkbox.HookScript) == "function" then
        checkbox:HookScript("OnShow", function()
            OnAccountBankSignal()
        end)

        checkbox:HookScript("OnHide", function()
            if currentBankType == BANK_TYPE_ACCOUNT then
                RunSoon(0.1, function()
                    if not IsAccountBankPanelShown() and not CanDepositAccountMoney() then
                        MarkBankClosed(BANK_TYPE_ACCOUNT)
                    end
                end)
            end
        end)
    end
end

local function ResetButtonPosition()
    local db = EnsureDB()
    db.buttonPoint = DEFAULT_POINT
    db.buttonRelativePoint = DEFAULT_POINT
    db.buttonX = DEFAULT_X
    db.buttonY = DEFAULT_Y
    db.buttonPositionVersion = POSITION_VERSION
    RestoreButtonPosition()
    UpdateButton()
    print(OK_PREFIX .. " " .. T("GD_RESET_DONE", "Button position reset."))
end

local function PrintHelp()
    local rule = GetCurrentRule()

    print(PREFIX .. " " .. T("GD_HELP_TITLE", "Commands:", "Команды:"))
    print(T("GD_HELP_DEPOSIT", "  /gd deposit          — deposit gold into the open bank: guild bank or warband bank", "  /gd deposit          — положить золото в открытый банк: гильдии или отряда"))
    print(T("GD_HELP_AUTO", "  /gd auto             — toggle auto-deposit for the current open bank", "  /gd auto             — переключить автодепозит для текущего открытого банка"))
    print(T("GD_HELP_AUTO_GUILD", "  /gd auto guild       — toggle guild bank auto-deposit", "  /gd auto guild       — переключить автодепозит в банк гильдии"))
    print(T("GD_HELP_AUTO_WARBAND", "  /gd auto warband     — toggle warband bank auto-deposit", "  /gd auto warband     — переключить автодепозит в банк отряда"))
    print(T("GD_HELP_SETTINGS", "  /gd settings         — open Gold Depositor settings", "  /gd settings         — открыть настройки депозита золота"))
    print(T("GD_HELP_LOCK", "  /gd lock             — lock/unlock button position", "  /gd lock             — заблокировать/разблокировать позицию кнопки"))
    print(T("GD_HELP_RESET", "  /gd reset            — reset button position", "  /gd reset            — сбросить позицию кнопки"))
    print(string.format(T("GD_HELP_KEEP", "  /gd keep <amount>    — how much gold to keep in the selected rule, current: %sg", "  /gd keep <число>     — сколько золота оставлять в выбранном правиле, сейчас: %sз"), tostring(GetCurrentKeepGold())))
    print(T("GD_HELP_BUTTON", "  /gd button           — refresh the button", "  /gd button           — обновить кнопку"))
    print(T("GD_HELP_STATUS", "  /gd status           — show current settings", "  /gd status           — показать текущие настройки"))
    print(T("GD_HELP_ALIAS", "  /ahuigd              — full alias for /gd", "  /ahuigd              — полный алиас для /gd"))
    print(string.format(T("GD_HELP_CURRENT_RULE", "  Current rule: %s", "  Текущее правило: %s"), GetRuleDisplayName(rule)))
    print(T("GD_HELP_BUTTON_HINT", "  Button: LMB deposit, Shift+LMB settings, MMB lock, RMB current bank auto.", "  Кнопка: ЛКМ депозит, Shift+ЛКМ настройки, СКМ блокировка, ПКМ авто текущего банка."))
end

local function PrintStatus()
    local rule = GetCurrentRule()
    local keepGold = GetCurrentKeepGold()
    local current = GetMoney()
    local refill = IsRefillRule(rule)
    local willDeposit = math.max(0, current - GoldToCopper(keepGold))
    local willRefill = math.max(0, GoldToCopper(keepGold) - current)
    local bankType = GetCurrentBankType()
    local accountMoney = nil
    local _, charKey = GetCharacterConfig()

    if C_Bank and type(C_Bank.FetchDepositedMoney) == "function" then
        local ok, money = pcall(C_Bank.FetchDepositedMoney, GetAccountBankType())

        if ok then
            accountMoney = money
        end
    end

    print(PREFIX .. " " .. T("GD_STATUS_TITLE", "Status:", "Статус:"))
    print(T("GD_STATUS_CHARACTER", "  Character:              ", "  Персонаж:               ") .. tostring(charKey))
    print(T("GD_STATUS_CHARACTER_ENABLED", "  Character deposit:      ", "  Депозит персонажа:      ") .. (IsCharacterDepositDisabled() and T("GD_DISABLED", "disabled", "отключен") or T("GD_ENABLED", "enabled", "включен")))
    print(T("GD_STATUS_RULE", "  Selected rule:          ", "  Выбранное правило:      ") .. GetRuleDisplayName(rule))
    print(T("GD_STATUS_MODE", "  Mode:                   ", "  Режим:                  ") .. (refill and T("GD_MODE_BOTH", "deposit + refill", "депозит + пополнение") or T("GD_MODE_DEPOSIT", "deposit", "депозит")))
    print(T("GD_STATUS_CURRENT", "  On character:           ", "  У персонажа:            ") .. CopperToString(current))
    print(T("GD_STATUS_KEEP", "  Keep on character:      ", "  Держать на персонаже:   ") .. tostring(keepGold) .. "g")
    print(T("GD_STATUS_OPEN_BANK", "  Open bank:              ", "  Открытый банк:          ") .. (bankType and GetBankName(bankType) or T("GD_NO", "none", "нет")))
    print(T("GD_STATUS_AUTO_GUILD", "  Guild bank auto:        ", "  Авто банк гильдии:      ") .. (IsAutoDepositEnabled(BANK_TYPE_GUILD) and T("GD_ENABLED", "enabled", "включен") or T("GD_DISABLED", "disabled", "отключен")))
    print(T("GD_STATUS_AUTO_ACCOUNT", "  Warband bank auto:      ", "  Авто банк отряда:       ") .. (IsAutoDepositEnabled(BANK_TYPE_ACCOUNT) and T("GD_ENABLED", "enabled", "включен") or T("GD_DISABLED", "disabled", "отключен")))
    print(T("GD_STATUS_POSITION", "  Button position:        ", "  Позиция кнопки:         ") .. (EnsureDB().buttonLocked and T("GD_LOCKED", "locked", "заблокирована") or T("GD_UNLOCKED", "unlocked", "разблокирована")))
    print(T("GD_STATUS_LAST_SIGNAL", "  Last signal:            ", "  Последний сигнал:       ") .. string.format("%.2f", lastBankSignalAt or 0))
    if willDeposit > 0 then
        print(T("GD_STATUS_WILL_DEPOSIT", "  Will deposit:           ", "  Будет внесено:          ") .. CopperToString(willDeposit))
    elseif refill and willRefill > 0 then
        print(T("GD_STATUS_WILL_REFILL", "  Will withdraw:          ", "  Будет снято:            ") .. CopperToString(willRefill))
    else
        print(T("GD_STATUS_WILL_NOTHING", "  Will transfer:          ", "  Будет переведено:       ") .. CopperToString(0))
    end

    if accountMoney ~= nil then
        print(T("GD_STATUS_ACCOUNT_BANK", "  In warband bank:        ", "  В банке отряда:         ") .. CopperToString(accountMoney))
    end
end

local function HandleCommand(input)
    EnsureDB()

    input = Trim(input)

    if not IsModuleEnabled() then
        print(ERROR_PREFIX .. " " .. T("GD_ERR_MODULE_DISABLED", "Gold Depositor is disabled in HironCraft settings."))
        return
    end

    local cmd, arg = input:match("^(%S*)%s*(.*)$")
    cmd = (cmd or ""):lower()
    arg = arg or ""

    if cmd == "" or cmd == "help" then
        PrintHelp()
    elseif cmd == "deposit" then
        DepositGold()
    elseif cmd == "auto" then
        ToggleAutoDeposit(ResolveAutoBankType(arg))
    elseif cmd == "settings" or cmd == "config" or cmd == "options" then
        OpenSettingsWindow()
    elseif cmd == "lock" then
        ToggleButtonLock()
    elseif cmd == "reset" then
        ResetButtonPosition()
    elseif cmd == "button" then
        EnsureButton()

        if IsBankSessionOpen() then
            print(OK_PREFIX .. " " .. T("GD_BUTTON_REFRESHED", "Button refreshed."))
        else
            print(ERROR_PREFIX .. " " .. T("GD_ERR_BUTTON_BANK_NOT_OPEN", "Bank is not open. Button will appear after opening a guild bank or warband bank."))
        end
    elseif cmd == "keep" then
        local amount = tonumber(arg)

        if amount and amount >= 0 then
            SetCurrentKeepGold(amount)
            print(string.format("%s " .. T("GD_KEEP_SET", "Now keeping %sg on the character.", "Теперь на персонаже остаётся %sз."), PREFIX, tostring(amount)))
            UpdateButton()
        else
            print(ERROR_PREFIX .. " " .. T("GD_ERR_KEEP_USAGE", "Enter a valid amount: /gd keep 200"))
        end
    elseif cmd == "status" then
        PrintStatus()
    else
        print(ERROR_PREFIX .. " " .. T("GD_ERR_UNKNOWN_COMMAND", "Unknown command. Type /gd help"))
    end
end

SLASH_HIRONCRAFT_PROFITGOLDDEPOSITOR1 = "/phgd"
SLASH_HIRONCRAFT_PROFITGOLDDEPOSITOR2 = "/gd"
SLASH_HIRONCRAFT_PROFITGOLDDEPOSITOR3 = "/ahuigd"
SlashCmdList["HIRONCRAFT_PROFITGOLDDEPOSITOR"] = HandleCommand

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("GUILDBANKFRAME_OPENED")
eventFrame:RegisterEvent("GUILDBANKFRAME_CLOSED")
eventFrame:RegisterEvent("GUILDBANK_UPDATE_MONEY")
eventFrame:RegisterEvent("GUILDBANK_UPDATE_TABS")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("BANKFRAME_CLOSED")
eventFrame:RegisterEvent("ACCOUNT_MONEY")
eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            EnsureDB()
            if IsModuleEnabled() then
                CreateButton()
            else
                HideButton()
            end
        elseif arg1 == "Blizzard_BankUI" and IsModuleEnabled() then
            InstallAccountBankHooks()
        end
        return
    elseif event == "PLAYER_LOGIN" then
        EnsureDB()
        if IsModuleEnabled() then
            CreateButton()
            InstallAccountBankHooks()
        else
            HideButton()
        end
        return
    end

    if not IsModuleEnabled() then
        HideButton()
        return
    end

    if event == "GUILDBANKFRAME_OPENED" then
        OnGuildBankSignal()
    elseif event == "GUILDBANK_UPDATE_MONEY" or event == "GUILDBANK_UPDATE_TABS" then
        if IsGuildBankFrameShown() then
            if currentBankType ~= BANK_TYPE_GUILD then
                OnGuildBankSignal()
            else
                UpdateButton()
            end
        else
            if currentBankType == BANK_TYPE_GUILD then
                MarkBankClosed(BANK_TYPE_GUILD)
            else
                UpdateButton()
            end
        end
    elseif event == "GUILDBANKFRAME_CLOSED" then
        MarkBankClosed(BANK_TYPE_GUILD)
    elseif event == "BANKFRAME_OPENED" then
        InstallAccountBankHooks()
        RunSoon(0.10, TryAccountBankSignal)
        RunSoon(0.35, TryAccountBankSignal)
    elseif event == "BANKFRAME_CLOSED" then
        if currentBankType == BANK_TYPE_ACCOUNT then
            MarkBankClosed(BANK_TYPE_ACCOUNT)
        end
    elseif event == "ACCOUNT_MONEY" then
        InstallAccountBankHooks()

        if currentBankType == BANK_TYPE_ACCOUNT then
            UpdateButton()
        elseif IsAccountBankPanelShown() then
            RunSoon(0.10, TryAccountBankSignal)
        end
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        if IsGuildBankerInteraction(arg1) then
            RunSoon(0.10, function()
                if IsGuildBankFrameShown() then
                    OnGuildBankSignal()
                end
            end)
        elseif IsAccountBankerInteraction(arg1) then
            RunSoon(0.10, TryAccountBankSignal)
            RunSoon(0.35, TryAccountBankSignal)
        else
            if currentBankType == BANK_TYPE_ACCOUNT and not IsAccountBankPanelShown() then
                MarkBankClosed(BANK_TYPE_ACCOUNT)
            else
                UpdateButton()
            end
        end
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        if IsGuildBankerInteraction(arg1) then
            MarkBankClosed(BANK_TYPE_GUILD)
        elseif IsAccountBankerInteraction(arg1) then
            MarkBankClosed(BANK_TYPE_ACCOUNT)
        else
            if currentBankType == BANK_TYPE_ACCOUNT then
                RunSoon(0.10, function()
                    if not IsAccountBankPanelShown() and not CanDepositAccountMoney() then
                        MarkBankClosed(BANK_TYPE_ACCOUNT)
                    end
                end)
            else
                UpdateButton()
            end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        UpdateButton()
    end
end)

local function ApplyEnabledState()
    EnsureDB()

    if not IsModuleEnabled() then
        bankSessionOpen = false
        currentBankType = nil
        autoDepositQueued = false
        autoDepositToken = autoDepositToken + 1
        HideButton()

        if keepPopup then
            keepPopup:Hide()
        end

        if settingsFrame then
            settingsFrame:Hide()
        end

        if Tooltip then
            Tooltip:Clear()
        end

        return
    end

    CreateButton()
    InstallAccountBankHooks()
    UpdateButton()
end

GD.IsEnabled = IsModuleEnabled
GD.ApplyEnabledState = ApplyEnabledState

GD.DepositGold = DepositGold
GD.ToggleAutoDeposit = ToggleAutoDeposit
GD.ResetButtonPosition = ResetButtonPosition
GD.OpenSettingsWindow = OpenSettingsWindow
GD.UpdateButton = UpdateButton
GD.ShowButton = ShowButton
GD.HideButton = HideButton
GD.GetDB = EnsureDB
GD.HandleCommand = HandleCommand
