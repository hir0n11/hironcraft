-- Patron shopping may run before the load-on-demand auction addon exists.
-- Execute the actual UI entry points, not an isolated copy of their guards.
SlashCmdList={}
local selections,creates,refreshes=0,0,0
local lib={DoesIDExist=function() return true end,
    SetSelected=function() selections=selections+1 end}
local session={active=true,rows={{itemID=123,quantity=20}}}
HironCraftProfit={ShoppingList={session=session,LibAHTab=lib}}
function CreateFrame() error('auction templates are not loaded') end
assert(loadfile('ProfitHub/Shop/UI/ShoppingList_UI.lua'))()
local S=HironCraftProfit.ShoppingList
for i=1,3 do S:ShowWindow() end
assert(S:CreateWindow()==nil and not S.frame and not S.isAuctionHouseOpen)
assert(S.session==session and session.rows[1].quantity==20,'patron import was lost')

local shown=false
AuctionHouseFrame={IsShown=function() return shown end}
S:ShowWindow()
assert(not S.frame and not S.isAuctionHouseOpen,'loaded but closed auction was treated as open')
local frame={hides=0,scroll={SetVerticalScroll=function(_,value) assert(value==0) end},
    SetParent=function(_,parent) assert(parent==AuctionHouseFrame) end,
    ClearAllPoints=function() end,SetAllPoints=function() end,
    Hide=function(self) self.hides=self.hides+1 end}
-- Rendering itself is covered by the static UI/style checks. Here the native
-- addon becomes available and we verify normal creation/selection resumes.
S.CreateWindow=function(self) creates=creates+1;self.frame=frame;return frame end
S.EnsureAuctionTab=function() end
S.RefreshWindow=function() refreshes=refreshes+1 end
shown=true;S:ShowWindow()
assert(creates==1 and selections==1 and refreshes==1 and S.isAuctionHouseOpen)
assert(S.session==session and session.rows[1].quantity==20)
shown=false;S.isAuctionHouseOpen=false;S:ShowWindow()
assert(creates==1 and selections==1 and not S.isAuctionHouseOpen and frame.hides==1)
print('Shopping window loading tests passed (patron import before AH load, closed/open lifecycle, session retained).')
