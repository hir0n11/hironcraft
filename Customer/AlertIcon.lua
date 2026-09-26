local HironCraftScan = select(2, ...)

local LID = HironCraftScan.CONST.TEXT;
local function L(id)
    return HironCraftScan.LOCAL:GetText(id);
end

HironCraftScanScannerMenuMixin = {}

HironCraftScanPageButtonMixin = {}

function HironCraftScanScannerMenuMixin:OnLoad()
    self.pulseLocks = {};
end

-- This is our only always visible frame, so we give it a generic map of
-- callbacks so the entire addon can use it for event registrations that might
-- only fire on a visible frame.
local eventCallbacks = {}
function HironCraftScanScannerMenuMixin:RegisterEventCallback(event, callback)
    local callbacks = HironCraftScan.Utils.saved(eventCallbacks, event, {});
    self:RegisterEvent(event);
    table.insert(callbacks, callback);
end

function HironCraftScanScannerMenuMixin:UnregisterEventCallback(event, callback)
    local callbacks = eventCallbacks[event];
    if callbacks then
        for i, cb in ipairs(callbacks) do
            if cb == callback then
                table.remove(callbacks, i);
                return;
            end
        end
    end
end

function HironCraftScanPageButtonMixin:OnEnter()
    GameTooltip:SetOwner(self, "ANCHOR_TOP");
    GameTooltip:SetText(HironCraftScan.Utils.PopulateBinds(LID.TOGGLE_CHAT_TOOLTIP, "HIRONCRAFT_SCAN_TOGGLE"), 1, 1, 1);
    GameTooltip:Show();
    self.PortraitBorder:SetAtlas("Soulbinds_Tree_Ring");
    self.GlowUp:Show()
end

function HironCraftScanPageButtonMixin:OnLeave()
    GameTooltip:Hide();
    self.PortraitBorder:SetAtlas("Soulbinds_Tree_Ring_Disabled");
    self.GlowUp:Hide()
end

function HironCraftScanPageButtonMixin:UpdateIcon(icon)
    -- Set the icon the most appropriate current profession - the one they are
    -- near the table for, the last profession they opened, or as a fallback,
    -- blacksmithing.
    local icon = icon or HironCraftScan.Utils.GetCurrentProfessionIcon();
    self.Portrait:SetTexture(icon or 4620670);
end

function HironCraftScanScannerMenuMixin:UpdateFrameVisibility(...)
    if HironCraftScan.Utils.IsScanningEnabled(...) then
        self:Show()
    else
        self:Hide()
    end
end

function HironCraftScanScannerMenuMixin:SetPulseLock(lock, enabled)
    self.pulseLocks[lock] = enabled;
end

function HironCraftScanScannerMenuMixin:TriggerPulseLock(lock)
    local enabled = true;
    self:SetPulseLock(lock, enabled)
    self.PageButton.MinimapLoopPulseAnim:Play();
end

function HironCraftScanScannerMenuMixin:HidePulse(lock)
    self:SetPulseLock(lock, false);
    local enabled = false;
    for k, v in pairs(self.pulseLocks) do
        if (v) then
            enabled = true;
            break
        end
    end

    -- If there are no other reasons to show the pulse, hide it
    if (not enabled) then
        self.PageButton.MinimapLoopPulseAnim:Stop();
    end
end

function HironCraftScanScannerMenuMixin:ClearPulses()
    for k, v in pairs(self.pulseLocks) do
        self.pulseLocks[k] = false;
    end
    self.PageButton.MinimapLoopPulseAnim:Stop();
    self.PageButton.MinimapAlertAnim:Stop()
end

local bannerDirection = nil;
local function UpdateBannerDirection()
    local setting = HironCraftScan.Utils.GetSetting("banner_direction");

    -- Flip the anchors so the pop-out goes in the desired direction. This will
    -- usually be a no-op unless the setting has changed.
    if setting ~= bannerDirection then
        if bannerDirection ~= nil or setting == HironCraftScan.CONST.RIGHT then
            HironCraftScan.Frames.flipTextureHorizontally(HironCraftScanScannerMenu.PageButton.AlertBG)
        end
        local isLeft = setting == HironCraftScan.CONST.LEFT;
        local point = isLeft and "RIGHT" or "LEFT";
        local relativePoint = isLeft and "LEFT" or "RIGHT";

        HironCraftScanScannerMenu.PageButton.AlertBG:ClearAllPoints();
        HironCraftScanScannerMenu.AlertBGButton:ClearAllPoints();
        HironCraftScanScannerMenu.PageButton.AlertText:ClearAllPoints();

        HironCraftScanScannerMenu.PageButton.AlertBG:SetPoint(point, HironCraftScanScannerMenuButton, "CENTER");
        HironCraftScanScannerMenu.AlertBGButton:SetPoint(point, HironCraftScanScannerMenuButton, "CENTER");
        HironCraftScanScannerMenu.PageButton.AlertText:SetPoint(point, HironCraftScanScannerMenuButton, relativePoint);
        --isLeft and -4 or 4, 0);

        -- Avoid the wrong justification being cached. Seems to only matter in
        -- testing with the same message repeatedly.
        HironCraftScanScannerMenu.PageButton.AlertText:SetText("");
        HironCraftScanScannerMenu.PageButton.AlertText:SetJustifyH(point);
    end
    bannerDirection = setting;
end

local bannerTimeout = nil;
local function UpdateAlertDuration()
    local setting = HironCraftScan.Utils.GetSetting("banner_timeout");
    if setting ~= bannerTimeout then
        local animation = HironCraftScanScannerMenu.PageButton.MinimapAlertAnim;
        animation.AlertTextFade:SetStartDelay(setting);
        animation.AlertBGFade:SetStartDelay(setting);
        animation.AlertBGShrink:SetStartDelay(setting);
    end
    bannerTimeout = setting;
end

-- Two requests in the same second used to share one banner: the second
-- replaced the first, which then had to be found in the order list. While a
-- banner is up, a new request waits here and is shown once the current one
-- is answered, dismissed or has timed out.
local QUEUE_MAX_AGE = 10 * 60
local alertQueue = {}

local function SameOrder(lhs, rhs)
    return lhs and rhs and lhs.customerName == rhs.customerName and lhs.responseID == rhs.responseID
end

local function RemoveQueued(order)
    for index = #alertQueue, 1, -1 do
        if SameOrder(alertQueue[index].order, order) then table.remove(alertQueue, index) end
    end
end

-- A queued request is still worth a banner only while it is the same,
-- unanswered request it was when it arrived, and its customer is not on hold.
local function StillWaiting(item)
    local response = HironCraftScan.OrderToResponse(item.order)
    local tips = HironCraftScan.Generous
    return response ~= nil
        and not (tips and tips.IsGreetingHeld and tips.IsGreetingHeld(item.order.customerName))
        and response.requestToken == item.requestToken
        and (item.requestToken ~= nil or response.time == item.requestTime)
        and not response.greeting_sent
        and HironCraftScan.DB.listed_orders[HironCraftScan.OrderToOrderID(item.order)] ~= nil
        and (time() - item.queuedAt) <= QUEUE_MAX_AGE
end

function HironCraftScanScannerMenuMixin:GetQueuedAlertCount()
    return #alertQueue
end

function HironCraftScanScannerMenuMixin:ShowNextAlert()
    if self.AlertBGButton:GetOrder() then return false end
    while #alertQueue > 0 do
        local item = table.remove(alertQueue, 1)
        if StillWaiting(item) then
            self:TriggerAlert(item.text, item.order)
            return true
        end
    end
    return false
end

function HironCraftScanScannerMenuMixin:TriggerAlert(text, order)
    local response = HironCraftScan.OrderToResponse(order)
    if not response then return end

    local displayed = self.AlertBGButton:GetOrder()
    if displayed and not SameOrder(displayed, order) then
        -- The banner on screen stays the one a key press acts on.
        RemoveQueued(order)
        alertQueue[#alertQueue + 1] = {
            text = text, order = order, queuedAt = time(),
            requestToken = response.requestToken, requestTime = response.time,
        }
        HironCraftScan.State.activeOrder = displayed
        return
    end
    RemoveQueued(order)

    -- Stop the old animation before binding the new target: OnHide releases
    -- its request. A later whisper must not retarget this displayed banner.
    self.PageButton.MinimapAlertAnim:Stop()
    HironCraftScan.State.activeOrder = order
    self.AlertBGButton.order = order
    self.AlertBGButton.response = response
    self.AlertBGButton.requestToken = response.requestToken
    self.AlertBGButton.requestTime = response.time
    UpdateBannerDirection();
    UpdateAlertDuration();
    self.PageButton:UpdateIcon();
    self.PageButton.AlertText:SetText(text);
    self.PageButton.MinimapAlertAnim:Play();
end

function HironCraftScanScannerMenuMixin:ClearAlert(order)
    if order == HironCraftScan.State.activeOrder then
        HironCraftScan.State.activeOrder = nil;
    end
    local displayed = self.AlertBGButton.order
    if order and displayed and order.customerName == displayed.customerName
        and order.responseID == displayed.responseID then
        self:ClearPulses()
        self.AlertBGButton:OnHide()
        self.AlertBGButton.HighlightTexture:Hide()
        self:ShowNextAlert()
    elseif order then
        -- Answered from the order list while it was still waiting its turn.
        RemoveQueued(order)
    end
end

function HironCraftScanPageButtonMixin:OnClick(button)
    if HironCraftScan.Frames.OrdersPage:IsShown() then
        HideUIPanel(HironCraftScan.Frames.OrdersPage);
    else
        ShowUIPanel(HironCraftScan.Frames.OrdersPage);
    end
end

HironCraftScanBannerMixin = {}

function HironCraftScanBannerMixin:GetOrder()
    -- Bindings invoke OnClick directly, even while the button/parent is hidden.
    if not self:IsVisible() or not self.order then return nil end
    local response = HironCraftScan.OrderToResponse(self.order)
    if response ~= self.response or not response
        or response.requestToken ~= self.requestToken
        or (not self.requestToken and response.time ~= self.requestTime)
        or not HironCraftScan.DB.listed_orders[HironCraftScan.OrderToOrderID(self.order)] then
        return nil
    end
    return self.order
end

function HironCraftScanBannerMixin:OnClick(button)
    local order = self:GetOrder()
    if not order then return end
    HironCraftScan.GreetCustomer(button, order)
    self:GetParent():ClearAlert(order)
end

local bannerTooltip = HironCraftScan.Utils.ChatHistoryTooltip:new();
function HironCraftScanBannerMixin:OnHide()
    if self.order and HironCraftScan.State.activeOrder == self.order then
        HironCraftScan.State.activeOrder = nil
    end
    self.order, self.response, self.requestToken, self.requestTime = nil, nil, nil, nil
    bannerTooltip:Hide()
end

function HironCraftScanBannerMixin:OnEnter()
    local order = self:GetOrder()
    if order then
        bannerTooltip:Show("HironCraftScanChatHistoryBannerTooltip", self, order,
            string.format(L("Customer Request"), HironCraftScan.NameAndRealmToName(order.customerName)),
            true);
        self.HighlightTexture:Show()
    end
end

function HironCraftScanBannerMixin:OnLeave()
    bannerTooltip:Hide();
    self.HighlightTexture:Hide()
end

function HironCraftScan.UpdateAlertIconScale()
    local scale = HironCraftScan.DB.settings.alert_icon_scale or
        HironCraftScan.CONST.DEFAULT_SETTINGS.alert_icon_scale;
    HironCraftScanScannerMenu:SetScale(scale / 100);
end

HironCraftScan.Utils.onLoad(function()
    local frame = HironCraftScanScannerMenu
    frame:SetParent(UIParent);
    HironCraftScan.Frames.MainButton = frame.PageButton;
    HironCraftScan.Frames.makeMovable(frame.PageButton)

    HironCraftScan.UpdateAlertIconScale();

    -- The banner timed out: the next waiting request gets its turn.
    frame.PageButton.MinimapAlertAnim:HookScript('OnFinished', function()
        frame:ShowNextAlert()
    end)

    frame:SetScript("OnEvent", function(self, event, ...)
        local callbacks = eventCallbacks[event];
        if callbacks then
            for _, callback in ipairs(callbacks) do
                callback(event, ...)
            end
        end
    end)

    local function DoUpdateFrameVisibility(...)
        frame:UpdateFrameVisibility(...);
    end

    HironCraftScan.Utils.RegisterEnableDisableCallback(DoUpdateFrameVisibility)

    frame.PageButton:UpdateIcon();

    DoUpdateFrameVisibility();
end)
