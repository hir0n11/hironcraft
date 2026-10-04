local Scan = select(2, ...)

-- Crafter pool profiles: named lists of characters, this account's and the
-- linked accounts', whose work is counted together. Kept per realm, inside
-- that realm's analytics journal (analytics.profiles).
--
-- With no profile on a realm everything is as it always was: every character
-- records and the window counts everything. Once one exists,
--   * a character that is in no profile records nothing: no time online, no
--     requests, no greetings, no orders (what linked accounts send is kept);
--   * the window can count one profile: the events its characters recorded
--     (event.w). Events from before 0.4.95 carry no recorder: orders and
--     crafts go by their crafter, the rest counts for the profile marked
--     legacy, the first one made on the realm.
local M = {}
Scan.AnalyticsProfiles = M

local listeners = {}
function M.OnChange(callback)
    listeners[#listeners + 1] = callback
end

local function Changed()
    for _, callback in ipairs(listeners) do pcall(callback) end
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
    store.seq = tonumber(store.seq) or 0
    return store
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
        name = text
        local own = M.Current()
        realm = own and own:match('^[^-]+%-(.+)$') or (GetNormalizedRealmName and GetNormalizedRealmName())
        if type(realm) ~= 'string' or realm == '' then return nil end
    end
    name = CleanName(name)
    realm = realm:gsub('[%s%-]', '')
    if not name or realm == '' then return nil end
    return name .. '-' .. realm
end

-- A new profile. The first one on a realm starts with every known character
-- and takes the history recorded before profiles; later ones start empty.
function M.Create(name)
    name = CleanName(name)
    if not name then return nil end
    local store = Store(true)
    if not store then return nil end
    store.seq = store.seq + 1
    local account = Scan.DB.settings and Scan.DB.settings.my_uuid
    local profile = {
        id = string.format('%s:%d', type(account) == 'string' and account:sub(1, 8) or 'local', store.seq),
        name = name, chars = {},
    }
    if #store.list == 0 then
        profile.legacy = true
        for _, character in ipairs(M.Candidates()) do profile.chars[character] = true end
    end
    store.list[#store.list + 1] = profile
    Changed()
    return profile
end

function M.Rename(id, name)
    local profile = M.Get(id)
    name = CleanName(name)
    if not profile or not name then return false end
    profile.name = name
    Changed()
    return true
end

-- The history from before profiles moves on to the oldest profile left.
function M.Delete(id)
    local store = Store()
    if not store then return false end
    for index, profile in ipairs(store.list) do
        if profile.id == id then
            table.remove(store.list, index)
            if profile.legacy and store.list[1] then store.list[1].legacy = true end
            Changed()
            return true
        end
    end
    return false
end

function M.SetMember(id, character, on)
    local profile = M.Get(id)
    if not profile or type(character) ~= 'string' or character == '' then return false end
    if type(profile.chars) ~= 'table' then profile.chars = {} end
    profile.chars[character] = on and true or nil
    Changed()
    return true
end

-- What the report needs to count one profile; nil counts everything.
function M.Filter(id)
    local profile = M.Get(id)
    if not profile then return nil end
    return { chars = type(profile.chars) == 'table' and profile.chars or {}, legacy = profile.legacy == true }
end

-- The name shown for a profile member: without the realm on the player's own.
function M.DisplayName(character)
    local own = M.Current()
    local realm = own and own:match('^[^-]+%-(.+)$')
    local name, itsRealm = tostring(character):match('^([^-]+)%-(.+)$')
    if name and realm and itsRealm == realm then return name end
    return tostring(character)
end
