local PT = HironCraftProfit
local L = PT.L

PT.DB = PT.DB or {}
PT.DB.MID = PT.DB.MID or {}

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

local DEMYSTIFYING_OK = select(4, GetBuildInfo()) >= 120100

-- Midnight Herbalism (16)
do
    local p = HironCraftProfit_Profession:New(2912, 471022, 3196)
	p.expansion = "MID"
    p.isMID = true
    --Unique Books 
	p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId = {93411},
		itemId = 258410,
		kp = 10,
        renown = { majorFactionId = 2704, levelRequired = 6 },
		currency = {
            { id = 3260, quantity = 75 },
            { id = 3316, quantity = 750 },
        },
        waypoint = { map = 2413, x = 0.510, y = 0.508 },
    }) -- Traditions of the Haranir: Herbalism

    p:AddEntry(HironCraftProfit_UniqueBook:New{
        questId = {92174},
        itemId = 250443,
        kp = 10,
        waypoint = { map = 2395, x = 0.566, y = 0.658 },
        currency = {
            { id = 3260, quantity = 75 },
            { id = 3377, quantity = 1600 },
        },
    }) -- Echo of Abundance: Herbalism

    -- Weekly Treasures
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
        questId = {81425, 81426, 81427, 81428, 81429},
        itemId = 238465,
        kp = 1,
		atlasIcon="Professions_Tracking_Herb", 
		text=L["LittleHerb"]
    }) -- Thalassian Phoenix Plume
	
    p:AddEntry(HironCraftProfit_DarkmoonQuest:New{
		questId={29514}, 
		waypoint={map=407, x=0.5500, y=0.7076}, 
		kp=3
	}) -- DMF Herbs for Healing
    
	p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
		questId = {81430},
		itemId = 238466,
		kp = 4,
		atlasIcon = "Professions_Tracking_Herb", 
		text = L["BigHerb"],
		requiresQuestId = {81429}, --81425, 81426, 81427, 81428, 
	})
    -- Unique Treasures
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89162},
        itemId = 238468,
        kp = 3,
		waypoint = { map = 2413, x = 0.3832, y = 0.6703 }
    }) -- Bloomed Bud

    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89161},
        itemId = 238469,
        kp = 3,
        waypoint = { map = 2437, x = 0.4191, y = 0.4593 }
    }) -- Sweeping Harvester's Scythe

    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89160},
        itemId = 238470,
        kp = 3,
        waypoint = { map = 2393, x = 0.490, y = 0.758 },
    }) -- Simple Leaf Pruners

    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89159},
        itemId = 238471,
        kp = 3,
        waypoint = { map = 2413, x = 0.366, y = 0.250 },
    }) -- Lightbloom Root

    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89158},
        itemId = 238472,
        kp = 3,
		waypoint = { map = 2395, x = 0.6425, y = 0.3046 }
    }) -- A Spade

    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89157},
        itemId = 238473,
        kp = 3,
        waypoint = { map = 2413, x = 0.7603, y = 0.511 },
    }) -- Harvester's Sickle

    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89156},
        itemId = 238474,
        kp = 3,
		waypoint = { map = 2405, x = 0.347, y = 0.57 },
    }) -- Peculiar Lotus

    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89155},
        itemId = 238475,
        kp = 3,
        waypoint = { map = 2413, x = 0.511, y = 0.557 },
    }) -- Planting Shovel

    -- Treatise
    p:AddEntry(HironCraftProfit_Treatise:New{
        questId = {95130},
        itemId = 245761,
        kp = 1,
		atlasIcon="Professions-Crafting-Orders-Icon", 
		text=L["IncWO"]
    }) -- Thalassian Treatise on Herbalism

    -- Weekly Quest Item
    p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
        questId = {93700, 93701, 93703, 93704, 93702},
        itemId = 263462,
        kp = 3,
		waypoint={map=2393, x=0.4828, y=0.5144}, 
		text=L["TQ"],
        unique = true,
    }) -- Thalassian Herbalist's Notes
	 
	-- Catch up mechanic
	    p:AddEntry(HironCraftProfit_CatchUp:New{
		questId={}, 
		itemId=238467, -- Thalassian Phoenix Ember
		catchUpCurrencyId=3196, 
		unlockRequirements={
			questIdIdx[81425], 
			questIdIdx[81430], 
			questIdIdx[93700]
		}, 
		atlasIcon="Professions_Tracking_Herb", 
		kp=1
	}) 
if DEMYSTIFYING_OK then p:AddEntry(HironCraftProfit_UniqueBook:New{
        questId = {96514},
        itemId = 274513,--Demystifying: Herbalism
        kp = 10,
        renown = { majorFactionId = 2772, levelRequired = 6 },
        currency = {
            { id = 3260, quantity = 75 },
            { id = 3316, quantity = 750 },
        },
        waypoint = { map = 2512, x = 0.588, y = 0.46 }
    }) end
    PT.DB.MID[2912] = p
end
-- Midnight Mining 15
do
    local p = HironCraftProfit_Profession:New(2916, 471013, 3192)
    p.expansion = "MID"
    p.isMID = true
    --Unique Books
	p:AddEntry(HironCraftProfit_UniqueBook:New{
        questId = {92187},
        itemId = 250444,
        kp = 10,
        waypoint = { map = 2395, x = 0.566, y = 0.658 },
        currency = {
            { id = 3264, quantity = 75 },
            { id = 3377, quantity = 1600 },
        },
    }) -- Echo of Abundance: Mining
    p:AddEntry(HironCraftProfit_UniqueBook:New{
        questId = {92372},
        itemId = 250924,
        kp = 10,
        renown = { majorFactionId = 2696, levelRequired = 6 },
        currency = {
            { id = 3264, quantity = 75 },
            { id = 3316, quantity = 750 },
        },
        waypoint = { map = 2437, x = 0.459, y = 0.659 }
    }) -- Whisper of the Loa: Mining
    -- Weekly Treasures
	    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
        questId = {88673, 88674, 88675, 88676, 88677},
        itemId = 237496,
        kp = 1,
		atlasIcon="Professions_Tracking_Ore", 
		text=L["LittleOre"]
    }) -- Igneous Rock Specimen
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
        questId = {88678},
        itemId = 237506,
        kp = 3,
        atlasIcon = "Professions_Tracking_Ore",
        text = L["BigOre"],
		requiresQuestId = {88677} --88673, 88674, 88675, 88676, 
    }) -- Septarian Nodule
    -- Unique Treasures
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89144},
        itemId = 238596,
        kp = 3,
		waypoint = { map = 2444, x = 0.305, y = 0.690 },
		extraWaypoints = {
			{map = 2405, x = 0.4121, y = 0.3462},
		},
    }) -- Miner's Guide to Voidstorm
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89145},
        itemId = 238597,
        kp = 3,
		waypoint = { map = 2437, x = 0.420, y = 0.465 }
    }) -- Spelunker's Lucky Charm
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89146},
        itemId = 238598,
        kp = 3,
		waypoint = { map = 2444, x = 0.5424, y = 0.5154 },
		extraWaypoints = {
			{map = 2405, x = 0.5185, y = 0.2701},
		},
		text = L["238598"]
    }) -- Lost Voidstorm Satchel
	p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89147},
        itemId = 238599,
        kp = 3,
        waypoint = { map = 2395, x = 0.380, y = 0.453 },
    }) -- Solid Ore Punchers 
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89148},
        itemId = 238600,
        kp = 3,
		waypoint = { map = 2444, x = 0.2877, y = 0.3859 },
		extraWaypoints = {
			{map = 2405, x = 0.4049, y = 0.2089},
		},
    }) -- Glimmering Void Pearl
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89149},
        itemId = 238601,
        kp = 3,
		waypoint = { map = 2536, x = 0.336, y = 0.660 },
		extraWaypoints = {
			{map = 2437, x = 0.3040, y = 0.5753},
		},
		text = L["storyL"]
    }) -- Amani Expert's Chisel
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89150},
        itemId = 238602,
        kp = 3,
		waypoint = { map = 2405, x = 0.418, y = 0.382 }
    }) -- Star Metal Deposit
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89151},
        itemId = 238603,
        kp = 3,
		waypoint = { map = 2413, x = 0.387, y = 0.6606 }
    }) -- Spare Expedition Torch
    
    p:AddEntry(HironCraftProfit_DarkmoonQuest:New{
		questId={29518}, 
		waypoint={map=407, x=0.4930, y=0.6087}, 
		kp=3
	}) -- DMF Rearm, Reuse, Recycle
  
    -- Treatise
    p:AddEntry(HironCraftProfit_Treatise:New{
        questId = {95135},
        itemId = 245762,
        kp = 1,
        atlasIcon = "Professions-Crafting-Orders-Icon",
        text = L["IncWO"]
    }) -- Thalassian Treatise on Mining
    -- Weekly Quest Item
    p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
        questId = {93705, 93706, 93707, 93708, 93709},
        itemId = 263463,
        kp = 3,
        waypoint = {map = 2393, x = 0.4259, y = 0.5285},
        text = L["TQ"],
        unique = true,
    }) -- Thalassian Miner's Notes
	
	-- Catch up mechanic    
	p:AddEntry(HironCraftProfit_CatchUp:New
		{questId={}, 
		itemId=237507, --Cloudy Quartz
		catchUpCurrencyId=3192, 
		unlockRequirements={
			questIdIdx[88678], 
			questIdIdx[88673], 
			questIdIdx[93707]}, 
		atlasIcon="Professions_Tracking_Ore", 
		kp=1
	}) 
    if DEMYSTIFYING_OK then p:AddEntry(HironCraftProfit_UniqueBook:New{
        questId = {96518},
        itemId = 274509,--Demystifying: Mining
        kp = 10,
        renown = { majorFactionId = 2772, levelRequired = 6 },
        currency = {
            { id = 3264, quantity = 75 },
            { id = 3316, quantity = 750 },
        },
        waypoint = { map = 2512, x = 0.588, y = 0.46 }
    }) end
    PT.DB.MID[2916] = p
end
-- Midnight Skinning
do
    local p = HironCraftProfit_Profession:New(2917, 471014, 3191)
    p.expansion = "MID"
    p.isMID = true
    -- Unique Books
    p:AddEntry(HironCraftProfit_UniqueBook:New{
        questId = {92188},
        itemId = 250360, -- Echo of Abundance: Skinning
        kp = 10,
        waypoint = { map = 2395, x = 0.566, y = 0.658 },
        currency = {
            { id = 3265, quantity = 75 },
            { id = 3377, quantity = 1600 },
        }
	})
	p:AddEntry(HironCraftProfit_UniqueBook:New{
        questId = {92373},
        itemId = 250923,
        kp = 10,
        renown = { majorFactionId = 2696, levelRequired = 6 },
        currency = {
            { id = 3265, quantity = 75 },
            { id = 3316, quantity = 750 },
        },
        waypoint = { map = 2437, x = 0.459, y = 0.659 }
    }) -- Whisper of the Loa: Skinning	

    -- Weekly Treasures
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
        questId = {88534, 88549, 88537, 88536, 88530},
        itemId = 238625, -- Fine Void-Tempered Hide
        kp = 1,
		atlasIcon="worldquest-icon-skinning", 
		text=L["LittleSkin"]
    })
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
        questId = {88529},
        itemId = 238626, -- Mana-Infused Bone
        kp = 3,
		atlasIcon="worldquest-icon-skinning", 
		text=L["BigSkin"],
		requiresQuestId = {88530}--88534, 88549, 88537, 88536,
    })
    -- Unique Treasures
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89166},
        itemId = 238628, -- Lightbloom Afflicted Hide
        kp = 3,
		waypoint = {map = 2413, x = 0.7609, y = 0.5110},
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89167},
        itemId = 238629, -- Cadre Skinning Knife
        kp = 3,
		waypoint = {map = 2536, x = 0.4491, y = 0.4515},
		extraWaypoints = {
			{map = 2437, x = 0.3289, y = 0.5463},
		},
        text = L["storyL"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89168},
        itemId = 238630, -- Primal Hide
        kp = 3,
		waypoint = {map = 2413, x = 0.6952, y = 0.4918},
		text = L["238630"]	
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89169},
        itemId = 238631, -- Voidstorm Leather Sample
        kp = 3,
		waypoint = {map = 2444, x = 0.4550, y = 0.4240},
		extraWaypoints = {
			{map = 2405, x = 0.4794, y = 0.2279},
		},
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89170},
        itemId = 238632, -- Amani Tanning Oil
        kp = 3,
		waypoint = {map = 2437, x = 0.4039, y = 0.3601},
    })
	p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89171},
        itemId = 238633, -- Sin'dorei Tanning Oil
        kp = 3,
		waypoint = {map = 2393, x = 0.4315, y = 0.556},
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89172},
        itemId = 238634, -- Amani Skinning Knife
        kp = 3,
		waypoint = {map = 2437, x = 0.3308, y = 0.7907},
		text = L["InCave"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89173},
        itemId = 238635, -- Thalassian Skinning Knife
        kp = 3,
		waypoint = {map = 2395, x = 0.4840, y = 0.7626},
    })
    -- Treatise
    p:AddEntry(HironCraftProfit_Treatise:New{
        questId = {95136},
        itemId = 245828, -- Thalassian Treatise on Skinning
        kp = 1,
        atlasIcon = "Professions-Crafting-Orders-Icon",
        text = L["IncWO"]
    })
    -- Weekly Quest Item
    p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
	    questId = {93714, 93713, 93712, 93711, 93710},
        itemId = 263461, -- Thalassian Skinner's Notes
        kp = 3,
        waypoint = {map = 2393, x = 0.432, y = 0.556},
        text = L["TQ"],
        unique = true,
    })
    p:AddEntry(HironCraftProfit_DarkmoonQuest:New{
		questId={29519}, 
		waypoint={map=407, x=0.5501, y=0.7078}, 
		kp=3
	}) -- DMF Tan My Hide
	
   	-- Catch up mechanic
    p:AddEntry(HironCraftProfit_CatchUp:New{
		questId={}, 
		itemId=238627, 
		catchUpCurrencyId=3191, 
		unlockRequirements={
			questIdIdx[88529], 
			questIdIdx[88534], 
			questIdIdx[93714]}, 
		atlasIcon="worldquest-icon-skinning", 
		kp=1
	})
   if DEMYSTIFYING_OK then p:AddEntry(HironCraftProfit_UniqueBook:New{
        questId = {96519},
        itemId = 274508,--Demystifying: Skinning
        kp = 10,
        renown = { majorFactionId = 2772, levelRequired = 6 },
        currency = {
            { id = 3265, quantity = 75 },
            { id = 3316, quantity = 750 },
        },
        waypoint = { map = 2512, x = 0.588, y = 0.46 }
    }) end
   PT.DB.MID[2917] = p
end
-- Midnight Alchemy
do
    local p = HironCraftProfit_Profession:New(2906, 471003, 3189)
    p.expansion = "MID"
    p.isMID = true
    -- Unique Books
    p:AddEntry(HironCraftProfit_UniqueBook:New{
        questId = {93794},
        itemId = 262645,
        kp = 10,
        kp = 10,
        renown = { majorFactionId = 2699, levelRequired = 9 },
        currency = {
            { id = 3256, quantity = 75 },
            { id = 3316, quantity = 750 },
        },
        waypoint = { map = 2405, x = 0.5258, y = 0.729 }
    })

    --Weekly Treasures
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
        questId = {93528},
        itemId = 259188, -- Lightbloomed Spore Sample
        kp = 1,
		atlasIcon="VignetteLoot", -- Assumed icon
		text=L["Found on treasures MN"]
    })
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
        questId = {93529},
        itemId = 259189, -- Aged Cruor
        kp = 1,
		atlasIcon="VignetteLoot", 
		text=L["Found on treasures MN"],
    })
    -- Unique Treasures
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89111}, 
        itemId = 238532, --Vial of Eversong Oddities
        kp = 3,
		waypoint = {map = 2393, x = 0.4511, y = 0.4478},
        text = L["238532"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89112},
        itemId = 238533, -- Vial of Voidstorm Oddities
        kp = 3,
		waypoint = {map = 2444, x = 0.4196, y = 0.4062},
		extraWaypoints = {
			{map = 2405, x = 0.4645, y = 0.2213},
		},
        --text = ""
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89113},
        itemId = 238534, -- Vial of Rootlands Oddities
        kp = 3,
		waypoint = {map = 2413, x = 0.3477, y = 0.247},
        -- text = ""
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89114},
        itemId = 238535, -- Vial of Zul'Aman Oddities
        kp = 3,
		waypoint = {map = 2437, x = 0.4039, y = 0.5117},
        -- text = ""
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89115},
        itemId = 238536, -- Freshly Plucked Peacebloom
        kp = 3,
		waypoint = {map = 2393, x = 0.4911, y = 0.7583},
        -- text = ""
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89116},
        itemId = 238537, -- Measured Ladle
        kp = 3,
		waypoint = {map = 2536, x = 0.491, y = 0.2321},
		extraWaypoints = {
			{map = 2437, x = 0.3310, y = 0.5033},
		},
        text = L["storyL"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89117},
        itemId = 238538, --Pristine Potion
        kp = 3,
		waypoint = {map = 2393, x = 0.4776, y = 0.5168},
        text = L["238538"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89118},
        itemId = 238539, -- Failed Experiment
        kp = 3,
		waypoint = {map = 2405, x = 0.3279, y = 0.4329},
        -- text = ""
    })
    -- Treatise
    p:AddEntry(HironCraftProfit_Treatise:New{
        questId = {95127},
        itemId = 245755, -- Thalassian Treatise on Alchemy
        kp = 1,
        atlasIcon = "Professions-Crafting-Orders-Icon",
        text = L["IncWO"]
    })
    -- Weekly Quest Item
    p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
	    questId = {93690},
        itemId = 263454, -- Thalassian Alchemist's Notebook
        kp = 1,
        waypoint = {map = 2393, x = 0.4704, y = 0.5197},
        text = L["TQ"],
        unique = true,
    })
    p:AddEntry(HironCraftProfit_DarkmoonQuest:New{
		questId={29506}, 
		waypoint={map=407, x=0.5049, y=0.6955}, 
		itemRequirements={{id=1645, quantity=5}}, 
		kp=3
	}) -- DMF A Fizzy Fusion
	
   	-- Catch up mechanic 
    p:AddEntry(HironCraftProfit_CatchUp:New{
		questId={}, 
		itemId=246320, -- Flicker of Midnight Alchemy Knowledge
		catchUpCurrencyId=3189, 
		-- unlockRequirements={
			-- questIdIdx[93528], 
			-- questIdIdx[93529], 
			-- questIdIdx[93690]}, 
		atlasIcon="worldquest-icon-alchemy", 
		kp=1
	})
   if DEMYSTIFYING_OK then p:AddEntry(HironCraftProfit_UniqueBook:New{
        questId = {96459},
        itemId = 274500,--Demystifying: Alchemy
        kp = 10,
        renown = { majorFactionId = 2772, levelRequired = 6 },
        currency = {
            { id = 3256, quantity = 75 },
            { id = 3316, quantity = 750 },
        },
        waypoint = { map = 2512, x = 0.588, y = 0.46 }
    }) end
   PT.DB.MID[2906] = p
end
-- Midnight Blacksmithing
do
    local p = HironCraftProfit_Profession:New(2907, 471004, 3199)
    p.expansion = "MID"
    p.isMID = true

    -- Unique Books
    p:AddEntry(HironCraftProfit_UniqueBook:New{
        questId = {93795},
        itemId = 262644, --Beyond the Event Horizon: Blacksmithing
        kp = 10,
        renown = { majorFactionId = 2699, levelRequired = 9 },
        currency = {
            { id = 3257, quantity = 75 },
            { id = 3316, quantity = 750 },
        },
        waypoint = { map = 2405, x = 0.5258, y = 0.729 }
    })

    --Weekly Treasures
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
        questId = {93531},
        itemId = 259191, --Infused Quenching Oil
        kp = 2,
        atlasIcon = "VignetteLoot",
        text = L["Found on treasures MN"]
    })
	
	    -- Weekly Treasures
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
        questId = {93530},
        itemId = 259190, --Thalassian Whestone
        kp = 2,
        atlasIcon = "VignetteLoot",
        text = L["Found on treasures MN"]
    })

    -- Unique Treasures
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89177},
        itemId = 238540, -- Deconstructed Forge Techniques
        kp = 3,
        waypoint = {map = 2393, x=0.2697, y=0.603},
        -- text = ""
    })
    -- Unique Treasures
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89178},
        itemId = 238541, -- Silvermoon Smithing Kit
        kp = 3,
        waypoint = {map=2395, x=0.4832, y=0.7578},
        -- text = ""
    })
    -- Unique Treasures
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89179},
        itemId = 238542, --Carefully Racked Spear
        kp = 3,
        waypoint = {map=2536 ,x=0.3308, y=0.6582},
		extraWaypoints = {
			{map = 2437, x = 0.3035, y = 0.5744},
		},
        text = L["storyL"]
    })
    -- Unique Treasures
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89180},
        itemId = 238543, -- Metalworking Cheat Sheet
        kp = 3,
        waypoint = {map=2395, x=0.5684, y=0.4077}, 
        -- text = ""
    })
    -- Unique Treasures
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89181},
        itemId = 238544, -- Voidstorm Defense Spear
        kp = 3,
        waypoint = {map=2444, x=0.3051, y=0.6899},
		extraWaypoints = {
			{map = 2405, x = 0.4126, y = 0.3445},
		},
        text = L["238544"]
    })
    -- Unique Treasures
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89182},
        itemId = 238545, -- Rutaani Floratender's Sword
        kp = 3,
        waypoint = {map = 2413, x=0.6634, y=0.5085},
        text = L["238545"]
    })
    -- Unique Treasures
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89183},
        itemId = 238546, -- Sin'dorei Master's Forgemace
        kp = 3,
        waypoint = {map=2393, x=0.4918, y=0.6134},
        text = L["238546"] 
    })
    -- Unique Treasures
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89184},
        itemId = 238547, -- Silvermoon Blacksmith's Hammer
        kp = 3,
        waypoint = {map=2393, x=0.485, y=0.7471},
        --text = ""
    })

    --Treatise
    p:AddEntry(HironCraftProfit_Treatise:New{
        questId = {95128},
        itemId = 245763, --Thalassian Treatise on Blacksmithing
        kp = 1,
        atlasIcon = "Professions-Crafting-Orders-Icon",
        text = L["IncWO"]
    })

    --Weekly Quest Item
    p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
        questId = {93691},--
        itemId = 263455,
        kp = 2,
        waypoint = {map=2393, x=0.436, y=0.516},
        text = L["TQ"],
        unique = true,
    })

    -- Darkmoon
    p:AddEntry(HironCraftProfit_DarkmoonQuest:New{
		questId={29508}, 
		waypoint={map=407, x=0.5110, y=0.8204},
		kp=3
	}) -- DMF Baby Needs Two Pair of Shoes

    -- Catch Up
    p:AddEntry(HironCraftProfit_CatchUp:New{
        questId = {},
        itemId = 246322, --Flicker of Midnight Blacksmithing Knowledge
        catchUpCurrencyId = 3199,
        --unlockRequirements = {
				-- questIdIdx[93531],
				-- questIdIdx[93530],
				-- questIdIdx[93726]},
        atlasIcon = "worldquest-icon-blacksmithing",
        kp = 1,
    })

    if DEMYSTIFYING_OK then p:AddEntry(HironCraftProfit_UniqueBook:New{
        questId = {96511},
        itemId = 274515,--Demystifying: Blacksmithing
        kp = 10,
        renown = { majorFactionId = 2772, levelRequired = 6 },
        currency = {
            { id = 3257, quantity = 75 },
            { id = 3316, quantity = 750 },
        },
        waypoint = { map = 2512, x = 0.588, y = 0.46 }
    }) end
    PT.DB.MID[2907] = p
end
-- Midnight Enchanting
do
    local p = HironCraftProfit_Profession:New(2909, 471006, 3198)
    p.expansion = "MID"
    p.isMID = true
	 
    -- Unique Books
    p:AddEntry(HironCraftProfit_UniqueBook:New{
        questId = {92186},
        itemId = 250445, -- Echo of Abundance: Enchanting
        kp = 10,
        waypoint = { map = 2437, x = 0.3156, y = 0.2626 },
        currency = {
            { id = 3258, quantity = 75 },
            { id = 3377, quantity = 1600 },
        },
    }) 
	    p:AddEntry(HironCraftProfit_UniqueBook:New{
        questId = {92374},
        itemId = 257600, --Skill Issue: Enchanting
        kp = 10,
        renown = { majorFactionId = 2710, levelRequired = 6 },
        currency = {
            { id = 3258, quantity = 75 },
            { id = 3316, quantity = 750 },
        },
        waypoint = { map = 2395, x = 0.434, y = 0.474 }
    })
	    -- Weekly Treasures
	    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
        questId = {95048, 95049, 95050, 95051, 95052},
        itemId = 267654,
        kp = 1,
		atlasIcon="lootroll-toast-icon-disenchant-up", 
		text=L["LittleDis"]
    }) -- Swirling Arcane Essence
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
        questId = {95053},
        itemId = 267655,
        kp = 4,
        atlasIcon = "lootroll-toast-icon-disenchant-up",
        text = L["BigDis"],
		requiresQuestId = {95052}
    }) -- 
    -- Weekly Treasures
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
        questId = {93532},
        itemId = 259192, --Voidstorm Ashes
        kp = 2,
        atlasIcon = "VignetteLoot",
        text=L["Found on treasures MN"]
    })	
	p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
        questId = {93533},
        itemId = 259193, --Lost Thalassian Vellum
        kp = 2,
        atlasIcon = "VignetteLoot",
        text=L["Found on treasures MN"]
    })

    --Unique Treasures
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89100},
        itemId = 238548,--Enchanted Amani Mask
        kp = 3,
        waypoint = {map=2536, x=0.488, y=0.225},
		extraWaypoints = {
			{map = 2437, x = 0.3311, y = 0.5050},
		},
        --text = ""
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89101},
        itemId = 238549,--Enchanted Sunfire Silk
        kp = 3,
        waypoint = {map=2395, x=0.4020, y =0.6121},
        text = L["89101"]
     })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89102},
        itemId = 238550, --Pure Void Crystal
        kp = 3,
        waypoint = {map=2405, x=0.355, y=0.588},
        --text = ""
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89103},
        itemId = 238551,--Everblazing Sunmote
        kp = 3,
        waypoint = {map=2395, x=0.608, y=0.530},
        --text = ""
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89104},
        itemId = 238552,--Entropic Shard
        kp = 3,
        waypoint = {map=2413, x=0.377, y =0.652},
        --text = ""
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89105},
        itemId = 238553,--Primal Essence Orb
        kp = 3,
        waypoint = {map=2413,x=0.657, y =0.502},
        text = L["238553"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89106},
        itemId = 238554,--Loa-Blessed Dust
        kp = 3,
        waypoint = {map=2437, x=0.404, y=0.5118},
        --text = ""
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89107},
        itemId = 238555,--Sin'dorei Enchanting Rod
        kp = 3,
        waypoint = {map=2395, x=0.635, y=0.326},
        --text = ""
    })

    -- Treatise
    p:AddEntry(HironCraftProfit_Treatise:New{
        questId = {95129},
        itemId = 245759, --Thalassian Treatise on Enchanting
        kp = 1,
        atlasIcon = "Professions-Crafting-Orders-Icon",
        -- text = ""
    })

    -- Weekly Quest Item
    p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
        questId = {93699, 93698, 93697},
        itemId = 263464,
        kp = 3,
        waypoint = {map=2393, x=0.4803, y=0.5386},
        text = L["TQ"],
        unique = true,
    })

    -- Darkmoon
    p:AddEntry(HironCraftProfit_DarkmoonQuest:New{
		questId={29510}, 
		waypoint={map=407, x=0.5316, y=0.7587}, 
		kp=3
	}) -- DMF Putting Trash to Good Use
 
    -- Catch Up
    p:AddEntry(HironCraftProfit_CatchUp:New{
        questId = {},
        itemId = 267653, -- Glimmering Powder
        catchUpCurrencyId = 3198,
		unlockRequirements={
			questIdIdx[93532], 
			questIdIdx[93533], 
			questIdIdx[95048],
			questIdIdx[95053], 
			questIdIdx[93697],
		}, 
        atlasIcon = "worldquest-icon-enchanting",
        kp = 1,
    })

    if DEMYSTIFYING_OK then p:AddEntry(HironCraftProfit_UniqueBook:New{
        questId = {96512},
        itemId = 274511,--Demystifying: Enchanting
        kp = 10,
        renown = { majorFactionId = 2772, levelRequired = 6 },
        currency = {
            { id = 3258, quantity = 75 },
            { id = 3316, quantity = 750 },
        },
        waypoint = { map = 2512, x = 0.588, y = 0.46 }
    }) end
    PT.DB.MID[2909] = p
end
-- Midnight Engineering
do
    local p = HironCraftProfit_Profession:New(2910, 471007, 3197)
    p.expansion = "MID"
    p.isMID = true

    -- Unique Books
    p:AddEntry(HironCraftProfit_UniqueBook:New{
        questId = {93796},
        itemId = 262646, --Beyond the Event Horizon: Engineering
        kp = 10,
        renown = { majorFactionId = 2699, levelRequired = 9 },
        currency = {
            { id = 3259, quantity = 75 },
            { id = 3316, quantity = 750 },
        },
        waypoint = { map = 2405, x = 0.5258, y = 0.729 }
    })

    -- Weekly Treasures
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
        questId = {93534},
        itemId = 259194,--Dance Gear
        kp = 1,
        atlasIcon = "VignetteLoot",
        text=L["Found on treasures MN"]
    })
	    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
        questId = {93535},
        itemId = 259195,--Dawn Capacitor
        kp = 1,
        atlasIcon = "VignetteLoot",
        text=L["Found on treasures MN"]
    })

    -- Unique Treasures
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89133},
        itemId = 238556, --One Engineer's Junk
        kp = 3,
        waypoint = {map=2393, x=0.5134, y=0.7442},
        text = L["238556"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89134},
        itemId = 238557,--Miniaturized Transport Skiff
        kp = 3,
        waypoint = {map=2444, x=0.2893, y=0.3898},
		extraWaypoints = {
			{map = 2405, x = 0.4078, y = 0.2147},
		},
        text = L["238557"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89135},
        itemId = 238558,--Manual of Mistakes and Mishaps
        kp = 3,
        waypoint = {map=2395, x=0.3958, y=0.4579},
        text = L["238558"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89136},
        itemId = 238559,--Expeditious Pylon
        kp = 3,
        waypoint = {map=2413, x=0.68, y=0.4979},
        text = L["238559"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89137},
        itemId = 238560,--Ethereal Stormwrench
        kp = 3,
        waypoint = {map=2444, x=0.5412, y=0.5101},
		extraWaypoints = {
			{map = 2405, x = 0.5202, y = 0.2693},
		},
        text = L["InsBuilding"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89138},
        itemId = 238561,--Offline Helper Bot
        kp = 3,
        waypoint = {map=2536, x=0.6514, y=0.3478},
		extraWaypoints = {
			{map = 2437, x = 0.3587, y = 0.5232},
		},
        text = L["storyL"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89139},--
        itemId = 238562,--What To Do When Nothing Works
        kp = 3,
        waypoint = {map=2393, x=0.5121, y=0.5725},
        text = L["238562"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89140},
        itemId = 238563,--Handy Wrenchw
        kp = 3,
        waypoint = {map=2437, x=0.3419, y=0.878},
        text = L["238563"]
    })

    --Treatise
    p:AddEntry(HironCraftProfit_Treatise:New{
        questId = {95138},
        itemId = 245809, --Thalassian Treatise on Engineering
        kp = 1,
        atlasIcon = "Professions-Crafting-Orders-Icon",
        text = L["IncWO"]
    })

    -- Weekly Quest Item
    p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
        questId = {93692},
        itemId = 263456,
        kp = 1,
        -- waypoint = {},
        text = L["TQ"],
        unique = true,
    })

    -- Darkmoon
    p:AddEntry(HironCraftProfit_DarkmoonQuest:New{
		questId={29511}, 
		waypoint={map=407, x=0.4925, y=0.6078}, 
		kp=3
	}) -- DMF Talkin' Tonks

    -- Catch Up
    p:AddEntry(HironCraftProfit_CatchUp:New{
        questId = {},
        itemId = 246326,--Flicker of Midnight Engineering Knowledge
        catchUpCurrencyId = 3197,
        --unlockRequirements = {},
        atlasIcon = "worldquest-icon-engineering",
        kp = 1,
    })

    if DEMYSTIFYING_OK then p:AddEntry(HironCraftProfit_UniqueBook:New{
        questId = {96513},
        itemId = 274516,--Demystifying: Engineering
        kp = 10,
        renown = { majorFactionId = 2772, levelRequired = 6 },
        currency = {
            { id = 3259, quantity = 75 },
            { id = 3316, quantity = 750 },
        },
        waypoint = { map = 2512, x = 0.588, y = 0.46 }
    }) end
    PT.DB.MID[2910] = p
end
-- Midnight Inscription
do
    local p = HironCraftProfit_Profession:New(2913, 471010, 3195)
    p.expansion = "MID"
    p.isMID = true

    -- Unique Books
    p:AddEntry(HironCraftProfit_UniqueBook:New{
        questId = {93412},
        itemId = 258411,--Traditions of the Haranir: Inscription
        kp = 10,
        renown = { majorFactionId = 2704, levelRequired = 6 },
        currency = {
            { id = 3261, quantity = 75 },
            { id = 3316, quantity = 750 },
        },
        waypoint = { map = 2413, x = 0.51, y = 0.508 }
    })

    -- Weekly Treasures
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
        questId = {93536},
        itemId = 259196,--Brilliant Phoenix Ink
        kp = 2,
        atlasIcon = "VignetteLoot",
        text=L["Found on treasures MN"]
    })
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
        questId = {93537},
        itemId = 259197,--Loa-Blessed Rune
        kp = 2,
        atlasIcon = "VignetteLoot",
        text=L["Found on treasures MN"]
    })

    -- Unique Treasures
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89067},
        itemId = 238572,--Void-Touched Quill
        kp = 3,
        waypoint = {map=2444, x=0.6069, y=0.8426},
		extraWaypoints = {
			{map = 2405, x = 0.5484, y = 0.4165},
		},
        text = L["238572"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89068},
        itemId = 238573,--Leather-Bound Techniques
        kp = 3,
        waypoint = {map=2437, x=0.405, y=0.494},
        text = L["InCave"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89069},
        itemId = 238574,--Spare Ink
        kp = 3,
        waypoint = {map=2395, x=0.483, y=0.755},
        -- text = ""
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89070},
        itemId = 238575,--Intrepid Explorer's Marker
        kp = 3,
        waypoint = {map=2413, x=0.524, y=0.526},
        text = L["238575"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89071},
        itemId = 238576,--Leftover Sanguithorn Pigment
        kp = 3,
        waypoint = {map=2413, x=0.527, y=0.5},
        text = L["238576"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89072},
        itemId = 238577,--Half-Baked Techniques
        kp = 3,
        waypoint = {map=2395, x=0.394, y=0.456},
        text = L["238577"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89073},
        itemId = 238578,--Songwriter's Pen
        kp = 3,
        waypoint = {map=2393, x=0.4766, y=0.504},
        text = L["238578"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89074},
        itemId = 238579,--Songwriter's Quill
        kp = 3,
        waypoint = {map=2395, x=0.404, y=0.612},
        text = L["238579"]
    })

    -- Treatise
    p:AddEntry(HironCraftProfit_Treatise:New{
        questId = {95131},
        itemId = 245757,--Thalassian Treatise on Inscription
        kp = 1,
        atlasIcon = "Professions-Crafting-Orders-Icon",
        text = L["IncWO"]
    })

    -- Weekly Quest Item
    p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
        questId = {93693},
        itemId = 263457,--Thalassian Scribe's Journal
        kp = 4,
        waypoint = {map=2393, x=0.4693, y=0.5159},
        text = L["TQ"],
        unique = true,
    })

    -- Darkmoon
    p:AddEntry(HironCraftProfit_DarkmoonQuest:New{
		questId={29515}, 
		waypoint={map=407, x=0.5325, y=0.7584}, 
		itemRequirements={{id=39354, quantity=5}}, 
		kp=3
	}) -- DMF Writing the Future

    -- Catch Up
    p:AddEntry(HironCraftProfit_CatchUp:New{
        questId = {},
        itemId = 246328,--Flicker of Midnight Inscription Knowledge
        catchUpCurrencyId = 3195,
        --unlockRequirements = {},
        atlasIcon = "worldquest-icon-inscription",
        kp = 1,
    })

    if DEMYSTIFYING_OK then p:AddEntry(HironCraftProfit_UniqueBook:New{
        questId = {96515},
        itemId = 274514,--Demystifying: Inscription
        kp = 10,
        renown = { majorFactionId = 2772, levelRequired = 6 },
        currency = {
            { id = 3261, quantity = 75 },
            { id = 3316, quantity = 750 },
        },
        waypoint = { map = 2512, x = 0.588, y = 0.46 }
    }) end
    PT.DB.MID[2913] = p
end
-- Midnight Jewelcrafting
do
    local p = HironCraftProfit_Profession:New(2914, 471011, 3194)
    p.expansion = "MID"
    p.isMID = true

    -- Unique Books
	p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId = {93222},
		itemId = 257599,--Skill Issue: Jewelcrafting
		kp = 10,
		renown = { majorFactionId = 2710, levelRequired = 6 },
        currency = {
            { id = 3262, quantity = 75 },
            { id = 3316, quantity = 750 },
        },
		waypoint = { map = 2395, x = 0.434, y = 0.474 }
	})

    -- Weekly Treasures
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
        questId = {93538},
        itemId = 259198,--Void-Touched Eversong Diamond Fragments
        kp = 2,
        atlasIcon = "VignetteLoot",
        text=L["Found on treasures MN"]
    })
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
        questId = {93539},
        itemId = 259199,--Harandar Stone Sample
        kp = 2,
        atlasIcon = "VignetteLoot",
        text=L["Found on treasures MN"]
    })

    -- Unique Treasures
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89122},
        itemId = 238580,--Sin'dorei Masterwork Chisel
        kp = 3,
		waypoint = {map=2393, x=0.505, y=0.5657},
		text = L["238580"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89123},
        itemId = 238581,--Speculative Voidstorm Crystal
        kp = 3,
        waypoint = {map=2444, x=0.3048, y=0.6903},
		extraWaypoints = {
			{map = 2405, x = 0.4127, y = 0.3487},
		},
        text = L["238581"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89124},
        itemId = 238582,--Dual-Function Magnifiers
        kp = 3,
        waypoint = {map=2393, x=0.2863, y=0.4637},
        text = L["238582"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89125},
        itemId = 238583,--Poorly Rounded Vial
        kp = 3,
        waypoint = {map=2395, x=0.5663, y=0.4088},
        text = L["238583"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89126},
        itemId = 238584,--Shattered Glass
        kp = 3,
        waypoint = {map=2444, x=0.6275, y=0.5348},
		extraWaypoints = {
			{map = 2405, x = 0.5560, y = 0.2775},
		},
        -- text = ""
    })
	p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89127},
        itemId = 238585,--Vintage Soul Gem
        kp = 3,
        waypoint = {map=2393, x=0.5544, y=0.4784},
        text = L["238585"]
    })
	p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89128},
        itemId = 238586,--Ethereal Gem Pliers
        kp = 3,
        waypoint = {map=2444, x=0.5420, y=0.5104},
		extraWaypoints = {
			{map = 2405, x = 0.5179, y = 0.2660},
		},
        text = L["238586"]
	})
	p:AddEntry(HironCraftProfit_UniqueTreasure:New{
		questId = {89129},
		itemId = 238587,--Sin'dorei Gem Faceters
		kp = 3,
		waypoint = {map=2395, x=0.3963, y=0.3862},
		text = L["238587"]
	})

    -- Treatise
    p:AddEntry(HironCraftProfit_Treatise:New{
        questId = {95133},
        itemId = 245760,--Thalassian Treatise on Jewelcrafting
        kp = 1,
        atlasIcon = "Professions-Crafting-Orders-Icon",
        text = L["IncWO"]
    })

    -- Weekly Quest Item
    p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
        questId = {93694},
        itemId = 263458,--Thalassian Jewelcrafter's Notebook
        kp = 3,
        -- waypoint = {},
        text = L["TQ"],
        unique = true,
    })

    -- Darkmoon
    p:AddEntry(HironCraftProfit_DarkmoonQuest:New{
		questId={29516}, 
		waypoint={map=407, x=0.5500, y=0.7079}, 
		kp=3
	}) -- DMF Keeping the Faire Sparkling

    -- Catch Up
    p:AddEntry(HironCraftProfit_CatchUp:New{
        questId = {},
        itemId = 246330,--Flicker of Midnight Jewelcrafting Knowledge
        catchUpCurrencyId = 3194,
        --unlockRequirements = {},
        atlasIcon = "worldquest-icon-jewelcrafting",
        kp = 1,
    })

    if DEMYSTIFYING_OK then p:AddEntry(HironCraftProfit_UniqueBook:New{
        questId = {96516},
        itemId = 274510,--Demystifying: Jewelcrafting
        kp = 10,
        renown = { majorFactionId = 2772, levelRequired = 6 },
        currency = {
            { id = 3262, quantity = 75 },
            { id = 3316, quantity = 750 },
        },
        waypoint = { map = 2512, x = 0.588, y = 0.46 }
    }) end
    PT.DB.MID[2914] = p
end
-- Midnight Leatherworking
do
    local p = HironCraftProfit_Profession:New(2915, 471012, 3193)
    p.expansion = "MID"
    p.isMID = true

    -- Unique Books
	p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId = {92371},
		itemId = 250922,--Whisper of the Loa: Leatherworking
		kp = 10,
		renown = { majorFactionId = 2696, levelRequired = 6 },
        currency = {
            { id = 3263, quantity = 75 },
            { id = 3316, quantity = 750 },
        },
			waypoint = { map = 2437, x = 0.458, y = 0.658 }
		})

    -- Weekly Treasures
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
        questId = {93540},
        itemId = 259200,--Amani Tanning Oil
        kp = 2,
        atlasIcon = "VignetteLoot",
        text=L["Found on treasures MN"]
    })
	p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
        questId = {93541},
        itemId = 259201,--Thalassian Mana Oil
        kp = 2,
        atlasIcon = "VignetteLoot",
        text=L["Found on treasures MN"]
    })

    -- Unique Treasures
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89089},
        itemId = 238588,--Amani Leatherworker's Tool
        kp = 3,
        waypoint = {map=2437, x=0.331, y=0.789},	
        text = L["InCave"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89090},
        itemId = 238589,--Ethereal Leatherworking Knife
        kp = 3,
        waypoint = {map=2405, x=0.3472, y=0.5693},
        -- text = ""
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89091},
        itemId = 238590,--Prestigiously Racked Hide
        kp = 3,
        waypoint = {map=2437, x=0.308, y=0.84},
        -- text = ""
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89092},
        itemId = 238591,--Bundle of Tanner's Trinkets
        kp = 3,
        waypoint = {map=2536, x=0.4530, y=0.4559},
		extraWaypoints = {
			{map = 2437, x = 0.3245, y = 0.5347},
		},
        -- text = ""
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89093},
        itemId = 238592,--Patterns: Beyond the Void
        kp = 3,
        waypoint = {map=2444 ,x=0.5374 ,y=0.5168},
		extraWaypoints = {
			{map = 2405, x = 0.5169, y = 0.2709},
		},
        text = L["InsBuilding"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89094},
        itemId = 238593,--Haranir Leatherworking Mallet
        kp = 3,
        waypoint = {map=2413, x=0.517, y=0.513},
        -- text = ""
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89095},
        itemId = 238594,--Haranir Leatherworking Knife
        kp = 3,
        waypoint = {map=2413, x=0.361, y=0.252},
        -- text = ""
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89096},
        itemId = 238595,--Artisan's Considered Order
        kp = 3,
        waypoint = {map=2393, x=0.448, y=0.562},
        -- text = ""
    })

    -- Treatise
    p:AddEntry(HironCraftProfit_Treatise:New{
        questId = {95134},
        itemId = 245758,--Thalassian Treatise on Leatherworking
        kp = 1,
        atlasIcon = "Professions-Crafting-Orders-Icon",
        text = L["IncWO"]
    })

    -- Weekly Quest Item
    p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
        questId = {93695},
        itemId = 263459,--Thalassian Leatherworker's Journal
        kp = 2,
        waypoint = {map=2393, x=0.4316, y=0.5577},
        text = L["TQ"],
        unique = true,
    })

    p:AddEntry(HironCraftProfit_DarkmoonQuest:New{
		questId={29517}, 
		waypoint={map=407, x=0.4925, y=0.6079}, 
		itemRequirements={{id=6529, quantity=10},{id=2320, quantity=5},{id=6260, quantity=5}}, 
		kp=3
	}) -- DMF Eyes on the Prizes

    -- Catch Up
    p:AddEntry(HironCraftProfit_CatchUp:New{
        questId = {},
        itemId = 246332,--Flicker of Midnight Leatherworking Knowledge
        catchUpCurrencyId = 3193,
        --unlockRequirements = {},
        atlasIcon = "worldquest-icon-leatherworking",
        kp = 1,
    })

    if DEMYSTIFYING_OK then p:AddEntry(HironCraftProfit_UniqueBook:New{
        questId = {96517},
        itemId = 274507,--Demystifying: Leatherworking
        kp = 10,
        renown = { majorFactionId = 2772, levelRequired = 6 },
        currency = {
            { id = 3263, quantity = 75 },
            { id = 3316, quantity = 750 },
        },
        waypoint = { map = 2512, x = 0.588, y = 0.46 }
    }) end
    PT.DB.MID[2915] = p
end
-- Midnight Tailoring
do
    local p = HironCraftProfit_Profession:New(2918, 471015, 3190)
    p.expansion = "MID"
    p.isMID = true

    -- Unique Books
	p:AddEntry(HironCraftProfit_UniqueBook:New{
		questId = {93201},
		itemId = 257601,--Skill Issue: Tailoring
		kp = 10,
		renown = { majorFactionId = 2710, levelRequired = 6 },
        currency = {
            { id = 3266, quantity = 75 },
            { id = 3316, quantity = 750 },
        },
			waypoint = { map = 2395, x = 0.434, y = 0.474 }
		})

    -- Weekly Treasures
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
        questId = {93542},
        itemId = 259202,--Embroidered Memento
        kp = 2,
        atlasIcon = "VignetteLoot",
        text=L["Found on treasures MN"]
    })
    p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
        questId = {93543},
        itemId = 259203,--Finely Woven Lynx Collar
        kp = 2,
        atlasIcon = "VignetteLoot",
        text=L["Found on treasures MN"]
    })

    -- Unique Treasures
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89078},
        itemId = 238612,--A Child's Stuffy
        kp = 3,
        waypoint = {map=2413, x=0.7052, y=0.5086},
        text = L["InsBuilding"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89079},
        itemId = 238613,--A Really Nice Curtain
        kp = 3,
        waypoint = {map=2393, x=0.359, y=0.611},
        text = L["238613"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89080},
        itemId = 238614,--Sin'dorei Outfitter's Ruler
        kp = 3,
        waypoint = {map=2395, x=0.463, y=0.348},
        text = L["238614"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89081},
        itemId = 238615,--Wooden Weaving Sword
        kp = 3,
        waypoint = {map=2413, x=0.6976, y=0.5104},
        -- text = ""
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89082},
        itemId = 238616,--Book of Sin'dorei Stitches
        kp = 3,
        waypoint = {map=2444, x=0.6201, y=0.8351},
		extraWaypoints = {
			{map = 2405, x = 0.5528, y = 0.4099},
		},
        -- text = ""
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89083},
        itemId = 238617,--Satin Throw Pillow
        kp = 3,
        waypoint = {map=2444 ,x=0.6139 ,y=0.8512},
		extraWaypoints = {
			{map = 2405, x = 0.5489, y = 0.4165},
		},
        text = L["InsBuilding"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89084},
        itemId = 238618,--Particularly Enchanting Tablecloth
        kp = 3,
        waypoint = {map=2393, x=0.318, y=0.682},
        text = L["238618"]
    })
    p:AddEntry(HironCraftProfit_UniqueTreasure:New{
        questId = {89085},
        itemId = 238619,--Artisan's Cover Comb
        kp = 3,
        waypoint = {map=2437, x=0.4053, y=0.4937},
        text = L["InCave"]
    })

    -- Treatise
    p:AddEntry(HironCraftProfit_Treatise:New{
        questId = {95137},
        itemId = 245756,--Thalassian Treatise on Tailoring
        kp = 1,
        atlasIcon = "Professions-Crafting-Orders-Icon",
        text = L["IncWO"]
    })

    -- Weekly Quest Item
    p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
        questId = {93696},
        itemId = 263460,--Thalassian Tailor's Notebook
        kp = 2,
        -- waypoint = {},
        text = L["TQ"],
        unique = true,
    })

    -- Darkmoon
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
  
    -- Catch Up
    p:AddEntry(HironCraftProfit_CatchUp:New{
        questId = {},
        itemId = 246334,--Flicker of Midnight Tailoring Knowledge
        catchUpCurrencyId = 3190,
        --noUnlockRequirements = true,
        atlasIcon = "worldquest-icon-tailoring",
        kp = 1,
    })

    if DEMYSTIFYING_OK then p:AddEntry(HironCraftProfit_UniqueBook:New{
        questId = {96520},
        itemId = 274512,--Demystifying: Tailoring
        kp = 10,
        renown = { majorFactionId = 2772, levelRequired = 6 },
        currency = {
            { id = 3266, quantity = 75 },
            { id = 3316, quantity = 750 },
        },
        waypoint = { map = 2512, x = 0.588, y = 0.46 }
    }) end
    PT.DB.MID[2918] = p
end
