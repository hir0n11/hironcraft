local HironCraftScan = select(2, ...)

local LID = HironCraftScan.CONST.TEXT
local function L(id)
    return HironCraftScan.LOCAL:GetText(id)
end

local saved = HironCraftScan.Utils.saved

local LibSerialize = LibStub('LibSerialize')
local LibDeflate = LibStub('LibDeflate')

-- We don't use this yet, but if we ever want a manual import/export process, use these:
--[[
function HironCraftScan.Utils:Export(data)
    local serialized = LibSerialize:Serialize(data)
    local compressed = LibDeflate:CompressDeflate(serialized)
    local encoded = LibDeflate:EncodeForPrint(compressed);
    return encoded;
end

function HironCraftScan.Utils:Import(encoded)
    local decoded = LibDeflate:DecodeForPrint(encoded);
    if not decoded then return end
    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then return end
    local success, data = LibSerialize:Deserialize(decompressed)
    if not success then return end
    return data;
end
]]

HironCraftScanComm = LibStub('AceAddon-3.0'):NewAddon('HironCraftScan', 'AceComm-3.0')
local LibSerialize = LibStub('LibSerialize')
local LibDeflate = LibStub('LibDeflate')

local broadcastChannel = 'HironCraftScan'
local HIRONCRAFT_SCAN_COMM_PREFIX = 'HIRONCRAFT_SCAN'
function HironCraftScanComm:OnEnable()
    self:RegisterComm(HIRONCRAFT_SCAN_COMM_PREFIX)

    -- We want to make sure we've waited until after the other channels are
    -- initialized so we don't plan HironCraftScan at /1. I tried being clever and
    -- waiting for those, but I think it was intermittently registering the
    -- event after it had happened, so we missed it and never registered. We
    -- only really need to do this once, so using a long ass wait should make it
    -- safe and only impacts the first login after upgrade.
    C_Timer.After(60, function()
        JoinChannelByName(broadcastChannel)
    end)
end

HironCraftScanComm.Operations = {
    ShareCharacterData = 'share_char_data',
    Handshake = 'handshake',
    ShareCustomerOrder = 'share_customer_order',
    ShareCustomerChat = 'share_customer_chat',
    ShareCustomGreeting = 'share_custom_greeting',
    ShareCustomExplanations = 'share_custom_explanations',
    ShareQuickReplies = 'share_quick_replies',
    ShareOrderStatus = 'share_order_status',
    OrderStatusAck = 'order_status_ack',
    OrderStatusRepair = 'order_status_repair',
    ShareOrderCompletion = 'share_order_completion',
    ShareOrderCompletionRepair = 'share_order_completion_repair',
    OrderCompletionAck = 'order_completion_ack',
    ShareOrderOutcome = 'share_order_outcome',
    ShareAnalytics = 'share_analytics',
    Ping = 'ping',
    FindCrafter = 'fc',
    RequestCraft = 'rc',
}

HironCraftScanComm.Permissions = {
    Full = 1,
    Analytics = 2,
}

HironCraftScanComm.PermissionStrings = {
    [HironCraftScanComm.Permissions.Full] = {
        name = LID.LINKED_ACCOUNT_PERMISSION_FULL,
        desc = LID.ACCOUNT_LINK_FULL_CONTROL_DESC,
    },
    [HironCraftScanComm.Permissions.Analytics] = {
        name = LID.LINKED_ACCOUNT_PERMISSION_ANALYTICS,
        desc = LID.ACCOUNT_LINK_ANALYTICS_DESC,
    },
}

-- A flag to send the request to all known linked accounts
local TARGET_ALL = nil

local TARGET_BROADCAST = 1

-- Accounts that respond to the initial sharing phase are stored here. From then
-- on, we keep this updated with who is talking to us, and we only talk back to
-- them. If a new remote account comes online, their sharing phase will replace
-- any prior entry from that account.
local remoteTargets = nil
local SendPing
local StartHeartbeat
local SendOrderStatusAcks
local SendOrderStatusRepairs
local ReceiveOrderStatuses
local lastRecentOrderReplayAt = nil
local FRESH_TARGET_SECONDS = 15
local HEARTBEAT_SECONDS = 10
local PING_ATTEMPT_TIMEOUT_SECONDS = 6
local RECENT_ORDER_REPLAY_THROTTLE_SECONDS = 2
local RECENT_ORDER_NOTICE_LIMIT = 12
local RECENT_ORDER_STATUS_LIMIT = 20
local PENDING_ORDER_BATCH_LIMIT = 20

local function NewestOrderEntries(entries, limit, predicate)
    local result = {}
    for _, entry in pairs(entries or {}) do
        if type(entry) == 'table' and (not predicate or predicate(entry)) then
            table.insert(result, entry)
        end
    end
    table.sort(result, function(lhs, rhs)
        return (tonumber(lhs.updatedAt) or 0) > (tonumber(rhs.updatedAt) or 0)
    end)
    while limit and #result > limit do
        table.remove(result)
    end
    return result
end

local function HaveTarget()
    if remoteTargets then
        for _, target in pairs(remoteTargets) do
            if next(target) then
                return true
            end
        end
    end

    -- We either have no one to talk to, or we haven't sent our greeting yet.
    -- The greeting syncs in both directions, so it's fine to skip updates
    -- before then. It's likely impossible in practice to sneak something into
    -- this window.
    return false
end

local function LinkedAccountsConfigured()
    if not HironCraftScan.DB.realm.linked_accounts or not next(HironCraftScan.DB.realm.linked_accounts) then
        return false
    end
    return true
end

local function FreshTargetForAccount(accountID)
    local accountTargets = remoteTargets and remoteTargets[accountID]
    local freshestTarget = nil
    local freshestSeen = nil
    for target, lastSeen in pairs(accountTargets or {}) do
        if not freshestSeen or lastSeen > freshestSeen then
            freshestTarget = target
            freshestSeen = lastSeen
        end
    end

    if freshestSeen and time() - freshestSeen <= FRESH_TARGET_SECONDS then
        return freshestTarget
    end
    return nil
end

local function TransmitToFullLinkedAccounts(data, operation)
    if not LinkedAccountsConfigured() then
        return false
    end

    local queued = false
    for accountID, account in pairs(HironCraftScan.DB.realm.linked_accounts) do
        if HironCraftScan.Utils.Contains(account.permissions, HironCraftScanComm.Permissions.Full) then
            local target = FreshTargetForAccount(accountID)
            if target then
                HironCraftScanComm:Transmit(HironCraftScan.Utils.DeepCopy(data), operation, target)
            else
                -- Do not trust an indefinitely stale green link. Discover the
                -- current character and deliver the original operation only
                -- after that character answers.
                SendPing(accountID, function(_, sender)
                    HironCraftScanComm:Transmit(HironCraftScan.Utils.DeepCopy(data), operation, sender)
                end)
            end
            queued = true
        end
    end
    return queued
end

function HironCraftScanComm:PrepareOrderStatusDelivery(entry)
    if type(entry) ~= 'table' then
        return false
    end

    local pending = {}
    for accountID, account in pairs(HironCraftScan.DB.realm.linked_accounts or {}) do
        if HironCraftScan.Utils.Contains(account.permissions, HironCraftScanComm.Permissions.Full) then
            pending[accountID] = true
        end
    end

    entry.deliveryPending = next(pending) and pending or nil
    entry.deliveryConfirmedAt = nil
    return entry.deliveryPending ~= nil
end

function HironCraftScanComm:PrepareOrderCompletionDelivery(notice)
    -- Completion notices are the only proof available when the crafting
    -- character does not have the originating CraftScan row. Keep them pending
    -- until every full linked account confirms receipt, just like exact status
    -- entries, so a fast logout cannot lose the green mark.
    return self:PrepareOrderStatusDelivery(notice)
end

local function CreateInitialTargets()
    local targets = {}

    for char, charConfig in pairs(HironCraftScan.DB.characters) do
        if charConfig.sourceID ~= nil and charConfig.sourceID ~= HironCraftScan.DB.settings.my_uuid then
            targets[charConfig.sourceID] = targets[charConfig.sourceID] or {}
            targets[charConfig.sourceID][char] = true
        end
    end

    for sourceID, info in pairs(HironCraftScan.DB.realm.linked_accounts) do
        if HironCraftScan.Utils.Contains(info.permissions, HironCraftScanComm.Permissions.Full) then
            targets[sourceID] = targets[sourceID] or {}
            for _, char in ipairs(info.backup_chars) do
                targets[sourceID][char] = true
            end
        end
    end

    return targets
end

-- Sharing has 3 phases. The first side sends an InitialInquiry with their
-- current profession revisions. The other side immediately responds with a
-- ResponseInquiry with its revisions. (We could potentially be smarter here
-- since we have a view of the other side already, but this data is small and
-- this keeps it clean and easy.) The side that received the InitialInquiry then
-- falls through and starts is ResponseData phase. When the originating side
-- receives the ResponseInquiry, it moves directly to the ResponseData phase
-- (without infinitely recursing on more ResponseInquiries). By the end, both
-- sides will have received any out of date profession information that the
-- other side has.
--
-- We do this full flow when establishing a linked account and when a character
-- logs in to catch up on any changes it missed while offline. This message is
-- also the only one we allow through while 'remoteTargets' is not initialized.
-- This initial sharing phase is also used to seed the remoteTargets so we know
-- who is online for future messages.
--
-- When individual profession changes are made, they are pushed across directly
-- with the ResponseData phase since we know the other side is out of date.
local SharingState = {
    InitialInquiry = 1,
    ResponseInquiry = 2,
    ResponseData = 3,
}

-- Filter our character list to only the revisions to send a small amount of
-- data in our greeting to other accounts.
local function CreateRevisions()
    local revisions = {}
    for char, charConfig in pairs(HironCraftScan.DB.characters) do
        for ppID, ppConfig in pairs(charConfig.parent_professions) do
            local ppRev = saved(revisions, char, {})
            ppRev[ppID] = ppConfig.rev or 0
        end
    end
    return revisions
end

-- Linked accounts can update eachother about a 3rd account, but only if the 3rd
-- account is also a linked such that the receiver can see it directly.
-- Inquiries include the requester's peer list so the response can be filtered.
local function MyPeers()
    local peers = {}
    for peer, _ in pairs(HironCraftScan.DB.realm.linked_accounts) do
        table.insert(peers, peer)
    end
    return peers
end

local function CharacterInPeers(charConfig, peers)
    for _, peer in ipairs(peers) do
        if charConfig.sourceID == peer then
            return true
        end
    end

    return false
end

local function GreetingRevision()
    local greeting = HironCraftScan.DB.settings.greeting
    return greeting and greeting.rev or 0
end

local function ExplanationsRevision()
    local explanations = HironCraftScan.DB.settings.explanations
    return explanations and explanations.rev or 0
end

local function QuickRepliesRevision()
    local quickReplies = HironCraftScan.DB.settings.quick_replies
    return quickReplies and quickReplies.rev or 0
end

local function SendShareCharacterData(target, data)
    HironCraftScanComm:Transmit(data, HironCraftScanComm.Operations.ShareCharacterData, target)
end

local function SendResponseCharacterData(target, characters, greeting, explanations, quickReplies)
    SendShareCharacterData(target, {
        characters = characters,
        greeting = greeting,
        explanations = explanations,
        quick_replies = quickReplies,
        state = SharingState.ResponseData,
    })
end

local function ShareCharacterData_(state, target)
    if not LinkedAccountsConfigured() then
        return
    end

    local revisions = CreateRevisions()
    local peers = MyPeers()
    local orderCompletions = {}
    local orderOutcomes = {}
    local orderStatuses = {}
    if HironCraftScan.OrderFulfillment then
        local recentNotices = NewestOrderEntries(
            HironCraftScan.OrderFulfillment:GetCompletionNotices(),
            RECENT_ORDER_NOTICE_LIMIT
        )
        for _, notice in ipairs(recentNotices) do
            if notice.status == HironCraftScan.OrderFulfillment.Status.Rejected then
                table.insert(orderOutcomes, HironCraftScan.Utils.DeepCopy(notice))
            else
                table.insert(orderCompletions, HironCraftScan.Utils.DeepCopy(notice))
            end
        end
        orderStatuses = HironCraftScan.Utils.DeepCopy(NewestOrderEntries(
            HironCraftScan.OrderFulfillment:GetStatuses(),
            RECENT_ORDER_STATUS_LIMIT
        ))
    end

    local data = {
        revisions = revisions,
        peers = peers,
        greeting_revision = GreetingRevision(),
        explanations_revision = ExplanationsRevision(),
        quick_replies_revision = QuickRepliesRevision(),
        order_statuses = orderStatuses,
        order_completions = orderCompletions,
        order_outcomes = orderOutcomes,
        state = state,
    }
    SendShareCharacterData(target, data)
end

local function ReceiveShareCustomGreeting_(greeting)
    if
        not HironCraftScan.DB.settings.greeting
        or ((HironCraftScan.DB.settings.greeting.rev or 0) < greeting.rev)
    then
        HironCraftScan.DB.settings.greeting = greeting
    end
end

local function ReceiveShareCustomExplanations_(explanations)
    if
        not HironCraftScan.DB.settings.explanations
        or ((HironCraftScan.DB.settings.explanations.rev or 0) < explanations.rev)
    then
        HironCraftScan.DB.settings.explanations = explanations
    end
end

local function ReceiveShareQuickReplies_(quickReplies)
    if HironCraftScan.QuickReplies then
        HironCraftScan.QuickReplies:ApplyRemoteConfig(quickReplies)
    end
end

local function ReceiveShareCharacterData(sender, data, senderID)
    if data.state == SharingState.InitialInquiry then
        -- The other side is requesting data, so we do the same to make sure
        -- everything is in sync.
        ShareCharacterData_(SharingState.ResponseInquiry, sender)
    end

    local characters = data.characters
    if characters then
        -- Process a reply with more up to date profession information. We verify
        -- one last time here that we only import more recent data.
        for char, charConfig in pairs(characters) do
            local localCharConfig = HironCraftScan.DB.characters[char]

            if not localCharConfig and string.find(char, "'") then
                -- See issue #48.
                -- We had incorrect realm shortening at one point that removed
                -- single quotes when it should not have. If we have received a
                -- correctly shortened realm, check if we have the
                -- corresponding entry with the incorrectly shortened name and
                -- swap them before continuing.
                local brokenChar = char:gsub("[']", '')
                localCharConfig = HironCraftScan.DB.characters[brokenChar]
                if localCharConfig then
                    HironCraftScan.DB.characters[char] = localCharConfig
                    HironCraftScan.DB.characters[brokenChar] = nil
                end
            end

            if not localCharConfig then
                HironCraftScan.DB.characters[char] = charConfig
            else
                if not localCharConfig.sourceID then
                    localCharConfig.sourceID = charConfig.sourceID
                end
                for ppID, ppConfig in pairs(charConfig.parent_professions) do
                    if
                        not localCharConfig.parent_professions[ppID]
                        or ((localCharConfig.parent_professions[ppID].rev or 0) < (ppConfig.rev or 0))
                        or ppConfig.character_disabled
                    then
                        localCharConfig.parent_professions[ppID] = ppConfig
                        if ppConfig.character_disabled then
                            -- The other side can't send the lack of something
                            -- without a special payload, so we handle the
                            -- character_disabled flag specially to copy the
                            -- parent side behavior of wiping out child
                            -- professions.
                            HironCraftScan.RemoveChildProfessions(localCharConfig, parentProfID)
                        elseif charConfig.professions then -- Can be excluded for parent only changes
                            for id, config in pairs(charConfig.professions) do
                                if config.parentProfID == ppID then
                                    localCharConfig.professions[id] = config
                                end
                            end
                        end
                    end
                end
            end
        end
        if next(characters) then
            HironCraftScanComm.applying_remote_state = true
            HironCraftScan.OnCrafterListModified()
            HironCraftScanComm.applying_remote_state = false
        end
    end

    if data.greeting then
        ReceiveShareCustomGreeting_(data.greeting)
    end

    if data.explanations then
        ReceiveShareCustomExplanations_(data.explanations)
    end

    if data.quick_replies then
        ReceiveShareQuickReplies_(data.quick_replies)
    end

    if data.order_statuses and HironCraftScan.OrderFulfillment then
        ReceiveOrderStatuses(sender, data.order_statuses, true)
    end

    if data.order_completions and HironCraftScan.OrderFulfillment then
        HironCraftScan.OrderFulfillment:ApplyRemoteCompletionNotices(data.order_completions)
    end

    if data.order_outcomes and HironCraftScan.OrderFulfillment then
        HironCraftScan.OrderFulfillment:ApplyRemoteCompletionNotices(data.order_outcomes)
    end

    if data.state ~= SharingState.ResponseData then
        -- We were given revisions. Respond with any character data that is
        -- either newer than or not included in the revisions, filtered by what
        -- the peer told us they are allowed to see.
        local revisions = data.revisions

        local brokenRevisions = {}
        for char, _ in pairs(revisions) do
            -- See issue #48.
            -- We might receive revisions where a shortened realm name has
            -- already been corrected on the this side. If we simply roll with
            -- that, we'll send them the bad version back. Convert all correct
            -- realm names to bad realm names so we can see if we have any
            -- locally and delete them. (We can only convert from good to bad,
            -- not from bad to good)
            if string.find(char, "'") then
                brokenRevisions[char:gsub("[']", '')] = true
            end
        end

        local responseCharacters = {}
        local peers = data.peers
        for char, localCharConfig in pairs(HironCraftScan.DB.characters) do
            local characterOwnedByPeer = localCharConfig.sourceID == senderID
            if CharacterInPeers(localCharConfig, peers) or characterOwnedByPeer then
                local remoteCharConfig = revisions[char]
                if not remoteCharConfig then
                    if brokenRevisions[char] then
                        HironCraftScan.DB.characters[char] = nil
                    else
                        if next(localCharConfig.parent_professions) then
                            responseCharacters[char] = localCharConfig
                        end
                    end
                else
                    -- Both sides have the character, walk the professions and
                    -- return only what the other side has out of date.
                    for ppID, ppConfig in pairs(localCharConfig.parent_professions) do
                        if
                            not remoteCharConfig[ppID]
                            or ((remoteCharConfig[ppID] or 0) < (ppConfig.rev or 0))
                        then
                            local rc = saved(responseCharacters, char, {})
                            local pps = saved(rc, 'parent_professions', {})
                            pps[ppID] = ppConfig

                            -- Only the character owning account has access to
                            -- modify professions, so we don't need to worry
                            -- about sending them.
                            --
                            -- Note that this can lead to errors if the user
                            -- manually does CLEANUP on the owning account but
                            -- not on the other account.
                            if not characterOwnedByPeer then
                                for id, config in pairs(localCharConfig.professions) do
                                    if config.parentProfID == ppID then
                                        local profs = saved(rc, 'professions', {})
                                        profs[id] = config
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        local greetingResponse = nil
        local greetingRevision = GreetingRevision()
        if data.greeting_revision and data.greeting_revision < greetingRevision then
            greetingResponse = HironCraftScan.DB.settings.greeting
        end

        local explanationsResponse = nil
        local explanationsRevision = ExplanationsRevision()
        if data.explanations_revision and data.explanations_revision < explanationsRevision then
            explanationsResponse = HironCraftScan.DB.settings.explanations
        end

        local quickRepliesResponse = nil
        local quickRepliesRevision = QuickRepliesRevision()
        if data.quick_replies_revision and data.quick_replies_revision < quickRepliesRevision then
            quickRepliesResponse = HironCraftScan.DB.settings.quick_replies
        end

        if next(responseCharacters) or greetingResponse or explanationsResponse or quickRepliesResponse then
            SendResponseCharacterData(
                sender,
                responseCharacters,
                greetingResponse,
                explanationsResponse,
                quickRepliesResponse
            )
        end
    end
end

function HironCraftScanComm:ShareCharacterData()
    if not LinkedAccountsConfigured() then
        return
    end

    StartHeartbeat()

    -- A full login snapshot can contain hundreds of historic orders and is
    -- intentionally sent at BULK priority. Replay the compact recent journal
    -- first so an order saved just before a character switch is visible on the
    -- linked client without waiting for that snapshot to finish.
    self:ReplayRecentOrderHistory()

    -- Discover one live character with a tiny ping before sending the full
    -- login snapshot. Sending the snapshot to every known alt makes AceComm
    -- split it into many offline whispers and floods the system chat once per
    -- fragment.
    remoteTargets = remoteTargets or {}
    for accountID, account in pairs(HironCraftScan.DB.realm.linked_accounts) do
        if HironCraftScan.Utils.Contains(account.permissions, HironCraftScanComm.Permissions.Full) then
            SendPing(accountID, function(_, sender)
                ShareCharacterData_(SharingState.InitialInquiry, sender)
            end)
        end
    end
end

function HironCraftScanComm:RefreshLinkedAccount(accountID)
    local account = HironCraftScan.DB.realm.linked_accounts
        and HironCraftScan.DB.realm.linked_accounts[accountID]
    if not account then
        return false
    end

    SendPing(accountID, function(_, sender)
        ShareCharacterData_(SharingState.InitialInquiry, sender)
    end)
    return true
end

local function AddOnePpMsg(msgCharacters, char, charConfig, ppID, ppConfig, ppChangeOnly)
    local mc = saved(msgCharacters, char, {})
    mc.sourceID = charConfig.sourceID

    local pps = saved(mc, 'parent_professions', {})
    pps[ppID] = ppConfig

    if not ppChangeOnly then
        for id, config in pairs(charConfig.professions) do
            if config.parentProfID == ppID then
                local profs = saved(mc, 'professions', {})
                profs[id] = config
            end
        end
    end
end

-- For the toggle-all buttons at the top of the character list, do a bulk push
-- of all parent professions with no child profession data.
function HironCraftScanComm:ShareAllPpCharacterModifications()
    if not LinkedAccountsConfigured() then
        return
    end

    for _, charConfig in pairs(HironCraftScan.DB.characters) do
        for _, ppConfig in pairs(charConfig.parent_professions) do
            ppConfig.rev = (ppConfig.rev or 0) + 1
        end
    end

    if not HaveTarget() then
        return
    end

    local msgCharacters = {}
    local ppChangeOnly = true
    for char, charConfig in pairs(HironCraftScan.DB.characters) do
        for ppID, ppConfig in pairs(charConfig.parent_professions) do
            AddOnePpMsg(msgCharacters, char, charConfig, ppID, ppConfig, ppChangeOnly)
        end
    end

    SendResponseCharacterData(TARGET_ALL, msgCharacters)
end

-- A single modification to the profession. We don't get specific - if they
-- changed anything, toss the whole profession across.
function HironCraftScanComm:ShareCharacterModification(char, ppID, ppChangeOnly)
    if not LinkedAccountsConfigured() then
        return
    end

    local charConfig = HironCraftScan.DB.characters[char]
    local ppConfig = charConfig.parent_professions[ppID]
    ppConfig.rev = (ppConfig.rev or 0) + 1

    if not HaveTarget() then
        return
    end

    local msgCharacters = {}

    AddOnePpMsg(msgCharacters, char, charConfig, ppID, ppConfig, ppChangeOnly)

    SendResponseCharacterData(TARGET_ALL, msgCharacters)
end

HironCraftScan.Events:Register('CHARACTER_ENABLED', function(ctxt)
    HironCraftScanComm:ShareCharacterModification(ctxt.name, ctxt.ppInfo.professionID)
end)

function HironCraftScanComm:ShareCustomerOrder(
    message,
    customer,
    customerGuid,
    lastChatFrameMessage,
    requestToken,
    restartTerminalRequest
)
    if not LinkedAccountsConfigured() then
        return
    end
    if HironCraftScanComm.applying_remote_state then
        return
    end -- Block infinite recursion
    if not HironCraftScan.DB.settings.proxy_send_enabled then
        return
    end -- We're disabled

    local data = {
        message = message,
        customer = customer,
        customerGuid = customerGuid,
        lastChatFrameMessage = HironCraftScan.Utils.DeepCopy(lastChatFrameMessage),
        requestToken = requestToken,
        restartTerminalRequest = restartTerminalRequest == true,
    }

    -- Trying to send a function crashes serialization. Only seen this in testing at args[9]
    if
        data.lastChatFrameMessage
        and data.lastChatFrameMessage.args
        and type(data.lastChatFrameMessage.args[9]) == 'function'
    then
        data.lastChatFrameMessage.args[9] = nil
        data.lastChatFrameMessage.args['n'] = data.lastChatFrameMessage.args['n'] - 1
    end

    TransmitToFullLinkedAccounts(data, HironCraftScanComm.Operations.ShareCustomerOrder)
end

local customerChatSequence = 0

function HironCraftScanComm:ShareCustomerChat(customer, customerGuid, entry, incoming)
    if not LinkedAccountsConfigured()
        or HironCraftScanComm.applying_remote_state
        or not HironCraftScan.DB.settings.proxy_send_enabled
        or type(customer) ~= 'string'
        or type(entry) ~= 'table'
        or type(entry.message) ~= 'string'
    then
        return
    end

    -- Keep this packet deliberately small: ChatFrame's original AddMessage
    -- arguments can contain functions and other values AceSerializer cannot
    -- transmit. The text and resolved colour are all the remote tooltip needs.
    customerChatSequence = customerChatSequence + 1
    entry.syncID = entry.syncID or table.concat({
        tostring(HironCraftScan.DB.settings.my_uuid or ''),
        tostring(time()),
        tostring(customerChatSequence),
    }, ':')
    local r, g, b = HironCraftScan.Utils.GetChatHistoryColor(entry)
    local data = {
        customer = customer,
        customerGuid = customerGuid,
        incoming = incoming == true,
        entry = {
            message = entry.message,
            args = { r, g, b },
            chatType = entry.chatType,
            syncID = entry.syncID,
        },
    }
    TransmitToFullLinkedAccounts(data, HironCraftScanComm.Operations.ShareCustomerChat)
end

local function ReceiveShareCustomerChat(sender, data, senderID)
    if not HironCraftScan.DB.settings.proxy_receive_enabled
        or type(data) ~= 'table'
        or not HironCraftScan.ApplyRemoteCustomerChat
    then
        return
    end

    local applyingRemoteState = HironCraftScanComm.applying_remote_state
    HironCraftScanComm.applying_remote_state = true
    local ok, err = pcall(
        HironCraftScan.ApplyRemoteCustomerChat,
        data.customer,
        data.customerGuid,
        data.entry,
        data.incoming
    )
    HironCraftScanComm.applying_remote_state = applyingRemoteState
    if not ok then
        HironCraftScan.Utils.printTable('Failed to receive customer chat', {
            sender = sender,
            senderID = senderID,
            error = err,
        })
    end
end

local function ReceiveShareCustomerOrder(sender, data, senderID)
    if not HironCraftScan.DB.settings.proxy_receive_enabled then
        return
    end
    if
        not HironCraftScan.InjectLastChatFrameMessage(
            data.customer,
            data.message,
            data.lastChatFrameMessage
        )
    then
        return
    end

    -- We pull the formatted message from a rotating chat log buffer, so
    -- inject the raw chat frame into that so it can be found.
    HironCraftScanComm.applying_remote_state = true

    -- Make sure the button is showing so the banner can be shown.
    HironCraftScanScannerMenu:Show()

    -- The sending side only sends after they get a match, but the minimum
    -- amount of data to send is simply the message itself and the customer. We
    -- have all the same config on this side, so we can process it in the same
    -- way. This is more work on this side, but it minimizes both the sent data and
    -- the differences between a received message and a naturally detected message.
    HironCraftScan.OnMessage(
        'CHAT_MSG_CHANNEL',
        data.message,
        data.customer,
        data.customerGuid,
        {
            requestToken = data.requestToken,
            restartTerminalRequest = data.restartTerminalRequest == true,
        }
    )

    HironCraftScanComm.applying_remote_state = false
end

function HironCraftScanComm:ShareCustomGreeting(greeting)
    if not LinkedAccountsConfigured() then
        return
    end

    greeting.rev = (greeting.rev or 0) + 1

    if not HaveTarget() then
        return
    end
    if HironCraftScanComm.applying_remote_state then
        return
    end -- Block infinite recursion

    HironCraftScanComm:Transmit(greeting, HironCraftScanComm.Operations.ShareCustomGreeting, TARGET_ALL)
end

local function ReceiveShareCustomGreeting(sender, data, senderID)
    ReceiveShareCustomGreeting_(data)
end

function HironCraftScanComm:ShareCustomExplanations(explanations)
    if not LinkedAccountsConfigured() then
        return
    end

    explanations.rev = (explanations.rev or 0) + 1

    if not HaveTarget() then
        return
    end
    if HironCraftScanComm.applying_remote_state then
        return
    end -- Block infinite recursion

    HironCraftScanComm:Transmit(
        explanations,
        HironCraftScanComm.Operations.ShareCustomExplanations,
        TARGET_ALL
    )
end

local function ReceiveShareCustomExplanations(sender, data, senderID)
    ReceiveShareCustomExplanations_(data)
end

function HironCraftScanComm:ShareQuickReplies(quickReplies)
    quickReplies.rev = (quickReplies.rev or 0) + 1

    if not LinkedAccountsConfigured() or not HaveTarget() then
        return
    end
    if HironCraftScanComm.applying_remote_state then
        return
    end -- Block infinite recursion

    HironCraftScanComm:Transmit(
        quickReplies,
        HironCraftScanComm.Operations.ShareQuickReplies,
        TARGET_ALL
    )
end

local function ReceiveShareQuickReplies(sender, data, senderID)
    ReceiveShareQuickReplies_(data)
end

local function DiscoverOrderStatusTarget(accountID)
    -- The ping response flushes every currently pending order update in one
    -- bounded packet. Avoid attaching one callback per revision: during a busy
    -- session those callbacks and their direct retries could outpace AceComm.
    SendPing(accountID)
end

function HironCraftScanComm:ShareOrderStatus(entry)
    if not LinkedAccountsConfigured() then
        return
    end
    if HironCraftScanComm.applying_remote_state then
        return
    end

    -- Send immediately to a recently verified character, but do not wait for
    -- the periodic heartbeat to notice that the account changed characters.
    -- If the direct delivery does not get an ACK within one second, discover
    -- the live character. Its ping response flushes the latest pending state
    -- as a batch, superseding any obsolete intermediate revisions.
    for accountID, account in pairs(HironCraftScan.DB.realm.linked_accounts or {}) do
        if
            type(entry.deliveryPending) == 'table'
            and entry.deliveryPending[accountID]
            and HironCraftScan.Utils.Contains(
                account.permissions,
                HironCraftScanComm.Permissions.Full
            )
        then
            local deliveryAccountID = accountID
            local target = FreshTargetForAccount(accountID)
            if target then
                HironCraftScanComm:Transmit(
                    HironCraftScan.Utils.DeepCopy(entry),
                    HironCraftScanComm.Operations.ShareOrderStatus,
                    target
                )
                if C_Timer and C_Timer.After then
                    C_Timer.After(1, function()
                        if
                            type(entry.deliveryPending) == 'table'
                            and entry.deliveryPending[deliveryAccountID]
                        then
                            DiscoverOrderStatusTarget(deliveryAccountID)
                        end
                    end)
                end
            else
                DiscoverOrderStatusTarget(accountID)
            end
        end
    end
end

local function StatusAck(entry)
    if type(entry) ~= 'table' then
        return nil
    end
    if type(entry.customerName) ~= 'string' then
        return nil
    end
    if type(entry.responseID) ~= 'number' and type(entry.responseID) ~= 'string' then
        return nil
    end

    return {
        customerName = entry.customerName,
        responseID = entry.responseID,
        origin = entry.origin,
        rev = tonumber(entry.rev) or 0,
        updatedAt = tonumber(entry.updatedAt) or 0,
    }
end

SendOrderStatusAcks = function(target, entries)
    local statuses = {}
    local myAccountID = HironCraftScan.DB.settings.my_uuid
    for _, entry in pairs(entries or {}) do
        local pending = type(entry) == 'table' and entry.deliveryPending
        if type(pending) == 'table' and pending[myAccountID] then
            local ack = StatusAck(entry)
            if ack then
                table.insert(statuses, ack)
            end
        end
    end

    if #statuses > 0 then
        HironCraftScanComm:Transmit(
            { statuses = statuses },
            HironCraftScanComm.Operations.OrderStatusAck,
            target
        )
    end
end

local function SendOrderStatusAck(target, entry)
    local ack = StatusAck(entry)
    if ack then
        HironCraftScanComm:Transmit(
            { statuses = { ack } },
            HironCraftScanComm.Operations.OrderStatusAck,
            target
        )
    end
end

SendOrderStatusRepairs = function(target, conflicts)
    if type(conflicts) ~= 'table' or #conflicts == 0 then
        return
    end

    -- One bulk sync may contain many historical conflicts. Repair the newest
    -- distinct rows first and keep this high-priority response small.
    table.sort(conflicts, function(lhs, rhs)
        return (tonumber(lhs.updatedAt) or 0) > (tonumber(rhs.updatedAt) or 0)
    end)
    local repairs = {}
    local seen = {}
    for _, current in ipairs(conflicts) do
        local key = HironCraftScan.OrderToOrderID(current)
        if key and not seen[key] then
            seen[key] = true
            table.insert(repairs, HironCraftScan.Utils.DeepCopy(current))
            if #repairs >= 20 then
                break
            end
        end
    end

    if #repairs > 0 then
        HironCraftScanComm:Transmit(
            { statuses = repairs },
            HironCraftScanComm.Operations.OrderStatusRepair,
            target
        )
    end
end

ReceiveOrderStatuses = function(sender, entries, allowRepair)
    if not HironCraftScan.OrderFulfillment then
        return false
    end

    local changed, accepted, conflicts =
        HironCraftScan.OrderFulfillment:ApplyRemoteStatuses(entries)
    SendOrderStatusAcks(sender, accepted)
    if allowRepair then
        SendOrderStatusRepairs(sender, conflicts)
    end
    return changed
end

local function ReceiveShareOrderStatus(sender, data, senderID)
    if HironCraftScan.OrderFulfillment then
        local _, accepted, current = HironCraftScan.OrderFulfillment:ApplyRemoteStatus(data)
        if accepted then
            SendOrderStatusAck(sender, data)
        elseif current then
            SendOrderStatusRepairs(sender, { current })
        end
    end
end

local function ReceiveOrderStatusAck(sender, data, senderID)
    if type(data) ~= 'table' or type(data.statuses) ~= 'table' then
        return
    end

    local statuses = HironCraftScan.OrderFulfillment and HironCraftScan.OrderFulfillment:GetStatuses()
    if not statuses then
        return
    end

    for _, ack in ipairs(data.statuses) do
        if
            type(ack) == 'table'
            and type(ack.customerName) == 'string'
            and (type(ack.responseID) == 'number' or type(ack.responseID) == 'string')
        then
            local key = HironCraftScan.OrderToOrderID(ack)
            local entry = statuses[key]
            if
                entry
                and entry.origin == ack.origin
                and (tonumber(entry.rev) or 0) == (tonumber(ack.rev) or 0)
                and (tonumber(entry.updatedAt) or 0) == (tonumber(ack.updatedAt) or 0)
                and type(entry.deliveryPending) == 'table'
                and entry.deliveryPending[senderID]
            then
                entry.deliveryPending[senderID] = nil
                if not next(entry.deliveryPending) then
                    entry.deliveryPending = nil
                    entry.deliveryConfirmedAt = time()
                end
                if HironCraftScan.OrderFulfillment.NotifyDeliveryUpdated then
                    HironCraftScan.OrderFulfillment:NotifyDeliveryUpdated(entry)
                end
            end
        end
    end
end

local function SendPendingOrderStatuses(accountID, target)
    if not HironCraftScan.OrderFulfillment then
        return
    end

    local statuses = {}
    local notices = {}
    local count = 0
    local function Flush()
        if count == 0 then
            return
        end
        HironCraftScanComm:Transmit(
            { statuses = statuses, recent = notices },
            HironCraftScanComm.Operations.ShareOrderCompletion,
            target
        )
        statuses = {}
        notices = {}
        count = 0
    end

    local function PendingForAccount(entry)
        return type(entry.deliveryPending) == 'table'
            and entry.deliveryPending[accountID]
    end

    -- Outcomes draw the final green/red mark and matter most to the operator,
    -- so put newest notices at the front of the ALERT queue. Exact state rows
    -- follow, also newest first, instead of relying on undefined pairs order.
    for _, notice in ipairs(NewestOrderEntries(
        HironCraftScan.OrderFulfillment:GetCompletionNotices(),
        nil,
        PendingForAccount
    )) do
        table.insert(notices, HironCraftScan.Utils.DeepCopy(notice))
        count = count + 1
        if count >= PENDING_ORDER_BATCH_LIMIT then
            Flush()
        end
    end

    for _, entry in ipairs(NewestOrderEntries(
        HironCraftScan.OrderFulfillment:GetStatuses(),
        nil,
        PendingForAccount
    )) do
        table.insert(statuses, HironCraftScan.Utils.DeepCopy(entry))
        count = count + 1
        if count >= PENDING_ORDER_BATCH_LIMIT then
            Flush()
        end
    end
    Flush()
end

local function CreateRecentOrderJournal()
    if not HironCraftScan.OrderFulfillment then
        return nil
    end

    local recent = NewestOrderEntries(
        HironCraftScan.OrderFulfillment:GetCompletionNotices(),
        RECENT_ORDER_NOTICE_LIMIT
    )
    local statuses = NewestOrderEntries(
        HironCraftScan.OrderFulfillment:GetStatuses(),
        RECENT_ORDER_STATUS_LIMIT
    )

    return {
        recent = HironCraftScan.Utils.DeepCopy(recent),
        statuses = HironCraftScan.Utils.DeepCopy(statuses),
    }
end

local function SendRecentOrderJournal(target)
    local journal = CreateRecentOrderJournal()
    if not journal or (#journal.recent == 0 and #journal.statuses == 0) then
        return false
    end

    -- Use the completion operation rather than the repair operation here. The
    -- receiver accepts the same journal payload, while ALERT priority lets this
    -- small login replay overtake the much larger BULK character snapshot.
    HironCraftScanComm:Transmit(
        journal,
        HironCraftScanComm.Operations.ShareOrderCompletion,
        target
    )
    return true
end

function HironCraftScanComm:ReplayRecentOrderHistory()
    if not LinkedAccountsConfigured() or not HironCraftScan.OrderFulfillment then
        return false
    end

    local now = GetTime and GetTime() or time()
    if
        lastRecentOrderReplayAt
        and now - lastRecentOrderReplayAt < RECENT_ORDER_REPLAY_THROTTLE_SECONDS
    then
        return false
    end
    lastRecentOrderReplayAt = now

    StartHeartbeat()
    remoteTargets = remoteTargets or {}

    local queued = false
    for accountID, account in pairs(HironCraftScan.DB.realm.linked_accounts) do
        if HironCraftScan.Utils.Contains(account.permissions, HironCraftScanComm.Permissions.Full) then
            -- On a character switch the linked account usually stayed on the
            -- same character. Send the tiny durable journal to that cached
            -- target immediately instead of making the UI wait for discovery.
            -- Discovery still runs in parallel and repairs a stale cached name.
            local cachedTarget = account.last_active_char
            if type(cachedTarget) == 'string' and cachedTarget ~= '' then
                SendRecentOrderJournal(cachedTarget)
                queued = true
            end
            SendPing(accountID, function(_, sender)
                if sender ~= cachedTarget then
                    SendRecentOrderJournal(sender)
                end
            end)
            queued = true
        end
    end
    return queued
end

function HironCraftScanComm:ShareOrderCompletion(notice)
    if not LinkedAccountsConfigured() then
        return
    end
    if HironCraftScanComm.applying_remote_state then
        return
    end

    -- Send only the current result. The durable pending flag and heartbeat ACK
    -- path retry it when needed; replaying the entire recent journal after every
    -- craft caused a steadily growing AceComm BULK queue during rush periods.
    TransmitToFullLinkedAccounts(notice, HironCraftScanComm.Operations.ShareOrderCompletion)
end


local function CompletionAck(notice)
    if
        type(notice) ~= 'table'
        or type(notice.customerName) ~= 'string'
        or not notice.updatedAt
    then
        return nil
    end

    return {
        orderID = notice.orderID,
        customerName = notice.customerName,
        spellID = notice.spellID,
        itemID = notice.itemID,
        status = notice.status,
        origin = notice.origin,
        updatedAt = notice.updatedAt,
    }
end

local function SendOrderCompletionAcks(target, notices)
    local acknowledgements = {}
    local myAccountID = HironCraftScan.DB.settings.my_uuid
    for _, notice in pairs(notices or {}) do
        local pending = type(notice) == 'table' and notice.deliveryPending
        if type(pending) == 'table' and pending[myAccountID] then
            local ack = CompletionAck(notice)
            if ack then
                table.insert(acknowledgements, ack)
            end
        end
    end

    if #acknowledgements > 0 then
        HironCraftScanComm:Transmit(
            { notices = acknowledgements },
            HironCraftScanComm.Operations.OrderCompletionAck,
            target
        )
    end
end


local function ReceiveOrderCompletionAck(sender, data, senderID)
    if
        type(data) ~= 'table'
        or type(data.notices) ~= 'table'
        or not HironCraftScan.OrderFulfillment
    then
        return
    end

    for _, ack in ipairs(data.notices) do
        HironCraftScan.OrderFulfillment:AcknowledgeCompletion(ack, senderID)
    end
end


function HironCraftScanComm:ShareOrderOutcome(notice)
    if not LinkedAccountsConfigured() or HironCraftScanComm.applying_remote_state then
        return
    end

    TransmitToFullLinkedAccounts(
        notice,
        HironCraftScanComm.Operations.ShareOrderOutcome
    )
end

local function ReceiveShareOrderCompletion(sender, data, senderID)
    if not HironCraftScan.OrderFulfillment then
        return
    end

    local receivedNotices = {}
    if type(data) == 'table' and (data.notice or data.recent or data.statuses) then
        if data.statuses then
            ReceiveOrderStatuses(sender, data.statuses, true)
        end
        if type(data.recent) == 'table' then
            HironCraftScan.OrderFulfillment:ApplyRemoteCompletionNotices(data.recent)
            for _, notice in pairs(data.recent) do
                table.insert(receivedNotices, notice)
            end
        end
        if type(data.notice) == 'table' then
            HironCraftScan.OrderFulfillment:ApplyRemoteCompletion(data.notice)
            table.insert(receivedNotices, data.notice)
        end
    elseif type(data) == 'table' then
        HironCraftScan.OrderFulfillment:ApplyRemoteCompletion(data)
        table.insert(receivedNotices, data)
    end
    SendOrderCompletionAcks(sender, receivedNotices)
end

local todosByAccount = {}
local heartbeatStarted = false
local function PingTargets(targetAccountID, characters)
    if not characters or not next(characters) then
        return
    end

    HironCraftScanComm:Transmit(
        { state = SharingState.InitialInquiry },
        HironCraftScanComm.Operations.Ping,
        { [targetAccountID] = characters }
    )
end

local function AddAccountDiscoveryCandidates(targetAccountID, account, candidates, excluded)
    local function AddCandidate(character)
        if type(character) == 'string' and character ~= '' and character ~= excluded then
            candidates[character] = true
        end
    end

    -- backup_chars contains characters that have spoken to us directly. It is
    -- the best source for non-crafting alts and for fresh links that have not
    -- completed a full profession sync yet.
    for _, character in ipairs(account.backup_chars or {}) do
        AddCandidate(character)
    end

    -- A linked account can change to any of its synced crafters. The optimized
    -- discovery path used to omit these names and could therefore stay pinned
    -- to the character used for linking. Probe them with the tiny Ping payload;
    -- the full login snapshot is still sent only to the character that replies.
    for character, characterConfig in pairs(HironCraftScan.DB.characters or {}) do
        if type(characterConfig) == 'table' and characterConfig.sourceID == targetAccountID then
            AddCandidate(character)
        end
    end
end

SendPing = function(targetAccountID, todo)
    -- This is a lightweight check to see who on the other account is online
    -- before we do a more heavy weight send. We don't want to try to send a
    -- huge payload to a bunch of characters to find out none of them are
    -- online.
    local account = (HironCraftScan.DB.realm.linked_accounts or {})[targetAccountID]
    if not account then
        return
    end

    local todos = todosByAccount[targetAccountID]
    if todos then
        -- One discovery is already running. Reuse its result instead of
        -- sending another set of pings.
        if todo then
            table.insert(todos, todo)
        end
        return
    end

    todos = {}
    todosByAccount[targetAccountID] = todos
    if todo then
        table.insert(todos, todo)
    end

    -- A ping to an offline character has no response event. Release a pure
    -- heartbeat attempt so the next tick can try again; retain and retry real
    -- queued work until an account comes back online.
    if C_Timer and C_Timer.After then
        C_Timer.After(PING_ATTEMPT_TIMEOUT_SECONDS, function()
            if todosByAccount[targetAccountID] ~= todos then
                return
            end

            todosByAccount[targetAccountID] = nil
            for _, pendingTodo in ipairs(todos) do
                SendPing(targetAccountID, pendingTodo)
            end
        end)
    end

    -- Existing installations do not have last_active_char yet. The first
    -- backup entry is the character used to create the link, so it is the best
    -- one-shot migration candidate and still gets the normal fallback below.
    local preferred = account.last_active_char or (account.backup_chars and account.backup_chars[1])
    if preferred then
        PingTargets(targetAccountID, { [preferred] = true })

        -- If the other account changed characters while we were offline, fall
        -- back to one small ping per remaining known character. Never send the
        -- large synchronization snapshot to these candidates.
        if C_Timer and C_Timer.After then
            C_Timer.After(1, function()
                if todosByAccount[targetAccountID] ~= todos then
                    return
                end

                local fallback = {}
                AddAccountDiscoveryCandidates(targetAccountID, account, fallback, preferred)
                PingTargets(targetAccountID, fallback)
            end)
        end
    else
        local candidates = {}
        AddAccountDiscoveryCandidates(targetAccountID, account, candidates)
        PingTargets(targetAccountID, candidates)
    end
end

StartHeartbeat = function()
    if heartbeatStarted or not C_Timer or not C_Timer.After then
        return
    end
    heartbeatStarted = true

    local function Tick()
        if not LinkedAccountsConfigured() then
            heartbeatStarted = false
            return
        end

        for accountID, account in pairs(HironCraftScan.DB.realm.linked_accounts) do
            local hasFull = HironCraftScan.Utils.Contains(
                account.permissions,
                HironCraftScanComm.Permissions.Full
            )
            local hasAnalytics = HironCraftScan.Utils.Contains(
                account.permissions,
                HironCraftScanComm.Permissions.Analytics
            )
            if hasFull or hasAnalytics then
                SendPing(accountID)
            end
        end
        C_Timer.After(HEARTBEAT_SECONDS, Tick)
    end

    C_Timer.After(HEARTBEAT_SECONDS, Tick)
end

local function ReceivePing(sender, data, senderID)
    if data.state == SharingState.InitialInquiry then
        HironCraftScanComm:Transmit(
            { state = SharingState.ResponseInquiry },
            HironCraftScanComm.Operations.Ping,
            sender
        )
    else
        local todos = todosByAccount[senderID]
        if not todos then
            return
        end
        todosByAccount[senderID] = nil
        for _, todo in ipairs(todos) do
            todo(senderID, sender)
        end
        -- A response proves which character currently represents the linked
        -- account. Flush its complete pending order state even when this ping
        -- also carried another callback, so discoveries cannot strand updates.
        local account = HironCraftScan.DB.realm.linked_accounts[senderID]
        if
            account
            and HironCraftScan.Utils.Contains(
                account.permissions,
                HironCraftScanComm.Permissions.Full
            )
        then
            SendPendingOrderStatuses(senderID, sender)
        end
    end
end

local function ShareAnalytics_(senderID, sender, state, sinceLastUpdate)
    local analytics = HironCraftScan.DB.analytics
    local lastShare = HironCraftScan.DB.realm.linked_accounts[senderID].last_analytics_share

    HironCraftScan.Utils.printTable(
        'ShareAnalytics_ Account',
        HironCraftScan.DB.realm.linked_accounts[senderID]
    )

    if sinceLastUpdate and lastShare then
        -- Copy the analytics table, then filter the 'times' lists to be more
        -- recent than the last sharing time.
        local allAnalytics = analytics
        analytics = { seen_items = {} }
        local dst = analytics.seen_items
        local src = allAnalytics.seen_items
        if src then
            for itemID, srcEntry in pairs(src) do
                local times = {}
                for _, t in ipairs(srcEntry.times) do
                    if HironCraftScan.Analytics.GetTimeStamp(t) > lastShare then
                        table.insert(times, t)
                    end
                end
                if #times ~= 0 then
                    dst[itemID] = {}
                    dstEntry = dst[itemID]
                    for key, value in pairs(srcEntry) do
                        if key ~= 'times' then
                            dstEntry[key] = value
                        end
                    end
                    dst[itemID].times = times
                end
            end
        end
    end

    HironCraftScanComm:Transmit(
        { analytics = analytics, state = state, recent = sinceLastUpdate },
        HironCraftScanComm.Operations.ShareAnalytics,
        sender
    )
end

local function MergeTimes(myTimes, otherTimes)
    local GetTime = HironCraftScan.Analytics.GetTimeStamp
    local i, j = 1, 1
    local merged = {}
    local merging = false
    while i <= #myTimes and j <= #otherTimes do
        local myTime = GetTime(myTimes[i])
        local otherTime = GetTime(otherTimes[j])
        if myTime == otherTime then
            local myTable = type(myTimes[i]) == 'table'
            local otherTable = type(otherTimes[j]) == 'table'
            if myTable and otherTable then
                -- If both sides saw repeats, take the max. We
                -- assume they were both watching, but one of them
                -- stayed online longer and saw more repeats.
                myTimes[i].c = math.max(myTimes[i].c or 1, otherTimes[j].c or 1)
            elseif otherTable then
                myTimes[i] = otherTimes[j]
            end

            if merging then
                table.insert(merged, myTimes[i])
            end
            i = i + 1
            j = j + 1
        elseif myTime < otherTime then
            if merging then
                table.insert(merged, myTimes[i])
            end
            i = i + 1
        else
            assert(myTime > otherTime)

            -- The other side has an entry that needs to go before our next
            -- entry, so time to copy and start merge inserting.
            if not merging then
                merging = true
                for copyI = 1, i - 1, 1 do
                    table.insert(merged, myTimes[copyI])
                end
            end

            table.insert(merged, otherTimes[j])
            j = j + 1
        end
    end

    if merging then
        while i <= #myTimes do
            table.insert(merged, myTimes[i])
            i = i + 1
        end
    end
    while j <= #otherTimes do
        if merging then
            table.insert(merged, otherTimes[j])
        else
            table.insert(myTimes, otherTimes[j])
        end
        j = j + 1
    end

    assert(merging or #merged == 0)
    return merging, merging and merged or myTimes
end

HironCraftScan.Utils.onLoad(function()
    if not HironCraftScan.Debug.IsEnabled() then
        return
    end

    function TestCase(index, myTimes, otherTimes, expectedMerged, expected)
        local merged, times = MergeTimes(myTimes, otherTimes)
        local failed = false
        if merged ~= expectedMerged then
            failed = true
        end
        if not merged and times ~= myTimes then
            failed = true
        end
        if #times ~= #expected then
            failed = true
        end
        for i, e in ipairs(expected) do
            if type(times[i]) == 'table' then
                if type(e) ~= 'table' then
                    failed = true
                end
                if times[i].t ~= e.t then
                    failed = true
                end
                if times[i].c ~= e.c then
                    failed = true
                end
            elseif times[i] ~= e then
                failed = true
            end
        end
        if failed then
            HironCraftScan.Utils.printTable('Failed Testcase Output', {
                index = index,
                merged = merged,
                expectedMerged = expectedMerged,
                times = times,
                expected = expected,
            })
            assert(not failed)
        end
    end

    -- Basic equal
    TestCase(1, { 1, 2, 3 }, { 1, 2, 3 }, false, { 1, 2, 3 })
    -- mine longer
    TestCase(2, { 1, 2, 3, 4 }, { 1, 2, 3 }, false, { 1, 2, 3, 4 })
    -- other longer
    TestCase(3, { 1, 2, 3 }, { 1, 2, 3, 4 }, false, { 1, 2, 3, 4 })
    -- other has a hole
    TestCase(4, { 1, 2, 3 }, { 1, 3, 4 }, false, { 1, 2, 3, 4 })
    -- Merges needed, other longer
    TestCase(5, { 1, 4 }, { 1, 2, 3 }, true, { 1, 2, 3, 4 })
    -- Merges needed, mine longer
    TestCase(6, { 11, 14, 15 }, { 11, 12, 13 }, true, { 11, 12, 13, 14, 15 })

    -- Mixed formats
    TestCase(7, { { t = 1 }, 9, 12 }, { 1, 2, { t = 5 } }, true, { { t = 1 }, 2, { t = 5 }, 9, 12 })
    TestCase(8, { { t = 1, c = 2 } }, { 1, 2 }, false, { { t = 1, c = 2 }, 2 })
    TestCase(8, { { t = 1, c = 2 } }, { { t = 1, c = 5 }, 2 }, false, { { t = 1, c = 5 }, 2 })
    TestCase(9, { 1 }, { { t = 1, c = 5 }, 2 }, false, { { t = 1, c = 5 }, 2 })
    TestCase(10, { 1, 3, 5 }, { 2, { t = 5, c = 5 } }, true, { 1, 2, 3, { t = 5, c = 5 } })
    TestCase(11, { 1, 3, { t = 5, c = 5 } }, { 2, 5 }, true, { 1, 2, 3, { t = 5, c = 5 } })
    TestCase(12, { 1, 3, { t = 5, c = 5 } }, { 2 }, true, { 1, 2, 3, { t = 5, c = 5 } })
    TestCase(12, { 1, 3 }, { 2, { t = 5, c = 5 } }, true, { 1, 2, 3, { t = 5, c = 5 } })
end)

local function ReceiveShareAnalytics(sender, data, senderID)
    if data.state == SharingState.InitialInquiry then
        ShareAnalytics_(senderID, sender, SharingState.ResponseInquiry, data.recent)
    end

    local function OnExitUpdate()
        HironCraftScan.DB.realm.linked_accounts[senderID].last_analytics_share = time()
        HironCraftScanCraftingOrderPage:UpdateAnalytics()
    end

    -- Our share analytics implementation is a merge. Any time stamps present on
    -- both sides are left in place and treated as being the same entry. If one
    -- side has an entry the other doesn't, it is merged into the collection at
    -- the right spot. To avoid terrible performance, once we need to start
    -- merging, we copy over all recent data and start appending to a new list
    -- to replace the list rather than inserting in the middle of the list.
    local other = data.analytics.seen_items
    local mine = HironCraftScan.DB.analytics.seen_items
    if not mine then
        HironCraftScan.DB.analytics.seen_items = other
        OnExitUpdate()
        return
    end
    if not other then
        return
    end

    for itemID, otherItem in pairs(other) do
        local myItem = mine[itemID]
        if not myItem then
            mine[itemID] = otherItem
        else
            -- If one side has identified the profession, accept it if we have
            -- not yet. If there's a difference, we leave our value in place and
            -- spit out a message about it.
            if otherItem.ppID then
                if not myItem.ppID then
                    myItem.ppID = otherItem.ppID
                elseif otherItem.ppID ~= myItem.ppID then
                    item = Item:CreateFromItemID(itemID)
                    item:ContinueOnItemLoad(function()
                        local myProf = HironCraftScan.Utils.ColorizedProfessionNameByID(myItem.ppID)
                        local otherProf =
                            HironCraftScan.Utils.ColorizedProfessionNameByID(otherItem.ppID)
                        print(
                            string.format(
                                L(LID.ANALYTICS_PROF_MISMATCH),
                                item:GetItemLink(),
                                myProf,
                                otherProf
                            )
                        )
                    end)
                end
            end

            local myTimes = myItem.times
            local otherTimes = otherItem.times
            local merged, times = MergeTimes(myTimes, otherTimes)
            if merged then
                myItem.times = times
            else
                assert(myTimes == times)
            end
        end
    end

    OnExitUpdate()
end

function HironCraftScanComm:ShareAnalytics(targetAccountID, sinceLastUpdate)
    SendPing(targetAccountID, function(senderID, sender)
        ShareAnalytics_(targetAccountID, sender, SharingState.InitialInquiry, sinceLastUpdate)
    end)
end

local function MakeUUID()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

local function InitMyUUID()
    if not HironCraftScan.DB.settings.my_uuid then
        local random = math.random
        local myUuid = MakeUUID()
        HironCraftScan.DB.settings.my_uuid = myUuid
        for char, charConfig in pairs(HironCraftScan.DB.characters) do
            charConfig.sourceID = myUuid
        end
    end
end

function HironCraftScanComm:SendHandshake(target, nickname, permissions)
    HironCraftScan.pending_peer_accept = {
        character = target,
        nickname = nickname,
        permissions = permissions,
    }

    InitMyUUID()
    HironCraftScanComm:Transmit({
        remoteID = HironCraftScan.DB.settings.my_uuid,
        version = HironCraftScan.CONST.CURRENT_VERSION,
        permissions = permissions,
    }, HironCraftScanComm.Operations.Handshake, target)
end

HironCraftScanComm.Result = {
    OK = 1,
    VersionMismatch = 1,
    UserDenied = 2,
}

local function GetRejectionMessage(result, data)
    if result == HironCraftScanComm.Result.VersionMismatch then
        return string.format(L(LID.VERSION_MISMATCH), data, HironCraftScan.CONST.CURRENT_VERSION)
    end
    if result == HironCraftScanComm.Result.UserDenied then
        return L(LID.LINKED_ACCOUNT_USER_REJECTED)
    end

    return 'Received unknown error code: ' .. result .. '. Argument: ' .. (data or 'none')
end

local function AcceptPeerRequest_(pending)
    local linkedAccounts = saved(HironCraftScan.DB.realm, 'linked_accounts', {})
    linkedAccounts[pending.remoteID] = {
        nickname = pending.nickname,
        backup_chars = { pending.character },
        permissions = pending.permissions,
    }

    if not remoteTargets then
        -- If this is the first time we're linking to anyone, we didn't
        -- initialize remoteTargets. We know who we're talking to already, so we
        -- can fully initialize it.
        remoteTargets = {
            [pending.remoteID] = { [pending.character] = time() },
        }
    end

    if not HironCraftScan.Utils.Contains(pending.permissions, HironCraftScanComm.Permissions.Full) then
        -- In case we're changing permissions to not include full, wipe out any
        -- remote characters.
        for char, charConfig in pairs(HironCraftScan.DB.characters) do
            if charConfig.sourceID == pending.remoteID then
                HironCraftScan.DB.characters[char] = nil
            end
        end
        HironCraftScan.OnCrafterListModified()
    end

    HironCraftScan.Utils.printTable('linkedAccounts:', linkedAccounts)
    StartHeartbeat()
end

local function ReceiveHandshake(sender, data)
    if data.result then
        if data.result == HironCraftScanComm.Result.OK then
            HironCraftScan.pending_peer_accept.remoteID = data.result_data.remoteID
            AcceptPeerRequest_(HironCraftScan.pending_peer_accept)
            HironCraftScan.pending_peer_accept = nil
            HironCraftScan.OnPendingPeerAccepted()

            -- Now that we know about the peer, kick off the initial sharing, which is
            -- necessary to identify some characters on the other side so we can use
            -- them to stay in sync.
            ShareCharacterData_(SharingState.InitialInquiry, sender)
        else
            print(
                string.format(
                    L(LID.LINKED_ACCOUNT_REJECTED),
                    GetRejectionMessage(data.result, data.result_data)
                )
            )
        end
        return
    end

    if data.version ~= HironCraftScan.CONST.CURRENT_VERSION then
        HironCraftScanComm:Transmit({
            result = HironCraftScanComm.Result.VersionMismatch,
            result_data = HironCraftScan.CONST.CURRENT_VERSION,
        }, HironCraftScanComm.Operations.Handshake, sender)
        return
    end

    HironCraftScan.pending_peer_request = {
        remoteID = data.remoteID,
        character = sender,
        permissions = data.permissions,
    }
    HironCraftScan.OnPendingPeerAdded()
end

function HironCraftScanComm:HavePendingPeerRequest()
    return HironCraftScan.pending_peer_request ~= nil
end

function HironCraftScanComm:GetPendingPeerRequestCharacter()
    return HironCraftScan.pending_peer_request.character
end

function HironCraftScanComm:GetPendingPeerRequestPermissions()
    local perms = HironCraftScan.pending_peer_request.permissions

    -- Very inefficient, but rarely used.
    local result = {}
    for _, perm in ipairs(perms) do
        local strings = HironCraftScanComm.PermissionStrings[perm]
        table.insert(result, L(strings.name) .. ' (' .. L(strings.desc) .. ')')
    end
    return table.concat(result, '\n')
end

function HironCraftScanComm:AcceptPeerRequest(nickname)
    HironCraftScan.pending_peer_request.nickname = nickname
    AcceptPeerRequest_(HironCraftScan.pending_peer_request)

    InitMyUUID()
    HironCraftScanComm:Transmit({
        result = HironCraftScanComm.Result.OK,
        result_data = {
            remoteID = HironCraftScan.DB.settings.my_uuid,
        },
    }, HironCraftScanComm.Operations.Handshake, HironCraftScan.pending_peer_request.character)

    HironCraftScan.pending_peer_request = nil
    HironCraftScan.OnPendingPeerAccepted()
end

function HironCraftScanComm:RejectPeerRequest()
    HironCraftScanComm:Transmit(
        { result = HironCraftScanComm.Result.UserDenied },
        HironCraftScanComm.Operations.Handshake,
        HironCraftScan.pending_peer_request.character
    )

    HironCraftScan.pending_peer_request = nil
end

function HironCraftScanComm:FindCrafters(itemID)
    HironCraftScanComm:Transmit(
        { i = itemID, cg = UnitGUID('player') },
        HironCraftScanComm.Operations.FindCrafter,
        TARGET_BROADCAST
    )
end

local function ReceiveFindCrafter(sender, data)
    if IsResting() or HironCraftScan.State.isBusy then
        if data.i and not data.c then
            if not HironCraftScan.DB.settings.discoverable then
                return
            end
            HironCraftScan.OnMessage('CHAT_MSG_CHANNEL', '', sender, data.cg, {
                itemInfo = function()
                    return true, nil, data.i
                end,
                resultCallback = function(crafter, greeting, commission)
                    HironCraftScanComm:Transmit(
                        -- TODO: Idle timer?
                        {
                            i = data.i,
                            c = crafter,
                            g = greeting,
                            b = HironCraftScan.State.isBusy,
                            co = commission,
                        },
                        HironCraftScanComm.Operations.FindCrafter,
                        sender
                    )
                end,
            })
        elseif data.i and data.c and data.g then
            HironCraftScan.SearchResultsReceived(data.i, sender, data.c, data.g, data.b, data.co)
        end
    end
end

local function CreateRequestCraftGreeting(itemID, OnReady)
    local item = Item:CreateFromItemID(itemID)
    item:ContinueOnItemLoad(function()
        OnReady(string.format(L(LID.FOUND_VIA_HIRONCRAFT_SCAN), item:GetItemLink()))
    end)
end

function HironCraftScanComm:RequestCraft(target, itemID)
    -- Start by simply sending the message that we want something crafted.
    CreateRequestCraftGreeting(itemID, function(message)
        SendChatMessage(message, 'WHISPER', select(2, GetDefaultLanguage()), target)

        -- Also inject that message into the crafter's list since we aren't always
        -- setup to listen for whispers.
        HironCraftScanComm:Transmit(
            { i = itemID, g = UnitGUID('player') },
            HironCraftScanComm.Operations.RequestCraft,
            target
        )
    end)
end

local function ReceiveRequestCraft(sender, data)
    if data.i then
        local itemID = data.i

        -- Would be nice to be '.cg', since .g is also used for greeting in this
        -- flow, but that would create a mixed version problem, so just living
        -- with it.
        local customerGUID = data.g
        CreateRequestCraftGreeting(itemID, function(message)
            HironCraftScan.OnMessage('CHAT_MSG_CHANNEL', message, sender, customerGUID, {
                itemInfo = function()
                    return true, nil, itemID
                end,
                greeted = true,
            })
        end)
    end
end

local function SendMessage(encoded, target, priority)
    HironCraftScanComm:SendCommMessage(
        HIRONCRAFT_SCAN_COMM_PREFIX,
        encoded,
        'WHISPER',
        target,
        priority
    )
end

local ALERT_OPERATIONS = {
    [HironCraftScanComm.Operations.Handshake] = true,
    [HironCraftScanComm.Operations.ShareCustomerOrder] = true,
    [HironCraftScanComm.Operations.ShareCustomerChat] = true,
    [HironCraftScanComm.Operations.ShareOrderStatus] = true,
    [HironCraftScanComm.Operations.OrderStatusAck] = true,
    [HironCraftScanComm.Operations.OrderStatusRepair] = true,
    [HironCraftScanComm.Operations.ShareOrderCompletion] = true,
    [HironCraftScanComm.Operations.OrderCompletionAck] = true,
    [HironCraftScanComm.Operations.ShareOrderOutcome] = true,
    [HironCraftScanComm.Operations.Ping] = true,
    [HironCraftScanComm.Operations.RequestCraft] = true,
}

local BULK_OPERATIONS = {
    [HironCraftScanComm.Operations.ShareCharacterData] = true,
    [HironCraftScanComm.Operations.ShareOrderCompletionRepair] = true,
    [HironCraftScanComm.Operations.ShareAnalytics] = true,
}

local function PriorityForOperation(operation)
    if ALERT_OPERATIONS[operation] then
        return 'ALERT'
    end
    if BULK_OPERATIONS[operation] then
        return 'BULK'
    end
    return 'NORMAL'
end

-- There is weirdly no way to test if a player is online. Originally, we tested
-- if characters were online by the lack of an error message when sending a
-- message. Unfortunately, it seems that at least in Aug 2024, you can
-- successfully send messages to your own characters that have been offline for
-- hours, so that test is out the window. The solution is actually better
-- though. Since we always ping around the latest information on login, and we
-- know only one character per account can be logged in, we can group our
-- characters by account and know that the last one that sent us a message is
-- the one that is online. If that one doesn't work any more, that's fine - when
-- another logs in, it will tell us and we'll save that. The only time we need
-- to ping multiple remote targets is on login when we are announcing ourselves
-- and waiting for replies.
local OFFLINE_FILTER_TTL_SECONDS = 180
local offlineExactMessages = {}
local offlineTargetNames = {}
local offlineFilterInstalled = false

local function EscapeLuaPattern(text)
    return (text:gsub('(%W)', '%%%1'))
end

local function MissingPlayerName(message)
    if type(message) ~= 'string' or type(ERR_CHAT_PLAYER_NOT_FOUND_S) ~= 'string' then
        return nil
    end

    local prefix, suffix = ERR_CHAT_PLAYER_NOT_FOUND_S:match('^(.-)%%s(.-)$')
    if not prefix then
        return nil
    end
    return message:match(
        '^' .. EscapeLuaPattern(prefix) .. '(.-)' .. EscapeLuaPattern(suffix) .. '$'
    )
end

local function BaseCharacterName(name)
    if type(name) ~= 'string' then
        return nil
    end
    return (name:match('^([^-]+)') or name):lower()
end

local function OfflineMessageFilter(_, _, msg)
    local now = GetTime and GetTime() or time()
    local exactExpiry = offlineExactMessages[msg]
    if exactExpiry then
        if exactExpiry >= now then
            return true
        end
        offlineExactMessages[msg] = nil
    end

    -- Blizzard can independently strip the realm from a whisper target on
    -- connected realms. Match the localized error's player field as fallback.
    local missingName = BaseCharacterName(MissingPlayerName(msg))
    local nameExpiry = missingName and offlineTargetNames[missingName]
    if nameExpiry then
        if nameExpiry >= now then
            return true
        end
        offlineTargetNames[missingName] = nil
    end
end

local function RegisterOfflineTargets(targets)
    local now = GetTime and GetTime() or time()
    local expiry = now + OFFLINE_FILTER_TTL_SECONDS

    if not offlineFilterInstalled then
        ChatFrame_AddMessageEventFilter('CHAT_MSG_SYSTEM', OfflineMessageFilter)
        offlineFilterInstalled = true
    end

    for message, messageExpiry in pairs(offlineExactMessages) do
        if messageExpiry < now then
            offlineExactMessages[message] = nil
        end
    end
    for name, nameExpiry in pairs(offlineTargetNames) do
        if nameExpiry < now then
            offlineTargetNames[name] = nil
        end
    end

    for _, accountTargets in pairs(targets) do
        for target in pairs(accountTargets) do
            local baseName = BaseCharacterName(target)
            if baseName then
                offlineTargetNames[baseName] = expiry
            end
            if type(ERR_CHAT_PLAYER_NOT_FOUND_S) == 'string' then
                offlineExactMessages[ERR_CHAT_PLAYER_NOT_FOUND_S:gsub('%%s', target)] = expiry
                local shortTarget = target:match('^([^-]+)') or target
                offlineExactMessages[ERR_CHAT_PLAYER_NOT_FOUND_S:gsub('%%s', shortTarget)] = expiry
            end
        end
    end
end

local function TransmitSerialized(serialized, target, priority)
    local compressed = LibDeflate:CompressDeflate(serialized)
    local encoded = LibDeflate:EncodeForWoWAddonChannel(compressed)

    if target == TARGET_BROADCAST then
        local channelNumber = GetChannelName(broadcastChannel)
        HironCraftScanComm:SendCommMessage(
            HIRONCRAFT_SCAN_COMM_PREFIX,
            encoded,
            'CHANNEL',
            channelNumber,
            priority
        )
        return
    end

    -- In responses, we're given an explicit character to send to, so we use it.
    -- Otherwise, generate a list of tarets based on our linked accounts. The
    -- offline message filter will hopefully be able to narrow that down to a
    -- character we already communicated with first so we don't have to send to
    -- every character every time.
    local targets = {}
    if target then
        if type(target) ~= 'table' then
            table.insert(targets, { [target] = true })
        else
            targets = target
        end
    else
        if not remoteTargets then
            targets = CreateInitialTargets()
            remoteTargets = {}
        else
            targets = remoteTargets
        end
    end

    HironCraftScan.Utils.printTable('targets', targets)

    RegisterOfflineTargets(targets)

    for _, accountTargets in pairs(targets) do
        for target, _ in pairs(accountTargets) do
            HironCraftScan.Utils.printTable('Sending request to', target)
            SendMessage(encoded, target, priority)
        end
    end

end

local function IsPublicOperation(op)
    return HironCraftScanComm.Operations.FindCrafter == op or HironCraftScanComm.Operations.RequestCraft == op
end

local asyncPool = CreateFramePool('Frame', UIParent)

function HironCraftScanComm:Transmit(data, operation, target)
    local msg = {
        operation = operation,
        version = HironCraftScan.CONST.CURRENT_VERSION,
        data = data,
    }

    if not IsPublicOperation(operation) then
        msg.senderID = HironCraftScan.DB.settings.my_uuid
    end

    HironCraftScan.Utils.printTable('Sending msg', msg)

    local priority = PriorityForOperation(operation)
    if priority == 'ALERT' then
        -- Critical order updates are small. Serialize them immediately so the
        -- addon queues the whisper in the same frame as the fulfillment event;
        -- an instant logout can otherwise happen before SerializeAsync gets its
        -- first OnUpdate callback.
        TransmitSerialized(LibSerialize:Serialize(msg), target, priority)
        return
    end

    local handler = LibSerialize:SerializeAsync(msg)

    local processing = asyncPool:Acquire()
    processing:SetScript('OnUpdate', function()
        local completed, serialized = handler()
        if completed then
            processing:SetScript('OnUpdate', nil)
            asyncPool:Release(processing)
            TransmitSerialized(serialized, target, priority)
        end
    end)

    -- OnUpdate won't fire if the frame is hidden, which is is by default when
    -- fetched from the pool.
    processing:Show()
end

local function ReceiveRemoteTarget(senderID, sender)
    remoteTargets[senderID] = { [sender] = time() }
    local linkedAccount = HironCraftScan.DB.realm.linked_accounts[senderID]
    linkedAccount.last_active_char = sender
    HironCraftScan.OnLinkedAccountStateChange()

    -- TODO: Connected realms - does sender come with the realm name?
    --local nameAndRealm = sender .. "-" .. GetRealmName();

    -- Every character that has answered is a valid account endpoint. Persist
    -- crafters as well as non-crafting alts so future logins can discover the
    -- account after either side changes character.
    linkedAccount.backup_chars = linkedAccount.backup_chars or {}
    local backupChars = linkedAccount.backup_chars
    if not HironCraftScan.Utils.Contains(backupChars, sender) then
        table.insert(backupChars, sender)
        HironCraftScan.Utils.printTable('Updated backupChars', backupChars)
    end

    HironCraftScan.Utils.printTable('Updated remoteTargets', remoteTargets)
end

local function ReceiveDeserialized(msg, sender)
    HironCraftScan.Utils.printTable('Received msg', msg)

    if msg.operation == HironCraftScanComm.Operations.Handshake then
        ReceiveHandshake(sender, msg.data)
    else
        if msg.version ~= HironCraftScan.CONST.CURRENT_VERSION then
            if
                not IsPublicOperation(msg.operation)
                or HironCraftScan.IsRemoteVersionMoreRecent(msg.version)
            then
                print(
                    string.format(
                        L(LID.VERSION_MISMATCH),
                        msg.version,
                        HironCraftScan.CONST.CURRENT_VERSION
                    )
                )
            end
            return
        end

        if msg.operation == HironCraftScanComm.Operations.FindCrafter then
            ReceiveFindCrafter(sender, msg.data)
            return
        elseif msg.operation == HironCraftScanComm.Operations.RequestCraft then
            ReceiveRequestCraft(sender, msg.data)
            return
        end

        local linkedAccounts = HironCraftScan.DB.realm.linked_accounts
        if not linkedAccounts or not linkedAccounts[msg.senderID] then
            HironCraftScan.Utils.printTable('Ignoring message from unknown account.', msg.senderID)
            return
        end

        local linkedAccount = linkedAccounts[msg.senderID]
        local hasFull =
            HironCraftScan.Utils.Contains(linkedAccount.permissions, HironCraftScanComm.Permissions.Full)
        local hasAnalytics =
            HironCraftScan.Utils.Contains(linkedAccount.permissions, HironCraftScanComm.Permissions.Analytics)

        remoteTargets = remoteTargets or {}
        ReceiveRemoteTarget(msg.senderID, sender)

        if msg.operation == HironCraftScanComm.Operations.Ping then
            ReceivePing(sender, msg.data, msg.senderID)
        elseif hasFull and msg.operation == HironCraftScanComm.Operations.ShareCharacterData then
            ReceiveShareCharacterData(sender, msg.data, msg.senderID)
        elseif hasFull and msg.operation == HironCraftScanComm.Operations.ShareCustomerOrder then
            ReceiveShareCustomerOrder(sender, msg.data, msg.senderID)
        elseif hasFull and msg.operation == HironCraftScanComm.Operations.ShareCustomerChat then
            ReceiveShareCustomerChat(sender, msg.data, msg.senderID)
        elseif hasFull and msg.operation == HironCraftScanComm.Operations.ShareCustomGreeting then
            ReceiveShareCustomGreeting(sender, msg.data, msg.senderID)
        elseif hasFull and msg.operation == HironCraftScanComm.Operations.ShareCustomExplanations then
            ReceiveShareCustomExplanations(sender, msg.data, msg.senderID)
        elseif hasFull and msg.operation == HironCraftScanComm.Operations.ShareQuickReplies then
            ReceiveShareQuickReplies(sender, msg.data, msg.senderID)
        elseif hasFull and msg.operation == HironCraftScanComm.Operations.ShareOrderStatus then
            ReceiveShareOrderStatus(sender, msg.data, msg.senderID)
        elseif hasFull and msg.operation == HironCraftScanComm.Operations.OrderStatusAck then
            ReceiveOrderStatusAck(sender, msg.data, msg.senderID)
        elseif hasFull and msg.operation == HironCraftScanComm.Operations.OrderStatusRepair then
            ReceiveOrderStatuses(sender, msg.data and msg.data.statuses, false)
        elseif hasFull and msg.operation == HironCraftScanComm.Operations.ShareOrderCompletion then
            ReceiveShareOrderCompletion(sender, msg.data, msg.senderID)
        elseif hasFull and msg.operation == HironCraftScanComm.Operations.OrderCompletionAck then
            ReceiveOrderCompletionAck(sender, msg.data, msg.senderID)
        elseif hasFull and msg.operation == HironCraftScanComm.Operations.ShareOrderOutcome then
            ReceiveShareOrderCompletion(sender, msg.data, msg.senderID)
        elseif
            hasFull
            and msg.operation == HironCraftScanComm.Operations.ShareOrderCompletionRepair
        then
            ReceiveShareOrderCompletion(sender, msg.data, msg.senderID)
        elseif
            (hasFull or hasAnalytics)
            and msg.operation == HironCraftScanComm.Operations.ShareAnalytics
        then
            ReceiveShareAnalytics(sender, msg.data, msg.senderID)
        end
    end
end

function HironCraftScanComm:OnCommReceived(prefix, payload, distribution, sender)
    if issecretvalue(payload) then return end

    HironCraftScan.Utils.printTable('Received from', sender)
    HironCraftScan.Utils.printTable('distribution', distribution)
    if not HironCraftScan.State.realmID or string.find(sender, '-') == nil then
        -- We're not on a connected realm, so hardcode the sender's realm to our
        -- own. I'm hitting some weird cases where my chat auto-completes the
        -- character name to a character of mine by the same name on a different
        -- realm. On connected realms, we just have to hope the infra puts the
        -- realm in the sender name already, which it seems to.
        --
        -- Even on connected realms, it seems that the sender realm is erased if
        -- it's the same realm, and then we can't even send a reply, so we also
        -- check for -
        sender = HironCraftScan.GetUnitName(sender, true)
    end

    if prefix ~= HIRONCRAFT_SCAN_COMM_PREFIX then
        return
    end

    local decoded = LibDeflate:DecodeForWoWAddonChannel(payload)
    if not decoded then
        return
    end

    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then
        return
    end

    local handler = LibSerialize:DeserializeAsync(decompressed)
    local processing = asyncPool:Acquire()
    processing:SetScript('OnUpdate', function()
        local completed, success, deserialized = handler()
        if completed then
            processing:SetScript('OnUpdate', nil)
            asyncPool:Release(processing)
            if not success then
                return
            end
            ReceiveDeserialized(deserialized, sender)
        end
    end)

    -- OnUpdate won't fire if the frame is hidden, which is is by default when
    -- fetched from the pool.
    processing:Show()
end

function HironCraftScanComm:LinkState(sourceID)
    if not remoteTargets or remoteTargets[sourceID] == nil then
        return nil
    end
    return next(remoteTargets[sourceID])
end
