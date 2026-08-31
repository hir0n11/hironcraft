local addonName = ...

HironCraftProfit = HironCraftProfit or {}
local PT = HironCraftProfit

HironCraft = PT

PT.professionsReady = false

local function KillLegacyHironCraftProfitState()
    if not PT then return end
    if PT.Bar then
        local bar = PT.Bar

        if bar.frame then
            bar.frame:Hide()
            bar.frame:SetParent(nil)
        end

        if bar.panels then
            for _, p in pairs(bar.panels) do
                if type(p) == "table" and p.frame then
                    p.frame:Hide()
                    p.frame:SetParent(nil)
                elseif type(p) == "table" and p.Hide then
                    p:Hide()
                    p:SetParent(nil)
                end
            end
        end

        PT.Bar = nil
    end

    PT.RegisteredDataTexts = nil
    PT.tooltipFunc = nil

    local f = _G["HironCraftProfit_BarFrame"]
    if f then
        f:Hide()
        f:SetParent(nil)
        _G["HironCraftProfit_BarFrame"] = nil
    end

    for i = 1, 50 do
        local pn = _G["HironCraftProfit_Panel_" .. i]
        if pn then
            pn:Hide()
            pn:SetParent(nil)
            _G["HironCraftProfit_Panel_" .. i] = nil
        end
    end
end

KillLegacyHironCraftProfitState()

PT.DB      = PT.DB or {}
PT.modules = PT.modules or {}

HironCraftProfit_DB         = HironCraftProfit_DB or {}
HironCraftProfit_CharConfig = HironCraftProfit_CharConfig or {}

HironCraftProfit_DB.saveMode = HironCraftProfit_DB.saveMode or "account"

function PT:GetConfigDB()
    if HironCraftProfit_DB.saveMode == "character" then
        HironCraftProfit_CharConfig.config = HironCraftProfit_CharConfig.config or {}
        return HironCraftProfit_CharConfig.config
    end

    HironCraftProfit_DB.config = HironCraftProfit_DB.config or {}
    return HironCraftProfit_DB.config
end

PT.config = PT:GetConfigDB()

if HironCraftProfit_CharConfig.autoLootInitialized == nil then
    HironCraftProfit_CharConfig.autoLootInitialized = false
end

if HironCraftProfit_CharConfig.showProfessionsWindow == nil then
    HironCraftProfit_CharConfig.showProfessionsWindow = true
end

if HironCraftProfit_CharConfig.skinningCheckEnabled == nil then
    HironCraftProfit_CharConfig.skinningCheckEnabled = true
end

HironCraftProfit_CharConfig.skinningIconSize = HironCraftProfit_CharConfig.skinningIconSize or 32

HironCraftProfit_DB.minimap = HironCraftProfit_DB.minimap or { hide = false }

local defaultConfig = {
    showAllProfessions      = false,
    minimized               = false,
    hideCatchUp             = false,
    weekly                  = false,
    hideMaxedProfession     = false,
    hideWhenDone            = false,
    hideTreatise            = false,
    showConcentration       = true,
    showProfessionsWindow   = true,
    lockWindows             = false,
	hideProfessionsInCombat      = true,
	hideConcentrationInCombat    = true,
	hideSkinningInCombat         = true,
	hideSkinningInInstance 		 = true,
	hideProfessionsInInstance    = true,
	hideConcentrationInInstance  = true,

	skinningCheckEnabled         = true,
	skinningIconSize             = 50,

    showMapKnowledge             = true,
    showMapLures                 = true,
    mapPinsSize                  = 30,

    stackAssistEnabled           = true,
    goldDepositorEnabled         = true,
    shoppingListAlwaysShowTab    = true,
    questShoppingEnabled         = true,
}

local function ApplyDefaultConfig()
    for k, v in pairs(defaultConfig) do
        if PT.config[k] == nil then
            PT.config[k] = v
        end
    end
end

ApplyDefaultConfig()

if not PT.config._forceEnableModulesV1 then
    PT.config._forceEnableModulesV1 = true
    PT.config.stackAssistEnabled    = true
    PT.config.goldDepositorEnabled  = true
    PT.config.questShoppingEnabled  = true
    PT.config.craftingOrdersEnabled = true
end

if not PT.config._forceShopTabV1 then
    PT.config._forceShopTabV1 = true
    PT.config.shoppingListAlwaysShowTab = true
end

function PT:IsInRestrictedInstance()
    local inInstance, instanceType = IsInInstance()
    if not inInstance then return false end

    return instanceType == "party"
        or instanceType == "raid"
        or instanceType == "arena"
        or instanceType == "pvp"
        or instanceType == "scenario"
end

PT._visibilityFrames = {}
PT._inCombat = false

function PT:RegisterVisibilityFrame(frame, combatKey, instanceKey, showKey)
    if not frame then return end

    self._visibilityFrames = self._visibilityFrames or {}

    self._visibilityFrames[frame] = {
        combatKey   = combatKey,
        instanceKey = instanceKey,
        showKey     = showKey,
    }
end

local function ShouldHideFrame(data)

    if data.showKey and PT.config[data.showKey] == false then
        return true
    end

    if data.combatKey
       and PT.config[data.combatKey]
       and PT._inCombat
    then
        return true
    end

    if data.instanceKey
       and PT.config[data.instanceKey]
       and PT:IsInRestrictedInstance()
    then
        return true
    end

    return false
end

function PT:UpdateVisibility()
    for frame, data in pairs(self._visibilityFrames) do
        if frame then
            if ShouldHideFrame(data) then
                if frame:IsShown() then
                    frame:Hide()
                end
            else
                if not frame:IsShown() then
                    frame:Show()
                end
            end
        end
    end
end

PT.collapsedProfessions = PT.collapsedProfessions or {}
PT.collapsedCategories  = PT.collapsedCategories  or {}

PT.FONT      = "Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\fonts\\default.ttf"
PT.SCALE_DEFAULT = 1.0
PT.SCALE_STEP    = 0.05
PT.SCALE_MIN     = 0.7
PT.SCALE_MAX     = 2.5

function PT.NormalizeItemId(v)
    if type(v) == "number" then return v end
    if type(v) == "string" then return tonumber(v) end
    if type(v) == "table" then
        if type(v.id) == "number" then return v.id end
        if type(v[1]) == "number" then return v[1] end
    end
    return nil
end

function PT:RefreshData()
    if PT.GetProfessions then
        PT.professions = PT.GetProfessions(true)
    end
end

local function InitAutoLootForNewChar()
    if HironCraftProfit_CharConfig.autoLootInitialized then
        return
    end

    if C_CVar and C_CVar.SetCVar then
        C_CVar.SetCVar("autoLootDefault", "1")
    else
        SetCVar("autoLootDefault", 1)
    end

    HironCraftProfit_CharConfig.autoLootInitialized = true
end

local f = CreateFrame("Frame")
PT.eventFrame = f

local _bagRefreshPending = false

f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")

f:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= addonName then return end

        HironCraftProfit_DB         = HironCraftProfit_DB or {}
        HironCraftProfit_CharConfig = HironCraftProfit_CharConfig or {}

        if PT.RebuildLocale then PT.RebuildLocale() end

        if not HironCraftProfit_DB._configMigrated then
            HironCraftProfit_DB.config = HironCraftProfit_DB.config or {}

            for k, v in pairs(HironCraftProfit_DB) do
                if type(v) ~= "table"
                   and k ~= "saveMode"
                   and k ~= "_configMigrated"
                then
                    HironCraftProfit_DB.config[k] = v
                end
            end

            HironCraftProfit_DB._configMigrated = true
        end

        PT.config = PT:GetConfigDB()
        ApplyDefaultConfig()
		
if HironCraftProfit_CharConfig.showProfessionsWindow ~= nil then
    if PT.config.showProfessionsWindow == nil then
        PT.config.showProfessionsWindow = HironCraftProfit_CharConfig.showProfessionsWindow
    end
    HironCraftProfit_CharConfig.showProfessionsWindow = nil
end

        PT.LoadActiveDB()
        PT:RefreshData()
        PT:RefreshUI()

        if PT.Settings and PT.Settings.Register then
            PT.Settings:Register()
        end

    elseif event == "PLAYER_LOGIN" then
        InitAutoLootForNewChar()
        PT.professionsReady = false
        PT:RefreshUI()
        PT:UpdateVisibility()

        if PT.config.lockWindows then
            if PT.UI and PT.UI.frame then
                PT.UI.frame:SetMovable(false)
                PT.UI.frame:EnableMouse(false)
            end
            if PT.ConcentrationUI and PT.ConcentrationUI.frame then
                PT.ConcentrationUI.frame:SetMovable(false)
                PT.ConcentrationUI.frame:EnableMouse(false)
            end
        end

    elseif event == "TRADE_SKILL_DATA_SOURCE_CHANGED" then
        PT.professions = nil
        PT.professionsReady = true
        PT:RefreshData()
        PT:RefreshUI()

    elseif event == "PLAYER_ENTERING_WORLD"
        or event == "QUEST_LOG_UPDATE"
        or event == "CURRENCY_DISPLAY_UPDATE"
        or event == "SKILL_LINES_CHANGED"
    then
        PT.professions = nil
        PT:RefreshData()
        PT:RefreshUI()

    elseif event == "BAG_UPDATE_DELAYED" then
        if not _bagRefreshPending then
            _bagRefreshPending = true
            C_Timer.After(0.1, function()
                _bagRefreshPending = false
                PT.professions = nil
                PT:RefreshData()
                PT:RefreshUI()
            end)
        end

    elseif event == "PLAYER_REGEN_DISABLED" then
        PT._inCombat = true
        PT:UpdateVisibility()

    elseif event == "PLAYER_REGEN_ENABLED" then
        PT._inCombat = false
        PT:UpdateVisibility()

    elseif event == "ZONE_CHANGED_NEW_AREA" then
        PT:UpdateVisibility()
    end
end)

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("QUEST_LOG_UPDATE")
f:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("SKILL_LINES_CHANGED")
f:RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")