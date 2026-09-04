local HironCraftScan = select(2, ...)
local Utils = HironCraftScan.Utils

local function StableIdentity(entry)
    if type(entry) ~= 'table' then return nil end
    if type(entry.syncID) == 'string' and entry.syncID ~= '' then
        return 'sync\30' .. entry.syncID
    end

    local args = entry.args
    local lineID
    if type(args) == 'table' then lineID = args[11] end
    if lineID ~= nil
        and (type(issecretvalue) ~= 'function' or not issecretvalue(lineID))
    then
        return table.concat({
            'line',
            tostring(entry.chatType or ''),
            tostring(lineID),
        }, '\30')
    end
    return nil
end

local function LegacyIdentity(entry)
    if type(entry) ~= 'table' or type(entry.message) ~= 'string' then
        return nil
    end
    return table.concat({
        tostring(entry.chatType or ''),
        entry.message,
    }, '\30')
end

function Utils.GetUniqueChatHistory(history)
    local result = {}
    local stableSeen = {}
    local previousLegacy

    for _, entry in ipairs(type(history) == 'table' and history or {}) do
        local stable = StableIdentity(entry)
        local legacy = not stable and LegacyIdentity(entry) or nil
        local duplicate = stable and stableSeen[stable]
            or (legacy and legacy == previousLegacy)

        if not duplicate then
            result[#result + 1] = entry
            if stable then stableSeen[stable] = true end
        end
        if stable then
            previousLegacy = nil
        else
            previousLegacy = legacy
        end
    end
    return result
end

function Utils.AppendUniqueChatHistory(history, entry)
    if type(history) ~= 'table' or type(entry) ~= 'table' then
        return nil, false
    end

    local stable = StableIdentity(entry)
    if stable then
        for _, stored in ipairs(history) do
            if StableIdentity(stored) == stable then
                return stored, false
            end
        end
    else
        local legacy = LegacyIdentity(entry)
        local last = history[#history]
        if legacy and LegacyIdentity(last) == legacy and not StableIdentity(last) then
            return last, false
        end
    end

    history[#history + 1] = entry
    return entry, true
end
