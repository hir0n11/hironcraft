local HironCraftScan = select(2, ...)

local function L(id)
    return HironCraftScan.LOCAL:GetText(id)
end

local Capture = {}
HironCraftScan.ChatTextCapture = Capture

local function Trim(text)
    if type(text) ~= 'string' then return '' end
    return text:match('^%s*(.-)%s*$') or ''
end

local function LinkLabel(linkText)
    return (linkText:gsub('^%[(.*)%]$', '%1'))
end

-- Filters are plain comma-separated phrases. Chat hyperlinks, textures and
-- colors must not be copied into them: item links become their visible names.
function Capture.NormalizeFilterText(text)
    if type(text) ~= 'string' then return '' end
    text = text:gsub('|H.-|h(.-)|h', LinkLabel)
    text = text:gsub('|c%x%x%x%x%x%x%x%x', '')
    text = text:gsub('|cn[%w_]+:', '')
    text = text:gsub('|r', '')
    text = text:gsub('|A.-|a', '')
    text = text:gsub('|T.-|t', '')
    text = text:gsub('[,\r\n]+', ' ')
    text = text:gsub('%s+', ' ')
    return Trim(text)
end

function Capture.DefaultLabel(text)
    local words = {}
    local length = 0
    for word in Capture.NormalizeFilterText(text):gmatch('%S+') do
        if #words >= 5 then break end
        local nextLength = length + #word + (#words > 0 and 1 or 0)
        if #words > 0 and nextLength > 60 then break end
        words[#words + 1] = word
        length = nextLength
    end
    return table.concat(words, ' ')
end

local function RefreshVisibleFilter(setting)
    local panel = _G.HironCraftScanGeneralConfigPanel
    local matching = panel and panel.Matching
    local field = matching and (setting == 'inclusions' and matching.Keywords or matching.Exclusions)
    local editBox = field and field.Expression and field.Expression.EditBox
    if editBox and (not editBox.HasFocus or not editBox:HasFocus()) then
        editBox:SetText(HironCraftScan.DB.settings[setting] or '')
    end
end

function Capture.SaveExplanation(label, text)
    label = Trim(label)
    text = Trim(text)
    if label == '' then return false, 'missing_label' end
    if text == '' then return false, 'missing_text' end
    if label == 'rev' then return false, 'reserved_label' end

    local explanations = HironCraftScan.Utils.saved(HironCraftScan.DB.settings, 'explanations', {})
    if explanations[label] ~= nil then return false, 'duplicate_label' end
    explanations[label] = text
    HironCraftScanComm:ShareCustomExplanations(explanations)
    return true
end

function Capture.SaveFilter(setting, text)
    if setting ~= 'inclusions' and setting ~= 'exclusions' then
        return false, 'invalid_setting'
    end
    local value = Capture.NormalizeFilterText(text)
    if value == '' then return false, 'missing_text' end

    local current = HironCraftScan.DB.settings[setting] or ''
    local wanted = string.lower(value)
    for entry in current:gmatch('([^,]+)') do
        if string.lower(Trim(entry)) == wanted then
            return false, 'duplicate_filter'
        end
    end

    HironCraftScan.DB.settings[setting] = current == '' and value or current .. ', ' .. value
    RefreshVisibleFilter(setting)
    HironCraftScan.Scanner.LoadConfig()
    return true
end

function Capture.ConfigureMessageScrollFrame(scrollFrame)
    -- InputScrollFrameTemplate otherwise treats the unlimited value as a
    -- zero-character limit and renders a large negative counter in the corner.
    scrollFrame.maxLetters = 0
    scrollFrame.hideCharCount = true
    scrollFrame.scrollBarHideIfUnscrollable = true
    scrollFrame.scrollBarHideTrackIfThumbExceedsTrack = true
    scrollFrame.scrollBarX = -10
    scrollFrame.scrollBarTopY = 2
    scrollFrame.scrollBarBottomY = -2
    if scrollFrame.CharCount then scrollFrame.CharCount:Hide() end
end

local function SetStatus(frame, reason)
    local messages = {
        missing_label = L('Enter a response name.'),
        missing_text = L('The edited message is empty.'),
        reserved_label = L("'rev' is a reserved response name."),
        duplicate_label = L('A prepared response with this name already exists.'),
        duplicate_filter = L('This phrase is already in the selected list.'),
    }
    frame.Status:SetText(messages[reason] or L('The text could not be saved.'))
end

local function CreateEditor()
    local frame = CreateFrame(
        'Frame',
        'HironCraftScanChatTextCaptureFrame',
        UIParent,
        'DefaultPanelFlatTemplate'
    )
    frame:SetSize(570, 300)
    frame:SetFrameStrata('DIALOG')
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetTitle(L('Save chat text'))
    HironCraftScan.Frames.makeMovable(frame)

    local close = CreateFrame('Button', nil, frame, 'UIPanelCloseButton')
    close:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', 2, 2)
    close:SetScript('OnClick', function() frame:Hide() end)

    local help = frame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
    help:SetPoint('TOPLEFT', frame, 'TOPLEFT', 24, -38)
    help:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -24, -38)
    help:SetJustifyH('LEFT')
    help:SetText(L('Edit the message, then choose where to save it. Nothing is sent.'))

    local labelCaption = frame:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
    labelCaption:SetPoint('TOPLEFT', help, 'BOTTOMLEFT', 0, -12)
    labelCaption:SetText(L('Prepared response name'))

    frame.Label = CreateFrame('EditBox', nil, frame, 'InputBoxTemplate')
    frame.Label:SetAutoFocus(false)
    frame.Label:SetPoint('TOPLEFT', labelCaption, 'BOTTOMLEFT', 4, -4)
    frame.Label:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -28, 0)
    frame.Label:SetHeight(22)
    frame.Label:SetScript('OnEscapePressed', function(self) self:ClearFocus(); frame:Hide() end)

    local messageCaption = frame:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
    messageCaption:SetPoint('TOPLEFT', frame.Label, 'BOTTOMLEFT', -4, -10)
    messageCaption:SetText(L('Message text'))

    frame.Message = CreateFrame('ScrollFrame', nil, frame, 'InputScrollFrameTemplate')
    frame.Message:SetPoint('TOPLEFT', messageCaption, 'BOTTOMLEFT', 0, -4)
    frame.Message:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -24, 73)
    local editBox = frame.Message.EditBox
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject('ChatFontNormal')
    editBox:SetPoint('TOPLEFT', frame.Message, 'TOPLEFT', 0, 0)
    editBox:SetWidth(500)
    editBox:SetMaxLetters(0)
    if editBox.SetHyperlinksEnabled then editBox:SetHyperlinksEnabled(true) end
    Capture.ConfigureMessageScrollFrame(frame.Message)
    InputScrollFrame_OnLoad(frame.Message)
    Capture.ConfigureMessageScrollFrame(frame.Message)
    editBox:SetScript('OnTextChanged', InputScrollFrame_OnTextChanged)
    editBox:SetScript('OnEscapePressed', function(self) self:ClearFocus(); frame:Hide() end)

    frame.Status = frame:CreateFontString(nil, 'ARTWORK', 'GameFontRedSmall')
    frame.Status:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 24, 54)
    frame.Status:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -24, 54)
    frame.Status:SetJustifyH('LEFT')

    local function AddButton(text, width, relative, offset, callback)
        local button = CreateFrame('Button', nil, frame, 'UIPanelButtonTemplate')
        button:SetSize(width, 22)
        if relative then
            button:SetPoint('LEFT', relative, 'RIGHT', offset, 0)
        else
            button:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 24, 20)
        end
        button:SetText(text)
        button:SetScript('OnClick', callback)
        return button
    end

    frame.ExplanationButton = AddButton(L('Prepared response'), 170, nil, 0, function()
        local ok, reason = Capture.SaveExplanation(frame.Label:GetText(), editBox:GetText())
        if ok then frame:Hide() else SetStatus(frame, reason) end
    end)
    frame.InclusionButton = AddButton(L('Scan keyword'), 150, frame.ExplanationButton, 8, function()
        local ok, reason = Capture.SaveFilter('inclusions', editBox:GetText())
        if ok then frame:Hide() else SetStatus(frame, reason) end
    end)
    frame.ExclusionButton = AddButton(L('Exclusion'), 150, frame.InclusionButton, 8, function()
        local ok, reason = Capture.SaveFilter('exclusions', editBox:GetText())
        if ok then frame:Hide() else SetStatus(frame, reason) end
    end)

    frame:SetScript('OnHide', function()
        frame.Label:ClearFocus()
        editBox:ClearFocus()
        frame.Status:SetText('')
    end)
    if UISpecialFrames then table.insert(UISpecialFrames, frame:GetName()) end
    frame:Hide()
    return frame
end

function Capture.Show(text)
    if (issecretvalue and issecretvalue(text)) or type(text) ~= 'string' or text == '' then
        return false
    end
    local frame = _G.HironCraftScanChatTextCaptureFrame or CreateEditor()
    frame.Label:SetText(Capture.DefaultLabel(text))
    frame.Message.EditBox:SetText(text)
    frame.Status:SetText('')
    frame:ClearAllPoints()
    frame:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
    frame:Show()
    frame.Message.EditBox:SetFocus()
    frame.Message.EditBox:HighlightText(0, -1)
    return true
end

function Capture.ShowForLine(lineID)
    if issecretvalue and issecretvalue(lineID) then return false end
    if type(lineID) == 'string' then
        lineID = lineID:match('^%d+$') and tonumber(lineID) or nil
    end
    if type(lineID) ~= 'number' or lineID <= 0 then return false end
    if not C_ChatInfo or not C_ChatInfo.GetChatLineText then return false end
    local ok, text = pcall(C_ChatInfo.GetChatLineText, lineID)
    if not ok then return false end
    return Capture.Show(text)
end
