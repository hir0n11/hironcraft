-- How customers tip: 5,000 gold or more on one order marks them generous,
-- under 999 gold stingy; the crafter can set or clear either by hand.
local now = 1000
function time() return now end
local Scan = { DB = { settings = {} }, Utils = {} }
function Scan.Utils.saved(parent, key, default)
    if parent[key] == nil then parent[key] = default end
    return parent[key]
end
assert(loadfile('Customer/GenerousCustomers.lua'))('HironCraft', Scan)
local G = Scan.Generous
local GOLD = 10000

-- In between: counted, not marked.
local counted, changed = G.RecordTip('Middle-Realm', 4999 * GOLD, 1)
assert(counted and not changed and G.MarkOf('Middle') == nil, 'a 4,999 gold tip got a mark')
-- 5,000 and more: generous, whatever the realm or the case of the name.
counted, changed = G.RecordTip('Big-Realm', 5000 * GOLD, 2)
assert(changed, 'a new mark was not reported, so the list would not redraw')
assert(G.IsGenerous('Big') and G.IsGenerous('big-otherrealm') and G.IsGenerous('BIG'),
    'a 5,000 gold tip did not mark')
-- Under 999: stingy; no tip at all is stingy too.
G.RecordTip('Small-Realm', 998 * GOLD, 3)
G.RecordTip('Nothing', 0, 4)
assert(G.IsStingy('Small') and G.IsStingy('Nothing'), 'a small tip did not mark the customer stingy')
G.RecordTip('Edge', 999 * GOLD, 5)
assert(G.MarkOf('Edge') == nil, '999 gold is already stingy')
-- Generosity wins: one small tip does not undo it, one big tip lifts a stingy customer.
G.RecordTip('Big', 100 * GOLD, 6)
assert(G.IsGenerous('Big'), 'a small tip made a generous customer stingy')
G.RecordTip('Small', 7000 * GOLD, 7)
assert(G.IsGenerous('Small'), 'a big tip did not lift a stingy customer')
-- The same order seen again counts once.
assert(not G.RecordTip('Big', 5000 * GOLD, 2))
local entry = G.Get('Big')
assert(entry.count == 2 and entry.total == 5100 * GOLD and entry.max == 5000 * GOLD)
assert(G.Describe('Big'):find('5 000g', 1, true) and G.Describe('Big'):find('5 100g', 1, true),
    'the tooltip does not show the tips')
assert(G.Decorate('Big', 'Big'):find('UI-GoldIcon', 1, true), 'no gold coin')
assert(G.Decorate('Nothing', 'Nothing'):find('UI-CopperIcon', 1, true), 'no copper coin')
assert(G.Decorate('Middle', 'Middle') == 'Middle')

-- By hand, and it sticks against later tips.
G.SetManual('Friendly', 'generous')
assert(G.IsGenerous('Friendly') and G.Describe('Friendly'))
G.SetManual('Cheap', 'stingy')
assert(G.IsStingy('Cheap'))
G.RecordTip('Cheap', 9000 * GOLD, 8)
assert(G.IsStingy('Cheap'), 'a tip overrode a mark set by hand')
G.SetManual('Big', 'none')
assert(G.MarkOf('Big') == nil)
G.RecordTip('Big', 9000 * GOLD, 9)
assert(G.MarkOf('Big') == nil, 'a tip undid a mark cleared by hand')

-- Marks saved by 0.4.32 keep their meaning.
Scan.DB.settings.generous_customers.legacy = { manual = true, orders = {} }
Scan.DB.settings.generous_customers.gone = { removed = true, max = 9000 * GOLD, orders = {} }
Scan.DB.settings.generous_customers.auto = { max = 6000 * GOLD, count = 1, orders = {} }
assert(G.IsGenerous('Legacy') and G.MarkOf('Gone') == nil and G.IsGenerous('Auto'),
    '0.4.32 marks changed meaning')

-- The pause for stingy customers holds their greetings only, only while on.
assert(not G.IsHoldingStingy() and not G.IsGreetingHeld('Cheap'), 'the pause is on by default')
G.SetHoldingStingy(true)
assert(G.IsHoldingStingy() and Scan.DB.settings.hold_stingy_greetings == true, 'the pause is not kept')
assert(G.IsGreetingHeld('Cheap-Realm') and not G.IsGreetingHeld('Friendly')
    and not G.IsGreetingHeld('Middle'), 'the pause held the wrong customers')
G.SetHoldingStingy(false)
assert(not G.IsGreetingHeld('Cheap') and Scan.DB.settings.hold_stingy_greetings == nil,
    'the pause did not switch off')

print('Customer tip tests passed (generous 5,000+, stingy under 999, generosity wins, repeats, by hand, 0.4.32 data, pause).')
