-- Count real constructors/refresh paths. Timings/FPS still require an in-game
-- capture; the mock keeps allocated objects alive like native frame objects.
local noop=function() end
local objects,frames,timers={}, {}, {}
local now=0
local function RunTimers()
    local guard=0
    while #timers>0 do
        table.sort(timers,function(a,b) return a.at<b.at end)
        local timer=table.remove(timers,1)
        now=timer.at;timer.fn();guard=guard+1
        assert(guard<1000,'Refresh timers did not settle')
    end
end
local function Mock(kind,parent)
    local o={kind=kind,parent=parent,children={},regions={},scripts={},events={},points={},
        shown=true,width=1400,height=500,scale=1,level=1}
    objects[#objects+1]=o
    if parent then
        local list=(kind=='Texture' or kind=='FontString') and parent.regions or parent.children
        list[#list+1]=o
    end
    local m={}
    function m:SetScript(k,fn) self.scripts[k]=fn end
    function m:GetScript(k) return self.scripts[k] end
    function m:HookScript(k,fn)
        local old=self.scripts[k]
        self.scripts[k]=function(...) if old then old(...) end;fn(...) end
    end
    function m:RegisterEvent(k) self.events[k]=true end
    function m:Show() local was=self.shown;self.shown=true;if not was and self.scripts.OnShow then self.scripts.OnShow(self) end end
    function m:Hide() local was=self.shown;self.shown=false;if was and self.scripts.OnHide then self.scripts.OnHide(self) end end
    function m:SetShown(on) if on then self:Show() else self:Hide() end end
    function m:IsShown() return self.shown end
    function m:IsVisible() return self.shown end
    function m:GetChildren() return unpack(self.children) end
    function m:GetRegions() return unpack(self.regions) end
    function m:GetObjectType() return self.kind end
    function m:SetParent(p)
        if self.parent then
            for i,v in ipairs(self.parent.children) do if v==self then table.remove(self.parent.children,i);break end end
        end
        self.parent=p;if p then p.children[#p.children+1]=self end
    end
    function m:GetParent() return self.parent end
    function m:SetSize(w,h) self.width,self.height=w,h end
    function m:SetWidth(w) self.width=w end
    function m:SetHeight(h) self.height=h end
    function m:GetWidth() return self.width end
    function m:GetHeight() return self.height end
    function m:SetScale(s) self.scale=s end
    function m:GetScale() return self.scale end
    function m:GetEffectiveScale() return self.scale end
    function m:SetPoint(k,...) self.points[k]={...} end
    function m:ClearAllPoints() self.points={} end
    function m:GetPoint() return 'TOPLEFT',UIParent,'TOPLEFT',0,0 end
    function m:GetLeft() return 0 end
    function m:GetTop() return 500 end
    function m:GetRight() return self.width end
    function m:GetBottom() return 0 end
    function m:GetCenter() return 500,300 end
    function m:SetFrameLevel(v) self.level=v end
    function m:GetFrameLevel() return self.level end
    function m:GetVerticalScroll() return 0 end
    function m:SetText(v) self.text=v end
    function m:GetText() return self.text end
    function m:GetStringWidth() return #tostring(self.text or '')*6 end
    function m:GetFont() return 'test.ttf',11,'' end
    function m:SetTextColor(...) self.textColor={...} end
    function m:SetAtlas(v) self.atlas=v end
    function m:GetAtlas() return self.atlas end
    function m:SetTexture(v) self.texture=v end
    function m:GetTexture() return self.texture end
    function m:CreateFontString() return Mock('FontString',self) end
    function m:CreateTexture() return Mock('Texture',self) end
    function m:GetChecked() return self.checked end
    function m:SetChecked(v) self.checked=v end
    return setmetatable(o,{__index=function(_,k)
        if m[k] then return m[k] end
        if k:match('^%u') then return noop end
    end})
end
function CreateFrame(kind,name,parent,template)
    local f=Mock(kind,parent);frames[#frames+1]=f
    if template=='UIPanelButtonTemplate' then f.Text=Mock('FontString',f) end
    if name then _G[name]=f end
    return f
end
function wipe(t) for k in pairs(t) do t[k]=nil end end
function GetTime() return now end
function time() return 1792000000+now end
function InCombatLockdown() return false end
function hooksecurefunc(owner,key,callback)
    if type(owner)=='string' then callback,key,owner=key,owner,_G end
    local original=owner[key] or noop
    owner[key]=function(...) local result=original(...);callback(...);return result end
end
function IsInInstance() return false end
function UnitName() return 'Current' end
function GetNormalizedRealmName() return 'Realm' end
function UnitClass() return 'Mage','MAGE' end
function GetScreenHeight() return 1080 end
function GetScreenWidth() return 1920 end
function strsplit(separator,text)
    local first,last=text:find(separator,1,true)
    if not first then return text end
    return text:sub(1,first-1),text:sub(last+1)
end
UIParent=Mock('Frame');UISpecialFrames={};SlashCmdList={};StaticPopupDialogs={}
GameTooltip=Mock('Tooltip')
C_Timer={After=function(delay,fn) timers[#timers+1]={at=now+delay,fn=fn} end}
C_Item={RequestLoadItemDataByID=noop,GetItemIconByID=function() return 134400 end}
HironCraftProfit={L={},Tracker={ToggleTrackedItem=function(_,item) item.isTracked=not item.isTracked end},
    Tooltip={Clear=noop,AddLine=noop,ShowAtCursor=noop}}
assert(loadfile('Workflow/Core/Core/Core.lua'))('HironCraft')
assert(loadfile('Workflow/Core/Core/Data.lua'))('HironCraft')
assert(loadfile('Workflow/Core/UI/ClassicTheme.lua'))()
assert(loadfile('Workflow/Core/UI/UI.lua'))()
local PT=HironCraftProfit
local available,required,markup=true,4,'icon'
local prof={id=1,name='Profession',index=1,entries={},expanded=true}
local item={profession=prof,itemId=123,index=1,GetName=function() return 'Item' end,
    GetIcon=function() return 134400 end,GetType=function() return 2 end,
    MeetRequirements=function() return available end,GetRemainingKnowledgePoints=function() return required end,
    GetCategoryIcon=function() return markup end}
prof.entries={item}
local reads,names=0,0
PT.GetProfessions=function() reads=reads+1;return {[1]=prof} end
PT.UpdateAllProfessionNames=function() names=names+1 end
PT:RefreshUI()
RunTimers()
local header,row=PT.UI.headers[1],PT.UI.itemRows[1]
assert(header and row and row._ahuiItem==item)
local allocated=#objects
for i=1,100 do PT:RefreshUI() end
assert(#objects==allocated,'Profession refresh allocated new frames/regions')
assert(PT.UI.headers[1]==header and PT.UI.itemRows[1]==row,'Cached row identity changed')
row.scripts.OnClick()
assert(item.isTracked,'Reused item click lost its target')
available=false;required=2;markup=nil;PT:RefreshUI()
assert(row.text.textColor[2]==0.2 and not row.typeFS:IsShown())
available=true;required=0;PT:RefreshUI()
assert(row.text.textColor[2]==1 and row.check:IsShown(),'Reused row kept old requirements state')
prof.expanded=false;PT:RefreshUI();assert(not row:IsShown())
header.scripts.OnClick();RunTimers();assert(row:IsShown(),'Header did not reopen cached item row')

-- One event burst, including all three listeners, produces one current pass
-- and one shared late-data retry. A hidden UI does not add another data read.
PT.config.showProfessionsWindow=false
PT:UpdateVisibility()
reads,names=0,0
for burst=1,25 do
    for _,f in ipairs(frames) do
        if f.events.SKILL_LINES_CHANGED and f.scripts.OnEvent then f.scripts.OnEvent(f,'SKILL_LINES_CHANGED') end
    end
end
RunTimers()
assert(reads==2 and names==2,'Event burst was not coalesced: '..reads..'/'..names)
local before=reads
for i=1,100 do PT:RefreshUI() end
assert(reads==before,'Hidden UI still reads profession data')
PT.config.showProfessionsWindow=true;PT:UpdateVisibility();RunTimers()
assert(PT.UI.headers[1]==header and row:IsShown(),'Hidden data did not refresh on show')

-- Real account overview constructors: rows/cells/header columns are reused
-- through sorting, column filtering, resize and character removal/replacement.
local filters={}
PT.AccountOverview_Data={GetColumnFilters=function() return filters end,
    GetTimewalkingStatus=function() return nil end}
PT.professionsReady=true
HironCraftProfit_DB.accountOverview={chars={['Alt-Realm']={},['Current-Realm']={}}}
assert(loadfile('Workflow/Core/UI/AccountOverview_UI.lua'))()
local AO=PT.AccountOverview_UI
AO:Show();RunTimers()
local f=AO.frame
f:SetWidth(1400);AO:RebuildHeader();AO:Refresh()
local first,second=f.content.rows[1],f.content.rows[2]
assert(first and second and first~=second)
local oldHeader=f.header
allocated=#objects
for i=1,100 do AO:Refresh();AO:RebuildHeader() end
assert(#objects==allocated,'Account overview leaked rows/header objects')
assert(f.header==oldHeader and f.content.rows[1]==first and f.content.rows[2]==second)
filters.profgear=false;AO:RebuildHeader();AO:Refresh()
assert(not first.cells.profgear and not first.allCells.profgear:IsShown())
filters.profgear=true;AO:RebuildHeader();AO:Refresh()
assert(first.cells.profgear==first.allCells.profgear and first.cells.profgear:IsShown())
assert(#objects==allocated,'Showing a previous column allocated another cell')
f:SetWidth(500);AO:RebuildHeader();AO:Refresh()
f:SetWidth(1400);AO:RebuildHeader();AO:Refresh()
assert(#objects==allocated,'Resize did not reuse cells')
AO:SetSortColumn('char');AO:SetSortColumn('char')
local afterArrows=#objects
for i=1,30 do AO:SetSortColumn('char') end
assert(#objects==afterArrows,'Sort arrows were recreated')
HironCraftProfit_DB.accountOverview.chars['Alt-Realm']=nil
AO:Refresh();assert(#f.content.rows==1 and not second:IsShown())
HironCraftProfit_DB.accountOverview.chars['Other-Realm']={}
AO:Refresh();assert(#f.content.rows==2 and f.content.rows[2]==second)
assert(f.content.rows[1].charKey~=f.content.rows[2].charKey,'Reused rows kept an old character')
print('Performance UI: stable allocations, current callbacks/state, hidden UI, coalesced bursts, columns, resize and sorting passed')
