local PT = HironCraftProfit
if not PT then return end

PT.config = PT.config or {}

PT.SkinningCheck = PT.SkinningCheck or {}
local SC = PT.SkinningCheck
local L  = PT.L or {}

local function GetSkinningDisabledDB()
    PT.config.skinningDisabledTargets =
        PT.config.skinningDisabledTargets or {}
    return PT.config.skinningDisabledTargets
end

if HironCraftProfit_CharConfig and HironCraftProfit_CharConfig.skinningDisabledTargets then
    PT.config.skinningDisabledTargets =
        PT.config.skinningDisabledTargets or HironCraftProfit_CharConfig.skinningDisabledTargets
    HironCraftProfit_CharConfig.skinningDisabledTargets = nil
end

SC.SKINNING_SKILL_LINES = {
    2834, -- Skinning (DF)
    2882, -- Skinning (TWW)
    2917, -- Skinning (MIDNIGHT)
}

SC.ROOT_SKINNING_ID = 393

local lastOpenedSkillLine = nil

SC.TARGETS = {
    {
        id = "cobra_skin",
        questId = 74235,
        itemId  = 205413,
        skillLineID = 2834,
        guide = {
            lureItem = 193906,
            craftFrom = {
                { id = 197741, count = 10 },
            },
            zone = {
                map = 2133,
                x = 0.4400,
                y = 0.4780,
            },
            npc = {
                id       = 204831,
                name     = L["npc_magma_cobra"],
                minLevel = 60,
            },
        },
    },
    {
        id = "slatefang",
        questId = 84259,
        itemId = 219013,
        skillLineID = 2882,
        guide = {
            lureItem = 219008,
            craftFrom = {
                { id = 222739, count = 1 },
            },
            zone = {
                map = 2214,
                x = 0.5704,
                y = 0.4715,
            },
            npc = {
                id       = 228439,
                name     = L["npc_slatefang"],
                minLevel = 71,
            },
        },
    },
    {
        id = "midnight_eversong_lure",
        questId = 88545,
        itemId  = 238652,
        minExpansion = 12,
        skillLineID = 2917,
        guide = {
            lureItem = 238652,
            craftFrom = {
                { id = 238371, count = 8 },
                { id = 238366, count = 8 },
            },
            zone = {
                map = 2395,
                x = 0.42,
                y = 0.80,
            },
            npc = {
                id = 245688,
                name = L["npc_gloomclaw"],
                minLevel = 80,
            },
        },
    },
    {
        id = "midnight_zulaman_lure",
        questId = 88526,
        itemId  = 238653,
        minExpansion = 12,
        skillLineID = 2917,
        guide = {
            lureItem = 238653,
            craftFrom = {
                { id = 238382, count = 8 },
            },
            zone = {
                map = 2437,
                x = 0.48,
                y = 0.54,
            },
            npc = {
                id = 245699,
                name = L["npc_silverscale"],
                minLevel = 80,
            },
        },
    },
    {
        id = "midnight_harandar_lure",
        questId = 88531,
        itemId  = 238654,
        minExpansion = 12,
        skillLineID = 2917,
        guide = {
            lureItem = 238654,
            craftFrom = {
                { id = 238375, count = 8 },
                { id = 238374, count = 8 },
            },
            zone = {
                map = 2413,
                x = 0.66,
                y = 0.48,
            },
            npc = {
                id = 245690,
                name = L["npc_lumenfin"],
                minLevel = 80,
            },
        },
    },
    {
        id = "midnight_voidstorm_lure",
        questId = 88532,
        itemId  = 238655,
        minExpansion = 12,
        skillLineID = 2917,
        guide = {
            lureItem = 238655,
            craftFrom = {
                { id = 238373, count = 4 },
            },
            zone = {
                map = 2405,
                x = 0.54,
                y = 0.65,
            },
            npc = {
                id = 247096,
                name = L["npc_umbrafang"],
                minLevel = 80,
            },
        },
    },
    {
        id = "midnight_grand_beast_lure",
        questId = 88524,
        itemId  = 238656,
        minExpansion = 12,
        skillLineID = 2917,
        guide = {
            lureItem = 238656,
            craftFrom = {
                { id = 238380, count = 4 },
            },
            zone = {
                map = 2405,
                x = 0.4325,
                y = 0.8275,
            },
            npc = {
                id = 247101,
                name = L["npc_netherscythe"],
                minLevel = 80,
            },
        },
    },
}

function SC:IsTargetAvailable(target)
    if not target then
        return false
    end

    if not target.minExpansion then
        return true
    end

    if target.minExpansion == 12 then
        return true
    end

    return GetExpansionLevel() >= target.minExpansion
end

function SC:GetTargetName(target)
    if not target then
        return L["Unknown"] or "Unknown"
    end

    if target.itemId then
        local name = C_Item.GetItemNameByID(target.itemId)
        if name then
            return name
        end
    end

    if target.id and L[target.id] then
        return L[target.id]
    end

    return L["item not loaded"] or "Item not loaded"
end

SC.pendingWaypoint = nil

function SC:SetPendingWaypoint(item)
    if not item or not item.guide or not item.guide.zone then return end
    self.pendingWaypoint = item
end

if not SC._waypointTicker then
    SC._waypointTicker = C_Timer.NewTicker(0.2, function()
        SC:ProcessPendingWaypoint()
    end)
end

function SC:ProcessPendingWaypoint()
    local t = self.pendingWaypoint
    if not t then return end

    local zone = t.guide and t.guide.zone
    if not zone or not zone.map or not zone.x or not zone.y then return end

    if TomTom then
        TomTom:AddWaypoint(zone.map, zone.x, zone.y, {
            title = self:GetTargetName(t),
            persistent = false,
        })
        self.pendingWaypoint = nil
        return
    end

    if not C_Map.CanSetUserWaypointOnMap(zone.map) then
        return
    end

    C_Map.ClearUserWaypoint()

    local point = UiMapPoint.CreateFromCoordinates(zone.map, zone.x, zone.y)
    C_Map.SetUserWaypoint(point)

    if C_SuperTrack then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end

    self.pendingWaypoint = nil
end

SC._npcNameCache = SC._npcNameCache or {}
SC._mapNameCache = SC._mapNameCache or {}

local function GetNPCName(npc)
    local id, overrideName

    if type(npc) == "table" then
        id = tonumber(npc.id)
        overrideName = npc.name
    else
        id = tonumber(npc)
    end

    if overrideName and overrideName ~= "" then
        return overrideName
    end

    if not id then
        return "Unknown NPC"
    end

    if SC._npcNameCache[id] then
        return SC._npcNameCache[id]
    end

    local name

    if C_CreatureInfo and C_CreatureInfo.GetCreatureInfo then
        local info = C_CreatureInfo.GetCreatureInfo(id)
        name = info and info.name
    end

    if not name then
        local tt = _G.HironCraftProfit_NPCTooltipScan
        if not tt then
            tt = CreateFrame("GameTooltip", "HironCraftProfit_NPCTooltipScan", UIParent, "GameTooltipTemplate")
            tt:SetOwner(UIParent, "ANCHOR_NONE")
        end

        tt:ClearLines()
        tt:SetHyperlink(("unit:Creature-0-0-0-0-%d-0000000000"):format(id))
        local text = _G.HironCraftProfit_NPCTooltipScanTextLeft1
        text = text and text:GetText()
        if text and text ~= "" then
            name = text
        end
    end

    if not name then
        name = "NPC #" .. id
    end

    SC._npcNameCache[id] = name
    return name
end

local function GetMapName(mapID)
    if not mapID then return "Unknown zone" end
    if SC._mapNameCache[mapID] then
        return SC._mapNameCache[mapID]
    end

    local info = C_Map.GetMapInfo(mapID)
    local name = info and info.name or ("Map #" .. mapID)
    SC._mapNameCache[mapID] = name
    return name
end

local function Chat(msg)
    if not msg or msg == "" then return end
    print("|cffb19cd9HironCraft:|r " .. tostring(msg))
end

local function AddBagID(list, seen, bagID)
    bagID = tonumber(bagID)
    if bagID == nil then return end
    if seen[bagID] then return end

    seen[bagID] = true
    list[#list + 1] = bagID
end

local function AddEnumBagID(list, seen, key)
    local bagID = Enum and Enum.BagIndex and Enum.BagIndex[key]
    if type(bagID) == "number" then
        AddBagID(list, seen, bagID)
    end
end

local function GetAllBags()
    local bags = {}
    local seen = {}

    AddBagID(bags, seen, BACKPACK_CONTAINER or 0)

    for bag = 1, (NUM_BAG_SLOTS or 4) do
        AddBagID(bags, seen, bag)
    end

    if type(REAGENTBAG_CONTAINER) == "number" then
        AddBagID(bags, seen, REAGENTBAG_CONTAINER)
    end

    AddEnumBagID(bags, seen, "ReagentBag")
    AddEnumBagID(bags, seen, "Reagentbag")

    AddBagID(bags, seen, 5)

    return bags
end

local function GetAllCraftingStorageBags()
    local bags = {}
    local seen = {}

    for _, bagID in ipairs(GetAllBags()) do
        AddBagID(bags, seen, bagID)
    end

    if type(BANK_CONTAINER) == "number" then
        AddBagID(bags, seen, BANK_CONTAINER)
    end

    AddEnumBagID(bags, seen, "Bank")

    if type(REAGENTBANK_CONTAINER) == "number" then
        AddBagID(bags, seen, REAGENTBANK_CONTAINER)
    end

    AddEnumBagID(bags, seen, "ReagentBank")
    AddEnumBagID(bags, seen, "Reagentbank")

    for i = 1, 7 do
        AddEnumBagID(bags, seen, "BankBag_" .. i)
    end

    for i = 1, 5 do
        AddEnumBagID(bags, seen, "AccountBankTab_" .. i)
        AddEnumBagID(bags, seen, "Accountbanktab_" .. i)
    end

    return bags
end

local function GetContainerSlotItemIDAndCount(bagID, slot)
    local itemID, count

    if C_Container and C_Container.GetContainerItemInfo then
        local okInfo, info = pcall(C_Container.GetContainerItemInfo, bagID, slot)

        if okInfo and type(info) == "table" then
            itemID = tonumber(info.itemID)
            count = tonumber(info.stackCount) or 1

            if not itemID and type(info.hyperlink) == "string" then
                itemID = tonumber(info.hyperlink:match("item:(%d+)"))
            end
        end
    end

    if not itemID and C_Container and C_Container.GetContainerItemID then
        local okItem, foundItemID = pcall(C_Container.GetContainerItemID, bagID, slot)
        if okItem then
            itemID = tonumber(foundItemID)
        end
    end

    if not itemID and C_Container and C_Container.GetContainerItemLink then
        local okLink, link = pcall(C_Container.GetContainerItemLink, bagID, slot)
        if okLink and type(link) == "string" then
            itemID = tonumber(link:match("item:(%d+)"))
        end
    end

    if itemID then
        return itemID, count or 1
    end

    return nil, 0
end

local function GetOutputItemIDFromRecipe(recipeID)
    if not recipeID
       or not C_TradeSkillUI
       or not C_TradeSkillUI.GetRecipeOutputItemData
    then
        return nil
    end

    local ok, outputInfo = pcall(C_TradeSkillUI.GetRecipeOutputItemData, recipeID)
    if not ok or type(outputInfo) ~= "table" then
        return nil
    end

    local itemID = tonumber(outputInfo.itemID)
    if itemID and itemID > 0 then
        return itemID
    end

    local link = outputInfo.hyperlink or outputInfo.itemLink or outputInfo.link
    if type(link) == "string" then
        return tonumber(link:match("item:(%d+)"))
    end

    return nil
end

function SC:GetTargetSkillLineID(target)
    if not target then
        return nil
    end

    return target.skillLineID
end

local function GetItemCountSafe(itemID, includeBank, includeReagentBank, includeAccountBank)
    itemID = tonumber(itemID)
    if not itemID then
        return 0
    end

    includeBank = includeBank and true or false
    includeReagentBank = includeReagentBank and true or false
    includeAccountBank = includeAccountBank and true or false

    if C_Item and C_Item.GetItemCount then
        local ok, count = pcall(
            C_Item.GetItemCount,
            itemID,
            includeBank,
            false,
            includeReagentBank,
            includeAccountBank
        )

        if ok and count ~= nil then
            return tonumber(count) or 0
        end
    end

    if GetItemCount then
        local ok, count = pcall(
            GetItemCount,
            itemID,
            includeBank,
            false,
            includeReagentBank
        )

        if ok and count ~= nil then
            return tonumber(count) or 0
        end
    end

    return 0
end

function SC:FindItemInBags(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return nil
    end

    if not C_Container or not C_Container.GetContainerNumSlots then
        return nil
    end

    for _, bag in ipairs(GetAllBags()) do
        local okSlots, slots = pcall(C_Container.GetContainerNumSlots, bag)
        slots = okSlots and tonumber(slots) or 0

        for slot = 1, slots do
            local foundItemID = GetContainerSlotItemIDAndCount(bag, slot)

            if foundItemID == itemID then
                return bag, slot
            end
        end
    end

    return nil
end

function SC:CountItemInBags(itemID)
    return GetItemCountSafe(itemID, false, false, false)
end

function SC:CountItemInCraftingStorage(itemID)
    return GetItemCountSafe(itemID, true, true, true)
end

function SC:GetGuideCraftableLureCount(target)
    local g = target and target.guide
    local craftFrom = g and g.craftFrom

    if not craftFrom then
        return nil
    end

    local minCrafts = nil
    local foundRequirement = false

    local function AddRequirement(entry)
        local itemID, need

        if type(entry) == "table" then
            itemID = tonumber(entry.id or entry.itemId or entry.itemID)
            need = tonumber(entry.count or entry.qty or entry.quantity or 1) or 1
        else
            itemID = tonumber(entry)
            need = 1
        end

        if not itemID or itemID <= 0 then
            return
        end

        if need <= 0 then
            need = 1
        end

        foundRequirement = true

        local have = self:CountItemInCraftingStorage(itemID)
        local can = math.floor(have / need)

        if minCrafts == nil or can < minCrafts then
            minCrafts = can
        end
    end

    if type(craftFrom) == "table" then
        if craftFrom.id or craftFrom.itemId or craftFrom.itemID then
            AddRequirement(craftFrom)
        else
            for _, entry in ipairs(craftFrom) do
                AddRequirement(entry)
            end
        end
    else
        AddRequirement(craftFrom)
    end

    if not foundRequirement then
        return nil
    end

    local outputCount = tonumber(g.craftOutputCount or g.outputCount or 1) or 1
    if outputCount < 1 then
        outputCount = 1
    end

    return (minCrafts or 0) * outputCount
end

function SC:GetActionableLureCount()
    if not self:IsAvailable() then return 0 end

    local count = 0
    for _, target in ipairs(self.TARGETS or {}) do
        if self:IsTargetAvailable(target)
           and self:IsTargetEnabled(target)
           and not self:IsTargetCompleted(target)
        then
            local lureItem = target.guide and target.guide.lureItem
            if lureItem then
                local canPlace = (self:CountItemInBags(lureItem) or 0) > 0
                local canCraft = (self:GetGuideCraftableLureCount(target) or 0) > 0
                if canPlace or canCraft then
                    count = count + 1
                end
            end
        end
    end

    return count
end

function SC:GetLureShoppingMaterials()
    if not self:IsAvailable() then return {} end

    local totalNeed = {}

    local function AddCraftFrom(craftFrom)
        if not craftFrom then return end
        local list = (craftFrom.id or craftFrom.itemId or craftFrom.itemID) and { craftFrom } or craftFrom
        for _, entry in ipairs(list) do
            local itemID, need
            if type(entry) == "table" then
                itemID = tonumber(entry.id or entry.itemId or entry.itemID)
                need = tonumber(entry.count or entry.qty or entry.quantity or 1) or 1
            else
                itemID = tonumber(entry)
                need = 1
            end
            if itemID and itemID > 0 then
                if need <= 0 then need = 1 end
                totalNeed[itemID] = (totalNeed[itemID] or 0) + need
            end
        end
    end

    for _, target in ipairs(self.TARGETS or {}) do
        if self:IsTargetAvailable(target)
           and self:IsTargetEnabled(target)
           and not self:IsTargetCompleted(target)
        then
            local g = target.guide
            local craftFrom = g and g.craftFrom
            if craftFrom and (self:GetGuideCraftableLureCount(target) or 0) <= 0 then
                AddCraftFrom(craftFrom)
            end
        end
    end

    local materials = {}
    for itemID, need in pairs(totalNeed) do
        local have = self:CountItemInCraftingStorage(itemID)
        local missing = need - have
        if missing > 0 then
            materials[#materials + 1] = {
                itemID = itemID,
                quantity = missing,
                label = C_Item.GetItemNameByID(itemID),
            }
        end
    end

    return materials
end

function SC:GetTargetByID(targetID)
    if not targetID then return nil end

    for _, target in ipairs(self.TARGETS or {}) do
        if target.id == targetID then
            return target
        end
    end

    return nil
end

function SC:HandleMenuLeftClick(targetID)
    local target = self:GetTargetByID(targetID)
    if not target then return end
    self:SetPendingWaypoint(target)
end

function SC:GetLureBagSlotString(target)
    local itemID = target and target.guide and target.guide.lureItem
    if not itemID then
        return nil
    end

    local bag, slot = self:FindItemInBags(itemID)
    if bag == nil or slot == nil then
        return nil
    end

    return string.format("%d %d", bag, slot)
end

function SC:NotifyLureMissingByID(targetID)
    local target = self:GetTargetByID(targetID)
    local itemID = target and target.guide and target.guide.lureItem
    if not itemID then
        return
    end

    local itemName = C_Item.GetItemNameByID(itemID)
        or (L["item not loaded"] or ("Item #" .. tostring(itemID)))

    Chat((L["SKINNING_LURE_NOT_FOUND"] or "Lure not found in bags: %s"):format(itemName))
end

function SC:FindRecipeForLure(itemID)
    if not itemID
       or not C_TradeSkillUI
       or not C_TradeSkillUI.GetAllRecipeIDs
       or not C_TradeSkillUI.GetRecipeInfo
    then
        return nil
    end

    local wantedName = C_Item.GetItemNameByID(itemID)
    local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs() or {}

    for _, recipeID in ipairs(recipeIDs) do
        local outputItemID = GetOutputItemIDFromRecipe(recipeID)
        if outputItemID and outputItemID == itemID then
            return recipeID
        end

        local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
        if info and wantedName and info.name == wantedName then
            return recipeID
        end
    end

    return nil
end

function SC:HandleMenuMiddleClick()
    local rootSkillLineID = self.ROOT_SKINNING_ID or 393
    if not rootSkillLineID then
        return
    end

    if ProfessionsFrame
       and ProfessionsFrame:IsShown()
       and lastOpenedSkillLine == rootSkillLineID
    then
        HideUIPanel(ProfessionsFrame)
        lastOpenedSkillLine = nil
        return
    end

    if ProfessionsFrame then
        ShowUIPanel(ProfessionsFrame)
    end

    if C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill then
        C_TradeSkillUI.OpenTradeSkill(rootSkillLineID)
        lastOpenedSkillLine = rootSkillLineID
    end
end

function SC:HandleMenuCraftClick(targetID)
    local target = self:GetTargetByID(targetID)
    if not target or not target.guide or not target.guide.lureItem then
        return
    end

    local rootSkillLineID = self.ROOT_SKINNING_ID or 393
    local targetSkillLineID = self:GetTargetSkillLineID(target)
    if not targetSkillLineID then
        return
    end

    if not ProfessionsFrame or not ProfessionsFrame:IsShown() then
        self:HandleMenuMiddleClick(targetID)
        return
    end

    local currentSkillLineID = nil
    if C_TradeSkillUI and C_TradeSkillUI.GetProfessionChildSkillLineID then
        currentSkillLineID = C_TradeSkillUI.GetProfessionChildSkillLineID()
    end

    if not currentSkillLineID then
        if C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill then
            C_TradeSkillUI.OpenTradeSkill(rootSkillLineID)
            lastOpenedSkillLine = rootSkillLineID
        end
        return
    end

    if currentSkillLineID ~= targetSkillLineID then
        if C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill then
            C_TradeSkillUI.OpenTradeSkill(targetSkillLineID)
            lastOpenedSkillLine = targetSkillLineID
        end
        return
    end

    if C_TradeSkillUI and C_TradeSkillUI.IsTradeSkillReady then
        local ok, ready = pcall(C_TradeSkillUI.IsTradeSkillReady)
        if ok and not ready then
            return
        end
    end

    local recipeID = self:FindRecipeForLure(target.guide.lureItem)
    if not recipeID then
        local itemName = C_Item.GetItemNameByID(target.guide.lureItem)
            or (L["item not loaded"] or ("Item #" .. tostring(target.guide.lureItem)))
        Chat((L["SKINNING_RECIPE_NOT_FOUND"] or "Recipe not found: %s"):format(itemName))
        return
    end

    if C_TradeSkillUI and C_TradeSkillUI.GetCraftableCount then
        local okCount, craftable = pcall(C_TradeSkillUI.GetCraftableCount, recipeID)
        if okCount and craftable ~= nil and craftable < 1 then
            local itemName = C_Item.GetItemNameByID(target.guide.lureItem)
                or (L["item not loaded"] or ("Item #" .. tostring(target.guide.lureItem)))
            Chat((L["SKINNING_CRAFT_NO_MATS"] or "Not enough materials to craft: %s"):format(itemName))
            return
        end
    end

    if C_TradeSkillUI and C_TradeSkillUI.OpenRecipe then
        pcall(C_TradeSkillUI.OpenRecipe, recipeID)
    end

    local crafted = false
    if C_TradeSkillUI and C_TradeSkillUI.CraftRecipe then
        crafted = pcall(C_TradeSkillUI.CraftRecipe, recipeID, 1)
    end

    if crafted then
        C_Timer.After(0.05, function()
            if C_TradeSkillUI and C_TradeSkillUI.CloseTradeSkill then
                pcall(C_TradeSkillUI.CloseTradeSkill)
            elseif ProfessionsFrame and ProfessionsFrame:IsShown() then
                HideUIPanel(ProfessionsFrame)
            end

            lastOpenedSkillLine = nil
        end)
    end
end

function SC:GetGuideTooltip(target)
    if not target or not target.guide then return nil end
    local g = target.guide
    local lines = {}

    table.insert(lines, L["SKINNING_HOW_TO_GET"] or "How to obtain:")

    if g.lureItem then
        local itemName = C_Item.GetItemNameByID(g.lureItem)
            or (L["item not loaded"] or "Item not loaded")
        table.insert(lines, ("– %s: %s"):format(
            L["SKINNING_LURE"] or "Lure",
            itemName
        ))
    end

    if g.craftFrom then
        local items = {}

        local function addItem(id, count)
            local name = C_Item.GetItemNameByID(id)
                or (L["item not loaded"] or ("Item #" .. id))

            if count and count > 1 then
                table.insert(items, string.format("%dx %s", count, name))
            else
                table.insert(items, name)
            end
        end

        if type(g.craftFrom) == "table" then
            for _, entry in ipairs(g.craftFrom) do
                if type(entry) == "table" then
                    addItem(entry.id, entry.count)
                else
                    addItem(entry, nil)
                end
            end
        else
            addItem(g.craftFrom, nil)
        end

        table.insert(lines, ("– %s: %s"):format(
            L["SKINNING_CRAFT_FROM"] or "Crafted from",
            table.concat(items, ", ")
        ))
    end

    if g.zone and g.zone.map then
        local zoneName = GetMapName(g.zone.map)
        if g.zone.x and g.zone.y then
            table.insert(lines, ("– %s: %s (%.1f, %.1f)"):format(
                L["SKINNING_LOCATION"] or "Location",
                zoneName,
                g.zone.x * 100,
                g.zone.y * 100
            ))
        else
            table.insert(lines, ("– %s: %s"):format(
                L["SKINNING_LOCATION"] or "Location",
                zoneName
            ))
        end
    end

    if g.npc and g.npc.id then
        local npcName = GetNPCName(g.npc)
        local npcLine = ("– %s: %s"):format(
            L["SKINNING_TARGET"] or "Target",
            npcName
        )

        if g.npc.minLevel then
            npcLine = npcLine .. (" (%d+ lvl need)"):format(g.npc.minLevel)
        end

        table.insert(lines, npcLine)
    end

    return table.concat(lines, "\n")
end

function SC:IsSkinningLearned()
    if not C_TradeSkillUI
       or not C_TradeSkillUI.GetProfessionInfoBySkillLineID
    then
        return false
    end

    for _, skillLineID in ipairs(self.SKINNING_SKILL_LINES) do
        local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID)
        if info and info.skillLevel and info.skillLevel > 0 then
            return true
        end
    end

    return false
end

function SC:HasSkinningProfession()
    if not GetProfessions or not GetProfessionInfo then
        return false
    end

    local prof1, prof2 = GetProfessions()
    if not prof1 and not prof2 then
        return false
    end

    for _, profIndex in ipairs({ prof1, prof2 }) do
        if profIndex then
            local _, _, _, _, _, _, skillLine = GetProfessionInfo(profIndex)
            if skillLine == self.ROOT_SKINNING_ID then
                return true
            end
        end
    end

    return false
end

function SC:IsAvailable()
    return self:HasSkinningProfession() or self:IsSkinningLearned()
end

function SC:IsTargetEnabled(target)
    local db = GetSkinningDisabledDB()
    return not db[target.id]
end

function SC:IsTargetCompleted(target)
    if not target or not target.questId then return false end
    return C_QuestLog.IsQuestFlaggedCompleted(target.questId)
end

function SC:HasMissingItems()
    if not self:IsAvailable() then return false end

    for _, target in ipairs(self.TARGETS) do
        if self:IsTargetAvailable(target)
           and self:IsTargetEnabled(target)
           and not self:IsTargetCompleted(target)
        then
            return true
        end
    end

    return false
end

function SC:GetMissingItems()
    local result = {}

    if not self:IsAvailable() then
        return result
    end

    for _, target in ipairs(self.TARGETS) do
        if self:IsTargetAvailable(target)
           and self:IsTargetEnabled(target)
           and not self:IsTargetCompleted(target)
        then
            table.insert(result, target)
        end
    end

    return result
end

function SC:GetIconTooltip()
    if not self:IsAvailable() then
        return L["SKINNING_NOT_LEARNED"]
    end

    local missing = self:GetMissingItems()
    if #missing == 0 then
        return L["SKINNING_ALL_DONE"]
    end

    local lines = { L["SKINNING_AVAILABLE"] }
    for _, t in ipairs(missing) do
        table.insert(lines, "• " .. self:GetTargetName(t))
    end

    return table.concat(lines, "\n")
end

function SC:GetProgress()
    if not self:IsAvailable() then
        return nil
    end

    local total, done = 0, 0

    for _, target in ipairs(self.TARGETS) do
        if self:IsTargetAvailable(target)
           and self:IsTargetEnabled(target)
        then
            total = total + 1
            if self:IsTargetCompleted(target) then
                done = done + 1
            end
        end
    end

    if total == 0 then
        return nil
    end

    return done, total
end