local Scan = select(2, ...)

-- How customers tip. A delivered crafting order with a tip of 5,000 gold or
-- more marks its customer generous (a gold coin); one under 999 gold marks
-- them stingy (a copper coin). The tip is the one the customer set; the cut
-- taken on delivery does not matter. Generosity wins: one small tip does not
-- make a generous customer stingy, one big tip lifts a stingy one. The
-- crafter can set or clear either mark by hand, and that decision sticks.
-- Marks are kept by character name without realm, the way order rows and
-- crafting orders name the same player differently.
local M = {}
Scan.Generous = M

M.DefaultThresholdGold = 5000
M.DefaultStingyGold = 999
local COPPER_PER_GOLD = 10000
local ICONS = {
    generous = '|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t',
    stingy = '|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t',
}

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

local function Entry(name)
    local key = Key(name)
    local store = key and Scan.DB.settings.generous_customers
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
    if manual == 'generous' or manual == 'stingy' then return manual end
    if manual == 'none' then return nil end
    if entry.mark then return entry.mark end
    if (tonumber(entry.max) or 0) >= M.ThresholdCopper() then return 'generous' end
    return nil
end

function M.Get(name)
    local entry = Entry(name)
    return Mark(entry) and entry or nil
end

function M.MarkOf(name)
    return Mark(Entry(name))
end

function M.IsGenerous(name) return M.MarkOf(name) == 'generous' end
function M.IsStingy(name) return M.MarkOf(name) == 'stingy' end

-- A delivered order. Every tip counts toward the numbers; the tip decides
-- the automatic mark. The same order is counted once, however often its
-- result is seen again (a linked account, a replay).
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
    if tipCopper >= M.ThresholdCopper() then
        entry.mark = 'generous'
    elseif tipCopper < M.StingyCopper() and entry.mark ~= 'generous'
        and (tonumber(entry.max) or 0) < M.ThresholdCopper() then
        entry.mark = 'stingy'
    end
    -- Second result: whether the coin in front of the name changed.
    return true, Mark(entry) ~= before
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

-- The name as shown in a list, with the mark in front when there is one.
function M.Decorate(name, text)
    local icon = ICONS[M.MarkOf(name) or '']
    if icon then return icon .. ' ' .. (text or name) end
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
    if not entry or (not mark and (tonumber(entry.count) or 0) == 0) then return nil end
    local L = Scan.LOCAL and function(key) return Scan.LOCAL:GetText(key) end or function(key) return key end
    local title = mark == 'generous' and L('Generous customer')
        or mark == 'stingy' and L('Stingy customer') or L('Customer tips')
    local manual = entry.manual == 'generous' or entry.manual == 'stingy' or entry.manual == true
    if (tonumber(entry.count) or 0) > 0 then
        return string.format(L('%s: max tip %s, total %s, orders %d'), title,
            Gold(entry.max), Gold(entry.total), tonumber(entry.count) or 0)
            .. (manual and (' ' .. L('(marked by hand)')) or '')
    end
    return title .. ' ' .. L('(marked by hand)')
end
