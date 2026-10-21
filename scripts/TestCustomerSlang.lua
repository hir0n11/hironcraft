time=function() return 1000 end
local Scan={DB={settings={},customers={},listed_orders={}},Utils={onLoad=function() end}}
assert(loadfile('ChatFilter/FilterEngine.lua'))('HironCraft',Scan)
assert(loadfile('Customer/CustomerAttention.lua'))('HironCraft',Scan)
local A=Scan.CustomerAttention
local positives={'on air','onair','in the air','inc','incoming','incomming','incomin','otw',
    'inc rn','incoming now','otw to u','order inc','order incoming','on its way','on the way',
    "it's on the way",'its on the way','order up',"order's up",'order is up',"it's up",'its up',
    'it is there',"it's in",'order is in','put it up','put the order up','should be there now',
    'u should have it now','posted','posted it','submitted the order','submited it rn',
    'placed the order now','I posted it','I have just submitted the order',"I've placed it already",
    'mailed it','delivered the order','dispatched it','sentit','sendit','sntit','sndit','sendedit','donezo',
    'snet','sennt','sentt','senttt','sendd','senddd','snding','sendng','donee','doneee',
    'senidng','sendign','sedning','sendnig',
    'кинул','закинула заказ','скинул тебе','уже оформил заказ','отправляю заказ','заказ у тебя',
    'order placed','order submitted','the order has been posted','it has been submitted',
    'order is posted','order is on the way','its otw',"it's inc",'on its way to you','on the air rn',
    'in ur orders','check your orders',
    'listed','listing','listin','listng','listd','lstd','lsted','lsited','lisetd','listted','listet',
    'order listed','the order has been listed',"it's listed",'listed it rn',
    'I listed the order','listed for you','listed the order for u',
    "I'm listing it now",'im listing the order','I am listing it',
    'put the order in','put an order in','put order in','put in the order','put in an order','put order up',
    'just put the order in',"I've put in the order",'in your order list','on ur order list',
    "it's in your crafting orders",
    'ordered','orderd','ordred','ordrd','orded','odered','ordering','orderin','orderng',
    'I ordered it',"I've ordered the order",'ordered it rn','ordered for you','order done',
    'made the order','made an order',"I've made an order",'created the order','created an order',
    'order created','order is created','заказал','заказала','заказано',
    'check','CHECK','chk','chck','check now','check rn','check pls','check plz','check please',
    'check it','check it now','check order','check the order','check orders','check the order pls',
    '2 order placed','2 orders placed','12 orders placed','two orders placed','both orders placed',
    'orders placed','the orders have been placed','2 crafting orders are listed',
    'I have just placed 2 orders','placed two orders now','submitted both orders for you',
    'the two orders are up','both orders created','all orders submitted','an order placed'}
local checks=0
for _,message in ipairs(positives) do
    for _,prefix in ipairs({'','ok, ','aight ','yep '}) do
        for _,suffix in ipairs({'','!',' ty',' thanks bro'}) do
            local sample=prefix..message..suffix
            assert(A.Classify(sample)=='sent','missed customer slang: '..sample)
            checks=checks+1
        end
    end
    for _,prefix in ipairs({'not ','not yet ','I will ','I havent ','please ','where can I '}) do
        local sample=prefix..message
        assert(A.Classify(sample)~='sent','negative/request became sent: '..sample)
        checks=checks+1
    end
    for _,suffix in ipairs({'?',' later',' tomorrow',' after getting mats',' if I can',' but not yet'}) do
        local sample=message..suffix
        assert(A.Classify(sample)~='sent','future/question became sent: '..sample)
        checks=checks+1
    end
end
for _,message in ipairs({'+','++',' + ','\t++\t','+ +','|cff00ff00+|r'}) do
    assert(A.Classify(message)=='sent','standalone plus confirmation was missed: '..message)
    checks=checks+1
end
for _,message in ipairs({'',' ','?','+?','++?','?+','not +','no +','+ not yet',
    '+1','+30','r5+','t5+','25k+','skill +10','1+1','2 + 2','++ later','ok +',
    'getting mats +','+ sent?','+++','--','-','Buyer: +'}) do
    assert(A.Classify(message)~='sent','non-confirmation became a plus acknowledgement: '..message)
    checks=checks+1
end
for _,prefix in ipairs({"I'll send ",'imma send ','ima send ','gonna send ',"I'm gonna send ",
    'im gonna send ','I am going to send ','going to send '}) do
    for _,tail in ipairs({'rn','it rn','the order rn','now','it right now','order rightnow'}) do
        local sample=prefix..tail
        assert(A.Classify(sample)=='sent',sample)
        assert(A.Classify(sample..'?')~='sent',sample..'?')
        assert(A.Classify(sample..' after getting mats')~='sent',sample..' after getting mats')
        assert(A.Classify(sample..' if I can')~='sent',sample..' if I can')
        checks=checks+4
    end
end
for _,message in ipairs({'omw','on my way','on my way to the table','otw to the bench','ready','rdy','all set',
    'okay','yes','sure','ty','np','getting mats','buying mats','posted the price','posted on discord',
    'please post it','can you submit it','how do I place the order','incoming?',
    'almost donee','nearly doneee','log','logging off','login failed','combat log','my log is on air',
    'imma send later','gonna send tomorrow','ima send soon','sentences','postmaster',
    'list','list it','my list','on the list','listings','blacklisted','unlisted',
    'listed the mats','listing materials','listed the recipe','listed on the AH','I listed it on auction',
    'can you list it','please list the order','I will be listing it','I am not listing it',
    'I am listing it later','listed after buying mats','listed if you can do it','put the order in?',
    'put the order in later','did you put the order in','do not put the order in',
    'order','orders','preordered','unordered','ordered?', 'not ordered','not yet ordered',
    'I will order it','I am not ordering it','ordered the mats','ordered reagents','ordered on the AH',
    'ordered the recipe','ordered from Amazon','made a list','created a character',
    'please create the order','did you make an order','created the order if I can',
    'check?','can you check','check price','price check','check quality','check skill','check r5',
    'check +10','check mats','check the materials','check the link','check this','please check quality',
    'check if I can send','check after getting mats','I will check','not check','check tomorrow',
    'checking','checks','checker','checklist','unchecked',
    '2 order placed?','not 2 orders placed','2 orders not placed','2 orders have not been placed',
    '2 orders will be placed','2 orders to be placed','need 2 orders placed','can you place 2 orders',
    'placed 2 orders later','placed 2 orders if I can','2 orders placed after buying mats',
    '0 orders placed','zero orders placed','no orders placed','placed 0 orders',
    '2 mats placed','placed two mats','2 orders listed on the AH','placed 2 orders on auction',
    'placed 2 orders it','2 orders','two orders','the orders',
    'senidngly','resenidng','unsenidng','sendigner'}) do
    assert(A.Classify(message)~='sent','ambiguous/unrelated message turned green: '..message)
    checks=checks+1
end
Scan.DB.settings.order_sent_keywords='booked, загружено, placed'
for _,message in ipairs({'booked','загружено','placed'}) do assert(A.Classify(message)=='sent',message) end
for _,message in ipairs({'not booked','I will booked','booked later','please booked',
    'не загружено','буду загружено','загружено позже','not placed','placed if I can',
    'almost sent','nearly sentt','почти отправил'}) do
    assert(A.Classify(message)~='sent','custom phrase bypassed confirmation guards: '..message)
    checks=checks+1
end
local lavu={crafterFullName='Lavu-Silvermoon',requestToken='lavu-job',responseID=1,customer_answered=true}
local vamo={crafterFullName='Vamo-Silvermoon',requestToken='vamo-job',responseID=2,customer_answered=true}
for _,message in ipairs({'log lavu','LOG LAVU!', 'log on Lavu','login Lavu','relog to Lavu',
    'hop on Lavu','switch to Lavu','swap to Lavu','pls log Lavu','log lavu pls',
    'can u log Lavu?','could you log Lavu now?','log Lavu-Silvermoon','зайди на Lavu',
    'u can log lavu','can ya hop on Lavu?','would u switch to Lavu pls?',
    'could u relog to Lavu?','log in on Lavu','login on Lavu','log Lavu asap'}) do
    assert(A.Classify(message,lavu)=='sent','crafter login request was missed: '..message)
    assert(A.Classify(message,vamo)~='sent','login request coloured another crafter: '..message)
    assert(A.Classify(message)~='sent','context-free login request coloured every active row: '..message)
    checks=checks+3
end
for _,message in ipairs({'dont log lavu','do not log lavu','log lavu later','I will log lavu',
    'log lavu after getting mats','log someoneelse','log lavu if possible','log lavutwo',
    'log Lavu-Otherrealm','do you know lavu','log file lavu'}) do
    assert(A.Classify(message,lavu)~='sent','invalid crafter login request became green: '..message)
    checks=checks+1
end
-- Both screenshots through the actual state recorder, including a synced
-- generic attention classification and a multi-crafter active inquiry.
local info={responses={[1]=lavu,[2]=vamo}}
local context={members={{responseID=1,requestToken='lavu-job'},{responseID=2,requestToken='vamo-job'}}}
A.Record(info,{body='on air',receivedAt=1000,replyContext=context},true)
assert(lavu.customerState=='sent' and vamo.customerState=='sent')
lavu.customerState='attention';vamo.customerState='attention'
A.Record(info,{body='listed',receivedAt=1000,replyContext=context},true)
assert(lavu.customerState=='sent' and vamo.customerState=='sent','screenshot listed did not turn the active inquiry green')
A.Record(info,{body='omw',receivedAt=1000},false)
assert(lavu.customerState=='sent' and vamo.customerState=='sent' and info.lastCrafterReplyAt==1000,
    'outgoing omw changed the customer state or failed to update the reminder reply clock')
lavu.customerState='attention';vamo.customerState='attention'
A.Record(info,{body='You choose the price',receivedAt=1000},false)
A.Record(info,{body='ordered',receivedAt=1000,replyContext=context},true)
assert(lavu.customerState=='sent' and vamo.customerState=='sent' and A.State({},lavu)=='sent',
    'screenshot ordered did not confirm the order or was treated as a completed craft')
assert(info.lastCrafterReplyAt==1000 and lavu.firstAnsweredAt==1000,'ordered changed the reminder start time')
lavu.customerState='attention';vamo.customerState='attention'
A.Record(info,{message='Makinguhappy: log lavu',customerState='attention',receivedAt=1001,replyContext=context},true)
assert(lavu.customerState=='sent' and vamo.customerState=='attention','login request did not stay crafter-specific')
assert(lavu.customer_answered and lavu.firstAnsweredAt==1000,'login request changed the answer/reminder clock')
A.Record(info,{body='log lavu',customerState='attention',receivedAt=999,replyContext=context},true)
assert(lavu.customerStateAt==1001,'delayed login request rolled back the state')
Scan.OrderFulfillment={GetStatus=function() return {status='crafted'} end}
assert(A.State({},lavu)=='done','login request reopened a completed craft')
print('Customer slang passed ('..checks..' classification checks, both screenshot scenarios, crafter-specific login requests, chronology and completed-order protection).')
