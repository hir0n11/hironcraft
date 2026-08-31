local HironCraftScan = select(2, ...)

local C = HironCraftScan.CONST
local LID = C.TEXT
local function L(id)
    return HironCraftScan.LOCAL:GetText(id)
end

local AceConfig = LibStub('AceConfig-3.0')
local AceConfigCmd = LibStub('AceConfigCmd-3.0') -- handles slash -> options mapping

local configOption = {
    type = 'execute',
    name = 'Config',
    desc = 'Toggle the config page',
    func = function()
        HironCraftScanConfigPage:ToggleVisibility()
    end,
}

local ordersOption = {
    type = 'execute',
    name = 'Orders',
    desc = 'Toggle the order page',
    func = function()
        if HironCraftScanConfigPage:IsShown() then
            HironCraftScanConfigPage:Hide()
        else
            HironCraftScanConfigPage:Show()
        end
    end,
}

local debugOption = {
    type = 'toggle',
    name = 'Debug',
    desc = 'Toggle debug mode (requires DevTool)',
    get = function()
        return HironCraftScan.Debug.IsEnabled()
    end,
    set = function(_, value)
        HironCraftScan.Debug.Enable(value)
    end,
}

-- Define your slash commands and subcommands
local options = {
    type = 'group',
    name = 'HironCraftScan',
    args = {
        config = configOption,
        c = configOption,
        orders = ordersOption,
        o = ordersOption,
        debug = debugOption,
        d = debugOption,
    },
}

-- Register the options table
AceConfig:RegisterOptionsTable('HironCraftScan', options)

-- Register the slash command to use the AceConfigCmd handler
AceConfigCmd:CreateChatCommand('hironcraftscan', 'HironCraftScan')
AceConfigCmd:CreateChatCommand('hcs', 'HironCraftScan')

table.insert(UISpecialFrames, 'HironCraftScanConfigPage')

local menuInitialized = false

local function IsEmptyNode(node)
    for _, child in ipairs(node:GetNodes()) do
        if child.data and (child.data.configInfo or child.data.headerInfo) then
            return false
        end
    end
    return true
end

local function EraseEmptyParents(node)
    if IsEmptyNode(node) then
        local parent = node:GetParent()
        parent:Remove(node)
        parent[node.data.parentKey] = nil
        EraseEmptyParents(parent)
    end
end

local function IsConcentrationDependent(recipeConfig)
    return C.RECIPE_STATES.SCANNING_ON == recipeConfig.scan_state
        and recipeConfig.required_concentration
        and recipeConfig.required_concentration ~= 0
end

local function HasRequiredConcentration(recipeConfig, profConfig)
    if not profConfig.concentration then
        return true -- Don't know concentration, so err on the side of scanning.
    end

    local concentration = HironCraftScan.ConcentrationData:Deserialize(profConfig.concentration)
    return recipeConfig.required_concentration <= concentration:GetCurrentAmount()
end

local function ConcentrationScanningSuffix(r, g, state)
    return ' - ' .. CreateColor(r, g, 0):WrapTextInColorCode(L(C.RECIPE_STATE_NAMES[state]))
end

local function ConcentrationScanningOnText()
    return L('Concentration Dependent')
        .. ConcentrationScanningSuffix(0, 1, C.RECIPE_STATES.SCANNING_ON)
end

local function ConcentrationScanningOffText()
    return L('Concentration Dependent')
        .. ConcentrationScanningSuffix(1, 0, C.RECIPE_STATES.SCANNING_OFF)
end

function HironCraftScan.RecipeStateName(recipeConfig, profConfig)
    if IsConcentrationDependent(recipeConfig) then
        if HasRequiredConcentration(recipeConfig, profConfig) then
            return ConcentrationScanningOnText()
        end
        return ConcentrationScanningOffText()
    end
    return L(C.RECIPE_STATE_NAMES[recipeConfig.scan_state])
end

local function GetScanStateDisplayOrder(recipeConfig, profConfig)
    local state = recipeConfig.scan_state
    local states = HironCraftScan.CONST.RECIPE_STATES
    if IsConcentrationDependent(recipeConfig) then
        if HasRequiredConcentration(recipeConfig, profConfig) then
            return 2
        end
        return 3
    elseif states.PENDING_REVIEW == state then
        return 1
    elseif states.SCANNING_ON == state then
        return 4
    elseif states.SCANNING_OFF == state then
        return 5
    elseif states.UNLEARNED == state then
        return 6
    end
end

local function SortByHeaderLabel(lhs, rhs)
    return strcmputf8i(lhs.data.headerInfo.label, rhs.data.headerInfo.label) < 0
end

local function SetSortComparator(node, comparator)
    local affectChildren = false
    local skipSort = false

    local function OrderComparatorWrapper(lhs, rhs)
        local lhsOrder = lhs.data.order
        local rhsOrder = rhs.data.order
        if lhsOrder ~= rhsOrder then
            return lhsOrder < rhsOrder
        end

        if comparator then
            return comparator(lhs, rhs)
        end
        return false
    end

    node:SetSortComparator(OrderComparatorWrapper, affectChildren, skipSort)
end

local function MakeProfessionNodeFactory(root)
    local db = {}

    local function SortByItemLabel(lhs, rhs)
        return strcmputf8i(lhs.data.configInfo.label, rhs.data.configInfo.label) < 0
    end

    local function GetProfessionNode(char, profID, profConfig)
        local isCurrent = HironCraftScan.Utils.IsCurrentExpansion(profID)
        if not db[isCurrent] then
            local expansionNode = root:Insert({
                parentKey = isCurrent,
                order = isCurrent and 3 or 4,
                headerInfo = {
                    label = L(isCurrent and 'Crafters' or 'Legacy Crafters'),
                    startCollapsed = not isCurrent,
                },
                sorter = SortByHeaderLabel,
            })
            db[isCurrent] = expansionNode
        end

        if not db[isCurrent][char] then
            local GetCrafterNameColor = function()
                local color = HironCraftScan.GetCrafterNameColor(char)
                if color.r ~= 0 then
                    -- We color the current character green. Usually the
                    -- others are white, but since the rest of the menu
                    -- colors entries yellow, we swap to that.
                    return CreateColor(GameFontNormal_NoShadow:GetTextColor())
                end
                return color
            end
            local charNode = db[isCurrent]:Insert({
                parentKey = char,
                order = 0,
                headerInfo = {
                    GetLabelColor = GetCrafterNameColor,
                    label = HironCraftScan.NameAndRealmToName(char, true),
                },
                sorter = SortByHeaderLabel,
            })

            charNode:Insert({ order = 1, bottomPadding = true })
            db[isCurrent][char] = charNode
        end

        if not db[isCurrent][char][profID] then
            local professionName = HironCraftScan.Utils.ProfessionNameByID(profConfig.parentProfID)
            if not isCurrent then
                professionName = HironCraftScan.Utils.ProfessionNameByID(profID)
            end
            local GetProfessionNameColor = function()
                return HironCraftScan.Utils.ProfessionColor(profConfig.parentProfID)
            end

            local profNode = db[isCurrent][char]:Insert({
                parentKey = profID,
                order = 0,
                headerInfo = {
                    -- TODO Add a 'refresh' style button to read in the profession on the current character.
                    GetLabelColor = GetProfessionNameColor,
                    label = professionName,
                    startCollapsed = true,
                },
                configInfo = {
                    char = char,
                    profID = profID,
                    profConfig = profConfig,
                    parentProfID = profConfig.parentProfID,
                    ppConfig = HironCraftScan.DB.characters[char].parent_professions[profConfig.parentProfID],
                    LoadOptions = HironCraftScan.Config.LoadProfessionConfigOptions,
                },
                sorter = false,
            })
            -- Scan_state is set as order, so 1-4 for pending/on/off/unlearned.
            -- Add some bottom padding by setting order higher than that - 10.
            profNode:Insert({ order = 10, bottomPadding = true })
            db[isCurrent][char][profID] = profNode
        end
        return db[isCurrent][char][profID]
    end

    local function GetRecipeParentNode(char, profID, profConfig, recipeConfig)
        local profNode = GetProfessionNode(char, profID, profConfig)
        local recipeScanState = GetScanStateDisplayOrder(recipeConfig, profConfig)
        if not profNode[recipeScanState] then
            local sectionNode = profNode:Insert({
                parentKey = recipeScanState,
                order = recipeScanState,
                headerInfo = {
                    label = HironCraftScan.RecipeStateName(recipeConfig, profConfig),
                    startCollapsed = true,
                },
                sorter = SortByItemLabel,
            })
            sectionNode:Insert({ order = 1, bottomPadding = true })
            profNode[recipeScanState] = sectionNode
        end

        return profNode[recipeScanState]
    end

    local function ExpandToNode(root, configInfo)
        local char = configInfo.char
        local profID = configInfo.profID
        local recipeConfig = configInfo.recipeConfig

        local isCurrent = HironCraftScan.Utils.IsCurrentExpansion(profID)
        local recipeScanState = GetScanStateDisplayOrder(recipeConfig, configInfo.profConfig)

        -- Expand the root
        root:SetCollapsed(
            false,
            TreeDataProviderConstants.RetainChildCollapse,
            TreeDataProviderConstants.SkipInvalidation
        )

        -- And then expand down the tree until we've expanded the exact node
        -- containing the recipe.
        local node = db
        for _, key in ipairs({ isCurrent, char, profID, recipeScanState }) do
            node = node[key]
            node:SetCollapsed(
                false,
                TreeDataProviderConstants.RetainChildCollapse,
                TreeDataProviderConstants.SkipInvalidation
            )
        end
    end

    local function InsertRecipeNode(parentNode, char, profID, profConfig, recipeInfo, recipeConfig)
        parentNode:Insert({
            order = 0,
            configInfo = {
                label = recipeInfo.name,
                char = char,
                profID = profID,
                profConfig = profConfig,
                recipeID = recipeInfo.recipeID,
                recipeConfig = recipeConfig,
                LoadOptions = HironCraftScan.Config.LoadRecipeConfigOptions,
            },
        })
    end

    local function PopulateProfessionNode(char, profID, profConfig, existingRecipeIDs, onFinished)
        -- For the initial load, the tree is not even displayed, so all this
        -- work occurring in the background happens very quickly and the page
        -- opens almost instantly. Once the tree is displayed and we're updating
        -- it, there's a bit of a screen lock up as the tree is updated, so we
        -- time slice that into small chunks so the tree updates in real time
        -- for the user to see instead of freezing the screen.
        local perFrame = existingRecipeIDs and 5 or 2000000

        if not profConfig.recipes then
            if onFinished then
                onFinished()
            end
            return
        end

        HironCraftScan.TimeSlice(profConfig.recipes, perFrame, function(recipeID, recipeConfig)
            if not existingRecipeIDs or not existingRecipeIDs[recipeID] then
                local parentNode = GetRecipeParentNode(char, profID, profConfig, recipeConfig)
                local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
                InsertRecipeNode(parentNode, char, profID, profConfig, recipeInfo, recipeConfig)
            end
        end, onFinished)
    end

    local function UpdateProfessionNode(char, profID, profConfig)
        if not menuInitialized then
            -- Nothing to update. It'll be correct when initialized.
            return
        end

        -- This is all  overkill. We should simply wipe out the tree and reload
        -- from the current state, but I want to play with the tree update
        -- functions and try to get them right.
        --
        -- We might have learned recipes that were previously marked as
        -- unlearned, so we need to move those to the correct spot. We might
        -- have also read in completely new recipes that didn't exist on last
        -- login, so check for those as well.
        --
        -- Create a list of nodes that need to be moved and a hash of existing
        -- nodes so we don't add duplicates.
        local profNode = GetProfessionNode(char, profID, profConfig)
        local scanStateChanges = {}
        local existingRecipeIDs = {}
        local emptyParents = {}
        for _, scanStateNode in ipairs(profNode:GetNodes()) do
            local toBeErased = {}
            for _, recipeNode in ipairs(scanStateNode:GetNodes()) do
                if recipeNode.data.configInfo then
                    local configInfo = recipeNode.data.configInfo
                    if not configInfo.profConfig.recipes[configInfo.recipeID] then
                        -- If the recipe has been removed from the config, erase
                        -- it from the tree.
                        table.insert(toBeErased, recipeNode)
                    else
                        if
                            GetScanStateDisplayOrder(configInfo.recipeConfig, configInfo.profConfig)
                            ~= scanStateNode.data.order
                        then
                            table.insert(scanStateChanges, recipeNode.data.configInfo)
                        end

                        existingRecipeIDs[configInfo.recipeID] = true
                    end
                end
            end
            for _, node in ipairs(toBeErased) do
                scanStateNode:Remove(node)
                table.insert(emptyParents, scanStateNode)
            end
        end

        for _, node in ipairs(emptyParents) do
            EraseEmptyParents(node)
        end

        -- Move any nodes in the wrong place.
        for _, configInfo in ipairs(scanStateChanges) do
            local skipReload = true
            HironCraftScan.Config.OnRecipeScanStateChange(configInfo, skipReload)
        end

        --  At this point, we know all nodes are in the correct spot, now we
        --  just need to insert any new recipes that weren't present the last
        --  time the profession was loaded.
        PopulateProfessionNode(char, profID, profConfig, existingRecipeIDs)

        profNode:Invalidate()
    end

    local function RemoveMissingProfessionNodes(char)
        local profConfigs = HironCraftScan.DB.characters[char].professions

        for _, isCurrent in ipairs({ true, false }) do
            local toBeRemoved = {}
            local charNode = db[isCurrent] and db[isCurrent][char]
            if charNode then
                for _, profNode in ipairs(charNode:GetNodes()) do
                    if
                        profNode.data.configInfo
                        and not profConfigs[profNode.data.configInfo.profID]
                    then
                        table.insert(toBeRemoved, profNode)
                    end
                end
            end
            for _, profNode in ipairs(toBeRemoved) do
                charNode:Remove(profNode)
                charNode[profNode.data.configInfo.profID] = nil
                EraseEmptyParents(charNode)
            end
        end

        -- Minor bug - we leave the character node even if it's empty. Not going
        -- to worry about it.
    end

    return GetRecipeParentNode,
        PopulateProfessionNode,
        UpdateProfessionNode,
        RemoveMissingProfessionNodes,
        ExpandToNode
end

HironCraftScanConfigPageMixin = {}

function HironCraftScanConfigPageMixin:OnShow()
    local icon = HironCraftScan.Utils.GetCurrentProfessionIcon()
    self:SetPortraitToAsset(icon or 4620670)
end

function HironCraftScanConfigPageMixin:OnHide()
    HironCraftScan.Events:Emit('TETHER_CHANGED', false)
end

function HironCraftScanConfigPageMixin:ToggleVisibility()
    if self:IsShown() then
        self:Hide()
    else
        self:SetMenuCollapsed(false)
        self:Show()
    end
end

function HironCraftScanConfigPageMixin:AnchorToProfessionPage()
    local profFrame = _G['ProfessionsFrame']
    if not profFrame or not profFrame:IsShown() then
        return
    end

    self:ClearAllPoints()
    if self.isMenuCollapsed then
        self:SetPoint('TOPLEFT', profFrame, 'TOPRIGHT', 0, 0)
        self:SetPoint('BOTTOMLEFT', profFrame, 'BOTTOMRIGHT', 0, 0)
    else
        local menuWidth = self.Menu:GetWidth()
        self:SetPoint('TOPLEFT', profFrame, 'TOPRIGHT', -menuWidth, 0)
        self:SetPoint('BOTTOMLEFT', profFrame, 'BOTTOMRIGHT', -menuWidth, 0)
    end

    -- Ensure we stay behind Blizzard
    self:SetFrameLevel(math.max(0, profFrame:GetFrameLevel() - 1))
    profFrame:Raise()

    -- TSM seems to be breaking the auto-hide based on parenthood, so we
    -- manually hide the config page when the Schematic form is hidden.
    ProfessionsFrame.CraftingPage.SchematicForm:HookScript('OnHide', function()
        if self.tethered then
            self:Hide()
        end
    end)
end

function HironCraftScanConfigPageMixin:ResizeOptionsPanel(collapsed, activeOptions)
    local width = 1105
    if collapsed then
        if activeOptions then
            width = activeOptions:GetWidth()
        else
            width = width - 350
        end
    end
    self:SetWidth(width)
end

function HironCraftScanConfigPageMixin:SetMenuCollapsed(collapsed)
    if self.isMenuCollapsed == collapsed then
        return
    end

    self.isMenuCollapsed = collapsed
    self.Menu:SetShown(not collapsed)

    if self.Menu.activeOptions and self.Menu.activeOptions.Layout then
        self.Menu.activeOptions:Layout(collapsed)
    end

    self:ResizeOptionsPanel(collapsed, self.Menu.activeOptions)

    -- Update the Options panel anchoring
    self.Options:ClearAllPoints()
    if collapsed then
        -- COLLAPSED: Snap the options to the LEFT edge of the whole frame
        self.Options:SetPoint('TOPLEFT', self, 'TOPLEFT', 4, -62)
        self.Options:SetPoint('BOTTOMRIGHT', self, 'BOTTOMRIGHT', -4, 4)
    else
        -- EXPANDED: Snap it back to the RIGHT side of the Menu
        self.Options:SetPoint('TOPLEFT', self.Menu, 'TOPRIGHT', 0, 0)
        self.Options:SetPoint('BOTTOMRIGHT', self, 'BOTTOMRIGHT', 0, 4)
    end

    -- 3. Update the button's internal state so the arrow points the right way
    if collapsed then
        self.MaximizeMinimize:Minimize()
    else
        self.MaximizeMinimize:Maximize()
    end

    if collapsed and ProfessionsFrame:IsShown() then
        self:AnchorToProfessionPage()
    end
end

HironCraftScan.Events:Register('ACTIVE_OPTION_UPDATED', function(activeOptions)
    local page = HironCraftScanConfigPage
    page:ResizeOptionsPanel(page.isMenuCollapsed, activeOptions)
end)

function HironCraftScanConfigPageMixin:ToggleMenu()
    self:SetMenuCollapsed(not self.isMenuCollapsed)
end

function HironCraftScanConfigPageMixin:SelectRecipe(char, profID, recipeID, attachButton)
    local menu = self.Menu

    local function OnMenuInitialized()
        if ProfessionsFrame.CraftingPage.SchematicForm:IsShown() then
            self:SetMenuCollapsed(true)
            self:AnchorToProfessionPage()
        end

        local dataProvider = menu.dataProvider

        -- Find the tree node containing what we need.
        local node = dataProvider:FindElementDataByPredicate(function(node)
            local data = node:GetData()
            return data.configInfo
                and data.configInfo.recipeID
                and data.configInfo.recipeID == recipeID
                and data.configInfo.char == char
                and data.configInfo.profID == profID
        end, TreeDataProviderConstants.IncludeCollapsed)

        if node then
            menu.ExpandToNode(dataProvider:GetRootNode(), node:GetData().configInfo)
            menu.selectionBehavior:SelectElementData(node)
            dataProvider:Invalidate()
            menu.ScrollBox:ScrollToElementData(node)
        end
    end

    if self:IsShown() then
        OnMenuInitialized()
    else
        if attachButton then
            attachButton:AttachedMenuLoading()
        end
        menu.onMenuInitialized = function()
            OnMenuInitialized()
            self:Show()
            if attachButton then
                attachButton:AttachedMenuLoadComplete()
            end
        end
        menu:InitMenu()
    end
end

function HironCraftScanConfigPageMixin:OnLoad()
    HironCraftScan.Frames.ConfigPage = self

    self:SetMovable(true)
    self:EnableMouse(true)
    self:RegisterForDrag('LeftButton')
    self:SetScript('OnDragStart', self.StartMoving)
    self:SetScript('OnDragStop', self.StopMovingOrSizing)

    self:SetTitle(L('HironCraftScan'))

    self:SetUserPlaced(true)

    HironCraftScan.Events:Register('OPEN_RECIPE', function(...)
        self:SelectRecipe(...)
    end)

    self.tethered = false
    HironCraftScan.Events:Register('TETHER_CHANGED', function(tethered)
        self.tethered = tethered
    end)

    -- Initialize the Maximize/Minimize button
    self.MaximizeMinimize:SetOnMaximizedCallback(function()
        HironCraftScan.Events:Emit('TETHER_CHANGED', false)
        self:SetMenuCollapsed(false)
    end)
    self.MaximizeMinimize:SetOnMinimizedCallback(function()
        self:SetMenuCollapsed(true)
    end)
end

HironCraftScanConfigMenuMixin = {}

function HironCraftScanConfigMenuMixin:OnLoad()
    local indent = 10
    local padLeft = 0
    local pad = 5
    local spacing = 1
    local view = CreateScrollBoxListTreeListView(indent, pad, pad, padLeft, pad, spacing)

    view:SetElementFactory(function(factory, node)
        local elementData = node:GetData()

        if elementData.headerInfo then
            local function Initializer(button, node)
                button:Init(node)

                button:SetScript('OnClick', function(button, buttonName)
                    node:ToggleCollapsed()
                    button:SetCollapseState(node:IsCollapsed())

                    if elementData.configInfo then
                        self.selectionBehavior:Select(button)
                    end
                end)

                if elementData.configInfo then
                    local selected = self.selectionBehavior:IsElementDataSelected(node)
                    button:SetSelected(selected)
                end
            end

            factory('HironCraftScanConfigMenuHeaderTemplate', Initializer)
        elseif elementData.configInfo then
            local function Initializer(button, node)
                button:Init(node)
                elementData.configInfo.treeNode = node
                button:SetLabelFontColors(button:GetLabelColor())

                button:SetScript('OnClick', function(button, buttonName, down)
                    self.selectionBehavior:Select(button)
                end)

                local selected = self.selectionBehavior:IsElementDataSelected(node)
                button:SetSelected(selected)
            end

            factory('HironCraftScanConfigMenuItemTemplate', Initializer)
        elseif elementData.recipeInfo then
        else
            factory('Frame')
        end
    end)

    view:SetElementExtentCalculator(function(dataIndex, node)
        local elementData = node:GetData()
        local baseElementHeight = 20
        local categoryPadding = 5

        if elementData.configInfo then
            return baseElementHeight
        end

        if elementData.headerInfo then
            return baseElementHeight + categoryPadding
        end

        if elementData.dividerHeight then
            return elementData.dividerHeight
        end

        if elementData.topPadding then
            return 1
        end

        if elementData.bottomPadding then
            return 10
        end
    end)

    ScrollUtil.InitScrollBoxListWithScrollBar(self.ScrollBox, self.ScrollBar, view)
    ScrollUtil.AddManagedScrollBarVisibilityBehavior(self.ScrollBox, self.ScrollBar, nil, nil)

    local function OnSelectionChanged(o, elementData, selected)
        local button = self.ScrollBox:FindFrame(elementData)
        if button then
            button:SetSelected(selected)
        end

        if selected then
            local configInfo = elementData.data.configInfo
            if configInfo then
                if self.activeOptions then
                    self.activeOptions:Hide()
                end
                HironCraftScanConfigPage.Options:Hide()

                self.activeOptions =
                    configInfo.LoadOptions(configInfo, HironCraftScanConfigPage.isMenuCollapsed)
                HironCraftScan.Events:Emit('ACTIVE_OPTION_UPDATED', self.activeOptions)
                self.activeOptions:Show()
                --HironCraftScanConfigPage.Options:SetScrollChild(self.activeOptions)
                HironCraftScanConfigPage.Options:Show()
            end
        end
    end

    self.selectionBehavior = ScrollUtil.AddSelectionBehavior(self.ScrollBox)
    self.selectionBehavior:RegisterCallback(
        SelectionBehaviorMixin.Event.OnSelectionChanged,
        OnSelectionChanged,
        self
    )

    -- Some legacy code in RecipeSchematicMenu reads in full professions the
    -- first time a profession window is open. There is a
    -- 'TRADESKILL_LIST_UPDATE' event, but it can change constantly based
    -- on sorting while the profession window is open, so don't want to rely on
    -- it. This event should allow us to move recipes from Unlearned over to
    -- Pending as they are learned.
    self:RegisterEvent('NEW_RECIPE_LEARNED')
    self:RegisterEvent('TRADE_SKILL_ITEM_CRAFTED_RESULT')
    self:RegisterEvent('TRADE_SKILL_DATA_SOURCE_CHANGED')
    self:SetScript('OnEvent', function(self, event, ...)
        if event == 'NEW_RECIPE_LEARNED' then
            local recipeID, recipeLevel, baseRecipeID = ...

            if issecretvalue(recipeID) then
                return
            end

            local profInfo = C_TradeSkillUI.GetProfessionInfoByRecipeID(recipeID)
            if
                not profInfo.isPrimaryProfession
                or not profInfo.parentProfessionID
                or not HironCraftScan.DB.characters[char]
            then
                return
            end
            local char = HironCraftScan.GetPlayerName(true)
            local profConfig = HironCraftScan.DB.characters[char].professions[profInfo.professionID]
            if profConfig then
                local recipeConfig = profConfig.recipes[recipeID]
                if recipeConfig then
                    recipeConfig.scan_state = HironCraftScan.CONST.RECIPE_STATES.PENDING_REVIEW
                    HironCraftScan.Config.UpdateProfession(char, profInfo.professionID, profConfig)
                end

                -- else, just trained a new profession and need to open it to ScanAllRecipes
            end
        elseif event == 'TRADE_SKILL_ITEM_CRAFTED_RESULT' then
            local resultData = ...
            if resultData.concentrationSpent and resultData.concentrationSpent ~= 0 then
                HironCraftScan.Events:Emit('CONCENTRATION_UPDATED')
            end
        elseif event == 'TRADE_SKILL_DATA_SOURCE_CHANGED' then
            HironCraftScan.Events:Emit('TRADESKILL_OPENED')
        end
    end)
end

local function OnConfigChange(configInfo)
    -- We used to attempt to keep a clean database here and only reference
    -- scanning enabled recipes. With the new cross-character functionality, we
    -- store all recipes of all known professions all the time so that we can
    -- easily pre-configure items we will learn and reference items from other
    -- crafters.
    if configInfo then
        HironCraftScanComm:ShareCharacterModification(
            configInfo.char,
            configInfo.profConfig.parentProfID
        )
    end

    -- TODO - Need to replicate tags

    HironCraftScan.Scanner.LoadConfig()
end

HironCraftScan.Config = {}
HironCraftScan.Config.OnConfigChange = OnConfigChange

function HironCraftScanConfigMenuMixin:OnMenuInitialized()
    if self.onMenuInitialized then
        self.onMenuInitialized()
        self.onMenuInitialized = nil
    end
end

function HironCraftScanConfigMenuMixin:OnShow()
    self:InitMenu()
end

function HironCraftScanConfigMenuMixin:InitMenu()
    if menuInitialized then
        self:OnMenuInitialized()
        return
    end

    menuInitialized = true

    local dataProvider = CreateTreeDataProvider()
    self.dataProvider = dataProvider

    local node = dataProvider:GetRootNode()

    local generalNode = node:Insert({
        order = 0,
        configInfo = {
            label = L('General'),
            LoadOptions = HironCraftScan.Config.LoadGlobalConfigOptions,
        },
    })

    node:Insert({
        order = 1,
        configInfo = {
            label = L('dialog.tag.header'),
            LoadOptions = HironCraftScan.Config.LoadSubstitutionTagConfigOptions,
        },
    })

    node:Insert({
        order = 2,
        configInfo = {
            label = L('Quick Replies'),
            LoadOptions = HironCraftScan.Config.LoadQuickReplyConfigOptions,
        },
    })

    -- Keep this between the fixed config entries and the profession sections.
    -- Current-expansion professions use order 3, and equal orders invoke the
    -- header comparator, which padding nodes intentionally do not implement.
    node:Insert({ order = 2.5, bottomPadding = true })

    local function CollapseTree()
        -- Processing startCollapsed in headerInfo's Init does not work, but this seems to.
        local excludeCollapsed = false
        dataProvider:ForEach(function(node)
            local elementData = node:GetData()

            -- Now that the full tree is populated, apply the sorter for a
            -- single n*log(n) sort instead of the original n*n*log(n) we got
            -- from applying the sorter before inserting children.
            if elementData.sorter ~= nil then
                if elementData.sorter then
                    SetSortComparator(node, elementData.sorter)
                else
                    SetSortComparator(node)
                end
                elementData.sorter = nil
            end
            if elementData.headerInfo and elementData.headerInfo.startCollapsed then
                node:SetCollapsed(true)

                -- The button is sometimes not initialized yet? Maybe elements that
                -- haven't been rendered haven't been init'ed yet?
                if elementData.headerInfo.button then
                    elementData.headerInfo.button:SetCollapseState(true)
                end
            end
        end, excludeCollapsed)
    end

    -- Wait until we have fully populated the tree to render it. Before
    -- rendering, we collapse almost all the nodes so we only display the
    -- current expansion's professions
    local waitGroup = HironCraftScan.WaitGroup(function()
        CollapseTree()
        SetSortComparator(node, SortByHeaderLabel)
        self.ScrollBox:SetDataProvider(dataProvider, ScrollBoxConstants.RetainScrollPosition)
        self.selectionBehavior:SelectElementData(generalNode)
        self.ScrollBox:ScrollToElementData(generalNode)
        self.Spinner:SetShown(false)
        self:OnMenuInitialized()
    end)

    local OnProfessionLoadComplete = function()
        waitGroup:Done()
    end

    self.Spinner:SetShown(true)
    self.GetRecipeParentNode, self.PopulateProfessionNode, self.UpdateProfessionNode, self.RemoveMissingProfessionNodes, self.ExpandToNode =
        MakeProfessionNodeFactory(node)
    for char, charConfig in pairs(HironCraftScan.DB.characters) do
        for profID, profConfig in pairs(charConfig.professions) do
            waitGroup:Add()
            self.PopulateProfessionNode(char, profID, profConfig, nil, OnProfessionLoadComplete)
        end
    end
    waitGroup:Close()
end

HironCraftScanConfigMenuHeaderMixin = {}

function HironCraftScanConfigMenuHeaderMixin:Init(node)
    local elementData = node:GetData()
    local headerInfo = elementData.headerInfo
    headerInfo.button = self
    if headerInfo.GetLabelColor then
        self.GetLabelColor = headerInfo.GetLabelColor
    else
        self.GetLabelColor = self.GetDefaultLabelColor
    end
    self.selectable = elementData.configInfo and true or false
    self.Label:SetText(headerInfo.label)
    self:SetLabelFontColors(self:GetLabelColor())

    self:SetCollapseState(node:IsCollapsed())
    self:SetSelected(false)
end

function HironCraftScanConfigMenuHeaderMixin:SetLabelFontColors(color)
    self.Label:SetVertexColor(color:GetRGB())
end

function HironCraftScanConfigMenuHeaderMixin:GetDefaultLabelColor()
    return CreateColor(GameFontNormal_NoShadow:GetTextColor())
end

function HironCraftScanConfigMenuHeaderMixin:OnEnter()
    self:SetLabelFontColors(HIGHLIGHT_FONT_COLOR)
    if not self.selectable then
        self.HighlightOverlay:SetShown(false)
    end
end

function HironCraftScanConfigMenuHeaderMixin:OnLeave()
    self:SetLabelFontColors(self:GetLabelColor())
end

function HironCraftScanConfigMenuHeaderMixin:SetCollapseState(collapsed)
    local atlas = collapsed and 'Professions-recipe-header-expand'
        or 'Professions-recipe-header-collapse'
    self.CollapseIcon:SetAtlas(atlas, TextureKitConstants.UseAtlasSize)
    self.CollapseIconAlphaAdd:SetAtlas(atlas, TextureKitConstants.UseAtlasSize)
end

function HironCraftScanConfigMenuHeaderMixin:SetSelected(selected)
    self.SelectedOverlay:SetShown(selected)
    self.HighlightOverlay:SetShown(not selected)
end

HironCraftScanConfigMenuItemMixin = {}

function HironCraftScanConfigMenuItemMixin:Init(node)
    local elementData = node:GetData()
    local configInfo = elementData.configInfo
    self.Label:SetText(configInfo.label)

    if configInfo.recipeConfig then
        self.enabled = configInfo.recipeConfig.scan_state ~= HironCraftScan.CONST.RECIPE_STATES.UNLEARNED
    else
        self.enabled = true
    end
end

function HironCraftScanConfigMenuItemMixin:SetLabelFontColors(color)
    self.Label:SetVertexColor(color:GetRGB())
end

function HironCraftScanConfigMenuItemMixin:OnEnter()
    self:SetLabelFontColors(HIGHLIGHT_FONT_COLOR)
end

function HironCraftScanConfigMenuItemMixin:GetLabelColor()
    if self.data and self.data.headerInfo and self.data.headerInfo.GetLabelColor then
        return self.data.headerInfo.GetLabelColor()
    end
    return self.enabled and PROFESSION_RECIPE_COLOR or DISABLED_FONT_COLOR
end

function HironCraftScanConfigMenuItemMixin:OnLeave()
    self:SetLabelFontColors(self:GetLabelColor())
end

function HironCraftScanConfigMenuItemMixin:SetSelected(selected)
    self.SelectedOverlay:SetShown(selected)
    self.HighlightOverlay:SetShown(not selected)
end

function HironCraftScan.Config.OnRecipeScanStateChange(configInfo, skipReload)
    -- If the tree hasn't initialized the configInfo yet, nothing to do.
    if not configInfo.treeNode then
        return
    end

    local menu = HironCraftScanConfigPage.Menu
    local newParent = menu.GetRecipeParentNode(
        configInfo.char,
        configInfo.profID,
        configInfo.profConfig,
        configInfo.recipeConfig
    )
    local oldParent = configInfo.treeNode:GetParent()
    newParent:MoveNode(configInfo.treeNode)
    EraseEmptyParents(oldParent)

    if not skipReload then
        -- TreeNodeMixin:InsertNode does invalidate prior to sort, so the node shows up
        -- at the end of the list. Fire off another Invalidate() so it shows in the
        -- right spot immediately.
        newParent:Invalidate()

        -- Update the Options panel based on the new state.
        menu.activeOptions = configInfo.LoadOptions(configInfo, HironCraftScanConfigPage.isMenuCollapsed)
        HironCraftScan.Events:Emit('ACTIVE_OPTION_UPDATED', menu.activeOptions)
    end

    HironCraftScan.Events:Emit('UPDATE_RECIPE_LABEL', configInfo.recipeID)
end

function HironCraftScan.Config.UpdateProfession(char, profID, profConfig)
    local menu = HironCraftScanConfigPage.Menu
    if menu.UpdateProfessionNode then
        menu.UpdateProfessionNode(char, profID, profConfig)
    end
end

function HironCraftScan.Config.RemoveMissingProfessionNodes(char)
    local menu = HironCraftScanConfigPage.Menu
    if menu.RemoveMissingProfessionNodes then
        menu.RemoveMissingProfessionNodes(char)
        if menu.activeOptions then
            -- Not perfect. There's no guarantee the user has a config page
            -- within the profession open, but this ensures we don't leave a
            -- dangling config page referencing a deleted recipeConfig.
            menu.activeOptions:Hide()
        end
    end
end
