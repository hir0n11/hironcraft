local function noop() end
local buttons, registered, reset = {}, false, 0
local layout={AddInitializer=noop}
local function Initializer(setting) return {data={setting=setting}, AddSearchTags=noop} end
local proxies = {}
local settings={}
local function Setting(category,variable,key,db,kind,name,default)
    local result={SetValueChangedCallback=function(self,fn) self.callback=fn end}
    if variable then
        assert(not settings[variable],'duplicate setting registration: '..variable)
        settings[variable]={category=category,key=key,kind=kind,default=default,setting=result}
    end
    return result
end
local function Proxy(_,variable,_,name,default,get,set)
    proxies[variable]={name=name,default=default,get=get,set=set}; return Setting()
end
Settings = {
    VarType={String='string',Boolean='boolean'},Default={True=true,False=false},
    RegisterVerticalLayoutCategory=function() return {GetID=function() return 42 end},layout end,
    RegisterVerticalLayoutSubcategory=function(parent,name)
        assert(parent:GetID()==42 and name=='Sounds and reminders')
        return {GetID=function() return 43 end},layout
    end,
    RegisterAddOnCategory=function() registered=true end,
    RegisterAddOnSetting=Setting, RegisterProxySetting=Proxy,
    CreateCheckbox=function(_,setting) return Initializer(setting) end,
    CreateDropdown=function(_,setting) return Initializer(setting) end,
    CreateSlider=function(_,setting) return Initializer(setting) end,
    CreateControlInitializer=function(_,setting) return Initializer(setting) end,
    CreateSliderOptions=function() return {SetLabelFormatter=noop} end,
    OpenToCategory=function(id) assert(id==42 or id==43) end,
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
for _,kind in ipairs({'scanner','whisper','order','quick_reply','reminder'}) do Scan.CONST.DEFAULT_SETTINGS[kind..'_volume']=100 end
Scan.CONST.DEFAULT_SETTINGS.customer_reminder_delay=60
Scan.CONST.DEFAULT_SETTINGS.customer_reminder_interval=60
assert(loadfile('Settings/Settings.lua'))('HironCraft',Scan)
assert(registered and buttons['Reset position'] and buttons.Open, 'settings initialization stopped halfway')
buttons['Reset position'].click(); assert(reset==1)
Scan.Settings:Open()
Scan.Settings:OpenAlerts();SlashCmdList.HIRONCRAFTSOUNDS()
for _,kind in ipairs({'scanner','whisper','order','quick_reply','reminder'}) do
    local value=settings['HIRONCRAFT_SCAN_'..kind:upper()..'_VOLUME']
    assert(value and value.kind=='number' and value.default==100 and value.category:GetID()==43)
end
local reminder=proxies.HIRONCRAFT_SCAN_CUSTOMER_REMINDERS_ENABLED
assert(reminder and reminder.get()==false,'reminders enabled on every computer by default')
reminder.set(true);assert(reminder.get()==true)
-- Gathering analytics is switched here (it was a checkbox of the analytics
-- window): on by default, and the window is told when it changes.
local gathering, told = true, 0
Scan.AnalyticsLog={IsEnabled=function() return gathering end, SetEnabled=function(on) gathering=on end}
local gather=proxies.HIRONCRAFT_SCAN_GATHER_ANALYTICS
assert(gather and gather.name=='Collect analytics data' and gather.default==true and gather.get()==true,
    'the settings have no switch for gathering analytics, or it is off by default')
gather.set(false)
assert(gathering==false and gather.get()==false, 'the settings cannot stop gathering')
Scan.AnalyticsWindow={GatheringChanged=function() told=told+1 end}
gather.set(true)
assert(gathering==true and told==1, 'the analytics window is not told about the switch')
print('Settings initialization passed (required Blizzard button arguments, full category creation, reset action, analytics switch).')
