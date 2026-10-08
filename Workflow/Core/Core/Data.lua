local PT = HironCraftProfit
PT.tradeSkillReady = false

HironCraftProfit_CharConfig = HironCraftProfit_CharConfig or {}
HironCraftProfit_CharConfig.activeDB = HironCraftProfit_CharConfig.activeDB or "MID"

PT.config = PT.config or {}
PT.config.activeDB = HironCraftProfit_CharConfig.activeDB

PT.DB = PT.DB or {}
PT.DB.DF  = PT.DB.DF  or {}
PT.DB.TWW = PT.DB.TWW or {}
PT.DB.MID = PT.DB.MID or {}

local function ImportDB(globalName, target)
    local g = _G[globalName]
    if g and type(g) == "table" then
        for k,v in pairs(g) do
            target[k] = v
        end
    end
end

function PT.LoadActiveDB()
    local key = HironCraftProfit_CharConfig.activeDB or "MID"

    PT.db = PT.DB[key] or {}
    PT.professions = nil

    HironCraftProfit_CharConfig.activeDB = key
    PT.config.activeDB = key

    return PT.db
end

PT.GetProfessionsByDB = {}

local function IsAdminShowAllProfessionsEnabled()
    return PT.adminShowAllProfessions or PT.config.showAllProfessions
end

local function PlayerHasSkillLine(skillLineID)
    local prof1, prof2, arch, fish, cook = GetProfessions()

    for _, profIndex in ipairs({ prof1, prof2, arch, fish, cook }) do
        if profIndex then
            local _, _, _, _, _, _, skillLine = GetProfessionInfo(profIndex)
            if skillLine == skillLineID then
                return true
            end
        end
    end

    return false
end

local function PlayerKnowsProfessionSpell(spellID)
    if not spellID then
        return false
    end

    if IsPlayerSpell and IsPlayerSpell(spellID) then
        return true
    end

    if C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spellID) then
        return true
    end

    return false
end

PT.GetProfessionsByDB.DF = function(db, refresh)
    local result = {}
    local showAll = IsAdminShowAllProfessionsEnabled()

    for id, prof in pairs(db or {}) do
        if type(prof) == "table" then
            if showAll or PlayerKnowsProfessionSpell(prof.spellId) then
                result[id] = prof
            else
                local skillInfo = prof:GetSkillLevel()
                if skillInfo and skillInfo.skillLevel > 0 then
                    result[id] = prof
                end
            end
        end
    end

    return result
end

PT.GetProfessionsByDB.TWW = function(db, refresh)
    local result = {}
    local showAll = IsAdminShowAllProfessionsEnabled()

    for id, prof in pairs(db or {}) do
        if type(prof) == "table" then
            if showAll or PlayerKnowsProfessionSpell(prof.spellId) then
                result[id] = prof
            end
        end
    end

    return result
end

PT.GetProfessionsByDB.MID = function(db, refresh)
    local result = {}
    local showAll = IsAdminShowAllProfessionsEnabled()

    for id, prof in pairs(db or {}) do
        if type(prof) == "table" then
            if showAll or PlayerHasSkillLine(prof.skillLine or prof.id) then
                result[id] = prof
            end
        end
    end

    return result
end

function PT.GetProfessions(refresh)
    local dbKey = PT.config.activeDB or "MID"
    local db    = PT.db or {}
    local fn    = PT.GetProfessionsByDB[dbKey]

    if not fn then
        return {}
    end

    local showAll = PT.adminShowAllProfessions or PT.config.showAllProfessions

    local result = fn(db, refresh)

    PT.professions = result

    for _, prof in pairs(result) do
        if prof.RefreshInfo then
            prof:RefreshInfo()
        end
    end

    return result
end

local f = CreateFrame("Frame")

local function SafeRegisterEvent(frame, event)
    if not frame or not event then return end
    pcall(frame.RegisterEvent, frame, event)
end

SafeRegisterEvent(f, "TRADE_SKILL_LIST_UPDATE")
SafeRegisterEvent(f, "SKILL_LINES_CHANGED")
SafeRegisterEvent(f, "SPELLS_CHANGED")
SafeRegisterEvent(f, "LEARNED_SPELL_IN_SKILL_LINE")
SafeRegisterEvent(f, "PLAYER_ENTERING_WORLD")

f:SetScript("OnEvent", function(_, event)
    PT.tradeSkillReady = true
    PT.UpdateAllProfessionNames()
    PT:RefreshData()
    PT:RefreshUI()

    if C_Timer then
        C_Timer.After(0.5, function()
            if PT.UpdateAllProfessionNames then
                PT.UpdateAllProfessionNames()
            end
            if PT.RefreshData then
                PT:RefreshData()
            end
            if PT.RefreshUI then
                PT:RefreshUI()
            end
        end)
    end
end)
