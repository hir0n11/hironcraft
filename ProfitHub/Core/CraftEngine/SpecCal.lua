local PT = HironCraft or HironCraftProfit
if not PT then return end

PT.CraftEngine = PT.CraftEngine or {}
local CE = PT.CraftEngine
local LILAC = { 0.694, 0.612, 0.851 }

local STAT_BY_NAME = {
    ["Находчивость"] = "resourcefulness", ["Resourcefulness"] = "resourcefulness",
    ["Перепроизводство"] = "multicraft", ["Multicraft"] = "multicraft",
    ["Изобретательность"] = "ingenuity", ["Ingenuity"] = "ingenuity",
    ["Скорость изготовления"] = "speed", ["Crafting Speed"] = "speed",
}

local function pc(fn, ...) if type(fn) ~= "function" then return nil end local ok, a = pcall(fn, ...) if ok then return a end end

function CE:SpecRecipeStats(rid)
    local op = pc(C_TradeSkillUI.GetCraftingOperationInfo, rid, {}, nil, false)
    if type(op) ~= "table" then return nil end
    local s = { skill = (op.baseSkill or 0) + (op.bonusSkill or 0) }
    if type(op.bonusStats) == "table" then
        for _, bs in ipairs(op.bonusStats) do
            local k = STAT_BY_NAME[bs.bonusStatName or ""]
            if k then s[k] = bs.ratingPct or bs.bonusStatValue or 0 end
        end
    end
    return s
end

function CE:SpecRanksVector(configID, sl)
    local PS, CT = C_ProfSpecs, C_Traits
    local out = {}
    for _, tabID in ipairs(pc(PS.GetSpecTabIDsForSkillLine, sl) or {}) do
        local stack = { pc(PS.GetRootPathForTab, tabID) }
        while #stack > 0 do
            local pid = table.remove(stack)
            if pid and out[pid] == nil then
                local ni = pc(CT.GetNodeInfo, configID, pid)
                out[pid] = (type(ni) == "table" and ni.currentRank) or 0
                for _, k in ipairs(pc(PS.GetChildrenForPath, pid, configID) or {}) do stack[#stack + 1] = k end
            end
        end
    end
    return out
end

function CE:SpecPathStat(pathID, configID)
    local desc = pc(C_ProfSpecs.GetDescriptionForPath, pathID, configID)
    if type(desc) ~= "string" then return nil end
    for name, key in pairs(STAT_BY_NAME) do if desc:find(name, 1, true) then return key end end
    if desc:find("навык", 1, true) or desc:find("Мастерств", 1, true) then return "skill" end
    if desc:find("ачеств", 1, true) then return "quality" end
    return nil
end

function CE:SpecNodeName(pathID, configID)
    local PS, CT = C_ProfSpecs, C_Traits
    local se = pc(PS.GetSpendEntryForPath, pathID)
    local ei = se and pc(CT.GetEntryInfo, configID, se)
    local di = ei and ei.definitionID and pc(CT.GetDefinitionInfo, ei.definitionID)
    if type(di) == "table" then
        if di.overrideName and di.overrideName ~= "" then return di.overrideName end
        local sid = di.spellID or di.overriddenSpellID
        if sid then
            local i = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(sid)
            if type(i) == "table" and i.name then return i.name end
        end
    end
    return "узел " .. tostring(pathID)
end

function CE:SpecCalDB(sl)
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB.specCal = HironCraftProfit_DB.specCal or {}
    HironCraftProfit_DB.specCal[sl] = HironCraftProfit_DB.specCal[sl] or { snaps = {}, learned = {} }
    return HironCraftProfit_DB.specCal[sl]
end

function CE:SpecSnapshot()
    local sl = self:ResolveSpecSkillLine()
    local configID = sl and pc(C_ProfSpecs.GetConfigIDForSkillLine, sl)
    if not configID then return nil, "нет открытой профессии со специализацией" end
    local ranks = self:SpecRanksVector(configID, sl)
    local recipes, nrec = {}, 0
    for _, rid in ipairs(pc(C_TradeSkillUI.GetAllRecipeIDs) or {}) do
        local ri = pc(C_TradeSkillUI.GetRecipeInfo, rid)
        if type(ri) == "table" and ri.supportsCraftingStats then
            local stats = self:SpecRecipeStats(rid)
            if stats then recipes[rid] = stats; nrec = nrec + 1 end
        end
    end
    local db = self:SpecCalDB(sl)
    table.insert(db.snaps, { ranks = ranks, recipes = recipes })
    while #db.snaps > 4 do table.remove(db.snaps, 1) end
    return sl, nrec
end

function CE:SpecDetectChange(sl)
    local db = HironCraftProfit_DB.specCal and HironCraftProfit_DB.specCal[sl]
    if not db or #db.snaps < 2 then return nil, "сделай базовый снимок, примени узел, ещё снимок" end
    local configID = pc(C_ProfSpecs.GetConfigIDForSkillLine, sl)
    local A, B = db.snaps[#db.snaps - 1], db.snaps[#db.snaps]
    local changed = {}
    for pid, rB in pairs(B.ranks) do if (A.ranks[pid] or 0) ~= rB then changed[#changed + 1] = pid end end
    if #changed == 0 then return nil, "ранги не менялись — примени узел и сними снова" end
    if #changed > 1 then return nil, string.format("изменилось узлов: %d — применяй по одному", #changed) end
    local node = changed[1]
    local stat = self:SpecPathStat(node, configID)
    local recipes = {}
    for rid, sB in pairs(B.recipes) do
        local sA = A.recipes[rid]
        if sA then
            local deltas = {}
            for st, vB in pairs(sB) do
                local d = (vB or 0) - (sA[st] or 0)
                if (not stat or st == stat) and math.abs(d) > 0.01 then
                    deltas[#deltas + 1] = { stat = st, d = d, a = vB or 0, b = sA[st] or 0 }
                end
            end
            if #deltas > 0 then
                local ri = pc(C_TradeSkillUI.GetRecipeInfo, rid)
                recipes[#recipes + 1] = { rid = rid, name = (ri and ri.name) or ("рецепт " .. rid),
                    stat = deltas[1].stat, deltas = deltas }
            end
        end
    end
    table.sort(recipes, function(a, b) return (a.name or "") < (b.name or "") end)
    return { node = node, name = self:SpecNodeName(node, configID), stat = stat, recipes = recipes }
end

function CE:SpecLearnedForRecipe(sl, recipeID)
    local out
    local bundled = PT.SpecMap and PT.SpecMap[sl] and PT.SpecMap[sl][recipeID]
    if bundled then out = {}; for k, v in pairs(bundled) do out[k] = v end end
    local db = HironCraftProfit_DB.specCal and HironCraftProfit_DB.specCal[sl]
    local live = db and db.learned and db.learned[recipeID]
    if live then out = out or {}; for k, v in pairs(live) do out[k] = v end end
    return out
end

function CE:SpecExportString()
    local cal = HironCraftProfit_DB.specCal
    local L = {}
    local total = 0
    if type(cal) == "table" then
        local sls = {}
        for sl in pairs(cal) do sls[#sls + 1] = sl end
        table.sort(sls)
        for _, sl in ipairs(sls) do
            local db = cal[sl]
            if db and db.learned and next(db.learned) then
                L[#L + 1] = string.format("PT.SpecMap[%d] = {", sl)
                local rids = {}
                for rid in pairs(db.learned) do rids[#rids + 1] = rid end
                table.sort(rids)
                for _, rid in ipairs(rids) do
                    local nodes, nids = db.learned[rid], {}
                    for nid in pairs(nodes) do nids[#nids + 1] = nid end
                    table.sort(nids)
                    local parts = {}
                    for _, nid in ipairs(nids) do parts[#parts + 1] = string.format("[%d]=%q", nid, nodes[nid] or "") end
                    L[#L + 1] = string.format("  [%d] = { %s },", rid, table.concat(parts, ", "))
                    total = total + 1
                end
                L[#L + 1] = "}"
            end
        end
    end
    if total == 0 then return "-- нет данных калибровки", 0 end
    return table.concat(L, "\n"), total
end

local function CountKeys(t) local n = 0 if t then for _ in pairs(t) do n = n + 1 end end return n end

local STAT_RU = { skill = "Навык", resourcefulness = "Находчивость", multicraft = "Перепроизводство",
    ingenuity = "Изобретательность", speed = "Скорость", quality = "Качество" }

local function ShowDeltaTooltip(owner, rec)
    if not rec then return end
    local tip = PT.Tooltip
    if tip then
        tip:Clear()
        tip:AddLine(rec.name or "?", 13, 1, 0.82, 0.35)
        tip:AddLine("Что изменилось от этого узла:", 11, 0.7, 0.7, 0.75)
        for _, d in ipairs(rec.deltas or {}) do
            local isPct = d.stat ~= "skill"
            local fmt = isPct and "%s: %.2f > %.2f  (%+.2f%%)" or "%s: %.0f > %.0f  (%+.0f)"
            tip:AddLine(string.format(fmt, STAT_RU[d.stat] or d.stat, d.b, d.a, d.d), 12,
                d.d >= 0 and 0.5 or 1, d.d >= 0 and 1 or 0.4, 0.5)
        end
        tip:ShowAtCursor(16, 0)
    else
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:AddLine(rec.name or "?", 1, 0.82, 0.35)
        for _, d in ipairs(rec.deltas or {}) do
            GameTooltip:AddLine(string.format("%s: %+.2f", STAT_RU[d.stat] or d.stat, d.d), 0.5, 1, 0.5)
        end
        GameTooltip:Show()
    end
end

function CE:SpecShowExport()
    local f = CE._exportUI
    if not f then
        f = CreateFrame("Frame", "HironCraftProfitSpecExport", UIParent, "BackdropTemplate")
        f:SetSize(560, 420)
        f:SetPoint("CENTER")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        f:SetBackdropColor(0.05, 0.06, 0.09, 0.98)
        f:SetBackdropBorderColor(LILAC[1], LILAC[2], LILAC[3], 0.85)
        f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f.title = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontNormalLarge")
        f.title:SetPoint("TOPLEFT", 12, -10)
        f.title:SetTextColor(LILAC[1], LILAC[2], LILAC[3])
        f.title:SetText("Экспорт калибровки")
        f.hint = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontHighlightSmall")
        f.hint:SetPoint("TOPLEFT", 12, -32); f.hint:SetPoint("RIGHT", -12, 0); f.hint:SetJustifyH("LEFT")
        f.hint:SetText("Ctrl+A, Ctrl+C. Вставь блоки в |cffffd24aDB\\SpecMap_<эпоха>.lua|r (DF / TWW / MID) по эпохе текущей профы.")
        f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        f.close:SetPoint("TOPRIGHT", 2, 2)
        f.scroll = CreateFrame("ScrollFrame", "HironCraftProfitSpecExportScroll", f, "UIPanelScrollFrameTemplate")
        f.scroll:SetPoint("TOPLEFT", 12, -54)
        f.scroll:SetPoint("BOTTOMRIGHT", -32, 12)
        f.edit = CreateFrame("EditBox", nil, f.scroll)
        f.edit:SetMultiLine(true)
        f.edit:SetFontObject("HironCraftProfit_ChatFontNormal")
        f.edit:SetWidth(500)
        f.edit:SetAutoFocus(false)
        f.edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        f.scroll:SetScrollChild(f.edit)
        CE._exportUI = f
    end
    local str, total = CE:SpecExportString()
    f.edit:SetText(str)
    f.title:SetText(string.format("Экспорт калибровки (%d рецептов)", total or 0))
    f:Show()
    f.edit:SetFocus()
    f.edit:HighlightText()
end

function CE:SpecAutoTick(retries, gen)
    if not self._autoOn then return end
    if gen and gen ~= self._autoGen then return end
    local sl = self:ResolveSpecSkillLine()
    if not sl then return end
    self:SpecSnapshot()
    local pending, reason = self:SpecDetectChange(sl)
    local db = HironCraftProfit_DB.specCal and HironCraftProfit_DB.specCal[sl]
    local f = self._calUI
    if pending and #pending.recipes > 0 then
        local cdb = self:SpecCalDB(sl)
        local n = 0
        for _, rec in ipairs(pending.recipes) do
            cdb.learned[rec.rid] = cdb.learned[rec.rid] or {}
            if not cdb.learned[rec.rid][pending.node] then n = n + 1 end
            cdb.learned[rec.rid][pending.node] = rec.stat
        end
        self._autoCount = (self._autoCount or 0) + 1
        print(string.format("|cff55ff55PH Авто #%d:|r '%s' > %d рец. (нов. %d)", self._autoCount, pending.name or "?", #pending.recipes, n))
        if f and f:IsShown() then
            f.nodeLabel:SetText(string.format("|cff55ff55Авто #%d: '%s' > %d рец. (нов. %d)|r", self._autoCount, pending.name or "?", #pending.recipes, n))
            if f._populate then f._populate({}) end
            if f._updateStatus then f._updateStatus() end
        end
        local E = _G.HironCraftProfitRecipeListEnv
        if E and E.M then E.M._talentCache = nil end
    elseif pending then
        if db and #db.snaps >= 2 then table.remove(db.snaps) end
        if (retries or 0) < 6 then
            C_Timer.After(0.6, function() CE:SpecAutoTick((retries or 0) + 1, gen) end)
        else
            print("|cffff8844PH Авто:|r '" .. (pending.name or "?") .. "': статы не подтянулись, сделай узел вручную кнопкой «Снимок».")
        end
    else
        if db and #db.snaps >= 2 then table.remove(db.snaps) end
    end
end

function CE:SpecAutoStart()
    self._autoOn = true
    self._autoCount = 0
    self._autoGen = 0
    if not self._autoFrame then
        local fr = CreateFrame("Frame")
        fr:SetScript("OnEvent", function()
            if not CE._autoOn then return end
            CE._autoGen = (CE._autoGen or 0) + 1
            local myGen = CE._autoGen
            C_Timer.After(0.8, function()
                if CE._autoOn and CE._autoGen == myGen then CE:SpecAutoTick(0, myGen) end
            end)
        end)
        self._autoFrame = fr
    end
    for _, ev in ipairs({ "TRAIT_CONFIG_UPDATED", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "TRAIT_NODE_CHANGED" }) do
        pcall(self._autoFrame.RegisterEvent, self._autoFrame, ev)
    end
    local slb, nrec = self:SpecSnapshot()
    print(string.format("|cff55ddffPH Авто ВКЛ|r (проф %s, база %s рец.). Трать очки по одному, помедленнее.", tostring(slb), tostring(nrec)))
end

function CE:SpecAutoStop()
    self._autoOn = false
    if self._autoFrame then self._autoFrame:UnregisterAllEvents() end
end

function CE:SpecCalUI()
    local f = CE._calUI
    if f then return f end
    f = CreateFrame("Frame", "HironCraftProfitSpecCalUI", UIParent, "BackdropTemplate")
    f:SetSize(380, 460)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    f:SetBackdropColor(0.06, 0.07, 0.11, 0.97)
    f:SetBackdropBorderColor(LILAC[1], LILAC[2], LILAC[3], 0.85)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    f.title = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 12, -10)
    f.title:SetTextColor(LILAC[1], LILAC[2], LILAC[3])
    f.title:SetText("Калибровка спеков")

    f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.close:SetPoint("TOPRIGHT", 2, 2)

    f.status = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontHighlightSmall")
    f.status:SetPoint("TOPLEFT", 12, -36)
    f.status:SetPoint("RIGHT", -12, 0)
    f.status:SetJustifyH("LEFT")

    f.snapBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.snapBtn:SetSize(160, 26)
    f.snapBtn:SetPoint("TOPLEFT", 12, -58)
    f.snapBtn:SetText("Снимок / поймать узел")

    f.resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.resetBtn:SetSize(80, 26)
    f.resetBtn:SetPoint("LEFT", f.snapBtn, "RIGHT", 8, 0)
    f.resetBtn:SetText("Сброс")

    f.exportBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.exportBtn:SetSize(90, 26)
    f.exportBtn:SetPoint("LEFT", f.resetBtn, "RIGHT", 8, 0)
    f.exportBtn:SetText("Экспорт")
    f.exportBtn:SetScript("OnClick", function() CE:SpecShowExport() end)

    f.nodeLabel = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontHighlight")
    f.nodeLabel:SetPoint("TOPLEFT", 12, -92)
    f.nodeLabel:SetPoint("RIGHT", -12, 0)
    f.nodeLabel:SetJustifyH("LEFT")
    f.nodeLabel:SetText("Жми «Снимок» на вкладке Рецепты, потом применяй узлы по одному.")

    f.allBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.allBtn:SetSize(80, 20)
    f.allBtn:SetPoint("TOPLEFT", 12, -112)
    f.allBtn:SetText("Все")
    f.noneBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.noneBtn:SetSize(80, 20)
    f.noneBtn:SetPoint("LEFT", f.allBtn, "RIGHT", 6, 0)
    f.noneBtn:SetText("Снять все")

    f.manualBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.manualBtn:SetSize(120, 20)
    f.manualBtn:SetPoint("LEFT", f.noneBtn, "RIGHT", 6, 0)
    f.manualBtn:SetText("Ручная правка")
    f.manualBtn:SetScript("OnClick", function()
        local m = CE:SpecManualUI()
        if m.Refresh then m:Refresh() end
        m:Show()
    end)

    f.autoCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    f.autoCheck:SetSize(22, 22)
    f.autoCheck:SetPoint("LEFT", f.manualBtn, "RIGHT", 6, 0)
    f.autoCheck.text = f.autoCheck:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontHighlightSmall")
    f.autoCheck.text:SetPoint("LEFT", f.autoCheck, "RIGHT", 2, 0)
    f.autoCheck.text:SetText("Авто")
    f.autoCheck:SetScript("OnClick", function(self)
        if self:GetChecked() then
            CE:SpecAutoStart()
            f.nodeLabel:SetText("|cff55ddffАвто ВКЛ.|r База снята. Трать очки по одному — ловлю сам. Жди зелёное подтверждение перед следующим.")
        else
            CE:SpecAutoStop()
            f.nodeLabel:SetText("Авто выкл.")
        end
        if f._updateStatus then f._updateStatus() end
    end)
    f:HookScript("OnShow", function() if f.autoCheck then f.autoCheck:SetChecked(CE._autoOn or false) end end)

    f.scroll = CreateFrame("ScrollFrame", "HironCraftProfitSpecCalScroll", f, "UIPanelScrollFrameTemplate")
    f.scroll:SetPoint("TOPLEFT", 12, -136)
    f.scroll:SetPoint("BOTTOMRIGHT", -30, 46)
    f.content = CreateFrame("Frame", nil, f.scroll)
    f.content:SetSize(320, 1)
    f.scroll:SetScrollChild(f.content)
    f.rows = {}

    f.saveBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.saveBtn:SetSize(356, 26)
    f.saveBtn:SetPoint("BOTTOMLEFT", 12, 12)
    f.saveBtn:SetText("Сохранить")

    local function UpdateStatus()
        local sl = CE:ResolveSpecSkillLine()
        local db = sl and HironCraftProfit_DB.specCal and HironCraftProfit_DB.specCal[sl]
        local free = "-"
        if sl and C_ProfSpecs.GetCurrencyInfoForSkillLine then
            local ci = pc(C_ProfSpecs.GetCurrencyInfoForSkillLine, sl)
            if ci then free = tostring(ci.numAvailable) end
        end
        f.status:SetText(string.format("Профа: |cffffffff%s|r | снимков: %d | рецептов в базе: |cff88dd99%d|r | свободно: %s",
            tostring(sl), db and #db.snaps or 0, db and CountKeys(db.learned) or 0, free))
    end

    local function PopulateRows(recipes)
        for _, r in ipairs(f.rows) do r:Hide() end
        for i, rec in ipairs(recipes) do
            local r = f.rows[i]
            if not r then
                r = CreateFrame("CheckButton", nil, f.content, "UICheckButtonTemplate")
                r:SetSize(20, 20)
                r:SetPoint("TOPLEFT", 0, -(i - 1) * 22)
                r.label = r:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontHighlightSmall")
                r.label:SetPoint("LEFT", r, "RIGHT", 2, 0)
                r.label:SetWidth(280); r.label:SetJustifyH("LEFT")
                r.hover = CreateFrame("Frame", nil, r)
                r.hover:SetPoint("TOPLEFT", r.label, "TOPLEFT", 0, 2)
                r.hover:SetPoint("BOTTOMRIGHT", r.label, "BOTTOMRIGHT", 0, -2)
                r.hover:EnableMouse(true)
                r.hover:SetScript("OnEnter", function(self) ShowDeltaTooltip(self, r._rec) end)
                r.hover:SetScript("OnLeave", function() if PT.Tooltip then PT.Tooltip:Clear() else GameTooltip:Hide() end end)
                r.hover:SetScript("OnMouseUp", function() r:Click() end)
                f.rows[i] = r
            end
            r:SetChecked(true)
            r._rec = rec
            r.label:SetText(string.format("%s |cff666666[%s]|r", rec.name or "?", rec.stat or ""))
            r:Show()
        end
        f.content:SetHeight(math.max(1, #recipes * 22))
    end
    f._populate = PopulateRows

    f.snapBtn:SetScript("OnClick", function()
        local sl, nrec = CE:SpecSnapshot()
        if not sl then f.nodeLabel:SetText("|cffff5555" .. tostring(nrec) .. "|r"); return end
        local pending, reason = CE:SpecDetectChange(sl)
        if pending then
            f._pending = pending
            f.nodeLabel:SetText(string.format("Узел: |cffffd24a%s|r |cff888888[%s]|r | рецептов: |cff88dd99%d|r",
                pending.name or "?", pending.stat or "?", #pending.recipes))
            PopulateRows(pending.recipes)
            f.saveBtn:SetText(string.format("Сохранить (%d)", #pending.recipes))
        else
            f._pending = nil
            PopulateRows({})
            f.nodeLabel:SetText("|cffffd24aСнимок сделан (" .. nrec .. " рец.).|r " .. (reason or ""))
            f.saveBtn:SetText("Сохранить")
        end
        UpdateStatus()
    end)

    f.resetBtn:SetScript("OnClick", function()
        local sl = CE:ResolveSpecSkillLine()
        if sl and HironCraftProfit_DB.specCal then HironCraftProfit_DB.specCal[sl] = nil end
        f._pending = nil; PopulateRows({}); f.nodeLabel:SetText("Сброшено. Жми «Снимок» для базы.")
        UpdateStatus()
    end)

    f.allBtn:SetScript("OnClick", function() for _, r in ipairs(f.rows) do if r:IsShown() then r:SetChecked(true) end end end)
    f.noneBtn:SetScript("OnClick", function() for _, r in ipairs(f.rows) do if r:IsShown() then r:SetChecked(false) end end end)

    f.saveBtn:SetScript("OnClick", function()
        local p = f._pending
        if not p then f.nodeLabel:SetText("|cffff8844Нет пойманного узла.|r"); return end
        local sl = CE:ResolveSpecSkillLine()
        local db = CE:SpecCalDB(sl)
        local n = 0
        for _, r in ipairs(f.rows) do
            if r:IsShown() and r:GetChecked() and r._rec then
                local rid = r._rec.rid
                db.learned[rid] = db.learned[rid] or {}
                if not db.learned[rid][p.node] then n = n + 1 end
                db.learned[rid][p.node] = r._rec.stat
            end
        end
        f.nodeLabel:SetText(string.format("|cff55ff55Записано: '%s' > %d рецептов.|r Применяй следующий узел.", p.name or "?", n))
        f._pending = nil; PopulateRows({}); f.saveBtn:SetText("Сохранить")
        UpdateStatus()
        local E = _G.HironCraftProfitRecipeListEnv
        if E and E.M then E.M._talentCache = nil; if E.M.RefreshSimulatorPanel then pcall(function() E.M:RefreshSimulatorPanel() end) end end
    end)

    f._updateStatus = UpdateStatus
    CE._calUI = f
    return f
end

function CE:CurrentRecipeIDName()
    local rid = tonumber(pc(C_TradeSkillUI.GetCurrentRecipeID))
    if not rid then
        local form = ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.SchematicForm
        if form and form.GetRecipeInfo then
            local ri = pc(form.GetRecipeInfo, form)
            if type(ri) == "table" then rid = tonumber(ri.recipeID) end
        end
    end
    if not rid then return nil end
    local ri = pc(C_TradeSkillUI.GetRecipeInfo, rid)
    return rid, (type(ri) == "table" and ri.name) or ("рецепт " .. rid)
end

function CE:SpecNodeList()
    local sl = self:ResolveSpecSkillLine()
    local configID = sl and pc(C_ProfSpecs.GetConfigIDForSkillLine, sl)
    if not configID then return {}, sl end
    local out, seen = {}, {}
    for _, tabID in ipairs(pc(C_ProfSpecs.GetSpecTabIDsForSkillLine, sl) or {}) do
        local stack = { pc(C_ProfSpecs.GetRootPathForTab, tabID) }
        while #stack > 0 do
            local pid = table.remove(stack)
            if pid and not seen[pid] then
                seen[pid] = true
                out[#out + 1] = { node = pid, name = self:SpecNodeName(pid, configID), stat = self:SpecPathStat(pid, configID) }
                for _, k in ipairs(pc(C_ProfSpecs.GetChildrenForPath, pid, configID) or {}) do stack[#stack + 1] = k end
            end
        end
    end
    table.sort(out, function(a, b) return (a.name or "") < (b.name or "") end)
    return out, sl, configID
end

local MANUAL_STATS = {
    { key = "skill",           text = "Навык" },
    { key = "multicraft",      text = "Мульти" },
    { key = "resourcefulness", text = "Находч" },
    { key = "ingenuity",       text = "Изобрет" },
    { key = "quality",         text = "Качество" },
}

function CE:SpecManualUI()
    local f = CE._manualUI
    if f then return f end
    f = CreateFrame("Frame", "HironCraftProfitSpecManualUI", UIParent, "BackdropTemplate")
    f:SetSize(440, 500)
    f:SetPoint("CENTER", 170, 0)
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    f:SetBackdropColor(0.06, 0.07, 0.11, 0.97)
    f:SetBackdropBorderColor(LILAC[1], LILAC[2], LILAC[3], 0.85)
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    f.title = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 12, -10)
    f.title:SetTextColor(LILAC[1], LILAC[2], LILAC[3])
    f.title:SetText("Ручная привязка узла к рецепту")

    f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.close:SetPoint("TOPRIGHT", 2, 2)

    f.recipeLabel = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontHighlight")
    f.recipeLabel:SetPoint("TOPLEFT", 12, -42)
    f.recipeLabel:SetPoint("RIGHT", -12, 0)
    f.recipeLabel:SetJustifyH("LEFT")

    f.curBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.curBtn:SetSize(170, 22)
    f.curBtn:SetPoint("TOPLEFT", 12, -64)
    f.curBtn:SetText("Взять текущий рецепт")
    f.curBtn:SetScript("OnClick", function()
        local rid, name = CE:CurrentRecipeIDName()
        if rid then f._recipeID = rid; f._recipeName = name; f.recipeBox:SetText(tostring(rid)); f:Refresh()
        else f.status:SetText("|cffff8844Открой рецепт в окне профессии|r") end
    end)

    f.recipeBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    f.recipeBox:SetSize(90, 22)
    f.recipeBox:SetPoint("LEFT", f.curBtn, "RIGHT", 16, 0)
    f.recipeBox:SetAutoFocus(false)
    f.recipeBox:SetNumeric(true)
    f.recipeBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    f.recipeBox:SetScript("OnEditFocusLost", function(self)
        local rid = tonumber(self:GetText())
        if rid then
            f._recipeID = rid
            local ri = pc(C_TradeSkillUI.GetRecipeInfo, rid)
            f._recipeName = (type(ri) == "table" and ri.name) or ("рецепт " .. rid)
            f:Refresh()
        end
    end)
    f.recipeBoxLabel = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontDisableSmall")
    f.recipeBoxLabel:SetPoint("LEFT", f.recipeBox, "RIGHT", 6, 0)
    f.recipeBoxLabel:SetText("recipeID")

    f.nodeLabel = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontHighlightSmall")
    f.nodeLabel:SetPoint("TOPLEFT", 14, -94)
    f.nodeLabel:SetText("Узел:")
    f.nodeDD = CreateFrame("Frame", "HironCraftProfitSpecManualNodeDD", f, "UIDropDownMenuTemplate")
    f.nodeDD:SetPoint("TOPLEFT", 0, -106)
    UIDropDownMenu_SetWidth(f.nodeDD, 330)
    UIDropDownMenu_SetText(f.nodeDD, "— выбери узел —")
    UIDropDownMenu_Initialize(f.nodeDD, function(_, level)
        for _, nd in ipairs(CE:SpecNodeList()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = nd.name .. (nd.stat and ("  |cff888888[" .. nd.stat .. "]|r") or "")
            info.checked = (f._node == nd.node)
            info.func = function()
                f._node, f._nodeName = nd.node, nd.name
                if nd.stat then f._stat = nd.stat end
                UIDropDownMenu_SetText(f.nodeDD, nd.name)
                f:Refresh()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    f.statLabel = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontHighlightSmall")
    f.statLabel:SetPoint("TOPLEFT", 14, -138)
    f.statLabel:SetText("Стат:")
    f.statBtns = {}
    local prev
    for _, st in ipairs(MANUAL_STATS) do
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(80, 20)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 3, 0) else b:SetPoint("TOPLEFT", 12, -152) end
        b:SetText(st.text)
        b._stat = st.key
        b:SetScript("OnClick", function() f._stat = st.key; f:Refresh() end)
        f.statBtns[#f.statBtns + 1] = b
        prev = b
    end

    f.bindBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.bindBtn:SetSize(416, 24)
    f.bindBtn:SetPoint("TOPLEFT", 12, -182)
    f.bindBtn:SetText("Привязать узел к рецепту")
    f.bindBtn:SetScript("OnClick", function()
        if not f._recipeID then f.status:SetText("|cffff5555Нет рецепта|r"); return end
        if not f._node then f.status:SetText("|cffff5555Не выбран узел|r"); return end
        if not f._stat then f.status:SetText("|cffff5555Не выбран стат|r"); return end
        local sl = CE:ResolveSpecSkillLine()
        if not sl then f.status:SetText("|cffff5555Профа не открыта|r"); return end
        local db = CE:SpecCalDB(sl)
        db.learned[f._recipeID] = db.learned[f._recipeID] or {}
        db.learned[f._recipeID][f._node] = f._stat
        f:Refresh()
        local E = _G.HironCraftProfitRecipeListEnv
        if E and E.M then E.M._talentCache = nil; if E.M.RefreshSimulatorPanel then pcall(function() E.M:RefreshSimulatorPanel() end) end end
    end)

    f.listHeader = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontHighlightSmall")
    f.listHeader:SetPoint("TOPLEFT", 12, -214)
    f.listHeader:SetText("Привязки этого рецепта:")

    f.scroll = CreateFrame("ScrollFrame", "HironCraftProfitSpecManualScroll", f, "UIPanelScrollFrameTemplate")
    f.scroll:SetPoint("TOPLEFT", 12, -232)
    f.scroll:SetPoint("BOTTOMRIGHT", -30, 36)
    f.content = CreateFrame("Frame", nil, f.scroll)
    f.content:SetSize(390, 1)
    f.scroll:SetScrollChild(f.content)
    f.rows = {}

    f.status = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontDisableSmall")
    f.status:SetPoint("BOTTOMLEFT", 12, 12)
    f.status:SetPoint("RIGHT", -12, 0)
    f.status:SetJustifyH("LEFT")

    function f:Refresh()
        local sl = CE:ResolveSpecSkillLine()
        local configID = sl and pc(C_ProfSpecs.GetConfigIDForSkillLine, sl)

        if not f._recipeID then
            local rid, name = CE:CurrentRecipeIDName()
            if rid then f._recipeID, f._recipeName = rid, name; f.recipeBox:SetText(tostring(rid)) end
        end

        if f._recipeID then
            f.recipeLabel:SetText(string.format("Рецепт: |cffffffff%s|r |cff888888[%d]|r", f._recipeName or "?", f._recipeID))
        else
            f.recipeLabel:SetText("Рецепт: |cffff8844не выбран|r — открой рецепт в профе и жми «Взять текущий»")
        end

        for _, b in ipairs(f.statBtns) do
            if b._stat == f._stat then b:LockHighlight() else b:UnlockHighlight() end
        end

        for _, r in ipairs(f.rows) do r:Hide() end
        local db = sl and HironCraftProfit_DB.specCal and HironCraftProfit_DB.specCal[sl]
        local live = db and db.learned and f._recipeID and db.learned[f._recipeID]
        local bundled = PT.SpecMap and sl and PT.SpecMap[sl] and f._recipeID and PT.SpecMap[sl][f._recipeID]
        local items = {}
        if live then for node, stat in pairs(live) do items[#items + 1] = { node = node, stat = stat, live = true } end end
        if bundled then for node, stat in pairs(bundled) do
            if not (live and live[node]) then items[#items + 1] = { node = node, stat = stat, live = false } end
        end end
        table.sort(items, function(a, b) return (CE:SpecNodeName(a.node, configID) or "") < (CE:SpecNodeName(b.node, configID) or "") end)

        for i, it in ipairs(items) do
            local r = f.rows[i]
            if not r then
                r = CreateFrame("Frame", nil, f.content)
                r:SetSize(380, 20)
                r:SetPoint("TOPLEFT", 0, -(i - 1) * 22)
                r.text = r:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontHighlightSmall")
                r.text:SetPoint("LEFT", 0, 0); r.text:SetWidth(330); r.text:SetJustifyH("LEFT")
                r.del = CreateFrame("Button", nil, r, "UIPanelCloseButton")
                r.del:SetSize(22, 22); r.del:SetPoint("RIGHT", 0, 0)
                f.rows[i] = r
            end
            local nm = CE:SpecNodeName(it.node, configID)
            r.text:SetText(string.format("%s |cff888888[%s]|r%s", nm, it.stat or "?", it.live and "" or " |cff888888(из файла)|r"))
            r.del:SetShown(it.live == true)
            r.del:SetScript("OnClick", function()
                if it.live and db and db.learned[f._recipeID] then
                    db.learned[f._recipeID][it.node] = nil
                    if not next(db.learned[f._recipeID]) then db.learned[f._recipeID] = nil end
                    f:Refresh()
                    local E = _G.HironCraftProfitRecipeListEnv
                    if E and E.M then E.M._talentCache = nil; if E.M.RefreshSimulatorPanel then pcall(function() E.M:RefreshSimulatorPanel() end) end end
                end
            end)
            r:Show()
        end
        f.content:SetHeight(math.max(1, #items * 22))

        local cnt = 0
        if live then for _ in pairs(live) do cnt = cnt + 1 end end
        f.status:SetText(string.format("Профа: |cffffffff%s|r | своих привязок у рецепта: |cff88dd99%d|r", tostring(sl), cnt))
    end

    CE._manualUI = f
    return f
end

SLASH_PHCECAL1 = "/phcecal"
SlashCmdList["PHCECAL"] = function()
    local f = CE:SpecCalUI()
    if f._updateStatus then f._updateStatus() end
    f:Show()
end

SLASH_PHCEMANUAL1 = "/phceedit"
SlashCmdList["PHCEMANUAL"] = function()
    local f = CE:SpecManualUI()
    if f.Refresh then f:Refresh() end
    f:Show()
end

SLASH_PHCEWIPE1 = "/phcewipe"
SlashCmdList["PHCEWIPE"] = function()
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    local n = 0
    if type(HironCraftProfit_DB.specCal) == "table" then
        for _ in pairs(HironCraftProfit_DB.specCal) do n = n + 1 end
    end
    HironCraftProfit_DB.specCal = nil
    print("|cffb19cd9HironCraft|r: калибровка сброшена (профессий: " .. n .. "). Жми /reload для сохранения на диск.")
end

SLASH_PHCEEV1 = "/phceev"
SlashCmdList["PHCEEV"] = function()
    if not CE._evSniffer then CE._evSniffer = CreateFrame("Frame") end
    local fr = CE._evSniffer
    if fr._on then
        fr:UnregisterAllEvents(); fr._on = false
        print("|cffb19cd9PH|r снифер ВЫКЛ.")
        return
    end
    fr._on = true
    fr:RegisterAllEvents()
    fr:SetScript("OnEvent", function(_, ev, a1, a2)
        local up = ev:upper()
        if up:find("TRAIT") or up:find("SPEC") or up:find("SKILL") or up:find("TRADE")
            or up:find("CRAFT") or up:find("KNOWLEDGE") or up:find("CONFIG")
            or up:find("CURRENCY") or up:find("PROFESSION") or up:find("ARTISAN") then
            print("|cff55ddff" .. ev .. "|r  " .. tostring(a1) .. "  " .. tostring(a2))
        end
    end)
    print("|cffb19cd9PH|r снифер ВКЛ. Потрать ОДНО очко спеца, посмотри что напечатает, потом /phceev ещё раз чтобы выключить.")
end

SLASH_PHMEM1 = "/phmem"
SlashCmdList["PHMEM"] = function()
    collectgarbage("collect")
    UpdateAddOnMemoryUsage()
    local getNum = (C_AddOns and C_AddOns.GetNumAddOns) or GetNumAddOns
    local getInfo = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo
    local t = {}
    for i = 1, getNum() do
        local name = getInfo(i)
        local mem = GetAddOnMemoryUsage(i)
        if mem and mem > 0 then t[#t + 1] = { name, mem } end
    end
    table.sort(t, function(a, b) return a[2] > b[2] end)
    print("|cffb19cd9PH память после GC:|r")
    for i = 1, math.min(12, #t) do
        print(string.format("  %s — %.1f МБ", tostring(t[i][1]), t[i][2] / 1024))
    end
end
