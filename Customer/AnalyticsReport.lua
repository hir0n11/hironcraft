local Scan = select(2, ...)

-- Counts for the analytics window, built from the journal's events (see
-- AnalyticsLog.lua) only while the window is open.
--
-- A conversation is one request row, followed through the rows that replaced
-- it ("LF tailor" -> "[Cloak]"). It is greeted when any of its rows was, and
-- crafted when its last row got a delivered order. A request for a profession
-- or a slot is counted under the item that was finally crafted.
local M = {}
Scan.AnalyticsReport = M

local MENTION_SAME_SECONDS = 60
-- Two linked accounts see the same chat line a moment apart.
local SAME_REQUEST_SECONDS = 180
local DAY = 24 * 60 * 60

local function BaseKey(name)
    if type(name) ~= 'string' or name == '' then return nil end
    return (name:match('^([^-]+)') or name):lower()
end
M.BaseKey = BaseKey

local function SameCrafter(filter, name)
    return BaseKey(filter) == BaseKey(name)
end

-- Which row of the item table an event belongs to.
local function Subject(event)
    if event.i then return 'item:' .. event.i, { kind = 'item', itemID = event.i, ppID = event.p } end
    if event.r then return 'recipe:' .. event.r, { kind = 'recipe', recipeID = event.r, ppID = event.p } end
    if event.s then
        return 'slot:' .. tostring(event.p) .. ':' .. event.s,
            { kind = 'slot', slot = event.s, label = event.lb, ppID = event.p }
    end
    if event.g then return 'generic', { kind = 'generic' } end
    if event.p then return 'prof:' .. event.p, { kind = 'profession', ppID = event.p } end
    return 'unknown', { kind = 'unknown' }
end

local function NewRow(key, info)
    local row = {
        key = key, mentions = 0, requests = 0, greetings = 0, crafted = 0,
        orders = 0, declined = 0, tips = 0, tipped = 0,
    }
    for field, value in pairs(info) do row[field] = value end
    return row
end

local function NewCustomer(key, name)
    return {
        key = key, name = name, requests = 0, greetings = 0, crafted = 0,
        orders = 0, declined = 0, tips = 0, tipped = 0, maxTip = 0, lastOrder = nil,
    }
end

local function Hours()
    local list = {}
    for hour = 0, 23 do list[hour] = 0 end
    return list
end

local function Weekdays()
    return { 0, 0, 0, 0, 0, 0, 0 }
end

-- 1 = Monday ... 7 = Sunday.
local function Weekday(t)
    local wday = tonumber(date('%w', t)) or 0
    return wday == 0 and 7 or wday
end

local function Hour(t)
    return tonumber(date('%H', t)) or 0
end

-- filters: from, to, ppID, crafter, tier ('generous' / 'regular' /
-- 'stingy' / 'none'), side ('H' / 'A').
-- context.markOf(customer) gives the customer's coin, context.itemProf(itemID)
-- the profession that makes an item.
function M.Build(chunks, filters, context)
    filters = filters or {}
    context = context or {}
    local from, to = filters.from or 0, filters.to or math.huge
    local markOf = context.markOf or function() return nil end
    local itemProf = context.itemProf or function() return nil end

    local requests, replacedBy, greeted, links, orders, tokenOrders = {}, {}, {}, {}, {}, {}
    local mentions = {}
    for _, events in ipairs(chunks or {}) do
        for _, event in ipairs(events) do
            local kind = event.k
            if kind == 'r' and event.id then
                local seen = requests[event.id]
                if not seen or event.t < seen.t then requests[event.id] = event end
            elseif kind == 'x' and event.id and event.to then
                replacedBy[event.id] = event.to
            elseif kind == 'g' and event.id then
                local seen = greeted[event.id]
                if not seen or event.t < seen.t then greeted[event.id] = event end
            elseif kind == 'l' and event.id then
                local seen = links[event.id]
                if not seen or event.t > seen.t then links[event.id] = event end
            elseif kind == 'd' and event.o ~= nil then
                local key = tostring(event.o) .. ':' .. tostring(event.st)
                if not orders[key] then orders[key] = event end
                if event.id then tokenOrders[event.id] = key end
            elseif kind == 'm' and event.i then
                mentions[#mentions + 1] = event
            end
        end
    end

    local function OrderOf(orderID)
        if orderID == nil then return nil end
        return orders[tostring(orderID) .. ':f'] or orders[tostring(orderID) .. ':r']
    end

    -- The rows of one conversation: a row and the rows that replaced it, and
    -- the same request seen by two linked accounts (the same customer asking
    -- for the same thing within a few minutes, recorded on each).
    local parent = {}
    local function Find(token)
        local root, guard = token, 0
        while parent[root] and guard < 50 do
            root = parent[root]
            guard = guard + 1
        end
        if root ~= token then parent[token] = root end
        return root
    end
    local function Union(lhs, rhs)
        local a, b = Find(lhs), Find(rhs)
        if a ~= b then parent[a] = b end
    end
    for old, new in pairs(replacedBy) do Union(old, new) end
    local sameAsked = {}
    for _, request in pairs(requests) do
        local who = BaseKey(request.c)
        if who then
            local key = who .. '|' .. (Subject(request))
            sameAsked[key] = sameAsked[key] or {}
            table.insert(sameAsked[key], request)
        end
    end
    for _, list in pairs(sameAsked) do
        table.sort(list, function(lhs, rhs) return lhs.t < rhs.t end)
        for index = 2, #list do
            local previous, current = list[index - 1], list[index]
            if (previous.m or 'own') ~= (current.m or 'own')
                and current.t - previous.t <= SAME_REQUEST_SECONDS then
                Union(current.id, previous.id)
            end
        end
    end

    local groups = {}
    local function Add(token)
        local root = Find(token)
        groups[root] = groups[root] or {}
        table.insert(groups[root], token)
    end
    for token in pairs(requests) do Add(token) end
    for token in pairs(greeted) do
        if not requests[token] then Add(token) end
    end

    -- The coin, where a customer with delivered orders and none on record
    -- (orders from before tips were kept) counts as silver.
    local ordered = {}
    for _, order in pairs(orders) do
        local who = order.st == 'f' and BaseKey(order.c)
        if who then ordered[who] = true end
    end
    local function MarkOf(name)
        local mark = markOf(name)
        if mark then return mark end
        local who = BaseKey(name)
        return who and ordered[who] and 'regular' or 'none'
    end

    local function PassesCommon(ppID, crafters, customer, side)
        if filters.ppID and ppID ~= filters.ppID then return false end
        if filters.crafter then
            local match = false
            for _, name in ipairs(crafters) do
                if name and SameCrafter(filters.crafter, name) then match = true end
            end
            if not match then return false end
        end
        if filters.tier and MarkOf(customer) ~= filters.tier then return false end
        if filters.side and side ~= filters.side then return false end
        return true
    end

    local report = {
        rows = {}, customers = {},
        hours = { requests = Hours(), greetings = Hours(), orders = Hours() },
        weekdays = { requests = Weekdays(), greetings = Weekdays(), orders = Weekdays() },
        totals = { mentions = 0, requests = 0, greetings = 0, crafted = 0, orders = 0,
            declined = 0, tips = 0, tipped = 0 },
        tiers = { generous = 0, regular = 0, stingy = 0, none = 0 },
    }
    local rows, customers = {}, {}
    local function Row(key, info)
        if not rows[key] then rows[key] = NewRow(key, info) end
        return rows[key]
    end
    local function Customer(name)
        local key = BaseKey(name)
        if not key then return nil end
        if not customers[key] then customers[key] = NewCustomer(key, name) end
        return customers[key]
    end

    -- Orders that belong to a conversation take its side and subject.
    local orderConversation = {}

    for _, tokens in pairs(groups) do
        -- The first request starts it; the latest is the most precise.
        local first, request, greeting = nil, nil, nil
        for _, token in ipairs(tokens) do
            local candidate = requests[token]
            if candidate and (not first or candidate.t < first.t) then first = candidate end
            if candidate and (not request or candidate.t > request.t) then request = candidate end
            local greetedAt = greeted[token]
            if greetedAt and (not greeting or greetedAt.t < greeting.t) then greeting = greetedAt end
        end
        -- The order it ended in: a delivered one over a declined one.
        local order, link = nil, nil
        for _, token in ipairs(tokens) do
            local candidateLink = links[token]
            local candidateOrder = candidateLink and OrderOf(candidateLink.o)
                or (tokenOrders[token] and orders[tokenOrders[token]])
            if candidateOrder and (not order or (candidateOrder.st == 'f' and order.st ~= 'f')) then
                order = candidateOrder
            end
            if candidateLink and (not link or (candidateLink.st == 'f' and link.st ~= 'f')) then
                link = candidateLink
            end
        end
        local crafted = (order and order.st == 'f') or (not order and link and link.st == 'f')
        local declined = (order and order.st == 'r') or (not order and link and link.st == 'r')
        local side = greeting and greeting.f or request and request.f
        if order then orderConversation[tostring(order.o) .. ':' .. order.st] = { side = side, request = request } end

        local started = first or request
        if started and started.t >= from and started.t <= to then
            local subjectEvent = (crafted and order and order.i) and order or request
            local ppID = (order and order.p) or request.p or (request.i and itemProf(request.i))
            local customer = request.c
            if PassesCommon(ppID, { request.x, order and order.x, greeting and greeting.x }, customer, side) then
                local key, info = Subject(subjectEvent)
                if info.ppID == nil then info.ppID = ppID end
                local row = Row(key, info)
                row.requests = row.requests + 1
                report.totals.requests = report.totals.requests + 1
                report.hours.requests[Hour(started.t)] = report.hours.requests[Hour(started.t)] + 1
                report.weekdays.requests[Weekday(started.t)] = report.weekdays.requests[Weekday(started.t)] + 1
                local person = Customer(customer)
                if person then person.requests = person.requests + 1 end
                if greeting then
                    row.greetings = row.greetings + 1
                    report.totals.greetings = report.totals.greetings + 1
                    report.hours.greetings[Hour(greeting.t)] = report.hours.greetings[Hour(greeting.t)] + 1
                    report.weekdays.greetings[Weekday(greeting.t)] = report.weekdays.greetings[Weekday(greeting.t)] + 1
                    if person then person.greetings = person.greetings + 1 end
                    if crafted then
                        row.crafted = row.crafted + 1
                        report.totals.crafted = report.totals.crafted + 1
                        if person then person.crafted = person.crafted + 1 end
                    end
                end
            end
        end
    end

    -- Every order delivered or declined in the period, conversation or not.
    local tierSeen = {}
    for key, order in pairs(orders) do
        if order.t >= from and order.t <= to then
            local conversation = orderConversation[key]
            local side = conversation and conversation.side or order.f
            local ppID = order.p or (order.i and itemProf(order.i))
            local request = conversation and conversation.request
            if PassesCommon(ppID, { order.x, request and request.x }, order.c, side) then
                local subjectKey, info = Subject(order)
                if info.ppID == nil then info.ppID = ppID end
                local row = Row(subjectKey, info)
                local person = Customer(order.c)
                if order.st == 'f' then
                    row.orders = row.orders + 1
                    report.totals.orders = report.totals.orders + 1
                    report.hours.orders[Hour(order.t)] = report.hours.orders[Hour(order.t)] + 1
                    report.weekdays.orders[Weekday(order.t)] = report.weekdays.orders[Weekday(order.t)] + 1
                    if order.tip then
                        row.tips = row.tips + order.tip
                        row.tipped = row.tipped + 1
                        report.totals.tips = report.totals.tips + order.tip
                        report.totals.tipped = report.totals.tipped + 1
                    end
                    if person then
                        person.orders = person.orders + 1
                        if order.tip then
                            person.tips = person.tips + order.tip
                            person.tipped = person.tipped + 1
                            person.maxTip = math.max(person.maxTip, order.tip)
                        end
                        if not person.lastOrder or order.t > person.lastOrder then person.lastOrder = order.t end
                        if not tierSeen[person.key] then
                            tierSeen[person.key] = true
                            local mark = MarkOf(order.c)
                            report.tiers[mark] = (report.tiers[mark] or 0) + 1
                        end
                    end
                else
                    row.declined = row.declined + 1
                    report.totals.declined = report.totals.declined + 1
                    if person then person.declined = person.declined + 1 end
                end
            end
        end
    end

    -- Mentions in chat: the same customer repeating the same item within a
    -- minute is one mention, also when two linked accounts saw it.
    table.sort(mentions, function(lhs, rhs) return lhs.t < rhs.t end)
    local lastSeen = {}
    for _, mention in ipairs(mentions) do
        local who = BaseKey(mention.c)
        local key = mention.i .. ':' .. (who or '')
        local previous = lastSeen[key]
        local repeated = previous and (who and mention.t - previous <= MENTION_SAME_SECONDS
            or (not who and mention.t == previous))
        lastSeen[key] = mention.t
        if not repeated and mention.t >= from and mention.t <= to then
            local ppID = mention.p or itemProf(mention.i)
            if PassesCommon(ppID, {}, mention.c, mention.f) and not filters.crafter then
                local row = Row('item:' .. mention.i, { kind = 'item', itemID = mention.i, ppID = ppID })
                row.mentions = row.mentions + 1
                report.totals.mentions = report.totals.mentions + 1
            end
        end
    end

    for _, row in pairs(rows) do
        row.conversion = row.greetings > 0 and row.crafted / row.greetings or nil
        row.averageTip = row.tipped > 0 and row.tips / row.tipped or nil
        report.rows[#report.rows + 1] = row
    end
    for _, person in pairs(customers) do
        person.conversion = person.greetings > 0 and person.crafted / person.greetings or nil
        person.averageTip = person.tipped > 0 and person.tips / person.tipped or nil
        person.mark = MarkOf(person.name)
        if not filters.tier or person.mark == filters.tier then
            report.customers[#report.customers + 1] = person
        end
    end
    local totals = report.totals
    totals.conversion = totals.greetings > 0 and totals.crafted / totals.greetings or nil
    totals.averageTip = totals.tipped > 0 and totals.tips / totals.tipped or nil
    return report
end

-- Resourcefulness on crafting orders: per reagent (and profession) how often
-- and how much of the customer's reagents came back and what it was worth
-- then; and the chance, overall and per profession. filters: from, to,
-- ppID, crafter.
function M.BuildReturns(chunks, filters)
    filters = filters or {}
    local from, to = filters.from or 0, filters.to or math.huge
    local rows, byProfession, seen = {}, {}, {}
    local totals = { crafts = 0, procs = 0, quantity = 0, value = 0, customerValue = 0, ownValue = 0, unpriced = 0 }
    for _, events in ipairs(chunks or {}) do
        for _, event in ipairs(events) do
            if event.k == 'c' and event.t >= from and event.t <= to
                and (not filters.ppID or event.p == filters.ppID)
                and (not filters.crafter or SameCrafter(filters.crafter, event.x)) then
                -- The same craft once, also when it came twice through an exchange.
                local key = tostring(event.o) .. ':' .. tostring(event.op or event.t) .. ':' .. tostring(event.x)
                if not seen[key] then
                    seen[key] = true
                    local profession = event.p or 0
                    byProfession[profession] = byProfession[profession] or { ppID = event.p, crafts = 0, procs = 0 }
                    byProfession[profession].crafts = byProfession[profession].crafts + 1
                    totals.crafts = totals.crafts + 1
                    local returned = event.pr or (type(event.rs) == 'table' and #event.rs > 0)
                    if returned then
                        byProfession[profession].procs = byProfession[profession].procs + 1
                        totals.procs = totals.procs + 1
                    end
                    -- Only what came back from the customer's reagents.
                    for _, reagent in ipairs(type(event.rs) == 'table' and event.rs or {}) do
                        if reagent.c then
                            local rowKey = tostring(reagent.i) .. ':' .. tostring(event.p)
                            local row = rows[rowKey]
                            if not row then
                                row = { key = rowKey, kind = 'item', itemID = reagent.i, ppID = event.p, procs = 0,
                                    quantity = 0, customerQuantity = 0, ownQuantity = 0, value = 0,
                                    customerValue = 0, ownValue = 0, priced = 0, unpriced = 0 }
                                rows[rowKey] = row
                            end
                            local count = tonumber(reagent.n) or 0
                            local value = reagent.v and reagent.v * count or 0
                            row.procs = row.procs + 1
                            row.quantity = row.quantity + count
                            row.value = row.value + value
                            if reagent.v then row.priced = row.priced + count else row.unpriced = row.unpriced + count end
                            if reagent.c then
                                row.customerQuantity = row.customerQuantity + count
                                row.customerValue = row.customerValue + value
                                totals.customerValue = totals.customerValue + value
                            else
                                row.ownQuantity = row.ownQuantity + count
                                row.ownValue = row.ownValue + value
                                totals.ownValue = totals.ownValue + value
                            end
                            if not row.lastAt or event.t > row.lastAt then row.lastAt = event.t end
                            totals.quantity = totals.quantity + count
                            totals.value = totals.value + value
                            if not reagent.v then totals.unpriced = totals.unpriced + count end
                        end
                    end
                end
            end
        end
    end
    local list, professions = {}, {}
    for _, row in pairs(rows) do
        row.unitPrice = row.priced > 0 and row.value / row.priced or nil
        list[#list + 1] = row
    end
    for _, profession in pairs(byProfession) do
        profession.chance = profession.crafts > 0 and profession.procs / profession.crafts or nil
        professions[#professions + 1] = profession
    end
    table.sort(professions, function(lhs, rhs) return lhs.crafts > rhs.crafts end)
    totals.chance = totals.crafts > 0 and totals.procs / totals.crafts or nil
    return { rows = list, totals = totals, professions = professions }
end

-- Period presets: from, to.
function M.Range(preset, now)
    now = now or time()
    local today = date('*t', now)
    local midnight = time({ year = today.year, month = today.month, day = today.day, hour = 0 })
    if preset == 'today' then return midnight, now end
    if preset == 'yesterday' then return midnight - DAY, midnight - 1 end
    if preset == '7d' then return midnight - 6 * DAY, now end
    if preset == '30d' then return midnight - 29 * DAY, now end
    if preset == 'month' then
        return time({ year = today.year, month = today.month, day = 1, hour = 0 }), now
    end
    return 0, now
end

-- "25.09.2026" or "25.09" (this year); the start of that day, or its end.
function M.ParseDate(text, endOfDay, now)
    if type(text) ~= 'string' then return nil end
    local day, month, year = text:match('^%s*(%d%d?)[%.%-/](%d%d?)[%.%-/](%d%d%d?%d?)%s*$')
    if not day then
        day, month = text:match('^%s*(%d%d?)[%.%-/](%d%d?)%s*$')
        year = date('*t', now or time()).year
    end
    day, month, year = tonumber(day), tonumber(month), tonumber(year)
    if not (day and month and year) or month < 1 or month > 12 or day < 1 or day > 31 then return nil end
    if year < 100 then year = 2000 + year end
    local t = time({ year = year, month = month, day = day, hour = 0 })
    return endOfDay and (t + DAY - 1) or t
end

function M.FormatDate(t)
    return t and t > 0 and date('%d.%m.%Y', t) or ''
end
