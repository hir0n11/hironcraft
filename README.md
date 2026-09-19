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
