local PT = HironCraftProfit
if not PT then return end

PT.ShoppingList = PT.ShoppingList or {}
local S = PT.ShoppingList

local P = S._Private or {}
local FONT = S.FONT or HironCraftProfit.FONT or STANDARD_TEXT_FONT
local LibAHTab = S.LibAHTab or (LibStub and LibStub("LibAHTab-1-0", true))
local function GetLibAHTab()
    if not LibAHTab and LibStub then
        LibAHTab = LibStub("LibAHTab-1-0", true)
        S.LibAHTab = LibAHTab
    end
    return LibAHTab
end

local AH_TAB_ID = S.AH_TAB_ID or "HironCraftProfitProfessionShopping"
local AH_TAB_TEXT_KEY = S.AH_TAB_TEXT_KEY or "PG_SHOP_TAB"
local TITLE = S.TITLE or "PG_SHOP_TITLE"
local ROW_HEIGHT = S.ROW_HEIGHT or 28
local ROW_GAP = S.ROW_GAP or 2

local PANEL_PAD = 12
local SIDEBAR_W = 176
local TOP_H = 36
local HEADER_H = 22
local ACTION_W = 28
local STATUS_W = 72
local AH_W = 48
local BUY_BTN_SIZE = 24
local BUY_ICON_SIZE = 24
local BUY_CONFIRM_ICON_SIZE = 24
local PRICE_W = 104
local CHOSEN_W = 48
local QTY_W = 40
local NAME_TIER_ICON_SIZE = 16
local CHOSEN_TIER_ICON_SIZE = 16
local SEARCH_BTN_GAP = 2
local SIDEBAR_TAB_W = 76
local SIDEBAR_TAB_H = 24

local SHOP_FTAB_H = 28
local SHOP_FTAB_GAP = 10
local SHOP_SIDETAB_GAP = 5
local SIDEBAR_TAB_GAP = 2

local FROW_BTN_H = 28
local FROW_BTN_GAP = 1
local FROW_COL_SHIFT = 34
local FSEARCH_BTN = 28

S.shoppingSidebarMode = S.shoppingSidebarMode or "lists"

local function T(key, default)
    if P.T then
        return P.T(key, default)
    end
    local L = PT.L or {}
    return L[key] or default or key
end

local function FormatMoneyText(value)
    if P.FormatMoneyText then return P.FormatMoneyText(value) end
    if type(value) ~= "number" or value <= 0 then return T("PG_DASH", "—") end
    return GetCoinTextureString(value, 12) or tostring(value)
end

local function GetItemIcon(itemID)
    if P.GetItemIcon then return P.GetItemIcon(itemID) end
    local _, _, _, _, icon = GetItemInfoInstant(itemID)
    return icon or 134400
end

local function RequestSessionItemData()
    if P.RequestSessionItemData then return P.RequestSessionItemData() end
end

local function GetRemainingQuantity(row)
    if P.GetRemainingQuantity then return P.GetRemainingQuantity(row) end
    return math.max(0, tonumber(row and row.remainingQuantity) or tonumber(row and row.quantity) or 0)
end

local function GetVisibleRows()
    if P.GetVisibleRows then return P.GetVisibleRows() end
    local out = {}
    for _, row in ipairs(S.session and S.session.rows or {}) do
        if not row.hidden then table.insert(out, row) end
    end
    return out
end

local function GetListSort()
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    local s = HironCraftProfit_DB.shoppingListSort
    if type(s) ~= "table" then return nil end
    if not s.field or not s.mode then return nil end
    return s
end

local function SetListSort(field, mode)
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    if not field or not mode then
        HironCraftProfit_DB.shoppingListSort = nil
    else
        HironCraftProfit_DB.shoppingListSort = { field = field, mode = mode }
    end
end

local function CycleListSort(field)
    local current = GetListSort()
    if not current or current.field ~= field then
        SetListSort(field, "asc")
    elseif current.mode == "asc" then
        SetListSort(field, "desc")
    else
        SetListSort(nil, nil)
    end
end

local function GetRowSortName(row)
    if not row then return "" end
    if row.label and row.label ~= "" then return row.label end
    if row.lastChosenName and row.lastChosenName ~= "" then return row.lastChosenName end
    if row.itemID and GetItemInfo then
        local name = GetItemInfo(row.itemID)
        if name then return name end
    end
    return ""
end

local function SortRows(rows)
    local sort = GetListSort()
    if not sort or not rows or #rows < 2 then return rows end

    local copy = {}
    for i, r in ipairs(rows) do copy[i] = r end

    local field = sort.field
    local desc = sort.mode == "desc"

    table.sort(copy, function(a, b)
        local va, vb
        if field == "price" then
            va = tonumber(a and (a.pendingUnitPrice or a.minPrice)) or math.huge
            vb = tonumber(b and (b.pendingUnitPrice or b.minPrice)) or math.huge
        elseif field == "name" then
            va = string.lower(GetRowSortName(a))
            vb = string.lower(GetRowSortName(b))
        else
            return false
        end

        if va == vb then
            return (tonumber(a.index) or 0) < (tonumber(b.index) or 0)
        end
        if desc then
            return va > vb
        else
            return va < vb
        end
    end)

    return copy
end

P.GetSortedVisibleRows = function()
    return SortRows(GetVisibleRows())
end

local function HasShoppingSession()
    if P.HasShoppingSession then return P.HasShoppingSession() end
    return S.session and S.session.active and S.session.rows ~= nil
end

local function ShouldShowAuctionTab()
    if P.ShouldShowAuctionTab then return P.ShouldShowAuctionTab() end
    return HasShoppingSession() or (PT.config and PT.config.shoppingListAlwaysShowTab == true)
end

local function UpdateAuctionTabVisibility()
    if P.UpdateAuctionTabVisibility then
        P.UpdateAuctionTabVisibility()
        return
    end

    local tabLib = GetLibAHTab()
    if not tabLib or not tabLib.DoesIDExist or not tabLib.GetButton then return end
    if not tabLib:DoesIDExist(AH_TAB_ID) then return end

    local button = tabLib:GetButton(AH_TAB_ID)
    if button then
        button:SetShown(ShouldShowAuctionTab())
    end
end

local function ShowRowTooltip(widget)
    if P.ShowRowTooltip then return P.ShowRowTooltip(widget) end
end

local function AnchorTooltipAtCursor()
    if not GameTooltip or not UIParent or not GetCursorPosition then return end
    local scale = UIParent:GetEffectiveScale() or 1
    local x, y = GetCursorPosition()
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end

local function ShowItemTooltip(widget, itemID, searchRow)
    if not widget or not itemID or not GameTooltip then return end
    GameTooltip:SetOwner(widget, "ANCHOR_NONE")

    local shown = false
    local itemKey = searchRow and searchRow.itemKey
    local itemLevel = (itemKey and tonumber(itemKey.itemLevel or itemKey.iLevel))
        or (searchRow and tonumber(searchRow.itemLevel))
    if GameTooltip.SetItemKey and itemLevel and itemLevel > 0 then
        local suffix = (itemKey and tonumber(itemKey.itemSuffix or itemKey.suffixID or itemKey.suffix)) or 0
        shown = pcall(GameTooltip.SetItemKey, GameTooltip, itemID, itemLevel, suffix)
    end
    if not shown then
        GameTooltip:SetHyperlink("item:" .. itemID)
    end

    AnchorTooltipAtCursor()
    GameTooltip:Show()
end

local function GetRowBaseLabel(row)
    if P.GetRowBaseLabel then return P.GetRowBaseLabel(row) end
    return row and row.label or "?"
end

local function TrimText(value)
    value = tostring(value or "")
    value = value:gsub("^%s+", "")
    value = value:gsub("%s+$", "")
    return value
end

local function Lower(value)
    return string.lower(tostring(value or ""))
end

local function IsFantasy()
    if PT.IsFantasyDesign then return PT:IsFantasyDesign() end
    return true
end

local function SetFrameBackdrop(frame, alpha)
    if not frame then return end
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.05, 0.05, 0.07, alpha or 0.92)
    frame:SetBackdropBorderColor(1, 1, 1, 0.10)
end

local function SetFrameAtlasBackground(frame, atlas, alpha)
    if not frame or not atlas then return end

    if not frame.ahuiAtlasBG then
        frame.ahuiAtlasBG = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
        frame.ahuiAtlasBG:SetPoint("TOPLEFT", 1, -1)
        frame.ahuiAtlasBG:SetPoint("BOTTOMRIGHT", -1, 1)
    end

    frame.ahuiAtlasBG:SetAtlas(atlas)
    frame.ahuiAtlasBG:SetVertexColor(1, 1, 1)
    frame.ahuiAtlasBG:SetAlpha(alpha or 0.18)
    frame.ahuiAtlasBG:Show()
end

local PURPLE_BORDER = { 0.694, 0.612, 0.851 }

local function ApplyBlockFrame(frame, bgAlpha)
    if not frame then return end
    local bd
    if IsFantasy() then
        bd = {
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        }
    else
        bd = { edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }
    end
    if bgAlpha then bd.bgFile = "Interface\\Buttons\\WHITE8x8" end
    frame:SetBackdrop(bd)
    if bgAlpha then frame:SetBackdropColor(0, 0, 0, bgAlpha) end
    if IsFantasy() then
        frame:SetBackdropBorderColor(0.62, 0.62, 0.62, 1)
    else
        frame:SetBackdropBorderColor(PURPLE_BORDER[1], PURPLE_BORDER[2], PURPLE_BORDER[3], 1)
    end
end

local function AccentRGB()
    if IsFantasy() then return 1, 0.82, 0.35 end
    return PURPLE_BORDER[1], PURPLE_BORDER[2], PURPLE_BORDER[3]
end

S.IsFantasy = IsFantasy
S.ApplyBlockFrame = ApplyBlockFrame
S.PURPLE_BORDER = PURPLE_BORDER
S.AccentRGB = AccentRGB

local function FlipTabVertical(tab)
    if not tab then return end
    for _, region in ipairs({ tab:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "Texture" and region.GetTexCoord then
            local ulx, uly, llx, lly, urx, ury, lrx, lry = region:GetTexCoord()
            if ulx then
                region:SetTexCoord(llx, lly, ulx, uly, lrx, lry, urx, ury)
            end
        end
    end
end

local function SetTabHeightForced(tb, h)
    if not tb then return end
    tb._baseTexH = tb._baseTexH or tb:GetHeight()
    tb:SetHeight(h)
    for _, region in ipairs({ tb:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "Texture" and region.SetHeight then
            region:SetHeight(h)
        end
    end
    if tb.NineSlice and tb.NineSlice.SetHeight then
        tb.NineSlice:SetHeight(h)
    end
end

local function ApplyPanelBackground(frame)
    if not frame then return end
    if IsFantasy() then
        if frame.ahuiBase then frame.ahuiBase:Hide() end
        ApplyBlockFrame(frame, nil)
        SetFrameAtlasBackground(frame, "auctionhouse-background-auctions", 1.0)
    else
        if not frame.ahuiBase then
            frame.ahuiBase = frame:CreateTexture(nil, "BACKGROUND", nil, -2)
            frame.ahuiBase:SetPoint("TOPLEFT", 1, -1)
            frame.ahuiBase:SetPoint("BOTTOMRIGHT", -1, 1)
        end
        frame.ahuiBase:SetColorTexture(0, 0, 0, 0.86)
        frame.ahuiBase:Show()
        ApplyBlockFrame(frame, nil)
        SetFrameAtlasBackground(frame, "shop-bg-toys", 0.45)
    end
end

local function ApplyInnerBackdrop(frame, soullessAlpha)
    ApplyBlockFrame(frame, 0.38)
end

local function MakeText(parent, size, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, size or 11, "")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetJustifyV("MIDDLE")
    return fs
end

local function ShowSimpleTooltip(owner, title, body)
    local TT = PT and PT.Tooltip
    if not owner or not TT then return end
    TT:Clear()
    if title and title ~= "" then
        TT:AddLine(title, 13, 1, 1, 1)
    end
    if body and body ~= "" then
        TT:AddLine(body, 11, 0.8, 0.8, 0.8)
    end
    TT:ShowCursorRightOrBelow()
end

local function HideSimpleTooltip()
    if PT and PT.Tooltip then PT.Tooltip:Clear() end
end

local function CreateCheckLine(parent, text, tooltipTitle, tooltipText, getChecked, setChecked)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(150, 20)
    holder:EnableMouse(true)

    holder.check = CreateFrame("CheckButton", nil, holder, "UICheckButtonTemplate")
    holder.check:SetSize(22, 22)
    holder.check:SetPoint("LEFT", -2, 0)

    holder.text = MakeText(holder, 10, "LEFT")
    holder.text:SetPoint("LEFT", holder.check, "RIGHT", -2, 0)
    holder.text:SetPoint("RIGHT", holder, "RIGHT", 0, 0)
    holder.text:SetText(text)

    function holder:Refresh()
        self.check:SetChecked(getChecked and getChecked() == true)
    end

    local function Toggle()
        local value = not (getChecked and getChecked() == true)
        if setChecked then
            setChecked(value)
        end
        holder:Refresh()
    end

    holder.check:SetScript("OnClick", function(self)
        if setChecked then
            setChecked(self:GetChecked() == true)
        end
        holder:Refresh()
    end)

    holder:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            Toggle()
        end
    end)

    local function OnEnter(self)
        ShowSimpleTooltip(self, tooltipTitle, tooltipText)
    end

    local function OnLeave()
        HideSimpleTooltip()
    end

    holder:SetScript("OnEnter", OnEnter)
    holder:SetScript("OnLeave", OnLeave)
    holder.check:SetScript("OnEnter", OnEnter)
    holder.check:SetScript("OnLeave", OnLeave)

    holder:Refresh()

    return holder
end

local function SetButtonAtlas(button, atlas)
    if not button then return end

    if not button.icon then
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("CENTER", 0, 0)
    end

    local size = button.iconSize or 18
    button.icon:SetSize(size, size)

    local ok = false
    if atlas and button.icon.SetAtlas then
        ok = pcall(button.icon.SetAtlas, button.icon, atlas)
    end

    if not ok then
        button.icon:SetTexture("Interface\\Buttons\\UI-RefreshButton")
    end
end

local function IsChoiceRow(rowData)
    return rowData and type(rowData.options) == "table" and #rowData.options > 0
end

local function IsQuantityEditable(rowData)
    if not rowData then
        return false
    end

    if rowData.purchaseStage == "await_price" or rowData.purchaseStage == "processing" then
        return false
    end

    if rowData.isSearchResult then
        return rowData.isCommodity == true
    end

    if rowData.isCommodity == false then
        return false
    end

    return true
end

local function GetDisplayItemID(rowData)
    if not rowData then
        return nil
    end

    return rowData.chosenItemID
        or rowData.itemID
        or (rowData.options and rowData.options[1] and rowData.options[1].itemID)
end

local function GetDisplayItemQuality(rowData)
    if not rowData then
        return nil
    end

    local quality = tonumber(rowData.quality or rowData.itemQuality)
    if quality ~= nil then
        return quality
    end

    local itemID = GetDisplayItemID(rowData)
    if itemID then
        local _, _, itemQuality = GetItemInfo(itemID)
        return tonumber(itemQuality)
    end

    return nil
end

local function IsEquippableRow(rowData)
    if not rowData then
        return false
    end

    local itemID = GetDisplayItemID(rowData)
    if not itemID then
        return false
    end

    local equipLoc = select(4, C_Item.GetItemInfoInstant(itemID))
    return equipLoc ~= nil and equipLoc ~= ""
        and equipLoc ~= "INVTYPE_NON_EQUIP" and equipLoc ~= "INVTYPE_BAG"
end

local function GetDisplayItemLevel(rowData)
    if not rowData then
        return nil
    end

    local itemLevel = tonumber(rowData.itemLevel or rowData.ilvl)
    if itemLevel and itemLevel > 0 then
        return math.floor(itemLevel)
    end

    local itemID = GetDisplayItemID(rowData)
    if itemID then
        local _, _, _, readItemLevel = GetItemInfo(itemID)
        readItemLevel = tonumber(readItemLevel)
        if readItemLevel and readItemLevel > 0 then
            return math.floor(readItemLevel)
        end
    end

    return nil
end

local function GetRowDisplayName(rowData)
    local name = GetRowBaseLabel(rowData)

    local classID = rowData and tonumber(rowData.itemClassID)
    local isCommodity = rowData and rowData.isCommodity == true
    local isConsumableOrReagent = classID == 0 or classID == 5 or classID == 7

    if not isCommodity and not isConsumableOrReagent and IsEquippableRow(rowData) then
        local itemLevel = GetDisplayItemLevel(rowData)
        if itemLevel then
            return string.format("%s (%d)", name, itemLevel)
        end
    end

    return name
end

local function ApplyNameColor(row, rowData)
    if not row or not row.name then
        return
    end

    local quality = GetDisplayItemQuality(rowData)
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] or nil

    if color then
        row.name:SetTextColor(color.r or 1, color.g or 1, color.b or 1)
    else
        row.name:SetTextColor(1, 1, 1)
    end
end

local function GetTierFromRow(rowData)
    if not rowData then
        return nil
    end

    local tier = tonumber(rowData.chosenTier or rowData.tier
        or rowData.qualityTier or rowData.professionQuality
        or rowData.craftedQuality or rowData.materialQuality)

    if not tier and rowData.lastChosenName then
        tier = tonumber(string.match(tostring(rowData.lastChosenName), "R(%d+)"))
    end

    if not tier and rowData.itemID and C_TradeSkillUI and C_TradeSkillUI.GetItemReagentQualityByItemInfo then
        local okQ, q = pcall(C_TradeSkillUI.GetItemReagentQualityByItemInfo, rowData.itemID)
        if okQ and tonumber(q) and tonumber(q) >= 1 then
            tier = tonumber(q)
        end
    end

    if not tier then
        return nil
    end

    tier = math.floor(tier)
    if tier < 1 or tier > 5 then
        return nil
    end

    return tier
end

local function GetChosenDisplay(rowData)
    local tier = GetTierFromRow(rowData)
    if tier then
        return tostring(tier)
    end

    if rowData and rowData.lastChosenName and rowData.lastChosenName ~= "" and rowData.lastChosenName ~= T("PG_DASH", "—") then
        return rowData.lastChosenName
    end

    if IsChoiceRow(rowData) then
        return "…"
    end

    return T("PG_DASH", "—")
end

local GetProfessionTierAtlas

local function SetChosenDisplay(row, rowData)
    if not row or not row.chosen then
        return
    end

    if not IsChoiceRow(rowData) then
        if row.chosenIcon then
            row.chosenIcon:Hide()
        end
        row.chosen:SetText(T("PG_DASH", "—"))
        return
    end

    local atlas = GetProfessionTierAtlas and GetProfessionTierAtlas(rowData) or nil

    if atlas and row.chosenIcon and row.chosenIcon.SetAtlas then
        local ok = pcall(row.chosenIcon.SetAtlas, row.chosenIcon, atlas)
        if ok then
            row.chosen:SetText("")
            row.chosenIcon:Show()
            return
        end
    end

    if row.chosenIcon then
        row.chosenIcon:Hide()
    end

    row.chosen:SetText(GetChosenDisplay(rowData))
end

local function RowMatchesSearch(rowData, query)
    if not query or query == "" then
        return true
    end

    local name = Lower(GetRowBaseLabel(rowData))
    if string.find(name, query, 1, true) then
        return true
    end

    if rowData and rowData.itemID and string.find(tostring(rowData.itemID), query, 1, true) then
        return true
    end

    for _, opt in ipairs(rowData and rowData.options or {}) do
        if opt.itemID and string.find(tostring(opt.itemID), query, 1, true) then
            return true
        end
    end

    return false
end

local function ApplyQuantityFromBox(box)
    if not box then return end

    local searchRow = box.searchRow
    if searchRow and searchRow.isSearchResult then
        if not IsQuantityEditable(searchRow) then
            box:SetText("1")
            box:ClearFocus()
            return
        end

        local text = TrimText(box:GetText())
        local quantity = tonumber(text)
        if not quantity then
            local current = GetRemainingQuantity(searchRow)
            box:SetText(tostring(current > 0 and current or 1))
            box:ClearFocus()
            return
        end

        quantity = math.floor(quantity)
        if quantity < 1 then quantity = 1 end
        if quantity > 999999 then quantity = 999999 end

        searchRow.quantity = quantity
        searchRow.remainingQuantity = quantity
        box:SetText(tostring(quantity))
        box:ClearFocus()

        if S.RefreshWindow then
            S:RefreshWindow()
        end
        return
    end

    local rowIndex = box.rowIndex
    if not rowIndex then return end

    local text = TrimText(box:GetText())
    local quantity = tonumber(text)
    if not quantity then
        local row = S.session and S.session.rows and S.session.rows[rowIndex]
        box:SetText(tostring(GetRemainingQuantity(row)))
        box:ClearFocus()
        return
    end

    quantity = math.floor(quantity)
    if quantity < 0 then quantity = 0 end

    if S.SetRowQuantity then
        S:SetRowQuantity(rowIndex, quantity)
    else
        local row = S.session and S.session.rows and S.session.rows[rowIndex]
        if row then
            row.quantity = quantity
            row.remainingQuantity = quantity
        end
        if S.RefreshWindow then S:RefreshWindow() end
    end

    box:ClearFocus()
end
local function CreateIconButton(parent, atlas, tooltipTitle, tooltipText, buttonSize, iconSize)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(buttonSize or 24, buttonSize or 24)

    btn.iconSize = iconSize or 18
    SetButtonAtlas(btn, atlas)

    btn.tooltipTitle = tooltipTitle
    btn.tooltipText = tooltipText

    btn:SetScript("OnEnter", function(self)
        if self.icon then self.icon:SetVertexColor(1.3, 1.3, 1.3) end
        ShowSimpleTooltip(self, self.tooltipTitle, self.tooltipText)
    end)

    btn:SetScript("OnLeave", function(self)
        if self.icon then
            self.icon:SetVertexColor(1, 1, 1)
            self.icon:ClearAllPoints()
            self.icon:SetPoint("CENTER", 0, 0)
        end
        HideSimpleTooltip()
    end)

    btn:HookScript("OnMouseDown", function(self)
        if self.icon then
            self.icon:ClearAllPoints()
            self.icon:SetPoint("CENTER", 1, -1)
            self.icon:SetVertexColor(0.7, 0.7, 0.7)
        end
    end)

    btn:HookScript("OnMouseUp", function(self)
        if self.icon then
            self.icon:ClearAllPoints()
            self.icon:SetPoint("CENTER", 0, 0)
            local v = self:IsMouseOver() and 1.3 or 1
            self.icon:SetVertexColor(v, v, v)
        end
    end)

    return btn
end

local function InstallRedButtonPress(btn)
    if not btn or btn._redPressInstalled then return end
    btn._redPressInstalled = true

    btn:HookScript("OnMouseDown", function(self)
        if self.icon and self._raPressed then
            self.icon:ClearAllPoints()
            self.icon:SetPoint("CENTER", 0, 0)
            self.icon:SetAtlas(self._raPressed)
            self.icon:SetVertexColor(1, 1, 1)
        end
    end)

    btn:HookScript("OnMouseUp", function(self)
        if self.icon and self._raNormal then
            self.icon:ClearAllPoints()
            self.icon:SetPoint("CENTER", 0, 0)
            self.icon:SetAtlas(self._raNormal)
            local v = self:IsMouseOver() and 1.15 or 1
            self.icon:SetVertexColor(v, v, v)
        end
    end)

    btn:HookScript("OnDisable", function(self)
        if self.icon and self._raDisabled then
            self.icon:SetAtlas(self._raDisabled)
        end
    end)

    btn:HookScript("OnEnable", function(self)
        if self.icon and self._raNormal then
            self.icon:SetAtlas(self._raNormal)
        end
    end)
end

local function SetRedButtonAtlas(btn, normalAtlas, pressedAtlas, fillSize, disabledAtlas)
    if not btn then return end
    InstallRedButtonPress(btn)
    btn._raNormal = normalAtlas
    btn._raPressed = pressedAtlas
    btn._raDisabled = disabledAtlas
    if fillSize then btn.iconSize = fillSize end
    SetButtonAtlas(btn, normalAtlas)
    if disabledAtlas and not btn:IsEnabled() then
        btn.icon:SetAtlas(disabledAtlas)
    end
end

local function ClearRedButtonAtlas(btn)
    if not btn then return end
    btn._raNormal = nil
    btn._raPressed = nil
    btn._raDisabled = nil
end

local function SetIconButtonTexture(btn, normalTex, pressedTex, fillSize)
    if not btn or not btn.icon then return end

    btn._itNormal = normalTex
    btn._itPressed = pressedTex or normalTex

    if fillSize then
        btn.iconSize = fillSize
        btn.icon:SetSize(fillSize, fillSize)
    end

    btn.icon:SetTexture(normalTex)

    if btn._itPressInstalled then return end
    btn._itPressInstalled = true

    btn:HookScript("OnMouseDown", function(self)
        if self.icon and self._itPressed then
            self.icon:ClearAllPoints()
            self.icon:SetPoint("CENTER", 0, 0)
            self.icon:SetTexture(self._itPressed)
            self.icon:SetVertexColor(1, 1, 1)
        end
    end)

    btn:HookScript("OnMouseUp", function(self)
        if self.icon and self._itNormal then
            self.icon:ClearAllPoints()
            self.icon:SetPoint("CENTER", 0, 0)
            self.icon:SetTexture(self._itNormal)
            local v = self:IsMouseOver() and 1.15 or 1
            self.icon:SetVertexColor(v, v, v)
        end
    end)
end

local promptPayloads = {}

local function GetPopupEditBox(popup)
    if not popup then
        return nil
    end

    if popup.editBox then
        return popup.editBox
    end

    if popup.EditBox then
        return popup.EditBox
    end

    local name = popup.GetName and popup:GetName() or nil
    if name then
        return _G[name .. "EditBox"] or _G[name .. "EditBox1"]
    end

    return nil
end

local function PromptText(dialogKey, title, defaultValue, onAccept)
    defaultValue = tostring(defaultValue or "")

    if not StaticPopupDialogs or not StaticPopup_Show then
        if onAccept then
            onAccept(defaultValue)
        end
        return
    end

    promptPayloads[dialogKey] = {
        defaultValue = defaultValue,
        onAccept = onAccept,
    }

    StaticPopupDialogs[dialogKey] = StaticPopupDialogs[dialogKey] or {
        text = "%s",
        button1 = ACCEPT or "OK",
        button2 = CANCEL or "Cancel",
        hasEditBox = true,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnAccept = function(self)
            local payload = promptPayloads[dialogKey]
            local box = GetPopupEditBox(self)
            local value = box and box:GetText() or ""
            if payload and payload.onAccept then
                payload.onAccept(TrimText(value))
            end
            promptPayloads[dialogKey] = nil
        end,
        OnCancel = function()
            promptPayloads[dialogKey] = nil
        end,
        OnShow = function(self)
            local payload = promptPayloads[dialogKey]
            local box = GetPopupEditBox(self)
            if box then
                box:SetText(payload and payload.defaultValue or "")
                box:SetFocus()
                box:HighlightText()
            end
        end,
        EditBoxOnEnterPressed = function(self)
            local parent = self:GetParent()
            if parent and parent.button1 then
                parent.button1:Click()
            elseif parent and StaticPopup_OnClick then
                StaticPopup_OnClick(parent, 1)
            end
        end,
        EditBoxOnEscapePressed = function(self)
            local parent = self:GetParent()
            if parent then
                parent:Hide()
            end
        end,
    }

    local popup = StaticPopup_Show(dialogKey, title or "")
    local box = GetPopupEditBox(popup)
    if box then
        box:SetText(defaultValue)
        box:SetFocus()
        box:HighlightText()
    end
end

local function EnsureImportExportDialog(owner)
    if not owner then
        return nil
    end

    if owner.importExportDialog then
        return owner.importExportDialog
    end

    local d = CreateFrame("Frame", nil, owner, "BackdropTemplate")
    d:SetSize(540, 360)
    d:SetPoint("CENTER", owner, "CENTER", 0, 0)
    d:SetFrameStrata("DIALOG")
    d:SetFrameLevel(80)
    d:EnableMouse(true)
    d:SetMovable(true)
    d:RegisterForDrag("LeftButton")
    d:SetScript("OnDragStart", function(self) self:StartMoving() end)
    d:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    d:Hide()
    SetFrameBackdrop(d, 0.98)

    d.title = MakeText(d, 13, "LEFT")
    d.title:SetPoint("TOPLEFT", 14, -12)
    d.title:SetPoint("RIGHT", -40, 0)

    d.close = CreateIconButton(d, "common-icon-redx", T("PG_SHOP_CLOSE", "Close"), "", 22, 14)
    d.close:SetPoint("TOPRIGHT", -10, -8)
    d.close:SetScript("OnClick", function()
        d:Hide()
    end)

    d.help = MakeText(d, 10, "LEFT")
    d.help:SetPoint("TOPLEFT", 14, -34)
    d.help:SetPoint("RIGHT", -14, 0)

    d.scroll = CreateFrame("ScrollFrame", nil, d, "UIPanelScrollFrameTemplate")
    d.scroll:SetPoint("TOPLEFT", 14, -58)
    d.scroll:SetPoint("BOTTOMRIGHT", -32, 54)

    d.editBox = CreateFrame("EditBox", nil, d.scroll)
    d.editBox:SetMultiLine(true)
    d.editBox:SetAutoFocus(false)
    d.editBox:SetFont(FONT, 11, "")
    d.editBox:SetWidth(480)
    d.editBox:SetHeight(240)
    d.editBox:SetJustifyH("LEFT")
    d.editBox:SetJustifyV("TOP")
    d.editBox:EnableMouse(true)
    d.editBox:SetTextInsets(4, 4, 4, 4)
    d.editBox:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self:SetFocus()
        end
    end)
    d.editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        d:Hide()
    end)
    d.scroll:SetScrollChild(d.editBox)
    d.scroll:EnableMouse(true)
    d.scroll:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then
            return
        end

        d.editBox:SetFocus()
        d.editBox:SetCursorPosition(string.len(d.editBox:GetText() or ""))
    end)

    d.status = MakeText(d, 10, "LEFT")
    d.status:SetPoint("BOTTOMLEFT", 14, 32)
    d.status:SetPoint("RIGHT", -14, 0)
    d.status:SetText("")

    d.ahui = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
    d.ahui:SetSize(92, 22)
    d.ahui:SetPoint("BOTTOMLEFT", 14, 8)
    d.ahui:SetText("HironCraft")

    d.auctionator = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
    d.auctionator:SetSize(104, 22)
    d.auctionator:SetPoint("LEFT", d.ahui, "RIGHT", 6, 0)
    d.auctionator:SetText("Auctionator")

    d.importNew = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
    d.importNew:SetSize(116, 22)
    d.importNew:SetPoint("BOTTOMLEFT", 14, 8)
    d.importNew:SetText(T("PG_SHOP_IMPORT_NEW", "Import new"))

    d.importMerge = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
    d.importMerge:SetSize(116, 22)
    d.importMerge:SetPoint("LEFT", d.importNew, "RIGHT", 6, 0)
    d.importMerge:SetText(T("PG_SHOP_IMPORT_MERGE", "Merge"))

    d.selectAll = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
    d.selectAll:SetSize(92, 22)
    d.selectAll:SetPoint("BOTTOMRIGHT", -104, 8)
    d.selectAll:SetText(T("PG_SHOP_SELECT_ALL", "Select all"))
    d.selectAll:SetScript("OnClick", function()
        d.editBox:SetFocus()
        d.editBox:HighlightText()
    end)

    d.done = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
    d.done:SetSize(84, 22)
    d.done:SetPoint("BOTTOMRIGHT", -14, 8)
    d.done:SetText(T("PG_SHOP_CLOSE", "Close"))
    d.done:SetScript("OnClick", function()
        d:Hide()
    end)

    local function SetExportText(format)
        local text = S.ExportActiveList and S:ExportActiveList(format) or ""
        d.editBox:SetText(text or "")
        d.editBox:SetFocus()
        d.editBox:HighlightText()
        d.status:SetText(format == "auctionator" and T("PG_SHOP_EXPORT_AUCTIONATOR_READY", "Auctionator export is ready to copy.") or T("PG_SHOP_EXPORT_HIRONCRAFT_PROFIT_READY", "HironCraft export is ready to copy."))
    end

    d.ahui:SetScript("OnClick", function()
        SetExportText("ahui")
    end)

    d.auctionator:SetScript("OnClick", function()
        SetExportText("auctionator")
    end)

    local function Import(mode)
        local value = d.editBox:GetText() or ""
        if S.ImportShoppingLists then
            local ok, err, itemCount, listCount = S:ImportShoppingLists(value, mode)
            if ok then
                d.status:SetText(string.format(T("PG_SHOP_IMPORT_DONE", "Imported: %d items"), tonumber(itemCount) or 0))
                if S.RefreshWindow then
                    S:RefreshWindow()
                end
            else
                d.status:SetText(T("PG_SHOP_IMPORT_FAILED", "Nothing imported. Check the pasted text."))
            end
        end
    end

    d.importNew:SetScript("OnClick", function()
        Import("new")
    end)

    d.importMerge:SetScript("OnClick", function()
        Import("merge")
    end)

    function d:SetMode(mode)
        self.mode = mode
        self.status:SetText("")

        if mode == "export" then
            self.title:SetText(T("PG_SHOP_EXPORT_TITLE", "Export shopping list"))
            self.help:SetText(T("PG_SHOP_EXPORT_HELP", "Copy the text below. HironCraftProfit keeps quantities and choices; Auctionator exports item names."))
            self.ahui:Show()
            self.auctionator:Show()
            self.importNew:Hide()
            self.importMerge:Hide()
            SetExportText("auctionator")
        else
            self.title:SetText(T("PG_SHOP_IMPORT_TITLE", "Import shopping list"))
            self.help:SetText(T("PG_SHOP_IMPORT_HELP", "Paste HironCraftProfit, Auctionator, old Auctionator, TSM, or plain item lines."))
            self.ahui:Hide()
            self.auctionator:Hide()
            self.importNew:Show()
            self.importMerge:Show()
            self.editBox:SetText("")
            self.editBox:SetFocus()
        end
    end

    owner.importExportDialog = d
    if PT.RestyleButtons then PT:RestyleButtons(d, 12) end
    return d
end

local function ShowImportExportDialog(mode)
    local f = S.frame
    if not f then
        return
    end

    if f.searchOptionsPanel then
        f.searchOptionsPanel:Hide()
    end
    if f.searchOptionsBlocker then
        f.searchOptionsBlocker:Hide()
    end

    local d = EnsureImportExportDialog(f)
    if not d then
        return
    end

    d:SetMode(mode)
    d:Show()
end


local function RefreshSearchClearButton(frame)
    if not frame or not frame.searchClearButton or not frame.searchBox then
        return
    end

    local hasText = TrimText(frame.searchBox:GetText() or "") ~= ""
    local hasResults = S.searchResults and S.searchResults.active
    local shown = hasText or hasResults

    frame.searchClearButton:SetShown(shown)
    frame.searchClearButton:SetAlpha(shown and 0.85 or 0.25)
end

local function HideSearchOptionsPanel()
    local f = S.frame
    if not f then
        return
    end

    if f.searchOptionsPanel then
        f.searchOptionsPanel:Hide()
    end

    if f.searchOptionsBlocker then
        f.searchOptionsBlocker:Hide()
    end
end

local function EnsureSearchOptionsBlocker(frame)
    if not frame or frame.searchOptionsBlocker then
        return
    end

    local blocker = CreateFrame("Button", nil, frame)
    blocker:SetAllPoints(frame)
    blocker:SetFrameStrata("DIALOG")
    blocker:SetFrameLevel(1)
    blocker:EnableMouse(true)
    blocker:Hide()
    blocker:SetScript("OnMouseDown", function()
        HideSearchOptionsPanel()
    end)

    frame.searchOptionsBlocker = blocker
end

local function RunSearchFromBox()
    local f = S.frame
    if not f or not f.searchBox then return end

    local text = TrimText(f.searchBox:GetText())

    if text == "" and S.CanRunEmptyAuctionSearch and not S:CanRunEmptyAuctionSearch() then
        if S.ClearAuctionSearch then
            S:ClearAuctionSearch()
        end
        if f.hint then
            f.hint:SetText(T("PG_SHOP_SEARCH_NEED_QUERY_OR_FILTER", "Введите текст или выберите тип/качество/уровень"))
        end
        return
    end

    if S.StartAuctionSearch then
        S:StartAuctionSearch(text)
    end

    f.searchBox:SetFocus()
    f.searchBox:SetCursorPosition(strlen(f.searchBox:GetText() or ""))
    RefreshSearchClearButton(f)
end

local function ToggleSearchOptionsPanel(anchor)
    local f = S.frame
    if not f then return end

    if f.searchOptionsPanel and f.searchOptionsPanel:IsShown() then
        HideSearchOptionsPanel()
        return
    end

    EnsureSearchOptionsBlocker(f)

    local function GetOpts()
        if S.GetSearchOptions then
            return S:GetSearchOptions()
        end
        S.searchOptions = S.searchOptions or {}
        return S.searchOptions
    end

    local function SetOpt(key, value)
        if S.SetSearchOption then
            S:SetSearchOption(key, value, true)
        else
            local opts = GetOpts()
            opts[key] = value
        end
    end

    local function MakeCategoryKey(classID, subClassID, inventoryType)
        if not classID then
            return "any"
        end
        return tostring(classID) .. ":" .. tostring(subClassID or "") .. ":" .. tostring(inventoryType or "")
    end

    local function ParseCategoryKey(value)
        if value == "any" then
            return nil, nil, nil
        end

        local classID, subClassID, inventoryType = tostring(value or ""):match("^([^:]*):([^:]*):([^:]*)$")
        classID = tonumber(classID)
        subClassID = tonumber(subClassID)
        inventoryType = tonumber(inventoryType)
        return classID, subClassID, inventoryType
    end

    local function ReadItemClassText(classID, subClassID, fallback)
        if fallback and fallback ~= "" then
            return fallback
        end

        if classID and subClassID and C_Item and C_Item.GetItemSubClassInfo then
            local ok, text = pcall(C_Item.GetItemSubClassInfo, classID, subClassID)
            if ok and text and text ~= "" then
                return text
            end
        end

        if classID and GetItemSubClassInfo and subClassID then
            local ok, text = pcall(GetItemSubClassInfo, classID, subClassID)
            if ok and text and text ~= "" then
                return text
            end
        end

        if classID and C_Item and C_Item.GetItemClassInfo then
            local ok, text = pcall(C_Item.GetItemClassInfo, classID)
            if ok and text and text ~= "" then
                return text
            end
        end

        if classID and GetItemClassInfo then
            local ok, text = pcall(GetItemClassInfo, classID)
            if ok and text and text ~= "" then
                return text
            end
        end

        return classID and tostring(classID) or "?"
    end

    local itemCategoryModel = nil

    local function BuildItemCategoryModel()
        local model = {
            classes = {},
            byID = {},
            subSeen = {},
        }

        local function ReadSubClassText(classID, subClassID)
            classID = tonumber(classID)
            subClassID = tonumber(subClassID)
            if classID == nil or subClassID == nil then
                return nil
            end

            if C_Item and C_Item.GetItemSubClassInfo then
                local ok, text = pcall(C_Item.GetItemSubClassInfo, classID, subClassID)
                if ok and text and text ~= "" then
                    return text
                end
            end

            if GetItemSubClassInfo then
                local ok, text = pcall(GetItemSubClassInfo, classID, subClassID)
                if ok and text and text ~= "" then
                    return text
                end
            end

            return nil
        end

        local function EnsureClass(classID, text)
            classID = tonumber(classID)
            if classID == nil then
                return nil
            end

            local existing = model.byID[classID]
            if existing then
                if (not existing.text or existing.text == "") and text and text ~= "" then
                    existing.text = text
                end
                return existing
            end

            local label = ReadItemClassText(classID, nil, text)
            if not label or label == "" then
                label = tostring(classID)
            end

            local entry = {
                classID = classID,
                text = label,
                subs = {},
            }
            model.byID[classID] = entry
            table.insert(model.classes, entry)
            return entry
        end

        local function AddSubClass(classID, subClassID, inventoryType, text)
            classID = tonumber(classID)
            subClassID = tonumber(subClassID)
            inventoryType = nil
            if classID == nil or subClassID == nil then
                return
            end

            local parent = EnsureClass(classID)
            if not parent then
                return
            end

            local key = MakeCategoryKey(classID, subClassID, inventoryType)
            if model.subSeen[key] then
                return
            end

            local label = ReadSubClassText(classID, subClassID) or text
            if not label or label == "" or label == parent.text then
                return
            end

            model.subSeen[key] = true
            table.insert(parent.subs, {
                classID = classID,
                subClassID = subClassID,
                inventoryType = inventoryType,
                value = key,
                text = label,
            })
        end

        local function Walk(categories, parentClassID)
            for _, cat in ipairs(categories or {}) do
                if type(cat) == "table" then
                    local classID = cat.itemClassID or cat.classID or cat.classId or cat.itemClass or parentClassID
                    local subClassID = cat.itemSubClassID or cat.subClassID or cat.subClassId or cat.itemSubClass
                    local inventoryType = cat.inventoryType or cat.inventorySlotType
                    local text = cat.name or cat.displayName or cat.categoryName or cat.label

                    if subClassID ~= nil then
                        AddSubClass(classID, subClassID, inventoryType, text)
                    else
                        EnsureClass(classID, text)
                    end

                    local childSets = {
                        cat.subCategories,
                        cat.subcategories,
                        cat.childCategories,
                        cat.children,
                        cat.categories,
                    }

                    for _, children in ipairs(childSets) do
                        if type(children) == "table" then
                            Walk(children, classID)
                        end
                    end
                end
            end
        end

        if C_AuctionHouse and C_AuctionHouse.GetAvailableCategories then
            local ok, categories = pcall(C_AuctionHouse.GetAvailableCategories)
            if ok and type(categories) == "table" then
                Walk(categories, nil)
            end
        end

        local fallbackClasses = {
            { 0,  T("PG_SHOP_OPT_CONSUMABLE", "Расходуемые") },
            { 1,  T("PG_SHOP_OPT_CONTAINER", "Сумки") },
            { 2,  T("PG_SHOP_OPT_WEAPON", "Оружие") },
            { 3,  T("PG_SHOP_OPT_GEM", "Самоцветы") },
            { 4,  T("PG_SHOP_OPT_ARMOR", "Броня") },
            { 5,  T("PG_SHOP_OPT_REAGENT", "Реагенты") },
            { 7,  T("PG_SHOP_OPT_TRADE_GOODS", "Ремесленные товары") },
            { 8,  T("PG_SHOP_OPT_ITEM_ENHANCEMENT", "Улучшения") },
            { 9,  T("PG_SHOP_OPT_RECIPE", "Рецепты") },
            { 12, T("PG_SHOP_OPT_QUEST", "Задания") },
            { 15, T("PG_SHOP_OPT_MISC", "Разное") },
            { 16, T("PG_SHOP_OPT_GLYPH", "Символы") },
            { 17, T("PG_SHOP_OPT_BATTLE_PET", "Боевые питомцы") },
        }

        for _, data in ipairs(fallbackClasses) do
            local classID = data[1]
            EnsureClass(classID, data[2])

            for subClassID = 0, 60 do
                local subText = ReadSubClassText(classID, subClassID)
                if subText and subText ~= "" and subText ~= data[2] then
                    AddSubClass(classID, subClassID, nil, subText)
                end
            end
        end

        table.sort(model.classes, function(a, b)
            return tostring(a.text or "") < tostring(b.text or "")
        end)

        for _, class in ipairs(model.classes) do
            table.sort(class.subs, function(a, b)
                return tostring(a.text or "") < tostring(b.text or "")
            end)
        end

        return model
    end

    local function GetItemCategoryModel()
        if not itemCategoryModel then
            itemCategoryModel = BuildItemCategoryModel()
        end
        return itemCategoryModel
    end

    local function BuildItemClassOptions()
        local out = {
            { value = "any", text = T("PG_SHOP_OPT_ANY", "Любой") },
        }

        for _, class in ipairs(GetItemCategoryModel().classes or {}) do
            table.insert(out, {
                value = tostring(class.classID),
                text = class.text,
                classID = class.classID,
            })
        end

        return out
    end

    local function BuildItemSubClassOptions(classID)
        local out = {
            { value = "any", text = T("PG_SHOP_OPT_ANY", "Любой") },
        }

        classID = tonumber(classID)
        if classID == nil then
            return out
        end

        local class = GetItemCategoryModel().byID[classID]
        for _, sub in ipairs(class and class.subs or {}) do
            table.insert(out, {
                value = sub.value,
                text = sub.text,
                classID = sub.classID,
                subClassID = sub.subClassID,
                inventoryType = sub.inventoryType,
            })
        end

        return out
    end

    local itemClassOptions = BuildItemClassOptions()

    local qualityOptions = {
        { value = "any",       text = T("PG_SHOP_OPT_ANY", "Любое") },
        { value = "poor",      text = T("PG_SHOP_QUALITY_POOR", "Низкое") },
        { value = "common",    text = T("PG_SHOP_QUALITY_COMMON", "Обычное") },
        { value = "uncommon",  text = T("PG_SHOP_QUALITY_UNCOMMON", "Необычное") },
        { value = "rare",      text = T("PG_SHOP_QUALITY_RARE", "Редкое") },
        { value = "epic",      text = T("PG_SHOP_QUALITY_EPIC", "Эпическое") },
        { value = "legendary", text = T("PG_SHOP_QUALITY_LEGENDARY", "Легендарное") },
    }

    local sortOptions = {
        { value = "price_asc",  text = T("PG_SHOP_SORT_PRICE_ASC", "Цена: дешёвые") },
        { value = "price_desc", text = T("PG_SHOP_SORT_PRICE_DESC", "Цена: дорогие") },
        { value = "name",       text = T("PG_SHOP_SORT_NAME", "Название") },
        { value = "quantity",   text = T("PG_SHOP_SORT_QUANTITY", "Количество") },
    }

    local expansionOptions = {
        { value = "any", text = T("PG_SHOP_OPT_ANY", "Любое") },
        { value = 0,     text = "Classic" },
        { value = 1,     text = "The Burning Crusade" },
        { value = 2,     text = "Wrath of the Lich King" },
        { value = 3,     text = "Cataclysm" },
        { value = 4,     text = "Mists of Pandaria" },
        { value = 5,     text = "Warlords of Draenor" },
        { value = 6,     text = "Legion" },
        { value = 7,     text = "Battle for Azeroth" },
        { value = 8,     text = "Shadowlands" },
        { value = 9,     text = "Dragonflight" },
        { value = 10,    text = "The War Within" },
        { value = 11,    text = "Midnight" },
    }

    local materialQualityOptions = {
        { value = "any", text = T("PG_SHOP_OPT_ANY", "Любое") },
        { value = 1,     text = "R1" },
        { value = 2,     text = "R2" },
        { value = 3,     text = "R3" },
        { value = 4,     text = "R4" },
        { value = 5,     text = "R5" },
    }

    local function FindOptionText(options, value)
        for _, opt in ipairs(options) do
            if tostring(opt.value) == tostring(value) then
                return opt.text
            end
        end
        return options[1] and options[1].text or ""
    end

    local function MakeLabel(parent, text, x, y)
        local fs = MakeText(parent, 10, "LEFT")
        fs:SetPoint("TOPLEFT", x, y)
        fs:SetText(text)
        return fs
    end

    local function MakeInput(parent, w, key)
        local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        box:SetAutoFocus(false)
        box:SetFont(FONT, 11, "")
        box:SetSize(w, 20)
        box:SetText(tostring(GetOpts()[key] or ""))

        box:SetScript("OnEnterPressed", function(self)
            SetOpt(key, TrimText(self:GetText()))
            self:ClearFocus()
            RunSearchFromBox()
        end)

        box:SetScript("OnEditFocusLost", function(self)
            SetOpt(key, TrimText(self:GetText()))
        end)

        return box
    end

    local function MakeCheck(parent, text, key, x, y)
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", x, y)
        cb:SetChecked(GetOpts()[key] == true)

        cb.text = MakeText(parent, 10, "LEFT")
        cb.text:SetPoint("LEFT", cb, "RIGHT", -2, 0)
        cb.text:SetText(text)

        cb:SetScript("OnClick", function(self)
            SetOpt(key, self:GetChecked() == true)
            if S.RefreshWindow then
                S:RefreshWindow()
            end
        end)

        return cb
    end

    local function MakeDropdown(parent, w, options, getValue, setValue)
        local function ResolveOptions()
            if type(options) == "function" then
                local ok, result = pcall(options)
                if ok and type(result) == "table" then
                    return result
                end
                return {}
            end
            return options or {}
        end

        if UIDropDownMenu_Initialize and UIDropDownMenu_CreateInfo then
            local dd = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
            UIDropDownMenu_SetWidth(dd, w)

            function dd:RefreshText()
                UIDropDownMenu_SetText(self, FindOptionText(ResolveOptions(), getValue()))
            end

            dd:RefreshText()

            UIDropDownMenu_Initialize(dd, function()
                local list = ResolveOptions()
                for _, opt in ipairs(list) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = opt.text
                    info.checked = tostring(getValue()) == tostring(opt.value)
                    info.func = function()
                        setValue(opt.value, opt)
                        UIDropDownMenu_SetText(dd, opt.text)
                        CloseDropDownMenus()
                        if S.RefreshWindow then
                            S:RefreshWindow()
                        end
                    end
                    UIDropDownMenu_AddButton(info)
                end
            end)

            return dd
        end

        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetSize(w + 30, 20)

        function btn:RefreshText()
            self:SetText(FindOptionText(ResolveOptions(), getValue()))
        end

        btn:SetScript("OnClick", function(self)
            local list = ResolveOptions()
            local current = tostring(getValue())
            local nextIndex = 1

            for index, opt in ipairs(list) do
                if tostring(opt.value) == current then
                    nextIndex = index + 1
                    break
                end
            end

            if nextIndex > #list then
                nextIndex = 1
            end

            local opt = list[nextIndex]
            if not opt then
                return
            end

            setValue(opt.value, opt)
            self:RefreshText()

            if S.RefreshWindow then
                S:RefreshWindow()
            end
        end)

        btn:RefreshText()
        return btn
    end

    local function GetCategoryDropdownText()
        local opts = GetOpts()
        if opts.itemClassID == nil then
            return T("PG_SHOP_OPT_ANY", "Любой")
        end

        local model = GetItemCategoryModel()
        local class = model.byID[tonumber(opts.itemClassID)]
        local classText = class and class.text or tostring(opts.itemClassID)

        if opts.itemSubClassID ~= nil and class then
            for _, sub in ipairs(class.subs or {}) do
                if tonumber(sub.subClassID) == tonumber(opts.itemSubClassID) then
                    return classText .. " > " .. sub.text
                end
            end
        end

        return classText
    end

    local function SetCategoryFilter(classID, subClassID, inventoryType)
        classID = tonumber(classID)
        subClassID = tonumber(subClassID)
        inventoryType = nil

        if classID == nil then
            SetOpt("categoryKey", "any")
            SetOpt("itemClassID", nil)
            SetOpt("itemSubClassID", nil)
            SetOpt("inventoryType", nil)
            return
        end

        SetOpt("itemClassID", classID)
        SetOpt("itemSubClassID", subClassID)
        SetOpt("inventoryType", nil)
        SetOpt("categoryKey", subClassID ~= nil and MakeCategoryKey(classID, subClassID, nil) or tostring(classID))
    end

    local function MakeCategoryDropdown(parent, w)
        if UIDropDownMenu_Initialize and UIDropDownMenu_CreateInfo then
            local dd = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
            UIDropDownMenu_SetWidth(dd, w)

            function dd:RefreshText()
                UIDropDownMenu_SetText(self, GetCategoryDropdownText())
            end

            UIDropDownMenu_Initialize(dd, function(_, level, menuList)
                level = level or 1

                if level == 1 then
                    local anyInfo = UIDropDownMenu_CreateInfo()
                    anyInfo.text = T("PG_SHOP_OPT_ANY", "Любой")
                    anyInfo.checked = GetOpts().itemClassID == nil
                    anyInfo.func = function()
                        SetCategoryFilter(nil, nil, nil)
                        dd:RefreshText()
                        CloseDropDownMenus()
                        if S.RefreshWindow then S:RefreshWindow() end
                    end
                    UIDropDownMenu_AddButton(anyInfo, level)

                    for _, class in ipairs(GetItemCategoryModel().classes or {}) do
                        local info = UIDropDownMenu_CreateInfo()
                        info.text = class.text
                        info.value = class.classID
                        info.menuList = class.classID
                        info.hasArrow = #(class.subs or {}) > 0
                        info.checked = tonumber(GetOpts().itemClassID) == tonumber(class.classID) and GetOpts().itemSubClassID == nil
                        info.func = function()
                            SetCategoryFilter(class.classID, nil, nil)
                            dd:RefreshText()
                            CloseDropDownMenus()
                            if S.RefreshWindow then S:RefreshWindow() end
                        end
                        UIDropDownMenu_AddButton(info, level)
                    end
                    return
                end

                local classID = tonumber(menuList)
                local class = classID and GetItemCategoryModel().byID[classID]
                if not class then
                    return
                end

                local allInfo = UIDropDownMenu_CreateInfo()
                allInfo.text = T("PG_SHOP_OPT_ANY_SUBTYPE", "Все")
                allInfo.checked = tonumber(GetOpts().itemClassID) == classID and GetOpts().itemSubClassID == nil
                allInfo.func = function()
                    SetCategoryFilter(classID, nil, nil)
                    dd:RefreshText()
                    CloseDropDownMenus()
                    if S.RefreshWindow then S:RefreshWindow() end
                end
                UIDropDownMenu_AddButton(allInfo, level)

                for _, sub in ipairs(class.subs or {}) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = sub.text
                    info.checked = tonumber(GetOpts().itemClassID) == tonumber(sub.classID) and tonumber(GetOpts().itemSubClassID) == tonumber(sub.subClassID)
                    info.func = function()
                        SetCategoryFilter(sub.classID, sub.subClassID, nil)
                        dd:RefreshText()
                        CloseDropDownMenus()
                        if S.RefreshWindow then S:RefreshWindow() end
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            end)

            dd:RefreshText()
            return dd
        end

        local function FlatCategoryOptions()
            local out = {
                { value = "any", text = T("PG_SHOP_OPT_ANY", "Любой") },
            }
            for _, class in ipairs(GetItemCategoryModel().classes or {}) do
                table.insert(out, { value = tostring(class.classID), text = class.text, classID = class.classID })
                for _, sub in ipairs(class.subs or {}) do
                    table.insert(out, { value = sub.value, text = class.text .. " > " .. sub.text, classID = sub.classID, subClassID = sub.subClassID })
                end
            end
            return out
        end

        return MakeDropdown(
            parent,
            w,
            FlatCategoryOptions,
            function()
                local opts = GetOpts()
                if opts.itemClassID == nil then
                    return "any"
                end
                if opts.itemSubClassID ~= nil then
                    return MakeCategoryKey(opts.itemClassID, opts.itemSubClassID, nil)
                end
                return tostring(opts.itemClassID)
            end,
            function(value)
                if value == "any" then
                    SetCategoryFilter(nil, nil, nil)
                    return
                end
                local classID, subClassID = ParseCategoryKey(value)
                SetCategoryFilter(classID or tonumber(value), subClassID, nil)
            end
        )
    end

    if not f.searchOptionsPanel then
        local p = CreateFrame("Frame", nil, f.panel, "BackdropTemplate")
        p:SetSize(430, 314)
        p:SetFrameStrata("DIALOG")
        p:SetFrameLevel(10)
        p:EnableMouse(true)
        ApplyBlockFrame(p, 0.97)
        p:SetScript("OnHide", function()
            if f.searchOptionsBlocker then
                f.searchOptionsBlocker:Hide()
            end
        end)

        p.title = MakeText(p, 12, "LEFT")
        p.title:SetPoint("TOPLEFT", 12, -10)
        p.title:SetText(T("PG_SHOP_SEARCH_OPTIONS", "Расширенный поиск"))

        p.exactMatch = MakeCheck(p, T("PG_SHOP_OPT_EXACT", "Точный поиск"), "exactMatch", 10, -30)
        p.onlyAvailable = MakeCheck(p, T("PG_SHOP_OPT_ONLY_AVAILABLE", "Только доступные"), "onlyAvailable", 150, -30)
        p.hideNoPrice = MakeCheck(p, T("PG_SHOP_OPT_HIDE_NO_PRICE", "Скрыть без цены"), "hideNoPrice", 290, -30)

        MakeLabel(p, T("PG_SHOP_OPT_ITEM_TYPE", "Тип предмета"), 14, -68)
        p.itemClass = MakeCategoryDropdown(p, 100)
        p.itemClass:SetPoint("TOPLEFT", 80, -58)

        MakeLabel(p, T("PG_SHOP_OPT_QUALITY", "Качество"), 250, -68)
        p.quality = MakeDropdown(p, 60, qualityOptions, function() return GetOpts().quality or "any" end, function(value) SetOpt("quality", value) end)
        p.quality:SetPoint("TOPLEFT", 310, -58)

        MakeLabel(p, T("PG_SHOP_OPT_PRICE", "Цена"), 14, -105)
        p.minPrice = MakeInput(p, 40, "minPrice")
        p.minPrice:SetPoint("TOPLEFT", 105, -96)

        p.priceDash = MakeText(p, 10, "CENTER")
        p.priceDash:SetPoint("LEFT", p.minPrice, "RIGHT", 6, 0)
        p.priceDash:SetText("-")

        p.maxPrice = MakeInput(p, 40, "maxPrice")
        p.maxPrice:SetPoint("LEFT", p.priceDash, "RIGHT", 8, 0)

        MakeLabel(p, T("PG_SHOP_OPT_MIN_QTY", "Кол-во от"), 250, -105)
        p.minQuantity = MakeInput(p, 30, "minQuantity")
        p.minQuantity:SetPoint("TOPLEFT", 335, -96)

        MakeLabel(p, T("PG_SHOP_OPT_ITEM_LEVEL", "Ур. предмета"), 14, -140)
        p.minItemLevel = MakeInput(p, 40, "minItemLevel")
        p.minItemLevel:SetPoint("TOPLEFT", 105, -131)

        p.ilvlDash = MakeText(p, 10, "CENTER")
        p.ilvlDash:SetPoint("LEFT", p.minItemLevel, "RIGHT", 4, 0)
        p.ilvlDash:SetText("-")

        p.maxItemLevel = MakeInput(p, 40, "maxItemLevel")
        p.maxItemLevel:SetPoint("LEFT", p.ilvlDash, "RIGHT", 8, 0)

        MakeLabel(p, T("PG_SHOP_OPT_REQUIRED_LEVEL", "Треб. уровень"), 250, -140)
        p.minRequiredLevel = MakeInput(p, 30, "minRequiredLevel")
        p.minRequiredLevel:SetPoint("TOPLEFT", 335, -131)

        p.reqDash = MakeText(p, 10, "CENTER")
        p.reqDash:SetPoint("LEFT", p.minRequiredLevel, "RIGHT", 4, 0)
        p.reqDash:SetText("-")

        p.maxRequiredLevel = MakeInput(p, 30, "maxRequiredLevel")
        p.maxRequiredLevel:SetPoint("LEFT", p.reqDash, "RIGHT", 8, 0)

        MakeLabel(p, T("PG_SHOP_OPT_EXPANSION", "Дополнение"), 14, -177)
        p.expansion = MakeDropdown(p, 100, expansionOptions, function() return GetOpts().expansionID or "any" end, function(value) SetOpt("expansionID", value) end)
        p.expansion:SetPoint("TOPLEFT", 80, -167)

        MakeLabel(p, T("PG_SHOP_OPT_MATERIAL_QUALITY", "Кач-во мат."), 250, -177)
        p.materialQuality = MakeDropdown(p, 60, materialQualityOptions, function() return GetOpts().materialQuality or "any" end, function(value) SetOpt("materialQuality", value) end)
        p.materialQuality:SetPoint("TOPLEFT", 310, -167)

        MakeLabel(p, T("PG_SHOP_OPT_SORT", "Сортировка"), 14, -214)
        p.sortMode = MakeDropdown(p, 100, sortOptions, function() return GetOpts().sortMode or "price_asc" end, function(value) SetOpt("sortMode", value) end)
        p.sortMode:SetPoint("TOPLEFT", 80, -204)

        p.note = MakeText(p, 10, "LEFT")
        p.note:SetPoint("TOPLEFT", 14, -238)
        p.note:SetPoint("RIGHT", -14, 0)
        p.note:SetText(T("PG_SHOP_SEARCH_FILTER_NOTE", "Пустой поиск работает только с типом, качеством или требуемым уровнем."))

        p.reset = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
        p.reset:SetSize(100, 22)
        p.reset:SetPoint("BOTTOMLEFT", 12, 10)
        p.reset:SetText(T("PG_SHOP_RESET_ALL", "Сбросить"))
        p.reset:SetScript("OnClick", function()
            if S.ResetSearchOptions then
                S:ResetSearchOptions(true)
            end

            HideSearchOptionsPanel()
            f.searchOptionsPanel = nil

            if S.RefreshWindow then
                S:RefreshWindow()
            end
        end)

        p.search = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
        p.search:SetSize(90, 22)
        p.search:SetPoint("BOTTOMRIGHT", -12, 10)
        p.search:SetText(T("PG_SHOP_SEARCH", "Поиск"))
        p.search:SetScript("OnClick", function()
            RunSearchFromBox()
        end)

        f.searchOptionsPanel = p
    else
        local opts = GetOpts()

        if f.searchOptionsPanel.itemClass and f.searchOptionsPanel.itemClass.RefreshText then f.searchOptionsPanel.itemClass:RefreshText() end
        if f.searchOptionsPanel.quality and f.searchOptionsPanel.quality.RefreshText then f.searchOptionsPanel.quality:RefreshText() end
        if f.searchOptionsPanel.sortMode and f.searchOptionsPanel.sortMode.RefreshText then f.searchOptionsPanel.sortMode:RefreshText() end
        if f.searchOptionsPanel.expansion and f.searchOptionsPanel.expansion.RefreshText then f.searchOptionsPanel.expansion:RefreshText() end
        if f.searchOptionsPanel.materialQuality and f.searchOptionsPanel.materialQuality.RefreshText then f.searchOptionsPanel.materialQuality:RefreshText() end

        if f.searchOptionsPanel.exactMatch then f.searchOptionsPanel.exactMatch:SetChecked(opts.exactMatch == true) end
        if f.searchOptionsPanel.onlyAvailable then f.searchOptionsPanel.onlyAvailable:SetChecked(opts.onlyAvailable == true) end
        if f.searchOptionsPanel.hideNoPrice then f.searchOptionsPanel.hideNoPrice:SetChecked(opts.hideNoPrice == true) end
        if f.searchOptionsPanel.minPrice then f.searchOptionsPanel.minPrice:SetText(tostring(opts.minPrice or "")) end
        if f.searchOptionsPanel.maxPrice then f.searchOptionsPanel.maxPrice:SetText(tostring(opts.maxPrice or "")) end
        if f.searchOptionsPanel.minQuantity then f.searchOptionsPanel.minQuantity:SetText(tostring(opts.minQuantity or "")) end
        if f.searchOptionsPanel.minItemLevel then f.searchOptionsPanel.minItemLevel:SetText(tostring(opts.minItemLevel or "")) end
        if f.searchOptionsPanel.maxItemLevel then f.searchOptionsPanel.maxItemLevel:SetText(tostring(opts.maxItemLevel or "")) end
        if f.searchOptionsPanel.minRequiredLevel then f.searchOptionsPanel.minRequiredLevel:SetText(tostring(opts.minRequiredLevel or "")) end
        if f.searchOptionsPanel.maxRequiredLevel then f.searchOptionsPanel.maxRequiredLevel:SetText(tostring(opts.maxRequiredLevel or "")) end
    end

    f.searchOptionsPanel:ClearAllPoints()
    f.searchOptionsPanel:SetPoint("TOPRIGHT", anchor or f.panel, "BOTTOMRIGHT", 0, -6)

    if f.searchOptionsBlocker then
        f.searchOptionsBlocker:SetFrameStrata("DIALOG")
        f.searchOptionsBlocker:SetFrameLevel(1)
        f.searchOptionsBlocker:Show()
    end

    f.searchOptionsPanel:SetFrameStrata("DIALOG")
    f.searchOptionsPanel:SetFrameLevel(10)
    f.searchOptionsPanel:Show()
end

function S:ClearSearchText(keepResults)
    local f = self.frame
    if f and f.searchBox then
        f.searchBox._ahuiSuppressTextChanged = true
        f.searchBox:SetText("")
        f.searchBox._ahuiSuppressTextChanged = nil
        f.searchBox:ClearFocus()
        RefreshSearchClearButton(f)
    end

    self.activeSearchBox = nil
    self.lastSearchBox = nil
    self.lastSearchBoxUntil = nil
    self.lastInsertedSearchLink = nil
    self.lastInsertedSearchLinkTime = nil

    if not keepResults and self.ClearAuctionSearch then
        self:ClearAuctionSearch()
    end
end

local function AddSelectedSearchResultToList()
    local row = S.selectedSearchResult

    if not row and S.searchResults and S.searchResults.rows then
        for _, candidate in ipairs(S.searchResults.rows or {}) do
            if candidate and candidate.itemID and (not S.SearchResultMatchesOptions or S:SearchResultMatchesOptions(candidate)) then
                row = candidate
                break
            end
        end
    end

    if not row or not row.itemID then
        return
    end

    local quantity = 1
    if row.isCommodity == true and S.frame and S.frame.rows then
        for _, widget in ipairs(S.frame.rows) do
            if widget and widget.hotspot and widget.hotspot.searchRow == row and widget.qtyBox then
                quantity = tonumber(widget.qtyBox:GetText()) or 1
                break
            end
        end
    end

    quantity = math.floor(quantity)
    if quantity <= 0 then
        quantity = 1
    end

    if S.AddItemToActiveList then
        S:AddItemToActiveList(row.itemID, quantity, row.label, row)
        S.selectedSearchResult = nil
        if S.RefreshWindow then
            S:RefreshWindow()
        end
    end
end

local function GetSearchTextFromItemLink(link)
    if type(link) ~= "string" or link == "" then
        return nil
    end

    local itemID = tonumber(link:match("item:(%d+)"))
    local name = GetItemInfo(link)

    if not name and itemID then
        name = GetItemInfo(itemID)
        if not name and C_Item and C_Item.RequestLoadItemDataByID then
            C_Item.RequestLoadItemDataByID(itemID)
        end
    end

    return name or (itemID and ("item:" .. itemID)) or link
end

local function HasActiveChatEditBox()
    local chatBox = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
    return chatBox and chatBox:IsShown() and chatBox:HasFocus()
end

local function GetSearchBoxForShiftClick()
    local f = S.frame
    if not f or not f:IsShown() or not f.searchBox or not f.searchBox:IsShown() then
        return nil
    end

    if HasActiveChatEditBox() then
        return nil
    end

    if S.activeSearchBox and S.activeSearchBox:IsShown() then
        return S.activeSearchBox
    end

    if f.searchBox:HasFocus() then
        return f.searchBox
    end

    return f.searchBox
end

local function InsertLinkIntoSearchBox(link)
    local box = GetSearchBoxForShiftClick()
    if not box then
        return false
    end

    local text = GetSearchTextFromItemLink(link)
    if not text or text == "" then
        return false
    end

    local now = GetTime and GetTime() or 0
    if S.lastInsertedSearchLink == link and S.lastInsertedSearchLinkTime and (now - S.lastInsertedSearchLinkTime) < 0.25 then
        return true
    end

    S.lastInsertedSearchLink = link
    S.lastInsertedSearchLinkTime = now

    box:SetFocus()
    box:SetText(text)
    box:SetCursorPosition(strlen(text))

    S.activeSearchBox = box
    S.lastSearchBox = box
    S.lastSearchBoxUntil = now + 10

    if S.StartAuctionSearch then
        S:StartAuctionSearch(text)
    end

    C_Timer.After(0, function()
        if box and box:IsShown() then
            box:SetFocus()
            box:SetCursorPosition(strlen(box:GetText() or ""))
        end
    end)

    return true
end

local function InstallSearchBoxLinkHandler()
    if S.searchBoxLinkHandlerInstalled then
        return
    end
    S.searchBoxLinkHandlerInstalled = true

    local oldChatEditInsertLink = ChatEdit_InsertLink
    ChatEdit_InsertLink = function(link, ...)
        if InsertLinkIntoSearchBox(link) then
            return true
        end

        if oldChatEditInsertLink then
            return oldChatEditInsertLink(link, ...)
        end

        return false
    end

    local oldHandleModifiedItemClick = HandleModifiedItemClick
    HandleModifiedItemClick = function(link, ...)
        if link and (IsShiftKeyDown() or (IsModifiedClick and IsModifiedClick("CHATLINK"))) then
            if InsertLinkIntoSearchBox(link) then
                return true
            end
        end

        if oldHandleModifiedItemClick then
            return oldHandleModifiedItemClick(link, ...)
        end

        return false
    end
end

local function StripTempPrefix(name)
    if type(name) ~= "string" then return name end
    return (name:gsub("^|cffffd200%[TEMP%]|r%s*", ""))
end

local function PromptRenameList(item)
    if not item or item.kind ~= "saved" or not item.id then
        return
    end

    PromptText(
        "HIRONCRAFT_PROFIT_SHOPPING_RENAME_LIST",
        T("PG_SHOP_RENAME_LIST", "Rename shopping list"),
        StripTempPrefix(item.name or ""),
        function(name)
            if name ~= "" and S.RenameSavedList then
                S:RenameSavedList(item.id, name)
            end
        end
    )
end

local function PromptSaveTempList(item)
    if not item or not item.id then return end
    PromptText(
        "HIRONCRAFT_PROFIT_SHOPPING_SAVE_TEMP_LIST",
        T("PG_SHOP_SAVE_LIST", "Save shopping list"),
        StripTempPrefix(item.name or ""),
        function(name)
            local cleanName = name ~= "" and name or StripTempPrefix(item.name or "")
            if S.PromoteTempListToSaved then
                S:PromoteTempListToSaved(item.id, cleanName)
            end
        end
    )
end

local function ShowListContextMenu(owner, item)
    if not item or item.kind ~= "saved" or not item.id then
        return
    end

    local entries = {}

    if item.temporary then
        table.insert(entries, {
            text = T("PG_SHOP_MENU_SAVE", "Save"),
            onClick = function() PromptSaveTempList(item) end,
        })
    end

    table.insert(entries, {
        text = T("PG_SHOP_MENU_RENAME", "Rename"),
        onClick = function() PromptRenameList(item) end,
    })

    table.insert(entries, {
        text = T("PG_SHOP_MENU_DELETE", "Delete"),
        onClick = function()
            if S.DeleteSavedList then
                S:DeleteSavedList(item.id)
            end
        end,
    })

    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
            rootDescription:SetTag("HIRONCRAFT_PROFIT_SHOPPING_LIST_MENU")
            for _, entry in ipairs(entries) do
                rootDescription:CreateButton(entry.text, entry.onClick)
            end
        end)
    elseif EasyMenu then
        local menuItems = {}
        for _, entry in ipairs(entries) do
            table.insert(menuItems, { text = entry.text, func = entry.onClick, notCheckable = true })
        end
        local menuFrame = CreateFrame("Frame", "HironCraftProfitShoppingListMenuFrame", UIParent, "UIDropDownMenuTemplate")
        EasyMenu(menuItems, menuFrame, "cursor", 0, 0, "MENU")
    end
end

local function CreateListButton(parent, index)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetHeight(26)
    btn:SetWidth(SIDEBAR_W - 16)
    btn:SetPoint("LEFT", 0, 0)
    btn:SetPoint("RIGHT", 0, 0)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    if IsFantasy() then
        btn.atlasBg = btn:CreateTexture(nil, "BACKGROUND")
        btn.atlasBg:SetAllPoints()
        btn.atlasBg:SetAtlas("Ui-Dialog-New-Button-Down")
        btn.atlasBg:SetVertexColor(0.32, 0.32, 0.34)
        btn.atlasBg:SetAlpha(0.9)
    else
        SetFrameBackdrop(btn, 0.16)
        btn:SetBackdropBorderColor(1, 1, 1, 0.05)
    end

    btn.refresh = CreateFrame("Button", nil, btn)
    btn.refresh:SetSize(16, 16)
    btn.refresh:SetPoint("RIGHT", -4, 0)
    if IsFantasy() then
        btn.refresh:SetSize(22, 22)
        btn.refresh:SetNormalAtlas("128-RedButton-Refresh")
        btn.refresh:SetPushedAtlas("128-RedButton-Refresh-Pressed")
    else
        btn.refresh:SetNormalAtlas("uitools-icon-refresh")
    end
    btn.refresh:SetScript("OnEnter", function(self)
        local tex = self:GetNormalTexture()
        if tex then tex:SetVertexColor(1.3, 1.3, 1.3) end
        local TT = PT and PT.Tooltip
        if TT then
            TT:Clear()
            TT:AddLine(T("PG_SHOP_RESCAN_LIST", "Refresh prices for this list"), 12, 1, 1, 1)
            TT:ShowCursorRightOrBelow()
        end
    end)
    btn.refresh:SetScript("OnLeave", function(self)
        local tex = self:GetNormalTexture()
        if tex then tex:SetVertexColor(1, 1, 1) end
        if PT and PT.Tooltip then PT.Tooltip:Clear() end
    end)
    btn.refresh:SetScript("OnClick", function(self)
        local item = btn.item
        if not item then return end
        if item.kind ~= "saved" and item.kind ~= "temporary" then return end

        local wasActive = (S.activeSavedListID == item.id)
        if not wasActive and S.LoadSavedList then
            S:LoadSavedList(item.id)
        end

        if not S.RefreshPrices then return end

        local function tryRefresh(attempt)
            if S.session and S.session.active and S.activeSavedListID == item.id then
                S:RefreshPrices()
                return
            end
            if attempt >= 20 then return end
            C_Timer.After(0.1, function() tryRefresh(attempt + 1) end)
        end
        tryRefresh(0)
    end)
    if PT and PT.AddPressFX then PT.AddPressFX(btn.refresh) end
    btn.refresh:Hide()

    btn.name = MakeText(btn, 10, "LEFT")
    btn.name:SetPoint("LEFT", 8, 0)
    btn.name:SetPoint("RIGHT", btn.refresh, "LEFT", -4, 0)
    btn.name:SetWordWrap(false)
    btn.name:SetMaxLines(1)

    btn.count = MakeText(btn, 10, "RIGHT")
    btn.count:SetPoint("RIGHT", btn.refresh, "LEFT", -2, 0)
    btn.count:SetWidth(24)
    btn.count:Hide()

    btn:SetScript("OnEnter", function(self)
        if self.item then
            ShowSimpleTooltip(self, self.item.name, self.item.kindText)
        end
    end)
    btn:SetScript("OnLeave", function()
        HideSimpleTooltip()
    end)
    btn:SetScript("OnClick", function(self, button)
        local item = self.item
        if not item then return end

        if item.kind == "history" then
            if button == "RightButton" then
                if S.RemoveSearchHistory then
                    S:RemoveSearchHistory(item.query or item.name)
                end
                return
            end

            local f = S.frame
            if f and f.searchBox then
                f.searchBox._ahuiSuppressTextChanged = true
                f.searchBox:SetText(item.query or item.name or "")
                f.searchBox._ahuiSuppressTextChanged = nil
                f.searchBox:SetFocus()
                f.searchBox:SetCursorPosition(strlen(f.searchBox:GetText() or ""))
            end
            RunSearchFromBox()
            return
        end

        if button == "RightButton" then
            ShowListContextMenu(self, item)
            return
        end
        if item.kind == "saved" and S.LoadSavedList then
            S:LoadSavedList(item.id)
        end
    end)

    return btn
end

local function BuildListItems()
    local items = {}
    local mode = S.shoppingSidebarMode or "lists"

    if mode == "history" then
        if S.GetSearchHistory then
            local currentQuery = Lower(S.searchResults and S.searchResults.query or "")
            for _, entry in ipairs(S:GetSearchHistory() or {}) do
                local text = TrimText(entry.text)
                if text ~= "" then
                    table.insert(items, {
                        kind = "history",
                        name = text,
                        query = text,
                        kindText = T("PG_SHOP_HISTORY_ITEM_TOOLTIP", "Left click — search again. Right click — remove from history."),
                        count = (tonumber(entry.count) or 0) > 1 and tostring(entry.count) or "",
                        active = currentQuery ~= "" and Lower(text) == currentQuery,
                    })
                end
            end
        end
        return items
    end

    if S.GetSavedLists then
        for _, list in ipairs(S:GetSavedLists() or {}) do
            local displayName = list.name or list.id
            if list.temporary then
                displayName = "|cffffd200[TEMP]|r " .. displayName
            end
            table.insert(items, {
                id = list.id,
                kind = "saved",
                name = displayName,
                kindText = list.temporary
                    and T("PG_SHOP_LIST_TEMPORARY_TOOLTIP", "Temporary list (will be wiped on reload). Click Save to keep permanently.")
                    or T("PG_SHOP_LIST_SAVED", "Saved list"),
                count = list.count or 0,
                active = S.activeSavedListID == list.id,
                temporary = list.temporary == true,
            })
        end
    end

    return items
end

local function EnsureListButtons(frame, needed)
    frame.listButtons = frame.listButtons or {}
    local current = #frame.listButtons
    if current >= needed then return end

    for index = current + 1, needed do
        local btn = CreateListButton(frame.listContent, index)
        if index == 1 then
            btn:SetPoint("TOP", frame.listContent, "TOP", 0, 0)
        else
            btn:SetPoint("TOP", frame.listButtons[index - 1], "BOTTOM", 0, -4)
        end
        frame.listButtons[index] = btn
    end
end

local function CreateSidebarTab(parent, text, width)
    local tab = CreateFrame("Button", nil, parent, "BackdropTemplate")
    tab:SetSize(width or SIDEBAR_TAB_W, SIDEBAR_TAB_H)
    tab:RegisterForClicks("LeftButtonUp")
    tab:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    tab.label = MakeText(tab, 10, "CENTER")
    tab.label:SetPoint("CENTER", 0, 1)
    tab.label:SetText(text or "")

    tab:SetScript("OnEnter", function(self)
        if self._active then return end
        self:SetBackdropColor(0.10, 0.12, 0.16, 0.55)
        self:SetBackdropBorderColor(0.55, 0.75, 1.0, 0.22)
        if self.label then self.label:SetTextColor(0.86, 0.90, 0.98) end
    end)
    tab:SetScript("OnLeave", function(self)
        if self._active then return end
        self:SetBackdropColor(0.02, 0.02, 0.03, 0.34)
        self:SetBackdropBorderColor(1, 1, 1, 0.08)
        if self.label then self.label:SetTextColor(0.62, 0.62, 0.68) end
    end)

    tab.bottomCover = tab:CreateTexture(nil, "OVERLAY")
    tab.bottomCover:SetColorTexture(0.05, 0.05, 0.07, 0.95)
    tab.bottomCover:SetPoint("BOTTOMLEFT", 1, -1)
    tab.bottomCover:SetPoint("BOTTOMRIGHT", -1, -1)
    tab.bottomCover:SetHeight(2)
    tab.bottomCover:Hide()

    return tab
end

local function SetSidebarTabVisual(button, active)
    if not button then return end

    button._active = active and true or false

    if active then
        button:SetBackdropColor(0.05, 0.05, 0.07, 0.62)
        button:SetBackdropBorderColor(0.55, 0.75, 1.0, 0.45)
        button:SetAlpha(1)
        if button.label then
            button.label:SetTextColor(1, 1, 1)
        end
        if button.bottomCover then
            button.bottomCover:Show()
        end
    else
        button:SetBackdropColor(0.02, 0.02, 0.03, 0.34)
        button:SetBackdropBorderColor(1, 1, 1, 0.08)
        button:SetAlpha(1)
        if button.label then
            button.label:SetTextColor(0.62, 0.62, 0.68)
        end
        if button.bottomCover then
            button.bottomCover:Hide()
        end
    end
end

local function RefreshListPanel(frame)
    if not frame then return end

    local mode = S.shoppingSidebarMode or "lists"
    local showLists = mode == "lists"
    local items = BuildListItems()
    local contentWidth = frame.listScroll and frame.listScroll:GetWidth() or 0
    if contentWidth < 20 then
        contentWidth = SIDEBAR_W - 16
    end
    if frame.listContent then
        frame.listContent:SetWidth(contentWidth)
    end

    if IsFantasy() and frame.LayoutSideTabs then
        if showLists then
            PanelTemplates_SelectTab(frame.listsTab)
            PanelTemplates_DeselectTab(frame.historyTab)
        else
            PanelTemplates_DeselectTab(frame.listsTab)
            PanelTemplates_SelectTab(frame.historyTab)
        end
        for _, tb in ipairs({ frame.listsTab, frame.historyTab }) do
            SetTabHeightForced(tb, SHOP_FTAB_H)
        end
        frame.LayoutSideTabs()
    else
        SetSidebarTabVisual(frame.listsTab, showLists)
        SetSidebarTabVisual(frame.historyTab, not showLists)
    end

    if frame.newList then frame.newList:SetShown(showLists) end
    if frame.saveList then frame.saveList:SetShown(showLists) end
    if frame.deleteList then frame.deleteList:SetShown(showLists) end
    if frame.importList then frame.importList:SetShown(showLists) end
    if frame.exportList then frame.exportList:SetShown(showLists) end
    if frame.clearHistory then
        frame.clearHistory:SetShown(not showLists)
        frame.clearHistory:SetEnabled((not showLists) and #items > 0 and S.ClearSearchHistory ~= nil)
    end

    EnsureListButtons(frame, #items)

    for index, item in ipairs(items) do
        local btn = frame.listButtons[index]
        btn.item = item
        btn:SetWidth(contentWidth)
        btn.name:SetText(item.name or "?")
        btn.count:SetText(tostring(item.count or ""))
        btn:Show()

        if btn.refresh then
            local showRefresh = (item.kind == "saved" or item.kind == "temporary")
            btn.refresh:SetShown(showRefresh)
        end

        if item.active then
            btn:SetBackdropColor(0.18, 0.30, 0.42, 0.60)
            btn:SetBackdropBorderColor(0.55, 0.75, 1.0, 0.45)
        else
            btn:SetBackdropColor(0.05, 0.05, 0.07, 0.16)
            btn:SetBackdropBorderColor(1, 1, 1, 0.05)
        end
    end

    for index = #items + 1, #(frame.listButtons or {}) do
        frame.listButtons[index]:Hide()
        frame.listButtons[index].item = nil
    end

    local contentHeight = math.max(1, #items * 30)
    frame.listContent:SetHeight(contentHeight)

    if frame.deleteList then
        frame.deleteList:SetEnabled(showLists and S.activeSavedListID ~= nil and S.DeleteSavedList ~= nil)
    end
    if frame.saveList then
        local rowCount = #(S:GetRows() or {})
        frame.saveList:SetEnabled(showLists and HasShoppingSession() and S.SaveActiveList ~= nil and (rowCount > 0 or S.activeSavedListID ~= nil))
    end
end

local function IsConsumableOrReagent(rowData)
    local classID = tonumber(rowData and rowData.itemClassID)
    return classID == 0 or classID == 5 or classID == 7
end

local function GetItemTierCount(rowData)
    local itemID = GetDisplayItemID(rowData)
    if not itemID then return 3 end

    local expac = select(15, GetItemInfo(itemID))
    expac = tonumber(expac)
    if expac and expac >= 11 then
        return 2
    end
    return 3
end

local function GetProfessionTierAtlasForRow(rowData, requireChoice)
    if not rowData then
        return nil
    end

    if requireChoice and not IsChoiceRow(rowData) then
        return nil
    end

    local tier = GetTierFromRow(rowData)
    if not tier then
        return nil
    end

    local count = GetItemTierCount(rowData)

    if count <= 2 then
        if tier < 1 or tier > 2 then
            return nil
        end
        return "Professions-Icon-Quality-12-Tier" .. tostring(tier)
    end

    if tier < 1 or tier > 3 then
        return nil
    end
    return "Professions-Icon-Quality-Tier" .. tostring(tier)
end

local function SetNameTierIcon(row, rowData)
    if not row or not row.nameTierIcon then
        return
    end

    local atlas = GetProfessionTierAtlasForRow(rowData, false)
    if not atlas or not row.nameTierIcon.SetAtlas then
        row.nameTierIcon:Hide()
        return
    end

    local ok = pcall(row.nameTierIcon.SetAtlas, row.nameTierIcon, atlas)
    if not ok then
        row.nameTierIcon:Hide()
        return
    end

    row.nameTierIcon:SetSize(NAME_TIER_ICON_SIZE, NAME_TIER_ICON_SIZE)
    row.nameTierIcon:ClearAllPoints()

    local anchor = row.icon
    if not anchor then
        row.nameTierIcon:Hide()
        return
    end

    row.nameTierIcon:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 3, -3)
    row.nameTierIcon:Show()
end

GetProfessionTierAtlas = function(rowData)
    return GetProfessionTierAtlasForRow(rowData, true)
end
local function CreateRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    local colShift = IsFantasy() and FROW_COL_SHIFT or 0
    row:EnableMouse(true)
    row:SetScript("OnMouseDown", function(self)
        if self.searchRow then
            S.selectedSearchResult = self.searchRow
            if S.RefreshWindow then
                S:RefreshWindow()
            end
        end
    end)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    if IsFantasy() then
        row.bg:SetAtlas("Ui-Dialog-New-Button-Down")
        row.bg:SetVertexColor(0.32, 0.32, 0.34)
        row.bg:SetAlpha((index % 2 == 0) and 0.9 or 0.7)
    else
        row.bg:SetColorTexture(1, 1, 1, (index % 2 == 0) and 0.035 or 0.02)
    end

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", 6, 0)

    row.name = MakeText(row, 11, "LEFT")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", -420, 0)
    row.name:SetWordWrap(false)
    row.name:SetMaxLines(1)

    row.nameTierIcon = row:CreateTexture(nil, "OVERLAY")
    row.nameTierIcon:SetSize(NAME_TIER_ICON_SIZE, NAME_TIER_ICON_SIZE)
    row.nameTierIcon:Hide()

    row.qtyBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    row.qtyBox:SetSize(QTY_W, 20)
    row.qtyBox:SetPoint("RIGHT", -(ACTION_W + STATUS_W + AH_W + PRICE_W + 40) - colShift, 0)
    row.qtyBox:SetAutoFocus(false)
    row.qtyBox:SetNumeric(true)
    row.qtyBox:SetJustifyH("CENTER")
    row.qtyBox:SetFont(FONT, 11, "")
    row.qtyBox:SetScript("OnEnterPressed", ApplyQuantityFromBox)
    row.qtyBox:SetScript("OnEscapePressed", function(self)
        if self.searchRow and self.searchRow.isSearchResult then
            if self.searchRow.isCommodity == true then
                local current = GetRemainingQuantity(self.searchRow)
                self:SetText(tostring(current > 0 and current or 1))
            else
                self:SetText("1")
            end
            self:ClearFocus()
            return
        end

        local rowData = self.rowIndex and S.session and S.session.rows and S.session.rows[self.rowIndex]
        self:SetText(tostring(GetRemainingQuantity(rowData)))
        self:ClearFocus()
    end)
    row.qtyBox:SetScript("OnEditFocusLost", ApplyQuantityFromBox)
    row.qtyBox:SetScript("OnEnter", function(self)
        ShowSimpleTooltip(self, T("PG_SHOP_COL_QUANTITY", "Quantity"), T("PG_SHOP_QTY_TOOLTIP", "Edit the quantity and press Enter."))
    end)
    row.qtyBox:SetScript("OnLeave", function()
        HideSimpleTooltip()
    end)

    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.name:SetPoint("RIGHT", row.qtyBox, "LEFT", -12, 0)

    row.price = MakeText(row, 11, "RIGHT")
    row.price:SetPoint("RIGHT", row, "RIGHT", -188 - colShift, 0)
    row.price:SetWidth(PRICE_W)

    row.available = MakeText(row, 11, "RIGHT")
    row.available:SetPoint("RIGHT", row, "RIGHT", -132 - colShift, 0)
    row.available:SetWidth(AH_W)

    row.status = MakeText(row, 10, "RIGHT")
    row.status:SetPoint("LEFT", row.available, "RIGHT", 0, 0)
    row.status:SetWidth(STATUS_W)

    row.buyBtn = CreateIconButton(row, "Perks-ShoppingCart", T("PG_SHOP_BUY", "Buy"), T("PG_SHOP_BUY_TOOLTIP", "Start purchase for this item."), BUY_BTN_SIZE, BUY_ICON_SIZE)
    row.buyBtn:SetSize(BUY_BTN_SIZE, BUY_BTN_SIZE)
    row.buyBtn.icon:SetSize(BUY_ICON_SIZE, BUY_ICON_SIZE)
    row.buyBtn.iconSize = BUY_ICON_SIZE
    if IsFantasy() then
        row.buyBtn:SetSize(FROW_BTN_H, FROW_BTN_H)
        SetRedButtonAtlas(row.buyBtn, "128-RedButton-ShoppingCart", "128-RedButton-ShoppingCart-Pressed", FROW_BTN_H, "128-RedButton-ShoppingCart-Disabled")
    end
    row.buyBtn:SetPoint("RIGHT", 0, 0)
    row.buyBtn.rowFrame = row
    row.buyBtn:SetScript("OnClick", function(self)
        if self.mode == "buy_search_result" then
            local qty = 1
            if self.rowFrame and self.rowFrame.qtyBox then
                qty = tonumber(self.rowFrame.qtyBox:GetText()) or 1
            end
            if self.searchRow and S.BuySearchResultRow then
                S:BuySearchResultRow(self.searchRow, qty)
            elseif self.itemID and S.BuySearchResult then
                S:BuySearchResult(self.itemID, qty, self.itemName)
            end
            return
        end

        if self.rowIndex then
            S:BuyRow(self.rowIndex)
        end
    end)

    row.scanBtn = CreateIconButton(row, "uitools-icon-refresh", T("PG_SHOP_RESCAN", "Rescan"), T("PG_SHOP_RESCAN_TOOLTIP", "Refresh price for this item."))
    row.scanBtn:SetSize(18, 18)
    row.scanBtn.icon:SetSize(18, 18)
    if IsFantasy() then
        row.scanBtn:SetSize(FROW_BTN_H, FROW_BTN_H)
        SetRedButtonAtlas(row.scanBtn, "128-RedButton-Refresh", "128-RedButton-Refresh-Pressed", FROW_BTN_H, "128-RedButton-Refresh-Disabled")
        row.scanBtn:SetPoint("RIGHT", row.buyBtn, "LEFT", -FROW_BTN_GAP, 0)
    else
        row.scanBtn:SetPoint("RIGHT", row.buyBtn, "LEFT", 2, 0)
    end
    row.scanBtn:SetScript("OnClick", function(self)
        if self.rowIndex then
            S:ScanRow(self.rowIndex)
        end
    end)

    row.deleteBtn = CreateIconButton(row, "common-icon-redx", T("PG_SHOP_DELETE", "Delete"), T("PG_SHOP_DELETE_ROW_TOOLTIP", "Remove this item from the shopping list."))
    row.deleteBtn:SetSize(18, 18)
    row.deleteBtn.icon:SetSize(16, 16)
    if IsFantasy() then
        row.deleteBtn:SetSize(FROW_BTN_H, FROW_BTN_H)
        SetRedButtonAtlas(row.deleteBtn, "128-RedButton-Delete", "128-RedButton-Delete-Pressed", FROW_BTN_H, "128-RedButton-Delete-Disabled")
        row.deleteBtn:SetPoint("RIGHT", row.scanBtn, "LEFT", -FROW_BTN_GAP, 0)
    else
        row.deleteBtn:SetPoint("RIGHT", row.scanBtn, "LEFT", 0, 0)
    end
    row.deleteBtn:SetScript("OnClick", function(self)
        if self.rowIndex and S.RemoveRow then
            S:RemoveRow(self.rowIndex)
        end
    end)

    row.hotspot = CreateFrame("Frame", nil, row)
    row.hotspot:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.hotspot:SetPoint("BOTTOMRIGHT", row.qtyBox, "BOTTOMLEFT", -4, 0)
    row.hotspot:EnableMouse(true)
    row.hotspot:SetFrameLevel(row:GetFrameLevel() + 5)
    row.hotspot.rowFrame = row
    row.hotspot:SetScript("OnEnter", function(self)
        if self.itemID then
            ShowItemTooltip(self, self.itemID, self.searchRow)
        else
            ShowRowTooltip(self.rowFrame)
        end
    end)
    row.hotspot:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    row.hotspot:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and IsShiftKeyDown() then
            local itemID
            if self.itemID then
                itemID = self.itemID
            elseif self.rowFrame and self.rowFrame.rowIndex and S.GetRows then
                local rowData = S:GetRows()[self.rowFrame.rowIndex]
                if rowData then
                    itemID = rowData.chosenItemID or rowData.itemID
                        or (rowData.options and rowData.options[1] and rowData.options[1].itemID)
                end
            end

            if itemID then
                local _, link = GetItemInfo(itemID)
                if not link and C_Item and C_Item.RequestLoadItemDataByID then
                    C_Item.RequestLoadItemDataByID(itemID)
                    link = "item:" .. tostring(itemID)
                end
                if link and InsertLinkIntoSearchBox then
                    if InsertLinkIntoSearchBox(link) then
                        return
                    end
                end
            end
        end

        if self.searchRow then
            S.selectedSearchResult = self.searchRow
            if S.RefreshWindow then
                S:RefreshWindow()
            end
        end
    end)

    return row
end

local function ConfigureRowHotspot(row, isSearchResult)
    if not row or not row.hotspot then
        return
    end

    row.hotspot:ClearAllPoints()

    if isSearchResult then
        row.hotspot:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.hotspot:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        local inputLevel = row.hotspot:GetFrameLevel() + 1
        if row.qtyBox then
            row.qtyBox:SetFrameLevel(inputLevel)
        end
        if row.buyBtn then
            row.buyBtn:SetFrameLevel(inputLevel)
        end
        if row.scanBtn then
            row.scanBtn:SetFrameLevel(inputLevel)
        end
        if row.deleteBtn then
            row.deleteBtn:SetFrameLevel(inputLevel)
        end
    else
        row.hotspot:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.hotspot:SetPoint("BOTTOMRIGHT", row.qtyBox, "BOTTOMLEFT", -4, 0)
        if row.qtyBox then
            row.qtyBox:SetFrameLevel(row:GetFrameLevel() + 1)
        end
    end
end

local function EnsureVisibleRows(frame, needed)
    frame.rows = frame.rows or {}
    local current = #frame.rows
    if current >= needed then
        return
    end

    for index = current + 1, needed do
        local row = CreateRow(frame.content, index)
        if index == 1 then
            row:SetPoint("TOPLEFT", 0, 0)
            row:SetPoint("TOPRIGHT", 0, 0)
        else
            row:SetPoint("TOPLEFT", frame.rows[index - 1], "BOTTOMLEFT", 0, -ROW_GAP)
            row:SetPoint("TOPRIGHT", frame.rows[index - 1], "BOTTOMRIGHT", 0, -ROW_GAP)
        end
        frame.rows[index] = row
    end
end

function S:CreateWindow()
    if self.frame then
        return self.frame
    end

    local parent = AuctionHouseFrame or UIParent

    local f = CreateFrame("Frame", "HironCraftProfitShoppingListTab", parent)
    f:SetAllPoints(parent)
    f:Hide()
    f:SetScript("OnShow", function()
        if S.searchResults and not S.searchResults.active and f.searchBox then
            S:ClearSearchText(true)
        end
        RefreshSearchClearButton(f)
        S:RefreshWindow()
        if f.ApplyShopTab then
            f.ApplyShopTab(S.shopTab or "buy")
        else
            if S.ApplyShoppingBinding then S:ApplyShoppingBinding() end
            if S.UpdateBindingValueText then S:UpdateBindingValueText() end
        end
    end)
    f:SetScript("OnHide", function()
        HideSearchOptionsPanel()
        S:ClearSearchText(true)
        if S.StopScanAll then S:StopScanAll() end
        if S.StopBuyAll then S:StopBuyAll() end
        if S.ClearShoppingTemporaryBinding then S:ClearShoppingTemporaryBinding() end
        if S.ClearSellTemporaryBinding then S:ClearSellTemporaryBinding() end
    end)

    f.panel = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.panel:SetPoint("TOPLEFT", 10, -50)
    f.panel:SetPoint("BOTTOMRIGHT", -30, 30)
    ApplyPanelBackground(f.panel)

    f.sellPanel = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.sellPanel:SetPoint("TOPLEFT", f.panel, "TOPLEFT", 0, 0)
    f.sellPanel:SetPoint("BOTTOMRIGHT", f.panel, "BOTTOMRIGHT", 0, 0)
    ApplyPanelBackground(f.sellPanel)
    f.sellPanel:Hide()
    f.sellPlaceholder = MakeText(f.sellPanel, 13, "CENTER")
    f.sellPlaceholder:SetPoint("CENTER", 0, 0)
    f.sellPlaceholder:SetText(T("PG_SHOP_SELL_PLACEHOLDER", "Auction posting — coming soon."))

    f.cancelPanel = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.cancelPanel:SetPoint("TOPLEFT", f.panel, "TOPLEFT", 0, 0)
    f.cancelPanel:SetPoint("BOTTOMRIGHT", f.panel, "BOTTOMRIGHT", 0, 0)
    ApplyPanelBackground(f.cancelPanel)
    f.cancelPanel:Hide()
    f.cancelPlaceholder = MakeText(f.cancelPanel, 13, "CENTER")
    f.cancelPlaceholder:SetPoint("CENTER", 0, 0)
    f.cancelPlaceholder:SetText(T("PG_SHOP_CANCEL_PLACEHOLDER", "Auction cancelling — coming soon."))

    local function ApplyShopTab(tab)
        if tab ~= "sell" and tab ~= "cancel" then tab = "buy" end
        S.shopTab = tab
        f.panel:SetShown(tab == "buy")
        if f.sellPanel then f.sellPanel:SetShown(tab == "sell") end
        if f.cancelPanel then f.cancelPanel:SetShown(tab == "cancel") end
        if IsFantasy() and f.Tabs then
            local idx = (tab == "buy" and 1) or (tab == "sell" and 2) or 3
            if PanelTemplates_SetTab then pcall(PanelTemplates_SetTab, f, idx) end
            for _, tb in ipairs(f.Tabs) do
                SetTabHeightForced(tb, SHOP_FTAB_H)
            end
            if f.LayoutShopTabs then f.LayoutShopTabs() end
        else
            SetSidebarTabVisual(f.buyTab, tab == "buy")
            SetSidebarTabVisual(f.sellTab, tab == "sell")
            SetSidebarTabVisual(f.cancelTab, tab == "cancel")
        end
        if f.sellExclusionsBtn then f.sellExclusionsBtn:SetShown(tab == "sell") end
        if f:IsShown() then
            if tab == "buy" then
                if S.ClearSellTemporaryBinding then S:ClearSellTemporaryBinding() end
                if S.ApplyShoppingBinding then S:ApplyShoppingBinding() end
                if S.UpdateBindingValueText then S:UpdateBindingValueText() end
            elseif tab == "sell" then
                if S.ClearShoppingTemporaryBinding then S:ClearShoppingTemporaryBinding() end
                if S.ApplySellBinding then S:ApplySellBinding() end
                if S.UpdateSellBindText then S:UpdateSellBindText() end
            else
                if S.ClearShoppingTemporaryBinding then S:ClearShoppingTemporaryBinding() end
                if S.ClearSellTemporaryBinding then S:ClearSellTemporaryBinding() end
            end
        end
        if tab == "sell" and S.RefreshSellList then
            S:RefreshSellList()
        end
        if tab == "cancel" and S.QueryOwnedAuctions then
            if S.cancel then S.cancel.wantScan = true end
            S:QueryOwnedAuctions()
        end
    end
    f.ApplyShopTab = ApplyShopTab

    f.tabStrip = CreateFrame("Frame", nil, f)
    f.tabStrip:SetPoint("TOPRIGHT", f.panel, "BOTTOMRIGHT", -10, 1)
    f.tabStrip:SetSize(100 * 3 + 4, SIDEBAR_TAB_H)
    f.tabStrip:SetFrameLevel(math.max(0, f.panel:GetFrameLevel() - 1))

    if IsFantasy() then
        f.buyTab = CreateFrame("Button", "HironCraftProfitShopTabBuy", f.tabStrip, "AuctionHouseFrameDisplayModeTabTemplate")
        f.buyTab:SetText(T("PG_SHOP_MAINTAB_BUY", "Buy"))
        f.buyTab:SetScript("OnClick", function() ApplyShopTab("buy") end)

        f.sellTab = CreateFrame("Button", "HironCraftProfitShopTabSell", f.tabStrip, "AuctionHouseFrameDisplayModeTabTemplate")
        f.sellTab:SetText(T("PG_SHOP_MAINTAB_SELL", "Sell"))
        f.sellTab:SetScript("OnClick", function() ApplyShopTab("sell") end)

        f.cancelTab = CreateFrame("Button", "HironCraftProfitShopTabCancel", f.tabStrip, "AuctionHouseFrameDisplayModeTabTemplate")
        f.cancelTab:SetText(T("PG_SHOP_MAINTAB_CANCEL", "Cancel"))
        f.cancelTab:SetScript("OnClick", function() ApplyShopTab("cancel") end)

        for _, tb in ipairs({ f.buyTab, f.sellTab, f.cancelTab }) do
            if PanelTemplates_TabResize then
                PanelTemplates_TabResize(tb, 20, nil, 70)
            end
            SetTabHeightForced(tb, SHOP_FTAB_H)
        end

        f.LayoutShopTabs = function()
            local bw = f.buyTab:GetWidth() or 90
            local sw = f.sellTab:GetWidth() or 90
            f.buyTab:ClearAllPoints()
            f.buyTab:SetPoint("TOPLEFT", f.tabStrip, "TOPLEFT", 0, 0)
            f.sellTab:ClearAllPoints()
            f.sellTab:SetPoint("TOPLEFT", f.tabStrip, "TOPLEFT", bw + SHOP_FTAB_GAP, 0)
            f.cancelTab:ClearAllPoints()
            f.cancelTab:SetPoint("TOPLEFT", f.tabStrip, "TOPLEFT", bw + sw + SHOP_FTAB_GAP * 2, 0)
        end
        f.LayoutShopTabs()

        f.Tabs = { f.buyTab, f.sellTab, f.cancelTab }
        f.buyTab:SetID(1)
        f.sellTab:SetID(2)
        f.cancelTab:SetID(3)
        if PanelTemplates_SetNumTabs then PanelTemplates_SetNumTabs(f, 3) end
    else
        f.buyTab = CreateSidebarTab(f.tabStrip, T("PG_SHOP_MAINTAB_BUY", "Buy"), 100)
        f.buyTab:SetPoint("BOTTOMLEFT", f.tabStrip, "BOTTOMLEFT", 0, 0)
        f.buyTab:SetScript("OnClick", function() ApplyShopTab("buy") end)

        f.sellTab = CreateSidebarTab(f.tabStrip, T("PG_SHOP_MAINTAB_SELL", "Sell"), 100)
        f.sellTab:SetPoint("LEFT", f.buyTab, "RIGHT", 2, 0)
        f.sellTab:SetScript("OnClick", function() ApplyShopTab("sell") end)

        f.cancelTab = CreateSidebarTab(f.tabStrip, T("PG_SHOP_MAINTAB_CANCEL", "Cancel"), 100)
        f.cancelTab:SetPoint("LEFT", f.sellTab, "RIGHT", 2, 0)
        f.cancelTab:SetScript("OnClick", function() ApplyShopTab("cancel") end)

        for _, tab in ipairs({ f.buyTab, f.sellTab, f.cancelTab }) do
            if tab.bottomCover then
                tab.bottomCover:ClearAllPoints()
                tab.bottomCover:SetPoint("TOPLEFT", 1, 1)
                tab.bottomCover:SetPoint("TOPRIGHT", -1, 1)
            end
            if tab.label then
                tab.label:ClearAllPoints()
                tab.label:SetPoint("CENTER", 0, -1)
            end
        end
    end

    if IsFantasy() then
        f.priceScanButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.priceScanButton:SetSize(86, SIDEBAR_TAB_H)
        if f.tabStrip then
            f.priceScanButton:SetPoint("BOTTOMRIGHT", f.tabStrip, "BOTTOMLEFT", -8, 0)
            f.priceScanButton:SetFrameLevel(f.tabStrip:GetFrameLevel())
        else
            f.priceScanButton:SetPoint("TOPRIGHT", f.panel, "BOTTOMRIGHT", -10, 1)
            f.priceScanButton:SetFrameLevel(f.panel:GetFrameLevel() + 10)
        end
        f.priceScanButton:SetText(T("PG_SHOP_PRICESCAN_SHORT", "SCAN"))

        local dot = f.priceScanButton:CreateTexture(nil, "OVERLAY")
        dot:SetSize(10, 10)
        dot:SetPoint("TOPRIGHT", f.priceScanButton, "TOPRIGHT", -2, -2)
        dot:SetTexture("Interface\\COMMON\\Indicator-Yellow")
        dot:Hide()
        f.priceScanButton.dot = dot

        local dotAnim = dot:CreateAnimationGroup()
        dotAnim:SetLooping("BOUNCE")
        local dotFade = dotAnim:CreateAnimation("Alpha")
        dotFade:SetFromAlpha(1)
        dotFade:SetToAlpha(0.1)
        dotFade:SetDuration(0.55)
        dotFade:SetSmoothing("IN_OUT")

        local STALE_AGE = 86400
        local function tint(r, g, b)
            for _, tex in ipairs({ f.priceScanButton:GetNormalTexture(), f.priceScanButton:GetPushedTexture(), f.priceScanButton:GetDisabledTexture() }) do
                if tex then tex:SetVertexColor(r, g, b) end
            end
        end

        local function ApplyScanLabel()
            local P = HironCraftProfit and HironCraftProfit.Prices
            local short = T("PG_SHOP_PRICESCAN_SHORT", "SCAN")
            local scanning, pct
            if P and P.GetScanProgress then scanning, pct = P:GetScanProgress() end
            local stale = false
            if not scanning then
                local last = (P and P.GetLastScan) and P:GetLastScan() or nil
                stale = not (last and last > 0 and (time() - last) < STALE_AGE)
            end
            if stale then
                tint(0.45, 0.62, 1)
            else
                tint(1, 0.45, 0.45)
            end
            if stale and not scanning then
                dot:Show()
                if not dotAnim:IsPlaying() then dotAnim:Play() end
            else
                if dotAnim:IsPlaying() then dotAnim:Stop() end
                dot:Hide()
            end
            f.priceScanButton:SetText(scanning and string.format("%s %d%%", short, pct or 0) or short)
        end
        ApplyScanLabel()

        f.priceScanButton:SetScript("OnUpdate", function(self, elapsed)
            self._acc = (self._acc or 0) + elapsed
            if self._acc >= 0.5 then
                self._acc = 0
                ApplyScanLabel()
            end
        end)

        f.priceScanButton:SetScript("OnClick", function()
            local P = HironCraftProfit and HironCraftProfit.Prices
            if not (P and P.StartFullScan) then return end
            local ok, reason = P:StartFullScan()
            if not ok then
                local map = {
                    ah_closed = "открой окно аукциона",
                    throttle  = "подожди перед повторным сканом",
                    scanning  = "скан уже идёт",
                    no_ah     = "API аукциона недоступно",
                }
                DEFAULT_CHAT_FRAME:AddMessage("|cffb19cd9HironCraft|r скан цен: " .. (map[reason] or tostring(reason)))
            end
            ApplyScanLabel()
        end)

        f.priceScanButton:SetScript("OnEnter", function(self)
            local TT = PT and PT.Tooltip
            if not TT then return end
            TT:Clear()
            TT:AddLine(T("PG_SHOP_PRICESCAN", "HironCraft price scan"), 13, 1, 1, 1)
            TT:AddLine(T("PG_SHOP_PRICESCAN_TOOLTIP", "Full auction house scan into the HironCraft price database."), 11, 0.8, 0.8, 0.8)
            local P = HironCraftProfit and HironCraftProfit.Prices
            if P and P.GetScanInfo then
                local last, n = P:GetScanInfo()
                local ago = (last and last > 0) and (math.floor((time() - last) / 60) .. T("PG_SHOP_PRICESCAN_MIN_AGO", " min ago")) or T("PG_SHOP_PRICESCAN_NEVER", "never")
                TT:AddLine(" ", 6)
                TT:AddLine(string.format(T("PG_SHOP_PRICESCAN_DBINFO", "%d items in DB \194\183 last scan: %s"), n or 0, ago), 11, 0.7, 0.7, 0.7)
                if not (last and last > 0 and (time() - last) < 86400) then
                    TT:AddLine(T("PG_SHOP_PRICESCAN_STALE", "Scan is over a day old \194\183 rescan recommended."), 11, 1, 0.6, 0.2)
                end
            end
            TT:ShowCursorRightOrBelow()
        end)
        f.priceScanButton:SetScript("OnLeave", function()
            if PT and PT.Tooltip then PT.Tooltip:Clear() end
        end)
    else
    f.priceScanButton = CreateFrame("Button", nil, f, "BackdropTemplate")
    f.priceScanButton:SetSize(86, SIDEBAR_TAB_H)
    if f.tabStrip then
        f.priceScanButton:SetPoint("BOTTOMRIGHT", f.tabStrip, "BOTTOMLEFT", -8, 0)
        f.priceScanButton:SetFrameLevel(f.tabStrip:GetFrameLevel())
    else
        f.priceScanButton:SetPoint("TOPRIGHT", f.panel, "BOTTOMRIGHT", -10, 1)
        f.priceScanButton:SetFrameLevel(f.panel:GetFrameLevel() + 10)
    end
    f.priceScanButton:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    do
        local baseR, baseG, baseB = 0.08, 0.08, 0.10
        f.priceScanButton:SetBackdropColor(baseR, baseG, baseB, 0.92)
        f.priceScanButton:SetBackdropBorderColor(0.69, 0.61, 0.85, 1)

        f.priceScanButton.label = MakeText(f.priceScanButton, 11, "CENTER")
        f.priceScanButton.label:SetPoint("CENTER", 0, 0)
        f.priceScanButton.label:SetTextColor(0.82, 0.74, 0.95)
        f.priceScanButton.label:SetText(T("PG_SHOP_PRICESCAN_SHORT", "SCAN"))

        local STALE_AGE = 86400

        local function ApplyScanLabel()
            local P = HironCraftProfit and HironCraftProfit.Prices
            local short = T("PG_SHOP_PRICESCAN_SHORT", "SCAN")

            local scanning, pct
            if P and P.GetScanProgress then scanning, pct = P:GetScanProgress() end

            local stale = false
            if not scanning then
                local last = (P and P.GetLastScan) and P:GetLastScan() or nil
                stale = not (last and last > 0 and (time() - last) < STALE_AGE)
            end

            f.priceScanButton._stale = stale
            f.priceScanButton._scanning = scanning
            if stale then
                f.priceScanButton.label:SetTextColor(1, 0.75, 0.35)
            else
                f.priceScanButton:SetBackdropBorderColor(0.69, 0.61, 0.85, 1)
                f.priceScanButton.label:SetTextColor(0.82, 0.74, 0.95)
                f.priceScanButton.label:SetAlpha(1)
            end

            if scanning then
                f.priceScanButton.label:SetText(string.format("%s %d%%", short, pct or 0))
                return
            end
            f.priceScanButton.label:SetText(short)
        end

        f.priceScanButton:SetScript("OnUpdate", function(self, elapsed)
            self._acc = (self._acc or 0) + elapsed
            if self._acc >= (self._scanning and 0.15 or 1.0) then
                self._acc = 0
                ApplyScanLabel()
            end

            if self._stale then
                self._pulse = (self._pulse or 0) + elapsed
                local t = 0.5 + 0.5 * math.sin(self._pulse * 2.2)
                self:SetBackdropBorderColor(1, 0.55, 0.15, 0.45 + 0.55 * t)
                self.label:SetAlpha(0.75 + 0.25 * t)
            end
        end)

        f.priceScanButton:SetScript("OnClick", function()
            local P = HironCraftProfit and HironCraftProfit.Prices
            if not (P and P.StartFullScan) then return end
            local ok, reason = P:StartFullScan()
            if not ok then
                local map = {
                    ah_closed = "открой окно аукциона",
                    throttle  = "подожди перед повторным сканом",
                    scanning  = "скан уже идёт",
                    no_ah     = "API аукциона недоступно",
                }
                DEFAULT_CHAT_FRAME:AddMessage("|cffb19cd9HironCraft|r скан цен: " .. (map[reason] or tostring(reason)))
            end
            ApplyScanLabel()
        end)

        f.priceScanButton:SetScript("OnEnter", function(self)
            self:SetBackdropColor(baseR + 0.05, baseG + 0.05, baseB + 0.05, 0.92)
            local TT = PT and PT.Tooltip
            if not TT then return end
            TT:Clear()
            TT:AddLine(T("PG_SHOP_PRICESCAN", "HironCraft price scan"), 13, 1, 1, 1)
            TT:AddLine(T("PG_SHOP_PRICESCAN_TOOLTIP", "Full auction house scan into the HironCraft price database."), 11, 0.8, 0.8, 0.8)
            local P = HironCraftProfit and HironCraftProfit.Prices
            if P and P.GetScanInfo then
                local last, n = P:GetScanInfo()
                local ago = (last and last > 0) and (math.floor((time() - last) / 60) .. T("PG_SHOP_PRICESCAN_MIN_AGO", " min ago")) or T("PG_SHOP_PRICESCAN_NEVER", "never")
                TT:AddLine(" ", 6)
                TT:AddLine(string.format(T("PG_SHOP_PRICESCAN_DBINFO", "%d items in DB \194\183 last scan: %s"), n or 0, ago), 11, 0.7, 0.7, 0.7)
                if not (last and last > 0 and (time() - last) < 86400) then
                    TT:AddLine(T("PG_SHOP_PRICESCAN_STALE", "Scan is over a day old \194\183 rescan recommended."), 11, 1, 0.6, 0.2)
                end
            end
            TT:ShowCursorRightOrBelow()
        end)
        f.priceScanButton:SetScript("OnLeave", function(self)
            self:SetBackdropColor(baseR, baseG, baseB, 0.92)
            if PT and PT.Tooltip then PT.Tooltip:Clear() end
        end)
        f.priceScanButton:HookScript("OnMouseDown", function(self)
            self:SetBackdropColor(baseR * 0.4, baseG * 0.4, baseB * 0.4, 0.95)
        end)
        f.priceScanButton:HookScript("OnMouseUp", function(self)
            self:SetBackdropColor(baseR, baseG, baseB, 0.92)
        end)
    end
    end

    if IsFantasy() then
        f.sellExclusionsBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.sellExclusionsBtn:SetSize(120, 22)
        f.sellExclusionsBtn:SetPoint("BOTTOMRIGHT", f.panel, "TOPRIGHT", -6, 1)
        f.sellExclusionsBtn:SetFrameLevel(f.panel:GetFrameLevel() + 10)
        f.sellExclusionsBtn:SetText(T("PG_SELL_EXCLUSIONS_BTN", "Exclusions"))
        f.sellExclusionsBtn:SetScript("OnClick", function()
            if S.ShowSellExclusionsEditor then S:ShowSellExclusionsEditor() end
        end)
        f.sellExclusionsBtn:Hide()
    else
        f.sellExclusionsBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
        f.sellExclusionsBtn:SetSize(120, 22)
        f.sellExclusionsBtn:SetPoint("BOTTOMRIGHT", f.panel, "TOPRIGHT", -6, 1)
        f.sellExclusionsBtn:SetFrameLevel(f.panel:GetFrameLevel() + 10)
        f.sellExclusionsBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        f.sellExclusionsBtn:SetBackdropColor(0.06, 0.06, 0.09, 0.9)
        f.sellExclusionsBtn:SetBackdropBorderColor(0.85, 0.55, 0.25, 0.8)
        f.sellExclusionsBtn.label = MakeText(f.sellExclusionsBtn, 11, "CENTER")
        f.sellExclusionsBtn.label:SetPoint("CENTER")
        f.sellExclusionsBtn.label:SetText(T("PG_SELL_EXCLUSIONS_BTN", "Exclusions"))
        f.sellExclusionsBtn.label:SetTextColor(0.95, 0.8, 0.55)
        f.sellExclusionsBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(0.12, 0.10, 0.08, 0.92) end)
        f.sellExclusionsBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(0.06, 0.06, 0.09, 0.9) end)
        f.sellExclusionsBtn:SetScript("OnClick", function()
            if S.ShowSellExclusionsEditor then S:ShowSellExclusionsEditor() end
        end)
        f.sellExclusionsBtn:Hide()
    end

    ApplyShopTab("buy")

    local BIND_BTN_W, BIND_BTN_H = 92, 28

    local function MakeBindActionButton(parent, target)
        if IsFantasy() then
            local labelText = T("PG_SHOP_BUY_BIND_SHORT", "BUY")
            if target == "skip" then
                labelText = T("PG_SHOP_SKIP_BIND_SHORT", "SKIP")
            elseif target == "refresh" then
                labelText = T("PG_SHOP_REFRESH_BIND_SHORT", "PRICES")
            end

            local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
            btn:SetSize(BIND_BTN_W, BIND_BTN_H)
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

            btn:SetText(labelText)
            btn.value = { SetText = function() end }

            local function CurrentKeyText()
                local binding
                if target == "skip" then
                    binding = S.GetShoppingSkipBinding and S:GetShoppingSkipBinding() or nil
                elseif target == "refresh" then
                    binding = S.GetShoppingRefreshBinding and S:GetShoppingRefreshBinding() or nil
                else
                    binding = S.GetShoppingBinding and S:GetShoppingBinding() or nil
                end
                if binding and binding ~= "" and _G.GetBindingText then
                    return _G.GetBindingText(binding, "KEY_")
                end
                return T("PG_SHOP_BIND_NONE", "—")
            end

            btn:SetScript("OnClick", function(self, mouseButton)
                if mouseButton == "RightButton" then
                    if IsShiftKeyDown and IsShiftKeyDown() then
                        if target == "skip" then
                            if S.ClearShoppingSkipBinding then S:ClearShoppingSkipBinding() end
                        elseif target == "refresh" then
                            if S.ClearShoppingRefreshBinding then S:ClearShoppingRefreshBinding() end
                        else
                            if S.ClearShoppingBinding then S:ClearShoppingBinding() end
                        end
                        if S.UpdateBindingValueText then S:UpdateBindingValueText() end
                        return
                    end
                    if S.CreateBindCapture then S:CreateBindCapture(target) end
                    if S.bindCapture then S.bindCapture:Show() end
                    return
                end

                if target == "skip" then
                    if S.RunHotkeySkipAction then S:RunHotkeySkipAction() end
                elseif target == "refresh" then
                    if S.RunHotkeyRefreshAction then S:RunHotkeyRefreshAction() end
                else
                    if S.RunHotkeyAction then S:RunHotkeyAction() end
                end
            end)

            btn:SetScript("OnEnter", function(self)
                local TT = PT and PT.Tooltip
                if not TT then return end
                TT:Clear()
                if target == "skip" then
                    TT:AddLine(T("PG_SHOP_SKIP_BIND_TT_TITLE", "Skip next item"), 13, 1, 1, 1)
                    TT:AddLine(T("PG_SHOP_SKIP_BIND_TT_DESC", "Skips the highlighted item without buying."), 11, 0.8, 0.8, 0.8)
                elseif target == "refresh" then
                    TT:AddLine(T("PG_SHOP_REFRESH_PRICES", "Refresh prices"), 13, 1, 1, 1)
                    TT:AddLine(T("PG_SHOP_REFRESH_PRICES_TOOLTIP", "Re-scan Auctionator prices for the list."), 11, 0.8, 0.8, 0.8)
                else
                    TT:AddLine(T("PG_SHOP_BUY_BIND_TT_TITLE", "Buy next item"), 13, 1, 1, 1)
                    TT:AddLine(T("PG_SHOP_BUY_BIND_TT_DESC", "Buys the highlighted item."), 11, 0.8, 0.8, 0.8)
                end
                TT:AddLine(" ", 6)
                TT:AddLine(string.format(T("PG_SHOP_BIND_TT_CURRENT", "Assigned key: %s"), CurrentKeyText()), 11, 0.98, 0.86, 0.42)
                TT:AddLine(" ", 6)
                TT:AddLine(T("PG_SHOP_BIND_TT_HINT_LMB", "Left click — perform action."), 11, 0.7, 0.7, 0.7)
                TT:AddLine(T("PG_SHOP_BIND_TT_HINT_RMB", "Right click — assign key."), 11, 0.7, 0.7, 0.7)
                TT:AddLine(T("PG_SHOP_BIND_TT_HINT_SHIFT_RMB", "Shift + right click — clear key."), 11, 0.7, 0.7, 0.7)
                TT:ShowCursorRightOrBelow()
            end)
            btn:SetScript("OnLeave", function()
                if PT and PT.Tooltip then PT.Tooltip:Clear() end
            end)

            return btn
        end

        local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
        btn:SetSize(BIND_BTN_W, BIND_BTN_H)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })

        local baseR, baseG, baseB = 0.08, 0.08, 0.10
        local borderR, borderG, borderB
        if target == "skip" then
            borderR, borderG, borderB = 0.85, 0.55, 0.25
        elseif target == "refresh" then
            borderR, borderG, borderB = 0.35, 0.55, 0.85
        else
            borderR, borderG, borderB = 0.30, 0.75, 0.40
        end

        btn:SetBackdropColor(baseR, baseG, baseB, 0.92)
        btn:SetBackdropBorderColor(borderR, borderG, borderB, 1)

        btn.label = MakeText(btn, 11, "CENTER")
        btn.label:SetPoint("TOP", 0, -3)
        btn.label:SetTextColor(0.75, 0.75, 0.75)
        local labelText = T("PG_SHOP_BUY_BIND_SHORT", "BUY")
        if target == "skip" then
            labelText = T("PG_SHOP_SKIP_BIND_SHORT", "SKIP")
        elseif target == "refresh" then
            labelText = T("PG_SHOP_REFRESH_BIND_SHORT", "PRICES")
        end
        btn.label:SetText(labelText)

        btn.value = MakeText(btn, 12, "CENTER")
        btn.value:SetPoint("BOTTOM", 0, 4)
        btn.value:SetTextColor(0.98, 0.86, 0.42)

        if target == "refresh" then
            btn.icon = btn:CreateTexture(nil, "ARTWORK")
            btn.icon:SetSize(18, 18)
            btn.icon:SetPoint("LEFT", 4, 0)
            btn.icon:SetAtlas("uitools-icon-refresh")
        end

        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(baseR + 0.05, baseG + 0.05, baseB + 0.05, 0.92)
            local TT = PT and PT.Tooltip
            if not TT then return end
            TT:Clear()
            if target == "skip" then
                TT:AddLine(T("PG_SHOP_SKIP_BIND_TT_TITLE", "Skip next item"), 13, 1, 1, 1)
                TT:AddLine(T("PG_SHOP_SKIP_BIND_TT_DESC", "Skips the highlighted item without buying."), 11, 0.8, 0.8, 0.8)
            elseif target == "refresh" then
                TT:AddLine(T("PG_SHOP_REFRESH_PRICES", "Refresh prices"), 13, 1, 1, 1)
                TT:AddLine(T("PG_SHOP_REFRESH_PRICES_TOOLTIP", "Re-scan Auctionator prices for the list."), 11, 0.8, 0.8, 0.8)
            else
                TT:AddLine(T("PG_SHOP_BUY_BIND_TT_TITLE", "Buy next item"), 13, 1, 1, 1)
                TT:AddLine(T("PG_SHOP_BUY_BIND_TT_DESC", "Buys the highlighted item."), 11, 0.8, 0.8, 0.8)
            end
            TT:AddLine(" ", 6)
            TT:AddLine(T("PG_SHOP_BIND_TT_HINT_LMB", "Left click — perform action."), 11, 0.7, 0.7, 0.7)
            TT:AddLine(T("PG_SHOP_BIND_TT_HINT_RMB", "Right click — assign key."), 11, 0.7, 0.7, 0.7)
            TT:AddLine(T("PG_SHOP_BIND_TT_HINT_SHIFT_RMB", "Shift + right click — clear key."), 11, 0.7, 0.7, 0.7)
            TT:ShowCursorRightOrBelow()
        end)

        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(baseR, baseG, baseB, 0.92)
            if PT and PT.Tooltip then PT.Tooltip:Clear() end
        end)

        btn:SetScript("OnClick", function(self, mouseButton)
            if mouseButton == "RightButton" then
                if IsShiftKeyDown and IsShiftKeyDown() then
                    if target == "skip" then
                        if S.ClearShoppingSkipBinding then S:ClearShoppingSkipBinding() end
                    elseif target == "refresh" then
                        if S.ClearShoppingRefreshBinding then S:ClearShoppingRefreshBinding() end
                    else
                        if S.ClearShoppingBinding then S:ClearShoppingBinding() end
                    end
                    if S.UpdateBindingValueText then S:UpdateBindingValueText() end
                    return
                end
                if S.CreateBindCapture then S:CreateBindCapture(target) end
                if S.bindCapture then S.bindCapture:Show() end
                return
            end

            if target == "skip" then
                if S.RunHotkeySkipAction then S:RunHotkeySkipAction() end
            elseif target == "refresh" then
                if S.RunHotkeyRefreshAction then S:RunHotkeyRefreshAction() end
            else
                if S.RunHotkeyAction then S:RunHotkeyAction() end
            end
        end)

        btn:HookScript("OnMouseDown", function(self)
            self:SetBackdropColor(baseR * 0.4, baseG * 0.4, baseB * 0.4, 0.95)
            if self.label then self.label:SetPoint("TOP", 0, -4) end
        end)
        btn:HookScript("OnMouseUp", function(self)
            self:SetBackdropColor(baseR, baseG, baseB, 0.92)
            if self.label then self.label:SetPoint("TOP", 0, -3) end
        end)

        return btn
    end

    local function MakeInterceptToggle(parent)
        if IsFantasy() then
            local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
            cb:SetSize(24, 24)

            cb.label = MakeText(cb, 11, "RIGHT")
            cb.label:SetPoint("RIGHT", cb, "LEFT", -2, 0)
            cb.label:SetText(T("PG_SHOP_CRAFTSIM_INTERCEPT_SHORT", "Intercept"))

            local function GetVal()
                if S.IsCraftSimInterceptEnabled then
                    return S:IsCraftSimInterceptEnabled()
                end
                return PT.config and PT.config.shoppingListInterceptCraftSim == true
            end
            local function SetVal(value)
                if S.SetCraftSimInterceptEnabled then
                    S:SetCraftSimInterceptEnabled(value)
                else
                    PT.config = PT.config or {}
                    PT.config.shoppingListInterceptCraftSim = value == true
                end
            end

            function cb:Refresh()
                local on = GetVal()
                self:SetChecked(on and true or false)
                if on then
                    self.label:SetTextColor(0.95, 0.9, 1)
                else
                    self.label:SetTextColor(0.7, 0.7, 0.75)
                end
            end

            cb:SetScript("OnClick", function(self)
                SetVal(self:GetChecked() and true or false)
                self:Refresh()
            end)

            cb:SetScript("OnEnter", function(self)
                local TT = PT and PT.Tooltip
                if not TT then return end
                TT:Clear()
                TT:AddLine(T("PG_SHOP_CRAFTSIM_INTERCEPT", "CraftSim intercept"), 13, 1, 1, 1)
                TT:AddLine(T("PG_SHOP_CRAFTSIM_INTERCEPT_TOOLTIP", "Intercept CraftSim Auctionator shopping lists into HironCraftProfitshop."), 11, 0.8, 0.8, 0.8)
                TT:ShowCursorRightOrBelow()
            end)
            cb:SetScript("OnLeave", function()
                if PT and PT.Tooltip then PT.Tooltip:Clear() end
            end)

            cb:Refresh()
            return cb
        end

        local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
        btn:SetSize(BIND_BTN_W, BIND_BTN_H)
        btn:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })

        local baseR, baseG, baseB = 0.08, 0.08, 0.10
        btn:SetBackdropColor(baseR, baseG, baseB, 0.92)

        btn.box = btn:CreateTexture(nil, "BACKGROUND")
        btn.box:SetSize(14, 14)
        btn.box:SetPoint("LEFT", 8, 0)
        btn.box:SetColorTexture(0.16, 0.16, 0.20, 1)

        btn.check = btn:CreateTexture(nil, "ARTWORK")
        btn.check:SetSize(18, 18)
        btn.check:SetPoint("CENTER", btn.box, "CENTER", 0, 0)
        if btn.check.SetAtlas then
            btn.check:SetAtlas("common-icon-checkmark")
        end
        btn.check:Hide()

        btn.label = MakeText(btn, 10, "LEFT")
        btn.label:SetPoint("LEFT", btn.box, "RIGHT", 5, 0)
        btn.label:SetPoint("RIGHT", -4, 0)
        btn.label:SetText(T("PG_SHOP_CRAFTSIM_INTERCEPT_SHORT", "Intercept"))

        local function GetVal()
            if S.IsCraftSimInterceptEnabled then
                return S:IsCraftSimInterceptEnabled()
            end
            return PT.config and PT.config.shoppingListInterceptCraftSim == true
        end
        local function SetVal(value)
            if S.SetCraftSimInterceptEnabled then
                S:SetCraftSimInterceptEnabled(value)
            else
                PT.config = PT.config or {}
                PT.config.shoppingListInterceptCraftSim = value == true
            end
        end

        function btn:Refresh()
            local on = GetVal()
            self.check:SetShown(on and true or false)
            if on then
                self:SetBackdropBorderColor(0.72, 0.58, 0.98, 1)
                self.label:SetTextColor(0.95, 0.9, 1)
            else
                self:SetBackdropBorderColor(0.4, 0.35, 0.5, 1)
                self.label:SetTextColor(0.7, 0.7, 0.75)
            end
        end

        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(baseR + 0.05, baseG + 0.05, baseB + 0.05, 0.92)
            local TT = PT and PT.Tooltip
            if not TT then return end
            TT:Clear()
            TT:AddLine(T("PG_SHOP_CRAFTSIM_INTERCEPT", "CraftSim intercept"), 13, 1, 1, 1)
            TT:AddLine(T("PG_SHOP_CRAFTSIM_INTERCEPT_TOOLTIP", "Intercept CraftSim Auctionator shopping lists into HironCraftProfitshop."), 11, 0.8, 0.8, 0.8)
            TT:ShowCursorRightOrBelow()
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(baseR, baseG, baseB, 0.92)
            if PT and PT.Tooltip then PT.Tooltip:Clear() end
        end)
        btn:SetScript("OnClick", function(self)
            SetVal(not GetVal())
            self:Refresh()
        end)
        btn:HookScript("OnMouseDown", function(self)
            self:SetBackdropColor(baseR * 0.4, baseG * 0.4, baseB * 0.4, 0.95)
        end)
        btn:HookScript("OnMouseUp", function(self)
            self:SetBackdropColor(baseR, baseG, baseB, 0.92)
        end)

        btn:Refresh()
        return btn
    end

    f.bindBar = CreateFrame("Frame", nil, f.panel)
    f.bindBar:SetPoint("BOTTOMRIGHT", f.panel, "BOTTOMRIGHT", -PANEL_PAD, 6)
    f.bindBar:SetSize(BIND_BTN_W * 3 + 12, BIND_BTN_H)
    f.bindBar:SetFrameLevel(f.panel:GetFrameLevel() + 5)

    f.skipBindAction = MakeBindActionButton(f.bindBar, "skip")
    f.skipBindAction:SetPoint("RIGHT", f.bindBar, "RIGHT", 0, 0)

    f.bindAction = MakeBindActionButton(f.bindBar, "buy")
    f.bindAction:SetPoint("RIGHT", f.skipBindAction, "LEFT", -4, 0)

    f.refreshAction = MakeBindActionButton(f.bindBar, "refresh")
    f.refreshAction:SetPoint("RIGHT", f.bindAction, "LEFT", -4, 0)

    f.bindValue = f.bindAction.value
    f.skipBindValue = f.skipBindAction.value
    f.refreshBindValue = f.refreshAction.value

    f.searchLabel = MakeText(f.panel, 10, "LEFT")
    f.searchLabel:SetPoint("TOPLEFT", PANEL_PAD, -12)
    f.searchLabel:SetText(T("PG_SHOP_SEARCH", "Search"))

    f.searchBox = CreateFrame("EditBox", nil, f.panel, "InputBoxTemplate")
    f.searchBox:SetAutoFocus(false)
    f.searchBox:SetFont(FONT, 11, "")
    f.searchBox:SetHeight(22)
    f.searchBox:EnableMouse(true)
    f.searchBox:EnableKeyboard(true)
    if f.searchBox.SetTextInsets then
        f.searchBox:SetTextInsets(0, 18, 0, 0)
    end

    f.searchClearButton = CreateIconButton(f.searchBox, "common-icon-redx", T("PG_SHOP_CLEAR_SEARCH", "Clear search"), T("PG_SHOP_CLEAR_SEARCH_TOOLTIP", "Clear the search field."), 16, 12)
    f.searchClearButton:SetPoint("RIGHT", f.searchBox, "RIGHT", -2, 0)
    f.searchClearButton:SetFrameLevel(f.searchBox:GetFrameLevel() + 8)
    f.searchClearButton:SetScript("OnClick", function()
        if S.ClearSearchText then
            S:ClearSearchText(false)
        else
            f.searchBox:SetText("")
            if S.ClearAuctionSearch then
                S:ClearAuctionSearch()
            end
            f.searchBox:ClearFocus()
        end
        RefreshSearchClearButton(f)
    end)
    f.searchClearButton:Hide()

    f.addToListButton = CreateIconButton(f.panel, "communities-chat-icon-plus", T("PG_SHOP_ADD_TO_LIST", "Add to list"), T("PG_SHOP_ADD_TO_LIST_TOOLTIP", "Add selected search result to the shopping list."), 24, 24)
    f.addToListButton:SetPoint("TOPRIGHT", -PANEL_PAD, -6)
    f.addToListButton:SetSize(20, 20)
    if IsFantasy() then
        f.addToListButton:SetSize(FSEARCH_BTN, FSEARCH_BTN)
        SetRedButtonAtlas(f.addToListButton, "128-RedButton-Plus", "128-RedButton-Plus-Pressed", FSEARCH_BTN, "128-RedButton-Plus-Disabled")
    end
    f.addToListButton:SetScript("OnClick", AddSelectedSearchResultToList)
    f.addToListButton:Show()

    f.searchOptionsButton = CreateIconButton(f.panel, "uitools-icon-settings", T("PG_SHOP_SEARCH_OPTIONS", "Search options"), T("PG_SHOP_SEARCH_OPTIONS_TOOLTIP", "Open search parameters."), 30, 20)
    f.searchOptionsButton:SetPoint("RIGHT", f.addToListButton, "LEFT", -SEARCH_BTN_GAP, 0)
    f.searchOptionsButton:SetSize(20, 20)
    if IsFantasy() then
        f.searchOptionsButton:SetSize(FSEARCH_BTN, FSEARCH_BTN)
        SetIconButtonTexture(f.searchOptionsButton, "Interface\\AddOns\\HironCraft\\ProfitHub\\Shop\\media\\settings", "Interface\\AddOns\\HironCraft\\ProfitHub\\Shop\\media\\settings-pressed", FSEARCH_BTN)
    end
    f.searchOptionsButton:SetScript("OnClick", function(self)
        ToggleSearchOptionsPanel(self)
    end)
    f.searchOptionsButton:Show()

    f.searchButton = CreateIconButton(f.panel, "talents-search-exactmatch", T("PG_SHOP_SEARCH", "Search"), T("PG_SHOP_SEARCH_TOOLTIP", "Search auction house."), 30, 30)
    f.searchButton:SetPoint("RIGHT", f.searchOptionsButton, "LEFT", -SEARCH_BTN_GAP, 0)
    f.searchButton:SetSize(20, 20)
    if IsFantasy() then
        f.searchButton:SetSize(FSEARCH_BTN, FSEARCH_BTN)
        SetIconButtonTexture(f.searchButton, "Interface\\AddOns\\HironCraft\\ProfitHub\\Shop\\media\\search", "Interface\\AddOns\\HironCraft\\ProfitHub\\Shop\\media\\search-pressed", FSEARCH_BTN)
    end
    f.searchButton:SetScript("OnClick", RunSearchFromBox)
    f.searchButton:Show()

    f.searchBox:SetPoint("LEFT", f.searchLabel, "RIGHT", 10, 0)
    f.searchBox:SetPoint("RIGHT", f.searchButton, "LEFT", -6, 0)
    InstallSearchBoxLinkHandler()

    f.searchBox:SetScript("OnEditFocusGained", function(self)
        S.activeSearchBox = self
        S.lastSearchBox = self
        S.lastSearchBoxUntil = (GetTime and GetTime() or 0) + 10
    end)

    f.searchBox:SetScript("OnEditFocusLost", function(self)
        if S.activeSearchBox == self then
            S.activeSearchBox = nil
        end
        S.lastSearchBox = self
        S.lastSearchBoxUntil = (GetTime and GetTime() or 0) + 10
    end)

    f.searchBox:SetScript("OnTextChanged", function(self)
        if self._ahuiSuppressTextChanged then
            return
        end

        RefreshSearchClearButton(f)

        local text = TrimText(self:GetText())
        if text == "" and S.CanRunEmptyAuctionSearch and not S:CanRunEmptyAuctionSearch() and S.ClearAuctionSearch then
            S:ClearAuctionSearch(true)
        end
    end)

    f.searchBox:SetScript("OnEnterPressed", function(self)
        RunSearchFromBox()
        self:ClearFocus()
    end)
    f.searchBox:SetScript("OnEscapePressed", function(self)
        if S.ClearSearchText then
            S:ClearSearchText(false)
        else
            self:SetText("")
            if S.ClearAuctionSearch then
                S:ClearAuctionSearch()
            end
            self:ClearFocus()
        end
    end)

    f.hint = MakeText(f.panel, 10, "RIGHT")
    f.hint:SetPoint("TOPRIGHT", f.panel, "TOPRIGHT", -PANEL_PAD, -34)
    f.hint:SetWidth(260)
    f.hint:SetText("")

    if IsFantasy() then
        f.stopScanBtn = CreateFrame("Button", nil, f.panel, "UIPanelButtonTemplate")
        f.stopScanBtn:SetSize(90, 22)
        f.stopScanBtn:SetPoint("RIGHT", f.hint, "RIGHT", -85, 0)
        f.stopScanBtn:SetText(T("PG_SHOP_STOPSCAN", "STOP scan"))
        f.stopScanBtn:SetScript("OnClick", function()
            if S.StopScanAll then S:StopScanAll() end
        end)
        f.stopScanBtn:Disable()
    else
        f.stopScanBtn = CreateFrame("Button", nil, f.panel, "BackdropTemplate")
        f.stopScanBtn:SetSize(90, 20)
        f.stopScanBtn:SetPoint("RIGHT", f.hint, "RIGHT", -85, 0)
        f.stopScanBtn:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        f.stopScanBtn:SetBackdropColor(0.35, 0.07, 0.07, 0.92)
        f.stopScanBtn:SetBackdropBorderColor(0.9, 0.35, 0.35, 0.9)
        f.stopScanBtn.label = MakeText(f.stopScanBtn, 11, "CENTER")
        f.stopScanBtn.label:SetPoint("CENTER")
        f.stopScanBtn.label:SetText(T("PG_SHOP_STOPSCAN", "STOP scan"))
        f.stopScanBtn.label:SetTextColor(1, 0.8, 0.8)
        f.stopScanBtn:SetScript("OnClick", function()
            if S.StopScanAll then S:StopScanAll() end
        end)
        f.stopScanBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.48, 0.10, 0.10, 0.95)
        end)
        f.stopScanBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.35, 0.07, 0.07, 0.92)
        end)
        f.stopScanBtn:Hide()
    end

    f.sidebar = CreateFrame("Frame", nil, f.panel, "BackdropTemplate")
    f.sidebar:SetPoint("TOPLEFT", PANEL_PAD, -(TOP_H + 10))
    f.sidebar:SetPoint("BOTTOMLEFT", PANEL_PAD, 36)
    f.sidebar:SetWidth(SIDEBAR_W)
    ApplyInnerBackdrop(f.sidebar, 0.36)

    if IsFantasy() then
        f.listsTab = CreateFrame("Button", "HironCraftProfitShopSideTabLists", f.sidebar, "AuctionHouseFrameDisplayModeTabTemplate")
        f.listsTab:SetText(T("PG_SHOP_TAB_LISTS", "Lists"))
        f.listsTab:SetScript("OnClick", function()
            S.shoppingSidebarMode = "lists"
            if S.RefreshWindow then S:RefreshWindow() end
        end)

        f.historyTab = CreateFrame("Button", "HironCraftProfitShopSideTabHistory", f.sidebar, "AuctionHouseFrameDisplayModeTabTemplate")
        f.historyTab:SetText(T("PG_SHOP_TAB_SEARCH_HISTORY", "History"))
        f.historyTab:SetScript("OnClick", function()
            S.shoppingSidebarMode = "history"
            if S.RefreshWindow then S:RefreshWindow() end
        end)

        for _, tb in ipairs({ f.listsTab, f.historyTab }) do
            if PanelTemplates_TabResize then PanelTemplates_TabResize(tb, 10, nil, 60) end
            SetTabHeightForced(tb, SHOP_FTAB_H)
            PanelTemplates_DeselectTab(tb)
        end

        f.LayoutSideTabs = function()
            local lw = f.listsTab:GetWidth() or 70
            f.listsTab:ClearAllPoints()
            f.listsTab:SetPoint("TOPLEFT", f.sidebar, "TOPLEFT", 8, -2)
            f.historyTab:ClearAllPoints()
            f.historyTab:SetPoint("TOPLEFT", f.sidebar, "TOPLEFT", 8 + lw + SHOP_SIDETAB_GAP, -2)
        end
        f.LayoutSideTabs()
    else
        f.listsTab = CreateSidebarTab(f.sidebar, T("PG_SHOP_TAB_LISTS", "Lists"), SIDEBAR_TAB_W)
        f.listsTab:SetPoint("TOPLEFT", 8, -7)
        f.listsTab:SetScript("OnClick", function()
            S.shoppingSidebarMode = "lists"
            if S.RefreshWindow then S:RefreshWindow() end
        end)

        f.historyTab = CreateSidebarTab(f.sidebar, T("PG_SHOP_TAB_SEARCH_HISTORY", "History"), SIDEBAR_TAB_W)
        f.historyTab:SetPoint("LEFT", f.listsTab, "RIGHT", SIDEBAR_TAB_GAP, 0)
        f.historyTab:SetScript("OnClick", function()
            S.shoppingSidebarMode = "history"
            if S.RefreshWindow then S:RefreshWindow() end
        end)
    end

    f.newList = CreateFrame("Button", nil, f.sidebar, "UIPanelButtonTemplate")
    f.newList:SetSize(46, 20)
    f.newList:SetPoint("TOPLEFT", 8, -36)
    f.newList:SetText(T("PG_SHOP_NEW_LIST_SHORT", "New"))
    f.newList:SetScript("OnClick", function()
        PromptText(
            "HIRONCRAFT_PROFIT_SHOPPING_NEW_LIST",
            T("PG_SHOP_NEW_LIST", "New shopping list"),
            "",
            function(name)
                if S.CreateSavedList then
                    S:CreateSavedList(name)
                elseif S.CreateManualList then
                    S:CreateManualList(name)
                end
            end
        )
    end)

    f.saveList = CreateFrame("Button", nil, f.sidebar, "UIPanelButtonTemplate")
    f.saveList:SetSize(54, 20)
    f.saveList:SetPoint("LEFT", f.newList, "RIGHT", 4, 0)
    f.saveList:SetText(T("PG_SHOP_SAVE_LIST_SHORT", "Save"))
    f.saveList:SetScript("OnClick", function()
        local currentName = S.GetActiveListName and S:GetActiveListName() or T("PG_SHOP_SAVED_LIST_DEFAULT", "Shopping list")
        PromptText(
            "HIRONCRAFT_PROFIT_SHOPPING_SAVE_LIST",
            T("PG_SHOP_SAVE_LIST", "Save shopping list"),
            currentName,
            function(name)
                if name == "" then
                    name = currentName
                end
                if S.activeSavedListID and #(S:GetRows() or {}) == 0 and S.RenameSavedList then
                    S:RenameSavedList(S.activeSavedListID, name)
                elseif S.SaveActiveList then
                    S:SaveActiveList(name)
                end
            end
        )
    end)

    f.deleteList = CreateFrame("Button", nil, f.sidebar, "UIPanelButtonTemplate")
    f.deleteList:SetSize(54, 20)
    f.deleteList:SetPoint("LEFT", f.saveList, "RIGHT", 4, 0)
    f.deleteList:SetText(T("PG_SHOP_DELETE_LIST_SHORT", "Del"))
    f.deleteList:SetScript("OnClick", function()
        if S.activeSavedListID and S.DeleteSavedList then
            S:DeleteSavedList(S.activeSavedListID)
        end
    end)

    f.importList = CreateFrame("Button", nil, f.sidebar, "UIPanelButtonTemplate")
    f.importList:SetSize(76, 20)
    f.importList:SetPoint("TOPLEFT", 8, -60)
    f.importList:SetText(T("PG_SHOP_IMPORT_SHORT", "Import"))
    f.importList:SetScript("OnClick", function()
        ShowImportExportDialog("import")
    end)

    f.exportList = CreateFrame("Button", nil, f.sidebar, "UIPanelButtonTemplate")
    f.exportList:SetSize(76, 20)
    f.exportList:SetPoint("LEFT", f.importList, "RIGHT", 4, 0)
    f.exportList:SetText(T("PG_SHOP_EXPORT_SHORT", "Export"))
    f.exportList:SetScript("OnClick", function()
        ShowImportExportDialog("export")
    end)

    f.clearHistory = CreateFrame("Button", nil, f.sidebar, "UIPanelButtonTemplate")
    f.clearHistory:SetSize(154, 20)
    f.clearHistory:SetPoint("TOPLEFT", 8, -36)
    f.clearHistory:SetText(T("PG_SHOP_CLEAR_HISTORY", "Clear history"))
    f.clearHistory:SetScript("OnClick", function()
        if S.ClearSearchHistory then
            S:ClearSearchHistory()
        end
    end)
    f.clearHistory:Hide()

    f.listScroll = CreateFrame("ScrollFrame", nil, f.sidebar)
    f.listScroll:SetPoint("TOPLEFT", 8, -88)
    f.listScroll:SetPoint("BOTTOMRIGHT", -8, 8)
    f.listScroll:EnableMouseWheel(true)
    f.listScroll:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll() or 0
        local step = 30 * 2
        local child = self:GetScrollChild()
        local maxScroll = math.max(0, (child and child:GetHeight() or 0) - self:GetHeight())
        local target = current - (delta * step)
        if target < 0 then target = 0 end
        if target > maxScroll then target = maxScroll end
        self:SetVerticalScroll(target)
    end)
    f.listContent = CreateFrame("Frame", nil, f.listScroll)
    f.listContent:SetSize(SIDEBAR_W - 16, 1)
    f.listScroll:SetScrollChild(f.listContent)
    f.listButtons = {}

    f.main = CreateFrame("Frame", nil, f.panel, "BackdropTemplate")
    f.main:SetPoint("TOPLEFT", f.sidebar, "TOPRIGHT", 10, 0)
    f.main:SetPoint("BOTTOMRIGHT", -PANEL_PAD, 36)
    ApplyInnerBackdrop(f.main, 0.28)

    f.header = CreateFrame("Frame", nil, f.main, "BackdropTemplate")
    f.header:SetPoint("TOPLEFT", 8, -8)
    f.header:SetPoint("TOPRIGHT", -8, -8)
    f.header:SetHeight(HEADER_H)
    f.header:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    f.header:SetBackdropColor(1, 1, 1, 0.05)

    local function MakeHeader(text, point, relativeTo, relativePoint, x, w, justify)
        local fs = MakeText(f.header, 10, justify or "LEFT")
        fs:SetPoint(point, relativeTo, relativePoint, x, 0)
        fs:SetWidth(w)
        fs:SetText(text)
        return fs
    end

    local hShift = IsFantasy() and FROW_COL_SHIFT or 0
    f.hItem = MakeHeader(T("PG_SHOP_COL_ITEM", "Item"), "LEFT", f.header, "LEFT", 35, 160, "LEFT")
    f.hAction = MakeHeader("", "RIGHT", f.header, "RIGHT", 17, ACTION_W + 20, "RIGHT")
    f.hStatus = MakeHeader(T("PG_SHOP_COL_STATUS", "Status"), "RIGHT", f.header, "RIGHT", -60 - hShift, STATUS_W, "RIGHT")
    f.hAH = MakeHeader(T("PG_SHOP_COL_AH", "On AH"), "RIGHT", f.header, "RIGHT", -132 - hShift, AH_W, "RIGHT")
    f.hPrice = MakeHeader(T("PG_SHOP_COL_PRICE", "Price"), "RIGHT", f.header, "RIGHT", -188 - hShift, PRICE_W, "RIGHT")

    local function UpdateSortHeaders()
        local sort = GetListSort()
        local function withArrow(text, field)
            if sort and sort.field == field then
                return text .. (sort.mode == "asc" and " |cffffd200v|r" or " |cffffd200^|r")
            end
            return text
        end
        f.hItem:SetText(withArrow(T("PG_SHOP_COL_ITEM", "Item"), "name"))
        f.hPrice:SetText(withArrow(T("PG_SHOP_COL_PRICE", "Price"), "price"))
    end

    local function MakeSortClicker(headerFs, field)
        local btn = CreateFrame("Button", nil, f.header)
        btn:SetPoint("TOP", headerFs, "TOP", 0, 2)
        btn:SetPoint("BOTTOM", headerFs, "BOTTOM", 0, -2)
        btn:SetPoint("LEFT", headerFs, "LEFT", -2, 0)
        btn:SetPoint("RIGHT", headerFs, "RIGHT", 2, 0)
        btn:EnableMouse(true)
        btn:SetScript("OnClick", function()
            CycleListSort(field)
            UpdateSortHeaders()
            if S.RefreshWindow then S:RefreshWindow() end
        end)
        btn:SetScript("OnEnter", function() headerFs:SetTextColor(1, 0.95, 0.6, 1) end)
        btn:SetScript("OnLeave", function() headerFs:SetTextColor(1, 1, 1, 1) end)
        return btn
    end

    f.itemSortBtn = MakeSortClicker(f.hItem, "name")
    f.priceSortBtn = MakeSortClicker(f.hPrice, "price")
    UpdateSortHeaders()

    f.hQty = MakeHeader(T("PG_SHOP_COL_QUANTITY", "Quantity"), "RIGHT", f.hPrice, "LEFT", 0, QTY_W, "CENTER")

    f.scroll = CreateFrame("ScrollFrame", nil, f.main)
    f.scroll:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, -4)
    f.scroll:SetPoint("BOTTOMRIGHT", f.main, "BOTTOMRIGHT", -8, 8)
    f.scroll:EnableMouseWheel(true)
    f.scroll:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll() or 0
        local step = (ROW_HEIGHT + ROW_GAP) * 2
        local child = self:GetScrollChild()
        local maxScroll = math.max(0, (child and child:GetHeight() or 0) - self:GetHeight())
        local target = current - (delta * step)
        if target < 0 then target = 0 end
        if target > maxScroll then target = maxScroll end
        self:SetVerticalScroll(target)
    end)

    f.content = CreateFrame("Frame", nil, f.scroll)
    f.content:SetSize(1, 1)
    f.scroll:SetScrollChild(f.content)
    f.rows = {}

    f.empty = MakeText(f.main, 11, "CENTER")
    f.empty:SetPoint("CENTER", 0, -8)
    f.empty:SetText(T("PG_SHOP_EMPTY", "List is empty"))
    f.empty:Hide()

    f.total = MakeText(f.panel, 11, "LEFT")
    f.total:SetPoint("BOTTOMLEFT", PANEL_PAD, 12)
    f.total:SetPoint("RIGHT", -PANEL_PAD, 0)
    f.total:SetText("")

    f.craftSimIntercept = MakeInterceptToggle(f.panel)
    f.craftSimIntercept:SetPoint("RIGHT", f.refreshAction, "LEFT", -4, 0)

    f.scanAll = CreateFrame("Button", nil, f.panel, "UIPanelButtonTemplate")
    f.scanAll:SetSize(1, 1)
    f.scanAll:SetPoint("BOTTOMLEFT", f.panel, "BOTTOMLEFT", 0, 0)
    f.scanAll:SetText("")
    f.scanAll:Hide()

    f.buyAll = CreateFrame("Button", nil, f.panel, "UIPanelButtonTemplate")
    f.buyAll:SetSize(1, 1)
    f.buyAll:SetPoint("BOTTOMLEFT", f.panel, "BOTTOMLEFT", 0, 0)
    f.buyAll:SetText("")
    f.buyAll:Hide()

    self.frame = f
    if PT.RestyleButtons then PT:RestyleButtons(f, 12) end
    return f
end

function S:SetShopTab(tab)
    if tab ~= "sell" and tab ~= "cancel" then tab = "buy" end
    self.shopTab = tab
    if self.frame and self.frame.ApplyShopTab then
        self.frame.ApplyShopTab(tab)
    end
end

function S:UpdateBindingValueText()
    if not self.frame then return end

    local function FormatBinding(binding)
        if binding and binding ~= "" and _G.GetBindingText then
            return _G.GetBindingText(binding, "KEY_")
        end
        return T("PG_SHOP_BIND_NONE", "—")
    end

    if self.frame.bindValue then
        local binding = self.GetShoppingBinding and self:GetShoppingBinding() or nil
        self.frame.bindValue:SetText(FormatBinding(binding))
    end

    if self.frame.skipBindValue then
        local binding = self.GetShoppingSkipBinding and self:GetShoppingSkipBinding() or nil
        self.frame.skipBindValue:SetText(FormatBinding(binding))
    end

    if self.frame.refreshBindValue then
        local binding = self.GetShoppingRefreshBinding and self:GetShoppingRefreshBinding() or nil
        self.frame.refreshBindValue:SetText(FormatBinding(binding))
    end
end

function S:CreateBindCapture(target)
    if target ~= "skip" and target ~= "refresh" then
        target = "buy"
    end

    if not self.bindCapture then
        local f = CreateFrame("Frame", "HironCraftProfitShoppingListBindCapture", UIParent, "BackdropTemplate")
        f:SetSize(380, 100)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetFrameLevel(1000)
        if f.SetBackdrop then
            f:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            f:SetBackdropColor(0.05, 0.05, 0.07, 0.96)
            f:SetBackdropBorderColor(0.694, 0.612, 0.851, 1)
        end
        f:EnableKeyboard(true)
        f:EnableMouse(true)
        f:Hide()

        f.text = MakeText(f, 12, "CENTER")
        f.text:SetWidth(340)
        f.text:SetPoint("CENTER")

        f:SetScript("OnShow", function(self)
            self:SetPropagateKeyboardInput(false)
        end)

        f:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" then
                self:Hide()
                return
            end

            local binding = _G.NormalizeBindingKey and _G.NormalizeBindingKey(key) or nil
            if not binding then
                if key == "LSHIFT" or key == "RSHIFT"
                or key == "LCTRL" or key == "RCTRL"
                or key == "LALT" or key == "RALT"
                or key == "UNKNOWN" or key == "" then
                    return
                end
                local parts = {}
                if IsControlKeyDown() then parts[#parts + 1] = "CTRL" end
                if IsAltKeyDown() then parts[#parts + 1] = "ALT" end
                if IsShiftKeyDown() then parts[#parts + 1] = "SHIFT" end
                parts[#parts + 1] = key:upper()
                binding = table.concat(parts, "-")
            end

            if self.target == "skip" then
                if S.SetShoppingSkipBinding then S:SetShoppingSkipBinding(binding) end
            elseif self.target == "refresh" then
                if S.SetShoppingRefreshBinding then S:SetShoppingRefreshBinding(binding) end
            else
                if S.SetShoppingBinding then S:SetShoppingBinding(binding) end
            end
            if S.UpdateBindingValueText then S:UpdateBindingValueText() end
            self:Hide()
        end)

        f:SetScript("OnMouseDown", function(self) self:Hide() end)

        self.bindCapture = f
    end

    self.bindCapture.target = target
    if self.bindCapture.text then
        if target == "skip" then
            self.bindCapture.text:SetText(T("PG_SHOP_BIND_CAPTURE_SKIP", "Press a key for the skip action.\nEsc — cancel."))
        elseif target == "refresh" then
            self.bindCapture.text:SetText(T("PG_SHOP_BIND_CAPTURE_REFRESH", "Press a key for the refresh action.\nEsc — cancel."))
        else
            self.bindCapture.text:SetText(T("PG_SHOP_BIND_CAPTURE", "Press a key for the buy action.\nEsc — cancel."))
        end
    end
end

function S:EnsureAuctionTab()
    local tabLib = GetLibAHTab()
    if not tabLib or not AuctionHouseFrame then
        return nil
    end

    if not ShouldShowAuctionTab() then
        return nil
    end

    local f = self:CreateWindow()

    if f:GetParent() ~= AuctionHouseFrame then
        f:SetParent(AuctionHouseFrame)
        f:ClearAllPoints()
        f:SetAllPoints(AuctionHouseFrame)
    end

    if not tabLib:DoesIDExist(AH_TAB_ID) then
        tabLib:CreateTab(AH_TAB_ID, f, T(AH_TAB_TEXT_KEY, "Shopping"), T(TITLE, "HironCraft: shopping list"))
    end

    UpdateAuctionTabVisibility()

    return f
end

function S:ShowWindow()
    local tabLib = GetLibAHTab()
    local f = self:CreateWindow()

    if AuctionHouseFrame and tabLib and HasShoppingSession() then
        self.isAuctionHouseOpen = true

        f:SetParent(AuctionHouseFrame)
        f:ClearAllPoints()
        f:SetAllPoints(AuctionHouseFrame)

        self:EnsureAuctionTab()
        self:RefreshWindow()
        if f.scroll and not f._didInitialScrollReset then
            f.scroll:SetVerticalScroll(0)
            f._didInitialScrollReset = true
        end

        if tabLib:DoesIDExist(AH_TAB_ID) then
            tabLib:SetSelected(AH_TAB_ID)
        end
    else
        f:Hide()
    end
end

function S:HideWindow()
    if self.frame then
        self.frame:Hide()
    end
end

local function GetDisplayedSearchRows(rows)
    rows = rows or {}
    local out = {}

    for _, row in ipairs(rows) do
        if not S.SearchResultMatchesOptions or S:SearchResultMatchesOptions(row) then
            table.insert(out, row)
        end
    end

    return out
end

function S:RefreshWindow()
    local f = self.frame
    if not f then
        return
    end

    local savedScroll = f.scroll and f.scroll:GetVerticalScroll() or 0
    local allRows = self:GetRows()
    local showingSearchResults = self.searchResults and self.searchResults.active
    local rows = showingSearchResults and GetDisplayedSearchRows(self.searchResults.rows or {}) or GetVisibleRows()
    if not showingSearchResults then
        rows = SortRows(rows)
    end
    local total = #rows

    RequestSessionItemData()
    RefreshListPanel(f)

    f.empty:SetShown(total == 0)
    EnsureVisibleRows(f, total)

    if f.scroll and f.content then
        local contentWidth = math.max(1, f.scroll:GetWidth() or 1)
        f.content:SetWidth(contentWidth)
    end

    local nextBuyIndex = self.GetNextBuyableRowIndex and self:GetNextBuyableRowIndex() or nil

    for index, rowData in ipairs(rows) do
        local row = f.rows[index]
        row:Show()
        row.rowIndex = rowData.index
        row.scanBtn.rowIndex = rowData.index
        row.buyBtn.rowIndex = rowData.index
        row.qtyBox.rowIndex = rowData.index
        row.qtyBox.searchRow = nil
        row.buyBtn.mode = nil
        row.buyBtn.searchRow = nil
        row.buyBtn.itemID = nil
        row.scanBtn.itemID = nil
        if row.deleteBtn then
            row.deleteBtn.rowIndex = rowData.index
        end

        row.searchRow = rowData.isSearchResult and rowData or nil

        if row.hotspot then
            ConfigureRowHotspot(row, rowData.isSearchResult == true)
            row.hotspot.rowIndex = rowData.index
            row.hotspot.itemID = rowData.isSearchResult and rowData.itemID or nil
            row.hotspot.searchRow = rowData.isSearchResult and rowData or nil
        end

        local iconID = GetDisplayItemID(rowData)
        row.icon:SetTexture(GetItemIcon(iconID))
        row.name:SetText(GetRowDisplayName(rowData))
        ApplyNameColor(row, rowData)
        SetNameTierIcon(row, rowData)

        local remaining = GetRemainingQuantity(rowData)
        if not row.qtyBox:HasFocus() then
            row.qtyBox:SetText(tostring(remaining))
        end

        local qtyEditable = IsQuantityEditable(rowData)
        row.qtyBox:SetEnabled(qtyEditable)
        row.qtyBox:SetAlpha(qtyEditable and 1 or 0.45)

        SetChosenDisplay(row, rowData)
        row.price:SetText(FormatMoneyText(rowData.pendingUnitPrice or rowData.minPrice))
        row.available:SetText(rowData.totalQuantity ~= nil and tostring(rowData.totalQuantity) or T("PG_DASH", "—"))
        row.status:SetText(rowData.status or "")
        row.status:SetTextColor(1, 1, 1)
        row.bg:SetColorTexture(1, 1, 1, (index % 2 == 0) and 0.035 or 0.02)

        if not rowData.isSearchResult and nextBuyIndex and rowData.index == nextBuyIndex then
            row.bg:SetColorTexture(0.20, 0.55, 0.30, 0.30)
        end

        if rowData.isSearchResult and S.selectedSearchResult and (S.selectedSearchResult == rowData or (S.selectedSearchResult.seenKey and rowData.seenKey and S.selectedSearchResult.seenKey == rowData.seenKey)) then
            row.bg:SetColorTexture(0.25, 0.45, 0.70, 0.32)
        end

        if rowData.skipped then
            row:SetAlpha(0.45)
        else
            row:SetAlpha(1)
        end

        if rowData.isSearchResult then
            local displayRow = rowData
            local displayQty = GetRemainingQuantity(displayRow)

            row.qtyBox.rowIndex = nil
            row.qtyBox.searchRow = rowData
            qtyEditable = IsQuantityEditable(rowData)
            row.qtyBox:SetEnabled(qtyEditable)
            row.qtyBox:SetAlpha(qtyEditable and 1 or 0.45)

            if not row.qtyBox:HasFocus() then
                if rowData.isCommodity == true then
                    row.qtyBox:SetText(tostring(displayQty > 0 and displayQty or (rowData.quantity or 1)))
                else
                    row.qtyBox:SetText("1")
                end
            end

            SetChosenDisplay(row, rowData)
            SetNameTierIcon(row, rowData)
            row.price:SetText(FormatMoneyText(rowData.pendingUnitPrice or rowData.minPrice))
            row.available:SetText(rowData.totalQuantity ~= nil and tostring(rowData.totalQuantity) or T("PG_DASH", "—"))
            row.status:SetText(rowData.status or T("PG_SHOP_SEARCH_RESULT", "Search result"))
            row.scanBtn:Hide()
            if row.deleteBtn then
                row.deleteBtn:Hide()
            end

            local buyEnabled = self.isAuctionHouseOpen and rowData.itemID ~= nil and displayQty > 0
            local buyAtlas = "Perks-ShoppingCart"
            local buyTitle = T("PG_SHOP_BUY", "Buy")
            local buyTip = T("PG_SHOP_BUY_TOOLTIP", "Start purchase for this item.")

            row.buyBtn.rowIndex = nil
            row.buyBtn.mode = "buy_search_result"
            row.buyBtn.searchRow = rowData
            row.buyBtn.itemID = rowData.itemID
            row.buyBtn.itemName = rowData.label

            if rowData.purchaseStage == "await_price" then
                buyEnabled = false
                buyTitle = T("PG_SHOP_WAIT", "Wait...")
                buyTip = T("PG_SHOP_WAIT_TOOLTIP", "Waiting for auction house price confirmation.")
            elseif rowData.purchaseStage == "confirm" then
                buyEnabled = true
                buyAtlas = "VAS-icon-checkmark"
                buyTitle = T("PG_SHOP_CONFIRM", "Confirm")
                buyTip = T("PG_SHOP_CONFIRM_TOOLTIP", "Confirm the current auction house price.")
            elseif rowData.purchaseStage == "processing" or rowData.searchPending or rowData.purchaseStage == "await_search" then
                buyEnabled = false
                buyTitle = rowData.purchaseStage == "processing" and T("PG_SHOP_STATUS_BUYING", "Buying...") or T("PG_SHOP_STATUS_SCANNING", "Scanning...")
                buyTip = ""
            elseif displayQty <= 0 then
                buyEnabled = false
                buyTitle = T("PG_SHOP_STATUS_BOUGHT", "Bought")
                buyTip = ""
            elseif rowData.totalQuantity ~= nil and tonumber(rowData.totalQuantity) <= 0 then
                buyEnabled = false
                buyTitle = T("PG_SHOP_STATUS_NO_ITEM", "No item")
                buyTip = ""
            elseif rowData.isCommodity == false and rowData.bestAuctionID == nil then
                buyEnabled = true
                buyTitle = T("PG_SHOP_BUY", "Buy")
                buyTip = T("PG_SHOP_BUY_TOOLTIP", "Start purchase for this item.")
            end

            if buyAtlas == "VAS-icon-checkmark" then
                row.buyBtn.iconSize = BUY_CONFIRM_ICON_SIZE
            else
                row.buyBtn.iconSize = BUY_ICON_SIZE
            end

            if IsFantasy() and buyAtlas == "Perks-ShoppingCart" then
                SetRedButtonAtlas(row.buyBtn, "128-RedButton-ShoppingCart", "128-RedButton-ShoppingCart-Pressed", FROW_BTN_H, "128-RedButton-ShoppingCart-Disabled")
            else
                ClearRedButtonAtlas(row.buyBtn)
                SetButtonAtlas(row.buyBtn, buyAtlas)
            end
            row.buyBtn.tooltipTitle = buyTitle
            row.buyBtn.tooltipText = buyTip
            row.buyBtn:SetEnabled(buyEnabled)
            row.buyBtn:SetAlpha(IsFantasy() and 1 or (buyEnabled and 1 or 0.30))
            row.buyBtn:Show()
        else
            local pendingLock = rowData.searchPending and rowData.chosenItemID == nil
            local canScan = self.isAuctionHouseOpen and remaining > 0 and not rowData.searchPending
            row.scanBtn:SetEnabled(canScan)
            row.scanBtn:SetAlpha(IsFantasy() and 1 or (canScan and 0.75 or 0.25))
            row.scanBtn:Show()

            if row.deleteBtn then
                local canDelete = rowData.purchaseStage ~= "await_price" and rowData.purchaseStage ~= "processing"
                row.deleteBtn.rowIndex = rowData.index
                row.deleteBtn:SetEnabled(canDelete)
                row.deleteBtn:SetAlpha(IsFantasy() and 1 or (canDelete and 0.85 or 0.25))
                row.deleteBtn:Show()
            end

            local buyEnabled = self.isAuctionHouseOpen and remaining > 0 and not pendingLock and rowData.chosenItemID ~= nil and rowData.minPrice ~= nil
            local buyAtlas = "Perks-ShoppingCart"
            local buyTitle = T("PG_SHOP_BUY", "Buy")
            local buyTip = T("PG_SHOP_BUY_TOOLTIP", "Start purchase for this item.")

            if rowData.purchaseStage == "await_price" then
                buyEnabled = false
                buyTitle = T("PG_SHOP_WAIT", "Wait...")
                buyTip = T("PG_SHOP_WAIT_TOOLTIP", "Waiting for auction house price confirmation.")
            elseif rowData.purchaseStage == "confirm" then
                buyEnabled = true
                buyAtlas = "VAS-icon-checkmark"
                buyTitle = T("PG_SHOP_CONFIRM", "Confirm")
                buyTip = T("PG_SHOP_CONFIRM_TOOLTIP", "Confirm the current auction house price.")
            elseif rowData.purchaseStage == "processing" then
                buyEnabled = false
                buyTitle = T("PG_SHOP_STATUS_BUYING", "Buying...")
                buyTip = ""
            elseif rowData.isCommodity == false and not rowData.bestAuctionID then
                buyEnabled = false
            elseif rowData.isCommodity == true and (not rowData.totalQuantity or rowData.totalQuantity <= 0) then
                buyEnabled = false
            end

            if buyAtlas == "VAS-icon-checkmark" then
                row.buyBtn.iconSize = BUY_CONFIRM_ICON_SIZE
            else
                row.buyBtn.iconSize = BUY_ICON_SIZE
            end

            if IsFantasy() and buyAtlas == "Perks-ShoppingCart" then
                SetRedButtonAtlas(row.buyBtn, "128-RedButton-ShoppingCart", "128-RedButton-ShoppingCart-Pressed", FROW_BTN_H, "128-RedButton-ShoppingCart-Disabled")
            else
                ClearRedButtonAtlas(row.buyBtn)
                SetButtonAtlas(row.buyBtn, buyAtlas)
            end
            row.buyBtn.tooltipTitle = buyTitle
            row.buyBtn.tooltipText = buyTip
            row.buyBtn:SetEnabled(buyEnabled)
            row.buyBtn:SetAlpha(IsFantasy() and 1 or (buyEnabled and 1 or 0.30))
            row.buyBtn:Show()
        end
    end

    for index = total + 1, #f.rows do
        local row = f.rows[index]
        row:Hide()
        row.rowIndex = nil
        row.scanBtn.rowIndex = nil
        row.buyBtn.rowIndex = nil
        row.qtyBox.rowIndex = nil
        row.qtyBox.searchRow = nil
        row.buyBtn.mode = nil
        row.buyBtn.itemID = nil
        row.scanBtn.itemID = nil
        row.searchRow = nil
        if row.name then
            row.name:SetTextColor(1, 1, 1)
        end
        if row.nameTierIcon then
            row.nameTierIcon:Hide()
        end
        if row.deleteBtn then
            row.deleteBtn.rowIndex = nil
        end
        if row.hotspot then
            row.hotspot.rowIndex = nil
            row.hotspot.itemID = nil
            row.hotspot.searchRow = nil
        end
    end

    local contentHeight = math.max(1, total * (ROW_HEIGHT + ROW_GAP))
    f.content:SetHeight(contentHeight)

    if f.scroll then
        C_Timer.After(0, function()
            if not f.scroll or not f.scroll:IsShown() then
                return
            end

            local child = f.scroll:GetScrollChild()
            local maxScroll = math.max(0, (child and child:GetHeight() or 0) - (f.scroll:GetHeight() or 0))
            local target = savedScroll or 0
            if target < 0 then target = 0 end
            if target > maxScroll then target = maxScroll end
            f.scroll:SetVerticalScroll(target)
        end)
    end

    local totalCost = 0
    local left = 0
    local done = 0

    for _, row in ipairs(allRows) do
        if row.hidden then
            done = done + 1
        else
            local remaining = GetRemainingQuantity(row)
            left = left + remaining
            if row.minPrice and remaining > 0 then
                totalCost = totalCost + (row.minPrice * remaining)
            end
        end
    end

    f.total:SetText(string.format(T("PG_SHOP_TOTAL", "Rows: %d  |  Closed: %d  |  Left: %d  |  Total: %s"), #allRows, done, left, FormatMoneyText(totalCost)))

    local hasRemaining = false
    for _, row in ipairs(allRows) do
        if GetRemainingQuantity(row) > 0 then
            hasRemaining = true
            break
        end
    end

    if self.searchResults and self.searchResults.active then
        if self.searchResults.pending then
            f.hint:SetText(T("PG_SHOP_SEARCHING", "Searching..."))
        elseif self.searchResults.lastError and #(self.searchResults.rows or {}) == 0 then
            f.hint:SetText(self.searchResults.lastError)
        else
            f.hint:SetText(string.format(T("PG_SHOP_SEARCH_RESULTS", "Results: %d"), #(self.searchResults.rows or {})))
        end
    elseif self.scanAllState.active then
        local doneCount = math.min(self.scanAllState.pointer or 0, #(self.scanAllState.queue or {}))
        local totalQueue = #(self.scanAllState.queue or {})
        f.hint:SetText(string.format(T("PG_SHOP_HINT_SCAN", "Scan: %d/%d"), doneCount, totalQueue))
    elseif self.buyAllState.active then
        local ptr = math.min(self.buyAllState.pointer or 1, #(self.buyAllState.order or {}))
        local totalOrder = #(self.buyAllState.order or {})
        f.hint:SetText(string.format(T("PG_SHOP_HINT_BUY", "Buying: %d/%d"), ptr, totalOrder))
    else
        f.hint:SetText(self.isAuctionHouseOpen and T("PG_SHOP_AH_OPEN", "AH open") or T("PG_SHOP_AH_CLOSED", "AH closed"))
    end

    if f.scanAll then f.scanAll:SetEnabled(self.isAuctionHouseOpen and hasRemaining) end
    if f.stopScanBtn then
        local scanning = self.scanAllState and self.scanAllState.active == true
        if IsFantasy() then
            f.stopScanBtn:Show()
            f.stopScanBtn:SetEnabled(scanning)
        else
            f.stopScanBtn:SetShown(scanning)
        end
    end
    if f.buyAll then f.buyAll:SetEnabled(false) end
    if f.refreshAction then f.refreshAction:SetEnabled(#allRows > 0) end
    if f.craftSimIntercept then
        f.craftSimIntercept:Show()
        if f.craftSimIntercept.Refresh then
            f.craftSimIntercept:Refresh()
        end
    end
    if f.searchOptionsButton then
        f.searchOptionsButton:Show()
        f.searchOptionsButton:SetEnabled(true)
        f.searchOptionsButton:SetAlpha(1)
    end
    if f.searchButton then
        f.searchButton:Show()
        f.searchButton:SetEnabled(true)
        f.searchButton:SetAlpha(1)
    end
    if f.addToListButton then
        f.addToListButton:Show()
        local canAdd = showingSearchResults and S.selectedSearchResult and S.selectedSearchResult.itemID ~= nil
        f.addToListButton:SetEnabled(canAdd)
        f.addToListButton:SetAlpha(IsFantasy() and 1 or (canAdd and 1 or 0.45))
    end

    RefreshSearchClearButton(f)
end

SLASH_HIRONCRAFT_PROFITSHOPPINGLIST1 = "/phshop"
SLASH_HIRONCRAFT_PROFITSHOPPINGLIST2 = "/phshopping"
SLASH_HIRONCRAFT_PROFITSHOPPINGLIST3 = "/ahuishop"
SLASH_HIRONCRAFT_PROFITSHOPPINGLIST4 = "/ahuishopping"
SlashCmdList["HIRONCRAFT_PROFITSHOPPINGLIST"] = function()
    if not S.session or not S.session.active then
        if S.CreateManualList then
            S:CreateManualList(T("PG_SHOP_MANUAL_LIST_DEFAULT", "Manual list"))
        end
    else
        S:ShowWindow()
    end
end
