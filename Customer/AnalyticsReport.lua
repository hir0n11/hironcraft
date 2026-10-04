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

-- Legacy presence marks cover five minutes. New ones carry exact [t, e)
-- intervals; both formats are unioned, never added once per linked account.
local PRESENCE_SLOT = 300
-- Two linked accounts see the same chat line a moment apart.
local SAME_REQUEST_SECONDS = 180

local function BaseKey(name)
    if type(name) ~= 'string' or name == '' then return nil end
    return (name:match('^([^-]+)') or name):lower()
end
M.BaseKey = BaseKey

local function SameCrafter(filter, name)
    return BaseKey(filter) == BaseKey(name)
end

-- Whether an event counts for a crafter pool profile (AnalyticsProfiles.lua):
-- by the character that recorded it. Orders and crafts from before recorders
-- were kept go by their crafter; anything else that old counts only for the
-- profile that took over the earlier history.
local function InProfile(profile, event)
    local who = event.w
    if who == nil and (event.k == 'd' or event.k == 'c') then who = event.x end
    if who ~= nil then return profile.chars[who] == true end
    return profile.legacy == true
end
M.InProfile = InProfile

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
        key = key, requests = 0, greetings = 0, crafted = 0,
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

-- The local hour, weekday and calendar keys of a moment, asked from the clock
-- once per quarter of an hour (every time zone offset and every change of the
-- clocks falls on one) instead of four times per counted event.
local slots, slotCount = {}, 0
local function Slot(t)
    local key = math.floor(t / 900)
    local slot = slots[key]
    if not slot then
        if slotCount >= 50000 then slots, slotCount = {}, 0 end
        local at = key * 900
        slot = { hour = Hour(at), weekday = Weekday(at), day = date('%Y-%m-%d', at), month = date('%Y-%m', at) }
        slots[key] = slot
        slotCount = slotCount + 1
    end
    return slot
end

-- Construct local calendar boundaries, never assuming a day has 86400 seconds
-- (DST), or that every month has the same number of days.
local function Midnight(year, month, day)
    return time({ year = year, month = month, day = day, hour = 0, min = 0, sec = 0 })
end

function M.CalendarRange(mode, anchor)
    local d = date('*t', anchor or time())
    if mode == 'year' then return Midnight(d.year, 1, 1), Midnight(d.year + 1, 1, 1) - 1 end
    if mode == 'month' then return Midnight(d.year, d.month, 1), Midnight(d.year, d.month + 1, 1) - 1 end
    local day = mode == 'week' and d.day - Weekday(anchor or time()) + 1 or d.day
    return Midnight(d.year, d.month, day), Midnight(d.year, d.month, day + (mode == 'week' and 7 or 1)) - 1
end

function M.ShiftCalendar(mode, anchor, direction)
    local d = date('*t', (M.CalendarRange(mode, anchor)))
    if mode == 'year' then return Midnight(d.year + direction, 1, 1) end
    if mode == 'month' then return Midnight(d.year, d.month + direction, 1) end
    return Midnight(d.year, d.month, d.day + direction * (mode == 'week' and 7 or 1))
end

function M.CalendarBuckets(mode, anchor)
    local first, last = M.CalendarRange(mode, anchor)
    local buckets, cursor = {}, first
    local unit = mode == 'year' and 'month' or 'day'
    while cursor <= last do
        local next_ = M.ShiftCalendar(unit, cursor, 1)
        buckets[#buckets + 1] = { from = cursor, to = next_ - 1,
            key = date(unit == 'month' and '%Y-%m' or '%Y-%m-%d', cursor), unit = unit }
        cursor = next_
    end
    return buckets
end

-- filters: from, to, ppID, crafter, tier ('diamond' / 'generous' / 'regular' /
-- 'stingy' / 'none'), side ('H' / 'A'), profile ({ chars, legacy }: only the
-- events of that profile exist for the report).
-- context.markOf(customer) gives the customer's coin, context.itemProf(itemID)
-- the profession that makes an item.
function M.Build(chunks, filters, context)
    filters = filters or {}
    context = context or {}
    local from, to = filters.from or 0, filters.to or math.huge
    local markOf = context.markOf or function() return nil end
    local itemProf = context.itemProf or function() return nil end

    local requests, replacedBy, greeted, links, orders, tokenOrders = {}, {}, {}, {}, {}, {}
    -- Time online: 5-minute slots of any account, each counted once.
    local online, firstOnline = {}, nil
    local profile = filters.profile
    for _, events in ipairs(chunks or {}) do
        for _, event in ipairs(events) do
            local kind = (not profile or InProfile(profile, event)) and event.k or nil
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
            elseif kind == 'p' then
                local start = event.e and event.t or math.floor(event.t / PRESENCE_SLOT) * PRESENCE_SLOT
                local finish = tonumber(event.e) or start + PRESENCE_SLOT
                firstOnline = math.min(firstOnline or start, start)
                if not filters.side or not event.f or event.f == filters.side then
                    if finish > start then online[#online + 1] = { start, finish } end
                end
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
        -- crafted: greeted conversations that ended in an order, by the time
        -- of the greeting, for the conversion of each hour and day.
        hours = { requests = Hours(), greetings = Hours(), crafted = Hours(), orders = Hours(),
            tips = Hours(), tipsEstimated = Hours(), tipsMissing = Hours() },
        weekdays = { requests = Weekdays(), greetings = Weekdays(), crafted = Weekdays(), orders = Weekdays(),
            tips = Weekdays(), tipsEstimated = Weekdays(), tipsMissing = Weekdays() },
        calendar = { days = {}, months = {} },
        totals = { requests = 0, greetings = 0, crafted = 0, orders = 0,
            declined = 0, tips = 0, tipped = 0 },
        tiers = { diamond = 0, generous = 0, regular = 0, stingy = 0, none = 0 },
    }
    local rows, customers = {}, {}
    local function CountTime(metric, t, amount)
        if t < from or t > to then return end
        amount = amount or 1
        local slot = Slot(t)
        local hours, weekdays = report.hours[metric], report.weekdays[metric]
        hours[slot.hour] = (hours[slot.hour] or 0) + amount
        weekdays[slot.weekday] = (weekdays[slot.weekday] or 0) + amount
        local days, months = report.calendar.days, report.calendar.months
        local day, month = days[slot.day], months[slot.month]
        if not day then day = {} days[slot.day] = day end
        if not month then month = {} months[slot.month] = month end
        day[metric] = (day[metric] or 0) + amount
        month[metric] = (month[metric] or 0) + amount
    end
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
        if started then
            local subjectEvent = (crafted and order and order.i) and order or request
            local ppID = (order and order.p) or request.p or (request.i and itemProf(request.i))
            local customer = request.c
            if PassesCommon(ppID, { request.x, order and order.x, greeting and greeting.x }, customer, side) then
                -- Charts use the actual timestamp of each event, including a
                -- greeting after midnight for a request from the previous day.
                CountTime('requests', started.t)
                if greeting then
                    CountTime('greetings', greeting.t)
                    if crafted then CountTime('crafted', greeting.t) end
                end
                if started.t >= from and started.t <= to then
                    local key, info = Subject(subjectEvent)
                    if info.ppID == nil then info.ppID = ppID end
                    local row = Row(key, info)
                    row.requests = row.requests + 1
                    report.totals.requests = report.totals.requests + 1
                    local person = Customer(customer)
                    if person then person.requests = person.requests + 1 end
                    if greeting then
                        row.greetings = row.greetings + 1
                        report.totals.greetings = report.totals.greetings + 1
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
    end

    -- Tips as received: the customer's tip less the Artisan's Consortium's
    -- cut. Orders recorded before the cut was kept get it at the share the
    -- recorded ones show, marked as an estimate; with none recorded, as set.
    local cutFrom, cutSum = 0, 0
    for _, order in pairs(orders) do
        if order.st == 'f' and order.tip and order.cut and order.tip > 0 then
            cutFrom, cutSum = cutFrom + order.tip, cutSum + order.cut
        end
    end
    local cutShare = cutFrom > 0 and cutSum / cutFrom or nil
    local function Received(order)
        if not order.tip then return nil end
        if order.tip == 0 then return 0 end
        if order.cut then return math.max(0, order.tip - order.cut) end
        report.totals.tipsEstimated = true
        if cutShare then return math.floor(order.tip * (1 - cutShare) + 0.5), true end
        return order.tip, true
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
                    CountTime('orders', order.t)
                    local tip, estimated = Received(order)
                    if tip then
                        CountTime('tips', order.t, tip)
                        if estimated then CountTime('tipsEstimated', order.t) end
                        row.tips = row.tips + tip
                        row.tipped = row.tipped + 1
                        report.totals.tips = report.totals.tips + tip
                        report.totals.tipped = report.totals.tipped + 1
                    else
                        CountTime('tipsMissing', order.t)
                    end
                    if person then
                        person.orders = person.orders + 1
                        if tip then
                            person.tips = person.tips + tip
                            person.tipped = person.tipped + 1
                            person.maxTip = math.max(person.maxTip, tip)
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

    -- Merge account/session overlaps, clip to the selected range, and split
    -- at local hour boundaries (including half-hour time zones and DST).
    report.hours.online, report.hours.possible = Hours(), Hours()
    report.weekdays.online, report.weekdays.possible = Weekdays(), Weekdays()
    local until_ = math.min(to + 1, time())
    local function CountInterval(metric, start, finish)
        local cursor, last = math.max(from, start), math.min(until_, finish)
        while cursor < last do
            local d = date('*t', cursor)
            local next_ = math.min(last, cursor + (60 - d.min) * 60 - d.sec)
            local minutes = (next_ - cursor) / 60
            CountTime(metric, cursor, minutes)
            if metric == 'online' then report.totals.online = (report.totals.online or 0) + minutes end
            cursor = next_
        end
    end
    table.sort(online, function(a, b) return a[1] < b[1] end)
    local start, finish
    for _, interval in ipairs(online) do
        if finish and interval[1] <= finish then
            finish = math.max(finish, interval[2])
        else
            if finish then CountInterval('online', start, finish) end
            start, finish = interval[1], interval[2]
        end
    end
    if finish then CountInterval('online', start, finish) end
    if firstOnline then
        CountInterval('possible', firstOnline, until_)
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
                and (not filters.profile or InProfile(filters.profile, event))
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
    local midnight = Midnight(today.year, today.month, today.day)
    if preset == '1h' then return now - 60 * 60, now end
    if preset == 'today' then return midnight, now end
    if preset == 'yesterday' then return M.ShiftCalendar('day', midnight, -1), midnight - 1 end
    if preset == '7d' then return M.ShiftCalendar('day', midnight, -6), now end
    if preset == '30d' then return M.ShiftCalendar('day', midnight, -29), now end
    if preset == 'week' or preset == 'month' or preset == 'year' then
        return (M.CalendarRange(preset, now)), now
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
    local t = Midnight(year, month, day)
    local actual = date('*t', t)
    if actual.year ~= year or actual.month ~= month or actual.day ~= day then return nil end
    return endOfDay and (M.ShiftCalendar('day', t, 1) - 1) or t
end

function M.FormatDate(t)
    return t and t > 0 and date('%d.%m.%Y', t) or ''
end
