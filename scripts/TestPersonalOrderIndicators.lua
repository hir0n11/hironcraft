local frames, named, sounds = {}, {}, 0
local function Make(name)
    local f = { scripts = {}, shown = true, name = name }
    frames[#frames + 1] = f
    if name then named[name] = f end
    function f:RegisterEvent() end
    function f:SetScript(key, fn) self.scripts[key] = fn end
    function f:HookScript(key, fn) self.scripts[key] = fn end
    function f:Show() self.shown=true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function f:Hide() self.shown=false end
    function f:SetShown(on) if on then self:Show() else self:Hide() end end
    function f:SetSize(w,h) self.w,self.h=w,h end
    function f:SetWidth(w) self.w=w end
    function f:SetScale(s) self.scale=s end
    function f:SetText(text) self.text=text end
    function f:SetTexture(icon) self.texture=icon end
    function f:SetParent(parent) self.parent=parent end
    function f:GetStringWidth() return #(tostring(self.text or '')) * 7 end
    function f:GetWidth() return self.w end
    function f:SetPoint(...) self.point={...} end
    function f:CreateTexture() return Make() end
    function f:CreateFontString() return Make() end
    for _, key in ipairs({'SetMovable','SetClampedToScreen','SetFrameStrata','ClearAllPoints',
        'SetAllPoints','SetTexCoord','RegisterForDrag','StartMoving','StopMovingOrSizing'}) do f[key]=function() end end
    return f
end
CreateFrame=function(_,name) return Make(name) end
UIParent, Minimap = {}, {}
local original=Make()
MinimapCluster={IndicatorFrame={CraftingOrderFrame=original}}
GetProfessions=function() return 2,4 end
GetProfessionInfo=function(index) if index==2 then return 'Blacksmithing',100 end return 'Tailoring',200 end
local infos={{profession=1,professionName='Blacksmithing',numPersonalOrders=2}}
C_CraftingOrders={GetPersonalOrdersInfo=function() return infos end}
local Scan={DB={settings={}},LOCAL={GetText=function(_,s) return s end},
    Notifications={Alert=function(kind) assert(kind=='order'); sounds=sounds+1 end}}
assert(loadfile('Customer/PersonalOrdersIndicator.lua'))('HironCraft',Scan)
local event=frames[#frames].scripts.OnEvent
event(nil,'PLAYER_ENTERING_WORLD')
local indicator=named.HironCraftPersonalOrderIndicators
assert(indicator.shown and not original.shown and sounds==0)
local iconRows={}
for _,f in ipairs(frames) do if f.info then iconRows[#iconRows+1]=f end end
assert(#iconRows==1 and iconRows[1].count.text==2 and iconRows[1].icon.texture==100)
infos={{profession=1,professionName='Blacksmithing',numPersonalOrders=3},
    {profession=2,professionName='Tailoring',numPersonalOrders=1}}
event(nil,'CRAFTINGORDERS_UPDATE_PERSONAL_ORDER_COUNTS')
assert(sounds==1 and indicator.w==88)
assert(iconRows[1].count.point[2]==iconRows[1].icon and iconRows[1].count.point[3]=='RIGHT',
    'count still overlaps the profession icon')
assert(indicator.parent==MinimapCluster.IndicatorFrame and indicator.layoutIndex==2,
    'indicator did not use the stock crafting-order slot')
event(nil,'CRAFTINGORDERS_UPDATE_PERSONAL_ORDER_COUNTS')
assert(sounds==1,'duplicate count event sounded again')
infos={{profession=2,professionName='Tailoring',numPersonalOrders=1}}
event(nil,'CRAFTINGORDERS_UPDATE_PERSONAL_ORDER_COUNTS')
assert(sounds==1 and indicator.w==40, 'fulfilled/rejected orders did not disappear')
Scan.DB.settings.personal_order_icons=false
Scan.PersonalOrdersIndicator.Update(true)
assert(original.shown and not indicator.shown,'stock indicator was not restored')
Scan.DB.settings.personal_order_icons=true
Scan.PersonalOrdersIndicator.Update(true)
original:Show()
assert(not original.shown,'stock event revived the duplicate hammer')
infos={}
event(nil,'CRAFTINGORDERS_UPDATE_PERSONAL_ORDER_COUNTS')
assert(not indicator.shown)
Scan.DB.settings.personal_order_position={x=123,y=456}
Scan.DB.settings.personal_order_scale=1.5
Scan.PersonalOrdersIndicator.Position()
assert(indicator.scale==1.5 and indicator.point[4]==123)
Scan.PersonalOrdersIndicator.Reset()
assert(not Scan.DB.settings.personal_order_position and indicator.parent==MinimapCluster.IndicatorFrame)
infos={{profession=1,professionName='Blacksmithing',numPersonalOrders=123}}
Scan.PersonalOrdersIndicator.Update(true)
assert(indicator.w==49, 'three-digit count was clipped or placed over the icon')
print('Personal order indicators passed (current-character server counts, icons, zero counts, sound dedup, original hammer, position/scale).')
