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

-- A held Shift on a row of the order list shows which key sends which quick
-- phrase, in place of the chat history.
do
    local shift = false
    function IsShiftKeyDown() return shift end
    function GetBindingText(key) return (key:gsub('SHIFT%-', 'Shift+')) end
    Scan.NameAndRealmToName = function(name) return name end
    -- The real list of phrases with keys.
    function InCombatLockdown() return false end
    function ClearOverrideBindings() end
    Scan.DB = { settings = {
        explanations = { ['Omw'] = 'On my way!', ['Mats'] = 'Please send  the materials\nwith the order. ' .. string.rep('long ', 60),
            ['No key'] = 'never shown', ['Big ty'] = 'Big ty for your tip <3', ['Reload'] = 'Try {crafter}-Kazzak or relog' },
        explanation_keys = { ['Omw'] = 'SHIFT-2', ['Mats'] = 'SHIFT-1', ['Gone'] = 'SHIFT-3', ['Big ty'] = 'SHIFT-4',
            ['Reload'] = 'SHIFT-5' },
    } }
    local createFrame = CreateFrame
    CreateFrame = function() return { SetScript = noop, RegisterEvent = noop } end
    assert(loadfile('Customer/ExplanationBindings.lua'))('HironCraft', Scan)
    CreateFrame = createFrame
    local list = Scan.ExplanationBindings.List()
    assert(#list == 4 and list[1].key == 'SHIFT-1' and list[1].label == 'Mats' and list[2].key == 'SHIFT-2'
        and list[2].text == 'On my way!' and list[4].key == 'SHIFT-5', 'the phrases with keys are listed wrong')
    -- A phrase is shown as it would go to this customer.
    Scan.CustomExplanations = { Render = function(_, text, customer, forOrder)
        assert(customer == 'Buyer' and forOrder == order, 'the phrase is not rendered for the hovered row')
        return (text:gsub('{crafter}', 'Vamo'))
    end }

    currentAudit = { orderID = 80 }
    response = { greeting_sent = true, requestToken = 'keys' }
    info.chat_history = { { message = 'the history line', syncID = 'k1', chatType = 'WHISPER' } }
    local row = { order = order, hironExplanationRow = true }
    local events = {}
    function tip:RegisterEvent(event) events[event] = true end
    function tip:IsShown() return self.visible end
    local function text() return table.concat(tip.lines, '\n') end

    -- Without Shift: the history, as ever.
    history:Show('TestHistoryTooltip', row, order, 'History')
    assert(text():find('the history line', 1, true) and not text():find('Quick phrase keys', 1, true))
    assert(events.MODIFIER_STATE_CHANGED and tip.scripts.OnEvent, 'the tooltip does not hear Shift')
    assert(history.reagentTooltip.visible)
    -- Shift pressed: the keys at once, by key, each with its phrase cut short.
    shift = true
    tip.scripts.OnEvent(tip, 'MODIFIER_STATE_CHANGED')
    local shown = text()
    assert(shown:find('Quick phrase keys', 1, true) and not shown:find('the history line', 1, true),
        'a held Shift still shows the chat history')
    local first, second = shown:find('Shift+1', 1, true), shown:find('Shift+2', 1, true)
    assert(first and second and first < second and shown:find('Mats', 1, true) and shown:find('On my way!', 1, true),
        'the keys and their phrases are not listed: ' .. shown)
    assert(shown:find('Please send the materials with the order.', 1, true) and shown:find('%.%.%.')
        and not shown:find(string.rep('long ', 40), 1, true), 'a long phrase is not shown as one short line')
    assert(not shown:find('never shown', 1, true) and not shown:find('SHIFT-3', 1, true), 'a phrase without a key, or a key without a phrase, is listed')
    -- Compact: the title and one line a phrase, nothing between them. The
    -- name of a phrase is there only where the phrase does not begin with it,
    -- and tags are filled in for the customer of the row.
    assert(#tip.lines == 5, 'the hints take ' .. #tip.lines .. ' lines for four phrases')
    assert(tip.lines[4]:find('Shift+4', 1, true) and tip.lines[4]:find('Big ty for your tip <3', 1, true)
        and not tip.lines[4]:find('Big ty:', 1, true), 'a phrase that begins with its name repeats the name')
    assert(tip.lines[5]:find('Reload:', 1, true) and tip.lines[5]:find('Try Vamo-Kazzak or relog', 1, true)
        and not shown:find('{crafter}', 1, true), 'a phrase is not shown as it would be sent')
    assert(tip.lines[3]:find('Omw:', 1, true) and tip.lines[3]:find('On my way!', 1, true))
    assert(not history.reagentTooltip.visible, 'the material list stayed next to the key hints')
    -- Shift let go: the history again (also found by the poll alone).
    shift = false
    tip.scripts.OnUpdate(tip, 0.25)
    assert(text():find('the history line', 1, true) and not text():find('Quick phrase keys', 1, true), 'letting Shift go kept the key hints')
    -- No keys yet: it says where to assign them.
    Scan.DB.settings.explanation_keys = {}
    shift = true
    tip.scripts.OnEvent(tip, 'MODIFIER_STATE_CHANGED')
    assert(text():find('Quick phrase keys none', 1, true), 'no hint on how to assign keys')
    -- Elsewhere (the request banner) Shift changes nothing.
    history:Show('TestHistoryTooltip', anchor, order, 'History')
    assert(text():find('the history line', 1, true) and not text():find('Quick phrase keys', 1, true),
        'a tooltip that is not a row of the list shows key hints')
    shift = false
end
print('Quick phrase key hints passed (Shift on a row, order of keys, long phrases, no keys, other tooltips).')
