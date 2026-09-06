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

function Scan.SendOrderGreeting(order)
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
            if #pending == 0 then
                Scan.RebuildResponseMessage(sibling)
                for _, line in ipairs(siblingResponse.message or {}) do messages[#messages + 1] = line end
            else
                local itemLink = siblingResponse.itemLink
                    or (siblingResponse.itemID and select(2, GetItemInfo(siblingResponse.itemID)))
                if type(itemLink) ~= 'string' or type(siblingResponse.crafterFullName) ~= 'string' then
                    return false
                end
                local crafter = Scan.NameAndRealmToName(siblingResponse.crafterFullName)
                if not crafter then return false end
                for _, line in ipairs(Scan.Utils.SplitResponse(itemLink .. ' Send to ' .. crafter .. '.')) do
                    messages[#messages + 1] = line
                end
            end
            pending[#pending + 1] = siblingResponse
        end
    end
    if #pending == 0 or #messages == 0 then return false end

    Scan.Utils.SendResponses(messages, order.customerName)
    for _, sentResponse in ipairs(pending) do
        if Scan.QuickReplies then Scan.QuickReplies:RememberConversationCharacter(sentResponse) end
        sentResponse.greeting_sent = true
    end
    return true
end
