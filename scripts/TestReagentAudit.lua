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
    reagent(103,5,1,2),reagent(201,1,2),reagent(401,1,3)}}
local audit=A.Capture(order)
assert(audit.complete and #audit.rows==3)
local total,missing,replace=A.Analyze(audit.rows[1])
assert(total==35 and missing==5 and #replace==2,'crafter inventory or ranks polluted customer counts')
assert(audit.rows[3].supplied[1].maxQuality==2,'unrelated optional reagent raised the maximum tier')
local issues=A.Issues(audit)
assert(issues=="Looks like you're missing 5 Alloy (T3) and 1 Thread. "
    ..'Could you replace 20 T1 Alloy with T3, 15 T2 Alloy with T3 and 1 T1 Missive A with T2, please?',
    'multiple shortages, mixed tiers or optional reagent replacement were lost')
order.reagents[1].reagentInfo.quantity=999
assert(audit.rows[1].supplied[1].quantity==20,'snapshot retained mutable API tables')
assert(not A.MaterialsOK(audit))
order.reagents={reagent(103,40,1),reagent(201,2,2),reagent(402,1,3)}
local details={reason='insufficient_quality',quality={currentQuality=4,requestedQuality=5,skill=488,nextQualitySkill=620,maxAllowed=40}}
local good=A.Capture(order,details)
assert(A.MaterialsOK(good) and A.QualityProblem(good):find('might be a recraft',1,true))
assert(not A.Issues(good):find('Could you replace',1,true),'normal max materials received a replace instruction')
assert(A.Issues(good):find('current setup',1,true),'quality failure was declared a proven game bug')
good.isRecraft=false
assert(not A.Issues(good):find('recraft',1,true),'ordinary skill shortfall called a recraft bug')
good.quality.currentQuality=5
assert(not A.QualityProblem(good))
order.reagents=nil
local unavailable=A.Capture(order,details)
assert(not unavailable.complete and not A.MaterialsOK(unavailable) and not A.Issues(unavailable):find("you're missing",1,true))
order.reagents={reagent(103,nil,1)}
local partial=A.Capture(order)
assert(not partial.complete and select(2,A.Analyze(partial.rows[1]))==nil,'unknown quantity treated as zero')
order.reagents={reagent(103,40,1),reagent(201,2,2)}
local oldRank=ranks[102];ranks[102]=nil
assert(not A.MaterialsOK(A.Capture(order)),'uncached maximum rank treated as known')
ranks[102]=oldRank
-- Sparks are never reported: neither missing, nor supplied, nor as an
-- unknown extra item. Spark slots are recognized structurally (spark/fragment
-- variable quantities) and by name, also in snapshots from older versions.
schematic={reagentSlotSchematics={slot({301,302},2,1),slot({201},3,2)}}
schematic.reagentSlotSchematics[1].variableQuantities={{reagent={itemID=301},quantity=2},{reagent={itemID=302},quantity=6}}
order.reagents={reagent(302,4,1)}
local sparkless=A.Capture(order)
assert(#sparkless.rows==1 and sparkless.rows[1].name=='Thread','spark slot entered the snapshot')
assert(A.Issues(sparkless)=="Looks like you're missing 3 Thread.",'missing spark was reported')
order.reagents={reagent(301,1,1),reagent(302,3,1),reagent(201,3,2)}
local withSparks=A.Capture(order)
assert(withSparks.complete and #withSparks.rows==1,'supplied sparks became unknown extra rows')
names[501]='Spark of Radiance';names[502]='Sterling Alloy'
schematic={reagentSlotSchematics={slot({501},4,1),slot({502},3,2)}}
order.reagents={}
local named=A.Capture(order)
assert(#named.rows==1 and named.rows[1].name=='Sterling Alloy','named spark slot entered the snapshot')
local legacy={version=1,orderID=9,capturedAt=time(),complete=true,rows={
    {itemID=501,name='Spark of Radiance',required=4,known=true,supplied={}},
    {itemID=601,name='Расколотая искра',required=2,known=true,supplied={}},
    {itemID=502,name='Sterling Alloy',required=3,known=true,supplied={}}}}
local cleaned=A.Sanitize(legacy)
assert(#cleaned.rows==1 and cleaned.rows[1].name=='Sterling Alloy','stored spark rows survived sanitizing')
assert(A.Issues(cleaned)=="Looks like you're missing 3 Sterling Alloy.")
schematic={reagentSlotSchematics={slot({101,102,103},5,1),slot({101,102,103},5,2)}}
order.reagents={{itemID=101,quantity=5}}
local ambiguous=A.Capture(order)
assert(not ambiguous.complete and not A.Issues(ambiguous):find("you're missing",1,true),'ambiguous slot falsely accused customer')
order.reagents={reagent(101,5,2)}
local indexed=A.Capture(order)
assert(indexed.rows[1].supplied[1]==nil and indexed.rows[2].supplied[1].quantity==5)
schematic={reagentSlotSchematics={{reagents={{currencyID=7}},quantityRequired=1,required=true}}}
order.reagents={}
assert(not A.Capture(order).complete and not A.Issues(A.Capture(order)):find("you're missing",1,true))
local clean=A.Sanitize(audit)
clean.rows[1].name='|Hitem:1|h[Injected]|h\n{crafter}'
clean.rows[1].supplied[1].quantity=-1
clean=A.Sanitize(clean)
assert(not clean.rows[1].name:find('[{}|]') and clean.rows[1].supplied[1].quantity==nil)
assert(not A.Sanitize({version=1,orderID=7001,rows={}}),'undated payload accepted')
local status={status='rejected',craftingOrderID=7001,reagentAudit=audit}
Scan.OrderFulfillment={Status={Rejected='rejected',Fulfilled='fulfilled'},GetStatus=function() return status end}
local response={};Scan.OrderToResponse=function() return response end
Scan.DB.listed_orders.a={}
assert(A.ForResponse(response)==audit)
status.craftingOrderID=7002
assert(not A.ForResponse(response),'audit leaked to resent game order')
status.craftingOrderID=7001;status.status='fulfilled'
assert(A.ForResponse(response)==audit and A.ForResponse(response).orderID==7001,
    'completed order lost its material list')

local owner,lines,columns={},{},{}
UIParent={GetWidth=function() return 1200 end}
local left,right=600,850
local history={GetLeft=function() return left end,GetRight=function() return right end}
function CreateFrame()
    return setmetatable({GetWidth=function() return 300 end,
        AddLine=function(_,text) lines[#lines+1]=text end,
        AddDoubleLine=function(_,text,value,_,_,_,r,g,b)
            lines[#lines+1]=text..' '..value;columns[#columns+1]={text=text,value=value,r=r,g=g,b=b}
        end,
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

-- Screenshot regression: late but populated snapshot showed green ?/N next
-- to explicit 1x/10x counts and duplicated names. Its spark is not shown.
local late={version=1,orderID=1238880255,capturedAt=time(),complete=false,rows={}}
local sample={{'Tormented Tantalum',1},{'Mote of Wild Magic',10},
    {'Kaleidoscopic Prism',1,2},{'Dusk-Shrouded Stone',3,2},{'Flawless Amani Lapis',1,2},
    {'Spark of Tides',2}}
for i,item in ipairs(sample) do
    late.rows[i]={itemID=i,name=i==6 and 'Spark of Radiance' or item[1],required=item[2],known=false,
        supplied={{itemID=i,name=item[1],quantity=item[2],quality=item[3],maxQuality=item[3]}}}
end
late=A.Sanitize(late)
table.remove(sample)
lines={};columns={};A.ShowTooltip(owner,'Late',history,late)
assert(#lines==8,'five materials should use five rows, two header lines and one partial-data note')
assert(#columns==5,'tooltip listed a spark')
for i,column in ipairs(columns) do
    assert(column.value:find('≥'..sample[i][2]..'/'..sample[i][2],1,true),'explicit supplied count became ?')
    assert(column.r==0.7 and column.g==0.7 and column.b==0.7,'unknown coverage was colored as confirmed good')
    assert(select(2,A.Analyze(late.rows[i]))==nil,'late evidence invented a shortage')
end
late.rows[3].supplied[1].quality=1
lines={};columns={};A.ShowTooltip(owner,'Late',history,late)
assert(columns[3].value:find('T1→T2',1,true) and columns[3].g==0.65,
    'partial snapshot hid known low-quality reagents')
late.rows[2].supplied[1].quantity=nil
assert(A.Analyze(late.rows[2])==nil,'missing numeric quantity was invented')
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
assert(rendered and rendered:find("you're missing 5 Alloy",1,true),'paste chose fulfilled context instead of declined item')
statuses[1].status='fulfilled'
assert(not Scan.CustomExplanations:Render('{reagent_issues}','Buyer'),'paste revived an obsolete rejection')
print('Reagent custom paste context tests passed.')
