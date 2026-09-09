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

The editable high-resolution icon source is kept in `artwork/`; the game uses the optimized `Media/HironCraftIcon.tga` version. A PNG preview is stored beside it.
