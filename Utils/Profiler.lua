-- On-demand hitch profiler. `/hcprof` wraps the functions exposed by the
-- ProfitHub order modules and the HironCraft modules, then reports which of
-- them consumed the time of any frame that took longer than the threshold.
-- Nothing is wrapped until it is enabled, and disabled wrappers only forward.
-- Times are inclusive (a caller includes its callees), so the deepest entry
-- with a large time is usually the culprit.
local Scan = select(2, ...)

local Profiler = { enabled = false, wrapped = false, threshold = 150 }
Scan.Profiler = Profiler

local clock = debugprofilestop
local frameID = 0
local touched = {}
local wrappedCount = 0
local seenFunctions = {}

local function Finish(stat, start, ...)
    if stat.frame ~= frameID then
        stat.frame, stat.time, stat.calls = frameID, 0, 0
        touched[#touched + 1] = stat
    end
    stat.time = stat.time + (clock() - start)
    stat.calls = stat.calls + 1
    return ...
end

local function WrapTable(owner, label, depth, visited)
    if type(owner) ~= 'table' or visited[owner] or owner == Profiler then
        return
    end
    visited[owner] = true
    local keys = {}
    for key, value in pairs(owner) do
        if type(key) == 'string' then
            keys[#keys + 1] = key
        end
    end
    for _, key in ipairs(keys) do
        local fn = rawget(owner, key)
        if type(fn) == 'function' and not seenFunctions[fn] and not key:find('^Debug') then
            local stat = { name = label .. key, frame = -1, time = 0, calls = 0 }
            local wrapper = function(...)
                if not Profiler.enabled then
                    return fn(...)
                end
                return Finish(stat, clock(), fn(...))
            end
            seenFunctions[fn], seenFunctions[wrapper] = true, true
            rawset(owner, key, wrapper)
            wrappedCount = wrappedCount + 1
        elseif type(fn) == 'table' and depth > 0 and not key:find('DB$') and not key:find('^L_') then
            WrapTable(fn, label .. key .. '.', depth - 1, visited)
        end
    end
end

local function WrapAll()
    if Profiler.wrapped then
        return
    end
    Profiler.wrapped = true
    local visited = {}
    WrapTable(_G.HironCraftProfitCraftingOrders, 'CO:', 1, visited)
    WrapTable(_G.HironCraftProfitCraftingOrdersEnv, 'Orders.', 0, visited)
    WrapTable(_G.HironCraftProfitShoppingListEnv, 'Shop.', 0, visited)
    WrapTable(_G.HironCraftProfit, 'PT.', 1, visited)
    WrapTable(_G.HironCraftScanComm, 'Comm:', 0, visited)
    for _, name in ipairs({ 'OrderFulfillment', 'ReagentAudit', 'QuickReplies', 'CustomExplanations',
        'BattleNet', 'Utils', 'ClassMatching', 'RequestTracking' }) do
        WrapTable(Scan[name], name .. '.', 0, visited)
    end
    WrapTable(Scan, 'Scan.', 0, visited)
end

local function Report(elapsed)
    table.sort(touched, function(lhs, rhs) return lhs.time > rhs.time end)
    if not touched[1] or touched[1].time < Profiler.threshold / 2 then
        print(string.format('|cffffd200HironCraft prof|r: frame %.0f ms, addon functions %.0f ms (time spent elsewhere).',
            elapsed, touched[1] and touched[1].time or 0))
        return
    end
    print(string.format('|cffffd200HironCraft prof|r: frame %.0f ms. Top functions (inclusive):', elapsed))
    for index = 1, math.min(12, #touched) do
        local stat = touched[index]
        if stat.time < 5 then break end
        print(string.format('  %6.0f ms  x%-5d %s', stat.time, stat.calls, stat.name))
    end
end

local monitor = CreateFrame('Frame')
local lastFrame = nil
monitor:SetScript('OnUpdate', function()
    local now = clock()
    if lastFrame and now - lastFrame > Profiler.threshold then
        Report(now - lastFrame)
    end
    lastFrame = now
    frameID = frameID + 1
    touched = {}
end)
monitor:Hide()

function Profiler:SetEnabled(enabled, threshold)
    if enabled then
        WrapAll()
        self.threshold = tonumber(threshold) or self.threshold
        lastFrame = nil
        monitor:Show()
    else
        monitor:Hide()
    end
    self.enabled = enabled
end

SLASH_HIRONCRAFTPROF1 = '/hcprof'
SlashCmdList.HIRONCRAFTPROF = function(message)
    local argument = (message or ''):match('^%s*(%S*)')
    if argument == 'off' or (argument == '' and Profiler.enabled) then
        Profiler:SetEnabled(false)
        print('|cffffd200HironCraft prof|r: off.')
        return
    end
    Profiler:SetEnabled(true, tonumber(argument))
    print(string.format('|cffffd200HironCraft prof|r: on, reporting frames over %d ms (%d functions). /hcprof off to stop.',
        Profiler.threshold, wrappedCount))
end
