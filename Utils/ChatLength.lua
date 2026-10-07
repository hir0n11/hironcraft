local HironCraftScan = select(2, ...)

-- What one whisper holds, as measured in the game on 2026-10-07 (patch 12.0)
-- with whispers to oneself. The probe that did it, /hcchatlimit, shipped in
-- 0.4.118 - 0.4.124 and is in the git history (Utils/ChatLimitProbe.lua): it
-- whispered from timers, which the addon otherwise never does, so it was
-- taken out once the numbers were known.
--
--   255 bytes of what is shown. Cyrillic takes 2 for a letter: 255 Cyrillic
--   letters (505 bytes) did not arrive.
--   The code of a link (its color, |H...|h, the closing |h and |r) costs
--   nothing: a link takes what its [name] takes, brackets included.
--   The quality icon inside a name (|A...|a) costs nothing either: three
--   links of "[Arcanoweave Bolt <icon>]" and a filler filled a whisper
--   exactly, the name counted as 19.
--   Ten links of 119 bytes, 1196 bytes in all, arrived whole; eleven
--   (1315 bytes) did not. Whether that is the bytes or the number of links
--   is not known, so neither is exceeded.
--
-- A message over the limit is not cut: the game raises "Chat message limits
-- exceeded" and sends nothing. So this must never say that something fits
-- when it does not.
local CHAT_MESSAGE_LETTERS = 255
local CHAT_MESSAGE_BYTES = 1196
local CHAT_MESSAGE_LINKS = 10

function HironCraftScan.Utils.ChatLength(text)
    local shown = text:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|cn[%w_]+:', ''):gsub('|H.-|h', '')
        :gsub('|h', ''):gsub('|r', ''):gsub('|A.-|a', '')
    return #shown
end

function HironCraftScan.Utils.FitsChatMessage(text)
    -- Plain text is its own length.
    if not text:find('|', 1, true) then return #text <= CHAT_MESSAGE_LETTERS end
    if #text > CHAT_MESSAGE_BYTES then return false end
    local _, links = text:gsub('|H', '')
    return links <= CHAT_MESSAGE_LINKS and HironCraftScan.Utils.ChatLength(text) <= CHAT_MESSAGE_LETTERS
end

-- One whisper where one is enough: someone who gets two in a row takes the
-- sender for a bot. The lines of one text that fit one message together go as
-- one. Not for lines that are answers of their own: a greeting says what goes
-- to which crafter in a whisper per crafter, which reads better apart.
function HironCraftScan.Utils.PackMessages(messages)
    local packed = {}
    for _, message in ipairs(messages) do
        if message ~= '' then
            local last = packed[#packed]
            local joined = last and (last .. ' ' .. message)
            if joined and HironCraftScan.Utils.FitsChatMessage(joined) then
                packed[#packed] = joined
            else
                packed[#packed + 1] = message
            end
        end
    end
    return packed
end
