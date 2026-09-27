local Scan = select(2, ...)

-- The ignore list for the whole account, without the game's limit of 50.
-- Everyone on it is hidden from the chat (ChatFilter asks IsIgnored); the
-- game's own list of each character is filled from it as far as it goes,
-- most recently ignored first, which also stops their invitations and trades
-- at the server. Ignoring or unignoring through the game (the chat menu,
-- /ignore, the friends window) changes this list too, and a player taken off
-- here is taken off the other characters' lists when they log in.
--
-- On top of that, as Global Ignore List did: an answer to their whispers,
-- their group and guild invitations, duels and trades declined, a warning
-- when one of them is in your group, and their groups marked in the group
-- finder.
local I = {}
Scan.ChatIgnore = I

local function L(key)
    return Scan.LOCAL and Scan.LOCAL:GetText(key) or key
end

local BLIZZARD_LIMIT = 50
local REPLY_EVERY_SECONDS = 5 * 60
local REMOVED_KEPT_SECONDS = 90 * 24 * 60 * 60
local NOTICE_SECONDS = 10
-- A player the game failed to find this often (renamed, deleted, banned) is
-- no longer put on its list; the chat still hides them by name.
local GAME_MISSES_LIMIT = 2

local DEFAULTS = { reply = false, decline = true, warn = true, lfg = true, blizzard = true, same_realm = true }

local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

local function Now() return GetTime and GetTime() or 0 end

local function Notice(text)
    local chat = rawget(_G, 'DEFAULT_CHAT_FRAME')
    if chat then chat:AddMessage('|cffffd200HironCraft:|r ' .. text) end
end

local prepared = nil
function I.Settings()
    local db = Scan.ChatFilter and Scan.ChatFilter.DB()
    if not db then return nil end
    local ignore = db.ignore
    if type(ignore) ~= 'table' then
        ignore = {}
        db.ignore = ignore
    end
    if prepared ~= ignore then
        for key, value in pairs(DEFAULTS) do
            if ignore[key] == nil then ignore[key] = value end
        end
        ignore.players = type(ignore.players) == 'table' and ignore.players or {}
        ignore.servers = type(ignore.servers) == 'table' and ignore.servers or {}
        ignore.removed = type(ignore.removed) == 'table' and ignore.removed or {}
        local now = time()
        for key, at in pairs(ignore.removed) do
            if type(at) ~= 'number' or now - at > REMOVED_KEPT_SECONDS then ignore.removed[key] = nil end
        end
        prepared = ignore
    end
    return ignore
end

local function MyRealm()
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    if type(realm) ~= 'string' or realm == '' then realm = GetRealmName and GetRealmName() or '' end
    return (tostring(realm):gsub('%s', ''))
end

-- "Name-Realm", the player's realm when none is given.
function I.FullName(name)
    if IsSecret(name) or type(name) ~= 'string' then return nil end
    name = name:gsub('%s', '')
    if name == '' then return nil end
    local base, realm = name:match('^([^-]+)-(.+)$')
    if not base then base, realm = name, MyRealm() end
    if realm == '' then return base end
    return base .. '-' .. realm
end

function I.Key(name)
    local full = I.FullName(name)
    return full and Scan.FilterEngine.Lower(full) or nil
end

local function RealmOf(key)
    return key and key:match('%-(.+)$')
end

function I.IsIgnored(name)
    local ignore = I.Settings()
    local key = ignore and I.Key(name)
    if not key then return false end
    if ignore.players[key] then return true end
    local realm = RealmOf(key)
    return realm ~= nil and ignore.servers[realm] ~= nil
end

function I.Entry(name)
    local ignore = I.Settings()
    local key = ignore and I.Key(name)
    return key and ignore.players[key] or nil
end

-- The list, most recently ignored first.
function I.List()
    local ignore = I.Settings()
    local list = {}
    for key, entry in pairs(ignore and ignore.players or {}) do
        if type(entry) == 'table' then
            entry.key = key
            list[#list + 1] = entry
        end
    end
    table.sort(list, function(lhs, rhs)
        if (lhs.at or 0) ~= (rhs.at or 0) then return (lhs.at or 0) > (rhs.at or 0) end
        return lhs.key < rhs.key
    end)
    return list
end

function I.Count()
    return #I.List()
end

-- The game's list ---------------------------------------------------------------

-- What the game's list held when it last changed: keys to names, and keys by
-- position (for an unignore by position).
local snapshot = { keys = {}, byIndex = {}, count = 0, valid = false }
local syncing = false
-- Players whose "now ignored" / "no longer ignored" line we caused.
local expected = {}

local function ReadGameList()
    local list = C_FriendList
    if not list or not list.GetNumIgnores then return nil end
    local keys, byIndex, count = {}, {}, 0
    for index = 1, list.GetNumIgnores() or 0 do
        local name = list.GetIgnoreName(index)
        -- Right after logging in the game may still call everyone "Unknown".
        if IsSecret(name) or type(name) ~= 'string' or name == '' or name == rawget(_G, 'UNKNOWN')
            or name == rawget(_G, 'UNKNOWNOBJECT') then
            return nil
        end
        local key = I.Key(name)
        if key then
            keys[key] = name
            byIndex[index] = key
            count = count + 1
        end
    end
    return keys, byIndex, count
end

local function TakeSnapshot()
    local keys, byIndex, count = ReadGameList()
    if keys then
        snapshot.keys, snapshot.byIndex, snapshot.count, snapshot.valid = keys, byIndex, count, true
    end
    return keys ~= nil
end

function I.GameListCount()
    return snapshot.valid and snapshot.count or nil
end

-- When we last asked the game to change its list: its "Player not found."
-- names nobody, so any that comes right after is taken for ours.
local lastGameCall = nil

local function Game(action, name)
    local call = C_FriendList and C_FriendList[action]
    if not call then return false end
    local key = I.Key(name)
    if key then expected[key] = Now() + NOTICE_SECONDS end
    lastGameCall = Now()
    syncing = true
    local ok = pcall(call, name)
    syncing = false
    return ok
end

-- On the game's list if it has room: only players of this realm when so set.
local function FitsGameList(ignore, key)
    if not ignore.blizzard or not snapshot.valid or snapshot.keys[key] then return false end
    if snapshot.count >= BLIZZARD_LIMIT then return false end
    local entry = ignore.players[key]
    if entry and (tonumber(entry.game_misses) or 0) >= GAME_MISSES_LIMIT then return false end
    if ignore.same_realm and RealmOf(key) ~= Scan.FilterEngine.Lower(MyRealm()) then return false end
    return true
end

-- The game's "is now being ignored" and similar lines we caused, and "your
-- ignore list is full" (the rest is on this list).
local function PatternOf(format)
    if type(format) ~= 'string' then return nil end
    return '^' .. format:gsub('([%(%)%.%+%-%*%?%[%]%^%$])', '%%%1'):gsub('%%s', '(.-)') .. '$'
end

function I.HidesSystemNotice(message)
    local ignore = I.Settings()
    if not ignore then return false end
    if message == rawget(_G, 'ERR_IGNORE_FULL') then return true end
    if lastGameCall and Now() - lastGameCall <= NOTICE_SECONDS
        and (message == rawget(_G, 'ERR_IGNORE_NOT_FOUND') or message == rawget(_G, 'ERR_FRIEND_NOT_FOUND')) then
        return true
    end
    for _, global in ipairs({ 'ERR_IGNORE_ADDED_S', 'ERR_IGNORE_REMOVED_S', 'ERR_IGNORE_ALREADY_S' }) do
        local pattern = PatternOf(rawget(_G, global))
        local name = pattern and message:match(pattern)
        local key = name and I.Key(name)
        if key and expected[key] and expected[key] >= Now() then return true end
    end
    return false
end

-- Changing the list -------------------------------------------------------------

-- options: note, at, source ('gil', 'game', 'window', 'menu'), quiet, fromGame.
-- True when the player was not on the list yet.
function I.Add(name, options)
    options = options or {}
    local ignore = I.Settings()
    local full = ignore and I.FullName(name)
    if not full then return false end
    local key = Scan.FilterEngine.Lower(full)
    ignore.removed[key] = nil
    local isNew = ignore.players[key] == nil
    if isNew then
        ignore.players[key] = { name = full, at = options.at or time(), note = options.note,
            source = options.source }
    else
        local entry = ignore.players[key]
        if options.note and not entry.note then entry.note = options.note end
        -- Taken from the game's list at login before Global Ignore List was
        -- taken over: its date is the real one.
        if options.source == 'gil' and entry.source == 'game' and options.at then
            entry.at, entry.source = options.at, 'gil'
        end
    end
    if not options.fromGame and FitsGameList(ignore, key) then Game('AddIgnore', full) end
    if isNew and not options.quiet then Notice(string.format(L('%s is on your ignore list now.'), full)) end
    if Scan.ChatFilter then Scan.ChatFilter.Changed() end
    return isNew
end

function I.Remove(name, options)
    options = options or {}
    local ignore = I.Settings()
    local key = ignore and I.Key(name)
    if not key or not ignore.players[key] then return false end
    local full = ignore.players[key].name or name
    ignore.players[key] = nil
    ignore.removed[key] = time()
    if not options.fromGame and snapshot.keys[key] then Game('DelIgnore', snapshot.keys[key]) end
    if not options.quiet then Notice(string.format(L('%s is off your ignore list.'), full)) end
    if Scan.ChatFilter then Scan.ChatFilter.Changed() end
    return true
end

function I.AddServer(realm)
    local ignore = I.Settings()
    if not ignore or type(realm) ~= 'string' or realm == '' then return false end
    local key = Scan.FilterEngine.Lower((realm:gsub('%s', '')))
    if ignore.servers[key] then return false end
    ignore.servers[key] = realm
    return true
end

function I.Toggle(name)
    if I.IsIgnored(name) then return I.Remove(name) end
    return I.Add(name, { source = 'menu' })
end

-- Bringing the game's list in line: what was ignored there elsewhere is taken
-- in, what was unignored here is taken off, and free places are filled.
function I.Sync()
    local ignore = I.Settings()
    if not ignore or not ignore.blizzard then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    if not TakeSnapshot() then return false end
    for key, name in pairs(snapshot.keys) do
        if not ignore.players[key] then
            if ignore.removed[key] then
                Game('DelIgnore', name)
                snapshot.keys[key] = nil
                snapshot.count = snapshot.count - 1
            else
                I.Add(name, { source = 'game', fromGame = true, quiet = true })
            end
        end
    end
    local tried = {}
    for _, entry in ipairs(I.List()) do
        if snapshot.count >= BLIZZARD_LIMIT then break end
        if FitsGameList(ignore, entry.key) then
            Game('AddIgnore', entry.name)
            tried[entry.key] = true
            snapshot.keys[entry.key] = entry.name
            snapshot.count = snapshot.count + 1
        end
    end
    -- A little later: whoever the game did not take was not found by it.
    if next(tried) and C_Timer then
        C_Timer.After(NOTICE_SECONDS, function()
            if not TakeSnapshot() then return end
            for key in pairs(tried) do
                local entry = ignore.players[key]
                if entry then
                    entry.game_misses = not snapshot.keys[key] and (tonumber(entry.game_misses) or 0) + 1 or nil
                end
            end
        end)
    end
    return true
end

-- Ignoring through the game changes this list too.
local function FromGame(add, name)
    if syncing or IsSecret(name) or type(name) ~= 'string' then return end
    local ignore = I.Settings()
    if not ignore then return end
    if add then
        I.Add(name, { source = 'game', fromGame = true, quiet = snapshot.count < BLIZZARD_LIMIT })
    else
        I.Remove(name, { fromGame = true, quiet = true })
    end
end

if hooksecurefunc and C_FriendList then
    if C_FriendList.AddIgnore then
        hooksecurefunc(C_FriendList, 'AddIgnore', function(name) FromGame(true, name) end)
    end
    if C_FriendList.DelIgnore then
        hooksecurefunc(C_FriendList, 'DelIgnore', function(name) FromGame(false, name) end)
    end
    if C_FriendList.AddOrDelIgnore then
        hooksecurefunc(C_FriendList, 'AddOrDelIgnore', function(name)
            local key = not IsSecret(name) and I.Key(name)
            FromGame(not (key and snapshot.keys[key]), name)
        end)
    end
    if C_FriendList.DelIgnoreByIndex then
        hooksecurefunc(C_FriendList, 'DelIgnoreByIndex', function(index)
            local key = snapshot.byIndex[index]
            if key then FromGame(false, snapshot.keys[key]) end
        end)
    end
end

-- Their whispers ----------------------------------------------------------------

local replied = {}

function I.ReplyText()
    return L('You are being ignored.')
end

-- Once in a while per player, never back to the game's own list (the game
-- does not pass their whispers on).
function I.ReplyTo(author)
    local ignore = I.Settings()
    if not ignore or not ignore.reply then return false end
    local key = I.Key(author)
    if not key then return false end
    local now = Now()
    if replied[key] and now - replied[key].at < REPLY_EVERY_SECONDS then return false end
    if Scan.Utils and Scan.Utils.CanSendMessages and not Scan.Utils.CanSendMessages() then return false end
    replied[key] = { at = now }
    local send = rawget(_G, 'SendChatMessage')
    if not send then return false end
    return (pcall(send, I.ReplyText(), 'WHISPER', nil, author))
end

-- Our own answer is not shown back in the chat.
function I.HidesOwnReply(message, target)
    local key = I.Key(target)
    local sent = key and replied[key]
    return sent ~= nil and message == I.ReplyText() and Now() - sent.at < NOTICE_SECONDS
end

local AddFilter = rawget(_G, 'ChatFrame_AddMessageEventFilter')
    or (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)
if AddFilter then
    AddFilter('CHAT_MSG_WHISPER_INFORM', function(_, _, message, target)
        if IsSecret(message) or IsSecret(target) then return false end
        return I.HidesOwnReply(message, target)
    end)
end

-- Invitations, duels, trades, groups ---------------------------------------------

local warned = {}

local function Declined(format, name)
    Notice(string.format(L(format), name))
end

local function CheckGroup()
    local ignore = I.Settings()
    if not ignore or not ignore.warn then return end
    if not (IsInGroup and IsInGroup()) then
        warned = {}
        return
    end
    local prefix = IsInRaid and IsInRaid() and 'raid' or 'party'
    local found = {}
    for index = 1, GetNumGroupMembers and GetNumGroupMembers() or 0 do
        local name = GetUnitName and GetUnitName(prefix .. index, true)
        local key = not IsSecret(name) and I.Key(name)
        if key and I.IsIgnored(name) and not warned[key] then
            warned[key] = true
            found[#found + 1] = name
        end
    end
    if #found > 0 then
        local names = table.concat(found, ', ')
        Notice(string.format(L('In your group, on your ignore list: %s'), names))
        if StaticPopup_Show and StaticPopupDialogs then
            StaticPopupDialogs.HIRONCRAFT_IGNORED_IN_GROUP = StaticPopupDialogs.HIRONCRAFT_IGNORED_IN_GROUP or {
                text = L('In your group, on your ignore list:\n%s'),
                button1 = rawget(_G, 'OKAY') or 'OK',
                timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
            }
            StaticPopup_Show('HIRONCRAFT_IGNORED_IN_GROUP', names)
        end
    end
end

local function OnRequest(event, name)
    local ignore = I.Settings()
    if not ignore or not ignore.decline or IsSecret(name) or not I.IsIgnored(name) then return end
    if event == 'PARTY_INVITE_REQUEST' then
        if DeclineGroup then pcall(DeclineGroup) end
        if StaticPopup_Hide then StaticPopup_Hide('PARTY_INVITE') end
        Declined('Declined a group invitation from %s (ignored).', name)
    elseif event == 'GUILD_INVITE_REQUEST' then
        if DeclineGuild then pcall(DeclineGuild) end
        if StaticPopup_Hide then StaticPopup_Hide('GUILD_INVITE') end
        Declined('Declined a guild invitation from %s (ignored).', name)
    elseif event == 'DUEL_REQUESTED' then
        if CancelDuel then pcall(CancelDuel) end
        if StaticPopup_Hide then StaticPopup_Hide('DUEL_REQUESTED') end
        Declined('Declined a duel from %s (ignored).', name)
    elseif event == 'TRADE_REQUEST' then
        if CancelTrade then pcall(CancelTrade) end
        Declined('Declined a trade from %s (ignored).', name)
    end
end

-- The group finder: groups led by someone on the list are marked, and the
-- leader can be ignored from the entry's menu.
local lfgHooked = false
local function HookGroupFinder()
    if lfgHooked or not hooksecurefunc then return end
    if not (rawget(_G, 'LFGListSearchEntry_Update') and C_LFGList and C_LFGList.GetSearchResultInfo) then return end
    lfgHooked = true
    local function Leader(entry)
        local info = entry and entry.resultID and C_LFGList.GetSearchResultInfo(entry.resultID)
        local leader = info and info.leaderName
        if IsSecret(leader) or type(leader) ~= 'string' or leader == '' then return nil end
        return leader
    end
    hooksecurefunc('LFGListSearchEntry_Update', function(entry)
        local ignore = I.Settings()
        local leader = ignore and ignore.lfg and Leader(entry)
        if leader and I.IsIgnored(leader) and entry.Name then
            entry.Name:SetTextColor(1, 0.25, 0.25)
        end
    end)
    if rawget(_G, 'LFGListSearchEntry_OnEnter') then
        hooksecurefunc('LFGListSearchEntry_OnEnter', function(entry)
            local ignore = I.Settings()
            local leader = ignore and ignore.lfg and Leader(entry)
            if leader and I.IsIgnored(leader) and GameTooltip then
                GameTooltip:AddLine(' ')
                GameTooltip:AddLine(L('The leader is on your ignore list.'), 1, 0.25, 0.25)
                GameTooltip:Show()
            end
        end)
    end
    if Menu and Menu.ModifyMenu then
        Menu.ModifyMenu('MENU_LFG_FRAME_SEARCH_ENTRY', function(owner, root)
            local leader = Leader(owner)
            if not leader then return end
            root:CreateDivider()
            root:CreateButton(I.IsIgnored(leader) and L('Remove the leader from the ignore list')
                or L('Ignore the leader'), function() I.Toggle(leader) end)
        end)
    end
end

-- Players' own menus (target, party and raid frames).
local function HookUnitMenus()
    if not (Menu and Menu.ModifyMenu) then return end
    local function Add(_, root, context)
        local unit = context and context.unit
        if not unit or not UnitIsPlayer or not UnitIsPlayer(unit) or (UnitIsUnit and UnitIsUnit(unit, 'player')) then
            return
        end
        local name, realm = UnitName(unit)
        if IsSecret(name) or IsSecret(realm) or type(name) ~= 'string' then return end
        local full = (realm and realm ~= '') and (name .. '-' .. realm) or name
        root:CreateDivider()
        root:CreateButton(I.IsIgnored(full) and L('Remove from the ignore list (HironCraft)')
            or L('Ignore (HironCraft)'), function() I.Toggle(full) end)
    end
    for _, tag in ipairs({ 'MENU_UNIT_PLAYER', 'MENU_UNIT_ENEMY_PLAYER', 'MENU_UNIT_PARTY', 'MENU_UNIT_RAID_PLAYER' }) do
        Menu.ModifyMenu(tag, Add)
    end
end

local synced = false
if CreateFrame then
    local watcher = CreateFrame('Frame')
    for _, event in ipairs({ 'PLAYER_LOGIN', 'PLAYER_ENTERING_WORLD', 'IGNORELIST_UPDATE', 'GROUP_ROSTER_UPDATE',
        'PARTY_INVITE_REQUEST', 'GUILD_INVITE_REQUEST', 'DUEL_REQUESTED', 'TRADE_REQUEST', 'ADDON_LOADED' }) do
        pcall(watcher.RegisterEvent, watcher, event)
    end
    watcher:SetScript('OnEvent', function(_, event, arg1)
        if event == 'PLAYER_LOGIN' then
            HookUnitMenus()
            HookGroupFinder()
        elseif event == 'ADDON_LOADED' then
            HookGroupFinder()
        elseif event == 'IGNORELIST_UPDATE' or event == 'PLAYER_ENTERING_WORLD' then
            TakeSnapshot()
            if not synced and C_Timer then
                -- Once per session, when the game's list reads properly.
                C_Timer.After(3, function()
                    if not synced and I.Sync() then synced = true end
                end)
            end
        elseif event == 'GROUP_ROSTER_UPDATE' then
            CheckGroup()
        else
            OnRequest(event, arg1)
        end
    end)
end
