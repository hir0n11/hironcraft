local function noop() end
local buttons, registered, reset = {}, false, 0
local buttonRows, sliders, previews, queued = {}, {}, {}, {}
local hidePreview, stoppedPreview
local layout={AddInitializer=noop}
local function Initializer(setting) return {data={setting=setting}, AddSearchTags=noop} end
local proxies = {}
local settings={}
local function Setting(category,variable,key,db,kind,name,default)
    local result={SetValueChangedCallback=function(self,fn) self.callback=fn end}
    if variable then
        assert(not settings[variable],'duplicate setting registration: '..variable)
        settings[variable]={category=category,key=key,kind=kind,name=name,default=default,setting=result}
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
    CreateSlider=function(_,setting,options)
        sliders[setting]={options=options}
        return Initializer(setting)
    end,
    CreateControlInitializer=function(_,setting) return Initializer(setting) end,
    CreateSliderOptions=function(min,max,step)
        return {min=min,max=max,step=step,formatters={},SetLabelFormatter=function(self,label,fn)
            self.formatters[label]=fn
        end}
    end,
    OpenToCategory=function(id) assert(id==42 or id==43) end,
}
SettingsPanel={GetLayout=function() return layout end,HookScript=function(_,event,fn)
    assert(event=='OnHide');hidePreview=fn
end}
MinimalSliderWithSteppersMixin={Label={Right=1}}
CreateSettingsButtonInitializer=function(name,text,click,tooltip,addSearchTags)
    -- Match Blizzard's actual assertion (older mocks accepted a missing arg).
    assert(addSearchTags~=nil, 'Blizzard_SettingControls: addSearchTags is required')
    buttons[text]={name=name,click=click}; return Initializer()
end
local originalButton=CreateSettingsButtonInitializer
CreateSettingsButtonInitializer=function(name,text,click,...)
    buttonRows[name]={text=text,click=click}
    return originalButton(name,text,click,...)
end
local Scan
Scan={DB={settings={}}, CONST={TEXT={},DEFAULT_SETTINGS={}},
    LOCAL={GetText=function(_,text) return text end},Utils={onLoad=function(fn) fn() end},
    Notifications={GetOptions=noop,
        StopPreview=function() stoppedPreview=true end,
        QueuePreview=function(sound,volume) queued[#queued+1]={sound=sound,volume=volume} end,
        Play=function(sound,preview,volume) previews[#previews+1]={sound=sound,preview=preview,volume=volume} end,
        Volume=function(kind)
            local value=Scan.DB.settings[kind..'_volume']
            if value==nil then value=Scan.CONST.DEFAULT_SETTINGS[kind..'_volume'] end
            return value
        end},PersonalOrdersIndicator={Reset=function() reset=reset+1 end}}
assert(loadfile('Consts.lua'))('HironCraft',Scan)
assert(Scan.CONST.DEFAULT_SETTINGS.quick_reply_sound_enabled==false)
assert(Scan.CONST.DEFAULT_SETTINGS.reminder_volume==50)
assert(loadfile('Settings/Settings.lua'))('HironCraft',Scan)
assert(registered and buttons['Reset position'] and buttons.Open, 'settings initialization stopped halfway')
assert(hidePreview,'settings close has no preview cleanup')
hidePreview();assert(stoppedPreview,'closing settings did not stop previews')
buttons['Reset position'].click(); assert(reset==1)
Scan.Settings:Open()
Scan.Settings:OpenAlerts();SlashCmdList.HIRONCRAFTSOUNDS()
for _,kind in ipairs({'scanner','whisper','order','quick_reply','reminder'}) do
    local value=settings['HIRONCRAFT_SCAN_'..kind:upper()..'_VOLUME']
    local expected=kind=='reminder' and 50 or 100
    assert(value and value.kind=='number' and value.default==expected and value.category:GetID()==43)
    local options=sliders[value.setting].options
    local format=options.formatters[MinimalSliderWithSteppersMixin.Label.Right]
    assert(format and format(0)=='0%' and format(50)=='50%' and format(100)=='100%',
        kind..' slider has no visible percentage')
    local before=#queued
    value.setting.callback(value.setting,expected)
    assert(#queued==before,'settings initialization/rebuild queued a preview')
    value.setting.callback(value.setting,30)
    value.setting.callback(value.setting,30)
    assert(#queued==before+1 and queued[#queued].volume==30,
        'slider used the stale DB volume or previewed duplicate callbacks')
    local soundKey=({scanner='ping_sound',whisper='whisper_alert_sound',order='personal_order_sound',
        quick_reply='quick_reply_sound',reminder='customer_reminder_sound'})[kind]
    assert(queued[#queued].sound==Scan.CONST.DEFAULT_SETTINGS[soundKey],
        'slider preview lost its default sound before settings saved it')
    local listen=buttonRows[value.name]
    assert(listen and listen.text=='Listen')
    Scan.DB.settings[kind..'_volume']=40
    listen.click()
    assert(previews[#previews].sound==Scan.CONST.DEFAULT_SETTINGS[soundKey]
        and previews[#previews].preview and previews[#previews].volume==40,
        'Listen button ignored the current volume or default sound')
    Scan.DB.settings[soundKey]='none'
    listen.click();assert(previews[#previews].sound=='none','explicit no-sound selection was replaced')
    Scan.DB.settings[soundKey]=nil
    Scan.DB.settings[kind..'_volume']=nil
end
for _,key in ipairs({'customer_reminder_delay','customer_reminder_interval'}) do
    local setting=settings['HIRONCRAFT_SCAN_'..key:upper()].setting
    local format=sliders[setting].options.formatters[MinimalSliderWithSteppersMixin.Label.Right]
    assert(format and format(60)=='60 sec.' and format(120)=='120 sec.',
        'reminder timing slider has no value/unit')
end
local iconSetting=settings.HIRONCRAFT_SCAN_ORDER_ICON_SCALE.setting
assert(sliders[iconSetting].options.formatters[MinimalSliderWithSteppersMixin.Label.Right](0.6)=='60%')
local quick=proxies.HIRONCRAFT_SCAN_QUICK_REPLY_SOUND_ENABLED
assert(quick and quick.default==false and quick.get()==false,'quick reply sound enabled by default')
assert(Scan.DB.settings.quick_reply_sound_enabled==nil,'reading defaults persisted a new sound preference')
quick.set(true);assert(quick.get()==true,'explicit quick reply sound opt-in was ignored')
quick.set(false);assert(quick.get()==false,'explicit quick reply sound opt-out was ignored')
Scan.DB.settings.quick_reply_sound_enabled=nil
assert(quick.get()==false,'clearing the override did not restore the silent default')
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
