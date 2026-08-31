local HironCraftScan = select(2, ...)

local LID = HironCraftScan.CONST.TEXT
local function L(id)
    return HironCraftScan.LOCAL:GetText(id)
end

local panel = nil

function HironCraftScan.Config.LoadGlobalConfigOptions()
    if not panel then
        panel = CreateFrame(
            'Frame',
            'HironCraftScanGeneralConfigPanel',
            HironCraftScanConfigPage.Options,
            'HironCraftScanGeneralConfigPanelTemplate'
        )
    end
    panel.Matching:Init()
    panel.Greetings:Init()
    return panel
end

HironCraftScanGeneralConfigPanelMixin = {}

function HironCraftScanGeneralConfigPanelMixin:TabGroup()
    if not self.tabGroup then
        self.tabGroup = CreateTabGroup()
    end
    return self.tabGroup
end

HironCraftScanGeneralConfigMatchingMixin = {}

function HironCraftScanGeneralConfigMatchingMixin:Init()
    self.tabGroup = self:GetParent():TabGroup()
    self.Title:SetText(L('Base Filters'))
    HironCraftScan.SetupTextInput(self, self.Keywords, 'inclusions')
    HironCraftScan.SetupTextInput(self, self.Exclusions, 'exclusions')
end

function HironCraftScanGeneralConfigMatchingMixin:GetConfigValue(keyword)
    return HironCraftScan.DB.settings[keyword]
end

function HironCraftScanGeneralConfigMatchingMixin:UpdateConfigValue(keyword, value)
    HironCraftScan.DB.settings[keyword] = value
end

function HironCraftScanGeneralConfigMatchingMixin:OnConfigChange()
    HironCraftScan.Config.OnConfigChange()
end

HironCraftScanGreetingConfigPanelMixin = {}

function HironCraftScanGreetingConfigPanelMixin:Init()
    self.tabGroup = self:GetParent():TabGroup()
    self.Title:SetText(L('Customer Greetings'))
    self.greetings = {
        ['GREETING_I_CAN_CRAFT_ITEM'] = { placeholders = { '{crafter}', '{item}' } },
        ['GREETING_I_HAVE_PROF'] = {
            placeholders = { '{crafter}', '{profession}', '{profession_link}' },
        },
        ['GREETING_ALT_CAN_CRAFT_ITEM'] = { placeholders = { '{crafter}', '{item}' } },
        ['GREETING_ALT_HAS_PROF'] = { placeholders = { '{crafter}', '{profession}' } },
        ['GREETING_ALT_SUFFIX'] = { placeholders = { '{crafter}' } },
        ['GREETING_BUSY'] = { placeholders = {} },
    }

    for _, key in pairs({
        'GREETING_I_CAN_CRAFT_ITEM',
        'GREETING_I_HAVE_PROF',
        'GREETING_ALT_CAN_CRAFT_ITEM',
        'GREETING_ALT_HAS_PROF',
        'GREETING_ALT_SUFFIX',
        'GREETING_BUSY',
    }) do
        HironCraftScan.SetupTextInput(self, self[key], key)
    end
end

function HironCraftScanGreetingConfigPanelMixin:GetConfigValue(keyword)
    local sv = HironCraftScan.DB.settings.greeting or {}
    return sv[keyword] or L(LID[keyword])
end

function HironCraftScanGreetingConfigPanelMixin:UpdateConfigValue(keyword, value)
    local sv = HironCraftScan.Utils.saved(HironCraftScan.DB.settings, 'greeting', {})
    if value == '' then
        sv[keyword] = nil
    else
        sv[keyword] = value
    end
    HironCraftScanComm:ShareCustomGreeting(sv)
end

function HironCraftScanGreetingConfigPanelMixin:OnConfigChange() end

function HironCraftScanGreetingConfigPanelMixin:GetDisplayValue(keyword)
    return HironCraftScan.Config.SubstituteTags(self:GetConfigValue(keyword))
end

function HironCraftScanGreetingConfigPanelMixin:IncludeContextInAutoComplete(keyword)
    return true
end

function HironCraftScanGreetingConfigPanelMixin:Validate(keyword, user_value, reporter)
    value = HironCraftScan.Config.SubstituteTags(user_value)

    local extra_placeholders = {}
    local num_extra_placeholders = 0
    local placeholders = self.greetings[keyword].placeholders
    for placeholder in string.gmatch(value, '%b{}') do
        if not HironCraftScan.Utils.Contains(placeholders, placeholder) then
            table.insert(extra_placeholders, placeholder)
            num_extra_placeholders = num_extra_placeholders + 1
        end
    end
    local missing_placeholders = {}
    local num_missing_placeholders = 0
    for i, placeholder in ipairs(placeholders) do
        if not value:match(placeholder) then
            table.insert(missing_placeholders, placeholder)
            num_missing_placeholders = num_missing_placeholders + 1
        end
    end

    local messages = {}
    if num_extra_placeholders > 0 then
        table.insert(
            messages,
            string.format(L(LID.EXTRA_PLACEHOLDERS), table.concat(extra_placeholders, ', '))
        )
    end
    if value:match('%%s') then
        table.insert(messages, L(LID.LEGACY_PLACEHOLDERS))
    end
    if num_missing_placeholders > 0 then
        table.insert(
            messages,
            string.format(L(LID.MISSING_PLACEHOLDERS), table.concat(missing_placeholders, ', '))
        )
    end
    local message = table.concat(messages, '\n\n')
    if num_extra_placeholders > 0 then
        reporter:Error(message)
    elseif message ~= '' then
        reporter:Warning(function(tooltip)
            tooltip:SetText(message, 1, 1, 1, 1, true)
            HironCraftScan.Config.AppendSubstitutionTagTooltip(user_value, tooltip, false)
        end)
    else
        HironCraftScan.Config.PopulateSubstitutionTagTooltip(user_value, reporter)
    end
end
