-- Load the real scanner/page/settings with a small WoW boundary mock. Broken
-- saved rows must not prevent login, right-click dismissal or later UI setup.
local function noop() end
local Scan
local function loadSource(path)
    local root = arg[1] and (arg[1] .. '/') or ''
    return assert(loadfile(root .. path))('HironCraft', Scan)
end
local frames, errors, queued = {}, {}, {}
Scan = {
    CONST = {
        TEXT = setmetatable({}, { __index = function(_, key) return key end }),
        DEFAULT_SETTINGS = { customer_timeout = 5 },
        MIDNIGHT_PROFESSION_ICONS = {}, PARENT_PROFESSION_ICONS = {},
    },
    LOCAL = { GetText = function(_, key) return key end },
    Events = { Register = noop, Emit = noop },
    Debug = { Print = noop },
    NotifyRecentChanges = noop,
}
function CreateFrame(_, name)
    local frame = { scripts = {}, events = {} }
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    function frame:GetScript(event) return self.scripts[event] end
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    frames[#frames + 1] = frame
    return frame
end
function CreateFromMixins(...) return {} end
EnumUtil = { MakeEnum = function(...) local e = {}; for i, k in ipairs({...}) do e[k] = i end; return e end }
function UnitName() return 'Crafter' end
function GetRealmName() return 'TestRealm' end
function GetAutoCompleteRealms() return {} end
function GetProfessions() return nil end
function time() return 1000 end
bit = { bxor = function() return 0 end, band = function() return 0 end }
StaticPopupDialogs, UISpecialFrames, UIPanelWindows = {}, {}, {}
C_TradeSkillUI = { IsNearProfessionSpellFocus = function() return false end }
C_Timer = { After = noop }
function geterrorhandler() return function(err) errors[#errors + 1] = err end end
local loggedIn = false
function IsLoggedIn() return loggedIn end
C_AddOns = { IsAddOnLoaded = function() return true, true end }
HironCraftScanComm = { ShareCharacterData = noop }

loadSource('Utils/Utils.lua')
local realOnLoad = Scan.Utils.onLoad
Scan.Utils.onLoad = function(fn) queued[#queued + 1] = fn end
loadSource('Customer/ChatScanner.lua')
loadSource('Customer/OrderPage.lua')
Scan.DB = { customers = {}, listed_orders = {}, settings = { customer_timeout = 5 } }
Scan.State = {}
local refreshes, closed = 0, 0
HironCraftScanCraftingOrderPage = { ShowGeneric = function() refreshes = refreshes + 1 end }
HironCraftScanScannerMenu = { ClearAlert = noop }
function FCF_Close() closed = closed + 1 end

local orphan = { customerName = 'Missing', responseID = 1 }
assert(Scan.OrderToResponse(orphan) == nil, 'missing customer must not throw')
assert(Scan.OrderToResponse(false) == nil, 'malformed saved row must not throw')
Scan.DB.customers.Bad = { responses = false }
assert(Scan.OrderToResponse({customerName='Bad', responseID=1}) == nil)
Scan.DB.listed_orders['Missing-1'] = orphan
Scan.State.activeOrder = orphan
Scan.CONST.PROFESSIONS = { { professionID=164, icon=42 } }
assert(Scan.Utils.GetCurrentProfessionIcon() == 42, 'stale alert must fall back to a profession icon')
Scan.GreetCustomer('RightButton', orphan)
assert(Scan.DB.listed_orders['Missing-1'] == nil and Scan.State.activeOrder == nil)
assert(refreshes == 1, 'stale right-click must still refresh the list')

local function addOrder(customer, id, response)
    local info = Scan.DB.customers[customer] or { responses = {}, chat_history = {'keep history'} }
    Scan.DB.customers[customer] = info
    info.responses[id] = response
    local order = { customerName = customer, responseID = id }
    Scan.DB.listed_orders[Scan.OrderToOrderID(order)] = order
    return order, info
end
local first, customer = addOrder('Buyer', 123, { time=999, responseID=123, less_granular={164} })
-- SavedVariables may deserialize an alias as a separate table.
customer.responses[164] = { time=999, responseID=123 }
local second = addOrder('Buyer', 456, { time=999, responseID=456 })
customer.responses.stray = false
Scan.DismissOrder(first)
assert(customer.responses[123] == nil and customer.responses[164] == nil)
assert(customer.responses[456] and Scan.DB.listed_orders['Buyer-456'] == second)
assert(customer.chat_history[1] == 'keep history')
customer.responses.stray = nil
Scan.LIVE.customers.Buyer = { chatFrame = {} }
Scan.DismissOrder(second)
assert(Scan.DB.customers.Buyer == nil and closed == 1)
Scan.DismissOrder(second) -- Repeated dismissal / expiry of an already removed alias.
assert(closed == 1)

local old, info = addOrder('Reused', 123, {time=998, responseID=123, less_granular={164}})
local replacement = {time=999, responseID=164}
info.responses[164] = replacement
Scan.DismissOrder(old)
assert(info.responses[164] == replacement, 'old alias must not delete a newer request')

-- Exercise the real page initializer, whose purge previously aborted the
-- remaining login callbacks on a dangling reference.
Scan.DB.customers = {}
Scan.DB.listed_orders = { ['Missing-1']=orphan, malformed=false }
addOrder('NoTime', 1, {})
addOrder('Expired', 1, {time=1})
local keep, keepInfo = addOrder('Healthy', 1, {time=999})
Scan.DB.listed_orders.noResponseID = {customerName='Healthy'}
local realm = { customers=Scan.DB.customers, listed_orders=Scan.DB.listed_orders, characters={} }
HironCraftScan_DB = { realms={TestRealm=realm}, settings={customer_timeout=5, alert_icon_scale=123} }
local button = { SetButtonText=noop, Init=noop }
HironCraftScanCraftingOrderPage.EnableMouse = noop
HironCraftScanCraftingOrderPage.BrowseFrame = {
    AddonToggleButton=button, AutoReplyButton=button, CustomExplanationsButton=button,
    LeftPanel={LinkedAccountList=button},
}
local hooked = 0
ProfessionsFrame = { HookScript = function() hooked = hooked + 1 end }
Scan.Utils.onLoad = realOnLoad
realOnLoad(queued[#queued]) -- OrderPage.lua's own startup callback.
realOnLoad(function() error('injected UI initializer failure') end)
local later = 0
realOnLoad(function() later = later + 1 end)

-- Simulate an original CraftScan already owning its Settings identifiers.
local registered = {}
local category = { GetID = function() return 17 end }
local initializer = { AddSearchTags=noop }
local function registerSetting(_, variable)
    assert(variable:match('^HIRONCRAFT_SCAN_'), 'shared CraftScan setting ID: ' .. variable)
    assert(not registered[variable], 'duplicate setting ID: ' .. variable)
    registered[variable] = true
    return { SetValueChangedCallback=noop }
end
local registeredCategory, openedCategory
Settings = {
    RegisterVerticalLayoutCategory=function() return category, {} end,
    RegisterAddOnSetting=registerSetting, RegisterProxySetting=registerSetting,
    CreateDropdown=function() return initializer end,
    CreateSlider=function() return initializer end,
    CreateCheckbox=function() return initializer end,
    CreateSliderOptions=function() return {SetLabelFormatter=noop} end,
    CreateControlInitializer=function() return {data={setting={}}, AddSearchTags=noop} end,
    RegisterAddOnCategory=function(value) registeredCategory=value end,
    OpenToCategory=function(value) openedCategory=value end,
    VarType={Boolean='boolean', String='string'}, Default={False=false},
}
SettingsPanel = { GetLayout=function() return {AddInitializer=noop} end }
MinimalSliderWithSteppersMixin = {Label={Right=1}}
Scan.CONST.AUTO_REPLIES_SUPPORTED = true -- Also verify the optional setting.
loadSource('Settings/Settings.lua')
local login = frames[1]
loggedIn = true
login:GetScript('OnEvent')(login, 'PLAYER_LOGIN')
assert(hooked == 1, 'stale rows interrupted the page initializer')
assert(later == 1, 'one failed initializer blocked later modules')
assert(#errors == 1 and errors[1]:find('injected UI initializer failure', 1, true), table.concat(errors, '\n'))
assert(not login.events.PLAYER_LOGIN and not login:GetScript('OnEvent'))
assert(Scan.DB.listed_orders['Healthy-1'] == keep and Scan.DB.customers.Healthy == keepInfo)
assert(Scan.DB.listed_orders['Missing-1'] == nil and Scan.DB.listed_orders.malformed == nil)
assert(Scan.DB.listed_orders.noResponseID == nil, 'malformed row without responseID was not removed')
assert(Scan.DB.listed_orders['NoTime-1'] == nil and Scan.DB.listed_orders['Expired-1'] == nil)
assert(Scan.DB.settings.alert_icon_scale == 123 and keepInfo.chat_history[1] == 'keep history')
assert(registeredCategory == category, 'settings category did not finish registration')
Scan.Settings:Open()
assert(openedCategory == 17)
realOnLoad(function() later = later + 1 end)
assert(later == 2, 'late registration after PLAYER_LOGIN was not initialized')
print('Scanner recovery tests passed (stale rows, dismissal, login isolation, settings namespaces).')
