local CraftScan = { Utils = {} }
assert(loadfile('Customer/ChatHistory.lua'))('HironCraft', CraftScan)

local first = {
    message = '18:43 [2. Trade] [Murahan]: LF Glaive crafter',
    chatType = 'CHANNEL',
}
local duplicate = {
    message = first.message,
    chatType = first.chatType,
}
local distinct = {
    message = '18:44 [2. Trade] [Murahan]: LF Glaive crafter',
    chatType = 'CHANNEL',
}

local unique = CraftScan.Utils.GetUniqueChatHistory({ first, duplicate, distinct })
assert(#unique == 2, 'adjacent legacy duplicate was not collapsed')
assert(unique[1] == first and unique[2] == distinct)

local synced = { message = 'hello', chatType = 'WHISPER', syncID = 'account:1' }
local syncedAgain = { message = 'hello', chatType = 'WHISPER', syncID = 'account:1' }
local history = { synced, distinct }
local stored, inserted = CraftScan.Utils.AppendUniqueChatHistory(history, syncedAgain)
assert(stored == synced and inserted == false, 'synced replay was inserted twice')
assert(#history == 2)

local orderEntry = { message = first.message, chatType = 'CHANNEL', syncID = 'order:req-1' }
stored, inserted = CraftScan.Utils.AppendUniqueChatHistory(history, orderEntry)
assert(stored == orderEntry and inserted == true)
stored, inserted = CraftScan.Utils.AppendUniqueChatHistory(history, {
    message = first.message,
    chatType = 'CHANNEL',
    syncID = 'order:req-1',
})
assert(stored == orderEntry and inserted == false, 'order replay duplicated chat history')

print('Chat history tests passed.')

