-- The grades the Profit reagent mode asks the craft engine for: the cheapest
-- that reach the requested quality. When the client gives no answer for a
-- recipe, or the quality is out of reach, the answer must not be "the best
-- grades in every slot" - that turned Profit into the most expensive mode.
local clock,calls=100,0
-- Two slots sold in two grades each: five of 101/102 and ten of 201/202.
local schematic={reagentSlotSchematics={
    {slotIndex=1,dataSlotIndex=1,quantityRequired=5,required=true,reagentType=1,reagents={{itemID=101},{itemID=102}}},
    {slotIndex=2,dataSlotIndex=2,quantityRequired=10,required=true,reagentType=1,reagents={{itemID=201},{itemID=202}}},
}}
local prices={[101]=10,[102]=100,[201]=20,[202]=50}
-- What the client answers for a set of grades: given by each case.
local answer
HironCraftProfit={Prices={GetItemPrice=function(_,itemID) return prices[itemID] end}}
Enum={CraftingReagentType={Basic=1,Finishing=3}}
GetTime=function() return clock end
SlashCmdList={}
C_TradeSkillUI={
    GetRecipeSchematic=function() return schematic end,
    GetRecipeInfo=function() return {maxQuality=5} end,
    GetCraftingOperationInfoForOrder=function(_,reagents,_,concentration)
        calls=calls+1
        local grade={}
        for _,reagent in ipairs(reagents) do
            grade[reagent.dataSlotIndex]=(reagent.reagent.itemID%100==2) and 2 or 1
        end
        return answer(grade[1],grade[2],concentration==true)
    end,
}
assert(loadfile('ProfitHub/Core/CraftEngine/Engine.lua'))()
local CE=HironCraftProfit.CraftEngine
local function info(quality,cost) return {craftingQuality=math.floor(quality),quality=quality,concentrationCost=cost or 0} end
local function grades(plan) return plan.tierByDataSlot[1]..','..plan.tierByDataSlot[2] end
local function solve() return CE:SolveTierPerSlot(900,5,77) end

-- The client does not price this recipe at all: there is nothing to conclude.
-- It used to come back as "best grades everywhere, concentration needed".
answer=function() return nil end
assert(solve()==nil,'no answer from the client was turned into a plan')
answer=function() return {} end
assert(solve()==nil,'an answer without a quality was turned into a plan')

-- The lowest grades already reach the quality: nothing better is bought.
answer=function() return info(5) end
local plan=solve()
assert(grades(plan)=='1,1' and plan.needs==false and plan.reachable==true)

-- One step is needed. Slot 1 gives it for 5 x 90, slot 2 for 10 x 30: the
-- cheaper step is taken, and only that one.
answer=function(a,b) return info(4+(a-1)*1+(b-1)*1) end
plan=solve()
assert(grades(plan)=='1,2' and plan.needs==false and plan.reachable==true,'not the cheapest step: '..grades(plan))
prices[202]=500
plan=solve()
assert(grades(plan)=='2,1','the step did not follow the prices: '..grades(plan))
prices[202]=50

-- Both steps are needed.
answer=function(a,b) return info(4+(a-1)*0.5+(b-1)*0.5) end
plan=solve()
assert(grades(plan)=='2,2' and plan.needs==false)

-- No single step shows any gain, only both together do: the best grades are
-- known to reach the quality, anything less must not be passed off as enough.
answer=function(a,b) return info((a==2 and b==2) and 5 or 4) end
plan=solve()
assert(grades(plan)=='2,2' and plan.needs==false and plan.reachable==true,'a plan that does not reach the quality was called enough: '..grades(plan))

-- Grades alone cannot do it, concentration can: the lowest grades with
-- concentration, and its cost.
answer=function(_,_,concentration) return info(concentration and 5 or 4,concentration and 0 or 250) end
plan=solve()
assert(grades(plan)=='1,1' and plan.needs==true and plan.reachable==true and plan.concentrationCost==250,
    'concentration was paired with better grades than needed: '..grades(plan))
-- Concentration needs one better grade to get there: that one, the cheaper.
answer=function(a,b,concentration) return info(3+(a-1)*0.5+(b-1)*0.5+(concentration and 1.5 or 0),120) end
plan=solve()
assert(grades(plan)=='1,2' and plan.needs==true and plan.reachable==true)

-- Out of reach whatever is used: the lowest grades. Paying for the best ones
-- bought nothing, and it is what made the profit column so much worse.
answer=function() return info(3,90) end
plan=solve()
assert(grades(plan)=='1,1' and plan.needs==true and plan.reachable==false,'an order out of reach was priced with the best grades: '..grades(plan))

-- The cached question. "profit" and a fixed grade are separate answers.
answer=function(a,b) return info(4+(a-1)*1+(b-1)*1) end
calls=0
local cached=CE:NeedsConcentrationCached(900,5,77,'profit')
assert(grades(cached)=='1,2' and calls>0)
local asked=calls
assert(CE:NeedsConcentrationCached(900,5,77,'profit')==cached and calls==asked,'a known plan was computed again')
local fixed=CE:NeedsConcentrationCached(900,5,77,'t1')
assert(fixed.needs==true and fixed~=cached)
-- No answer is remembered for a moment only: asked once per second, not once
-- per drawn row, and asked again as soon as the client may know.
answer=function() return nil end
calls=0
assert(CE:NeedsConcentrationCached(901,5,78,'profit')==nil and calls==1)
assert(CE:NeedsConcentrationCached(901,5,78,'profit')==nil and calls==1,'a recipe without an answer was asked about again at once')
assert(CE:NeedsConcentrationCached(901,5,78,'t1')==nil)
clock=clock+1.5
answer=function() return info(5) end
plan=CE:NeedsConcentrationCached(901,5,78,'profit')
assert(plan and grades(plan)=='1,1' and plan.needs==false,'an answer that arrived later was not taken')

print('Profit grade tests passed (no answer, lowest enough, cheapest step, both steps, joint step, concentration, out of reach, cache).')
