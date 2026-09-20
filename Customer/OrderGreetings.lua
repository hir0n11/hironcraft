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
function Scan.BuildOrderDestinationMessage(response)
    if type(response) ~= 'table' or type(response.crafterFullName) ~= 'string' then
        return nil
    end
    local subject = Scan.Utils.GetReplyItemLink(response.itemID, response.itemLink)
        or response.equipmentLabel or response.professionName
    local crafter = Scan.NameAndRealmToName(response.crafterFullName)
    if type(subject) ~= 'string' or subject == '' or not crafter then return nil end
    return subject .. ' Send to ' .. crafter .. '.'
end

function Scan.SendOrderGreeting(order, userInitiated)
    if userInitiated ~= true then return false end
    local response = Scan.OrderToResponse(order)
    if not response or response.greeting_sent then return false end

    local group = response.greetingGroup
    if type(group) ~= 'table' or #group == 0 then
        group = {{ responseID = order.responseID, requestToken = response.requestToken }}
    end
    local pending, messages, seen = {}, {}, {}
    for _, member in ipairs(group) do
        local sibling = { customerName = order.customerName,
            responseID = type(member) == 'table' and member.responseID or nil }
        local siblingResponse = Scan.OrderToResponse(sibling)
        if siblingResponse and not siblingResponse.greeting_sent
            and siblingResponse.requestToken == member.requestToken
            and not seen[member.responseID]
            and Scan.DB.listed_orders[Scan.OrderToOrderID(sibling)] then
            seen[member.responseID] = true
            if #pending == 0 and siblingResponse.destination_only_greeting ~= true then
                -- Rebuild even on the same character: older saved greetings
                -- may contain hyperlink fragments from the whitespace splitter.
                Scan.RebuildResponseMessage(sibling, true)
                for _, line in ipairs(siblingResponse.message or {}) do messages[#messages + 1] = line end
            else
                local destination = Scan.BuildOrderDestinationMessage(siblingResponse)
                if not destination then return false end
                for _, line in ipairs(Scan.Utils.SplitResponse(destination)) do
                    messages[#messages + 1] = line
                end
            end
            pending[#pending + 1] = siblingResponse
        end
    end
    if #pending == 0 or #messages == 0 then return false end

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

