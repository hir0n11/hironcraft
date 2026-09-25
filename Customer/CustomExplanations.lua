local HironCraftScan = select(2, ...)

local LID = HironCraftScan.CONST.TEXT;
local function L(id)
    return HironCraftScan.LOCAL:GetText(id);
end

local allowedContext = {
    crafter = true,
    item = true,
    profession = true,
    profession_link = true,
    commission = true,
    reagent_issues = true,
}

local function UnknownPlaceholders(text)
    local expanded = HironCraftScan.Config.SubstituteTags(text)
    local unknown = {}
    for placeholder in expanded:gmatch('{(.-)}') do
        if not allowedContext[placeholder] then
            table.insert(unknown, '{' .. placeholder .. '}')
        end
    end
    return unknown
end

local function ExplanationTextValidator(_, text)
    local unknown = UnknownPlaceholders(text)
    if #unknown > 0 then
        return { error = string.format(L('Unknown quick reply placeholders'), table.concat(unknown, ', ')) }
    end
end

local CustomExplanations = {}
HironCraftScan.CustomExplanations = CustomExplanations

-- A customer can have several unfinished requests at once. Keep a manual
-- context choice in memory only: it must not outlive a reload or silently bind
-- a future request to an old response ID.
local selectedContexts = {}

local function IsTerminalOrder(order)
    local fulfillment = HironCraftScan.OrderFulfillment
    if not fulfillment or not fulfillment.GetStatus or not fulfillment.Status then
        return false
    end
    local ok, entry = pcall(fulfillment.GetStatus, fulfillment, order)
    if not ok or type(entry) ~= 'table' then
        return false
    end
    local status = entry.status
    return status == fulfillment.Status.Crafted
        or status == fulfillment.Status.Fulfilled
        or status == fulfillment.Status.Rejected
end

local function ResponseContext(response)
    local ok, context = pcall(HironCraftScan.BuildResponseContext, response)
    return ok and type(context) == 'table' and context or nil
end

-- Unlike automatic quick replies, this list intentionally spans every active
-- inquiry from the customer. That is what lets the user answer "where do I
-- send both items?" after two different profession requests.
function CustomExplanations:GetPendingResponses(target, includeRejected)
    local customerInfo = HironCraftScan.DB.customers and HironCraftScan.DB.customers[target]
    local listedOrders = HironCraftScan.DB.listed_orders
    if type(customerInfo) ~= 'table'
        or type(customerInfo.responses) ~= 'table'
        or type(listedOrders) ~= 'table'
    then
        selectedContexts[target] = nil
        return {}
    end

    local candidates, seen = {}, {}
    for responseKey, response in pairs(customerInfo.responses) do
        if type(response) == 'table' and not seen[response] then
            seen[response] = true
            local responseID = response.responseID or responseKey
            local order = { customerName = target, responseID = responseID }
            local orderID = HironCraftScan.OrderToOrderID(order)
            if response.crafterFullName
                and response.professionID
                and listedOrders[orderID]
                and (not IsTerminalOrder(order) or (includeRejected
                    and HironCraftScan.OrderFulfillment:GetStatus(order).status == HironCraftScan.OrderFulfillment.Status.Rejected))
            then
                candidates[#candidates + 1] = {
                    order = order,
                    response = response,
                    responseID = responseID,
                    requestToken = response.requestToken,
                    responseTime = response.time,
                }
            end
        end
    end

    table.sort(candidates, function(lhs, rhs)
        local lhsTime = tonumber(lhs.response.time) or 0
        local rhsTime = tonumber(rhs.response.time) or 0
        if lhsTime == rhsTime then
            return tostring(lhs.responseID) < tostring(rhs.responseID)
        end
        return lhsTime < rhsTime
    end)
    return candidates
end

local function MatchesSelection(candidate, selection)
    if not selection or candidate.responseID ~= selection.responseID then
        return false
    end
    if selection.requestToken ~= nil or candidate.requestToken ~= nil then
        return candidate.requestToken == selection.requestToken
    end
    return candidate.response == selection.response
        and candidate.responseTime == selection.responseTime
end

function CustomExplanations:GetSelectedResponse(target, pending)
    local selection = selectedContexts[target]
    if not selection then return nil end
    for _, candidate in ipairs(pending or self:GetPendingResponses(target)) do
        if MatchesSelection(candidate, selection) then
            return candidate.response
        end
    end
    selectedContexts[target] = nil
    return nil
end

function CustomExplanations:SetSelectedResponse(target, candidate)
    if not candidate then
        selectedContexts[target] = nil
        return
    end
    selectedContexts[target] = {
        response = candidate.response,
        responseID = candidate.responseID,
        requestToken = candidate.requestToken,
        responseTime = candidate.responseTime,
    }
end

local function ResponseSubject(response, context)
    if response.itemID then
        local link = HironCraftScan.Utils.GetReplyItemLink(response.itemID, response.itemLink)
        if type(link) == 'string' and link ~= '' then return link end
    end
    return context.profession
        or response.equipmentLabel or response.professionName
        or HironCraftScan.Utils.ProfessionNameByID(response.parentProfID or response.professionID)
end

local function Assignment(candidate)
    local response = candidate.response
    local context = ResponseContext(response)
    if not context or not context.crafter then return nil end
    local subject = ResponseSubject(response, context)
    if not subject then return nil end
    -- Keep the separator inside WoW's universally supported font range. The
    -- arrow glyph renders as an empty square with some client fonts/locales.
    return subject .. ' - ' .. context.crafter,
        table.concat({
            response.itemID and ('item:' .. tostring(response.itemID))
                or ('profession:' .. tostring(response.parentProfID or response.professionID)),
            tostring(response.crafterFullName),
        }, '\31')
end

function CustomExplanations:BuildAssignments(target, pending)
    local result, seen = {}, {}
    for _, candidate in ipairs(pending or self:GetPendingResponses(target)) do
        local text, key = Assignment(candidate)
        if text and not seen[key] then
            seen[key] = true
            result[#result + 1] = text
        end
    end
    return result
end

local function SendManualMessages(messages, target)
    return HironCraftScan.Utils.SendResponses(messages, target, true)
end

local function SendManualText(text, target)
    return SendManualMessages(HironCraftScan.Utils.SplitResponse(text), target)
end

function CustomExplanations:SendAssignments(target)
    local assignments = self:BuildAssignments(target)
    if #assignments == 0 then
        print('|cffffd100HironCraftScan:|r ' .. L('No unfinished order contexts are available.'))
        return false
    end
    local message = table.concat(assignments, '; ')
    -- Prefer one compact whisper. If several links exceed Blizzard's 255-byte
    -- chat limit, keep each mapping intact as its own line from the same click.
    return SendManualMessages(#message <= 255 and { message } or assignments, target)
end

-- Custom explanations are follow-up messages for the selected customer, so use
-- the same order selection and substitution rules as contextual quick replies.
-- Plain explanations continue to work even when the customer has no order.
function CustomExplanations:Render(text, target)
    local raw = HironCraftScan.Config.SubstituteTags(text)
    if not raw:find('%b{}') then
        return raw
    end

    local customerInfo = HironCraftScan.DB.customers and HironCraftScan.DB.customers[target]
    local quickReplies = HironCraftScan.QuickReplies
    if not customerInfo or not quickReplies or not quickReplies.ResolveResponses then
        return nil
    end

    local wantsAudit = raw:find('{reagent_issues}', 1, true)
    local pending = self:GetPendingResponses(target, wantsAudit)
    if wantsAudit and HironCraftScan.OrderFulfillment then
        local rejected = {}
        for _, candidate in ipairs(pending) do
            local entry = HironCraftScan.OrderFulfillment:GetStatus(candidate.order)
            if entry and entry.status == HironCraftScan.OrderFulfillment.Status.Rejected then
                rejected[#rejected+1] = candidate
            end
        end
        pending = rejected
    end
    local selected = self:GetSelectedResponse(target, pending)
    local candidates = {}
    if selected then
        candidates[1] = { response = selected }
    else
        local pendingResponses = {}
        for _, candidate in ipairs(pending) do
            pendingResponses[candidate.response] = true
        end
        for _, candidate in ipairs(quickReplies:ResolveResponses(target, customerInfo)) do
            if pendingResponses[candidate.response] then
                candidates[#candidates + 1] = candidate
            end
        end
        -- The reply tracker can still point at an older inquiry that just
        -- finished. Fall back to the newest unfinished row instead of reviving
        -- the completed context or refusing a valid manual follow-up.
        if #candidates == 0 and #pending > 0 then
            candidates[1] = pending[#pending]
        end
    end
    for _, candidate in ipairs(candidates) do
        local context = HironCraftScan.BuildResponseContext(candidate.response)
        if context then
            local rendered = HironCraftScan.Utils.FString(raw, context)
            if not rendered:find('%b{}') then
                return rendered
            end
        end
    end
    return nil
end

function CustomExplanations:Send(text, target)
    local rendered = self:Render(text, target)
    if not rendered then
        print('|cffffd100HironCraftScan:|r ' .. L('Custom explanation context unavailable.'))
        return false
    end
    return SendManualText(rendered, target)
end

HironCraftScan_CustomExplanationsButtonMixin = {}

function HironCraftScan_CustomExplanationsButtonMixin:OnLoad()
    self:SetText(L("Custom Explanations"))
    self:FitToText();
end

local function OnCreate()
    local explanations = HironCraftScan.DB.settings.explanations;

    local Validator = function(index, label)
        if label == 'rev' then
            return { error = "'rev' is a reserved label" };
        end
        if explanations and explanations[label] then
            return { error = L(LID.EXPLANATION_DUPLICATE_LABEL) };
        end
    end

    local OnAccept = function(label, text)
        explanations[label] = text;
        HironCraftScanComm:ShareCustomExplanations(explanations);
    end

    local elements = {
        {
            type = HironCraftScan.Dialog.Element.Text,
            text = L(LID.EXPLANATION_LABEL_DESC),
        },
        {
            type = HironCraftScan.Dialog.Element.EditBox,
            Validator = Validator,
        },
        {
            type = HironCraftScan.Dialog.Element.Text,
            text = L(LID.EXPLANATION_TEXT_DESC) .. '\n' .. L('Custom explanation tags description'),
        },
        {
            type = HironCraftScan.Dialog.Element.EditBox,
            multiline = true,
            Validator = ExplanationTextValidator,
        },
    }
    HironCraftScan.Dialog.Show({
        key = "custom_explanations",
        title = L("Create an Explanation"),
        submit = L("Save"),
        OnAccept = OnAccept,
        elements = elements,
        width = 450,
    })
end

local function OnModify(label, text)
    local explanations = HironCraftScan.DB.settings.explanations;

    local Validator = function(index, newLabel)
        if label ~= newLabel and explanations and explanations[newLabel] then
            return { error = L(LID.EXPLANATION_DUPLICATE_LABEL) };
        end
    end

    local OnAccept = function(newLabel, text)
        if newLabel ~= label then
            explanations[label] = nil;
        end
        explanations[newLabel] = text;
        HironCraftScanComm:ShareCustomExplanations(explanations);
    end

    local elements = {
        {
            type = HironCraftScan.Dialog.Element.Text,
            text = L(LID.EXPLANATION_LABEL_DESC),
        },
        {
            type = HironCraftScan.Dialog.Element.EditBox,
            Validator = Validator,
            initial_text = label,
            default_text = label,
            default_label = L("Reset"),
        },
        {
            type = HironCraftScan.Dialog.Element.Text,
            text = L(LID.EXPLANATION_TEXT_DESC) .. '\n' .. L('Custom explanation tags description'),
        },
        {
            type = HironCraftScan.Dialog.Element.EditBox,
            initial_text = text,
            default_text = text,
            default_label = L("Reset"),
            multiline = true,
            Validator = ExplanationTextValidator,
        },
    }
    HironCraftScan.Dialog.Show({
        key = "custom_explanations",
        title = L("Create an Explanation"),
        submit = L("Save"),
        OnAccept = OnAccept,
        elements = elements,
        width = 450,
    })
end

local function OnDelete(label)
    local explanations = HironCraftScan.DB.settings.explanations;
    explanations[label] = nil;
    HironCraftScanComm:ShareCustomExplanations(explanations);
end

function HironCraftScan_CustomExplanationsButtonMixin:Init()
    if not HironCraftScan.DB.settings.explanations then
        HironCraftScan.DB.settings.explanations = {};
    end

    -- Sort the explanations so we aren't getting random dictionary order.
    local CreateUIExplanations = function()
        local explanations = {};

        for label, text in pairs(HironCraftScan.DB.settings.explanations) do
            if label ~= 'rev' then
                table.insert(explanations, { label = label, text = text });
            end
        end
        table.sort(explanations, function(a, b) return a.label < b.label; end)

        return explanations;
    end

    -- The drop down button used to configure explanations
    self:SetupMenu(function(owner, rootDescription)
        local explanations = CreateUIExplanations();
        for _, entry in ipairs(explanations) do
            local label = entry.label;
            local text = entry.text;
            local subMenu = rootDescription:CreateButton(label);
            subMenu:SetTooltip(function(tooltip, elementDescription)
                GameTooltip_AddNormalLine(tooltip, HironCraftScan.MakeTextWhite(text));
            end);
            subMenu:CreateButton(L("Modify"), function() OnModify(label, text) end);
            subMenu:CreateButton(L("Delete"), function() OnDelete(label) end);
        end

        rootDescription:CreateButton(L("Create"), OnCreate);
    end)

    -- Inject our buttons on the right click of a name in chat.
    local function AddChatActions(owner, rootDescription, contextData, isBattleNet)
        local target = contextData.chatTarget
        if isBattleNet then
            target = HironCraftScan.BattleNet and HironCraftScan.BattleNet.ContextCustomer(contextData)
            if not target then return end
        end
        if (issecretvalue and issecretvalue(target)) or type(target) ~= 'string' then return end
        local collapsed = HironCraftScan.DB.settings.collapse_chat_context
        local prefix = collapsed and "" or L("HironCraftScan") .. " - "
        local subMenu = collapsed and rootDescription:CreateButton(L("HironCraftScan")) or rootDescription

        if collapsed then
            subMenu:CreateTitle(L("HironCraftScan"))
        end

        -- Shift+click on an entry adds the row quietly: no banner, sound or
        -- greeting card. The greeting is one click on the row whenever the
        -- crafter wants it. (The chat menu does not pass right clicks on.)
        local function IsQuietPick()
            return IsShiftKeyDown and IsShiftKeyDown() or false
        end
        local function QuietTooltip(tooltip)
            GameTooltip_AddNormalLine(tooltip, HironCraftScan.MakeTextWhite(L('Manual match quiet help')))
        end

        do
            subMenu:CreateDivider();
            local title = subMenu:CreateTitle(prefix .. L(LID.MANUAL_MATCHING_TITLE));
            title:SetTooltip(function(tooltip, elementDescription)
                GameTooltip_AddNormalLine(tooltip, HironCraftScan.MakeTextWhite(L(LID.MANUAL_MATCHING_DESC)));
            end);
        end

        -- "LF crafter" names no profession, so offer the general greeting the
        -- scanner would have offered on its own. Its text lives in
        -- Settings - Customer Greetings, next to the phrases that trigger it.
        do
            local generalGreeting = subMenu:CreateButton(
                prefix .. L(LID.MANUAL_GENERAL_GREETING),
                function()
                    local quiet = IsQuietPick()
                    local lineID = contextData.lineID
                    if issecretvalue and issecretvalue(lineID) then return end
                    if type(lineID) == 'string' then lineID = lineID:match('^%d+$') and tonumber(lineID) end
                    local message, customerGuid
                    if type(lineID) == 'number' and lineID > 0 and C_ChatInfo then
                        if C_ChatInfo.GetChatLineText then
                            local ok, text = pcall(C_ChatInfo.GetChatLineText, lineID)
                            if ok then message = text end
                        end
                        if C_ChatInfo.GetChatLineSenderGUID then
                            local ok, guid = pcall(C_ChatInfo.GetChatLineSenderGUID, lineID)
                            if ok then customerGuid = guid end
                        end
                    end
                    if issecretvalue and (issecretvalue(message) or issecretvalue(customerGuid)) then return end
                    if isBattleNet then customerGuid = nil end
                    local response = HironCraftScan.OnMessage(nil,
                        type(message) == 'string' and message or '', target, customerGuid, {
                            battleNet = isBattleNet,
                            manualMatch = true,
                            forceGeneralRequest = true,
                            -- The crafter asked for this row again on purpose.
                            restartTerminalRequest = true,
                            suppressBatchAlert = quiet or nil,
                            suppressGreetingBanner = quiet or nil,
                            chatEntry = not message and {chatType='SYSTEM',
                                message='[Manual matching] ' .. L('General crafting request')} or nil,
                        })
                    if response ~= nil then
                        HironCraftScanCraftingOrderPage:ShowGeneric()
                    end
                end)
            generalGreeting:SetTooltip(function(tooltip, elementDescription)
                GameTooltip_AddNormalLine(tooltip,
                    HironCraftScan.MakeTextWhite(L(LID.MANUAL_GENERAL_GREETING_DESC)))
                QuietTooltip(tooltip)
            end)
        end

        local crafterRows = HironCraftScan.GetSortedCrafters();
        for _, crafterInfo in ipairs(crafterRows) do
            local char = crafterInfo.name;
            local charConfig = HironCraftScan.DB.characters[char];
            local ppID = crafterInfo.parentProfessionID;
            local ppConfig = charConfig.parent_professions[ppID];

            if ppConfig.scanning_enabled and not ppConfig.character_disabled then
                local profName = HironCraftScan.Utils.ProfessionNameByID(ppID);
                local matchButton = subMenu:CreateButton(
                    string.format(L(LID.MANUAL_MATCH), HironCraftScan.ColorizeCrafterName(char),
                        HironCraftScan.Utils.ColorizeProfessionName(ppID, profName)),
                    function()
                        local quiet = IsQuietPick()
                        -- Numeric hyperlink IDs can be strings; expired lines
                        -- still allow the explicitly chosen generic profession.
                        local lineID = contextData.lineID
                        if issecretvalue and issecretvalue(lineID) then return end
                        if type(lineID) == 'string' then lineID = lineID:match('^%d+$') and tonumber(lineID) end
                        local customer = target;
                        local message, customerGuid
                        if type(lineID) == 'number' and lineID > 0 and C_ChatInfo then
                            if C_ChatInfo.GetChatLineText then
                                local ok, text = pcall(C_ChatInfo.GetChatLineText, lineID)
                                if ok then message = text end
                            end
                            if C_ChatInfo.GetChatLineSenderGUID then
                                local ok, guid = pcall(C_ChatInfo.GetChatLineSenderGUID, lineID)
                                if ok then customerGuid = guid end
                            end
                        end
                        if issecretvalue and (issecretvalue(message) or issecretvalue(customerGuid)) then return end
                        if isBattleNet then customerGuid = nil end
                        local response = HironCraftScan.OnMessage(nil, type(message) == 'string' and message or '', customer, customerGuid, {
                            battleNet = isBattleNet,
                            manualMatch = true,
                            chatEntry = not message and {chatType='SYSTEM', message='[Manual matching] ' .. profName} or nil,
                            suppressBatchAlert = quiet or nil,
                            suppressGreetingBanner = quiet or nil,
                            forceCrafterInfo = {
                                crafter = char,
                                parentProfID = ppID,
                            }
                        });
                        if type(response) == 'table' then
                            HironCraftScanCraftingOrderPage:ShowGeneric()
                        end
                    end);
                if matchButton and matchButton.SetTooltip then matchButton:SetTooltip(QuietTooltip) end
            end
        end

        do
            local lineID = contextData.lineID
            if type(lineID) == 'string' then
                lineID = lineID:match('^%d+$') and tonumber(lineID) or nil
            end
            if
                type(lineID) == 'number'
                and lineID > 0
                and not (issecretvalue and issecretvalue(lineID))
                and HironCraftScan.ChatTextCapture
            then
                subMenu:CreateDivider()
                subMenu:CreateButton(prefix .. L('Save chat text'), function()
                    HironCraftScan.ChatTextCapture.ShowForLine(lineID)
                end)
            end
        end

        local pending = CustomExplanations:GetPendingResponses(target)
        local contexts = CustomExplanations:GetPendingResponses(target, true)
        -- A single unfinished order is useful here too: the customer may ask
        -- for the destination character without having requested two items.
        if #contexts >= 1 then
            subMenu:CreateDivider()
            if #pending >= 1 then
            local assignments = subMenu:CreateButton(prefix .. L('To who send'), function()
                CustomExplanations:SendAssignments(target)
            end)
            assignments:SetTooltip(function(tooltip, elementDescription)
                GameTooltip_AddNormalLine(tooltip,
                    HironCraftScan.MakeTextWhite(L('Send every unfinished item or profession with its crafter.')))
            end)
            end

            if #contexts > 1 then
                local activeOrder = subMenu:CreateButton(prefix .. L('Active order'))
                activeOrder:SetTooltip(function(tooltip, elementDescription)
                    GameTooltip_AddNormalLine(tooltip,
                        HironCraftScan.MakeTextWhite(L('Choose the order for message tags, including declined orders for {reagent_issues}.')))
                end)
                activeOrder:CreateRadio(L('Automatic (latest relevant order)'),
                    function()
                        return CustomExplanations:GetSelectedResponse(target, contexts) == nil
                    end,
                    function()
                        CustomExplanations:SetSelectedResponse(target, nil)
                    end)
                for _, candidate in ipairs(contexts) do
                    local label = Assignment(candidate)
                    if label then
                        activeOrder:CreateRadio(label,
                            function(value)
                                return CustomExplanations:GetSelectedResponse(target, contexts) == value.response
                            end,
                            function(value)
                                CustomExplanations:SetSelectedResponse(target, value)
                            end,
                            candidate)
                    end
                end
            end
        end

        if next(HironCraftScan.DB.settings.explanations) then
            subMenu:CreateDivider();
            subMenu:CreateTitle(prefix .. L("Custom Explanations"));
            local explanations = CreateUIExplanations();
            for _, entry in ipairs(explanations) do
                local label = entry.label;
                local text = entry.text;
                local button = subMenu:CreateButton(label, function()
                    CustomExplanations:Send(text, target)
                end);

                button:SetTooltip(function(tooltip, elementDescription)
                    GameTooltip_AddNormalLine(tooltip, HironCraftScan.MakeTextWhite(text));
                end);
            end
        end

        if HironCraftScan.Generous and not isBattleNet then
            local generous = HironCraftScan.Generous
            local marked = generous.IsGenerous(target)
            local button = subMenu:CreateButton(prefix .. L(marked and 'Unmark generous customer'
                or 'Mark as generous customer'), function()
                generous.SetManual(target, not marked)
                if HironCraftScanCraftingOrderPage and HironCraftScanCraftingOrderPage.ShowGeneric then
                    HironCraftScanCraftingOrderPage:ShowGeneric()
                end
            end)
            button:SetTooltip(function(tooltip)
                GameTooltip_AddNormalLine(tooltip, HironCraftScan.MakeTextWhite(
                    generous.Describe(target) or L('Generous customer tooltip')))
            end)
        end

        do
            subMenu:CreateDivider()
            local ignoredList = HironCraftScan.DB.settings.ignored
            local isIgnored = HironCraftScan.IsIgnored and HironCraftScan.IsIgnored(target)
                or (ignoredList and ignoredList[target] and true or false)
            local function SetIgnored(seconds)
                if HironCraftScan.SetIgnored then return HironCraftScan.SetIgnored(target, seconds) end
                local list = HironCraftScan.Utils.saved(HironCraftScan.DB.settings, 'ignored', {})
                list[target] = seconds ~= false and 1 or nil
            end
            if isIgnored then
                local left = HironCraftScan.IgnoreSecondsLeft and HironCraftScan.IgnoreSecondsLeft(target)
                local title = subMenu:CreateButton(prefix .. L(LID.UNIGNORE), function()
                    SetIgnored(false)
                end)
                title:SetTooltip(function(tooltip)
                    GameTooltip_AddNormalLine(tooltip, HironCraftScan.MakeTextWhite(L(LID.UNIGNORE_TOOLTIP)))
                    if left then
                        GameTooltip_AddNormalLine(tooltip, string.format(L('Ignore ends in %s'),
                            SecondsToTime and SecondsToTime(left) or (math.ceil(left / 60) .. ' min')))
                    end
                end)
            else
                -- A time-waster, or a customer whose LF spam should rest for
                -- a while: ignore for a set time, or for good.
                local ignoreMenu = subMenu:CreateButton(prefix .. L(LID.IGNORE))
                ignoreMenu:SetTooltip(function(tooltip)
                    GameTooltip_AddNormalLine(tooltip, HironCraftScan.MakeTextWhite(L(LID.IGNORE_TOOLTIP)))
                end)
                for _, choice in ipairs({
                    { label = 'Ignore for 1 hour', seconds = 60 * 60 },
                    { label = 'Ignore for 1 day', seconds = 24 * 60 * 60 },
                    { label = 'Ignore for 1 week', seconds = 7 * 24 * 60 * 60 },
                    { label = 'Ignore permanently', seconds = nil },
                }) do
                    ignoreMenu:CreateButton(L(choice.label), function()
                        SetIgnored(choice.seconds)
                    end)
                end
            end
        end
    end
    Menu.ModifyMenu("MENU_UNIT_FRIEND", function(owner, rootDescription, contextData)
        AddChatActions(owner, rootDescription, contextData, false)
    end)
    Menu.ModifyMenu("MENU_UNIT_BN_FRIEND", function(owner, rootDescription, contextData)
        AddChatActions(owner, rootDescription, contextData, true)
    end)
end
