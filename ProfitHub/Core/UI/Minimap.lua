local PT = HironCraftProfit
local L = PT.L
local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

local broker = LDB:NewDataObject("HironCraftProfit", {
    type = "data source",
    text = "HironCraft",
    icon = "Interface\\AddOns\\HironCraft\\Media\\HironCraftIcon.tga",

OnClick = function(self, button)
    if button == "LeftButton" then
        if IsShiftKeyDown()
            and PT.FarmTracker
            and PT.FarmTracker.ToggleVisibility
            and (not HironCraftProfit_DB or not HironCraftProfit_DB.farmTracker or HironCraftProfit_DB.farmTracker.config == nil or HironCraftProfit_DB.farmTracker.config.minimapShiftOpen ~= false)
        then
            PT.FarmTracker:ToggleVisibility()
            return
        end

        if PT.Settings and PT.Settings.category then
            Settings.OpenToCategory(PT.Settings.category:GetID())
        end

    elseif button == "RightButton" then
        if IsShiftKeyDown() then
            if PT.DisEnchantSuper and PT.DisEnchantSuper.Toggle then
                PT.DisEnchantSuper:Toggle()
            end
        else
            if PT.AccountOverview then
                PT.AccountOverview:Toggle()
            end
        end
    end
end,

OnTooltipShow = function(tt)
    tt:AddLine(L["LDB_TITLE"])
    tt:AddLine(L["LDB_LEFT_CLICK"], 1, 1, 1)
    tt:AddLine(L["LDB_RIGHT_CLICK"], 1, 1, 1)
end,
})

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    HironCraftProfit_DB = HironCraftProfit_DB or {}
    HironCraftProfit_DB.minimap = HironCraftProfit_DB.minimap or { hide = false }

    LDBIcon:Register("HironCraftProfit", broker, HironCraftProfit_DB.minimap)
end)
