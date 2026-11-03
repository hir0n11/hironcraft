# 0.4.177 — Restore customer reminders and limit answered rows to one hour

- Quick replies, generated greetings and decline explanations no longer
  silence yellow highlights or reminders. Sent confirmations remain green;
  outgoing replies still restart the normal reminder delay.
- Right-click still clears either background and its reminder without
  removing the customer's second reply check. A new reply reopens attention.
- Only explicit manual acknowledgements are synchronized as handled. Legacy
  handled markers had no origin, so they are no longer allowed to suppress
  reminders; an old acknowledged background may reappear once after upgrading.
- Rows with the second check expire one hour after the request's original
  list time, including quiet rows and when the ordinary timeout is longer.
  Messages and replies do not prolong that limit. Expired rows stop reminding
  immediately and are removed by the existing list cleanup cycle.
