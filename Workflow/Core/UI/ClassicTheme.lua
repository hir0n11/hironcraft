-- Shared, game-native chrome. Item rarity, class and warning colours are separate.
local PT = HironCraftProfit
local Theme = {}
PT.ClassicTheme = Theme

Theme.GOLD = { 1, 0.82, 0 }
Theme.BORDER = { 0.72, 0.65, 0.52, 1 }

function Theme:ApplyFrame(frame, inset)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(inset and 0.55 or 0.85, inset and 0.48 or 0.78, inset and 0.38 or 0.68, 1)
    frame:SetBackdropBorderColor(unpack(self.BORDER))
end

function Theme:ApplyTooltip(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.08, 0.08, 0.06, 1)
    frame:SetBackdropBorderColor(unpack(self.BORDER))
end

function Theme:ApplyHeader(frame)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    frame:SetBackdropColor(0.3, 0.24, 0.13, 0.7)
    local line = frame.classicRule or frame:CreateTexture(nil, "BORDER")
    frame.classicRule = line
    line:SetColorTexture(0.65, 0.54, 0.33, 0.6)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", 0, 0)
end

-- Legacy layout keys are retained for compatibility; the old skin is no longer selectable.
function PT:GetDesignStyle() return "classic" end
function PT:IsFantasyDesign() return true end
function PT:ApplyStyleLayout(frame, layouts)
    if not frame or not layouts then return end
    local layout = layouts.classic or layouts.fantasy or layouts.soulless
    if not layout then return end
    for key, c in pairs(layout) do
        local region = frame[key]
        if region then
            if c.w and c.h and region.SetSize then region:SetSize(c.w, c.h) end
            if (c.p or c.x or c.y or c.rel) and region.SetPoint then
                region:ClearAllPoints()
                region:SetPoint(c.p or "TOPRIGHT", (c.rel and frame[c.rel]) or frame,
                    c.rp or c.p or "TOPRIGHT", c.x or 0, c.y or 0)
            end
        end
    end
end

if PT.config then PT.config.designStyle = "classic" end
