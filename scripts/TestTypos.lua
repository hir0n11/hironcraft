-- What counts as a typo of a keyword. The misses were real words one letter
-- away from a keyword ("help" read as "helm"); the hits are how people
-- actually mistype.
local Scan = { Utils = {} }
assert(loadfile('Utils/FStrings.lua'))('HironCraft', Scan)
local T = Scan.Utils.TypoDistance

local typos = {
    { 'charr', 'char' },          -- doubled letter
    { 'writs', 'wrist' },         -- swapped neighbours
    { 'wirst', 'wrist' },
    { 'staf', 'staff' },          -- dropped letter
    { 'bracerss', 'bracers' },
    { 'glvoes', 'gloves' },
    { 'rings', 'ring' },          -- plural
    { 'qualiti', 'quality' },     -- changed letter in a long word
    { 'caracter', 'character' },
    { 'neckalce', 'necklace' },
    { 'recraftign', 'recrafting' },
}
for _, case in ipairs(typos) do
    assert(T(case[1], case[2], 4), case[1] .. ' should be read as ' .. case[2])
end

local words = {
    { 'help', 'helm' },       -- a changed letter in a short word is another word
    { 'stuff', 'staff' },
    { 'crest', 'chest' },
    { 'cheat', 'chest' },
    { 'send', 'sent' },
    { 'less', 'legs' },
    { 'feel', 'feet' },
    { 'heal', 'head' },
    { 'price', 'pride' },
    { 'king', 'ring' },       -- another first letter
    { 'meet', 'feet' },
    { 'bring', 'ring' },
    { 'words', 'sword' },
    { 'boost', 'boots' },     -- real words, whatever the edit
    { 'danger', 'dagger' },
    { 'braces', 'bracers' },
    { 'crafted', 'crafter' },
    { 'from', 'form' },
    { 'ring', 'rng' },        -- too short
    { 'wristwatch', 'wrist' },
    { 'чар', 'char' },        -- not ASCII
}
for _, case in ipairs(words) do
    assert(not T(case[1], case[2], 4), case[1] .. ' must not be read as ' .. case[2])
end
assert(T('wrist', 'wrist', 4) == 0)

print('Typo tests passed (doubled, swapped, dropped letters and plurals are typos; real words, other first letters and short-word substitutions are not).')
