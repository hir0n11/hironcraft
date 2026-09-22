local Scan = select(2, ...)

-- The last greeting handed to the server, kept only long enough to take it
-- back if the server says it was sent too fast.
local lastGreeting = nil

-- Persist only identities, not response references: SavedVariables and linked
-- accounts must not reconnect a later request to an old multi-item greeting.
function Scan.GroupOrderGreetings(responses)
    local group = {}
    for _, response in ipairs(responses) do
        group[#group + 1] = { responseID = response.responseID, requestToken = response.requestToken }
    end
    for _, response in ipairs(responses) do response.greetingGroup = group end
end

-- A customer who is already talking to us does not need another full
-- introduction for every additional craft. Reuse the compact line used for
-- the second and later items in a multi-item request.
local function Subject(response)
    local subject = Scan.Utils.GetReplyItemLink(response.itemID, response.itemLink)
        or response.equipmentLabel or response.professionName
    return type(subject) == 'string' and subject ~= '' and subject or nil
end

-- "Shield", "Shield and Sword", "Shield, Sword and Cloak".
local function JoinSubjects(subjects)
    if #subjects < 2 then return subjects[1] end
    return table.concat(subjects, ', ', 1, #subjects - 1) .. ' and ' .. subjects[#subjects]
end

function Scan.BuildOrderDestinationMessage(response, subjects)
    if type(response) ~= 'table' or type(response.crafterFullName) ~= 'string' then
        return nil
    end
    local subject = subjects and JoinSubjects(subjects) or Subject(response)
    local crafter = Scan.NameAndRealmToName(response.crafterFullName)
    if not subject or not crafter then return nil end
    return subject .. ' Send to ' .. crafter .. '.'
end

local function SameCrafter(lhs, rhs)
    return type(lhs.crafterFullName) == 'string' and lhs.crafterFullName == rhs.crafterFullName
end

local function Mentions(lines, subject)
    local text = table.concat(lines, ' '):lower()
    return text:find(subject:lower(), 1, true) ~= nil
end

-- The lines one greeting click sends, and the rows it answers. The card shows
-- the same text before the click.
local function BuildGreeting(order)
    local response = Scan.OrderToResponse(order)
    if not response or response.greeting_sent then return nil end

    local group = response.greetingGroup
    if type(group) ~= 'table' or #group == 0 then
        group = {{ responseID = order.responseID, requestToken = response.requestToken }}
    end
    local pending, siblings, seen = {}, {}, {}
    for _, member in ipairs(group) do
        local sibling = { customerName = order.customerName,
            responseID = type(member) == 'table' and member.responseID or nil }
        local siblingResponse = Scan.OrderToResponse(sibling)
        if siblingResponse and not siblingResponse.greeting_sent
            and siblingResponse.requestToken == member.requestToken
            and not seen[member.responseID]
            and Scan.DB.listed_orders[Scan.OrderToOrderID(sibling)] then
            seen[member.responseID] = true
            pending[#pending + 1] = siblingResponse
            siblings[#siblings + 1] = sibling
        end
    end
    if #pending == 0 then return nil end

    local messages, covered = {}, {}
    local first = pending[1]
    if first.destination_only_greeting ~= true then
        -- Rebuild even on the same character: older saved greetings
        -- may contain hyperlink fragments from the whitespace splitter.
        Scan.RebuildResponseMessage(siblings[1], true)
        local lines = {}
        for _, line in ipairs(first.message or {}) do lines[#lines + 1] = line end
        covered[first] = true
        -- "LF shield & sword" answered with "Send to Favu. You choose the
        -- price" does not say what goes to Favu. When the greeting does not
        -- name its item, open it with everything this crafter makes here.
        local firstSubject = Subject(first)
        if #pending > 1 and #lines > 0 and firstSubject and not Mentions(lines, firstSubject) then
            local subjects = { firstSubject }
            for index = 2, #pending do
                local subject = Subject(pending[index])
                if subject and SameCrafter(pending[index], first) then
                    subjects[#subjects + 1] = subject
                    covered[pending[index]] = true
                end
            end
            local opening = Scan.Utils.SplitResponse(JoinSubjects(subjects) .. ': ' .. lines[1])
            table.remove(lines, 1)
            for index = #opening, 1, -1 do table.insert(lines, 1, opening[index]) end
        end
        for _, line in ipairs(lines) do messages[#messages + 1] = line end
    end

    -- The rest, one line per crafter: "Shield and Sword Send to Favu."
    for index, response in ipairs(pending) do
        if not covered[response] then
            local subjects = {}
            for other = index, #pending do
                local candidate = pending[other]
                if not covered[candidate] and SameCrafter(candidate, response) then
                    local subject = Subject(candidate)
                    if not subject then return nil end
                    subjects[#subjects + 1] = subject
                    covered[candidate] = true
                end
            end
            covered[response] = true
            local destination = Scan.BuildOrderDestinationMessage(response, subjects)
            if not destination then return nil end
            for _, line in ipairs(Scan.Utils.SplitResponse(destination)) do
                messages[#messages + 1] = line
            end
        end
    end
    if #messages == 0 then return nil end
    return messages, pending
end

function Scan.BuildOrderGreetingText(order)
    local ok, messages = pcall(BuildGreeting, order)
    return ok and messages and table.concat(messages, ' ') or nil
end

function Scan.SendOrderGreeting(order, userInitiated)
    if userInitiated ~= true then return false end
    local messages, pending = BuildGreeting(order)
    if not messages then return false end

    local reply = table.concat(messages, '\n')
    if Scan.QuickReplies and Scan.QuickReplies.IsReplyOnCooldown
        and Scan.QuickReplies:IsReplyOnCooldown(order.customerName, reply) then return false end
    if Scan.Utils.SendResponses(messages, order.customerName, true) == false then return false end
    if Scan.QuickReplies and Scan.QuickReplies.RememberSentReply then
        Scan.QuickReplies:RememberSentReply(order.customerName, reply)
    end
    Scan.RequestTracking.GreetingSent(Scan.OrderToCustomerInfo(order), pending)
    for _, sentResponse in ipairs(pending) do
        if Scan.QuickReplies then Scan.QuickReplies:RememberConversationCharacter(sentResponse) end
        sentResponse.greeting_sent = true
        sentResponse.destination_only_greeting = nil
    end
    lastGreeting = {
        customer = order.customerName,
        responses = pending,
        at = (GetTime and GetTime()) or (time and time()) or 0,
    }
    return true
end

-- The server can swallow a whisper it considers too fast, and it says so a
-- moment later. The greeting was already marked as sent, which leaves the row
-- looking answered while the customer heard nothing. Take it back and put the
-- greeting card up again once the server lets us speak, so it is one click
-- away instead of something to remember. Nothing is ever sent by a timer.
local THROTTLE_UNDO_WINDOW = 2
local THROTTLE_RETRY_DELAY = 6
local THROTTLE_RETRY_ATTEMPTS = 3

local function OfferGreetingAgain(recent, attempt)
    local customerInfo = Scan.DB.customers and Scan.DB.customers[recent.customer]
    if type(customerInfo) ~= 'table' then return end

    local pending = {}
    for _, response in ipairs(recent.responses or {}) do
        -- The crafter may have greeted them by hand in the meantime.
        if type(response) == 'table' and not response.greeting_sent then
            pending[#pending + 1] = response
        end
    end
    if #pending == 0 then return end

    if not (Scan.Utils.CanSendMessages and Scan.Utils.CanSendMessages()) then
        if attempt < THROTTLE_RETRY_ATTEMPTS and C_Timer and C_Timer.After then
            C_Timer.After(THROTTLE_RETRY_DELAY, function()
                OfferGreetingAgain(recent, attempt + 1)
            end)
        end
        return
    end

    if Scan.QuickReplies and Scan.QuickReplies.ShowOrderGreeting then
        Scan.QuickReplies:ShowOrderGreeting(recent.customer, '', customerInfo, pending)
    end
end

if Scan.Utils and Scan.Utils.OnChatThrottled then
    Scan.Utils.OnChatThrottled(function()
        local recent = lastGreeting
        lastGreeting = nil
        if type(recent) ~= 'table' then return end

        local now = (GetTime and GetTime()) or (time and time()) or 0
        if now - (tonumber(recent.at) or 0) > THROTTLE_UNDO_WINDOW then return end

        for _, response in ipairs(recent.responses or {}) do
            response.greeting_sent = false
            response.greetingSentAt = nil
        end
        print('|cffffd100HironCraftScan:|r ' .. string.format(
            Scan.LOCAL:GetText('Greeting was not sent, the server limited the rate'),
            tostring(Scan.NameAndRealmToName and Scan.NameAndRealmToName(recent.customer)
                or recent.customer)))
        if HironCraftScanCraftingOrderPage and HironCraftScanCraftingOrderPage.ShowGeneric then
            HironCraftScanCraftingOrderPage:ShowGeneric()
        end

        if C_Timer and C_Timer.After then
            C_Timer.After(THROTTLE_RETRY_DELAY, function()
                OfferGreetingAgain(recent, 1)
            end)
        end
    end)
end

