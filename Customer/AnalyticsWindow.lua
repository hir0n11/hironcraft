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
-- Resourcefulness on crafting orders, for the fourth tab.
local returns = nil
local loadToken = 0
local rebuildPending = false
local namesPending = false
-- What was typed in the search box, lower case; '' shows everything.
local searchText = ''

local TAB_ITEMS, TAB_CUSTOMERS, TAB_TIME, TAB_RETURNS = 1, 2, 3, 4

local PRESETS = {
    { value = '1h', label = 'Last hour' },
    { value = 'today', label = 'Today' },
    { value = 'yesterday', label = 'Yesterday' },
    { value = '7d', label = 'Last 7 days' },
    { value = '30d', label = 'Last 30 days' },
    { value = 'month', label = 'This month' },
    { value = 'all', label = 'All time' },
    { value = 'custom', label = 'Own dates' },
}

local TIERS = {
    { value = nil, label = 'All customers' },
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

-- Formatting -----------------------------------------------------------------

local function Number(value)
    if not value or value == 0 then return '|cff808080-|r' end
    return BreakUpLargeNumbers and BreakUpLargeNumbers(value) or tostring(value)
end

local function Percent(value)
    if not value then return '|cff808080-|r' end
    return string.format('%d%%', math.floor(value * 100 + 0.5))
end

local function Gold(copper)
    if not copper or copper <= 0 then return '|cff808080-|r' end
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

-- What a row of the item table is: a name with its icon and quality colour.
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
        return (icon and ('|T' .. icon .. ':16:16:0:0|t ') or '') .. text, name
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
    { key = 'mentions', label = 'Mentions', width = 72, tip = 'Mentions tooltip' },
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
    view:SetElementInitializer('HironCraftAnalyticsRowTemplate', function(row, data)
        -- First: a hover must never show the item this frame showed before.
        row.data = data.row
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
            cell:SetText(ok and text or '?')
        end
    end)
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
        local list = {}
        for index, row in ipairs(rows) do list[index] = { row = row, index = index } end
        self.scrollBox:SetDataProvider(CreateDataProvider(list), ScrollBoxConstants.RetainScrollPosition)
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
        local bar = CreateFrame('Frame', nil, chart)
        bar.fill = bar:CreateTexture(nil, 'ARTWORK')
        bar.fill:SetColorTexture(1, 0.78, 0.25, 0.85)
        bar.fill:SetPoint('BOTTOMLEFT')
        bar.fill:SetPoint('BOTTOMRIGHT')
        bar.value = bar:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        bar.value:SetPoint('BOTTOM', bar.fill, 'TOP', 0, 2)
        bar.label = chart:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
        bar.label:SetPoint('TOP', bar, 'BOTTOM', 0, -3)
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

    function chart:SetValues(values, infos)
        local width, height = self:GetWidth(), self:GetHeight() - 34
        local slot = width / count
        local max = 0
        for index = 1, count do max = math.max(max, values[index] or 0) end
        for index, bar in ipairs(self.bars) do
            local value = values[index] or 0
            bar:ClearAllPoints()
            bar:SetPoint('BOTTOMLEFT', self, 'BOTTOMLEFT', (index - 1) * slot + slot * 0.15, 18)
            bar:SetSize(slot * 0.7, height)
            bar.fill:SetHeight(math.max(1, max > 0 and height * value / max or 1))
            bar.fill:SetAlpha(value > 0 and 1 or 0.25)
            bar.value:SetText(value > 0 and value or '')
            bar.info = infos and infos[index]
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
    local counts = { generous = 0, regular = 0, stingy = 0 }
    local store = Scan.DB.settings.generous_customers
    if type(store) == 'table' and Scan.Generous then
        for key in pairs(store) do
            local mark = Scan.Generous.MarkOf(key)
            if mark and counts[mark] then counts[mark] = counts[mark] + 1 end
        end
    end
    return counts
end

-- The summary: one tile per figure, in three groups - the way from request
-- to craft, the orders, the chat - and a line of customers per coin.
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
    { color = { 0.62, 0.62, 0.62 }, tiles = {
        { key = 'mentions', label = 'Mentions', tip = 'Mentions tooltip' },
    } },
}
local TILE_WIDTH, TILE_HEIGHT, TILE_GAP, GROUP_GAP = 74, 40, 4, 12
-- The export and exchange buttons at the right end of the tile row.
local TILE_ROW_RESERVED = 14 + 110 + 6 + 150 + 4
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
    local tiles, order = {}, { x = x, y = y }
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

-- Each tile widens to its figure (a big sum of tips), the ones after it move
-- along; should the row then run into the buttons on the right, the figures
-- that needed more room take a smaller font instead.
local function LayoutTiles(order)
    local limit = frame:GetWidth() - TILE_ROW_RESERVED
    local function Place(shrink)
        local x = order.x
        for index, tile in ipairs(order) do
            tile.value:SetFontObject(TILE_FONT)
            local need = math.ceil(TextWidth(tile.value) + 14)
            if shrink and need > tile.minWidth then
                tile.value:SetFontObject(TILE_FONT_SMALL)
                need = math.ceil(TextWidth(tile.value) + 14)
            end
            if index > 1 then x = x + tile.gap end
            local width = math.max(tile.minWidth, need)
            tile:SetWidth(width)
            tile:SetPoint('TOPLEFT', frame, 'TOPLEFT', x, order.y)
            x = x + width
        end
        return x
    end
    if Place(false) > limit then Place(true) end
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
    for _, key in ipairs({ 'requests', 'greetings', 'crafted', 'orders', 'declined', 'mentions' }) do
        tiles[key].value:SetText(report and TileNumber(totals[key]) or '')
    end
    tiles.conversion.value:SetText(report and Percent(totals.conversion) or '')
    tiles.conversion.value:SetTextColor(ConversionColor(totals.conversion))
    tiles.tips.value:SetText(report and Gold(totals.tips) or '')
    tiles.averageTip.value:SetText(report and Gold(totals.averageTip) or '')
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
    frame.Tiers:SetText(string.format('|cffffd100%s|r   %s     %s     %s          |cff9d9d9d%s|r   %s     %s     %s',
        L('Customers in the period:'),
        Count('generous', tiers.generous), Count('regular', tiers.regular), Count('stingy', tiers.stingy),
        L('Marked overall:'),
        Count('generous', all.generous), Count('regular', all.regular), Count('stingy', all.stingy)))
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

local function UpdateCharts()
    if not report then return end
    local metric = View().metric or 'orders'
    local function Infos(group, count, titleOf, offset)
        local values, infos = {}, {}
        for index = 1, count do
            local slot = index - 1 + offset
            values[index] = report[group][metric][slot] or 0
            infos[index] = { title = titleOf(index), lines = {
                string.format('%s: %d', L('Requests'), report[group].requests[slot] or 0),
                string.format('%s: %d', L('Greetings'), report[group].greetings[slot] or 0),
                string.format('%s: %d', L('Crafted orders'), report[group].orders[slot] or 0),
            } }
        end
        return values, infos
    end
    frame.HourChart:SetValues(Infos('hours', 24, function(index) return string.format('%02d:00-%02d:59', index - 1, index - 1) end, 0))
    frame.DayChart:SetValues(Infos('weekdays', 7, function(index) return L(WEEKDAYS[index]) end, 1))
end

local function SetStatus(text)
    frame.Status:SetText(text or '')
    frame.Status:SetShown(text ~= nil and text ~= '')
end

local function Matches(text)
    return searchText == '' or (text and text:lower():find(searchText, 1, true) ~= nil)
end

-- Items only seen in chat are left out: a row appears once someone asked
-- you for it or ordered it, and fills in as more comes. A search looks at
-- every item, chat-only ones included, so any item can be checked.
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

local function Render()
    if not frame or not report then return end
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
end

function W.Rebuild()
    if not frame or not chunks then return end
    report = Scan.AnalyticsReport.Build(chunks, Filters(), Context())
    returns = Scan.AnalyticsReport.BuildReturns(chunks, Filters())
    Render()
end

function W.Reload()
    if not frame or not frame:IsShown() then return end
    loadToken = loadToken + 1
    local token = loadToken
    SetStatus(L('Loading analytics...'))
    local from, to = CurrentRange()
    Scan.AnalyticsLog.LoadRange(from, to, function(done, total)
        if token == loadToken and frame:IsShown() then
            SetStatus(string.format(L('Loading analytics %d / %d'), done, total))
        end
    end, function(loaded)
        if token ~= loadToken or not frame:IsShown() then return end
        chunks = loaded
        W.Rebuild()
    end)
end

-- New events while the window is open: counted again a little later.
local function ScheduleRebuild(delay)
    if rebuildPending or not frame or not frame:IsShown() then return end
    rebuildPending = true
    C_Timer.After(delay, function()
        rebuildPending = false
        if frame and frame:IsShown() then W.Reload() end
    end)
end

-- A linked account's analytics has arrived: count it at once.
function W.DataArrived()
    if frame and frame:IsShown() then W.Reload() end
end

function W.Release()
    loadToken = loadToken + 1
    chunks, report, returns = nil, nil, nil
    if Scan.AnalyticsLog then Scan.AnalyticsLog.ReleaseCache() end
    if frame then
        frame.Items:SetRows({})
        frame.Customers:SetRows({})
        frame.Returns:SetRows({})
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

local function SelectTab(index)
    View().tab = index
    PanelTemplates_SetTab(frame, index)
    frame.Items.frame:SetShown(index == TAB_ITEMS)
    frame.Customers.frame:SetShown(index == TAB_CUSTOMERS)
    frame.Charts:SetShown(index == TAB_TIME)
    frame.Returns.frame:SetShown(index == TAB_RETURNS)
    -- Resourcefulness has figures of its own, and no side or coin to filter.
    local onReturns = index == TAB_RETURNS
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
    if not report then return end
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
        lines[1] = 'period,requests,greetings,orders'
        for hour = 0, 23 do
            lines[#lines + 1] = string.format('%02d:00,%d,%d,%d', hour, report.hours.requests[hour],
                report.hours.greetings[hour], report.hours.orders[hour])
        end
        for day = 1, 7 do
            lines[#lines + 1] = string.format('%s,%d,%d,%d', CSV(L(WEEKDAYS[day])), report.weekdays.requests[day],
                report.weekdays.greetings[day], report.weekdays.orders[day])
        end
    else
        lines[1] = 'item,item_id,profession,mentions,requests,greetings,crafted,conversion,all_orders,declined,average_tip_gold'
        for _, row in ipairs(frame.Items.rows or {}) do
            local _, name = Subject(row)
            lines[#lines + 1] = table.concat({ CSV(name), row.itemID or '', CSV(ProfessionName(row.ppID) or ''),
                row.mentions, row.requests, row.greetings, row.crafted,
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
    frame:SetSize(1080, 640)
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
    frame.Inset:SetPoint('TOPLEFT', frame, 'TOPLEFT', 10, -142)
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

    -- Row 2: what the period comes to, and the buttons.
    frame.Tiles, frame.TileOrder = CreateTiles(frame, 16, -68)
    frame.ReturnTiles, frame.ReturnTileOrder = CreateTiles(frame, 16, -68, RETURN_TILE_GROUPS)
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
    frame.Tiers:SetJustifyH('LEFT')

    local export = CreateFrame('Button', nil, frame, 'UIPanelButtonTemplate')
    export:SetSize(110, 22)
    export:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -14, -68)
    export:SetText(L('Export CSV'))
    export:SetScript('OnClick', ExportCSV)
    frame.ExportButton = export

    local sync = CreateFrame('Button', nil, frame, 'UIPanelButtonTemplate')
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

    -- Search by name: items on the item tab, customers on the customer tab.
    local search = CreateFrame('EditBox', nil, frame, 'SearchBoxTemplate')
    search:SetSize(258, 20)
    search:SetPoint('TOPRIGHT', export, 'BOTTOMRIGHT', 0, -4)
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

    frame.SyncText = frame:CreateFontString(nil, 'OVERLAY', 'GameFontDisableSmall')
    frame.SyncText:SetPoint('TOPRIGHT', search, 'BOTTOMRIGHT', 0, -8)

    local gather = CreateFrame('CheckButton', nil, frame, 'UICheckButtonTemplate')
    gather:SetSize(22, 22)
    gather:SetPoint('TOPLEFT', search, 'BOTTOMLEFT', -8, -1)
    gather.text = gather:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    gather.text:SetPoint('LEFT', gather, 'RIGHT', 2, 0)
    gather.text:SetText(L('Gather Analytics'))
    gather:SetChecked(Scan.AnalyticsLog.IsEnabled())
    gather:SetScript('OnClick', function(self) Scan.AnalyticsLog.SetEnabled(self:GetChecked()) end)


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
    hourTitle:SetPoint('TOPLEFT', 14, -10)
    hourTitle:SetText(L('By hour of day'))
    frame.HourChart = CreateChart(frame.Charts, 24, function(index) return tostring(index - 1) end)
    frame.HourChart:SetPoint('TOPLEFT', frame.Charts, 'TOPLEFT', 10, -30)
    frame.HourChart:SetPoint('RIGHT', frame.Charts, 'RIGHT', -10, 0)
    frame.HourChart:SetHeight(200)
    local dayTitle = frame.Charts:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    dayTitle:SetPoint('TOPLEFT', frame.HourChart, 'BOTTOMLEFT', 4, -14)
    dayTitle:SetText(L('By day of week'))
    frame.DayChart = CreateChart(frame.Charts, 7, function(index) return L(WEEKDAYS[index]) end)
    frame.DayChart:SetPoint('TOPLEFT', dayTitle, 'BOTTOMLEFT', -4, -6)
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
        if event == 'GET_ITEM_INFO_RECEIVED' and namesPending and report then
            namesPending = false
            C_Timer.After(0.3, function() if frame:IsShown() and report then Render() end end)
        end
    end)
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
