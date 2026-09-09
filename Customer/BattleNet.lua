local Scan = select(2, ...)
local M = {}
Scan.BattleNet = M

local function Secret(value)
    return issecretvalue and issecretvalue(value)
end

function M.IsCustomer(customer)
    return not Secret(customer) and type(customer) == 'string' and customer:sub(1, 5) == 'BNET:'
end

local function Owner()
    return Scan.DB and Scan.DB.settings and Scan.DB.settings.my_uuid
end

local function ValidTag(tag)
    return not Secret(tag) and type(tag) == 'string' and #tag <= 64
        and tag:match('^[^#%s|:]+#%d+$') ~= nil
end

local function Key(info)
    if Secret(info) or type(info) ~= 'table' or Secret(info.isFriend) or info.isFriend ~= true
        or not ValidTag(info.battleTag) or type(Owner()) ~= 'string' then return nil end
    return 'BNET:' .. Owner() .. ':' .. info.battleTag:lower()
end

-- IDs are session-local. Persist only an account-scoped BattleTag key, never
-- an ID that could identify a different friend after reload/account switching.
function M.FromID(id)
    if Secret(id) or type(id) ~= 'number' or id <= 0
        or not C_BattleNet or not C_BattleNet.GetAccountInfoByID then return nil end
    local ok, info = pcall(C_BattleNet.GetAccountInfoByID, id)
    if not ok then return nil end
    return Key(info), info
end

function M.DisplayName(customer)
    if not M.IsCustomer(customer) then return nil end
    local tag = customer:match('^BNET:[^:]+:(.+)$')
    return ValidTag(tag) and (tag .. ' (Battle.net)') or 'Battle.net'
end

function M.ResolveTarget(customer)
    if not M.IsCustomer(customer) then return nil end
    local owner, tag = customer:match('^BNET:([^:]+):(.+)$')
    if owner ~= Owner() or not ValidTag(tag) or not BNGetNumFriends
        or not C_BattleNet or not C_BattleNet.GetFriendAccountInfo then return nil end
    local ok, count = pcall(BNGetNumFriends)
    if not ok or Secret(count) or type(count) ~= 'number' then return nil end
    for index = 1, count do
        local found, info = pcall(C_BattleNet.GetFriendAccountInfo, index)
        if found and Key(info) == customer and not Secret(info.bnetAccountID)
            and type(info.bnetAccountID) == 'number' and info.bnetAccountID > 0 then
            return info.bnetAccountID, info
        end
    end
end

function M.Unavailable()
    print('HironCraft: ' .. Scan.LOCAL:GetText('Battle.net reply could not be fully sent. Check that the friend is available.'))
end

function M.HistoryEntry(customer, message, event, lineID)
    local kind = event == 'CHAT_MSG_BN_WHISPER_INFORM' and 'BN_WHISPER_INFORM' or 'BN_WHISPER'
    local color = ChatTypeInfo and ChatTypeInfo[kind]
    local args = color and {color.r, color.g, color.b} or {0, 1, 1}
    if not Secret(lineID) then args[11] = lineID end
    return {chatType=kind, args=args,
        message=(kind == 'BN_WHISPER_INFORM' and '→ ' or '← ')
            .. M.DisplayName(customer) .. ': ' .. message}
end

function M.HandleEvent(event, message, _, ...)
    if not Scan.DB or Scan.DB.settings.scan_bnet_whispers == false
        or Secret(message) or type(message) ~= 'string' then return end
    -- The leading text/playerName are consumed above: guid=12, bnSenderID=13.
    local guid, id = select(10, ...), select(11, ...)
    local customer = M.FromID(id)
    if not customer then return end
    if Secret(guid) or type(guid) ~= 'string' or not guid:match('^Player%-') then guid = nil end
    Scan.OnMessage(event, message, customer, guid, {
        battleNet=true, chatEntry=M.HistoryEntry(customer,message,event,select(9,...)),
    })
end

function M.ContextCustomer(context)
    local id = context.bnetIDAccount or (context.accountInfo and context.accountInfo.bnetAccountID)
    return M.FromID(id)
end

function M.OpenChat(customer)
    local id, info = M.ResolveTarget(customer)
    if not id then M.Unavailable(); return false end
    local name = info.accountName
    if Secret(name) or type(name) ~= 'string' then M.Unavailable(); return false end
    if name == '' then name = info.battleTag:match('^([^#]+)') end
    -- Opening the stock editor uses a name, so check its reverse lookup too.
    -- Two identically displayed friends must never open the wrong conversation.
    if not BNet_GetBNetIDAccount then M.Unavailable(); return false end
    local ok, resolved = pcall(BNet_GetBNetIDAccount, name)
    if not ok or Secret(resolved) or resolved ~= id then M.Unavailable(); return false end
    if ChatFrameUtil and ChatFrameUtil.SendBNetTell then
        ChatFrameUtil.SendBNetTell(name)
    elseif ChatFrame_SendBNetTell then
        ChatFrame_SendBNetTell(name)
    else M.Unavailable(); return false end
    return true
end
