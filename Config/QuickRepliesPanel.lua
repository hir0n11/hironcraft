local HironCraftScan = select(2, ...)

local function L(id)
    return HironCraftScan.LOCAL:GetText(id)
end

local panel = nil

local FULL_PANEL_WIDTH = 750
local FULL_CONTENT_WIDTH = 700
local FULL_ROW_HEIGHT = 112
local FULL_ROW_STEP = 116

local COMPACT_PANEL_WIDTH = 350
local COMPACT_CONTENT_WIDTH = 300
local COMPACT_ROW_HEIGHT = 226
local COMPACT_ROW_STEP = 230

local allowedContext = {
    crafter = true,
    item = true,
    profession = true,
    profession_link = true,
    commission = true,
}

local function UnknownContextPlaceholders(value)
    local expanded = HironCraftScan.Config.SubstituteTags(value)
    local unknown = {}
    for placeholder in expanded:gmatch('{(.-)}') do
        if not allowedContext[placeholder] then
            table.insert(unknown, '{' .. placeholder .. '}')
        end
    end
    return unknown
end

function HironCraftScan.Config.LoadQuickReplyConfigOptions(_, isCollapsed)
    if not panel then
        panel = CreateFrame('Frame', 'HironCraftScanQuickReplyConfigPanel', HironCraftScanConfigPage.Options)
        panel:SetSize(FULL_PANEL_WIDTH, 575)
        panel:SetPoint('TOPLEFT', 0, -6)
        Mixin(panel, HironCraftScanQuickReplyConfigPanelMixin)
        panel:CreateControls()
    end
    panel:Init(isCollapsed)
    return panel
end

HironCraftScanQuickReplyConfigPanelMixin = {}

local function CreateLabel(parent, font, text)
    local label = parent:CreateFontString(nil, 'OVERLAY', font)
    label:SetText(text)
    label:SetJustifyH('LEFT')
    return label
end

function HironCraftScanQuickReplyConfigPanelMixin:CreateControls()
    self.Title = CreateLabel(self, 'GameFontNormalLarge', L('Quick Replies'))
    self.Title:SetPoint('TOPLEFT', 12, -8)

    self.Description = CreateLabel(self, 'GameFontHighlightSmall', L('Quick Replies Description'))
    self.Description:SetPoint('TOPLEFT', self.Title, 'BOTTOMLEFT', 0, -6)
    self.Description:SetPoint('RIGHT', -24, 0)
    self.Description:SetHeight(34)
    self.Description:SetJustifyV('TOP')

    self.Enabled = CreateFrame('Frame', nil, self, 'HironCraftScanCheckButtonTemplate')
    self.Enabled:SetPoint('TOPLEFT', self.Description, 'BOTTOMLEFT', -5, -3)
    self.Enabled:SetWidth(300)

    self.TypoTolerance = CreateFrame('Frame', nil, self, 'HironCraftScanCheckButtonTemplate')
    self.TypoTolerance:SetPoint('LEFT', self.Enabled, 'RIGHT', 8, 0)
    self.TypoTolerance:SetWidth(250)

    self.AddButton = CreateFrame('Button', nil, self, 'HironCraftScanConfigButtonTemplate')
    self.AddButton:SetPoint('TOPRIGHT', self.Description, 'BOTTOMRIGHT', 0, -1)
    HironCraftScan.SetupButton(self.AddButton, 'quick_reply.new.button', function()
        self:ShowCreateDialog()
    end)

    self.Scroll = CreateFrame(
        'ScrollFrame',
        'HironCraftScanQuickReplyConfigScroll',
        self,
        'UIPanelScrollFrameTemplate'
    )
    self.Scroll:SetPoint('TOPLEFT', self.Enabled, 'BOTTOMLEFT', 5, -8)
    self.Scroll:SetPoint('BOTTOMRIGHT', self, 'BOTTOMRIGHT', -30, 8)

    self.Content = CreateFrame('Frame', nil, self.Scroll)
    self.Content:SetWidth(FULL_CONTENT_WIDTH)
    self.Scroll:SetScrollChild(self.Content)

    self.Rows = {}
end

function HironCraftScanQuickReplyConfigPanelMixin:Init(isCollapsed)
    self.isCollapsed = isCollapsed
    self:RefreshRows()
end

local function CreateRow(panel, index)
    local row = CreateFrame('Frame', nil, panel.Content)
    row:SetSize(FULL_CONTENT_WIDTH, FULL_ROW_HEIGHT)

    row.Background = row:CreateTexture(nil, 'BACKGROUND')
    row.Background:SetAllPoints()

    row.Separator = row:CreateTexture(nil, 'BORDER')
    row.Separator:SetPoint('BOTTOMLEFT', 0, -2)
    row.Separator:SetPoint('BOTTOMRIGHT', 0, -2)
    row.Separator:SetHeight(2)
    row.Separator:SetColorTexture(1, 0.72, 0.05, 0.9)
    row.Separator:Hide()

    row.Enabled = CreateFrame('Frame', nil, row, 'HironCraftScanCheckButtonTemplate')
    row.Enabled:SetPoint('TOPLEFT', 3, -4)
    row.Enabled:SetWidth(114)

    row.Delete = CreateFrame('Button', nil, row, 'UIPanelButtonTemplate')
    row.Delete:SetSize(88, 22)
    row.Delete:SetPoint('TOPLEFT', 8, -42)
    row.Delete:SetText(L('Delete'))

    row.PriorityLabel = CreateLabel(row, 'GameFontNormalSmall', L('dialog.quick_reply.priority'))
    row.PriorityLabel:SetSize(64, 20)
    row.PriorityLabel:SetJustifyV('MIDDLE')

    row.Priority = CreateFrame('EditBox', nil, row, 'InputBoxTemplate')
    row.Priority:SetSize(42, 20)
    row.Priority:SetAutoFocus(false)
    row.Priority:SetNumeric(true)
    row.Priority:SetMaxLetters(3)
    row.Priority:SetJustifyH('CENTER')

    row.Keywords = CreateFrame('Frame', nil, row, 'HironCraftScanTextInputTemplate')
    row.Keywords:SetSize(280, 102)
    row.Keywords:SetPoint('TOPLEFT', 116, 0)

    row.Response = CreateFrame('Frame', nil, row, 'HironCraftScanTextInputTemplate')
    row.Response:SetSize(298, 102)
    row.Response:SetPoint('TOPLEFT', 398, 0)

    panel.Rows[index] = row
    return row
end

local function LayoutRow(row, isCollapsed)
    row.Enabled:ClearAllPoints()
    row.Delete:ClearAllPoints()
    row.PriorityLabel:ClearAllPoints()
    row.Priority:ClearAllPoints()
    row.Keywords:ClearAllPoints()
    row.Response:ClearAllPoints()

    row.Enabled:SetPoint('TOPLEFT', 3, -4)
    local eventOnly = row.definition and row.definition.eventOnly

    if isCollapsed then
        row:SetSize(COMPACT_CONTENT_WIDTH, COMPACT_ROW_HEIGHT)
        row.Enabled:SetWidth(eventOnly and 260 or 190)

        row.Delete:SetPoint('TOPRIGHT', -3, -2)

        if eventOnly then
            row.PriorityLabel:Hide()
            row.Priority:Hide()
            row.Response:SetSize(COMPACT_CONTENT_WIDTH, 150)
            row.Response:SetPoint('TOPLEFT', 0, -28)
        else
            row.PriorityLabel:SetPoint('TOPLEFT', 5, -31)
            row.Priority:SetPoint('TOPLEFT', 70, -29)
            row.PriorityLabel:Show()
            row.Priority:Show()

            row.Keywords:SetSize(COMPACT_CONTENT_WIDTH, 80)
            row.Keywords:SetPoint('TOPLEFT', 0, -55)

            row.Response:SetSize(COMPACT_CONTENT_WIDTH, 80)
            row.Response:SetPoint('TOPLEFT', 0, -139)
        end
    else
        row:SetSize(FULL_CONTENT_WIDTH, FULL_ROW_HEIGHT)
        row.Enabled:SetWidth(eventOnly and 184 or 114)

        row.Delete:SetPoint('TOPLEFT', 8, -76)

        if eventOnly then
            row.PriorityLabel:Hide()
            row.Priority:Hide()
            row.Response:SetSize(508, 102)
            row.Response:SetPoint('TOPLEFT', 188, 0)
        else
            row.PriorityLabel:SetPoint('TOPLEFT', 5, -39)
            row.Priority:SetPoint('TOPLEFT', 70, -37)
            row.PriorityLabel:Show()
            row.Priority:Show()

            row.Keywords:SetSize(280, 102)
            row.Keywords:SetPoint('TOPLEFT', 116, 0)

            row.Response:SetSize(298, 102)
            row.Response:SetPoint('TOPLEFT', 398, 0)
        end
    end
end

function HironCraftScanQuickReplyConfigPanelMixin:Layout(isCollapsed)
    self.isCollapsed = isCollapsed

    local panelWidth = isCollapsed and COMPACT_PANEL_WIDTH or FULL_PANEL_WIDTH
    local contentWidth = isCollapsed and COMPACT_CONTENT_WIDTH or FULL_CONTENT_WIDTH
    local rowStep = isCollapsed and COMPACT_ROW_STEP or FULL_ROW_STEP

    self:SetWidth(panelWidth)
    self.Enabled:SetWidth(isCollapsed and 190 or 300)
    self.Content:SetWidth(contentWidth)

    self.TypoTolerance:ClearAllPoints()
    self.Scroll:ClearAllPoints()
    if isCollapsed then
        self.TypoTolerance:SetPoint('TOPLEFT', self.Enabled, 'BOTTOMLEFT', 0, 0)
        self.TypoTolerance:SetWidth(300)
        self.Scroll:SetPoint('TOPLEFT', self.TypoTolerance, 'BOTTOMLEFT', 5, -8)
    else
        self.TypoTolerance:SetPoint('LEFT', self.Enabled, 'RIGHT', 8, 0)
        self.TypoTolerance:SetWidth(250)
        self.Scroll:SetPoint('TOPLEFT', self.Enabled, 'BOTTOMLEFT', 5, -8)
    end
    self.Scroll:SetPoint('BOTTOMRIGHT', self, 'BOTTOMRIGHT', -30, 8)

    for index = 1, self.definitionCount or 0 do
        local row = self.Rows[index]
        LayoutRow(row, isCollapsed)
        row:ClearAllPoints()
        row:SetPoint('TOPLEFT', 0, -(index - 1) * rowStep)
    end

    self.Content:SetHeight(math.max(1, (self.definitionCount or 0) * rowStep))
end

local function SetupCustomTooltip(frame, title, body)
    frame:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
        GameTooltip:SetText(title, nil, nil, nil, nil, true)
        GameTooltip:AddLine(' ')
        GameTooltip:AddLine(body, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame:SetScript('OnLeave', function()
        GameTooltip:Hide()
    end)
end

local function SetupPriorityInput(panel, row, keyword)
    local function RefreshValue()
        row.Priority:SetText(tostring(HironCraftScan.QuickReplies.NormalizePriority(
            panel:GetConfigValue(keyword)
        )))
    end

    RefreshValue()
    row.Priority:SetScript('OnEnterPressed', function(self)
        self:ClearFocus()
    end)
    row.Priority:SetScript('OnEscapePressed', function(self)
        RefreshValue()
        self:ClearFocus()
    end)
    row.Priority:SetScript('OnEditFocusLost', function(self)
        local priority = HironCraftScan.QuickReplies.NormalizePriority(self:GetText())
        panel:UpdateConfigValue(keyword, priority)
        self:SetText(tostring(priority))
        panel:OnConfigChange(keyword)
    end)
    SetupCustomTooltip(
        row.Priority,
        L('dialog.quick_reply.priority'),
        L('dialog.quick_reply.priority.tooltip.body')
    )
    if panel.tabGroup then
        panel.tabGroup:AddFrame(row.Priority)
    end
end

function HironCraftScanQuickReplyConfigPanelMixin:RefreshRows()
    self.tabGroup = CreateTabGroup()
    HironCraftScan.SetupCheckBox(self, self.Enabled, 'quick_reply.enabled', 300)
    HironCraftScan.SetupCheckBox(self, self.TypoTolerance, 'quick_reply.typo_tolerance', 250)

    local definitions = HironCraftScan.QuickReplies:GetDefinitions()
    self.definitionCount = #definitions
    for index, definition in ipairs(definitions) do
        local row = self.Rows[index] or CreateRow(self, index)
        row.definition = definition
        if definition.eventOnly then
            row.Background:SetColorTexture(0.18, 0.13, 0.02, 0.42)
            row.Separator:Show()
        else
            row.Background:SetColorTexture(0.08, 0.08, 0.08, index % 2 == 0 and 0.3 or 0.18)
            row.Separator:Hide()
        end

        local prefix = 'quick_reply.' .. definition.key .. '.'
        HironCraftScan.SetupCheckBox(self, row.Enabled, prefix .. 'enabled', 98)
        if definition.eventOnly then
            row.Keywords:Hide()
        else
            SetupPriorityInput(self, row, prefix .. 'priority')
            HironCraftScan.SetupTextInput(self, row.Keywords, prefix .. 'keywords')
            row.Keywords:Show()
        end
        HironCraftScan.SetupTextInput(self, row.Response, prefix .. 'response')

        if definition.custom then
            row.Enabled.Title:SetText(definition.label)
            row.Keywords.Title:SetText(L('dialog.quick_reply.custom.keywords'))
            row.Response.Title:SetText(L('dialog.quick_reply.custom.response'))
            SetupCustomTooltip(
                row.Enabled,
                definition.label,
                L('dialog.quick_reply.custom.enabled.tooltip.body')
            )
            HironCraftScan.SetupInfoIcon(row.Keywords.Info, 'quick_reply.custom.keywords')
            HironCraftScan.SetupInfoIcon(row.Response.Info, 'quick_reply.custom.response')
            row.Delete:SetScript('OnClick', function()
                if HironCraftScan.QuickReplies:DeleteCustomTemplate(definition.key) then
                    self:RefreshRows()
                end
            end)
            row.Delete:Show()
        else
            row.Delete:Hide()
        end
        row:Show()
    end

    for index = #definitions + 1, #self.Rows do
        self.Rows[index]:Hide()
    end
    self:Layout(self.isCollapsed)
end

function HironCraftScanQuickReplyConfigPanelMixin:ShowCreateDialog()
    local function Validator(index, value)
        if index == 1 and not HironCraftScan.QuickReplies:IsLabelAvailable(value) then
            return { error = L('Quick reply duplicate name') }
        end
        if index == 3 then
            local unknown = UnknownContextPlaceholders(value)
            if #unknown > 0 then
                return {
                    error = string.format(
                        L('Unknown quick reply placeholders'),
                        table.concat(unknown, ', ')
                    ),
                }
            end
        end
    end

    HironCraftScan.Dialog.Show({
        key = 'create_quick_reply',
        title = L('Create a Quick Reply'),
        submit = L('Save'),
        width = 520,
        OnAccept = function(label, keywords, response)
            if HironCraftScan.QuickReplies:CreateCustomTemplate(label, keywords, response) then
                self:RefreshRows()
            end
        end,
        elements = {
            {
                type = HironCraftScan.Dialog.Element.Text,
                text = L('Quick reply name description'),
            },
            {
                type = HironCraftScan.Dialog.Element.EditBox,
                Validator = Validator,
            },
            {
                type = HironCraftScan.Dialog.Element.Text,
                text = L('Quick reply keywords description'),
            },
            {
                type = HironCraftScan.Dialog.Element.EditBox,
                multiline = true,
            },
            {
                type = HironCraftScan.Dialog.Element.Text,
                text = L('Quick reply response description'),
            },
            {
                type = HironCraftScan.Dialog.Element.EditBox,
                multiline = true,
            },
        },
    })
end

local function ParseTemplateKeyword(keyword)
    return keyword:match('^quick_reply%.([^.]+)%.([^.]+)$')
end

function HironCraftScanQuickReplyConfigPanelMixin:GetConfigValue(keyword)
    local config = HironCraftScan.QuickReplies:GetConfig()
    if keyword == 'quick_reply.enabled' then
        return config.enabled
    end
    if keyword == 'quick_reply.typo_tolerance' then
        return config.typo_tolerance
    end

    local templateKey, field = ParseTemplateKeyword(keyword)
    local template = templateKey and config.templates[templateKey]
    return template and template[field] or ''
end

function HironCraftScanQuickReplyConfigPanelMixin:UpdateConfigValue(keyword, value)
    local config = HironCraftScan.QuickReplies:GetConfig()
    if keyword == 'quick_reply.enabled' then
        config.enabled = value
        return
    end
    if keyword == 'quick_reply.typo_tolerance' then
        config.typo_tolerance = value
        return
    end

    local templateKey, field = ParseTemplateKeyword(keyword)
    local template = templateKey and config.templates[templateKey]
    if template then
        if field == 'priority' then
            value = HironCraftScan.QuickReplies.NormalizePriority(value)
        end
        template[field] = value
    end
end

function HironCraftScanQuickReplyConfigPanelMixin:GetDisplayValue(keyword)
    local value = self:GetConfigValue(keyword)
    if type(value) == 'string' then
        return HironCraftScan.Config.SubstituteTags(value)
    end
    return value
end

function HironCraftScanQuickReplyConfigPanelMixin:IncludeContextInAutoComplete(keyword)
    return keyword:match('%.response$') ~= nil
end

function HironCraftScanQuickReplyConfigPanelMixin:Validate(keyword, value, reporter)
    if not keyword:match('%.response$') then
        reporter:Clear()
        return
    end

    local unknown = UnknownContextPlaceholders(value)

    if #unknown > 0 then
        reporter:Error(string.format(L('Unknown quick reply placeholders'), table.concat(unknown, ', ')))
    else
        HironCraftScan.Config.PopulateSubstitutionTagTooltip(value, reporter)
    end
end

function HironCraftScanQuickReplyConfigPanelMixin:OnConfigChange()
    HironCraftScan.QuickReplies:NotifyConfigChanged()
end

HironCraftScan.Events:Register('QUICK_REPLIES_UPDATED', function()
    if panel then
        panel:RefreshRows()
    end
end)
