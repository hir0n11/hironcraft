local E = _G.HironCraftProfitCraftingOrdersEnv
if not E then
    E = {}
    _G.HironCraftProfitCraftingOrdersEnv = E
    setmetatable(E, { __index = _G })
end
setfenv(1, E)
if not PT or not CO then return end

local QUESTION_MARK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local function SafeCall(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h, i, j = pcall(func, ...)
    if ok then return a, b, c, d, e, f, g, h, i, j end
    return nil
end

local function GetItemIDFromLinkOrValue(value)
    if type(value) == "number" then return value end
    if type(value) == "string" then
        local id = value:match("item:(%d+)") or value:match("Hitem:(%d+)")
        return tonumber(id)
    end
    return nil
end

local function GetInstantItemIcon(item)
    if not item then return nil end

    if GetItemInfoInstant then
        local _, _, _, _, icon = SafeCall(GetItemInfoInstant, item)
        if icon then return icon end
    end

    if C_Item and C_Item.GetItemInfoInstant then
        local result = SafeCall(C_Item.GetItemInfoInstant, item)
        if type(result) == "table" then
            return result.iconFileID or result.icon or result.texture
        end

        local _, _, _, _, icon = SafeCall(C_Item.GetItemInfoInstant, item)
        if icon then return icon end
    end

    return nil
end

local function GetLoadedItemIcon(item)
    if not item then return nil end

    if C_Item and C_Item.GetItemInfo then
        local _, _, _, _, _, _, _, _, _, icon = SafeCall(C_Item.GetItemInfo, item)
        if icon then return icon end
    end

    if GetItemInfo then
        local _, _, _, _, _, _, _, _, _, icon = SafeCall(GetItemInfo, item)
        if icon then return icon end
    end

    return nil
end

local function ResolveItemIcon(itemID, itemLink)
    local icon

    if itemLink then
        icon = GetInstantItemIcon(itemLink) or GetLoadedItemIcon(itemLink)
        if icon then return icon end
    end

    if itemID then
        if C_Item and C_Item.GetItemIconByID then
            icon = SafeCall(C_Item.GetItemIconByID, itemID)
            if icon then return icon end
        end

        if GetItemTexture then
            icon = SafeCall(GetItemTexture, itemID)
            if icon then return icon end
        end

        icon = GetInstantItemIcon(itemID) or GetLoadedItemIcon(itemID)
        if icon then return icon end
    end

    return nil
end

local function RequestRewardItemLoad(itemID, itemLink)
    if itemID and C_Item and C_Item.RequestLoadItemDataByID then
        SafeCall(C_Item.RequestLoadItemDataByID, itemID)
    end

    if itemLink and C_Item and C_Item.RequestLoadItemData then
        SafeCall(C_Item.RequestLoadItemData, itemLink)
    end
end

local function QueueRewardsFrameRefresh(frame, itemID, itemLink)
    if not frame or not C_Timer or not C_Timer.After then return end

    RequestRewardItemLoad(itemID, itemLink)

    frame.ahuiRewardRefreshRetries = (frame.ahuiRewardRefreshRetries or 0) + 1
    if frame.ahuiRewardRefreshRetries > 6 then return end

    frame.ahuiRewardRefreshToken = (frame.ahuiRewardRefreshToken or 0) + 1
    local token = frame.ahuiRewardRefreshToken
    local delay = math.min(1.0, 0.12 + frame.ahuiRewardRefreshRetries * 0.12)

    C_Timer.After(delay, function()
        if not frame or frame.ahuiRewardRefreshToken ~= token then return end
        if not frame:IsShown() then return end

        local order = frame.order
        if order and CO and CO.UpdateRewardsFrame then
            CO:UpdateRewardsFrame(frame, order)
        end
    end)
end

local function ResolveRewardItemID(reward)
    if type(reward) ~= "table" then return nil end

    local itemID = tonumber(reward.itemID or reward.itemId or reward.itemTypeID or reward.itemTypeId)
    if itemID then return itemID end

    return GetItemIDFromLinkOrValue(reward.itemLink or reward.link)
end

function CO:UpdateRewardsFrame(frame, order)
    if not frame or not order then return end

    frame.order = order
    local orderKey = order.orderID or order.spellID or order.skillLineAbilityID
    if frame.ahuiRewardOrderKey ~= orderKey then
        frame.ahuiRewardOrderKey = orderKey
        frame.ahuiRewardRefreshRetries = 0
        frame.ahuiRewardRefreshToken = (frame.ahuiRewardRefreshToken or 0) + 1
    end

    frame.icons = frame.icons or {}
    for _, icon in ipairs(frame.icons) do icon:Hide() end

    local index = 1
    local iconAreaWidth = math.max(MINI_ICON_SIZE, (frame:GetWidth() or REWARDS_COLUMN_W) - PROFIT_COLUMN_W - 4)
    local needsRefresh = false

    local function SetupIcon(texture, count, tooltipFunc, itemID, itemLink)
        if index > MAX_REWARD_ICONS then return end
        local nextRight = (index - 1) * (MINI_ICON_SIZE + 1) + MINI_ICON_SIZE
        if nextRight > iconAreaWidth then return end

        local iconTexture = texture or QUESTION_MARK_ICON
        if iconTexture == QUESTION_MARK_ICON and (itemID or itemLink) then
            needsRefresh = true
            QueueRewardsFrameRefresh(frame, itemID, itemLink)
        end

        local icon = frame.icons[index]
        if not icon then
            icon = self:CreateMiniIcon(frame)
            frame.icons[index] = icon
        end
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", frame, "LEFT", (index - 1) * (MINI_ICON_SIZE + 1), 0)
        icon.icon:SetTexture(iconTexture)
        icon.icon:SetDesaturated(false)
        icon.icon:SetVertexColor(1, 1, 1, 1)
        icon.count:SetText(count and count > 1 and tostring(count) or "")
        icon.grade:SetText("")
        if icon.qualityBadge then icon.qualityBadge:Hide() end
        if icon.qualityOutline then icon.qualityOutline:Hide() end
        if icon.missingX then icon.missingX:Hide() end
        icon:SetAlpha(1)
        icon:SetBackdropBorderColor(0.95, 0.78, 0.35, 0.8)
        icon:SetScript("OnEnter", tooltipFunc)
        icon:SetScript("OnLeave", GameTooltip_Hide)
        icon:Show()
        index = index + 1
    end

    if order.tipAmount and order.tipAmount > 0 then
        SetupIcon("Interface\\MoneyFrame\\UI-GoldIcon", nil, function(self)
            GameTooltip:SetOwner(self, "ANCHOR_NONE")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(T("COA_REWARD_COMMISSION", "Commission") .. ": " .. FormatCopperShort(order.tipAmount) .. "g", 1, 0.82, 0.35)
            ShowGameTooltipCursorRightOrBelow()
        end)
    end

    local rewards = order.npcOrderRewards or order.rewards or {}
    for _, reward in ipairs(rewards) do
        if index > MAX_REWARD_ICONS then break end

        local itemID = ResolveRewardItemID(reward)
        local itemLink = reward.itemLink or reward.link

        if itemLink or itemID then
            local texture = ResolveItemIcon(itemID, itemLink)
            SetupIcon(texture, reward.count or reward.quantity, function(self)
                GameTooltip:SetOwner(self, "ANCHOR_NONE")
                GameTooltip:ClearLines()

                local link = itemLink
                if (not link) and itemID and C_Item and C_Item.GetItemInfo then
                    local _, loadedLink = SafeCall(C_Item.GetItemInfo, itemID)
                    link = loadedLink
                end
                if link then
                    GameTooltip:SetHyperlink(link)
                else
                    local itemName
                    if itemID and C_Item and C_Item.GetItemInfo then
                        itemName = SafeCall(C_Item.GetItemInfo, itemID)
                    elseif itemID and GetItemInfo then
                        itemName = SafeCall(GetItemInfo, itemID)
                    end
                    GameTooltip:AddLine(itemName or ("Item " .. tostring(itemID or "?")))
                end

                ShowGameTooltipCursorRightOrBelow()
            end, itemID, itemLink)
        elseif reward.currencyType then
            local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(reward.currencyType)
            SetupIcon(info and info.iconFileID or "Interface\\Icons\\INV_Misc_Coin_01", reward.count, function(self)
                GameTooltip:SetOwner(self, "ANCHOR_NONE")
                GameTooltip:ClearLines()
                if GameTooltip.SetCurrencyByID then
                    GameTooltip:SetCurrencyByID(reward.currencyType, reward.count)
                else
                    GameTooltip:AddLine(info and info.name or ("Currency " .. tostring(reward.currencyType)))
                end
                ShowGameTooltipCursorRightOrBelow()
            end)
        end
    end

    if not needsRefresh then
        frame.ahuiRewardRefreshRetries = 0
    end
end

function CO:OpenReagentMixPicker(owner, order, reagentEntry)
    if not owner or not order or not reagentEntry then return end
    local key = MakeReagentSelectionKeyForEntry(order.orderID, reagentEntry)
    if not key then return end
    local required = tonumber(reagentEntry.quantity) or 0
    if required <= 0 then return end

    local candidates = self:GetReagentCandidates(order, reagentEntry) or {}
    table.sort(candidates, function(a, b)
        return (tonumber(self:GetQueueReagentCandidateTier(a)) or 0) < (tonumber(self:GetQueueReagentCandidateTier(b)) or 0)
    end)
    if #candidates == 0 then return end

    local counts = {}
    local sel = self.selectedReagents[key]
    if sel and type(sel.mix) == "table" then
        for _, p in ipairs(sel.mix) do counts[p.itemID] = (counts[p.itemID] or 0) + (p.quantity or 0) end
    elseif sel and sel.itemID then
        counts[sel.itemID] = tonumber(sel.quantity) or required
    end

    local f = self._mixPicker
    if not f then
        f = CreateFrame("Frame", "HironCraftProfitOrderReagentMixPicker", UIParent, "BackdropTemplate")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        CreateBackdrop(f, 0.97)
        f:SetBackdropBorderColor(0.694, 0.612, 0.851, 1)
        f:EnableMouse(true)
        f.rows = {}
        f.title = f:CreateFontString(nil, "OVERLAY"); ApplyFont(f.title, 12, "")
        f.title:SetPoint("TOPLEFT", 10, -8); f.title:SetTextColor(1, 0.82, 0.35, 1)
        f.total = f:CreateFontString(nil, "OVERLAY"); ApplyFont(f.total, 11, "")
        f.total:SetPoint("BOTTOMLEFT", 10, 8)
        f.autoBtn = self:CreateTextButton(f, nil, 54, 18, T("COA_REAGENT_AUTO", "Авто"))
        f.autoBtn:SetPoint("BOTTOMRIGHT", -8, 6)
        f:SetScript("OnEvent", function(self2, event)
            if event == "GLOBAL_MOUSE_DOWN" and not self2:IsMouseOver() then self2:Hide() end
        end)
        f:SetScript("OnHide", function(self2) self2:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)
        self._mixPicker = f
    end

    local function totalCount() local t = 0; for _, c in pairs(counts) do t = t + c end; return t end
    local function refreshTotal()
        local t = totalCount()
        f.total:SetText(string.format(T("COA_MIX_TOTAL", "итого: %d / %d"), t, required))
        local ok = t == required
        f.total:SetTextColor(ok and 0.35 or 1, ok and 0.95 or 0.82, ok and 0.45 or 0.35, 1)
    end
    local function apply()
        local mix = {}
        for _, cand in ipairs(candidates) do
            local c = counts[cand.itemID] or 0
            if c > 0 then
                mix[#mix + 1] = {
                    itemID = cand.itemID, quantity = c,
                    slotIndex = reagentEntry.slotIndex or reagentEntry.dataSlotIndex,
                    dataSlotIndex = reagentEntry.dataSlotIndex,
                    qualityTier = self:GetQueueReagentCandidateTier(cand),
                }
            end
        end
        if #mix == 0 then
            self:SetSelectedReagentForEntry(order.orderID, reagentEntry, nil)
        else
            self.selectedReagents[key] = {
                slotIndex = reagentEntry.slotIndex or reagentEntry.dataSlotIndex,
                dataSlotIndex = reagentEntry.dataSlotIndex,
                quantity = required, itemID = mix[1].itemID, qualityTier = mix[1].qualityTier, mix = mix,
            }
            self:InvalidateOrderCaches(order.orderID)
        end
        self:RefreshVisibleRowsSoon()
        if self.CustomList and self.CustomList.Refresh and self.activePageFrame then
            self.CustomList:Refresh(self.activePageFrame)
        end
    end

    local y = -26
    for i, cand in ipairs(candidates) do
        local row = f.rows[i]
        if not row then
            row = CreateFrame("Frame", nil, f)
            row:SetSize(196, 22)
            row.badgeBtn = CreateFrame("Button", nil, row)
            row.badgeBtn:SetSize(18, 18); row.badgeBtn:SetPoint("LEFT", 2, 0)
            row.badge = row.badgeBtn:CreateTexture(nil, "ARTWORK"); row.badge:SetAllPoints()
            row.badgeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row.plus = self:CreateTextButton(row, nil, 20, 18, "+"); row.plus:SetPoint("RIGHT", -2, 0)
            row.count = row:CreateFontString(nil, "OVERLAY"); ApplyFont(row.count, 12, ""); row.count:SetPoint("RIGHT", row.plus, "LEFT", -3, 0); row.count:SetWidth(22); row.count:SetJustifyH("CENTER")
            row.minus = self:CreateTextButton(row, nil, 20, 18, "−"); row.minus:SetPoint("RIGHT", row.count, "LEFT", -3, 0)
            f.rows[i] = row
        end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 8, y); row:SetPoint("RIGHT", f, "RIGHT", -8, 0)
        local tier = self:GetQueueReagentCandidateTier(cand)
        local atlas = GetProfessionQualityAtlas(tier, cand.maxQualityTier, cand.expansionID, cand.qualityKind)
        if atlas then row.badge:SetAtlas(atlas, true); row.badge:Show() else row.badge:Hide() end
        row.badgeBtn:SetScript("OnEnter", function(self2)
            if not cand.itemID or not GameTooltip.SetItemByID then return end
            GameTooltip:SetOwner(self2, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(cand.itemID)
            GameTooltip:Show()
        end)
        row.count:SetText(tostring(counts[cand.itemID] or 0))
        row.minus:SetScript("OnClick", function()
            local c = counts[cand.itemID] or 0
            if c > 0 then counts[cand.itemID] = c - 1; row.count:SetText(tostring(c - 1)); refreshTotal(); apply() end
        end)
        row.plus:SetScript("OnClick", function()
            if totalCount() < required then
                local c = (counts[cand.itemID] or 0) + 1; counts[cand.itemID] = c; row.count:SetText(tostring(c)); refreshTotal(); apply()
            end
        end)
        row:Show()
        y = y - 22
    end
    for i = #candidates + 1, #f.rows do f.rows[i]:Hide() end

    f.autoBtn:SetScript("OnClick", function()
        for k in pairs(counts) do counts[k] = nil end
        for i = 1, #candidates do if f.rows[i] then f.rows[i].count:SetText("0") end end
        refreshTotal(); apply()
    end)

    f.title:SetText((C_Item.GetItemInfo(reagentEntry.itemID)) or T("COA_MIX_TITLE", "Микс грейдов"))
    f.title:SetWidth(128); f.title:SetWordWrap(false)
    refreshTotal()
    f:SetSize(150, 26 + #candidates * 22 + 34)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    f:Show()
    f:Raise()
    f:RegisterEvent("GLOBAL_MOUSE_DOWN")
end

function CO:OpenReagentMenu(owner, order, reagentEntry)
    if not owner or not order or not reagentEntry then return end

    if (self.GetQueueReagentMode and self:GetQueueReagentMode()) == "manual" then
        return self:OpenReagentMixPicker(owner, order, reagentEntry)
    end

    local slotIndex = reagentEntry.slotIndex or GetOrderReagentSlotIndex(reagentEntry) or reagentEntry.dataSlotIndex
    local candidates = self:GetReagentCandidates(order, reagentEntry)
    local current = self:GetSelectedReagentForEntry(order.orderID, reagentEntry)

    local items = {
        {
            text = T("COA_REAGENT_AUTO", "Auto"),
            checked = current == nil,
            onClick = function()
                CO:SetSelectedReagentForEntry(order.orderID, reagentEntry, nil)
                CO:SetStatus(T("COA_STATUS_REAGENT_AUTO", "Reagent selection: auto."))
            end,
        },
    }

    for i, candidate in ipairs(candidates) do
        local itemName, itemLink, _, itemQuality, _, _, _, _, _, texture = C_Item.GetItemInfo(candidate.itemID)
        local text = string.format(T("COA_REAGENT_QUALITY_FMT", "Q%d"), candidate.qualityTier or i)
        if itemName then text = text .. " - " .. itemName else text = text .. " - " .. tostring(candidate.itemID) end
        local selected = current and current.itemID == candidate.itemID
        items[#items + 1] = {
            text = text,
            icon = texture or GetItemTexture(candidate.itemID),
            checked = selected,
            onClick = function()
                CO:SetSelectedReagentForEntry(order.orderID, reagentEntry, {
                    itemID = candidate.itemID,
                    quantity = reagentEntry.quantity or candidate.quantity or 0,
                    slotIndex = slotIndex,
                    dataSlotIndex = reagentEntry.dataSlotIndex or candidate.dataSlotIndex,
                    qualityTier = candidate.qualityTier,
                    maxQualityTier = candidate.maxQualityTier,
                    expansionID = candidate.expansionID,
                    qualityKind = candidate.qualityKind,
                })
                CO:SetStatus(T("COA_STATUS_REAGENT_SELECTED", "Reagent selected.") .. " " .. (itemName or tostring(candidate.itemID)))
            end,
        }
    end

    if PT.Dropdown and PT.Dropdown.Show then
        PT.Dropdown:Show({ owner = owner, items = items })
        return
    end

    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
            rootDescription:SetTag("HIRONCRAFT_PROFIT_CRAFTING_ORDER_REAGENT")
            for _, item in ipairs(items) do
                local text, onClick = item.text, item.onClick
                rootDescription:CreateButton(text, onClick)
            end
        end)
    end
end

function CO:GetReagentDisplayQuality(order, reagentEntry, selected, displayItemID)
    local tier = selected and selected.qualityTier
    local maxTier = selected and selected.maxQualityTier
    local expansionID = selected and selected.expansionID
    local qualityKind = selected and selected.qualityKind

    if not tier and reagentEntry then
        tier = reagentEntry.qualityTier
        maxTier = reagentEntry.maxQualityTier
        expansionID = reagentEntry.expansionID
        qualityKind = reagentEntry.qualityKind
    end

    if not tier then
        tier = ReadProfessionQualityFromItem(displayItemID)
    end

    if not expansionID then
        expansionID = ReadItemExpansionID(displayItemID)
    end

    if not qualityKind then
        qualityKind = DetermineProfessionQualityKind(nil, displayItemID)
    end

    if not maxTier and expansionID and expansionID >= 11 and qualityKind ~= "item" and tier and tier <= 2 then
        maxTier = 2
    end

    if not maxTier and tier then
        maxTier = qualityKind == "item" and (tier >= 4 and 5 or nil) or (tier <= 3 and 3 or nil)
    end

    return tier, maxTier, expansionID, qualityKind
end


function CO:GetDisplayableCrafterReagentCount(order)
    if not order then return 0 end

    local count = 0
    local seenSlots = {}
    for _, reagentEntry in ipairs(self:BuildDisplayReagents(order)) do
        if reagentEntry.itemID and IsCrafterProvidedReagent(reagentEntry) then
            local slotKey = MakeReagentSelectionKeyForEntry(order.orderID, reagentEntry)
            if not (slotKey and seenSlots[slotKey]) then
                if slotKey then seenSlots[slotKey] = true end
                count = count + 1
            end
        end
    end

    return count
end

function CO:OrderNeedsTallReagentRow(order)
    return true
end

function CO:GetOrderRowBaseExtent(pageFrame)
    local base = pageFrame and tonumber(pageFrame.ahuiOrderBaseRowExtent)
    if base and base > 0 then return base end
    return ROW_BUTTON_H + 4
end

function CO:GetOrderRowExtent(pageFrame, elementData)
    local order = elementData and (elementData.option or elementData.order or elementData)
    local base = self:GetOrderRowBaseExtent(pageFrame)
    if order and order.orderID and self:OrderNeedsTallReagentRow(order) then
        return math.max(base, ORDER_ROW_TALL_H)
    end
    return base
end

function CO:InstallOrderRowExtentCalculator(pageFrame)
    pageFrame = pageFrame or self.activePageFrame or self:FindOrderPageFrame()
    local scrollBox = pageFrame and pageFrame.BrowseFrame and pageFrame.BrowseFrame.OrderList and pageFrame.BrowseFrame.OrderList.ScrollBox
    local view = scrollBox and scrollBox.GetView and scrollBox:GetView()
    if not view then return false end

    if view.SetElementExtentCalculator then
        if not pageFrame.ahuiOrderExtentCalculatorInstalled then
            view:SetElementExtentCalculator(function(dataIndex, elementData)
                return CO:GetOrderRowExtent(pageFrame, elementData)
            end)
            pageFrame.ahuiOrderExtentCalculatorInstalled = true
        end
        return true
    end

    if view.SetElementExtent then
        local extent = pageFrame.ahuiOrderHasTallRows and math.max(self:GetOrderRowBaseExtent(pageFrame), ORDER_ROW_TALL_H) or self:GetOrderRowBaseExtent(pageFrame)
        pcall(view.SetElementExtent, view, extent)
        return true
    end

    return false
end

function CO:QueueOrderListLayoutRefresh(pageFrame)
    if self.rowHeightLayoutRefreshQueued then return end
    self.rowHeightLayoutRefreshQueued = true

    local function run()
        CO.rowHeightLayoutRefreshQueued = nil
        pageFrame = pageFrame or CO.activePageFrame or CO:FindOrderPageFrame()
        local scrollBox = pageFrame and pageFrame.BrowseFrame and pageFrame.BrowseFrame.OrderList and pageFrame.BrowseFrame.OrderList.ScrollBox
        if not scrollBox then return end

        CO:InstallOrderRowExtentCalculator(pageFrame)

        if scrollBox.FullUpdate then
            pcall(scrollBox.FullUpdate, scrollBox)
        elseif scrollBox.Update then
            pcall(scrollBox.Update, scrollBox)
        elseif scrollBox.RecalculateDerivedExtent then
            pcall(scrollBox.RecalculateDerivedExtent, scrollBox)
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, run)
    else
        run()
    end
end

function FormatReagentOwnedText(owned, required)
    return string.format(T("COA_REAGENT_OWNED_FMT", "Owned: %d / %d"), tonumber(owned) or 0, tonumber(required) or 0)
end

function FormatReagentMissingText(missing)
    return string.format(T("COA_REAGENT_MISSING_FMT", "Missing: %d"), math.max(0, tonumber(missing) or 0))
end

function CO:GetDisplayedReagentAvailability(displayItemID, quantity)
    quantity = math.floor(tonumber(quantity) or 0)
    if not displayItemID or quantity <= 0 then
        return true, 0, quantity, 0
    end

    local owned = self:GetItemCountForShopping(displayItemID)
    local missing = math.max(0, quantity - owned)
    return missing <= 0, owned, quantity, missing
end

function CO:ApplyOrderRowHeight(row, order, pageFrame)
    if not row or not order then return false end

    pageFrame = pageFrame or self.activePageFrame or self:FindOrderPageFrame(row)
    local tall = self:OrderNeedsTallReagentRow(order)
    local observedHeight = row.GetHeight and row:GetHeight()
    local baseHeight = pageFrame and tonumber(pageFrame.ahuiOrderBaseRowExtent)

    if not row.ahuiOrderOriginalHeight then
        if observedHeight and observedHeight > 0 and (not tall or observedHeight < ORDER_ROW_TALL_H) then
            row.ahuiOrderOriginalHeight = observedHeight
        else
            row.ahuiOrderOriginalHeight = baseHeight or (ROW_BUTTON_H + 4)
        end
    end

    if pageFrame and row.ahuiOrderOriginalHeight and row.ahuiOrderOriginalHeight > 0 and row.ahuiOrderOriginalHeight < ORDER_ROW_TALL_H then
        pageFrame.ahuiOrderBaseRowExtent = row.ahuiOrderOriginalHeight
    end

    local targetHeight = tall and math.max(self:GetOrderRowBaseExtent(pageFrame), ORDER_ROW_TALL_H) or self:GetOrderRowBaseExtent(pageFrame)
    local currentHeight = row.GetHeight and row:GetHeight() or 0
    local changed = false

    if targetHeight and targetHeight > 0 and math.abs((currentHeight or 0) - targetHeight) > 0.5 then
        row:SetHeight(targetHeight)
        changed = true
    end

    row.ahuiOrderTallRow = tall == true
    if pageFrame and tall then
        pageFrame.ahuiOrderHasTallRows = true
    end

    if row.cells then
        for _, cell in ipairs(row.cells) do
            if cell and cell.SetHeight then
                if not cell.ahuiOrderOriginalHeight then
                    local h = cell.GetHeight and cell:GetHeight()
                    if h and h > 0 and (not tall or h < ORDER_ROW_TALL_H) then
                        cell.ahuiOrderOriginalHeight = h
                    else
                        cell.ahuiOrderOriginalHeight = self:GetOrderRowBaseExtent(pageFrame)
                    end
                end
                if targetHeight and targetHeight > 0 then
                    cell:SetHeight(targetHeight)
                end
            end
        end
    end

    self:InstallOrderRowExtentCalculator(pageFrame)
    if changed then
        self:QueueOrderListLayoutRefresh(pageFrame)
    end

    return tall
end

function CO:UpdateReagentsFrame(frame, order)
    if not frame or not order then return end

    frame.order = order
    frame:EnableMouse(CO.reagentDebugEnabled == true)
    frame:SetScript("OnMouseUp", function(self, mouseButton)
        if CO.reagentDebugEnabled and mouseButton == "RightButton" and IsAltKeyDown and IsAltKeyDown() and CO.DebugDumpOrder then
            CO.debugLastOrder = self.order
            CO:DebugDumpOrder(self.order, "alt-right reagent frame")
        end
    end)

    frame.icons = frame.icons or {}
    for _, icon in ipairs(frame.icons) do
        if icon.qualityBadge then icon.qualityBadge:Hide() end
        if icon.qualityOutline then icon.qualityOutline:Hide() end
        if icon.missingX then icon.missingX:Hide() end
        if icon.icon then
            icon.icon:SetDesaturated(false)
            icon.icon:SetVertexColor(1, 1, 1, 1)
        end
        icon:SetAlpha(1)
        icon:Hide()
    end
    if frame.moreText then frame.moreText:SetText("") end

    local reagents = self:BuildDisplayReagents(order)
    local displayable = {}
    local displayableSlots = {}

    for _, reagentEntry in ipairs(reagents) do
        if IsCrafterProvidedReagent(reagentEntry) and reagentEntry.itemID then
            local slotKey = MakeReagentSelectionKeyForEntry(order.orderID, reagentEntry)
            if not (slotKey and displayableSlots[slotKey]) then
                if slotKey then displayableSlots[slotKey] = true end
                displayable[#displayable + 1] = reagentEntry
            end
        end
    end

    if CO.reagentDebugEnabled then
        if not frame.debugText then
            frame.debugText = frame:CreateFontString(nil, "OVERLAY")
            frame.debugText.ahuiCraftingOrdersOwned = true
            ApplyFont(frame.debugText, 8, "OUTLINE")
            frame.debugText:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 8)
            frame.debugText:SetTextColor(0.35, 0.85, 1, 1)
        end
        frame.debugText:SetText("DBG raw=" .. tostring(type(order.reagents) == "table" and #order.reagents or "nil") .. " show=" .. tostring(#displayable))
        frame.debugText:Show()
    elseif frame.debugText then
        frame.debugText:Hide()
    end

    local twoRows = #displayable > REAGENT_TWO_ROW_THRESHOLD
    local iconSize = twoRows and REAGENT_TWO_ROW_ICON_SIZE or MINI_ICON_SIZE
    local gapX = twoRows and REAGENT_TWO_ROW_GAP_X or 1
    local gapY = twoRows and REAGENT_TWO_ROW_GAP_Y or 0
    local badgeSize = twoRows and REAGENT_TWO_ROW_BADGE_SIZE or REAGENT_QUALITY_BADGE_SIZE
    local columns = twoRows and REAGENT_TWO_ROW_COLUMNS or MAX_REAGENT_ICONS
    local maxShown = twoRows and math.min(MAX_REAGENT_ICONS, REAGENT_TWO_ROW_COLUMNS * 2) or MAX_REAGENT_ICONS
    local totalWidth = columns * iconSize + math.max(0, columns - 1) * gapX
    local startX = twoRows and math.max(0, math.floor(((frame:GetWidth() or REAGENTS_COLUMN_W) - totalWidth) * 0.5)) or 0
    local topY = twoRows and math.floor((iconSize + gapY) * 0.5) or 0

    local shown = 0

    for _, reagentEntry in ipairs(displayable) do
        if shown >= maxShown then break end

        local itemID = reagentEntry.itemID
        if itemID then
            shown = shown + 1
            local icon = frame.icons[shown]
            if not icon then
                icon = self:CreateMiniIcon(frame)
                frame.icons[shown] = icon
            end

            ResizeMiniIcon(icon, iconSize, badgeSize)

            local selected = self:GetSelectedReagentForEntry(order.orderID, reagentEntry)
            local displayItemID = selected and selected.itemID or itemID
            local texture = GetItemTexture(displayItemID) or "Interface\\Icons\\INV_Misc_QuestionMark"
            local quantity = (selected and selected.quantity) or reagentEntry.quantity or 0
            local providedByCustomer = IsCustomerProvidedReagent(reagentEntry)
            local selectable = IsCrafterProvidedReagent(reagentEntry)

            icon:ClearAllPoints()
            if twoRows then
                local zeroIndex = shown - 1
                local col = zeroIndex % REAGENT_TWO_ROW_COLUMNS
                local rowIndex = math.floor(zeroIndex / REAGENT_TWO_ROW_COLUMNS)
                local x = startX + col * (iconSize + gapX)
                local y = rowIndex == 0 and topY or -topY
                icon:SetPoint("CENTER", frame, "LEFT", x + iconSize * 0.5, y)
            else
                icon:SetPoint("LEFT", frame, "LEFT", (shown - 1) * (iconSize + gapX), 0)
            end

            icon.icon:SetTexture(texture)
            icon.icon:SetDesaturated(false)
            icon.icon:SetVertexColor(1, 1, 1, 1)
            icon:SetAlpha(1)
            if icon.missingX then icon.missingX:Hide() end
            if icon.qualityOutline then icon.qualityOutline:Hide() end
            icon.count:SetText(quantity and quantity > 1 and tostring(quantity) or "")
            icon.grade:SetText("")

            local tier, maxTier, expansionID, qualityKind = self:GetReagentDisplayQuality(order, reagentEntry, selected, displayItemID)
            local qualityAtlas = GetProfessionQualityAtlas(tier, maxTier, expansionID, qualityKind)
            if qualityAtlas and icon.qualityBadge and icon.qualityBadge.SetAtlas then
                icon.qualityBadge:SetAtlas(qualityAtlas, true)
                icon.qualityBadge:SetSize(badgeSize, badgeSize)
                icon.qualityBadge:Show()
                if icon.qualityOutline then
                    icon.qualityOutline:Hide()
                end
            elseif icon.qualityBadge then
                icon.qualityBadge:Hide()
                if icon.qualityOutline then icon.qualityOutline:Hide() end
            end

            local enough, owned, required, missing = self:GetDisplayedReagentAvailability(displayItemID, quantity)
            if selectable and not enough then
                icon.icon:SetDesaturated(true)
                icon.icon:SetVertexColor(0.58, 0.58, 0.58, 0.92)
                if icon.missingX then
                    icon.missingX:Show()
                end
            end

            if selectable and not enough and (self.GetQueueReagentMode and self:GetQueueReagentMode()) == "auto"
               and self.BuildOwnedMixForEntry then
                local mix, remaining = self:BuildOwnedMixForEntry(order, reagentEntry, {})
                if remaining <= 0 then
                    icon.icon:SetDesaturated(false)
                    icon.icon:SetVertexColor(1, 1, 1, 1)
                    if icon.missingX then icon.missingX:Hide() end
                    if #mix >= 2 and icon.qualityBadge and icon.qualityBadge.SetAtlas then
                        icon.qualityBadge:SetAtlas("Professions-Icon-Quality-Mixed", true)
                        icon.qualityBadge:SetSize(badgeSize, badgeSize)
                        icon.qualityBadge:Show()
                    end
                end
            end

            if selectable and selected and type(selected.mix) == "table" and #selected.mix >= 1 then
                local ownedEnough = true
                for _, p in ipairs(selected.mix) do
                    if (self:GetItemCountForShopping(p.itemID) or 0) < (tonumber(p.quantity) or 0) then
                        ownedEnough = false
                        break
                    end
                end
                if ownedEnough then
                    icon.icon:SetDesaturated(false)
                    icon.icon:SetVertexColor(1, 1, 1, 1)
                    if icon.missingX then icon.missingX:Hide() end
                end
                if #selected.mix >= 2 and icon.qualityBadge and icon.qualityBadge.SetAtlas then
                    icon.qualityBadge:SetAtlas("Professions-Icon-Quality-Mixed", true)
                    icon.qualityBadge:SetSize(badgeSize, badgeSize)
                    icon.qualityBadge:Show()
                end
            end

            icon.order = order
            icon.reagentEntry = reagentEntry
            icon.reagentInfo = reagentEntry
            icon:EnableMouse(true)
            icon:Enable()

            if providedByCustomer then
                icon:SetBackdropBorderColor(0.25, 0.85, 1, 0.95)
            elseif selected then
                icon:SetBackdropBorderColor(0.35, 1, 0.35, 0.95)
            else
                icon:SetBackdropBorderColor(0.95, 0.65, 0.25, 0.90)
            end
            if selectable and not enough then
                icon:SetBackdropBorderColor(0.78, 0.24, 0.24, 0.92)
            end

            icon:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            icon:SetScript("OnClick", function(self, mouseButton)
                CO.debugLastOrder = self.order
                if CO.reagentDebugEnabled and mouseButton == "RightButton" and IsAltKeyDown and IsAltKeyDown() and CO.DebugDumpOrder then
                    CO:DebugDumpOrder(self.order, "alt-right reagent icon")
                    return
                end
                if mouseButton == "LeftButton" and IsCrafterProvidedReagent(self.reagentEntry) then
                    CO:OpenReagentMenu(self, self.order, self.reagentEntry)
                end
            end)
            SetIconTooltip(icon, displayItemID, providedByCustomer and T("COA_REAGENT_CUSTOMER", "Provided by customer") or T("COA_REAGENT_CRAFTER", "Provided by you"), function()
                if selectable and required and required > 0 then
                    GameTooltip:AddLine(" ")
                    if enough then
                        GameTooltip:AddLine(FormatReagentOwnedText(owned, required), 0.35, 0.95, 0.45)
                    else
                        GameTooltip:AddLine(FormatReagentOwnedText(owned, required), 1, 0.35, 0.35)
                        GameTooltip:AddLine(FormatReagentMissingText(missing), 1, 0.22, 0.22)
                    end
                end
            end)
            icon:Show()
        end
    end

    local extra = #displayable - shown
    if extra > 0 and frame.moreText then
        frame.moreText:ClearAllPoints()
        if twoRows then
            frame.moreText:SetPoint("RIGHT", frame, "RIGHT", -1, 0)
        else
            frame.moreText:SetPoint("RIGHT", frame, "RIGHT", -1, 0)
        end
        frame.moreText:SetText("+" .. tostring(extra))
    end
end

function CO:UpdateOrderColumnFrames(row, order)
    if not row or not order then return end
    self:ApplyOrderNameFont(row, order)
    self:UpdateFocusFrame(row.ahuiOrderFocusFrame, order)
    self:UpdateRewardsFrame(row.ahuiOrderRewardsFrame, order)
    self:UpdateReagentsFrame(row.ahuiOrderReagentsFrame, order)
    self:UpdateProfitFrame(row.ahuiOrderProfitFrame, order)

    if self.HideBlizzardColumnsUnderHironCraftProfit then
        self:HideBlizzardColumnsUnderHironCraftProfit(row)
    end
end

function CO:CreateTextButton(parent, name, width, height, text)
    local b = CreateFrame("Button", name, parent, "UIPanelButtonTemplate,BackdropTemplate")
    b:SetSize(width, height)
    CreateBackdrop(b, 0.94)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    b.text = b:GetFontString()
    ApplyFont(b.text, 11, "")
    b.text:ClearAllPoints()
    b.text:SetPoint("CENTER", 0, 0)
    b.text:SetWidth(math.max(1, (width or 40) - 6))
    b.text:SetJustifyH("CENTER")
    b.text:SetWordWrap(false)
    if b.text.SetMaxLines then b.text:SetMaxLines(1) end
    b.text:SetText(text or "")
    if self.StyleClassicButton then self:StyleClassicButton(b) end

    b:SetScript("OnMouseDown", function(self)
        if self:IsEnabled() then self.text:SetPoint("CENTER", 1, -1) end
    end)
    b:SetScript("OnMouseUp", function(self)
        self.text:SetPoint("CENTER", 0, 0)
    end)

    return b
end

function CO:CreateValueInput(parent, width, height, getCopper, setCopper)
    local eb = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    eb:SetSize(width, height)
    CreateBackdrop(eb, 0.94)
    eb:SetAutoFocus(false)
    ApplyFont(eb, 12, "")
    eb:SetTextColor(1, 1, 1, 1)
    eb:SetTextInsets(4, 4, 0, 0)
    eb:SetJustifyH("CENTER")
    eb:SetMaxLetters(12)

    eb.RefreshValue = function(self)
        if self:HasFocus() then return end
        local c = getCopper()
        self:SetText(c and tostring(c / 10000) or "")
        self:SetCursorPosition(0)
    end

    local function commit(self)
        local copper, ok = CO:ParseQueueMinProfitInput(self:GetText() or "")
        if ok then setCopper(copper) end
        self:RefreshValue()
    end

    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEscapePressed", function(self) self._cancel = true; self:ClearFocus() end)
    eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    eb:SetScript("OnEditFocusLost", function(self)
        if self._cancel then self._cancel = nil; self:RefreshValue(); return end
        commit(self)
    end)

    eb:RefreshValue()
    return eb
end
