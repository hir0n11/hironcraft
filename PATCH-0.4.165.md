# 0.4.165 — Short check acknowledgements

- Incoming `check`, `chk`, `chck`, `check now`, `check pls` and short
  order-specific variants turn the active customer's scanner row green.
- Questions, negations, future/conditional messages and requests to check
  price, quality, skill, materials or links remain non-green.
- Regression coverage reproduces the screenshot's `hi` -> `check` followed
  by the crafter's `omw` -> `hey`. The order stays unfinished, and the reminder
  waits a full minute after the crafter's latest reply.
