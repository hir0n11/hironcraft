local HironCraftScan = select(2, ...)

local LID = HironCraftScan.CONST.TEXT;
local function L(id)
    return HironCraftScan.LOCAL:GetText(id);
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
            text = L(LID.EXPLANATION_TEXT_DESC),
        },
        {
            type = HironCraftScan.Dialog.Element.EditBox,
            multiline = true,
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
            text = L(LID.EXPLANATION_TEXT_DESC),
        },
        {
            type = HironCraftScan.Dialog.Element.EditBox,
            initial_text = text,
            default_text = text,
            default_label = L("Reset"),
            multiline = true,
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

        do
            subMenu:CreateDivider();
            local title = subMenu:CreateTitle(prefix .. L(LID.MANUAL_MATCHING_TITLE));
            title:SetTooltip(function(tooltip, elementDescription)
                GameTooltip_AddNormalLine(tooltip, HironCraftScan.MakeTextWhite(L(LID.MANUAL_MATCHING_DESC)));
            end);
        end

        local crafterRows = HironCraftScan.GetSortedCrafters();
        for _, crafterInfo in ipairs(crafterRows) do
            local char = crafterInfo.name;
            local charConfig = HironCraftScan.DB.characters[char];
            local ppID = crafterInfo.parentProfessionID;
            local ppConfig = charConfig.parent_professions[ppID];

            if ppConfig.scanning_enabled and not ppConfig.character_disabled then
                local profName = HironCraftScan.Utils.ProfessionNameByID(ppID);
                subMenu:CreateButton(
                    string.format(L(LID.MANUAL_MATCH), HironCraftScan.ColorizeCrafterName(char),
                        HironCraftScan.Utils.ColorizeProfessionName(ppID, profName)),
                    function()
                        -- Force the message through as if it were a match for the specified profession.
                        if (issecretvalue and issecretvalue(contextData.lineID))
                            or type(contextData.lineID) ~= 'number' then return end
                        local customer = target;
                        local message = C_ChatInfo.GetChatLineText(contextData.lineID)
                        local customerGuid = C_ChatInfo.GetChatLineSenderGUID(contextData.lineID)
                        if issecretvalue and (issecretvalue(message) or issecretvalue(customerGuid)) then return end
                        if isBattleNet then customerGuid = nil end
                        HironCraftScan.OnMessage(nil, message, customer, customerGuid, {
                            battleNet = isBattleNet,
                            forceCrafterInfo = {
                                crafter = char,
                                parentProfID = ppID,
                            }
                        });
                    end);
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
                    local message = HironCraftScan.Utils.SplitResponse(text);
                    HironCraftScan.Utils.SendResponses(message, target, true)
                end);

                button:SetTooltip(function(tooltip, elementDescription)
                    GameTooltip_AddNormalLine(tooltip, HironCraftScan.MakeTextWhite(text));
                end);
            end
        end

        do
            subMenu:CreateDivider()
            local ignored = HironCraftScan.DB.settings.ignored and HironCraftScan.DB.settings.ignored[target];
            local title = subMenu:CreateButton(prefix .. L(ignored and LID.UNIGNORE or LID.IGNORE),
                function()
                    if ignored then
                        HironCraftScan.DB.settings.ignored[target] = nil
                    else
                        HironCraftScan.Utils.saved(HironCraftScan.DB.settings, 'ignored', {})[target] = 1
                    end
                end);
            title:SetTooltip(function(tooltip, elementDescription)
                GameTooltip_AddNormalLine(tooltip,
                    HironCraftScan.MakeTextWhite(L(ignored and LID.UNIGNORE_TOOLTIP or LID.IGNORE_TOOLTIP)));
            end);
        end
    end
    Menu.ModifyMenu("MENU_UNIT_FRIEND", function(owner, rootDescription, contextData)
        AddChatActions(owner, rootDescription, contextData, false)
    end)
    Menu.ModifyMenu("MENU_UNIT_BN_FRIEND", function(owner, rootDescription, contextData)
        AddChatActions(owner, rootDescription, contextData, true)
    end)
end
