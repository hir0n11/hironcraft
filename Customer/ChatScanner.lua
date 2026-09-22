local HironCraftScan = select(2, ...)

local LID = HironCraftScan.CONST.TEXT
local function L(id)
    return HironCraftScan.LOCAL:GetText(id)
end

local saved = HironCraftScan.Utils.saved
local requestTokenSerial = 0
local GENERAL_REQUEST_ID = '__hironcraft_general_request__'

local function NewRequestToken(customer, responseID, chatEntry)
    if chatEntry and type(chatEntry.syncID) == 'string' then
        return chatEntry.syncID .. ':' .. tostring(responseID)
    end
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

-- Hyperlinks (including their quality atlas and color) are indivisible. A
-- whitespace inside [an item name] is not a safe chat-message boundary.
local function SplitResponse(raw_response)
    local result = {}
    for _, line in ipairs({ strsplit('\n', raw_response) }) do
        local response, space, position = '', '', 1
        local function Flush()
            if response ~= '' then result[#result + 1] = response end
            response = ''
        end
        while position <= #line do
            local tail = line:sub(position)
            local whitespace = tail:match('^%s+')
            if whitespace then
                space = whitespace
                position = position + #whitespace
            else
                local color = tail:match('^|c%x%x%x%x%x%x%x%x') or tail:match('^|cn[%w_]+:') or ''
                local start = position + #color
                local ending
                if line:sub(start, start + 1) == '|H' then
                    local header = line:find('|h', start + 2, true)
                    local label = header and line:find('|h', header + 2, true)
                    if label then
                        ending = label + 1
                        if line:sub(ending + 1, ending + 2) == '|r' then ending = ending + 2 end
                    end
                elseif tail:sub(1, 2) == '|A' or tail:sub(1, 2) == '|T' then
                    local close = line:find(tail:sub(1, 2) == '|A' and '|a' or '|t', position + 2, true)
                    ending = close and close + 1
                end
                local atomic = ending ~= nil
                if not ending then
                    ending = position
                    while ending < #line and not line:sub(ending + 1, ending + 1):match('[%s|]') do
                        ending = ending + 1
                    end
                end
                local token = line:sub(position, ending)
                if #response + #space + #token > 255 then Flush() end
                -- Never cut a UTF-8 character in an unusually long plain word.
                while not atomic and #token > 255 do
                    local cut = 255
                    while cut > 0 and token:byte(cut + 1) >= 128 and token:byte(cut + 1) < 192 do cut = cut - 1 end
                    if cut == 0 then cut = 255 end
                    result[#result + 1] = token:sub(1, cut)
                    token = token:sub(cut + 1)
                end
                response = response .. (response ~= '' and space or '') .. token
                space = ''
                position = ending + 1
            end
        end
        -- An individual link longer than the chat limit stays whole; the
        -- sender's preflight rejects it instead of emitting invalid fragments.
        Flush()
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
        -- Keywords require an inclusion; monitored item links may stand alone.
        exclusions = {},
        inclusions = {},
        generic_requests = {},
        prof_keywords = {},
        items = {},
        recipes = {},
        equipment = {},
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
HironCraftScan.Scanner.GENERAL_REQUEST_ID = GENERAL_REQUEST_ID

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
    config.generic_requests = ParseStringList(
        HironCraftScan.DB.settings.generic_request_keywords
            or L(HironCraftScan.CONST.TEXT.GENERIC_REQUEST_KEYWORDS_DEFAULT)
    )

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
                                local getInfo=C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
                                if type(getInfo)=='function' then
                                    local ok,_,_,_,slot,_,itemClass,subClass=pcall(getInfo,itemID)
                                    if ok and type(slot)=='string' and slot~='' then
                                        if slot=='INVTYPE_ROBE' then slot='INVTYPE_CHEST' end
                                        config.equipment[crafter]=config.equipment[crafter] or {}
                                        local byProfession=config.equipment[crafter]
                                        byProfession[parentProfID]=byProfession[parentProfID] or {}
                                        byProfession[parentProfID]['slot:'..slot]=true
                                        if itemClass==2 and type(subClass)=='number' then
                                            byProfession[parentProfID]['weapon:'..subClass]=true
                                        end
                                    end
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

local function RecipeIdForKeywords(message, profConfig, armorContext)
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
            if matchLen and (not armorContext or HironCraftScan.ClassMatching.MatchesRecipe(
                armorContext, C_TradeSkillUI.GetRecipeInfo(id))) then
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

local function GetRequestID(message, crafterInfo, profConfig, armorContext)
    local recipeID = crafterInfo.recipeID
    if not recipeID then
        recipeID = RecipeIdForKeywords(message, profConfig, armorContext)
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

local function MonitorsEquipmentRequest(crafterInfo,request)
    if not request or not request.dynamicProfession then return true end
    local byCrafter=config.equipment[crafterInfo.crafter]
    local byProfession=byCrafter and byCrafter[crafterInfo.parentProfID]
    if not byProfession then return false end
    if request.subclasses then
        for subclass in pairs(request.subclasses) do
            if byProfession['weapon:'..subclass] then return true end
        end
        return false
    end
    return request.slot and byProfession['slot:'..request.slot]==true or false
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

local function GetMonitoredItemMatches(message)
    local lower = message:lower()
    local matches, seen = {}, {}
    local position = 1
    while true do
        local first, last, id = lower:find('|hitem:(%d+):[^|]*|h.-|h', position)
        if not first then break end
        position = last + 1
        local itemID = tonumber(id)
        local crafterInfo = config.items[itemID]
        if crafterInfo and not seen[crafterInfo.recipeID] and IsScanningEnabled(crafterInfo) then
            local character = HironCraftScan.DB.characters[crafterInfo.crafter]
            local profession = character.professions[crafterInfo.profID]
            local recipe = profession.recipes[crafterInfo.recipeID]
            local parent = ParentProfessionConfig(crafterInfo)
            if recipe and HironCraftScan.Scanner.RecipeScanningOn(profession, recipe)
                and not HasMatch(lower, ParseStringList(parent.exclusions or '')) then
                local recipeInfo = C_TradeSkillUI.GetRecipeInfo(crafterInfo.recipeID)
                if recipeInfo then
                    -- Preserve the actual linked variant and its display text.
                    local prefix = message:sub(1, first - 1)
                    local color = prefix:match('(|c%x%x%x%x%x%x%x%x)$') or prefix:match('(|cn[%w_]+:)$')
                    if color then first = first - #color end
                    if lower:sub(last + 1, last + 2) == '|r' then last = last + 2 end
                    seen[crafterInfo.recipeID] = true
                    matches[#matches + 1] = {
                        crafterInfo = crafterInfo, itemID = itemID, recipeInfo = recipeInfo,
                        itemLink = message:sub(first, last), position = first,
                    }
                end
            end
        end
    end

    -- Recipe links ("Midnight Inscription: Aln'hara Lantern") ask for a craft
    -- just like item links. Every one of them counts, not only the first.
    -- A recipe this account knows gets its exact row; one it does not know is
    -- asked of a crafter of that profession, as a profession row.
    local seenProfession = {}
    for _, pattern in ipairs({ '()|henchant:(%d+)', '()|hrecipe:(%d+)' }) do
        for linkStart, id in lower:gmatch(pattern) do
            local recipeID = tonumber(id)
            local exact = recipeID and config.recipes[recipeID]
            if recipeID and not seen[recipeID] then
                seen[recipeID] = true
                local recipeInfo = exact and IsScanningEnabled(exact) and C_TradeSkillUI.GetRecipeInfo(recipeID)
                if recipeInfo then
                    local outputs = HironCraftScan.Utils.GetOutputItems(recipeInfo)
                    matches[#matches + 1] = {
                        crafterInfo = exact, itemID = outputs and outputs[1], recipeInfo = recipeInfo,
                        position = linkStart, fromRecipeLink = true,
                    }
                else
                    local ok, professionInfo = pcall(C_TradeSkillUI.GetProfessionInfoByRecipeID, recipeID)
                    local generic = ok and professionInfo and professionInfo.parentProfessionID
                        and GenericCrafterForParentProfession(professionInfo.parentProfessionID,
                            professionInfo.professionID)
                    local key = generic and (generic.crafter .. ':' .. tostring(generic.profID))
                    if generic and not seenProfession[key] then
                        seenProfession[key] = true
                        matches[#matches + 1] = {
                            crafterInfo = generic, position = linkStart,
                            fromRecipeLink = true, professionOnly = true,
                        }
                    end
                end
            end
        end
    end
    table.sort(matches, function(lhs, rhs) return lhs.position < rhs.position end)
    return matches
end

local function IsCrafterAdvertisement(message)
    if type(message) ~= 'string' then return false end
    -- Match the author's words, never item/profession names inside links.
    local text = (strlower or string.lower)(message)
        :gsub('|h[^|]+|h.-|h', ' '):gsub('|a.-|a', ' '):gsub('|t.-|t', ' ')
        :gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|cn[%w_]+:', ''):gsub('|r', '')
    local question = text:find('?', 1, true)
    text = text:gsub('[%p%c]', ' '):gsub('%s+', ' '):match('^%s*(.-)%s*$')
    -- Greetings often precede an unsolicited sales pitch. Strip whole words
    -- only; do not mistake "can YOU craft", LF, or a bare link for an offer.
    local changed = true
    while changed do
        local count
        text, count = text:gsub('^hi%s+', '')
        if count == 0 then text, count = text:gsub('^hello%s+', '') end
        if count == 0 then text, count = text:gsub('^hey%s+', '') end
        if count == 0 then text, count = text:gsub('^mate%s+', '') end
        if count == 0 then text, count = text:gsub('^привет%s+', '') end
        changed = count > 0
    end
    local destination = text:match('^send%s+to%s+(%a+)')
        or text:match('^send%s+orders?%s+to%s+(%a+)')
    if destination == 'who' or destination == 'whom' or destination == 'which'
        or destination == 'what' or destination == 'where' then return false end
    if not question and (text:find('^send%s+to%s+%S')
        or text:find('^send%s+orders?%s+to%s+%S')) then return true end
    local offers = {
        '^i%s+can%s+craft%f[%A]', '^i%s+can%s+recraft%f[%A]',
        '^i%s+craft%f[%A]', '^i%s+recraft%f[%A]',
        '^wts%f[%A]', '^crafting%s+services%f[%A]',
        '^могу скрафтить', '^могу перекрафтить', '^крафчу', '^изготовлю',
        '^отправляй заказ', '^отправляйте заказ', '^заказы на ',
    }
    for _, pattern in ipairs(offers) do
        if text:find(pattern) then return true end
    end
    -- "Can craft [item]?" can be a terse customer question.
    return not question and (text:find('^can%s+craft%f[%A]') ~= nil
        or text:find('^can%s+recraft%f[%A]') ~= nil)
end
HironCraftScan.Scanner.IsCrafterAdvertisement = IsCrafterAdvertisement

local function GetCrafterForMessage(customer, message, overrides, customerGuid)
    local originalMessage = message
    message = string.lower(message)

    -- An explicit UI choice wins over every keyword/link and never depends on
    -- item-cache callbacks. Offer the chosen profession, not an unverified item.
    if overrides and overrides.forceCrafterInfo then
        local forced = overrides.forceCrafterInfo
        local char = HironCraftScan.DB.characters[forced.crafter]
        local parent = char and char.parent_professions[forced.parentProfID]
        if not parent or not parent.scanning_enabled or parent.character_disabled then return nil end
        local newest
        for id, profession in pairs(char.professions or {}) do
            if profession.parentProfID == forced.parentProfID and (not newest or id > newest) then newest = id end
        end
        return newest and {crafter=forced.crafter, profID=newest} or nil
    end

    if not overrides or (not overrides.forceCrafterInfo and not overrides.itemInfo) then
        if IsCrafterAdvertisement(originalMessage) then return nil end
        if HasMatch(message, config.exclusions) then
            return nil
        end

        local hasKeywords = HasMatch(message, config.inclusions)
        local itemMatches = GetMonitoredItemMatches(originalMessage)
        local genericFollowup = overrides and overrides.genericFollowup == true
        -- A bare link is a request too: people often post just the recipe of
        -- the gear they want, known to us or not. Crafter ads were filtered
        -- out above.
        if not hasKeywords and not genericFollowup
            and (HironCraftScan.DB.settings.scan_item_links_without_keywords == false
                or #itemMatches == 0) then
            return nil
        end

        if not HironCraftScanComm.applying_remote_state
            and not (HironCraftScan.BattleNet and HironCraftScan.BattleNet.IsCustomer(customer)) then
            -- Don't add to analytics based on proxied orders. The 'now' might
            -- be slightly off because of the messaging. We don't want that to
            -- create duplicates if both characters see the same message at the
            -- same time. Instead, analytics can be separately sync'ed between
            -- accounts, with a merge of timestamps to avoid creating
            -- duplicates.

            -- Analytics has its own handling of quality links, including items
            -- this account does not monitor.
            AddMessageToAnalytics(customer, message)
        end

        if #itemMatches > 0 then
            local first = itemMatches[1]
            return first.crafterInfo, first.itemID, first.recipeInfo, itemMatches
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
            if IsScanningEnabled(crafterInfo)
                and not HasMatch(message, ParseStringList(ParentProfessionConfig(crafterInfo).exclusions or '')) then
                local recipeInfo = GetRequestID(message, crafterInfo, profConfig)
                return crafterInfo, itemID, recipeInfo
            end
        end

        if not overrides or not overrides.forceCrafterInfo then
            return nil
        end
    end

    local armorContext
    if HironCraftScan.ClassMatching and not (overrides and overrides.forceCrafterInfo) then
        local existing = HironCraftScan.DB.customers and HironCraftScan.DB.customers[customer]
        armorContext = HironCraftScan.ClassMatching.GetContext(originalMessage,
            customerGuid or (existing and existing.guid),
            HironCraftScanComm.applying_remote_state and overrides and overrides.customerClass)
    end
    local equipmentRequests = HironCraftScan.ClassMatching
        and HironCraftScan.ClassMatching.GetRequests(armorContext) or nil
    -- Without the customer's class an armor slot cannot be routed, but a ring,
    -- a cloak or a dagger never needed it. Route those now; only when nothing
    -- is left to route does the whole request wait for the class.
    if armorContext and armorContext.unknownClass
        and (not equipmentRequests or #equipmentRequests == 0) then
        return nil, nil, nil, nil, true
    end
    local armorWaitsForClass = armorContext and armorContext.unknownClass or nil
    if armorContext and next(armorContext.slots or {})
        and (not equipmentRequests or #equipmentRequests==0)
        and not (overrides and overrides.equipmentRequest) then return nil end
    if overrides and overrides.equipmentRequest then
        local request = overrides.equipmentRequest
        armorContext = {parentProfID=request.parentProfID, armor=request.armor,
            slots=request.slot and {[request.slot]=true} or {},
            weapons=request.subclasses and {[request.key]=true} or nil}
        equipmentRequests = {request}
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
                    local recipeInfo = GetRequestID(message, crafterInfo, pConfig, armorContext)
                    if recipeInfo then
                        return { crafter = crafterInfo.crafter, profID = pID,
                            equipmentRequests=equipmentRequests,
                            classPending=armorWaitsForClass }, nil, recipeInfo
                    end

                    if pID > maxProfID then
                        maxProfID = pID
                    end
                end
            end

            local profID = maxProfID
            if profID > 0 and not bestMatch then
                bestMatch = { crafter = crafterInfo.crafter, profID = profID,
                    equipmentRequests=equipmentRequests, classPending=armorWaitsForClass }
            end -- Keep looking for other crafters with keywords that match something specific.
        end
    end

    for _, crafterInfo in ipairs(config.prof_keywords) do
        local equipmentProfession = false
        for _, request in ipairs(equipmentRequests or {}) do
            local supports=HironCraftScan.ClassMatching.RequestSupportsProfession(request,crafterInfo.parentProfID)
            if supports and MonitorsEquipmentRequest(crafterInfo,request) then
                equipmentProfession = true; break
            end
        end
        if
            (equipmentProfession or (armorContext and (not equipmentRequests or #equipmentRequests==0)
                    and crafterInfo.parentProfID == armorContext.parentProfID)
                or (not armorContext and HasMatch(message, crafterInfo.keywords)))
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

local function HasDelimitedPhrase(message, phrases)
    for phrase in pairs(phrases or {}) do
        local start = 1
        while true do
            local first, last = message:find(phrase, start, true)
            if not first then break end
            local before = first > 1 and message:sub(first - 1, first - 1) or ''
            local after = last < #message and message:sub(last + 1, last + 1) or ''
            if (before == '' or not before:match('[%w]'))
                and (after == '' or not after:match('[%w]')) then
                return true
            end
            start = first + 1
        end
    end
    return false
end

local function IsGenericRequest(message)
    if IsCrafterAdvertisement(message) then return false end
    if type(message) ~= 'string' then return false end
    -- A linked item is already a specific request, even when none of the
    -- enabled characters knows its recipe. Do not turn a failed item match
    -- into the much broader "I can craft everything" placeholder.
    if message:find('|Hitem:', 1, true) then return false end
    local lower = message:lower()
    return not HasMatch(lower, config.exclusions)
        and HasMatch(lower, config.inclusions) ~= nil
        and HasDelimitedPhrase(lower, config.generic_requests)
end

HironCraftScan.Scanner.IsGenericRequest = IsGenericRequest

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
    local customers = HironCraftScan.DB and HironCraftScan.DB.customers
    if type(order) ~= 'table' or type(customers) ~= 'table' then
        return nil
    end
    local customer = customers[order.customerName]
    return type(customer) == 'table' and customer or nil
end

HironCraftScan.OrderToResponse = function(order)
    local customer = HironCraftScan.OrderToCustomerInfo(order)
    local responses = customer and customer.responses
    local response = type(responses) == 'table' and responses[order.responseID]
    return type(response) == 'table' and response or nil
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

local function HasGeneralRequest(customer, customerInfo)
    local response = customerInfo and customerInfo.responses
        and customerInfo.responses[GENERAL_REQUEST_ID]
    if type(response) ~= 'table' then return false end
    return HironCraftScan.DB.listed_orders[
        HironCraftScan.OrderToOrderID({ customerName = customer, responseID = GENERAL_REQUEST_ID })
    ] ~= nil
end

local function RemoveGeneralRequest(customer, customerInfo)
    if not HasGeneralRequest(customer, customerInfo) then return nil end
    local response = customerInfo.responses[GENERAL_REQUEST_ID]
    local order = { customerName = customer, responseID = GENERAL_REQUEST_ID }
    if HironCraftScanScannerMenu and HironCraftScanScannerMenu.ClearAlert then
        HironCraftScanScannerMenu:ClearAlert(order)
    end
    HironCraftScan.DB.listed_orders[HironCraftScan.OrderToOrderID(order)] = nil
    customerInfo.responses[GENERAL_REQUEST_ID] = nil

    local liveCustomer = HironCraftScan.LIVE and HironCraftScan.LIVE.customers
        and HironCraftScan.LIVE.customers[customer]
    if liveCustomer and liveCustomer.responses then
        liveCustomer.responses[GENERAL_REQUEST_ID] = nil
    end
    local active = HironCraftScan.State.activeOrder
    if active and active.customerName == customer and active.responseID == GENERAL_REQUEST_ID then
        HironCraftScan.State.activeOrder = nil
    end
    if HironCraftScan.QuickReplies and HironCraftScan.QuickReplies.DismissOrderGreeting then
        HironCraftScan.QuickReplies:DismissOrderGreeting(
            customer, GENERAL_REQUEST_ID, response.requestToken)
    end
    return response
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
    if HironCraftScan.BattleNet and HironCraftScan.BattleNet.IsCustomer(name) then
        return HironCraftScan.BattleNet.DisplayName(name)
    end
    if HironCraftScan.State.realmID then
        if forDisplay then
            return ShortenedRealmForDisplay(name)
        end
        return name -- On cross-realm servers, never remove realm names.
    end
    return name:match('^([^-]+)')
end

HironCraftScan.ColorizePlayerName = function(name, guid)
    if HironCraftScan.BattleNet and HironCraftScan.BattleNet.IsCustomer(name) then
        return '|cff00ffff' .. HironCraftScan.BattleNet.DisplayName(name) .. '|r'
    end
    name = HironCraftScan.NameAndRealmToName(name)
    local class = HironCraftScan.ClassMatching.ResolveClass(guid)
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
    if HironCraftScan.BattleNet and HironCraftScan.BattleNet.IsCustomer(customer) then
        return HironCraftScan.Utils.StampChatHistory(HironCraftScan.BattleNet.HistoryEntry(customer, message, event))
    end
    local chatType = ChatTypeFromEvent(event) or 'WHISPER'
    local color = ChatTypeInfo and ChatTypeInfo[chatType]
    -- Record the actual event, not a fuzzy match in a rotating ChatFrame buffer.
    -- Chat addons/window filters and repeated short replies can otherwise make
    -- an unrelated older line impersonate this message and be deduplicated.
    local prefix = chatType == 'WHISPER_INFORM' and '→ ' or (chatType == 'WHISPER' and '← ' or '')
    local stamp = date and (date('%H:%M:%S') .. ' ') or ''
    return HironCraftScan.Utils.StampChatHistory({
        message = stamp .. prefix .. customer .. ': ' .. message,
        rawMessage = message,
        args = color and { color.r, color.g, color.b } or nil,
        chatType = chatType,
    })
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

    -- A row made from a crafting order stores the base profession (755),
    -- whose info has no parent of its own: it is its own parent.
    local skillLineID = profInfo.parentProfessionID or profInfo.professionID
    if type(skillLineID) ~= 'number' then
        return nil
    end
    local spellSkillIndex = C_SpellBook.GetSkillLineIndexByID(skillLineID)
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

function HironCraftScan.Utils.GetReplyItemLink(itemID, originalLink)
    -- Reply with the cached base-item link, just like single-item requests.
    -- Customer recraft links can contain hundreds of bytes of modifiers/GUIDs.
    return (itemID and select(2, GetItemInfo(itemID))) or originalLink
end

local function BuildResponseContext(crafterFullName, profID, itemID, itemLink, recipeID)
    local profInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(profID)
    local crafter = HironCraftScan.NameAndRealmToName(crafterFullName)
    local altCraft = crafter ~= HironCraftScan.GetPlayerName()
    local professionName = profInfo and (profInfo.parentProfessionName or profInfo.professionName) or nil
    local professionLink = professionName
    if not altCraft then
        professionLink = GetProfessionLink(profInfo) or professionName
    end

    return {
        crafter = crafter,
        item = HironCraftScan.Utils.GetReplyItemLink(itemID, itemLink) or L(LID.GREETING_LINK_BACKUP),
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
    if response.equipmentLabel then context.item = response.equipmentLabel end
    context.crafter = response.crafterName or context.crafter
    context.profession = response.professionName or context.profession
    context.profession_link = context.profession_link or context.profession
    if HironCraftScan.ReagentAudit then
        context.reagent_issues = HironCraftScan.ReagentAudit.Issues(HironCraftScan.ReagentAudit.ForResponse(response))
    end
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
HironCraftScan.RebuildResponseMessage = function(order, force)
    local response = HironCraftScan.OrderToResponse(order)
    if not response or response.greeting_sent or not response.crafterFullName then
        return
    end
    local character = HironCraftScan.DB.characters and HironCraftScan.DB.characters[response.crafterFullName]
    if not character or not character.professions or not character.professions[response.professionID] then
        return -- Preserve a saved greeting if its crafter configuration was removed.
    end
    local crafter = HironCraftScan.NameAndRealmToName(response.crafterFullName)
    local currentAltCraft = crafter ~= HironCraftScan.GetPlayerName()
    if not force and currentAltCraft == response.alt_craft then
        return
    end
    local greeting, newAltCraft =
        BuildRawGreeting(response.crafterFullName, response.professionID, response.itemID, response.itemLink, response.recipeID)
    response.message = SplitResponse(greeting)
    response.alt_craft = newAltCraft
end

local function GenericAlertPreferences()
    local visual, sound = false, false
    local current = HironCraftScan.GetPlayerName(true)
    for _, crafterInfo in ipairs(config.prof_keywords) do
        local character = HironCraftScan.DB.characters[crafterInfo.crafter]
        local parent = character and character.parent_professions
            and character.parent_professions[crafterInfo.parentProfID]
        if parent and parent.scanning_enabled and not parent.character_disabled then
            local localAlertAllowed = not parent.local_alerts_only
                or current == crafterInfo.crafter
            if localAlertAllowed then
                visual = visual or parent.visual_alert_enabled == true
                sound = sound or parent.sound_alert_enabled == true
            end
        end
    end
    return visual, sound
end

local function HandleGeneralRequest(message, customer, customerInfo, overrides, chatEvent)
    local responses = saved(customerInfo, 'responses', {})
    local response = saved(responses, GENERAL_REQUEST_ID, {})
    local firstInteraction = not next(response)
    local requestChatEntry = overrides and overrides.chatEntry
        or MakeChatHistoryEntryDefault(customer, message, chatEvent)
    local chatHistory = saved(customerInfo, 'chat_history', {})
    if not (overrides and overrides.chatHistoryAlreadyStored) then
        requestChatEntry = HironCraftScan.Utils.AppendUniqueChatHistory(
            chatHistory, requestChatEntry)
    end
    if not firstInteraction and requestChatEntry.receivedAt and response.time
        and requestChatEntry.receivedAt < response.time then return nil end

    local publicRequest = chatEvent == 'CHAT_MSG_CHANNEL' or chatEvent == 'CHAT_MSG_SAY'
        or chatEvent == 'CHAT_MSG_PARTY' or chatEvent == 'CHAT_MSG_GUILD'
    local reoffer = publicRequest and HironCraftScan.RequestTracking.CanReoffer(
        response, requestChatEntry.receivedAt or time())
    local remoteRestart = HironCraftScanComm.applying_remote_state and overrides
        and type(overrides.requestToken) == 'string'
        and response.requestToken and response.requestToken ~= overrides.requestToken
    local restarting = reoffer or remoteRestart
        or (overrides and overrides.restartTerminalRequest == true)
    if response.greeting_sent and not restarting then return nil end

    local fresh = firstInteraction or restarting
    local requestToken = response.requestToken
    if fresh then
        requestToken = overrides and overrides.requestToken
            or NewRequestToken(customer, GENERAL_REQUEST_ID, requestChatEntry)
        response.previousGreeting = reoffer
            and { id = response.inquiryID or response.requestToken } or nil
        response.requestToken = requestToken
        response.conversationCharacter = nil
        response.conversationFaction = nil
        response.greetingGroup = nil
        response.battleNetCharacters = nil
        response.inquiryID = nil
        response.greetingSentAt = nil
        response.customer_answered = false
    end
    if requestChatEntry and requestToken then
        requestChatEntry.syncID = requestChatEntry.syncID
            or ('order:' .. tostring(requestToken))
    end
    HironCraftScan.RequestTracking.AssignInquiry(
        customerInfo, response, requestChatEntry, restarting)

    local customerStartedInteraction = overrides
        and overrides.customerStartedInteraction == true
    response.message = SplitResponse(GetGreeting('GREETING_GENERIC_REQUEST'))
    response.generic_request = true
    response.responseID = GENERAL_REQUEST_ID
    response.crafterName = L('All crafters')
    response.professionName = L('Any profession')
    response.time = fresh and (requestChatEntry.receivedAt or time())
        or response.time or time()
    if customerStartedInteraction and (fresh or not response.greeting_sent) then
        response.greeting_sent = false
    elseif overrides and overrides.battleNet then
        response.greeting_sent = (not restarting and response.greeting_sent)
            or overrides.greeted or false
    else
        response.greeting_sent = overrides and overrides.greeted
            or customerStartedInteraction
    end
    if customerStartedInteraction then response.customer_answered = true end

    if overrides and overrides.battleNet and HironCraftScan.BattleNet then
        HironCraftScan.BattleNet.RememberCharacters(customer, response)
    end
    if HironCraftScan.QuickReplies then
        HironCraftScan.QuickReplies:ApplyConversationOwners(
            customerInfo, overrides and overrides.conversationOwners)
        if customerStartedInteraction or (overrides and overrides.greeted) then
            HironCraftScan.QuickReplies:RememberConversationCharacter(response)
        end
        requestChatEntry.conversationOwners =
            HironCraftScan.QuickReplies:GetConversationOwners(customerInfo)
    end

    local order = { customerName = customer, responseID = GENERAL_REQUEST_ID }
    if fresh then
        HironCraftScan.DB.listed_orders[HironCraftScan.OrderToOrderID(order)] = order
        local visualAlert, soundAlert = GenericAlertPreferences()
        if visualAlert then
            HironCraftScan.State.activeOrder = order
            FlashClientIcon()
            if not customerStartedInteraction and not (overrides and overrides.suppressGreetingBanner) then
                HironCraftScanScannerMenu:TriggerAlert(
                    string.format('%s\n%s (%s)',
                        HironCraftScan.ColorizePlayerName(customer, customerInfo.guid),
                        L('General crafting request'), L('All crafters')),
                    order)
                if not HironCraftScanCraftingOrderPage:IsShown() then
                    HironCraftScanScannerMenu:TriggerPulseLock('scanned')
                end
            end
        end
        if soundAlert and not (overrides and overrides.suppressBatchAlert) then
            PlaySoundFile(HironCraftScan.Utils.GetSetting('ping_sound'), 'Master')
        end
        HironCraftScanCraftingOrderPage:ShowGeneric()
    end

    HironCraftScanComm:ShareCustomerOrder(
        message, customer, customerInfo.guid, requestChatEntry,
        response.requestToken, restarting)
    return response
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
    local crafterConfig=HironCraftScan.DB.characters[crafterInfo.crafter]
    local profConfig=crafterConfig and crafterConfig.professions[profID]
    local crafterParentProfID=profConfig and profConfig.parentProfID
    local recipeID = recipeInfo and recipeInfo.recipeID
    local equipmentRequest = overrides and overrides.equipmentRequest
    local responseID = equipmentRequest and ('equipment:' .. profID .. ':' .. equipmentRequest.key)
        or recipeID or profID

    local needsResultCallbackOnly = overrides and overrides.resultCallback

    if not needsResultCallbackOnly then
        RemoveGeneralRequest(customer, customerInfo)
    end

    -- Replace only a compatible pending slot/type, never another requested
    -- item. Retain the conversation itself and invalidate its old toast.
    -- Requests narrow down: "LF crafter" -> "LF tailor" -> "chest" -> the
    -- linked item. Each step replaces the broader row of the same profession
    -- and a broader request never pushes a narrower row aside.
    local newIsSpecific = equipmentRequest ~= nil or itemID ~= nil or recipeID ~= nil
    local function SameProfession(old)
        return old.professionID == profID
            or (old.parentProfID ~= nil and old.parentProfID == crafterParentProfID)
    end
    local function IsProfessionOnly(old, listedID)
        return type(listedID) == 'number' and old.responseID == listedID
            and old.professionID == listedID
            and not old.itemID and not old.recipeID and not old.equipmentRequest
    end
    if HironCraftScan.ClassMatching and not needsResultCallbackOnly then
        local remove = {}
        for orderID, order in pairs(HironCraftScan.DB.listed_orders) do
            if order.customerName == customer then
                local old = customerInfo.responses and customerInfo.responses[order.responseID]
                local fulfillment = HironCraftScan.OrderFulfillment
                local state = fulfillment and fulfillment.GetStatus and fulfillment:GetStatus(order)
                local terminal = state and (state.status == 'fulfilled' or state.status == 'rejected' or state.status == 'failed')
                if old and not terminal and order.responseID ~= responseID then
                    if not newIsSpecific and not (overrides and overrides.manualMatch)
                        and not IsProfessionOnly(old, order.responseID) and SameProfession(old)
                        and (old.itemID or old.recipeID or old.equipmentRequest) then
                        return nil -- "LF tailor" after "chest" is the same request
                    end
                    if newIsSpecific and IsProfessionOnly(old, order.responseID) and SameProfession(old) then
                        remove[#remove+1] = {orderID=orderID, order=order, response=old}
                    end
                end
                if old and not terminal then
                    if equipmentRequest and old.itemID
                        and HironCraftScan.ClassMatching.MatchesItem(equipmentRequest, old.itemID) then
                        return nil -- do not downgrade a known item to a slot
                    end
                    if itemID and old.equipmentRequest
                        and (not old.equipmentRequest.parentProfID
                            or old.equipmentRequest.parentProfID==crafterParentProfID)
                        and HironCraftScan.ClassMatching.MatchesItem(old.equipmentRequest, itemID) then
                        remove[#remove+1] = {orderID=orderID, order=order, response=old}
                    end
                end
            end
        end
        for _, old in ipairs(remove) do
            HironCraftScan.DB.listed_orders[old.orderID] = nil
            for id, value in pairs(customerInfo.responses) do
                if value == old.response then customerInfo.responses[id] = nil end
            end
            if HironCraftScan.QuickReplies and HironCraftScan.QuickReplies.DismissOrderGreeting then
                HironCraftScan.QuickReplies:DismissOrderGreeting(customer, old.order.responseID, old.response.requestToken)
            end
            if HironCraftScanScannerMenu.ClearAlert then HironCraftScanScannerMenu:ClearAlert(old.order) end
            local active = HironCraftScan.State.activeOrder
            if active and active.customerName == customer and active.responseID == old.order.responseID then
                HironCraftScan.State.activeOrder = nil
            end
            local live = HironCraftScan.LIVE and HironCraftScan.LIVE.customers[customer]
            if live and live.responses then live.responses[old.order.responseID] = nil end
        end
    end

    local responses = saved(customerInfo, 'responses', {})
    local response = saved(responses, responseID, {})
    local firstInteraction = not next(response)
    local restartingTerminalRequest = overrides
        and overrides.restartTerminalRequest == true
        and (not overrides.requestToken or overrides.requestToken ~= response.requestToken)
        or false
    local requestChatEntry = overrides and overrides.chatEntry or MakeChatHistoryEntryDefault(customer, message, chatEvent)
    local chat_history = saved(customerInfo, 'chat_history', {})
    if not needsResultCallbackOnly then
        local _, inserted = HironCraftScan.Utils.AppendUniqueChatHistory(chat_history, requestChatEntry)
        if inserted and response.greeting_sent and chatEvent ~= 'CHAT_MSG_WHISPER'
            and chatEvent ~= 'CHAT_MSG_BN_WHISPER' and HironCraftScanComm.ShareCustomerChat then
            HironCraftScanComm:ShareCustomerChat(customer, customerInfo.guid, requestChatEntry, false)
        end
    end
    -- A delayed proxy/cache callback is history, not a fresh request.
    if not firstInteraction and requestChatEntry.receivedAt and response.time
        and requestChatEntry.receivedAt < response.time then return end
    local publicRequest = chatEvent == 'CHAT_MSG_CHANNEL' or chatEvent == 'CHAT_MSG_SAY'
        or chatEvent == 'CHAT_MSG_PARTY' or chatEvent == 'CHAT_MSG_GUILD'
    local statusEntry = HironCraftScan.OrderFulfillment and HironCraftScan.OrderFulfillment:GetStatus({customerName=customer, responseID=responseID})
    local reoffer = publicRequest and HironCraftScan.RequestTracking.CanReoffer(
        response, requestChatEntry.receivedAt or time(), statusEntry and statusEntry.status)
    restartingTerminalRequest = restartingTerminalRequest or reoffer or (overrides and overrides.manualMatch == true)
    if HironCraftScanComm.applying_remote_state and overrides and type(overrides.requestToken) == 'string'
        and response.requestToken and response.requestToken ~= overrides.requestToken then
        restartingTerminalRequest = true
    end
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
    profConfig = profConfig or HironCraftScan.DB.characters[crafterInfo.crafter].professions[profID]

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
    local requestToken = response.requestToken
    if firstInteraction or restartingTerminalRequest then
        requestToken = overrides and overrides.requestToken
            or NewRequestToken(customer, responseID, requestChatEntry)
    end
    if requestChatEntry and requestToken then
        requestChatEntry.syncID = requestChatEntry.syncID
            or ('order:' .. tostring(requestToken))
    end
    if not (overrides and overrides.chatHistoryAlreadyStored) then
        requestChatEntry = HironCraftScan.Utils.AppendUniqueChatHistory(
            chat_history,
            requestChatEntry
        )
    end
    if firstInteraction or restartingTerminalRequest then
        -- A late answer to our first greeting can arrive while the replacement
        -- row is merely proposed. Keep that conversation eligible until another
        -- greeting is actually sent; do not mark this new row as greeted yet.
        response.previousGreeting = reoffer and {id=response.inquiryID or response.requestToken} or nil
        response.requestToken = requestToken
        response.conversationCharacter = nil
        response.conversationFaction = nil
        response.greetingGroup = nil
        response.battleNetCharacters = nil
        response.inquiryID = nil
        response.greetingSentAt = nil
        response.customer_answered = false
    end
    HironCraftScan.RequestTracking.AssignInquiry(customerInfo, response, requestChatEntry, restartingTerminalRequest)

    -- Save the request at higher granularities as well so that we don't
    -- respond to someone a second time for something more generic. E.g. we
    -- responded to 'lf bs <item>', they didn't take the offer, then they
    -- requested 'lf bs'. We don't want to message that person again after
    -- they rejected us offering the exact item they wanted.
    if not equipmentRequest and not responses[profID] then
        responses[profID] = response
        local children = saved(response, 'less_granular', {})
        table.insert(children, profID)
    end

    local now = time()

    local customerStartedInteraction = overrides and overrides.customerStartedInteraction
    local offerIncomingGreeting = customerStartedInteraction
        and (firstInteraction or restartingTerminalRequest or not response.greeting_sent)

    response.crafterName = crafter
    response.crafterFullName = crafterInfo.crafter
    response.alt_craft = alt_craft
    response.professionID = profID
    response.parentProfID = profInfo.parentProfessionID
    response.professionName = profInfo.parentProfessionName
    response.itemID = itemID
    response.itemLink = itemLink
    response.recipeID = recipeID
    response.equipmentRequest = equipmentRequest
    response.equipmentLabel = equipmentRequest and equipmentRequest.label
    response.time = (firstInteraction or restartingTerminalRequest) and (requestChatEntry.receivedAt or now) or response.time or now
    response.responseID = responseID
    response.destination_only_greeting = customerStartedInteraction == true or nil
    if offerIncomingGreeting then
        -- An incoming crafting request establishes contact, but it is not our
        -- answer. Leave the generated greeting pending so Quick Replies can
        -- offer an explicit click action for this exact new request.
        response.greeting_sent = false
    elseif overrides and overrides.battleNet then
        -- Receiving a request is not the same as sending our proposed reply.
        response.greeting_sent = (not restartingTerminalRequest and response.greeting_sent) or overrides.greeted or false
    else
        response.greeting_sent = overrides and overrides.greeted or customerStartedInteraction
    end
    -- Battle.net routing metadata is independent from the greeting state. A
    -- newly offered Quick Reply still needs the verified game character so its
    -- click can reach the correct Battle.net conversation.
    if overrides and overrides.battleNet then
        HironCraftScan.BattleNet.RememberCharacters(customer, response)
    end
    if HironCraftScan.QuickReplies then
        -- A proxied request must retain the originating conversation character.
        HironCraftScan.QuickReplies:ApplyConversationOwners(customerInfo,
            overrides and overrides.conversationOwners)
        if customerStartedInteraction or (overrides and overrides.greeted) then
            HironCraftScan.QuickReplies:RememberConversationCharacter(response)
        end
    end
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

    if firstInteraction or restartingTerminalRequest then
        local order = {
            customerName = customer,
            responseID = responseID,
        }
        HironCraftScan.DB.listed_orders[HironCraftScan.OrderToOrderID(order)] = order

        local ppConfig = ParentProfessionConfig(crafterInfo)

        local isAlertFiltered = (
            ppConfig.local_alerts_only and HironCraftScan.GetPlayerName(true) ~= crafterInfo.crafter
        )
        if ppConfig.visual_alert_enabled and not isAlertFiltered
            and not (overrides and overrides.suppressBatchAlert) then
            HironCraftScan.State.activeOrder = order

            FlashClientIcon()

            if not customerStartedInteraction and not (overrides and overrides.suppressGreetingBanner) then
                HironCraftScanScannerMenu:TriggerAlert(
                    string.format(
                        '%s\n%s (%s)',
                        HironCraftScan.ColorizePlayerName(customer, customerInfo.guid),
                        itemLink or response.equipmentLabel
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

        if ppConfig.sound_alert_enabled and not isAlertFiltered
            and not (overrides and overrides.suppressBatchAlert) then
            PlaySoundFile(HironCraftScan.Utils.GetSetting('ping_sound'), 'Master')
        end

        if not (overrides and overrides.deferItemBatch) then
            HironCraftScanCraftingOrderPage:ShowGeneric()
        end
    end

    if requestChatEntry and HironCraftScan.QuickReplies then
        requestChatEntry.conversationOwners = HironCraftScan.QuickReplies:GetConversationOwners(customerInfo)
    end
    if not (overrides and overrides.deferItemBatch) then
        HironCraftScanComm:ShareCustomerOrder(
            message,
            customer,
            customerInfo.guid,
            requestChatEntry or chat_history[#chat_history],
            response.requestToken,
            restartingTerminalRequest
        )
    end
    return response
end

local function HandleItemBatch(message, customer, matches, overrides, event)
    local responses, tokens = {}, {}
    for _, match in ipairs(matches) do
        local options = {}
        for key, value in pairs(overrides or {}) do options[key] = value end
        options.deferItemBatch = true
        options.suppressBatchAlert = #responses > 0
        options.chatHistoryAlreadyStored = options.chatHistoryAlreadyStored or #responses > 0
        local id = match.recipeInfo and match.recipeInfo.recipeID or match.crafterInfo.profID
        if overrides and type(overrides.requestTokens) == 'table' then
            options.requestToken = overrides.requestTokens[id] or overrides.requestTokens[tostring(id)]
        end
        local itemLink = match.itemLink
            or (match.itemID and HironCraftScan.Utils.GetReplyItemLink(match.itemID, nil))
        local item = itemLink and { GetItemLink = function() return itemLink end } or nil
        local response = handleResponse(message, customer, match.crafterInfo,
            match.itemID, match.recipeInfo, item, options, event)
        if response then
            responses[#responses + 1] = response
            tokens[id] = response.requestToken
        end
    end
    if #responses == 0 then return end
    HironCraftScan.GroupOrderGreetings(responses)
    HironCraftScanCraftingOrderPage:ShowGeneric()

    local customerInfo = HironCraftScan.DB.customers[customer]
    local history = customerInfo.chat_history
    local entry = overrides and overrides.chatEntry or (history and history[#history])
    if entry and HironCraftScan.QuickReplies then
        entry.conversationOwners = HironCraftScan.QuickReplies:GetConversationOwners(customerInfo)
    end
    HironCraftScanComm:ShareCustomerOrder(message, customer, customerInfo.guid, entry,
        responses[1].requestToken, overrides and overrides.restartTerminalRequest, tokens)
    return responses
end

local function OfferDeferredQuickReply(customer, message, customerInfo, overrides, matchedResponses)
    if not overrides
        or not overrides.deferQuickReplyUntilScan
        or overrides.quickReplyOffered
        or not HironCraftScan.QuickReplies
        or type(customerInfo) ~= 'table'
    then
        return
    end
    overrides.quickReplyOffered = true

    local responses = {}
    if type(matchedResponses) == 'table' and matchedResponses.responseID then
        responses[1] = matchedResponses
    elseif type(matchedResponses) == 'table' then
        for _, response in ipairs(matchedResponses) do
            if type(response) == 'table' and response.responseID then
                responses[#responses + 1] = response
            end
        end
    end

    if #responses > 0 then
        if HironCraftScan.QuickReplies.ShowOrderGreeting then
            HironCraftScan.QuickReplies:ShowOrderGreeting(customer, message, customerInfo, responses)
        end
    elseif HironCraftScan.QuickReplies.OnWhisper then
        -- Ordinary follow-up questions that are not new crafting requests keep
        -- using the configured keyword classifier.
        HironCraftScan.QuickReplies:OnWhisper(customer, message, customerInfo)
    end
end

local function BaseCustomerName(name)
    if type(name) ~= 'string' then
        return nil
    end
    return (name:match('^([^-]+)') or name):lower()
end

local function ResolveExistingCustomer(customer, customerGuid)
    local customers = HironCraftScan.DB.customers or {}
    if HironCraftScan.BattleNet and HironCraftScan.BattleNet.IsCustomer(customer) then
        return customer, customers[customer]
    end
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
        if not (HironCraftScan.BattleNet and HironCraftScan.BattleNet.IsCustomer(key))
            and BaseCustomerName(key) == wanted then
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
    local _, inserted = HironCraftScan.Utils.AppendUniqueChatHistory(
        chatHistory,
        HironCraftScan.Utils.DeepCopy(entry)
    )
    if HironCraftScan.QuickReplies then
        HironCraftScan.QuickReplies:ApplyConversationOwners(customerInfo, entry.conversationOwners)
    end
    if not inserted then return false end
    if entry.greetingContext then HironCraftScan.RequestTracking.ApplyContext(customerInfo, entry.greetingContext, false) end
    if incoming then HironCraftScan.RequestTracking.MarkReply(customerInfo, entry) end
    if HironCraftScanCraftingOrderPage and HironCraftScanCraftingOrderPage.ShowGeneric then
        HironCraftScanCraftingOrderPage:ShowGeneric()
    end
    return true
end

local function RunRequestCallback(options, callback)
    -- Item/class data may arrive after the linked-packet handler has returned.
    -- Keep that work remote so it cannot echo packets or claim a local owner.
    local previous = HironCraftScanComm.applying_remote_state
    if options.remoteRequest then HironCraftScanComm.applying_remote_state = true end
    local ok, err = pcall(callback)
    HironCraftScanComm.applying_remote_state = previous
    if not ok then error(err, 0) end
end

-- A request whose armor slot waits for the customer's class. The quick
-- retries right after the message cover a class the client is still loading;
-- this covers a class that only turns up later - the customer leaves the
-- instance, whispers again from their character, or the linked account
-- shares it. The row is added then, not guessed now. The wait is saved, so a
-- relog to another character in between does not lose it.
local CLASS_WAIT_SECONDS = 10 * 60
local CLASS_WAIT_POLL = 2
local classWaitScheduled = false

local function WaitingForClass()
    return saved(HironCraftScan.DB.settings, 'class_waits', {})
end

-- Only plain data survives into SavedVariables.
local function PlainCopy(value, depth)
    local kind = type(value)
    if kind == 'string' or kind == 'number' or kind == 'boolean' then return value end
    if kind ~= 'table' or (depth or 0) > 4 then return nil end
    local copy = {}
    for key, item in pairs(value) do
        if type(key) == 'string' or type(key) == 'number' then
            copy[key] = PlainCopy(item, (depth or 0) + 1)
        end
    end
    return copy
end

local function PollWaitingForClass()
    classWaitScheduled = false
    local matching = HironCraftScan.ClassMatching
    local waiting = WaitingForClass()
    local remaining = false
    for key, entry in pairs(waiting) do
        local stored = type(entry) == 'table' and HironCraftScan.DB.customers
            and HironCraftScan.DB.customers[entry.customer]
        local guid = type(entry) == 'table' and (entry.guid or (stored and stored.guid))
        if type(entry) ~= 'table' or type(entry.message) ~= 'string' or type(entry.customer) ~= 'string'
            or time() > (tonumber(entry.expires) or 0) or (entry.hadRow and not stored)
            or (HironCraftScan.DB.settings.ignored and HironCraftScan.DB.settings.ignored[entry.customer]) then
            -- Too late, or the crafter removed or ignored the customer meanwhile.
            waiting[key] = nil
        elseif matching and guid and matching.ResolveClass(guid) then
            waiting[key] = nil
            local options = type(entry.options) == 'table' and entry.options or {}
            RunRequestCallback(options, function()
                HironCraftScan.OnMessage(entry.event, entry.message, entry.customer, guid, options)
            end)
        else
            remaining = true
        end
    end
    if remaining and C_Timer and C_Timer.After then
        classWaitScheduled = true
        C_Timer.After(CLASS_WAIT_POLL, PollWaitingForClass)
    end
end

local function ScheduleClassWait()
    if classWaitScheduled or not (C_Timer and C_Timer.After) then return end
    classWaitScheduled = true
    C_Timer.After(CLASS_WAIT_POLL, PollWaitingForClass)
end

local function WaitForClass(event, message, customer, guid, options)
    if not (C_Timer and C_Timer.After) then return false end
    local stored = HironCraftScan.DB.customers and HironCraftScan.DB.customers[customer]
    WaitingForClass()[customer .. '\n' .. message] = {
        event=event, message=message, customer=customer, guid=guid, options=PlainCopy(options),
        hadRow=stored ~= nil, expires=time() + CLASS_WAIT_SECONDS,
    }
    ScheduleClassWait()
    return true
end

function HironCraftScan.OnMessage(event, message, customer, customerGuid, overrides)
    if not message or not customer then
        return false
    end
    local isBattleNet = HironCraftScan.BattleNet and HironCraftScan.BattleNet.IsCustomer(customer)
    if isBattleNet and (HironCraftScanComm.applying_remote_state
        or not (overrides and overrides.battleNet)) then return false end

    local existingCustomer, customerInfo = ResolveExistingCustomer(customer, customerGuid)
    if existingCustomer then
        customer = existingCustomer
    end

    if isBattleNet and customerInfo then customerInfo.guid = customerGuid end

    local ignored = HironCraftScan.DB.settings.ignored and HironCraftScan.DB.settings.ignored[customer]
    if ignored then
        return false
    end
    overrides = overrides or {}
    overrides.remoteRequest = overrides.remoteRequest == true or HironCraftScanComm.applying_remote_state == true
    overrides.chatEntry = HironCraftScan.Utils.StampChatHistory(overrides.chatEntry
        or MakeChatHistoryEntryDefault(customer, message, event))
    if HasGeneralRequest(customer, customerInfo) then
        -- Once we have asked what the customer needs, their clarification is
        -- allowed to be just "BS", "wrist" or an item link without another LF.
        -- Global and profession exclusions are still checked normally.
        overrides.genericFollowup = true
    elseif (event == 'CHAT_MSG_WHISPER' or event == 'CHAT_MSG_BN_WHISPER')
        and HironCraftScan.QuickReplies and HironCraftScan.QuickReplies.HasUnfinishedOrders
        and HironCraftScan.QuickReplies:HasUnfinishedOrders(customer)
    then
        -- The same holds in a conversation that is already about an order:
        -- "dagger for Favu, wrist for ? and ring for ?" asks for two more
        -- items without saying LF again. Only while something of theirs is
        -- still open - after the craft, "the ring looks great" is not a new
        -- order.
        overrides.genericFollowup = true
    end
    -- A line the crafter linked by hand is their own decision, not a customer
    -- greeting, so it raises the normal request banner. Only a real incoming
    -- whisper is answered with a greeting card.
    local incomingWhisper = event == 'CHAT_MSG_WHISPER' or event == 'CHAT_MSG_BN_WHISPER'
    if incomingWhisper and not overrides.remoteRequest then
        overrides.deferQuickReplyUntilScan = true
    end

    local crafterInfo, itemID, recipeInfo, itemMatches, classPending

    if event == 'CHAT_MSG_WHISPER_INFORM' or event == 'CHAT_MSG_BN_WHISPER_INFORM' then
        if customerInfo then
            local chat_history = saved(customerInfo, 'chat_history', {})
            local entry = overrides and overrides.chatEntry or MakeChatHistoryEntryDefault(customer, message, event)
            if HironCraftScan.QuickReplies then
                entry.conversationOwners = HironCraftScan.QuickReplies:RememberCustomerConversation(customerInfo)
            end
            entry.greetingContext = HironCraftScan.RequestTracking.GetReplyContext(customerInfo)
            HironCraftScan.Utils.AppendUniqueChatHistory(chat_history, entry)
            if HironCraftScanComm and HironCraftScanComm.ShareCustomerChat then
                HironCraftScanComm:ShareCustomerChat(customer, customerInfo.guid, entry, false)
            end
        end
        return false
    end

    if not overrides.forceCrafterInfo and not overrides.itemInfo
        and IsCrafterAdvertisement(message) then
        -- Retain existing local history, but do not create/reopen a request,
        -- switch the active order, or classify this sales pitch as a question.
        if incomingWhisper and customerInfo then
            HironCraftScan.Utils.AppendUniqueChatHistory(
                saved(customerInfo, 'chat_history', {}), overrides.chatEntry)
            HironCraftScanCraftingOrderPage:ShowGeneric()
        end
        return false
    end

    if (event == 'CHAT_MSG_WHISPER' or event == 'CHAT_MSG_BN_WHISPER') and not overrides.classRetry then
        if customerInfo then
            local chat_history = saved(customerInfo, 'chat_history', {})
            local entry = overrides and overrides.chatEntry or MakeChatHistoryEntryDefault(customer, message, event)
            if HironCraftScan.QuickReplies then
                entry.conversationOwners = HironCraftScan.QuickReplies:RememberCustomerConversation(customerInfo)
            end
            HironCraftScan.Utils.AppendUniqueChatHistory(chat_history, entry)
            HironCraftScan.RequestTracking.MarkReply(customerInfo, entry)
            if HironCraftScanComm and HironCraftScanComm.ShareCustomerChat then
                HironCraftScanComm:ShareCustomerChat(customer, customerGuid or customerInfo.guid, entry, true)
            end

            HironCraftScanCraftingOrderPage:ShowGeneric()
            FlashClientIcon()

            -- Follow-up questions stay in the current conversation. Only a
            -- message that independently matches the craft scanner continues
            -- below, where a terminal row can be reopened as a new request.
            overrides = overrides or {}
            crafterInfo, itemID, recipeInfo, itemMatches, classPending = GetCrafterForMessage(
                customer,
                message,
                overrides,
                customerGuid
            )
            if not crafterInfo and not classPending and not overrides.forceGeneralRequest
                and not IsGenericRequest(message) then
                OfferDeferredQuickReply(customer, message, customerInfo, overrides)
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

    -- A general greeting the crafter started themselves answers for every
    -- profession on purpose. Do not let a profession named in the line turn it
    -- into one specific request.
    if overrides.forceGeneralRequest then
        crafterInfo, itemID, recipeInfo, itemMatches, classPending = nil, nil, nil, nil, nil
    elseif not crafterInfo then
        crafterInfo, itemID, recipeInfo, itemMatches, classPending = GetCrafterForMessage(customer, message, overrides, customerGuid)
    end
    local function RetryOnceClassIsKnown()
        if (overrides.classRetry or 0) > 3 or not (C_Timer and C_Timer.After) then return false end
        local options = {}
        for key, value in pairs(overrides) do options[key] = value end
        options.classRetry = (overrides.classRetry or 0) + 1
        if options.classRetry > 3 then
            -- The quick retries are spent: keep waiting for the class in the
            -- background and add the slot once it is known.
            return WaitForClass(event, message, customer, customerGuid, options)
        end
        C_Timer.After(options.classRetry == 1 and 0.1 or 0.5, function()
            -- Only re-evaluate the request; never send chat from a timer.
            if time() - options.chatEntry.receivedAt > 5 then return end
            local guid = customerGuid
            if not guid and type(options.lineID) == 'number' and C_ChatInfo and C_ChatInfo.GetChatLineSenderGUID then
                local ok, value = pcall(C_ChatInfo.GetChatLineSenderGUID, options.lineID)
                if ok and not (issecretvalue and issecretvalue(value)) then guid = value end
            end
            RunRequestCallback(options, function()
                HironCraftScan.OnMessage(event, message, customer, guid, options)
            end)
        end)
        return true
    end

    if not crafterInfo then
        if classPending and RetryOnceClassIsKnown() then
            -- Scheduled above.
        elseif overrides.forceGeneralRequest or IsGenericRequest(message) then
            customerInfo = customerInfo or saved(HironCraftScan.DB.customers, customer, {})
            customerInfo.guid = customerGuid or customerInfo.guid
            local response = HandleGeneralRequest(
                message, customer, customerInfo, overrides, event)
            OfferDeferredQuickReply(
                customer, message, customerInfo, overrides, response)
        else
            OfferDeferredQuickReply(customer, message, customerInfo, overrides)
        end
        return false
    end

    local customerInfo = saved(HironCraftScan.DB.customers, customer, {})
    customerInfo.guid = customerGuid or customerInfo.guid

    if crafterInfo.equipmentRequests and #crafterInfo.equipmentRequests > 0 then
        local responses, tokens = {}, {}
        for _, request in ipairs(crafterInfo.equipmentRequests) do
            local options = {}
            for key, value in pairs(overrides) do options[key] = value end
            options.equipmentRequest = request
            options.deferItemBatch = true
            options.suppressBatchAlert = #responses > 0
            local crafter = GetCrafterForMessage(customer, message, options, customerGuid)
            if crafter then
                local id = 'equipment:' .. crafter.profID .. ':' .. request.key
                if type(overrides.requestTokens) == 'table' then options.requestToken = overrides.requestTokens[id] end
                local response = handleResponse(message, customer, crafter, nil, nil, nil, options, event)
                if response then
                    responses[#responses+1] = response
                    tokens[response.responseID] = response.requestToken
                end
            end
        end
        if #responses > 0 then
            HironCraftScan.GroupOrderGreetings(responses)
            HironCraftScanCraftingOrderPage:ShowGeneric()
            HironCraftScanComm:ShareCustomerOrder(message, customer, customerInfo.guid, overrides.chatEntry,
                responses[1].requestToken, overrides.restartTerminalRequest, tokens)
        end
        OfferDeferredQuickReply(customer, message, customerInfo, overrides, responses)
        -- The ring and the dagger are routed; the wrist still needs to know
        -- what armor the customer wears. Look again once the class arrives.
        if crafterInfo.classPending then RetryOnceClassIsKnown() end
        return false
    end

    if itemMatches and #itemMatches > 1 then
        -- Load every base-item link before creating/sending the group. This is
        -- the same cache boundary as the single-item path below.
        local function Continue()
            if HironCraftScan.DB.customers[customer] then
                RunRequestCallback(overrides, function()
                    local responses = HandleItemBatch(message, customer, itemMatches, overrides, event)
                    OfferDeferredQuickReply(customer, message,
                        HironCraftScan.DB.customers[customer], overrides, responses)
                end)
            end
        end
        local pending = 0
        for _, match in ipairs(itemMatches) do
            if match.itemID then pending = pending + 1 end
        end
        if pending == 0 then
            customerInfo = customerInfo or saved(HironCraftScan.DB.customers, customer, {})
            Continue()
            return false
        end
        for _, match in ipairs(itemMatches) do
            if match.itemID then
                Item:CreateFromItemID(match.itemID):ContinueOnItemLoad(function()
                    pending = pending - 1
                    if pending == 0 then Continue() end
                end)
            end
        end
        return false
    end

    if recipeInfo and overrides and type(overrides.requestTokens) == 'table' then
        overrides.requestToken = overrides.requestTokens[recipeInfo.recipeID]
            or overrides.requestTokens[tostring(recipeInfo.recipeID)]
    end

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
                RunRequestCallback(overrides, function()
                    if HironCraftScan.DB.customers[customer] then
                        local response = handleResponse(
                            message, customer, crafterInfo, itemID, recipeInfo, item, overrides, event)
                        OfferDeferredQuickReply(customer, message,
                            HironCraftScan.DB.customers[customer], overrides, response)
                    end
                end)
            end)
            return false
        end
    end

    local response = handleResponse(message, customer, crafterInfo, itemID, recipeInfo, nil, overrides, event)
    OfferDeferredQuickReply(customer, message,
        HironCraftScan.DB.customers[customer], overrides, response)
    if overrides.manualMatch then return response end

    return false
end

local function OnMessage_(self, event, ...)
    if event == 'CHAT_MSG_BN_WHISPER' or event == 'CHAT_MSG_BN_WHISPER_INFORM' then
        if HironCraftScan.BattleNet then HironCraftScan.BattleNet.HandleEvent(event, ...) end
        return
    end
    local message, customer = ...

    if issecretvalue(message) then return end

    local customerGuid = select(12, ...)
    HironCraftScan.OnMessage(event, message, customer, customerGuid, {lineID=select(11, ...)})
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
            frame:RegisterEvent('CHAT_MSG_BN_WHISPER')
            frame:RegisterEvent('CHAT_MSG_BN_WHISPER_INFORM')
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
            frame:UnregisterEvent('CHAT_MSG_BN_WHISPER')
            frame:UnregisterEvent('CHAT_MSG_BN_WHISPER_INFORM')
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
    -- A wait started on the previous character goes on here.
    if next(WaitingForClass()) then ScheduleClassWait() end
end)
