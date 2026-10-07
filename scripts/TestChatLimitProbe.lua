-- /hcchatlimit against a stand-in for the game's chat: a server that holds a
-- number of letters in a whisper, does not count the code of a link, takes a
-- quality icon for some letters and refuses more than a number of bytes. A
-- message too long is cut, dropped or refused with an error, and whispers
-- may be allowed only on a key press: the probe has to cope with each.
local printed = {}
local realPrint = print
print = function(text) printed[#printed + 1] = tostring(text) end

local timers, inTimer, clock = {}, false, 100
function GetTime() return clock end
C_Timer = { After = function(delay, fn) timers[#timers + 1] = { at = delay, fn = fn } end }
local function runTimers()
    local guard = 0
    while #timers > 0 do
        guard = guard + 1
        assert(guard < 5000, 'the probe never finishes')
        local timer = table.remove(timers, 1)
        inTimer = true
        clock = clock + 1
        timer.fn()
        inTimer = false
    end
end

local frames = {}
function CreateFrame()
    local frame = { events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(_, fn) self.handler = fn end
    frames[#frames + 1] = frame
    return frame
end
local function fire(event, ...)
    for _, frame in ipairs(frames) do
        if frame.events[event] and frame.handler then frame.handler(frame, event, ...) end
    end
end
function UnitName() return 'Vamo', nil end
function time() return 1000 end
SlashCmdList = {}

local plainLink = '|cnIQ3:|Hitem:1001::::::::90:::::::::|h[Darkmoon Game Token]|h|r'
local iconLink = '|cnIQ2:|Hitem:2002::::::::90:::::::::|h[Radiant Shard |A:Professions-ChatIcon-Quality-12-Tier2:17:18::1|a]|h|r'
local fullBags = { [0] = { 'not a link', plainLink }, [5] = { iconLink } }
local bags = fullBags
C_Container = {
    GetContainerNumSlots = function(bag) return bags[bag] and #bags[bag] or 0 end,
    GetContainerItemLink = function(bag, slot) return bags[bag] and bags[bag][slot] end,
}

-- The server.
local rules
local sentMessages = {}
local function deliver(text)
    local out, used, position = {}, 0, 1
    while position <= #text do
        local color = text:match('^|cn[%w_]+:', position) or ''
        local linkEnd
        if text:sub(position + #color, position + #color + 1) == '|H' then
            local header = text:find('|h', position + #color + 2, true)
            local label = header and text:find('|h', header + 2, true)
            linkEnd = label and (text:sub(label + 2, label + 3) == '|r' and label + 3 or label + 1)
        end
        local token, cost
        if linkEnd then
            token = text:sub(position, linkEnd)
            local name = token:match('|h(%[.-%])|h')
            local _, icons = name:gsub('|A.-|a', '')
            cost = #(name:gsub('|A.-|a', '')) + icons * rules.icon
        else
            local byte = text:byte(position)
            local size = byte >= 240 and 4 or byte >= 224 and 3 or byte >= 192 and 2 or 1
            token = text:sub(position, position + size - 1)
            cost = rules.byBytes and size or 1
        end
        if used + cost > rules.letters then break end
        if #table.concat(out) + #token > rules.bytes then break end
        out[#out + 1] = token
        used = used + cost
        position = position + #token
    end
    if position <= #text then
        if rules.long == 'error' then error('message too long', 0) end
        if rules.long == 'drop' then return nil end
    end
    return table.concat(out)
end
function SendChatMessage(text, kind, _, target, extra)
    assert(kind == 'WHISPER' and target == 'Vamo' and extra == nil, 'a test whisper went to someone else')
    sentMessages[#sentMessages + 1] = text
    if rules.dead then
        fire('CHAT_MSG_SYSTEM', 'No player named Vamo is currently playing.')
        return
    end
    if rules.keyOnly and inTimer then
        if rules.blockedEvent then fire('ADDON_ACTION_BLOCKED', 'HironCraft', 'SendChatMessage()') end
        return
    end
    local arrived = deliver(text)
    if arrived then fire('CHAT_MSG_WHISPER', arrived, 'Vamo') end
end

local Scan = { DB = { settings = {} }, Utils = {} }
assert(loadfile('Utils/ChatLimitProbe.lua'))('HironCraft', Scan)
local Probe = Scan.ChatLimitProbe
assert(SLASH_HIRONCRAFTCHATLIMIT1 == '/hcchatlimit' and SlashCmdList.HIRONCRAFTCHATLIMIT, 'the probe has no command')

local presses
local function run(serverRules)
    rules = serverRules
    rules.long = rules.long or 'cut'
    rules.bytes = rules.bytes or 100000
    sentMessages, printed, presses = {}, {}, 0
    Scan.DB.settings.chat_limit_probe = nil
    SlashCmdList.HIRONCRAFTCHATLIMIT()
    presses = 1
    -- Ours while it runs, and only ours.
    assert(Probe.Owns('hcp12 xxxx') and not Probe.Owns('LF crafter') and not Probe.Owns('hcp x'),
        'the scanner cannot tell a test whisper from a customer')
    local guard = 0
    while true do
        runTimers()
        if not Probe.Owns('hcp1 x') then break end
        -- It waits for the command again.
        guard = guard + 1
        assert(guard < 200, 'the probe never finishes on key presses')
        SlashCmdList.HIRONCRAFTCHATLIMIT()
        presses = presses + 1
    end
    for _, message in ipairs(sentMessages) do assert(message:find('^hcp%d+ '), 'a test whisper is not marked') end
    return assert(Scan.DB.settings.chat_limit_probe, 'the result was not saved'), table.concat(printed, '\n')
end

-- A long message is cut: 255 letters, an icon for nothing.
local result, said = run({ letters = 255, icon = 0 })
assert(presses == 1, 'the command had to be typed again where a timer may whisper')
assert(result.letters == 255 and result.cuts == true, 'the number of letters is wrong: ' .. tostring(result.letters))
assert(result.cyrillic == 'letters', 'Cyrillic by letters was not seen')
assert(result.plain.cost == #'[Darkmoon Game Token]' and result.plain.nameLetters == result.plain.cost,
    'a link does not take its name: ' .. tostring(result.plain.cost))
assert(result.icon.cost == #'[Radiant Shard ]', 'a free icon was counted: ' .. tostring(result.icon.cost))
assert(result.whole and result.whole.links >= 10 and result.whole.bytes > 255, 'the bytes that arrive were not measured')
assert(said:find('done', 1, true) and #result.lines >= 5, 'the result is not reported')

-- An icon that takes 4 letters, Cyrillic by bytes.
result = run({ letters = 255, icon = 4, byBytes = true })
assert(result.letters == 255 and result.cyrillic == 'bytes' and result.cyrillicBytes <= 255, 'Cyrillic by bytes was not seen')
assert(result.icon.cost == #'[Radiant Shard ]' + 4, 'the cost of an icon was not measured: ' .. tostring(result.icon.cost))

-- A ceiling on the bytes: the longest message of links that arrives whole.
result = run({ letters = 255, icon = 0, bytes = 700 })
assert(result.whole and result.whole.bytes <= 700 and result.whole.bytes > 700 - #iconLink,
    'the byte ceiling was not found: ' .. tostring(result.whole and result.whole.bytes))
assert(result.cut and result.cut.bytes > 700, 'the message that was cut is not reported')

-- A long message is dropped, not cut: the longest that arrives is searched,
-- and what a link takes is tried instead of read off a cut message.
result, said = run({ letters = 255, icon = 0, long = 'drop' })
assert(result.letters == 255 and not result.cuts, 'the longest whisper that arrives was not searched: ' .. tostring(result.letters))
assert(result.cyrillic == 'letters' and result.plain.cost == #'[Darkmoon Game Token]'
    and result.icon.cost == #'[Radiant Shard ]' and result.whole, 'a server that drops long messages was not measured')
result = run({ letters = 255, icon = 2, long = 'drop', byBytes = true })
assert(result.letters == 255 and result.cyrillic == 'bytes' and result.icon.cost == #'[Radiant Shard ]' + 2,
    'the cost of an icon was not tried out: ' .. tostring(result.icon.cost))
result = run({ letters = 300, icon = 0, long = 'drop' })
assert(result.letters == 300, 'another number of letters was not found: ' .. tostring(result.letters))

-- A long message is refused with an error: it is caught, said, and searched around.
result, said = run({ letters = 255, icon = 0, long = 'error' })
assert(result.letters == 255 and said:find('message too long', 1, true), 'an error of the game stopped the probe silently')
assert(result.plain.cost == #'[Darkmoon Game Token]' and result.whole)

-- Whispers only on a key press: every step asks for the command again.
result, said = run({ letters = 255, icon = 0, keyOnly = true })
assert(presses > 4 and said:find('only on a key press', 1, true), 'a blocked timer whisper was not noticed')
assert(result.letters == 255 and result.cuts and result.plain.cost == #'[Darkmoon Game Token]' and result.whole,
    'the probe did not finish on key presses')
result, said = run({ letters = 255, icon = 0, keyOnly = true, blockedEvent = true, long = 'drop' })
assert(presses > 6 and result.letters == 255 and result.icon.cost == #'[Radiant Shard ]', 'a blocked action was not worked around')

-- Nothing arrives at all: it says so and stops, with what the game said.
result, said = run({ letters = 255, icon = 0, dead = true })
assert(result.letters == nil and said:find('does not arrive', 1, true) and said:find('No player named', 1, true)
    and #sentMessages == 1, 'a whisper that cannot arrive was not reported: ' .. said)

-- Nothing to link: the letters are still measured.
bags = {}
result = run({ letters = 255, icon = 0 })
assert(result.letters == 255 and result.plain == nil and result.icon == nil and result.whole == nil)
bags = fullBags

-- A run that died is not waited for forever.
rules = { letters = 255, icon = 0, long = 'cut', bytes = 100000 }
SlashCmdList.HIRONCRAFTCHATLIMIT()
timers = {}
printed = {}
SlashCmdList.HIRONCRAFTCHATLIMIT()
assert(table.concat(printed, '\n'):find('already running', 1, true), 'a second command started a second run')
timers = {}
clock = clock + 500
printed = {}
SlashCmdList.HIRONCRAFTCHATLIMIT()
assert(table.concat(printed, '\n'):find('measuring', 1, true), 'a dead run blocked the probe forever')
runTimers()

print = realPrint
print('Chat limit probe passed (cut, dropped and refused long messages, Cyrillic, link and icon cost, byte ceiling, key presses only, nothing arrives, empty bags, dead run).')
