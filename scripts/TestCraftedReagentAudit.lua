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
        slotIndex=1,dataSlotIndex=1,reagents={{itemID=11},{itemID=12},{itemID=13}}}}} end,
    GetItemReagentQualityByItemInfo=function(id) return id==11 and 1 or (id==12 and 2 or 3) end,
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
local function start(id,isRecraft)
    now=now+10
    local row={customerName='Buyer'..id..'-Realm',responseID=123}
    Scan.DB.customers[row.customerName]={responses={[123]={recipeID=123,itemID=321,parentProfID=164,
        requestToken='request-'..id,time=now,crafterFullName='Smith-Realm'}}}
    Scan.DB.listed_orders[Scan.OrderToOrderID(row)]=row
    claimed={orderID=id,spellID=123,itemID=321,customerName=row.customerName,isRecraft=isRecraft==true,
        minQuality=5,reagents={{itemID=11,quantity=20,slotIndex=1,source=1},
            {itemID=12,quantity=20,slotIndex=1,source=1},
            {itemID=13,quantity=999,slotIndex=1,source=2}}}
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
local row=start(7001,false)
assert(not Scan.ReagentAudit.GetForOrder(row),'claim exposed a rejection tooltip')
hooks.CraftRecipe(123,1,nil,nil,7001)
complete(7001,4)
local A,F=Scan.ReagentAudit,Scan.OrderFulfillment
local status=F:GetStatus(row)
assert(status.status=='fulfilled','below-T5 craft became rejected')
local snapshot=assert(A.GetForOrder(row),'T4 completion did not expose reagent audit')
assert(snapshot.craftedQuality==4 and snapshot.maxCraftedQuality==5 and snapshot.craftAttempt==1)
local total,missing,replace=A.Analyze(snapshot.rows[1])
assert(total==40 and missing==0 and #replace==2,
    'full mixed-quality customer materials were mistaken for missing/correct materials')
assert(replace[1].quantity==20 and replace[1].quality==1 and replace[1].maxQuality==3)
assert(replace[2].quantity==20 and replace[2].quality==2 and replace[2].maxQuality==3)
assert(A.Issues(snapshot)==
    'Could you replace 20 T1 Alloy with T3 and 20 T2 Alloy with T3, please?',
    'completed T4 diagnosis did not name exact customer quantities and tiers')
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
local tooltipText=table.concat(lines,'\n')
assert(tooltipText:find('Alloy 40 / 40',1,true),'full quantity was displayed as missing')
assert(tooltipText:find('Replace: 20x Alloy T1 -> T3',1,true))
assert(tooltipText:find('Replace: 20x Alloy T2 -> T3',1,true))

-- SavedVariables survive reload both mid-order and after fulfillment.
loadModules();A,F=Scan.ReagentAudit,Scan.OrderFulfillment
assert(A.GetForOrder(row).rows[1].supplied[1].quantity==20)
local reloadRow=start(7002);hooks.CraftRecipe(123,1,nil,nil,7002)
claimed.reagents={};loadModules();A,F=Scan.ReagentAudit,Scan.OrderFulfillment
complete(7002,3)
assert(A.GetForOrder(reloadRow).craftedQuality==3 and A.GetForOrder(reloadRow).rows[1].supplied[1].quantity==20)

-- Every fulfilled order exposes its actual customer inputs, regardless of rank.
local perfect=start(7003);hooks.CraftRecipe(123,1,nil,nil,7003);complete(7003,5)
assert(F:GetStatus(perfect).status=='fulfilled' and A.GetForOrder(perfect).craftedQuality==5)
assert(#select(3,A.Analyze(A.GetForOrder(perfect).rows[1]))==2,
    'T5 output hid the two lower-tier customer materials')
maxQuality=3
local lowCap=start(7004);hooks.CraftRecipe(123,1,nil,nil,7004);complete(7004,2)
assert(A.GetForOrder(lowCap).maxCraftedQuality==3)
maxQuality=5
local unknown=start(7005);hooks.CraftRecipe(123,1,nil,nil,7005);complete(7005,nil)
assert(A.GetForOrder(unknown).completed and not A.GetForOrder(unknown).craftedQuality)
lines={}
A.ShowTooltip({},'Unknown',{GetLeft=function() return 600 end,GetRight=function() return 850 end},A.GetForOrder(unknown))
assert(lines[1]=='Customer reagents for completed order','uncached quality mislabeled completion as decline')
local allGood=start(7010)
claimed.reagents={{itemID=13,quantity=40,slotIndex=1,source=1}}
hooks.CraftRecipe(123,1,nil,nil,7010);complete(7010,5)
local goodAudit=assert(A.GetForOrder(allGood))
assert(A.MaterialsOK(goodAudit) and #select(3,A.Analyze(goodAudit.rows[1]))==0)
lines={}
A.ShowTooltip({},'Good',{GetLeft=function() return 600 end,GetRight=function() return 850 end},goodAudit)
assert(not table.concat(lines,'\n'):find('Replace:',1,true) and not table.concat(lines,'\n'):find('Missing:',1,true))
maxQuality=0
local unranked=start(7011);hooks.CraftRecipe(123,1,nil,nil,7011);complete(7011,nil)
assert(A.GetForOrder(unranked).completed and not A.GetForOrder(unranked).maxCraftedQuality)
maxQuality=5
local unknownSnapshot=A.Sanitize(F:GetStatus(unknown).reagentAudit)
unknownSnapshot.craftedQuality=4
F:SetStatus(unknown,'fulfilled',{craftingOrderID=7005,reagentAudit=unknownSnapshot})
assert(A.GetForOrder(unknown).craftedQuality==4,'late actual-quality enrichment was discarded')

-- Item quality can be uncached at the craft response. A bounded retry must
-- enrich the already fulfilled row and journal once the exact output resolves.
local delayed=start(7009);hooks.CraftRecipe(123,1,nil,nil,7009)
complete(7009,nil)
assert(A.GetForOrder(delayed).completed and not A.GetForOrder(delayed).craftedQuality)
qualities['output:7009']=3
local pending=timers;timers={}
for _,callback in ipairs(pending) do callback() end
local delayedAudit=assert(A.GetForOrder(delayed),'late output quality was never retried')
assert(delayedAudit.craftedQuality==3 and F:GetStatus(delayed).status=='fulfilled')
local delayedNotice
for _,candidate in pairs(F:GetCompletionNotices()) do
    if candidate.orderID==7009 then delayedNotice=candidate end
end
assert(delayedNotice and delayedNotice.reagentAudit.craftedQuality==3,
    'late actual quality did not enrich the completion journal')

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
local recraft=start(7006,true);hooks.RecraftRecipeForOrder(7006)
claimed.isFulfillable=true;claimed.outputItemHyperlink='pass-one';qualities['pass-one']=4
claimed.reagents={};event('CRAFTINGORDERS_CRAFT_ORDER_RESPONSE',0,7006)
hooks.RecraftRecipeForOrder(7006)
complete(7006,5)
assert(A.GetForOrder(recraft).craftedQuality==5,'previous recraft pass T4 survived a final T5')
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
