# 0.4.170 — Recognize sending typos

- Added the screenshot's "senidng" and nearby transposition typos "sendign",
  "sedning" and "sendnig" to customer sending acknowledgements.
- These are exact word variants using the existing context guards, not fuzzy
  matching. Questions, negatives, requests and delayed/conditional plans do
  not become confirmations through these variants.
- Added classification regressions and the incoming "senidng" / outgoing
  "omw" scenario: the active row stays green and unfinished, while the first
  reminder still waits a full minute after the crafter's latest reply.
