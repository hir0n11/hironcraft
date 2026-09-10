local HironCraftScan = select(2, ...)
local Utils = HironCraftScan.Utils
local sequence = 0

function Utils.StampChatHistory(entry)
    if type(entry) ~= 'table' then return entry end
    entry.receivedAt = tonumber(entry.receivedAt) or time()
    if not entry.syncID then
        sequence = sequence + 1
        local settings = HironCraftScan.DB and HironCraftScan.DB.settings
        local precise = GetTimePreciseSec and GetTimePreciseSec() or (GetTime and GetTime()) or 0
        entry.syncID = table.concat({tostring(settings and settings.my_uuid or 'local'),
            tostring(entry.receivedAt), tostring(precise), tostring(sequence)}, ':')
    end
    return entry
end

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
            -- Legacy ChatFrame argument packs are not event payloads. A reused
            -- formatting ID must never collapse different incoming messages.
            tostring(entry.message or ''),
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
