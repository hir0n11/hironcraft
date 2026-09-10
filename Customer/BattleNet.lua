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
            return info.bnetAccountID, info, index
        end
    end
end

local function CharacterKey(name, realm)
    if Secret(name) or type(name) ~= 'string' or #name > 128 then return nil end
    local short, embeddedRealm = name:match('^([^%-]+)%-(.+)$')
    if short then name, realm = short, embeddedRealm end
    if Secret(realm) or type(realm) ~= 'string' then return nil end
    -- Realm names in hyperlinks omit spaces; Battle.net exposes display names.
    realm = realm:gsub('%s+', '')
    if name == '' or realm == '' or name:find('[%s|:#]') or realm:find('[|:#]') then return nil end
    return (name .. '-' .. realm):lower()
end

local function PlayerGUID(value)
    return not Secret(value) and type(value) == 'string' and #value <= 128
        and value:match('^Player%-%d+%-%x+$') and value or nil
end

local function RememberGameCharacter(response, game)
    if Secret(game) or type(game) ~= 'table'
        or Secret(game.clientProgram) or game.clientProgram ~= 'WoW'
        or Secret(game.isOnline) or game.isOnline ~= true
        or Secret(game.wowProjectID) or not WOW_PROJECT_ID or game.wowProjectID ~= WOW_PROJECT_ID
        or Secret(game.isInCurrentRegion) or game.isInCurrentRegion ~= true then return end
    local key = CharacterKey(game.characterName, game.realmName)
    if not key then return end
    local characters = response.battleNetCharacters
    if type(characters) ~= 'table' then characters = {}; response.battleNetCharacters = characters end
    local count = 0
    for _ in pairs(characters) do count = count + 1 end
    if count < 32 or characters[key] then
        characters[key] = PlayerGUID(game.playerGuid) or characters[key] or true
    end
end

local function RememberFriendCharacters(response, info, index)
    -- A friend may have several WoW accounts online. Do not rely only on the
    -- representative account, which can even be running another Blizzard game.
    RememberGameCharacter(response, info.gameAccountInfo)
    if not C_BattleNet.GetFriendNumGameAccounts or not C_BattleNet.GetFriendGameAccountInfo then return end
    local ok, count = pcall(C_BattleNet.GetFriendNumGameAccounts, index)
    if not ok or Secret(count) or type(count) ~= 'number' then return end
    for accountIndex = 1, math.min(count, 32) do
        local found, game = pcall(C_BattleNet.GetFriendGameAccountInfo, index, accountIndex)
        if found then RememberGameCharacter(response, game) end
    end
end

function M.RememberCharacters(customer, response)
    if type(response) ~= 'table' then return end
    local id, info, index = M.ResolveTarget(customer)
    if id then RememberFriendCharacters(response, info, index) end
end

function M.MatchesCraftingCustomer(customer, characterName, response, crafterFullName, customerGuid)
    if type(response) ~= 'table' then return false end
    -- Unqualified names in a linked completion belong to the recording
    -- crafter's realm, not necessarily the realm displaying the private row.
    local realm
    if crafterFullName ~= nil then
        if Secret(crafterFullName) or type(crafterFullName) ~= 'string' then return false end
        realm = crafterFullName:match('^[^%-]+%-(.+)$')
    else
        realm = GetNormalizedRealmName and GetNormalizedRealmName()
            or (GetRealmName and GetRealmName())
    end
    local wanted = CharacterKey(characterName, realm)
    local guid = PlayerGUID(customerGuid)
    if not wanted and not guid then return false end
    -- Revalidate ownership/friendship, but keep verified request-local names
    -- after logout/alt switching. Never guess from a BattleTag or Real ID name.
    local id, info, index = M.ResolveTarget(customer)
    if not id then return false end
    local function MatchesSnapshot()
        local characters = response.battleNetCharacters
        if type(characters) ~= 'table' then return false end
        if guid then
            for _, knownGuid in pairs(characters) do
                if knownGuid == guid then return true end
            end
        end
        local known = wanted and characters[wanted]
        -- A known different GUID overrides a coincidentally matching full name.
        return known == true or (PlayerGUID(known) ~= nil and (not guid or known == guid))
    end
    if MatchesSnapshot() then return true end
    -- Also repairs rows created before character snapshots were introduced.
    RememberFriendCharacters(response, info, index)
    return MatchesSnapshot()
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
    if Secret(context) or type(context) ~= 'table' then return nil end
    local id = context.bnetIDAccount
    if Secret(id) then return nil end
    if id == nil then
        local info = context.accountInfo
        if Secret(info) or type(info) ~= 'table' then return nil end
        id = info.bnetAccountID
    end
    if Secret(id) then return nil end
    -- Chat hyperlinks pass a digit string through FriendsFrame_ShowBNDropdown;
    -- friend-list menus use numbers. Never substitute a display/character name
    -- (or a different accountInfo ID) when an explicit ID is invalid.
    if type(id) == 'string' then
        if not id:match('^%d+$') then return nil end
        id = tonumber(id)
    end
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
