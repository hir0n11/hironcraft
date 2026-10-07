local Scan = select(2, ...)

-- How customers tip, by the average tip over their delivered crafting
-- orders: 10,000 gold or more earns a diamond, 3,000 to 9,999 gold a gold
-- coin, 1,000 to 2,999 a silver coin, under 1,000 a copper coin.
-- Every order counts, one without a tip too, so the mark follows the
-- customer's habit rather than one order. The tip is the one the customer
-- set; the cut taken on delivery does not matter. The crafter can set or
-- clear the mark by hand, and that decision sticks.
-- Marks are kept by character name without realm, the way order rows and
-- crafting orders name the same player differently.
local M = {}
Scan.Generous = M

-- Average tips from DefaultThresholdGold are generous, under DefaultStingyGold
-- stingy.
M.DefaultThresholdGold = 3000
M.DefaultStingyGold = 1000
M.DiamondThresholdGold = 10000
local COPPER_PER_GOLD = 10000
local ICONS = {
    diamond = '|TInterface\\Icons\\INV_Misc_Gem_Diamond_01:12:12:0:0|t',
    generous = '|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t',
    regular = '|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t',
    stingy = '|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t',
}

-- A problem customer: a mark the crafter sets by hand, apart from the coin
-- (someone can tip well and still be hard work). A toy monkey that claps its
-- cymbals, for nobody being home. It says nothing about tips and changes
-- nothing but what is shown. The picture is drawn by
-- scripts/MakeProblemCustomerIcon.py.
local PROBLEM_ICON = '|TInterface\\AddOns\\HironCraft\\Media\\ProblemCustomer:16:16:0:0|t'

local function Key(name)
    if type(name) ~= 'string' or name == '' or (issecretvalue and issecretvalue(name)) then return nil end
    return (name:match('^([^-]+)') or name):lower()
end

local function Store()
    return Scan.Utils.saved(Scan.DB.settings, 'generous_customers', {})
end

function M.ThresholdCopper()
    local gold = tonumber(Scan.DB.settings.generous_tip_gold) or M.DefaultThresholdGold
    return math.max(1, gold) * COPPER_PER_GOLD
end

function M.StingyCopper()
    local gold = tonumber(Scan.DB.settings.stingy_tip_gold) or M.DefaultStingyGold
    return math.max(0, gold) * COPPER_PER_GOLD
end

local function CoinTier(averageCopper)
    if averageCopper >= M.ThresholdCopper() then return 'generous' end
    if averageCopper >= M.StingyCopper() then return 'regular' end
    return 'stingy'
end

local function Entry(name)
    local key = Key(name)
    local settings = Scan.DB and Scan.DB.settings
    local store = key and settings and settings.generous_customers
    local entry = store and store[key]
    return type(entry) == 'table' and entry or nil
end

-- The mark that shows: a decision by hand first, then what the tips say.
-- 0.4.32 stored manual = true / removed = true for the generous mark only.
local function Mark(entry)
    if not entry then return nil end
    local manual = entry.manual
    if manual == true then manual = 'generous' end
    if entry.removed and manual == nil then manual = 'none' end
    if manual == 'generous' or manual == 'stingy' or manual == 'regular' then return manual end
    if manual == 'none' then return nil end
    local count = tonumber(entry.count) or 0
    if count > 0 then
        -- The first records (0.4.32) may lack the total: the largest tip then.
        local total = tonumber(entry.total)
        -- A maximum alone cannot establish a 10k average across several
        -- legacy orders. Preserve their previous coin classification.
        if not total and count > 1 then return CoinTier(tonumber(entry.max) or 0) end
        return M.TierOf(total and total / count or tonumber(entry.max) or 0)
    end
    -- No tip on record: the silver MarkUntipped gave orders from before tips
    -- were kept.
    return entry.mark
end

-- The coin an average tip (copper) earns.
function M.TierOf(averageCopper)
    if averageCopper >= M.DiamondThresholdGold * COPPER_PER_GOLD then return 'diamond' end
    return CoinTier(averageCopper)
end

function M.AverageTip(entry)
    local count = entry and tonumber(entry.count) or 0
    if count <= 0 then return nil end
    return tonumber(entry.total) and entry.total / count or tonumber(entry.max)
end

function M.Get(name)
    local entry = Entry(name)
    return Mark(entry) and entry or nil
end

function M.MarkOf(name)
    return Mark(Entry(name))
end

function M.IsGenerous(name)
    local mark = M.MarkOf(name)
    return mark == 'generous' or mark == 'diamond'
end
function M.IsStingy(name) return M.MarkOf(name) == 'stingy' end

-- A pause for stingy customers, switched from the orders window. While it is
-- on, their requests still get a row, but nothing offers the greeting: no
-- banner, no card, no sound. A click on the row greets them as usual. It
-- lasts until switched off, over /reload and relogs.
function M.IsHoldingStingy()
    return Scan.DB.settings.hold_stingy_greetings == true
end

function M.SetHoldingStingy(on)
    Scan.DB.settings.hold_stingy_greetings = on and true or nil
end

function M.IsGreetingHeld(name)
    return M.IsHoldingStingy() and M.IsStingy(name)
end

-- A delivered order. Every tip counts toward the average that decides the
-- automatic mark. The same order is counted once, however often its result
-- is seen again (a linked account, a replay).
function M.RecordTip(name, tipCopper, orderID)
    local key = Key(name)
    tipCopper = tonumber(tipCopper)
    if not key or not tipCopper or tipCopper < 0 then return false end
    local store = Store()
    local entry = type(store[key]) == 'table' and store[key] or { orders = {} }
    store[key] = entry
    entry.orders = type(entry.orders) == 'table' and entry.orders or {}
    if orderID ~= nil then
        local id = tostring(orderID)
        if entry.orders[id] then return false end
        entry.orders[id] = true
    end
    local before = Mark(entry)
    entry.count = (tonumber(entry.count) or 0) + 1
    entry.total = (tonumber(entry.total) or 0) + tipCopper
    entry.max = math.max(tonumber(entry.max) or 0, tipCopper)
    entry.at = time()
    entry.name = entry.name or name
    -- The average decides from now on; the mark kept by earlier versions
    -- (or the silver of an untipped customer) is not needed.
    entry.mark = nil
    -- Second result: whether the coin in front of the name changed.
    return true, Mark(entry) ~= before
end

-- Customers with delivered orders from before tips were kept (0.4.32) have
-- no entry and no coin. They paid something, just not on record: silver. An
-- automatic mark, so the next tip moves it as usual.
function M.MarkUntipped(names)
    local store = Store()
    local marked = 0
    for _, name in ipairs(names or {}) do
        local key = Key(name)
        if key and store[key] == nil then
            store[key] = { orders = {}, count = 0, mark = 'regular', name = name, at = time() }
            marked = marked + 1
        end
    end
    return marked
end

-- By hand: 'generous', 'stingy' or 'none'. true/false mean generous / none.
function M.SetManual(name, mark)
    local key = Key(name)
    if not key then return end
    if mark == true then mark = 'generous' elseif mark == false or mark == nil then mark = 'none' end
    local store = Store()
    local entry = type(store[key]) == 'table' and store[key] or { orders = {} }
    store[key] = entry
    entry.name = entry.name or name
    entry.removed = nil
    entry.manual = mark
end

function M.Icon(mark)
    return ICONS[mark or 'generous']
end

function M.IsProblem(name)
    local entry = Entry(name)
    return entry ~= nil and entry.problem == true
end

-- By hand, and only by hand: nothing sets or clears it on its own.
function M.SetProblem(name, on)
    local key = Key(name)
    if not key then return end
    local store = Store()
    local entry = type(store[key]) == 'table' and store[key] or { orders = {} }
    store[key] = entry
    entry.name = entry.name or name
    entry.problem = on and true or nil
end

function M.ProblemIcon()
    return PROBLEM_ICON
end

-- What stands in front of a name: the coin, then the problem mark. nil when
-- there is neither.
function M.Marks(name)
    local coin = ICONS[M.MarkOf(name) or '']
    local problem = M.IsProblem(name) and PROBLEM_ICON or nil
    if coin and problem then return coin .. problem end
    return coin or problem
end

-- The name as shown in a list, with its marks in front when there are any.
function M.Decorate(name, text)
    local marks = M.Marks(name)
    if marks then return marks .. ' ' .. (text or name) end
    return text or name
end

local function Gold(copper)
    local gold = math.floor((tonumber(copper) or 0) / COPPER_PER_GOLD)
    local text = tostring(gold):reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^ ', '')
    return text .. 'g'
end

-- One line for a tooltip, or nil.
function M.Describe(name)
    local entry = Entry(name)
    local mark = Mark(entry)
    local problem = entry ~= nil and entry.problem == true
    if not entry or (not mark and (tonumber(entry.count) or 0) == 0 and not problem) then return nil end
    local L = Scan.LOCAL and function(key) return Scan.LOCAL:GetText(key) end or function(key) return key end
    local title = mark == 'diamond' and L('Diamond customer')
        or mark == 'generous' and L('Generous customer')
        or mark == 'stingy' and L('Stingy customer')
        or mark == 'regular' and L('Regular customer') or L('Customer tips')
    local manual = entry.manual == 'generous' or entry.manual == 'stingy' or entry.manual == true
    local text
    if (tonumber(entry.count) or 0) > 0 then
        text = string.format(L('%s: average tip %s, largest %s, total %s over %d orders'), title,
            Gold(M.AverageTip(entry)), Gold(entry.max), Gold(entry.total), tonumber(entry.count) or 0)
            .. (manual and (' ' .. L('(marked by hand)')) or '')
    elseif mark then
        text = manual and (title .. ' ' .. L('(marked by hand)')) or title
    end
    if problem then
        local line = PROBLEM_ICON .. ' ' .. L('Problem customer') .. ' ' .. L('(marked by hand)')
        text = text and (text .. '\n' .. line) or line
    end
    return text
end
