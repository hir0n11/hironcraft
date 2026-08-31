local E = _G.HironCraftProfitCraftingOrdersEnv
if not E then
    E = {}
    _G.HironCraftProfitCraftingOrdersEnv = E
    setmetatable(E, { __index = _G })
end
setfenv(1, E)
if not PT or not CO then return end

function CO:GetRecipeKnownState(order)
    if not order or not order.spellID then return nil end

    if order.isRecipeKnown ~= nil then return order.isRecipeKnown == true end
    if order.recipeLearned ~= nil then return order.recipeLearned == true end
    if order.isKnown ~= nil then return order.isKnown == true end

    local recipeInfo = order.recipeInfo
    if not recipeInfo and C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
        local ok, info = pcall(C_TradeSkillUI.GetRecipeInfo, order.spellID)
        if ok then recipeInfo = info end
    end

    if recipeInfo then
        if recipeInfo.learned ~= nil then return recipeInfo.learned == true end
        if recipeInfo.isLearned ~= nil then return recipeInfo.isLearned == true end
        if recipeInfo.known ~= nil then return recipeInfo.known == true end
        if recipeInfo.isKnown ~= nil then return recipeInfo.isKnown == true end
        if recipeInfo.disabledReason and recipeInfo.disabledReason ~= "" then return false end
        return true
    end

    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic then
        local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, order.spellID, order.isRecraft)
        if ok and schematic then return true end
    end

    return nil
end

function CO:IsRecipeKnown(order)
    local known = self:GetRecipeKnownState(order)
    return known ~= false
end

function CO:IsCraftingOrderInteractionType(interactionType)
    local PIT = Enum and Enum.PlayerInteractionType
    if PIT then
        if interactionType == PIT.ProfessionsCraftingOrder
        or interactionType == PIT.ProfessionsCustomerOrder
        or interactionType == PIT.Professions then
            return true
        end
    end


    return interactionType == 58 or interactionType == 59 or interactionType == 60
end

function CO:SetOrderTablePresence(value, pageFrame)
    self.atOrderTable = value == true
    self.orderTableUnavailable = value ~= true
    self.lastOrderTablePresenceUpdate = GetTime and GetTime() or time()

    pageFrame = pageFrame or self.activePageFrame or self:FindOrderPageFrame()
    if pageFrame then
        pageFrame.ahuiViewingCachedOrders = false
        self.activePageFrame = pageFrame
        self:EnsurePageBindingHooks(pageFrame)
        self:EnsureControlPanel(pageFrame)
        self:UpdateControlPanelVisibility(pageFrame)
    end

    self.viewingCachedOrders = false
    wipe(self.orderIssues)
    self:RefreshVisibleRowsSoon(0.05)

    if value == true then
        self:WarmVisibleOrderQualitySoon(pageFrame, QUALITY_WARM_START_DELAY)
        if C_Timer then
            for _, delay in ipairs({ 0.1, 0.3, 0.6, 1.0 }) do
                C_Timer.After(delay, function()
                    local pf = pageFrame or self.activePageFrame or self:FindOrderPageFrame()
                    if pf then
                        self:EnsureControlPanel(pf)
                        self:UpdateControlPanelVisibility(pf)
                    end
                end)
            end
        end
    end
end

function CO:IsAtUsableCraftingOrderTable(pageFrame)
    pageFrame = pageFrame or self:FindOrderPageFrame() or self.activePageFrame
    if not self:IsCraftingOrdersPageOpen(pageFrame) then
        return false
    end

    if self.viewingCachedOrders or (pageFrame and pageFrame.ahuiViewingCachedOrders) then
        return false
    end

    if self.atOrderTable == true then
        return true
    end

    local profession = GetProfessionFromPage(pageFrame)


    if C_CraftingOrders then
        local apiNames = {
            "IsAtCraftingOrderNPC",
            "IsAtCraftingOrderNpc",
            "IsAtCraftingOrderTable",
            "IsNearCraftingOrderTable",
        }
        for _, apiName in ipairs(apiNames) do
            local fn = C_CraftingOrders[apiName]
            if type(fn) == "function" then
                local ok, value = pcall(fn, profession)
                if ok and value == true then
                    self.atOrderTable = true
                    self.orderTableUnavailable = false
                    return true
                end
                ok, value = pcall(fn)
                if ok and value == true then
                    self.atOrderTable = true
                    self.orderTableUnavailable = false
                    return true
                end
            end
        end
    end

    if C_TradeSkillUI and type(C_TradeSkillUI.IsNearProfessionSpellFocus) == "function" and profession then
        local ok, value = pcall(C_TradeSkillUI.IsNearProfessionSpellFocus, profession)
        if ok and value == true then
            self.atOrderTable = true
            self.orderTableUnavailable = false
            return true
        end
    end


    if pageFrame and pageFrame:IsShown() and not pageFrame.ahuiViewingCachedOrders then
        return true
    end

    return false
end

IsCustomerProvidedReagent = nil
IsCrafterProvidedReagent = nil

function CO:IsOrderSelected(orderID)
    local key = OrderKey(orderID)
    return key and self.selectedOrders and self.selectedOrders[key] == true
end

function CO:SetOrderSelected(orderID, selected)
    local key = OrderKey(orderID)
    if not key then return end

    if selected then
        self.selectedOrders[key] = true
        self.currentQueueOrderID = self.currentQueueOrderID or orderID
    else
        self.selectedOrders[key] = nil
        if self.currentQueueOrderID and SameOrderID(self.currentQueueOrderID, orderID) then
            self.currentQueueOrderID = nil
        end
    end

    self:RefreshVisibleRowsSoon()
    self:UpdateControlPanel()
end

function CO:ClearSelectedOrders()
    wipe(self.selectedOrders)
    self.currentQueueOrderID = nil
    self:RefreshVisibleRowsSoon()
    self:UpdateControlPanel()
end

function CO:HasSelectedOrders()
    for _ in pairs(self.selectedOrders or {}) do
        return true
    end
    return false
end

function CO:SelectAllVisibleOrders(pageFrame)
    pageFrame = pageFrame or self.activePageFrame or (_G.ProfessionsFrame and ProfessionsFrame.OrdersPage)
    local currentType = pageFrame and pageFrame.orderType

    local orders
    if C_CraftingOrders and C_CraftingOrders.GetCrafterOrders then
        local ok, list = pcall(C_CraftingOrders.GetCrafterOrders)
        if ok and type(list) == "table" then orders = list end
    end
    if type(orders) ~= "table" then return end

    self.selectedOrders = self.selectedOrders or {}
    local added = false
    for _, o in ipairs(orders) do
        if type(o) == "table" and o.orderID then
            local typeOk = (currentType == nil) or (o.orderType == nil) or (o.orderType == currentType)
            local fulfilled = self.fulfilledOrderIDs and self.fulfilledOrderIDs[o.orderID]
            if typeOk and not fulfilled then
                local key = OrderKey(o.orderID)
                if key then
                    self.selectedOrders[key] = true
                    self.currentQueueOrderID = self.currentQueueOrderID or o.orderID
                    added = true
                end
            end
        end
    end

    if added then
        self:RefreshVisibleRowsSoon()
        self:UpdateControlPanel()
    end
end

function IsResultOk(result)
    if Enum and Enum.CraftingOrderResult and Enum.CraftingOrderResult.Ok ~= nil then
        return result == Enum.CraftingOrderResult.Ok
    end
    return result == 0
end

function SetCachedOrderStateClaimed(order)
    if not order then return end
    if Enum and Enum.CraftingOrderState and Enum.CraftingOrderState.Claimed then
        order.orderState = Enum.CraftingOrderState.Claimed
    end
    if not order.claimEndTime and order.expirationTime then
        order.claimEndTime = order.expirationTime
    end
end

function SafeCall(label, fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, err = pcall(fn, ...)
    if not ok then
        print("|cffff5555HironCraft:|r " .. (label or "Crafting orders") .. ": " .. tostring(err))
        return false
    end
    return true
end

function GetProfessionFromPage(pageFrame)
    if pageFrame and pageFrame.professionInfo and pageFrame.professionInfo.profession then
        return pageFrame.professionInfo.profession
    end

    local childInfo = C_TradeSkillUI.GetChildProfessionInfo and C_TradeSkillUI.GetChildProfessionInfo()
    if childInfo and childInfo.profession then
        return childInfo.profession
    end

    local profInfo = Professions and Professions.GetProfessionInfo and Professions.GetProfessionInfo()
    if profInfo and profInfo.profession then
        return profInfo.profession
    end

    return nil
end

function GetRemainingTimeText(order)
    if not order then return "" end

    local endTime
    if IsOrderClaimed(order) and order.claimEndTime then
        endTime = order.claimEndTime
    elseif order.expirationTime then
        endTime = order.expirationTime
    end
    if not endTime then return "" end

    local seconds
    if Professions and Professions.GetCraftingOrderRemainingTime then
        seconds = Professions.GetCraftingOrderRemainingTime(endTime)
    else
        seconds = math.max(0, endTime - GetServerTime())
    end

    if not seconds or seconds < 0 then seconds = 0 end

    if Professions and Professions.OrderTimeLeftFormatter then
        return Professions.OrderTimeLeftFormatter:Format(seconds)
    end

    if SecondsToTimeAbbrev then
        return SecondsToTimeAbbrev(seconds)
    end

    return tostring(math.ceil(seconds / 60)) .. "m"
end


function GetMoneyTextureString()
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("Coin-Gold") then
        return CreateAtlasMarkup("Coin-Gold", 12, 12)
    end
    return "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t"
end

function FormatCopperShort(value)
    value = tonumber(value) or 0
    if value <= 0 then return "" end
    local gold = math.floor(value / 10000)
    if gold >= 1000 then
        return string.format("%.1fk", gold / 1000)
    end
    if gold > 0 then
        return tostring(gold)
    end
    local silver = math.floor((value % 10000) / 100)
    if silver > 0 then
        return tostring(silver) .. "s"
    end
    return tostring(value % 100) .. "c"
end

function Clamp01(v)
    v = tonumber(v) or 0
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

function SafeNum(v)
    return tonumber(v) or 0
end

function GetQualityText(quality, maxQuality)
    quality = tonumber(quality) or 0
    maxQuality = tonumber(maxQuality) or 0
    if quality <= 0 then return "?" end
    if maxQuality > 0 then
        return tostring(quality) .. "/" .. tostring(maxQuality)
    end
    return tostring(quality)
end

function SetConcentrationIconTexture(texture)
    if not texture then return end

    texture:SetTexture(CONCENTRATION_TEXTURE)
    texture:SetTexCoord(0, 1, 0, 1)
end

function SetFrameBackdropColors(frame, bgR, bgG, bgB, bgA, borderR, borderG, borderB, borderA)
    if not frame then return end
    if frame.SetBackdropColor then frame:SetBackdropColor(bgR, bgG, bgB, bgA) end
    if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(borderR, borderG, borderB, borderA) end
end
