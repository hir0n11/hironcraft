local PT = HironCraftProfit
if not PT or not PT.SkinningCheck then return end

local SC = PT.SkinningCheck
local Tooltip = PT.Tooltip
local Tracker = PT.Tracker
local Dropdown = PT.Dropdown
local L = PT.L
PT.config.enableMapPins = PT.config.enableMapPins ~= false

local PIN_TEMPLATE = "HironCraftProfitSkinningWorldMapPinTemplate"

PT.SkinningWorldMapDataProvider = PT.SkinningWorldMapDataProvider or CreateFromMixins(MapCanvasDataProviderMixin)

local knowledgeByMap = {}
local knowledgeDirty = true
local requestedItemData = {}
local refreshQueued = false

local CHECKBOX_ON  = "Interface\\Buttons\\UI-CheckBox-Check"
local CHECKBOX_OFF = "Interface\\Buttons\\UI-CheckBox-Up"

local function GetMapPinsSize()
    local size = tonumber(PT.config.mapPinsSize) or 20
    if size < 12 then size = 12 end
    if size > 40 then size = 40 end
    return size
end

local function QueueRefreshMapPins()
    if refreshQueued then return end
    refreshQueued = true

    C_Timer.After(0.1, function()
        refreshQueued = false
        if PT.SkinningWorldMapDataProvider and WorldMapFrame and WorldMapFrame:IsShown() then
            PT.SkinningWorldMapDataProvider:RefreshAllData()
        end
    end)
end

local function MarkKnowledgeDirty()
    knowledgeDirty = true
end

local function TranslateMapPos(fromMapID, toMapID, x, y)
    if not fromMapID or not toMapID or not x or not y then return nil end
    if fromMapID == toMapID then return x, y end
    return nil
end

local allKnowledgeEntries = {}

local function RebuildKnowledgeCache()
    if not knowledgeDirty then return end

    allKnowledgeEntries = {}
    knowledgeByMap = {}

    if not PT.GetProfessions then
        knowledgeDirty = false
        return
    end

    local profs = PT.GetProfessions(true)
    if not profs then
        knowledgeDirty = false
        return
    end

    local function RegisterWaypoint(entry, wp)
        if not wp or not wp.map or not wp.x or not wp.y then return end
        table.insert(allKnowledgeEntries, { entry = entry, mapID = wp.map, x = wp.x, y = wp.y })
        knowledgeByMap[wp.map] = knowledgeByMap[wp.map] or {}
        table.insert(knowledgeByMap[wp.map], { entry = entry, x = wp.x, y = wp.y })
    end

    for _, profession in pairs(profs) do
        for _, entry in ipairs(profession.entries or {}) do
            RegisterWaypoint(entry, entry.waypoint)
            if type(entry.extraWaypoints) == "table" then
                for _, wp in ipairs(entry.extraWaypoints) do
                    RegisterWaypoint(entry, wp)
                end
            end
        end
    end

    knowledgeDirty = false
end

local function GetKnowledgeEntriesForMap(mapID)
    return knowledgeByMap[mapID]
end

local function IsSkinningTarget(data)
    return data and data.guide and data.guide.zone and SC.GetTargetName and SC:GetTargetName(data)
end

local function GetProfessionBadge(entry)
    if not entry or not entry.profession then return nil end
    return entry.profession.icon
end

local PROFESSION_ATLAS_BY_SKILLLINE = {
    [171] = "worldquest-icon-alchemy",
    [164] = "worldquest-icon-blacksmithing",
    [185] = "worldquest-icon-cooking",
    [333] = "worldquest-icon-enchanting",
    [202] = "worldquest-icon-engineering",
    [356] = "worldquest-icon-fishing",
    [182] = "worldquest-icon-herbalism",
    [773] = "worldquest-icon-inscription",
    [755] = "worldquest-icon-jewelcrafting",
    [165] = "worldquest-icon-leatherworking",
    [186] = "worldquest-icon-mining",
    [393] = "worldquest-icon-skinning",
    [197] = "worldquest-icon-tailoring",
}

local function GetProfessionAtlas(entry)
    if not entry or not entry.profession then return nil end
    return PROFESSION_ATLAS_BY_SKILLLINE[entry.profession.skillLine]
end

function PT.SkinningWorldMapDataProvider:RemoveAllData()
    if self:GetMap() then
        self:GetMap():RemoveAllPinsByTemplate(PIN_TEMPLATE)
    end
end

local function AddKnowledgePins(provider, mapID)
    if PT.config.showMapKnowledge == false then return end

    RebuildKnowledgeCache()

    local items = GetKnowledgeEntriesForMap(mapID)
    if not items or #items == 0 then return end

    for _, item in ipairs(items) do
        local entry = item.entry
        if entry.itemId and not requestedItemData[entry.itemId] then
            requestedItemData[entry.itemId] = true
            C_Item.RequestLoadItemDataByID(entry.itemId)
        end

        local show = true

        if entry.GetRemainingKnowledgePoints then
            local kp = entry:GetRemainingKnowledgePoints()
            if not kp or kp <= 0 then
                show = false
            end
        end

        if show then
            provider:GetMap():AcquirePin(
                PIN_TEMPLATE,
                entry,
                item.x,
                item.y
            )
        end
    end
end

function PT.SkinningWorldMapDataProvider:RefreshAllData()
    if PT.config.enableMapPins == false then
        self:RemoveAllData()
        return
    end

    if not self:GetMap() then return end

    self:RemoveAllData()

    local mapID = self:GetMap():GetMapID()
    if not mapID then return end

    if PT.config.showMapLures ~= false and PT.config.skinningCheckEnabled and SC:IsAvailable() then
        for _, target in ipairs(SC.TARGETS) do
            if SC:IsTargetAvailable(target)
            and SC:IsTargetEnabled(target)
            and not SC:IsTargetCompleted(target)
            then
                local zone = target.guide and target.guide.zone
                if zone and zone.map == mapID and zone.x and zone.y then
                    self:GetMap():AcquirePin(PIN_TEMPLATE, target, zone.x, zone.y)
                end
            end
        end
    end

    AddKnowledgePins(self, mapID)
end

HironCraftProfitSkinningWorldMapPinMixin = CreateFromMixins(MapCanvasPinMixin)

function HironCraftProfitSkinningWorldMapPinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_TOPMOST")
    self:SetMovable(true)
    self:SetScalingLimits(1, 1.0, 1.2)

    if self.texture then
        self.texture:SetDrawLayer("ARTWORK", 0)
    end

    if self.badge then
        self.badge:SetSize(12, 12)
        self.badge:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 1, -1)
        self.badge:SetDrawLayer("OVERLAY", 7)
        self.badge:Hide()
    end
end

function HironCraftProfitSkinningWorldMapPinMixin:OnAcquired(data, x, y)
    self.data = data
    self:SetPosition(x, y)

    local size = GetMapPinsSize()
    self:SetSize(size, size)

    if self.texture.SetAtlas then
        self.texture:SetAtlas("UI_Icon_Chest_NPCreward")
    else
        self.texture:SetTexture("Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\Media\\logo.tga")
    end

    if self.badge then
        if IsSkinningTarget(data) then
            self.badge:SetAtlas("Vehicle-Trap-Gold")
            self.badge:Show()
        else
            local badge = GetProfessionBadge(data)
            if badge then
                self.badge:SetTexture(badge)
                self.badge:Show()
            else
                self.badge:Hide()
            end
        end
    end
end

function HironCraftProfitSkinningWorldMapPinMixin:OnMouseEnter()
    if not self.data then return end

    Tooltip:Clear()

    if IsSkinningTarget(self.data) then
        Tooltip:AddLine(SC:GetTargetName(self.data), 14, 1, 1, 1)

        local guide = SC:GetGuideTooltip(self.data)
        if guide then
            Tooltip:AddLine(guide, 12, 0.85, 0.85, 0.85)
        end
    else
        local name = self.data.GetName and self.data:GetName()
        if (not name or name == "") and self.data.itemId then
            name = C_Item.GetItemNameByID(self.data.itemId)
        end
        if not name or name == "" then
            name = L["MAP_PINS_UNKNOWN"]
        end

        Tooltip:AddLine(name, 14, 1, 1, 1)

        if self.data.kp then
            Tooltip:AddLine("+" .. self.data.kp, 12, 0, 1, 0)
        end

        local text = self.data.text
        if not text and self.data.GetDescription then
            text = self.data:GetDescription()
        end
        if not text and self.data.GetRequirementsText then
            text = self.data:GetRequirementsText()
        end
        if not text then
            text = self.data.note or self.data.description
        end

        if text and text ~= "" then
            Tooltip:AddLine(text, 12, 0.85, 0.85, 0.85)
        end
    end

    Tooltip:ShowSmart(self)
end

function HironCraftProfitSkinningWorldMapPinMixin:OnMouseLeave()
    Tooltip:Clear()
end

function HironCraftProfitSkinningWorldMapPinMixin:OnMouseDown(button)
end

function HironCraftProfitSkinningWorldMapPinMixin:OnMouseUp(button)
    if button ~= "LeftButton" then return end
    if not self.data then return end

    if IsSkinningTarget(self.data) then
        SC:SetPendingWaypoint(self.data)
        return
    end

    if Tracker and Tracker.SetTrackedItem then
        Tracker:SetTrackedItem(self.data)
    elseif Tracker and Tracker.ToggleTrackedItem then
        Tracker:ToggleTrackedItem(self.data)
    end
end

HironCraftProfitSkinningWorldMapPinMixin.SetPassThroughButtons = function() end

local function HideMapPinsMenu()
    if Dropdown and Dropdown.Hide then
        Dropdown:Hide()
    end

    if PT.MapPinsSizeBox then
        if PT.MapPinsSizeBox.label then
            PT.MapPinsSizeBox.label:Hide()
            PT.MapPinsSizeBox.label:SetParent(nil)
            PT.MapPinsSizeBox.label = nil
        end

        PT.MapPinsSizeBox:Hide()
        PT.MapPinsSizeBox:SetParent(nil)
        PT.MapPinsSizeBox = nil
    end
end

PT.HideMapPinsMenu = HideMapPinsMenu

if Dropdown and Dropdown.Show and not Dropdown._mapPinsHookInstalled then
    Dropdown._mapPinsHookInstalled = true
    hooksecurefunc(Dropdown, "Show", function(_, opts)
        if not (opts and opts.tag == "mappins") then
            if PT.MapPinsSizeBox then
                if PT.MapPinsSizeBox.label then
                    PT.MapPinsSizeBox.label:Hide()
                    PT.MapPinsSizeBox.label:SetParent(nil)
                    PT.MapPinsSizeBox.label = nil
                end
                PT.MapPinsSizeBox:Hide()
                PT.MapPinsSizeBox:SetParent(nil)
                PT.MapPinsSizeBox = nil
            end
        end
    end)
end

local function ShowMapPinsSizeInput(owner)
    if not owner then return end

    if PT.MapPinsSizeBox then
        PT.MapPinsSizeBox:Hide()
        PT.MapPinsSizeBox:SetParent(nil)
        PT.MapPinsSizeBox = nil
    end

    local parent = Dropdown and Dropdown.frame or WorldMapFrame
    if not parent then return end

    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetSize(44, 20)
    box:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -18, -75)
    box:SetText(tostring(GetMapPinsSize()))
    box:SetCursorPosition(0)
    box:HighlightText()

    box.label = parent:CreateFontString(nil, "OVERLAY")
    box.label:SetFont(HironCraftProfit.FONT, 11, "")
    box.label:SetPoint("RIGHT", box, "LEFT", -6, 0)
    box.label:SetText(L["MAP_PINS_SIZE"])

    local function ApplyValue()
        local v = tonumber(box:GetText())
        if not v then
            box:SetText(tostring(GetMapPinsSize()))
            return
        end

        v = math.floor(v + 0.5)
        if v < 12 then v = 12 end
        if v > 40 then v = 40 end

        PT.config.mapPinsSize = v
        box:SetText(tostring(v))
        QueueRefreshMapPins()
    end

    box:SetScript("OnEnterPressed", function(self)
        ApplyValue()
        self:ClearFocus()
    end)

    box:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(GetMapPinsSize()))
        self:ClearFocus()
    end)

    box:SetScript("OnEditFocusLost", function()
        ApplyValue()
    end)

    PT.MapPinsSizeBox = box
end


local function ShowMapPinsMenu(owner)
    if not Dropdown or not owner then return end

    HideMapPinsMenu()

    local function ReanchorMenu()
        if Dropdown and Dropdown.frame and owner then
            Dropdown.frame:SetClampedToScreen(false)
            Dropdown.frame:ClearAllPoints()
            Dropdown.frame:SetPoint("TOPLEFT", owner, "TOPRIGHT", 4, 0)
        end
    end

    Dropdown:Show({
        owner = owner,
        tag = "mappins",
        anchorPoint = "TOPLEFT",
        anchorRelativePoint = "TOPRIGHT",
        anchorX = 4,
        anchorY = 0,
        clampToScreen = false,
        keepOpen = true,
        items = {
            { header = true, text = L["MAP_PINS_MENU_TITLE"] },
            {
                text = L["MAP_PINS_KNOWLEDGE"],
                icon = (PT.config.showMapKnowledge ~= false) and CHECKBOX_ON or CHECKBOX_OFF,
                iconSize = 14,
                onClick = function()
                    PT.config.showMapKnowledge = not (PT.config.showMapKnowledge ~= false)
                    QueueRefreshMapPins()
                    C_Timer.After(0.01, function()
                        HideMapPinsMenu()
                        C_Timer.After(0.01, function()
                            if PT.MapPinsButton and PT.MapPinsButton:IsShown() then
                                ShowMapPinsMenu(PT.MapPinsButton)
                            end
                        end)
                    end)
                end,
            },
            {
                text = L["MAP_PINS_LURES"],
                icon = (PT.config.showMapLures ~= false) and CHECKBOX_ON or CHECKBOX_OFF,
                iconSize = 14,
                onClick = function()
                    PT.config.showMapLures = not (PT.config.showMapLures ~= false)
                    QueueRefreshMapPins()
                    C_Timer.After(0.01, function()
                        HideMapPinsMenu()
                        C_Timer.After(0.01, function()
                            if PT.MapPinsButton and PT.MapPinsButton:IsShown() then
                                ShowMapPinsMenu(PT.MapPinsButton)
                            end
                        end)
                    end)
                end,
            },
            { header = true, text = " " },
        }
    })

    ReanchorMenu()

    C_Timer.After(0, function()
        if not Dropdown.frame or not Dropdown.frame:IsShown() then return end
        ReanchorMenu()
        ShowMapPinsSizeInput(owner)
    end)
end

local function CreateMapPinsButton()
    if PT.MapPinsButton then return end
    if not WorldMapFrame then return end

    local canvas = WorldMapFrame.GetCanvasContainer and WorldMapFrame:GetCanvasContainer() or WorldMapFrame
    local btn = CreateFrame("Button", nil, canvas)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("HIGH")
    btn:RegisterForClicks("LeftButtonUp")

    local function PositionBeneathOverlays()
        local count = 0
        local krowiLib = LibStub and LibStub("Krowi_WorldMapButtons-1.4", true)
        if krowiLib and krowiLib.Buttons then
            for _, f in ipairs(krowiLib.Buttons) do
                if f ~= btn then count = count + 1 end
            end
        else
            if WorldMapFrame.overlayFrames then
                for _, f in ipairs(WorldMapFrame.overlayFrames) do
                    if f ~= btn and f:IsShown()
                       and (
                           (WorldMapTrackingOptionsButtonMixin and f.OnLoad == WorldMapTrackingOptionsButtonMixin.OnLoad)
                           or (WorldMapTrackingPinButtonMixin and f.OnLoad == WorldMapTrackingPinButtonMixin.OnLoad)
                       )
                    then
                        count = count + 1
                    end
                end
            end
        end
        btn:ClearAllPoints()
        btn:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -4, -2 - count * 32)
    end
    btn.PositionBeneathOverlays = PositionBeneathOverlays
    PositionBeneathOverlays()

    if WorldMapFrame.HookScript then
        hooksecurefunc(WorldMapFrame, "RefreshOverlayFrames", function()
            PositionBeneathOverlays()
        end)
    end

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(25, 25)
    bg:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -4)
    btn.bg = bg

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(24, 24)
    btn.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 5, -4)
    btn.icon:SetTexture("Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\media\\logo.tga")

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    btn.border = border

    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    btn:SetScript("OnEnter", function(self)
        if not Tooltip then return end

        Tooltip:Clear()
        Tooltip:AddLine(L["MAP_PINS_TITLE"], 14, 1, 1, 1)
        Tooltip:AddLine(" ")
        Tooltip:AddLine(L["MAP_PINS_SETTINGS"], 12, 0.85, 0.85, 0.85)
        Tooltip:ShowAtCursor(16, 12)
    end)

    btn:SetScript("OnLeave", function()
        if Tooltip then
            Tooltip:Clear()
        end
    end)

    btn:SetScript("OnClick", function(self)
        if Tooltip then
            Tooltip:Clear()
        end
        ShowMapPinsMenu(self)
    end)

    if PT.config.enableMapPins == false then
        btn:Hide()
    end
    PT.MapPinsButton = btn
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("QUEST_LOG_UPDATE")
f:RegisterEvent("SKILL_LINES_CHANGED")
f:RegisterEvent("TRADE_SKILL_SHOW")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("ITEM_DATA_LOAD_RESULT")
f:RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")

f:SetScript("OnEvent", function(_, event, itemID, success)
    if event == "ITEM_DATA_LOAD_RESULT" then
        if success then
            QueueRefreshMapPins()
        end
        return
    end

    if event == "PLAYER_LOGIN"
    or event == "PLAYER_ENTERING_WORLD"
    or event == "QUEST_LOG_UPDATE"
    or event == "SKILL_LINES_CHANGED"
    or event == "TRADE_SKILL_SHOW"
    or event == "TRADE_SKILL_DATA_SOURCE_CHANGED"
    then
        MarkKnowledgeDirty()
    end

    if not WorldMapFrame then return end

    if PT.config.enableMapPins == false then
        if PT.SkinningWorldMapDataProvider then
            PT.SkinningWorldMapDataProvider:RemoveAllData()
        end

        if PT.MapPinsButton then
            PT.MapPinsButton:Hide()
        end

        HideMapPinsMenu()
        return
    end

    if not WorldMapFrame.dataProviders or not WorldMapFrame.dataProviders[PT.SkinningWorldMapDataProvider] then
        WorldMapFrame:AddDataProvider(PT.SkinningWorldMapDataProvider)
    end

    CreateMapPinsButton()
    QueueRefreshMapPins()
end)

if PT.RefreshUI then
    hooksecurefunc(PT, "RefreshUI", function()
        MarkKnowledgeDirty()
        QueueRefreshMapPins()
    end)
end

if Tracker then
    if Tracker.ToggleTrackedItem then
        hooksecurefunc(Tracker, "ToggleTrackedItem", function()
            MarkKnowledgeDirty()
            QueueRefreshMapPins()
        end)
    end

    if Tracker.SetTrackedItem then
        hooksecurefunc(Tracker, "SetTrackedItem", function()
            MarkKnowledgeDirty()
            QueueRefreshMapPins()
        end)
    end
end

if WorldMapFrame then
    WorldMapFrame:HookScript("OnShow", function()
        if PT.config.enableMapPins == false then
            if PT.MapPinsButton then
                PT.MapPinsButton:Hide()
            end
            return
        end

        CreateMapPinsButton()
        MarkKnowledgeDirty()
        QueueRefreshMapPins()
    end)

    WorldMapFrame:HookScript("OnHide", function()
        HideMapPinsMenu()
        if Tooltip then
            Tooltip:Clear()
        end
    end)
end

local function ShowDebugDump(text)
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB._mapDebugLog = text or ""
    print("|cff33ccffHironCraft:|r map debug saved to HironCraftProfit_DB._mapDebugLog. /reload or relog, then open WTF\\Account\\<account>\\SavedVariables\\HironCraftProfit.lua and find _mapDebugLog.")
end

SLASH_PHMAPPOS1 = "/phmappos"
SlashCmdList["PHMAPPOS"] = function()
    local viewedID = WorldMapFrame and WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
    if not viewedID then
        ShowDebugDump("Open the world map first.")
        return
    end

    local info = C_Map.GetMapInfo(viewedID)
    local lines = {}
    table.insert(lines, string.format("viewedID = %d (%s)",
        viewedID, tostring(info and info.name or "?")))
    table.insert(lines, string.format("parentMapID = %s, mapType = %s",
        tostring(info and info.parentMapID or "?"),
        tostring(info and info.mapType or "?")))
    table.insert(lines, "")

    RebuildKnowledgeCache()

    local maxRows = 12
    local shown = 0

    for _, src in ipairs(allKnowledgeEntries) do
        if shown >= maxRows then break end
        if src.mapID ~= viewedID then
            local a, b, c, d = C_Map.GetMapRectOnMap(src.mapID, viewedID)
            local name = (src.entry.GetName and src.entry:GetName()) or "?"
            table.insert(lines, string.format("entry[%s] map=%d xy=%.3f,%.3f",
                tostring(name):sub(1, 40), src.mapID, src.x, src.y))

            local function repr(v)
                if type(v) == "table" then
                    return string.format("{x=%s,y=%s}", tostring(v.x), tostring(v.y))
                end
                return tostring(v)
            end
            table.insert(lines, string.format("  rect = %s | %s | %s | %s",
                repr(a), repr(b), repr(c), repr(d)))

            local px, py = TranslateMapPos(src.mapID, viewedID, src.x, src.y)
            table.insert(lines, string.format("  translated = %s, %s",
                tostring(px), tostring(py)))
            table.insert(lines, "")
            shown = shown + 1
        end
    end
    if shown == 0 then
        table.insert(lines, "No cross-map entries to test from this view.")
    end

    ShowDebugDump(table.concat(lines, "\n"))
end

SLASH_PHADDWAYPOINT1 = "/phaddwaypoint"
SLASH_PHADDWAYPOINT2 = "/phwp"
SlashCmdList["PHADDWAYPOINT"] = function()
    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        print("|cff33ccffHironCraft:|r open the world map and hover the cursor over the target spot first.")
        return
    end

    local mapID = WorldMapFrame:GetMapID()
    if not mapID then
        print("|cff33ccffHironCraft:|r couldn't read current map ID.")
        return
    end

    local scrollContainer = WorldMapFrame.ScrollContainer
    if not scrollContainer or not scrollContainer.GetNormalizedCursorPosition then
        print("|cff33ccffHironCraft:|r cursor position API unavailable.")
        return
    end

    local cx, cy = scrollContainer:GetNormalizedCursorPosition()
    if not cx or not cy or cx < 0 or cx > 1 or cy < 0 or cy > 1 then
        print("|cff33ccffHironCraft:|r cursor is outside the map area.")
        return
    end

    local info = C_Map.GetMapInfo(mapID)
    local mapName = info and info.name or "?"
    local snippet = string.format("waypoint = { map = %d, x = %.4f, y = %.4f },",
        mapID, cx, cy)
    local snippetExtra = string.format("    { map = %d, x = %.4f, y = %.4f },",
        mapID, cx, cy)

    print(string.format("|cff33ccffHironCraft:|r %s (%d) at %.4f, %.4f",
        mapName, mapID, cx, cy))
    print(snippet)
    print("|cff999999  or for extraWaypoints:|r")
    print(snippetExtra)

    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB._lastCursorPos = {
        mapID = mapID,
        mapName = mapName,
        x = cx,
        y = cy,
        waypointLine = snippet,
        extraLine = snippetExtra,
        time = time(),
    }
end

