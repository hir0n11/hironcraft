local Scan = select(2, ...)

-- The chat filter: what the chat window leaves out. It only hides lines from
-- the chat frames; the scanner reads the chat events directly, so a request
-- is still caught when its line is hidden.
--
-- Player messages are checked against the rules (keys and expressions, see
-- FilterEngine) and the ignore list (IgnoreList). NPC speech is hidden by
-- kind (say, yell, emote, whisper), except in dungeons and raids if wished.
-- "X has come online / gone offline" is hidden for your own characters
-- (those of linked accounts too), guild members and friends.
--
-- Everything lives in HironCraftScan_DB.chat_filter, for the whole account:
-- it is read before the rest of the addon is set up, so lines that come
-- while logging in are filtered as well.
local F = {}
Scan.ChatFilter = F

local function L(key)
    return Scan.LOCAL and Scan.LOCAL:GetText(key) or key
end

local HISTORY_PER_RULE = 20
local LOG_SIZE = 200
local CACHE_SIZE = 64

local DEFAULTS = {
    enabled = true,
    rules_on = true,
    skip = { guild = true, party = false, whisper = true, self = false },
    npc = { say = true, yell = true, emote = true, whisper = false, keep_in_instances = true },
    presence = { own = true, guild = true, friends = true },
}

local function Fill(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == 'table' then
            if type(target[key]) ~= 'table' then target[key] = {} end
            Fill(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

-- The saved settings, or nil until the saved variables are loaded.
local prepared = nil
function F.DB()
    local root = rawget(_G, 'HironCraftScan_DB')
    if type(root) ~= 'table' then return nil end
    local db = root.chat_filter
    if type(db) ~= 'table' then
        db = {}
        root.chat_filter = db
    end
    if prepared ~= db then
        Fill(db, DEFAULTS)
        db.rules = type(db.rules) == 'table' and db.rules or {}
        db.log = type(db.log) == 'table' and db.log or {}
        db.npc_names = type(db.npc_names) == 'table' and db.npc_names or {}
        db.total = tonumber(db.total) or 0
        db.next_id = tonumber(db.next_id) or 1
        prepared = db
    end
    return db
end

local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

-- Rules ------------------------------------------------------------------------

local compiledRules = setmetatable({}, { __mode = 'k' })

-- The rule's test, or nil and the error; compiled once per text.
function F.Compiled(rule)
    local source = rule.expr or ((rule.whole and 'w:' or 'c:') .. tostring(rule.key))
    local cached = compiledRules[rule]
    if cached and cached.source == source then return cached.test, cached.error end
    local test, err
    if rule.expr then
        test, err = Scan.FilterEngine.Compile(rule.expr)
    else
        test, err = Scan.FilterEngine.CompileKey(rule.key, rule.whole)
    end
    compiledRules[rule] = { source = source, test = test, error = err }
    return test, err
end

function F.Rules()
    local db = F.DB()
    return db and db.rules or {}
end

function F.RuleByID(id)
    for index, rule in ipairs(F.Rules()) do
        if rule.id == id then return rule, index end
    end
    return nil
end

local changeListeners = {}
function F.OnChange(callback) changeListeners[#changeListeners + 1] = callback end
local function Changed()
    for _, callback in ipairs(changeListeners) do pcall(callback) end
end
F.Changed = Changed

local function NewID(db)
    local id = 'r' .. db.next_id
    db.next_id = db.next_id + 1
    return id
end

-- A key from the text selection tool or the window. False and a reason when
-- it cannot be added.
function F.AddKey(text, whole, name)
    local db = F.DB()
    if not db then return false, 'not_ready' end
    local plain = Scan.FilterEngine.PlainText(text)
    if plain == '' then return false, 'missing_text' end
    local lower = Scan.FilterEngine.Lower(plain)
    for _, rule in ipairs(db.rules) do
        if rule.key and Scan.FilterEngine.Lower(rule.key) == lower and (rule.whole == true) == (whole == true) then
            return false, 'duplicate_filter'
        end
    end
    local rule = { id = NewID(db), name = name or plain, key = plain, whole = whole and true or nil, on = true,
        count = 0, at = time() }
    db.rules[#db.rules + 1] = rule
    Changed()
    return true, rule
end

function F.AddExpression(expression, name)
    local db = F.DB()
    if not db then return false, 'not_ready' end
    local test, err = Scan.FilterEngine.Compile(expression)
    if not test then return false, err end
    local rule = { id = NewID(db), name = name or expression, expr = expression, on = true, count = 0, at = time() }
    db.rules[#db.rules + 1] = rule
    Changed()
    return true, rule
end

function F.RemoveRule(id)
    local db = F.DB()
    local _, index = F.RuleByID(id)
    if db and index then
        table.remove(db.rules, index)
        Changed()
        return true
    end
    return false
end

-- Where a message was said, for [channel=n] and [chname=name]: the channel's
-- number and name, or for other chat its kind (say, guild, whisper, ...).
local function Context(event, channelNumber, channelName)
    local number = tonumber(channelNumber) or 0
    local name = channelName
    if number == 0 or type(name) ~= 'string' or name == '' then
        name = event:match('^CHAT_MSG_(.+)$') or event
    end
    return { channelNumber = number, channelName = Scan.FilterEngine.Lower(name) }
end

-- The first rule on that matches, or nil.
function F.MatchRules(message, event, channelNumber, channelName)
    local db = F.DB()
    if not db or db.rules_on == false then return nil end
    local info, context
    for _, rule in ipairs(db.rules) do
        if rule.on then
            local test = F.Compiled(rule)
            if test then
                info = info or Scan.FilterEngine.Analyze(message)
                context = context or Context(event, channelNumber, channelName)
                local ok, hit = pcall(test, info, context)
                if ok and hit then return rule end
            end
        end
    end
    return nil
end

-- Presence notices -------------------------------------------------------------

local function BaseName(name)
    if type(name) ~= 'string' or name == '' then return nil end
    return Scan.FilterEngine.Lower(name:match('^([^-]+)') or name)
end
F.BaseName = BaseName

local function PatternOf(format)
    if type(format) ~= 'string' then return nil end
    local pattern = format:gsub('([%(%)%.%+%-%*%?%[%]%^%$])', '%%%1'):gsub('%%s', '(.-)')
    return '^' .. pattern .. '$'
end

-- The player a "has come online" or "has gone offline" notice is about.
function F.PresenceName(message)
    if type(message) ~= 'string' then return nil end
    local online = PatternOf(rawget(_G, 'ERR_FRIEND_ONLINE_SS') or '|Hplayer:%s|h[%s]|h has come online.')
    local offline = PatternOf(rawget(_G, 'ERR_FRIEND_OFFLINE_S') or '%s has gone offline.')
    local name = online and message:match(online)
    if name then return name, 'online' end
    name = offline and message:match(offline)
    if name then return name, 'offline' end
    return nil
end

local sets = { own = nil, guild = nil, friends = nil }
local ownBuiltAt = nil
local OWN_REFRESH_SECONDS = 60

local function Now() return GetTime and GetTime() or 0 end

-- Your characters on every realm, and those of linked accounts.
local function OwnCharacters()
    if sets.own and ownBuiltAt and Now() - ownBuiltAt < OWN_REFRESH_SECONDS then return sets.own end
    local own = {}
    local function Add(name) local base = BaseName(name) if base then own[base] = true end end
    Add(UnitName and UnitName('player'))
    local root = rawget(_G, 'HironCraftScan_DB')
    for _, realm in pairs(type(root) == 'table' and type(root.realms) == 'table' and root.realms or {}) do
        for name in pairs(type(realm) == 'table' and type(realm.characters) == 'table' and realm.characters or {}) do
            Add(name)
        end
        for _, account in pairs(type(realm) == 'table' and type(realm.linked_accounts) == 'table'
            and realm.linked_accounts or {}) do
            if type(account) == 'table' then
                for _, name in ipairs(type(account.backup_chars) == 'table' and account.backup_chars or {}) do Add(name) end
                for name in pairs(type(account.characters) == 'table' and account.characters or {}) do Add(name) end
                Add(account.last_active_char)
            end
        end
    end
    sets.own, ownBuiltAt = own, Now()
    return own
end

local function GuildMembers()
    if sets.guild then return sets.guild end
    local guild = {}
    if IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo then
        for index = 1, GetNumGuildMembers() or 0 do
            local name = GetGuildRosterInfo(index)
            local base = not IsSecret(name) and BaseName(name)
            if base then guild[base] = true end
        end
    end
    sets.guild = guild
    return guild
end

local function Friends()
    if sets.friends then return sets.friends end
    local friends = {}
    local list = C_FriendList
    if list and list.GetNumFriends and list.GetFriendInfoByIndex then
        for index = 1, list.GetNumFriends() or 0 do
            local info = list.GetFriendInfoByIndex(index)
            local base = info and not IsSecret(info.name) and BaseName(info.name)
            if base then friends[base] = true end
        end
    end
    sets.friends = friends
    return friends
end

function F.ForgetRosters(which)
    if which then sets[which] = nil else sets.guild, sets.friends, sets.own = nil, nil, nil end
end

-- Why a presence notice is hidden, or nil.
local function PresenceReason(db, message)
    local name = F.PresenceName(message)
    if not name then return nil end
    if Scan.ChatIgnore and Scan.ChatIgnore.IsIgnored(name) then return 'ignored' end
    local base = BaseName(name)
    if not base then return nil end
    if db.presence.own and OwnCharacters()[base] then return 'presence' end
    if db.presence.guild and GuildMembers()[base] then return 'presence' end
    if db.presence.friends and Friends()[base] then return 'presence' end
    return nil
end

-- What is hidden ---------------------------------------------------------------

local NPC_KINDS = {
    CHAT_MSG_MONSTER_SAY = 'say', CHAT_MSG_MONSTER_PARTY = 'say', CHAT_MSG_MONSTER_YELL = 'yell',
    CHAT_MSG_MONSTER_EMOTE = 'emote', CHAT_MSG_MONSTER_WHISPER = 'whisper',
}
local GUILD_EVENTS = { CHAT_MSG_GUILD = true, CHAT_MSG_OFFICER = true }
local GROUP_EVENTS = {
    CHAT_MSG_PARTY = true, CHAT_MSG_PARTY_LEADER = true, CHAT_MSG_RAID = true, CHAT_MSG_RAID_LEADER = true,
    CHAT_MSG_RAID_WARNING = true, CHAT_MSG_INSTANCE_CHAT = true, CHAT_MSG_INSTANCE_CHAT_LEADER = true,
}
-- Player lines the rules look at; the ignore list hides these and a few more.
local RULE_EVENTS = {
    CHAT_MSG_CHANNEL = true, CHAT_MSG_SAY = true, CHAT_MSG_YELL = true, CHAT_MSG_EMOTE = true,
    CHAT_MSG_TEXT_EMOTE = true, CHAT_MSG_WHISPER = true, CHAT_MSG_GUILD = true, CHAT_MSG_OFFICER = true,
    CHAT_MSG_PARTY = true, CHAT_MSG_PARTY_LEADER = true, CHAT_MSG_RAID = true, CHAT_MSG_RAID_LEADER = true,
    CHAT_MSG_RAID_WARNING = true, CHAT_MSG_INSTANCE_CHAT = true, CHAT_MSG_INSTANCE_CHAT_LEADER = true,
}
local IGNORE_ONLY_EVENTS = {
    CHAT_MSG_ACHIEVEMENT = true, CHAT_MSG_GUILD_ACHIEVEMENT = true, CHAT_MSG_CHANNEL_JOIN = true,
    CHAT_MSG_CHANNEL_LEAVE = true,
}

local function IsMe(author)
    local me = UnitName and UnitName('player')
    return me ~= nil and BaseName(author) == BaseName(me)
end

local function InInstance()
    if not IsInInstance then return false end
    local inside = IsInInstance()
    return inside == true
end

-- Why this line is hidden: nil, or a reason ('rule', 'ignored', 'npc',
-- 'presence', 'system') and the rule.
function F.Decide(event, message, author, channelNumber, channelName)
    local db = F.DB()
    if not db or db.enabled == false or type(message) ~= 'string' then return nil end
    if IsSecret(message) or IsSecret(author) then return nil end

    if event == 'CHAT_MSG_SYSTEM' then
        if Scan.ChatIgnore and Scan.ChatIgnore.HidesSystemNotice(message) then return 'system' end
        return PresenceReason(db, message)
    end

    local npcKind = NPC_KINDS[event]
    if npcKind then
        local base = BaseName(author)
        if base and db.npc_names[base] then return 'npc' end
        if db.npc[npcKind] and not (db.npc.keep_in_instances and InInstance()) then return 'npc' end
        return nil
    end

    if type(author) ~= 'string' or author == '' then return nil end
    if (RULE_EVENTS[event] or IGNORE_ONLY_EVENTS[event]) and Scan.ChatIgnore
        and Scan.ChatIgnore.IsIgnored(author) then
        return 'ignored'
    end
    if not RULE_EVENTS[event] then return nil end
    if db.skip.guild and GUILD_EVENTS[event] then return nil end
    if db.skip.party and GROUP_EVENTS[event] then return nil end
    if db.skip.whisper and event == 'CHAT_MSG_WHISPER' then return nil end
    if db.skip.self and IsMe(author) then return nil end
    local rule = F.MatchRules(message, event, channelNumber, channelName)
    if rule then return 'rule', rule end
    return nil
end

-- The journal ------------------------------------------------------------------

local function Push(list, entry, limit)
    list[#list + 1] = entry
    while #list > limit do table.remove(list, 1) end
end

local function Record(db, reason, rule, event, message, author, channelName)
    db.total = db.total + 1
    local entry = { t = time(), m = message, a = author, e = event, c = channelName ~= '' and channelName or nil,
        r = rule and rule.id or reason }
    if rule then
        rule.count = (tonumber(rule.count) or 0) + 1
        rule.history = type(rule.history) == 'table' and rule.history or {}
        Push(rule.history, entry, HISTORY_PER_RULE)
    end
    Push(db.log, entry, LOG_SIZE)
end

function F.ClearLog()
    local db = F.DB()
    if db then db.log = {} end
    Changed()
end

-- The chat hook ----------------------------------------------------------------

-- The game asks once per chat window that shows the event; the answer and
-- the counting are done once per line.
local cache, cacheOrder = {}, {}

local function Remember(key, value)
    if cache[key] == nil then
        cacheOrder[#cacheOrder + 1] = key
        if #cacheOrder > CACHE_SIZE then cache[table.remove(cacheOrder, 1)] = nil end
    end
    cache[key] = value
end

local function LineKey(lineID)
    if not IsSecret(lineID) and type(lineID) == 'number' and lineID > 0 then return lineID end
    return nil
end

local function Evaluate(event, message, author, channelNumber, channelName)
    local reason, rule = F.Decide(event, message, author, channelNumber, channelName)
    if not reason then return false end
    local db = F.DB()
    Record(db, reason, rule, event, message, author, channelName)
    if reason == 'ignored' and event == 'CHAT_MSG_WHISPER' and Scan.ChatIgnore then
        Scan.ChatIgnore.ReplyTo(author)
    end
    return true
end

function F.MessageFilter(_, event, message, author, ...)
    local ok, hide = pcall(function(...)
        local channelNumber, channelName, lineID = select(6, ...), select(7, ...), select(9, ...)
        if IsSecret(channelName) then channelName = nil end
        local key = LineKey(lineID)
        if key then
            local known = cache[key]
            if known ~= nil then return known end
        end
        local result = Evaluate(event, message, author, channelNumber, channelName)
        if key then Remember(key, result) end
        return result
    end, ...)
    return ok and hide or false
end

local EVENTS = { 'CHAT_MSG_SYSTEM' }
for event in pairs(NPC_KINDS) do EVENTS[#EVENTS + 1] = event end
for event in pairs(RULE_EVENTS) do EVENTS[#EVENTS + 1] = event end
for event in pairs(IGNORE_ONLY_EVENTS) do EVENTS[#EVENTS + 1] = event end
F.EVENTS = EVENTS

local AddFilter = rawget(_G, 'ChatFrame_AddMessageEventFilter')
    or (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)
if AddFilter then
    for _, event in ipairs(EVENTS) do AddFilter(event, F.MessageFilter) end
end
F.AddFilter = AddFilter

-- Rosters for the presence notices.
if CreateFrame then
    local watcher = CreateFrame('Frame')
    watcher:RegisterEvent('GUILD_ROSTER_UPDATE')
    watcher:RegisterEvent('FRIENDLIST_UPDATE')
    watcher:RegisterEvent('PLAYER_GUILD_UPDATE')
    watcher:RegisterEvent('PLAYER_ENTERING_WORLD')
    watcher:RegisterEvent('PLAYER_LOGIN')
    watcher:SetScript('OnEvent', function(_, event)
        if event == 'PLAYER_LOGIN' then
            F.TakeOverAtLogin()
        elseif event == 'PLAYER_ENTERING_WORLD' then
            -- The roster is not there until asked for.
            if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
        elseif event == 'FRIENDLIST_UPDATE' then
            F.ForgetRosters('friends')
        else
            F.ForgetRosters('guild')
        end
    end)
end

-- Global Ignore List ------------------------------------------------------------

function F.GILLoaded()
    local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    return isLoaded ~= nil and isLoaded('GlobalIgnoreList') == true
end

-- "2026.09.27 01:25:04" and "14 Apr 2026" as times.
local MONTHS = { jan = 1, feb = 2, mar = 3, apr = 4, may = 5, jun = 6, jul = 7, aug = 8, sep = 9, oct = 10,
    nov = 11, dec = 12 }
function F.ParseGILDate(text)
    if type(text) ~= 'string' then return nil end
    local year, month, day, hour, min, sec = text:match('^(%d+)%.(%d+)%.(%d+) (%d+):(%d+):(%d+)$')
    if year then
        return time({ year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = tonumber(hour),
            min = tonumber(min), sec = tonumber(sec) })
    end
    local d, monthName, y = text:match('^(%d+) (%a+) (%d+)$')
    local m = monthName and MONTHS[monthName:lower():sub(1, 3)]
    if m then return time({ year = tonumber(y), month = m, day = tonumber(d), hour = 12 }) end
    return nil
end

-- Global Ignore List's filters, ignore list and options, taken over once.
-- Filters already here (by their GIL ID or text) are not added again.
function F.ImportGIL(source)
    source = source or rawget(_G, 'GlobalIgnoreDB')
    local db = F.DB()
    if not db then return nil, 'not_ready' end
    if type(source) ~= 'table' then return nil, 'no_gil' end
    local result = { rules = 0, players = 0, npcs = 0, servers = 0 }
    local known = {}
    for _, rule in ipairs(db.rules) do
        if rule.gil then known[rule.gil] = true end
        if rule.expr then known[rule.expr] = true end
    end
    local list = type(source.filterList) == 'table' and source.filterList or {}
    for index, expression in ipairs(list) do
        local gilID = type(source.filterID) == 'table' and source.filterID[index] or nil
        if gilID == '' then gilID = nil end
        if type(expression) == 'string' and not known[expression] and not (gilID and known[gilID]) then
            local history = {}
            local blocked = type(source.filterBlocked) == 'table' and source.filterBlocked[index]
            for _, entry in ipairs(type(blocked) == 'table' and blocked or {}) do
                if type(entry) == 'table' and type(entry.m) == 'string' then
                    history[#history + 1] = { t = F.ParseGILDate(entry.t), m = entry.m, a = entry.s, c = entry.n,
                        r = 'imported' }
                end
            end
            while #history > HISTORY_PER_RULE do table.remove(history, 1) end
            db.rules[#db.rules + 1] = {
                id = NewID(db),
                name = type(source.filterDesc) == 'table' and source.filterDesc[index] or expression,
                expr = expression,
                on = type(source.filterActive) == 'table' and source.filterActive[index] == true,
                count = type(source.filterCount) == 'table' and tonumber(source.filterCount[index]) or 0,
                history = history,
                gil = gilID,
                at = time(),
            }
            result.rules = result.rules + 1
        end
    end
    if Scan.ChatIgnore then
        local names = type(source.ignoreList) == 'table' and source.ignoreList or {}
        for index, name in ipairs(names) do
            local kind = type(source.typeList) == 'table' and source.typeList[index] or 'player'
            local note = type(source.notes) == 'table' and source.notes[index] or nil
            local at = type(source.dateList) == 'table' and F.ParseGILDate(source.dateList[index]) or nil
            if kind == 'npc' then
                local base = BaseName(name)
                if base and not db.npc_names[base] then
                    db.npc_names[base] = name
                    result.npcs = result.npcs + 1
                end
            elseif kind == 'server' then
                if Scan.ChatIgnore.AddServer(name) then result.servers = result.servers + 1 end
            elseif Scan.ChatIgnore.Add(name, { note = note ~= '' and note or nil, at = at, source = 'gil',
                quiet = true }) then
                result.players = result.players + 1
            end
        end
        local ignore = Scan.ChatIgnore.Settings()
        if ignore then
            if source.ignoreResponse ~= nil then ignore.reply = source.ignoreResponse == true end
            if source.showWarning ~= nil then ignore.warn = source.showWarning == true end
            if source.sameserver ~= nil then ignore.same_realm = source.sameserver == true end
        end
    end
    if source.spamFilter ~= nil then db.rules_on = source.spamFilter == true end
    if source.skipGuild ~= nil then db.skip.guild = source.skipGuild == true end
    if source.skipParty ~= nil then db.skip.party = source.skipParty == true end
    if source.skipPrivate ~= nil then db.skip.whisper = source.skipPrivate == true end
    if source.skipYourself ~= nil then db.skip.self = source.skipYourself == true end
    db.total = db.total + (tonumber(source.filterTotal) or 0)
    db.gil_imported = time()
    Changed()
    return result
end

local function Notice(text)
    local chat = rawget(_G, 'DEFAULT_CHAT_FRAME')
    if chat then chat:AddMessage('|cffffd200HironCraft:|r ' .. text) end
end

-- Global Ignore List's data can only be read while it is on. So when it is
-- on and nothing was taken over yet, that happens at login by itself; when
-- it is already off and the filter has no rules, say how to get them.
function F.TakeOverAtLogin()
    local db = F.DB()
    if not db or db.gil_imported then return nil end
    if F.GILLoaded() and type(rawget(_G, 'GlobalIgnoreDB')) == 'table' then
        local result = F.ImportGIL()
        if result then
            Notice(string.format(L('Global Ignore List taken over: %d rules, %d players. It can be turned off now (/hcfilter).'),
                result.rules, result.players))
        end
        return result
    end
    if #db.rules == 0 then
        Notice(L('The chat filter has no rules yet. Turn Global Ignore List on for one login: its filters and ignore list are taken over by themselves.'))
    end
    return nil
end

-- Opening the window: /hcfilter, /hcf.
SLASH_HIRONCRAFTCHATFILTER1 = '/hcfilter'
SLASH_HIRONCRAFTCHATFILTER2 = '/hcf'
SlashCmdList = SlashCmdList or {}
SlashCmdList.HIRONCRAFTCHATFILTER = function()
    if Scan.ChatFilterWindow then Scan.ChatFilterWindow.Toggle() end
end
