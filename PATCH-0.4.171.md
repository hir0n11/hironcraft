# 0.4.171 — Anticipate typos in other sending confirmations

- Added 91 explicit English/Russian spelling variants for done, listed,
  ordered, placed, posted, submitted, mailed, delivered, dispatched, check,
  incoming, onair, order/orders and several Russian acknowledgements.
  Examples: "palced", "sumbitted", "cehck", "dnoe", "litsed", "оптравил".
- The lookup is built once and used only inside the full-phrase acknowledgement
  grammar. There is no runtime fuzzy matching or expansion of the general
  substring keyword scan. Character identities, original chat messages and
  user-defined keywords retain their spelling and existing behaviour.
- Combined typo confirmations such as "2 ordrs palced" work, including plural
  "check the orders" and compact "onair rn". Questions, negative/future and
  conditional statements, reagents, auction listings and lookalike words have
  dedicated rejection cases; ambiguous short words such as "don", "one",
  "place" and "submit" are not introduced as confirmations.
- New regression coverage exercises every added variant, active-inquiry
  isolation, crafter identity, original chat retention, waiting-state changes
  and the unchanged one-minute reminder. No craft completion or scanner-row
  creation is inferred from a misspelled acknowledgement.
