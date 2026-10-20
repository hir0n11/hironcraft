# 0.4.166 — Adaptive chat-name menus

- Chat-name menus now fit independently of the main-window scaling option.
  Long explanation and matching lists fold into submenus; on short screens
  the addon actions can temporarily collapse into one HironCraftScan branch
  without overwriting the saved collapse preference.
- Root menus and all addon submenus use native scrolling with a height limit
  derived from the current game window. Size is recalculated on every opening.
- Addon labels have a bounded width without reducing the normal font size.
  Truncated labels remain available in tooltips alongside existing help;
  actual messages, item links, recipients and action callbacks are unchanged.
- Height estimates include recrafts, decline reasons, active-order tools,
  mute/ignore actions and enabled crafters. Native WoW/other-addon entries
  retain their original labels, tooltips, initializers and handlers.
- Added a focused native-menu boundary harness covering resizing, scrolling,
  clipping, retained tooltips, action payloads, ordinary/Battle.net targets
  and disabled main-window fitting. All 84 Lua harnesses passed twice.
