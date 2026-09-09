local Scan = select(2, ...)
local M = {}
Scan.CharacterRenames = M

local function Copy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}; seen[value] = result
    for key, child in pairs(value) do result[key] = Copy(child, seen) end
    return result
end

local function Records(storage)
    local value = storage and storage.settings and storage.settings.character_renames
    return type(value) == 'table' and value or {}
end

local function Valid(from, record)
    return type(from) == 'string' and #from <= 128 and from:find('-', 1, true)
        and type(record) == 'table' and type(record.to) == 'string'
        and #record.to <= 128 and record.to:find('-', 1, true) and record.to ~= from
        and type(record.sourceID) == 'string' and record.sourceID ~= ''
end

local function ResolveIn(name, records, activeOnly)
    local seen = {}
    while type(name) == 'string' and Valid(name, records[name])
        and (not activeOnly or records[name].active == true) do
        if seen[name] then return nil end
        seen[name] = true; name = records[name].to
    end
    return name
end

function M.Resolve(name, storage)
    return ResolveIn(name, Records(storage or HironCraftScan_DB), true) or name
end

-- Existing monitored recipes/keywords win over a freshly discovered new-name
-- profile. New-only recipes/settings are retained as well.
local function Merge(old, new)
    local result = Copy(new or {})
    for key, value in pairs(old) do
        if type(value) == 'table' and type(result[key]) == 'table' then
            result[key] = Merge(value, result[key])
        else result[key] = Copy(value) end
    end
    return result
end

local function RewriteText(text, full, short)
    if type(text) ~= 'string' then return text end
    local function Plain(part)
        return (part:gsub('[%w_][%w_%-]*', function(word)
            return full[word] or short[word] or word
        end))
    end
    local pieces, position = {}, 1
    while true do
        local first, last = text:find('|H[^|]*|h.-|h', position)
        if not first then pieces[#pieces+1] = Plain(text:sub(position)); break end
        pieces[#pieces+1] = Plain(text:sub(position, first-1))
        pieces[#pieces+1] = text:sub(first,last)
        position = last+1
    end
    return table.concat(pieces)
end

local function RewriteEditable(node, full, short, seen)
    if type(node) ~= 'table' then return false end
    seen = seen or {}; if seen[node] then return false end; seen[node] = true
    local changed = false
    for key, value in pairs(node) do
        if type(value) == 'string' then
            local replacement = RewriteText(value,full,short)
            if replacement ~= value then node[key] = replacement; changed = true end
        elseif type(value) == 'table' and RewriteEditable(value,full,short,seen) then
            changed = true
        end
    end
    return changed
end

-- Late configuration packets may still contain a literal pre-rename name.
function M.NormalizeEditable(config, storage)
    local full, short = {}, {}
    for from, record in pairs(Records(storage or HironCraftScan_DB)) do
        if Valid(from, record) and record.active == true then
            local target = M.Resolve(from, storage)
            full[from] = target
            local before, after = from:match('^([^-]+)'), target:match('^([^-]+)')
            if short[before] ~= nil and short[before] ~= after then short[before] = false
            else short[before] = after end
        end
    end
    if next(full) and RewriteEditable(config, full, short) and type(config.rev) == 'number' then
        config.rev = config.rev + 1
    end
end

local function RewriteReferences(node, full, short, seen)
    if type(node) ~= 'table' or seen[node] then return end
    seen[node] = true
    local original = node.crafterFullName
    if full[original] then
        -- Keep legacy journal keys stable when the old crafter name was the
        -- fallback identity used in place of an account UUID.
        if node.orderID and node.status and not node.origin then node.origin = original end
        node.crafterFullName = full[original]
        if node.crafterName == original then node.crafterName = full[original]
        elseif node.crafterName == original:match('^([^-]+)') then
            node.crafterName = full[original]:match('^([^-]+)')
        end
    end
    for _, key in ipairs({'conversationCharacter','last_active_char','character'}) do
        if full[node[key]] then node[key] = full[node[key]] end
    end
    for _, key in ipairs({'backup_chars'}) do
        if type(node[key]) == 'table' then
            local names, dedup = {}, {}
            for _, name in ipairs(node[key]) do
                name = full[name] or name
                if not dedup[name] then names[#names+1] = name; dedup[name] = true end
            end
            node[key] = names
        end
    end
    for key, child in pairs(node) do
        if key ~= 'character_renames' and key ~= 'character_rename_backups' then
            -- History text and request tokens are deliberately never rewritten.
            RewriteReferences(child,full,short,seen)
        end
    end
end

function M.Apply(storage)
    if type(storage) ~= 'table' or type(storage.settings) ~= 'table' then return 0, {} end
    local records, full, short, errors = Records(storage), {}, {}, {}
    local moved = 0
    for from, record in pairs(records) do
        if Valid(from,record) then
            local target = ResolveIn(from,records,false)
            local conflict = not target
            for _, realm in pairs(storage.realms or {}) do
                for _, name in ipairs({from,target or from}) do
                    local profile = realm.characters and realm.characters[name]
                    if profile and profile.sourceID and profile.sourceID ~= record.sourceID then conflict = true end
                end
            end
            if conflict then
                record.active = nil
                errors[#errors+1] = from
            else
                for realmID, realm in pairs(storage.realms or {}) do
                    local chars = realm.characters
                    local old, new = chars and chars[from], chars and chars[target]
                    if type(old) == 'table' then
                        local backups = storage.settings.character_rename_backups or {}
                        storage.settings.character_rename_backups = backups
                        backups[realmID] = backups[realmID] or {}
                        backups[realmID][from] = backups[realmID][from] or {
                            to=target, old=Copy(old), previousTarget=Copy(new),
                        }
                        local merged = Merge(old,new)
                        merged.sourceID = record.sourceID
                        for id, parent in pairs(merged.parent_professions or {}) do
                            local nextParent = new and new.parent_professions and new.parent_professions[id]
                            parent.rev = math.max(tonumber(parent.rev) or 0, tonumber(nextParent and nextParent.rev) or 0)+1
                        end
                        for id, profession in pairs(merged.professions or {}) do
                            local fresh = new and new.professions and new.professions[id]
                            if fresh and fresh.concentration then profession.concentration = Copy(fresh.concentration) end
                        end
                        chars[target], chars[from] = merged, nil
                        moved = moved+1
                    end
                end
                record.active = true
                full[from] = target
                local before, after = from:match('^([^-]+)'), target:match('^([^-]+)')
                if short[before] ~= nil and short[before] ~= after then short[before] = false
                else short[before] = after end
            end
        end
    end
    if not next(full) then return moved, errors end
    RewriteReferences(storage,full,short,{})
    for _, key in ipairs({'greeting','explanations','quick_replies','substitution_tags'}) do
        local editable = storage.settings[key]
        if RewriteEditable(editable,full,short) and type(editable.rev) == 'number' then editable.rev = editable.rev+1 end
    end
    for _, realm in pairs(storage.realms or {}) do
        for _, profile in pairs(realm.characters or {}) do
            local function UpdateGreetings(node)
                for key, value in pairs(node) do
                    if key == 'greeting' and type(value) == 'string' then node[key] = RewriteText(value,full,short)
                    elseif type(value) == 'table' then UpdateGreetings(value) end
                end
            end
            UpdateGreetings(profile)
        end
    end
    return moved, errors
end

function M.ExportOwn(storage)
    storage = storage or HironCraftScan_DB
    local result = {}
    for from, record in pairs(Records(storage)) do
        if Valid(from,record) and record.active and record.sourceID == storage.settings.my_uuid then
            result[from] = {to=record.to,sourceID=record.sourceID}
        end
    end
    return next(result) and result or nil
end

function M.AcceptRemote(storage, records, senderID)
    if type(records) ~= 'table' or type(senderID) ~= 'string' or not storage or not storage.settings then return end
    local aliases = Records(storage)
    storage.settings.character_renames = aliases
    for from, record in pairs(records) do
        if Valid(from,record) and record.sourceID == senderID then
            local existing = aliases[from]
            -- Renames are immutable; conflicting mappings need manual review.
            if not existing or (type(existing) == 'table' and existing.to == record.to and existing.sourceID == senderID) then
                aliases[from] = existing or Copy(record)
            end
        end
    end
    return M.Apply(storage)
end

function M.FilterIncomingCharacters(characters, storage)
    if type(characters) ~= 'table' then return characters end
    local result = {}
    for name, profile in pairs(characters) do
        -- A remembered rename is a tombstone for the old profile, not an
        -- invitation to let stale old-name packets overwrite the new one.
        local record = Records(storage or HironCraftScan_DB)[name]
        if M.Resolve(name,storage) == name
            or (type(profile) == 'table' and profile.sourceID and record and profile.sourceID ~= record.sourceID) then
            result[name] = profile
        end
    end
    return result
end
