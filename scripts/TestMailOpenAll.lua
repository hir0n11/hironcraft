-- The key for the mailbox's "Open All" button: assigned from a small button
-- beside it, active only while "Open All" is on screen, never written to the
-- game's own key bindings.
local function eq(actual, expected, what)
    if actual ~= expected then
        error((what or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
    end
end

local frames, byName, handlers = {}, {}, nil
local function NewFrame(kind, name, parent, template)
    local frame = { kind = kind, name = name, parent = parent, template = template, shown = true, scripts = {}, hooks = {}, events = {} }
    function frame:SetSize(w, h) self.width, self.height = w, h end
    function frame:SetPoint(...) self.point = { ... } end
    function frame:SetAllPoints() end
    function frame:SetFrameStrata() end
    function frame:EnableKeyboard(on) self.keyboard = on end
    function frame:EnableMouse() end
    function frame:SetPropagateKeyboardInput(on) self.propagate = on end
    function frame:SetBackdrop() end
    function frame:SetBackdropColor() end
    function frame:SetBackdropBorderColor() end
    function frame:RegisterForClicks(...) self.clicks = { ... } end
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(script, fn) self.scripts[script] = fn end
    function frame:HookScript(script, fn)
        self.hooks[script] = self.hooks[script] or {}
        table.insert(self.hooks[script], fn)
    end
    function frame:Show() self.shown = true if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function frame:Hide() self.shown = false end
    function frame:IsShown() return self.shown end
    function frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function frame:Raise() end
    function frame:GetParent() return self.parent end
    function frame:CreateFontString()
        local text = {}
        function text:SetFont(path, size) self.font, self.size = path, size end
        function text:SetPoint() end
        function text:SetWidth() end
        function text:SetWordWrap() end
        function text:SetJustifyH() end
        function text:SetTextColor() end
        function text:SetText(value) self.text = value end
        return text
    end
    frames[#frames + 1] = frame
    if name then byName[name] = frame end
    if kind == 'Frame' and not name and not parent then handlers = frame end
    return frame
end
UIParent = NewFrame('Frame', 'UIParent')
function CreateFrame(kind, name, parent, template) return NewFrame(kind, name, parent, template) end

-- The game's bindings: what is overridden, and what must never be called.
local overrides, forbidden = {}, 0
function SetOverrideBindingClick(owner, priority, key, button, mouse)
    overrides[key] = { owner = owner, priority = priority, button = button, mouse = mouse }
end
function ClearOverrideBindings(owner)
    for key, entry in pairs(overrides) do
        if entry.owner == owner then overrides[key] = nil end
    end
end
function SetBinding() forbidden = forbidden + 1 end
function SetBindingClick() forbidden = forbidden + 1 end
function SaveBindings() forbidden = forbidden + 1 end
function GetBindingText(key, _, abbreviated)
    if abbreviated then return (key:gsub('BUTTON', 'M'):gsub('SHIFT%-', 's-'):gsub('CTRL%-', 'c-')) end
    return 'Key ' .. key
end
local combat, shift, ctrl, alt = false, false, false, false
function InCombatLockdown() return combat end
function IsShiftKeyDown() return shift end
function IsControlKeyDown() return ctrl end
function IsAltKeyDown() return alt end

local tooltipLines = {}
HironCraftProfit = {
    L = {}, FONT = 'Addon/default.ttf',
    Tooltip = {
        Clear = function() tooltipLines = {} end,
        AddLine = function(_, text) tooltipLines[#tooltipLines + 1] = text end,
        ShowCursorRightOrBelow = function() end,
    },
}
HironCraftProfit_DB = nil

assert(loadfile('ProfitHub/Core/UI/MailOpenAll.lua'))()
local M = HironCraftProfit.MailOpenAll
assert(handlers and handlers.events.MAIL_SHOW and handlers.events.PLAYER_REGEN_ENABLED, 'no event frame')
local function fire(event, ...) handlers.scripts.OnEvent(handlers, event, ...) end

-- Saved variables are not touched while the file loads.
eq(HironCraftProfit_DB, nil, 'saved variables created at load')

-- Before the mailbox exists nothing is built; another addon loading changes nothing.
fire('ADDON_LOADED', 'SomethingElse')
fire('PLAYER_LOGIN')
eq(byName.HironCraftProfitMailOpenAllBinding, nil, 'built without the mailbox')

-- The mailbox: the inbox with its Open All button.
local inbox = NewFrame('Frame', 'InboxFrame', UIParent)
local openAll = NewFrame('Button', 'OpenAllMail', inbox)
OpenAllMail = openAll
inbox.shown = false
fire('ADDON_LOADED', 'Blizzard_MailFrame')
local owner = byName.HironCraftProfitMailOpenAllBinding
assert(owner, 'the binding owner was not created')
local bind
for _, frame in ipairs(frames) do
    if frame.kind == 'Button' and frame.parent == inbox and frame ~= openAll then bind = frame end
end
assert(bind, 'no button to assign the key')
eq(bind.point[2], openAll, 'placed beside Open All')
eq(bind.point[1], 'RIGHT', 'to the left of it')
eq(bind.label.text, '...', 'nothing assigned yet')
eq(bind.label.font, 'Addon/default.ttf', 'the addon\'s font')
eq(#openAll.hooks.OnShow, 1, 'follows Open All being shown')
eq(#openAll.hooks.OnHide, 1, 'and hidden')
eq(next(openAll.scripts), nil, 'the game\'s own button scripts are not replaced')
fire('MAIL_SHOW')
fire('PLAYER_LOGIN')
local built = 0
for _, frame in ipairs(frames) do
    if frame.name == 'HironCraftProfitMailOpenAllBinding' then built = built + 1 end
end
eq(built, 1, 'built once')

local function open() inbox.shown = true for _, hook in ipairs(openAll.hooks.OnShow) do hook(openAll) end end
local function close() inbox.shown = false for _, hook in ipairs(openAll.hooks.OnHide) do hook(openAll) end end
local function capture() return byName.HironCraftProfitMailOpenAllCapture end

-- No key assigned: opening the mailbox binds nothing.
open()
eq(next(overrides), nil, 'a binding without a key')

-- Assigning: a click asks for a key; Esc and plain clicks cancel.
bind.scripts.OnClick(bind, 'LeftButton')
assert(capture() and capture().shown, 'no key was asked for')
eq(capture().propagate, false, 'the pressed key must not reach the game')
assert(capture().text.text:find('Open All', 1, true), 'the request does not say what the key is for')
capture().scripts.OnKeyDown(capture(), 'ESCAPE')
eq(capture().shown, false, 'Esc did not cancel')
eq(M.GetBinding(), nil, 'Esc assigned a key')
bind.scripts.OnClick(bind, 'RightButton')
capture().scripts.OnMouseDown(capture(), 'LeftButton')
eq(capture().shown, false, 'a click did not cancel')
eq(M.GetBinding(), nil, 'a click assigned a key')
-- A modifier alone is not a key: the request stays.
bind.scripts.OnClick(bind, 'LeftButton')
capture().scripts.OnKeyDown(capture(), 'LSHIFT')
eq(capture().shown, true, 'a modifier alone ended the request')

-- A key with a modifier.
shift = true
capture().scripts.OnKeyDown(capture(), 'f')
shift = false
eq(M.GetBinding(), 'SHIFT-F', 'key with its modifier')
eq(HironCraftProfit_DB.mail.openAllBinding, 'SHIFT-F', 'saved for the account')
eq(capture().shown, false, 'the request closed')
eq(bind.label.text, 's-F', 'the button shows the key')
local entry = overrides['SHIFT-F']
assert(entry, 'the key was not bound while the mailbox is open')
eq(entry.button, 'OpenAllMail', 'it presses the game\'s own button')
eq(entry.mouse, 'LeftButton', 'with a left click')
eq(entry.owner, owner, 'owned by this module')
eq(entry.priority, false, 'not a priority override')

-- Closed mailbox: the key is free again. Open: bound again.
close()
eq(next(overrides), nil, 'the key stayed bound with the mailbox closed')
open()
assert(overrides['SHIFT-F'], 'not bound again on reopening')

-- A side mouse button replaces the key.
bind.scripts.OnClick(bind, 'LeftButton')
capture().scripts.OnMouseDown(capture(), 'Button5')
eq(M.GetBinding(), 'BUTTON5', 'side mouse button')
eq(overrides['SHIFT-F'], nil, 'the old key was released')
assert(overrides.BUTTON5, 'the new key is bound')
eq(bind.label.text, 'M5', 'the button shows the mouse button')

-- The tooltip names the key and how to change it.
bind.scripts.OnEnter(bind)
assert(table.concat(tooltipLines, '\n'):find('Key BUTTON5', 1, true), 'the tooltip does not show the key')
bind.scripts.OnLeave(bind)

-- In combat bindings cannot change: done when it is over.
combat = true
close()
assert(overrides.BUTTON5, 'changed bindings in combat')
fire('PLAYER_REGEN_ENABLED')
assert(overrides.BUTTON5, 'changed bindings before combat ended')
combat = false
fire('PLAYER_REGEN_ENABLED')
eq(next(overrides), nil, 'not released after combat')
-- Without anything pending the end of combat does nothing.
open()
overrides.BUTTON5.marker = true
fire('PLAYER_REGEN_ENABLED')
eq(overrides.BUTTON5.marker, true, 'rebound for no reason after combat')

-- Shift + right click clears.
shift = true
bind.scripts.OnClick(bind, 'RightButton')
shift = false
eq(M.GetBinding(), nil, 'not cleared')
eq(next(overrides), nil, 'still bound after clearing')
eq(bind.label.text, '...', 'the button still shows a key')
eq(capture().shown, false, 'clearing asked for a key')
bind.scripts.OnEnter(bind)
assert(table.concat(tooltipLines, '\n'):find('not assigned', 1, true), 'the tooltip does not say it is unassigned')

-- Other mailbox tabs: Open All hidden, key free.
M.SetBinding('F')
assert(overrides.F, 'bound')
close()
eq(next(overrides), nil, 'bound while Open All is hidden')

eq(M.NormalizeKey('UNKNOWN'), nil, 'unknown key')
eq(M.NormalizeKey(''), nil, 'empty key')
ctrl, alt = true, true
eq(M.NormalizeKey('numpad1'), 'CTRL-ALT-NUMPAD1', 'modifier order')
ctrl, alt = false, false

eq(forbidden, 0, 'the game\'s own key bindings were written')
print('Mail Open All key passed (assign, cancel, modifiers, mouse buttons, scope, combat, clear, tooltip, no game bindings).')
