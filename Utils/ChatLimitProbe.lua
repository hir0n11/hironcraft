local HironCraftScan = select(2, ...)

-- /hcchatlimit measures what one whisper really holds, with whispers to
-- yourself: how many letters, whether Cyrillic is counted by letters or by
-- bytes, what a link and its quality icon take, and how many bytes arrive.
-- Utils/ChatLength.lua is set from what it reports. Every test whisper starts
-- with "hcpN " and ends with a filler, so a message cut short loses filler
-- and the count of what is left is the answer.
local Probe = {}
HironCraftScan.ChatLimitProbe = Probe

local MARK = 'hcp'
local STEP_SECONDS = 2
local WAIT_SECONDS = 4
local FILLER = 600

local running = false
local pending = {}
local serial = 0
local watcher = nil

local function Secret(value)
    return issecretvalue and issecretvalue(value) or false
end

-- A test whisper of ours: the scanner must not take it for a customer's.
function Probe.Owns(message)
    if not running or type(message) ~= 'string' or Secret(message) then return false end
    return message:find('^' .. MARK .. '%d+ ') ~= nil
end

local function Say(text)
    print('|cffffd100HironCraft chat limit:|r ' .. text)
end

local function Watch()
    if watcher then return end
    watcher = CreateFrame('Frame')
    watcher:RegisterEvent('CHAT_MSG_WHISPER')
    watcher:SetScript('OnEvent', function(_, _, text)
        if not running or Secret(text) or type(text) ~= 'string' then return end
        local id = text:match('^' .. MARK .. '(%d+) ')
        local callback = id and pending[id]
        if callback then
            pending[id] = nil
            callback(text)
        end
    end)
end

-- Sends one test whisper and hands what arrived (nil when nothing did) to
-- the callback, a moment later so that the next one is not sent too fast.
-- The body may be made from the whisper's prefix, for an exact total length.
local function Try(body, callback)
    serial = serial + 1
    local id = tostring(serial)
    local prefix = MARK .. id .. ' '
    if type(body) == 'function' then body = body(prefix) end
    local done = false
    local function Finish(received)
        if done then return end
        done = true
        pending[id] = nil
        C_Timer.After(STEP_SECONDS, function() callback(received, prefix) end)
    end
    pending[id] = Finish
    SendChatMessage(prefix .. body, 'WHISPER', nil, UnitName('player'))
    C_Timer.After(WAIT_SECONDS, function() Finish(nil) end)
end

local function Letters(text)
    return #(text:gsub('[\128-\191]', ''))
end

-- A link's [name] as it is shown, without its quality icon.
local function ShownName(link)
    local name = link:match('|h(%[.-%])|h') or ''
    return (name:gsub('|A.-|a', ''))
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

local function CountLinks(text)
    return select(2, text:gsub('|Hitem:', ''))
end

function Probe.Run()
    if running then Say('already running.'); return false end
    if not (C_Timer and C_Timer.After and SendChatMessage and CreateFrame) then return false end
    running = true
    Watch()
    local result = { at = time and time() or 0, lines = {} }
    local function Note(text)
        result.lines[#result.lines + 1] = text
        Say(text)
    end
    local function Done()
        running = false
        local settings = HironCraftScan.DB and HironCraftScan.DB.settings
        if type(settings) == 'table' then settings.chat_limit_probe = result end
        Say('done. Send a screenshot of these lines (or /reload: the result is saved).')
    end
    Say('measuring with a few whispers to yourself, about half a minute...')

    local plain, icon = BagLinks()
    local steps = {}
    local function Next()
        local step = table.remove(steps, 1)
        if step then step() else Done() end
    end

    -- 1. Letters: a long plain message is cut to what a whisper holds. Where a
    -- long message does not arrive at all, the longest that does is searched.
    steps[#steps + 1] = function()
        Try(string.rep('x', FILLER), function(received, prefix)
            if received then
                result.letters = #received
                Note(string.format('a whisper holds %d letters (sent %d).', #received, #prefix + FILLER))
                return Next()
            end
            local low, high = 100, #prefix + FILLER
            local function Search()
                if high - low <= 1 then
                    result.letters, result.rejected = low, true
                    Note(string.format('a whisper holds %d letters; a longer one does not arrive at all.', low))
                    return Next()
                end
                local middle = math.floor((low + high) / 2)
                Try(function(nextPrefix) return string.rep('x', middle - #nextPrefix) end, function(arrived)
                    if arrived and #arrived == middle then low = middle else high = middle end
                    Search()
                end)
            end
            Search()
        end)
    end

    -- 2. Cyrillic: counted by letters or by bytes?
    steps[#steps + 1] = function()
        Try(string.rep('я', 400), function(received, prefix)
            if received then
                result.cyrillicLetters, result.cyrillicBytes = Letters(received), #received
                Note(string.format('Cyrillic: %d letters, %d bytes arrived.', Letters(received), #received))
            else
                Note('Cyrillic: a long message did not arrive.')
            end
            Next()
        end)
    end

    -- 3 and 4. What a link takes: three of them and a filler; the filler that
    -- is left tells how much the links took.
    local function LinkStep(link, key, label)
        steps[#steps + 1] = function()
            if not link then
                Note(label .. ': no such item in the bags, not measured.')
                return Next()
            end
            Try(string.rep(link, 3) .. ' ' .. string.rep('x', FILLER), function(received, prefix)
                local name = ShownName(link)
                local entry = { name = name, nameLetters = Letters(name), bytes = #link }
                result[key] = entry
                if received and CountLinks(received) == 3 and result.letters then
                    local filler = #(received:match('(x*)$') or '')
                    entry.cost = (result.letters - #prefix - 1 - filler) / 3
                    Note(string.format('%s %s: takes %s letters (its name is %d, the link is %d bytes).',
                        label, name, tostring(entry.cost), entry.nameLetters, #link))
                else
                    entry.arrivedLinks = received and CountLinks(received) or nil
                    Note(string.format('%s %s: %s.', label, name,
                        received and ('only ' .. CountLinks(received) .. ' of 3 links arrived') or 'the message did not arrive'))
                end
                Next()
            end)
        end
    end
    LinkStep(plain, 'plain', 'link')
    LinkStep(icon, 'icon', 'link with a quality icon')

    -- 5. Bytes: as many links as the letters allow, whole?
    steps[#steps + 1] = function()
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
            return Next()
        end
        local count = math.floor((result.letters - #MARK - 4) / bestCost)
        local function Attempt()
            if count < 1 then
                Note('bytes: no message of links arrived whole.')
                return Next()
            end
            Try(string.rep(best, count), function(received, prefix)
                if received and CountLinks(received) == count then
                    result.whole = { links = count, bytes = #prefix + count * #best }
                    Note(string.format('bytes: %d links, %d bytes arrived whole.', count, result.whole.bytes))
                    return Next()
                end
                result.cut = result.cut or { links = count, bytes = #prefix + count * #best,
                    arrived = received and CountLinks(received) or nil }
                count = count - 1
                Attempt()
            end)
        end
        Attempt()
    end

    Next()
    return true
end

if SlashCmdList then
    SLASH_HIRONCRAFTCHATLIMIT1 = '/hcchatlimit'
    SlashCmdList.HIRONCRAFTCHATLIMIT = function() Probe.Run() end
end
