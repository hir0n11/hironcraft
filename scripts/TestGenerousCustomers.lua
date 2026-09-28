-- Customer tip tiers: diamond at 10,000+, gold at 3,000+, silver at 1,000+,
-- copper below 1,000; the crafter
-- can set or clear the mark by hand.
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

-- An average in between: a silver coin.
local counted, changed = G.RecordTip('Middle-Realm', 2000 * GOLD, 1)
assert(counted and changed and G.MarkOf('Middle') == 'regular', 'a 2,000 gold average did not make a regular')
assert(G.Decorate('Middle', 'Middle'):find('UI-SilverIcon', 1, true), 'no silver coin')
assert(G.Describe('Middle'):find('Regular customer', 1, true), 'the tooltip does not name a regular')
-- The edges: 1,000 is silver, 999 copper, 3,000 gold; no tip at all is copper.
G.RecordTip('Edge', 1000 * GOLD, 2)
G.RecordTip('Below', 999 * GOLD, 3)
G.RecordTip('Top', 3000 * GOLD, 4)
G.RecordTip('Nothing', 0, 5)
assert(G.MarkOf('Edge') == 'regular' and G.IsStingy('Below') and G.IsGenerous('Top') and G.IsStingy('Nothing'),
    'the coin edges are off')
assert(G.Decorate('Top', 'Top'):find('UI-GoldIcon', 1, true), 'no gold coin')
assert(G.Decorate('Nothing', 'Nothing'):find('UI-CopperIcon', 1, true), 'no copper coin')
assert(G.Decorate('Stranger', 'Stranger') == 'Stranger')

-- The average decides, not the largest tip: orders without a tip bring a
-- generous customer down step by step, a big tip lifts them again.
G.RecordTip('Mixed', 6000 * GOLD, 6)
counted, changed = G.RecordTip('Mixed', 0, 7)          -- 3,000 on average
assert(G.IsGenerous('Mixed') and not changed, 'a 3,000 gold average is not gold')
counted, changed = G.RecordTip('Mixed', 0, 8)          -- 2,000
assert(G.MarkOf('Mixed') == 'regular' and changed, 'the average did not bring the coin down to silver')
for order = 9, 11 do G.RecordTip('Mixed', 0, order) end -- 1,000
assert(G.MarkOf('Mixed') == 'regular', 'a 1,000 gold average is not silver')
G.RecordTip('Mixed', 0, 12)                             -- 857
assert(G.IsStingy('Mixed'), 'the average did not bring the coin down to copper')
G.RecordTip('Mixed', 20000 * GOLD, 13)                  -- 3,250
assert(G.IsGenerous('Mixed'), 'a big tip did not lift the average to gold')

-- Whatever the realm or the case of the name; the same order counts once.
counted, changed = G.RecordTip('Big-Realm', 5000 * GOLD, 20)
assert(changed, 'a new mark was not reported, so the list would not redraw')
assert(G.IsGenerous('Big') and G.IsGenerous('big-otherrealm') and G.IsGenerous('BIG'), 'the name did not match')
G.RecordTip('Big', 100 * GOLD, 21)
assert(not G.RecordTip('Big', 5000 * GOLD, 20), 'a repeated order counted again')
local entry = G.Get('Big')
assert(entry.count == 2 and entry.total == 5100 * GOLD and entry.max == 5000 * GOLD and G.MarkOf('Big') == 'regular')
local describe = G.Describe('Big')
assert(describe:find('2 550g', 1, true) and describe:find('5 000g', 1, true) and describe:find('5 100g', 1, true),
    'the tooltip does not show the average, the largest and the total tip: ' .. describe)

-- Records of earlier versions: the average of what they kept decides, over
-- the mark they stored.
Scan.DB.settings.generous_customers.older = { max = 3000 * GOLD, count = 2, total = 5000 * GOLD, orders = {} }
Scan.DB.settings.generous_customers.never = { manual = 'none', max = 3000 * GOLD, count = 1, orders = {} }
Scan.DB.settings.generous_customers.kept = { mark = 'generous', max = 6000 * GOLD, count = 3, total = 6300 * GOLD, orders = {} }
assert(G.MarkOf('Older') == 'regular' and G.MarkOf('Never') == nil and G.MarkOf('Kept') == 'regular',
    'earlier records are not judged by their average')

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
    and not G.IsGreetingHeld('Older'), 'the pause held the wrong customers')
G.SetHoldingStingy(false)
assert(not G.IsGreetingHeld('Cheap') and Scan.DB.settings.hold_stingy_greetings == nil,
    'the pause did not switch off')

-- Orders from before tips were kept: silver, automatic, moved by the next tip.
assert(G.MarkUntipped({ 'Early-Realm', 'Early-Other', 'Big' }) == 1, 'untipped customers were not marked once')
assert(G.MarkOf('Early') == 'regular' and not G.Describe('Early'):find('by hand', 1, true),
    'an untipped customer is not silver, or looks marked by hand')
assert(G.MarkOf('Big') == nil, 'a customer with a record (unmarked by hand) was overwritten')
G.RecordTip('Early', 6000 * GOLD, 20)
assert(G.IsGenerous('Early'), 'a big tip did not move an untipped customer to gold')
G.MarkUntipped({ 'Later' })
G.RecordTip('Later', 100 * GOLD, 21)
assert(G.IsStingy('Later'), 'a small tip did not move an untipped customer to copper')

-- The diamond threshold is inclusive and uses the unrounded average, not
-- the maximum or last tip. Duplicate linked notices never change it.
assert(G.TierOf(10000*GOLD-1)=='generous' and G.TierOf(10000*GOLD)=='diamond',
    'diamond threshold rounded up or excluded exactly 10,000 gold')
G.RecordTip('DiamondEdge-Realm',10000*GOLD,101)
assert(G.MarkOf('DIAMONDEDGE-Other')=='diamond' and G.IsGenerous('DiamondEdge'))
assert(G.Decorate('DiamondEdge','Name'):find('INV_Misc_Gem_Diamond_01',1,true)
    and G.Describe('DiamondEdge'):find('Diamond customer: average tip 10 000g',1,true),
    'diamond icon or average-tip tooltip is missing')
G.RecordTip('DiamondMix',9000*GOLD,102)
counted,changed=G.RecordTip('DiamondMix',11000*GOLD,103)
assert(counted and changed and G.MarkOf('DiamondMix')=='diamond','crossing 10k did not update the mark')
assert(not G.RecordTip('DiamondMix-Other',11000*GOLD,103) and G.Get('DiamondMix').count==2,
    'a replay raised the diamond average')
counted,changed=G.RecordTip('DiamondMix',0,104)
assert(counted and changed and G.MarkOf('DiamondMix')=='generous',
    'a zero-tip order did not lower the average below diamond')

-- Existing complete histories upgrade without mutation or another order.
local savedDiamond={mark='generous',count=2,total=24000*GOLD,max=20000*GOLD,orders={}}
Scan.DB.settings.generous_customers.saveddiamond=savedDiamond
assert(G.MarkOf('SavedDiamond')=='diamond' and savedDiamond.mark=='generous' and savedDiamond.count==2,
    'old history needed migration or a new order to earn diamond')
Scan.DB.settings.generous_customers.unknownaverage={count=2,max=20000*GOLD,orders={}}
assert(G.MarkOf('UnknownAverage')=='generous','a legacy maximum was mistaken for a known 10k average')
Scan.DB.settings.generous_tip_gold=25000
assert(G.MarkOf('UnknownAverage')=='regular','legacy fallback ignored an existing custom coin threshold')
Scan.DB.settings.generous_tip_gold=nil
Scan.DB.settings.generous_customers.singleold={count=1,max=10000*GOLD,orders={}}
assert(G.MarkOf('SingleOld')=='diamond','a known single-order legacy average was ignored')
G.SetManual('DiamondEdge','none')
G.RecordTip('DiamondEdge',30000*GOLD,105)
assert(G.MarkOf('DiamondEdge')==nil,'diamond overrode a manually removed mark')
G.SetManual('SavedDiamond','stingy')
assert(G.IsStingy('SavedDiamond'),'diamond overrode a manual copper mark')
G.RecordTip('Friendly',20000*GOLD,106)
assert(G.MarkOf('Friendly')=='generous','diamond changed an explicit manual gold mark')
G.SetHoldingStingy(true)
assert(not G.IsGreetingHeld('SingleOld'),'a diamond customer was held by the copper pause')

print('Customer tip tests passed (diamond 10,000+, gold/silver/copper; exact averages, repeats, manual priority, saved data, pause).')
