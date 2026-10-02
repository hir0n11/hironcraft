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
local soundSettings = { 'ping_sound', 'whisper_alert_sound', 'personal_order_sound' }
local aliases = { ['interface\\addons\\whisperalert\\wisp.ogg'] = N.sounds[5][1] }
local durations = {}
local mediaRoot = 'Interface\\AddOns\\HironCraft\\Media\\SharedMedia\\Sounds\\'
for _, sound in ipairs(Scan.BundledAlertSounds or {}) do
    local file, label, duration = sound[1], sound[2], sound[3]
    local value = tonumber(file) and file or (mediaRoot .. file)
    N.sounds[#N.sounds+1] = { value, label }
    durations[value] = duration
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
function N.Play(value, preview)
    value = N.ResolveSound(value)
    if not value or value == 'none' or value == '1' then return false end
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
        local deadline = GetTime() + math.max(2, (durations[tostring(value)] or 0) + 0.25)
        restoreAt = math.max(restoreAt or 0, deadline)
        C_Timer.After(restoreAt - GetTime(), function()
            if generation == token then Restore() end
        end)
    end
    local kit = tostring(value):match('^kit:(.+)$')
    if kit then
        local id = SOUNDKIT and SOUNDKIT[kit]
        if id then return PlaySound(id, 'Master') end
        -- Older clients without a newer chime retain a short built-in alert.
        return PlaySound(SOUNDKIT.TELL_MESSAGE, 'Master')
    end
    return PlaySoundFile(tonumber(value) or value, 'Master')
end
function N.Alert(kind)
    local now = GetTime()
    if last[kind] and now - last[kind] < 0.8 then return end
    local values = {
        scanner = Setting('ping_sound', 'kit:TELL_MESSAGE'),
        whisper = Setting('whisper_alert_sound', 'kit:TELL_MESSAGE'),
        order = Setting('personal_order_sound', 'kit:AUCTION_WINDOW_CLOSE'),
    }
    if kind == 'whisper' and not Setting('whisper_alert_enabled', true) then return end
    if kind == 'order' and not Setting('personal_order_sound_enabled', true) then return end
    -- A whisper that also creates a scanner row must not play two alerts.
    if lastAlert and now - lastAlert < 0.15 then return end
    if values[kind] == 'none' or values[kind] == '1' then return end
    last[kind], lastAlert = now, now
    N.Play(values[kind])
end
function N.GetOptions()
    local container = Settings.CreateControlTextContainer()
    local found = {}
    local function Add(value, label)
        value = N.ResolveSound(value)
        value = tostring(value)
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
f:SetScript('OnEvent', function(_, event, name)
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
    elseif not N.externalWhisper then N.Alert('whisper') end
end)
