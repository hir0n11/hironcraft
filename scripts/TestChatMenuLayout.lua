-- Real menu builder, with native description/initializer semantics at the boundary.
local noop=function() end
local menus,configure,actions={},{},{}
local screen={width=800,height=600}
UIParent={GetWidth=function() return screen.width end,GetHeight=function() return screen.height end}
local secret={}
function issecretvalue(value) return value==secret end
function IsShiftKeyDown() return false end
Menu={ModifyMenu=function(name,callback) menus[name]=callback end}
MenuUtil={GetElementText=function(description) return description.text end}
function GameTooltip_AddNormalLine(tooltip,text) tooltip[#tooltip+1]=text end
HironCraftScanCraftingOrderPage={ShowGeneric=noop}

local Node={}
Node.__index=Node
local function New(text,kind)
    return setmetatable({text=text,kind=kind or 'button',children={},initializers={}},Node)
end
function Node:CreateButton(text,callback,data)
    local child=New(text)
    child.click=callback and function() return callback(data) end
    self.children[#self.children+1]=child
    return child
end
function Node:CreateTitle(text)
    local child=self:CreateButton(text);child.kind='title';return child
end
function Node:CreateDivider()
    local child=self:CreateButton(nil);child.kind='divider';return child
end
function Node:CreateRadio(text,selected,callback,data)
    local child=self:CreateButton(text,callback,data)
    child.selected=function() return selected(data) end
    return child
end
function Node:EnumerateElementDescriptions() return ipairs(self.children) end
function Node:SetTooltip(callback) self.tooltip=callback end
function Node:SetScrollMode(height) self.scrollHeight=height end
function Node:SetMaximumWidth(width) self.maxWidth=width end
function Node:AddInitializer(callback) self.initializers[#self.initializers+1]=callback end
local function Find(root,text)
    for _,child in ipairs(root.children) do
        if child.text==text then return child end
        local found=Find(child,text)
        if found then return found end
    end
end
local function Need(root,text) return assert(Find(root,text),'Missing '..text) end
local function Record(kind,value,target) actions[#actions+1]={kind=kind,value=value,target=target} end

local crafters,deliveries,declines={},{},{}
local longLabel='|cff00ff00'..string.rep('Длинная подпись ',20)..'|r'
local longMessage='Original full reply with {crafter} and an item link, not a clipped label.'
local Scan={
    DB={settings={fit_to_screen=false,collapse_chat_context=false,explanations={[longLabel]=longMessage,rev=2}},
        characters={},customers={},listed_orders={}},
    Utils={onLoad=noop,FitsScreen=function() error('Menu depends on main-window fitting') end},
    CONST={TEXT=setmetatable({MANUAL_MATCH='Match %s %s'},{__index=function(_,key) return key end})},
    LOCAL={GetText=function(_,text) return text end},
    Config={SubstituteTags=function(text) return text end},
    GetSortedCrafters=function() return crafters end,
    ColorizeCrafterName=function(name) return name end,MakeTextWhite=function(text) return text end,
    OrderToOrderID=function(order) return order.customerName..'-'..order.responseID end,
    BuildResponseContext=function(response) return {crafter=response.crafterFullName,profession='Profession'} end,
    OnMessage=function(_,message,target,_,options) Record('match',options,target) end,
    BattleNet={ContextCustomer=function(context) return context.bnetIDAccount==30 and 'BNET:30' or nil end},
    Scanner={RecentDeliveries=function() return deliveries end,DeliveryLabel=function(value) return value.label end,
        RequestRecraft=function(value,options,callback) Record('recraft',value,options);callback(nil) end},
    QuickReplies={DeclinesForMenu=function() return declines end,BuildDeclineReason=function(_,value) return value.reason end,
        DeclineLabel=function(_,value) return value.label end,SendDeclineReason=function(_,value) Record('decline',value) end},
    CustomerPreferences={IsMuted=function() return false end,SetMuted=function(target,value) Record('mute',value,target) end},
    ChatIgnore={IsIgnored=function() return false end,Add=function(target,value) Record('ignore',value,target) end},
    CustomerAttention={Snooze=function(order) Record('snooze',order) end,
        SetState=function(order,state) Record('state',order,state) end},
    Generous={MarkOf=noop,Describe=noop,IsProblem=function() return false end,ProblemIcon=function() return '!' end,
        SetManual=function(target,value) Record('mark',value,target) end,SetProblem=noop},
    ChatTextCapture={ShowForLine=function(line,snapshot) Record('capture',line,snapshot) end},
    ChatFilter={LineText=function(line) assert(line==44);return 'Original chat text' end},
}
Scan.Utils.ProfessionNameByID=function(id) return 'Profession '..id end
Scan.Utils.ColorizeProfessionName=function(_,text) return text end
Scan.Utils.GetReplyItemLink=function(_,link) return link end
Scan.Utils.saved=function(t,k,value) if t[k]==nil then t[k]=value end;return t[k] end
for i=1,8 do
    local name='Crafter'..i
    crafters[#crafters+1]={name=name,parentProfessionID=i}
    Scan.DB.characters[name]={parent_professions={[i]={scanning_enabled=true}}}
end
crafters[#crafters+1]={name='Deleted',parentProfessionID=1}
crafters[#crafters+1]={name='Disabled',parentProfessionID=1}
Scan.DB.characters.Disabled={parent_professions={[1]={scanning_enabled=true,character_disabled=true}}}
for i=1,39 do Scan.DB.settings.explanations[string.format('Reply %02d',i)]='Message '..i end
for i=1,3 do deliveries[i]={label='|cff00ff00|Hitem:'..i..'|h['..string.rep('Recraft item ',20)..']|h|r'} end
declines={{label='Missing mats',reason='Full reason'},{label='Unavailable',reason='Full second reason'},
    {label='No valid reason'}}
for _,target in ipairs({'Customer-Realm','BNET:30'}) do
    local info={responses={}}
    Scan.DB.customers[target]=info
    for i=1,2 do
        local response={crafterFullName='Crafter'..i,professionID=i,responseID=i,requestToken='request'..i,
            time=i,itemID=i,itemLink='Item '..i}
        info.responses[i]=response
        local order={customerName=target,responseID=i}
        Scan.DB.listed_orders[Scan.OrderToOrderID(order)]=order
    end
end
assert(loadfile('Customer/CustomExplanations.lua'))('HironCraft',Scan)
Scan.CustomExplanations.Send=function(_,text,target) Record('reply',text,target) end
Scan.CustomExplanations.SendAssignments=function(_,target) Record('assignments',nil,target) end
HironCraftScan_CustomExplanationsButtonMixin.Init({SetupMenu=function(_,callback) configure=callback end})

local function Open(name,context,count)
    local root=New(nil,'root')
    for i=1,count or 12 do
        local native=root:CreateButton('Native '..i,function() Record('native',i) end)
        native:SetTooltip(noop)
        native:AddInitializer(noop)
    end
    menus[name or 'MENU_UNIT_FRIEND'](nil,root,context or {chatTarget='Customer-Realm',lineID='44'})
    return root
end
local function AssertOwnedLayout(node)
    assert(node.scrollHeight==math.floor(math.min(screen.height*0.6,screen.height-32)))
    assert(node.maxWidth==math.floor(math.min(420,screen.width*0.75,screen.width-48)))
    for _,child in ipairs(node.children) do AssertOwnedLayout(child) end
end
local root=Open()
assert(#actions==0,'Opening the menu performed an action')
assert(root.scrollHeight==360 and #root.children==13,'Small screen did not group addon actions')
assert(not Scan.DB.settings.collapse_chat_context,'Adaptive grouping changed saved settings')
for i=1,12 do
    local native=root.children[i]
    assert(native.maxWidth==nil and native.scrollHeight==nil and #native.initializers==1 and native.tooltip==noop,
        'Native description was modified')
end
AssertOwnedLayout(Need(root,'HironCraftScan'))
assert(not Find(root,'Match Deleted Profession 1') and not Find(root,'Match Disabled Profession 1'))
local reply=Need(root,longLabel)
local tooltip={}
local font={GetUnboundedStringWidth=function() return 3000 end,SetWidth=function(self,value) self.width=value end,
    SetWordWrap=function(self,value) self.wrap=value end,SetMaxLines=function(self,value) self.lines=value end,
    SetFont=function() error('Changed normal font size') end}
local width,height=reply.initializers[1]({fontString=font})
assert(width==372 and height==20 and font.width==336 and font.wrap==false and font.lines==1)
reply.tooltip(tooltip,reply)
assert(tooltip[1]==longMessage and tooltip[2]==longLabel,'Full label replaced the original tooltip')
assert(reply.text==longLabel,'Clipping modified description data')
reply.click()
assert(actions[#actions].value==longMessage and actions[#actions].target=='Customer-Realm')
Need(root,'Match Crafter1 Profession 1').click()
assert(actions[#actions].kind=='match' and actions[#actions].target=='Customer-Realm'
    and actions[#actions].value.forceCrafterInfo.crafter=='Crafter1')
Need(root,'Recraft: '..deliveries[1].label).click()
assert(actions[#actions].value==deliveries[1],'Recraft payload was truncated')
Need(root,'Decline reason: Missing mats').click()
assert(actions[#actions].value==declines[1])
Need(root,'Save chat text').click()
assert(actions[#actions].value==44 and actions[#actions].target=='Original chat text')
Need(root,'To who send').click()
assert(actions[#actions].target=='Customer-Realm')
Need(Need(root,'Active order'),'Item 2 - Crafter2').click()
assert(Scan.CustomExplanations:GetSelectedResponse('Customer-Realm')==Scan.DB.customers['Customer-Realm'].responses[2])
Need(Need(root,'Ignore everywhere'),'Ignore for 1 day').click()
assert(actions[#actions].target=='Customer-Realm' and actions[#actions].value.seconds==86400)
Need(Need(Need(root,'Customer order state'),'Item 1 - Crafter1'),'Order sent').click()
assert(actions[#actions].value.responseID==1 and actions[#actions].value.customerName=='Customer-Realm'
    and actions[#actions].target=='sent')
root.children[1].click()
assert(actions[#actions].kind=='native','Native responder changed')

-- Native scrolling covers every submenu, including settings, not just top level.
local settingsRoot=New(nil,'root')
configure(nil,settingsRoot)
assert(settingsRoot.scrollHeight==360 and #settingsRoot.children==41)
for _,child in ipairs(settingsRoot.children) do AssertOwnedLayout(child) end
local settingsTip={}
Need(settingsRoot,longLabel).tooltip(settingsTip)
assert(settingsTip[1]==longMessage)

-- Re-evaluate logical screen bounds on reopening, without changing preferences.
screen.width,screen.height=400,360
local narrow=Open()
assert(narrow.scrollHeight==216)
AssertOwnedLayout(Need(narrow,'HironCraftScan'))
screen.width,screen.height=1600,3000
local tall=Open()
assert(not Find(tall,'HironCraftScan'),'Tall menu stayed automatically collapsed')
assert(Need(tall,'HironCraftScan - Custom Explanations').kind=='title','Tall menu unnecessarily folded')
Scan.DB.settings.collapse_chat_context=true
assert(Find(Open(),'HironCraftScan'),'Explicit grouping preference ignored')
Scan.DB.settings.collapse_chat_context=false

-- A long recraft history alone must participate in overflow detection.
Scan.DB.settings.explanations={rev=3}
screen.height=1000
for i=4,50 do deliveries[i]={label='Recraft '..i} end
local recrafts=Open()
assert(Need(recrafts,'HironCraftScan - MANUAL_MATCHING_TITLE').kind=='button')
assert(not Find(recrafts,'HironCraftScan - Custom Explanations'),'Revision marker made an empty section')

-- Unknown/secret targets remain non-actionable; BN actions keep canonical recipient.
local empty=Open('MENU_UNIT_FRIEND',{chatTarget=secret})
assert(#empty.children==12 and not empty.scrollHeight)
empty=Open('MENU_UNIT_BN_FRIEND',{bnetIDAccount=999})
assert(#empty.children==12 and not empty.scrollHeight)
Scan.DB.settings.explanations={Price='Choose the price'}
local bn=Open('MENU_UNIT_BN_FRIEND',{bnetIDAccount=30,chatTarget='Wrong recipient'})
Need(bn,'Price').click()
assert(actions[#actions].target=='BNET:30')
assert(not Find(bn,'HironCraftScan - Mark as generous customer'),'BN character-only action leaked')
screen.width,screen.height=nil,0
assert(Open().scrollHeight==460,'Invalid UI dimensions did not use safe fallback')
print('Adaptive menus: native entries, fitting-off, resize, scrolling, clipping, tooltips and callbacks passed')
