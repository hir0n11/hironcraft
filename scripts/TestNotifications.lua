local frames, timers, plays = {}, {}, {}
local now, cv = 10, { Sound_EnableAllSound = '0', Sound_EnableSoundWhenGameIsInBG = '0' }
GetTime = function() return now end
GetCVar = function(key) return cv[key] end
SetCVar = function(key, value) cv[key] = value end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
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
