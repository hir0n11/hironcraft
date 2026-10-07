local _, Scan = ...
local B = {}
Scan.ExplanationBindings = B
local owner = CreateFrame('Frame')
local buttons, active, elapsed, lastSent = {}, false, 0, {}
local function L(s) return Scan.LOCAL:GetText(s) end
local function Keys()
    if not Scan.DB or not Scan.DB.settings then return {} end
    Scan.DB.settings.explanation_keys = Scan.DB.settings.explanation_keys or {}
    return Scan.DB.settings.explanation_keys
end
function B.HoveredOrder()
    if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then return end
    for _, focus in ipairs(GetMouseFoci and GetMouseFoci() or {}) do
        for _ = 1, 12 do
            if not focus then break end
            if focus.hironExplanationRow and focus:IsVisible() then
                local order = focus.order
                local listed = Scan.DB and Scan.DB.listed_orders
                if order and listed and listed[Scan.OrderToOrderID(order)]
                    and Scan.OrderToResponse(order) then return order end
                return
            end
            focus = focus.GetParent and focus:GetParent()
        end
    end
end
function B.Send(label)
    if InCombatLockdown() then return false end
    local order = B.HoveredOrder()
    if not order then return false end
    local text = Scan.DB.settings.explanations and Scan.DB.settings.explanations[label]
    if not text then return false end
    local key = order.customerName .. '\031' .. label
    if lastSent[key] and GetTime() - lastSent[key] < 6 then return false end
    local sent = Scan.CustomExplanations:Send(text, order.customerName, order)
    if sent ~= false then lastSent[key] = GetTime() end
    return sent
end
function B.Refresh()
    if InCombatLockdown() then return end
    ClearOverrideBindings(owner)
    active = false
    if not B.HoveredOrder() then return end
    local labels = {}
    for label in pairs(Keys()) do labels[#labels + 1] = label end
    table.sort(labels)
    for index, label in ipairs(labels) do
        if Scan.DB.settings.explanations and Scan.DB.settings.explanations[label] then
            local button = buttons[index]
            if not button then
                button = CreateFrame('Button', 'HironCraftExplanationKey' .. index, UIParent)
                button:RegisterForClicks('AnyUp')
                button:SetScript('OnClick', function(self) B.Send(self.label) end)
                buttons[index] = button
            end
            button.label = label
            SetOverrideBindingClick(owner, false, Keys()[label], button:GetName(), 'LeftButton')
            active = true
        end
    end
end
function B.Rename(old, new)
    local keys = Keys()
    if old ~= new then keys[new], keys[old] = keys[old], nil end
    B.Refresh()
end
function B.Remove(label)
    Keys()[label] = nil
    B.Refresh()
end
function B.Key(label) return Keys()[label] end
-- The phrases that have a key, for the hint a held Shift shows on a row:
-- { key, label, text }, in the order of the keys.
function B.List()
    local list = {}
    local texts = Scan.DB and Scan.DB.settings and Scan.DB.settings.explanations
    if type(texts) ~= 'table' then return list end
    for label, key in pairs(Keys()) do
        if type(key) == 'string' and key ~= '' and type(texts[label]) == 'string' then
            list[#list + 1] = { key = key, label = label, text = texts[label] }
        end
    end
    table.sort(list, function(lhs, rhs)
        if lhs.key ~= rhs.key then return lhs.key < rhs.key end
        return lhs.label < rhs.label
    end)
    return list
end
function B.Assign(label, key)
    for other, existing in pairs(Keys()) do
        if existing == key and other ~= label then return false, other end
    end
    Keys()[label] = key
    B.Refresh()
    return true
end
local capture
function B.Capture(label)
    if InCombatLockdown() then return end
    if not capture then
        capture = CreateFrame('Frame', 'HironCraftExplanationBindCapture', UIParent, 'BackdropTemplate')
        capture:SetSize(440, 170)
        capture:SetPoint('CENTER')
        capture:SetFrameStrata('DIALOG')
        capture:EnableKeyboard(true)
        capture:EnableMouse(true)
        capture:SetBackdrop({ bgFile = 'Interface/Tooltips/UI-Tooltip-Background',
            edgeFile = 'Interface/Tooltips/UI-Tooltip-Border', edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 } })
        capture:SetBackdropColor(0.05, 0.05, 0.05, 1)
        capture.text = capture:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
        capture.text:SetPoint('TOP', 0, -18)
        capture.text:SetWidth(404)
        capture.save = CreateFrame('Button', nil, capture, 'UIPanelButtonTemplate')
        capture.save:SetSize(120, 24)
        capture.save:SetPoint('BOTTOMLEFT', 20, 15)
        capture.save:SetText(L('Save'))
        capture.save:SetScript('OnClick', function()
            if not capture.key then return end
            local ok, other = B.Assign(capture.label, capture.key)
            if ok then capture:Hide()
            else capture.text:SetText(L('Key already assigned') .. ': ' .. other) end
        end)
        local cancel = CreateFrame('Button', nil, capture, 'UIPanelButtonTemplate')
        cancel:SetSize(120, 24)
        cancel:SetPoint('BOTTOMRIGHT', -20, 15)
        cancel:SetText(L('Cancel'))
        cancel:SetScript('OnClick', function() capture:Hide() end)
        capture:SetScript('OnKeyDown', function(self, key)
            self:SetPropagateKeyboardInput(false)
            if key == 'ESCAPE' then self:Hide(); return end
            if key:match('SHIFT$') or key:match('CTRL$') or key:match('ALT$') then return end
            key = (IsControlKeyDown() and 'CTRL-' or '') .. (IsAltKeyDown() and 'ALT-' or '')
                .. (IsShiftKeyDown() and 'SHIFT-' or '') .. key
            self.key = key
            local existing = GetBindingAction(key) or ''
            self.text:SetText(self.label .. '\n\n' .. key .. '\n' ..
                L('Works only on the customer row under the cursor.') ..
                (existing ~= '' and ('\n' .. L('Temporarily replaces') .. ': ' .. existing) or ''))
            self.save:Enable()
        end)
        capture:SetScript('OnShow', function(self) self:SetPropagateKeyboardInput(false) end)
    end
    capture.label, capture.key = label, nil
    capture.text:SetText(label .. '\n\n' .. L('Press a key combination, then Save. Escape cancels.'))
    capture.save:Disable()
    capture:Show()
end
-- Only install temporary keys while actually hovering an order. This also
-- covers cell children, scrolling/recycled rows and closing the scanner.
owner:SetScript('OnUpdate', function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.1 or InCombatLockdown() then return end
    elapsed = 0
    local wants = next(Keys()) ~= nil and B.HoveredOrder() ~= nil and not (capture and capture:IsShown())
    if wants ~= active then
        if wants then B.Refresh() else ClearOverrideBindings(owner); active = false end
    end
end)
