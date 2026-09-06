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

The editable high-resolution icon source is kept in `artwork/`; the game uses the optimized `Media/HironCraftIcon.tga` version. A PNG preview is stored beside it.
