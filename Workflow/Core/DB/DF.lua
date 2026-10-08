local PT = HironCraftProfit
PT.DB = PT.DB or {}
local L = PT.L

local HironCraftProfit_Profession      = PT.HironCraftProfit_Profession
local HironCraftProfit_UniqueTreasure  = PT.HironCraftProfit_UniqueTreasure
local HironCraftProfit_UniqueBook      = PT.HironCraftProfit_UniqueBook
local HironCraftProfit_WeeklyTreasure  = PT.HironCraftProfit_WeeklyTreasure
local HironCraftProfit_WeeklyQuestItem = PT.HironCraftProfit_WeeklyQuestItem
local HironCraftProfit_DarkmoonQuest   = PT.HironCraftProfit_DarkmoonQuest
local HironCraftProfit_CatchUp         = PT.HironCraftProfit_CatchUp
local HironCraftProfit_Treatise        = PT.HironCraftProfit_Treatise

local HironCraftProfit_Instructor      = PT.HironCraftProfit_Instructor
local HironCraftProfit_Consortium      = PT.HironCraftProfit_Consortium
local HironCraftProfit_Expedition      = PT.HironCraftProfit_Expedition
local HironCraftProfit_ProfMaster      = PT.HironCraftProfit_ProfMaster
local HironCraftProfit_WorkOrder       = PT.HironCraftProfit_WorkOrder
local HironCraftProfit_CraftingOrder   = PT.HironCraftProfit_CraftingOrder

PT.DB.DF = PT.DB.DF or {}

    
    -- HERBALISM (profID = 182)
    
do
    local p = HironCraftProfit_Profession:New(2832, 366242, nil)
		p.expansion = "DF"
        -- Instructor Quest
        p:AddEntry(HironCraftProfit_Instructor:New{
            questId  = {70616, 70613, 70614, 70615},
            waypoint = { map = 2112, x = 0.375, y = 0.679},
			itemId = 199115,
            kp       = 3,
            text     = L["Instructor Quest"],
			professionSkill = {
				expansion = "DF",
				level     = 50,
			},
        })

        -- Treatise (Inscription Crafting Order -> Treatise)
        p:AddEntry(HironCraftProfit_Treatise:New{
            questId  = {74107},
            itemId   = 194704,
            kp       = 1,
            text     = L["IncWO"],
        })

        -- RNG Drop while Gathering (еженедельный предмет-квест)
        p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
            questId  = {71857, 71858, 71859, 71860, 71861},
            itemId   = 200677,
            kp       = 1,
			atlasIcon="Professions_Tracking_Herb",
            text     = L["LittleHerb"],
        })
		p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
            questId  = {71864},
            itemId   = 200678,
            kp       = 3,
			atlasIcon="Professions_Tracking_Herb",
            text     = L["BigHerb"],
			requiresQuestId = {71861}
        })

        -- Profession Master (одноразовый источник)
        p:AddEntry(HironCraftProfit_ProfMaster:New{
            questId  = {70253},
            waypoint = { map = 2023, x = 0.5842, y = 0.5004 },
            kp       = 10,
            text     = L["70253"],
        })
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71897}, 
			itemId=200980, 
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 100
			kp=15, 
			spell=393157,
			reputation = {factionId=2544, standingRequired=4},
			itemRequirements={{id=190456, quantity=100}} 
		}) --  
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71908}, 
			itemId=201276, 
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 150
			kp=15, 
			spell=393232,
			reputation = {factionId=2544, standingRequired=6},		
			itemRequirements={{id=190456, quantity=150}} 
		}) -- 
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71919}, 
			itemId=201287, 
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 200
			kp=15, 
			spell=393233,
			reputation = {factionId=2544, standingRequired=7},	
			itemRequirements={{id=190456, quantity=200}} 
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72319}, --знания-искарских-мастеров
			itemId=201705, 
			waypoint={map=2024, x=0.139, y=0.5008}, -- Роккутук 
			kp=10, 
			spell=394221,
			renown={majorFactionId=2511, levelRequired=14},	 
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72313}, --дар-знания
			itemId=201705, 
			waypoint={map=2023, x=0.604, y=0.376}, -- Интендант Хусенг 
			kp=10, 
			spell=394221,
			renown={majorFactionId=2503, levelRequired=14},	
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72324}, --искарское-мастерство
			itemId=201717, 
			waypoint={map=2024, x=0.139, y=0.5008}, -- Роккутук
			kp=10, 
			spell=394232,
			renown={majorFactionId=2511, levelRequired=24},	
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72313}, --дар-знания
			itemId=201705, 
			waypoint={map=2023, x=0.604, y=0.376}, -- Интендант Хусенг 
			kp=10, 
			spell=394221,
			renown={majorFactionId=2503, levelRequired=14},	
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75753}, 
			itemId=205358, --Ниффский блокнот со знаниями травничества
			waypoint={map=2133, x=0.564, y=0.556}, 
			kp=10, 
			spell=409562,
			renown={majorFactionId=2564, levelRequired=12},	
			currency={{id=2003, quantity=300}} 
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75843},
			itemId=205434, --Выменянные записи травника
			waypoint={map=2133, x=0.58, y=0.538},
			kp=5, 
			spell=410047,
			itemRequirementsOR = {
				{ {id=204985, quantity=35} },
				{ {id=205188, quantity=25} }
			}
		})
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75852},
			itemId=205445, --Выменянный журнал травника
			waypoint={map=2133, x=0.58, y=0.538},
			kp=5, 
			spell=410048,	
			itemRequirementsOR = {
				{ {id=204985, quantity=90} },
				{ {id=205188, quantity=40} }
			}
		}) 
        -- One-time treasure / уникальный источник
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{
            questId  = {74933},
            itemId   = 204228,
            waypoint = { map = 2151, x = 0.566, y = 0.592 },
            kp       = 1,
			itemRequirements={{id=203416, quantity=1}},
            text     = L["204228"],
        })
	PT.DB.DF[2832] = p
end

    
    -- MINING (profID = 186)
    
do
    local p = HironCraftProfit_Profession:New(2833, 366264, nil)
		p.expansion = "DF"
        -- Instructor Quest
        p:AddEntry(HironCraftProfit_Instructor:New{
            questId  = {70617, 72157, 70618, 72156},
            waypoint = { map = 2112, x = 0.388, y = 0.514 },
			itemId 	 = 199122,
            kp       = 3,
            text     = L["Instructor Quest"],
			professionSkill = {
				expansion = "DF",
				level     = 50,
			},
        })

        -- Treatise
        p:AddEntry(HironCraftProfit_Treatise:New{
            questId  = {74106},
            itemId   = 194708,
            kp       = 1,
            text     = L["IncWO"],
        })

        -- RNG Drop while Mining (еженедельный предмет-квест)
        p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
            questId  = {72160, 72161, 72162, 72163, 72164},
            itemId   = 201300,
            kp       = 1,
			atlasIcon="Professions_Tracking_Ore",
            text     = L["LittleOre"],
        })
        p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
            questId  = {72165},
            itemId   = 201301,
            kp       = 1,
			atlasIcon="Professions_Tracking_Ore",
            text = L["BigOre"],
			requiresQuestId = {72164}
        })

        -- Profession Master
        p:AddEntry(HironCraftProfit_ProfMaster:New{
            questId  = {70258},
            waypoint = { map = 2025, x = 0.6141, y = 0.7686},
            kp       = 10,
            text     = L["70258"],
        })

		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71901}, 
			itemId=200981, 
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 100
			kp=15, 
			spell=393161,
			reputation = {factionId=2544, standingRequired=4},
			itemRequirements={{id=190456, quantity=100}} 
		}) --  
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71912}, 
			itemId=201277, 
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 150
			kp=15, 
			spell=393240,
			reputation = {factionId=2544, standingRequired=6},		
			itemRequirements={{id=190456, quantity=150}} 
		}) -- 
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71923}, 
			itemId=201288, 
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 200
			kp=15, 
			spell=393241,
			reputation = {factionId=2544, standingRequired=7},	
			itemRequirements={{id=190456, quantity=200}} 
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72302}, --Профессиональные знания экспедиции
			itemId=201700, 
			waypoint={map=2022, x=0.4694, y=0.829}, -- Босс Магор
			kp=5, 
			spell=394217,
			renown={majorFactionId=2507, levelRequired=14},	
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72332}, --Начинаем с малого
			itemId=201700, 
			waypoint={map=2112, x=0.366, y=0.628}, -- Дофенос
			kp=5, 
			spell=394217,
			renown={majorFactionId=2510, levelRequired=14},	 
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72308}, --Профессиональные знания экспедиции
			itemId=201716, 
			waypoint={map=2022, x=0.4694, y=0.829}, -- Босс Магор
			kp=10, 
			spell=394234,
			renown={majorFactionId=2507, levelRequired=24},	
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72335}, --Как стать лучшим
			itemId=201716, 
			waypoint={map=2112, x=0.366, y=0.628}, -- Дофенос
			kp=10, 
			spell=394234,
			renown={majorFactionId=2510, levelRequired=24},	
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75758}, 
			itemId=205356, --Ниффский блокнот со знаниями горного дела
			waypoint={map=2133, x=0.564, y=0.556}, 
			kp=10, 
			spell=409570,
			renown={majorFactionId=2564, levelRequired=12},	
			currency={{id=2003, quantity=300}} 
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75839},
			itemId=205432, --выменянные-записи-горняка
			waypoint={map=2133, x=0.58, y=0.538},
			kp=5, 
			spell=410039,	
			itemRequirementsOR = {
				{ {id=204985, quantity=35} },
				{ {id=205188, quantity=25} }
			}
		})
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75856},
			itemId=205443, --Выменянный журнал горняка
			waypoint={map=2133, x=0.58, y=0.538},
			kp=5, 
			spell=410040,	
			itemRequirementsOR = {
				{ {id=204985, quantity=90} },
				{ {id=205188, quantity=40} }
			}
		})
		
        -- One-time treasure
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{
            questId  = {74926},
            itemId   = 204233,
            waypoint = { map = 2151, x = 0.432, y = 0.496},
            kp       = 1,
			itemRequirements={{id=203418, quantity=1}},
            text     = L["204233"],
        })
	PT.DB.DF[2833] = p
end
		
    
    -- SKINNING (profID = 393)
    
do
    local p = HironCraftProfit_Profession:New(2834, 366263, nil)
		p.expansion = "DF"
        -- Instructor Quest
        p:AddEntry(HironCraftProfit_Instructor:New{
            questId  = {70620, 72159, 70619, 72158},
            waypoint = { map = 2112, x = 0.285, y = 0.604 },
			itemId 	 = 199128,
            kp       = 3,
            text     = L["Instructor Quest"],
			professionSkill = {
				expansion = "DF",
				level     = 50,
			},
        })

        -- Treatise
        p:AddEntry(HironCraftProfit_Treatise:New{
            questId  = {74114},
            itemId   = 201023,
            kp       = 1,
            text     = L["IncWO"],
        })

        -- RNG Drop
        p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
            questId  = {70381,70383,70384,70385,70386},
            itemId   = 198837,
            kp       = 1,
			atlasIcon="worldquest-icon-skinning",
            text     = L["LittleSkin"],
        })
        p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
            questId  = {70389},
            itemId   = 198841,
            kp       = 2,
			atlasIcon="worldquest-icon-skinning",
            text = L["BigSkin"],
			requiresQuestId = {70386}
        })

        -- Profession Master
        p:AddEntry(HironCraftProfit_ProfMaster:New{
            questId  = {70259},
            waypoint = { map = 2022, x = 0.7334, y = 0.6972 },
            kp       = 10,
            text     = L["70259"],
        })
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71902}, 
			itemId=200982, 
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 100
			kp=15, 
			spell=393162,
			reputation = {factionId=2544, standingRequired=4},
			itemRequirements={{id=190456, quantity=100}} 
		}) --  
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71913}, 
			itemId=201278, 
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 150
			kp=15, 
			spell=393242,
			reputation = {factionId=2544, standingRequired=6},		
			itemRequirements={{id=190456, quantity=150}} 
		}) -- 
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71924}, 
			itemId=201289, 
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 200
			kp=15, 
			spell=393243,
			reputation = {factionId=2544, standingRequired=7},	
			itemRequirements={{id=190456, quantity=200}} 
		}) --
		
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72310}, --Дар знания
			itemId=201714, 
			waypoint={map=2023, x=0.604, y=0.376}, --Интендант Хусенг
			kp=5, 
			spell=394222,
			renown={majorFactionId=2503, levelRequired=14},	 
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72322}, --Знания искарских мастеров
			itemId=201714, 
			waypoint={map=2024, x=0.139, y=0.5008}, -- Роккутук
			kp=5, 
			spell=394222,
			renown={majorFactionId=2511, levelRequired=14},	
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72317}, --дар-тайн
			itemId=201718, 
			waypoint={map=2023, x=0.604, y=0.376}, -- Интендант Хусенг
			kp=10, 
			spell=394233,
			renown={majorFactionId=2503, levelRequired=24},	 
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72327}, --искарское-мастерство
			itemId=201718, 
			waypoint={map=2024, x=0.139, y=0.5008}, -- Роккутук
			kp=10, 
			spell=394233,
			renown={majorFactionId=2511, levelRequired=24},	
		}) --

		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75760}, 
			itemId=205357, --Ниффский блокнот со знаниями снятия шкур
			waypoint={map=2133, x=0.564, y=0.556}, 
			kp=10, 
			spell=409573,
			renown={majorFactionId=2564, levelRequired=12},	
			currency={{id=2003, quantity=300}} 
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75838},
			itemId=205433, --Выменянные записи шкуродера
			waypoint={map=2133, x=0.58, y=0.538},
			kp=5, 
			spell=410037,
			itemRequirementsOR = {
				{ {id=204985, quantity=35} },
				{ {id=205188, quantity=25} }
			}
		})
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75857},
			itemId=205444, --Выменянный журнал шкуродера
			waypoint={map=2133, x=0.58, y=0.538},
			kp=5, 
			spell=410038,
			itemRequirementsOR = {
				{ {id=204985, quantity=90} },
				{ {id=205188, quantity=40} }
			}
		}) 
		
        -- Unique Treasure
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{
            questId  = {74930},
            itemId   = 204231,
            waypoint = { map = 2151, x = 0.452, y = 0.366 },
            kp       = 1,
			itemRequirements={{id=203417, quantity=1}},
            text     = L["204231"],
        })
	PT.DB.DF[2834] = p
end

    
    -- ALCHEMY (profID = 171)
    
do
    local p = HironCraftProfit_Profession:New(2823, 366261, nil)
		p.expansion = "DF"
        -- Instructor
        p:AddEntry(HironCraftProfit_Instructor:New{
            questId  = {70530,70532,70533,70531},
            waypoint = { map = 2112, x = 0.364, y = 0.717 },
			itemId   = 198608,
            kp       = 3,
            text     = L["Instructor Quest"],
			professionSkill = {
				expansion = "DF",
				level     = 50,
			},
        })

        -- Consortium Quest
        p:AddEntry(HironCraftProfit_Consortium:New{
            questId  = {66940, 72427, 66937, 66938, 77932, 77933},
            waypoint = { map = 2112, x = 0.366, y = 0.629 },
			itemId   = 198608,
            kp       = 3,
            text     = L["Consortium Quest"],
        })

        -- Treatise
        p:AddEntry(HironCraftProfit_Treatise:New{
            questId  = {74108},
            itemId   = 194697,
            kp       = 1,
            text     = L["IncWO"],
        })

        -- Expedition Drop
        p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
            questId  = {66373},
			itemId   = 193891,
            kp       = 1,
            text=L["Found on treasures DF"]
        })
        p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
            questId  = {66374},
			itemId   = 193897,
            kp       = 1,
            text=L["Found on treasures DF"]
        })

        -- RNG Drops
        p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
            questId  = {70511},
            itemId   = 198964,
            kp       = 1,
			waypoint = {map=2023, x=0.796, y=0.798}, --Hissing Springsoul
            text     = L["RousingElem"],
        })
        p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
            questId  = {70504},
            itemId   = 198963,--Decaying Phlegm
            kp       = 1,
			waypoint = {map=2024, x=0.1778, y=0.3922}, --Brakenhide Rotflinger
            text     = L["Decay"],
        })

        -- Profession Master
        p:AddEntry(HironCraftProfit_ProfMaster:New{
            questId  = {70247},
            waypoint = { map = 2022, x = 0.6092, y = 0.7584 },
            kp       = 10,
            text     = L["70247"],
        })

        
        -- Unique Treasures — 15+ entries
        
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70289}, 
			itemId=198685, 
			waypoint={map=2022,x=0.2512,y=0.7411}, 
			kp=3 
		}) 
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70274}, 
			itemId=198663, 
			waypoint={map=2022,x=0.55,y=0.81}, 
			kp=3
		}) 
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70208}, 
			itemId=198599, 
			waypoint={map=2024,x=0.164,y=0.385}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70305}, 
			itemId=198710, 
			waypoint={map=2023,x=0.792,y=0.838}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70309}, 
			itemId=198712, 
			waypoint={map=2024,x=0.67,y=0.132}, kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70278}, 
			itemId=203471, 
			waypoint={map=2025,x=0.552,y=0.305}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70301}, 
			itemId=198697, 
			waypoint={map=2025,x=0.595,y=0.384}, 
			kp=3
		})

        -- Zaralek Cavern alchemy treasures
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={75651}, 
			itemId=205213, 
			waypoint={map=2133,x=0.4048,y=0.5918}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={75649}, 
			itemId=205212, 
			waypoint={map=2133,x=0.6210,y=0.4112}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={75646}, 
			itemId=205211, 
			waypoint={map=2133,x=0.5268,y=0.183}, 
			kp=3 
		})

        -- Emerald Dream
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={78269}, 
			itemId=210185, 
			waypoint={map=2200,x=0.6348,y=0.7169}, 
			kp=3,
			text=L["InCave"] 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={78275}, 
			itemId=210190, 
			waypoint={map=2200,x=0.3621,y=0.4663}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={78264}, 
			itemId=210184, 
			waypoint={map=2200,x=0.5405,y=0.3264}, 
			kp=3 
		})

        -- book
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71893}, 
			itemId=200974, 
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 100
			kp=10, 
			spell=393153,
			reputation = {factionId=2544, standingRequired=4},
			itemRequirements={{id=190456, quantity=100}} 
		}) --  
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71904}, 
			itemId=201270, 
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 150
			kp=10, 
			spell=393224,
			reputation = {factionId=2544, standingRequired=6},		
			itemRequirements={{id=190456, quantity=150}} 
		}) -- 
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71915}, 
			itemId=201281, 
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 200
			kp=10, 
			spell=393225,
			reputation = {factionId=2544, standingRequired=7},	
			itemRequirements={{id=190456, quantity=200}} 
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={70892}, --Начинаем с малого
			itemId=201706, 
			waypoint={map=2112, x=0.366, y=0.628}, --Дофенос
			kp=5, 
			spell=394223,
			renown={majorFactionId=2510, levelRequired=14},	
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72311}, --дар-знания
			itemId=201706, 
			waypoint={map=2023, x=0.604, y=0.376}, -- Интендант Хусенг 
			kp=5, 
			spell=394223,
			renown={majorFactionId=2503, levelRequired=14},	
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={70889}, --Как стать лучшим
			itemId=201706, 
			waypoint={map=2112, x=0.366, y=0.628}, --Дофенос
			kp=5, 
			spell=394223,
			renown={majorFactionId=2510, levelRequired=24},	
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72314}, --дар-тайн
			itemId=201706, 
			waypoint={map=2023, x=0.604, y=0.376}, -- Интендант Хусенг
			kp=5, 
			spell=394223,
			renown={majorFactionId=2503, levelRequired=24},	
		})
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75756}, 
			itemId=205353, --Ниффский блокнот со знаниями алхимии
			waypoint={map=2133, x=0.564, y=0.556}, 
			kp=10, 
			spell=409567,
			renown={majorFactionId=2564, levelRequired=12},	
			currency={{id=2003, quantity=300}} 
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75847},
			itemId=205429, --Выменянные записи алхимика
			waypoint={map=2133, x=0.58, y=0.538},
			kp=5, 
			spell=410055,	
			itemRequirementsOR = {
				{ {id=204985, quantity=35} },
				{ {id=205188, quantity=25} }
			}
		})
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75848},
			itemId=205440, --Выменянный журнал алхимика
			waypoint={map=2133, x=0.58, y=0.538},
			kp=5, 
			spell=410056,	
			itemRequirementsOR = {
				{ {id=204985, quantity=90} },
				{ {id=205188, quantity=40} }
			}
		}) 		
        -- One-time treasure / уникальный источник
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{
            questId={74935}, 
			itemId=204226,
            waypoint={map=2151,x=0.56,y=0.394},
            kp=1, 
			itemRequirements={{id=203407, quantity=1}},
			text=L["74935"]
        })
	PT.DB.DF[2823] = p
end		

    
    -- ENGINEERING (profID = 202)
    
do
    local p = HironCraftProfit_Profession:New(2827, 366254, nil)
		p.expansion = "DF"
        -- Instructor Quest
        p:AddEntry(HironCraftProfit_Instructor:New{
            questId  = {70557, 70540, 70545, 70539},
            waypoint = { map = 2112, x = 0.42, y = 0.486 },
			itemId   = 198611,
            kp       = 2,
            text     = L["Instructor Quest"],
			professionSkill = {
				expansion = "DF",
				level     = 50,
			},
        })

        -- Consortium Quest
        p:AddEntry(HironCraftProfit_Consortium:New{
            questId  = {66890, 66942, 72396, 77938, 77891},
            waypoint = { map = 2112, x = 0.366, y = 0.629 },
			itemId   = 198611,
            kp       = 2,
            text     = L["Consortium Quest"],
        })

        -- Crafting Orders Quest
        p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
            questId  = {70591},--Требуются услуги инженера
			itemId   = {198611},
            waypoint = { map = 2112, x = 0.354, y = 0.588 },
            kp       = 2,
            text     = L["CraftOQ"]
        })

        -- Inscription Treatise
        p:AddEntry(HironCraftProfit_Treatise:New{
            questId = {74111},
            itemId  = 198510,
            kp      = 1,
            text    = L["IncWO"]
        })

        -- Expedition Drop
        p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
            questId = {66379},
			itemId  = 193902,
            kp      = 1,
            text    = L["Found on treasures DF"]
        })
        p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
            questId = {66378},
			itemId  = 193903,
            kp      = 1,
            text    = L["Found on treasures DF"]
        })
        -- RNG Drops
        p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
            questId = {70517},
            itemId  = 198970,
            kp      = 1,
			waypoint = {map=2025, x=0.458, y=0.582},
            text    = "Mobs: Dragonkin"
        })
        p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
            questId = {70516},
            itemId  = 198969,
            kp      = 1,
			waypoint = {map=2025, x=0.57, y=0.592},
            text    = "Mobs: Titans"
        })

        -- Profession Master
        p:AddEntry(HironCraftProfit_ProfMaster:New{
            questId  = {70252},
            waypoint = { map = 2024, x = 0.178, y = 0.217 },
            kp       = 10,
            text     = "Profession Master (NPC: Frizz Buzzcrank)"
        })

        
        -- Unique Treasures (+11 entries)
        
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70270}, 
			itemId=201014, 
			waypoint={map=2022,x=0.56,y=0.449}, 
			kp=3,
			text=L["BOOMTHYR_ROCKET_NOTE"]
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70275}, 
			itemId=198789, 
			waypoint={map=2022,x=0.4909,y=0.7754}, 
			kp=3
		})

        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={75180}, 
			itemId=204469, 
			waypoint={map=2133,x=0.4848,y=0.4864}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={75431}, 
			itemId=204853, 
			waypoint={map=2133,x=0.4944,y=0.7901}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={75188}, 
			itemId=204480, 
			waypoint={map=2133,x=0.4987,y=0.5925}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={75186}, 
			itemId=204475, 
			waypoint={map=2133,x=0.3782,y=0.5883}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={75430}, 
			itemId=204850, 
			waypoint={map=2133,x=0.5765,y=0.7394}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={75433}, 
			itemId=204855, 
			waypoint={map=2133,x=0.4810,y=0.1659}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={75183}, 
			itemId=204470, 
			waypoint={map=2133,x=0.4817,y=0.2793}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={75184}, 
			itemId=204471, 
			waypoint={map=2133,x=0.5051,y=0.4793}, 
			kp=3 
		})

        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={78279}, 
			itemId=210194, 
			waypoint={map=2200,x=0.6327,y=0.7345}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={78278}, 
			itemId=210193, 
			waypoint={map=2200,x=0.3955,y=0.5228}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={78281}, 
			itemId=210197, 
			waypoint={map=2200,x=0.6266,y=0.3627}, 
			kp=3 
		})

        -- Darkmoon Faire
        p:AddEntry(HironCraftProfit_DarkmoonQuest:New{
            questId  = {29511},
            waypoint = { map = 407, x = 0.494, y = 0.608 },
            kp       = 1,
            text     = "NPC: Rinling"
        })

        --Book
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71896}, 
			itemId=200977, --Пыльные черновики инженера
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 100
			kp=10, 
			spell=393156,
			reputation = {factionId=2544, standingRequired=4},
			itemRequirements={{id=190456, quantity=100}} 
		}) --  
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71907}, 
			itemId=201273, 
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 150
			kp=10, 
			spell=393230,
			reputation = {factionId=2544, standingRequired=6},		
			itemRequirements={{id=190456, quantity=150}} 
		}) -- 
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71918}, 
			itemId=201284, --Древние черновики инженера
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 200
			kp=10, 
			spell=393231,
			reputation = {factionId=2544, standingRequired=7},	
			itemRequirements={{id=190456, quantity=200}} 
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72330}, --Начинаем с малого
			itemId=201710, 
			waypoint={map=2112, x=0.366, y=0.628}, --Дофенос
			kp=5, 
			spell=394226,
			renown={majorFactionId=2510, levelRequired=14},	
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={70902}, --Как стать лучшим
			itemId=201710, 
			waypoint={map=2112, x=0.366, y=0.628}, --Дофенос
			kp=5, 
			spell=394226,
			renown={majorFactionId=2510, levelRequired=24},	
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72300}, --Профессиональные знания экспедиции
			itemId=201710, 
			waypoint={map=2022, x=0.4694, y=0.829}, -- Босс Магор
			kp=5, 
			spell=394226,
			renown={majorFactionId=2507, levelRequired=14},	
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72305}, --Профессиональные знания экспедиции
			itemId=201710, 
			waypoint={map=2022, x=0.4694, y=0.829}, -- Босс Магор
			kp=5, 
			spell=394226,
			renown={majorFactionId=2507, levelRequired=24},	
		}) --
		
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75759}, 
			itemId=205349, --Ниффский блокнот со знаниями инженерного дела
			waypoint={map=2133, x=0.564, y=0.556}, 
			kp=10, 
			spell=409571,
			renown={majorFactionId=2564, levelRequired=12},	
			currency={{id=2003, quantity=300}} 
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75844},
			itemId=205425, --Выменянные записи инженера
			waypoint={map=2133, x=0.58, y=0.538},
			kp=5, 
			spell=410049,
			itemRequirementsOR = {
				{ {id=204985, quantity=35} },
				{ {id=205188, quantity=25} }
			} 
		})
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75851},
			itemId=205436, --Выменянный журнал инженера
			waypoint={map=2133, x=0.58, y=0.538},
			kp=5, 
			spell=410050,	
			itemRequirementsOR = {
				{ {id=204985, quantity=90} },
				{ {id=205188, quantity=40} }
			}
		}) 
		
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{
            questId  = {74934},
            itemId   = 204227,
            waypoint = { map = 2151, x = 0.612, y = 0.268 },
            kp       = 1,
			itemRequirements={{id=203411, quantity=1}},
            text     = "Fimbol"
        })
	PT.DB.DF[2827] = p
end

    
    -- TAILORING (profID = 197)
    
do
    local p = HironCraftProfit_Profession:New(2831, 366258, nil)
		p.expansion = "DF"
        -- Instructor Quest
        p:AddEntry(HironCraftProfit_Instructor:New{
            questId  = {70572,70587,70586,70582},
            waypoint = { map = 2112, x = 0.319, y = 0.672 },
			itemId	 = 198609,
            kp       = 3,
            text     = L["Instructor Quest"],
			professionSkill = {
				expansion = "DF",
				level     = 50,
			},
        })

        -- Consortium Quest
        p:AddEntry(HironCraftProfit_Consortium:New{
            questId  = {72410,66952,66953,66899,77947,77949},
            waypoint = { map = 2112, x = 0.366, y = 0.629 },
			itemId	 = 198609,
            kp       = 3,
            text     = L["Consortium Quest"]
        })

        -- Crafting Orders Quest
        p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
            questId  = {70595},
			itemId 	 = 198609,
            waypoint = { map = 2112, x = 0.354, y = 0.588 },
            kp       = 3,
            text     = L["CraftOQ"]
        })

        -- Treatise
        p:AddEntry(HironCraftProfit_Treatise:New{
            questId = {74115},
            itemId  = 194698,
            kp      = 1,
            text    = L["IncWO"]
        })

        -- Expedition Drop
        p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
            questId = {66386},
			itemId  = 193898,
            kp      = 1,
            text    = L["Found on treasures DF"]
        })
        p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
            questId = {66387},
			itemId  = 193899,
            kp      = 1,
            text    = L["Found on treasures DF"]
        })	
        
        -- RNG Drops
        
        p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{ 
			questId={70524}, 
			itemId=198977, 
			kp=1, 
			waypoint = {map=2023, x=0.84, y=0.56},
			text=L["198977"]
		})
        p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{ 
			questId={70525}, 
			itemId=198978, 
			kp=1, 
			waypoint = {map=2024, x=0.3384, y=0.4722},
			text= L["198978"]
		})

        -- Profession Master
        p:AddEntry(HironCraftProfit_ProfMaster:New{
            questId  = {70260},
            waypoint = { map = 2112, x = 0.2796, y = 0.4576 },
            kp       = 10,
            text     = L["70260"]
        })

        
        -- Unique Treasures (18 entries)
        
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70302}, 
			itemId=198699, 
			waypoint={map=2022,x=0.747,y=0.379}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70304}, 
			itemId=198702, 
			waypoint={map=2022,x=0.249,y=0.697}, 
			kp=3 
			})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70295}, 
			itemId=198692, 
			waypoint={map=2023,x=0.3534,y=0.4012}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70303}, 
			itemId=201020, 
			waypoint={map=2023,x=0.661,y=0.529}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70284}, 
			itemId=198680, 
			waypoint={map=2024,x=0.162,y=0.388}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70267}, 
			itemId=198662, 
			waypoint={map=2024,x=0.407,y=0.545}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70288}, 
			itemId=198684, 
			waypoint={map=2025,x=0.604,y=0.797}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70372}, 
			itemId=201019, 
			waypoint={map=2025,x=0.586,y=0.458}, 
			kp=3 
		})

        -- Zaralek Cavern
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={76116}, 
			itemId=206030, 
			waypoint={map=2133,x=0.4452,y=0.1565}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={76102}, 
			itemId=206019, 
			waypoint={map=2133,x=0.4721,y=0.4855}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={76110}, 
			itemId=206026, 
			waypoint={map=2133,x=0.5911,y=0.7314}, 
			kp=3 
		})

        -- Emerald Dream
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={78415}, 
			itemId=210462, 
			waypoint={map=2200,x=0.4983,y=0.6148}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={78414}, 
			itemId=210461, 
			waypoint={map=2200,x=0.5327,y=0.2792}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={78416}, 
			itemId=210463, 
			waypoint={map=2200,x=0.4070,y=0.8616}, 
			kp=3 
		})

        -- Darkmoon Faire
        p:AddEntry(HironCraftProfit_DarkmoonQuest:New{
            questId = {29520},
            waypoint={map=407,x=55.4/100,y=54.8/100},
            kp=1,
            text="NPC: Selina Dourman"
        })

        -- Book
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71903}, 
			itemId=200975, --Пыльные схемы портного
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 100
			kp=10, 
			spell=393163,
			reputation = {factionId=2544, standingRequired=4},
			itemRequirements={{id=190456, quantity=100}} 
		}) --  
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71914}, 
			itemId=201271, --Редкие схемы портного
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 150
			kp=10, 
			spell=393244,
			reputation = {factionId=2544, standingRequired=6},		
			itemRequirements={{id=190456, quantity=150}} 
		}) -- 
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71925}, 
			itemId=201282, --Древние схемы портного
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 200
			kp=10, 
			spell=393245,
			reputation = {factionId=2544, standingRequired=7},	
			itemRequirements={{id=190456, quantity=200}} 
		}) --
		
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72333}, --Начинаем с малого
			itemId=201715, 
			waypoint={map=2112, x=0.366, y=0.628}, --Дофенос
			kp=5, 
			spell=394230,
			renown={majorFactionId=2510, levelRequired=14},	
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72336}, --Как стать лучшим
			itemId=201715, 
			waypoint={map=2112, x=0.366, y=0.628}, --Дофенос
			kp=5, 
			spell=394230,
			renown={majorFactionId=2510, levelRequired=24},	
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72303}, --Профессиональные знания экспедиции
			itemId=201715, 
			waypoint={map=2022, x=0.4694, y=0.829}, -- Босс Магор
			kp=5, 
			spell=394230,
			renown={majorFactionId=2507, levelRequired=14},	
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72309}, --Профессиональные знания экспедиции
			itemId=201715, 
			waypoint={map=2022, x=0.4694, y=0.829}, -- Босс Магор
			kp=5, 
			spell=394230,
			renown={majorFactionId=2507, levelRequired=24},	
		}) --		
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75757}, 
			itemId=205355, --Ниффский блокнот со знаниями портняжного дела
			waypoint={map=2133, x=0.564, y=0.556}, 
			kp=10, 
			spell=409568,
			renown={majorFactionId=2564, levelRequired=12},	
			currency={{id=2003, quantity=300}} 
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75837},
			itemId=205431, --Выменянные записи портного
			waypoint={map=2133, x=0.58, y=0.538},
			kp=5, 
			spell=410035,
			itemRequirementsOR = {
				{ {id=204985, quantity=35} },
				{ {id=205188, quantity=25} }
			} 
		})
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75858},
			itemId=205442, --Выменянный журнал портного
			waypoint={map=2133, x=0.58, y=0.538},
			kp=5, 
			spell=410036,	
			itemRequirementsOR = {
				{ {id=204985, quantity=90} },
				{ {id=205188, quantity=40} }
			}
		}) 
				
        p:AddEntry(HironCraftProfit_UniqueBook:New{
            questId  = {74929},
            itemId   = 204225,
            waypoint = { map = 2151, x = 0.312, y = 0.536 },
            kp       = 1,
			itemRequirements={{id=203415, quantity=1}},
            text     = L["204225"]
        })
	PT.DB.DF[2831] = p
end

    
    -- ENCHANTING (profID = 333)
    
do
    local p = HironCraftProfit_Profession:New(2825, 366255, nil)
		p.expansion = "DF"
        
        -- Instructor Quest
        
        p:AddEntry(HironCraftProfit_Instructor:New{
            questId  = {72173,72172,72175,72155},
            waypoint = { map = 2112, x = 0.311, y = 0.614 },
			itemId   = 198610,
            kp       = 3,
            text     = L["Instructor Quest"],
			professionSkill = {
				expansion = "DF",
				level     = 50,
			},
        })

        
        -- Consortium Quest
        
        p:AddEntry(HironCraftProfit_Consortium:New{
            questId  = {66900,66884,72423,66935,77910,77937},
            waypoint = { map = 2112, x = 0.366, y = 0.629 },
			itemId   = 198610,
            kp       = 3,
            text     = L["Consortium Quest"]
        })

        
        -- Treatise (Inscription)
        
        p:AddEntry(HironCraftProfit_Treatise:New{
            questId = {74110},
            itemId  = 194702,
            kp      = 1,
            text    = L["IncWO"]
        })

        
        -- Expedition Drop
        
        p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
            questId = {66377},
			itemId  = 193900,
            kp      = 1,
            text    = L["Found on treasures DF"]
        })        
		p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
            questId = {66378},
			itemId  = 193901,
            kp      = 1,
            text    = L["Found on treasures DF"]
        })
        
        -- RNG mob drops 
        
        p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
            questId = {70515},
            itemId  = 198968,
            kp      = 1,
			waypoint = {map=2025, x=0.532, y=0.656},
            text    = "Mobs: Humanoid Primalists\n(Earthshaker Marauder)"
        })
        p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
            questId = {70514},
            itemId  = 198967,
            kp      = 1,
			waypoint = {map=2024, x=0.4049, y=0.61},
            text    = "Mobs: Arcane Elementals\nAttentive-Guardian or Stablized-Elemental"
        })

        
        -- Profession Master
        
        p:AddEntry(HironCraftProfit_ProfMaster:New{
            questId  = {70251},
            waypoint = { map = 2023, x = 0.6242, y = 0.187 },
            kp       = 10,
            text     = L["70251"]
        })

        
        -- Unique Treasures (Dragon Isles)
        
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70320}, 
			itemId=198798, 
			waypoint={map=2022,x=0.575,y=0.836}, 
			kp=3
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70283}, 
			itemId=198675, 
			waypoint={map=2022,x=0.68,y=0.268}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70272}, 
			itemId=201012, 
			waypoint={map=2022,x=0.575,y=0.585}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70291}, 
			itemId=198689, 
			waypoint={map=2023,x=0.614,y=0.676}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70336}, 
			itemId=198799, 
			waypoint={map=2024,x=0.385,y=0.592}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70290}, 
			itemId=201013, 
			waypoint={map=2024,x=0.451,y=0.612}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70298}, 
			itemId=198694, 
			waypoint={map=2024,x=0.21,y=0.45}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70342}, 
			itemId=198800, 
			waypoint={map=2025,x=0.599,y=0.704}, 
			kp=3 
		})

        
        -- Zaralek Cavern (2133)
        
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={75510}, 
			itemId=205001, 
			waypoint={map=2133,x=0.3666,y=0.6933}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={75509}, 
			itemId=204999, 
			waypoint={map=2133,x=0.6239,y=0.5380}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={75508}, 
			itemId=204990, 
			waypoint={map=2133,x=0.4800,y=0.1700}, 
			kp=3
		})

        
        -- Emerald Dream (2200)
        
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={78308}, 
			itemId=210228, 
			waypoint={map=2200,x=0.3837,y=0.3020}, kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={78309}, 
			itemId=210231, 
			waypoint={map=2200,x=0.4616,y=0.2051}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={78310}, 
			itemId=210234, 
			waypoint={map=2200,x=0.6636,y=0.7420}, 
			kp=3
		})

        
        -- Primal Storms ()
        
		p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId = {71940}, 
			itemId  = 201359, 
			kp      = 3, 
			text    = L["PrimalStorms_Earth"],
		})

		p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId = {71939}, 
			itemId  = 201358, 
			kp      = 3, 
			text    = L["PrimalStorms_Air"],
		})

		p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId = {71942}, 
			itemId  = 201357, 
			kp      = 3, 
			text    = L["PrimalStorms_Frost"],
		})

		p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId = {71941}, 
			itemId  = 201356, 
			kp      = 3, 
			text    = L["PrimalStorms_Fire"],
		})
		p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId	={71943}, 
			itemId	=201360, 
			kp		=3,
			itemRequirements={{id=200479, quantity=1}},			
			text	=L["GlimmerOfOrder"] 
		})
        
        -- Darkmoon Faire
        
        p:AddEntry(HironCraftProfit_DarkmoonQuest:New{
            questId  = {29510},
            waypoint = { map = 407, x = 0.53, y = 0.758 },
            kp       = 1,
            text     = "NPC: Sayge"
        })

		--Books
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71895}, 
			itemId=200976, 
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 100
			kp=10, 
			spell=393155,
			reputation = {factionId=2544, standingRequired=4},
			itemRequirements={{id=190456, quantity=100}} 
		}) --  
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71906}, 
			itemId=201272, 
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 150
			kp=10, 
			spell=393228,
			reputation = {factionId=2544, standingRequired=6},		
			itemRequirements={{id=190456, quantity=150}} 
		}) -- 
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71917}, 
			itemId=201283, 
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 200
			kp=10, 
			spell=393229,
			reputation = {factionId=2544, standingRequired=7},	
			itemRequirements={{id=190456, quantity=200}} 
		}) --
		
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72318}, --Знания искарских мастеров
			itemId=201709, 
			waypoint={map=2024, x=0.139, y=0.5008}, -- Роккутук
			kp=5, 
			spell=394225,
			renown={majorFactionId=2511, levelRequired=14},	
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72323}, --искарское-мастерство
			itemId=201709, 
			waypoint={map=2024, x=0.139, y=0.5008}, -- Роккутук
			kp=5, 
			spell=394225,
			renown={majorFactionId=2511, levelRequired=24},	
		}) --
		
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72299}, --Профессиональные знания экспедиции
			itemId=201709, 
			waypoint={map=2022, x=0.4694, y=0.829}, -- Босс Магор
			kp=5, 
			spell=394225,
			renown={majorFactionId=2507, levelRequired=14},	
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72304}, --Профессиональные знания экспедиции
			itemId=201709, 
			waypoint={map=2022, x=0.4694, y=0.829}, -- Босс Магор
			kp=5, 
			spell=394225,
			renown={majorFactionId=2507, levelRequired=24},	
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75752}, 
			itemId=205351, --Ниффский блокнот со знаниями наложения чар
			waypoint={map=2133, x=0.564, y=0.556}, 
			kp=10, 
			spell=409561,
			renown={majorFactionId=2564, levelRequired=12},	
			currency={{id=2003, quantity=300}} 
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75845},
			itemId=205427, --Выменянные записи зачаровывателя
			waypoint={map=2133, x=0.58, y=0.538},
			kp=5, 
			spell=410051,
			itemRequirementsOR = {
				{ {id=204985, quantity=35} },
				{ {id=205188, quantity=25} }
			}
		})
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75850},
			itemId=205438, --Выменянный журнал зачаровывателя
			waypoint={map=2133, x=0.58, y=0.538},
			kp=5, 
			spell=410052,
			itemRequirementsOR = {
				{ {id=204985, quantity=90} },
				{ {id=205188, quantity=40} }
			}
		}) 			
		
        p:AddEntry(HironCraftProfit_UniqueBook:New{
            questId  = {74927},
            itemId   = 204224,
            waypoint = { map = 2151, x = 0.554, y = 0.364 },
            kp       = 1,
			itemRequirements={{id=203410, quantity=1}},
            text     = L["204224"]
        })
	PT.DB.DF[2825] = p
end

    
    -- LEATHERWORKING (profID = 165)
    
do
    local p = HironCraftProfit_Profession:New(2830, 366249, nil)
		p.expansion = "DF"
        
        -- Instructor Quest
        
        p:AddEntry(HironCraftProfit_Instructor:New{
            questId  = {70568,70569,70571,70567},
            waypoint = { map = 2112, x = 0.285, y = 0.613 },
			itemId   = 198613,
            kp       = 3,
            text     = L["Instructor Quest"],
			professionSkill = {
				expansion = "DF",
				level     = 50,
			},
        })

        
        -- Consortium Quest
        
        p:AddEntry(HironCraftProfit_Consortium:New{
            questId  = {66363,66364,72407,66951,77946,77945},
            waypoint = { map = 2112, x = 0.366, y = 0.629 },
			itemId   = 198613,
            kp       = 3,
            text     = L["Consortium Quest"]
        })

        
        -- Crafting Orders Quest
        
        p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
            questId  = {70594},
			itemId 	 = 198613,
            waypoint = { map = 2112, x = 0.354, y = 0.588 },
            kp       = 2,
            text     = L["CraftOQ"]
        })

        
        -- Treatise (Inscription)
        
        p:AddEntry(HironCraftProfit_Treatise:New{
            questId = {74113},
            itemId  = 194700,
            kp      = 1,
            text    = L["IncWO"]
        })

        
        -- Expedition Drop
        
        p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
            questId = {66384},
			itemId  = 193910,
            kp      = 1,
            text    = L["Found on treasures DF"]
        })
        p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
            questId = {66385},
			itemId  = 193913,
            kp      = 1,
            text    = L["Found on treasures DF"]
        })

        
        -- RNG Mob Drops (Unique Treasures)
        
        p:AddEntry(HironCraftProfit_WeeklyTreasure:New{ 
			questId={70523}, 
			itemId=198976, 
			waypoint={map=2024,x=0.38,y=0.30}, 
			kp=1,
			text=L["198976"]
		})
        p:AddEntry(HironCraftProfit_WeeklyTreasure:New{ 
			questId={70522}, 
			itemId=198975, 
			waypoint={map=2022,x=0.80,y=0.24},
			kp=1,
			text=L["198975"]
		})

        
        -- Profession Master
        
        p:AddEntry(HironCraftProfit_ProfMaster:New{
            questId  = {70256},
            waypoint = { map = 2023, x = 0.8245, y = 0.5067 },
            kp       = 10,
            text     = L["70256"]
        })

        
        -- Unique Treasures (Dragon Isles)
        
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70308}, 
			itemId=198711,
			waypoint={map=2022,x=0.39,y=0.86}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70280}, 
			itemId=198667,
			waypoint={map=2022,x=0.643,y=0.254}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70300}, 
			itemId=198696, 
			waypoint={map=2023,x=0.864,y=0.537}, kp=3
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70269},
			itemId=201018, 
			waypoint={map=2024,x=0.125,y=0.494}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70266}, 
			itemId=198658, 
			waypoint={map=2024,x=0.167,y=0.388}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70286}, 
			itemId=198683, 
			waypoint={map=2024,x=0.575,y=0.413}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70294}, 
			itemId=198690, 
			waypoint={map=2025,x=0.568,y=0.305}, 
			kp=3 
		})

        
        -- Zaralek Cavern (2133)
        
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={75496}, 
			itemId=204987, 
			waypoint={map=2133,x=0.4525,y=0.2112}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={75495}, 
			itemId=204986,
			waypoint={map=2133,x=0.4116,y=0.4881}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={75502}, 
			itemId=204988, 
			waypoint={map=2133,x=0.4956,y=0.5480}, 
			kp=3 
		})

        
        -- Emerald Dream (2200)
        
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={78298}, 
			itemId=210208, 
			waypoint={map=2200,x=0.4175,y=0.6649}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={78305}, 
			itemId=210215, 
			waypoint={map=2200,x=0.34,y=0.2970}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={78299}, 
			itemId=210211, 
			waypoint={map=2200,x=0.3745,y=0.7102}, 
			kp=3 
		})

        
        -- Darkmoon Faire
        
        p:AddEntry(HironCraftProfit_DarkmoonQuest:New{
            questId  = {29517},
            waypoint = { map = 407, x = 0.494, y = 0.608 },
            kp       = 1,
            text     = "Rinling (DMF Quest)"
        })

        
        -- Book
        
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71900}, 
			itemId=200979, --Пыльные  
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 100
			kp=10, 
			spell=393160,
			reputation = {factionId=2544, standingRequired=4},
			itemRequirements={{id=190456, quantity=100}} 
		}) --  
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71911}, 
			itemId=201275, 
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 150
			kp=10, 
			spell=393238,
			reputation = {factionId=2544, standingRequired=6},		
			itemRequirements={{id=190456, quantity=150}} 
		}) -- 
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71922}, 
			itemId=201286, --Древние  
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 200
			kp=10, 
			spell=393239,
			reputation = {factionId=2544, standingRequired=7},	
			itemRequirements={{id=190456, quantity=200}} 
		}) --		
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72321}, --знания-искарских-мастеров
			itemId=201713, 
			waypoint={map=2024, x=0.139, y=0.5008}, -- Роккутук 
			kp=10, 
			spell=394229,
			renown={majorFactionId=2511, levelRequired=14},	 
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72326}, --искарское-мастерство
			itemId=201713, 
			waypoint={map=2024, x=0.139, y=0.5008}, -- Роккутук
			kp=10, 
			spell=394229,
			renown={majorFactionId=2511, levelRequired=24},	
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72296}, --дар-знания
			itemId=201713, 
			waypoint={map=2023, x=0.604, y=0.376}, -- Интендант Хусенг 
			kp=10, 
			spell=394229,
			renown={majorFactionId=2503, levelRequired=14},	
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72297}, --дар-тайн
			itemId=201713, 
			waypoint={map=2023, x=0.604, y=0.376}, -- Интендант Хусенг 
			kp=10, 
			spell=394229,
			renown={majorFactionId=2503, levelRequired=24},	
		}) --		
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75751}, 
			itemId=205350, --Ниффский блокнот
			waypoint={map=2133, x=0.564, y=0.556}, 
			kp=10, 
			spell=409559,
			renown={majorFactionId=2564, levelRequired=12},	
			currency={{id=2003, quantity=300}} 
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75840},
			itemId=205426, --Выменянные записи 
			waypoint={map=2133, x=0.58, y=0.538},
			kp=5, 
			spell=410041,
			itemRequirementsOR = {
				{ {id=204985, quantity=35} },
				{ {id=205188, quantity=25} }
			} 
		})
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75855},
			itemId=205437, --Выменянный журнал 
			waypoint={map=2133, x=0.58, y=0.538},
			kp=5, 
			spell=410042,	
			itemRequirementsOR = {
				{ {id=204985, quantity=90} },
				{ {id=205188, quantity=40} }
			}
		})
        p:AddEntry(HironCraftProfit_UniqueBook:New{
            questId  = {74928},
            itemId   = 204232,
            waypoint = { map = 2151, x = 0.37, y = 0.47 },
            kp       = 1,
			itemRequirements={{id=203414, quantity=1}},
            text     = L["204232"]
        })
	PT.DB.DF[2830] = p
end

    
    -- BLACKSMITHING (164)
    
do
    local p = HironCraftProfit_Profession:New(2822, 365677, nil)
		p.expansion = "DF"
        
        -- Instructor Quest
        
        p:AddEntry(HironCraftProfit_Instructor:New{
            questId  = {70233,70235,70234,70211},
            waypoint = { map=2112, x=0.37, y=0.471 },
			itemId	 = 198606,
            kp       = 3,
            text     = L["Instructor Quest"],
			professionSkill = {
				expansion = "DF",
				level     = 50,
			},
        })

        
        -- Consortium
        
        p:AddEntry(HironCraftProfit_Consortium:New{
            questId  = {66897,66517,66941,72398,77935,77936,75569,75148},
            waypoint = { map=2112, x=0.366, y=0.629 },
			itemId	 = 198606,
            kp       = 3,
            text     = L["Consortium Quest"]
        })

        
        -- Crafting Orders
        
        p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
            questId  = {70589},
			itemId = 198606,
            waypoint = { map=2112, x=0.354, y=0.588 },
            kp       = 3,
            text     = L["CraftOQ"]
        })

        
        -- Treatise (Inscription)
        
        p:AddEntry(HironCraftProfit_Treatise:New{
            questId = {74109},
            itemId  = 198454,
            kp      = 1,
            text    = L["IncWO"]
        })

        
        -- Expedition Drop
        
        p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
            questId = {66381},
			itemId  = 192131,
            kp      = 1,
            text    = L["Found on treasures DF"]
        })
        p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
            questId = {66382},
			itemId  = 192132,
            kp      = 1,
            text    = L["Found on treasures DF"]
        })
        
        -- RNG Mob Drops (Unique Treasures)
        
        p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{ 
			questId={70513}, 
			itemId=198966, 
			waypoint={map=2022,x=0.376,y=0.721}, 
			kp=1,
			text=L["198966"]
		})
        p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{ 
			questId={70512}, 
			itemId=198965, 
			waypoint={map=2022,x=0.4635,y=0.3726}, 
			kp=1,
			text=L["198965"]
		})

        
        -- Profession Master
        
        p:AddEntry(HironCraftProfit_ProfMaster:New{
            questId  = {70250},
            waypoint = { map=2022, x=0.4332, y=0.666 },
            kp       = 5,
            text     = L["70250"]
        })

        
        -- Dragon Isles Unique Treasures
        
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70230}, 
			itemId=198791, 
			waypoint={map=2022,x=0.564,y=0.195}, 
			kp=3,
			text = L["UNIQUE_TREASURE_70230_DESC"],	
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70246}, 
			itemId=201007, 
			waypoint={map=2022,x=0.22,y=0.87}, 
			kp=3,
			text    = L["UNIQUE_TREASURE_70246_DESC"],
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70312}, 
			itemId=201005, 
			waypoint={map=2022,x=0.655,y=0.257}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70296}, 
			itemId=201008, 
			waypoint={map=2022,x=0.355,y=0.643}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70310}, 
			itemId=201010, 
			waypoint={map=2022,x=0.345,y=0.671},
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70313}, 
			itemId=201004, 
			waypoint={map=2023,x=0.811,y=0.379}, 
			kp=3,
			text=L["InCave"] 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70353}, 
			itemId=201009, 
			waypoint={map=2023,x=0.509,y=0.665}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70314}, 
			itemId=201011, 
			waypoint={map=2024,x=0.531,y=0.653}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={70296}, 
			itemId=201006, 
			waypoint={map=2025,x=0.522,y=0.805}, 
			kp=3
		})

        
        -- Zaralek Cavern (2133)
        
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={76080}, 
			itemId=205988, 
			waypoint={map=2133,x=0.2753,y=0.4287}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={76079}, 
			itemId=205987, 
			waypoint={map=2133,x=0.4830,y=0.2195}, 
			kp=3
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={76078}, 
			itemId=205986, 
			waypoint={map=2133,x=0.5715,y=0.5464}, 
			kp=3 
		})

        
        -- Emerald Dream (2200)
        
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={78417}, 
			itemId=210464, 
			waypoint={map=2200,x=0.4983,y=0.6299}, 
			kp=3 
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={78418}, 
			itemId=210465, 
			waypoint={map=2200,x=0.3634,y=0.4679}, 
			kp=3
		})
        p:AddEntry(HironCraftProfit_UniqueTreasure:New{ 
			questId={78419}, 
			itemId=210466, 
			waypoint={map=2200,x=0.3729,y=0.2294}, 
			kp=3
		})

        
        -- Darkmoon Faire
        
        p:AddEntry(HironCraftProfit_DarkmoonQuest:New{
            questId  = {29508},
            waypoint = { map=407, x=0.51, y=0.818 },
            kp       = 1,
            text     = "DMF Blacksmithing Quest"
        })

        
        --Book
        
		
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71894}, 
			itemId=200972, --Пыльные  
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 100
			kp=10, 
			spell=393154,
			reputation = {factionId=2544, standingRequired=4},
			itemRequirements={{id=190456, quantity=100}} 
		}) --  
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71905}, 
			itemId=201268, --редкие
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 150
			kp=10, 
			spell=393226,
			reputation = {factionId=2544, standingRequired=6},		
			itemRequirements={{id=190456, quantity=150}} 
		}) -- 
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71916}, 
			itemId=201279, --Древние  
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 200
			kp=10, 
			spell=393227,
			reputation = {factionId=2544, standingRequired=7},	
			itemRequirements={{id=190456, quantity=200}} 
		})
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72312}, --дар-знания
			itemId=201708, 
			waypoint={map=2023, x=0.604, y=0.376}, -- Интендант Хусенг 
			kp=5, 
			spell=394224,
			renown={majorFactionId=2503, levelRequired=14},	
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72315}, --дар-тайн
			itemId=201708, 
			waypoint={map=2023, x=0.604, y=0.376}, -- Интендант Хусенг 
			kp=5, 
			spell=394224,
			renown={majorFactionId=2503, levelRequired=24},	
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72329}, --Начинаем с малого
			itemId=201708, 
			waypoint={map=2112, x=0.366, y=0.628}, --Дофенос
			kp=5, 
			spell=394224,
			renown={majorFactionId=2510, levelRequired=14},	
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={70909}, --Как стать лучшим
			itemId=201708, 
			waypoint={map=2112, x=0.366, y=0.628}, --Дофенос
			kp=5, 
			spell=394224,
			renown={majorFactionId=2510, levelRequired=24},	
		}) --		
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75755}, 
			itemId=205352, --Ниффский блокнот
			waypoint={map=2133, x=0.564, y=0.556}, 
			kp=10, 
			spell=409566,
			renown={majorFactionId=2564, levelRequired=12},	
			currency={{id=2003, quantity=300}} 
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75846},
			itemId=205428, --Выменянные записи 
			waypoint={map=2133, x=0.58, y=0.538},
			kp=5, 
			spell=410053,
			itemRequirementsOR = {
				{ {id=204985, quantity=35} },
				{ {id=205188, quantity=25} }
			} 
		})
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75849},
			itemId=205439, --Выменянный журнал 
			waypoint={map=2133, x=0.58, y=0.538},
			kp=5, 
			spell=410054,	
			itemRequirementsOR = {
				{ {id=204985, quantity=90} },
				{ {id=205188, quantity=40} }
			}
		}) 		
		
        p:AddEntry(HironCraftProfit_UniqueBook:New{
            questId  = {74931},
            itemId   = 204230,
            waypoint = { map=2151, x=0.802, y=0.596 },
            kp       = 1,
			itemRequirements={{id=203408, quantity=1}},
            text     = L["204230"]
        })
	PT.DB.DF[2822] = p
end

    
    -- JEWELCRAFTING (++)
    
do
    local p = HironCraftProfit_Profession:New(2829, 366250, nil)
		p.expansion = "DF"
        
        -- Instructor (Trainer) Quest
        
        p:AddEntry(HironCraftProfit_Instructor:New{
            --questId  = {70251, 70253, 70252, 70199},
            questId  = {70563, 70562, 70564, 70565},
            waypoint = { map=2112, x=0.382, y=0.484 },
            kp       = 3,
			itemId   = 198612,
            text     = L["Instructor Quest"],
			professionSkill = {
				expansion = "DF",
				level     = 50,
			},
        })

        
        -- Consortium
        
        p:AddEntry(HironCraftProfit_Consortium:New{
            --questId  = {66918, 66516, 66519, 72407, 77835, 77836},
            questId  = {77892, 66950, 66949, 75362, 75602, 72428, 66516, 77912},
            waypoint = { map=2112, x=0.366, y=0.629 },
			itemId   = 198612,
            kp       = 3,
            text     = L["Consortium Quest"]
        })

        
        -- Crafting Orders
        
        p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
            questId  = {70593},
			itemId = 198612,
            waypoint = { map=2112, x=0.354, y=0.588 },
            kp       = 3,
            text     = L["CraftOQ"]
        })

        
        -- Treatise
        
        p:AddEntry(HironCraftProfit_Treatise:New{
            questId = {74112},
            itemId  = 194703,
            kp      = 1,
            text    = L["IncWO"]
        })

        
        -- Expedition Drops
        
        p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
            questId = {66389},
			itemId=193907,
            kp      = 1,
            text    = L["Found on treasures DF"]
        })
        p:AddEntry(HironCraftProfit_WeeklyTreasure:New{
            questId = {66388},
			itemId=193909,
            kp      = 1,
            text    = L["Found on treasures DF"]
        })
        p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
            questId = {70521},
            itemId  = 198974,
            kp      = 1,
			waypoint = {map=2025, x=0.456, y=0.526},
            text    = "Mobs: Rebel Bruiser"
        })
        p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
            questId = {70520},
            itemId  = 198973,
            kp      = 1,
			waypoint = {map=2022, x=0.516, y=0.332},
            text    = "Mobs: Crushing Elemental"
        })
        
        -- (Unique Treasures)
        


		-- Painter's Pretty Jewel
		p:AddEntry(HironCraftProfit_UniqueTreasure:New{
			questId = {70261},
			itemId  = 198656,
			waypoint = { map=2025, x=0.569, y=0.437 },
			kp = 3
		})

		-- Fragmented Key (Forgotten Jewelry Box)
		p:AddEntry(HironCraftProfit_UniqueTreasure:New{
			questId = {70263},
			itemId  = 198660,
			waypoint = { map=2023, x=0.618, y=0.130 },
			kp = 3
		})

		-- Crystalline Overgrowth
		p:AddEntry(HironCraftProfit_UniqueTreasure:New{
			questId = {70277},
			itemId  = 198664,
			waypoint = { map=2024, x=0.451, y=0.612 },
			kp = 3
		})

		-- Lofty Malygite
		p:AddEntry(HironCraftProfit_UniqueTreasure:New{
			questId = {70282},
			itemId  = 198670,
			waypoint = { map=2023, x=0.2507, y=0.3489 },
			kp = 3
		})

		-- Alexstraszite Cluster
		p:AddEntry(HironCraftProfit_UniqueTreasure:New{
			questId = {70285},
			itemId  = 198682,
			waypoint = { map=2025, x=0.599, y=0.651 },
			kp = 3
		})

		-- Closely Guarded Shiny
		p:AddEntry(HironCraftProfit_UniqueTreasure:New{
			questId = {70292},
			itemId  = 198687,
			waypoint = { map=2022, x=0.504, y=0.451 },
			kp = 3
		})

		-- Harmonic Crystal Harmonizer (Harmonic Chest)
		p:AddEntry(HironCraftProfit_UniqueTreasure:New{
			questId = {70271},
			itemId  = 201016,
			waypoint = { map=2024, x=0.446, y=0.615 },
			kp = 3,
			text     = L["UNIQUE_TREASURE_SILVER_KEY_CRYSTALS"]
		})

		-- Igneous Gem
		p:AddEntry(HironCraftProfit_UniqueTreasure:New{
			questId = {70273},
			itemId  = 201017,
			waypoint = { map=2022, x=0.340, y=0.637 },
			kp = 3,
			text     = L["UNIQUE_TREASURE_MAGMA_CRYSTALS"],
		})

		-- Snubbed Snail Shells
		p:AddEntry(HironCraftProfit_UniqueTreasure:New{
			questId = {75652},
			itemId  = 205214,
			waypoint = { map=2133, x=0.404, y=0.807 },
			kp = 3
		})

		-- Gently Jostled Jewels
		p:AddEntry(HironCraftProfit_UniqueTreasure:New{
			questId = {75653},
			itemId  = 205216,
			waypoint = { map=2133, x=0.345, y=0.455 },
			kp = 3
		})

		-- Broken Barter Boulder
		p:AddEntry(HironCraftProfit_UniqueTreasure:New{
			questId = {75654},
			itemId  = 205219,
			waypoint = { map=2133, x=0.545, y=0.325 },
			kp = 3
		})

		-- Petrified Hope
		p:AddEntry(HironCraftProfit_UniqueTreasure:New{
			questId = {78282},
			itemId  = 210200,
			waypoint = { map=2200, x=0.332, y=0.466 },
			kp = 3
		})

		-- Handful of Tiny Pebbles (Unpolished Blemish)
		p:AddEntry(HironCraftProfit_UniqueTreasure:New{
			questId = {78283},
			itemId  = 210201,
			waypoint = { map=2200, x=0.435, y=0.334 },
			kp = 3
		})

		-- Coalesced Dreamstone
		p:AddEntry(HironCraftProfit_UniqueTreasure:New{
			questId = {78285},
			itemId  = 210202,
			waypoint = { map=2200, x=0.589, y=0.539 },
			kp = 3
		})

        
        -- Profession Master
        
        p:AddEntry(HironCraftProfit_ProfMaster:New{
            questId  = {70255},
            waypoint = { map=2024, x=0.462, y=0.408 },
            kp       = 5,
            text     = L["70255"]
        })

        
        -- Darkmoon Faire
        
        p:AddEntry(HironCraftProfit_DarkmoonQuest:New{
            questId  = {29515},
            waypoint = { map=407, x=0.531, y=0.758 },
            kp       = 1,
            text     = "DMF Jewelcrafting Quest"
        })
        --Book

		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71899}, 
			itemId=200978, --Пыльные  
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 100
			kp=10, 
			spell=393159,
			reputation = {factionId=2544, standingRequired=4},
			itemRequirements={{id=190456, quantity=100}} 
		}) --  
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71910}, 
			itemId=201274, --редкие
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 150
			kp=10, 
			spell=393236,
			reputation = {factionId=2544, standingRequired=6},		
			itemRequirements={{id=190456, quantity=150}} 
		}) -- 
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71921}, 
			itemId=201285, --Древние  
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 200
			kp=10, 
			spell=393237,
			reputation = {factionId=2544, standingRequired=7},	
			itemRequirements={{id=190456, quantity=200}} 
		})
		
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72320}, --знания-искарских-мастеров
			itemId=201712, 
			waypoint={map=2024, x=0.139, y=0.5008}, -- Роккутук 
			kp=5, 
			spell=394228,
			renown={majorFactionId=2511, levelRequired=14},	 
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72325}, --искарское-мастерство
			itemId=201712, 
			waypoint={map=2024, x=0.139, y=0.5008}, -- Роккутук
			kp=5, 
			spell=394228,
			renown={majorFactionId=2511, levelRequired=24},	
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72301}, --Профессиональные знания экспедиции
			itemId=201712, 
			waypoint={map=2022, x=0.4694, y=0.829}, -- Босс Магор
			kp=5, 
			spell=394228,
			renown={majorFactionId=2507, levelRequired=14},	
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72306}, --Профессиональные знания экспедиции
			itemId=201712, 
			waypoint={map=2022, x=0.4694, y=0.829}, -- Босс Магор
			kp=5, 
			spell=394228,
			renown={majorFactionId=2507, levelRequired=24},	
		}) --	
		
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75754}, 
			itemId=205348, --Ниффский блокнот
			waypoint={map=2133, x=0.564, y=0.556}, 
			kp=10, 
			spell=409563,
			renown={majorFactionId=2564, levelRequired=12},	
			currency={{id=2003, quantity=300}} 
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75841},
			itemId=205424, --Выменянные записи 
			waypoint={map=2133, x=0.58, y=0.538},
			kp=5, 
			spell=410043,
			itemRequirementsOR = {
				{ {id=204985, quantity=35} },
				{ {id=205188, quantity=25} }
			} 
		})
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75854},
			itemId=205435, --Выменянный журнал 
			waypoint={map=2133, x=0.58, y=0.538},
			kp=5, 
			spell=410044,	
			itemRequirementsOR = {
				{ {id=204985, quantity=90} },
				{ {id=205188, quantity=40} }
			}
		}) 
        
        -- DF Book / Rare Knowledge
        
        p:AddEntry(HironCraftProfit_UniqueBook:New{
            questId  = {74932},
            itemId   = 204222,
            waypoint = { map=2151, x=0.802, y=0.596 },
            kp       = 1,
			itemRequirements={{id=203413, quantity=1}},
            text     = L["204222"]
        })
	PT.DB.DF[2829] = p
end

    
    -- INSCRIPTION (++)
    
do
    local p = HironCraftProfit_Profession:New(2828, 366251, nil)
		p.expansion = "DF"
        
        -- Instructor (Trainer) Quest
        
        p:AddEntry(HironCraftProfit_Instructor:New{
            --questId  = {70256, 70257, 70255, 70258},
			questId  = {70561, 70559, 70560, 70558},
            waypoint = { map=2112, x=0.394, y=0.736 },
			itemId   = 198607,
            kp       = 3,
            text     = L["Instructor Quest"],
			professionSkill = {
				expansion = "DF",
				level     = 50,
			},
        })

        
        -- Consortium
        
        p:AddEntry(HironCraftProfit_Consortium:New{
            --questId  = {66933, 66517, 66520, 72410, 77837, 77838},
			questId  = {77914, 77889, 72438, 75573, 66944, 66945, 75149, 66943},
            waypoint = { map=2112, x=0.366, y=0.629 },
			itemId   = 198607,
            kp       = 3,
            text     = L["Consortium Quest"]
        })

        
        -- Crafting Orders
        
        p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
            questId  = {70592},
			itemId   = 198607,
            waypoint = { map=2112, x=0.354, y=0.588 },
            kp       = 3,
            text     = L["CraftOQ"]
        })

        
        -- Treatise
        
        p:AddEntry(HironCraftProfit_Treatise:New{
            questId = {74105},
            itemId  = 194699,
            kp      = 1,
            text    = L["IncWO"]
        })

        
        -- Expedition Drops
        
        p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
            questId = {66375},
			itemId  = 193904,
            kp      = 1,
            text    = L["Found on treasures DF"]
        })
        p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
            questId = {66376},
			itemId  = 193905,
            kp      = 1,
            text    = L["Found on treasures DF"]
        })
		
		p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
            questId = {70518},
            itemId  = 198971,
            kp      = 1,
			waypoint = {map=2022, x=0.366, y=0.692}, 
            text    = "Mobs: Qalashi Necksnapper"
        })
        p:AddEntry(HironCraftProfit_WeeklyQuestItem:New{
            questId = {70519},
            itemId  = 198972,
            kp      = 1,
			waypoint = {map=2024, x=0.664, y=0.594},
            text    = "Mobs: Arcane Manipulators"
        })
        
        -- Unique Treasures
        
		-- Forgetful Apprentice's Tome
		p:AddEntry(HironCraftProfit_UniqueTreasure:New{
			questId  = {70264},
			itemId   = 198659,
			waypoint = { map=2025, x=0.563, y=0.412 },
			kp       = 3,
			--text     = L["FORGETFUL_APPRENTICE_TOME"],
		})

		-- How to Train Your Whelpling
		p:AddEntry(HironCraftProfit_UniqueTreasure:New{
			questId  = {70281},
			itemId   = 198669,
			waypoint = { map=2112, x=0.137, y=0.630 },
			kp       = 3,
		})

		-- Frosted Parchment
		p:AddEntry(HironCraftProfit_UniqueTreasure:New{
			questId  = {70293},
			itemId   = 198686,
			waypoint = { map=2024, x=0.436, y=0.308 },
			kp       = 3,
		})

		-- Dusty Darkmoon Card
		p:AddEntry(HironCraftProfit_UniqueTreasure:New{
			questId  = {70297},
			itemId   = 198693,
			waypoint = { map=2024, x=0.462, y=0.240 },
			kp       = 3,
		})

		-- Language Reference Sheet
		p:AddEntry(HironCraftProfit_UniqueTreasure:New{
			questId  = {70307},
			itemId   = 198703,
			waypoint = { map=2023, x=0.857, y=0.252 },
			kp       = 3,
		})

		-- Pulsing Earth Rune
		p:AddEntry(HironCraftProfit_UniqueTreasure:New{
			questId  = {70306},
			itemId   = 198704,
			waypoint = { map=2022, x=0.678, y=0.579 },
			kp       = 3,
		})

		-- Counterfeit Darkmoon Deck
		p:AddEntry(HironCraftProfit_UniqueTreasure:New{
			questId  = {70287},
			itemId   = 201015,
			waypoint = { map=2025, x=0.5608, y=0.4097 },
			kp       = 3,
			text     = L["COUNTERFEIT_DARKMOON_DECK"],
		})

		
		-- ZARALEK CAVERN (2133)
		

		-- Intricate Zaqali Runes
		p:AddEntry(HironCraftProfit_UniqueTreasure:New{
			questId  = {76117},
			itemId   = 206031,
			waypoint = { map=2133, x=0.367, y=0.463 },
			kp       = 3,
		})

		-- Hissing Rune Draft
		p:AddEntry(HironCraftProfit_UniqueTreasure:New{
			questId  = {76120},
			itemId   = 206034,
			waypoint = { map=2133, x=0.530, y=0.743 },
			kp       = 3,
		})

		-- Ancient Research
		p:AddEntry(HironCraftProfit_UniqueTreasure:New{
			questId  = {76121},
			itemId   = 206035,
			waypoint = { map=2133, x=0.546, y=0.202 },
			kp       = 3,
			text=L["206035"]
		})

		
		-- EMERALD DREAM (2200)
		

		-- Winnie's Notes on Flora and Fauna
		p:AddEntry(HironCraftProfit_UniqueTreasure:New{
			questId  = {78411},
			itemId   = 210458,
			waypoint = { map=2200, x=0.556, y=0.275 },
			kp       = 3,
		})

		-- Grove Keeper's Pillar
		p:AddEntry(HironCraftProfit_UniqueTreasure:New{
			questId  = {78412},
			itemId   = 210459,
			waypoint = { map=2200, x=0.635, y=0.715 },
			kp       = 3,
		})

		-- Rune of the Darkbound Elementalists
		p:AddEntry(HironCraftProfit_UniqueTreasure:New{
			questId  = {78413},
			itemId   = 210460,
			waypoint = { map=2200, x=0.360, y=0.467 },
			kp       = 3,
		})

        
        -- Profession Master
        
        p:AddEntry(HironCraftProfit_ProfMaster:New{
            questId  = {70254},
            waypoint = { map=2024, x=0.402, y=0.644 },
            kp       = 10,
            text     = L["70254"]
        })

        
        -- Darkmoon Faire
        
        p:AddEntry(HironCraftProfit_DarkmoonQuest:New{
            questId={29515},
            waypoint={map=407,x=0.531,y=0.758},
            kp=1,
            text="DMF Inscription Quest"
        })

        
        -- DF Book (Rare Knowledge)
        
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71898}, 
			itemId=200973, --Пыльные  
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 100
			kp=10, 
			spell=393158,
			reputation = {factionId=2544, standingRequired=4},
			itemRequirements={{id=190456, quantity=100}} 
		}) --  
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71909}, 
			itemId=201269, --редкие
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 150
			kp=10, 
			spell=393234,
			reputation = {factionId=2544, standingRequired=6},		
			itemRequirements={{id=190456, quantity=150}} 
		}) -- 
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={71920}, 
			itemId=201280, --Древние  
			waypoint={map=2112, x=0.356, y=0.592}, -- Рабул 200
			kp=10, 
			spell=393235,
			reputation = {factionId=2544, standingRequired=7},	
			itemRequirements={{id=190456, quantity=200}} 
		})
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72294}, --Профессиональные знания экспедиции
			itemId=201711, 
			waypoint={map=2022, x=0.4694, y=0.829}, -- Босс Магор
			kp=5, 
			spell=394227,
			renown={majorFactionId=2507, levelRequired=14},	
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72295}, --Профессиональные знания экспедиции
			itemId=201711, 
			waypoint={map=2022, x=0.4694, y=0.829}, -- Босс Магор
			kp=5, 
			spell=394227,
			renown={majorFactionId=2507, levelRequired=24},	
		}) --		

		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72331}, --Начинаем с малого
			itemId=201711, 
			waypoint={map=2112, x=0.366, y=0.628}, --Дофенос
			kp=5, 
			spell=394227,
			renown={majorFactionId=2510, levelRequired=14},	
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={72334}, --Как стать лучшим
			itemId=201711, 
			waypoint={map=2112, x=0.366, y=0.628}, --Дофенос
			kp=5, 
			spell=394227,
			renown={majorFactionId=2510, levelRequired=24},	
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75761}, 
			itemId=205354, --Ниффский блокнот
			waypoint={map=2133, x=0.564, y=0.556}, 
			kp=10, 
			spell=409575,
			renown={majorFactionId=2564, levelRequired=12},	
			currency={{id=2003, quantity=300}} 
		}) --
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75842},
			itemId=205430, --Выменянные записи 
			waypoint={map=2133, x=0.58, y=0.538},
			kp=5, 
			spell=410045,
			itemRequirementsOR = {
				{ {id=204985, quantity=35} },
				{ {id=205188, quantity=25} }
			} 
		})
		p:AddEntry(HironCraftProfit_UniqueBook:New{
			questId={75853},
			itemId=205441, --Выменянный журнал 
			waypoint={map=2133, x=0.58, y=0.538},
			kp=5, 
			spell=410046,	
			itemRequirementsOR = {
				{ {id=204985, quantity=90} },
				{ {id=205188, quantity=40} }
			}
		}) 
						
        p:AddEntry(HironCraftProfit_UniqueBook:New{
            questId={74931},
            itemId=204229,
            waypoint={map=2151,x=0.492,y=0.418},
            kp=1,
			itemRequirements={{id=203412, quantity=1}},
            text=L["204229"]
        })
    PT.DB.DF[2828] = p
end


