local Scan = select(2, ...)

-- The matching behind the chat filter: a message is read once into what the
-- rules look at (its words, its links, its raid icons), and each rule is
-- compiled once into a function over that.
--
-- Two kinds of rules. A key is a word or a phrase, found anywhere in the
-- message or only as whole words. An expression is written the way Global
-- Ignore List writes its filters, so those carry over unchanged:
--
--   ([word=anal] or [contains=analan]) and ([link] or [words=2])
--
-- Tags: [word=x] a whole word, [contains=x] anywhere, [words=n] exactly n
-- words, [link] any link, [item] [spell] [achievement] [talent] [pet] with an
-- optional =ID, [trade] [guild] [journal] [mount] [outfit] [community] link
-- kinds, [icon] / [icon=n] raid icons, [nonlatin] CJK text, [channel=n] and
-- [chname=name] where it was said. A backslash lets a space, a bracket or a
-- parenthesis into a value. As in Global Ignore List, "or" binds tighter than
-- "and" ("a b or c" is a and (b or c)), "not" tighter than both, and two tags
-- side by side mean "and".
local E = {}
Scan.FilterEngine = E

-- Lower case, Cyrillic too: string.lower only knows ASCII.
function E.Lower(text)
    text = string.lower(text)
    if not text:find('\208', 1, true) then return text end
    text = text:gsub('\208([\144-\159])', function(c) return '\208' .. string.char(c:byte() + 32) end)
    text = text:gsub('\208([\160-\175])', function(c) return '\209' .. string.char(c:byte() - 32) end)
    return (text:gsub('\208\129', '\209\145'))
end

-- The message as it reads, links as their names: what keys look at, and
-- what the text selection tool shows (so a selected phrase is found again).
function E.PlainText(text)
    if type(text) ~= 'string' then return '' end
    text = text:gsub('|H.-|h%[?(.-)%]?|h', '%1')
    text = text:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|cn[%w_]+:', ''):gsub('|r', '')
    text = text:gsub('|A.-|a', ''):gsub('|T.-|t', '')
    text = text:gsub('%s+', ' ')
    return (text:match('^%s*(.-)%s*$'))
end

-- Links whose name is left out of the text, their IDs kept.
local ID_LINKS = { item = 'items', spell = 'spells', achievement = 'achievements', talent = 'talents',
    battlepet = 'pets' }
-- Links known by kind; their names stay in the text.
local KIND_LINKS = { trade = 'trade', clubfinder = 'guild', journal = 'journal', mount = 'mount',
    outfit = 'outfit', clubticket = 'community' }
local RAID_ICONS = { 'star', 'circle', 'diamond', 'triangle', 'moon', 'square', 'cross', 'x', 'skull', 'coin' }

-- Everything a rule may ask about one message.
function E.Analyze(message)
    local info = { items = {}, spells = {}, achievements = {}, talents = {}, pets = {}, kinds = {},
        links = 0, icons = 0, words = {} }
    local text = E.Lower(message or '')
    text = text:gsub('|h(%a+):([^|]*)|h(.-)|h', function(kind, data, name)
        local list = ID_LINKS[kind]
        -- [link] is any of these but a community invitation, as in Global
        -- Ignore List.
        if list or (KIND_LINKS[kind] and kind ~= 'clubticket') then info.links = info.links + 1 end
        if list then
            info[list][#info[list] + 1] = data:match('^([^:]*)')
            return ' '
        end
        info.kinds[KIND_LINKS[kind] or kind] = true
        return name
    end)
    text = text:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|cn[%w_]+:', ''):gsub('|r', '')
    text = text:gsub('|a.-|a', ''):gsub('|t.-|t', ''):gsub('||', '|')
    local count
    text, count = text:gsub('{rt%d}', ' ')
    info.icons = info.icons + count
    for _, icon in ipairs(RAID_ICONS) do
        text, count = text:gsub('{' .. icon .. '}', ' ')
        info.icons = info.icons + count
    end
    info.text = text
    for word in text:gmatch('%S+') do
        word = word:gsub('%p+$', '')
        if word ~= '' then info.words[#info.words + 1] = word end
    end
    info.nonlatin = text:find('[\227-\237]') ~= nil
    info.plain = E.Lower(E.PlainText(message or ''))
    return info
end

local function Contains(list, value)
    for _, entry in ipairs(list) do
        if entry == value then return true end
    end
    return false
end

local function IsWordByte(byte)
    return byte ~= nil and (byte >= 128 or (byte >= 48 and byte <= 57)
        or (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122))
end

-- A phrase standing on its own: no letter or digit right before or after.
function E.HasWhole(text, phrase)
    if phrase == '' then return false end
    local start = 1
    while true do
        local first, last = text:find(phrase, start, true)
        if not first then return false end
        if not IsWordByte(text:byte(first - 1)) and not IsWordByte(text:byte(last + 1)) then return true end
        start = first + 1
    end
end

-- A key: its text (as the selection tool gives it) and whether only whole
-- words count.
function E.CompileKey(text, whole)
    local phrase = E.Lower(E.PlainText(text or ''))
    if phrase == '' then return nil, 'empty' end
    if whole then
        return function(info) return E.HasWhole(info.plain, phrase) end
    end
    return function(info) return info.plain:find(phrase, 1, true) ~= nil end
end

local function Tag(name, value)
    if name == 'word' then
        return function(info) return Contains(info.words, value) end
    elseif name == 'contains' then
        return function(info) return info.text:find(value, 1, true) ~= nil end
    elseif name == 'words' then
        local count = tonumber(value)
        return function(info) return #info.words == count end
    elseif name == 'channel' then
        local number = tonumber(value)
        return function(_, context) return context.channelNumber == number end
    elseif name == 'chname' then
        return function(_, context) return (context.channelName or 'none') == value end
    elseif name == 'link' then
        return function(info) return info.links > 0 end
    elseif name == 'icon' then
        local least = tonumber(value) or 1
        return function(info) return info.icons >= least end
    elseif name == 'nonlatin' then
        return function(info) return info.nonlatin end
    end
    local list = ({ item = 'items', spell = 'spells', achievement = 'achievements', talent = 'talents',
        pet = 'pets' })[name]
    if list then
        if value == nil or value == '' then return function(info) return #info[list] > 0 end end
        return function(info) return Contains(info[list], value) end
    end
    local kind = ({ trade = 'trade', guild = 'guild', journal = 'journal', mount = 'mount', outfit = 'outfit',
        community = 'community' })[name]
    if kind then return function(info) return info.kinds[kind] == true end end
    return nil
end

-- Words, tags and parentheses; a backslash takes the next character as is.
local function Tokens(expression)
    local tokens, current, escaped = {}, {}, false
    local function Finish()
        if #current > 0 then tokens[#tokens + 1] = table.concat(current) end
        current = {}
    end
    for index = 1, #expression do
        local char = expression:sub(index, index)
        if escaped then
            current[#current + 1] = char
            escaped = false
        elseif char == '\\' then
            escaped = true
        elseif char == '(' or char == ')' then
            Finish()
            tokens[#tokens + 1] = char
        elseif char:match('%s') then
            Finish()
        else
            current[#current + 1] = char
        end
    end
    Finish()
    return tokens
end

-- A function of (info, context), or nil and why not.
function E.Compile(expression)
    if type(expression) ~= 'string' or expression:match('^%s*$') then return nil, 'empty' end
    local tokens = Tokens(expression)
    local position = 1
    local function Peek() return tokens[position] and E.Lower(tokens[position]) end
    local ParseAnd

    local function ParseUnary()
        local token = tokens[position]
        if not token then error('unexpected end', 0) end
        local lower = E.Lower(token)
        position = position + 1
        if lower == 'not' then
            local inner = ParseUnary()
            return function(info, context) return not inner(info, context) end
        elseif lower == '(' then
            local inner = ParseAnd()
            if tokens[position] ~= ')' then error('missing )', 0) end
            position = position + 1
            return inner
        end
        local body = token:match('^%[(.*)%]$')
        if not body then error('not a tag: ' .. token, 0) end
        local name, value = body:match('^([^=]*)=(.*)$')
        name = E.Lower(name or body):match('^%s*(.-)%s*$')
        local test = Tag(name, value and E.Lower(value))
        if not test then error('unknown tag: ' .. token, 0) end
        return test
    end

    local function ParseOr()
        local left = ParseUnary()
        while Peek() == 'or' do
            position = position + 1
            local lhs, rhs = left, ParseUnary()
            left = function(info, context) return lhs(info, context) or rhs(info, context) end
        end
        return left
    end

    function ParseAnd()
        local left = ParseOr()
        while tokens[position] and tokens[position] ~= ')' do
            if Peek() == 'and' then position = position + 1 end
            local lhs, rhs = left, ParseOr()
            left = function(info, context) return lhs(info, context) and rhs(info, context) end
        end
        return left
    end

    local ok, result = pcall(function()
        local compiled = ParseAnd()
        if tokens[position] then error('unexpected ' .. tokens[position], 0) end
        return compiled
    end)
    if not ok then return nil, result end
    return result
end
