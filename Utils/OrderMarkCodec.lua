local HironCraftScan = select(2, ...)

-- The final mark of a crafting order as one addon message.
--
-- A mark is a status of the order's row and, with it, the completion notice
-- of the order. As tables with named fields, in the envelope every packet
-- has, the pair is about 500 bytes on the wire: two or three addon messages
-- of the 255 bytes each may carry, on a channel the server limits to about
-- one message a second. Written by position instead, with what both halves
-- share sent once (LibSerialize refers back to a string it has already
-- written) and account ids packed to their 16 bytes, the pair is about 170
-- bytes: one message.
--
-- This file only turns marks and their ACKs into such packets and back.
-- Utils/Comm.lua sends them on a prefix of their own, to a linked account
-- that says it understands them.
local C = {}
HironCraftScan.OrderMarkCodec = C

C.MARKS, C.ACKS = 1, 2

local STATUS_CODES = { unknown = 0, claimed = 1, crafted = 2, fulfilled = 3, failed = 4, rejected = 5 }
local STATUS_NAMES = {}
for name, code in pairs(STATUS_CODES) do STATUS_NAMES[code] = name end

-- An account id is a UUID: 36 letters, 16 bytes. Anything else is kept as it is.
local UUID = '^(%x%x%x%x%x%x%x%x)%-(%x%x%x%x)%-(%x%x%x%x)%-(%x%x%x%x)%-(%x%x%x%x%x%x%x%x%x%x%x%x)$'
local function PackID(id)
    if type(id) ~= 'string' then return nil end
    local a, b, c, d, e = id:match(UUID)
    if not a or id ~= id:lower() then return '\002' .. id end
    return '\001' .. ((a .. b .. c .. d .. e):gsub('%x%x', function(pair) return string.char(tonumber(pair, 16)) end))
end
local function UnpackID(packed)
    if type(packed) ~= 'string' or #packed < 2 then return nil end
    local kind, body = packed:sub(1, 1), packed:sub(2)
    if kind == '\002' then return body end
    if kind ~= '\001' or #body ~= 16 then return nil end
    local hex = body:gsub('.', function(char) return string.format('%02x', char:byte()) end)
    return hex:sub(1, 8) .. '-' .. hex:sub(9, 12) .. '-' .. hex:sub(13, 16) .. '-' .. hex:sub(17, 20) .. '-' .. hex:sub(21, 32)
end
C.PackID, C.UnpackID = PackID, UnpackID

-- An id inside a packet is mostly the sender's own or the receiver's: 1 and 2.
local function Who(id, sender, receiver)
    if id == nil then return false end
    if id == sender then return 1 end
    if id == receiver then return 2 end
    return PackID(id) or false
end
local function WhoBack(value, sender, receiver)
    if value == 1 then return sender end
    if value == 2 then return receiver end
    return UnpackID(value)
end

-- A request token starts with the id of the account that made the request.
local function PackToken(token, sender, receiver)
    if type(token) ~= 'string' then return false end
    local owner, rest = token:match('^(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x):(.*)$')
    if not owner or owner ~= owner:lower() then return token end
    return { Who(owner, sender, receiver), rest }
end
local function UnpackToken(value, sender, receiver)
    if type(value) == 'string' then return value end
    if type(value) ~= 'table' or type(value[2]) ~= 'string' then return nil end
    local owner = WhoBack(value[1], sender, receiver)
    return owner and (owner .. ':' .. value[2]) or nil
end

-- nil cannot sit in the middle of a list: false stands for it, and what a
-- list ends with is left off.
local function Dense(values, count)
    local last = 0
    for index = 1, count do
        if values[index] == nil then values[index] = false end
        if values[index] ~= false then last = index end
    end
    for index = last + 1, count do values[index] = nil end
    return values
end
local function Value(value)
    if value == false then return nil end
    return value
end

local function PackStatus(entry, sender, receiver)
    return Dense({
        entry.customerName,
        entry.responseID,
        STATUS_CODES[entry.status],
        entry.rev,
        entry.updatedAt,
        entry.automatic == false and 0 or 1,
        PackToken(entry.requestToken, sender, receiver),
        entry.requestTime,
        entry.clockOffset,
        entry.craftingOrderID,
        entry.crafterFullName,
        Who(entry.origin, sender, receiver),
        entry.result,
        entry.answeredAt,
    }, 14)
end
local function UnpackStatus(packed, sender, receiver)
    if type(packed) ~= 'table' then return nil end
    local status = STATUS_NAMES[packed[3]]
    if not status or type(packed[1]) ~= 'string' then return nil end
    return {
        customerName = packed[1],
        responseID = Value(packed[2]),
        status = status,
        rev = Value(packed[4]),
        updatedAt = Value(packed[5]),
        automatic = packed[6] ~= 0,
        requestToken = UnpackToken(Value(packed[7]), sender, receiver),
        requestTime = Value(packed[8]),
        clockOffset = Value(packed[9]),
        craftingOrderID = Value(packed[10]),
        crafterFullName = Value(packed[11]),
        origin = WhoBack(Value(packed[12]), sender, receiver),
        result = Value(packed[13]),
        answeredAt = Value(packed[14]),
        -- A mark on this channel always asks to be confirmed.
        deliveryPending = { [receiver] = true },
    }
end

local function PackNotice(notice, sender, receiver)
    return Dense({
        notice.customerName,
        notice.customerGuid,
        notice.updatedAt,
        STATUS_CODES[notice.status or 'fulfilled'],
        notice.orderID,
        notice.spellID,
        notice.itemID,
        notice.parentProfessionID,
        notice.crafterFullName,
        Who(notice.origin, sender, receiver),
        PackToken(notice.requestToken, sender, receiver),
        notice.requestTime,
        notice.clockOffset,
        notice.tipAmount,
        notice.consortiumCut,
    }, 15)
end
local function UnpackNotice(packed, sender, receiver)
    if type(packed) ~= 'table' then return nil end
    local status = STATUS_NAMES[packed[4]]
    if not status or type(packed[1]) ~= 'string' then return nil end
    return {
        customerName = packed[1],
        customerGuid = Value(packed[2]),
        updatedAt = Value(packed[3]),
        status = status,
        orderID = Value(packed[5]),
        spellID = Value(packed[6]),
        itemID = Value(packed[7]),
        parentProfessionID = Value(packed[8]),
        crafterFullName = Value(packed[9]),
        origin = WhoBack(Value(packed[10]), sender, receiver),
        requestToken = UnpackToken(Value(packed[11]), sender, receiver),
        requestTime = Value(packed[12]),
        clockOffset = Value(packed[13]),
        tipAmount = Value(packed[14]),
        consortiumCut = Value(packed[15]),
        deliveryPending = { [receiver] = true },
    }
end

local function PackStatusAck(ack, sender, receiver)
    return Dense({ ack.customerName, ack.responseID, Who(ack.origin, sender, receiver), ack.rev, ack.updatedAt }, 5)
end
local function UnpackStatusAck(packed, sender, receiver)
    if type(packed) ~= 'table' or type(packed[1]) ~= 'string' then return nil end
    return { customerName = packed[1], responseID = Value(packed[2]), origin = WhoBack(Value(packed[3]), sender, receiver),
        rev = Value(packed[4]), updatedAt = Value(packed[5]) }
end
local function PackNoticeAck(ack, sender, receiver)
    return Dense({ ack.orderID, ack.customerName, ack.spellID, ack.itemID, STATUS_CODES[ack.status or 'fulfilled'],
        Who(ack.origin, sender, receiver), ack.updatedAt }, 7)
end
local function UnpackNoticeAck(packed, sender, receiver)
    if type(packed) ~= 'table' or type(packed[2]) ~= 'string' then return nil end
    return { orderID = Value(packed[1]), customerName = packed[2], spellID = Value(packed[3]), itemID = Value(packed[4]),
        status = STATUS_NAMES[packed[5]], origin = WhoBack(Value(packed[6]), sender, receiver), updatedAt = Value(packed[7]) }
end

local function PackAll(list, pack, sender, receiver)
    local packed = {}
    for _, entry in ipairs(list or {}) do
        if type(entry) == 'table' and type(entry.customerName) == 'string' then
            packed[#packed + 1] = pack(entry, sender, receiver)
        end
    end
    return packed
end
local function UnpackAll(list, unpack, sender, receiver)
    local entries = {}
    for _, packed in ipairs(type(list) == 'table' and list or {}) do
        local entry = unpack(packed, sender, receiver)
        if entry then entries[#entries + 1] = entry end
    end
    return entries
end

-- { kind, protocol version, sender, statuses, notices }
function C.EncodeMarks(statuses, notices, sender, receiver, version)
    return { C.MARKS, version, PackID(sender), PackAll(statuses, PackStatus, sender, receiver),
        PackAll(notices, PackNotice, sender, receiver) }
end
function C.EncodeAcks(statuses, notices, sender, receiver, version)
    return { C.ACKS, version, PackID(sender), PackAll(statuses, PackStatusAck, sender, receiver),
        PackAll(notices, PackNoticeAck, sender, receiver) }
end

-- What a packet is, before anything in it is believed: its kind, its
-- protocol version and who says they sent it.
function C.Header(packet)
    if type(packet) ~= 'table' then return nil end
    local kind, sender = packet[1], UnpackID(packet[3])
    if (kind ~= C.MARKS and kind ~= C.ACKS) or not sender then return nil end
    return kind, packet[2], sender
end

-- The statuses and notices (or their ACKs) of a packet, as the tables the
-- rest of the addon works with.
function C.Decode(packet, receiver)
    local kind, _, sender = C.Header(packet)
    if not kind then return nil end
    if kind == C.MARKS then
        return UnpackAll(packet[4], UnpackStatus, sender, receiver), UnpackAll(packet[5], UnpackNotice, sender, receiver)
    end
    return UnpackAll(packet[4], UnpackStatusAck, sender, receiver), UnpackAll(packet[5], UnpackNoticeAck, sender, receiver)
end
