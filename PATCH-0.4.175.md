# 0.4.175 — More conversational order-sent confirmations

- Added bounded acknowledgements "did", "I did", "did it", "I already did"
  and related order-only tails. Existing "posted" also accepts conversational
  padding and "posted again", without matching arbitrary uses of "did".
- Added common lead-ins such as "yoo", "hey bro", "thx" and "thanks". Exact
  check acknowledgements support polite prefixes/suffixes: "yoo check it",
  "check pls", "pls check it" and "please check the orders". Price, quality,
  skill and material-check requests are not included.
- Added the screenshot's "Thx you got it" and close you/u-got/have-order
  confirmations, plus resending/resent/resend/reposted/resubmitted and selected
  spelling variants. "Got it" alone still means neither order submission nor
  completion; questions, negatives and future/conditional plans stay guarded.
- Recheck an older peer's generic attention classification using the current
  grammar, so a newly supported confirmation can become green on the receiver.
  Explicit sent/waiting classifications remain compatible, and original chat
  messages, character names and user keywords are not rewritten.
- Regression coverage exercises both screenshot conversations, declined-order
  resending, post-acknowledgement posted replies, and real quick-reply clicks.
  Heart/omw replies do not silence these green orders; the reply check, actual
  game-order status and existing reminder timing remain unchanged.
- Phrase tables and courtesy lists are built once. No fuzzy matching, extra
  timers or broad standalone substring matching of "did" was introduced.
