-- A decline made outside ProfitHub (Blizzard's own button) must still mark the
-- chat row as rejected; ProfitHub's own declines are not recorded twice.
local now = 2000000000
local events, hooks = {}, {}
local Scan = {DB={settings={my_uuid='local'},realm={},customers={},listed_orders={}},
    Utils={},LOCAL={GetText=function(_,key) return key end},Events={Emit=function() end}}
function Scan.Utils.saved(parent,key,value)
    if parent[key]==nil then parent[key]=value end
    return parent[key]
end
function Scan.Utils.onLoad(callback) callback() end
function Scan.GetPlayerName() return 'Smith-Realm' end
function Scan.OrderToOrderID(order) return order.customerName..':'..order.responseID end
function Scan.OrderToResponse(order)
    local customer=Scan.DB.customers[order.customerName]
    return customer and customer.responses[order.responseID]
end
function Scan.OrderToLiveResponse() end
function time() return now end
function issecretvalue() return false end
function hooksecurefunc(_,name,callback) hooks[name]=callback end
local timers={}
C_Timer={After=function(_,callback) timers[#timers+1]=callback end}
HironCraftScanScannerMenu={RegisterEventCallback=function(_,event,callback) events[event]=callback end}
local listed={}
C_CraftingOrders={GetClaimedOrder=function() return nil end,FulfillOrder=function() end,
    RejectOrder=function() end,GetCrafterOrders=function() return listed end}
C_TradeSkillUI={GetRecipeSchematic=function() return {reagentSlotSchematics={{required=true,quantityRequired=4,
        slotIndex=1,dataSlotIndex=1,reagents={{itemID=11}}}}} end,
    GetBaseProfessionInfo=function() return {parentProfessionID=164} end}
C_Item={GetItemNameByID=function() return 'Alloy' end,IsItemDataCachedByID=function() return true end}
Enum={CraftingOrderReagentSource={Customer=1,Crafter=2,None=3},CraftingReagentType={Basic=1}}
assert(loadfile('Customer/ReagentAudit.lua'))('HironCraft',Scan)
assert(loadfile('Customer/OrderFulfillment.lua'))('HironCraft',Scan)
assert(hooks.RejectOrder,'RejectOrder was not hooked')

local function chatRow(id,customer)
    local row={customerName=customer,responseID=id}
    Scan.DB.customers[customer]={responses={[id]={recipeID=123,itemID=321,parentProfID=164,
        requestToken='request-'..id,time=now-60,crafterFullName='Smith-Realm'}}}
    Scan.DB.listed_orders[Scan.OrderToOrderID(row)]=row
    return row
end
local F=Scan.OrderFulfillment

local manual=chatRow(1,'Kiwidk-Realm')
listed[#listed+1]={orderID=900,spellID=123,itemID=321,customerName='Kiwidk-Realm',
    reagents={{itemID=11,quantity=1,slotIndex=1,source=1}}}
C_CraftingOrders.RejectOrder(900,'',164);hooks.RejectOrder(900,'',164)
local status=F:GetStatus(manual)
assert(status and status.status=='rejected','Blizzard decline left the chat row without its cross')
assert(status.reagentAudit and status.reagentAudit.rows[1].supplied[1].quantity==1,
    'manual decline lost the material list')

local profit=chatRow(2,'Other-Realm')
listed[#listed+1]={orderID=901,spellID=123,itemID=321,customerName='Other-Realm',reagents={}}
HironCraftProfitCraftingOrders={rejectedOrderIDs={['901']=now+5}}
hooks.RejectOrder(901,'',164)
assert(not F:GetStatus(profit),'ProfitHub decline was recorded a second time by the hook')

hooks.RejectOrder(999,'',164) -- unknown order: nothing to record, no error

-- Fast clicking declines before the list is captured: the list saved when the
-- order was claimed is used, so the reply never says it was unavailable.
local fast=chatRow(3,'Fast-Realm')
Scan.ReagentAudit.CaptureProgress({orderID=902,spellID=123,
    reagents={{itemID=11,quantity=4,slotIndex=1,source=1}}})
F:RecordRejection({orderID=902,customerName='Fast-Realm',spellID=123,itemID=321},902,'insufficient_quality')
local recovered=F:GetStatus(fast)
assert(recovered and recovered.status=='rejected','fast decline was not recorded')
assert(recovered.reagentAudit and recovered.reagentAudit.rows[1].supplied[1].quantity==4,
    'fast decline lost the list captured when the order was claimed')

-- The list can also arrive after the decline; the retries pick it up.
local later=chatRow(4,'Later-Realm')
timers={}
F:RecordRejection({orderID=903,customerName='Later-Realm',spellID=123,itemID=321},903,'insufficient_quality')
local initial=F:GetStatus(later).reagentAudit
assert(not initial or initial.complete~=true,'a complete list appeared before it was captured')
assert(#timers>0,'no retry was scheduled for the missing list')
Scan.ReagentAudit.CaptureProgress({orderID=903,spellID=123,
    reagents={{itemID=11,quantity=2,slotIndex=1,source=1}}})
for _,callback in ipairs(timers) do callback() end
local late=F:GetStatus(later)
assert(late.reagentAudit and late.reagentAudit.rows[1].supplied[1].quantity==2,
    'a list captured right after the decline never reached the status')
-- A personal order can arrive from someone who never wrote a word. Its result
-- had nowhere to show: no cross, and no reply to offer. Such an order gets a
-- row of its own, owned by the character that received it.
Scan.DB.customers['Silent-Realm']=nil
local silentInfo={orderID=904,customerName='Silent-Realm',spellID=123,itemID=321,
    orderType=2,parentProfessionID=164,
    reagents={{itemID=11,quantity=1,slotIndex=1,source=1}}}
assert(F:RecordRejection(silentInfo,904,'missing_customer_reagents'),
    'an order from a stranger was not recorded at all')
local silentRow=Scan.DB.listed_orders['Silent-Realm:order:904']
    or Scan.DB.listed_orders['Silent-Realm-order:904']
if not silentRow then
    for key,row in pairs(Scan.DB.listed_orders) do
        if row.customerName=='Silent-Realm' then silentRow=row end
    end
end
assert(silentRow,'no row was created for an order from a stranger')
local silentStatus=F:GetStatus(silentRow)
assert(silentStatus and silentStatus.status=='rejected','the new row has no cross')
local silentResponse=Scan.DB.customers['Silent-Realm'].responses[silentRow.responseID]
assert(silentResponse and silentResponse.conversationCharacter=='Smith-Realm',
    'the row belongs to no character, so nothing could answer for it')
assert(silentResponse.greeting_sent,'a greeting was offered for an order nobody asked about')
-- The same order again keeps the one row.
F:RecordRejection(silentInfo,904,'missing_customer_reagents')
local rows=0
for _,row in pairs(Scan.DB.listed_orders) do
    if row.customerName=='Silent-Realm' then rows=rows+1 end
end
assert(rows==1,'a second decline made a second row')
-- A patron order is not a conversation and gets no row.
local patron={orderID=905,customerName='Patron-Realm',npcCustomerName='Patron',spellID=123,
    itemID=321,orderType=4,parentProfessionID=164,reagents={}}
F:RecordRejection(patron,905,'missing_customer_reagents')
for _,row in pairs(Scan.DB.listed_orders) do
    assert(row.customerName~='Patron-Realm','a patron order was given a customer row')
end

-- The linked account that talked to the customer finds its own row only
-- through the notice. A listener that fails while the decline is recorded
-- must not cost that notice.
local mockEvents=Scan.Events
HironCraftScan_DB={settings=Scan.DB.settings}
seterrorhandler=nil
assert(loadfile('Utils/ErrorLog.lua'))('HironCraft',Scan)
assert(loadfile('Utils/EventBus.lua'))('HironCraft',Scan)
local previousHandler=geterrorhandler
geterrorhandler=function() return function() end end
Scan.Events:Register('ORDER_FULFILLMENT_UPDATED',function() error('listener broke') end)
local brokenInfo={orderID=906,customerName='Broken-Realm',spellID=123,itemID=321,
    orderType=2,parentProfessionID=164,reagents={{itemID=11,quantity=1,slotIndex=1,source=1}}}
assert(F:RecordRejection(brokenInfo,906,'missing_customer_reagents'),'the decline was not recorded')
local function noticeFor(orderID)
    for _,notice in pairs(F:GetCompletionNotices()) do
        if tostring(notice.orderID)==tostring(orderID) and notice.status=='rejected' then return notice end
    end
end
assert(noticeFor(906),'a failing listener cost the notice the other account needs')
local logged=Scan.DB.settings.error_log and Scan.DB.settings.error_log[1]
assert(logged and logged.context=='ORDER_FULFILLMENT_UPDATED' and logged.error:find('listener broke'),
    'the error was not kept for later')
Scan.Events=mockEvents
geterrorhandler=previousHandler
-- A notice that was lost anyway is rebuilt from the saved status, with the
-- time of the decline itself.
local lost=noticeFor(906)
local declinedAt=lost.updatedAt
for key,notice in pairs(F:GetCompletionNotices()) do
    if notice==lost then F:GetCompletionNotices()[key]=nil end
end
assert(not noticeFor(906))
now=now+120
assert(F:RepairOrderRowNotices()==1,'the lost notice was not rebuilt')
assert(noticeFor(906) and noticeFor(906).updatedAt==declinedAt,'the rebuilt notice has the wrong time')
assert(F:RepairOrderRowNotices()==0,'a notice was rebuilt twice')

print('Manual decline tests passed (Blizzard button marks the row, ProfitHub declines not duplicated, late material lists recovered, rows for orders nobody asked about).')
