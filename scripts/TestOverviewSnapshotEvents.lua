local noop=function() end
local frames,timers={},{}
function CreateFrame()
    local f={events={},scripts={}}
    function f:RegisterEvent(event) self.events[event]=true end
    function f:SetScript(event,fn) self.scripts[event]=fn end
    frames[#frames+1]=f;return f
end
local combat,instance=false,false
function InCombatLockdown() return combat end
function IsInInstance() return instance end
time=os.time;date=os.date
SlashCmdList={}
C_Timer={After=function(_,fn) timers[#timers+1]=fn end,NewTicker=function() return {} end}
HironCraftProfit={}
HironCraftProfit_DB={accountOverview={chars={A={},B={}}}}
assert(loadfile('Workflow/Core/Core/AccountOverview_Data.lua'))()
local PT=HironCraftProfit
local D=PT.AccountOverview_Data
local saves,checks,refreshes=0,0,0
local current,saved=1,nil
function D:SaveCurrentCharacterSnapshot() saves=saves+1;saved=current end
function D:CheckFullConcentration() checks=checks+1 end
PT.AccountOverview={Refresh=function() refreshes=refreshes+1 end}
local owner
for _,f in ipairs(frames) do if f.events.PLAYER_LOGOUT then owner=f end end
assert(owner)
local function Event(event,unit) owner.scripts.OnEvent(owner,event,unit) end
local function Drain()
    local pending=timers;timers={}
    for _,fn in ipairs(pending) do fn() end
end
for i=1,30 do
    Event('PLAYER_EQUIPMENT_CHANGED');Event('UNIT_INVENTORY_CHANGED','player');Event('TRADE_SKILL_SHOW')
end
assert(saves==0 and #timers==1,'Snapshot burst was not deferred/coalesced')
current=2;Drain()
assert(saves==1 and saved==2 and checks==2 and refreshes==1,'Merged snapshot lost the newest state')
Event('UNIT_INVENTORY_CHANGED','target');assert(#timers==0)
Event('PLAYER_EQUIPMENT_CHANGED');current=3;Event('PLAYER_LOGOUT')
assert(saved==3 and saves==2 and refreshes==1,'Logout did not synchronously save the latest state')
Drain();assert(saves==2,'Queued callback saved again after logout')
combat=true;Event('TRADE_SKILL_SHOW');Drain();assert(saves==2,'Combat safety changed')
combat=false;instance=true;Event('TRADE_SKILL_SHOW');Drain();assert(saves==2,'Instance safety changed')
print('Overview snapshots: burst coalescing, latest state, synchronous logout, canceled work and safety guards passed')
