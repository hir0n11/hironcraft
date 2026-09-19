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
C_Timer={After=function() end}
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
print('Manual decline tests passed (Blizzard button marks the row, ProfitHub declines not duplicated).')
