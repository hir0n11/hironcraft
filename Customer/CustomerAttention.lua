-- Attention is independent of the second check: that check means a reply,
-- not that a crafting order has actually been sent.
local _, Scan = ...
local A = {}
Scan.CustomerAttention = A
local function Settings() return Scan.DB and Scan.DB.settings or {} end
local function Customer(name)
    local customers=Scan.DB and Scan.DB.customers or {}
    if customers[name] then return customers[name],name end
    local key=Scan.ChatIgnore and Scan.ChatIgnore.Key(name)
    if not key then return end
    local found,foundName
    for candidate,info in pairs(customers) do
        if Scan.ChatIgnore.Key(candidate)==key then
            if found then return end
            found,foundName=info,candidate
        end
    end
    return found,foundName
end
local function Requests(info)
    local result,seen={},{}
    for id,r in pairs(info.responses or {}) do
        if type(r)=='table' and type(r.requestToken)=='string' and not seen[r] and #result<64 then
            seen[r]=true;result[#result+1]={responseID=r.responseID or id,token=r.requestToken}
        end
    end
    return result
end
local function Lower(s)
    return Scan.FilterEngine and Scan.FilterEngine.Lower(s) or s:lower()
end
local function Plain(s)
    s = tostring(s or ''):gsub('|H.-|h(.-)|h', '%1'):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '')
    return Lower(s):gsub('’',"'"):gsub('[%p%c]', ' '):gsub('%s+', ' '):match('^%s*(.-)%s*$')
end
local SEND_WORDS = {'sent','send','sending','sendin','sended','sented','sendt','sendet',
    'senting','sendig','sendingg','sends','sned','sedn','snt','snd'}
local function SendContext(s,first,last)
    -- Accept broken English, but not a question, request or future intention.
    -- Inspect only the few words before the confirmation: "sent, not sure"
    -- is still a confirmation, unlike "not yet sent".
    local prefix=s:sub(1,first-1)
    local recent={}
    for word in prefix:gmatch('%S+') do
        recent[#recent+1]=word
        if #recent>4 then table.remove(recent,1) end
    end
    local before=' '..table.concat(recent,' ')..' '
    for _,word in ipairs({'not','never','havent','haven','hasnt','hasn','didnt','didn','dont','don',
        'isnt','isn','wasnt','wasn','werent','weren','arent','aren','wont','won',
        'couldnt','couldn','wouldnt','wouldn','shouldnt','shouldn',
        'cant','cannot','will','ll','gonna','can','could','should','would','shall','must','might','may'}) do
        if before:find(' '..word..' ',1,true) then return 'waiting' end
    end
    if before:match(' no%s*$') or before:match(' to%s*$') then return 'waiting' end
    for _,word in ipairs({'where','who','whom','which','what','when','how','please','pls','plz'}) do
        if before:find(' '..word..' ',1,true) then return 'attention' end
    end
    local after=' '..s:sub(last+1)
    if after:match('^%s*me%s') then return 'attention' end
    if s:sub(first,last):match('%S+')=='send'
        and (after:match('^%s*please%s*$') or after:match('^%s*pl[sz]%s*$')) then return 'attention' end
    for _,word in ipairs({'soon','later','tomorrow'}) do
        if after:find(' '..word..' ',1,true) then return 'waiting' end
    end
    for _,unit in ipairs({'sec','min','hour'}) do
        if after:find(' in%s+%d+%s*'..unit) or after:find(' in%s+a%s+'..unit)
            or after:find(' in%s+a%s+few%s+'..unit) then return 'waiting' end
    end
    return 'sent'
end
function A.Classify(message)
    local s = ' ' .. Plain(message) .. ' '
    -- Negative/future statements win over a bare "sent" or "send".
    for _, phrase in ipairs({'not sent', 'havent sent', 'haven t sent', 'didnt send', 'didn t send',
        'not send', 'will send', 'll send', 'going to send', 'can i send', 'should i send', 'be sent', 'getting mats',
        'gathering mats', 'buying mats', 'не отправ', 'не посла', 'отправлю', 'собираю', 'куплю', 'закупаю'}) do
        if s:find(phrase, 1, true) then return 'waiting' end
    end
    if tostring(message or ''):find('?', 1, true) then return 'attention' end
    local extra = Settings().order_sent_keywords or ''
    for _,word in ipairs(SEND_WORDS) do
        local first,last=s:find(' '..word..' ',1,true)
        if first then return SendContext(s,first,last) end
    end
    local words = {'отправил', 'отправила', 'отправлено', 'отослал', 'послал', 'послала'}
    for word in extra:gmatch('[^,\n]+') do words[#words+1] = Plain(word) end
    for _, word in ipairs(words) do
        if word ~= '' and s:find(' ' .. word .. ' ', 1, true) then return 'sent' end
    end
    return 'attention'
end
local function Stamp(entry)
    local at = tonumber(entry and entry.receivedAt)
    if not at or at ~= at or at < 1 or at > time() + 300 then return time() end
    return at
end
local function Members(info, entry)
    local context = entry and entry.replyContext
    local result = {}
    if type(context) == 'table' and type(context.members)=='table' then
        for index, member in ipairs(context.members) do
            if index>64 then break end
            if type(member)=='table' then
                local r = info.responses and info.responses[member.responseID]
                if r and r.requestToken == member.requestToken then result[r] = true end
            end
        end
    end
    return result
end
function A.Record(info, entry, incoming)
    if type(info) ~= 'table' or type(entry) ~= 'table' then return end
    local at = Stamp(entry)
    if not incoming then
        info.lastCrafterReplyAt = math.max(tonumber(info.lastCrafterReplyAt) or 0, at)
        return
    end
    local eligible = Members(info, entry)
    local classified = entry.customerState
    if classified~='sent' and classified~='waiting' and classified~='attention' then
        local text=entry.body or tostring(entry.message or ''):match(':%s+(.+)$') or entry.message
        classified=A.Classify(text)
    end
    local seen = {}
    for _, response in pairs(info.responses or {}) do
        if type(response) == 'table' and not seen[response] then
            seen[response] = true
            if response.customer_answered and (eligible[response] or response.attentionReturned) then
                local returned=response.attentionReturned
                response.attentionReturned = nil
                response.lastCustomerReplyAt=math.max(tonumber(response.lastCustomerReplyAt) or 0,at)
                response.firstAnsweredAt = returned and at or tonumber(response.firstAnsweredAt) or at
                if at >= (tonumber(response.customerStateAt) or 0) then
                    -- Small talk cannot undo a confirmed send. An explicit
                    -- return to getting materials, or a new request, can.
                    if classified ~= 'attention' or response.customerState ~= 'sent' then
                        response.customerState = classified
                    end
                    response.customerStateAt = at
                end
            end
        end
    end
end
function A.State(order, response)
    local f = Scan.OrderFulfillment
    local ok,entry=true,nil
    if f and f.GetStatus then ok,entry=pcall(f.GetStatus,f,order) end
    local status = ok and type(entry)=='table' and entry.status or nil
    if status == 'crafted' or status == 'fulfilled' or status == 'rejected' then return 'done' end
    if not response or not response.customer_answered then return nil end
    if status == 'claimed' then return 'sent' end
    return response.customerState or 'attention'
end
function A.SetState(order, state)
    if state ~= 'sent' and state ~= 'waiting' and state ~= 'attention' then return end
    local response = Scan.OrderToResponse(order)
    if not response then return end
    response.customerState, response.customerStateAt = state, time()
    A.Share(order, {state=state})
    if HironCraftScanCraftingOrderPage then HironCraftScanCraftingOrderPage:ShowGeneric() end
end
function A.Share(order, change)
    local response = order and Scan.OrderToResponse(order)
    if not response or type(response.requestToken) ~= 'string' then return end
    response.attentionRevision = (tonumber(response.attentionRevision) or 0) + 1
    local packet = {customer=order.customerName, responseID=order.responseID, token=response.requestToken,
        n=response.attentionRevision, by=Settings().my_uuid, at=time(), state=change.state, answered=change.answered,
        snooze=change.snooze,stateAt=change.state and response.customerStateAt or nil}
    response.attentionActor = packet.by
    response.attentionChangedAt = packet.at
    if not (Scan.BattleNet and Scan.BattleNet.IsCustomer(order.customerName))
        and HironCraftScanComm and HironCraftScanComm.ShareCustomerAttention then
        HironCraftScanComm:ShareCustomerAttention(packet)
    end
end
function A.Receive(data)
    if type(data)=='table' and Scan.BattleNet and Scan.BattleNet.IsCustomer(data.customer) then return false end
    if type(data)=='table' and data.reply==true then return A.ReceiveReply(data) end
    if type(data) ~= 'table' or type(data.customer) ~= 'string' or #data.customer<1 or #data.customer > 256
        or type(data.token) ~= 'string' or #data.token<1 or #data.token > 256
        or type(data.by) ~= 'string' or #data.by<1 or #data.by > 128
        or type(data.n) ~= 'number' or data.n ~= data.n or data.n < 1 or data.n > 1e12 or data.n % 1 ~= 0
        or type(data.at) ~= 'number' or data.at ~= data.at or data.at < 1 or data.at > time()+300
        or (data.state ~= nil and data.state ~= 'sent' and data.state ~= 'waiting' and data.state ~= 'attention')
        or (data.answered ~= nil and type(data.answered) ~= 'boolean') then return false end
    if (type(data.responseID)~='string' and type(data.responseID)~='number') or #tostring(data.responseID)>128 then return false end
    if type(data.responseID)=='number' and (data.responseID~=data.responseID or math.abs(data.responseID)>1e12) then return false end
    if data.stateAt~=nil and (type(data.stateAt)~='number' or data.stateAt~=data.stateAt or data.stateAt<1 or data.stateAt>time()+300) then return false end
    if data.snooze~=nil and (type(data.snooze)~='number' or data.snooze~=data.snooze or data.snooze<data.at
        or data.snooze>data.at+3600) then return false end
    local response = Scan.OrderToResponse({customerName=data.customer, responseID=data.responseID})
    if not response or response.requestToken ~= data.token then
        local s=Settings()
        s.customer_attention_pending=s.customer_attention_pending or {}
        local key=data.customer..'\030'..data.token
        local previous=s.customer_attention_pending[key]
        local count=0
        for _ in pairs(s.customer_attention_pending) do count=count+1 end
        if (previous or count<256) and (not previous or data.n>previous.n or (data.n==previous.n and data.by>previous.by)) then
            local clean={}
            for _,k in ipairs({'customer','responseID','token','by','n','at','state','stateAt','answered','snooze'}) do clean[k]=data[k] end
            s.customer_attention_pending[key]=clean
        end
        return false
    end
    local n = tonumber(response.attentionRevision) or 0
    if data.n < n or (data.n == n and data.by <= (response.attentionActor or '')) then return false end
    response.attentionRevision, response.attentionActor = data.n, data.by
    local stateAt=data.stateAt or data.at
    if data.state and stateAt >= (tonumber(response.customerStateAt) or 0) then
        response.customerState, response.customerStateAt = data.state, stateAt
    end
    response.attentionChangedAt=data.at
    if data.answered ~= nil and data.at >= (tonumber(response.lastCustomerReplyAt) or 0) then
        response.customer_answered, response.awaitingReturn = data.answered, not data.answered or nil
        response.answerResetAt = not data.answered and data.at or nil
        if data.answered then response.firstAnsweredAt = data.at end
    end
    if data.snooze then response.reminderSnoozeUntil=data.snooze end
    if HironCraftScanCraftingOrderPage then HironCraftScanCraftingOrderPage:ShowGeneric() end
    return true
end
function A.Snooze(order)
    local r=Scan.OrderToResponse(order)
    if not r then return end
    r.reminderSnoozeUntil=time()+300
    A.Share(order,{snooze=r.reminderSnoozeUntil})
end
function A.Snapshot()
    local result,sharedReplies = {},{}
    for _, order in pairs(Scan.DB and Scan.DB.listed_orders or {}) do
        local r = Scan.OrderToResponse(order)
        if r and r.attentionRevision and r.attentionActor and #result < 200
            and not (Scan.BattleNet and Scan.BattleNet.IsCustomer(order.customerName)) then
            result[#result+1] = {customer=order.customerName,responseID=order.responseID,token=r.requestToken,
                n=r.attentionRevision,by=r.attentionActor,at=r.attentionChangedAt or r.customerStateAt or r.firstAnsweredAt or time(),
                state=r.customerState,stateAt=r.customerStateAt,answered=r.customer_answered == true}
        end
        local info=Scan.OrderToCustomerInfo(order)
        local at=info and tonumber(info.lastCrafterReplyAt)
        if at and at>time()-86400 and not sharedReplies[order.customerName] and #result<200
            and not (Scan.BattleNet and Scan.BattleNet.IsCustomer(order.customerName)) then
            sharedReplies[order.customerName]=true
            result[#result+1]={reply=true,customer=order.customerName,at=at,requests=Requests(info)}
        end
    end
    return result
end
function A.ProcessPending()
    local pending=Settings().customer_attention_pending
    if type(pending)~='table' then return end
    for key,data in pairs(pending) do
        if data.reply then
            if A.ReceiveReply(data,true) or time()-data.at>86400 then pending[key]=nil end
        else
            local response=Scan.OrderToResponse({customerName=data.customer,responseID=data.responseID})
            if response and response.requestToken==data.token then A.Receive(data);pending[key]=nil
            elseif time()-data.at>86400 then pending[key]=nil end
        end
    end
end
function A.ReceiveReply(data,noQueue)
    if type(data)~='table' or type(data.customer)~='string' or #data.customer<1 or #data.customer>256
        or type(data.at)~='number' or data.at~=data.at or data.at<1 or data.at>time()+300
        or type(data.requests)~='table' or #data.requests<1 or #data.requests>64 then return false end
    if Scan.BattleNet and Scan.BattleNet.IsCustomer(data.customer) then return false end
    local info=Customer(data.customer)
    local matched=false
    for _,request in ipairs(data.requests) do
        if type(request)~='table' or type(request.token)~='string' or #request.token>256
            or (type(request.responseID)~='number' and type(request.responseID)~='string') then return false end
        if #tostring(request.responseID)>128 or (type(request.responseID)=='number'
            and (request.responseID~=request.responseID or math.abs(request.responseID)>1e12)) then return false end
        local r=info and info.responses and info.responses[request.responseID]
        if r and r.requestToken==request.token then matched=true end
    end
    if matched then
        info.lastCrafterReplyAt=math.max(tonumber(info.lastCrafterReplyAt) or 0,data.at)
        return true
    end
    if not noQueue then
        local s=Settings()
        s.customer_attention_pending=s.customer_attention_pending or {}
        local pending=s.customer_attention_pending
        local key=data.customer..'\030reply'
        local count=0
        for _ in pairs(pending) do count=count+1 end
        if (pending[key] or count<256) and (not pending[key] or data.at>pending[key].at) then
            pending[key]={reply=true,customer=data.customer,at=data.at,requests=data.requests}
        end
    end
    return false
end
function A.Outgoing(customer)
    local info,name=Customer(customer)
    if not info or not next(info.responses or {}) then return end
    local now=time()
    info.lastCrafterReplyAt=math.max(tonumber(info.lastCrafterReplyAt) or 0,now)
    if info.lastAttentionReplySharedAt==now then return end
    info.lastAttentionReplySharedAt=now
    -- A timing record, not private chat. This also works with scanning/proxy
    -- chat disabled on the crafting computer. BN conversations stay private.
    if not (Scan.BattleNet and Scan.BattleNet.IsCustomer(name)) and HironCraftScanComm and HironCraftScanComm.ShareCustomerAttention then
        HironCraftScanComm:ShareCustomerAttention({reply=true,customer=name,at=now,requests=Requests(info)})
    end
end
function A.KeepAlive(order,response)
    return response and response.customer_answered and A.State(order,response)~='done'
        and not (Scan.IsIgnored and Scan.IsIgnored(order.customerName))
end
function A.Collect(now)
    local due, oldest, seen = 0, 0, {}
    local settings = Settings()
    local delay = math.max(10, math.min(3600, tonumber(settings.customer_reminder_delay) or 60))
    for _, order in pairs(Scan.DB and Scan.DB.listed_orders or {}) do
        local response = Scan.OrderToResponse(order)
        if response and not seen[response] and response.customer_answered
            and (tonumber(response.reminderSnoozeUntil) or 0)<=now
            and not (Scan.IsIgnored and Scan.IsIgnored(order.customerName)) and A.State(order, response) ~= 'done' then
            seen[response] = true
            local info = Scan.OrderToCustomerInfo(order)
            -- Persist the fallback once: refreshing the UI must not restart it.
            response.firstAnsweredAt = tonumber(response.firstAnsweredAt) or now
            local requestAt=tonumber(response.time) or 0
            local replyAt=tonumber(info and info.lastCrafterReplyAt)
            -- A greeting may be minutes old when the customer first answers.
            -- Never ring immediately on activating (or reactivating) a row.
            local start=math.max(response.firstAnsweredAt,(replyAt and replyAt>=requestAt) and replyAt or 0)
            start = math.min(start, now)
            if now-start >= delay then due, oldest = due+1, math.max(oldest, now-start) end
        end
    end
    return due, oldest
end
function A.RemindersChanged()
    local s=Settings()
    s.customer_reminder_enabled_at=s.customer_reminders_enabled == true and time() or nil
end
function A.Tick()
    A.ProcessPending()
    local s = Settings()
    -- Explicit local role: never infer "laptop" from a character or account.
    if s.customer_reminders_enabled ~= true then return end
    local now = time()
    -- First enable/upgrade gets a full grace period, even with old checked rows.
    local enabledAt=tonumber(s.customer_reminder_enabled_at)
    if not enabledAt or enabledAt>now then enabledAt=now;s.customer_reminder_enabled_at=now end
    local delay=math.max(10,math.min(3600,tonumber(s.customer_reminder_delay) or 60))
    if now-enabledAt<delay then return end
    local count = A.Collect(now)
    if count == 0 then return end
    local interval = math.max(10, math.min(3600, tonumber(s.customer_reminder_interval) or 60))
    local previous = tonumber(s.customer_reminder_last) or 0
    if previous > now then previous = 0 end
    if now-previous < interval then return end
    if Scan.Notifications and Scan.Notifications.Alert('reminder') then s.customer_reminder_last = now end
end
if CreateFrame then
    local outgoing=CreateFrame('Frame')
    outgoing:RegisterEvent('CHAT_MSG_WHISPER_INFORM')
    outgoing:RegisterEvent('CHAT_MSG_BN_WHISPER_INFORM')
    outgoing:SetScript('OnEvent',function(_,event,_,customer,...)
        if event=='CHAT_MSG_BN_WHISPER_INFORM' then
            customer=Scan.BattleNet and Scan.BattleNet.FromID(select(11,...))
        end
        if customer then A.Outgoing(customer) end
    end)
end
if Scan.Utils and Scan.Utils.onLoad then
    Scan.Utils.onLoad(function()
        if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(5, A.Tick) end
    end)
end
