local noop = function() end
local reloads, quickShares, professionShares, emitted = 0, 0, 0, 0
local Scan = {
    DB = {
        settings = { inclusions = 'LF, need craft' },
        characters = { Favu = { parent_professions = { [164] = {} } } },
        customers = {},
        listed_orders = {},
    },
    State = {},
    Utils = {},
    Config = { SubstituteTags = function(text) return text end },
    Scanner = { LoadConfig = function() reloads = reloads + 1 end },
    Frames = { makeMovable = noop },
    Events = {
        Emit = function() emitted = emitted + 1 end,
        Register = noop,
    },
    OrderFulfillment = { Status = { Rejected = 'rejected' } },
    LOCAL = { GetText = function(_, text)
        return text == 'DEFAULT_BS' and 'BS, Blacksmith' or text
    end },
    CONST = {
        TEXT = setmetatable({ MANUAL_MATCH = 'Match %s %s' }, { __index = function(_, key) return key end }),
        PROFESSION_DEFAULT_KEYWORDS = { [164] = 'DEFAULT_BS' },
    },
}
function Scan.Utils.saved(parent, key, default)
    if parent[key] == nil then parent[key] = default end
    return parent[key]
end
Scan.Utils.onLoad = noop
Scan.Utils.ProfessionNameByID = function() return 'Blacksmithing' end
Scan.Utils.ColorizeProfessionName = function(_, name) return name end
Scan.ColorizeCrafterName = function(name) return name end
Scan.GetSortedCrafters = function() return { { name = 'Favu', parentProfessionID = 164 } } end
HironCraftScanComm = {
    ShareQuickReplies = function() quickShares = quickShares + 1 end,
    ShareCharacterModification = function(_, char, id, ppOnly)
        assert(char == 'Favu' and id == 164 and ppOnly == true)
        professionShares = professionShares + 1
    end,
}

assert(loadfile('Customer/QuickReplies.lua'))('HironCraft', Scan)
assert(loadfile('Customer/ChatTextCapture.lua'))('HironCraft', Scan)
local Capture = Scan.ChatTextCapture
local QuickReplies = Scan.QuickReplies

local link = '|cffa335ee|Hitem:123::::::::|h[Thalassian Competitor\'s Cloth Cloak]|h|r'
assert(Capture.NormalizeFilterText('  LF ' .. link .. ', please\n ') ==
    "LF Thalassian Competitor's Cloth Cloak please")

local hidden = 0
local scrollFrame = { CharCount = { Hide = function() hidden = hidden + 1 end } }
Capture.ConfigureMessageScrollFrame(scrollFrame)
assert(scrollFrame.maxLetters == 0 and scrollFrame.hideCharCount == true and
    scrollFrame.scrollBarHideIfUnscrollable == true and hidden == 1)

local editBox = { text = 'alpha beta gamma', selectionStart = 6, selectionEnd = 10 }
function editBox:GetText() return self.text end
function editBox:Insert(value)
    self.text = self.text:sub(1, self.selectionStart) .. value .. self.text:sub(self.selectionEnd + 1)
end
function editBox:SetText(value) self.text = value end
function editBox:SetCursorPosition(value) self.cursor = value end
function editBox:HighlightText(first, last) self.highlightFirst, self.highlightLast = first, last end
assert(Capture.ExtractSelectedText(editBox) == 'beta')
assert(editBox.text == 'alpha beta gamma' and editBox.cursor == 10 and
    editBox.highlightFirst == 6 and editBox.highlightLast == 10)
editBox.selectionStart, editBox.selectionEnd = 5, 5
assert(Capture.ExtractSelectedText(editBox) == nil, 'an empty cursor became selected text')

-- Double click selects a word, a third click everything, Shift+click
-- stretches the selection over more words - as in most editors.
local W = Capture.WordBoundsAt
local text = "LF crafter Farstrider's Faulds, 'omw' привет мир"
local function word(cursor) local a, b = W(text, cursor); return a and text:sub(a + 1, b) end
assert(word(0) == 'LF' and word(2) == 'LF', 'the word at either edge was missed')
assert(word(13) == "Farstrider's", 'an apostrophe inside a word split it')
assert(word(33) == 'omw', 'quotes around a word were selected with it')
assert(word(40) == 'привет', 'a Cyrillic word was not selected whole')
assert(word(#text) == 'мир')
assert(W(text, 31) == nil, 'punctuation between words was taken for a word')
local box = { text = text, cursor = 0 }
function box:GetText() return self.text end
function box:GetCursorPosition() return self.cursor end
function box:SetCursorPosition(value) self.cursor = value end
function box:HighlightText(first, last) self.first, self.last = first, last end
local previousTimer = C_Timer
C_Timer = nil
box.cursor = 14
assert(Capture.HandleMultiClick(box, 10) == nil, 'a single click selected something')
box.cursor = 14
assert(Capture.HandleMultiClick(box, 10.2) == 11 and text:sub(box.first + 1, box.last) == "Farstrider's",
    'a double click did not select the word')
box.cursor = 26
Capture.HandleMultiClick(box, 11, true)
assert(text:sub(box.first + 1, box.last) == "Farstrider's Faulds", 'Shift+click did not extend the selection')
box.cursor = 3
Capture.HandleMultiClick(box, 12, true)
assert(text:sub(box.first + 1, box.last) == "crafter Farstrider's", 'Shift+click did not extend backwards')
-- Every click puts the cursor where the mouse is.
box.cursor = 3; Capture.HandleMultiClick(box, 20)
box.cursor = 3; Capture.HandleMultiClick(box, 20.1)
box.cursor = 3; Capture.HandleMultiClick(box, 20.2)
assert(box.first == 0 and box.last == #text, 'a triple click did not select everything')
box.first = nil
box.cursor = 3; Capture.HandleMultiClick(box, 30)
box.cursor = 3; Capture.HandleMultiClick(box, 31)
assert(box.first == nil, 'two slow clicks were taken for a double click')
C_Timer = previousTimer

local ok, reason = Capture.SaveGlobalKeyword(' lf ')
assert(not ok and reason == 'duplicate_filter' and reloads == 0)
ok, reason = Capture.SaveGlobalKeyword('unusual request')
assert(ok and Scan.DB.settings.inclusions == 'LF, need craft, unusual request' and reloads == 1)

ok, reason = Capture.SaveProfessionKeyword('Favu', 164, 'wrist')
assert(ok and Scan.DB.characters.Favu.parent_professions[164].keywords ==
    'BS, Blacksmith, wrist' and reloads == 2 and professionShares == 1)
ok, reason = Capture.SaveProfessionKeyword('Favu', 164, 'WRIST')
assert(not ok and reason == 'duplicate_filter' and professionShares == 1)

ok, reason = Capture.SaveQuickReplyKeyword('NAME', 'nickname')
assert(ok and QuickReplies:GetConfig().templates.NAME.keywords:match('nickname') and quickShares == 1)
ok, reason = Capture.SaveQuickReplyKeyword('NAME', 'NICKNAME')
assert(not ok and reason == 'duplicate_filter' and quickShares == 1)
assert(emitted == 1, 'quick-reply editor was not refreshed')

local function NewMenu()
    local menu = { entries = {}, titles = {} }
    function menu:CreateTitle(text) self.titles[#self.titles + 1] = text end
    function menu:CreateButton(label, click)
        local child = NewMenu()
        self.entries[#self.entries + 1] = { label = label, click = click, child = child }
        return child
    end
    return menu
end
local status = { SetText = function(self, value) self.text = value end,
    SetTextColor = function(self, ...) self.color = { ... } end }
local frame = { Status = status }
local root = NewMenu()
assert(Capture.PopulateSelectionMenu(root, frame, 'chosen words'))
assert(#root.entries == 4)
assert(root.entries[1].label == 'Add to existing quick response')
assert(root.entries[2].label == 'Add to global scanning')
assert(root.entries[3].label == 'Add to profession scanning')
assert(root.entries[4].label == 'Create new quick response for this keyword')
assert(#root.entries[1].child.entries >= 4, 'existing quick responses were not listed')
assert(root.entries[3].child.entries[1].label == 'Favu - Blacksmithing')

local dialogKeywords
Scan.Dialog = { Element = { Text = 1, EditBox = 2 }, Show = function(config)
    dialogKeywords = config.elements[4].initial_text
end }
assert(loadfile('Config/QuickRepliesPanel.lua'))('HironCraft', Scan)
Scan.Config.ShowCreateQuickReplyDialog('chosen words')
assert(dialogKeywords == 'chosen words', 'new quick response did not prefill the selected keyword')

local chatReads, shown = 0, 0
C_ChatInfo = { GetChatLineText = function(id)
    assert(id == 44)
    chatReads = chatReads + 1
    return 'message from chat'
end }
Capture.Show = function(text) shown = shown + 1; assert(text == 'message from chat'); return true end
assert(Capture.ShowForLine('44') and chatReads == 1 and shown == 1)
assert(not Capture.ShowForLine('bad') and chatReads == 1)

Scan.DB.settings.explanations = {}
Scan.DB.settings.ignored = {}
local menus = {}
Menu = { ModifyMenu = function(name, callback) menus[name] = callback end }
assert(loadfile('Customer/CustomExplanations.lua'))('HironCraft', Scan)
HironCraftScan_CustomExplanationsButtonMixin.Init({ SetupMenu = noop })
local buttons = {}
root = { CreateDivider = noop, CreateTitle = function() return { SetTooltip = noop } end }
function root:CreateButton(label, click)
    local button = { label = label, click = click, SetTooltip = noop,
        CreateButton = self.CreateButton, CreateDivider = noop, CreateTitle = self.CreateTitle }
    buttons[#buttons + 1] = button
    return button
end
menus.MENU_UNIT_FRIEND(nil, root, { chatTarget = 'Buyer-Realm', lineID = '44' })
assert(chatReads == 1 and shown == 1, 'opening the menu read or changed the message')
local save
for _, button in ipairs(buttons) do
    if button.label == 'HironCraftScan - Save chat text' then save = button end
end
assert(save, 'save-chat-text action missing')
save.click()
assert(chatReads == 2 and shown == 2, 'clicked action did not open the source message')

assert(SendChatMessage == nil and BNSendWhisper == nil, 'test unexpectedly gained a send API')
print('Chat text selection tests passed (selection extraction, four-action menu, global/profession/quick keys, dialog prefill and click-only source).')
