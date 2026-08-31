local PT = HironCraftProfit
if not PT then return end

local L = PT.L or {}
local UI = PT.Settings
if not UI then return end

PT.config = PT.config or {}

local panel = CreateFrame("Frame", "HironCraftProfitQuestShoppingSettingsPanel", UIParent)
panel:SetSize(700, 460)

local title = panel:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontHighlightLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText(L["Settings_QuestShopping"] or "Quest Shopping")

local cbEnable = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
cbEnable:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -14)
cbEnable.text:SetText(L["Settings_QuestShopping"] or "Quest Shopping")
cbEnable:SetChecked(PT.config.questShoppingEnabled == true)
cbEnable:SetScript("OnClick", function(self)
    PT.config.questShoppingEnabled = self:GetChecked() == true
    if PT.QuestShopping and PT.QuestShopping.ApplyEnabledState then
        PT.QuestShopping:ApplyEnabledState()
    end
end)

local desc = panel:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontDisable")
desc:SetPoint("TOPLEFT", cbEnable, "BOTTOMLEFT", 4, -8)
desc:SetWidth(560)
desc:SetJustifyH("LEFT")
desc:SetText(L["Settings_QuestShopping_Tooltip"] or "Darkmoon Faire quests show a cart automatically. For any other quest, Alt + left click it in the objective tracker to add a cart; Alt + right click the cart (or Remove below) to remove it.")

local listLabel = panel:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontNormal")
listLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", -4, -18)
listLabel:SetText(L["Settings_QuestShopping_SavedList"] or "Saved quests")

local listFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
listFrame:SetPoint("TOPLEFT", listLabel, "BOTTOMLEFT", 0, -4)
listFrame:SetSize(360, 220)
listFrame:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 2,
})
listFrame:SetBackdropColor(0, 0, 0, 0.6)
listFrame:SetBackdropBorderColor(0.694, 0.612, 0.851, 1)

local scroll = CreateFrame("ScrollFrame", nil, listFrame)
scroll:SetPoint("TOPLEFT", 4, -4)
scroll:SetPoint("BOTTOMRIGHT", -4, 4)
scroll:EnableMouseWheel(true)

local content = CreateFrame("Frame", nil, scroll)
content:SetSize(1, 1)
scroll:SetScrollChild(content)

local ROW_H = 24
scroll:SetScript("OnMouseWheel", function(self, delta)
    self:SetVerticalScroll(math.max(0, self:GetVerticalScroll() - delta * ROW_H))
end)

local emptyText = content:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontDisableSmall")
emptyText:SetPoint("TOPLEFT", 6, -8)
emptyText:SetText(L["Settings_QuestShopping_NoSaved"] or "No saved quests. Alt + left click a quest in the tracker to add one.")
emptyText:Hide()

local function RebuildList()
    local children = { content:GetChildren() }
    for _, ch in ipairs(children) do
        ch:Hide()
        ch:SetParent(nil)
    end

    local M = PT.QuestShopping
    if not M or not M.GetSavedQuestIDs then
        emptyText:Show()
        content:SetHeight(1)
        return
    end

    local ids = M:GetSavedQuestIDs()
    if #ids == 0 then
        emptyText:Show()
        content:SetHeight(1)
        return
    end

    emptyText:Hide()

    local y = -2
    for _, questID in ipairs(ids) do
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(348, ROW_H)
        row:SetPoint("TOPLEFT", 0, y)
        row:EnableMouse(true)

        local hover = row:CreateTexture(nil, "BACKGROUND")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0)

        local titleText = (M.GetSavedQuestTitle and M:GetSavedQuestTitle(questID))
            or (M.GetQuestTitle and M:GetQuestTitle(questID))
            or ("#" .. tostring(questID))

        local lbl = row:CreateFontString(nil, "OVERLAY", "HironCraftProfit_GameFontNormal")
        lbl:SetPoint("LEFT", 6, 0)
        lbl:SetPoint("RIGHT", row, "RIGHT", -88, 0)
        lbl:SetJustifyH("LEFT")
        lbl:SetWordWrap(false)
        lbl:SetText(titleText)

        local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        removeBtn:SetSize(78, 20)
        removeBtn:SetPoint("RIGHT", -4, 0)
        removeBtn:SetText(L["Settings_QuestShopping_Remove"] or "Remove")
        if PT.StyleButton then PT:StyleButton(removeBtn) end
        removeBtn:SetScript("OnClick", function()
            if M.UnsaveQuest then
                M:UnsaveQuest(questID)
            end
            RebuildList()
        end)

        row:SetScript("OnEnter", function()
            hover:SetColorTexture(1, 1, 1, 0.10)
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:SetText(titleText, 1, 1, 1)
            GameTooltip:AddLine("questID: " .. tostring(questID), 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function()
            hover:SetColorTexture(1, 1, 1, 0)
            GameTooltip:Hide()
        end)

        y = y - ROW_H
    end

    content:SetHeight(math.max(1, -y + 4))
end

local clearBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
clearBtn:SetSize(360, 24)
clearBtn:SetPoint("TOPLEFT", listFrame, "BOTTOMLEFT", 0, -8)
clearBtn:SetText(L["Settings_QuestShopping_ClearSaved"] or "Remove all saved quests")
clearBtn:SetScript("OnClick", function()
    if PT.QuestShopping and PT.QuestShopping.ClearSavedQuests then
        PT.QuestShopping:ClearSavedQuests()
    end
    RebuildList()
end)

local restoreBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
restoreBtn:SetSize(360, 24)
restoreBtn:SetPoint("TOPLEFT", clearBtn, "BOTTOMLEFT", 0, -6)
restoreBtn:SetText(L["Settings_QuestShopping_RestoreHidden"] or "Restore hidden Faire carts")
restoreBtn:SetScript("OnClick", function()
    if PT.QuestShopping and PT.QuestShopping.ClearBlacklist then
        PT.QuestShopping:ClearBlacklist()
    end
    RebuildList()
end)

local function RefreshUI()
    cbEnable:SetChecked(PT.config.questShoppingEnabled == true)
    RebuildList()
end

function UI:RefreshQuestShoppingSubcategory()
    RefreshUI()
end

function UI:RegisterQuestShoppingSubcategory()
    if self.questShoppingSubcategory then return end
    if not self.category then return end

    local sub = Settings.RegisterCanvasLayoutSubcategory(
        self.category,
        panel,
        L["Settings_QuestShopping"] or "Quest Shopping"
    )

    if sub and sub.SetOnRefresh then
        sub:SetOnRefresh(RefreshUI)
    elseif sub then
        sub.OnRefresh = RefreshUI
    end

    self.questShoppingSubcategory = sub
    RefreshUI()

    if PT.RestyleButtons then PT:RestyleButtons(panel) end
end
