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

function HironCraftScanScannerMenuMixin:TriggerAlert(text, order)
    UpdateBannerDirection();
    UpdateAlertDuration();
    self.PageButton:UpdateIcon();
    self.PageButton.AlertText:SetText(text);
    self.PageButton.MinimapAlertAnim:Play();
end

function HironCraftScanScannerMenuMixin:ClearAlert(order)
    if order == HironCraftScan.State.activeOrder then
        HironCraftScan.State.activeOrder = nil;
        self:ClearPulses()
        self.AlertBGButton.HighlightTexture:Hide()
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

function HironCraftScanBannerMixin:OnClick(button)
    if HironCraftScan.State.activeOrder then
        HironCraftScan.GreetCustomer(button, HironCraftScan.State.activeOrder)
        self:GetParent():ClearAlert(HironCraftScan.State.activeOrder)
    end
end

local bannerTooltip = HironCraftScan.Utils.ChatHistoryTooltip:new();
function HironCraftScanBannerMixin:OnEnter()
    if HironCraftScan.State.activeOrder then
        bannerTooltip:Show("HironCraftScanChatHistoryBannerTooltip", self, HironCraftScan.State.activeOrder,
            string.format(L("Customer Request"), HironCraftScan.NameAndRealmToName(HironCraftScan.State.activeOrder.customerName)),
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
