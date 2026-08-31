local HironCraftScan = select(2, ...)

local LID = HironCraftScan.CONST.TEXT
local function L(id)
    return HironCraftScan.LOCAL:GetText(id)
end

local panel = nil
function HironCraftScan.Config.LoadProfessionConfigOptions(configInfo)
    if not panel then
        panel = CreateFrame(
            'Frame',
            'HironCraftScanProfessionConfigPanel',
            HironCraftScanConfigPage.Options,
            'HironCraftScanProfessionConfigPanelTemplate'
        )
    end
    panel:Init(configInfo)
    return panel
end

HironCraftScanProfessionConfigPanelMixin = {}

function HironCraftScanProfessionConfigPanelMixin:Init(configInfo)
    self.configInfo = configInfo
    self.Left:Hide()
    self.Right:Hide()

    self.tabGroup = CreateTabGroup()

    self:SetupProfessionIcon()

    self.defaults = {
        keywords = '',
        commission = '',
        exclusions = '',
        greeting = '',
        omit_general = false,
    }

    HironCraftScan.SetupTextInput(self, self.Left.Keywords, 'prof.keywords')
    HironCraftScan.SetupTextInput(self, self.Left.Exclusions, 'prof.exclusions')
    HironCraftScan.SetupTextInput(self, self.Left.Commission, 'prof.commission')

    local CHECK_BOX_WIDTH = 240
    HironCraftScan.SetupTextInput(self, self.Right.Greeting, 'prof.greeting')
    HironCraftScan.SetupCheckBox(self, self.Right.OmitGeneral, 'prof.omit_general', CHECK_BOX_WIDTH)

    self.Left:Show()
    self.Right:Show()
end

function HironCraftScanProfessionConfigPanelMixin:SetupProfessionIcon()
    local icon = C_TradeSkillUI.GetTradeSkillTexture(self.configInfo.profID)
    local professionName =
        HironCraftScan.Utils.ColorizedProfessionNameByID(self.configInfo.profConfig.parentProfID)

    self.IconLabel:ClearAllPoints()
    self.IconLabel:SetPoint('LEFT', self.ProfessionIcon, 'RIGHT', 14, 17)

    self.IconLabel:SetHeight(200)
    self.IconLabel:SetText(professionName)
    self.IconLabel:SetWidth(500)
    self.IconLabel:SetHeight(self.IconLabel:GetStringHeight())

    self.IconSubLabel:SetText(HironCraftScan.ColorizeCrafterName(self.configInfo.char))

    ClearItemButtonOverlay(self.ProfessionIcon)
    SetItemButtonTexture(self.ProfessionIcon, icon)
    SetItemButtonQuality(self.ProfessionIcon, Enum.ItemQuality.Common)
    SetItemButtonBorderVertexColor(
        self.ProfessionIcon,
        HironCraftScan.Utils.ProfessionColor(self.configInfo.profConfig.parentProfID):GetRGB()
    )
end

local function KeywordToConfigKey(keyword)
    -- Our config uses short words, but we need longer keywords to distinguish
    -- between localization tags (e.g. prof.greeting vs item.greeting)
    return keyword:sub(6)
end

-- Keywords and commission are stored on the parent profession config.
-- Greetings and omit are stored on the expansion specific profession
-- config.
local function IsPPConfigKey(key)
    return key == 'keywords' or key == 'exclusions' or key == 'commission'
end

function HironCraftScanProfessionConfigPanelMixin:IncludeContextInAutoComplete(keyword)
    -- Keywords should not include context, but greetings should
    return KeywordToConfigKey(keyword) == 'greeting'
end

function HironCraftScanProfessionConfigPanelMixin:GetConfigValue(keyword)
    local key = KeywordToConfigKey(keyword)

    if IsPPConfigKey(key) then
        return self.configInfo.ppConfig[key] or self.defaults[key]
    end
    return self.configInfo.profConfig[key] or self.defaults[key]
end

function HironCraftScanProfessionConfigPanelMixin:UpdateConfigValue(keyword, value)
    local key = KeywordToConfigKey(keyword)
    if IsPPConfigKey(key) then
        self.configInfo.ppConfig[key] = value
    else
        self.configInfo.profConfig[key] = value
    end
end

function HironCraftScanProfessionConfigPanelMixin:OnConfigChange()
    HironCraftScan.Config.OnConfigChange(self.configInfo)
end

function HironCraftScanProfessionConfigPanelMixin:Validate(keyword, value, reporter) end

function HironCraftScanProfessionConfigPanelMixin:GetInstructions(keyword)
    local function Wrap(text)
        return '{' .. text .. '}'
    end

    local key = KeywordToConfigKey(keyword)

    if IsPPConfigKey(key) then
        if key == 'keywords' then
            local profInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(
                self.configInfo.profConfig.parentProfID
            )
            -- Default to a {<profession>} tag, and we'll generate a default tag
            -- entry with some defaulted keywords for that tag.
            return Wrap(profInfo.professionName)
        elseif key == 'commission' then
            return Wrap(L('Commission'))
        end
    end
    return nil
end

function HironCraftScanProfessionConfigPanelMixin:GetDisplayValue(keyword)
    return HironCraftScan.Config.SubstituteTags(self:GetConfigValue(keyword))
end

function HironCraftScanProfessionConfigPanelMixin:InstructionsAccepted(tag)
    HironCraftScan.Config.AutoCreateFromDefault(tag)
end

function HironCraftScanProfessionConfigPanelMixin:Validate(keyword, value, reporter)
    HironCraftScan.Config.PopulateSubstitutionTagTooltip(value, reporter)
end
