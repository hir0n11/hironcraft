local E = _G.HironCraftProfitCraftingOrdersEnv
if not E then
    E = {}
    _G.HironCraftProfitCraftingOrdersEnv = E
    setmetatable(E, { __index = _G })
end
setfenv(1, E)
if not PT or not CO then return end

function CO:GetActionSortOrder()
    if self.ahuiActionSortOrder then return self.ahuiActionSortOrder end

    local source = ProfessionsSortOrder and ProfessionsSortOrder.Expiration
    if type(source) == "table" then
        self.ahuiActionSortOrder = CopyPrimitiveTableFields(source)
    elseif source ~= nil then
        self.ahuiActionSortOrder = { sortType = source }
    else
        return nil
    end

    self.ahuiActionSortOrder.ahuiCraftingOrdersActionSort = true
    self.ahuiActionSortOrder.ahuiSortByAction = true
    for _, field in ipairs(ORDER_COLUMN_TEXT_FIELDS) do
        if self.ahuiActionSortOrder[field] ~= nil and type(self.ahuiActionSortOrder[field]) ~= "function" then
            self.ahuiActionSortOrder[field] = T("COA_HDR_ACTION", "Action")
        end
    end
    return self.ahuiActionSortOrder
end

function CO:EnsureHironCraftProfitProfitColumnSpec()
    local PTC = _G.ProfessionsTableConstants
    if type(PTC) ~= "table" then return nil end

    if type(PTC.HironCraftProfitProfit) ~= "table" then
        PTC.HironCraftProfitProfit = CopyPrimitiveTableFields(PTC.Tip or PTC.Reagents or {})
    end

    PTC.HironCraftProfitProfit.Width = PROFIT_COLUMN_W + 8
    PTC.HironCraftProfitProfit.width = PROFIT_COLUMN_W + 8
    PTC.HironCraftProfitProfit.LeftCellPadding = 0
    PTC.HironCraftProfitProfit.RightCellPadding = 0
    PTC.HironCraftProfitProfit.Label = T("COA_HDR_PROFIT", "Profit")
    PTC.HironCraftProfitProfit.Text = T("COA_HDR_PROFIT", "Profit")
    return PTC.HironCraftProfitProfit
end

function CO:LockOrderTableColumns()
    local PTC = _G.ProfessionsTableConstants
    if type(PTC) ~= "table" then return end
    self.originalOrderTableConstants = self.originalOrderTableConstants or {}

    for key, width in pairs(LOCKED_ORDER_COLUMN_WIDTHS) do
        local spec = PTC[key]
        if type(spec) == "table" then
            if not self.originalOrderTableConstants[key] then
                self.originalOrderTableConstants[key] = {}
                for k, v in pairs(spec) do
                    if type(v) ~= "table" and type(v) ~= "function" then
                        self.originalOrderTableConstants[key][k] = v
                    end
                end
            end

            if tonumber(width) then
                spec.Width = width
                spec.width = width
            end

            local label = T(LOCKED_ORDER_COLUMN_LABELS[key], LOCKED_ORDER_COLUMN_FALLBACKS[key])
            for _, field in ipairs(ORDER_COLUMN_TEXT_FIELDS) do
                if spec[field] ~= nil and type(spec[field]) ~= "function" then
                    spec[field] = label
                end
            end
        end
    end
end


function CollectVisibleFontStrings(frame, out, depth, seen)
    if not frame or depth > 9 then return end
    seen = seen or {}
    if seen[frame] then return end
    seen[frame] = true

    if frame.GetRegions then
        for _, region in ipairs({ frame:GetRegions() }) do
            if region and region.GetObjectType and region:GetObjectType() == "FontString"
               and region.IsShown and region:IsShown() and not region.ahuiCraftingOrdersOwned then
                out[#out + 1] = region
            end
        end
    end

    if frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do
            if child and not child.ahuiCraftingOrdersOwned then
                CollectVisibleFontStrings(child, out, depth + 1, seen)
            end
        end
    end
end

function CO:RestoreHiddenOrderHeaderRegions(pageFrame)
    if not pageFrame then return end

    if pageFrame.ahuiOrderHeaderHiddenRegions then
        for region in pairs(pageFrame.ahuiOrderHeaderHiddenRegions) do
            if region and region.Show then
                region:Show()
            end
        end
        wipe(pageFrame.ahuiOrderHeaderHiddenRegions)
    end


    if pageFrame.ahuiOrderHeaderOverlay and pageFrame.ahuiOrderHeaderOverlay.Hide then
        pageFrame.ahuiOrderHeaderOverlay:Hide()
    end
end

function ForEachHeaderFontString(frame, callback, depth, seen)
    if not frame or not callback or (depth or 0) > 6 then return end
    seen = seen or {}
    if seen[frame] then return end
    seen[frame] = true

    for _, field in ipairs({ "Text", "Label", "Name", "Title", "Header", "HeaderText", "FontString" }) do
        local fs = frame[field]
        if fs and fs.GetObjectType and fs:GetObjectType() == "FontString" then
            callback(fs)
        end
    end

    if frame.GetRegions then
        for _, region in ipairs({ frame:GetRegions() }) do
            if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                callback(region)
            end
        end
    end

    if frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do
            ForEachHeaderFontString(child, callback, (depth or 0) + 1, seen)
        end
    end
end

function ApplyHeaderFrameFont(headerFrame)
    if not headerFrame then return end

    ForEachHeaderFontString(headerFrame, function(fs)
        ApplyFont(fs, 11, "")
        if fs.SetWordWrap then fs:SetWordWrap(false) end
        if fs.SetMaxLines then fs:SetMaxLines(1) end
    end)
end

function SetHeaderFrameLabel(headerFrame, label)
    if not headerFrame or not label then return end

    if headerFrame.SetWidth and headerFrame.ahuiOrderColumnWidth then
        headerFrame:SetWidth(headerFrame.ahuiOrderColumnWidth)
    end

    if headerFrame.SetText then
        pcall(headerFrame.SetText, headerFrame, label)
    end

    ForEachHeaderFontString(headerFrame, function(fs)
        if not fs.ahuiCraftingOrdersOwned then
            fs:SetText(label)
            ApplyFont(fs, 11, "")
            if fs.SetWordWrap then fs:SetWordWrap(false) end
            if fs.SetMaxLines then fs:SetMaxLines(1) end
            if fs.Show then fs:Show() end
        end
    end)

    if headerFrame.ahuiRewardsLabel and headerFrame.ahuiRewardsLabel.Hide then
        headerFrame.ahuiRewardsLabel:Hide()
    end
    if headerFrame.ahuiProfitLabel and headerFrame.ahuiProfitLabel.Hide then
        headerFrame.ahuiProfitLabel:Hide()
    end
end

function ApplyOrderHeaderContainerFont(pageFrame)
    local headerContainer = pageFrame and pageFrame.BrowseFrame and pageFrame.BrowseFrame.OrderList
        and pageFrame.BrowseFrame.OrderList.HeaderContainer
    if not headerContainer then return end

    if headerContainer.GetRegions then
        for _, region in ipairs({ headerContainer:GetRegions() }) do
            if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                ApplyFont(region, 11, "")
            end
        end
    end

    if headerContainer.GetChildren then
        for _, child in ipairs({ headerContainer:GetChildren() }) do
            if child and child.GetRegions then
                for _, region in ipairs({ child:GetRegions() }) do
                    if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                        ApplyFont(region, 11, "")
                    end
                end
            end
            if child and child.Text and child.Text.SetFont then
                ApplyFont(child.Text, 11, "")
            end
            ApplyHeaderFrameFont(child)
        end
    end
end

function EnsureSplitHeaderLabel(headerFrame, key, fallback, width, side)
    if not headerFrame or not headerFrame.CreateFontString then return nil end

    local name = "ahui" .. tostring(key or "Header") .. "Label"
    local fs = headerFrame[name]
    if not fs then
        fs = headerFrame:CreateFontString(nil, "OVERLAY")
        fs.ahuiCraftingOrdersOwned = true
        headerFrame[name] = fs
        ApplyFont(fs, 11, "")
        fs:SetJustifyH(side == "RIGHT" and "RIGHT" or "LEFT")
        fs:SetWordWrap(false)
        if fs.SetMaxLines then fs:SetMaxLines(1) end
    end

    fs:ClearAllPoints()
    if side == "RIGHT" then
        fs:SetPoint("RIGHT", headerFrame, "RIGHT", -2, 0)
    else
        fs:SetPoint("LEFT", headerFrame, "LEFT", 2, 0)
    end
    fs:SetWidth(math.max(1, width or 60))
    fs:SetText(T(key, fallback))
    fs:Show()
    return fs
end

function SetRewardsProfitHeaderLabel(headerFrame, width)
    if not headerFrame then return end

    width = tonumber(width) or REWARDS_COLUMN_W

    if headerFrame.SetWidth then
        headerFrame:SetWidth(width)
    end

    if headerFrame.SetText then
        pcall(headerFrame.SetText, headerFrame, "")
    end


    ForEachHeaderFontString(headerFrame, function(fs)
        if not fs.ahuiCraftingOrdersOwned then
            fs:SetText("")
            if fs.Hide then fs:Hide() end
        end
    end)

    local profitWidth = math.min(PROFIT_COLUMN_W, math.max(46, width - 34))
    local rewardsWidth = math.max(36, width - profitWidth - 8)

    local rewards = EnsureSplitHeaderLabel(headerFrame, "COA_HDR_REWARDS", "Rewards", rewardsWidth, "LEFT")
    local profit = EnsureSplitHeaderLabel(headerFrame, "COA_HDR_PROFIT", "Profit", profitWidth, "RIGHT")

    headerFrame.ahuiRewardsLabel = rewards
    headerFrame.ahuiProfitLabel = profit
end

function SetFrameWidthSafe(frame, width)
    if frame and width and frame.SetWidth then
        frame:SetWidth(width)
    end
end

function CO:GetHeaderAnchorRow()
    local bestRow, bestTop

    for btn in pairs(self.visibleRowButtons or {}) do
        if btn and btn.IsShown and btn:IsShown() then
            local row = btn.GetParent and btn:GetParent()
            local top = row and row.GetTop and row:GetTop()
            if top and (not bestTop or top > bestTop) then
                bestRow, bestTop = row, top
            end
        end
    end

    return bestRow
end

function CO:ApplyRealOrderTableLayout(pageFrame)
    if not self:IsEnabled() then return end
    pageFrame = pageFrame or self.activePageFrame
    if not pageFrame then return end


    self:RestoreHiddenOrderHeaderRegions(pageFrame)

    local widths = GetOrderTableColumnWidths()
    local tableWidth = GetOrderListTableWidth(pageFrame)
    local columnInfo = {
        [2] = { key = "CustomerName", width = widths.customer,   label = ""  },
        [3] = { key = "Tip",          width = widths.tip,        label = T("COA_HDR_REWARDS",  "Rewards")  },
        [4] = { key = "Reagents",     width = widths.reagents,   label = T("COA_HDR_REAGENTS", "Reagents") },
        [5] = { key = "Expiration",   width = widths.expiration, label = T("COA_HDR_ACTION",   "Action")   },
    }

    local tableBuilder = pageFrame.tableBuilder
    if tableBuilder and tableBuilder.SetTableWidth then
        pcall(tableBuilder.SetTableWidth, tableBuilder, tableWidth)
    end

    local columns = tableBuilder and tableBuilder.GetColumns and tableBuilder:GetColumns()
    if type(columns) == "table" then


        if columns[1] and columns[1].headerFrame then
            ApplyHeaderFrameFont(columns[1].headerFrame)
        end

        for index, info in pairs(columnInfo) do
            local column = columns[index]
            if type(column) == "table" then
                column.fixedWidth = info.width
                column.width = info.width
                column.Width = info.width
                if column.headerFrame then
                    column.headerFrame.ahuiOrderColumnWidth = info.width
                    SetFrameWidthSafe(column.headerFrame, info.width)
                    if info.key == "Tip" then
                        SetRewardsProfitHeaderLabel(column.headerFrame, info.width)
                    else
                        SetHeaderFrameLabel(column.headerFrame, info.label)
                    end
                    ApplyHeaderFrameFont(column.headerFrame)
                    if column.headerFrame.Show then column.headerFrame:Show() end
                end
            end
        end
    end

    ApplyOrderHeaderContainerFont(pageFrame)


end

function CO:GetLockedHeaderZones(anchorRow)
    if not anchorRow or not anchorRow.GetRight then return nil end

    local rowRight = anchorRow:GetRight()
    if not rowRight then return nil end

    local widths = GetOrderTableColumnWidths()
    return {
        { key = "quality", offset = widths.expiration + widths.reagents + widths.tip, width = widths.customer, label = "" },
        { key = "rewards", offset = widths.expiration + widths.reagents, width = widths.tip, label = T("COA_HDR_REWARDS", "Rewards") },
        { key = "reagents", offset = widths.expiration, width = widths.reagents, label = T("COA_HDR_REAGENTS", "Reagents") },
        { key = "action", offset = 0, width = widths.expiration, label = T("COA_HDR_ACTION", "Action") },
    }, rowRight
end

function CO:EnsureOrderHeaderOverlay(pageFrame, anchorRow)
    if pageFrame and pageFrame.ahuiOrderHeaderOverlay and pageFrame.ahuiOrderHeaderOverlay.Hide then
        pageFrame.ahuiOrderHeaderOverlay:Hide()
    end
end

function CO:HideExternalHeaderRegions(pageFrame, anchorRow)
    self:RestoreHiddenOrderHeaderRegions(pageFrame)
end

function CO:ProtectOrderHeaderLabels(pageFrame)
    if not self:IsEnabled() then return end
    pageFrame = pageFrame or self.activePageFrame
    if not pageFrame then return end

    self:ApplyRealOrderTableLayout(pageFrame)
end

function CO:RestoreOrderTableColumns()
    local PTC = _G.ProfessionsTableConstants
    local originals = self.originalOrderTableConstants
    if type(PTC) ~= "table" or type(originals) ~= "table" then return end

    for key, values in pairs(originals) do
        local spec = PTC[key]
        if type(spec) == "table" and type(values) == "table" then
            for k, v in pairs(values) do
                spec[k] = v
            end
        end
    end
end

function SetRowColumnByRightOffset(row, frame, rightOffset, width, padX)
    if not row or not frame then return end
    padX = padX or 4
    frame:ClearAllPoints()
    frame:SetSize(math.max(24, (width or 80) - (padX * 2)), ROW_BUTTON_H)
    frame:SetPoint("RIGHT", row, "RIGHT", -(ROW_RIGHT_PAD + rightOffset + padX), 0)
end

GetProfessionFromPage = nil
