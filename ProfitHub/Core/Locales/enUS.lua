--enUS.lua
local PT = HironCraftProfit
if not PT then return end

PT.L = PT.L or {}
local L = PT.L

function PT.EffectiveLocale()
    local lang = HironCraftProfit_DB and HironCraftProfit_DB.language
    if lang and lang ~= "auto" and lang ~= "" then return lang end
    return GetLocale()
end

function PT.RebuildLocale()
    local base = PT.L_enUS
    if not base then return end
    wipe(PT.L)
    for k, v in pairs(base) do PT.L[k] = v end
    if PT.EffectiveLocale() == "ruRU" and PT.L_ruRU then
        for k, v in pairs(PT.L_ruRU) do PT.L[k] = v end
    end
end

--infopanel


-- Combat Stats


-- Currency (InfoPanel)
-- ItemSlot (InfoPanel)
-- Durability (InfoPanel)
-- FPS / MS (InfoPanel)
-- Gold (InfoPanel)
-- Guild (InfoPanel)
-- Item Level (InfoPanel)
-- Spec / Loot Spec (InfoPanel)
-- WoW Token (InfoPanel)
-- Currency Picker
-- Concentration UI
L["TIME_MIN"]   = "%dm"
L["TIME_HOUR"]  = "%dh %dm"
L["TIME_DAY"]   = "%dd %dh"
L["NO_CONCENTRATION_AVAILABLE"] = "This profession does not use concentration"
-- ConfirmButtons
--infopanel(settings)
L["Width"]  = "Width:"
L["Height"] = "Height:"
L["+"] = "+"
L["-"] = "-"
--settings
L["Settings_Title"] = "Settings"
L["Settings_SaveMode"] = "Save settings"
L["Settings_SaveCharacter"] = "Save per character"
L["Settings_SaveAccount"] = "Save for account"
L["Settings_Concentration"] = "Concentration"
L["Settings_SkinningCheck"] = "Skinning Check"
L["Settings_SkinningTargets"] = "Configure targets:"
L["Settings_SkinningIconSize"] = "Skinning icon size:"
L["Settings_ProfWindow"] = "Knowledge Points"
L["Settings_LockWindows"] = "Lock all windows (disable movement)"
L["Default"] = "Default"
L["Settings_Transparency"] = "Transparency"
L["Settings_HideInCombat"] = "Hide in combat"
L["Settings_HideInInstance"] = "Hide in instances"


L["Settings_MapPins"] = "Additional modules:"
L["Settings_Enable"] = "Map Pins"
L["Settings_FirstCraft"] = "First-craft icons"
L["Settings_GoldDepositor"] = "Gold Depositor"
L["DB_Selector_Title"]    = "Database"
L["CONCENTRATION_MODE"]   = "Concentration Mode"
L["DB_Rotation_LMB"]      = "LMB: %s"
L["DB_Rotation_RMB"]      = "RMB: add-on selection"
L["UI_SCALE_ALT_WHEEL"] = "Alt + Mouse Wheel — change scale"
L["UI_SCALE_ALT_MMB"]   = "Alt + Middle Mouse Button — reset scale"
L["CONC_COMPACT_TITLE"] = "Compact mode"
L["CONC_COMPACT_ON"]    = "On — icon with value only"
L["CONC_COMPACT_OFF"]   = "Off — full bar"
L["CONC_COMPACT_HINT"]  = "Click — toggle"
--Profession.lua
L["Not loaded yet"] = "Not loaded yet"
L["Found on treasures"] = "Found on treasures"
L["Found on treasures DF"] = "Found on treasures\ntake Expedition Shovel"
L["ItemID"] = "ItemID"
L["item not loaded"] = "item not loaded"
L["Instructor Quest"] = "Instructor Quest"
L["Consortium Quest"] = "Consortium Quest"
L["Unknown"] = "Unknown"
--core\SkinningCheck.lua
L["SKINNING_NOT_LEARNED"] = "Skinning not learned"
L["SKINNING_ALL_DONE"]    = "All rare skinning targets completed"
L["SKINNING_AVAILABLE"]  = "Available skinning targets:"
L["SKINNING_LURE"]        = "Lure"
L["SKINNING_CRAFT_FROM"]  = "Crafted from"
L["SKINNING_LOCATION"]    = "Location"
L["SKINNING_TARGET"]      = "Target"
-- Targets
L["cobra_skin"]  = "Obsidian Cobraskin"
L["slatefang"]   = "Superb Beast Fang"
-- Minimap / LDB
L["LDB_TITLE"]        = "HironCraft"
L["LDB_LEFT_CLICK"]   = "LMB — settings"
L["LDB_RIGHT_CLICK"]  = "RMB — account overview"
-- SkinningCheck UI
L["SKINNING_TITLE"]        = "Skinning Check"
L["SKINNING_LURE_RMB_HINT"] = "Right click — send missing lure reagents to Shop"
L["SKINNING_LURE_LIST"]     = "Lure reagents"
L["SKINNING_LURE_SHOP_NONE"] = "You already have reagents for all lures."
L["SKINNING_LURE_SHOP_NA"]  = "Shop module is unavailable."
L["SKINNING_HOW_TO_GET"]   = ""
L["SKINNING_GUIDE"] = "Guide:"
L["SKINNING_ROW_HINT"] = "Left Click — set waypoint\nRight Click — use lure\nMiddle Click — craft lure\nShift + Middle Click — open profession\n\nFirst number — ready lures in bags.\nIn brackets — how many can be crafted."
L["SKINNING_LURE_NOT_FOUND"] = "Lure not found in bags: %s"
L["SKINNING_LURE_USE_FAILED"] = "Failed to use lure: %s"
L["SKINNING_CRAFT_NO_MATS"] = "Not enough materials to craft: %s"
L["SKINNING_RECIPE_NOT_FOUND"] = "Lure recipe not found: %s"
-- Skinning targets window
L["SKINNING_TARGETS_TITLE"] = "Skinning Check — tracked targets"
--UI.lua
L["PROF_WINDOW_TITLE"] = "Knowledge Points"
L["CATCHUP_REQUIREMENTS"] = "Catch-Up unlock requirements:"
L["REQUIREMENTS"] = "Requirements:"
L["REQUIRES_PROFESSION_SKILL_25"] = "Requires profession skill 25"
L["PROFESSION_SKILL"] = "Profession skill"
L["CATCHUP_SOURCE_NPC_ORDERS"] = "Obtained from NPC crafting orders"
L["FILTER_TOOLTIP_TITLE"] = "Filters"
L["FILTER_TOOLTIP_HINT"]  = "Configure what is shown in the list"

L["FILTER_PRESETS"] = "Presets"
L["FILTER_PRESET_ALL"] = "All"
L["FILTER_PRESET_ONLY_MAP"] = "Current zone"
L["FILTER_PRESET_ONLY_WEEKLY"] = "Only weekly"

L["FILTER_SHOW"] = "Show:"
L["FILTER_UNIQUE_TREASURE"] = "Unique Treasures"
L["FILTER_UNIQUE_BOOK"] = "Unique Books"
L["FILTER_WEEKLY"] = "Weekly"
L["FILTER_SHOW_ZEAL"] = "Artisan's Acuity"
L["FILTER_TREATISE"] = "Treatises"
--welcome.lua
L["WELCOME_TEXT"] =
"Welcome to |cffb19cd9HironCraft|r!\n\n" ..
"This addon is built mainly for gold farming, but it also adds small conveniences for everyone else.\n\n" ..
"It's made of a core (the base feature set) and modules (extra features) — you can install the modules separately, as you like."
















L["WELCOME_OPEN_SETTINGS"] = "Open settings"

L["Midnight Herbalism"] = "Midnight Herbalism"

L["CLICK_TO_TOGGLE_PROFESSIONS"] = "Left-click to open/close the Professions window"
L["Found on treasures MN"] = "Found on treasures at Midnigh zones."
L["OR"] = "OR"
--df.lua
L["BOOMTHYR_ROCKET_NOTE"] =
"Inside the building to the right of the entrance lies a note.\n" ..
"After reading it, you will receive a 10-minute buff —\n" ..
"\"Boomthyr Rocket Parts List\".\n\n" ..
"Then, collect three items in the house at /way 57.5, 44.3:\n" ..
"• Volatile Vapors\n" ..
"• Aerospace Dragonite\n" ..
"• Reinforced Crystal\n\n" ..
"and Ashes inside the house with the rocket.\n" ..
"After that, you will be able to pick up the Boomthyr Rocket.\n\n" ..
"If the rocket is not active, relogging or using /reload usually helps."
L["GlimmerOfOrder"] =
"You must have 10x KP into Insight of the Blue, and have the Primal Extraction sub-spec unlocked.\n\n" ..
"(you can have 0/40 KP in Primal Extraction and this will work).\n\n" ..
"Craft a pet Sophic Amalgamation or obtain it via a Public Crafting Order — do NOT add the pet to your collection.\n\n" ..
"Disenchant the crafted Sophic Amalgamation to receive Glimmer of Order.\n\n" ..
"The drop is RNG-based and not guaranteed, so you may need to disenchant multiple Sophic Amalgamations.\n\n" ..
"You cannot disenchant a caged Sophic Amalgamation — only the crafted item can be disenchanted."
L["PrimalStorms_Earth"] = "kill mobs in Primal Storms (Earth)"
L["PrimalStorms_Air"]   = "kill mobs in Primal Storms (Air)"
L["PrimalStorms_Frost"] = "kill mobs in Primal Storms (Frost)"
L["PrimalStorms_Fire"]  = "kill mobs in Primal Storms (Fire)"
L["FORGETFUL_APPRENTICE_TOME"] =
"It's for Inscription profession.\n" ..
"Click the Curious Glyph (book) to get the buff «Making Connections».\n" ..
"Leave the building and go to the other side of the bridge.\n" ..
"At the end you will find Confusion Manifest — kill it and loot the Decryption Key.\n" ..
"Return to the Curious Glyph and click it again to loot the Forgetful Apprentice's Tome.\n\n" ..
"/way 47.10 40.07 — Curious Glyph\n" ..
"/way 49.84 40.31 — Confusion Manifest"

L["COUNTERFEIT_DARKMOON_DECK"] =
"Not marked on the minimap.\n" ..
"A purple-framed NPC named Siennagosa.\n" ..
"Speak with her and offer to help restore her Darkmoon Deck.\n" ..
"Under her are 8 clickable cards — click them in the correct order:\n" ..
"Ace -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8.\n" ..
"Speak with her again after finishing to receive your knowledge."
L["UNIQUE_TREASURE_SILVER_KEY_CRYSTALS"] =
"Inside the pond you will find a large chest.\n" ..
"A silver key lies beside it.\n" ..
"When you click the key, you will receive a buff.\n" ..
"With this buff, click 3 nearby crystals.\n\n" ..
"Crystal locations:\n" ..
"44.71, 61.99\n" ..
"44.68, 60.20\n" ..
"44.18, 61.98\n" ..
"And you will be able to open the chest."
L["UNIQUE_TREASURE_MAGMA_CRYSTALS"] =
"To unlock the item, click 3 different crystals on small islands inside the magma.\n" ..
"A large magma frog jumps around nearby — defeat it before starting.\n" ..
"After activating the first crystal, you will have limited time to activate the other two.\n" ..
"Each crystal channels a lava beam into a dirt pile.\n" ..
"Channeling all three beams unlocks the item."

L["UNIQUE_TREASURE_70230_DESC"] =
"Slim tower in back, not the room without a roof.\n" ..
"Craft a Primal Molten Alloy near the Dim Forge\n" ..
"and the item becomes lootable in the Slack Tub."
L["UNIQUE_TREASURE_70246_DESC"] =
"Defeat the 4 shields surrounding the sword.\nAfter defeating them, wait 2–3 seconds and click the pedestal.\nIf the item does not appear in your inventory immediately, relog and retrieve it from the mailbox."

--Customization
L["DEFAULT"] = "Default"
L["Customization"] = "Customization"

L["Customization_Title"] = "Customization"
L["Customization_Concentration"] = "Concentration"
L["Customization_ProfessionsWindow"] = "Knowledge Points Window"

L["Customization_BarColor"] = "Bar color"
L["Customization_TimerColor"] = "Timer text color"
L["Customization_DividerColor"] = "Divider color"
L["Customization_BorderColor"] = "Bar border color"
L["Customization_IconBorderColor"] = "Icon border color"
L["Customization_BackgroundColor"] = "Background color"

L["Customization_Font"] = "Font"
L["Customization_TimerFontSize"] = "Timer font size"
L["Customization_ProfFontSize"] = "Font size"

L["Customization_Prof_Background"] = "Background"
L["Customization_Prof_Border"] = "Window border"
L["Customization_Prof_Header"] = "Header"
L["Customization_Prof_FontColor"] = "Text color"

L["Customization_ResetDefault"] = "Reset to default color"
-- Account Overview column tooltips
L["AO_SCALE_TIP"] = "Alt + Wheel — scale\nAlt + Middle Click — reset"
L["AO_TITLE"] = "Account Overview"
L["AO_HDR_CHAR"]   = "Character"
L["AO_HDR_C_DF"]   = "Conc DF"
L["AO_HDR_C_TWW"]  = "Conc TWW"
L["AO_HDR_C_MID"]  = "Conc MN"
L["AO_HDR_ZEAL"]   = "Moxie"
L["AO_TIP_ZEAL"]   = "Artisan's Moxie per active profession (Midnight)"
L["AO_CONC_NOTIFY_ON"]    = "Notification enabled"
L["AO_CONC_NOTIFY_OFF"]   = "Notification disabled"
L["AO_CONC_NOTIFY_CLICK"] = "Click to toggle"
L["AO_CONC_NOTIFY_DRAG"] = "Drag to move"
L["AO_CONC_NOTIFY_CLICK_OPEN"] = "Click to open Account Overview"
L["AO_HDR_KP_DF"]  = "KP DF"
L["AO_HDR_KP_TWW"] = "KP TWW"
L["AO_HDR_KP_MID"] = "KP MN"

L["AO_HDR_SKIN"]   = "Skinning"
L["AO_HDR_TW"]     = "TW"
L["AO_HDR_DUNDUN"] = "Dundun"
L["AO_TIP_DUNDUN"] = "Earned this week / weekly cap (current currency)."
L["AO_DUNDUN_EARNED"] = "Earned this week"
L["AO_DUNDUN_MAX"] = "Weekly maximum"
L["AO_DUNDUN_CURRENT"] = "Current currency"

L["AO_TIP_CHAR"] = "Character name and realm"

L["AO_TIP_C_DF"]  = "Dragonflight profession concentration"
L["AO_TIP_C_TWW"] = "The War Within profession concentration"
L["AO_TIP_C_MID"] = "Midnight profession concentration"

L["AO_TIP_KP_DF"]  = "Weekly Knowledge Points activities\n(Dragonflight)"
L["AO_TIP_KP_TWW"] = "Weekly Knowledge Points activities\n(The War Within)"
L["AO_TIP_KP_MID"] = "Weekly Knowledge Points activities\n(Midnight)"

L["AO_TIP_SKIN"] = "Skinning daily progress"
L["AO_TIP_TW"]   = "Timewalking quest status"
L["AO_TIP_DMF"]     = "Darkmoon profession quest"
L["AO_DMF_QUEST_DONE"]     = "Quest completed"
L["AO_DMF_QUEST_NOT_DONE"] = "Quest not completed"
L["AO_KP_TITLE"]     = "Weekly Knowledge"
L["AO_KP_TRAINER"]   = "Weelky Quest"
L["AO_KP_TREASURE"]  = "Treasure"
L["AO_KP_TREATISE"]  = "Treatise"
L["AO_HDR_PROF_EQUIP"] = "Prof Gear"
L["AO_TIP_PROF_EQUIP"] = "Equipped profession gear"
L["AO_FILTER_RESET_ORDER"] = "Reset column order"
L["AO_COLUMNS_MOVE_UP"] = "Move up"
L["AO_COLUMNS_MOVE_DOWN"] = "Move down"
L["AO_RESET"] = "Reset"
L["AO_RESET_1_TEXT"] =
"HEY. STOP RIGHT THERE.\n\n" ..
"Do you really want to do this?\n\n" ..
"All Account Overview data will be deleted."

L["AO_RESET_2_TEXT"] =
"LAST WARNING.\n\n" ..
"This action cannot be undone.\n\n" ..
"Are you absolutely sure?"

L["AO_DELETE_CHAR_TEXT"] = "Remove this character from the list?\n\n%s"
L["AO_NOTE_TITLE"] = "Note"
L["AO_NOTE_EMPTY"] = "No note. Click to add."
L["AO_DELETE_CHAR_TITLE"] = "Delete character"

L["AO_RESET_2_YES"] = "I KNOW WHAT I'M DOING"
L["AO_RESET_2_NO"]  = "ABORT"
L["AO_FILTER_TIP"] = "Show column filters"
L["AO_FILTER_TITLE"] = "Columns"
L["AO_MANUAL_ORDER"] = "Custom order"
L["AO_MANUAL_ORDER_TIP"] = "Drag characters to reorder; column sorting is disabled"
L["AO_NO_NEW_CHARS"] = "Don't add new"
L["AO_NO_NEW_CHARS_TIP"] = "New characters won't be added to the table"
L["AO_CONC_FULL_TITLE"] = "Concentration restored"
L["AO_CONC_MORE"] = "and others…"
L["AO_NOTIFY_ON"] = "Notifications enabled"
L["AO_NOTIFY_OFF"] = "Notifications disabled"


--DB
L["InCave"] = "In cave"
L["InsBuilding"] = "Inside building"
L["IncWO"] = "Inscription work order"
L["TQ"] = "Trainer quest"
L["CraftOQ"] = "Crafting Orders Quest"
L["LittleHerb"] = "Randomly looted while gathering herbs"
L["BigHerb"] = "Looted through herbs, after gathering 5 petals"
L["LittleOre"] ="Randomly looted while gathering ore"
L["BigOre"] = "Looted through ores, after gathering 5 shards"
L["LittleSkin"] = "Randomly looted while skinning"
L["BigSkin"] = "Looted through skinning, after 5 pelts"
L["LittleDis"] = "Randomly looted while disenchanting"
L["BigDis"] = "Looted from disenchanting, after looting 5 shards"
L["238586"] = "Inside the building, near the lamp"
L["238581"] = "Inside building, right side, under table"
L["238572"] = "Inside building, right side\non table"
L["238557"] = "Top of the stairs"
L["238544"] = "Inside the building, right side\nnear to the table"
L["238630"] = "In cave, entry at 69.88, 50.31\nright corridor"	
L["238538"] = "ON the roof"
L["238546"] = "In the crest upgrade room\non the table to the left"
L["238553"] = "On top of mushroom"
L["238556"] = "Inside an auction house"
L["238558"] = "lower level\non table"
L["238559"] = "On the cap of the mushroom"
L["238562"] = "upper level\non table"
L["238563"] = "Above the cave there is a big tree\nthe treasure is behind the tree"
L["238575"] = "On top of the roots"
L["238576"] = "Near the herbalism trainer"
L["238578"] = "upper level\nnear Rae'ana"
L["238579"] = "first floor\ninside building"
L["238580"] = "inside Silvery Serenades\n2nd room\nunder table"
L["238583"] = "first floor\non table"
L["238585"] = "lower level\non the boxes"
L["238587"] = "Inside the tent\non the table"
L["238613"] = "inside Welcome Wares\nuppstairs"
L["238614"] = "second flor\nright of the entrance"
L["238618"] = "inside tower\nfirst table on left"
L["238598"] = "Inside the building\nnext to a large broken vessel"
L["238601"] = "Becomes available after completing the zone storyline."
L["238582"] = "Inside the building, under the table."
L["storyL"] = "Becomes available after completing the zone storyline."
--df
L["70253"] = "Profession Master (NPC: Hua Greenpaw)"
L["204228"] = "Kangalo(The Forbidden Reach)"
L["70258"] = "Profession Master (NPC: Bridgette Holdug)"
L["204233"] = "Tectonus(The Forbidden Reach)"
L["70259"] = "Profession Master (NPC: Zenzi)"
L["204231"] = "Faunos(The Forbidden Reach)"
L["RousingElem"] = "Rousing elements mobs"
L["Decay"] = "Decaying mobs"
L["70247"] = "Profession Master (NPC: Grigori Vialtry)"
L["74935"] = "Agni Blazehoof"
L["70260"] = "Profession Master (NPC: Elysa Raywinder)"
L["204225"] = "Gareed(The Forbidden Reach)"
L["70251"] = "Profession Master (NPC: Shalasar Glimmerdusk)"
L["204224"] = "Manathema"
L["70256"] = "Profession Master (NPC: Erden)"
L["204232"] = "Snarfang(The Forbidden Reach)"
L["70250"] = "Profession Master (NPC: Grekka Anvilsmash)\noutside tower, in grass"
L["204230"] = "Tidesmith Zarviss(The Forbidden Reach)"
L["70255"] = "Profession Master (NPC: Pluutar)"
L["204222"] = "Amephyst(The Forbidden Reach)"
L["206035"] = "Under the table"
L["70254"] = "Profession Master (NPC: Lydiara Whisperfeather)"
L["204229"] = "Arcantrix(The Forbidden Reach)"
L["198977"] = "Mobs: Nokhud" 
L["198978"] = "Mobs: Gnolls"
L["198976"] = "Mobs:Azure Vorquin"
L["198975"] = "Mobs:Primal Proto-Drakes"
L["198965"] = "Mobs:Crushing Elemental"
L["198966"] = "Mobs:Blazing Manifestation"
L["89101"] = "The item is inside the building on the ground under the table with a barrel of grapes.\n\nIf you cannot see it, try relogging or switching layers by joining a group."
L["238577"] = "The item is inside the building on the first floor, next to the table.\n\nIf you cannot see it, try relogging or switching layers by joining a group."
L["238532"] = "The flask is on the bench.\n\nIf you cannot see it, try relogging or switching layers by joining a group."
L["238545"] = "It is on TOP of a giant mushroom"
L["23856"] = "Inside the building, next to the lamp"
--epochs.lua
L["Alchemy"] = "Alchemy"
L["Blacksmithing"] = "Blacksmithing"
L["Enchanting"] = "Enchanting"
L["Engineering"] = "Engineering"
L["Inscription"] = "Inscription"
L["Jewelcrafting"] = "Jewelcrafting"
L["Leatherworking"] = "Leatherworking"
L["Tailoring"] = "Tailoring"
L["Cooking"] = "Cooking"
--mappins.lua
L["MAP_PINS_TITLE"] = "Map Pins"
L["MAP_PINS_SETTINGS"] = "Left Click: Settings"
L["MAP_PINS_MENU_TITLE"] = "Map Pins"
L["MAP_PINS_KNOWLEDGE"] = "Knowledge"
L["MAP_PINS_LURES"] = "Lures"
L["MAP_PINS_SIZE"] = "Size"
L["MAP_PINS_UNKNOWN"] = "Unknown"

-- FarmTracker
L["LDB_SHIFT_LEFT_CLICK"] = "Shift + LMB — Farm Tracker"
L["LDB_SHIFT_R_CLICK"] = "Shift + RMB — Disenchant Menu"

L["Customization"] = "Customization"
L["Customization_Title"] = "Customization"

L["Customization_Concentration"] = "Concentration"
L["Customization_BarColor"] = "Bar color"
L["Customization_TimerColor"] = "Timer text color"
L["Customization_DividerColor"] = "Divider color"
L["Customization_BorderColor"] = "Bar border color"
L["Customization_IconBorderColor"] = "Icon border color"
L["Customization_BackgroundColor"] = "Background color"
L["Customization_Font"] = "Font"
L["Customization_TimerFontSize"] = "Timer font size"
L["Customization_ProfFontSize"] = "Font size"

L["Customization_ProfessionsWindow"] = "Knowledge Points Window"
L["Customization_Prof_Background"] = "Background"
L["Customization_Prof_Border"] = "Window border"
L["Customization_Prof_Header"] = "Profession header"
L["Customization_Prof_FontColor"] = "Text color"


L["Customization_ResetDefault"] = "Reset to default"
L["DEFAULT"] = "Default"

-- ruRU

L["COA_CONFLICT_BAR_PREFIX"] = "CO conflict"
L["COA_CONFLICT_TOOLTIP_TITLE"] = "HironCraft Crafting Orders — conflict detected"
L["COA_CONFLICT_TOOLTIP_FRAMES"] = "Foreign frames in this window:"
L["COA_CONFLICT_TOOLTIP_HINT_DISABLE"] = "/ahuico off — disable HironCraft module"
L["COA_CONFLICT_TOOLTIP_HINT_DISMISS"] = "× — dismiss this warning"

-- Profession Guides Localization
L["PG_NOT_LEARNED"] = "This profession expansion is not learned"




-- Recipe List



-- RecipeList snapshots / filters






-- Gold Depositor













-- Multi InfoPanel
L["Delete"] = L["Delete"] or "Delete"
L["Width"] = L["Width"] or "Width"
L["Height"] = L["Height"] or "Height"

-- Crafting Orders Assistant

L["COA_ACTION_NONE"] = "No action"
L["COA_ACTION_OPEN"] = "Open"
L["COA_ACTION_CLAIM"] = "Claim"
L["COA_ACTION_CRAFT"] = "Craft"
L["COA_ACTION_RECRAFT"] = "Recraft"
L["COA_ACTION_FULFILL"] = "Complete"
L["COA_ACTION_CLAIMING"] = "Claiming"
L["COA_ACTION_CRAFTING"] = "Crafting"
L["COA_ACTION_FULFILLING"] = "Completing"
L["COA_ACTION_BUSY"] = "Busy"
L["COA_BINDING_LABEL"] = "Key:"
L["COA_BINDING_NONE"] = "Not assigned"
L["COA_BIND_ASSIGN"] = "Bind"
L["COA_BIND_CAPTURE"] = "Press a key for the order action button.\nEsc — cancel."
L["COA_TOOLTIP_TITLE"] = "Crafting Order Action"
L["COA_TOOLTIP_DESC"] = "Performs the current order step."
L["COA_ROW_TOOLTIP_CLAIM"] = "Claim this order."
L["COA_ROW_TOOLTIP_OPEN"] = "Open this order."
L["COA_ROW_TOOLTIP_INLINE"] = "Left click: perform this row step. Assigned key works only on checked orders."
L["COA_ROW_TOOLTIP_BIND"] = "Right click: assign hotkey. Shift-right click: clear hotkey."
L["COA_STATUS_NO_PROFESSION"] = "Profession is not available."
L["COA_STATUS_NO_ORDER"] = "Select an order first."
L["COA_STATUS_NO_ROW"] = "Hover an HironCraft order button first."
L["COA_STATUS_NO_ACTION"] = "No available action."
L["COA_STATUS_BLIZZ_BLOCKED"] = "Blizzard button is disabled."
L["COA_STATUS_CLAIMING"] = "Claiming order..."
L["COA_STATUS_CLAIM_FAILED"] = "Could not claim the order."
L["COA_STATUS_CLAIMED"] = "Order claimed."
L["COA_STATUS_CRAFTING"] = "Crafting order..."
L["COA_STATUS_CRAFTED_READY"] = "Order crafted. Complete it."
L["COA_STATUS_CRAFT_FAILED"] = "Could not craft the order."
L["COA_STATUS_CANNOT_CRAFT"] = "Cannot craft: reagents, cooldown or quality check failed."
L["COA_STATUS_NO_REAGENTS"] = "Cannot craft: missing reagents."
L["COA_ACTION_NO_REAGENTS"] = "Missing reagents"
L["COA_STATUS_FULFILLING"] = "Completing order..."
L["COA_STATUS_DONE"] = "Order completed or released."
L["COA_STATUS_FULFILLED"] = "Order completed."
L["COA_STATUS_FULFILL_FAILED"] = "Could not complete the order."
L["COA_STATUS_NO_ENGINE"] = "Crafting order view is not available."
L["COA_STATUS_PREPARE_FAILED"] = "Could not prepare the order."
L["COA_STATUS_BIND_SET"] = "Order hotkey assigned:"
L["COA_STATUS_BIND_CLEARED"] = "Order hotkey cleared."
L["COA_SELECTED_LABEL"] = "Selected:"
L["COA_CLEAR_SELECTED"] = "Clear"
L["COA_QUEUE_TOOLTIP_TITLE"] = "Crafting Orders Queue"
L["COA_QUEUE_TOOLTIP_DESC"] = "Check orders here, then press the assigned key to process the selected queue step by step."
L["COA_ROW_TOOLTIP_RELEASE"] = "Right click: release the claimed order."
L["COA_STATUS_NO_SELECTED_ROW"] = "Check an order first."
L["COA_STATUS_NOT_CLAIMED"] = "This order is not claimed."
L["COA_STATUS_RELEASING"] = "Releasing order..."
L["COA_ACTION_CANNOT_CRAFT"] = "Cannot craft"
L["COA_CONCENTRATION_SHORT"] = "Conc"
L["COA_CONCENTRATION_ON"] = "On"
L["COA_CONCENTRATION_TOOLTIP"] = "Toggle concentration for this order."
L["COA_REWARD_COMMISSION"] = "Commission"
L["COA_REAGENT_AUTO"] = "Auto"
L["COA_REAGENT_QUALITY_FMT"] = "Q%d"
L["COA_REAGENT_CUSTOMER"] = "Provided by customer"
L["COA_REAGENT_CRAFTER"] = "Provided by you"
L["COA_REAGENT_OWNED_FMT"] = "Owned: %d / %d"
L["COA_REAGENT_MISSING_FMT"] = "Missing: %d"
L["COA_STATUS_CONCENTRATION_ON"] = "Concentration enabled for this order."
L["COA_STATUS_CONCENTRATION_OFF"] = "Concentration disabled for this order."
L["COA_STATUS_CONCENTRATION_NOT_NEEDED"] = "Concentration is not needed: the order can already be crafted."
L["COA_STATUS_REAGENT_AUTO"] = "Reagent selection: auto."
L["COA_STATUS_REAGENT_SELECTED"] = "Reagent selected:"
L["COA_EXPECTED_QUALITY"] = "Expected quality"
L["COA_QUALITY_TOOLTIP_QUALITY"] = "Quality"
L["COA_QUALITY_TOOLTIP_SKILL"] = "Skill"
L["COA_QUALITY_TOOLTIP_CONC"] = "Concentration is applied."
L["COA_QUALITY_TOOLTIP_NO_CONC_NEEDED"] = "Concentration is not needed."
L["COA_QUALITY_TOOLTIP_NO_DATA"] = "Quality data is not available yet."

L["COA_ACTION_CLAIM_SHORT"] = "Claim"
L["COA_ACTION_CRAFT_SHORT"] = "Craft"
L["COA_ACTION_RECRAFT_SHORT"] = "Re"
L["COA_ACTION_FULFILL_SHORT"] = "Done"
L["COA_ACTION_CLAIMING_SHORT"] = "..."
L["COA_ACTION_CRAFTING_SHORT"] = "..."
L["COA_ACTION_FULFILLING_SHORT"] = "..."
L["COA_ACTION_BLOCKED_SHORT"] = "—"
L["COA_ACTION_NONE_SHORT"] = "—"
L["COA_PANEL_HELP_TITLE"] = "Crafting Orders Queue"
L["COA_PANEL_HELP_DESC"] = "Check orders inside row buttons, then press the assigned key. Each key press performs one step: claim, craft, or complete. Right-click a row button to release a claimed order."
L["COA_PANEL_HELP_REAGENTS"] = "Use reagent icons to choose a grade. The concentration icon in the quality column enables concentration when needed."
L["COA_PANEL_HELP_ROW_COLORS_TITLE"] = "Row colors:"
L["COA_PANEL_HELP_ROW_GREEN"] = "Green: can be crafted."
L["COA_PANEL_HELP_ROW_YELLOW"] = "Yellow: requested quality needs concentration."
L["COA_PANEL_HELP_ROW_RED"] = "Red: recipe is unknown or unavailable."
L["COA_TOOLTIP_STATE"] = "Current state:"
L["COA_TOOLTIP_TIME_LEFT"] = "Time left:"
L["COA_TOOLTIP_QUEUE_STATE"] = "In queue:"
L["COA_YES"] = "Yes"
L["COA_NO"] = "No"
L["COA_SELECT_ALL"] = "Queue"
L["COA_SELECT_ALL_TOOLTIP_TITLE"] = "Queue work orders"
L["COA_SELECT_ALL_TOOLTIP"] = "Builds a work-order queue with HironCraft checks and marks matching order buttons."
L["COA_STATUS_SELECTED_CRAFTABLE"] = "Selected craftable orders: %d."
L["COA_SHOPPING_BUTTON"] = "Shopping"
L["COA_SHOPPING_TOOLTIP_TITLE"] = "Create shopping list"
L["COA_SHOPPING_TOOLTIP"] = "Creates an HironCraft Shop shopping list from checked orders and selected reagent grades. Customer/NPC-provided reagents are skipped; only missing quantities are added."
L["COA_SHOPPING_LIST_NAME"] = "Crafting Orders"
L["COA_STATUS_SHOP_NO_SELECTED"] = "Check orders first."
L["COA_STATUS_SHOP_EMPTY"] = "Nothing to buy for selected orders."
L["COA_STATUS_SHOP_CREATED"] = "Shopping list created: %d items from %d orders."
L["COA_STATUS_SHOP_CREATED_AUCTIONATOR"] = "Auctionator list created: %d items."
L["COA_STATUS_SHOP_UNAVAILABLE"] = "HironCraft Shop or Auctionator shopping list API is unavailable."

L["COA_ACTION_UNKNOWN_RECIPE"] = "Unknown"
L["COA_ACTION_VIEW_ONLY"] = "View only"
L["COA_STATUS_TABLE_REQUIRED"] = "Crafting order table is required for this action."
L["COA_STATUS_UNKNOWN_RECIPE"] = "This recipe is not known by this character."

L["COA_HDR_QUALITY"] = "Quality"

L["COA_HDR_REWARDS"] = "Rewards"

L["COA_HDR_REAGENTS"] = "Reagents"
L["COA_HDR_PROFIT"] = "Profit"

L["COA_HDR_ACTION"] = "Action"
L["COA_HDR_NAME"] = "Name"
L["COA_HDR_COST"] = "Cost"
L["COA_HDR_CONC"] = "Conc."
L["COA_HDR_REWARD"] = "Reward"
L["COA_PROFIT_NO_DATA"] = "Profit data is not available."
L["COA_PROFIT_MISSING"] = "Some Auctionator prices are missing."
L["COA_PROFIT_REAGENTS"] = "Reagent cost:"
L["COA_PROFIT_REWARDS"] = "Reward value:"
L["COA_PROFIT_RESULT"] = "Profit:"
L["COA_QUALITY_TOOLTIP_CONC_COST"] = "Concentration to next quality:"
L["COA_STATUS_SHOP_TEMP_FAILED"] = "Could not create a temporary HironCraft Shop list."
L["COA_STATUS_SHOP_UNAVAILABLE"] = "HironCraft Shop temporary shopping session API is unavailable."

L["COA_PROF_TOOL_SLOT_TITLE"] = "Profession tool"
L["COA_BEST_QUALITY_TITLE"] = "Use best quality reagents"
L["COA_BEST_QUALITY_DESC"] = "Always allocate the highest quality reagents for every recipe. Highlighted when enabled."
L["COA_PROF_TOOL_EMPTY"] = "No profession tool is equipped for the current profession."
L["COA_PROF_TOOL_STAT_FMT"] = "Tool stat: %s"
L["COA_PROF_TOOL_CLICK_HINT"] = "Click to choose another tool from bags."
L["COA_PROF_TOOL_STAT_INGENUITY"] = "Ingenuity"
L["COA_PROF_TOOL_STAT_INSPIRATION"] = "Inspiration"
L["COA_PROF_TOOL_STAT_RESOURCEFULNESS"] = "Resourcefulness"
L["COA_PROF_TOOL_STAT_MULTICRAFT"] = "Multicraft"
L["COA_PROF_TOOL_STAT_CRAFTING_SPEED"] = "Crafting Speed"
L["COA_PROF_TOOL_STAT_FINESSE"] = "Finesse"
L["COA_PROF_TOOL_STAT_DEFTNESS"] = "Deftness"
L["COA_PROF_TOOL_STAT_PERCEPTION"] = "Perception"
L["COA_PROF_TOOL_MENU_TITLE"] = "Profession tools"
L["COA_PROF_TOOL_MENU_EMPTY"] = "No matching tools found in bags."
L["COA_STATUS_PROF_TOOL_COMBAT"] = "Cannot change profession tool in combat."
L["COA_STATUS_PROF_TOOL_EQUIP"] = "Equipping profession tool: %s."
L["COA_STATUS_PROF_TOOL_EQUIP_FAILED"] = "Could not equip the profession tool."

L["COA_EXPANSION_MIDNIGHT"] = "Midnight"
L["COA_EXPANSION_TWW"] = "TWW"
L["COA_EXPANSION_DF"] = "DF"
L["COA_EXPANSION_CURRENT_FMT"] = "Expansion: %s"
L["COA_EXPANSION_DROPDOWN_TITLE"] = "Profession expansion"
L["COA_EXPANSION_DROPDOWN_TOOLTIP"] = "Switches the actual profession expansion, like Blizzard's profession page dropdown."
L["COA_STATUS_EXPANSION_SELECTED"] = "Profession expansion: %s."
L["COA_STATUS_EXPANSION_UNAVAILABLE"] = "Profession expansion is unavailable for the current profession: %s."
L["COA_STATUS_EXPANSION_SWITCH_FAILED"] = "Could not switch profession expansion: %s."

L["COA_QUEUE_BUTTON"] = "Queue"
L["COA_QUEUE_TOOLTIP"] = "Builds a work-order queue with HironCraft checks and marks matching order buttons. It checks known recipes, available reagents, and required quality."
L["COA_QUEUE_REAGENT_MODE_AUTO"] = "Cheap"
L["COA_QUEUE_REAGENT_MODE_T1"] = "T1"
L["COA_QUEUE_REAGENT_MODE_T2"] = "T2"
L["COA_QUEUE_REAGENT_MODE_PROFIT"] = "Profit"
L["COA_QUEUE_REAGENT_MODE_CURRENT_FMT"] = "Reagents: %s"
L["COA_QUEUE_REAGENT_MODE_HINT"] = "Right-click: Cheap, T1, T2 or Profit."
L["COA_STATUS_QUEUE_REAGENT_MODE"] = "Queue reagent mode: %s."
L["COA_QUEUE_PROFIT_FILTER_OFF"] = "Off"
L["COA_QUEUE_PROFIT_FILTER_HEADER"] = "Profit filter"
L["COA_QUEUE_PROFIT_FILTER_CURRENT_FMT"] = "Minimum profit: %s"
L["COA_QUEUE_PROFIT_FILTER_CLEAR"] = "Disable profit filter"
L["COA_QUEUE_AUTO_ON_OPEN_HEADER"] = "Auto queue"
L["COA_QUEUE_AUTO_ON_OPEN"] = "Auto-queue on open"
L["COA_QUEUE_AUTO_SHOPPING"] = "Auto-shopping after auto-queue"
L["COA_STATUS_AUTOQUEUE_ON"] = "Auto-queue enabled."
L["COA_STATUS_AUTOQUEUE_OFF"] = "Auto-queue disabled."
L["COA_STATUS_AUTOSHOP_ON"] = "Auto-shopping enabled."
L["COA_STATUS_AUTOSHOP_OFF"] = "Auto-shopping disabled."
L["COA_QUEUE_PROFIT_FILTER_POPUP"] = "Minimum queue profit in gold. Negative values are allowed. Empty value disables the filter."
L["COA_STATUS_QUEUE_PROFIT_FILTER"] = "Queue profit filter: %s."
L["COA_STATUS_QUEUE_PROFIT_FILTER_OFF"] = "Queue profit filter disabled."
L["COA_STATUS_QUEUE_PROFIT_FILTER_INVALID"] = "Queue profit filter: enter a number."
L["COA_STATUS_QUEUE_BUILDING"] = "Building work order queue..."
L["COA_STATUS_QUEUED_ORDERS"] = "Queued orders: %d."
L["COA_STATUS_QUEUE_VIEW_ONLY"] = "Queue can only be built while the crafting orders page is available."
L["COA_STATUS_QUEUE_NO_TYPES"] = "No work order types are enabled for the queue."
L["COA_WEEKLY_QUEST_TAKEN_SHORT"] = "Quest: taken"
L["COA_WEEKLY_QUEST_NOT_TAKEN_SHORT"] = "Quest: no"
L["COA_WEEKLY_QUEST_DONE_SHORT"] = "Quest: done"
L["COA_WEEKLY_QUEST_UNKNOWN_SHORT"] = "Quest: —"
L["COA_WEEKLY_QUEST_TOOLTIP_TITLE"] = "Weekly profession quest"
L["COA_WEEKLY_QUEST_TOOLTIP_TAKEN"] = "The weekly profession quest is in your quest log."
L["COA_WEEKLY_QUEST_TOOLTIP_NOT_TAKEN"] = "The weekly profession quest is not in your quest log."
L["COA_WEEKLY_QUEST_TOOLTIP_DONE"] = "The weekly profession quest is already completed this week."
L["COA_WEEKLY_QUEST_TOOLTIP_NONE"] = "No weekly quest entry was found for this profession in HironCraft knowledge data."
L["COA_WEEKLY_QUEST_TOOLTIP_UNKNOWN"] = "Could not match the current profession expansion to HironCraft knowledge data."
L["COA_WEEKLY_QUEST_STATE_TAKEN"] = "taken"
L["COA_WEEKLY_QUEST_STATE_NOT_TAKEN"] = "not taken"
L["COA_WEEKLY_QUEST_STATE_DONE"] = "done"
L["COA_WEEKLY_QUEST_STATE_UNKNOWN"] = "unknown"
L["COA_WEEKLY_QUEST_FALLBACK_NAME"] = "Weekly profession quest"


