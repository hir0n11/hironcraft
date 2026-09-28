-- The analytics window, built on a permissive stand-in for the frame API:
-- creation, loading, the three tabs, filters, sorting and CSV export run
-- without errors and show what the report counted.
local now = os.time({ year = 2026, month = 9, day = 20, hour = 12 })
function time(t) if t then return os.time(t) end return now end
date = os.date
function GetTime() return 1000 end
function InCombatLockdown() return false end
function UnitFactionGroup() return 'Horde' end
strmatch = string.match
assert(loadfile('ProfitHub/Core/Libs/LibStub/LibStub.lua'))()
assert(loadfile('Libs/LibSerialize.lua'))()
assert(loadfile('Libs/LibDeflate.lua'))()

local initializers = {}
charWidth = 5
local texts = {}
local function Mock(kind)
    local object = { kind = kind, scripts = {}, shown = true, text = nil, width = 800, height = 300 }
    local methods = {}
    function methods:SetScript(name, fn) self.scripts[name] = fn end
    function methods:GetScript(name) return self.scripts[name] end
    function methods:HookScript(name, fn) self.scripts[name] = fn end
    function methods:Show() local was = self.shown; self.shown = true; if not was and self.scripts.OnShow then self.scripts.OnShow(self) end end
    function methods:Hide() local was = self.shown; self.shown = false; if was and self.scripts.OnHide then self.scripts.OnHide(self) end end
    function methods:SetShown(on) if on then self:Show() else self:Hide() end end
    function methods:SetEnabled(on) self.enabled = on end
    function methods:IsShown() return self.shown end
    function methods:IsVisible() return self.shown end
    function methods:GetWidth() return self.width end
    function methods:GetHeight() return self.height end
    function methods:SetWidth(w) self.width = w end
    function methods:SetHeight(h) self.height = h end
    function methods:SetSize(w, h) self.width, self.height = w, h end
    function methods:SetText(text) self.text = text; texts[#texts + 1] = text end
    function methods:GetText() return self.text end
    function methods:GetStringWidth() return 50 end
    -- Wide enough for a tile: letters of charWidth, a coin of 18.
    function methods:GetUnboundedStringWidth()
        local text = tostring(self.text or '')
        local _, icons = text:gsub('|T.-|t', '')
        local plain = text:gsub('|T.-|t', ''):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '')
        return #plain * charWidth + icons * 18
    end
    function methods:SetFontObject(font) self.font = font end
    function methods:CreateFontString() return Mock('FontString') end
    function methods:CreateTexture() return Mock('Texture') end
    function methods:GetHighlightTexture() return Mock('Texture') end
    function methods:GetChecked() return self.checked end
    function methods:SetChecked(on) self.checked = on end
    function methods:SetupMenu(fn) self.menu = fn end
    function methods:SetDataProvider(provider)
        self.provider = provider
        self.inited = {}
        local init = initializers[self]
        for _, data in ipairs(provider.list) do
            -- Frames are reused: this one showed another row before.
            local row = Mock('Row')
            row.Stripe = Mock('Texture')
            row.data = { kind = 'item', itemID = 999999 }
            init(row, data)
            self.inited[#self.inited + 1] = { row = row, data = data }
        end
    end
    function methods:SetPoint(_, relative, _, x, y) self.anchor, self.x, self.y = relative, x, y end
    function methods:GetID() return self.id end
    function methods:SetID(id) self.id = id end
    -- WoW methods are capitalised; any other missing key is a plain field.
    return setmetatable(object, { __index = function(_, key)
        if methods[key] then return methods[key] end
        if type(key) == 'string' and key:match('^%u') then return function() end end
        return nil
    end })
end

UIParent = Mock('Frame')
UISpecialFrames = {}
function CreateFrame(kind, name, parent, template)
    local frame = Mock(kind)
    frame.shown = kind ~= 'Frame' or name == nil
    if template == 'ButtonFrameTemplate' then frame.Inset = Mock('Frame'); frame.shown = true end
    if template == 'SearchBoxTemplate' then frame.Instructions = Mock('FontString') end
    if name then _G[name] = frame end
    return frame
end
function ButtonFrameTemplate_HidePortrait() end
function ButtonFrameTemplate_HideButtonBar() end
function PanelTemplates_SetNumTabs() end
function PanelTemplates_SetTab() end
function PanelTemplates_TabResize() end
function PlaySound() end
SOUNDKIT = {}
GameTooltip = Mock('Tooltip')
function GameTooltip_SetTitle() end
function GameTooltip_AddNormalLine() end
function BreakUpLargeNumbers(value) return tostring(value) end
ITEM_QUALITY_COLORS = { [4] = { hex = '|cffa335ee' } }
-- Items whose data has not come from the server yet.
local unloaded = {}
C_Item = {
    GetItemNameByID = function(id) if not unloaded[id] then return 'Item ' .. id end end,
    RequestLoadItemDataByID = function() end,
    GetItemIconByID = function() return 134400 end,
    GetItemQualityByID = function() return 4 end,
}
C_Spell = { GetSpellName = function(id) return 'Recipe ' .. id end }
C_TradeSkillUI = { GetProfessionInfoBySkillLineID = function(id) return { professionName = 'Prof ' .. id } end,
    GetItemReagentQualityByItemInfo = function(id) return id == 7001 and 2 or nil end }
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function RunTimers() local list = timers; timers = {}; for _, fn in ipairs(list) do fn() end end
local function Soon(fn) local saved = C_Timer.After; C_Timer.After = function(_, f) f() end; fn(); C_Timer.After = saved end
ScrollBoxConstants = { RetainScrollPosition = true }
function CreateDataProvider(list) return { list = list } end
function CreateScrollBoxListLinearView()
    local view = {}
    function view:SetElementExtent() end
    function view:SetElementInitializer(template, fn) self.template, self.init = template, fn end
    return view
end
ScrollUtil = { InitScrollBoxListWithScrollBar = function(scrollBox, _, view) initializers[scrollBox] = view.init end }

local dumped
local Scan = {
    DB = { analytics = {}, settings = { my_uuid = 'me' }, realm = { linked_accounts = {} }, characters = { ['Tailor-Realm'] = {} } },
    Utils = {
        Contains = function() return false end,
        -- As in Midnight when a colour is passed wrongly: it raises an error.
        ColorizeProfessionName = function() error('bad argument #2 to WrapTextInColor') end,
        DumpCopyableText = function(text) dumped = text end,
        saved = function(parent, key, default)
            if parent[key] == nil then parent[key] = default end
            return parent[key]
        end,
    },
    CONST = { PROFESSION_COLORS = { [197] = 'ffffff' } },
    LOCAL = { GetText = function(_, key) return key end },
    NameAndRealmToName = function(name) return (name:gsub('%-.*', '')) end,
}
local function load(path) assert(loadfile(path))('HironCraft', Scan) end
load('Customer/GenerousCustomers.lua')
load('Customer/AnalyticsLog.lua')
load('Customer/AnalyticsReport.lua')
load('Customer/AnalyticsSync.lua')
load('Customer/AnalyticsWindow.lua')
local Log = Scan.AnalyticsLog
Log.synchronous = true

Log.Request('Buyer-Realm', { requestToken = 't1', itemID = 1001, parentProfID = 197, crafterFullName = 'Tailor-Realm', time = now - 60 })
Log.Greeting('Buyer-Realm', { requestToken = 't1' })
Log.Outcome({ orderID = 1, status = 'fulfilled', customerName = 'Buyer', itemID = 1001,
    parentProfessionID = 197, tipAmount = 6000 * 10000, updatedAt = now - 30 })
Log.Link('t1', 1, 'fulfilled')
Log.Request('Slot-Realm', { requestToken = 't2', parentProfID = 197, time = now - 50,
    equipmentRequest = { key = 'INVTYPE_WRIST', label = 'Wrist' } })
Scan.Generous.RecordTip('Buyer', 6000 * 10000, 1)
Log.Record({ k = 'c', o = 1, r = 1, p = 197, x = 'Tailor-Realm', t = now - 30,
    rs = { { i = 7001, n = 2, v = 30000, s = 'a', c = 1 } } })
Log.Record({ k = 'c', o = 2, r = 1, p = 197, x = 'Tailor-Realm', t = now - 20 })
Log.Record({ k = 'p', t = now - 90, e = now, f = 'H' })
Log.Merge({ { k = 'p', t = now - 60, e = now, f = 'H' } }, 'peer')

-- Opening it loads, counts and fills every tab.
Scan.AnalyticsWindow.Toggle()
local frame = _G.HironCraftAnalyticsFrame
assert(frame and Scan.AnalyticsWindow.IsShown(), 'the window did not open')
local items = frame.Items.rows
assert(#items == 2, 'item rows (only those with data): ' .. #items)
-- A cell that fails leaves the rest of the row and its hover intact.
for _, entry in ipairs(frame.Items.scrollBox.inited) do
    assert(entry.row.data == entry.data.row, 'a row kept the item it showed before')
    assert(entry.row.cells[#entry.row.cells].text ~= nil, 'a failing cell blanked the row')
end
-- Own dates are hidden until chosen.
assert(not frame.FromBox:IsShown() and not frame.ToBox:IsShown(), 'date boxes shown for a preset period')
assert(frame.Profession.anchor == frame.Period, 'the filters did not close the gap of the hidden dates')
assert(frame.Tiles.requests.value:GetText() == '2' and frame.Tiles.greetings.value:GetText() == '1'
    and frame.Tiles.crafted.value:GetText() == '1' and frame.Tiles.conversion.value:GetText() == '100%'
    and frame.Tiles.orders.value:GetText() == '1', 'the summary tiles are off')
assert(frame.Tiers:GetText():find('Customers in the period:', 1, true), 'no customers per coin')
assert(frame.Tiles.returnedValue.value.text:find('^6|T'), 'summary return value differs from the Returns report')
assert(frame.Tiles.online.value.text=='0:01', 'summary online doubled linked accounts or rounded up')
assert(frame.TileOrder.rows==2 and frame:GetWidth()==1080 and frame:GetHeight()==684,
    'extra metrics widened the window or overlapped the old header')
assert(frame.Tiers.y==-160 and frame.Inset.y==-186,'wrapped metrics overlap customer counts or content')
-- The hour's tooltip: the conversion of the greetings sent in it.
local noon = frame.HourChart.bars[13].info
assert(noon and noon.lines[5] == 'Conversion: 100% (1 / 1)', 'no hourly conversion: ' .. tostring(noon and noon.lines[5]))
assert(noon.lines[3] == 'Crafted: 1', 'the Ordered numerator is missing from the tooltip')
assert(frame.HourChart.bars[12].info.lines[5]:find('-', 1, true), 'an hour without greetings shows a conversion')
-- A figure wider than its tile widens it, not climbing over the name; the
-- tiles after it move along, and when the row runs into the buttons the
-- widened ones take the smaller font.
local function CheckTiles(small)
    local order = frame.TileOrder
    for index, tile in ipairs(order) do
        assert(tile.width >= tile.value:GetUnboundedStringWidth() + 12, 'a figure is wider than its tile')
        local font = small and small[tile] and 'GameFontHighlight' or 'GameFontHighlightLarge'
        assert(tile.value.font == font, 'the tile font is ' .. tostring(tile.value.font))
        local before = order[index - 1]
        assert(not before or tile.y < before.y or tile.x >= before.x + before.width + 4, 'tiles overlap')
        assert(tile.x + tile.width <= frame:GetWidth() - 284, 'tile overlaps the right-hand controls')
    end
end
CheckTiles()
charWidth = 30
Scan.AnalyticsWindow.Rebuild()
assert(frame.Tiles.tips.width > 104, 'a long sum of tips did not widen its tile')
CheckTiles({ [frame.Tiles.tips] = true, [frame.Tiles.averageTip] = true, [frame.Tiles.conversion] = true,
    [frame.Tiles.online] = true })
charWidth = 5
Scan.AnalyticsWindow.Rebuild()
CheckTiles()
local found = false
for _, text in ipairs(texts) do
    if type(text) == 'string' and text:find('Item 1001', 1, true) then found = true end
end
assert(found, 'the crafted item was not drawn in the table')
assert(#frame.Customers.rows == 2, 'customer rows: ' .. #frame.Customers.rows)

-- Filters, tabs and sorting redraw without errors.
local view = Scan.DB.settings.analytics_view
view.side = 'A'
Scan.AnalyticsWindow.Rebuild()
assert(#frame.Items.rows == 0, 'the Alliance filter kept Horde conversations')
view.side = 'H'
Scan.AnalyticsWindow.Rebuild()
assert(#frame.Items.rows == 2, 'the Horde filter lost its rows')
view.side = nil
view.tier = 'generous'
Scan.AnalyticsWindow.Rebuild()
assert(#frame.Customers.rows == 1 and frame.Customers.rows[1].key == 'buyer', 'the tier filter is off')
view.tier = nil
Scan.AnalyticsWindow.Rebuild()
for _, tab in ipairs(frame.Tabs) do tab.scripts.OnClick(tab) end
-- Sorting: down, up, then back to the usual order.
local tipHeader = frame.Items.headers[#frame.Items.headers]
tipHeader.scripts.OnClick(tipHeader)
assert(view.sort[1].key == 'averageTip' and view.sort[1].desc, 'the first click did not sort')
tipHeader.scripts.OnClick(tipHeader)
assert(view.sort[1].key == 'averageTip' and not view.sort[1].desc, 'the second click did not turn the order')
tipHeader.scripts.OnClick(tipHeader)
Scan.AnalyticsWindow.Rebuild()
assert(view.sort[1].key == 'orders' and view.sort[1].desc and not view.sort[1].step,
    'the third click did not go back to the usual order')
for _, header in ipairs(frame.Items.headers) do header.scripts.OnClick(header) end
for _, header in ipairs(frame.Customers.headers) do header.scripts.OnClick(header) end

-- Search by name or item ID; customers on their tab.
local function Type(text)
    frame.Search:SetText(text)
    Soon(function() frame.Search.scripts.OnTextChanged(frame.Search) end)
end
Type('Item 1001')
assert(#frame.Items.rows == 1 and frame.Items.rows[1].itemID == 1001, 'the search did not find the item')
Type('1001')
assert(#frame.Items.rows == 1 and frame.Items.rows[1].itemID == 1001, 'the search did not find the item by its ID')
Type('BUYER')
assert(#frame.Customers.rows == 1 and frame.Customers.rows[1].key == 'buyer', 'the customer search is off')
Type('')
assert(#frame.Items.rows == 2 and #frame.Customers.rows == 2, 'clearing the search did not bring the rows back')

-- Own dates typed in the boxes.
frame.FromBox:SetText('19.09.2026')
frame.FromBox.scripts.OnEnterPressed(frame.FromBox)
assert(view.preset == 'custom' and os.date('%d.%m', view.from) == '19.09', 'a typed date was not used')
assert(frame.FromBox:IsShown() and frame.ToBox:IsShown(), 'date boxes hidden for own dates')
assert(frame.Profession.anchor == frame.ToBox, 'the filters did not move over for the dates')
frame.ToBox:SetText('nonsense')
frame.ToBox.scripts.OnEnterPressed(frame.ToBox)
assert(view.preset == 'custom', 'a wrong date broke the period')

-- CSV of each tab.
view.preset = 'all'
Scan.AnalyticsWindow.Reload()
for tab, header in ipairs({ 'item,item_id', 'customer,tier', 'period,requests' }) do
    frame.Tabs[tab].scripts.OnClick(frame.Tabs[tab])
    dumped = nil
    frame.ExportButton.scripts.OnClick(frame.ExportButton)
    assert(dumped and dumped:sub(1, #header) == header and dumped:find('\n', 1, true),
        'CSV of tab ' .. tab .. ' is off')
end
assert(dumped:find('00:00,', 1, true), 'the time CSV has no hours')

-- The resource returns tab: its own tiles, no side or coin filter.
-- A reagent not loaded yet shows its number, and its name once the game has
-- it; its rank is marked.
unloaded[7001] = true
Scan.AnalyticsWindow.Rebuild()
frame.Tabs[4].scripts.OnClick(frame.Tabs[4])
assert(#frame.Returns.rows == 1 and frame.Returns.rows[1].itemID == 7001, 'the returns table is off')
local function ReagentCell()
    local inited = frame.Returns.scrollBox.inited
    return inited[#inited].row.cells[1].text
end
assert(ReagentCell():find('#7001', 1, true) and ReagentCell():find('Professions-Icon-Quality-12-Tier2', 1, true),
    'an unloaded reagent or its rank is drawn wrong: ' .. ReagentCell())
unloaded[7001] = nil
frame.scripts.OnEvent(frame, 'ITEM_DATA_LOAD_RESULT', 7001, true)
RunTimers()
assert(ReagentCell():find('Item 7001', 1, true), 'the reagent name did not come: ' .. ReagentCell())
assert(frame.ReturnTiles.chance.value:GetText() == '50%' and frame.ReturnTiles.crafts.value:GetText() == '2',
    'the returns tiles are off')
assert(frame:GetHeight()==640 and frame.Inset.y==-142, 'the Returns tab retained an empty summary row')
assert(not frame.SideDropdown:IsShown() and not frame.TierDropdown:IsShown() and not frame.Tiers:IsShown()
    and frame.ReturnTiles.value:IsShown() and not frame.Tiles.requests:IsShown(), 'the returns tab shows the wrong controls')
dumped = nil
frame.ExportButton.scripts.OnClick(frame.ExportButton)
assert(dumped and dumped:find('^reagent,item_id') and dumped:find('7001', 1, true), 'the returns CSV is off')
frame.Tabs[1].scripts.OnClick(frame.Tabs[1])
assert(frame.SideDropdown:IsShown() and frame.Tiles.requests:IsShown(), 'leaving the returns tab left its controls')
assert(frame:GetHeight()==684 and frame.Inset.y==-186, 'leaving Returns did not restore the wrapped header')

-- Closing lets the data go.
-- The lower chart is an independent calendar, not a sum of all Mondays.
local W, R = Scan.AnalyticsWindow, Scan.AnalyticsReport
local function At(y, m, d, h) return os.time({ year = y, month = m, day = d, hour = h or 0, min = 0, sec = 0 }) end
Log.Record({ k = 'd', st = 'f', o = 901, c = 'Calendar', p = 197, f = 'H', t = At(2026, 9, 15, 9) })
Log.Record({ k = 'd', st = 'f', o = 902, c = 'Calendar', p = 197, f = 'H', t = At(2026, 9, 19, 10) })
Log.Record({ k = 'd', st = 'f', o = 903, c = 'Calendar', p = 197, f = 'H', t = At(2026, 9, 8, 14) })
Log.Record({ k = 'd', st = 'f', o = 904, c = 'Calendar', p = 197, f = 'H', t = At(2025, 2, 14, 15) })
frame.Tabs[3].scripts.OnClick(frame.Tabs[3])
W.SelectCalendarPeriod('week', now)
assert(view.preset == 'week' and #frame.DayChart.buckets == 7)
local weekAnchor = view.calendarAnchor
local function ClickDay(index)
    local bar = frame.DayChart.bars[index]
    bar.scripts.OnClick(bar)
end
ClickDay(2)
assert(view.preset == 'custom' and view.calendarAnchor == weekAnchor and date('%d.%m', view.from) == '15.09')
assert(frame.FromBox.text == '15.09.2026' and frame.ToBox.text == '15.09.2026')
assert(frame.DayChart.bars[2].selection.shown and frame.HourChart.bars[10].value.text == 1)
assert(frame.HourChart.bars[15].value.text == '', 'another Tuesday leaked into selected day')
assert(frame.HourTitle.text:find('15.09.2026', 1, true))
assert(frame.DayChart.bars[6].value.text == 1, 'day selection narrowed the lower calendar')
ClickDay(6)
assert(view.preset == 'yesterday' and not frame.FromBox.shown)
ClickDay(7)
assert(view.preset == 'today' and view.calendarAnchor == weekAnchor)
W.MoveCalendar(-1)
assert(view.preset == 'custom' and date('%d.%m', view.from) == '07.09' and date('%d.%m', view.to) == '13.09')
assert(frame.DayChart.bars[2].value.text == 1, 'previous week was not loaded')
ClickDay(2)
assert(frame.HourChart.bars[15].value.text == 1 and frame.HourChart.bars[10].value.text == '')
W.MoveCalendar(1)
assert(view.preset == 'week' and not frame.CalendarNext.enabled)

W.SelectCalendarPeriod('year', At(2025, 7, 1))
assert(#frame.DayChart.buckets == 12 and frame.DayChart.bars[2].value.text == 1)
ClickDay(2)
assert(view.calendarMode == 'month' and #frame.DayChart.buckets == 28 and date('%Y-%m', view.from) == '2025-02')
assert(view.preset == 'custom' and date('%d.%m', view.to) == '28.02')
ClickDay(14)
assert(view.calendarMode == 'month' and #frame.DayChart.buckets == 28)
assert(frame.HourChart.bars[16].value.text == 1 and view.from == At(2025, 2, 14))
assert(frame.DayChart.bars[14].selection.shown and not frame.DayChart.bars[29].shown)
frame.ExportButton.scripts.OnClick(frame.ExportButton)
assert(dumped:find('2025-02-14,', 1, true), 'calendar CSV exported aggregated weekdays')
W.SelectCalendarPeriod('month', At(2024, 2, 10))
assert(#frame.DayChart.buckets == 29 and frame.DayChart.bars[29].shown and not frame.DayChart.bars[30].shown)
W.SelectCalendarPeriod('year', now)
assert(view.preset == 'year')
ClickDay(9)
assert(view.preset == 'month' and view.calendarMode == 'month' and #frame.DayChart.buckets == 30)
local previousFrom = view.from
ClickDay(30) -- now is September 20: future dates cannot be selected.
assert(view.from == previousFrom and not frame.DayChart.bars[30].enabled)

-- Common filters affect the calendar and the drill-down together.
view.side = 'A'; W.Rebuild()
assert(frame.DayChart.bars[15].value.text == '')
view.side = nil; W.Rebuild()
assert(frame.DayChart.bars[15].value.text == 1)

-- Rapid navigation while loading: an older reply must not replace the new one.
local originalLoad, pending = Log.LoadRange, {}
W.Release() -- The earlier All time selection had cached every historical year.
Log.LoadRange = function(from, to, _, done)
    local request = { from = from, to = to, done = done }
    pending[#pending + 1] = request
    return function() request.cancelled = true end
end
W.SelectCalendarPeriod('year', At(2022, 1, 1))
W.SelectCalendarPeriod('year', At(2021, 1, 1))
assert(#pending == 2 and pending[2].from == At(2021, 1, 1))
assert(pending[1].cancelled, 'obsolete year kept unpacking after rapid navigation')
pending[2].done({ { { k = 'd', st = 'f', o = 1000, c = 'Older', t = At(2021, 3, 1) } } })
assert(frame.DayChart.bars[3].value.text == 1)
pending[1].done({})
assert(frame.DayChart.bars[3].value.text == 1 and frame.CalendarTitle.text:find('2021', 1, true))
Log.LoadRange = originalLoad
print('Analytics calendar UI passed (day clicks, presets, navigation, year/month/day drill-down, filters, CSV, load races).')

-- Summary metrics reuse the same historical returns and unioned presence as
-- the detailed reports. Missing prices are explicit; own reagents stay out.
view.preset = 'today'; view.side = nil; view.ppID = nil; view.crafter = nil; view.tier = nil
Log.Record({ k = 'c', o = 3, r = 1, p = 197, x = 'Tailor-Realm', t = now - 10,
    rs = { { i = 7002, n = 3, c = 1 }, { i = 7003, n = 100, v = 90000 } } })
W.Reload()
assert(frame.Tiles.returnedValue.value.text:find('^6|T')
    and frame.Tiles.returnedValue.value.text:find('*',1,true), 'unpriced/own reagents inflated returns or lacked a warning')
assert(frame.Tiles.online.value.text=='0:01')
local tooltipLines = {}
GameTooltip.AddLine = function(_, text) tooltipLines[#tooltipLines+1] = text end
GameTooltip.AddDoubleLine = function(_, left, right) tooltipLines[#tooltipLines+1] = left..': '..right end
frame.Tiles.returnedValue.scripts.OnEnter(frame.Tiles.returnedValue)
assert(tooltipLines[1]=='Reagents returned: 5' and tooltipLines[2]=='Without a price: 3',
    'return tooltip lost reagent quantities or missing-price count')
frame.Tiles.online.scripts.OnEnter(frame.Tiles.online)
assert(tooltipLines[3]=='1 min 30 s','online tooltip lost precise seconds')

view.side = 'A'; W.Rebuild()
assert(frame.Tiles.online.value.text=='0:00' and frame.Tiles.returnedValue.value.text:find('^6|T'),
    'faction filtering disagrees with the existing online/returns reports')
view.side = nil; view.crafter = 'Other-Realm'; W.Rebuild()
assert(frame.Tiles.online.value.text=='0:01' and frame.Tiles.returnedValue.value.text:find('^0|T')
    and not frame.Tiles.returnedValue.value.text:find('*',1,true), 'crafter filtering left stale return figures')
view.crafter = nil; view.ppID = 164; W.Rebuild()
assert(frame.Tiles.online.value.text=='0:01' and frame.Tiles.returnedValue.value.text:find('^0|T'),
    'profession filtering changed account presence or retained another profession returns')
view.ppID = nil; view.preset = 'yesterday'; W.Reload()
assert(frame.Tiles.online.value.text=='0:00' and frame.Tiles.returnedValue.value.text:find('^0|T'),
    'an empty date retained the previous day summary')

-- Local checkpoints refresh an already-open window, including an interval
-- not committed to the journal yet. Overlaps still count only once.
view.preset = 'today'; W.Reload()
Log.StartPresence()
now = now + 30; Log.NotePresence(); RunTimers()
assert(frame.Tiles.online.value.text=='0:02','live pending presence did not refresh the summary')
now = now + 30; Log.NotePresence(); RunTimers()
assert(frame.Tiles.online.value.text=='0:02','partial minutes rounded up in the summary')
Log.StopPresence(); RunTimers()

-- Long ranges display total hours, not a clock that wraps after 24 hours.
local multiDayStart = At(2026,9,10)
Log.Record({ k = 'p', t = multiDayStart, e = multiDayStart + 49*3600 + 120, f = 'H' })
view.preset = 'custom'; view.from = multiDayStart; view.to = multiDayStart + 3*86400 - 1
W.Reload()
assert(frame.Tiles.online.value.text=='49:02' and frame.Tiles.returnedValue.value.text:find('^0|T'),
    'multi-day online time wrapped at midnight or ignored the selected dates')
print('Analytics summary metrics passed (historical value, missing prices, quantities, filters, interval union, live refresh, multi-day hours, layout).')

Scan.AnalyticsWindow.Toggle()
assert(not Scan.AnalyticsWindow.IsShown() and #frame.Items.rows == 0, 'closing kept the data')
print('Analytics window passed (open, tabs, filters, sorting, dates, CSV, close).')
