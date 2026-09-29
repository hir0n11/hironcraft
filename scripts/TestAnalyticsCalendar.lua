-- Calendar arithmetic and dated buckets, independently of UI and compression.
local function stamp(y, m, d, h, min)
    return os.time({ year = y, month = m, day = d, hour = h or 0, min = min or 0, sec = 0 })
end
local now = stamp(2026, 9, 28, 12)
time = function(t) return t and os.time(t) or now end
date = os.date
local Scan = {}
assert(loadfile('Customer/AnalyticsReport.lua'))('HironCraft', Scan)
local R = Scan.AnalyticsReport
local function formatted(t) return date('%Y-%m-%d %H:%M:%S', t) end
local first, last = R.CalendarRange('week', now)
assert(formatted(first) == '2026-09-28 00:00:00' and formatted(last) == '2026-10-04 23:59:59')
first, last = R.CalendarRange('week', stamp(2027, 1, 1))
assert(formatted(first) == '2026-12-28 00:00:00' and formatted(last) == '2027-01-03 23:59:59')
assert(formatted(R.ShiftCalendar('month', stamp(2024, 1, 31), 1)) == '2024-02-01 00:00:00')
assert(formatted(R.ShiftCalendar('month', stamp(2024, 1, 1), -1)) == '2023-12-01 00:00:00')
assert(formatted(R.ShiftCalendar('year', stamp(2024, 2, 29), -1)) == '2023-01-01 00:00:00')
assert(#R.CalendarBuckets('month', stamp(2024, 2, 10)) == 29)
assert(#R.CalendarBuckets('month', stamp(2025, 2, 10)) == 28)
assert(#R.CalendarBuckets('month', stamp(2026, 9, 10)) == 30)
assert(#R.CalendarBuckets('month', stamp(2026, 10, 10)) == 31)
assert(#R.CalendarBuckets('week', now) == 7 and #R.CalendarBuckets('year', now) == 12)
for _, mode in ipairs({ 'week', 'month', 'year' }) do
    local buckets = R.CalendarBuckets(mode, now)
    for i = 2, #buckets do assert(buckets[i].from == buckets[i - 1].to + 1) end
    assert(select(2, R.Range(mode)) == now and R.Range(mode) == R.CalendarRange(mode, now))
end
assert(not R.ParseDate('31.02.2026') and not R.ParseDate('29.02.2025'))
assert(R.ParseDate('29.02.2024', true) == stamp(2024, 3, 1) - 1)

local events = {
    { k = 'd', st = 'f', o = 1, c = 'A', p = 197, f = 'H', t = stamp(2026, 9, 7, 9) },
    { k = 'd', st = 'f', o = 2, c = 'B', p = 197, f = 'H', t = stamp(2026, 9, 14, 11) },
    { k = 'd', st = 'f', o = 3, c = 'C', p = 164, f = 'A', t = stamp(2026, 9, 14, 15) },
    { k = 'd', st = 'f', o = 4, c = 'D', p = 197, f = 'H', t = stamp(2026, 8, 14, 11) },
    { k = 'r', id = 'late', c = 'Late', p = 197, f = 'H', t = stamp(2026, 9, 13, 23, 59) },
    { k = 'g', id = 'late', c = 'Late', p = 197, f = 'H', t = stamp(2026, 9, 14, 0, 1) },
    { k = 'l', id = 'late', o = 2, st = 'f', t = stamp(2026, 9, 14, 11) },
    { k = 'p', f = 'H', t = stamp(2026, 9, 14, 10) },
    { k = 'p', f = 'H', t = stamp(2026, 9, 14, 10), m = 'peer' },
}
first, last = R.CalendarRange('month', now)
local report = R.Build({ events }, { from = first, to = last })
assert(report.calendar.days['2026-09-07'].orders == 1)
assert(report.calendar.days['2026-09-14'].orders == 2, 'Mondays from different dates were merged')
assert(report.calendar.months['2026-09'].orders == 3 and not report.calendar.months['2026-08'])
assert(report.calendar.days['2026-09-14'].online == 5, 'linked online marks doubled the day')
first, last = R.CalendarRange('day', stamp(2026, 9, 14))
report = R.Build({ events }, { from = first, to = last, ppID = 197, side = 'H' })
assert(report.hours.orders[11] == 1 and report.hours.orders[9] == 0 and report.hours.orders[15] == 0)
assert(report.calendar.days['2026-09-14'].orders == 1 and report.hours.greetings[0] == 1,
    'filters or greeting after midnight were lost')
report = R.Build({ events }, { from = R.CalendarRange('year', now), to = now })
assert(report.calendar.months['2026-08'].orders == 1 and report.calendar.months['2026-09'].orders == 3)
local ten = stamp(2026, 9, 28, 10)
report = R.Build({ {
    { k = 'r', id = 'one', c = 'Buyer', t = ten },
    { k = 'g', id = 'one', c = 'Buyer', t = ten + 1 },
    { k = 'l', id = 'one', o = 11, st = 'f', t = ten + 60 },
    { k = 'd', o = 11, c = 'Buyer', st = 'f', t = ten + 60 },
    { k = 'd', o = 12, c = 'Buyer', st = 'f', t = ten + 120 },
    { k = 'd', o = 13, c = 'Buyer', st = 'f', t = ten + 180 },
    { k = 'd', o = 14, c = 'Unprompted', st = 'f', t = ten + 200 },
} }, { from = ten, to = ten + 3600 })
assert(report.hours.greetings[10] == 1 and report.hours.crafted[10] == 1 and report.hours.orders[10] == 4,
    'extra items or orders without a greeting inflated Ordered / Greeted')
assert(report.totals.conversion == 1 and report.calendar.days['2026-09-28'].crafted == 1)
print('Analytics calendar passed (dates, leap years, period boundaries, dated counts, filters, midnight, online).')

-- Money follows delivery time, not greeting time. It is net of the cut,
-- partitioned by hour/day/month, deduplicated and filtered like order counts.
local moneyEvents = {
    {k='d',st='f',o=101,c='Paid',p=197,f='H',t=stamp(2026,9,14,9,5),tip=1000*10000,cut=100*10000},
    {k='d',st='f',o=102,c='Paid',p=197,f='H',t=stamp(2026,9,14,9,10),tip=2000*10000,cut=200*10000},
    {k='d',st='f',o=103,c='Legacy',p=197,f='H',t=stamp(2026,9,14,10),tip=1000*10000},
    {k='d',st='f',o=104,c='Free',p=197,f='H',t=stamp(2026,9,14,10,10),tip=0},
    {k='d',st='f',o=105,c='Unknown',p=197,f='H',t=stamp(2026,9,14,10,30)},
    {k='d',st='r',o=106,c='Rejected',p=197,f='H',t=stamp(2026,9,14,10,35),tip=1000000*10000},
    {k='d',st='f',o=107,c='NextDay',p=197,f='H',t=stamp(2026,9,15),tip=500*10000,cut=50*10000},
    {k='d',st='f',o=108,c='Other',p=164,f='A',t=stamp(2026,9,14,9),tip=5000*10000,cut=500*10000},
}
first,last=R.CalendarRange('day',stamp(2026,9,14))
report=R.Build({moneyEvents,{moneyEvents[1]}},{from=first,to=last,ppID=197,side='H'})
assert(report.totals.tips==3600*10000 and report.hours.tips[9]==2700*10000 and report.hours.tips[10]==900*10000,
    'hourly income includes cuts, duplicates, declined orders, another date or profession')
assert(report.calendar.days['2026-09-14'].tips==report.totals.tips
    and report.calendar.months['2026-09'].tips==report.totals.tips,'day/month income differs from the summary')
assert(report.hours.tipsEstimated[9]==0 and report.hours.tipsEstimated[10]==1
    and report.hours.tipsMissing[10]==1,'estimates/missing data were not isolated to their own hour')
local incomeSum=0
for hour=0,23 do incomeSum=incomeSum+report.hours.tips[hour] end
assert(incomeSum==report.totals.tips,'hourly income does not add up to period income')
report=R.Build({moneyEvents},{from=first,to=stamp(2026,9,16)-1,ppID=197,side='H'})
assert(report.calendar.days['2026-09-15'].tips==450*10000 and report.calendar.months['2026-09'].tips==4050*10000,
    'delivery at midnight went to the wrong date')
report=R.Build({{moneyEvents[4]}},{})
assert(report.hours.tips[10]==0 and report.hours.tipsEstimated[10]==0 and report.hours.tipsMissing[10]==0,
    'a known zero tip was treated as unknown or estimated')
print('Analytics income buckets passed (net gold, delivery dates, zero/missing/estimated tips, filters, deduplication).')
