local PT = HironCraftProfit or {}
HironCraftProfit = PT
PT.DB = PT.DB or {}
PT.DB.TWW = PT.DB.TWW or {}
local L = PT.L

local HironCraftProfit_Profession      = PT.HironCraftProfit_Profession
local HironCraftProfit_UniqueTreasure  = PT.HironCraftProfit_UniqueTreasure
local HironCraftProfit_UniqueBook      = PT.HironCraftProfit_UniqueBook
local HironCraftProfit_WeeklyTreasure  = PT.HironCraftProfit_WeeklyTreasure
local HironCraftProfit_WeeklyQuestItem = PT.HironCraftProfit_WeeklyQuestItem
local HironCraftProfit_DarkmoonQuest   = PT.HironCraftProfit_DarkmoonQuest
local HironCraftProfit_CatchUp         = PT.HironCraftProfit_CatchUp
local HironCraftProfit_Treatise        = PT.HironCraftProfit_Treatise

local questIdIdx  = PT.questIdIdx
local spellIdIdx  = PT.spellIdIdx
local idIdx       = PT.idIdx

    -- Alchemy
do
	local p = HironCraftProfit_Profession:New(2871, 423321, 3057)
	p.expansion = "TWW"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83840}, 
		itemId=226265, 
		waypoint={map=2339, x=0.3245, y=0.6034}, 
		kp=3
	})  -- "Earthen Iron Powder"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83841}, 
		itemId=226266, 
		waypoint={map=2248, x=0.5770, y=0.6177}, 
		kp=3
	})  -- "Metal Dornogal Frame"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83842}, 
		itemId=226267, 
		waypoint={map=2214, x=0.3803, y=0.2415}, 
		kp=3
	})  -- "Reinforced Beaker"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83843}, 
		itemId=226268, 
		waypoint={map=2214, x=0.6081, y=0.6174}, 
		kp=3
	})  -- "Engraved Stirring Rod"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83844}, 
		itemId=226269, 
		waypoint={map=2215, x=0.4265, y=0.5510},
		kp=3
	})  -- "Chemist's Purified Water"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83845}, 
		itemId=226270, 
		waypoint={map=2215, x=0.4166, y=0.5583}, 
		kp=3
	})  -- "Sanctified Mortar and Pestle"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83846}, 
		itemId=226271, 
		waypoint={map=2213, x=0.4537, y=0.1322}, 
		kp=3
	})  -- "Nerubian Mixing Salts"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83847}, 
		itemId=226272, 
		waypoint={map=2255, x=0.4288, y=0.5724}, 
		kp=3
	})  -- "Dark Apothecary's Vial"
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={81146}, 
		itemId=227409, 
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=10, 
		spell=459885, 
		itemRequirements={{
			id=210814, 
			quantity=200
			}} 
		}) -- Lyrendal. 200 - Faded Alchemist's Research 
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={81147}, 
		itemId=227420, 
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=10, 
		spell=459886, 
		itemRequirements={{
			id=210814, 
			quantity=300
			}} 
		}) -- Lyrendal. 300 - Exceptional Alchemist's Research 
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={81148}, 
		itemId=227431,
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=10, 
		spell=459887, 
		itemRequirements={{
			id=210814, 
			quantity=400
			}} 
		}) -- Lyrendal. 400 - Pristine Alchemist's Research 
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={83058}, 
		itemId=224645, 
		waypoint={map=2339, x=0.3908, y=0.2414}, 
		kp=10, 
		spell=453440, 
		renown={majorFactionId=2590, levelRequired=12}
	}) -- Council of Dornogal Rank 12, 1625 Resonance Crystals, 2815 - Jewel-Etched Alchemy Notes 
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={85734}, 
		itemId=232499, 
		waypoint={map=2346, x=0.4386, y=0.5082}, 
		kp=10, 
		spell=470728, 
		renown={majorFactionId=2653, levelRequired=16}
	}) -- Undermine Treatise on Blacksmithing
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={82633}, 
		itemId=224024, 
		waypoint={map=2213, x=0.5560, y=0.4700}, 
		kp=10, 
		spell=450818, 
		currency={id=3056, quantity=565}
	}) -- Theories of Bodily Transmutation, Chapter 8, 565 kej (3056) - Theories of Bodily Transmutation, Chapter 8 
    p:AddEntry(HironCraftProfit_Treatise:New {
		questId={83725}, 
		itemId=222546, 
		waypoint={map=2339, x=0.5804, y=0.5645}, 
		kp=1,
		spell=457715, 
		atlasIcon="Professions-Crafting-Orders-Icon", 
		text=L["IncWO"]
	}) -- Algari Treatise on Alchemy (Requires skill 25)
    p:AddEntry(HironCraftProfit_WeeklyQuestItem:New {
		questId={84133}, 
		itemId=228773, 
		waypoint={map=2339, x=0.5916, y=0.5527}, 
		kp=2, 
		text=L["CraftOQ"]
	}) -- Algari Alchemist's Notebook
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
		questId={83253}, 
		itemId=225234, 
		kp=2,
		text= L["Found on treasures"]
	}) -- Alchemical Sediment +2, Treasure Hunt
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
		questId={83255}, 
		itemId=225235, 
		kp=2,
		text= L["Found on treasures"]
	}) -- Deepstone Crucible + 2, Treasure Hunt
    p:AddEntry(HironCraftProfit_DarkmoonQuest:New{
		questId={29506}, 
		waypoint={map=407, x=0.5049, y=0.6955}, 
		itemRequirements={{id=1645, quantity=5}}, 
		kp=3
	}) -- DMF A Fizzy Fusion
    p:AddEntry(HironCraftProfit_CatchUp:New{
		questId={}, 
		itemId=228724, 
		atlasIcon="Professions-Crafting-Orders-Icon", 
		unlockRequirements={
			questIdIdx[83253], 
			questIdIdx[83255], 
			questIdIdx[84133]
			}, 
		kp=1, 
		text=PROFESSIONS_CRAFTING_ORDERS_PAGE_NAME:format(PROFESSIONS_CRAFTER_ORDER_TAB_NPC)
	}) -- Catch up mechanic
    PT.DB.TWW[2871] = p
end	
    -- Blacksmithing
do
	local p = HironCraftProfit_Profession:New(2872, 423332, 3058)
	p.expansion = "TWW"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83848}, 
		itemId=226276, 
		waypoint={map=2248, x=0.59827, y=0.6191}, 
		kp=3
	}) -- "Ancient Earthen Anvil"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83849}, 
		itemId=226277, 
		waypoint={map=2339, x=0.4757, y=0.2623}, 
		kp=3
	}) -- "Dornogal Hammer"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83850}, 
		itemId=226278, 
		waypoint={map=2214, x=0.4355, y=0.3316}, 
		kp=3
	}) -- "Ringing Hammer Vise"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83851}, 
		itemId=226279, 
		waypoint={map=2214, x=0.5637, y=0.5367}, 
		kp=3
	}) -- "Earthen Chisels"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83852}, 
		itemId=226280, 
		waypoint={map=2215, x=0.4758, y=0.6106}, 
		kp=3
	}) -- "Holy Flame Forge"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83853}, 
		itemId=226281, 
		waypoint={map=2215, x=0.4406, y=0.5558},
		kp=3
	}) -- "Radiant Tongs"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83854}, 
		itemId=226282, 
		waypoint={map=2213, x=0.4651, y=0.2292}, 
		kp=3
	}) -- "Nerubian Smith's Kit"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83855}, 
		itemId=226283, 
		waypoint={map=2255, x=0.5295, y=0.5125}, 
		kp=3
	}) -- "Spiderling's Wire Brush"
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={84226}, 
		itemId=227407, 
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=10, 
		spell=459888, 
		itemRequirements={{id=210814, quantity=200}} 
	}) -- Faded Blacksmith's Diagrams 200
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={84227}, 
		itemId=227418, 
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=10, 
		spell=459889, 
		itemRequirements={{id=210814, quantity=300}} 
	}) -- Lyrendal, 300
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={84228}, 
		itemId=227429,
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=10, 
		spell=459890, 
		itemRequirements={{id=210814, quantity=400}} 
	}) -- Lyrendal, 400
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={83059}, 
		itemId=224647, 
		waypoint={map=2339, x=0.3920, y=0.2420}, 
		kp=10, 
		spell=453443, 
		renown={majorFactionId=2590, levelRequired=12}, 
		itemRequirements={{id=210814, quantity=50}} 
	}) -- Jewel-Etched Blacksmithing Notes, Renown 12 Council of Dornogal
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={85735},
		itemId=232500, 
		waypoint={map=2346, x=0.4386, y=0.5082}, 
		kp=10, 
		spell=470729, 
		renown={majorFactionId=2653, levelRequired=16}
	}) -- Undermine Treatise on Blacksmithing
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={82631}, 
		itemId=224038, 
		waypoint={map=2213, x=0.4680, y=0.2220},
		kp=10, 
		spell=450819,
		currency={id=3056, quantity=565}
	}) -- Smithing After Saronite
    p:AddEntry(HironCraftProfit_Treatise:New{
		questId={83726}, 
		itemId=222554, 
		waypoint={map=2339, x=0.5804, y=0.5645},
		kp=1, 
		spell=457717, 
		atlasIcon="Professions-Crafting-Orders-Icon", 
		text=L["IncWO"]
	}) -- Algari Treatise on Blacksmithing (Requires skill 25)
    p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
		questId={84127}, 
		itemId=228774, 
		waypoint={map=2339, x=0.5916, y=0.5527}, 
		kp=2, 
		text=L["CraftOQ"]
	}) -- Algari Blacksmith's Journal
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
		questId={83256}, 
		itemId=225233, 
		kp=1,
		text= L["Found on treasures"]
	}) -- Dense Bladestone
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
		questId={83257}, 
		itemId=225232, 
		kp=1,
		text= L["Found on treasures"]
	}) -- Coreway Billet
    p:AddEntry(HironCraftProfit_DarkmoonQuest:New{
		questId={29508}, 
		waypoint={map=407, x=0.5110, y=0.8204},
		kp=3
	}) -- DMF Baby Needs Two Pair of Shoes
    p:AddEntry(HironCraftProfit_CatchUp:New{
		questId={}, 
		itemId=228726,
		atlasIcon="Professions-Crafting-Orders-Icon", 
		unlockRequirements={
			questIdIdx[83256], 
			questIdIdx[83257], 
			questIdIdx[84127]
			}, 
		kp=1, 
		text=PROFESSIONS_CRAFTING_ORDERS_PAGE_NAME:format(PROFESSIONS_CRAFTER_ORDER_TAB_NPC)
	}) -- Catch up mechanic
    PT.DB.TWW[2872] = p
end    
    -- Enchanting 
do
	local p = HironCraftProfit_Profession:New(2874, 423334, 3059)
	p.expansion = "TWW"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83856}, 
		itemId=226284, 
		waypoint={map=2248, x=0.5759, y=0.6164}, 
		kp=3
	}) -- "Grinded Earthen Gem"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83859}, 
		itemId=226285, 
		waypoint={map=2339, x=0.5803, y=0.5695},
		kp=3
	}) -- "Silver Dornogal Rod"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83860}, 
		itemId=226286, 
		waypoint={map=2214, x=0.4046, y=0.22132}, 
		kp=3
	}) -- "Soot-Coated Orb"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83861}, 
		itemId=226287, 
		waypoint={map=2214, x=0.6304, y=0.6589}, 
		kp=3
	}) -- "Animated Enchanting Dust"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83862}, 
		itemId=226288, 
		waypoint={map=2215, x=0.4006, y=0.7055},
		kp=3
	}) -- "Essence of Holy Fire"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83863}, 
		itemId=226289,
		waypoint={map=2215, x=0.4859, y=0.6450},
		kp=3
	}) -- "Enchanted Arathi Scroll"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83864}, 
		itemId=226290, 
		waypoint={map=2213, x=0.6172, y=0.2200}, 
		kp=3
	}) -- "Book of Dark Magic"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83865}, 
		itemId=226291,
		waypoint={map=2255, x=0.5736, y=0.4404}, 
		kp=3
	}) -- "Void Shard"
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={81076}, 
		itemId=227411, 
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=10, 
		spell=459891, 
		itemRequirements={{id=210814, quantity=200}} 
	}) -- Lyrendal, 200
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={81077}, 
		itemId=227422, 
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=10, 
		spell=459892, 
		itemRequirements={{id=210814, quantity=300}}		
	}) -- Lyrendal, 300
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={81078}, 
		itemId=227433, 
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=10, 
		spell=459893, 
		itemRequirements={{id=210814, quantity=400}} 
	}) -- Lyrendal, 400
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={83060}, 
		itemId=224652, 
		waypoint={map=2339, x=0.3920, y=0.2420}, 
		kp=10, 
		spell=453444, 
		renown={majorFactionId=2590, levelRequired=12}
	}) -- Jewel-Etched Enchanting Notes
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={85736}, 
		itemId=232501, 
		waypoint={map=2346, x=0.4386, y=0.5082}, 
		kp=10, 
		spell=470730, 
		renown={majorFactionId=2653, levelRequired=16}
	}) -- Undermine Treatise on Enchanting
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={82635}, 
		itemId=224050, 
		waypoint={map=2213, x=0.4580, y=0.3320}, 
		kp=10, 
		spell=450821, 
		currency={id=3056, quantity=565}
	}) -- Web Sparkles: Pretty and Powerful
    p:AddEntry(HironCraftProfit_Treatise:New{
		questId={83727}, 
		itemId=222550, 
		waypoint={map=2339, x=0.5804, y=0.5645}, 
		kp=1, 
		spell=457718, 
		atlasIcon="Professions-Crafting-Orders-Icon", 
		text=L["IncWO"]
	}) -- Algari Treatise on Enchanting (Requires skill 25)
    p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
		questId={84084, 84085, 84086}, 
		itemId=227667, 
		waypoint={map=2339, x=0.5292, y=0.7132}, 
		kp=3, 
		text=L["TQ"], 
		unique=true
	}) -- Algari Enchanter's Folio
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
		questId={84290, 84291, 84292, 84293, 84294}, 
		itemId=227659, 
		kp=1, 
		atlasIcon="lootroll-toast-icon-disenchant-up", 
		text=L["LittleDis"]
	}) -- "Fleeting Arcane Manifestation"
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
		questId={84295}, 
		itemId=227661, 
		kp=4, 
		atlasIcon="lootroll-toast-icon-disenchant-up", 
		text=L["BigDis"]
	}) -- "Gleaming Telluric Crystal"
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
		questId={83258}, 
		itemId=225231, 
		kp=1,
		text= L["Found on treasures"]
	}) -- Powdered Fulgurance
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
		questId={83259}, 
		itemId=225230, 
		kp=1,
		text= L["Found on treasures"]
	}) -- Crystalline Repository
    p:AddEntry(HironCraftProfit_DarkmoonQuest:New{
		questId={29510}, 
		waypoint={map=407, x=0.5316, y=0.7587}, 
		kp=3
	}) -- DMF Putting Trash to Good Use
    p:AddEntry(HironCraftProfit_CatchUp:New{
		questId={}, 
		itemId=227662, 
		catchUpCurrencyId=3059, 
		atlasIcon="lootroll-toast-icon-disenchant-up", 
		unlockRequirements={
			questIdIdx[83258], 
			questIdIdx[83259], 
			questIdIdx[84084],
			questIdIdx[84290], 
			questIdIdx[84295]}, 
		kp=1
	}) -- Catch up mechanic
    PT.DB.TWW[2874] = p
end
    -- Engineering
do
	local p = HironCraftProfit_Profession:New(2875, 423335, 3060)
	p.expansion = "TWW"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83866}, 
		itemId=226292, 
		waypoint={map=2248, x=0.6136, y=0.6957}, 
		kp=3
	}) -- "Rock Engineer's Wrench"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83867}, 
		itemId=226293,
		waypoint={map=2339, x=0.6466, y=0.5258}, 
		kp=3
	}) -- "Dornogal Spectacles"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83868}, 
		itemId=226294, 
		waypoint={map=2214, x=0.3852, y=0.2729}, 
		kp=3
	}) -- "Inert Mining Bomb"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83869},
		itemId=226295, 
		waypoint={map=2214, x=0.6044, y=0.5873}, 
		kp=3
	}) -- "Earthen Construct Blueprints"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83870}, 
		itemId=226296, 
		waypoint={map=2215, x=0.4632, y=0.6136},
		kp=3
	}) -- "Holy Firework Dud"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83871}, 
		itemId=226297, 
		waypoint={map=2215, x=0.4161, y=0.4889}, 
		kp=3
	}) -- "Arathi Safety Gloves"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83872}, 
		itemId=226298,
		waypoint={map=2255, x=0.5690, y=0.3864}, 
		kp=3
	}) -- "Puppeted Mechanical Spider"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83873}, 
		itemId=226299, 
		waypoint={map=2213, x=0.6317, y=0.1133}, 
		kp=3
	}) -- "Emptied Venom Canister"
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={84229}, 
		itemId=227412, 
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=10, 
		spell=459894, 
		itemRequirements={{id=210814, quantity=200}} 
	}) -- Lyrendal. 200
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={84230}, 
		itemId=227423, 
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=10, 
		spell=459895, 
		itemRequirements={{id=210814, quantity=300}} 
	}) -- Lyrendal, 300
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={84231}, 
		itemId=227434, 
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=10, 
		spell=459896, 
		itemRequirements={{id=210814, quantity=400}} 
	}) -- Lyrendal, 400
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={83063}, 
		itemId=224653, 
		waypoint={map=2214, x=0.4315, y=0.3293}, 
		kp=10, 
		spell=453450, 
		renown={majorFactionId=2594, levelRequired=12}
	}) -- Machine-Learned Engineering Notes, Renown 12 The Assembly of the Deeps 
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={85737}, 
		itemId=232507, 
		waypoint={map=2346, x=0.4386, y=0.5082}, 
		kp=10, 
		spell=470731, 
		renown={majorFactionId=2653, levelRequired=16}
	}) -- Undermine Treatise on Engineering
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={82632}, 
		itemId=224052, 
		waypoint={map=2213, x=0.5787, y=0.3205}, 
		kp=10, 
		spell=450824, 
		currency={id=3056, quantity=565}
	}) -- Clocks, Gears, Sprockets, and Legs, 565 kej
    p:AddEntry(HironCraftProfit_Treatise:New{
		questId={83728}, 
		itemId=222621, 
		waypoint={map=2339, x=0.5804, y=0.5645}, 
		kp=1, 
		spell=457721, 
		atlasIcon="Professions-Crafting-Orders-Icon", 
		text=L["IncWO"]
	}) -- Algari Treatise on Engineering (Requires skill 25)
    p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
		questId={84128}, 
		itemId=228775, 
		waypoint={map=2339, x=0.5916, y=0.5527}, 
		kp=1, 
		text=L["CraftOQ"]
	}) -- Algari Engineer's Notepad
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
		questId={83260}, 
		itemId=225228, 
		kp=1,
		text= L["Found on treasures"]
		}) -- Rust-Locked Mechanism
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
		questId={83261}, 
		itemId=225229, 
		kp=1,
		text= L["Found on treasures"]
	}) -- Earthen Induction Coil
    p:AddEntry(HironCraftProfit_DarkmoonQuest:New{
		questId={29511}, 
		waypoint={map=407, x=0.4925, y=0.6078}, 
		kp=3
	}) -- DMF Talkin' Tonks
    p:AddEntry(HironCraftProfit_CatchUp:New{
		questId={}, 
		itemId=228730, 
		atlasIcon="Professions-Crafting-Orders-Icon", 
		unlockRequirements={
			questIdIdx[83260], 
			questIdIdx[83261], 
			questIdIdx[84128]
			}, 
		kp=1, 
		text=PROFESSIONS_CRAFTING_ORDERS_PAGE_NAME:format(PROFESSIONS_CRAFTER_ORDER_TAB_NPC)
	}) -- Catch up mechanic
    PT.DB.TWW[2875] = p
end
    -- Herbalism 
do
	local p = HironCraftProfit_Profession:New(2877, 441327, 3061)
    p.expansion = "TWW"	
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83874}, 
		itemId=226300,
		waypoint={map=2248, x=0.5755, y=0.6146}, 
		kp=3
	}) -- "Ancient Flower"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83875}, 
		itemId=226301, 
		waypoint={map=2339, x=0.5925, y=0.2354},
		kp=3
	}) -- "Dornogal Gardening Scythe"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83876}, 
		itemId=226302, 
		waypoint={map=2214, x=0.4409, y=0.3504},
		kp=3
	}) -- "Earthen Digging Fork"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83877},
		itemId=226303,
		waypoint={map=2214, x=0.4876, y=0.6581}, 
		kp=3
	}) -- "Fungarian Slicer's Knife"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83878}, 
		itemId=226304, 
		waypoint={map=2215, x=0.4778, y=0.6331}, 
		kp=3
	}) -- "Arathi Garden Trowel"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83879}, 
		itemId=226305,
		waypoint={map=2215, x=0.3597, y=0.5501}, 
		kp=3
	}) -- "Arathi Herb Pruner"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83880}, 
		itemId=226306, 
		waypoint={map=2213, x=0.5459, y=0.2089}, 
		kp=3
	}) -- "Web-Entangled Lotus"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83881}, 
		itemId=226307, 
		waypoint={map=2213, x=0.4677, y=0.1613}, 
		kp=3
	}) -- "Tunneler's Shovel"
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={81422}, 
		itemId=227415, 
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=15, 
		spell=459897, 
		itemRequirements={{id=210814, quantity=200}} 
	}) -- Lyrendal, 200
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={81423},
		itemId=227426, 
		waypoint={map=2339, x=0.5983, y=0.5643},
		kp=15, 
		spell=459898, 
		itemRequirements={{id=210814, quantity=300}}
	}) -- Lyrendal, 300
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={81424}, 
		itemId=227437, 
		waypoint={map=2339, x=0.5983, y=0.5643},
		kp=15, 
		spell=459899, 
		itemRequirements={{id=210814, quantity=400}} 
	}) -- Lyrendal, 400
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={83066}, 
		itemId=224656, 
		waypoint={map=2215, x=0.4120, y=0.5300}, 
		kp=10, 
		spell=453454, 
		renown={majorFactionId=2570, levelRequired=14}
	}) -- Void-Lit Herbalism Notes
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={85738}, 
		itemId=232503, 
		waypoint={map=2346, x=0.4386, y=0.5082}, 
		kp=10, 
		spell=470732, 
		renown={majorFactionId=2653, levelRequired=16}
	}) -- Undermine Treatise on Herbalism
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={82630}, 
		itemId=224023, 
		waypoint={map=2213, x=0.4701, y=0.1620}, 
		kp=10, 
		spell=450793, 
		currency={id=3056, quantity=565}
	}) -- Herbal Embalming Techniques
    p:AddEntry(HironCraftProfit_Treatise:New{
		questId={83729}, 
		itemId=222552,
		waypoint={map=2339, x=0.5804, y=0.5645}, 
		kp=1, 
		spell=457723, 
		atlasIcon="Professions-Crafting-Orders-Icon", 
		text=L["IncWO"]
	}) -- Algari Treatise on Herbalism (Requires skill 25)
    p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
		questId={82970, 82958, 82965, 82916, 82962}, 
		itemId=224817,  
		waypoint={map=2339, x=0.4476, y=0.6929}, 
		kp=3, 
		text=L["TQ"], 
		unique=true
	}) -- "Algari Herbalist's Notes"
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
		questId={81416, 81417, 81418, 81419, 81420}, 
		itemId=224264, 
		kp=1, 
		atlasIcon="Professions_Tracking_Herb", 
		text=L["LittleHerb"]
	}) -- "Deepgrove Rose Petal"
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
		questId={81421}, 
		itemId=224265, 
		kp=4, 
		atlasIcon="Professions_Tracking_Herb", 
		text=L["BigHerb"]
	}) -- "Deepgrove Rose"
    p:AddEntry(HironCraftProfit_DarkmoonQuest:New{
		questId={29514}, 
		waypoint={map=407, x=0.5500, y=0.7076}, 
		kp=3
	}) -- DMF Herbs for Healing
    p:AddEntry(HironCraftProfit_CatchUp:New{
		questId={}, 
		itemId=224835, 
		catchUpCurrencyId=3061, 
		unlockRequirements={
			questIdIdx[81416], 
			questIdIdx[81421], 
			questIdIdx[82970]}, 
		atlasIcon="Professions_Tracking_Herb", 
		kp=1
	}) -- Catch up mechanic
    PT.DB.TWW[2877] = p
end
    -- Inscription 
do
	local p = HironCraftProfit_Profession:New(2878, 423338, 3062)
	p.expansion = "TWW"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83882}, 
		itemId=226308, 
		waypoint={map=2339, x=0.5725, y=0.4690}, 
		kp=3
	}) -- "Dornogal Scribe's Quill"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83883}, 
		itemId=226309, 
		waypoint={map=2248, x=0.55975, y=0.6001},
		kp=3
	}) -- "Historian's Dip Pen"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83884}, 
		itemId=226310, 
		waypoint={map=2214, x=0.4441, y=0.3432}, 
		kp=3
	}) -- "Runic Scroll"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83885}, 
		itemId=226311, 
		waypoint={map=2214, x=0.5831, y=0.5801}, 
		kp=3
	}) -- "Blue Earthen Pigment"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83886}, 
		itemId=226312, 
		waypoint={map=2215, x=0.4325, y=0.5894}, 
		kp=3
	}) -- "Informant's Fountain Pen"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83887}, 
		itemId=226313, 
		waypoint={map=2215 ,x=0.4283, y=0.4906}, 
		kp=3
	}) -- "Calligrapher's Chiselled Marker" Get inside through the balcony door
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83888}, 
		itemId=226314, 
		waypoint={map=2255, x=0.5583, y=0.4389}, 
		kp=3
	}) -- "Nerubian Texts"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83889}, 
		itemId=226315, 
		waypoint={map=2213, x=0.5023, y=0.3085},
		kp=3
	}) -- "Venomancer's Ink Well"
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={80749}, 
		itemId=227408, 
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=10, 
		spell=459900, 
		itemRequirements={{id=210814, quantity=200}} 
	}) -- Lyrendal, 200
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={80750}, 
		itemId=227419, 
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=10, 
		spell=459901, 
		itemRequirements={{id=210814, quantity=300}} 
	}) -- Lyrendal, 300
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={80751}, 
		itemId=227430, 
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=10, 
		spell=459902, 
		itemRequirements={{id=210814, quantity=400}} 
	}) -- Lyrendal, 400
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={83064}, 
		itemId=224654, 
		waypoint={map=2214, x=0.4315, y=0.3293}, 
		kp=10, 
		spell=453452, 
		renown={majorFactionId=2594, levelRequired=12}
	}) -- Machine-Learned Inscription Notes
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={85739}, 
		itemId=232508, 
		waypoint={map=2346, x=0.4386, y=0.5082}, 
		kp=10, 
		spell=470733, 
		renown={majorFactionId=2653, levelRequired=16}
	}) -- Undermine Treatise on Inscription
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={82636},
		itemId=224053, 
		waypoint={map=2213, x=0.4228, y=0.2616},
		kp=10, 
		spell=450827, 
		currency={id=3056, quantity=565}
	}) -- Eight Views on Defense against Hostile Runes
    p:AddEntry(HironCraftProfit_Treatise:New{
		questId={83730}, 
		itemId=222548, 
		waypoint={map=2339, x=0.5804, y=0.5645}, 
		kp=1, spell=457722, 
		atlasIcon="Professions-Crafting-Orders-Icon", 
		text=L["IncWO"] 
	}) -- Algari Treatise on Inscription (Requires skill 25)
    p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
		questId={84129}, 
		itemId=228776, 
		waypoint={map=2339, x=0.5916, y=0.5527}, 
		kp=2, 
		text=L["CraftOQ"] 
	}) -- Algari Scribe's Journal
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
		questId={83262}, 
		itemId=225227, 
		kp=2,
		text= L["Found on treasures"]
	}) -- Wax-Sealed Records
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
		questId={83264}, 
		itemId=225226, 
		kp=2,
		text= L["Found on treasures"]
	}) -- Striated Inkstone
    p:AddEntry(HironCraftProfit_DarkmoonQuest:New{
		questId={29515}, 
		waypoint={map=407, x=0.5325, y=0.7584}, 
		itemRequirements={{id=39354, quantity=5}}, 
		kp=3
	}) -- DMF Writing the Future
    p:AddEntry(HironCraftProfit_CatchUp:New{
		questId={}, 
		itemId=228732, 
		atlasIcon="Professions-Crafting-Orders-Icon", 
		unlockRequirements={
			questIdIdx[83262], 
			questIdIdx[83264], 
			questIdIdx[84129]}, 
			kp=1, 
			text=PROFESSIONS_CRAFTING_ORDERS_PAGE_NAME:format(PROFESSIONS_CRAFTER_ORDER_TAB_NPC)
	}) -- Catch up mechanic
    PT.DB.TWW[2878] = p
end
    -- Jewelcrafting
do
	local p = HironCraftProfit_Profession:New(2879, 423339, 3063)
	p.expansion = "TWW"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83890}, 
		itemId=226316, 
		waypoint={map=2248, x=0.6353, y=0.6688}, 
		kp=3
		}) -- "Gentle Jewel Hammer" Door at 63.05 67.20
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83891}, 
		itemId=226317, 
		waypoint={map=2339, x=0.3484, y=0.5217}, 
		kp=3
		}) -- "Earthen Gem Pliers"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83892}, 
		itemId=226318, 
		waypoint={map=2214, x=0.4433, y=0.3512}, 
		kp=3
		}) -- "Carved Stone File" Door at 48.12 34.69
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83893}, 
		itemId=226319, 
		waypoint={map=2214, x=0.5283, y=0.5454}, 
		kp=3
		}) -- "Jeweler's Delicate Drill" Door at 57.51 54.80
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83894}, 
		itemId=226320, 
		waypoint={map=2215, x=0.4739, y=0.6068}, 
		kp=3
		}) -- "Arathi Sizing Gauges"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83895}, 
		itemId=226321, 
		waypoint={map=2215, x=0.4469, y=0.5097}, 
		kp=3
		}) -- "Librarian's Magnifiers" Top Floor
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83896}, 
		itemId=226322, 
		waypoint={map=2213, x=0.4782, y=0.1952}, 
		kp=3
		}) -- "Ritual Caster's Crystal"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83897}, 
		itemId=226323, 
		waypoint={map=2255, x=0.5615, y=0.5867}, 
		kp=3
		}) -- "Nerubian Bench Blocks"
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={81259}, 
		itemId=227413, 
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=10, 
		spell=459903, 
		itemRequirements={{id=210814, quantity=200}} 
		}) -- Lyrendal, 200
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={81260}, 
		itemId=227424, 
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=10, 
		spell=459904, 
		itemRequirements={{id=210814, quantity=300}} 
		}) -- Lyrendal, 300
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={81261}, 
		itemId=227435, 
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=10, 
		spell=459905, 
		itemRequirements={{id=210814, quantity=400}} 
		}) -- Lyrendal, 400
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={83065}, 
		itemId=224655, 
		waypoint={map=2215, x=0.4123, y=0.5300}, 
		kp=10, 
		spell=453453, 
		renown={majorFactionId=2570, levelRequired=14}
		}) -- Void-Lit Jewelcrafting Notes
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={85740}, 
		itemId=232504, 
		waypoint={map=2346, x=0.4386, y=0.5082}, 
		kp=10, 
		spell=470735, 
		renown={majorFactionId=2653, levelRequired=16}
		}) -- Undermine Treatise on Jewelcrafting
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={82637}, 
		itemId=224054, 
		waypoint={map=2213, x=0.4779, y=0.1871}, 
		kp=10, 
		spell=450828, 
		currency={id=3056, quantity=565}
		}) -- Emergent Crystals of the Surface-Dwellers
    p:AddEntry(HironCraftProfit_Treatise:New {
		questId={83731}, 
		itemId=222551, 
		waypoint={map=2339, x=0.5804, y=0.5645}, 
		kp=1, 
		spell=457725, 
		atlasIcon="Professions-Crafting-Orders-Icon", 
		text=L["IncWO"]
		}) -- Algari Treatise on Jewelcrafting (Requires skill 25)
    p:AddEntry(HironCraftProfit_WeeklyQuestItem:New {
		questId={84130}, 
		itemId=228777, 
		waypoint={map=2339, x=0.5971, y=0.5627}, 
		kp=2, 
		text=L["CraftOQ"]
		}) -- Algari Jewelcrafter's Notebook
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
		questId={83265}, 
		itemId=225224, 
		kp=2,
		text= L["Found on treasures"]
		}) -- "Diaphanous Gem Shards" Kobyss Ritual Cache
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
		questId={83266}, 
		itemId=225225, 
		kp=2,
		text= L["Found on treasures"]
		}) -- "Deepstone Fragment" Deep-Lost Satchel 
    p:AddEntry(HironCraftProfit_DarkmoonQuest:New{
		questId={29516}, 
		waypoint={map=407, x=0.5500, y=0.7079}, 
		kp=3
		}) -- DMF Keeping the Faire Sparkling
    p:AddEntry(HironCraftProfit_CatchUp:New{
		questId={}, 
		itemId=228734, 
		atlasIcon="Professions-Crafting-Orders-Icon", 
		unlockRequirements={
			questIdIdx[83265], 
			questIdIdx[83266], 
			questIdIdx[84130]
			}, 
		kp=1, 
		text=PROFESSIONS_CRAFTING_ORDERS_PAGE_NAME:format(PROFESSIONS_CRAFTER_ORDER_TAB_NPC)
		}) -- Catch up mechanic
    PT.DB.TWW[2879] = p
end
    -- Leatherworking
do
	local p = HironCraftProfit_Profession:New(2880, 423340, 3064)
	p.expansion = "TWW"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83898}, 
		itemId=226324, 
		waypoint={map=2339, x=0.6826, y=0.2334}, 
		kp=3
		}) -- "Earthen Lacing Tools"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83899}, 
		itemId=226325,
		waypoint={map=2248, x=0.5865, y=0.3077}, 
		kp=3
		}) -- "Dornogal Craftsman's Flat Knife"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83900}, 
		itemId=226326, 
		waypoint={map=2214, x=0.4290, y=0.3489}, 
		kp=3
		}) -- "Underground Stropping Compound"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83901}, 
		itemId=226327,
		waypoint={map=2214, x=0.6013, y=0.6528}, 
		kp=3
		}) -- "Earthen Awl"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83902}, 
		itemId=226328, 
		waypoint={map=2215, x=0.4750, y=0.6513}, 
		kp=3
		}) -- "Arathi Beveler Set"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83903}, 
		itemId=226329, 
		waypoint={map=2215, x=0.4150, y=0.5783}, 
		kp=3
		}) -- "Arathi Leather Burnisher"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83904}, 
		itemId=226330, 
		waypoint={map=2213, x=0.5503, y=0.2695}, 
		kp=3
		}) -- "Nerubian Tanning Mallet"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83905}, 
		itemId=226331, 
		waypoint={map=2255, x=0.5999, y=0.5401}, 
		kp=3
		}) -- "Curved Nerubian Skinning Knife"
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={80978}, 
		itemId=227414, 
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=10, 
		spell=459906, 
		itemRequirements={{id=210814, quantity=200}} 
		}) -- Lyrendal, 200
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={80979}, 
		itemId=227425, 
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=10, 
		spell=459907, 
		itemRequirements={{id=210814, quantity=300}}
		}) -- Lyrendal, 300
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={80980}, 
		itemId=227436, 
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=10, 
		spell=459908, 
		itemRequirements={{id=210814, quantity=400}} 
		}) -- Lyrendal, 400
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={83068}, 
		itemId=224658, 
		waypoint={map=2215, x=0.4123, y=0.5300}, 
		kp=10, 
		spell=453456, 
		renown={majorFactionId=2570, levelRequired=14}
		}) -- Void-Lit Leatherworking Notes
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={85741}, 
		itemId=232505, 
		waypoint={map=2346, x=0.4386, y=0.5082}, 
		kp=10, 
		spell=470736, 
		renown={majorFactionId=2653, levelRequired=16}
		}) -- Undermine Treatise on Leatherworking
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={82626}, 
		itemId=224056, 
		waypoint={map=2213, x=0.4309, y=0.2065}, 
		kp=10, 
		spell=450835, 
		currency={id=3056, quantity=565}
		}) -- Uses for Leftover Husks (After You Take Them Apart)
    p:AddEntry(HironCraftProfit_Treatise:New {
		questId={83732}, 
		itemId=222549, 
		waypoint={map=2339, x=0.5804, y=0.5645}, 
		kp=1, 
		spell=457720, 
		atlasIcon="Professions-Crafting-Orders-Icon", 
		text=L["IncWO"]
		}) -- Algari Treatise on Leatherworking (Requires skill 25)
    p:AddEntry(HironCraftProfit_WeeklyQuestItem:New {
		questId={84131}, 
		itemId=228778, 
		waypoint={map=2339, x=0.5971, y=0.5627}, 
		kp=2, 
		text=L["CraftOQ"]
		}) -- Algari Leatherworker's Journal
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
		questId={83267}, 
		itemId=225223, 
		kp=1,
		text= L["Found on treasures"]
		}) -- Sturdy Nerubian Carapace
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
		questId={83268}, 
		itemId=225222, 
		kp=1,
		text= L["Found on treasures"]
		}) -- Stone-Leather Swatch
    p:AddEntry(HironCraftProfit_DarkmoonQuest:New{
		questId={29517}, 
		waypoint={map=407, x=0.4925, y=0.6079}, 
		itemRequirements={{id=6529, quantity=10},{id=2320, quantity=5},{id=6260, quantity=5}}, 
		kp=3
		}) -- DMF Eyes on the Prizes
    p:AddEntry(HironCraftProfit_CatchUp:New{
		questId={}, 
		itemId=228736, 
		atlasIcon="Professions-Crafting-Orders-Icon", 
		unlockRequirements={
			questIdIdx[83267], 
			questIdIdx[83268], 
			questIdIdx[84131]}, 
		kp=1, 
		text=PROFESSIONS_CRAFTING_ORDERS_PAGE_NAME:format(PROFESSIONS_CRAFTER_ORDER_TAB_NPC)
		}) -- Catch up mechanic
    PT.DB.TWW[2880] = p
end
    -- Mining 
do
	local p = HironCraftProfit_Profession:New(2881, 423341, 3065)
	p.expansion = "TWW"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83906}, 
		itemId=226332, 
		waypoint={map=2248, x=0.5819, y=0.6204}, 
		kp=3
		}) -- "Earthen Miner's Gavel"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83907}, 
		itemId=226333, 
		waypoint={map=2339, x=0.3670, y=0.7935}, 
		kp=3
		}) -- "Dornogal Chisel"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83908}, 
		itemId=226334, 
		waypoint={map=2214, x=0.4527, y=0.2754}, 
		kp=3
		}) -- "Earthen Excavator's Shovel"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83909}, 
		itemId=226335, 
		waypoint={map=2214, x=0.6211, y=0.6623}, 
		kp=3
		}) -- "Regenerating Ore"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83910}, 
		itemId=226336, 
		waypoint={map=2215, x=0.4607, y=0.6439}, 
		kp=3
		}) -- "Arathi Precision Drill"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83911}, 
		itemId=226337, 
		waypoint={map=2215, x=0.4309, y=0.5685}, 
		kp=3
		}) -- "Devout Archaeologist's Excavator"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83912}, 
		itemId=226338, 
		waypoint={map=2213, x=0.4682, y=0.2170}, 
		kp=3
		}) -- "Heavy Spider Crusher"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83913}, 
		itemId=226339, 
		waypoint={map=2213, x=0.4797, y=0.4062}, 
		kp=3
		}) -- "Nerubian Mining Cart"
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={81390}, 
		itemId=227416, 
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=15, 
		spell=459909, 
		itemRequirements={{id=210814, quantity=200}} 
		}) -- Lyrendal, 200
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={81391}, 
		itemId=227427,
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=15, 
		spell=459910, 
		itemRequirements={{id=210814, quantity=300}} 
		}) -- Lyrendal, 300
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={81392}, 
		itemId=227438, 
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=15, 
		spell=459911, 
		itemRequirements={{id=210814, quantity=400}} 
		}) -- Lyrendal, 400
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={83062}, 
		itemId=224651, 
		waypoint={map=2214, x=0.4315, y=0.3293}, 
		kp=10, 
		spell=453448, 
		renown={majorFactionId=2594, levelRequired=12}
		}) -- Machine-Learned Mining Notes
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={85742}, 
		itemId=232509, 
		waypoint={map=2346, x=0.4386, y=0.5082}, 
		kp=10, 
		spell=470737, 
		renown={majorFactionId=2653,levelRequired=16}
		}) -- Undermine Treatise on Mining
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={82614}, 
		itemId=224055, 
		waypoint={map=2213, x=0.4680, y=0.2220}, 
		kp=10, 
		spell=450836, 
		currency={id=3056, quantity=565}
		}) -- A Rocky Start
    p:AddEntry(HironCraftProfit_WeeklyQuestItem:New {
		questId={83104, 83105, 83103, 83106, 83102}, 
		itemId=224818,  
		waypoint={map=2339, x=0.5262, y=0.5254}, 
		kp=3, 
		text=L["TQ"], 
		unique=true
		}) -- "Algari Miner's Notes"
    p:AddEntry(HironCraftProfit_Treatise:New {
		questId={83733}, 
		itemId=222553, 
		waypoint={map=2339, x=0.5804, y=0.5645}, 
		kp=1, 
		spell=457726, 
		atlasIcon="Professions-Crafting-Orders-Icon", 
		text=L["IncWO"]
		}) -- Algari Treatise on Mining (Requires skill 25)
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New {
		questId={83050, 83051, 83052, 83053, 83054}, 
		itemId=224583, 
		kp=1, 
		atlasIcon="Professions_Tracking_Ore", 
		text=L["LittleOre"]
		}) -- "Slab of Slate"
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New {
		questId={83049}, 
		itemId=224584, 
		kp=3, 
		atlasIcon="Professions_Tracking_Ore", 
		text=L["BigOre"]
		}) -- "Slab of Slate"
    p:AddEntry(HironCraftProfit_DarkmoonQuest:New{
		questId={29518}, 
		waypoint={map=407, x=0.4930, y=0.6087}, 
		kp=3
		}) -- DMF Rearm, Reuse, Recycle
    p:AddEntry(HironCraftProfit_CatchUp:New{
		questId={}, 
		itemId=224838, 
		catchUpCurrencyId=3065, 
		unlockRequirements={
			questIdIdx[83049], 
			questIdIdx[83050], 
			questIdIdx[83104]
			}, 
		atlasIcon="Professions_Tracking_Ore", 
		kp=1
		}) -- Catch up mechanic
    PT.DB.TWW[2881] = p
end
    -- Skinning
do
	local p = HironCraftProfit_Profession:New(2882, 423342, 3066)
	p.expansion = "TWW"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83914}, 
		itemId=226340, 
		waypoint={map=2339, x=0.2877, y=0.5166}, 
		kp=3
		}) -- "Dornogal Carving Knife" Door at 30.51 56.31
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83915}, 
		itemId=226341, 
		waypoint={map=2248, x=0.6004, y=0.2800}, 
		kp=3
		}) -- "Earthen Worker's Beams"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83916}, 
		itemId=226342, 
		waypoint={map=2214, x=0.4314, y=0.2834}, 
		kp=3
		}) -- "Artisan's Drawing Knife"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83917}, 
		itemId=226343, 
		waypoint={map=2214, x=0.6156, y=0.6190}, 
		kp=3
		}) -- "Fungarian's Rich Tannin"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83918}, 
		itemId=226344, 
		waypoint={map=2215, x=0.4936, y=0.6216}, 
		kp=3
		}) -- "Arathi Tanning Agent"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83919}, 
		itemId=226345, 
		waypoint={map=2215, x=0.4229, y=0.5393},
		kp=3
		}) -- "Arathi Craftsman's Spokeshave"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83920}, 
		itemId=226346, 
		waypoint={map=2213, x=0.4446, y=0.4945}, 
		kp=3
		}) -- "Nerubian's Slicking Iron"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83921}, 
		itemId=226347, 
		waypoint={map=2255, x=0.5654, y=0.5524}, 
		kp=3
		}) -- "Carapace Shiner"
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={84232}, 
		itemId=227417, 
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=15, 
		spell=459912, 
		itemRequirements={{id=210814, quantity=200}} 
		}) -- Lyrendal, 200
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={84233}, 
		itemId=227428, 
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=15, 
		spell=459913, 
		itemRequirements={{id=210814, quantity=300}} 
		}) -- Lyrendal, 300
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={84234}, 
		itemId=227439, 
		waypoint={map=2339, x=0.5983, y=0.5643},
		kp=15, 
		spell=459914, 
		itemRequirements={{id=210814, quantity=400}} 
		}) -- Lyrendal, 400
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={83067}, 
		itemId=224657, 
		waypoint={map=2215, x=0.4120, y=0.5300}, 
		kp=10, 
		spell=453455, 
		renown={majorFactionId=2570, levelRequired=14}
		}) -- Void-Lit Skinning Notes
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={85744}, 
		itemId=232506, 
		waypoint={map=2346, x=0.4386, y=0.5082}, 
		kp=10, 
		spell=470738, 
		renown={majorFactionId=2653, levelRequired=16}
		}) -- Undermine Treatise on Skinning
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={82596}, 
		itemId=224007, 
		waypoint={map=2213, x=0.4309, y=0.2065}, 
		kp=10, 
		spell=450698, currency={id=3056, quantity=565}
		}) -- Uses for Leftover Husks (How to Take Them Apart)
    p:AddEntry(HironCraftProfit_WeeklyQuestItem:New {
		questId={83097, 83098, 83100, 82992, 82993}, 
		itemId=224807,  
		waypoint={map=2339, x=0.5429, y=0.5738}, 
		kp=3, 
		text=L["TQ"], 
		unique=true
		}) -- "Algari Herbalist's Notes"
    p:AddEntry(HironCraftProfit_Treatise:New {
		questId={83734}, 
		itemId=222649, 
		waypoint={map=2339, x=0.5804, y=0.5645}, 
		kp=1, 
		spell=457724, 
		atlasIcon="Professions-Crafting-Orders-Icon", 
		text=L["IncWO"]
		}) -- Algari Treatise on Skinning (Requires skill 25)
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
		questId={81459, 81460, 81461, 81462, 81463}, 
		itemId=224780, 
		kp=1, 
		atlasIcon="worldquest-icon-skinning", 
		text=L["LittleSkin"]
		}) -- "Toughened Tempest Pelt"
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
		questId={81464}, 
		itemId=224781, 
		kp=2, 
		atlasIcon="worldquest-icon-skinning", 
		text=L["BigSkin"]
		}) -- "Toughened Tempest Pelt"
    p:AddEntry(HironCraftProfit_DarkmoonQuest:New{
		questId={29519}, 
		waypoint={map=407, x=0.5501, y=0.7078}, 
		kp=3
		}) -- DMF Tan My Hide
    p:AddEntry(HironCraftProfit_CatchUp:New{
		questId={}, 
		itemId=224782, 
		catchUpCurrencyId=3066,
		unlockRequirements={
			questIdIdx[81464], 
			questIdIdx[81459], 
			questIdIdx[83097]
			}, 
		atlasIcon="worldquest-icon-skinning", 
		kp=1
		}) -- Catch up mechanic
    PT.DB.TWW[2882] = p
end 
    -- Tailoring
do
    local p = HironCraftProfit_Profession:New(2883, 423343, 3067)
    p.expansion = "TWW"	
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83922}, 
		itemId=226348, 
		waypoint={map=2339, x=0.6155, y=0.1852}, 
		kp=3
		}) -- "Dornogal Seam Ripper"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83923}, 
		itemId=226349, 
		waypoint={map=2248, x=0.5621, y=0.6101}, 
		kp=3
		}) -- "Earthen Tape Measure"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83924}, 
		itemId=226350, 
		waypoint={map=2214, x=0.4053, y=0.3287}, 
		kp=3
		}) -- "Runed Earthen Pins" Door at 47.63 32.17
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83925}, 
		itemId=226351, 
		waypoint={map=2214, x=0.5585, y=0.6033}, 
		kp=3
		}) -- "Earthen Stitcher's Snips" Under a tent on top of a table
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83926}, 
		itemId=226352, 
		waypoint={map=2215, x=0.4932, y=0.6231}, 
		kp=3
		}) -- "Arathi Rotary Cutter"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83927}, 
		itemId=226353, 
		waypoint={map=2215, x=0.4009, y=0.6814}, 
		kp=3
		}) -- "Royal Outfitter's Protractor"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83928}, 
		itemId=226354, 
		waypoint={map=2255, x=0.5327, y=0.5312}, 
		kp=3
		}) -- "Nerubian Quilt"
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId={83929}, 
		itemId=226355, 
		waypoint={map=2213, x=0.5032, y=0.1684}, 
		kp=3
		}) -- "Nurubian's Pincushion"
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={80871}, 
		itemId=227410, 
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=10, 
		spell=459915, 
		itemRequirements={{id=210814, quantity=200}}
		}) -- Lyrendal, 200
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={80872}, 
		itemId=227421, 
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=10, 
		spell=459916, 
		itemRequirements={{id=210814, quantity=300}} 
		}) -- Lyrendal, 300
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={80873}, 
		itemId=227432, 
		waypoint={map=2339, x=0.5983, y=0.5643}, 
		kp=10, 
		spell=459917, 
		itemRequirements={{id=210814, quantity=400}} 
		}) -- Lyrendal, 400
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={83061}, 
		itemId=224648, 
		waypoint={map=2339, x=0.3983, y=0.2420}, 
		kp=10, 
		spell=453447, 
		renown={majorFactionId=2590, levelRequired=12}
		}) -- Jewel-Etched Tailoring Notes
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={85745}, 
		itemId=232502, 
		waypoint={map=2346, x=0.4386, y=0.5082}, 
		kp=10, 
		spell=470739, 
		renown={majorFactionId=2653, levelRequired=16}
		}) -- Undermine Treatise on Tailoring
    p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId={82634}, 
		itemId=224036, 
		waypoint={map=2213, x=0.5063, y=0.1680}, 
		kp=10, 
		spell=450840, 
		currency={id=3056, quantity=565}
		}) -- And That's A Web-Wrap!
    p:AddEntry(HironCraftProfit_Treatise:New {
		questId={83735}, 
		itemId=222547, 
		waypoint={map=2339, x=0.5804, y=0.5645}, 
		kp=1, 
		spell=457719, 
		atlasIcon="Professions-Crafting-Orders-Icon", 
		text=L["IncWO"]
		}) -- Algari Treatise on Tailoring (Requires skill 25)
    p:AddEntry(HironCraftProfit_WeeklyQuestItem:New {
		questId={84132}, 
		itemId=228779, 
		waypoint={map=2339, x=0.5971, y=0.5627}, 
		kp=2, 
		text=L["CraftOQ"]
		}) -- Algari Tailor's Notebook
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
		questId={83269}, 
		itemId=225221, 
		kp=1,
		text= L["Found on treasures"]
		}) -- "Spool of Webweave"
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
		questId={83270}, 
		itemId=225220, 
		kp=1,
		text= L["Found on treasures"]
		}) -- "Machine Speaker's" 
    p:AddEntry(HironCraftProfit_DarkmoonQuest:New {
		questId={29520}, 
		waypoint={map=407, x=0.5555, y=0.5500}, 
		itemRequirements={
			{id=2320, quantity=1}, 
			{id=2604, quantity=1}, 
			{id=6260, quantity=1}
			
			}, 
		kp=3
		}) -- Banners, Banners Everywhere!
    p:AddEntry(HironCraftProfit_CatchUp:New{
		questId={}, 
		itemId=228738, 
		atlasIcon="Professions-Crafting-Orders-Icon", 
		unlockRequirements={
			questIdIdx[83269], 
			questIdIdx[83270], 
			questIdIdx[84132]
			}, 
			kp=1, 
			text=PROFESSIONS_CRAFTING_ORDERS_PAGE_NAME:format(PROFESSIONS_CRAFTER_ORDER_TAB_NPC)
		}) -- Catch up mechanic
    PT.DB.TWW[2883] = p
end
