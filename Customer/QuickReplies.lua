local HironCraftScan = select(2, ...)

local function L(id)
    return HironCraftScan.LOCAL:GetText(id)
end

local QuickReplies = {}
HironCraftScan.QuickReplies = QuickReplies

local MAX_MESSAGE_BYTES = 160
local MAX_MESSAGE_WORDS = 12
local MAX_CHAT_BYTES = 255
local MAX_VISIBLE_TOASTS = 8
local MAX_OPTIONS_PER_POPUP = 8
local MAX_PRIORITY = 999
local REJECTED_ORDER_TEMPLATE_KEY = 'REJECTED_ORDER'
local COMPLETED_ORDER_TEMPLATE_KEY = 'COMPLETED_ORDER'
local ORDER_GREETING_ACTION = 'order-greeting'
local REPLY_COOLDOWN = 6
local LEGACY_REJECTION_TEXT = 'You need provide all mats and they all should be max tier (even missive and embelishment)'
local REJECTION_TEXT_MIGRATIONS = {
    [LEGACY_REJECTION_TEXT] = true,
    ['{reagent_issues}'] = true,
    ['Resend. You missed {reagent_issues}'] = true,
    ['Resend. You missed [reagent_issues]'] = true,
}
-- 0.3.85 rewrote these three answers and 0.3.86 put them back. Undo that
-- rewrite for anyone who never edited them; a text the crafter wrote
-- themselves is theirs and is left alone.
local DEFAULT_TEXT_MIGRATIONS = {
    NAME = { ['{crafter} will craft it.'] = true },
    PRICE = { ['The commission is {commission}.'] = true },
    ORDER = { ['Send a personal order to {crafter}.'] = true },
}
local sentReplies = {}

local lastSentReply = {}

local function CustomerKey(customer)
    local info = HironCraftScan.DB.customers[customer]
    return tostring(info and info.guid or customer):lower()
end

local function ReplyKey(customer, reply)
    return CustomerKey(customer) .. '\31' .. reply
end

function QuickReplies:IsReplyOnCooldown(customer, reply)
    local now = GetTime()
    for key, sentAt in pairs(sentReplies) do
        if now - sentAt >= REPLY_COOLDOWN then sentReplies[key] = nil end
    end
    return sentReplies[ReplyKey(customer, reply)] ~= nil
end

function QuickReplies:RememberSentReply(customer, reply)
    sentReplies[ReplyKey(customer, reply)] = GetTime()
    lastSentReply[CustomerKey(customer)] = { reply = reply, at = GetTime() }
end

-- Nobody repeats themselves back to back. While the last thing said to this
-- customer is exactly this answer, offering it again is noise: they have it
-- in front of them. Saying anything else - another reply, an order status -
-- moves the conversation on and lifts the block at once, and after a few
-- minutes the same question deserves an answer again anyway.
local LAST_REPLY_REPEAT_WINDOW = 300

function QuickReplies:IsReplyTheLastThingSaid(customer, reply)
    if type(reply) ~= 'string' or reply == '' then return false end

    local entry = lastSentReply[CustomerKey(customer)]
    if type(entry) ~= 'table' or entry.reply ~= reply then return false end
    return (GetTime() - (tonumber(entry.at) or 0)) < LAST_REPLY_REPEAT_WINDOW
end

-- Per quick reply: how long the same answer stays out of the way for the same
-- person after it was sent. Two "omw" a few seconds apart help nobody, while
-- an unrelated question must still be answered immediately, so the delay is
-- kept per template and per customer instead of muting the whole stack.
local MAX_REPEAT_SECONDS = 86400

local function NormalizeRepeatSeconds(value)
    value = math.floor(tonumber(value) or 0)
    return math.max(0, math.min(MAX_REPEAT_SECONDS, value))
end

QuickReplies.NormalizeRepeatSeconds = NormalizeRepeatSeconds

local sentTemplates = {}

local function TemplateCustomerKey(customer, templateKey)
    local info = HironCraftScan.DB.customers[customer]
    return tostring(info and info.guid or customer):lower() .. '' .. tostring(templateKey)
end

function QuickReplies:GetTemplateRepeatDelay(templateKey)
    -- GetConfig, not the EnsureConfig local: this runs above its definition.
    local template = templateKey and self:GetConfig().templates[templateKey]
    if type(template) ~= 'table' then return 0 end
    return NormalizeRepeatSeconds(template.repeat_seconds)
end

function QuickReplies:IsTemplateOnRepeatCooldown(customer, templateKey)
    local delay = self:GetTemplateRepeatDelay(templateKey)
    if delay <= 0 then return false end

    local sentAt = sentTemplates[TemplateCustomerKey(customer, templateKey)]
    return sentAt ~= nil and (GetTime() - sentAt) < delay
end

function QuickReplies:RememberSentTemplate(customer, templateKey)
    if not templateKey then return end

    local now = GetTime()
    for key, sentAt in pairs(sentTemplates) do
        if now - sentAt > MAX_REPEAT_SECONDS then sentTemplates[key] = nil end
    end
    sentTemplates[TemplateCustomerKey(customer, templateKey)] = now
end

-- Adding another built-in quick reply only requires another definition here.
-- The SavedVariables defaults and the configuration UI are generated from
-- this list.
local DEFAULT_TEMPLATES = {
    {
        key = REJECTED_ORDER_TEMPLATE_KEY,
        eventOnly = true,
        keywords = '',
        response = 'I checked your order. {reagent_issues}',
    },
    {
        key = COMPLETED_ORDER_TEMPLATE_KEY,
        eventOnly = true,
        keywords = '',
        response = 'Your order is done, thank you!',
    },
    {
        key = 'NAME',
        keywords = 'name, crafter, char, character, who',
        response = '{crafter}',
    },
    {
        key = 'PRICE',
        keywords = 'price, cost, fee, how much, commission, tip',
        response = '{commission}',
    },
    {
        key = 'ORDER',
        keywords = 'where, where to send, send where, order where, who to send, personal order',
        response = 'Send personal order to {crafter}',
    },
    {
        key = 'QUALITY',
        keywords = 'max, max quality, quality, r5, rank 5, guarantee, guaranteed',
        response = 'Yes, max quality guaranteed.',
    },
}

local builtinKeys = {}
for _, definition in ipairs(DEFAULT_TEMPLATES) do
    builtinKeys[definition.key] = true
end

local function Trim(text)
    return (text or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function NormalizePriority(value)
    value = math.floor(tonumber(value) or 0)
    return math.max(0, math.min(MAX_PRIORITY, value))
end

QuickReplies.NormalizePriority = NormalizePriority

local function EnsureConfig()
    local config = HironCraftScan.Utils.saved(HironCraftScan.DB.settings, 'quick_replies', {})
    if config.enabled == nil then
        config.enabled = true
    end
    if type(config.dedup_seconds) ~= 'number' then
        config.dedup_seconds = 5
    end
    if type(config.rev) ~= 'number' then
        config.rev = 0
    end
    if type(config.next_custom_id) ~= 'number' then
        config.next_custom_id = 1
    end
    if config.typo_tolerance == nil then
        config.typo_tolerance = true
    end
    local previousSchema = tonumber(config.schema_version) or 0
    config.schema_version = 11

    local templates = HironCraftScan.Utils.saved(config, 'templates', {})
    for _, definition in ipairs(DEFAULT_TEMPLATES) do
        local template = HironCraftScan.Utils.saved(templates, definition.key, {})
        if template.enabled == nil then
            template.enabled = true
        end
        if template.keywords == nil then
            template.keywords = definition.keywords
        end
        -- Upgrade only known old wording once, including the user's exact
        -- screenshot text. Preserve other custom pastes and future edits.
        local upgrades = DEFAULT_TEXT_MIGRATIONS[definition.key]
        if template.response == nil or (definition.key == REJECTED_ORDER_TEMPLATE_KEY
            and not template.deleted and previousSchema < 8
            and REJECTION_TEXT_MIGRATIONS[Trim(template.response)])
            or (upgrades and not template.deleted and previousSchema < 11
                and upgrades[Trim(template.response)]) then
            template.response = definition.response
        end
    end
    for _, template in pairs(templates) do
        if type(template) == 'table' then
            template.priority = NormalizePriority(template.priority)
            if template.active_orders_only == nil then
                template.active_orders_only = false
            end
            -- 0.3.70 asked for this delay in minutes. Carry those values over
            -- once so a configured delay keeps its real length in seconds.
            if template.repeat_minutes ~= nil then
                if template.repeat_seconds == nil then
                    template.repeat_seconds = (tonumber(template.repeat_minutes) or 0) * 60
                end
                template.repeat_minutes = nil
            end
            template.repeat_seconds = NormalizeRepeatSeconds(template.repeat_seconds)
        end
    end
    return config
end

function QuickReplies:GetConfig()
    return EnsureConfig()
end

function QuickReplies:GetDefinitions()
    local config = EnsureConfig()
    local definitions = {}
    for _, definition in ipairs(DEFAULT_TEMPLATES) do
        local template = config.templates[definition.key]
        if not template.deleted then table.insert(definitions, {
            key = definition.key,
            label = template.label or L('dialog.quick_reply.' .. definition.key .. '.enabled'),
            custom = false,
            eventOnly = definition.eventOnly == true,
        }) end
    end

    local custom = {}
    for key, template in pairs(config.templates) do
        if not builtinKeys[key] and type(template) == 'table' and template.custom and not template.deleted then
            table.insert(custom, {
                key = key,
                label = template.label or key,
                custom = true,
            })
        end
    end
    table.sort(custom, function(lhs, rhs)
        return lhs.label:lower() < rhs.label:lower()
    end)
    for _, definition in ipairs(custom) do
        table.insert(definitions, definition)
    end
    return definitions
end

function QuickReplies:GetTemplateLabel(key)
    for _, definition in ipairs(self:GetDefinitions()) do
        if definition.key == key then
            return definition.label
        end
    end
    return key
end

function QuickReplies:IsLabelAvailable(label, exceptKey)
    if type(label) ~= 'string' or #label > 128 or label:find('[%c|]') then return false end
    label = (strlower or string.lower)(Trim(label))
    if label == '' then
        return false
    end
    for _, definition in ipairs(self:GetDefinitions()) do
        if definition.key ~= exceptKey and (strlower or string.lower)(definition.label) == label then
            return false
        end
    end
    return true
end

function QuickReplies:NotifyConfigChanged()
    local config = EnsureConfig()
    if HironCraftScanComm and HironCraftScanComm.ShareQuickReplies then
        HironCraftScanComm:ShareQuickReplies(config)
    else
        config.rev = (config.rev or 0) + 1
    end
end

function QuickReplies:AddKeyword(key, keyword)
    keyword = Trim(keyword):gsub('[,\r\n]+', ' '):gsub('%s+', ' ')
    if keyword == '' then return false, 'missing_text' end

    local config = EnsureConfig()
    local template = config.templates[key]
    if type(template) ~= 'table' or template.deleted or key == REJECTED_ORDER_TEMPLATE_KEY then
        return false, 'invalid_quick_reply'
    end

    local wanted = keyword:lower()
    local current = template.keywords or ''
    for entry in current:gmatch('[^,\n]+') do
        if Trim(entry):lower() == wanted then
            return false, 'duplicate_filter'
        end
    end

    template.keywords = current == '' and keyword or current .. ', ' .. keyword
    self:NotifyConfigChanged()
    if HironCraftScan.Events then
        HironCraftScan.Events:Emit('QUICK_REPLIES_UPDATED')
    end
    return true
end

function QuickReplies:CreateCustomTemplate(label, keywords, response)
    label = Trim(label)
    if not self:IsLabelAvailable(label) then
        return nil
    end

    local config = EnsureConfig()
    local key
    repeat
        key = 'CUSTOM_' .. config.next_custom_id
        config.next_custom_id = config.next_custom_id + 1
    until config.templates[key] == nil

    config.templates[key] = {
        custom = true,
        label = label,
        enabled = true,
        keywords = Trim(keywords),
        response = Trim(response),
        priority = 0,
    }
    self:NotifyConfigChanged()
    return key
end

function QuickReplies:RenameTemplate(key, label)
    local template = EnsureConfig().templates[key]
    if type(template) ~= 'table' or template.deleted or not self:IsLabelAvailable(label, key) then return false end
    template.label = Trim(label)
    self:NotifyConfigChanged()
    if self.InvalidateTemplateToasts then self:InvalidateTemplateToasts(key) end
    HironCraftScan.Events:Emit('QUICK_REPLIES_UPDATED')
    return true
end

function QuickReplies:DeleteTemplate(key)
    local config = EnsureConfig()
    local template = config.templates[key]
    if type(template) ~= 'table' or template.deleted then
        return false
    end
    -- Retain a tombstone, including on linked accounts. Defaults must not
    -- silently recreate a deliberately removed built-in after reload.
    config.templates[key] = {deleted=true, enabled=false, keywords='', response='', custom=template.custom}
    self:NotifyConfigChanged()
    if self.InvalidateTemplateToasts then self:InvalidateTemplateToasts(key) end
    HironCraftScan.Events:Emit('QUICK_REPLIES_UPDATED')
    return true
end

function QuickReplies:DeleteCustomTemplate(key)
    if builtinKeys[key] then return false end
    return self:DeleteTemplate(key)
end

function QuickReplies:ApplyRemoteConfig(remoteConfig)
    if type(remoteConfig) ~= 'table' then
        return false
    end

    local localConfig = HironCraftScan.DB.settings.quick_replies
    if localConfig and (localConfig.rev or 0) >= (remoteConfig.rev or 0) then
        return false
    end

    HironCraftScan.DB.settings.quick_replies = remoteConfig
    EnsureConfig()
    HironCraftScan.Events:Emit('QUICK_REPLIES_UPDATED')
    return true
end

local function Normalize(text)
    if not text then
        return ''
    end

    -- Retain the displayed text of links, then normalize punctuation and
    -- whitespace. Matching below is plain-text matching against padded strings,
    -- which gives phrase and word boundaries without interpreting user input as
    -- a Lua pattern.
    text = text:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '')
    text = text:gsub('|H.-|h(.-)|h', '%1')
    text = text:lower():gsub('[%c%p]', ' '):gsub('%s+', ' ')
    return text:gsub('^%s+', ''):gsub('%s+$', '')
end

QuickReplies.Normalize = Normalize

local function CountWords(text)
    local count = 0
    for _ in text:gmatch('%S+') do
        count = count + 1
    end
    return count
end

local function SplitWords(text)
    local words = {}
    for word in text:gmatch('%S+') do
        words[#words + 1] = word
    end
    return words
end

-- Four letters is the shortest word a typo can still be read through
-- ("charr" for "char"). Below that a single edit turns one real word into
-- another, so those keep requiring an exact match.
local MIN_TYPO_LENGTH = 4

local function FuzzyWordDistance(lhs, rhs)
    return HironCraftScan.Utils.FuzzyWordDistance(lhs, rhs, MIN_TYPO_LENGTH)
end

local function KeywordScore(message, keyword, allowTypos, exactWords)
    keyword = Normalize(keyword)
    if keyword == '' then
        return nil
    end

    local paddedMessage = ' ' .. message .. ' '
    if paddedMessage:find(' ' .. keyword .. ' ', 1, true) then
        -- Prefer longer phrases ("who to send") over contained short words
        -- ("who") so ORDER wins over NAME in that example.
        return CountWords(keyword) * 1000 + #keyword, true, CountWords(keyword)
    end
    if not allowTypos then return nil end

    local messageWords = SplitWords(message)
    local keywordWords = SplitWords(keyword)
    if #keywordWords == 0 or #keywordWords > #messageWords then return nil end

    local bestDistance
    for startIndex = 1, #messageWords - #keywordWords + 1 do
        local totalDistance = 0
        local changedWords = 0
        local valid = true
        for keywordIndex, keywordWord in ipairs(keywordWords) do
            local messageWord = messageWords[startIndex + keywordIndex - 1]
            if messageWord ~= keywordWord then
                -- "waist" is a word of its own; it must never be read as a
                -- misspelled "wrist", whichever template asks for it.
                if exactWords and exactWords[messageWord] then
                    valid = false
                    break
                end
                local wordDistance = FuzzyWordDistance(messageWord, keywordWord)
                if not wordDistance then
                    valid = false
                    break
                end
                changedWords = changedWords + 1
                totalDistance = totalDistance + wordDistance
                -- One misspelled word per phrase is deliberately conservative.
                if changedWords > 1 then
                    valid = false
                    break
                end
            end
        end
        if valid and (bestDistance == nil or totalDistance < bestDistance) then
            bestDistance = totalDistance
        end
    end

    if bestDistance == nil then return nil end
    -- An exact phrase with the same word count must always beat its fuzzy form.
    return #keywordWords * 1000 + #keyword - bestDistance * 100 - 1, false, #keywordWords
end

function QuickReplies:Classify(message)
    local config = EnsureConfig()
    if not config.enabled then
        return {}
    end

    local normalized = Normalize(message)
    if normalized == '' then
        -- Punctuation-only whispers carry no intent. In particular, do not
        -- turn one or more question marks into every configured action.
        return {}
    end
    if #normalized > MAX_MESSAGE_BYTES
        or CountWords(normalized) > MAX_MESSAGE_WORDS
    then
        return {}
    end

    local exactWords = {}
    for _, definition in ipairs(self:GetDefinitions()) do
        local template = config.templates[definition.key]
        if template and template.enabled and not definition.eventOnly then
            local keywords = HironCraftScan.Config.SubstituteTags(template.keywords or '')
            for keyword in keywords:gmatch('[^,\n]+') do
                for _, word in ipairs(SplitWords(Normalize(keyword))) do
                    exactWords[word] = true
                end
            end
        end
    end

    local bestExact = nil
    local bestWords = nil
    local bestPriority = nil
    local bestScore = nil
    local matched = {}
    for _, definition in ipairs(self:GetDefinitions()) do
        local template = config.templates[definition.key]
        if template and template.enabled and not definition.eventOnly then
            local templateScore, templateExact, templateWords = nil, false, 0
            local keywords = HironCraftScan.Config.SubstituteTags(template.keywords or '')
            for keyword in keywords:gmatch('[^,\n]+') do
                local score, exact, words = KeywordScore(
                    normalized, keyword, config.typo_tolerance, exactWords)
                if score and (not templateScore or score > templateScore) then
                    templateScore = score
                    templateExact = exact == true
                    templateWords = words or 0
                end
            end

            if templateScore then
                local priority = NormalizePriority(template.priority)
                -- What the customer actually said decides first: a longer
                -- phrase is stronger evidence than a single word, and a word
                -- they really wrote is stronger than one read through a typo.
                -- Priority only ranks answers that match the message equally
                -- well; it does not promote a guess over a certainty.
                local better = bestScore == nil
                    or templateWords > bestWords
                    or (templateWords == bestWords and templateExact and not bestExact)
                    or (templateWords == bestWords and templateExact == bestExact
                        and (priority > bestPriority
                            or (priority == bestPriority and templateScore > bestScore)))
                local tied = bestScore ~= nil
                    and templateWords == bestWords
                    and templateExact == bestExact
                    and priority == bestPriority
                    and templateScore == bestScore

                if better then
                    bestExact = templateExact
                    bestWords = templateWords
                    bestPriority = priority
                    bestScore = templateScore
                    matched = { definition.key }
                elseif tied then
                    table.insert(matched, definition.key)
                end
            end
        end
    end
    return matched
end

local function IsListedOrder(customer, responseID)
    if responseID == nil then
        return false
    end
    return HironCraftScan.DB.listed_orders[customer .. '-' .. responseID] ~= nil
end

-- Resolve the response independently for each customer. The profession-level
-- response can alias a recipe response, so response table identity is used to
-- remove duplicates before applying the selection priority.
function QuickReplies:ResolveResponses(customer, customerInfo)
    if not customerInfo or not customerInfo.responses then
        return {}
    end

    local candidates = {}
    local seen = {}
    for responseKey, response in pairs(customerInfo.responses) do
        if type(response) == 'table' and not seen[response] then
            seen[response] = true
            local responseID = response.responseID or responseKey
            if
                response.crafterFullName
                and response.professionID
                and IsListedOrder(customer, responseID)
                and (not HironCraftScan.RequestTracking or HironCraftScan.RequestTracking.IsActiveResponse(customerInfo, response))
            then
                table.insert(candidates, {
                    response = response,
                    responseID = responseID,
                })
            end
        end
    end

    if #candidates <= 1 then
        return candidates
    end

    local activeOrder = HironCraftScan.State.activeOrder
    if activeOrder and activeOrder.customerName == customer then
        for _, candidate in ipairs(candidates) do
            if candidate.responseID == activeOrder.responseID then
                return { candidate }
            end
        end
    end

    local answered = {}
    for _, candidate in ipairs(candidates) do
        if candidate.response.customer_answered then
            table.insert(answered, candidate)
        end
    end
    if #answered > 0 then
        candidates = answered
    end

    local newest = nil
    for _, candidate in ipairs(candidates) do
        local responseTime = candidate.response.time or 0
        if not newest or responseTime > newest then
            newest = responseTime
        end
    end

    local result = {}
    for _, candidate in ipairs(candidates) do
        if (candidate.response.time or 0) == newest then
            table.insert(result, candidate)
        end
    end
    table.sort(result, function(lhs, rhs)
        local lhsName = lhs.response.crafterName or lhs.response.crafterFullName or ''
        local rhsName = rhs.response.crafterName or rhs.response.crafterFullName or ''
        if lhsName == rhsName then
            return tostring(lhs.responseID) < tostring(rhs.responseID)
        end
        return lhsName < rhsName
    end)
    return result
end

function QuickReplies:BuildReply(templateKey, response)
    local config = EnsureConfig()
    local template = config.templates[templateKey]
    if not template or template.deleted or not template.enabled or template.response == '' then
        return nil
    end

    local context = HironCraftScan.BuildResponseContext(response)
    if not context then
        return nil
    end

    -- Match greeting behavior: custom substitution tags are expanded first so
    -- their values may themselves contain response-context placeholders.
    local raw = HironCraftScan.Config.SubstituteTags(template.response)
    local reply = HironCraftScan.Utils.FString(raw, context)
    reply = reply:gsub('[\r\n]+', ' '):gsub('^%s+', ''):gsub('%s+$', '')

    -- An unavailable commission (or any unknown context token) must never leak
    -- as a literal placeholder or turn into a misleading answer.
    local hasAuditTag = raw:find('{reagent_issues}', 1, true)
    if reply == '' or reply:find('%b{}') or #reply > (hasAuditTag and 4096 or MAX_CHAT_BYTES) then
        return nil
    end
    return reply
end

local toastPool = {}
local popupSerial = 0

local function DisplayText(text)
    return text
        :gsub('|c%x%x%x%x%x%x%x%x', '')
        :gsub('|r', '')
        :gsub('|H.-|h(.-)|h', '%1')
        :gsub('|T.-|t', '')
end

local function Shorten(text, maxBytes)
    if #text <= maxBytes then
        return text
    end

    local limit = maxBytes - 3
    local index = 1
    local lastComplete = 0
    while index <= #text and index <= limit do
        local firstByte = text:byte(index)
        local charBytes = 1
        if firstByte >= 240 then
            charBytes = 4
        elseif firstByte >= 224 then
            charBytes = 3
        elseif firstByte >= 192 then
            charBytes = 2
        end
        if index + charBytes - 1 > limit then
            break
        end
        lastComplete = index + charBytes - 1
        index = lastComplete + 1
    end
    return text:sub(1, lastComplete) .. '...'
end

local function ResponseLabel(response)
    if response.generic_request then
        return L('General crafting request')
    end
    local crafter = response.crafterName
        or HironCraftScan.NameAndRealmToName(response.crafterFullName)
    local subject = response.equipmentLabel or response.professionName
    if response.itemID then
        subject = select(1, GetItemInfo(response.itemID)) or subject
    end
    if subject then
        return crafter .. ' / ' .. subject
    end
    return crafter
end

-- The character handling the conversation is not necessarily the crafter.
-- Keep ownership on the individual request, not on the account/customer.
function QuickReplies:RememberConversationCharacter(response, character)
    if type(response) ~= 'table' then return end
    if not character then
        if HironCraftScanComm and HironCraftScanComm.applying_remote_state then return end
        character = HironCraftScan.GetPlayerName(true)
    end
    if HironCraftScan.CharacterRenames then character = HironCraftScan.CharacterRenames.Resolve(character) end
    if type(character) == 'string' and character ~= '' and not response.conversationCharacter then
        response.conversationCharacter = character
    end
end

function QuickReplies:GetConversationOwners(customerInfo)
    local owners, seen = {}, {}
    for responseID, response in pairs(customerInfo.responses or {}) do
        if type(response) == 'table' and not seen[response] and response.conversationCharacter then
            seen[response] = true
            owners[#owners + 1] = {
                responseID = response.responseID or responseID,
                requestToken = response.requestToken,
                time = response.time,
                character = response.conversationCharacter,
            }
        end
    end
    return owners
end

function QuickReplies:RememberCustomerConversation(customerInfo)
    for _, response in pairs(customerInfo.responses or {}) do
        if not HironCraftScan.RequestTracking or HironCraftScan.RequestTracking.IsActiveResponse(customerInfo, response) then
            self:RememberConversationCharacter(response)
        end
    end
    return self:GetConversationOwners(customerInfo)
end

function QuickReplies:ApplyConversationOwners(customerInfo, owners)
    if type(owners) ~= 'table' then return end
    for _, owner in ipairs(owners) do
        if type(owner) == 'table' and type(owner.character) == 'string' and #owner.character <= 128 then
            for responseID, response in pairs(customerInfo.responses or {}) do
                if type(response) == 'table'
                    and (response.responseID or responseID) == owner.responseID
                    and ((response.requestToken and response.requestToken == owner.requestToken)
                        or (not response.requestToken and not owner.requestToken
                            and response.time and response.time == owner.time))
                then
                    self:RememberConversationCharacter(response, owner.character)
                end
            end
        end
    end
end

local function SameCharacter(lhs, rhs)
    if type(lhs) ~= 'string' or type(rhs) ~= 'string' then return false end
    return lhs:gsub('%s+', ''):lower() == rhs:gsub('%s+', ''):lower()
end

local function IsCharacterOnThisAccount(name)
    if type(name) ~= 'string' or name == '' then return false end
    for character in pairs(HironCraftScan.DB.characters or {}) do
        if SameCharacter(character, name) then return true end
    end
    return false
end

-- The character this order was assigned to and crafted by, when the character
-- that spoke to the customer cannot be reached from here: orders are often
-- collected on one account and crafted on another. While the conversation
-- belongs to a character of this account, switching to it is the right thing
-- to do and the reply stays there.
function QuickReplies:IsOrderCrafter(response, entry)
    local current = HironCraftScan.GetPlayerName(true)
    if type(current) ~= 'string' then return false end

    local owner = type(response) == 'table' and response.conversationCharacter or nil
    if IsCharacterOnThisAccount(owner) then return false end

    if type(entry) == 'table' and SameCharacter(entry.crafterFullName, current) then
        return true
    end
    return type(response) == 'table' and SameCharacter(response.crafterFullName, current)
end

function QuickReplies:IsConversationCharacter(response)
    local owner = response and response.conversationCharacter
    local current = HironCraftScan.GetPlayerName(true)
    -- Old rows without ownership cannot safely be assigned to the crafting alt.
    return type(owner) == 'string' and type(current) == 'string'
        and owner:gsub('%s+', ''):lower() == current:gsub('%s+', ''):lower()
end

-- Both order-status replies are built the same way; only the status they
-- react to, their template and the toast headline differ.
local STATUS_OPTIONS = {
    -- A decline has to reach the customer from wherever the craft happened:
    -- it names the reagents they must fix before resending. A completion is a
    -- courtesy note and stays with the character they were talking to.
    rejected = { template = REJECTED_ORDER_TEMPLATE_KEY, message = 'Crafting order status rejected',
        crafterMayAnswer = true },
    fulfilled = { template = COMPLETED_ORDER_TEMPLATE_KEY, message = 'Crafting order status completed',
        lastOrderOnly = true, automaticOnly = true, oncePerCustomer = true },
}

-- A customer who placed several orders at once gets one "your order is done",
-- not one per order, so the reply waits for the last of their orders. A
-- decline is the opposite: it names the materials of one specific order and
-- must still be offered for each.
local PENDING_SIBLING_WINDOW = 12 * 60 * 60

-- OrderFulfillment.Status holds exactly these strings; compare against them
-- directly so a partially built status table cannot silently match nothing.
local FINAL_ORDER_RESULTS = { fulfilled = true, rejected = true, failed = true }
local STARTED_ORDER_RESULTS = { claimed = true, crafted = true }

-- Does this customer have anything of theirs still in the works? A request
-- that was never claimed counts while it is fresh; one that was completed or
-- declined does not. Used by replies that only make sense before the craft is
-- finished: "omw" reads strangely after the item was already handed over.
function QuickReplies:HasUnfinishedOrders(customerName, exceptResponseID)
    local fulfillment = HironCraftScan.OrderFulfillment
    if type(customerName) ~= 'string' or not fulfillment or not fulfillment.GetStatus then
        return false
    end

    local now = time and time() or 0
    for _, listed in pairs(HironCraftScan.DB.listed_orders or {}) do
        if type(listed) == 'table' and listed.customerName == customerName
            and (exceptResponseID == nil
                or tostring(listed.responseID) ~= tostring(exceptResponseID))
        then
            local ok, entry = pcall(fulfillment.GetStatus, fulfillment, listed)
            local status = ok and type(entry) == 'table' and entry.status or nil
            if STARTED_ORDER_RESULTS[status] then
                return true
            elseif not FINAL_ORDER_RESULTS[status] then
                -- No result yet. Only a request from the same working session
                -- counts: an old question that never became an order must not
                -- keep a customer "busy" forever.
                local okResponse, response = pcall(HironCraftScan.OrderToResponse, listed)
                local requestedAt = okResponse and type(response) == 'table' and tonumber(response.time)
                if requestedAt and now - requestedAt <= PENDING_SIBLING_WINDOW then
                    return true
                end
            end
        end
    end

    return false
end

function QuickReplies:IsTemplateWaitingForOpenOrder(customer, templateKey)
    local template = templateKey and self:GetConfig().templates[templateKey]
    if type(template) ~= 'table' or template.active_orders_only ~= true then return false end
    return not self:HasUnfinishedOrders(customer)
end

function QuickReplies:HasUnfinishedSiblingOrders(order)
    if type(order) ~= 'table' then return false end
    return self:HasUnfinishedOrders(order.customerName, order.responseID)
end

-- A decline or a completion that happened while its conversation character
-- was logged out - on another character, or on the linked account that did
-- the crafting - never got its reply offered: the card is built from a live
-- event, and the event had already passed. Remember which replies were
-- actually sent so the ones that were not can be offered again at login.
local PENDING_STATUS_REPLY_MAX_AGE = 6 * 60 * 60
local MAX_PENDING_STATUS_REPLIES = 5

-- One "your order is done" covers the whole batch, but a batch is not always
-- finished at once: orders are crafted one after another, often on different
-- characters, and each completion that lands when nothing else is left
-- pending would ask to announce itself. Remember that this customer was told,
-- per customer and across character switches, and stay quiet for a while.
local COMPLETION_QUIET_WINDOW = 15 * 60

local function CustomerStatusReplyKey(customer, templateKey)
    return 'customer\31' .. CustomerKey(customer) .. '\31' .. tostring(templateKey)
end

local function StatusReplyKey(order, entry)
    if type(order) ~= 'table' or type(entry) ~= 'table' then return nil end
    local orderID = HironCraftScan.OrderToOrderID(order)
    if not orderID then return nil end
    return table.concat({
        tostring(orderID),
        tostring(entry.craftingOrderID or entry.requestToken or ''),
        tostring(entry.status or ''),
    }, '\31')
end

local function SentStatusReplies()
    return HironCraftScan.Utils.saved(HironCraftScan.DB.settings, 'status_replies_sent', {})
end

function QuickReplies:WasCustomerTold(customer, templateKey, window)
    local sentAt = tonumber(SentStatusReplies()[CustomerStatusReplyKey(customer, templateKey)])
    if not sentAt then return false end

    local now = time and time() or 0
    return (now - sentAt) < (tonumber(window) or COMPLETION_QUIET_WINDOW)
end

function QuickReplies:RememberCustomerTold(customer, templateKey)
    SentStatusReplies()[CustomerStatusReplyKey(customer, templateKey)] = time and time() or 0
end

function QuickReplies:WasStatusReplySent(order, entry)
    local key = StatusReplyKey(order, entry)
    return key ~= nil and SentStatusReplies()[key] ~= nil
end

-- Mark every finished order this customer has as announced, and take the
-- cards that would announce them again off the screen.
function QuickReplies:MarkCustomerCompletionAnswered(customer, templateKey)
    local fulfillment = HironCraftScan.OrderFulfillment
    if type(customer) ~= 'string' or not fulfillment or not fulfillment.GetStatus then return end

    for _, listed in pairs(HironCraftScan.DB.listed_orders or {}) do
        if type(listed) == 'table' and listed.customerName == customer then
            local ok, entry = pcall(fulfillment.GetStatus, fulfillment, listed)
            if ok and type(entry) == 'table' and STATUS_OPTIONS[entry.status]
                and STATUS_OPTIONS[entry.status].oncePerCustomer
            then
                self:RememberSentStatusReply(listed, entry)
            end
        end
    end

    self:DismissTemplateToasts(customer, templateKey)
end

function QuickReplies:RememberSentStatusReply(order, entry)
    local key = StatusReplyKey(order, entry)
    if not key then return end

    local sent = SentStatusReplies()
    local now = time and time() or 0
    for stored, sentAt in pairs(sent) do
        if type(sentAt) ~= 'number' or now - sentAt > PENDING_STATUS_REPLY_MAX_AGE then
            sent[stored] = nil
        end
    end
    sent[key] = now
end

function QuickReplies:BuildOrderStatusOption(order, entry)
    local config = EnsureConfig()
    local statusOption = type(entry) == 'table' and STATUS_OPTIONS[entry.status]
    if
        not config.enabled
        or type(order) ~= 'table'
        or not statusOption
        or type(order.customerName) ~= 'string'
        or order.responseID == nil
        or not IsListedOrder(order.customerName, order.responseID)
    then
        return nil
    end

    -- A check mark set by hand says the crafter already dealt with this order
    -- their own way. Announcing it again is their call, not ours.
    if statusOption.automaticOnly and entry.automatic == false then
        return nil
    end

    -- Two orders can finish in the same moment, or one after another over a
    -- few minutes, and each would ask to announce itself. One "your order is
    -- done" answers for all of them.
    if statusOption.oncePerCustomer
        and (self:WasStatusReplySent(order, entry)
            or self:WasCustomerTold(order.customerName, statusOption.template))
    then
        return nil
    end

    -- Another account of this crafter already told the customer.
    if entry.answeredAt then return nil end

    local customerInfo = HironCraftScan.DB.customers[order.customerName]
    if not customerInfo then
        return nil
    end

    local ok, response = pcall(HironCraftScan.OrderToResponse, order)
    if not ok or type(response) ~= 'table' then
        return nil
    end
    -- The character that talked to this customer may sit on another account,
    -- on another machine, while the order itself was crafted here. The result
    -- of an order is the crafter's own news, and the customer already knows
    -- their name: the greeting told them where to send it. So either of the
    -- two may say it - unlike a conversational reply, which stays with the
    -- character holding the conversation.
    if not self:IsConversationCharacter(response)
        and not (statusOption.crafterMayAnswer and self:IsOrderCrafter(response, entry))
    then
        return nil
    end
    if self:IsTemplateOnRepeatCooldown(order.customerName, statusOption.template) then
        return nil
    end
    if statusOption.lastOrderOnly and self:HasUnfinishedSiblingOrders(order) then
        return nil
    end

    local reply = self:BuildReply(statusOption.template, response)
    if not reply then
        return nil
    end

    return {
        customer = order.customerName,
        message = L(statusOption.message),
        response = response,
        responseID = order.responseID,
        requestToken = response.requestToken,
        requestTime = response.time,
        templateKey = statusOption.template,
        statusEntry = entry,
        rejectionOrderID = entry.status == 'rejected' and entry.craftingOrderID or nil,
        templateLabel = self:GetTemplateLabel(statusOption.template),
        reply = reply,
        label = reply,
        contextLabel = ResponseLabel(response),
    }, customerInfo
end

function QuickReplies:BuildRejectedOrderOption(order, entry)
    local rejected = HironCraftScan.OrderFulfillment
        and HironCraftScan.OrderFulfillment.Status
        and HironCraftScan.OrderFulfillment.Status.Rejected
    if type(entry) ~= 'table' or entry.status ~= rejected then
        return nil
    end
    return self:BuildOrderStatusOption(order, entry)
end

local TOAST_WIDTH = 277
local TOAST_HEIGHT = 53

local function VisibleToasts()
    local result = {}
    for _, toast in ipairs(toastPool) do
        if toast:IsShown() then
            table.insert(result, toast)
        end
    end
    table.sort(result, function(lhs, rhs)
        if lhs.serial == rhs.serial then
            return lhs.optionIndex < rhs.optionIndex
        end
        return lhs.serial > rhs.serial
    end)
    return result
end

local function SetToastDirection(toast, showLeft)
    if toast.showLeft == nil then
        if showLeft then
            HironCraftScan.Frames.flipTextureHorizontally(toast.Background)
        end
    elseif toast.showLeft ~= showLeft then
        HironCraftScan.Frames.flipTextureHorizontally(toast.Background)
    end
    toast.showLeft = showLeft

    toast.Portrait:ClearAllPoints()
    toast.Background:ClearAllPoints()
    toast.Customer:ClearAllPoints()
    toast.Reply:ClearAllPoints()

    if showLeft then
        toast.Portrait:SetPoint('CENTER', toast, 'RIGHT', -26.5, 0)
        toast.Background:SetPoint('RIGHT', toast.Portrait, 'CENTER')
        toast.Customer:SetPoint('TOPLEFT', toast.Background, 'TOPLEFT', 12, -5)
        toast.Customer:SetPoint('TOPRIGHT', toast.Background, 'TOPRIGHT', -30, -5)
        toast.Reply:SetPoint('TOPLEFT', toast.Background, 'TOPLEFT', 12, -24)
        toast.Reply:SetPoint('TOPRIGHT', toast.Background, 'TOPRIGHT', -30, -24)
        toast.Customer:SetJustifyH('RIGHT')
        toast.Reply:SetJustifyH('RIGHT')
    else
        toast.Portrait:SetPoint('CENTER', toast, 'LEFT', 26.5, 0)
        toast.Background:SetPoint('LEFT', toast.Portrait, 'CENTER')
        toast.Customer:SetPoint('TOPLEFT', toast.Background, 'TOPLEFT', 30, -5)
        toast.Customer:SetPoint('TOPRIGHT', toast.Background, 'TOPRIGHT', -12, -5)
        toast.Reply:SetPoint('TOPLEFT', toast.Background, 'TOPLEFT', 30, -24)
        toast.Reply:SetPoint('TOPRIGHT', toast.Background, 'TOPRIGHT', -12, -24)
        toast.Customer:SetJustifyH('LEFT')
        toast.Reply:SetJustifyH('LEFT')
    end
end

local function LayoutToasts()
    local direction = HironCraftScan.Utils.GetSetting('banner_direction')
    local showLeft = direction == HironCraftScan.CONST.LEFT
    local anchor = HironCraftScanScannerMenu and HironCraftScanScannerMenu.PageButton or UIParent
    local previous = nil

    for _, toast in ipairs(VisibleToasts()) do
        SetToastDirection(toast, showLeft)
        toast:ClearAllPoints()
        if previous then
            toast:SetPoint('TOP', previous, 'BOTTOM', 0, -4)
        elseif showLeft then
            toast:SetPoint('TOPRIGHT', anchor, 'BOTTOMRIGHT', 0, -3)
        else
            toast:SetPoint('TOPLEFT', anchor, 'BOTTOMLEFT', 0, -3)
        end
        previous = toast
    end
end

local function DismissToast(toast)
    toast.option = nil
    toast:Hide()
    LayoutToasts()
end

function QuickReplies:InvalidateTemplateToasts(key)
    local changed=false
    for _, toast in ipairs(toastPool) do
        local option = toast.option
        if toast:IsShown() and type(option) == 'table' then
            local affected = option.templateKey == key
            for _, source in ipairs(option.sources or {}) do
                affected = affected or source.templateKey == key
            end
            if affected then toast.option=nil; toast:Hide(); changed=true end
        end
    end
    if changed then LayoutToasts() end
end

function QuickReplies:DismissOrderGreeting(customer, responseID, requestToken)
    local changed = false
    for _, toast in ipairs(toastPool) do
        local option = toast.option
        if toast:IsShown() and option and option.action == ORDER_GREETING_ACTION
            and option.customer == customer and option.responseID == responseID
            and (requestToken == nil or option.requestToken == requestToken)
        then
            toast.option = nil
            toast:Hide()
            changed = true
        end
    end
    if changed then LayoutToasts() end
    return changed
end

local function CreateToast()
    local parent = HironCraftScanScannerMenu or UIParent
    local toast = CreateFrame('Button', nil, parent)
    toast:SetSize(TOAST_WIDTH, TOAST_HEIGHT)
    toast:SetFrameStrata('DIALOG')
    toast:SetClampedToScreen(true)
    toast:RegisterForClicks('LeftButtonUp', 'RightButtonUp')

    toast.Background = toast:CreateTexture(nil, 'BACKGROUND')
    toast.Background:SetAtlas('GarrLanding-MinimapAlertBG')
    toast.Background:SetSize(250, 45)

    toast.Highlight = toast:CreateTexture(nil, 'BORDER')
    toast.Highlight:SetAtlas('auctionhouse-ui-row-highlight')
    toast.Highlight:SetAlpha(0.32)
    toast.Highlight:SetSize(218, 35)
    toast.Highlight:SetPoint('CENTER', toast.Background, 'CENTER')
    toast.Highlight:Hide()

    toast.Portrait = toast:CreateTexture(nil, 'ARTWORK')
    toast.Portrait:SetSize(44, 44)

    toast.CircleMask = toast:CreateMaskTexture(nil, 'ARTWORK')
    toast.CircleMask:SetTexture('Interface\\CharacterFrame\\TempPortraitAlphaMask')
    toast.CircleMask:SetPoint('TOPLEFT', toast.Portrait, 'TOPLEFT', 2, 0)
    toast.CircleMask:SetPoint('BOTTOMRIGHT', toast.Portrait, 'BOTTOMRIGHT', -2, 4)
    toast.Portrait:AddMaskTexture(toast.CircleMask)

    toast.PortraitBorder = toast:CreateTexture(nil, 'OVERLAY')
    toast.PortraitBorder:SetAtlas('Soulbinds_Tree_Ring_Disabled')
    toast.PortraitBorder:SetSize(56, 56)
    toast.PortraitBorder:SetPoint('CENTER', toast.Portrait, 'CENTER', 0, 2)

    toast.Glow = toast:CreateTexture(nil, 'OVERLAY')
    toast.Glow:SetAtlas('Soulbinds_Tree_Ring_Glow')
    toast.Glow:SetSize(54, 54)
    toast.Glow:SetPoint('CENTER', toast.Portrait, 'CENTER', 0, 2)
    toast.Glow:Hide()

    toast.Customer = toast:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    toast.Customer:SetHeight(17)
    toast.Customer:SetWordWrap(false)
    toast.Customer:SetJustifyV('MIDDLE')

    toast.Reply = toast:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    toast.Reply:SetHeight(17)
    toast.Reply:SetWordWrap(false)
    toast.Reply:SetJustifyV('MIDDLE')

    toast:Hide()
    table.insert(toastPool, toast)
    return toast
end

local function GetToast()
    for _, toast in ipairs(toastPool) do
        if not toast:IsShown() then
            return toast
        end
    end
    if #toastPool < MAX_VISIBLE_TOASTS then
        return CreateToast()
    end

    local oldest = toastPool[1]
    for _, toast in ipairs(toastPool) do
        if toast.serial < oldest.serial then
            oldest = toast
        end
    end
    DismissToast(oldest)
    return oldest
end

local function CurrentResponse(option)
    local customerInfo = HironCraftScan.DB.customers[option.customer]
    local responses = customerInfo and customerInfo.responses
    if not responses or not IsListedOrder(option.customer, option.responseID) then
        return nil
    end

    -- A row can be reused in place for a later request. An old toast must not
    -- follow that table into a new conversation about the same recipe.
    if option.requestTime ~= nil or option.requestToken ~= nil then
        if option.response.requestToken ~= option.requestToken
            or (not option.requestToken and option.response.time ~= option.requestTime) then
            return nil
        end
    end

    local response = responses[option.responseID]
    if response == option.response then
        return response
    end

    -- A recipe response can also live under its profession ID. The direct
    -- recipe key may disappear while the alias still owns the listed request;
    -- table identity is the authoritative link in that case.
    for _, stored in pairs(responses) do
        if stored == option.response then
            return stored
        end
    end
    return nil
end

local function FindEquivalentResponse(option)
    local customerInfo = HironCraftScan.DB.customers[option.customer]
    for _, candidate in ipairs(QuickReplies:ResolveResponses(option.customer, customerInfo)) do
        local reply = QuickReplies:BuildReply(option.templateKey, candidate.response)
        if reply == option.reply and ResponseLabel(candidate.response) == option.contextLabel then
            return candidate.response
        end
    end
    return nil
end

function QuickReplies:ResolvePopupResponse(option)
    if option.templateKey ~= REJECTED_ORDER_TEMPLATE_KEY and option.sources then
        -- A generic reply may represent several items/templates. If its
        -- preferred row disappeared, only another original, still-current
        -- source with the same outgoing text can keep the suggestion alive.
        for _, source in ipairs(option.sources) do
            local response = CurrentResponse(source)
            if response and self:BuildReply(source.templateKey, response) == option.reply then
                return response, source.templateKey
            end
        end
        return nil
    end
    local response = CurrentResponse(option)
    if option.templateKey == REJECTED_ORDER_TEMPLATE_KEY then
        local fulfillment = HironCraftScan.OrderFulfillment
        if fulfillment and fulfillment.GetStatus then
            local status = fulfillment:GetStatus({customerName=option.customer,responseID=option.responseID})
            if not status or status.status ~= fulfillment.Status.Rejected
                or (option.rejectionOrderID and tostring(option.rejectionOrderID) ~= tostring(status.craftingOrderID)) then
                return nil
            end
        end
        return self:IsConversationCharacter(response) and response or nil
    end
    return response or FindEquivalentResponse(option)
end

local function SameReplyContext(lhs, rhs)
    if not lhs or not rhs or lhs.customer ~= rhs.customer then
        return false
    end
    if lhs.action == ORDER_GREETING_ACTION or rhs.action == ORDER_GREETING_ACTION then
        return lhs.action == rhs.action
            and lhs.responseID == rhs.responseID
            and lhs.requestToken == rhs.requestToken
    end
    if lhs.reply ~= rhs.reply then return false end
    if lhs.templateKey == REJECTED_ORDER_TEMPLATE_KEY or rhs.templateKey == REJECTED_ORDER_TEMPLATE_KEY then
        -- Rejection actions are tied to an exact order, not a general whisper.
        return lhs.templateKey == rhs.templateKey and lhs.responseID == rhs.responseID
            and lhs.requestToken == rhs.requestToken
    end
    return true
end

local function DismissEquivalentToasts(option)
    for _, other in ipairs(toastPool) do
        if other:IsShown() and SameReplyContext(other.option, option) then
            other.option = nil
            other:Hide()
        end
    end
    LayoutToasts()
end

local function SendOption(toast, option)
    if toast.option ~= option or not toast:IsVisible() then return end
    if option.action == ORDER_GREETING_ACTION then
        local response = CurrentResponse(option)
        if not response or response.greeting_sent then
            print('|cffffd100HironCraftScan:|r ' .. L('Quick reply is no longer available.'))
            DismissEquivalentToasts(option)
            return
        end
        if HironCraftScan.SendOrderGreeting({
            customerName = option.customer,
            responseID = option.responseID,
        }, true) == false then
            return
        end
        -- The normal row-click path refreshes the table after greeting. The
        -- toast is a separate click path, so do the same here or its first
        -- status icon remains a stale red X until another UI event arrives.
        if HironCraftScanCraftingOrderPage
            and HironCraftScanCraftingOrderPage.ShowGeneric then
            HironCraftScanCraftingOrderPage:ShowGeneric()
        end
        DismissEquivalentToasts(option)
        return
    end

    local response, templateKey = QuickReplies:ResolvePopupResponse(option)
    local reply = response and QuickReplies:BuildReply(templateKey or option.templateKey, response) or nil
    if not reply then
        print('|cffffd100HironCraftScan:|r ' .. L('Quick reply is no longer available.'))
        DismissEquivalentToasts(option)
        return
    end

    local statusEntry = option.statusEntry
    local statusOption = statusEntry and STATUS_OPTIONS[statusEntry.status]
    if statusOption and statusOption.oncePerCustomer
        and QuickReplies:WasStatusReplySent(
            { customerName = option.customer, responseID = option.responseID }, statusEntry)
    then
        print('|cffffd100HironCraftScan:|r ' .. L('Quick reply is no longer available.'))
        DismissEquivalentToasts(option)
        return
    end

    -- The order may have finished between the card appearing and this click.
    if QuickReplies:IsTemplateWaitingForOpenOrder(option.customer, templateKey or option.templateKey) then
        print('|cffffd100HironCraftScan:|r ' .. L('Quick reply is no longer available.'))
        DismissEquivalentToasts(option)
        return
    end

    -- Only conversational answers: an order event that repeats itself is a
    -- new attempt at the same order, and the customer has to hear about it.
    if not option.statusEntry and QuickReplies:IsReplyTheLastThingSaid(option.customer, reply) then
        print('|cffffd100HironCraftScan:|r ' .. L('Quick reply is no longer available.'))
        DismissEquivalentToasts(option)
        return
    end

    -- Long reagent audits are split only on this explicit click; the complete
    -- reply shares one cooldown. Each whisper is recorded in chat history.
    if QuickReplies:IsReplyOnCooldown(option.customer, reply) then return end
    local messages = #reply > MAX_CHAT_BYTES and HironCraftScan.Utils.SplitResponse(reply) or { reply }
    if HironCraftScan.Utils.SendResponses(messages, option.customer, true) == false then return end
    QuickReplies:RememberSentReply(option.customer, reply)
    QuickReplies:RememberSentTemplate(option.customer, templateKey or option.templateKey)
    if option.statusEntry then
        local statusOrder = { customerName = option.customer, responseID = option.responseID }
        QuickReplies:RememberSentStatusReply(statusOrder, option.statusEntry)
        local fulfillment = HironCraftScan.OrderFulfillment
        if fulfillment and fulfillment.MarkStatusAnswered then
            fulfillment:MarkStatusAnswered(statusOrder)
        end
        local statusOption = STATUS_OPTIONS[option.statusEntry.status]
        if statusOption and statusOption.oncePerCustomer then
            QuickReplies:MarkCustomerCompletionAnswered(option.customer, option.templateKey)
            QuickReplies:RememberCustomerTold(option.customer, option.templateKey)
        end
    end
    DismissEquivalentToasts(option)
end

function QuickReplies:SendTopReply(userInitiated)
    if userInitiated ~= true then return false end
    local toast = VisibleToasts()[1]
    if not toast or not toast:IsVisible() then return false end
    SendOption(toast, toast.option)
    return true
end

-- Key bindings and mouse clicks share the same context checks and cooldown.
function HironCraftScanSendQuickReply()
    QuickReplies:SendTopReply(true)
end

local function SetupToast(toast, option, customerInfo, serial, optionIndex)
    toast.serial = serial
    toast.optionIndex = optionIndex
    toast.option = option
    local professionIcon = option.response.professionID
        and C_TradeSkillUI.GetTradeSkillTexture(option.response.professionID)
    toast.Portrait:SetTexture(professionIcon
        or (HironCraftScan.Utils.GetCurrentProfessionIcon
            and HironCraftScan.Utils.GetCurrentProfessionIcon())
        or 4620670)
    toast.Customer:SetText(HironCraftScan.ColorizePlayerName(option.customer, customerInfo.guid))
    toast.Reply:SetText(Shorten(DisplayText(option.label), 54))

    toast:SetScript('OnClick', function(self, button)
        if button == 'RightButton' then
            DismissToast(self)
        else
            SendOption(self, option)
        end
    end)
    toast:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, self.showLeft and 'ANCHOR_LEFT' or 'ANCHOR_RIGHT')
        GameTooltip:SetText(option.templateLabel, 1, 0.82, 0)
        GameTooltip:AddLine('"' .. option.message .. '"', 0.75, 0.75, 0.75, true)
        GameTooltip:AddLine(' ')
        GameTooltip:AddLine(option.reply, 1, 1, 1, true)
        if option.contextLabel then
            GameTooltip:AddLine(' ')
            GameTooltip:AddLine(option.contextLabels and table.concat(option.contextLabels, '\n')
                or option.contextLabel, 0.7, 0.7, 0.7, true)
        end
        GameTooltip:AddLine(' ')
        GameTooltip:AddLine(L('Quick reply click help'), 1, 0.82, 0, true)
        GameTooltip:AddLine(L('Quick reply dismiss help'), 1, 0.82, 0, true)
        GameTooltip:Show()
        self.PortraitBorder:SetAtlas('Soulbinds_Tree_Ring')
        self.Highlight:Show()
        self.Glow:Show()
    end)
    toast:SetScript('OnLeave', function(self)
        GameTooltip:Hide()
        self.PortraitBorder:SetAtlas('Soulbinds_Tree_Ring_Disabled')
        self.Highlight:Hide()
        self.Glow:Hide()
    end)
    toast:Show()
end

-- A craft request received in whisper is matched asynchronously. Offer its
-- generated greeting only after the new row exists, so the click is bound to
-- the new request token rather than an older completed order for that customer.
function QuickReplies:ShowOrderGreeting(customer, message, customerInfo, responses)
    if not EnsureConfig().enabled or type(customerInfo) ~= 'table' then
        return false
    end

    local selected
    local contextLabels = {}
    local seenLabels = {}
    for _, response in ipairs(responses or {}) do
        if type(response) == 'table'
            and response.responseID ~= nil
            and not response.greeting_sent
            and IsListedOrder(customer, response.responseID)
        then
            selected = selected or response
            local label = ResponseLabel(response)
            if label and not seenLabels[label] then
                seenLabels[label] = true
                contextLabels[#contextLabels + 1] = label
            end
        end
    end
    if not selected then return false end

    local reply
    if selected.destination_only_greeting == true
        and HironCraftScan.BuildOrderDestinationMessage then
        reply = HironCraftScan.BuildOrderDestinationMessage(selected)
    end
    if not reply then
        reply = type(selected.message) == 'table'
            and table.concat(selected.message, ' ') or ''
    end
    if reply == '' then
        reply = L('Reply to new crafting request')
    end
    local option = {
        action = ORDER_GREETING_ACTION,
        customer = customer,
        message = message,
        response = selected,
        responseID = selected.responseID,
        requestToken = selected.requestToken,
        requestTime = selected.time,
        reply = reply,
        label = reply,
        templateLabel = L('New crafting request'),
        contextLabel = contextLabels[1],
        contextLabels = contextLabels,
    }

    DismissEquivalentToasts(option)
    popupSerial = popupSerial + 1
    SetupToast(GetToast(), option, customerInfo, popupSerial, 1)
    LayoutToasts()
    return true
end

local function PreferPopupOption(existing, candidate)
    local activeOrder = HironCraftScan.State.activeOrder
    local existingIsActive = activeOrder
        and activeOrder.customerName == existing.customer
        and activeOrder.responseID == existing.responseID
    local candidateIsActive = activeOrder
        and activeOrder.customerName == candidate.customer
        and activeOrder.responseID == candidate.responseID
    if existingIsActive ~= candidateIsActive then
        return candidateIsActive
    end

    local existingTime = tonumber(existing.response.time) or 0
    local candidateTime = tonumber(candidate.response.time) or 0
    if existingTime ~= candidateTime then
        return candidateTime > existingTime
    end
    return tostring(candidate.responseID) > tostring(existing.responseID)
end

local function HasMultipleKeys(values)
    local first = next(values)
    return first ~= nil and next(values, first) ~= nil
end

function QuickReplies:BuildPopupOptions(customer, message, responses, templateKeys)
    local options = {}
    local bySignature = {}
    for _, candidate in ipairs(responses) do
        for _, templateKey in ipairs(templateKeys) do
            local reply = self:BuildReply(templateKey, candidate.response)
            if reply and self:IsReplyTheLastThingSaid(customer, reply) then
                reply = nil
            end
            if reply then
                local contextLabel = ResponseLabel(candidate.response)
                local option = {
                    customer = customer,
                    message = message,
                    response = candidate.response,
                    responseID = candidate.responseID,
                    requestToken = candidate.response.requestToken,
                    requestTime = candidate.response.time,
                    templateKey = templateKey,
                    templateLabel = self:GetTemplateLabel(templateKey),
                    reply = reply,
                    contextLabel = contextLabel,
                }
                local source = {}
                for key, value in pairs(option) do source[key] = value end
                option.sources = {source}
                -- Different items can yield the same conversational answer
                -- ("hey hey", "omw"). Only the text actually sent distinguishes
                -- these options; event-only rejection actions remain per order.
                local signature = templateKey == REJECTED_ORDER_TEMPLATE_KEY
                    and table.concat({ templateKey, reply, tostring(candidate.responseID) }, '\30')
                    or reply
                local existing = bySignature[signature]
                if not existing then
                    bySignature[signature] = option
                    table.insert(options, option)
                else
                    local sources = existing.sources
                    sources[#sources + 1] = source
                    if PreferPopupOption(existing, option) then
                        for key, value in pairs(option) do existing[key] = value end
                    end
                    existing.sources = sources
                end
            end
        end
    end

    local responseIDs = {}
    local templateIDs = {}
    for _, option in ipairs(options) do
        responseIDs[tostring(option.responseID)] = true
        templateIDs[option.templateKey] = true
    end
    local multipleResponses = HasMultipleKeys(responseIDs)
    local multipleTemplates = HasMultipleKeys(templateIDs)
    for _, option in ipairs(options) do
        local seenLabels = {}
        option.contextLabels = {}
        for _, source in ipairs(option.sources) do
            if not seenLabels[source.contextLabel] then
                seenLabels[source.contextLabel] = true
                option.contextLabels[#option.contextLabels + 1] = source.contextLabel
            end
        end
        local label = option.reply
        if multipleResponses then
            label = option.contextLabel .. ': ' .. label
        end
        if multipleTemplates then
            label = option.templateLabel .. ': ' .. label
        end
        option.label = label
    end

    return options
end


local function ShowPopup(customer, message, customerInfo, responses, templateKeys)
    local options = QuickReplies:BuildPopupOptions(customer, message, responses, templateKeys)

    -- Avoid silently hiding one of several ambiguous orders. Very large sets
    -- are left to the normal order page instead of presenting a partial choice.
    if #options == 0 or #options > MAX_OPTIONS_PER_POPUP then
        return false
    end

    popupSerial = popupSerial + 1
    for index, option in ipairs(options) do
        -- A customer may express the same intent in consecutive, differently
        -- worded whispers (for example "will send" followed by "sent"). Keep
        -- only the newest actionable card for that reply/order context; the
        -- older card may reference a response table replaced by the refresh.
        DismissEquivalentToasts(option)
        SetupToast(GetToast(), option, customerInfo, popupSerial, index)
    end
    LayoutToasts()
    return true
end

local lastShown = {}
function QuickReplies:OnWhisper(customer, message, customerInfo)
    if HironCraftScan.Scanner and HironCraftScan.Scanner.IsCrafterAdvertisement
        and HironCraftScan.Scanner.IsCrafterAdvertisement(message) then return end
    local config = EnsureConfig()
    if not config.enabled then
        return
    end

    local templateKeys = self:Classify(message)
    if #templateKeys == 0 then
        return
    end

    local offerable = {}
    for _, templateKey in ipairs(templateKeys) do
        if not self:IsTemplateOnRepeatCooldown(customer, templateKey)
            and not self:IsTemplateWaitingForOpenOrder(customer, templateKey)
        then
            offerable[#offerable + 1] = templateKey
        end
    end
    templateKeys = offerable
    if #templateKeys == 0 then
        return
    end

    local responses = self:ResolveResponses(customer, customerInfo)
    if #responses == 0 then
        return
    end

    local normalized = Normalize(message)
    local now = GetTime()
    local previous = lastShown[customer]
    if
        previous
        and previous.message == normalized
        and now - previous.time < config.dedup_seconds
    then
        return
    end

    if ShowPopup(customer, message, customerInfo, responses, templateKeys) then
        lastShown[customer] = {
            message = normalized,
            time = now,
        }
    end
end

local shownRejections = {}
function QuickReplies:GetRejectedOrderSuggestionKeys(order, entry)
    local keys = {}
    local seen = {}
    local function add(kind, value)
        if value == nil or value == '' then return end
        local key = kind .. '\30' .. tostring(value)
        if not seen[key] then
            seen[key] = true
            keys[#keys + 1] = key
        end
    end

    -- Keep every stable identity as an alias. Reconciliation may initially
    -- omit craftingOrderID and populate it on a later ACK; revisions and
    -- updatedAt change on those updates and must not create another offer.
    local status = type(entry) == 'table' and tostring(entry.status) or ''
    add('crafting-order', entry and entry.craftingOrderID and (status .. ':' .. entry.craftingOrderID))
    add('request-token', entry and entry.requestToken and (status .. ':' .. entry.requestToken))
    add('order', order and (status .. ':' .. tostring(HironCraftScan.OrderToOrderID(order))))
    if type(order) == 'table' then
        add('response', table.concat({
            status,
            tostring(order.customerName or ''),
            tostring(order.responseID or ''),
        }, '\31'))
    end
    return keys
end

-- A decline can be recorded before its material list is captured, which is
-- what fast clicking through the queue does. Offering the reply right then
-- produced "I couldn't find the material details"; wait for the list first.
local MATERIAL_WAIT_DELAYS = { 0.4, 1, 2, 3 }

function QuickReplies:IsWaitingForMaterials(order, entry)
    if type(entry) ~= 'table' or entry.status ~= 'rejected' or not HironCraftScan.ReagentAudit then
        return false
    end
    local config = EnsureConfig()
    local template = config.templates and config.templates[REJECTED_ORDER_TEMPLATE_KEY]
    local response = type(template) == 'table' and template.response or ''
    if type(response) ~= 'string' or not response:find('{reagent_issues}', 1, true) then
        return false
    end
    -- A list built from the recipe alone carries no customer amounts yet.
    local snapshot = HironCraftScan.ReagentAudit.GetForOrder(order)
    return type(snapshot) ~= 'table' or snapshot.complete ~= true
end

-- A card that was offered while the order was still open stays on screen
-- after it is finished, and a blind click sends "omw" right behind "Done,
-- ty". Take those cards away as soon as the order has its result.
-- Every card of one template for one customer, used when a single reply has
-- already answered for all of them.
function QuickReplies:DismissTemplateToasts(customer, templateKey)
    if type(customer) ~= 'string' or templateKey == nil then return 0 end

    local dismissed = 0
    for _, toast in ipairs(toastPool) do
        local option = toast.option
        if toast:IsShown() and type(option) == 'table' and option.customer == customer
            and option.templateKey == templateKey
        then
            DismissToast(toast)
            dismissed = dismissed + 1
        end
    end

    return dismissed
end

function QuickReplies:DismissRepliesWaitingForOpenOrder(customer)
    if type(customer) ~= 'string' then return 0 end

    local dismissed = 0
    for _, toast in ipairs(toastPool) do
        local option = toast.option
        if toast:IsShown() and type(option) == 'table' and option.customer == customer
            and self:IsTemplateWaitingForOpenOrder(customer, option.templateKey)
        then
            DismissToast(toast)
            dismissed = dismissed + 1
        end
    end

    return dismissed
end

function QuickReplies:OnOrderFulfillmentUpdated(order, entry, attempt)
    if type(entry) == 'table' and FINAL_ORDER_RESULTS[entry.status] and type(order) == 'table' then
        self:DismissRepliesWaitingForOpenOrder(order.customerName)
    end

    if self:IsWaitingForMaterials(order, entry) then
        local delay = MATERIAL_WAIT_DELAYS[(attempt or 0) + 1]
        if delay and C_Timer and C_Timer.After then
            C_Timer.After(delay, function()
                local fulfillment = HironCraftScan.OrderFulfillment
                local current = fulfillment and fulfillment:GetStatus(order) or entry
                QuickReplies:OnOrderFulfillmentUpdated(order, current, (attempt or 0) + 1)
            end)
            return
        end
    end

    local option, customerInfo = self:BuildOrderStatusOption(order, entry)
    if not option then
        return
    end

    local rejectionKeys = self:GetRejectedOrderSuggestionKeys(order, entry)
    local gameOrderID = entry.craftingOrderID and tostring(entry.craftingOrderID)
    for _, key in ipairs(rejectionKeys) do
        local previous = shownRejections[key]
        if previous and (not gameOrderID or previous == true or previous == gameOrderID) then
            -- Upgrade legacy aliases once the game order ID becomes known.
            if gameOrderID then
                for _, alias in ipairs(rejectionKeys) do shownRejections[alias] = gameOrderID end
            end
            return
        end
    end
    for _, key in ipairs(rejectionKeys) do shownRejections[key] = gameOrderID or true end

    for _, toast in ipairs(toastPool) do
        local old = toast.option
        if type(old) == 'table' and old.templateKey == option.templateKey
            and old.customer == option.customer and old.responseID == option.responseID then
            toast:Hide(); toast.option = nil
        end
    end

    popupSerial = popupSerial + 1
    SetupToast(GetToast(), option, customerInfo, popupSerial, 1)
    LayoutToasts()
end

-- Offer the replies whose moment passed while this character was elsewhere.
function QuickReplies:OfferPendingOrderStatusReplies()
    local fulfillment = HironCraftScan.OrderFulfillment
    if not fulfillment or not fulfillment.GetStatuses then return 0 end
    if not EnsureConfig().enabled then return 0 end

    local now = time and time() or 0
    local pending = {}
    for _, entry in pairs(fulfillment:GetStatuses() or {}) do
        if type(entry) == 'table' and STATUS_OPTIONS[entry.status]
            and type(entry.customerName) == 'string' and entry.responseID ~= nil
        then
            local updatedAt = tonumber(entry.updatedAt) or 0
            local order = { customerName = entry.customerName, responseID = entry.responseID }
            if now - updatedAt <= PENDING_STATUS_REPLY_MAX_AGE
                and not self:WasStatusReplySent(order, entry)
            then
                pending[#pending + 1] = { order = order, entry = entry, updatedAt = updatedAt }
            end
        end
    end

    -- Newest first: an old decline matters less than the one just made, and
    -- the stack of cards stays short.
    table.sort(pending, function(lhs, rhs) return lhs.updatedAt > rhs.updatedAt end)

    local offered = 0
    for index, candidate in ipairs(pending) do
        if index > MAX_PENDING_STATUS_REPLIES then break end
        -- Everything that decides whether this reply may be offered at all -
        -- the listing, the conversation character, the template - is checked
        -- by the normal path.
        self:OnOrderFulfillmentUpdated(candidate.order, candidate.entry)
        offered = offered + 1
    end

    return offered
end

HironCraftScan.Utils.onLoad(function()
    EnsureConfig()

    -- Linked-account statuses and the order list both arrive after load, so
    -- look once things have settled, and once more for a slow sync.
    if C_Timer and C_Timer.After then
        C_Timer.After(8, function() QuickReplies:OfferPendingOrderStatusReplies() end)
        C_Timer.After(25, function() QuickReplies:OfferPendingOrderStatusReplies() end)
    end
end)

HironCraftScan.Events:Register('ORDER_FULFILLMENT_UPDATED', function(order, entry)
    QuickReplies:OnOrderFulfillmentUpdated(order, entry)
end)
