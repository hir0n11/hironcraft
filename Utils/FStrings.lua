local HironCraftScan = select(2, ...)

local function f(s, dict)
    return (s:gsub("{(.-)}", function(key)
        return dict[key] or "{"..key.."}"
    end))
end

HironCraftScan.Utils.FString = f;


-- Conservative misspelling distance, shared by the quick-reply keywords and
-- the equipment aliases so both recognise the same typos. Returns nil when the
-- words are too far apart to be the same word, or too short to guess at.
-- Restricted ASCII words only: a Cyrillic word is one byte sequence away from
-- far too many others.
local function IsAsciiWord(word)
    return type(word) == 'string' and word:match('^[a-z]+$') ~= nil
end

HironCraftScan.Utils.IsAsciiWord = IsAsciiWord

function HironCraftScan.Utils.FuzzyWordDistance(lhs, rhs, minimumLength)
    if type(lhs) ~= 'string' or type(rhs) ~= 'string' then return nil end
    if lhs == rhs then return 0 end
    if not IsAsciiWord(lhs) or not IsAsciiWord(rhs) then return nil end

    local longest = math.max(#lhs, #rhs)
    if longest < (minimumLength or 6) then return nil end
    -- One typo in a short word, two only once a word is long enough that two
    -- edits still leave it recognisable.
    local limit = longest >= 10 and 2 or 1
    if math.abs(#lhs - #rhs) > limit then return nil end

    local distance = {}
    for i = 0, #lhs do
        distance[i] = { [0] = i }
    end
    for j = 0, #rhs do
        distance[0][j] = j
    end

    for i = 1, #lhs do
        local rowMinimum = limit + 1
        for j = 1, #rhs do
            local cost = lhs:byte(i) == rhs:byte(j) and 0 or 1
            local value = math.min(
                distance[i - 1][j] + 1,
                distance[i][j - 1] + 1,
                distance[i - 1][j - 1] + cost
            )
            -- Swapped neighbours ("writs" for "wrist") are one typo, not two.
            if i > 1 and j > 1
                and lhs:byte(i) == rhs:byte(j - 1)
                and lhs:byte(i - 1) == rhs:byte(j)
            then
                value = math.min(value, distance[i - 2][j - 2] + 1)
            end
            distance[i][j] = value
            rowMinimum = math.min(rowMinimum, value)
        end
        if rowMinimum > limit and i > #rhs + limit then
            return nil
        end
    end

    local result = distance[#lhs][#rhs]
    return result <= limit and result or nil
end
