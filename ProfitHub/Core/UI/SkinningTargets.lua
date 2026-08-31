local PT = HironCraftProfit
if not PT or not PT.SkinningCheck then return end

local SC = PT.SkinningCheck
local UI = {}
local L = PT.L
PT.UI_SkinningTargets = UI

local FONT = HironCraftProfit.FONT

local function GetSkinningDisabledDB()
    PT.config.skinningDisabledTargets =
        PT.config.skinningDisabledTargets or {}
    return PT.config.skinningDisabledTargets
end

local function SyncSkinningTargets()
    if PT.UI_SkinningCheck then
        PT.UI_SkinningCheck:Update()
    end

    if PT.AccountOverview_Data
       and PT.AccountOverview_Data.SaveCurrentCharacterSkinningSnapshot
    then
        PT.AccountOverview_Data:SaveCurrentCharacterSkinningSnapshot()
    end

    if PT.AccountOverview and PT.AccountOverview.Refresh then
        PT.AccountOverview:Refresh()
    end
end

function UI:Create()
    if self.frame then return self.frame end

    local f = CreateFrame("Frame", "HironCraftProfitSkinningTargetsFrame", UIParent, "BackdropTemplate")
    f:SetSize(360, 300)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 3,
    })
    f:SetBackdropColor(0, 0, 0, 0.95)
    f:SetBackdropBorderColor(0.694, 0.612, 0.851, 1)
    f:Hide()

    if HironCraftProfit.RegisterEscClose then HironCraftProfit:RegisterEscClose(f) end

    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetFont(FONT, 14, "OUTLINE")
    title:SetPoint("TOP", 0, -10)
    title:SetText(L["SKINNING_TARGETS_TITLE"])
    f.title = title

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -36)
    scroll:SetPoint("BOTTOMRIGHT", -30, 12)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    f.content = content
    self.frame = f

    self:Build()

    return f
end

function UI:Build()
    if not self.frame or not self.frame.content then
        return
    end

    local content = self.frame.content
    local disabledDB = GetSkinningDisabledDB()

    if content.rows then
        for _, row in ipairs(content.rows) do
            row:Hide()
            row:SetParent(nil)
        end
    end
    content.rows = {}

    local y = 0
    local rowWidth = 300

    for _, target in ipairs(SC.TARGETS) do
        if SC:IsTargetAvailable(target) then
            local row = CreateFrame("Frame", nil, content)
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetSize(rowWidth, 24)

            local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            cb:SetPoint("LEFT", 0, 0)
            cb:SetSize(24, 24)

            local enabled = not disabledDB[target.id]
            cb:SetChecked(enabled)

            local text = row:CreateFontString(nil, "OVERLAY")
            text:SetFont(FONT, 12, "")
            text:SetPoint("LEFT", cb, "RIGHT", 6, 0)
            text:SetJustifyH("LEFT")
            text:SetWidth(rowWidth - 30)
            text:SetText(SC:GetTargetName(target))

            cb:SetScript("OnClick", function(self)
                disabledDB[target.id] = not self:GetChecked()

                SyncSkinningTargets()
                UI:Build()
            end)

            table.insert(content.rows, row)
            y = y + 24
        end
    end

    content:SetHeight(math.max(y, 1))
end

function UI:Toggle()
    local f = self:Create()

    if f:IsShown() then
        f:Hide()
    else
        self:Build()
        f:Show()
    end
end