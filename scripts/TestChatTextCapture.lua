local noop = function() end
local reloads, shares = 0, 0
local Scan = {
    DB = { settings = { inclusions = 'LF, need craft', exclusions = 'WTS' } },
    Utils = {},
    Scanner = { LoadConfig = function() reloads = reloads + 1 end },
    Frames = { makeMovable = noop },
    LOCAL = { GetText = function(_, text) return text end },
    CONST = { TEXT = setmetatable({ MANUAL_MATCH = 'Match %s %s' }, { __index = function(_, key) return key end }) },
}
function Scan.Utils.saved(parent, key, default)
    if parent[key] == nil then parent[key] = default end
    return parent[key]
end
HironCraftScanComm = { ShareCustomExplanations = function(_, explanations)
    shares = shares + 1
    assert(explanations.Answer == 'Keep |cff0070dd|Hitem:1|h[Blue Item]|h|r')
end }
assert(loadfile('Customer/ChatTextCapture.lua'))('HironCraft', Scan)
local Capture = Scan.ChatTextCapture

local link = '|cffa335ee|Hitem:123::::::::|h[Thalassian Competitor\'s Cloth Cloak]|h|r'
assert(Capture.NormalizeFilterText('  LF ' .. link .. ', please\n ') ==
    "LF Thalassian Competitor's Cloth Cloak please")
assert(Capture.DefaultLabel('one two three four five six seven') == 'one two three four five')
local hidden = 0
local scrollFrame = { CharCount = { Hide = function() hidden = hidden + 1 end } }
Capture.ConfigureMessageScrollFrame(scrollFrame)
assert(scrollFrame.maxLetters == 0 and scrollFrame.hideCharCount == true and
    scrollFrame.scrollBarHideIfUnscrollable == true and hidden == 1)

local ok, reason = Capture.SaveExplanation('', 'text')
assert(not ok and reason == 'missing_label')
ok, reason = Capture.SaveExplanation('Answer', '  Keep |cff0070dd|Hitem:1|h[Blue Item]|h|r  ')
assert(ok and shares == 1)
ok, reason = Capture.SaveExplanation('Answer', 'different')
assert(not ok and reason == 'duplicate_label' and shares == 1)

ok, reason = Capture.SaveFilter('inclusions', ' lf ')
assert(not ok and reason == 'duplicate_filter' and reloads == 0)
ok, reason = Capture.SaveFilter('inclusions', 'LW ' .. link)
assert(ok and Scan.DB.settings.inclusions ==
    "LF, need craft, LW Thalassian Competitor's Cloth Cloak" and reloads == 1)
ok, reason = Capture.SaveFilter('exclusions', 'selling services')
assert(ok and Scan.DB.settings.exclusions == 'WTS, selling services' and reloads == 2)

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
Scan.DB.characters = {}
Scan.GetSortedCrafters = function() return {} end
local menus = {}
Menu = { ModifyMenu = function(name, callback) menus[name] = callback end }
assert(loadfile('Customer/CustomExplanations.lua'))('HironCraft', Scan)
HironCraftScan_CustomExplanationsButtonMixin.Init({ SetupMenu = noop })
local buttons = {}
local root = { CreateDivider = noop, CreateTitle = function() return { SetTooltip = noop } end }
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

buttons = {}
menus.MENU_UNIT_FRIEND(nil, root, { chatTarget = 'Buyer-Realm' })
for _, button in ipairs(buttons) do
    assert(button.label ~= 'HironCraftScan - Save chat text', 'action offered without a chat line')
end

assert(SendChatMessage == nil and BNSendWhisper == nil, 'test unexpectedly gained a send API')
print('Chat text capture tests passed (editing helpers, destination order data, deduplication, hyperlink cleanup, live scanner refresh, click-only menu).')
