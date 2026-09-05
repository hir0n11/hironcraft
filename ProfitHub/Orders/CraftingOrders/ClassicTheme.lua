local E = _G.HironCraftProfitCraftingOrdersEnv
if not E or not E.CO then return end
setfenv(1, E)

-- A single, Blizzard-native presentation for the order workflow. The shell
-- sits outside the Orders page; it never resizes Blizzard's window or list.
CO.CLASSIC_PANEL_WIDTH = 244
CO.CLASSIC_PANEL_GAP = 8

function CO:ApplyClassicInset(frame, raised)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(raised and 0.65 or 0.35, raised and 0.58 or 0.32, raised and 0.48 or 0.28, 0.96)
    frame:SetBackdropBorderColor(0.65, 0.57, 0.43, 1)
end

function CO:StyleClassicButton(button, selected, unavailable)
    if not button then return end
    if button.hironClassicClose then return end
    button.hironClassic = true
    button:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-" .. ((selected or unavailable) and "Disabled" or "Up"))
    button:SetPushedTexture("Interface\\Buttons\\UI-Panel-Button-Down")
    button:SetDisabledTexture("Interface\\Buttons\\UI-Panel-Button-Disabled")
    button:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight", "ADD")
    for _, texture in ipairs({ button:GetNormalTexture(), button:GetPushedTexture(), button:GetDisabledTexture(), button:GetHighlightTexture() }) do
        texture:SetTexCoord(0, 0.625, 0, 0.6875)
    end
    if button.SetBackdropColor then button:SetBackdropColor(0, 0, 0, 0) end
    if button.SetBackdropBorderColor then button:SetBackdropBorderColor(0, 0, 0, 0) end
    if selected then button:LockHighlight() else button:UnlockHighlight() end
    local label = button.text or button.label
    if label then
        label:SetFontObject(GameFontNormalSmall)
        ApplyFont(label, 11, "")
        label:ClearAllPoints()
        label:SetPoint("CENTER", button, "CENTER", 0, 0)
        label:SetSize(math.max(1, button:GetWidth() - 8), button:GetHeight())
        label:SetJustifyH("CENTER")
        label:SetJustifyV("MIDDLE")
        label:SetTextColor(unavailable and 0.55 or 1, unavailable and 0.55 or 0.82, unavailable and 0.55 or 0.2)
    end
end

function CO:CreateClassicPanelShell(panel)
    self:ApplyClassicInset(panel, true)
    panel.footer = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    panel.footer:SetPoint("BOTTOMLEFT", 5, 5)
    panel.footer:SetPoint("BOTTOMRIGHT", -5, 5)
    panel.footer:SetHeight(140)
    self:ApplyClassicInset(panel.footer)

    -- Common actions stay outside both settings scroll pages.
    panel.queueActions = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    panel.queueActions:SetPoint("BOTTOMLEFT", panel.footer, "TOPLEFT", 0, 4)
    panel.queueActions:SetPoint("BOTTOMRIGHT", panel.footer, "TOPRIGHT", 0, 4)
    panel.queueActions:SetHeight(112)
    self:ApplyClassicInset(panel.queueActions)

    panel.classicPages = {}
    panel.classicTabs = {}
    for index, key in ipairs({ "craft", "queue" }) do
        local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 8, -66)
        scroll:SetPoint("BOTTOMRIGHT", panel.queueActions, "TOPRIGHT", -24, 5)
        local body = CreateFrame("Frame", nil, scroll)
        body:SetSize(self.CLASSIC_PANEL_WIDTH - 40, 1)
        scroll:SetScrollChild(body)
        scroll:HookScript("OnSizeChanged", function(self, width)
            body:SetWidth(math.max(1, width))
            CO:UpdateClassicSettingsScroll(self, body)
        end)
        local function updateScroll() CO:UpdateClassicSettingsScroll(scroll, body) end
        scroll:HookScript("OnShow", updateScroll)
        scroll:HookScript("OnScrollRangeChanged", updateScroll)
        body:HookScript("OnSizeChanged", updateScroll)
        panel.classicPages[key] = { scroll = scroll, body = body }
        local tab = self:CreateTextButton(panel, nil, 110, 24,
            index == 1 and T("COA_CLASSIC_CRAFT_TAB", "Crafting") or T("COA_CLASSIC_QUEUE_TAB", "Queue"))
        tab:SetPoint("TOPLEFT", 10 + (index - 1) * 114, -36)
        tab:SetScript("OnClick", function() CO:SelectClassicPanelTab(panel, key) end)
        panel.classicTabs[key] = tab
    end
    self:SelectClassicPanelTab(panel, "craft")
end

function CO:UpdateClassicSettingsScroll(scroll, body)
    local range = math.max(0, body:GetHeight() - scroll:GetHeight())
    local needed = range > 1
    if scroll.ScrollBar then scroll.ScrollBar:SetShown(needed) end
    scroll:EnableMouseWheel(needed)
    local offset = scroll:GetVerticalScroll()
    local clamped = needed and math.min(offset, range) or 0
    if clamped ~= offset then scroll:SetVerticalScroll(clamped) end
end

function CO:SelectClassicPanelTab(panel, key)
    panel.classicTab = key
    for name, page in pairs(panel.classicPages) do
        page.scroll:SetShown(name == key)
        self:StyleClassicButton(panel.classicTabs[name], name == key)
    end
end

-- Columns are shared by headers and rows. Hide secondary columns as space
-- narrows; item, reward, profit and action always remain within the viewport.
function CO:GetClassicOrderColumns(width, compact)
    width = math.max(320, tonumber(width) or 800)
    local columns = {}
    local cursor = width - 6
    local function right(key, size)
        cursor = cursor - size
        columns[key] = { x = cursor, w = size }
        cursor = cursor - 8
    end
    local narrow = width < 400
    right("action", narrow and 68 or 78)
    right("profit", narrow and 54 or (width >= 580 and 94 or 70))
    right("reward", narrow and 48 or 82)
    if width >= 480 then right("conc", 52) end
    if not compact and width >= 760 then right("cost", 74) end
    if compact and width >= 760 then right("reagents", 100) end
    local nameX = compact and 64 or 82
    columns.name = { x = nameX, w = math.max(40, cursor - nameX) }
    return columns
end

function CO:UpdateClassicPanelStatus(panel)
    panel = panel or self.controlPanel
    if not panel or not panel.statusText then return end
    panel.statusText:SetText(self.lastStatus or T("COA_CLASSIC_READY", "Select orders and press Action."))
end
