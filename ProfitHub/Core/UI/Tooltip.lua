local PT = HironCraftProfit
if not PT then return end

PT.Tooltip = PT.Tooltip or {}
local T = PT.Tooltip

T.MIN_WIDTH = 60
T.MAX_WIDTH = 360
T.PADDING_X = 16

local FONT = HironCraftProfit.FONT

local f = CreateFrame("Frame", "HironCraftProfitTooltip", UIParent, "BackdropTemplate")
f:SetFrameStrata("TOOLTIP")
f:SetFrameLevel(9999)
f:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
})
f:SetBackdropColor(0, 0, 0, 0.95)
f:SetBackdropBorderColor(0.694, 0.612, 0.851, 1)
f:Hide()

f.lines = {}
f.icons = {}
T.frame = f

function T:Clear()
    f:SetScript("OnUpdate", nil)

    for _, fs in ipairs(f.lines) do
        fs:Hide()
        fs:SetParent(nil)
    end
    wipe(f.lines)

    for _, tex in ipairs(f.icons) do
        if tex then
            tex:Hide()
            tex:SetParent(nil)
        end
    end
    wipe(f.icons)

    f:Hide()
end

function T:AddLine(text, size, r, g, b)
    local fs = f:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, size or 13, "")
    fs:SetTextColor(r or 1, g or 1, b or 1)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetWordWrap(true)
    fs:SetWidth(1)
    fs:SetText(text)

    table.insert(f.lines, fs)
    return fs
end

local function CalculateAutoWidth()
    local maxW = 0

    for _, fs in ipairs(f.lines) do
        fs:SetWordWrap(false)
        fs:SetWidth(0)
        local w = fs:GetStringWidth()
        if w and w > maxW then
            maxW = w
        end
    end

    maxW = maxW + T.PADDING_X
    maxW = math.max(T.MIN_WIDTH, math.min(T.MAX_WIDTH, maxW))

    return math.floor(maxW + 0.5)
end

local function Layout(width)
    for _, fs in ipairs(f.lines) do
        fs:SetWordWrap(true)
        fs:SetWidth(width - T.PADDING_X)
    end

    local height = 8
    local prev

    for i, fs in ipairs(f.lines) do
        fs:ClearAllPoints()
        if i == 1 then
            fs:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8)
        else
            fs:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -4)
        end
        height = height + fs:GetStringHeight() + 4
        prev = fs
    end

    height = height + 8
    return height
end

function T:ShowAt(owner, point, offsetX, offsetY)
    local width = CalculateAutoWidth()
    local height = Layout(width)

    f:SetSize(width, height)
    f:ClearAllPoints()

    offsetX = offsetX or 0
    offsetY = offsetY or 0
    point = point or "TOP"

    f:SetPoint(point, owner, point, offsetX, offsetY)
    f:Show()
end

function T:ShowSmart(owner, offset)
    if not owner then return end
    offset = offset or 8

    local width  = CalculateAutoWidth()
    local height = Layout(width)

    f:SetSize(width, height)
    f:ClearAllPoints()

    local screenW = UIParent:GetWidth()
    local screenH = UIParent:GetHeight()

    local l = owner:GetLeft()
    local r = owner:GetRight()
    local t = owner:GetTop()
    local b = owner:GetBottom()

    if not l or not r or not t or not b then
        f:SetPoint("TOP", owner, "BOTTOM", 0, -offset)
        f:Show()
        return
    end

    local spaceRight = screenW - r
    local spaceLeft  = l
    local spaceAbove = screenH - t
    local spaceBelow = b

    local placeRight = (spaceRight >= width + offset) or (spaceRight >= spaceLeft)

    local placeAbove
    if spaceAbove >= height + offset then
        placeAbove = true
    elseif spaceBelow >= height + offset then
        placeAbove = false
    else
        placeAbove = (spaceAbove >= spaceBelow)
    end

    local x
    if placeRight then
        x = r + offset
    else
        x = l - width - offset
    end

    local y
    if placeAbove then
        y = t + offset
    else
        y = b - height - offset
    end

    if x < 0 then x = 0 end
    if y < 0 then y = 0 end
    if x + width > screenW then x = screenW - width end
    if y + height > screenH then y = screenH - height end

    f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
    f:Show()
end

function T:ShowAtCursor(offsetX, offsetY)
    offsetX = offsetX or 16
    offsetY = offsetY or 16

    local width = CalculateAutoWidth()
    local height = Layout(width)

    f:SetSize(width, height)
    f:Show()

    f:SetScript("OnUpdate", function(self)
        local cx, cy = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()

        local x = cx / scale + offsetX
        local y = cy / scale + offsetY

        local screenW = UIParent:GetWidth()
        local screenH = UIParent:GetHeight()

        if x + width > screenW then
            x = x - width - 24
        end

        if y + height > screenH then
            y = y - height - 24
        end

        self:ClearAllPoints()
        self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
    end)
end

local function ClampTooltipCursorPoint(x, y, width, height)
    local screenW = UIParent:GetWidth() or 0
    local screenH = UIParent:GetHeight() or 0

    if x < 0 then x = 0 end
    if y < 0 then y = 0 end
    if x + width > screenW then x = math.max(0, screenW - width) end
    if y + height > screenH then y = math.max(0, screenH - height) end

    return x, y
end

local function GetCursorRightOrBelowPoint(width, height, offsetX, offsetY)
    offsetX = offsetX or 12
    offsetY = offsetY or 10

    local cx, cy = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale() or 1

    cx = cx / scale
    cy = cy / scale

    local screenW = UIParent:GetWidth() or 0
    local screenH = UIParent:GetHeight() or 0

    local x = cx + offsetX
    local y = cy

    if x + width > screenW or y + height > screenH then
        x = cx + offsetX
        y = cy - height - offsetY
    end

    return ClampTooltipCursorPoint(x, y, width, height)
end

function T:PositionFrameCursorRightOrBelow(frame, offsetX, offsetY)
    if not frame then return end

    local width = frame:GetWidth() or 0
    local height = frame:GetHeight() or 0

    if width <= 0 then width = (frame.GetStringWidth and frame:GetStringWidth()) or 220 end
    if height <= 0 then height = (frame.GetStringHeight and frame:GetStringHeight()) or 40 end

    local x, y = GetCursorRightOrBelowPoint(width, height, offsetX or 12, offsetY or 10)

    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
end

function T:ShowGameTooltipCursorRightOrBelow(offsetX, offsetY)
    if not GameTooltip then return end

    GameTooltip:Show()
    self:PositionFrameCursorRightOrBelow(GameTooltip, offsetX or 12, offsetY or 10)
end

function T:ShowCursorRightOrBelow(offsetX, offsetY)
    offsetX = offsetX or 12
    offsetY = offsetY or 10

    local width = CalculateAutoWidth()
    local height = Layout(width)

    f:SetSize(width, height)

    local function Position(self)
        local x, y = GetCursorRightOrBelowPoint(width, height, offsetX, offsetY)

        self:ClearAllPoints()
        self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
    end

    Position(f)
    f:SetScript("OnUpdate", Position)
    f:Show()
end

function T:AddIcon(size)
    local tex = f:CreateTexture(nil, "OVERLAY")
    tex:SetSize(size or 12, size or 12)
    table.insert(f.icons, tex)
    return tex
end