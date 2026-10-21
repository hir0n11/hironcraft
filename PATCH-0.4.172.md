# 0.4.172 — Restore attention after a declined order gets a new reply

- A decline still turns off the scanner row's highlight and waiting reminder.
  A newer incoming reply to that inquiry restores attention: ordinary replies
  are yellow, material gathering stays yellow, sending confirmations are green.
  The original rejection/cross, material audit and game-order status are kept.
- The first post-decline reply gets a fresh one-minute reminder delay; further
  customer replies do not continually restart it. A later crafter reply resets
  the timer as before. Outgoing decline explanations do not reopen attention.
- Different declined game orders start a new attention cycle. Duplicate status
  deliveries and reagent-audit enrichment for the same game order do not close
  an already restored highlight. Completed/crafted orders remain terminal.
- Status/chat chronology uses the existing peer/server clock offsets, including
  notice-only statuses. Late status delivery preserves a genuinely later reply;
  legacy peers without clock metadata use one fixed local receipt boundary.
  The marker survives reload and remains scoped to the exact request/inquiry.
- Added "both should be there now" and "both orders should be there now"
  (also without "now") as full-phrase sending confirmations. One greeting for
  two items turns both of those rows green without checking unrelated inquiries.
- Regression coverage includes repeated declines, stale replies, manual marks,
  reload, old/new peer clocks, notice-only delivery, colours and reminder timing.
