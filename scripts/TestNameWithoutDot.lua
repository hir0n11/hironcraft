-- A crafter's name never touches a full stop in a message filled from a
-- template: customers asked whether an order goes to "Favu." with the dot.
local Scan = { Utils = {} }
assert(loadfile('Utils/FStrings.lua'))('HironCraft', Scan)
local F, Undot = Scan.Utils.FString, Scan.Utils.NameWithoutDot

local function check(template, values, expected, what)
    local got = F(template, values)
    assert(got == expected, what .. ': "' .. got .. '"')
end
local favu = { crafter = 'Favu', profession_link = '[Jewelcrafting]', item = '[Ring]' }

-- Before more words the dot becomes a dash that stands apart from the name.
check('Send to {crafter}. You choose the price. I\'ll do it now. {profession_link}', favu,
    'Send to Favu - You choose the price. I\'ll do it now. [Jewelcrafting]', 'the dot after the name stayed')
-- At the end of the message it is simply dropped.
check('Hi! Send {item} to {crafter}.', favu, 'Hi! Send [Ring] to Favu', 'a message ends with the name and a dot')
check('Send to {crafter}.  ', favu, 'Send to Favu  ', 'trailing spaces kept the dot')
-- A line that ends with the name may be joined with the next one.
check('Send to {crafter}.\nYou choose the price.', favu, 'Send to Favu -\nYou choose the price.', 'a line ends with the name and a dot')
-- The name with its realm is a name too.
check('Try {crafter}-Kazzak. Or relog.', favu, 'Try Favu-Kazzak - Or relog.', 'the dot after name and realm stayed')
check('Try {crafter}-Kazzak.', favu, 'Try Favu-Kazzak', 'the dot after name and realm stayed at the end')
-- Typed by hand in the same text, and more than once.
check('{crafter}. Send to Favu. Thanks.', favu, 'Favu - Send to Favu - Thanks.', 'a name typed by hand kept its dot')
-- Letters outside ASCII and marks inside a name.
check('Send to {crafter}. Ty', { crafter = 'Azarøth' }, 'Send to Azarøth - Ty', 'a name with other letters kept its dot')
check('Send to {crafter}.', { crafter = "D'arc" }, "Send to D'arc", 'a name with a mark kept its dot')

-- What is not touched: other punctuation, other dots, other names.
check('My alt, {crafter}, can craft {item}.', favu, 'My alt, Favu, can craft [Ring].', 'a comma or another dot was changed')
check('Send to {crafter}... soon', favu, 'Send to Favu... soon', 'an ellipsis was changed')
check('Send to {crafter}! Or {crafter}?', favu, 'Send to Favu! Or Favu?', 'other marks were changed')
check('Send to Vamo. Not to {crafter}', favu, 'Send to Vamo. Not to Favu', 'another name was changed')
check('See favu.example for {crafter}', favu, 'See favu.example for Favu', 'a dot inside a word was changed')
-- Without a crafter in the context nothing is looked for; an unknown tag stays.
check('Send to {crafter}. Ok', {}, 'Send to {crafter}. Ok', 'an unfilled tag was changed')
check('I have {profession}. Ok', { profession = 'Tailoring' }, 'I have Tailoring. Ok', 'a text without a crafter was changed')
assert(Undot('Send to Favu.', nil) == 'Send to Favu.' and Undot('Send to Favu.', '') == 'Send to Favu.')
assert(Undot('nothing here.', 'Favu') == 'nothing here.')

print('Name without a dot passed (before words, at the end, across lines, with realm, by hand, other letters; untouched cases).')
