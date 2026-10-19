# 0.4.162 — Listed-order confirmations

- `listed`, `listing`, `listin`, `listd` and similar short listing typos can
  turn a customer's scanner row green. Existing subject/courtesy rules also
  cover `order listed`, `I've listed it`, `I'm listing it now`, and `listed
  the order for you`.
- Added short placement acknowledgements such as `put the order in`,
  `put in an order`, `in your order list` and `in your crafting orders`.
- Questions, negations, future/conditional promises, material/AH listings and
  unrelated words do not qualify. Bare `list` remains ambiguous and non-green.
- Regression coverage includes the screenshot's incoming `listed` followed
  by the crafter's outgoing `omw`. Reminder clocks, completion status and
  crafter-specific login requests retain their existing behaviour.
