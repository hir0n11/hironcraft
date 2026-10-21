# 0.4.169 — Recognize confirmations for multiple orders

- Customer acknowledgements such as "2 order placed", "2 orders placed",
  "two orders placed", "both orders placed" and "placed two orders" turn the
  active scanner inquiry green. Plural subjects and completed-state auxiliaries
  also work, including "the orders have been placed" and "both orders are up".
- Quantities are recognized only inside the existing full-phrase confirmation
  grammar. Questions, negatives, delayed/conditional plans, material purchases
  and zero-order statements do not become confirmations through this rule.
- A quantity does not create scanner rows, complete a craft or check unrelated
  inquiries/customers. The normal one-minute first reminder remains unchanged.
- Added classification cases and the screenshot's real incoming-reply scenario,
  including inquiry isolation, row preservation and reminder timing checks.
