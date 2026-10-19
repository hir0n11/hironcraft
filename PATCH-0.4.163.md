# 0.4.163 — Ordered confirmations

- Incoming `ordered`, short ordering variants/typos, `I ordered it` and
  `ordered it rn` turn a customer's scanner row green.
- Added related acknowledgements such as `made an order`, `created the order`,
  `order created`, and Russian `заказал` / `заказала` / `заказано`.
- Questions, negations, future/conditional promises, ordering materials and
  unrelated word fragments remain non-green. Bare `order` is not a confirmation.
- The screenshot conversation is covered by regression tests. These words
  confirm the customer's order, not a completed craft; reminder timing,
  crafter-specific login highlighting and sound settings are unchanged.
