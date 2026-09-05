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

The original CraftScan and ProfitHUB folders are not required after migration and can no longer overwrite this copy when they update.

## Crafting orders interface (0.3.0)

The order list and controls now share Blizzard's profession window. Native
buttons, standard fonts, framed panels and gold selection highlights replace
the external flat sidebar. Existing queue settings and key bindings are kept.

- **Crafting** contains reagent quality, concentration, finishers and tools.
- **Queue** contains profit filters, automatic selection and shopping.
- The action button, selection count and current status stay visible below
  both settings pages. The settings and order list scroll independently.
- Use the list's **+/−** button to switch between compact and detailed rows.
  Detailed rows include the customer; narrower lists show profit beneath the
  item, and the commission tooltip also includes it. Additional icons are
  available through **+N** when their column is full.
- **Refresh** reloads orders when no order action is in progress. Clicking the
  item row still opens the original Blizzard order details.

This release changes presentation; the reported finisher craft-start issue
is not considered resolved by the interface redesign.

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
