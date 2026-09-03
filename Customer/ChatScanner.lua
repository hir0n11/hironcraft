local HironCraftScan = select(2, ...)

local LID = HironCraftScan.CONST.TEXT
local function L(id)
    return HironCraftScan.LOCAL:GetText(id)
end

local saved = HironCraftScan.Utils.saved
local requestTokenSerial = 0

local function NewRequestToken(customer, responseID, chatEntry)
    local args = chatEntry and chatEntry.args
    local lineID = args and args[11]
    if lineID ~= nil and not (issecretvalue and issecretvalue(lineID)) then
        return table.concat({
            'chat',
            tostring(customer),
            tostring(responseID),
            tostring(lineID),
        }, ':')
    end

    requestTokenSerial = requestTokenSerial + 1
    local origin = HironCraftScan.DB
        and HironCraftScan.DB.settings
        and HironCraftScan.DB.settings.my_uuid
        or HironCraftScan.GetPlayerName(true)
        or 'local'
    local precise = GetTimePreciseSec and GetTimePreciseSec() or GetTime()
    return table.concat({
        tostring(origin),
        tostring(time()),
        string.format('%.3f', precise or 0),
        tostring(requestTokenSerial),
    }, ':')
end

HironCraftScan.MessageType = EnumUtil.MakeEnum('General', 'Whisper')

-- Split and normalize a comma separated list of strings
local function ParseStringList(list)
    if not list then
        return {}
    end

    local items = {}
    for token in string.gmatch(HironCraftScan.Config.SubstituteTags(list), '([^,]+)') do
        items[string.lower(token:gsub('^%s*(.-)%s*$', '%1'))] = true
    end
    return items
end

-- Split a string on newlines, then further split each line to ensure
-- it fits in a whisper.
local function SplitResponse(raw_response)
    local result = {}
    for _, response in ipairs({ strsplit('\n', raw_response) }) do
        while #response > 255 do
            local split = 255
            for i = 255, 1, -1 do
                if response:sub(i, i) == ' ' then
                    split = i
                    break
                end
            end
            table.insert(result, response:sub(1, split))
            response = response:sub(split + 1, #response)
        end
        table.insert(result, response)
    end
    return result
end
HironCraftScan.Utils.SplitResponse = SplitResponse

local function DelimitedHasMatchCheck(b, e, message)
    return b
        and e
        and (b == 1 or message:sub(b - 1, b - 1) == ' ' or (b > 2 and message:sub(b - 2, b - 1) == '|r'))
        and (e == #message or message:sub(e + 1, e + 1) == ' ' or message:sub(e + 1, e + 1) == '|')
end

local function PermissiveHasMatchCheck(b, e, message)
    return b and e
end

-- Support with or without caring about space delimiters so languages that don't
-- use spaces can disable the space checking.
local HasMatchCheck = DelimitedHasMatchCheck
function HironCraftScan.UpdateHasMatchStyle()
    if HironCraftScan.DB.settings.permissive_matching then
        HasMatchCheck = PermissiveHasMatchCheck
    else
        HasMatchCheck = DelimitedHasMatchCheck
    end
end

-- Given a string and a list of string tokens, return if the string
-- contains one of the tokens, delimited by spaces, start/end, or
-- the [] of an item link.]
local function HasMatch(message, tokens, secondary_keywords)
    local len = nil
    local numMatches = 0
    for token, _ in pairs(tokens) do
        local b, e = string.find(message, token)
        if HasMatchCheck(b, e, message) then
            if not len or len < #token then
                len = #token
            end
            numMatches = numMatches + 1
            if secondary_keywords then
                local secondary_tokens = ParseStringList(secondary_keywords)
                local secLen, secNum = HasMatch(message, secondary_tokens)
                numMatches = numMatches + secNum
            end
        end
    end
    return len, numMatches
end

local config = {}
local function resetConfig()
    config = {
        -- The message must match an inclusion and either a prof_keyword or an item
        exclusions = {},
        inclusions = {},
        prof_keywords = {},
        items = {},
        recipes = {},
    }
end

--[[
"characters": {
    "name-realm": {
        "professions": {
            <id>: {
                "recipes": {
                    "recipeID": {
                        "scan_state": <HironCraftScan.CONST.RECIPE_STATES>
                        "keywords": "<keywords>",
                        "greeting": "<greeting>",
                        "override": <true|false>
                    }
                },
                "keywords": "<keywords>",
                "greeting": "<greeting>"
            }
        }
    }

}
]]

HironCraftScan.Scanner = {}

HironCraftScan.Utils.GetOutputItems = function(recipeInfo)
    if recipeInfo.qualityItemIDs then
        -- If included, we already have the itemIDs we need.
        -- This appears to be how reagant style crafts, like
        -- gems are represented, and we get a separate itemID for
        -- each quality level. Armor pieces are not found here.
        return recipeInfo.qualityItemIDs
    else
        -- Things like recraft don't have an outputItemID, and we don't want to detect those anyway.
        local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeInfo.recipeID, false)
        if schematic.outputItemID then
            return { schematic.outputItemID }
        end
    end

    return nil
end

local RecipeCreatesEpicItem = function(recipeID)
    local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
    local items = HironCraftScan.Utils.GetOutputItems(recipeInfo)
    if items and #items == 1 then
        return Enum.ItemQuality.Epic == C_Item.GetItemQualityByID(items[1])
    end
    return false
end

function HironCraftScan.Scanner.RecipeScanningOn(profConfig, recipeConfig)
    if recipeConfig.scan_state == HironCraftScan.CONST.RECIPE_STATES.SCANNING_ON then
        if recipeConfig.required_concentration and profConfig.concentration then
            local concentration = HironCraftScan.ConcentrationData:Deserialize(profConfig.concentration)
            if concentration:GetCurrentAmount() < recipeConfig.required_concentration then
                return false, concentration:GetTimeUntil(recipeConfig.required_concentration)
            end
        end

        return true
    end

    return false
end

-- The usage of this method is *very* inefficient. On any profession
-- configuration change, we reload the whole thing. AddonUsage shows that
-- during config changes, we shoot up to #1 on memory usage of any addon.
-- Tossing a manual 'collectgarbage()' call into resetConfig() makes it so we
-- stay low at all times, but makes every button click hang for a second.
--
-- This config should change very rarely, so was more concerned with correctness
-- over efficiency, and didn't want to code special case updates for each
-- different button option.
local loadInProgress = false
local needsReload = false
function HironCraftScan.Scanner.LoadConfig()
    if loadInProgress then
        needsReload = true
        return
    end
    resetConfig()

    config.exclusions = ParseStringList(HironCraftScan.DB.settings.exclusions)
    config.inclusions = ParseStringList(HironCraftScan.DB.settings.inclusions)

    -- Sort professions so that when we scan for generic keyword matches, we
    -- find the local charcter first, then the primary crafter. We ignore
    -- duplicate recipes, so this gives priority to the local character, then
    -- the primary crafter, then other crafters in alphabetical order than can
    -- make the item.
    local parentProfessions = {}
    for crafter, crafterConfig in pairs(HironCraftScan.DB.characters) do
        for parentProfID, parentProf in pairs(crafterConfig.parent_professions) do
            if not parentProf.character_disabled then
                local professions = {}
                for profID, prof in pairs(crafterConfig.professions) do
                    if prof.parentProfID == parentProfID then
                        table.insert(professions, {
                            profID = profID,
                            profession = prof,
                        })
                    end
                end
                table.insert(parentProfessions, {
                    crafter = crafter,
                    parentProfID = parentProfID,
                    parentProfession = parentProf,
                    professions = professions,
                })
            end
        end
    end

    local playerNameWithRealm = HironCraftScan.GetPlayerName(true)
    table.sort(parentProfessions, function(lhs, rhs)
        if lhs.crafter == playerNameWithRealm then
            if rhs.crafter ~= playerNameWithRealm then
                return true
            end
        elseif rhs.crafter == playerNameWithRealm then
            return false
        end
        if lhs.parentProfession.primary_crafter then
            if not rhs.parentProfession.primary_crafter then
                return true
            end
        elseif rhs.parentProfession.primary_crafter then
            return false
        end
        return lhs.crafter < rhs.crafter
    end)

    local concentrationMinTime = 0
    local waitGroup = HironCraftScan.WaitGroup(function()
        loadInProgress = false
        if needsReload then
            -- A config change was made while we were processing the last config
            -- change. Restart.
            needsReload = false
            C_Timer.After(0, HironCraftScan.Scanner.LoadConfig)
            return
        end

        -- Very unlikely to matter, but if the user is logged on as they reach a
        -- concentration threshold, reload the config to scan for that recipe.
        --
        -- This can be heavy weight work with a large config, so we only do it if
        -- scanning is enabled (currently just IsResting()), so we don't lock up
        -- someone's UI in a dungeon.
        if concentrationMinTime ~= 0 then
            local function LoadIfScanning()
                if not HironCraftScan.Utils.IsScanningEnabled() then
                    C_Timer.After(60, LoadIfScanning)
                else
                    HironCraftScan.Scanner.LoadConfig()
                end
            end
            C_Timer.After(concentrationMinTime + 1, LoadIfScanning)
        end
    end)

    -- Flatten the keywords, storing the path back to their source so we can
    -- find the greeting after getting a match.
    --
    -- Convert recipeIDs to itemIDs, which is what we will find in chat message
    -- links.
    for _, entry in ipairs(parentProfessions) do
        local crafter = entry.crafter
        local parentProf = entry.parentProfession
        local parentProfID = entry.parentProfID
        local professions = entry.professions

        local keywords = parentProf.keywords
            or L(HironCraftScan.CONST.PROFESSION_DEFAULT_KEYWORDS[parentProfID])
        table.insert(config.prof_keywords, {
            keywords = ParseStringList(keywords),
            exclusions = ParseStringList(parentProf.exclusions or ''),
            crafter = crafter,
            parentProfID = parentProfID,
        })

        for _, pEntry in ipairs(professions) do
            local prof = pEntry.profession
            if prof.recipes then
                local profID = pEntry.profID

                local function ProcessRecipe(recipeID, recipe)
                    local scanningOn, timeToScanningOn =
                        HironCraftScan.Scanner.RecipeScanningOn(prof, recipe)
                    if scanningOn then
                        if not config.recipes[recipeID] then
                            config.recipes[recipeID] = {
                                crafter = crafter,
                                profID = profID,
                                parentProfID = parentProfID,
                                recipeID = recipeID,
                            }
                        end

                        -- Look up the itemIDs associated with the recipe
                        local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
                        local itemIDs = HironCraftScan.Utils.GetOutputItems(recipeInfo)
                        if itemIDs then
                            for _, itemID in ipairs(itemIDs) do
                                if not config.items[itemID] then
                                    config.items[itemID] = {
                                        crafter = crafter,
                                        profID = profID,
                                        recipeID = recipeID,
                                    }
                                end
                            end
                        end
                    elseif
                        timeToScanningOn
                        and (concentrationMinTime == 0 or timeToScanningOn < concentrationMinTime)
                    then
                        concentrationMinTime = timeToScanningOn
                    end
                end

                local perFrame = 1000
                waitGroup:Add()
                HironCraftScan.TimeSlice(prof.recipes, perFrame, ProcessRecipe, function()
                    waitGroup:Done()
                end)
            end
        end
    end
    waitGroup:Close()
end

local function ParentProfessionConfig(crafterInfo)
    local crafterConfig = HironCraftScan.DB.characters[crafterInfo.crafter]
    local profConfig = crafterConfig.professions[crafterInfo.profID]
    return crafterConfig.parent_professions[profConfig.parentProfID]
end

local function IsScanningEnabled(crafterInfo)
    local ppConfig = ParentProfessionConfig(crafterInfo)
    return ppConfig.scanning_enabled
end

local function RecipeIdForKeywords(message, profConfig)
    local recipeConfigs = profConfig.recipes
    if not recipeConfigs then
        return nil
    end

    local len = nil
    local num = 0
    local result = nil
    for id, recipeConfig in pairs(recipeConfigs) do
        if
            HironCraftScan.Scanner.RecipeScanningOn(profConfig, recipeConfig) and recipeConfig.keywords
        then
            local matchLen, numMatches = HasMatch(
                message,
                ParseStringList(recipeConfig.keywords),
                recipeConfig.secondary_keywords
            )
            if matchLen then
                if
                    not len
                    or len < matchLen
                    or (len == matchLen and num < numMatches)
                    -- All else being equal, prioritize the epic spark-level craft.
                    or (num == numMatches and RecipeCreatesEpicItem(id))
                then
                    len = matchLen
                    num = numMatches
                    result = id
                end
            end
        end
    end
    return result
end

local function GetRequestID(message, crafterInfo, profConfig)
    local recipeID = crafterInfo.recipeID
    if not recipeID then
        recipeID = RecipeIdForKeywords(message, profConfig)
        if not recipeID then
            return nil
        end
    end

    local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
    if recipeInfo then
        return recipeInfo
    end

    return nil
end

-- There does not appear to be any reverse look up from itemID to whether the
-- item is crafted or not. The onyl option I've found is the reverse direction,
-- but then we'd need a mapping of every craftable item in the game to determine
-- if a given itemID is crafted. Instead, we're going to depend on the fact that
-- players don't really have easy access to item links that don't have a
-- crafting 'quality' embedded in the link itself. (We generate such links, but
-- without an addon all items clicked from a profession or the order page have a
-- quality.)
local function GetItemIDsFromQualityLinks(inputString)
    local itemIDs = nil

    local pattern = 'item:(%d+)'
    local qualityPattern = 'professions%-chaticon%-quality%-tier'
    for itemLink in string.gmatch(inputString, '(item:[%d:]+%|h%b[])') do
        local itemIDStr = itemLink:match(pattern)
        if itemIDStr then
            local itemID = tonumber(itemIDStr)
            local crafterInfo = config.items[itemID]
            if crafterInfo or string.find(itemLink, qualityPattern) then
                if not itemIDs then
                    itemIDs = {}
                end

                if crafterInfo then
                    local profConfig =
                        HironCraftScan.DB.characters[crafterInfo.crafter].professions[crafterInfo.profID]
                    table.insert(itemIDs, { itemID = itemID, ppID = profConfig.parentProfID })
                else
                    table.insert(itemIDs, itemID)
                end
            end
        end
    end

    return itemIDs
end

-- Return array with the front n elements removed.
local function RemoveFront(array, n)
    local result = {}
    for i = n + 1, #array, 1 do
        table.insert(result, array[i])
    end
    return result
end

local function RemoveBack(array, n)
    for _ = 1, n do
        table.remove(array)
    end
end

HironCraftScan.Analytics = {}

function HironCraftScan.Analytics.GetTimeStamp(timeEntry)
    if type(timeEntry) == 'table' then
        return timeEntry.t
    end
    return timeEntry
end

local function ClearAnalyticsForItem_(itemID, range)
    local timeout = range.seconds
    local recent = range.recent
    local items = HironCraftScan.DB.analytics.seen_items
    local itemInfo = items[itemID]
    local now = time()
    for i, timeInfo in ipairs(itemInfo.times) do
        if HironCraftScan.Analytics.GetTimeStamp(timeInfo) + timeout > now then
            if recent then
                local count = #itemInfo.times - i + 1
                if count == 0 then
                    -- Don't need to refresh the display
                    return false
                end

                RemoveBack(itemInfo.times, count)
            else
                local count = i - 1
                if count == 0 then
                    -- Don't need to refresh the display
                    return false
                end

                itemInfo.times = RemoveFront(itemInfo.times, i - 1)
            end
            if #itemInfo.times == 0 then
                items[itemID] = nil
            end
            return true
        end
    end
    if not recent then
        items[itemID] = nil
        return true
    end
end

-- Remove entries older than timeout for the given itemID. If itemID is nil,
-- apply to all itemIDs.
function HironCraftScan.Analytics:ClearAnalyticsForItem(itemID, range)
    local timeout = range.seconds

    local items = HironCraftScan.DB.analytics.seen_items
    if timeout == nil then
        if itemID == nil then
            items = {}
        else
            items[itemID] = nil
        end
        return true
    end

    if itemID then
        return ClearAnalyticsForItem_(itemID, range)
    end

    local result = false
    for itemID, itemInfo in pairs(items) do
        if ClearAnalyticsForItem_(itemID, range) then
            result = true
        end
    end
    return result
end

-- If the same customer requests the same item repeatedly, that indicates a
-- supply gap in the market, so we try to track and highlight it. Duplicate
-- requests within 15 seconds are ignored completely - they're just impatient.
-- For an hour after their first request, if they keep requesting the same
-- thing, we count them.
local ANALYTICS_IGNORE_DUPLICATE_INTERVAL = 15
local ANALYTICS_RESET_DUPLICATE_INTERVAL = 3600

local function CleanRecentAnalytics()
    if not HironCraftScan.DB.analytics.seen_items then
        return
    end

    local timeout = ANALYTICS_RESET_DUPLICATE_INTERVAL
    local now = time()
    for _, itemInfo in pairs(HironCraftScan.DB.analytics.seen_items) do
        for i, timeInfo in ipairs(itemInfo.times) do
            if type(timeInfo) == 'table' and timeInfo.t + timeout < now then
                if timeInfo.c ~= nil then
                    -- Save the count, but erase the customer to save some space.
                    timeInfo['customer'] = nil
                else
                    -- No duplicates from this customer, so replace the dictionary with the raw time.
                    itemInfo.times[i] = timeInfo.t
                end
            end
        end
    end

    -- On login and every hour after that, clean up any recent records to save space.
    C_Timer.After(timeout, CleanRecentAnalytics)
end

local function AddTimeToAnalytics(customer, item)
    -- For recent requests, we track the customer, allowing us to detect
    -- duplicate requests for the same item from the same person. This helps us
    -- find items that are difficult to get crafted, which might indicate a good
    -- item to invest in learning to craft.
    local times = item.times

    --  Track repeat requests for up to an hour. This aligns with our 'peak per
    --  hour', so duplicate requests don't artificially inflate the peak requests.
    local timeout = ANALYTICS_RESET_DUPLICATE_INTERVAL
    local now = time()
    for i = #times, 1, -1 do
        local entry = times[i]
        if type(entry) == 'table' then
            if entry.t + ANALYTICS_IGNORE_DUPLICATE_INTERVAL > now then
                -- Ignore it. Same customer spamming a request before they had a chance to get any replies.
                HironCraftScan.Utils.printTable('Ignoring very recent request', true)
                return
            end

            if entry.t + timeout < now then
                HironCraftScan.Utils.printTable('Starting a new bucket', true)
                break
            end

            if entry.customer == customer then
                entry.c = (entry.c or 1) + 1
                HironCraftScan.Utils.printTable('Incrementing bucket', entry)
                HironCraftScanCraftingOrderPage:UpdateAnalytics()
                return
            end
        else
            -- After an hour, a garbage collector converts entries from
            -- dictionaries to values if they don't contain a duplicate request
            -- count, so hitting a non-dictionary value means we are done
            -- looking for recent orders.
            break
        end
    end
    table.insert(item.times, { t = time(), customer = customer })

    HironCraftScanCraftingOrderPage:UpdateAnalytics()
end

local function AddItemToAnalytics(customer, itemID, parentProfID)
    if not HironCraftScan.DB.analytics.enabled then
        return
    end

    local seen = saved(HironCraftScan.DB.analytics, 'seen_items', {})
    local item = saved(seen, itemID, { times = {}, ppID = parentProfID })
    AddTimeToAnalytics(customer, item)
    if not item.ppID then
        item.ppID = parentProfID
    end
end

local function AddMessageToAnalytics(customer, message)
    if not HironCraftScan.DB.analytics.enabled then
        return
    end

    local itemIDs = GetItemIDsFromQualityLinks(message)
    if not itemIDs then
        return
    end

    local seen = saved(HironCraftScan.DB.analytics, 'seen_items', {})
    for _, itemID in ipairs(itemIDs) do
        if type(itemID) == 'table' then
            AddItemToAnalytics(customer, itemID.itemID, itemID.ppID)
        else
            local item = saved(seen, itemID, { times = {} })
            AddTimeToAnalytics(customer, item)
        end
    end
end

-- Because we can't reverse look up from item link to crafting profession, we do
-- the translation when a profession is opened scan any saved items and see if
-- they are related to this profession.
local function UpdateAnalyticsProfIDs(parentProfID)
    if not HironCraftScan.DB.analytics.enabled then
        return
    end

    if not HironCraftScan.DB.analytics.seen_items then
        return
    end

    local ppInfo = C_TradeSkillUI.GetBaseProfessionInfo()

    local itemIDs = nil
    for itemID, itemInfo in pairs(HironCraftScan.DB.analytics.seen_items) do
        if not itemInfo.ppID then
            if not itemIDs then
                itemIDs = {}
                -- On the first analytics item without profession info, grab the
                -- full list, convert it to all itemIDs created by the
                -- profession, then check if we have a match.
                local recipes = C_TradeSkillUI.GetAllRecipeIDs()
                for _, id in pairs(recipes) do
                    local recipeInfo = C_TradeSkillUI.GetRecipeInfo(id)
                    local recipeItemIDs = HironCraftScan.Utils.GetOutputItems(recipeInfo)
                    if recipeItemIDs then
                        for _, itemID in ipairs(recipeItemIDs) do
                            itemIDs[itemID] = true
                        end
                    end
                end
            end

            if itemIDs[itemID] then
                itemInfo.ppID = ppInfo.professionID
            end
        end
    end
end
HironCraftScan.Events:Register('TRADESKILL_OPENED', function()
    local ppInfo = C_TradeSkillUI.GetBaseProfessionInfo()
    HironCraftScan.DoOnceForTag(ppInfo.professionID, UpdateAnalyticsProfIDs)
end)

local function RecipeIDFromLink(message)
    -- Shift-clicking a profession recipe produces an "enchant" hyperlink,
    -- even for professions other than Enchanting.
    local recipeID = message:match('|henchant:(%d+)')
        or message:match('|hrecipe:(%d+)')
    return tonumber(recipeID)
end

local function GenericCrafterForParentProfession(parentProfessionID, preferredProfessionID)
    for _, crafterInfo in ipairs(config.prof_keywords) do
        if crafterInfo.parentProfID == parentProfessionID then
            local crafterConfig = HironCraftScan.DB.characters[crafterInfo.crafter]
            local parentConfig = crafterConfig.parent_professions[parentProfessionID]
            if parentConfig and parentConfig.scanning_enabled then
                if preferredProfessionID and crafterConfig.professions[preferredProfessionID] then
                    return {
                        crafter = crafterInfo.crafter,
                        profID = preferredProfessionID,
                    }
                end

                local newestProfessionID = nil
                for professionID, professionConfig in pairs(crafterConfig.professions) do
                    if
                        professionConfig.parentProfID == parentProfessionID
                        and (not newestProfessionID or professionID > newestProfessionID)
                    then
                        newestProfessionID = professionID
                    end
                end
                if newestProfessionID then
                    return {
                        crafter = crafterInfo.crafter,
                        profID = newestProfessionID,
                    }
                end
            end
        end
    end
    return nil
end

local function GetCrafterForMessage(customer, message, overrides)
    message = string.lower(message)

    if not overrides or (not overrides.forceCrafterInfo and not overrides.itemInfo) then
        if HasMatch(message, config.exclusions) then
            return nil
        end

        if not HasMatch(message, config.inclusions) then
            return nil
        end

        if not HironCraftScanComm.applying_remote_state then
            -- Don't add to analytics based on proxied orders. The 'now' might
            -- be slightly off because of the messaging. We don't want that to
            -- create duplicates if both characters see the same message at the
            -- same time. Instead, analytics can be separately sync'ed between
            -- accounts, with a merge of timestamps to avoid creating
            -- duplicates.

            -- We originally piggy backed on the matching below for analytics, but
            -- analytics supports multiple items in a request while the matching
            -- below does not.
            AddMessageToAnalytics(customer, message)
        end
    end

    local linkedRecipeID = RecipeIDFromLink(message)
    if linkedRecipeID then
        local exactCrafter = config.recipes[linkedRecipeID]
        if exactCrafter and IsScanningEnabled(exactCrafter) then
            local recipeInfo = C_TradeSkillUI.GetRecipeInfo(linkedRecipeID)
            if recipeInfo then
                local itemIDs = HironCraftScan.Utils.GetOutputItems(recipeInfo)
                return exactCrafter, itemIDs and itemIDs[1], recipeInfo
            end
        end

        local ok, professionInfo = pcall(
            C_TradeSkillUI.GetProfessionInfoByRecipeID,
            linkedRecipeID
        )
        if ok and professionInfo and professionInfo.parentProfessionID then
            local genericCrafter = GenericCrafterForParentProfession(
                professionInfo.parentProfessionID,
                professionInfo.professionID
            )
            if genericCrafter then
                -- We know the profession but not that this character knows the
                -- recipe, so deliberately generate the safer profession-level
                -- response instead of claiming the exact craft.
                return genericCrafter
            end
        end
    end

    local itemFound, _, itemID
    if overrides and overrides.itemInfo then
        -- If this is a request from another HironCraftScan user, they provided the itemID.
        itemFound, _, itemID = overrides.itemInfo()
    else
        -- Determine the profession via the item link or keywords in the message
        itemFound, _, itemID = string.find(message, 'item:(%d+):')
    end

    if itemFound then
        itemID = tonumber(itemID)
        local crafterInfo = config.items[itemID]
        if crafterInfo then
            local profConfig =
                HironCraftScan.DB.characters[crafterInfo.crafter].professions[crafterInfo.profID]
            if IsScanningEnabled(crafterInfo) then
                local recipeInfo = GetRequestID(message, crafterInfo, profConfig)
                return crafterInfo, itemID, recipeInfo
            end
        end

        if not overrides or not overrides.forceCrafterInfo then
            return nil
        end
    end

    local bestMatch = nil

    local function FindBestCrafter(crafterInfo)
        -- For profession keywords, we store the parent profession ID,
        -- and need to determine which expansion's profession we should
        -- report. We check the sub-configurations for a recipe match, and if
        -- not found, return the largest profession ID, which presumable refers
        -- to the latest expansion.
        local crafterConfig = HironCraftScan.DB.characters[crafterInfo.crafter]
        local ppConfig = crafterConfig.parent_professions[crafterInfo.parentProfID]
        if ppConfig.scanning_enabled then
            local maxProfID = 0
            for pID, pConfig in pairs(crafterConfig.professions) do
                if pConfig.parentProfID == crafterInfo.parentProfID then
                    local recipeInfo = GetRequestID(message, crafterInfo, pConfig)
                    if recipeInfo then
                        return { crafter = crafterInfo.crafter, profID = pID }, nil, recipeInfo
                    end

                    if pID > maxProfID then
                        maxProfID = pID
                    end
                end
            end

            local profID = maxProfID
            if profID ~= nil and not bestMatch then
                bestMatch = { crafter = crafterInfo.crafter, profID = profID }
            end -- Keep looking for other crafters with keywords that match something specific.
        end
    end

    for _, crafterInfo in ipairs(config.prof_keywords) do
        if
            HasMatch(message, crafterInfo.keywords)
            and not HasMatch(message, crafterInfo.exclusions)
        then
            local crafterInfo, itemID, recipeInfo = FindBestCrafter(crafterInfo)
            if crafterInfo then
                return crafterInfo, itemID, recipeInfo
            end
        end
    end

    if not bestMatch and overrides and overrides.forceCrafterInfo then
        local crafterInfo, itemID, recipeInfo = FindBestCrafter(overrides.forceCrafterInfo)
        if crafterInfo then
            return crafterInfo, itemID, recipeInfo
        end
    end

    return bestMatch
end

-- Kept on Scanner so the link-routing behavior can be verified without
-- generating or sending a customer response.
HironCraftScan.Scanner.GetCrafterForMessage = GetCrafterForMessage

local function ConcatGreetings(lhs, rhs)
    if lhs and lhs ~= '' then
        if rhs and rhs ~= '' then
            return lhs .. ' ' .. rhs
        end
        return lhs
    end
    return rhs
end

local function MakeGreetingBuilder()
    local result = ''

    local function Greeting(text)
        result = ConcatGreetings(result, text)
    end

    local function FinalGreeting(context)
        -- Start by substituting tags, then substitute context. This allows tags
        -- to include context.
        result = HironCraftScan.Config.SubstituteTags(result)
        return HironCraftScan.Utils.FString(result, context)
    end

    return Greeting, FinalGreeting
end

HironCraftScan.OrderToCustomerInfo = function(order)
    local customers = HironCraftScan.DB.customers
    if not customers then
        return nil
    end
    return customers[order.customerName]
end

HironCraftScan.OrderToResponse = function(order)
    local customers = HironCraftScan.DB.customers
    return customers[order.customerName].responses[order.responseID]
end

HironCraftScan.OrderToLiveCustomerInfo = function(order, default)
    local customers = saved(HironCraftScan.LIVE, 'customers', default and {})
    if not customers then
        return nil
    end
    return saved(customers, order.customerName, default and {})
end

HironCraftScan.OrderToLiveResponses = function(order, default)
    local customerInfo = HironCraftScan.OrderToLiveCustomerInfo(order, default)
    if not customerInfo then
        return nil
    end
    return saved(customerInfo, 'responses', default and {})
end

HironCraftScan.OrderToLiveResponse = function(order, default)
    local responses = HironCraftScan.OrderToLiveResponses(order, default)
    if not responses then
        return nil
    end
    return saved(responses, order.responseID, default and {})
end

HironCraftScan.OrderToOrderID = function(order)
    return order.customerName .. '-' .. order.responseID
end

HironCraftScan.GetUnitName = function(unit, forceRealm)
    if HironCraftScan.State.realmID or forceRealm then
        local realm = HironCraftScan.Utils.ShortenRealmName(GetRealmName())
        return unit .. '-' .. realm
    end
    return unit
end

HironCraftScan.GetPlayerName = function(forceRealm)
    return HironCraftScan.GetUnitName(UnitName('player'), forceRealm)
end

local function ShortenedRealmForDisplay(name)
    local dash = string.find(name, '-')
    if dash then
        return name:sub(1, dash + 3)
    end
    return name
end

HironCraftScan.NameAndRealmToName = function(name, forDisplay)
    if HironCraftScan.State.realmID then
        if forDisplay then
            return ShortenedRealmForDisplay(name)
        end
        return name -- On cross-realm servers, never remove realm names.
    end
    return name:match('^([^-]+)')
end

HironCraftScan.ColorizePlayerName = function(name, guid)
    name = HironCraftScan.NameAndRealmToName(name)
    local _, class = GetPlayerInfoByGUID(guid)
    local cc = RAID_CLASS_COLORS[class]
    if cc then
        return cc:WrapTextInColorCode(name)
    end
    return name
end

local GetCrafterNameColor = function(name)
    if name ~= HironCraftScan.GetPlayerName() and name ~= HironCraftScan.GetPlayerName(true) then
        return CreateColor(1, 1, 1, 1)
    end
    return CreateColor(0, 1, 0, 1)
end

HironCraftScan.GetCrafterNameColor = function(name)
    return GetCrafterNameColor(name)
end

HironCraftScan.ColorizeCrafterName = function(name)
    local color = GetCrafterNameColor(name)
    return color:WrapTextInColorCode(HironCraftScan.NameAndRealmToName(name, true))
end

local lastChatFrameMessages = {}
local lastChatFrameIndex = 0 -- Incremented to 1 before use
-- A busy services channel can push more than ten formatted lines through the
-- chat frame before an item finishes loading and the matching callback runs.
local CHAT_FRAME_BUFFER_SIZE = 50

local function NormalizeChatHistorySearchText(text)
    if type(text) ~= 'string' then
        return ''
    end
    text = text:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '')
    text = text:gsub('|H.-|h(.-)|h', '%1')
    text = text:gsub('|T.-|t', ''):gsub('|A.-|a', '')
    return text:lower():gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
end

local function ChatTypeFromEvent(event)
    if type(event) ~= 'string' then
        return nil
    end
    return event:match('^CHAT_MSG_(.+)$')
end

local function MakeChatHistoryEntry(customer, expectedMessage, event)
    -- We've hacked together the ChatFrame and the CHAT_MSG_ events, but they
    -- are not guaranteed to line up with eachother because we depend on the
    -- message appearing on ChatFrame1 but it could appear on any (or no) chat
    -- frame. We listen to all channels even if they aren't displayed in any
    -- window. If we didn't see the message in a window, then we won't have any
    -- history on it, so we return the raw text without the nice formatting from
    -- the chat window.

    -- You can test this out by leaving 'Say' chat, then saying an order for
    -- yourself.
    local function DoIt(index)
        local lastChatFrameMessage = lastChatFrameMessages[index]
        if type(lastChatFrameMessage) ~= 'table' or type(lastChatFrameMessage.message) ~= 'string' then
            return nil
        end

        local formatted = NormalizeChatHistorySearchText(lastChatFrameMessage.message)
        local customerName = type(customer) == 'string'
            and NormalizeChatHistorySearchText(customer:match('^([^-]+)') or customer)
            or ''
        local expected = NormalizeChatHistorySearchText(expectedMessage)
        local customerMatches = customerName == '' or formatted:find(customerName, 1, true) ~= nil
        local messageMatches = expected == '' or formatted:find(expected, 1, true) ~= nil
        if customerMatches and messageMatches then
            return {
                message = lastChatFrameMessage.message,
                args = lastChatFrameMessage.args,
                chatType = ChatTypeFromEvent(event),
            }
        end
        return nil
    end

    -- We add entries to the circular buffer in increasing order, so start at
    -- the last added entry and work our way backwards to find the customer's
    -- message with formatting.
    local count = #lastChatFrameMessages
    if count > 0 and lastChatFrameIndex >= 1 then
        for offset = 0, count - 1 do
            local index = ((lastChatFrameIndex - offset - 1) % count) + 1
            local result = DoIt(index)
            if result then
                return result
            end
        end
    end

    return nil
end

local function MakeChatHistoryEntryDefault(customer, message, event)
    local found = MakeChatHistoryEntry(customer, message, event)
    if found then
        return found
    end
    local chatType = ChatTypeFromEvent(event) or 'WHISPER'
    local color = ChatTypeInfo and ChatTypeInfo[chatType]
    return {
        message = message,
        args = color and { color.r, color.g, color.b } or nil,
        chatType = chatType,
    }
end

local function GetGreeting(tag)
    -- We support configured or internationalized greetings. They use the
    -- same naming pattern, so we can look them up by tag.
    local greeting = HironCraftScan.DB.settings.greeting
    if not greeting then
        return L(LID[tag])
    end
    return greeting[tag] or L(LID[tag])
end

HironCraftScan.Utils.GetGreeting = GetGreeting

-- Commission values are configured per recipe, with the parent profession as
-- the fallback. Keep the lookup in one place so customer search results and
-- contextual quick replies cannot disagree about the quoted price.
function HironCraftScan.GetConfiguredCommission(crafterFullName, profID, recipeID)
    local charConfig = HironCraftScan.DB.characters[crafterFullName]
    local profConfig = charConfig and charConfig.professions and charConfig.professions[profID]
    if not profConfig then
        return nil
    end

    local recipeConfig = recipeID and profConfig.recipes and profConfig.recipes[recipeID]
    local itemCommission = recipeConfig and recipeConfig.commission
    if itemCommission and itemCommission ~= '' then
        return HironCraftScan.Config.SubstituteTags(itemCommission)
    end

    local parentProfConfig = charConfig.parent_professions
        and charConfig.parent_professions[profConfig.parentProfID]
    local professionCommission = parentProfConfig and parentProfConfig.commission

    -- Older saved data could still have the commission on the expansion
    -- profession. Preserve it as a final compatibility fallback.
    professionCommission = professionCommission or profConfig.commission
    if professionCommission and professionCommission ~= '' then
        return HironCraftScan.Config.SubstituteTags(professionCommission)
    end

    return nil
end

function HironCraftScan.GetCommissionForResponse(response)
    if not response then
        return nil
    end
    return HironCraftScan.GetConfiguredCommission(
        response.crafterFullName,
        response.professionID,
        response.recipeID
    )
end

local function GetProfessionLink(profInfo)
    if not profInfo then
        return nil
    end

    local spellSkillIndex = C_SpellBook.GetSkillLineIndexByID(profInfo.parentProfessionID)
    local skillLineInfo = spellSkillIndex
        and C_SpellBook.GetSpellBookSkillLineInfo(spellSkillIndex)
    if not skillLineInfo then
        return nil
    end

    local skillSpellID = select(
        2,
        C_SpellBook.GetSpellBookItemType(
            skillLineInfo.itemIndexOffset + 1,
            Enum.SpellBookSpellBank.Player
        )
    )
    return skillSpellID and C_Spell.GetSpellTradeSkillLink(skillSpellID) or nil
end

local function BuildResponseContext(crafterFullName, profID, itemID, itemLink, recipeID)
    local profInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(profID)
    local crafter = HironCraftScan.NameAndRealmToName(crafterFullName)
    local altCraft = crafter ~= HironCraftScan.GetPlayerName()
    local professionName = profInfo and profInfo.parentProfessionName or nil
    local professionLink = professionName
    if not altCraft then
        professionLink = GetProfessionLink(profInfo) or professionName
    end

    return {
        crafter = crafter,
        item = itemLink or (itemID and select(2, GetItemInfo(itemID))) or L(LID.GREETING_LINK_BACKUP),
        profession = professionName,
        profession_link = professionLink,
        commission = HironCraftScan.GetConfiguredCommission(crafterFullName, profID, recipeID),
    }, altCraft
end

-- Expose the same context used by greetings to follow-up features. Stored
-- response fields are used as fallbacks because profession/item APIs can be
-- temporarily unavailable while the client cache is warming up.
function HironCraftScan.BuildResponseContext(response)
    if not response or not response.crafterFullName or not response.professionID then
        return nil
    end

    local context = BuildResponseContext(
        response.crafterFullName,
        response.professionID,
        response.itemID,
        nil,
        response.recipeID
    )
    context.crafter = response.crafterName or context.crafter
    context.profession = response.professionName or context.profession
    context.profession_link = context.profession_link or context.profession
    return context
end

-- Builds the greeting text for a pending order. Computes alt_craft based on
-- the *current* logged-in character so the message stays accurate when the
-- player logs into the crafter character after the notification was created.
local function BuildRawGreeting(crafterFullName, profID, itemID, itemLink, recipeID)
    local profConfig = HironCraftScan.DB.characters[crafterFullName].professions[profID]
    local recipeConfig = recipeID and profConfig.recipes[recipeID] or nil

    local context, alt_craft =
        BuildResponseContext(crafterFullName, profID, itemID, itemLink, recipeID)

    local GeneralGreeting, GeneralFinalGreeting = MakeGreetingBuilder()
    local Greeting, FinalGreeting = MakeGreetingBuilder()
    if alt_craft then
        if itemID then
            GeneralGreeting(GetGreeting('GREETING_ALT_CAN_CRAFT_ITEM'))
        else
            GeneralGreeting(GetGreeting('GREETING_ALT_HAS_PROF'))
        end
    else
        if itemID then
            GeneralGreeting(GetGreeting('GREETING_I_CAN_CRAFT_ITEM'))
        else
            GeneralGreeting(GetGreeting('GREETING_I_HAVE_PROF'))
        end
    end

    if not profConfig.omit_general and (not recipeConfig or not recipeConfig.omit_general) then
        Greeting(GeneralFinalGreeting(context))
    else
        context.general_greeting = GeneralFinalGreeting(context)
    end

    if HironCraftScan.State.isBusy then
        Greeting(GetGreeting('GREETING_BUSY'))
    end

    if not recipeConfig or not recipeConfig.omit_profession then
        Greeting(profConfig.greeting)
    end

    if recipeConfig then
        Greeting(recipeConfig.greeting)
    end

    if alt_craft then
        Greeting(GetGreeting('GREETING_ALT_SUFFIX'))
    end

    return FinalGreeting(context), alt_craft
end

-- If the player has logged into the crafter character since the notification
-- was saved, the stored message may say "my alt X can craft this" even though
-- we are now playing X. Rebuild it so it uses the first-person greeting.
HironCraftScan.RebuildResponseMessage = function(order)
    local response = HironCraftScan.OrderToResponse(order)
    if not response or response.greeting_sent or not response.crafterFullName then
        return
    end
    local crafter = HironCraftScan.NameAndRealmToName(response.crafterFullName)
    local currentAltCraft = crafter ~= HironCraftScan.GetPlayerName()
    if currentAltCraft == response.alt_craft then
        return
    end
    local greeting, newAltCraft =
        BuildRawGreeting(response.crafterFullName, response.professionID, response.itemID, nil, response.recipeID)
    response.message = SplitResponse(greeting)
    response.alt_craft = newAltCraft
end

local function handleResponse(message, customer, crafterInfo, itemID, recipeInfo, item, overrides, chatEvent)
    -- At this point, we have everything we need to generate a response to the message.
    local itemLink = item and item:GetItemLink() or nil

    -- TODO - Want to make the item look 5*, but this doesn't send through chat.
    --if itemLink then
    --local tier5 = Professions.GetChatIconMarkupForQuality(5, true, 0);
    --itemLink = itemLink .. " " .. tier5;
    --end

    -- We keep a history of our customers to avoid spamming the same person repeatedly.
    local customerInfo = HironCraftScan.DB.customers[customer]

    -- Be as specific as possible about what we're responding to.
    local profID = crafterInfo.profID
    local recipeID = recipeInfo and recipeInfo.recipeID
    local responseID = recipeID or profID

    local needsResultCallbackOnly = overrides and overrides.resultCallback

    local responses = saved(customerInfo, 'responses', {})
    local response = saved(responses, responseID, {})
    local firstInteraction = not next(response)
    local restartingTerminalRequest = overrides
        and overrides.restartTerminalRequest == true
        or false
    if
        overrides
        and overrides.existingCustomerRequest
        and HironCraftScan.OrderFulfillment
    then
        local existingStatus = HironCraftScan.OrderFulfillment:GetStatus({
            customerName = customer,
            responseID = responseID,
        })
        local status = existingStatus and existingStatus.status
        restartingTerminalRequest = status == HironCraftScan.OrderFulfillment.Status.Fulfilled
            or status == HironCraftScan.OrderFulfillment.Status.Rejected
            or status == HironCraftScan.OrderFulfillment.Status.Failed
    end
    if
        restartingTerminalRequest
        and response.responseID ~= nil
        and response.responseID ~= responseID
    then
        -- A recipe-specific response is also aliased under its profession ID.
        -- A later profession-only request must get a fresh response instead of
        -- mutating the old completed recipe row through that alias.
        response = {}
        responses[responseID] = response
        firstInteraction = true
    end
    if
        response.greeting_sent
        and not needsResultCallbackOnly
        and not restartingTerminalRequest
    then
        -- We already messaged the customer about this craft
        return
    end

    local profInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(profID)
    local profConfig = HironCraftScan.DB.characters[crafterInfo.crafter].professions[profID]

    local crafter = HironCraftScan.NameAndRealmToName(crafterInfo.crafter)
    local greeting, alt_craft = BuildRawGreeting(crafterInfo.crafter, profID, itemID, itemLink, recipeID)

    if needsResultCallbackOnly then
        -- Erase the persistent state associated with this since it's just a
        -- query the the crafter shouldn't know about yet until the customer
        -- chooses to interact.
        HironCraftScan.DismissOrder({
            customerName = customer,
            responseID = responseID,
        })

        overrides.resultCallback(
            crafter,
            greeting,
            HironCraftScan.GetConfiguredCommission(crafterInfo.crafter, profID, recipeID)
        )
        return
    end

    response.message = SplitResponse(greeting)
    local chat_history = saved(customerInfo, 'chat_history', {})
    local requestChatEntry
    if not (overrides and overrides.chatHistoryAlreadyStored) then
        requestChatEntry = MakeChatHistoryEntryDefault(customer, message, chatEvent)
        table.insert(chat_history, requestChatEntry)
    else
        requestChatEntry = chat_history[#chat_history]
    end

    if firstInteraction or restartingTerminalRequest then
        response.requestToken = overrides and overrides.requestToken
            or NewRequestToken(customer, responseID, requestChatEntry)
    end

    -- Save the request at higher granularities as well so that we don't
    -- respond to someone a second time for something more generic. E.g. we
    -- responded to 'lf bs <item>', they didn't take the offer, then they
    -- requested 'lf bs'. We don't want to message that person again after
    -- they rejected us offering the exact item they wanted.
    if not responses[profID] then
        responses[profID] = response
        local children = saved(response, 'less_granular', {})
        table.insert(children, profID)
    end

    local greeting_queued = not alt_craft
        and HironCraftScan.auto_replies_enabled
        and not (overrides and overrides.existingCustomerRequest)
    if greeting_queued then
        C_Timer.After(HironCraftScan.Utils.GetSetting('auto_reply_delay') / 1000, function()
            HironCraftScan.Utils.SendResponses(response.message, customer)
            response.greeting_sent = true
        end)
    end

    local now = time()

    local customerStartedInteraction = overrides and overrides.customerStartedInteraction

    response.crafterName = crafter
    response.crafterFullName = crafterInfo.crafter
    response.alt_craft = alt_craft
    response.professionID = profID
    response.parentProfID = profInfo.parentProfessionID
    response.professionName = profInfo.parentProfessionName
    response.itemID = itemID
    response.recipeID = recipeID
    response.time = now
    response.responseID = responseID
    response.greeting_sent = overrides and overrides.greeted or customerStartedInteraction
    if customerStartedInteraction then
        response.customer_answered = true
    end


    if restartingTerminalRequest then
        local order = {
            customerName = customer,
            responseID = responseID,
        }
        -- The visual row is intentionally reused, but its request token and
        -- timestamp now identify a new job. Old green/yellow status entries no
        -- longer apply to it.
        HironCraftScan.DB.listed_orders[HironCraftScan.OrderToOrderID(order)] = order
    end

    if firstInteraction then
        local order = {
            customerName = customer,
            responseID = responseID,
        }
        HironCraftScan.DB.listed_orders[HironCraftScan.OrderToOrderID(order)] = order

        local ppConfig = ParentProfessionConfig(crafterInfo)

        local isAlertFiltered = (
            ppConfig.local_alerts_only and HironCraftScan.GetPlayerName(true) ~= crafterInfo.crafter
        )
        if ppConfig.visual_alert_enabled and not isAlertFiltered then
            HironCraftScan.State.activeOrder = order

            FlashClientIcon()

            if not greeting_queued and not customerStartedInteraction then
                HironCraftScanScannerMenu:TriggerAlert(
                    string.format(
                        '%s\n%s (%s)',
                        HironCraftScan.ColorizePlayerName(customer, customerInfo.guid),
                        itemLink
                            or HironCraftScan.Utils.ColorizeProfessionName(
                                profInfo.parentProfessionID,
                                profInfo.parentProfessionName
                            ),
                        HironCraftScan.ColorizeCrafterName(crafter)
                    ),
                    order
                )

                if not HironCraftScanCraftingOrderPage:IsShown() then
                    HironCraftScanScannerMenu:TriggerPulseLock('scanned')
                end
            end
        end

        if ppConfig.sound_alert_enabled and not isAlertFiltered then
            PlaySoundFile(HironCraftScan.Utils.GetSetting('ping_sound'), 'Master')
        end

        HironCraftScanCraftingOrderPage:ShowGeneric()
    end

    HironCraftScanComm:ShareCustomerOrder(
        message,
        customer,
        customerInfo.guid,
        chat_history[#chat_history],
        response.requestToken,
        restartingTerminalRequest
    )
end

local function BaseCustomerName(name)
    if type(name) ~= 'string' then
        return nil
    end
    return (name:match('^([^-]+)') or name):lower()
end

local function ResolveExistingCustomer(customer, customerGuid)
    local customers = HironCraftScan.DB.customers or {}
    local guidCanBeCompared = customerGuid
        and (type(issecretvalue) ~= 'function' or not issecretvalue(customerGuid))
    if customers[customer]
        and (not guidCanBeCompared or not customers[customer].guid or customers[customer].guid == customerGuid)
    then
        return customer, customers[customer]
    end

    -- Whisper events can omit the realm even though the original channel
    -- request was stored as Name-Realm (or the reverse). Use a base-name match
    -- only when it is unambiguous, otherwise keep the realms separated.
    local wanted = BaseCustomerName(customer)
    local foundKey, foundInfo
    for key, info in pairs(customers) do
        if BaseCustomerName(key) == wanted then
            if guidCanBeCompared and info.guid == customerGuid then
                return key, info
            end
            if foundKey then
                return nil, nil
            end
            foundKey, foundInfo = key, info
        end
    end
    return foundKey, foundInfo
end

function HironCraftScan.ApplyRemoteCustomerChat(customer, customerGuid, entry, incoming)
    if type(customer) ~= 'string'
        or type(entry) ~= 'table'
        or type(entry.message) ~= 'string'
    then
        return false
    end

    local existingCustomer, customerInfo = ResolveExistingCustomer(customer, customerGuid)
    customer = existingCustomer or customer
    customerInfo = customerInfo or saved(HironCraftScan.DB.customers, customer, {})
    if customerGuid and not customerInfo.guid then
        customerInfo.guid = customerGuid
    end

    local chatHistory = saved(customerInfo, 'chat_history', {})
    if entry.syncID then
        for _, stored in ipairs(chatHistory) do
            if stored.syncID == entry.syncID then
                return false
            end
        end
    end

    table.insert(chatHistory, HironCraftScan.Utils.DeepCopy(entry))
    if incoming then
        for _, response in pairs(customerInfo.responses or {}) do
            if response.greeting_sent then
                response.customer_answered = true
            end
        end
    end
    if HironCraftScanCraftingOrderPage and HironCraftScanCraftingOrderPage.ShowGeneric then
        HironCraftScanCraftingOrderPage:ShowGeneric()
    end
    return true
end

function HironCraftScan.OnMessage(event, message, customer, customerGuid, overrides)
    if not message or not customer then
        return false
    end

    local existingCustomer, customerInfo = ResolveExistingCustomer(customer, customerGuid)
    if existingCustomer then
        customer = existingCustomer
    end

    local ignored = HironCraftScan.DB.settings.ignored and HironCraftScan.DB.settings.ignored[customer]
    if ignored then
        return false
    end

    local crafterInfo, itemID, recipeInfo

    if event == 'CHAT_MSG_WHISPER_INFORM' then
        if customerInfo then
            local chat_history = saved(customerInfo, 'chat_history', {})
            local entry = MakeChatHistoryEntryDefault(customer, message, event)
            table.insert(chat_history, entry)
            if HironCraftScanComm and HironCraftScanComm.ShareCustomerChat then
                HironCraftScanComm:ShareCustomerChat(customer, customerInfo.guid, entry, false)
            end
        end
        return false
    end

    if event == 'CHAT_MSG_WHISPER' then
        if customerInfo then
            local chat_history = saved(customerInfo, 'chat_history', {})
            local entry = MakeChatHistoryEntryDefault(customer, message, event)
            table.insert(chat_history, entry)
            if HironCraftScanComm and HironCraftScanComm.ShareCustomerChat then
                HironCraftScanComm:ShareCustomerChat(customer, customerGuid or customerInfo.guid, entry, true)
            end

            for _, response in pairs(customerInfo.responses) do
                if response.greeting_sent then
                    response.customer_answered = true
                end
            end
            if HironCraftScan.QuickReplies then
                HironCraftScan.QuickReplies:OnWhisper(customer, message, customerInfo)
            end
            HironCraftScanCraftingOrderPage:ShowGeneric()
            FlashClientIcon()

            -- Follow-up questions stay in the current conversation. Only a
            -- message that independently matches the craft scanner continues
            -- below, where a terminal row can be reopened as a new request.
            overrides = overrides or {}
            crafterInfo, itemID, recipeInfo = GetCrafterForMessage(
                customer,
                message,
                overrides
            )
            if not crafterInfo then
                return false
            end
            overrides.customerStartedInteraction = true
            overrides.existingCustomerRequest = true
            overrides.chatHistoryAlreadyStored = true
        end
        if not overrides then
            overrides = {}
        end

        -- If they are whispering us about a craft, we want to match it and get
        -- it in our table so we can keep track of them, but we don't need a big
        -- alert. We'll still flash the client icon so you know to tab back in.
        overrides.customerStartedInteraction = true
    end

    if not crafterInfo then
        crafterInfo, itemID, recipeInfo = GetCrafterForMessage(customer, message, overrides)
    end
    if not crafterInfo then
        return false
    end

    local customerInfo = saved(HironCraftScan.DB.customers, customer, {})
    customerInfo.guid = customerGuid

    if itemID or recipeInfo then
        if not itemID then
            -- We didn't find an item in the message, but if the message
            -- matched an item by keyword, we can still find it.
            local itemIDs = HironCraftScan.Utils.GetOutputItems(recipeInfo)
            itemID = itemIDs and itemIDs[1]
        end

        if itemID then
            local item = Item:CreateFromItemID(itemID)
            item:ContinueOnItemLoad(function()
                handleResponse(message, customer, crafterInfo, itemID, recipeInfo, item, overrides, event)
            end)
            return false
        end
    end

    handleResponse(message, customer, crafterInfo, itemID, recipeInfo, nil, overrides, event)

    return false
end

local function OnMessage_(self, event, ...)
    local message, customer = ...

    if issecretvalue(message) then return end

    local customerGuid = select(12, ...)
    HironCraftScan.OnMessage(event, message, customer, customerGuid)
end

local frame = CreateFrame('frame')

-- Can't unhook, so we disable it without the table allocation at least.
local registered = false
local disableHook = false

local function InsertChatFrame(message, args)
    if #lastChatFrameMessages < CHAT_FRAME_BUFFER_SIZE then
        table.insert(lastChatFrameMessages, {})
    end
    lastChatFrameIndex = lastChatFrameIndex % CHAT_FRAME_BUFFER_SIZE + 1 -- Wow this looks weird. Thanks Lua 1-basedness
    local currentChatFrame = lastChatFrameMessages[lastChatFrameIndex]

    currentChatFrame.message = message
    currentChatFrame.args = args
end
local function CaptureChatMessage(chatFrame, message, ...)
    if disableHook then
        return
    end

    -- For Prat integration, we grab the historyBuffer value, which has
    -- the timestamp separately added. 'message' does not include it.
    local displayedMessage = message
    local historyBuffer = chatFrame and chatFrame.historyBuffer
    local entry = historyBuffer
        and historyBuffer.GetEntryAtIndex
        and historyBuffer:GetEntryAtIndex(1)
    if entry and type(entry.message) == 'string' then
        displayedMessage = entry.message
    end
    if type(displayedMessage) == 'string' then
        InsertChatFrame(displayedMessage, SafePack(...))
    end
end

function HironCraftScan.InjectLastChatFrameMessage(customer, message, last)
    -- If we didn't see the same message, append it to our history and return
    -- that we should continue processing it. Otherwise, this account has
    -- already seen it so we can stop working.
    if type(last) ~= 'table' or type(last.message) ~= 'string' then
        return true
    end

    local found = MakeChatHistoryEntry(customer, message, 'CHAT_MSG_CHANNEL')
    if not found or found.message ~= last.message then
        HironCraftScan.Utils.printTable('Inserting', last.message)
        InsertChatFrame(last.message, last.args)
        return true
    else
        HironCraftScan.Utils.printTable('Filtering', last.message)
        HironCraftScan.Utils.printTable('Because', found.message)
    end
    return false
end

local function UpdateScannerEventRegistry(...)
    -- For our chat history feature, we want to replicate what we saw in the
    -- chat window. The CHAT_MSG events give us the message text, but not what
    -- appeared in the window. I haven't found any way to correlate a CHAT_MSG
    -- with the history buffer of the chat windows. Instead, we record each
    -- AddMessage call on the main window, and then when we process a CHAT_MSG
    -- event that matches, we grab the last message recorded here to get the
    -- full ChatFrame format.
    if HironCraftScan.Utils.IsScanningEnabled(...) then
        disableHook = false

        if not registered then
            frame:RegisterEvent('CHAT_MSG_SAY')
            frame:RegisterEvent('CHAT_MSG_PARTY')
            frame:RegisterEvent('CHAT_MSG_CHANNEL')
            frame:RegisterEvent('CHAT_MSG_GUILD')
            frame:RegisterEvent('CHAT_MSG_WHISPER')
            frame:RegisterEvent('CHAT_MSG_WHISPER_INFORM')
            registered = true
        end
    else
        disableHook = true
        if registered then
            registered = false
            frame:UnregisterEvent('CHAT_MSG_SAY')
            frame:UnregisterEvent('CHAT_MSG_PARTY')
            frame:UnregisterEvent('CHAT_MSG_CHANNEL')
            frame:UnregisterEvent('CHAT_MSG_GUILD')
            frame:UnregisterEvent('CHAT_MSG_WHISPER')
            frame:UnregisterEvent('CHAT_MSG_WHISPER_INFORM')
        end
    end
end

HironCraftScan.Utils.onLoad(function()
    HironCraftScan.Scanner.LoadConfig()

    frame:SetScript('OnEvent', OnMessage_)

    HironCraftScan.Utils.RegisterEnableDisableCallback(UpdateScannerEventRegistry)
    hooksecurefunc(_G.ChatFrame1, 'AddMessage', CaptureChatMessage)
    UpdateScannerEventRegistry()

    CleanRecentAnalytics()
end)
