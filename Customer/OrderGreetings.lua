local Scan = select(2, ...)

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
    return true
end
