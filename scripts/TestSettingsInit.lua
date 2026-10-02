local function noop() end
local buttons, registered, reset = {}, false, 0
local layout={AddInitializer=noop}
local function Initializer(setting) return {data={setting=setting}, AddSearchTags=noop} end
local function Setting() return {SetValueChangedCallback=noop} end
Settings = {
    VarType={String='string',Boolean='boolean'},Default={True=true,False=false},
    RegisterVerticalLayoutCategory=function() return {GetID=function() return 42 end},layout end,
    RegisterAddOnCategory=function() registered=true end,
    RegisterAddOnSetting=Setting, RegisterProxySetting=Setting,
    CreateCheckbox=function(_,setting) return Initializer(setting) end,
    CreateDropdown=function(_,setting) return Initializer(setting) end,
    CreateSlider=function(_,setting) return Initializer(setting) end,
    CreateControlInitializer=function(_,setting) return Initializer(setting) end,
    CreateSliderOptions=function() return {SetLabelFormatter=noop} end,
    OpenToCategory=function(id) assert(id==42) end,
}
SettingsPanel={GetLayout=function() return layout end}
MinimalSliderWithSteppersMixin={Label={Right=1}}
CreateSettingsButtonInitializer=function(name,text,click,tooltip,addSearchTags)
    -- Match Blizzard's actual assertion (older mocks accepted a missing arg).
    assert(addSearchTags~=nil, 'Blizzard_SettingControls: addSearchTags is required')
    buttons[text]={name=name,click=click}; return Initializer()
end
local Scan={DB={settings={}}, CONST={TEXT={},DEFAULT_SETTINGS={}},
    LOCAL={GetText=function(_,text) return text end},Utils={onLoad=function(fn) fn() end},
    Notifications={GetOptions=noop},PersonalOrdersIndicator={Reset=function() reset=reset+1 end}}
assert(loadfile('Settings/Settings.lua'))('HironCraft',Scan)
assert(registered and buttons['Reset position'] and buttons.Open, 'settings initialization stopped halfway')
buttons['Reset position'].click(); assert(reset==1)
Scan.Settings:Open()
print('Settings initialization passed (required Blizzard button arguments, full category creation, reset action).')
