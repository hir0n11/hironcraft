-- HironCraft's key bindings come back after a session without the addon:
-- remembered while it runs, restored at login when the game dropped them,
-- never onto a key something else took, and a key cleared by hand stays off.
local bindings = {   -- command -> { key1, key2 }
    HIRONCRAFT_SCAN_QUICK_REPLY = { 'F7' },
    HIRONCRAFT_SCAN_GREET_CURRENT_CUSTOMER = { 'F8', 'SHIFT-F8' },
    HIRONCRAFT_SCAN_TOGGLE = {},
    MOVEFORWARD = { 'W' },
}
local order = { 'HIRONCRAFT_SCAN_QUICK_REPLY', 'HIRONCRAFT_SCAN_GREET_CURRENT_CUSTOMER', 'HIRONCRAFT_SCAN_TOGGLE', 'MOVEFORWARD' }
function GetNumBindings() return #order end
function GetBinding(index)
    local command = order[index]
    local keys = bindings[command] or {}
    return command, 'cat', keys[1], keys[2]
end
function GetBindingAction(key)
    for command, keys in pairs(bindings) do
        for _, bound in ipairs(keys) do if bound == key then return command end end
    end
    return ''
end
function SetBinding(key, command)
    for _, keys in pairs(bindings) do
        for i = #keys, 1, -1 do if keys[i] == key then table.remove(keys, i) end end
    end
    table.insert(bindings[command], key)
    return true
end
local saved = 0
function SaveBindings() saved = saved + 1 end
function GetCurrentBindingSet() return 1 end
function InCombatLockdown() return false end
local printed = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) printed[#printed + 1] = text end }

local Scan = { DB = { settings = {} }, LOCAL = { GetText = function(_, key) return key end } }
assert(loadfile('Utils/KeyBindings.lua'))('HironCraft', Scan)
local K = Scan.KeyBindings

-- A session with the addon: its keys are remembered, other commands are not.
assert(K.Start() and saved == 0, 'nothing was lost, yet bindings were saved')
local memory = Scan.DB.settings.key_bindings.account
assert(memory.HIRONCRAFT_SCAN_QUICK_REPLY[1] == 'F7' and #memory.HIRONCRAFT_SCAN_GREET_CURRENT_CUSTOMER == 2
    and memory.HIRONCRAFT_SCAN_TOGGLE == nil and memory.MOVEFORWARD == nil, 'the keys were not remembered')

-- A login without the addon: the game dropped its keys, and F8 went to
-- something else meanwhile.
bindings.HIRONCRAFT_SCAN_QUICK_REPLY = {}
bindings.HIRONCRAFT_SCAN_GREET_CURRENT_CUSTOMER = {}
bindings.MOVEFORWARD = { 'W', 'F8' }
local restored = K.Restore()
assert(#restored == 2 and bindings.HIRONCRAFT_SCAN_QUICK_REPLY[1] == 'F7'
    and bindings.HIRONCRAFT_SCAN_GREET_CURRENT_CUSTOMER[1] == 'SHIFT-F8', 'the dropped keys did not come back')
assert(bindings.MOVEFORWARD[2] == 'F8', 'a key something else took was taken back')
assert(saved == 1, 'the restored keys were not saved')

-- A key taken off by hand while the addon runs is forgotten, not restored.
bindings.HIRONCRAFT_SCAN_QUICK_REPLY = {}
K.Remember()
assert(Scan.DB.settings.key_bindings.account.HIRONCRAFT_SCAN_QUICK_REPLY == nil, 'a cleared key was kept')
assert(#K.Restore() == 0 and #bindings.HIRONCRAFT_SCAN_QUICK_REPLY == 0, 'a key cleared by hand came back')

-- The login restore says what it gave back.
bindings.HIRONCRAFT_SCAN_GREET_CURRENT_CUSTOMER = {}
Scan.DB.settings.key_bindings.account.HIRONCRAFT_SCAN_GREET_CURRENT_CUSTOMER = { 'SHIFT-F9' }
BINDING_NAME_HIRONCRAFT_SCAN_GREET_CURRENT_CUSTOMER = 'Greet'
assert(K.Start() and printed[#printed]:find('Greet', 1, true), 'the restore was not reported')
print('Key binding tests passed (remember, restore after a session without the addon, taken keys, cleared keys).')
