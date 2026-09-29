local Scan = select(2, ...)

-- The analytics window. Nothing here runs until it is opened: the journal's
-- stores for the chosen dates are unpacked then, counted, and let go again
-- when the window closes.
local W = {}
Scan.AnalyticsWindow = W

local function L(key)
    return Scan.LOCAL:GetText(key)
end

local FRAME_NAME = 'HironCraftAnalyticsFrame'
local ROW_HEIGHT = 20
local GAP = 6
local GOLD = 10000

local frame = nil
local chunks, report = nil, nil
local calendarReport, loadedFrom, loadedTo = nil, nil, nil
local loading = false
local backgroundLoad, refreshAfterLoad = false, false
local cancelLoad = nil
-- Resourcefulness on crafting orders, for the fourth tab.
local returns = nil
local loadToken = 0
local rebuildPending = nil
local namesPending = false
-- Redraws for names still on their way; a few, in case a load goes unanswered.
local NAME_RETRIES, NAME_RETRY_SECONDS = 5, 2
local nameRedrawAt, nameRetries = nil, 0
-- What was typed in the search box, lower case; '' shows everything.
local searchText = ''

local TAB_ITEMS, TAB_CUSTOMERS, TAB_TIME, TAB_RETURNS = 1, 2, 3, 4

local PRESETS = {
    { value = '1h', label = 'Last hour' },
    { value = 'today', label = 'Today' },
    { value = 'yesterday', label = 'Yesterday' },
    { value = 'week', label = 'This week' },
    { value = '7d', label = 'Last 7 days' },
    { value = '30d', label = 'Last 30 days' },
    { value = 'month', label = 'This month' },
    { value = 'year', label = 'This year' },
    { value = 'all', label = 'All time' },
    { value = 'custom', label = 'Own dates' },
}

local CALENDAR_MODES = {
    { value = 'week', label = 'Week' },
    { value = 'month', label = 'Month' },
    { value = 'year', label = 'Year' },
}

local TIERS = {
    { value = nil, label = 'All customers' },
    { value = 'diamond', label = 'Diamond customers', coin = 'diamond' },
    { value = 'generous', label = 'Generous customers', coin = 'generous' },
    { value = 'regular', label = 'Regular customers', coin = 'regular' },
    { value = 'stingy', label = 'Stingy customers', coin = 'stingy' },
}

local SIDES = {
    { value = nil, label = 'Both sides' },
    { value = 'H', label = 'Horde' },
    { value = 'A', label = 'Alliance' },
}

local METRICS = {
    { value = 'requests', label = 'Requests' },
    { value = 'greetings', label = 'Greetings' },
    { value = 'crafted', label = 'Crafted' },
    { value = 'orders', label = 'Crafted orders' },
}

local function View()
    local settings = Scan.DB.settings
    if type(settings.analytics_view) ~= 'table' then
        settings.analytics_view = { preset = '30d', tab = TAB_ITEMS, metric = 'orders', sort = {} }
    end
    local view = settings.analytics_view
    view.sort = type(view.sort) == 'table' and view.sort or {}
    -- Most ordered first, until a header is clicked.
    view.sort[TAB_ITEMS] = view.sort[TAB_ITEMS] or { key = 'orders', desc = true }
    -- The "without a mark" filter is gone: such customers count as silver.
    if view.tier == 'none' then view.tier = nil end
    view.sort[TAB_CUSTOMERS] = view.sort[TAB_CUSTOMERS] or { key = 'orders', desc = true }
    view.sort[TAB_RETURNS] = view.sort[TAB_RETURNS] or { key = 'value', desc = true }
    return view
end

local function CurrentRange()
    local view = View()
    if view.preset == 'custom' and view.from then
        return view.from, view.to or time()
    end
    return Scan.AnalyticsReport.Range(view.preset)
end

local function CalendarState()
    local view = View()
    local mode = view.calendarMode
    if mode ~= 'week' and mode ~= 'month' and mode ~= 'year' then
        mode = (view.preset == 'month' or view.preset == 'year') and view.preset or 'week'
    end
    local anchor = view.calendarAnchor
    if not anchor then
        local from = CurrentRange()
        anchor = (view.preset == 'custom' or view.preset == 'yesterday') and from > 0 and from or time()
    end
    return mode, anchor
end

local function RequiredRange()
    local from, to = CurrentRange()
    local mode, anchor = CalendarState()
    local calendarFrom, calendarTo = Scan.AnalyticsReport.CalendarRange(mode, anchor)
    return math.min(from, calendarFrom), math.max(to, math.min(calendarTo, time()))
end

local function RangeLabel(from, to)
    if not from or from == 0 then return L('All time') end
    local first, last = date('%d.%m.%Y', from), date('%d.%m.%Y', to)
    return first == last and first or (first .. ' – ' .. last)
end

-- Formatting -----------------------------------------------------------------

local function Number(value)
    if not value or value == 0 then return '|cff808080-|r' end
    return BreakUpLargeNumbers and BreakUpLargeNumbers(value) or tostring(value)
end

local function Percent(value)
    if not value then return '|cff808080-|r' end
    return string.format('%d%%', math.floor(value * 100 + 0.5))
end

local function Gold(copper, showZero)
    if not copper or copper < 0 or (copper == 0 and not showZero) then return '|cff808080-|r' end
    local gold = math.floor(copper / GOLD + 0.5)
    return (BreakUpLargeNumbers and BreakUpLargeNumbers(gold) or tostring(gold))
        .. '|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t'
end

local function PlainGold(copper)
    return tostring(math.floor((copper or 0) / GOLD + 0.5))
end

local function StripCodes(text)
    return (tostring(text or ''):gsub('|T.-|t', ''):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''))
end

local function ProfessionName(ppID)
    if not ppID then return nil end
    local info = C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID
        and C_TradeSkillUI.GetProfessionInfoBySkillLineID(ppID)
    return info and info.professionName ~= '' and info.professionName or nil
end

local function ColoredProfession(ppID)
    local name = ProfessionName(ppID)
    if not name then return '|cff808080-|r' end
    local ok, colored = pcall(Scan.Utils.ColorizeProfessionName, ppID, name)
    return ok and colored or name
end

local function Coin(mark)
    return Scan.Generous and mark and mark ~= 'none' and Scan.Generous.Icon(mark) or ''
end

-- A reagent's rank as the game draws it: two ranks from Midnight on, three
-- before. Tells apart rows of one name.
local function RankMark(itemID)
    local get = C_TradeSkillUI and C_TradeSkillUI.GetItemReagentQualityByItemInfo
    if not get then return '' end
    local ok, tier = pcall(get, itemID)
    tier = ok and tonumber(tier)
    if not tier or tier < 1 then return '' end
    local expansion = C_Item.GetItemInfo and tonumber((select(15, C_Item.GetItemInfo(itemID))))
    local atlas
    if (expansion and expansion >= 11) or (not expansion and tier <= 2) then
        atlas = 'Professions-Icon-Quality-12-Tier' .. math.min(tier, 2)
    else
        atlas = 'Professions-Icon-Quality-Tier' .. math.min(tier, 3)
    end
    return ' |A:' .. atlas .. ':16:16|a'
end

-- What a row of the item table is: a name with its icon, quality colour and
-- rank.
local function Subject(row)
    if row.kind == 'item' and row.itemID then
        local name = C_Item.GetItemNameByID(row.itemID)
        if not name then
            namesPending = true
            C_Item.RequestLoadItemDataByID(row.itemID)
            name = '#' .. row.itemID
        end
        local icon = C_Item.GetItemIconByID(row.itemID)
        local quality = C_Item.GetItemQualityByID(row.itemID)
        local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        local text = color and color.hex and (color.hex .. name .. '|r') or name
        return (icon and ('|T' .. icon .. ':16:16:0:0|t ') or '') .. text .. RankMark(row.itemID), name
    end
    if row.kind == 'recipe' and row.recipeID then
        local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(row.recipeID)
            or (L('Recipe') .. ' ' .. row.recipeID)
        return name, name
    end
    if row.kind == 'slot' then
        local text = string.format(L('Slot: %s'), row.label or row.slot or '?')
        return '|cffc0c0c0' .. text .. '|r', text
    end
    if row.kind == 'profession' then
        local text = string.format(L('Profession: %s'), ProfessionName(row.ppID) or '?')
        return '|cffc0c0c0' .. text .. '|r', text
    end
    if row.kind == 'generic' then
        local text = L('General crafting request')
        return '|cffc0c0c0' .. text .. '|r', text
    end
    return '?', '?'
end

-- Tables -----------------------------------------------------------------------

local ITEM_COLUMNS = {
    { key = 'name', label = 'Item', fill = true, align = 'LEFT',
        text = function(row) return (Subject(row)) end,
        value = function(row) return select(2, Subject(row)):lower() end },
    { key = 'profession', label = 'Profession', width = 110, align = 'LEFT',
        text = function(row) return ColoredProfession(row.ppID) end,
        value = function(row) return (ProfessionName(row.ppID) or ''):lower() end },
    { key = 'requests', label = 'Requests', width = 68, tip = 'Requests tooltip' },
    { key = 'greetings', label = 'Greetings', width = 72, tip = 'Greetings tooltip' },
    { key = 'crafted', label = 'Crafted', width = 72, tip = 'Crafted tooltip' },
    { key = 'conversion', label = 'Conversion', width = 76, tip = 'Conversion tooltip',
        text = function(row) return Percent(row.conversion) end },
    { key = 'orders', label = 'All orders', width = 76, tip = 'All orders tooltip' },
    { key = 'declined', label = 'Declined', width = 64, tip = 'Declined tooltip' },
    { key = 'averageTip', label = 'Average tip', width = 92,
        text = function(row) return Gold(row.averageTip) end },
}

local CUSTOMER_COLUMNS = {
    { key = 'name', label = 'Customer', fill = true, align = 'LEFT',
        text = function(row)
            local coin = Coin(row.mark)
            return (coin ~= '' and (coin .. ' ') or '') .. (Scan.NameAndRealmToName and Scan.NameAndRealmToName(row.name) or row.name)
        end,
        value = function(row) return row.key end },
    { key = 'orders', label = 'Orders', width = 70 },
    { key = 'tips', label = 'Tips total', width = 100, text = function(row) return Gold(row.tips) end },
    { key = 'averageTip', label = 'Average tip', width = 92, text = function(row) return Gold(row.averageTip) end },
    { key = 'maxTip', label = 'Largest tip', width = 92, text = function(row) return Gold(row.maxTip) end },
    { key = 'declined', label = 'Declined', width = 64 },
    { key = 'greetings', label = 'Greetings', width = 72 },
    { key = 'conversion', label = 'Conversion', width = 76, text = function(row) return Percent(row.conversion) end },
    { key = 'lastOrder', label = 'Last order', width = 110,
        text = function(row) return row.lastOrder and date('%d.%m.%Y %H:%M', row.lastOrder) or '|cff808080-|r' end },
}

local RETURN_COLUMNS = {
    { key = 'name', label = 'Reagent', fill = true, align = 'LEFT',
        text = function(row) return (Subject(row)) end,
        value = function(row) return select(2, Subject(row)):lower() end },
    { key = 'profession', label = 'Profession', width = 110, align = 'LEFT',
        text = function(row) return ColoredProfession(row.ppID) end,
        value = function(row) return (ProfessionName(row.ppID) or ''):lower() end },
    { key = 'procs', label = 'Returns', width = 70, tip = 'Returns tooltip' },
    { key = 'quantity', label = 'Quantity', width = 70 },
    { key = 'unitPrice', label = 'Price each', width = 92, text = function(row) return Gold(row.unitPrice) end },
    { key = 'value', label = 'Worth', width = 104, text = function(row) return Gold(row.value) end },
    { key = 'lastAt', label = 'Last', width = 96,
        text = function(row) return row.lastAt and date('%d.%m %H:%M', row.lastAt) or '|cff808080-|r' end },
}

local function CellText(column, row)
    if column.text then return column.text(row) end
    return Number(row[column.key])
end

local function SortValue(column, row)
    if column.value then return column.value(row) end
    return row[column.key] or -1
end

local function CreateTable(parent, columns, tabIndex, onEnter)
    local tbl = { columns = columns, tabIndex = tabIndex }
    tbl.frame = CreateFrame('Frame', nil, parent)
    tbl.frame:SetAllPoints(parent)

    local fixed = 0
    for _, column in ipairs(columns) do fixed = fixed + (column.width or 0) + GAP end
    local function Layout()
        local width = math.max(200, tbl.frame:GetWidth() - 34)
        local x = 8
        for _, column in ipairs(columns) do
            column.x = x
            column.w = column.fill and math.max(120, width - fixed) or column.width
            x = x + column.w + GAP
        end
    end
    Layout()

    tbl.headers = {}
    for index, column in ipairs(columns) do
        local header = CreateFrame('Button', nil, tbl.frame)
        header:SetHeight(20)
        header.text = header:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
        header.text:SetAllPoints()
        header.text:SetJustifyH(column.align or 'RIGHT')
        header:SetHighlightTexture('Interface\\Buttons\\UI-Listbox-Highlight2', 'ADD')
        header:GetHighlightTexture():SetAlpha(0.3)
        -- First click sorts, the second turns the order round, the third
        -- goes back to the usual order (most orders first).
        header:SetScript('OnClick', function()
            local sort = View().sort[tabIndex]
            if sort and sort.key == column.key and (sort.step or 1) >= 2 then
                View().sort[tabIndex] = nil
            elseif sort and sort.key == column.key then
                sort.desc = not sort.desc
                sort.step = 2
            else
                View().sort[tabIndex] = { key = column.key, desc = column.align ~= 'LEFT', step = 1 }
            end
            tbl:Refresh()
        end)
        header:SetScript('OnEnter', function(self)
            if not column.tip then return end
            GameTooltip:SetOwner(self, 'ANCHOR_TOP')
            GameTooltip_SetTitle(GameTooltip, L(column.label))
            GameTooltip_AddNormalLine(GameTooltip, L(column.tip))
            GameTooltip:Show()
        end)
        header:SetScript('OnLeave', function() GameTooltip:Hide() end)
        tbl.headers[index] = header
    end

    tbl.scrollBox = CreateFrame('Frame', nil, tbl.frame, 'WowScrollBoxList')
    tbl.scrollBox:SetPoint('TOPLEFT', tbl.frame, 'TOPLEFT', 4, -26)
    tbl.scrollBox:SetPoint('BOTTOMRIGHT', tbl.frame, 'BOTTOMRIGHT', -24, 4)
    tbl.scrollBar = CreateFrame('EventFrame', nil, tbl.frame, 'MinimalScrollBar')
    tbl.scrollBar:SetPoint('TOPLEFT', tbl.scrollBox, 'TOPRIGHT', 6, 0)
    tbl.scrollBar:SetPoint('BOTTOMLEFT', tbl.scrollBox, 'BOTTOMRIGHT', 6, 0)

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(ROW_HEIGHT)
    local function Populate(row, data)
        -- First: a hover must never show the item this frame showed before.
        row.data = data.row
        row.analyticsElement = data
        row:SetScript('OnEnter', function(self) if onEnter then onEnter(self, self.data) end end)
        row:SetScript('OnLeave', function() GameTooltip:Hide() end)
        row.Stripe:SetShown(data.index % 2 == 0)
        row.cells = row.cells or {}
        for index, column in ipairs(columns) do
            local cell = row.cells[index]
            if not cell then
                cell = row:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
                cell:SetWordWrap(false)
                row.cells[index] = cell
            end
            cell:ClearAllPoints()
            cell:SetPoint('LEFT', row, 'LEFT', column.x - 4, 0)
            cell:SetWidth(column.w)
            cell:SetJustifyH(column.align or 'RIGHT')
            local ok, text = pcall(CellText, column, data.row)
            text = ok and text or '?'
            if cell:GetText() ~= text then cell:SetText(text) end
        end
    end
    view:SetElementInitializer('HironCraftAnalyticsRowTemplate', Populate)
    ScrollUtil.InitScrollBoxListWithScrollBar(tbl.scrollBox, tbl.scrollBar, view)

    function tbl:Refresh()
        Layout()
        local sort = View().sort[tabIndex]
        for index, column in ipairs(columns) do
            local header = self.headers[index]
            header:ClearAllPoints()
            header:SetPoint('TOPLEFT', self.frame, 'TOPLEFT', column.x, -4)
            header:SetWidth(column.w)
            local arrow = ''
            if sort and sort.key == column.key then arrow = sort.desc and ' v' or ' ^' end
            header.text:SetText(L(column.label) .. arrow)
        end
        local rows = self.rows or {}
        local column = nil
        for _, candidate in ipairs(columns) do
            if sort and candidate.key == sort.key then column = candidate end
        end
        if column then
            table.sort(rows, function(lhs, rhs)
                local a, b = SortValue(column, lhs), SortValue(column, rhs)
                if type(a) ~= type(b) then a, b = tostring(a), tostring(b) end
                if a == b then return tostring(lhs.key) < tostring(rhs.key) end
                if sort.desc then return a > b end
                return a < b
            end)
        end
        -- Keep the provider/visible row frames when the ordered identities
        -- are unchanged. Online checkpoints and item-name loads must not
        -- recycle the entire table (or disturb scrolling/hover).
        local list = self.elements
        local sameOrder = list and #list == #rows
        if sameOrder then
            for index, row in ipairs(rows) do
                if list[index].row.key ~= row.key then sameOrder = false; break end
            end
        end
        if sameOrder then
            for index, row in ipairs(rows) do list[index].row = row end
            for _, row in pairs(self.scrollBox:GetFrames()) do
                if row.analyticsElement then Populate(row, row.analyticsElement) end
            end
        else
            list = {}
            for index, row in ipairs(rows) do list[index] = { row = row, index = index } end
            self.elements = list
            self.scrollBox:SetDataProvider(CreateDataProvider(list), ScrollBoxConstants.RetainScrollPosition)
        end
    end

    function tbl:SetRows(rows)
        self.rows = rows
        self:Refresh()
    end

    return tbl
end

-- Charts --------------------------------------------------------------------------

local function CreateChart(parent, count, labelOf)
    local chart = CreateFrame('Frame', nil, parent)
    chart.bars = {}
    for index = 1, count do
        local bar = CreateFrame('Button', nil, chart)
        bar:RegisterForClicks('LeftButtonUp')
        bar:SetHighlightTexture('Interface\\Buttons\\UI-Listbox-Highlight2', 'ADD')
        bar:GetHighlightTexture():SetAlpha(0.15)
        bar.selection = bar:CreateTexture(nil, 'BACKGROUND')
        bar.selection:SetAllPoints()
        bar.selection:SetColorTexture(1, 0.82, 0.25, 0.12)
        bar.selection:Hide()
        bar:SetScript('OnClick', function(self)
            if (not loading or backgroundLoad) and self.info and self.info.bucket then W.SelectCalendarBucket(self.info.bucket) end
        end)
        -- Under it, a thin gauge: how much of that time someone was online.
        bar.onlineTrack = bar:CreateTexture(nil, 'BACKGROUND')
        bar.onlineTrack:SetColorTexture(1, 1, 1, 0.08)
        bar.onlineTrack:SetPoint('TOPLEFT', bar, 'BOTTOMLEFT', 0, -3)
        bar.onlineTrack:SetPoint('TOPRIGHT', bar, 'BOTTOMRIGHT', 0, -3)
        bar.onlineTrack:SetHeight(3)
        bar.onlineFill = bar:CreateTexture(nil, 'ARTWORK')
        bar.onlineFill:SetColorTexture(0.35, 0.85, 0.45, 0.9)
        bar.onlineFill:SetPoint('TOPLEFT', bar.onlineTrack, 'TOPLEFT')
        bar.onlineFill:SetHeight(3)
        bar.fill = bar:CreateTexture(nil, 'ARTWORK')
        bar.fill:SetColorTexture(1, 0.78, 0.25, 0.85)
        bar.fill:SetPoint('BOTTOMLEFT')
        bar.fill:SetPoint('BOTTOMRIGHT')
        bar.value = bar:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        bar.value:SetPoint('BOTTOM', bar.fill, 'TOP', 0, 2)
        bar.label = chart:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
        bar.label:SetPoint('TOP', bar, 'BOTTOM', 0, -9)
        bar.label:SetText(labelOf(index))
        bar:EnableMouse(true)
        bar:SetScript('OnEnter', function(self)
            if not self.info then return end
            GameTooltip:SetOwner(self, 'ANCHOR_TOP')
            GameTooltip_SetTitle(GameTooltip, self.info.title)
            for _, line in ipairs(self.info.lines) do GameTooltip_AddNormalLine(GameTooltip, line) end
            GameTooltip:Show()
        end)
        bar:SetScript('OnLeave', function() GameTooltip:Hide() end)
        chart.bars[index] = bar
    end

    function chart:SetValues(values, infos, shares, labels, selected)
        self.infos = infos or {}
        local width, height = self:GetWidth(), self:GetHeight() - 40
        local visible = #values
        local slot = width / math.max(1, visible)
        local max = 0
        for index = 1, count do max = math.max(max, values[index] or 0) end
        for index, bar in ipairs(self.bars) do
            bar:SetShown(index <= visible)
            bar.label:SetShown(index <= visible)
            bar.selection:SetShown(selected and selected[index] == true or false)
            if labels then bar.label:SetText(labels[index] or '') end
            local value = values[index] or 0
            bar:ClearAllPoints()
            bar:SetPoint('BOTTOMLEFT', self, 'BOTTOMLEFT', (index - 1) * slot + slot * 0.15, 24)
            bar:SetSize(slot * 0.7, math.max(1, height))
            bar.fill:SetHeight(math.max(1, max > 0 and height * value / max or 1))
            bar.fill:SetAlpha(value > 0 and 1 or 0.25)
            bar.value:SetText(value > 0 and value or '')
            local share = shares and shares[index]
            bar.onlineTrack:SetShown(share ~= nil)
            bar.onlineFill:SetWidth(math.max(0.01, slot * 0.7 * math.min(1, share or 0)))
            bar.onlineFill:SetShown(share ~= nil and share > 0)
            bar.info = infos and infos[index]
            bar:SetEnabled(not bar.info or not bar.info.bucket or bar.info.bucket.from <= time())
        end
    end
    return chart
end

-- Filters and summary ----------------------------------------------------------

local function Filters()
    local view = View()
    local from, to = CurrentRange()
    return { from = from, to = to, ppID = view.ppID, crafter = view.crafter, side = view.side, tier = view.tier }
end

local function Context()
    local marks = {}
    return {
        markOf = function(name)
            if type(name) ~= 'string' then return nil end
            local key = Scan.AnalyticsReport.BaseKey(name)
            if marks[key] == nil then
                marks[key] = Scan.Generous and Scan.Generous.MarkOf(name) or false
            end
            return marks[key] or nil
        end,
        itemProf = function(itemID) return Scan.AnalyticsLog.ProfessionOfItem(itemID) end,
    }
end

-- Customers with each coin, however long ago they got it.
local function AllTimeTiers()
    local counts = { diamond = 0, generous = 0, regular = 0, stingy = 0 }
    local store = Scan.DB.settings.generous_customers
    if type(store) == 'table' and Scan.Generous then
        for key in pairs(store) do
            local mark = Scan.Generous.MarkOf(key)
            if mark and counts[mark] then counts[mark] = counts[mark] + 1 end
        end
    end
    return counts
end

-- One full-width strip: request funnel, order results, returns/online.
local TILE_GROUPS = {
    { color = { 0.35, 0.65, 1.00 }, tiles = {
        { key = 'requests', label = 'Requests', tip = 'Requests tooltip' },
        { key = 'greetings', label = 'Greetings', tip = 'Greetings tooltip' },
        { key = 'crafted', label = 'Crafted', tip = 'Crafted tooltip' },
        { key = 'conversion', label = 'Conversion', tip = 'Conversion tooltip' },
    } },
    { color = { 1.00, 0.78, 0.25 }, tiles = {
        { key = 'orders', label = 'Orders delivered', tip = 'All orders tooltip' },
        { key = 'declined', label = 'Declined', tip = 'Declined tooltip' },
        { key = 'tips', label = 'Tips total', tip = 'Tips tooltip', width = 104 },
        { key = 'averageTip', label = 'Average tip', tip = 'Average tip tooltip', width = 86 },
    } },
    { color = { 0.45, 0.85, 0.55 }, tiles = {
        { key = 'returnedValue', label = 'Reagent returns value', tip = 'Returned worth tooltip', width = 104 },
        { key = 'online', label = 'Online time', tip = 'Online time tooltip', width = 86 },
    } },
}
local TILE_WIDTH, TILE_HEIGHT, TILE_GAP, GROUP_GAP = 74, 40, 4, 12
local TILE_FONT, TILE_FONT_SMALL = 'GameFontHighlightLarge', 'GameFontHighlight'

local function TileNumber(value)
    return BreakUpLargeNumbers and BreakUpLargeNumbers(value or 0) or tostring(value or 0)
end

-- A line's whole width, however narrow its frame.
local function TextWidth(fontString)
    local measure = fontString.GetUnboundedStringWidth or fontString.GetStringWidth
    return measure(fontString) or 0
end

-- Returns the tiles by key and in their order along the row.
local function CreateTiles(parent, x, y, groups)
    local strip = CreateFrame('Frame', nil, parent)
    strip:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, y)
    strip:SetSize(parent:GetWidth() - 2 * x, TILE_HEIGHT)
    local tiles, order = {}, { x = x, y = y, frame = strip, parent = parent }
    parent, x, y = strip, 0, 0
    for groupIndex, group in ipairs(groups or TILE_GROUPS) do
        for index, info in ipairs(group.tiles) do
            local tile = CreateFrame('Frame', nil, parent)
            tile.gap = (groupIndex > 1 and index == 1) and GROUP_GAP or TILE_GAP
            tile:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, y)
            tile.background = tile:CreateTexture(nil, 'BACKGROUND')
            tile.background:SetAllPoints()
            tile.background:SetColorTexture(1, 1, 1, 0.05)
            tile.accent = tile:CreateTexture(nil, 'BORDER')
            tile.accent:SetPoint('TOPLEFT')
            tile.accent:SetPoint('BOTTOMLEFT')
            tile.accent:SetWidth(2)
            tile.accent:SetColorTexture(group.color[1], group.color[2], group.color[3], 0.9)
            tile.label = tile:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
            tile.label:SetPoint('TOPLEFT', 8, -5)
            tile.label:SetPoint('RIGHT', -4, 0)
            tile.label:SetJustifyH('LEFT')
            tile.label:SetTextColor(0.75, 0.75, 0.75)
            tile.label:SetWordWrap(false)
            tile.label:SetText(L(info.label))
            -- At least as wide as its name needs, one line.
            tile.minWidth = math.max(info.width or TILE_WIDTH, math.ceil(TextWidth(tile.label) + 16))
            local width = tile.minWidth
            tile:SetSize(width, TILE_HEIGHT)
            tile.value = tile:CreateFontString(nil, 'OVERLAY', TILE_FONT)
            tile.value:SetPoint('BOTTOMLEFT', 8, 5)
            tile.value:SetPoint('RIGHT', -4, 0)
            tile.value:SetJustifyH('LEFT')
            -- A figure too long for the tile would wrap and climb over the name.
            tile.value:SetWordWrap(false)
            tile:EnableMouse(true)
            tile:SetScript('OnEnter', function(self)
                GameTooltip:SetOwner(self, 'ANCHOR_BOTTOM')
                GameTooltip_SetTitle(GameTooltip, L(info.label))
                GameTooltip_AddNormalLine(GameTooltip, L(info.tip))
                GameTooltip:Show()
            end)
            tile:SetScript('OnLeave', function() GameTooltip:Hide() end)
            tiles[info.key] = tile
            order[#order + 1] = tile
            x = x + width + TILE_GAP
        end
        x = x + GROUP_GAP - TILE_GAP
    end
    return tiles, order
end

-- The toolbar has its own row, leaving all the horizontal space for metrics.
-- Distribute spare space evenly; for unusually long totals/localized labels,
-- try the smaller value font, then fit the entire strip without clipping,
-- abbreviating amounts, wrapping, or changing the window's size.
local function LayoutTiles(order)
    local available = order.parent:GetWidth() - 2 * order.x
    local function Measure(shrink)
        local width = 0
        for index, tile in ipairs(order) do
            tile.value:SetFontObject(TILE_FONT)
            local need = math.ceil(TextWidth(tile.value) + 14)
            if shrink and need > tile.minWidth then
                tile.value:SetFontObject(TILE_FONT_SMALL)
                need = math.ceil(TextWidth(tile.value) + 14)
            end
            if index > 1 then width = width + tile.gap end
            tile:SetWidth(math.max(tile.minWidth, need))
            width = width + tile:GetWidth()
        end
        return width
    end
    local width = Measure(false)
    if width > available then width = Measure(true) end
    local extra = math.max(0, available - width) / #order
    local scale = math.min(1, available / width)
    order.frame:SetSize(math.max(available, width), TILE_HEIGHT)
    order.frame:SetScale(scale)
    order.frame:ClearAllPoints()
    -- Point offsets are in the scaled strip's units; keep its outer margin.
    order.frame:SetPoint('TOPLEFT', order.parent, 'TOPLEFT', order.x / scale, order.y / scale)
    local x = 0
    for index, tile in ipairs(order) do
        if index > 1 then x = x + tile.gap end
        tile:SetWidth(tile:GetWidth() + extra)
        tile:SetPoint('TOPLEFT', order.frame, 'TOPLEFT', x, 0)
        x = x + tile:GetWidth()
    end
end

-- The resourcefulness tab: how often it comes, and what it brought.
local RETURN_TILE_GROUPS = {
    { color = { 0.45, 0.85, 0.55 }, tiles = {
        { key = 'crafts', label = 'Order crafts', tip = 'Order crafts tooltip' },
        { key = 'procs', label = 'With returns', tip = 'With returns tooltip' },
        { key = 'chance', label = 'Chance', tip = 'Return chance tooltip' },
    } },
    { color = { 1.00, 0.78, 0.25 }, tiles = {
        { key = 'quantity', label = 'Reagents returned', tip = 'Reagents returned tooltip' },
        { key = 'value', label = 'Returned worth', tip = 'Returned worth tooltip', width = 110 },
    } },
}

-- Green from half the greetings crafted, yellow from a quarter, else red.
local function ConversionColor(value)
    if not value then return 0.5, 0.5, 0.5 end
    if value >= 0.5 then return 0.35, 1, 0.35 end
    if value >= 0.25 then return 1, 0.82, 0 end
    return 1, 0.45, 0.35
end

local function UpdateSummary()
    local totals = report and report.totals or {}
    local tiles = frame.Tiles
    for _, key in ipairs({ 'requests', 'greetings', 'crafted', 'orders', 'declined' }) do
        tiles[key].value:SetText(report and TileNumber(totals[key]) or '')
    end
    tiles.conversion.value:SetText(report and Percent(totals.conversion) or '')
    tiles.conversion.value:SetTextColor(ConversionColor(totals.conversion))
    tiles.tips.value:SetText(report and Gold(totals.tips) or '')
    tiles.averageTip.value:SetText(report and Gold(totals.averageTip) or '')
    local returned = returns and returns.totals
    tiles.returnedValue.value:SetText(returned and (Gold(returned.value, true)
        .. (returned.unpriced > 0 and ' |cffffb347*|r' or '')) or '')
    local minutes = math.floor(totals.online or 0)
    tiles.online.value:SetText(report and string.format('%d:%02d', math.floor(minutes / 60), minutes % 60) or '')
    LayoutTiles(frame.TileOrder)
    if not report then
        frame.Tiers:SetText('')
        return
    end
    local all = AllTimeTiers()
    local tiers = report.tiers
    local function Count(mark, count)
        return Coin(mark) .. ' |cffffffff' .. TileNumber(count) .. '|r'
    end
    local function Counts(counts)
        local parts = {}
        for _, mark in ipairs({ 'diamond', 'generous', 'regular', 'stingy' }) do
            parts[#parts + 1] = Count(mark, counts[mark])
        end
        return table.concat(parts, '     ')
    end
    frame.Tiers:SetText(string.format('|cffffd100%s|r   %s          |cff9d9d9d%s|r   %s',
        L('Customers in the period:'), Counts(tiers), L('Marked overall:'), Counts(all)))
end

local function UpdateReturnTiles()
    local totals = returns and returns.totals or {}
    local tiles = frame.ReturnTiles
    tiles.crafts.value:SetText(returns and TileNumber(totals.crafts) or '')
    tiles.procs.value:SetText(returns and TileNumber(totals.procs) or '')
    tiles.chance.value:SetText(returns and Percent(totals.chance) or '')
    tiles.quantity.value:SetText(returns and TileNumber(totals.quantity) or '')
    tiles.value.value:SetText(returns and Gold(totals.value) or '')
    LayoutTiles(frame.ReturnTileOrder)
end

local WEEKDAYS = { 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun' }

-- Minutes as "3 h 05 min" or "40 min".
local function Duration(minutes)
    local seconds = math.floor((minutes or 0) * 60 + 0.5)
    minutes = math.floor(seconds / 60)
    if seconds % 60 > 0 then
        if minutes >= 60 then
            return string.format(L('%d h %02d min %02d s'), math.floor(minutes / 60), minutes % 60, seconds % 60)
        end
        if minutes > 0 then return string.format(L('%d min %02d s'), minutes, seconds % 60) end
        return string.format(L('%d s'), seconds)
    end
    if minutes >= 60 then
        return string.format(L('%d h %02d min'), math.floor(minutes / 60), minutes % 60)
    end
    return string.format(L('%d min'), minutes)
end

-- The year stays visible below its detail. With no explicit selection, show
-- this month for the current year, otherwise the latest active month (January
-- for an empty year). Presence capacity alone is not activity.
local function YearDetail()
    local mode, anchor = CalendarState()
    if mode ~= 'year' then return nil end
    local model, view = Scan.AnalyticsReport, View()
    local first, last = model.CalendarRange('year', anchor)
    local month = tonumber(view.yearDetailMonth)
    if not month or month < first or month > last or month > time() then
        month = nil
        if first == model.CalendarRange('year') then
            month = model.CalendarRange('month')
        else
            for _, bucket in ipairs(model.CalendarBuckets('year', first)) do
                local stats = calendarReport.calendar.months[bucket.key] or {}
                if bucket.from <= time() and ((stats.requests or 0) > 0 or (stats.greetings or 0) > 0
                    or (stats.orders or 0) > 0 or (stats.online or 0) > 0) then month = bucket.from end
            end
        end
    end
    month = model.CalendarRange('month', month or first)
    local from, to = CurrentRange()
    local day = tonumber(view.yearDetailDay)
    if not day or day ~= from or day > time() or day < month
        or day > select(2, model.CalendarRange('month', month))
        or to > select(2, model.CalendarRange('day', day)) then day = nil end
    return month, day
end

local function UpdateCharts()
    if not report or not calendarReport or (loading and not backgroundLoad) then return end
    local metric = View().metric or 'orders'
    local function Infos(count, statsOf, titleOf)
        local values, infos, shares = {}, {}, {}
        for index = 1, count do
            local stats = statsOf(index)
            values[index] = stats[metric] or 0
            local greetings, crafted = stats.greetings or 0, stats.crafted or 0
            local online, possible = stats.online or 0, stats.possible or 0
            shares[index] = possible > 0 and online / possible or nil
            local estimated, missing = (stats.tipsEstimated or 0) > 0, (stats.tipsMissing or 0) > 0
            infos[index] = { title = titleOf(index), stats = stats, lines = {
                string.format('%s: %d', L('Requests'), stats.requests or 0),
                string.format('%s: %d', L('Greetings'), greetings),
                string.format('%s: %d', L('Crafted'), crafted),
                string.format('%s: %d', L('Crafted orders'), stats.orders or 0),
                -- Of the greetings sent in this hour, how many were ordered.
                string.format('%s: %s', L('Conversion'), greetings > 0
                    and string.format('%s (%d / %d)', Percent(crafted / greetings), crafted, greetings)
                    or Percent(nil)),
                L('Gold from orders') .. ': ' .. Gold(stats.tips or 0, true)
                    .. ((estimated or missing) and ' |cffffb347*|r' or ''),
                possible > 0 and string.format(L('Online: %s of %s (%s)'), Duration(online), Duration(possible),
                    Percent(online / possible)) or L('Online: not recorded yet'),
            } }
            if estimated then infos[index].lines[#infos[index].lines + 1] = L('Order gold estimated') end
            if missing then infos[index].lines[#infos[index].lines + 1] = L('Order gold incomplete') end
        end
        return values, infos, shares
    end
    local from, to = CurrentRange()
    local range = RangeLabel(from, to)
    local detailMonth, detailDay = YearDetail()
    frame.HourChart.detailMonth = detailMonth
    frame.DetailBack:SetShown(detailMonth ~= nil and detailDay ~= nil)
    if detailMonth and not detailDay then
        local buckets = Scan.AnalyticsReport.CalendarBuckets('month', detailMonth)
        local values, infos, shares = Infos(#buckets, function(index)
            return calendarReport.calendar.days[buckets[index].key] or {}
        end, function(index) return RangeLabel(buckets[index].from, buckets[index].to) end)
        local labels = {}
        for index, bucket in ipairs(buckets) do
            labels[index] = date('%d', bucket.from)
            infos[index].bucket, infos[index].period = bucket, bucket.key
            infos[index].lines[#infos[index].lines + 1] = L('Click to view this day')
        end
        frame.HourChart.kind, frame.HourChart.buckets = 'days', buckets
        frame.HourTitle:SetText(L('By day of month') .. ' — '
            .. RangeLabel(detailMonth, select(2, Scan.AnalyticsReport.CalendarRange('month', detailMonth))))
        frame.HourChart:SetValues(values, infos, shares, labels)
    else
        local values, infos, shares = Infos(24, function(index)
            local stats = {}
            for key, slots in pairs(report.hours) do stats[key] = slots[index - 1] end
            return stats
        end, function(index) return range .. ' · ' .. string.format('%02d:00-%02d:59', index - 1, index - 1) end)
        local labels = {}
        for index = 1, 24 do
            labels[index] = tostring(index - 1)
            infos[index].period = range .. ' ' .. string.format('%02d:00', index - 1)
        end
        frame.HourChart.kind, frame.HourChart.buckets = 'hours', nil
        frame.HourTitle:SetText(L('By hour of day') .. ' — ' .. range)
        frame.HourChart:SetValues(values, infos, shares, labels)
    end

    local mode, anchor = CalendarState()
    local first, last = Scan.AnalyticsReport.CalendarRange(mode, anchor)
    local buckets = Scan.AnalyticsReport.CalendarBuckets(mode, anchor)
    local values, infos, shares = Infos(#buckets, function(index)
        local bucket = buckets[index]
        return calendarReport.calendar[bucket.unit == 'month' and 'months' or 'days'][bucket.key] or {}
    end, function(index) return RangeLabel(buckets[index].from, buckets[index].to) end)
    local labels, selected = {}, {}
    for index, bucket in ipairs(buckets) do
        labels[index] = mode == 'week' and (L(WEEKDAYS[index]) .. ' ' .. date('%d.%m', bucket.from))
            or date(mode == 'year' and '%m' or '%d', bucket.from)
        selected[index] = (mode == 'year' and detailMonth == bucket.from)
            or (mode ~= 'year' and from == bucket.from and to <= bucket.to)
        infos[index].bucket, infos[index].period = bucket, bucket.key
        infos[index].lines[#infos[index].lines + 1] = L(bucket.unit == 'month'
            and 'Click to view this month' or 'Click to view this day')
    end
    frame.DayChart.buckets = buckets
    frame.DayChart:SetValues(values, infos, shares, labels, selected)
    frame.CalendarTitle:SetText(RangeLabel(first, last))
    frame.CalendarNext:SetEnabled(last < time())
    frame.CalendarPrevious:SetEnabled(date('*t', first).year > 1970)
    if frame.CalendarMode.GenerateMenu then frame.CalendarMode:GenerateMenu() end
end

local function SetStatus(text)
    frame.Status:SetText(text or '')
    frame.Status:SetShown(text ~= nil and text ~= '')
end

local function Matches(text)
    return searchText == '' or (text and text:lower():find(searchText, 1, true) ~= nil)
end

-- A row appears once someone asked you for an item or ordered it, and fills
-- in as more comes. A search also finds rows that have nothing left in the
-- period.
local function ItemRows()
    local rows = {}
    for _, row in ipairs(report.rows) do
        local hasData = row.requests > 0 or row.greetings > 0 or row.orders > 0 or row.declined > 0
        if searchText == '' then
            if hasData then rows[#rows + 1] = row end
        elseif Matches(select(2, Subject(row))) or (row.itemID and tostring(row.itemID) == searchText) then
            rows[#rows + 1] = row
        end
    end
    return rows
end

local function CustomerRows()
    local rows = {}
    for _, row in ipairs(report.customers) do
        if Matches(row.name) then rows[#rows + 1] = row end
    end
    return rows
end

local function ReturnRows()
    local rows = {}
    for _, row in ipairs(returns and returns.rows or {}) do
        if Matches(select(2, Subject(row))) or tostring(row.itemID) == searchText then rows[#rows + 1] = row end
    end
    return rows
end

local ScheduleNameRedraw, ScheduleRebuild

local function Render()
    if not frame or not report or (loading and not backgroundLoad) then return end
    namesPending = false
    frame.Items:SetRows(ItemRows())
    frame.Customers:SetRows(CustomerRows())
    frame.Returns:SetRows(ReturnRows())
    UpdateSummary()
    UpdateReturnTiles()
    UpdateCharts()
    local tab = View().tab
    local empty = (tab == TAB_ITEMS and #frame.Items.rows == 0) or (tab == TAB_CUSTOMERS and #frame.Customers.rows == 0)
        or (tab == TAB_RETURNS and #frame.Returns.rows == 0)
    SetStatus(empty and L('No analytics data for the period') or nil)
    local last = Scan.AnalyticsSync and Scan.AnalyticsSync.LastSync()
    frame.SyncText:SetText(last and string.format(L('Last exchange: %s'), date('%d.%m %H:%M', last)) or '')
    -- Names still missing: look again shortly, even if no word comes.
    if namesPending and nameRetries < NAME_RETRIES then
        nameRetries = nameRetries + 1
        ScheduleNameRedraw(NAME_RETRY_SECONDS)
    end
end

-- Item names come from the server a moment after they are asked for: the
-- tables are drawn again once they are here. An earlier redraw takes the
-- place of a later one.
function ScheduleNameRedraw(delay)
    local at = GetTime() + delay
    if nameRedrawAt and nameRedrawAt <= at then return end
    nameRedrawAt = at
    C_Timer.After(delay, function()
        if nameRedrawAt ~= at then return end
        nameRedrawAt = nil
        if frame and frame:IsShown() and report and namesPending then Render() end
    end)
end

function W.Rebuild()
    if not frame or not chunks or (loading and not backgroundLoad) then return end
    nameRetries = 0
    local filters, context = Filters(), Context()
    report = Scan.AnalyticsReport.Build(chunks, filters, context)
    local mode, anchor = CalendarState()
    local from, to = Scan.AnalyticsReport.CalendarRange(mode, anchor)
    to = math.min(to, time())
    if filters.from == from and filters.to == to then
        calendarReport = report
    else
        local calendarFilters = { from = from, to = to, ppID = filters.ppID,
            crafter = filters.crafter, side = filters.side, tier = filters.tier }
        calendarReport = Scan.AnalyticsReport.Build(chunks, calendarFilters, context)
    end
    returns = Scan.AnalyticsReport.BuildReturns(chunks, Filters())
    Render()
end

function W.Reload(background)
    if not frame or not frame:IsShown() then return end
    if background and loading then
        -- Finish the current snapshot, then refresh once for the whole burst.
        refreshAfterLoad = true
        return
    end
    if cancelLoad then cancelLoad(); cancelLoad = nil end
    rebuildPending, refreshAfterLoad = nil, false
    loadToken = loadToken + 1
    local token = loadToken
    loading = true
    backgroundLoad = background == true and report ~= nil
    -- Keep the committed view intact until the new snapshot is ready. Only
    -- initial loading uses the central message; manual navigation uses the
    -- small toolbar status, while background updates stay visually silent.
    frame.ExportButton:SetEnabled(backgroundLoad)
    local function Progress(text)
        if backgroundLoad then return end
        if report then frame.SyncText:SetText(text) else SetStatus(text) end
    end
    Progress(L('Loading analytics...'))
    local from, to = RequiredRange()
    local completed = false
    local cancel = Scan.AnalyticsLog.LoadRange(from, to, function(done, total)
        if token == loadToken and frame:IsShown() then
            Progress(string.format(L('Loading analytics %d / %d'), done, total))
        end
    end, function(loaded)
        completed = true
        if token ~= loadToken or not frame:IsShown() then return end
        cancelLoad = nil
        chunks = loaded
        loading, backgroundLoad = false, false
        local again = refreshAfterLoad
        refreshAfterLoad = false
        loadedFrom, loadedTo = from, to
        W.Rebuild()
        frame.ExportButton:SetEnabled(true)
        if again then ScheduleRebuild(0.2) end
    end)
    -- LoadRange may finish synchronously; don't resurrect its cancellation
    -- handle after the completion callback has already committed the view.
    if not completed and token == loadToken then cancelLoad = cancel end
end

local function RefreshSelection()
    local from, to = RequiredRange()
    if not loading and chunks and loadedFrom <= from and loadedTo >= to then
        W.Rebuild()
    else
        W.Reload()
    end
end

-- New events while the window is open: counted again a little later.
function ScheduleRebuild(delay)
    if not frame or not frame:IsShown() then return end
    local pending = { at = GetTime() + delay }
    if rebuildPending and rebuildPending.at <= pending.at then return end
    rebuildPending = pending
    C_Timer.After(delay, function()
        if rebuildPending ~= pending then return end
        rebuildPending = nil
        if frame and frame:IsShown() then W.Reload(true) end
    end)
end

-- Merge local notifications and linked-account batches into one refresh.
function W.DataArrived()
    ScheduleRebuild(0.2)
end

function W.Release()
    if cancelLoad then cancelLoad(); cancelLoad = nil end
    loadToken = loadToken + 1
    rebuildPending, refreshAfterLoad, backgroundLoad, nameRedrawAt = nil, false, false, nil
    chunks, report, returns, calendarReport = nil, nil, nil, nil
    loadedFrom, loadedTo, loading = nil, nil, false
    if Scan.AnalyticsLog then Scan.AnalyticsLog.ReleaseCache() end
    if frame then
        frame.Items:SetRows({})
        frame.Customers:SetRows({})
        frame.Returns:SetRows({})
        frame.HourChart:SetValues({})
        frame.HourChart.buckets, frame.HourChart.detailMonth = nil, nil
        frame.DayChart:SetValues({})
        frame.DetailBack:Hide()
    end
end

local function UpdateDateBoxes()
    local from, to = CurrentRange()
    frame.FromBox:SetText(from and from > 0 and Scan.AnalyticsReport.FormatDate(from) or '')
    frame.ToBox:SetText(Scan.AnalyticsReport.FormatDate(to))
    local custom = View().preset == 'custom'
    for _, element in ipairs(frame.DateElements) do element:SetShown(custom) end
    -- Own dates sit right after the period; the other filters make room.
    frame.Profession:ClearAllPoints()
    if custom then
        frame.Profession:SetPoint('LEFT', frame.ToBox, 'RIGHT', 14, 0)
    else
        frame.Profession:SetPoint('LEFT', frame.Period, 'RIGHT', 8, 0)
    end
    -- A typed date switches the period to own dates; show that.
    if frame.Period and frame.Period.GenerateMenu then frame.Period:GenerateMenu() end
end

-- A day click changes only the detailed period, not the calendar below it.
function W.SelectCalendarBucket(bucket)
    if not bucket or bucket.from > time() then return end
    local view, model = View(), Scan.AnalyticsReport
    local mode = CalendarState()
    if bucket.unit == 'month' then
        if mode == 'year' then
            view.yearDetailMonth, view.yearDetailDay = bucket.from, nil
        else
            view.calendarMode, view.calendarAnchor = 'month', bucket.from
            view.yearDetailMonth, view.yearDetailDay = nil, nil
        end
        view.preset = bucket.from == model.CalendarRange('month') and 'month' or 'custom'
    else
        if mode == 'year' then
            view.yearDetailMonth, view.yearDetailDay = model.CalendarRange('month', bucket.from), bucket.from
        end
        local today = model.CalendarRange('day')
        local yesterday = model.ShiftCalendar('day', today, -1)
        view.preset = bucket.from == today and 'today' or bucket.from == yesterday and 'yesterday' or 'custom'
    end
    view.from, view.to = bucket.from, bucket.to
    UpdateDateBoxes()
    RefreshSelection()
end

function W.SelectCalendarPeriod(mode, anchor)
    local view, model = View(), Scan.AnalyticsReport
    local from, to = model.CalendarRange(mode, anchor)
    if from > time() or date('*t', from).year < 1970 then return end
    view.calendarMode, view.calendarAnchor = mode, from
    view.yearDetailMonth, view.yearDetailDay = nil, nil
    view.preset = from == model.CalendarRange(mode) and mode or 'custom'
    view.from, view.to = from, to
    UpdateDateBoxes()
    RefreshSelection()
end

function W.MoveCalendar(direction)
    local mode, anchor = CalendarState()
    W.SelectCalendarPeriod(mode, Scan.AnalyticsReport.ShiftCalendar(mode, anchor, direction))
end

local function ResetCalendarForFilter()
    local view = View()
    view.calendarMode = (view.preset == 'year' or view.preset == 'month') and view.preset or 'week'
    view.calendarAnchor = nil
    view.yearDetailMonth, view.yearDetailDay = nil, nil
end

local function SelectTab(index)
    View().tab = index
    PanelTemplates_SetTab(frame, index)
    frame.Items.frame:SetShown(index == TAB_ITEMS)
    frame.Customers.frame:SetShown(index == TAB_CUSTOMERS)
    frame.Charts:SetShown(index == TAB_TIME)
    frame.Returns.frame:SetShown(index == TAB_RETURNS)
    -- Resourcefulness has figures of its own, and no side or coin to filter.
    local onReturns = index == TAB_RETURNS
    frame.TileOrder.frame:SetShown(not onReturns)
    frame.ReturnTileOrder.frame:SetShown(onReturns)
    for _, tile in pairs(frame.Tiles) do tile:SetShown(not onReturns) end
    for _, tile in pairs(frame.ReturnTiles) do tile:SetShown(onReturns) end
    frame.Tiers:SetShown(not onReturns)
    frame.SideDropdown:SetShown(not onReturns)
    frame.TierDropdown:SetShown(not onReturns)
    if report then Render() end
end

-- CSV of the visible tab, for a spreadsheet.
local function CSV(text)
    text = StripCodes(text)
    if text:find('[,"\n]') then text = '"' .. text:gsub('"', '""') .. '"' end
    return text
end

local function ExportCSV()
    if not report or (loading and not backgroundLoad) then return end
    local lines = {}
    local tab = View().tab
    if tab == TAB_RETURNS then
        lines[1] = 'reagent,item_id,profession,returns,quantity,unit_price_gold,worth_gold,unpriced_quantity'
        for _, row in ipairs(frame.Returns.rows or {}) do
            local _, name = Subject(row)
            lines[#lines + 1] = table.concat({ CSV(name), row.itemID, CSV(ProfessionName(row.ppID) or ''),
                row.procs, row.quantity, row.unitPrice and string.format('%.2f', row.unitPrice / GOLD) or '',
                PlainGold(row.value), row.unpriced }, ',')
        end
    elseif tab == TAB_CUSTOMERS then
        lines[1] = 'customer,tier,orders,tips_gold,average_tip_gold,largest_tip_gold,declined,greetings,conversion,last_order'
        for _, row in ipairs(frame.Customers.rows or {}) do
            lines[#lines + 1] = table.concat({ CSV(row.name), row.mark or 'none', row.orders, PlainGold(row.tips),
                PlainGold(row.averageTip), PlainGold(row.maxTip), row.declined, row.greetings,
                row.conversion and string.format('%.2f', row.conversion) or '',
                row.lastOrder and date('%Y-%m-%d %H:%M', row.lastOrder) or '' }, ',')
        end
    elseif tab == TAB_TIME then
        lines[1] = 'period,requests,greetings,crafted,conversion,orders,tips_gold,tips_estimated,orders_without_tip_data'
        for _, chart in ipairs({ frame.HourChart, frame.DayChart }) do
            for _, info in ipairs(chart.infos or {}) do
                local stats = info.stats
                local greetings, crafted = stats.greetings or 0, stats.crafted or 0
                lines[#lines + 1] = table.concat({ CSV(info.period), stats.requests or 0, greetings, crafted,
                    greetings > 0 and string.format('%.2f', crafted / greetings) or '', stats.orders or 0,
                    PlainGold(stats.tips or 0), (stats.tipsEstimated or 0) > 0 and 1 or 0, stats.tipsMissing or 0 }, ',')
            end
        end
    else
        lines[1] = 'item,item_id,profession,requests,greeted,ordered,order_rate,orders_done,declined,average_tip_gold'
        for _, row in ipairs(frame.Items.rows or {}) do
            local _, name = Subject(row)
            lines[#lines + 1] = table.concat({ CSV(name), row.itemID or '', CSV(ProfessionName(row.ppID) or ''),
                row.requests, row.greetings, row.crafted,
                row.conversion and string.format('%.2f', row.conversion) or '', row.orders, row.declined,
                row.averageTip and PlainGold(row.averageTip) or '' }, ',')
        end
    end
    Scan.Utils.DumpCopyableText(table.concat(lines, '\n'))
end

-- Building the window ------------------------------------------------------------

local function Dropdown(parent, width, entries, get, set)
    local dropdown = CreateFrame('DropdownButton', nil, parent, 'WowStyle1DropdownTemplate')
    dropdown:SetWidth(width)
    dropdown:SetupMenu(function(_, root)
        for _, entry in ipairs(entries()) do
            root:CreateRadio(entry.text, function() return get() == entry.value end,
                function() set(entry.value) end, entry.value)
        end
    end)
    return dropdown
end

local function ProfessionEntries()
    local list = { { text = L('All professions'), value = nil } }
    local sorted = {}
    for ppID in pairs(Scan.CONST.PROFESSION_COLORS or {}) do
        local name = ProfessionName(ppID)
        if name then sorted[#sorted + 1] = { text = ColoredProfession(ppID), value = ppID, sortName = name } end
    end
    table.sort(sorted, function(lhs, rhs) return lhs.sortName < rhs.sortName end)
    for _, entry in ipairs(sorted) do list[#list + 1] = entry end
    return list
end

local function CrafterEntries()
    local list = { { text = L('All crafters'), value = nil } }
    local names = {}
    for name in pairs(Scan.DB.characters or {}) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        list[#list + 1] = { text = Scan.NameAndRealmToName and Scan.NameAndRealmToName(name) or name, value = name }
    end
    return list
end

local function Entries(source)
    return function()
        local list = {}
        for _, entry in ipairs(source) do
            local coin = entry.coin and (Coin(entry.coin) .. ' ') or ''
            list[#list + 1] = { text = coin .. L(entry.label), value = entry.value }
        end
        return list
    end
end

local function FilterChanged()
    W.Rebuild()
end

local function Create()
    frame = CreateFrame('Frame', FRAME_NAME, UIParent, 'ButtonFrameTemplate')
    ButtonFrameTemplate_HidePortrait(frame)
    ButtonFrameTemplate_HideButtonBar(frame)
    frame:SetSize(1080, 670)
    frame:SetPoint('CENTER')
    frame:SetFrameStrata('HIGH')
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag('LeftButton')
    frame:SetScript('OnDragStart', frame.StartMoving)
    frame:SetScript('OnDragStop', frame.StopMovingOrSizing)
    frame:SetTitle(L('Analytics'))
    table.insert(UISpecialFrames, FRAME_NAME)

    frame.Inset:ClearAllPoints()
    frame.Inset:SetPoint('TOPLEFT', frame, 'TOPLEFT', 10, -172)
    frame.Inset:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -8, 8)

    local view = View()

    -- Row 1: period and filters.
    local period = Dropdown(frame, 150, function()
        local list = {}
        for _, preset in ipairs(PRESETS) do list[#list + 1] = { text = L(preset.label), value = preset.value } end
        return list
    end, function() return View().preset end, function(value)
        local current = View()
        if value == 'custom' then
            current.from, current.to = CurrentRange()
        end
        current.preset = value
        ResetCalendarForFilter()
        UpdateDateBoxes()
        W.Reload()
    end)
    period:SetPoint('TOPLEFT', frame, 'TOPLEFT', 16, -32)
    frame.Period = period

    frame.DateElements = {}
    local function DateBox(label, anchor, endOfDay)
        local text = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
        text:SetPoint('LEFT', anchor, 'RIGHT', 12, 0)
        text:SetText(L(label))
        table.insert(frame.DateElements, text)
        local box = CreateFrame('EditBox', nil, frame, 'InputBoxTemplate')
        box:SetSize(78, 20)
        box:SetAutoFocus(false)
        box:SetPoint('LEFT', text, 'RIGHT', 8, 0)
        box:SetScript('OnEnterPressed', function(self)
            local value = Scan.AnalyticsReport.ParseDate(self:GetText(), endOfDay)
            self:ClearFocus()
            if not value then UpdateDateBoxes() return end
            local current = View()
            local from, to = CurrentRange()
            current.preset = 'custom'
            current.from, current.to = from, to
            if endOfDay then current.to = value else current.from = value end
            if current.from > current.to then
                if endOfDay then
                    current.from = Scan.AnalyticsReport.CalendarRange('day', value)
                else
                    current.to = select(2, Scan.AnalyticsReport.CalendarRange('day', value))
                end
            end
            ResetCalendarForFilter()
            UpdateDateBoxes()
            W.Reload()
        end)
        box:SetScript('OnEscapePressed', function(self)
            self:ClearFocus()
            UpdateDateBoxes()
        end)
        box:SetScript('OnEnter', function(self)
            GameTooltip:SetOwner(self, 'ANCHOR_TOP')
            GameTooltip_AddNormalLine(GameTooltip, L('Date box tooltip'))
            GameTooltip:Show()
        end)
        box:SetScript('OnLeave', function() GameTooltip:Hide() end)
        table.insert(frame.DateElements, box)
        return box
    end

    frame.FromBox = DateBox('From', period, false)
    frame.ToBox = DateBox('To', frame.FromBox, true)

    local profession = Dropdown(frame, 150, ProfessionEntries,
        function() return View().ppID end, function(value) View().ppID = value FilterChanged() end)
    profession:SetPoint('LEFT', period, 'RIGHT', 8, 0)
    frame.Profession = profession
    local crafter = Dropdown(frame, 150, CrafterEntries,
        function() return View().crafter end, function(value) View().crafter = value FilterChanged() end)
    crafter:SetPoint('LEFT', profession, 'RIGHT', 8, 0)
    local side = Dropdown(frame, 120, Entries(SIDES),
        function() return View().side end, function(value) View().side = value FilterChanged() end)
    side:SetPoint('LEFT', crafter, 'RIGHT', 8, 0)
    side:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_TOP')
        GameTooltip_AddNormalLine(GameTooltip, L('Side filter tooltip'))
        GameTooltip:Show()
    end)
    side:SetScript('OnLeave', function() GameTooltip:Hide() end)
    local tier = Dropdown(frame, 176, Entries(TIERS),
        function() return View().tier end, function(value) View().tier = value FilterChanged() end)
    tier:SetPoint('LEFT', side, 'RIGHT', 8, 0)
    frame.SideDropdown, frame.TierDropdown = side, tier

    -- Row 2: a single full-width row of metrics, followed by customer counts.
    frame.Tiles, frame.TileOrder = CreateTiles(frame, 16, -68)
    frame.ReturnTiles, frame.ReturnTileOrder = CreateTiles(frame, 16, -68, RETURN_TILE_GROUPS)
    frame.Tiles.returnedValue:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_BOTTOM')
        GameTooltip_SetTitle(GameTooltip, L('Reagent returns value'))
        GameTooltip_AddNormalLine(GameTooltip, L('Returned worth tooltip'))
        GameTooltip_AddNormalLine(GameTooltip, L('Reagent returns filters tooltip'))
        local totals = returns and returns.totals
        if totals then
            GameTooltip:AddDoubleLine(L('Reagents returned'), TileNumber(totals.quantity), 1, 1, 1, 1, 1, 1)
            if totals.unpriced > 0 then
                GameTooltip:AddLine(string.format(L('Without a price: %d'), totals.unpriced), 1, 0.5, 0.4, true)
            end
        end
        GameTooltip:Show()
    end)
    frame.Tiles.online:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_BOTTOM')
        GameTooltip_SetTitle(GameTooltip, L('Online time'))
        GameTooltip_AddNormalLine(GameTooltip, L('Online time tooltip'))
        if report then GameTooltip:AddLine(Duration(report.totals.online), 1, 1, 1) end
        GameTooltip:Show()
    end)
    frame.ReturnTiles.chance:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_BOTTOM')
        GameTooltip_SetTitle(GameTooltip, L('Chance'))
        GameTooltip_AddNormalLine(GameTooltip, L('Return chance tooltip'))
        for _, profession in ipairs(returns and returns.professions or {}) do
            GameTooltip:AddDoubleLine(ColoredProfession(profession.ppID),
                string.format('%s  (%d / %d)', Percent(profession.chance), profession.procs, profession.crafts), 1, 1, 1, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    frame.Tiers = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    frame.Tiers:SetPoint('TOPLEFT', frame, 'TOPLEFT', 18, -116)
    frame.Tiers:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -18, -116)
    frame.Tiers:SetJustifyH('LEFT')
    frame.Tiers:SetWordWrap(false)

    -- Row 3: search, collection/status and actions, separate from the metrics.
    local toolbar = CreateFrame('Frame', nil, frame)
    toolbar:SetPoint('TOPLEFT', frame, 'TOPLEFT', 16, -138)
    toolbar:SetSize(1048, 22)
    frame.Toolbar = toolbar

    local export = CreateFrame('Button', nil, toolbar, 'UIPanelButtonTemplate')
    export:SetSize(110, 22)
    export:SetPoint('RIGHT', toolbar, 'RIGHT', 0, 0)
    export:SetText(L('Export CSV'))
    export:SetScript('OnClick', ExportCSV)
    frame.ExportButton = export

    local sync = CreateFrame('Button', nil, toolbar, 'UIPanelButtonTemplate')
    sync:SetSize(150, 22)
    sync:SetPoint('RIGHT', export, 'LEFT', -6, 0)
    sync:SetText(L('Exchange now'))
    sync:SetScript('OnClick', function()
        if Scan.AnalyticsSync then Scan.AnalyticsSync.SyncNow() end
        -- The window refreshes as soon as the exchange is done.
    end)
    sync:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_TOP')
        GameTooltip_SetTitle(GameTooltip, L('Exchange now'))
        GameTooltip_AddNormalLine(GameTooltip, L('Exchange now tooltip'))
        local status = Scan.AnalyticsSync and Scan.AnalyticsSync.Status() or {}
        if #status > 0 then GameTooltip:AddLine(' ') end
        for _, account in ipairs(status) do
            local name = account.name .. (account.version and (' |cff9d9d9d(' .. account.version .. ')|r') or '')
            GameTooltip:AddDoubleLine(name,
                account.at and date('%d.%m %H:%M', account.at) or L('never exchanged'), 1, 1, 1, 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    sync:SetScript('OnLeave', function() GameTooltip:Hide() end)
    frame.SyncButton = sync

    -- Search by name: items on the item tab, customers on the customer tab.
    local search = CreateFrame('EditBox', nil, toolbar, 'SearchBoxTemplate')
    search:SetSize(236, 20)
    search:SetPoint('LEFT', toolbar, 'LEFT', 0, 0)
    search:SetAutoFocus(false)
    if search.Instructions then search.Instructions:SetText(L('Search by name')) end
    local searchPending = false
    search:HookScript('OnTextChanged', function(self)
        local text = (self:GetText() or ''):lower():gsub('^%s+', ''):gsub('%s+$', '')
        if text == searchText then return end
        searchText = text
        if searchPending then return end
        searchPending = true
        C_Timer.After(0.25, function()
            searchPending = false
            if frame:IsShown() and report then Render() end
        end)
    end)
    frame.Search = search

    local gather = CreateFrame('CheckButton', nil, toolbar, 'UICheckButtonTemplate')
    gather:SetSize(22, 22)
    gather:SetPoint('LEFT', search, 'RIGHT', 16, 0)
    gather.text = gather:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    gather.text:SetPoint('LEFT', gather, 'RIGHT', 2, 0)
    gather.text:SetText(L('Gather Analytics'))
    gather:SetChecked(Scan.AnalyticsLog.IsEnabled())
    gather:SetScript('OnClick', function(self) Scan.AnalyticsLog.SetEnabled(self:GetChecked()) end)
    frame.GatherCheck = gather

    frame.SyncText = toolbar:CreateFontString(nil, 'OVERLAY', 'GameFontDisableSmall')
    frame.SyncText:SetPoint('LEFT', gather.text, 'RIGHT', 20, 0)
    frame.SyncText:SetPoint('RIGHT', sync, 'LEFT', -16, 0)
    frame.SyncText:SetJustifyH('LEFT')
    frame.SyncText:SetWordWrap(false)


    -- The tabs' contents.
    frame.Items = CreateTable(frame.Inset, ITEM_COLUMNS, TAB_ITEMS, function(row, data)
        if data.kind == 'item' and data.itemID then
            GameTooltip:SetOwner(row, 'ANCHOR_RIGHT')
            GameTooltip:SetItemByID(data.itemID)
            GameTooltip:Show()
        end
    end)
    frame.Returns = CreateTable(frame.Inset, RETURN_COLUMNS, TAB_RETURNS, function(row, data)
        GameTooltip:SetOwner(row, 'ANCHOR_RIGHT')
        GameTooltip:SetItemByID(data.itemID)
        GameTooltip:AddLine(' ')
        GameTooltip:AddLine(L('Worth at the price of the moment it came back'), 0.8, 0.8, 0.8, true)
        if data.unpriced > 0 then
            GameTooltip:AddLine(string.format(L('Without a price: %d'), data.unpriced), 1, 0.5, 0.4)
        end
        GameTooltip:Show()
    end)
    frame.Customers = CreateTable(frame.Inset, CUSTOMER_COLUMNS, TAB_CUSTOMERS, function(row, data)
        local text = Scan.Generous and Scan.Generous.Describe(data.name)
        if text then
            GameTooltip:SetOwner(row, 'ANCHOR_RIGHT')
            GameTooltip_SetTitle(GameTooltip, data.name)
            GameTooltip_AddNormalLine(GameTooltip, text)
            GameTooltip:Show()
        end
    end)

    frame.Charts = CreateFrame('Frame', nil, frame.Inset)
    frame.Charts:SetAllPoints(frame.Inset)
    frame.MetricDropdown = Dropdown(frame.Charts, 170, Entries(METRICS),
        function() return View().metric end, function(value) View().metric = value UpdateCharts() end)
    frame.MetricDropdown:SetPoint('TOPRIGHT', frame.Charts, 'TOPRIGHT', -10, -6)
    local hourTitle = frame.Charts:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    frame.HourTitle = hourTitle
    hourTitle:SetPoint('TOPLEFT', 14, -10)
    hourTitle:SetText(L('By hour of day'))
    local legend = frame.Charts:CreateFontString(nil, 'OVERLAY', 'GameFontDisableSmall')
    legend:SetPoint('TOPLEFT', frame.Charts, 'TOPLEFT', 14, -28)
    legend:SetText(L('Grey behind a bar: the share of that time you were online.'))
    frame.HourChart = CreateChart(frame.Charts, 31, function() return '' end)
    frame.HourChart:SetPoint('TOPLEFT', frame.Charts, 'TOPLEFT', 10, -46)
    frame.HourChart:SetPoint('RIGHT', frame.Charts, 'RIGHT', -10, 0)
    frame.HourChart:SetHeight(184)
    frame.DetailBack = CreateFrame('Button', nil, frame.Charts, 'UIPanelButtonTemplate')
    frame.DetailBack:SetSize(136, 22)
    frame.DetailBack:SetPoint('RIGHT', frame.MetricDropdown, 'LEFT', -8, 0)
    frame.DetailBack:SetText(L('Back to month days'))
    frame.DetailBack:SetScript('OnClick', function()
        local month = frame.HourChart.detailMonth
        if (not loading or backgroundLoad) and month then
            local first, last = Scan.AnalyticsReport.CalendarRange('month', month)
            W.SelectCalendarBucket({ unit = 'month', from = first, to = last })
        end
    end)
    frame.DetailBack:Hide()
    local dayTitle = frame.Charts:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    frame.CalendarTitle = dayTitle
    dayTitle:SetPoint('TOPLEFT', frame.HourChart, 'BOTTOMLEFT', 4, -14)
    dayTitle:SetText(L('By day of week'))
    frame.CalendarMode = Dropdown(frame.Charts, 110, Entries(CALENDAR_MODES),
        function() return (CalendarState()) end, function(mode)
            -- Changing the calendar granularity always starts at Current.
            -- Historical browsing remains on the explicit previous/next keys.
            W.SelectCalendarPeriod(mode, time())
        end)
    local function CalendarButton(text, width, action)
        local button = CreateFrame('Button', nil, frame.Charts, 'UIPanelButtonTemplate')
        button:SetSize(width, 22)
        button:SetText(text)
        button:SetScript('OnClick', action)
        return button
    end
    frame.CalendarCurrent = CalendarButton(L('Current period'), 96, function()
        W.SelectCalendarPeriod((CalendarState()), time())
    end)
    frame.CalendarCurrent:SetPoint('TOPRIGHT', frame.HourChart, 'BOTTOMRIGHT', 0, -8)
    frame.CalendarNext = CalendarButton('>', 26, function() W.MoveCalendar(1) end)
    frame.CalendarNext:SetPoint('RIGHT', frame.CalendarCurrent, 'LEFT', -4, 0)
    frame.CalendarPrevious = CalendarButton('<', 26, function() W.MoveCalendar(-1) end)
    frame.CalendarPrevious:SetPoint('RIGHT', frame.CalendarNext, 'LEFT', -4, 0)
    frame.CalendarMode:SetPoint('RIGHT', frame.CalendarPrevious, 'LEFT', -8, 0)
    frame.DayChart = CreateChart(frame.Charts, 31, function() return '' end)
    frame.DayChart:SetPoint('TOPLEFT', frame.HourChart, 'BOTTOMLEFT', 0, -40)
    frame.DayChart:SetPoint('RIGHT', frame.Charts, 'RIGHT', -10, 0)
    frame.DayChart:SetPoint('BOTTOM', frame.Charts, 'BOTTOM', 0, 10)

    frame.Status = frame.Inset:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    frame.Status:SetPoint('CENTER')

    -- Tabs under the window, as in Journalator.
    frame.Tabs = {}
    for index, label in ipairs({ 'Items', 'Customers', 'By time', 'Resource returns' }) do
        local tab = CreateFrame('Button', FRAME_NAME .. 'Tab' .. index, frame, 'PanelTabButtonTemplate')
        tab:SetID(index)
        tab:SetText(L(label))
        if index == 1 then
            tab:SetPoint('TOPLEFT', frame, 'BOTTOMLEFT', 20, 2)
        else
            tab:SetPoint('LEFT', frame.Tabs[index - 1], 'RIGHT', -15, 0)
        end
        tab:SetScript('OnShow', function(self) PanelTemplates_TabResize(self, 30, nil, 20) end)
        tab:SetScript('OnClick', function(self)
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            SelectTab(self:GetID())
        end)
        PanelTemplates_TabResize(tab, 30, nil, 20)
        frame.Tabs[index] = tab
    end
    PanelTemplates_SetNumTabs(frame, #frame.Tabs)

    frame:SetScript('OnShow', function()
        -- Smaller than the game window when it has to be (tabs hang below).
        if Scan.Utils.FitFrame then Scan.Utils.FitFrame(frame, 20, 40) end
        gather:SetChecked(Scan.AnalyticsLog.IsEnabled())
        UpdateDateBoxes()
        SelectTab(View().tab or TAB_ITEMS)
        W.Reload()
    end)
    frame:SetScript('OnHide', function() W.Release() end)
    frame:SetScript('OnEvent', function(_, event)
        if (event == 'DISPLAY_SIZE_CHANGED' or event == 'UI_SCALE_CHANGED') and frame:IsShown() then
            if Scan.Utils.FitFrame then Scan.Utils.FitFrame(frame, 20, 40) end
        end
        -- Loading by ID answers with ITEM_DATA_LOAD_RESULT, not always with
        -- GET_ITEM_INFO_RECEIVED.
        if (event == 'ITEM_DATA_LOAD_RESULT' or event == 'GET_ITEM_INFO_RECEIVED') and namesPending and report then
            ScheduleNameRedraw(0.3)
        end
    end)
    frame:RegisterEvent('ITEM_DATA_LOAD_RESULT')
    frame:RegisterEvent('GET_ITEM_INFO_RECEIVED')
    frame:RegisterEvent('DISPLAY_SIZE_CHANGED')
    frame:RegisterEvent('UI_SCALE_CHANGED')
    frame:Hide()

    -- Events trickle in (mentions every few seconds): counted again shortly
    -- after, not once per event.
    Scan.AnalyticsLog.OnChange(function() ScheduleRebuild(2) end)
end

function W.Toggle()
    if not frame then Create() end
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

-- The fit-to-screen setting changed.
function W.Refit()
    if frame then if Scan.Utils.FitFrame then Scan.Utils.FitFrame(frame, 20, 40) end end
end

function W.IsShown()
    return frame ~= nil and frame:IsShown()
end
