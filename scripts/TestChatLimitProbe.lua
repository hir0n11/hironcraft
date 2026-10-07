-- /hcchatlimit against a stand-in for the game's chat: a server that cuts a
-- whisper to a number of letters, does not count the code of a link, takes a
-- quality icon for a letter or two and refuses more than a number of bytes.
local printed = {}
local realPrint = print
print = function(text) printed[#printed + 1] = tostring(text) end

local timers = {}
C_Timer = { After = function(delay, fn) timers[#timers + 1] = { at = delay, fn = fn } end }
local function runTimers()
    local guard = 0
    while #timers > 0 do
        guard = guard + 1
        assert(guard < 2000, 'the probe never finishes')
        local timer = table.remove(timers, 1)
        timer.fn()
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
function UnitName() return 'Vamo' end
function time() return 1000 end
SlashCmdList = {}

local plainLink = '|cnIQ3:|Hitem:1001::::::::90:::::::::|h[Darkmoon Game Token]|h|r'
local iconLink = '|cnIQ2:|Hitem:2002::::::::90:::::::::|h[Radiant Shard |A:Professions-ChatIcon-Quality-12-Tier2:17:18::1|a]|h|r'
local bags = { [0] = { 'not a link', plainLink }, [5] = { iconLink } }
C_Container = {
    GetContainerNumSlots = function(bag) return bags[bag] and #bags[bag] or 0 end,
    GetContainerItemLink = function(bag, slot) return bags[bag] and bags[bag][slot] end,
}

-- The server.
local rules
local sentMessages = {}
local function deliver(text)
    if #text > rules.bytes then
        if rules.rejectBytes then return nil end
    end
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
    if position <= #text and rules.rejectLong then return nil end
    return table.concat(out)
end
function SendChatMessage(text, kind, _, target)
    assert(kind == 'WHISPER' and target == 'Vamo', 'a test whisper went to someone else')
    sentMessages[#sentMessages + 1] = text
    local arrived = deliver(text)
    if arrived then
        for _, frame in ipairs(frames) do
            if frame.events.CHAT_MSG_WHISPER and frame.handler then frame.handler(frame, 'CHAT_MSG_WHISPER', arrived, 'Vamo') end
        end
    end
end

local Scan = { DB = { settings = {} }, Utils = {} }
assert(loadfile('Utils/ChatLimitProbe.lua'))('HironCraft', Scan)
local Probe = Scan.ChatLimitProbe
assert(SLASH_HIRONCRAFTCHATLIMIT1 == '/hcchatlimit' and SlashCmdList.HIRONCRAFTCHATLIMIT, 'the probe has no command')

local function run(serverRules)
    rules = serverRules
    sentMessages, printed = {}, {}
    Scan.DB.settings.chat_limit_probe = nil
    assert(Probe.Run() == true)
    -- Ours while it runs, and only ours.
    assert(Probe.Owns('hcp12 xxxx') and not Probe.Owns('LF crafter') and not Probe.Owns('hcp x'),
        'the scanner cannot tell a test whisper from a customer')
    assert(Probe.Run() == false, 'two probes ran at once')
    runTimers()
    assert(not Probe.Owns('hcp12 xxxx'), 'a finished probe still claims whispers')
    return assert(Scan.DB.settings.chat_limit_probe, 'the result was not saved')
end

-- What the game is believed to do: 255 letters, an icon for nothing.
local result = run({ letters = 255, icon = 0, bytes = 100000 })
assert(result.letters == 255, 'the number of letters is wrong: ' .. tostring(result.letters))
assert(result.cyrillicLetters == 255 and result.cyrillicBytes > 255, 'Cyrillic by letters was not seen')
assert(result.plain.cost == #'[Darkmoon Game Token]' and result.plain.nameLetters == result.plain.cost,
    'a link does not take its name: ' .. tostring(result.plain.cost))
assert(result.icon.cost == #'[Radiant Shard ]', 'a free icon was counted: ' .. tostring(result.icon.cost))
assert(result.whole and result.whole.links >= 10 and result.whole.bytes > 255, 'the bytes that arrive were not measured')
for _, message in ipairs(sentMessages) do assert(message:find('^hcp%d+ '), 'a test whisper is not marked') end

-- An icon that takes 4 letters, Cyrillic by bytes.
result = run({ letters = 255, icon = 4, bytes = 100000, byBytes = true })
assert(result.letters == 255 and result.cyrillicBytes <= 255 and result.cyrillicLetters < 140, 'Cyrillic by bytes was not seen')
assert(result.icon.cost == #'[Radiant Shard ]' + 4, 'the cost of an icon was not measured: ' .. tostring(result.icon.cost))

-- A ceiling on the bytes: the longest message of links that arrives whole.
result = run({ letters = 255, icon = 0, bytes = 700 })
assert(result.whole and result.whole.bytes <= 700 and result.whole.bytes > 700 - #iconLink,
    'the byte ceiling was not found: ' .. tostring(result.whole and result.whole.bytes))
assert(result.cut and result.cut.bytes > 700, 'the message that was cut is not reported')

-- A server that drops a long message instead of cutting it.
result = run({ letters = 255, icon = 0, bytes = 100000, rejectLong = true })
assert(result.letters == 255 and result.rejected == true, 'the longest whisper that arrives was not searched: '
    .. tostring(result.letters))

-- Nothing to link: the letters are still measured.
bags = {}
result = run({ letters = 300, icon = 0, bytes = 100000 })
assert(result.letters == 300 and result.plain == nil and result.icon == nil and result.whole == nil)

print = realPrint
print('Chat limit probe passed (letters, Cyrillic by letters or bytes, link and icon cost, byte ceiling, dropped messages, empty bags).')
