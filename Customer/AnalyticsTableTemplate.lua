local HironCraftScan = select(2, ...)

local LID = HironCraftScan.CONST.TEXT;
local function L(id)
    return HironCraftScan.LOCAL:GetText(id);
end

HironCraftScan.AnalyticsTableSortOrder = EnumUtil.MakeEnum(
    "ItemName",
    "ProfessionName",
    "TotalSeen",
    "TotalSeenFiltered",
    "AveragePerDay",
    "PeakPerHour",
    "MedianPerCustomer",
    "MedianPerCustomerFiltered"
);

HironCraftScanAnalyticsTableConstants = {};
HironCraftScanAnalyticsTableConstants.StandardPadding = 10;
HironCraftScanAnalyticsTableConstants.NoPadding = 0;
HironCraftScanAnalyticsTableConstants.ItemName = {
    Width = 330,
    Padding = HironCraftScanAnalyticsTableConstants.StandardPadding,
    LeftCellPadding = HironCraftScanAnalyticsTableConstants.NoPadding,
    RightCellPadding = HironCraftScanAnalyticsTableConstants.NoPadding
};
HironCraftScanAnalyticsTableConstants.ProfessionName = {
    Width = 100,
    Padding = HironCraftScanAnalyticsTableConstants.StandardPadding,
    LeftCellPadding = HironCraftScanAnalyticsTableConstants.NoPadding,
    RightCellPadding = HironCraftScanAnalyticsTableConstants.NoPadding
}
HironCraftScanAnalyticsTableConstants.TotalSeen = {
    Width = 60,
    Padding = HironCraftScanAnalyticsTableConstants.StandardPadding,
    LeftCellPadding = HironCraftScanAnalyticsTableConstants.NoPadding,
    RightCellPadding = HironCraftScanAnalyticsTableConstants.NoPadding
};
HironCraftScanAnalyticsTableConstants.TotalSeenFiltered = {
    Width = 60,
    Padding = HironCraftScanAnalyticsTableConstants.StandardPadding,
    LeftCellPadding = HironCraftScanAnalyticsTableConstants.NoPadding,
    RightCellPadding = HironCraftScanAnalyticsTableConstants.NoPadding
};
HironCraftScanAnalyticsTableConstants.AveragePerDay = {
    Width = 60,
    Padding = HironCraftScanAnalyticsTableConstants.StandardPadding,
    LeftCellPadding = HironCraftScanAnalyticsTableConstants.NoPadding,
    RightCellPadding = HironCraftScanAnalyticsTableConstants.NoPadding
};
HironCraftScanAnalyticsTableConstants.PeakPerHour = {
    Width = 70,
    Padding = HironCraftScanAnalyticsTableConstants.StandardPadding,
    LeftCellPadding = HironCraftScanAnalyticsTableConstants.NoPadding,
    RightCellPadding = HironCraftScanAnalyticsTableConstants.NoPadding
};
HironCraftScanAnalyticsTableConstants.MedianPerCustomer = {
    Width = 70,
    Padding = HironCraftScanAnalyticsTableConstants.StandardPadding,
    LeftCellPadding = HironCraftScanAnalyticsTableConstants.NoPadding,
    RightCellPadding = HironCraftScanAnalyticsTableConstants.NoPadding
};
HironCraftScanAnalyticsTableConstants.MedianPerCustomerFiltered = {
    Width = 100,
    Padding = HironCraftScanAnalyticsTableConstants.StandardPadding,
    LeftCellPadding = HironCraftScanAnalyticsTableConstants.NoPadding,
    RightCellPadding = HironCraftScanAnalyticsTableConstants.NoPadding
};

local function TooltipText(sortOrder)
    if sortOrder == HironCraftScan.AnalyticsTableSortOrder.ItemName then
        return L(LID.ANALYTICS_ITEM_TOOLTIP)
    elseif sortOrder == HironCraftScan.AnalyticsTableSortOrder.ProfessionName then
        return L(LID.ANALYTICS_PROFESSION_TOOLTIP)
    elseif sortOrder == HironCraftScan.AnalyticsTableSortOrder.TotalSeen then
        return L(LID.ANALYTICS_TOTAL_TOOLTIP)
    elseif sortOrder == HironCraftScan.AnalyticsTableSortOrder.TotalSeenFiltered then
        return L(LID.ANALYTICS_REPEAT_TOOLTIP)
    elseif sortOrder == HironCraftScan.AnalyticsTableSortOrder.AveragePerDay then
        return L(LID.ANALYTICS_AVERAGE_TOOLTIP)
    elseif sortOrder == HironCraftScan.AnalyticsTableSortOrder.PeakPerHour then
        return L(LID.ANALYTICS_PEAK_TOOLTIP)
    elseif sortOrder == HironCraftScan.AnalyticsTableSortOrder.MedianPerCustomer then
        return L(LID.ANALYTICS_MEDIAN_TOOLTIP)
    elseif sortOrder == HironCraftScan.AnalyticsTableSortOrder.MedianPerCustomerFiltered then
        return L(LID.ANALYTICS_MEDIAN_TOOLTIP_FILTERED)
    end
end

local function HeaderName(sortOrder)
    if sortOrder == HironCraftScan.AnalyticsTableSortOrder.ItemName then
        return PROFESSIONS_COLUMN_HEADER_ITEM;
    elseif sortOrder == HironCraftScan.AnalyticsTableSortOrder.ProfessionName then
        return L("Profession");
    elseif sortOrder == HironCraftScan.AnalyticsTableSortOrder.TotalSeen then
        return L("Total");
    elseif sortOrder == HironCraftScan.AnalyticsTableSortOrder.TotalSeenFiltered then
        return L("Repeat");
    elseif sortOrder == HironCraftScan.AnalyticsTableSortOrder.AveragePerDay then
        return L("Avg Per Day");
    elseif sortOrder == HironCraftScan.AnalyticsTableSortOrder.PeakPerHour then
        return L("Peak Per Hour");
    elseif sortOrder == HironCraftScan.AnalyticsTableSortOrder.MedianPerCustomer then
        return L("Median Per Customer");
    elseif sortOrder == HironCraftScan.AnalyticsTableSortOrder.MedianPerCustomerFiltered then
        return L("Median Per Customer Filtered");
    end
end

HironCraftScanAnalyticsTableHeaderStringMixin = CreateFromMixins(HironCraftScanCrafterTableHeaderStringMixin);

function HironCraftScanAnalyticsTableHeaderStringMixin:OnEnter()
    local text = TooltipText(self.sortOrder);
    if text == nil then
        return
    end

    GameTooltip:SetOwner(self, "ANCHOR_TOP");
    GameTooltip_SetTitle(GameTooltip, HeaderName(self.sortOrder));
    GameTooltip_AddBlankLineToTooltip(GameTooltip);
    GameTooltip:AddLine(text, 1, 1, 1, true);
    GameTooltip:Show();
end

function HironCraftScanAnalyticsTableHeaderStringMixin:OnLeave()
    GameTooltip:Hide();
end

HironCraftScanAnalyticsTableBuilderMixin = CreateFromMixins(HironCraftScanTableBuilderMixin,
    { header_template = "HironCraftScanAnalyticsTableHeaderStringTemplate" });

function HironCraftScanAnalyticsTableBuilderMixin:GetHeaderNameFromSortOrder(sortOrder)
    return HeaderName(sortOrder);
end

HironCraftScanAnalyticsCellItemNameMixin = CreateFromMixins(TableBuilderCellMixin);

function HironCraftScanAnalyticsCellItemNameMixin:Populate(rowData)
    local itemInfo = rowData.item;

    -- The item is already loaded because we loaded it to generate this table row's source data.
    local item = Item:CreateFromItemID(itemInfo.itemID);
    local icon = item:GetItemIcon();
    self.Icon:SetTexture(icon);

    local qualityColor = item:GetItemQualityColor().color;
    local itemName = qualityColor:WrapTextInColorCode(item:GetItemName());
    self.Text:SetText(itemName);
end

HironCraftScanAnalyticsTableCellProfessionNameMixin = CreateFromMixins(TableBuilderCellMixin);

function HironCraftScanAnalyticsTableCellProfessionNameMixin:Populate(rowData)
    local itemInfo = rowData.item;
    self.Text:SetText(itemInfo.profession);
end

HironCraftScanAnalyticsTableCellTotalSeenMixin = CreateFromMixins(TableBuilderCellMixin);

function HironCraftScanAnalyticsTableCellTotalSeenMixin:Populate(rowData)
    local itemInfo = rowData.item;
    self.Text:SetText(itemInfo.totalSeen);
end

HironCraftScanAnalyticsTableCellTotalSeenFilteredMixin = CreateFromMixins(TableBuilderCellMixin);

function HironCraftScanAnalyticsTableCellTotalSeenFilteredMixin:Populate(rowData)
    local itemInfo = rowData.item;
    self.Text:SetText(itemInfo.totalSeenFiltered);
end

HironCraftScanAnalyticsTableCellAveragePerDayMixin = CreateFromMixins(TableBuilderCellMixin);

function HironCraftScanAnalyticsTableCellAveragePerDayMixin:Populate(rowData)
    local itemInfo = rowData.item;
    self.Text:SetText(string.format("%.2f", itemInfo.averagePerDay));
end

HironCraftScanAnalyticsTableCellPeakPerHourMixin = CreateFromMixins(TableBuilderCellMixin);

function HironCraftScanAnalyticsTableCellPeakPerHourMixin:Populate(rowData)
    local itemInfo = rowData.item;
    self.Text:SetText(itemInfo.peakPerHour);
end

HironCraftScanAnalyticsTableCellMedianPerCustomerMixin = CreateFromMixins(TableBuilderCellMixin);

function HironCraftScanAnalyticsTableCellMedianPerCustomerMixin:Populate(rowData)
    local itemInfo = rowData.item;
    self.Text:SetText(itemInfo.medianPerCustomer);
end

HironCraftScanAnalyticsTableCellMedianPerCustomerFilteredMixin = CreateFromMixins(TableBuilderCellMixin);

function HironCraftScanAnalyticsTableCellMedianPerCustomerFilteredMixin:Populate(rowData)
    local itemInfo = rowData.item;
    self.Text:SetText(itemInfo.medianPerCustomerFiltered);
end
