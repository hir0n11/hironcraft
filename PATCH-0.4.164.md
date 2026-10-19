# 0.4.164 — Scanner version label and plus confirmations

- The scanner's title strip now shows `HironCraft <version>` beside the
  profession portrait, using small plain grey text.
- The label uses the loaded addon's version, not the scanner sync protocol.
  A separate mouse-transparent frame keeps it above the native decoration
  without changing buttons, window size, order rows or scrolling.
- Initial opening and subsequent reopens reuse the same label. The version
  appears before order-list refresh, so it remains available for screenshots
  even when a separate list error occurs.
- A customer's standalone `+` or `++` also turns the active inquiry green.
  Pluses in quality, skill, price, arithmetic or longer messages do not count;
  questions and negations retain their normal non-green state.
- The screenshot scenario is tested through reply tracking, including the
  second check and the unchanged full-minute initial reminder delay.
