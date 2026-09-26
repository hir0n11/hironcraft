local Scan = select(2, ...)

-- Linked accounts share their analytics so each one shows the whole picture,
-- but only while both are quiet: no requests, greetings, whispers or crafting
-- for AnalyticsLog.QUIET_SECONDS, and not in combat. The receiver pulls the
-- sender's own events in small batches on a channel of their own and stops
-- as soon as either side gets busy; the next quiet period carries on from
-- where it stopped.
--
--   offer  {seq}        "I have events up to seq"         (sent when quiet)
--   pull   {from}       "send yours after from"           (sent when quiet)
--   events {events, last, more}                           (answer to a pull)
--
-- "Exchange now" skips the wait and says in chat how it went, so an account
-- that does not answer (an older HironCraft there) does not go unnoticed.
local M = {}
Scan.AnalyticsSync = M

M.BATCH = 150
M.OFFER_INTERVAL = 15 * 60
M.ANSWER_SECONDS = 30
local TICK_SECONDS = 60

M.Operations = {
    Offer = 'an_offer',
    Pull = 'an_pull',
    Events = 'an_events',
}

local lastOfferAt = {}
-- Exchanges started by hand: accountID -> { answered, received }.
local sessions = {}

local function Log() return Scan.AnalyticsLog end

local function Comm() return HironCraftScanComm end

local function L(key)
    return Scan.LOCAL and Scan.LOCAL:GetText(key) or key
end

local function Accounts()
    return Scan.DB and Scan.DB.realm and Scan.DB.realm.linked_accounts or {}
end

local function MayShare(account)
    local comm = Comm()
    if type(account) ~= 'table' or not comm or not comm.Permissions then return false end
    return Scan.Utils.Contains(account.permissions, comm.Permissions.Full)
        or Scan.Utils.Contains(account.permissions, comm.Permissions.Analytics)
end

local function Send(operation, data, target)
    local comm = Comm()
    if comm and comm.Transmit and target then comm:Transmit(data, operation, target) end
end

local function Ready(force)
    local log = Log()
    return log and log.IsEnabled() and (force or log.IsQuiet())
end

local function Name(accountID)
    local account = Accounts()[accountID]
    return type(account) == 'table' and (account.nickname or account.last_active_char) or tostring(accountID)
end

local function Say(text)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage('|cffffd200HironCraft:|r ' .. text)
    end
end

-- A linked account's character, known or found by a ping.
local function Reach(accountID, callback)
    local comm = Comm()
    if not comm then return end
    if comm.ReachAccount then
        comm:ReachAccount(accountID, callback)
    elseif comm.FreshTarget then
        local target = comm:FreshTarget(accountID)
        if target then callback(target) end
    end
end

function M.Handles(operation)
    return operation == M.Operations.Offer or operation == M.Operations.Pull
        or operation == M.Operations.Events
end

local function Offer(accountID, target, force, reply)
    lastOfferAt[accountID] = time()
    Send(M.Operations.Offer, { seq = Log().Seq(), force = force or nil, reply = reply or nil }, target)
end

-- Every minute: offer our events to each linked account that is online,
-- at most every OFFER_INTERVAL, and only while quiet.
function M.Tick(force)
    if not Ready(force) then return end
    if not force then pcall(Log().Maintain) end
    local comm = Comm()
    for accountID, account in pairs(Accounts()) do
        local target = comm and comm.FreshTarget and comm:FreshTarget(accountID)
        if MayShare(account) and target
            and (force or time() - (lastOfferAt[accountID] or 0) >= M.OFFER_INTERVAL) then
            Offer(accountID, target, force)
        end
    end
end

-- "Exchange now" in the window: does not wait for a quiet period, finds the
-- linked accounts' characters, and reports in chat.
function M.SyncNow()
    if not Log().IsEnabled() then return end
    local names = {}
    for accountID, account in pairs(Accounts()) do
        if MayShare(account) then
            local session = { answered = false, received = 0 }
            sessions[accountID] = session
            names[#names + 1] = Name(accountID)
            Reach(accountID, function(target) Offer(accountID, target, true) end)
            if C_Timer and C_Timer.After then
                C_Timer.After(M.ANSWER_SECONDS, function()
                    if sessions[accountID] == session and not session.answered then
                        sessions[accountID] = nil
                        Say(string.format(L('Analytics exchange: %s did not answer'), Name(accountID)))
                    end
                end)
            end
        end
    end
    if #names == 0 then
        Say(L('Analytics exchange: no linked accounts'))
    else
        table.sort(names)
        Say(string.format(L('Analytics exchange started: %s'), table.concat(names, ', ')))
    end
end

local function Finish(accountID, received)
    local session = sessions[accountID]
    if not session then return end
    sessions[accountID] = nil
    Say(string.format(L('Analytics exchange: %d new events from %s'), received, Name(accountID)))
end

function M.Receive(operation, sender, data, senderID)
    local account = Accounts()[senderID]
    if not MayShare(account) or type(data) ~= 'table' then return end
    local force = data.force == true
    local session = sessions[senderID]
    if session then session.answered = true end

    if operation == M.Operations.Offer then
        if not Ready(force) then return end
        local have = tonumber(data.seq) or 0
        local got = tonumber(account.analytics_received) or 0
        -- Their journal started over (a reset); take it from the start.
        if have < got then got = 0 end
        if have > got then
            Send(M.Operations.Pull, { from = got, force = force or nil }, sender)
        else
            -- Nothing new over there: we are up to date with them.
            account.analytics_synced_at = time()
            if data.reply then Finish(senderID, 0) end
        end
        if not data.reply then Offer(senderID, sender, force, true) end
    elseif operation == M.Operations.Pull then
        if not Ready(force) then return end
        -- An account with full access gets every order result as it happens
        -- (the order journal); only analytics-only accounts need them here.
        local comm = Comm()
        local full = comm and Scan.Utils.Contains(account.permissions, comm.Permissions.Full)
        local events, last, more = Log().OwnSince(data.from, M.BATCH, full and { d = true } or nil)
        Send(M.Operations.Events, { events = events, last = last, more = more or nil, force = force or nil }, sender)
    elseif operation == M.Operations.Events then
        local merged = Log().Merge(data.events, senderID)
        account.analytics_received = tonumber(data.last) or account.analytics_received
        account.analytics_synced_at = time()
        if session then session.received = session.received + merged end
        if data.more and Ready(force) then
            Send(M.Operations.Pull, { from = account.analytics_received, force = force or nil }, sender)
        elseif session then
            Finish(senderID, session.received)
        end
        return merged
    end
end

-- When the last exchange with any linked account finished, or nil.
function M.LastSync()
    local latest = nil
    for _, account in pairs(Accounts()) do
        local at = tonumber(type(account) == 'table' and account.analytics_synced_at)
        if at and (not latest or at > latest) then latest = at end
    end
    return latest
end

-- Each linked account and when analytics was last exchanged with it.
function M.Status()
    local list = {}
    for accountID, account in pairs(Accounts()) do
        if MayShare(account) then
            list[#list + 1] = { name = Name(accountID), at = tonumber(account.analytics_synced_at) }
        end
    end
    table.sort(list, function(lhs, rhs) return lhs.name < rhs.name end)
    return list
end

if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(TICK_SECONDS, function() pcall(M.Tick) end)
end
