-- A price stored one at a time (the shopping list does that while it searches)
-- is told to the listeners once, after the burst is over.
local clock, timers = 1000, {}
HironCraftProfit = {}
HironCraftProfit_PriceDB = nil
GetRealmName = function() return 'Test Realm' end
time = function() return clock end
CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end
SlashCmdList = {}
C_Timer = { After = function(delay, callback) timers[#timers + 1] = { at = clock + delay, callback = callback } end }
local function advance(seconds)
    local untilTime = clock + seconds
    for _ = 1, 1000 do
        table.sort(timers, function(a, b) return a.at < b.at end)
        if not timers[1] or timers[1].at > untilTime then clock = untilTime return end
        local timer = table.remove(timers, 1)
        clock = timer.at
        timer.callback()
    end
    error('unbounded timer loop')
end

assert(loadfile('ProfitHub/Core/Core/Prices.lua'))()
local P = HironCraftProfit.Prices

-- Nobody listens: storing a price schedules nothing.
assert(P:UpdateItem(100, 5000, 5000, 3) and #timers == 0, 'a price change was scheduled for nobody')

local heard = 0
P:OnPricesChanged(function() heard = heard + 1 end)
P:OnPricesChanged('not a function')

-- Seven reagents found one after another, as a shopping scan does.
for index = 1, 7 do
    assert(P:UpdateItem(200 + index, 1000 * index, 1000 * index, 10))
    advance(0.45)
    assert(heard == 0, 'the listeners were told in the middle of a burst')
end
advance(0.2)
assert(heard == 1, 'the listeners were not told after the burst: ' .. heard)
advance(5)
assert(heard == 1, 'one burst was told more than once')
assert(P:GetItemPrice(207) == 7000)

-- A later change is a new notice; a refused price is none.
assert(not P:UpdateItem(300, 0) and not P:UpdateItem(nil, 100))
advance(1)
assert(heard == 1, 'a refused price was announced')
P:UpdateItem(300, 100)
advance(1)
assert(heard == 2)

-- A listener that fails does not silence the others.
local second = 0
P._changeListeners[1] = function() error('broken listener') end
P:OnPricesChanged(function() second = second + 1 end)
P:UpdateItem(301, 100)
advance(1)
assert(second == 1, 'a failing listener stopped the notice')

print('Price change notice passed (nobody listening, one notice per burst, refused prices, failing listener).')
