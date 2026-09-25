-- Customers who tip 5,000 gold or more on one order are marked; the crafter
-- can mark or unmark by hand.
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

assert(not G.RecordTip('Small-Realm', 4999 * GOLD, 1) and not G.IsGenerous('Small'),
    'a tip under 5,000 gold marked the customer')
assert(G.RecordTip('Big-Realm', 5000 * GOLD, 2) and G.IsGenerous('Big'), 'a 5,000 gold tip did not mark')
-- The same player under another spelling of the name.
assert(G.IsGenerous('big-otherrealm') and G.IsGenerous('BIG'), 'the mark depends on how the name is written')
-- The same order seen again (a linked account, a replay) counts once.
assert(not G.RecordTip('Big', 5000 * GOLD, 2))
-- Smaller tips of a marked customer still count toward the numbers.
assert(G.RecordTip('Big', 1000 * GOLD, 3))
local entry = G.Get('Big')
assert(entry.count == 2 and entry.total == 6000 * GOLD and entry.max == 5000 * GOLD)
assert(G.Describe('Big'):find('5 000g', 1, true) and G.Describe('Big'):find('6 000g', 1, true),
    'the tooltip does not show the tips')
assert(G.Decorate('Big', 'Big'):find('UI-GoldIcon', 1, true) and G.Decorate('Small', 'Small') == 'Small')

-- By hand, both ways; an unmark by hand is not undone by the next tip.
G.SetManual('Friendly', true)
assert(G.IsGenerous('Friendly') and G.Describe('Friendly'))
G.SetManual('Big', false)
assert(not G.IsGenerous('Big'), 'unmarking by hand did not stick')
assert(not G.RecordTip('Big', 9000 * GOLD, 4) and not G.IsGenerous('Big'), 'a tip undid an unmark by hand')
G.SetManual('Big', true)
assert(G.IsGenerous('Big'))

print('Generous customer tests passed (5,000 gold per order, names, repeats, numbers, by hand).')
