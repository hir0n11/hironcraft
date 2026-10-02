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

-- The picker is only for matching keys. Display links as their readable names
-- so Blizzard's hyperlink mouse handling cannot interfere with text selection.
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

local function AppendPhrase(current, text)
    local value = Capture.NormalizeFilterText(text)
    if value == '' then return nil, 'missing_text' end

    current = current or ''
    local wanted = value:lower()
    for entry in current:gmatch('([^,]+)') do
        if Trim(entry):lower() == wanted then
            return nil, 'duplicate_filter'
        end
    end
    return current == '' and value or current .. ', ' .. value
end

local GLOBAL_FILTER_FIELDS = {
    inclusions = 'Keywords', exclusions = 'Exclusions', generic_request_keywords = 'GenericRequests',
}

local function RefreshVisibleGlobalFilter(setting)
    local panel = _G.HironCraftScanGeneralConfigPanel
    local matching = panel and panel.Matching
    local field = matching and matching[GLOBAL_FILTER_FIELDS[setting]]
    local editBox = field and field.Expression and field.Expression.EditBox
    if editBox and (not editBox.HasFocus or not editBox:HasFocus()) then
        editBox:SetText(HironCraftScan.DB.settings[setting] or '')
    end
end

function Capture.SaveGlobalKeyword(text)
    local updated, reason = AppendPhrase(HironCraftScan.DB.settings.inclusions, text)
    if not updated then return false, reason end
    HironCraftScan.DB.settings.inclusions = updated
    RefreshVisibleGlobalFilter('inclusions')
    HironCraftScan.Scanner.LoadConfig()
    return true
end

-- "LF crafter"-like phrases: a request that names no profession yet.
function Capture.SaveGenericKeyword(text)
    local settings = HironCraftScan.DB.settings
    local current = settings.generic_request_keywords
    if current == nil then current = L(HironCraftScan.CONST.TEXT.GENERIC_REQUEST_KEYWORDS_DEFAULT) end
    local updated, reason = AppendPhrase(current, text)
    if not updated then return false, reason end
    settings.generic_request_keywords = updated
    RefreshVisibleGlobalFilter('generic_request_keywords')
    HironCraftScan.Scanner.LoadConfig()
    return true
end

function Capture.SaveProfessionKeyword(char, parentProfessionID, text)
    local charConfig = HironCraftScan.DB.characters[char]
    local ppConfig = charConfig and charConfig.parent_professions[parentProfessionID]
    if not ppConfig then return false, 'invalid_profession' end

    local current = ppConfig.keywords
    if current == nil then
        local defaultID = HironCraftScan.CONST.PROFESSION_DEFAULT_KEYWORDS[parentProfessionID]
        current = defaultID and L(defaultID) or ''
    end
    local updated, reason = AppendPhrase(current, text)
    if not updated then return false, reason end

    ppConfig.keywords = updated
    if HironCraftScanComm and HironCraftScanComm.ShareCharacterModification then
        local ppChangeOnly = true
        HironCraftScanComm:ShareCharacterModification(char, parentProfessionID, ppChangeOnly)
    end
    HironCraftScan.Scanner.LoadConfig()
    return true
end

function Capture.SaveQuickReplyKeyword(templateKey, text)
    local value = Capture.NormalizeFilterText(text)
    if value == '' then return false, 'missing_text' end
    if not HironCraftScan.QuickReplies or not HironCraftScan.QuickReplies.AddKeyword then
        return false, 'quick_replies_unavailable'
    end
    return HironCraftScan.QuickReplies:AddKeyword(templateKey, value)
end

-- A key for the chat filter: messages with it are hidden from the chat.
function Capture.SaveFilterKey(text, whole)
    if not HironCraftScan.ChatFilter then return false, 'filter_unavailable' end
    local ok, reason = HironCraftScan.ChatFilter.AddKey(text, whole)
    if ok then return true end
    return false, reason
end

function Capture.ConfigureMessageScrollFrame(scrollFrame)
    scrollFrame.maxLetters = 0
    scrollFrame.hideCharCount = true
    scrollFrame.scrollBarHideIfUnscrollable = true
    scrollFrame.scrollBarHideTrackIfThumbExceedsTrack = true
    scrollFrame.scrollBarX = -10
    scrollFrame.scrollBarTopY = 2
    scrollFrame.scrollBarBottomY = -2
    if scrollFrame.CharCount then scrollFrame.CharCount:Hide() end
end

-- SimpleEditBoxAPI exposes HighlightText and Insert, but no selection getter.
-- Insert replaces the current selection, so use a unique marker to discover
-- its exact byte range, then immediately restore both the text and highlight.
function Capture.ExtractSelectedText(editBox)
    local original = editBox:GetText()
    if type(original) ~= 'string' or original == '' then return nil end

    local marker = '__HIRONCRAFT_SELECTED_TEXT__'
    while original:find(marker, 1, true) do marker = marker .. '_' end
    editBox:Insert(marker)
    local changed = editBox:GetText()
    local markerStart = type(changed) == 'string' and changed:find(marker, 1, true)
    if not markerStart then
        editBox:SetText(original)
        return nil
    end

    local prefixLength = markerStart - 1
    local suffixLength = #changed - (prefixLength + #marker)
    local selectionEnd = #original - suffixLength
    editBox:SetText(original)
    editBox:SetCursorPosition(selectionEnd)
    editBox:HighlightText(prefixLength, selectionEnd)
    if selectionEnd <= prefixLength then return nil end
    return original:sub(prefixLength + 1, selectionEnd)
end

-- The word around a cursor position, as byte offsets for HighlightText.
-- Letters, digits and apostrophes (Farstrider's) belong to a word; every
-- byte of a multibyte character counts as a letter, so Cyrillic words are
-- whole and a character is never cut in half.
local function IsWordByte(byte)
    return byte ~= nil and (byte >= 128 or (byte >= 48 and byte <= 57)
        or (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122)
        or byte == 39 or byte == 95)
end

function Capture.WordBoundsAt(text, cursor)
    if type(text) ~= 'string' or text == '' or type(cursor) ~= 'number' then return nil end
    cursor = math.max(0, math.min(#text, math.floor(cursor)))
    -- The cursor sits between two bytes; take the word on either side.
    local index = cursor + 1
    if not IsWordByte(text:byte(index)) then
        if IsWordByte(text:byte(cursor)) then index = cursor else return nil end
    end
    local first, last = index, index
    while first > 1 and IsWordByte(text:byte(first - 1)) do first = first - 1 end
    while last < #text and IsWordByte(text:byte(last + 1)) do last = last + 1 end
    -- A word ends on a letter, not on a quote: "'omw'" selects omw.
    while first < last and text:byte(first) == 39 do first = first + 1 end
    while last > first and text:byte(last) == 39 do last = last - 1 end
    if text:byte(first) == 39 then return nil end
    return first - 1, last
end

-- Double click selects a word, a third click the whole message, as in most
-- editors; Shift+click then stretches the selection to the clicked word, for
-- a phrase of several words. The game's edit boxes only select by dragging.
local MULTI_CLICK_SECONDS = 0.4

function Capture.HandleMultiClick(editBox, now, shift)
    local previous = editBox.hironCraftLastClick
    local cursor = editBox:GetCursorPosition()
    local text = editBox:GetText()
    local first, last

    local anchor = editBox.hironCraftAnchor
    if shift and anchor then
        local wordFirst, wordLast = Capture.WordBoundsAt(text, cursor)
        wordFirst, wordLast = wordFirst or cursor, wordLast or cursor
        first, last = math.min(anchor.first, wordFirst), math.max(anchor.last, wordLast)
        editBox.hironCraftLastClick = nil
    else
        local count = 1
        if previous and now - previous.at <= MULTI_CLICK_SECONDS
            and math.abs(cursor - previous.cursor) <= 1 then
            count = previous.count + 1
        end
        editBox.hironCraftLastClick = { at = now, cursor = cursor, count = count }
        if count == 2 then
            first, last = Capture.WordBoundsAt(text, cursor)
        elseif count >= 3 then
            first, last = 0, type(text) == 'string' and #text or 0
        end
        editBox.hironCraftAnchor = first and { first = first, last = last } or nil
    end
    if not first then return nil end
    local function Apply()
        editBox:SetCursorPosition(last)
        editBox:HighlightText(first, last)
    end
    Apply()
    -- The game may still settle the click after this handler; apply again.
    if C_Timer and C_Timer.After then C_Timer.After(0, Apply) end
    return first, last
end

-- Double click and drag: the selection grows word by word from the word
-- clicked, as in most editors. The press that makes the double click starts
-- it; while the button is held the game moves the cursor with the mouse, and
-- the selection follows it to whole words.
function Capture.BeginWordDrag(editBox, now)
    local previous = editBox.hironCraftLastClick
    if not previous or previous.count ~= 1 or now - previous.at > MULTI_CLICK_SECONDS then return false end
    local first, last = Capture.WordBoundsAt(editBox:GetText(), previous.cursor)
    if not first then return false end
    editBox.hironCraftDrag = { first = first, last = last, from = first, to = last }
    return true
end

function Capture.UpdateWordDrag(editBox)
    local drag = editBox.hironCraftDrag
    if not drag then return nil end
    local cursor = editBox:GetCursorPosition()
    local wordFirst, wordLast = Capture.WordBoundsAt(editBox:GetText(), cursor)
    wordFirst, wordLast = wordFirst or cursor, wordLast or cursor
    drag.from, drag.to = math.min(drag.first, wordFirst), math.max(drag.last, wordLast)
    editBox:HighlightText(drag.from, drag.to)
    return drag.from, drag.to
end

-- The button is let go: a drag over more than the word keeps what it
-- selected (Shift+click stretches it further); true when it did.
function Capture.FinishWordDrag(editBox)
    if not editBox.hironCraftDrag then return false end
    Capture.UpdateWordDrag(editBox)
    local drag = editBox.hironCraftDrag
    editBox.hironCraftDrag = nil
    if drag.from == drag.first and drag.to == drag.last then return false end
    local first, last = drag.from, drag.to
    editBox.hironCraftLastClick = nil
    editBox.hironCraftAnchor = { first = first, last = last }
    local function Apply()
        editBox:SetCursorPosition(last)
        editBox:HighlightText(first, last)
    end
    Apply()
    if C_Timer and C_Timer.After then C_Timer.After(0, Apply) end
    return true
end

local function SetStatus(frame, ok, reason)
    local errors = {
        missing_text = L('Select a word or phrase first.'),
        duplicate_filter = L('This keyword is already present.'),
        invalid_profession = L('This profession is no longer available.'),
        invalid_quick_reply = L('This quick response is no longer available.'),
        quick_replies_unavailable = L('Quick responses are not available.'),
        filter_unavailable = L('The chat filter is not available.'),
    }
    if ok then
        frame.Status:SetTextColor(0.2, 1, 0.2)
        frame.Status:SetText(L('Keyword added.'))
    else
        frame.Status:SetTextColor(1, 0.2, 0.2)
        frame.Status:SetText(errors[reason] or L('The keyword could not be added.'))
    end
end

local function ProfessionLabel(char, parentProfessionID)
    local name = HironCraftScan.ColorizeCrafterName(char)
    local professionName = HironCraftScan.Utils.ProfessionNameByID(parentProfessionID)
    local profession = HironCraftScan.Utils.ColorizeProfessionName(parentProfessionID, professionName)
    return name .. ' - ' .. profession
end

function Capture.PopulateSelectionMenu(rootDescription, frame, selectedText)
    selectedText = Capture.NormalizeFilterText(selectedText)
    if selectedText == '' then
        SetStatus(frame, false, 'missing_text')
        return false
    end

    rootDescription:CreateTitle(string.format(L('Selected: %s'), selectedText))

    local existing = rootDescription:CreateButton(L('Add to existing quick response'))
    local quickReplies = HironCraftScan.QuickReplies
    if quickReplies then
        for _, definition in ipairs(quickReplies:GetDefinitions()) do
            if not definition.eventOnly then
                local key = definition.key
                existing:CreateButton(quickReplies:GetTemplateLabel(key), function()
                    SetStatus(frame, Capture.SaveQuickReplyKeyword(key, selectedText))
                end)
            end
        end
    end

    rootDescription:CreateButton(L('Add to global scanning'), function()
        SetStatus(frame, Capture.SaveGlobalKeyword(selectedText))
    end)

    rootDescription:CreateButton(L('Add to generic craft requests'), function()
        SetStatus(frame, Capture.SaveGenericKeyword(selectedText))
    end)

    local professions = rootDescription:CreateButton(L('Add to profession scanning'))
    for _, crafterInfo in ipairs(HironCraftScan:GetSortedCrafters()) do
        local char = crafterInfo.name
        local parentProfessionID = crafterInfo.parentProfessionID
        professions:CreateButton(ProfessionLabel(char, parentProfessionID), function()
            SetStatus(frame, Capture.SaveProfessionKeyword(char, parentProfessionID, selectedText))
        end)
    end

    local hide = rootDescription:CreateButton(L('Hide in chat'))
    local anywhere = hide:CreateButton(L('Messages with this phrase'), function()
        SetStatus(frame, Capture.SaveFilterKey(selectedText, false))
    end)
    local whole = hide:CreateButton(L('Messages with this as whole words'), function()
        SetStatus(frame, Capture.SaveFilterKey(selectedText, true))
    end)
    for _, entry in ipairs({ { anywhere, 'Hide anywhere tooltip' }, { whole, 'Hide whole words tooltip' } }) do
        if entry[1] and entry[1].SetTooltip then
            entry[1]:SetTooltip(function(tooltip)
                GameTooltip_AddNormalLine(tooltip, L(entry[2]))
            end)
        end
    end

    rootDescription:CreateButton(L('Create new quick response for this keyword'), function()
        if HironCraftScan.Config.ShowCreateQuickReplyDialog then
            HironCraftScan.Config.ShowCreateQuickReplyDialog(selectedText)
        else
            SetStatus(frame, false, 'quick_replies_unavailable')
        end
    end)
    return true
end

function Capture.OpenSelectionMenu(editBox, frame, selectedText)
    selectedText = selectedText or Capture.ExtractSelectedText(editBox)
    if not selectedText or Trim(selectedText) == '' then
        SetStatus(frame, false, 'missing_text')
        return false
    end
    if not MenuUtil or not MenuUtil.CreateContextMenu then
        SetStatus(frame, false, 'quick_replies_unavailable')
        return false
    end
    MenuUtil.CreateContextMenu(editBox, function(_, rootDescription)
        Capture.PopulateSelectionMenu(rootDescription, frame, selectedText)
    end)
    return true
end

local function CreateEditor()
    local frame = CreateFrame(
        'Frame',
        'HironCraftScanChatTextCaptureFrame',
        UIParent,
        'DefaultPanelFlatTemplate'
    )
    frame:SetSize(620, 255)
    frame:SetFrameStrata('DIALOG')
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetTitle(L('Select chat text'))
    HironCraftScan.Frames.makeMovable(frame)

    local close = CreateFrame('Button', nil, frame, 'UIPanelCloseButton')
    close:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', 2, 2)
    close:SetScript('OnClick', function() frame:Hide() end)

    local help = frame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
    help:SetPoint('TOPLEFT', frame, 'TOPLEFT', 24, -40)
    help:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -24, -40)
    help:SetJustifyH('LEFT')
    help:SetText(L('Select a word or phrase in the message, then right-click the selection.'))

    frame.Message = CreateFrame('ScrollFrame', nil, frame, 'InputScrollFrameTemplate')
    frame.Message:SetPoint('TOPLEFT', help, 'BOTTOMLEFT', 0, -14)
    frame.Message:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -24, 52)
    local editBox = frame.Message.EditBox
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject('ChatFontNormal')
    editBox:SetPoint('TOPLEFT', frame.Message, 'TOPLEFT', 0, 0)
    editBox:SetMaxLetters(0)
    Capture.ConfigureMessageScrollFrame(frame.Message)
    InputScrollFrame_OnLoad(frame.Message)
    Capture.ConfigureMessageScrollFrame(frame.Message)
    editBox:SetScript('OnTextChanged', InputScrollFrame_OnTextChanged)
    editBox:SetScript('OnEnterPressed', function(self) self:Insert('\n') end)
    editBox:SetScript('OnEscapePressed', function(self) self:ClearFocus(); frame:Hide() end)
    editBox:SetScript('OnMouseDown', function(self, button)
        if button == 'RightButton' then
            self.hironCraftSelectedText = Capture.ExtractSelectedText(self)
        elseif button == 'LeftButton' and not (IsShiftKeyDown and IsShiftKeyDown()) then
            Capture.BeginWordDrag(self, GetTime and GetTime() or 0)
        end
    end)
    editBox:HookScript('OnUpdate', function(self)
        if self.hironCraftDrag then Capture.UpdateWordDrag(self) end
    end)
    editBox:SetScript('OnMouseUp', function(self, button)
        if button == 'LeftButton' then
            if Capture.FinishWordDrag(self) then return end
            Capture.HandleMultiClick(self, GetTime and GetTime() or 0, IsShiftKeyDown and IsShiftKeyDown())
        elseif button == 'RightButton' then
            local selectedText = self.hironCraftSelectedText
            self.hironCraftSelectedText = nil
            Capture.OpenSelectionMenu(self, frame, selectedText)
        end
    end)

    local function UpdateMessageWidth()
        local width = frame.Message:GetWidth()
        if width and width > 30 then editBox:SetWidth(width - 20) end
    end
    frame.Message:HookScript('OnSizeChanged', UpdateMessageWidth)
    if C_Timer and C_Timer.After then C_Timer.After(0, UpdateMessageWidth) end

    frame.Status = frame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
    frame.Status:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 24, 24)
    frame.Status:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -24, 24)
    frame.Status:SetJustifyH('LEFT')

    frame:SetScript('OnHide', function()
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
    local plainText = Capture.NormalizeFilterText(text)
    if plainText == '' then return false end
    frame.Message.EditBox:SetText(plainText)
    frame.Status:SetText('')
    frame:ClearAllPoints()
    frame:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
    frame:Show()
    frame:Raise()
    frame.Message.EditBox:SetFocus()
    frame.Message.EditBox:HighlightText(0, -1)
    return true
end

local function PublicText(value)
    if issecretvalue and issecretvalue(value) then return nil end
    if type(value) == 'string' and value ~= '' then return value end
end

-- Chat lines can outlive the engine's GetChatLineText cache. Read only the
-- exact line ID in an ordinary chat frame; never guess by author or content.
function Capture.VisibleLine(lineID)
    local frames, seen = {}, {}
    for _, name in ipairs(CHAT_FRAMES or {}) do
        local frame = rawget(_G, name)
        if frame and not seen[frame] then frames[#frames+1] = frame; seen[frame] = true end
    end
    local default = rawget(_G, 'DEFAULT_CHAT_FRAME')
    if default and not seen[default] then frames[#frames+1] = default end
    for _, frame in ipairs(frames) do
        if frame.GetNumMessages and frame.GetMessageInfo then
            local ok, count = pcall(frame.GetNumMessages, frame)
            if ok and not (issecretvalue and issecretvalue(count)) and type(count) == 'number' then
                for index = count, math.max(1, count - 4999), -1 do
                    local read, text, _, _, _, _, _, id = pcall(frame.GetMessageInfo, frame, index)
                    if read and not (issecretvalue and issecretvalue(id)) and id == lineID then
                        return PublicText(text)
                    end
                end
            end
        end
    end
end

function Capture.ShowForLine(lineID, snapshot)
    if issecretvalue and issecretvalue(lineID) then return false end
    if type(lineID) == 'string' then
        lineID = lineID:match('^%d+$') and tonumber(lineID) or nil
    end
    if type(lineID) ~= 'number' or lineID <= 0 then return false end
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
        local chat = rawget(_G, 'DEFAULT_CHAT_FRAME')
        if chat then chat:AddMessage('|cffffd200HironCraft:|r ' .. L('Chat text is temporarily restricted by the game. Try again after leaving combat or the instance.')) end
        return false
    end
    local text = PublicText(snapshot)
    if not text and C_ChatInfo and C_ChatInfo.GetChatLineText then
        local ok, value = pcall(C_ChatInfo.GetChatLineText, lineID)
        if ok and not (issecretvalue and issecretvalue(value)) and type(value) == 'string' and value ~= '' then
            text = value
        end
    end
    -- The game does not always give a line's text back; the chat filter
    -- keeps the last lines it saw.
    local filter = HironCraftScan.ChatFilter
    if not text and filter and filter.LineText then text = PublicText(filter.LineText(lineID)) end
    if not text then text = Capture.VisibleLine(lineID) end
    if not text then
        local chat = rawget(_G, 'DEFAULT_CHAT_FRAME')
        if chat then chat:AddMessage('|cffffd200HironCraft:|r ' .. L('The game did not give the text of this line.')) end
        return false
    end
    return Capture.Show(text)
end
