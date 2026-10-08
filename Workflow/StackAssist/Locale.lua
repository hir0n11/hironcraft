local PT = HironCraftProfit
if not PT then return end

PT.L_enUS = PT.L_enUS or {}
PT.L_ruRU = PT.L_ruRU or {}

PT.L_enUS["Settings_StackAssist"] = "Stack Assist"
PT.L_enUS["STACK_ASSIST_RESTART"] = "Stack Assist: stacks have been prepared. Start the recipe again."
PT.L_enUS["STACK_ASSIST_ETA"] = "Remaining:"

PT.L_ruRU["Settings_StackAssist"] = "Умные стаки"
PT.L_ruRU["STACK_ASSIST_RESTART"] = "Умные стаки: стаки подготовлены. Запусти рецепт ещё раз."
PT.L_ruRU["STACK_ASSIST_ETA"] = "Осталось:"

if PT.RebuildLocale then PT.RebuildLocale() end
