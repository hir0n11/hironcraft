# 0.4.159 — Immediate sending confirmations

- Standalone customer acknowledgements such as `I will send now`, `I'll send
  right now` and `I will send the order now` turn the scanner row green.
  Capitalisation, punctuation and a trailing `thanks` or `ty` are supported.
- Questions, negations, conditional promises, collecting materials and
  promises to send later remain non-green. General future-tense detection
  is unchanged outside the specific immediate-sending acknowledgements.
- Green remains a customer sending confirmation, not a completed craft.
  Reminder timing and unfinished-customer tracking are unchanged.
- Regression coverage includes the screenshot conversation, acknowledgement
  variants and misleading negative/future/material phrases.
