local now=1000
function time() return now end
local Scan={}
assert(loadfile('Customer/RequestTracking.lua'))('HironCraft',Scan)
local M=Scan.RequestTracking
local info={responses={}}
local function add(id,at,fresh,entry)
    local response={responseID=id,requestToken='request-'..id..'-'..at,time=at}
    info.responses[id]=response
    M.AssignInquiry(info,response,entry or {receivedAt=at},fresh)
    return response
end
local first=add(101,1000)
local sibling=add(102,1029)
assert(first.inquiryID==sibling.inquiryID)
local later=add(103,1060)
assert(later.inquiryID~=first.inquiryID)
M.GreetingSent(info,{first,sibling},1030)
local oldReply={}
assert(M.MarkReply(info,oldReply))
assert(first.customer_answered and sibling.customer_answered and not later.customer_answered)
M.GreetingSent(info,{later},1061)
local context=M.GetReplyContext(info)
assert(#context.members==1 and context.members[1].responseID==103)
first.customer_answered,sibling.customer_answered=nil,nil
assert(M.MarkReply(info,{}))
assert(later.customer_answered and not first.customer_answered and not sibling.customer_answered)
assert(not M.IsActiveResponse(info,first) and M.IsActiveResponse(info,later))

-- A delayed linked reply retains its original group. It cannot select a new
-- job with the same responseID or steal the currently active inquiry.
local replacement=add(101,1090,true)
assert(M.MarkReply(info,oldReply)) -- only unchanged sibling 102 is eligible
assert(not replacement.customer_answered and sibling.customer_answered)
assert(info.activeInquiryID==later.inquiryID)
local peer={responses={[103]={responseID=103,requestToken=later.requestToken,time=1060}}}
assert(M.ApplyContext(peer,context,false))
assert(peer.responses[103].greeting_sent and not peer.responses[103].customer_answered)
assert(peer.responses[103].greetingSentAt==1061)
assert(M.ApplyContext(peer,context,true) and peer.responses[103].customer_answered)
peer.responses[103].requestToken='new-job';peer.responses[103].customer_answered=nil
assert(not M.ApplyContext(peer,context,true) and not peer.responses[103].customer_answered)
assert(not M.ApplyContext(peer,{id='bad',at=1100,members={false,{responseID=9}}},true))

local waiting={time=1000,greeting_sent=true,greetingSentAt=1010}
assert(not M.CanReoffer(waiting,1039))
assert(M.CanReoffer(waiting,1040))
for _,status in ipairs({'claimed','crafted','fulfilled'}) do assert(not M.CanReoffer(waiting,1100,status)) end
waiting.customer_answered=true;assert(not M.CanReoffer(waiting,1100))
waiting.customer_answered=false;waiting.greeting_sent=false;assert(not M.CanReoffer(waiting,1100))

-- Legacy rows use only the latest explicit greeting group, not every customer
-- response and not a profession alias counted a second time.
local a={responseID=1,requestToken='a',greeting_sent=true,time=1000}
local b={responseID=2,requestToken='b',greeting_sent=true,time=1050}
local c={responseID=3,requestToken='c',greeting_sent=true,time=1050}
b.greetingGroup={{responseID=2,requestToken='b'},{responseID=3,requestToken='c'}}
c.greetingGroup=b.greetingGroup
local legacy={responses={[1]=a,[2]=b,[3]=c,[197]=c}}
assert(M.MarkReply(legacy,{}))
assert(not a.customer_answered and b.customer_answered and c.customer_answered)
local brokenGroup={responses={[1]={requestToken='legacy',greeting_sent=true,time=900,greetingGroup=false}}}
assert(M.MarkReply(brokenGroup,{}), 'legacy non-table grouping blocked replies')
local mixedTimes={responses={}}
local early={responseID=1,requestToken='early',inquiryID='together'}
local late={responseID=2,requestToken='late',inquiryID='together'}
mixedTimes.responses[1],mixedTimes.responses[2]=early,late
M.GreetingSent(mixedTimes,{early},1000);M.GreetingSent(mixedTimes,{late},1029)
assert(M.MarkReply(mixedTimes,{}))
assert(early.greetingSentAt==1000 and late.greetingSentAt==1029, 'reply changed individual greeting times')
-- A customer who went quiet: the crafter sets the second mark back to a
-- cross, and any later message from them checks it again - also when the row
-- is not part of the conversation's latest request.
local quiet={responseID=301,requestToken='quiet-a',greeting_sent=true,customer_answered=true}
local newer={responseID=302,requestToken='quiet-b'}
local quietInfo={responses={[301]=quiet,[302]=newer}}
M.GreetingSent(quietInfo,{quiet},1000)
M.GreetingSent(quietInfo,{newer},1100)
assert(M.ToggleAnswered(quiet)==false and not quiet.customer_answered and quiet.awaitingReturn,
    'the mark was not set back to waiting')
assert(M.MarkReply(quietInfo,{}))
assert(quiet.customer_answered and not quiet.awaitingReturn,
    'the customer came back but the row stayed a cross')
-- And by hand the other way.
M.ToggleAnswered(quiet)
assert(M.ToggleAnswered(quiet)==true and quiet.customer_answered and not quiet.awaitingReturn,
    'the mark could not be set back to answered')
print('Request tracking tests passed (30-second boundary, group identity, latest greeted inquiry, linked replay, legacy groups).')
