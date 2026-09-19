local noop=function() end
function CreateFrame() return {SetScript=noop,RegisterEvent=noop} end
local Scan={CONST={TEXT={}},LOCAL={GetText=function(_,k) return k end}}
assert(loadfile('Utils/Utils.lua'))('HironCraft',Scan)
assert(loadfile('Customer/ChatHistory.lua'))('HironCraft',Scan)
local info={chat_history={{message='first',syncID='first',chatType='WHISPER'}}}
local response={greeting_sent=true,requestToken='one'}
Scan.OrderToResponse=function() return response end
Scan.OrderToCustomerInfo=function() return info end
ChatTypeInfo={WHISPER={r=1,g=0,b=1}}
ChatFrame1={GetFontObject=noop,GetWidth=function() return 600 end}
function GetBindingKey() end
function GameTooltip_AddBlankLineToTooltip(tip) tip:AddLine('') end
function CreateFrame(_,name)
    local font={SetFontObject=noop,GetFontObject=noop}
    local tip={TextLeft2=font,TextRight1=font,TextRight2=font,lines={},scripts={}}
    function tip:SetScript(event,fn) self.scripts[event]=fn end
    function tip:ClearLines() self.lines={} end
    function tip:AddLine(text) self.lines[#self.lines+1]=text end
    function tip:AddDoubleLine(text) self:AddLine(text) end
    function tip:Hide() self.visible=false end
    function tip:Show() self.visible=true end
    function tip:SetMinimumWidth(width) self.width=width end
    tip.SetOwner=noop;tip.GetNumRegions=function() return 0 end
    _G[name]=tip
    return tip
end
local order={customerName='Buyer',responseID=1}
local anchor={order=order}
local history=Scan.Utils.ChatHistoryTooltip:new()
history:Show('TestHistoryTooltip',anchor,order,'History')
local tip=history.tooltip
assert(tip.visible and tip.lines[#tip.lines]=='first')
info.chat_history[#info.chat_history+1]={message='sent',syncID='second',chatType='WHISPER'}
tip.scripts.OnUpdate(tip,0.25)
assert(tip.lines[#tip.lines]=='sent', 'hovered history did not update')
info.chat_history[#info.chat_history+1]={message='sent',syncID='third',chatType='WHISPER'}
tip.scripts.OnUpdate(tip,0.25)
assert(tip.lines[#tip.lines]=='sent' and tip.lines[#tip.lines-1]=='sent', 'repeated but distinct event was lost')
anchor.order={customerName='Other',responseID=2}
tip.scripts.OnUpdate(tip,0.25)
assert(not tip.visible, 'recycled row retained another customer tooltip')
anchor.order=order;history:Show('TestHistoryTooltip',anchor,order,'History')
response=nil;tip.scripts.OnUpdate(tip,0.25)
assert(not tip.visible, 'dismissed request left a stale tooltip')
local legacy=Scan.Utils.GetUniqueChatHistory({
    {message='hi',chatType='WHISPER',args={[11]=1}},
    {message='sent',chatType='WHISPER',args={[11]=1}},
})
assert(#legacy==2, 'reused legacy formatting ID erased a different reply')
print('Chat history tooltip tests passed (live updates, repeated events, recycled rows, dismissal, legacy identity collisions).')

local currentAudit={orderID=77}
Scan.ReagentAudit={GetForOrder=function() return currentAudit end,
    ShowTooltip=function(owner,_,_,snapshot)
        owner.reagentTooltip=owner.reagentTooltip or {Hide=function(self) self.visible=false end}
        owner.reagentTooltip.visible=snapshot~=nil
        owner.reagentTooltip.snapshot=snapshot
    end}
response={greeting_sent=true,requestToken='new'}
history:Show('TestHistoryTooltip',anchor,order,'History')
assert(history.reagentTooltip.visible)
currentAudit={orderID=78};tip.scripts.OnUpdate(tip,0.25)
assert(history.reagentTooltip.snapshot.orderID==78,'hover kept old rejection snapshot')
currentAudit=nil;tip.scripts.OnUpdate(tip,0.25)
assert(not history.reagentTooltip.visible,'completed order kept material tooltip')
currentAudit={orderID=79};history:Show('TestHistoryTooltip',anchor,order,'History')
tip.scripts.OnHide(tip)
assert(not history.reagentTooltip.visible,'hidden chat history left material tooltip behind')
print('Reagent side tooltip lifecycle tests passed.')
