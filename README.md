# HironCraft

Standalone personal World of Warcraft addon combining the customized chat scanner with the selected ProfitHUB workflow modules.

Included modules:

- Chat scanner and linked-account synchronization
- Buttons
- GoldDeposit
- Orders
- QuestShopping
- Shop
- StackAssist

Personal orders that are missing any customer-provided required reagent are
offered as `Decline` instead of `Claim`. The matching chat row receives a yellow
cross; a later successfully completed order replaces it with the green check.
Completion state is scoped to an individual customer request, so an older job
does not mark a later request from the same customer as complete.
The rejected-order quick reply is offered only on the character that started
the customer conversation, even if another character performs the craft.
Conversation ownership is stored per request and shared with linked accounts.
Legacy requests without recorded ownership do not offer this reply until a
local conversation establishes the owner; the crafting character is not guessed.

The original CraftScan and ProfitHUB folders are not required after migration and can no longer overwrite this copy when they update.

## Quiet Manual Matching is Shift+click (0.4.14)

- The chat menu does not pass right clicks on to its entries, so the quiet
  add from 0.4.13 is Shift+click only; the tooltip says so.

## Add a row from Manual Matching without a greeting (0.4.13)

- Right click (or Shift+click) on an entry of Manual Matching in the chat
  menu, including the general greeting, only adds the row: no banner, sound,
  flash or greeting card, nothing sent. The greeting stays one click on the
  row. A left click works as before.

## Select words by clicking in "Save chat text" (0.4.12)

- The chat text window selected only by dragging. Double-click now selects
  a word (apostrophes such as "Farstrider's" stay inside it, Cyrillic words
  stay whole), Shift+click stretches that selection to the clicked word for a
  phrase of several words, and a triple click selects the whole message.
  Right-click the selection as before.

## A bare recipe link is a request (0.4.11)

- People often post just the recipe of the gear they want, without LF. A
  bare recipe link now counts as a request like a bare item link, also when
  none of the crafters knows that recipe (a profession row for a crafter of
  its profession). It follows the same setting ("Scan item and recipe links
  without keywords"); crafter ads and exclusions are still filtered out.

## Recipe links count like item links (0.4.10)

- "LF crafter [Leatherworking: X] and [Inscription: Y]" made a row for the
  first recipe link only; the second was lost and had to be asked again.
  Every recipe link in a message now counts, in the order written, exactly
  like item links: a recipe this account knows gets its exact row, an
  unknown one a profession row for a crafter of that profession, and all of
  them are answered by one greeting. A recipe linked together with its item
  is one request. A bare unknown recipe link still needs LF.

## Set the "answered" mark back by hand (0.4.9)

- A customer who went quiet may or may not come back. Right click on the
  second mark (customer answered) sets it back to a cross; the next message
  from that customer checks it again, whichever of their requests the
  message is about. Right click on a cross marks it answered by hand. Other
  clicks on the mark act like a click on the row.

## No order replies across factions, one "done" card per customer (0.4.8)

- Crafting orders cross factions, whispers do not. An Alliance crafter that
  made a Horde customer's order was offered "done, ty" (or a decline) it
  could never send, next to the card on the Horde account that talked to
  the customer. The customer's side is read from their race; the card is
  not offered to a character of the other side. Races that choose their
  side (Pandaren, Dracthyr, Earthen, Haranir) are not guessed.
- Two finished orders of the same customer, or one result landing on two
  rows, showed two "done" cards; one card now answers for the customer.

## Notice the chat limit wherever the server says it (0.4.7)

- The greeting take-back watched only the red error message. When the server
  refuses a whisper with a plain line in the chat frame instead, nothing
  noticed: the row stayed marked as greeted while the customer heard
  nothing. Both are watched now, and the text is compared without
  surrounding spaces.

## A multi-item greeting says what goes where (0.4.6)

- "LF shield & intel sword" was answered with "Send to Favu. You choose the
  price..." and then "Sword Send to Favu.": the first message named no item.
  When a request has several items and the greeting does not name its item,
  it now opens with what this crafter makes: "Shield and Sword: Send to
  Favu. You choose the price...". The same crafter's items are not repeated
  one line each; another crafter still gets its own short line. A single
  item, or a greeting that already names the item, is unchanged.
- Short lines are joined per crafter too ("Wrist and Chest Send to Favu."),
  and the greeting card shows exactly the text the click sends.

## A remote decline waits for its material list (0.4.5)

- A decline made on another account sends its material list separately and
  later than the cross. The decline card waited only a few seconds and then
  offered "I couldn't find the material details". It now waits up to about
  two minutes for a remote list and appears as soon as the list arrives.
- A reagent whose name the game has not loaded yet is requested and waited
  for, so the reply no longer says "item:251283".

## An order for a neighbouring recipe marks its row (0.4.4)

- A customer asked for one recipe and ordered a neighbouring one from the
  same crafter (typically the wrong item, sent without materials). The
  result matched no row by recipe or item, so the decline showed no cross on
  the account holding the conversation. When that row is the customer's only
  row with that crafter and profession, the result now marks it; with
  several such rows nothing is guessed.

## Say why a result fits no row (0.4.3)

- A result from a linked account that fits none of the rows of the same
  customer used to show nothing at all. The receiving account now says
  once in chat which check failed for each of that customer's rows (time,
  recipe/item, slot, profession, customer name) and keeps it in
  `settings.notice_mismatch_log` (newest 20). Customers the account never
  talked to stay silent.

## Order results compared on the server clock (0.4.2)

- Each client stamps order results with its own computer clock. A crafting
  PC whose clock runs behind made a decline look older than the request it
  answered, so the linked account dropped it and showed no cross. Statuses
  and notices now carry how far their clock stood from the game server
  (`clockOffset`), and times from two computers are compared on the
  server's clock. Notices of the last day are backfilled and sent again.
- The reply context no longer fails for rows made from a crafting order,
  which store the base profession (for example 755) instead of a branch.

## Requests take turns on the banner (0.4.1)

- Two requests in the same second shared one banner: the second replaced the
  first, which then had to be found in the order list. While a banner is up,
  a new request now waits and gets the banner once the current one is
  answered, dismissed or has timed out. A waiting request answered from the
  order list, removed, or older than 10 minutes is skipped.

## Error log for every HironCraft error (0.4.0)

- Every Lua error that passes through HironCraft - chat scanning, the order
  table, windows, timers, listeners - is kept in SavedVariables
  (`HironCraftScan_DB.settings.error_log`, newest 20, with its stack). A
  repeating error is counted instead of filling the log; other addons'
  errors are not kept.
- Errors are still shown exactly as before: the game's error frame or
  BugSack gets every one of them. With BugGrabber installed its
  announcements are used, since it keeps the error handler to itself.

## A decline always reaches the linked account (0.3.99)

- A decline of an order from a customer this client never talked to got no
  cross on the linked account that held the conversation: that account finds
  its row only through the notice, and an error in a listener of the status
  change stopped the notice from being recorded (ProfitHub swallowed it).
  Listeners can no longer break the code that raised the event.
- Errors in listeners are kept in SavedVariables (`error_log`, newest 20) and
  still reported through the game's error handler.
- On load, a missing notice for such an order row (last 24 hours) is rebuilt
  from the saved status and shared again.

## A request that narrows down replaces its row (0.3.98)

- Requests narrow down: "LF crafter" -> "LF tailor" -> "chest" -> the linked
  item. "LF tailor" followed by "can you craft chest?" left both rows; the
  more specific one now replaces the profession row of the same profession.
  A broader request later ("LF tailor" again) does not push the narrower row
  aside or add a second one.

## Replies stay on the customer's side (0.3.97)

- The side (Alliance/Horde) of the character that talked to the customer is
  kept with the request and shared with linked accounts. A decline or a
  completion note is offered on the crafter only when it is on that same
  side: a whisper cannot cross from Horde to Alliance. Older rows without a
  recorded side are not held back.

## One account that talks and crafts (0.3.96)

- A decline is offered on the crafting character even when the character that
  talked to the customer is on the same account. Before, it waited for a relog
  back to that character; it is still marked as sent for the whole account, so
  it is not offered twice.
- "Also send from the crafter" on the completed-order reply offers the
  completion note on the crafting character too. Off by default; the customer
  still hears it once.
- Sent quick replies (repeat delay, "not the same answer twice in a row") and
  armor slots waiting for the class are saved, so frequent relogs between the
  talking and the crafting character no longer reset them.

## Armor slots wait for a late class (0.3.95)

- An armor slot such as a wrist needs the customer's class, and the class was
  looked up only for about a second after the message. When it arrives later
  (the customer leaves an instance, whispers again from their character) the
  request now keeps waiting for up to 10 minutes and the missing row is added
  as soon as the class is known. Rows that need no class (ring, cloak,
  weapon) are still created at once. Nothing is sent by itself; removing or
  ignoring the customer meanwhile cancels the wait.

## Follow-up items in a running conversation (0.3.94)

- A whisper like "dagger for Favu, wrist for ? and ring for ?" asks for more
  items without saying LF again, and the scanner ignored it: without a
  primary keyword only a general request accepted such a follow-up. While the
  customer has an order that is still open, their whispers now count as
  requests too; once everything of theirs is finished, "the ring looks great"
  is not taken for a new order.
- When the customer's class was not known yet, the whole message was dropped,
  even the parts that never need a class. A ring, a cloak or a weapon is now
  routed at once, and only the armor slot waits for the class, looked up
  again a moment later so the wrist follows as soon as it is known.

## One completion note per customer, not per order (0.3.93)

- Orders of one customer are crafted one after another, often on different
  characters, so each completion landed when nothing else was pending any
  more and asked to announce itself: three "your order is done" to the same
  person. Sending that reply now keeps the addon quiet about completions for
  that customer for fifteen minutes, across character switches and reloads,
  so a batch is announced once however it is spread out. A customer whose
  next batch finishes later still hears about it.

## A greeting the server refused comes back as a card (0.3.92)

- A greeting taken back after the server refused it is now offered again on
  its own, a few seconds later, once the server lets messages through. It
  arrives as the usual greeting card, one click away, instead of something to
  remember and find in the table. Nothing is ever sent by a timer, a greeting
  the crafter sent by hand in the meantime is not offered again, and the
  offer is retried at most three times while the server keeps refusing.

## No chat line about a reply held elsewhere (0.3.91)

- The line explaining that a reply belongs to another character is gone. It
  was added in 0.3.79 to break the silence when nothing appeared; with the
  crafter now able to send a decline and the collecting account offering the
  rest, it only repeated what the other account was already doing.

## Orders collected on one account and crafted on another (0.3.90)

- The character that spoke to a customer often sits on another account, on
  another machine, while the order is crafted here. A decline names the
  reagents the customer has to fix before resending, so the character that
  crafted the order may now send that reply when the conversation belongs to
  another account's character. While that character is one of this account's
  own, the reply still waits for it: switching to it is the right thing to do.
  The completion note is a courtesy and stays with the character the customer
  was talking to.
- The fact that a customer has been told now travels with the order status
  itself, so the account that sends the message answers for all of them and
  no second account offers it again.

## Orders from customers who never wrote (0.3.88)

- A personal order can arrive from someone who never said a word in chat.
  Nothing in the table matched it, so a decline left no cross and no reply to
  send: the customer was never told what was wrong with their reagents. Such
  an order now gets a row of its own when it is declined or completed, owned
  by the character that received it, so the result shows and its reply can be
  sent. No greeting is offered for it - the customer asked nothing - and a
  second result for the same order reuses the same row. Patron orders are
  never given one.

## A greeting the server swallowed is offered again (0.3.87)

- The server limits how fast whispers go out, and when it refuses one the
  addon hears nothing: the message never arrives while the row is already
  marked as greeted. The row now un-marks itself when the server says it was
  sending too fast right after a greeting, and says so in chat naming the
  customer. Nothing is resent on its own - the row simply becomes clickable
  again.
- For the few seconds after such a refusal no further message is handed to
  the server, and a reply attempted in that window says so instead of
  disappearing. No guess is made about the limit itself: a made-up limit
  would block work the server was happy to carry.

## No answer twice in a row, built-in wording restored (0.3.86)

- The same answer is no longer offered to the same customer twice in a row.
  While the last thing said to them is exactly this text, the card does not
  appear and a click on one made earlier sends nothing. Saying anything else
  to them lifts it at once, and after five minutes the same question is
  answered again anyway. Order events are exempt: a decline repeating itself
  is a new attempt at the same order, and the customer has to hear about it.
- The three built-in answers 0.3.85 rewrote are back to their original
  wording. Anything the crafter edited was never touched by either change.

## Which reply wins (0.3.85)

- Ranking now follows what the customer actually said. A longer phrase they
  wrote beats a single word, and a word they really wrote beats one read
  through a typo. Priority ranks answers that match the message equally well;
  it no longer lets a guess on a high-priority reply outrank a certain match
  on another.

## One completion reply, even when two orders finish together (0.3.84)

- Two orders finishing in the same moment each asked to announce themselves,
  and both messages went out. Sending one "your order is done" now counts as
  the answer for everything of that customer's that is already finished: the
  other cards leave the screen, a click on one that slipped through sends
  nothing, and they are not offered again after a reload. An order that
  finishes later still gets its own reply.

## No completion reply for a check mark set by hand (0.3.83)

- Marking an order complete by hand no longer offers the completion reply. A
  check mark set that way is the crafter's own bookkeeping - the customer may
  have been told already, or not be waiting for anything - so announcing it is
  their call. A completion the addon detected itself still offers the reply,
  and a decline recorded by hand keeps its own reply, because that one carries
  the materials to fix.

## Minimum profit of its own for knowledge orders (0.3.82)

- Order filters gained a "Knowledge: min. profit" field next to the ordinary
  minimum. Knowledge orders are taken for the knowledge, often at a loss, so
  they can now have their own threshold - a negative value is the loss you
  agree to. While the field is filled it decides for knowledge orders instead
  of the "Knowledge: ignore min. profit" switch, every other order keeps using
  the ordinary minimum, and clearing the field hands the decision back to the
  switch.

## Replies that only make sense before the craft (0.3.81)

- Every keyword reply gained an "Only while an order is open" switch in Quick
  Replies. With it on, the reply is offered only while that customer still has
  something in the works, so a customer who writes "sent" again after their
  item was handed over no longer brings "omw" back. An order that is claimed,
  being crafted or still waiting for a result counts as open; one that was
  completed or declined does not, and a request that never became an order
  stops counting after 12 hours. Default off, so nothing changes until the
  switch is ticked; the event replies do not have it, because an order event
  is the order.
- A card that was offered while the order was still open is taken off the
  screen the moment the order gets its result, and a click on one that
  slipped through sends nothing: "omw" no longer goes out one second behind
  "Done, ty".

## Replies that waited while their character was away (0.3.79)

- A decline or completion whose reply never appeared is offered again when
  its conversation character logs in. The card was built from a live event,
  so a status that arrived while that character was logged out - because the
  crafting happened on another character or on the linked account - lost its
  reply for good. Replies that were actually sent are remembered, so a reload
  does not offer them a second time, and only the five newest unanswered ones
  from the last six hours are offered.

## Typos in short keywords, general greeting from the chat menu (0.3.78)

- The existing "Recognize typos" switch now also forgives typos in short
  words, which is where they actually happen: "charr" finds char, "writs"
  finds wrist. Words of three letters or fewer still require an exact match,
  a word that is a keyword in its own right is never read as a misspelling of
  another one ("waist" stays waist), and a guess that fits two different
  keywords equally well is skipped.
- The same switch now covers equipment aliases as well, so a misspelled slot
  in "LF writs" still creates the request and its greeting. One switch
  controls both; turning it off restores exact matching everywhere.
- Right-clicking a name in chat offers "General greeting (LF crafter)". It
  creates the same general request an "LF crafter" line creates on its own and
  offers its greeting to send, without naming a profession. The text stays
  editable in Settings - Customer Greetings, and the phrases that trigger it
  on their own in Settings - Matching.

## Concentration priced from the recipe's own slots (0.3.77)

- The refusal the diagnostics recorded is the whole answer being withheld, not
  a complaint about one entry, so the lists are now built the way the client
  addresses slots: one entry per required slot of the recipe, taken from the
  schematic, carrying the customer's item where they supplied one. This is
  asked first, before the lists built from the order's own reagent payloads,
  whose slot numbers do not always line up with the schematic.
- The cheapest list could send two entries for the same slot, which is never a
  valid request; it now sends one entry per slot like every other list.
- When a cost can still only be had from an empty list, the diagnostics also
  print the recipe's slots as the schematic reports them.

## Concentration for recipes the client prices only empty (0.3.76)

- `/ahuicodbg conc` output showed the cause of the rows that print "?": for
  those recipes the client answers nothing at all - not a zero cost, no answer
  - for every reagent list we attach, while it answers normally for an empty
  list. The lookup now also asks with an empty allocation. That number ignores
  the reagents, so the cell prefixes it with "~" and the tooltip says it is
  approximate.
- A nil reagent list is never accepted by the client, so that attempt was
  replaced rather than added to.
- When the client refuses a list, the diagnostics now record its refusal and
  the exact reagents that were sent, which is what the remaining exact-cost
  work needs.

## Concentration diagnostics report the client's answer (0.3.75)

- `/ahuicodbg conc` now prints which operation-info and concentration
  functions this client exposes, and for every order it cannot price: the
  fields the client's answer actually carries, every value whose name mentions
  concentration, currency or cost, and what the prepared order view reports
  for the same order. A row that shows "?" while Blizzard's own crafting
  details show a number can be explained from this output instead of guessed.

## Concentration cell tells its three answers apart (0.3.74)

- A requested quality that concentration cannot reach is no longer printed as
  "?" - the cell shows a red dash and says so in its tooltip. Concentration
  bridges one quality step, so for an order far below its requested quality
  the client answers with no cost at all, which is not the same as data that
  has not loaded yet; "?" now means only the latter.
- `/ahuicodbg conc` prints, for every order on screen, the requested quality,
  what the engine decided, and every concentration lookup with the client's
  answer. Use it on a row that still shows no number.

## One completion reply per batch of orders (0.3.72)

- A customer who placed several orders at once is told once, when the last of
  their orders is finished, instead of after every third check mark. An order
  of theirs that is claimed, being crafted, or still waiting for a result
  holds the reply back; an order that was completed or declined does not, and
  a declined order still gets its own reply with the materials to fix. An old
  request that never became an order stops holding the reply after 12 hours,
  so a stale chat row cannot mute it forever.

## Banner for hand-linked lines, repeat delay in seconds (0.3.71)

- Matching a chat line by hand (right-click on the name) raises the normal
  request banner again. It used to suppress the banner and offer a greeting
  card instead; a line the crafter links is their own decision, so the
  greeting card is now reserved for whispers the customer actually sent.
- The per-reply repeat delay is entered in seconds instead of minutes, up to
  86400. A delay configured in 0.3.70 keeps its real length.

## Repeat delay per quick reply (0.3.70)

- Every quick reply, built-in or custom, gained a repeat-delay setting in
  Quick Replies. After the reply is sent to someone, it is not offered to that
  same person again for that long, so a customer who writes "will send" and
  then "sent" is offered one "omw" instead of two. Other quick replies for the
  same person are unaffected, and 0 (the default) keeps the previous
  behaviour. The delay is counted within the current session and is shared
  with linked accounts as part of the quick-reply settings.

## Public tab refresh, stable row background (0.3.69)

- Switching to the Public tab kept showing the orders of the tab left behind.
  `C_CraftingOrders` holds the last answered list, so the tab was handed those
  same orders back and the list looked unchanged; dropping rows by order type
  did not catch it, because the previous results pass a type check of their
  own. The list now remembers exactly what the previous tab showed and
  withholds that set until the server answers for the tab now open, which is
  what Blizzard's own empty list already says. A deliberate Search, a real
  answer with different orders, or closing the window release it.
- The row background no longer drops back to neutral while an order is being
  claimed, crafted or handed in. Those steps invalidate the data the state is
  read from, and a finished row is not analysed at all, so the last answer for
  the row is kept and reused while the live one is missing.

## Personal order row states, concentration cost (0.3.68)

- A Personal order row now says what the order is before it is claimed. Red:
  reagents are missing, either the customer's or ours. Yellow: everything is
  in place, but the requested quality is only reachable with concentration.
  Green: craftable as requested without concentration. A row whose data
  Blizzard has not delivered yet keeps its plain stripe instead of looking
  healthy until the craft says otherwise, and repaints as soon as the answer
  arrives. Patron, Guild and Public rows are not coloured this way.
- The concentration button printed "?" for orders the client would not price
  with the allocation we planned. The cost is now looked up through the
  allocations Blizzard can answer for, down to the order exactly as the
  customer left it - the same one its own order page prices. A cost read from
  an allocation we would not craft with is still not treated as evidence that
  an order needs concentration.
- `/ahuicodbg hover` reports every concentration lookup it tried and the row
  state, for orders that still show no number.

## Completed-order reply, material lists on fast declines (0.3.67)

- New built-in quick reply COMPLETED ORDER, offered when an order is completed
  and gets its green check ("Your order is done, thank you!"). Like every quick
  reply it is editable and is only sent when you click the suggestion; its
  checkbox in Quick Replies turns it off.
- Clicking through the queue quickly could record a decline before its material
  list was captured, so the reply said the details could not be found. The
  list saved when the order was claimed is now used, retried for a few seconds
  if it arrives late, and the decline reply waits for it.
- Switching order tabs refreshes the list again. A tab that sends no request
  (Public without favourites, an empty Guild tab) used to keep showing the
  previous tab's orders.

## Stable order list, late Personal orders, manual declines (0.3.66)

- The order list no longer blinks after a completed order. Every refresh used
  to hide all rows until the server answered; the rows now stay on screen
  (inert: no hotkey or click) and are replaced when the response arrives. A
  tab/profession change or a request without an answer (3 s) still clears it.
- In one-button Personal mode, a Personal order that arrives while the list is
  already open is selected like the ones present at opening; an order you
  unchecked yourself stays unchecked.
- A decline made with Blizzard's own button now also marks the chat row with
  the rejected cross and keeps its material list. ProfitHub's own declines are
  still recorded once, with their reason.

## Hitch profiler (0.3.65)

- `/hcprof [ms]` (default 150) reports every frame slower than the threshold
  in chat, with the ProfitHub order and HironCraft functions that consumed its
  time (inclusive, with call counts). `/hcprof off` stops it. Nothing is
  wrapped until the first `/hcprof`; disabled wrappers only forward the call.
- Recordings showed the game freezing for about 9 seconds while the Personal
  orders list was processed, before the decline itself ran. The profiler
  identifies which step is responsible.

## Faster declines, exact late material lists (0.3.64)

- Status marks look up completion notices through a per-customer index
  instead of scanning the whole journal (hundreds of notices) for every
  visible mark on every refresh. A decline or completion triggers several
  such refreshes, which froze the UI.
- The completion journal is no longer duplicated into every realm section of
  SavedVariables. Those aliases were written as separate copies, one per
  realm ever visited (about 7 MB parsed on every login); the copies are
  removed on the next load.
- A material list first captured after crafting (for example a quick recraft)
  shows covered quantities exactly (3/3) instead of "≥"; only an apparent
  shortage remains marked as uncertain.
- The low-tier hint uses "T1->T2": the game font has no "→" glyph.

## Sparks excluded from material lists (0.3.63)

- Sparks are no longer reported as missing in the decline message and are not
  shown in, or sent with, the order material list. A spark slot is recognized
  by its interchangeable spark/fragment quantities or by the item name
  ("Spark of ...", "Искра ..."); a supplied spark still fills its slot instead
  of appearing as an unknown extra item. Lists saved or received from older
  versions have their spark rows removed as well. The decline decision itself
  is unchanged.

## Text cursor position in settings fields (0.3.62)

- Multi-line settings fields (keywords, responses, greetings, aliases) now set
  their 12 pt font before their text. Changing the font after the text left
  the caret laid out for the template's smaller font, so it was drawn away
  from the actual insertion point. When a field's width changes while it is
  not being edited, its text is re-applied to refresh the caret layout.

## Congestion-free status and material sync (0.3.61)

- Checkmarks no longer queue behind material lists. Blizzard throttles addon
  messages per prefix and AceComm sends each prefix/priority in order, so
  material lists, profession snapshots, analytics and settings now use a
  separate `HIRONCRAFT_BULK` prefix. Marks, ACKs and pings keep
  `HIRONCRAFT_SCAN`, as do the public crafter-search messages.
- Marks are sent without materials and acknowledged immediately. Claim, craft
  and fulfil revisions made within 0.3 s are sent together; a mark still in the
  local send queue is never queued again, and resends back off. A backlog is
  sent ten marks at a time, the next part after each ACK.
- Material lists (fulfilled and rejected only) have their own durable
  "undelivered" flag and ACK. At most one batch per linked account is in
  flight; the next batch or a retry follows an ACK or a timeout counted from
  the moment the batch actually left the queue. A list still queued at logout
  is sent by the next character. Rows materialized from a linked account's
  notice no longer echo the list back.
- Ping timeouts start when the ping is actually sent, and pinging every known
  character is limited to once per 20 s. Previously a busy queue looked like a
  character switch and triggered pings to every alt, which slowed it further.
- Logging in sends only unconfirmed marks instead of the recent journal with
  materials, and the login snapshot no longer contains material lists.
- Both linked clients must run this version: older clients ignore the new
  prefix and do not acknowledge material lists.

## Prompt live material delivery and compact tooltips (0.3.60)

- Ordinary live outcomes (up to 12 reagent rows / 24 supplied variants) send
  their material snapshot immediately with the status at ALERT priority. They
  no longer wait for NORMAL traffic or a subsequent frame before serialization.
  Claim/craft progress sends only the status, keeping pre-consumption evidence
  durable locally and avoiding repeated material transfers before completion.
  Large outcomes and history batches retain the compact-first delivery path.
- The material tooltip uses one line per ordinary reagent: actual supplied
  name, supplied/required quantity, and quality. Low tiers show an amber
  T1→T2/T3; proven shortages remain red. Long mixed variants may wrap.
- Partial/late snapshots display observed quantities as ≥N, in neutral color,
  rather than green question marks. Unknown coverage never becomes a proven
  shortage. The selected spark's name replaces the schematic's first variant.
- Hovering a completed order no longer rebuilds both tooltips four times per
  second: unchanged reagent snapshots preserve their identity.

## Completed-order materials and responsive status sync (0.3.59)

- Customer reagent snapshots appear for every fulfilled order, including T5,
  recipes capped at another rank, unranked crafts and uncached output quality.
  Missing quantities and lower-tier customer reagents keep their existing
  highlighting. The completed-order heading no longer depends on cached quality.
- Linked status updates, outcomes, recent-history replays and status repairs
  queue a compact status immediately at ALERT priority. Material evidence follows
  at NORMAL priority, so large reagent lists do not occupy the urgent status
  queue. Both packets use existing operations and preserve order/revision identity.
- The compact packet cannot acknowledge delivery of material evidence. The full
  packet retains delivery metadata for existing ACK/retry handling; reordered
  packets enrich the same result without erasing evidence or changing a newer order.

## Complete equipment aliases (0.3.58)

- Equipment Names now includes Neck, Ring, Trinket and Held Off-hand, plus the
  missing craftable weapon families Bow, Crossbow, Fist weapon and Wand. The
  starter aliases include common English/Russian forms and player shorthand
  such as `ring`/`ринг`, `neck`/`нек`, `trinket`/`тринкет` and `offhand`/`оффхенд`.
- Ring and Neck route to Jewelcrafting. Ambiguous types (trinkets, held
  off-hands and the added weapon families) are recipe-driven: a profession is
  offered only when one of its currently monitored recipes produces that exact
  inventory type/subclass. This follows expansion recipe changes without
  claiming a craft from an unrelated enabled profession.
- Messages can create several independent equipment rows, and a later item link
  replaces only the matching type and profession. `sword and off-hand` remains
  two requests, while adjacent `sword off-hand` stays a weapon-hand qualifier.
  No reply is sent until its banner/Quick Reply is clicked.
- Generic bags, shirts and profession tools/accessories remain outside this
  combat-equipment vocabulary: their names do not identify one reliable target
  profession or order. Exact monitored item links continue through normal item
  matching.

## Completed-order material diagnosis reliability (0.3.57)

- Added an end-to-end regression for the intended case: a T4/T3 result from an
  unlocked order whose customer supplied the full quantity as mixed lower-tier
  reagents. `40 / 40` remains complete while every confirmed lower tier is
  listed separately, for example `20x T1 -> T3` and `20x T2 -> T3`. Crafter-
  supplied reagents remain excluded from this evidence.
- If the crafted item's actual rank is not cached at the first result event,
  retry it after 0.2, 1 and 3 seconds using the exact order/output identity.
  Late data enriches the existing green completed row and its linked-account
  journal; it never changes the result back to an in-progress state.
- The tooltip reports observed material quantities/tiers and the actual output
  tier. It does not claim that materials are the sole cause of a lower result,
  because skill and recipe state can also matter.

## Completed-order materials and scanner fixes (0.3.56)

- Completed equipment orders below T5 now show the customer reagent tooltip
  beside chat history, including the actual crafted tier. The green completion
  check remains; this does not offer a rejected-order reply. Recipes whose
  maximum is T2/T3, T5 results, and unknown results do not trigger this tooltip.
- Capture customer materials before crafting consumes them. Preserve snapshots
  across reloads and linked-account status/journal updates; track the final pass
  of a recraft separately. Missing post-craft data is unknown, not a shortage.
  Actual quality comes from the fulfilled order's output hyperlink, not its
  requested minimum or a crafting preview. Previously completed orders without
  a snapshot cannot be reconstructed. Pending snapshots are capped at 500/30 days.
- Weapon qualifiers (`one hand`, `two hand`, `1h`, `2h`, hyphenated forms)
  no longer create an extra Gloves request. Separate requests such as
  `hands and one hand sword` still produce two rows. Configured weapon phrases
  remain intact, and exact links replace only the matching equipment request.
- Added editable Shield synonyms (`shield`, `shields`, `buckler`, `bucklers`,
  `щит`, `щиты`, `щита`, `щитов`). Shields route to Blacksmithing independently of
  customer armor class and replace their placeholder when a shield is linked.
- Patron/recipe shopping can populate its list before the first auction visit.
  The shopping UI is created only after the auction UI is available and shown,
  avoiding missing `AuctionHouseFrameDisplayModeTabTemplate` errors. The stored
  list is retained for the next auction visit; closed auctions are not marked open.
- Regression tests cover capture/craft/fulfillment, reloads, linked enrichment,
  recraft passes, tooltip quality, scanner phrases and deferred auction opening.
  All outgoing replies remain manual. Live rendering still needs an in-game check.

## Natural reagent replies (0.3.55)

- `{reagent_issues}` now writes conversational sentences: `Looks like you're
  missing ...` and `Could you replace ..., please?`. Each sentence lists every
  confirmed material, quantity and relevant tier, including several lower tiers
  of the same material and selected optional reagents. The underlying saved
  customer-only counts and quality checks are unchanged.
- Recraft and unavailable-data explanations also use natural wording without
  inventing shortages or claiming a proven game bug. The detailed hover tooltip
  retains its compact quantities and tier comparisons.
- The default rejected-order reply is `I checked your order. {reagent_issues}`.
  On first upgrade, the old defaults and the exact `Resend. You missed ...`
  variant (curly or square brackets) migrate to it. Other custom pastes, renamed
  labels, priorities, disabled/deleted replies and subsequent edits are preserved.
- Chat reports stay in English with captured item names. Long reports still
  split only after a manual click/bind and share the existing cooldown; no
  material is dropped just to fit a single whisper. Tests cover multi-material
  reports, both locales, migrations and real UTF-8 chat splitting.

## Editable replies and equipment names (0.3.54)

- Config > Quick Replies now offers **Name** and **Delete** for every answer,
  including built-ins and the rejected-order reply. Renaming preserves triggers,
  text, priority and enabled state. Deletions survive reloads and linked-account
  config synchronization. Visible cards for a renamed/deleted answer are dismissed;
  stale clicks cannot send them. Disabled checkboxes remain disabled on refresh.
- Config > Equipment Names contains editable English/Russian starter synonyms for
  nine armor slots (including Back/Cloak) and eight weapon types. Add words or
  phrases separated by commas/newlines. Changes save on leaving the field and
  apply to new messages; an empty row disables that category. Exact duplicates
  across categories are rejected. Defaults can be restored separately per row.
- `Hey, i need also belt, hands and back can you craft?` creates three separate
  typed requests when the customer class and monitored crafters are available.
  Armor routes by class, cloaks to Tailoring. A compatible monitored item link
  replaces only its own placeholder, retaining the other requests.
- Explicit `looking for wrist cloth crafter please` produces a cloth Wrist
  request even with no class information or class inference disabled. Clicking
  the proposed greeting keeps the typed row; a later bracer link replaces it.
- Manual profession matching through the nickname menu offers one Quick Reply,
  not an additional greeting banner. When Quick Replies are disabled, the normal
  enabled banner alert remains available. Nothing sends until a manual click/bind.
- Automated regression tests cover the exact reported phrases, unknown classes,
  link replacement, real settings callbacks, compact/full layouts, persistent
  edits and stale reply actions. Game rendering still needs an in-game check.

## Declined-order reagent snapshots (0.3.53)

- Before an addon-driven decline/release, save the customer's server-provided
  reagents, quantities and ranks. Never include the crafter's inventory or
  temporary transaction allocations. Snapshots survive reloads and travel with
  rejection statuses/journal notices between fully linked accounts.
- Hover a rejected CraftScan row for a separate reagent tooltip to the left of
  chat history (right/below fallback near screen edges). It shows supplied vs.
  required quantities, shortages, and lower-tier materials. Missing API data
  stays unknown. Old declines cannot be reconstructed retroactively.
- Use `{reagent_issues}` in Quick Reply or Custom Explanations. The unchanged
  legacy rejection reply is migrated to this tag; edited pastes are preserved.
  The tag expands to concrete missing/replacement quantities in English using
  captured item names. Select an active/declined item in the customer menu when
  the customer has several requests. Long replies split at chat limits only
  after a manual click/bind and share the six-second cooldown.
- If all supplied materials are complete and highest tier, a captured quality
  rejection reports the game's computed vs. requested quality, not a request to
  replace good materials. Recrafts are marked as a *possible* calculation issue,
  not proof of a Blizzard bug. The tooltip includes captured skill/next-tier
  threshold and configured finishing-reagent limit when available. Skill,
  specializations, concentration and settings can also limit output quality.
- Snapshots and reply actions stay tied to the exact Blizzard order ID. Delayed
  rejection messages cannot replace the status of a more recent resent order.
- Regression coverage includes mixed ranks, alternative spark quantities,
  ambiguous/unavailable reagent data, pre-release capture, linked-account
  persistence, manual reply batches, and live tooltip lifecycle. Actual game UI
  and server payloads still require an in-game check after `/reload`.

## Reply safety (0.3.52)

- Banner bindings act only on a currently visible banner and its displayed
  request. New whispers cannot silently replace its recipient. Hidden,
  expired, dismissed or reused requests cannot be sent via an old banner.
- The Quick Reply binding also refuses cards whose parent interface is hidden.
- Obvious crafter service offers (including `Send order to ...`, `I can craft`
  and the reported unsolicited sales messages) no longer create requests or
  quick-reply suggestions. Item links alone and customer questions still work;
  explicit manual profession matching remains available.

## Conversation and patron queue fixes (0.3.51)

- The same outgoing quick-reply text to the same customer has a six-second
  cooldown. Other replies and customers are independent; failed sends can retry.
- Bind **Send top Quick Reply** under HironCraftScan in WoW's key bindings.
  It uses the same validation and cooldown as clicking the uppermost card.
- Right-click manual profession matching creates a proposed reply without
  sending. Click its card/order banner to send it.
- New whisper requests use `item Send to crafter.`, including first contact.
- Slot requests (Wrist, Belt, etc.) and weapon requests (Axe, Sword, Gun, etc.)
  have separate placeholder rows. Armor follows the customer's class or explicit
  armor/profession. Compatible monitored item links replace their placeholder;
  unrelated types remain separate. Requests never automatically send chat.
- Patron selection survives transient concentration-cache misses and partial
  order-list refreshes during a craft. Unsafe claims remain blocked, but no
  longer silently uncheck the order or erase its saved selection.

## Editable recipe shopping plan (updated in 0.3.51)

- Adding a recipe opens a small, movable side window (360 wide, at most five
  visible rows). It never takes keyboard focus. Close it with X/Escape and
  reopen it with **List** or by right-clicking **Add to shopping**.
- Each row has minus/plus, an editable quantity (Enter or focus loss to apply)
  and X to remove it. Quantity zero removes that row. **Clear** works with one
  click. Removing or reducing one recipe rebuilds only the accumulated
  recipe list, preserving the other recipes and their reagent selections.
- The side-window quality selector applies to new additions: **T1** or **T2**.
  Explicit quality overrides required quality-reagent slots,
  while selected optional/finishing reagents remain as selected. An unavailable
  tier produces an error instead of silently buying another tier.
- Identical recipe/reagent selections merge. Different quality or optional
  reagent selections retain separate rows and immutable per-craft snapshots.
- Owned reagents are always deducted once from the combined requirement for
  each exact item ID/quality. For 40 T1 required, 20 T1 owned and 15 T2 owned,
  the list buys 20 T1. Other quality stock does not reduce that amount.
  Stock is also checked on auction opening and before purchase; a larger old
  commodity quote is cancelled if stock changed before confirmation.
- Bound reagents such as sparks are excluded, including slots with several
  interchangeable sparks. They cannot block selection of T1/T2 materials.
- Each addition refreshes the side-window rows, count and tooltip immediately.
  The main duplicate quality button, stock checkbox and Recalculate are removed.
  Creating a plan outside the AH no longer constructs the full auction window.
- Recipe plans and settings survive reload/login. Shopping's temporary-list
  cleanup no longer deletes user-managed recipe lists.
- Unlearned recipe items also appear in the editor and can be removed
  individually. Auction lookup keeps their unresolved rows visible and saved
  until results arrive; interruption or no matching auction cannot delete the
  request. Lookup accepts recipe-learning items, not the crafted output.
- Plan mutations roll back when the shopping backend rejects an update.

## First-open navigation and release packaging (0.3.49)

- Clicking Recipes, Specializations, Crafting Orders or Chat Orders cancels
  pending automatic Personal-order navigation for this opening. Late retries
  and order-count events no longer take navigation back from the user.
  Automatic Personal opening remains enabled for the next visit.
- Removed a delayed direct TabSystem selection and the blanket HIGH-layer
  override for Blizzard tabs; native tab ownership and layers are preserved.
- Release ZIPs use standard forward-slash entry names and plain Windows file
  attributes, including builds made with Windows PowerShell 5.1.
- The runtime addon version now comes from the TOC rather than a stale literal.

## Regular-recipe shopping list (0.3.49)

- Learned recipes on the standard profession crafting page have a quantity
  field and **Add to shopping** button below the native recipe-tracking control;
  this does not require Profession Shopping List.
- Repeated clicks and different recipes accumulate into one temporary
  **Profession recipes** list in HironCraft Shop. Player inventory, bank and
  reagent storage are reserved once across the complete plan, so only the
  combined missing amount is listed.
- An unlearned recipe shows **Add recipe** in the same upper-right position.
  It adds the recipe-learning item itself; unresolved source text is matched
  by recipe name and restricted to auction items in the Recipe class.
- HironCraft's recipe button and Profession Shopping List's **Track New Mogs**
  button are kept inside the recipe panel so they cannot cover Blizzard's
  Recipes, Specializations, Crafting Orders, or Chat Orders tabs on first open.
- The shopping controls have extra spacing below Track Recipe. A visible
  planned-craft/recipe count sits below the button and updates when the plan
  changes; the open tooltip refreshes at the same time, without re-hovering.
  Tooltip refresh also uses Blizzard's native owner UpdateTooltip callback.
- Current reagent-quality allocations and explicitly selected optional or
  finishing reagents are preserved. The best-quality checkbox controls an
  otherwise unallocated quality slot.
- Right-clicking opens the editor; full clearing uses its **Clear** button
  (one click since 0.3.51).

## Specific item request guard (0.3.45)

- `LF craft [item]` no longer falls back to the general-request row when the
  linked recipe is unknown, unlearned, disabled or unavailable on every
  configured crafter.
- The broad editable greeting remains limited to requests that contain no
  explicit item link.

## Unapplied concentration cost projection (0.3.44)

- Exact concentration cost is read from the operation projection before
  concentration is applied; WoW 12.x can return zero after application.
- Quality reachability is still checked with concentration enabled, while both
  reagent solvers retain the cost from the matching disabled projection.

## Concentration cost compatibility (0.3.43)

- Crafting-order quality probes now submit the nested `CraftingReagentInfo`
  format required by WoW 12.x instead of the removed top-level `itemID` form.
- The fast fallback accepts both the direct `concentrationCost` result and
  concentration-specific cost collections returned by operation-info variants.

## Contained Auction House hotkey labels (0.3.42)

- Assigned keys on Buy, Refresh, Skip, Post and sell-side Skip buttons use a
  smaller single-line caption inset from the upper-right edge, so the caption
  remains entirely inside the Blizzard button border.

## Follow-up replies and Auction House controls (0.3.41)

- A new craft request from an existing conversation uses a compact
  `item/profession Send to crafter` reply instead of repeating the full greeting.
- Clicking that Quick Reply refreshes the matching row immediately, including
  its first status checkmark.
- Buy and sell action labels stay centered while the assigned hotkey appears as
  small text in the upper-right corner.
- Auction House tabs attach cleanly to the frame, and selected tab and duration
  captions no longer move with Blizzard's pressed-state offsets.

## Stable crafting-order list (0.3.40)

- Crafting-order API bursts are coalesced into one repaint after a short quiet window.
- Each order keeps a dedicated row frame keyed by order ID across refreshes and explicit sorts.
- Partial server snapshots are merged with the last complete list while claim, craft, release or fulfillment is in progress.
- Scroll position follows the first surviving visible order when rows above it disappear.
- Repeated page callbacks no longer authorize transient empty snapshots to clear the visible list.
- Custom rows no longer receive duplicate Blizzard-row overlays or delayed layer refreshes.

## Single-order destination reply (0.3.39)

- **To who send** is explicitly available for customers with one unfinished order as well as several.
- Assignment labels use a client-font-safe separator instead of an arrow glyph that could render as a square.

## Auction House tab spacing (0.3.38)

- The Auction House tab row now sits flush against the bottom edge of the Auction House frame.

## Generic crafting requests (0.3.37)

Messages such as `LF crafter`, `LF craft` and `LF recraft` create a temporary
general request row when no monitored profession or item can be identified.
Its editable greeting is sent only by an explicit click. A later clarification
such as `BS`, an armor slot or one or more item links replaces the general row
with the corresponding profession or item rows, without requiring another
`LF`. Global and profession exclusions remain active throughout the exchange.

## Auction Shop layout refinements (0.3.36)

The Auction House tab is named `HironCraft` and is placed before Blizzard's
Buy tab while preserving the order of Auctionator's tabs. Pressing an internal
Shop tab no longer shifts its centered label. The stop-scan action now occupies
a separate status row and is hidden whenever a scan is not running.

## Classic Auction Shop interface (0.3.35)

The HironCraft Auction House page now uses the same Blizzard-native visual
language as the Crafting Orders workflow: textured dark-brown insets, warm
borders, gold headers and standard panel buttons. Text buttons are explicitly
centered, including the two-line buy/refresh/skip hotkey controls. The old
purple outlines, colored action borders and oversized toy-shop artwork are no
longer used. Buy, Sell and Cancel keep the same behavior and share the style.

HironCraft Shop is now selected as the Auction House landing page on every
open, even when the current shopping list is empty. The internal Buy page is
selected first so search and manual list creation are immediately available.

## Quick Reply for new whisper orders (0.3.34)

When an existing customer whispers a new crafting request, the scanner now
creates or reopens that exact order row before offering its generated greeting
as a Quick Reply. The popup is tied to the row's new request token, so a
completed older order cannot consume or redirect the reply. Multi-item and
Battle.net requests retain their normal routing information. Nothing is sent
automatically; the greeting still requires one explicit click.

## Multi-order reply context (0.3.33)

The chat name context menu now offers **To who send** for customers with
unfinished requests. One explicit click sends a compact, chronological list of
unique assignments: item requests use item to crafter, while generic requests
use profession to crafter. Crafted, fulfilled and rejected orders are excluded.

When several unfinished requests exist, **Active order** can pin one of them as
the source for the crafter, item, profession, profession link and commission
placeholders in Custom Explanations. **Automatic** keeps the previous
latest-relevant behavior. The choice is per customer and session-only, and is
discarded as soon as that exact request is completed, rejected, replaced or
removed. Choosing a context sends nothing; chat is still sent only by a direct
click on an answer.

## Order hotkey lifecycle fix (0.3.32)

The configured order hotkey is now applied as soon as an already visible
crafting-order page or crafting table is detected. Native rows can initialize
after the page's first `OnShow`; that missed lifecycle event previously left the
hotkey inactive until the mouse entered an action button and forced a binding
refresh. Hovering a row is no longer required before processing the queue.

## Safe concentration queue checks (0.3.31)

Patron orders are no longer treated as concentration-free while Blizzard's
quality calculation is still loading. Unknown orders stay out of automatic and
knowledge queues, and the concentration state is checked again before claiming
an NPC order selected without concentration. If the late result is unsafe, its
checkbox and saved selection are removed without calling the protected claim
API. A missing crafter reagent is now a transient craft result rather than a
sticky row error, so buying the material lets the next explicit Action press
continue normally.

## Context tags in Custom Explanations (0.3.30)

Custom Explanations now expand the same order-context placeholders as greetings
and quick replies: `{crafter}`, `{item}`, `{profession}`, `{profession_link}` and
`{commission}`. User-defined substitution tags are expanded first, so their
values may contain these context placeholders too. The most relevant active or
newest listed request for the selected customer supplies the values. Plain saved
messages still work without an order; a contextual message is not sent when its
order data is unavailable, preventing a raw placeholder from reaching chat.
Sending remains an explicit click action.

## Select chat keywords and route them from one menu (0.3.29)

Right-click a chat message and choose **HironCraftScan - Save chat text** to
open a plain, selectable copy of that message. Item links are displayed as item
names so they do not intercept selection. Select a word or phrase and right-click
the selection to choose one of four actions:

- add the key to an existing quick response;
- add it to global scanning;
- add it to a selected crafter's profession scanning;
- create a new quick response with the selected key prefilled.

The editor supports multiline text, wraps to its actual width and uses unlimited
text without Blizzard's misleading negative character counter. Duplicate keys
are rejected. Scanner changes apply immediately; quick responses and profession
changes continue through their existing linked-account synchronization. Nothing
is sent to customer chat by any picker action.

## Saved order selection and configurable knowledge queue (0.3.26)

Crafting-order checkboxes now survive closing the profession window, shopping,
tab changes and `/reload`. Choices are isolated by character GUID, profession,
expansion and order tab. Only orders in the current list enter the active queue;
missing orders do not contribute to shopping or selected counts. A temporarily
empty/filtered list does not erase saved choices. Completed/rejected orders are
cleared, recipe changes invalidate a reused ID, and unseen choices expire after
30 days. This stores checkbox decisions, not cached actionable orders.

Automatic selection adds qualifying orders without clearing the existing queue
or restoring manually unchecked orders. Explicit **Queue**, **Queue: knowledge**
and **Select all** clicks can select them again. Startup navigation to Personal
no longer erases the saved Patron queue; Personal auto-selection also respects
manual exclusions. Delayed queue/shopping callbacks are cancelled when the
window closes or its selection context changes.

The sidebar's **Queue** settings page has two independent options:

- **Knowledge (patrons)** under **Auto on open** adds knowledge orders in the
  same pass as the normal queue. It also works with normal auto-queue disabled.
  Existing auto-queue users start with this enabled; subsequent choices persist.
- **Knowledge: ignore profit** controls both the automatic knowledge pass and
  the manual knowledge button. Enabled preserves the former knowledge behavior,
  including negative/unknown profit. Disabled applies the usual minimum-profit
  filter; set its minimum to `0` to exclude losses. Previously checked orders
  stay selected until the user changes them or explicitly rebuilds the queue.

Knowledge selection still excludes unknown recipes and concentration-required
orders; missing reagents can be collected in Shopping. Selection and shopping
list preparation never claim, craft, complete, buy, or send customer chat. Those
actions retain their existing click requirements. Regression tests cover both
settings, real row/menu callbacks, persistence and asynchronous open/close races.

## Request lifecycle and stable order lists (0.3.25)

A new public search for the same craft can renew an unanswered request once
30 seconds have passed since the greeting was actually sent. The existing row
is replaced by a fresh request at the bottom of the default chronological list;
the greeting is only proposed, never sent automatically. Claimed, crafted,
completed and answered requests are not reopened by this rule.

Different items in one message share one inquiry. New items less than 30 seconds
apart can join that inquiry; later searches start a separate one. An incoming
reply checks only the latest greeted inquiry, not every old order from the
customer. A newer ungreeted search cannot steal that reply. A late reply to the
previous greeting remains recognizable while its replacement is only proposed.
Linked chat carries exact inquiry/request identities and individual greeting
times; delayed packets cannot check a replacement request with a different token.
Battle.net history remains local. Deferred item/class lookups preserve linked
context without echoing orders or assigning ownership to the receiving character.

Manual Matching now sends the selected crafter's profession greeting directly
from the menu click, including numeric-string or expired chat-line IDs. Opening
the menu does not send anything. Tooltip history records raw chat events with
unique identities, preserves repeated short replies, and updates while hovered.

Explicit item links still outrank class inference. Explicit armor words such as
plate, mail, leather and cloth now select the matching profession instead of
disabling the class filter. Explicit professions override class as well. Generic
armor slots use the sender GUID and a verified class cache; missing class data is
retried briefly, then the ambiguous request is skipped rather than guessed.

Red problem highlighting applies only to personal crafting orders, never patrons.
Background refreshes update existing rows and reagent/reward icons in place;
they no longer hide/re-show the whole list or dismiss unchanged row tooltips.
Row positions are stable during background quality/profit recalculations.
Clicking a sort header or changing tabs applies a fresh sort. Tests cover these
cases alongside the existing click-only chat/crafting safety checks.

## Battle.net order checkmarks (0.3.24)

Incoming friend requests now show established contact in the first indicator,
without marking the proposed greeting as sent: sending still requires a click.
Crafting completion matches Battle.net rows through verified WoW character GUIDs
(preferred), or character and realm names from the current friends list, never
through a BattleTag/Real ID name. Game-order GUIDs survive completion snapshots
and linked notices, including orders that omit the customer's realm in the name.
Only online characters in the current WoW project and region are recorded. Each
request retains its local character snapshot across logout/alt switches; a new
request starts fresh. Existing rows can resolve currently available characters.

Ordinary completion notices from linked crafters can update a matching private
row locally. Battle.net conversations, character snapshots and private request
tokens are not added to the shared game-order journal. Realm, recipe and request
age checks still apply, and replaying a notice preserves a manually cleared mark.
If Blizzard does not expose a verifiable character, the manual mark remains
available; no character is guessed. Regression tests cover the scanner, contact
renderer, claim/craft/fulfill events, linked notices, identity isolation and replay.

## Finisher selection and order warnings (0.3.23)

Open **Finishers** in the right-hand crafting panel. Select one specific bonus
item and independently enable **Use for crafts** / **Use for recrafts**. These
apply only to personal orders, never patrons. No bonus item is selected by
default; craft is enabled and recraft disabled until explicitly changed.
The existing skill setting/limit is preserved and now labelled **Skill when
needed (highest priority)**. When enabled, requested quality takes priority over
the bonus item, using the weakest sufficient owned skill finisher within the
limit. If quality is already met, the selected bonus item may be used instead.

The Midnight picker distinguishes these exact item IDs:

| Bonus | Lesser item | Combined item (5 lesser items) |
| --- | --- | --- |
| Resourcefulness | [Resourceful Rebar, 247725](https://www.wowhead.com/item=247725) | [Resourceful Routing, 247726](https://www.wowhead.com/item=247726) |
| Multicraft | [Multicraft Matrix, 247719](https://www.wowhead.com/item=247719) | [Multicraft Manifold, 247724](https://www.wowhead.com/item=247724) |
| Ingenuity | [Ingenious Identifier, 260630](https://www.wowhead.com/item=260630) | [Ingenious Identity, 247788](https://www.wowhead.com/item=247788) |

Skill finishers remain Apprentice's Scribbles (246447, +5), Artisan's Ledger
(246448, +10), Mentor's Helpful Handiwork (246449, +20), and Artisan's Consortium
Gold Star (246450, +50). Other non-skill finishing items found in the current
recipe schematics are also offered. Names, item-quality colors and tooltips come
from the client; external tooltip stat values are not used for crafting decisions.
The live recipe must support/unlock the selected item, with enough owned quantity.
Missing items are skipped, never silently replaced or automatically combined.
Customer finishing slots and manually filled bonus slots are preserved. Skill
simulations restore the original allocation when unsuccessful; unavailable data
does not authorize a decline or a bare craft. Selection and submission still
require separate clicks, for both skill and non-skill finishers.

Problem rows are tinted red, including while selected. Hover the row for the
reason: missing customer/crafter reagents, unknown recipe, a recorded issue, or
insufficient quality under the current settings. Preview warnings do not prepare
the live transaction or trigger rejection. Unknown quality/schematic data is not
treated as proof of failure; the action rechecks the order before declining it.

## Battle.net right-click reply menu fix (0.3.22)

Prepared replies now appear when right-clicking a Battle.net name in chat, not
just in friend-list contexts. Chat hyperlinks supply the account ID as a numeric
string; the menu now safely normalizes it before resolving the friend. Invalid
or secret IDs still fail closed, without falling back to a character whisper.
Opening the menu never sends a message; selecting a prepared reply sends it to
the corresponding Battle.net conversation. Expanded and collapsed menus are
covered by regression tests using the chat hyperlink's actual context shape.

## Battle.net friend whispers (0.3.21)

The **Scan Battle.net whispers** setting is enabled by default. Incoming friend
requests use the existing keywords, monitored-item matching and exclusions.
Repeated links are deduplicated; distinct items get separate rows and grouped
greetings. Plain social messages do not create orders, but follow-ups in an
existing conversation feed its history and quick-reply suggestions. Sending
still requires a click, including the first proposed greeting.

Battle.net rows show a BattleTag, and replies use Battle.net rather than a
character whisper. IDs are resolved against the current friends list at click
time; session IDs and Real ID names are not saved. Unavailable, removed, secret
or mismatched recipients fail closed without switching transports. Right-click
chat menus also support manual matching, custom explanations and ignoring.

These private conversations and their exact status rows remain on the receiving
account: they are not proxied, added to analytics or included in linked journals.
The shared crafter configuration still supplies the available professions.
BattleTags are not assumed to be character names: automatic completion is not
inferred from a friend's display name; the manual completion mark remains usable.

Implementation follows Blizzard's
[Battle.net API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/BattleNetDocumentation.lua)
and [chat event payloads](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua).
Live client testing is still needed for account-specific chat restrictions/UI.

## Character rename migration (0.3.20)

Explicit account-owned rename records migrate monitored recipes, profession
settings, conversation ownership, crafter references and editable reply templates.
Existing settings win over fresh default profiles, while new-only recipes and
fresh concentration data are retained. Profile snapshots are kept for recovery;
customer identities, chat text and order-status identities are not rewritten.

Full linked accounts receive rename records from the owning account during
character-data synchronization. Remembered aliases suppress stale old-name
profiles and normalize later status/template packets. Conflicting profile owners
or cyclic renames are refused. All linked clients must use this version or newer;
no personal names or migration records are bundled in the release. Player-chat
replies still require a click.

## Customer class for generic armor requests (0.3.19)

Generic requests such as `need wrist` can now use the author's class from the
chat-event GUID: plate routes to Blacksmithing, cloth to Tailoring, and leather
or mail to Leatherworking. Exact keyword-matched recipes also need the requested
equipment slot and native armor subclass, so a hunter is not offered leather
bracers just because the same leatherworker knows both recipes.

The heuristic recognizes common English/Russian names for head, shoulders,
chest, wrists, hands, waist, legs and feet. Item/recipe links take precedence;
explicit profession/material words, non-armor items, enchants and alt/transmog
requests retain normal matching. Existing inclusion/exclusion filters, scanning
toggles, recipe monitoring and crafter priorities remain in effect. No matching
enabled profession means no substitution with the wrong armor profession.

When class information is unavailable, normal matching remains. When item
metadata is unavailable, only a profession-level response is offered, without
claiming the exact recipe. Valid class metadata travels with proxied orders
for linked clients that cannot resolve the author's GUID themselves.

The scanner setting **Use customer class for armor requests** is enabled by
default and can be changed without reload. Replies still require a click.
Regression tests cover all 13 classes, slot/subclass filtering, links, missing
APIs/data, exclusions, opt-out, proxy metadata and existing whisper conversations.
GUID/class lookup follows the
[Blizzard chat UI](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua);
item classification uses the documented `C_Item.GetItemInfoInstant` fields.

## Manual-action safety hardening (0.3.18)

Removed the legacy auto-greeting mode, its timers and settings UI, and the
robots.txt listener that could send unsolicited whispers after an addon packet.
All player-chat send paths now require an explicit manual caller. Greetings,
grouped item replies, quick replies, custom explanations and craft requests
remain available on click. Scanning, exclusions, item deduplication, suggestions
and linked-account data/status synchronization remain automatic, not sending
player chat or executing the recipient's gameplay actions.

The selling-tab commodity purchase now waits for a second click after receiving
the price quote. Releasing a claimed order for rejection also requires another
click to decline it. Removed the dormant buy-all execution path. Bank-event gold
transfers are disabled regardless of legacy settings; manual deposit/refill
buttons and commands remain. Existing SavedVariables are not wiped.

These are conservative risk reductions, not a finding that every removed
feature violated policy, and not Blizzard approval or an account-safety guarantee.
API availability does not by itself establish policy compliance. See the
[Blizzard UI Add-On Policy](https://eu.forums.blizzard.com/en/wow/t/wow-user-interface-add-on-development-policy/1642).
Regression tests cover event-versus-click behavior, legacy flags, repeated
clicks, price changes/expiry, and release/decline staging. Reload all game clients
after updating; live server behavior still needs an in-game check.

## Knowledge and shopping actions above the order list (0.3.17)

The Patron knowledge-queue button now sits above the order list, to the left
of the sidebar toggle. Shopping is beside it, with the compact cost on the
same line. Both actions remain available when the sidebar is collapsed;
on other order tabs Shopping moves next to the toggle without an empty gap.
The sidebar closes the vacated rows and retains Queue, Select all where
applicable, and Clear. Selection rules and shopping behavior are unchanged.

Layout tests cover anchors, alignment, tab changes, hidden/disabled views,
collapsed-panel clicks and exactly one action per click.

## Manual completion marks survive synchronization (0.3.16)

Clearing a completion check is now treated as an intentional manual edit, not
as lost automatic crafting progress. Linked accounts accept the newer clear
and cannot restore the old check by echoing a stale status snapshot. Replaying
completion history still respects the manual override.

Same-second edits use revision order within one source; across accounts an
otherwise tied manual edit takes priority over an automatic snapshot. Genuine
later events and new customer requests can still update the status. Automatic
fulfillment continues to take precedence over an earlier rejection. Regression
tests cover both merge directions, repeated packets, rapid toggles and reused
request rows. Reload all linked game clients after updating so they use the
same merge rules; the fix still needs confirmation in-game.

## One conversational quick reply for multiple items (0.3.15)

Identical rendered quick replies such as `hey hey` or `omw` now produce one
suggestion per customer, even when several items or templates generated it.
Clicking sends one whisper and removes equivalent suggestions; repeated clicks
on a hidden/reused card cannot send the old answer again. Different prices,
crafter names and item-link responses remain separate choices, as do event-only
rejection actions tied to individual orders.

A merged suggestion retains its original request identities and can use another
matching item if one row is dismissed. It cannot attach to a newer replacement
request or silently send template text changed since the card appeared. Tooltip
context includes all represented items. Regression tests exercise the actual
whisper-to-toast-to-click path with mocked UI and chat APIs.

## Long item links in grouped replies (0.3.14)

Grouped requests now wait for all item-cache loads and use the same compact
base-item links as single-item replies. Customer recraft links can carry long
bonus/modifier lists, GUIDs and quality icons; copying them into greetings caused
the old whitespace splitter to cut inside a hyperlink and WoW rejected the
message with `Invalid escape code in chat message`.

Message splitting now keeps whole hyperlinks (including named colors and
quality markup) together and respects UTF-8 character boundaries. A batch is
validated before any whisper is sent. Pending greetings are rebuilt on click,
even on the same character, repairing older saved fragments without deleting
the order rows or changing SavedVariables directly. Regression tests cover
long recraft links, saved fragments, out-of-order cache callbacks, automatic
and manual group sends, and invalid-message preflight. In-game delivery still
needs a check after `/reload`.

## Stable completion after a rejected order (0.3.13)

Replaying a linked-account rejection no longer turns a successfully completed
replacement back into a cross. For the same customer request, fulfillment takes
precedence over rejection even when the replacement has a different Blizzard
order ID or an older client inflated the rejection's timestamp/revision.

Journal replay resolves the matching outcomes together and preserves the
original event time instead of recording the replay as a new event. Existing
stale crosses are repaired when matching fulfillment evidence is available.
New customer requests, manual clearing and authoritative errors after optimistic
fulfillment remain separate. Regression coverage exercises repeated and
out-of-order replays, persisted stale statuses and request reuse with mocked APIs.
Update linked accounts too so both clients use the corrected merge rules.

## Monitored item links and multi-item requests (0.3.12)

Chat scanning now recognizes a link to an item from a monitored recipe even
without `LF` or other search keywords. Global and profession exclusions, ignored
customers, scanning toggles and concentration requirements still apply. The
scanner setting **Scan monitored item links without keywords** is enabled by
default and can be switched off to require search keywords again.

A message containing different monitored crafts creates a separate order row
for each. Clicking any unanswered row sends the normal greeting for the first
item, followed by separate whispers in the form `[item link] Send to Crafter.`
for the remaining items. All included rows are marked answered together;
clicking them again opens the conversation without repeating the greeting.
Repeated links, including bonus/quality variants of the same recipe output,
do not create extra rows or messages. Repeated requests reuse existing rows
until dismissed, expired or explicitly reopened as a new job.

Grouped replies preserve per-request tokens for linked accounts. Deleted or
replaced rows cannot be sent by an old group or delayed auto-reply callback.
The existing manual-reply policy for alt crafters is retained. Regression tests
cover matching, exclusions, deduplication, row actions and delayed sends with
mocked WoW APIs; actual chat delivery still needs an in-game check.

## Finishing reagents and recrafts (0.3.11)

Finishing reagents are allocated using the slot's position in the recipe
schematic, not its separate API `dataSlotIndex`. Before submitting a staged
craft, the addon verifies that the selected finishing reagent is still in the
transaction and in the outgoing reagent list. If an order update rebuilt the
transaction, another hardware press restores the finisher instead of crafting
without it. Submission uses Blizzard's per-slot customer ownership filtering;
recrafts also remove unchanged item modifications as the native order view does.

Regression tests cover different slot indices, a lost allocation between
presses, filtered-out finishing reagents and the recraft API payload. An in-game
recraft remains necessary to confirm the reported recording's symptoms are gone.

## Scanner recovery (0.3.10)

Stale chat-order references no longer abort dismissal, page refresh or login
when their customer/response is missing. Expired or incomplete rows are removed
without resetting profession settings or unrelated customer conversations.
The alert portrait falls back to a profession icon if its active order is stale.
An error in one scanner UI initializer is reported to WoW's error handler without
preventing the remaining initializers from running.

Scanner settings and profession-tab buttons now have HironCraft-specific global
identifiers, avoiding the remaining collisions with the original CraftScan.
Existing saved settings keep their values; no manual SavedVariables reset is needed.
These regressions have standalone test coverage; the reported user's exact
failure still needs confirmation in-game with their saved data/addon combination.

## Crafting orders interface (0.3.9)

The order list uses the full width of Blizzard's profession window, with the
control panel attached outside its right edge. Native buttons, framed panels
and gold selection highlights keep the classic WoW look. Cyrillic-capable
addon fonts keep Russian labels readable on English clients too. Existing
queue settings and key bindings are kept.

Use the small arrow above the order list's top-right corner to hide or show
the entire side panel, including its header. The arrow stays inside the main
window. This preference survives reopening and reloads; selected orders and
the hotkey still work while the side panel is hidden.
The toggle uses a centered drawn chevron and an inset 20-pixel button whose
textures stay inside its bounds, clear of the main window's border. Its own
four-sided outline remains visible even at small UI scales.

- **Crafting** contains reagent quality, concentration, finishers and tools.
- The **Queue** settings tab contains profit filters and automatic selection settings.
- Queue, knowledge selection, Shopping and Clear are always available beneath
  both settings tabs, alongside the action button, selection count and status.
  Settings scrollbars appear only when their contents do not fit.
- To select profitable orders plus all knowledge rewards, click **Queue**,
  then **Queue: knowledge**. The latter adds to the current selection and
  ignores minimum profit (including missing prices), without changing saved
  filters or previously selected reagents. Unknown recipes and orders requiring
  concentration remain excluded; missing reagents can be added to Shopping.
- Use the list's **+/−** button to switch between compact and detailed rows.
  Detailed rows include the customer. The **Profit** column stays visible in
  both layouts, including narrow windows. Additional icons are available
  through a plain **+N** hover label when their column is full.
- **Refresh** reloads orders when no order action is in progress. Clicking the
  item row still opens the original Blizzard order details.
- Labels are centered within the classic buttons; craft progress inherits
  the action button's scale and stays inside its border. The binding-clear
  control uses WoW's square close button. Empty lists show a single message.
- Choosing Patron, Guild or Public immediately stops the current automatic
  Personal-tab preparation. Auto on open still works on the next opening.
- Reagent icons have reserved spacing for quality badges and quantities.
  Profit has a wider column and remains on one line, using decimal gold or
  compact k/m notation when necessary. Hover for the detailed amount.
- Personal orders omit the redundant **Reward** column and use its space for
  the item name. Public, Guild and Patron orders keep Reward visible.
- Checking or unchecking an order no longer changes its sort position. Equal
  rows retain the order supplied by Blizzard across selection refreshes.

The reported finisher craft-start issue is not considered resolved by these
interface changes.

## First start and settings migration

1. Install the `HironCraft` folder on both WoW clients.
2. For the first login, leave the original CraftScan and ProfitHUB addons enabled. HironCraft imports their loaded SavedVariables into its own uniquely named databases.
3. Log in once on every character whose per-character ProfitHUB settings must be copied.
4. Log out or run `/reload`, disable the original CraftScan and all ProfitHUB modules, and keep only HironCraft enabled.
5. Repeat the installation and migration on the second linked account. Both accounts must run HironCraft to use its isolated `HIRONCRAFT_SCAN` communication channel.

If the first login was made with the originals disabled, enable them and run `/hcmigrate force`, then `/reload`.

Commands:

- `/hc` or `/hironcraft` — open HironCraft settings
- `/hcs` or `/hironcraftscan` — open the chat scanner configuration
- `/ph` — open the integrated workflow settings
- `/hcmigrate force` — overwrite HironCraft settings from currently loaded original addons

## Updating

Only update or replace the `HironCraft` folder. Updates to `CraftScan`, `AhUI` or the old ProfitHUB module folders do not change this addon.

Run `scripts/Build.ps1` to create a clean versioned ZIP without repository and development files.

On Windows, `scripts/TestReleaseArchive.ps1 -Archive dist/HironCraft-<version>.zip`
checks ZIP paths and every file hash, then copies the addon through Explorer's
compressed-folder handler and verifies the extracted files against the source.

For installation, use **Extract All** first, then copy the extracted `HironCraft`
folder into `World of Warcraft/_retail_/Interface/AddOns`. If Explorer reports
0x80004005 while dragging out of an older ZIP, cancel that copy and use the new
release archive. Do not keep a partially extracted addon. Restart WoW or run
`/reload` after replacing the files; keep your `WTF` folder/settings untouched.

The editable high-resolution icon source is kept in `artwork/`; the game uses the optimized `Media/HironCraftIcon.tga` version. A PNG preview is stored beside it.
