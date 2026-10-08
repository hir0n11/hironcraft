-- The compact form of an order's final mark: what goes in comes out, and a
-- mark with its completion notice is one addon message (255 bytes) on the
-- wire, with the real serializer and compressor.
strmatch = string.match
assert(loadfile('Workflow/Core/Libs/LibStub/LibStub.lua'))()
assert(loadfile('Libs/LibSerialize.lua'))()
assert(loadfile('Libs/LibDeflate.lua'))()
local Serialize, Deflate = LibStub('LibSerialize'), LibStub('LibDeflate')
local Scan = {}
assert(loadfile('Utils/OrderMarkCodec.lua'))('HironCraft', Scan)
local C = Scan.OrderMarkCodec

local me, peer, third = 'a6f90972-44b4-4044-8e9e-3cc681e3410c', 'bc3e77fc-2a95-4396-a3c3-b90db522c813',
    'fcd4d56a-02e6-4e08-8127-059f93b7c50c'
local function wire(packet)
    return Deflate:EncodeForWoWAddonChannel(Deflate:CompressDeflate(Serialize:Serialize(packet)))
end
local function unwire(text)
    local ok, packet = Serialize:Deserialize(Deflate:DecompressDeflate(Deflate:DecodeForWoWAddonChannel(text)))
    assert(ok, 'the packet does not come back from the wire')
    return packet
end
local function same(lhs, rhs, path)
    path = path or 'value'
    assert(type(lhs) == type(rhs), path .. ': ' .. type(lhs) .. ' became ' .. type(rhs))
    if type(lhs) ~= 'table' then
        assert(lhs == rhs, path .. ': ' .. tostring(lhs) .. ' became ' .. tostring(rhs))
        return
    end
    for key, value in pairs(lhs) do same(value, rhs[key], path .. '.' .. tostring(key)) end
    for key in pairs(rhs) do assert(lhs[key] ~= nil, path .. '.' .. tostring(key) .. ' appeared from nowhere') end
end

-- Account ids: a UUID is 16 bytes on the way, anything else is kept as it is.
assert(#C.PackID(me) == 17 and C.UnpackID(C.PackID(me)) == me, 'a UUID does not survive packing')
for _, odd in ipairs({ 'Crafter-Realm', 'A6F90972-44B4-4044-8E9E-3CC681E3410C', 'exactlysixteenchr', 'x' }) do
    assert(C.UnpackID(C.PackID(odd)) == odd, 'an id that is no UUID was changed: ' .. odd)
end
assert(C.PackID(nil) == nil and C.UnpackID(nil) == nil and C.UnpackID('x') == nil and C.UnpackID('\001short') == nil)

local function pair(customer, crafter, tokenOwner)
    local token = tokenOwner .. ':1791372327:147825.8237914:554:1230485'
    local status = { customerName = customer, responseID = 1230485, status = 'fulfilled', craftingOrderID = 1285127005,
        crafterFullName = crafter, updatedAt = 1791404468, clockOffset = -2, automatic = true, rev = 3, origin = me,
        requestToken = token, requestTime = 1791372327, result = 0 }
    local notice = { orderID = 1285127005, customerName = customer, customerGuid = 'Player-1305-0C1A2B3D', spellID = 1230485,
        itemID = 240949, parentProfessionID = 755, crafterFullName = crafter, updatedAt = 1791404469, clockOffset = -2,
        origin = me, status = 'fulfilled', requestToken = token, requestTime = 1791372327, tipAmount = 95000000,
        consortiumCut = 4750000 }
    return status, notice
end

-- A mark with its notice: back as it went, asking for its confirmation.
local status, notice = pair('Maeymagus', 'Lavu-Kazzak', me)
local packet = unwire(wire(C.EncodeMarks({ status }, { notice }, me, peer, 14)))
local kind, version, sender = C.Header(packet)
assert(kind == C.MARKS and version == 14 and sender == me, 'the head of the packet is wrong')
local statuses, notices = C.Decode(packet, peer)
assert(#statuses == 1 and #notices == 1)
status.deliveryPending, notice.deliveryPending = { [peer] = true }, { [peer] = true }
same(status, statuses[1], 'status')
same(notice, notices[1], 'notice')

-- One addon message: a usual pair, and one with long cross-realm names whose
-- request was made on a third account.
local usual = #wire(C.EncodeMarks({ status }, { notice }, me, peer, 14))
local longStatus, longNotice = pair('Executerogueman-Burning Legion', 'Leathloringer-Burning Legion', third)
local long = #wire(C.EncodeMarks({ longStatus }, { longNotice }, me, peer, 14))
assert(usual <= 200, 'a usual mark takes ' .. usual .. ' bytes')
assert(long <= 255, 'a mark with long names takes ' .. long .. ' bytes: two addon messages')
-- As named tables in the usual envelope the same pair is two messages or more.
local old = #wire({ operation = 'share_order_completion', version = 14, addon = '0.4.128', senderID = me,
    data = { statuses = { status }, recent = { notice } } })
assert(old > 255 and usual * 2 < old, 'the compact form is not what makes the difference: ' .. usual .. ' against ' .. old)

-- Whose request it was: the sender's, the receiver's, a third account's, or
-- a token of another shape; all come back as they were.
for _, owner in ipairs({ me, peer, third }) do
    local s = pair('Buyer', 'Crafter-Realm', owner)
    local back = C.Decode(unwire(wire(C.EncodeMarks({ s }, {}, me, peer, 14))), peer)
    assert(back[1].requestToken == s.requestToken, 'a request token changed on the way')
end
local odd = pair('Buyer', 'Crafter-Realm', me)
odd.requestToken = 'Buyer-Realm:general:17'
odd.origin = 'Crafter-Realm'
assert(C.Decode(unwire(wire(C.EncodeMarks({ odd }, {}, me, peer, 14))), peer)[1].requestToken == 'Buyer-Realm:general:17')
assert(C.Decode(unwire(wire(C.EncodeMarks({ odd }, {}, me, peer, 14))), peer)[1].origin == 'Crafter-Realm')

-- Every status, a row that is a slot or a general request, a mark set by
-- hand, and the fields that are not there.
for _, name in ipairs({ 'unknown', 'claimed', 'crafted', 'fulfilled', 'failed', 'rejected' }) do
    local bare = { customerName = 'Buyer-Realm', responseID = 'equipment:165:3', status = name, automatic = false, rev = 1,
        updatedAt = 5, answeredAt = 77 }
    local back = C.Decode(unwire(wire(C.EncodeMarks({ bare }, {}, 'source', 'receiver', 1))), 'receiver')[1]
    bare.deliveryPending = { receiver = true }
    same(bare, back, name)
end
local plain = { customerName = 'Buyer', updatedAt = 9, status = 'rejected', orderID = 'old:7' }
local backNotice = select(2, C.Decode(unwire(wire(C.EncodeMarks({}, { plain }, 'source', 'receiver', 1))), 'receiver'))[1]
plain.deliveryPending = { receiver = true }
same(plain, backNotice, 'bare notice')
local head = { C.Header(unwire(wire(C.EncodeMarks({}, {}, 'source', 'receiver', 1)))) }
assert(head[1] == C.MARKS and head[3] == 'source', 'an id that is no UUID is not carried')

-- The ACKs of both, one small message.
local statusAck = { customerName = 'Maeymagus', responseID = 1230485, origin = me, rev = 3, updatedAt = 1791404468 }
local noticeAck = { orderID = 1285127005, customerName = 'Maeymagus', spellID = 1230485, itemID = 240949, status = 'fulfilled',
    origin = me, updatedAt = 1791404469 }
local ackWire = wire(C.EncodeAcks({ statusAck }, { noticeAck }, peer, me, 14))
assert(#ackWire <= 120, 'the confirmation takes ' .. #ackWire .. ' bytes')
local ackPacket = unwire(ackWire)
local ackKind, _, ackSender = C.Header(ackPacket)
assert(ackKind == C.ACKS and ackSender == peer)
local statusAcks, noticeAcks = C.Decode(ackPacket, me)
same(statusAck, statusAcks[1], 'status ACK')
same(noticeAck, noticeAcks[1], 'notice ACK')

-- Junk is nobody's packet, and a broken entry is left out without the rest.
for _, junk in ipairs({ false, 'text', {}, { 3, 1, C.PackID(me) }, { C.MARKS, 1, 'x' }, { C.MARKS, 1 } }) do
    assert(C.Header(junk) == nil and C.Decode(junk, peer) == nil, 'junk was taken for a packet')
end
local broken = C.EncodeMarks({ status }, { notice }, me, peer, 14)
broken[4][2] = 'not a status'
broken[4][3] = { 'Buyer', 1, 99 }
broken[5][2] = { false, false, 1, 3 }
local keptStatuses, keptNotices = C.Decode(broken, peer)
assert(#keptStatuses == 1 and #keptNotices == 1, 'a broken entry was not left out alone')

print(string.format('Order mark codec passed (round trip, ids, tokens, every status, ACKs, junk; a mark is %d bytes, %d at its longest, %d before).',
    usual, long, old))
