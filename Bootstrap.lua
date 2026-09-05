local addonName = ...

HironCraftProfit = HironCraftProfit or {}
HironCraft = HironCraftProfit

HironCraft.addonName = addonName
HironCraft.version = "0.3.3"
HironCraft.migration = HironCraft.migration or {
    imported = {},
}

local function DeepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    if seen[value] then
        return seen[value]
    end

    local copy = {}
    seen[value] = copy
    for key, child in pairs(value) do
        copy[DeepCopy(key, seen)] = DeepCopy(child, seen)
    end
    return copy
end

local migrations = {
    {
        sourceName = "CraftScan_DB",
        targetName = "HironCraftScan_DB",
        label = "CraftScan",
    },
    {
        sourceName = "AhUI_DB",
        targetName = "HironCraftProfit_DB",
        label = "ProfitHUB account data",
    },
    {
        sourceName = "AhUI_Config",
        targetName = "HironCraftProfit_Config",
        label = "ProfitHUB UI settings",
    },
    {
        sourceName = "AhUI_PriceDB",
        targetName = "HironCraftProfit_PriceDB",
        label = "ProfitHUB prices",
    },
    {
        sourceName = "AhUI_CharConfig",
        targetName = "HironCraftProfit_CharConfig",
        label = "ProfitHUB character settings",
    },
}

local function ImportLegacyData(force)
    local imported = {}

    for _, migration in ipairs(migrations) do
        local source = _G[migration.sourceName]
        local target = _G[migration.targetName]
        local targetIsEmpty = type(target) ~= "table" or next(target) == nil

        if type(source) == "table" and (force or targetIsEmpty) then
            _G[migration.targetName] = DeepCopy(source)
            table.insert(imported, migration.label)
        elseif type(target) ~= "table" then
            _G[migration.targetName] = {}
        end
    end

    HironCraft.migration.imported = imported
    HironCraft.migration.didImport = #imported > 0
    HironCraft.migration.needsReload = force and #imported > 0
    return imported
end

HironCraft.ImportLegacyData = ImportLegacyData
ImportLegacyData(false)

local function PrintMigrationResult(imported, forced)
    if #imported == 0 then
        print("|cffffd200HironCraft:|r старые данные не найдены или уже были перенесены.")
        return
    end

    print("|cff45ff78HironCraft:|r перенесены настройки: " .. table.concat(imported, ", ") .. ".")
    if forced then
        print("|cffffd200HironCraft:|r выполните /reload, чтобы применить импорт.")
    else
        print("|cffffd200HironCraft:|r после проверки отключите оригинальные CraftScan и ProfitHUB-модули.")
    end
end

SLASH_HIRONCRAFTMIGRATE1 = "/hcmigrate"
SlashCmdList.HIRONCRAFTMIGRATE = function(message)
    local command = tostring(message or ""):lower():match("^%s*(.-)%s*$")
    if command == "force" then
        PrintMigrationResult(ImportLegacyData(true), true)
        return
    end

    print("|cffffd200HironCraft:|r /hcmigrate force — повторно импортировать данные из включенных CraftScan/ProfitHUB.")
end

if HironCraft.migration.didImport then
    local login = CreateFrame("Frame")
    login:RegisterEvent("PLAYER_LOGIN")
    login:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        C_Timer.After(1, function()
            PrintMigrationResult(HironCraft.migration.imported, false)
        end)
    end)
end
