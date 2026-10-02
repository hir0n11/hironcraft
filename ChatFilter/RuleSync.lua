-- Per-rule last-writer-wins records. Deletions are durable tombstones, so an
-- offline account cannot bring a removed rule back when it reconnects.
-- Local history, counts, ignores and general filtering switches never travel.
local _, Scan = ...
local S = {}
Scan.ChatFilterSync = S
local F = Scan.ChatFilter
local queued, timer, applying = {}, false, false
local function Actor()
    return Scan.DB and Scan.DB.settings and Scan.DB.settings.my_uuid
end
local function Definition(rule)
    return { name=rule.name, key=rule.key, expr=rule.expr, whole=rule.whole == true, on=rule.on == true }
end
local function Equal(a, b)
    for _, key in ipairs({'name','key','expr','whole','on'}) do if a[key] ~= b[key] then return false end end
    return true
end
local function Copy(record)
    local copy = {}
    for key, value in pairs(record) do copy[key] = value end
    return copy
end
local function Identity(rule)
    if rule.expr then return 'expr:' .. rule.expr end
    return (rule.whole and 'word:' or 'key:') .. Scan.FilterEngine.Lower(rule.key or '')
end
local function State()
    local db, actor = F.DB(), Actor()
    if not db or type(actor) ~= 'string' or actor == '' then return end
    if type(db.rule_sync) ~= 'table' then db.rule_sync = { clock=0, records={} } end
    return db.rule_sync, db, actor
end
local function Newer(a, b)
    return not b or a.n > b.n or (a.n == b.n and a.by > b.by)
end
local function Queue(record)
    queued[record.id] = Copy(record)
    if timer or not C_Timer then return end
    timer = true
    C_Timer.After(1, function()
        timer = false
        local records = {}
        for _, entry in pairs(queued) do records[#records+1] = entry end
        queued = {}
        if #records > 0 and HironCraftScanComm and HironCraftScanComm.ShareChatFilterRules then
            HironCraftScanComm:ShareChatFilterRules(records)
        end
    end)
end
function S.Capture()
    if applying then return end
    local state, db, actor = State()
    if not state then return end
    local seen = {}
    for _, rule in ipairs(db.rules) do
        local definition = Definition(rule)
        local id = rule.syncID or Identity(rule)
        local previous = state.records[id]
        -- Re-adding the original keyword after editing it must not replace
        -- the edited rule that still owns that original migration identity.
        if not rule.syncID and previous and not previous.deleted and not Equal(previous, definition) then
            id = actor .. ':' .. tostring(rule.id)
            previous = state.records[id]
        end
        rule.syncID, seen[id] = id, true
        if not previous or previous.deleted or not Equal(previous, definition) then
            state.clock = state.clock + 1
            definition.id, definition.n, definition.by = id, state.clock, actor
            state.records[id] = definition
            Queue(definition)
        end
    end
    for id, previous in pairs(state.records) do
        if not previous.deleted and not seen[id] then
            state.clock = state.clock + 1
            local tombstone = {id=id, n=state.clock, by=actor, deleted=true}
            state.records[id] = tombstone
            Queue(tombstone)
        end
    end
end
function S.Revisions()
    S.Capture()
    local state = State()
    if not state then return nil end
    local revisions = {}
    for id, record in pairs(state.records) do revisions[id] = {n=record.n, by=record.by} end
    return revisions
end
function S.Delta(revisions)
    if type(revisions) ~= 'table' then return {} end -- older clients
    S.Capture()
    local state = State()
    local records = {}
    for id, record in pairs(state and state.records or {}) do
        local peer = revisions[id]
        if type(peer) ~= 'table' or type(peer.n) ~= 'number' or type(peer.by) ~= 'string'
            or Newer(record, peer) then records[#records+1] = Copy(record) end
    end
    return records
end
local function ValidString(value, max)
    return type(value) == 'string' and #value > 0 and #value <= max
end
local function Validate(record)
    if type(record) ~= 'table' or not ValidString(record.id, 8192)
        or not ValidString(record.by, 128) or type(record.n) ~= 'number'
        or record.n ~= record.n or record.n < 1 or record.n > 1e12 or record.n % 1 ~= 0 then return end
    if record.deleted == true then return { id=record.id, n=record.n, by=record.by, deleted=true } end
    if not ValidString(record.name, 4096) or type(record.on) ~= 'boolean' then return end
    if record.expr then
        if record.key ~= nil or not ValidString(record.expr, 4096) or not Scan.FilterEngine.Compile(record.expr) then return end
    elseif not ValidString(record.key, 4096) or type(record.whole) ~= 'boolean' then return end
    local clean = Definition(record)
    clean.id, clean.n, clean.by = record.id, record.n, record.by
    return clean
end
function S.Merge(records)
    if type(records) ~= 'table' or #records > 40 then return false end
    S.Capture() -- preserve local edits before comparing remote versions
    local state, db = State()
    if not state then return false end
    local changed = false
    for _, incoming in ipairs(records) do
        local record = Validate(incoming)
        if record then
            state.clock = math.max(state.clock, record.n)
            if Newer(record, state.records[record.id]) then
                state.records[record.id] = record
                Queue(record) -- forward once to other linked accounts; identical versions stop here
                changed = true
            end
        end
    end
    if not changed then return false end
    local rules, seen = {}, {}
    local function Apply(record, old)
        if not record or record.deleted or seen[record.id] then return end
        local rule = old or { id='r' .. db.next_id, count=0, at=time() }
        if not old then db.next_id = db.next_id + 1 end
        for _, key in ipairs({'name','key','expr','whole','on'}) do rule[key] = record[key] end
        rule.syncID, seen[record.id] = record.id, true
        rules[#rules+1] = rule
    end
    -- Keep existing row IDs, local histories and ordering.
    for _, rule in ipairs(db.rules) do Apply(state.records[rule.syncID], rule) end
    local ids = {}
    for id, record in pairs(state.records) do
        if not seen[id] and not record.deleted then ids[#ids+1] = id end
    end
    table.sort(ids)
    for _, id in ipairs(ids) do Apply(state.records[id]) end
    db.rules = rules
    applying = true
    F.Changed()
    applying = false
    return true
end
F.OnChange(S.Capture)
if Scan.Utils and Scan.Utils.onLoad then Scan.Utils.onLoad(S.Capture) end
