local E = _G.HironCraftProfitCraftingOrdersEnv
if not E then
    E = {}
    _G.HironCraftProfitCraftingOrdersEnv = E
    setmetatable(E, { __index = _G })
end
setfenv(1, E)
if not PT or not CO then return end

function CO:IsOrderCraftableForSelection(btn)
    if not btn or not btn.orderID then return false end

    local order = btn.order or self:GetEffectiveOrder(btn.orderID, btn.order)
    if not order or not order.spellID then return false end
    if self:GetRecipeKnownState(order) == false then return false end
    if self.viewingCachedOrders then return false end

    local issueKey = OrderKey(btn.orderID)
    if issueKey and self.orderIssues and self.orderIssues[issueKey] then return false end

    local claimed = self:GetClaimedOrder()
    if claimed and not SameOrderID(claimed.orderID, btn.orderID) then return false end


    if not self:CanSupplyCrafterReagentsForQueue(order, false) then
        return false
    end

    local q = self:GetOrderQualityInfo(order, false, false)
    local minQuality = tonumber(order.minQuality) or 0
    if minQuality > 0 then
        if not q or not tonumber(q.quality) or q.quality <= 0 or q.quality < minQuality then
            return false
        end
    end


    local concCost = self:GetConcentrationCostToNextQuality(order, q, false)
    if concCost and concCost > 0 and minQuality > 0 and (not q or q.quality < minQuality) then
        return false
    end

    return true
end

function CO:GetQueueOptions()
    local db = GetDB()
    db.queue = db.queue or {}
    local q = db.queue


    if q.includeNpc == nil then q.includeNpc = true end
    if q.includePersonal == nil then q.includePersonal = true end
    if q.includeGuild == nil then q.includeGuild = false end
    if q.includePublic == nil then q.includePublic = false end
    if q.allowConcentration == nil then q.allowConcentration = false end
    if q.forceConcentration == nil then q.forceConcentration = false end
    if q.onlyProfitable == nil then q.onlyProfitable = false end
    if q.publicMaxCount == nil then q.publicMaxCount = 0 end
    if q.reagentMode ~= "t1" and q.reagentMode ~= "t2" and q.reagentMode ~= "profit" and q.reagentMode ~= "manual" then q.reagentMode = "auto" end
    q.minProfitCopper = tonumber(q.minProfitCopper)
    if q.autoQueueOnOpen == nil then q.autoQueueOnOpen = false end
    if q.autoShoppingOnOpen == nil then q.autoShoppingOnOpen = false end
    if q.autoTool == nil then q.autoTool = false end
    if q.autoFinishingEnabled == nil then q.autoFinishingEnabled = false end
    q.autoFinishingMaxSkill = tonumber(q.autoFinishingMaxSkill) or 5

    return q
end

function CO:IsAutoFinishingEnabled()
    return self:GetQueueOptions().autoFinishingEnabled == true
end

function CO:SetAutoFinishingEnabled(value)
    self:GetQueueOptions().autoFinishingEnabled = value == true
    if self.UpdateControlPanel then self:UpdateControlPanel() end
end

function CO:GetAutoFinishingMaxSkillBonus()
    return math.max(0, tonumber(self:GetQueueOptions().autoFinishingMaxSkill) or 5)
end

function CO:SetAutoFinishingMaxSkillBonus(value)
    value = math.max(0, math.floor((tonumber(value) or 5) + 0.5))
    self:GetQueueOptions().autoFinishingMaxSkill = value
    if self.UpdateControlPanel then self:UpdateControlPanel() end
end

function CO:GetAutoFinishingLabel()
    if not self:IsAutoFinishingEnabled() then
        return T("COA_FINISHER_OFF", "Выкл")
    end
    return string.format(
        T("COA_FINISHER_LIMIT_FMT", "до +%d"),
        self:GetAutoFinishingMaxSkillBonus()
    )
end

function CO:IsAutoToolOn()
    return self:GetQueueOptions().autoTool == true
end

function CO:SetAutoToolOn(value)
    self:GetQueueOptions().autoTool = (value == true)
end

function CO:IsAutoQueueOnOpen()
    return self:GetQueueOptions().autoQueueOnOpen == true
end

function CO:SetAutoQueueOnOpen(value)
    self:GetQueueOptions().autoQueueOnOpen = (value == true)

    if value == true and self.atOrderTable and self.BeginOneButtonPersonalFlow then
        self._oneButtonPreparedForOpen = false
        self:BeginOneButtonPersonalFlow()
    elseif value ~= true and self.CancelOneButtonPersonalFlow then
        self:CancelOneButtonPersonalFlow()
    end

    -- Rebuild temporary overrides immediately: disabling Queue must restore
    -- Interact With Target even if the profession window remains open.
    if self.HasVisibleOrderContext and self:HasVisibleOrderContext() and self.ApplyTemporaryBinding then
        self:ApplyTemporaryBinding()
    end
end

function CO:IsAutoShoppingOnOpen()
    return self:GetQueueOptions().autoShoppingOnOpen == true
end

function CO:SetAutoShoppingOnOpen(value)
    self:GetQueueOptions().autoShoppingOnOpen = (value == true)
end

function CO:GetQueueMinProfitCopper()
    if not self:IsNpcTab() then return nil end
    return tonumber(self:GetQueueOptions().minProfitCopper)
end

function CO:GetQueueMinProfitText()
    local value = self:GetQueueMinProfitCopper()
    if not value then
        return T("COA_QUEUE_PROFIT_FILTER_OFF", "Off")
    end
    return FormatProfitCopper(value)
end

function CO:ParseQueueMinProfitInput(text)
    text = tostring(text or ""):gsub("%s+", ""):gsub("[gGРгГ]", ""):gsub(",", ".")
    if text == "" then return nil, true end

    local value = tonumber(text)
    if not value then return nil, false end

    local copper = value * 10000
    if copper >= 0 then
        return math.floor(copper + 0.5), true
    end
    return math.ceil(copper - 0.5), true
end

function CO:SetQueueMinProfitCopper(value)
    local opts = self:GetQueueOptions()
    value = tonumber(value)
    if value then
        opts.minProfitCopper = value
        self:SetStatus(string.format(T("COA_STATUS_QUEUE_PROFIT_FILTER", "Queue profit filter: %s."), self:GetQueueMinProfitText()))
    else
        opts.minProfitCopper = nil
        self:SetStatus(T("COA_STATUS_QUEUE_PROFIT_FILTER_OFF", "Queue profit filter disabled."))
    end
    if self.UpdateControlPanel then self:UpdateControlPanel() end
end

function CO:OpenQueueMinProfitPopup()
    if not StaticPopupDialogs or not StaticPopup_Show then return end

    local dialogKey = "HIRONCRAFT_PROFIT_CO_QUEUE_MIN_PROFIT"
    StaticPopupDialogs[dialogKey] = StaticPopupDialogs[dialogKey] or {
        text = T("COA_QUEUE_PROFIT_FILTER_POPUP", "Minimum queue profit in gold. Negative values are allowed. Empty value disables the filter."),
        button1 = ACCEPT,
        button2 = CANCEL,
        hasEditBox = true,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnShow = function(self)
            local box = self.EditBox or self.editBox or _G[(self:GetName() or "") .. "EditBox"]
            if not box then return end

            local copper = CO:GetQueueMinProfitCopper()
            if copper then
                box:SetText(tostring(copper / 10000))
            else
                box:SetText("")
            end
            box:SetFocus()
            box:HighlightText()
        end,
        OnAccept = function(self)
            local box = self.EditBox or self.editBox or _G[(self:GetName() or "") .. "EditBox"]
            local copper, ok = CO:ParseQueueMinProfitInput(box and box:GetText() or "")
            if not ok then
                CO:SetStatus(T("COA_STATUS_QUEUE_PROFIT_FILTER_INVALID", "Queue profit filter: enter a number."))
                return
            end
            CO:SetQueueMinProfitCopper(copper)
        end,
        EditBoxOnEnterPressed = function(self)
            local parent = self:GetParent()
            if parent and StaticPopup_OnClick then
                StaticPopup_OnClick(parent, 1)
            end
        end,
        EditBoxOnEscapePressed = function(self)
            local parent = self:GetParent()
            if parent then parent:Hide() end
        end,
    }

    StaticPopup_Show(dialogKey)
end

function CO:OpenCopperInputPopup(dialogKey, promptText, getCopper, setCopper)
    if not StaticPopupDialogs or not StaticPopup_Show then return end

    StaticPopupDialogs[dialogKey] = StaticPopupDialogs[dialogKey] or {
        text = promptText,
        button1 = ACCEPT,
        button2 = CANCEL,
        hasEditBox = true,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnShow = function(self)
            local box = self.EditBox or self.editBox or _G[(self:GetName() or "") .. "EditBox"]
            if not box then return end
            local copper = getCopper()
            box:SetText(copper and tostring(copper / 10000) or "")
            box:SetFocus()
            box:HighlightText()
        end,
        OnAccept = function(self)
            local box = self.EditBox or self.editBox or _G[(self:GetName() or "") .. "EditBox"]
            local copper, ok = CO:ParseQueueMinProfitInput(box and box:GetText() or "")
            if not ok then return end
            setCopper(copper)
        end,
        EditBoxOnEnterPressed = function(self)
            local parent = self:GetParent()
            if parent and StaticPopup_OnClick then
                StaticPopup_OnClick(parent, 1)
            end
        end,
        EditBoxOnEscapePressed = function(self)
            local parent = self:GetParent()
            if parent then parent:Hide() end
        end,
    }

    StaticPopup_Show(dialogKey)
end

function CO:GetBagRewardValueCopper()
    if not self:IsNpcTab() then return nil end
    return tonumber(self:GetQueueOptions().bagRewardCopper)
end

function CO:GetBagRewardValueText()
    local v = self:GetBagRewardValueCopper()
    if not v then return T("COA_QUEUE_MINPROFIT_OFF", "выкл") end
    return FormatProfitCopper(v)
end

function CO:SetBagRewardValueCopper(value)
    local opts = self:GetQueueOptions()
    value = tonumber(value)
    opts.bagRewardCopper = (value and value > 0) and value or nil
    if self.UpdateControlPanel then self:UpdateControlPanel() end
    if self.RefreshVisibleRows then self:RefreshVisibleRows() end
end

function CO:OpenBagRewardValuePopup()
    self:OpenCopperInputPopup("HIRONCRAFT_PROFIT_CO_BAG_VALUE",
        T("COA_BAGVALUE_POPUP", "Стоимость сумки-награды в золоте (для расчёта профита). Пусто — не учитывать."),
        function() return CO:GetBagRewardValueCopper() end,
        function(c) CO:SetBagRewardValueCopper(c) end)
end

function CO:GetKnowledgePointValueCopper()
    if not self:IsNpcTab() then return nil end
    return tonumber(self:GetQueueOptions().knowledgePointCopper)
end

function CO:GetKnowledgePointValueText()
    local v = self:GetKnowledgePointValueCopper()
    if not v then return T("COA_QUEUE_MINPROFIT_OFF", "выкл") end
    return FormatProfitCopper(v)
end

function CO:SetKnowledgePointValueCopper(value)
    local opts = self:GetQueueOptions()
    value = tonumber(value)
    opts.knowledgePointCopper = (value and value > 0) and value or nil
    if self.UpdateControlPanel then self:UpdateControlPanel() end
    if self.RefreshVisibleRows then self:RefreshVisibleRows() end
end

function CO:OpenKnowledgePointValuePopup()
    self:OpenCopperInputPopup("HIRONCRAFT_PROFIT_CO_KP_VALUE",
        T("COA_KPVALUE_POPUP", "Стоимость одного очка знания в золоте (для расчёта профита). Пусто — не учитывать."),
        function() return CO:GetKnowledgePointValueCopper() end,
        function(c) CO:SetKnowledgePointValueCopper(c) end)
end

function CO:IsNpcTab(pageFrame)
    pageFrame = pageFrame or self.activePageFrame
    if not pageFrame then return false end
    if not (Enum and Enum.CraftingOrderType and Enum.CraftingOrderType.Npc) then return false end
    return pageFrame.orderType == Enum.CraftingOrderType.Npc
end

function CO:GetQueueReagentMode()
    local opts = self:GetQueueOptions()
    if self:IsNpcTab() then
        return opts.reagentMode or "auto"
    end
    return opts.reagentModeOther or "t1"
end

function CO:GetQueueReagentModeLabel(mode)
    mode = mode or self:GetQueueReagentMode()
    if mode == "t1" then
        return T("COA_QUEUE_REAGENT_MODE_T1", "T1")
    elseif mode == "t2" then
        return T("COA_QUEUE_REAGENT_MODE_T2", "T2")
    elseif mode == "profit" then
        return T("COA_QUEUE_REAGENT_MODE_PROFIT", "Профит")
    elseif mode == "manual" then
        return T("COA_QUEUE_REAGENT_MODE_MANUAL", "Ручной")
    end
    return T("COA_QUEUE_REAGENT_MODE_AUTO", "Эконом")
end

function CO:SetQueueReagentMode(mode)
    local opts = self:GetQueueOptions()
    if self:IsNpcTab() then
        if mode ~= "t1" and mode ~= "t2" and mode ~= "profit" and mode ~= "manual" then mode = "auto" end
        opts.reagentMode = mode
    else
        if mode ~= "t2" and mode ~= "manual" then mode = "t1" end
        opts.reagentModeOther = mode
    end
    self.queueReagentPriceCache = {}
    self:SetStatus(string.format(T("COA_STATUS_QUEUE_REAGENT_MODE", "Queue reagent mode: %s."), self:GetQueueReagentModeLabel(mode)))
    if self.CustomList and self.CustomList.Refresh and self.activePageFrame then
        self.CustomList:Refresh(self.activePageFrame)
    end
end

function CO:GetQueueConcMode()
    local q = self:GetQueueOptions()
    if q.forceConcentration then return "force" end
    if q.allowConcentration then return "allow" end
    return "off"
end

function CO:SetQueueConcMode(value)
    local q = self:GetQueueOptions()
    q.allowConcentration = (value == "allow" or value == "force")
    q.forceConcentration = (value == "force")
end

function CO:GetQueueOrderTypeIncluded(kind)
    local q = self:GetQueueOptions()
    if kind == "npc" then return q.includeNpc == true end
    if kind == "personal" then return q.includePersonal == true end
    if kind == "guild" then return q.includeGuild == true end
    if kind == "public" then return q.includePublic == true end
    return false
end

function CO:SetQueueOrderTypeIncluded(kind, value)
    local q = self:GetQueueOptions()
    value = value == true
    if kind == "npc" then q.includeNpc = value
    elseif kind == "personal" then q.includePersonal = value
    elseif kind == "guild" then q.includeGuild = value
    elseif kind == "public" then q.includePublic = value end
end


function CO:OpenQueueReagentModeMenu(owner)
    if not owner then return end

    local current = self:GetQueueReagentMode()
    local options
    if self:IsNpcTab() then
        options = {
            { mode = "auto", label = self:GetQueueReagentModeLabel("auto") },
            { mode = "t1", label = self:GetQueueReagentModeLabel("t1") },
            { mode = "t2", label = self:GetQueueReagentModeLabel("t2") },
            { mode = "profit", label = self:GetQueueReagentModeLabel("profit") },
            { mode = "manual", label = self:GetQueueReagentModeLabel("manual") },
        }
    else
        options = {
            { mode = "t1", label = self:GetQueueReagentModeLabel("t1") },
            { mode = "t2", label = self:GetQueueReagentModeLabel("t2") },
            { mode = "manual", label = self:GetQueueReagentModeLabel("manual") },
        }
    end

    local items = {}
    for _, option in ipairs(options) do
        local optionCopy = option
        items[#items + 1] = {
            text = optionCopy.label,
            checked = current == optionCopy.mode,
            onClick = function()
                CO:SetQueueReagentMode(optionCopy.mode)
            end,
        }
    end

    if self:IsNpcTab() then
        items[#items + 1] = {
            text = T("COA_QUEUE_PROFIT_FILTER_HEADER", "Profit filter"),
            header = true,
        }
        items[#items + 1] = {
            text = string.format(T("COA_QUEUE_PROFIT_FILTER_CURRENT_FMT", "Minimum profit: %s"), self:GetQueueMinProfitText()),
            onClick = function()
                CO:OpenQueueMinProfitPopup()
            end,
        }
        items[#items + 1] = {
            text = T("COA_QUEUE_PROFIT_FILTER_CLEAR", "Disable profit filter"),
            onClick = function()
                CO:SetQueueMinProfitCopper(nil)
            end,
        }
    end

    if self:IsNpcTab() then
        items[#items + 1] = {
            text = T("COA_QUEUE_AUTO_ON_OPEN_HEADER", "Auto queue"),
            header = true,
        }
        items[#items + 1] = {
            text = T("COA_QUEUE_AUTO_ON_OPEN", "Авто-очередь при открытии"),
            checked = CO:IsAutoQueueOnOpen(),
            onClick = function()
                CO:SetAutoQueueOnOpen(not CO:IsAutoQueueOnOpen())
                CO:SetStatus(CO:IsAutoQueueOnOpen()
                    and T("COA_STATUS_AUTOQUEUE_ON", "Авто-очередь включена.")
                    or T("COA_STATUS_AUTOQUEUE_OFF", "Авто-очередь выключена."))
            end,
        }
        items[#items + 1] = {
            text = T("COA_QUEUE_AUTO_SHOPPING", "Авто-закуп после авто-очереди"),
            checked = CO:IsAutoShoppingOnOpen(),
            onClick = function()
                CO:SetAutoShoppingOnOpen(not CO:IsAutoShoppingOnOpen())
                CO:SetStatus(CO:IsAutoShoppingOnOpen()
                    and T("COA_STATUS_AUTOSHOP_ON", "Авто-закуп включён.")
                    or T("COA_STATUS_AUTOSHOP_OFF", "Авто-закуп выключен."))
            end,
        }
    end

    if PT.Dropdown and PT.Dropdown.Show then
        PT.Dropdown:Show({ owner = owner, items = items })
        return
    end

    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
            rootDescription:SetTag("HIRONCRAFT_PROFIT_CRAFTING_ORDER_QUEUE_REAGENTS")
            for _, item in ipairs(items) do
                rootDescription:CreateButton(item.text, item.onClick)
            end
        end)
    end
end

function CO:GetQueueOrderTypes()
    local types = {}
    if not Enum or not Enum.CraftingOrderType then return types end

    local q = self:GetQueueOptions()
    if q.includeNpc and Enum.CraftingOrderType.Npc then
        types[#types + 1] = Enum.CraftingOrderType.Npc
    end
    if q.includeGuild and Enum.CraftingOrderType.Guild then
        types[#types + 1] = Enum.CraftingOrderType.Guild
    end
    if q.includePersonal and Enum.CraftingOrderType.Personal then
        types[#types + 1] = Enum.CraftingOrderType.Personal
    end
    if q.includePublic and Enum.CraftingOrderType.Public then
        types[#types + 1] = Enum.CraftingOrderType.Public
    end

    return types
end

function CO:GetQueueConcentrationAmount()
    if C_TradeSkillUI and C_TradeSkillUI.GetConcentrationCurrencyID and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local ok, currencyID = pcall(C_TradeSkillUI.GetConcentrationCurrencyID)
        if ok and currencyID then
            local infoOk, info = pcall(C_CurrencyInfo.GetCurrencyInfo, currencyID)
            if infoOk and info and tonumber(info.quantity) then
                return tonumber(info.quantity)
            end
        end
    end

    return 0
end


function CO:GetVisibleOrderButtonsSorted()
    local buttons = {}
    for btn in pairs(self.visibleRowButtons or {}) do
        if btn and btn:IsShown() and btn.orderID and btn.order then
            buttons[#buttons + 1] = btn
        end
    end

    table.sort(buttons, function(a, b)
        return (a:GetTop() or 0) > (b:GetTop() or 0)
    end)

    return buttons
end

local function ShouldWarmOrderQualityForVisibleRow(self, order)
    local key = OrderKey(order and order.orderID)
    if not key then return false end

    local now = CacheNow()
    self.qualityWarmAttempts = self.qualityWarmAttempts or {}

    for attemptKey, expiresAt in pairs(self.qualityWarmAttempts) do
        if not expiresAt or expiresAt <= now then
            self.qualityWarmAttempts[attemptKey] = nil
        end
    end

    local attemptKey = key .. ":" .. tostring(GetOrderRevision(self, order.orderID))
    if self.qualityWarmAttempts[attemptKey] and self.qualityWarmAttempts[attemptKey] > now then
        return false
    end

    self.qualityWarmAttempts[attemptKey] = now + (QUALITY_WARM_ATTEMPT_TTL or 6.0)
    return true
end

function CO:WarmOrderQualityForList(order, pageFrame, opts)
    if not self:IsEnabled() or self.queueSelectionRunning or not order or not order.orderID then return false end
    pageFrame = pageFrame or self.activePageFrame or self:FindOrderPageFrame()
    if not pageFrame or not self:IsSafeToPrepareOrderViewForAnalysis(pageFrame) then return false end

    opts = opts or {}

    self:PrepareOrderForQueueAnalysis(order, pageFrame)

    local q = self:GetOrderQualityInfo(order, false, true)
    local qConc
    if opts.includeConcentration ~= false then
        qConc = self:GetOrderQualityInfo(order, true, true)
    end


    if q and qConc and (not q.concentrationCost or q.concentrationCost <= 0) and qConc.concentrationCost and qConc.concentrationCost > 0 then
        q.concentrationCost = qConc.concentrationCost
        local key = OrderKey(order.orderID)
        if key then
            local revision = GetOrderRevision(self, order.orderID)
            local cacheKey = key .. ":0:" .. tostring(revision) .. ":f"
            if self.qualityCache and self.qualityCache[cacheKey] then
                self.qualityCache[cacheKey].value = q
            end
            cacheKey = key .. ":0:" .. tostring(revision) .. ":p"
            if self.qualityCache and self.qualityCache[cacheKey] then
                self.qualityCache[cacheKey].value = q
            end
        end
    end

    return q ~= nil or qConc ~= nil
end

function CO:WarmVisibleOrderQualitySoon(pageFrame, delay)
    self.qualityWarmSerial = (tonumber(self.qualityWarmSerial) or 0) + 1
    local serial = self.qualityWarmSerial

    local function run()
        CO:WarmVisibleOrderQuality(pageFrame, serial, 1)
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(delay or QUALITY_WARM_START_DELAY, run)
    else
        run()
    end
    return true
end

function CO:WarmVisibleOrderQuality(pageFrame, serial, startIndex)
    if serial and serial ~= self.qualityWarmSerial then return false end
    if not self:IsEnabled() or self.queueSelectionRunning then return false end

    pageFrame = self:FindOrderPageFrame(pageFrame) or self:FindOrderPageFrame(self.activePageFrame)
    if not pageFrame or (pageFrame.IsShown and not pageFrame:IsShown()) then return false end
    if not self:IsSafeToPrepareOrderViewForAnalysis(pageFrame) then return false end

    local buttons = self:GetVisibleOrderButtonsSorted()
    local index = tonumber(startIndex) or 1

    while index <= #buttons do
        local btn = buttons[index]
        local order = btn and btn.order
        local row = btn and btn.GetParent and btn:GetParent()

        if order and order.orderID and self:GetOrderRequestedQuality(order) > 0 then
            local _, hasRequirement = self:GetCachedConcentrationRequirement(order)
            local qInfo = self:GetCachedOrderQualityInfo(order, false)
            if hasRequirement or qInfo then
                if row then self:UpdateConcentrationRequiredBorder(row, order) end
            elseif ShouldWarmOrderQualityForVisibleRow(self, order) then
                self:WarmOrderQualityForList(order, pageFrame, { includeConcentration = false })
                if row then self:UpdateConcentrationRequiredBorder(row, order) end

                index = index + 1
                if index <= #buttons then
                    local nextDelay = QUALITY_WARM_STEP_DELAY or 0.02
                    if nextDelay < 0.01 then nextDelay = 0.01 end
                    if C_Timer and C_Timer.After then
                        C_Timer.After(nextDelay, function()
                            CO:WarmVisibleOrderQuality(pageFrame, serial, index)
                        end)
                    else
                        self:WarmVisibleOrderQuality(pageFrame, serial, index)
                    end
                end
                return true
            end
        end

        index = index + 1
    end

    return true
end

function CO:PrepareOrderForQueueAnalysis(order, pageFrame)
    if not order or not order.orderID then return false end

    -- Do not let background quality warming rebuild the live transaction after
    -- the first click has staged a finishing reagent for this order.
    if self.preparedFinisherOrderID
        and SameOrderID(self.preparedFinisherOrderID, order.orderID)
    then
        return true
    end

    pageFrame = self:FindOrderPageFrame(pageFrame) or self:FindOrderPageFrame(self.activePageFrame)
    if not pageFrame or not self:CanPrepareOrderView(pageFrame) then return false end

    self.queuePreparedOrders = self.queuePreparedOrders or {}
    local key = OrderKey(order.orderID)
    local prepKey = key and (key .. ":" .. tostring(order.spellID or "") .. ":" .. tostring(order.isRecraft == true))
    if prepKey and self.queuePreparedOrders[prepKey] then
        return true
    end


    self:InvalidateOrderCaches(order.orderID)

    local browse = pageFrame.BrowseFrame
    local orderView = pageFrame.OrderView
    local browseWasShown = browse and browse.IsShown and browse:IsShown()
    local orderViewWasShown = orderView and orderView.IsShown and orderView:IsShown()
    local orderOpenFlag = pageFrame.ahuiCraftingOrdersOrderOpen

    local engine
    if orderView and orderView.SetOrder then
        engine = self:GetOrderEngine(pageFrame, order)
    end

    if engine then
        self:ApplySelectedReagentsToEngine(engine, order)
        self:SetEngineConcentration(engine, false)
    end


    if browse and browse.Show and browseWasShown ~= false then
        browse:Show()
    end
    if engine and engine.Hide and not orderViewWasShown then
        engine:Hide()
    end
    pageFrame.ahuiCraftingOrdersOrderOpen = orderOpenFlag
    self:UpdateControlPanelVisibility(pageFrame)

    local prepared = engine and engine.SetOrder ~= nil
    if prepared and prepKey then
        self.queuePreparedOrders[prepKey] = true
    end
    return prepared == true
end

function CO:FindAvailableCrafterReagent(order, reagentEntry)
    if not order or not reagentEntry then return nil end
    if IsCustomerProvidedReagent(reagentEntry) or not IsCrafterProvidedReagent(reagentEntry) then
        return { provided = true }
    end

    local quantity = tonumber(reagentEntry.quantity) or 0
    if quantity <= 0 then return { provided = true } end

    local slotIndex = reagentEntry.slotIndex or reagentEntry.dataSlotIndex
    local selected = self:GetSelectedReagentForEntry(order.orderID, reagentEntry)
    if selected and selected.itemID and self:GetItemCountForShopping(selected.itemID) >= quantity then
        return selected
    end

    if reagentEntry.itemID and self:GetItemCountForShopping(reagentEntry.itemID) >= quantity then
        return {
            itemID = reagentEntry.itemID,
            qualityTier = reagentEntry.qualityTier,
            maxQualityTier = reagentEntry.maxQualityTier,
            expansionID = reagentEntry.expansionID,
            qualityKind = reagentEntry.qualityKind,
            slotIndex = slotIndex,
            dataSlotIndex = reagentEntry.dataSlotIndex,
        }
    end

    local best
    for _, candidate in ipairs(self:GetReagentCandidates(order, reagentEntry)) do
        if candidate and candidate.itemID and self:GetItemCountForShopping(candidate.itemID) >= quantity then
            if not best then
                best = candidate
            else
                local cp = tonumber(self:GetQueueReagentAuctionatorPrice(candidate.itemID)) or math.huge
                local bp = tonumber(self:GetQueueReagentAuctionatorPrice(best.itemID)) or math.huge
                if cp < bp or (cp == bp and (tonumber(candidate.qualityTier) or 0) < (tonumber(best.qualityTier) or 0)) then
                    best = candidate
                end
            end
        end
    end

    return best
end

function CO:GetQueueReagentAuctionatorPrice(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil end

    self.queueReagentPriceCache = self.queueReagentPriceCache or {}
    local cached = self.queueReagentPriceCache[itemID]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end

    local price = GetAuctionatorItemPrice and GetAuctionatorItemPrice(itemID, nil)
    price = tonumber(price)
    if price and price > 0 then
        self.queueReagentPriceCache[itemID] = price
        return price
    end

    self.queueReagentPriceCache[itemID] = false
    return nil
end

function CO:GetQueueReagentCandidateTier(candidate)
    if not candidate then return nil end
    return NormalizeQualityTier(candidate.qualityTier)
        or ReadProfessionQualityFromItem(candidate.itemID)
end

function CO:ChooseCheapestQueueReagentCandidate(candidates)
    local best
    local bestPrice

    for _, candidate in ipairs(candidates or {}) do
        if candidate and candidate.itemID then
            local price = self:GetQueueReagentAuctionatorPrice(candidate.itemID)
            if price and (not bestPrice or price < bestPrice) then
                best = candidate
                bestPrice = price
            end
        end
    end

    return best
end

function CO:BuildLockedReagentsForEngine(order)
    local locked = {}
    if not order or type(order.reagents) ~= "table" then return locked end
    for _, r in ipairs(order.reagents) do
        local reagentInfo = r.reagentInfo or r
        local reagent = reagentInfo and reagentInfo.reagent
        local slot = r.slotIndex or (reagentInfo and reagentInfo.dataSlotIndex)
        local itemID = reagent and reagent.itemID
        local qty = (reagentInfo and reagentInfo.quantity) or r.quantity or 1
        if slot and itemID then
            locked[slot] = { itemID = itemID, quantity = qty }
        end
    end
    return locked
end

function CO:ChooseQueueReagentCandidate(order, reagentEntry, mode)
    if not order or not reagentEntry then return nil end
    if IsCustomerProvidedReagent(reagentEntry) or not IsCrafterProvidedReagent(reagentEntry) then return nil end

    local candidates = self:GetReagentCandidates(order, reagentEntry)
    if mode == "t1" or mode == "t2" then
        local targetTier = mode == "t1" and 1 or 2
        local hasQualityChoices = false
        local tierCandidates = {}

        for _, candidate in ipairs(candidates) do
            local tier = self:GetQueueReagentCandidateTier(candidate)
            if tier then
                hasQualityChoices = true
                if tier == targetTier then
                    tierCandidates[#tierCandidates + 1] = candidate
                end
            end
        end

        if not hasQualityChoices then return nil end
        if #tierCandidates == 0 then return false end

        return self:ChooseCheapestQueueReagentCandidate(tierCandidates) or tierCandidates[1]
    end

    if mode == "profit" then
        local CE = HironCraft and HironCraft.CraftEngine
        local target = self:GetOrderRequestedQuality(order)
        if CE and order.spellID and target > 0 then
            local locked = self:BuildLockedReagentsForEngine(order)
            local plan = CE:NeedsConcentrationCached(order.spellID, target, order.orderID, "profit", locked)
            local ds = reagentEntry.dataSlotIndex or reagentEntry.slotIndex
            local wantTier = plan and plan.tierByDataSlot and ds and plan.tierByDataSlot[ds]
            if wantTier then
                local tierCandidates = {}
                for _, candidate in ipairs(candidates) do
                    if self:GetQueueReagentCandidateTier(candidate) == wantTier then
                        tierCandidates[#tierCandidates + 1] = candidate
                    end
                end
                if #tierCandidates > 0 then
                    return self:ChooseCheapestQueueReagentCandidate(tierCandidates) or tierCandidates[1]
                end
            end
        end
        return self:ChooseCheapestQueueReagentCandidate(candidates)
    end

    return self:ChooseCheapestQueueReagentCandidate(candidates)
end

function CO:ApplyQueueReagentModeToOrder(order)
    if not order or not order.orderID then return false end

    local mode = self:GetQueueReagentMode()
    if mode == "manual" then return true end

    local changed = false
    local ok = true

    for _, reagentEntry in ipairs(self:BuildDisplayReagents(order)) do
        if IsCrafterProvidedReagent(reagentEntry) and not IsCustomerProvidedReagent(reagentEntry) then
            local selectionSlotIndex = reagentEntry.dataSlotIndex or reagentEntry.slotIndex
            local selectionKey = MakeReagentSelectionKeyForEntry(order.orderID, reagentEntry)
            if selectionKey then
                local legacyKey = MakeReagentSelectionKey(order.orderID, selectionSlotIndex)
                local alternateKey
                if reagentEntry.slotIndex ~= nil and reagentEntry.slotIndex ~= selectionSlotIndex then
                    alternateKey = MakeReagentSelectionKey(order.orderID, reagentEntry.slotIndex)
                end
                local candidate = self:ChooseQueueReagentCandidate(order, reagentEntry, mode)
                if candidate == false then
                    ok = false
                    self.selectedReagents[selectionKey] = nil
                    if legacyKey and legacyKey ~= selectionKey then self.selectedReagents[legacyKey] = nil end
                    if alternateKey then self.selectedReagents[alternateKey] = nil end
                    changed = true
                elseif candidate and candidate.itemID then
                    local quantity = reagentEntry.quantity or candidate.quantity or 0
                    local dataSlotIndex = reagentEntry.dataSlotIndex or candidate.dataSlotIndex
                    local slotIndex = reagentEntry.slotIndex or candidate.slotIndex or dataSlotIndex
                    local qualityTier = self:GetQueueReagentCandidateTier(candidate)
                    local current = self.selectedReagents[selectionKey]
                    if not current
                       or current.itemID ~= candidate.itemID
                       or current.quantity ~= quantity
                       or current.slotIndex ~= slotIndex
                       or current.dataSlotIndex ~= dataSlotIndex
                       or current.qualityTier ~= qualityTier then
                        self.selectedReagents[selectionKey] = {
                            itemID = candidate.itemID,
                            quantity = quantity,
                            slotIndex = slotIndex,
                            dataSlotIndex = dataSlotIndex,
                            qualityTier = qualityTier,
                            maxQualityTier = candidate.maxQualityTier,
                            expansionID = candidate.expansionID,
                            qualityKind = candidate.qualityKind,
                        }
                        changed = true
                    end
                    if legacyKey and legacyKey ~= selectionKey and self.selectedReagents[legacyKey] ~= nil then
                        self.selectedReagents[legacyKey] = nil
                        changed = true
                    end
                    if alternateKey and self.selectedReagents[alternateKey] ~= nil then
                        self.selectedReagents[alternateKey] = nil
                        changed = true
                    end
                elseif self.selectedReagents[selectionKey] ~= nil then
                    self.selectedReagents[selectionKey] = nil
                    if legacyKey and legacyKey ~= selectionKey then self.selectedReagents[legacyKey] = nil end
                    if alternateKey then self.selectedReagents[alternateKey] = nil end
                    changed = true
                elseif legacyKey and legacyKey ~= selectionKey and self.selectedReagents[legacyKey] ~= nil then
                    self.selectedReagents[legacyKey] = nil
                    changed = true
                elseif alternateKey and self.selectedReagents[alternateKey] ~= nil then
                    self.selectedReagents[alternateKey] = nil
                    changed = true
                end
            end
        end
    end

    if changed then
        self:InvalidateOrderCaches(order.orderID)
    end

    return ok
end

function CO:OrderPassesQueueProfitFilter(order)
    local minProfit = self:GetQueueMinProfitCopper()
    if not minProfit then return true end
    if not order then return false end

    local info = self:GetOrderProfitInfo(order)
    if not info or tonumber(info.profit) == nil then return false end

    return tonumber(info.profit) >= minProfit
end

function CO:OrderRequiresConcentrationForQueue(order, pageFrame)
    if not order or not order.orderID then return false end

    if self.GetCachedConcentrationRequirementVisualState then
        local visualNeeded, hasVisualState = self:GetCachedConcentrationRequirementVisualState(order)
        if hasVisualState and visualNeeded == true then return true end
    end

    local requestedQuality = self:GetOrderRequestedQuality(order)
    if requestedQuality <= 0 then return false end

    local needed = self:DoesOrderNeedConcentrationForTargetQuality(order, true)
    if needed == nil and self.PrepareOrderForQueueAnalysis then
        self:PrepareOrderForQueueAnalysis(order, pageFrame)
        needed = self:DoesOrderNeedConcentrationForTargetQuality(order, true)
    end
    return needed == true
end

function CO:BuildOwnedMixForEntry(order, reagentEntry, vInv)
    local quantity = tonumber(reagentEntry.quantity) or 0
    if quantity <= 0 then return {}, 0 end

    local candidates = self:GetReagentCandidates(order, reagentEntry) or {}
    table.sort(candidates, function(a, b)
        local pa = tonumber(self:GetQueueReagentAuctionatorPrice(a.itemID)) or math.huge
        local pb = tonumber(self:GetQueueReagentAuctionatorPrice(b.itemID)) or math.huge
        if pa ~= pb then return pa < pb end
        return (tonumber(self:GetQueueReagentCandidateTier(a)) or 0) < (tonumber(self:GetQueueReagentCandidateTier(b)) or 0)
    end)

    local mix = {}
    local remaining = quantity
    for _, cand in ipairs(candidates) do
        if remaining <= 0 then break end
        local id = cand.itemID
        if id then
            local left = vInv[id]
            if left == nil then left = self:GetItemCountForShopping(id) or 0 end
            if left > 0 then
                local take = math.min(left, remaining)
                vInv[id] = left - take
                mix[#mix + 1] = {
                    itemID = id,
                    quantity = take,
                    slotIndex = reagentEntry.slotIndex or reagentEntry.dataSlotIndex,
                    dataSlotIndex = reagentEntry.dataSlotIndex,
                    qualityTier = self:GetQueueReagentCandidateTier(cand),
                }
                remaining = remaining - take
            end
        end
    end
    return mix, remaining
end

function CO:CanSupplyCrafterReagentsForQueue(order, saveSelections)
    if not order then return false end

    local mode = self.GetQueueReagentMode and self:GetQueueReagentMode() or "auto"
    local slots = self:BuildDisplayReagents(order)

    if mode == "auto" then
        local vInv = {}
        for _, reagentEntry in ipairs(slots) do
            if IsCrafterProvidedReagent(reagentEntry) and not IsCustomerProvidedReagent(reagentEntry) then
                local mix, remaining = self:BuildOwnedMixForEntry(order, reagentEntry, vInv)
                if remaining > 0 then
                    return false
                end
                if saveSelections and #mix > 0 then
                    local key = MakeReagentSelectionKeyForEntry(order.orderID, reagentEntry)
                    if key then
                        self.selectedReagents[key] = {
                            slotIndex = reagentEntry.slotIndex or reagentEntry.dataSlotIndex,
                            dataSlotIndex = reagentEntry.dataSlotIndex,
                            quantity = tonumber(reagentEntry.quantity) or 0,
                            itemID = mix[1].itemID,
                            qualityTier = mix[1].qualityTier,
                            mix = mix,
                        }
                    end
                end
            end
        end
        return true
    end

    for _, reagentEntry in ipairs(slots) do
        if IsCrafterProvidedReagent(reagentEntry) and not IsCustomerProvidedReagent(reagentEntry) then
            local selKey = MakeReagentSelectionKeyForEntry(order.orderID, reagentEntry)
            local sel = selKey and self.selectedReagents[selKey]
            if sel and type(sel.mix) == "table" and #sel.mix > 0 then
                local sum = 0
                for _, part in ipairs(sel.mix) do
                    if not part.itemID or (self:GetItemCountForShopping(part.itemID) or 0) < (tonumber(part.quantity) or 0) then
                        return false
                    end
                    sum = sum + (tonumber(part.quantity) or 0)
                end
                if sum < (tonumber(reagentEntry.quantity) or 0) then
                    return false
                end
            else
                local available = self:FindAvailableCrafterReagent(order, reagentEntry)
                if not available or not available.itemID then
                    return false
                end

                if saveSelections then
                    local slotIndex = reagentEntry.slotIndex or reagentEntry.dataSlotIndex
                    if slotIndex and available.itemID and available.itemID ~= reagentEntry.itemID then
                        self:SetSelectedReagentForEntry(order.orderID, reagentEntry, available)
                    end
                end
            end
        end
    end

    return true
end

function CO:OrderGivesKnowledge(order)
    if not order then return false end
    local rewards = order.npcOrderRewards or order.rewards
    if type(rewards) ~= "table" then return false end
    for _, reward in ipairs(rewards) do
        if type(reward) == "table" and GetRewardItemID and IsKnowledgePointRewardItem then
            local itemID = GetRewardItemID(reward)
            if itemID and IsKnowledgePointRewardItem(itemID) then
                return true
            end
        end
    end
    return false
end

function CO:AnalyzeOrderForQueue(order, orderType, opts, pageFrame)
    if not order or not order.orderID or not order.spellID then return nil end

    local prepared = self:PrepareOrderForQueueAnalysis(order, pageFrame)

    if self._knowledgeOnly then
        if not self:OrderGivesKnowledge(order) then return nil end
        local o = {}
        if opts then for k, v in pairs(opts) do o[k] = v end end
        o.allowConcentration = false
        o.forceConcentration = false
        opts = o
    end

    local known = self:GetRecipeKnownState(order)
    if known ~= true then
        if not prepared then
            prepared = self:PrepareOrderForQueueAnalysis(order, pageFrame)
            known = self:GetRecipeKnownState(order)
        end
        if known ~= true then return nil end
    end

    if not self:OrderMatchesSelectedProfessionExpansion(order, false) then return nil end


    if order.isFulfillable == false and orderType == (Enum and Enum.CraftingOrderType and Enum.CraftingOrderType.Public) then
        return nil
    end

    if not self:CanSupplyCrafterReagentsForQueue(order, false) then
        if not prepared then
            prepared = self:PrepareOrderForQueueAnalysis(order, pageFrame)
        end
        if not self:CanSupplyCrafterReagentsForQueue(order, false) then
            return nil
        end
    end

    local minQuality = tonumber(order.minQuality) or 0
    if minQuality <= 0 then
        return { queued = true, useConcentration = false, score = tonumber(order.tipAmount) or 0 }
    end

    local q = self:GetOrderQualityInfo(order, false, true)
    if not q and not prepared then
        prepared = self:PrepareOrderForQueueAnalysis(order, pageFrame)
        q = self:GetOrderQualityInfo(order, false, true)
    end
    if q and tonumber(q.quality) and q.quality >= minQuality then
        return { queued = true, useConcentration = false, score = tonumber(order.tipAmount) or 0 }
    end

    opts = opts or {}
    if opts.allowConcentration or opts.forceConcentration then
        local qConc = self:GetOrderQualityInfo(order, true, true)
        if not qConc and not prepared then
            prepared = self:PrepareOrderForQueueAnalysis(order, pageFrame)
            qConc = self:GetOrderQualityInfo(order, true, true)
        end
        if qConc and tonumber(qConc.quality) and qConc.quality >= minQuality then
            local cost = tonumber(qConc.concentrationCost) or 0
            if cost <= 0 or self:GetQueueConcentrationAmount() >= cost then
                return { queued = true, useConcentration = true, score = tonumber(order.tipAmount) or 0 }
            end
        end
    end

    return nil
end

function CO:MarkOrderQueuedForCheckbox(order, analysis, pageFrame)
    if not order or not order.orderID then return false end

    local key = OrderKey(order.orderID)
    if not key then return false end

    self.rowStates[order.orderID] = self.rowStates[order.orderID] or {}
    self.rowStates[order.orderID].order = order
    self.rowStates[order.orderID].pageFrame = pageFrame or self.activePageFrame

    if not self:ApplyQueueReagentModeToOrder(order) then
        return false
    end

    self.selectedOrders[key] = true
    self.useConcentration[key] = analysis and analysis.useConcentration == true or nil
    self.currentQueueOrderID = self.currentQueueOrderID or order.orderID

    return true
end

function CO:ShouldQueueOrderByAvailabilityColor(order)
    if not order or not order.orderID then return false end
    if self._knowledgeOnly and not self:OrderGivesKnowledge(order) then return false end
    if not self.GetOrderActionAvailabilitySortRank then return false end
    if not self:ApplyQueueReagentModeToOrder(order) then return false end
    if self:OrderRequiresConcentrationForQueue(order) then return false end
    if not self:OrderPassesQueueProfitFilter(order) then return false end

    local rank = self:GetOrderActionAvailabilitySortRank(order)
    return rank == 1 or rank == 2
end

function CO:GetAvailabilityQueueAnalysis(order, orderType, opts, pageFrame)
    if not self:ShouldQueueOrderByAvailabilityColor(order) then return nil end

    local analysis = self:AnalyzeOrderForQueue(order, orderType, opts, pageFrame)
    if analysis and analysis.queued then
        local profit = tonumber((self:GetOrderProfitInfo(order) or {}).profit)
        if profit then
            analysis.score = profit
        end
        return analysis
    end

    return {
        queued = true,
        useConcentration = false,
        score = tonumber((self:GetOrderProfitInfo(order) or {}).profit) or tonumber(order and order.tipAmount) or 0,
    }
end

function CO:FinishQueueWorkOrdersSelection(session)
    local selected = session and session.selected or 0
    self.queueSelectionRunning = false

    if self.controlPanel and self.controlPanel.selectAllButton then
        self.controlPanel.selectAllButton:Enable()
        self.controlPanel.selectAllButton.text:SetText(T("COA_QUEUE_BUTTON", "Queue"))
    end

    self:RefreshVisibleRows()
    self:UpdateControlPanel()
    self:SetStatus(string.format(T("COA_STATUS_QUEUED_ORDERS", "Queued orders: %d."), selected))
end

function CO:QueueVisibleWorkOrdersSelection()
    local pageFrame = self:FindOrderPageFrame() or self.activePageFrame
    local session = { selected = 0, seen = {} }

    wipe(self.selectedOrders)
    self.currentQueueOrderID = nil
    self.queueReagentPriceCache = {}
    wipe(self.queuePreparedOrders or {})
    self.queuePreparedOrders = self.queuePreparedOrders or {}

    local buttons = self:GetVisibleOrderButtonsSorted()

    local opts = self:GetQueueOptions()
    for _, btn in ipairs(buttons) do
        local order = btn.order
        local key = OrderKey(order and order.orderID)
        local tabOk = not (pageFrame and pageFrame.orderType ~= nil and order and order.orderType ~= nil
            and order.orderType ~= pageFrame.orderType)
        if key and tabOk and not session.seen[key] then
            session.seen[key] = true
            local analysis = self:GetAvailabilityQueueAnalysis(order, order.orderType, opts, pageFrame)
            if analysis and analysis.queued and self:MarkOrderQueuedForCheckbox(order, analysis, pageFrame) then
                session.selected = session.selected + 1
            end
        end
    end

    self:FinishQueueWorkOrdersSelection(session)
end

function CO:QueueWorkOrdersSelection(knowledgeOnly)
    if self.queueSelectionRunning then return end
    self._knowledgeOnly = knowledgeOnly == true
    if self.viewingCachedOrders then
        self:SetStatus(T("COA_STATUS_QUEUE_VIEW_ONLY", "Queue can only be built while the crafting orders page is available."))
        return
    end

    local pageFrame = self:FindOrderPageFrame() or self.activePageFrame
    local profession = GetProfessionFromPage(pageFrame)
    if not profession or not C_CraftingOrders or type(C_CraftingOrders.RequestCrafterOrders) ~= "function" then
        self:QueueVisibleWorkOrdersSelection()
        return
    end

    local orderTypes = self:GetQueueOrderTypes()
    if pageFrame and pageFrame.orderType ~= nil then
        orderTypes = { pageFrame.orderType }
    end
    if #orderTypes == 0 then
        self:SetStatus(T("COA_STATUS_QUEUE_NO_TYPES", "No work order types are enabled for the queue."))
        return
    end

    self.queueSelectionRunning = true
    wipe(self.selectedOrders)
    self.currentQueueOrderID = nil
    self.queueReagentPriceCache = {}
    wipe(self.queuePreparedOrders or {})
    self.queuePreparedOrders = self.queuePreparedOrders or {}

    local opts = self:GetQueueOptions()

    if self.controlPanel and self.controlPanel.selectAllButton then
        self.controlPanel.selectAllButton:Disable()
        self.controlPanel.selectAllButton.text:SetText("...")
    end

    local session = {
        selected = 0,
        publicCandidates = {},
        seen = {},
    }

    local function selectOrder(order, analysis)
        local key = OrderKey(order and order.orderID)
        if not key or session.seen[key] then return end
        if pageFrame and pageFrame.orderType ~= nil and order and order.orderType ~= nil
            and order.orderType ~= pageFrame.orderType then
            return
        end
        session.seen[key] = true
        if self:MarkOrderQueuedForCheckbox(order, analysis, pageFrame) then
            session.selected = session.selected + 1
        end
    end

    local function flushPublicCandidates()
        if #session.publicCandidates == 0 then return end

        table.sort(session.publicCandidates, function(a, b)
            return (tonumber(a.score) or 0) > (tonumber(b.score) or 0)
        end)

        local maxCount = tonumber(opts.publicMaxCount) or 0
        if maxCount == 0 and C_CraftingOrders.GetOrderClaimInfo then
            local claimInfo = C_CraftingOrders.GetOrderClaimInfo(profession)
            maxCount = claimInfo and tonumber(claimInfo.claimsRemaining) or 0
        end
        if maxCount <= 0 then maxCount = #session.publicCandidates end

        for i = 1, math.min(maxCount, #session.publicCandidates) do
            local candidate = session.publicCandidates[i]
            selectOrder(candidate.order, candidate.analysis)
        end
    end

    local function finish()
        if session.finished then return end
        session.finished = true
        flushPublicCandidates()


        if session.selected == 0 then
            self.queueSelectionRunning = false
            self:QueueVisibleWorkOrdersSelection()
            return
        end
        self:FinishQueueWorkOrdersSelection(session)
    end

    local function processOrders(orderType, orders, done)
        local i = 1
        local isPublic = Enum and Enum.CraftingOrderType and orderType == Enum.CraftingOrderType.Public

        local function step()
            local limit = math.min(#orders, i + 3)
            while i <= limit do
                local order = orders[i]
                i = i + 1
                if order and order.orderID and order.spellID then
                    local analysis = self:GetAvailabilityQueueAnalysis(order, orderType, opts, pageFrame)
                    if analysis and analysis.queued then
                        if isPublic then
                            session.publicCandidates[#session.publicCandidates + 1] = {
                                order = order,
                                analysis = analysis,
                                score = analysis.score or order.tipAmount or 0,
                            }
                        else
                            selectOrder(order, analysis)
                        end
                    end
                end
            end

            if i <= #orders then
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, step)
                else
                    step()
                end
            else
                done()
            end
        end

        step()
    end

    local function requestType(index)
        local orderType = orderTypes[index]
        if not orderType then
            finish()
            return
        end

        if self.controlPanel and self.controlPanel.selectAllButton then
            self.controlPanel.selectAllButton.text:SetText(tostring(index) .. "/" .. tostring(#orderTypes))
        end

        local callback = function(result)
            if not IsResultOk(result) then
                requestType(index + 1)
                return
            end

            local orders = {}
            local ok, resultOrders = pcall(C_CraftingOrders.GetCrafterOrders)
            if ok and type(resultOrders) == "table" then
                orders = resultOrders
            end

            local claimed = self:GetClaimedOrder()
            if claimed and (not claimed.orderType or claimed.orderType == orderType) then
                orders[#orders + 1] = claimed
            end

            processOrders(orderType, orders, function()
                requestType(index + 1)
            end)
        end

        local request = {
            orderType = orderType,
            searchFavorites = false,
            initialNonPublicSearch = false,
            primarySort = {
                sortType = Enum.CraftingOrderSortType and Enum.CraftingOrderSortType.ItemName or 1,
                reversed = false,
            },
            secondarySort = {
                sortType = Enum.CraftingOrderSortType and Enum.CraftingOrderSortType.MaxTip or 2,
                reversed = false,
            },
            forCrafter = true,
            offset = 0,
            profession = profession,
            callback = (C_FunctionContainers and C_FunctionContainers.CreateCallback) and C_FunctionContainers.CreateCallback(callback) or callback,
        }

        local ok = pcall(C_CraftingOrders.RequestCrafterOrders, request)
        if not ok then
            requestType(index + 1)
        end
    end

    self:SetStatus(T("COA_STATUS_QUEUE_BUILDING", "Building work order queue..."))
    if C_Timer and C_Timer.After then
        C_Timer.After(5, function()
            if CO.queueSelectionRunning and not session.finished then
                finish()
            end
        end)
    end
    requestType(1)
end

function CO:SelectCraftableVisibleOrders()
    wipe(self.selectedOrders)
    self.currentQueueOrderID = nil
    self.queueReagentPriceCache = {}
    wipe(self.queuePreparedOrders or {})
    self.queuePreparedOrders = self.queuePreparedOrders or {}

    local buttons = {}
    for btn in pairs(self.visibleRowButtons or {}) do
        if btn and btn:IsShown() and btn.orderID and self:IsOrderCraftableForSelection(btn) then
            buttons[#buttons + 1] = btn
        end
    end

    table.sort(buttons, function(a, b)
        return (a:GetTop() or 0) > (b:GetTop() or 0)
    end)

    for _, btn in ipairs(buttons) do
        self.selectedOrders[OrderKey(btn.orderID)] = true
        self.currentQueueOrderID = self.currentQueueOrderID or btn.orderID
    end

    self:SetStatus(string.format(T("COA_STATUS_SELECTED_CRAFTABLE", "Selected craftable orders: %d."), #buttons))
    self:RefreshVisibleRows()
    self:UpdateControlPanel()
end

function CO:GetItemCountForShopping(itemID)
    if not itemID then return 0 end

    local function TryCount(fn)
        if type(fn) ~= "function" then return nil end


        local attempts = {
            { itemID, true, false, true, true },
            { itemID, true, false, true },
            { itemID, true },
            { itemID },
        }

        for _, args in ipairs(attempts) do
            local ok, value = pcall(fn, unpack(args))
            value = ok and tonumber(value) or nil
            if value then
                return value
            end
        end

        return nil
    end

    return TryCount(C_Item and C_Item.GetItemCount)
        or TryCount(GetItemCount)
        or 0
end

function CO:AddShoppingMaterial(materialsByKey, itemID, quantity, qualityTier, label, maxTier, expansionID)
    itemID = tonumber(itemID)
    quantity = math.floor(tonumber(quantity) or 0)
    if not itemID or quantity <= 0 then return end

    qualityTier = NormalizeQualityTier(qualityTier)
    local key = tostring(itemID) .. ":" .. tostring(qualityTier or 0)
    local row = materialsByKey[key]
    if not row then
        row = {
            itemID = itemID,
            quantity = 0,
            label = label,
            maxTier = tonumber(maxTier),
            expansionID = tonumber(expansionID),
        }
        if qualityTier then
            row.tier = qualityTier
            row.chosenTier = qualityTier
            row.materialQuality = qualityTier
            row.professionQuality = qualityTier
        end
        materialsByKey[key] = row
    else
        row.maxTier = row.maxTier or tonumber(maxTier)
        row.expansionID = row.expansionID or tonumber(expansionID)
    end

    row.quantity = row.quantity + quantity
end

function CO:BuildShoppingMaterialsForSelectedOrders()
    local debug = self.shoppingDebug == true
    local function DPrint(msg) if debug then print("|cffb19cd9HironCraft CO shop|r " .. msg) end end

    local required = {}
    local orderCount = 0
    local seenOrders = {}
    local virtualInventory = {}

    local function ReserveFromVirtualInventory(itemID, want)
        itemID = tonumber(itemID)
        if not itemID or not want or want <= 0 then return 0 end
        local left = virtualInventory[itemID]
        if left == nil then
            left = self:GetItemCountForShopping(itemID) or 0
        end
        local take = math.min(left, want)
        virtualInventory[itemID] = left - take
        return take
    end

    local visibleCount = 0
    for _ in pairs(self.visibleRowButtons or {}) do visibleCount = visibleCount + 1 end
    DPrint("visibleRowButtons=" .. visibleCount)

    for btn in pairs(self.visibleRowButtons or {}) do
        if btn and btn:IsShown() and btn.orderID and self:IsOrderSelected(btn.orderID) then
            local orderKey = OrderKey(btn.orderID)
            local order = btn.order
            if order and orderKey and not seenOrders[orderKey] then
                seenOrders[orderKey] = true
                orderCount = orderCount + 1

                local recipeName = (order and order.spellID and GetSpellInfo and GetSpellInfo(order.spellID)) or tostring(order and order.spellID or "?")
                DPrint(string.format("--- order #%d id=%s recipe=%s ---", orderCount, tostring(btn.orderID), tostring(recipeName)))

                local seenSlots = {}
                for ri, reagentEntry in ipairs(self:BuildDisplayReagents(order)) do
                    local isCrafter = IsCrafterProvidedReagent(reagentEntry) == true
                    local isCustomer = IsCustomerProvidedReagent(reagentEntry) == true
                    local entryName = reagentEntry.name or (reagentEntry.itemID and GetItemInfo(reagentEntry.itemID)) or "?"

                    if not isCrafter or isCustomer then
                        DPrint(string.format("  reagent[%d] %s itemID=%s skip: crafter=%s customer=%s",
                            ri, tostring(entryName), tostring(reagentEntry.itemID),
                            tostring(isCrafter), tostring(isCustomer)))
                    end

                    if isCrafter and not isCustomer then
                        local schematicIndex = reagentEntry.schematicIndex
                        local slotIndex = reagentEntry.dataSlotIndex or reagentEntry.slotIndex
                        local slotKey
                        if schematicIndex then
                            slotKey = "schematic:" .. tostring(schematicIndex)
                        elseif slotIndex and reagentEntry.itemID then
                            slotKey = "slot:" .. tostring(slotIndex) .. ":item:" .. tostring(reagentEntry.itemID)
                        elseif slotIndex then
                            slotKey = "slot:" .. tostring(slotIndex)
                        else
                            slotKey = "item:" .. tostring(reagentEntry.itemID or "?")
                        end

                        if not seenSlots[slotKey] then
                            seenSlots[slotKey] = true
                            local selected = self:GetSelectedReagentForEntry(order.orderID, reagentEntry)
                            if selected and type(selected.mix) == "table" and #selected.mix > 0 then
                                for _, part in ipairs(selected.mix) do
                                    local pid = part.itemID
                                    local pq = tonumber(part.quantity) or 0
                                    if pid and pq > 0 then
                                        local reserved = ReserveFromVirtualInventory(pid, pq)
                                        local rem = pq - reserved
                                        if rem > 0 then
                                            self:AddShoppingMaterial(required, pid, rem, part.qualityTier, (GetItemInfo(pid)), reagentEntry.maxQualityTier, reagentEntry.expansionID)
                                            DPrint(string.format("    mix => added %dx item %s", rem, tostring(pid)))
                                        end
                                    end
                                end
                            else
                            local itemID = selected and selected.itemID or reagentEntry.itemID
                            local quantity = reagentEntry.quantity or 0
                            local qualityTier = (selected and selected.qualityTier) or reagentEntry.qualityTier
                            local label = selected and selected.label or reagentEntry.name

                            local have = itemID and (self:GetItemCountForShopping(itemID) or 0) or 0
                            DPrint(string.format("  reagent[%d] %s itemID=%s qty=%s tier=%s have=%s slotKey=%s",
                                ri, tostring(label), tostring(itemID), tostring(quantity),
                                tostring(qualityTier), tostring(have), slotKey))

                            if quantity > 0 then
                                local remaining = quantity

                                if itemID then
                                    local reserved = ReserveFromVirtualInventory(itemID, remaining)
                                    remaining = remaining - reserved
                                    DPrint(string.format("    reserved main=%s remaining=%s", tostring(reserved), tostring(remaining)))
                                end

                                local reagentMode = self.GetQueueReagentMode and self:GetQueueReagentMode() or "auto"
                                local allowCandidateSubstitution = reagentMode == "auto"

                                if remaining > 0 and allowCandidateSubstitution then
                                    local candidates = self.GetReagentCandidates
                                        and self:GetReagentCandidates(order, reagentEntry)
                                        or reagentEntry.candidates
                                        or {}
                                    for _, cand in ipairs(candidates) do
                                        if remaining <= 0 then break end
                                        local cid = cand and (cand.itemID or (cand.reagent and cand.reagent.itemID))
                                        if cid and cid ~= itemID then
                                            local reserved = ReserveFromVirtualInventory(cid, remaining)
                                            remaining = remaining - reserved
                                            DPrint(string.format("    candidate cid=%s reserved=%s remaining=%s", tostring(cid), tostring(reserved), tostring(remaining)))
                                        end
                                    end
                                elseif remaining > 0 then
                                    DPrint(string.format("    reagentMode=%s -> skip candidate substitution (must buy %s of exact itemID)", reagentMode, tostring(remaining)))
                                end

                                if remaining > 0 then
                                    self:AddShoppingMaterial(required, itemID, remaining, qualityTier, label, reagentEntry.maxQualityTier, reagentEntry.expansionID)
                                    DPrint(string.format("    => added %sx %s (tier=%s)", tostring(remaining), tostring(label), tostring(qualityTier)))
                                else
                                    DPrint("    => fully covered by inventory, not adding")
                                end
                            else
                                DPrint("    => quantity<=0, skipping")
                            end
                            end
                        else
                            DPrint(string.format("  reagent[%d] %s itemID=%s slot dup, skip", ri, tostring(entryName), tostring(reagentEntry.itemID)))
                        end
                    end
                end
            end
        end
    end

    local materials = {}
    for _, row in pairs(required) do
        if row.quantity > 0 then
            materials[#materials + 1] = row
        end
    end

    table.sort(materials, function(a, b)
        local an = a.label or (a.itemID and GetItemInfo(a.itemID)) or tostring(a.itemID or "")
        local bn = b.label or (b.itemID and GetItemInfo(b.itemID)) or tostring(b.itemID or "")
        if an == bn then return (a.itemID or 0) < (b.itemID or 0) end
        return tostring(an) < tostring(bn)
    end)

    DPrint(string.format("=== result: %d materials, %d orders ===", #materials, orderCount))
    for _, m in ipairs(materials) do
        DPrint(string.format("  - %s itemID=%s qty=%s tier=%s",
            tostring(m.label), tostring(m.itemID), tostring(m.quantity), tostring(m.tier or m.chosenTier)))
    end

    return materials, orderCount
end


function CO:EncodeHironCraftProfitShoppingExportField(value)
    value = tostring(value or "")
    local encoded = value:gsub("([^%w _%-%.])", function(char)
        return string.format("%%%02X", string.byte(char))
    end)
    return encoded
end

function CO:BuildHironCraftProfitShoppingImportText(listName, materials)
    local parts = {
        "HIRONCRAFT_PROFIT_SHOP_V1",
        self:EncodeHironCraftProfitShoppingExportField(listName or T("COA_SHOPPING_LIST_NAME", "Crafting orders")),
    }

    for _, row in ipairs(materials or {}) do
        local itemID = tonumber(row.itemID)
        local quantity = math.max(1, math.floor(tonumber(row.quantity) or 1))
        local tier = NormalizeQualityTier(row.chosenTier or row.tier or row.professionQuality or row.materialQuality) or 0
        local label = self:EncodeHironCraftProfitShoppingExportField(row.label or (itemID and GetItemInfo(itemID)) or "")

        if itemID then
            parts[#parts + 1] = "i," .. tostring(itemID) .. "," .. tostring(quantity) .. "," .. tostring(tier) .. "," .. label
        elseif row.label and row.label ~= "" then
            parts[#parts + 1] = "n," .. tostring(quantity) .. "," .. tostring(tier) .. "," .. label
        end
    end

    return table.concat(parts, "^")
end

function CO:TryStartHironCraftProfitShopScan(shopping, delays)
    if not shopping or type(shopping.ScanAllRows) ~= "function" or not C_Timer then return end
    for _, delay in ipairs(delays or { 0.25, 0.75, 1.5, 2.5 }) do
        C_Timer.After(delay, function()
            if shopping.session and shopping.session.active and shopping.isAuctionHouseOpen
               and not (shopping.scanAllState and shopping.scanAllState.active) then
                shopping:ScanAllRows()
            end
        end)
    end
end


local function FormatShoppingCopperPlain(copper)
    copper = math.max(0, math.floor(tonumber(copper) or 0))

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local coin = copper % 100

    if gold >= 1000000 then
        return string.format("%.1fm", gold / 1000000) .. "g"
    end
    if gold >= 1000 then
        return string.format("%.1fk", gold / 1000) .. "g"
    end
    if gold > 0 then
        return tostring(gold) .. "g"
    end
    if silver > 0 then
        return tostring(silver) .. "s"
    end
    return tostring(coin) .. "c"
end

function CO:FormatShoppingCostCompact(copper, missingPrices)
    copper = tonumber(copper) or 0
    local text = FormatShoppingCopperPlain(copper)

    if missingPrices then
        if copper > 0 then
            return text .. "+?"
        end
        return "?"
    end

    return text
end

function CO:GetShoppingMaterialsCostInfo(materials)
    local total = 0
    local missingPrices = false
    local pricedItems = 0

    for _, row in ipairs(materials or {}) do
        local itemID = tonumber(row.itemID)
        local quantity = tonumber(row.quantity) or 0
        if itemID and quantity > 0 then
            local price = GetAuctionatorItemPrice and GetAuctionatorItemPrice(itemID, nil)
            if price and price > 0 then
                total = total + (price * quantity)
                pricedItems = pricedItems + 1
            else
                missingPrices = true
            end
        end
    end

    return {
        total = total,
        missingPrices = missingPrices,
        pricedItems = pricedItems,
        itemCount = #(materials or {}),
        text = self:FormatShoppingCostCompact(total, missingPrices),
    }
end

function CO:GetSelectedShoppingCostInfo()
    local materials, orderCount = self:BuildShoppingMaterialsForSelectedOrders()
    local info = self:GetShoppingMaterialsCostInfo(materials)
    info.orderCount = orderCount or 0
    info.materials = materials
    return info
end

function CO:UpdateShoppingCostText()
    local panel = self.controlPanel
    local text = panel and panel.shopCostText
    if not text then return end

    local info = self:GetSelectedShoppingCostInfo()
    local value = info and info.text or ""
    text:SetText(value)

    if info and info.missingPrices then
        text:SetTextColor(1, 0.35, 0.35, 1)
    elseif info and tonumber(info.total) and tonumber(info.total) > 0 then
        text:SetTextColor(0.95, 0.82, 0.42, 1)
    else
        text:SetTextColor(0.55, 0.55, 0.58, 1)
    end
end

function CO:CreateShoppingListForSelectedOrders()
    if not self:HasSelectedOrders() then
        self:SetStatus(T("COA_STATUS_SHOP_NO_SELECTED", "Check orders first."))
        return false
    end

    local materials, orderCount = self:BuildShoppingMaterialsForSelectedOrders()
    if not materials or #materials == 0 then
        self:SetStatus(T("COA_STATUS_SHOP_EMPTY", "Nothing to buy for selected orders."))
        return false
    end

    local listName = T("COA_SHOPPING_LIST_NAME", "Crafting orders")
    local shopping = PT and PT.ShoppingList

    if shopping and type(shopping.CreateTemporaryImportedList) == "function" then
        local ok, reason = shopping:CreateTemporaryImportedList(listName, materials, "crafting_orders")

        if ok then
            if type(shopping.ShowWindow) == "function" then
                SafeCall("HironCraftProfitshop ShowWindow", function() shopping:ShowWindow() end)
            end
            self:TryStartHironCraftProfitShopScan(shopping)
            self:SetStatus(string.format(T("COA_STATUS_SHOP_CREATED", "Shopping list created: %d items from %d orders."), #materials, orderCount or 0))
            return true
        end

        self:SetStatus(T("COA_STATUS_SHOP_TEMP_FAILED", "Could not create a temporary HironCraftProfitshop list.") .. " " .. tostring(reason or ""))
        return false
    end

    self:SetStatus(T("COA_STATUS_SHOP_UNAVAILABLE", "HironCraftProfitshop temporary shopping session API is unavailable."))
    return false
end

function CO:HideOrderRowOverlays(row)
    if not row then return end
    RestoreHiddenOrderRowRegions(row)
    if row.ahuiOrderOriginalHeight and row.SetHeight then
        row:SetHeight(row.ahuiOrderOriginalHeight)
        row.ahuiOrderTallRow = false
    end
    if row.cells then
        for _, cell in ipairs(row.cells) do
            if cell and cell.ahuiOrderOriginalHeight and cell.SetHeight then
                cell:SetHeight(cell.ahuiOrderOriginalHeight)
            end
        end
    end
    if row.ahuiOrderActionButton then row.ahuiOrderActionButton:Hide() end
    if row.ahuiOrderReagentsFrame then row.ahuiOrderReagentsFrame:Hide() end
    if row.ahuiOrderRewardsFrame then row.ahuiOrderRewardsFrame:Hide() end
    if row.ahuiOrderFocusFrame then row.ahuiOrderFocusFrame:Hide() end
    if row.ahuiOrderProfitFrame then row.ahuiOrderProfitFrame:Hide() end
    if row.ahuiUnknownRecipeBorder then row.ahuiUnknownRecipeBorder:Hide() end
    if row.ahuiCraftableOrderBorder then row.ahuiCraftableOrderBorder:Hide() end
    if row.ahuiConcentrationRequiredBorder then row.ahuiConcentrationRequiredBorder:Hide() end
    if row.ahuiOrderHoverHighlight then row.ahuiOrderHoverHighlight:Hide() end
end

function CO:HideAllOrderOverlays()
    self:RestoreOrderTableColumns()
    local pageFrame = self.activePageFrame or self.protectedPageFrame
    if pageFrame then
        self:RestoreHiddenOrderHeaderRegions(pageFrame)
        if pageFrame.ahuiOrderHeaderOverlay then pageFrame.ahuiOrderHeaderOverlay:Hide() end
    end
    if self.controlPanel then
        self.controlPanel:Hide()
        if self.controlPanel.shopButton then self.controlPanel.shopButton:Hide() end
    end

    for btn in pairs(self.visibleRowButtons or {}) do
        if btn then
            local row = btn.GetParent and btn:GetParent()
            self:HideOrderRowOverlays(row)
        end
    end

    self:ClearTemporaryBinding()
    self:StopRowProgress()
    self:StopPageProtector()
end

function CO:ApplyEnabledState()
    if not self:IsEnabled() then
        self:HideAllOrderOverlays()
        if self.CustomList and self.CustomList.Deactivate then
            self.CustomList:Deactivate()
        end
        return
    end

    self:HookBlizzardProfessions()
    self:LockOrderTableColumns()
    local pageFrame = self.activePageFrame or self:FindOrderPageFrame()
    if pageFrame then
        self.activePageFrame = pageFrame
        self:EnsurePageBindingHooks(pageFrame)
        self:EnsureControlPanel(pageFrame)
        self:UpdateControlPanelVisibility(pageFrame)
        self:ApplyTemporaryBinding()
        self:StartPageProtector(pageFrame)
        if pageFrame.SetupTable then
            pcall(pageFrame.SetupTable, pageFrame)
        end
    end
    self:RefreshVisibleRowsSoon(0.05)
end
