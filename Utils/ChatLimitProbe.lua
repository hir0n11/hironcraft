local HironCraftScan = select(2, ...)

-- /hcchatlimit measures what one whisper really holds, with whispers to
-- yourself: how many letters, whether Cyrillic is counted by letters or by
-- bytes, what a link and its quality icon take, and how many bytes arrive.
-- Utils/ChatLength.lua is set from what it reports.
--
-- Nothing is taken for granted about the game: a send that raises an error is
-- caught and reported, a long message may be cut or may not arrive at all,
-- and where an addon may whisper only on a key press the command asks to be
-- typed again for every step. Every test whisper starts with "hcpN ".
local Probe = {}
HironCraftScan.ChatLimitProbe = Probe

local MARK = 'hcp'
local STEP_SECONDS = 2
local WAIT_SECONDS = 4
local STALE_SECONDS = 60
local LONG = 600
local ICON_GUESSES = { 0, 1, 2, 4 }

local state = nil
local serial = 0
local watcher = nil

local function Secret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function Clock()
    return (GetTime and GetTime()) or (time and time()) or 0
end

-- A test whisper of ours: the scanner must not take it for a customer's.
function Probe.Owns(message)
    if not state or type(message) ~= 'string' or Secret(message) then return false end
    return message:find('^' .. MARK .. '%d+ ') ~= nil
end

local function Say(text)
    print('|cffffd100HironCraft chat limit:|r ' .. text)
end

local function Note(text)
    if state then state.result.lines[#state.result.lines + 1] = text end
    Say(text)
end

local function Letters(text)
    return #(text:gsub('[\128-\191]', ''))
end

-- A link's [name] as it is shown, without its quality icon.
local function ShownName(link)
    local name = link:match('|h(%[.-%])|h') or ''
    return (name:gsub('|A.-|a', ''))
end

local function CountLinks(text)
    return select(2, text:gsub('|Hitem:', ''))
end

local function BagLinks()
    local plain, icon
    if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemLink) then return nil, nil end
    for bag = 0, 5 do
        for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
            local link = C_Container.GetContainerItemLink(bag, slot)
            if type(link) == 'string' and not Secret(link) and link:find('|Hitem:', 1, true) and link:find('|h%[.-%]|h') then
                if link:find('|A', 1, true) then icon = icon or link else plain = plain or link end
            end
        end
    end
    return plain, icon
end

local function Finish()
    local result = state.result
    state = nil
    local settings = HironCraftScan.DB and HironCraftScan.DB.settings
    if type(settings) == 'table' then settings.chat_limit_probe = result end
    Say('done. Send a screenshot of these lines (or /reload: the result is saved).')
end

local function Fail(problem)
    Note('stopped: ' .. tostring(problem))
    Finish()
end

local Step

-- What follows a step: the next one on its own, or on the next key press.
local function Continue()
    if not state then return end
    state.progress = Clock()
    if #state.queue == 0 then return Finish() end
    if state.manual then
        Say(string.format('type /hcchatlimit again for the next step (%d left, more if it has to search).', #state.queue))
    else
        C_Timer.After(STEP_SECONDS, function() if state then Step(false) end end)
    end
end

-- Sends the whisper of one step and hands its outcome to the step: what
-- arrived (nil when nothing did), what was sent, and what went wrong.
function Step(byKey)
    local experiment = table.remove(state.queue, 1)
    -- A step that only plans what follows sends nothing.
    while experiment and experiment.plan do
        local planned, problem = pcall(experiment.plan)
        if not planned then return Fail(problem) end
        experiment = table.remove(state.queue, 1)
    end
    if not experiment then return Finish() end
    serial = serial + 1
    local id = tostring(serial)
    local prefix = MARK .. id .. ' '
    local run = state
    local finished = false
    local text
    local function Outcome(received, problem)
        if finished or state ~= run then return end
        finished = true
        state.waiting = nil
        local ok, err = pcall(experiment.done, received, text, problem or state.lastSystem, prefix)
        if not ok then return Fail(err) end
        Continue()
    end
    local built, body = pcall(experiment.body, prefix)
    if not built then return Fail(body) end
    text = prefix .. body
    state.waiting = { id = id, arrive = Outcome }
    state.lastSystem = nil
    state.progress = Clock()
    local sent, err = pcall(SendChatMessage, text, 'WHISPER', nil, (UnitName('player')))
    if not sent then
        C_Timer.After(0, function() Outcome(nil, 'the game refused to send it: ' .. tostring(err)) end)
        return
    end
    C_Timer.After(WAIT_SECONDS, function() Outcome(nil) end)
end

local function Push(experiment, first)
    if first then table.insert(state.queue, 1, experiment) else state.queue[#state.queue + 1] = experiment end
end

local function Whole(received, text)
    return received ~= nil and #received == #text
end

-- The longest plain whisper that arrives whole, between one that does and one
-- that does not.
local function Search(low, high, guess)
    if high - low <= 1 then
        state.result.letters = low
        Note(string.format('a whisper holds %d letters; a longer one does not arrive.', low))
        return
    end
    local middle = (guess and guess > low and guess < high) and guess or math.floor((low + high) / 2)
    Push({
        body = function(prefix) return string.rep('x', middle - #prefix) end,
        done = function(received, text)
            if Whole(received, text) then
                Search(middle, high, middle == 255 and 256 or nil)
            else
                Search(low, middle, middle == 256 and nil or 255)
            end
        end,
    }, true)
end

local function LinkSteps(link, key, label)
    if not link then
        Note(label .. ': no such item in the bags, not measured.')
        return
    end
    local name = ShownName(link)
    local entry = { name = name, nameLetters = Letters(name), bytes = #link }
    state.result[key] = entry
    Push({
        -- Three of them and a filler: a message cut short loses filler, and
        -- what is left of it tells how much the links took.
        body = function() return string.rep(link, 3) .. ' ' .. string.rep('x', LONG) end,
        done = function(received, _, _, prefix)
            local letters = state.result.letters
            if received and CountLinks(received) == 3 and state.result.cuts and letters then
                local filler = #(received:match('(x*)$') or '')
                entry.cost = (letters - #prefix - 1 - filler) / 3
                Note(string.format('%s %s: takes %s letters (its name is %d, the link is %d bytes).',
                    label, name, tostring(entry.cost), entry.nameLetters, #link))
                return
            end
            -- Nothing is cut here: try what it is believed to take, exactly
            -- filling a whisper, with more for the icon each time.
            local guesses = key == 'icon' and ICON_GUESSES or { 0 }
            local function Guess(index)
                local extra = guesses[index]
                if not extra or not letters then
                    Note(string.format('%s %s: not measured (its name is %d letters, the link is %d bytes).',
                        label, name, entry.nameLetters, #link))
                    return
                end
                Push({
                    body = function(guessPrefix)
                        local filler = letters - #guessPrefix - 1 - 3 * (entry.nameLetters + extra)
                        return string.rep(link, 3) .. ' ' .. string.rep('x', math.max(filler, 0))
                    end,
                    done = function(arrived, text)
                        if arrived and CountLinks(arrived) == 3 and #(arrived:match('(x*)$') or '') == #(text:match('(x*)$') or '') then
                            entry.cost = entry.nameLetters + extra
                            Note(string.format('%s %s: takes at most %d letters (its name is %d, the link is %d bytes).',
                                label, name, entry.cost, entry.nameLetters, #link))
                        else
                            Guess(index + 1)
                        end
                    end,
                }, true)
            end
            Guess(1)
        end,
    })
end

local function Start()
    state = { queue = {}, result = { at = time and time() or 0, lines = {} }, manual = false, progress = Clock() }
    local plain, icon = BagLinks()
    Say('measuring with a few whispers to yourself, about half a minute...')

    -- Does a whisper to yourself arrive at all, and may one be sent without a
    -- key press?
    Push({
        body = function() return 'ping' end,
        done = function(received, _, problem)
            if not received then
                error('a whisper to yourself does not arrive' .. (problem and (' (' .. tostring(problem) .. ')') or ''), 0)
            end
        end,
    })
    Push({
        body = function() return 'ping' end,
        done = function(received)
            if not received then
                state.manual = true
                Note('an addon may whisper only on a key press here: every step needs the command again.')
            end
        end,
    })

    -- Letters: a long plain message is cut to what a whisper holds, or does
    -- not arrive; then the longest that does is searched.
    Push({
        body = function() return string.rep('x', LONG) end,
        done = function(received, text, problem)
            if received and #received < #text then
                state.result.letters, state.result.cuts = #received, true
                Note(string.format('a whisper holds %d letters (a longer one is cut).', #received))
            elseif received then
                state.result.letters = #received
                Note(string.format('a whisper of %d letters arrived whole.', #received))
            else
                Note('a whisper of ' .. #text .. ' letters does not arrive' .. (problem and (' (' .. tostring(problem) .. ')') or '')
                    .. '; searching for the longest that does...')
                Search(#MARK + 6, #text, 255)
            end
        end,
    })

    -- Cyrillic: as many letters as a whisper holds. Whole means letters are
    -- counted, not bytes.
    Push({
        body = function(prefix) return string.rep('я', math.max((state.result.letters or 255) - #prefix, 1)) end,
        done = function(received, text)
            if received and #received == #text then
                state.result.cyrillic = 'letters'
                Note(string.format('Cyrillic is counted by letters: %d letters, %d bytes arrived whole.', Letters(received), #received))
            elseif received then
                state.result.cyrillic, state.result.cyrillicBytes = 'bytes', #received
                Note(string.format('Cyrillic is cut: %d letters, %d bytes arrived of %d letters.',
                    Letters(received), #received, Letters(text)))
            else
                state.result.cyrillic = 'bytes'
                Note(string.format('Cyrillic: %d letters (%d bytes) did not arrive, so bytes are counted.', Letters(text), #text))
            end
        end,
    })

    -- Planned once the letters are known.
    Push({ plan = function()
        LinkSteps(plain, 'plain', 'link')
        LinkSteps(icon, 'icon', 'link with a quality icon')
        -- Bytes: as many links as the letters allow, whole?
        Push({ plan = function()
            local result = state.result
            local best, bestCost
            for _, key in ipairs({ 'plain', 'icon' }) do
                local entry = result[key]
                local link = key == 'plain' and plain or icon
                if entry and link and entry.cost and entry.cost > 0 then
                    if not best or #link / entry.cost > #best / bestCost then best, bestCost = link, entry.cost end
                end
            end
            if not best or not result.letters then
                Note('bytes: not measured (no link was measured).')
                return
            end
            -- The most links that arrive whole, between a number that does
            -- (none) and one that does not.
            local count = math.floor((result.letters - #MARK - 4) / bestCost)
            local good, bad = 0, count + 1
            local function Attempt(links)
                if links < 1 then
                    Note('bytes: no message of links arrived whole.')
                    return
                end
                Push({
                    body = function() return string.rep(best, links) end,
                    done = function(received, text)
                        local arrived = received and CountLinks(received) or nil
                        if arrived == links then
                            good = links
                            result.whole = { links = links, bytes = #text }
                        else
                            bad = links
                            result.cut = result.cut or { links = links, bytes = #text, arrived = arrived }
                            -- A message that is cut says how many fit.
                            if arrived and arrived >= good then bad = math.min(bad, arrived + 1) end
                        end
                        if bad - good <= 1 then
                            if result.whole then
                                Note(string.format('bytes: %d links, %d bytes arrived whole%s.', result.whole.links,
                                    result.whole.bytes, result.cut and (', ' .. result.cut.bytes .. ' did not') or ''))
                            else
                                Note('bytes: no message of links arrived whole.')
                            end
                            return
                        end
                        Attempt(math.floor((good + bad) / 2))
                    end,
                }, true)
            end
            Attempt(count)
        end })
    end })
end

local function Watch()
    if watcher then return end
    watcher = CreateFrame('Frame')
    watcher:RegisterEvent('CHAT_MSG_WHISPER')
    watcher:RegisterEvent('CHAT_MSG_SYSTEM')
    watcher:RegisterEvent('ADDON_ACTION_BLOCKED')
    watcher:RegisterEvent('ADDON_ACTION_FORBIDDEN')
    watcher:SetScript('OnEvent', function(_, event, text, second)
        if not state then return end
        if event == 'CHAT_MSG_SYSTEM' then
            if type(text) == 'string' and not Secret(text) then state.lastSystem = text end
            return
        end
        local waiting = state.waiting
        if event == 'ADDON_ACTION_BLOCKED' or event == 'ADDON_ACTION_FORBIDDEN' then
            if waiting and text == 'HironCraft' then waiting.arrive(nil, 'the game blocked ' .. tostring(second)) end
            return
        end
        if Secret(text) then
            if waiting then waiting.arrive(nil, 'whispers are hidden from addons here') end
            return
        end
        if type(text) ~= 'string' then return end
        local id = text:match('^' .. MARK .. '(%d+) ')
        if waiting and id == waiting.id then waiting.arrive(text) end
    end)
end

function Probe.Run()
    if not (C_Timer and C_Timer.After and SendChatMessage and CreateFrame) then return false end
    if state and Clock() - (state.progress or 0) > STALE_SECONDS and not state.manual then
        -- A run that died leaves nothing to wait for.
        state = nil
    end
    if state then
        if state.waiting then
            Say('waiting for the last whisper, a moment...')
            return false
        end
        if not state.manual then
            Say('already running.')
            return false
        end
        Step(true)
        return true
    end
    Watch()
    local ok, err = pcall(Start)
    if not ok then
        Say('could not start: ' .. tostring(err))
        state = nil
        return false
    end
    Step(true)
    return true
end

if SlashCmdList then
    SLASH_HIRONCRAFTCHATLIMIT1 = '/hcchatlimit'
    SlashCmdList.HIRONCRAFTCHATLIMIT = function()
        local ok, err = pcall(Probe.Run)
        if not ok then
            Say('error: ' .. tostring(err))
            state = nil
        end
    end
end
