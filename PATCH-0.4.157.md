# 0.4.157 — "done" confirms a customer's sent order

- Incoming `done`, `done'`, `DONE!`, `all done` and `done, thanks` can turn an
  active conversation's scanner row green, including after a quality question.
- This means the customer confirmed sending their order, not that the crafter
  completed it. Fulfillment checks and waiting reminders remain unchanged.
- Negations, questions, future intentions, `almost/nearly done`, and messages
  about getting/buying materials do not activate the green state.
- Regression coverage includes the screenshot conversation, punctuation and
  word boundaries, misleading "done" phrases and the unchanged reminder delay.
