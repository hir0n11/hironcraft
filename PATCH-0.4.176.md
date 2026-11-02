# 0.4.176 — Recognize "order out" confirmations

- Added the screenshot's "order out, ty" as an order-sent acknowledgement,
  alongside "order is out", "orders out", "both orders are out" and compact
  "it's out" forms, with the existing courtesy and now/rn/already handling.
- Only complete acknowledgement phrases are matched. Bare "out", "out of
  mats", "order out of stock", questions, negatives, delayed/conditional
  statements and zero-order claims do not become green through this rule.
- Regression coverage includes the exact screenshot message after a handled
  quick reply, outgoing heart/omw responses, manual acknowledgement/re-arming
  and the unchanged waiting-for-craft reminder.
