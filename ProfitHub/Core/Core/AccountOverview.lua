local PT = HironCraftProfit
if not PT then return end

PT.AccountOverview = PT.AccountOverview or {}
local M = PT.AccountOverview

function M:Show()
    if PT.AccountOverview_UI and PT.AccountOverview_UI.Show then
        PT.AccountOverview_UI:Show()
    end
end

function M:Hide()
    if PT.AccountOverview_UI and PT.AccountOverview_UI.Hide then
        PT.AccountOverview_UI:Hide()
    end
end

function M:Toggle()
    if PT.AccountOverview_UI and PT.AccountOverview_UI.Toggle then
        PT.AccountOverview_UI:Toggle()
    end
end

function M:Refresh()
    if PT.AccountOverview_UI
       and PT.AccountOverview_UI.frame
       and PT.AccountOverview_UI.frame:IsShown()
       and PT.AccountOverview_UI.Refresh
    then
        PT.AccountOverview_UI:Refresh()
    end
end