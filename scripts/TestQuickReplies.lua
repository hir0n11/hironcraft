-- Regression coverage for duplicate/stale quick-reply popups.
local CraftScan = {
    DB = {
        settings = {
            quick_replies = {
                enabled = true,
                templates = {
                    CUSTOM_1 = {
                        custom = true,
                        label = "OMW",
                        enabled = true,
                        keywords = "sent",
                        response = "omw",
                    },
                    CUSTOM_2 = {
                        custom = true,
                        label = "YES",
                        enabled = true,
                        keywords = "sent",
                        response = "yes",
                        priority = 10,
                    },
                    CUSTOM_3 = {
                        custom = true,
                        label = "CHARACTER CONFIRMATION",
                        enabled = true,
                        keywords = "this character",
                        response = "yes",
                    },
                },
            },
        },
        customers = {},
        listed_orders = {},
    },
    State = {},
    Utils = {},
    Config = {},
    Events = { Emit = function() end, Register = function() end },
    OrderFulfillment = { Status = { Rejected = "rejected" } },
    LOCAL = { GetText = function(_, id) return id end },
}

function CraftScan.Utils.saved(parent, key, default)
    if parent[key] == nil then parent[key] = default end
    return parent[key]
end

function CraftScan.Utils.onLoad(callback) callback() end
function CraftScan.Utils.FString(text) return text end
function CraftScan.Config.SubstituteTags(text) return text end
function CraftScan.BuildResponseContext(response)
    return {
        crafter = response.crafterName,
        profession = response.professionName,
        profession_link = response.professionName,
        item = response.itemName,
        commission = "",
    }
end
function CraftScan.NameAndRealmToName(name) return name and name:match("^[^-]+") end
local currentCharacter = "Seller-Realm"
function CraftScan.GetPlayerName() return currentCharacter end
function CraftScan.OrderToOrderID(order)
    return order.customerName .. "-" .. tostring(order.responseID)
end
function CraftScan.OrderToResponse(order)
    local customer = CraftScan.DB.customers[order.customerName]
    return customer and customer.responses[order.responseID]
end

function GetItemInfo(itemID)
    return itemID == 200 and "Second Item" or "Spellbreaker's Bracers"
end

assert(loadfile("Customer/QuickReplies.lua"))("HironCraft", CraftScan)
local QuickReplies = CraftScan.QuickReplies

assert(QuickReplies:GetConfig().templates.CUSTOM_1.priority == 0, "missing priority was not migrated")
local classified = QuickReplies:Classify("sent")
assert(#classified == 1 and classified[1] == "CUSTOM_2", "higher-priority reply did not win")
QuickReplies:GetConfig().templates.CUSTOM_2.priority = 0
classified = QuickReplies:Classify("sent")
assert(#classified == 2, "equal-priority exact matches should remain tied")

QuickReplies:GetConfig().templates.CUSTOM_1.keywords = "send, sent"
classified = QuickReplies:Classify("i send on this caracter")
assert(
    #classified == 1 and classified[1] == "CUSTOM_3",
    "a specific phrase with the character/caracter typo should beat the broad send keyword"
)
QuickReplies:GetConfig().typo_tolerance = false
classified = QuickReplies:Classify("i send on this caracter")
assert(
    #classified == 1 and classified[1] == "CUSTOM_1",
    "disabling typo recognition should restore exact-only matching"
)
QuickReplies:GetConfig().typo_tolerance = true
classified = QuickReplies:Classify("i send on this char")
for _, templateKey in ipairs(classified) do
    assert(templateKey ~= "CUSTOM_3", "short words must not fuzzy-match a longer keyword")
end

local definitions = QuickReplies:GetDefinitions()
assert(definitions[1].key == "REJECTED_ORDER", "rejected-order setting must be first")
assert(definitions[1].eventOnly == true, "rejected-order reply must not use chat keywords")

local function Response(responseID, itemID)
    return {
        responseID = responseID,
        crafterName = "Farrierr",
        crafterFullName = "Farrierr-Realm",
        professionID = 164,
        professionName = "Blacksmithing",
        itemID = itemID or 100,
        time = 100,
    }
end

local first = Response(101)
local second = Response(102)
CraftScan.State.activeOrder = { customerName = "Valnihra", responseID = 101 }

local options = QuickReplies:BuildPopupOptions("Valnihra", "sent", {
    { response = first, responseID = 101 },
    { response = second, responseID = 102 },
}, { "CUSTOM_1" })

assert(#options == 1, "identical quick replies must collapse into one popup")
assert(options[1].response == first, "the active order should win an identical-popup tie")
assert(options[1].label == "omw", "a single deduplicated popup needs no redundant context prefix")

local different = Response(103, 200)
options = QuickReplies:BuildPopupOptions("Valnihra", "sent", {
    { response = first, responseID = 101 },
    { response = different, responseID = 103 },
}, { "CUSTOM_1" })
assert(#options == 2, "different item contexts must remain separate")
assert(options[1].label:find(": omw", 1, true), "ambiguous replies must retain their context")

-- A recipe response may only be stored through its profession alias. It is
-- still current when the recipe order itself remains listed.
CraftScan.DB.customers.Valnihra = { responses = { [164] = first } }
CraftScan.DB.listed_orders["Valnihra-101"] = { customerName = "Valnihra", responseID = 101 }
local resolved = QuickReplies:ResolvePopupResponse({
    customer = "Valnihra",
    response = first,
    responseID = 101,
    templateKey = "CUSTOM_1",
    reply = "omw",
    contextLabel = "Farrierr / Spellbreaker's Bracers",
})
assert(resolved == first, "profession aliases must not make a popup stale")

-- A yellow rejected-order status creates one direct, context-bound reply. It
-- must not be classified from chat keywords and must never attach to another
-- order belonging to the same customer.
CraftScan.DB.customers.Valnihra.responses[101] = first
local rejectionOrder = { customerName = "Valnihra", responseID = 101 }
local rejectionEntry = { status = "rejected", rev = 1 }
assert(QuickReplies:BuildRejectedOrderOption(rejectionOrder, rejectionEntry) == nil,
    "a legacy row without conversation ownership was assigned to an arbitrary character")
QuickReplies:RememberConversationCharacter(first)
assert(first.conversationCharacter == "Seller-Realm")
currentCharacter = "Farrierr-Realm"
QuickReplies:RememberCustomerConversation(CraftScan.DB.customers.Valnihra)
assert(first.conversationCharacter == "Seller-Realm", "crafting alt stole the conversation")
assert(QuickReplies:BuildRejectedOrderOption(rejectionOrder, rejectionEntry) == nil,
    "rejection reply leaked onto the crafting alt")
currentCharacter = "Seller-OtherRealm"
assert(QuickReplies:BuildRejectedOrderOption(rejectionOrder, rejectionEntry) == nil,
    "same name on another realm inherited the rejection")
currentCharacter = "Seller-Realm"
local rejectedOption = QuickReplies:BuildRejectedOrderOption(
    { customerName = "Valnihra", responseID = 101 },
    { status = "rejected", rev = 1 }
)
assert(rejectedOption, "rejected order did not create a quick reply")
assert(rejectedOption.response == first)
currentCharacter = "Farrierr-Realm"
assert(QuickReplies:ResolvePopupResponse(rejectedOption) == nil, "stale rejection popup sent from another character")
currentCharacter = "Seller-Realm"
assert(
    rejectedOption.reply == "You need provide all mats and they all should be max tier (even missive and embelishment)",
    "rejected-order reply text changed"
)
QuickReplies:GetConfig().templates.REJECTED_ORDER.response = "Edited rejected-order reply"
rejectedOption = QuickReplies:BuildRejectedOrderOption(
    { customerName = "Valnihra", responseID = 101 },
    { status = "rejected", rev = 2 }
)
assert(rejectedOption.reply == "Edited rejected-order reply", "rejected-order reply is not editable")
assert(QuickReplies:BuildRejectedOrderOption(
    { customerName = "Valnihra", responseID = 101 },
    { status = "failed", rev = 2 }
) == nil, "ordinary red crosses must not offer the rejected-order reply")

local stableOrder = { customerName = "Valnihra", responseID = 101 }
local initialKeys = QuickReplies:GetRejectedOrderSuggestionKeys(stableOrder, {
    status = "rejected",
    requestToken = "request-1",
    rev = 1,
    updatedAt = 100,
})
local reconciledKeys = QuickReplies:GetRejectedOrderSuggestionKeys(stableOrder, {
    status = "rejected",
    craftingOrderID = 9001,
    requestToken = "request-1",
    rev = 7,
    updatedAt = 500,
})
local initialSet = {}
for _, key in ipairs(initialKeys) do initialSet[key] = true end
local hasStableAlias = false
for _, key in ipairs(reconciledKeys) do
    if initialSet[key] then hasStableAlias = true end
end
assert(hasStableAlias, "reconciled rejected status would create a repeated suggestion")

-- Ownership survives linked-account chat, aliases and request replay. A later
-- job for the same item must not inherit ownership from an old chat packet.
first.requestToken = "request-owner-1"
local owners = QuickReplies:GetConversationOwners(CraftScan.DB.customers.Valnihra)
assert(#owners == 1, "profession alias duplicated the conversation owner")
local remoteResponse = Response(101)
remoteResponse.requestToken = first.requestToken
local remoteCustomer = { responses = { [101] = remoteResponse } }
HironCraftScanComm = { applying_remote_state = true }
QuickReplies:RememberConversationCharacter(remoteResponse)
assert(remoteResponse.conversationCharacter == nil, "proxied scan claimed the local character")
QuickReplies:ApplyConversationOwners(remoteCustomer, owners)
assert(remoteResponse.conversationCharacter == "Seller-Realm", "linked account lost the conversation owner")
remoteResponse.requestToken = "request-owner-2"
remoteResponse.conversationCharacter = nil
QuickReplies:ApplyConversationOwners(remoteCustomer, owners)
assert(remoteResponse.conversationCharacter == nil, "old chat assigned a newer request")
HironCraftScanComm = nil
currentCharacter = "NewSeller-Realm"
QuickReplies:RememberConversationCharacter(remoteResponse)
assert(remoteResponse.conversationCharacter == currentCharacter, "new request cannot select a new conversation character")

-- Exercise the actual outgoing-whisper event path, not just the owner helper.
CraftScan.CONST = { TEXT = {} }
CraftScan.Utils.onLoad = function() end
CraftScan.Utils.DeepCopy = function(value) return value end
EnumUtil = { MakeEnum = function() return {} end }
CreateFrame = function() return {} end
assert(loadfile('Customer/ChatHistory.lua'))('HironCraft', CraftScan)
assert(loadfile('Customer/ChatScanner.lua'))('HironCraft', CraftScan)
CraftScan.GetPlayerName = function() return currentCharacter end
local sharedEntry
HironCraftScanComm = { ShareCustomerChat = function(_, _, _, entry) sharedEntry = entry end }
local liveResponse = Response(201)
liveResponse.requestToken = 'live-request'
CraftScan.DB.customers.LiveCustomer = { responses = { [201] = liveResponse } }
CraftScan.OnMessage('CHAT_MSG_WHISPER_INFORM', 'Hello, send the order to my crafter.', 'LiveCustomer')
assert(liveResponse.conversationCharacter == 'NewSeller-Realm', 'outgoing greeting did not record its character')
assert(sharedEntry.conversationOwners[1].character == 'NewSeller-Realm', 'outgoing whisper omitted synced ownership')
local linkedResponse = Response(201)
linkedResponse.requestToken = 'live-request'
CraftScan.DB.customers.LinkedCustomer = { responses = { [201] = linkedResponse } }
CraftScan.ApplyRemoteCustomerChat('LinkedCustomer', nil, sharedEntry, false)
assert(linkedResponse.conversationCharacter == 'NewSeller-Realm', 'remote chat handler discarded ownership')
currentCharacter = 'Farrierr-Realm'
CraftScan.OnMessage('CHAT_MSG_WHISPER_INFORM', 'Crafting now.', 'LiveCustomer')
assert(liveResponse.conversationCharacter == 'NewSeller-Realm', 'later alt whisper replaced the original seller')

-- Explicit greeting/open-chat clicks capture the selected request before the
-- outgoing-chat echo arrives (including middle-click without a greeting).
CreateFromMixins = function() return {} end
StaticPopupDialogs = {}
UnitName = function() return currentCharacter end
GetRealmName = function() return 'Realm' end
bit = { bxor = function() return 0 end, band = function() return 0 end }
setmetatable(CraftScan.CONST.TEXT, { __index = function(_, key) return key end })
CraftScan.Utils.ChatHistoryTooltip = { new = function() return {} end }
HironCraftScanScannerMenu = { ClearAlert = function() end }
HironCraftScanCraftingOrderPage = { ShowGeneric = function() end }
CraftScan.Utils.SendResponses = function() end
ChatFrame_SendTell = function() end
assert(loadfile('Customer/OrderPage.lua'))('HironCraft', CraftScan)
CraftScan.RebuildResponseMessage = function() end
local clickedResponse = Response(301)
clickedResponse.requestToken = 'clicked-request'
CraftScan.DB.customers.ClickedCustomer = { responses = { [301] = clickedResponse } }
local clickedOrder = { customerName = 'ClickedCustomer', responseID = 301 }
CraftScan.GreetCustomer('LeftButton', clickedOrder)
assert(clickedResponse.conversationCharacter == currentCharacter, 'greeting click did not capture the seller')
clickedResponse.conversationCharacter = nil
CraftScan.GreetCustomer('MiddleButton', clickedOrder)
assert(clickedResponse.conversationCharacter == currentCharacter, 'middle-click conversation did not capture the seller')

print("Quick reply tests passed.")
