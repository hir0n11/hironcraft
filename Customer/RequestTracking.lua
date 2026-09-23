local Scan = select(2, ...)
local M = { Interval = 30 }
Scan.RequestTracking = M

local function Responses(info)
    local result, seen = {}, {}
    for id, response in pairs(info.responses or {}) do
        if type(response) == 'table' and not seen[response] then
            seen[response] = true
            result[#result + 1] = { responseID=response.responseID or id, response=response }
        end
    end
    return result
end

function M.AssignInquiry(info, response, entry, fresh)
    if not fresh and response.inquiryID then return end
    local receivedAt = tonumber(entry.receivedAt) or time()
    local inquiry = entry.inquiry
    if type(inquiry) ~= 'table' or type(inquiry.id) ~= 'string' or #inquiry.id > 192 then
        local previous = info.latestInquiry
        if not fresh and previous and receivedAt >= previous.lastAt
            and receivedAt - previous.lastAt < M.Interval then
            inquiry = {id=previous.id, startedAt=previous.startedAt}
        else
            inquiry = {id=response.requestToken, startedAt=receivedAt}
        end
        entry.inquiry = inquiry
    end
    response.inquiryID = inquiry.id
    response.inquiryStartedAt = tonumber(inquiry.startedAt) or receivedAt
    if not info.latestInquiry or receivedAt >= info.latestInquiry.lastAt then
        info.latestInquiry = {id=inquiry.id, startedAt=response.inquiryStartedAt, lastAt=receivedAt}
    end
end

function M.CanReoffer(response, receivedAt, status)
    return response.greeting_sent and not response.customer_answered
        and receivedAt - (tonumber(response.greetingSentAt) or tonumber(response.time) or receivedAt) >= M.Interval
        and status ~= 'claimed' and status ~= 'crafted' and status ~= 'fulfilled'
end

function M.GreetingSent(info, responses, at)
    at = at or time()
    local first = responses[1]
    if not first then return end
    local inquiryID = first.inquiryID or first.requestToken
    for _, response in ipairs(responses) do
        response.inquiryID = response.inquiryID or inquiryID
        response.greeting_sent = true
        response.greetingSentAt = at
        response.previousGreeting = nil
    end
    info.activeInquiryID, info.activeInquiryAt = inquiryID, at
end

function M.GetReplyContext(info)
    local all = Responses(info)
    local activeID, activeAt = info.activeInquiryID, info.activeInquiryAt
    if not activeID then
        -- Old saved rows have no inquiry IDs. Pick the latest greeted request;
        -- only its explicit multi-item greeting group may join it.
        local latest
        for _, candidate in ipairs(all) do
            local response = candidate.response
            local at = tonumber(response.greetingSentAt) or tonumber(response.time) or 0
            if response.greeting_sent and (not latest or at > activeAt) then
                latest, activeAt = response, at
            end
        end
        if not latest then return nil end
        activeID = latest.inquiryID or latest.requestToken
        if not activeID then return nil end
        latest.inquiryID = activeID
        local group = type(latest.greetingGroup) == 'table' and latest.greetingGroup or {}
        for _, member in ipairs(group) do
            local sibling = type(member) == 'table' and info.responses[member.responseID]
            if sibling and sibling.requestToken == member.requestToken then sibling.inquiryID = activeID end
        end
        info.activeInquiryID, info.activeInquiryAt = activeID, activeAt
    end
    local members = {}
    for _, candidate in ipairs(all) do
        local response = candidate.response
        local pendingPrevious = not response.greeting_sent and type(response.previousGreeting) == 'table'
            and response.previousGreeting.id == activeID
        if (response.greeting_sent and response.inquiryID == activeID) or pendingPrevious then
            members[#members + 1] = {responseID=candidate.responseID, requestToken=response.requestToken,
                greetingSentAt=tonumber(response.greetingSentAt) or activeAt}
        end
    end
    if #members == 0 then return nil end
    return {id=activeID, at=activeAt, members=members}
end

function M.ApplyContext(info, context, incoming)
    if type(context) ~= 'table' or type(context.id) ~= 'string' or #context.id > 192
        or type(context.members) ~= 'table' or type(context.at) ~= 'number' then return false end
    local matched = false
    for index, member in ipairs(context.members) do
        if index > 64 then break end
        if type(member) == 'table' then
            local response = info.responses and info.responses[member.responseID]
            if response and type(response.requestToken) == 'string'
                and response.requestToken == member.requestToken then
                response.inquiryID = context.id
                response.greeting_sent = true
                local sentAt = math.min(tonumber(member.greetingSentAt) or context.at, context.at)
                response.greetingSentAt = math.max(tonumber(response.greetingSentAt) or 0, sentAt)
                response.previousGreeting = nil
                if incoming then response.customer_answered = true end
                matched = true
            end
        end
    end
    if matched and context.at >= (tonumber(info.activeInquiryAt) or 0) then
        info.activeInquiryID, info.activeInquiryAt = context.id, context.at
    end
    return matched
end

function M.MarkReply(info, entry)
    -- Carry the exact request identities in synced history. Delayed replies
    -- must not check a newer row simply because it arrived before the packet.
    entry.replyContext = entry.replyContext or M.GetReplyContext(info)
    local matched = M.ApplyContext(info, entry.replyContext, true)
    -- A row the crafter set back to waiting is waiting for exactly this: any
    -- message from the customer, whichever request it is about.
    for _, candidate in ipairs(Responses(info)) do
        local response = candidate.response
        if response.awaitingReturn then
            response.awaitingReturn = nil
            response.customer_answered = true
            matched = true
        end
    end
    return matched
end

-- The second mark by hand. A customer who went quiet may or may not come
-- back: set back to waiting, their next message checks it again.
function M.ToggleAnswered(response)
    if type(response) ~= 'table' then return nil end
    response.customer_answered = not response.customer_answered
    response.awaitingReturn = not response.customer_answered or nil
    return response.customer_answered
end

function M.IsActiveResponse(info, response)
    local context = M.GetReplyContext(info)
    return not context or response.inquiryID == context.id
end
