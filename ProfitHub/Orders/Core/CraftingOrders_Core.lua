local E = _G.HironCraftProfitCraftingOrdersEnv
if not E then
    E = {}
    _G.HironCraftProfitCraftingOrdersEnv = E
    setmetatable(E, { __index = _G })
end
setfenv(1, E)

PT = HironCraftProfit
if not PT then return end
if not C_CraftingOrders or not C_TradeSkillUI then return end

L = PT.L or {}
Tooltip = PT.Tooltip
PT.CraftingOrders = PT.CraftingOrders or {}
CO = PT.CraftingOrders
_G.HironCraftProfitCraftingOrders = CO

-- The Orders locale can be Russian even on an English client. A direct
-- STANDARD_TEXT_FONT assignment bypasses Blizzard's font-family fallbacks.
FONT = PT.FONT or "Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\fonts\\default.ttf"
CO.FONT = FONT
ROW_BUTTON_W = 74
ROW_BUTTON_H = 28
ROW_CHECKBOX_SIZE = 22
ROW_CHECKBOX_HIT_PAD = 2
REAGENTS_COLUMN_W = 110
PROFIT_COLUMN_W = 90
REWARDS_COLUMN_W = 180
UNKNOWN_RECIPE_BORDER_LEVEL_OFFSET = 110
FOCUS_COLUMN_W = 22
QUALITY_BAR_W = 0
QUALITY_BAR_H = 10
CONC_BUTTON_SIZE = 22
COLUMN_GAP = 4
ROW_RIGHT_PAD = 6
MINI_ICON_SIZE = 26
REAGENT_QUALITY_BADGE_SIZE = 22
REAGENT_QUALITY_BADGE_X = 2
REAGENT_QUALITY_BADGE_Y = 2
MAX_REAGENT_ICONS = 8
REAGENT_TWO_ROW_THRESHOLD = 4
REAGENT_TWO_ROW_COLUMNS = 4


ORDER_ROW_TALL_H = 64
REAGENT_TWO_ROW_ICON_SIZE = MINI_ICON_SIZE
REAGENT_TWO_ROW_GAP_X = 2
REAGENT_TWO_ROW_GAP_Y = 2
REAGENT_TWO_ROW_BADGE_SIZE = REAGENT_QUALITY_BADGE_SIZE
MAX_REWARD_ICONS = 4
PANEL_W = 335
PANEL_H = 26
HOTKEY_PROXY_NAME = "HironCraftProfitCraftingOrdersHotkeyProxy"
CONCENTRATION_TEXTURE = "Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\media\\ui_concentration.tga"
CHECKMARK_ATLAS = "common-icon-checkmark"
RED_X_ATLAS = "common-icon-redx"
REAGENT_MISSING_X_SIZE = 10
REAGENT_QUALITY_OUTLINE_PAD = 1
ROW_REFRESH_DELAY = 0.12
PAGE_PROTECTOR_INTERVAL = 1.25
QUALITY_CACHE_TTL = 3.0
QUALITY_MISS_CACHE_TTL = 0.8
QUALITY_WARM_STEP_DELAY = 0.04
QUALITY_WARM_START_DELAY = 0.18
QUALITY_WARM_REQUEST_THROTTLE = 0.25
QUALITY_WARM_ATTEMPT_TTL = 6.0
CONCENTRATION_REQUIREMENT_CACHE_TTL = 30.0
CONCENTRATION_REQUIREMENT_VISUAL_HOLD_TTL = 8.0
CRAFTABLE_ORDER_VISUAL_HOLD_TTL = 8.0
ORDER_VISUAL_STALE_HOLD_TTL = 2.0
REAGENT_CACHE_TTL = 8.0
ROW_HOVER_ALPHA = 0.10
ROW_HOVER_BORDER_ALPHA = 0.32
EXTERNAL_PAGE_REAPPLY_DELAYS = { 0, 0.03, 0.12 }
HEADER_OVERLAY_H = 20
HEADER_OVERLAY_Y_OFFSET = 18

EXPANSION_MIDNIGHT = 11
EXPANSION_TWW = 10
EXPANSION_DF = 9
EXPANSION_DEFAULT_KEY = "midnight"
EXPANSION_OPTIONS = {
    { key = "midnight", expansionID = EXPANSION_MIDNIGHT, labelKey = "COA_EXPANSION_MIDNIGHT", fallback = "Midnight" },
    { key = "tww",      expansionID = EXPANSION_TWW,      labelKey = "COA_EXPANSION_TWW",      fallback = "TWW" },
    { key = "df",       expansionID = EXPANSION_DF,       labelKey = "COA_EXPANSION_DF",       fallback = "DF" },
}
EXPANSION_DBKEY_BY_ID = {
    [EXPANSION_DF] = "DF",
    [EXPANSION_TWW] = "TWW",
    [EXPANSION_MIDNIGHT] = "MID",
}

TRADE_SKILL_LINE_IDS_BY_EXPANSION = {}
function AddTradeSkillLineExpansionMap(profession, dfSkillLineID, twwSkillLineID, midnightSkillLineID)
    if not profession then return end
    TRADE_SKILL_LINE_IDS_BY_EXPANSION[profession] = {
        [EXPANSION_DF] = dfSkillLineID,
        [EXPANSION_TWW] = twwSkillLineID,
        [EXPANSION_MIDNIGHT] = midnightSkillLineID,
    }
end

if Enum and Enum.Profession then
    AddTradeSkillLineExpansionMap(Enum.Profession.Blacksmithing,  2822, 2872, 2907)
    AddTradeSkillLineExpansionMap(Enum.Profession.Leatherworking, 2830, 2880, 2915)
    AddTradeSkillLineExpansionMap(Enum.Profession.Alchemy,        2823, 2871, 2906)
    AddTradeSkillLineExpansionMap(Enum.Profession.Herbalism,      2832, 2877, 2912)
    AddTradeSkillLineExpansionMap(Enum.Profession.Cooking,        2824, 2873, 2908)
    AddTradeSkillLineExpansionMap(Enum.Profession.Mining,         2833, 2881, 2916)
    AddTradeSkillLineExpansionMap(Enum.Profession.Tailoring,      2831, 2883, 2918)
    AddTradeSkillLineExpansionMap(Enum.Profession.Engineering,    2827, 2875, 2910)
    AddTradeSkillLineExpansionMap(Enum.Profession.Enchanting,     2825, 2874, 2909)
    AddTradeSkillLineExpansionMap(Enum.Profession.Fishing,        2826, 2876, 2911)
    AddTradeSkillLineExpansionMap(Enum.Profession.Skinning,       2834, 2882, 2917)
    AddTradeSkillLineExpansionMap(Enum.Profession.Jewelcrafting,  2829, 2879, 2914)
    AddTradeSkillLineExpansionMap(Enum.Profession.Inscription,    2828, 2878, 2913)
end

CO.visibleRowButtons = CO.visibleRowButtons or {}
CO.rowStates = CO.rowStates or {}
CO.selectedOrders = CO.selectedOrders or {}
CO.rowButtonsByOrderID = CO.rowButtonsByOrderID or {}
CO.orderIssues = CO.orderIssues or {}
CO.selectedReagents = CO.selectedReagents or {}
CO.useConcentration = CO.useConcentration or {}
CO.qualityCache = CO.qualityCache or {}
CO.concentrationRequirementCache = CO.concentrationRequirementCache or {}
CO.concentrationRequirementVisualCache = CO.concentrationRequirementVisualCache or {}
CO.craftableOrderVisualCache = CO.craftableOrderVisualCache or {}
CO.displayReagentsCache = CO.displayReagentsCache or {}
CO.craftingReagentInfoCache = CO.craftingReagentInfoCache or {}
CO.orderCacheRevision = CO.orderCacheRevision or {}
CO.orderExpansionCache = CO.orderExpansionCache or {}

function T(key, fallback)
    return (L and L[key]) or fallback or key
end

local function IsStyledTooltipOwnerVisible(owner)
    if not owner or not owner.IsShown or not owner:IsShown() then
        return false
    end

    if owner.IsVisible and not owner:IsVisible() then
        return false
    end

    return true
end

local function StopStyledTooltipWatcher()
    if CO.styledTooltipWatcher and CO.styledTooltipWatcher.Cancel then
        CO.styledTooltipWatcher:Cancel()
    end

    CO.styledTooltipWatcher = nil
    CO.styledTooltipWatcherOwner = nil
    CO.styledTooltipOwner = nil
end

local function StartStyledTooltipWatcher(owner)
    CO.styledTooltipOwner = owner

    if CO.styledTooltipWatcherOwner == owner and CO.styledTooltipWatcher then
        return
    end

    if CO.styledTooltipWatcher and CO.styledTooltipWatcher.Cancel then
        CO.styledTooltipWatcher:Cancel()
    end

    CO.styledTooltipWatcherOwner = owner

    if not C_Timer or not C_Timer.NewTicker then
        return
    end

    CO.styledTooltipWatcher = C_Timer.NewTicker(0.05, function(ticker)
        local currentOwner = CO.styledTooltipOwner
        local frame = Tooltip and Tooltip.frame

        if not currentOwner or not frame or not frame:IsShown() then
            ticker:Cancel()
            if CO.styledTooltipWatcher == ticker then
                CO.styledTooltipWatcher = nil
                CO.styledTooltipWatcherOwner = nil
            end
            return
        end

        if not IsStyledTooltipOwnerVisible(currentOwner) then
            HideStyledTooltip()
        end
    end)
end

function HideStyledTooltip()
    StopStyledTooltipWatcher()

    if Tooltip and Tooltip.Clear then
        Tooltip:Clear()
    end
end

function ShowStyledTooltip(owner)
    StartStyledTooltipWatcher(owner)

    if Tooltip and Tooltip.ShowCursorRightOrBelow then
        Tooltip:ShowCursorRightOrBelow(12, 10)
    elseif Tooltip and Tooltip.ShowSmart then
        Tooltip:ShowSmart(owner)
    end
end

function ShowGameTooltipCursorRightOrBelow(offsetX, offsetY)
    if Tooltip and Tooltip.ShowGameTooltipCursorRightOrBelow then
        Tooltip:ShowGameTooltipCursorRightOrBelow(offsetX or 12, offsetY or 10)
    elseif GameTooltip then
        GameTooltip:Show()
    end
end

function IsFrameMouseOver(frame)
    if not frame or not frame.IsShown or not frame:IsShown() then return false end
    if frame.IsMouseOver then
        return frame:IsMouseOver()
    end
    if MouseIsOver then
        return MouseIsOver(frame)
    end
    return false
end

function OrderKey(orderID)
    if orderID == nil then return nil end
    return tostring(orderID)
end


function CacheNow()
    return GetTime and GetTime() or 0
end

function StartsWith(value, prefix)
    return type(value) == "string" and type(prefix) == "string" and value:sub(1, #prefix) == prefix
end

function CO:HoldOrderVisualState(duration)
    local untilTime = CacheNow() + (tonumber(duration) or ORDER_VISUAL_STALE_HOLD_TTL or 2.0)
    self.orderVisualStateHoldUntil = math.max(tonumber(self.orderVisualStateHoldUntil) or 0, untilTime)
end

function CO:IsOrderVisualStateHoldActive()
    return (tonumber(self.orderVisualStateHoldUntil) or 0) > CacheNow()
end

function CO:InvalidateOrderCaches(orderID)
    local key = OrderKey(orderID)
    if not key then
        self:HoldOrderVisualState(ORDER_VISUAL_STALE_HOLD_TTL)
    end

    local preserveVisualCaches = self.pendingClaimOrderID ~= nil
        or self.pendingCraftOrderID ~= nil
        or self.pendingFulfillOrderID ~= nil
        or self.pendingReleaseOrderID ~= nil
        or self.progressOrderID ~= nil
        or self.pendingCraftButton ~= nil
        or self.progressActive == true
        or self:IsOrderVisualStateHoldActive()

    if not key then
        wipe(self.qualityCache)
        wipe(self.concentrationRequirementCache)
        if not preserveVisualCaches then
            wipe(self.concentrationRequirementVisualCache)
            wipe(self.craftableOrderVisualCache)
        end
        wipe(self.displayReagentsCache)
        wipe(self.craftingReagentInfoCache)
        wipe(self.orderCacheRevision)
        return
    end

    self.displayReagentsCache[key] = nil
    self.craftingReagentInfoCache[key] = nil
    self.orderCacheRevision[key] = (tonumber(self.orderCacheRevision[key]) or 0) + 1

    local prefix = key .. ":"
    for cacheKey in pairs(self.qualityCache or {}) do
        if StartsWith(cacheKey, prefix) then
            self.qualityCache[cacheKey] = nil
        end
    end
    for cacheKey in pairs(self.concentrationRequirementCache or {}) do
        if StartsWith(cacheKey, prefix) then
            self.concentrationRequirementCache[cacheKey] = nil
        end
    end
    if not preserveVisualCaches then
        for cacheKey in pairs(self.concentrationRequirementVisualCache or {}) do
            if StartsWith(cacheKey, prefix) then
                self.concentrationRequirementVisualCache[cacheKey] = nil
            end
        end
        if self.craftableOrderVisualCache then
            self.craftableOrderVisualCache[key] = nil
        end
    end
end

function GetOrderRevision(self, orderID)
    local key = OrderKey(orderID)
    return key and (tonumber(self.orderCacheRevision[key]) or 0) or 0
end

function ApplyFont(fs, size, flags)
    if fs and fs.SetFont then
        fs:SetFont(FONT, size or 12, flags or "")
    end
end

function CreateBackdrop(frame, alpha)
    if not frame or not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.02, 0.02, 0.025, alpha or 0.92)
    frame:SetBackdropBorderColor(1, 1, 1, 0.12)
end

function GetDB()
    HironCraftProfit_Config = HironCraftProfit_Config or {}
    HironCraftProfit_Config.craftingOrders = HironCraftProfit_Config.craftingOrders or {}
    local db = HironCraftProfit_Config.craftingOrders
    -- One-time: force action diagnostics off for anyone who had it on (now enabled via Shift+RMB).
    if not db._debugForcedOff then
        db._debugForcedOff = true
        db.debugActions = false
    end
    if db.cachedOrders then
        db.cachedOrders = nil
    end
    return db
end

function CO:IsEnabled()
    return true
end

function CO:SetEnabled(enabled)
    PT.config = PT.config or {}
    PT.config.craftingOrdersEnabled = enabled == true
    self:ApplyEnabledState()
end

local KNOWN_CO_CONFLICTING_ADDONS = {
    { addon = "PublicOrdersReagentsColumn", fingerprints = { "PublicOrdersReagentsColumn" } },
}

local FRAME_NAME_SAFE_PREFIXES = {
    "HironCraftProfit", "Ahui",
    "Blizzard", "Professions", "Tradeskill", "C_TradeSkill",
    "UIParent",
}

local FRAME_PREFIX_TO_ADDON = {
    ["PublicOrders"] = "PublicOrdersReagentsColumn",
}

local function NameLooksForeign(name)
    if type(name) ~= "string" or name == "" then return false end
    for _, prefix in ipairs(FRAME_NAME_SAFE_PREFIXES) do
        if name:sub(1, #prefix) == prefix then return false end
    end
    local prefix = name:match("^(%a[%w]*)")
    if not prefix then return false end
    return true, prefix
end

function CO:GetAddonForFramePrefix(prefix)
    return FRAME_PREFIX_TO_ADDON[prefix] or prefix
end

function CO:DetectConflictingAddons()
    local seen = {}
    local out = {}
    local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded

    for _, entry in ipairs(KNOWN_CO_CONFLICTING_ADDONS) do
        local loaded = false
        if type(isLoaded) == "function" then
            local ok, value = pcall(isLoaded, entry.addon)
            if ok and (value == true or value == 1) then
                loaded = true
            end
        end

        local hasFingerprint = false
        for _, fp in ipairs(entry.fingerprints or {}) do
            if _G[fp] ~= nil then
                hasFingerprint = true
                break
            end
        end

        if loaded and hasFingerprint and not seen[entry.addon] then
            seen[entry.addon] = true
            out[#out + 1] = entry.addon
        end
    end

    return out
end

function CO:ScanForeignFramesInOrdersPage()
    local out = {}
    local pageFrame = (self.FindOrderPageFrame and self:FindOrderPageFrame()) or self.activePageFrame
    if not pageFrame or type(pageFrame.GetChildren) ~= "function" then return out end

    local seen = {}
    local function walk(frame, depth)
        if not frame or depth > 4 then return end
        if type(frame.GetChildren) ~= "function" then return end

        local children = { frame:GetChildren() }
        for _, child in ipairs(children) do
            if type(child) == "table" and type(child.GetName) == "function" then
                local ok, name = pcall(child.GetName, child)
                if ok and name and not seen[name] then
                    seen[name] = true
                    local foreign, prefix = NameLooksForeign(name)
                    if foreign then
                        out[#out + 1] = { name = name, prefix = prefix }
                    end
                end
                walk(child, depth + 1)
            end
        end
    end

    walk(pageFrame, 0)
    return out
end

function CO:IsConflictWarningDismissed()
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    return HironCraftProfit_DB.craftingOrdersConflictDismissed == true
end

function CO:DismissConflictWarning()
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB.craftingOrdersConflictDismissed = true
end

function CO:ResetConflictWarning()
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB.craftingOrdersConflictDismissed = nil
end

function CO:WarnAboutConflictsIfNeeded()
    if not self:IsEnabled() then return end
    if self:IsConflictWarningDismissed() then return end

    local detected = self:DetectConflictingAddons()
    if #detected == 0 then return end

    local warnText = L and L.CO_CONFLICT_WARNING or "Other addons may also manage crafting orders"
    local hintText = L and L.CO_CONFLICT_HINT or "Disable one of them to avoid data overlap. /ahuico off — disable HironCraftProfit module. /ahuico dismiss — hide this warning."

    local msg = "|cff33ccffHironCraftProfit Crafting Orders:|r "
        .. warnText
        .. ": |cffffd200" .. table.concat(detected, ", ") .. "|r. "
        .. hintText

    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(msg)
    end
end

function NormalizeBindingKey(key)
    if not key or key == "" or key == "UNKNOWN" then
        return nil
    end

    key = key:upper()

    if key == "LSHIFT" or key == "RSHIFT"
    or key == "LCTRL" or key == "RCTRL"
    or key == "LALT" or key == "RALT" then
        return nil
    end

    local parts = {}
    if IsControlKeyDown() then parts[#parts + 1] = "CTRL" end
    if IsAltKeyDown() then parts[#parts + 1] = "ALT" end
    if IsShiftKeyDown() then parts[#parts + 1] = "SHIFT" end
    parts[#parts + 1] = key
    return table.concat(parts, "-")
end

function BindingText(binding)
    if not binding or binding == "" then
        return T("COA_BINDING_NONE", "Not assigned")
    end
    local text = _G.GetBindingText and _G.GetBindingText(binding, "KEY_")
    return text and text ~= "" and text or binding
end

function IsOrderCreated(order)
    return order and Enum and Enum.CraftingOrderState and order.orderState == Enum.CraftingOrderState.Created
end

function IsOrderClaimed(order)
    return order and Enum and Enum.CraftingOrderState and order.orderState == Enum.CraftingOrderState.Claimed
end


function SameOrderID(a, b)
    if a == nil or b == nil then return false end
    return tostring(a) == tostring(b)
end

function GetProfessionsTableColumnWidth(key, fallback)
    local PTC = _G.ProfessionsTableConstants
    local spec = PTC and PTC[key]
    local width = spec and tonumber(spec.Width)
    return width or fallback
end

function GetOrderListTableWidth(pageFrame)
    local width

    local orderList = pageFrame and pageFrame.BrowseFrame and pageFrame.BrowseFrame.OrderList
    local scrollBox = orderList and orderList.ScrollBox

    if scrollBox and scrollBox.GetWidth then
        width = scrollBox:GetWidth()
    end

    if (not width or width <= 0) and orderList and orderList.GetWidth then
        width = orderList:GetWidth()
    end

    if (not width or width <= 0) and pageFrame and pageFrame.BrowseFrame and pageFrame.BrowseFrame.GetWidth then
        width = pageFrame.BrowseFrame:GetWidth()
    end

    width = tonumber(width) or 777


    return math.max(777, math.floor(width - 8))
end

function GetOrderTableColumnWidths()
    return {
        expiration = GetProfessionsTableColumnWidth("Expiration", math.max(ROW_BUTTON_W, 60)),


        profit     = 0,
        reagents   = GetProfessionsTableColumnWidth("Reagents", REAGENTS_COLUMN_W + 8),
        tip        = GetProfessionsTableColumnWidth("Tip", REWARDS_COLUMN_W + 8),
        customer   = GetProfessionsTableColumnWidth("CustomerName", FOCUS_COLUMN_W + 8),
    }
end

LOCKED_ORDER_COLUMN_WIDTHS = {
    CustomerName = FOCUS_COLUMN_W + 8,
    Tip          = REWARDS_COLUMN_W + 8,
    Reagents     = REAGENTS_COLUMN_W + 8,
    Expiration   = math.max(ROW_BUTTON_W, 60),
}

LOCKED_ORDER_COLUMN_LABELS = {
    CustomerName = "",
    Tip          = "COA_HDR_REWARDS",
    Reagents     = "COA_HDR_REAGENTS",
    Expiration   = "COA_HDR_ACTION",
}

LOCKED_ORDER_COLUMN_FALLBACKS = {
    CustomerName = "",
    Tip          = "Rewards",
    Reagents     = "Reagents",
    Expiration   = "Action",
}

ORDER_COLUMN_TEXT_FIELDS = {
    "Label", "label", "Text", "text", "Header", "header", "HeaderText", "headerText", "Name", "name", "Title", "title", "TextKey", "textKey", "LabelKey", "labelKey",
}

function CopyPrimitiveTableFields(source)
    local out = {}
    if type(source) ~= "table" then return out end
    for k, v in pairs(source) do
        if type(v) ~= "table" and type(v) ~= "function" then
            out[k] = v
        end
    end
    return out
end
