# 0.4.178 — Restore attention to replies after a decline

- A newly declined request becomes the customer's current conversation when
  the cancellation is newer than their previous greeting. A reply such as
  "I will fix it" now returns attention to that request instead of another
  item that happened to have the latest greeting.
- Replies received in the same second as cancellation can reopen attention
  when their captured request context identifies that exact decline. Old
  pre-decline contexts and repeated messages cannot provide that evidence.
- Notice-only declines are observed immediately, including linked-device
  delivery, rather than waiting for the scanner row to be read or hovered.
- The actual rejection status stays intact. New replies get the normal
  reminder grace period; manual background dismissal, completed orders and
  the one-hour answered-row limit keep their existing behavior.
