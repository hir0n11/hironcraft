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

-- Adding another built-in quick reply only requires another definition here.
-- The SavedVariables defaults and the configuration UI are generated from
-- this list.
local DEFAULT_TEMPLATES = {
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
    config.schema_version = 2

    local templates = HironCraftScan.Utils.saved(config, 'templates', {})
    for _, definition in ipairs(DEFAULT_TEMPLATES) do
        local template = HironCraftScan.Utils.saved(templates, definition.key, {})
        if template.enabled == nil then
            template.enabled = true
        end
        if template.keywords == nil then
            template.keywords = definition.keywords
        end
        if template.response == nil then
            template.response = definition.response
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
        table.insert(definitions, {
            key = definition.key,
            label = definition.key,
            custom = false,
        })
    end

    local custom = {}
    for key, template in pairs(config.templates) do
        if not builtinKeys[key] and type(template) == 'table' and template.custom then
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
            if definition.custom then
                return definition.label
            end
            return L('dialog.quick_reply.' .. key .. '.enabled')
        end
    end
    return key
end

function QuickReplies:IsLabelAvailable(label)
    label = Trim(label):lower()
    if label == '' then
        return false
    end
    for _, definition in ipairs(self:GetDefinitions()) do
        if definition.label:lower() == label then
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
    }
    self:NotifyConfigChanged()
    return key
end

function QuickReplies:DeleteCustomTemplate(key)
    local config = EnsureConfig()
    local template = config.templates[key]
    if not template or not template.custom or builtinKeys[key] then
        return false
    end
    config.templates[key] = nil
    self:NotifyConfigChanged()
    return true
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

local function KeywordScore(message, keyword)
    keyword = Normalize(keyword)
    if keyword == '' then
        return nil
    end

    local paddedMessage = ' ' .. message .. ' '
    if not paddedMessage:find(' ' .. keyword .. ' ', 1, true) then
        return nil
    end

    -- Prefer longer phrases ("who to send") over contained short words
    -- ("who") so ORDER wins over NAME in that example.
    return CountWords(keyword) * 1000 + #keyword
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

    local bestScore = nil
    local matched = {}
    for _, definition in ipairs(self:GetDefinitions()) do
        local template = config.templates[definition.key]
        if template and template.enabled then
            local templateScore = nil
            local keywords = HironCraftScan.Config.SubstituteTags(template.keywords or '')
            for keyword in keywords:gmatch('[^,\n]+') do
                local score = KeywordScore(normalized, keyword)
                if score and (not templateScore or score > templateScore) then
                    templateScore = score
                end
            end

            if templateScore then
                if not bestScore or templateScore > bestScore then
                    bestScore = templateScore
                    matched = { definition.key }
                elseif templateScore == bestScore then
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
    if not template or not template.enabled or template.response == '' then
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
    if reply == '' or reply:find('%b{}') or #reply > MAX_CHAT_BYTES then
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
    local crafter = response.crafterName
        or HironCraftScan.NameAndRealmToName(response.crafterFullName)
    local subject = response.professionName
    if response.itemID then
        subject = select(1, GetItemInfo(response.itemID)) or subject
    end
    if subject then
        return crafter .. ' / ' .. subject
    end
    return crafter
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
    return CurrentResponse(option) or FindEquivalentResponse(option)
end

local function SameReplyContext(lhs, rhs)
    return lhs
        and rhs
        and lhs.customer == rhs.customer
        and lhs.templateKey == rhs.templateKey
        and lhs.reply == rhs.reply
        and lhs.contextLabel == rhs.contextLabel
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
    local response = QuickReplies:ResolvePopupResponse(option)
    local reply = response and QuickReplies:BuildReply(option.templateKey, response) or nil
    if not reply then
        print('|cffffd100HironCraftScan:|r ' .. L('Quick reply is no longer available.'))
        DismissEquivalentToasts(option)
        return
    end

    -- Exactly one entry is intentionally passed. SendResponses uses the same
    -- whisper path as greetings, and CHAT_MSG_WHISPER_INFORM records it in the
    -- customer's existing chat_history.
    HironCraftScan.Utils.SendResponses({ reply }, option.customer)
    DismissEquivalentToasts(option)
end

local function SetupToast(toast, option, customerInfo, serial, optionIndex)
    toast.serial = serial
    toast.optionIndex = optionIndex
    toast.option = option
    toast.Portrait:SetTexture(
        C_TradeSkillUI.GetTradeSkillTexture(option.response.professionID)
            or HironCraftScan.Utils.GetCurrentProfessionIcon()
            or 4620670
    )
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
            GameTooltip:AddLine(option.contextLabel, 0.7, 0.7, 0.7, true)
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
            if reply then
                local contextLabel = ResponseLabel(candidate.response)
                local option = {
                    customer = customer,
                    message = message,
                    response = candidate.response,
                    responseID = candidate.responseID,
                    templateKey = templateKey,
                    templateLabel = self:GetTemplateLabel(templateKey),
                    reply = reply,
                    contextLabel = contextLabel,
                }
                local signature = table.concat({ templateKey, reply, contextLabel }, '\30')
                local existing = bySignature[signature]
                if not existing then
                    bySignature[signature] = option
                    table.insert(options, option)
                elseif PreferPopupOption(existing, option) then
                    for key, value in pairs(option) do
                        existing[key] = value
                    end
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
        SetupToast(GetToast(), option, customerInfo, popupSerial, index)
    end
    LayoutToasts()
    return true
end

local lastShown = {}
function QuickReplies:OnWhisper(customer, message, customerInfo)
    local config = EnsureConfig()
    if not config.enabled then
        return
    end

    local templateKeys = self:Classify(message)
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

HironCraftScan.Utils.onLoad(function()
    EnsureConfig()
end)
