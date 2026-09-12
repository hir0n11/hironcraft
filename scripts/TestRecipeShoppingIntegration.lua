-- Exercise real shopping normalization, persistence and auction lookup instead
-- of replacing CreateTemporaryImportedList with a successful stub.
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
local function noop() end
local eventHandler
local timers = {}
SlashCmdList = {}
HironCraftProfit = {L={}}
HironCraftProfit_DB = {}
Enum = { ItemClass={Recipe=9}, AuctionHouseSortOrder={Price=0,Name=1} }
function wipe(t) for k in pairs(t) do t[k]=nil end end
function GetTime() return 100 end
function time() return 100 end
function GetItemInfo(id)
    if id==901 then return 'Plans: Test Recipe',nil,3,nil,nil,nil,nil,nil,nil,nil,nil,9,0 end
    if id==902 then return 'Test Recipe',nil,3,nil,nil,nil,nil,nil,nil,nil,nil,4,0 end
end
function GetItemInfoInstant(id) return id,nil,nil,nil,nil,id==902 and 4 or 9,0 end
C_Item = {GetItemCount=function() return 0 end, RequestLoadItemDataByID=noop}
C_TradeSkillUI = {GetRecipeSourceText=function() return 'World drop' end}
C_Timer = {After=function(delay,fn) timers[#timers+1]={delay,fn} end}
C_AuctionHouse = {
    SendBrowseQuery=noop,GetBrowseResults=function() return {} end,
    MakeItemKey=function(id) return {itemID=id} end,SendSearchQuery=noop,
    GetNumCommoditySearchResults=function() return 0 end,GetCommoditySearchResultInfo=noop,
    GetNumItemSearchResults=function() return 0 end,GetItemSearchResultInfo=noop,
}
CreateFrame = function()
    return {RegisterEvent=noop, SetScript=function(_,event,fn) if event=='OnEvent' then eventHandler=fn end end}
end
dofile('ProfitHub/Shop/Core/ShoppingList_Core.lua')
dofile('ProfitHub/Shop/Core/RecipeShopping.lua')
local S, RS = HironCraftProfit.ShoppingList, HironCraftProfit.RecipeShopping
S.isAuctionHouseOpen=false
assert(RS:AddUnlearnedRecipe({recipeID=2002,name='Test Recipe',learned=false}))
assert(#S.session.rows==1 and S.session.rows[1].unresolvedName=='Test Recipe','recipe never reached the shop')
local listID=S.activeSavedListID
local db=HironCraftProfit_DB.shoppingList
assert(#db.savedLists==1 and #db.savedLists[1].rows==1,'recipe not saved before opening AH')
S.isAuctionHouseOpen=true
assert(S:ResolveUnresolvedSessionRowsByBrowse(), 'recipe lookup did not start')
assert(#S.session.rows==1 and #db.savedLists[1].rows==1,
    'opening the auction house removed the recipe while its item was being resolved')
eventHandler(nil,'AUCTION_HOUSE_CLOSED')
assert(#S.session.rows==1 and #db.savedLists[1].rows==1,'interrupted lookup lost the recipe')
assert(S.activeSavedListID==listID,'opening or closing AH switched recipe list')
S.isAuctionHouseOpen=true
assert(S:ResolveUnresolvedSessionRowsByBrowse(),'interrupted recipe lookup did not resume')
local E=HironCraftProfitShoppingListEnv
E.LibAHTab={}
local query={itemClassID=9,importSearchName='Test Recipe',quantity=1}
assert(not E.BuildImportMaterialFromBrowseResult({itemKey={itemID=902}},query),
    'recipe lookup accepted the crafted product instead of the learning item')
local resolved=assert(E.BuildImportMaterialFromBrowseResult({itemKey={itemID=901}},query))
assert(E.AppendImportedMaterialsToTarget(listID,{resolved},S.session.importSerial)==1)
assert(#S.session.rows==1 and S.session.rows[1].itemID==901 and S.session.rows[1].quantity==1,
    'resolved recipe did not replace its placeholder exactly once')
assert(#db.savedLists[1].rows==1 and db.savedLists[1].rows[1].itemID==901)
assert(E.AppendImportedMaterialsToTarget(listID,{resolved},S.session.importSerial-1)==0,
    'stale lookup appended a result to the saved list')

-- Also keep a placeholder when adding while AH is already open, and after a
-- completed search with no matching recipe (vendor/non-auctionable recipes).
assert(RS:ClearPlan())
assert(RS:AddUnlearnedRecipe({recipeID=2002,name='Test Recipe',learned=false}))
assert(#S.session.rows==1,'adding with AH open hid the recipe immediately')
listID=S.activeSavedListID
local unresolved={itemClassID=9,unresolvedName='Test Recipe',importSearchName='Test Recipe',
    quantity=1,importResolveAttempted=true}
E.AppendImportedMaterialsToTarget(listID,{unresolved},S.session.importSerial)
assert(#S.session.rows==1 and S.session.rows[1].quantity==1 and not S.session.rows[1].itemID,
    'failed lookup lost or doubled the unresolved recipe')
table.insert(db.savedLists,{id='old_temp',temporary=true,sourceKind='other_import',rows={}})
S:CleanupTemporaryLists()
assert(#db.savedLists==1 and db.savedLists[1].id==listID,'login cleanup removed the user-managed recipe list')
local active=S.session
assert(not S:RestoreRecipeShoppingListOnOpen() and S.session==active,
    'recipe restore replaced another active shopping session')
S.session={active=false,rows={}}
assert(S:RestoreRecipeShoppingListOnOpen() and #S.session.rows==1 and S.activeSavedListID==listID,
    'first auction opening after reload did not restore the pending recipe list')
RS.planLoaded=false
RS.plan={entries={},recipeItems={}}
local entries=RS:GetPlanEntries()
assert(#entries==1 and entries[1].kind=='recipe_item','recipe editor lost the saved learning-item request')
print('Recipe shopping integration tests passed.')
