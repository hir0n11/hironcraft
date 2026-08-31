local HironCraftScan = select(2, ...)

local OrderFulfillment = {}
HironCraftScan.OrderFulfillment = OrderFulfillment

OrderFulfillment.Status = {
    Unknown = 'unknown',
    Claimed = 'claimed',
    Crafted = 'crafted',
    Fulfilled = 'fulfilled',
    Failed = 'failed',
    Rejected = 'rejected',
}

local MAX_STATUS_AGE = 30 * 24 * 60 * 60
local MAX_STATUS_COUNT = 500
local craftingOrderToHironCraftScan = {}
-- Fulfillment responses may omit orderID after GetClaimedOrder() has already
-- been cleared, so retain the last snapshots captured by claim/craft events.
local craftingOrderSnapshots = {}
local lastCraftingOrderSnapshot = nil
local pendingFulfillOrderID = nil
local statusButtons = setmetatable({}, { __mode = 'k' })
local scheduledStatusRefreshes = {}
local ScheduleStatusRefreshes

local function EnsureStorage()
    if not HironCraftScan.DB or not HironCraftScan.DB.realm then
        return {}
    end

    return HironCraftScan.Utils.saved(HironCraftScan.DB.realm, 'order_statuses', {})
end

local function EnsureCompletionStorage()
    if not HironCraftScan.DB or not HironCraftScan.DB.realm then
        return {}
    end

    -- This journal is independent of local HironCraftScan response IDs. It lets a
    -- linked account apply the completion even if its order row arrives later.
    return HironCraftScan.Utils.saved(HironCraftScan.DB.realm, 'order_completion_notices', {})
end

local function BaseName(name)
    if type(name) ~= 'string' then
        return nil
    end

    return string.lower(name:match('^([^-]+)') or name)
end

local function NamesMatch(lhs, rhs)
    local lhsBase = BaseName(lhs)
    local rhsBase = BaseName(rhs)
    return lhsBase and rhsBase and lhsBase == rhsBase
end

local function PlainName(text)
    if type(text) ~= 'string' then
        return nil
    end

    text = text:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '')
    text = text:gsub('|H.-|h(.-)|h', '%1'):gsub('|T.-|t', '')
    text = text:gsub('|A.-|a', ''):gsub('^%[', ''):gsub('%]$', '')
    text = text:gsub('^%s+', ''):gsub('%s+$', '')
    if text == '' then
        return nil
    end
    return text:lower()
end

local function ItemIDFromLink(link)
    if not link then
        return nil
    end

    if C_Item and C_Item.GetItemInfoInstant then
        return select(1, C_Item.GetItemInfoInstant(link))
    end
    if GetItemInfoInstant then
        return select(1, GetItemInfoInstant(link))
    end
    return nil
end

local function ItemNameForID(itemID)
    if not itemID then
        return nil
    end

    if C_Item and C_Item.GetItemNameByID then
        local ok, itemName = pcall(C_Item.GetItemNameByID, itemID)
        if ok and itemName then
            return itemName
        end
    end
    if GetItemInfo then
        local ok, itemName = pcall(GetItemInfo, itemID)
        if ok then
            return itemName
        end
    end
    return nil
end

local function ItemIDFromDisplayName(itemName)
    if not GetItemInfo then
        return nil
    end

    local ok, _, itemLink = pcall(GetItemInfo, itemName)
    if ok then
        return ItemIDFromLink(itemLink)
    end
    return nil
end

local function CurrentParentProfessionID()
    if not C_TradeSkillUI or not C_TradeSkillUI.GetBaseProfessionInfo then
        return nil
    end

    local ok, info = pcall(C_TradeSkillUI.GetBaseProfessionInfo)
    if not ok or type(info) ~= 'table' then
        return nil
    end

    return tonumber(info.parentProfessionID or info.professionID or info.profession)
end

local function SnapshotOrderInfo(orderInfo, craftingOrderID)
    if type(orderInfo) ~= 'table' or type(orderInfo.customerName) ~= 'string' then
        return nil
    end

    local snapshot = {
        orderID = craftingOrderID or orderInfo.orderID,
        customerName = orderInfo.customerName,
        spellID = tonumber(orderInfo.spellID),
        itemID = tonumber(orderInfo.itemID) or ItemIDFromLink(orderInfo.outputItemHyperlink),
        parentProfessionID = tonumber(orderInfo.parentProfessionID) or CurrentParentProfessionID(),
        capturedAt = time(),
    }

    if snapshot.orderID then
        craftingOrderSnapshots[snapshot.orderID] = snapshot
    end
    lastCraftingOrderSnapshot = snapshot
    return snapshot
end

local function GetClaimedOrder()
    if not C_CraftingOrders or not C_CraftingOrders.GetClaimedOrder then
        return nil
    end

    local ok, orderInfo = pcall(C_CraftingOrders.GetClaimedOrder)
    if ok then
        return orderInfo
    end
    return nil
end

local function IsSuccessfulResult(result)
    if result == nil then
        return true
    end

    local okResult = Enum and Enum.CraftingOrderResult and Enum.CraftingOrderResult.Ok
    if okResult ~= nil then
        return result == okResult
    end
    return result == 0
end

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function ResultForStorage(result)
    if result == nil or IsSecret(result) then
        return nil
    end
    if type(result) == 'number' then
        return result
    end
    return tostring(result):sub(1, 64)
end

local function EntryIsNewer(candidate, current)
    if not current then
        return true
    end

    local candidateRevision = tonumber(candidate.rev) or 0
    local currentRevision = tonumber(current.rev) or 0
    if candidateRevision ~= currentRevision then
        return candidateRevision > currentRevision
    end

    local candidateTime = tonumber(candidate.updatedAt) or 0
    local currentTime = tonumber(current.updatedAt) or 0
    if candidateTime ~= currentTime then
        return candidateTime > currentTime
    end

    return tostring(candidate.origin or '') > tostring(current.origin or '')
end

local function SanitizeEntry(entry)
    if type(entry) ~= 'table' then
        return nil
    end

    local allowed = {
        [OrderFulfillment.Status.Unknown] = true,
        [OrderFulfillment.Status.Claimed] = true,
        [OrderFulfillment.Status.Crafted] = true,
        [OrderFulfillment.Status.Fulfilled] = true,
        [OrderFulfillment.Status.Failed] = true,
        [OrderFulfillment.Status.Rejected] = true,
    }
    if not allowed[entry.status] then
        return nil
    end
    if type(entry.customerName) ~= 'string' or #entry.customerName > 128 then
        return nil
    end
    if type(entry.responseID) ~= 'number' and type(entry.responseID) ~= 'string' then
        return nil
    end

    local clean = {
        customerName = entry.customerName,
        responseID = entry.responseID,
        status = entry.status,
        rev = math.max(0, math.floor(tonumber(entry.rev) or 0)),
        updatedAt = tonumber(entry.updatedAt) or 0,
        automatic = entry.automatic ~= false,
    }

    if type(entry.requestToken) == 'string' then
        clean.requestToken = entry.requestToken:sub(1, 192)
    end
    if type(entry.requestTime) == 'number' then
        clean.requestTime = entry.requestTime
    end

    if type(entry.craftingOrderID) == 'number' then
        clean.craftingOrderID = entry.craftingOrderID
    end
    if type(entry.crafterFullName) == 'string' then
        clean.crafterFullName = entry.crafterFullName:sub(1, 128)
    end
    if type(entry.origin) == 'string' then
        clean.origin = entry.origin:sub(1, 128)
    end
    if type(entry.result) == 'number' then
        clean.result = entry.result
    elseif type(entry.result) == 'string' then
        clean.result = entry.result:sub(1, 64)
    end

    return clean
end

local function SanitizeCompletionNotice(notice)
    if type(notice) ~= 'table' then
        return nil
    end
    if type(notice.customerName) ~= 'string' or #notice.customerName > 128 then
        return nil
    end

    local clean = {
        customerName = notice.customerName,
        updatedAt = tonumber(notice.updatedAt) or 0,
        status = notice.status or OrderFulfillment.Status.Fulfilled,
    }
    if
        clean.status ~= OrderFulfillment.Status.Fulfilled
        and clean.status ~= OrderFulfillment.Status.Rejected
    then
        return nil
    end
    if clean.updatedAt <= 0 then
        return nil
    end
    if type(notice.orderID) == 'number' or type(notice.orderID) == 'string' then
        clean.orderID = notice.orderID
    end
    if type(notice.spellID) == 'number' then
        clean.spellID = notice.spellID
    end
    if type(notice.itemID) == 'number' then
        clean.itemID = notice.itemID
    end
    if type(notice.parentProfessionID) == 'number' then
        clean.parentProfessionID = notice.parentProfessionID
    end
    if type(notice.crafterFullName) == 'string' then
        clean.crafterFullName = notice.crafterFullName:sub(1, 128)
    end
    if type(notice.origin) == 'string' then
        clean.origin = notice.origin:sub(1, 128)
    end
    if type(notice.requestToken) == 'string' then
        clean.requestToken = notice.requestToken:sub(1, 192)
    end
    if type(notice.requestTime) == 'number' then
        clean.requestTime = notice.requestTime
    end

    return clean
end

local function CompletionNoticeKey(notice)
    return table.concat({
        tostring(notice.origin or notice.crafterFullName or ''),
        tostring(notice.orderID or notice.updatedAt or ''),
        tostring(BaseName(notice.customerName) or ''),
        tostring(notice.spellID or ''),
        tostring(notice.itemID or ''),
        tostring(notice.status or OrderFulfillment.Status.Fulfilled),
    }, ':')
end

local function ResponseForOrder(order)
    local ok, response = pcall(HironCraftScan.OrderToResponse, order)
    if ok then
        return response
    end
    return nil
end

local function CompletionNoticeMatchesOrder(notice, order)
    if not NamesMatch(notice.customerName, order.customerName) then
        return false
    end

    local response = ResponseForOrder(order)
    if not response then
        return false
    end

    local responseRequestToken = response.requestToken
    if type(responseRequestToken) == 'string' then
        -- The same customer/profession pair is deliberately reused by
        -- CraftScan. A per-request token prevents an old completion or
        -- rejection from being painted onto that reused row.
        if notice.requestToken ~= responseRequestToken then
            return false
        end
    else
        local responseTime = tonumber(response.time)
        -- Legacy rows do not have request tokens. In that case require the
        -- status event to be no older than the request; the former 60-second
        -- grace window allowed an old green check to leak onto a new request.
        if responseTime and (notice.updatedAt or 0) < responseTime then
            return false
        end
    end

    local responseRecipeID = tonumber(response.recipeID)
    local responseItemID = tonumber(response.itemID)
    if responseRecipeID or responseItemID then
        local recipeMatches = responseRecipeID
            and notice.spellID
            and responseRecipeID == notice.spellID
        local itemMatches = responseItemID and notice.itemID and responseItemID == notice.itemID
        return recipeMatches or itemMatches or false
    end

    local responseParentProfessionID = tonumber(response.parentProfID)
    return not notice.parentProfessionID
        or not responseParentProfessionID
        or notice.parentProfessionID == responseParentProfessionID
end

local function FindCompletionNotice(order)
    local newest = nil
    for _, notice in pairs(EnsureCompletionStorage()) do
        if
            CompletionNoticeMatchesOrder(notice, order)
            and (
                not newest
                or (notice.updatedAt or 0) > (newest.updatedAt or 0)
                or (
                    (notice.updatedAt or 0) == (newest.updatedAt or 0)
                    and notice.status == OrderFulfillment.Status.Fulfilled
                    and newest.status ~= OrderFulfillment.Status.Fulfilled
                )
            )
        then
            newest = notice
        end
    end
    return newest
end

local function OrderFromEntry(entry)
    return {
        customerName = entry.customerName,
        responseID = entry.responseID,
    }
end

function OrderFulfillment:RegisterStatusButton(button)
    if not button then
        return
    end

    statusButtons[button] = true

    -- ScrollBox rows are recycled. A completion can arrive in the same frame
    -- that a row is rebound to a different order, leaving the immediate
    -- refresh pointed at the row's previous order. Remember the current
    -- binding and schedule a coalesced post-layout refresh whenever it changes.
    local orderID = button.order and HironCraftScan.OrderToOrderID(button.order)
    if button.craftScanFulfillmentOrderID ~= orderID then
        button.craftScanFulfillmentOrderID = orderID
        if ScheduleStatusRefreshes then
            ScheduleStatusRefreshes()
        end
    end
end

local function RefreshStatusButtons(order)
    local orderID = order and HironCraftScan.OrderToOrderID(order)
    for button in pairs(statusButtons) do
        local buttonOrderID = button.order and HironCraftScan.OrderToOrderID(button.order)
        if
            button.Refresh
            and (not button.IsShown or button:IsShown())
            and (not orderID or buttonOrderID == orderID)
        then
            button:Refresh()
        end
    end
end

ScheduleStatusRefreshes = function()
    if not C_Timer or not C_Timer.After then
        return
    end

    -- Linked-account messages, item-cache callbacks, and ScrollBox row
    -- recycling can finish in different frames. Refresh all visible status
    -- buttons in a short, coalesced burst so the UI converges without waiting
    -- for the next crafting-order event. At most four timers can be pending,
    -- even when a bulk linked-account sync imports hundreds of notices.
    for index, delay in ipairs({ 0, 0.2, 1, 3 }) do
        if not scheduledStatusRefreshes[index] then
            scheduledStatusRefreshes[index] = true
            C_Timer.After(delay, function()
                scheduledStatusRefreshes[index] = nil
                RefreshStatusButtons()
            end)
        end
    end
end

local function NotifyUpdated(entry)
    local order = OrderFromEntry(entry)
    HironCraftScan.Events:Emit('ORDER_FULFILLMENT_UPDATED', order, entry)

    local liveResponse = HironCraftScan.OrderToLiveResponse(order, false)
    local interactionFrame = liveResponse and liveResponse.interactionFrame
    if interactionFrame and interactionFrame.UpdateOrderStatus then
        interactionFrame:UpdateOrderStatus()
    end
    RefreshStatusButtons(order)
    ScheduleStatusRefreshes()
end

local function NotifyCompletionUpdated(notice)
    HironCraftScan.Events:Emit('ORDER_COMPLETION_NOTICE_UPDATED', notice)

    for _, order in pairs(HironCraftScan.DB.listed_orders or {}) do
        if CompletionNoticeMatchesOrder(notice, order) then
            local liveResponse = HironCraftScan.OrderToLiveResponse(order, false)
            local interactionFrame = liveResponse and liveResponse.interactionFrame
            if interactionFrame and interactionFrame.UpdateOrderStatus then
                interactionFrame:UpdateOrderStatus()
            end
        end
    end
    RefreshStatusButtons()
    ScheduleStatusRefreshes()
end

function OrderFulfillment:NotifyDeliveryUpdated(entry)
    NotifyUpdated(entry)
end

local function RememberCraftingOrder(entry)
    if entry.craftingOrderID and entry.status ~= OrderFulfillment.Status.Unknown then
        craftingOrderToHironCraftScan[entry.craftingOrderID] = HironCraftScan.OrderToOrderID(entry)
    end
end

local function PruneEntries(entries)
    local now = time()
    local retained = {}

    for key, entry in pairs(entries) do
        if
            type(entry) == 'table'
            and now - (tonumber(entry.updatedAt) or now) <= MAX_STATUS_AGE
        then
            table.insert(retained, { key = key, updatedAt = tonumber(entry.updatedAt) or 0 })
        else
            entries[key] = nil
        end
    end

    table.sort(retained, function(lhs, rhs)
        return lhs.updatedAt > rhs.updatedAt
    end)
    for index = MAX_STATUS_COUNT + 1, #retained do
        entries[retained[index].key] = nil
    end
end

local function PruneStorage()
    PruneEntries(EnsureStorage())
    PruneEntries(EnsureCompletionStorage())
end

function OrderFulfillment:GetStatuses()
    return EnsureStorage()
end

function OrderFulfillment:GetCompletionNotices()
    return EnsureCompletionStorage()
end

function OrderFulfillment:IsDeliveryPending(entry)
    if type(entry) ~= 'table' or type(entry.deliveryPending) ~= 'table' then
        return false
    end

    local linkedAccounts = HironCraftScan.DB.realm.linked_accounts or {}
    for accountID in pairs(entry.deliveryPending) do
        if linkedAccounts[accountID] then
            return true
        end
    end
    return false
end

function OrderFulfillment:GetStatus(order)
    local entry = EnsureStorage()[HironCraftScan.OrderToOrderID(order)]
    local response = ResponseForOrder(order)
    if entry and response then
        if type(response.requestToken) == 'string' then
            if entry.requestToken ~= response.requestToken then
                entry = nil
            end
        elseif
            response.time
            and (tonumber(entry.updatedAt) or 0) < tonumber(response.time)
        then
            entry = nil
        end
    end
    local notice = FindCompletionNotice(order)
    if entry and (not notice or (entry.updatedAt or 0) >= (notice.updatedAt or 0)) then
        if entry.status == self.Status.Unknown then
            return nil
        end
        return entry
    end
    if notice then
        return {
            status = notice.status or self.Status.Fulfilled,
            crafterFullName = notice.crafterFullName,
            updatedAt = notice.updatedAt,
            automatic = true,
            completionNotice = true,
            deliveryPending = entry
                and entry.status == self.Status.Fulfilled
                and entry.deliveryPending,
            deliveryConfirmedAt = entry
                and entry.status == self.Status.Fulfilled
                and entry.deliveryConfirmedAt,
        }
    end
    return nil
end

local function FindStoredOrder(craftingOrderID)
    if not craftingOrderID then
        return nil
    end

    local key = craftingOrderToHironCraftScan[craftingOrderID]
    local entry = key and EnsureStorage()[key]
    if entry then
        return OrderFromEntry(entry)
    end

    for storedKey, storedEntry in pairs(EnsureStorage()) do
        if storedEntry.craftingOrderID == craftingOrderID then
            craftingOrderToHironCraftScan[craftingOrderID] = storedKey
            return OrderFromEntry(storedEntry)
        end
    end
    return nil
end

function OrderFulfillment:FindMatchingOrder(orderInfo)
    if type(orderInfo) ~= 'table' or not orderInfo.customerName then
        return nil
    end

    local currentCrafter = HironCraftScan.GetPlayerName(true)
    local claimedItemID = tonumber(orderInfo.itemID)
        or ItemIDFromLink(orderInfo.outputItemHyperlink)
    local claimedRecipeID = tonumber(orderInfo.spellID)
    local bestOrder = nil
    local bestScore = nil
    local tied = false

    for _, order in pairs(HironCraftScan.DB.listed_orders or {}) do
        if NamesMatch(order.customerName, orderInfo.customerName) then
            local ok, response = pcall(HironCraftScan.OrderToResponse, order)
            local responseCrafter = ok
                and response
                and (response.crafterFullName or response.crafterName)
            if responseCrafter and NamesMatch(responseCrafter, currentCrafter) then
                local responseRecipeID = tonumber(response.recipeID)
                local responseItemID = tonumber(response.itemID)
                local recipeMismatch = claimedRecipeID
                    and responseRecipeID
                    and claimedRecipeID ~= responseRecipeID
                local itemMismatch = claimedItemID
                    and responseItemID
                    and claimedItemID ~= responseItemID

                if not recipeMismatch and not itemMismatch then
                    local score = 1
                    if response.crafterFullName == currentCrafter then
                        score = score + 8
                    end
                    if order.customerName == orderInfo.customerName then
                        score = score + 4
                    end
                    if claimedItemID and responseItemID == claimedItemID then
                        score = score + 32
                    end
                    if claimedRecipeID and responseRecipeID == claimedRecipeID then
                        score = score + 128
                    end

                    if not bestScore or score > bestScore then
                        bestOrder = order
                        bestScore = score
                        tied = false
                    elseif
                        score == bestScore
                        and HironCraftScan.OrderToOrderID(order)
                            ~= HironCraftScan.OrderToOrderID(bestOrder)
                    then
                        tied = true
                    end
                end
            end
        end
    end

    if tied then
        return nil
    end
    return bestOrder
end

function OrderFulfillment:FindGenericOrders(orderInfo)
    if type(orderInfo) ~= 'table' or not orderInfo.customerName then
        return {}
    end

    local currentCrafter = HironCraftScan.GetPlayerName(true)
    local parentProfessionID = tonumber(orderInfo.parentProfessionID)
    local matches = {}

    for _, order in pairs(HironCraftScan.DB.listed_orders or {}) do
        if NamesMatch(order.customerName, orderInfo.customerName) then
            local ok, response = pcall(HironCraftScan.OrderToResponse, order)
            local responseCrafter = ok
                and response
                and (response.crafterFullName or response.crafterName)
            local responseParentProfessionID = response and tonumber(response.parentProfID)
            local professionMatches = not parentProfessionID
                or not responseParentProfessionID
                or parentProfessionID == responseParentProfessionID

            if
                responseCrafter
                and NamesMatch(responseCrafter, currentCrafter)
                and not response.recipeID
                and not response.itemID
                and professionMatches
            then
                table.insert(matches, order)
            end
        end
    end

    return matches
end

local function MayTransition(current, status, craftingOrderID, requestToken)
    if not current or current.status == OrderFulfillment.Status.Unknown then
        return true
    end
    if requestToken and current.requestToken ~= requestToken then
        return true
    end
    if
        craftingOrderID
        and (
            (current.craftingOrderID and current.craftingOrderID ~= craftingOrderID)
            or not current.automatic
        )
    then
        return true
    end
    if current.status == status then
        return false
    end
    if current.status == OrderFulfillment.Status.Fulfilled then
        return false
    end
    if
        (
            current.status == OrderFulfillment.Status.Crafted
            or current.status == OrderFulfillment.Status.Failed
        ) and status == OrderFulfillment.Status.Claimed
    then
        return false
    end
    return true
end

function OrderFulfillment:SetStatus(order, status, options)
    options = options or {}
    local statuses = EnsureStorage()
    local key = HironCraftScan.OrderToOrderID(order)
    local current = statuses[key]
    local craftingOrderID = options.craftingOrderID
    local response = ResponseForOrder(order)

    local requestToken = response and response.requestToken
    if
        not options.force
        and not MayTransition(current, status, craftingOrderID, requestToken)
    then
        return current, false
    end

    local entry = {
        customerName = order.customerName,
        responseID = order.responseID,
        status = status,
        craftingOrderID = craftingOrderID,
        crafterFullName = options.crafterFullName or HironCraftScan.GetPlayerName(true),
        updatedAt = time(),
        automatic = options.automatic ~= false,
        result = ResultForStorage(options.result),
        rev = (current and current.rev or 0) + 1,
        origin = HironCraftScan.DB.settings.my_uuid or HironCraftScan.GetPlayerName(true),
    }
    if response then
        entry.requestToken = response.requestToken
        entry.requestTime = tonumber(response.time)
    end

    if HironCraftScanComm and HironCraftScanComm.PrepareOrderStatusDelivery then
        HironCraftScanComm:PrepareOrderStatusDelivery(entry)
    end

    statuses[key] = entry
    RememberCraftingOrder(entry)
    NotifyUpdated(entry)

    if HironCraftScanComm and HironCraftScanComm.ShareOrderStatus then
        HironCraftScanComm:ShareOrderStatus(entry)
    end

    return entry, true
end

function OrderFulfillment:ToggleManual(order)
    local current = self:GetStatus(order)
    local status = current and current.status == self.Status.Fulfilled and self.Status.Unknown
        or self.Status.Fulfilled
    return self:SetStatus(order, status, {
        automatic = false,
        force = true,
    })
end

function OrderFulfillment:ApplyRemoteStatus(remoteEntry)
    local entry = SanitizeEntry(remoteEntry)
    if not entry then
        return false
    end

    local statuses = EnsureStorage()
    local key = HironCraftScan.OrderToOrderID(entry)
    if not EntryIsNewer(entry, statuses[key]) then
        return false
    end

    statuses[key] = entry
    RememberCraftingOrder(entry)
    NotifyUpdated(entry)
    return true
end

function OrderFulfillment:ApplyRemoteStatuses(remoteStatuses)
    if type(remoteStatuses) ~= 'table' then
        return false
    end

    local changed = false
    for _, entry in pairs(remoteStatuses) do
        changed = self:ApplyRemoteStatus(entry) or changed
    end
    return changed
end

function OrderFulfillment:ApplyRemoteCompletion(noticeData)
    local notice = SanitizeCompletionNotice(noticeData)
    if not notice then
        return false
    end

    local notices = EnsureCompletionStorage()
    local key = CompletionNoticeKey(notice)
    local current = notices[key]
    if current and (current.updatedAt or 0) >= notice.updatedAt then
        -- Replayed linked-account notices are also a cheap UI repair signal.
        -- The data is already current, but the ScrollBox row may have been
        -- rebound after the original notification was handled.
        ScheduleStatusRefreshes()
        return false
    end

    notices[key] = notice
    NotifyCompletionUpdated(notice)
    return true
end

function OrderFulfillment:ApplyRemoteCompletionNotices(remoteNotices)
    if type(remoteNotices) ~= 'table' then
        return false
    end

    local changed = false
    for _, notice in pairs(remoteNotices) do
        changed = self:ApplyRemoteCompletion(notice) or changed
    end
    return changed
end

function OrderFulfillment:RecordNotice(orderInfo, craftingOrderID, status)
    if type(orderInfo) ~= 'table' or not orderInfo.customerName then
        return false
    end

    local notice = {
        orderID = craftingOrderID or orderInfo.orderID,
        customerName = orderInfo.customerName,
        spellID = tonumber(orderInfo.spellID),
        itemID = tonumber(orderInfo.itemID),
        parentProfessionID = tonumber(orderInfo.parentProfessionID),
        crafterFullName = HironCraftScan.GetPlayerName(true),
        updatedAt = time(),
        origin = HironCraftScan.DB.settings.my_uuid or HironCraftScan.GetPlayerName(true),
        status = status or self.Status.Fulfilled,
        requestToken = orderInfo.requestToken,
        requestTime = tonumber(orderInfo.requestTime),
    }

    if not self:ApplyRemoteCompletion(notice) then
        return false
    end
    if
        notice.status == self.Status.Rejected
        and HironCraftScanComm
        and HironCraftScanComm.ShareOrderOutcome
    then
        HironCraftScanComm:ShareOrderOutcome(notice)
    elseif HironCraftScanComm and HironCraftScanComm.ShareOrderCompletion then
        HironCraftScanComm:ShareOrderCompletion(notice)
    end
    return true
end

function OrderFulfillment:RecordCompletion(orderInfo, craftingOrderID)
    return self:RecordNotice(orderInfo, craftingOrderID, self.Status.Fulfilled)
end

local function OrderInfoFromHironCraftScanOrder(order, craftingOrderID)
    local ok, response = pcall(HironCraftScan.OrderToResponse, order)
    return {
        orderID = craftingOrderID,
        customerName = order.customerName,
        spellID = ok and response and response.recipeID,
        itemID = ok and response and response.itemID,
        parentProfessionID = ok and response and response.parentProfID,
        requestToken = ok and response and response.requestToken,
        requestTime = ok and response and tonumber(response.time),
    }
end

local function FreshLastSnapshot()
    if
        lastCraftingOrderSnapshot
        and time() - (lastCraftingOrderSnapshot.capturedAt or 0) <= 30 * 60
    then
        return lastCraftingOrderSnapshot
    end
    return nil
end

local function TrackOrderInfo(status, craftingOrderID, result, orderInfo, genericOnly)
    local order = FindStoredOrder(craftingOrderID)
    if not order and orderInfo and not genericOnly then
        order = OrderFulfillment:FindMatchingOrder(orderInfo)
    end
    if not orderInfo and order then
        orderInfo = OrderInfoFromHironCraftScanOrder(order, craftingOrderID)
    end

    if order and orderInfo then
        local response = ResponseForOrder(order)
        if response then
            orderInfo.requestToken = response.requestToken
            orderInfo.requestTime = tonumber(response.time)
        end
    end

    local matched = order ~= nil
    if order then
        OrderFulfillment:SetStatus(order, status, {
            craftingOrderID = craftingOrderID or (orderInfo and orderInfo.orderID),
            automatic = true,
            result = result,
        })
    end

    if
        (
            status == OrderFulfillment.Status.Fulfilled
            or status == OrderFulfillment.Status.Rejected
        )
        and orderInfo
    then
        for _, genericOrder in ipairs(OrderFulfillment:FindGenericOrders(orderInfo)) do
            matched = true
            if not orderInfo.requestToken then
                local genericResponse = ResponseForOrder(genericOrder)
                if genericResponse then
                    orderInfo.requestToken = genericResponse.requestToken
                    orderInfo.requestTime = tonumber(genericResponse.time)
                end
            end
            OrderFulfillment:SetStatus(genericOrder, status, {
                craftingOrderID = craftingOrderID or orderInfo.orderID,
                automatic = true,
                result = result,
            })
        end

        matched = true
        OrderFulfillment:RecordNotice(orderInfo, craftingOrderID, status)
    end

    return matched
end

function OrderFulfillment:RecordRejection(orderInfo, craftingOrderID, reason)
    if type(orderInfo) ~= 'table' or type(orderInfo.customerName) ~= 'string' then
        return false
    end

    local snapshot = SnapshotOrderInfo(orderInfo, craftingOrderID or orderInfo.orderID)
        or orderInfo
    return TrackOrderInfo(
        self.Status.Rejected,
        craftingOrderID or orderInfo.orderID,
        reason or 'missing_customer_reagents',
        snapshot
    )
end

local function TrackClaimedOrder(status, craftingOrderID, result, allowLastSnapshot)
    local liveOrderInfo = GetClaimedOrder()
    if liveOrderInfo and not craftingOrderID then
        craftingOrderID = liveOrderInfo.orderID
    end

    local orderInfo = liveOrderInfo and SnapshotOrderInfo(liveOrderInfo, craftingOrderID)
        or (craftingOrderID and craftingOrderSnapshots[craftingOrderID])
    if not orderInfo and allowLastSnapshot then
        local lastSnapshot = FreshLastSnapshot()
        if lastSnapshot and (not craftingOrderID or lastSnapshot.orderID == craftingOrderID) then
            orderInfo = lastSnapshot
            craftingOrderID = craftingOrderID or lastSnapshot.orderID
        end
    end

    return TrackOrderInfo(status, craftingOrderID, result, orderInfo)
end

local function TrackWithRetry(status, craftingOrderID, result, allowLastSnapshot)
    if TrackClaimedOrder(status, craftingOrderID, result, allowLastSnapshot) then
        return
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.2, function()
            TrackClaimedOrder(status, craftingOrderID, result, allowLastSnapshot)
        end)
    end
end

local function OrderInfoFromDisplayedItem(customerName, itemName, craftingOrderID)
    local displayedName = PlainName(itemName)
    local itemID = ItemIDFromDisplayName(itemName)
    local bestResponse = nil

    if displayedName then
        local currentCrafter = HironCraftScan.GetPlayerName(true)
        for _, order in pairs(HironCraftScan.DB.listed_orders or {}) do
            if NamesMatch(order.customerName, customerName) then
                local response = ResponseForOrder(order)
                local responseCrafter = response
                    and (response.crafterFullName or response.crafterName)
                local responseItemName = response and ItemNameForID(response.itemID)
                if
                    responseCrafter
                    and NamesMatch(responseCrafter, currentCrafter)
                    and PlainName(responseItemName) == displayedName
                then
                    bestResponse = response
                    itemID = tonumber(response.itemID) or itemID
                    break
                end
            end
        end
    end

    return {
        orderID = craftingOrderID,
        customerName = customerName,
        spellID = bestResponse and tonumber(bestResponse.recipeID),
        itemID = itemID,
        parentProfessionID = bestResponse and tonumber(bestResponse.parentProfID)
            or CurrentParentProfessionID(),
    }
end

local function TrackDisplayedCompletion(customerName, itemName, craftingOrderID, allowGeneric)
    local orderInfo = craftingOrderID and craftingOrderSnapshots[craftingOrderID]
        or FreshLastSnapshot()
    if not orderInfo or not NamesMatch(orderInfo.customerName, customerName) then
        orderInfo = OrderInfoFromDisplayedItem(customerName, itemName, craftingOrderID)
    end

    local hasSpecificContext = orderInfo.spellID or orderInfo.itemID
    local hasStoredOrder = FindStoredOrder(craftingOrderID) ~= nil
    if not hasSpecificContext and not hasStoredOrder and not allowGeneric then
        return false
    end
    TrackOrderInfo(
        OrderFulfillment.Status.Fulfilled,
        craftingOrderID,
        nil,
        orderInfo,
        not hasSpecificContext and not hasStoredOrder
    )
    return hasSpecificContext or hasStoredOrder
end

local function RegisterEvents()
    -- Capture the order while Blizzard still exposes it. Some clients clear
    -- GetClaimedOrder() before the fulfillment response reaches addons.
    if hooksecurefunc then
        if C_CraftingOrders and type(C_CraftingOrders.FulfillOrder) == 'function' then
            hooksecurefunc(C_CraftingOrders, 'FulfillOrder', function(orderID)
                pendingFulfillOrderID = orderID
                local orderInfo = GetClaimedOrder()
                if orderInfo then
                    SnapshotOrderInfo(orderInfo, orderID)
                end
            end)
        end

        if C_TradeSkillUI and type(C_TradeSkillUI.CraftRecipe) == 'function' then
            hooksecurefunc(C_TradeSkillUI, 'CraftRecipe', function(_, _, _, _, orderID)
                if orderID then
                    local orderInfo = GetClaimedOrder()
                    if orderInfo then
                        SnapshotOrderInfo(orderInfo, orderID)
                    end
                end
            end)
        end

        if C_TradeSkillUI and type(C_TradeSkillUI.RecraftRecipeForOrder) == 'function' then
            hooksecurefunc(C_TradeSkillUI, 'RecraftRecipeForOrder', function(orderID)
                local orderInfo = GetClaimedOrder()
                if orderInfo then
                    SnapshotOrderInfo(orderInfo, orderID)
                end
            end)
        end
    end

    HironCraftScanScannerMenu:RegisterEventCallback('TRADE_SKILL_SHOW', function()
        TrackWithRetry(OrderFulfillment.Status.Claimed)
    end)

    HironCraftScanScannerMenu:RegisterEventCallback(
        'CRAFTINGORDERS_CLAIM_ORDER_RESPONSE',
        function(_, result, orderID)
            if IsSuccessfulResult(result) then
                TrackWithRetry(OrderFulfillment.Status.Claimed, orderID)
            end
        end
    )

    HironCraftScanScannerMenu:RegisterEventCallback(
        'CRAFTINGORDERS_CLAIMED_ORDER_ADDED',
        function(_, orderID)
            TrackWithRetry(OrderFulfillment.Status.Claimed, orderID)
        end
    )

    HironCraftScanScannerMenu:RegisterEventCallback(
        'CRAFTINGORDERS_CLAIMED_ORDER_UPDATED',
        function(_, orderID)
            TrackWithRetry(OrderFulfillment.Status.Claimed, orderID)
        end
    )

    HironCraftScanScannerMenu:RegisterEventCallback(
        'CRAFTINGORDERS_CRAFT_ORDER_RESPONSE',
        function(_, result, orderID)
            if IsSuccessfulResult(result) then
                TrackWithRetry(OrderFulfillment.Status.Crafted, orderID, nil, true)
            end
        end
    )

    HironCraftScanScannerMenu:RegisterEventCallback('TRADE_SKILL_ITEM_CRAFTED_RESULT', function()
        TrackWithRetry(OrderFulfillment.Status.Crafted)
    end)

    HironCraftScanScannerMenu:RegisterEventCallback(
        'CRAFTINGORDERS_FULFILL_ORDER_RESPONSE',
        function(_, result, orderID)
            local status = IsSuccessfulResult(result) and OrderFulfillment.Status.Fulfilled
                or OrderFulfillment.Status.Failed
            TrackWithRetry(status, orderID or pendingFulfillOrderID, result, true)
        end
    )

    -- This is the authoritative event Blizzard uses to print the yellow
    -- "You have filled ... for <customer>" message. It includes the customer
    -- name even when the lower-level response has already lost its order data.
    HironCraftScanScannerMenu:RegisterEventCallback(
        'CRAFTINGORDERS_DISPLAY_CRAFTER_FULFILLED_MSG',
        function(_, _, itemName, customerName)
            if type(customerName) ~= 'string' or IsSecret(customerName) then
                return
            end

            local craftingOrderID = pendingFulfillOrderID
            local matchedSpecific = TrackDisplayedCompletion(
                customerName,
                itemName,
                craftingOrderID,
                true
            )
            pendingFulfillOrderID = nil

            -- Item data can arrive just after the system event. Retry only the
            -- exact-name enrichment; the generic customer/profession fallback
            -- has already been safely recorded by the first pass.
            if not matchedSpecific and C_Timer and C_Timer.After then
                C_Timer.After(0.2, function()
                    TrackDisplayedCompletion(customerName, itemName, craftingOrderID, false)
                end)
                C_Timer.After(1, function()
                    TrackDisplayedCompletion(customerName, itemName, craftingOrderID, false)
                end)
            end
        end
    )
end

HironCraftScan.Utils.onLoad(function()
    PruneStorage()
    for _, entry in pairs(EnsureStorage()) do
        RememberCraftingOrder(entry)
    end
    RegisterEvents()
end)

-- ProfitHUB's selected Orders module is loaded earlier in the same addon. The
-- bridge lets its safe reject action feed the CraftScan status journal without
-- coupling either module to the other's private Lua environment.
_G.HironCraft = _G.HironCraft or {}
_G.HironCraft.RecordRejectedCraftingOrder = function(orderInfo, reason)
    return OrderFulfillment:RecordRejection(
        orderInfo,
        orderInfo and orderInfo.orderID,
        reason
    )
end
