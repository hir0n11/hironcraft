-- Runs the actual overview and shared widgets, including narrow/wide layouts.
local model = dofile('scripts/UIFrameModel.lua')
local frames, methods, frame, bounds, noop = model.frames, model.methods, model.frame, model.bounds, model.noop
STANDARD_TEXT_FONT = 'Fonts/FRIZQT__.TTF'
unpack = unpack or table.unpack
SlashCmdList, StaticPopupDialogs = {}, {}
HironCraftProfit_Config = { designStyle='soulless', accountOverviewScale=1, accountOverviewWidth=1200, accountOverviewHeight=560 }
HironCraftProfit_DB = { accountOverview={chars={}}, charNotes={} }
local PT = { config=HironCraftProfit_Config, db=HironCraftProfit_DB, L={}, professionsReady=true,
    FONT='Interface\\AddOns\\HironCraft\\Workflow\\Core\\fonts\\default.ttf', SCALE_DEFAULT=1, SCALE_STEP=.1, SCALE_MAX=2.5 }
HironCraftProfit = PT
CreateFrame = function(kind, name, parent, template)
    local f = frame(kind, parent, template)
    f.name = name
    if template == 'UIPanelCloseButton' then f:SetSize(32,32) end
    return f
end
UIParent = frame('Frame'); UIParent:SetSize(1440,900)
GetLocale = function() return arg[2] == 'en' and 'enUS' or 'ruRU' end
UnitName = function() return 'Vamo' end
GetNormalizedRealmName = function() return 'Kazzak' end
GetCursorPosition = function() return 100,100 end
InCombatLockdown, IsAltKeyDown, IsMouseButtonDown = function() return false end, function() return false end, function() return false end
hooksecurefunc = noop
wipe = function(t) for k in pairs(t) do t[k]=nil end end
strsplit = function(_, s) return s:match('^([^%-]+)%-(.+)$') end
C_Timer = { After=noop, NewTicker=function() return {Cancel=noop} end }
C_Item, C_TradeSkillUI = {}, {}
time = function() return 1791457200 end
RAID_CLASS_COLORS = { MAGE={r=.25,g=.78,b=.92}, HUNTER={r=.67,g=.83,b=.45}, ROGUE={r=1,g=.96,b=.41} }
local names = {'Inscriper','Engineering','Alchemest','Enchantin','Hiron','Vamo','Favu','Mavu','Lavu'}
for i,name in ipairs(names) do
    HironCraftProfit_DB.accountOverview.chars[name..'-Kazzak'] = {class=i%2==0 and 'HUNTER' or 'MAGE'}
end
local filters = {profgear=true,c_df=false,c_tww=false,c_mid=true,zeal=true,kp_df=false,kp_tww=false,kp_mid=true,skin=false,dundun=false,dmf=true,tw=true}
local D = setmetatable({}, {__index=function() return function() return nil end end})
function D:GetColumnFilters() return filters end
function D:GetConcentration(_, exp)
    if exp == 'mid' then return {[164]={name='Blacksmithing',icon=136241,value=1000,max=1000}} end
end
function D:GetZeal() return {[164]={name='Blacksmithing',icon=136241,value=2170}} end
PT.AccountOverview_Data = D
dofile('Workflow/Core/UI/ClassicTheme.lua')
dofile('Workflow/Core/Locales/enUS.lua')
dofile('Workflow/Core/Locales/ruRU.lua')
PT.L = GetLocale() == 'enUS' and PT.L_enUS or PT.L_ruRU
dofile('Workflow/Core/UI/Dropdown.lua')
dofile('Workflow/Core/UI/Tooltip.lua')
dofile('Workflow/Core/UI/AccountOverview_UI.lua')
local UI = PT.AccountOverview_UI
UI:Refresh() -- unopened windows are safe
UI:Show()
local f = UI.frame
assert(f.backdrop.edgeFile:find('UI%-Tooltip%-Border'), 'overview lacks native frame border')
assert(f.title.color[1] == 1 and f.title.color[2] == .82, 'overview title is not gold')
assert(#f.content.rows == 9, 'character rows disappeared')
assert(PT:GetDesignStyle() == 'classic' and PT:IsFantasyDesign(), 'old skin is still selectable')
assert(HironCraftProfit_Config.designStyle == 'classic', 'legacy skin setting was not upgraded')
assert(PT.Tooltip.frame.backdrop.edgeSize == 16, 'shared tooltip still uses the old outline')
for _,width in ipairs({500,860,1200,1400}) do
    f:SetWidth(width)
    UI:RebuildHeader()
    UI:Refresh()
    local _,hy = bounds(f.header)
    local _,ty,_,th = bounds(f.title)
    local mx,my,mw,mh = bounds(f.manualOrderCheck)
    local nx,ny,nw,nh = bounds(f.noNewCharsCheck)
    local rx,ry,rw,rh = bounds(f.resetButton)
    local fx,fy,fw,fh = bounds(f.filterButton)
    assert(hy >= ty+th+30, 'table overlaps title or toolbar')
    assert(my+mh < hy and ny+nh < hy and ry+rh < hy, 'toolbar overlaps table')
    assert(mx+mw < nx and nx+nw+120 < fx and fx+fw < rx, 'toolbar controls overlap at width '..width)
    assert(#f.content.rows == 9 and f.content:GetWidth() > 0, 'resize lost the table')
end
f.manualOrderCheck:SetChecked(true); f.manualOrderCheck:Click()
assert(HironCraftProfit_Config.accountOverviewManualOrder, 'manual-order checkbox stopped working')
f.noNewCharsCheck:SetChecked(true); f.noNewCharsCheck:Click()
assert(HironCraftProfit_Config.accountOverviewNoNewChars, 'no-new-characters checkbox stopped working')
UI:EnsureDragVisuals()
assert(UI._dragGhost.backdrop.edgeSize == 16 and UI._dragLine.color[2] == .82, 'drag feedback retained the old skin')
UI:EditCharNote('Vamo-Kazzak')
assert(UI.noteEditDialog.backdrop.edgeSize == 16, 'note editor retained the old skin')
UI.noteEditDialog:Hide()
PT.Dropdown:Show({owner=f.filterButton, items={{text='Test',onClick=noop}}})
assert(PT.Dropdown.frame.backdrop.edgeSize == 16, 'dropdown retained the old skin')
PT.Dropdown:Hide()
-- Persisted fonts and cyclic tables survive the folder rename.
CreateFont = function() local font=frame('Font'); font.CopyFontObject=noop; return font end
dofile('Workflow/Core/UI/Fonts.lua')
local saved={font='Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\fonts\\GothamXNarrow-Medium.ttf',
    logo='Interface/AddOns/HironCraft/ProfitHub/Core/Media/logo_big.tga', text='customer text'}
saved.self=saved
PT.MigrateFontPaths(saved)
assert(saved.font == PT.FONT and saved.text == 'customer text' and saved.self == saved, 'asset path migration lost saved settings')
assert(saved.logo == 'Interface\\AddOns\\HironCraft\\Media\\HironCraftIcon.tga', 'saved legacy artwork was not migrated')
print('Classic overview UI tests passed ('..GetLocale()..').')

if arg[1] == '--scene' then
    f:SetSize(1200,560); f:ClearAllPoints(); f:SetPoint('TOPLEFT',UIParent,'TOPLEFT',20,-20)
    UI:RebuildHeader(); UI:Refresh()
    local function quote(v) return '"'..tostring(v or ''):gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','')..'"' end
    for _,widget in ipairs(frames) do
        if widget:IsVisible() then
            local x,y,w,h=bounds(widget)
            if w>0 and h>0 then
                local color=widget.color or widget.fill or {0,0,0,0}
                print('UI '..string.format('{"kind":%s,"x":%.1f,"y":%.1f,"w":%.1f,"h":%.1f,"text":%s,"size":%d,"justify":%s,"skin":%s,"texture":%s,"checked":%s,"color":[%.3f,%.3f,%.3f,%.3f]}',
                    quote(widget.kind),x,y,w,h,quote(widget.text),widget.fontSize or 12,quote(widget.justify),
                    quote(widget.backdrop and 'inset' or widget.template=='UIPanelButtonTemplate' and 'button' or widget.template=='UIPanelCloseButton' and 'close' or ''),
                    quote(widget.texture),tostring(widget.checked==true),color[1],color[2],color[3],(color[4] or 1)*(widget.alpha or 1)))
            end
        end
    end
end
