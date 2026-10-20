# 0.4.168 — Reduce repeated work and session memory growth

- Profession rows, headers, item icons/text and account-overview rows/cells,
  column headers and sort arrows are reused instead of recreated on refresh.
  Reused controls retain their current item/character actions and reset their
  visual state; hidden profession windows defer display work until shown.
- Profession listeners share one queued data/display refresh and one shared
  late-data retry. Equipment/skill bursts also share an account snapshot;
  logout still saves the latest character state synchronously.
- Analytics rotates into bounded raw chunks, saved in a persistent pending
  queue and readable before packing. One chunk of at most 500 events is packed
  per background callback, outside combat, without waiting for the exchange's
  quiet period. Old oversized open blocks are split, not compressed at login.
- The last 201 events remain mutable for throttled-greeting retractions.
  Failed encoders and reloads retain pending data. History queries, return
  cataloguing and navigation handle rotation during asynchronous loading.
- Finite analytics sync batches retain/sort only the batch plus lookahead.
  Sequence bounds avoid unpacking later stores; missing legacy lower bounds
  are learned conservatively without changing the exchange protocol.
- Added dedicated allocation/event-burst, snapshot/logout and analytics stress
  checks (10,000-event history, reload, encoder failure, retraction, background
  rotation, legacy ordering and bounded sync). No user settings/history reset.

The native professions UI dependency is intentionally retained: configuration
XML inherits its templates. Removing that dependency requires a separate
lazy-loading redesign; it is not silently disabled in this performance patch.
Automated checks measure work/allocation bounds, not real in-game FPS.
