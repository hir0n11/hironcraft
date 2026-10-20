-- Stress persistence, retractions and bounded sync using the real journal and
-- serializers. No actual player history or SavedVariables are touched.
local now=1792000000
function time() return now end
function GetTime() return now end
date=os.date;strmatch=string.match
local combat=false
function InCombatLockdown() return combat end
local timers={}
C_Timer={After=function(delay,fn) timers[#timers+1]={at=now+delay,fn=fn} end}
local function Timer()
    table.sort(timers,function(a,b) return a.at<b.at end)
    local timer=table.remove(timers,1)
    if not timer then return false end
    now=timer.at;timer.fn();return true
end
assert(loadfile('Workflow/Core/Libs/LibStub/LibStub.lua'))()
assert(loadfile('Libs/LibSerialize.lua'))()
assert(loadfile('Libs/LibDeflate.lua'))()
local Serialize,Deflate=LibStub('LibSerialize'),LibStub('LibDeflate')
local packs,maxPack=0,0
local serialize=Serialize.Serialize
function Serialize:Serialize(value,...)
    if type(value)=='table' and value[1] and value[1].k then
        packs=packs+1;maxPack=math.max(maxPack,#value)
    end
    return serialize(self,value,...)
end
local Scan={DB={analytics={backfilled=1,untipped_silver=1},settings={},customers={}},Utils={}}
assert(loadfile('Customer/AnalyticsLog.lua'))('HironCraft',Scan)
local Log=Scan.AnalyticsLog
local function All()
    local result={}
    Log.LoadRange(0,math.huge,nil,function(chunks)
        for _,events in ipairs(chunks) do for _,event in ipairs(events) do result[#result+1]=event end end
    end)
    return result
end
local root=Log.Root()
for i=1,10000 do
    root.open.events[i]={k='r',q=i,t=now-10000+i,c='Synthetic'..i,id='request:'..i}
end
root.seq=10000;root.open.from=now-10000;root.open.to=now;root.open.maxQ=10000
Log.Startup()
assert(packs==0,'Startup compressed the old oversized store synchronously')
assert(#root.open.events==Log.RECENT_EVENTS and #root.pending>0)
for _,chunk in ipairs(root.pending) do assert(#chunk.events<=Log.STORE_LIMIT) end
assert(#All()==10000,'Splitting old history lost or duplicated events')

-- Recording while busy never compresses on the event handler's stack, and
-- leaves every event within the old 201-event retraction window mutable.
while #root.open.events<Log.STORE_LIMIT-1 do Log.Record({k='r'}) end
local beforePacks=packs
local greeting=Log.Record({k='g',id='throttled'})
local beforeRetract=#All()
assert(packs==beforePacks and #root.open.events==Log.RECENT_EVENTS)
Log.Retract({greeting})
assert(#All()==beforeRetract-1,'Rotation broke a throttled greeting retraction')
Log.Record({k='c',o=77,rs={{i=9,n=2,v=100}}})
local expected=#All()
local crafts=0
Log.VisitReturnEvents(function() crafts=crafts+1 end,function() end)
-- VisitReturnEvents intentionally streams its pending raw stores over timers.
local guard=0
while #timers>0 do
    local before=packs
    Timer();guard=guard+1
    assert(packs-before<=1,'A background callback packed more than one chunk')
    assert(guard<200,'Maintenance did not finish')
end
assert(crafts==1 and #All()==expected,'Catalogue/maintenance did not preserve all events')
assert(maxPack<=Log.STORE_LIMIT,'A compression block exceeded the bounded size')

-- Pending chunks must survive an immediate logout/reload and encoder failure.
for i=1,700 do Log.Record({k='r',id='new:'..i}) end
expected=#All()
assert(#root.pending>0)
local ok,copy=Serialize:Deserialize(Serialize:Serialize(Scan.DB))
assert(ok)
Scan.DB=copy;Log.ReleaseCache();root=Log.Root()
assert(#All()==expected,'Reload lost pending records')
local pendingCount=#root.pending
local first=root.pending[1]
local actualSerialize=Serialize.Serialize
Serialize.Serialize=function() error('Synthetic encoder failure') end
assert(not pcall(Log.CloseOpenStore))
assert(#root.pending==pendingCount and root.pending[1]==first and first.events,
    'Encoder failure discarded the persistent pending chunk')
Serialize.Serialize=actualSerialize
Log.Startup()
combat=true
local before=packs
Timer()
assert(packs==before,'Maintenance ignored the combat guard')
combat=false
guard=0
while Timer() do guard=guard+1;assert(guard<200) end
assert(#root.pending==0 and #All()==expected)

-- Finite sync batches neither sort all remaining events nor unpack all later
-- bounded stores. Gaps/retractions and foreign events preserve the protocol.
local unpacks=0
local decompress=Deflate.DecompressDeflate
function Deflate:DecompressDeflate(...) unpacks=unpacks+1;return decompress(self,...) end
local largestSort=0
local sort=table.sort
table.sort=function(values,compare)
    if values[1] and type(values[1])=='table' and values[1].q then largestSort=math.max(largestSort,#values) end
    return sort(values,compare)
end
Log.ReleaseCache()
local batch,last,more=Log.OwnSince(0,150)
assert(#batch==150 and last==150 and more)
assert(unpacks<=2,'First batch unpacked later history: '..unpacks)
assert(largestSort<=151,'Finite batch sorted the entire history')
local own,previous={},0
repeat
    local rows,nextQ,hasMore=Log.OwnSince(previous,150)
    for _,event in ipairs(rows) do
        assert(event.q>previous and not own[event.q],'Sync skipped ordering or duplicated an event')
        own[event.q]=true;previous=event.q
        assert(event.id~='throttled','Retracted greeting was synchronized')
    end
    assert(nextQ>=previous)
    previous=nextQ;more=hasMore
until not more
assert(previous==root.seq)
local n=0;for _ in pairs(own) do n=n+1 end
assert(n==expected,'Sync lost an event')
assert(largestSort<=151)
table.sort=sort

-- A rotation during an asynchronous history load must neither drop the
-- previous open tail nor include it again through newly packed stores.
while #root.open.events<Log.STORE_LIMIT-1 do Log.Record({k='r'}) end
local expectedSnapshot=#All()
local drivers={}
CreateFrame=function()
    local frame={}
    function frame:SetScript(_,fn) self.update=fn end
    drivers[#drivers+1]=frame;return frame
end
local ticks=0
debugprofilestop=function() ticks=ticks+20;return ticks end
local loaded
Log.ReleaseCache()
Log.LoadRange(0,math.huge,nil,function(chunks)
    loaded=0;for _,events in ipairs(chunks) do loaded=loaded+#events end
end)
assert(not loaded,'Expected a yielding load')
Log.Record({k='r',id='arrived-during-load'})
Log.Maintain()
guard=0
while not loaded do
    for _,frame in ipairs(drivers) do if frame.update then frame.update() end end
    guard=guard+1;assert(guard<200)
end
assert(loaded==expectedSnapshot+1,'Rotation lost/duplicated the loading snapshot')
CreateFrame=nil;debugprofilestop=nil

-- Legacy stores can have no lower bound and may be out of physical order.
local function Store(events)
    local maxQ=0;for _,event in ipairs(events) do maxQ=math.max(maxQ,event.q or 0) end
    return {data=Deflate:EncodeForPrint(Deflate:CompressDeflate(Serialize:Serialize(events))),
        n=#events,maxQ=maxQ,tidy=1}
end
Scan.DB.analytics={seq=20,stores={
    Store({{k='r',q=9},{k='r',q=2}}),Store({{k='d',q=1},{k='r',q=3}}),
    Store({{k='r',q=7},{k='r',q=20,m='foreign'}})},open={events={}}}
Log.ReleaseCache()
batch,last,more=Log.OwnSince(0,2)
assert(batch[1].q==1 and batch[2].q==2 and last==2 and more)
batch,last,more=Log.OwnSince(0,2,{d=true})
assert(batch[1].q==2 and batch[2].q==3 and last==3 and more)
batch,last,more=Log.OwnSince(9,2)
assert(#batch==0 and last==20 and not more,'Skipped/foreign sequence gap was not acknowledged')
print('Performance analytics: bounded packing/sorts, deferred startup, busy recording, retract, reload, failure, catalogue and legacy sync passed')
