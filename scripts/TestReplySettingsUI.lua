-- Run the real panels and input callbacks with only the WoW frame boundary mocked.
local function noop() end
local methods={}
local function surface(parent)
    return setmetatable({parent=parent,scripts={},points={},shown=true,text='',width=300}, {__index=methods})
end
function methods:SetSize(w,h) self.width=w;self.height=h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetPoint(...) self.points[#self.points+1]={...} end
function methods:ClearAllPoints() self.points={} end
function methods:SetScript(key,fn) self.scripts[key]=fn end
function methods:GetScript(key) return self.scripts[key] end
function methods:HookScript(key,fn) self.scripts[key]=fn end
function methods:SetText(text) self.text=text end
function methods:GetText() return self.text end
function methods:SetChecked(value) self.checked=value end
function methods:GetChecked() return self.checked end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:IsShown() return self.shown end
function methods:CreateFontString() return surface(self) end
methods.CreateTexture=methods.CreateFontString
function methods:GetFont() return 'font',12,'' end
function methods:HasFocus() return self.focused==true end
for _,method in ipairs({'SetJustifyH','SetJustifyV','SetAllPoints','SetColorTexture','SetNormalFontObject',
    'SetAutoFocus','SetNumeric','SetMaxLetters','SetMultiLine','SetFont','SetAlpha','SetScrollChild','FitToText',
    'ClearFocus'}) do methods[method]=noop end
function Mixin(target,source) for key,value in pairs(source) do target[key]=value end end
function CreateFrame(_,_,parent,template)
    local frame=surface(parent)
    if template=='HironCraftScanCheckButtonTemplate' then
        frame.Title=surface(frame);frame.Act=surface(frame)
    elseif template=='HironCraftScanTextInputTemplate' then
        frame.Title=surface(frame);frame.Info=surface(frame);frame.Expression=surface(frame)
        frame.Expression.EditBox=surface(frame.Expression)
        frame.Expression.EditBox.Instructions=surface(frame.Expression.EditBox)
        frame.Expression.ValidationIcon={Clear=function(self) self.error=nil end,
            Error=function(self,error) self.error=error end,OK=function(self) return self.error==nil end}
    end
    return frame
end
function CreateTabGroup() return {AddFrame=noop,OnTabPressed=noop} end
InputScrollFrame_OnLoad=noop;InputScrollFrame_OnTextChanged=noop;InputScrollFrame_OnEscapePressed=noop
HironCraftScanConfigPage={Options=surface(),TitleContainer={TitleText=surface()}}
local events={}
local Scan={Config={},DB={settings={['tag.autocomplete_enabled']=false}},Utils={},
    LOCAL={GetText=function(_,key) return key end,Exists=function() return false end},
    Dialog={Element={Text=1,EditBox=2}},Events={
        Register=function(_,event,fn) events[event]=fn end,
        Emit=function(_,event,...) if events[event] then events[event](...) end end}}
function Scan.Utils.saved(parent,key,value) if parent[key]==nil then parent[key]=value end;return parent[key] end
Scan.Utils.onLoad=function(fn) fn() end
Scan.Config.SubstituteTags=function(text) return text end
Scan.Config.ContainsSubstitutionTags=function() return false end
Scan.Config.PopulateSubstitutionTagTooltip=function(_,reporter) reporter:Clear() end
local dialog
Scan.Dialog.Show=function(value) dialog=value end
for _,file in ipairs({'Utils/FStrings.lua','Customer/QuickReplies.lua','Customer/ClassMatching.lua',
    'Config/BasicTemplates.lua','Config/QuickRepliesPanel.lua','Config/EquipmentAliasesPanel.lua'}) do
    assert(loadfile(file))('HironCraft',Scan)
end
local function click(frame) frame.scripts.OnClick(frame) end
local function edit(field,text)
    local box=field.Expression.EditBox
    box:SetText(text);box.scripts.OnEditFocusLost(box)
end
local replies=Scan.Config.LoadQuickReplyConfigOptions(nil,false)
assert(replies.definitionCount==7)
local function findRow(key)
    for _,row in ipairs(replies.Rows) do if row:IsShown() and row.definition.key==key then return row end end
end
for _,row in ipairs(replies.Rows) do assert(row.Rename:IsShown() and row.Delete:IsShown()) end
-- The reason of a decline is a reply like the others here: keywords and a text.
assert(findRow('DECLINE_REASON') and not findRow('DECLINE_REASON').definition.eventOnly
    and findRow('DECLINE_REASON').Keywords:IsShown(), 'the decline reason has no settings row with keywords')
local price=findRow('PRICE')
price.Enabled.Act:SetChecked(false);click(price.Enabled.Act)
replies:RefreshRows()
assert(price.Enabled.Act:GetChecked()==false,'refresh re-enabled a disabled built-in checkbox')
edit(price.Keywords,'cost, fee');edit(price.Response,'500g')
price.Priority:SetText('12');price.Priority.scripts.OnEditFocusLost(price.Priority)
click(price.Rename)
assert(dialog.key=='rename_quick_reply' and dialog.elements[2].initial_text==Scan.QuickReplies:GetTemplateLabel('PRICE'))
assert(not dialog.elements[2].Validator(1,'Commission'))
dialog.OnAccept('Commission')
assert(findRow('PRICE').Enabled.Title.text=='Commission')
price.Repeat:SetText('45');price.Repeat.scripts.OnEditFocusLost(price.Repeat)
local template=Scan.QuickReplies:GetConfig().templates.PRICE
assert(template.keywords=='cost, fee' and template.response=='500g' and template.priority==12 and template.enabled==false)
assert(template.repeat_seconds==45,'the repeat delay was not saved')
price.Repeat:SetText('99999');price.Repeat.scripts.OnEditFocusLost(price.Repeat)
assert(template.repeat_seconds==86400 and price.Repeat.text=='86400','the repeat delay was not clamped')
price.Repeat:SetText('');price.Repeat.scripts.OnEditFocusLost(price.Repeat)
assert(template.repeat_seconds==0,'an empty repeat delay did not turn the delay off')
assert(template.active_orders_only==false,'the open-order switch had no starting value')
price.ActiveOnly.Act:SetChecked(true);click(price.ActiveOnly.Act)
assert(template.active_orders_only==true,'the open-order switch was not saved')
price.ActiveOnly.Act:SetChecked(false);click(price.ActiveOnly.Act)
assert(template.active_orders_only==false,'the open-order switch could not be turned off')
click(findRow('PRICE').Delete)
assert(replies.definitionCount==6 and not findRow('PRICE'))
-- The completed-order reply is a normal built-in row: editable and switchable.
local done=findRow('COMPLETED_ORDER')
assert(done and done.Keywords and not done.Keywords:IsShown(),'completed-order reply asked for keywords')
assert(done.Repeat:IsShown(),'an event reply had no repeat delay of its own')
assert(done.ActiveOnly:IsShown(),'the completed-order reply had no crafter switch')
done.ActiveOnly.Act:SetChecked(true);click(done.ActiveOnly.Act)
assert(Scan.QuickReplies:GetConfig().templates.COMPLETED_ORDER.from_crafter==true,
    'the crafter switch was not saved')
done.ActiveOnly.Act:SetChecked(false);click(done.ActiveOnly.Act)
assert(Scan.QuickReplies:GetConfig().templates.COMPLETED_ORDER.from_crafter==false,
    'the crafter switch could not be turned off')
local declined=findRow('REJECTED_ORDER')
assert(declined and not declined.ActiveOnly:IsShown(),'a decline asked to wait for an order')
edit(done.Response,'Your order is ready!')
done.Enabled.Act:SetChecked(false);click(done.Enabled.Act)
local completed=Scan.QuickReplies:GetConfig().templates.COMPLETED_ORDER
assert(completed.response=='Your order is ready!' and completed.enabled==false,
    'completed-order reply could not be edited or switched off')
done.Enabled.Act:SetChecked(true);click(done.Enabled.Act)
-- Pooled rows must replace their delete/rename callbacks after reordering.
click(findRow('ORDER').Delete)
assert(replies.definitionCount==5 and not findRow('ORDER') and findRow('QUALITY'))
click(findRow('REJECTED_ORDER').Rename);dialog.OnAccept('Resend materials')
edit(findRow('REJECTED_ORDER').Response,'Please resend: {reagent_issues}')
assert(Scan.QuickReplies:GetConfig().templates.REJECTED_ORDER.response=='Please resend: {reagent_issues}')
replies:Init(true)
assert(replies.width==350 and replies.Description.height==76)
for _,row in ipairs(replies.Rows) do if row:IsShown() then
    assert(row.Rename.width+row.Rename.points[1][2]<=row.Delete.points[1][2])
    assert(row.Delete.width+row.Delete.points[1][2]<=300)
    assert(row.Response.height-row.Response.points[1][3]<=276)
    assert(row.Repeat.points[1][2]+row.Repeat.width<=300)
end end
click(findRow('REJECTED_ORDER').Delete)
assert(not findRow('REJECTED_ORDER') and findRow('NAME').Keywords:IsShown())
replies:Init(false)
assert(replies.Description.height==34 and findRow('NAME').Response.width==298)
local aliases=Scan.Config.LoadEquipmentAliasesConfigOptions(nil,false)
assert(#aliases.Rows==26)
local function aliasRow(key) for _,row in ipairs(aliases.Rows) do if row.key==key then return row end end end
local wrist,hand=aliasRow('INVTYPE_WRIST'),aliasRow('INVTYPE_HAND')
local original=Scan.ClassMatching.GetSynonyms('INVTYPE_HAND')
edit(hand,original..', mitts')
assert(Scan.ClassMatching.GetSynonyms('INVTYPE_HAND'):find('mitts',1,true))
edit(wrist,'mitts')
assert(wrist.Expression.ValidationIcon.error and Scan.ClassMatching.GetSynonyms('INVTYPE_WRIST')~='mitts')
edit(hand,'');assert(Scan.ClassMatching.GetSynonyms('INVTYPE_HAND')=='')
click(hand.Reset);assert(Scan.ClassMatching.GetSynonyms('INVTYPE_HAND')==original)
aliases.Enabled.Act:SetChecked(false);click(aliases.Enabled.Act)
assert(Scan.DB.settings.match_customer_class==false)
aliases:Init(true)
assert(aliases.width==350 and aliases.Content.width==300 and aliases.Description.height==90)
for _,row in ipairs(aliases.Rows) do assert(row.width==300 and row.Reset:IsShown()) end
aliases:Init(false)
assert(aliases.Description.height==54 and aliases.Rows[1].width==700)
print('Reply/settings UI passed (real save/validation callbacks, rename/delete, pooled rows, compact/full layouts, alias reset).')

-- Global greetings use the same real save callback as the other editors.
Scan.CONST={TEXT=setmetatable({}, {__index=function(_,key) return key end})}
Scan.Utils.Contains=function(list,value)
    for _,entry in ipairs(list) do if entry==value then return true end end
    return false
end
Scan.Config.AppendSubstitutionTagTooltip=noop
local greetingShares=0
HironCraftScanComm={ShareCustomGreeting=function() greetingShares=greetingShares+1 end}
assert(loadfile('Config/GeneralConfigPanel.lua'))('HironCraft',Scan)
local greetingPanel=setmetatable({Title=surface(),GetParent=function()
    return {TabGroup=CreateTabGroup}
end},{__index=HironCraftScanGreetingConfigPanelMixin})
local greetingKeys={'GREETING_I_CAN_CRAFT_ITEM','GREETING_I_HAVE_PROF',
    'GREETING_ALT_CAN_CRAFT_ITEM','GREETING_ALT_HAS_PROF','GREETING_ALT_SUFFIX','GREETING_BUSY'}
local function greetingField(key)
    local field=CreateFrame('Frame',nil,nil,'HironCraftScanTextInputTemplate')
    field.Expression.ValidationIcon.Warning=function(self,callback)
        self.error=nil;self.warning=callback
    end
    greetingPanel[key]=field
end
for _,key in ipairs(greetingKeys) do greetingField(key) end
greetingField('GREETING_GENERIC_REQUEST')
greetingPanel:Init()
for _,key in ipairs(greetingKeys) do
    local text='I have {profession_link}. You choose price.'
    edit(greetingPanel[key],text)
    assert(not greetingPanel[key].Expression.ValidationIcon.error,
        key..' rejected the profession link')
    assert(Scan.DB.settings.greeting[key]==text, key..' did not save the profession link')
    edit(greetingPanel[key],'{profession}: {profession_link}')
    assert(Scan.DB.settings.greeting[key]=='{profession}: {profession_link}')
    edit(greetingPanel[key],'{profession_link_typo}')
    assert(greetingPanel[key].Expression.ValidationIcon.error
        and Scan.DB.settings.greeting[key]=='{profession}: {profession_link}',
        'an invalid tag overwrote the saved greeting')
end
assert(greetingShares==#greetingKeys*2,'valid greetings were not shared exactly once')
edit(greetingPanel.GREETING_GENERIC_REQUEST,'I have {profession_link}.')
assert(greetingPanel.GREETING_GENERIC_REQUEST.Expression.ValidationIcon.error,
    'generic request accepted a tag without profession context')
edit(greetingPanel.GREETING_GENERIC_REQUEST,'Hello, what do you need?')
assert(Scan.DB.settings.greeting.GREETING_GENERIC_REQUEST=='Hello, what do you need?')
print('Greeting editor passed (profession links, actual save/share callbacks, invalid and generic tags).')
