-- Real time-cell methods; only the frame and clock boundaries are mocked.
local now = 1000
function time() return now end
function CreateFromMixins() return {} end
EnumUtil = { MakeEnum=function(...) local e={}; for i,key in ipairs({...}) do e[key]=i end; return e end }
local Scan = {CONST={TEXT={}}, LOCAL={GetText=function(_,key) return key end}}
Scan.OrderFulfillment = {Status={Unknown=0,Claimed=1,Crafted=2,Fulfilled=3,Failed=4,Rejected=5}}
local responses, live = {}, {}
function Scan.OrderToResponse(order)
    local customer = order and responses[order.customerName]
    return customer and customer[order.responseID]
end
function Scan.OrderToLiveResponse(order)
    live[order.customerName] = live[order.customerName] or {}
    local customer = live[order.customerName]
    customer[order.responseID] = customer[order.responseID] or {}
    return customer[order.responseID]
end
assert(loadfile('Customer/OrderTableTemplate.lua'))('HironCraft',Scan)
local M = HironCraftScanCrafterTableCellTimeMixin
local function put(customer,id,age)
    local order = {customerName=customer,responseID=id}
    responses[customer] = responses[customer] or {}
    responses[customer][id] = {time=now-age,requestToken=customer..id}
    return order
end
local function cell()
    local f = setmetatable({visible=true,writes=0,row={}}, {__index=M})
    f.Text = {SetText=function(_,text) f.text=text; f.writes=f.writes+1 end}
    function f:IsVisible() return self.visible end
    function f:GetParent() return self.row end
    return f
end
local function bind(f,order)
    f.row.order=order
    f:Populate({order=order})
    return Scan.OrderToLiveResponse(order)
end
local function tick()
    for _,customer in pairs(live) do
        for _,response in pairs(customer) do
            if response.updateAge then response.updateAge() end
        end
    end
end
local old = put('Old',1,660)
local fresh = put('Fresh',2,5)
local f = cell()
local oldLive = bind(f,old)
assert(f.text=='11m')
local stale = oldLive.updateAge
local freshLive = bind(f,fresh)
assert(f.text=='5s')
local count=f.writes
stale()
assert(f.text=='5s' and f.writes==count, 'recycled cell was overwritten with the old 11-minute timer')
assert(oldLive.updateAge==nil, 'old request retained a pooled-cell callback')
for _=1,20 do now=now+5; tick(); assert(f.text~='11m', 'timer jumped during the global age refresh') end
assert(f.text=='1m')

-- A sync merge replaces the response object without replacing the cell.
responses.Fresh[2] = {time=now-35,requestToken='replaced'}
freshLive.updateAge()
assert(f.text=='35s', 'timer kept the pre-sync response table')
responses.Fresh[2].time=now-50; freshLive.updateAge()
assert(f.text=='50s')

-- Hidden/released cells cannot update, and reopening immediately rebinds them.
local hiddenCallback=freshLive.updateAge
f.visible=false; f:OnHide()
count=f.writes; now=now+20; hiddenCallback(); tick()
assert(f.writes==count and not freshLive.updateAge, 'hidden cell retained its timer')
f.visible=true; f:OnShow()
assert(f.text=='1m' and freshLive.updateAge, 'reopened cell did not resume')

-- An old cell being hidden must not clear the callback of a newer owner.
local replacement=cell(); bind(replacement,fresh)
local activeCallback=freshLive.updateAge
count=f.writes; f._ageUpdate()
assert(f.writes==count, 'superseded owner updated another binding')
f:OnHide()
assert(freshLive.updateAge==activeCallback, 'old cell cleared the new cell\'s timer')

-- Guard the gap while a parent row has been recycled but cells are not populated.
replacement.row.order=old
count=replacement.writes; activeCallback()
assert(replacement.writes==count, 'timer updated after its parent row was recycled')
replacement.row.order=fresh

-- Missing/bad dates do not break the shared ticker; future dates never wrap unsigned.
local function textFor(stamp,expected)
    responses.Fresh[2]={time=stamp}
    activeCallback()
    assert(replacement.text==expected, 'invalid/future date: '..tostring(stamp)..' -> '..tostring(replacement.text))
end
textFor(now+600,'0s')
textFor(nil,'—'); textFor('bad','—'); textFor(0/0,'—'); textFor(math.huge,'—'); textFor(-math.huge,'—')
textFor(tostring(now-59),'55s'); textFor(now-60,'1m'); textFor(now-3599,'59m'); textFor(now-3600,'1h')
responses.Fresh[2]=nil; activeCallback(); assert(replacement.text=='—')
replacement:Populate({}); assert(not freshLive.updateAge and replacement.text=='—')

-- Many pooled/reordered cells, aliases and status refreshes remain independent.
local pool={cell(),cell(),cell()}
local orders={}
for i=1,30 do orders[i]=put('Buyer',i,i*60) end
for round=1,20 do
    for i,c in ipairs(pool) do
        local order=orders[(round+i-2)%#orders+1]
        bind(c,order)
    end
    tick()
    for _,c in ipairs(pool) do
        local age=math.floor((now-responses.Buyer[c.row.order.responseID].time)/60)
        assert(c.text==age..'m', 'a pooled row displays another order\'s age')
    end
end
print('Order timer tests passed (11m recycling, stale callbacks, sync replacement, hide/show, ownership, malformed dates, pooled rows).')
