local HironCraftScan = select(2, ...)

-- What one chat message holds. The game counts the letters that are shown:
-- the code of a link (its color, |H...|h, the closing |h and |r) costs
-- nothing, so a link takes what its [name] takes, where 255 bytes of
-- everything had been assumed before 0.4.116.
--
-- Checked in the game with whispers sent from here, which arrived whole:
--   six item links, 508 bytes;
--   eight links of a reagent with a quality icon, 1016 bytes, 216 letters
--   shown without the icons.
-- The second leaves at most 4 letters for a quality icon (|A...|a), so an
-- icon is counted as 4, and a message takes no more bytes than that whisper
-- had: nothing longer is known to arrive.
local CHAT_MESSAGE_LETTERS = 255
local CHAT_MESSAGE_BYTES = 1016
local CHAT_ICON_LETTERS = 4

function HironCraftScan.Utils.ChatLength(text)
    local shown = text:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|cn[%w_]+:', ''):gsub('|H.-|h', '')
        :gsub('|h', ''):gsub('|r', '')
    local icons
    shown, icons = shown:gsub('|A.-|a', '')
    return #shown + icons * CHAT_ICON_LETTERS
end

function HironCraftScan.Utils.FitsChatMessage(text)
    if #text <= CHAT_MESSAGE_LETTERS then return true end
    return #text <= CHAT_MESSAGE_BYTES and HironCraftScan.Utils.ChatLength(text) <= CHAT_MESSAGE_LETTERS
end
