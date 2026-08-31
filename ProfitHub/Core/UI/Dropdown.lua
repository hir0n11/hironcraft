local PT = HironCraftProfit
if not PT then return end
local catcher
PT.Dropdown = {}
local D = PT.Dropdown

local FONT = HironCraftProfit.FONT
local CHECKED_ATLAS = "common-icon-checkmark"

function PT:CreateDropdownLikeButton(parent, width, height)
    width = width or 220

    D._ddCount = (D._ddCount or 0) + 1
    local dd = CreateFrame("Frame", "HironCraftProfitDropdownLike" .. D._ddCount, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dd, width)

    local overlay = CreateFrame("Button", nil, dd)
    overlay:SetAllPoints(dd)
    overlay:RegisterForClicks("LeftButtonUp")
    overlay:SetFrameLevel((dd:GetFrameLevel() or 0) + 5)
    dd.overlay = overlay

    if dd.Button then
        dd.Button:EnableMouse(false)
    end

    function dd:SetText(t)
        UIDropDownMenu_SetText(self, t or "")
    end

    function dd:GetText()
        if self.Text and self.Text.GetText then return self.Text:GetText() or "" end
        return ""
    end

    function dd:SetOnClick(fn)
        overlay:SetScript("OnClick", fn)
    end

    function dd:InitFilterMenu(getCurrent, onSelect)
        overlay:SetScript("OnClick", function()
            local cur = (getCurrent and getCurrent()) or ""
            local items = {}
            for _, opt in ipairs(dd.options or {}) do
                local value = opt.value
                items[#items + 1] = {
                    text = opt.label or tostring(value),
                    checked = tostring(value) == tostring(cur),
                    onClick = function()
                        if onSelect then onSelect(value) end
                    end,
                }
            end
            D:Show({ owner = dd, items = items })
        end)
    end

    function dd:InitMultiMenu(getItems)
        local function openMenu()
            local items = {}
            for _, it in ipairs((getItems and getItems()) or {}) do
                if it.header then
                    items[#items + 1] = { text = it.text, header = true }
                else
                    local cap = it
                    items[#items + 1] = {
                        text = cap.text,
                        checked = cap.checked and true or false,
                        onClick = function()
                            if cap.onClick then cap.onClick(not cap.checked) end
                            C_Timer.After(0, openMenu)
                        end,
                    }
                end
            end
            D:Show({ owner = dd, keepOpen = true, items = items })
        end
        overlay:SetScript("OnClick", openMenu)
    end

    function dd:SetEnabled(enabled)
        if enabled ~= false then
            overlay:Enable()
            if self.Text then self.Text:SetTextColor(1, 1, 1) end
        else
            overlay:Disable()
            if self.Text then self.Text:SetTextColor(0.5, 0.5, 0.5) end
        end
    end

    function dd:IsEnabled()
        return overlay:IsEnabled()
    end

    return dd
end


local function UpdateArrows(f)
    if not f.upArrow then return end
    local maxScroll = (f.scroll and f.scroll.maxScroll) or 0
    if maxScroll <= 0 then
        f.upArrow:Hide()
        f.downArrow:Hide()
        return
    end
    local cur = f.scroll:GetVerticalScroll()
    if cur > 1 then f.upArrow:Show() else f.upArrow:Hide() end
    if cur < maxScroll - 1 then f.downArrow:Show() else f.downArrow:Hide() end
end

local function CreateFrameOnce()
    if D.frame then return end

    local f = CreateFrame("Frame", "HironCraftProfitDropdown", UIParent, "BackdropTemplate")
    f:SetFrameStrata("TOOLTIP")
	f:SetFrameLevel(1001)
    f:SetClampedToScreen(true)
    f:Hide()

    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    f:SetBackdropColor(0, 0, 0, 0.95)
    f:SetBackdropBorderColor(0.694, 0.612, 0.851, 1)

    local scroll = CreateFrame("ScrollFrame", nil, f)
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", 0, 0)
    scroll:EnableMouseWheel(true)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = self.maxScroll or 0
        if maxScroll <= 0 then return end
        local cur = self:GetVerticalScroll()
        local step = 44
        local new = math.min(maxScroll, math.max(0, cur - delta * step))
        self:SetVerticalScroll(new)
        UpdateArrows(f)
    end)

    f.scroll = scroll
    f.content = content

    local arrowLayer = CreateFrame("Frame", nil, f)
    arrowLayer:SetAllPoints(f)
    arrowLayer:SetFrameLevel((f:GetFrameLevel() or 0) + 20)
    arrowLayer:EnableMouse(false)

    local upArrow = arrowLayer:CreateTexture(nil, "OVERLAY")
    upArrow:SetAtlas("uitools-icon-chevron-down")
    upArrow:SetRotation(math.pi)
    upArrow:SetSize(12, 12)
    upArrow:SetPoint("TOPRIGHT", -4, -3)
    upArrow:SetVertexColor(0.694, 0.612, 0.851)
    upArrow:Hide()
    f.upArrow = upArrow

    local downArrow = arrowLayer:CreateTexture(nil, "OVERLAY")
    downArrow:SetAtlas("uitools-icon-chevron-down")
    downArrow:SetSize(12, 12)
    downArrow:SetPoint("BOTTOMRIGHT", -4, 3)
    downArrow:SetVertexColor(0.694, 0.612, 0.851)
    downArrow:Hide()
    f.downArrow = downArrow

    f.items = {}
    D.frame = f

    if not catcher then
        catcher = CreateFrame("Frame", nil, UIParent)
        catcher:SetAllPoints(UIParent)
        catcher:SetFrameStrata("TOOLTIP")
        catcher:SetFrameLevel(1000)
        catcher:EnableMouse(true)
        catcher:Hide()

        catcher:SetScript("OnMouseDown", function()
            D:Hide()
        end)
    end
end

function D:Hide()
    if not self.frame then return end
self.frame:Hide()
if catcher then
    catcher:Hide()
end

end

local function ApplyDropdownFrameStyle(f)
    local fantasy = PT.IsFantasyDesign and PT:IsFantasyDesign()
    if fantasy then
        f:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 5, right = 5, top = 5, bottom = 5 },
        })
        f:SetBackdropColor(1, 1, 1, 1)
        f:SetBackdropBorderColor(1, 1, 1, 1)
        if f.upArrow then f.upArrow:SetVertexColor(1, 0.82, 0.35) end
        if f.downArrow then f.downArrow:SetVertexColor(1, 0.82, 0.35) end
    else
        f:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 2,
        })
        f:SetBackdropColor(0, 0, 0, 0.95)
        f:SetBackdropBorderColor(0.694, 0.612, 0.851, 1)
        if f.upArrow then f.upArrow:SetVertexColor(0.694, 0.612, 0.851) end
        if f.downArrow then f.downArrow:SetVertexColor(0.694, 0.612, 0.851) end
    end
    return fantasy
end

function D:Show(opts)
    CreateFrameOnce()

    local f = self.frame
	self.keepOpen = opts and opts.keepOpen

    local fantasy = ApplyDropdownFrameStyle(f)
    local pad = fantasy and 6 or 0
    f.scroll:ClearAllPoints()
    f.scroll:SetPoint("TOPLEFT", pad, -pad)
    f.scroll:SetPoint("BOTTOMRIGHT", -pad, pad)
    if f.upArrow then f.upArrow:SetPoint("TOPRIGHT", -(4 + pad), -(3 + pad)) end
    if f.downArrow then f.downArrow:SetPoint("BOTTOMRIGHT", -(4 + pad), 3 + pad) end

f:Show()
if catcher then
    catcher:Show()
end

    for _, row in ipairs(f.items) do
        row:Hide()
    end
    wipe(f.items)

    local maxTextWidth    = 0
    local maxAmountWidth  = 0
    local maxActionsWidth = 0

    if opts.items then
        for _, item in ipairs(opts.items) do
            if item.text then
                local fs = f:CreateFontString(nil, "OVERLAY")
                fs:SetFont(FONT, 12, "")
                fs:SetText(item.text)
                maxTextWidth = math.max(maxTextWidth, fs:GetStringWidth())
                fs:Hide()
            end

            if item.amount then
                local fs = f:CreateFontString(nil, "OVERLAY")
                fs:SetFont(FONT, 12, "")
                fs:SetText(item.amount)
                maxAmountWidth = math.max(maxAmountWidth, fs:GetStringWidth())
                fs:Hide()
            end

            if type(item.actionButtons) == "table" then
                maxActionsWidth = math.max(maxActionsWidth, #item.actionButtons * 18)
            end
        end
    end

    local width = 0
    local y = -8

    for _, item in ipairs(opts.items or {}) do
        local row = CreateFrame("Button", nil, f.content)
        row:SetHeight(20)
        row:SetPoint("TOPLEFT", 8, y)
        row:EnableMouse(true)

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(1, 1, 1, 0)

        row.hover = row:CreateTexture(nil, "HIGHLIGHT")
        row.hover:SetAllPoints()
        row.hover:SetColorTexture(1, 1, 1, 0.08)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("LEFT", 0, 0)

        if item.checked then
            if icon.SetAtlas then
                icon:SetAtlas(item.checkedAtlas or CHECKED_ATLAS, false)
            else
                icon:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            end

            icon:SetSize(16, 16)
            icon:SetVertexColor(0.35, 1, 0.35, 1)
            icon:Show()

        elseif item.atlas and icon.SetAtlas then
            icon:SetAtlas(item.atlas, false)
            icon:SetSize(16, 16)
            icon:SetVertexColor(1, 1, 1, 1)
            icon:Show()

        elseif item.icon then
            icon:SetSize(16, 16)
            icon:SetTexture(item.icon)
            icon:SetVertexColor(1, 1, 1, 1)
            icon:Show()

        else
            icon:SetTexture(nil)
            icon:Hide()
        end

        row.icon = icon
		
        local text = row:CreateFontString(nil, "OVERLAY")
        text:SetFont(FONT, 12, "")
        text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        text:SetWidth(maxTextWidth)
        text:SetJustifyH("LEFT")
        text:SetText(item.text or "")
        row.text = text

        if item.amount then
            local amount = row:CreateFontString(nil, "OVERLAY")
            amount:SetFont(FONT, 12, "")
            amount:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            amount:SetWidth(maxAmountWidth)
            amount:SetJustifyH("RIGHT")
            amount:SetText(item.amount)
            amount:SetTextColor(0.9, 0.9, 0.9)
            row.amount = amount
        end

        if item.header then
            row:EnableMouse(false)
            row.text:SetFont(FONT, 11, "")
            row.text:SetTextColor(1, 0.82, 0)
        else
            if item.checked then
                row.text:SetTextColor(1, 0.82, 0)
            end

			row:SetScript("OnClick", function()
				if item.onClick then item.onClick() end

				if not D.keepOpen then
					D:Hide()
				end
			end)
        end

        local w = 22 + maxTextWidth
        if row.amount then
            w = w + maxAmountWidth + 12
        end
        if maxActionsWidth > 0 then
            w = w + maxActionsWidth + 8
        end

        width = math.max(width, w)
        row:SetWidth(w)

        if row.amount and maxActionsWidth > 0 then
            row.amount:ClearAllPoints()
            row.amount:SetPoint("RIGHT", row, "RIGHT", -(maxActionsWidth + 10), 0)
        end

        if type(item.actionButtons) == "table" then
            local right = -2

            for i = #item.actionButtons, 1, -1 do
                local spec = item.actionButtons[i]
                local btn = CreateFrame("Button", nil, row)
                btn:SetSize(16, 16)
                btn:SetPoint("RIGHT", row, "RIGHT", right, 0)
                btn:EnableMouse(true)

                local visual

                if spec.atlas then
                    visual = btn:CreateTexture(nil, "OVERLAY")
                    visual:SetSize(12, 12)
                    visual:SetPoint("CENTER")
                    visual:SetAtlas(spec.atlas)
                    if spec.rotation then visual:SetRotation(spec.rotation) end
                elseif spec.icon then
                    visual = btn:CreateTexture(nil, "OVERLAY")
                    visual:SetSize(12, 12)
                    visual:SetPoint("CENTER")
                    visual:SetTexture(spec.icon)
                else
                    visual = btn:CreateFontString(nil, "OVERLAY")
                    visual:SetFont(FONT, 12, "OUTLINE")
                    visual:SetPoint("CENTER")
                    visual:SetText(spec.text or "")
                end

                if spec.disabled then
                    if visual.SetTextColor then
                        visual:SetTextColor(0.35, 0.35, 0.35)
                    else
                        visual:SetAlpha(0.25)
                    end
                else
                    if visual.SetTextColor then
                        visual:SetTextColor(1, 1, 1)
                    else
                        visual:SetAlpha(1)
                    end

                    btn:SetScript("OnClick", function()
                        if spec.onClick then
                            spec.onClick()
                        end

                        if not D.keepOpen then
                            D:Hide()
                        end
                    end)

                    if visual.SetVertexColor then
                        btn:SetScript("OnEnter", function() visual:SetVertexColor(1.3, 1.3, 1.3) end)
                        btn:SetScript("OnLeave", function()
                            visual:SetVertexColor(1, 1, 1)
                            visual:ClearAllPoints()
                            visual:SetPoint("CENTER")
                        end)
                        btn:HookScript("OnMouseDown", function()
                            visual:ClearAllPoints()
                            visual:SetPoint("CENTER", 1, -1)
                            visual:SetVertexColor(0.7, 0.7, 0.7)
                        end)
                        btn:HookScript("OnMouseUp", function(self)
                            visual:ClearAllPoints()
                            visual:SetPoint("CENTER")
                            local v = self:IsMouseOver() and 1.3 or 1
                            visual:SetVertexColor(v, v, v)
                        end)
                    end
                end

                right = right - 18
            end
        end

        table.insert(f.items, row)
        y = y - 22
    end

    local frameW = width + 16
    local contentH = -y + 8

    local visibleH = contentH
    if opts.maxHeight and contentH > opts.maxHeight then
        visibleH = opts.maxHeight
    end

    f.content:SetSize(frameW, contentH)
    f.scroll.maxScroll = math.max(0, contentH - visibleH)
    f.scroll:SetVerticalScroll(0)
    UpdateArrows(f)

    f:SetSize(frameW + pad * 2, visibleH + pad * 2)

    if opts.clampToScreen == false then
        f:SetClampedToScreen(false)
    else
        f:SetClampedToScreen(true)
    end

    f:ClearAllPoints()
    if opts.owner then
        local p = opts.anchorPoint or "TOPLEFT"
        local rp = opts.anchorRelativePoint or "BOTTOMLEFT"
        local x = opts.anchorX or 0
        local y = opts.anchorY or -4
        f:SetPoint(p, opts.owner, rp, x, y)
    else
        f:SetPoint("CENTER")
    end
end