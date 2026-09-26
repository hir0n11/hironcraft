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
local M = {}
Scan.AnalyticsSync = M

M.BATCH = 150
M.OFFER_INTERVAL = 15 * 60
local TICK_SECONDS = 60

M.Operations = {
    Offer = 'an_offer',
    Pull = 'an_pull',
    Events = 'an_events',
}

local lastOfferAt = {}

local function Log() return Scan.AnalyticsLog end

local function Comm() return HironCraftScanComm end

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

-- "Exchange now" in the window: skips the wait for a quiet period.
function M.SyncNow()
    M.Tick(true)
end

function M.Receive(operation, sender, data, senderID)
    local account = Accounts()[senderID]
    if not MayShare(account) or type(data) ~= 'table' then return end
    local force = data.force == true

    if operation == M.Operations.Offer then
        if not Ready(force) then return end
        local have = tonumber(data.seq) or 0
        local got = tonumber(account.analytics_received) or 0
        -- Their journal started over (a reset); take it from the start.
        if have < got then got = 0 end
        if have > got then Send(M.Operations.Pull, { from = got, force = force or nil }, sender) end
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
        if data.more and Ready(force) then
            Send(M.Operations.Pull, { from = account.analytics_received, force = force or nil }, sender)
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

if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(TICK_SECONDS, function() pcall(M.Tick) end)
end
