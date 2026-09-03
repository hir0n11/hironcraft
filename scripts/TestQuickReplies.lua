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
                },
            },
        },
        customers = {},
        listed_orders = {},
    },
    State = {},
    Utils = {},
    Config = {},
    Events = { Emit = function() end },
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

function GetItemInfo(itemID)
    return itemID == 200 and "Second Item" or "Spellbreaker's Bracers"
end

assert(loadfile("Customer/QuickReplies.lua"))("HironCraft", CraftScan)
local QuickReplies = CraftScan.QuickReplies

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

print("Quick reply tests passed.")
