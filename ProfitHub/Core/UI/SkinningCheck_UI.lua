local PT = HironCraftProfit
if not PT then return end

local Tooltip = PT.Tooltip
local L = PT.L or {}

local UI = {}
PT.UI_SkinningCheck = UI

local function GetSC()
    local mod = PT and PT.SkinningCheck
    if type(mod) ~= "table" then
        return nil
    end
    return mod
end

if not GetSC() then
    return
end

PT.config = PT.config or {}

local FONT = HironCraftProfit.FONT
local ICON_TEXTURE = "Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\media\\skinning.tga"

PT.config.skinningCheckEnabled = PT.config.skinningCheckEnabled ~= false
PT.config.skinningIconSize = PT.config.skinningIconSize or 50

local function GetIconSize()
    local v = PT.config.skinningIconSize or 50
    return math.max(20, math.min(300, v))
end

local function IsInCombatLockdown()
    return InCombatLockdown and InCombatLockdown()
end

local function SyncSkinningToAccountOverview()
    if PT.AccountOverview_Data
       and PT.AccountOverview_Data.SaveCurrentCharacterSkinningSnapshot
    then
        PT.AccountOverview_Data:SaveCurrentCharacterSkinningSnapshot()
    end

    if PT.AccountOverview and PT.AccountOverview.Refresh then
        PT.AccountOverview:Refresh()
    end
end

function UI:StopMenuRefreshTicker()
    if self.menuRefreshTicker then
        self.menuRefreshTicker:Cancel()
        self.menuRefreshTicker = nil
    end
end

function UI:RefreshRowUseAction(row)
    local SC = GetSC()
    if not SC or not row or not row._item then
        return
    end

    if IsInCombatLockdown() then
        return
    end

    local lureItemID = row._item.guide and row._item.guide.lureItem
    local bagSlot = SC:GetLureBagSlotString(row._item)
    local count = lureItemID and SC:CountItemInBags(lureItemID) or 0

    local craftable = nil
    if SC.GetGuideCraftableLureCount then
        craftable = SC:GetGuideCraftableLureCount(row._item)
    end

    row._hasBagItem = count > 0

    if bagSlot then
        row:SetAttribute("type2", "item")
        row:SetAttribute("item2", bagSlot)
        row:SetAttribute("macrotext2", nil)
    else
        row:SetAttribute("type2", nil)
        row:SetAttribute("item2", nil)
        row:SetAttribute("macrotext2", nil)
    end

    if row.countText then
        local text = tostring(count)

        if craftable ~= nil then
            text = text .. " (" .. tostring(craftable) .. ")"
        end

        row.countText:SetText(text)
        row.countText:SetAlpha((count > 0 or (craftable and craftable > 0)) and 1 or 0.45)
    end
end

function UI:RefreshMenuUseActions()
    if not self.menu or not self.menu:IsShown() or not self.menu.items then
        return
    end

    for _, row in ipairs(self.menu.items) do
        self:RefreshRowUseAction(row)
    end
end

function UI:StartMenuRefreshTicker()
    self:StopMenuRefreshTicker()

    self.menuRefreshTicker = C_Timer.NewTicker(0.2, function()
        if not UI.menu or not UI.menu:IsShown() then
            UI:StopMenuRefreshTicker()
            return
        end

        UI:RefreshMenuUseActions()
    end)
end

function UI:CreateIcon()
    if self.icon then return self.icon end

    local SC = GetSC()
    if not SC or type(SC.IsAvailable) ~= "function" then
        return nil
    end

    if not SC:IsAvailable() then
        return nil
    end

    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB.positions = HironCraftProfit_DB.positions or {}

    if not HironCraftProfit_DB.positions.skinningIcon then
        HironCraftProfit_DB.positions.skinningIcon = {
            point = "CENTER",
            relPoint = "CENTER",
            x = 0,
            y = 0,
        }
    end

    local cfg = HironCraftProfit_DB.positions.skinningIcon

    local f = CreateFrame("Button", "HironCraftProfitSkinningIcon", UIParent)

    local size = GetIconSize()
    f:SetSize(size, size)
    f:SetPoint(cfg.point, UIParent, cfg.relPoint or cfg.point, cfg.x, cfg.y)

    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        cfg.point = point
        cfg.relPoint = relPoint
        cfg.x = x
        cfg.y = y
    end)

    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture(ICON_TEXTURE)
    f.iconTex = tex

    local ring = f:CreateTexture(nil, "OVERLAY")
    ring:SetTexture("Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\media\\glow_ring.tga")
    ring:SetPoint("TOPLEFT", f, "TOPLEFT", -12, 12)
    ring:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 12, -12)
    ring:SetAlpha(1)
    ring:Hide()
    f.ring = ring
    f.ringFadeAlpha = 0
    f.ringFadeDir   = 1

    local lureBg = f:CreateTexture(nil, "OVERLAY", nil, 1)
    lureBg:SetColorTexture(0.04, 0.04, 0.06, 0.92)
    lureBg:Hide()
    f.lureBg = lureBg

    local lureMask = f:CreateMaskTexture()
    lureMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    lureMask:SetAllPoints(lureBg)
    lureBg:AddMaskTexture(lureMask)

    local lureRing = f:CreateTexture(nil, "OVERLAY", nil, 2)
    lureRing:SetAtlas("services-cover-ring")
    lureRing:Hide()
    f.lureRing = lureRing

    local lureNum = f:CreateFontString(nil, "OVERLAY")
    lureNum:SetDrawLayer("OVERLAY", 7)
    lureNum:SetPoint("CENTER", lureRing, "CENTER", 0, 0)
    lureNum:SetFont(HironCraftProfit.FONT, 16, "OUTLINE")
    lureNum:SetTextColor(1, 0.95, 0.6)
    lureNum:Hide()
    f.lureNum = lureNum

    f:SetScript("OnUpdate", function(self, elapsed)
        if not self.ring or not self.ring:IsShown() then return end

        local speed = 1.2
        self.ringFadeAlpha = self.ringFadeAlpha + elapsed * speed * self.ringFadeDir

        if self.ringFadeAlpha >= 1 then
            self.ringFadeAlpha = 1
            self.ringFadeDir = -1
        elseif self.ringFadeAlpha <= 0 then
            self.ringFadeAlpha = 0
            self.ringFadeDir = 1
        end

        self.ring:SetAlpha(self.ringFadeAlpha)
    end)

    f:SetScript("OnEnter", function()
        local SC = GetSC()
        if not SC or type(SC.IsAvailable) ~= "function" then return end
        if not SC:IsAvailable() then return end

        Tooltip:Clear()
        Tooltip:AddLine(L["SKINNING_TITLE"], 14, 1, 1, 1)
        Tooltip:AddLine(SC:GetIconTooltip(), 12, 0.85, 0.85, 0.85)
        if type(SC.GetLureShoppingMaterials) == "function" and #SC:GetLureShoppingMaterials() > 0 then
            Tooltip:AddLine(" ", 6)
            Tooltip:AddLine(L["SKINNING_LURE_RMB_HINT"] or "ПКМ — отправить недостающие реагенты приманок в Закуп", 11, 0.6, 0.85, 1)
        end
        Tooltip:ShowAtCursor()
    end)

    f:SetScript("OnLeave", function()
        Tooltip:Clear()
    end)

    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f:SetScript("OnClick", function(_, btn)
        if btn == "LeftButton" then
            UI:ToggleMenu()
        elseif btn == "RightButton" then
            UI:SendLureShopping()
        end
    end)

    self.icon = f

    PT:RegisterVisibilityFrame(
        f,
        "hideSkinningInCombat",
        "hideSkinningInInstance",
        "skinningCheckEnabled"
    )

    PT:UpdateVisibility()
    return f
end

function UI:SendLureShopping()
    local SC = GetSC()
    if not SC or type(SC.GetLureShoppingMaterials) ~= "function" then return end

    local materials = SC:GetLureShoppingMaterials()
    if not materials or #materials == 0 then
        print("|cffb19cd9HironCraft|r " .. (L["SKINNING_LURE_SHOP_NONE"] or "Хватает реагентов на все приманки."))
        return
    end

    local Shop = HironCraftProfit and HironCraftProfit.ShoppingList
    if not Shop or type(Shop.CreateTemporaryImportedList) ~= "function" then
        print("|cffb19cd9HironCraft|r " .. (L["SKINNING_LURE_SHOP_NA"] or "Модуль Закуп недоступен."))
        return
    end

    Shop:CreateTemporaryImportedList(L["SKINNING_LURE_LIST"] or "Приманки — реагенты", materials, "skinning_lure")
end

function UI:UpdateLureBadge()
    local f = self.icon
    if not f or not f.lureRing then return end

    local SC = GetSC()
    local count = (SC and type(SC.GetActionableLureCount) == "function" and SC:GetActionableLureCount()) or 0

    if count <= 0 then
        f.lureRing:Hide()
        if f.lureNum then f.lureNum:Hide() end
        if f.lureBg then f.lureBg:Hide() end
        return
    end

    local size = GetIconSize()
    local ringSize = math.max(10, size * 0.40)
    f.lureRing:SetSize(ringSize, ringSize)
    f.lureRing:ClearAllPoints()
    f.lureRing:SetPoint("CENTER", f, "BOTTOMRIGHT", -ringSize * 0.30, ringSize * 0.30)
    f.lureRing:Show()

    if f.lureBg then
        local bgSize = ringSize * 0.82
        f.lureBg:SetSize(bgSize, bgSize)
        f.lureBg:ClearAllPoints()
        f.lureBg:SetPoint("CENTER", f.lureRing, "CENTER", 0, 0)
        f.lureBg:Show()
    end

    if f.lureNum then
        local fontSize = math.max(10, math.floor(ringSize * 0.5))
        f.lureNum:SetFont(HironCraftProfit.FONT, fontSize, "OUTLINE")
        f.lureNum:SetText(count > 99 and "99+" or tostring(count))
        f.lureNum:Show()
    end
end

function UI:Update()
    local SC = GetSC()
    if not SC or type(SC.IsAvailable) ~= "function" then
        if self.icon then
            self.icon:Hide()
        end
        return
    end

    if not PT.config.skinningCheckEnabled then
        if self.icon then
            self.icon:Hide()
        end
        return
    end

    if not SC:IsAvailable() then
        if self.icon then
            self.icon:Hide()
        end
        return
    end

    if not self.icon then
        self:CreateIcon()
    end

    if not self.icon then
        return
    end

    if PT.UpdateVisibility then
        PT:UpdateVisibility()
    end

    local size = GetIconSize()
    if IsInCombatLockdown() then
        self._pendingIconSize = size
    else
        if self.icon:GetWidth() ~= size or self.icon:GetHeight() ~= size then
            self.icon:SetSize(size, size)
        end
        self._pendingIconSize = nil
    end

    if SC:HasMissingItems() then
        self.icon:SetAlpha(1)
        if self.icon.ring then
            self.icon.ring:Show()
            self.icon.ringFadeAlpha = 0
            self.icon.ringFadeDir = 1
        end
    else
        self.icon:SetAlpha(0.5)
        if self.icon.ring then
            self.icon.ring:Hide()
        end
    end

    self:UpdateLureBadge()
end

function UI:CreateMenu()
    if self.menu then return self.menu end

    local f = CreateFrame("Frame", "HironCraftProfitSkinningMenu", UIParent, "BackdropTemplate")
    f:SetFrameStrata("HIGH")
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    f:SetBackdropColor(0, 0, 0, 0.7)
    f:SetBackdropBorderColor(0, 0, 0, 1)
    f:Hide()

    self.menu = f
    return f
end

function UI:ToggleMenu()
    local SC = GetSC()
    if not SC or type(SC.GetMissingItems) ~= "function" then
        return
    end

    if not self.menu then self:CreateMenu() end

    if self.menu:IsShown() then
        self:HideMenu()
        return
    end

    self:BuildMenu()
    self:RefreshMenuUseActions()
    self:StartMenuRefreshTicker()
end

function UI:HideMenu()
    if IsInCombatLockdown() then
        return
    end
    if self.menu and self.menu:IsShown() then
        self.menu:Hide()
    end
    self:StopMenuRefreshTicker()
end

local function SetEllipsizedText(fontString, text, maxWidth)
    text = tostring(text or "")

    fontString:SetText(text)

    if not maxWidth or maxWidth <= 0 then
        return
    end

    if fontString:GetStringWidth() <= maxWidth then
        return
    end

    local dots = "..."
    local len = #text

    while len > 0 do
        local candidate = text:sub(1, len) .. dots
        fontString:SetText(candidate)

        if fontString:GetStringWidth() <= maxWidth then
            return
        end

        len = len - 1
    end

    fontString:SetText(dots)
end

function UI:BuildMenu()
    local SC = GetSC()
    if not SC or type(SC.GetMissingItems) ~= "function" then
        return
    end

    local menu = self.menu
    menu:Show()
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", self.icon, "TOPRIGHT", 6, 0)

    if menu.items then
        for _, row in ipairs(menu.items) do
            row:Hide()
            row:SetParent(nil)
        end
    end
    menu.items = {}

    local missing = SC:GetMissingItems()
    local y = -6
    local width = 280

    for _, item in ipairs(missing) do
        local row = CreateFrame("Button", nil, menu, "SecureActionButtonTemplate")
        row:SetSize(width, 20)
        row:SetPoint("TOPLEFT", 6, y)
        row:EnableMouse(true)
        row:RegisterForClicks("AnyUp", "AnyDown")
        row._item = item

        self:RefreshRowUseAction(row)

        row:SetScript("OnMouseUp", function(_, button)
            local SC = GetSC()
            if not SC then
                return
            end

            if button == "LeftButton" then
                SC:HandleMenuLeftClick(item.id)
            elseif button == "MiddleButton" then
                if IsShiftKeyDown() then
                    SC:HandleMenuMiddleClick()
                else
                    SC:HandleMenuCraftClick(item.id)
                end
            end
        end)

        row:SetScript("PostClick", function(self, button)
            if button ~= "RightButton" then
                return
            end

            local SC = GetSC()
            local usedLure = row._hasBagItem == true
            C_Timer.After(0, function()
                if usedLure then
                    UI:HideMenu()
                    return
                end
                if UI and UI.RefreshRowUseAction and row then
                    UI:RefreshRowUseAction(row)
                    if not row._hasBagItem and SC and SC.NotifyLureMissingByID then
                        SC:NotifyLureMissingByID(item.id)
                    end
                end
            end)
        end)

        row:SetScript("OnEnter", function(self)
            UI:RefreshRowUseAction(self)

            local SC = GetSC()
            if not SC then return end

            local guideText = SC:GetGuideTooltip(item)
            if not guideText then return end

            Tooltip:Clear()
            Tooltip:AddLine(L["SKINNING_GUIDE"] or "Guide", 13, 1, 0.82, 0)
            Tooltip:AddLine(guideText, 12, 0.85, 0.85, 0.85)
            Tooltip:AddLine(" ")
            Tooltip:AddLine(
                L["SKINNING_ROW_HINT"]
                    or "Left Click — set waypoint\nRight Click — use lure\nMiddle Click — craft lure\nShift + Middle Click — open profession\n\nFirst number — ready lures in bags.\nIn brackets — how many can be crafted.",
                11, 0.70, 0.70, 0.70
            )
            Tooltip:ShowSmart(self)
        end)

        row:SetScript("OnLeave", function()
            Tooltip:Clear()
        end)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        icon:SetTexture(item.itemId and C_Item.GetItemIconByID(item.itemId) or 134400)
                
        local text = row:CreateFontString(nil, "OVERLAY")
        text:SetFont(FONT, 13, "")
        text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        text:SetPoint("RIGHT", row, "RIGHT", -50, 0)
        text:SetJustifyH("LEFT")
        text:SetWordWrap(false)
        text:SetMaxLines(1)
        SetEllipsizedText(text, SC:GetTargetName(item), 220)

        local countText = row:CreateFontString(nil, "OVERLAY")
        countText:SetFont(FONT, 13, "OUTLINE")
        countText:SetWidth(54)
        countText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        countText:SetJustifyH("RIGHT")
        row.countText = countText

        table.insert(menu.items, row)
        y = y - 22
    end

    menu:SetSize(width + 12, -y + 6)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("QUEST_LOG_UPDATE")
f:RegisterEvent("SKILL_LINES_CHANGED")
f:RegisterEvent("TRADE_SKILL_SHOW")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")

f:SetScript("OnEvent", function(_, event)
    local SC = GetSC()
    if not SC or type(SC.IsAvailable) ~= "function" then
        if UI.icon then UI.icon:Hide() end
        return
    end

    if not PT.config.skinningCheckEnabled then
        if UI.icon then UI.icon:Hide() end
        return
    end

    UI:CreateIcon()

    if event == "PLAYER_REGEN_ENABLED" and UI.icon and UI._pendingIconSize then
        UI.icon:SetSize(UI._pendingIconSize, UI._pendingIconSize)
        UI._pendingIconSize = nil
    end

    UI:Update()

    if UI.menu and UI.menu:IsShown() then
        if event == "BAG_UPDATE_DELAYED" then
            UI:RefreshMenuUseActions()
        elseif event == "QUEST_LOG_UPDATE" or event == "SKILL_LINES_CHANGED" or event == "TRADE_SKILL_SHOW" or event == "PLAYER_ENTERING_WORLD" then
            if not IsInCombatLockdown() then
                UI:BuildMenu()
                UI:RefreshMenuUseActions()
            end
        end
    end

    SyncSkinningToAccountOverview()
    PT:UpdateVisibility()
end)
