local HironCraftScan = select(2, ...)

HironCraftScanCrafterOrderListElementMixin = CreateFromMixins(TableBuilderRowMixin);

HironCraftScan.LIVE = {}
HironCraftScan.LIVE.customers = {}

local LID = HironCraftScan.CONST.TEXT;
local function L(id)
    return HironCraftScan.LOCAL:GetText(id);
end

local function SetTooltipWithTitle(tooltip, title, text)
    GameTooltip_SetTitle(tooltip, title);
    GameTooltip_AddNormalLine(tooltip, text);
end;

function HironCraftScanCrafterOrderListElementMixin:Init(elementData)
    self.order = elementData.order
    -- self.browseType = elementData.browseType;
    self.pageFrame = elementData.pageFrame;
    self.contextMenu = elementData.contextMenu;
    self:UpdateProgressHighlight()
end

local function removeOrder(orders, order, orderID)
    -- A saved list row can outlive its customer/response (including aliases
    -- removed by an earlier row). Always remove the row itself in that case.
    if not orderID then
        orderID = HironCraftScan.OrderToOrderID(order)
    end
    orders[orderID] = nil
    if HironCraftScan.State.activeOrder == order then
        HironCraftScan.State.activeOrder = nil
    end

    local customerInfo = HironCraftScan.OrderToCustomerInfo(order)
    if not customerInfo or type(customerInfo.responses) ~= 'table' or order.responseID == nil then
        return
    end

    -- Wipe out any less granular reponses related to this one
    local response = customerInfo.responses[order.responseID];
    if type(response) == 'table' and type(response.less_granular) == 'table' then
        for _, child in ipairs(response.less_granular) do
            local childResponse = customerInfo.responses[child]
            -- Do not delete a newer request that has since reused this alias.
            if childResponse == response or (type(childResponse) == 'table'
                and childResponse.responseID == order.responseID
                and childResponse.requestToken == response.requestToken
                and childResponse.time == response.time) then
                customerInfo.responses[child] = nil
            end
        end
    end
    customerInfo.responses[order.responseID] = nil

    -- I somehow managed to get a random empty entry in the responses table.
    -- Clear that out in case there's a bug somewhere creating them. No idea how
    -- it happened. Hopefully just something during development.
    for key, value in pairs(customerInfo.responses) do
        if type(value) == 'table' and not next(value) then
            customerInfo.responses[key] = nil;
        end
    end

    if not next(customerInfo.responses) then
        -- No more orders with this customer, so close out the frames related to them.
        local liveCustomerInfo = HironCraftScan.LIVE.customers[order.customerName]
        if liveCustomerInfo then
            if liveCustomerInfo.chatFrame then
                FCF_Close(liveCustomerInfo.chatFrame)
                liveCustomerInfo.chatFrame = nil
            end
            HironCraftScan.LIVE.customers[order.customerName] = nil
        end
        HironCraftScan.DB.customers[order.customerName] = nil
    end
end

function HironCraftScan.GreetCustomer(button, order)
    HironCraftScanScannerMenu:ClearAlert(order)

    local response = HironCraftScan.OrderToResponse(order)
    if not response then
        HironCraftScan.DismissOrder(order)
        return
    end
    if button == "LeftButton" or button == "MiddleButton" then
        HironCraftScan.QuickReplies:RememberConversationCharacter(response)
    end
    if button == "LeftButton" then
        if not response.greeting_sent then
            HironCraftScan.SendOrderGreeting(order, true)
            -- TODO: More efficient way to update the display?
            HironCraftScanCraftingOrderPage:ShowGeneric()
        else
            -- After sending the initial greeting, subsequent clicks open a chat with the customer.
            HironCraftScan.Utils.OpenCustomerChat(order.customerName)
        end
    elseif button == "MiddleButton" then
        -- Middle button to begin chat without the generated greeting
        if HironCraftScan.Utils.OpenCustomerChat(order.customerName) ~= false then
            response.greeting_sent = true
            if HironCraftScan.RequestTracking then
                HironCraftScan.RequestTracking.GreetingSent(HironCraftScan.OrderToCustomerInfo(order), {response})
            end
        end
    elseif button == "RightButton" then
        HironCraftScan.DismissOrder(order);
    end
end

function HironCraftScan.DismissOrder(order)
    removeOrder(HironCraftScan.DB.listed_orders, order)
    HironCraftScanCraftingOrderPage:ShowGeneric()
end

function HironCraftScanCrafterOrderListElementMixin:OnClick(button)
    HironCraftScan.GreetCustomer(button, self.order)
end

-- A conversation under way: the customer answered (second mark) and the
-- order is not delivered yet (no final third mark). These are the rows that
-- still need something from the crafter, so they carry a soft yellow wash.
function HironCraftScan.IsOrderInProgress(order)
    local response = order and HironCraftScan.OrderToResponse(order)
    if type(response) ~= 'table' or not response.customer_answered then return false end
    local fulfillment = HironCraftScan.OrderFulfillment
    local ok, entry = true, nil
    if fulfillment and fulfillment.GetStatus then ok, entry = pcall(fulfillment.GetStatus, fulfillment, order) end
    local status = ok and type(entry) == 'table' and entry.status or nil
    return status ~= 'fulfilled'
end

local PROGRESS_COLOR = { 1.00, 0.82, 0.20, 0.10 }

function HironCraftScanCrafterOrderListElementMixin:UpdateProgressHighlight()
    local inProgress = HironCraftScan.IsOrderInProgress(self.order)
    if not self.ProgressTexture then
        if not inProgress then return end
        -- Under the hover highlight, so hovering still shows on top of it.
        self.ProgressTexture = self:CreateTexture(nil, 'BACKGROUND', nil, -1)
        self.ProgressTexture:SetAllPoints()
        self.ProgressTexture:SetColorTexture(unpack(PROGRESS_COLOR))
    end
    self.ProgressTexture:SetShown(inProgress)
end

local chatTooltip = HironCraftScan.Utils.ChatHistoryTooltip:new();
function HironCraftScanCrafterOrderListElementMixin:OnLineEnter()
    self.HighlightTexture:Show();

    -- Pop up a tooltip that looks like the chat window. We copy
    -- the chat window width (up to a limit that fits over the crafting window),
    -- and the primary chat window's font settings. This seems to make the text
    -- wrapping match and overall it looks pretty close to the real chat window
    -- to give an easy refresher on prior interactions without popping out the
    -- dedicated chat frame.
    chatTooltip:Show("HironCraftScanChatHistoryTooltip", self, self.order,
        string.format(L("Chat History"), HironCraftScan.NameAndRealmToName(self.order.customerName)));
end

function HironCraftScanCrafterOrderListElementMixin:OnLineLeave()
    self.HighlightTexture:Hide();

    GameTooltip:Hide();
    chatTooltip:Hide();
    ResetCursor();
end

local function CreateAcceptLinkedAccountDialog()
    if not HironCraftScanComm:HavePendingPeerRequest() then
        return;
    end

    local OnAccept = function(nickname)
        HironCraftScanComm:AcceptPeerRequest(nickname);
    end
    local OnReject = function()
        HironCraftScanComm:RejectPeerRequest();
    end
    HironCraftScan.Dialog.Show({
        key = "accept_linked_account",
        title = L("Accept Linked Account"),
        submit = L("Accept Linked Account"),
        OnAccept = OnAccept,
        OnReject = OnReject,
        elements = {
            {
                type = HironCraftScan.Dialog.Element.Text,
                text = string.format(L(LID.ACCOUNT_LINK_ACCEPT_DST_INFO),
                    HironCraftScanComm:GetPendingPeerRequestCharacter(),
                    HironCraftScanComm:GetPendingPeerRequestPermissions()),
            },
            {
                type = HironCraftScan.Dialog.Element.EditBox,
            },
        },
    })
end

HironCraftScanCraftingOrderPageMixin = {} --CreateFromMixins(ProfessionsRecipeListPanelMixin);

function HironCraftScanCraftingOrderPageMixin:InitOrderListTable()
    local orderList = self.BrowseFrame.OrderList;
    orderList:SetHeight(HironCraftScan.DB.settings.order_list_height or 200);

    local pad = 5;
    local spacing = 1;
    local view = CreateScrollBoxListLinearView(pad, pad, pad, pad, spacing);
    view:SetElementInitializer("HironCraftScanCrafterOrderListElementTemplate", function(button, elementData)
        button:Init(elementData);
    end);
    ScrollUtil.InitScrollBoxListWithScrollBar(orderList.ScrollBox, orderList.ScrollBar, view);
end

function HironCraftScanCraftingOrderPageMixin:UpdateFilterResetVisibility()
    self.BrowseFrame.LeftPanel.CrafterList.FilterButton.ResetButton:SetShown(
        not HironCraftScan.IsUsingDefaultFilters(ignoreSkillLine));
end

function HironCraftScanCraftingOrderPageMixin:GetDesiredPageWidth()
    return 1105;
end

function HironCraftScanCraftingOrderPageMixin:OnLoad()
    HironCraftScan.Utils.onLoad(function()
        self:ResetSortOrder() -- self.InitButtons()
        self:InitOrderListTable()
        self:SetupOrderListTable()
        -- Analytics has a window of its own: the order list takes the height.
        self.BrowseFrame.OrderList:SetHeight(self.BrowseFrame.LeftPanel:GetHeight());
    end);
end

function HironCraftScanCraftingOrderPageMixin:OnShow()
    HironCraftScanScannerMenu:ClearPulses()
    -- Opening the page starts at the newest request. Subsequent refreshes only
    -- move the list when another order actually appears.
    self.renderedOrderIDs = nil
    self:ShowGeneric()

    local icon = HironCraftScan.Utils.GetCurrentProfessionIcon();
    self:SetPortraitToAsset(icon or 4620670);

    -- Since we are a UIPanel, Bliz tries to close all other windows, including
    -- the dialog we might try to open, so wait a sec then open any incoming
    -- requests.
    C_Timer.After(1, CreateAcceptLinkedAccountDialog);
end

function HironCraftScanCraftingOrderPageMixin:OnHide()
end

local function getOrderName(response)
    if response.itemID then
        local item = Item:CreateFromItemID(response.itemID);
        return item:GetItemName()
    else
        return response.equipmentLabel or response.professionName;
    end
end

local function ApplySortOrder(sortOrder, lhsOrder, rhsOrder)
    -- HironCraftScan.ChatOrderSortOrder = EnumUtil.MakeEnum("CustomerName", "CrafterName", "ProfessionName", "ItemName", "Interaction"); -- , "Sent");
    local lhs = HironCraftScan.OrderToResponse(lhsOrder);
    local rhs = HironCraftScan.OrderToResponse(rhsOrder);
    if sortOrder == HironCraftScan.ChatOrderSortOrder.ItemName then
        local lhsName = getOrderName(lhs)
        local rhsName = getOrderName(rhs)
        return SortUtil.CompareUtf8i(lhsName, rhsName)
    elseif sortOrder == HironCraftScan.ChatOrderSortOrder.CustomerName then
        return SortUtil.CompareUtf8i(lhsOrder.customerName, rhsOrder.customerName)
    elseif sortOrder == HironCraftScan.ChatOrderSortOrder.CrafterName then
        return SortUtil.CompareUtf8i(lhs.crafterName, rhs.crafterName)
    elseif sortOrder == HironCraftScan.ChatOrderSortOrder.ProfessionName then
        return SortUtil.CompareUtf8i(lhs.professionName, rhs.professionName)
    elseif sortOrder == HironCraftScan.ChatOrderSortOrder.Time then
        local now = time()
        local lhsAge = math.floor(now - lhs.time)
        local rhsAge = math.floor(now - rhs.time)
        return SortUtil.CompareNumeric(lhsAge, rhsAge)
    end
    return 0;
end

local function PurgeOldOrders()
    local orders = HironCraftScan.DB.listed_orders

    local now = time()
    local old = {}
    local timeout = HironCraftScan.Utils.GetSetting('customer_timeout') * 60;
    for orderID, order in pairs(orders) do
        local response = HironCraftScan.OrderToResponse(order)
        if not response or type(response.time) ~= 'number' or now - response.time > timeout then
            table.insert(old, { id = orderID, order = order })
        end
    end

    for _, entry in ipairs(old) do
        removeOrder(orders, entry.order, entry.id)
    end

    return #old ~= 0
end

local updateCellsScheduled = false
local ScheduleUpdateCells

local function UpdateCells()
    for customer, customerInfo in pairs(HironCraftScan.LIVE.customers) do
        for _, response in pairs(customerInfo.responses) do
            if response.updateAge then
                response.updateAge()
            end
        end
    end

    if PurgeOldOrders() then
        HironCraftScanCraftingOrderPage:ShowGeneric()
    else
        ScheduleUpdateCells()
    end
end

ScheduleUpdateCells = function()
    if updateCellsScheduled then return end
    updateCellsScheduled = true
    C_Timer.After(5, function()
        updateCellsScheduled = false
        UpdateCells()
    end)
end

local function SortItemsByComparator(items, keys, comparator)
    table.sort(items, function(lhs, rhs)
        local cmp = comparator(keys.primarySort.order, lhs, rhs);

        if cmp ~= 0 then
            if keys.primarySort.ascending then
                return cmp < 0
            else
                return cmp > 0
            end
        end

        if keys.secondarySort then
            cmp = comparator(keys.secondarySort.order, lhs, rhs);
            if keys.secondarySort.ascending then
                return cmp < 0
            else
                return cmp > 0
            end
        end

        return false;
    end);
end

local function ScrollOrderListToEnd(scrollBox)
    if not scrollBox or not C_Timer or not C_Timer.After then
        return
    end

    -- SetDataProvider lays out the ScrollBox on the next frame. Waiting one
    -- frame makes the final extent available and avoids landing one row above
    -- the newest order when the list has just crossed the visible-page limit.
    C_Timer.After(0, function()
        if not scrollBox or (scrollBox.IsShown and not scrollBox:IsShown()) then
            return
        end

        if scrollBox.HasScrollableExtent then
            local ok, hasExtent = pcall(scrollBox.HasScrollableExtent, scrollBox)
            if ok and not hasExtent then
                return
            end
        end

        if scrollBox.ScrollToEnd then
            local ok = pcall(scrollBox.ScrollToEnd, scrollBox)
            if ok then
                return
            end
        end

        -- Compatibility fallback for ScrollBox implementations that predate
        -- ScrollToEnd but still expose the normalized scroll percentage API.
        if scrollBox.SetScrollPercentage then
            pcall(scrollBox.SetScrollPercentage, scrollBox, 1)
        end
    end)
end

-- Two linked accounts on one machine often sit on different sides: a Horde
-- collector next to Alliance crafters. The other side's requests arrive
-- through the link and keep working underneath (statuses, crosses, "Done" go
-- back to the account that talked), but this character cannot whisper those
-- customers, so they are not listed or announced here. Logging in on a
-- character of that side brings them back.
function HironCraftScan.IsHiddenOtherSideOrder(order)
    if HironCraftScan.DB.settings.hide_other_faction_orders ~= true then return false end
    local quickReplies = HironCraftScan.QuickReplies
    if not quickReplies or not quickReplies.IsOtherSide or type(order) ~= 'table' then return false end
    -- A Battle.net friend is reachable from either side.
    if HironCraftScan.BattleNet and HironCraftScan.BattleNet.IsCustomer(order.customerName) then return false end
    local customerInfo = HironCraftScan.DB.customers and HironCraftScan.DB.customers[order.customerName]
    if type(customerInfo) ~= 'table' then return false end
    local response = customerInfo.responses and customerInfo.responses[order.responseID]
    local ok, other = pcall(quickReplies.IsOtherSide, quickReplies, customerInfo, response)
    return ok and other == true
end

function HironCraftScanCraftingOrderPageMixin:ShowGeneric()
    PurgeOldOrders()
    local scrollBox = self.BrowseFrame.OrderList.ScrollBox;
    scrollBox:Show();

    local dataProvider = CreateDataProvider();

    local orders = {}
    for _, order in pairs(HironCraftScan.DB.listed_orders) do
        if not HironCraftScan.IsHiddenOtherSideOrder(order) then
            table.insert(orders, order)
        end
    end

    SortItemsByComparator(orders, self, ApplySortOrder);

    local orderIDs = {}
    local hasNewOrder = self.renderedOrderIDs == nil
    for _, order in ipairs(orders) do
        local orderID = HironCraftScan.OrderToOrderID(order)
        local response = HironCraftScan.OrderToResponse(order)
        local identity = response and response.requestToken or true
        orderIDs[orderID] = identity
        if self.renderedOrderIDs and self.renderedOrderIDs[orderID] ~= identity then
            hasNewOrder = true
        end
    end
    self.renderedOrderIDs = orderIDs

    if #orders == 0 then
        self.BrowseFrame.OrderList.ResultsText:SetText(PROFESSIONS_CUSTOMER_NO_ORDERS);
        self.BrowseFrame.OrderList.ResultsText:Show();
    else
        self.BrowseFrame.OrderList.ResultsText:Hide();
    end

    for i, order in ipairs(orders) do
        dataProvider:Insert({
            order = order,
            pageFrame = self,
            contextMenu = self.BrowseFrame.OrderList.ContextMenu
        });
    end
    -- Most ShowGeneric calls are status/age refreshes. Preserve the user's
    -- current position through those provider replacements; a genuinely new
    -- order is moved into view explicitly below.
    scrollBox:SetDataProvider(
        dataProvider,
        ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition
    );

    if hasNewOrder and #orders > 0 then
        ScrollOrderListToEnd(scrollBox)
    end

    ScrollUtil.AddManagedScrollBarVisibilityBehavior(scrollBox, self.BrowseFrame.OrderList.ScrollBar, nil, nil);

    ScheduleUpdateCells()
end

function HironCraftScanCraftingOrderPageMixin:SortOrderIsValid(sortOrder)
    return sortOrder == HironCraftScan.ChatOrderSortOrder.ItemName or sortOrder == HironCraftScan.ChatOrderSortOrder.CustomerName
end

function HironCraftScanCraftingOrderPageMixin:ResetSortOrder()
    self.primarySort = {
        order = HironCraftScan.ChatOrderSortOrder.Time,
        ascending = false
    };

    self.secondarySort = nil;

    if self.tableBuilder then
        for frame in self.tableBuilder:EnumerateHeaders() do
            frame:UpdateArrow();
        end
    end
end

function HironCraftScanCraftingOrderPageMixin:GetSortOrder()
    return self.primarySort.order, self.primarySort.ascending;
end

function HironCraftScanCraftingOrderPageMixin:SetSortOrder(sortOrder)
    if self.primarySort.order == sortOrder then
        self.primarySort.ascending = not self.primarySort.ascending;
    else
        self.secondarySort = CopyTable(self.primarySort);
        self.primarySort = {
            order = sortOrder,
            ascending = true
        };
    end

    if self.tableBuilder then
        for frame in self.tableBuilder:EnumerateHeaders() do
            frame:UpdateArrow();
        end
    end

    self:ShowGeneric()
    -- if self.lastRequest then
    -- self.lastRequest.offset = 0; -- Get a fresh page of sorted results
    -- self:SendOrderRequest(self.lastRequest);
    -- end
end

function HironCraftScanCraftingOrderPageMixin:SetupOrderListTable()
    if not self.tableBuilder then
        self.tableBuilder = CreateTableBuilder(nil, HironCraftScanOrderTableBuilderMixin);
        local function ElementDataTranslator(elementData)
            return elementData;
        end
        ScrollUtil.RegisterTableBuilder(self.BrowseFrame.OrderList.ScrollBox, self.tableBuilder, ElementDataTranslator);

        local function ElementDataProvider(elementData)
            return elementData;
        end
        self.tableBuilder:SetDataProvider(ElementDataProvider);
    end

    self.tableBuilder:Reset();
    self.tableBuilder:SetColumnHeaderOverlap(2);
    self.tableBuilder:SetHeaderContainer(self.BrowseFrame.OrderList.HeaderContainer);
    self.tableBuilder:SetTableMargins(-3, 5);
    self.tableBuilder:SetTableWidth(777);

    local PTC = HironCraftScanTableConstants;

    self.tableBuilder:AddFillColumn(self, PTC.NoPadding, 1.0, 8, PTC.ItemName.RightCellPadding,
        HironCraftScan.ChatOrderSortOrder.ItemName, "HironCraftScanCrafterTableCellItemNameTemplate");

    self.tableBuilder:AddFixedWidthColumn(self, PTC.NoPadding, PTC.CustomerName.Width, PTC.CustomerName.LeftCellPadding,
        PTC.CustomerName.RightCellPadding, HironCraftScan.ChatOrderSortOrder.CustomerName,
        "HironCraftScanCrafterTableCellCustomerNameTemplate");

    self.tableBuilder:AddFixedWidthColumn(self, PTC.NoPadding, PTC.CrafterName.Width, PTC.CrafterName.LeftCellPadding,
        PTC.CrafterName.RightCellPadding, HironCraftScan.ChatOrderSortOrder.CrafterName,
        "HironCraftScanCrafterTableCellCrafterNameTemplate");

    self.tableBuilder:AddFixedWidthColumn(self, PTC.NoPadding, PTC.ProfessionName.Width,
        PTC.ProfessionName.LeftCellPadding, PTC.ProfessionName.RightCellPadding,
        HironCraftScan.ChatOrderSortOrder.ProfessionName,
        "HironCraftScanCrafterTableCellProfessionNameTemplate");

    self.tableBuilder:AddUnsortableFixedWidthColumn(self, PTC.NoPadding, PTC.Interaction.Width,
        PTC.Interaction.LeftCellPadding, PTC.Interaction.RightCellPadding, L("Replies"),
        "HironCraftScanCrafterTableCellInteractionTemplate");

    self.tableBuilder:AddFixedWidthColumn(self, PTC.NoPadding, PTC.Time.Width, PTC.Time.LeftCellPadding,
        PTC.Time.RightCellPadding, HironCraftScan.ChatOrderSortOrder.Time, "HironCraftScanCrafterTableCellTimeTemplate");

    -- AddUnsortableFixedWidthColumn

    -- self.tableBuilder:AddFixedWidthColumn(self, PTC.NoPadding, PTC.Tip.Width, PTC.Tip.LeftCellPadding,
    -- PTC.Tip.RightCellPadding, HironCraftScanSortOrder.Tip, "HironCraftScanCrafterTableCellActualCommissionTemplate");
    -- self.tableBuilder:AddFixedWidthColumn(self, PTC.NoPadding, PTC.Reagents.Width, PTC.Reagents.LeftCellPadding,
    -- PTC.Reagents.RightCellPadding, HironCraftScanSortOrder.Reagents, "HironCraftScanCrafterTableCellReagentsTemplate");
    -- self.tableBuilder:AddFixedWidthColumn(self, PTC.NoPadding, PTC.Expiration.Width, PTC.Expiration.LeftCellPadding,
    -- PTC.Expiration.RightCellPadding, HironCraftScanSortOrder.Expiration,
    -- "HironCraftScanCrafterTableCellExpirationTemplate");

    self.tableBuilder:Arrange();
end

local function ParentProfessionConfig(crafterInfo)
    return HironCraftScan.DB.characters[crafterInfo.name].parent_professions[crafterInfo.parentProfessionID];
end

-- States: 0 - all unchecked
--         1 - all checked
--         2 - indeterminate

local function ForEachProfession(op)
    local allTrue = true;
    local allFalse = true;
    for _, crafterConfig in pairs(HironCraftScan.DB.characters) do
        for _, ppConfig in pairs(crafterConfig.parent_professions) do
            if not ppConfig.character_disabled then
                local result = op(ppConfig);
                if result then
                    allFalse = false;
                else
                    allTrue = false;
                end
            end
        end
    end
    return allTrue and 1 or allFalse and 0 or 2;
end

local function ForEachCrafterFrame(op)
    for _, frame in pairs(HironCraftScanCraftingOrderPage.BrowseFrame.LeftPanel.CrafterList.ScrollBox:GetFrames()) do
        op(frame)
    end
end

-- We re-use the same template for the header that we use for the rows. The
-- callbacks check if they are the header and act on the whole list if so.
local crafterListAll = nil
local function IsAll(self)
    return self:GetParent() == crafterListAll
end

local function UpdateAllCheckBox(checkbox)
    local stateBefore = checkbox.state;
    checkbox.state =
        ForEachProfession(function(ppConfig)
            return ppConfig[checkbox.ppconfig_key];
        end);
    checkbox:UpdateAllCheckBoxDisplay();
    if stateBefore == 2 and checkbox.state ~= 2 then
        -- If we're applying the remote state, it has already taken the snapshot
        -- for us, so we skip that step here.
        if not HironCraftScanComm.applying_remote_state then
            checkbox:RememberAllUserState();
        end
    end
end

local function InitAllCheckBox(checkbox)
    if not checkbox.checked_texture then
        checkbox.indeterminate_texture = checkbox:CreateTexture();
        checkbox.indeterminate_texture:SetSize(12, 12);
        checkbox.indeterminate_texture:SetAllPoints(checkbox);
        checkbox.indeterminate_texture:SetAtlas(checkbox.indeterminate_atlas);
        checkbox.indeterminate_texture:Hide();

        checkbox.checked_texture = checkbox:GetCheckedTexture();
    end

    UpdateAllCheckBox(checkbox);
end

HironCraftScan_CrafterToggleMixin = {}

function HironCraftScan_CrafterToggleMixin:UpdateAllCheckBoxDisplay()
    self.indeterminate_texture:Hide();
    if self.state == 0 then
        self:SetChecked(false);
    elseif self.state == 1 then
        self:SetCheckedTexture(self.checked_texture);
        self:SetChecked(true);
    else
        self.indeterminate_texture:Show();
        self:SetCheckedTexture(self.indeterminate_texture);
        self:SetChecked(true);
    end
end

function HironCraftScan_CrafterToggleMixin:RememberAllUserState()
    -- Remember the most recent user specified state so we can restore it when
    -- clicking through to the indeterminate state.
    ForEachProfession(function(ppConfig)
        ppConfig[self.ppconfig_key .. "_last"] = ppConfig[self.ppconfig_key];
    end)
end

function HironCraftScan_CrafterToggleMixin:OnClick(button)
    if IsAll(self) then
        if self.state == 2 then
            -- Moving from indeterminate to all disabled. Remember the user
            -- configured states of each box so we can click back to
            -- indeterminate to restore it.
            self:RememberAllUserState();
            self.state = 0;
        elseif self.state == 1 then
            local rememberedState = ForEachProfession(function(ppConfig) return ppConfig[self.ppconfig_key .. "_last"]; end);
            if rememberedState == 2 then
                self.state = 2;
            else
                self.state = 0;
            end
        else
            self.state = 1;
        end

        if self.state ~= 2 then
            -- Manually moving everything to all on or all off.
            local checked = self.state == 1;
            ForEachProfession(function(ppConfig)
                ppConfig[self.ppconfig_key] = checked;
            end)

            ForEachCrafterFrame(function(frame)
                frame[self:GetName()]:SetChecked(checked);
            end)

            -- Push only the ppConfig of all characters across
            HironCraftScanComm:ShareAllPpCharacterModifications();
        else
            -- When moving to the indeterminate state manually, reapply the last
            -- user state.
            ForEachProfession(function(ppConfig)
                ppConfig[self.ppconfig_key] = ppConfig[self.ppconfig_key .. "_last"];
            end)

            -- And update the display to match the saved config.
            ForEachCrafterFrame(function(frame)
                frame[self:GetName()]:InitState();
            end)

            -- Push only the ppConfig of all characters across
            HironCraftScanComm:ShareAllPpCharacterModifications();
        end

        self:UpdateAllCheckBoxDisplay();
    else
        local crafterInfo = self:GetParent().crafterInfo;
        ParentProfessionConfig(crafterInfo)[self.ppconfig_key] = self:GetChecked();
        UpdateAllCheckBox(crafterListAll[self:GetName()])

        local ppChangeOnly = true;
        HironCraftScanComm:ShareCharacterModification(crafterInfo.name, crafterInfo.parentProfessionID, ppChangeOnly);
    end
    if GameTooltip:IsShown() then
        self:SetTooltip();
    end
end

function HironCraftScan_CrafterToggleMixin:InitState()
    self:SetChecked(ParentProfessionConfig(self:GetParent().crafterInfo)[self.ppconfig_key])
end

function HironCraftScan_CrafterToggleMixin:SetTooltip()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
    if self:GetChecked() then
        SetTooltipWithTitle(GameTooltip, L(self.enabled_tooltip), L(self.tooltip_details));
    else
        SetTooltipWithTitle(GameTooltip, L(self.disabled_tooltip), L(self.tooltip_details));
    end
    GameTooltip:Show();
end

function HironCraftScan_CrafterToggleMixin:OnEnter()
    self:GetParent().HoverBackground:Show();
    self:SetTooltip();
end

function HironCraftScan_CrafterToggleMixin:OnLeave()
    self:GetParent().HoverBackground:Hide();
    GameTooltip:Hide();
end

-- The analytics window, in place of the table that used to sit under the
-- order list.
-- The fit-to-screen setting was switched: apply it to the open windows.
function HironCraftScan.ApplyFitToScreen()
    local page = HironCraftScanCraftingOrderPage
    local on = HironCraftScan.Utils.FitsScreen()
    if page and SetUIPanelAttribute then
        SetUIPanelAttribute(page, 'checkFit', on and 1 or 0)
        if page:IsShown() then HironCraftScan.Utils.FitFrame(page, 20, 50) end
    end
    if HironCraftScan.AnalyticsWindow and HironCraftScan.AnalyticsWindow.Refit then
        HironCraftScan.AnalyticsWindow.Refit()
    end
end

HironCraftScan_OpenAnalyticsButtonMixin = {}

function HironCraftScan_OpenAnalyticsButtonMixin:OnLoad()
    self:SetText(L("Analytics"))
    self:FitToText();
end

function HironCraftScan_OpenAnalyticsButtonMixin:OnClick()
    if HironCraftScan.AnalyticsWindow then
        HironCraftScan.AnalyticsWindow.Toggle()
    end
end

function HironCraftScan:GetSortedCrafters()
    local crafterRows = {}
    for name, info in pairs(HironCraftScan.DB.characters) do
        for parentProfessionID, ppInfo in pairs(info.parent_professions) do
            if not ppInfo.character_disabled then
                table.insert(crafterRows, {
                    name = name,
                    parentProfessionID = parentProfessionID,
                })
            end
        end
    end

    -- Sort characters so all primary crafters appear first, then alphabetically within the two groups.
    table.sort(crafterRows, function(lhs, rhs)
        local lhsPpConfig = HironCraftScan.DB.characters[lhs.name].parent_professions[lhs.parentProfessionID];
        local rhsPpConfig = HironCraftScan.DB.characters[rhs.name].parent_professions[rhs.parentProfessionID];

        local secondarySort = function()
            if lhs.name ~= rhs.name then
                return lhs.name < rhs.name
            end

            local lhsProfInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(lhs.parentProfessionID);
            local rhsProfInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(rhs.parentProfessionID);

            return lhsProfInfo.professionName < rhsProfInfo.professionName
        end

        if lhsPpConfig.primary_crafter then
            if rhsPpConfig.primary_crafter then
                return secondarySort()
            end
            return true;
        end

        if rhsPpConfig.primary_crafter then
            return false;
        end

        return secondarySort()
    end)
    return crafterRows;
end

HironCraftScan_CrafterListMixin = {}

function HironCraftScan_CrafterListMixin:SetupCrafterList()
    crafterListAll = self.CrafterListAllButton;

    InitAllCheckBox(crafterListAll.EnabledCheckBox)
    InitAllCheckBox(crafterListAll.SoundAlertCheckBox)
    InitAllCheckBox(crafterListAll.VisualAlertCheckBox)
    InitAllCheckBox(crafterListAll.LocalAlertCheckBox)

    -- TODO Make this big and find a better texture
    crafterListAll.CrafterName:SetText(L("All crafters"))
    crafterListAll:Show();

    local topPadding = 3;
    local leftPadding = 4;
    local rightPadding = 2;
    local spacing = 1;
    local view = CreateScrollBoxListLinearView(topPadding, 0, leftPadding, rightPadding, spacing);

    local function FrameInitializer(frame, crafterInfo)
        local crafterName = HironCraftScan.ColorizeCrafterName(crafterInfo.name)
        frame.CrafterName:SetText(crafterName)
        frame.crafterInfo = crafterInfo
        frame.EnabledCheckBox:InitState()
        frame.SoundAlertCheckBox:InitState()
        frame.VisualAlertCheckBox:InitState()
        frame.LocalAlertCheckBox:InitState()
        frame.ProfessionIcon:SetTexture(C_TradeSkillUI.GetTradeSkillTexture(crafterInfo.parentProfessionID))
        frame:RegisterForClicks("AnyUp");

        local profInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(crafterInfo.parentProfessionID);
        frame.ProfessionName:SetText(HironCraftScan.Utils.ColorizeProfessionName(profInfo.professionID,
            profInfo.professionName))

        if HironCraftScan.DB.characters[crafterInfo.name].parent_professions[crafterInfo.parentProfessionID].primary_crafter then
            frame.PrimaryCrafterIcon:Show();
        else
            frame.PrimaryCrafterIcon:Hide();
        end
        frame.LinkedAccountIcon:Init(frame.crafterInfo);
    end

    view:SetElementFactory(function(factory)
        factory("HironCraftScanCrafterListElementTemplate", FrameInitializer);
    end);

    ScrollUtil.InitScrollBoxListWithScrollBar(self.ScrollBox, self.ScrollBar, view);

    -- Highly unlikely to ever need a scroll bar, so hide it unless needed.
    -- Tested one time with 20 dummy characters in the config and the scroll
    -- bar did appear and was usable.
    ScrollUtil.AddManagedScrollBarVisibilityBehavior(self.ScrollBox, self.ScrollBar, nil,
        nil);


    local crafterRows = HironCraftScan.GetSortedCrafters();
    local dataProvider = CreateDataProvider(crafterRows)
    self.ScrollBox:SetDataProvider(dataProvider, ScrollBoxConstants.RetainScrollPosition);
end

function HironCraftScan_CrafterListMixin:OnShow()
    self:SetupCrafterList();
end

HironCraftScanCrafterListElementMixin = {}

function HironCraftScanCrafterListElementMixin:OnEnter()
    self.HoverBackground:Show();
end

function HironCraftScanCrafterListElementMixin:OnLeave()
    self.HoverBackground:Hide();
end

function HironCraftScan.OnCrafterListModified()
    if HironCraftScanCraftingOrderPage.BrowseFrame.LeftPanel.CrafterList:IsShown() then
        -- Refresh the list to display the change.
        HironCraftScanCraftingOrderPage.BrowseFrame.LeftPanel.CrafterList:SetupCrafterList();
    end

    -- Reload the scanner data to apply the change.
    HironCraftScan.Scanner.LoadConfig()
end

-- Provide common properties for our various confirmations.
local function SetupPopupDialog(key, config)
    local popup = {
        button2 = "Cancel",
        OnCancel = nil,
        hasEditBox = true,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3, -- Avoid UI taint issues by using a higher index
        EditBoxOnEnterPressed = function(self)
            local parent = self:GetParent()
            parent:GetButton1():Click() -- Simulate a click on the Confirm button
        end,
        EditBoxOnEscapePressed = function(self)
            local parent = self:GetParent()
            parent:GetButton2():Click() -- Simulate a click on the Cancel button
        end,
    };
    for key, value in pairs(config) do
        popup[key] = value;
    end
    StaticPopupDialogs[key] = popup;
end

function HironCraftScan.RemoveChildProfessions(charConfig, ppID)
    local pConfigs = charConfig.professions;
    for profID, config in pairs(pConfigs) do
        if config.parentProfID == ppID then
            pConfigs[profID] = nil;
        end
    end
end

-- The confirmation dialog to 'disable' a profession for a specific character.
SetupPopupDialog("HIRONCRAFT_SCAN_CONFIRM_CONFIG_DELETE", {
    text = L(LID.DELETE_CONFIG_TOOLTIP_TEXT) .. '\n\n' .. L(LID.DELETE_CONFIG_CONFIRM),
    button1 = "Delete",
    OnAccept = function(self, crafterInfo)
        local userInput = self.EditBox:GetText()
        if string.lower(userInput) == "delete" then
            local charConfig = HironCraftScan.DB.characters[crafterInfo.name];

            -- Flag the profession as disabled. We don't fully delete it
            -- because we want to remember that the user disabled it so
            -- we don't keep re-enabling it when they open the
            -- profession window.
            local parentProfID = crafterInfo.parentProfessionID;

            -- Wipe the ppConfig to a clean slate.
            local rev = charConfig.parent_professions[parentProfID].rev;
            charConfig.parent_professions[parentProfID] = HironCraftScan.Utils.DeepCopy(HironCraftScan.CONST.DEFAULT_PPCONFIG);
            local ppConfig = charConfig.parent_professions[parentProfID];
            ppConfig.rev = rev; -- The revision needs to persist through disable/enable cycles so we know which side wins.
            ppConfig.character_disabled = true;

            -- Delete all details about the expansion level professions.
            HironCraftScan.RemoveChildProfessions(charConfig, parentProfID);

            -- Send the modification to any linked accounts.
            local ppChangeOnly = true;
            HironCraftScanComm:ShareCharacterModification(crafterInfo.name, parentProfID, ppChangeOnly);

            HironCraftScan.Config.RemoveMissingProfessionNodes(crafterInfo.name)
            HironCraftScan.OnCrafterListModified();
            HironCraftScan.Events:Emit('CHARACTER_DISABLED', crafterInfo.name, parentProfID)
        else
            print("HironCraftScan confirmation failed.")
        end
    end
})

-- The confirmation dialog to 'cleanup' a profession for a specific character.
SetupPopupDialog("HIRONCRAFT_SCAN_CONFIRM_CONFIG_CLEANUP", {
    text = L(LID.CLEANUP_CONFIG_TOOLTIP_TEXT) .. '\n\n' .. L(LID.CLEANUP_CONFIG_CONFIRM),
    button1 = "Cleanup",
    OnAccept = function(self, crafterInfo)
        local userInput = self.EditBox:GetText()
        if string.lower(userInput) == "cleanup" then
            local charConfig = HironCraftScan.DB.characters[crafterInfo.name];

            -- Fully delete the parent profession and all references to it
            local parentProfID = crafterInfo.parentProfessionID;
            charConfig.parent_professions[parentProfID] = nil;

            local pConfigs = charConfig.professions;
            for profID, config in pairs(pConfigs) do
                if config.parentProfID == parentProfID then
                    pConfigs[profID] = nil;
                end
            end

            HironCraftScan.Config.RemoveMissingProfessionNodes(crafterInfo.name)
            HironCraftScan.OnCrafterListModified();
        else
            print("HironCraftScan confirmation failed.")
        end
    end
})

HironCraftScan_PrimaryCrafterIconMixin = {}

function HironCraftScan_PrimaryCrafterIconMixin:OnShow()
    local linkedAccount = self:GetParent().LinkedAccountIcon;
    linkedAccount:ClearAllPoints()
    linkedAccount:SetPoint("LEFT", self, "RIGHT", 2, 0)
end

function HironCraftScan_PrimaryCrafterIconMixin:OnHide()
    local linkedAccount = self:GetParent().LinkedAccountIcon;
    if linkedAccount then
        linkedAccount:ClearAllPoints()
        linkedAccount:SetPoint("LEFT", self:GetParent().CrafterName, "RIGHT", 2, 0)
    end
end

HironCraftScan_LinkedAccountIconMixin = {}

function HironCraftScan_LinkedAccountIconMixin:Init(crafterInfo)
    -- GetParent() doesn't return during OnLoad, so we have a manual init call
    -- to receive the crafterInfo directly.
    local charConfig = HironCraftScan.DB.characters[crafterInfo.name];
    if charConfig.sourceID and charConfig.sourceID ~= HironCraftScan.DB.settings.my_uuid then
        self:Show();
    else
        self:Hide();
    end
end

function HironCraftScan_LinkedAccountIconMixin:OnEnter()
    local crafter = self:GetParent().crafterInfo.name;
    local sourceID = HironCraftScan.DB.characters[crafter].sourceID;
    local nickname = HironCraftScan.DB.realm.linked_accounts[sourceID].nickname;

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
    GameTooltip:SetText(string.format(L(LID.REMOTE_CRAFTER_SUMMARY), nickname));
    GameTooltip:Show()
end

function HironCraftScan_LinkedAccountIconMixin:OnLeave()
    GameTooltip:Hide()
end

HironCraftScan_ProxyEnabledMixin = {}

function HironCraftScan_ProxyEnabledMixin:OnShow()
    local value = HironCraftScan.DB.settings[self.key] or false;
    self:SetChecked(value);
    self.Text:SetText(L(self.key));
end

function HironCraftScan_ProxyEnabledMixin:OnClick()
    HironCraftScan.DB.settings[self.key] = not HironCraftScan.DB.settings[self.key];

    -- If disabled out in the world, we need a kick to hide the button.
    HironCraftScanScannerMenu:UpdateFrameVisibility();
end

function HironCraftScan_ProxyEnabledMixin:OnEnter()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
    GameTooltip:SetText(L(LID[self.tooltip]), 1, 1, 1, 1, true)
    GameTooltip:Show()
end

function HironCraftScan_ProxyEnabledMixin:OnLeave()
    GameTooltip:Hide()
end

HironCraftScan_LinkAccountButtonMixin = {}

function HironCraftScan_LinkAccountButtonMixin:Reset()
    self:SetText(L("Link Account"));
    self:FitToText();
end

function HironCraftScan_LinkAccountButtonMixin:OnShow()
    self:Reset();
end

function HironCraftScan_LinkAccountButtonMixin:OnLoad()
    self:Reset();
end

function HironCraftScan_LinkAccountButtonMixin:OnClick()
    local Validator = function(fullcontrol, analytics, character, nickname)
        return fullcontrol == true or analytics == true;
    end

    local OnAccept = function(fullcontrol, analytics, character, nickname)
        if not HironCraftScan.State.realmID and string.find(character, "-") == nil then
            -- On non-connected realms, hardcode the realm to our own to
            -- avoid auto-complete on whisper sending to our own characters
            -- on other realms.
            character = HironCraftScan.GetUnitName(character, true, true);
        end
        local permissions = {};
        if fullcontrol then
            table.insert(permissions, HironCraftScanComm.Permissions.Full);
        elseif analytics then
            table.insert(permissions, HironCraftScanComm.Permissions.Analytics);
        end
        HironCraftScanComm:SendHandshake(character, nickname, permissions);
    end
    local elements = {
        {
            type = HironCraftScan.Dialog.Element.Text,
            text = L(LID.ACCOUNT_LINK_DESC),
        },
        {
            type = HironCraftScan.Dialog.Element.Text,
            text = L(LID.ACCOUNT_LINK_PERMISSIONS_DESC),
        },
        {
            type = HironCraftScan.Dialog.Element.CheckButton,
            default = true,
            text = L(HironCraftScanComm.PermissionStrings[HironCraftScanComm.Permissions.Full].name),
            description = L(HironCraftScanComm.PermissionStrings[HironCraftScanComm.Permissions.Full].desc),
        },
        {
            type = HironCraftScan.Dialog.Element.CheckButton,
            text = L(HironCraftScanComm.PermissionStrings[HironCraftScanComm.Permissions.Analytics].name),
            description = L(HironCraftScanComm.PermissionStrings[HironCraftScanComm.Permissions.Analytics].desc),
        },
        {
            type = HironCraftScan.Dialog.Element.Text,
            text = L(LID.ACCOUNT_LINK_PROMPT_CHARACTER),
            padding = 10,
        },
        {
            type = HironCraftScan.Dialog.Element.EditBox,
        },
        {
            type = HironCraftScan.Dialog.Element.Text,
            text = L(LID.ACCOUNT_LINK_PROMPT_NICKNAME),
            padding = 10,
        },
        {
            type = HironCraftScan.Dialog.Element.EditBox,
        },
    }
    HironCraftScan.Dialog.Show({
        key = "link_account",
        title = L("Link Account"),
        submit = L("Link Account"),
        Validator = Validator,
        OnAccept = OnAccept,
        elements = elements,
    })
end

function HironCraftScan.OnPendingPeerAdded()
    HironCraftScanCraftingOrderPage.BrowseFrame.LeftPanel.LinkAccountControls.LinkAccountButton:Reset();

    if HironCraftScanCraftingOrderPage:IsShown() then
        CreateAcceptLinkedAccountDialog();
    end
end

function HironCraftScan.OnPendingPeerAccepted()
    HironCraftScanCraftingOrderPage.BrowseFrame.LeftPanel.LinkedAccountList:Init();
end

HironCraftScan_LinkedAccountListMixin = {}

function HironCraftScan_LinkedAccountListMixin:OnShow()
    self:Init();
end

function FormatTimeAgo(pastTime)
    local currentTime = time()
    local diff = currentTime - pastTime

    if diff < 60 then
        return diff .. "s"
    elseif diff < 3600 then
        local minutes = math.floor(diff / 60)
        return minutes .. "m"
    else
        local hours = math.floor(diff / 3600)
        return hours .. "h"
    end
end

function HironCraftScan_LinkedAccountListMixin:Init()
    -- If there are linked accounts, show additional controls for them.
    -- Otherwise, we only show the button to create a link.
    local showList = HironCraftScan.DB.realm.linked_accounts and next(HironCraftScan.DB.realm.linked_accounts);

    local linkAccountControls = self:GetParent().LinkAccountControls;
    if showList then
        linkAccountControls:SetHeight(70)
        linkAccountControls.ProxyReceiveEnabled:Show();
        linkAccountControls.ProxySendEnabled:Show();
    else
        linkAccountControls:SetHeight(35)
        linkAccountControls.ProxyReceiveEnabled:Hide();
        linkAccountControls.ProxySendEnabled:Hide();
    end

    local crafterList = self:GetParent().CrafterList;
    crafterList:ClearAllPoints();
    crafterList:SetPoint("TOPLEFT", self:GetParent(), "TOPLEFT", 0, 0);
    crafterList:SetPoint("BOTTOMLEFT", linkAccountControls, "TOPLEFT", 0, showList and 105 or 0);

    if not showList then
        self:Hide();
        return;
    end

    self.Title:SetText(L("Linked Accounts"));

    local topPadding = 3;
    local leftPadding = 4;
    local rightPadding = 2;
    local spacing = 1;
    local view = CreateScrollBoxListLinearView(topPadding, 0, leftPadding, rightPadding, spacing);

    local function FrameInitializer(frame, linkedAccount)
        frame.linkedAccount = linkedAccount;
        frame.AccountName:SetText(linkedAccount.info.nickname);
        frame.UpdateDisplay = function(frame)
            local linkedAccount = frame.linkedAccount;
            local connectedTo, lastSeen = HironCraftScanComm:LinkState(linkedAccount.sourceID);
            frame.LinkState:SetText(connectedTo and
                string.format(L(LID.LINK_ACTIVE), HironCraftScan.NameAndRealmToName(connectedTo, true),
                    FormatTimeAgo(lastSeen)) or
                FRIENDS_LIST_OFFLINE);

            frame.StatusIcon:SetTexture(connectedTo and FRIENDS_TEXTURE_ONLINE or FRIENDS_TEXTURE_OFFLINE);
        end
        frame.UpdateDisplay(frame);
    end

    view:SetElementFactory(function(factory)
        factory("HironCraftScan_LinkedAccountListElementTemplate", FrameInitializer);
    end);

    ScrollUtil.InitScrollBoxListWithScrollBar(self.ScrollBox, self.ScrollBar, view);

    -- Highly unlikely to ever need a scroll bar, so hide it unless needed.
    -- Tested one time with 20 dummy characters in the config and the scroll
    -- bar did appear and was usable.
    ScrollUtil.AddManagedScrollBarVisibilityBehavior(self.ScrollBox, self.ScrollBar, nil,
        nil);

    local linkedAccounts = {}
    for sourceID, info in pairs(HironCraftScan.DB.realm.linked_accounts) do
        table.insert(linkedAccounts, {
            sourceID = sourceID,
            info = info
        });
    end

    -- Sort characters so all primary crafters appear first, then alphabetically within the two groups.
    table.sort(linkedAccounts, function(lhs, rhs)
        return lhs.info.nickname < rhs.info.nickname;
    end)

    local dataProvider = CreateDataProvider(linkedAccounts)
    self.ScrollBox:SetDataProvider(dataProvider, ScrollBoxConstants.RetainScrollPosition);

    local function UpdateDisplay()
        if HironCraftScanCraftingOrderPage:IsShown() then
            for _, frame in pairs(HironCraftScanCraftingOrderPage.BrowseFrame.LeftPanel.LinkedAccountList.ScrollBox:GetFrames()) do
                frame.UpdateDisplay(frame);
            end

            C_Timer.After(5, self.UpdateDisplay)
        end
    end

    if self.UpdateDisplay then
        self.UpdateDisplay:Cancel();
    end
    self.UpdateDisplay = C_FunctionContainers.CreateCallback(UpdateDisplay);
    UpdateDisplay();

    self:Show();
end

HironCraftScan_LinkedAccountListElementMixin = {}

function HironCraftScan_LinkedAccountListElementMixin:OnClick()
    local linkedAccountID = self.linkedAccount.sourceID;
    local linkedAccount = self.linkedAccount.info;
    MenuUtil.CreateContextMenu(owner, function(owner, rootDescription)
        local hasFull = HironCraftScan.Utils.Contains(linkedAccount.permissions, HironCraftScanComm.Permissions.Full);
        local hasAnalytics = HironCraftScan.Utils.Contains(linkedAccount.permissions, HironCraftScanComm.Permissions.Analytics);

        local crafterList = {}
        for char, charConfig in pairs(HironCraftScan.DB.characters) do
            if charConfig.sourceID == linkedAccountID then
                table.insert(crafterList, HironCraftScan.NameAndRealmToName(char));
            end
        end


        do
            rootDescription:CreateTitle(linkedAccount.nickname);
            rootDescription:QueueDivider();

            if hasFull then
                rootDescription:QueueTitle(
                    L(HironCraftScanComm.PermissionStrings[HironCraftScanComm.Permissions.Full].name));
            else
                for _, perm in ipairs(linkedAccount.permissions) do
                    rootDescription:QueueTitle(L(HironCraftScanComm.PermissionStrings[perm].name));
                end
            end
        end
        do
            rootDescription:QueueDivider();
            rootDescription:QueueTitle(L("Backup characters"));
            local OnClick = function(char)
                for i, backup_char in ipairs(linkedAccount.backup_chars) do
                    if char == backup_char then
                        table.remove(linkedAccount.backup_chars, i)
                        break
                    end
                end
            end

            for _, char in ipairs(linkedAccount.backup_chars) do
                local popoutButton = rootDescription:CreateButton(char);
                popoutButton:CreateButton(L("Remove"), OnClick, char);
            end

            do
                local OnClick = function()
                    local function AddChar(char)
                        if not HironCraftScan.State.realmID and string.find(char, "-") == nil then
                            -- Normalize adding the current realm onto
                            -- non-connected realms that don't provide it.
                            char = HironCraftScan.GetUnitName(char, true);
                        end

                        table.insert(HironCraftScan.DB.realm.linked_accounts[linkedAccountID].backup_chars, char);
                    end
                    HironCraftScan.Dialog.Show({
                        key = "add_backup_char",
                        title = L("Add character"),
                        submit = L("Add character"),
                        OnAccept = AddChar,
                        elements = {
                            {
                                type = HironCraftScan.Dialog.Element.Text,
                                text = string.format(L(LID.ACCOUNT_LINK_ADD_CHAR)),
                            },
                            {
                                type = HironCraftScan.Dialog.Element.EditBox,
                            },
                        },
                    });
                end

                local button = rootDescription:CreateButton(L("Add"), OnClick, nil)
            end
        end
        do
            rootDescription:QueueDivider();
            rootDescription:CreateButton(L("Refresh connection"), function()
                HironCraftScanComm:RefreshLinkedAccount(linkedAccountID);
            end, nil);
        end
        if hasFull or hasAnalytics then
            rootDescription:QueueDivider();
            do
                -- Normally analytics is exchanged by itself in a quiet period.
                local function OnClick()
                    if HironCraftScan.AnalyticsSync then HironCraftScan.AnalyticsSync.SyncNow() end
                end

                rootDescription:CreateButton(L("Exchange analytics now"), OnClick, nil)
            end
        end
        rootDescription:QueueDivider();
        do
            local function DoRename(nickname)
                linkedAccount.nickname = nickname;
                HironCraftScanCraftingOrderPage.BrowseFrame.LeftPanel.LinkedAccountList:Init();
            end

            local OnClick = function()
                HironCraftScan.Dialog.Show({
                    key = "rename_linked_account",
                    title = L("Rename account"),
                    submit = L("Rename account"),
                    OnAccept = DoRename,
                    elements = {
                        {
                            type = HironCraftScan.Dialog.Element.Text,
                            text = L("New name"),
                        },
                        {
                            type = HironCraftScan.Dialog.Element.EditBox,
                        },
                    },
                });
            end

            rootDescription:CreateButton(L("Rename account"), OnClick, nil)
        end

        do
            local function DoDelete()
                for char, charConfig in pairs(HironCraftScan.DB.characters) do
                    if charConfig.sourceID == linkedAccountID then
                        HironCraftScan.DB.characters[char] = nil;
                    end
                end
                HironCraftScan.DB.realm.linked_accounts[linkedAccountID] = nil;

                HironCraftScanCraftingOrderPage.BrowseFrame.LeftPanel.LinkedAccountList:Init();
                HironCraftScan.OnCrafterListModified();
            end

            local OnClick = function()
                HironCraftScan.Dialog.Show({
                    key = "delete_linked_account",
                    title = L("Delete Linked Account"),
                    submit = L("Delete Linked Account"),
                    OnAccept = DoDelete,
                    elements = {
                        {
                            type = HironCraftScan.Dialog.Element.Text,
                            text = string.format(L(LID.ACCOUNT_LINK_DELETE_INFO), linkedAccount.nickname,
                                table.concat(crafterList, "\n")),
                        },
                    },
                });
            end

            rootDescription:CreateButton(L("Unlink account"), OnClick, nil)
        end
    end);
end

function HironCraftScan_LinkedAccountListElementMixin:OnEnter()
    self.HoverBackground:Show();
end

function HironCraftScan_LinkedAccountListElementMixin:OnLeave()
    self.HoverBackground:Hide();
end

function HironCraftScan.OnLinkedAccountStateChange()
    if HironCraftScanCraftingOrderPage.BrowseFrame.LeftPanel.LinkedAccountList:IsShown() then
        HironCraftScanCraftingOrderPage.BrowseFrame.LeftPanel.LinkedAccountList:Init();
    end
end

local function ProcessPrimaryCrafterUpdate(crafterInfo, ppConfig)
    -- We can only have one primary crafter for a given profession, so walk the
    -- list and turn off the others.
    if not ppConfig.primary_crafter then
        return
    end

    for char, charConfig in pairs(HironCraftScan.DB.characters) do
        if char ~= crafterInfo.name then
            for parentProfID, parentProfConfig in pairs(charConfig.parent_professions) do
                if parentProfID == crafterInfo.parentProfessionID and parentProfConfig.primary_crafter then
                    parentProfConfig.primary_crafter = false;

                    local ppChangeOnly = true;
                    HironCraftScanComm:ShareCharacterModification(char, parentProfID, ppChangeOnly);

                    return; -- There can only be one.
                end
            end
        end
    end
end

local function SetTooltipWithTitleFromData(tooltip, elementDescription)
    local data = elementDescription:GetData();
    SetTooltipWithTitle(tooltip, data.tooltipTitle or MenuUtil.GetElementText(elementDescription), data.tooltipText);
end;

-- We only register for RightButton on the individual character rows, not the
-- 'All Crafters' row, so we don't need to filter it out.
function HironCraftScanCrafterListElementMixin:OnClick(button)
    if button == 'LeftButton' then
        self.EnabledCheckBox:SetChecked(not self.EnabledCheckBox:GetChecked())
        self.EnabledCheckBox:OnClick()
        return
    end

    -- Create a context menu to operate on the character's saved
    -- configuration. This allows easily cleanup of an alt army. Any
    -- destructive operations have confirmations since it is easy to
    -- accidentally click something in a context menu.
    local profInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(self.crafterInfo.parentProfessionID);
    local profName = HironCraftScan.Utils.ColorizeProfessionName(profInfo.professionID,
        profInfo.professionName);
    local crafter = HironCraftScan.NameAndRealmToName(self.crafterInfo.name);

    local charConfig = HironCraftScan.DB.characters[self.crafterInfo.name];
    local ppConfig = charConfig.parent_professions[self.crafterInfo.parentProfessionID];

    MenuUtil.CreateContextMenu(owner, function(owner, rootDescription)
        local isRemoteCrafter = charConfig.sourceID and charConfig.sourceID ~= HironCraftScan.DB.settings.my_uuid;
        do
            local title = rootDescription:CreateTitle(HironCraftScan.NameAndRealmToName(self.crafterInfo.name));
            if isRemoteCrafter then
                title:SetTooltip(function(tooltip)
                    --GameTooltip_SetTitle(tooltip, data.tooltipTitle or MenuUtil.GetElementText(elementDescription));
                    GameTooltip_AddNormalLine(tooltip, L(LID.REMOTE_CRAFTER_TOOLTIP));
                end);
            end
        end
        do
            local onClick = function()
                StaticPopup_Show("HIRONCRAFT_SCAN_CONFIRM_CONFIG_DELETE", profName, crafter, self.crafterInfo)
            end
            local data = {
                tooltipText = string.format(L(LID.DELETE_CONFIG_TOOLTIP_TEXT), profName, crafter)
            };
            local button = rootDescription:CreateButton(L("Disable"), onClick, data)

            if isRemoteCrafter then
                button:SetEnabled(false);
            else
                button:SetTooltip(SetTooltipWithTitleFromData);
            end
        end
        do
            local onClick = function()
                StaticPopup_Show("HIRONCRAFT_SCAN_CONFIRM_CONFIG_CLEANUP", profName, crafter, self.crafterInfo)
            end
            local data = {
                tooltipText = string.format(L(LID.CLEANUP_CONFIG_TOOLTIP_TEXT), profName, crafter),
            };
            local button = rootDescription:CreateButton(L("Cleanup"), onClick, data)
            button:SetTooltip(SetTooltipWithTitleFromData);
        end
        do
            local IsSelected = function()
                return ppConfig.primary_crafter;
            end
            local SetSelected = function()
                ppConfig.primary_crafter = not ppConfig.primary_crafter;
                ProcessPrimaryCrafterUpdate(self.crafterInfo, ppConfig)
                HironCraftScan.OnCrafterListModified();

                local ppChangeOnly = true;
                HironCraftScanComm:ShareCharacterModification(self.crafterInfo.name, self.crafterInfo.parentProfessionID,
                    ppChangeOnly);
            end
            local data = {
                tooltipText = string.format(L(LID.PRIMARY_CRAFTER_TOOLTIP), crafter, profName),
            };
            local button = rootDescription:CreateCheckbox(L("Primary Crafter"), IsSelected, SetSelected, data)
            button:SetTooltip(SetTooltipWithTitleFromData);
        end
    end);
end

HironCraftScan_CrafterListAllButtonMixin = {}

function HironCraftScan_CrafterListAllButtonMixin:OnEnter()
    self.HoverBackground:Show();
end

function HironCraftScan_CrafterListAllButtonMixin:OnLeave()
    self.HoverBackground:Hide();
end

function HironCraftScan_CrafterListAllButtonMixin:OnClick()
    self.EnabledCheckBox:SetChecked(not self.EnabledCheckBox:GetChecked())
    self.EnabledCheckBox:OnClick()
end

HironCraftScan_AddonToggleButtonMixin = {}

function HironCraftScan_AddonToggleButtonMixin:OnClick(button)
    HironCraftScan.Utils.ToggleSavedAddons()
    self:SetButtonText()
end

function HironCraftScan_AddonToggleButtonMixin:SetButtonText()
    self:SetText(HironCraftScan.Utils.AddonsAreSaved() and L(LID.RENABLE_ADDONS) or L(LID.DISABLE_ADDONS))
end

function HironCraftScan_AddonToggleButtonMixin:OnEnter()
    if not HironCraftScan.Utils.AddonsAreSaved() then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
        GameTooltip:SetText(L(LID.DISABLE_ADDONS_TOOLTIP), 1, 1, 1, 1, true)
        GameTooltip:Show()
    end
end

function HironCraftScan_AddonToggleButtonMixin:OnLeave()
    GameTooltip:Hide()
end

HironCraftScan_TabButtonMixin = {}

function HironCraftScan_TabButtonMixin:UpdateTabWidth()
    self:SetWidth(self.Text:GetStringWidth() + 25);
end

function HironCraftScan_TabButtonMixin:OnShow()
    self:SetTabSelected(false);
    self.Text:SetPoint("CENTER", self, "CENTER", 0, -3);
end

function HironCraftScan_TabButtonMixin:Init()
    self:HandleRotation();
    self:SetButtonText();
    self:UpdateTabWidth();
end

HironCraftScan_OpenProfessionButtonMixin = {}

function HironCraftScan_OpenProfessionButtonMixin:OnClick(button)
    -- With TWW update, this hide is no longer automatic.
    HideUIPanel(HironCraftScan.Frames.OrdersPage);

    C_TradeSkillUI.OpenTradeSkill(self.profession.professionID);
    self:SetTabSelected(false);
    self.Text:SetPoint("CENTER", self, "CENTER", 0, 0);
end

function HironCraftScan_OpenProfessionButtonMixin:SetButtonText()
    local professionInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(self.profession.professionID);
    self:SetText(professionInfo.professionName);
    self:UpdateTabWidth();
end

HironCraftScan_OpenChatOrdersButtonMixin = {}

function HironCraftScan_OpenChatOrdersButtonMixin:OnClick(button)
    -- With TWW update, this hide is no longer automatic.
    HideUIPanel(ProfessionsFrame);

    ShowUIPanel(HironCraftScan.Frames.OrdersPage);
end

function HironCraftScan_OpenChatOrdersButtonMixin:SetButtonText()
    self.Text:SetText(L(LID.CHAT_ORDERS));
end

-- Highlight only this player's configured crafters, not a hidden author list.
function HironCraftScan.Utils.ItsMe(player)
    if type(player) ~= "string" then return false end
    local shortName = player:match("^([^-]+)") or player
    if shortName == UnitName("player") then return true end
    for name in pairs(HironCraftScan.DB and HironCraftScan.DB.characters or {}) do
        if name == player or (name:match("^([^-]+)") or name) == shortName then return true end
    end
    return false
end

HironCraftScan_OpenSettingsButtonMixin = {}

function HironCraftScan_OpenSettingsButtonMixin:OnLoad()
    self:SetText(L("Open Settings"))
    self:FitToText();
end

function HironCraftScan_OpenSettingsButtonMixin:OnClick(button)
    if button == "LeftButton" then
        HironCraftScan.Settings:Open();
    else
        MenuUtil.CreateContextMenu(self, function(owner, rootDescription)
            rootDescription:CreateButton(L("Reset Alert Icon"), function()
                HironCraftScanScannerMenu.PageButton:ClearAllPoints();
                HironCraftScanScannerMenu.PageButton:SetPoint("CENTER", UIParent, "CENTER", 0, 0);

                HironCraftScanScannerMenu:ClearAllPoints();
                HironCraftScanScannerMenu:SetPoint("CENTER", UIParent, "CENTER", 0, 0);

                HironCraftScan.DB.settings.alert_icon_scale = HironCraftScan.CONST.DEFAULT_SETTINGS.alert_icon_scale;
                HironCraftScan.UpdateAlertIconScale();
            end)
        end);
    end
end

HironCraftScan_OpenConfigButtonMixin = {}

function HironCraftScan_OpenConfigButtonMixin:OnLoad()
    self:SetText(L("Config"))
    self:FitToText();
end

function HironCraftScan_OpenConfigButtonMixin:OnClick(button)
    HironCraftScan.Frames.ConfigPage:ToggleVisibility()
end

HironCraftScan_BusyCheckButtonMixin = {}

function HironCraftScan_BusyCheckButtonMixin:OnLoad()
    self.Text:SetText(L(LID.BUSY_RIGHT_NOW));
end

function HironCraftScan_BusyCheckButtonMixin:OnClick()
    HironCraftScan.State.isBusy = self:GetChecked();
end

function HironCraftScan_BusyCheckButtonMixin:OnEnter()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
    GameTooltip:AddLine(string.format(L(LID.BUSY_HELP), HironCraftScan.Utils.GetGreeting("GREETING_BUSY")), 1, 1, 1, true);
    GameTooltip:SetMinimumWidth(350);
    GameTooltip:Show();
end

function HironCraftScan_BusyCheckButtonMixin:OnLeave()
    GameTooltip:Hide();
end

-- Pause for customers with the copper coin: their requests come in without a
-- banner or a greeting card until this is switched off.
HironCraftScan_HoldStingyCheckButtonMixin = {}

function HironCraftScan_HoldStingyCheckButtonMixin:Init()
    local tips = HironCraftScan.Generous
    self.Text:SetText((tips and tips.Icon('stingy') .. ' ' or '') .. L('Hold stingy greetings'))
    -- Just left of Busy Mode, whatever the label's length.
    local busy = self:GetParent().BusyCheckButton
    if busy then
        self:ClearAllPoints()
        self:SetPoint('BOTTOMLEFT', busy, 'BOTTOMLEFT', -(self:GetWidth() + self.Text:GetStringWidth() + 16), 0)
    end
    self:OnShow()
end

function HironCraftScan_HoldStingyCheckButtonMixin:OnShow()
    local tips = HironCraftScan.Generous
    self:SetChecked(tips and tips.IsHoldingStingy() or false)
end

function HironCraftScan_HoldStingyCheckButtonMixin:OnClick()
    HironCraftScan.Generous.SetHoldingStingy(self:GetChecked())
end

function HironCraftScan_HoldStingyCheckButtonMixin:OnEnter()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
    GameTooltip_SetTitle(GameTooltip, L('Hold stingy greetings'));
    GameTooltip_AddNormalLine(GameTooltip, HironCraftScan.MakeTextWhite(L('Hold stingy greetings tooltip')));
    GameTooltip:SetMinimumWidth(350);
    GameTooltip:Show();
end

function HironCraftScan_HoldStingyCheckButtonMixin:OnLeave()
    GameTooltip:Hide();
end

local openChatOrdersFrame = nil
function HironCraftScan.UpdateShowChatOrdersTab()
    if openChatOrdersFrame then
        if HironCraftScan.DB.settings.show_chat_orders_tab == false then
            openChatOrdersFrame:Hide()
        else
            openChatOrdersFrame:Show()
        end
    end
end

HironCraftScan.Utils.onLoad(function()
    local frame = HironCraftScanCraftingOrderPage
    frame:EnableMouse(true);

    HironCraftScan.Frames.OrdersPage = frame
    table.insert(UISpecialFrames, "HironCraftScanCraftingOrderPage"); -- Make 'esc' close the frame
    -- checkFit: Blizzard scales the window down to fit whenever it opens and
    -- whenever the game window changes size. The profession buttons hang
    -- below it, hence the extra height.
    UIPanelWindows["HironCraftScanCraftingOrderPage"] = { area = "doublewide", pushable = 1, whileDead = 1,
        checkFit = HironCraftScan.Utils.FitsScreen() and 1 or 0, checkFitExtraWidth = 20, checkFitExtraHeight = 50 }

    frame.BrowseFrame.AddonToggleButton:SetButtonText();
    frame.BrowseFrame.CustomExplanationsButton:Init();
    frame.BrowseFrame.HoldStingyCheckButton:Init();

    frame.BrowseFrame.LeftPanel.LinkedAccountList:Init();

    local lastButton = nil;
    for i, profession in ipairs(HironCraftScan.CONST.PROFESSIONS) do
        local profButton = CreateFrame("Button", "HironCraftScanOpenProfessionButton" .. i, frame,
            "HironCraftScan_OpenProfessionButtonTemplate");
        profButton.profession = profession;
        if lastButton then
            profButton:SetPoint("TOPLEFT", lastButton, "TOPRIGHT", 2, 0);
        else
            profButton:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 2, 2);
        end
        profButton:Init();
        lastButton = profButton;
    end

    PurgeOldOrders()

    local initialized = false;
    ProfessionsFrame:HookScript("OnShow", function()
        if not initialized then
            openChatOrdersFrame = CreateFrame("Button", "HironCraftScanOpenChatOrdersButton", ProfessionsFrame,
                "HironCraftScan_OpenChatOrdersButtonTemplate");
            openChatOrdersFrame:Init();
            openChatOrdersFrame:SetPoint("TOPLEFT", ProfessionsFrame.TabSystem, "TOPRIGHT", 2, 0);

            HironCraftScan.UpdateShowChatOrdersTab()

            initialized = true;
        end
    end)
end)
