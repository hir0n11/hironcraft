local Scan=select(2,...)
local function L(key) return Scan.LOCAL:GetText(key) end
local panel
local function Label(parent,font,text)
    local label=parent:CreateFontString(nil,'OVERLAY',font)
    label:SetText(text);label:SetJustifyH('LEFT')
    return label
end
local function Validate(key,value,reporter)
    local valid,reason,alias,other=Scan.ClassMatching.ValidateSynonyms(key,value)
    if valid then reporter:Clear()
    elseif reason=='Equipment alias already assigned' then
        reporter:Error(string.format(L(reason),alias,L('Equipment type '..other)))
    else reporter:Error(L(reason)) end
end

HironCraftScanEquipmentAliasesPanelMixin={}
local Panel=HironCraftScanEquipmentAliasesPanelMixin
function Panel:CreateControls()
    self:SetPoint('TOPLEFT',0,-6)
    self:SetHeight(575)
    self.Title=Label(self,'GameFontNormalLarge',L('Equipment Names'))
    self.Title:SetPoint('TOPLEFT',12,-8)
    self.Description=Label(self,'GameFontHighlightSmall',L('Equipment aliases description'))
    self.Description:SetPoint('TOPLEFT',12,-34);self.Description:SetPoint('RIGHT',-24,0)
    self.Description:SetHeight(54);self.Description:SetJustifyV('TOP')
    self.Enabled=CreateFrame('Frame',nil,self,'HironCraftScanCheckButtonTemplate')
    self.Enabled:SetPoint('TOPLEFT',7,-86)
    self.Scroll=CreateFrame('ScrollFrame','HironCraftScanEquipmentAliasesScroll',self,'UIPanelScrollFrameTemplate')
    self.Scroll:SetPoint('TOPLEFT',12,-116);self.Scroll:SetPoint('BOTTOMRIGHT',-30,8)
    self.Content=CreateFrame('Frame',nil,self.Scroll)
    self.Scroll:SetScrollChild(self.Content)
    self.Rows={}
end
function Panel:GetConfigValue() return Scan.DB.settings.match_customer_class~=false end
function Panel:UpdateConfigValue(_,value) Scan.DB.settings.match_customer_class=value end
function Panel:OnConfigChange() end
function Panel:Init(collapsed)
    self.tabGroup=CreateTabGroup()
    Scan.SetupCheckBox(self,self.Enabled,'equipment_aliases.enabled',collapsed and 300 or 650)
    local definitions=Scan.ClassMatching.GetSynonymDefinitions()
    for index,definition in ipairs(definitions) do
        local row=self.Rows[index]
        if not row then
            row=CreateFrame('Frame',nil,self.Content,'HironCraftScanTextInputTemplate')
            row.Reset=CreateFrame('Button',nil,row,'UIPanelButtonTemplate')
            row.Reset:SetSize(88,20);row.Reset:SetPoint('TOPRIGHT',-42,-3)
            row.Reset:SetText(L('Equipment aliases default button'))
            row.Reset:SetNormalFontObject('GameFontNormalSmall')
            row.Title:ClearAllPoints();row.Title:SetPoint('TOPLEFT',10,-5)
            row.Title:SetPoint('RIGHT',-142,0);row.Title:SetHeight(25)
            row.GetConfigValue=function(r) return Scan.ClassMatching.GetSynonyms(r.key) end
            row.GetInstructions=function() return L('Equipment aliases input hint') end
            row.Validate=function(r,_,value,reporter) Validate(r.key,value,reporter) end
            row.UpdateConfigValue=function(r,_,value) Scan.ClassMatching.SetSynonyms(r.key,value) end
            row.OnConfigChange=function(r) r.Expression.EditBox:SetText(r:GetConfigValue()) end
            self.Rows[index]=row
        end
        row.key=definition.key;row.label=definition.label;row.tabGroup=self.tabGroup
        Scan.SetupTextInput(row,row,'equipment_aliases')
        row.Title:SetText(L('Equipment type '..definition.label))
        row.Reset:SetScript('OnClick',function()
            local ok,reason,alias,other=Scan.ClassMatching.ResetSynonyms(row.key)
            if ok then
                row.Expression.EditBox:SetText(row:GetConfigValue())
                row.Expression.ValidationIcon:Clear()
            elseif reason=='Equipment alias already assigned' then
                row.Expression.ValidationIcon:Error(string.format(L(reason),alias,L('Equipment type '..other)))
            else row.Expression.ValidationIcon:Error(L(reason)) end
        end)
        row:Show()
    end
    self:Layout(collapsed)
end
function Panel:Layout(collapsed)
    local width=collapsed and 300 or 700
    local step=collapsed and 130 or 104
    self:SetWidth(collapsed and 350 or 750)
    self.Description:SetHeight(collapsed and 90 or 54)
    self.Enabled:ClearAllPoints();self.Enabled:SetPoint('TOPLEFT',7,collapsed and -128 or -86)
    self.Scroll:ClearAllPoints()
    self.Scroll:SetPoint('TOPLEFT',12,collapsed and -158 or -116)
    self.Scroll:SetPoint('BOTTOMRIGHT',-30,8)
    self.Content:SetWidth(width)
    for index,row in ipairs(self.Rows) do
        row:SetSize(width,step-4);row:ClearAllPoints()
        row:SetPoint('TOPLEFT',0,-(index-1)*step)
    end
    self.Content:SetHeight(math.max(1,#self.Rows*step))
end
function Scan.Config.LoadEquipmentAliasesConfigOptions(_,collapsed)
    if not panel then
        panel=CreateFrame('Frame','HironCraftScanEquipmentAliasesPanel',HironCraftScanConfigPage.Options)
        Mixin(panel,Panel);panel:CreateControls()
    end
    panel:Init(collapsed)
    return panel
end
