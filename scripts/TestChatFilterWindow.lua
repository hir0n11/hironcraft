-- The chat filter window on a permissive stand-in for the frame API: it
-- opens, its four tabs draw, a rule is chosen, edited and saved, keys and
-- expressions are added, Global Ignore List is taken over, players are
-- ignored and unignored, and the journal lists what was hidden.
local now = 1790000000
function time(t) if t then return os.time(t) end return now end
date = os.date
function GetTime() return 1000 end
function UnitName() return 'Mavu' end
function GetNormalizedRealmName() return 'Kazzak' end
function IsInInstance() return false end

local initializers = {}
local function Mock(kind)
    local object = { kind = kind, scripts = {}, shown = true, width = 600, height = 300 }
    local methods = {}
    function methods:SetScript(name, fn) self.scripts[name] = fn end
    function methods:HookScript(name, fn) self.scripts[name] = fn end
    function methods:GetScript(name) return self.scripts[name] end
    function methods:Show() local was = self.shown; self.shown = true; if not was and self.scripts.OnShow then self.scripts.OnShow(self) end end
    function methods:Hide() self.shown = false end
    function methods:SetShown(on) if on then self:Show() else self:Hide() end end
    function methods:IsShown() return self.shown end
    function methods:GetWidth() return self.width end
    function methods:SetWidth(w) self.width = w end
    function methods:SetSize(w, h) self.width, self.height = w, h end
    function methods:SetText(text) self.text = text end
    function methods:GetText() return self.text end
    function methods:SetChecked(on) self.checked = on end
    function methods:GetChecked() return self.checked end
    function methods:CreateFontString() return Mock('FontString') end
    function methods:CreateTexture() return Mock('Texture') end
    function methods:SetDataProvider(provider)
        self.list = provider.list
        self.inited = {}
        for _, data in ipairs(provider.list) do
            local row = Mock('Row')
            row.Stripe = Mock('Texture')
            initializers[self](row, data)
            self.inited[#self.inited + 1] = row
        end
    end
    function methods:GetID() return self.id end
    function methods:SetID(id) self.id = id end
    return setmetatable(object, { __index = function(_, key)
        if methods[key] then return methods[key] end
        if type(key) == 'string' and key:match('^%u') then return function() end end
        return nil
    end })
end

UIParent = Mock('Frame')
UISpecialFrames = {}
function CreateFrame(kind, name, parent, template)
    local f = Mock(kind)
    f.shown = kind ~= 'Frame' or name == nil
    if template == 'ButtonFrameTemplate' then f.Inset = Mock('Frame') end
    if template == 'InputScrollFrameTemplate' then f.EditBox = Mock('EditBox') end
    if name then _G[name] = f end
    return f
end
function ButtonFrameTemplate_HidePortrait() end
function ButtonFrameTemplate_HideButtonBar() end
function PanelTemplates_SetNumTabs() end
function PanelTemplates_SetTab() end
function PanelTemplates_TabResize() end
function InputScrollFrame_OnLoad() end
function InputScrollFrame_OnTextChanged() end
function PlaySound() end
SOUNDKIT = {}
GameTooltip = Mock('Tooltip')
function GameTooltip_SetTitle() end
function GameTooltip_AddNormalLine() end
function BreakUpLargeNumbers(value) return tostring(value) end
C_Timer = { After = function() end }
ScrollBoxConstants = { RetainScrollPosition = true }
function CreateDataProvider(list) return { list = list } end
function CreateScrollBoxListLinearView()
    local view = {}
    function view:SetElementExtent() end
    function view:SetElementInitializer(_, fn) self.init = fn end
    return view
end
ScrollUtil = { InitScrollBoxListWithScrollBar = function(scrollBox, _, view) initializers[scrollBox] = view.init end }
C_AddOns = { IsAddOnLoaded = function(name) return name == 'GlobalIgnoreList' end,
    DisableAddOn = function(name) C_AddOns.disabled = name end }
local captured
HironCraftScan_DB = {}

local Scan = {
    LOCAL = { GetText = function(_, key) return key end },
    Utils = { FitFrame = function() end },
    ChatTextCapture = { Show = function(text) captured = text end, ConfigureMessageScrollFrame = function() end },
}
local function load(path) assert(loadfile(path))('HironCraft', Scan) end
load('ChatFilter/FilterEngine.lua')
load('ChatFilter/ChatFilter.lua')
load('ChatFilter/IgnoreList.lua')
load('ChatFilter/FilterWindow.lua')
local F, W = Scan.ChatFilter, Scan.ChatFilterWindow

GlobalIgnoreDB = {
    filterList = { '[contains=wts] and [contains=boost]', '[nonlatin]' },
    filterDesc = { 'Boosts', 'CJK' }, filterActive = { true, false }, filterCount = { 12, 0 },
    ignoreList = { 'Spammer-Kazzak' }, typeList = { 'player' }, dateList = { '14 Apr 2026' }, notes = { '' },
}

W.Toggle()
local frame = _G.HironCraftChatFilterFrame
assert(frame and W.IsShown(), 'the window did not open')
assert(frame.ImportButton:IsShown() and frame.DisableGILButton:IsShown(), 'Global Ignore List is not offered')
frame.ImportButton.scripts.OnClick(frame.ImportButton)
assert(#F.Rules() == 2 and Scan.ChatIgnore.IsIgnored('Spammer'), 'taking over from the window failed')
assert(#frame.Rules.scrollBox.inited == 2, 'the rules are not listed')

-- Choosing a rule fills the editor; saving a broken expression keeps the old one.
local row = frame.Rules.scrollBox.inited[1]
row.scripts.OnClick(row, 'LeftButton')
assert(frame.Editor.Name:GetText() == 'Boosts' and frame.Editor.Text.EditBox:GetText() == '[contains=wts] and [contains=boost]',
    'the editor does not show the rule')
frame.Editor.Text.EditBox:SetText('[contains=wts] and (')
frame.Editor.Name.scripts.OnEnterPressed(frame.Editor.Name)
assert(F.Rules()[1].expr == '[contains=wts] and [contains=boost]', 'a broken expression was saved')
assert(frame.Editor.Status:GetText():find('Cannot be read', 1, true), 'a broken expression was not reported')
frame.Editor.Text.EditBox:SetText('[contains=wts] and [contains=carry]')
frame.Editor.On:SetChecked(false)
frame.Editor.Name:SetText('Carries')
frame.Editor.Name.scripts.OnEnterPressed(frame.Editor.Name)
assert(F.Rules()[1].expr == '[contains=wts] and [contains=carry]' and F.Rules()[1].name == 'Carries'
    and not F.Rules()[1].on, 'the rule was not saved')

-- A hidden line shows in the rule's history and in the journal; a click
-- opens it in the text selection tool.
F.Rules()[1].on = true
assert(F.MessageFilter(nil, 'CHAT_MSG_CHANNEL', 'WTS carry tonight', 'Seller-Kazzak', '', '', '', '', 0, 2,
    'Trade - City', 0, 77, ''), 'the saved rule does not hide')
row = frame.Rules.scrollBox.inited[1]
row.scripts.OnClick(row, 'LeftButton')
assert(#frame.Editor.History.scrollBox.inited == 1, 'the rule history is empty')
for _, tab in ipairs(frame.Tabs) do tab.scripts.OnClick(tab) end
assert(#frame.Journal.scrollBox.inited >= 1, 'the journal is empty')
local journalRow = frame.Journal.scrollBox.inited[1]
journalRow.scripts.OnClick(journalRow, 'LeftButton')
assert(captured == 'WTS carry tonight', 'the journal line did not open in the selection tool')

-- New rules from the buttons, then chosen in the editor.
frame.Tabs[1].scripts.OnClick(frame.Tabs[1])
local before = #F.Rules()
frame.Pages[1].NewKey.scripts.OnClick(frame.Pages[1].NewKey)
frame.Pages[1].NewKey.scripts.OnClick(frame.Pages[1].NewKey)
frame.Pages[1].NewExpression.scripts.OnClick(frame.Pages[1].NewExpression)
assert(#F.Rules() == before + 3 and F.Rules()[before + 3].expr, 'the new rule buttons did not add')
assert(frame.Editor.Name:GetText() == 'New expression', 'a new rule was not chosen')
frame.Editor.Text.EditBox:SetText('gamer-choice.net')
row = frame.Rules.scrollBox.inited[before + 1]
row.scripts.OnClick(row, 'LeftButton')
frame.Editor.Text.EditBox:SetText('Gamer-Choice.net')
frame.Editor.Whole:SetChecked(true)
frame.Editor.Name.scripts.OnEnterPressed(frame.Editor.Name)
assert(F.Rules()[before + 1].key == 'Gamer-Choice.net' and F.Rules()[before + 1].whole, 'a key was not saved')

-- Incoming sync must not be silently overwritten by an already-open editor.
frame.Editor.Name:SetText('unsaved local edit')
F.Rules()[before + 1].name='Remote name'; F.Changed()
frame.Editor.Name.scripts.OnEnterPressed(frame.Editor.Name)
assert(F.Rules()[before + 1].name=='Remote name' and frame.Editor.Name:GetText()=='unsaved local edit')
assert(frame.Editor.Status:GetText():find('another account',1,true))
row=frame.Rules.scrollBox.inited[before+1]; row.scripts.OnClick(row,'LeftButton')
assert(frame.Editor.Name:GetText()=='Remote name')
frame.Editor.Name:SetText('reviewed edit'); frame.Editor.Name.scripts.OnEnterPressed(frame.Editor.Name)
assert(F.Rules()[before + 1].name=='reviewed edit')

-- The ignore list tab: add and remove.
frame.Tabs[3].scripts.OnClick(frame.Tabs[3])
assert(#frame.Players.scrollBox.inited == 1, 'the ignore list is not listed')
Scan.ChatIgnore.Add('Goldseller', { quiet = true })
W.Refresh()
assert(#frame.Players.scrollBox.inited == 2, 'an added player is not listed')
local playerRow = frame.Players.scrollBox.inited[1]
playerRow.scripts.OnClick(playerRow, 'LeftButton')
for _, check in ipairs(frame.Pages[3].Checks) do check.scripts.OnClick(check) end

-- What is hidden: every switch works.
frame.Tabs[2].scripts.OnClick(frame.Tabs[2])
for _, check in ipairs(frame.Pages[2].Checks) do
    check:SetChecked(not check.get())
    check.scripts.OnClick(check)
end
assert(F.DB().enabled == false, 'the main switch did not switch')

-- Turning Global Ignore List off.
frame.DisableGILButton.scripts.OnClick(frame.DisableGILButton)
assert(C_AddOns.disabled == 'GlobalIgnoreList', 'Global Ignore List was not turned off')
W.Toggle()
assert(not W.IsShown(), 'the window did not close')
print('Chat filter window passed (open, take over, edit, history, journal, keys, ignore list, switches).')
