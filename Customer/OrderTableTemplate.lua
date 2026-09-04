local HironCraftScan = select(2, ...)

local LID = HironCraftScan.CONST.TEXT;
local function L(id)
    return HironCraftScan.LOCAL:GetText(id);
end

HironCraftScan.ChatOrderSortOrder = EnumUtil.MakeEnum("CustomerName", "CrafterName", "ProfessionName", "ItemName", "Time"); -- , "Sent");

HironCraftScanTableConstants = {};
HironCraftScanTableConstants.StandardPadding = 10;
HironCraftScanTableConstants.NoPadding = 0;
HironCraftScanTableConstants.Name = {
    Width = 100,
    Padding = HironCraftScanTableConstants.NoPadding,
    FillCoefficient = 1.0,
    LeftCellPadding = HironCraftScanTableConstants.StandardPadding,
    RightCellPadding = HironCraftScanTableConstants.NoPadding
};
HironCraftScanTableConstants.ItemName = {
    Width = 330,
    Padding = HironCraftScanTableConstants.StandardPadding,
    LeftCellPadding = HironCraftScanTableConstants.NoPadding,
    RightCellPadding = HironCraftScanTableConstants.NoPadding
};
HironCraftScanTableConstants.CustomerName = {
    Width = 160,
    Padding = HironCraftScanTableConstants.StandardPadding,
    LeftCellPadding = HironCraftScanTableConstants.NoPadding,
    RightCellPadding = HironCraftScanTableConstants.NoPadding
};
HironCraftScanTableConstants.CrafterName = {
    Width = 120,
    Padding = HironCraftScanTableConstants.StandardPadding,
    LeftCellPadding = HironCraftScanTableConstants.NoPadding,
    RightCellPadding = HironCraftScanTableConstants.NoPadding
};
HironCraftScanTableConstants.ProfessionName = {
    Width = 120,
    Padding = HironCraftScanTableConstants.StandardPadding,
    LeftCellPadding = HironCraftScanTableConstants.NoPadding,
    RightCellPadding = HironCraftScanTableConstants.NoPadding
};
HironCraftScanTableConstants.Interaction = {
    Width = 76,
    Padding = HironCraftScanTableConstants.StandardPadding,
    LeftCellPadding = HironCraftScanTableConstants.NoPadding,
    RightCellPadding = HironCraftScanTableConstants.NoPadding
};
HironCraftScanTableConstants.Time = {
    Width = 40,
    Padding = HironCraftScanTableConstants.StandardPadding,
    LeftCellPadding = HironCraftScanTableConstants.NoPadding,
    RightCellPadding = HironCraftScanTableConstants.NoPadding
};

HironCraftScanCrafterListTableConstants = {};
HironCraftScanCrafterListTableConstants.StandardPadding = 10;
HironCraftScanCrafterListTableConstants.NoPadding = 0;
HironCraftScanCrafterListTableConstants.CrafterName = {
    Width = 120,
    Padding = HironCraftScanCrafterListTableConstants.StandardPadding,
    LeftCellPadding = HironCraftScanCrafterListTableConstants.NoPadding,
    RightCellPadding = HironCraftScanCrafterListTableConstants.NoPadding
}

HironCraftScanCrafterTableHeaderStringMixin = CreateFromMixins(TableBuilderElementMixin);

function HironCraftScanCrafterTableHeaderStringMixin:OnClick()
    if not self.sortOrder then
        return;
    end

    self.owner:SetSortOrder(self.sortOrder);
    self:UpdateArrow();
end

function HironCraftScanCrafterTableHeaderStringMixin:Init(owner, headerText, sortOrder)
    self:SetText(headerText);

    self.owner = owner;
    self.sortOrder = sortOrder;
    self:UpdateArrow();
end

function HironCraftScanCrafterTableHeaderStringMixin:UpdateArrow()
    local sortOrder, ascending = self.owner:GetSortOrder();
    if sortOrder == self.sortOrder then
        self.Arrow:Show();
        if ascending then
            self.Arrow:SetTexCoord(0, 1, 0, 1);
        else
            self.Arrow:SetTexCoord(0, 1, 1, 0);
        end
    else
        self.Arrow:Hide();
    end
end

HironCraftScanTableBuilderMixin = {};

function HironCraftScanTableBuilderMixin:AddColumnInternal(owner, sortOrder, cellTemplate, ...)
    local column = self:AddColumn();

    if sortOrder then
        local headerName = self:GetHeaderNameFromSortOrder(sortOrder);
        column:ConstructHeader("BUTTON", self.header_template or "HironCraftScanCrafterTableHeaderStringTemplate", owner, headerName,
            sortOrder);
    end

    column:ConstructCells("FRAME", cellTemplate, owner, ...);

    return column;
end

function HironCraftScanTableBuilderMixin:AddUnsortableColumnInternal(owner, headerText, cellTemplate, ...)
    local column = self:AddColumn();
    local sortOrder = nil;
    column:ConstructHeader("BUTTON", self.header_template or "HironCraftScanCrafterTableHeaderStringTemplate", owner, headerText, sortOrder);
    column:ConstructCells("FRAME", cellTemplate, owner, ...);
    return column;
end

function HironCraftScanTableBuilderMixin:AddFixedWidthColumn(owner, padding, width, leftCellPadding, rightCellPadding,
                                                        sortOrder, cellTemplate, ...)
    local column = self:AddColumnInternal(owner, sortOrder, cellTemplate, ...);
    column:SetFixedConstraints(width, padding);
    column:SetCellPadding(leftCellPadding, rightCellPadding);
    return column;
end

function HironCraftScanTableBuilderMixin:AddFillColumn(owner, padding, fillCoefficient, leftCellPadding,
                                                  rightCellPadding, sortOrder, cellTemplate, ...)
    local column = self:AddColumnInternal(owner, sortOrder, cellTemplate, ...);
    column:SetFillConstraints(fillCoefficient, padding);
    column:SetCellPadding(leftCellPadding, rightCellPadding);
    return column;
end

function HironCraftScanTableBuilderMixin:AddUnsortableFixedWidthColumn(owner, padding, width, leftCellPadding,
                                                                  rightCellPadding, headerText, cellTemplate, ...)
    local column = self:AddUnsortableColumnInternal(owner, headerText, cellTemplate, ...);
    column:SetFixedConstraints(width, padding);
    column:SetCellPadding(leftCellPadding, rightCellPadding);
    return column;
end

function HironCraftScanTableBuilderMixin:AddUnsortableFillColumn(owner, padding, fillCoefficient, leftCellPadding,
                                                            rightCellPadding, headerText, cellTemplate, ...)
    local column = self:AddUnsortableColumnInternal(owner, headerText, cellTemplate, ...);
    column:SetFillConstraints(fillCoefficient, padding);
    column:SetCellPadding(leftCellPadding, rightCellPadding);
    return column;
end

HironCraftScanOrderTableBuilderMixin = CreateFromMixins(HironCraftScanTableBuilderMixin);

function HironCraftScanOrderTableBuilderMixin:GetHeaderNameFromSortOrder(sortOrder)
    if sortOrder == HironCraftScan.ChatOrderSortOrder.ItemName then
        return PROFESSIONS_COLUMN_HEADER_ITEM;
    elseif sortOrder == HironCraftScan.ChatOrderSortOrder.CrafterName then
        return L("Crafter Name");
    elseif sortOrder == HironCraftScan.ChatOrderSortOrder.ProfessionName then
        return L("Profession");
        -- elseif sortOrder == HironCraftScanSortOrder.Time then
        -- return CreateAtlasMarkup("auctionhouse-icon-clock", 16, 16, 2, -2);
        -- elseif sortOrder == HironCraftScanSortOrder.ItemName then
        -- return AUCTION_HOUSE_BROWSE_HEADER_NAME;
    elseif sortOrder == HironCraftScan.ChatOrderSortOrder.CustomerName then
        return L("Customer Name");
    elseif sortOrder == HironCraftScan.ChatOrderSortOrder.Time then
        return CreateAtlasMarkup("auctionhouse-icon-clock", 16, 16, 2, -2);
    end
end

HironCraftScanTableCellTextMixin = CreateFromMixins(TableBuilderCellMixin);

function HironCraftScanTableCellTextMixin:SetText(text)
    self.Text:SetText(text);
end

HironCraftScanCrafterTableCellNameMixin = CreateFromMixins(TableBuilderCellMixin);

function HironCraftScanCrafterTableCellNameMixin:Populate(rowData, dataIndex)
    local order = rowData;
    local text = order:GetName();
    HironCraftScanTableCellTextMixin.SetText(self, text);
end

HironCraftScanCrafterTableCellItemNameMixin = CreateFromMixins(TableBuilderCellMixin);

function HironCraftScanCrafterTableCellItemNameMixin:Populate(rowData, dataIndex)
    local response = HironCraftScan.OrderToResponse(rowData.order);

    if not response.itemID then
        self.Icon:SetTexture(C_TradeSkillUI.GetTradeSkillTexture(response.professionID))
        self.Text:SetText(HironCraftScan.Utils.ColorizeProfessionName(response.parentProfID, response.professionName))
        return
    end

    local item = Item:CreateFromItemID(response.itemID);
    item:ContinueOnItemLoad(function()
        if item:GetItemID() ~= response.itemID then
            -- Callback from a previous async request
            return;
        end
        local icon = item:GetItemIcon();
        self.Icon:SetTexture(icon);

        local qualityColor = item:GetItemQualityColor().color;
        local itemName = qualityColor:WrapTextInColorCode(item:GetItemName());
        self.Text:SetText(itemName);
    end);
end

HironCraftScanCrafterTableCellTimeMixin = CreateFromMixins(TableBuilderCellMixin);

local function UpdateAge(self, response)
    local age = math.floor(time() - response.time)
    local text;
    if (age < 60) then
        text = string.format("%us", math.floor(age / 5) * 5)
    elseif (age < 3600) then
        text = string.format("%um", math.floor(age / 60))
    else
        text = string.format("%uh", math.floor(age / 3600))
    end

    HironCraftScanTableCellTextMixin.SetText(self, text);
end

function HironCraftScanCrafterTableCellTimeMixin:Populate(rowData, dataIndex)
    local order = rowData.order;
    local response = HironCraftScan.OrderToResponse(order);
    local liveResponse = HironCraftScan.OrderToLiveResponse(order, true)
    liveResponse.updateAge = function()
        UpdateAge(self, response)
    end
    UpdateAge(self, response)
end

HironCraftScanCrafterTableCellCustomerNameMixin = CreateFromMixins(TableBuilderCellMixin);

function HironCraftScanCrafterTableCellCustomerNameMixin:Populate(rowData, dataIndex)
    local order = rowData.order
    local customerInfo = HironCraftScan.OrderToCustomerInfo(order)
    HironCraftScanTableCellTextMixin.SetText(self, HironCraftScan.ColorizePlayerName(order.customerName, customerInfo.guid))
end

HironCraftScanCrafterTableCellCrafterNameMixin = CreateFromMixins(TableBuilderCellMixin);

function HironCraftScanCrafterTableCellCrafterNameMixin:Populate(rowData, dataIndex)
    local response = HironCraftScan.OrderToResponse(rowData.order);
    HironCraftScanTableCellTextMixin.SetText(self,
        HironCraftScan.ColorizeCrafterName(response.crafterName));
end

HironCraftScanCrafterTableCellProfessionNameMixin = CreateFromMixins(TableBuilderCellMixin);

function HironCraftScanCrafterTableCellProfessionNameMixin:Populate(rowData, dataIndex)
    local response = HironCraftScan.OrderToResponse(rowData.order);
    HironCraftScanTableCellTextMixin.SetText(self,
        HironCraftScan.Utils.ColorizeProfessionName(response.parentProfID, response.professionName))
end

HironCraftScanCrafterTableCellInteractionMixin = CreateFromMixins(TableBuilderCellMixin);

function HironCraftScanCrafterTableCellInteractionMixin:UpdateOrderStatus()
    self.OrderStatus.order = self.order
    self.OrderStatus:Refresh()
end

function HironCraftScanCrafterTableCellInteractionMixin:Populate(rowData, dataIndex)
    self.order = rowData.order;
    local response = HironCraftScan.OrderToResponse(rowData.order);
    if response.greeting_sent then
        self.PlayerIcon:SetAtlas("common-icon-checkmark")
    else
        self.PlayerIcon:SetAtlas("common-icon-redx")
    end

    if response.customer_answered then
        self.CustomerIcon:SetAtlas("common-icon-checkmark")
    else
        self.CustomerIcon:SetAtlas("common-icon-redx")
    end

    self:UpdateOrderStatus()

    -- Link ourselves to the response. This allows all chat bubble icons with a
    -- single customer to act in unison.
    HironCraftScan.OrderToLiveResponse(self.order, true).interactionFrame = self
end

HironCraftScanCraftingOrderStatusButtonMixin = {}

local ORDER_STATUS_COLORS = {
    [HironCraftScan.OrderFulfillment.Status.Unknown] = { 0.45, 0.45, 0.45, 0.7 },
    [HironCraftScan.OrderFulfillment.Status.Claimed] = { 1, 0.55, 0.1, 1 },
    [HironCraftScan.OrderFulfillment.Status.Crafted] = { 1, 0.85, 0.1, 1 },
    [HironCraftScan.OrderFulfillment.Status.Fulfilled] = { 1, 1, 1, 1 },
    [HironCraftScan.OrderFulfillment.Status.Failed] = { 1, 1, 1, 1 },
    -- Use exact RGB yellow so the desaturated red-X atlas does not read as an
    -- olive or yellow-green mark on darker UI backgrounds.
    [HironCraftScan.OrderFulfillment.Status.Rejected] = { 1, 1, 0, 1 },
}

function HironCraftScanCraftingOrderStatusButtonMixin:Refresh()
    HironCraftScan.OrderFulfillment:RegisterStatusButton(self)
    self:Show()
    self:SetAlpha(1)
    self.Icon:Show()
    local entry = self.order and HironCraftScan.OrderFulfillment:GetStatus(self.order)
    local status = entry and entry.status or HironCraftScan.OrderFulfillment.Status.Unknown
    local deliveryPending = entry
        and HironCraftScan.OrderFulfillment:IsDeliveryPending(entry)
    local isIncomplete = status == HironCraftScan.OrderFulfillment.Status.Unknown
        or status == HironCraftScan.OrderFulfillment.Status.Failed
        or status == HironCraftScan.OrderFulfillment.Status.Rejected
    local isRejected = status == HironCraftScan.OrderFulfillment.Status.Rejected
    local atlas = isIncomplete and "common-icon-redx" or "common-icon-checkmark"
    local color = ORDER_STATUS_COLORS[status]

    if not self.RejectGlow then
        self.RejectGlow = self:CreateTexture(nil, "BACKGROUND")
        self.RejectGlow:SetAtlas("common-icon-redx")
        self.RejectGlow:SetPoint("CENTER", self.Icon, "CENTER")
        self.RejectGlow:SetSize(20, 20)
        self.RejectGlow:SetDesaturated(true)
        self.RejectGlow:SetVertexColor(1, 1, 0, 1)
        self.RejectGlow:SetBlendMode("ADD")
    end

    self.entry = entry
    self.deliveryPending = deliveryPending
    self.Icon:SetAtlas(atlas)
    self.Icon:SetSize(isRejected and 16 or 14, isRejected and 16 or 14)
    self.Icon:SetAlpha(1)
    self.Icon:SetDesaturated(
        status ~= HironCraftScan.OrderFulfillment.Status.Fulfilled
            and status ~= HironCraftScan.OrderFulfillment.Status.Failed
    )
    self.Icon:SetVertexColor(unpack(color))
    -- Keep the cross itself opaque and add a separate additive halo. Applying
    -- ADD directly to the icon made its thin parts look translucent.
    self.Icon:SetBlendMode("BLEND")
    self.RejectGlow:SetShown(isRejected)
end

function HironCraftScanCraftingOrderStatusButtonMixin:OnClick(button)
    if button == "RightButton" and self.order then
        HironCraftScan.OrderFulfillment:ToggleManual(self.order)
        self:Refresh()
        self:OnEnter()
    end
end

function HironCraftScanCraftingOrderStatusButtonMixin:OnEnter()
    local entry = self.entry
    local status = entry and entry.status or HironCraftScan.OrderFulfillment.Status.Unknown
    local statusText = L("Crafting order status unknown")

    if status == HironCraftScan.OrderFulfillment.Status.Claimed then
        statusText = L("Crafting order status claimed")
    elseif status == HironCraftScan.OrderFulfillment.Status.Crafted then
        statusText = L("Crafting order status crafted")
    elseif status == HironCraftScan.OrderFulfillment.Status.Fulfilled then
        statusText = L("Crafting order status fulfilled")
    elseif status == HironCraftScan.OrderFulfillment.Status.Failed then
        statusText = L("Crafting order status failed")
    elseif status == HironCraftScan.OrderFulfillment.Status.Rejected then
        statusText = L("Crafting order status rejected")
    end

    GameTooltip:ClearLines()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L("Crafting order status"), 1, 0.82, 0)
    GameTooltip:AddLine(statusText, 1, 1, 1, true)
    if entry and entry.crafterFullName then
        GameTooltip:AddLine(string.format(L("Crafting order crafter"), HironCraftScan.NameAndRealmToName(entry.crafterFullName)), 0.8, 0.8, 0.8)
    end
    if entry and entry.updatedAt and entry.updatedAt > 0 then
        GameTooltip:AddLine(string.format(L("Crafting order updated"), date("%d.%m.%Y %H:%M", entry.updatedAt)), 0.8, 0.8, 0.8)
    end
    if self.deliveryPending then
        GameTooltip:AddLine(L("Crafting order sync pending"), 1, 0.82, 0, true)
    elseif entry and entry.deliveryConfirmedAt then
        GameTooltip:AddLine(
            string.format(
                L("Crafting order sync confirmed"),
                date("%d.%m.%Y %H:%M:%S", entry.deliveryConfirmedAt)
            ),
            0.3,
            1,
            0.3,
            true
        )
    end
    if entry then
        GameTooltip:AddLine(entry.automatic and L("Crafting order detected automatically") or L("Crafting order marked manually"), 0.65, 0.65, 0.65)
    end
    GameTooltip:AddLine(status == HironCraftScan.OrderFulfillment.Status.Fulfilled and L("Crafting order clear help") or L("Crafting order mark help"), 1, 0.82, 0, true)
    GameTooltip:Show()
end

function HironCraftScanCraftingOrderStatusButtonMixin:OnLeave()
    GameTooltip:Hide()
end

HironCraftScanChatPopOutButtonMixin = {}

local function PopulateChatHistory(order, chatFrame)
    local customerInfo = HironCraftScan.OrderToCustomerInfo(order)

    local accessID = ChatHistory_GetAccessID("WHISPER", order.customerName);
    for _, item in ipairs(customerInfo.chat_history) do
        -- With Prat, this leads to a double timestamp because they hook
        -- AddMessage to add the timestamp, and our message already includes a
        -- timestamp. Tried what they do by calling historyBuffer:PushBack, but
        -- that leads to scrollframe getting upset. I'm fine with the double
        -- timestamp for now.
        if item.args and tonumber(item.args[1]) and tonumber(item.args[2]) and tonumber(item.args[3]) then
            chatFrame:AddMessage(item.message, unpack(item.args))
        else
            local r, g, b = HironCraftScan.Utils.GetChatHistoryColor(item)
            chatFrame:AddMessage(item.message, r, g, b)
        end
    end
    chatFrame:ResetAllFadeTimes()
end

function HironCraftScanChatPopOutButtonMixin:OnClick(button)
    local order = self:GetParent().order;

    local liveCustomerInfo = HironCraftScan.OrderToLiveCustomerInfo(order, true)
    local liveResponses = HironCraftScan.OrderToLiveResponses(order, true)

    if button == "RightButton" or liveCustomerInfo.chatFrame then
        -- Right click only closes. Left click toggles
        if liveCustomerInfo and liveCustomerInfo.chatFrame then
            FCF_Close(liveCustomerInfo.chatFrame)
        end
    else
        if liveCustomerInfo and liveCustomerInfo.chatFrame then
            liveCustomerInfo.chatFrame:Clear();
            PopulateChatHistory(order, liveCustomerInfo.chatFrame)
            FCF_SelectDockFrame(liveCustomerInfo.chatFrame)
            return
        end

        local chatFrame = FCF_OpenTemporaryWindow("WHISPER", order.customerName, nil, true)
        PopulateChatHistory(order, chatFrame)
        liveCustomerInfo.chatFrame = chatFrame
        for _, response in pairs(liveResponses) do
            response.interactionFrame.Chat.SelectedHighlight:Show()
        end

        -- Handle close events triggered outside our control as well.
        hooksecurefunc("FCF_Close", function(frame)
            if frame == liveCustomerInfo.chatFrame then
                liveCustomerInfo.chatFrame = nil
                for _, response in pairs(liveResponses) do
                    response.interactionFrame.Chat.SelectedHighlight:Hide()
                end
            end
        end)
    end
end
