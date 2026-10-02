local Scan = select(2, ...)

-- The chat filter's window (/hcfilter): its rules, what kinds of lines are
-- hidden, the ignore list and the journal of what was hidden.
local W = {}
Scan.ChatFilterWindow = W

local function L(key)
    return Scan.LOCAL:GetText(key)
end

local FRAME_NAME = 'HironCraftChatFilterFrame'
local ROW_HEIGHT = 20
local GAP = 6
local TAB_RULES, TAB_KINDS, TAB_IGNORE, TAB_JOURNAL = 1, 2, 3, 4

local frame = nil
local selectedRule = nil
local selectedDefinition = nil
local selectedPlayer = nil

local function F() return Scan.ChatFilter end
local function I() return Scan.ChatIgnore end

local function Number(value)
    return BreakUpLargeNumbers and BreakUpLargeNumbers(value or 0) or tostring(value or 0)
end

local function OneLine(text)
    return (Scan.FilterEngine.PlainText(text or ''):gsub('|', '||'))
end

-- A table: columns of text, a row can be selected by a click.
local function CreateTable(parent, columns, options)
    options = options or {}
    local tbl = { columns = columns, rows = {} }
    tbl.frame = CreateFrame('Frame', nil, parent)

    local function Layout()
        local fixed = 0
        for _, column in ipairs(columns) do fixed = fixed + (column.width or 0) + GAP end
        local width = math.max(200, tbl.frame:GetWidth() - 34)
        local x = 8
        for _, column in ipairs(columns) do
            column.x = x
            column.w = column.fill and math.max(80, width - fixed) or column.width
            x = x + column.w + GAP
        end
    end

    tbl.headers = {}
    for index, column in ipairs(columns) do
        local header = tbl.frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
        header:SetJustifyH(column.align or 'LEFT')
        header:SetText(L(column.label))
        tbl.headers[index] = header
    end

    tbl.scrollBox = CreateFrame('Frame', nil, tbl.frame, 'WowScrollBoxList')
    tbl.scrollBox:SetPoint('TOPLEFT', tbl.frame, 'TOPLEFT', 4, -22)
    tbl.scrollBox:SetPoint('BOTTOMRIGHT', tbl.frame, 'BOTTOMRIGHT', -24, 4)
    tbl.scrollBar = CreateFrame('EventFrame', nil, tbl.frame, 'MinimalScrollBar')
    tbl.scrollBar:SetPoint('TOPLEFT', tbl.scrollBox, 'TOPRIGHT', 6, 0)
    tbl.scrollBar:SetPoint('BOTTOMLEFT', tbl.scrollBox, 'BOTTOMRIGHT', 6, 0)

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(ROW_HEIGHT)
    view:SetElementInitializer('HironCraftAnalyticsRowTemplate', function(row, data)
        row.data = data.row
        row.Stripe:SetShown(data.index % 2 == 0)
        if not row.selectedMark then
            row.selectedMark = row:CreateTexture(nil, 'BACKGROUND', nil, 1)
            row.selectedMark:SetAllPoints()
            row.selectedMark:SetColorTexture(1, 0.82, 0, 0.18)
        end
        row.selectedMark:SetShown(options.isSelected ~= nil and options.isSelected(data.row) == true)
        row:SetScript('OnClick', function(self, button)
            if options.onClick then options.onClick(self.data, button) end
        end)
        row:SetScript('OnEnter', function(self) if options.onEnter then options.onEnter(self, self.data) end end)
        row:SetScript('OnLeave', function() GameTooltip:Hide() end)
        row.cells = row.cells or {}
        for index, column in ipairs(columns) do
            local cell = row.cells[index]
            if not cell then
                cell = row:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
                cell:SetWordWrap(false)
                row.cells[index] = cell
            end
            cell:ClearAllPoints()
            cell:SetPoint('LEFT', row, 'LEFT', column.x - 4, 0)
            cell:SetWidth(column.w)
            cell:SetJustifyH(column.align or 'LEFT')
            local ok, text = pcall(column.text, data.row)
            cell:SetText(ok and text or '?')
        end
    end)
    ScrollUtil.InitScrollBoxListWithScrollBar(tbl.scrollBox, tbl.scrollBar, view)

    function tbl:SetRows(rows)
        self.rows = rows or {}
        Layout()
        for index, column in ipairs(columns) do
            local header = self.headers[index]
            header:ClearAllPoints()
            header:SetPoint('TOPLEFT', self.frame, 'TOPLEFT', column.x, -4)
            header:SetWidth(column.w)
        end
        local list = {}
        for index, row in ipairs(self.rows) do list[index] = { row = row, index = index } end
        self.scrollBox:SetDataProvider(CreateDataProvider(list), ScrollBoxConstants.RetainScrollPosition)
    end

    tbl.frame:SetScript('OnSizeChanged', function() tbl:SetRows(tbl.rows) end)
    return tbl
end

local function Checkbox(parent, label, tooltip, get, set)
    local check = CreateFrame('CheckButton', nil, parent, 'UICheckButtonTemplate')
    check:SetSize(22, 22)
    check.text = check:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    check.text:SetPoint('LEFT', check, 'RIGHT', 2, 0)
    check.text:SetText(L(label))
    check.get = get
    check:SetScript('OnClick', function(self)
        set(self:GetChecked() and true or false)
        W.Refresh()
    end)
    if tooltip then
        check:SetScript('OnEnter', function(self)
            GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
            GameTooltip_SetTitle(GameTooltip, L(label))
            GameTooltip_AddNormalLine(GameTooltip, L(tooltip))
            GameTooltip:Show()
        end)
        check:SetScript('OnLeave', function() GameTooltip:Hide() end)
    end
    return check
end

local function Button(parent, label, width, onClick)
    local button = CreateFrame('Button', nil, parent, 'UIPanelButtonTemplate')
    button:SetSize(width, 22)
    button:SetText(L(label))
    button:SetScript('OnClick', onClick)
    return button
end

local function Title(parent, text)
    local title = parent:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    title:SetText(L(text))
    return title
end

-- Why a line was hidden, for the journal.
local function Reason(entry)
    local reason = entry.r
    if reason == 'ignored' then return L('Ignore list') end
    if reason == 'npc' then return L('NPC speech') end
    if reason == 'presence' then return L('Online/offline') end
    if reason == 'system' then return L('Ignore list notice') end
    if reason == 'duel' then return L('Duel results') end
    if reason == 'imported' then return L('Global Ignore List') end
    local rule = F().RuleByID(reason)
    return rule and rule.name or L('Deleted rule')
end

local function Where(entry)
    if entry.c and entry.c ~= '' then return entry.c end
    local kind = entry.e and entry.e:match('^CHAT_MSG_(.+)$')
    return kind and kind:lower():gsub('_', ' ') or ''
end

local function When(entry)
    return entry.t and date('%d.%m %H:%M', entry.t) or ''
end

local function MessageTooltip(row, entry)
    GameTooltip:SetOwner(row, 'ANCHOR_RIGHT')
    GameTooltip_SetTitle(GameTooltip, (entry.a and entry.a ~= '' and entry.a or Where(entry)))
    GameTooltip:AddLine(OneLine(entry.m), 1, 1, 1, true)
    GameTooltip:AddLine(' ')
    GameTooltip:AddLine(When(entry) .. '  ' .. Where(entry) .. '  ' .. Reason(entry), 0.6, 0.6, 0.6, true)
    GameTooltip:AddLine(L('Click to open the message in the text selection tool.'), 0.5, 0.8, 1, true)
    GameTooltip:Show()
end

local function OpenInCapture(entry)
    if entry and Scan.ChatTextCapture and type(entry.m) == 'string' then Scan.ChatTextCapture.Show(entry.m) end
end

-- Rules -----------------------------------------------------------------------------

local RULE_COLUMNS = {
    { label = 'On', width = 30, text = function(rule)
        return rule.on and '|cff40ff40' .. L('yes') .. '|r' or '|cff808080' .. L('no') .. '|r' end },
    { label = 'Rule', fill = true, text = function(rule)
        local _, err = F().Compiled(rule)
        return (err and '|cffff4040! |r' or '') .. OneLine(rule.name) end },
    { label = 'Kind', width = 90, text = function(rule)
        if rule.expr then return L('Expression') end
        return rule.whole and L('Whole words') or L('Key') end },
    { label = 'Hidden', width = 80, align = 'RIGHT', text = function(rule) return Number(rule.count) end },
}

local HISTORY_COLUMNS = {
    { label = 'When', width = 70, text = When },
    { label = 'Who', width = 110, text = function(entry) return entry.a or '' end },
    { label = 'Message', fill = true, text = function(entry) return OneLine(entry.m) end },
}

local function Definition(rule)
    return rule and {name=rule.name, key=rule.key, expr=rule.expr, whole=rule.whole == true, on=rule.on == true}
end
local function EditorIsStale(rule)
    local current = Definition(rule)
    if not current or not selectedDefinition then return false end
    for _, key in ipairs({'name','key','expr','whole','on'}) do
        if current[key] ~= selectedDefinition[key] then return true end
    end
    return false
end
local function WarnStaleEditor()
    frame.Editor.Status:SetTextColor(1, 0.65, 0)
    frame.Editor.Status:SetText(L('This rule changed on another account. Select it again before editing.'))
end
local function ShowRule(rule)
    selectedRule = rule and rule.id or nil
    selectedDefinition = Definition(rule)
    local editor = frame.Editor
    editor.Name:SetText(rule and rule.name or '')
    editor.Text.EditBox:SetText(rule and (rule.expr or rule.key) or '')
    editor.On:SetChecked(rule and rule.on or false)
    editor.Whole:SetShown(rule ~= nil and rule.expr == nil)
    editor.Whole:SetChecked(rule and rule.whole or false)
    editor.Kind:SetText(rule and (rule.expr and L('Expression') or L('Key')) or '')
    local _, err = rule and F().Compiled(rule)
    editor.Status:SetTextColor(1, 0.3, 0.3)
    editor.Status:SetText(err and string.format(L('Cannot be read: %s'), err) or '')
    editor.History:SetRows(rule and rule.history and (function()
        local list = {}
        for index = #rule.history, 1, -1 do list[#list + 1] = rule.history[index] end
        return list
    end)() or {})
    for _, element in ipairs(editor.Elements) do element:SetShown(rule ~= nil) end
    editor.Whole:SetShown(rule ~= nil and rule.expr == nil)
    frame.Rules:SetRows(F().Rules())
end

local function SaveRule()
    local rule = selectedRule and F().RuleByID(selectedRule)
    if not rule then return end
    if EditorIsStale(rule) then WarnStaleEditor(); return end
    local editor = frame.Editor
    local text = editor.Text.EditBox:GetText() or ''
    if rule.expr then
        local test, err = Scan.FilterEngine.Compile(text)
        if not test then
            editor.Status:SetTextColor(1, 0.3, 0.3)
            editor.Status:SetText(string.format(L('Cannot be read: %s'), err))
            return
        end
        rule.expr = text
    else
        local plain = Scan.FilterEngine.PlainText(text)
        if plain == '' then return end
        rule.key = plain
        rule.whole = editor.Whole:GetChecked() and true or nil
    end
    local name = editor.Name:GetText() or ''
    rule.name = name ~= '' and name or (rule.expr or rule.key)
    rule.on = editor.On:GetChecked() and true or false
    F().Changed()
    ShowRule(rule)
    editor.Status:SetTextColor(0.3, 1, 0.3)
    editor.Status:SetText(L('Saved.'))
end

local function NewRule(kind)
    local ok, rule
    if kind == 'expr' then
        ok, rule = F().AddExpression('[contains=' .. L('example') .. ']', L('New expression'))
    else
        local base = L('new key')
        local text, index = base, 1
        repeat
            ok, rule = F().AddKey(text, false, L('New key'))
            index = index + 1
            text = base .. ' ' .. index
        until ok or index > 50
    end
    if ok then
        ShowRule(rule)
        frame.Editor.Text.EditBox:SetFocus()
        frame.Editor.Text.EditBox:HighlightText()
    end
end

local EXPRESSION_HELP = 'Expression help'

local function CreateRulesTab(parent)
    local tab = CreateFrame('Frame', nil, parent)
    tab:SetAllPoints(parent)

    local newKey = Button(tab, 'New key', 110, function() NewRule('key') end)
    newKey:SetPoint('TOPLEFT', tab, 'TOPLEFT', 8, -8)
    local newExpr = Button(tab, 'New expression', 130, function() NewRule('expr') end)
    newExpr:SetPoint('LEFT', newKey, 'RIGHT', 6, 0)
    local rulesOn = Checkbox(tab, 'Rules on', 'Rules on tooltip',
        function() return F().DB().rules_on ~= false end, function(on) F().DB().rules_on = on end)
    rulesOn:SetPoint('LEFT', newExpr, 'RIGHT', 14, 0)
    tab.RulesOn, tab.NewKey, tab.NewExpression = rulesOn, newKey, newExpr

    frame.Rules = CreateTable(tab, RULE_COLUMNS, {
        isSelected = function(rule) return rule.id == selectedRule end,
        onClick = function(rule) ShowRule(rule) end,
        onEnter = function(row, rule)
            GameTooltip:SetOwner(row, 'ANCHOR_RIGHT')
            GameTooltip_SetTitle(GameTooltip, OneLine(rule.name))
            GameTooltip:AddLine(OneLine(rule.expr or rule.key), 1, 1, 1, true)
            local _, err = F().Compiled(rule)
            if err then GameTooltip:AddLine(string.format(L('Cannot be read: %s'), err), 1, 0.3, 0.3, true) end
            GameTooltip:Show()
        end,
    })
    frame.Rules.frame:SetPoint('TOPLEFT', tab, 'TOPLEFT', 0, -36)
    frame.Rules.frame:SetPoint('BOTTOMLEFT', tab, 'BOTTOMLEFT', 0, 0)
    frame.Rules.frame:SetWidth(520)

    -- The selected rule.
    local editor = CreateFrame('Frame', nil, tab)
    editor:SetPoint('TOPLEFT', frame.Rules.frame, 'TOPRIGHT', 12, 0)
    editor:SetPoint('BOTTOMRIGHT', tab, 'BOTTOMRIGHT', -8, 0)
    frame.Editor = editor
    editor.Elements = {}
    local function Keep(element) editor.Elements[#editor.Elements + 1] = element return element end

    local nameLabel = Keep(editor:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall'))
    nameLabel:SetPoint('TOPLEFT', editor, 'TOPLEFT', 0, -4)
    nameLabel:SetText(L('Name'))
    editor.Name = Keep(CreateFrame('EditBox', nil, editor, 'InputBoxTemplate'))
    editor.Name:SetAutoFocus(false)
    editor.Name:SetHeight(20)
    editor.Name:SetPoint('TOPLEFT', nameLabel, 'BOTTOMLEFT', 6, -2)
    editor.Name:SetPoint('RIGHT', editor, 'RIGHT', -4, 0)
    editor.Name:SetScript('OnEnterPressed', SaveRule)
    editor.Name:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)

    editor.On = Keep(Checkbox(editor, 'Enabled', nil, function() return true end, function() end))
    editor.On:SetScript('OnClick', nil)
    editor.On:SetPoint('TOPLEFT', editor.Name, 'BOTTOMLEFT', -8, -4)
    editor.Kind = Keep(editor:CreateFontString(nil, 'OVERLAY', 'GameFontDisableSmall'))
    editor.Kind:SetPoint('LEFT', editor.On.text, 'RIGHT', 16, 0)
    editor.Whole = Checkbox(editor, 'Whole words only', 'Whole words only tooltip', function() return false end,
        function() end)
    editor.Whole:SetScript('OnClick', nil)
    editor.Whole:SetPoint('LEFT', editor.Kind, 'RIGHT', 16, 0)

    local help = Keep(CreateFrame('Button', nil, editor))
    help:SetSize(20, 20)
    help:SetPoint('TOPRIGHT', editor.Name, 'BOTTOMRIGHT', 0, -5)
    help:SetNormalTexture('Interface\\Common\\help-i')
    help:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
        GameTooltip_SetTitle(GameTooltip, L('How rules are written'))
        GameTooltip:AddLine(L(EXPRESSION_HELP), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    help:SetScript('OnLeave', function() GameTooltip:Hide() end)

    editor.Text = Keep(CreateFrame('ScrollFrame', nil, editor, 'InputScrollFrameTemplate'))
    editor.Text:SetPoint('TOPLEFT', editor.On, 'BOTTOMLEFT', 8, -8)
    editor.Text:SetPoint('RIGHT', editor, 'RIGHT', -8, 0)
    editor.Text:SetHeight(110)
    local box = editor.Text.EditBox
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject('ChatFontNormal')
    box:SetMaxLetters(0)
    if Scan.ChatTextCapture then Scan.ChatTextCapture.ConfigureMessageScrollFrame(editor.Text) end
    InputScrollFrame_OnLoad(editor.Text)
    if Scan.ChatTextCapture then Scan.ChatTextCapture.ConfigureMessageScrollFrame(editor.Text) end
    box:SetScript('OnTextChanged', InputScrollFrame_OnTextChanged)
    box:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
    editor.Text:HookScript('OnSizeChanged', function(self)
        local width = self:GetWidth()
        if width and width > 30 then box:SetWidth(width - 20) end
    end)

    local save = Keep(Button(editor, 'Save', 100, SaveRule))
    save:SetPoint('TOPLEFT', editor.Text, 'BOTTOMLEFT', -6, -8)
    local remove = Keep(Button(editor, 'Delete', 100, function()
        if selectedRule and F().RemoveRule(selectedRule) then ShowRule(nil) end
    end))
    remove:SetPoint('LEFT', save, 'RIGHT', 6, 0)
    editor.Status = Keep(editor:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall'))
    editor.Status:SetPoint('LEFT', remove, 'RIGHT', 10, 0)
    editor.Status:SetPoint('RIGHT', editor, 'RIGHT', -4, 0)
    editor.Status:SetJustifyH('LEFT')

    local historyTitle = Keep(editor:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall'))
    historyTitle:SetPoint('TOPLEFT', save, 'BOTTOMLEFT', 2, -12)
    historyTitle:SetText(L('Last hidden by this rule'))
    editor.History = CreateTable(editor, HISTORY_COLUMNS, {
        onEnter = MessageTooltip,
        onClick = OpenInCapture,
    })
    Keep(editor.History.frame)
    editor.History.frame:SetPoint('TOPLEFT', historyTitle, 'BOTTOMLEFT', -8, -2)
    editor.History.frame:SetPoint('BOTTOMRIGHT', editor, 'BOTTOMRIGHT', 0, 0)

    editor.Empty = editor:CreateFontString(nil, 'OVERLAY', 'GameFontDisable')
    editor.Empty:SetPoint('CENTER')
    editor.Empty:SetText(L('Choose a rule on the left, or add one.'))
    return tab
end

-- What kinds of lines are hidden --------------------------------------------------

local function CreateKindsTab(parent)
    local tab = CreateFrame('Frame', nil, parent)
    tab:SetAllPoints(parent)
    tab.Checks = {}
    local function Column(x, title, entries, y)
        local heading = Title(tab, title)
        heading:SetPoint('TOPLEFT', tab, 'TOPLEFT', x, y or -14)
        local previous = heading
        for _, entry in ipairs(entries) do
            local check = Checkbox(tab, entry[1], entry[2], entry[3], entry[4])
            check:SetPoint('TOPLEFT', previous, 'BOTTOMLEFT', previous == heading and -4 or 0, -6)
            tab.Checks[#tab.Checks + 1] = check
            previous = check
        end
    end
    local function Setting(path, key)
        return function() return F().DB()[path][key] == true end,
            function(on) F().DB()[path][key] = on end
    end
    local db = function() return F().DB() end
    Column(16, 'General', {
        { 'Chat filter on', 'Chat filter on tooltip', function() return db().enabled ~= false end,
            function(on) db().enabled = on end },
        { 'Rules on', 'Rules on tooltip', function() return db().rules_on ~= false end,
            function(on) db().rules_on = on end },
        { 'Leave guild chat alone', nil, Setting('skip', 'guild') },
        { 'Leave group and raid chat alone', nil, Setting('skip', 'party') },
        { 'Leave whispers alone', 'Leave whispers alone tooltip', Setting('skip', 'whisper') },
        { 'Leave your own messages alone', nil, Setting('skip', 'self') },
    })
    Column(330, 'NPC speech', {
        { 'NPCs saying', 'NPC speech tooltip', Setting('npc', 'say') },
        { 'NPCs yelling', 'NPC speech tooltip', Setting('npc', 'yell') },
        { 'NPC emotes', 'NPC speech tooltip', Setting('npc', 'emote') },
        { 'NPCs whispering you', 'NPC whisper tooltip', Setting('npc', 'whisper') },
        { 'Show them in dungeons and raids', 'Show them in dungeons and raids tooltip',
            Setting('npc', 'keep_in_instances') },
    })
    Column(640, 'Online and offline notices', {
        { 'Your characters', 'Your characters tooltip', Setting('presence', 'own') },
        { 'Guild members', nil, Setting('presence', 'guild') },
        { 'Friends', nil, Setting('presence', 'friends') },
    })
    Column(640, 'Other system messages', {
        { 'Duel results', 'Duel results tooltip', Setting('system', 'duels') },
    }, -150)
    return tab
end

-- The ignore list --------------------------------------------------------------------

local IGNORE_COLUMNS = {
    { label = 'Player', fill = true, text = function(entry) return entry.name or entry.key end },
    { label = 'Since', width = 90, text = function(entry) return entry.at and date('%d.%m.%Y', entry.at) or '' end },
    { label = 'Note', width = 220, text = function(entry)
        if entry.note and entry.note ~= '' then return OneLine(entry.note) end
        return (tonumber(entry.game_misses) or 0) >= 2 and '|cff808080' .. L('not found by the game') .. '|r' or ''
    end },
}

local function CreateIgnoreTab(parent)
    local tab = CreateFrame('Frame', nil, parent)
    tab:SetAllPoints(parent)

    local input = CreateFrame('EditBox', nil, tab, 'InputBoxTemplate')
    input:SetAutoFocus(false)
    input:SetSize(220, 20)
    input:SetPoint('TOPLEFT', tab, 'TOPLEFT', 16, -10)
    local hint = input:CreateFontString(nil, 'ARTWORK', 'GameFontDisableSmall')
    hint:SetPoint('RIGHT', input, 'RIGHT', -6, 0)
    hint:SetText(L('Name-Realm'))
    input:SetScript('OnTextChanged', function(self) hint:SetShown((self:GetText() or '') == '') end)
    local function AddTyped()
        local name = (input:GetText() or ''):gsub('^%s+', ''):gsub('%s+$', '')
        if name ~= '' then
            I().Add(name, { source = 'window' })
            input:SetText('')
            W.Refresh()
        end
    end
    input:SetScript('OnEnterPressed', AddTyped)
    input:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
    local add = Button(tab, 'Ignore', 100, AddTyped)
    add:SetPoint('LEFT', input, 'RIGHT', 8, 0)
    local remove = Button(tab, 'Unignore', 120, function()
        if selectedPlayer then
            I().Remove(selectedPlayer)
            selectedPlayer = nil
            W.Refresh()
        end
    end)
    remove:SetPoint('LEFT', add, 'RIGHT', 6, 0)
    tab.Count = tab:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    tab.Count:SetPoint('LEFT', remove, 'RIGHT', 14, 0)

    frame.Players = CreateTable(tab, IGNORE_COLUMNS, {
        isSelected = function(entry) return entry.name == selectedPlayer end,
        onClick = function(entry)
            selectedPlayer = entry.name
            frame.Players:SetRows(frame.Players.rows)
        end,
    })
    frame.Players.frame:SetPoint('TOPLEFT', tab, 'TOPLEFT', 0, -40)
    frame.Players.frame:SetPoint('BOTTOMLEFT', tab, 'BOTTOMLEFT', 0, 0)
    frame.Players.frame:SetWidth(600)

    tab.Checks = {}
    local heading = Title(tab, 'With them')
    heading:SetPoint('TOPLEFT', frame.Players.frame, 'TOPRIGHT', 20, -4)
    local previous = heading
    local function Option(key, label, tooltip)
        local check = Checkbox(tab, label, tooltip,
            function() return I().Settings()[key] == true end,
            function(on)
                I().Settings()[key] = on
                if key == 'blizzard' and on then I().Sync() end
            end)
        check:SetPoint('TOPLEFT', previous, 'BOTTOMLEFT', previous == heading and -4 or 0, -6)
        tab.Checks[#tab.Checks + 1] = check
        previous = check
    end
    Option('reply', 'Answer their whispers', 'Answer their whispers tooltip')
    Option('decline', 'Decline their invitations', 'Decline their invitations tooltip')
    Option('warn', 'Warn when one is in your group', nil)
    Option('lfg', 'Mark their groups in the group finder', nil)
    Option('blizzard', "Fill the game's ignore list", "Fill the game's ignore list tooltip")
    Option('same_realm', 'Only players of this realm there', nil)
    return tab
end

-- The journal ------------------------------------------------------------------------

local JOURNAL_COLUMNS = {
    { label = 'When', width = 80, text = When },
    { label = 'Why', width = 170, text = function(entry) return OneLine(Reason(entry)) end },
    { label = 'Where', width = 120, text = Where },
    { label = 'Who', width = 130, text = function(entry) return entry.a or '' end },
    { label = 'Message', fill = true, text = function(entry) return OneLine(entry.m) end },
}

local function CreateJournalTab(parent)
    local tab = CreateFrame('Frame', nil, parent)
    tab:SetAllPoints(parent)
    local clear = Button(tab, 'Clear journal', 130, function()
        F().ClearLog()
        W.Refresh()
    end)
    clear:SetPoint('TOPRIGHT', tab, 'TOPRIGHT', -8, -8)
    local note = tab:CreateFontString(nil, 'OVERLAY', 'GameFontDisableSmall')
    note:SetPoint('TOPLEFT', tab, 'TOPLEFT', 12, -14)
    note:SetText(L('The last lines hidden, newest first. Click one to open it in the text selection tool.'))
    frame.Journal = CreateTable(tab, JOURNAL_COLUMNS, { onEnter = MessageTooltip, onClick = OpenInCapture })
    frame.Journal.frame:SetPoint('TOPLEFT', tab, 'TOPLEFT', 0, -36)
    frame.Journal.frame:SetPoint('BOTTOMRIGHT', tab, 'BOTTOMRIGHT', 0, 0)
    return tab
end

-- The window -------------------------------------------------------------------------

local function SelectTab(index)
    frame.tab = index
    PanelTemplates_SetTab(frame, index)
    for tabIndex, page in ipairs(frame.Pages) do page:SetShown(tabIndex == index) end
    W.Refresh()
end

local function UpdateBanner()
    local db = F().DB()
    local gil = F().GILLoaded()
    frame.Total:SetText(string.format(L('Hidden in total: %s'), Number(db and db.total)))
    if gil then
        frame.Banner:SetText(db and db.gil_imported
            and L('Global Ignore List is still on: it filters the same chat again. Turn it off once you are happy.')
            or L('Global Ignore List is on. Take over its filters, ignore list and settings?'))
    elseif db and db.gil_imported then
        frame.Banner:SetText(L('Global Ignore List was taken over.'))
    else
        frame.Banner:SetText(#F().Rules() == 0
            and L('Nothing taken over yet: turn Global Ignore List on for one login.') or '')
    end
    frame.ImportButton:SetShown(gil and rawget(_G, 'GlobalIgnoreDB') ~= nil)
    frame.DisableGILButton:SetShown(gil)
end

function W.Refresh()
    if not frame or not frame:IsShown() then return end
    UpdateBanner()
    local tab = frame.tab or TAB_RULES
    if tab == TAB_RULES then
        frame.Pages[TAB_RULES].RulesOn:SetChecked(F().DB().rules_on ~= false)
        local rule = selectedRule and F().RuleByID(selectedRule)
        frame.Rules:SetRows(F().Rules())
        frame.Editor.Empty:SetShown(rule == nil)
        if EditorIsStale(rule) then WarnStaleEditor() end
        if not rule then
            for _, element in ipairs(frame.Editor.Elements) do element:Hide() end
            frame.Editor.Whole:Hide()
        end
    elseif tab == TAB_KINDS then
        for _, check in ipairs(frame.Pages[TAB_KINDS].Checks) do check:SetChecked(check.get()) end
    elseif tab == TAB_IGNORE then
        local page = frame.Pages[TAB_IGNORE]
        for _, check in ipairs(page.Checks) do check:SetChecked(check.get()) end
        local list = I().List()
        frame.Players:SetRows(list)
        local game = I().GameListCount()
        page.Count:SetText(string.format(L('%d players; on this character\'s game list: %s / 50'), #list,
            game and tostring(game) or '?'))
    elseif tab == TAB_JOURNAL then
        local log = F().DB().log
        local list = {}
        for index = #log, 1, -1 do list[#list + 1] = log[index] end
        frame.Journal:SetRows(list)
    end
end

local function Create()
    frame = CreateFrame('Frame', FRAME_NAME, UIParent, 'ButtonFrameTemplate')
    ButtonFrameTemplate_HidePortrait(frame)
    ButtonFrameTemplate_HideButtonBar(frame)
    frame:SetSize(1000, 600)
    frame:SetPoint('CENTER')
    frame:SetFrameStrata('HIGH')
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag('LeftButton')
    frame:SetScript('OnDragStart', frame.StartMoving)
    frame:SetScript('OnDragStop', frame.StopMovingOrSizing)
    frame:SetTitle(L('Chat filter'))
    table.insert(UISpecialFrames, FRAME_NAME)

    frame.Inset:ClearAllPoints()
    frame.Inset:SetPoint('TOPLEFT', frame, 'TOPLEFT', 10, -64)
    frame.Inset:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -8, 8)

    frame.Banner = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    frame.Banner:SetPoint('TOPLEFT', frame, 'TOPLEFT', 18, -36)
    frame.Banner:SetJustifyH('LEFT')
    frame.DisableGILButton = Button(frame, 'Turn off Global Ignore List', 200, function()
        local disable = C_AddOns and C_AddOns.DisableAddOn or DisableAddOn
        if disable then disable('GlobalIgnoreList') end
        frame.Banner:SetText(L('Global Ignore List is off after /reload.'))
    end)
    frame.DisableGILButton:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -14, -34)
    frame.ImportButton = Button(frame, 'Take over Global Ignore List', 210, function()
        local result = F().ImportGIL()
        if result then
            frame.Banner:SetText(string.format(L('Taken over: %d rules, %d players.'), result.rules, result.players))
            selectedRule = nil
        end
        W.Refresh()
    end)
    frame.ImportButton:SetPoint('RIGHT', frame.DisableGILButton, 'LEFT', -6, 0)
    frame.Total = frame:CreateFontString(nil, 'OVERLAY', 'GameFontDisableSmall')
    frame.Total:SetPoint('RIGHT', frame.ImportButton, 'LEFT', -12, 0)
    frame.Banner:SetPoint('RIGHT', frame.Total, 'LEFT', -12, 0)

    frame.Pages = {
        CreateRulesTab(frame.Inset),
        CreateKindsTab(frame.Inset),
        CreateIgnoreTab(frame.Inset),
        CreateJournalTab(frame.Inset),
    }

    frame.Tabs = {}
    for index, label in ipairs({ 'Rules', 'What is hidden', 'Ignore list', 'Journal' }) do
        local tab = CreateFrame('Button', FRAME_NAME .. 'Tab' .. index, frame, 'PanelTabButtonTemplate')
        tab:SetID(index)
        tab:SetText(L(label))
        if index == 1 then
            tab:SetPoint('TOPLEFT', frame, 'BOTTOMLEFT', 20, 2)
        else
            tab:SetPoint('LEFT', frame.Tabs[index - 1], 'RIGHT', -15, 0)
        end
        tab:SetScript('OnShow', function(self) PanelTemplates_TabResize(self, 30, nil, 20) end)
        tab:SetScript('OnClick', function(self)
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            SelectTab(self:GetID())
        end)
        PanelTemplates_TabResize(tab, 30, nil, 20)
        frame.Tabs[index] = tab
    end
    PanelTemplates_SetNumTabs(frame, #frame.Tabs)

    frame:SetScript('OnShow', function()
        if Scan.Utils.FitFrame then Scan.Utils.FitFrame(frame, 20, 40) end
        SelectTab(frame.tab or TAB_RULES)
        local rule = selectedRule and F().RuleByID(selectedRule)
        if rule then ShowRule(rule) end
    end)
    frame:Hide()

    -- Keys added from the text selection tool show at once.
    F().OnChange(function() W.Refresh() end)
end

function W.Toggle()
    if not frame then Create() end
    frame:SetShown(not frame:IsShown())
end

function W.Show(tab)
    if not frame then Create() end
    frame:Show()
    if tab then SelectTab(tab) end
end

function W.IsShown()
    return frame ~= nil and frame:IsShown()
end

W.TAB_RULES, W.TAB_KINDS, W.TAB_IGNORE, W.TAB_JOURNAL = TAB_RULES, TAB_KINDS, TAB_IGNORE, TAB_JOURNAL
