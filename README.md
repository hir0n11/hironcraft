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

## A message the game refuses is not taken for sent (0.4.121)

What stopped the first `/hcchatlimit` is known from the error log: the game
does not cut a message that is too long. It raises `SendChatMessage(): Chat
message limits exceeded` and sends nothing.

- A reply the game refuses this way no longer breaks the click silently:
  the crafter is told `Reply could not be sent: the game refused the message
  (...)`, and the row is not marked as answered.

## `/hcchatlimit` says what stops it (0.4.120)

The first run of `/hcchatlimit` in the game printed its opening line and
then nothing: it broke on its first step and did not say so. It is rewritten
to take nothing for granted about the game:

- A send that raises an error is caught and its text is printed; a step
  that breaks stops the measuring with a line that says why.
- It starts with a short whisper to yourself and stops with the game's own
  words when that does not arrive.
- A long message may be cut, dropped or refused: when it is not cut, the
  longest whisper that arrives is searched, and what a link and its quality
  icon take is tried out with whispers that fill one exactly.
- Where an addon may whisper only on a key press, it says so and asks for
  the command again for every step.
- A run that died is not waited for: after a minute the command starts over.

## A greeting for several crafters: a whisper per crafter again (0.4.119)

0.4.118 joined everything one click sends into one whisper, also a greeting
for several items or professions: `Hi! Send [A] to Seller. [B] Send to
Tailor. [C] Send to Seller.` in one line is hard to read. That part is taken
back: what goes to another crafter is a whisper of its own, as before.

- Still one whisper when it fits: the lines of one text (a greeting or a
  text of the chat menu written in several lines), and the reply about
  materials, which names its items when their links would make it too long.
- The sender itself joins nothing any more; joining is done where one text
  was split into lines.

## One whisper where one is enough; a recraft asked for in public chat (0.4.118)

**One whisper.** Someone who gets two whispers in a row takes the sender for
a bot. Everything the addon sends to a player now goes out as one whisper
whenever its text fits one:

- Lines sent by one click are joined. A greeting for several items or
  professions was a whisper per crafter (`Hi! Send [A] to Seller.`, then
  `[B] Send to Tailor.`); a greeting written in several lines was a whisper
  per line. They are one whisper now, and only what does not fit together
  stays apart. The same holds for quick replies, the reply about materials,
  the reason of a decline and the texts sent from the chat menu.
- The reply about materials writes items as links only while the whole reply
  fits one whisper. When the links make it too long, the items are named
  instead (about five items fit as links, six by name). Only a text that is
  too long even by name is split.
- `/hcchatlimit` measures what one whisper really holds, with a few whispers
  to yourself (about half a minute): the number of letters, whether Cyrillic
  is counted by letters or by bytes, what a link and its quality icon take,
  and how many bytes arrive whole. It prints the result and saves it in the
  settings (`chat_limit_probe`); the measure in `Utils/ChatLength.lua` is set
  from it. The scanner ignores these test whispers.

**A recraft asked for in public chat.** A customer who got their item and a
few minutes later wrote `LF recraft [that item]` in Trade was passed over:
with the row of the delivered order still listed, the line looked like a
repeat of a request that was done. Now a line in public chat that has a
recraft phrase (Settings - Matching, "Recraft requests") next to the item
that was delivered to them in the last 24 hours, or its slot, adds the
request again, marked `(recraft)`, like the whisper "can you recraft?" does.

- Without the item it is not taken to be about that delivery: in public
  chat `LF recraft` is anyone's line.
- Another item, or a player nothing was delivered to, is an ordinary
  request as before. The old line repeated without the phrase stays passed
  over.

## Five linked items in one whisper (0.4.117)

0.4.116 still counted the quality icon inside an item's name in full (about
50 letters) and kept a message under 500 bytes, until that was checked. It
was: a whisper of eight links of a reagent with its quality icon, 1016
bytes, arrived whole. So an icon is counted as 4 letters (the most that
whisper leaves for it) and a message may take as many bytes as that one.

- The reply about materials holds about five linked items in one whisper
  (two in 0.4.116); more take a second one.

## Item links in the reply about materials (0.4.116)

The reply about an order's materials writes an item as its link again, where
it wrote its name: the item to replace, and for a missing one the item of the
quality that is needed. 0.4.106 did this and 0.4.107 took it back, because a
link was believed to cost about 110 of the 255 bytes of a whisper, so every
item took a whisper of its own.

That was wrong. The game counts what is shown: the code of a link (its color,
`|H...|h`, `|r`) is not counted, and a link takes what its `[name]` takes.
Checked in the game: a whisper of six item links and 508 bytes sent by the
addon arrived whole.

- One or two linked items fit one whisper, three or four take two. When a
  reply is split, a count stays with its link and a link's phrase is kept
  whole, as in 0.4.106.
- The reason of a decline sent again (`DECLINE REASON`) uses links as well.
- The measure is used for everything the addon sends: a greeting or a quick
  reply with an item or profession link is no longer split, or refused,
  because of the bytes of the link's code.
- Two things stay on the safe side until they are checked: the quality icon
  inside a name is still counted in full (about 50 letters), and a message
  stays under 500 bytes.
- Without item data the name is used and the data is asked for once. A
  snapshot never carries a link; it is made from the item's number when the
  reply is built.

## Collecting analytics is a setting (0.4.115)

The `Collect data` checkbox has left the toolbar of the analytics window. It
is now `Collect analytics data` in the HironCraft settings (the page with the
sounds and the chat filter), switched on by default.

- It is one switch for the whole account now. It used to be kept per realm,
  so it could be off on one realm unnoticed.
- What the old checkbox left behind is dropped: an account that had it
  unticked starts with collecting switched on once. Unticked in the
  settings, it stays off.
- While it is off, the analytics window says `Data collection is off
  (settings)` next to the search box, and a linked account that asks for an
  exchange is told where to switch it on.

## The reason of a decline, again (0.4.114)

A customer who missed the reply about a declined order asks why it was
declined. The reply could not be offered a second time, and the order's row
has usually left the list by then. Now the reason can be sent again:

- **By a whisper.** When a customer whose order was declined in the last 24
  hours whispers a question like `why?`, `why declined`, `what's wrong`, a
  reply card with the reason appears; a click sends it. Several declines get
  a card each, the newest first, with the item and the time in the card's
  tooltip.
- It is a quick reply of its own, `DECLINE REASON`, in the quick reply
  settings: its keywords and its text can be edited there, and switching it
  off stops the cards. Its keywords count only for a customer who was
  declined, so `why` does not compete with the other replies.
- **By hand.** The menu of a player's name in chat lists `Decline reason:
  item - crafter, time` for their declines of the last week; the tooltip
  shows the text and a click sends it.
- The reason is rebuilt from the decline itself (the order's saved status
  keeps its material list for a month, also on a linked account), so it does
  not need the row. A declined order that was taken again is no longer
  offered.

## The recraft of what was just made (0.4.113)

- `u can recraft it ?` right after a craft was answered with "several orders
  were delivered to them lately, choose one" when the same customer had
  another delivery earlier that day. Of several deliveries in the last 24
  hours, the only one of the last half hour is taken now: that is the one
  they mean. Two or more in that half hour, or none, are still not guessed
  at.

## Completed orders leave the list (0.4.112)

- The last completed order could reappear from the list's anti-flicker
  snapshot, especially on the Public tab. Completed orders are now excluded
  from that snapshot too; unfinished rows keep their stable positions.
- A completed order cannot be submitted again from a stale row or cached
  claimed-order data. Repeated presses while completion is pending do nothing.
- A failed completion still allows an explicit retry, including when the
  game API throws an error before it can send a response.

## Expansion buttons (0.4.110, off by default since 0.4.111)

The game shows one expansion of a profession at a time and changes it only
by the dropdown on the recipe page. Two places now have buttons for it:

- **Patron orders.** On the Patron tab of the crafting orders, above
  `Shopping` / `Queue: knowledge`: a button for each expansion with patron
  orders (`Midnight`, `TWW`) that the character has trained. The one on
  screen is marked; a click switches the profession to the other and the
  list follows. It is the same switch as the button in the sidebar, which
  is out of reach while the sidebar is collapsed. Shown only when there is
  more than one such expansion.
- **Specializations.** On the Specializations page, to the left of the
  knowledge points bar: a button for each expansion of the profession that
  has specializations, named as the game names them (`Midnight`, `Khaz
  Algar`, `Dragon Isles`). The trees and the knowledge bar follow.
- Both are off until switched on in the settings, under `Additional
  modules`: `Expansion buttons: patron orders` and `Expansion buttons:
  specializations` (on by default in 0.4.110, off since 0.4.111).

## A slot named beside a linked item (0.4.109)

- `neeed to craft [Thalassian Competitor's Signet] and the neck` made a row
  for the signet only: a message with an item link was answered by its links
  alone, and the words beside them were never read. Now the text outside the
  links is read for slots as well, and every slot it names gets its own row
  (`Neck`), greeted together with the linked items and shared with a linked
  account as one request.
- Not counted as another request: the slot the linked item fills itself
  (`LF [Signet] ring` is one row) and a slot word inside an item's name.
- An armor slot named beside a link (`[Signet] and wrist`) still needs the
  customer's class, like a slot named alone: its row is added once the class
  is known.

## Recraft requests (0.4.108)

A customer who got their order often comes back for a recraft: wrong stats,
the wrong embellishment. By then the row of that order has left the list (it
goes ten minutes after the request), and nothing in "can you recraft?" says
which item is meant. Now a new request for the same item is added:

- **By a whisper.** When a whisper has one of the phrases from Settings -
  Matching - `Recraft requests` (`recraft, re-craft, remake, redo, craft
  again, ...`; edit the list there, empty switches this off) and one thing
  was delivered to that customer in the last 24 hours, a row for the same
  item, crafter and profession is added, marked `(recraft)` after the item's
  name. It behaves like any request the customer whispered: the greeting
  waits for a click, the marks start over, analytics count a new request.
- **Several deliveries are not guessed at.** If the whisper links the item or
  names its slot, that delivery is taken. Otherwise a line in chat says that
  they ask for a recraft and that the crafter has to choose.
- **By hand.** The menu of a player's name in chat (HironCraftScan - Manual
  Matching) lists `Recraft: [item] - crafter` for what was delivered to them
  in the last week, up to six. A click adds the row with the usual banner;
  Shift+click adds it quietly, as already greeted.
- What was delivered is read from the orders' saved statuses (customer,
  recipe, crafter; kept for a month and shared with linked accounts), so it
  works for orders delivered before this version and whether or not the row
  is still listed. A row that is still listed becomes the new request. A
  delivery whose crafter is not set up on this account is not offered.
- A linked account is told which delivery is asked for again and adds the
  same row under the same request (both sides need this version).

## Names again in the reply about materials (0.4.107)

- 0.4.106 wrote items in `{reagent_issues}` as links. A link takes about 110
  of the 255 bytes a whisper holds, so a reply about two or three items went
  out as two or three whispers; that is not worth it, and 0.4.106 is undone
  in full: the reply names items as before (`Could you replace 5 T1
  Glimmering Gemdust with T2, please?`), and replies are split into whispers
  as before.

## Specialization ranks to try, panel in English (0.4.105)

- The `Specialization` view tries other ranks the way `Simulation` tries
  other reagents. Each node has a box with its rank: type another one (`-`
  for a node not unlocked) and everything is counted with it in place of the
  character's own. `Your ranks` returns every node to what the character
  has, `All maxed` maxes every node of the recipe. A tried rank is gold.
- On top of the view is the craft itself, as `Simulation` has it (the same
  scale and the line with skill, quality and what the top quality still
  needs), at the skill the tried ranks would give. Below it: `Tried: +50
  skill, +10 points (3 unspent)`, the change of skill, the knowledge points
  it takes more (or fewer, to see where points could have been saved) and
  the points the character has left. Unlocking a node counts as free; a
  rank is one point.
- The stats show what is tried against the maximum, with the change in
  brackets: `80 (+50) / 85`.
- A node's tooltip tells where its skill comes from: what each rank gives
  and what is gained at which rank (`Rank 25: +40 Skill`), green when the
  rank shown has reached it. Only what counts for the selected recipe is
  listed, so it shows which ranks are worth reaching and which are not.
- The ranks tried stay with their nodes from recipe to recipe until `Your
  ranks` is pressed or the game is reloaded, and they count in `Simulation`
  as well, which says so (`With the ranks tried: +50 skill`): reagents and
  ranks can be tried together.
- Not modelled: that a node needs points in its parent before it opens, and
  nodes that do not affect the selected recipe. The game's own page has the
  last word on what can be bought.
- The whole panel is in English now, whatever the addon's language is.

## Required slots with a choice of reagents (0.4.104)

- Fixed the skill panel breaking on a recipe with a required slot that takes
  one of several different reagents (`Competitor's Heraldry` on PvP gear has
  six). The panel treated them as six qualities of one reagent while it has
  room for three, and its recount stopped halfway: the slot's row slid out
  of the panel to the left, the lists below were empty, and the skill, the
  scale and the quality shown were those of the recipe selected before.
- Such a slot is a list now, like the optional ones: its button names the
  slot and the reagent chosen, and the list offers `as in the window`,
  `empty` and the reagents gathered by what they do to difficulty and skill.
  The quality presets leave it alone.
- If a view of the panel ever fails again, the failure goes to the error log
  as before, and the panel says it has no data instead of leaving another
  recipe's numbers on screen.

## What the specializations give a recipe (0.4.103)

- The skill panel has two views now, chosen by the tabs under its title:
  `Simulation` (the craft tried with other reagents and skill, as before) and
  `Specialization`. The view left open is remembered.
- `Specialization` shows, for the selected recipe, what its specialization
  nodes give now against what they would give when maxed: skill, multicraft
  and its extra items, resourcefulness and its extra items, ingenuity and its
  refund, less concentration use, crafting speed. Only the stats the nodes of
  this recipe can give are listed, and multicraft, resourcefulness and
  ingenuity only for a recipe that has that stat (a piece of gear cannot be
  multicrafted). A stat already at its maximum is green.
- Below are the nodes that give this recipe something, each with its icon,
  name and rank: the maxed ones first (green), then by rank, the ones not
  unlocked yet last (grey, no rank). The view does not need a recipe with
  quality, and it works for a recraft too.
- Which nodes and perks affect a recipe and what each gives is CraftSim's
  data for Midnight (MIT, `LICENSE-CraftSim.txt`), converted by
  `scripts/ImportCraftSimSpecData.lua` and counted the way CraftSim counts
  it, so the numbers should match its Specialization Info. After CraftSim
  updates its data for a patch, run the script again:
  `lua5.1 scripts/ImportCraftSimSpecData.lua "<AddOns>/CraftSim"`. Recipes of
  earlier expansions have no data and say so.
- It costs nothing while the other view is shown or the panel is closed. Shown,
  a recount reads the ranks of the recipe's nodes (a handful); names, perk
  ranks and the recipe's stats are asked once.

## Part of a slot at another quality (0.4.102)

- Each quality reagent row has, per quality, a button and a box: the button
  puts the whole slot at that quality, the box says how many of the slot are
  of it. Typing a number tries a slot partly at one quality and partly at
  another; the slot stays full (the other qualities keep what they had, the
  highest first, and the lowest takes the rest), and no more than the slot
  holds can be entered. The boxes start as the slot is filled in the window.
- The `=` button per row is gone; `As in window` above the rows returns all
  of them to the window's reagents.

## One-block skill panel, crests (0.4.101)

- The skill panel is one block now. The part that repeated the game's own
  Crafting Details (difficulty, skill, the comparison rows) is gone; what the
  panel adds stays on top: the scale with every quality's threshold, a line
  with skill, quality and what is missing for the top one, concentration and
  the reagents' cost. Below it are the reagents and the `+/-` skill to try.
  It starts as the craft is set up in the window, so nothing is lost, and a
  recount is one question to the game instead of three or four.
- The scale follows what is tried, including another skill. Quality names are
  above the bar and the skill each needs below it, so close thresholds no
  longer run into each other.
- Crests and other currency reagents can be chosen in the lists (`Infuse with
  Power` used to offer only `as in the window` and `empty`). They are not
  priced, and that is not counted as a missing price.
- The presets for all quality slots are labelled `Quality of all reagents`:
  `As in window`, `Highest`, `Lowest`.

## Skill button by Create, shorter reagent lists (0.4.100)

- The `Skill` button sits inside the profession window, right above `Create`,
  instead of outside its right edge. Its label is set again each time it is
  shown: the button can be created before the addon's language is applied.
- The lists of optional and finishing reagents in the simulation show one line
  per effect instead of one per reagent: reagents that change difficulty and
  skill by the same amounts are gathered (`Missive of the Aurora and 5 more
  (quality 1): difficulty +25`), so a dozen missives that differ only in the
  stats they give become one line per quality. Picking a line uses its first
  reagent. The game is asked what each reagent does only when a list is first
  opened for a recipe (once per reagent), and never again in that session.
- The `Attach HironCraftScan` button is as wide as its text needs.

## Craft simulation (0.4.99)

- The skill panel has a second part, opened by its button: the selected
  recipe tried with other reagents and another skill. Nothing is spent and
  the reagents need not be owned.
- Reagents: a row per quality slot with `=` (as in the window) and the
  slot's qualities, three presets for all slots at once (as in the window,
  best, plain), and a list per optional and finishing slot (as in the window,
  empty, or one of its reagents). Slots the character cannot use yet are
  left out.
- Skill: a `+/-` box; the button beside it puts in what the chosen reagents
  lack for the top quality.
- Result: skill, quality, what is missing, the concentration cost of the next
  quality and the cost of the reagents by HironCraft's prices (marked when a
  price is unknown). Concentration is known for the real skill only: the game
  prices it, and it does not price a made-up skill.
- One question to the game per change of reagents; another skill is
  arithmetic on the last answer. With the simulation closed the panel costs
  what it did in 0.4.98. Choices belong to the recipe and start over with
  another one.

## Skill needed for each quality (0.4.98)

- The `Skill` button outside the profession window's right edge opens a panel
  for the selected recipe: its difficulty (the skill the top quality needs),
  your skill split into your own and what the reagents add, a scale with the
  threshold of every quality, and how much is missing for the top one.
- Three sets of reagents are compared: the ones chosen in the window, the best
  and the plainest quality in every slot (optional and finishing reagents stay
  as chosen). The panel also shows what concentration costs for the next
  quality.
- Skill, difficulty, quality and concentration come from the game for each set
  of reagents (three questions per recount); the thresholds are shares of the
  difficulty (20/50/80/100% for five qualities, 50/100% for three), replaced
  by the game's own numbers where it reports them. Current character only.
- Built not to slow the profession window: nothing is created or asked until
  the panel is first opened, a closed panel costs nothing, an open one
  recounts the selected recipe at most once a frame and only after a change.
  The time of the last recount is kept in the saved variables
  (`HironCraftProfit_DB.craftSimulator.lastMs`). The panel can be dragged; its
  place and whether it is open are remembered.
- The idea comes from CraftSim's recipe info; no CraftSim code or data is
  included.

## Shared profiles, a key for Open All (0.4.97)

- Crafter pool profiles are the same on every linked account (full or
  analytics link), so each account records and counts by the same lists. They
  travel inside the analytics offer: a change goes at once to the accounts
  that are online, busy or not, and an account that was offline is brought up
  to date within a minute of being online. Each profile is whichever side
  changed it last; a deleted profile stays deleted. Another realm's profiles
  are not taken. An older HironCraft on the other account ignores them.
- The history from before recorders were kept counts for the oldest profile,
  the same one on every account. If two accounts had each made a profile
  before this version, both appear on both; delete the one not wanted.
- A new profile says in chat who is in it.
- Mailbox: the small button left of `Open All` assigns a key (or a side mouse
  button) that presses `Open All`; Shift + right click clears it. The key is
  an override binding that exists only while `Open All` is on screen, so it
  keeps its usual meaning elsewhere and the game's key bindings are not
  touched. Saved for the account.

## Updating from GitHub (0.4.96)

- `Update-HironCraft.cmd` in the addon folder (double-click it; it runs
  `Update-HironCraft.ps1`) compares the installed version with the one on
  GitHub, downloads the newer one and copies it over the installed files.
  Settings live in the game's `WTF` folder and are not touched. Restart the
  game afterwards. From a command line:
  `powershell -ExecutionPolicy Bypass -File "<AddOns>\HironCraft\Update-HironCraft.ps1"`.
- Nothing is changed unless the download is complete (every file the `.toc`
  lists is there); the `.toc` is written last, so an interrupted update is
  simply done again. A newer installed version is not downgraded, and a git
  checkout is never overwritten. `-Force` reinstalls the same version,
  `-Clean` also deletes files the new version does not have, `-Source` takes
  a `.zip` or a folder instead of GitHub.
- The knowledge points bar is drawn with the addon's own font: its label is
  in the addon's language, and the game's font on an English client has no
  Cyrillic.

## Crafter pool profiles (0.4.95)

- A profile is a named list of characters, this account's and the linked
  accounts', whose work is counted together. Profiles belong to a realm (its
  connected realms included) and live in that realm's analytics journal. The
  list on the analytics toolbar picks one or `All characters`, makes, renames
  and deletes profiles, and ticks each profile's characters (known crafters,
  linked accounts' characters, everyone who has recorded, or a typed name).
- While a realm has no profile nothing changes. Once it has one, a character
  in none of them records nothing: no time online, no requests, no greetings,
  no orders. What linked accounts send is still kept.
- Every recorded event names its character (`w`). A profile counts the events
  its characters recorded. Events from before 0.4.95 have no recorder: orders
  and crafts go by their crafter, everything else counts for the first profile
  made on the realm, which also starts with every known character.
- A realm's journal no longer takes the account-wide order journal of other
  realms' crafters on the first login there.
- Not yet: profiles are set per account (they are not sent to linked accounts),
  and another realm's profile cannot be opened from this one.

## Faster analytics window (0.4.94)

- Unpacked journal stores stay in memory until the interface is reloaded (the
  most recently used, up to 40,000 events, roughly 25 MB): opening the window
  again unpacks nothing, and a range that is wholly in memory is answered at
  once instead of over a dozen frames.
- Stores are packed by the game's own encoder (CBOR, deflate, base64) instead
  of LibSerialize + LibDeflate. A store is written that way only when unpacking
  it gives back exactly what went in; otherwise, and where the encoder is
  missing, the libraries are used as before. Older stores are repacked the
  first time they are unpacked, the rest one at a time while the window is
  open. An older HironCraft cannot read repacked stores: after a downgrade
  their history is not shown, though nothing is deleted.
- Mention events (item links in chat, not recorded or shown since 0.4.65) are
  removed from the journal as its stores are unpacked; a store of nothing else
  disappears. Mentions sent by an older linked account are not taken. Data
  that cannot be read is never removed.
- The report asks the clock once per quarter of an hour instead of four times
  per event; unpacking is paced by time (10 ms a frame) and reuses its frame.
- `analytics.perf` in the saved variables keeps what the last load cost:
  stores, how many were unpacked, how many are in the game's format, and the
  milliseconds spent unpacking and counting.

## Knowledge points bar (0.4.93)

- The Specializations page shows `Knowledge Points  earned / total` for the whole
  profession, in the free strip above the tabs on the right. The total is what
  every path of every tab takes; unlock tiers are not points, as on the dials.
- The solid part of the bar is spent, the pale part is earned and not spent yet.
  Staged purchases move points from pale to solid; the number does not change
  until more knowledge is earned.
- A profession without specializations has no bar.

## Cached profession links across linked accounts (0.4.92)

- Cache the current character's server-issued trade links on login and skill/
  profession updates. Log into each crafter and open their profession once after
  updating both computers. Missing API data never replaces a good link with nil.
- `{profession_link}` uses the selected crafter's full name/realm and base skill
  line, including an alt or a crafter on a linked account. Validate complete links
  and their owner GUID; never borrow the collector's profession. Until a link is
  available, use the profession name. Existing custom substitution tags can refer
  to `{profession_link}`; no saved message/tag text is rewritten automatically.
- Cache changes share only parent-profession data via existing full-account links
  and BULK transport. Unchanged captures send nothing; revision exchange repairs
  missed updates after a relog. Parent-only first arrivals still request the full
  recipe catalog, even at the same revision. Analytics-only links are excluded.
- Pending greeting previews rebuild after a profession revision arrives. Quick
  Replies and Custom Explanations reuse the same context; all chat stays manual.

## Profession links in greeting templates (0.4.91)

- Allow `{profession}` and `{profession_link}` in item greetings for the current
  character and alts, the alt profession greeting/suffix, and the busy suffix.
  The existing profession greeting, Quick Replies and Custom Explanations also
  support the link. Unknown placeholders still block saving; the generic request
  greeting has no profession context and does not accept profession placeholders.
- Use the existing response context: the current crafter's clickable link when
  available, otherwise the profession name (including another crafter's replies).
  Tooltips explain the fallback and curly-brace syntax. Saved texts and manual
  click/hotkey-to-send behaviour are unchanged.

## Public-order counter layout (0.4.90)

- Place the native Orders Remaining counter above Shopping, with clearance for
  its decorative background. It no longer shares the shopping total's space or
  pushes into the order-type tabs. Counter values and the recharge tooltip are
  still managed by Blizzard; order and purchase behaviour is unchanged.

## SharedMedia sounds, minimap spacing and return tooltip (0.4.89)

- The sound selectors include WhisperAlert's original `wisp.OGG`, bundled as
  `Media/WhisperAlert.ogg`. It can be previewed and selected for scanner alerts,
  incoming whispers or personal orders without WhisperAlert/LibSharedMedia.
  Current selections are preserved; the separate addon is not disabled or
  removed automatically. Disable it yourself to avoid duplicate whisper alerts.
- Also includes 107 available WeakAuras SharedMedia sounds (106 bundled files
  plus one Blizzard sound ID), with their original labels, licences and credits.
  No fonts/textures/media library are required. Known old selected paths migrate
  to the bundled copies; a still-loaded external library does not duplicate them.
  Longer clips keep temporary unmute active until playback can finish.
- The profession indicator now anchors beyond the mail icon's actual texture,
  with a gap, rather than its narrower layout slot. Mail appearing/disappearing
  repositions the default indicator; custom dragged positions remain unchanged.
- Remove the red missing-price line and asterisk from the overall reagent-return
  metric. Historical prices, including Auctionator records, remain unchanged;
  quantities without a saved price remain inspectable in the detailed report/CSV.

## Chat tools, linked filters and faster reagent prices (0.4.88)

- Save chat text keeps a bounded 2,000-line public-text cache independently of
  display filters. Open menus retain a snapshot; expired API entries can fall
  back to the exact line ID in chat history. Secret text and chat lockdown are
  still respected; there is no approximate author/text matching.
- Personal-order profession icons occupy the stock minimap indicator slot.
  Counts sit outside each icon and accommodate multiple digits. Manual dragging,
  scaling and reset remain available; disabling restores the stock hammer.
- Chat-filter rule definitions, names, enabled/whole-word flags and deletions
  sync across fully linked accounts. Initial libraries merge; per-rule revisions
  and persistent deletion records reconcile offline changes on reconnect.
  Concurrent changes converge deterministically. Logs, hit counts, ignore lists
  and general filter switches stay local. Bulk batches do not use the urgent
  order-status channel. Update all linked clients to use this feature.
  An editor opened before a remote change requires reselecting the updated rule
  before saving, preventing stale form values from silently undoing the change.
- The auction footer has a separate Scan reagent prices button beside the full
  price scan, using the same targeted catalogue/progress as Returns analytics.
  Cached-key preloading avoids silently ignored searches. Requests advance on
  results/server-ready events, without a fixed second per reagent; only one
  search is outstanding. Manual activity yields for two seconds and waits for
  active purchases/sales. The server's throttling, timeouts and old prices on
  missing results are preserved. Historical return values are not repriced.
- Fix Settings initialization: the indicator-reset button now supplies the
  required Blizzard search-tag argument instead of causing an assertion.

## Order tools, notifications and targeted prices (0.4.87)

- Public/Personal/Patron lists now use the page's own answered orders, scoped
  to tab, profession and expansion, instead of the shared last-result cache.
  Switching scope immediately hides old rows and cancels the previous callback.
  Same-list refreshes keep the existing anti-flicker behaviour and selections.
  Public's remaining-order count sits beside Shopping; knowledge is Patron-only.
- Right-click the floating scanner portrait to open Analytics.
- Personal-order icons beside the minimap show the current character's actual
  server counts by profession. Shift-drag to move; Settings offers scale, reset
  and the option to restore the standard hammer. Counts are not guessed for alts.
- Settings now contains built-in Blizzard sounds with previews for whispers,
  scanner alerts and new personal orders. Whisper alerts include Battle.net.
  Alerts can temporarily enable muted/background audio and restore its previous
  state, including overlapping alerts. Master volume is not changed.
  Disable the separate WhisperAlert addon to use the integrated whisper sound:
  HironCraft deliberately yields when that addon is loaded to avoid duplicates.
  No external addon is deleted or disabled. SharedMedia sounds remain optional.
- Opening the auction house refreshes missing or 15-minute-old prices only for
  unique exact-quality reagents in the complete resource-return history,
  including linked history and unpriced returns. The Returns tab has a manual
  refresh button and progress/time. The scan yields to manual queries for
  15 seconds and waits while a purchase/sale or shopping scan is active.
  Server throttles, timeouts and closing the auction house are respected.
  Missing listings retain the last successful price; they never write zero.
  New returns freeze the latest successful HironCraft scan price. If none
  exists they remain unpriced. Historical values are never recalculated.
- Custom Explanations > message > Assign hotkey captures a combination such
  as Shift+1, shows any overridden action and requires Save. The key works
  only on the customer row under the cursor (including its child cells).
  Tags use that exact row, not another order or the last whisper. No sends
  while typing or in combat, no send on hover; repeated same messages have
  a six-second cooldown. Rename preserves the key; delete/removal releases it.

## Preserve the customer before declining an order (0.4.86)

- Capture an owned copy of customer/recipe identity when an order row is
  displayed, before sparse claimed/row-state data or a list refresh can erase
  it. Restore missing fields only from the same exact crafting-order ID.
- If identity or the status recorder is unavailable, leave the order intact
  and selected with a clear retry message. Loading data never submits an
  automatic decline: another player action is required.
- Capture materials with the recovered identity before Release/Reject, then
  use the existing durable status/audit delivery. Regression coverage includes
  Hentihunter's bracers, neighbouring customers, relog replay and a later
  successful replacement order. Previously unrecorded declines are not guessed
  or retroactively inserted; current fulfilled marks remain unchanged.

## Compare requests, greetings and orders on the time charts (0.4.85)

- Hourly and calendar charts open in All stages mode: a broad grey Greeted
  bar contains a narrower yellow Ordered bar; a slim blue Requests bar
  sits beside it. The series share a zero baseline and a count scale.
  They are not added together: Ordered is part of Greeted, while requests
  and greetings can fall in different hours or days.
- Orders done remain in every hover tooltip, alongside conversion, order
  income and online time. The green online gauge stays below each group.
  In All stages, the number over the yellow bar is Ordered.
- A shared legend and subtle numbered grid make both charts easier to
  compare. Separate metric views remain in the dropdown and use consistent
  colours. Existing installations start in All stages once, then retain
  the chosen view. Calendar drill-down, filters and CSV contents are preserved.

## Independent profession qualifiers in equipment lists (0.4.84)

- Mixed requests such as "LF loa Ring crafter and crafter for plate wrist
  and tailor for cloak" now keep each equipment group's profession/material:
  Ring goes to Jewelcrafting, plate Wrist to Blacksmithing, Cloak to Tailoring.
  A later profession no longer redirects the whole list or discards jewelry.
- Groups separated by and, commas, semicolons, slashes, plus or ampersand
  retain shared compatible qualifiers, including trailing qualifiers on a
  uniform list. Fixed-profession items do not inherit an incompatible armor
  crafter. Existing enchant restrictions and configured aliases are preserved.
- Requests remain manual-send only. Follow-up item links replace only their
  matching slot/profession row, and an unavailable smith never falls back to
  a tailor. Install the update on the scanning clients as well as crafters.

## Stable analytics refresh and current calendar periods (0.4.83)

- Background updates keep the displayed charts, totals and tables intact
  until the next snapshot is ready; they no longer flash a blank chart or
  the central loading message. Manual date changes retain the old view with
  a small loading status, and obsolete results cannot replace a newer view.
- Local notifications and linked-account batches share one pending refresh.
  Updates arriving during a load request one follow-up instead of repeatedly
  restarting it. No additional sync traffic is generated.
- Tables reuse their provider and visible rows while ordered identities are
  unchanged, updating values and hover data in place. Actual additions,
  removals and reordering retain the scroll box's scroll-position behavior.
- Selecting Week, Month or Year in the calendar dropdown always opens the
  current period, clearing historical drill-down. Previous/next and Current
  still work, and day/month drill-down remains available.

## Order income tooltips and useful year drill-down (0.4.82)

- Every hour/day/month tooltip now includes gold received from orders in
  that interval, net of the recorded Consortium cut, using the same logic
  as the summary total. Income follows delivery time and the active filters;
  duplicate results and declined orders do not contribute. Legacy estimated
  cuts and missing tip data are explicitly marked, not presented as exact.
- In Year mode the lower chart stays on the year's twelve months. Above it
  are the selected month's days; click a day for its hours, then use Month
  days to return. Clicking another month updates the detail without losing
  the year. The main date filter follows explicit month/day selections.
- A newly opened current year starts with the current month; a past year
  starts with its latest active month (January if empty). Standalone Month
  and Week modes retain their hourly chart. Future dates cannot be selected.
- The time CSV mirrors both displayed charts, including net income and flags
  for estimated/incomplete amounts. No extra history or sync messages are
  recorded for these views.

## Diamond customers (0.4.81)

- Customers whose average tip across recorded completed orders is at least
  10,000 gold now have a diamond instead of the gold coin. The exact average
  decides, including zero-tip orders, not the largest or most recent tip.
  A later order can move the customer back down; duplicate completion notices
  still count once. Existing complete histories qualify immediately.
- Diamond has its own customer filter and period/all-time counts in analytics,
  and is shown in customer rows, tooltips and CSV exports. The existing
  unmark-generous action also clears diamond. Explicit manual marks/removals
  retain priority; old maximum-only histories with several orders cannot
  establish a diamond average and keep their previous coin classification.

## Single-row analytics summary (0.4.80)

- All ten summary metrics now share one full-width row. Search, collection,
  last exchange and the sync/export buttons have their own toolbar below.
- Tiles distribute free space evenly, retain complete amounts and fit unusually
  long values or translated labels without wrapping. Window width and chart
  space are preserved, and changing tabs no longer changes the window height.

## Returns and online time in the analytics summary (0.4.79)

- The main summary now includes the gold value of resourcefulness-returned
  customer reagents, using the same historical prices and date/profession/
  crafter filters as the Returns tab. Hover for returned quantities. An
  asterisk marks an incomplete valuation when some saved prices are missing;
  own reagents and unknown prices do not inflate the total.
- Online time shows total hours:minutes for the selected dates, with precise
  seconds on hover. Today therefore shows today's online time. Overlapping
  linked accounts count once; faction filtering applies, while profession,
  crafter and customer filters do not alter account presence. Local intervals
  refresh with the existing checkpoints; remote intervals appear after sync.
- Summary tiles wrap when needed, keeping the window's existing width and
  preserving room for the charts, customer counts and right-hand controls.

## Preserve declined-order identity (0.4.78)

- The decline button snapshots the customer, game order, recipe and material
  evidence before submitting the action. Identity is retained across the
  separate release/decline clicks and no longer depends on an API/list table
  remaining populated after the order is removed.
- The rejection is recorded before selection/UI cleanup. A normal `false`
  return from the recording bridge is now reported with order/customer/recipe
  context instead of being mistaken for a successful recording. Failed game
  calls still do not create rejected-order notices.
- Material snapshots retain modern recipe IDs above one million, including
  Aln'hara Lantern, rather than silently dropping them during sanitization.
- Regression checks cover disappearing order data, sparse rows after release,
  and one crafter delivering a cross and material list independently to two
  collectors. An ACK from one collector cannot clear the other's delivery.
  These changes cannot reconstruct a past order whose evidence was never saved.

## Analytics calendar and precise online time (0.4.77)

- Click a day in the lower chart to see that date's hourly statistics above.
  Today/Yesterday/Own dates follows the selection, while the calendar stays
  on its week or month so adjacent days remain easy to compare.
- Browse weeks, months and years with the calendar selector and arrows.
  Click a month in the year view to open its days, then a day for its hours.
  The Current button returns to the current period. All other filters still
  apply to both charts, and CSV exports identify the actual dates.
- Chart tooltips now show Ordered alongside Greeted and Orders done, and
  Ordered is also available as a chart metric. Order rate remains
  Ordered / Greeted: extra completed items and orders without a greeting
  do not inflate it.
- New online history uses actual session intervals with a local checkpoint
  every 30 seconds and a final endpoint on normal logout. Overlapping linked
  accounts count only once. Records are batched every five minutes or on
  leaving the world, without adding a network message every 30 seconds.
  Historical five-minute marks remain readable; their old rounding cannot
  be undone. Update both linked clients for the precise interval display.
  A crash can still lose unsaved game data; checkpoints do not force disk
  writes, and unobserved disconnect/suspension gaps are not filled in.

## Reliable reagent auction posting (0.4.76)

- Posting holds the selected item until the auction-created event and updated
  bag counts agree. Repeated clicks/keys cannot queue duplicate posts or skip
  an item, and only confirmed posts update the success message and last price.
- Posts requiring an auction-house warning use an explicit confirmation dialog
  bound to the original item, quantity, price and duration. Cancelling or a
  server error retains the item; confirmation never runs from an event or timer.
- A delayed response remains locked with a visible notice rather than silently
  retrying. Close/reopen the auction house to reconcile with actual inventory.
- Posting waits for the selected item's price search, validates its bag slot,
  ignores unrelated search results and no longer restores stale sold items
  just because the bags contain empty slots or bound equipment.
- Busy-key presses are no longer replayed from an auction event, outside the
  hardware click. When the auction house becomes ready, press Post again.

## Chat filter: other people's duels (0.4.73)

- "What is hidden" - Other system messages - Duel results: "A has defeated
  B in a duel" and "... has fled ... in a duel" are hidden unless they name
  you. On by default.

## Right click on a row takes one mark at a time (0.4.72)

- A right click on a row of the orders window first clears the customer's
  answer (the second mark), then the order's status (a decline's cross or
  the delivered mark), and only when no mark is left removes the row. The
  banner's right click and its key still dismiss the customer at once.

## The decline reply sends from the crafter (0.4.71)

- A declined order's reply ("I checked your order. {reagent_issues}") was
  offered on the crafting character but did nothing when clicked there ("Quick
  reply is no longer available") unless that character had also talked to the
  customer; it took a relog to the talking character. The click now accepts
  the crafter on the customer's side, as the offer does.
- The "~" before estimated tips on the analytics tiles is gone.

## Analytics: tips as received (0.4.70)

- Tips in the analytics are what you received: the customer's tip less the
  Artisan's Consortium's cut, which is now kept with each delivered order.
  Orders recorded earlier get the cut at the share the newer ones show. The
  customer's coin still
  follows the tip they set.

## Text selection: double click and drag; clearer hide options (0.4.69)

- In the text selection window a double click followed by a drag selects
  whole words from the one clicked to the one under the mouse, forwards or
  back; letting go keeps them, and Shift+click stretches further.
- The chat filter entries of its menu read "Hide messages containing this":
  "Anywhere, also inside other words" and "Only as separate words", each
  with an example in its tooltip.

## A key to skip the top Quick Reply (0.4.68)

- Key Bindings - HironCraftScan: "Skip top Quick Reply" puts the top quick
  reply away unsent, as a right click on it does; the next one moves up.

## Analytics: time online as a gauge under the bar (0.4.67)

- The grey block behind each bar used the chart's height, so it looked like
  another count. Time online is now a thin green gauge under each bar: empty
  when nobody was online in that hour, full when someone always was.

## Analytics: time online never above the time gone (0.4.66)

- The 5-minute mark running now counted in full, so a fresh hour could show
  more online time than had passed ("15 min of 13 min (114%)"). It counts
  only the minutes gone.

## Analytics: time online, simpler names, no mentions (0.4.65)

- Time online: every 5 minutes online is marked in the journal and shared
  with linked accounts. On the "By time" charts a grey block behind each bar
  shows the share of that hour (or weekday) someone was online, and the
  tooltip gives the minutes, e.g. "Online: 3 h 20 min of 5 h 00 min (67%)".
  Counted from this version on.
- Mentions (item links seen in chat) are no longer recorded or shown:
  Requests already tell what is in demand, and mentions were most of the
  journal.
- Simpler names: Requests, Greeted, Ordered, Order rate, Orders done,
  Declined, Tips, Average tip, Top tip; the returns tab: Crafts, With returns,
  Return chance, Returned, Worth, Times; "Sync now", "Collect data".

## No "Player not found." at login (0.4.64)

- At login the chat filter fills the game's ignore list from its own, and
  the game answers "Player not found." for players who were renamed,
  deleted or banned since. Those lines right after its own requests are no
  longer shown, and a player the game failed to find twice is not asked for
  again (the chat still hides them; the ignore list marks them "not found
  by the game").

## "Save chat text" without the game's copy of the line (0.4.63)

- "Save chat text" asked the game for the line's text and, when none came
  back, silently did nothing (seen on the laptop). The chat filter now keeps
  the last 200 lines it saw, hidden ones too, and the text selection tool
  takes the line from there when the game gives nothing; if neither has it,
  the chat says so.

## No greeting offers on a crafter; analytics from the minimap (0.4.62)

- "No greeting offers here" in the orders window, next to the stingy pause:
  on an account whose linked accounts catch the orders, requests are listed
  without the banner, the greeting card, the sound or the flashing icon; a
  click on the row still greets. Per account, until unchecked.
- The minimap button: right-click opens the analytics window; the account
  overview moved to Ctrl+right-click.

## Chat filter: Global Ignore List taken over at login (0.4.61)

- Global Ignore List's data can only be read while it is on, and turning it
  off before pressing "Take over" left the chat filter with no rules. Now,
  whenever GIL is on and nothing was taken over yet, its filters, ignore
  list and options are taken over at login by themselves. With GIL off and
  no rules, the chat says to turn it on for one login.

## Login fixed after the chat filter (0.4.60)

- 0.4.59 kept the chat filter's settings at the top of the saved variables,
  and an old migration took every such key for a realm: the login stopped
  there on every start, so the saved data was never set up. Crafting
  orders were drawn empty or without profit, the one-button crafting did
  nothing, linked accounts and the recipe menu failed. The migration now
  moves only entries that hold characters, and the stray entry 0.4.59 left
  behind is removed by itself at the next login.

## Chat filter, in place of Global Ignore List (0.4.59)

A chat filter of its own (/hcfilter, or "Chat filter" at the top of the
orders window, or the addon's settings). It only hides lines from the chat
windows: the scanner reads the chat events directly and still catches every
request.

- Rules: keys (a word or a phrase, anywhere or as whole words) and
  expressions written as in Global Ignore List ([word=], [contains=], [link],
  [journal], [guild], [community], and, or, not, parentheses...). "Take over
  Global Ignore List" brings its filters (on/off, counters, their last
  hidden lines), its ignore list and its options; after that GIL can be
  turned off from the same window.
- Keys from the text selection tool: select a phrase, right-click, "Hide in
  chat".
- NPC speech hidden by kind (saying, yelling, emotes, whispers), shown in
  dungeons and raids if wished.
- "Has come online / gone offline" hidden for your own characters (all
  realms and linked accounts), guild members and friends.
- The ignore list for the whole account, beyond the game's 50: their lines
  are hidden everywhere, the game's list of each character is filled with
  the most recently ignored, ignoring through the game's menus changes this
  list too. Optionally: an answer to their whispers, their invitations,
  duels and trades declined, a warning when one is in your group, their
  groups marked in the group finder.
- A journal of the last hidden lines, and each rule's own last lines; a
  click opens a line in the text selection tool.

## Customer coins by the average tip; hourly conversion (0.4.58)

- The coin in front of a customer's name now follows their average tip over
  delivered orders instead of their largest one: 3,000 gold or more is gold,
  1,000 to 2,999 silver, under 1,000 copper. Orders without a tip count too.
  Records kept so far are judged the same way right away; marks set by hand
  stay. The tooltip shows the average, the largest and the total tip.
- The hour and weekday tooltips of the analytics "By time" tab show the
  conversion: how many of the greetings sent in that hour (or on that day)
  ended in a crafted order. The time CSV has the crafted and conversion
  columns too.

## Analytics: reagent names and ranks (0.4.57)

- Reagents not in the game's cache stayed as their item numbers (#238205):
  the window waited for a server answer the game does not always send when
  an item is loaded by its ID. It now listens for the right one and looks
  again a few times on its own, so the names come in shortly after opening.
- Reagents of the same name are told apart by their rank icon.

## Analytics: long figures stay on their tile (0.4.56)

- A figure too long for its summary tile (a big sum of tips) wrapped onto a
  second line and climbed over the tile's name. It now stays on one line and
  the tile widens to it, the tiles after it moving along; should the row
  then reach the buttons on the right, that figure takes a smaller font.

## Analytics: the last hour (0.4.55)

- The analytics period list starts with "Last hour".

## Shop: posting as before, one request at a time (0.4.54)

- 0.4.53 made posting slower and lost posts: its queue could send several
  auction house requests at once (a post, a search and a search ahead of
  time); the auction house drops the extra ones, a dropped post left its
  item in the bags but out of the list, and presses waited for dropped
  searches. Posting is back to 0.4.52: one request at a time, a press posts
  at the price shown.
- Kept from 0.4.53: the landing tab and the first item chosen on Sell; a
  press while the auction house is busy is kept for 3 seconds and done the
  moment it is ready, alone.
- When the auction house drops a request anyway, the bags are read again,
  so an item that was not posted comes back into the list.

## Shop: landing tab, faster posting (0.4.53)

- At the auction house the Shop opens on Buy when there is a shopping list,
  and on Sell otherwise, with the first item of the bags already chosen
  and its prices asked for.
- Posting from Sell went quickly three times and then stalled: the auction
  house takes only a few requests at a time, every post and every price
  search is one, and a key press during the wait was simply lost. Now:
  - a press is kept and done as soon as the auction house is ready and the
    item's prices are in (for up to 5 seconds), never at a guessed price -
    before, a quick press could post at the remembered price before the
    search came back;
  - the next item's prices are asked for while the current one is on
    screen, so after a post they are already there;
  - prices read in the last minute are not searched again.

## Analytics refreshes with the exchange (0.4.52)

- The open analytics window showed new figures ten seconds after the chat
  line about the exchange: every new event waited 10 seconds before a
  recount. A finished exchange now refreshes the window at once, and other
  events are recounted after 2 seconds.

## Fitting: the first opening, and a compact name menu (0.4.51)

- The orders window still came up too wide the first time it opened after
  logging in or /reload. Until the panel manager places it, the XML spans
  it over the whole screen, and that is what the first fit measured. The
  window gets its real size at load and the manager is told it.
- The chat name menu folds its long lists once it would take more than
  about 60% of the screen's height, not only when it would not fit at all;
  and with "Collapse chat context menu" on, the HironCraftScan submenu folds
  its custom explanations and manual matching the same way.

## Analytics exchange after 3 quiet minutes (0.4.50)

- Linked accounts exchange analytics once both have been quiet for 3
  minutes instead of 10, and try every 5 minutes instead of 15.
- Only what the player does counts as work: greetings, whispers they type,
  crafting, claiming and delivering orders, combat. Requests and whispers
  that come in, results from linked accounts and the order traffic between
  accounts no longer hold the exchange back, so stepping away from the
  computer is enough.

## Resource returns: the customer's reagents only (0.4.49)

- The customer's reagents that came back were recorded as the crafter's:
  the order lists them with source "any" as well as "customer", and only
  the latter was checked. The rule of the reagent audit is used now (all but
  the crafter's), and only the customer's reagents are counted - the
  crafter's own are left out, so the "from customer" and "own" columns and
  tiles are gone. The chance still counts every resourcefulness return.
- Summary tiles are as wide as their names and never wrap, and there is
  room between the filters and the tiles.

## Resource returns (0.4.48)

- A fourth tab in the analytics window, "Resource returns": the reagents
  resourcefulness gave back on crafting-order crafts, per reagent and
  profession - how often, how many, the price each and the worth - with the
  period, profession and crafter filters, search and CSV export.
- The worth is counted at the price of the moment each came back:
  Auctionator, else TSM, else ProfitHub's own scans. Reagents without any
  price are counted but left out of the worth; currencies are left out.
- Returns from the customer's reagents (yours to keep) and from your own
  (a saving) are summed apart, and the chance - order crafts with a return
  out of all order crafts - is shown overall and, on hover, per
  profession.
- Recorded on the crafting account from now on and shared with linked
  accounts through the analytics exchange.

## Fit windows to the screen (0.4.47)

- A new setting, "Fit windows to the screen" (on by default, Settings -
  HironCraft), for small game windows such as two clients side by side on
  a laptop:
  - the orders window is scaled down to fit whenever it opens and whenever
    the game window changes size (it used to fit only after a resize, not
    after logging in); the analytics window does the same;
  - the chat name menu folds its long lists into submenus when it would run
    off the screen: the custom explanations first, then the manual
    matching. On a tall screen it stays as it was.
- Switched off, windows keep their full size and the menu stays flat.

## Analytics on by default, a third click unsorts, silver for the untipped (0.4.46)

- "Gather analytics" is switched on once on every account, also where it
  was switched off in the old opt-in analytics: such an account kept its
  greetings out of the combined picture without anyone noticing. Unticking
  it afterwards stays.
- Column headers in the analytics tables: the first click sorts, the second
  turns the order round, the third goes back to the usual order (most orders
  first).
- Customers whose delivered orders came before tips were recorded (0.4.32)
  had no coin at all. They get a silver coin once, as an automatic mark the
  next tip moves as usual; in the analytics any customer with delivered
  orders and no coin counts as silver. "No mark" is gone from the summary and
  from the coin filter.

## Linked accounts say their version (0.4.45)

- Every message between linked accounts carries the sender's HironCraft
  version, and each account remembers it. When "Exchange now" gets no answer
  the chat says why: the account is not online, runs a HironCraft older than
  0.4.45 (or one that cannot exchange analytics), or is current and simply
  did not answer. An account with gathering switched off answers that it is
  off instead of keeping quiet. The button's tooltip shows each account's
  version next to its last exchange.

## Analytics: exchange you can see, one request per conversation, search (0.4.44)

- "Exchange now" finds the linked accounts (pinging them when the link is
  stale) and says in chat how it went: how many new events came from each,
  or that an account did not answer, which usually means an older
  HironCraft there. The button's tooltip lists when each account was last
  exchanged with. An exchange with nothing new counts as done.
- The crafter's PC and a collector see the same chat line and each record
  the request. The same customer asking for the same thing on two linked
  accounts within three minutes is now one conversation, greeted and
  crafted if either side was.
- A search box under the buttons filters the item table by name (and the
  customer table by customer). While searching, items only seen in chat
  are included too, so any item can be checked.

## Analytics summary as tiles (0.4.43)

- The three lines of figures at the top of the analytics window are tiles
  now, one figure each with its name above it, in three groups: from request
  to craft (requests, greetings, crafted, conversion - green, yellow or red),
  orders (delivered, declined, tips, average tip) and chat (mentions). Each
  tile explains itself on hover. Customers per coin are one line below.
- The own-dates boxes appear right after the period list; the other
  filters move over while they are shown.

## Analytics window fixes (0.4.42)

- Rows of items with a profession showed no numbers, and hovering them
  showed the tooltip of whatever item that line had shown before. Colouring
  the profession name failed (a hex string where Midnight wants a colour),
  which stopped the row half-way; the same failure left the profession
  filter empty. The colour is fixed, and a row now takes its data first and
  draws every cell on its own, so one bad cell cannot blank it.
- The date boxes show only when "Own dates" is chosen, at the end of the
  filter row.
- The item table lists only items someone asked you for, was greeted about,
  ordered or had declined; items only seen in chat are left out and an item
  appears as its first data comes in. Their mentions still count.

## Analytics in a window of its own (0.4.41)

- The analytics table under the order list is replaced by an "Analytics"
  window (the button above the order list). Nothing is counted while it is
  closed: opening it unpacks the chosen dates, closing it lets them go.
- It follows each request: requests to you, greetings sent, how many
  greeted requests were crafted (conversion), all delivered orders,
  declines and tips. A request for a profession or a slot counts under the
  item finally crafted, and "LF tailor" narrowed to an item is one request.
  Item links seen in chat are still counted (mentions), also for items you
  do not craft.
- Filters: dates (presets or own dates), profession, crafter, side and
  customer coin. The side is that of the character that greeted or saw the
  request; an order without a conversation goes by the customer's race.
  Tabs: items, customers (orders, tips, conversion, last order) and by hour
  and day of week. Each tab exports to CSV. The summary counts the
  customers with each coin in the period and overall.
- Stored the way Journalator stores its logs: a journal of small events,
  full stores compressed with LibDeflate. The old chat counter moves in the
  first time the window opens; the order journal, order rows and statuses
  still kept are taken in once.
- Linked accounts exchange their analytics by themselves once both have
  been idle for 10 minutes (no requests, whispers, greetings or crafting)
  and out of combat, in small batches on a channel of its own, stopping as
  soon as either gets busy. "Exchange now" in the window does not wait.
  Order results keep travelling with the order statuses.

## A silver coin for tips in between (0.4.40)

- A customer who has only ever tipped between 999 and 4,999 gold gets a
  silver coin in front of the name, next to the gold (5,000+) and copper
  (under 999) ones. One small tip makes them copper, one big tip gold.
  Customers whose tips in between were counted before show silver at once.
  The silver coin is automatic only and does not affect "Pause stingy".

## Pause stingy customers; a swallowed greeting comes back as the banner (0.4.39)

- The orders window has a "Pause stingy" checkbox next to Busy Mode. While
  it is checked, requests from customers with the copper coin are listed
  without the banner, the greeting card or the sound; a click on the row
  still greets them. It stays on over /reload and relogs until unchecked
  (`settings.hold_stingy_greetings`, per account). A stingy request already
  waiting for the banner is skipped once the pause is on.
- A greeting the server swallowed (message rate limit) came back as a quick
  reply card even when it had been sent from the banner. It now comes back
  the way it was sent: the banner for the banner or the order list, the
  card for the card.

## No chat line for a result of another order (0.4.38)

- "result for X is not tied to a row" appeared in chat whenever a customer
  who talked to this account also had a different order done by the linked
  crafter (another profession or crafter). That is normal, not a fault. The
  reason is still kept in `settings.notice_mismatch_log` for tracing a
  missing mark, without a word in chat.

## Fewer wrong rows from tools and small talk (0.4.37)

- "LF Inscriptor that can craft me alchemy tool" made an Alchemy row next to
  the Inscription one. A profession named right before "tool", "tools",
  "gear", "accessory" (or after "tool for") names the item, not another
  crafter, and no longer makes a row of its own in a list of professions.
- "caps" in a running conversation became a cloak (read as "capes"). Slot
  typos are only recognised when the message itself asks for a craft (LF,
  need ...); small talk needs the exact slot word. "cap" and "caps" are
  never read as typos.

## A quiet Manual Matching row counts as greeted (0.4.36)

- A row added by Shift+click in Manual Matching is one the crafter already
  answered in chat: it gets its first mark (greeting sent), becomes the
  conversation the next reply of the customer belongs to (second mark), and
  offers no greeting of its own.

## A new tip mark shows at once (0.4.35)

- The coin in front of a customer's name was set when the order was
  delivered, but the chat orders table redrew the name only at its next
  update. It now redraws as soon as a mark appears or changes.

## Recipe shopping tooltip error (0.4.34)

- Hovering an entry of the recipe shopping list raised a Lua error: the
  tooltip title passed its wrap flag where the game expects the alpha.

## Stingy customers are marked too (0.4.33)

- A delivered order with a tip under 999 gold (no tip included) marks its
  customer stingy: a copper coin in front of the name. Generosity wins: a
  generous customer does not become stingy through one small tip, and a
  5,000+ tip lifts a stingy one.
- The chat menu can mark or unmark either by hand; a mark set or cleared
  by hand is not changed by later tips. Tips of every delivered order now
  count toward the numbers in the tooltip.

## Generous customers are marked (0.4.32)

- A delivered crafting order with a tip of 5,000 gold or more (the tip as
  set by the customer, before the cut) marks its customer with a gold coin
  in front of the name in the chat orders table and in the crafting order
  rows. The mark travels to linked accounts with the order result.
- "Mark as generous customer" / "Unmark generous customer" in the chat
  menu sets it by hand; its tooltip shows the largest tip, the total and
  the number of orders. An unmark by hand is not undone by later tips.
- Marks are kept by name without realm. Alts are not linked: the game does
  not tell which characters share an account.

## A list of professions makes a row for each (0.4.31)

- "lf bs/tailor/jc" made one row. Profession words such as "tailor" and
  "jc" also serve equipment requests ("lw wrist") and narrowed the request
  to the last one named. Without a slot or weapon they now count like any
  keyword, and a message naming several professions makes one row per
  profession (one crafter each, in the order written), answered by one
  greeting. Words separated by "/", ",", "&", "+", ";" or followed by
  "?", "!", ".", ":" are recognised without permissive matching; a keyword
  inside another word still is not.

## Orders stay where they appeared, as in CraftScan (0.4.30)

- As in the original CraftScan, an order only reaches another account
  through "Proxy Orders" (send) and "Receive Proxied Orders" (receive).
  With receiving off, an order stays on the account whose chat it appeared
  in. Hiding other-faction orders (0.4.26) is now off by default and
  remains a setting.
- A crafting order from a customer of the other faction no longer creates a
  row on the crafter: that character cannot whisper them. The result still
  reaches the account that talked to them as a notice.

## The other faction is recognised for every race (0.4.29)

- Races that pick their side (Pandaren, Dracthyr, Earthen) share one race
  name, so 0.4.26 could not tell their faction and such customers still
  showed on both sides. The side now comes from the race ID, which differs
  per faction, and is remembered on the customer. A customer who whispered
  this character is on its side, and the linked account passes the side it
  knows along with each shared request.

## A whispered "can craft [item]" is always a question (0.4.28)

- Whispered to the crafter, a short "can craft/recraft [item]" without a
  question mark is a customer's question from anyone, not only from a known
  customer; crafters pitch that way in trade chat. Clear whisper spam
  ("send order to X, commission ...", "I can craft", "WTS") is still
  filtered.

## "can craft [item]" from a customer makes a row (0.4.27)

- A customer in a conversation asked "can craft [Masterwork Sin'dorei Band]"
  and sent the "?" as the next line. Without the question mark the line
  looked like a crafter's pitch and no row was made. From someone this
  account already has a request from, a short "can craft/recraft ..." is now
  a question; clear ads ("I can craft", "WTS", "crafting services") are still
  filtered from everyone, and a stranger's "can craft ..." is still an ad.

## Other-faction orders are hidden (0.4.26)

- Two linked accounts on one PC often sit on different sides (a Horde
  collector next to Alliance crafters). The other side's requests arrived
  through the link and were listed and announced on a character that cannot
  whisper those customers. They are now hidden from the chat orders list and
  raise no banner or sound there; they keep working underneath, so statuses,
  crosses and "Done" still reach the account that talked. A character of
  that side shows them again. The side comes from the customer's race, or
  from the character that talked to them. Battle.net friends are never
  hidden. Setting: "Hide orders from the other faction" (on by default).

## Typo recognition without real-word mistakes (0.4.25)

- "Recognize typos" read any word one letter away from a keyword as a typo,
  so real words triggered replies and slots: help/helm, stuff/staff,
  crest/chest, send/sent, king/ring, boost/boots, danger/dagger. A typo now
  keeps its first letter; in words under six letters only dropped, doubled,
  extra or swapped letters count (staf, charr, writs), not a changed one;
  and a list of common English words is never read as a typo. Long words
  still allow a changed letter (qualiti), words of ten letters or more two
  edits.

## Ignore a player for a while (0.4.24)

- "HironCraftScan - Ignore" in the chat menu is a choice of durations: for 1
  hour, 1 day, 1 week or permanently. A timed ignore ends by itself; while
  it lasts, "Remove Ignore" shows how long is left. Existing ignores stay
  permanent.

## Item names written as text are recognised (0.4.23)

- A chat addon or a paste can turn a link into plain text, e.g. "LFC
  [Silvermoon Agent's Deflectors |A:...|a]"; only links were recognised.
  The name of a monitored craft in [brackets] now counts like a link. A bare
  name (no brackets) counts when the message asks for a craft (LF and other
  keywords), so talk about an item does not become a request. Names must
  match whole words; a name and a link of the same craft are one request.

## The label turns white behind the fill (0.4.22)

- While the craft progress fills the action button, the part of the label
  the fill has passed is drawn white, the rest stays gold: gold text on the
  gold wash lost its contrast.

## Craft progress fills the button (0.4.21)

- The thin line at the bottom of the action button during a craft is
  replaced by a translucent gold fill of the whole button from left to
  right. It sits over the label, so it is translucent to keep "Crafting"
  readable.

## Rows in progress are highlighted (0.4.20)

- In the chat orders window a row whose customer answered (second mark) and
  whose order is not delivered yet (no final third mark) carries a soft
  yellow wash under the hover highlight. It follows the marks: a delivered
  order, or the second mark set back to a cross, clears it.

## Compact order rows show the customer (0.4.19)

- Compact rows of the crafting order list are 32px instead of 36 and carry
  two lines: the item name (12px) and under it the customer or patron
  (10px, muted). Without a customer the name is centred.
- The action button repeated on every row is lighter (66x22, right edge on
  its column), the check box and icon are smaller, the concentration badge
  is 20px high, and reagent icons sit closer (four fit the column).
- Profit values and their header are right-aligned so the amounts line up.

## "send to Lavu" counts as an answer; no "crest"/"stone" defaults (0.4.18)

- A customer's "send to Lavu" looks like a crafter's ad and only went into
  the chat history: the second mark never appeared. From a customer this
  account already talks to it now counts as their answer (marked, shared
  with the linked account); it still creates no request, and the same line
  from a stranger is still ignored as an ad.
- The default Enchanting keyword "Crest" and Alchemy keyword "Stone" (and
  their translations) were everyday words: "no crest" made an Enchanting
  request. They are removed. A crafter who kept exactly the old default list
  gets the new one; edited lists are left alone. Profession keywords are set
  per crafter on their profession page (Keywords).

## A delivered item closes its slot for an hour (0.4.17)

- After Martyr's Leggings were delivered, "it is ur legs :d" made a new
  "Legs" row. An equipment slot (legs, wrist, ...) that an item delivered to
  the same customer within the last hour fits no longer makes a row; later
  "LF legs" may be for another set and works as before. Manual matching
  is not affected.

## No automatic reset of the answered mark (0.4.16)

- The automatic reset of the second mark after three minutes of silence from
  0.4.15 is removed; the mark changes only by the customer's messages or a
  right click on it, as in 0.4.9.

## Generic keys from chat, the answered mark resets after silence (0.4.15)

- The chat text selection menu can add a phrase to "Generic craft requests"
  (the "LF crafter" list) as well.
- The second mark (customer answered) turns back into a cross by itself after
  three minutes without a whisper from the customer, so their return stands
  out; their next message checks it again. It stays while their order has
  arrived (claimed, crafted or delivered); a declined order does not hold it.
  Rows with no message of the customer on record are left alone.

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
