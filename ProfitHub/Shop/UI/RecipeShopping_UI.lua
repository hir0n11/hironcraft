local PT = HironCraftProfit
local RS = PT and PT.RecipeShopping
if not RS then return end

local WIDTH, ROW_HEIGHT, MAX_ROWS = 360, 34, 5
local function T(key, fallback) return (PT.L and PT.L[key]) or fallback end

local function Label(parent, text, width, point, relative, relativePoint, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint(point, relative, relativePoint, x, y)
    label:SetWidth(width)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end

local function Button(parent, text, width, point, relative, relativePoint, x, y, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetPoint(point, relative, relativePoint, x, y)
    button:SetText(text)
    button:SetPushedTextOffset(0, 0)
    local label = button:GetFontString()
    label:ClearAllPoints()
    label:SetPoint("CENTER", button, "CENTER", 0, 0)
    button:SetScript("OnClick", onClick)
    return button
end

function RS:ShowQualityMenu(owner)
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner, function(_, root)
            root:CreateTitle(T("PG_RECIPE_PLAN_QUALITY", "New reagents"))
            for value = 1, 2 do
                local quality = value
                root:CreateRadio(RS:GetQualityLabel(quality),
                    function() return RS:GetSettings().quality == quality end,
                    function() RS:SetQuality(quality) end)
            end
        end)
    else
        self:SetQuality(self:GetSettings().quality == 1 and 2 or 1)
    end
end

local function SetQuantity(entry, quantity)
    if not entry then return end
    local ok, reason = RS:SetEntryQuantity(entry.id, quantity)
    if not ok then RS:NotifyPlanError(reason); RS:RefreshPlanWindow() end
end

local function EntryTooltip(row)
    local entry = row.entry
    if not entry or not GameTooltip then return end
    GameTooltip:SetOwner(row, "ANCHOR_LEFT")
    GameTooltip:SetText(entry.name, 1, 0.82, 0, 1, true)
    if entry.kind == "recipe_item" then
        GameTooltip:AddLine(T("PG_RECIPE_ITEM_TOOLTIP", "Buy the recipe-learning item."), 1, 1, 1, true)
    else
        GameTooltip:AddLine(T("PG_RECIPE_PLAN_PER_CRAFT", "Reagents per craft:"), 0.8, 0.8, 0.8)
        local ids = {}
        for itemID in pairs(entry.materials) do ids[#ids + 1] = itemID end
        table.sort(ids)
        for _, itemID in ipairs(ids) do
            local material = entry.materials[itemID]
            local tier = material.tier and (" T" .. material.tier) or ""
            GameTooltip:AddLine((material.label or ("#" .. itemID)) .. tier .. " x" .. material.quantity, 1, 1, 1)
        end
        GameTooltip:AddLine(T("PG_RECIPE_PLAN_EDIT_HINT", "Enter: apply quantity. Zero or X: remove this row."), 0.65, 0.85, 1, true)
    end
    GameTooltip:Show()
end

local function CreateRow(frame)
    local row = CreateFrame("Frame", nil, frame.content)
    row:SetSize(316, ROW_HEIGHT)
    row:EnableMouse(true)
    row:SetScript("OnEnter", EntryTooltip)
    row:SetScript("OnLeave", function(self)
        if GameTooltip and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
    end)
    row.name = Label(row, "", 166, "TOPLEFT", row, "TOPLEFT", 0, -2)
    row.name:SetWordWrap(false)
    row.detail = Label(row, "", 166, "TOPLEFT", row, "TOPLEFT", 0, -17)
    row.detail:SetTextColor(0.65, 0.65, 0.65)
    row.minus = Button(row, "-", 20, "LEFT", row, "LEFT", 168, 0,
        function() SetQuantity(row.entry, row.entry and row.entry.count - 1) end)
    local quantity = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    quantity:SetSize(38, 20)
    quantity:SetPoint("LEFT", row, "LEFT", 194, 0)
    quantity:SetAutoFocus(false)
    quantity:SetNumeric(true)
    quantity:SetMaxLetters(4)
    quantity:SetJustifyH("CENTER")
    local function Commit(self)
        if not self.dirty then return end
        self.dirty = false
        local text = self:GetText()
        local number = type(text) == "string" and text:match("^%d+$") and tonumber(text)
        if number then SetQuantity(row.entry, number) else
            RS:NotifyPlanError("bad_quantity")
            RS:RefreshPlanWindow()
        end
    end
    quantity:SetScript("OnTextChanged", function(self, userInput) if userInput then self.dirty = true end end)
    quantity:SetScript("OnEnterPressed", function(self) Commit(self); self:ClearFocus() end)
    quantity:SetScript("OnEditFocusLost", Commit)
    quantity:SetScript("OnEscapePressed", function(self)
        self.dirty = false
        self:SetNumber(row.entry and row.entry.count or 0)
        self:ClearFocus()
    end)
    row.quantity = quantity
    row.plus = Button(row, "+", 20, "LEFT", row, "LEFT", 236, 0,
        function() SetQuantity(row.entry, row.entry and row.entry.count + 1) end)
    row.remove = Button(row, "X", 24, "LEFT", row, "LEFT", 286, 0,
        function() SetQuantity(row.entry, 0) end)
    return row
end

function RS:EnsurePlanWindow()
    if self.planFrame then return self.planFrame end
    if not ProfessionsFrame then return nil end
    local frame = CreateFrame("Frame", "HironCraftRecipeShoppingPlan", ProfessionsFrame, "BackdropTemplate")
    frame:SetSize(WIDTH, 160)
    frame:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", 6, -66)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true,
        tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.06, 0.05, 0.04, 0.96)
    frame:SetBackdropBorderColor(0.65, 0.55, 0.35, 1)
    frame:Hide()
    local drag = CreateFrame("Frame", nil, frame)
    drag:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -4)
    drag:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -30, -4)
    drag:SetHeight(24)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() frame:StartMoving() end)
    drag:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    local title = Label(drag, T("PG_RECIPE_PLAN_TITLE", "Recipes in shopping"), WIDTH - 60,
        "CENTER", drag, "CENTER", 0, 0)
    title:SetJustifyH("CENTER")
    title:SetTextColor(1, 0.82, 0)
    frame.close = Button(frame, "X", 22, "TOPRIGHT", frame, "TOPRIGHT", -6, -5, function() frame:Hide() end)
    Label(frame, T("PG_RECIPE_PLAN_QUALITY", "New reagents"), 162, "TOPLEFT", frame, "TOPLEFT", 12, -38)
    frame.quality = Button(frame, "", 150, "TOPRIGHT", frame, "TOPRIGHT", -12, -32,
        function(self) RS:ShowQualityMenu(self) end)
    frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -64)
    frame.scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 42)
    frame.content = CreateFrame("Frame", nil, frame.scroll)
    frame.content:SetSize(316, ROW_HEIGHT)
    frame.scroll:SetScrollChild(frame.content)
    frame.empty = Label(frame, T("PG_RECIPE_PLAN_EMPTY", "Add a recipe with Add to shopping."), 300,
        "TOPLEFT", frame, "TOPLEFT", 18, -70)
    frame.empty:SetJustifyH("CENTER")
    frame.rows = {}
    frame.rowPool = {}
    frame.total = Label(frame, "", 210, "BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 15)
    frame.clear = Button(frame, T("PG_RECIPE_PLAN_CLEAR", "Clear"), 82,
        "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 10, function()
            local ok, reason = RS:ClearPlan()
            if not ok then RS:NotifyPlanError(reason) end
        end)
    self.planFrame = frame
    UISpecialFrames = UISpecialFrames or {}
    table.insert(UISpecialFrames, "HironCraftRecipeShoppingPlan")
    return frame
end

function RS:RefreshPlanWindow()
    local frame = self.planFrame
    if not frame then return end
    local entries = self:GetPlanEntries()
    local visible = math.max(1, math.min(MAX_ROWS, #entries))
    frame:SetHeight(106 + visible * ROW_HEIGHT)
    frame.content:SetHeight(math.max(1, #entries) * ROW_HEIGHT)
    frame.scroll:SetVerticalScroll(math.min(frame.scroll:GetVerticalScroll(), math.max(0, (#entries - visible) * ROW_HEIGHT)))
    frame.empty:SetShown(#entries == 0)
    frame.quality:SetText(self:GetQualityLabel(self:GetSettings().quality))
    frame.total:SetText(string.format(T("PG_RECIPE_PLAN_TOTAL", "Rows: %d"), #entries))
    local active = {}
    for index, entry in ipairs(entries) do
        local row = frame.rows[entry.id]
        if not row then row = table.remove(frame.rowPool) or CreateRow(frame); frame.rows[entry.id] = row end
        active[entry.id] = true
        row.entry = entry
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
        row.name:SetText(entry.name)
        row.detail:SetText(entry.kind == "recipe_item" and T("PG_RECIPE_PLAN_RECIPE_ITEM", "Recipe item") or self:GetQualityLabel(entry.quality))
        if not row.quantity.dirty then row.quantity:SetNumber(entry.count) end
        if entry.kind == "recipe_item" then row.quantity:Disable() else row.quantity:Enable() end
        row.minus:SetEnabled(entry.kind ~= "recipe_item")
        row.plus:SetEnabled(entry.kind ~= "recipe_item" and entry.count < 9999)
        row:Show()
    end
    for id, row in pairs(frame.rows) do
        if not active[id] then
            row.quantity.dirty = false
            row.entry = nil
            row.quantity:ClearFocus()
            row:Hide()
            frame.rows[id] = nil
            frame.rowPool[#frame.rowPool + 1] = row
        end
    end
end

function RS:ShowPlanWindow()
    local frame = self:EnsurePlanWindow()
    if not frame then return end
    self:RefreshPlanWindow()
    frame:Show()
end
