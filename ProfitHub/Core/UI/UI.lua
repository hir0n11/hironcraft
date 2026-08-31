local PT = HironCraftProfit
local L = PT.L
local Tracker = PT.Tracker
local Tooltip = PT.Tooltip

local function IsFantasy()
    return PT.IsFantasyDesign and PT:IsFantasyDesign()
end

local function GetProfessionFilters()
    HironCraftProfit_CharConfig = HironCraftProfit_CharConfig or {}
    HironCraftProfit_CharConfig.professionFilters = HironCraftProfit_CharConfig.professionFilters or {}

    local F = HironCraftProfit_CharConfig.professionFilters

    if F.uniqueTreasure == nil then F.uniqueTreasure = true end
    if F.uniqueBook     == nil then F.uniqueBook     = true end
    if F.weekly         == nil then F.weekly         = true end
    if F.catchUp        == nil then F.catchUp        = true end
    if F.treatise       == nil then F.treatise       = true end
    if F.onlyMap        == nil then F.onlyMap        = false end
    if F.showZeal       == nil then F.showZeal       = true end

    return F
end

HironCraftProfit_CharConfig = HironCraftProfit_CharConfig or {}
HironCraftProfit_CharConfig.activeDB = HironCraftProfit_CharConfig.activeDB or "MID"
HironCraftProfit_CharConfig.dbRotation = HironCraftProfit_CharConfig.dbRotation or { "MID", "TWW", "DF" }

local CHECKBOX_ON  = "Interface\\Buttons\\UI-CheckBox-Check"
local CHECKBOX_OFF = "Interface\\Buttons\\UI-CheckBox-Up"

local function GetActivePreset()
    local F = GetProfessionFilters()

    if F.onlyMap then
        return "only_map"
    end

    if F.weekly
       and not F.uniqueTreasure
       and not F.uniqueBook
       and not F.catchUp
       and not F.treatise
    then
        return "only_weekly"
    end

    if F.uniqueTreasure
       and F.uniqueBook
       and F.weekly
       and F.catchUp
       and F.treatise
       and not F.onlyMap
    then
        return "all"
    end

    return nil
end

local function ApplyFilterPreset_All()
    local F = GetProfessionFilters()
    F.uniqueTreasure = true
    F.uniqueBook     = true
    F.weekly         = true
    F.catchUp        = true
    F.treatise       = true
    F.onlyMap        = false
end

local function ApplyFilterPreset_OnlyMap()
    local F = GetProfessionFilters()
    F.uniqueTreasure = true
    F.uniqueBook     = true
    F.weekly         = true
    F.catchUp        = true
    F.treatise       = true
    F.onlyMap        = true
end

local function ApplyFilterPreset_OnlyWeekly()
    local F = GetProfessionFilters()
    F.uniqueTreasure = false
    F.uniqueBook     = false
    F.weekly         = true
    F.catchUp        = false
    F.treatise       = false
    F.onlyMap        = false
end

PT.collapsedProfessions = PT.collapsedProfessions or {}
PT.adminShowAllProfessions = PT.adminShowAllProfessions or false

local MID_ZEAL_CURRENCY_BY_PROFESSION = {
    [2906] = 3256,
    [2912] = 3260,
    [2909] = 3258,
    [2916] = 3264,
    [2917] = 3265,
    [2907] = 3257,
    [2918] = 3266,
    [2915] = 3263,
    [2914] = 3262,
    [2910] = 3259,
    [2913] = 3261,
}
PT.MID_ZEAL_CURRENCY_BY_PROFESSION = MID_ZEAL_CURRENCY_BY_PROFESSION

PT.MID_ZEAL_CURRENCY_BY_PARENT_PROFESSION = {
    [171] = 3256,
    [182] = 3260,
    [333] = 3258,
    [186] = 3264,
    [393] = 3265,
    [164] = 3257,
    [197] = 3266,
    [165] = 3263,
    [755] = 3262,
    [202] = 3259,
    [773] = 3261,
}

local MID_ZEAL_COLOR = { 0.80, 0.40, 1.00 }

local function GetProfessionZealInfo(profession)
    if not profession or profession.expansion ~= "MID" then
        return nil
    end

    local currencyID = MID_ZEAL_CURRENCY_BY_PROFESSION[profession.id]
    if not currencyID then
        return nil
    end

    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    if not info then
        return nil
    end

    return {
        quantity = info.quantity or 0,
        icon = info.iconFileID,
    }
end

local FONT          = HironCraftProfit.FONT
local DEFAULT_SCALE = HironCraftProfit.SCALE_DEFAULT
local SCALE_STEP    = HironCraftProfit.SCALE_STEP
local SCALE_MIN     = HironCraftProfit.SCALE_MIN
local SCALE_MAX     = HironCraftProfit.SCALE_MAX
local pendingRowsByItemId = {}

local function NormalizeItemId(v)
    return HironCraftProfit.NormalizeItemId(v)
end

local refreshQueued = false
local function QueueRefreshUI()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0, function()
        refreshQueued = false
        if PT.RefreshUI then
            PT:RefreshUI()
        end
    end)
end

local itemEventFrame = CreateFrame("Frame")
itemEventFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
itemEventFrame:SetScript("OnEvent", function(_, _, itemID, success)
    if not success then return end

    local rows = pendingRowsByItemId[itemID]
    if not rows then return end

    local name = C_Item.GetItemNameByID(itemID) or GetItemInfo(itemID)
    local icon = C_Item.GetItemIconByID(itemID)

    for i = #rows, 1, -1 do
        local row = rows[i]
        if not row or not row:IsShown() then
            table.remove(rows, i)
        else
            if name and row.text then
                row.text:SetText(name)
            end
            if icon and row.icon then
                row.icon:SetTexture(icon)
            end

            local item = row._ahuiItem
            if item and item.MeetRequirements and row.text and row.value then
                local ok = item:MeetRequirements()
                if ok then
                    row.text:SetTextColor(1, 1, 1)
                else
                    row.text:SetTextColor(1, 0.2, 0.2)
                end

                local val = item.GetRemainingKnowledgePoints and item:GetRemainingKnowledgePoints() or 0
                if val > 0 then
                    row.value:SetText("+" .. val)
                else
                    row.value:SetText("")
                end
            end
        end
    end

    if #rows == 0 then
        pendingRowsByItemId[itemID] = nil
    end
end)

local mapEventFrame = CreateFrame("Frame")
mapEventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
mapEventFrame:RegisterEvent("ZONE_CHANGED")
mapEventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
mapEventFrame:SetScript("OnEvent", function()
    QueueRefreshUI()
end)

local professionEventFrame = CreateFrame("Frame")
professionEventFrame:RegisterEvent("SKILL_LINES_CHANGED")
professionEventFrame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
professionEventFrame:RegisterEvent("CHAT_MSG_SKILL")
professionEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

professionEventFrame:SetScript("OnEvent", function()
    C_Timer.After(0, function()
        if PT.LoadActiveDB then
            PT.LoadActiveDB()
        end
        if PT.RefreshData then
            PT:RefreshData()
        end
        QueueRefreshUI()
    end)
end)


local function WarmupItemsForActiveDB()
    if not HironCraftProfit or not HironCraftProfit.professions then return end

    for _, prof in pairs(HironCraftProfit.professions) do
        if prof.entries then
            for _, entry in ipairs(prof.entries) do
                local id = NormalizeItemId(entry.itemId)
                if id then
                    C_Item.RequestLoadItemDataByID(id)
                end
            end
        end
    end
end

local function WarmupProfessionInfo()
    if not HironCraftProfit or not HironCraftProfit.professions then return end

    for _, p in pairs(HironCraftProfit.professions) do
        C_TradeSkillUI.GetProfessionInfoBySkillLineID(p.id)
        C_TradeSkillUI.GetChildProfessionInfo(p.id)
        C_TradeSkillUI.GetTradeSkillTexture(p.id)
    end
end

local function ApplyBackdrop(frame, r, g, b, a)
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(r, g, b, a)
end

local function GetItemDistanceSq(item)
    if not item
       or not item.waypoint
       or not item.waypoint.map
       or not item.waypoint.x
       or not item.waypoint.y
    then
        return nil
    end

    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID or mapID ~= item.waypoint.map then
        return nil
    end

    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return nil end

    local px, py = pos:GetXY()
    local dx = px - item.waypoint.x
    local dy = py - item.waypoint.y

    return dx * dx + dy * dy
end

local function SortItems(a, b)
    local aDist = a._distSq
    local bDist = b._distSq

    local aOnMap = aDist ~= nil
    local bOnMap = bDist ~= nil

    if aOnMap ~= bOnMap then
        return aOnMap
    end

    if aOnMap and bOnMap and aDist ~= bDist then
        return aDist < bDist
    end

    local A = a.GetType and a:GetType() or 99
    local B = b.GetType and b:GetType() or 99
    if A ~= B then return A < B end

    return (a:GetName() or "") < (b:GetName() or "")
end

local function SavePosition(frame)
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB.positions = HironCraftProfit_DB.positions or {}

    local x = frame:GetLeft()
    local y = frame:GetTop() - (GetScreenHeight() / frame:GetScale())

    if not x or not y then return end

    HironCraftProfit_DB.positions.professions = {
        x = x,
        y = y,
    }
end

local function LoadPosition(frame)
    frame:ClearAllPoints()

    if HironCraftProfit_DB
       and HironCraftProfit_DB.positions
       and HironCraftProfit_DB.positions.professions
    then
        local p = HironCraftProfit_DB.positions.professions
        frame:SetPoint("TOPLEFT", p.x, p.y)
    else
        frame:SetPoint("TOPLEFT", 20, -20)
    end
end

local function IsWindowLocked()
    return (InCombatLockdown and InCombatLockdown())
        or (PT.config and PT.config.lockWindows == true)
end

local function StopDragAndSave(root)
    if not root then return end

    root:StopMovingOrSizing()

    local x = root:GetLeft()
    local y = root:GetTop() - (GetScreenHeight() / root:GetScale())
    if not x or not y then return end

    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB.positions = HironCraftProfit_DB.positions or {}
    HironCraftProfit_DB.positions.professions = { x = x, y = y }

    root:ClearAllPoints()
    root:SetPoint("TOPLEFT", x, y)
    root:SetUserPlaced(true)
end

local function MakeDraggable(child, root)
    if not child or not root or not child.RegisterForDrag then return end

    child:EnableMouse(true)
    child:RegisterForDrag("LeftButton")

    child:SetScript("OnDragStart", function()
        if IsWindowLocked() then return end
        root:StartMoving()
    end)

    child:SetScript("OnDragStop", function()
        StopDragAndSave(root)
    end)
end

local ALL_DBS = { "MID", "TWW", "DF" }

local function GetDBRotation(rotationKey)
    local r = HironCraftProfit_CharConfig[rotationKey or "dbRotation"]
    if type(r) == "table" and #r > 0 then return r end
    return ALL_DBS
end

local _dbMenuOverlay = nil
local _dbMenuFrame   = nil
local _dbMenuRotKey  = nil
local _dbMenuActKey  = nil

local DB_LABELS = {
    DF  = "Dragonflight",
    TWW = "The War Within",
    MID = "Midnight",
}

local function ShowDBRotationMenu(anchorBtn, rotationKey, activeKey, onChangeFn)
    _dbMenuRotKey = rotationKey or "dbRotation"
    _dbMenuActKey = activeKey   or "activeDB"

    if not _dbMenuOverlay then
        _dbMenuOverlay = CreateFrame("Frame", nil, UIParent)
        _dbMenuOverlay:SetAllPoints(UIParent)
        _dbMenuOverlay:SetFrameStrata("FULLSCREEN_DIALOG")
        _dbMenuOverlay:EnableMouse(true)
        _dbMenuOverlay:Hide()
        _dbMenuOverlay:SetScript("OnMouseDown", function()
            _dbMenuFrame:Hide()
            _dbMenuOverlay:Hide()
        end)
    end

    if not _dbMenuFrame then
        local m = CreateFrame("Frame", nil, _dbMenuOverlay, "BackdropTemplate")
        m:SetSize(180, #ALL_DBS * 24 + 12)
        m:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        m:SetBackdropColor(0, 0, 0, 0.95)
        m:SetBackdropBorderColor(1, 1, 1, 0.15)
        m:EnableMouse(true)
        m:SetScript("OnHide", function()
            _dbMenuOverlay:Hide()
        end)

        m._rows = {}
        for i, db in ipairs(ALL_DBS) do
            local row = CreateFrame("Button", nil, m)
            row:SetSize(164, 22)
            row:SetPoint("TOPLEFT", 8, -6 - (i - 1) * 24)

            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetColorTexture(1, 1, 1, 0)

            row.box = row:CreateTexture(nil, "ARTWORK")
            row.box:SetSize(12, 12)
            row.box:SetPoint("LEFT", 2, 0)
            row.box:SetTexture("Interface\\Buttons\\WHITE8x8")

            row.label = row:CreateFontString(nil, "OVERLAY")
            row.label:SetFont(FONT, 12)
            row.label:SetPoint("LEFT", row.box, "RIGHT", 6, 0)
            row.label:SetText(DB_LABELS[db])

            row._db = db

            row:SetScript("OnEnter", function(self)
                self.bg:SetColorTexture(1, 1, 1, 0.08)
            end)
            row:SetScript("OnLeave", function(self)
                self.bg:SetColorTexture(1, 1, 1, 0)
            end)
            row:SetScript("OnClick", function(self)
                local rot = HironCraftProfit_CharConfig[_dbMenuRotKey] or { "MID", "TWW", "DF" }
                local found = false
                for j, v in ipairs(rot) do
                    if v == self._db then
                        if #rot > 1 then
                            table.remove(rot, j)
                            local cur = HironCraftProfit_CharConfig[_dbMenuActKey] or "MID"
                            if cur == self._db then
                                HironCraftProfit_CharConfig[_dbMenuActKey] = rot[1]
                            end
                        end
                        found = true
                        break
                    end
                end
                if not found then
                    local order = { MID = 1, TWW = 2, DF = 3 }
                    local inserted = false
                    for j, v in ipairs(rot) do
                        if order[self._db] < order[v] then
                            table.insert(rot, j, self._db)
                            inserted = true
                            break
                        end
                    end
                    if not inserted then
                        table.insert(rot, self._db)
                    end
                end
                HironCraftProfit_CharConfig[_dbMenuRotKey] = rot
                m:_Refresh()
                if onChangeFn then onChangeFn() end
            end)

            m._rows[i] = row
        end

        function m:_Refresh()
            local rot = HironCraftProfit_CharConfig[_dbMenuRotKey] or ALL_DBS
            local cur = HironCraftProfit_CharConfig[_dbMenuActKey] or "MID"
            local inRot = {}
            for _, v in ipairs(rot) do
                inRot[v] = true
            end
            for _, row in ipairs(self._rows) do
                if inRot[row._db] then
                    if row._db == cur then
                        row.box:SetVertexColor(0.2, 0.9, 0.2, 1)
                    else
                        row.box:SetVertexColor(0.2, 0.6, 0.2, 0.8)
                    end
                else
                    row.box:SetVertexColor(0.4, 0.4, 0.4, 0.6)
                end
            end
        end

        _dbMenuFrame = m
    end

    local scale = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    local ux = cx / scale
    local uy = cy / scale

    local mw = _dbMenuFrame:GetWidth()
    local mh = _dbMenuFrame:GetHeight()
    local sw = UIParent:GetRight()
    local sh = UIParent:GetTop()

    local mx = ux + 4
    if mx + mw > sw then mx = ux - mw - 4 end

    local my = uy
    if my - mh < 0 then my = mh end

    _dbMenuFrame:ClearAllPoints()
    _dbMenuFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", mx, my)
    _dbMenuFrame:SetScale(1)
    _dbMenuFrame:_Refresh()
    _dbMenuOverlay:Show()
    _dbMenuFrame:Show()
end

PT.ShowDBRotationMenu = ShowDBRotationMenu
PT.GetDBRotation      = GetDBRotation
PT.DB_LABELS          = DB_LABELS

SLASH_HIRONCRAFT_PROFITADMINPROF1 = "/ahuiprof"
SLASH_HIRONCRAFT_PROFITADMINPROF2 = "/aprof"

SlashCmdList["HIRONCRAFT_PROFITADMINPROF"] = function(msg)
    msg = strlower(strtrim(tostring(msg or "")))

    if msg == "on" then
        PT.adminShowAllProfessions = true
        print("|cffb19cd9HironCraft:|r admin professions mode |cff00ff00ON|r")
    elseif msg == "off" then
        PT.adminShowAllProfessions = false
        print("|cffb19cd9HironCraft:|r admin professions mode |cffff4040OFF|r")
    else
        PT.adminShowAllProfessions = not PT.adminShowAllProfessions
        print("|cffb19cd9HironCraft:|r admin professions mode " ..
            (PT.adminShowAllProfessions and "|cff00ff00ON|r" or "|cffff4040OFF|r"))
    end

    if PT.RefreshData then
        PT:RefreshData()
    end
    if PT.RefreshUI then
        PT:RefreshUI()
    end
end

local DB_SELECTOR_ATLAS = "glues-characterSelect-GS-TopHUD-iconShop"
local DB_COLORS = {
    DF  = { 0.30, 0.60, 1.00 }, -- синий
    TWW = { 1.00, 0.55, 0.15 }, -- оранжевый
    MID = { 0.70, 0.45, 1.00 }, -- фиолетовый
}
PT.DB_SELECTOR_ATLAS = DB_SELECTOR_ATLAS
PT.DB_COLORS = DB_COLORS

local function CreateDBSelector(frame)
    local btn = CreateFrame("Button", nil, frame)
    btn:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 14, 2)
    btn:SetSize(15, 15)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints()

    function btn:Update()
        local db = HironCraftProfit_CharConfig.activeDB or "MID"
        btn.icon:SetAtlas(DB_SELECTOR_ATLAS)
        local c = DB_COLORS[db] or DB_COLORS.MID
        btn.icon:SetVertexColor(c[1], c[2], c[3])
    end

    function btn:UpdateTooltip()
        Tooltip:Clear()
        Tooltip:AddLine(L["DB_Selector_Title"], 14, 1, 1, 1)
        Tooltip:AddLine(" ")

        local db = HironCraftProfit_CharConfig.activeDB or "MID"
        local labels = PT.DB_LABELS or { DF = "Dragonflight", TWW = "The War Within", MID = "Midnight" }
        Tooltip:AddLine(labels[db] or db, 12, 1, 0.82, 0)

        local rot = GetDBRotation("dbRotation")
        if #rot > 1 then
            Tooltip:AddLine(" ")
            Tooltip:AddLine(L["DB_Rotation_LMB"]:format(table.concat(rot, " > ")), 11, 0.6, 0.6, 0.6)
        end
        Tooltip:AddLine(L["DB_Rotation_RMB"], 11, 0.6, 0.6, 0.6)

        Tooltip:AddLine(" ")
        Tooltip:AddLine(L["UI_SCALE_ALT_WHEEL"] or "Alt + Mouse Wheel — change scale", 11, 0.6, 0.6, 0.6)
        Tooltip:AddLine(L["UI_SCALE_ALT_MMB"] or "Alt + Middle Mouse Button — reset scale", 11, 0.6, 0.6, 0.6)

        Tooltip:ShowAtCursor()
    end

    btn:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            ShowDBRotationMenu(self, "dbRotation", "activeDB", function()
                if PT.LoadActiveDB then
                    PT.LoadActiveDB()
                end
                if PT.RefreshData then
                    PT:RefreshData()
                end

                self:Update()
                if self:IsMouseOver() then self:UpdateTooltip() end

                QueueRefreshUI()
            end)
            return
        end

        local list = GetDBRotation("dbRotation")
        local cur = HironCraftProfit_CharConfig.activeDB or "MID"
        local pos = 1
        for i, v in ipairs(list) do
            if v == cur then
                pos = i
                break
            end
        end
        pos = pos + 1
        if pos > #list then pos = 1 end

        local newDB = list[pos]
        HironCraftProfit_CharConfig.activeDB = newDB
        PT.config.activeDB = newDB

        PT.LoadActiveDB()
        PT:RefreshData()

        C_Timer.After(0, function()
            WarmupProfessionInfo()
            WarmupItemsForActiveDB()
            C_Timer.After(0.1, function()
                QueueRefreshUI()
            end)
        end)

        self:Update()
        if PT.UpdateAllProfessionNames then
            PT.UpdateAllProfessionNames()
        end

        QueueRefreshUI()

        if self:IsMouseOver() then
            self:UpdateTooltip()
        end
    end)

    btn:SetScript("OnEnter", function()
        btn:UpdateTooltip()
    end)

    btn:SetScript("OnLeave", function()
        Tooltip:Clear()
    end)

    btn:Update()
    frame.dbSelector = btn
end

local UI = {}
PT.UI = UI

function UI:ApplyCustomization()
    if not self.frame then return end
    if not PT.config or not PT.config.customization then return end

    local cfg = PT.config.customization.professionsWindow
    if not cfg then return end

    local font = PT.FONT
    cfg.font = font
    local fontSize = tonumber(cfg.fontSize) or 11
    if fontSize <= 0 then fontSize = 11 end
    local fontColor = (cfg.__preview and cfg.__preview.fontColor) or cfg.fontColor

    local bg = (cfg.__preview and cfg.__preview.backgroundColor) or cfg.backgroundColor
    if self.frame.bg and bg then
        self.frame.bg:SetColorTexture(bg.r, bg.g, bg.b, bg.a)
    end

    local border = (cfg.__preview and cfg.__preview.borderColor) or cfg.borderColor
    if border then
        self.frame:SetBackdropBorderColor(border.r, border.g, border.b, border.a)
    end

    if self.frame.title and font then
        local _, defaultSize, flags = self.frame.title:GetFont()
        if not defaultSize or defaultSize <= 0 then
            defaultSize = 14
        end

        self.frame.title:SetFont(font, defaultSize, flags)
        if fontColor then
            self.frame.title:SetTextColor(fontColor.r, fontColor.g, fontColor.b, fontColor.a)
        end
    end

    local headers = PT.UI and PT.UI.headers
    if headers then
        for _, header in ipairs(headers) do
            local h = (cfg.__preview and cfg.__preview.headerColor) or cfg.headerColor
            if h then
                header:SetBackdropColor(h.r, h.g, h.b, h.a)
            end

            if header.text and font then
                header.text:SetFont(font, fontSize)
                if fontColor then
                    header.text:SetTextColor(fontColor.r, fontColor.g, fontColor.b, fontColor.a)
                end
            end
        end
    end

    if self.itemRows then
        for _, row in ipairs(self.itemRows) do
            if row.text and font then
                row.text:SetFont(font, fontSize)
            end
            if row.value and font then
                row.value:SetFont(font, fontSize)
            end
        end
    end
end

function UI:SetScale(delta)
    HironCraftProfit_Config = HironCraftProfit_Config or {}
    HironCraftProfit_Config.professionsScale = HironCraftProfit_Config.professionsScale or DEFAULT_SCALE

    local nextScale = HironCraftProfit_Config.professionsScale + delta
    nextScale = math.max(SCALE_MIN, math.min(SCALE_MAX, nextScale))

    HironCraftProfit_Config.professionsScale = nextScale

    if self.frame then
        self.frame:SetScale(nextScale)
    end
end

function UI:ResetScale()
    HironCraftProfit_Config = HironCraftProfit_Config or {}
    HironCraftProfit_Config.professionsScale = DEFAULT_SCALE

    if self.frame then
        self.frame:SetScale(DEFAULT_SCALE)
    end
end

function UI:CreateMainFrame()
    if self.frame then return self.frame end

    local f = CreateFrame("Frame", "HironCraftProfitFrame", UIParent, "BackdropTemplate")
    f:SetSize(330, 70)

    HironCraftProfit_Config = HironCraftProfit_Config or {}
    local scale = HironCraftProfit_Config.professionsScale or DEFAULT_SCALE
    f:SetScale(scale)

    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    f:SetBackdropColor(0, 0, 0, 0)
    f:SetBackdropBorderColor(0, 0, 0, 0)

    ApplyBackdrop(f, 0, 0, 0, 0)

    LoadPosition(f)

    f:SetMovable(true)
    f:EnableMouse(true)
    f:EnableMouseWheel(true)
    f:SetClampedToScreen(true)
    f:SetClampRectInsets(0, 0, -40, 0)

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

    f:SetScript("OnMouseUp", function(self, button)
        if button == "MiddleButton" and IsAltKeyDown() then
            UI:ResetScale()
        end
    end)

    local filterBtn = CreateFrame("Button", nil, f)
    filterBtn:SetSize(15, 15)
    filterBtn:SetPoint("TOPRIGHT", -2, -8)

    filterBtn.icon = filterBtn:CreateTexture(nil, "ARTWORK")
    filterBtn.icon:SetAllPoints()
    filterBtn.icon:SetAtlas("uitools-icon-settings")
    filterBtn.icon:SetVertexColor(1, 1, 1)

    f.filterBtn = filterBtn

    filterBtn:SetScript("OnEnter", function(self)
        if not Tooltip then return end

        Tooltip:Clear()
        Tooltip:AddLine(L["FILTER_TOOLTIP_TITLE"] or "Filters", 14, 1, 1, 1)
        Tooltip:AddLine(" ")
        Tooltip:AddLine(L["FILTER_TOOLTIP_HINT"] or "Configure what is shown in the list", 12, 0.8, 0.8, 0.8)
        Tooltip:ShowAtCursor()
    end)

    filterBtn:SetScript("OnLeave", function()
        if Tooltip then
            Tooltip:Clear()
        end
    end)

    filterBtn:SetScript("OnClick", function(self)
        local F = GetProfessionFilters()
        local activePreset = GetActivePreset()

        PT.Dropdown:Show({
            owner = self,
            items = {
                { header = true, text = L["FILTER_PRESETS"] or "Presets:" },

                {
                    text = L["FILTER_PRESET_ALL"] or "All",
                    icon = (activePreset == "all") and CHECKBOX_ON or CHECKBOX_OFF,
                    iconSize = 14,
                    onClick = function()
                        ApplyFilterPreset_All()
                        QueueRefreshUI()
                    end,
                },
                {
                    text = L["FILTER_PRESET_ONLY_MAP"] or "Only this map",
                    icon = (activePreset == "only_map") and CHECKBOX_ON or CHECKBOX_OFF,
                    iconSize = 14,
                    onClick = function()
                        ApplyFilterPreset_OnlyMap()
                        QueueRefreshUI()
                    end,
                },
                {
                    text = L["FILTER_PRESET_ONLY_WEEKLY"] or "Only weekly",
                    icon = (activePreset == "only_weekly") and CHECKBOX_ON or CHECKBOX_OFF,
                    iconSize = 14,
                    onClick = function()
                        ApplyFilterPreset_OnlyWeekly()
                        QueueRefreshUI()
                    end,
                },

                { header = true, text = L["FILTER_SHOW"] or "Show:" },

                {
                    text     = L["FILTER_UNIQUE_TREASURE"] or "Unique Treasures",
                    icon     = F.uniqueTreasure and CHECKBOX_ON or CHECKBOX_OFF,
                    iconSize = 14,
                    onClick = function()
                        F.uniqueTreasure = not F.uniqueTreasure
                        QueueRefreshUI()
                    end,
                },
                {
                    text     = L["FILTER_UNIQUE_BOOK"] or "Unique Books",
                    icon     = F.uniqueBook and CHECKBOX_ON or CHECKBOX_OFF,
                    iconSize = 14,
                    onClick = function()
                        F.uniqueBook = not F.uniqueBook
                        QueueRefreshUI()
                    end,
                },
                {
                    text     = L["FILTER_WEEKLY"] or "Weekly",
                    icon     = F.weekly and CHECKBOX_ON or CHECKBOX_OFF,
                    iconSize = 14,
                    onClick = function()
                        F.weekly = not F.weekly
                        QueueRefreshUI()
                    end,
                },
                {
                    text     = L["FILTER_CATCHUP"] or "Catch-up",
                    icon     = F.catchUp and CHECKBOX_ON or CHECKBOX_OFF,
                    iconSize = 14,
                    onClick = function()
                        F.catchUp = not F.catchUp
                        QueueRefreshUI()
                    end,
                },
                {
                    text     = L["FILTER_TREATISE"] or "Treatise",
                    icon     = F.treatise and CHECKBOX_ON or CHECKBOX_OFF,
                    iconSize = 14,
                    onClick = function()
                        F.treatise = not F.treatise
                        QueueRefreshUI()
                    end,
                },
                {
                    text     = L["FILTER_SHOW_ZEAL"] or "Artisan's Moxie",
                    icon     = F.showZeal and CHECKBOX_ON or CHECKBOX_OFF,
                    iconSize = 14,
                    onClick = function()
                        F.showZeal = not F.showZeal
                        QueueRefreshUI()
                    end,
                },
            }
        })
    end)

    CreateDBSelector(f)

    local function SetChromeVisible(visible)
        local alpha = visible and 1 or 0

        filterBtn:SetAlpha(alpha)
        filterBtn:EnableMouse(visible)

        if f.dbSelector then
            f.dbSelector:SetAlpha(alpha)
            f.dbSelector:EnableMouse(visible)
        end
    end

    SetChromeVisible(false)

    local hoverElapsed = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        hoverElapsed = hoverElapsed + elapsed
        if hoverElapsed < 0.05 then
            return
        end
        hoverElapsed = 0

        local hovered =
            self:IsMouseOver() or
            filterBtn:IsMouseOver() or
            (self.dbSelector and self.dbSelector:IsMouseOver()) or
            (_dbMenuFrame and _dbMenuFrame:IsShown() and _dbMenuFrame:IsMouseOver())

        if hovered ~= self._ahuiChromeShown then
            self._ahuiChromeShown = hovered
            SetChromeVisible(hovered)
        end
    end)

    local content = CreateFrame("Frame", nil, f)
    content:EnableMouse(true)
    MakeDraggable(content, f)
    content:SetPoint("TOPLEFT", 10, -35)
    content:SetPoint("TOPRIGHT", -10, -35)
    content:SetHeight(1)

    MakeDraggable(f, f)

    self.content = content
    self.frame   = f

    PT:RegisterVisibilityFrame(
        f,
        "hideProfessionsInCombat",
        "hideProfessionsInInstance",
        "showProfessionsWindow"
    )

    PT:UpdateVisibility()
    return f
end

local function HasNearbyTreasure(profession)
    for _, entry in ipairs(profession.entries or {}) do
        if entry.IsUniqueTreasure
           and entry:GetRemainingKnowledgePoints() > 0
           and entry.IsOnSameMap
           and entry:IsOnSameMap()
        then
            return true
        end
    end
    return false
end

local function CreateProfessionHeader(parent, profession)
    local header = CreateFrame("Button", nil, parent, "BackdropTemplate")
    header:SetSize(310, 20)
    if UI.frame then
        MakeDraggable(header, UI.frame)
    end
    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    header:SetBackdropColor(0.10, 0.10, 0.10, 0.85)

    if IsFantasy() then
        header.bgFantasy = header:CreateTexture(nil, "BACKGROUND")
        header.bgFantasy:SetAllPoints()
        header.bgFantasy:SetAtlas("Professions-Specializations-Background-Footer")
        if header.bgFantasy:GetAtlas() then
            header:SetBackdropColor(0, 0, 0, 0)
        else
            header.bgFantasy:Hide()
        end
    end

    header.icon = header:CreateTexture(nil, "ARTWORK")
    header.icon:SetSize(16, 16)
    header.icon:SetPoint("LEFT", 4, 0)
    header.icon:SetTexture(profession.icon)

    header.text = header:CreateFontString(nil, "OVERLAY")
    header.text:SetFont(FONT, 12)
    header.text:SetPoint("LEFT", header, "LEFT", 24, 0)
    header.text:SetJustifyH("LEFT")

    local name = profession.name or "Profession"
    local skillInfo = profession.GetSkillLevel and profession:GetSkillLevel()
    if skillInfo and skillInfo.skillLevel then
        local skill = skillInfo.skillLevel or 0
        local max   = skillInfo.maxSkillLevel or 100
        local bonus = skillInfo.bonusSkill or skillInfo.skillModifier or 0

        if bonus > 0 then
            header.text:SetText(name .. "  " .. skill .. "/" .. max .. " |cff66cfff(+" .. bonus .. ")|r")
        else
            header.text:SetText(name .. "  " .. skill .. "/" .. max)
        end
    else
        header.text:SetText(name)
    end

    header.kpText = header:CreateFontString(nil, "OVERLAY")
    header.kpText:SetFont(FONT, 11)
    header.kpText:SetPoint("RIGHT", header, "RIGHT", -17, 0)
    header.kpText:SetJustifyH("RIGHT")
    header.kpText:SetTextColor(0, 1, 0)

    header.mapIcon = header:CreateTexture(nil, "OVERLAY")
    header.mapIcon:SetSize(14, 14)
    header.mapIcon:SetAtlas("poi-islands-table")
    header.mapIcon:Hide()

    header.zealIcon = header:CreateTexture(nil, "OVERLAY")
    header.zealIcon:SetSize(14, 14)
    header.zealIcon:SetPoint("RIGHT", header, "RIGHT", -82, 0)
    header.zealIcon:Hide()

    header.zealText = header:CreateFontString(nil, "OVERLAY")
    header.zealText:SetFont(FONT, 11)
    header.zealText:SetJustifyH("LEFT")
    header.zealText:SetPoint("LEFT", header.zealIcon, "RIGHT", 1, 0)
    header.zealText:Hide()

    local totalKP = 0
    for _, entry in ipairs(profession.entries or {}) do
        if entry.GetRemainingKnowledgePoints
           and entry.MeetRequirements
           and entry:MeetRequirements()
        then
            local val = entry:GetRemainingKnowledgePoints()
            if val and val > 0 then
                totalKP = totalKP + val
            end
        end
    end

    if totalKP > 0 then
        header.kpText:SetText("+" .. totalKP)
    else
        header.kpText:SetText("")
    end

    if HasNearbyTreasure(profession) then
        header.mapIcon:Show()
        header.mapIcon:ClearAllPoints()
        header.mapIcon:SetPoint("RIGHT", header.kpText, "LEFT", -3, 0)
    else
        header.mapIcon:Hide()
    end

    local F = GetProfessionFilters()
    local zealInfo = F.showZeal and GetProfessionZealInfo(profession) or nil

    if zealInfo then
        header.zealText:SetText(zealInfo.quantity or 0)
        header.zealText:SetTextColor(MID_ZEAL_COLOR[1], MID_ZEAL_COLOR[2], MID_ZEAL_COLOR[3])

        if zealInfo.icon then
            header.zealIcon:SetTexture(zealInfo.icon)
            header.zealIcon:Show()
            header.zealText:Show()
        else
            header.zealIcon:Hide()
            header.zealText:Hide()
        end
    else
        header.zealText:SetText("")
        header.zealText:Hide()
        header.zealIcon:Hide()
    end

    header.toggleText = header:CreateFontString(nil, "OVERLAY")
    header.toggleText:SetFont(FONT, 14, "OUTLINE")
    header.toggleText:SetPoint("RIGHT", header, "RIGHT", -2, 0)
    header.toggleText:SetJustifyH("RIGHT")
    header.toggleText:SetTextColor(1, 1, 1)

    header:SetScript("OnClick", function()
        local willExpand = not profession.expanded

        profession.expanded = willExpand
        PT.collapsedProfessions[profession.id] = not willExpand

        if willExpand then
            header.toggleText:SetText("−")
            for _, entry in ipairs(profession.entries or {}) do
                local id = NormalizeItemId(entry.itemId)
                if id then
                    C_Item.RequestLoadItemDataByID(id)
                end
            end
        else
            header.toggleText:SetText("+")
        end

        QueueRefreshUI()
    end)

    if profession.expanded then
        header.toggleText:SetText("−")
    else
        header.toggleText:SetText("+")
    end

    PT.UI.headers = PT.UI.headers or {}
    table.insert(PT.UI.headers, header)

    return header
end

local function CreateInfoRow(parent, textValue, r, g, b)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetSize(310, 18)

    if UI.frame then
        MakeDraggable(row, UI.frame)
    end

    row:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    row:SetBackdropColor(0.10, 0.10, 0.10, 0.85)

    row.text = row:CreateFontString(nil, "OVERLAY")
    row.text:SetFont(FONT, 11)
    row.text:SetPoint("LEFT", 20, 0)
    row.text:SetWidth(260)
    row.text:SetJustifyH("LEFT")
    row.text:SetTextColor(r or 1, g or 0.2, b or 0.2)
    row.text:SetText(textValue or "")

    return row
end

local function CreateItemRow(parent, item)
    if not item or not item.profession then
        return nil
    end

    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetSize(310, 18)
    if UI.frame then
        MakeDraggable(row, UI.frame)
    end
    row._ahuiItem = item

    row:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    row:SetBackdropColor(0.10, 0.10, 0.10, 0.85)

    if IsFantasy() then
        row.bgFantasy = row:CreateTexture(nil, "BACKGROUND", nil, -1)
        row.bgFantasy:SetPoint("TOPLEFT", 10, 0)
        row.bgFantasy:SetPoint("BOTTOMRIGHT", 0, 0)
        row.bgFantasy:SetAtlas("Professions-Specializations-Background-Dial")
        if row.bgFantasy:GetAtlas() then
            row:SetBackdropColor(0, 0, 0, 0)
        else
            row.bgFantasy:Hide()
        end
    end

    row.trackBg = row:CreateTexture(nil, "BACKGROUND")
    row.trackBg:SetAllPoints()
    row.trackBg:SetColorTexture(1, 0.8, 0, 0.20)
    row.trackBg:SetShown(item.isTracked)

    local id = NormalizeItemId(item.itemId)
    if id then
        C_Item.RequestLoadItemDataByID(id)
    end

    row.iconBtn = CreateFrame("Button", nil, row)
    row.iconBtn:SetSize(16, 16)
    row.iconBtn:SetPoint("LEFT", 14, 0)
    row.iconBtn:EnableMouse(true)

    row.icon = row.iconBtn:CreateTexture(nil, "ARTWORK")
    row.icon:SetAllPoints()

    local icon = (item.GetIcon and item:GetIcon()) or (id and C_Item.GetItemIconByID(id)) or 134400
    row.icon:SetTexture(icon)

    row.iconBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(row.iconBtn, "ANCHOR_RIGHT")
        if id then
            GameTooltip:SetItemByID(id)
        else
            GameTooltip:SetText(item:GetName() or "Unknown")
        end
        GameTooltip:Show()
    end)

    row.iconBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    row.iconBtn:SetScript("OnClick", function()
    end)

    local markup = item.GetCategoryIcon and item:GetCategoryIcon()
    if markup then
        row.typeFS = row:CreateFontString(nil, "OVERLAY")
        row.typeFS:SetFont(FONT, 12)
        row.typeFS:SetPoint("LEFT", row.icon, "RIGHT", 2, 0)
        row.typeFS:SetText(markup)
    end

    row.text = row:CreateFontString(nil, "OVERLAY")
    row.text:SetFont(FONT, 11)

    if row.typeFS then
        row.text:SetPoint("LEFT", row.typeFS, "RIGHT", 4, 0)
    else
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    end

    row.text:SetWidth(220)
    row.text:SetJustifyH("LEFT")

    local nm = item.GetName and item:GetName() or ""
    if (not nm or nm == "") and id then
        nm = "Loading…"
        if C_Item and C_Item.RequestLoadItemDataByID then
            C_Item.RequestLoadItemDataByID(id)
        end
        pendingRowsByItemId[id] = pendingRowsByItemId[id] or {}
        table.insert(pendingRowsByItemId[id], row)
    elseif nm == "" then
        nm = "Loading…"
    end

    row.text:SetText(nm)

    if item.MeetRequirements and not item:MeetRequirements() then
        row.text:SetTextColor(1, 0.2, 0.2)
    end

    row.value = row:CreateFontString(nil, "OVERLAY")
    row.value:SetFont(FONT, 11)
    row.value:SetPoint("RIGHT", -4, 0)
    row.value:SetWidth(40)
    row.value:SetJustifyH("RIGHT")

    local val = item.GetRemainingKnowledgePoints and item:GetRemainingKnowledgePoints() or 0
    if val > 0 then
        row.value:SetText("+" .. val)
        if item.MeetRequirements and not item:MeetRequirements() then
            row.value:SetTextColor(1, 0.2, 0.2)
        elseif item.IsCatchUp and item:IsCatchUp() then
            row.value:SetTextColor(0.2, 1, 0.2)
        else
            row.value:SetTextColor(1, 0.7, 0.2)
        end
    else
        row.value:SetText("")
    end

    row.check = row:CreateTexture(nil, "ARTWORK")
    row.check:SetSize(12, 12)
    row.check:SetPoint("RIGHT", row.value, "LEFT", -4, 0)
    row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    row.check:SetVertexColor(0.4, 1, 0.4)
    if item.GetRemainingKnowledgePoints then
        row.check:SetShown(item:GetRemainingKnowledgePoints() == 0)
    else
        row.check:Hide()
    end

    row:SetScript("OnEnter", function()
        Tooltip:Clear()
        Tooltip:AddLine(item:GetName() or "Unknown", 14, 1, 1, 1)

        if item.IsCatchUp and item:IsCatchUp()
           and item.unlockRequirements
           and next(item.unlockRequirements)
        then
            Tooltip:AddLine(" ")
            Tooltip:AddLine(L["CATCHUP_REQUIREMENTS"], 12, 1, 0.82, 0)

            for _, req in ipairs(item.unlockRequirements) do
                local ok = req:GetRemainingKnowledgePoints() == 0
                local nm2 = req:GetName() or "Unknown"
                if ok then
                    Tooltip:AddLine(" + " .. nm2, 12, 0.2, 1, 0.2)
                else
                    Tooltip:AddLine(" × " .. nm2, 12, 1, 0.2, 0.2)
                end
            end
        elseif item.IsCatchUp and item:IsCatchUp() then
            Tooltip:AddLine(" ")
            Tooltip:AddLine(
                L["CATCHUP_SOURCE_NPC_ORDERS"] or "Obtained from NPC crafting orders",
                12, 0.9, 0.9, 0.9
            )
        else
            local reqText = item.GetRequirementsText and item:GetRequirementsText()
            if reqText then
                Tooltip:AddLine(" ")
                Tooltip:AddLine(L["REQUIREMENTS"], 12, 1, 0.82, 0)
                Tooltip:AddLine(reqText, 12, 0.9, 0.9, 0.9)
            else
                local desc = item.GetDescription and item:GetDescription()
                if desc then
                    Tooltip:AddLine(" ")
                    Tooltip:AddLine(desc, 12, 0.9, 0.9, 0.9)
                end
            end
        end

        Tooltip:ShowAtCursor()
    end)

    row:SetScript("OnLeave", function()
        Tooltip:Clear()
    end)

    row:SetScript("OnClick", function()
        if not Tracker or not Tracker.ToggleTrackedItem then
            return
        end
        Tracker:ToggleTrackedItem(item)
        row.trackBg:SetShown(item.isTracked)
    end)

    PT.UI.itemRows = PT.UI.itemRows or {}
    table.insert(PT.UI.itemRows, row)

    return row
end

local function FindFirstAvailableProfessionDB()
    local currentDB = HironCraftProfit_CharConfig.activeDB or "MID"

    if PT.adminShowAllProfessions then
        if PT.LoadActiveDB then
            PT.LoadActiveDB()
        end
        local profs = PT.GetProfessions(false) or PT.GetProfessions(true)
        if profs and next(profs) then
            return currentDB, profs
        end
    end

    local order = { currentDB, "MID", "TWW", "DF" }
    local seen = {}
    local unique = {}

    for _, db in ipairs(order) do
        if not seen[db] then
            seen[db] = true
            table.insert(unique, db)
        end
    end

    local oldDB = HironCraftProfit_CharConfig.activeDB
    local oldCfgDB = PT.config.activeDB

    for _, db in ipairs(unique) do
        HironCraftProfit_CharConfig.activeDB = db
        PT.config.activeDB = db

        if PT.LoadActiveDB then
            PT.LoadActiveDB()
        end

        local profs = PT.GetProfessions(true)
        if profs and next(profs) then
            return db, profs
        end
    end

    HironCraftProfit_CharConfig.activeDB = oldDB
    PT.config.activeDB = oldCfgDB
    if PT.LoadActiveDB then
        PT.LoadActiveDB()
    end

    return nil, nil
end

function PT:RefreshUI()
    if PT.UI then
        PT.UI.headers = {}
        PT.UI.itemRows = {}
    end

    wipe(pendingRowsByItemId)

    local profs
    if PT.adminShowAllProfessions then
        profs = PT.GetProfessions(false) or PT.GetProfessions(true)
    else
        profs = PT.GetProfessions(true)
    end

    local frame = UI:CreateMainFrame()

    if PT.UpdateVisibility then
        PT:UpdateVisibility()
    else
        if PT.config.showProfessionsWindow == false then
            frame:Hide()
        else
            frame:Show()
        end
    end

    if not frame:IsShown() then
        return
    end

    local parent = UI.content
    if not parent then return end

    for _, child in ipairs({ parent:GetChildren() }) do
        child:SetParent(nil)
        child:Hide()
    end

    if not profs or not next(profs) then
        local msg = L["PG_NOT_LEARNED"] or "This profession expansion is not learned"
        local row = CreateInfoRow(parent, msg, 1, 0.2, 0.2)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -2)

        if frame.dbSelector then
            frame.dbSelector:ClearAllPoints()
            frame.dbSelector:SetPoint("BOTTOMLEFT", row, "TOPLEFT", 4, 1)
        end
        if frame.filterBtn then
            frame.filterBtn:ClearAllPoints()
            frame.filterBtn:SetPoint("BOTTOMRIGHT", row, "TOPRIGHT", 0, 1)
        end

        parent:SetHeight(28)
        frame:SetHeight(65)

        if UI.frame and UI.frame.dbSelector and UI.frame.dbSelector.Update then
            UI.frame.dbSelector:Update()
        end

        if PT.UI and PT.UI.ApplyCustomization then
            PT.UI:ApplyCustomization()
        end

        return
    end

    local ordered = {}
    for _, p in pairs(profs) do
        table.insert(ordered, p)
    end

    table.sort(ordered, function(a, b)
        return a.index < b.index
    end)

    local y = -2

    for _, profession in ipairs(ordered) do
        if PT.collapsedProfessions[profession.id] ~= nil then
            profession.expanded = not PT.collapsedProfessions[profession.id]
        end

        local header = CreateProfessionHeader(parent, profession)
        header:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
        y = y - 20

        if profession.expanded then
            local items = {}
            local F = GetProfessionFilters()

        for _, item in ipairs(profession.entries or {}) do
            item._distSq = GetItemDistanceSq(item)
            local show = true

            if not PT.adminShowAllProfessions then
                if item.Show and not item:Show() then
                    show = false
                end

                if show and F.onlyMap and item.IsOnSameMap and not item:IsOnSameMap() then
                    show = false
                end
            end

            if show and not PT.adminShowAllProfessions then
                if item.IsUniqueBook then
                    if not F.uniqueBook then
                        show = false
                    end
                elseif item.IsUniqueTreasure then
                    if not F.uniqueTreasure then
                        show = false
                    end
                elseif item.GetType and (item:GetType() == 2 or item:GetType() == 3) then
                    if not F.weekly then
                        show = false
                    end
                elseif item.GetType and item:GetType() == 4 then
                    if not F.catchUp then
                        show = false
                    end
                end

                if show and item.IsTreatise then
                    if not F.treatise then
                        show = false
                    end
                end
            end

                if show then
                    table.insert(items, item)
                end
            end

            table.sort(items, SortItems)

            if #items == 0 and (HironCraftProfit_CharConfig.activeDB or "MID") == "DF" then
                local skillInfo = profession:GetSkillLevel()
                local skill = skillInfo and skillInfo.skillLevel or 0

                if skill < 25 then
                    local row = CreateInfoRow(parent, L["REQUIRES_PROFESSION_SKILL_25"], 1, 0.2, 0.2)
                    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
                    y = y - 18
                end
            end

            for _, item in ipairs(items) do
                local row = CreateItemRow(parent, item)
                if row then
                    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
                    y = y - 18
                end
            end
        end
    end

    local contentHeight = math.abs(y) + 8
    parent:SetHeight(contentHeight)
    frame:SetHeight(math.min(contentHeight + 35, 2000))

    local firstHeader = PT.UI and PT.UI.headers and PT.UI.headers[1]

    if frame.dbSelector then
        frame.dbSelector:ClearAllPoints()
        if firstHeader then
            frame.dbSelector:SetPoint("BOTTOMLEFT", firstHeader, "TOPLEFT", 4, 1)
        else
            frame.dbSelector:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 14, 2)
        end
    end

    if frame.filterBtn then
        frame.filterBtn:ClearAllPoints()
        if firstHeader then
            frame.filterBtn:SetPoint("BOTTOMRIGHT", firstHeader, "TOPRIGHT", 0, 1)
        else
            frame.filterBtn:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -2, 2)
        end
    end

    if PT.UI and PT.UI.ApplyCustomization then
        PT.UI:ApplyCustomization()
    end
end