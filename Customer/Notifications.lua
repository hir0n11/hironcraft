-- Built-in kits and bundled alert sounds; no media addon required.
local _, Scan = ...
local N = {}
Scan.Notifications = N
local function L(s) return Scan.LOCAL:GetText(s) end
local function Setting(key, fallback)
    local settings = Scan.DB and Scan.DB.settings
    if settings and settings[key] ~= nil then return settings[key] end
    return fallback
end
N.sounds = {
    { 'kit:ALARM_CLOCK_WARNING_3', 'Bell' },
    { 'kit:AUCTION_WINDOW_CLOSE', 'Auction bell' },
    { 'kit:IG_MAINMENU_OPTION_CHECKBOX_ON', 'Soft click' },
    { 'kit:TELL_MESSAGE', 'Whisper' },
    { 'Interface\\AddOns\\HironCraft\\Media\\WhisperAlert.ogg', 'WhisperAlert' },
}
local soundSettings = { 'ping_sound', 'whisper_alert_sound', 'personal_order_sound', 'quick_reply_sound', 'customer_reminder_sound' }
local aliases = { ['interface\\addons\\whisperalert\\wisp.ogg'] = N.sounds[5][1] }
local durations, volumeFiles = {}, {}
volumeFiles[N.sounds[5][1]] = true
local mediaRoot = 'Interface\\AddOns\\HironCraft\\Media\\SharedMedia\\Sounds\\'
for _, sound in ipairs(Scan.BundledAlertSounds or {}) do
    local file, label, duration = sound[1], sound[2], sound[3]
    local value = tonumber(file) and file or (mediaRoot .. file)
    N.sounds[#N.sounds+1] = { value, label }
    durations[value] = duration
    if not tonumber(file) then volumeFiles[value] = true end
    if not tonumber(file) then
        aliases[('Interface\\AddOns\\WeakAuras_SharedMedia\\Sounds\\' .. file):lower()] = value
    end
end
function N.ResolveSound(value)
    if value == nil then return nil end
    return aliases[tostring(value):lower()] or value
end
local lease, changing, generation, last = nil, false, 0, {}
local restoreAt
local lastAlert
local function Restore()
    local previous = lease
    lease = nil
    restoreAt = nil
    for key, value in pairs(previous or {}) do
        if GetCVar(key) == '1' then
            changing = true
            SetCVar(key, value)
            changing = false
        end
    end
end
function N.Volume(kind)
    local value=tonumber(Setting(kind .. '_volume',100)) or 100
    if value~=value then value=100 end
    return math.max(0,math.min(100,math.floor(value/10+0.5)*10))
end
function N.SupportsVolume(value)
    value=N.ResolveSound(value)
    return tostring(value):match('^kit:') ~= nil or volumeFiles[value] == true
end
function N.Play(value, preview, volume)
    value = N.ResolveSound(value)
    if not value or value == 'none' or value == '1' then return false end
    volume=tonumber(volume) or 100
    if volume~=volume then volume=100 end
    volume=math.max(0,math.min(100,math.floor(volume/10+0.5)*10))
    if volume==0 then return false end
    local original=value
    if volume<100 and volumeFiles[value] then
        local relative=value:match('^Interface\\AddOns\\HironCraft\\Media\\(.+)$')
        value='Interface\\AddOns\\HironCraft\\Media\\AlertVolume\\'..volume..'\\'..relative:gsub('%.mp3$','.ogg')
    end
    local force = Setting('alert_sound_when_muted', true)
    if force and GetCVar and SetCVar then
        lease = lease or {}
        for _, key in ipairs({ 'Sound_EnableAllSound', 'Sound_EnableSoundWhenGameIsInBG' }) do
            local previous = GetCVar(key)
            if previous == '0' then
                if lease[key] == nil then lease[key] = previous end
                changing = true
                SetCVar(key, '1')
                changing = false
            end
        end
        generation = generation + 1
        local token = generation
        -- Longer SharedMedia clips must finish before temporarily unmuted
        -- audio is restored. A later short alert must not cut one off either.
        local deadline = GetTime() + math.max(2, (durations[tostring(original)] or 0) + 0.25)
        restoreAt = math.max(restoreAt or 0, deadline)
        C_Timer.After(restoreAt - GetTime(), function()
            if generation == token then Restore() end
        end)
    end
    local kit = tostring(value):match('^kit:(.+)$')
    if kit then
        local id = SOUNDKIT and SOUNDKIT[kit]
        if id then return PlaySound(id, 'Master', false, false, nil, volume/100) end
        -- Older clients without a newer chime retain a short built-in alert.
        return PlaySound(SOUNDKIT.TELL_MESSAGE, 'Master', false, false, nil, volume/100)
    end
    return PlaySoundFile(tonumber(value) or value, 'Master')
end
function N.Alert(kind, customer)
    if customer and Scan.IsIgnored and Scan.IsIgnored(customer) then return false end
    if kind=='whisper' and customer and Scan.CustomerPreferences and Scan.CustomerPreferences.IsMuted(customer) then return false end
    local now = GetTime()
    if last[kind] and now - last[kind] < 0.8 then return end
    local values = {
        scanner = Setting('ping_sound', 'kit:TELL_MESSAGE'),
        whisper = Setting('whisper_alert_sound', 'kit:TELL_MESSAGE'),
        order = Setting('personal_order_sound', 'kit:AUCTION_WINDOW_CLOSE'),
        quick_reply = Setting('quick_reply_sound', 'kit:IG_MAINMENU_OPTION_CHECKBOX_ON'),
        reminder = Setting('customer_reminder_sound', 'kit:ALARM_CLOCK_WARNING_3'),
    }
    if not values[kind] then return false end
    if kind == 'whisper' and not Setting('whisper_alert_enabled', true) then return end
    if kind == 'order' and not Setting('personal_order_sound_enabled', true) then return end
    if kind == 'scanner' and not Setting('scanner_sound_enabled',true) then return false end
    if kind == 'quick_reply' and not Setting('quick_reply_sound_enabled',true) then return false end
    if N.Volume(kind)==0 then return false end
    -- A whisper that also creates a scanner row must not play two alerts.
    -- A quick-reply suggestion is a distinct alert. Do not swallow it merely
    -- because the whisper that caused it just played its own sound.
    if kind~='quick_reply' and kind~='reminder' and lastAlert and now - lastAlert < 0.15 then return false end
    if values[kind] == 'none' or values[kind] == '1' then return end
    local played=N.Play(values[kind], false, N.Volume(kind))
    if played then
        last[kind]=now
        if kind~='quick_reply' and kind~='reminder' then lastAlert=now end
    end
    return played
end
local suggestions, suggestionOrder = {}, {}
function N.QuickReply(option)
    local key=table.concat({tostring(option.customer),tostring(option.templateKey or option.action),
        tostring(option.requestToken),tostring(option.responseID),tostring(option.message),tostring(option.reply)},'\030')
    local now=GetTime()
    if suggestions[key] and now-suggestions[key]<60 then return false end
    if not suggestions[key] then suggestionOrder[#suggestionOrder+1]=key end
    suggestions[key]=now
    if #suggestionOrder>256 then suggestions[table.remove(suggestionOrder,1)]=nil end
    return N.Alert('quick_reply',option.customer)
end
function N.GetOptions()
    local container = Settings.CreateControlTextContainer()
    local found = {}
    local function Add(value, label)
        value = N.ResolveSound(value)
        value = tostring(value)
        if value~='none' and not N.SupportsVolume(value) then label=label..' ('..L('Original volume only')..')' end
        if not found[value] then container:Add(value, label); found[value] = true end
    end
    Add('none', L('No sound'))
    for _, sound in ipairs(N.sounds) do Add(sound[1], L(sound[2])) end
    local lsm = LibStub and LibStub('LibSharedMedia-3.0', true)
    if lsm then
        for _, name in ipairs(lsm:List('sound')) do
            Add(lsm:Fetch('sound', name), name)
        end
    end
    -- Keep an existing external selection visible even after removing its library.
    for _, key in ipairs(soundSettings) do
        local value = Setting(key)
        if value then Add(value, L('Saved sound') .. ': ' .. tostring(value)) end
    end
    return container:GetData()
end
local f = CreateFrame('Frame')
for _, event in ipairs({ 'CHAT_MSG_WHISPER', 'CHAT_MSG_BN_WHISPER', 'CVAR_UPDATE', 'PLAYER_LOGOUT', 'PLAYER_LOGIN' }) do
    f:RegisterEvent(event)
end
f:SetScript('OnEvent', function(_, event, name, sender, ...)
    if event == 'PLAYER_LOGOUT' then Restore()
    elseif event == 'CVAR_UPDATE' then
        if lease and not changing then
            -- Do not undo a user's sound changes made during the alert.
            for key in pairs(lease) do
                if tostring(name):lower() == key:lower() and GetCVar(key) ~= '1' then lease[key] = nil end
            end
        end
    elseif event == 'PLAYER_LOGIN' then
        local settings = Scan.DB and Scan.DB.settings
        for _, key in ipairs(soundSettings) do
            if settings and settings[key] ~= nil then settings[key] = N.ResolveSound(settings[key]) end
        end
        -- Do not disable another addon behind the user's back. It already owns
        -- these events: yield the whisper sound only, and explain how to switch.
        N.externalWhisper = C_AddOns and C_AddOns.IsAddOnLoaded('WhisperAlert')
        if N.externalWhisper and Setting('whisper_alert_enabled', true) then
            print('HironCraft: ' .. L('Disable WhisperAlert to use the built-in whisper sound.'))
        end
    elseif not N.externalWhisper then
        local customer=sender
        if event=='CHAT_MSG_BN_WHISPER' and Scan.BattleNet then
            customer=Scan.BattleNet.FromID(select(11,...))
        end
        if customer and Scan.ChatIgnore and Scan.ChatIgnore.IsIgnored(customer) then
            Scan.ChatIgnore.Attempt(customer)
            return
        end
        N.Alert('whisper',customer)
    end
end)
