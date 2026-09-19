-- Customer-only snapshots, mixed material ranks, recraft uncertainty and UI.
local Scan={DB={listed_orders={}},LOCAL={GetText=function(_,key) return key end}}
local names={[101]='Alloy',[102]='Alloy',[103]='Alloy',[201]='Thread',
    [301]='Spark',[302]='Spark shard',[401]='Missive A',[402]='Missive A',[403]='Missive B'}
local ranks={[101]=1,[102]=2,[103]=3,[401]=1,[402]=2,[403]=3}
local schematic
function time() return 123456 end
function date() return '19.09 12:00' end
C_Item={GetItemNameByID=function(id) return names[id] end,
    IsItemDataCachedByID=function(id) return names[id]~=nil end}
C_TradeSkillUI={GetRecipeSchematic=function(_,recraft) return schematic end,
    GetItemReagentQualityByItemInfo=function(id) return ranks[id] end}
Enum={CraftingOrderReagentSource={Customer=1,Crafter=2,None=3},CraftingReagentType={Basic=1,Modifying=2,Finishing=3}}
assert(loadfile('Customer/ReagentAudit.lua'))('HironCraft',Scan)
local A=Scan.ReagentAudit
local function slot(ids,required,index,optional)
    local s={reagents={},quantityRequired=required,dataSlotIndex=index,slotIndex=index,required=not optional}
    for _,id in ipairs(ids) do s.reagents[#s.reagents+1]={itemID=id} end
    return s
end
local function reagent(id,quantity,index,source)
    return {source=source or 1,slotIndex=index,reagentInfo={reagent={itemID=id},quantity=quantity,dataSlotIndex=index}}
end
schematic={reagentSlotSchematics={slot({101,102,103},40,1),slot({201},2,2),slot({401,402,403},1,3,true)}}
local order={orderID=7001,spellID=123,isRecraft=true,reagents={reagent(101,20,1),reagent(102,15,1),
    reagent(103,5,1,2),reagent(201,2,2),reagent(401,1,3)}}
local audit=A.Capture(order)
assert(audit.complete and #audit.rows==3)
local total,missing,replace=A.Analyze(audit.rows[1])
assert(total==35 and missing==5 and #replace==2,'crafter inventory or ranks polluted customer counts')
assert(audit.rows[3].supplied[1].maxQuality==2,'unrelated optional reagent raised the maximum tier')
local issues=A.Issues(audit)
assert(issues:find('Missing: 5x Alloy',1,true) and issues:find('Replace: 20x Alloy T1 -> T3',1,true))
order.reagents[1].reagentInfo.quantity=999
assert(audit.rows[1].supplied[1].quantity==20,'snapshot retained mutable API tables')
assert(not A.MaterialsOK(audit))
order.reagents={reagent(103,40,1),reagent(201,2,2),reagent(402,1,3)}
local details={reason='insufficient_quality',quality={currentQuality=4,requestedQuality=5,skill=488,nextQualitySkill=620,maxAllowed=40}}
local good=A.Capture(order,details)
assert(A.MaterialsOK(good) and A.QualityProblem(good):find('Possible recraft',1,true))
assert(not A.Issues(good):find('Replace:',1,true),'normal max materials received a replace instruction')
assert(A.Issues(good):find('current skill/settings',1,true),'quality failure was declared a proven game bug')
good.isRecraft=false
assert(not A.Issues(good):find('recraft',1,true),'ordinary skill shortfall called a recraft bug')
good.quality.currentQuality=5
assert(not A.QualityProblem(good))
order.reagents=nil
local unavailable=A.Capture(order,details)
assert(not unavailable.complete and not A.MaterialsOK(unavailable) and not A.Issues(unavailable):find('Missing:',1,true))
order.reagents={reagent(103,nil,1)}
local partial=A.Capture(order)
assert(not partial.complete and select(2,A.Analyze(partial.rows[1]))==nil,'unknown quantity treated as zero')
order.reagents={reagent(103,40,1),reagent(201,2,2)}
local oldRank=ranks[102];ranks[102]=nil
assert(not A.MaterialsOK(A.Capture(order)),'uncached maximum rank treated as known')
ranks[102]=oldRank
schematic={reagentSlotSchematics={slot({301,302},2,1)}}
schematic.reagentSlotSchematics[1].variableQuantities={{reagent={itemID=301},quantity=2},{reagent={itemID=302},quantity=6}}
order.reagents={reagent(302,4,1)}
assert(select(2,A.Analyze(A.Capture(order).rows[1]))==2,'spark alternative quantity ignored')
order.reagents={reagent(301,1,1),reagent(302,3,1)}
assert(not A.Capture(order).complete and select(2,A.Analyze(A.Capture(order).rows[1]))==nil)
schematic={reagentSlotSchematics={slot({101,102,103},5,1),slot({101,102,103},5,2)}}
order.reagents={{itemID=101,quantity=5}}
local ambiguous=A.Capture(order)
assert(not ambiguous.complete and not A.Issues(ambiguous):find('Missing:',1,true),'ambiguous slot falsely accused customer')
order.reagents={reagent(101,5,2)}
local indexed=A.Capture(order)
assert(indexed.rows[1].supplied[1]==nil and indexed.rows[2].supplied[1].quantity==5)
schematic={reagentSlotSchematics={{reagents={{currencyID=7}},quantityRequired=1,required=true}}}
order.reagents={}
assert(not A.Capture(order).complete and not A.Issues(A.Capture(order)):find('Missing:',1,true))
local clean=A.Sanitize(audit)
clean.rows[1].name='|Hitem:1|h[Injected]|h\n{crafter}'
clean.rows[1].supplied[1].quantity=-1
clean=A.Sanitize(clean)
assert(not clean.rows[1].name:find('[{}|]') and clean.rows[1].supplied[1].quantity==nil)
assert(not A.Sanitize({version=1,orderID=7001,rows={}}),'undated payload accepted')
local status={status='rejected',craftingOrderID=7001,reagentAudit=audit}
Scan.OrderFulfillment={Status={Rejected='rejected'},GetStatus=function() return status end}
local response={};Scan.OrderToResponse=function() return response end
Scan.DB.listed_orders.a={}
assert(A.ForResponse(response)==audit)
status.craftingOrderID=7002
assert(not A.ForResponse(response),'audit leaked to resent game order')
status.craftingOrderID=7001;status.status='fulfilled'
assert(not A.ForResponse(response),'fulfilled row retains rejection tooltip')

local owner,lines={},{}
UIParent={GetWidth=function() return 1200 end}
local left,right=600,850
local history={GetLeft=function() return left end,GetRight=function() return right end}
function CreateFrame()
    return setmetatable({GetWidth=function() return 300 end,
        AddLine=function(_,text) lines[#lines+1]=text end,AddDoubleLine=function(_,text) lines[#lines+1]=text end,
        SetPoint=function(self,point,_,relative) self.anchor=relative end,
        Show=function(self) self.visible=true end,Hide=function(self) self.visible=false end},
        {__index=function() return function() end end})
end
A.ShowTooltip(owner,'Test',history,audit)
assert(owner.reagentTooltip.anchor=='TOPLEFT' and owner.reagentTooltip.visible)
left,right=100,350;A.ShowTooltip(owner,'Test',history,audit)
assert(owner.reagentTooltip.anchor=='TOPRIGHT')
A.ShowTooltip(owner,'Test',history,nil)
assert(not owner.reagentTooltip.visible)
print('Reagent audit tests passed (customer-only capture, ranks, missing/unknown data, recraft, identity, tooltip).')

-- Custom pastes can explicitly select a declined item among several requests.
Scan.CONST={TEXT={}}
Scan.Utils={};Scan.Config={SubstituteTags=function(text) return text end}
assert(loadfile('Utils/FStrings.lua'))('HironCraft',Scan)
assert(loadfile('Customer/CustomExplanations.lua'))('HironCraft',Scan)
response={responseID=1,requestToken='a',time=1,crafterFullName='Crafter',professionID=164}
local other={responseID=2,requestToken='b',time=2,crafterFullName='Crafter',professionID=164}
Scan.DB.customers={Buyer={responses={[1]=response,[2]=other}}}
Scan.DB.listed_orders={['Buyer-1']={customerName='Buyer',responseID=1},['Buyer-2']={customerName='Buyer',responseID=2}}
Scan.OrderToOrderID=function(o) return o.customerName..'-'..o.responseID end
Scan.OrderToResponse=function(o) return Scan.DB.customers[o.customerName].responses[o.responseID] end
local statuses={[1]={status='rejected',craftingOrderID=7001,reagentAudit=audit},[2]={status='fulfilled'}}
Scan.OrderFulfillment.GetStatus=function(_,o) return statuses[o.responseID] end
Scan.OrderFulfillment.Status.Fulfilled='fulfilled'
Scan.BuildResponseContext=function(r) return {reagent_issues=A.Issues(A.ForResponse(r))} end
Scan.QuickReplies={ResolveResponses=function() return {{response=other}} end}
assert(#Scan.CustomExplanations:GetPendingResponses('Buyer')==0)
assert(#Scan.CustomExplanations:GetPendingResponses('Buyer',true)==1)
local rendered=Scan.CustomExplanations:Render('Order declined: {reagent_issues}','Buyer')
assert(rendered and rendered:find('Missing: 5x Alloy',1,true),'paste chose fulfilled context instead of declined item')
statuses[1].status='fulfilled'
assert(not Scan.CustomExplanations:Render('{reagent_issues}','Buyer'),'paste revived an obsolete rejection')
print('Reagent custom paste context tests passed.')
