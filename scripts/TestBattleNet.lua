-- Real menu and linked-account code, with no network/chat transport available.
local noop=function() end
local Scan={DB={settings={my_uuid='local-account',substitution_tags={support='Ask {crafter}.'},
        explanations={Price='You choose the price.',Crafter='Try {crafter} for {item}.',Support='{support}'}},
    characters={Smith={parent_professions={[164]={scanning_enabled=true}}}},realm={},customers={},
    listed_orders={}},
    Utils={onLoad=noop,Contains=function(values,wanted)
        for _,value in ipairs(values) do if value==wanted then return true end end
    end}, CONST={TEXT=setmetatable({MANUAL_MATCH='Match %s %s'}, {__index=function(_,k) return k end})},
    LOCAL={GetText=function(_,text) return text end},Events={Register=noop},
}
Scan.Utils.saved=function(t,k,v) if t[k]==nil then t[k]=v end;return t[k] end
Scan.Utils.FString=function(text,values)
    return (text:gsub('{(.-)}',function(key) return values[key] or '{'..key..'}' end))
end
Scan.Config={SubstituteTags=function(text) return Scan.Utils.FString(text,Scan.DB.settings.substitution_tags) end}
Scan.Utils.ProfessionNameByID=function() return 'Blacksmithing' end
Scan.Utils.ColorizeProfessionName=function(_,name) return name end
Scan.Utils.SplitResponse=function(text) return {text} end
Scan.Utils.GetReplyItemLink=function(_,link) return link end
Scan.GetSortedCrafters=function() return {{name='Smith',parentProfessionID=164}} end
Scan.ColorizeCrafterName=function(name) return name end
Scan.OrderToOrderID=function(order) return order.customerName..'-'..order.responseID end
local fulfillmentStatuses={}
Scan.OrderFulfillment={
    Status={Crafted='crafted',Fulfilled='fulfilled',Rejected='rejected'},
    GetStatus=function(_,order) return fulfillmentStatuses[Scan.OrderToOrderID(order)] end,
}
local matched, sent={},{}
Scan.OnMessage=function(event,message,customer,guid,options)
    matched[#matched+1]={customer=customer,message=message,options=options}
end
Scan.Utils.SendResponses=function(messages,customer,manual)
    assert(manual==true);sent[#sent+1]={customer=customer,message=messages[1]};return true
end
local friend={isFriend=true,battleTag='Friend#1234',bnetAccountID=30,accountName='Friend'}
function BNGetNumFriends() return 1 end
C_BattleNet={GetAccountInfoByID=function(id) if id==friend.bnetAccountID then return friend end end,
    GetFriendAccountInfo=function() return friend end}
local secret={}
function issecretvalue(value) return value==secret end
C_ChatInfo={GetChatLineText=function(id) assert(id==44);return '[Item request]' end,
    GetChatLineSenderGUID=function() return 'BNet-GUID' end}
assert(loadfile('Customer/BattleNet.lua'))('HironCraft',Scan)
local key=Scan.BattleNet.FromID(30)
local response={crafterName='Favu',crafterFullName='Favu-Kazzak',professionID=164,
    professionName='Blacksmithing',itemID=100,itemLink="Spellbreaker's Rebuke",
    responseID=1,requestToken='first-request',time=100}
Scan.DB.customers[key]={responses={[1]=response}}
Scan.DB.customers['Normal-Realm']={responses={[1]=response}}
Scan.DB.listed_orders[Scan.OrderToOrderID({customerName=key,responseID=1})]=
    {customerName=key,responseID=1}
Scan.DB.listed_orders[Scan.OrderToOrderID({customerName='Normal-Realm',responseID=1})]=
    {customerName='Normal-Realm',responseID=1}
local second, duplicate
Scan.BuildResponseContext=function(value)
    if value==response or value==duplicate then
        return {crafter='Favu',item="Spellbreaker's Rebuke",profession='Blacksmithing',
            profession_link='Blacksmithing',commission='10k'}
    end
    assert(value==second)
    return {crafter='Lavu',item='that',profession='Jewelcrafting',
        profession_link='Jewelcrafting',commission='5k'}
end
Scan.QuickReplies={ResolveResponses=function(_,customer,customerInfo)
    assert(customerInfo==Scan.DB.customers[customer])
    return {{response=customerInfo.responses[1],responseID=1}}
end}
local menus={}
Menu={ModifyMenu=function(name,callback) menus[name]=callback end}
assert(loadfile('Customer/CustomExplanations.lua'))('HironCraft',Scan)
HironCraftScan_CustomExplanationsButtonMixin.Init({SetupMenu=noop})
local function menu(name,context)
    local buttons={}
    local root={CreateDivider=noop,CreateTitle=function() return {SetTooltip=noop} end}
    function root:CreateButton(label,click)
        local button={label=label,click=click,SetTooltip=noop,
            CreateButton=self.CreateButton,CreateRadio=self.CreateRadio,
            CreateDivider=noop,CreateTitle=self.CreateTitle}
        buttons[#buttons+1]=button;return button
    end
    function root:CreateRadio(label,isSelected,setSelected,data)
        local button={label=label,click=function() setSelected(data) end,
            selected=function() return isSelected(data) end,SetTooltip=noop,
            CreateButton=self.CreateButton,CreateRadio=self.CreateRadio,
            CreateDivider=noop,CreateTitle=self.CreateTitle}
        buttons[#buttons+1]=button;return button
    end
    menus[name](nil,root,context)
    return buttons
end
local function find(buttons,label)
    for _,button in ipairs(buttons) do if button.label==label then return button end end
    error('Missing menu action '..label)
end
local buttons=menu('MENU_UNIT_BN_FRIEND',{bnetIDAccount=30,lineID=44,chatTarget='Do not whisper this'})
assert(#sent==0 and #matched==0, 'opening a menu took an action')
find(buttons,'Match Smith Blacksmithing').click()
assert(#matched==1 and matched[1].customer==key and matched[1].options.battleNet==true)
find(buttons,'Price').click()
assert(sent[1].customer==key and sent[1].message=='You choose the price.')
find(buttons,'Crafter').click()
assert(sent[2].customer==key and sent[2].message=="Try Favu for Spellbreaker's Rebuke.",
    'Battle.net explanation did not expand order context')
find(buttons,'Support').click()
assert(sent[3].customer==key and sent[3].message=='Ask Favu.',
    'custom substitution tag did not expand contextual tag')
find(buttons,'HironCraftScan - IGNORE').click()
assert(Scan.DB.settings.ignored[key]==1)
buttons=menu('MENU_UNIT_BN_FRIEND',{accountInfo=friend,lineID=44})
find(buttons,'HironCraftScan - UNIGNORE').click()
assert(not Scan.DB.settings.ignored[key])
buttons=menu('MENU_UNIT_FRIEND',{chatTarget='Normal-Realm',lineID=44})
find(buttons,'Price').click()
assert(sent[4].customer=='Normal-Realm', 'ordinary whisper context changed')
assert(#menu('MENU_UNIT_BN_FRIEND',{bnetIDAccount=999})==0, 'unknown friend has actionable menu')
buttons=menu('MENU_UNIT_BN_FRIEND',{bnetIDAccount=30})
find(buttons,'Match Smith Blacksmithing').click()
assert(#matched==2 and matched[2].message=='' and matched[2].options.manualMatch, 'friend-list click did not create the selected generic greeting')

-- Blizzard's BNPlayer hyperlink handler passes the split account ID as a
-- STRING to FriendsFrame_ShowBNDropdown, and does not forward the chat line ID.
-- UnitPopup adds accountInfo, but retains the original string bnetIDAccount.
local chatContext={name='Friend',chatTarget='Friend',chatType='BN_WHISPER',
    bnetIDAccount='30',accountInfo=friend}
buttons=menu('MENU_UNIT_BN_FRIEND',chatContext)
assert(#sent==4 and #matched==2, 'opening the real chat context took an action')
find(buttons,'Price').click()
assert(#sent==5 and sent[5].customer==key, 'chat hyperlink reply lost its Battle.net recipient')
find(buttons,'Match Smith Blacksmithing').click()
assert(#matched==3 and matched[3].message=='', 'missing line ID prevented explicit generic matching')
Scan.DB.settings.collapse_chat_context=true
buttons=menu('MENU_UNIT_BN_FRIEND',{bnetIDAccount='30',chatTarget='Friend'})
find(buttons,'HironCraftScan')
find(buttons,'Price').click()
assert(#sent==6 and sent[6].customer==key, 'collapsed Battle.net reply menu failed')
Scan.DB.settings.collapse_chat_context=false

-- One explicit button combines every unfinished request. Item requests use the
-- item, while generic requests fall back to the profession. Selecting context
-- only affects subsequent tagged explanations and never sends by itself.
second={crafterName='Lavu',crafterFullName='Lavu-Kazzak',professionID=755,
    parentProfID=755,professionName='Jewelcrafting',responseID=2,
    requestToken='second-request',time=120}
Scan.DB.customers[key].responses[2]=second
Scan.DB.listed_orders[Scan.OrderToOrderID({customerName=key,responseID=2})]=
    {customerName=key,responseID=2}
duplicate={crafterName='Favu',crafterFullName='Favu-Kazzak',professionID=164,
    professionName='Blacksmithing',itemID=100,itemLink="Spellbreaker's Rebuke"}
local pending=Scan.CustomExplanations:GetPendingResponses(key)
local deduplicated=Scan.CustomExplanations:BuildAssignments(key,
    {pending[1],{response=duplicate},pending[2]})
assert(#deduplicated==2, 'duplicate item/crafter assignment was repeated')
buttons=menu('MENU_UNIT_BN_FRIEND',{bnetIDAccount=30,chatTarget='Friend'})
local beforeAssignments=#sent
find(buttons,'HironCraftScan - To who send').click()
assert(#sent==beforeAssignments+1)
assert(sent[#sent].message=="Spellbreaker's Rebuke → Favu; Jewelcrafting → Lavu",
    'unfinished item/profession assignments were not combined')
find(buttons,'HironCraftScan - Active order')
local selected=find(buttons,'Jewelcrafting → Lavu')
assert(not selected.selected(), 'manual order context started selected')
local beforeSelection=#sent
selected.click()
assert(#sent==beforeSelection and selected.selected(), 'choosing context sent chat or was not retained')
find(buttons,'Crafter').click()
assert(sent[#sent].message=='Try Lavu for that.', 'custom tags ignored the manual order context')

fulfillmentStatuses[Scan.OrderToOrderID({customerName=key,responseID=2})]={status='crafted'}
assert(#Scan.CustomExplanations:GetPendingResponses(key)==1, 'crafted order remained available')
assert(Scan.CustomExplanations:Render('Try {crafter}.',key)=='Try Favu.',
    'completed manual context did not fall back to the remaining request')
local remaining=Scan.CustomExplanations:BuildAssignments(key)
assert(#remaining==1 and remaining[1]=="Spellbreaker's Rebuke → Favu",
    'completed order was included in the combined assignment')
fulfillmentStatuses[Scan.OrderToOrderID({customerName=key,responseID=1})]={status='rejected'}
assert(#Scan.CustomExplanations:GetPendingResponses(key)==0)
assert(Scan.CustomExplanations:Render('Try {crafter}.',key)==nil,
    'completed/rejected response was reused as a custom tag context')

assert(Scan.BattleNet.ContextCustomer({accountInfo=friend})==key)
assert(Scan.BattleNet.ContextCustomer({bnetIDAccount=30})==key)
for _,badID in ipairs({'not-an-id','0','-30','30.5','3e1',' 30 ',false,{},secret}) do
    assert(#menu('MENU_UNIT_BN_FRIEND',{bnetIDAccount=badID,accountInfo=friend})==0,
        'invalid/secret explicit ID fell back to another recipient')
end
assert(not Scan.BattleNet.ContextCustomer(nil))
assert(not Scan.BattleNet.ContextCustomer(secret))
assert(not Scan.BattleNet.ContextCustomer({accountInfo=secret}))
assert(not Scan.BattleNet.ContextCustomer({accountInfo='invalid'}))

local comm={}
LibStub=function() return {NewAddon=function() return comm end} end
CreateFramePool=function() return {} end
HironCraftScanScannerMenu={RegisterEventCallback=noop}
assert(loadfile('Utils/Comm.lua'))('HironCraft',Scan)
comm.Transmit=function() error('Private Battle.net data was transmitted') end
Scan.DB.settings.proxy_send_enabled=true
Scan.DB.realm.linked_accounts={peer={permissions={1}}}
Scan.OrderFulfillment={GetStatuses=function() return {private={customerName=key,updatedAt=20},
    normal={customerName='Normal-Realm',updatedAt=10}} end,GetCompletionNotices=function() return {} end}
comm:ShareCustomerOrder('private text',key,nil,{message='private history'})
comm:ShareCustomerChat(key,nil,{message='private history'},true)
comm:ShareOrderStatus({customerName=key})
local status={customerName=key,deliveryPending={peer=true}}
assert(not comm:PrepareOrderStatusDelivery(status) and not status.deliveryPending)
local function findUpvalue(fn,wanted,seen)
    seen=seen or {};if seen[fn] then return end;seen[fn]=true
    for i=1,100 do
        local name,value=debug.getupvalue(fn,i)
        if not name then break end
        if name==wanted then return value end
        if type(value)=='function' then local found=findUpvalue(value,wanted,seen);if found then return found end end
    end
end
local newest=assert(findUpvalue(comm.ShareCharacterData,'NewestOrderEntries'))
local exported=newest(Scan.OrderFulfillment:GetStatuses())
assert(#exported==1 and exported[1].customerName=='Normal-Realm', 'private identity leaked into journal/snapshot')
print('Battle.net menu/sync tests passed (chat hyperlink string IDs, collapsed replies, secret/invalid context, manual matching, explanations, ignore, ordinary chat, private data isolation).')
