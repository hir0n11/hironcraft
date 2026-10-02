-- GetPersonalOrdersInfo is the server's current-character count, not scanner
-- guesses or a cache of other crafters' orders.
local _, Scan = ...
local I = {}
Scan.PersonalOrdersIndicator = I
local frame, buttons, previous = nil, {}, nil
local function SettingsDB()
    return Scan.DB and Scan.DB.settings
end
local function L(text) return Scan.LOCAL:GetText(text) end
local function Original()
    return MinimapCluster and MinimapCluster.IndicatorFrame and MinimapCluster.IndicatorFrame.CraftingOrderFrame
end
function I.Enabled()
    local db = SettingsDB()
    return db and db.personal_order_icons ~= false
end
function I.Reset()
    local db = SettingsDB()
    if db then db.personal_order_position = nil end
    I.Position()
end
function I.Position()
    if not frame then return end
    local db = SettingsDB() or {}
    frame:ClearAllPoints()
    frame:SetScale(tonumber(db.personal_order_scale) or 1)
    local pos = db.personal_order_position
    local indicators = MinimapCluster and MinimapCluster.IndicatorFrame
    local mail = indicators and indicators.MailFrame
    if mail and not mail.hironOrderSpacingHook then
        mail.hironOrderSpacingHook = true
        mail:HookScript('OnShow', I.Position)
        mail:HookScript('OnHide', I.Position)
    end
    -- The mail atlas is wider than its 20px layout slot. Putting this group
    -- in the next slot overlaps the actual envelope, especially when scaled.
    -- Follow the stock area but anchor outside the mail texture's real edge.
    frame.layoutIndex = nil
    frame.ignoreInLayout = true
    if pos and tonumber(pos.x) and tonumber(pos.y) then
        frame:SetParent(UIParent)
        frame:SetPoint('CENTER', UIParent, 'BOTTOMLEFT', pos.x, pos.y)
    else
        -- Use Blizzard's indicator group (tracking/mail/crafting orders).
        -- It follows Edit Mode and tracking-button changes automatically.
        frame:SetParent(indicators or UIParent)
        if mail and mail:IsShown() then
            frame:SetPoint('TOPLEFT', mail.MailIcon or MiniMapMailIcon or mail, 'TOPRIGHT', 8, 0)
        elseif indicators then
            frame:SetPoint('TOPLEFT', indicators, 'TOPLEFT', 0, 0)
        else
            frame:SetPoint('TOPRIGHT', Minimap, 'TOPLEFT', -3, 0)
        end
    end
    if indicators and indicators.Layout then indicators:Layout() end
end
local function MakeFrame()
    if frame then return end
    frame = CreateFrame('Frame', 'HironCraftPersonalOrderIndicators', UIParent)
    frame:SetSize(52, 24)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata('MEDIUM')
    I.Position()
end
local function Icon(name)
    if not GetProfessions or not GetProfessionInfo then return end
    for _, index in pairs({ GetProfessions() }) do
        local professionName, icon = GetProfessionInfo(index)
        if professionName == name then return icon end
    end
end
function I.Update(silent)
    if not C_CraftingOrders or not C_CraftingOrders.GetPersonalOrdersInfo then return end
    local ok, infos = pcall(C_CraftingOrders.GetPersonalOrdersInfo)
    if not ok or type(infos) ~= 'table' then return end
    local counts, rows, increased = {}, {}, false
    for _, info in ipairs(infos) do
        local count = tonumber(info.numPersonalOrders) or 0
        local key = info.profession
        if key and count > 0 then
            counts[key] = count
            rows[#rows + 1] = info
            if previous and count > (previous[key] or 0) then increased = true end
        end
    end
    previous = counts
    if increased and not silent and Scan.Notifications then Scan.Notifications.Alert('order') end
    local original = Original()
    if original and not original.hironIndicatorHook then
        original.hironIndicatorHook = true
        original:HookScript('OnShow', function(self) if I.Enabled() then self:Hide() end end)
    end
    if not I.Enabled() then
        if frame then frame:Hide() end
        if original then original:SetShown(#rows > 0) end
        local indicators = MinimapCluster and MinimapCluster.IndicatorFrame
        if indicators and indicators.Layout then indicators:Layout() end
        return
    end
    if original then original:Hide() end
    MakeFrame()
    table.sort(rows, function(a, b) return a.profession < b.profession end)
    local offset = 0
    for index, info in ipairs(rows) do
        local button = buttons[index]
        if not button then
            button = CreateFrame('Button', nil, frame)
            buttons[index] = button
            button:SetSize(52, 24)
            button.icon = button:CreateTexture(nil, 'ARTWORK')
            button.icon:SetSize(24, 24)
            button.icon:SetPoint('LEFT', button, 'LEFT', 0, 0)
            button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            button.count = button:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
            button.count:SetPoint('LEFT', button.icon, 'RIGHT', 4, 0)
            button:RegisterForDrag('LeftButton')
            button:SetScript('OnDragStart', function() if IsShiftKeyDown() then frame:StartMoving() end end)
            button:SetScript('OnDragStop', function()
                frame:StopMovingOrSizing()
                local x, y = frame:GetCenter()
                local db = SettingsDB()
                if x and db then
                    db.personal_order_position = { x = x, y = y }
                    I.Position()
                end
            end)
            button:SetScript('OnEnter', function(self)
                GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
                GameTooltip:SetText(self.info.professionName)
                GameTooltip:AddLine(L('Personal orders') .. ': ' .. self.info.numPersonalOrders, 1, 1, 1)
                GameTooltip:AddLine(L('Shift-drag to move. Scale and reset are in Settings.'), 0.7, 0.7, 0.7, true)
                GameTooltip:Show()
            end)
            button:SetScript('OnLeave', function() GameTooltip:Hide() end)
        end
        button.info = info
        button.icon:SetTexture(Icon(info.professionName) or 134400)
        button.count:SetText(info.numPersonalOrders)
        local countWidth = button.count:GetStringWidth()
        button:SetWidth(28 + math.max(12, countWidth))
        button:ClearAllPoints()
        button:SetPoint('LEFT', frame, 'LEFT', offset, 0)
        offset = offset + button:GetWidth() + 8
        button:Show()
    end
    for index = #rows + 1, #buttons do buttons[index]:Hide() end
    frame:SetWidth(math.max(40, offset - 8))
    frame:SetShown(#rows > 0)
    local indicators = MinimapCluster and MinimapCluster.IndicatorFrame
    if indicators and indicators.Layout then indicators:Layout() end
end
local events = CreateFrame('Frame')
for _, event in ipairs({ 'PLAYER_ENTERING_WORLD', 'SKILL_LINES_CHANGED',
    'CRAFTINGORDERS_UPDATE_PERSONAL_ORDER_COUNTS' }) do events:RegisterEvent(event) end
events:SetScript('OnEvent', function(_, event)
    if event == 'PLAYER_ENTERING_WORLD' then previous = nil end
    I.Update(event == 'PLAYER_ENTERING_WORLD')
end)
