local now=1000
time=function() return now end
local Scan={DB={settings={},customers={},listed_orders={}},Utils={onLoad=function() end}}
Scan.OrderToCustomerInfo=function(o) return Scan.DB.customers[o.customerName] end
Scan.OrderToResponse=function(o)
    local info=Scan.OrderToCustomerInfo(o)
    return info and info.responses[o.responseID]
end
assert(loadfile('ChatFilter/FilterEngine.lua'))('HironCraft',Scan)
assert(loadfile('Customer/RequestTracking.lua'))('HironCraft',Scan)
assert(loadfile('Customer/CustomerAttention.lua'))('HironCraft',Scan)
local A,M=Scan.CustomerAttention,Scan.RequestTracking
local groups={
    done={'dnoe','doen','dne','donne','doone'},
    listed={'litsed','litsted','lissted','listeed','listde','listedd'},
    ordered={'orderde','oredered','odrered','orderred','ordereed','orderedd'},
    placed={'palced','plcaed','plaecd','placde','placd','placedd','pleaced'},
    posted={'psoted','posetd','postde','postd','postedd'},
    submitted={'sumbitted','submtited','submittde','submtted','submittd','submmited','submittedd'},
    mailed={'mialed','mailde','maild'},
    delivered={'delivred','delievered','delviered','deliverd'},
    dispatched={'dispached','dispathced','dispatchd'},
    check={'cehck','chekc','chek','chec','chekk','checkk','checck','chcek'},
    incoming={'incomign','incomng','incomimg','incoiming','incominng'},
    onair={'oniar','onari','onairr'},
    order={'ordr','ordrer','odrer','oreder'},
    orders={'ordrs','ordrers','odrers','oreders','ordres'},
    ['отправил']={'оптравил','отпраивл','отправли','отправилл'},
    ['отправила']={'оптравила','отпраивла','отправлиа','отправилаа'},
    ['отправлено']={'отправелно','оптравлено','отпралено','отправленно'},
    ['кинул']={'киунл','кинлу'},
    ['скинул']={'скиунл','скинлу'},
    ['закинул']={'закиунл','закинлу'},
    ['заказал']={'закаазал','заказалл'},
}
local checks,variants=0,0
local function IsSent(message,expected)
    assert((A.Classify(message)=='sent')==expected,'unexpected typo classification: '..message)
    checks=checks+1
end
for canonical,words in pairs(groups) do
    local noun=canonical=='order' or canonical=='orders'
    for _,word in ipairs(words) do
        variants=variants+1
        local phrase=noun and word..' placed' or word
        for _,prefix in ipairs({'','ok, ','yep ','aight '}) do
            for _,suffix in ipairs({'','!',' ty',' thanks bro'}) do
                IsSent(prefix..phrase..suffix,true)
            end
        end
        IsSent(phrase:upper()..'!',true)
        for _,prefix in ipairs({'not ','not yet ','never ','I will ','I havent ',
            "I haven't ",'please ','where can I ','need '}) do
            IsSent(prefix..phrase,false)
        end
        for _,suffix in ipairs({'?',' later',' tomorrow',' after getting mats',' if I can',' but not yet',
            ' the mats',' on the AH'}) do
            IsSent(phrase..suffix,false)
        end
        -- Exact tokens, not fuzzy matching or a substring inside another word.
        IsSent('x'..phrase,false)
        IsSent(phrase..'xyz',false)
        IsSent('someone said '..phrase,false)
        if noun then IsSent(word,false) end
    end
end
for _,phrase in ipairs({'2 ordrs palced','the odrer has been sumbitted','both ordres are litsed',
    'chekc the ordr','cehck the ordres pls','I have just palced two ordres',
    'all dnoe','doen the order now','incomign rn','order incomng','oniar rn',
    'оптравил заказ','оптравила тебе','отправленно','закиунл заказ'}) do
    IsSent(phrase,true)
    IsSent(phrase..'?',false)
    IsSent('not '..phrase,false)
    IsSent(phrase..' after getting mats',false)
end
for _,phrase in ipairs({'dome','doe','don','one','list','order','orders','place','post','submit','mail',
    'chess','cheese','checking','checkpoint','displaced','reordered','unlisted','submittedness',
    'отравил','отравила','order mats','chekc price','chekc quality','chekc skill','chekc mats',
    'palced reagents','sumbitted a ticket','litsed on auction','orderde the mats',
    'dnoe buying mats','dnoe getting mats','dnoe gathering mats','please chekc the price',
    'can you palced it','I am not litsed','ordrs not palced','ordrs will be palced',
    'nearly dnoe','I will be dnoe','palced 2 orders not yet','не оптравил',
    'еще не оптравил','пока не оптравила заказ','оптравил позже','оптравил заказ если получится'}) do
    IsSent(phrase,false)
end
-- Do not normalize customer-defined keywords or crafter identities. Those
-- retain their exact spelling independently of acknowledgement aliases.
Scan.DB.settings.order_sent_keywords='palced marker'
IsSent('palced marker',true)
Scan.DB.settings.order_sent_keywords=nil
local crafter={crafterFullName='Palced-Realm'}
assert(A.Classify('log Palced',crafter)=='sent')
assert(A.Classify('log Placed',crafter)~='sent','typo normalization changed the requested crafter')
assert(A.Classify('log Palced',{crafterFullName='Placed-Realm'})~='sent',
    'a character name was fuzzy-matched to another crafter')
assert(A.Classify('log Palced')~='sent','an alias in a context-free name became a confirmation')
-- Real reply recording still uses the active inquiry only. Incoming typo
-- acknowledgements do not create rows/complete crafts or restart the reminder.
local active={responseID=1,requestToken='active',inquiryID='active',greeting_sent=true,time=now}
local old={responseID=2,requestToken='older',inquiryID='older',greeting_sent=true,time=now}
local info={responses={[1]=active,[2]=old},activeInquiryID='active',activeInquiryAt=now}
Scan.DB.customers['Buyer-Realm']=info
local order={customerName='Buyer-Realm',responseID=1}
Scan.DB.listed_orders.active=order
Scan.DB.listed_orders.older={customerName='Buyer-Realm',responseID=2}
A.Record(info,{body='Send to Lavu',receivedAt=now},false)
for _,body in ipairs({'palced','2 ordrs sumbitted','cehck the ordres pls','оптравил заказ'}) do
    now=now+1
    local entry={body=body,receivedAt=now}
    M.MarkReply(info,entry)
    assert(entry.body==body,'classification rewrote the original chat body')
    assert(active.customer_answered and A.State(order,active)=='sent' and A.KeepAlive(order,active))
    assert(not old.customer_answered and not old.customerState,'typo acknowledgement checked another inquiry')
    assert(active.firstAnsweredAt==1001,'later typo acknowledgements restarted the reminder')
end
assert(A.Collect(1060)==0 and A.Collect(1061)==1)
now=1005;A.Record(info,{body='omw',receivedAt=now},false)
assert(A.State(order,active)=='sent' and A.Collect(1064)==0 and A.Collect(1065)==1)
now=1006;M.MarkReply(info,{body='getting mats',receivedAt=now})
assert(A.State(order,active)=='waiting','normal waiting reply failed after a typo acknowledgement')
local rows=0
for _ in pairs(Scan.DB.listed_orders) do rows=rows+1 end
assert(rows==2 and Scan.OrderToResponse(order)==active,'typo acknowledgement altered scanner rows')
print('Customer typos passed ('..variants..' explicit variants, '..checks..
    ' classification checks, exact tokens/identities, active inquiry, original chat and reminder timing).')
