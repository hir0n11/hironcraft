local PT = HironCraftProfit
if not PT then return end

PT.ShoppingList = PT.ShoppingList or {}
local S = PT.ShoppingList

local FONT = S.FONT or HironCraftProfit.FONT or STANDARD_TEXT_FONT

local PAD = 12
local ROW_H = 30

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

local function FormatTimeLeft(seconds)
    seconds = seconds or 0
    if seconds >= 86400 then
        return string.format("%dд", math.floor(seconds / 86400))
    elseif seconds >= 3600 then
        return string.format("%dч", math.floor(seconds / 3600))
    elseif seconds >= 60 then
        return string.format("%dм", math.floor(seconds / 60))
    end
    return tostring(seconds) .. "с"
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

local function AuctionNameAndIcon(a)
    local name, icon
    if a.itemLink and C_Item and C_Item.GetItemInfo then
        name = (C_Item.GetItemInfo(a.itemLink))
    end
    if a.itemID and C_Item then
        if not name and C_Item.GetItemInfo then name = (C_Item.GetItemInfo(a.itemID)) end
        if C_Item.GetItemIconByID then icon = C_Item.GetItemIconByID(a.itemID) end
    end
    if not name then
        if a.itemID and C_Item and C_Item.RequestLoadItemDataByID then
            C_Item.RequestLoadItemDataByID(a.itemID)
        end
        name = a.itemLink or ("item:" .. tostring(a.itemID or "?"))
    end
    return name, icon or 134400
end

local function MakeButton(parent, w, label, r, g, b)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(w, 22)
    btn:SetText(label)
    return btn
end

local function EnsureRows(box, count)
    for i = #box.rows + 1, count do
        local row = CreateFrame("Frame", nil, box.content)
        row:SetSize(10, ROW_H - 2)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        row:SetPoint("RIGHT", box.content, "RIGHT", 0, 0)

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(22, 22)
        row.icon:SetPoint("LEFT", 4, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        row.gradeTex = row:CreateTexture(nil, "OVERLAY")
        row.gradeTex:SetSize(12, 12)
        row.gradeTex:SetPoint("TOPLEFT", row.icon, "TOPLEFT", -2, 2)
        row.gradeTex:Hide()

        if S.IsFantasy and S.IsFantasy() then
            row.cancel = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.cancel:SetSize(64, 22)
            row.cancel:SetPoint("RIGHT", -4, 0)
            row.cancel:SetText(T("PG_CANCEL_BTN", "Cancel"))
            row.cancel.label = {
                SetText = function(_, t) row.cancel:SetText(t) end,
                SetTextColor = function() end,
            }
        else
            row.cancel = CreateFrame("Button", nil, row, "BackdropTemplate")
            row.cancel:SetSize(64, 20)
            row.cancel:SetPoint("RIGHT", -4, 0)
            row.cancel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            row.cancel:SetBackdropColor(0.14, 0.08, 0.08, 0.92)
            row.cancel:SetBackdropBorderColor(0.85, 0.35, 0.30, 0.9)
            row.cancel.label = MakeText(row.cancel, 10, "CENTER")
            row.cancel.label:SetPoint("CENTER")
            row.cancel.label:SetText(T("PG_CANCEL_BTN", "Cancel"))
            row.cancel.label:SetTextColor(0.95, 0.7, 0.7)
            row.cancel:SetScript("OnEnter", function(self) self:SetBackdropColor(0.20, 0.10, 0.10, 0.95) end)
            row.cancel:SetScript("OnLeave", function(self) self:SetBackdropColor(0.14, 0.08, 0.08, 0.92) end)
        end
        row.cancel:SetScript("OnClick", function(self)
            if self.auctionID and S.CancelOwnedAuction then S:CancelOwnedAuction(self.auctionID) end
        end)

        row.soldLabel = MakeText(row, 11, "RIGHT")
        row.soldLabel:SetPoint("RIGHT", -8, 0)
        row.soldLabel:SetTextColor(0.55, 0.9, 0.55)

        row.timeLeft = MakeText(row, 11, "RIGHT")
        row.timeLeft:SetPoint("RIGHT", row.cancel, "LEFT", -10, 0)
        row.timeLeft:SetWidth(46)
        row.timeLeft:SetTextColor(0.7, 0.7, 0.75)

        row.status = MakeText(row, 11, "RIGHT")
        row.status:SetPoint("RIGHT", row.timeLeft, "LEFT", -8, 0)
        row.status:SetWidth(120)

        row.price = MakeText(row, 11, "RIGHT")
        row.price:SetPoint("RIGHT", row.status, "LEFT", -8, 0)
        row.price:SetWidth(100)
        row.price:SetTextColor(0.98, 0.86, 0.42)

        row.qty = MakeText(row, 11, "RIGHT")
        row.qty:SetPoint("RIGHT", row.price, "LEFT", -8, 0)
        row.qty:SetWidth(46)

        row.name = MakeText(row, 11, "LEFT")
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.name:SetPoint("RIGHT", row.qty, "LEFT", -8, 0)
        row.name:SetWordWrap(false)

        row:SetScript("OnEnter", function(self)
            if self.itemLink and GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.itemLink)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

        box.rows[i] = row
    end
end

function S:EnsureCancelPanel()
    local f = self.frame
    if not f or not f.cancelPanel then return end
    local panel = f.cancelPanel
    if panel._built then return end
    panel._built = true

    if f.cancelPlaceholder then f.cancelPlaceholder:Hide() end

    local box = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    box:SetPoint("TOPLEFT", PAD, -PAD)
    box:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    SetBackdrop(box, 0.4)
    panel.box = box

    box.title = MakeText(box, 12, "LEFT")
    box.title:SetPoint("TOPLEFT", 8, -8)
    box.title:SetText(T("PG_CANCEL_TITLE", "My auctions"))

    box.refresh = MakeButton(box, 80, T("PG_CANCEL_REFRESH", "Refresh"))
    box.refresh:SetPoint("TOPRIGHT", -8, -6)
    box.refresh:SetScript("OnClick", function()
        if S.cancel then S.cancel.wantScan = true end
        if S.QueryOwnedAuctions then S:QueryOwnedAuctions() end
    end)

    box.scanBtn = MakeButton(box, 130, T("PG_CANCEL_SCAN_BTN", "Scan undercuts"))
    box.scanBtn:SetPoint("RIGHT", box.refresh, "LEFT", -6, 0)
    box.scanBtn:SetScript("OnClick", function()
        if S.StartUndercutScan then S:StartUndercutScan() end
    end)

    box.cancelUndercut = MakeButton(box, 150, T("PG_CANCEL_UNDERCUT_BTN", "Cancel undercut"))
    box.cancelUndercut:SetPoint("RIGHT", box.scanBtn, "LEFT", -6, 0)
    box.cancelUndercut:SetScript("OnClick", function()
        if S.CancelUndercutAuctions then S:CancelUndercutAuctions() end
    end)

    box.cancelAll = MakeButton(box, 100, T("PG_CANCEL_ALL", "Cancel all"))
    box.cancelAll:SetPoint("RIGHT", box.cancelUndercut, "LEFT", -6, 0)
    box.cancelAll:SetScript("OnClick", function()
        if S.CancelAllShownAuctions then S:CancelAllShownAuctions() end
    end)

    box.hName = MakeText(box, 10, "LEFT")
    box.hName:SetPoint("TOPLEFT", 36, -34)
    box.hName:SetText(T("PG_CANCEL_COL_ITEM", "Item"))
    box.hName:SetTextColor(0.6, 0.6, 0.65)

    box.scroll = CreateFrame("ScrollFrame", nil, box)
    box.scroll:SetPoint("TOPLEFT", 6, -50)
    box.scroll:SetPoint("BOTTOMRIGHT", -6, 30)
    box.scroll:EnableMouseWheel(true)
    box.scroll:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll() or 0
        local child = self:GetScrollChild()
        local maxScroll = math.max(0, (child and child:GetHeight() or 0) - self:GetHeight())
        local target = current - (delta * ROW_H * 2)
        if target < 0 then target = 0 end
        if target > maxScroll then target = maxScroll end
        self:SetVerticalScroll(target)
    end)
    box.content = CreateFrame("Frame", nil, box.scroll)
    box.content:SetSize(10, 1)
    box.scroll:SetScrollChild(box.content)
    box.rows = {}

    box.empty = MakeText(box, 11, "CENTER")
    box.empty:SetPoint("CENTER", 0, 14)
    box.empty:SetText(T("PG_CANCEL_EMPTY", "No active auctions"))
    box.empty:Hide()

    box.footer = MakeText(box, 11, "LEFT")
    box.footer:SetPoint("BOTTOMLEFT", 10, 9)
    box.footer:SetPoint("RIGHT", -10, 0)

    if PT.RestyleButtons then PT:RestyleButtons(panel, 12) end
end

function S:RefreshCancelUI()
    self:EnsureCancelPanel()
    local f = self.frame
    if not f or not f.cancelPanel or not f.cancelPanel._built then return end

    local box = f.cancelPanel.box
    local active = self.cancel.auctions or {}
    local sold = self.cancel.sold or {}

    local display = {}
    for _, a in ipairs(active) do display[#display + 1] = { a = a, sold = false } end
    for _, a in ipairs(sold) do display[#display + 1] = { a = a, sold = true } end

    box.content:SetWidth(math.max(10, box.scroll:GetWidth()))
    EnsureRows(box, #display)

    for i, item in ipairs(display) do
        local row = box.rows[i]
        local a = item.a
        row.auctionID = a.auctionID
        row.itemLink = a.itemLink
        local name, icon = AuctionNameAndIcon(a)
        row.icon:SetTexture(icon)
        local gradeAtlas = QualityTierAtlas(a.itemID)
        if gradeAtlas and row.gradeTex.SetAtlas then
            row.gradeTex:SetAtlas(gradeAtlas)
            row.gradeTex:Show()
        else
            row.gradeTex:Hide()
        end
        row.name:SetText(name)
        row.qty:SetText("x" .. tostring(a.quantity or 1))
        row.price:SetText(FormatGold(a.unitPrice))

        if item.sold then
            row.bg:SetColorTexture(0.10, 0.20, 0.10, 0.35)
            row.cancel:Hide()
            row.timeLeft:SetText("")
            row.status:SetText("")
            row.soldLabel:Show()
            row.soldLabel:SetText(T("PG_CANCEL_SOLD", "Sold") .. " " .. FormatGold(a.totalPrice or 0))
        else
            row.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.03 or 0.01)
            row.soldLabel:Hide()
            row.timeLeft:SetText(FormatTimeLeft(a.timeLeft))

            local undercut = S.IsAuctionUndercut and S:IsAuctionUndercut(a)
            if undercut then
                local cm = self.cancel.undercut[a.itemID]
                row.status:SetText("|cffff5555" .. T("PG_CANCEL_UNDERCUT_MARK", "undercut") .. " " .. FormatGold(cm) .. "|r")
            else
                row.status:SetText("")
            end

            row.cancel:Show()
            row.cancel.auctionID = a.auctionID
            if a.cancelling then
                row.cancel:Disable()
                row.cancel.label:SetText(T("PG_CANCEL_PENDING", "..."))
                row.cancel.label:SetTextColor(0.5, 0.5, 0.5)
            else
                row.cancel:Enable()
                row.cancel.label:SetText(T("PG_CANCEL_BTN", "Cancel"))
                row.cancel.label:SetTextColor(0.95, 0.7, 0.7)
            end
        end
        row:Show()
    end
    for i = #display + 1, #box.rows do
        box.rows[i].auctionID = nil
        box.rows[i]:Hide()
    end
    box.content:SetHeight(math.max(1, #display * ROW_H))

    local pending = self.cancel.pending
    box.empty:SetShown(not pending and #display == 0)

    local scan = self.cancel.scan
    local footer = T("PG_CANCEL_TOTAL_ONSALE", "On sale: %s"):format(FormatGold(self.cancel.totalOnSale or 0))
        .. "   " .. T("PG_CANCEL_TOTAL_SOLD", "Sold: %s"):format(FormatGold(self.cancel.totalSold or 0))
    if scan and scan.active then
        footer = footer .. "   |cff88aaff" .. T("PG_CANCEL_SCAN_PROGRESS", "Scanning %d/%d"):format(scan.index or 0, #(scan.queue or {})) .. "|r"
    end
    box.footer:SetText(footer)

    local remainingShown = (S.CountUncancelledShown and S:CountUncancelledShown()) or #active
    local remainingUndercut = (S.CountUncancelledUndercut and S:CountUncancelledUndercut()) or 0
    box.cancelAll:SetText(remainingShown > 0
        and string.format("%s (%d)", T("PG_CANCEL_ALL", "Cancel all"), remainingShown)
        or T("PG_CANCEL_ALL", "Cancel all"))
    box.cancelUndercut:SetText(remainingUndercut > 0
        and string.format("%s (%d)", T("PG_CANCEL_UNDERCUT_BTN", "Cancel undercut"), remainingUndercut)
        or T("PG_CANCEL_UNDERCUT_BTN", "Cancel undercut"))
    box.cancelAll:SetEnabled(remainingShown > 0)
    box.cancelUndercut:SetEnabled(remainingUndercut > 0)
    box.scanBtn:SetEnabled(#active > 0 and not (scan and scan.active))
end
