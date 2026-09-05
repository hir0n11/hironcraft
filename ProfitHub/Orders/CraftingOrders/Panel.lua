local E = _G.HironCraftProfitCraftingOrdersEnv
if not E then
    E = {}
    _G.HironCraftProfitCraftingOrdersEnv = E
    setmetatable(E, { __index = _G })
end
setfenv(1, E)
if not PT or not CO then return end

local PROFESSION_TOOL_SLOT_SIZE = 34

local PROFESSION_SKILL_TO_ENUM = {
    [164] = 1,  -- Blacksmithing
    [165] = 2,  -- Leatherworking
    [171] = 3,  -- Alchemy
    [182] = 4,  -- Herbalism
    [186] = 6,  -- Mining
    [197] = 7,  -- Tailoring
    [202] = 8,  -- Engineering
    [333] = 9,  -- Enchanting
    [393] = 11, -- Skinning
    [755] = 12, -- Jewelcrafting
    [773] = 13, -- Inscription
}

local function SetProfessionSkillEnum(skillLine, enumKey)
    if Enum and Enum.Profession and Enum.Profession[enumKey] ~= nil then
        PROFESSION_SKILL_TO_ENUM[skillLine] = tonumber(Enum.Profession[enumKey]) or PROFESSION_SKILL_TO_ENUM[skillLine]
    end
end

SetProfessionSkillEnum(164, "Blacksmithing")
SetProfessionSkillEnum(165, "Leatherworking")
SetProfessionSkillEnum(171, "Alchemy")
SetProfessionSkillEnum(182, "Herbalism")
SetProfessionSkillEnum(186, "Mining")
SetProfessionSkillEnum(197, "Tailoring")
SetProfessionSkillEnum(202, "Engineering")
SetProfessionSkillEnum(333, "Enchanting")
SetProfessionSkillEnum(393, "Skinning")
SetProfessionSkillEnum(755, "Jewelcrafting")
SetProfessionSkillEnum(773, "Inscription")

local PROFESSION_TOOL_STAT_DEFS = {
    {
        keys = { "ITEM_MOD_INGENUITY_SHORT", "ITEM_MOD_INGENUITY", "ITEM_MOD_INGENUITY_RATING_SHORT", "ITEM_MOD_INGENUITY_RATING" },
        labelKey = "COA_PROF_TOOL_STAT_INGENUITY",
        fallback = "Ingenuity",
    },
    {
        keys = { "ITEM_MOD_INSPIRATION_SHORT", "ITEM_MOD_INSPIRATION", "ITEM_MOD_INSPIRATION_RATING_SHORT", "ITEM_MOD_INSPIRATION_RATING" },
        labelKey = "COA_PROF_TOOL_STAT_INSPIRATION",
        fallback = "Inspiration",
    },
    {
        keys = { "ITEM_MOD_RESOURCEFULNESS_SHORT", "ITEM_MOD_RESOURCEFULNESS", "ITEM_MOD_RESOURCEFULNESS_RATING_SHORT", "ITEM_MOD_RESOURCEFULNESS_RATING" },
        labelKey = "COA_PROF_TOOL_STAT_RESOURCEFULNESS",
        fallback = "Resourcefulness",
    },
    {
        keys = { "ITEM_MOD_MULTICRAFT_SHORT", "ITEM_MOD_MULTICRAFT", "ITEM_MOD_MULTICRAFT_RATING_SHORT", "ITEM_MOD_MULTICRAFT_RATING" },
        labelKey = "COA_PROF_TOOL_STAT_MULTICRAFT",
        fallback = "Multicraft",
    },
    {
        keys = { "ITEM_MOD_CRAFTING_SPEED_SHORT", "ITEM_MOD_CRAFTING_SPEED", "ITEM_MOD_CRAFTING_SPEED_RATING_SHORT", "ITEM_MOD_CRAFTING_SPEED_RATING" },
        labelKey = "COA_PROF_TOOL_STAT_CRAFTING_SPEED",
        fallback = "Crafting Speed",
    },
    {
        keys = { "ITEM_MOD_FINESSE_SHORT", "ITEM_MOD_FINESSE", "ITEM_MOD_FINESSE_RATING_SHORT", "ITEM_MOD_FINESSE_RATING" },
        labelKey = "COA_PROF_TOOL_STAT_FINESSE",
        fallback = "Finesse",
    },
    {
        keys = { "ITEM_MOD_DEFTNESS_SHORT", "ITEM_MOD_DEFTNESS", "ITEM_MOD_DEFTNESS_RATING_SHORT", "ITEM_MOD_DEFTNESS_RATING" },
        labelKey = "COA_PROF_TOOL_STAT_DEFTNESS",
        fallback = "Deftness",
    },
    {
        keys = { "ITEM_MOD_PERCEPTION_SHORT", "ITEM_MOD_PERCEPTION", "ITEM_MOD_PERCEPTION_RATING_SHORT", "ITEM_MOD_PERCEPTION_RATING" },
        labelKey = "COA_PROF_TOOL_STAT_PERCEPTION",
        fallback = "Perception",
    },
}

local function FirstUtf8Character(text)
    text = tostring(text or "")
    local firstByte = text:byte(1)
    if not firstByte then return "" end

    local length = 1
    if firstByte >= 240 then
        length = 4
    elseif firstByte >= 224 then
        length = 3
    elseif firstByte >= 192 then
        length = 2
    end

    return text:sub(1, length)
end

local function ExtractProfessionSlotNumber(value)
    if type(value) == "number" then return value end
    if type(value) == "table" then
        return value.slot
            or value.slotID
            or value.slotId
            or value.inventorySlot
            or value.inventorySlotID
            or value.inventorySlotId
            or value.inventorySlotIndex
            or value.invSlot
    end
    return nil
end

local function GetItemInstantInfoSafe(item)
    if C_Item and C_Item.GetItemInfoInstant then
        local ok, itemID, itemType, itemSubType, equipLoc, icon, classID, subClassID =
            pcall(C_Item.GetItemInfoInstant, item)
        if ok then
            return itemID, itemType, itemSubType, equipLoc, icon, classID, subClassID
        end
    end

    if GetItemInfoInstant then
        local ok, itemID, itemType, itemSubType, equipLoc, icon, classID, subClassID =
            pcall(GetItemInfoInstant, item)
        if ok then
            return itemID, itemType, itemSubType, equipLoc, icon, classID, subClassID
        end
    end

    return nil
end

local function GetItemStatsSafe(item)
    if not item then return nil end

    if C_Item and C_Item.GetItemStats then
        local ok, stats = pcall(C_Item.GetItemStats, item)
        if ok and type(stats) == "table" then return stats end
    end

    if GetItemStats then
        local ok, stats = pcall(GetItemStats, item)
        if ok and type(stats) == "table" then return stats end
    end

    return nil
end

local function GetItemNameSafe(item)
    if not item then return nil end

    if C_Item and C_Item.GetItemInfo then
        local ok, name = pcall(C_Item.GetItemInfo, item)
        if ok and name then return name end
    end

    if GetItemInfo then
        local ok, name = pcall(GetItemInfo, item)
        if ok and name then return name end
    end

    return nil
end

local function GetProfessionEnumBySkillLine(skillLine)
    skillLine = tonumber(skillLine)
    if not skillLine then return nil end

    if C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID then
        local ok, info = pcall(C_TradeSkillUI.GetProfessionInfoBySkillLineID, skillLine)
        if ok and type(info) == "table" then
            return tonumber(info.profession)
                or tonumber(info.parentProfessionID)
                or PROFESSION_SKILL_TO_ENUM[skillLine]
        end
    end

    return PROFESSION_SKILL_TO_ENUM[skillLine]
end

local function GetSkillLineForProfessionGear(itemInfo, bag, slot)
    if not itemInfo or not C_TradeSkillUI or not C_TradeSkillUI.GetSkillLineForGear then
        return nil
    end

    local ok, skillLine = pcall(C_TradeSkillUI.GetSkillLineForGear, itemInfo)
    skillLine = ok and tonumber(skillLine) or nil
    if skillLine then
        return skillLine
    end

    if ItemLocation and bag and slot then
        local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
        if location then
            ok, skillLine = pcall(C_TradeSkillUI.GetSkillLineForGear, location)
            skillLine = ok and tonumber(skillLine) or nil
            if skillLine then
                return skillLine
            end
        end
    end

    return nil
end

local function GetProfessionNameBySkillLine(skillLine)
    skillLine = tonumber(skillLine)
    if skillLine and C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID then
        local ok, info = pcall(C_TradeSkillUI.GetProfessionInfoBySkillLineID, skillLine)
        if ok and type(info) == "table" then
            return info.parentProfessionName
                or info.parentSkillLineName
                or info.professionName
                or info.skillLineName
                or info.name
        end
    end

    return nil
end

local function GetProfessionToolStatLabel(def)
    for _, key in ipairs(def.keys or {}) do
        local value = _G[key]
        if type(value) == "string" and value ~= "" then
            return value
        end
    end

    return T(def.labelKey, def.fallback)
end

local function GetProfessionToolStatValue(stats, def)
    if type(stats) ~= "table" or type(def) ~= "table" then return nil end

    for _, key in ipairs(def.keys or {}) do
        local value = tonumber(stats[key])
        if value and value ~= 0 then
            return value
        end

        local label = _G[key]
        if type(label) == "string" and label ~= "" then
            value = tonumber(stats[label])
            if value and value ~= 0 then
                return value
            end
        end
    end

    return nil
end

function CO:GetProfessionToolStatFromTooltip(slot)
    slot = tonumber(slot)
    if not slot or not GameTooltip then return nil end

    if not self.professionToolScanTooltip then
        self.professionToolScanTooltip = CreateFrame("GameTooltip", "HironCraftProfitCraftingOrdersToolScanTooltip", UIParent, "GameTooltipTemplate")
    end

    local tooltip = self.professionToolScanTooltip
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:ClearLines()
    tooltip:SetInventoryItem("player", slot)

    local name = tooltip:GetName()
    for lineIndex = 2, tooltip:NumLines() do
        local line = _G[name .. "TextLeft" .. lineIndex]
        local text = line and line:GetText()
        if type(text) == "string" and text ~= "" then
            for _, def in ipairs(PROFESSION_TOOL_STAT_DEFS) do
                local label = GetProfessionToolStatLabel(def)
                if label and label ~= "" and text:find(label, 1, true) then
                    tooltip:Hide()
                    return label, nil
                end
            end
        end
    end

    tooltip:Hide()
    return nil
end

function CO:BagItemTooltipContainsText(bag, slot, needle)
    if not bag or not slot or type(needle) ~= "string" or needle == "" then return false end
    if not GameTooltip then return false end

    if not self.professionToolScanTooltip then
        self.professionToolScanTooltip = CreateFrame("GameTooltip", "HironCraftProfitCraftingOrdersToolScanTooltip", UIParent, "GameTooltipTemplate")
    end

    local tooltip = self.professionToolScanTooltip
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:ClearLines()
    tooltip:SetBagItem(bag, slot)

    local name = tooltip:GetName()
    for lineIndex = 2, tooltip:NumLines() do
        local line = _G[name .. "TextLeft" .. lineIndex]
        local text = line and line:GetText()
        if type(text) == "string" and text:find(needle, 1, true) then
            tooltip:Hide()
            return true
        end
    end

    tooltip:Hide()
    return false
end

function CO:GetProfessionToolStatInfo(itemInfo, slot)
    local stats = GetItemStatsSafe(itemInfo)
    if stats then
        for _, def in ipairs(PROFESSION_TOOL_STAT_DEFS) do
            local value = GetProfessionToolStatValue(stats, def)
            if value then
                local label = GetProfessionToolStatLabel(def)
                return label, FirstUtf8Character(label), value
            end
        end
    end

    local label, value = self:GetProfessionToolStatFromTooltip(slot)
    if label then
        return label, FirstUtf8Character(label), value
    end

    return nil, nil, nil
end

function CO:GetCurrentProfessionToolInfo(pageFrame)
    if InCombatLockdown and InCombatLockdown() then return nil end
    if not C_TradeSkillUI or not C_TradeSkillUI.GetProfessionSlots then return nil end

    local profession = GetProfessionFromPage(pageFrame or self.activePageFrame)
    if not profession then return nil end

    local ok, professionSlots = pcall(C_TradeSkillUI.GetProfessionSlots, profession)
    if not ok or not professionSlots then return nil end

    local slots = type(professionSlots) == "table" and professionSlots or { professionSlots }
    for _, slotValue in ipairs(slots) do
        local slot = ExtractProfessionSlotNumber(slotValue)
        local itemID = slot and GetInventoryItemID("player", slot)
        local link = slot and GetInventoryItemLink("player", slot)

        if slot and (itemID or link) then
            local itemInfo = link or itemID
            local _, _, _, equipLoc, instantIcon = GetItemInstantInfoSafe(itemInfo)
            if equipLoc == "INVTYPE_PROFESSION_TOOL" then
                local statName, statLetter, statValue = self:GetProfessionToolStatInfo(itemInfo, slot)
                return {
                    slot = slot,
                    itemID = tonumber(itemID),
                    link = link,
                    icon = GetInventoryItemTexture("player", slot) or instantIcon,
                    statName = statName,
                    statLetter = statLetter,
                    statValue = statValue,
                }
            end
        end
    end

    return nil
end

function CO:GetCurrentProfessionToolSlot(pageFrame)
    local info = self:GetCurrentProfessionToolInfo(pageFrame)
    if info and info.slot then return info.slot end

    if not C_TradeSkillUI or not C_TradeSkillUI.GetProfessionSlots then
        return _G.INVSLOT_PROFESSION_TOOL
    end

    local profession = GetProfessionFromPage(pageFrame or self.activePageFrame)
    if not profession then return _G.INVSLOT_PROFESSION_TOOL end

    local ok, professionSlots = pcall(C_TradeSkillUI.GetProfessionSlots, profession)
    if not ok or not professionSlots then return _G.INVSLOT_PROFESSION_TOOL end

    local slots = type(professionSlots) == "table" and professionSlots or { professionSlots }
    for _, slotValue in ipairs(slots) do
        local slot = ExtractProfessionSlotNumber(slotValue)
        if slot then
            local itemID = GetInventoryItemID("player", slot)
            local link = GetInventoryItemLink("player", slot)
            if itemID or link then
                local _, _, _, equipLoc = GetItemInstantInfoSafe(link or itemID)
                if equipLoc == "INVTYPE_PROFESSION_TOOL" then
                    return slot
                end
            end
        end
    end

    return ExtractProfessionSlotNumber(slots[1]) or _G.INVSLOT_PROFESSION_TOOL
end

function CO:GetCurrentProfessionSkillLineForTool(pageFrame)
    local profession = GetProfessionFromPage(pageFrame or self.activePageFrame)
    profession = tonumber(profession)
    if not profession then return nil, nil end

    if C_TradeSkillUI and C_TradeSkillUI.GetProfessionSkillLineID then
        local ok, skillLine = pcall(C_TradeSkillUI.GetProfessionSkillLineID, profession)
        skillLine = tonumber(skillLine)
        if ok and skillLine then
            return skillLine, profession
        end
    end

    return nil, profession
end

function CO:DoesProfessionToolMatchCurrentProfession(itemInfo, pageFrame, bag, slot)
    local _, _, _, equipLoc = GetItemInstantInfoSafe(itemInfo)
    if equipLoc ~= "INVTYPE_PROFESSION_TOOL" then return false end

    local currentSkillLine, currentProfession = self:GetCurrentProfessionSkillLineForTool(pageFrame)
    if not currentProfession then return false end

    local itemSkillLine = GetSkillLineForProfessionGear(itemInfo, bag, slot)
    if itemSkillLine and currentSkillLine and itemSkillLine == currentSkillLine then
        return true
    end

    if itemSkillLine then
        local itemProfession = GetProfessionEnumBySkillLine(itemSkillLine)
        return itemProfession ~= nil and tonumber(itemProfession) == tonumber(currentProfession)
    end

    local professionName = GetProfessionNameBySkillLine(currentSkillLine)
    if professionName and self:BagItemTooltipContainsText(bag, slot, professionName) then
        return true
    end

    return false
end

function CO:GetAvailableProfessionTools(pageFrame)
    if not C_Container or not C_Container.GetContainerNumSlots then return {} end

    local tools = {}
    local lastBag = tonumber(_G.NUM_TOTAL_EQUIPPED_BAG_SLOTS) or tonumber(_G.NUM_BAG_SLOTS) or 4

    for bag = 0, lastBag do
        local okSlots, slotCount = pcall(C_Container.GetContainerNumSlots, bag)
        slotCount = okSlots and tonumber(slotCount) or 0

        for slot = 1, slotCount do
            local itemID = C_Container.GetContainerItemID and C_Container.GetContainerItemID(bag, slot)
            local link = C_Container.GetContainerItemLink and C_Container.GetContainerItemLink(bag, slot)
            local itemInfo = link or itemID

            if itemInfo and self:DoesProfessionToolMatchCurrentProfession(itemInfo, pageFrame, bag, slot) then
                local containerInfo = C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
                local _, _, _, _, instantIcon = GetItemInstantInfoSafe(itemInfo)
                local statName, statLetter, statValue = self:GetProfessionToolStatInfo(itemInfo)
                local itemName = GetItemNameSafe(itemInfo) or ("Item " .. tostring(itemID or "?"))

                tools[#tools + 1] = {
                    bag = bag,
                    slot = slot,
                    itemID = tonumber(itemID),
                    link = link,
                    name = itemName,
                    icon = (type(containerInfo) == "table" and containerInfo.iconFileID) or instantIcon,
                    statName = statName,
                    statLetter = statLetter,
                    statValue = statValue,
                }
            end
        end
    end

    table.sort(tools, function(a, b)
        local aStat = a.statName or ""
        local bStat = b.statName or ""
        if aStat ~= bStat then return aStat < bStat end

        local aName = a.name or ""
        local bName = b.name or ""
        if aName ~= bName then return aName < bName end

        if (a.bag or 0) ~= (b.bag or 0) then return (a.bag or 0) < (b.bag or 0) end
        return (a.slot or 0) < (b.slot or 0)
    end)

    return tools
end

local function LowerFirstUtf8(s)
    if type(s) ~= "string" or s == "" then return s end
    local b1 = string.byte(s, 1)
    if b1 < 0x80 then
        return s:sub(1, 1):lower() .. s:sub(2)
    end
    if b1 == 0xD0 then
        local b2 = string.byte(s, 2)
        if b2 and b2 >= 0x90 and b2 <= 0x9F then
            return string.char(0xD0, b2 + 0x20) .. s:sub(3)
        elseif b2 and b2 >= 0xA0 and b2 <= 0xAF then
            return string.char(0xD1, b2 - 0x20) .. s:sub(3)
        elseif b2 == 0x81 then
            return string.char(0xD1, 0x91) .. s:sub(3)
        end
    end
    return s
end

function CO:EquipProfessionTool(tool, pageFrame)
    if not tool or not tool.bag or not tool.slot then return end

    if InCombatLockdown and InCombatLockdown() then
        self:SetStatus(T("COA_STATUS_PROF_TOOL_COMBAT", "Cannot change profession tool in combat."))
        return
    end

    local currentTool = self:GetCurrentProfessionToolInfo(pageFrame)
    local targetSlot = currentTool and currentTool.slot
    local ok

    if targetSlot and C_Container and C_Container.PickupContainerItem and PickupInventoryItem then
        ok = SafeCall("Equip profession tool", function()
            ClearCursor()
            C_Container.PickupContainerItem(tool.bag, tool.slot)
            PickupInventoryItem(targetSlot)
            if CursorHasItem and CursorHasItem() then
                C_Container.PickupContainerItem(tool.bag, tool.slot)
            end
            if ClearCursor and CursorHasItem and CursorHasItem() then
                ClearCursor()
            end
        end)
    elseif EquipItemByName then
        ok = SafeCall("Equip profession tool", function()
            EquipItemByName(tool.link or tool.itemID)
        end)
    end

    if ok then
        local statLabel = (tool.statName and LowerFirstUtf8(tool.statName)) or tool.name or tostring(tool.itemID or "")
        self:SetStatus(string.format(T("COA_STATUS_PROF_TOOL_EQUIP", "tool > %s"), statLabel))
        if C_Timer then
            C_Timer.After(0.15, function() CO:UpdateControlPanel() end)
            C_Timer.After(0.70, function() CO:UpdateControlPanel() end)
        else
            self:UpdateControlPanel()
        end
    else
        self:SetStatus(T("COA_STATUS_PROF_TOOL_EQUIP_FAILED", "Could not equip the profession tool."))
    end
end

local RESOURCEFULNESS_DEF
for _, def in ipairs(PROFESSION_TOOL_STAT_DEFS) do
    if def.labelKey == "COA_PROF_TOOL_STAT_RESOURCEFULNESS" then RESOURCEFULNESS_DEF = def end
end

local function ResourcefulnessLabel()
    return RESOURCEFULNESS_DEF and GetProfessionToolStatLabel(RESOURCEFULNESS_DEF) or nil
end

function CO:AutoEquipResourcefulnessTool(pageFrame, attempt)
    if not self:IsEnabled() then return end
    if not self.IsAutoToolOn or not self:IsAutoToolOn() then return end
    if InCombatLockdown and InCombatLockdown() then return end

    local wantLabel = ResourcefulnessLabel()
    if not wantLabel then return end

    local current = self:GetCurrentProfessionToolInfo(pageFrame)
    if current and current.statName == wantLabel then return end

    local tools = self:GetAvailableProfessionTools(pageFrame)
    if (not tools or #tools == 0) and (attempt or 0) < 8 and C_Timer then
        C_Timer.After(0.4, function() CO:AutoEquipResourcefulnessTool(pageFrame, (attempt or 0) + 1) end)
        return
    end

    for _, tool in ipairs(tools or {}) do
        if tool.statName == wantLabel then
            self:EquipProfessionTool(tool, pageFrame)
            return
        end
    end

    self:SetStatus(string.format(T("COA_STATUS_AUTOTOOL_MISSING", "no %s tool in bags"), LowerFirstUtf8(wantLabel)))
end

function CO:OpenProfessionToolMenu(owner)
    if not owner then return end

    local pageFrame = (self.controlPanel and self.controlPanel.pageFrame) or self.activePageFrame
    local tools = self:GetAvailableProfessionTools(pageFrame)
    local current = owner.professionToolInfo or self:GetCurrentProfessionToolInfo(pageFrame)
    local currentLink = current and current.link
    local currentItemID = current and current.itemID

    local items = {
        {
            text = T("COA_PROF_TOOL_MENU_TITLE", "Profession tools"),
            header = true,
        },
    }

    if #tools == 0 then
        items[#items + 1] = {
            text = T("COA_PROF_TOOL_MENU_EMPTY", "No matching tools found in bags."),
            header = true,
        }
    else
        for _, tool in ipairs(tools) do
            local toolCopy = tool
            local checked = (currentLink and toolCopy.link and toolCopy.link == currentLink)
                or (not currentLink and currentItemID and toolCopy.itemID == currentItemID)
            local statText = toolCopy.statLetter
            if toolCopy.statValue then
                statText = (statText or "?") .. " +" .. tostring(toolCopy.statValue)
            end

            items[#items + 1] = {
                text = toolCopy.name,
                icon = toolCopy.icon,
                amount = statText,
                checked = checked,
                onClick = function()
                    CO:EquipProfessionTool(toolCopy, pageFrame)
                end,
            }
        end
    end

    if PT.Dropdown and PT.Dropdown.Show then
        PT.Dropdown:Show({ owner = owner, items = items })
    end
end

function CO:ShowProfessionToolSlotTooltip(owner)
    if not owner then return end

    local info = owner.professionToolInfo
    if info and info.slot and GameTooltip then
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:SetInventoryItem("player", info.slot)
        if info.statName then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(string.format(T("COA_PROF_TOOL_STAT_FMT", "Tool stat: %s"), info.statName), 0.70, 0.90, 1)
        end
        GameTooltip:AddLine(T("COA_PROF_TOOL_CLICK_HINT", "Click to choose another tool from bags."), 0.70, 0.90, 1)
        GameTooltip:Show()
        return
    end

    if Tooltip then
        Tooltip:Clear()
        Tooltip:AddLine(T("COA_PROF_TOOL_SLOT_TITLE", "Profession tool"), 13, 1, 0.82, 0.35)
        Tooltip:AddLine(T("COA_PROF_TOOL_EMPTY", "No profession tool is equipped for the current profession."), 11, 0.85, 0.85, 0.85)
        Tooltip:AddLine(T("COA_PROF_TOOL_CLICK_HINT", "Click to choose another tool from bags."), 11, 0.70, 0.90, 1)
        ShowStyledTooltip(owner)
    end
end

local function FindBestQualityCheckbox()
    local PF = _G.ProfessionsFrame
    if not PF then return nil end

    local candidates = {}
    local cp = PF.CraftingPage
    if cp and cp.SchematicForm then
        candidates[#candidates + 1] = cp.SchematicForm.AllocateBestQualityCheckbox
    end
    local ov = PF.OrdersPage and PF.OrdersPage.OrderView
    local od = ov and ov.OrderDetails
    if od and od.SchematicForm then
        candidates[#candidates + 1] = od.SchematicForm.AllocateBestQualityCheckbox
    end

    for _, cb in ipairs(candidates) do
        if cb and cb.IsVisible and cb:IsVisible() then
            return cb
        end
    end
    return candidates[1]
end

function CO:GetBestQualityState()
    if Professions and Professions.ShouldAllocateBestQualityReagents then
        local ok, value = pcall(Professions.ShouldAllocateBestQualityReagents)
        if ok then
            return value and true or false
        end
    end

    local cb = FindBestQualityCheckbox()
    if cb and cb.GetChecked then
        return cb:GetChecked() and true or false
    end
    return false
end

function CO:SetBestQualityState(value)
    value = value and true or false

    local cb = FindBestQualityCheckbox()
    local current
    if cb and cb.GetChecked then
        current = cb:GetChecked() and true or false
    end

    if cb and cb.Click and current ~= nil and current ~= value then
        pcall(cb.Click, cb)
    elseif Professions and Professions.SetShouldAllocateBestQualityReagents then
        pcall(Professions.SetShouldAllocateBestQualityReagents, value)
    end

    self:UpdateBestQualityToggle(value)
end

function CO:ToggleBestQuality()
    self:SetBestQualityState(not self:GetBestQualityState())
end

function CO:CreateBestQualityToggle(parent)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(PROFESSION_TOOL_SLOT_SIZE, PROFESSION_TOOL_SLOT_SIZE)
    CreateBackdrop(button, 0.90)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 4, -4)
    button.icon:SetPoint("BOTTOMRIGHT", -4, 4)
    if button.icon.SetAtlas then
        button.icon:SetAtlas("Professions-ChatIcon-Quality-Tier5-Cap")
    end

    button:SetScript("OnEnter", function(self)
        if Tooltip then
            Tooltip:Clear()
            Tooltip:AddLine(T("COA_BEST_QUALITY_TITLE", "Use best quality reagents"), 13, 1, 0.82, 0.35)
            Tooltip:AddLine(T("COA_BEST_QUALITY_DESC", "Always allocate the highest quality reagents for every recipe."), 11, 0.85, 0.85, 0.85)
            ShowStyledTooltip(self)
        end
    end)
    button:SetScript("OnLeave", function()
        HideStyledTooltip()
    end)
    button:SetScript("OnClick", function()
        CO:ToggleBestQuality()
    end)

    return button
end

function CO:UpdateBestQualityToggle(stateOverride)
    local panel = self.controlPanel
    local button = panel and panel.bestQualityToggle
    if not button then return end

    local on = stateOverride
    if on == nil then
        on = self:GetBestQualityState()
    end
    if button.icon then
        button.icon:SetDesaturated(not on)
        button.icon:SetAlpha(on and 1 or 0.45)
    end
    if button.SetBackdropBorderColor then
        if on then
            button:SetBackdropBorderColor(1, 0.82, 0.2, 1)
        else
            button:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
        end
    end
end

function CO:CreateAutoToolToggle(parent)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(PROFESSION_TOOL_SLOT_SIZE, PROFESSION_TOOL_SLOT_SIZE)
    CreateBackdrop(button, 0.90)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 5, -5)
    button.icon:SetPoint("BOTTOMRIGHT", -5, 5)
    if button.icon.SetAtlas then
        button.icon:SetAtlas("uitools-icon-refresh")
    end

    button:SetScript("OnEnter", function(self)
        if Tooltip then
            Tooltip:Clear()
            Tooltip:AddLine(T("COA_AUTOTOOL_TITLE", "Auto resourcefulness tool"), 13, 1, 0.82, 0.35)
            Tooltip:AddLine(T("COA_AUTOTOOL_DESC", "When orders open, equips a resourcefulness tool — multicraft yield goes to the customer, so only resourcefulness helps you."), 11, 0.85, 0.85, 0.85)
            ShowStyledTooltip(self)
        end
    end)
    button:SetScript("OnLeave", function()
        HideStyledTooltip()
    end)
    button:SetScript("OnClick", function()
        CO:ToggleAutoTool()
    end)

    return button
end

function CO:UpdateAutoToolToggle()
    local panel = self.controlPanel
    local button = panel and panel.autoToolToggle
    if not button then return end

    local on = self.IsAutoToolOn and self:IsAutoToolOn()
    if button.icon then
        button.icon:SetDesaturated(not on)
        if on then
            button.icon:SetVertexColor(0.3, 1, 0.3, 1)
        else
            button.icon:SetVertexColor(0.6, 0.6, 0.65, 1)
        end
    end
    if button.SetBackdropBorderColor then
        if on then
            button:SetBackdropBorderColor(0.3, 1, 0.3, 1)
        else
            button:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
        end
    end
end

function CO:ToggleAutoTool()
    self:SetAutoToolOn(not self:IsAutoToolOn())
    self:UpdateAutoToolToggle()
    if self:IsAutoToolOn() then
        local pageFrame = (self.controlPanel and self.controlPanel.pageFrame) or self.activePageFrame
        self:AutoEquipResourcefulnessTool(pageFrame)
    end
end

function CO:CreateProfessionToolSlot(parent)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(PROFESSION_TOOL_SLOT_SIZE, PROFESSION_TOOL_SLOT_SIZE)
    CreateBackdrop(button, 0.90)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 3, -3)
    button.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.letterBg = button:CreateTexture(nil, "OVERLAY")
    button.letterBg:SetPoint("BOTTOMRIGHT", -1, 1)
    button.letterBg:SetSize(14, 14)
    button.letterBg:SetColorTexture(0, 0, 0, 0.78)

    button.statText = button:CreateFontString(nil, "OVERLAY")
    ApplyFont(button.statText, 10, "OUTLINE")
    button.statText:SetPoint("CENTER", button.letterBg, "CENTER", 0, 0)
    button.statText:SetTextColor(1, 0.82, 0.18, 1)

    button:SetScript("OnEnter", function(self)
        CO:ShowProfessionToolSlotTooltip(self)
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
        HideStyledTooltip()
    end)
    button:SetScript("OnClick", function(self)
        if GameTooltip then GameTooltip:Hide() end
        HideStyledTooltip()
        CO:OpenProfessionToolMenu(self)
    end)

    return button
end

function CO:UpdateProfessionToolSlot()
    local panel = self.controlPanel
    local slot = panel and panel.professionToolSlot
    if not slot then return end

    local info = self:GetCurrentProfessionToolInfo(panel.pageFrame or self.activePageFrame)
    slot.professionToolInfo = info

    if info and info.icon then
        slot.icon:SetTexture(info.icon)
        slot.icon:SetDesaturated(false)
        slot.statText:SetText(info.statLetter or "?")
        slot.statText:SetTextColor(1, 0.82, 0.18, 1)
    else
        slot.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        slot.icon:SetDesaturated(true)
        slot.statText:SetText("-")
        slot.statText:SetTextColor(0.55, 0.55, 0.58, 1)
    end
end

function CO:CreateSegmentedControl(parent, segments, totalWidth, getValue, setValue, opts)
    opts = opts or {}
    local n = #segments
    local gap = 2
    local rowH = opts.rowH or 22

    -- Per-row button counts: explicit opts.rows = {3, 2}, or uniform opts.columns.
    local rowCounts = opts.rows
    if not rowCounts then
        local columns = opts.columns or n
        rowCounts = {}
        local remaining = n
        while remaining > 0 do
            local c = math.min(columns, remaining)
            rowCounts[#rowCounts + 1] = c
            remaining = remaining - c
        end
    end

    local holder = CreateFrame("Frame", nil, parent)
    holder.buttons = {}
    holder.getValue = getValue
    holder.setValue = setValue
    holder:SetSize(totalWidth, #rowCounts * rowH + (#rowCounts - 1) * gap)

    local function AttachTip(b)
        if not opts.tipTitle then return end
        b:SetScript("OnEnter", function(self2)
            if not Tooltip then return end
            Tooltip:Clear()
            Tooltip:AddLine(opts.tipTitle, 13, 1, 0.82, 0.35)
            if opts.tipDesc then Tooltip:AddLine(opts.tipDesc, 11, 0.85, 0.85, 0.85) end
            ShowStyledTooltip(self2)
        end)
        b:SetScript("OnLeave", HideStyledTooltip)
    end

    local idx = 0
    for rowIndex, cnt in ipairs(rowCounts) do
        local avail = totalWidth - gap * (cnt - 1)
        local totalWeight = 0
        for c = 1, cnt do
            local seg = segments[idx + c]
            totalWeight = totalWeight + ((seg and tonumber(seg.weight)) or 1)
        end
        local x = 0
        for c = 0, cnt - 1 do
            idx = idx + 1
            local seg = segments[idx]
            if seg then
                local wgt = tonumber(seg.weight) or 1
                local w = (c == cnt - 1) and (totalWidth - x) or math.floor(avail * wgt / totalWeight)
                local b = self:CreateTextButton(holder, nil, w, rowH, seg.label)
                if b.text then ApplyFont(b.text, 12, "") end
                b:SetPoint("TOPLEFT", x, -(rowIndex - 1) * (rowH + gap))
                b.segValue = seg.value
                b:SetScript("OnClick", function(self2)
                    if holder.setValue then holder.setValue(self2.segValue) end
                    CO:UpdateQueueSettingWidgets()
                    CO:RefreshVisibleRowsSafe()
                end)
                AttachTip(b)
                holder.buttons[idx] = b
                x = x + w + gap
            end
        end
    end

    return holder
end

function CO:StyleWidget(frame, selected)
    if not frame then return end
    if frame.hironClassicClose then return end
    if frame.GetObjectType and frame:GetObjectType() == "Button" and frame.text then
        self:StyleClassicButton(frame, selected)
    else
        self:ApplyClassicInset(frame)
        if frame.GetObjectType and frame:GetObjectType() == "EditBox" then
            frame:SetTextColor(1, 1, 1)
        end
    end
end

local PROFESSION_BG = {
    [171] = "Alchemy",
    [164] = "Blacksmithing",
    [333] = "Enchanting",
    [202] = "Engineering",
    [773] = "Inscription",
    [755] = "Jewelcrafting",
    [165] = "Leatherworking",
    [197] = "Tailoring",
    [185] = "Cooking",
    [182] = "Herbalism",
    [186] = "Mining",
    [393] = "Skinning",
    [356] = "Fishing",
}
if Enum and Enum.Profession then
    PROFESSION_BG[Enum.Profession.Alchemy]        = "Alchemy"
    PROFESSION_BG[Enum.Profession.Blacksmithing]  = "Blacksmithing"
    PROFESSION_BG[Enum.Profession.Enchanting]     = "Enchanting"
    PROFESSION_BG[Enum.Profession.Engineering]    = "Engineering"
    PROFESSION_BG[Enum.Profession.Inscription]    = "Inscription"
    PROFESSION_BG[Enum.Profession.Jewelcrafting]  = "Jewelcrafting"
    PROFESSION_BG[Enum.Profession.Leatherworking] = "Leatherworking"
    PROFESSION_BG[Enum.Profession.Tailoring]      = "Tailoring"
    PROFESSION_BG[Enum.Profession.Cooking]        = "Cooking"
    PROFESSION_BG[Enum.Profession.Herbalism]      = "Herbalism"
    PROFESSION_BG[Enum.Profession.Mining]         = "Mining"
    PROFESSION_BG[Enum.Profession.Skinning]       = "Skinning"
    PROFESSION_BG[Enum.Profession.Fishing]        = "Fishing"
end

function CO:GetProfessionBgSuffix(pageFrame)
    local cands = {}
    local function push(v) if v ~= nil then cands[#cands + 1] = v end end
    local function add(info)
        if type(info) ~= "table" then return end
        push(info.profession); push(info.professionID)
        push(info.parentProfession); push(info.parentProfessionID)
    end
    if C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo then
        local ok, info = pcall(C_TradeSkillUI.GetBaseProfessionInfo); if ok then add(info) end
    end
    if pageFrame then add(pageFrame.professionInfo) end
    if C_TradeSkillUI and C_TradeSkillUI.GetChildProfessionInfo then
        local ok, info = pcall(C_TradeSkillUI.GetChildProfessionInfo); if ok then add(info) end
    end
    for _, c in ipairs(cands) do
        local s = PROFESSION_BG[tonumber(c) or c]
        if s then return s end
    end
    return nil
end

function CO:UpdatePageBackground(pageFrame)
    pageFrame = pageFrame or self.activePageFrame
    if not pageFrame then return end
    local container = pageFrame.ahuiCustomList
    if not container or not container.profBg then return end
    -- Keep the custom rows transparent over Blizzard's original crafting-order
    -- background. The old ProfitHUB logo tile obscured the default artwork.
    container.profBg:Hide()
    if container.tile then container.tile:Hide() end
    self:ApplyClassicInset(container)
end

function CO:UpdateSegmentedControl(holder)
    if not holder or not holder.buttons then return end
    local cur = holder.getValue and holder.getValue()
    for _, b in ipairs(holder.buttons) do
        CO:StyleWidget(b, b.segValue == cur)
    end
end

function CO:CreateCheckToggle(parent, label, getValue, setValue, width)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 82, 20)
    b.getValue = getValue
    b.setValue = setValue

    b.box = b:CreateTexture(nil, "ARTWORK")
    b.box:SetSize(16, 16)
    b.box:SetPoint("LEFT", 0, 0)
    b.box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")

    b.check = b:CreateTexture(nil, "OVERLAY")
    b.check:SetSize(14, 14)
    b.check:SetPoint("CENTER", b.box, "CENTER", 0, 0)
    b.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")

    b.label = b:CreateFontString(nil, "OVERLAY")
    ApplyFont(b.label, 12, "")
    b.label:SetPoint("LEFT", b.box, "RIGHT", 3, 0)
    b.label:SetPoint("RIGHT", 0, 0)
    b.label:SetJustifyH("LEFT")
    b.label:SetWordWrap(false)
    b.label:SetText(label)

    b:SetScript("OnClick", function(self2)
        if self2.setValue and self2.getValue then
            self2.setValue(not self2.getValue())
        end
        CO:UpdateQueueSettingWidgets()
        CO:RefreshVisibleRowsSafe()
    end)
    b:SetScript("OnEnter", function(self2) self2.box:SetVertexColor(1.25, 1.25, 1.25) end)
    b:SetScript("OnLeave", function(self2) self2.box:SetVertexColor(1, 1, 1) end)

    return b
end

function CO:UpdateCheckToggle(b)
    if not b then return end
    local on = b.getValue and b.getValue()
    if b.check then b.check:SetShown(on and true or false) end
    if b.label then
        local c = on and { 1, 0.82, 0.2, 1 } or { 0.65, 0.61, 0.53, 1 }
        b.label:SetTextColor(c[1], c[2], c[3], c[4])
    end
end

function CO:RefreshVisibleRowsSafe()
    if self.RefreshVisibleRows then self:RefreshVisibleRows() end
    if self.UpdateControlPanel then self:UpdateControlPanel() end
end

function CO:UpdateQueueSettingWidgets()
    local panel = self.controlPanel
    if not panel then return end

    self:UpdateSegmentedControl(panel.reagentSeg)
    self:UpdateSegmentedControl(panel.concSeg)

    self:UpdateCheckToggle(panel.autoQueueCheck)
    self:UpdateCheckToggle(panel.autoShopCheck)

    if panel.minProfitInput and panel.minProfitInput.RefreshValue then
        panel.minProfitInput:RefreshValue()
    end

    if panel.bagValueInput and panel.bagValueInput.RefreshValue then
        panel.bagValueInput:RefreshValue()
    end

    if panel.kpValueInput and panel.kpValueInput.RefreshValue then
        panel.kpValueInput:RefreshValue()
    end

    if panel.finisherButton and panel.finisherButton.text then
        panel.finisherButton.text:SetText(self:GetAutoFinishingLabel())
    end
end

function CO:OpenAutoFinishingMenu(owner)
    if not owner or not PT.Dropdown or not PT.Dropdown.Show then return end

    local enabled = self:IsAutoFinishingEnabled()
    local currentLimit = self:GetAutoFinishingMaxSkillBonus()
    local items = {
        {
            text = T("COA_FINISHER_MENU_TITLE", "Автофинишеры"),
            header = true,
        },
        {
            text = T("COA_FINISHER_ENABLE", "Использовать автоматически"),
            checked = enabled,
            onClick = function()
                CO:SetAutoFinishingEnabled(not enabled)
            end,
        },
        {
            text = T("COA_FINISHER_LIMIT_HEADER", "Максимальное усиление навыка"),
            header = true,
        },
    }

    for _, limit in ipairs({ 5, 10, 20, 50 }) do
        local selectedLimit = limit
        items[#items + 1] = {
            text = string.format(T("COA_FINISHER_LIMIT_OPTION_FMT", "До +%d навыка"), selectedLimit),
            checked = currentLimit == selectedLimit,
            onClick = function()
                CO:SetAutoFinishingMaxSkillBonus(selectedLimit)
            end,
        }
    end

    PT.Dropdown:Show({ owner = owner, items = items })
end

function CO:AnchorControlPanelToOrderList(panel, pageFrame)
    if not panel or not pageFrame then return end
    panel:ClearAllPoints()
    local list = pageFrame.BrowseFrame and pageFrame.BrowseFrame.OrderList
    if list then
        panel:SetPoint("TOPLEFT", list, "TOPRIGHT", self.CLASSIC_PANEL_GAP, 0)
        panel:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", self.CLASSIC_PANEL_GAP, 0)
    else
        panel:SetPoint("TOPLEFT", pageFrame, "TOPRIGHT", self.CLASSIC_PANEL_GAP, -110)
        panel:SetPoint("BOTTOMLEFT", pageFrame, "BOTTOMRIGHT", self.CLASSIC_PANEL_GAP, 10)
    end
    if panel.collapseButton then
        panel.collapseButton:ClearAllPoints()
        if list then
            panel.collapseButton:SetPoint("BOTTOMRIGHT", list, "TOPRIGHT", -6, 6)
        else
            panel.collapseButton:SetPoint("TOPRIGHT", pageFrame, "TOPRIGHT", -6, -80)
        end
        panel.collapseButton.text:SetText(GetDB().panelCollapsed and "<" or ">")
    end
end

function CO:EnsureControlPanel(pageFrame)
    if not self:IsEnabled() then
        if self.controlPanel then
            self.controlPanel:Hide()
            if self.controlPanel.collapseButton then self.controlPanel.collapseButton:Hide() end
        end
        if pageFrame and pageFrame.ahuiCraftingOrdersPanel then
            pageFrame.ahuiCraftingOrdersPanel:Hide()
            if pageFrame.ahuiCraftingOrdersPanel.collapseButton then pageFrame.ahuiCraftingOrdersPanel.collapseButton:Hide() end
        end
        return
    end

    if not pageFrame or pageFrame.ahuiCraftingOrdersPanel then
        if pageFrame and pageFrame.ahuiCraftingOrdersPanel then
            self.controlPanel = pageFrame.ahuiCraftingOrdersPanel
            self:UpdateControlPanel()
        end
        return
    end


    local VPANEL_W = self.CLASSIC_PANEL_WIDTH
    local PADX = 8
    local INNER = VPANEL_W - 40 - PADX * 2
    local COL_GAP = 6
    local COL_W = math.floor((INNER - COL_GAP) / 2)

    local panel = CreateFrame("Frame", nil, pageFrame, "BackdropTemplate")
    panel:SetWidth(VPANEL_W)
    panel:SetFrameLevel((pageFrame:GetFrameLevel() or 1) + 60)
    panel.pageFrame = pageFrame
    self:CreateClassicPanelShell(panel)
    self:AnchorControlPanelToOrderList(panel, pageFrame)
    -- Help icon (top-left)
    panel.helpButton = CreateFrame("Button", nil, panel)
    panel.helpButton:SetSize(28, 28)
    panel.helpButton:SetPoint("TOPLEFT", 6, -6)
    panel.helpButton.icon = panel.helpButton:CreateTexture(nil, "ARTWORK")
    panel.helpButton.icon:SetAllPoints()
    panel.helpButton.icon:SetTexture("Interface\\COMMON\\help-i")
    panel.helpButton:SetScript("OnEnter", function(self)
        if not Tooltip then return end
        Tooltip:Clear()
        Tooltip:AddLine(T("COA_PANEL_HELP_TITLE", "HironCraftProfit crafting order queue"), 14, 1, 0.82, 0.35)
        Tooltip:AddLine(T("COA_PANEL_HELP_DESC", "Check orders inside row buttons, then press the assigned key. Each key press performs one allowed step: claim, craft, or complete. Right-click a row button to release a claimed order."), 11, 0.85, 0.85, 0.85)
        Tooltip:AddLine(" ", 4, 1, 1, 1)
        Tooltip:AddLine(T("COA_PANEL_HELP_ROW_COLORS_TITLE", "Row colors:"), 12, 1, 0.82, 0.35)
        Tooltip:AddLine(T("COA_PANEL_HELP_ROW_GREEN", "Green: can be crafted."), 11, 0.45, 1.00, 0.45)
        Tooltip:AddLine(T("COA_PANEL_HELP_ROW_YELLOW", "Yellow: requested quality needs concentration."), 11, 1.00, 0.82, 0.25)
        Tooltip:AddLine(T("COA_PANEL_HELP_ROW_RED", "Red: recipe is unknown or unavailable."), 11, 1.00, 0.35, 0.35)
        ShowStyledTooltip(self)
    end)
    panel.helpButton:SetScript("OnLeave", HideStyledTooltip)

    -- Title (next to the help icon)
    panel.titleFS = panel:CreateFontString(nil, "OVERLAY")
    ApplyFont(panel.titleFS, 13, "OUTLINE")
    panel.titleFS:SetPoint("LEFT", panel.helpButton, "RIGHT", 6, 0)
    panel.titleFS:SetPoint("RIGHT", panel, "RIGHT", -6, 0)
    panel.titleFS:SetJustifyH("LEFT")
    panel.titleFS:SetText(T("COA_PANEL_TITLE", "Очередь заказов"))


    local body = panel.classicPages.craft.body
    local y = -8
    local function AddHeader(text)
        local fs = body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", PADX, y)
        fs:SetWidth(INNER)
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        y = y - 22
        return fs
    end
    -- Reagent mode (two rows)
    AddHeader(T("COA_QUEUE_REAGENTS_HEADER", "Реагенты"))
    panel.reagentSeg = self:CreateSegmentedControl(body, {
        { value = "auto",   label = T("COA_QUEUE_REAGENT_MODE_AUTO_SHORT", "Авто") },
        { value = "t1",     label = "T1" },
        { value = "t2",     label = "T2" },
        { value = "profit", label = T("COA_QUEUE_REAGENT_MODE_PROFIT", "Профит") },
        { value = "manual", label = T("COA_QUEUE_REAGENT_MODE_MANUAL", "Ручной") },
    }, INNER, function() return CO:GetQueueReagentMode() end, function(v) CO:SetQueueReagentMode(v) end,
    { rows = { 3, 2 },
      tipTitle = T("COA_REAGENT_TIP_TITLE", "Режим реагентов"),
      tipDesc = T("COA_REAGENT_TIP_DESC", "Авто (эконом) — автоподбор самых дешёвых реагентов под нужное качество. T1 / T2 — принудительно этот грейд для всех слотов. Проф — грейды под максимальную выгоду. Руч — не трогать выбранные вручную реагенты.") })
    panel.reagentSeg:SetPoint("TOPLEFT", PADX, y)
    y = y - 50

    -- Concentration
    AddHeader(T("COA_QUEUE_CONC_HEADER", "Концентрация"))
    panel.concSeg = self:CreateSegmentedControl(body, {
        { value = "off",   label = T("COA_CONC_OFF", "Выкл"), weight = 1 },
        { value = "allow", label = T("COA_CONC_ALLOW_FULL", "Разрешить"), weight = 2 },
    }, INNER, function() local m = CO:GetQueueConcMode(); return m == "force" and "allow" or m end,
    function(v) CO:SetQueueConcMode(v) end,
    { columns = 2,
      tipTitle = T("COA_CONC_TIP_TITLE", "Концентрация в очереди"),
      tipDesc = T("COA_CONC_TIP_DESC", "Выкл — не тратить концентрацию. Разр. — тратить, только если без неё нужное качество недостижимо. Прин. — тратить всегда для повышения качества.") })
    panel.concSeg:SetPoint("TOPLEFT", PADX, y)
    y = y - 26

    -- Automatic finishing reagents. The menu separates the master switch from
    -- the maximum skill bonus the queue may consume before declining an order.
    local finisherHeader = body:CreateFontString(nil, "OVERLAY")
    ApplyFont(finisherHeader, 11, "OUTLINE")
    finisherHeader:SetPoint("TOPLEFT", PADX, y - 4)
    finisherHeader:SetTextColor(1, 0.82, 0.35, 1)
    finisherHeader:SetText(T("COA_FINISHER_HEADER", "Финишеры"))
    panel.finisherButton = self:CreateTextButton(
        body,
        nil,
        62,
        20,
        self:GetAutoFinishingLabel()
    )
    panel.finisherButton:SetPoint("TOPRIGHT", -PADX, y)
    panel.finisherButton:SetScript("OnClick", function(self)
        CO:OpenAutoFinishingMenu(self)
    end)
    panel.finisherButton:SetScript("OnEnter", function(self)
        if not Tooltip then return end
        Tooltip:Clear()
        Tooltip:AddLine(T("COA_FINISHER_TOOLTIP_TITLE", "Автоматические финишеры"), 13, 1, 0.82, 0.35)
        Tooltip:AddLine(T("COA_FINISHER_TOOLTIP_DESC", "Перед крафтом выбирает самый слабый имеющийся финишер, который гарантирует заказанное качество. Если нужен финишер сильнее разрешённого, персональный заказ отклоняется."), 11, 0.85, 0.85, 0.85)
        ShowStyledTooltip(self)
    end)
    panel.finisherButton:SetScript("OnLeave", HideStyledTooltip)
    y = y - 26


    y = y - 12
    AddHeader(T("COA_CLASSIC_TOOLS", "Profession equipment"))
    -- Tool icons row (centered): best quality, auto tool, profession tool slot
    local toolsRowW = PROFESSION_TOOL_SLOT_SIZE * 3 + 8 * 2
    local toolsStartX = PADX + math.max(0, math.floor((INNER - toolsRowW) / 2))
    panel.bestQualityToggle = self:CreateBestQualityToggle(body)
    panel.bestQualityToggle:SetPoint("TOPLEFT", toolsStartX, y)
    panel.autoToolToggle = self:CreateAutoToolToggle(body)
    panel.autoToolToggle:SetPoint("LEFT", panel.bestQualityToggle, "RIGHT", 8, 0)
    panel.professionToolSlot = self:CreateProfessionToolSlot(body)
    panel.professionToolSlot:SetPoint("LEFT", panel.autoToolToggle, "RIGHT", 8, 0)
    y = y - 44

    -- Expansion + weekly quest (bottom of settings block)
    panel.expansionButton = self:CreateTextButton(body, nil, COL_W, 20, self:GetSelectedProfessionExpansionLabel())
    if panel.expansionButton.text then ApplyFont(panel.expansionButton.text, 12, "") end
    panel.expansionButton:SetPoint("TOPLEFT", PADX, y)
    panel.expansionButton:SetScript("OnClick", function(self)
        CO:OpenProfessionExpansionMenu(self)
    end)
    panel.expansionButton:SetScript("OnEnter", function(self)
        if not Tooltip then return end
        Tooltip:Clear()
        Tooltip:AddLine(T("COA_EXPANSION_DROPDOWN_TITLE", "Profession expansion"), 13, 1, 0.82, 0.35)
        Tooltip:AddLine(T("COA_EXPANSION_DROPDOWN_TOOLTIP", "Switches the actual profession expansion, like Blizzard's profession page dropdown."), 11, 0.85, 0.85, 0.85)
        ShowStyledTooltip(self)
    end)
    panel.expansionButton:SetScript("OnLeave", HideStyledTooltip)

    panel.weeklyQuestIndicator = self:CreateTextButton(body, nil, COL_W, 20, "")
    if panel.weeklyQuestIndicator.text then ApplyFont(panel.weeklyQuestIndicator.text, 12, "") end
    panel.weeklyQuestIndicator:SetPoint("TOPLEFT", PADX + COL_W + COL_GAP, y)
    panel.weeklyQuestIndicator:SetScript("OnClick", nil)
    panel.weeklyQuestIndicator:SetScript("OnEnter", function(self)
        CO:ShowWeeklyQuestIndicatorTooltip(self)
    end)
    panel.weeklyQuestIndicator:SetScript("OnLeave", HideStyledTooltip)


    body:SetHeight(-y + 26)

    body = panel.classicPages.queue.body
    y = -8
    AddHeader(T("COA_CLASSIC_FILTERS", "Order filters"))
    -- Min profit
    local mpHeader = body:CreateFontString(nil, "OVERLAY")
    ApplyFont(mpHeader, 11, "OUTLINE")
    mpHeader:SetPoint("TOPLEFT", PADX, y - 4)
    mpHeader:SetTextColor(1, 0.82, 0.35, 1)
    mpHeader:SetText(T("COA_QUEUE_MINPROFIT_HEADER", "Мин. профит"))
    panel.minProfitInput = self:CreateValueInput(body, 62, 20,
        function() return CO:GetQueueMinProfitCopper() end,
        function(c) CO:SetQueueMinProfitCopper(c) end)
    panel.minProfitInput:SetPoint("TOPRIGHT", -PADX, y)
    y = y - 26

    -- Bag reward value
    local bagHeader = body:CreateFontString(nil, "OVERLAY")
    ApplyFont(bagHeader, 11, "OUTLINE")
    bagHeader:SetPoint("TOPLEFT", PADX, y - 4)
    bagHeader:SetTextColor(1, 0.82, 0.35, 1)
    bagHeader:SetText(T("COA_QUEUE_BAGVALUE_HEADER", "Цена сумки"))
    panel.bagValueInput = self:CreateValueInput(body, 62, 20,
        function() return CO:GetBagRewardValueCopper() end,
        function(c) CO:SetBagRewardValueCopper(c) end)
    panel.bagValueInput:SetPoint("TOPRIGHT", -PADX, y)
    y = y - 26

    -- Knowledge point value
    local kpHeader = body:CreateFontString(nil, "OVERLAY")
    ApplyFont(kpHeader, 11, "OUTLINE")
    kpHeader:SetPoint("TOPLEFT", PADX, y - 4)
    kpHeader:SetTextColor(1, 0.82, 0.35, 1)
    kpHeader:SetText(T("COA_QUEUE_KPVALUE_HEADER", "Цена ОЗ"))
    panel.kpValueInput = self:CreateValueInput(body, 62, 20,
        function() return CO:GetKnowledgePointValueCopper() end,
        function(c) CO:SetKnowledgePointValueCopper(c) end)
    panel.kpValueInput:SetPoint("TOPRIGHT", -PADX, y)
    y = y - 28

    -- Auto on open (stacked)
    AddHeader(T("COA_QUEUE_AUTO_ON_OPEN_HEADER", "При открытии"))
    panel.autoQueueCheck = self:CreateCheckToggle(body, T("COA_AUTO_QUEUE_SHORT", "Очередь"),
        function() return CO:IsAutoQueueOnOpen() end,
        function(v) CO:SetAutoQueueOnOpen(v) end, 74)
    panel.autoQueueCheck:SetPoint("TOPLEFT", PADX, y)
    panel.autoQueueCheck:HookScript("OnEnter", function(self)
        if not Tooltip then return end
        Tooltip:Clear()
        Tooltip:AddLine(T("COA_ONE_BUTTON_TITLE", "One-button personal orders"), 13, 1, 0.82, 0.35)
        Tooltip:AddLine(T("COA_ONE_BUTTON_TIP", "Opens Personal orders, selects all, and temporarily reuses Interact With Target for the next queue action."), 11, 0.85, 0.85, 0.85)
        ShowStyledTooltip(self)
    end)
    panel.autoQueueCheck:HookScript("OnLeave", HideStyledTooltip)
    panel.autoShopCheck = self:CreateCheckToggle(body, T("COA_AUTO_SHOP_SHORT", "Закуп"),
        function() return CO:IsAutoShoppingOnOpen() end,
        function(v) CO:SetAutoShoppingOnOpen(v) end, INNER - 74)
    panel.autoShopCheck:SetPoint("TOPLEFT", PADX + 74, y)
    y = y - 24

    body:SetHeight(-y + 8)
    body = panel.queueActions
    y = -6
    local ACTION_INNER = VPANEL_W - 26
    local ACTION_COL_W = math.floor((ACTION_INNER - COL_GAP) / 2)

    -- Queue action (full width)
    panel.selectAllButton = self:CreateTextButton(body, nil, ACTION_INNER, 26, T("COA_QUEUE_BUTTON", "Queue"))
    if panel.selectAllButton.text then ApplyFont(panel.selectAllButton.text, 13, "") end
    panel.selectAllButton:SetPoint("TOPLEFT", PADX, y)
    panel.selectAllButton:SetScript("OnClick", function(self)
        CO:QueueWorkOrdersSelection()
    end)
    panel.selectAllButton:SetScript("OnEnter", function(self)
        if not Tooltip then return end
        Tooltip:Clear()
        Tooltip:AddLine(T("COA_QUEUE_TOOLTIP_TITLE", "Queue work orders"), 13, 1, 0.82, 0.35)
        Tooltip:AddLine(T("COA_QUEUE_TOOLTIP", "Builds a work-order queue with HironCraftProfit checks and marks matching order buttons."), 11, 0.85, 0.85, 0.85)
        Tooltip:AddLine(string.format(T("COA_QUEUE_REAGENT_MODE_CURRENT_FMT", "Reagents: %s"), CO:GetQueueReagentModeLabel()), 11, 0.70, 0.90, 1)
        Tooltip:AddLine(string.format(T("COA_QUEUE_PROFIT_FILTER_CURRENT_FMT", "Minimum profit: %s"), CO:GetQueueMinProfitText()), 11, 0.70, 0.90, 1)
        ShowStyledTooltip(self)
    end)
    panel.selectAllButton:SetScript("OnLeave", HideStyledTooltip)
    y = y - 32

    -- Knowledge-only queue (patron) / select-all-visible (other tabs)
    panel.knowledgeButton = self:CreateTextButton(body, nil, ACTION_INNER, 22, T("COA_KNOWLEDGE_QUEUE_BTN", "Очередь: знания"))
    if panel.knowledgeButton.text then ApplyFont(panel.knowledgeButton.text, 12, "") end
    panel.knowledgeButton:SetPoint("TOPLEFT", PADX, y)
    panel.knowledgeButton:SetBackdropBorderColor(0.30, 0.60, 1.00, 1)
    panel.knowledgeButton:SetScript("OnClick", function(self)
        CO:QueueWorkOrdersSelection(true)
    end)
    panel.knowledgeButton:SetScript("OnEnter", function(self)
        if not Tooltip then return end
        Tooltip:Clear()
        Tooltip:AddLine(T("COA_KNOWLEDGE_QUEUE_TITLE", "Очередь: только знания"), 13, 1, 0.82, 0.35)
        Tooltip:AddLine(T("COA_KNOWLEDGE_QUEUE_TIP", "Добавляет заказы со знаниями независимо от профита, сохраняя уже выбранные. Заказы с неизвестным рецептом или требующие концентрацию исключаются. Недостающие реагенты можно добавить в закупку."), 11, 0.85, 0.85, 0.85)
        ShowStyledTooltip(self)
    end)
    panel.knowledgeButton:SetScript("OnLeave", HideStyledTooltip)

    panel.selectAllOrdersButton = self:CreateTextButton(body, nil, ACTION_INNER, 22, T("COA_SELECT_ALL_TITLE", "Select all"))
    if panel.selectAllOrdersButton.text then ApplyFont(panel.selectAllOrdersButton.text, 12, "") end
    panel.selectAllOrdersButton:SetPoint("TOPLEFT", PADX, y)
    panel.selectAllOrdersButton:Hide()
    panel.selectAllOrdersButton:SetScript("OnClick", function()
        CO:SelectAllVisibleOrders()
    end)
    panel.selectAllOrdersButton:SetScript("OnEnter", function(self)
        if not Tooltip then return end
        Tooltip:Clear()
        Tooltip:AddLine(T("COA_SELECT_ALL_TITLE", "Select all"), 13, 1, 0.82, 0.35)
        Tooltip:AddLine(T("COA_SELECT_ALL_TIP", "Selects all orders on this tab."), 11, 0.85, 0.85, 0.85)
        ShowStyledTooltip(self)
    end)
    panel.selectAllOrdersButton:SetScript("OnLeave", HideStyledTooltip)
    y = y - 28

    -- Shopping + Clear (two columns)
    panel.shopButton = self:CreateTextButton(body, nil, ACTION_COL_W, 22, T("COA_SHOPPING_BUTTON", "Shopping"))
    if panel.shopButton.text then ApplyFont(panel.shopButton.text, 12, "") end
    panel.shopButton:SetPoint("TOPLEFT", PADX, y)
    panel.shopButton:SetScript("OnClick", function()
        CO:CreateShoppingListForSelectedOrders()
    end)
    panel.shopButton:SetScript("OnEnter", function(self)
        if not Tooltip then return end
        Tooltip:Clear()
        Tooltip:AddLine(T("COA_SHOPPING_TOOLTIP_TITLE", "Create shopping list"), 13, 1, 0.82, 0.35)
        Tooltip:AddLine(T("COA_SHOPPING_TOOLTIP", "Creates an HironCraftProfitshop shopping list from checked orders and selected reagent grades. Customer/NPC-provided reagents are skipped; only missing quantities are added."), 11, 0.85, 0.85, 0.85)
        if CO.UpdateShoppingCostText then
            CO:UpdateShoppingCostText()
        end
        if CO.GetSelectedShoppingCostInfo then
            local info = CO:GetSelectedShoppingCostInfo()
            if info then
                Tooltip:AddLine(" ", 4, 1, 1, 1)
                Tooltip:AddLine(T("COA_SHOPPING_BUTTON", "Shopping") .. ": " .. tostring(info.text or "-"), 11, 1, 0.82, 0.35)
                if info.missingPrices then
                    Tooltip:AddLine("+?", 11, 1, 0.35, 0.35)
                end
            end
        end
        ShowStyledTooltip(self)
    end)
    panel.shopButton:SetScript("OnLeave", HideStyledTooltip)

    panel.clearSelectedButton = self:CreateTextButton(body, nil, ACTION_COL_W, 22, T("COA_CLEAR_SELECTED", "Clear"))
    if panel.clearSelectedButton.text then ApplyFont(panel.clearSelectedButton.text, 12, "") end
    panel.clearSelectedButton:SetPoint("TOPLEFT", PADX + ACTION_COL_W + COL_GAP, y)
    panel.clearSelectedButton:SetScript("OnClick", function()
        CO:ClearSelectedOrders()
    end)

    -- Shopping cost centered under Shopping; selected count centered under Clear
    panel.shopCostText = body:CreateFontString(nil, "OVERLAY")
    ApplyFont(panel.shopCostText, 12, "")
    panel.shopCostText:SetPoint("TOP", panel.shopButton, "BOTTOM", 0, -3)
    panel.shopCostText:SetWidth(ACTION_COL_W)
    panel.shopCostText:SetJustifyH("CENTER")
    panel.shopCostText:SetText("")
    panel.shopCostText:SetTextColor(0.95, 0.82, 0.42, 1)


    local footer = panel.footer
    y = -64
    -- Action: click-equivalent of the hotkey (performs one order step per click)
    panel.runActionButton = self:CreateTextButton(footer, nil, INNER, 24, T("COA_CL_RUN_NEXT", "Действие"))
    if panel.runActionButton.text then ApplyFont(panel.runActionButton.text, 13, "") end
    panel.runActionButton:SetPoint("TOPLEFT", PADX, y)
    panel.runActionButton:SetBackdropBorderColor(0.30, 0.75, 0.40, 1)
    panel.runActionButton:SetScript("OnClick", function()
        CO:RunActiveRowAction()
    end)
    panel.runActionButton:SetScript("OnEnter", function(self)
        if not Tooltip then return end
        Tooltip:Clear()
        Tooltip:AddLine(T("COA_CL_RUN_NEXT_TITLE", "Выполнить действие"), 13, 1, 0.82, 0.35)
        Tooltip:AddLine(T("COA_CL_RUN_NEXT_TIP", "Отметь заказы галочками и жми — за одно нажатие выполняется одно действие по очереди (взять / скрафтить / завершить), как по биндом."), 11, 0.85, 0.85, 0.85)
        ShowStyledTooltip(self)
    end)
    panel.runActionButton:SetScript("OnLeave", HideStyledTooltip)
    y = y - 32

    -- Hotkey: label on its own line, then Bind / clear
    panel.keyText = footer:CreateFontString(nil, "OVERLAY")
    ApplyFont(panel.keyText, 12, "")
    panel.keyText:SetPoint("TOPLEFT", PADX, y - 3)
    panel.keyText:SetWidth(INNER)
    panel.keyText:SetJustifyH("CENTER")
    y = y - 20

    local bindGroupW = 60 + 4 + 24
    local bindStartX = PADX + math.max(0, math.floor((INNER - bindGroupW) / 2))
    panel.bindButton = self:CreateTextButton(footer, nil, 60, 22, T("COA_BIND_ASSIGN", "Bind"))
    if panel.bindButton.text then ApplyFont(panel.bindButton.text, 12, "") end
    panel.bindButton:SetPoint("TOPLEFT", bindStartX, y)
    panel.bindButton:SetScript("OnClick", function()
        CO:CreateBindCapture()
        CO.bindCapture:Show()
    end)

    panel.clearButton = CreateFrame("Button", nil, footer, "UIPanelCloseButton")
    panel.clearButton.hironClassicClose = true
    panel.clearButton:SetSize(28, 28)
    panel.clearButton:SetPoint("LEFT", panel.bindButton, "RIGHT", 4, 0)
    panel.clearButton:SetScript("OnClick", function()
        CO:ClearBinding()
        CO:SetStatus(T("COA_STATUS_BIND_CLEARED", "Order hotkey cleared."))
        CO:UpdateControlPanel()
    end)
    y = y - 30


    panel.runActionButton:ClearAllPoints()
    panel.runActionButton:SetPoint("TOPLEFT", footer, "TOPLEFT", 10, -64)
    panel.runActionButton:SetSize(VPANEL_W - 30, 28)
    panel.runActionButton.text:SetWidth(VPANEL_W - 40)
    panel.keyText:ClearAllPoints()
    panel.keyText:SetPoint("BOTTOMLEFT", footer, "BOTTOMLEFT", 10, 13)
    panel.keyText:SetWidth(100)
    panel.keyText:SetJustifyH("LEFT")
    panel.bindButton:ClearAllPoints()
    panel.bindButton:SetPoint("BOTTOMRIGHT", footer, "BOTTOMRIGHT", -36, 8)
    panel.bindButton:SetWidth(68)
    panel.clearButton:ClearAllPoints()
    panel.clearButton:SetPoint("BOTTOMRIGHT", footer, "BOTTOMRIGHT", -5, 5)

    panel.selectedText = footer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.selectedText:SetPoint("TOPLEFT", 10, -8)
    panel.selectedText:SetWidth(VPANEL_W - 30)
    panel.selectedText:SetJustifyH("LEFT")
    panel.statusText = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.statusText:SetPoint("TOPLEFT", 10, -26)
    panel.statusText:SetSize(VPANEL_W - 30, 32)
    panel.statusText:SetJustifyH("LEFT")
    panel.statusText:SetJustifyV("TOP")
    panel.statusText:SetMaxLines(2)
    local statusTip = CreateFrame("Frame", nil, footer)
    statusTip:SetAllPoints(panel.statusText)
    statusTip:EnableMouse(true)
    statusTip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(CO.lastStatus or T("COA_CLASSIC_READY", "Select orders and press Action."), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    statusTip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Action-debug toggle: tiny square flush in the bottom-right corner
    panel.debugToggle = CreateFrame("Button", nil, panel)
    panel.debugToggle:SetSize(10, 10)
    panel.debugToggle:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
    panel.debugToggle:SetFrameLevel((panel:GetFrameLevel() or 1) + 6)
    panel.debugToggle.tex = panel.debugToggle:CreateTexture(nil, "OVERLAY")
    panel.debugToggle.tex:SetAllPoints()
    panel.debugToggle.tex:SetAtlas("SquareMask")
    panel.debugToggle.tex:SetVertexColor(0, 0, 0, 0.85)
    panel.debugToggle:RegisterForClicks("RightButtonUp")
    panel.debugToggle:SetScript("OnClick", function(self, button)
        if button == "RightButton" and IsShiftKeyDown() then
            CO:ToggleActionDebug()
        end
    end)

    panel.debugDummy = panel:CreateTexture(nil, "OVERLAY")
    panel.debugDummy:SetSize(10, 10)
    panel.debugDummy:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    panel.debugDummy:SetAtlas("SquareMask")
    panel.debugDummy:SetVertexColor(0, 0, 0, 0.85)

    self:UpdateSegmentedControl(panel.reagentSeg)
    self:UpdateSegmentedControl(panel.concSeg)
    self:UpdateCheckToggle(panel.autoQueueCheck)
    self:UpdateCheckToggle(panel.autoShopCheck)
    for _, w in ipairs({ panel.minProfitInput, panel.bagValueInput, panel.kpValueInput }) do
        if w then self:StyleWidget(w) end
    end

    for _, w in ipairs({
        panel.selectAllButton, panel.knowledgeButton, panel.selectAllOrdersButton,
        panel.shopButton, panel.clearSelectedButton, panel.runActionButton,
        panel.bindButton, panel.clearButton, panel.expansionButton, panel.weeklyQuestIndicator,
        panel.finisherButton,
    }) do
        if w then self:StyleWidget(w) end
    end
    for _, w in ipairs({ panel.bestQualityToggle, panel.autoToolToggle, panel.professionToolSlot }) do
        if w then self:StyleWidget(w) end
    end
    pageFrame.ahuiCraftingOrdersPanel = panel
    self.controlPanel = panel
    self:EnsureConflictBar(pageFrame)
    self:UpdateControlPanel()
    self:UpdateControlPanelVisibility(pageFrame)
    self:UpdateTabActionButton(pageFrame)
    self:UpdateConflictBar(pageFrame)
end

function CO:UpdateTabActionButton(pageFrame)
    local panel = self.controlPanel or (pageFrame and pageFrame.ahuiCraftingOrdersPanel)
    if not panel then return end
    pageFrame = pageFrame or panel.pageFrame or self.activePageFrame

    local isPatron = pageFrame ~= nil and Enum and Enum.CraftingOrderType
        and pageFrame.orderType == Enum.CraftingOrderType.Npc

    if panel.knowledgeButton then panel.knowledgeButton:SetShown(isPatron and true or false) end
    if panel.selectAllOrdersButton then panel.selectAllOrdersButton:SetShown((not isPatron) and true or false) end
end

function CO:UpdateDebugToggle()
    local panel = self.controlPanel
    local b = panel and panel.debugToggle
    if not b or not b.tex then return end
    if self:IsActionDebug() then
        b.tex:SetVertexColor(0.20, 1.00, 0.20, 1)
    else
        b.tex:SetVertexColor(0, 0, 0, 0.85)
    end
end

function CO:EnsureConflictBar(pageFrame)
    return nil
end

function CO:UpdateConflictBar(pageFrame)
end

function CO:GetVisibleButtonForOrder(orderID)
    local key = OrderKey(orderID)
    local function isVisible(btn)
        if not btn then return false end
        if btn.IsVisible then return btn:IsVisible() end
        return btn.IsShown and btn:IsShown()
    end

    local btn = key and self.rowButtonsByOrderID and self.rowButtonsByOrderID[key]
    if isVisible(btn) and btn.orderID and SameOrderID(btn.orderID, orderID) then
        return btn
    end

    if key and self.rowButtonsByOrderID then
        self.rowButtonsByOrderID[key] = nil
    end

    for visibleBtn in pairs(self.visibleRowButtons or {}) do
        if isVisible(visibleBtn) and visibleBtn.orderID and SameOrderID(visibleBtn.orderID, orderID) then
            if key and self.rowButtonsByOrderID then
                self.rowButtonsByOrderID[key] = visibleBtn
            end
            return visibleBtn
        end
    end

    return nil
end
