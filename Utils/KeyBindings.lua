local Scan = select(2, ...)

-- HironCraft's key bindings survive a login with the addon switched off.
-- The game drops a binding whose command does not exist, so one session
-- without the addon loses every key set for it. While the addon runs, the
-- keys of its commands are remembered (a key taken off by hand is forgotten
-- too); at login a command that lost its key gets it back, if nothing else
-- took that key meanwhile.
local K = {}
Scan.KeyBindings = K

local PREFIX = 'HIRONCRAFT'

local function L(key)
    return Scan.LOCAL and Scan.LOCAL:GetText(key) or key
end

-- Remembered keys per binding set: the account's, or one character's.
local function Memory()
    local settings = Scan.DB and Scan.DB.settings
    if type(settings) ~= 'table' then return nil end
    if type(settings.key_bindings) ~= 'table' then settings.key_bindings = {} end
    local set = GetCurrentBindingSet and GetCurrentBindingSet() or 1
    local slot = set == 2 and ('char:' .. tostring(Scan.GetPlayerName and Scan.GetPlayerName(true) or '?')) or 'account'
    if type(settings.key_bindings[slot]) ~= 'table' then settings.key_bindings[slot] = {} end
    return settings.key_bindings[slot], set
end

-- HironCraft's commands and their keys now.
function K.Current()
    local current = {}
    for index = 1, GetNumBindings and GetNumBindings() or 0 do
        local command, _, key1, key2 = GetBinding(index)
        if type(command) == 'string' and command:sub(1, #PREFIX) == PREFIX then
            local keys = {}
            if key1 and key1 ~= '' then keys[#keys + 1] = key1 end
            if key2 and key2 ~= '' then keys[#keys + 1] = key2 end
            current[command] = keys
        end
    end
    return current
end

function K.Remember()
    local memory = Memory()
    if not memory then return end
    for command, keys in pairs(K.Current()) do
        memory[command] = #keys > 0 and keys or nil
    end
end

-- Give back what the game dropped. Returns the commands restored.
function K.Restore()
    local memory, set = Memory()
    if not memory then return {} end
    local current = K.Current()
    local restored = {}
    for command, keys in pairs(memory) do
        -- Only commands this version has, and only when they lost every key.
        if current[command] and #current[command] == 0 and type(keys) == 'table' then
            for _, key in ipairs(keys) do
                local taken = GetBindingAction and GetBindingAction(key)
                if (taken == nil or taken == '') and SetBinding(key, command) then
                    restored[#restored + 1] = command
                end
            end
        end
    end
    if #restored > 0 and SaveBindings then SaveBindings(set) end
    return restored
end

local ready = false

function K.Start()
    if InCombatLockdown and InCombatLockdown() then return false end
    local restored = K.Restore()
    if #restored > 0 then
        local names = {}
        for _, command in ipairs(restored) do
            names[#names + 1] = rawget(_G, 'BINDING_NAME_' .. command) or command
        end
        local chat = rawget(_G, 'DEFAULT_CHAT_FRAME')
        if chat then
            chat:AddMessage('|cffffd200HironCraft:|r ' .. L('Key bindings restored:') .. ' ' .. table.concat(names, ', '))
        end
    end
    ready = true
    K.Remember()
    return true
end

if CreateFrame then
    local watcher = CreateFrame('Frame')
    watcher:RegisterEvent('PLAYER_ENTERING_WORLD')
    watcher:RegisterEvent('UPDATE_BINDINGS')
    watcher:RegisterEvent('PLAYER_REGEN_ENABLED')
    watcher:SetScript('OnEvent', function(_, event)
        if not ready then
            -- Once the game has its bindings and the saved data is set up.
            if (event == 'PLAYER_ENTERING_WORLD' or event == 'PLAYER_REGEN_ENABLED') and C_Timer then
                C_Timer.After(2, function() if not ready then pcall(K.Start) end end)
            end
        elseif event == 'UPDATE_BINDINGS' then
            pcall(K.Remember)
        end
    end)
end
