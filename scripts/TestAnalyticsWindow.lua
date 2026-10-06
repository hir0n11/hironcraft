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
    local object = { kind = kind, scripts = {}, points = {}, shown = true, text = nil, width = 800, height = 300 }
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
    function methods:SetScale(scale) self.scale = scale end
    function methods:SetColorTexture(...) self.color = { ... } end
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
    function methods:GetFrames()
        local frames = {}
        for _, entry in ipairs(self.inited or {}) do frames[#frames+1] = entry.row end
        return frames
    end
    function methods:SetDataProvider(provider)
        self.providerSetCount = (self.providerSetCount or 0) + 1
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
    function methods:SetPoint(point, relative, relativePoint, x, y)
        self.anchor, self.x, self.y = relative, x, y
        self.points[point] = { relative = relative, point = relativePoint, x = x, y = y }
    end
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
    frame.parent = parent
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
local priceScans, priceChanges = 0, nil
Scan.ReturnPrices = {
    Status = function() return {open=true, catalog=4, total=0, finished=0} end,
    OnChange = function(fn) priceChanges=fn end,
    Start = function(force) assert(force); priceScans=priceScans+1 end,
    Observe = function() end,
    GetPrice = function() return nil end,
}
load('Customer/GenerousCustomers.lua')
load('Customer/AnalyticsLog.lua')
load('Customer/AnalyticsReport.lua')
load('Customer/AnalyticsSync.lua')
load('Customer/AnalyticsProfiles.lua')
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
-- An existing saved single-metric choice migrates once to the comparison.
Scan.DB.settings.analytics_view = { preset = '30d', tab = 1, metric = 'orders' }
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
assert(frame:GetWidth()==1080 and frame:GetHeight()==670, 'the summary changed the fixed window size')
assert(frame.Tiers.points.TOPLEFT.y==-116 and frame.Inset.points.TOPLEFT.y==-172, 'summary, customer counts and content do not have separate rows')
assert(frame.Toolbar.y==-138 and frame.Toolbar.height==22 and frame.Toolbar.width==1048,
    'the toolbar is not below the metrics and above the chart')
assert(frame.Search.parent==frame.Toolbar and frame.Search.anchor==frame.Toolbar
    and frame.ExportButton.parent==frame.Toolbar and frame.ExportButton.anchor==frame.Toolbar
    and frame.SyncButton.anchor==frame.ExportButton,
    'search/actions still occupy the metrics row')
-- Gathering is switched in the settings: no checkbox here, and no note while it is on.
assert(rawget(frame, 'GatherCheck')==nil and not frame.GatherOffText:IsShown()
    and frame.SyncText.points.LEFT.relative==frame.Search, 'the toolbar still carries the gathering switch')
-- The hour's tooltip: the conversion of the greetings sent in it.
local noon = frame.HourChart.bars[13].info
assert(noon and noon.lines[5] == 'Conversion: 100% (1 / 1)', 'no hourly conversion: ' .. tostring(noon and noon.lines[5]))
assert(noon.lines[3] == 'Crafted: 1', 'the Ordered numerator is missing from the tooltip')
assert(frame.HourChart.bars[12].info.lines[5]:find('-', 1, true), 'an hour without greetings shows a conversion')
local paidHour=frame.HourChart.bars[tonumber(date('%H',now-30))+1].info
assert(paidHour.lines[6]:find('Gold from orders: 6000|T',1,true)
    and paidHour.lines[6]:find('*',1,true),'hour tooltip lost its income or estimated marker')
assert(table.concat(paidHour.lines,'\n'):find('Order gold estimated',1,true), 'legacy commission estimate not explained')

-- All three counts use their own heights on one scale. Ordered is part of
-- Greeted; Requests may be larger OR smaller because their timestamps differ.
assert(Scan.DB.settings.analytics_view.metric == 'overview'
    and frame.HourChart.metric == 'overview' and frame.DayChart.metric == 'overview',
    'the comparison did not become the default on both charts')
assert(frame.ChartLegend.entries.greetings.shown and frame.ChartLegend.entries.crafted.shown
    and frame.ChartLegend.entries.requests.shown and frame.ChartLegend.note.shown,
    'the comparison legend is incomplete')
for _, chart in ipairs({ frame.HourChart, frame.DayChart }) do
    local stats = { greetings = 20, crafted = 8, requests = 30, orders = 100 }
    chart:SetValues({ 8, 0, 2 }, { { stats = stats }, { stats = {} },
        { stats = { greetings = 12, crafted = 2, requests = 1 } } }, { 0.5, 0, 0.25 },
        { 'A', 'B', 'C' }, { true }, 'overview')
    local bar, height = chart.bars[1], chart:GetHeight() - 40
    assert(chart.maximum >= 30 and chart.maximum < 100, 'scale summed the stages or included tooltip-only orders')
    assert(math.abs(bar.series.greetings.height / height - 20 / chart.maximum) < 0.001)
    assert(math.abs(bar.series.crafted.height / height - 8 / chart.maximum) < 0.001)
    assert(math.abs(bar.series.requests.height / height - 30 / chart.maximum) < 0.001)
    assert(bar.series.crafted.x > 0 and bar.series.crafted.x + bar.series.crafted.width < bar.series.greetings.width,
        'yellow no longer fits inside grey')
    assert(bar.series.requests.x > bar.series.greetings.width, 'requests overlap the greeting count')
    assert(chart.bars[3].series.requests.height < chart.bars[3].series.crafted.height,
        'a smaller request count was incorrectly treated as an outer funnel')
    assert(not chart.bars[2].series.greetings.shown and not chart.bars[2].series.crafted.shown
        and not chart.bars[2].series.requests.shown, 'zero counts draw fake bars')
    assert(bar.value.text == 8 and not bar.fill.shown and bar.selection.shown,
        'the comparison label or calendar selection is wrong')
    assert(bar.onlineFill.shown and math.abs(bar.onlineFill.width - bar.width * 0.5) < 0.001,
        'the online gauge changed its units')
    chart:SetValues({})
    assert(not chart.bars[1].shown and not chart.bars[1].series.crafted.shown
        and not chart.grid[1].label.shown, 'clearing the chart left old comparison marks')
end
local function SelectMetric(key)
    local selected
    frame.MetricDropdown.menu(frame.MetricDropdown, { CreateRadio = function(_, _, _, action, value)
        if value == key then selected = action end
    end })
    assert(selected, 'missing metric choice: ' .. key)
    selected()
end
SelectMetric('requests')
Scan.AnalyticsWindow.Rebuild()
assert(Scan.DB.settings.analytics_view.metric == 'requests' and frame.HourChart.metric == 'requests',
    'rebuilding overwrote a chosen individual metric')
assert(not frame.ChartLegend.entries.greetings.shown and frame.ChartLegend.entries.requests.shown
    and not frame.ChartLegend.note.shown, 'single-metric view kept the comparison legend')
SelectMetric('overview')
assert(frame.HourChart.metric == 'overview' and frame.DayChart.metric == 'overview')
print('Analytics comparison passed (default migration, independent scales, nesting, zero counts, legend, online time, metric choices).')
-- All metrics stay on one baseline. Spare width is distributed; long figures
-- shrink/fill as one strip, never wrap or disappear behind the toolbar.
local function CheckTiles(small, order)
    order = order or frame.TileOrder
    for index, tile in ipairs(order) do
        assert(tile.width >= tile.value:GetUnboundedStringWidth() + 12, 'a figure is wider than its tile')
        local font = small and small[tile] and 'GameFontHighlight' or 'GameFontHighlightLarge'
        if small ~= false then assert(tile.value.font == font, 'the tile font is ' .. tostring(tile.value.font)) end
        local before = order[index - 1]
        assert(tile.y==0 and tile.anchor==order.frame, 'a metric moved onto another row')
        assert(not before or tile.x >= before.x + before.width + 4, 'tiles overlap')
        assert((tile.x + tile.width) * order.frame.scale <= frame:GetWidth() - 32 + 0.01,
            'a metric extends beyond the available width')
    end
    local last = order[#order]
    assert(math.abs((last.x + last.width) * order.frame.scale - (frame:GetWidth()-32)) < 0.01,
        'metrics do not evenly fill the available strip')
    assert(math.abs(order.frame.x * order.frame.scale - 16)<0.01
        and math.abs(order.frame.y * order.frame.scale + 68)<0.01, 'scaled metrics shifted the outer margin')
    assert(frame:GetHeight()==670 and frame.Inset.points.TOPLEFT.y==-172, 'long numbers changed the window height')
end
CheckTiles()
assert(frame.TileOrder.frame.scale==1,'normal figures were unnecessarily scaled down')
charWidth = 30
Scan.AnalyticsWindow.Rebuild()
assert(frame.Tiles.tips.width > 104, 'a long sum of tips did not widen its tile')
CheckTiles({ [frame.Tiles.tips] = true, [frame.Tiles.averageTip] = true, [frame.Tiles.conversion] = true,
    [frame.Tiles.online] = true })
assert(frame.TileOrder.frame.scale<1,'unusually wide figures did not fit the single strip')
charWidth = 5
Scan.AnalyticsWindow.Rebuild()
CheckTiles()
assert(frame.TileOrder.frame.scale==1,'smaller totals did not restore normal text size')
-- Wide translated labels must also stay intact on one line.
local savedWidths = {}
for index, tile in ipairs(frame.TileOrder) do
    savedWidths[index] = tile.minWidth
    tile.minWidth = tile.minWidth + 40
end
Scan.AnalyticsWindow.Rebuild()
CheckTiles(false)
for index, tile in ipairs(frame.TileOrder) do tile.minWidth = savedWidths[index] end
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
assert(frame.PriceScan:IsShown() and frame.PriceStatus:IsShown() and priceScans==0)
assert(frame.PriceScan.points.TOPRIGHT.y==-111, 'price controls overlap the metric tiles')
frame.PriceScan.scripts.OnClick()
assert(priceScans==1, 'manual price refresh did not request a forced targeted scan')
Scan.ReturnPrices.Status=function() return {open=true,catalog=4,total=4,finished=2,running=true,paused=true} end
priceChanges()
assert(frame.PriceScan:GetText()=='Paused 2/4', 'price progress is not visible')
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
assert(frame:GetHeight()==670 and frame.Inset.points.TOPLEFT.y==-172, 'the Returns tab moved/resized the content')
assert(frame.ReturnTileOrder.frame.shown and not frame.TileOrder.frame.shown, 'inactive metric strip covers Returns')
CheckTiles(nil, frame.ReturnTileOrder)
assert(not frame.SideDropdown:IsShown() and not frame.TierDropdown:IsShown() and not frame.Tiers:IsShown()
    and frame.ReturnTiles.value:IsShown() and not frame.Tiles.requests:IsShown(), 'the returns tab shows the wrong controls')
dumped = nil
frame.ExportButton.scripts.OnClick(frame.ExportButton)
assert(dumped and dumped:find('^reagent,item_id') and dumped:find('7001', 1, true), 'the returns CSV is off')
frame.Tabs[1].scripts.OnClick(frame.Tabs[1])
assert(frame.SideDropdown:IsShown() and frame.Tiles.requests:IsShown(), 'leaving the returns tab left its controls')
assert(frame:GetHeight()==670 and frame.Inset.points.TOPLEFT.y==-172, 'leaving Returns moved/resized the content')
assert(frame.TileOrder.frame.shown and not frame.ReturnTileOrder.frame.shown, 'inactive Returns strip covers metrics')

-- Closing lets the data go.
-- The lower chart is an independent calendar, not a sum of all Mondays.
local W, R = Scan.AnalyticsWindow, Scan.AnalyticsReport
-- Exercise the retained Orders done view throughout the existing calendar tests.
SelectMetric('orders')
local function At(y, m, d, h) return os.time({ year = y, month = m, day = d, hour = h or 0, min = 0, sec = 0 }) end
Log.Record({ k = 'd', st = 'f', o = 901, c = 'Calendar', p = 197, f = 'H', t = At(2026, 9, 15, 9) })
Log.Record({ k = 'd', st = 'f', o = 902, c = 'Calendar', p = 197, f = 'H', t = At(2026, 9, 19, 10) })
Log.Record({ k = 'd', st = 'f', o = 903, c = 'Calendar', p = 197, f = 'H', t = At(2026, 9, 8, 14) })
Log.Record({ k = 'd', st = 'f', o = 904, c = 'Calendar', p = 197, f = 'H', t = At(2025, 2, 14, 15),
    tip=1500*10000,cut=150*10000 })
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
assert(frame.HourChart.kind=='days' and #frame.HourChart.buckets==28
    and frame.HourChart.detailMonth==At(2025,2,1),'past year did not default to its latest active month')
assert(frame.DayChart.bars[2].selection.shown and not frame.DetailBack.shown)
ClickDay(2)
assert(view.calendarMode == 'year' and #frame.DayChart.buckets == 12 and date('%Y-%m', view.from) == '2025-02')
assert(view.preset == 'custom' and date('%d.%m', view.to) == '28.02')
assert(frame.HourChart.bars[14].value.text==1 and frame.HourChart.bars[14].label.text=='14')
assert(frame.HourChart.bars[14].info.lines[6]:find('Gold from orders: 1350|T',1,true)
    and not frame.HourChart.bars[14].info.lines[6]:find('*',1,true),'daily income is not exact net gold')
assert(frame.DayChart.bars[2].info.lines[6]:find('Gold from orders: 1350|T',1,true),'monthly income is missing')
frame.ExportButton.scripts.OnClick(frame.ExportButton)
assert(dumped:find('tips_gold,tips_estimated,orders_without_tip_data',1,true)
    and dumped:find('2025-02-14,0,0,0,,1,1350,0,0',1,true)
    and not dumped:find('00:00,',1,true),'year detail CSV does not match the displayed days/income')
local function ClickDetailDay(index)
    local bar=frame.HourChart.bars[index]
    bar.scripts.OnClick(bar)
end
ClickDetailDay(14)
assert(view.calendarMode == 'year' and #frame.DayChart.buckets == 12 and frame.HourChart.kind=='hours')
assert(frame.HourChart.bars[16].value.text == 1 and view.from == At(2025, 2, 14))
assert(frame.DayChart.bars[2].selection.shown and not frame.HourChart.bars[25].shown and frame.DetailBack.shown)
assert(frame.HourChart.bars[1].label.text=='0' and frame.HourChart.bars[16].label.text=='15',
    'day labels survived the switch to hours')
frame.ExportButton.scripts.OnClick(frame.ExportButton)
assert(dumped:find('14.02.2025 15:00,0,0,0,,1,1350,0,0',1,true),'hourly CSV lost the selected day/income')
-- Reopening retains the day inside the year. Back restores month days, not
-- an aggregated hourly chart or a different year.
W.Toggle(); W.Toggle()
assert(view.calendarMode=='year' and frame.HourChart.kind=='hours' and frame.DetailBack.shown)
frame.DetailBack.scripts.OnClick(frame.DetailBack)
assert(frame.HourChart.kind=='days' and #frame.HourChart.buckets==28 and not frame.DetailBack.shown)
assert(view.from==At(2025,2,1) and #frame.DayChart.buckets==12)
ClickDay(1)
assert(#frame.HourChart.buckets==31 and frame.HourChart.bars[14].value.text==''
    and frame.HourChart.bars[14].info.lines[6]:find('Gold from orders: 0|T',1,true),'empty month retained old values')
W.SelectCalendarPeriod('month', At(2024, 2, 10))
assert(#frame.DayChart.buckets == 29 and frame.DayChart.bars[29].shown and not frame.DayChart.bars[30].shown)
assert(frame.HourChart.kind=='hours' and not frame.DetailBack.shown,'standalone month lost its hourly breakdown')
W.SelectCalendarPeriod('year',At(2024,1,1))
assert(frame.HourChart.detailMonth==At(2024,1,1),'an empty past year did not default to January')
ClickDay(2)
assert(#frame.HourChart.buckets==29 and not frame.HourChart.bars[30].shown,'year detail lost leap day')
ClickDetailDay(29)
assert(view.from==At(2024,2,29) and frame.HourChart.kind=='hours' and frame.DetailBack.shown)
frame.DetailBack.scripts.OnClick(frame.DetailBack)
assert(#frame.HourChart.buckets==29 and #frame.DayChart.buckets==12)
W.SelectCalendarPeriod('year', now)
assert(view.preset == 'year')
assert(frame.HourChart.kind=='days' and frame.HourChart.detailMonth==At(2026,9,1),
    'current year did not open the current month')
ClickDay(9)
assert(view.preset == 'month' and view.calendarMode == 'year' and #frame.DayChart.buckets == 12)
local previousFrom = view.from
ClickDetailDay(30) -- now is September 20: future dates cannot be selected.
assert(view.from == previousFrom and not frame.HourChart.bars[30].enabled)
ClickDay(12)
assert(view.from==previousFrom and not frame.DayChart.bars[12].enabled,'a future month was selected')

-- Common filters affect the calendar and the drill-down together.
view.side = 'A'; W.Rebuild()
assert(frame.HourChart.bars[15].value.text == '' and frame.DayChart.bars[9].value.text=='')
view.side = nil; W.Rebuild()
assert(frame.HourChart.bars[15].value.text == 1 and frame.DayChart.bars[9].value.text>0)
assert(table.concat(frame.HourChart.bars[15].info.lines,'\n'):find('Order gold incomplete',1,true),
    'an order without stored tip data was displayed as known zero income')
-- Explicit period filters leave year drill-down; no stale month/day may win.
ClickDetailDay(15)
local selectToday
frame.Period.menu(frame.Period,{CreateRadio=function(_,_,_,click,value)
    if value=='today' then selectToday=click end
end})
assert(selectToday); selectToday()
assert(view.calendarMode=='week' and view.yearDetailMonth==nil and view.yearDetailDay==nil
    and frame.HourChart.kind=='hours' and not frame.DetailBack.shown,'Today retained year detail state')
W.SelectCalendarPeriod('year',now)
W.MoveCalendar(-1)
assert(frame.HourChart.detailMonth==At(2025,2,1) and frame.HourChart.kind=='days'
    and view.yearDetailDay==nil,'year navigation retained stale detail from another year')
W.MoveCalendar(1)
assert(frame.HourChart.detailMonth==At(2026,9,1))

-- Changing the bottom dropdown always starts at Current, even after a
-- historical drill-down. Only the explicit arrows keep browsing history.
local function SelectCalendarMode(mode)
    local selected
    frame.CalendarMode.menu(frame.CalendarMode, { CreateRadio=function(_,_,_,click,value)
        if value==mode then selected=click end
    end })
    assert(selected, 'calendar mode missing: '..mode); selected()
end
for _, mode in ipairs({'week','month','year'}) do
    W.SelectCalendarPeriod('year', At(2025,1,1))
    ClickDay(2); ClickDetailDay(14)
    SelectCalendarMode(mode)
    local first, last=R.CalendarRange(mode,now)
    assert(view.calendarMode==mode and view.preset==mode and view.yearDetailMonth==nil
        and view.yearDetailDay==nil, 'calendar dropdown retained historical drill-down: '..mode)
    assert(frame.DayChart.buckets[1].from==first
        and frame.DayChart.buckets[#frame.DayChart.buckets].to==last,
        'calendar dropdown did not open Current: '..mode)
    W.MoveCalendar(-1)
    assert(frame.DayChart.buckets[1].from<first, 'historical arrows stopped working: '..mode)
    SelectCalendarMode(mode)
    assert(frame.DayChart.buckets[1].from==first, 'reselecting the same mode did not return to Current')
end

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
assert(not frame.DetailBack.shown and #frame.HourChart.infos==0,'old detail remained actionable while loading')
pending[2].done({ { { k = 'd', st = 'f', o = 1000, c = 'Older', t = At(2021, 3, 1) } } })
assert(frame.DayChart.bars[3].value.text == 1)
assert(frame.HourChart.kind=='days' and frame.HourChart.detailMonth==At(2021,3,1)
    and frame.HourChart.bars[1].value.text==1,'new year detail did not follow the winning load')
pending[1].done({})
assert(frame.DayChart.bars[3].value.text == 1 and frame.CalendarTitle.text:find('2021', 1, true))
Log.LoadRange = originalLoad
print('Analytics calendar UI passed (day clicks, presets, navigation, year/month/day drill-down, filters, CSV, load races).')

-- Summary metrics reuse the same historical returns and unioned presence as
-- the detailed reports. The compact tile has no missing-price alert; own reagents stay out.
view.preset = 'today'; view.side = nil; view.ppID = nil; view.crafter = nil; view.tier = nil
Log.Record({ k = 'c', o = 3, r = 1, p = 197, x = 'Tailor-Realm', t = now - 10,
    rs = { { i = 7002, n = 3, c = 1 }, { i = 7003, n = 100, v = 90000 } } })
W.Reload()
assert(frame.Tiles.returnedValue.value.text:find('^6|T')
    and not frame.Tiles.returnedValue.value.text:find('*',1,true), 'return value changed or the summary warning remained')
assert(frame.Tiles.online.value.text=='0:01')
local tooltipLines = {}
GameTooltip.AddLine = function(_, text) tooltipLines[#tooltipLines+1] = text end
GameTooltip.AddDoubleLine = function(_, left, right) tooltipLines[#tooltipLines+1] = left..': '..right end
frame.Tiles.returnedValue.scripts.OnEnter(frame.Tiles.returnedValue)
assert(tooltipLines[1]=='Reagents returned: 5' and #tooltipLines==1,
    'return tooltip lost reagent quantities or still warns about missing prices')
frame.Tiles.online.scripts.OnEnter(frame.Tiles.online)
assert(tooltipLines[2]=='1 min 30 s','online tooltip lost precise seconds')

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

-- Diamond customers get the same mark in rows, counters, filtering and CSV.
Scan.Generous.RecordTip('Buyer',14000*10000,11000) -- 6k + 14k = 10k average.
Log.Outcome({orderID=11000,status='fulfilled',customerName='Buyer',itemID=1001,
    parentProfessionID=197,tipAmount=14000*10000,updatedAt=now})
view.preset='all'; view.tier=nil; W.Reload()
local diamondCount=Scan.Generous.Icon('diamond')..' |cffffffff1|r'
local firstDiamond=assert(frame.Tiers.text:find(diamondCount,1,true),'period diamond counter missing')
assert(frame.Tiers.text:find(diamondCount,firstDiamond+#diamondCount,true),'overall diamond counter missing')
local diamondFilter
frame.TierDropdown.menu(frame.TierDropdown,{CreateRadio=function(_,text,selected,click,value)
    if value=='diamond' then
        assert(text:find(Scan.Generous.Icon('diamond'),1,true),'diamond filter lacks its icon')
        diamondFilter=click
    end
end})
assert(diamondFilter,'diamond tier missing from filter choices')
diamondFilter()
assert(#frame.Customers.rows==1 and frame.Customers.rows[1].key=='buyer'
    and frame.Customers.rows[1].mark=='diamond','diamond filter did not narrow the customer table')
local renderedDiamond=false
for _,entry in ipairs(frame.Customers.scrollBox.inited) do
    if entry.row.cells[1].text:find(Scan.Generous.Icon('diamond'),1,true) then renderedDiamond=true end
end
assert(renderedDiamond,'customer row does not render the diamond')
frame.Tabs[2].scripts.OnClick(frame.Tabs[2])
frame.ExportButton.scripts.OnClick(frame.ExportButton)
assert(dumped:find(',diamond,',1,true),'CSV lost the diamond tier')
view.tier=nil; W.Rebuild()
CheckTiles()
print('Diamond analytics UI passed (existing-average promotion, counters, filter, customer row, CSV).')

-- The video regression: progress notifications must not erase a committed
-- chart/table for a frame. Coalesce updates and reuse unchanged row identities.
do
    W.SelectCalendarPeriod('week',now)
    RunTimers()
    local loaded
    originalLoad(0,now,nil,function(result) loaded=result end)
    assert(loaded)
    local requests={}
    Log.LoadRange=function(from,to,progress,done)
        local request={from=from,to=to,progress=progress,done=done}
        requests[#requests+1]=request
        return function() request.cancelled=true end
    end
    local hourInfos, dayInfos=frame.HourChart.infos,frame.DayChart.infos
    local orders, status, sync=frame.Tiles.orders.value.text,frame.Status.text,frame.SyncText.text
    local boxes={frame.Items.scrollBox,frame.Customers.scrollBox,frame.Returns.scrollBox}
    local providers, rowFrames, providerCounts={},{},{}
    for i,box in ipairs(boxes) do
        providers[i],rowFrames[i],providerCounts[i]=box.provider,box:GetFrames(),box.providerSetCount
    end
    Log.Record({k='p',t=now-1,e=now,f='H'}) -- queues the slower local refresh
    for _=1,12 do W.DataArrived() end -- supersedes it with one peer refresh
    RunTimers()
    assert(#requests==1,'a local/remote burst started redundant loads')
    requests[1].progress(1,4)
    assert(frame.HourChart.infos==hourInfos and frame.DayChart.infos==dayInfos
        and frame.Tiles.orders.value.text==orders and frame.Status.text==status
        and frame.SyncText.text==sync and frame.ExportButton.enabled,
        'background loading cleared/relabelled the committed view')
    for _=1,12 do W.DataArrived() end
    RunTimers()
    assert(#requests==1 and not requests[1].cancelled,'new data restarted an unfinished load')
    requests[1].done(loaded)
    for i,box in ipairs(boxes) do
        assert(box.provider==providers[i] and box.providerSetCount==providerCounts[i],
            'unchanged table replaced its provider')
        for j,row in ipairs(box:GetFrames()) do
            assert(row==rowFrames[i][j] and row.data==box.provider.list[j].row,
                'value refresh recycled a visible row or left stale hover data')
        end
    end
    RunTimers()
    assert(#requests==2,'updates during loading did not produce one trailing refresh')
    requests[2].done(loaded); RunTimers()
    assert(#requests==2,'the refresh loop continued without new data')

    -- Changing a value updates the same frame and its hover data; a new key
    -- does replace the provider, retaining the normal scroll-box behavior.
    local tableUI=frame.Customers
    local oldRow=tableUI.scrollBox:GetFrames()[1]
    local edited={}
    for k,v in pairs(oldRow.data) do edited[k]=v end
    edited.orders=(edited.orders or 0)+1
    local rows={}
    for i,row in ipairs(tableUI.rows) do rows[i]=row.key==edited.key and edited or row end
    view.sort[2]={key='name',desc=false}
    tableUI:SetRows(rows) -- establish a fixed name order
    local provider=tableUI.scrollBox.provider
    local keptFrame
    for _,row in ipairs(tableUI.scrollBox:GetFrames()) do if row.data.key==edited.key then keptFrame=row end end
    local nextRow={}
    for k,v in pairs(edited) do nextRow[k]=v end
    nextRow.orders=edited.orders+1
    for i,row in ipairs(rows) do if row.key==nextRow.key then rows[i]=nextRow end end
    tableUI:SetRows(rows)
    assert(tableUI.scrollBox.provider==provider and keptFrame.data==nextRow
        and keptFrame.cells[2].text==tostring(nextRow.orders),'changed count was not updated in place')
    tableUI:SetRows({})
    assert(tableUI.scrollBox.provider~=provider and #tableUI.scrollBox.provider.list==0,
        'removed rows survived a structural refresh')

    -- Navigation wins over background loads; old results cannot overwrite it.
    W.DataArrived(); RunTimers()
    assert(#requests==3)
    W.SelectCalendarPeriod('year',At(2020,1,1))
    assert(#requests==4 and requests[3].cancelled and not frame.ExportButton.enabled)
    assert(frame.HourChart.infos~=nil and #frame.HourChart.infos>0,
        'manual navigation erased the old chart before its replacement arrived')
    local oldChart=frame.HourChart.infos
    W.Rebuild()
    assert(frame.HourChart.infos==oldChart,'foreground load rebuilt old data under a new date')
    requests[4].done({})
    local winningChart=frame.HourChart.infos
    requests[3].done(loaded)
    assert(frame.HourChart.infos==winningChart and frame.CalendarTitle.text:find('2020',1,true),
        'late background data replaced the selected year')

    -- Closing cancels work and invalidates timers, even if reopened before
    -- those timers run. Late callbacks from the old session stay ignored.
    W.DataArrived(); RunTimers()
    local closing=requests[#requests]
    W.DataArrived()
    W.Toggle()
    assert(closing.cancelled)
    Log.LoadRange=originalLoad
    W.Toggle()
    local reopenedChart=frame.HourChart.infos
    closing.done(loaded)
    RunTimers()
    assert(frame.HourChart.infos==reopenedChart,'a closed session changed the reopened view')
    W.SelectCalendarPeriod('week',now)
end
print('Stable analytics refresh passed (silent progress, coalescing, trailing refresh, row reuse, changed values, navigation, close/reopen).')

-- Moving actions to the toolbar must preserve their manual callbacks.
local originalSync, syncClicks = Scan.AnalyticsSync.SyncNow, 0
Scan.AnalyticsSync.SyncNow = function() syncClicks = syncClicks + 1 end
frame.SyncButton.scripts.OnClick(frame.SyncButton)
assert(syncClicks==1, 'the relocated sync button does not respond')
Scan.AnalyticsSync.SyncNow = originalSync
-- Switched off in the settings: the window says so, next to the search box.
Log.SetEnabled(false)
Scan.AnalyticsWindow.GatheringChanged()
assert(frame.GatherOffText:IsShown() and frame.GatherOffText.text=='Data collection is off'
    and frame.GatherOffText.anchor==frame.Search and frame.SyncText.points.LEFT.relative==frame.GatherOffText,
    'the window does not say that gathering is off')
Log.SetEnabled(true)
Scan.AnalyticsWindow.GatheringChanged()
assert(not frame.GatherOffText:IsShown() and frame.SyncText.points.LEFT.relative==frame.Search,
    'the note stayed after gathering was switched on')
-- And it is looked at again whenever the window opens.
Log.SetEnabled(false)
frame:Hide(); frame:Show()
assert(frame.GatherOffText:IsShown(), 'a reopened window does not notice that gathering is off')
Log.SetEnabled(true)
frame:Hide(); frame:Show()
assert(not frame.GatherOffText:IsShown(), 'a reopened window does not notice that gathering is on')
print('Analytics single-row header passed (long values/labels, stable tabs, separate toolbar, manual actions).')

-- Crafter pool profiles: the list on the toolbar picks and edits them.
do
    local Profiles = Scan.AnalyticsProfiles
    local view = Scan.DB.settings.analytics_view
    local dropdown = frame.ProfileDropdown
    assert(dropdown and dropdown.menu, 'no profile list on the toolbar')
    assert(frame.SyncText.points.RIGHT.relative == dropdown, 'the status text runs under the profile list')
    MenuResponse = { Refresh = 'refresh' }
    Scan.GetPlayerName = function() return 'Tailor-Realm' end
    local asked
    Scan.Dialog = { Element = { EditBox = 1, Text = 2 }, Show = function(config) asked = config end }
    local generated = 0
    function dropdown:GenerateMenu() generated = generated + 1 end

    local function Menu()
        local function Node(text, kind)
            local node = { text = text, kind = kind, children = {} }
            local function Add(child) node.children[#node.children + 1] = child return child end
            function node:CreateRadio(label, isSelected, setSelected)
                local child = Add(Node(label, 'radio'))
                child.selected, child.click = isSelected, setSelected
                return child
            end
            function node:CreateCheckbox(label, isSelected, setSelected)
                local child = Add(Node(label, 'checkbox'))
                child.selected, child.click = isSelected, setSelected
                return child
            end
            function node:CreateButton(label, callback)
                local child = Add(Node(label, 'button'))
                child.click = callback
                return child
            end
            function node:CreateTitle(label) return Add(Node(label, 'title')) end
            function node:CreateDivider() return Add(Node(nil, 'divider')) end
            function node:Find(label)
                for _, child in ipairs(self.children) do
                    if child.text == label then return child end
                end
            end
            return node
        end
        local root = Node('root', 'root')
        dropdown.menu(dropdown, root)
        return root
    end
    local function Tile(key) return frame.Tiles[key].value.text end

    -- Without profiles: everything, and a way to make one.
    local root = Menu()
    assert(root:Find('All characters').selected(), 'all characters is the choice without profiles')
    assert(root:Find('New profile...'), 'no way to make a profile')
    local requestsBefore, ordersBefore = Tile('requests'), Tile('orders')

    -- The first profile takes every known character and the earlier history: the counts stay.
    root:Find('New profile...').click()
    assert(asked and asked.key == 'analytics_profile_new', 'the name was not asked for')
    asked.OnAccept('Main pool')
    local pool = Profiles.List()[1]
    assert(pool and pool.name == 'Main pool' and view.profile == pool.id, 'the new profile was not selected')
    assert(generated > 0, 'the list was not rebuilt')
    assert(Tile('requests') == requestsBefore and Tile('orders') == ordersBefore, 'the first profile changed the counts')
    root = Menu()
    assert(root:Find('Main pool').selected() and not root:Find('All characters').selected(), 'the profile is not shown as chosen')
    local edit = root:Find('Profile characters: Main pool')
    assert(edit and edit:Find('Tailor'), 'the profile\'s characters cannot be ticked')
    assert(edit:Find('Tailor').selected(), 'a known crafter did not start in the first profile')

    -- A second, empty profile counts nothing; back to everything restores the counts.
    root:Find('New profile...').click()
    asked.OnAccept('Empty')
    local empty = Profiles.List()[2]
    assert(view.profile == empty.id and Tile('requests') ~= requestsBefore, 'an empty profile still counted requests')
    root = Menu()
    root:Find('All characters').click()
    assert(view.profile == nil and Tile('requests') == requestsBefore, 'all characters did not restore the counts')

    -- Ticking keeps the menu open and changes the profile.
    edit = root:Find('Profile characters: Empty')
    assert(not edit:Find('Tailor').selected(), 'a later profile did not start empty')
    assert(edit:Find('Tailor').click() == 'refresh', 'ticking closed the menu')
    assert(Profiles.Has(empty, 'Tailor-Realm') and edit:Find('Tailor').selected(), 'ticking did not add the character')
    edit:Find('Tailor').click()
    assert(not Profiles.Has(empty, 'Tailor-Realm'), 'unticking did not remove the character')

    -- A typed character, with the realm completed.
    edit:Find('Add character...').click()
    assert(asked.key == 'analytics_profile_character', 'the character was not asked for')
    asked.OnAccept(' Scout ')
    assert(Profiles.Has(empty, 'Scout-Realm'), 'the typed character was not added')
    asked.OnAccept('')
    edit:Find('Rename profile...').click()
    asked.OnAccept('Side pool')
    assert(empty.name == 'Side pool' and Menu():Find('Side pool'), 'the profile was not renamed')

    -- Deleting the chosen profile goes back to everything.
    view.profile = empty.id
    W.Rebuild()
    Menu():Find('Profile characters: Side pool'):Find('Delete profile').click()
    assert(#Profiles.List() == 1 and view.profile == nil, 'the deleted profile stayed chosen')
    assert(Tile('requests') == requestsBefore, 'the counts did not come back after deleting')
    -- A profile that no longer exists counts everything.
    view.profile = 'gone:9'
    W.Rebuild()
    assert(Tile('requests') == requestsBefore and Menu():Find('All characters').selected(), 'an unknown profile hid the data')
    view.profile = nil
    Profiles.Delete(pool.id)
    Scan.GetPlayerName, Scan.Dialog, MenuResponse = nil, nil, nil
end
print('Analytics profiles in the window passed (list, first profile, empty profile, ticking, typed names, rename, delete).')

Scan.AnalyticsWindow.Toggle()
assert(not Scan.AnalyticsWindow.IsShown() and #frame.Items.rows == 0, 'closing kept the data')
print('Analytics window passed (open, tabs, filters, sorting, dates, CSV, close).')
