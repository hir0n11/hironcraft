# 0.4.174 — Separate customer replies from outstanding attention

- A successfully sent quick reply resolves yellow attention for the exact
  request/message it answers, without clearing the customer's second check.
  Merely matching a keyword/showing a card, failed sends and old cards answering
  an earlier message do not silence a newer unresolved question.
- Quick replies to confirmed sent/claimed orders (for example "omw") retain
  the green highlight and crafting reminder. A row's right click can explicitly
  resolve either yellow or green attention when the user has dealt with it.
  Subsequent status clearing / row removal retain their existing separate steps;
  right click no longer toggles the customer's reply check.
- A new incoming message re-arms attention with a fresh one-minute grace period.
  Resolving attention does not mark a craft complete or expire its pending row:
  the customer can still return later with "sent" after gathering materials.
- Ready-answer cards, merged reply sources, generated greeting groups and
  decline explanations retain exact message/request identities. The resolution
  is saved and shared between linked accounts; late packets cannot hide a newer
  question or resolve a replacement request. Battle.net privacy is unchanged.
  A row reused for a fresh request resets its old attention epoch, not its data
  or chat history, so previous acknowledgements/colours/timers cannot leak in.
- Server-throttle feedback rolls back a just-sent quick reply's attention
  resolution, but cannot undo a later manual acknowledgement or new message.
  Existing explicit-click send guards and cooldowns are unchanged.
- Added independent attention-resolution and real toast/click regressions,
  including yellow/green right clicks, unchanged checks, reminders, reload/sync,
  stale contexts, pending-row retention, errors and server-throttle rollback.
