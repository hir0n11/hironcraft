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
    function methods:SetPoint(_, relative, _, x) self.anchor, self.x = relative, x end
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
C_Item = {
    GetItemNameByID = function(id) return 'Item ' .. id end,
    RequestLoadItemDataByID = function() end,
    GetItemIconByID = function() return 134400 end,
    GetItemQualityByID = function() return 4 end,
}
C_Spell = { GetSpellName = function(id) return 'Recipe ' .. id end }
C_TradeSkillUI = { GetProfessionInfoBySkillLineID = function(id) return { professionName = 'Prof ' .. id } end }
C_Timer = { After = function(_, fn) end }
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
Log.Mention('Chatty-Realm', 4004)
Scan.Generous.RecordTip('Buyer', 6000 * 10000, 1)
Log.Record({ k = 'c', o = 1, r = 1, p = 197, x = 'Tailor-Realm', t = now - 30,
    rs = { { i = 7001, n = 2, v = 30000, s = 'a', c = 1 } } })
Log.Record({ k = 'c', o = 2, r = 1, p = 197, x = 'Tailor-Realm', t = now - 20 })

-- Opening it loads, counts and fills every tab.
Scan.AnalyticsWindow.Toggle()
local frame = _G.HironCraftAnalyticsFrame
assert(frame and Scan.AnalyticsWindow.IsShown(), 'the window did not open')
local items = frame.Items.rows
assert(#items == 2, 'item rows (only those with data): ' .. #items)
for _, row in ipairs(items) do assert(row.kind ~= 'item' or row.itemID ~= 4004, 'a chat-only item was listed') end
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
        assert(not before or tile.x >= before.x + before.width + 4, 'tiles overlap')
    end
end
CheckTiles()
charWidth = 30
Scan.AnalyticsWindow.Rebuild()
assert(frame.Tiles.tips.width > 104, 'a long sum of tips did not widen its tile')
CheckTiles({ [frame.Tiles.tips] = true, [frame.Tiles.averageTip] = true, [frame.Tiles.conversion] = true })
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

-- Search by name: any item, chat-only ones included; customers on their tab.
local function Type(text)
    frame.Search:SetText(text)
    Soon(function() frame.Search.scripts.OnTextChanged(frame.Search) end)
end
Type('Item 1001')
assert(#frame.Items.rows == 1 and frame.Items.rows[1].itemID == 1001, 'the search did not find the item')
Type('4004')
assert(#frame.Items.rows == 1 and frame.Items.rows[1].itemID == 4004, 'the search did not find a chat-only item')
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
frame.Tabs[4].scripts.OnClick(frame.Tabs[4])
assert(#frame.Returns.rows == 1 and frame.Returns.rows[1].itemID == 7001, 'the returns table is off')
assert(frame.ReturnTiles.chance.value:GetText() == '50%' and frame.ReturnTiles.crafts.value:GetText() == '2',
    'the returns tiles are off')
assert(not frame.SideDropdown:IsShown() and not frame.TierDropdown:IsShown() and not frame.Tiers:IsShown()
    and frame.ReturnTiles.value:IsShown() and not frame.Tiles.requests:IsShown(), 'the returns tab shows the wrong controls')
dumped = nil
frame.ExportButton.scripts.OnClick(frame.ExportButton)
assert(dumped and dumped:find('^reagent,item_id') and dumped:find('7001', 1, true), 'the returns CSV is off')
frame.Tabs[1].scripts.OnClick(frame.Tabs[1])
assert(frame.SideDropdown:IsShown() and frame.Tiles.requests:IsShown(), 'leaving the returns tab left its controls')

-- Closing lets the data go.
Scan.AnalyticsWindow.Toggle()
assert(not Scan.AnalyticsWindow.IsShown() and #frame.Items.rows == 0, 'closing kept the data')
print('Analytics window passed (open, tabs, filters, sorting, dates, CSV, close).')
