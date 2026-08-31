local PT = HironCraftProfit
if not PT then return end
local L = PT.L

PT.AccountOverview_UI = PT.AccountOverview_UI or {}
local UI = PT.AccountOverview_UI

local FONT          = HironCraftProfit.FONT

local function IsFantasy()
    return PT.IsFantasyDesign and PT:IsFantasyDesign()
end

local DEFAULT_SCALE = HironCraftProfit.SCALE_DEFAULT
local SCALE_STEP    = HironCraftProfit.SCALE_STEP
local SCALE_MIN     = 0.8
local SCALE_MAX     = HironCraftProfit.SCALE_MAX
local SIZE_W, SIZE_H = 860, 420
local MIN_W, MIN_H   = 500, 260
local MAX_W, MAX_H   = 1400, 900
local ROW_H = 34
local HEADER_H = 24
local TITLE_GAP = 15
local NOTIFY_MIN_W = 280
local NOTIFY_MAX_W = 520
local NOTIFY_LINE_H = 14
local NOTIFY_PAD_X = 16
local NOTIFY_PAD_Y = 10

local COLS = {
	{ key="char",  w=180, title="AO_HDR_CHAR",  tip="AO_TIP_CHAR" },
	{ key="profgear", w=104, title="AO_HDR_PROF_EQUIP", tip="AO_TIP_PROF_EQUIP", filterable=true },
	{ key="c_df",  w=80,  title="AO_HDR_C_DF",  tip="AO_TIP_C_DF",  filterable=true },
	{ key="c_tww", w=80,  title="AO_HDR_C_TWW", tip="AO_TIP_C_TWW", filterable=true },
	{ key="c_mid", w=80,  title="AO_HDR_C_MID", tip="AO_TIP_C_MID", filterable=true },
	{ key="zeal",  w=80,  title="AO_HDR_ZEAL",  tip="AO_TIP_ZEAL",  filterable=true },

	{ key="kp_df",  w=80, title="AO_HDR_KP_DF",  tip="AO_TIP_KP_DF",  filterable=true },
	{ key="kp_tww", w=80, title="AO_HDR_KP_TWW", tip="AO_TIP_KP_TWW", filterable=true },
	{ key="kp_mid", w=80, title="AO_HDR_KP_MID", tip="AO_TIP_KP_MID", filterable=true },

	{ key="skin",   w=80, title="AO_HDR_SKIN",   tip="AO_TIP_SKIN",   filterable=true },
	{ key="dundun", w=80, title="AO_HDR_DUNDUN", tip="AO_TIP_DUNDUN", filterable=true },
	{ key="dmf",    w=80, title="DMF",           tip="AO_TIP_DMF",    filterable=true },
	{ key="tw",     w=80, title="AO_HDR_TW",     tip="AO_TIP_TW",     filterable=true },
}

local COL_BY_KEY = {}
local DEFAULT_COLUMN_ORDER = {}

for _, c in ipairs(COLS) do
    COL_BY_KEY[c.key] = c
    table.insert(DEFAULT_COLUMN_ORDER, c.key)
end

local function CopyDefaultColumnOrder()
    local order = {}

    for _, key in ipairs(DEFAULT_COLUMN_ORDER) do
        table.insert(order, key)
    end

    return order
end

local function NormalizeColumnOrder(order)
    local result = {}
    local seen = {}

    if type(order) == "table" then
        for _, key in ipairs(order) do
            if COL_BY_KEY[key] and not seen[key] then
                seen[key] = true
                table.insert(result, key)
            end
        end
    end

    for _, key in ipairs(DEFAULT_COLUMN_ORDER) do
        if not seen[key] then
            seen[key] = true
            table.insert(result, key)
        end
    end

    if result[1] ~= "char" then
        for i = 2, #result do
            if result[i] == "char" then
                table.remove(result, i)
                break
            end
        end

        table.insert(result, 1, "char")
    end

    return result
end

local function GetColumnOrder()
    HironCraftProfit_Config = HironCraftProfit_Config or {}

    local order = NormalizeColumnOrder(HironCraftProfit_Config.accountOverviewColumnOrder)
    HironCraftProfit_Config.accountOverviewColumnOrder = order

    return order
end

local function ResetColumnOrder()
    HironCraftProfit_Config = HironCraftProfit_Config or {}
    HironCraftProfit_Config.accountOverviewColumnOrder = CopyDefaultColumnOrder()
    return HironCraftProfit_Config.accountOverviewColumnOrder
end

local function GetOrderedColumns()
    local columns = {}

    for _, key in ipairs(GetColumnOrder()) do
        local col = COL_BY_KEY[key]
        if col then
            table.insert(columns, col)
        end
    end

    return columns
end

local function GetColumnOrderIndex(key)
    for i, k in ipairs(GetColumnOrder()) do
        if k == key then
            return i
        end
    end
end

local function CanMoveColumn(key, delta)
    if key == "char" then
        return false
    end

    local order = GetColumnOrder()
    local index

    for i, k in ipairs(order) do
        if k == key then
            index = i
            break
        end
    end

    if not index then
        return false
    end

    local target = index + delta
    return target >= 2 and target <= #order
end

local function MoveColumn(key, delta)
    if not CanMoveColumn(key, delta) then
        return false
    end

    local order = GetColumnOrder()
    local index

    for i, k in ipairs(order) do
        if k == key then
            index = i
            break
        end
    end

    local target = index + delta
    order[index], order[target] = order[target], order[index]
    HironCraftProfit_Config.accountOverviewColumnOrder = order

    return true
end

local CONCENTRATION_MAX = 1000
local CONC_VALUE_W = 23
local PROF_EQUIP_ICON_SIZE = 14
local PROF_EQUIP_ICON_GAP = 2
local PROF_EQUIP_ICON_COLS = 3
local PROF_EQUIP_ICON_MAX = 6
local PROF_EQUIP_QUALITY_ICON_SIZE = 9

local function GetBtnIcon(btn)
    return btn.icon or (btn.GetNormalTexture and btn:GetNormalTexture()) or nil
end

local function AddPressFX(btn)
    btn:HookScript("OnMouseDown", function(self)
        local tex = GetBtnIcon(self)
        if not tex then return end
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", 1, -1)
        tex:SetPoint("BOTTOMRIGHT", 1, -1)
        tex:SetVertexColor(0.7, 0.7, 0.7)
    end)
    btn:HookScript("OnMouseUp", function(self)
        local tex = GetBtnIcon(self)
        if not tex then return end
        tex:ClearAllPoints()
        tex:SetAllPoints()
        local v = self:IsMouseOver() and 1.3 or 1
        tex:SetVertexColor(v, v, v)
    end)
    btn:HookScript("OnLeave", function(self)
        local tex = GetBtnIcon(self)
        if not tex then return end
        tex:ClearAllPoints()
        tex:SetAllPoints()
        tex:SetVertexColor(1, 1, 1)
    end)
    return btn
end
PT.AddPressFX = AddPressFX

local function StyleIconBtn(btn, atlas, size)
    size = size or 18
    btn:SetSize(size, size)
    btn.icon = btn.icon or btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints()
    if atlas then btn.icon:SetAtlas(atlas) end
    btn:SetScript("OnEnter", function(self) self.icon:SetVertexColor(1.3, 1.3, 1.3) end)
    btn:SetScript("OnLeave", function(self) self.icon:SetVertexColor(1, 1, 1) end)
    AddPressFX(btn)
    return btn
end
PT.StyleIconBtn = StyleIconBtn

local EXP_LABEL = {
    df  = "DF",
    tww = "TWW",
    mid = "MID",
}

local COLOR_NORMAL = { 1, 1, 1 }
local COLOR_FULL   = { 0.2, 1.0, 0.2 }

local function GetProgressColor(done, total)
    if not total or total == 0 then
        return 1, 1, 1
    end

    local t = math.min(1, math.max(0, done / total))

    local r, g
    if t < 0.5 then
        r = 1
        g = t * 2
    else
        r = 2 - t * 2
        g = 1
    end

    return r, g, 0
end

local WEEKLY_ICONS = {
    trainer  = "quest-recurring-available",
    treasure = "VignetteLoot",
    treatise = "Levelup-Icon-Bag",
}

local WEEKLY_MARKS = {
    ok  = "common-icon-checkmark",
    bad = "common-icon-redx",
}

local SKIN_MARKS = {
    ok  = "common-icon-checkmark",
    bad = "common-icon-redx",
}

local function GetWeeklyStatus(charKey, expansion)
    if PT.AccountOverview_Data
        and PT.AccountOverview_Data.GetWeeklyStatus
    then
        return PT.AccountOverview_Data:GetWeeklyStatus(charKey, expansion)
    end
end

local CreateRow

local function ApplyBackdrop(f)
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    f:SetBackdropColor(0, 0, 0, 0.95)
    f:SetBackdropBorderColor(0.694, 0.612, 0.851, 1)

    if IsFantasy() then
        if not f.bgFantasy then
            f.bgFantasy = f:CreateTexture(nil, "BACKGROUND", nil, 1)
            f.bgFantasy:SetPoint("TOPLEFT", 2, -2)
            f.bgFantasy:SetPoint("BOTTOMRIGHT", -2, 2)
        end
        f.bgFantasy:SetAtlas("Professions-Recipe-Background")
        if f.bgFantasy:GetAtlas() then
            f.bgFantasy:Show()
            f:SetBackdropColor(0, 0, 0, 0.35)
        else
            f.bgFantasy:Hide()
        end
    end
end

local AO_STRATA_IDLE = "MEDIUM"
local AO_STRATA_ACTIVE = "DIALOG"
local AO_LEVEL_IDLE = 20
local AO_LEVEL_ACTIVE = 900

local function SetAccountOverviewActive(active)
    local f = UI.frame
    if not f then return end

    if active then
        f:SetFrameStrata(AO_STRATA_ACTIVE)
        f:SetFrameLevel(AO_LEVEL_ACTIVE)

        if f.Raise then
            f:Raise()
        end
    else
        f:SetFrameStrata(AO_STRATA_IDLE)
        f:SetFrameLevel(AO_LEVEL_IDLE)
    end
end

local function IsWindowLocked()
    return (InCombatLockdown and InCombatLockdown())
        or (PT.config and PT.config.lockWindows == true)
end

local function StartWindowMove(root)
    if not root or IsWindowLocked() then return end

    SetAccountOverviewActive(true)
    root:StartMoving()
end

local function StopWindowMove(root)
    if not root then return end
    root:StopMovingOrSizing()
end

local function MakeChildDraggable(child, root)
    if not child or not root or not child.RegisterForDrag then return end

    child:EnableMouse(true)
    child:RegisterForDrag("LeftButton")

    child:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            SetAccountOverviewActive(true)
        end
    end)

    child:SetScript("OnDragStart", function()
        StartWindowMove(root)
    end)

    child:SetScript("OnDragStop", function()
        StopWindowMove(root)
    end)
end

local function KillScrollFrameTextures(sf)
    for _, region in ipairs({ sf:GetRegions() }) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" then
            region:SetTexture(nil)
            region:Hide()
        end
    end
end

local function GetVisibleColumns(frameWidth, filters)
    local visible = {}
    local totalWidth = 8

    for _, c in ipairs(GetOrderedColumns()) do
        if not c.filterable or filters[c.key] ~= false then
            table.insert(visible, c)
            totalWidth = totalWidth + c.w
        end
    end

    local maxRight = math.max(0, frameWidth - 24)

    while #visible > 0 and totalWidth > maxRight do
        local removed = false

        for i = #visible, 1, -1 do
            local c = visible[i]
            if c.filterable then
                totalWidth = totalWidth - c.w
                table.remove(visible, i)
                removed = true
                break
            end
        end

        if not removed then
            break
        end
    end

    return visible
end

local SORTABLE_COLUMNS = {}

for _, c in ipairs(COLS) do
    SORTABLE_COLUMNS[c.key] = true
end

local function GetSortDefaultDir(key)
    if key == "char" then
        return "asc"
    end

    return "desc"
end

local function GetSortState()
    HironCraftProfit_Config = HironCraftProfit_Config or {}

    local state = HironCraftProfit_Config.accountOverviewSort

    if type(state) ~= "table" then
        state = {
            key = "default",
            dir = "desc",
        }

        HironCraftProfit_Config.accountOverviewSort = state
    end

    if state.key ~= "default" and not SORTABLE_COLUMNS[state.key] then
        state.key = "default"
    end

    if state.dir ~= "asc" and state.dir ~= "desc" then
        state.dir = GetSortDefaultDir(state.key)
    end

    return state
end

local function IsManualOrder()
    HironCraftProfit_Config = HironCraftProfit_Config or {}
    return HironCraftProfit_Config.accountOverviewManualOrder == true
end

local function IsNoNewChars()
    HironCraftProfit_Config = HironCraftProfit_Config or {}
    return HironCraftProfit_Config.accountOverviewNoNewChars == true
end

local function GetManualOrder()
    HironCraftProfit_Config = HironCraftProfit_Config or {}
    if type(HironCraftProfit_Config.accountOverviewManualSort) ~= "table" then
        HironCraftProfit_Config.accountOverviewManualSort = {}
    end
    return HironCraftProfit_Config.accountOverviewManualSort
end

function UI:SetSortColumn(key)
    if IsManualOrder() then
        return
    end
    if not SORTABLE_COLUMNS[key] then
        return
    end

    local state = GetSortState()

    if state.key == key then
        state.dir = state.dir == "asc" and "desc" or "asc"
    else
        state.key = key
        state.dir = GetSortDefaultDir(key)
    end

    self:RebuildHeader()
    self:Refresh()
end

local function CreateSortArrow(holder, key)
    if IsManualOrder() then
        return nil
    end

    local state = GetSortState()

    if state.key ~= key then
        return nil
    end

    local arrow = holder:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12)
    arrow:SetAtlas("uitools-icon-chevron-down")
    arrow:SetRotation(state.dir == "asc" and math.pi or 0)

    return arrow
end

local function LayoutConcLine(line)
    if not line or not line.group or not line.text or not line.icon or not line.notifyBtn then
        return
    end

    local group = line.group
    local showNotify = line.notifyBtn:IsShown()
    local showIcon = line.icon:IsShown()

    local textWidth = line.text:GetWidth() or CONC_VALUE_W
    if textWidth < CONC_VALUE_W then
        textWidth = CONC_VALUE_W
    end

    local x = 0

    line.notifyBtn:ClearAllPoints()
    line.icon:ClearAllPoints()
    line.text:ClearAllPoints()

    if showNotify then
        line.notifyBtn:SetPoint("LEFT", group, "LEFT", x, 0)
        x = x + 14 + 2
    end

    if showIcon then
        line.icon:SetPoint("LEFT", group, "LEFT", x, 0)
        x = x + 14 + 4
    end

    line.text:SetPoint("LEFT", group, "LEFT", x, 0)

    group:SetWidth(math.min(line:GetWidth(), x + textWidth))
    group:ClearAllPoints()
    group:SetPoint("CENTER", line, "CENTER", 0, 0)
end

local function CreateHeader(parent)
    local header = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 12, -36)
    header:SetPoint("TOPRIGHT", -12, -36)
    header:SetHeight(HEADER_H)

    header:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    header:SetBackdropColor(1, 1, 1, 0.06)
    header:SetBackdropBorderColor(1, 1, 1, 0.15)

    if IsFantasy() then
        header.bgFantasy = header:CreateTexture(nil, "BACKGROUND")
        header.bgFantasy:SetAllPoints()
        header.bgFantasy:SetAtlas("Professions-Specializations-Background-Footer")
        if header.bgFantasy:GetAtlas() then
            header:SetBackdropColor(0, 0, 0, 0)
            header:SetBackdropBorderColor(0, 0, 0, 0)
        else
            header.bgFantasy:Hide()
        end
    end

    MakeChildDraggable(header, parent)

    local filters = PT.AccountOverview_Data:GetColumnFilters()
    local visibleCols = GetVisibleColumns(parent:GetWidth(), filters)
    local x = 8

    local function AddInfoIcon(holder, fs, tipText)
        if not tipText then
            return
        end

        local info = CreateFrame("Frame", nil, holder)
        info:SetSize(20, 20)
        info:SetFrameLevel(holder:GetFrameLevel() + 5)

        info:SetPoint("LEFT", fs, "RIGHT", -3, 4)
        info:EnableMouse(true)

        local icon = info:CreateTexture(nil, "OVERLAY")
        icon:SetAllPoints()
        icon:SetTexture("Interface\\COMMON\\help-i")

        info:SetScript("OnEnter", function(self)
            UI:ShowHeaderTooltip(self, tipText)
        end)

        info:SetScript("OnLeave", function()
            UI:HideHeaderTooltip()
        end)

        return info
    end

    for _, c in ipairs(visibleCols) do
        local colKey = c.key

        local holder = CreateFrame("Button", nil, header)
        holder:SetPoint("LEFT", header, "LEFT", x, 0)
        holder:SetSize(c.w, HEADER_H)
        holder:RegisterForClicks("LeftButtonUp")
        MakeChildDraggable(holder, parent)

        holder:SetScript("OnClick", function(_, button)
            if button == "LeftButton" then
                UI:SetSortColumn(colKey)
            end
        end)

        local titleText = L[c.title] or c.title
        local tipText = c.tip and (L[c.tip] or c.tip) or nil

        if c.key == "char" then
            local arrow = CreateSortArrow(holder, colKey)

            if arrow then
                arrow:SetPoint("LEFT", holder, "LEFT", 0, 0)
            end

            local fs = holder:CreateFontString(nil, "OVERLAY")
            fs:SetFont(FONT, 12, "")
            fs:SetPoint("LEFT", holder, "LEFT", arrow and 14 or 0, 0)
            fs:SetJustifyH("LEFT")
            fs:SetText(titleText)

            AddInfoIcon(holder, fs, tipText)
        else
            local fs = holder:CreateFontString(nil, "OVERLAY")
            fs:SetFont(FONT, 12, "")
            fs:SetPoint("CENTER", holder, "CENTER", 0, 0)
            fs:SetJustifyH("CENTER")
            fs:SetText(titleText)

            local arrow = CreateSortArrow(holder, colKey)

            if arrow then
                arrow:SetPoint("RIGHT", fs, "LEFT", -2, 0)
            end

            AddInfoIcon(holder, fs, tipText)
        end

        x = x + c.w
    end

    return header
end

local function GetCharacterKey()
    local name = UnitName("player")
    local realm = GetNormalizedRealmName()
    if not name then return nil end
    return name .. "-" .. (realm or "")
end

local function GetCharNote(charKey)
    if not charKey then return "" end
    if HironCraftProfit_DB and HironCraftProfit_DB.charNotes and HironCraftProfit_DB.charNotes[charKey] then
        return HironCraftProfit_DB.charNotes[charKey] or ""
    end
    return ""
end

local function GetCharClassColor(charKey)
    if not charKey then return nil end
    local chars = HironCraftProfit_DB and HironCraftProfit_DB.accountOverview and HironCraftProfit_DB.accountOverview.chars
    local entry = chars and chars[charKey]
    local classFile = entry and entry.class
    if not classFile then return nil end
    local c = (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(classFile))
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile])
    if not c then return nil end
    return c.r, c.g, c.b
end

local function SetCharNote(charKey, text)
    if not charKey then return end
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB.charNotes = HironCraftProfit_DB.charNotes or {}
    text = tostring(text or "")
    if text == "" then
        HironCraftProfit_DB.charNotes[charKey] = nil
    else
        HironCraftProfit_DB.charNotes[charKey] = text
    end
end

local function GetProfessionEquipment(charKey)
    if PT.AccountOverview_Data
       and PT.AccountOverview_Data.GetProfessionEquipment
    then
        return PT.AccountOverview_Data:GetProfessionEquipment(charKey)
    end
end

function UI:ShowProfessionGearTooltip(anchor, item, charKey)
    if not anchor or not item or not GameTooltip then
        return
    end

    GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")

    local shown = false
    if charKey == GetCharacterKey() and item.slot then
        shown = GameTooltip:SetInventoryItem("player", item.slot) and true or false
    end

    if not shown and item.link and item.link ~= "" then
        GameTooltip:SetHyperlink(item.link)
        shown = true
    elseif not shown and item.itemID then
        if GameTooltip.SetItemByID then
            GameTooltip:SetItemByID(item.itemID)
        else
            GameTooltip:SetHyperlink("item:" .. tostring(item.itemID))
        end
        shown = true
    end

    if shown then
        GameTooltip:Show()
    end
end

function UI:HideProfessionGearTooltip()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

local function GetKP(charKey, expansion)
    if not PT.AccountOverview_Data
       or not PT.AccountOverview_Data.GetKPByProfession
    then
        return nil
    end

    local data = PT.AccountOverview_Data:GetKPByProfession(charKey, expansion)
    if type(data) ~= "table" then
        return nil
    end

    if data.profs then
        return data.profs
    end

    return data
end

local function FormatConcentration(data)
    if type(data) ~= "table" then
        return nil
    end

    local sum = 0
    for _, info in pairs(data) do
        sum = sum + (info.value or 0)
    end

    return sum
end

local function GetConcentration(charKey, expansion)
    if PT.AccountOverview_Data
       and PT.AccountOverview_Data.GetConcentration
    then
        return PT.AccountOverview_Data:GetConcentration(charKey, expansion)
    end
end

local function GetZeal(charKey)
    if PT.AccountOverview_Data
       and PT.AccountOverview_Data.GetZeal
    then
        return PT.AccountOverview_Data:GetZeal(charKey)
    end
end

local function GetDundunWeekly(charKey)
    if PT.AccountOverview_Data
       and PT.AccountOverview_Data.GetDundunWeekly
    then
        return PT.AccountOverview_Data:GetDundunWeekly(charKey)
    end
end

local function GetDarkmoonStatus(charKey)
    if PT.AccountOverview_Data
       and PT.AccountOverview_Data.GetDarkmoonStatus
    then
        return PT.AccountOverview_Data:GetDarkmoonStatus(charKey)
    end
end

local WEEKLY_SORT_KEYS = {
    "trainer",
    "treasure",
    "treatise",
}

local function GetProfessionCount(charKey)
    local D = PT.AccountOverview_Data
    if not D then return 0 end

    local profs = {}

    for _, exp in ipairs({ "df", "tww", "mid" }) do
        local weekly = D:GetWeeklyStatus(charKey, exp)
        if type(weekly) == "table" then
            for profId in pairs(weekly) do
                profs[profId] = true
            end
        end
    end

    for _, exp in ipairs({ "df", "tww", "mid" }) do
        local conc = D:GetConcentration(charKey, exp)
        if type(conc) == "table" then
            for skillLine in pairs(conc) do
                profs[skillLine] = true
            end
        end
    end

    local dmf = D:GetDarkmoonStatus(charKey)
    if type(dmf) == "table" then
        for skillLine in pairs(dmf) do
            profs[skillLine] = true
        end
    end

    local count = 0
    for _ in pairs(profs) do
        count = count + 1
    end

    return count
end

local function MakeSortScore(has, ...)
    return {
        has = has == true,
        values = { ... },
    }
end

local function MakeEmptySortScore()
    return MakeSortScore(false, 0)
end

local function GetConcentrationSortScore(charKey, expansion)
    local data = GetConcentration(charKey, expansion)

    if type(data) ~= "table" or not next(data) then
        return MakeEmptySortScore()
    end

    local count = 0
    local sum = 0
    local fullCount = 0

    for _, info in pairs(data) do
        count = count + 1

        local value = tonumber(info.value) or 0
        sum = sum + value

        if value >= CONCENTRATION_MAX then
            fullCount = fullCount + 1
        end
    end

    return MakeSortScore(count > 0, sum, fullCount, count)
end

local function GetWeeklyKPSortScore(charKey, expansion)
    local data = GetWeeklyStatus(charKey, expansion)

    if type(data) ~= "table" or not next(data) then
        return MakeEmptySortScore()
    end

    local profCount = 0
    local done = 0
    local total = 0

    for _, info in pairs(data) do
        profCount = profCount + 1

        if type(info.weekly) == "table" then
            for _, key in ipairs(WEEKLY_SORT_KEYS) do
                total = total + 1

                if info.weekly[key] then
                    done = done + 1
                end
            end
        end
    end

    local ratio = total > 0 and done / total or 0

    return MakeSortScore(total > 0, done, ratio, profCount)
end

local function GetSkinningSortScore(charKey)
    local D = PT.AccountOverview_Data
    if not D or not D.GetSkinningProgress then
        return MakeEmptySortScore()
    end

    local done, total = D:GetSkinningProgress(charKey)

    done = tonumber(done)
    total = tonumber(total)

    if not done or not total or total <= 0 then
        return MakeEmptySortScore()
    end

    return MakeSortScore(true, done, done / total, total)
end

local function GetDundunSortScore(charKey)
    local data = GetDundunWeekly(charKey)

    if type(data) ~= "table" then
        return MakeEmptySortScore()
    end

    local amount = tonumber(data.value) or 0
    local maxVal = tonumber(data.max) or 8
    local quantity = tonumber(data.quantity) or 0
    local done = amount >= maxVal and 1 or 0

    return MakeSortScore(true, done, amount, quantity)
end

local function GetDMFSortScore(charKey)
    local data = GetDarkmoonStatus(charKey)

    if type(data) ~= "table" or not next(data) then
        return MakeEmptySortScore()
    end

    local done = 0
    local total = 0

    for _, info in pairs(data) do
        total = total + 1

        if info.done then
            done = done + 1
        end
    end

    local ratio = total > 0 and done / total or 0

    return MakeSortScore(total > 0, done, ratio, total)
end

local function GetTimewalkingSortScore(charKey)
    local D = PT.AccountOverview_Data
    if not D or not D.GetTimewalkingStatus then
        return MakeEmptySortScore()
    end

    local data = D:GetTimewalkingStatus(charKey)

    if type(data) ~= "table" then
        return MakeEmptySortScore()
    end

    return MakeSortScore(true, data.done and 1 or 0)
end

local function GetProfessionEquipmentSortScore(charKey)
    local data = GetProfessionEquipment(charKey)

    if type(data) ~= "table" or not next(data) then
        return MakeEmptySortScore()
    end

    local count = 0
    local itemSum = 0

    for _, item in ipairs(data) do
        count = count + 1
        itemSum = itemSum + (tonumber(item.itemID) or 0)
    end

    return MakeSortScore(count > 0, count, itemSum)
end

local function GetColumnSortScore(charKey, key)
    if key == "profgear" then
        return GetProfessionEquipmentSortScore(charKey)
    elseif key == "c_df" then
        return GetConcentrationSortScore(charKey, "df")
    elseif key == "c_tww" then
        return GetConcentrationSortScore(charKey, "tww")
    elseif key == "c_mid" then
        return GetConcentrationSortScore(charKey, "mid")
    elseif key == "zeal" then
        local data = GetZeal(charKey)
        if type(data) ~= "table" or not next(data) then
            return MakeEmptySortScore()
        end
        local count, sum = 0, 0
        for _, info in pairs(data) do
            count = count + 1
            sum = sum + (tonumber(info.value) or 0)
        end
        return MakeSortScore(count > 0, sum, count)

    elseif key == "kp_df" then
        return GetWeeklyKPSortScore(charKey, "df")
    elseif key == "kp_tww" then
        return GetWeeklyKPSortScore(charKey, "tww")
    elseif key == "kp_mid" then
        return GetWeeklyKPSortScore(charKey, "mid")

    elseif key == "skin" then
        return GetSkinningSortScore(charKey)
    elseif key == "dundun" then
        return GetDundunSortScore(charKey)
    elseif key == "dmf" then
        return GetDMFSortScore(charKey)
    elseif key == "tw" then
        return GetTimewalkingSortScore(charKey)
    end

    return MakeEmptySortScore()
end

local function CompareSortScores(aScore, bScore, dir)
    if aScore.has ~= bScore.has then
        return aScore.has
    end

    local aValues = aScore.values or {}
    local bValues = bScore.values or {}
    local count = math.max(#aValues, #bValues)

    for i = 1, count do
        local a = tonumber(aValues[i]) or 0
        local b = tonumber(bValues[i]) or 0

        if a ~= b then
            if dir == "asc" then
                return a < b
            end

            return a > b
        end
    end

    return nil
end

local function CollectCharacters()
    local candidates = {}
    local seen = {}

    local function add(key)
        if key and not seen[key] then
            seen[key] = true
            table.insert(candidates, key)
        end
    end

    if HironCraftProfit_DB
       and HironCraftProfit_DB.accountOverview
       and HironCraftProfit_DB.accountOverview.chars
    then
        for charKey in pairs(HironCraftProfit_DB.accountOverview.chars) do
            if type(charKey) == "string" then
                local n, r = strsplit("-", charKey)
                if n and r and r ~= "" then
                    add(n .. "-" .. r)
                end
            end
        end
    end

    local current = GetCharacterKey()
    add(current)

    local manual = GetManualOrder()
    local inManual = {}
    for i, k in ipairs(manual) do inManual[k] = i end

    local noNew = IsNoNewChars()
    local chars = {}
    for _, key in ipairs(candidates) do
        if inManual[key] then
            chars[#chars + 1] = key
        elseif not noNew then
            manual[#manual + 1] = key
            inManual[key] = #manual
            chars[#chars + 1] = key
        end
    end

    if IsManualOrder() then
        local existing = {}
        for _, k in ipairs(chars) do existing[k] = true end
        local ordered = {}
        for _, k in ipairs(manual) do
            if existing[k] then
                ordered[#ordered + 1] = k
                existing[k] = nil
            end
        end
        for _, k in ipairs(chars) do
            if existing[k] then ordered[#ordered + 1] = k end
        end
        return ordered
    end

    local sortState = GetSortState()
    local sortKey = sortState.key or "default"
    local dir = sortState.dir or "desc"

    table.sort(chars, function(a, b)
        if a == current then return true end
        if b == current then return false end

        if sortKey == "char" then
            if dir == "desc" then
                return a > b
            end

            return a < b
        end

        if sortKey ~= "default" then
            local result = CompareSortScores(
                GetColumnSortScore(a, sortKey),
                GetColumnSortScore(b, sortKey),
                dir
            )

            if result ~= nil then
                return result
            end

            return a < b
        end

        local aCount = GetProfessionCount(a)
        local bCount = GetProfessionCount(b)

        if aCount ~= bCount then
            return aCount > bCount
        end

        return a < b
    end)

    return chars
end

function UI:DragTargetIndex()
    local f = self.frame
    local scroll = f and f.scroll
    if not scroll then return 1 end

    local _, my = GetCursorPosition()
    local scale = scroll:GetEffectiveScale()
    if scale == 0 then scale = 1 end
    my = my / scale

    local top = scroll:GetTop()
    if not top then return 1 end

    local yFromTop = (top - my) + scroll:GetVerticalScroll()
    return math.floor(yFromTop / ROW_H) + 1
end

function UI:EnsureDragVisuals()
    if self._dragGhost then return end
    local f = self.frame
    if not f then return end

    local ghost = CreateFrame("Frame", nil, f, "BackdropTemplate")
    ghost:SetFrameStrata("TOOLTIP")
    ghost:SetSize(170, 22)
    ghost:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    ghost:SetBackdropColor(0.10, 0.10, 0.14, 0.95)
    ghost:SetBackdropBorderColor(0.694, 0.612, 0.851, 1)
    ghost.text = ghost:CreateFontString(nil, "OVERLAY")
    ghost.text:SetFont(FONT, 12, "OUTLINE")
    ghost.text:SetPoint("LEFT", 6, 0)
    ghost.text:SetPoint("RIGHT", -6, 0)
    ghost.text:SetJustifyH("LEFT")
    ghost:Hide()
    self._dragGhost = ghost

    if f.content then
        local line = f.content:CreateTexture(nil, "OVERLAY")
        line:SetHeight(2)
        line:SetColorTexture(0.694, 0.612, 0.851, 1)
        line:Hide()
        self._dragLine = line
    end
end

function UI:UpdateDragVisuals()
    if not self._rowDrag then return end
    local f = self.frame
    if not f then return end

    self:EnsureDragVisuals()

    if self._dragGhost then
        local mx, my = GetCursorPosition()
        local s = self._dragGhost:GetEffectiveScale()
        if s == 0 then s = 1 end
        self._dragGhost:ClearAllPoints()
        self._dragGhost:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", mx / s + 14, my / s + 10)
    end

    if self._dragLine and f.content then
        local nRows = (f.content.rows and #f.content.rows) or 0
        local idx = math.max(1, math.min(nRows + 1, self:DragTargetIndex()))
        local y = -2 - (idx - 1) * ROW_H + 1
        self._dragLine:ClearAllPoints()
        self._dragLine:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, y)
        self._dragLine:SetPoint("RIGHT", f.content, "RIGHT", 0, 0)
        self._dragLine:Show()
    end
end

function UI:BeginRowDrag(row)
    if not row or not row.charKey then return end
    self._rowDrag = row.charKey
    self._dragRow = row

    self:EnsureDragVisuals()
    if self._dragGhost then
        local name = strsplit("-", row.charKey)
        self._dragGhost.text:SetText(name or row.charKey)
        self._dragGhost:Show()
    end

    row:SetAlpha(0.35)
    self:UpdateDragVisuals()
end

function UI:EndRowDrag(row)
    local dragKey = self._rowDrag
    self._rowDrag = nil

    if self._dragGhost then self._dragGhost:Hide() end
    if self._dragLine then self._dragLine:Hide() end
    if self._dragRow then self._dragRow:SetAlpha(1) end
    self._dragRow = nil

    if not dragKey then return end

    local chars = CollectCharacters()
    local list = {}
    for _, k in ipairs(chars) do
        if k ~= dragKey then list[#list + 1] = k end
    end

    local targetIndex = math.max(1, math.min(#list + 1, self:DragTargetIndex()))
    table.insert(list, targetIndex, dragKey)

    local manual = GetManualOrder()
    wipe(manual)
    for _, k in ipairs(list) do manual[#manual + 1] = k end

    self:Refresh()
end

local BuildColumnFilterItems

local function RefreshColumnFilterDropdown(ui)
    if not ui
       or not ui.frame
       or not ui.frame.filterButton
       or not PT.Dropdown
       or not PT.Dropdown.Show
    then
        return
    end

    PT.Dropdown:Show({
        owner    = ui.frame.filterButton,
        keepOpen = true,
        items    = BuildColumnFilterItems(ui),
    })
end

local function ApplyColumnLayoutChange(ui, keepDropdownOpen)
    if not ui then return end

    ui:RebuildHeader()
    ui:Refresh()

    if keepDropdownOpen then
        RefreshColumnFilterDropdown(ui)
    end
end

BuildColumnFilterItems = function(ui)
    local filters = PT.AccountOverview_Data:GetColumnFilters()
    local items = {}

    for _, c in ipairs(GetOrderedColumns()) do
        if c.filterable then
            local enabled = filters[c.key] ~= false

            table.insert(items, {
                text    = L[c.title] or c.title,
                icon    = enabled
                    and "Interface\\Buttons\\UI-CheckBox-Check"
                    or "Interface\\Buttons\\UI-CheckBox-Up",
                checked = enabled,
                actionButtons = {
                    {
                        atlas = "uitools-icon-chevron-down",
                        rotation = math.pi,
                        disabled = not CanMoveColumn(c.key, -1),
                        onClick = function()
                            MoveColumn(c.key, -1)
                            ApplyColumnLayoutChange(ui, true)
                        end,
                    },
                    {
                        atlas = "uitools-icon-chevron-down",
                        disabled = not CanMoveColumn(c.key, 1),
                        onClick = function()
                            MoveColumn(c.key, 1)
                            ApplyColumnLayoutChange(ui, true)
                        end,
                    },
                },
                onClick = function()
                    filters[c.key] = not enabled
                    ApplyColumnLayoutChange(ui, true)
                end,
            })
        end
    end

    table.insert(items, {
        text = L["AO_FILTER_RESET_ORDER"] or "Reset column order",
        icon = "Interface\\Buttons\\UI-RefreshButton",
        onClick = function()
            ResetColumnOrder()
            ApplyColumnLayoutChange(ui, true)
        end,
    })

    return items
end

function UI:RebuildHeader()
    local f = self.frame
    if not f then return end

    if f.header then
        f.header:Hide()
        f.header:SetParent(nil)
        f.header = nil
    end

    f.header = CreateHeader(f)

    if f.scroll then
        f.scroll:ClearAllPoints()
        f.scroll:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, -6)
        f.scroll:SetPoint("BOTTOMRIGHT", -12, 12)
        f.scroll:SetVerticalScroll(0)
    end
end

function UI:SetScale(delta)
    HironCraftProfit_Config = HironCraftProfit_Config or {}

    local cur = HironCraftProfit_Config.accountOverviewScale or DEFAULT_SCALE
    local nextScale = cur + delta

    nextScale = math.max(SCALE_MIN, math.min(SCALE_MAX, nextScale))
    HironCraftProfit_Config.accountOverviewScale = nextScale

    if self.frame then
        self.frame:SetScale(nextScale)
    end
end

function UI:ResetScale()
    HironCraftProfit_Config = HironCraftProfit_Config or {}
    HironCraftProfit_Config.accountOverviewScale = DEFAULT_SCALE

    if self.frame then
        self.frame:SetScale(DEFAULT_SCALE)
    end
end

function UI:Create()
    if self.frame then return self.frame end

    local f = CreateFrame("Frame", "HironCraftProfitAccountOverviewFrame", UIParent, "BackdropTemplate")

    HironCraftProfit_Config = HironCraftProfit_Config or {}
    local savedW = HironCraftProfit_Config.accountOverviewWidth or SIZE_W
    local savedH = HironCraftProfit_Config.accountOverviewHeight or SIZE_H

    f:SetSize(savedW, savedH)
    f:SetPoint("CENTER")

    local scale = HironCraftProfit_Config.accountOverviewScale or DEFAULT_SCALE
    f:SetScale(scale)
    f:SetFrameStrata(AO_STRATA_IDLE)
    f:SetFrameLevel(AO_LEVEL_IDLE)
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMouseMotionEnabled(true)
	f:EnableMouseWheel(true)
    f:SetResizable(true)
    f:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
    f:SetUserPlaced(true)

	f:SetScript("OnMouseUp", function(self, button)
		if button == "MiddleButton" and IsAltKeyDown() then
			UI:ResetScale()
		end
	end)

	f:SetScript("OnMouseWheel", function(self, delta)
		if not IsAltKeyDown() then
			return
		end

		if delta > 0 then
			UI:SetScale(SCALE_STEP)
		else
			UI:SetScale(-SCALE_STEP)
		end
	end)

    ApplyBackdrop(f)
    f:Hide()
    if HironCraftProfit.RegisterEscClose then HironCraftProfit:RegisterEscClose(f) end

	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
    f:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            SetAccountOverviewActive(true)
        end
    end)
    f:SetScript("OnDragStart", function(self)
        StartWindowMove(self)
    end)

    f:SetScript("OnDragStop", function(self)
        StopWindowMove(self)
    end)

    f.isResizing = false

    local resizeBtn = CreateFrame("Frame", nil, f)
    resizeBtn:SetSize(16, 16)
    resizeBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
    resizeBtn:SetFrameStrata(f:GetFrameStrata())
    resizeBtn:SetFrameLevel(f:GetFrameLevel() + 50)
    resizeBtn:EnableMouse(true)

    local resizeTex = resizeBtn:CreateTexture(nil, "OVERLAY")
    resizeTex:SetPoint("TOPLEFT", resizeBtn, "TOPLEFT", 2, -2)
    resizeTex:SetPoint("BOTTOMRIGHT", resizeBtn, "BOTTOMRIGHT", -2, 2)
    resizeTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeTex:SetAlpha(0.85)

    resizeBtn:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        if InCombatLockdown() then return end

        f.isResizing = true
        f:StartSizing("BOTTOMRIGHT")
        resizeTex:SetAlpha(1)
    end)

    resizeBtn:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" then return end

        f:StopMovingOrSizing()
        f.isResizing = false

        HironCraftProfit_Config = HironCraftProfit_Config or {}
        HironCraftProfit_Config.accountOverviewWidth = math.floor(f:GetWidth())
        HironCraftProfit_Config.accountOverviewHeight = math.floor(f:GetHeight())

        if f.scroll and f.header then
            f.scroll:ClearAllPoints()
            f.scroll:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, -6)
            f.scroll:SetPoint("BOTTOMRIGHT", -12, 12)
        end

        UI:RebuildHeader()
        UI:Refresh()
        resizeTex:SetAlpha(0.85)
    end)

    resizeBtn:SetScript("OnEnter", function()
        resizeTex:SetAlpha(1)
    end)

    resizeBtn:SetScript("OnLeave", function()
        if not IsMouseButtonDown("LeftButton") then
            resizeTex:SetAlpha(0.85)
        end
    end)

    f.resizeBtn = resizeBtn

    f:SetScript("OnSizeChanged", function(self)
        if self.content and self.scroll then
            self.content:SetWidth(math.max(1, self.scroll:GetWidth()))
        end
        UI:RebuildHeader()
    end)

    f._ahuiLastLeftDown = false

    f:HookScript("OnUpdate", function(self)
        local down = IsMouseButtonDown("LeftButton")

        if down and not self._ahuiLastLeftDown then
            if not self:IsMouseOver() then
                SetAccountOverviewActive(false)
            end
        end

        self._ahuiLastLeftDown = down

        if UI._rowDrag then
            UI:UpdateDragVisuals()
        end
    end)

    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetFont(FONT, 14, "OUTLINE")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText(L["AO_TITLE"] or "Account Overview")
    f.title = title

	local info = CreateFrame("Frame", nil, f)
	info:SetSize(20, 20)
	info:SetPoint("LEFT", title, "RIGHT", -2, 4)
	info:EnableMouse(true)

	local icon = info:CreateTexture(nil, "OVERLAY")
	icon:SetAllPoints()
	icon:SetTexture("Interface\\COMMON\\help-i")

	info:SetScript("OnEnter", function(self)
		UI:ShowHeaderTooltip(self, L["AO_SCALE_TIP"])
	end)

	info:SetScript("OnLeave", function()
		UI:HideHeaderTooltip()
	end)

    local close = CreateFrame("Button", nil, f)
    close:SetPoint("TOPRIGHT", -6, -6)
    StyleIconBtn(close, "uitools-icon-close")
    close:SetScript("OnClick", function() f:Hide() end)

	local reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	reset:SetSize(80, 20)
	reset:SetPoint("RIGHT", close, "LEFT", -6, 0)
	reset:SetText(L["AO_RESET"] or "Reset")

	if reset.Text then
		reset.Text:SetFont(FONT, 12, "OUTLINE")
		reset.Text:SetTextColor(1, 1, 1)
	end

	reset:SetScript("OnClick", function()
		UI:ConfirmReset()
	end)

	f.resetButton = reset

	local filter = CreateFrame("Button", nil, f)
	filter:SetSize(20, 20)
	filter:SetPoint("RIGHT", reset, "LEFT", -5, 0)
	filter:EnableMouse(true)

	filter:SetScript("OnClick", function(self)
		PT.Dropdown:Show({
			owner    = self,
			keepOpen = true,
			items    = BuildColumnFilterItems(UI),
		})
	end)

	local filterIcon = filter:CreateTexture(nil, "ARTWORK")
	filterIcon:SetAllPoints()
	filterIcon:SetAtlas("uitools-icon-settings")

	filter.icon = filterIcon
	f.filterButton = filter

	filter:SetScript("OnEnter", function(self)
		self.icon:SetVertexColor(1.3, 1.3, 1.3)
		UI:ShowHeaderTooltip(self, L["AO_FILTER_TIP"] or "Column filters")
	end)

	filter:SetScript("OnLeave", function()
		UI:HideHeaderTooltip()
	end)
	AddPressFX(filter)

	local cbManual = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	cbManual:SetSize(18, 18)
	cbManual:SetPoint("TOPRIGHT", filter, "TOPLEFT", -2, 4)
	cbManual:SetChecked(IsManualOrder())
	local lblManual = cbManual:CreateFontString(nil, "OVERLAY")
	lblManual:SetFont(FONT, 11, "")
	lblManual:SetPoint("RIGHT", cbManual, "LEFT", -2, 0)
	lblManual:SetText(L["AO_MANUAL_ORDER"] or "Свой порядок")
	cbManual:SetScript("OnClick", function(self)
		HironCraftProfit_Config = HironCraftProfit_Config or {}
		HironCraftProfit_Config.accountOverviewManualOrder = self:GetChecked() and true or false
		UI:RebuildHeader()
		UI:Refresh()
	end)
	cbManual:SetScript("OnEnter", function(self)
		UI:ShowHeaderTooltip(self, L["AO_MANUAL_ORDER_TIP"] or "Перетаскивай строки мышью; сортировка по колонкам отключается")
	end)
	cbManual:SetScript("OnLeave", function() UI:HideHeaderTooltip() end)
	f.manualOrderCheck = cbManual

	local cbNoNew = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	cbNoNew:SetSize(18, 18)
	cbNoNew:SetPoint("TOPRIGHT", cbManual, "BOTTOMRIGHT", 0, 0)
	cbNoNew:SetChecked(IsNoNewChars())
	local lblNoNew = cbNoNew:CreateFontString(nil, "OVERLAY")
	lblNoNew:SetFont(FONT, 11, "")
	lblNoNew:SetPoint("RIGHT", cbNoNew, "LEFT", -2, 0)
	lblNoNew:SetText(L["AO_NO_NEW_CHARS"] or "Не добавлять новых")
	cbNoNew:SetScript("OnClick", function(self)
		HironCraftProfit_Config = HironCraftProfit_Config or {}
		HironCraftProfit_Config.accountOverviewNoNewChars = self:GetChecked() and true or false
		UI:Refresh()
	end)
	cbNoNew:SetScript("OnEnter", function(self)
		UI:ShowHeaderTooltip(self, L["AO_NO_NEW_CHARS_TIP"] or "Новые персонажи не будут добавляться в таблицу")
	end)
	cbNoNew:SetScript("OnLeave", function() UI:HideHeaderTooltip() end)
	f.noNewCharsCheck = cbNoNew

    f.header = CreateHeader(f)

	CreateRow = function(parent)
		local row = CreateFrame("Frame", nil, parent)
		row:SetHeight(ROW_H)
		row:SetWidth(math.max(1, parent:GetWidth()))
		row:EnableMouse(true)
		row:SetMouseMotionEnabled(true)
        row:RegisterForDrag("LeftButton")
        row:SetScript("OnMouseDown", function(_, button)
            if button == "LeftButton" then SetAccountOverviewActive(true) end
        end)
        row:SetScript("OnDragStart", function(self)
            if IsManualOrder() then
                UI:BeginRowDrag(self)
            else
                StartWindowMove(f)
            end
        end)
        row:SetScript("OnDragStop", function(self)
            if UI._rowDrag then
                UI:EndRowDrag(self)
            else
                StopWindowMove(f)
            end
        end)
		row.bg = row:CreateTexture(nil, "BACKGROUND")
		row.bg:SetAllPoints()
		row.bg:SetColorTexture(1, 1, 1, 0)

		row.highlight = row:CreateTexture(nil, "BORDER")
		row.highlight:SetAllPoints()
		row.highlight:SetColorTexture(0.4, 0.6, 1.0)
		row.highlight:SetAlpha(0)

		row.isCurrent = false
		row.cells = {}

		local filters = PT.AccountOverview_Data:GetColumnFilters()
		local visibleCols = GetVisibleColumns(f:GetWidth(), filters)
		local x = 8

		for _, c in ipairs(visibleCols) do
			if c.key == "profgear" then
				local cell = CreateFrame("Frame", nil, row)
				cell:SetPoint("LEFT", row, "LEFT", x, 0)
				cell:SetSize(c.w, ROW_H)

				cell.text = cell:CreateFontString(nil, "OVERLAY")
				cell.text:SetFont(FONT, 12, "")
				cell.text:SetPoint("CENTER")
				cell.text:SetText("—")
				cell.text:Show()

				cell.icons = {}
				local totalW = PROF_EQUIP_ICON_COLS * PROF_EQUIP_ICON_SIZE + (PROF_EQUIP_ICON_COLS - 1) * PROF_EQUIP_ICON_GAP
				local totalH = 2 * PROF_EQUIP_ICON_SIZE + PROF_EQUIP_ICON_GAP
				local startX = math.floor((c.w - totalW) / 2)
				local startY = math.floor((ROW_H - totalH) / 2)

				for i = 1, PROF_EQUIP_ICON_MAX do
					local iconFrame = CreateFrame("Frame", nil, cell)
					iconFrame:SetSize(PROF_EQUIP_ICON_SIZE, PROF_EQUIP_ICON_SIZE)
					iconFrame:EnableMouse(true)
					iconFrame:Hide()

					local rowIndex = math.floor((i - 1) / PROF_EQUIP_ICON_COLS)
					local colIndex = (i - 1) % PROF_EQUIP_ICON_COLS
					iconFrame:SetPoint(
						"TOPLEFT",
						cell,
						"TOPLEFT",
						startX + colIndex * (PROF_EQUIP_ICON_SIZE + PROF_EQUIP_ICON_GAP),
						-(startY + rowIndex * (PROF_EQUIP_ICON_SIZE + PROF_EQUIP_ICON_GAP))
					)

					local tex = iconFrame:CreateTexture(nil, "ARTWORK")
					tex:SetAllPoints()
					tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
					iconFrame.tex = tex

                    local qualityBorder = {}

                    qualityBorder.top = iconFrame:CreateTexture(nil, "OVERLAY", nil, 1)
                    qualityBorder.top:SetColorTexture(1, 1, 1, 1)
                    qualityBorder.top:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 0, 0)
                    qualityBorder.top:SetPoint("TOPRIGHT", iconFrame, "TOPRIGHT", 0, 0)
                    qualityBorder.top:SetHeight(1)

                    qualityBorder.bottom = iconFrame:CreateTexture(nil, "OVERLAY", nil, 1)
                    qualityBorder.bottom:SetColorTexture(1, 1, 1, 1)
                    qualityBorder.bottom:SetPoint("BOTTOMLEFT", iconFrame, "BOTTOMLEFT", 0, 0)
                    qualityBorder.bottom:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", 0, 0)
                    qualityBorder.bottom:SetHeight(1)

                    qualityBorder.left = iconFrame:CreateTexture(nil, "OVERLAY", nil, 1)
                    qualityBorder.left:SetColorTexture(1, 1, 1, 1)
                    qualityBorder.left:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 0, 0)
                    qualityBorder.left:SetPoint("BOTTOMLEFT", iconFrame, "BOTTOMLEFT", 0, 0)
                    qualityBorder.left:SetWidth(1)

                    qualityBorder.right = iconFrame:CreateTexture(nil, "OVERLAY", nil, 1)
                    qualityBorder.right:SetColorTexture(1, 1, 1, 1)
                    qualityBorder.right:SetPoint("TOPRIGHT", iconFrame, "TOPRIGHT", 0, 0)
                    qualityBorder.right:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", 0, 0)
                    qualityBorder.right:SetWidth(1)

                    for _, borderLine in pairs(qualityBorder) do
                        borderLine:Hide()
                    end

                    iconFrame.qualityBorder = qualityBorder

                    local qualityIcon = iconFrame:CreateTexture(nil, "OVERLAY", nil, 3)
                    qualityIcon:SetSize(PROF_EQUIP_QUALITY_ICON_SIZE, PROF_EQUIP_QUALITY_ICON_SIZE)
                    qualityIcon:SetPoint("TOPRIGHT", iconFrame, "TOPRIGHT", 3, 3)
                    qualityIcon:Hide()
                    iconFrame.qualityIcon = qualityIcon

					iconFrame:SetScript("OnEnter", function(self)
						if self.item then
							UI:ShowProfessionGearTooltip(self, self.item, row.charKey)
						end
					end)

					iconFrame:SetScript("OnLeave", function()
						UI:HideProfessionGearTooltip()
					end)

					cell.icons[i] = iconFrame
				end

				row.cells[c.key] = cell

			elseif c.key == "zeal" then
				local cell = CreateFrame("Frame", nil, row)
				cell:SetPoint("LEFT", row, "LEFT", x, 0)
				cell:SetSize(c.w, ROW_H)

				cell.lines = {}
				for i = 1, 2 do
					local line = CreateFrame("Frame", nil, cell)
					line:SetSize(c.w, ROW_H / 2)
					line:SetPoint("TOPLEFT", 0, i == 1 and -2 or -(ROW_H / 2))

					line.icon = line:CreateTexture(nil, "ARTWORK")
					line.icon:SetSize(14, 14)
					line.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
					line.icon:SetPoint("LEFT", line, "LEFT", math.floor((c.w - 14 - 4 - 32) / 2), 0)
					line.icon:Hide()

					line.text = line:CreateFontString(nil, "OVERLAY")
					line.text:SetFont(FONT, 11, "")
					line.text:SetPoint("LEFT", line.icon, "RIGHT", 4, 0)
					line.text:SetJustifyH("LEFT")
					line.text:SetText("—")
					line.text:SetTextColor(unpack(COLOR_NORMAL))

					cell.lines[i] = line
				end

				row.cells[c.key] = cell

			elseif c.key == "c_df" or c.key == "c_tww" or c.key == "c_mid" then
				local cell = CreateFrame("Frame", nil, row)
				cell:SetPoint("LEFT", row, "LEFT", x, 0)
				cell:SetSize(c.w, ROW_H)

				cell.lines = {}
				for i = 1, 2 do
					local line = CreateFrame("Frame", nil, cell)
					line:SetSize(c.w, ROW_H / 2)
					line:SetPoint("TOPLEFT", 0, i == 1 and -2 or -(ROW_H / 2))

					line.group = CreateFrame("Frame", nil, line)
					line.group:SetSize(1, 14)
					line.group:SetPoint("CENTER", line, "CENTER", 0, 0)

					local notifyBtn = CreateFrame("Button", nil, line.group)
					notifyBtn:SetSize(14, 14)
					notifyBtn:Hide()

					local notifyChat = notifyBtn:CreateTexture(nil, "ARTWORK")
					notifyChat:SetAllPoints()
					notifyChat:SetAtlas("transmog-icon-chat")
					notifyBtn.chatTex = notifyChat

					local notifyMark = notifyBtn:CreateTexture(nil, "OVERLAY")
					notifyMark:SetSize(8, 8)
					notifyMark:SetPoint("BOTTOMRIGHT", 1, -1)
					notifyBtn.markTex = notifyMark

					line.notifyBtn = notifyBtn

					line.icon = line.group:CreateTexture(nil, "ARTWORK")
					line.icon:SetSize(14, 14)
					line.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
					line.icon:Hide()

                    line.text = line.group:CreateFontString(nil, "OVERLAY")
                    line.text:SetFont(FONT, 11, "")
                    line.text:SetWidth(CONC_VALUE_W)
                    line.text:SetJustifyH("RIGHT")
                    line.text:SetText("—")
                    line.text:SetTextColor(unpack(COLOR_NORMAL))

					LayoutConcLine(line)
					cell.lines[i] = line
				end

				row.cells[c.key] = cell

			elseif c.key == "kp_df" or c.key == "kp_tww" or c.key == "kp_mid" then
				local cell = CreateFrame("Frame", nil, row)
				cell:SetPoint("LEFT", row, "LEFT", x, 0)
				cell:SetSize(c.w, ROW_H)

				cell.lines = {}

				for i = 1, 2 do
					local line = CreateFrame("Frame", nil, cell)
					line:SetSize(c.w, ROW_H / 2)
					line:SetPoint("TOPLEFT", 0, i == 1 and -2 or -(ROW_H / 2))

					line.group = CreateFrame("Frame", nil, line)
					line.group:SetSize(64, 14)
					line.group:SetPoint("CENTER", line, "CENTER", 0, 0)
					line.group:Hide()

					line.icon = line.group:CreateTexture(nil, "ARTWORK")
					line.icon:SetSize(14, 14)
					line.icon:SetPoint("LEFT", line.group, "LEFT", 0, 0)
					line.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
					line.icon:Hide()

					line.text = line:CreateFontString(nil, "OVERLAY")
					line.text:SetFont(FONT, 11, "")
					line.text:SetPoint("CENTER", line, "CENTER", 0, 0)
					line.text:SetText("—")
					line.text:SetTextColor(unpack(COLOR_NORMAL))
					line.text:Show()

					line.weekly = {}

					local order = { "trainer", "treasure", "treatise" }
					local xOff = 18

					for _, key in ipairs(order) do
						local wrap = CreateFrame("Frame", nil, line.group)
						wrap:SetSize(14, 14)
						wrap:SetPoint("LEFT", line.group, "LEFT", xOff, 0)
						wrap:EnableMouse(true)

						wrap:SetScript("OnEnter", function(self)
							if line.info and line.info.weekly then
								UI:ShowWeeklyKPTooltip(self, line.info, line.info.weekly)
							end
						end)

						wrap:SetScript("OnLeave", function()
							UI:HideWeeklyKPTooltip()
						end)

						local icon = wrap:CreateTexture(nil, "ARTWORK")
						icon:SetAllPoints()
						icon:SetAtlas(WEEKLY_ICONS[key])
						icon:Hide()

						local mark = wrap:CreateTexture(nil, "OVERLAY")
						mark:SetSize(10, 10)
						mark:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 3, -3)
						mark:Hide()

						line.weekly[key] = {
							icon = icon,
							mark = mark,
							key  = key,
							line = line,
						}

						xOff = xOff + 16
					end

					cell.lines[i] = line
				end

				row.cells[c.key] = cell

			elseif c.key == "dmf" then
				local cell = CreateFrame("Frame", nil, row)
				cell:SetPoint("LEFT", row, "LEFT", x, 0)
				cell:SetSize(c.w, ROW_H)

				cell.lines = {}

				for i = 1, 2 do
					local line = CreateFrame("Frame", nil, cell)
					line:SetSize(c.w, ROW_H / 2)
					line:SetPoint("TOPLEFT", 0, i == 1 and -2 or -(ROW_H / 2))
					line:EnableMouse(true)
                    MakeChildDraggable(line, f)
					line.text = line:CreateFontString(nil, "OVERLAY")
					line.text:SetFont(FONT, 12, "")
					line.text:SetPoint("CENTER")
					line.text:SetText("—")
					line.text:Show()

					line.icon = line:CreateTexture(nil, "ARTWORK")
					line.icon:SetSize(16, 16)
					line.icon:SetPoint("CENTER")
					line.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
					line.icon:Hide()

					line.mark = line:CreateTexture(nil, "OVERLAY")
					line.mark:SetSize(10, 10)
					line.mark:SetPoint("BOTTOMRIGHT", line.icon, "BOTTOMRIGHT", 3, -3)
					line.mark:Hide()

					line:SetScript("OnEnter", function(self)
						if self.info then
							UI:ShowDMFTooltip(self, self.info)
						end
					end)

					line:SetScript("OnLeave", function()
						UI:HideDMFTooltip()
					end)

					cell.lines[i] = line
				end

				row.cells[c.key] = cell

			elseif c.key == "tw" then
				local cell = CreateFrame("Frame", nil, row)
				cell:SetPoint("LEFT", row, "LEFT", x, 0)
				cell:SetSize(c.w, ROW_H)

				cell.text = cell:CreateFontString(nil, "OVERLAY")
				cell.text:SetFont(FONT, 12, "")
				cell.text:SetPoint("CENTER")
				cell.text:SetText("—")
				cell.text:Show()

				cell.icon = cell:CreateTexture(nil, "OVERLAY")
				cell.icon:SetSize(18, 18)
				cell.icon:SetPoint("CENTER", 0, -6)
				cell.icon:Hide()

				cell.mark = cell:CreateTexture(nil, "OVERLAY")
				cell.mark:SetSize(25, 25)
				cell.mark:ClearAllPoints()
				cell.mark:SetPoint("BOTTOMRIGHT", cell.icon, "BOTTOMRIGHT", 10, 5)
				cell.mark:SetDrawLayer("OVERLAY", 7)
				cell.mark:Hide()

				row.cells.tw = cell

			else
				local fs = row:CreateFontString(nil, "OVERLAY")

				if c.key == "char" then
					fs:SetFont(FONT, 12, "")
					fs:SetPoint("LEFT", row, "LEFT", x, 0)
					fs:SetWidth(c.w)
					fs:SetJustifyH("LEFT")

				elseif c.key == "skin" then
					fs:SetFont(FONT, 18, "OUTLINE")
                    fs:SetPoint("LEFT", row, "LEFT", x, -2)
                    fs:SetWidth(c.w)
					fs:SetJustifyH("CENTER")
					fs:EnableMouse(true)
					fs:SetScript("OnEnter", function(self)
						UI:ShowSkinTooltip(self, row.charKey)
					end)
					fs:SetScript("OnLeave", function()
						UI:HideSkinTooltip()
					end)

                elseif c.key == "dundun" then
                    fs:SetFont(FONT, 18, "OUTLINE")
                    fs:SetPoint("LEFT", row, "LEFT", x, 0)
                    fs:SetWidth(c.w)
                    fs:SetJustifyH("CENTER")
                    fs:EnableMouse(true)
                    fs:SetScript("OnEnter", function(self)
                        UI:ShowDundunTooltip(self, row.charKey)
                    end)
                    fs:SetScript("OnLeave", function()
                        UI:HideDundunTooltip()
                    end)

				else
					fs:SetFont(FONT, 12, "")
					fs:SetPoint("LEFT", row, "LEFT", x, 0)
					fs:SetWidth(c.w)
					fs:SetJustifyH("CENTER")
				end

				fs:SetText("—")
				row.cells[c.key] = fs
			end

			x = x + c.w
		end

		return row
	end

	local scroll = CreateFrame("ScrollFrame", nil, f)
	scroll:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, -6)
	scroll:SetPoint("BOTTOMRIGHT", -12, 12)

	scroll:EnableMouse(true)
	scroll:SetMouseMotionEnabled(true)
    MakeChildDraggable(scroll, f)
	scroll.bg = scroll:CreateTexture(nil, "BACKGROUND")
	scroll.bg:SetAllPoints()
	scroll.bg:SetColorTexture(0, 0, 0, 0.001)

	scroll:EnableMouseWheel(true)
	KillScrollFrameTextures(scroll)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
	content:EnableMouse(true)
	content:SetMouseMotionEnabled(true)
    MakeChildDraggable(content, f)
    scroll:SetScrollChild(content)
	scroll.content = content
	scroll.hoveredRow = nil

	scroll:SetScript("OnUpdate", function(self)
		local content = self.content
		if not content or not content.rows then return end

		if not self:IsMouseOver() then
			if self.hoveredRow then
				local r = self.hoveredRow
				r.highlight:SetAlpha(r.isCurrent and 0.06 or 0)
				self.hoveredRow = nil
			end
			return
		end

		local mx, my = GetCursorPosition()
		local scale = self:GetEffectiveScale()
		mx, my = mx / scale, my / scale

		local _, top = self:GetLeft(), self:GetTop()
		if not top then return end

		local yFromTop = (top - my) + self:GetVerticalScroll()
		local index = math.floor(yFromTop / ROW_H) + 1
		local row = content.rows[index]

		if row ~= self.hoveredRow then
			if self.hoveredRow then
				local r = self.hoveredRow
				r.highlight:SetAlpha(r.isCurrent and 0.06 or 0)
			end

			self.hoveredRow = row

			if row then
				row.highlight:SetAlpha(row.isCurrent and 0.15 or 0.10)
			end
		end
	end)

    scroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        self:SetVerticalScroll(math.max(0, cur - delta * ROW_H))
    end)

    f.scroll = scroll
    f.content = content

    self.frame = f
    return f
end

local function GetProfessionGearGrade(item)
    if type(item) ~= "table" then
        return nil
    end

    local grade = tonumber(item.craftedQuality or item.grade or item.craftedQualityID)
    if grade and grade >= 1 and grade <= 5 then
        return grade
    end

    if not C_TradeSkillUI
       or not C_TradeSkillUI.GetItemCraftedQualityByItemInfo
    then
        return nil
    end

    local itemInfo = item.link or item.itemID
    if not itemInfo then
        return nil
    end

    local ok, quality = pcall(C_TradeSkillUI.GetItemCraftedQualityByItemInfo, itemInfo)
    quality = tonumber(quality)

    if ok and quality and quality >= 1 and quality <= 5 then
        item.craftedQuality = quality
        return quality
    end

    return nil
end

local function GetProfessionGearItemQuality(item)
    if type(item) ~= "table" then
        return nil
    end

    local quality = tonumber(item.itemQuality or item.quality)

    if quality then
        return quality
    end

    local itemInfo = item.link or item.itemID
    if itemInfo then
        local q = select(3, GetItemInfo(itemInfo))
        quality = tonumber(q)
        if quality then
            item.itemQuality = quality
            return quality
        end
    end

    return nil
end

local function SetProfessionEquipmentCell(cell, data, charKey)
    if not cell or not cell.icons then
        return
    end

    if cell.text then
        cell.text:SetText("—")
        cell.text:Show()
    end

    for _, iconFrame in ipairs(cell.icons) do
        iconFrame.item = nil

        if iconFrame.tex then
            iconFrame.tex:SetTexture(nil)
        end

        if iconFrame.qualityIcon then
            iconFrame.qualityIcon:SetTexture(nil)
            iconFrame.qualityIcon:Hide()
        end

        if iconFrame.qualityBorder then
            for _, borderLine in pairs(iconFrame.qualityBorder) do
                borderLine:Hide()
            end
        end

        iconFrame:Hide()
    end

    if type(data) ~= "table" or not next(data) then
        return
    end

    if cell.text then
        cell.text:Hide()
    end

    local used = {}

    local function GetTargetIconIndex(item)
        local displayIndex = tonumber(item and item.displayIndex)

        if displayIndex
        and displayIndex >= 1
        and displayIndex <= PROF_EQUIP_ICON_MAX
        then
            if not used[displayIndex] then
                return displayIndex
            end

            return nil
        end

        for i = 1, PROF_EQUIP_ICON_MAX do
            if not used[i] then
                return i
            end
        end

        return nil
    end

    for fallbackIndex, item in ipairs(data) do
        if type(item) == "table" then
            local iconIndex = GetTargetIconIndex(item)
            local iconFrame = iconIndex and cell.icons[iconIndex]

            if iconFrame then
                used[iconIndex] = true
                iconFrame.item = item

                if iconFrame.tex then
                    iconFrame.tex:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                end

                if iconFrame.qualityBorder then
                    local itemQuality = GetProfessionGearItemQuality(item)
                    local color = itemQuality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[itemQuality]

                    if color then
                        for _, borderLine in pairs(iconFrame.qualityBorder) do
                            borderLine:SetColorTexture(color.r, color.g, color.b, 1)
                            borderLine:Show()
                        end
                    else
                        for _, borderLine in pairs(iconFrame.qualityBorder) do
                            borderLine:Hide()
                        end
                    end
                end

                local grade = GetProfessionGearGrade(item)

                if iconFrame.qualityIcon then
                    if grade and grade >= 1 and grade <= 5 then
                        iconFrame.qualityIcon:SetAtlas("Professions-Icon-Quality-Tier" .. grade, false)
                        iconFrame.qualityIcon:Show()
                    else
                        iconFrame.qualityIcon:SetTexture(nil)
                        iconFrame.qualityIcon:Hide()
                    end
                end

                iconFrame:Show()
            end
        end
    end
end

local function SetZealCell(cell, data)
    if not cell or not cell.lines then return end

    for i = 1, 2 do
        local line = cell.lines[i]
        if line.icon then
            line.icon:Hide()
            line.icon:SetTexture(nil)
        end
        if line.text then
            line.text:SetText("—")
            line.text:SetTextColor(unpack(COLOR_NORMAL))
        end
    end

    if type(data) ~= "table" or not next(data) then return end

    local items = {}
    for skillLine, info in pairs(data) do
        table.insert(items, { skillLine = skillLine, info = info })
    end
    table.sort(items, function(a, b)
        return (a.info.name or "") < (b.info.name or "")
    end)

    for i = 1, 2 do
        local entry = items[i]
        local line  = cell.lines[i]
        if not entry or not line then break end

        local info = entry.info
        if info and line.icon then
            if info.icon then
                line.icon:SetTexture(info.icon)
                line.icon:Show()
            end
            if line.text then
                local v = tonumber(info.value) or 0
                line.text:SetText(tostring(v))
                if v >= 600 then
                    line.text:SetTextColor(1.0, 0.55, 0.20)
                else
                    line.text:SetTextColor(unpack(COLOR_NORMAL))
                end
            end
        end
    end
end

local function SetConcCell(cell, data, charKey, exp)
    if not cell or not cell.lines then return end

    for i = 1, 2 do
        local line = cell.lines[i]
        if line.icon then
            line.icon:Hide()
            line.icon:SetTexture(nil)
        end
        if line.notifyBtn then
            line.notifyBtn:Hide()
        end
        if line.text then
            line.text:SetText("—")
            line.text:SetTextColor(unpack(COLOR_NORMAL))
        end
        LayoutConcLine(line)
    end

    if type(data) ~= "table" or not next(data) then
        return
    end

    local items = {}
    for skillLine, info in pairs(data) do
        table.insert(items, { skillLine = skillLine, info = info })
    end
    table.sort(items, function(a, b)
        return (a.info.name or "") < (b.info.name or "")
    end)

    local D = PT.AccountOverview_Data

    for i = 1, 2 do
        local entry = items[i]
        local line  = cell.lines[i]
        if not entry or not line then break end

        local info      = entry.info
        local skillLine = entry.skillLine

        if info and line.icon then
            if info.icon then
                line.icon:SetTexture(info.icon)
                line.icon:Show()
            end

            if line.text then
                if info.value == nil then
                    line.text:SetText("…")
                else
                    line.text:SetText(tostring(info.value))
                end

                if info.value and info.value >= CONCENTRATION_MAX then
                    line.text:SetTextColor(unpack(COLOR_FULL))
                else
                    line.text:SetTextColor(unpack(COLOR_NORMAL))
                end
            end

            if line.notifyBtn and charKey and skillLine and D then
                local btn = line.notifyBtn

                local function RefreshNotifyBtn()
                    local enabled = D:IsConcentrationProfEnabled(charKey, exp, skillLine)
                    btn.chatTex:SetDesaturated(not enabled)
                    btn.chatTex:SetAlpha(enabled and 1 or 0.5)
                    btn.markTex:SetTexture(nil)

                    if enabled then
                        btn.markTex:SetAtlas("common-icon-checkmark")
                        btn.markTex:SetVertexColor(0.2, 0.9, 0.2, 1)
                    else
                        btn.markTex:SetAtlas("common-icon-redx")
                        btn.markTex:SetVertexColor(0.9, 0.2, 0.2, 0.8)
                    end

                    btn.markTex:Show()
                end

                btn:SetScript("OnClick", function()
                    local cur = D:IsConcentrationProfEnabled(charKey, exp, skillLine)
                    D:SetConcentrationProfEnabled(charKey, exp, skillLine, not cur)
                    RefreshNotifyBtn()
                    LayoutConcLine(line)
                end)

                btn:SetScript("OnEnter", function()
                    local enabled = D:IsConcentrationProfEnabled(charKey, exp, skillLine)
                    local Tooltip = PT.Tooltip
                    if Tooltip then
                        Tooltip:Clear()
                        Tooltip:AddLine(info.name or "", 12, 1, 1, 1)
                        if enabled then
                            Tooltip:AddLine(L["AO_CONC_NOTIFY_ON"] or "Notification enabled", 11, 0.2, 0.9, 0.2)
                        else
                            Tooltip:AddLine(L["AO_CONC_NOTIFY_OFF"] or "Notification disabled", 11, 0.6, 0.6, 0.6)
                        end
                        Tooltip:AddLine(L["AO_CONC_NOTIFY_CLICK"] or "Click to toggle", 11, 0.5, 0.5, 0.5)
                        Tooltip:ShowAtCursor(16, 16)
                    end
                end)

                btn:SetScript("OnLeave", function()
                    if PT.Tooltip then PT.Tooltip:Clear() end
                end)

                RefreshNotifyBtn()
                btn:Show()
            end

            LayoutConcLine(line)
        end
    end
end

local function SetWeeklyKPCell(cell, data)
    if not cell or not cell.lines then return end

    if type(data) ~= "table" or not next(data) then
        for i = 1, 2 do
            local line = cell.lines[i]
            line.info = nil

            if line.group then
                line.group:Hide()
            end

            if line.icon then
                line.icon:Hide()
            end

            for _, w in pairs(line.weekly) do
                if w.icon then w.icon:Hide() end
                if w.mark then w.mark:Hide() end
            end

            if line.text then
                line.text:SetText("—")
                line.text:Show()
            end
        end
        return
    end

    local items = {}
    for _, v in pairs(data) do
        table.insert(items, v)
    end

    table.sort(items, function(a, b)
        return (a.name or "") < (b.name or "")
    end)

    for i = 1, 2 do
        local info = items[i]
        local line = cell.lines[i]

        line.info = nil

        if line.group then
            line.group:Hide()
        end

        if line.icon then
            line.icon:Hide()
        end

        for _, w in pairs(line.weekly) do
            if w.icon then w.icon:Hide() end
            if w.mark then w.mark:Hide() end
        end

        if info then
            line.info = info

            if line.text then
                line.text:Hide()
            end

            if line.group then
                line.group:Show()
            end

            if info.icon then
                line.icon:SetTexture(info.icon)
                line.icon:Show()
            end

            if info.weekly then
                for key, w in pairs(line.weekly) do
                    if w.icon then
                        w.icon:Show()
                    end

                    local done = info.weekly[key]
                    if w.mark then
                        w.mark:SetAtlas(done and WEEKLY_MARKS.ok or WEEKLY_MARKS.bad)
                        w.mark:Show()
                    end
                end
            end
        else
            if line.text then
                line.text:SetText("—")
                line.text:Show()
            end
        end
    end
end

local function SetDMFCell(cell, data)
    if not cell or not cell.lines then
        return
    end

    for i = 1, 2 do
        local line = cell.lines[i]
        line.info = nil

        if line.icon then
            line.icon:Hide()
            line.icon:SetTexture(nil)
        end

        if line.mark then
            line.mark:Hide()
        end

        if line.text then
            line.text:SetText("—")
            line.text:Show()
        end
    end

    if type(data) ~= "table" or not next(data) then
        return
    end

    local items = {}
    for _, info in pairs(data) do
        table.insert(items, info)
    end

    table.sort(items, function(a, b)
        return (a.name or "") < (b.name or "")
    end)

    for i = 1, 2 do
        local info = items[i]
        local line = cell.lines[i]

        if info and line then
            line.info = info

            if line.text then
                line.text:Hide()
            end

            if line.icon and info.icon then
                line.icon:SetTexture(info.icon)
                line.icon:Show()
            end

            if line.mark then
                line.mark:SetAtlas(info.done and WEEKLY_MARKS.ok or WEEKLY_MARKS.bad)
                line.mark:Show()
            end
        end
    end
end

local function SetTWCell(cell, data)
    if not cell then return end

    if not data then
        cell.icon:Hide()
        cell.mark:Hide()
        if cell.text then
            cell.text:SetText("—")
            cell.text:Show()
        end
        return
    end

    if cell.text then
        cell.text:Hide()
    end

	if C_Texture.GetAtlasInfo(data.atlas) then
        cell.icon:SetAtlas(data.atlas, true)
        cell.icon:SetSize(60, 40)
        cell.icon:SetTexCoord(0, 1, 0, 1)
        cell.icon:SetVertexColor(1, 1, 1, 1)
        cell.icon:Show()
    else
        cell.icon:Hide()
    end

    cell.mark:SetAtlas(data.done and WEEKLY_MARKS.ok or WEEKLY_MARKS.bad)
    cell.mark:Show()
end

function UI:SetSkinCell(cell, charKey)
    if not cell or not charKey then return end

    cell:SetText("—")
    cell:SetTextColor(1, 1, 1)

    local D = PT.AccountOverview_Data
    if not D or not D.GetSkinningProgress then
        return
    end

    local done, total = D:GetSkinningProgress(charKey)
    if not done or not total then
        return
    end

    cell:SetText(done .. "/" .. total)

    local r, g, b = GetProgressColor(done, total)
    cell:SetTextColor(r, g, b)
end

function UI:ShowSkinTooltip(cell, charKey)
    local Tooltip = PT.Tooltip
    local D  = PT.AccountOverview_Data
    local SC = PT.SkinningCheck

    if not Tooltip or not D then return end

    local done, total = D:GetSkinningProgress(charKey)
    if not done or not total then
        return
    end

    Tooltip:Clear()

    Tooltip:AddLine(L["SKINNING_TITLE"] or "Skinning", 14, 1, 1, 1)

    local r, g, b = GetProgressColor(done, total)
    Tooltip:AddLine(" " .. string.format("%d / %d", done, total), 12, r, g, b)

    if charKey == GetCharacterKey() and SC then
        for _, target in ipairs(SC.TARGETS) do
            if SC:IsTargetAvailable(target)
               and SC:IsTargetEnabled(target)
            then
                local completed = SC:IsTargetCompleted(target)
                local name = SC:GetTargetName(target)

				local fs = Tooltip:AddLine("      " .. name, 12, 1, 1, 1)

                local icon = Tooltip:AddIcon(12)
				Tooltip.frame.icons = Tooltip.frame.icons or {}
				table.insert(Tooltip.frame.icons, icon)
                icon:SetSize(12, 12)
                icon:SetPoint("LEFT", fs, "LEFT", 1, 0)
                icon:SetAtlas(completed and SKIN_MARKS.ok or SKIN_MARKS.bad)
            end
        end
    end

    Tooltip:ShowAtCursor(16, 16)
end

function UI:HideSkinTooltip()
    if PT.Tooltip then
        PT.Tooltip:Clear()
    end
end

function UI:ShowDundunTooltip(cell, charKey)
    local Tooltip = PT.Tooltip
    local D = PT.AccountOverview_Data

    if not Tooltip or not D or not charKey then
        return
    end

    local data = D:GetDundunWeekly(charKey)
    if type(data) ~= "table" then
        return
    end

    local amount   = tonumber(data.value) or 0
    local maxVal   = tonumber(data.max) or 8
    local quantity = tonumber(data.quantity) or 0

    Tooltip:Clear()
    Tooltip:AddLine(L["AO_HDR_DUNDUN"] or "Dundun", 14, 1, 1, 1)
    Tooltip:AddLine((L["AO_DUNDUN_EARNED"] or "Earned this week") .. ": " .. amount, 12, 1, 1, 1)
    Tooltip:AddLine((L["AO_DUNDUN_MAX"] or "Weekly maximum") .. ": " .. maxVal, 12, 1, 1, 1)
    Tooltip:AddLine((L["AO_DUNDUN_CURRENT"] or "Current currency") .. ": " .. quantity, 12, 1, 1, 1)

    Tooltip:ShowAtCursor(16, 16)
end

function UI:HideDundunTooltip()
    if PT.Tooltip then
        PT.Tooltip:Clear()
    end
end

function UI:ShowDMFTooltip(anchor, info)
    local Tooltip = PT.Tooltip
    if not Tooltip or not info then
        return
    end

    Tooltip:Clear()
    Tooltip:AddLine("Darkmoon Faire", 14, 1, 1, 1)
    Tooltip:AddLine(info.name or "", 12, 1, 1, 1)

    if info.done then
        Tooltip:AddLine(L["AO_DMF_QUEST_DONE"] or "Quest completed", 11, 0.2, 0.9, 0.2)
    else
        Tooltip:AddLine(L["AO_DMF_QUEST_NOT_DONE"] or "Quest not completed", 11, 0.9, 0.2, 0.2)
    end

    Tooltip:ShowAtCursor(16, 16)
end

function UI:HideDMFTooltip()
    if PT.Tooltip then
        PT.Tooltip:Clear()
    end
end

function UI:ShowHeaderTooltip(anchor, text)
    local Tooltip = PT.Tooltip
    if not Tooltip or not text then return end

    Tooltip:Clear()
    Tooltip:AddLine(text, 12, 1, 1, 1)
    Tooltip:ShowAtCursor(16, 16)
end

function UI:HideHeaderTooltip()
    if PT.Tooltip then
        PT.Tooltip:Clear()
    end
end

do
    local _notifyFrame = nil
    local _notifyTimer = nil

    function UI:ShowConcentrationNotification()
        local D = PT.AccountOverview_Data
        if not D or not D.pendingFullConc then return end

        local queue = {}
        for charKey, list in pairs(D.pendingFullConc) do
            for _, data in ipairs(list) do
                table.insert(queue, data)
            end
            D.pendingFullConc[charKey] = nil
        end

        if #queue == 0 then return end

        if not self.concNotifyFrame then
            local f = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
            f:SetFrameStrata("DIALOG")
            f:SetClampedToScreen(true)
            f:SetMovable(true)
            f:EnableMouse(true)
            f:RegisterForDrag("LeftButton")

            f:SetScript("OnDragStart", function(self)
                if not InCombatLockdown() then
                    self:StartMoving()
                end
            end)

            f:SetScript("OnDragStop", function(self)
                self:StopMovingOrSizing()

                HironCraftProfit_DB = HironCraftProfit_DB or {}
                HironCraftProfit_DB.concNotifyPos = {
                    point = { self:GetPoint() }
                }
            end)

            self.concNotifyFrame = f
        end

        local f = self.concNotifyFrame

        f:ClearAllPoints()
        if HironCraftProfit_DB and HironCraftProfit_DB.concNotifyPos and HironCraftProfit_DB.concNotifyPos.point then
            f:SetPoint(unpack(HironCraftProfit_DB.concNotifyPos.point))
        else
            f:SetPoint("TOP", UIParent, "TOP", 0, -120)
        end

        f:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 2,
        })
        f:SetBackdropColor(0, 0, 0, 0.95)
        f:SetBackdropBorderColor(0.2, 1.0, 0.2, 1)

        if f._regions then
            for _, r in ipairs(f._regions) do
                r:Hide()
                r:SetParent(nil)
            end
        end
        f._regions = {}

        local close = CreateFrame("Button", nil, f)
        close:SetPoint("TOPRIGHT", -6, -6)
        StyleIconBtn(close, "uitools-icon-close", 16)
        close:SetScript("OnClick", function() f:Hide() end)
        table.insert(f._regions, close)

        local checkIcon = f:CreateTexture(nil, "ARTWORK")
        checkIcon:SetSize(20, 20)
        checkIcon:SetPoint("LEFT", 12, 0)
        checkIcon:SetAtlas("common-icon-checkmark")
        table.insert(f._regions, checkIcon)

        local title = f:CreateFontString(nil, "OVERLAY")
        title:SetFont(FONT, 14, "OUTLINE")
        title:SetPoint("TOPLEFT", 44, -10)
        title:SetText(L["AO_CONC_FULL_TITLE"] or "Concentration restored")
        title:SetTextColor(0.2, 1.0, 0.2)
        table.insert(f._regions, title)

        local text = f:CreateFontString(nil, "OVERLAY")
        text:SetFont(FONT, 11, "")
        text:SetJustifyH("LEFT")
        text:SetJustifyV("TOP")
        text:SetWordWrap(true)

        local lines = {}
        for i, data in ipairs(queue) do
            if i > 5 then break end
            table.insert(lines, string.format(
                "%s — %s (%s, %d)",
                data.charKey,
                data.name or "",
                EXP_LABEL[data.exp] or data.exp,
                data.value or 0
            ))
        end

        if #queue > 5 then
            table.insert(lines, L["AO_CONC_MORE"] or "and others…")
        end

        text:SetText(table.concat(lines, "\n"))
        text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -TITLE_GAP)

        table.insert(f._regions, text)

        local finalW = math.max(NOTIFY_MIN_W, math.min(NOTIFY_MAX_W, text:GetStringWidth() + 100))
        local finalH = title:GetStringHeight() + TITLE_GAP + text:GetStringHeight() + NOTIFY_PAD_Y * 2

        f:SetSize(finalW, finalH)

        f:SetScript("OnClick", function()
            UI:Toggle()
            f:Hide()
        end)

        f:Show()

        if self._notifyTimer then
            self._notifyTimer:Cancel()
        end

        self._notifyTimer = C_Timer.NewTimer(18, function()
            f:Hide()
        end)
    end
end

function UI:ShowWeeklyKPTooltip(anchor, info, weekly)
    local Tooltip = PT.Tooltip
    if not Tooltip or not Tooltip.frame then
        return
    end

    Tooltip:Clear()

    Tooltip.frame.icons = Tooltip.frame.icons or {}

    for _, tex in ipairs(Tooltip.frame.icons) do
        if tex then
            tex:Hide()
            tex:SetParent(nil)
        end
    end
    wipe(Tooltip.frame.icons)

    Tooltip:AddLine(L["AO_KP_TITLE"] or "Weekly Knowledge", 14, 1, 1, 1)

    local order = {
        { key = "trainer",  label = L["AO_KP_TRAINER"]  or "Trainer"  },
        { key = "treasure", label = L["AO_KP_TREASURE"] or "Treasure" },
        { key = "treatise", label = L["AO_KP_TREATISE"] or "Treatise" },
    }

    for _, o in ipairs(order) do
        local done = weekly and weekly[o.key]

        local fs = Tooltip:AddLine("      " .. o.label, 12, 1, 1, 1)

        local icon = Tooltip:AddIcon(12)
        table.insert(Tooltip.frame.icons, icon)

        icon:SetSize(12, 12)
        icon:SetPoint("LEFT", fs, "LEFT", 1, 0)
        icon:SetAtlas(done and WEEKLY_MARKS.ok or WEEKLY_MARKS.bad)
        icon:Show()
    end

    Tooltip:ShowAtCursor(16, 16)
end

function UI:HideWeeklyKPTooltip()
    if PT.Tooltip then
        PT.Tooltip:Clear()
    end
end

local function SetWeeklyCell(cell, status)
    if not cell or not cell.weekly then return end

    for key, pack in pairs(cell.weekly) do
        if pack.icon then
            pack.icon:Show()
        end

        if pack.mark then
            if status == nil then
                pack.mark:Hide()
            else
                local done = status[key] and true or false
                pack.mark:SetAtlas(done and WEEKLY_MARKS.ok or WEEKLY_MARKS.bad)
                pack.mark:Show()
            end
        end
    end
end

function UI:Refresh()
    local f = self.frame
    if f.scroll then
        f.scroll.hoveredRow = nil
    end
    if not f then return end
    f.content.rows = {}

    for _, c in ipairs({ f.content:GetChildren() }) do
        c:Hide()
    end

    local chars = CollectCharacters()
    local y = -2

    for i, charKey in ipairs(chars) do
        local row = CreateRow(f.content)
        row.charKey = charKey
        table.insert(f.content.rows, row)

        if i % 2 == 0 then
            row.bg:SetColorTexture(1, 1, 1, 0.05)
        else
            row.bg:SetColorTexture(1, 1, 1, 0)
        end

        if charKey == GetCharacterKey() then
            row.isCurrent = true
            row.highlight:SetAlpha(0.06)
            row.cells.char:SetFont(FONT, 12, "OUTLINE")
        else
            row.isCurrent = false
            row.highlight:SetAlpha(0)
        end

        row:SetPoint("TOPLEFT", 0, y)
        row:SetPoint("RIGHT", f.content, "RIGHT", 0, 0)

        if row.cells.char then
            local isCurrent = (charKey == GetCharacterKey())

            if not row.deleteBtn then
                local btn = CreateFrame("Button", nil, row)
                btn:SetSize(14, 14)

                local tex = btn:CreateTexture(nil, "OVERLAY")
                tex:SetAllPoints()
                tex:SetAtlas("common-icon-redx")

                btn.tex = tex
                row.deleteBtn = btn
            end

            if not isCurrent then
                row.deleteBtn:ClearAllPoints()
                row.deleteBtn:SetPoint("LEFT", row.cells.char, "LEFT", -10, 0)
                row.deleteBtn:Show()

                row.deleteBtn:SetScript("OnClick", function()
                    UI:ConfirmDeleteCharacter(charKey)
                end)

                row.cells.char:SetText("   " .. charKey)
            else
                row.deleteBtn:Hide()
                row.cells.char:SetText(charKey)
            end

            local ccr, ccg, ccb = GetCharClassColor(charKey)
            if ccr then
                row.cells.char:SetTextColor(ccr, ccg, ccb)
            else
                row.cells.char:SetTextColor(1, 1, 1)
            end

            if not row.noteBtn then
                local nb = CreateFrame("Button", nil, row)
                nb:SetSize(14, 14)
                nb:EnableMouse(true)

                local tex = nb:CreateTexture(nil, "ARTWORK")
                tex:SetAllPoints()
                nb.tex = tex

                nb:SetScript("OnEnter", function(self)
                    if self.tex then self.tex:SetVertexColor(1.3, 1.3, 1.3) end
                    local note = GetCharNote(self.charKey)
                    if PT.Tooltip then
                        PT.Tooltip:Clear()
                        PT.Tooltip:AddLine((L["AO_NOTE_TITLE"] or "Note") .. ": " .. tostring(self.charKey), 13, 1, 1, 1)
                        if note and note ~= "" then
                            PT.Tooltip:AddLine(note, 12, 0.9, 0.9, 0.9)
                        else
                            PT.Tooltip:AddLine(L["AO_NOTE_EMPTY"] or "No note. Click to add.", 11, 0.6, 0.6, 0.6)
                        end
                        PT.Tooltip:ShowAtCursor(16, 12)
                    end
                end)

                nb:SetScript("OnLeave", function(self)
                    if self.tex then self.tex:SetVertexColor(1, 1, 1) end
                    if PT.Tooltip then PT.Tooltip:Clear() end
                end)

                nb:SetScript("OnClick", function(self)
                    UI:EditCharNote(self.charKey)
                end)

                row.noteBtn = nb
            end

            row.noteBtn.charKey = charKey
            row.noteBtn:ClearAllPoints()
            row.noteBtn:SetPoint("RIGHT", row.cells.char, "RIGHT", -4, 0)

            local note = GetCharNote(charKey)
            if note and note ~= "" then
                row.noteBtn.tex:SetAtlas("Pencil-Icon")
                row.noteBtn.tex:SetVertexColor(1, 0.85, 0.3)
            else
                row.noteBtn.tex:SetAtlas("Pencil-Icon")
                row.noteBtn.tex:SetVertexColor(0.5, 0.5, 0.5, 0.5)
            end
            row.noteBtn:Show()
        end

        do
            if row.cells.profgear then
                local data = GetProfessionEquipment(charKey)
                SetProfessionEquipmentCell(row.cells.profgear, data, charKey)
            end
        end

        do
            if row.cells.c_df then
                local v = GetConcentration(charKey, "df")
                SetConcCell(row.cells.c_df, v, charKey, "df")
            end
        end

        do
            if row.cells.c_tww then
                local v = GetConcentration(charKey, "tww")
                SetConcCell(row.cells.c_tww, v, charKey, "tww")
            end
        end

        do
            local cell = row.cells.c_mid
            if cell then
                local v = GetConcentration(charKey, "mid")
                SetConcCell(cell, v, charKey, "mid")
            end
        end

        do
            local cell = row.cells.zeal
            if cell then
                local v = GetZeal(charKey)
                SetZealCell(cell, v)
            end
        end

        do
            local data = GetWeeklyStatus(charKey, "df")
            if row.cells.kp_df then
                SetWeeklyKPCell(row.cells.kp_df, data)
            end
        end

        do
            local data = GetWeeklyStatus(charKey, "tww")
            if row.cells.kp_tww then
                SetWeeklyKPCell(row.cells.kp_tww, data)
            end
        end

        do
            local data = GetWeeklyStatus(charKey, "mid")
            if row.cells.kp_mid then
                SetWeeklyKPCell(row.cells.kp_mid, data)
            end
        end

        do
            if row.cells.skin then
                self:SetSkinCell(row.cells.skin, charKey)
            end
        end

        do
            local cell = row.cells.dundun
            if cell then
                local data = GetDundunWeekly(charKey)

                if type(data) ~= "table" then
                    cell:SetText("—")
                    cell:SetTextColor(1, 1, 1)
                else
                    local amount = tonumber(data.value) or 0
                    local maxVal = tonumber(data.max) or 8
                    local quantity = tonumber(data.quantity) or 0

                    cell:SetText(string.format("%d/%d(%d)", amount, maxVal, quantity))

                    if amount >= maxVal then
                        cell:SetTextColor(0.2, 1.0, 0.2)
                    else
                        local r, g, b = GetProgressColor(amount, maxVal)
                        cell:SetTextColor(r, g, b)
                    end
                end
            end
        end

        do
            local data = GetDarkmoonStatus(charKey)
            if row.cells.dmf then
                SetDMFCell(row.cells.dmf, data)
            end
        end

        do
            local data = PT.AccountOverview_Data:GetTimewalkingStatus(charKey)
            if row.cells.tw then
                SetTWCell(row.cells.tw, data)
            end
        end

        y = y - ROW_H
    end

    f.content:SetWidth(math.max(1, f.scroll:GetWidth()))
    f.content:SetHeight(-y + 4)
end

function UI:Show()
    local f = self:Create()
    f:Show()

    if PT.professionsReady then
        self:Refresh()
    else
        C_Timer.After(0.2, function()
            if f:IsShown() then
                self:Refresh()
            end
        end)
    end
end

function UI:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function UI:Toggle()
    local f = self:Create()
    if f:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function UI:ConfirmReset()
    StaticPopupDialogs["HIRONCRAFT_PROFIT_AO_RESET_1"] = {
        text = L["AO_RESET_1_TEXT"],
        button1 = YES,
        button2 = NO,
        OnAccept = function()
            StaticPopup_Show("HIRONCRAFT_PROFIT_AO_RESET_2")
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopupDialogs["HIRONCRAFT_PROFIT_AO_RESET_2"] = {
        text = L["AO_RESET_2_TEXT"] or "This action cannot be undone.",
        button1 = L["AO_RESET_2_YES"] or YES,
        button2 = L["AO_RESET_2_NO"]  or NO,

        OnShow = function(self)
            local btn1 = _G[self:GetName() .. "Button1"]
            if not btn1 then return end

            btn1:Disable()

            C_Timer.After(1.2, function()
                if self:IsShown() and btn1 then
                    btn1:Enable()
                end
            end)
        end,

        OnAccept = function()
            if PT.AccountOverview_Data and PT.AccountOverview_Data.Reset then
                PT.AccountOverview_Data:Reset()
            end
            UI:Refresh()
        end,

        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopup_Show("HIRONCRAFT_PROFIT_AO_RESET_1")
end

function UI:EditCharNote(charKey)
    if not charKey then return end

    if not self.noteEditDialog then
        local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        f:SetSize(420, 220)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetToplevel(true)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        f:SetBackdropColor(0, 0, 0, 0.95)
        f:SetBackdropBorderColor(0.694, 0.612, 0.851, 1)
        f:Hide()
        if HironCraftProfit.RegisterEscClose then HironCraftProfit:RegisterEscClose(f) end

        local title = f:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontHighlight")
        title:SetPoint("TOPLEFT", 12, -10)
        f.title = title

        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -32)
        scroll:SetPoint("BOTTOMRIGHT", -30, 40)

        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetMaxLetters(2000)
        edit:SetAutoFocus(false)
        edit:EnableMouse(true)
        edit:SetFontObject(HironCraftProfit_ChatFontNormal)
        edit:SetWidth(380)
        edit:SetHeight(140)
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        scroll:SetScrollChild(edit)
        f.edit = edit

        scroll:EnableMouse(true)
        scroll:SetScript("OnMouseDown", function()
            edit:SetFocus()
        end)

        local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        cancelBtn:SetSize(90, 22)
        cancelBtn:SetPoint("BOTTOMRIGHT", -12, 10)
        cancelBtn:SetText(CANCEL or "Cancel")
        cancelBtn:SetScript("OnClick", function() f:Hide() end)
        if PT.StyleButton then PT:StyleButton(cancelBtn, 12) end

        local saveBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        saveBtn:SetSize(90, 22)
        saveBtn:SetPoint("RIGHT", cancelBtn, "LEFT", -6, 0)
        saveBtn:SetText(SAVE or "Save")
        saveBtn:SetScript("OnClick", function()
            SetCharNote(f.charKey, f.edit:GetText())
            f:Hide()
            UI:Refresh()
        end)
        if PT.StyleButton then PT:StyleButton(saveBtn, 12) end

        local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        clearBtn:SetSize(90, 22)
        clearBtn:SetPoint("BOTTOMLEFT", 12, 10)
        clearBtn:SetText(CLEAR_ALL or "Clear")
        clearBtn:SetScript("OnClick", function()
            f.edit:SetText("")
            SetCharNote(f.charKey, "")
            f:Hide()
            UI:Refresh()
        end)
        if PT.StyleButton then PT:StyleButton(clearBtn, 12) end

        self.noteEditDialog = f
    end

    local f = self.noteEditDialog
    f.charKey = charKey
    f.title:SetText((L["AO_NOTE_TITLE"] or "Note") .. ": " .. charKey)
    local text = GetCharNote(charKey)
    f.edit:SetText(text)
    f:Show()
    f:Raise()
    C_Timer.After(0, function()
        if not f:IsShown() then return end
        f.edit:SetFocus()
        f.edit:SetCursorPosition(#text)
    end)
end

function UI:ConfirmDeleteCharacter(charKey)
    StaticPopupDialogs["HIRONCRAFT_PROFIT_AO_DELETE_CHAR"] = {
        text = string.format(
            L["AO_DELETE_CHAR_TEXT"] or "Remove character?\n\n%s",
            charKey or ""
        ),
        button1 = YES,
        button2 = NO,
        OnAccept = function()
            if HironCraftProfit_DB
               and HironCraftProfit_DB.accountOverview
               and HironCraftProfit_DB.accountOverview.chars
            then
                HironCraftProfit_DB.accountOverview.chars[charKey] = nil
            end
            UI:Refresh()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopup_Show("HIRONCRAFT_PROFIT_AO_DELETE_CHAR")
end

if not PT._AccountOverviewLayerHooked then
    PT._AccountOverviewLayerHooked = true

    hooksecurefunc("ShowUIPanel", function(frame)
        local f = UI.frame
        if not f or not f:IsShown() then return end
        if frame == f then return end

        SetAccountOverviewActive(false)
    end)
end