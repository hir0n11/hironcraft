local PT = HironCraftProfit
if not PT then return end
PT.CraftingOrders = PT.CraftingOrders or {}
local CO = PT.CraftingOrders

local CL = {}
CO.CustomList = CL

local FONT = PT.FONT or STANDARD_TEXT_FONT
local BORDER = { 0.694, 0.612, 0.851 }

local function IsFantasy()
    return PT.IsFantasyDesign and PT:IsFantasyDesign()
end


CL.ROW_H = 56
CL.ICON_SIZE = 48
CL.SMALL_ICON = 22
CL.GAP = 6

CL.ROW_H_COMPACT = 30
CL.ICON_COMPACT = 24

local QueueRefresh

function CL:IsCompact()
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB.craftingOrders = HironCraftProfit_DB.craftingOrders or {}
    return HironCraftProfit_DB.craftingOrders.customListCompact ~= false
end

function CL:SetCompact(value)
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB.craftingOrders = HironCraftProfit_DB.craftingOrders or {}
    HironCraftProfit_DB.craftingOrders.customListCompact = (value == true)
end

function CL:RowHeight()
    return self:IsCompact() and self.ROW_H_COMPACT or self.ROW_H
end

CL._stripeTex     = nil
CL._stripeIsAtlas = false
CL._stripeColor   = { 0.30, 1.00, 0.30, 0.35 }

local function StripeDB()
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB.craftingOrders = HironCraftProfit_DB.craftingOrders or {}
    return HironCraftProfit_DB.craftingOrders
end

function CL:LoadStripeConfig()
    local db = StripeDB()
    if not db._stripeForcedOff then
        db._stripeForcedOff = true
        db.doneStripe = false
        self._stripeTex = nil
        return
    end
    if db.doneStripe ~= nil then
        local s = db.doneStripe
        if s == false then
            self._stripeTex = nil
        else
            self._stripeTex     = s.tex or self._stripeTex
            self._stripeIsAtlas = s.isAtlas == true
            self._stripeColor   = s.color or self._stripeColor
        end
    end
end

function CL:SaveStripeConfig()
    local db = StripeDB()
    if not self._stripeTex then
        db.doneStripe = false
    else
        db.doneStripe = {
            tex     = self._stripeTex,
            isAtlas = self._stripeIsAtlas,
            color   = self._stripeColor,
        }
    end
end

function CL:ApplyStripe(row)
    local t = row and row.doneStripe
    if not t then return end
    if not self._stripeTex then
        t:Hide()
        return
    end
    local c = self._stripeColor or { 0.30, 1.00, 0.30, 0.16 }
    if self._stripeIsAtlas then
        t:SetTexture(nil)
        pcall(t.SetAtlas, t, self._stripeTex, false)
        t:SetTexCoord(0, 1, 0, 1)
        t:SetHorizTile(false)
        t:SetVertTile(false)
    else
        pcall(t.SetTexture, t, self._stripeTex, "REPEAT", "REPEAT")
        t:SetHorizTile(true)
        t:SetVertTile(true)
    end
    t:SetVertexColor(c[1], c[2], c[3], c[4] or 0.16)
    t:SetBlendMode("BLEND")
end

function CL:ReapplyStripeToVisibleRows()
    local pf = CO.activePageFrame or (ProfessionsFrame and ProfessionsFrame.OrdersPage)
    local container = pf and pf.ahuiCustomList
    if not container or not container.rows then return end
    for _, row in ipairs(container.rows) do
        self:ApplyStripe(row)
        if row.doneStripe and row.doneCheck and row.doneCheck:IsShown() and self._stripeTex then
            row.doneStripe:Show()
        elseif row.doneStripe then
            row.doneStripe:Hide()
        end
    end
end

CL._stripePresets = {
    { tex = "Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\media\\stripe.tga",  atlas = false },
    { tex = "Interface\\PetBattles\\DeadPetTexture",       atlas = false },
    { tex = "Interface\\Buttons\\WHITE8x8",                atlas = false },
    { tex = "Interface\\GLUES\\Models\\UI_MainMenu\\stipple", atlas = false },
    { tex = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",      atlas = false },
    { tex = "Professions-Background-DragDrop",             atlas = true  },
    { tex = "BonusLoot-IconCover",                         atlas = true  },
    { tex = "QuestObjectiveProgressBar-Fill",             atlas = true  },
    { tex = "GarrMission_RewardsBanner-Tile",             atlas = true  },
    { tex = "talenttree-background-tile",                  atlas = true  },
}

local function ApplyStripePreset(step)
    local list = CL._stripePresets
    local n = #list
    local idx = (CL._stripePresetIdx or 0) + step
    if idx < 1 then idx = n elseif idx > n then idx = 1 end
    CL._stripePresetIdx = idx
    local p = list[idx]
    CL._stripeTex = p.tex
    CL._stripeIsAtlas = p.atlas == true
    return idx, p
end

SLASH_PHSTRIPE1 = "/phstripe"
SlashCmdList["PHSTRIPE"] = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%S+)%s*(.*)$")
    cmd = cmd and cmd:lower() or ""
    local pre = "|cffb19cd9HironCraft|r штриховка: "
    if cmd == "" then
        print(pre .. "тек. = " .. (CL._stripeTex or "выкл") .. (CL._stripeIsAtlas and " (atlas)" or " (file)"))
        print("  |cffaaaaaa/phstripe next|r — следующий из готовых, |cffaaaaaa/phstripe prev|r — предыдущий")
        print("  |cffaaaaaa/phstripe <путь_текстуры>|r — файл (напр. Interface\\PetBattles\\DeadPetTexture)")
        print("  |cffaaaaaa/phstripe atlas <имя_атласа>|r — атлас")
        print("  |cffaaaaaa/phstripe alpha 0.0-1.0|r — прозрачность")
        print("  |cffaaaaaa/phstripe color r g b|r — цвет (0-1)")
        print("  |cffaaaaaa/phstripe off|r — выключить")
        return
    elseif cmd == "next" or cmd == "prev" then
        local idx, p = ApplyStripePreset(cmd == "next" and 1 or -1)
        CL:SaveStripeConfig()
        CL:ReapplyStripeToVisibleRows()
        print(pre .. ("вариант %d/%d → %s%s"):format(idx, #CL._stripePresets, p.tex, p.atlas and " (atlas)" or " (file)"))
        return
    elseif cmd == "off" then
        CL._stripeTex = nil
    elseif cmd == "atlas" then
        if rest == "" then print(pre .. "укажи имя атласа") return end
        CL._stripeTex = rest
        CL._stripeIsAtlas = true
    elseif cmd == "alpha" then
        local a = tonumber(rest)
        if not a then print(pre .. "alpha 0.0-1.0") return end
        CL._stripeColor = CL._stripeColor or { 0.30, 1.00, 0.30, 0.16 }
        CL._stripeColor[4] = math.max(0, math.min(1, a))
    elseif cmd == "color" then
        local r, g, b = rest:match("^([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)")
        r, g, b = tonumber(r), tonumber(g), tonumber(b)
        if not (r and g and b) then print(pre .. "color r g b (0-1)") return end
        local a = (CL._stripeColor and CL._stripeColor[4]) or 0.16
        CL._stripeColor = { r, g, b, a }
    else
        CL._stripeTex = msg
        CL._stripeIsAtlas = false
    end
    CL:SaveStripeConfig()
    CL:ReapplyStripeToVisibleRows()
    print(pre .. (CL._stripeTex and ("вкл → " .. CL._stripeTex) or "выкл"))
end

local function L(key, fallback)
    local L_ = PT.L or {}
    return L_[key] or fallback or key
end

local NAME_X = 96
local COLS = {
    name   = { x = NAME_X, w = 220, label = L("COA_HDR_NAME",   "Название") },
    conc   = { x = 340, w = 50,  label = L("COA_HDR_CONC",   "Конц.") },
    cost   = { x = 420, w = 75,  label = L("COA_HDR_COST",   "Стоимость") },
    reward = { x = 510, w = 100, label = L("COA_HDR_REWARD", "Награда") },
    profit = { x = 600, w = 75,  label = L("COA_HDR_PROFIT", "Профит") },
    action = { x = 690, w = 82,  label = L("COA_HDR_ACTION", "Действие") },
}

local COLS_COMPACT = {
    name     = { x = 60,  w = 170, label = L("COA_HDR_NAME",     "Название"), sort = "name" },
    conc     = { x = 320, w = 50,  label = L("COA_HDR_CONC",     "Конц.") },
    reward   = { x = 380, w = 100, label = L("COA_HDR_REWARD",   "Награда"), sort = "reward" },
    profit   = { x = 480, w = 65,  label = L("COA_HDR_PROFIT",   "Профит"), sort = "profit" },
    reagents = { x = 565, w = 75,  label = L("COA_HDR_REAGENTS", "Реагенты") },
    action   = { x = 690, w = 82,  label = L("COA_HDR_ACTION",   "Действие") },
}

function CL:ActiveCols()
    return self:IsCompact() and COLS_COMPACT or COLS
end

local function MakeBackdrop(frame)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        frame:SetBackdropColor(0, 0, 0, 0.92)
        frame:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], 0.6)
    end
end

local function MakeText(parent, size, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, size or 12, "")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetTextColor(0.95, 0.95, 0.95)
    return fs
end

function CL:CreateHeader(parent)
    local h = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    h:SetPoint("TOPLEFT", 0, 0)
    h:SetPoint("TOPRIGHT", 0, 0)
    h:SetHeight(26)
    h:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    if IsFantasy() then
        h:SetBackdropColor(0, 0, 0, 0)
        h.bgAtlas = h:CreateTexture(nil, "BACKGROUND")
        h.bgAtlas:SetAtlas("Professions-Specializations-Background-Footer", false)
        h.bgAtlas:SetAllPoints()
        h:SetBackdropBorderColor(0, 0, 0, 1)
    else
        h:SetBackdropColor(0.08, 0.08, 0.10, 0.95)
        h:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], 0.6)
    end

    local toggle = CreateFrame("Button", nil, h)
    toggle:SetSize(20, 20)
    toggle:SetPoint("LEFT", h, "LEFT", 6, 0)
    toggle.tex = toggle:CreateTexture(nil, "ARTWORK")
    toggle.tex:SetAllPoints()

    toggle.caption = MakeText(toggle, 10, "LEFT")
    toggle.caption:SetPoint("LEFT", toggle, "RIGHT", 3, 0)
    toggle.caption:SetText(L("COA_CL_VIEW_CAPTION", "view"))
    toggle.caption:SetTextColor(0.70, 0.65, 0.85)

    local function RefreshToggleIcon()
        if CL:IsCompact() then
            toggle.tex:SetAtlas("azsharawards-state2-zone4")
        else
            toggle.tex:SetAtlas("azsharawards-state2-zone4-cap")
        end
    end
    RefreshToggleIcon()
    toggle:SetScript("OnEnter", function(self)
        self.tex:SetVertexColor(1.3, 1.3, 1.3)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L("COA_CL_VIEW_TITLE", "Display mode"), 1, 0.82, 0.35)
        GameTooltip:AddLine(CL:IsCompact() and L("COA_CL_VIEW_COMPACT_NOW", "Now: compact. Click — normal.") or L("COA_CL_VIEW_NORMAL_NOW", "Now: normal. Click — compact."), 0.85, 0.85, 0.85)
        GameTooltip:Show()
    end)
    toggle:SetScript("OnLeave", function(self)
        self.tex:SetVertexColor(1, 1, 1)
        GameTooltip:Hide()
    end)
    toggle:SetScript("OnClick", function()
        CL:SetCompact(not CL:IsCompact())
        RefreshToggleIcon()
        CL:RebuildHeader(h)
        if QueueRefresh then QueueRefresh() end
    end)
    h.toggle = toggle

    h.cols = {}
    CL:RebuildHeader(h)

    return h
end

function CL:RebuildHeader(h)
    if not h then return end
    h.cols = h.cols or {}
    for _, btn in pairs(h.cols) do btn:Hide() end

    local active = self:ActiveCols()
    for key, col in pairs(active) do
        local btn = h.cols[key]
        if not btn then
            btn = CreateFrame("Button", nil, h)
            btn._label = MakeText(btn, 11, "LEFT")
            btn._label:SetPoint("LEFT")
            btn._arrow = btn:CreateTexture(nil, "OVERLAY")
            btn._arrow:SetSize(12, 12)
            h.cols[key] = btn
        end
        btn:ClearAllPoints()
        btn:SetPoint("LEFT", h, "LEFT", col.x, 0)
        btn:SetSize(col.w, 24)
        btn._label:SetWidth(col.w)
        btn._label:SetText(col.label)
        btn._label:SetTextColor(0.78, 0.72, 0.95)
        btn._arrow:Hide()

        local sortKey = col.sort or key
        local sortable = (sortKey == "name" or sortKey == "cost" or sortKey == "reward" or sortKey == "profit")

        btn:SetScript("OnEnter", function() btn._label:SetTextColor(1, 0.95, 0.55) end)
        btn:SetScript("OnLeave", function() btn._label:SetTextColor(0.78, 0.72, 0.95) end)
        if sortable then
            btn:SetScript("OnClick", function()
                if CL._sortColumn == sortKey then
                    CL._sortDir = (CL._sortDir == "desc") and "asc" or "desc"
                else
                    CL._sortColumn = sortKey
                    CL._sortDir = "desc"
                end
                if QueueRefresh then QueueRefresh() end
            end)
        else
            btn:SetScript("OnClick", nil)
        end
        btn:Show()
    end
end

local SORT_ARROW_UP   = "housing-floor-arrow-up-pressed"
local SORT_ARROW_DOWN = "housing-floor-arrow-down-pressed"

local function UpdateHeaderArrows(header)
    if not header or not header.cols then return end
    for key, btn in pairs(header.cols) do
        if CL._sortColumn == key then
            btn._arrow:ClearAllPoints()
            btn._arrow:SetPoint("LEFT", btn._label, "LEFT", (btn._label:GetStringWidth() or 0) + 4, 0)
            btn._arrow:SetAtlas("uitools-icon-chevron-down")
            btn._arrow:SetRotation(CL._sortDir == "asc" and math.pi or 0)
            btn._arrow:Show()
        else
            btn._arrow:Hide()
        end
    end
end

function CL:CreateRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(800, self.ROW_H)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0, 0, 0, 0)

    row.hover = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.hover:SetAllPoints()
    row.hover:SetColorTexture(1, 1, 1, 0)

    row.separator = row:CreateTexture(nil, "ARTWORK")
    row.separator:SetPoint("BOTTOMLEFT", 4, 0)
    row.separator:SetPoint("BOTTOMRIGHT", -4, 0)
    row.separator:SetHeight(1)
    row.separator:SetColorTexture(0.30, 0.27, 0.40, 0.40)

    row.checkbox = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.checkbox:SetSize(24, 24)
    row.checkbox:SetPoint("LEFT", row, "LEFT", 6, 0)

    row.iconBtn = CreateFrame("Button", nil, row)
    row.iconBtn:SetSize(self.ICON_SIZE, self.ICON_SIZE)
    row.iconBtn:SetPoint("LEFT", row.checkbox, "RIGHT", 4, 0)

    row.icon = row.iconBtn:CreateTexture(nil, "ARTWORK")
    row.icon:SetAllPoints()
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.qualityBadge = row.iconBtn:CreateTexture(nil, "OVERLAY")
    row.qualityBadge:SetSize(20, 20)
    row.qualityBadge:SetPoint("TOPLEFT", row.iconBtn, "TOPLEFT", -4, 4)
    row.qualityBadge:Hide()

    row.doneStripe = row:CreateTexture(nil, "ARTWORK", nil, 1)
    row.doneStripe:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.doneStripe:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.doneStripe:Hide()
    CL:ApplyStripe(row)

    row.doneCheck = row.iconBtn:CreateTexture(nil, "OVERLAY", nil, 2)
    row.doneCheck:SetSize(28, 28)
    row.doneCheck:SetPoint("CENTER", row.iconBtn, "CENTER", 0, 0)
    row.doneCheck:SetAtlas("common-icon-checkmark")
    row.doneCheck:SetVertexColor(0.30, 1.00, 0.30)
    row.doneCheck:Hide()

    row.name = MakeText(row, 13, "LEFT")
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", NAME_X, -8)
    row.name:SetPoint("RIGHT", row, "LEFT", NAME_X + COLS.name.w, 0)
    row.name:SetWordWrap(false)

    row.firstCraftIcon = row:CreateTexture(nil, "OVERLAY")
    row.firstCraftIcon:SetSize(18, 18)
    row.firstCraftIcon:SetAtlas("Professions_Icon_FirstTimeCraft")
    row.firstCraftIcon:Hide()

    row.reagentsBar = CreateFrame("Frame", nil, row)
    row.reagentsBar:SetSize(COLS.name.w, self.SMALL_ICON)
    row.reagentsBar:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -6)
    row.reagentIcons = {}

    row.cost = MakeText(row, 12, "LEFT")
    row.cost:SetPoint("TOPLEFT", row, "TOPLEFT", COLS.cost.x, -10)
    row.cost:SetWidth(COLS.cost.w)

    row.concBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
    row.concBtn:SetSize(54, 24)
    row.concBtn:SetPoint("TOPLEFT", row, "TOPLEFT", COLS.conc.x, -8)
    row.concBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    row.concBtn:SetBackdropColor(0.08, 0.10, 0.16, 0.85)
    row.concBtn:SetBackdropBorderColor(0.35, 0.85, 1.00, 0.85)

    row.concBtn.icon = row.concBtn:CreateTexture(nil, "ARTWORK")
    row.concBtn.icon:SetSize(16, 16)
    row.concBtn.icon:SetPoint("LEFT", 4, 0)
    row.concBtn.icon:SetTexture("Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\media\\ui_concentration.tga")

    row.concBtn.text = MakeText(row.concBtn, 12, "LEFT")
    row.concBtn.text:SetPoint("LEFT", row.concBtn.icon, "RIGHT", 2, 0)
    row.concBtn.text:SetPoint("RIGHT", row.concBtn, "RIGHT", -4, 0)
    row.concBtn:Hide()

    row.reward = MakeText(row, 12, "LEFT")
    row.reward:SetPoint("TOPLEFT", row, "TOPLEFT", COLS.reward.x, -10)
    row.reward:SetWidth(COLS.reward.w)

    row.rewardBar = CreateFrame("Frame", nil, row)
    row.rewardBar:SetSize(COLS.reward.w, self.SMALL_ICON)
    row.rewardBar:SetPoint("TOPLEFT", row.reward, "BOTTOMLEFT", 0, -4)
    row.rewardIcons = {}

    row.profitBtn = CreateFrame("Button", nil, row)
    row.profitBtn:SetPoint("TOPLEFT", row, "TOPLEFT", COLS.profit.x, -10)
    row.profitBtn:SetSize(COLS.profit.w, 18)

    row.profit = MakeText(row.profitBtn, 13, "LEFT")
    row.profit:SetPoint("LEFT")
    row.profit:SetWidth(COLS.profit.w)

    row.action = CreateFrame("Button", nil, row, "BackdropTemplate")
    row.action:SetSize(74, 28)
    row.action:SetPoint("LEFT", row, "LEFT", COLS.action.x, 0)
    row.action:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    row.action:SetBackdropColor(0.07, 0.09, 0.11, 0.94)
    row.action:SetBackdropBorderColor(0.95, 0.78, 0.35, 0.80)
    if IsFantasy() and PT.ApplyPanelButtonSkin then
        PT:ApplyPanelButtonSkin(row.action)
        row.action:SetBackdropColor(0, 0, 0, 0)
        row.action:SetBackdropBorderColor(0, 0, 0, 0)
    end
    row.action.text = MakeText(row.action, 12, "CENTER")
    row.action.text:SetPoint("CENTER")
    row.action.text:SetText("—")
    row.action.label = row.action.text

    row.action.bar = CreateFrame("StatusBar", nil, row.action)
    row.action.bar:SetPoint("BOTTOMLEFT", 1, 1)
    row.action.bar:SetPoint("BOTTOMRIGHT", -1, 1)
    row.action.bar:SetHeight(3)
    row.action.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    row.action.bar:SetStatusBarColor(0.95, 0.78, 0.35, 0.95)
    row.action.bar:SetMinMaxValues(0, 1)
    row.action.bar:SetValue(0)
    row.action.bar:Hide()

    row.action.check = row.checkbox
    row.action.pageFrame = nil

    row.action:SetScript("OnLeave", function(self)
        if PT.Tooltip and PT.Tooltip.Clear then PT.Tooltip:Clear() end
    end)

    row:SetScript("OnEnter", function(self)
        self.hover:SetColorTexture(1, 1, 1, 0.06)
    end)
    row:SetScript("OnLeave", function(self)
        self.hover:SetColorTexture(1, 1, 1, 0)
        GameTooltip:Hide()
        if PT.Tooltip and PT.Tooltip.Clear then PT.Tooltip:Clear() end
    end)

    return row
end

function CL:EnsureScrollFrame(pageFrame)
    if pageFrame.ahuiCustomList then return pageFrame.ahuiCustomList end

    local listAnchor = pageFrame.BrowseFrame and pageFrame.BrowseFrame.OrderList
    if not listAnchor then return nil end

    local container = CreateFrame("Frame", nil, listAnchor, "BackdropTemplate")
    container:SetAllPoints(listAnchor)
    container:SetFrameLevel((listAnchor:GetFrameLevel() or 0) + 10)
    container:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    container:SetBackdropColor(0, 0, 0, 0.92)
    if IsFantasy() then
        container:SetBackdropBorderColor(0, 0, 0, 1)
    else
        container:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], 0.6)
    end

    local tile = container:CreateTexture(nil, "BACKGROUND", nil, 1)
    tile:SetAllPoints()
    tile:SetTexture("Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\media\\logo.tga")
    tile:SetAlpha(0.07)
    tile:SetVertexColor(0.7, 0.6, 0.85)
    container.tile = tile

    local profBg = container:CreateTexture(nil, "BACKGROUND", nil, 0)
    profBg:SetAllPoints()
    profBg:Hide()
    container.profBg = profBg

    pageFrame.ahuiCustomList = container

    CO:UpdatePageBackground(pageFrame)

    container.header = CL:CreateHeader(container)

    container.scroll = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    container.scroll:SetPoint("TOPLEFT", container.header, "BOTTOMLEFT", 0, -2)
    container.scroll:SetPoint("BOTTOMRIGHT", -30, 4)
    container.scroll:EnableMouseWheel(true)

    container.content = CreateFrame("Frame", nil, container.scroll)
    container.content:SetSize(800, 1)
    container.scroll:SetScrollChild(container.content)

    container.rows = {}

    local scrollBox = listAnchor.ScrollBox
    if scrollBox and scrollBox.RegisterCallback and ScrollBoxConstants then
        local evt = ScrollBoxConstants.OnDataProviderChanged
            or ScrollBoxConstants.OnDataChanged
        if evt then
            scrollBox:RegisterCallback(evt, function()
                QueueRefresh()
            end, container)
        end
    end

    return container
end

local function ForceHide(frame)
    if not frame then return end
    if frame._ahuiHideHooked then
        frame:Hide()
        return
    end
    frame._ahuiHideHooked = true
    frame:Hide()
    frame:HookScript("OnShow", function(self)
        if CO and CO.CustomList and CO.CustomList._listActive then
            self:Hide()
        end
    end)
end

function CL:HideBlizzardList(pageFrame)
    local list = pageFrame.BrowseFrame and pageFrame.BrowseFrame.OrderList
    if not list then return end
    self._listActive = true
    ForceHide(list.ScrollBox)
    ForceHide(list.ScrollBar)
    ForceHide(list.HeaderContainer)
end

function CL:ShowBlizzardList(pageFrame)
    local list = pageFrame.BrowseFrame and pageFrame.BrowseFrame.OrderList
    if not list then return end
    if list.ScrollBox then list.ScrollBox:Show() end
    if list.ScrollBar then list.ScrollBar:Show() end
    if list.HeaderContainer then list.HeaderContainer:Show() end
end

function CL:Deactivate(pageFrame)
    pageFrame = pageFrame or CO.activePageFrame or (_G.ProfessionsFrame and ProfessionsFrame.OrdersPage)
    self._pollStamp = (self._pollStamp or 0) + 1
    self._listActive = false
    if pageFrame then
        if pageFrame.ahuiCustomList then pageFrame.ahuiCustomList:Hide() end
        self:ShowBlizzardList(pageFrame)
    end
end

local function ReadProviderOrders(pageFrame)
    local list = pageFrame.BrowseFrame and pageFrame.BrowseFrame.OrderList
    if not list or not list.ScrollBox or not list.ScrollBox.GetDataProvider then return {} end
    local provider = list.ScrollBox:GetDataProvider()
    if not provider then return {} end
    local out = {}
    if provider.EnumerateEntireRange then
        for _, ed in provider:EnumerateEntireRange() do
            local order = ed and (ed.option or ed.order or ed)
            if type(order) == "table" then
                out[#out + 1] = order
            end
        end
    end
    return out
end

function CL:GetOrders(pageFrame)
    if C_CraftingOrders and C_CraftingOrders.GetCrafterOrders then
        local ok, apiOrders = pcall(C_CraftingOrders.GetCrafterOrders)
        if ok and type(apiOrders) == "table" then
            local out = {}
            local container = pageFrame and pageFrame.ahuiCustomList
            if container and container._freshSearchPending then
                return out
            end
            for _, order in ipairs(apiOrders) do
                if type(order) == "table" then
                    out[#out + 1] = order
                end
            end
            return out
        end
    end

    return ReadProviderOrders(pageFrame)
end

local GOLD_ICON   = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:0:-1|t"
local SILVER_ICON = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:0:-1|t"

local function FormatCopper(copper)
    if not copper then return "0" end
    local neg = copper < 0
    local abs = math.abs(copper)
    local gold = math.floor(abs / 10000)
    local silver = math.floor((abs % 10000) / 100)
    local sign = neg and "-" or ""
    if gold > 0 and silver > 0 then
        return sign .. gold .. GOLD_ICON .. " " .. silver .. SILVER_ICON
    elseif gold > 0 then
        return sign .. gold .. GOLD_ICON
    elseif silver > 0 then
        return sign .. silver .. SILVER_ICON
    end
    return "0"
end

local function GetIconButton(row, parent, store, index)
    local b = store[index]
    if b then return b end
    b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(CL.SMALL_ICON, CL.SMALL_ICON)
    b:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    b:SetBackdropBorderColor(0, 0, 0, 0)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetPoint("TOPLEFT", 1, -1)
    b.tex:SetPoint("BOTTOMRIGHT", -1, 1)
    b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.count = b:CreateFontString(nil, "OVERLAY")
    b.count:SetFont(HironCraftProfit.FONT or STANDARD_TEXT_FONT, 12, "THICKOUTLINE")
    b.count:SetPoint("BOTTOMRIGHT", -1, 1)
    b.count:SetTextColor(1, 1, 1)
    b.count:SetShadowColor(0, 0, 0, 1)
    b.count:SetShadowOffset(1, -1)
    b.grade = b:CreateTexture(nil, "OVERLAY")
    b.grade:SetSize(16, 16)
    b.grade:SetPoint("CENTER", b, "TOPLEFT", 1, -1)
    b.grade:Hide()
    b.gold = b:CreateFontString(nil, "OVERLAY")
    b.gold:SetFont(HironCraftProfit.FONT or STANDARD_TEXT_FONT, 12, "OUTLINE")
    b.gold:SetPoint("LEFT", b, "RIGHT", 2, 0)
    b.gold:SetTextColor(1, 0.82, 0.20)
    b.gold:Hide()
    store[index] = b
    return b
end

local function ShowItemTooltip(self)
    if not self._itemID and not self._itemLink then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self._itemLink then
        GameTooltip:SetHyperlink(self._itemLink)
    elseif self._itemID then
        GameTooltip:SetItemByID(self._itemID)
    end
    GameTooltip:Show()
end

local function HideTooltip()
    GameTooltip:Hide()
end

local function GetItemQualityAtlas(quality, maxQuality)
    quality = tonumber(quality)
    if not quality or quality < 1 or quality > 5 then return nil end
    quality = math.floor(quality)
    if maxQuality and maxQuality <= 2 then
        return "Professions-Icon-Quality-12-Tier" .. tostring(math.min(quality, 2))
    end
    return "Professions-Icon-Quality-Tier" .. tostring(quality)
end

local function ReagentGradeLabel(candidate)
    local name = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(candidate.itemID))
        or ("item:" .. tostring(candidate.itemID))
    local tier = tonumber(candidate.qualityTier)
    if tier and tier > 0 then
        local atlas = GetItemQualityAtlas(tier, tonumber(candidate.maxQualityTier))
        local markup = atlas and CreateAtlasMarkup(atlas, 14, 14) or ("T" .. tier)
        return markup .. " " .. name
    end
    return name
end

function OpenReagentGradeMenu(owner, order, reagentEntry)
    if not order or not reagentEntry then return end

    if CO.OpenReagentMixPicker then
        return CO:OpenReagentMixPicker(owner, order, reagentEntry)
    end

    if not (PT and PT.Dropdown and CO.GetReagentCandidates) then return end

    local candidates = CO:GetReagentCandidates(order, reagentEntry)
    if not candidates or #candidates == 0 then return end

    local selected = CO.GetSelectedReagentForEntry and CO:GetSelectedReagentForEntry(order.orderID, reagentEntry)
    local selectedID = (selected and selected.itemID) or reagentEntry.itemID

    local items = {}
    for _, c in ipairs(candidates) do
        local cc = c
        items[#items + 1] = {
            text = ReagentGradeLabel(cc),
            icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(cc.itemID)) or nil,
            checked = (cc.itemID == selectedID),
            onClick = function()
                local dataSlotIndex = reagentEntry.dataSlotIndex or cc.dataSlotIndex
                local slotIndex = reagentEntry.slotIndex or cc.slotIndex or dataSlotIndex
                CO:SetSelectedReagentForEntry(order.orderID, reagentEntry, {
                    itemID = cc.itemID,
                    quantity = reagentEntry.quantity or cc.quantity or 0,
                    slotIndex = slotIndex,
                    dataSlotIndex = dataSlotIndex,
                    qualityTier = (CO.GetQueueReagentCandidateTier and CO:GetQueueReagentCandidateTier(cc)) or cc.qualityTier,
                    maxQualityTier = cc.maxQualityTier,
                    expansionID = cc.expansionID,
                    qualityKind = cc.qualityKind,
                })
                if CO.CustomList and CO.CustomList.Refresh and CO.activePageFrame then
                    CO.CustomList:Refresh(CO.activePageFrame)
                end
            end,
        }
    end

    PT.Dropdown:Show({ owner = owner, items = items })
end

function CL:ApplyRowLayout(row)
    local compact = self:IsCompact()
    local h = self:RowHeight()
    row:SetHeight(h)

    if compact then
        local C = COLS_COMPACT
        row.iconBtn:SetSize(self.ICON_COMPACT, self.ICON_COMPACT)
        row.iconBtn:ClearAllPoints()
        row.iconBtn:SetPoint("LEFT", row.checkbox, "RIGHT", 2, 0)

        row.qualityBadge:SetSize(14, 14)

        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", row, "LEFT", C.name.x, 0)
        row.name:SetWidth(C.name.w)

        row.cost:Hide()
        row.reward:Hide()

        row.profit:Show()
        row.profitBtn:ClearAllPoints()
        row.profitBtn:SetPoint("LEFT", row, "LEFT", C.profit.x, 0)
        row.profitBtn:SetSize(C.profit.w, 18)
        row.profit:SetWidth(C.profit.w)

        row.concBtn:ClearAllPoints()
        row.concBtn:SetPoint("LEFT", row, "LEFT", C.conc.x, 0)
        row.concBtn:SetSize(48, 22)

        row.rewardBar:Show()
        row.rewardBar:ClearAllPoints()
        row.rewardBar:SetPoint("LEFT", row, "LEFT", C.reward.x, 0)

        row.reagentsBar:ClearAllPoints()
        row.reagentsBar:SetPoint("LEFT", row, "LEFT", C.reagents.x, 0)

        row.action:ClearAllPoints()
        row.action:SetPoint("LEFT", row, "LEFT", C.action.x, 0)
        row.action:SetSize(74, 24)
    else
        row.iconBtn:SetSize(self.ICON_SIZE, self.ICON_SIZE)
        row.iconBtn:ClearAllPoints()
        row.iconBtn:SetPoint("LEFT", row.checkbox, "RIGHT", 4, 0)

        row.qualityBadge:SetSize(20, 20)

        row.name:ClearAllPoints()
        row.name:SetPoint("TOPLEFT", row, "TOPLEFT", NAME_X, -8)
        row.name:SetPoint("RIGHT", row, "LEFT", NAME_X + COLS.name.w, 0)

        row.cost:Show()
        row.profit:Show()
        row.reward:Hide()
        row.rewardBar:Show()

        row.cost:ClearAllPoints()
        row.cost:SetPoint("TOPLEFT", row, "TOPLEFT", COLS.cost.x, -10)

        row.concBtn:ClearAllPoints()
        row.concBtn:SetPoint("TOPLEFT", row, "TOPLEFT", COLS.conc.x, -8)
        row.concBtn:SetSize(54, 24)

        row.rewardBar:ClearAllPoints()
        row.rewardBar:SetPoint("TOPLEFT", row, "TOPLEFT", COLS.reward.x, -8)

        row.reagentsBar:ClearAllPoints()
        row.reagentsBar:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -6)

        row.profitBtn:ClearAllPoints()
        row.profitBtn:SetPoint("TOPLEFT", row, "TOPLEFT", COLS.profit.x, -10)

        row.action:ClearAllPoints()
        row.action:SetPoint("LEFT", row, "LEFT", COLS.action.x, 0)
        row.action:SetSize(74, 28)
    end
end

function CL:PopulateRow(row, order)
    row._order = order
    self:ApplyRowLayout(row)

    local spellID = order.spellID
    local recipeInfo = spellID and C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo and C_TradeSkillUI.GetRecipeInfo(spellID)
    local icon = recipeInfo and recipeInfo.icon or (spellID and GetSpellTexture and GetSpellTexture(spellID)) or "Interface\\Icons\\INV_Misc_QuestionMark"
    row.icon:SetTexture(icon)
    row.name:SetText((recipeInfo and recipeInfo.name) or ("Recipe " .. tostring(spellID)))

    row.iconBtn._spellID = spellID
    row.iconBtn._itemID = order.itemID
    row.iconBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self._spellID and C_TradeSkillUI and C_TradeSkillUI.GetRecipeItemLink then
            local link = C_TradeSkillUI.GetRecipeItemLink(self._spellID)
            if link then
                GameTooltip:SetHyperlink(link)
                GameTooltip:Show()
                return
            end
        end
        if self._itemID then
            GameTooltip:SetItemByID(self._itemID)
            GameTooltip:Show()
        end
    end)
    row.iconBtn:SetScript("OnLeave", HideTooltip)

    local firstCraft = false
    if recipeInfo then
        if recipeInfo.firstCraft == true then firstCraft = true end
    end
    if firstCraft then
        row.firstCraftIcon:ClearAllPoints()
        row.firstCraftIcon:SetPoint("LEFT", row.name, "LEFT", (row.name:GetStringWidth() or 0) + 4, 0)
        row.firstCraftIcon:Show()
    else
        row.firstCraftIcon:Hide()
    end

    local minQ = tonumber(order.minQuality)
    local maxQ = tonumber(recipeInfo and recipeInfo.maxQuality) or 5
    local atlas = minQ and minQ > 0 and GetItemQualityAtlas(minQ, maxQ) or nil
    if atlas then
        row.qualityBadge:SetAtlas(atlas)
        row.qualityBadge:Show()
    else
        row.qualityBadge:Hide()
    end

    for _, b in pairs(row.reagentIcons) do b:Hide() end
    if CO.BuildDisplayReagents then
        if CO.ApplyQueueReagentModeToOrder then CO:ApplyQueueReagentModeToOrder(order) end
        local manual = (CO.GetQueueReagentMode and CO:GetQueueReagentMode()) == "manual"
        local reagents = CO:BuildDisplayReagents(order) or {}
        local x = 0
        local i = 1
        for _, reagent in ipairs(reagents) do
            local selected = CO.GetSelectedReagentForEntry and CO:GetSelectedReagentForEntry(order.orderID, reagent)
            local id = (selected and selected.itemID) or reagent.itemID
            if id then
                local iconTex = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
                if iconTex then
                    local b = GetIconButton(row, row.reagentsBar, row.reagentIcons, i)
                    b.tex:SetTexture(iconTex)
                    b._itemID = id
                    b._itemLink = nil

                    local need = tonumber(selected and selected.quantity) or tonumber(reagent.quantity) or 0
                    local available, missing, mixedCount = false, 0, 0

                    if selected and type(selected.mix) == "table" and #selected.mix > 0 then
                        mixedCount = #selected.mix
                        local sum, ok = 0, true
                        for _, p in ipairs(selected.mix) do
                            local pq = tonumber(p.quantity) or 0
                            local powned = CO:GetItemCountForShopping(p.itemID) or 0
                            if powned < pq then ok = false; missing = missing + (pq - powned) end
                            sum = sum + pq
                        end
                        available = ok and sum >= need
                    elseif (CO.GetQueueReagentMode and CO:GetQueueReagentMode()) == "auto" and CO.BuildOwnedMixForEntry then
                        local mix, remaining = CO:BuildOwnedMixForEntry(order, reagent, {})
                        available = remaining <= 0
                        if available then mixedCount = #mix else missing = remaining end
                    else
                        local have = (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id, true, false, true, true)) or 0
                        available = have >= need
                        missing = math.max(0, need - have)
                    end

                    if available then
                        b.count:SetText("")
                        b:SetBackdropBorderColor(0.30, 0.95, 0.30, 0.95)
                        if b.tex.SetDesaturated then b.tex:SetDesaturated(false) end
                        b.tex:SetVertexColor(1, 1, 1)
                    else
                        b.count:SetText(missing > 0 and tostring(missing) or "")
                        b.count:SetTextColor(1.00, 0.85, 0.30, 1)
                        b:SetBackdropBorderColor(0.95, 0.30, 0.30, 0.95)
                        if b.tex.SetDesaturated then b.tex:SetDesaturated(true) end
                        b.tex:SetVertexColor(0.85, 0.85, 0.85)
                    end

                    local tier = (ReadProfessionQualityFromItem and ReadProfessionQualityFromItem(id))
                        or tonumber((selected and selected.qualityTier) or reagent.qualityTier)
                    local maxTier = tonumber((selected and selected.maxQualityTier) or reagent.maxQualityTier)
                    local gradeAtlas = tier and tier > 0 and GetItemQualityAtlas(tier, maxTier) or nil
                    if mixedCount >= 2 then
                        b.grade:SetAtlas("Professions-Icon-Quality-Mixed")
                        b.grade:Show()
                    elseif gradeAtlas then
                        b.grade:SetAtlas(gradeAtlas)
                        b.grade:Show()
                    else
                        b.grade:Hide()
                    end

                    b._order = order
                    b._reagentEntry = reagent
                    if manual then
                        b:RegisterForClicks("LeftButtonUp")
                        b:SetScript("OnClick", function(self)
                            OpenReagentGradeMenu(self, self._order, self._reagentEntry)
                        end)
                    else
                        b:SetScript("OnClick", nil)
                    end

                    b:ClearAllPoints()
                    b:SetPoint("LEFT", row.reagentsBar, "LEFT", x, 0)
                    b:SetScript("OnEnter", ShowItemTooltip)
                    b:SetScript("OnLeave", HideTooltip)
                    b:Show()
                    x = x + self.SMALL_ICON + 4
                    i = i + 1
                end
            end
        end
    end

    local tip = tonumber(order.tipAmount) or 0
    local cost = 0
    local profitInfo
    if CO.GetOrderProfitInfo then
        profitInfo = CO:GetOrderProfitInfo(order)
        if profitInfo and profitInfo.reagentCost then cost = tonumber(profitInfo.reagentCost) or 0 end
    end
    row.cost:SetText(cost > 0 and FormatCopper(cost) or "—")

    local compact = self:IsCompact()
    local isNpcReward = Enum and Enum.CraftingOrderType and order.orderType == Enum.CraftingOrderType.Npc
    for _, b in pairs(row.rewardIcons) do b:Hide() end
    row.reward:SetText("")
    local rewards = order.npcOrderRewards or order.rewards or {}

    do
        local GR, GG, GB = 1.00, 0.82, 0.20
        local perRow = compact and 99 or 4
        local step = self.SMALL_ICON + 2
        local i = 1

        local function place(b)
            local col = (i - 1) % perRow
            local rowIdx = math.floor((i - 1) / perRow)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", row.rewardBar, "TOPLEFT", col * step, -rowIdx * step)
            b:SetBackdropBorderColor(GR, GG, GB, 1)
            b:Show()
            i = i + 1
        end

        if tip and tip > 0 then
            local b = GetIconButton(row, row.rewardBar, row.rewardIcons, i)
            b.tex:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
            b._itemID = nil
            b._itemLink = nil
            if not isNpcReward then
                b.gold:SetText(tostring(math.floor(tip / 10000 + 0.5)))
                b.gold:Show()
            else
                b.gold:Hide()
            end
            b.count:SetText("")
            b:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(FormatCopper(tip), 1, 0.82, 0.20)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", HideTooltip)
            place(b)
        end

        for _, rw in ipairs(rewards) do
            local itemID = rw.itemID or (rw.item and rw.item.itemID)
            local itemLink = rw.itemLink or rw.link
            if itemID or itemLink then
                local tex
                if itemID and C_Item and C_Item.GetItemIconByID then
                    tex = C_Item.GetItemIconByID(itemID)
                end
                if not tex and GetItemIcon then tex = GetItemIcon(itemLink or itemID) end
                if tex then
                    local b = GetIconButton(row, row.rewardBar, row.rewardIcons, i)
                    b.tex:SetTexture(tex)
                    b._itemID = itemID
                    b._itemLink = itemLink
                    b.gold:Hide()
                    local count = tonumber(rw.count) or tonumber(rw.quantity) or 0
                    b.count:SetText(count > 1 and tostring(count) or "")
                    b:SetScript("OnEnter", ShowItemTooltip)
                    b:SetScript("OnLeave", HideTooltip)
                    place(b)
                end
            end
        end
    end

    local profit = (profitInfo and tonumber(profitInfo.profit)) or (tip - cost)
    row.profit:SetText(FormatCopper(profit))
    if profit > 0 then
        row.profit:SetTextColor(0.50, 1.00, 0.50)
    elseif profit < 0 then
        row.profit:SetTextColor(1.00, 0.45, 0.45)
    else
        row.profit:SetTextColor(0.85, 0.85, 0.85)
    end

    row.profitBtn._order = order
    row.profitBtn._info = profitInfo
    row.profitBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(L("COA_CL_PROFIT_TITLE", "Profit"), 1, 0.82, 0.35)
        local info = self._info
        if info then
            local prof = tonumber(info.profit) or 0
            local rew = tonumber(info.rewardValue) or 0
            local cst = tonumber(info.reagentCost) or 0
            local r1, g1, b1 = (prof >= 0) and 0.50 or 1.00, (prof >= 0) and 1.00 or 0.45, (prof >= 0) and 0.50 or 0.45
            GameTooltip:AddLine(L("COA_CL_PROFIT_VALUE", "Profit: %s"):format(FormatCopper(prof)), r1, g1, b1)
            GameTooltip:AddLine(L("COA_CL_REWARD_VALUE", "Reward: %s"):format(FormatCopper(rew + (tonumber(self._order and self._order.tipAmount) or 0))), 1, 1, 1)
            GameTooltip:AddLine(L("COA_CL_REAGENTS_COST", "Reagents cost: %s"):format(FormatCopper(cst)), 0.85, 0.85, 0.85)
            if info.missingPrices then
                GameTooltip:AddLine(L("COA_CL_AUCTIONATOR_MISSING", "Some Auctionator prices missing"), 1, 0.65, 0.25)
            end
        else
            GameTooltip:AddLine(L("COA_CL_NO_DATA", "Data unavailable"), 0.85, 0.85, 0.85)
        end
        GameTooltip:Show()
    end)
    row.profitBtn:SetScript("OnLeave", HideTooltip)

    local action, _, _, enabled = CO.GetRowAction and CO:GetRowAction(order.orderID, order)
    local actionLabel = "—"
    if action == "reject" then actionLabel = L("COA_ACTION_REJECT", "Decline")
    elseif action == "rejecting" then actionLabel = "..."
    elseif action == "claim" then actionLabel = L("COA_ACTION_CLAIM", "Claim")
    elseif action == "craft" then actionLabel = order.isRecraft and L("COA_ACTION_RECRAFT", "Recraft") or L("COA_ACTION_CRAFT", "Craft")
    elseif action == "fulfill" then actionLabel = L("COA_ACTION_FULFILL", "Complete")
    elseif action == "pending" or action == "claiming" then actionLabel = "..."
    elseif action == "crafting" then actionLabel = L("COA_ACTION_CRAFTING", "Crafting")
    elseif action == "fulfilling" then actionLabel = L("COA_ACTION_FULFILLING", "Completing")
    end
    row.action.text:SetText(actionLabel)

    if action == "fulfill" or action == "fulfilling" then
        row.doneCheck:Show()
        CL:ApplyStripe(row)
        if row.doneStripe then
            if CL._stripeTex then row.doneStripe:Show() else row.doneStripe:Hide() end
        end
    else
        row.doneCheck:Hide()
        if row.doneStripe then row.doneStripe:Hide() end
    end
    row.action.action = action
    row.action.actionEnabled = enabled
    if enabled then
        row.action.text:SetTextColor(1, 1, 1, 1)
    else
        row.action.text:SetTextColor(0.55, 0.55, 0.55, 1)
    end

    local known = CO.GetRecipeKnownState and CO:GetRecipeKnownState(order)

    local CE = HironCraft and HironCraft.CraftEngine
    local target = (CO.GetOrderRequestedQuality and CO:GetOrderRequestedQuality(order)) or tonumber(order.minQuality) or 0
    local concInfo
    if CE and order.spellID and target > 0 then
        local mode = CO.GetQueueReagentMode and CO:GetQueueReagentMode() or "auto"
        local locked = CO.BuildLockedReagentsForEngine and CO:BuildLockedReagentsForEngine(order) or nil
        concInfo = CE:NeedsConcentrationCached(order.spellID, target, order.orderID, mode, locked)
    end

    local needsConc, engineCost
    if target <= 0 then
        needsConc = false
    elseif concInfo then
        needsConc = concInfo.needs
        engineCost = concInfo.concentrationCost
    else
        needsConc = CO.OrderRequiresConcentrationForQueue and CO:OrderRequiresConcentrationForQueue(order)
    end

    if needsConc then
        local cost = (engineCost and engineCost > 0) and engineCost
            or (CO.GetFastConcentrationCost and CO:GetFastConcentrationCost(order)) or nil
        if not (cost and cost > 0) then
            local qInfoConc = CO.GetOrderQualityInfo and CO:GetOrderQualityInfo(order, true, true)
            if qInfoConc and qInfoConc.concentrationCost and qInfoConc.concentrationCost > 0 then
                cost = qInfoConc.concentrationCost
            end
        end

        local key = order.orderID and tostring(order.orderID)
        local concOn = key and CO.useConcentration and CO.useConcentration[key] == true

        if cost and cost > 0 then
            row.concBtn.text:SetText(tostring(math.floor(cost + 0.5)))
        else
            row.concBtn.text:SetText("?")
        end

        if concOn then
            row.concBtn.text:SetTextColor(0.30, 0.95, 1.00)
            row.concBtn:SetBackdropColor(0.10, 0.30, 0.40, 0.95)
            row.concBtn:SetBackdropBorderColor(0.30, 0.95, 1.00, 1)
            if row.concBtn.icon then row.concBtn.icon:SetVertexColor(0.30, 0.95, 1.00) end
        elseif cost and cost > 0 then
            row.concBtn.text:SetTextColor(1.00, 0.78, 0.20)
            row.concBtn:SetBackdropColor(0.08, 0.10, 0.16, 0.85)
            row.concBtn:SetBackdropBorderColor(1.00, 0.78, 0.20, 0.90)
            if row.concBtn.icon then row.concBtn.icon:SetVertexColor(1, 1, 1) end
        else
            row.concBtn.text:SetTextColor(0.85, 0.85, 0.85)
            row.concBtn:SetBackdropColor(0.08, 0.10, 0.16, 0.85)
            row.concBtn:SetBackdropBorderColor(0.55, 0.55, 0.65, 0.70)
            if row.concBtn.icon then row.concBtn.icon:SetVertexColor(1, 1, 1) end
        end

        row.concBtn._order = order
        row.concBtn._cost = cost
        row.concBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(L("COA_CL_CONC_TITLE", "Concentration"), 1, 0.82, 0.35)
            if self._cost and self._cost > 0 then
                GameTooltip:AddLine(L("COA_CL_CONC_REQUIRED", "Required: %s"):format(tostring(math.floor(self._cost + 0.5))), 1, 1, 1)
            else
                GameTooltip:AddLine(L("COA_CL_CONC_NO_DATA", "Exact data not loaded"), 0.85, 0.85, 0.85)
            end
            local on = key and CO.useConcentration and CO.useConcentration[key] == true
            GameTooltip:AddLine(" ", 1, 1, 1)
            GameTooltip:AddLine(on and L("COA_CL_CONC_TOGGLE_OFF", "Click: disable concentration") or L("COA_CL_CONC_TOGGLE_ON", "Click: enable concentration"), 0.70, 0.90, 1)
            GameTooltip:Show()
        end)
        row.concBtn:SetScript("OnLeave", HideTooltip)
        row.concBtn:SetScript("OnClick", function()
            if not key then return end
            CO.useConcentration = CO.useConcentration or {}
            CO.useConcentration[key] = (not CO.useConcentration[key]) and true or nil
            QueueRefresh()
        end)
        row.concBtn:Show()
    else
        row.concBtn:Hide()
    end
    local nr, ng, nb
    if known == false then
        nr, ng, nb = 1.00, 0.45, 0.45
    elseif needsConc then
        nr, ng, nb = 1.00, 0.82, 0.30
    elseif CO.IsOrderCraftableForActionSort and CO:IsOrderCraftableForActionSort(order) then
        nr, ng, nb = 0.55, 1.00, 0.55
    else
        nr, ng, nb = 0.95, 0.95, 0.95
    end
    row.bg:SetColorTexture(0, 0, 0, 0)
    row.name:SetTextColor(nr, ng, nb)

    row.checkbox:SetChecked(CO.IsOrderSelected and CO:IsOrderSelected(order.orderID) or false)

    row.checkbox:SetScript("OnClick", function(self)
        if CO.SetOrderSelected and order.orderID then
            CO:SetOrderSelected(order.orderID, self:GetChecked())
            QueueRefresh()
        end
    end)

    row.action.order = order
    row.action.orderID = order.orderID
    row.action.pageFrame = CO.activePageFrame

    CO.visibleRowButtons = CO.visibleRowButtons or {}
    CO.visibleRowButtons[row.action] = true
    CO.rowButtonsByOrderID = CO.rowButtonsByOrderID or {}
    if order.orderID then
        CO.rowButtonsByOrderID[tostring(order.orderID)] = row.action
    end
    row.action:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.action:SetScript("OnClick", function(self, button)
        self.pageFrame = CO.activePageFrame
        if button == "RightButton" then
            if CO.ReleaseOrder then
                CO:ReleaseOrder(self.order or order, self.pageFrame)
            end
            return
        end
        if CO.RunRowButtonAction then
            CO:RunRowButtonAction(self)
        end
    end)

    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" then return end
        if CO.SetActiveRowButton then CO:SetActiveRowButton(row.action) end
        local pf = CO.activePageFrame
        if not pf or not pf.OrderView then return end
        if ProfessionsCraftingOrderPageMixin and ProfessionsCraftingOrderPageMixin.ViewOrder then
            ProfessionsCraftingOrderPageMixin.ViewOrder(pf, order)
        elseif pf.ViewOrder then
            pf:ViewOrder(order)
        end
    end)
    row:HookScript("OnEnter", function()
        if CO.SetActiveRowButton then CO:SetActiveRowButton(row.action) end
    end)
end

function CL:Refresh(pageFrame)
    pageFrame = pageFrame or CO.activePageFrame
    if not pageFrame then return end
    if not pageFrame:IsShown() then return end
    if not CO:IsEnabled() then return end

    if GameTooltip and GameTooltip:IsShown() and GameTooltip.GetOwner then
        local owner = GameTooltip:GetOwner()
        if owner and owner.GetParent then
            local p = owner
            for _ = 1, 6 do
                if not p then break end
                if p == pageFrame.ahuiCustomList then
                    GameTooltip:Hide()
                    break
                end
                p = p.GetParent and p:GetParent() or nil
            end
        end
    end

    local container = self:EnsureScrollFrame(pageFrame)
    if not container then return end

    self:HideBlizzardList(pageFrame)

    local currentType = pageFrame.orderType
    if container._orderType == nil then
        container._orderType = currentType
    elseif currentType ~= nil and currentType ~= container._orderType then
        container._orderType = currentType
        container._lastGoodOrders = nil
        container._lastGoodType = nil
        container._allowEmptyOnce = true
        if CO.selectedOrders then wipe(CO.selectedOrders) end
        CO.currentQueueOrderID = nil
        for _, row in ipairs(container.rows) do row:Hide() end
    end

    if CO.EnsureControlPanel then CO:EnsureControlPanel(pageFrame) end
    if CO.UpdateControlPanelVisibility then CO:UpdateControlPanelVisibility(pageFrame) end
    if CO.UpdateTabActionButton then CO:UpdateTabActionButton(pageFrame) end

    local function rankOrder(order)
        return CO.GetOrderActionAvailabilitySortRank and CO:GetOrderActionAvailabilitySortRank(order) or 4
    end

    local function getProfit(o)
        return (CO.GetOrderProfitInfo and (CO:GetOrderProfitInfo(o) or {}).profit) or 0
    end
    local function getCost(o)
        return (CO.GetOrderProfitInfo and (CO:GetOrderProfitInfo(o) or {}).reagentCost) or 0
    end
    local function getReward(o)
        return tonumber(o.tipAmount) or 0
    end
    local function getName(o)
        local ri = o.spellID and C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo and C_TradeSkillUI.GetRecipeInfo(o.spellID)
        return (ri and ri.name) or ""
    end

    local orders = self:GetOrders(pageFrame)

    if currentType ~= nil and #orders > 0 then
        local filtered = {}
        for _, o in ipairs(orders) do
            if o.orderType == nil or o.orderType == currentType then
                filtered[#filtered + 1] = o
            end
        end
        orders = filtered
    end

    if CO.fulfilledOrderIDs and #orders > 0 then
        local filtered = {}
        for _, o in ipairs(orders) do
            if not (o and o.orderID and CO.fulfilledOrderIDs[o.orderID]) then
                filtered[#filtered + 1] = o
            end
        end
        orders = filtered
    end

    if #orders == 0 then
        if container._allowEmptyOnce then
            container._lastGoodOrders = nil
            container._lastGoodType = nil
        elseif container._lastGoodOrders and #container._lastGoodOrders > 0
            and container._lastGoodType == currentType then
            orders = container._lastGoodOrders
            C_Timer.After(0.3, function()
                if pageFrame:IsShown() then CL:Refresh(pageFrame) end
            end)
        end
    else
        container._lastGoodOrders = orders
        container._lastGoodType = currentType
    end
    container._allowEmptyOnce = false
    container._lastOrderCount = #orders

    local sortCol = CL._sortColumn
    local sortAsc = (CL._sortDir == "asc")

    local function isActiveCraft(order)
        if not order or not order.orderID then return false end
        local activeID = CO.progressOrderID or CO.pendingCraftOrderID
        if activeID and tostring(activeID) == tostring(order.orderID) then return true end
        return false
    end

    local doneMap = {}
    local fulfilled = CO.fulfilledOrderIDs
    for _, order in ipairs(orders) do
        if order and order.orderID then
            local act = CO.GetRowAction and CO:GetRowAction(order.orderID, order)
            local isFulfilled = (fulfilled and fulfilled[order.orderID]) and true or false
            doneMap[order.orderID] = (act == "fulfilling") or isFulfilled
        end
    end
    local function isDoneOrder(order)
        return order and order.orderID and doneMap[order.orderID] or false
    end

    local isNpcTab = Enum and Enum.CraftingOrderType and currentType == Enum.CraftingOrderType.Npc

    table.sort(orders, function(a, b)
        local aDone = isDoneOrder(a) and 1 or 0
        local bDone = isDoneOrder(b) and 1 or 0
        if aDone ~= bDone then return aDone < bDone end

        local pa = isActiveCraft(a) and 1 or 0
        local pb = isActiveCraft(b) and 1 or 0
        if pa ~= pb then return pa > pb end

        local sa = CO.IsOrderSelected and CO:IsOrderSelected(a.orderID) and 1 or 0
        local sb = CO.IsOrderSelected and CO:IsOrderSelected(b.orderID) and 1 or 0
        if sa ~= sb then return sa > sb end

        if sortCol then
            local va, vb
            if sortCol == "name" then
                va, vb = getName(a), getName(b)
                if va ~= vb then
                    if sortAsc then return va < vb else return va > vb end
                end
            elseif sortCol == "cost" then
                va, vb = getCost(a), getCost(b)
            elseif sortCol == "reward" then
                va, vb = getReward(a), getReward(b)
            elseif sortCol == "profit" then
                va, vb = getProfit(a), getProfit(b)
            end
            if va ~= nil and vb ~= nil and va ~= vb then
                if sortAsc then return va < vb else return va > vb end
            end
        end

        if not sortCol and not isNpcTab then
            local na, nb = getName(a), getName(b)
            if na ~= nb then return na < nb end
            return tostring(a.orderID or 0) < tostring(b.orderID or 0)
        end

        local ra = rankOrder(a)
        local rb = rankOrder(b)
        if ra ~= rb then return ra < rb end
        return getProfit(a) > getProfit(b)
    end)

    if container.header and UpdateHeaderArrows then UpdateHeaderArrows(container.header) end

    for _, row in ipairs(container.rows) do row:Hide() end
    local y = 0
    for i, order in ipairs(orders) do
        local row = container.rows[i]
        if not row then
            row = self:CreateRow(container.content, i)
            container.rows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", container.content, "TOPLEFT", 0, -y)
        row:SetPoint("RIGHT", container.content, "RIGHT", 0, 0)
        row:Show()
        self:PopulateRow(row, order)
        y = y + self:RowHeight()
    end

    container.content:SetHeight(math.max(1, y))
    container:Show()
end

function CL:SettleOnRecipes()
    local op = ProfessionsFrame and ProfessionsFrame.OrdersPage
    if op and op:IsShown() then return end
    local ts = ProfessionsFrame and ProfessionsFrame.TabSystem
    if not ts or not ts.tabs then return end
    local recipesTab = ts.tabs[1]
    local tabID = recipesTab and (recipesTab.tabID or recipesTab:GetID())
    if tabID and ts.SetTab then
        pcall(ts.SetTab, ts, tabID)
    end
end

function CL:StartLoadPoll(pageFrame)
    self._pollStamp = (self._pollStamp or 0) + 1
    local stamp = self._pollStamp
    local startedAt = GetTime()

    local function tick()
        if stamp ~= self._pollStamp then return end
        if not pageFrame:IsShown() then return end
        self:Refresh(pageFrame)
        local orders = self:GetOrders(pageFrame)
        if #orders > 0 then return end
        if (GetTime() - startedAt) > 5 then return end
        C_Timer.After(0.3, tick)
    end

    tick()
end

local hooksAttached = false

local function AttachHooks()
    if hooksAttached then return true end
    if not ProfessionsCraftingOrderPageMixin or not ProfessionsCraftingOrderPageMixin.ShowGeneric then
        return false
    end
    hooksAttached = true

    local function HookAfter(pageFrame)
        if not pageFrame then return end
        if not CO:IsEnabled() then return end
        CO.activePageFrame = CO.activePageFrame or pageFrame
        if pageFrame.ahuiCustomList then
            pageFrame.ahuiCustomList._allowEmptyOnce = true
        end
        CL:StartLoadPoll(pageFrame)
        if pageFrame.HookScript and not pageFrame.ahuiCustomListHidehooked then
            pageFrame.ahuiCustomListHidehooked = true
            pageFrame:HookScript("OnHide", function()
                if pageFrame.ahuiCustomList and pageFrame.ahuiCustomList.rows then
                    for _, row in ipairs(pageFrame.ahuiCustomList.rows) do
                        if row.action and CO.visibleRowButtons then
                            CO.visibleRowButtons[row.action] = nil
                        end
                    end
                end
                if CO.ClearTemporaryBinding then CO:ClearTemporaryBinding() end
            end)
        end
    end

    hooksecurefunc(ProfessionsCraftingOrderPageMixin, "ShowGeneric", HookAfter)

    if ProfessionsFrame and ProfessionsFrame.OrdersPage and ProfessionsFrame.OrdersPage.HookScript
        and not ProfessionsFrame.OrdersPage.ahuiCustomListShowHooked then
        ProfessionsFrame.OrdersPage.ahuiCustomListShowHooked = true
        ProfessionsFrame.OrdersPage:HookScript("OnShow", function(self)
            if not CO:IsEnabled() then return end
            CO.activePageFrame = self
            if self.ahuiCustomList then
                self.ahuiCustomList._allowEmptyOnce = true
            end
            CL:StartLoadPoll(self)
        end)
    end

    if ProfessionsFrame and ProfessionsFrame.HookScript and not ProfessionsFrame.ahuiCustomListHidehooked then
        ProfessionsFrame.ahuiCustomListHidehooked = true
        ProfessionsFrame:HookScript("OnHide", function()
            if CO.visibleRowButtons then
                wipe(CO.visibleRowButtons)
            end
            if CO.ClearTemporaryBinding then CO:ClearTemporaryBinding() end
            CL._pollStamp = (CL._pollStamp or 0) + 1
            local pf = ProfessionsFrame.OrdersPage
            if pf and pf.ahuiCustomList then
                pf.ahuiCustomList._lastOrderCount = 0
                pf.ahuiCustomList._lastGoodOrders = nil
                pf.ahuiCustomList._lastGoodType = nil
                pf.ahuiCustomList._orderType = nil
                pf.ahuiCustomList._allowEmptyOnce = true
                if pf.ahuiCustomList.rows then
                    for _, row in ipairs(pf.ahuiCustomList.rows) do row:Hide() end
                end
            end
        end)
    end
    print("|cffb19cd9HironCraft CL|r attached order list hooks")
    return true
end

QueueRefresh = function()
    if not CL._refreshQueued then
        CL._refreshQueued = true
        C_Timer.After(0.05, function()
            CL._refreshQueued = false
            local pf = CO.activePageFrame or (ProfessionsFrame and ProfessionsFrame.OrdersPage)
            if pf then CL:Refresh(pf) end
        end)
    end
end

function CL:Init()
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("ADDON_LOADED")
    pcall(f.RegisterEvent, f, "CRAFTINGORDERS_UPDATE_PERSONAL_ORDER_COUNTS")
    pcall(f.RegisterEvent, f, "CRAFTINGORDERS_UPDATE_ORDER_COUNT")
    pcall(f.RegisterEvent, f, "CRAFTINGORDERS_CLAIM_PERSONAL_ORDER_RESPONSE")
    pcall(f.RegisterEvent, f, "CRAFTINGORDERS_UNCLAIM_ORDER_RESPONSE")
    pcall(f.RegisterEvent, f, "CRAFTINGORDERS_FULFILL_ORDER_RESPONSE")
    pcall(f.RegisterEvent, f, "CRAFTINGORDERS_CLAIMED_ORDER_ADDED")
    pcall(f.RegisterEvent, f, "CRAFTINGORDERS_CLAIMED_ORDER_REMOVED")
    pcall(f.RegisterEvent, f, "CRAFTINGORDERS_CRAFTER_ORDERS_UPDATED")
    pcall(f.RegisterEvent, f, "BAG_UPDATE_DELAYED")
    pcall(f.RegisterEvent, f, "PLAYERREAGENTBANKSLOTS_CHANGED")
    pcall(f.RegisterEvent, f, "TRADE_SKILL_SHOW")
    pcall(f.RegisterEvent, f, "TRADE_SKILL_DATA_SOURCE_CHANGED")
    f:SetScript("OnEvent", function(_, event, addonName)
        if event == "ADDON_LOADED" then
            if addonName == "Blizzard_Professions" then
                AttachHooks()
            end
        elseif event == "PLAYER_LOGIN" then
            CL:LoadStripeConfig()
            AttachHooks()
        elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" then
            if not CO:IsEnabled() then return end
            local pf = (ProfessionsFrame and ProfessionsFrame.OrdersPage)
            if pf and pf.ahuiCustomList then pf.ahuiCustomList._allowEmptyOnce = true end
            if event == "TRADE_SKILL_SHOW" then
                C_Timer.After(0, function() CL:SettleOnRecipes() end)
            end
            QueueRefresh()
        else
            QueueRefresh()
        end
    end)
    AttachHooks()
end

CL:Init()

SLASH_HIRONCRAFT_PROFITCLREFRESH1 = "/phclrefresh"
SlashCmdList["HIRONCRAFT_PROFITCLREFRESH"] = function()
    print("|cffb19cd9HironCraft CL|r manual refresh; attached=" .. tostring(hooksAttached))
    local pf = CO.activePageFrame or (ProfessionsFrame and ProfessionsFrame.OrdersPage)
    if pf then
        CL:Refresh(pf)
    else
        print("|cffff5555HironCraft CL|r no page frame")
    end
end

do
    local dbgFrame
    local CO_EVENTS = {
        "CRAFTINGORDERS_UPDATE_PERSONAL_ORDER_COUNTS",
        "CRAFTINGORDERS_UPDATE_ORDER_COUNT",
        "CRAFTINGORDERS_CLAIM_PERSONAL_ORDER_RESPONSE",
        "CRAFTINGORDERS_UNCLAIM_ORDER_RESPONSE",
        "CRAFTINGORDERS_FULFILL_ORDER_RESPONSE",
        "CRAFTINGORDERS_CLAIMED_ORDER_ADDED",
        "CRAFTINGORDERS_CLAIMED_ORDER_REMOVED",
        "CRAFTINGORDERS_CRAFTER_ORDERS_UPDATED",
        "CRAFTINGORDERS_DISPLAY_CRAFTER_ORDERS",
        "CRAFTINGORDERS_ORDER_PLACEMENT_RESPONSE",
        "CRAFTINGORDERS_CAN_REQUEST",
        "CRAFTINGORDERS_REQUEST_MORE_ORDERS_RESPONSE",
        "TRADE_SKILL_LIST_UPDATE",
        "TRADE_SKILL_SHOW",
        "TRADE_SKILL_DATA_SOURCE_CHANGED",
    }

    local function CountOrders()
        local pf = CO.activePageFrame or (ProfessionsFrame and ProfessionsFrame.OrdersPage)
        if not pf then return -1 end
        local ok, list = pcall(function() return CL:GetOrders(pf) end)
        if ok and type(list) == "table" then return #list end
        return -2
    end

    local function ApiCount()
        if not C_CraftingOrders or not C_CraftingOrders.GetCrafterOrders then return -1 end
        local ok, list = pcall(C_CraftingOrders.GetCrafterOrders)
        if ok and type(list) == "table" then return #list end
        return -2
    end

    SLASH_HIRONCRAFT_PROFITCLDBG1 = "/phcldbg"
    SlashCmdList["HIRONCRAFT_PROFITCLDBG"] = function()
        if dbgFrame and dbgFrame:IsEventRegistered("TRADE_SKILL_SHOW") then
            for _, e in ipairs(CO_EVENTS) do pcall(dbgFrame.UnregisterEvent, dbgFrame, e) end
            print("|cffff5555CL DBG|r выключен")
            return
        end
        if not dbgFrame then
            dbgFrame = CreateFrame("Frame")
            dbgFrame:SetScript("OnEvent", function(_, event, ...)
                local t = string.format("%.2f", GetTime())
                print(string.format("|cffb19cd9CL DBG|r [%s] %s  provider=%d  api=%d",
                    t, event, CountOrders(), ApiCount()))
            end)
        end
        for _, e in ipairs(CO_EVENTS) do pcall(dbgFrame.RegisterEvent, dbgFrame, e) end
        print("|cff66ff66CL DBG|r включён. Пройди сценарий профа1→профа2.")
    end
end
