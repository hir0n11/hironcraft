# 0.4.173 — Optional Shift tooltip suppression beside the custom phrases

- Added a default-off "Hide tooltip while holding Shift" checkbox at the top
  of the Custom Explanations dropdown, directly beside the phrase controls.
  The preference is saved in this account's settings, independent of phrase
  text, assigned keys and linked accounts' preferences.
- When checked, holding Shift over an order-list row hides the quick-phrase
  popup and its reagent side tooltip. Releasing Shift restores normal chat
  history without moving the mouse. Hovering with Shift already held works too.
- Phrase hotkeys keep working. Without Shift and on other tooltip owners,
  history retains its normal behaviour; unchecking restores the existing hints.
- Hidden GameTooltips do not get OnUpdate, so modifier events handle restoration
  without a new timer. Explicit row leave, cleared/recycled rows, dismissal or
  closing the scanner cancel restoration rather than reviving a stale tooltip.
- Regression checks cover the menu checkbox/default/persistence, tooltip
  hide/restore lifecycle and actual hotkey sending with suppression enabled.
