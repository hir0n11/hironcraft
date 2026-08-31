local PT = HironCraftProfit

PT.fonts = PT.fonts or {}

local function MigrateFontPaths(tbl, seen)
    if type(tbl) ~= "table" then return end
    seen = seen or {}
    if seen[tbl] then return end
    seen[tbl] = true
    for k, v in pairs(tbl) do
        if type(v) == "string" then
            if v:find("GothamXNarrow-Medium.ttf", 1, true) then
                tbl[k] = (v:gsub("GothamXNarrow%-Medium%.ttf", "default.ttf"))
            end
        elseif type(v) == "table" then
            MigrateFontPaths(v, seen)
        end
    end
end
PT.MigrateFontPaths = MigrateFontPaths

local function RunFontMigration()
    MigrateFontPaths(_G.HironCraftProfit_Config)
    MigrateFontPaths(_G.HironCraftProfit_CharConfig)
    MigrateFontPaths(_G.HironCraftProfit_DB)
    MigrateFontPaths(PT.config)
    MigrateFontPaths(PT.db)
end
RunFontMigration()

local fontMigFrame = CreateFrame("Frame")
fontMigFrame:RegisterEvent("PLAYER_LOGIN")
fontMigFrame:SetScript("OnEvent", function(self)
    RunFontMigration()
    self:UnregisterAllEvents()
end)

local function CreateFontObject(name, path, height, flags)
    local obj = CreateFont(name)
    obj:SetFont(path, height, flags)
    return obj
end

PT.fonts.normal = CreateFontObject("HironCraftProfit_Font_Normal", "Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\fonts\\default.ttf", 14, "")
PT.fonts.small  = CreateFontObject("HironCraftProfit_Font_Small",  "Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\fonts\\default.ttf", 12, "")
PT.fonts.title  = CreateFontObject("HironCraftProfit_Font_Title",  "Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\fonts\\default.ttf", 16, "OUTLINE")

local NEW_FONT_PATH = "Interface\\AddOns\\HironCraft\\ProfitHub\\Core\\fonts\\default.ttf"

local BLIZZ_FONT_DOUBLES = {
    "GameFontNormal", "GameFontNormalSmall", "GameFontNormalLarge", "GameFontNormalHuge",
    "GameFontHighlight", "GameFontHighlightSmall", "GameFontHighlightLarge",
    "GameFontDisable", "GameFontDisableSmall",
    "ChatFontNormal", "NumberFontNormalSmall",
}

PT.fontDoubles = PT.fontDoubles or {}
for _, blizzName in ipairs(BLIZZ_FONT_DOUBLES) do
    local src = _G[blizzName]
    if src and src.GetFont then
        local obj = CreateFont("HironCraftProfit_" .. blizzName)
        if obj.CopyFontObject then obj:CopyFontObject(src) end
        local _, height, flags = src:GetFont()
        obj:SetFont(NEW_FONT_PATH, height or 12, flags or "")
        PT.fontDoubles[blizzName] = obj
    end
end

function PT:StyleButton(btn, size)
    if not btn or not btn.GetFontString then return end
    local fs = btn:GetFontString()
    if fs and fs.SetFont then
        fs:SetFont(PT.FONT, size or 12, "")
    end
end

function PT:RestyleButtons(frame, size)
    if not frame then return end
    local function styleFS(fs)
        if not (fs and fs.GetFont and fs.SetFont) then return end
        local _, h, flags = fs:GetFont()
        fs:SetFont(PT.FONT, size or h or 12, flags or "")
    end
    local function walk(obj)
        if not obj then return end
        if obj.GetRegions then
            for _, r in ipairs({ obj:GetRegions() }) do
                if r.IsObjectType and r:IsObjectType("FontString") then styleFS(r) end
            end
        end
        if obj.IsObjectType then
            if obj:IsObjectType("EditBox") then styleFS(obj) end
            if obj:IsObjectType("Button") and obj.GetFontString then styleFS(obj:GetFontString()) end
        end
        if type(obj) == "table" then
            if obj.text then styleFS(obj.text) end
            if obj.Text then styleFS(obj.Text) end
        end
        if obj.GetChildren then
            for _, child in ipairs({ obj:GetChildren() }) do
                walk(child)
            end
        end
    end
    walk(frame)
end

local function IsOurPanel(frame)
    local n = frame and frame.GetName and frame:GetName()
    return n and (n:find("^HironCraftProfit") or n:find("^HironCraft")) and true or false
end

if Settings and hooksecurefunc then
    if Settings.RegisterCanvasLayoutSubcategory then
        hooksecurefunc(Settings, "RegisterCanvasLayoutSubcategory", function(_, frame)
            if IsOurPanel(frame) then PT:RestyleButtons(frame) end
        end)
    end
    if Settings.RegisterCanvasLayoutCategory then
        hooksecurefunc(Settings, "RegisterCanvasLayoutCategory", function(frame)
            if IsOurPanel(frame) then PT:RestyleButtons(frame) end
        end)
    end
end
