local Scan = select(2, ...)

-- Customers who tip well. A crafting order that is delivered with a tip of
-- 5,000 gold or more marks its customer (the tip as the customer set it; the
-- cut taken on delivery does not matter). The crafter can also mark or unmark
-- a customer by hand. Marks are kept by character name without realm, the
-- way order rows and crafting orders name the same player differently.
local M = {}
Scan.Generous = M

M.DefaultThresholdGold = 5000
local COPPER_PER_GOLD = 10000
local ICON = '|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t'

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

function M.Get(name)
    local key = Key(name)
    local entry = key and Scan.DB.settings.generous_customers and Scan.DB.settings.generous_customers[key]
    if type(entry) ~= 'table' or entry.removed then return nil end
    return entry
end

function M.IsGenerous(name)
    return M.Get(name) ~= nil
end

-- A delivered order. Counts toward the tooltip numbers for a marked customer,
-- and marks one whose tip reaches the threshold. The same order is counted
-- once, however often its result is seen again.
function M.RecordTip(name, tipCopper, orderID)
    local key = Key(name)
    tipCopper = tonumber(tipCopper) or 0
    if not key or tipCopper <= 0 then return false end
    local store = Store()
    local entry = store[key]
    local reaches = tipCopper >= M.ThresholdCopper()
    if not entry and not reaches then return false end
    if type(entry) ~= 'table' then
        entry = { orders = {} }
        store[key] = entry
    end
    -- A customer the crafter unmarked by hand stays unmarked.
    if entry.removed then return false end
    entry.orders = type(entry.orders) == 'table' and entry.orders or {}
    if orderID ~= nil then
        local id = tostring(orderID)
        if entry.orders[id] then return false end
        entry.orders[id] = true
    end
    entry.count = (tonumber(entry.count) or 0) + 1
    entry.total = (tonumber(entry.total) or 0) + tipCopper
    entry.max = math.max(tonumber(entry.max) or 0, tipCopper)
    entry.at = time()
    entry.name = entry.name or name
    return true
end

function M.SetManual(name, generous)
    local key = Key(name)
    if not key then return end
    local store = Store()
    local entry = type(store[key]) == 'table' and store[key] or { orders = {} }
    store[key] = entry
    entry.name = entry.name or name
    if generous then
        entry.removed = nil
        entry.manual = true
    else
        entry.removed = true
        entry.manual = nil
    end
end

function M.Icon()
    return ICON
end

-- The name as shown in a list, with the mark in front when it applies.
function M.Decorate(name, text)
    if M.IsGenerous(name) then return ICON .. ' ' .. (text or name) end
    return text or name
end

local function Gold(copper)
    local gold = math.floor((tonumber(copper) or 0) / COPPER_PER_GOLD)
    local text = tostring(gold):reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^ ', '')
    return text .. 'g'
end

-- One line for a tooltip, or nil.
function M.Describe(name)
    local entry = M.Get(name)
    if not entry then return nil end
    local L = Scan.LOCAL and function(key) return Scan.LOCAL:GetText(key) end or function(key) return key end
    if (tonumber(entry.count) or 0) > 0 then
        return string.format(L('Generous customer: max tip %s, total %s, orders %d'),
            Gold(entry.max), Gold(entry.total), tonumber(entry.count) or 0)
    end
    return L('Generous customer (marked by hand)')
end
