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
    return f
end
function methods:CreateFontString(_, _, template) return frame('FontString', self, template) end
function methods:CreateTexture() return frame('Texture', self) end
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
function methods:SetFont(_, size) self.fontSize = size end
function methods:SetFontObject() self.fontSize = 12 end
function methods:SetJustifyH(value) self.justify = value end
function methods:GetStringWidth() return #(self.text or '') * 6 end
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
for _, name in ipairs({'RegisterForClicks','SetTexCoord','SetRotation','SetWordWrap','SetMaxLines','SetAutoFocus','SetMaxLetters','SetCursorPosition','SetTextInsets','SetJustifyV','EnableMouse','EnableMouseWheel','LockHighlight','UnlockHighlight','SetStatusBarTexture','SetStatusBarColor','SetMinMaxValues','SetValue','RegisterEvent','SetDesaturated','SetAlpha','SetVertexColor','Enable','SetBlendMode'}) do methods[name] = noop end

local CO, PT = {}, { L = {} }
PT.CraftingOrders = CO
HironCraftProfit = PT
STANDARD_TEXT_FONT = 'Fonts/FRIZQT__.TTF'
SlashCmdList = {}
GameFontNormalSmall, GameFontNormal, GameFontHighlightSmall = {}, {}, {}
CreateFrame = function(kind, _, parent, template) return frame(kind, parent, template) end
GetLocale = function() return arg[2] == 'en' and 'enUS' or 'ruRU' end
wipe = function(t) for k in pairs(t) do t[k] = nil end end
Enum = { CraftingOrderType = { Npc = 4, Personal = 3 } }
C_Timer = { After = noop }
local E = setmetatable({ CO=CO, PT=PT, CreateBackdrop=noop, ApplyFont=function(f,size) f:SetFont('',size) end,
    T=function(key,fallback) return PT.L[key] or fallback end,
    HideStyledTooltip=noop,
}, {__index=_G})
HironCraftProfitCraftingOrdersEnv = E
dofile('ProfitHub/Core/Locales/enUS.lua')
dofile('ProfitHub/Core/Locales/ruRU.lua')
dofile('ProfitHub/Orders/Locale.lua')
PT.L = arg[2] == 'en' and PT.L_enUS or PT.L_ruRU
dofile('ProfitHub/Orders/CraftingOrders/Rows.lua')
dofile('ProfitHub/Orders/CraftingOrders/ClassicTheme.lua')
dofile('ProfitHub/Orders/CraftingOrders/Panel.lua')
dofile('ProfitHub/Orders/CraftingOrders/CustomList.lua')
CO.IsEnabled = function() return true end
CO.UpdateControlPanel, CO.UpdateControlPanelVisibility = noop, noop
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
local craft, queue = panel.classicPages.craft, panel.classicPages.queue
assert(craft.scroll:IsVisible() and not queue.scroll:IsVisible())
assert(panel.reagentSeg:GetParent() == craft.body)
assert(panel.bestQualityToggle:GetParent() == craft.body, 'tool escaped the scroll page')
assert(panel.minProfitInput:GetParent() == queue.body)
assert(panel.runActionButton:GetParent() == panel.footer)
panel.classicTabs.queue:Click()
assert(queue.scroll:IsVisible() and not craft.scroll:IsVisible())
assert(panel.runActionButton:IsVisible(), 'switching settings hid the primary action')
local calls = 0
CO.RunActiveRowAction = function() calls = calls + 1 end
panel.runActionButton:Click()
assert(calls == 1, 'action click no longer dispatches exactly one step')
panel.classicTabs.craft:Click()
local CL = CO.CustomList
local container = CL:EnsureScrollFrame(page)
local row = CL:CreateRow(container.content, 1)
container.rows[1] = row
row:SetPoint('TOPLEFT', container.content, 'TOPLEFT', 0, 0)
row:SetPoint('TOPRIGHT', container.content, 'TOPRIGHT', 0, 0)
for _, width in ipairs({640, 792, 1020, 1250}) do
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
        assert(ax >= rx and ax + aw <= rx + rw + .1, 'action outside the list')
        assert(rx + rw < px, 'list overlaps the settings pane')
        local cols = CL:ActiveCols()
        local ordered = {}
        for _, col in pairs(cols) do ordered[#ordered+1] = col end
        table.sort(ordered,function(a,b) return a.x < b.x end)
        for i=2,#ordered do assert(ordered[i-1].x+ordered[i-1].w <= ordered[i].x, 'columns overlap') end
    end
end
for _, height in ipairs({390,490,590}) do
    anchor:SetHeight(height)
    local _, sy, _, sh = bounds(craft.scroll)
    local _, fy = bounds(panel.footer)
    assert(sh > 0 and sy + sh < fy, 'settings overlap the persistent footer')
end
local icons = {}
for i=1,12 do
    local icon = frame('Button', row.reagentsBar)
    icon:SetSize(20,20)
    icons[i] = icon
end
row.reagentsBar:SetWidth(82)
CL:FitIconBar(row.reagentsBar, icons, 1, 'Reagents')
assert(row.reagentsBar.more:IsShown(), 'overflow is unreachable')
local count = 0
for _, icon in ipairs(icons) do if icon:IsShown() then count = count + 1 end end
assert(count == 2, 'too many icons entered the next column')
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
print('Classic orders UI tests passed.')

if arg[1] == '--scene' then
    anchor:SetWidth(792); anchor:SetHeight(590)
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
