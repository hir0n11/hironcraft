-- Execute the real widget factories against a small frame model. This catches
-- reparenting/anchor regressions without claiming to emulate protected WoW APIs.
if not setfenv then
    function setfenv(fn, env)
        if type(fn) == 'number' then fn = debug.getinfo(fn + 1, 'f').func end
        for i = 1, 100 do
            local name = debug.getupvalue(fn, i)
            if not name then break end
            if name == '_ENV' then
                debug.upvaluejoin(fn, i, function() return env end, 1)
                break
            end
        end
        return fn
    end
end
local frames, methods = {}, {}
local function noop() end
local function frame(kind, parent, template)
    local f = setmetatable({ kind = kind, parent = parent, template = template, anchors = {}, scripts = {}, visible = true }, { __index = methods })
    frames[#frames + 1] = f
    if template == 'UIPanelScrollFrameTemplate' then f.ScrollBar = frame('Slider', f) end
    return f
end
function methods:CreateFontString(_, _, template) return frame('FontString', self, template) end
function methods:CreateTexture() return frame('Texture', self) end
function methods:CreateLine() return frame('Line', self) end
function methods:SetStartPoint(point, relative, x, y) self.startPoint = {point, relative, x, y} end
function methods:SetEndPoint(point, relative, x, y) self.endPoint = {point, relative, x, y} end
function methods:SetThickness(value) self.thickness = value end
function methods:SetPoint(point, relative, relativePoint, x, y)
    if type(relative) == 'number' then x, y, relative, relativePoint = relative, relativePoint, self.parent, point end
    relative, relativePoint = relative or self.parent, relativePoint or point
    self.anchors[point] = { relative, relativePoint, x or 0, y or 0 }
end
function methods:ClearAllPoints() self.anchors = {} end
function methods:SetAllPoints(other)
    self:ClearAllPoints()
    self:SetPoint('TOPLEFT', other or self.parent, 'TOPLEFT', 0, 0)
    self:SetPoint('BOTTOMRIGHT', other or self.parent, 'BOTTOMRIGHT', 0, 0)
end
function methods:SetSize(w, h) self.w, self.h = w, h end
function methods:SetWidth(w) self.w = w end
function methods:SetHeight(h) self.h = h end
local factors = { TOPLEFT={0,0},TOP={.5,0},TOPRIGHT={1,0},LEFT={0,.5},CENTER={.5,.5},RIGHT={1,.5},BOTTOMLEFT={0,1},BOTTOM={.5,1},BOTTOMRIGHT={1,1} }
local function bounds(f)
    if not f then return 0, 0, 0, 0 end
    local w, h = f.w or 0, f.h or (f.kind == 'FontString' and 14 or 0)
    if f.kind == 'FontString' and not f.w then w = #(f.text or '') * 6 end
    local points = {}
    for point, a in pairs(f.anchors) do
        local x0, y0, w0, h0 = bounds(a[1])
        local r, p = factors[a[2]], factors[point]
        points[#points+1] = { x0 + r[1]*w0 + a[3], y0 + r[2]*h0 - a[4], p[1], p[2] }
    end
    if #points == 0 then
        local x, y = bounds(f.parent)
        return x, y, w, h
    end
    local a = points[1]
    for i=2,#points do
        local b = points[i]
        if b[3] ~= a[3] then w = (b[1]-a[1])/(b[3]-a[3]) end
        if b[4] ~= a[4] then h = (b[2]-a[2])/(b[4]-a[4]) end
    end
    return a[1]-a[3]*w, a[2]-a[4]*h, w, h
end
function methods:GetWidth() local _,_,w = bounds(self); return w end
function methods:GetHeight() local _,_,_,h = bounds(self); return h end
function methods:GetParent() return self.parent end
function methods:SetParent(parent) self.parent = parent end
function methods:SetScale(scale) self.scale = scale end
function methods:GetEffectiveScale() return (self.scale or 1) * (self.parent and self.parent:GetEffectiveScale() or 1) end
function methods:SetFrameStrata(strata) self.strata = strata end
function methods:GetFrameStrata() return self.strata or 'MEDIUM' end
function methods:SetAlpha(alpha) self.alpha = alpha end
function methods:GetAlpha() return self.alpha or 1 end
function methods:GetObjectType() return self.kind end
function methods:GetFrameLevel() return self.level or 1 end
function methods:SetFrameLevel(level) self.level = level end
function methods:SetText(text) self.text = tostring(text or '') end
function methods:GetText() return self.text end
function methods:SetTextColor(r,g,b,a) self.color = {r,g,b,a or 1} end
function methods:SetColorTexture(r,g,b,a) self.color = {r,g,b,a or 1} end
function methods:SetTexture(texture) self.texture = texture end
function methods:SetAtlas(texture) self.texture = texture end
function methods:SetBackdrop(value) self.backdrop = value end
function methods:SetBackdropColor(r,g,b,a) self.fill = {r,g,b,a} end
function methods:SetBackdropBorderColor(r,g,b,a) self.border = {r,g,b,a} end
function methods:SetFont(path, size) self.fontPath, self.fontSize = path, size end
function methods:SetFontObject() self.fontPath, self.fontSize = STANDARD_TEXT_FONT, 12 end
function methods:SetJustifyH(value) self.justify = value end
function methods:SetJustifyV(value) self.justifyV = value end
function methods:GetStringWidth() return #(self.text or '') * 6 end
function methods:GetUnboundedStringWidth()
    local plain, textureCount = (self.text or ''):gsub('|T.-|t', '')
    return #plain * 7 + textureCount * 13
end
function methods:SetWordWrap(value) self.wordWrap = value end
function methods:SetMaxLines(value) self.maxLines = value end
function methods:GetFontString()
    self.fontString = self.fontString or frame('FontString', self)
    return self.fontString
end
for _, kind in ipairs({'Normal','Pushed','Disabled','Highlight'}) do
    methods['Set'..kind..'Texture'] = function(self, path)
        self[kind..'Texture'] = self[kind..'Texture'] or frame('Texture', self)
        self[kind..'Texture']:SetTexture(path)
    end
    methods['Get'..kind..'Texture'] = function(self) return self[kind..'Texture'] end
end
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:HookScript(event, fn)
    local previous = self.scripts[event]
    self.scripts[event] = function(...) if previous then previous(...) end; fn(...) end
end
function methods:Click() if self.scripts.OnClick then self.scripts.OnClick(self, 'LeftButton') end end
function methods:Show() self.visible = true end
function methods:Hide() self.visible = false end
function methods:SetShown(value) self.visible = not not value end
function methods:IsShown() return self.visible end
function methods:IsVisible() return self.visible and (not self.parent or self.parent:IsVisible()) end
function methods:IsEnabled() return true end
function methods:HasFocus() return false end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:SetScrollChild(child) self.child = child end
function methods:SetVerticalScroll(value) self.scroll = value end
function methods:GetVerticalScroll() return self.scroll or 0 end
for _, name in ipairs({'RegisterForClicks','SetTexCoord','SetRotation','SetAutoFocus','SetMaxLetters','SetCursorPosition','SetTextInsets','EnableMouse','EnableMouseWheel','LockHighlight','UnlockHighlight','SetStatusBarTexture','SetStatusBarColor','SetMinMaxValues','SetValue','RegisterEvent','SetDesaturated','SetVertexColor','Enable','SetBlendMode'}) do methods[name] = noop end

local CO, PT = {}, { L = {} }
PT.CraftingOrders = CO
HironCraftProfit = PT
STANDARD_TEXT_FONT = 'Fonts/FRIZQT__.TTF'
PT.FONT = 'Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\fonts\\default.ttf'
SlashCmdList = {}
GameFontNormalSmall, GameFontNormal, GameFontHighlightSmall = {}, {}, {}
CreateFrame = function(kind, _, parent, template) return frame(kind, parent, template) end
GetLocale = function() return arg[2] == 'en' and 'enUS' or 'ruRU' end
wipe = function(t) for k in pairs(t) do t[k] = nil end end
Enum = { CraftingOrderType = { Npc = 4, Personal = 3 } }
C_Timer = { After = noop }
C_CraftingOrders, C_TradeSkillUI = {}, {}
local E = setmetatable({ CO=CO, PT=PT }, {__index=_G})
HironCraftProfitCraftingOrdersEnv = E
dofile('ProfitHub/Core/Locales/enUS.lua')
dofile('ProfitHub/Core/Locales/ruRU.lua')
dofile('ProfitHub/Orders/Locale.lua')
PT.L = arg[2] == 'en' and PT.L_enUS or PT.L_ruRU
dofile('ProfitHub/Orders/Core/CraftingOrders_Core.lua')
local coreMethods = {}
for key, value in pairs(CO) do coreMethods[key] = value end
dofile('ProfitHub/Orders/CraftingOrders/QualityReagents.lua')
-- Keep the real visibility lifecycle, without importing unrelated crafting
-- checks into this presentation-only frame model.
local visibilityMethods = { UpdateControlPanelVisibility=true, IsOrderListOpen=true,
    IsOrderViewOpen=true, IsCraftingOrdersPageOpen=true }
for key in pairs(CO) do
    if not visibilityMethods[key] then CO[key] = coreMethods[key] end
end
dofile('ProfitHub/Orders/CraftingOrders/Rows.lua')
dofile('ProfitHub/Orders/CraftingOrders/ClassicTheme.lua')
dofile('ProfitHub/Orders/CraftingOrders/Panel.lua')
dofile('ProfitHub/Orders/CraftingOrders/CustomList.lua')
local CL = CO.CustomList
CO.IsEnabled = function() return true end
CO.UpdateControlPanel = noop
CO.GetQueueReagentMode = function() return 't1' end
CO.GetQueueConcMode = function() return 'off' end
CO.GetAutoFinishingLabel = function() return '+10' end
CO.GetSelectedProfessionExpansionLabel = function() return 'Midnight' end
CO.GetQueueMinProfitCopper = function() return nil end
CO.GetBagRewardValueCopper = function() return nil end
CO.GetKnowledgePointValueCopper = function() return nil end
CO.IsAutoQueueOnOpen = function() return true end
CO.IsAutoShoppingOnOpen = function() return true end

local page = frame('Frame')
page:SetSize(1060, 680)
page.orderType = Enum.CraftingOrderType.Personal
page.BrowseFrame = frame('Frame', page)
page.BrowseFrame:SetAllPoints()
local anchor = frame('Frame', page.BrowseFrame)
anchor:SetPoint('TOPLEFT', 260, -70)
anchor:SetPoint('BOTTOMRIGHT', -8, 8)
page.BrowseFrame.OrderList = anchor
CO:EnsureControlPanel(page)
local panel = CO.controlPanel
local container = CL:EnsureScrollFrame(page)
local personalCols = CL:ActiveCols()
assert(not personalCols.reward and not container.header.cols.reward:IsVisible(),
    'Personal tab still shows the Reward column')
local personalNameWidth = personalCols.name.w
assert(panel.titleFS.fontPath == PT.FONT, 'panel title lost the Cyrillic-capable font')
assert(panel.keyText.fontPath == PT.FONT, 'binding label lost the Cyrillic-capable font')
assert(panel.runActionButton.text.fontPath == PT.FONT, 'action label lost the Cyrillic-capable font')
CO:StyleClassicButton(panel.runActionButton, true)
assert(panel.runActionButton.text.fontPath == PT.FONT, 'native button styling reset the font')
local craft, queue = panel.classicPages.craft, panel.classicPages.queue
assert(craft.scroll:IsVisible() and not queue.scroll:IsVisible())
assert(panel.reagentSeg:GetParent() == craft.body)
assert(panel.bestQualityToggle:GetParent() == craft.body, 'tool escaped the scroll page')
assert(panel.minProfitInput:GetParent() == queue.body)
assert(panel.runActionButton:GetParent() == panel.footer)
for _, button in ipairs({panel.selectAllButton, panel.shopButton, panel.clearSelectedButton}) do
    assert(button:GetParent() == panel.queueActions and button:IsVisible(), 'common action requires a settings-tab click')
end
page.orderType = Enum.CraftingOrderType.Npc
CL:ResizeList(container)
local npcCols = CL:ActiveCols()
assert(npcCols.reward and container.header.cols.reward:IsVisible(), 'Patron tab lost the Reward column')
assert(personalNameWidth > npcCols.name.w, 'Personal Reward space was not returned to the item name')
CO:UpdateTabActionButton(page)
assert(panel.knowledgeButton:IsVisible(), 'knowledge action is not available on the main settings page')
assert(not panel.selectAllOrdersButton:IsVisible(), 'knowledge and select-all buttons overlap')
assert(panel.clearButton.template == 'UIPanelCloseButton' and not panel.clearButton.backdrop,
    'binding clear button lost the native square close style')
panel.classicTabs.queue:Click()
assert(queue.scroll:IsVisible() and not craft.scroll:IsVisible())
assert(panel.runActionButton:IsVisible(), 'switching settings hid the primary action')
assert(panel.shopButton:IsVisible() and panel.knowledgeButton:IsVisible(), 'switching settings hid common actions')
local calls = 0
CO.RunActiveRowAction = function() calls = calls + 1 end
panel.runActionButton:Click()
assert(calls == 1, 'action click no longer dispatches exactly one step')
panel.classicTabs.craft:Click()
assert(container.refreshButton.text.justify == 'CENTER' and container.refreshButton.text.justifyV == 'MIDDLE',
    'Refresh label is not centered horizontally and vertically')
local bx, by, bw, bh = bounds(container.refreshButton)
local tx, ty, tw, th = bounds(container.refreshButton.text)
assert(bx + bw/2 == tx + tw/2 and by + bh/2 == ty + th/2, 'Refresh label anchors are off-center')
anchor.ResultsText = frame('FontString', anchor)
anchor.ResultsText:SetAlpha(.8)
CL:HideBlizzardList(page)
assert(anchor.ResultsText:GetAlpha() == 0, 'duplicate Blizzard empty message remains visible')
CL:HideBlizzardList(page)
CL:Deactivate(page)
assert(anchor.ResultsText:GetAlpha() == .8, 'native empty-message alpha was not restored')
container:Show()
assert(container.countText.fontPath == PT.FONT, 'list labels lost the Cyrillic-capable font')
local row = CL:CreateRow(container.content, 1)
container.rows[1] = row
row:SetPoint('TOPLEFT', container.content, 'TOPLEFT', 0, 0)
row:SetPoint('TOPRIGHT', container.content, 'TOPRIGHT', 0, 0)
for _, width in ipairs({352, 431, 432, 511, 512, 600, 640, 792, 1020, 1250}) do
    anchor:SetWidth(width)
    -- Keep one horizontal anchor to simulate Blizzard windows of different widths.
    anchor.anchors.BOTTOMRIGHT = nil
    anchor:SetHeight(590)
    for _, compact in ipairs({true,false}) do
        CL:SetCompact(compact)
        CL:ResizeList(container)
        local rx,_,rw,rh = bounds(row)
        assert(rh == CL:RowHeight(), 'row anchors stretch its height')
        local ax,_,aw = bounds(row.action)
        local px = bounds(panel)
        local lx, ly, lw, lh = bounds(anchor)
        local cx, cy, cw, ch = bounds(container)
        assert(cx == lx and cy == ly and cw == lw and ch == lh, 'list no longer fills the original order area')
        assert(px == lx + lw + CO.CLASSIC_PANEL_GAP, 'settings panel is not outside the order list')
        assert(panel:GetWidth() == CO.CLASSIC_PANEL_WIDTH, 'external panel width changed')
        assert(ax >= rx and ax + aw <= rx + rw + .1, 'action outside the list')
        assert(rx + rw < px, 'list overlaps the settings pane')
        local cols = CL:ActiveCols()
        assert(cols.profit and row.profitBtn:IsVisible() and container.header.cols.profit:IsVisible(),
            'profit column disappeared at a narrow width')
        local ordered = {}
        for _, col in pairs(cols) do ordered[#ordered+1] = col end
        table.sort(ordered,function(a,b) return a.x < b.x end)
        for i=2,#ordered do assert(ordered[i-1].x+ordered[i-1].w <= ordered[i].x, 'columns overlap') end
    end
end
for _, height in ipairs({390,490,590}) do
    anchor:SetHeight(height)
    CO:AnchorControlPanelToOrderList(panel, page)
    local _, sy, _, sh = bounds(craft.scroll)
    local _, fy = bounds(panel.footer)
    local _, ay, _, ah = bounds(panel.queueActions)
    assert(sh > 0 and sy + sh < ay and ay + ah < fy, 'settings overlap the common actions or footer')
    for _, scrollPage in pairs(panel.classicPages) do
        CO:UpdateClassicSettingsScroll(scrollPage.scroll, scrollPage.body)
        assert(scrollPage.scroll.ScrollBar:IsShown() == (scrollPage.body:GetHeight() > scrollPage.scroll:GetHeight() + 1),
            'settings scrollbar does not match the content overflow')
    end
end
local savedHeight = craft.body:GetHeight()
craft.body:SetHeight(10)
craft.scroll:SetVerticalScroll(40)
CO:UpdateClassicSettingsScroll(craft.scroll, craft.body)
assert(not craft.scroll.ScrollBar:IsShown() and craft.scroll:GetVerticalScroll() == 0, 'empty settings retain scrollbar/offset')
craft.body:SetHeight(savedHeight)
local originalListWidth, originalPanelHeight = anchor:GetWidth(), panel:GetHeight()
panel.classicTabs.queue:Click()
panel.collapseButton:Click()
assert(E.GetDB().panelCollapsed == true and not panel:IsVisible(), 'collapse did not persist or hide the panel')
assert(panel.collapseButton.arrowTop.endPoint[3] == -2 and panel.collapseButton:IsVisible(), 'hidden panel cannot be restored')
assert(panel.collapseButton:GetParent() == page, 'toggle is hidden with the panel')
assert(not panel.helpButton:IsVisible() and not panel.titleFS:IsVisible(), 'hidden panel retains its header')
local toggleX, toggleY, toggleW, toggleH = bounds(panel.collapseButton)
local listX, listY, listW = bounds(anchor)
assert(toggleW == 20 and toggleH == 20 and not panel.collapseButton.template, 'toggle retained the oversized text-button template')
assert(toggleX >= listX and toggleX + toggleW <= listX + listW - 14 and toggleY + toggleH <= listY - 8,
    'toggle is not above the top-right corner inside the main window')
for _, texture in ipairs({panel.collapseButton:GetNormalTexture(), panel.collapseButton:GetPushedTexture(),
    panel.collapseButton:GetDisabledTexture(), panel.collapseButton:GetHighlightTexture()}) do
    local x,y,w,h = bounds(texture)
    assert(x == toggleX and y == toggleY and w == toggleW and h == toggleH, 'toggle skin extends beyond the button')
end
local borderExpectations = {
    borderTop = { 'TOPLEFT', 1, -1, 'TOPRIGHT', -1, -1 },
    borderBottom = { 'BOTTOMLEFT', 1, 1, 'BOTTOMRIGHT', -1, 1 },
    borderLeft = { 'TOPLEFT', 1, -1, 'BOTTOMLEFT', 1, 1 },
    borderRight = { 'TOPRIGHT', -1, -1, 'BOTTOMRIGHT', -1, 1 },
}
for key, expected in pairs(borderExpectations) do
    local border = panel.collapseButton[key]
    assert(border and border.kind == 'Line' and border.thickness == 1, key .. ' border is missing')
    assert(border.startPoint[1] == expected[1] and border.startPoint[2] == panel.collapseButton
        and border.startPoint[3] == expected[2] and border.startPoint[4] == expected[3],
        key .. ' start is outside the button')
    assert(border.endPoint[1] == expected[4] and border.endPoint[2] == panel.collapseButton
        and border.endPoint[3] == expected[5] and border.endPoint[4] == expected[6],
        key .. ' end is outside the button')
end
for _, line in ipairs({panel.collapseButton.arrowTop, panel.collapseButton.arrowBottom}) do
    assert(line.kind == 'Line' and line.thickness == 1.5, 'chevron relies on font metrics or rotated solid textures')
    assert(line.startPoint[1] == 'CENTER' and line.endPoint[1] == 'CENTER'
        and line.startPoint[2] == panel.collapseButton and line.endPoint[2] == panel.collapseButton,
        'chevron is not anchored to the button center')
    assert(line.startPoint[3] + line.endPoint[3] == 0, 'chevron is not centered horizontally')
    assert(math.abs(line.startPoint[4]) == 4 and line.endPoint[4] == 0, 'chevron escaped the centered icon area')
end
assert(panel.collapseButton.arrowTop.startPoint[4] + panel.collapseButton.arrowBottom.startPoint[4] == 0,
    'chevron is not centered vertically')
assert(not panel.shopButton:IsVisible() and not panel.runActionButton:IsVisible()
    and not queue.scroll:IsVisible() and not panel.debugToggle:IsVisible(), 'collapsed content leaked outside the header')
CO:UpdateTabActionButton(page)
CO:UpdateControlPanelVisibility(page)
assert(not panel.knowledgeButton:IsVisible() and not panel:IsVisible(), 'periodic refresh expanded the panel')
assert(anchor:GetWidth() == originalListWidth, 'collapse resized the order list')
panel.collapseButton:Click()
assert(panel.collapseButton.arrowTop.endPoint[3] == 2, 'chevron did not reverse when showing the panel')
assert(E.GetDB().panelCollapsed == false and panel:GetHeight() == originalPanelHeight, 'expand did not restore full height')
assert(queue.scroll:IsVisible() and not craft.scroll:IsVisible(), 'expand lost the selected settings tab')
assert(panel.runActionButton:IsVisible() and panel.shopButton:IsVisible(), 'expand lost actions')
panel.classicTabs.craft:Click()
E.GetDB().panelCollapsed = true
local reopenedPage = frame('Frame')
reopenedPage:SetSize(1060, 680)
CO:EnsureControlPanel(reopenedPage)
assert(not CO.controlPanel:IsVisible() and CO.controlPanel.collapseButton:IsVisible(),
    'a newly created panel ignored the saved collapse preference')
reopenedPage:Hide()
CO.controlPanel = panel
E.GetDB().panelCollapsed = false
page.BrowseFrame:Hide()
CO:UpdateControlPanelVisibility(page)
assert(not panel:IsVisible() and not panel.collapseButton:IsVisible(), 'toggle remains on the order-detail page')
page.BrowseFrame:Show()
CO:UpdateControlPanelVisibility(page)
assert(panel:IsVisible() and panel.collapseButton:IsVisible(), 'returning to the list lost the panel toggle')
local fallbackPage = frame('Frame')
fallbackPage:SetSize(1060, 680)
local fallbackPanel = frame('Frame', fallbackPage)
fallbackPanel:SetWidth(CO.CLASSIC_PANEL_WIDTH)
CO:AnchorControlPanelToOrderList(fallbackPanel, fallbackPage)
local fallbackX, _, fallbackWidth = bounds(fallbackPanel)
assert(fallbackX == 1060 + CO.CLASSIC_PANEL_GAP and fallbackWidth == CO.CLASSIC_PANEL_WIDTH,
    'panel fallback anchor moved inside the profession window')
fallbackPanel:Hide()
local icons = {}
for i=1,12 do
    local icon = frame('Button', row.reagentsBar)
    icon:SetSize(20,20)
    icons[i] = icon
end
row.reagentsBar:SetWidth(100)
CL:FitIconBar(row.reagentsBar, icons, 1, 'Reagents')
assert(row.reagentsBar.more:IsShown(), 'overflow is unreachable')
assert(row.reagentsBar.more:GetObjectType() == 'Frame' and not row.reagentsBar.more.template and not row.reagentsBar.more.backdrop,
    'reagent overflow is still styled as an action button')
local mx, _, mw = bounds(row.reagentsBar.more)
local count = 0
local previousRight
for _, icon in ipairs(icons) do
    if icon:IsShown() then
        count = count + 1
        local ix, _, iw = bounds(icon)
        assert(ix + iw <= mx, 'overflow label overlaps a reagent icon')
        if previousRight then assert(ix - previousRight >= 10, 'reagent quantities/badges have no breathing room') end
        previousRight = ix + iw
    end
end
assert(count == 2, 'too many icons entered the next column')
local moneyText = frame('FontString', row)
for _, width in ipairs({54,70,94}) do
    moneyText:SetWidth(width)
    for _, copper in ipairs({-32900,-27422800,1785000,123456789012}) do
        CL:SetMoneyText(moneyText, copper)
        assert(moneyText.wordWrap == false and moneyText.maxLines == 1, 'money can wrap into the next row')
        assert(moneyText:GetUnboundedStringWidth() <= width, 'money exceeds its column width')
        if copper < 0 then assert(moneyText:GetText():find('-',1,true), 'negative profit lost its sign') end
    end
end
moneyText:Hide()
CO.GetRowAction = function(_, _, order) return 'craft', 'Craft', order, true end
CO.activePageFrame = page
local rowCalls, focusCalls = 0, 0
CO.RunRowButtonAction = function() rowCalls = rowCalls + 1 end
CO.SetActiveRowButton = function() focusCalls = focusCalls + 1 end
for i=1,50 do CL:PopulateRow(row, {orderID=42, spellID=1234, customerName='Buyer'}) end
assert(row.action.actionEnabled == true, 'available action was drawn as unavailable')
row.action:Click()
assert(rowCalls == 1, 'row action did not dispatch exactly once')
row.scripts.OnEnter(row)
assert(focusCalls == 1, 'row refresh accumulated hover callbacks')

-- Selecting a lower row may repaint it, but must not promote it above the
-- list order (the recorded regression was the third row jumping to first).
local sortOrders = {
    {orderID=101, spellID=101, customerName='Buyer'},
    {orderID=102, spellID=102, customerName='Buyer'},
    {orderID=103, spellID=103, customerName='Buyer'},
}
local recipeNames = { [101]='Alpha', [102]='Bravo', [103]='Charlie' }
C_TradeSkillUI.GetRecipeInfo = function(spellID) return { name=recipeNames[spellID], learned=true } end
CL.GetOrders = function() return { sortOrders[1], sortOrders[2], sortOrders[3] } end
CO.selectedOrders = { ['103']=true }
CO.IsOrderSelected = function(_, orderID) return CO.selectedOrders[tostring(orderID)] == true end
CO.GetOrderProfitInfo = function() return { profit=0, reagentCost=0 } end
CO.GetOrderActionAvailabilitySortRank = function() return 1 end
page.orderType = Enum.CraftingOrderType.Personal
container._orderType = page.orderType
CL._sortColumn = nil
CL:Refresh(page)
assert(container.rows[1].action.orderID == 101 and container.rows[2].action.orderID == 102
    and container.rows[3].action.orderID == 103, 'checking an order moved it to the top')
CO.selectedOrders = {}
CL:Refresh(page)
assert(container.rows[1].action.orderID == 101 and container.rows[2].action.orderID == 102
    and container.rows[3].action.orderID == 103, 'unchecking an order changed its position')

dofile('ProfitHub/Orders/CraftingOrders/Actions.lua')
UIParent = frame('Frame')
for _, scale in ipairs({.65, 1, 1.3}) do
    page:SetScale(scale)
    CO:ShowRowProgressVisual(row.action, .5)
    local progress = CO.rowProgressOverlay
    assert(progress:GetParent() == row.action and progress:GetEffectiveScale() == row.action:GetEffectiveScale(),
        'craft progress does not inherit the action button scale')
    local px, py, pw, ph = bounds(progress)
    local ax, ay, aw, ah = bounds(row.action)
    assert(px == ax + 4 and px + pw == ax + aw - 4 and py + ph == ay + ah - 4,
        'craft progress escaped the button interior')
end
CO:HideRowProgressVisual(row.action)
page:SetScale(1)
print('Classic orders UI tests passed.')

if arg[1] == '--scene' then
    anchor:SetWidth(792); anchor:SetHeight(590)
    CO:AnchorControlPanelToOrderList(panel, page)
    CL:SetCompact(false); CL:ResizeList(container)
    panel.selectedText:SetText('Выбрано: 2')
    panel.keyText:SetText('Клавиша: Tab')
    panel.statusText:SetText('Отметьте заказы и нажмите «Действие».')
    panel.weeklyQuestIndicator.text:SetText('Квест')
    container.countText:SetText('Заказов: 3')
    for i, name in ipairs({"Farstrider’s Plated Bracers", "Silvermoon Agent’s Deflectors", "Martyr’s Bindings"}) do
        local demo = i == 1 and row or CL:CreateRow(container.content, i)
        demo:ClearAllPoints()
        demo:SetPoint('TOPLEFT', container.content, 'TOPLEFT', 0, -(i-1)*72)
        demo:SetPoint('TOPRIGHT', container.content, 'TOPRIGHT', 0, -(i-1)*72)
        CL:ApplyRowLayout(demo)
        demo.name:SetText(name)
        demo.customer:SetText(({'Visynell','Asuna','Blutix'})[i])
        demo.reward:Show(); demo.reward:ClearAllPoints()
        demo.reward:SetPoint('LEFT', demo.rewardBar, 'LEFT', 0, 0)
        demo.reward:SetWidth(82); demo.reward:SetText(({'6000 g','2000 g','1000 g'})[i])
        demo.concBtn.text:SetText(i == 2 and '84' or '—')
        demo.action.text:SetText(i == 1 and 'Крафт' or 'Взять')
    end
    if arg[3] == 'queue' then panel.classicTabs.queue:Click() end
    if arg[3] == 'collapsed' then panel.collapseButton:Click() end
    local function quote(value)
        return '"' .. tostring(value or ''):gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','') .. '"'
    end
    for _, f in ipairs(frames) do
        if f:IsVisible() then
            local x,y,w,h = bounds(f)
            if w > 0 and h > 0 then
                print('UI ' .. string.format('{"kind":%s,"x":%.1f,"y":%.1f,"w":%.1f,"h":%.1f,"text":%s,"size":%d,"justify":%s,"skin":%s}',
                    quote(f.kind),x,y,w,h,quote(f.text),f.fontSize or 12,quote(f.justify),quote(f.backdrop and 'inset' or (f.hironClassic and 'button' or ''))))
            end
        end
    end
end
