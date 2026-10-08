local PT = HironCraftProfit
if not PT then return end

-- A key for the mailbox's "Open All" button. It is assigned from the small
-- button to the left of it and works only while "Open All" is on screen: an
-- override binding that presses the game's own button, so the same key keeps
-- its usual meaning everywhere else and nothing is written to the game's key
-- bindings.
local M = {}
PT.MailOpenAll = M

local TARGET = "OpenAllMail"

local function T(key, fallback)
    local L = PT.L
    local text = L and L[key]
    return type(text) == "string" and text or fallback
end

-- Saved for the account; read only once the game has loaded saved variables.
local function DB()
    _G.HironCraftProfit_DB = _G.HironCraftProfit_DB or {}
    local db = _G.HironCraftProfit_DB
    if type(db.mail) ~= "table" then db.mail = {} end
    return db.mail
end

function M.GetBinding()
    local binding = DB().openAllBinding
    return type(binding) == "string" and binding ~= "" and binding or nil
end

local function KeyText(binding, abbreviated)
    if not binding then return nil end
    if type(GetBindingText) == "function" then
        return GetBindingText(binding, "KEY_", abbreviated and true or nil)
    end
    return binding
end

local owner, bind, capture
local pending = false

local function UpdateBindButton()
    if not bind then return end
    local binding = M.GetBinding()
    bind.label:SetText(binding and KeyText(binding, true) or "...")
end

-- The key presses "Open All" only while that button can be seen. Bindings
-- cannot change in combat: done as soon as it is over.
function M.Apply()
    if not owner then return false end
    if InCombatLockdown and InCombatLockdown() then
        pending = true
        return false
    end
    pending = false
    ClearOverrideBindings(owner)
    local target, binding = _G[TARGET], M.GetBinding()
    if binding and target and target:IsVisible() then
        SetOverrideBindingClick(owner, false, binding, TARGET, "LeftButton")
    end
    UpdateBindButton()
    return true
end

function M.SetBinding(binding)
    DB().openAllBinding = type(binding) == "string" and binding ~= "" and binding or nil
    M.Apply()
    UpdateBindButton()
end

-- "SHIFT-F", "BUTTON5": what the game calls the pressed key, with the
-- modifiers held. A modifier alone is not a key.
local function NormalizeKey(key)
    if type(key) ~= "string" or key == "" or key == "UNKNOWN" then return nil end
    key = key:upper()
    if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL"
        or key == "LALT" or key == "RALT" or key == "LMETA" or key == "RMETA" then
        return nil
    end
    local parts = {}
    if IsControlKeyDown and IsControlKeyDown() then parts[#parts + 1] = "CTRL" end
    if IsAltKeyDown and IsAltKeyDown() then parts[#parts + 1] = "ALT" end
    if IsShiftKeyDown and IsShiftKeyDown() then parts[#parts + 1] = "SHIFT" end
    parts[#parts + 1] = key
    return table.concat(parts, "-")
end
M.NormalizeKey = NormalizeKey

local function EnsureCapture()
    if capture then return capture end
    capture = CreateFrame("Frame", "HironCraftProfitMailOpenAllCapture", UIParent, "BackdropTemplate")
    capture:SetAllPoints(UIParent)
    capture:SetFrameStrata("FULLSCREEN_DIALOG")
    capture:EnableKeyboard(true)
    capture:EnableMouse(true)
    capture:Hide()

    local box = CreateFrame("Frame", nil, capture, "BackdropTemplate")
    box:SetSize(400, 104)
    box:SetPoint("CENTER")
    PT.ClassicTheme:ApplyFrame(box)
    capture.text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if PT.FONT then capture.text:SetFont(PT.FONT, 13, "") end
    capture.text:SetWidth(360)
    capture.text:SetJustifyH("CENTER")
    capture.text:SetPoint("CENTER")

    local function Finish(self, key)
        local binding = NormalizeKey(key)
        if not binding then return end
        self:Hide()
        M.SetBinding(binding)
    end
    capture:SetScript("OnShow", function(self)
        self:SetPropagateKeyboardInput(false)
        self.text:SetText(T("MAIL_OPENALL_BIND_CAPTURE",
            "Press a keyboard key or a side mouse button (Button4/Button5) for Open All.\nEsc or left/right click - cancel."))
    end)
    capture:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
            return
        end
        Finish(self, key)
    end)
    capture:SetScript("OnMouseDown", function(self, button)
        if type(button) == "string" and button:match("^Button%d+$") then
            Finish(self, button)
            return
        end
        self:Hide()
    end)
    return capture
end

function M.ShowCapture()
    local frame = EnsureCapture()
    frame:Show()
    if frame.Raise then frame:Raise() end
end

local function ShowTooltip()
    local tooltip = PT.Tooltip
    if not tooltip then return end
    local key = KeyText(M.GetBinding()) or T("MAIL_OPENALL_BIND_NONE", "not assigned")
    tooltip:Clear()
    tooltip:AddLine(T("MAIL_OPENALL_BIND_TITLE", "Open All hotkey"), 13, 1, 1, 1)
    tooltip:AddLine(T("MAIL_OPENALL_BIND_SCOPE", "Works only while the inbox is open."), 11, 0.8, 0.8, 0.8)
    tooltip:AddLine(" ", 6)
    tooltip:AddLine(string.format(T("MAIL_OPENALL_BIND_CURRENT", "Assigned key: %s"), key), 11, 0.98, 0.86, 0.42)
    tooltip:AddLine(" ", 6)
    tooltip:AddLine(T("MAIL_OPENALL_BIND_HINT", "Click - assign a key."), 11, 0.7, 0.7, 0.7)
    tooltip:AddLine(T("MAIL_OPENALL_BIND_CLEAR", "Shift + right click - clear."), 11, 0.7, 0.7, 0.7)
    tooltip:ShowCursorRightOrBelow()
end

local function Build()
    local target = _G[TARGET]
    if owner or not target then return end
    owner = CreateFrame("Frame", "HironCraftProfitMailOpenAllBinding", UIParent)

    -- Between "Prev" and "Open All"; the game's own button is left as it is.
    bind = CreateFrame("Button", nil, target:GetParent(), "UIPanelButtonTemplate")
    bind:SetSize(26, 22)
    bind:SetPoint("RIGHT", target, "LEFT", -1, 0)
    bind:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    bind.label = bind:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if PT.FONT then bind.label:SetFont(PT.FONT, 9, "") end
    bind.label:SetPoint("CENTER", 0, 0)
    bind.label:SetWidth(24)
    bind.label:SetWordWrap(false)
    bind.label:SetTextColor(0.98, 0.86, 0.42)
    bind:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" and IsShiftKeyDown and IsShiftKeyDown() then
            M.SetBinding(nil)
        else
            M.ShowCapture()
        end
    end)
    bind:SetScript("OnEnter", ShowTooltip)
    bind:SetScript("OnLeave", function()
        if PT.Tooltip then PT.Tooltip:Clear() end
    end)

    target:HookScript("OnShow", M.Apply)
    target:HookScript("OnHide", M.Apply)
    M.Apply()
end

if not CreateFrame then return end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "ADDON_LOADED", "MAIL_SHOW", "MAIL_CLOSED", "PLAYER_REGEN_ENABLED" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name ~= "Blizzard_MailFrame" then return end
    if event == "PLAYER_REGEN_ENABLED" and not pending then return end
    Build()
    M.Apply()
end)
