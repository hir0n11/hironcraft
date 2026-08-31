local PT = HironCraftProfit
if not PT then return end

PT.ShoppingList = PT.ShoppingList or {}
local S = PT.ShoppingList

local FONT = S.FONT or HironCraftProfit.FONT or STANDARD_TEXT_FONT

local PAD = 12
local LIST_W = 280
local ICON = 36
local GAP = 6
local CAT_H = 20
local AUC_ROW_H = 24
local FORM_H = 172

local function T(key, default)
    local L = PT.L or {}
    return L[key] or default or key
end

local function MakeText(parent, size, justify)
    local fs = parent:CreateFontString(nil, "ARTWORK")
    fs:SetFont(FONT, size or 11, "")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetTextColor(0.92, 0.92, 0.92)
    return fs
end

local function IsFantasy()
    return S.IsFantasy and S.IsFantasy()
end

local function SetBackdrop(frame, alpha)
    if S.ApplyBlockFrame then
        S.ApplyBlockFrame(frame, alpha or 0.4)
        return
    end
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.04, 0.04, 0.06, alpha or 0.4)
    frame:SetBackdropBorderColor(1, 1, 1, 0.06)
end

local function FormatGold(copper)
    if GetMoneyString then
        return GetMoneyString(copper or 0, true)
    end
    return tostring(math.floor((copper or 0) / 10000)) .. "g"
end

local function CopperToGoldText(copper)
    return string.format("%.2f", (copper or 0) / 10000)
end

local function GoldTextToCopper(text)
    local cleaned = (text or ""):gsub(",", ".")
    local gold = tonumber(cleaned)
    if not gold then return 0 end
    return math.floor(gold * 100 + 0.5) * 100
end

local function QualityColor(quality)
    local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if c then return c.r, c.g, c.b end
    return 0.92, 0.92, 0.92
end

local function QualityTierAtlas(itemID)
    if not itemID or not C_TradeSkillUI or not C_TradeSkillUI.GetItemReagentQualityByItemInfo then
        return nil
    end
    local okQ, tier = pcall(C_TradeSkillUI.GetItemReagentQualityByItemInfo, itemID)
    tier = okQ and tonumber(tier) or nil
    if not tier or tier < 1 then
        return nil
    end
    local expansionID
    if GetItemInfo then
        local _, _, _, _, _, _, _, _, _, _, _, _, _, _, exp = GetItemInfo(itemID)
        expansionID = tonumber(exp)
    end
    if expansionID and expansionID >= 11 then
        if tier > 2 then tier = 2 end
        return "Professions-Icon-Quality-12-Tier" .. tostring(tier)
    end
    if tier > 3 then tier = 3 end
    return "Professions-Icon-Quality-Tier" .. tostring(tier)
end

local function MakeDurationButton(parent, label, code)
    if IsFantasy() then
        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetSize(40, 22)
        btn:SetText(label)
        btn:SetScript("OnClick", function()
            if S.SetSellDuration then S:SetSellDuration(code) end
            if S.RefreshSellUI then S:RefreshSellUI() end
        end)
        btn:SetScript("OnEnter", function(self)
            local TT = PT and PT.Tooltip
            if not TT then return end
            TT:Clear()
            TT:AddLine(T("PG_SELL_DURATION_TT_TITLE", "Auction duration"), 13, 1, 1, 1)
            TT:AddLine(T("PG_SELL_DURATION_TT_DESC", "Saved as account-wide default."), 11, 0.8, 0.8, 0.8)
            TT:ShowCursorRightOrBelow()
        end)
        btn:SetScript("OnLeave", function()
            if PT and PT.Tooltip then PT.Tooltip:Clear() end
        end)
        return btn
    end

    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(38, 22)
    btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    btn.label = MakeText(btn, 11, "CENTER")
    btn.label:SetPoint("CENTER")
    btn.label:SetText(label)
    btn:SetScript("OnClick", function()
        if S.SetSellDuration then S:SetSellDuration(code) end
        if S.RefreshSellUI then S:RefreshSellUI() end
    end)
    btn:SetScript("OnEnter", function(self)
        local TT = PT and PT.Tooltip
        if not TT then return end
        TT:Clear()
        TT:AddLine(T("PG_SELL_DURATION_TT_TITLE", "Auction duration"), 13, 1, 1, 1)
        TT:AddLine(T("PG_SELL_DURATION_TT_DESC", "Saved as account-wide default."), 11, 0.8, 0.8, 0.8)
        TT:ShowCursorRightOrBelow()
    end)
    btn:SetScript("OnLeave", function()
        if PT and PT.Tooltip then PT.Tooltip:Clear() end
    end)
    return btn
end

local function SetDurationVisual(btn, active)
    if IsFantasy() then
        if active then
            btn:SetButtonState("PUSHED", true)
        else
            btn:SetButtonState("NORMAL")
        end
        return
    end
    if active then
        btn:SetBackdropColor(0.16, 0.30, 0.42, 0.85)
        btn:SetBackdropBorderColor(0.55, 0.75, 1.0, 0.6)
        btn.label:SetTextColor(1, 1, 1)
    else
        btn:SetBackdropColor(0.06, 0.06, 0.08, 0.7)
        btn:SetBackdropBorderColor(1, 1, 1, 0.08)
        btn.label:SetTextColor(0.7, 0.7, 0.75)
    end
end

local function CategoryName(classID)
    if classID and classID >= 0 and C_Item and C_Item.GetItemClassInfo then
        local name = C_Item.GetItemClassInfo(classID)
        if name then return name end
    end
    return T("PG_SELL_CAT_OTHER", "Other")
end

local function BuildCategories()
    local items = S.sell.items or {}
    local cats = {}
    local order = {}
    for _, e in ipairs(items) do
        local cid = e.classID or -1
        local c = cats[cid]
        if not c then
            c = { classID = cid, name = CategoryName(cid), items = {} }
            cats[cid] = c
            order[#order + 1] = c
        end
        c.items[#c.items + 1] = e
    end
    table.sort(order, function(a, b) return (a.name or "") < (b.name or "") end)
    return order
end

function S:GetSellDisplayOrder()
    local flat = {}
    for _, c in ipairs(BuildCategories()) do
        for _, e in ipairs(c.items or {}) do
            flat[#flat + 1] = e
        end
    end
    return flat
end

local function GetHeader(list, index)
    local h = list.headers[index]
    if h then return h end
    h = CreateFrame("Button", nil, list.content, "BackdropTemplate")
    h:SetHeight(CAT_H)
    h:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    h:SetBackdropColor(0.10, 0.10, 0.14, 0.7)
    h:SetBackdropBorderColor(1, 1, 1, 0.04)
    h.arrow = MakeText(h, 12, "CENTER")
    h.arrow:SetPoint("LEFT", 4, 0)
    h.arrow:SetWidth(12)
    h.label = MakeText(h, 11, "LEFT")
    h.label:SetPoint("LEFT", h.arrow, "RIGHT", 2, 0)
    h.label:SetPoint("RIGHT", -8, 0)
    h:SetScript("OnClick", function(self)
        if self.classID == nil then return end
        S.sell.collapsedCats[self.classID] = not S.sell.collapsedCats[self.classID]
        S:RefreshSellUI()
    end)
    list.headers[index] = h
    return h
end

local function GetIcon(list, index)
    local b = list.icons[index]
    if b then return b end
    b = CreateFrame("Button", nil, list.content, "BackdropTemplate")
    b:SetSize(ICON, ICON)
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetPoint("TOPLEFT", 2, -2)
    b.tex:SetPoint("BOTTOMRIGHT", -2, 2)
    b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.count = b:CreateFontString(nil, "OVERLAY")
    b.count:SetFont(FONT, 11, "OUTLINE")
    b.count:SetPoint("BOTTOMRIGHT", -2, 2)
    b.count:SetTextColor(1, 1, 1)
    b.selGlow = b:CreateTexture(nil, "OVERLAY")
    b.selGlow:SetPoint("TOPLEFT", 1, -1)
    b.selGlow:SetPoint("BOTTOMRIGHT", -1, 1)
    b.selGlow:SetColorTexture(1, 0.85, 0.3, 0.30)
    b.selGlow:Hide()
    b.gradeTex = b:CreateTexture(nil, "OVERLAY", nil, 1)
    b.gradeTex:SetSize(20, 20)
    b.gradeTex:SetPoint("TOPLEFT", -2, 2)
    b.gradeTex:Hide()
    b:SetScript("OnEnter", function(self)
        self.tex:SetVertexColor(1.3, 1.3, 1.3)
        if self.entry and self.entry.bag and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetBagItem(self.entry.bag, self.entry.slot)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        self.tex:SetVertexColor(1, 1, 1)
        if GameTooltip then GameTooltip:Hide() end
    end)
    b:SetScript("OnClick", function(self, button)
        if not self.entry then return end
        if button == "RightButton" then
            if S.ShowSellRowMenu then S:ShowSellRowMenu(self, self.entry) end
        else
            S:SelectSellItem(self.entry)
        end
    end)
    list.icons[index] = b
    return b
end

local function EnsureAuctionRows(auc, count)
    for i = #auc.rows + 1, count do
        local row = CreateFrame("Button", nil, auc.content)
        row:SetSize(10, AUC_ROW_H - 2)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * AUC_ROW_H)
        row:SetPoint("RIGHT", auc.content, "RIGHT", 0, 0)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.hl = row:CreateTexture(nil, "HIGHLIGHT")
        row.hl:SetAllPoints()
        row.hl:SetColorTexture(1, 1, 1, 0.06)
        row.price = MakeText(row, 11, "LEFT")
        row.price:SetPoint("LEFT", 6, 0)
        row.qty = MakeText(row, 11, "CENTER")
        row.qty:SetPoint("CENTER", row, "CENTER", -40, 0)

        row:SetScript("OnClick", function(self)
            if not self.tier or not self.tier.price or self.tier.price <= 0 then return end
            if not S.frame or not S.frame.sellPanel or not S.frame.sellPanel._built then return end
            S.sell.price = self.tier.price
            S.sell._priceSeeded = nil
            local form = S.frame.sellPanel.form
            if form and form.priceBox and form.priceBox.SetText then
                form.priceBox:SetText(CopperToGoldText(self.tier.price))
                if form.priceBox.ClearFocus then form.priceBox:ClearFocus() end
            end
            if S.UpdateSellTotals then S:UpdateSellTotals() end
        end)

        row:SetScript("OnEnter", function(self)
            local tier = self.tier
            if not tier then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

            local link = S.sell and S.sell.selected and S.sell.selected.itemLink
            if link then
                GameTooltip:SetHyperlink(link)
            else
                GameTooltip:AddLine(T("PG_SELL_LOT_TT_TITLE", "Лот аукциона"), 1, 0.82, 0.2)
            end

            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine(T("PG_SELL_LOT_UNIT", "Цена за ед."), FormatGold(tier.price or 0), 0.8, 0.8, 0.8, 1, 1, 1)
            GameTooltip:AddDoubleLine(T("PG_SELL_LOT_QTY", "Количество"), tostring(tier.qty or 0), 0.8, 0.8, 0.8, 1, 1, 1)
            GameTooltip:AddDoubleLine(T("PG_SELL_LOT_TOTAL", "Сумма"), FormatGold((tier.price or 0) * (tier.qty or 0)), 0.8, 0.8, 0.8, 1, 1, 1)

            if tier.owned then
                GameTooltip:AddDoubleLine(T("PG_SELL_LOT_SELLER", "Продавец"), T("PG_SELL_AUC_YOU", "you"), 0.8, 0.8, 0.8, 0.55, 0.75, 1)
            elseif type(tier.owners) == "table" and #tier.owners > 0 then
                local name = tier.owners[1]
                if #tier.owners > 1 then name = name .. " +" .. (#tier.owners - 1) end
                GameTooltip:AddDoubleLine(T("PG_SELL_LOT_SELLER", "Продавец"), name, 0.8, 0.8, 0.8, 0.9, 0.9, 0.9)
            end

            if tier.isReference then
                GameTooltip:AddLine(T("PG_SELL_LOT_REF", "Эталон цены (по нему считается постинг)"), 0.55, 0.9, 0.55)
            elseif tier.isFlip then
                GameTooltip:AddLine(T("PG_SELL_LOT_FLIP", "Пропущен как флиппер (наживка)"), 0.95, 0.55, 0.35)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        row.buy = CreateFrame("Button", nil, row)
        row.buy:SetSize(20, 20)
        row.buy:SetPoint("RIGHT", -8, 0)
        row.buy:SetFrameLevel(row:GetFrameLevel() + 2)
        row.buy.icon = row.buy:CreateTexture(nil, "ARTWORK")
        row.buy.icon:SetAllPoints()
        if row.buy.icon.SetAtlas then row.buy.icon:SetAtlas("Perks-ShoppingCart") end
        row.buy:SetScript("OnEnter", function(self)
            if self.icon then self.icon:SetVertexColor(1.3, 1.3, 1.3) end
            local TT = PT and PT.Tooltip
            if not TT then return end
            TT:Clear()
            if self.isConfirm then
                TT:AddLine(T("PG_SHOP_CONFIRM", "Confirm"), 13, 1, 1, 1)
                TT:AddLine(T("PG_SELL_BUY_PENDING_TT", "Purchase pending..."), 11, 0.8, 0.8, 0.8)
            else
                TT:AddLine(T("PG_SELL_BUY_BTN", "Buy"), 13, 1, 1, 1)
                TT:AddLine(T("PG_SELL_BUY_TT", "Buy out this auction."), 11, 0.8, 0.8, 0.8)
            end
            TT:ShowCursorRightOrBelow()
        end)
        row.buy:SetScript("OnLeave", function(self)
            if self.icon then self.icon:SetVertexColor(1, 1, 1) end
            if PT and PT.Tooltip then PT.Tooltip:Clear() end
        end)
        row.buy:SetScript("OnClick", function(self)
            if self.tier and S.BuySellTier then S:BuySellTier(self.tier) end
        end)

        row.owner = MakeText(row, 11, "CENTER")
        row.owner:SetPoint("CENTER", row.buy, "CENTER", 0, 0)
        row.owner:SetWidth(40)
        row.owner:SetTextColor(0.55, 0.75, 1.0)

        auc.rows[i] = row
    end
end

function S:EnsureSellPanel()
    local f = self.frame
    if not f or not f.sellPanel then return end
    local panel = f.sellPanel
    if panel._built then return end
    panel._built = true
    S.sell.collapsedCats = S.sell.collapsedCats or {}

    if f.sellPlaceholder then f.sellPlaceholder:Hide() end

    local list = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    list:SetPoint("TOPLEFT", PAD, -PAD)
    list:SetPoint("BOTTOMLEFT", PAD, PAD)
    list:SetWidth(LIST_W)
    SetBackdrop(list, 0.4)
    panel.list = list

    list.title = MakeText(list, 12, "LEFT")
    list.title:SetPoint("TOPLEFT", 8, -8)
    list.title:SetText(T("PG_SELL_BAGS_TITLE", "Bags"))

    list.scroll = CreateFrame("ScrollFrame", nil, list)
    list.scroll:SetPoint("TOPLEFT", 8, -28)
    list.scroll:SetPoint("BOTTOMRIGHT", -8, 6)
    list.scroll:EnableMouseWheel(true)
    list.scroll:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll() or 0
        local child = self:GetScrollChild()
        local maxScroll = math.max(0, (child and child:GetHeight() or 0) - self:GetHeight())
        local target = current - (delta * (ICON + GAP) * 2)
        if target < 0 then target = 0 end
        if target > maxScroll then target = maxScroll end
        self:SetVerticalScroll(target)
    end)
    list.content = CreateFrame("Frame", nil, list.scroll)
    list.content:SetSize(LIST_W - 16, 1)
    list.scroll:SetScrollChild(list.content)
    list.headers = {}
    list.icons = {}

    list.empty = MakeText(list, 11, "CENTER")
    list.empty:SetPoint("CENTER", 0, 10)
    list.empty:SetText(T("PG_SELL_EMPTY", "No items to sell"))
    list.empty:Hide()

    local form = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    form:SetPoint("TOPLEFT", list, "TOPRIGHT", 10, 0)
    form:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -PAD)
    form:SetHeight(FORM_H)
    SetBackdrop(form, 0.4)
    panel.form = form

    form.icon = form:CreateTexture(nil, "ARTWORK")
    form.icon:SetSize(40, 40)
    form.icon:SetPoint("TOPLEFT", 12, -12)
    form.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    form.name = MakeText(form, 13, "LEFT")
    form.name:SetPoint("TOPLEFT", form.icon, "TOPRIGHT", 10, -2)
    form.name:SetPoint("RIGHT", -12, 0)
    form.name:SetWordWrap(false)

    form.count = MakeText(form, 11, "LEFT")
    form.count:SetPoint("BOTTOMLEFT", form.icon, "BOTTOMRIGHT", 10, 1)
    form.count:SetTextColor(0.7, 0.7, 0.75)

    form.qtyLabel = MakeText(form, 11, "LEFT")
    form.qtyLabel:SetPoint("TOPLEFT", 12, -62)
    form.qtyLabel:SetText(T("PG_SELL_QUANTITY", "Quantity"))

    form.qtyBox = CreateFrame("EditBox", nil, form, "InputBoxTemplate")
    form.qtyBox:SetSize(60, 22)
    form.qtyBox:SetPoint("LEFT", form.qtyLabel, "RIGHT", 12, 0)
    form.qtyBox:SetAutoFocus(false)
    form.qtyBox:SetNumeric(true)
    form.qtyBox:SetFont(FONT, 12, "")
    form.qtyBox:SetScript("OnTextChanged", function(box, userInput)
        if not userInput then return end
        S.sell.quantity = tonumber(box:GetText()) or 0
        S:UpdateSellTotals()
    end)
    form.qtyBox:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
    form.qtyBox:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)

    form.maxBtn = CreateFrame("Button", nil, form, "UIPanelButtonTemplate")
    form.maxBtn:SetSize(44, 22)
    form.maxBtn:SetPoint("LEFT", form.qtyBox, "RIGHT", 6, 0)
    form.maxBtn:SetText(T("PG_SELL_MAX", "Max"))
    form.maxBtn:SetScript("OnClick", function()
        S.sell.quantity = S:GetSellPostLimit()
        S:RefreshSellUI()
    end)

    form.durLabel = MakeText(form, 11, "LEFT")
    form.durLabel:SetPoint("LEFT", form.maxBtn, "RIGHT", 20, 0)
    form.durLabel:SetText(T("PG_SELL_DURATION", "Duration"))

    form.dur12 = MakeDurationButton(form, T("PG_SELL_12H", "12h"), 1)
    form.dur12:SetPoint("LEFT", form.durLabel, "RIGHT", 8, 0)
    form.dur24 = MakeDurationButton(form, T("PG_SELL_24H", "24h"), 2)
    form.dur24:SetPoint("LEFT", form.dur12, "RIGHT", 4, 0)
    form.dur48 = MakeDurationButton(form, T("PG_SELL_48H", "48h"), 3)
    form.dur48:SetPoint("LEFT", form.dur24, "RIGHT", 4, 0)

    form.priceLabel = MakeText(form, 11, "LEFT")
    form.priceLabel:SetPoint("TOPLEFT", 12, -92)
    form.priceLabel:SetText(T("PG_SELL_PRICE", "Unit price (g)"))

    form.priceBox = CreateFrame("EditBox", nil, form, "InputBoxTemplate")
    form.priceBox:SetSize(46, 22)
    form.priceBox:SetPoint("LEFT", form.priceLabel, "RIGHT", 12, 0)
    form.priceBox:SetAutoFocus(false)
    form.priceBox:SetFont(FONT, 12, "")
    form.priceBox:SetScript("OnTextChanged", function(box, userInput)
        if not userInput then return end
        S.sell.price = GoldTextToCopper(box:GetText())
        S.sell._priceSeeded = nil
        S:UpdateSellTotals()
    end)
    form.priceBox:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
    form.priceBox:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)

    form.priceMoney = MakeText(form, 11, "LEFT")
    form.priceMoney:SetPoint("LEFT", form.priceBox, "RIGHT", 8, 0)
    form.priceMoney:SetTextColor(0.98, 0.86, 0.42)

    form.marketLine = MakeText(form, 11, "RIGHT")
    form.marketLine:SetPoint("TOPRIGHT", -12, -92)
    form.marketLine:SetTextColor(0.6, 0.85, 0.6)

    form.flipLine = MakeText(form, 11, "RIGHT")
    form.flipLine:SetPoint("TOPRIGHT", -12, -112)
    form.flipLine:SetTextColor(0.95, 0.55, 0.35)

    form.depositLine = MakeText(form, 11, "LEFT")
    form.depositLine:SetPoint("BOTTOMLEFT", 12, 36)
    form.depositLine:SetTextColor(0.75, 0.75, 0.8)

    form.totalLine = MakeText(form, 12, "LEFT")
    form.totalLine:SetPoint("BOTTOMLEFT", 12, 16)

    local function BuildSellActionButton(w, br, bg, bb, labelText, labelColor, actionKey, onLMB, ttTitle, ttDesc)
        if IsFantasy() then
            local btn = CreateFrame("Button", nil, form, "UIPanelButtonTemplate")
            btn:SetSize(w, 24)
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            btn:SetText(labelText)
            btn:SetScript("OnClick", function(self, button)
                if button == "RightButton" then
                    if IsShiftKeyDown and IsShiftKeyDown() then
                        if S.ClearSellBinding then S:ClearSellBinding(actionKey) end
                    elseif S.ShowSellBindCapture then
                        S:ShowSellBindCapture(actionKey)
                    end
                    return
                end
                onLMB()
            end)
            btn:SetScript("OnEnter", function(self)
                local TT = PT and PT.Tooltip
                if not TT then return end
                TT:Clear()
                TT:AddLine(ttTitle, 13, 1, 1, 1)
                if ttDesc then TT:AddLine(ttDesc, 11, 0.8, 0.8, 0.8) end
                local b = S.GetSellBinding and S:GetSellBinding(actionKey) or nil
                local keyText = (b and b ~= "" and _G.GetBindingText) and _G.GetBindingText(b, "KEY_") or T("PG_SHOP_BIND_NONE", "—")
                TT:AddLine(" ", 6)
                TT:AddLine(string.format(T("PG_SHOP_BIND_TT_CURRENT", "Assigned key: %s"), keyText), 11, 0.98, 0.86, 0.42)
                TT:AddLine(" ", 6)
                TT:AddLine(T("PG_SELL_BIND_TT_RMB", "Right click — assign key."), 11, 0.7, 0.7, 0.7)
                TT:AddLine(T("PG_SELL_BIND_TT_SHIFT", "Shift + right click — clear."), 11, 0.7, 0.7, 0.7)
                TT:ShowCursorRightOrBelow()
            end)
            btn:SetScript("OnLeave", function()
                if PT and PT.Tooltip then PT.Tooltip:Clear() end
            end)
            return btn
        end

        local btn = CreateFrame("Button", nil, form, "BackdropTemplate")
        btn:SetSize(w, 24)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        btn:SetBackdropColor(0.10, 0.10, 0.12, 0.92)
        btn:SetBackdropBorderColor(br, bg, bb, 1)
        btn.label = MakeText(btn, 12, "CENTER")
        btn.label:SetPoint("CENTER", 0, -1)
        btn.label:SetText(labelText)
        if labelColor then btn.label:SetTextColor(labelColor[1], labelColor[2], labelColor[3]) end
        btn.key = MakeText(btn, 8, "RIGHT")
        btn.key:SetPoint("TOPRIGHT", -3, -2)
        btn.key:SetTextColor(0.98, 0.86, 0.42)
        btn:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                if IsShiftKeyDown and IsShiftKeyDown() then
                    if S.ClearSellBinding then S:ClearSellBinding(actionKey) end
                elseif S.ShowSellBindCapture then
                    S:ShowSellBindCapture(actionKey)
                end
                return
            end
            onLMB()
        end)
        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.15, 0.16, 0.14, 0.95)
            local TT = PT and PT.Tooltip
            if not TT then return end
            TT:Clear()
            TT:AddLine(ttTitle, 13, 1, 1, 1)
            if ttDesc then TT:AddLine(ttDesc, 11, 0.8, 0.8, 0.8) end
            TT:AddLine(" ", 6)
            TT:AddLine(T("PG_SELL_BIND_TT_RMB", "Right click — assign key."), 11, 0.7, 0.7, 0.7)
            TT:AddLine(T("PG_SELL_BIND_TT_SHIFT", "Shift + right click — clear."), 11, 0.7, 0.7, 0.7)
            TT:ShowCursorRightOrBelow()
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.10, 0.10, 0.12, 0.92)
            if PT and PT.Tooltip then PT.Tooltip:Clear() end
        end)
        return btn
    end

    form.postBtn = BuildSellActionButton(96, 0.30, 0.75, 0.40,
        T("PG_SELL_POST", "Post"), nil, "post",
        function() if S.PostSellItem then S:PostSellItem() end end,
        T("PG_SELL_POST_TT_TITLE", "Post (hotkey)"),
        T("PG_SELL_POST_TT_DESC", "Left click / bound key — post current item."))
    form.postBtn:SetPoint("BOTTOMRIGHT", -12, 14)

    form.skipBtn = BuildSellActionButton(96, 0.60, 0.55, 0.30,
        T("PG_SELL_SKIP", "Skip"), { 0.9, 0.85, 0.6 }, "skip",
        function() if S.SkipSellItem then S:SkipSellItem() end end,
        T("PG_SELL_SKIP_TT_TITLE", "Skip (hotkey)"),
        T("PG_SELL_SKIP_TT_DESC", "Left click / bound key — skip to next item."))
    form.skipBtn:SetPoint("RIGHT", form.postBtn, "LEFT", -6, 0)

    form.selectHint = MakeText(form, 12, "CENTER")
    form.selectHint:SetPoint("CENTER")
    form.selectHint:SetText(T("PG_SELL_SELECT_HINT", "Select an item on the left"))

    local auc = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    auc:SetPoint("TOPLEFT", form, "BOTTOMLEFT", 0, -8)
    auc:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -PAD, PAD)
    SetBackdrop(auc, 0.4)
    panel.auc = auc

    auc.title = MakeText(auc, 12, "LEFT")
    auc.title:SetPoint("TOPLEFT", 8, -8)
    auc.title:SetText(T("PG_SELL_AUC_TITLE", "Current auctions"))

    auc.flipLabel = MakeText(auc, 11, "RIGHT")
    auc.flipLabel:SetPoint("TOPRIGHT", -175, -8)
    auc.flipLabel:SetTextColor(0.95, 0.55, 0.35)
    auc.flipLabel:SetText(T("PG_SELL_FLIP_LABEL", "Анти-флиппер: <"))

    auc.flipBox = CreateFrame("EditBox", nil, auc, "InputBoxTemplate")
    auc.flipBox:SetSize(24, 18)
    auc.flipBox:SetPoint("LEFT", auc.flipLabel, "RIGHT", 5, 0)
    auc.flipBox:SetAutoFocus(false)
    auc.flipBox:SetNumeric(true)
    auc.flipBox:SetMaxLetters(3)
    auc.flipBox:SetFont(FONT, 11, "")
    auc.flipBox:SetJustifyH("CENTER")
    auc.flipBox:SetText(tostring(math.floor((S:GetFlipRatio() or 0.6) * 100 + 0.5)))

    auc.flipSuffix = MakeText(auc, 11, "LEFT")
    auc.flipSuffix:SetPoint("LEFT", auc.flipBox, "RIGHT", 2, 0)
    auc.flipSuffix:SetTextColor(0.95, 0.55, 0.35)
    auc.flipSuffix:SetText("%")

    local function ApplyFlipBox()
        local raw = tonumber(auc.flipBox:GetText())
        if not raw then
            auc.flipBox:SetText(tostring(math.floor(S:GetFlipRatio() * 100 + 0.5)))
            return
        end
        if raw < 1 then raw = 1 end
        if raw > 99 then raw = 99 end
        S:SetFlipRatio(raw / 100)
        auc.flipBox:SetText(tostring(raw))
        if S.RefreshSellUI then S:RefreshSellUI() end
        if S.DoSellSearch and S.sell and S.sell.selected then S:DoSellSearch(S.sell.selected) end
    end
    auc.flipBox:SetScript("OnEnterPressed", function(self) ApplyFlipBox(); self:ClearFocus() end)
    auc.flipBox:SetScript("OnEditFocusLost", ApplyFlipBox)
    auc.flipBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    auc.flipQtyLabel = MakeText(auc, 11, "LEFT")
    auc.flipQtyLabel:SetPoint("LEFT", auc.flipSuffix, "RIGHT", 10, 0)
    auc.flipQtyLabel:SetTextColor(0.95, 0.55, 0.35)
    auc.flipQtyLabel:SetText(T("PG_SELL_FLIP_QTY_LABEL", "кол-во <="))

    auc.flipQtyBox = CreateFrame("EditBox", nil, auc, "InputBoxTemplate")
    auc.flipQtyBox:SetSize(42, 18)
    auc.flipQtyBox:SetPoint("LEFT", auc.flipQtyLabel, "RIGHT", 5, 0)
    auc.flipQtyBox:SetAutoFocus(false)
    auc.flipQtyBox:SetNumeric(true)
    auc.flipQtyBox:SetMaxLetters(4)
    auc.flipQtyBox:SetFont(FONT, 11, "")
    auc.flipQtyBox:SetJustifyH("CENTER")
    auc.flipQtyBox:SetText(tostring(S:GetFlipMinQty()))

    local function ApplyFlipQtyBox()
        local raw = tonumber(auc.flipQtyBox:GetText())
        if not raw then
            auc.flipQtyBox:SetText(tostring(S:GetFlipMinQty()))
            return
        end
        if raw < 0 then raw = 0 end
        if raw > 9999 then raw = 9999 end
        S:SetFlipMinQty(raw)
        auc.flipQtyBox:SetText(tostring(math.floor(raw)))
        if S.RefreshSellUI then S:RefreshSellUI() end
        if S.DoSellSearch and S.sell and S.sell.selected then S:DoSellSearch(S.sell.selected) end
    end
    auc.flipQtyBox:SetScript("OnEnterPressed", function(self) ApplyFlipQtyBox(); self:ClearFocus() end)
    auc.flipQtyBox:SetScript("OnEditFocusLost", ApplyFlipQtyBox)
    auc.flipQtyBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    auc.flipReset = CreateFrame("Button", nil, auc)
    auc.flipReset:SetSize(14, 14)
    auc.flipReset:SetPoint("LEFT", auc.flipQtyBox, "RIGHT", 4, 0)
    auc.flipReset.tex = auc.flipReset:CreateTexture(nil, "ARTWORK")
    auc.flipReset.tex:SetAllPoints()
    auc.flipReset.tex:SetAtlas("transmog-icon-revert-small")
    auc.flipReset.tex:SetVertexColor(0.85, 0.85, 0.9)
    auc.flipReset:SetScript("OnEnter", function(self)
        self.tex:SetVertexColor(1, 1, 1)
        local TT = PT and PT.Tooltip
        if not TT then return end
        TT:Clear()
        TT:AddLine(T("PG_SELL_FLIP_RESET", "Сбросить к значению по умолчанию (60%)"), 11, 1, 1, 1)
        TT:ShowCursorRightOrBelow()
    end)
    auc.flipReset:SetScript("OnLeave", function(self)
        self.tex:SetVertexColor(0.85, 0.85, 0.9)
        if PT and PT.Tooltip then PT.Tooltip:Clear() end
    end)
    auc.flipReset:SetScript("OnClick", function()
        local def = S.FLIP_DROP_RATIO_DEFAULT or 0.6
        S:SetFlipRatio(def)
        auc.flipBox:SetText(tostring(math.floor(def * 100 + 0.5)))
        S:SetFlipMinQty(S.FLIP_MIN_QTY_DEFAULT or 5)
        if auc.flipQtyBox then auc.flipQtyBox:SetText(tostring(S:GetFlipMinQty())) end
        if S.RefreshSellUI then S:RefreshSellUI() end
        if S.DoSellSearch and S.sell and S.sell.selected then S:DoSellSearch(S.sell.selected) end
    end)

    auc.flipLabel:SetScript("OnEnter", function()
        local TT = PT and PT.Tooltip
        if not TT then return end
        TT:Clear()
        TT:AddLine(T("PG_SELL_FLIP_TT_TITLE", "Порог анти-флиппера"), 13, 1, 1, 1)
        TT:AddLine(T("PG_SELL_FLIP_TT_DESC", "Лот считается приманкой флиппера, если его цена меньше указанного % от следующего лота. Такие лоты исключаются при расчёте цены."), 11, 0.8, 0.8, 0.8)
        TT:AddLine(T("PG_SELL_FLIP_QTY_TT_DESC", "«Кол-во <=» — лоты с количеством не больше этого считаются мелкой приманкой и отсеиваются."), 11, 0.8, 0.8, 0.8)
        TT:ShowCursorRightOrBelow()
    end)
    auc.flipLabel:SetScript("OnLeave", function()
        if PT and PT.Tooltip then PT.Tooltip:Clear() end
    end)
    auc.flipLabel:EnableMouse(true)

    auc.hPrice = MakeText(auc, 10, "LEFT")
    auc.hPrice:SetPoint("TOPLEFT", 12, -26)
    auc.hPrice:SetText(T("PG_SELL_AUC_PRICE", "Price"))
    auc.hPrice:SetTextColor(0.6, 0.6, 0.65)

    auc.hQty = MakeText(auc, 10, "CENTER")
    auc.hQty:SetPoint("TOP", auc, "TOP", -20, -26)
    auc.hQty:SetText(T("PG_SELL_AUC_QTY", "Qty"))
    auc.hQty:SetTextColor(0.6, 0.6, 0.65)

    auc.hOwner = MakeText(auc, 10, "RIGHT")
    auc.hOwner:SetPoint("TOPRIGHT", -8, -26)
    auc.hOwner:SetText(T("PG_SELL_AUC_OWNER", "Owner"))
    auc.hOwner:SetTextColor(0.6, 0.6, 0.65)

    auc.scroll = CreateFrame("ScrollFrame", nil, auc)
    auc.scroll:SetPoint("TOPLEFT", 6, -42)
    auc.scroll:SetPoint("BOTTOMRIGHT", -6, 6)
    auc.scroll:EnableMouseWheel(true)
    auc.scroll:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll() or 0
        local child = self:GetScrollChild()
        local maxScroll = math.max(0, (child and child:GetHeight() or 0) - self:GetHeight())
        local target = current - (delta * AUC_ROW_H * 2)
        if target < 0 then target = 0 end
        if target > maxScroll then target = maxScroll end
        self:SetVerticalScroll(target)
    end)
    auc.content = CreateFrame("Frame", nil, auc.scroll)
    auc.content:SetSize(10, 1)
    auc.scroll:SetScrollChild(auc.content)
    auc.rows = {}

    auc.empty = MakeText(auc, 11, "CENTER")
    auc.empty:SetPoint("CENTER", 0, 10)
    auc.empty:SetText(T("PG_SELL_AUC_EMPTY", "No auctions"))
    auc.empty:Hide()

    if PT.RestyleButtons then PT:RestyleButtons(panel, 12) end
end

local function LayoutSellBags(list)
    local cats = BuildCategories()
    S.sell.orderedKeys = {}
    local contentW = list.scroll:GetWidth()
    if contentW < 20 then contentW = LIST_W - 16 end
    list.content:SetWidth(contentW)

    local perRow = math.max(1, math.floor((contentW + GAP) / (ICON + GAP)))
    local y = 0
    local hIdx, iIdx = 0, 0

    for _, c in ipairs(cats) do
        hIdx = hIdx + 1
        local header = GetHeader(list, hIdx)
        local collapsed = S.sell.collapsedCats[c.classID] == true
        header.classID = c.classID
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", 0, -y)
        header:SetPoint("RIGHT", list.content, "RIGHT", 0, 0)
        header.arrow:SetText(collapsed and "|cffaaaaaa+|r" or "|cffaaaaaa-|r")
        header.label:SetText("|cffffd200" .. (c.name or "?") .. "|r  |cff888888(" .. #c.items .. ")|r")
        header:Show()
        y = y + CAT_H + 3

        if not collapsed then
            local col = 0
            for _, entry in ipairs(c.items) do
                iIdx = iIdx + 1
                local b = GetIcon(list, iIdx)
                b.entry = entry
                S.sell.orderedKeys[#S.sell.orderedKeys + 1] = entry.key
                local x = col * (ICON + GAP)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", x, -y)
                if entry.icon then b.tex:SetTexture(entry.icon) end
                if (entry.count or 0) > 1 then
                    b.count:SetText(tostring(entry.count))
                else
                    b.count:SetText("")
                end
                local gradeAtlas = QualityTierAtlas(entry.itemID)
                if gradeAtlas and b.gradeTex.SetAtlas then
                    b.gradeTex:SetAtlas(gradeAtlas)
                    b.gradeTex:Show()
                else
                    b.gradeTex:Hide()
                end
                local qr, qg, qb = QualityColor(entry.quality)
                if S.sell.selected and S.sell.selected.key == entry.key then
                    b:SetBackdropColor(0.24, 0.20, 0.06, 0.9)
                    b:SetBackdropBorderColor(1, 0.9, 0.35, 1)
                    b.selGlow:Show()
                else
                    b:SetBackdropColor(0.05, 0.05, 0.07, 0.4)
                    b:SetBackdropBorderColor(qr, qg, qb, 0.95)
                    b.selGlow:Hide()
                end
                b:Show()
                col = col + 1
                if col >= perRow then
                    col = 0
                    y = y + ICON + GAP
                end
            end
            if col > 0 then
                y = y + ICON + GAP
            end
        end
        y = y + 6
    end

    for i = hIdx + 1, #list.headers do list.headers[i]:Hide() end
    for i = iIdx + 1, #list.icons do
        list.icons[i].entry = nil
        list.icons[i]:Hide()
    end

    list.content:SetHeight(math.max(1, y))
    list.empty:SetShown(#(S.sell.items or {}) == 0)
end

function S:UpdateSellTotals()
    local f = self.frame
    if not f or not f.sellPanel or not f.sellPanel._built then return end
    local form = f.sellPanel.form
    if not self.sell.selected then return end

    local qty = self.sell.quantity or 0
    local price = self.sell.price or 0

    form.depositLine:SetText(T("PG_SELL_DEPOSIT", "Deposit") .. ": " .. FormatGold(self:GetSellDeposit()))
    form.totalLine:SetText(T("PG_SELL_TOTAL", "Total") .. ": " .. FormatGold(qty * price))
    form.priceMoney:SetText(FormatGold(price))

    local valid = qty > 0 and price > 0 and qty <= self:GetSellPostLimit()
    if IsFantasy() then
        form.postBtn:SetEnabled(valid)
    elseif valid then
        form.postBtn.label:SetTextColor(1, 1, 1)
        form.postBtn:SetBackdropBorderColor(0.30, 0.75, 0.40, 1)
    else
        form.postBtn.label:SetTextColor(0.5, 0.5, 0.5)
        form.postBtn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    end
end

local function RefreshAuctions(auc, scan)
    local tiers = (scan and scan.tiers) or {}
    EnsureAuctionRows(auc, #tiers)
    auc.content:SetWidth(math.max(10, auc.scroll:GetWidth()))

    for i, tier in ipairs(tiers) do
        local row = auc.rows[i]
        row.tier = tier
        local prefix = ""
        if tier.isFlip then
            prefix = "|cffff8844* |r"
            row.price:SetTextColor(0.95, 0.55, 0.35)
        elseif tier.isReference then
            row.price:SetTextColor(0.55, 0.9, 0.55)
        else
            row.price:SetTextColor(0.92, 0.92, 0.92)
        end
        row.price:SetText(prefix .. FormatGold(tier.price))
        row.qty:SetText(tostring(tier.qty or 0))
        row.owner:SetText(tier.owned and T("PG_SELL_AUC_YOU", "you") or "")
        row.buy.tier = tier
        row.buy:SetShown(scan and scan.isCommodity and not tier.owned and true or false)
        local pb = S.sell and S.sell.pendingBuy
        local isConfirm = pb and scan and pb.itemID == scan.itemID and pb.tierPrice == tier.price and true or false
        row.buy.isConfirm = isConfirm
        if row.buy.icon and row.buy.icon.SetAtlas then
            row.buy.icon:SetAtlas(isConfirm and "VAS-icon-checkmark" or "Perks-ShoppingCart")
        end
        if tier.isReference then
            row.bg:SetColorTexture(0.16, 0.32, 0.18, 0.5)
        elseif tier.isFlip then
            row.bg:SetColorTexture(0.32, 0.18, 0.12, 0.5)
        elseif i % 2 == 0 then
            row.bg:SetColorTexture(1, 1, 1, 0.03)
        else
            row.bg:SetColorTexture(1, 1, 1, 0.01)
        end
        row:Show()
    end
    for i = #tiers + 1, #auc.rows do
        auc.rows[i].tier = nil
        auc.rows[i]:Hide()
    end
    auc.content:SetHeight(math.max(1, #tiers * AUC_ROW_H))
    auc.empty:SetShown(#tiers == 0 and not (scan and scan.pending))
end

function S:RefreshSellUI()
    self:EnsureSellPanel()
    local f = self.frame
    if not f or not f.sellPanel or not f.sellPanel._built then return end

    local panel = f.sellPanel
    local form = panel.form

    LayoutSellBags(panel.list)

    local selected = self.sell.selected
    local hasItem = selected ~= nil

    form.selectHint:SetShown(not hasItem)
    local widgets = { form.icon, form.name, form.count, form.qtyLabel, form.qtyBox, form.maxBtn,
        form.durLabel, form.dur12, form.dur24, form.dur48, form.priceLabel, form.priceBox,
        form.priceMoney, form.marketLine, form.flipLine, form.depositLine, form.totalLine, form.postBtn, form.skipBtn }
    for _, w in ipairs(widgets) do w:SetShown(hasItem) end
    self:UpdateSellBindText()

    RefreshAuctions(panel.auc, self.sell.scan)

    if not hasItem then return end

    if selected.icon then form.icon:SetTexture(selected.icon) end
    local r, g, b = QualityColor(selected.quality)
    form.name:SetText(selected.itemName or ("item:" .. tostring(selected.itemID)))
    form.name:SetTextColor(r, g, b)
    form.count:SetText(string.format(T("PG_SELL_COUNT", "In bags: %d"), selected.count or 0))

    if not form.qtyBox:HasFocus() then
        form.qtyBox:SetText(tostring(self.sell.quantity or 0))
    end
    if not form.priceBox:HasFocus() then
        form.priceBox:SetText(self.sell.price and self.sell.price > 0 and CopperToGoldText(self.sell.price) or "")
    end

    SetDurationVisual(form.dur12, self.sell.duration == 1)
    SetDurationVisual(form.dur24, self.sell.duration == 2)
    SetDurationVisual(form.dur48, self.sell.duration == 3)

    local scan = self.sell.scan
    if scan and scan.pending then
        form.marketLine:SetText(T("PG_SELL_SCANNING", "Scanning..."))
        form.marketLine:SetTextColor(0.7, 0.7, 0.75)
        form.flipLine:SetText("")
    elseif scan and scan.reference then
        form.marketLine:SetText(T("PG_SELL_MARKET_MIN", "Market min") .. ": " .. FormatGold(scan.reference))
        form.marketLine:SetTextColor(0.6, 0.85, 0.6)
        if scan.skipped and #scan.skipped > 0 then
            form.flipLine:SetText(string.format(T("PG_SELL_FLIPS_SKIPPED", "Skipped flips: %d (below %s)"), #scan.skipped, FormatGold(scan.skipped[1].price)))
            form.flipLine:SetTextColor(0.95, 0.55, 0.35)
        elseif scan.ourLastPrice and scan.ourLastPrice > 0 then
            form.flipLine:SetText(T("PG_SELL_YOUR_LAST", "Your last price") .. ": " .. FormatGold(scan.ourLastPrice))
            form.flipLine:SetTextColor(1, 0.82, 0.35)
        else
            form.flipLine:SetText("")
        end
    else
        if scan and scan.priceFromDB then
            form.marketLine:SetText(T("PG_SELL_FROM_SCANS", "From scans") .. ": " .. FormatGold(self.sell.price or 0))
            form.marketLine:SetTextColor(0.55, 0.75, 1)
        elseif scan and scan.priceFromLastPost then
            form.marketLine:SetText(T("PG_SELL_YOUR_LAST", "Your last price") .. ": " .. FormatGold(self.sell.price or 0))
            form.marketLine:SetTextColor(1, 0.82, 0.35)
        else
            form.marketLine:SetText(T("PG_SELL_NO_DATA", "No price data"))
            form.marketLine:SetTextColor(0.7, 0.7, 0.75)
        end
        if scan and scan.ourLastPrice and scan.ourLastPrice > 0 and not scan.priceFromLastPost then
            form.flipLine:SetText(T("PG_SELL_YOUR_LAST", "Your last price") .. ": " .. FormatGold(scan.ourLastPrice))
            form.flipLine:SetTextColor(1, 0.82, 0.35)
        else
            form.flipLine:SetText("")
        end
    end

    self:UpdateSellTotals()
end

function S:ShowSellRowMenu(anchor, entry)
    if not entry then return end
    local menuEntries = {
        {
            text = T("PG_SELL_MENU_HIDE", "Hide from sell list"),
            onClick = function() S:AddSellExclusion(entry.itemID) end,
        },
    }

    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(anchor, function(_, root)
            root:SetTag("HIRONCRAFT_PROFIT_SELL_ROW_MENU")
            for _, e in ipairs(menuEntries) do
                root:CreateButton(e.text, e.onClick)
            end
        end)
    elseif EasyMenu then
        local items = {}
        for _, e in ipairs(menuEntries) do
            items[#items + 1] = { text = e.text, func = e.onClick, notCheckable = true }
        end
        local mf = CreateFrame("Frame", "HironCraftProfitSellRowMenuFrame", UIParent, "UIDropDownMenuTemplate")
        EasyMenu(items, mf, "cursor", 0, 0, "MENU")
    end
end

local EXCL_ROW_H = 28

local function ItemNameAndIcon(itemID)
    local name, icon
    if C_Item then
        if C_Item.GetItemInfo then name = (C_Item.GetItemInfo(itemID)) end
        if C_Item.GetItemIconByID then icon = C_Item.GetItemIconByID(itemID) end
    end
    if not name then
        if C_Item and C_Item.RequestLoadItemDataByID then
            C_Item.RequestLoadItemDataByID(itemID)
        end
        name = "item:" .. tostring(itemID)
    end
    return name, icon or 134400
end

local function EnsureExclRows(f, count)
    for i = #f.rows + 1, count do
        local row = CreateFrame("Frame", nil, f.content)
        row:SetSize(10, EXCL_ROW_H - 2)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * EXCL_ROW_H)
        row:SetPoint("RIGHT", f.content, "RIGHT", 0, 0)
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.03 or 0.01)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(20, 20)
        row.icon:SetPoint("LEFT", 6, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.name = MakeText(row, 11, "LEFT")
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.name:SetPoint("RIGHT", -30, 0)
        row.name:SetWordWrap(false)
        row.remove = CreateFrame("Button", nil, row)
        row.remove:SetSize(18, 18)
        row.remove:SetPoint("RIGHT", -6, 0)
        row.remove.tex = row.remove:CreateTexture(nil, "ARTWORK")
        row.remove.tex:SetAllPoints()
        row.remove.tex:SetAtlas("common-icon-redx")
        row.remove.tex:SetAlpha(0.75)
        row.remove:SetScript("OnEnter", function(self) self.tex:SetAlpha(1) end)
        row.remove:SetScript("OnLeave", function(self) self.tex:SetAlpha(0.75) end)
        row.remove:SetScript("OnClick", function(self)
            local r = self:GetParent()
            if r.itemID then S:RemoveSellExclusion(r.itemID) end
        end)
        f.rows[i] = row
    end
end

function S:EnsureSellExclusionsEditor()
    if self.sellExclFrame then return self.sellExclFrame end

    local f = CreateFrame("Frame", "HironCraftProfitSellExclusionsFrame", UIParent, "BackdropTemplate")
    f:SetSize(380, 420)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0.05, 0.05, 0.07, 0.97)
    f:SetBackdropBorderColor(0.85, 0.55, 0.25, 0.8)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "HironCraftProfitSellExclusionsFrame") end

    f.title = MakeText(f, 14, "LEFT")
    f.title:SetPoint("TOPLEFT", 14, -12)
    f.title:SetText(T("PG_SELL_EXCL_TITLE", "Hidden items"))
    f.title:SetTextColor(0.95, 0.8, 0.55)

    f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.close:SetPoint("TOPRIGHT", -4, -4)

    f.listBox = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.listBox:SetPoint("TOPLEFT", 14, -40)
    f.listBox:SetPoint("BOTTOMRIGHT", -14, 48)
    SetBackdrop(f.listBox, 0.4)

    f.scroll = CreateFrame("ScrollFrame", nil, f.listBox)
    f.scroll:SetPoint("TOPLEFT", 6, -6)
    f.scroll:SetPoint("BOTTOMRIGHT", -6, 6)
    f.scroll:EnableMouseWheel(true)
    f.scroll:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll() or 0
        local child = self:GetScrollChild()
        local maxScroll = math.max(0, (child and child:GetHeight() or 0) - self:GetHeight())
        local target = current - (delta * EXCL_ROW_H * 2)
        if target < 0 then target = 0 end
        if target > maxScroll then target = maxScroll end
        self:SetVerticalScroll(target)
    end)
    f.content = CreateFrame("Frame", nil, f.scroll)
    f.content:SetSize(10, 1)
    f.scroll:SetScrollChild(f.content)
    f.rows = {}

    f.empty = MakeText(f, 12, "CENTER")
    f.empty:SetPoint("CENTER", f.listBox, "CENTER", 0, 0)
    f.empty:SetTextColor(0.6, 0.6, 0.6)
    f.empty:SetText(T("PG_SELL_EXCL_EMPTY", "No hidden items"))
    f.empty:Hide()

    f.clearAll = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.clearAll:SetSize(130, 24)
    f.clearAll:SetPoint("BOTTOMLEFT", 14, 14)
    f.clearAll:SetText(T("PG_SELL_EXCL_CLEAR", "Clear all"))
    f.clearAll:SetScript("OnClick", function() S:ClearSellExclusions() end)

    self.sellExclFrame = f
    return f
end

function S:RefreshSellExclusionsEditor()
    local f = self.sellExclFrame
    if not f or not f:IsShown() then return end

    local ids = self:GetSellExclusionIDs()
    EnsureExclRows(f, #ids)
    f.content:SetWidth(math.max(10, f.scroll:GetWidth()))

    for i, itemID in ipairs(ids) do
        local row = f.rows[i]
        row.itemID = itemID
        local name, icon = ItemNameAndIcon(itemID)
        row.icon:SetTexture(icon)
        row.name:SetText(name)
        row:Show()
    end
    for i = #ids + 1, #f.rows do
        f.rows[i].itemID = nil
        f.rows[i]:Hide()
    end
    f.content:SetHeight(math.max(1, #ids * EXCL_ROW_H))
    f.empty:SetShown(#ids == 0)
end

function S:ShowSellExclusionsEditor()
    local f = self:EnsureSellExclusionsEditor()
    f:Show()
    f:Raise()
    self:RefreshSellExclusionsEditor()
end

function S:UpdateSellBindText()
    local f = self.frame
    if not f or not f.sellPanel or not f.sellPanel._built then return end
    local form = f.sellPanel.form
    local function apply(btn, action)
        if not btn or not btn.key then return end
        local b = self.GetSellBinding and self:GetSellBinding(action) or nil
        if b and b ~= "" and _G.GetBindingText then
            btn.key:SetText(_G.GetBindingText(b, "KEY_"))
        else
            btn.key:SetText("")
        end
    end
    apply(form.postBtn, "post")
    apply(form.skipBtn, "skip")
end

local function NormalizeBindingKey(key)
    if not key or key == "" or key == "UNKNOWN" then return nil end
    key = key:upper()
    if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL"
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

function S:CreateSellBindCapture()
    if self.sellBindCapture then return self.sellBindCapture end

    local f = CreateFrame("Frame", "HironCraftProfitSellBindCapture", UIParent, "BackdropTemplate")
    f:SetSize(360, 100)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    f:SetBackdropColor(0.05, 0.05, 0.07, 0.97)
    f:SetBackdropBorderColor(0.35, 0.55, 0.85, 1)
    f:EnableKeyboard(true)
    f:EnableMouse(true)
    f:Hide()

    f.text = MakeText(f, 13, "CENTER")
    f.text:SetPoint("CENTER", 0, 0)
    f.text:SetWidth(320)
    f.text:SetText(T("PG_SELL_BIND_CAPTURE", "Press a key to post the current item.\nEsc — cancel."))

    f:SetScript("OnShow", function(self) self:SetPropagateKeyboardInput(false) end)
    f:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
            return
        end
        local binding = NormalizeBindingKey(key)
        if not binding then return end
        if S.SetSellBinding then S:SetSellBinding(self.captureAction or "post", binding) end
        self:Hide()
    end)
    f:SetScript("OnMouseDown", function(self) self:Hide() end)

    self.sellBindCapture = f
    return f
end

function S:ShowSellBindCapture(action)
    local f = self:CreateSellBindCapture()
    f.captureAction = (action == "skip") and "skip" or "post"
    if f.text then
        f.text:SetText(f.captureAction == "skip"
            and T("PG_SELL_BIND_CAPTURE_SKIP", "Press a key to skip to the next item.\nEsc — cancel.")
            or T("PG_SELL_BIND_CAPTURE", "Press a key to post the current item.\nEsc — cancel."))
    end
    f:Show()
    f:Raise()
end
