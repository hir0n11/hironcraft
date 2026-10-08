local PT = HironCraftProfit
if not PT then return end

PT.L_enUS = PT.L_enUS or {}
PT.L_ruRU = PT.L_ruRU or {}

local E = PT.L_enUS
local R = PT.L_ruRU

E["Settings_QuestShopping"] = "Quest Shopping"
E["Settings_QuestShopping_Tooltip"] = "Darkmoon Faire quests show a cart automatically. For any other quest, Alt + left click it in the objective tracker to add a cart; Alt + right click the cart (or Remove below) to remove it."
E["Settings_QuestShopping_SavedList"] = "Saved quests"
E["Settings_QuestShopping_NoSaved"] = "No saved quests. Alt + left click a quest in the tracker to add one."
E["Settings_QuestShopping_Remove"] = "Remove"
E["Settings_QuestShopping_ClearSaved"] = "Remove all saved quests"
E["Settings_QuestShopping_RestoreHidden"] = "Restore hidden Faire carts"
E["QS_QUEST_SAVED"] = "quest cart enabled: %s"
E["QS_QUEST_UNSAVED"] = "quest cart removed: %s"
E["QS_TOOLTIP_TITLE"] = "Quest Shopping"
E["QS_TOOLTIP_DESC"] = "Open a temporary HironCraft Shop list for missing items."
E["QS_TOOLTIP_ALL_TITLE"] = "Quest Shopping"
E["QS_TOOLTIP_ALL_DESC"] = "Open a temporary HironCraft Shop list for all tracked quests with matching items."
E["QS_TOOLTIP_HINT_LMB"] = "Left click: open shopping list."
E["QS_TOOLTIP_HINT_ALT_RMB"] = "Alt + right click: remove the cart for this quest."
E["QS_TOOLTIP_HINT_ALT_LMB"] = "Alt + left click a quest in the tracker: add/remove its cart."
E["QS_TOOLTIP_HINT_ALT_RMB_ALL"] = "Alt + right click: remove carts for all these quests (manage them in settings)."
E["QS_SHOP_LIST_NAME"] = "Quest: %s"
E["QS_SHOP_LIST_ALL"] = "Quest items"
E["QS_STATUS_CREATED"] = "HironCraft Shop list created: %d items."
E["QS_STATUS_EMPTY"] = "No missing items to buy."
E["QS_STATUS_SHOP_UNAVAILABLE"] = "HironCraft Shop is unavailable."
E["QS_STATUS_SHOP_FAILED"] = "Could not create a temporary HironCraft Shop list."

R["Settings_QuestShopping"] = "Покупки для квестов"
R["Settings_QuestShopping_Tooltip"] = "Квесты Ярмарки Новолуния показывают корзинку автоматически. Для любого другого квеста: Alt + ЛКМ по нему в трекере целей — добавить корзинку; Alt + ПКМ по корзинке (или «Убрать» ниже) — убрать."
R["Settings_QuestShopping_SavedList"] = "Сохранённые квесты"
R["Settings_QuestShopping_NoSaved"] = "Нет сохранённых квестов. Alt + ЛКМ по квесту в трекере, чтобы добавить."
R["Settings_QuestShopping_Remove"] = "Убрать"
R["Settings_QuestShopping_ClearSaved"] = "Убрать все сохранённые квесты"
R["Settings_QuestShopping_RestoreHidden"] = "Вернуть скрытые корзинки Ярмарки"
R["QS_QUEST_SAVED"] = "корзинка квеста включена: %s"
R["QS_QUEST_UNSAVED"] = "корзинка квеста убрана: %s"
R["QS_TOOLTIP_TITLE"] = "Покупки для квестов"
R["QS_TOOLTIP_DESC"] = "Открыть временный список HironCraft Shop для недостающих предметов."
R["QS_TOOLTIP_ALL_TITLE"] = "Покупки для квестов"
R["QS_TOOLTIP_ALL_DESC"] = "Открыть временный список HironCraft Shop по всем отслеживаемым квестам с подходящими предметами."
R["QS_TOOLTIP_HINT_LMB"] = "ЛКМ: открыть список покупок."
R["QS_TOOLTIP_HINT_ALT_RMB"] = "Alt + ПКМ: убрать корзинку для этого квеста."
R["QS_TOOLTIP_HINT_ALT_LMB"] = "Alt + ЛКМ по квесту в трекере: добавить/убрать корзинку."
R["QS_TOOLTIP_HINT_ALT_RMB_ALL"] = "Alt + ПКМ: убрать корзинки по всем этим квестам (управление — в настройках)."
R["QS_SHOP_LIST_NAME"] = "Квест: %s"
R["QS_SHOP_LIST_ALL"] = "Предметы для квестов"
R["QS_STATUS_CREATED"] = "Список HironCraft Shop создан: %d предметов."
R["QS_STATUS_EMPTY"] = "Нет недостающих предметов для покупки."
R["QS_STATUS_SHOP_UNAVAILABLE"] = "HironCraft Shop недоступен."
R["QS_STATUS_SHOP_FAILED"] = "Не удалось создать временный список HironCraft Shop."

if PT.RebuildLocale then PT.RebuildLocale() end
