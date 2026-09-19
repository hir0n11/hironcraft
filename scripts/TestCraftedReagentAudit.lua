-- Real capture, crafting hooks, completion journal and linked-account merges.
-- Only WoW APIs/transports are mocked; this test never sends game chat.
local now,claimed=2000000000,nil
local events,hooks,timers={},{},{}
local Scan={DB={settings={my_uuid='local'},realm={},customers={},listed_orders={}},
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
function date() return '19.09 12:00' end
function issecretvalue() return false end
function hooksecurefunc(_,name,callback) hooks[name]=callback end
function SendChatMessage() error('audit must never send chat') end
C_Timer={After=function(_,callback) timers[#timers+1]=callback end}
HironCraftScanScannerMenu={RegisterEventCallback=function(_,event,callback) events[event]=callback end}
local maxQuality=5
local qualities={}
C_CraftingOrders={GetClaimedOrder=function() return claimed end,FulfillOrder=function() end}
C_TradeSkillUI={CraftRecipe=function() end,RecraftRecipeForOrder=function() end,
    GetRecipeSchematic=function() return {reagentSlotSchematics={{required=true,quantityRequired=40,
        slotIndex=1,dataSlotIndex=1,reagents={{itemID=11},{itemID=12}}}}} end,
    GetItemReagentQualityByItemInfo=function(id) return id==11 and 1 or 2 end,
    GetQualitiesForRecipe=function()
        local result={};for i=1,maxQuality do result[i]=i end;return result
    end,
    GetItemCraftedQualityByItemInfo=function(link) return qualities[link] end,
    GetBaseProfessionInfo=function() return {parentProfessionID=164} end}
C_Item={GetItemNameByID=function() return 'Alloy' end,
    IsItemDataCachedByID=function() return true end}
Enum={CraftingOrderReagentSource={Customer=1,Crafter=2,None=3},CraftingReagentType={Basic=1}}
local function loadModules()
    assert(loadfile('Customer/ReagentAudit.lua'))('HironCraft',Scan)
    assert(loadfile('Customer/OrderFulfillment.lua'))('HironCraft',Scan)
end
loadModules()
local function event(name,...) assert(events[name],name)(nil,...) end
local function start(id)
    now=now+10
    local row={customerName='Buyer'..id..'-Realm',responseID=123}
    Scan.DB.customers[row.customerName]={responses={[123]={recipeID=123,itemID=321,parentProfID=164,
        requestToken='request-'..id,time=now,crafterFullName='Smith-Realm'}}}
    Scan.DB.listed_orders[Scan.OrderToOrderID(row)]=row
    claimed={orderID=id,spellID=123,itemID=321,customerName=row.customerName,isRecraft=true,
        minQuality=5,reagents={{itemID=11,quantity=20,slotIndex=1,source=1},
            {itemID=12,quantity=20,slotIndex=1,source=2}}}
    event('CRAFTINGORDERS_CLAIMED_ORDER_ADDED',id)
    assert(Scan.OrderFulfillment:GetStatus(row).status=='claimed')
    return row
end
local function complete(id,quality)
    claimed.isFulfillable=true;claimed.outputItemHyperlink='output:'..id
    qualities[claimed.outputItemHyperlink]=quality
    claimed.reagents={} -- Inputs have now been consumed by the game.
    event('CRAFTINGORDERS_CRAFT_ORDER_RESPONSE',0,id)
    hooks.FulfillOrder(id)
    claimed=nil
    event('CRAFTINGORDERS_FULFILL_ORDER_RESPONSE',0,id)
end
local row=start(7001)
assert(not Scan.ReagentAudit.GetForOrder(row),'claim exposed a rejection tooltip')
hooks.RecraftRecipeForOrder(7001)
complete(7001,4)
local A,F=Scan.ReagentAudit,Scan.OrderFulfillment
local status=F:GetStatus(row)
assert(status.status=='fulfilled','below-T5 craft became rejected')
local snapshot=assert(A.GetForOrder(row),'T4 completion did not expose reagent audit')
assert(snapshot.craftedQuality==4 and snapshot.maxCraftedQuality==5 and snapshot.craftAttempt==1)
local total,missing,replace=A.Analyze(snapshot.rows[1])
assert(total==20 and missing==20 and #replace==1,'post-craft consumption or crafter materials polluted snapshot')
assert(snapshot.reason==nil,'successful craft inherited a decline reason')
local noticeKey=F:CompletionNoticeKey({orderID=7001,customerName=row.customerName,origin='local',spellID=123,itemID=321})
local notice=assert(F:GetCompletionNotices()[noticeKey],'completion journal absent')
assert(notice.reagentAudit.craftedQuality==4 and notice.status=='fulfilled')

-- The tooltip clearly labels the actual result, not the requested/projected T5.
local lines={}
UIParent={GetWidth=function() return 1200 end}
function CreateFrame()
    return setmetatable({GetWidth=function() return 300 end,
        AddLine=function(_,text) lines[#lines+1]=text end,
        AddDoubleLine=function(_,text,value) lines[#lines+1]=text..' '..value end},
        {__index=function() return function() end end})
end
A.ShowTooltip({},'Test',{GetLeft=function() return 600 end,GetRight=function() return 850 end},snapshot)
assert(lines[1]=='Customer reagents for completed order')
assert(table.concat(lines,'\n'):find('Crafted quality: T4 / T5',1,true))

-- SavedVariables survive reload both mid-order and after fulfillment.
loadModules();A,F=Scan.ReagentAudit,Scan.OrderFulfillment
assert(A.GetForOrder(row).rows[1].supplied[1].quantity==20)
local reloadRow=start(7002);hooks.CraftRecipe(123,1,nil,nil,7002)
claimed.reagents={};loadModules();A,F=Scan.ReagentAudit,Scan.OrderFulfillment
complete(7002,3)
assert(A.GetForOrder(reloadRow).craftedQuality==3 and A.GetForOrder(reloadRow).rows[1].supplied[1].quantity==20)

-- T5, max-T3 recipes and missing actual quality never create false warnings.
local perfect=start(7003);hooks.CraftRecipe(123,1,nil,nil,7003);complete(7003,5)
assert(F:GetStatus(perfect).status=='fulfilled' and not A.GetForOrder(perfect))
maxQuality=3
local lowCap=start(7004);hooks.CraftRecipe(123,1,nil,nil,7004);complete(7004,2)
assert(not A.GetForOrder(lowCap),'a max-T3 recipe was presented as a failed T5')
maxQuality=5
local unknown=start(7005);hooks.CraftRecipe(123,1,nil,nil,7005);complete(7005,nil)
assert(not A.GetForOrder(unknown),'requested T5/minQuality was mistaken for a real craft result')
local unknownSnapshot=A.Sanitize(F:GetStatus(unknown).reagentAudit)
unknownSnapshot.craftedQuality=4
F:SetStatus(unknown,'fulfilled',{craftingOrderID=7005,reagentAudit=unknownSnapshot})
assert(A.GetForOrder(unknown).craftedQuality==4,'late actual-quality enrichment was discarded')

-- Equivalent linked packets can add missing evidence; legacy peers cannot erase it.
local function copy(value)
    if type(value)~='table' then return value end
    local out={};for k,v in pairs(value) do out[k]=copy(v) end;return out
end
local linked=copy(F:GetStatus(row))
Scan.DB.realm.order_statuses[Scan.OrderToOrderID(row)].reagentAudit=nil
assert(F:ApplyRemoteStatus(linked))
assert(A.GetForOrder(row).craftedQuality==4)
linked.rev=linked.rev+1;linked.reagentAudit=nil
assert(F:ApplyRemoteStatus(linked))
assert(A.GetForOrder(row).rows[1].supplied[1].quantity==20)
local remoteNotice=copy(notice)
local saved=F:GetCompletionNotices()[noticeKey]
saved.reagentAudit=nil
Scan.DB.realm.order_statuses[Scan.OrderToOrderID(row)].reagentAudit=nil
assert(F:ApplyRemoteCompletion(remoteNotice),'same-time fulfilled notice did not enrich audit')
assert(A.GetForOrder(row).craftedQuality==4)
remoteNotice.updatedAt=remoteNotice.updatedAt+1;remoteNotice.reagentAudit=nil
assert(F:ApplyRemoteCompletion(remoteNotice))
assert(A.GetForOrder(row),'legacy journal update erased fulfilled audit')

-- Successive passes through the same recraft must use the final pass's rank.
local recraft=start(7006);hooks.RecraftRecipeForOrder(7006)
claimed.isFulfillable=true;claimed.outputItemHyperlink='pass-one';qualities['pass-one']=4
claimed.reagents={};event('CRAFTINGORDERS_CRAFT_ORDER_RESPONSE',0,7006)
hooks.RecraftRecipeForOrder(7006)
complete(7006,5)
assert(not A.GetForOrder(recraft),'previous recraft pass T4 survived a final T5')
assert(F:GetStatus(recraft).reagentAudit.craftAttempt==2)
local before=A.Sanitize(snapshot);local after=A.Sanitize(snapshot)
before.craftAttempt=1;after.craftAttempt=2;after.craftedQuality=nil
assert(A.Merge(after,before).craftedQuality==nil,'new attempt inherited an old quality')
assert(A.Merge(before,after).craftAttempt==2 and not A.HasMoreDetails(before,after))

-- A late response for A while B is claimed cannot write B's data into A.
local other=start(7007)
event('CRAFTINGORDERS_FULFILL_ORDER_RESPONSE',0,7001)
assert(F:GetStatus(other).status=='claimed' and A.GetForOrder(row).orderID==7001)

-- First observation after materials were consumed: unknown, never missing 40.
local late={orderID=7008,spellID=123,isFulfillable=true,reagents={},outputItemHyperlink='late'}
qualities.late=4
local lateAudit=A.CaptureProgress(late)
assert(lateAudit.craftedQuality==4 and not lateAudit.complete)
assert(select(2,A.Analyze(lateAudit.rows[1]))==nil,'uncaptured materials became a false shortage')
assert(not A.QualityProblem(snapshot),'low craft quality alone became a proven recraft bug')
local invalid=A.Sanitize(snapshot);invalid.craftedQuality=0
assert(A.Sanitize(invalid).craftedQuality==nil)

-- Bounded account-wide progress cache, no stale entries after long absences.
local cache=Scan.DB.settings.order_reagent_snapshots
for id=1,510 do cache['extra-'..id]={capturedAt=now-id} end
cache.stale={capturedAt=now-31*86400};cache.invalid='invalid'
A.PruneProgress()
local count=0;for _ in pairs(cache) do count=count+1 end
assert(count==500 and not cache.stale and not cache.invalid)
print('Crafted reagent audit tests passed (real hooks, consumption, T1-T4/T5, reload, recraft, linked merge, identity, tooltip, cache bounds).')
