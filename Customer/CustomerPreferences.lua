-- Only fully linked accounts exchange these records. Lamport revisions and
-- durable removals prevent offline peers from resurrecting an expired ignore.
local _, Scan = ...
local P = {}
Scan.CustomerPreferences = P
local function State()
    local s = Scan.DB and Scan.DB.settings
    if not s then return end
    if type(s.customer_preferences) ~= 'table' then s.customer_preferences={clock=0,records={}} end
    s.customer_preferences.clock=tonumber(s.customer_preferences.clock) or 0
    if type(s.customer_preferences.records)~='table' then s.customer_preferences.records={} end
    return s.customer_preferences, s.my_uuid or 'local'
end
local function Key(name)
    return Scan.ChatIgnore and Scan.ChatIgnore.Key(name)
end
local function Newer(a,b) return not b or a.n>b.n or (a.n==b.n and a.by>b.by) end
local function Send(records)
    if HironCraftScanComm and HironCraftScanComm.ShareCustomerPreferences then
        HironCraftScanComm:ShareCustomerPreferences(records)
    end
end
function P.Set(kind, name, expires, removed, quiet)
    local s, actor = State()
    local key = Key(name)
    if not s or not key then return end
    local id = kind .. ':' .. key
    s.clock = s.clock+1
    local r = {id=id,kind=kind,name=name,n=s.clock,by=actor,expires=expires or 0,removed=removed == true,at=time()}
    s.records[id] = r
    if not quiet then Send({r}) end
    if kind=='mute' and Scan.ChatFilter then Scan.ChatFilter.Changed() end
    return r
end
function P.IsMuted(name)
    local s = State()
    local key = Key(name)
    local r = s and key and s.records['mute:'..key]
    return r and not r.removed and (r.expires == 0 or r.expires > time()) or false
end
function P.SetMuted(name, muted) P.Set('mute',name,0,not muted) end
function P.Snapshot()
    local s = State()
    local result = {}
    for _, r in pairs(s and s.records or {}) do result[#result+1]=r end
    return result
end
function P.Revisions()
    local result={}
    for _, r in ipairs(P.Snapshot()) do result[r.id]={n=r.n,by=r.by} end
    return result
end
function P.Delta(revisions)
    local result={}
    for _,r in ipairs(P.Snapshot()) do
        local old=type(revisions)=='table' and revisions[r.id]
        if type(old)~='table' or type(old.n)~='number' or type(old.by)~='string' or Newer(r,old) then
            result[#result+1]=r
        end
    end
    return result
end
function P.Merge(records)
    if type(records) ~= 'table' or #records>40 then return false end
    local s = State()
    if not s then return false end
    local changed, forward = false, {}
    for _, r in ipairs(records) do
        if type(r)=='table' and (r.kind=='ignore' or r.kind=='mute')
            and type(r.name)=='string' and #r.name>0 and #r.name<=256
            and type(r.by)=='string' and #r.by>0 and #r.by<=128
            and type(r.n)=='number' and r.n==r.n and r.n>=1 and r.n<=1e12 and r.n%1==0
            and type(r.expires)=='number' and r.expires==r.expires and r.expires>=0 and r.expires<1e12
            and type(r.removed)=='boolean' and type(r.at)=='number' and r.at==r.at and r.at>0 and r.at<1e12 then
            local key = Key(r.name)
            local id = key and (r.kind..':'..key)
            if id and r.id==id then
                s.clock=math.max(s.clock,r.n)
                if Newer(r,s.records[id]) then
                    local clean={id=id,kind=r.kind,name=r.name,n=r.n,by=r.by,expires=r.expires,removed=r.removed,at=r.at}
                    s.records[id]=clean
                    if r.kind=='ignore' and Scan.ChatIgnore then
                        if r.removed or (r.expires>0 and r.expires<=time()) then
                            Scan.ChatIgnore.Remove(r.name,{remote=true,quiet=true})
                        else
                            Scan.ChatIgnore.Add(r.name,{remote=true,quiet=true,replace=true,at=r.at,expires=r.expires})
                        end
                    end
                    changed=true; forward[#forward+1]=clean
                end
            end
        end
    end
    if #forward>0 then Send(forward) end
    if changed and Scan.ChatFilter then Scan.ChatFilter.Changed() end
    return changed
end
if Scan.Utils and Scan.Utils.onLoad then
    Scan.Utils.onLoad(function()
        local s = State()
        if not s or s.imported then return end
        for _, e in ipairs(Scan.ChatIgnore.List()) do
            P.Set('ignore',e.name,tonumber(e.expires) or 0,false,true)
        end
        s.imported=true
    end)
end
