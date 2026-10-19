local queued, created, fonts = {}, 0, 0
local function noop() end
CreateFromMixins=function() return {} end
EnumUtil={MakeEnum=function(...)
    local values={};for i,key in ipairs({...}) do values[key]=i end;return values
end}
StaticPopupDialogs={}
local Scan={CONST={TEXT=setmetatable({},{__index=function(_,key) return key end}),CURRENT_VERSION='1.2.5-protocol'},
    LOCAL={GetText=function(_,value) return value end},
    Utils={onLoad=function(fn) queued[#queued+1]=fn end,GetCurrentProfessionIcon=function() return 42 end,
        ChatHistoryTooltip={new=function() return {} end}}}
assert(loadfile('Customer/OrderPage.lua'))('HironCraft',Scan)
local M=HironCraftScanCraftingOrderPageMixin
local function Frame(parent,level)
    local frame={parent=parent,level=level or 1,height=505}
    function frame:GetParent() return self.parent end
    function frame:GetFrameLevel() return self.level end
    function frame:SetFrameLevel(value) self.level=value end
    function frame:SetSize(width,height) self.width,self.height=width,height end
    function frame:SetHeight(height) self.height=height end
    function frame:GetHeight() return self.height end
    function frame:EnableMouse(on) self.mouse=on end
    function frame:ClearAllPoints() self.anchor=nil end
    function frame:SetPoint(...) self.anchor={...} end
    function frame:Show() self.shown=true end
    function frame:Hide() self.shown=false end
    function frame:CreateFontString(_,layer,template)
        fonts=fonts+1
        local label={parent=self,layer=layer,template=template}
        function label:GetFont() return 'Fonts/test.ttf',12,'OUTLINE' end
        function label:SetFont(path,size,flags) self.font,self.size,self.flags=path,size,flags end
        function label:SetTextColor(...) self.colour={...} end
        function label:SetShadowOffset(x,y) self.shadow={x,y} end
        function label:SetJustifyH(value) self.justify=value end
        function label:SetWordWrap(on) self.wrap=on end
        function label:SetAllPoints(target) self.target=target end
        function label:SetText(value) self.text=value end
        function label:Show() self.shown=true end
        return label
    end
    return frame
end
CreateFrame=function(kind,name,parent)
    assert(kind=='Frame' and name==nil)
    created=created+1;return Frame(parent)
end
local function Page()
    local page=setmetatable(Frame(nil,100),{__index=M})
    page.BrowseFrame=Frame(page,120)
    page.BrowseFrame.OrderList=Frame(page.BrowseFrame)
    page.BrowseFrame.LeftPanel=Frame(page.BrowseFrame)
    page.NineSlice=Frame(page,150)
    page.TitleContainer=Frame(page,130)
    return page
end
HironCraft={version='9.8.7-loaded'}
local metadataCalls=0
C_AddOns={GetAddOnMetadata=function(name,key)
    assert(name=='HironCraft' and key=='Version');metadataCalls=metadataCalls+1;return '9.8.8-metadata'
end}
local page=Page()
page:UpdateVersionLabel()
local holder,label=page.hironVersionFrame,page.hironVersionLabel
assert(label.text=='HironCraft 9.8.7-loaded' and metadataCalls==0,'label did not use the loaded addon version')
assert(holder:GetParent()==page and label.parent==holder and holder.mouse==false)
assert(holder:GetFrameLevel()==160 and holder.shown and label.shown,'native decoration can cover the version')
assert(holder.anchor[1]=='TOPLEFT' and holder.anchor[2]==page and holder.anchor[3]=='TOPLEFT'
    and holder.anchor[4]==84 and holder.anchor[5]==-8,'label is not beside the portrait in the title strip')
assert(holder.width==170 and holder.height==14 and label.size==10 and label.flags==''
    and label.wrap==false and label.justify=='LEFT','label is not small plain single-line text')
assert(label.colour[1]>=0.7 and label.shadow[1]==0 and label.shadow[2]==0)
for _=1,5 do page:UpdateVersionLabel() end
assert(created==1 and fonts==1 and page.hironVersionFrame==holder and page.hironVersionLabel==label,
    'reopening/refreshing duplicated the version label')
page.NineSlice.level=500
page:UpdateVersionLabel();assert(holder.level==510,'label was left under a rebuilt/raised border')
-- Exercise the real XML lifecycle entry points, not only the helper.
local resets,renders=0,0
page.ResetSortOrder=function(self) assert(self.hironVersionLabel.shown);resets=resets+1 end
page.InitOrderListTable=noop;page.SetupOrderListTable=noop
page:OnLoad();queued[#queued]()
assert(resets==1 and page.BrowseFrame.OrderList.height==page.BrowseFrame.LeftPanel.height)
HironCraftScanScannerMenu={ClearPulses=noop}
C_Timer={After=noop}
page.ShowGeneric=function() renders=renders+1 end
page.SetPortraitToAsset=function(_,icon) assert(icon==42) end
page:OnShow();assert(renders==1 and created==1 and fonts==1)
holder:Hide();label.shown=false
page.ShowGeneric=function() error('injected unrelated list failure') end
assert(not pcall(page.OnShow,page) and holder.shown and label.shown,
    'an order-list initialization error prevented the version from appearing')
-- Metadata is a fallback; the scanner wire-protocol version is never shown.
HironCraft=nil
local fallback=Page();fallback:UpdateVersionLabel()
assert(fallback.hironVersionLabel.text=='HironCraft 9.8.8-metadata' and metadataCalls==1)
C_AddOns=nil
GetAddOnMetadata=function(name,key) assert(name=='HironCraft' and key=='Version');return '9.8.9-legacy' end
fallback:UpdateVersionLabel();assert(fallback.hironVersionLabel.text=='HironCraft 9.8.9-legacy')
GetAddOnMetadata=function() error('metadata unavailable') end
fallback:UpdateVersionLabel();assert(fallback.hironVersionLabel.text=='HironCraft ?')
GetAddOnMetadata=nil
fallback:UpdateVersionLabel();assert(fallback.hironVersionLabel.text=='HironCraft ?')
print('Scanner version passed (loaded version, metadata fallbacks, title-corner anchor, plain font, layering, lifecycle/reopen reuse and independence from order rows/protocol version).')
