local HironCraftScan = select(2, ...)

-- What one chat message holds. The game counts the letters that are shown:
-- the code of a link (its color, |H...|h, the closing |h and |r) costs
-- nothing, so a link takes what its [name] takes. A whisper of six item links
-- and 508 bytes sent from here arrived whole, where 255 bytes of everything
-- had been assumed before 0.4.116.
--
-- Two things stay on the safe side until they are known better: the quality
-- icon inside a name (|A...|a) is counted in full, and a message stays under
-- the number of bytes that is known to arrive.
local CHAT_MESSAGE_LETTERS = 255
local CHAT_MESSAGE_BYTES = 500

function HironCraftScan.Utils.ChatLength(text)
    local shown = text:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|cn[%w_]+:', ''):gsub('|H.-|h', '')
        :gsub('|h', ''):gsub('|r', '')
    return #shown
end

function HironCraftScan.Utils.FitsChatMessage(text)
    if #text <= CHAT_MESSAGE_LETTERS then return true end
    return #text <= CHAT_MESSAGE_BYTES and HironCraftScan.Utils.ChatLength(text) <= CHAT_MESSAGE_LETTERS
end
