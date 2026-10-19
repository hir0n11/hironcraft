local now, held, visible = 0, false, true
local timers, frames, plays, stopped, active = {}, {}, {}, {}, {}
local cv={Sound_EnableAllSound='1',Sound_EnableSoundWhenGameIsInBG='1',Sound_MasterVolume='0.15'}
GetTime=function() return now end
GetCVar=function(key) return cv[key] end
SetCVar=function(key,value) cv[key]=value end
IsMouseButtonDown=function(button) assert(button=='LeftButton');return held end
SettingsPanel={IsShown=function() return visible end}
C_Timer={After=function(delay,fn) timers[#timers+1]={at=now+delay,fn=fn} end}
local function Advance(target)
    for iteration=1,10000 do
        local nextIndex,nextAt
        for i,timer in ipairs(timers) do
            if timer.at<=target and (not nextAt or timer.at<nextAt) then nextIndex,nextAt=i,timer.at end
        end
        if not nextIndex then now=target;return end
        local timer=table.remove(timers,nextIndex)
        now=timer.at;timer.fn()
    end
    error('preview timers did not settle')
end
CreateFrame=function()
    local frame={RegisterEvent=function() end,SetScript=function(self,_,fn) self.event=fn end}
    frames[#frames+1]=frame;return frame
end
SOUNDKIT={TELL_MESSAGE=1,ALARM_CLOCK_WARNING_3=2}
local legacyCalls=0
local function Kit(id,channel,duplicates,finish,priority,volume)
    assert(channel=='Master' and duplicates==false and finish==false and priority==nil)
    local handle=#plays+1
    plays[handle]={id=id,volume=volume};active[handle]=true
    return true,handle
end
C_Sound={PlaySound=Kit}
PlaySound=function(...) legacyCalls=legacyCalls+1;return Kit(...) end
PlaySoundFile=function(file,channel)
    assert(channel=='Master')
    local handle=#plays+1
    plays[handle]={file=file};active[handle]=true
    return true,handle
end
StopSound=function(handle)
    assert(type(handle)=='number' and plays[handle],'invalid preview sound handle')
    stopped[#stopped+1]=handle;active[handle]=nil
end
local Scan={DB={settings={alert_sound_when_muted=false}},LOCAL={GetText=function(_,s) return s end}}
assert(loadfile('Consts.lua'))('HironCraft',Scan)
assert(loadfile('Media/AlertSounds.lua'))('HironCraft',Scan)
assert(loadfile('Customer/Notifications.lua'))('HironCraft',Scan)
local N=Scan.Notifications
local bundled='Interface\\AddOns\\HironCraft\\Media\\WhisperAlert.ogg'
local _,first=N.Play('kit:TELL_MESSAGE',true,100)
assert(first==1 and active[first] and legacyCalls==0,'current sound API/handle was not used')
held=true
N.QueuePreview('kit:TELL_MESSAGE',30)
assert(stopped[#stopped]==first and not active[first],'dragging did not stop the old preview')
Advance(0.05);N.QueuePreview('kit:TELL_MESSAGE',60)
Advance(0.1);N.QueuePreview('kit:TELL_MESSAGE',20)
Advance(0.8)
assert(#plays==1,'holding/dragging the slider started overlapping samples')
held=false;Advance(1)
assert(#plays==2 and plays[2].volume==0.2 and active[2],'release did not play exactly the latest volume')
N.QueuePreview('kit:TELL_MESSAGE',0);Advance(2)
assert(#plays==2 and not active[2],'zero volume failed to stop/silence the preview')
local _,filePreview=N.Play(bundled,true,100)
local _,nextPreview=N.Play(bundled,true,30)
assert(not active[filePreview] and active[nextPreview]
    and plays[nextPreview].file=='Interface\\AddOns\\HironCraft\\Media\\AlertVolume\\30\\WhisperAlert.ogg',
    'Listen/file previews stacked or ignored volume')
N.QueuePreview(bundled,50);Advance(3)
assert(plays[#plays].file=='Interface\\AddOns\\HironCraft\\Media\\AlertVolume\\50\\WhisperAlert.ogg')
N.QueuePreview(bundled,10)
local _,clicked=N.Play('kit:TELL_MESSAGE',true,40)
Advance(4)
assert(#plays==clicked and active[clicked],'Listen did not cancel a queued slider sample')
local _,alert=N.Play('kit:TELL_MESSAGE',false,80)
assert(not active[clicked] and active[alert],'actual alert did not replace the preview')
local _,sample=N.Play('kit:TELL_MESSAGE',true,20)
assert(active[alert] and active[sample],'preview stopped an actual alert')
N.QueuePreview(bundled,60)
assert(not active[sample] and active[alert])
assert(N.Alert('reminder'))
local actual=#plays
Advance(5)
assert(#plays==actual and active[alert] and active[actual],
    'pending preview ran after a real notification or stopped another alert')
N.QueuePreview(bundled,80);visible=false;Advance(6)
assert(#plays==actual,'preview ran after the settings panel closed')
visible=true
N.QueuePreview(bundled,80);frames[1].event(nil,'PLAYER_LOGOUT');Advance(7)
assert(#plays==actual,'preview ran after logout')
local _,sampleBeforeSilence=N.Play(bundled,true,70)
N.Play('none',true,100)
assert(not active[sampleBeforeSilence],'selecting No sound left a preview playing')
C_Sound=nil
local _,fallback=N.Play('kit:UNKNOWN_KIT',true,50)
assert(legacyCalls==1 and plays[fallback].id==SOUNDKIT.TELL_MESSAGE and plays[fallback].volume==0.5,
    'legacy sound fallback lost the volume/handle')
PlaySound=function() return false end
assert(not N.Play('kit:TELL_MESSAGE',true,30))
N.StopPreview()
assert(active[alert] and active[actual] and cv.Sound_MasterVolume=='0.15',
    'preview failure/cleanup interfered with real notifications or master volume')
print('Notification preview checks passed (drag/release coalescing, latest kit/file volume, handle replacement, zero/none, Listen cancellation, real-alert priority, panel close/logout and API fallback).')
