local HironCraftScan = select(2, ...)

local LID = HironCraftScan.CONST.TEXT
local function L(id)
    return HironCraftScan.LOCAL:GetText(id)
end

HironCraftScan.Frames = {}
HironCraftScan.Utils = {}

function HironCraftScan.Utils.Contains(array, value)
    for _, v in ipairs(array) do
        if v == value then
            return true
        end
    end
    return false
end

local function DeepCopy_(original)
    local copy
    if type(original) == 'table' then
        copy = {}
        for key, value in next, original, nil do
            copy[DeepCopy_(key)] = DeepCopy_(value)
        end
        setmetatable(copy, DeepCopy_(getmetatable(original)))
    else -- number, string, boolean, etc.
        copy = original
    end
    return copy
end

function HironCraftScan.Utils.DeepCopy(original)
    return DeepCopy_(original)
end

function HironCraftScan.Utils.ColorizeText(text, hex)
    if hex then
        return CreateColor(hex):WrapTextInColorCode(text)
    end
    return text
end

function HironCraftScan.Utils.IsCurrentExpansion(profID)
    -- ExpansionUpdateTag
    return profID > 2905 -- Lowest Midnight profID is 2906, alchemy
end

-- Expecting AARRGGBB
function HironCraftScan.Utils.ColorFromHex(hex)
    if not hex then
        return CreateColor(1, 1, 1)
    end

    return CreateColor(
        tonumber(hex:sub(3, 4), 16) / 255,
        tonumber(hex:sub(5, 6), 16) / 255,
        tonumber(hex:sub(7, 8), 16) / 255,
        1
    )
end

function HironCraftScan.Utils.ProfessionColor(profID)
    return HironCraftScan.Utils.ColorFromHex(HironCraftScan.CONST.PROFESSION_COLORS[profID])
end

function HironCraftScan.Utils.ColorizeProfessionName(profID, professionName)
    local hex = HironCraftScan.CONST.PROFESSION_COLORS[profID]
    return HironCraftScan.Utils.ColorFromHex(hex):WrapTextInColorCode(professionName)
end

function HironCraftScan.Utils.ProfessionNameByID(professionID)
    local profInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(professionID)
    return profInfo.professionName
end

function HironCraftScan.Utils.ColorizedProfessionNameByID(professionID)
    return HironCraftScan.Utils.ColorizeProfessionName(
        professionID,
        HironCraftScan.Utils.ProfessionNameByID(professionID)
    )
end

function HironCraftScan.Utils.SendResponses(responses, customer)
    RobotsDotTxtAPI.NotifyCustomer(customer, 'HironCraftScan')
    for _, response in pairs(responses) do
        SendChatMessage(response, 'WHISPER', select(2, GetDefaultLanguage()), customer)
    end
end

function HironCraftScan.Frames.createLabel(
    labelText,
    parent,
    anchorParent,
    anchorA,
    anchorB,
    offsetX,
    offsetY,
    updateDisplay
)
    local label = parent:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    label:SetText(labelText)
    label:SetPoint(anchorA, anchorParent, anchorB, offsetX, offsetY)
    label:SetTextColor(1, 1, 1)
    label:SetFontObject('GameFontHighlight')

    if updateDisplay then
        label.updateDisplay = function()
            label:SetText(updateDisplay() or '<unset>')
        end
    end
    return label
end

function HironCraftScan.Utils.SetupParentChildScrolling(scrollFrame, parentScrollFrame)
    -- When at the limits of the text scroll frame, delegate to the parent scroll frame.
    local function IsScrollLimit(delta)
        if delta < 0 then
            local maxScroll = scrollFrame:GetVerticalScrollRange()
            local currentScroll = scrollFrame:GetVerticalScroll()
            return (maxScroll - currentScroll) <= 0.001
        else
            return scrollFrame:GetVerticalScroll() == 0
        end
    end

    local scrollParent = parentScrollFrame:GetScript('OnMouseWheel')
    local scrollText = scrollFrame:GetScript('OnMouseWheel')
    scrollFrame:SetScript('OnMouseWheel', function(_, delta)
        if IsScrollLimit(delta) then
            scrollParent(parentScrollFrame, delta)
        else
            scrollText(scrollFrame, delta)
        end
    end)
end

function HironCraftScan.Frames.createTextInput(
    name,
    parent,
    sizeX,
    sizeY,
    labelText,
    initialValue,
    template,
    onTextChangedCallback,
    updateDisplay,
    parentScrollFrame
)
    local textFrame = CreateFrame('Frame', nil, parent)
    textFrame:SetSize(sizeX, sizeY + 22)

    local scrollFrame = CreateFrame('ScrollFrame', nil, textFrame, template)
    scrollFrame:SetPoint('TOPLEFT', textFrame, 'TOPLEFT', 0, -17)
    scrollFrame:SetSize(sizeX, sizeY)
    scrollFrame.EditBox.Instructions:SetWidth(sizeX)

    local textInput = scrollFrame.EditBox
    textInput:SetPoint('TOPLEFT', scrollFrame, 'TOPLEFT', 0, 0)
    textInput:SetSize(sizeX - 20, sizeY)
    textInput:SetAutoFocus(false) -- dont automatically focus
    textInput:SetFontObject('ChatFontNormal')
    textInput:SetText(initialValue or updateDisplay())
    textInput:SetMultiLine(true)
    textInput:SetScript('OnEscapePressed', function()
        textInput:ClearFocus()
    end)
    if onTextChangedCallback then
        textInput:SetScript('OnEditFocusLost', onTextChangedCallback)
    end

    if parentScrollFrame then
        HironCraftScan.Utils.SetupParentChildScrolling(scrollFrame, parentScrollFrame)
    end

    HironCraftScan.Frames.createLabel(labelText .. ':', textFrame, textFrame, 'TOPLEFT', 'TOPLEFT', 0, 0)

    if updateDisplay then
        textFrame.updateDisplay = function()
            textInput:SetText(updateDisplay() or '')
        end
    end
    return textFrame
end

local diagPrintFrame = nil
local diagPrint = nil
local diagText = ''

local function DisplayDiagText()
    if not diagPrint then
        diagPrintFrame = CreateFrame('Frame', 'Section', UIParent, 'HironCraftScan_DebugFrame')
        diagPrint = HironCraftScan.Frames.createTextInput(
            'Frame',
            diagPrintFrame,
            400,
            800,
            'https://github.com/stevin05/HironCraftScan',
            nil,
            'HironCraftScan_Debug',
            nil,
            function()
                return diagText
            end
        )
        diagPrintFrame:SetPoint('TOPRIGHT', UIParent, 'TOPRIGHT', -250, -115)
        diagPrintFrame:SetTitle('HironCraftScan Debug Log')
        diagPrint:SetPoint('TOPLEFT', diagPrintFrame, 'TOPLEFT', 15, -25)
    else
        diagPrintFrame:Show()
        diagPrint.updateDisplay()
    end
end

function HironCraftScan.Utils.printTable(label, tbl, indent)
    -- Should go through and mass replace at some point. We used to print JSON
    -- to a debug frame, but now support DevTool instead.
    HironCraftScan.Debug.Print(tbl, label)
end

function HironCraftScan.Utils.DumpCopyableText(value)
    diagText = value
    DisplayDiagText()
end

function HironCraftScan.Frames.CreateVerticalLayoutOrganizer(anchor, xPadding, yPadding)
    local OrganizerMixin = {
        entries = {},
    }

    xPadding = xPadding or 0
    yPadding = yPadding or 0

    function OrganizerMixin:Empty()
        return not next(self.entries)
    end

    function OrganizerMixin:Add(frame, xPadding, yPadding, child)
        table.insert(self.entries, {
            frame = frame,
            child = child,
            xPadding = xPadding or 0,
            yPadding = yPadding or 0,
        })
    end

    function OrganizerMixin:Resize(frame)
        local height = frame:GetTop() - self.entries[#self.entries].frame:GetBottom()
        if self.entries[#self.entries].frame.needsExtraYPadding then
            height = height + self.entries[#self.entries].frame.needsExtraYPadding
        end
        if height < 200 then
            height = 200
        end
        frame:SetSize(frame:GetWidth(), height)
        if frame.BackgroundTop then
            frame.BackgroundTop:SetSize(frame:GetWidth() - 20, 100)
            frame.BackgroundBottom:SetSize(frame:GetWidth() - 20, 100)
        end
    end

    function OrganizerMixin:Layout(parentXPadding)
        local anchorA, anchorFrame, anchorB, offsetX, offsetY = anchor:Get()

        local yPosition = 0 - offsetY - yPadding

        for index, entry in ipairs(self.entries) do
            if entry.child then
                entry.child:Layout(offsetX + xPadding + entry.xPadding)
                entry.child:Resize(entry.frame)
            end

            local xPosition = (parentXPadding or 0) + offsetX + xPadding + entry.xPadding
            yPosition = yPosition - entry.yPadding

            entry.frame:ClearAllPoints()
            entry.frame:SetPoint(anchorA, anchorFrame, anchorB, xPosition, yPosition)

            yPosition = yPosition - entry.frame:GetHeight()
        end
    end

    return CreateFromMixins(OrganizerMixin)
end

function HironCraftScan.Frames.createOptionsBlock(titleText, parent, organizer, updateDisplay)
    local options = CreateFrame('Frame', 'Section', parent, 'HironCraftScan_SectionTemplate')

    local anchor = AnchorUtil.CreateAnchor('TOPLEFT', options, 'TOPLEFT', 0, 50)
    local childOrganizer = HironCraftScan.Frames.CreateVerticalLayoutOrganizer(anchor, 5, 0)

    if titleText then
        options.Label:SetText(titleText)
    end

    organizer:Add(options, 1, 0, childOrganizer)

    if updateDisplay then
        local function OnDone(text)
            options.Label:SetText(text)
        end
        options.updateDisplay = function()
            local value = updateDisplay(OnDone)
            if value then
                OnDone(value)
                -- else hope they call OnDone.
            end
        end
    end

    return childOrganizer, options
end

function HironCraftScan.Frames.createCheckBox(labelText, parent, onClickCallback, updateDisplay)
    local checkBox = CreateFrame('CheckButton', nil, parent)
    checkBox:SetSize(25, 25)

    checkBox:SetNormalTexture('Interface\\Buttons\\UI-CheckBox-Up')
    checkBox:SetPushedTexture('Interface\\Buttons\\UI-CheckBox-Down')
    checkBox:SetHighlightTexture('Interface\\Buttons\\UI-CheckBox-Highlight', 'ADD')
    checkBox:SetCheckedTexture('Interface\\Buttons\\UI-CheckBox-Check')
    checkBox:SetDisabledCheckedTexture('Interface\\Buttons\\UI-CheckBox-Check-Disabled')

    if onClickCallback then
        checkBox:SetScript('OnClick', onClickCallback)
    end

    local label = checkBox:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    label:SetText(labelText)
    label:SetPoint('LEFT', checkBox, 'RIGHT', 0, 0) -- Position to the right of the checkbox
    label:SetTextColor(1, 1, 1)
    label:SetFontObject('GameFontHighlight')

    if updateDisplay then
        checkBox.updateDisplay = function()
            local checked, shown = updateDisplay()
            checkBox:SetChecked(checked)
            if shown then
                checkBox:Show()
            else
                checkBox:Hide()
            end
        end
    end

    checkBox.needsExtraYPadding = 16
    checkBox.label = label
    return checkBox
end

function HironCraftScan.Frames.makeMovable(frame)
    frame:RegisterForDrag('LeftButton')
    frame:SetScript('OnDragStart', function(self)
        self:StartMoving()
    end)
    frame:SetScript('OnDragStop', function(self)
        self:StopMovingOrSizing()
    end)
end

function HironCraftScan.Frames.flipTextureHorizontally(texture)
    local ulx, uly, llx, lly, urx, ury, lrx, lry = texture:GetTexCoord()
    texture:SetTexCoord(urx, ury, lrx, lry, ulx, uly, llx, lly)
end

function HironCraftScan.Frames.flipTextureVertically(texture)
    local ulx, uly, llx, lly, urx, ury, lrx, lry = texture:GetTexCoord()
    texture:SetTexCoord(llx, lly, ulx, uly, lrx, lry, urx, ury)
end

function HironCraftScan.Utils.saved(parent, child, default)
    if not parent then
        return nil
    end
    if default and not parent[child] then
        parent[child] = default
    end
    return parent[child]
end

function HironCraftScan.Utils.AddonsAreSaved()
    return HironCraftScan_DB.saved_addons
end

-- A check to be paired with RegisterEnableDisableCallback to perform actions to
-- enable/disable this addons functionality. The callback arguments should be
-- passed through to this helper.
function HironCraftScan.Utils.IsScanningEnabled(event)
    return IsResting() and event ~= 'CINEMATIC_START' and event ~= 'PLAY_MOVIE'
end

function HironCraftScan.Utils.RegisterEnableDisableCallback(callback)
    HironCraftScanScannerMenu:RegisterEventCallback('PLAYER_UPDATE_RESTING', callback)
    HironCraftScanScannerMenu:RegisterEventCallback('ZONE_CHANGED_NEW_AREA', callback)
    HironCraftScanScannerMenu:RegisterEventCallback('CINEMATIC_START', callback)
    HironCraftScanScannerMenu:RegisterEventCallback('CINEMATIC_STOP', callback)
    HironCraftScanScannerMenu:RegisterEventCallback('PLAY_MOVIE', callback)
    HironCraftScanScannerMenu:RegisterEventCallback('STOP_MOVIE', callback)
end

function HironCraftScan.Utils.ToggleSavedAddons()
    if HironCraftScan_DB.saved_addons then
        for _, name in ipairs(HironCraftScan_DB.saved_addons) do
            C_AddOns.EnableAddOn(name)
        end

        print('Addons enabled. Reload UI.')
        HironCraftScan_DB.saved_addons = nil

        return
    end

    local configWhitelist =
        HironCraftScan.Utils.saved(HironCraftScan.DB.settings, 'disabled_addon_whitelist', {})
    local whitelist = { HironCraft = true }
    for _, value in ipairs(configWhitelist) do
        whitelist[value] = true
    end

    HironCraftScan_DB.saved_addons = {}
    local numAddOns = C_AddOns.GetNumAddOns()
    for i = 1, numAddOns do
        local name, _, _, enabled = C_AddOns.GetAddOnInfo(i)
        if enabled and not whitelist[name] then
            table.insert(HironCraftScan_DB.saved_addons, name)
        end
    end

    -- Step 2: Disable all addons
    for _, name in ipairs(HironCraftScan_DB.saved_addons) do
        C_AddOns.DisableAddOn(name)
    end
end

local function AllocateRealmID()
    HironCraftScan_DB.realm_id_seed = HironCraftScan_DB.realm_id_seed or 0
    HironCraftScan_DB.realm_id_seed = HironCraftScan_DB.realm_id_seed + 1

    -- Make it a string so we aren't mixing numeric and string keys in the table,
    -- making it look wonky.
    return '_' .. HironCraftScan_DB.realm_id_seed
end

local function UpgradeRealmStorage()
    -- I was a bit of a dumbass and didn't originally nest realms in an object, so they
    -- are scattered about at the top level. Everything except 'settings',
    -- 'connected_realms', and 'realm_id_seed' are realms, so move them on down.
    local realms = HironCraftScan.Utils.saved(HironCraftScan_DB, 'realms', {})
    for key, value in pairs(HironCraftScan_DB) do
        if
            key ~= 'realms'
            and key ~= 'connected_realms'
            and key ~= 'settings'
            and key ~= 'saved_addons'
            and key ~= 'realm_id_seed'
        then
            realms[key] = value

            -- Preserve legacy account-wide links while moving old realm data.
            -- They are normalized back to one account-wide table after the
            -- current realm has been selected.
            realms[key].linked_accounts = HironCraftScan_DB.settings
                and HironCraftScan_DB.settings.linked_accounts

            -- Normalize the realm name stored in the character name on
            -- connected realms to have no spaces or dashes.
            local newRealms = nil
            for char, info in pairs(value.characters) do
                charName = char:match('^([^-]+)')
                local shortenedRealm = HironCraftScan.Utils.ShortenRealmName(key)
                if shortenedRealm ~= key then
                    newRealms = newRealms or {}
                    newRealms[char] = charName .. '-' .. shortenedRealm
                end
            end

            if newRealms then
                for old, new in pairs(newRealms) do
                    value.characters[new] = value.characters[old]
                    value.characters[old] = nil
                end
            end

            HironCraftScan_DB[key] = nil
        end
    end
end

function HironCraftScan.Utils.ShortenRealmName(realmName)
    -- Hopefully this is the correct shortening. Stolen from https://github.com/phanx-wow/LibRealmInfo/blob/master/LibRealmInfo.lua
    local shortenedName = realmName:gsub('[%s%-]', '')
    return shortenedName
end

local function UpgradeCrossRealmSupport(realmNames)
    if #realmNames == 0 then
        return GetRealmName()
    end

    HironCraftScan_DB.realm_ids = nil

    -- Generate a unique number ID for each set of connected realms. We'll
    -- use that ID to merge realm data instead of a realm name.
    local realmID = nil
    local connectedRealms = HironCraftScan.Utils.saved(HironCraftScan_DB, 'connected_realms', {})
    for _, realmName in ipairs(realmNames) do
        if connectedRealms[realmName] then
            if not realmID then
                realmID = connectedRealms[realmName]
                break
            end
        end
    end

    if not realmID then
        realmID = AllocateRealmID()
    end

    for _, realmName in ipairs(realmNames) do
        if not connectedRealms[realmName] then
            connectedRealms[realmName] = realmID
        elseif realmID ~= connectedRealms[realmName] then
            print(
                string.format(
                    '|cFFFF0000HironCraftScan Error: Connected realm ID problem. Realm: %s. Prior ID: %d. Conflicting ID: %d. Open a github issue.|r',
                    realmName,
                    connectedRealms[realmName],
                    realmID
                )
            )
        end
    end

    local function MergeTablesInPlace(dst, src)
        for key, value in pairs(src) do
            if type(value) == 'table' and type(dst[key]) == 'table' then
                -- If both dst and src have a table at this key, merge them recursively
                MergeTablesInPlace(dst[key], value)
            elseif dst[key] ~= nil then
                -- Key collision detected, print an error message
                print(
                    "HironCraftScan: Error upgrading SavedVariables: Key collision detected for key '"
                        .. tostring(key)
                        .. "'. Overwriting. If your config looks screwed, grab HironCraftScan.lua.bak and save it."
                )
                dst[key] = value
            else
                -- No collision, simply assign the value
                dst[key] = value
            end
        end
    end

    local pending = nil
    local realmDB = HironCraftScan_DB.realms
    for dbRealm, info in pairs(realmDB) do
        local connectedRealm = HironCraftScan.Utils.ShortenRealmName(dbRealm)
        HironCraftScan.Utils.printTable('dbRealm', dbRealm)
        HironCraftScan.Utils.printTable('connectedRealm', connectedRealm)

        if connectedRealms[connectedRealm] then
            pending = pending or {}
            table.insert(pending, {
                dbRealm = dbRealm,
                info = info,
            })
        end
    end

    if pending ~= nil then
        for _, p in ipairs(pending) do
            realmDB[realmID] = realmDB[realmID] or {}
            HironCraftScan.Utils.printTable('Merging', p.info)
            HironCraftScan.Utils.printTable('Into', realmDB[realmID])
            MergeTablesInPlace(realmDB[realmID], p.info)

            -- And remove the old realm-specific entry.
            realmDB[p.dbRealm] = nil
        end
    end
    return realmID
end

local function MergeLinkedAccountInfo(target, source)
    if target == source or type(source) ~= 'table' then
        return
    end

    -- Preserve any fields added by CraftScan or HironCraft versions that this
    -- migration does not know about. Current account-wide values win when both
    -- copies contain a value.
    for key, value in pairs(source) do
        if target[key] == nil then
            target[key] = value
        end
    end

    target.backup_chars = target.backup_chars or {}
    for _, character in ipairs(source.backup_chars or {}) do
        if not HironCraftScan.Utils.Contains(target.backup_chars, character) then
            table.insert(target.backup_chars, character)
        end
    end

    if
        source.last_analytics_share
        and (not target.last_analytics_share or source.last_analytics_share > target.last_analytics_share)
    then
        target.last_analytics_share = source.last_analytics_share
    end
end

local function UpgradeAccountWideLinkedAccounts(currentRealmDB)
    -- A link identifies a WoW account, not a character, faction, or realm. Old
    -- CraftScan storage kept copies under individual realm groups. That works
    -- only while every realm already has a copy and breaks after a clean reset:
    -- a character on another faction/realm cannot announce that it came online.
    local accountWide = HironCraftScan.Utils.saved(
        HironCraftScan.DB.settings,
        'linked_accounts',
        {}
    )

    local function MergeRealm(realmDB)
        if type(realmDB) ~= 'table' then
            return
        end
        for accountID, info in pairs(realmDB.linked_accounts or {}) do
            if type(info) == 'table' then
                if not accountWide[accountID] then
                    accountWide[accountID] = info
                else
                    MergeLinkedAccountInfo(accountWide[accountID], info)
                end
            end
        end
    end

    -- Prefer the realm being loaded, then merge any useful character endpoints
    -- learned on other realms by older versions.
    MergeRealm(currentRealmDB)
    for _, realmDB in pairs(HironCraftScan_DB.realms or {}) do
        if realmDB ~= currentRealmDB then
            MergeRealm(realmDB)
        end
    end

    -- Keep the legacy realm field as an alias so existing call sites and saved
    -- databases remain compatible. All realms point at the same table during
    -- the session, so unlinking cannot leave a stale copy to reappear later.
    for _, realmDB in pairs(HironCraftScan_DB.realms or {}) do
        if type(realmDB) == 'table' then
            realmDB.linked_accounts = accountWide
        end
    end
    currentRealmDB.linked_accounts = accountWide

    return accountWide
end

local function UpgradeAccountWideOrderCompletionNotices(currentRealmDB)
    -- Completion notices must survive an immediate character switch even when
    -- the next crafter belongs to another faction or realm group. Exact row
    -- statuses remain realm-local, but this compact result journal is safe to
    -- replay account-wide because its matching code also checks request time,
    -- customer, item/recipe, and profession context.
    local accountWide = HironCraftScan.Utils.saved(
        HironCraftScan.DB.settings,
        'order_completion_notices',
        {}
    )

    local function PreferSource(source, target)
        if type(target) ~= 'table' then
            return true
        end
        local sourceTime = tonumber(source.updatedAt) or 0
        local targetTime = tonumber(target.updatedAt) or 0
        if sourceTime ~= targetTime then
            return sourceTime > targetTime
        end
        return source.status == 'fulfilled' and target.status ~= 'fulfilled'
    end

    local function MergeRealm(realmDB)
        if type(realmDB) ~= 'table' then
            return
        end
        for key, notice in pairs(realmDB.order_completion_notices or {}) do
            if type(notice) == 'table' and PreferSource(notice, accountWide[key]) then
                accountWide[key] = notice
            end
        end
    end

    MergeRealm(currentRealmDB)
    for _, realmDB in pairs(HironCraftScan_DB.realms or {}) do
        if realmDB ~= currentRealmDB then
            MergeRealm(realmDB)
        end
    end

    -- Alias every realm to the authoritative journal for compatibility with
    -- old call sites and to ensure ACK updates are saved consistently.
    for _, realmDB in pairs(HironCraftScan_DB.realms or {}) do
        if type(realmDB) == 'table' then
            realmDB.order_completion_notices = accountWide
        end
    end
    currentRealmDB.order_completion_notices = accountWide

    return accountWide
end

local function UpgradePersistentConfig()
    -- As we make changes to the SavedVariable format, upgrade it here globally
    -- before anything else runs against it so we don't need conditionals
    -- anywhere else.

    -- Upgrade the profession configuration to create a normalized 'parent
    -- profession' node. The professionIDs we usually deal with are 'Dragon
    -- Isles Blacksmithing', but we present most options per parent profession
    -- (e.g. 'Blacksmithing'). Save state directly in the parent profession
    -- instead of the child professions now. Link the children to the parent.
    for _, charConfig in pairs(HironCraftScan.DB.characters) do
        charConfig['enabled'] = nil
        if charConfig.professions then
            local secondaryProfs = {}
            for profID, profConfig in pairs(charConfig.professions) do
                local profInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(profID)

                -- 'Supply Shipments' is a profession in the emerald dream. It
                -- is marked as a primary profession, so got through our
                -- filters, but it does not have a parentProfessionID.
                if
                    not profInfo.isPrimaryProfession
                    or not profInfo.parentProfessionID
                    or not HironCraftScan.CONST.PROFESSION_DEFAULT_KEYWORDS[profInfo.parentProfessionID]
                then
                    table.insert(secondaryProfs, profID)
                    if profInfo.parentProfessionID then
                        charConfig.parent_professions[profInfo.parentProfessionID] = nil
                    end
                else
                    local parentProfConfigs =
                        HironCraftScan.Utils.saved(charConfig, 'parent_professions', {})
                    local parentProfConfig = HironCraftScan.Utils.saved(
                        parentProfConfigs,
                        profInfo.parentProfessionID,
                        HironCraftScan.Utils.DeepCopy(HironCraftScan.CONST.DEFAULT_PPCONFIG)
                    )
                    profConfig.parentProfID = profInfo.parentProfessionID
                    profConfig['scanning_enabled'] = nil
                    profConfig['auto_reply'] = nil

                    -- Moving profession keywords over to the parent profession so
                    -- they are only configured once. An item match will then
                    -- trigger its expansion's greeting, or if a generic match is
                    -- made, we use the primary expansion's greeting.
                    local keywords = profConfig['keywords']
                    if keywords then
                        if parentProfConfig['keywords'] then
                            if #keywords > #parentProfConfig['keywords'] then
                                parentProfConfig['keywords'] = keywords
                            end
                        else
                            parentProfConfig['keywords'] = keywords
                        end
                        profConfig['keywords'] = nil
                    end
                end
            end
            for _, profID in ipairs(secondaryProfs) do
                -- We were accidentally saving secondary profs in the past. Erase them if found in the persistent config.
                charConfig.professions[profID] = nil
            end
        end
    end

    -- These two were never saving correctly in this location, so it only holds the defaults.
    -- Now located at HironCraftScan_DB.settings.{inclusions,exclusions}
    HironCraftScan_DB['inclusions'] = nil
    HironCraftScan_DB['exclusions'] = nil

    -- Now that we have a proper addon whitelist control, erase all the
    -- 'None's that might have snuck into the list.
    do
        local whitelist = HironCraftScan.DB.settings.disabled_addon_whitelist
        if whitelist then
            for i = #whitelist, 1, -1 do
                if whitelist[i] == 'None' then
                    table.remove(whitelist, i)
                end
            end
        end
    end

    if HironCraftScan.DB.realm.linked_accounts then
        for _, info in pairs(HironCraftScan.DB.realm.linked_accounts) do
            if not info.permissions then
                info.permissions = { HironCraftScanComm.Permissions.Full }
            end
        end
    end

    -- We used to be always on. Now that we want to support customers, it's
    -- opt-in. This keeps it on for existing users.
    if HironCraftScan.DB.analytics.enabled == nil then
        if HironCraftScan.DB.analytics.seen_items and next(HironCraftScan.DB.analytics.seen_items) then
            HironCraftScan.DB.analytics.enabled = true
        end
    end

    if HironCraftScan.DB.settings.discoverable == nil then
        HironCraftScan.DB.settings.discoverable = true
    end

    if HironCraftScan.DB.settings.permissive_matching == nil then
        HironCraftScan.DB.settings.permissive_matching = false
    end

    if HironCraftScan.DB.settings.show_chat_orders_tab == nil then
        HironCraftScan.DB.settings.show_chat_orders_tab = true
    end

    if HironCraftScan.DB.settings.collapse_chat_context == nil then
        HironCraftScan.DB.settings.collapse_chat_context = false
    end

    -- After changing placeholders in customer greetings from %s to {placeholder},
    -- existing configs must be updated to replace %s placeholders with the new ones.

    -- This upgrade work has the downside that users putting %'s in their
    -- messages causes the whole addon not to load. It's been months since this
    -- was added, so just disabling it.
    --[[
    local greeting = HironCraftScan.DB.settings.greeting;
    if greeting ~= nil then
        greeting['GREETING_ALT_CAN_CRAFT_ITEM'] = string.format(greeting['GREETING_ALT_CAN_CRAFT_ITEM'], "{crafter}",
            "{item}");
        greeting['GREETING_ALT_HAS_PROF'] = string.format(greeting['GREETING_ALT_HAS_PROF'], "{crafter}", "{profession}");
        greeting['GREETING_I_CAN_CRAFT_ITEM'] = string.format(greeting['GREETING_I_CAN_CRAFT_ITEM'], "{item}");
        greeting['GREETING_I_HAVE_PROF'] = string.format(greeting['GREETING_I_HAVE_PROF'], "{profession}");
    end
    ]]
    --

    -- Account link users are hitting a case where they have a parent profession
    -- with no associated child professions. I think this has to do with
    -- abandoning professions for artisan acuity shuffling. Look for
    -- unexpected states and wipe them out.
    for char, charConfig in pairs(HironCraftScan.DB.characters) do
        if not charConfig.professions or not charConfig.parent_professions then
            HironCraftScan.DB.characters[char] = nil
        else
            -- Wipe out any child professions configs that don't have a
            -- corresponding parent prof config.
            for profID, profConfig in pairs(charConfig.professions) do
                if not charConfig.parent_professions[profConfig.parentProfID] then
                    charConfig.professions[profID] = nil
                end
            end

            -- Wipe out any parent prof configs that don't have any corresponding
            -- child prof configs.
            for ppID, ppConfig in pairs(charConfig.parent_professions) do
                local found = false
                if ppConfig.character_disabled == true then
                    found = true
                else
                    for _, profConfig in pairs(charConfig.professions) do
                        if profConfig.parentProfID == ppID then
                            found = true
                            break
                        end
                    end
                end
                if not found then
                    charConfig.parent_professions[ppID] = nil
                end
            end
        end
    end

    do
        -- See issue #48
        -- The correct version of this gsub should not have ' in it. This
        -- was a bug in the original ShortenRealmName, and its results were
        -- stored in saved variables. If we find that the current player is
        -- one of these broken shortened names, we replace it with the correct
        -- one. We can only convert from good realm name to bad, so we can't fix
        -- this problem until the user logs in to each character so we can
        -- access the good name to convert it to the bad name and see if it
        -- was saved. Until they do so, messages about that character
        -- will still be missing the '.
        function BrokenShortenRealmName(realmName)
            local shortenedName = realmName:gsub("[%s%-']", '')
            return shortenedName
        end

        local realm = BrokenShortenRealmName(GetRealmName())
        local brokenPlayerName = UnitName('player') .. '-' .. realm
        local correctPlayerName = HironCraftScan.GetPlayerName(true)

        if correctPlayerName ~= brokenPlayerName then
            local config = HironCraftScan.DB.characters[brokenPlayerName]
            if config then
                HironCraftScan.DB.characters[correctPlayerName] = config
                HironCraftScan.DB.characters[brokenPlayerName] = nil
            end
        end
    end

    do
        -- Upgrade for cross-character configuration. Change 'enabled' to
        -- 'scan_state' on, to support new scan states of off, pending, and
        -- unlearned.
        for _, charConfig in pairs(HironCraftScan.DB.characters) do
            if charConfig.professions then
                for _, profConfig in pairs(charConfig.professions) do
                    if profConfig.recipes then
                        local all_enabled = profConfig.all_enabled
                        for _, recipeConfig in pairs(profConfig.recipes) do
                            if not recipeConfig.scan_state then
                                -- We never stored unlearned recipes prior to the
                                -- upgrade to 'scan_state', so anything not enabled
                                -- should be flagged pending so the user can decide to
                                -- move it to on or off.
                                local enabled = recipeConfig.enabled
                                if enabled or all_enabled then
                                    recipeConfig.scan_state =
                                        HironCraftScan.CONST.RECIPE_STATES.SCANNING_ON
                                else
                                    recipeConfig.scan_state =
                                        HironCraftScan.CONST.RECIPE_STATES.PENDING_REVIEW
                                end
                                recipeConfig['enabled'] = nil
                            end
                            recipeConfig['categoryID'] = nil
                            if recipeConfig['override'] then
                                recipeConfig['omit_profession'] = recipeConfig['override']
                                recipeConfig['override'] = nil
                            end
                        end
                        -- It's becoming much easier to determine what is and is not
                        -- enabled, so the 'all_enabled' functionality is going away.
                        profConfig['all_enabled'] = nil
                        profConfig['categoryIDsUpgraded'] = nil
                    end
                end
            end
        end
    end
end

function HironCraftScan.Utils.GetSetting(key)
    local value = HironCraftScan.DB.settings[key]
    if value then
        return value
    end

    return HironCraftScan.CONST.DEFAULT_SETTINGS[key]
end

local once = false
local function doOnce()
    if once then
        return
    end
    -- Things that should happen one time before any other files run their init

    -- Can't seem to internationalize the binding header anymore. Comes as a raw string in Bindings.xml
    -- Can't find a proper API to tag these as search-able, so tossing the name in there.
    BINDING_NAME_HIRONCRAFT_SCAN_TOGGLE =
        string.format('%s - %s', L(LID.MAIN_BUTTON_BINDING_NAME), L(LID.HIRONCRAFT_SCAN))
    BINDING_NAME_HIRONCRAFT_SCAN_CONFIG_TOGGLE =
        string.format('%s - %s', L(LID.CONFIG_TOGGLE_BINDING_NAME), L(LID.HIRONCRAFT_SCAN))
    BINDING_NAME_HIRONCRAFT_SCAN_GREET_CURRENT_CUSTOMER =
        string.format('%s - %s', L(LID.GREET_BUTTON_BINDING_NAME), L(LID.HIRONCRAFT_SCAN))
    BINDING_NAME_HIRONCRAFT_SCAN_CHAT_CURRENT_CUSTOMER =
        string.format('%s - %s', L(LID.CHAT_BUTTON_BINDING_NAME), L(LID.HIRONCRAFT_SCAN))
    BINDING_NAME_HIRONCRAFT_SCAN_DISMISS_CURRENT_CUSTOMER =
        string.format('%s - %s', L(LID.DISMISS_BUTTON_BINDING_NAME), L(LID.HIRONCRAFT_SCAN))

    -- We alias our SavedVariable so we can easily switch to non-persistent mode for testing.
    HironCraftScan.DB = {}
    HironCraftScan.State = {}
    local persistentMode = true
    if persistentMode then
        HironCraftScan_DB = HironCraftScan_DB or {}

        UpgradeRealmStorage()

        HironCraftScan.DB.settings = HironCraftScan.Utils.saved(HironCraftScan_DB, 'settings', {})
        HironCraftScan.DB.settings.inclusions = HironCraftScan.DB.settings.inclusions
            or L(LID.GLOBAL_INCLUSION_DEFAULT)
        HironCraftScan.DB.settings.exclusions = HironCraftScan.DB.settings.exclusions
            or L(LID.GLOBAL_EXCLUSION_DEFAULT)

        local realmNames = GetAutoCompleteRealms()
        HironCraftScan.Utils.printTable('realmNames', realmNames)

        local realmID = UpgradeCrossRealmSupport(realmNames)
        if #realmNames ~= 0 then
            HironCraftScan.State.realmID = realmID
            HironCraftScan.State.realmNames = realmNames
        end

        local realmDB = HironCraftScan.Utils.saved(HironCraftScan_DB.realms, realmID, {})
        UpgradeAccountWideLinkedAccounts(realmDB)
        UpgradeAccountWideOrderCompletionNotices(realmDB)
        HironCraftScan.DB.characters = HironCraftScan.Utils.saved(realmDB, 'characters', {})
        HironCraftScan.DB.listed_orders = HironCraftScan.Utils.saved(realmDB, 'listed_orders', {})
        HironCraftScan.DB.customers = HironCraftScan.Utils.saved(realmDB, 'customers', {})
        HironCraftScan.DB.analytics = HironCraftScan.Utils.saved(realmDB, 'analytics', {})
        HironCraftScan.DB.realm = realmDB

        UpgradePersistentConfig()

        HironCraftScan.UpdateHasMatchStyle()
    else
        HironCraftScan.DB.settings = {}
        HironCraftScan.DB.settings.inclusions = L(LID.GLOBAL_INCLUSION_DEFAULT)
        HironCraftScan.DB.settings.exclusions = L(LID.GLOBAL_EXCLUSION_DEFAULT)
        HironCraftScan.DB.characters = {}
        HironCraftScan.DB.listed_orders = {}
        HironCraftScan.DB.customers = {}
        HironCraftScan.DB.analytics = {}
    end

    local prof1, prof2 = GetProfessions()
    HironCraftScan.CONST.PROFESSIONS = {}
    for _, prof in ipairs({ prof1, prof2 }) do
        local _, icon, _, _, _, _, professionID = GetProfessionInfo(prof)
        local professionInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(professionID)
        HironCraftScan.State.professionID = professionID
        table.insert(HironCraftScan.CONST.PROFESSIONS, {
            professionID = professionID,
            icon = icon,
            profession = professionInfo.profession,
        })
    end

    HironCraftScan.NotifyRecentChanges()

    HironCraftScanComm:ShareCharacterData()

    once = true
end

-- Originally, the 'Chat orders' tab was actually part of the professions frame.
-- That was a giant memory leak for some reason, so I changed it to its own page
-- that has a link to both of the characters professions. I was originally
-- trying to keep the icon in sync with which profession should be opened, but
-- now that it's neither, the icon doesn't really matter. Instead of associating
-- it directly with one of the current character's professions, it should now
-- flip around to match the most recent customer request.
HironCraftScan.Utils.GetCurrentProfessionIcon = function()
    if HironCraftScan.State.activeOrder then
        -- If we have an active order, return the icon associated with the
        -- requested profession to give a good visual queue about the request.
        local response = HironCraftScan.OrderToResponse(HironCraftScan.State.activeOrder)
        return HironCraftScan.CONST.MIDNIGHT_PROFESSION_ICONS[response.professionID]
            or HironCraftScan.CONST.PARENT_PROFESSION_ICONS[response.parentProfID]
    end

    -- Otherwise, fall back to one of our professions - the one that we're near
    -- the crafting table for if possible.
    local prof = nil
    for _, p in ipairs(HironCraftScan.CONST.PROFESSIONS) do
        if C_TradeSkillUI.IsNearProfessionSpellFocus(p.profession) then
            return p.icon
        elseif HironCraftScan.State.professionID == p.professionID then
            prof = p
        elseif not prof then
            prof = p
        end
    end
    return prof and prof.icon
end

local loginFrame = CreateFrame('Frame')
local loadOnLogin = {}
local requiredAddons = { 'HironCraft', 'Blizzard_Professions' }
function HironCraftScan.Utils.onLoad(onLoad)
    if not C_AddOns.IsAddOnLoaded('Blizzard_Professions') then
        C_AddOns.LoadAddOn('Blizzard_Professions')
    end

    local count = 0

    local function doLoad()
        count = count + 1
        if count ~= #requiredAddons then
            return
        end
        if not IsLoggedIn() then
            table.insert(loadOnLogin, onLoad)
            if not loginFrame:GetScript('OnEvent') then
                -- SavedVariables are not available until the player is logged in.
                loginFrame:RegisterEvent('PLAYER_LOGIN')
                loginFrame:SetScript('OnEvent', function(self, event, ...)
                    if event == 'PLAYER_LOGIN' then
                        doOnce()
                        for _, onLoad in ipairs(loadOnLogin) do
                            onLoad()
                        end
                        loginFrame = nil
                    end
                end)
            end
        else
            doOnce()
            onLoad()
        end
    end

    for _, entry in ipairs(requiredAddons) do
        local loaded, fullyLoaded = C_AddOns.IsAddOnLoaded(entry)
        if fullyLoaded then
            doLoad()
        else
            EventUtil.ContinueOnAddOnLoaded(entry, function()
                doLoad()
            end)
        end
    end
end

local function GetMaxTextLeftWidth(tooltipName)
    local tooltip = _G[tooltipName]
    if not tooltip then
        return nil
    end

    local maxWidth = 0

    for i = 1, tooltip:GetNumRegions() do
        local region = select(i, tooltip:GetRegions())
        if
            region
            and region:GetObjectType() == 'FontString'
            and region:GetName()
            and region:GetName():match('TextLeft')
        then
            local width = region:GetStringWidth()
            if width > maxWidth then
                maxWidth = width
            end
        end
    end

    return maxWidth
end

-- I want the help text in the top right corner of the tooltip, which uses
-- TextRight. With no TextLeft associated with them, they were vertically
-- overlapping. This method walks the right text of a tooltip and manually
-- spaces it out to look nice.
local function SpaceOutRightText(tooltipName)
    local tooltip = _G[tooltipName]
    if not tooltip then
        return
    end

    local lastRegion = nil
    for i = 1, tooltip:GetNumRegions() do
        local region = select(i, tooltip:GetRegions())
        if
            region
            and region:GetObjectType() == 'FontString'
            and region:GetName()
            and region:GetName():match('TextRight')
        then
            if lastRegion then
                region:SetPoint('TOPRIGHT', lastRegion, 'BOTTOMRIGHT', 0, -1)
            end
            lastRegion = region
        end
    end
end

-- This method is a bit of mess now that we're only ever populating a single %s,
-- but too lazy to fix atm.
HironCraftScan.Utils.PopulateBinds = function(lid, ...)
    local binds = { ... }
    for i, bind in ipairs(binds) do
        local b = GetBindingKey(bind)
        if b then
            binds[i] = ' |cffffd100(' .. b .. ')|r'
        else
            binds[i] = ''
        end
    end
    if not next(binds) then
        return string.format(L(lid), '')
    end
    return string.format(L(lid), unpack(binds))
end

HironCraftScan.Utils.ChatHistoryTooltip = {}
HironCraftScan.Utils.ChatHistoryTooltip.__index = HironCraftScan.Utils.ChatHistoryTooltip

function HironCraftScan.Utils.GetChatHistoryColor(chat)
    local args = type(chat) == 'table' and chat.args
    local r = type(args) == 'table' and tonumber(args[1])
    local g = type(args) == 'table' and tonumber(args[2])
    local b = type(args) == 'table' and tonumber(args[3])
    if r and g and b then
        return r, g, b
    end

    local chatType = type(chat) == 'table' and chat.chatType
    local message = type(chat) == 'table' and tostring(chat.message or '') or ''
    if not chatType and message:find('|Hchannel:', 1, true) then
        chatType = 'CHANNEL'
    end
    local color = ChatTypeInfo and ChatTypeInfo[chatType or 'WHISPER']
    if color then
        return color.r or 0.78, color.g or 0.78, color.b or 0.78
    end
    return 0.78, 0.78, 0.78
end

function HironCraftScan.Utils.ChatHistoryTooltip:new()
    local instance = setmetatable({}, HironCraftScan.Utils.ChatHistoryTooltip)
    instance.tooltip = nil
    return instance
end

function HironCraftScan.Utils.ChatHistoryTooltip:Hide()
    if self.tooltip then
        self.tooltip:Hide()
    end
end

function HironCraftScan.Utils.ChatHistoryTooltip:Show(name, anchor, order, header, includeBinds)
    if not self.tooltip then
        self.tooltip = CreateFrame('GameTooltip', name, UIParent, 'GameTooltipTemplate')
        self.tooltip.TextLeft2:SetFontObject(ChatFrame1:GetFontObject())
        self.tooltip.TextRight1:SetFontObject(self.tooltip.TextRight2:GetFontObject())
    end

    local tooltip = self.tooltip
    tooltip:ClearLines()

    tooltip:SetOwner(anchor, 'ANCHOR_TOPLEFT')

    local response = HironCraftScan.OrderToResponse(order)
    if response.greeting_sent then
        tooltip:AddDoubleLine(header, L('Chat Help'), 1, 1, 1)
    else
        tooltip:AddDoubleLine(
            header,
            HironCraftScan.Utils.PopulateBinds(
                L('Greet Help'),
                includeBinds and 'HIRONCRAFT_SCAN_GREET_CURRENT_CUSTOMER'
            ),
            1,
            1,
            1
        )
        tooltip:AddDoubleLine(
            '',
            HironCraftScan.Utils.PopulateBinds(
                L('Chat Override'),
                includeBinds and 'HIRONCRAFT_SCAN_CHAT_CURRENT_CUSTOMER'
            )
        )
    end
    tooltip:AddDoubleLine(
        '',
        HironCraftScan.Utils.PopulateBinds(
            L('Dismiss'),
            includeBinds and 'HIRONCRAFT_SCAN_DISMISS_CURRENT_CUSTOMER'
        )
    )

    GameTooltip_AddBlankLineToTooltip(tooltip)

    if not response.greeting_sent then
        HironCraftScan.RebuildResponseMessage(order)
        tooltip:AddLine(L('Proposed Greeting'), 1, 1, 1)
        local wc = ChatTypeInfo['WHISPER']
        for _, line in ipairs(response.message) do
            tooltip:AddLine(line, wc.r, wc.g, wc.b, true, 0)
        end

        GameTooltip_AddBlankLineToTooltip(tooltip)
    end

    local customerInfo = HironCraftScan.OrderToCustomerInfo(order)
    for _, chat in ipairs(HironCraftScan.Utils.GetUniqueChatHistory(customerInfo.chat_history)) do
        local r, g, b = HironCraftScan.Utils.GetChatHistoryColor(chat)
        tooltip:AddLine(chat.message, r, g, b, true, 0)
    end

    SpaceOutRightText(name)

    -- Find the maximum text width so we can make the tooltip look sane. If it's
    -- super long, cap at the chat frame width to match its text wrapping.
    tooltip:SetMinimumWidth(math.min(GetMaxTextLeftWidth(name), ChatFrame1:GetWidth()))

    tooltip:Show()
end

function HironCraftScan.Utils.SizeTooltipLikeChat(name, tooltip)
    SpaceOutRightText(name)

    -- Find the maximum text width so we can make the tooltip look sane. If it's
    -- super long, cap at the chat frame width to match its text wrapping.
    tooltip:SetMinimumWidth(math.min(GetMaxTextLeftWidth(name), ChatFrame1:GetWidth()))
end
