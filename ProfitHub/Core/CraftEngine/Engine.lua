local PT = HironCraft or HironCraftProfit
if not PT then return end

PT.CraftEngine = PT.CraftEngine or {}
local CE = PT.CraftEngine

local function SafeNum(v) return tonumber(v) or 0 end

local ENCHANTING_VELLUM_ID = 38682

function CE:GetProfessionStats(skillLineID)
    skillLineID = tonumber(skillLineID)
    if not skillLineID or not C_TradeSkillUI or not C_TradeSkillUI.GetProfessionInfoBySkillLineID then
        return nil
    end
    local ok, info = pcall(C_TradeSkillUI.GetProfessionInfoBySkillLineID, skillLineID)
    if not ok or type(info) ~= "table" then return nil end

    local stats = {
        skillLineID         = skillLineID,
        professionID        = info.professionID,
        parentSkillLineID   = info.parentProfessionID or info.parentSkillLineID,
        skillLevel          = SafeNum(info.skillLevel),
        maxSkillLevel       = SafeNum(info.maxSkillLevel),
        skillModifier       = SafeNum(info.skillModifier),
        profession          = info.profession,
        professionName      = info.professionName,
        expansionName       = info.expansionName,
    }
    stats.totalSkill = stats.skillLevel + stats.skillModifier
    return stats
end

function CE:GetRecipeBasics(spellID)
    spellID = tonumber(spellID)
    if not spellID or not C_TradeSkillUI then return nil end

    local schematic
    if C_TradeSkillUI.GetRecipeSchematic then
        local ok, s = pcall(C_TradeSkillUI.GetRecipeSchematic, spellID, false)
        if ok then schematic = s end
    end
    if type(schematic) ~= "table" then return nil end

    local recipeInfo
    if C_TradeSkillUI.GetRecipeInfo then
        local ok2, ri = pcall(C_TradeSkillUI.GetRecipeInfo, spellID)
        if ok2 then recipeInfo = ri end
    end

    local maxQuality = 0
    if type(recipeInfo) == "table" then
        maxQuality = SafeNum(recipeInfo.maxQuality)
    end
    if maxQuality == 0 and schematic.reagentSlotSchematics then
        for _, slot in ipairs(schematic.reagentSlotSchematics) do
            if slot.reagents and #slot.reagents > maxQuality then
                maxQuality = #slot.reagents
            end
        end
    end

    local CRT = Enum and Enum.CraftingReagentType
    local basicEnum     = CRT and CRT.Basic
    local finishingEnum = CRT and CRT.Finishing

    local basicSlots, optionalSlots, finishingSlots, fixedReagents = {}, {}, {}, {}
    local basicByDS = {}
    if schematic.reagentSlotSchematics then
        for _, slot in ipairs(schematic.reagentSlotSchematics) do
            local hasOpts = slot.reagents and #slot.reagents > 0
            local qc = hasOpts and #slot.reagents or 0
            local ds = slot.dataSlotIndex or slot.slotIndex
            local entry = {
                slotIndex     = slot.slotIndex,
                dataSlotIndex = ds,
                quantity      = SafeNum(slot.quantityRequired),
                qualityCount  = qc,
                options       = slot.reagents,
                reagentType   = slot.reagentType,
                required      = slot.required,
            }
            if hasOpts then
                if finishingEnum and slot.reagentType == finishingEnum then
                    if Professions and Professions.GetReagentSlotStatus then
                        local okL, locked, reason = pcall(Professions.GetReagentSlotStatus, slot, recipeInfo)
                        entry.locked = (okL and locked == true) or false
                        if entry.locked then entry.lockReason = reason end
                    end
                    finishingSlots[#finishingSlots + 1] = entry
                elseif slot.required and qc == 1 then
                    local opt = slot.reagents[1]
                    local itemID = opt and (opt.itemID or opt)
                    if itemID then
                        fixedReagents[#fixedReagents + 1] = {
                            itemID = itemID,
                            quantity = entry.quantity,
                            dataSlotIndex = ds,
                            slotIndex = slot.slotIndex,
                        }
                    end
                elseif slot.required and qc >= 2 then
                    local prevIdx = basicByDS[ds]
                    if prevIdx then
                        if entry.qualityCount > basicSlots[prevIdx].qualityCount then
                            basicSlots[prevIdx] = entry
                        end
                    else
                        basicSlots[#basicSlots + 1] = entry
                        basicByDS[ds] = #basicSlots
                    end
                else
                    optionalSlots[#optionalSlots + 1] = entry
                end
            end
        end
    end

    local outputItemIDs
    if C_TradeSkillUI.GetRecipeQualityItemIDs then
        local okIDs, ids = pcall(C_TradeSkillUI.GetRecipeQualityItemIDs, spellID)
        if okIDs and type(ids) == "table" then
            local dense = {}
            local cap = math.max(maxQuality, 5)
            for q = 1, cap do
                if ids[q] then dense[#dense + 1] = ids[q] end
            end
            if #dense == 0 then
                for _, v in pairs(ids) do dense[#dense + 1] = v end
            end
            if #dense > 0 then outputItemIDs = dense end
        end
    end
    if not outputItemIDs and C_TradeSkillUI.GetRecipeOutputItemData then
        local dense = {}
        local maxQ = maxQuality > 0 and maxQuality or 1
        for q = 1, maxQ do
            local okO, data = pcall(C_TradeSkillUI.GetRecipeOutputItemData, spellID, nil, nil, nil, q)
            if okO and type(data) == "table" and data.itemID then
                dense[#dense + 1] = data.itemID
            end
        end
        if #dense == 0 then
            local okO, data = pcall(C_TradeSkillUI.GetRecipeOutputItemData, spellID)
            if okO and type(data) == "table" and data.itemID then
                dense[1] = data.itemID
            end
        end
        if #dense > 0 then outputItemIDs = dense end
    end
    if not outputItemIDs then
        local sid = schematic.outputItemID
            or (type(schematic.outputItemData) == "table" and schematic.outputItemData.itemID)
        if sid then outputItemIDs = { sid } end
    end

    local isEnchant = (recipeInfo and recipeInfo.isEnchantingRecipe) == true
    if isEnchant and (not outputItemIDs or #outputItemIDs == 0) then
        outputItemIDs = self:GetEnchantScrollItemIDs(spellID, maxQuality)
    end

    return {
        spellID        = spellID,
        recipeInfo     = recipeInfo,
        schematic      = schematic,
        maxQuality     = maxQuality,
        basicSlots     = basicSlots,
        optionalSlots  = optionalSlots,
        finishingSlots = finishingSlots,
        fixedReagents  = fixedReagents,
        outputItemIDs  = outputItemIDs,
        hasOutput      = (outputItemIDs ~= nil and #outputItemIDs > 0),
        isEnchant      = isEnchant,
        enchantVellumID = isEnchant and ENCHANTING_VELLUM_ID or nil,
        outputQuantity = SafeNum(schematic.quantityMin) > 0 and SafeNum(schematic.quantityMin) or 1,
        skillLineID    = schematic.recipeType == 1 and (recipeInfo and recipeInfo.skillLineID) or nil,
    }
end

function CE:GetEnchantCraftingDataID(spellID)
    spellID = tonumber(spellID)
    if not spellID or not C_TradeSkillUI then return nil end
    local getInfo = C_TradeSkillUI.GetCraftingOperationInfo
    if not getInfo then return nil end
    local ok, info = pcall(getInfo, spellID, {}, nil, false)
    if not ok or type(info) ~= "table" then
        ok, info = pcall(getInfo, spellID, {})
    end
    if type(info) == "table" then
        return info.craftingDataID
    end
    return nil
end

function CE:GetEnchantScrollItemIDs(spellID, maxQuality)
    local scrolls = self.ENCHANT_SCROLLS
    if type(scrolls) ~= "table" then return nil end

    local craftingDataID = self:GetEnchantCraftingDataID(spellID)
    if not craftingDataID then return nil end

    local ed = scrolls[craftingDataID]
    if type(ed) ~= "table" then return nil end

    local dense = {}
    for _, key in ipairs({ "q1", "q2", "q3" }) do
        if ed[key] then dense[#dense + 1] = ed[key] end
    end
    if #dense == 0 then return nil end
    return dense
end

function CE:RecipeSupportsMulticraft(spellID)
    spellID = tonumber(spellID)
    if not spellID then return false end
    local basics = self:GetRecipeBasics(spellID)
    if not basics then return false end

    if basics.isEnchant then return false end

    local itemID = basics.schematic and basics.schematic.outputItemID
    if not itemID then
        local ids = basics.outputItemIDs
        itemID = ids and (ids[#ids] or ids[1])
    end
    if not itemID then
        return (tonumber(basics.outputQuantity) or 1) > 1
    end

    local stack = select(8, GetItemInfo(itemID))
    if stack ~= nil then
        return (tonumber(stack) or 1) > 1
    end

    local equipLoc = select(4, GetItemInfoInstant(itemID))
    if equipLoc and equipLoc ~= "" then
        return false
    end
    return true
end

local function AsReagent(opt)
    if type(opt) == "table" then return opt end
    return { itemID = opt }
end

function CE:MakeReagents(basics, pickTier, locked)
    local out = {}
    if not basics or not basics.basicSlots then return out end
    local usedDS = {}
    for _, slot in ipairs(basics.basicSlots) do
        local ds = slot.dataSlotIndex
        local lk = locked and locked[ds]
        if lk and lk.itemID then
            out[#out + 1] = {
                reagent       = { itemID = lk.itemID },
                dataSlotIndex = ds,
                quantity      = lk.quantity or slot.quantity,
            }
            usedDS[ds] = true
        else
            local t = pickTier(slot) or 1
            if t < 1 then t = 1 end
            if t > slot.qualityCount then t = slot.qualityCount end
            local opt = slot.options and slot.options[t]
            if opt and slot.quantity and slot.quantity > 0 then
                out[#out + 1] = {
                    reagent       = AsReagent(opt),
                    dataSlotIndex = ds,
                    quantity      = slot.quantity,
                }
            end
        end
    end
    if locked then
        for ds, lk in pairs(locked) do
            if not usedDS[ds] and lk.itemID then
                out[#out + 1] = {
                    reagent       = { itemID = lk.itemID },
                    dataSlotIndex = ds,
                    quantity      = lk.quantity or 1,
                }
            end
        end
    end
    return out
end

function CE:IsLockedSlot(locked, dataSlotIndex)
    return locked and locked[dataSlotIndex] and locked[dataSlotIndex].itemID ~= nil
end

function CE:CallOp(spellID, reagents, orderID, useConcentration)
    if not C_TradeSkillUI then return nil, nil, "no C_TradeSkillUI" end
    local lastErr
    if orderID and C_TradeSkillUI.GetCraftingOperationInfoForOrder then
        local ok, info = pcall(C_TradeSkillUI.GetCraftingOperationInfoForOrder, spellID, reagents, orderID, useConcentration)
        if ok and type(info) == "table" then return info, "order" end
        lastErr = ok and "order:non-table" or ("order:" .. tostring(info))
    end
    if C_TradeSkillUI.GetCraftingOperationInfo then
        local ok, info = pcall(C_TradeSkillUI.GetCraftingOperationInfo, spellID, reagents, nil, useConcentration)
        if ok and type(info) == "table" then return info, "plain" end
        lastErr = ok and "plain:non-table" or ("plain:" .. tostring(info))

        local ok2, info2 = pcall(C_TradeSkillUI.GetCraftingOperationInfo, spellID, reagents)
        if ok2 and type(info2) == "table" then return info2, "plain2" end
        lastErr = ok2 and (lastErr .. " | plain2:non-table") or (lastErr .. " | plain2:" .. tostring(info2))
    end
    return nil, nil, lastErr
end

local function DumpTable(prefix, t, depth)
    depth = depth or 0
    if depth > 2 then return end
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
        local v = t[k]
        if type(v) == "table" then
            print(string.format("%s%s = { #%d }", prefix, tostring(k), #v))
            if depth < 2 then DumpTable(prefix .. "  ", v, depth + 1) end
        else
            print(string.format("%s%s = %s", prefix, tostring(k), tostring(v)))
        end
    end
end

function CE:Probe(spellID, orderID)
    local basics = self:GetRecipeBasics(spellID)
    if not basics then
        print("|cffff5555CE|r no schematic for " .. tostring(spellID))
        return
    end
    print(string.format("|cffb19cd9CraftEngine probe|r spell=%d maxQ=%d basicSlots=%d order=%s",
        spellID, basics.maxQuality, #basics.basicSlots, tostring(orderID)))

    local lowR  = self:MakeReagents(basics, function() return 1 end)
    local highR = self:MakeReagents(basics, function(s) return s.qualityCount end)

    for _, case in ipairs({ { "NO-REAGENTS", {} }, { "ALL-LOW", lowR }, { "ALL-HIGH", highR } }) do
        for _, conc in ipairs({ false, true }) do
            local norm, err = self:Evaluate(spellID, case[2], { orderID = orderID, useConcentration = conc })
            if norm then
                print(string.format("|cff88ff88%s conc=%s|r Q%s (%.3f) skill=%s/%s conc=%s",
                    case[1], tostring(conc), tostring(norm.quality), norm.qualityFloat or 0,
                    tostring(norm.skill), tostring(norm.difficulty), tostring(norm.concentrationCost)))
            else
                print(string.format("|cffff5555%s conc=%s nil|r", case[1], tostring(conc)))
            end
        end
    end
end

function CE:Normalize(info, source)
    if type(info) ~= "table" then return nil end
    local qFloat = tonumber(info.quality)
    local qInt   = tonumber(info.craftingQuality)
    if not qInt and qFloat then qInt = math.floor(qFloat) end

    local baseSkill = tonumber(info.baseSkill)
    local bonusSkill = tonumber(info.bonusSkill)
    local skill = info.skill and tonumber(info.skill)
    if not skill and baseSkill then skill = baseSkill + (bonusSkill or 0) end

    local baseDiff = tonumber(info.baseDifficulty)
    local bonusDiff = tonumber(info.bonusDifficulty)
    local difficulty = info.difficulty and tonumber(info.difficulty)
    if not difficulty and baseDiff then difficulty = baseDiff + (bonusDiff or 0) end

    return {
        raw                 = info,
        source              = source,
        quality             = qInt,
        qualityFloat        = qFloat or qInt,
        qualityID           = info.craftingQualityID,
        guaranteedQualityID = info.guaranteedCraftingQualityID,
        skill               = skill,
        difficulty          = difficulty,
        lowerThreshold      = tonumber(info.lowerSkillThreshold),
        upperThreshold      = tonumber(info.upperSkillThreshold) or tonumber(info.upperSkillTreshold),
        concentrationCost   = tonumber(info.concentrationCost) or 0,
        concentrationCurrencyID = tonumber(info.concentrationCurrencyID),
        isQualityCraft      = info.isQualityCraft,
    }
end

function CE:Evaluate(spellID, reagents, opts)
    opts = opts or {}
    local info, src = self:CallOp(spellID, reagents, opts.orderID, opts.useConcentration)
    return self:Normalize(info, src)
end

local function ProgressMetric(norm)
    if not norm then return nil end
    if norm.qualityFloat then return norm.qualityFloat end
    if norm.skill then return norm.skill end
    return norm.quality
end

function CE:DefaultPrice(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil end
    local PP = HironCraftProfit and HironCraftProfit.Prices
    if PP and PP.GetItemPrice then
        local v = PP:GetItemPrice(itemID)
        if type(v) == "number" and v > 0 then return v end
    end
    local env = _G.HironCraftProfitRecipeListEnv
    if env and type(env.GetAuctionatorPriceByItemID) == "function" then
        local ok, p = pcall(env.GetAuctionatorPriceByItemID, itemID)
        if ok and type(p) == "number" and p > 0 then return p end
    end
    return nil
end

local function NewAllocAllTier(basics, tier)
    local alloc = {}
    for i, slot in ipairs(basics.basicSlots) do
        local arr = {}
        local t = tier
        if t == "max" then t = slot.qualityCount end
        for u = 1, slot.quantity do arr[u] = t end
        alloc[i] = arr
    end
    return alloc
end

local function CopyAlloc(alloc)
    local out = {}
    for i, arr in ipairs(alloc) do
        local c = {}
        for u, v in ipairs(arr) do c[u] = v end
        out[i] = c
    end
    return out
end

function CE:AllocToReagents(basics, alloc)
    local out = {}
    for i, slot in ipairs(basics.basicSlots) do
        local arr = alloc[i]
        local perTier = {}
        for _, t in ipairs(arr) do perTier[t] = (perTier[t] or 0) + 1 end
        for t = 1, slot.qualityCount do
            local cnt = perTier[t]
            if cnt and cnt > 0 then
                local opt = slot.options and slot.options[t]
                if opt then
                    out[#out + 1] = {
                        reagent       = AsReagent(opt),
                        dataSlotIndex = slot.dataSlotIndex,
                        quantity      = cnt,
                    }
                end
            end
        end
    end
    return out
end

local function AllocCost(basics, alloc, getPrice)
    local total, priced, units = 0, 0, 0
    for i, slot in ipairs(basics.basicSlots) do
        for _, t in ipairs(alloc[i]) do
            units = units + 1
            local opt = slot.options and slot.options[t]
            local itemID = opt and (opt.itemID or opt)
            local p = itemID and getPrice(itemID)
            if p and p > 0 then
                total = total + p
                priced = priced + 1
            end
        end
    end
    return total, (priced == units and units > 0), priced, units
end

function CE:_GreedySolve(spellID, basics, targetQ, useConc, getPrice, orderID)
    local alloc = NewAllocAllTier(basics, 1)
    local function evalAlloc(a)
        return self:Evaluate(spellID, self:AllocToReagents(basics, a), { orderID = orderID, useConcentration = useConc })
    end

    local norm = evalAlloc(alloc)
    if norm and norm.quality and norm.quality >= targetQ then
        return alloc, norm, true
    end

    local maxAlloc = NewAllocAllTier(basics, "max")
    local maxNorm = evalAlloc(maxAlloc)
    if not (maxNorm and maxNorm.quality and maxNorm.quality >= targetQ) then
        return maxAlloc, maxNorm, false
    end

    local guard = 0
    local maxSteps = 0
    for _, slot in ipairs(basics.basicSlots) do
        maxSteps = maxSteps + slot.quantity * math.max(0, slot.qualityCount - 1)
    end

    while guard < maxSteps + 2 do
        guard = guard + 1
        local cur = evalAlloc(alloc)
        if cur and cur.quality and cur.quality >= targetQ then
            return alloc, cur, true
        end
        local curMetric = ProgressMetric(cur) or 0

        local bestI, bestU, bestScore
        for i, slot in ipairs(basics.basicSlots) do
            for u = 1, slot.quantity do
                local t = alloc[i][u]
                if t < slot.qualityCount then
                    local trial = CopyAlloc(alloc)
                    trial[i][u] = t + 1
                    local trialNorm = evalAlloc(trial)
                    local gain = (ProgressMetric(trialNorm) or curMetric) - curMetric
                    local o1 = slot.options[t];     local p1 = o1 and getPrice(o1.itemID or o1) or 0
                    local o2 = slot.options[t + 1]; local p2 = o2 and getPrice(o2.itemID or o2) or 0
                    local dCost = (p2 or 0) - (p1 or 0)
                    if dCost <= 0 then dCost = 1 end
                    local score = gain / dCost
                    if gain > 0 and (not bestScore or score > bestScore) then
                        bestScore, bestI, bestU = score, i, u
                    end
                end
            end
        end

        if not bestI then
            alloc = maxAlloc
            return alloc, evalAlloc(alloc), true
        end
        alloc[bestI][bestU] = alloc[bestI][bestU] + 1
    end

    return alloc, evalAlloc(alloc), true
end

function CE:SolveForQuality(spellID, targetQ, opts)
    spellID = tonumber(spellID)
    targetQ = tonumber(targetQ)
    if not spellID or not targetQ then return nil end
    opts = opts or {}
    local getPrice = opts.getPrice or function(id) return self:DefaultPrice(id) end
    local orderID = opts.orderID
    local allowConc = opts.allowConcentration ~= false

    local basics = self:GetRecipeBasics(spellID)
    if not basics or #basics.basicSlots == 0 then
        local norm = self:Evaluate(spellID, {}, { orderID = orderID })
        local q = norm and norm.quality
        return {
            spellID = spellID, targetQuality = targetQ,
            reachable = (q ~= nil) and (q >= targetQ) or (q == nil),
            needsConcentration = false, concentrationCost = 0,
            achievedQuality = q, achievedQualityFloat = norm and norm.qualityFloat,
            reagents = {}, alloc = {}, cost = nil, pricedComplete = false,
            noQualitySlots = true,
        }
    end

    local alloc, norm, ok = self:_GreedySolve(spellID, basics, targetQ, false, getPrice, orderID)
    if ok then
        local cost, complete = AllocCost(basics, alloc, getPrice)
        return {
            spellID = spellID, targetQuality = targetQ,
            reachable = true, needsConcentration = false, concentrationCost = 0,
            achievedQuality = norm and norm.quality, achievedQualityFloat = norm and norm.qualityFloat,
            reagents = self:AllocToReagents(basics, alloc), alloc = alloc,
            cost = cost, pricedComplete = complete,
        }
    end

    if allowConc then
        local cAlloc, cNorm, cOk = self:_GreedySolve(spellID, basics, targetQ, true, getPrice, orderID)
        if cOk then
            local cost, complete = AllocCost(basics, cAlloc, getPrice)
            return {
                spellID = spellID, targetQuality = targetQ,
                reachable = true, needsConcentration = true,
                concentrationCost = cNorm and cNorm.concentrationCost or 0,
                achievedQuality = cNorm and cNorm.quality, achievedQualityFloat = cNorm and cNorm.qualityFloat,
                reagents = self:AllocToReagents(basics, cAlloc), alloc = cAlloc,
                cost = cost, pricedComplete = complete,
            }
        end
    end

    return {
        spellID = spellID, targetQuality = targetQ,
        reachable = false, needsConcentration = allowConc,
        concentrationCost = norm and norm.concentrationCost or 0,
        achievedQuality = norm and norm.quality, achievedQualityFloat = norm and norm.qualityFloat,
        reagents = self:AllocToReagents(basics, alloc), alloc = alloc,
        cost = nil, pricedComplete = false,
    }
end

function CE:TierPickerForMode(mode, getPrice)
    if mode == "t1" then
        return function() return 1 end
    elseif mode == "t2" then
        return function(slot) return math.min(2, slot.qualityCount) end
    elseif mode == "max" then
        return function(slot) return slot.qualityCount end
    end
    getPrice = getPrice or function(id) return self:DefaultPrice(id) end
    return function(slot)
        local bestT, bestP
        for t = 1, slot.qualityCount do
            local opt = slot.options and slot.options[t]
            local id = opt and (opt.itemID or opt)
            local p = id and getPrice(id)
            if p and (not bestP or p < bestP) then bestP, bestT = p, t end
        end
        return bestT or 1
    end
end

function CE:NeedsConcentration(spellID, targetQ, orderID, pickTier, locked)
    spellID = tonumber(spellID)
    targetQ = tonumber(targetQ)
    if not spellID or not targetQ then return nil end

    local basics = self:GetRecipeBasics(spellID)
    if not basics then return nil end
    pickTier = pickTier or function(s) return s.qualityCount end
    local reagents = self:MakeReagents(basics, pickTier, locked)

    local best = self:Evaluate(spellID, reagents, { orderID = orderID, useConcentration = false })
    if not best or not best.quality then return nil end

    if best.quality >= targetQ then
        return { needs = false, reachable = true, reachableNoConc = true,
                 concentrationCost = 0, noConcQuality = best.quality }
    end

    local withConc = self:Evaluate(spellID, reagents, { orderID = orderID, useConcentration = true })
    local reachable = withConc and withConc.quality and withConc.quality >= targetQ
    return {
        needs = true,
        reachable = reachable or false,
        reachableNoConc = false,
        concentrationCost = withConc and withConc.concentrationCost or 0,
        noConcQuality = best.quality,
        concQuality = withConc and withConc.quality,
    }
end

function CE:SolveTierPerSlot(spellID, targetQ, orderID, getPrice, locked)
    spellID = tonumber(spellID)
    targetQ = tonumber(targetQ)
    if not spellID or not targetQ then return nil end
    getPrice = getPrice or function(id) return self:DefaultPrice(id) end
    local basics = self:GetRecipeBasics(spellID)
    if not basics then return nil end
    if #basics.basicSlots == 0 then
        local n = self:NeedsConcentration(spellID, targetQ, orderID, nil, locked)
        if n then n.tierByDataSlot = {} end
        return n
    end

    local tierByDS = {}
    local function setAll(fn)
        for _, slot in ipairs(basics.basicSlots) do tierByDS[slot.dataSlotIndex] = fn(slot) end
    end
    local function pick(slot) return tierByDS[slot.dataSlotIndex] or 1 end
    local function evalConc(useConc)
        return self:Evaluate(spellID, self:MakeReagents(basics, pick, locked), { orderID = orderID, useConcentration = useConc })
    end

    local function greedy(useConc)
        setAll(function() return 1 end)
        local cur = evalConc(useConc)
        if cur and cur.quality and cur.quality >= targetQ then return cur, true end

        setAll(function(s) return s.qualityCount end)
        local mx = evalConc(useConc)
        if not (mx and mx.quality and mx.quality >= targetQ) then return mx, false end

        setAll(function() return 1 end)
        local guard = 0
        while guard < 200 do
            guard = guard + 1
            cur = evalConc(useConc)
            if cur and cur.quality and cur.quality >= targetQ then return cur, true end
            local curM = ProgressMetric(cur) or 0
            local bestI, bestScore
            for i, slot in ipairs(basics.basicSlots) do
                local t = tierByDS[slot.dataSlotIndex]
                if t < slot.qualityCount and not self:IsLockedSlot(locked, slot.dataSlotIndex) then
                    tierByDS[slot.dataSlotIndex] = t + 1
                    local trial = evalConc(useConc)
                    tierByDS[slot.dataSlotIndex] = t
                    local gain = (ProgressMetric(trial) or curM) - curM
                    local o1 = slot.options[t]; local o2 = slot.options[t + 1]
                    local p1 = o1 and getPrice(o1.itemID or o1) or 0
                    local p2 = o2 and getPrice(o2.itemID or o2) or 0
                    local d = (p2 or 0) - (p1 or 0); if d <= 0 then d = 1 end
                    local score = gain / d
                    if gain > 0 and (not bestScore or score > bestScore) then bestScore, bestI = score, i end
                end
            end
            if not bestI then break end
            local s = basics.basicSlots[bestI]
            tierByDS[s.dataSlotIndex] = tierByDS[s.dataSlotIndex] + 1
        end
        return evalConc(useConc), true
    end

    local cur, ok = greedy(false)
    local needsConc, concCost, reachable = false, 0, ok
    if not ok then
        cur, ok = greedy(true)
        needsConc, reachable = true, ok
        concCost = cur and cur.concentrationCost or 0
    end

    local tierMap = {}
    for k, v in pairs(tierByDS) do tierMap[k] = v end
    return {
        tierByDataSlot    = tierMap,
        needs             = needsConc,
        reachable         = reachable,
        concentrationCost = concCost,
        quality           = cur and cur.quality,
    }
end

function CE:NeedsConcentrationCached(spellID, targetQ, orderID, mode, locked, ttl)
    ttl = ttl or 30
    self._concCache = self._concCache or {}
    local key = tostring(spellID) .. ":" .. tostring(targetQ) .. ":" .. tostring(orderID) .. ":" .. tostring(mode or "max")
    local now = GetTime()
    local hit = self._concCache[key]
    if hit and hit.expires > now then return hit.value end

    local value
    if mode == "profit" then
        value = self:SolveTierPerSlot(spellID, targetQ, orderID, nil, locked)
    else
        value = self:NeedsConcentration(spellID, targetQ, orderID, self:TierPickerForMode(mode), locked)
    end
    if value then
        self._concCache[key] = { value = value, expires = now + ttl }
    end
    return value
end

function CE:InvalidateConcCache()
    self._concCache = {}
end

function CE:ReagentsCost(reagents, getPrice)
    local total, complete = 0, true
    for _, r in ipairs(reagents or {}) do
        local id = r.reagent and r.reagent.itemID
        local p = id and getPrice(id)
        if p and p > 0 then
            total = total + p * (r.quantity or 1)
        else
            complete = false
        end
    end
    return total, complete
end

function CE:FixedReagentsCost(basics, getPrice)
    local total = 0
    for _, r in ipairs(basics and basics.fixedReagents or {}) do
        local p = r.itemID and getPrice(r.itemID)
        if p and p > 0 then total = total + p * (r.quantity or 1) end
    end
    if basics and basics.isEnchant then
        local vp = getPrice(basics.enchantVellumID or ENCHANTING_VELLUM_ID)
        if vp and vp > 0 then total = total + vp end
    end
    return total
end

function CE:GetOutputValue(basics, quality, getPrice)
    if not basics then return nil end
    local ids = basics.outputItemIDs
    if not ids or #ids == 0 then return nil end
    local q = quality or #ids
    if q < 1 then q = 1 end
    if q > #ids then q = #ids end
    local itemID = ids[q]
    if not itemID then return nil end
    local p = getPrice(itemID)
    if not p then return nil, itemID end
    return p * (basics.outputQuantity or 1), itemID
end

CE.MULTICRAFT_YIELD    = 1.25  
CE.RESOURCEFULNESS_SAVE = 0.30 
CE.INGENUITY_REFUND     = 0.55 

local STAT_MATCH = {
    multicraft      = { "перепроизводство", "multicraft" },
    resourcefulness = { "находчивость", "resourcefulness" },
    ingenuity       = { "изобретательность", "ingenuity" },
}

function CE:ExtractStats(norm)
    local out = { multicraft = 0, resourcefulness = 0, ingenuity = 0 }
    local bs = norm and norm.raw and norm.raw.bonusStats
    if type(bs) ~= "table" then return out end
    for _, e in ipairs(bs) do
        local name = tostring(e.bonusStatName or ""):lower()
        local pct = tonumber(e.ratingPct) or tonumber(e.bonusRatingPct) or 0
        for key, names in pairs(STAT_MATCH) do
            for _, n in ipairs(names) do
                if name:find(n, 1, true) then out[key] = pct end
            end
        end
    end
    return out
end

function CE:AdjustEconomics(norm, outVal, cost)
    local s = self:ExtractStats(norm)
    local adjOut = (outVal or 0) * (1 + (s.multicraft / 100) * self.MULTICRAFT_YIELD)
    local adjCost = (cost or 0) * (1 - (s.resourcefulness / 100) * self.RESOURCEFULNESS_SAVE)
    local effConc = (norm.concentrationCost or 0) * (1 - (s.ingenuity / 100) * self.INGENUITY_REFUND)
    return adjOut, adjCost, effConc, s
end

local function ItemOwned(itemID)
    if not itemID then return false end
    local cnt
    if C_Item and C_Item.GetItemCount then
        cnt = C_Item.GetItemCount(itemID)
    elseif GetItemCount then
        cnt = GetItemCount(itemID)
    end
    return (cnt or 0) > 0
end

function CE:GetSlotOptions(slot, requireOwned)
    local out = {}
    for _, o in ipairs(slot and slot.options or {}) do
        if o and o.itemID and (not requireOwned or ItemOwned(o.itemID)) then
            out[#out + 1] = o
        end
    end
    return out
end

function CE:BuildReagentsFromAlloc(basics, tierByDS, extraByDS, locked)
    local r = self:MakeReagents(basics, function(slot) return (tierByDS and tierByDS[slot.dataSlotIndex]) or 1 end, locked)
    if extraByDS then
        for ds, opt in pairs(extraByDS) do
            if opt and opt.itemID then
                r[#r + 1] = { reagent = { itemID = opt.itemID }, dataSlotIndex = ds, quantity = 1 }
            end
        end
    end
    return r
end

function CE:EvaluateAlloc(spellID, basics, tierByDS, extraByDS, useConc, opts)
    opts = opts or {}
    local getPrice = opts.getPrice or function(id) return self:DefaultPrice(id) end
    local reagents = self:BuildReagentsFromAlloc(basics, tierByDS, extraByDS, opts.locked)
    local norm = self:Evaluate(spellID, reagents, { orderID = opts.orderID, useConcentration = useConc })
    if not norm then return nil end
    local outVal = self:GetOutputValue(basics, norm.quality, getPrice) or 0
    local cost = self:ReagentsCost(reagents, getPrice) + self:FixedReagentsCost(basics, getPrice)
    local adjOut, adjCost, effConc, stats = self:AdjustEconomics(norm, outVal, cost)
    return {
        quality           = norm.quality,
        qualityFloat      = norm.qualityFloat,
        outputValue       = adjOut,
        baseOutputValue   = outVal,
        reagentCost       = adjCost,
        baseReagentCost   = cost,
        profit            = adjOut - adjCost,
        baseProfit        = outVal - cost,
        concentrationCost = norm.concentrationCost or 0,
        effConcentration  = effConc,
        stats             = stats,
    }
end

function CE:BuildReagentsFromMix(basics, mixByDS, extraByDS, locked, includeFixed)
    local out = {}
    if not basics then return out end
    for _, slot in ipairs(basics.basicSlots) do
        local ds = slot.dataSlotIndex
        local lk = locked and locked[ds]
        if lk and lk.itemID then
            out[#out + 1] = { reagent = { itemID = lk.itemID }, dataSlotIndex = ds, quantity = lk.quantity or slot.quantity }
        else
            local mix = mixByDS and mixByDS[ds]
            local any = false
            if mix then
                for tier = 1, slot.qualityCount do
                    local cnt = mix[tier]
                    if cnt and cnt > 0 then
                        local opt = slot.options and slot.options[tier]
                        local itemID = opt and (opt.itemID or opt)
                        if itemID then
                            out[#out + 1] = { reagent = { itemID = itemID }, dataSlotIndex = ds, quantity = cnt }
                            any = true
                        end
                    end
                end
            end
            if not any then
                local opt = slot.options and slot.options[1]
                local itemID = opt and (opt.itemID or opt)
                if itemID and slot.quantity and slot.quantity > 0 then
                    out[#out + 1] = { reagent = { itemID = itemID }, dataSlotIndex = ds, quantity = slot.quantity }
                end
            end
        end
    end
    if extraByDS then
        for ds, opt in pairs(extraByDS) do
            if opt and opt.itemID then
                out[#out + 1] = { reagent = { itemID = opt.itemID }, dataSlotIndex = ds, quantity = 1 }
            end
        end
    end
    if includeFixed then
        for _, fr in ipairs(basics.fixedReagents or {}) do
            if fr.itemID and fr.quantity and fr.quantity > 0 then
                out[#out + 1] = { reagent = { itemID = fr.itemID }, dataSlotIndex = fr.dataSlotIndex, quantity = fr.quantity }
            end
        end
    end
    return out
end

function CE:EvaluateMix(spellID, basics, mixByDS, extraByDS, useConc, opts)
    opts = opts or {}
    local getPrice = opts.getPrice or function(id) return self:DefaultPrice(id) end
    local reagents = self:BuildReagentsFromMix(basics, mixByDS, extraByDS, opts.locked)
    local norm = self:Evaluate(spellID, reagents, { orderID = opts.orderID, useConcentration = useConc })
    if not norm then return nil end
    local outVal = self:GetOutputValue(basics, norm.quality, getPrice) or 0
    local cost = self:ReagentsCost(reagents, getPrice) + self:FixedReagentsCost(basics, getPrice)
    local adjOut, adjCost, effConc, stats = self:AdjustEconomics(norm, outVal, cost)
    return {
        quality           = norm.quality,
        qualityFloat      = norm.qualityFloat,
        outputValue       = adjOut,
        reagentCost       = adjCost,
        profit            = adjOut - adjCost,
        baseOutputValue   = outVal,
        baseReagentCost   = cost,
        baseProfit        = outVal - cost,
        concentrationCost = norm.concentrationCost or 0,
        concentrationCurrencyID = norm.concentrationCurrencyID,
        effConcentration  = effConc,
        stats             = stats,
    }
end

function CE:QuickProfit(spellID, opts)
    spellID = tonumber(spellID)
    if not spellID then return nil end
    opts = opts or {}
    local getPrice = opts.getPrice or function(id) return self:DefaultPrice(id) end
    local basics = self:GetRecipeBasics(spellID)
    if not basics then return nil end

    local lowR  = self:MakeReagents(basics, function() return 1 end)
    local highR = self:MakeReagents(basics, function(s) return s.qualityCount end)
    local fixedCost = self:FixedReagentsCost(basics, getPrice)

    local best, anyOut = nil, false
    local function consider(reagents, useConc)
        local norm = self:Evaluate(spellID, reagents, { useConcentration = useConc })
        if not norm then return end
        local outVal, outItem = self:GetOutputValue(basics, norm.quality, getPrice)
        if outItem and not outVal then return end  
        anyOut = true
        local cost = self:ReagentsCost(reagents, getPrice) + fixedCost
        local adjOut, adjCost = self:AdjustEconomics(norm, outVal or 0, cost)
        local profit = adjOut - adjCost
        if not best or profit > best then best = profit end
    end

    consider(lowR, false)
    consider(lowR, true)   
    consider(highR, false)
    consider(highR, true)
    if not anyOut then return nil end
    return best
end

function CE:OptimizeProfit(spellID, opts)
    spellID = tonumber(spellID)
    if not spellID then return nil end
    opts = opts or {}
    local getPrice = opts.getPrice or function(id) return self:DefaultPrice(id) end
    local orderID = opts.orderID
    local locked = opts.locked
    local basics = self:GetRecipeBasics(spellID)
    if not basics then return nil end

    local extraSlots = {}
    for _, s in ipairs(basics.finishingSlots or {}) do extraSlots[#extraSlots + 1] = { slot = s, finishing = true } end
    for _, s in ipairs(basics.optionalSlots or {}) do extraSlots[#extraSlots + 1] = { slot = s, finishing = false } end

    local tierByDS = {}
    local extraByDS = {}

    local function buildReagents()
        local r = self:MakeReagents(basics, function(slot) return tierByDS[slot.dataSlotIndex] or 1 end, locked)
        for ds, opt in pairs(extraByDS) do
            if opt and opt.itemID then
                r[#r + 1] = { reagent = { itemID = opt.itemID }, dataSlotIndex = ds, quantity = 1 }
            end
        end
        return r
    end

    local function profitOf(useConc)
        local reagents = buildReagents()
        local norm = self:Evaluate(spellID, reagents, { orderID = orderID, useConcentration = useConc })
        if not norm then return nil end
        local outVal = self:GetOutputValue(basics, norm.quality, getPrice) or 0
        local cost = self:ReagentsCost(reagents, getPrice) + self:FixedReagentsCost(basics, getPrice)
        local adjOut, adjCost, effConc, stats = self:AdjustEconomics(norm, outVal, cost)
        return adjOut - adjCost, {
            quality           = norm.quality,
            qualityFloat      = norm.qualityFloat,
            outputValue       = adjOut,
            reagentCost       = adjCost,
            concentrationCost = norm.concentrationCost or 0,
            effConcentration  = effConc,
            stats             = stats,
        }
    end

    local function greedyBasics(useConc)
        local bestProfit = profitOf(useConc)
        if not bestProfit then return nil end
        local guard = 0
        while guard < 200 do
            guard = guard + 1
            local bestI, bestDelta = nil, 0
            for i, slot in ipairs(basics.basicSlots) do
                local t = tierByDS[slot.dataSlotIndex] or 1
                if t < slot.qualityCount and not self:IsLockedSlot(locked, slot.dataSlotIndex) then
                    tierByDS[slot.dataSlotIndex] = t + 1
                    local p = profitOf(useConc)
                    tierByDS[slot.dataSlotIndex] = t
                    if p and (p - bestProfit) > bestDelta then bestDelta = p - bestProfit; bestI = i end
                end
            end
            if not bestI then break end
            local s = basics.basicSlots[bestI]
            tierByDS[s.dataSlotIndex] = (tierByDS[s.dataSlotIndex] or 1) + 1
            bestProfit = profitOf(useConc)
        end
        return bestProfit
    end

    local function greedyExtras(useConc)
        for _, e in ipairs(extraSlots) do
            local slot = e.slot
            local ds = slot.dataSlotIndex
            local opts = (e.finishing and slot.locked) and {} or self:GetSlotOptions(slot, e.finishing)
            local bestOpt = extraByDS[ds]
            local bestProfit = profitOf(useConc) or 0
            for _, opt in ipairs(opts) do
                extraByDS[ds] = opt
                local p = profitOf(useConc)
                if p and p > bestProfit then bestProfit, bestOpt = p, opt end
            end
            extraByDS[ds] = bestOpt
        end
    end

    local function optimize(useConc)
        for _, slot in ipairs(basics.basicSlots) do tierByDS[slot.dataSlotIndex] = 1 end
        for k in pairs(extraByDS) do extraByDS[k] = nil end
        greedyBasics(useConc)
        if not opts.skipExtras then
            greedyExtras(useConc)
            greedyBasics(useConc)
        end
        local finalProfit, info = profitOf(useConc)
        if not info then return nil end
        info.profit = finalProfit
        local tierMap = {} ; for k, v in pairs(tierByDS) do tierMap[k] = v end
        local extraMap = {} ; for k, v in pairs(extraByDS) do extraMap[k] = v end
        info.tierByDataSlot = tierMap
        info.extraByDataSlot = extraMap
        return info
    end

    local noConc = optimize(false)
    local conc = optimize(true)
    local concValue
    if noConc and conc and conc.concentrationCost and conc.concentrationCost > 0 then
        concValue = (conc.profit - noConc.profit) / conc.concentrationCost
    end
    return {
        noConc             = noConc,
        conc               = conc,
        concentrationValue = concValue,
        outputItemIDs      = basics.outputItemIDs,
    }
end

function CE:OptimizeProfitMix(spellID, opts)
    spellID = tonumber(spellID)
    if not spellID then return nil end
    opts = opts or {}
    local getPrice = opts.getPrice or function(id) return self:DefaultPrice(id) end
    local orderID = opts.orderID
    local locked = opts.locked
    local basics = self:GetRecipeBasics(spellID)
    if not basics then return nil end

    local extraSlots = {}
    for _, s in ipairs(basics.finishingSlots or {}) do extraSlots[#extraSlots + 1] = { slot = s, finishing = true } end
    for _, s in ipairs(basics.optionalSlots or {}) do extraSlots[#extraSlots + 1] = { slot = s, finishing = false } end

    local function buildReagents(alloc, extraByDS)
        local r = self:AllocToReagents(basics, alloc)
        for ds, opt in pairs(extraByDS) do
            if opt and opt.itemID then
                r[#r + 1] = { reagent = { itemID = opt.itemID }, dataSlotIndex = ds, quantity = 1 }
            end
        end
        return r
    end

    local function evalAlloc(alloc, extraByDS, useConc)
        local reagents = buildReagents(alloc, extraByDS)
        local norm = self:Evaluate(spellID, reagents, { orderID = orderID, useConcentration = useConc })
        if not norm then
            if #basics.basicSlots == 0 then
                local outVal = self:GetOutputValue(basics, nil, getPrice) or 0
                local cost = self:ReagentsCost(reagents, getPrice) + self:FixedReagentsCost(basics, getPrice)
                return outVal - cost, { concentrationCost = 0 }, outVal - cost
            end
            return nil
        end
        local outVal = self:GetOutputValue(basics, norm.quality, getPrice) or 0
        local cost = self:ReagentsCost(reagents, getPrice) + self:FixedReagentsCost(basics, getPrice)
        local adjOut, adjCost = self:AdjustEconomics(norm, outVal, cost)
        return adjOut - adjCost, norm, outVal - cost
    end

    local concBudget = tonumber(opts.concBudget) or 0
    local function objectiveOf(profit, norm, useConc)
        if useConc and concBudget > 0 and norm then
            local cc = norm.concentrationCost or 0
            if cc > 0 then
                return profit * (concBudget / cc)
            end
        end
        return profit
    end

    local function optimize(useConc)
        local extraByDS = {}
        local alloc = NewAllocAllTier(basics, 1)

        local bestProfit, bestNorm = evalAlloc(alloc, extraByDS, useConc)
        if not bestProfit then return nil end
        local bestObj = objectiveOf(bestProfit, bestNorm, useConc)
        local bestAlloc = CopyAlloc(alloc)

        local maxSteps = 0
        for _, slot in ipairs(basics.basicSlots) do
            maxSteps = maxSteps + slot.quantity * math.max(0, slot.qualityCount - 1)
        end

        local curObj, curNorm = bestObj, bestNorm
        local guard = 0
        while guard < maxSteps + 2 do
            guard = guard + 1
            local curMetric = ProgressMetric(curNorm) or 0
            local gI, gU, gGain        
            local pI, pU, pScore       
            for i, slot in ipairs(basics.basicSlots) do
                if not self:IsLockedSlot(locked, slot.dataSlotIndex) then
                    -- units of the same tier in a slot are identical: evaluate one
                    -- representative per current tier instead of every single unit.
                    local repByTier = {}
                    for u = 1, slot.quantity do
                        local t = alloc[i][u]
                        if t < slot.qualityCount and not repByTier[t] then
                            repByTier[t] = u
                        end
                    end
                    for t, u in pairs(repByTier) do
                        alloc[i][u] = t + 1
                        local p, n = evalAlloc(alloc, extraByDS, useConc)
                        alloc[i][u] = t
                        if p then
                            local gain = objectiveOf(p, n, useConc) - curObj
                            if not gGain or gain > gGain then gGain, gI, gU = gain, i, u end
                            local prog = (ProgressMetric(n) or curMetric) - curMetric
                            if prog > 0 then
                                local o1 = slot.options[t];     local pr1 = o1 and getPrice(o1.itemID or o1) or 0
                                local o2 = slot.options[t + 1]; local pr2 = o2 and getPrice(o2.itemID or o2) or 0
                                local d = (pr2 or 0) - (pr1 or 0); if d <= 0 then d = 1 end
                                local score = prog / d
                                if not pScore or score > pScore then pScore, pI, pU = score, i, u end
                            end
                        end
                    end
                end
            end

            local mi, mu
            if gGain and gGain > 0 then
                mi, mu = gI, gU
            elseif pI then
                mi, mu = pI, pU       
            else
                break
            end
            alloc[mi][mu] = alloc[mi][mu] + 1
            local p, n = evalAlloc(alloc, extraByDS, useConc)
            if not p then break end
            curNorm = n
            curObj = objectiveOf(p, n, useConc)
            if curObj > bestObj then
                bestObj, bestProfit, bestNorm = curObj, p, n
                bestAlloc = CopyAlloc(alloc)
            end
        end

        if not opts.skipExtras and #extraSlots > 0 then
            alloc = CopyAlloc(bestAlloc)
            for _, e in ipairs(extraSlots) do
                local slot = e.slot
                local ds = slot.dataSlotIndex
                local choices = (e.finishing and slot.locked) and {} or self:GetSlotOptions(slot, e.finishing)
                local keep = extraByDS[ds]
                local bp, bn = evalAlloc(alloc, extraByDS, useConc)
                local baseObj = bp and objectiveOf(bp, bn, useConc) or bestObj
                for _, opt in ipairs(choices) do
                    extraByDS[ds] = opt
                    local p, n = evalAlloc(alloc, extraByDS, useConc)
                    local o = p and objectiveOf(p, n, useConc)
                    if o and o > baseObj then baseObj, keep = o, opt end
                end
                extraByDS[ds] = keep
            end
            local p2, n2 = evalAlloc(alloc, extraByDS, useConc)
            if p2 then
                local o2 = objectiveOf(p2, n2, useConc)
                if o2 >= bestObj then
                    bestObj, bestProfit, bestNorm, bestAlloc = o2, p2, n2, CopyAlloc(alloc)
                end
            end
        end

        local mixByDS = {}
        for i, slot in ipairs(basics.basicSlots) do
            local m = {}
            for _, t in ipairs(bestAlloc[i]) do m[t] = (m[t] or 0) + 1 end
            mixByDS[slot.dataSlotIndex] = m
        end
        local extraMap = {} ; for k, v in pairs(extraByDS) do extraMap[k] = v end
        local baseProfit = select(3, evalAlloc(bestAlloc, extraByDS, useConc))

        return {
            profit            = bestProfit,
            baseProfit        = baseProfit,
            score             = bestObj,
            quality           = bestNorm and bestNorm.quality,
            qualityFloat      = bestNorm and bestNorm.qualityFloat,
            concentrationCost = bestNorm and bestNorm.concentrationCost or 0,
            mixByDataSlot     = mixByDS,
            extraByDataSlot   = extraMap,
        }
    end

    local noConc = optimize(false)
    local conc = optimize(true)
    local concValue
    if noConc and conc and conc.concentrationCost and conc.concentrationCost > 0 then
        concValue = (conc.profit - noConc.profit) / conc.concentrationCost
    end
    return {
        noConc             = noConc,
        conc               = conc,
        concentrationValue = concValue,
        outputItemIDs      = basics.outputItemIDs,
    }
end

function CE:SolveForOrder(order, opts)
    if type(order) ~= "table" or not order.spellID then return nil end
    local targetQ = tonumber(order.minQuality) or tonumber(order.quality) or 1
    opts = opts or {}
    opts.orderID = order.orderID
    return self:SolveForQuality(order.spellID, targetQ, opts)
end

function CE:ResolveSpecSkillLine(spellID)
    local sl
    if C_TradeSkillUI.GetProfessionChildSkillLineID then
        local ok, child = pcall(C_TradeSkillUI.GetProfessionChildSkillLineID)
        if ok and child and child ~= 0 then sl = child end
    end
    if not sl and spellID and C_TradeSkillUI.GetProfessionInfoByRecipeID then
        local ok, pi = pcall(C_TradeSkillUI.GetProfessionInfoByRecipeID, spellID)
        if ok and type(pi) == "table" then sl = pi.professionID end
    end
    return sl
end

function CE:GetSpecOverview(spellID)
    local PS = _G.C_ProfSpecs
    if not PS or not _G.C_Traits then return nil end
    local sl = self:ResolveSpecSkillLine(spellID)
    if not sl or sl == 0 then return nil end
    if PS.SkillLineHasSpecialization and not PS.SkillLineHasSpecialization(sl) then return nil end
    local tabs = PS.GetSpecTabIDsForSkillLine and PS.GetSpecTabIDsForSkillLine(sl)
    if type(tabs) ~= "table" or #tabs == 0 then return nil end
    local configID = PS.GetConfigIDForSkillLine and PS.GetConfigIDForSkillLine(sl)
    if not configID then return nil end

    local function tryCall(fn, ...) if type(fn) ~= "function" then return nil end local ok, r = pcall(fn, ...) if ok then return r end end

    local cur = tryCall(PS.GetCurrencyInfoForSkillLine, sl)
    local out = {
        skillLine = sl,
        configID = configID,
        unspent = cur and cur.numAvailable or 0,
        currencyName = cur and cur.currencyName,
        tabs = {},
    }

    local function readNode(pathID)
        local ni = tryCall(C_Traits.GetNodeInfo, configID, pathID)
        local rank = ni and (ni.ranksPurchased or ni.currentRank or ni.activeRank)
        local maxR = ni and ni.maxRanks
        return tonumber(rank) or 0, tonumber(maxR) or 0
    end

    local STAT_KEYS = {
        ["Находчивост"] = "resourcefulness", ["находчивост"] = "resourcefulness",
        ["Изобретательност"] = "ingenuity", ["изобретательност"] = "ingenuity",
        ["Перепроизводств"] = "multicraft", ["перепроизводств"] = "multicraft",
        ["ультикрафт"] = "multicraft",
        ["Скорость изготовлен"] = "speed", ["корость изготовлен"] = "speed",
    }
    local STAT_RU = { resourcefulness = "Находчивость", ingenuity = "Изобретательность",
        multicraft = "Мультикрафт", speed = "Скорость", skill = "Навык", quality = "Качество" }
    local function parseEffect(desc)
        if type(desc) ~= "string" then return nil end
        local stat
        for key, sk in pairs(STAT_KEYS) do if desc:find(key, 1, true) then stat = sk break end end
        if not stat then
            if desc:find("навык", 1, true) or desc:find("Мастерств", 1, true) then stat = "skill"
            elseif desc:find("ачеств", 1, true) then stat = "quality" end
        end
        local n = desc:match("на (%d+) за каждое очко") or desc:match("на (%d+) за очко")
        return stat, tonumber(n)
    end

    local function pathName(pathID)
        local se = tryCall(PS.GetSpendEntryForPath, pathID)
        local ei = se and tryCall(C_Traits.GetEntryInfo, configID, se)
        local defID = ei and ei.definitionID
        local di = defID and tryCall(C_Traits.GetDefinitionInfo, defID)
        if type(di) ~= "table" then return nil end
        if di.overrideName and di.overrideName ~= "" then return di.overrideName end
        local sid = di.spellID or di.overriddenSpellID
        if sid then
            local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(sid)
            if type(info) == "table" and info.name then return info.name end
            if GetSpellInfo then local nm = GetSpellInfo(sid); if nm then return nm end end
        end
        return nil
    end

    local function pathIcon(pathID)
        local ni = tryCall(C_Traits.GetNodeInfo, configID, pathID)
        if type(ni) ~= "table" or type(ni.entryIDs) ~= "table" then return nil end
        for _, entryID in ipairs(ni.entryIDs) do
            local ei = tryCall(C_Traits.GetEntryInfo, configID, entryID)
            local di = ei and ei.definitionID and tryCall(C_Traits.GetDefinitionInfo, ei.definitionID)
            if type(di) == "table" then
                if di.overrideIcon then return di.overrideIcon end
                local sid = di.spellID or di.overriddenSpellID
                if sid then
                    local tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(sid)
                    if tex then return tex end
                end
            end
        end
        return nil
    end

    local function collectPaths(pathID, depth, list, statSet)
        if depth > 8 then return end
        local rank, maxR = readNode(pathID)
        if maxR > 0 then maxR = maxR - 1 end
        rank = rank > 0 and (rank - 1) or 0
        local desc = tryCall(PS.GetDescriptionForPath, pathID, configID)
        local stat, perPoint = parseEffect(desc)
        if stat and statSet then statSet[stat] = true end
        local entry = {
            pathID = pathID,
            rank = rank,
            maxRank = maxR,
            depth = depth,
            name = pathName(pathID),
            icon = pathIcon(pathID),
            description = desc,
            stat = stat,
            statName = stat and STAT_RU[stat],
            perPoint = perPoint,
            state = tryCall(PS.GetStateForPath, pathID, configID),
        }
        list[#list + 1] = entry
        local children = tryCall(PS.GetChildrenForPath, pathID, configID)
        if type(children) == "table" then
            for _, ch in ipairs(children) do collectPaths(ch, depth + 1, list, statSet) end
        end
    end

    for _, tabID in ipairs(tabs) do
        local info = tryCall(PS.GetTabInfo, tabID)
        local state = tryCall(PS.GetStateForTab, tabID, configID)
        local root = tryCall(PS.GetRootPathForTab, tabID)
        local paths, statSet = {}, {}
        if root then collectPaths(root, 0, paths, statSet) end
        local invested, capacity = 0, 0
        for _, p in ipairs(paths) do
            invested = invested + p.rank
            capacity = capacity + p.maxRank
        end
        out.tabs[#out.tabs + 1] = {
            tabID = tabID,
            name = info and info.name,
            icon = info and info.rootIconID,
            description = info and info.description,
            sourceText = tryCall(PS.GetSourceTextForPath, root, configID),
            state = state,
            unlocked = state == 2 or state == 3,
            invested = invested,
            capacity = capacity,
            paths = paths,
            statSet = statSet,
        }
    end

    local learned = spellID and self.SpecLearnedForRecipe and self:SpecLearnedForRecipe(sl, spellID)
    out.hasLearned = learned ~= nil
    if learned then
        for _, tab in ipairs(out.tabs) do
            local stats = {}
            for _, p in ipairs(tab.paths) do
                local st = learned[p.pathID]
                if st then tab.learnedRelevant = true; stats[st] = true; p.relevant = true; p.relStat = st end
            end
            if tab.learnedRelevant then
                local names = {}
                for st in pairs(stats) do names[#names + 1] = st end
                tab.learnedStats = names
            end
        end
    end
    return out
end

function CE:DumpRecipe(spellID)
    local basics = self:GetRecipeBasics(spellID)
    if not basics then
        print("|cffff5555CE|r no schematic for " .. tostring(spellID))
        return
    end
    print(string.format("|cffb19cd9CraftEngine recipe|r spell=%d maxQ=%d slots=%d",
        spellID, basics.maxQuality, #basics.basicSlots))
    for i, s in ipairs(basics.basicSlots) do
        print(string.format("  slot#%d ds=%d qty=%d tiers=%d firstItem=%s",
            i, s.dataSlotIndex, s.quantity, s.qualityCount,
            tostring(s.options[1] and s.options[1].itemID)))
    end

    local recipeInfo = basics.recipeInfo
    local skillLineID = recipeInfo and (recipeInfo.skillLineID or recipeInfo.parentSkillLineID)
    if skillLineID then
        local stats = self:GetProfessionStats(skillLineID)
        if stats then
            print(string.format("  prof %s lvl=%d/%d mod=+%d total=%d",
                tostring(stats.professionName), stats.skillLevel, stats.maxSkillLevel,
                stats.skillModifier, stats.totalSkill))
        end
    end
end

local function ResolveCurrentSpellID(msg)
    local id = tonumber(msg)
    if id then return id end

    if PT.RecipeList and PT.RecipeList._simRecipe then
        return tonumber(PT.RecipeList._simRecipe)
    end

    if C_TradeSkillUI and C_TradeSkillUI.GetCurrentRecipeID then
        local ok, cur = pcall(C_TradeSkillUI.GetCurrentRecipeID)
        if ok and tonumber(cur) then return tonumber(cur) end
    end

    local form = ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.SchematicForm
    if form and form.GetRecipeInfo then
        local ok, ri = pcall(form.GetRecipeInfo, form)
        if ok and type(ri) == "table" and tonumber(ri.recipeID) then
            return tonumber(ri.recipeID)
        end
    end

    if form and form.currentRecipeInfo and tonumber(form.currentRecipeInfo.recipeID) then
        return tonumber(form.currentRecipeInfo.recipeID)
    end

    return nil
end

local function ResolveOrderID(spellID)
    if C_CraftingOrders and C_CraftingOrders.GetClaimedOrder then
        local ok, o = pcall(C_CraftingOrders.GetClaimedOrder)
        if ok and type(o) == "table" and o.spellID == spellID then return o.orderID end
    end
    return nil
end

local function FmtGold(copper)
    if not copper then return "—" end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    return string.format("%dg %ds", g, s)
end

SLASH_PHCEAPI1 = "/phceapi"
SlashCmdList["PHCEAPI"] = function()
    if not C_TradeSkillUI then print("|cffff5555CE|r no C_TradeSkillUI") return end
    print("|cffb19cd9CraftEngine API|r функции C_TradeSkillUI (Operation/Crafting/Quality/Reagent):")
    local names = {}
    for k, v in pairs(C_TradeSkillUI) do
        if type(v) == "function" then
            local lk = k:lower()
            if lk:find("operation") or lk:find("crafting") or lk:find("quality") or lk:find("reagent") or lk:find("difficulty") then
                names[#names + 1] = k
            end
        end
    end
    table.sort(names)
    for _, n in ipairs(names) do print("   C_TradeSkillUI." .. n) end
    print("   ---")
    print("   GetCraftingOperationInfo = " .. type(C_TradeSkillUI.GetCraftingOperationInfo))
    print("   GetCraftingOperationInfoForOrder = " .. type(C_TradeSkillUI.GetCraftingOperationInfoForOrder))
    print("   GetRecipeOperationInfo = " .. type(C_TradeSkillUI.GetRecipeOperationInfo))
end

SLASH_PHCEPROBE1 = "/phceop"
SlashCmdList["PHCEPROBE"] = function(msg)
    local id = ResolveCurrentSpellID(msg)
    if not id then
        print("|cffff5555CE|r usage: /phceop <spellID> (or open a recipe first)")
        return
    end
    CE:Probe(id, ResolveOrderID(id))
end

SLASH_PHCEDUMP1 = "/phcedump"
SlashCmdList["PHCEDUMP"] = function(msg)
    local id = ResolveCurrentSpellID(msg)
    if not id then
        print("|cffff5555CE|r usage: /phcedump <spellID> (or open a recipe first)")
        return
    end
    CE:DumpRecipe(id)
end

SLASH_PHCEOPT1 = "/phceopt"
SlashCmdList["PHCEOPT"] = function(msg)
    local id = ResolveCurrentSpellID(msg ~= "" and msg or nil)
    if not id then
        print("|cffff5555CE|r usage: /phceopt [spellID] (or open a recipe)")
        return
    end
    local r = CE:OptimizeProfit(id, { orderID = ResolveOrderID(id) })
    if not r then print("|cffff5555CE|r no recipe data") return end

    local basics = CE:GetRecipeBasics(id)
    print(string.format("|cffb19cd9CraftEngine optimize|r spell=%d  out=%s  optionalSlots=%d finishingSlots=%d",
        id, basics and basics.outputItemIDs and ("#" .. #basics.outputItemIDs) or "nil",
        basics and #basics.optionalSlots or 0, basics and #basics.finishingSlots or 0))

    local CRT = Enum and Enum.CraftingReagentType
    print(string.format("   |cffaaaaaaenum Basic=%s Finishing=%s Modifying=%s|r",
        tostring(CRT and CRT.Basic), tostring(CRT and CRT.Finishing), tostring(CRT and CRT.Modifying)))

    if basics and basics.outputItemIDs then
        print(string.format("   |cffffd24aoutputQuantity=%s|r", tostring(basics.outputQuantity)))
        for q, oid in ipairs(basics.outputItemIDs) do
            local nm = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(oid)) or "?"
            local price = CE:DefaultPrice(oid)
            print(string.format("   out Q%d: id=%s  %s  price=%s", q, tostring(oid), tostring(nm), FmtGold(price)))
        end
    end
    if basics and basics.schematic and basics.schematic.reagentSlotSchematics then
        for i, slot in ipairs(basics.schematic.reagentSlotSchematics) do
            print(string.format("   slot#%d type=%s required=%s #reagents=%s ds=%s",
                i, tostring(slot.reagentType), tostring(slot.required),
                tostring(slot.reagents and #slot.reagents or 0), tostring(slot.dataSlotIndex)))
        end
    end

    local function dumpExtraSlots(label, slots)
        if not slots or #slots == 0 then return end
        for _, s in ipairs(slots) do
            local opts = {}
            for _, o in ipairs(s.options or {}) do
                local nm = (C_Item and C_Item.GetItemNameByID and o.itemID and C_Item.GetItemNameByID(o.itemID)) or tostring(o.itemID)
                opts[#opts + 1] = nm
            end
            print(string.format("   |cffaaaaaa%s ds=%s: %s|r", label, tostring(s.dataSlotIndex), table.concat(opts, ", ")))
        end
    end
    dumpExtraSlots("завершающий", basics and basics.finishingSlots)
    dumpExtraSlots("опциональный", basics and basics.optionalSlots)

    local function line(tag, info)
        if not info then print("   " .. tag .. ": nil") return end
        print(string.format("   %s: Q%s  out=%s  reg=%s  conc=%s  |cff55ff55профит=%s|r",
            tag, tostring(info.quality), FmtGold(info.outputValue), FmtGold(info.reagentCost),
            tostring(info.concentrationCost), FmtGold(info.profit)))
        if info.extraByDataSlot then
            for ds, opt in pairs(info.extraByDataSlot) do
                if opt and opt.itemID then
                    local nm = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(opt.itemID)) or ("item:" .. opt.itemID)
                    print("      |cff66ccff+ доп/завершающий выбран:|r " .. nm)
                end
            end
        end
    end
    line("без конц", r.noConc)
    line("с конц  ", r.conc)
    if r.concentrationValue then
        print(string.format("   |cffffd24dцена 1 конц = %s|r", FmtGold(r.concentrationValue)))
    else
        print("   |cffaaaaaaцена концентрации: н/д (нет цен или конц не выгодна)|r")
    end
end

local function IsProfGearEquipLoc(loc)
    return loc == "INVTYPE_PROFESSION_TOOL" or loc == "INVTYPE_PROFESSION_GEAR"
end

SLASH_PHCETOOL1 = "/phcetool"
SlashCmdList["PHCETOOL"] = function()
    print("|cffb19cd9CraftEngine|r инструменты/гир профессии в сумках:")
    local found = 0
    for bag = 0, 5 do
        local slots = (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag)) or 0
        for slot = 1, slots do
            local itemID = C_Container.GetContainerItemID and C_Container.GetContainerItemID(bag, slot)
            if itemID then
                local _, _, _, equipLoc = C_Item.GetItemInfoInstant(itemID)
                if IsProfGearEquipLoc(equipLoc) then
                    found = found + 1
                    local info = C_Container.GetContainerItemInfo(bag, slot)
                    local link = info and info.hyperlink
                    local ilvl = (C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(link or itemID)) or "?"
                    print(string.format("  |cff66ccff%s|r  equipLoc=%s ilvl=%s", tostring(link), equipLoc, tostring(ilvl)))
                    local stats = link and C_Item.GetItemStats and C_Item.GetItemStats(link)
                    if type(stats) == "table" then
                        for k, v in pairs(stats) do
                            print(string.format("     %s = %s", tostring(k), tostring(v)))
                        end
                    else
                        print("     (GetItemStats: нет данных — возможно нужен прогрев item, повтори команду)")
                    end
                end
            end
        end
    end
    if found == 0 then
        print("  |cffaaaaaaинструментов профессии в сумках не найдено|r")
    end
end

SLASH_PHCEOUT1 = "/phceout"
SlashCmdList["PHCEOUT"] = function(msg)
    local id = ResolveCurrentSpellID(msg ~= "" and msg or nil)
    if not id then print("|cffff5555CE|r usage: /phceout [spellID]") return end
    print(string.format("|cffb19cd9CraftEngine out-probe|r spell=%d", id))

    if C_TradeSkillUI.GetRecipeInfo then
        local ok, ri = pcall(C_TradeSkillUI.GetRecipeInfo, id)
        if ok and type(ri) == "table" then
            print("|cff88ff88recipeInfo:|r")
            local keys = {}
            for k in pairs(ri) do keys[#keys + 1] = k end
            table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
            for _, k in ipairs(keys) do
                local v = ri[k]
                if type(v) ~= "table" then
                    print(string.format("   %s = %s", tostring(k), tostring(v)))
                end
            end
        end
    end

    if C_TradeSkillUI.GetRecipeSchematic then
        local ok, s = pcall(C_TradeSkillUI.GetRecipeSchematic, id, false)
        if ok and type(s) == "table" then
            print("|cff88ff88schematic (выходные поля):|r")
            for _, k in ipairs({ "outputItemID", "recipeType", "hasCraftingOperationInfo", "quantityMin", "quantityMax" }) do
                print(string.format("   %s = %s", k, tostring(s[k])))
            end
            if type(s.outputItemData) == "table" then
                for k, v in pairs(s.outputItemData) do
                    if type(v) ~= "table" then print(string.format("   outputItemData.%s = %s", tostring(k), tostring(v))) end
                end
            end
        end
    end

    if C_TradeSkillUI.GetRecipeQualityItemIDs then
        local ok, ids = pcall(C_TradeSkillUI.GetRecipeQualityItemIDs, id)
        print("   GetRecipeQualityItemIDs = " .. (ok and type(ids) == "table" and ("#" .. #ids) or tostring(ids)))
        if ok and type(ids) == "table" then
            for q, oid in ipairs(ids) do print("      Q" .. q .. " = " .. tostring(oid)) end
        end
    end

    if C_TradeSkillUI.GetRecipeOutputItemData then
        print("|cff88ff88GetRecipeOutputItemData:|r")
        local function dumpOut(label, ...)
            local ok, data = pcall(C_TradeSkillUI.GetRecipeOutputItemData, ...)
            if ok and type(data) == "table" then
                print(string.format("   %s: itemID=%s qualityID=%s hyperlink=%s",
                    label, tostring(data.itemID), tostring(data.qualityID), tostring(data.hyperlink)))
            else
                print("   " .. label .. ": " .. tostring(data))
            end
        end
        dumpOut("base", id)
        for q = 1, 3 do
            dumpOut("Q" .. q, id, nil, nil, q)
        end
    end

    if C_TradeSkillUI.GetQualitiesForRecipe then
        local ok, q = pcall(C_TradeSkillUI.GetQualitiesForRecipe, id)
        if ok and type(q) == "table" then
            local parts = {}
            for _, v in ipairs(q) do parts[#parts + 1] = tostring(v) end
            print("   GetQualitiesForRecipe = " .. table.concat(parts, ", "))
        end
    end
end

SLASH_PHCESLOT1 = "/phceslot"
SlashCmdList["PHCESLOT"] = function(msg)
    local rid = ResolveCurrentSpellID(msg ~= "" and msg or nil)
    if not rid then print("|cffff5555CE|r выбери рецепт") return end
    local sch = select(2, pcall(C_TradeSkillUI.GetRecipeSchematic, rid, false))
    if type(sch) ~= "table" then print("|cffff5555CE|r нет схемы") return end
    local ri = select(2, pcall(C_TradeSkillUI.GetRecipeInfo, rid))
    print("|cffb19cd9CE slot-probe|r recipe=" .. tostring(rid) .. " slots=" .. tostring(sch.reagentSlotSchematics and #sch.reagentSlotSchematics))
    local Prof = _G.Professions
    for i, slot in ipairs(sch.reagentSlotSchematics or {}) do
        local nopts = slot.reagents and #slot.reagents or 0
        local line = string.format("  #%d ds=%s type=%s req=%s qty=%s opts=%d",
            i, tostring(slot.dataSlotIndex), tostring(slot.reagentType), tostring(slot.required),
            tostring(slot.quantityRequired), nopts)
        if Prof and Prof.GetReagentSlotStatus then
            local st = select(2, pcall(Prof.GetReagentSlotStatus, slot, ri))
            line = line .. " | slotStatus=" .. tostring(st)
        end
        print(line)
        if type(slot.slotInfo) == "table" then
            local t = {}
            for k, v in pairs(slot.slotInfo) do if type(v) ~= "table" then t[#t + 1] = k .. "=" .. tostring(v) end end
            if #t > 0 then print("      slotInfo: " .. table.concat(t, " ")) end
        end
        local s = {}
        for k, v in pairs(slot) do if type(v) ~= "table" and k ~= "dataSlotIndex" and k ~= "reagentType" and k ~= "required" and k ~= "quantityRequired" and k ~= "slotIndex" then s[#s + 1] = k .. "=" .. tostring(v) end end
        if #s > 0 then print("      slot: " .. table.concat(s, " ")) end
    end
    print("  |cff888888Enum.ReagentSlotStatus:|r " .. (Enum and Enum.ReagentSlotStatus and (function() local t={} for k,v in pairs(Enum.ReagentSlotStatus) do t[#t+1]=k.."="..tostring(v) end return table.concat(t," ") end)() or "нет"))
end

SLASH_PHCESTAGE1 = "/phcestage"
SlashCmdList["PHCESTAGE"] = function(msg)
    local PS, CT = _G.C_ProfSpecs, _G.C_Traits
    if not PS or not CT then print("|cffff5555CE|r нет C_ProfSpecs/C_Traits") return end
    local rid = ResolveCurrentSpellID(msg ~= "" and msg or nil)
    if not rid then print("|cffff5555CE|r выбери рецепт в симуляторе") return end
    local sl = CE:ResolveSpecSkillLine(rid)
    local configID = sl and PS.GetConfigIDForSkillLine(sl)
    if not configID then print("|cffff5555CE|r нет configID") return end

    local function tryCall(fn, ...) if type(fn) ~= "function" then return nil, "no fn" end local r = { pcall(fn, ...) } if r[1] then return r[2], r[3] else return nil, r[2] end end

    local function readStats()
        local op = select(1, tryCall(C_TradeSkillUI.GetCraftingOperationInfo, rid, {}, nil, false))
        if type(op) ~= "table" then return nil, "нет op" end
        local s = { skill = (op.baseSkill or 0) + (op.bonusSkill or 0) }
        local parts = { "skill=" .. s.skill }
        if type(op.bonusStats) == "table" then
            for _, bs in ipairs(op.bonusStats) do
                local nm = bs.bonusStatName or "?"
                s[nm] = bs.ratingPct or bs.bonusStatValue or 0
                parts[#parts + 1] = string.format("%s=%.2f", nm, s[nm])
            end
        end
        return s, table.concat(parts, "  ")
    end

    local cfgInfo = select(1, tryCall(CT.GetConfigInfo, configID))
    if type(cfgInfo) == "table" then
        local t = {}; for k, v in pairs(cfgInfo) do if type(v) ~= "table" then t[#t + 1] = k .. "=" .. tostring(v) end end
        print("   configInfo: " .. table.concat(t, " "))
    end

    local target, tRank
    local tabs = PS.GetSpecTabIDsForSkillLine(sl) or {}
    for _, tabID in ipairs(tabs) do
        local root = PS.GetRootPathForTab(tabID)
        local stack, all = { root }, {}
        while #stack > 0 do
            local pid = table.remove(stack)
            all[#all + 1] = pid
            local kids = select(1, tryCall(PS.GetChildrenForPath, pid, configID))
            if type(kids) == "table" then for _, k in ipairs(kids) do stack[#stack + 1] = k end end
        end
        for _, pid in ipairs(all) do
            local ni = select(1, tryCall(CT.GetNodeInfo, configID, pid))
            if type(ni) == "table" and (ni.currentRank or 0) > 1 then
                local kids = select(1, tryCall(PS.GetChildrenForPath, pid, configID)) or {}
                local childSpent = false
                for _, k in ipairs(kids) do
                    local kn = select(1, tryCall(CT.GetNodeInfo, configID, k))
                    if kn and (kn.currentRank or 0) > 1 then childSpent = true break end
                end
                local canR = select(1, tryCall(PS.CanRefundPath, pid, configID))
                if not childSpent and canR then target, tRank = pid, ni.currentRank; break end
                if not target then target, tRank = pid, ni.currentRank end
            end
        end
        if target then break end
    end
    if not target then print("|cffff5555CE|r не нашёл прокачанный узел") return end
    local canRef = select(1, tryCall(PS.CanRefundPath, target, configID))
    print(string.format("|cffb19cd9CE stage-probe|r recipe=%d node=%s rank=%s CanRefundPath=%s",
        rid, tostring(target), tostring(tRank), tostring(canRef)))

    local before, bStr = readStats()
    print("   ДО:    " .. tostring(bStr))

    local okR, errR = tryCall(CT.RefundRank, configID, target)
    local niAfter = select(1, tryCall(CT.GetNodeInfo, configID, target))
    print(string.format("   RefundRank ok=%s err=%s → staged rank=%s",
        tostring(okR), tostring(errR), tostring(niAfter and niAfter.currentRank)))

    local after, aStr = readStats()
    print("   ПОСЛЕ: " .. tostring(aStr))

    if before and after then
        local changed = {}
        for k, v in pairs(before) do
            local d = (after[k] or 0) - v
            if math.abs(d) > 0.001 then changed[#changed + 1] = string.format("%s %+.2f", k, d) end
        end
        if #changed > 0 then
            print("   |cff55ff55ОРАКУЛ ВИДИТ СТЕЙДЖ! изменилось:|r " .. table.concat(changed, ", "))
        else
            print("   |cffff8844оракул НЕ реагирует на стейдж (читает закоммиченный конфиг)|r")
        end
    end

    local okRb, errRb = tryCall(CT.RollbackConfig, configID)
    local niRb = select(1, tryCall(CT.GetNodeInfo, configID, target))
    print(string.format("   RollbackConfig ok=%s err=%s → rank=%s (должно быть %s)",
        tostring(okRb), tostring(errRb), tostring(niRb and niRb.currentRank), tostring(tRank)))
end

SLASH_PHCECOND1 = "/phcecond"
SlashCmdList["PHCECOND"] = function(msg)
    local PS, CT = _G.C_ProfSpecs, _G.C_Traits
    if not PS or not CT then print("|cffff5555CE|r нет C_ProfSpecs/C_Traits") return end
    local rid = ResolveCurrentSpellID(msg ~= "" and msg or nil)
    local sl = (CE.ResolveSpecSkillLine and CE:ResolveSpecSkillLine(rid))
    if not sl then print("|cffff5555CE|r нет skillLine") return end
    local configID = PS.GetConfigIDForSkillLine(sl)
    print("|cffb19cd9CE cond-probe|r recipe=" .. tostring(rid) .. " skillLine=" .. tostring(sl) .. " cfg=" .. tostring(configID))
    print("   recipe catID=" .. tostring(select(2, pcall(function() local i = C_TradeSkillUI.GetRecipeInfo(rid) return i and i.categoryID end))))

    local function tryCall(fn, ...) if type(fn) ~= "function" then return nil end local ok, r = pcall(fn, ...) if ok then return r end end
    local function dumpAll(label, t, indent)
        indent = indent or "   "
        if type(t) ~= "table" then print(indent .. label .. " = " .. tostring(t)) return end
        local scal, arr = {}, {}
        for k, v in pairs(t) do
            if type(v) == "table" then arr[#arr + 1] = k else scal[#scal + 1] = k .. "=" .. tostring(v) end
        end
        print(indent .. label .. ": " .. table.concat(scal, " "))
        for _, k in ipairs(arr) do
            local v = t[k]
            local vals = {}
            for _, x in ipairs(v) do vals[#vals + 1] = tostring(x) end
            print(indent .. "  ." .. k .. " = {" .. table.concat(vals, ",") .. "}")
        end
    end

    local tabs = PS.GetSpecTabIDsForSkillLine(sl)
    for ti, tabID in ipairs(tabs or {}) do
        local root = PS.GetRootPathForTab(tabID)
        local kids = tryCall(PS.GetChildrenForPath, root, configID) or {}
        local probePath = kids[1] or root
        local info = tryCall(PS.GetTabInfo, tabID)
        print(string.format("|cffffd24aTAB %s '%s' path=%s|r", tostring(tabID), tostring(info and info.name), tostring(probePath)))
        local ni = tryCall(CT.GetNodeInfo, configID, probePath)
        if type(ni) == "table" then dumpAll("nodeInfo", ni) end
        local se = tryCall(PS.GetSpendEntryForPath, probePath)
        local ei = se and tryCall(CT.GetEntryInfo, configID, se)
        if type(ei) == "table" then dumpAll("entryInfo", ei) end
        local condIDs = (ni and ni.conditionIDs) or (ei and ei.conditionIDs)
        if type(condIDs) == "table" and CT.GetConditionInfo then
            for _, cid in ipairs(condIDs) do
                local ci = tryCall(CT.GetConditionInfo, configID, cid)
                dumpAll("cond[" .. tostring(cid) .. "]", ci, "      ")
            end
        end
        if ti >= 2 then break end
    end
end

SLASH_PHCEREC1 = "/phcerec"
SlashCmdList["PHCEREC"] = function(msg)
    local rid = ResolveCurrentSpellID(msg ~= "" and msg or nil)
    if not rid then print("|cffff5555CE|r нет рецепта (выбери в симуляторе)") return end
    print("|cffb19cd9CE rec-spec probe|r recipe=" .. tostring(rid))
    local function dumpFields(label, t)
        if type(t) ~= "table" then print("   " .. label .. " = " .. tostring(t)) return end
        local s = {}
        for k, v in pairs(t) do if type(v) ~= "table" then s[#s + 1] = k .. "=" .. tostring(v) end end
        print("   " .. label .. ": " .. table.concat(s, " "))
    end
    local hits = {}
    for k in pairs(C_TradeSkillUI) do
        if type(C_TradeSkillUI[k]) == "function" and (k:find("Spec") or k:find("Require") or k:find("Category")) then hits[#hits + 1] = k end
    end
    table.sort(hits)
    print("   |cff88ff88TSU fns:|r " .. table.concat(hits, ", "))

    local okRi, riT = pcall(C_TradeSkillUI.GetRecipeInfo, rid)
    if okRi then dumpFields("recipeInfo", riT) end

    local okS, sch = pcall(C_TradeSkillUI.GetRecipeSchematic, rid, false)
    if okS and type(sch) == "table" then
        dumpFields("schematic", sch)
        for k, v in pairs(sch) do
            if tostring(k):lower():find("spec") then print("   |cffffd24aschematic." .. k .. " = " .. tostring(v) .. "|r") end
        end
    end

    local catID = okRi and riT and riT.categoryID
    if catID and C_TradeSkillUI.GetCategoryInfo then
        local okC, ci = pcall(C_TradeSkillUI.GetCategoryInfo, catID)
        if okC then dumpFields("categoryInfo(" .. tostring(catID) .. ")", ci) end
    end

    local PS = _G.C_ProfSpecs
    if PS then
        for k in pairs(PS) do
            if type(PS[k]) == "function" and (k:find("Recipe") or k:find("Ability") or k:find("Source")) then
                print("   |cff88ff88PS fn:|r " .. k)
            end
        end
    end
end

SLASH_PHCESPEC1 = "/phcespec"
SlashCmdList["PHCESPEC"] = function(msg)
    local PS = _G.C_ProfSpecs
    if not PS then print("|cffff5555CE|r нет C_ProfSpecs") return end
    print("|cffb19cd9CraftEngine spec-probe|r")

    local fns = {}
    for k, v in pairs(PS) do if type(v) == "function" then fns[#fns + 1] = k end end
    table.sort(fns)
    print("|cff88ff88C_ProfSpecs функции:|r " .. table.concat(fns, ", "))

    local cands = {}
    if C_TradeSkillUI.GetBaseProfessionInfo then
        local ok, info = pcall(C_TradeSkillUI.GetBaseProfessionInfo)
        if ok and type(info) == "table" then
            print(string.format("   baseProf: professionID=%s skillLineID=%s name=%s",
                tostring(info.professionID), tostring(info.skillLineID), tostring(info.professionName)))
            cands[info.professionID or 0] = true
            cands[info.skillLineID or 0] = true
        end
    end
    if C_TradeSkillUI.GetProfessionChildSkillLineID then
        local ok, child = pcall(C_TradeSkillUI.GetProfessionChildSkillLineID)
        if ok and child then print("   childSkillLineID=" .. tostring(child)); cands[child] = true end
    end
    local rid = ResolveCurrentSpellID(msg ~= "" and msg or nil)
    if rid and C_TradeSkillUI.GetProfessionInfoByRecipeID then
        local ok, pi = pcall(C_TradeSkillUI.GetProfessionInfoByRecipeID, rid)
        if ok and type(pi) == "table" then
            print(string.format("   recipe %s prof: professionID=%s skillLineID=%s", tostring(rid),
                tostring(pi.professionID), tostring(pi.skillLineID)))
            cands[pi.professionID or 0] = true
            cands[pi.skillLineID or 0] = true
        end
    end

    local function tryCall(fn, ...)
        if type(fn) ~= "function" then return nil end
        local ok, r = pcall(fn, ...)
        if ok then return r end
        return nil
    end

    local function dumpPath(pathID, depth, configID)
        if depth > 6 then return end
        local state = tryCall(PS.GetStateForPath, pathID, configID)
        local spendEntry = tryCall(PS.GetSpendEntryForPath, pathID)
        local perks = tryCall(PS.GetPerksForPath, pathID) or {}
        local rank, maxRank, nodeID
        if spendEntry and _G.C_Traits then
            local einfo = tryCall(C_Traits.GetEntryInfo, configID, spendEntry)
            nodeID = einfo and einfo.nodeID
            if nodeID then
                local ninfo = tryCall(C_Traits.GetNodeInfo, configID, nodeID)
                if ninfo then
                    rank = ninfo.currentRank or ninfo.ranksPurchased or ninfo.activeRank
                    maxRank = ninfo.maxRanks
                end
            end
        end
        local earned = 0
        if type(perks) == "table" then
            for _, pk in ipairs(perks) do
                local ps = tryCall(PS.GetStateForPerk, pk, configID)
                if ps == 2 or ps == 3 then earned = earned + 1 end
            end
        end
        print(string.format("%spath=%s node=%s rank=%s/%s state=%s perks=%d earned=%d",
            string.rep("  ", depth + 1), tostring(pathID), tostring(nodeID),
            tostring(rank), tostring(maxRank), tostring(state),
            type(perks) == "table" and #perks or 0, earned))
        local children = tryCall(PS.GetChildrenForPath, pathID, configID) or {}
        if type(children) == "table" then
            for _, ch in ipairs(children) do dumpPath(ch, depth + 1, configID) end
        end
    end

    for sl in pairs(cands) do
        if sl and sl ~= 0 and PS.GetSpecTabIDsForSkillLine then
            local tabs = tryCall(PS.GetSpecTabIDsForSkillLine, sl)
            if type(tabs) == "table" and #tabs > 0 then
                local configID = tryCall(PS.GetConfigIDForSkillLine, sl)
                local curInfo = tryCall(PS.GetCurrencyInfoForSkillLine, sl)
                print(string.format("|cff88ff88skillLine %s → tabs#%d configID=%s|r", tostring(sl), #tabs, tostring(configID)))
                if type(curInfo) == "table" then
                    print("   currency: " .. table.concat((function() local t={} for k,v in pairs(curInfo) do if type(v)~="table" then t[#t+1]=k.."="..tostring(v) end end return t end)(), " "))
                end
                for ti2, tabID in ipairs(tabs) do
                    local info = tryCall(PS.GetSpecTabInfo, tabID)
                    if ti2 == 1 and type(info) == "table" then
                        local t = {}; for k, v in pairs(info) do if type(v) ~= "table" then t[#t+1]=k.."="..tostring(v) end end
                        print("   tabInfo fields: " .. table.concat(t, " "))
                    end
                    print(string.format("|cffffd24atab=%s name=%s|r", tostring(tabID), tostring(info and info.name)))
                    if ti2 == 1 then  
                        local root = tryCall(PS.GetRootPathForTab, tabID)
                        if root then dumpPath(root, 0, configID) end
                        local kids = tryCall(PS.GetChildrenForPath, root, configID)
                        local p1 = kids and kids[1]
                        if p1 then
                            print("|cff66ccffДЕТАЛЬ path=" .. tostring(p1) .. ":|r")
                            local se = tryCall(PS.GetSpendEntryForPath, p1)
                            local perks2 = tryCall(PS.GetPerksForPath, p1) or {}
                            print("   spendEntry=" .. tostring(se) .. " unlockEntry=" .. tostring(tryCall(PS.GetUnlockEntryForPath, p1)))
                            if se and _G.C_Traits then
                                local ei = tryCall(C_Traits.GetEntryInfo, configID, se)
                                local t = {}; if type(ei)=="table" then for k,v in pairs(ei) do if type(v)~="table" then t[#t+1]=k.."="..tostring(v) end end end
                                print("   entryInfo: " .. table.concat(t, " "))
                            end
                            if _G.C_Traits then
                                local ni = tryCall(C_Traits.GetNodeInfo, configID, p1)
                                if type(ni) == "table" then
                                    print(string.format("   |cff55ff55GetNodeInfo(cfg,%s): currentRank=%s ranksPurchased=%s maxRanks=%s|r",
                                        tostring(p1), tostring(ni.currentRank), tostring(ni.ranksPurchased), tostring(ni.maxRanks)))
                                end
                            end
                            print("   tabInfo2=" .. (function() local i=tryCall(PS.GetTabInfo, tabID); if type(i)~="table" then return tostring(i) end local t={} for k,v in pairs(i) do if type(v)~="table" then t[#t+1]=k.."="..tostring(v) end end return table.concat(t," ") end)())
                            print("   descPath=" .. tostring(tryCall(PS.GetDescriptionForPath, p1, configID)))
                            print("   srcPath=" .. tostring(tryCall(PS.GetSourceTextForPath, p1, configID)))
                            print("   descRoot=" .. tostring(tryCall(PS.GetDescriptionForPath, root, configID)))
                            print("   srcRoot=" .. tostring(tryCall(PS.GetSourceTextForPath, root, configID)))
                            local pk1 = perks2 and perks2[1]
                            pk1 = type(pk1)=="table" and (pk1.perkID or pk1.ID) or pk1
                            if pk1 then print("   descPerk1=" .. tostring(tryCall(PS.GetDescriptionForPerk, pk1, configID))) end
                        end
                    end
                end
            end
        end
    end
end

SLASH_PHCEQUICK1 = "/phcequick"
SlashCmdList["PHCEQUICK"] = function(msg)
    local id = ResolveCurrentSpellID(msg ~= "" and msg or nil)
    if not id then print("|cffff5555CE|r usage: /phcequick [spellID]") return end
    local basics = CE:GetRecipeBasics(id)
    if not basics then print("|cffff5555CE|r no basics") return end
    local getPrice = function(i) return CE:DefaultPrice(i) end
    local lowR  = CE:MakeReagents(basics, function() return 1 end)
    local highR = CE:MakeReagents(basics, function(s) return s.qualityCount end)
    local fixedCost = CE:FixedReagentsCost(basics, getPrice)
    print(string.format("|cffb19cd9QuickProfit dbg|r spell=%d  basicSlots=%d fixedCost=%s",
        id, #basics.basicSlots, FmtGold(fixedCost)))
    local function dbg(label, reagents, conc)
        local norm = CE:Evaluate(id, reagents, { useConcentration = conc })
        if not norm then print("   " .. label .. ": Evaluate=nil") return end
        local outVal, outItem = CE:GetOutputValue(basics, norm.quality, getPrice)
        local cost = CE:ReagentsCost(reagents, getPrice) + fixedCost
        local adjOut, adjCost = CE:AdjustEconomics(norm, outVal or 0, cost)
        print(string.format("   %s: Q=%s outItem=%s outVal=%s cost=%s профит=%s",
            label, tostring(norm.quality), tostring(outItem), FmtGold(outVal), FmtGold(cost), FmtGold(adjOut - adjCost)))
    end
    dbg("low  noConc", lowR, false)
    dbg("high noConc", highR, false)
    dbg("high  conc ", highR, true)
    print("   |cff55ff55QuickProfit() = " .. FmtGold(CE:QuickProfit(id)) .. "|r")
end

SLASH_PHCESOLVE1 = "/phcesolve"
SlashCmdList["PHCESOLVE"] = function(msg)
    local arg1, arg2 = msg:match("^(%S*)%s*(%S*)$")
    local id = ResolveCurrentSpellID(arg2 ~= "" and arg2 or nil)
    local targetQ = tonumber(arg1)
    if not id then
        print("|cffff5555CE|r usage: /phcesolve <targetQuality> [spellID] (or open a recipe)")
        return
    end
    if not targetQ then
        local oid = ResolveOrderID(id)
        if oid and C_CraftingOrders and C_CraftingOrders.GetClaimedOrder then
            local ok, o = pcall(C_CraftingOrders.GetClaimedOrder)
            if ok and type(o) == "table" then targetQ = tonumber(o.minQuality) end
        end
        targetQ = targetQ or 3
    end

    local plan = CE:SolveForQuality(id, targetQ, { orderID = ResolveOrderID(id) })
    if not plan then print("|cffff5555CE|r no plan") return end

    print(string.format("|cffb19cd9CraftEngine solve|r spell=%d target=Q%d", id, targetQ))
    print(string.format("  reachable=%s conc=%s concCost=%s achievedQ=%s(%.2f) cost=%s%s",
        tostring(plan.reachable), tostring(plan.needsConcentration),
        tostring(plan.concentrationCost), tostring(plan.achievedQuality),
        plan.achievedQualityFloat or 0, FmtGold(plan.cost),
        plan.pricedComplete and "" or " |cffaaaaaa(no full prices)|r"))
    for _, r in ipairs(plan.reagents or {}) do
        local name = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(r.itemID)) or ("item:" .. r.itemID)
        print(string.format("   x%d ds=%s  %s", r.quantity, tostring(r.dataSlotIndex), tostring(name)))
    end
end

PT.CraftingOrders = PT.CraftingOrders or {}
PT.CraftingOrders.QualityEngine = CE
