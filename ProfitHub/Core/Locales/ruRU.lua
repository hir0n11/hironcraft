--ruRU.lua
local PT = HironCraftProfit
if not PT then return end

PT.L = PT.L or {}

PT.L_enUS = PT.L_enUS or {}
if not next(PT.L_enUS) then for k, v in pairs(PT.L) do PT.L_enUS[k] = v end end
PT.L_ruRU = PT.L_ruRU or {}
local L = PT.L_ruRU

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
L["TIME_MIN"]   = "%dм"
L["TIME_HOUR"]  = "%dч %dм"
L["TIME_DAY"]   = "%dд %dч"
L["NO_CONCENTRATION_AVAILABLE"] = "Эта профессия не использует концентрацию"
-- ConfirmButtons
--infopanel(settings)
L["Width"] 				 = "Ширина:"
L["Height"] 			 = "Высота:"
L["+"] 					 = "+"
L["-"] 					 = "-"
--settings
L["Settings_Title"]			 = "Настройки"
L["Settings_SaveMode"] = "Сохранение настроек"
L["Settings_SaveCharacter"] = "Сохранять для персонажа"
L["Settings_SaveAccount"] = "Сохранять для аккаунта"
L["Settings_Concentration"]  = "Концентрация"
L["Settings_SkinningCheck"]  = "Шкуропроверятель"
L["Settings_SkinningTargets"] = "Настроить цели:"
L["Settings_SkinningIconSize"] = "Размер иконки Шкуропроверятеля:"
L["Settings_ProfWindow"] = "Очки знаний"
L["Settings_LockWindows"] = "Закрепить все окна (запретить перемещение)"
L["Default"] = "По умолчанию"
L["Settings_Transparency"] = "Прозрачность"
L["Settings_HideInCombat"] = "Скрывать в бою"
L["Settings_HideInInstance"] = "Скрывать в инстах"


L["Settings_MapPins"] = "Дополнительные модули:"
L["Settings_Enable"] = "Метки на карте"
L["Settings_FirstCraft"] = "Значки первого крафта"
L["Settings_GoldDepositor"] = "Депозит золота"
L["DB_Selector_Title"]    = "База данных"
L["CONCENTRATION_MODE"]   = "Режим концентрации"
L["DB_Rotation_LMB"]      = "ЛКМ: %s"
L["DB_Rotation_RMB"]      = "ПКМ: выбор дополнения"
L["UI_SCALE_ALT_WHEEL"] = "Alt + колесо мыши — изменить масштаб"
L["UI_SCALE_ALT_MMB"]   = "Alt + средняя кнопка мыши — сбросить масштаб"
L["CONC_COMPACT_TITLE"] = "Компактный режим"
L["CONC_COMPACT_ON"]    = "Вкл — только иконка со значением"
L["CONC_COMPACT_OFF"]   = "Выкл — полная полоска"
L["CONC_COMPACT_HINT"]  = "Клик — переключить"
--Profession.lua
L["Not loaded yet"] = "Не загружено"
L["Found on treasures"] = "Находится в кучках или сундуках"
L["Found on treasures DF"] = "Находится в кучках или сундуках\nприкупи экспедиционную лопату"
L["ItemID"] = "ID предмета"
L["item not loaded"] = "Предмет не загружен"
L["Instructor Quest"] = "Квест инструктора"
L["Consortium Quest"] = "Квест консорциума"
L["Unknown"] = "Неизвестно"
--core\SkinningCheck.lua
L["SKINNING_NOT_LEARNED"] = "Снятие шкур не изучено"
L["SKINNING_ALL_DONE"]    = "Все редкие цели для снятия шкур выполнены"
L["SKINNING_AVAILABLE"]  = "Доступны цели для снятия шкур:"
L["SKINNING_LURE"]        = "Наживка"
L["SKINNING_CRAFT_FROM"]  = "Создаётся из"
L["SKINNING_LOCATION"]    = "Локация"
L["SKINNING_TARGET"]      = "Цель"
-- Targets
L["cobra_skin"]  = "Кожа обсидиановой кобры"
L["slatefang"]   = "Превосходный клык"
L["majestic_claw"] = "Majestic Claw"
L["majestic_fin"]  = "Majestic Fin"
-- Minimap / LDB
L["LDB_TITLE"]        = "HironCraft"
L["LDB_LEFT_CLICK"]   = "ЛКМ — настройки"
L["LDB_RIGHT_CLICK"]  = "ПКМ — обзор персонажей"
-- SkinningCheck UI
L["SKINNING_TITLE"]        = "Шкуропроверятель"
L["SKINNING_LURE_RMB_HINT"] = "ПКМ — отправить недостающие реагенты приманок в Закуп"
L["SKINNING_LURE_LIST"]     = "Приманки — реагенты"
L["SKINNING_LURE_SHOP_NONE"] = "На все приманки реагентов хватает."
L["SKINNING_LURE_SHOP_NA"]  = "Модуль Закуп недоступен."
L["SKINNING_HOW_TO_GET"]   = ""
L["SKINNING_GUIDE"] = "Руководство:"
L["SKINNING_ROW_HINT"] = "ЛКМ — поставить метку\nПКМ — использовать приманку\nКолесо — создать приманку\nShift + колесо — открыть профу\n\nПервое число — готовые приманки в сумках.\nВ скобках — сколько можно скрафтить."
L["SKINNING_LURE_NOT_FOUND"] = "Приманка не найдена в сумках: %s"
L["SKINNING_LURE_USE_FAILED"] = "Не удалось использовать приманку: %s"
L["SKINNING_CRAFT_NO_MATS"] = "Недостаточно материалов для создания: %s"
L["SKINNING_RECIPE_NOT_FOUND"] = "Рецепт приманки не найден: %s"
-- Skinning targets window
L["SKINNING_TARGETS_TITLE"] = "Шкуропроверятель — отслеживаемые цели"
--UI.lua
L["PROF_WINDOW_TITLE"] = "Очки знаний"
L["CATCHUP_REQUIREMENTS"] = "Требования для Catch-Up:"
L["REQUIREMENTS"] = "Требования:"
L["REQUIRES_PROFESSION_SKILL_25"] = "Требуется навык профессии 25"
L["PROFESSION_SKILL"] = "Навык профессии"
L["CATCHUP_SOURCE_NPC_ORDERS"] = "Попадаются в крафт-заказах от NPC"
L["FILTER_TOOLTIP_TITLE"] = "Фильтры"
L["FILTER_TOOLTIP_HINT"]  = "Настройка отображаемых элементов"

L["FILTER_PRESETS"] = "Пресеты"
L["FILTER_PRESET_ALL"] = "Всё"
L["FILTER_PRESET_ONLY_MAP"] = "Текущая зона"
L["FILTER_PRESET_ONLY_WEEKLY"] = "Только еженедельные"

L["FILTER_SHOW"] = "Показывать:"
L["FILTER_UNIQUE_TREASURE"] = "Уникальные сокровища"
L["FILTER_UNIQUE_BOOK"] = "Уникальные книги"
L["FILTER_WEEKLY"] = "Еженедельные"
L["FILTER_TREATISE"] = "Сокровища"
L["FILTER_SHOW_ZEAL"] = "Пыл ремесленника"
--welcome.lua
L["WELCOME_TEXT"] =
"Добро пожаловать в |cffb19cd9HironCraft|r!\n\n" ..
"Аддон сделан в первую очередь для голдфарма, но добавляет и небольшие удобства для остальных игроков.\n\n" ..
"Он состоит из ядра(базовый набор функций) и модулей(дополнительные возможности) — модули можно ставить отдельно, по своему вкусу."
















L["WELCOME_OPEN_SETTINGS"] = "Открыть настройки"

L["Midnight Herbalism"] = "Полуночное травничество"

L["CLICK_TO_TOGGLE_PROFESSIONS"] = "ЛКМ — открыть/закрыть окно профессий"
L["Found on treasures MN"] = "Находится в сундуках с сокровищами\nв локациях Миднайт."
L["OR"] = "ИЛИ"
--df.lua
L["BOOMTHYR_ROCKET_NOTE"] =
"В здании справа от входа лежит записка.\n" ..
"После её прочтения на вас появится 10-минутный бафф —\n" ..
"«Список деталей для ракеты \"Бумтир\"».\n\n" ..
"Затем, собрав три предмета в доме по координатам /way 57.5, 44.3:\n" ..
"• Взрывоопасные испарения\n" ..
"• Аэрокосмический драконит\n" ..
"• Прочный кристалл\n\n" ..
"и Пепел в доме с ракетой,\n" ..
"вы сможете подобрать ракету «Бумтир».\n\n" ..
"Если ракета не активна, помогает перезаход в игру или команда /reload."
L["GlimmerOfOrder"] =
"У вас должно быть вложено 10 очков знаний в ветку Проницательность синих драконов, а также открыта подспециализация Извлечение сущности.\n\n" ..
"(при этом у вас может быть 0/40 очков знаний в Извлечение сущности — это всё равно будет работать).\n\n" ..
"Создайте питомца Слияние мудрости или получите его через публичный заказ — НЕ добавляйте питомца в коллекцию.\n\n" ..
"Распылите созданную Слияние мудрости, чтобы получить Проблеск порядка.\n\n" ..
"Предмет выпадает случайно и не гарантирован, поэтому может потребоваться распылить несколько Слияний мудрости.\n\n" ..
"Распылить Слияние мудрости в клетке нельзя — распыляется только созданный предмет."
L["PrimalStorms_Earth"] = "убивай мобов в Буре стихий (Земля)"
L["PrimalStorms_Air"]   = "убивай мобов в Буре стихий (Воздух)"
L["PrimalStorms_Frost"] = "убивай мобов в Буре стихий (Лёд)"
L["PrimalStorms_Fire"]  = "убивай мобов в Буре стихий (Огонь)"
L["FORGETFUL_APPRENTICE_TOME"] =
"Для профессии Начертание.\n" ..
"Нажмите на Таинственный символ (книгу), чтобы получить бафф «Установление связей».\n" ..
"Выйдите из здания и перейдите на другую сторону моста.\n" ..
"В конце вы найдёте Проявление замешательства — убейте его и заберите Ключ дешифровки.\n" ..
"Вернитесь к книге и нажмите на неё снова, чтобы получить «Книгу забывчивого ученика».\n\n" ..
"/way 47.1 40.07 — Таинственный символ\n" ..
"/way 49.84 40.31 — Проявление замешательства"

L["COUNTERFEIT_DARKMOON_DECK"] =
"Не отмечено на миникарте.\n" ..
"Фиолетовый NPC по имени Сиеннагоса.\n" ..
"Поговорите с ней и предложите помощь в восстановлении колоды Новолуния.\n" ..
"Под ней лежат 8 карт — нажмите их в правильном порядке:\n" ..
"Туз -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8.\n" ..
"После этого поговорите с ней ещё раз, чтобы получить очки знаний."
L["UNIQUE_TREASURE_SILVER_KEY_CRYSTALS"] =
"Внутри пруда вы найдёте большой сундук.\n" ..
"Рядом с ним лежит серебряный ключ.\n" ..
"При использовании ключа вы получите бафф.\n" ..
"С этим баффом нужно активировать 3 кристалла поблизости.\n\n" ..
"Координаты кристаллов:\n" ..
"44.71, 61.99\n" ..
"44.68, 60.20\n" ..
"44.18, 61.98\n" ..
"И вы сможете открыть сундук"
L["UNIQUE_TREASURE_MAGMA_CRYSTALS"] =
"Чтобы открыть предмет, активируйте 3 разных кристалла на небольших островках в магме.\n" ..
"Рядом прыгает большая лавовая лягушка — убейте её перед началом.\n" ..
"После активации первого кристалла у вас будет ограниченное время, чтобы активировать остальные два.\n" ..
"Каждый кристалл направляет лавовый луч в кучку земли.\n" ..
"Активация всех трёх лучей откроет предмет."
L["UNIQUE_TREASURE_70230_DESC"] =
"Тонкая башня сзади, не помещение без крыши.\n" ..
"Создайте «Раскалённый первичный сплав» рядом с Тёмной кузней.\n" ..
"После этого предмет станет доступен для добычи в чане с шлаком."
L["UNIQUE_TREASURE_70246_DESC"] =
"Победите 4 щита, окружающие меч.\nПосле победы через 2–3 секунды нажмите на пьедестал.\nЕсли предмет не появился в инвентаре сразу — перезайдите в игру и заберите его с почты."

--Customization

L["DEFAULT"] = "По умолчанию"
L["Customization"] = "Кастомизация"

L["Customization_Title"] = "Кастомизация"
L["Customization_Concentration"] = "Концентрация"
L["Customization_ProfessionsWindow"] = "Окно очков знаний"

L["Customization_BarColor"] = "Цвет полосы"
L["Customization_TimerColor"] = "Цвет текста"
L["Customization_DividerColor"] = "Цвет разделителя"
L["Customization_BorderColor"] = "Цвет рамки полосы"
L["Customization_IconBorderColor"] = "Цвет рамки иконки"
L["Customization_BackgroundColor"] = "Цвет фона"
L["Customization_Font"] = "Шрифт"
L["Customization_TimerFontSize"] = "Размер шрифта таймера"
L["Customization_ProfFontSize"] = "Размер шрифта"

L["Customization_Prof_Background"] = "Фон"
L["Customization_Prof_Border"] = "Рамка окна"
L["Customization_Prof_Header"] = "Заголовок профессии"
L["Customization_Prof_FontColor"] = "Цвет текста"

L["Customization_ResetDefault"] = "Сбросить на цвет по умолчанию"
-- Account Overview column tooltips
L["AO_SCALE_TIP"] = "Alt + колесо — изменение масштаба\nAlt + клик колёсиком — сброс"
L["AO_TITLE"] = "Обзор персонажей"
L["AO_HDR_CHAR"]   = "Персонаж"
L["AO_HDR_C_DF"]   = "Конц DF"
L["AO_HDR_C_TWW"]  = "Конц TWW"
L["AO_HDR_C_MID"]  = "Конц MN"
L["AO_HDR_ZEAL"]   = "Пыл"
L["AO_TIP_ZEAL"]   = "Пыл ремесленника по активным профессиям (Midnight)"
L["AO_CONC_NOTIFY_ON"]    = "Уведомление включено"
L["AO_CONC_NOTIFY_OFF"]   = "Уведомление отключено"
L["AO_CONC_NOTIFY_CLICK"] = "Нажмите для переключения"
L["AO_CONC_NOTIFY_DRAG"] = "Перетащите для перемещения"
L["AO_CONC_NOTIFY_CLICK_OPEN"] = "Нажмите, чтобы открыть обзор аккаунта"
L["AO_HDR_KP_DF"]  = "Знания DF"
L["AO_HDR_KP_TWW"] = "Знания TWW"
L["AO_HDR_KP_MID"] = "Знания MN"

L["AO_HDR_SKIN"]   = "Шкуры"
L["AO_HDR_DUNDUN"] = "Дандан"
L["AO_TIP_DUNDUN"] = "Получено за неделю / недельный максимум (текущее количество)."
L["AO_DUNDUN_EARNED"] = "Получено за неделю"
L["AO_DUNDUN_MAX"] = "Недельный максимум"
L["AO_DUNDUN_CURRENT"] = "Текущее количество"

L["AO_HDR_TW"]     = "TimeWalk"

L["AO_TIP_CHAR"]   = "Имя персонажа и игровой мир"

L["AO_TIP_C_DF"]   = "Концентрация профессий\n(Dragonflight)"
L["AO_TIP_C_TWW"]  = "Концентрация профессий\n(The War Within)"
L["AO_TIP_C_MID"]  = "Концентрация профессий\n(Midnight)"

L["AO_TIP_KP_DF"]  = "Еженедельные активности знаний профессий\n(Dragonflight)"
L["AO_TIP_KP_TWW"] = "Еженедельные активности знаний профессий\n(The War Within)"
L["AO_TIP_KP_MID"] = "Еженедельные активности знаний профессий\n(Midnight)"

L["AO_TIP_SKIN"]   = "Ежедневный прогресс снятия шкур"
L["AO_TIP_TW"]     = "Статус выполнения квеста путешествия во времени"
L["AO_TIP_DMF"]     = "Профквесты Ярмарки Новолуния"
L["AO_DMF_QUEST_DONE"]     = "Квест выполнен"
L["AO_DMF_QUEST_NOT_DONE"] = "Квест не выполнен"
L["AO_KP_TITLE"]     = "Еженедельные знания"
L["AO_KP_TRAINER"]   = "Недельный квест"
L["AO_KP_TREASURE"]  = "Сокровище"
L["AO_KP_TREATISE"]  = "Трактат"
L["AO_HDR_PROF_EQUIP"] = "Эквип проф"
L["AO_TIP_PROF_EQUIP"] = "Надетые профессиональные предметы"
L["AO_FILTER_RESET_ORDER"] = "Сбросить порядок колонок"
L["AO_COLUMNS_MOVE_UP"] = "Переместить выше"
L["AO_COLUMNS_MOVE_DOWN"] = "Переместить ниже"
L["AO_RESET"] = "Сброс"
L["AO_RESET_1_TEXT"] =
"АЛЛО. ТЫ КУДА НАЖАЛ?\n\n" ..
"Ты правда хочешь это сделать?\n\n" ..
"Все данные Обзора персонажей будут удалены."

L["AO_RESET_2_TEXT"] =
"ПОСЛЕДНЕЕ ПРЕДУПРЕЖДЕНИЕ.\n\n" ..
"Это действие нельзя отменить.\n\n" ..
"Ты абсолютно уверен?"

L["AO_DELETE_CHAR_TEXT"] = "Удалить персонажа из списка?\n\n%s"
L["AO_NOTE_TITLE"] = "Заметка"
L["AO_NOTE_EMPTY"] = "Нет заметки. Кликни чтобы добавить."
L["AO_DELETE_CHAR_TITLE"] = "Удаление персонажа"

L["AO_RESET_2_YES"] = "Я ЗНАЮ, ЧТО ДЕЛАЮ"
L["AO_RESET_2_NO"]  = "ОТМЕНА"
L["AO_FILTER_TIP"] = "Фильтр колонок"
L["AO_FILTER_TITLE"] = "Колонки"
L["AO_MANUAL_ORDER"] = "Свой порядок"
L["AO_MANUAL_ORDER_TIP"] = "Перетаскивай персонажей мышью; сортировка по колонкам отключается"
L["AO_NO_NEW_CHARS"] = "Не добавлять новых"
L["AO_NO_NEW_CHARS_TIP"] = "Новые персонажи не будут добавляться в таблицу"
L["AO_CONC_FULL_TITLE"] = "Концентрация восстановлена"
L["AO_CONC_MORE"] = "и другие..."
L["AO_NOTIFY_ON"] = "Уведомления включены"
L["AO_NOTIFY_OFF"] = "Уведомления выключены"


--DB
L["InCave"] = "В пещере"
L["InsBuilding"] = "Внутри здания"
L["IncWO"] = "Крафт заказ у начертателя"
L["TQ"] = "Задание учителя"
L["CraftOQ"] = "Заказ на крафт"
L["LittleHerb"] = "Случайная добыча при сборе трав"
L["BigHerb"] = "Добывается из трав после сбора 5 лепестков"
L["LittleOre"] = "Случайная добыча при сборе руды"
L["BigOre"] = "Добывается из руды после сбора 5 осколков"
L["LittleSkin"] = "Случайная добыча при снятии шкур"
L["BigSkin"] = "Добывается при снятии шкур после сбора 5 лоскутов"
L["LittleDis"] = "Случайная добыча при распылении"
L["BigDis"] = "Добывается при распылении после сбора 5 осколков"
L["238586"] = "Внутри здания, рядом с лампой"
L["23856"] = "Внутри здания, рядом с фонарем"
L["238581"] = "Внутри здания, правая сторона\nпод столом"
L["238572"] = "Внутри здания, правая сторона\nна столе"
L["238557"] = "Наверху лестницы"
L["238544"] = "Внутри здания, правая сторона\nрядом со столом"
L["238630"] = "В пещере, вход на 69.88, 50.31\nправый коридор"
L["238538"] = "На крыше"
L["238546"] = "В комнате улучшения гребней\nна столе слева"
L["238553"] = "На шляпке гриба"
L["238556"] = "В помещеним аукциона"
L["238558"] = "Нижний уровень\nна столе"
L["238559"] = "На шляпке гриба"
L["238562"] = "Верхний уровень\nна столе"
L["238563"] = "Над пещерой растет большое дерево\nсокровище находится за деревом"
L["238575"] = "Сверху на корнях"
L["238576"] = "Рядом с учителем травничества"
L["238578"] = "Верхний уровень\nрядом с Рэа'ной"
L["238579"] = "Первый этаж\nвнутри здания"
L["238580"] = "Внутри «Серебряных серенад»\n2-я комната\nпод столом"
L["238583"] = "Первый этаж\nна столе"
L["238585"] = "Нижний уровень\nна ящиках"
L["238587"] = "Внутри палатки\nна столе"
L["238613"] = "Внутри «Радушных товаров»\nна верхнем этаже"
L["238614"] = "Второй этаж\nсправа от входа"
L["238618"] = "Внутри башни\nпервый стол слева"
L["238598"] = "Внутри здания\nрядом с большой разбитой колбой"
L["storyL"] = "Становится доступно после выполнения сюжетной линии локации."
L["238582"] = "В здании, под столом."
--df
L["70253"] = "Мастер-травник\nХуа Зеленая Лапа"
L["204228"] = "Кангало (Запретный край)"
L["70258"] = "Мастер горного\nдела Бриджит Холдаг"
L["204233"] = "Тектоний(Запретный край)"
L["70259"] = "Маста-шкурник Зензи"
L["204231"] = "Фавнос(Запретный край)"
L["RousingElem"] = "Добывается с элементалей"
L["Decay"] = "Мобы, пораженные гнилью"
L["70247"] = "Мастер-алхимик\nГрегори Виалтри"
L["74935"] = "Агни Пылающее Копыто"
L["70260"] = "Мастер портняжного дела\nЭлиза Рейвиндер"
L["204225"] = "Гарид(Запретный край)"
L["70251"] = "Мастер наложения чар\nШалазар Мерцающий Закат"
L["204224"] = "Манафема"
L["70256"] = "Мастер-кожевник Эрден"
L["204232"] = "Кривоклык(Запретный край)"
L["70250"] = "Мастер-кузнец\nГрекка Разбитая Наковальня\nснаружи башни, в травке"
L["204230"] = "Кузнец приливов Зарвисс(Запретный край)"
L["70255"] = "Мастер-ювелир Плуута"
L["204222"] = "Неистовый аметист(Запретный край)"
L["206035"] = "На столе"
L["70254"] = "Мастер-начертатель\nЛидиара Шепчущее Перо"
L["204229"] = "Чаротрикс(Запретный край)"
L["198977"] = "Мобы: Кентавры клана Нокхуд" 
L["198978"] = "Мобы: Гноллы"
L["198976"] = "Мобы: Лазурный ворквин"
L["198975"] = "Мобы: Изначальный протодракон"
L["198965"] = "Мобы: Сокрушающий элементаль"
L["198966"] = "Мобы: Пылающее проявление"
L["89101"] = "Предмет находится внутри здания на земле под столом с бочкой винограда.\n\nЕсли вы его не видите, попробуйте сделать релог или сменить фазу, вступив в группу."
L["238577"] = "Предмет находится внутри здания на первом этаже рядом со столом.\n\nЕсли вы его не видите, попробуйте сделать релог или сменить фазу, вступив в группу."
L["238532"] = "Колба стоит на скамейке.\n\nЕсли вы её не видите, попробуйте сделать релог или сменить фазу, вступив в группу."
L["238545"] = "Сверху большого гриба"
--epochs.lua
L["Alchemy"] = "Алхимия"
L["Blacksmithing"] = "Кузнечное дело"
L["Enchanting"] = "Наложение чар"
L["Engineering"] = "Инженерное дело"
L["Inscription"] = "Начертание"
L["Jewelcrafting"] = "Ювелирное дело"
L["Leatherworking"] = "Кожевничество"
L["Tailoring"] = "Портняжное дело"
L["Cooking"] = "Кулинария"
--mappins.lua
L["MAP_PINS_TITLE"] = "Метки на карте"
L["MAP_PINS_SETTINGS"] = "ЛКМ: Настройки"
L["MAP_PINS_MENU_TITLE"] = "Метки на карте"
L["MAP_PINS_KNOWLEDGE"] = "Очки знаний"
L["MAP_PINS_LURES"] = "Приманки"
L["MAP_PINS_SIZE"] = "Размер"
L["MAP_PINS_UNKNOWN"] = "Неизвестно"

-- FarmTracker
L["LDB_SHIFT_LEFT_CLICK"] = "Shift + ЛКМ - Трекер фарма"
L["LDB_SHIFT_R_CLICK"] = "Shift + ПКМ - Меню распыления"

L["Customization"] = "Кастомизация"
L["Customization_Title"] = "Кастомизация"

L["Customization_Concentration"] = "Концентрация"
L["Customization_BarColor"] = "Цвет полосы"
L["Customization_TimerColor"] = "Цвет текста таймера"
L["Customization_DividerColor"] = "Цвет разделителя"
L["Customization_BorderColor"] = "Цвет рамки полосы"
L["Customization_IconBorderColor"] = "Цвет рамки иконки"
L["Customization_BackgroundColor"] = "Цвет фона"
L["Customization_Font"] = "Шрифт"
L["Customization_TimerFontSize"] = "Размер шрифта таймера"
L["Customization_ProfFontSize"] = "Размер шрифта"

L["Customization_ProfessionsWindow"] = "Окно очков знаний"
L["Customization_Prof_Background"] = "Фон"
L["Customization_Prof_Border"] = "Рамка окна"
L["Customization_Prof_Header"] = "Заголовок профессии"
L["Customization_Prof_FontColor"] = "Цвет текста"


L["Customization_ResetDefault"] = "Сбросить по умолчанию"
L["DEFAULT"] = "По умолчанию"



L["COA_CONFLICT_BAR_PREFIX"] = "Конфликт по заказам"
L["COA_CONFLICT_TOOLTIP_TITLE"] = "HironCraft Заказы — обнаружен конфликт"
L["COA_CONFLICT_TOOLTIP_FRAMES"] = "Чужие фреймы в этом окне:"
L["COA_CONFLICT_TOOLTIP_HINT_DISABLE"] = "/ahuico off — отключить модуль HironCraft"
L["COA_CONFLICT_TOOLTIP_HINT_DISMISS"] = "× — скрыть это предупреждение"





-- Profession Guides Localization
L["PG_NOT_LEARNED"] = "Профессия этой эпохи не изучена"





-- Recipe List



-- RecipeList snapshots / filters






-- Gold Depositor















-- Multi InfoPanel
L["Delete"] = L["Delete"] or "Удалить"
L["Width"] = L["Width"] or "Ширина"
L["Height"] = L["Height"] or "Высота"

-- Crafting Orders Assistant

L["COA_ACTION_NONE"] = "Нет действия"
L["COA_ACTION_OPEN"] = "Открыть"
L["COA_ACTION_CLAIM"] = "Взять"
L["COA_ACTION_CRAFT"] = "Изготовить"
L["COA_ACTION_RECRAFT"] = "Рекрафт"
L["COA_ACTION_FULFILL"] = "Завершить"
L["COA_ACTION_CLAIMING"] = "Берём"
L["COA_ACTION_CRAFTING"] = "Крафтим"
L["COA_ACTION_FULFILLING"] = "Сдаём"
L["COA_ACTION_BUSY"] = "Занят"
L["COA_BINDING_LABEL"] = "Клавиша:"
L["COA_BINDING_NONE"] = "Не назначена"
L["COA_BIND_ASSIGN"] = "Бинд"
L["COA_BIND_CAPTURE"] = "Нажмите клавишу для кнопки заказа.\nEsc — отмена."
L["COA_TOOLTIP_TITLE"] = "Действие заказа профессии"
L["COA_TOOLTIP_DESC"] = "Выполняет текущий шаг заказа."
L["COA_ROW_TOOLTIP_CLAIM"] = "Взять этот заказ."
L["COA_ROW_TOOLTIP_OPEN"] = "Открыть этот заказ."
L["COA_ROW_TOOLTIP_INLINE"] = "ЛКМ — выполнить текущий шаг этой строки. Назначенная клавиша работает только по заказам с галочкой."
L["COA_ROW_TOOLTIP_BIND"] = "ПКМ — назначить клавишу. Shift+ПКМ — сбросить клавишу."
L["COA_STATUS_NO_PROFESSION"] = "Профессия недоступна."
L["COA_STATUS_NO_ORDER"] = "Сначала выберите заказ."
L["COA_STATUS_NO_ROW"] = "Сначала наведите курсор на кнопку заказа HironCraft."
L["COA_STATUS_NO_ACTION"] = "Нет доступного действия."
L["COA_STATUS_BLIZZ_BLOCKED"] = "Кнопка Blizzard недоступна."
L["COA_STATUS_CLAIMING"] = "Берём заказ..."
L["COA_STATUS_CLAIM_FAILED"] = "Не удалось взять заказ."
L["COA_STATUS_CLAIMED"] = "Заказ взят."
L["COA_STATUS_CRAFTING"] = "Изготавливаем заказ..."
L["COA_STATUS_CRAFTED_READY"] = "Заказ изготовлен. Можно сдавать."
L["COA_STATUS_CRAFT_FAILED"] = "Не удалось изготовить заказ."
L["COA_STATUS_CANNOT_CRAFT"] = "Нельзя изготовить: не хватает реагентов, кулдаун или не проходит качество."
L["COA_STATUS_NO_REAGENTS"] = "Нельзя изготовить: не хватает реагентов."
L["COA_ACTION_NO_REAGENTS"] = "Нет реагентов"
L["COA_STATUS_FULFILLING"] = "Завершаем заказ..."
L["COA_STATUS_DONE"] = "Заказ завершён или освобождён."
L["COA_STATUS_FULFILLED"] = "Заказ завершён."
L["COA_STATUS_FULFILL_FAILED"] = "Не удалось завершить заказ."
L["COA_STATUS_NO_ENGINE"] = "Окно заказа недоступно."
L["COA_STATUS_PREPARE_FAILED"] = "Не удалось подготовить заказ."
L["COA_STATUS_BIND_SET"] = "Клавиша для заказов назначена:"
L["COA_STATUS_BIND_CLEARED"] = "Клавиша для заказов сброшена."
L["COA_SELECTED_LABEL"] = "Выбрано:"
L["COA_CLEAR_SELECTED"] = "Снять"
L["COA_QUEUE_TOOLTIP_TITLE"] = "Очередь заказов профессий"
L["COA_QUEUE_TOOLTIP_DESC"] = "Отметьте заказы здесь, затем нажимайте назначенную клавишу, чтобы выполнять выбранную очередь по шагам."
L["COA_ROW_TOOLTIP_RELEASE"] = "ПКМ — отказаться от взятого заказа / освободить его."
L["COA_STATUS_NO_SELECTED_ROW"] = "Сначала отметьте заказ галочкой."
L["COA_STATUS_NOT_CLAIMED"] = "Этот заказ сейчас не взят."
L["COA_STATUS_RELEASING"] = "Отказываемся от заказа..."
L["COA_ACTION_CANNOT_CRAFT"] = "Нельзя"
L["COA_CONCENTRATION_SHORT"] = "Конц"
L["COA_CONCENTRATION_ON"] = "Вкл"
L["COA_CONCENTRATION_TOOLTIP"] = "Переключить использование концентрации для этого заказа."
L["COA_REWARD_COMMISSION"] = "Комиссия"
L["COA_REAGENT_AUTO"] = "Авто"
L["COA_REAGENT_QUALITY_FMT"] = "Q%d"
L["COA_REAGENT_CUSTOMER"] = "Предоставлено заказчиком"
L["COA_REAGENT_CRAFTER"] = "Нужно предоставить вам"
L["COA_REAGENT_OWNED_FMT"] = "В наличии: %d / %d"
L["COA_REAGENT_MISSING_FMT"] = "Не хватает: %d"
L["COA_STATUS_CONCENTRATION_ON"] = "Концентрация включена для этого заказа."
L["COA_STATUS_CONCENTRATION_OFF"] = "Концентрация выключена для этого заказа."
L["COA_STATUS_CONCENTRATION_NOT_NEEDED"] = "Концентрация не требуется: заказ уже можно изготовить."
L["COA_STATUS_REAGENT_AUTO"] = "Выбор реагента: авто."
L["COA_STATUS_REAGENT_SELECTED"] = "Реагент выбран:"
L["COA_EXPECTED_QUALITY"] = "Ожидаемый уровень качества"
L["COA_QUALITY_TOOLTIP_QUALITY"] = "Качество"
L["COA_QUALITY_TOOLTIP_SKILL"] = "Мастерство"
L["COA_QUALITY_TOOLTIP_CONC"] = "Концентрация применена."
L["COA_QUALITY_TOOLTIP_NO_CONC_NEEDED"] = "Концентрация не требуется."
L["COA_QUALITY_TOOLTIP_NO_DATA"] = "Данные качества пока недоступны."

L["COA_ACTION_CLAIM_SHORT"] = "Взять"
L["COA_ACTION_CRAFT_SHORT"] = "Крафт"
L["COA_ACTION_RECRAFT_SHORT"] = "Рек"
L["COA_ACTION_FULFILL_SHORT"] = "Сдать"
L["COA_ACTION_CLAIMING_SHORT"] = "..."
L["COA_ACTION_CRAFTING_SHORT"] = "..."
L["COA_ACTION_FULFILLING_SHORT"] = "..."
L["COA_ACTION_BLOCKED_SHORT"] = "—"
L["COA_ACTION_NONE_SHORT"] = "—"
L["COA_PANEL_HELP_TITLE"] = "Очередь заказов профессий"
L["COA_PANEL_HELP_DESC"] = "Отмечайте заказы галочкой внутри кнопки строки, затем нажимайте назначенную клавишу. Каждое нажатие выполняет один шаг: взять, изготовить или завершить. ПКМ по кнопке строки освобождает взятый заказ."
L["COA_PANEL_HELP_REAGENTS"] = "Иконки реагентов позволяют выбрать грейд. Иконка концентрации в колонке качества включает концентрацию, если она нужна."
L["COA_PANEL_HELP_ROW_COLORS_TITLE"] = "Цвета строк:"
L["COA_PANEL_HELP_ROW_GREEN"] = "Зелёная: заказ можно изготовить."
L["COA_PANEL_HELP_ROW_YELLOW"] = "Жёлтая: требуемое качество выше крафта без концентрации."
L["COA_PANEL_HELP_ROW_RED"] = "Красная: рецепт не изучен или недоступен."
L["COA_TOOLTIP_STATE"] = "Состояние:"
L["COA_TOOLTIP_TIME_LEFT"] = "Осталось:"
L["COA_TOOLTIP_QUEUE_STATE"] = "В очереди:"
L["COA_YES"] = "Да"
L["COA_NO"] = "Нет"
L["COA_SELECT_ALL"] = "Очередь"
L["COA_SELECT_ALL_TOOLTIP_TITLE"] = "Сформировать очередь"
L["COA_SELECT_ALL_TOOLTIP"] = "Формирует очередь заказов средствами HironCraft и отмечает подходящие заказы галочками."
L["COA_STATUS_SELECTED_CRAFTABLE"] = "Выбрано доступных заказов: %d."
L["COA_SHOPPING_BUTTON"] = "Закупка"
L["COA_SHOPPING_TOOLTIP_TITLE"] = "Создать список закупки"
L["COA_SHOPPING_TOOLTIP"] = "Создаёт список HironCraft Shop по отмеченным заказам и выбранным грейдам реагентов. Реагенты заказчика/НИПа пропускаются; добавляется только недостающее количество."
L["COA_SHOPPING_LIST_NAME"] = "Заказы профессий"
L["COA_STATUS_SHOP_NO_SELECTED"] = "Сначала отметьте заказы галочкой."
L["COA_STATUS_SHOP_EMPTY"] = "По отмеченным заказам нечего покупать."
L["COA_STATUS_SHOP_CREATED"] = "Список закупки создан: %d предметов из %d заказов."
L["COA_STATUS_SHOP_CREATED_AUCTIONATOR"] = "Список Auctionator создан: %d предметов."
L["COA_STATUS_SHOP_UNAVAILABLE"] = "HironCraft Shop или API списков Auctionator недоступны."

L["COA_ACTION_UNKNOWN_RECIPE"] = "Неизвестно"
L["COA_ACTION_VIEW_ONLY"] = "Просмотр"
L["COA_STATUS_TABLE_REQUIRED"] = "Для этого действия нужен стол заказов."
L["COA_STATUS_UNKNOWN_RECIPE"] = "Этот рецепт не изучен этим персонажем."

L["COA_HDR_QUALITY"] = "Качество"

L["COA_HDR_REWARDS"] = "Награды"

L["COA_HDR_REAGENTS"] = "Реагенты"
L["COA_HDR_PROFIT"] = "Профит"

L["COA_HDR_ACTION"] = "Действие"
L["COA_HDR_NAME"] = "Название"
L["COA_HDR_COST"] = "Стоимость"
L["COA_HDR_CONC"] = "Конц."
L["COA_HDR_REWARD"] = "Награда"
L["COA_PROFIT_NO_DATA"] = "Данные профита недоступны."
L["COA_PROFIT_MISSING"] = "Часть цен Auctionator недоступна."
L["COA_PROFIT_REAGENTS"] = "Стоимость реагентов:"
L["COA_PROFIT_REWARDS"] = "Стоимость наград:"
L["COA_PROFIT_RESULT"] = "Профит:"
L["COA_QUALITY_TOOLTIP_CONC_COST"] = "Концентрации до следующего качества:"
L["COA_STATUS_SHOP_TEMP_FAILED"] = "Не удалось создать временный список HironCraft Shop."
L["COA_STATUS_SHOP_UNAVAILABLE"] = "Временная сессия HironCraft Shop недоступна."

L["COA_PROF_TOOL_SLOT_TITLE"] = "Инструмент профессии"
L["COA_BEST_QUALITY_TITLE"] = "Использовать реагенты лучшего качества"
L["COA_BEST_QUALITY_DESC"] = "Всегда подбирать реагенты самого высокого качества для всех рецептов. Подсвечивается, когда включено."
L["COA_PROF_TOOL_EMPTY"] = "Для текущей профессии не надет инструмент."
L["COA_PROF_TOOL_STAT_FMT"] = "Стат инструмента: %s"
L["COA_PROF_TOOL_CLICK_HINT"] = "Клик: выбрать другой инструмент из сумок."
L["COA_PROF_TOOL_STAT_INGENUITY"] = "Изобретательность"
L["COA_PROF_TOOL_STAT_INSPIRATION"] = "Вдохновение"
L["COA_PROF_TOOL_STAT_RESOURCEFULNESS"] = "Находчивость"
L["COA_PROF_TOOL_STAT_MULTICRAFT"] = "Перепроизводство"
L["COA_PROF_TOOL_STAT_CRAFTING_SPEED"] = "Скорость изготовления"
L["COA_PROF_TOOL_STAT_FINESSE"] = "Искусность"
L["COA_PROF_TOOL_STAT_DEFTNESS"] = "Проворство"
L["COA_PROF_TOOL_STAT_PERCEPTION"] = "Восприятие"
L["COA_PROF_TOOL_MENU_TITLE"] = "Инструменты профессии"
L["COA_PROF_TOOL_MENU_EMPTY"] = "В сумках нет подходящих инструментов."
L["COA_STATUS_PROF_TOOL_COMBAT"] = "В бою нельзя менять инструмент профессии."
L["COA_STATUS_PROF_TOOL_EQUIP"] = "Надеваем инструмент профессии: %s."
L["COA_STATUS_PROF_TOOL_EQUIP_FAILED"] = "Не удалось надеть инструмент профессии."

L["COA_EXPANSION_MIDNIGHT"] = "Midnight"
L["COA_EXPANSION_TWW"] = "TWW"
L["COA_EXPANSION_DF"] = "DF"
L["COA_EXPANSION_CURRENT_FMT"] = "Дополнение: %s"
L["COA_EXPANSION_DROPDOWN_TITLE"] = "Дополнение профессии"
L["COA_EXPANSION_DROPDOWN_TOOLTIP"] = "Переключает реальное дополнение профессии, как дропдаун на основной странице профессии."
L["COA_STATUS_EXPANSION_SELECTED"] = "Дополнение профессии: %s."
L["COA_STATUS_EXPANSION_UNAVAILABLE"] = "Это дополнение недоступно для текущей профессии: %s."
L["COA_STATUS_EXPANSION_SWITCH_FAILED"] = "Не удалось переключить дополнение профессии: %s."

L["COA_QUEUE_BUTTON"] = "Очередь"
L["COA_QUEUE_TOOLTIP"] = "Формирует очередь заказов средствами HironCraft и отмечает подходящие заказы галочками. Проверяет известный рецепт, доступные реагенты и требуемое качество."
L["COA_QUEUE_REAGENT_MODE_AUTO"] = "Эконом"
L["COA_QUEUE_REAGENT_MODE_T1"] = "Т1"
L["COA_QUEUE_REAGENT_MODE_T2"] = "Т2"
L["COA_QUEUE_REAGENT_MODE_PROFIT"] = "Профит"
L["COA_QUEUE_REAGENT_MODE_CURRENT_FMT"] = "Реагенты: %s"
L["COA_QUEUE_REAGENT_MODE_HINT"] = "ПКМ: Эконом, Т1, Т2 или Профит."
L["COA_STATUS_QUEUE_REAGENT_MODE"] = "Режим реагентов очереди: %s."
L["COA_QUEUE_PROFIT_FILTER_OFF"] = "Выкл."
L["COA_QUEUE_PROFIT_FILTER_HEADER"] = "Фильтр профита"
L["COA_QUEUE_PROFIT_FILTER_CURRENT_FMT"] = "Профит не ниже: %s"
L["COA_QUEUE_PROFIT_FILTER_CLEAR"] = "Выключить фильтр профита"
L["COA_QUEUE_AUTO_ON_OPEN_HEADER"] = "Авто-очередь"
L["COA_QUEUE_AUTO_ON_OPEN"] = "Авто-очередь при открытии"
L["COA_QUEUE_AUTO_SHOPPING"] = "Авто-закуп после авто-очереди"
L["COA_STATUS_AUTOQUEUE_ON"] = "Авто-очередь включена."
L["COA_STATUS_AUTOQUEUE_OFF"] = "Авто-очередь выключена."
L["COA_STATUS_AUTOSHOP_ON"] = "Авто-закуп включён."
L["COA_STATUS_AUTOSHOP_OFF"] = "Авто-закуп выключен."
L["COA_QUEUE_PROFIT_FILTER_POPUP"] = "Минимальный профит для очереди в золоте. Можно отрицательное число. Пустое значение выключает фильтр."
L["COA_STATUS_QUEUE_PROFIT_FILTER"] = "Фильтр профита очереди: %s."
L["COA_STATUS_QUEUE_PROFIT_FILTER_OFF"] = "Фильтр профита очереди выключен."
L["COA_STATUS_QUEUE_PROFIT_FILTER_INVALID"] = "Фильтр профита очереди: введите число."
L["COA_STATUS_QUEUE_BUILDING"] = "Формирую очередь заказов..."
L["COA_STATUS_QUEUED_ORDERS"] = "Добавлено в очередь заказов: %d."
L["COA_STATUS_QUEUE_VIEW_ONLY"] = "Очередь можно формировать только при доступной странице заказов."
L["COA_STATUS_QUEUE_NO_TYPES"] = "Для очереди не включён ни один тип заказов."
L["COA_WEEKLY_QUEST_TAKEN_SHORT"] = "Квест: взят"
L["COA_WEEKLY_QUEST_NOT_TAKEN_SHORT"] = "Квест: нет"
L["COA_WEEKLY_QUEST_DONE_SHORT"] = "Квест: готов"
L["COA_WEEKLY_QUEST_UNKNOWN_SHORT"] = "Квест: —"
L["COA_WEEKLY_QUEST_TOOLTIP_TITLE"] = "Недельный квест профессии"
L["COA_WEEKLY_QUEST_TOOLTIP_TAKEN"] = "Недельный квест профессии есть в журнале заданий."
L["COA_WEEKLY_QUEST_TOOLTIP_NOT_TAKEN"] = "Недельный квест профессии не взят."
L["COA_WEEKLY_QUEST_TOOLTIP_DONE"] = "Недельный квест профессии уже выполнен на этой неделе."
L["COA_WEEKLY_QUEST_TOOLTIP_NONE"] = "Для этой профессии в базе очков знаний HironCraft не найден недельный квест."
L["COA_WEEKLY_QUEST_TOOLTIP_UNKNOWN"] = "Не удалось сопоставить текущее дополнение профессии с базой очков знаний HironCraft."
L["COA_WEEKLY_QUEST_STATE_TAKEN"] = "взят"
L["COA_WEEKLY_QUEST_STATE_NOT_TAKEN"] = "не взят"
L["COA_WEEKLY_QUEST_STATE_DONE"] = "готов"
L["COA_WEEKLY_QUEST_STATE_UNKNOWN"] = "неизвестно"
L["COA_WEEKLY_QUEST_FALLBACK_NAME"] = "Недельный квест профессии"



-- финализируем локаль на файл-загрузке (по локали клиента; переопределение применит ADDON_LOADED)
if PT.RebuildLocale then PT.RebuildLocale() end
