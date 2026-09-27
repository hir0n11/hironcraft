-- The chat filter that replaces Global Ignore List: its expressions, the
-- taking over of GIL's filters and ignore list, the rules, NPC speech,
-- online/offline notices, the ignore list and the game's own list.
local clock, now = 1000, 1790000000
function GetTime() return clock end
function time(t) if t then return os.time(t) end return now end
date = os.date
strmatch = string.match
function UnitName() return 'Mavu' end
function GetNormalizedRealmName() return 'Kazzak' end
local inInstance = false
function IsInInstance() return inInstance end
ERR_FRIEND_ONLINE_SS = '|Hplayer:%s|h[%s]|h has come online.'
ERR_FRIEND_OFFLINE_S = '%s has gone offline.'
ERR_IGNORE_FULL = 'Your ignore list is full.'
ERR_IGNORE_ADDED_S = '%s is now being ignored.'
ERR_IGNORE_REMOVED_S = '%s is no longer being ignored.'
ERR_IGNORE_NOT_FOUND = 'Player not found.'
DUEL_WINNER_KNOCKOUT = '%1$s has defeated %2$s in a duel'
DUEL_WINNER_RETREAT = '%2$s has fled from %1$s in a duel'
UNKNOWN = 'Unknown'

-- Frames, timers and the chat hook.
local frames, filters, timers = {}, {}, {}
function CreateFrame()
    local f = { events = {} }
    function f:RegisterEvent(event) self.events[event] = true end
    function f:SetScript(_, fn) self.handler = fn end
    frames[#frames + 1] = f
    return f
end
local function Fire(event, ...)
    for _, f in ipairs(frames) do
        if f.events[event] and f.handler then f.handler(f, event, ...) end
    end
end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function RunTimers() local list = timers; timers = {}; for _, fn in ipairs(list) do fn() end end
function ChatFrame_AddMessageEventFilter(event, fn)
    filters[event] = filters[event] or {}
    table.insert(filters[event], fn)
end
-- What the chat window would do: a line is shown unless a filter says no;
-- the game asks once per chat window.
local lineID = 0
local function Shown(event, message, author, channelNumber, channelName, windows)
    lineID = lineID + 1
    local shown = true
    for _ = 1, windows or 1 do
        for _, fn in ipairs(filters[event] or {}) do
            if fn(nil, event, message, author or '', '', '', '', '', 0, channelNumber or 0, channelName or '', 0,
                lineID, '') then
                shown = false
            end
        end
    end
    return shown
end
function hooksecurefunc(tbl, name, fn)
    if type(tbl) == 'string' then tbl, name, fn = _G, tbl, name end
    local original = tbl[name]
    tbl[name] = function(...)
        local results = { original(...) }
        fn(...)
        return unpack(results)
    end
end

-- The game's ignore list.
local gameList = { 'Oldspam', 'Forgiven' }
local addCalls = {}
local function IndexOf(name)
    for index, entry in ipairs(gameList) do if entry:lower() == name:lower() then return index end end
end
C_FriendList = {
    GetNumIgnores = function() return #gameList end,
    GetIgnoreName = function(index) return gameList[index] end,
    AddIgnore = function(name)
        addCalls[name] = (addCalls[name] or 0) + 1
        -- Gone was renamed: the game does not find them.
        if name:match('^Gone') then return end
        if #gameList < 50 and not IndexOf(name) then gameList[#gameList + 1] = (name:gsub('%-Kazzak$', '')) end
    end,
    DelIgnore = function(name)
        local index = IndexOf((name:gsub('%-Kazzak$', '')))
        if index then table.remove(gameList, index) end
    end,
    DelIgnoreByIndex = function(index) table.remove(gameList, index) end,
    AddOrDelIgnore = function(name)
        if IndexOf((name:gsub('%-Kazzak$', ''))) then C_FriendList.DelIgnore(name) else C_FriendList.AddIgnore(name) end
    end,
    GetNumFriends = function() return 1 end,
    GetFriendInfoByIndex = function() return { name = 'Buddy' } end,
}
function IsInGuild() return true end
function GetNumGuildMembers() return 1 end
function GetGuildRosterInfo() return 'Guildie-Kazzak' end
local sent, declined = {}, {}
function SendChatMessage(text, kind, _, target) sent[#sent + 1] = { text = text, kind = kind, target = target } end
function DeclineGroup() declined[#declined + 1] = 'group' end
function StaticPopup_Hide() end
local printed = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) printed[#printed + 1] = text end }

HironCraftScan_DB = {
    realms = { r1 = {
        characters = { ['Favu-Kazzak'] = {} },
        linked_accounts = { laptop = { backup_chars = { 'Laptopmin-Kazzak' } } },
    } },
}
local Scan = { LOCAL = { GetText = function(_, key) return key end }, Utils = {} }
local function load(path) assert(loadfile(path))('HironCraft', Scan) end
load('ChatFilter/FilterEngine.lua')
load('ChatFilter/ChatFilter.lua')
load('ChatFilter/IgnoreList.lua')
local E, F, I = Scan.FilterEngine, Scan.ChatFilter, Scan.ChatIgnore

-- The engine ------------------------------------------------------------------
assert(E.Lower('WTS Продам ЁЖИК') == 'wts продам ёжик', 'Cyrillic is not lowered: ' .. E.Lower('WTS Продам ЁЖИК'))
local info = E.Analyze('WTS |cnIQ4:|Hitem:19019::::|h[Thunderfury]|h|r {rt1}{skull} cheap!')
assert(info.items[1] == '19019' and info.icons == 2 and info.links == 1, 'the message was read wrong')
assert(info.words[1] == 'wts' and info.words[2] == 'cheap' and #info.words == 2, 'words: ' .. table.concat(info.words, ' '))
assert(not info.text:find('thunderfury', 1, true) and info.plain:find('thunderfury', 1, true),
    'item names belong to keys, not to expressions')
-- "or" binds tighter than "and", as in Global Ignore List.
local test = assert(E.Compile('[word=a] [word=b] or [word=c]'))
assert(test(E.Analyze('a c'), {}) and not test(E.Analyze('c'), {}), 'the precedence differs from GIL')
assert(assert(E.Compile('not ([word=x])'))(E.Analyze('y'), {}), 'not does not work')
assert(assert(E.Compile('[contains=gold\\ only]'))(E.Analyze('for GOLD ONLY'), {}), 'an escaped space is lost')
assert(assert(E.Compile('[chname=trade\\ -\\ city]'))(E.Analyze('x'), { channelName = 'trade - city' }), 'chname')
assert(not E.Compile('[word=a] and ('), 'an unbalanced expression was accepted')
assert(not E.Compile('[bogus=1]'), 'an unknown tag was accepted')
assert(assert(E.CompileKey('wts', true))(E.Analyze('WTS boost')) and not E.CompileKey('wts', true)(E.Analyze('wtsx')),
    'a whole-word key is off')

-- Taking over Global Ignore List ----------------------------------------------
local gil = {
    filterList = {
        '([word=anal] or [contains=analan]) and ([link] or [words=2])',
        '([contains=WTS] or [contains=sell]) and ([contains=m+] or [contains=boost] or [journal])',
        '(([guild] or ([contains=<] and [contains=>])) and ([contains=recruit] or [contains=guild])) or ([contains=guild] and [contains=recruit])',
        '[nonlatin]',
    },
    filterDesc = { 'Anal', 'M+ sellers', 'Guild recruitment', 'CJK' },
    filterID = { 'GIL0001', 'GIL0003', 'GIL0008', 'GIL0011' },
    filterActive = { true, true, true, false },
    filterCount = { 1, 49688, 901188, 0 },
    filterBlocked = { [2] = { { m = 'WTS m+ boost', t = '2026.09.27 01:25:04', s = 'Seller-Kazzak', n = 'Trade - City' } } },
    ignoreList = { 'Goodgirl-Kazzak', 'Spammer-Kazzak', 'Forgiven-Kazzak' },
    typeList = { 'player', 'player', 'player' },
    dateList = { '14 Apr 2026', '15 Apr 2026', '16 Apr 2026' },
    notes = { '', 'gold seller', '' },
    ignoreResponse = true, showWarning = true, sameserver = true,
    spamFilter = true, skipGuild = true, skipParty = false, skipPrivate = true, skipYourself = false,
    filterTotal = 1030662,
}
local result = assert(F.ImportGIL(gil))
assert(result.rules == 4 and result.players == 3, 'import: ' .. result.rules .. ' rules, ' .. result.players .. ' players')
assert(F.Rules()[2].count == 49688 and F.Rules()[2].on and not F.Rules()[4].on and #F.Rules()[2].history == 1,
    'the filters lost their state')
assert(I.IsIgnored('Spammer') and I.IsIgnored('spammer-kazzak') and I.Entry('Spammer').note == 'gold seller',
    'the ignore list was not taken over')
assert(I.Settings().reply == true and F.DB().skip.guild and F.DB().total == 1030662, 'the options were not taken over')
assert(F.ImportGIL(gil).rules == 0, 'a second import added the filters again')
-- Unignored here after the import: taken off the game's list later.
I.Remove('Forgiven', { quiet = true })

-- Rules ------------------------------------------------------------------------
local trade, tradeName = 2, 'Trade - City'
assert(not Shown('CHAT_MSG_CHANNEL', 'WTS M+ boost, fast', 'Seller-Kazzak', trade, tradeName, 3),
    'a seller was shown')
assert(F.Rules()[2].count == 49689, 'counted more than once for one line in three chat windows')
assert(Shown('CHAT_MSG_CHANNEL', 'LF blacksmith for a weapon', 'Buyer-Kazzak', trade, tradeName), 'a request was hidden')
assert(F.LineText(lineID) == 'LF blacksmith for a weapon' and F.LineText(tostring(lineID - 1)) == 'WTS M+ boost, fast',
    'the lines are not remembered for the text selection tool')
assert(Shown('CHAT_MSG_GUILD', 'WTS m+ boost', 'Guildie-Kazzak'), 'guild chat was filtered')
assert(not Shown('CHAT_MSG_CHANNEL', '<Night Watch> recruit for raids', 'Rec-Kazzak', trade, tradeName),
    'guild recruitment was shown')
-- A key, as the text selection tool adds it.
assert(F.AddKey('gamer-choice.net', false))
assert(not F.AddKey('GAMER-CHOICE.NET', false), 'a key was added twice')
assert(not Shown('CHAT_MSG_CHANNEL', 'Runs 24/7! |cff82c5ff|HclubTicket:abc|h[Visit gamer-choice.net]|h|r',
    'Other-Kazzak', trade, tradeName), 'a key did not hide its message')
assert(F.DB().log[#F.DB().log].r == F.Rules()[5].id, 'the journal does not name the key')

-- The ignore list: hidden everywhere, whispers answered once in a while ------
assert(not Shown('CHAT_MSG_SAY', 'hello', 'Spammer-Kazzak'), 'an ignored player was shown')
assert(not Shown('CHAT_MSG_WHISPER', 'buy gold', 'Spammer'), 'an ignored whisper was shown')
assert(#sent == 1 and sent[1].target == 'Spammer' and sent[1].text == 'You are being ignored.', 'no answer')
assert(not Shown('CHAT_MSG_WHISPER_INFORM', 'You are being ignored.', 'Spammer'), 'our own answer was shown')
assert(not Shown('CHAT_MSG_WHISPER', 'buy gold!!', 'Spammer'))
assert(#sent == 1, 'answered twice within five minutes')
assert(Shown('CHAT_MSG_WHISPER', 'WTS m+ boost', 'Friend-Kazzak'), 'rules looked at whispers')

-- NPC speech: hidden by kind, not in dungeons and raids -----------------------
assert(not Shown('CHAT_MSG_MONSTER_SAY', 'Right... ok, what sort of axe be ya looking for?', 'Shiri'),
    'an NPC saying was shown')
assert(Shown('CHAT_MSG_MONSTER_WHISPER', 'Meet me at the docks.', 'Quest Giver'), 'an NPC whisper was hidden')
inInstance = true
assert(Shown('CHAT_MSG_MONSTER_YELL', 'You will die!', 'Boss'), 'a boss was hidden in a raid')
inInstance = false

-- Online and offline ------------------------------------------------------------
assert(not Shown('CHAT_MSG_SYSTEM', 'Mavu has gone offline.'), 'your own character was shown')
assert(not Shown('CHAT_MSG_SYSTEM', '|Hplayer:Favu|h[Favu]|h has come online.'), 'another own character was shown')
assert(not Shown('CHAT_MSG_SYSTEM', 'Laptopmin has gone offline.'), "a linked account's character was shown")
assert(not Shown('CHAT_MSG_SYSTEM', '|Hplayer:Guildie-Kazzak|h[Guildie-Kazzak]|h has come online.'), 'a guild member')
assert(not Shown('CHAT_MSG_SYSTEM', 'Buddy has gone offline.'), 'a friend was shown')
assert(Shown('CHAT_MSG_SYSTEM', 'Stranger has gone offline.'), 'a stranger was hidden')
-- Other people's duels are hidden; yours are not.
assert(not Shown('CHAT_MSG_SYSTEM', 'Wickomode-TarrenMill has defeated Waior in a duel'), "someone else's duel was shown")
assert(not Shown('CHAT_MSG_SYSTEM', 'Waior has fled from Wickedmode in a duel'), "someone else's retreat was shown")
assert(Shown('CHAT_MSG_SYSTEM', 'Mavu has defeated Waior in a duel'), 'your own duel was hidden')
assert(Shown('CHAT_MSG_SYSTEM', 'Waior has defeated Mavu-Kazzak in a duel'), 'your own lost duel was hidden')
F.DB().system.duels = false
assert(Shown('CHAT_MSG_SYSTEM', 'Wickomode-TarrenMill has defeated Waior in a duel'), 'duels were hidden with the option off')
F.DB().system.duels = true
F.DB().presence.friends = false
assert(Shown('CHAT_MSG_SYSTEM', 'Buddy has gone offline.'), 'friends were hidden with the option off')

-- The game's list ----------------------------------------------------------------
I.Add('Gone', { quiet = true, at = now + 100 })
Fire('IGNORELIST_UPDATE')
RunTimers()
-- Gone is not found: the game's line is ours and not shown, twice missed
-- they are not asked for again, and the chat still hides them.
assert(addCalls['Gone-Kazzak'] == 1, 'Gone was not tried')
assert(not Shown('CHAT_MSG_SYSTEM', 'Player not found.'), "the game's not-found line after the sync was shown")
RunTimers()
assert(I.Entry('Gone').game_misses == 1, 'a player the game did not find was not noted')
I.Sync()
RunTimers()
assert(addCalls['Gone-Kazzak'] == 2 and I.Entry('Gone').game_misses == 2)
I.Sync()
RunTimers()
assert(addCalls['Gone-Kazzak'] == 2, 'a player the game never finds was asked for again')
assert(I.IsIgnored('Gone') and not Shown('CHAT_MSG_SAY', 'hi', 'Gone-Kazzak'), 'the chat stopped hiding them')
assert(I.IsIgnored('Oldspam'), "someone ignored in the game was not taken in")
assert(not IndexOf('Forgiven'), "someone unignored here stayed on the game's list")
assert(IndexOf('Goodgirl') and IndexOf('Spammer'), "the game's list was not filled")
-- Those lines were ours: not shown.
assert(not Shown('CHAT_MSG_SYSTEM', 'Goodgirl is now being ignored.'), 'a sync line was shown')
assert(Shown('CHAT_MSG_SYSTEM', 'Somebody is now being ignored.'), "someone else's ignore line was hidden")
-- Later, a not-found line is the player's own (a mistyped /ignore).
clock = clock + 60
assert(Shown('CHAT_MSG_SYSTEM', 'Player not found.'), "someone's own not-found line was hidden")
-- Ignoring and unignoring through the game changes this list.
C_FriendList.AddIgnore('Newbie')
assert(I.IsIgnored('Newbie-Kazzak'), 'an ignore through the game was not kept')
Fire('IGNORELIST_UPDATE')
C_FriendList.AddOrDelIgnore('Newbie')
assert(not I.IsIgnored('Newbie') and I.Settings().removed['newbie-kazzak'], 'an unignore through the game was lost')
-- Beyond 50 the list still hides them; the game's "full" line is not shown.
for index = 1, 60 do I.Add('Bulk' .. index, { quiet = true }) end
assert(#gameList == 50 and I.Count() > 60, "the game's list went over 50")
assert(I.IsIgnored('Bulk60') and not Shown('CHAT_MSG_SAY', 'hi', 'Bulk60-Kazzak'), 'beyond 50 was not hidden')
assert(not Shown('CHAT_MSG_SYSTEM', 'Your ignore list is full.'), 'the full line was shown')

-- Invitations -----------------------------------------------------------------------
Fire('PARTY_INVITE_REQUEST', 'Spammer-Kazzak')
assert(declined[1] == 'group', 'an invitation from an ignored player was not declined')
Fire('PARTY_INVITE_REQUEST', 'Friend-Kazzak')
assert(#declined == 1, 'a friend was declined')

-- Off is off; secret lines are left alone.
function issecretvalue(value) return value == 'SECRET' end
assert(Shown('CHAT_MSG_CHANNEL', 'SECRET', 'Seller-Kazzak', trade, tradeName), 'a secret line was touched')
issecretvalue = nil
F.DB().enabled = false
assert(Shown('CHAT_MSG_SAY', 'hello', 'Spammer-Kazzak'), 'the filter worked while switched off')
F.DB().enabled = true
-- At login: Global Ignore List on and nothing taken over yet - taken over
-- by itself, once; already off with no rules - the chat says how.
HironCraftScan_DB.chat_filter = nil
C_AddOns = { IsAddOnLoaded = function(name) return name == 'GlobalIgnoreList' end }
GlobalIgnoreDB = gil
Fire('PLAYER_LOGIN')
assert(#F.Rules() == 4 and F.DB().gil_imported and I.IsIgnored('Goodgirl'), 'Global Ignore List was not taken over at login')
assert(printed[#printed]:find('taken over', 1, true), 'the take-over was not reported')
local reports = #printed
Fire('PLAYER_LOGIN')
assert(#F.Rules() == 4 and #printed == reports, 'Global Ignore List was taken over twice')
HironCraftScan_DB.chat_filter = nil
C_AddOns, GlobalIgnoreDB = nil, nil
Fire('PLAYER_LOGIN')
assert(printed[#printed]:find('no rules yet', 1, true), 'an empty filter did not say how to fill it')
print('Chat filter passed (expressions, GIL import, rules, keys, ignore list, answers, NPC speech, online/offline, game list, invitations, take-over at login).')
