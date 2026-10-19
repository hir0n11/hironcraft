local frames, timers, plays, delays = {}, {}, {}, {}
local now, cv = 10, { Sound_EnableAllSound = '0', Sound_EnableSoundWhenGameIsInBG = '0' }
GetTime = function() return now end
GetCVar = function(key) return cv[key] end
SetCVar = function(key, value) cv[key] = value end
C_Timer = { After = function(delay, fn) timers[#timers + 1] = fn; delays[#delays+1]=delay end }
CreateFrame = function()
    local f = { RegisterEvent = function() end, SetScript = function(self, _, fn) self.event = fn end }
    frames[#frames + 1] = f
    return f
end
SOUNDKIT = { TELL_MESSAGE = 1, AUCTION_WINDOW_CLOSE = 2 }
PlaySound = function(id, channel) plays[#plays + 1] = { id, channel }; return true end
PlaySoundFile = PlaySound
C_AddOns = { IsAddOnLoaded = function() return false end }
local Scan = { DB = { settings = {} }, LOCAL = { GetText = function(_, s) return s end } }
assert(loadfile('Media/AlertSounds.lua'))('HironCraft', Scan)
assert(loadfile('Customer/Notifications.lua'))('HironCraft', Scan)
local N, f = Scan.Notifications, frames[1]
f.event(nil, 'PLAYER_LOGIN')
f.event(nil, 'CHAT_MSG_WHISPER')
assert(#plays == 1 and cv.Sound_EnableAllSound == '1')
N.Alert('scanner')
assert(#plays == 1, 'one whisper plus a scanner row played twice')
now = 11
f.event(nil, 'CHAT_MSG_BN_WHISPER')
assert(#plays == 2)
timers[1]()
assert(cv.Sound_EnableAllSound == '1', 'an old timer muted a newer alert')
timers[2]()
assert(cv.Sound_EnableAllSound == '0' and cv.Sound_EnableSoundWhenGameIsInBG == '0')
now = 14
N.Alert('order')
cv.Sound_EnableAllSound = '0'
f.event(nil, 'CVAR_UPDATE', 'Sound_EnableAllSound')
cv.Sound_EnableAllSound = '1'
timers[3]()
assert(cv.Sound_EnableAllSound == '1', 'user sound choice was overwritten')
Scan.DB.settings.alert_sound_when_muted = false
cv.Sound_EnableAllSound = '0'
N.Play('kit:TELL_MESSAGE', true)
assert(cv.Sound_EnableAllSound == '0')
Scan.DB.settings.whisper_alert_enabled = false
local count = #plays
now = 17
f.event(nil, 'CHAT_MSG_WHISPER')
assert(#plays == count, 'disabled whisper sound still played')
Scan.DB.settings.whisper_alert_enabled = true
C_AddOns.IsAddOnLoaded = function() return true end
f.event(nil, 'PLAYER_LOGIN')
f.event(nil, 'CHAT_MSG_WHISPER')
assert(#plays == count, 'separate WhisperAlert caused a duplicate')
print('Built-in notifications passed (mute leases, overlaps, user changes, deduplication, opt-outs, Battle.net).')

-- WhisperAlert's original sound ships with HironCraft, so disabling/removing
-- the separate addon or LibSharedMedia cannot remove it from any sound picker.
Settings={CreateControlTextContainer=function()
    local rows={}
    return {Add=function(_,value,label) rows[#rows+1]={value=value,label=label} end,
        GetData=function() return rows end}
end}
LibStub=nil
local bundled='Interface\\AddOns\\HironCraft\\Media\\WhisperAlert.ogg'
local options=N.GetOptions()
local found=0
for _,option in ipairs(options) do
    if option.value==bundled then assert(option.label=='WhisperAlert'); found=found+1 end
end
assert(found==1, 'bundled WhisperAlert sound missing or duplicated')
N.Play(bundled,true)
assert(plays[#plays][1]==bundled and plays[#plays][2]=='Master', 'preview used the old addon path')
Scan.DB.settings.whisper_alert_sound=bundled
Scan.DB.settings.ping_sound=bundled
Scan.DB.settings.personal_order_sound=bundled
C_AddOns.IsAddOnLoaded=function() return false end
f.event(nil,'PLAYER_LOGIN')
for _,kind in ipairs({'whisper','scanner','order'}) do
    now=now+2
    local before=#plays
    N.Alert(kind)
    assert(#plays==before+1 and plays[#plays][1]==bundled, kind..' ignored the selected bundled sound')
end
options=N.GetOptions(); found=0
for _,option in ipairs(options) do if option.value==bundled then found=found+1 end end
assert(found==1, 'saved selections duplicate the same sound')
print('WhisperAlert sound passed (bundled path, preview, all three selectors, no external addon/library, no duplicate options).')

assert(#Scan.BundledAlertSounds==107 and #options==113, 'SharedMedia catalogue is incomplete')
local air='Interface\\AddOns\\HironCraft\\Media\\SharedMedia\\Sounds\\AirHorn.ogg'
local oldAir='Interface\\AddOns\\WeakAuras_SharedMedia\\Sounds\\AirHorn.ogg'
Scan.DB.settings.ping_sound=oldAir
Scan.DB.settings.whisper_alert_sound='Interface\\AddOns\\WhisperAlert\\wisp.ogg'
f.event(nil,'PLAYER_LOGIN')
assert(Scan.DB.settings.ping_sound==air and Scan.DB.settings.whisper_alert_sound==bundled,
    'old selections still depend on the removed addon')
LibStub=function()
    return {List=function() return {'Air Horn'} end,Fetch=function() return oldAir end}
end
assert(#N.GetOptions()==113, 'an installed SharedMedia library duplicates bundled entries')
N.Play(oldAir,true); assert(plays[#plays][1]==air)
N.Play('554003',true); assert(plays[#plays][1]==554003, 'a game sound ID became a file path')
Scan.DB.settings.alert_sound_when_muted=true
cv.Sound_EnableAllSound='0'
now=100
N.Play('Interface\\AddOns\\HironCraft\\Media\\SharedMedia\\Sounds\\AcousticGuitar.ogg',true)
local longTimer=#timers
assert(delays[longTimer]>=12 and delays[longTimer]<13, 'long clip was cut off by the old two-second mute timer')
now=101; N.Play('kit:TELL_MESSAGE',true)
assert(delays[#timers]>=11, 'short alert cuts off an overlapping long clip')
timers[longTimer](); assert(cv.Sound_EnableAllSound=='1')
timers[#timers](); assert(cv.Sound_EnableAllSound=='0')
print('SharedMedia sounds passed (complete catalogue, selection migration, deduplication, numeric ID, long/overlapping clip mute restoration).')

-- Independent volume never moves the game's master/SFX/music sliders.
cv.Sound_MasterVolume='0.15'
local previousSound=PlaySound
PlaySound=function(id,channel,duplicates,finish,priority,volume)
    plays[#plays+1]={id,channel,volume=volume};return true
end
for level=10,100,10 do
    assert(N.Play('kit:TELL_MESSAGE',true,level))
    assert(plays[#plays].volume==level/100)
    N.Play(bundled,true,level)
    local expected=level==100 and bundled or ('Interface\\AddOns\\HironCraft\\Media\\AlertVolume\\'..level..'\\WhisperAlert.ogg')
    assert(plays[#plays][1]==expected,'wrong bundled volume path')
end
assert(cv.Sound_MasterVolume=='0.15')
count=#plays
assert(not N.Play(bundled,true,0) and #plays==count,'zero volume was not silent')
Scan.DB.settings.whisper_volume=0
now=now+2;f.event(nil,'CHAT_MSG_WHISPER','hello','Quiet-Realm')
assert(#plays==count,'zero-volume whisper used a different alert path')
Scan.DB.settings.whisper_volume=50
Scan.CustomerPreferences={IsMuted=function(name) return name=='Quiet-Realm' end}
now=now+2;f.event(nil,'CHAT_MSG_WHISPER','hello','Quiet-Realm')
assert(#plays==count,'per-player whisper mute was ignored')
f.event(nil,'CHAT_MSG_WHISPER','hello','Other-Realm')
assert(#plays==count+1)
Scan.IsIgnored=function(name) return name=='Ignored-Realm' end
for _,kind in ipairs({'scanner','whisper','quick_reply'}) do
    now=now+2;local before=#plays
    N.Alert(kind,'Ignored-Realm');assert(#plays==before,'ignored sender played '..kind)
end
local bnID
Scan.BattleNet={FromID=function(id) bnID=id;return 'Quiet-Realm' end}
now=now+2;count=#plays
f.event(nil,'CHAT_MSG_BN_WHISPER','hello','Display name',nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,77)
assert(bnID==77 and #plays==count,'Battle.net sender identity/mute was lost')
Scan.CustomerPreferences=nil
now=now+2
local option={customer='Other-Realm',templateKey='sent',message='sent',reply='Thanks',requestToken='job'}
N.QuickReply(option);count=#plays
now=now+2;N.QuickReply(option)
assert(#plays==count,'rebuilding the same suggestion rang again')
now=now+61;N.QuickReply(option)
assert(#plays==count+1,'a later genuine suggestion stayed muted forever')
for _,kind in ipairs({'scanner','whisper','order','quick_reply','reminder'}) do
    Scan.DB.settings[kind..'_volume']=30
    now=now+2;local before=#plays
    assert(N.Alert(kind) and #plays==before+1,kind..' did not use the common alert route')
end
assert(cv.Sound_MasterVolume=='0.15')
print('New notification checks passed: all five alert types, kit/file volumes, zero volume, per-player/BN mute, full ignore, quick-reply deduplication and untouched master volume.')
