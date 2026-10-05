local Scan = select(2, ...)

-- Crafter pool profiles: named lists of characters, this account's and the
-- linked accounts', whose work is counted together. Kept per realm, inside
-- that realm's analytics journal (analytics.profiles), and the same on every
-- linked account (see Export and Merge).
--
-- With no profile on a realm everything is as it always was: every character
-- records and the window counts everything. Once one exists,
--   * a character that is in no profile records nothing: no time online, no
--     requests, no greetings, no orders (what linked accounts send is kept);
--   * the window can count one profile: the events its characters recorded
--     (event.w). Events from before 0.4.95 carry no recorder: orders and
--     crafts go by their crafter, the rest counts for the oldest profile.
--
-- Sharing is last writer wins per profile. A change made here stamps the
-- profile with this realm's profile clock (n) and this account (by); a
-- deleted profile leaves a tombstone (gone[id] = { n, by }), so an account
-- that was offline cannot bring it back.
local M = {}
Scan.AnalyticsProfiles = M

-- callback(isLocal): isLocal is true for a change made on this account.
local listeners = {}
function M.OnChange(callback)
    listeners[#listeners + 1] = callback
end

local function Changed(isLocal)
    for _, callback in ipairs(listeners) do pcall(callback, isLocal == true) end
end

local function Actor()
    local account = Scan.DB and Scan.DB.settings and Scan.DB.settings.my_uuid
    return type(account) == 'string' and account ~= '' and account or 'local'
end

local function Store(create)
    local analytics = Scan.DB and Scan.DB.analytics
    if type(analytics) ~= 'table' then return nil end
    if type(analytics.profiles) ~= 'table' then
        if not create then return nil end
        analytics.profiles = { seq = 0, list = {} }
    end
    local store = analytics.profiles
    if type(store.list) ~= 'table' then store.list = {} end
    if type(store.gone) ~= 'table' then store.gone = {} end
    store.seq = tonumber(store.seq) or 0
    store.clock = tonumber(store.clock) or 0
    return store
end

-- Whether stamp (n1, by1) is later than (n2, by2).
local function Newer(n1, by1, n2, by2)
    n1, n2 = tonumber(n1) or 0, tonumber(n2) or 0
    if n1 ~= n2 then return n1 > n2 end
    return tostring(by1 or '') > tostring(by2 or '')
end

local function Stamp(store, record)
    store.clock = store.clock + 1
    record.n, record.by = store.clock, Actor()
end

-- Oldest first, the same order on every account.
local function Before(lhs, rhs)
    local a, b = tonumber(lhs.at) or 0, tonumber(rhs.at) or 0
    if a ~= b then return a < b end
    return tostring(lhs.id) < tostring(rhs.id)
end

function M.List()
    local store = Store()
    return store and store.list or {}
end

function M.Any()
    return #M.List() > 0
end

function M.Get(id)
    if id == nil then return nil end
    for _, profile in ipairs(M.List()) do
        if profile.id == id then return profile end
    end
    return nil
end

-- The profile that takes the history from before recorders were kept: the
-- oldest one, whichever account made it.
function M.IsLegacy(profile)
    if type(profile) ~= 'table' then return false end
    for _, other in ipairs(M.List()) do
        if other ~= profile and Before(other, profile) then return false end
    end
    return M.Get(profile.id) == profile
end

-- The character logged in here, "Name-Realm". It does not change in a session.
local current
function M.Current()
    if current then return current end
    if type(Scan.GetPlayerName) ~= 'function' then return nil end
    local ok, name = pcall(Scan.GetPlayerName, true)
    if ok and type(name) == 'string' and name:find('-', 1, true) then current = name end
    return current
end

function M.Has(profile, character)
    return type(profile) == 'table' and type(profile.chars) == 'table' and character ~= nil
        and profile.chars[character] == true
end

-- Whether what a character does is recorded: always while the realm has no
-- profiles, afterwards only for a character in one of them.
function M.MayRecord(character)
    local list = M.List()
    if #list == 0 then return true end
    character = character or M.Current()
    -- Who is playing is not known yet: nothing is lost by recording.
    if not character then return true end
    for _, profile in ipairs(list) do
        if M.Has(profile, character) then return true end
    end
    return false
end

-- The realms of this journal: the player's and the ones connected to it.
local function LocalRealms()
    local realms, any = {}, false
    local own = GetNormalizedRealmName and GetNormalizedRealmName()
    if type(own) == 'string' and own ~= '' then realms[own], any = true, true end
    -- The way this addon writes the realm into a character's name.
    local written = GetRealmName and GetRealmName()
    if type(written) == 'string' and written ~= '' then realms[(written:gsub('[%s%-]', ''))], any = true, true end
    for _, realm in ipairs(Scan.State and type(Scan.State.realmNames) == 'table' and Scan.State.realmNames or {}) do
        if type(realm) == 'string' and realm ~= '' then realms[realm], any = true, true end
    end
    return any and realms or nil
end

-- Whether a "Name-Realm" belongs to this journal's realms. True when that
-- cannot be told.
function M.IsLocal(name)
    local realm = type(name) == 'string' and name:match('^[^-]+%-(.+)$')
    if not realm then return true end
    local realms = LocalRealms()
    if not realms then return true end
    return realms[realm] == true
end

-- The realm the player is on, as it is written into character names.
local function OwnRealm()
    local own = M.Current()
    local realm = own and own:match('^[^-]+%-(.+)$') or (GetNormalizedRealmName and GetNormalizedRealmName())
    return type(realm) == 'string' and realm ~= '' and realm or nil
end

-- Characters a profile can be made of: the realm's crafters, the linked
-- accounts' known characters, everyone who ever recorded into this journal,
-- the members of the profiles, and the player.
function M.Candidates()
    local names = {}
    local function Add(name)
        if type(name) == 'string' and name:find('-', 1, true) and M.IsLocal(name) then names[name] = true end
    end
    for name in pairs(Scan.DB and Scan.DB.characters or {}) do Add(name) end
    local accounts = Scan.DB and Scan.DB.realm and Scan.DB.realm.linked_accounts
    for _, account in pairs(type(accounts) == 'table' and accounts or {}) do
        if type(account) == 'table' then
            Add(account.last_active_char)
            for _, name in ipairs(type(account.backup_chars) == 'table' and account.backup_chars or {}) do Add(name) end
        end
    end
    local analytics = Scan.DB and Scan.DB.analytics
    for name in pairs(type(analytics) == 'table' and type(analytics.recorders) == 'table' and analytics.recorders or {}) do
        Add(name)
    end
    Add(M.Current())
    -- Members stay listed wherever they are from, so they can be unticked.
    for _, profile in ipairs(M.List()) do
        for name in pairs(type(profile.chars) == 'table' and profile.chars or {}) do names[name] = true end
    end
    local list = {}
    for name in pairs(names) do list[#list + 1] = name end
    table.sort(list)
    return list
end

local function CleanName(name)
    if type(name) ~= 'string' then return nil end
    name = name:gsub('^%s+', ''):gsub('%s+$', '')
    return name ~= '' and name or nil
end

-- A typed character name as "Name-Realm": the player's realm when none is
-- given, the realm without spaces like the game writes it.
function M.FullName(text)
    text = CleanName(text)
    if not text then return nil end
    local name, realm = text:match('^([^-]+)%-(.+)$')
    if not name then
        name, realm = text, OwnRealm()
        if not realm then return nil end
    end
    name = CleanName(name)
    realm = realm:gsub('[%s%-]', '')
    if not name or realm == '' then return nil end
    return name .. '-' .. realm
end

-- The members of a profile, sorted.
function M.Members(profile)
    local list = {}
    for name in pairs(type(profile) == 'table' and type(profile.chars) == 'table' and profile.chars or {}) do
        list[#list + 1] = name
    end
    table.sort(list)
    return list
end

-- A new profile. The first one on a realm starts with every known character
-- (leaving one out by mistake would lose what it does; an extra one is
-- unticked without loss); later ones start empty.
function M.Create(name)
    name = CleanName(name)
    if not name then return nil end
    local store = Store(true)
    if not store then return nil end
    store.seq = store.seq + 1
    local profile = {
        id = string.format('%s:%d', Actor():sub(1, 8), store.seq),
        name = name, chars = {}, at = time and time() or 0,
    }
    if #store.list == 0 then
        for _, character in ipairs(M.Candidates()) do profile.chars[character] = true end
    end
    Stamp(store, profile)
    store.list[#store.list + 1] = profile
    table.sort(store.list, Before)
    Changed(true)
    return profile
end

function M.Rename(id, name)
    local profile, store = M.Get(id), Store()
    name = CleanName(name)
    if not profile or not name then return false end
    profile.name = name
    Stamp(store, profile)
    Changed(true)
    return true
end

-- The history from before profiles goes on to the oldest profile left.
function M.Delete(id)
    local store = Store()
    if not store then return false end
    for index, profile in ipairs(store.list) do
        if profile.id == id then
            table.remove(store.list, index)
            local mark = {}
            Stamp(store, mark)
            store.gone[id] = mark
            Changed(true)
            return true
        end
    end
    return false
end

function M.SetMember(id, character, on)
    local profile, store = M.Get(id), Store()
    if not profile or type(character) ~= 'string' or character == '' then return false end
    if type(profile.chars) ~= 'table' then profile.chars = {} end
    profile.chars[character] = on and true or nil
    Stamp(store, profile)
    Changed(true)
    return true
end

-- What the report needs to count one profile; nil counts everything.
function M.Filter(id)
    local profile = M.Get(id)
    if not profile then return nil end
    return { chars = type(profile.chars) == 'table' and profile.chars or {}, legacy = M.IsLegacy(profile) }
end

-- The name shown for a profile member: without the realm on the player's own.
function M.DisplayName(character)
    local realm = OwnRealm()
    local name, itsRealm = tostring(character):match('^([^-]+)%-(.+)$')
    if name and realm and itsRealm == realm then return name end
    return tostring(character)
end

-- Sharing with linked accounts -------------------------------------------------

-- A number that changes whenever this realm's profiles do, here or by a
-- merge; nil while the realm never had any.
function M.Stamp()
    local store = Store()
    if not store or (#store.list == 0 and next(store.gone) == nil) then return nil end
    return store.clock
end

-- This realm's profiles and tombstones for a linked account, or nil when the
-- realm never had any.
function M.Export()
    local store = Store()
    if not store then return nil end
    local list, gone = {}, {}
    for _, profile in ipairs(store.list) do
        -- Made before profiles were shared.
        if profile.n == nil then Stamp(store, profile) end
        list[#list + 1] = { id = profile.id, name = profile.name, chars = M.Members(profile),
            at = profile.at, n = profile.n, by = profile.by }
    end
    for id, mark in pairs(store.gone) do
        gone[#gone + 1] = { id = id, n = mark.n, by = mark.by }
    end
    if #list == 0 and #gone == 0 then return nil end
    return { realm = OwnRealm(), list = list, gone = gone }
end

-- Takes a linked account's Export. Each profile is whichever side changed it
-- last; a deletion counts as a change. Returns whether anything changed here.
function M.Merge(data)
    if type(data) ~= 'table' then return false end
    -- Profiles belong to a realm: another realm's are not for this journal.
    if type(data.realm) == 'string' and data.realm ~= '' and not M.IsLocal('x-' .. data.realm) then return false end
    local incoming = type(data.list) == 'table' and data.list or {}
    local deleted = type(data.gone) == 'table' and data.gone or {}
    if #incoming == 0 and #deleted == 0 then return false end
    local store = Store(true)
    if not store then return false end

    local byID, changed = {}, false
    for _, profile in ipairs(store.list) do byID[profile.id] = profile end
    for _, mark in ipairs(deleted) do
        if type(mark) == 'table' and type(mark.id) == 'string' and tonumber(mark.n) then
            store.clock = math.max(store.clock, tonumber(mark.n))
            local have, known = byID[mark.id], store.gone[mark.id]
            if have then
                if Newer(mark.n, mark.by, have.n, have.by) then
                    for index, profile in ipairs(store.list) do
                        if profile == have then table.remove(store.list, index) break end
                    end
                    byID[mark.id] = nil
                    store.gone[mark.id] = { n = tonumber(mark.n), by = mark.by }
                    changed = true
                end
            elseif not known or Newer(mark.n, mark.by, known.n, known.by) then
                store.gone[mark.id] = { n = tonumber(mark.n), by = mark.by }
            end
        end
    end
    for _, record in ipairs(incoming) do
        local name = type(record) == 'table' and CleanName(record.name)
        if name and type(record.id) == 'string' and tonumber(record.n) and type(record.chars) == 'table' then
            store.clock = math.max(store.clock, tonumber(record.n))
            local have, known = byID[record.id], store.gone[record.id]
            local deletedLater = known and not Newer(record.n, record.by, known.n, known.by)
            if not deletedLater and (not have or Newer(record.n, record.by, have.n, have.by)) then
                local profile = have or { id = record.id }
                profile.name, profile.at = name, tonumber(record.at)
                profile.n, profile.by = tonumber(record.n), record.by
                profile.chars = {}
                for _, character in ipairs(record.chars) do
                    if type(character) == 'string' and character ~= '' then profile.chars[character] = true end
                end
                if not have then
                    store.list[#store.list + 1] = profile
                    byID[record.id] = profile
                end
                store.gone[record.id] = nil
                changed = true
            end
        end
    end
    if changed then
        table.sort(store.list, Before)
        Changed(false)
    end
    return changed
end
