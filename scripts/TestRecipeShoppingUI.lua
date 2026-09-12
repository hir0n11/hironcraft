-- Real popup/control callbacks with a small WoW widget harness.
local function noop() end
local widgets, messages, lastMaterials = {}, {}, {}
local function Widget(kind)
    local w={kind=kind,scripts={},points={},shown=true,enabled=true,scroll=0,text='',dirty=false}
    widgets[#widgets+1]=w
    function w:SetScript(event,fn) self.scripts[event]=fn end
    function w:Run(event,...) if self.scripts[event] then self.scripts[event](self,...) end end
    function w:SetPoint(...) self.points[#self.points+1]={...} end
    function w:ClearAllPoints() self.points={} end
    function w:SetSize(width,height) self.width,self.height=width,height end
    function w:SetWidth(width) self.width=width end
    function w:SetHeight(height) self.height=height end
    function w:SetText(text) self.text=tostring(text); self:Run('OnTextChanged',false) end
    function w:GetText() return self.text end
    function w:SetNumber(number) self:SetText(number) end
    function w:GetNumber() return tonumber(self.text) or 0 end
    function w:SetAutoFocus(value) self.autoFocus=value end
    function w:SetFocus() self.focused=true end
    function w:ClearFocus()
        if self.focused then self.focused=false; self:Run('OnEditFocusLost') end
    end
    function w:Show() self.shown=true end
    function w:Hide() if self.shown then self.shown=false; self:Run('OnHide') end end
    function w:IsShown() return self.shown end
    function w:SetShown(value) if value then self:Show() else self:Hide() end end
    function w:SetEnabled(value) self.enabled=value end
    function w:Enable() self.enabled=true end
    function w:Disable() self.enabled=false end
    function w:SetChecked(value) self.checked=value end
    function w:GetChecked() return self.checked end
    function w:SetVerticalScroll(value) self.scroll=value end
    function w:GetVerticalScroll() return self.scroll end
    function w:CreateFontString() return Widget('FontString') end
    function w:GetFontString() self.font=self.font or Widget('FontString'); return self.font end
    function w:GetFrameLevel() return 5 end
    function w:SetScrollChild(child) self.scrollChild=child end
    function w:SetClampedToScreen(value) self.clamped=value end
    function w:SetFrameStrata(value) self.strata=value end
    function w:SetPushedTextOffset(x,y) self.pushedOffset={x,y} end
    function w:SetMovable(value) self.movable=value end
    for _,method in ipairs({'SetFrameLevel','SetNumeric','SetMaxLetters','SetJustifyH','SetCursorPosition',
        'RegisterForClicks','SetTextColor','SetWordWrap','EnableMouse','SetBackdrop','SetBackdropColor',
        'SetBackdropBorderColor','RegisterForDrag','StartMoving','StopMovingOrSizing'}) do w[method]=noop end
    return w
end
CreateFrame=function(kind,name,parent)
    local frame=Widget(kind); frame.parent=parent
    if name then _G[name]=frame end
    return frame
end
HironCraftProfit={L={}}
HironCraftProfit_DB={}
UIErrorsFrame={AddMessage=function(_,msg) messages[#messages+1]=msg end}
GameTooltip={GetOwner=function(self) return self.owner end,SetOwner=function(self,owner) self.owner=owner end,
    SetText=noop,AddLine=noop,ClearLines=noop,Show=noop,Hide=noop}
Enum={CraftingReagentType={Basic=1},TradeskillRecipeType={Item=1,Salvage=2},ItemClass={Recipe=9}}
C_Item={GetItemCount=function(id) return id==101 and 3 or 0 end}
C_TradeSkillUI={GetItemReagentQualityByItemInfo=function(id) return id==101 and 1 or 2 end,
    GetRecipeSourceText=function() return 'World drop' end}
function GetItemInfo(id) return 'Material '..id end
function wipe(t) for k in pairs(t) do t[k]=nil end end
HironCraftProfit.ShoppingList={CreateTemporaryImportedList=function(_,_,materials)
    lastMaterials=materials; return true,'created'
end}
ProfessionsFrame=Widget('Frame')
ProfessionsFrame.CraftingPage=Widget('Frame')
local recipeInfo={recipeID=1,learned=true,name='Test recipe'}
local transaction={GetRecipeSchematic=function() return {recipeType=1,reagentSlotSchematics={
    {slotIndex=1,quantityRequired=10,reagentType=1,reagents={{itemID=101},{itemID=102}}},
}} end,IsSlotRequired=function() return true end}
local form=Widget('Frame')
form.GetRecipeInfo=function() return recipeInfo end
form.GetTransaction=function() return transaction end
ProfessionsFrame.CraftingPage.SchematicForm=form
dofile('ProfitHub/Shop/Core/RecipeShopping.lua')
dofile('ProfitHub/Shop/UI/RecipeShopping_UI.lua')
local RS=HironCraftProfit.RecipeShopping
RS:OnRecipeSelected()
RS.controls.button:Run('OnClick','LeftButton')
local frame=assert(RS.planFrame,'adding a recipe did not create the popup')
assert(frame:IsShown() and frame.width==360 and frame.height<=300 and frame.clamped and frame.movable,
    'popup is not compact/movable/clamped')
assert(UISpecialFrames[1]=='HironCraftRecipeShoppingPlan','popup cannot close with Escape')
for _,widget in ipairs(widgets) do
    if widget.kind=='EditBox' then assert(widget.autoFocus==false and not widget.focused,'popup stole keyboard focus') end
end
local id=RS.plan.entries[1].id
local row=frame.rows[id]
assert(row.name.text=='Test recipe' and row.quantity:GetNumber()==1 and lastMaterials[1].quantity==7)
row.plus:Run('OnClick')
assert(row.quantity:GetNumber()==2 and RS.plan.totalCrafts==2 and lastMaterials[1].quantity==17)
row.quantity:SetFocus()
row.quantity:SetText('5'); row.quantity:Run('OnTextChanged',true)
row.quantity:Run('OnEnterPressed')
assert(RS.plan.totalCrafts==5 and row.quantity:GetNumber()==5 and lastMaterials[1].quantity==47)
row.quantity:SetFocus()
row.quantity:SetText(''); row.quantity:Run('OnTextChanged',true)
row.quantity:ClearFocus()
assert(RS.plan.totalCrafts==5 and row.quantity:GetNumber()==5,'blank quantity deleted a recipe')
row.quantity:SetText('3'); row.quantity:Run('OnTextChanged',true)
row.quantity:Run('OnEscapePressed')
assert(RS.plan.totalCrafts==5 and row.quantity:GetNumber()==5,'Escape committed an unfinished edit')
row.minus:Run('OnClick')
assert(RS.plan.totalCrafts==4)
frame.close:Run('OnClick')
assert(not frame:IsShown(),'close did not hide popup')
RS.controls.list:Run('OnClick')
assert(frame:IsShown(),'List did not reopen popup')
RS.controls.button:Run('OnClick','RightButton')
assert(RS.plan.totalCrafts==4,'opening editor cleared the plan')

local choices={}
MenuUtil={CreateContextMenu=function(_,generator)
    generator(nil,{CreateTitle=noop,CreateRadio=function(_,label,selected,choose)
        choices[#choices+1]={label=label,selected=selected,choose=choose}
    end})
end}
RS.controls.quality:Run('OnClick')
assert(#choices==4 and choices[1].selected(),'quality menu default mismatch')
choices[3].choose()
assert(RS:GetSettings().quality==2 and RS.plan.entries[1].quality==0,
    'quality setting rewrote existing snapshot')
RS.controls.button:Run('OnClick','LeftButton')
assert(#RS.plan.entries==2 and RS.plan.entries[2].quality==2)
frame.inventory:SetChecked(false); frame.inventory:Run('OnClick')
local quantities={}; for _,m in ipairs(lastMaterials) do quantities[m.itemID]=m.quantity end
assert(quantities[101]==40 and quantities[102]==10,'inventory checkbox did not recalculate shopping')
row.remove:Run('OnClick')
assert(#RS.plan.entries==1 and RS.plan.entries[1].quality==2 and #frame.rowPool==1,
    'row delete lost other recipes or leaked its widget')

for recipe=2,8 do recipeInfo={recipeID=recipe,learned=true,name='Recipe '..recipe}; RS:AddRecipe(recipe,1,transaction,form) end
assert(frame.height==300 and frame.content.height==8*34,'long plan expanded instead of scrolling')
frame.scroll:SetVerticalScroll(102)
RS:RefreshPlanWindow()
assert(frame.scroll:GetVerticalScroll()==102,'refresh jumped to the start of the list')
frame.clear:Run('OnClick')
assert(#RS.plan.entries==8,'one click on clear removed everything without confirmation')
frame.clear:Run('OnClick')
assert(#RS.plan.entries==0 and #lastMaterials==0 and frame.empty:IsShown() and frame.scroll.scroll==0)

recipeInfo={recipeID=77,learned=false,name='Unlearned test'}
RS:OnRecipeSelected()
RS.controls.button:Run('OnClick','LeftButton')
local itemRow=frame.rows['recipe:77']
assert(itemRow and not itemRow.quantity.enabled and not itemRow.plus.enabled and not itemRow.minus.enabled,
    'unlearned recipe item was not displayed separately from craft quantities')
itemRow.remove:Run('OnClick')
assert(RS:GetPlannedRecipeItemCount()==0 and #lastMaterials==0,'unlearned recipe could not be individually removed')
print('Recipe shopping UI tests passed (compact popup, no focus theft, edits, tiers, stock, scroll, removal).')
