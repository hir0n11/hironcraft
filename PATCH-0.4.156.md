# 0.4.156 — flexible send confirmations and first reminder delay

- Green-row confirmations now also accept `sending`, `send` within a phrase,
  `sendin`, `sends`, `sended`, `sented`, `sendt`, `sendet`, `senting`, `sendig`,
  `sendingg`, `sned`, `sedn`, `snt` and `snd`. Case/punctuation do not matter.
- Questions, requests such as `please send`/`send me`, negations and future
  intentions such as `will send`, `not yet sending` or `sending later` stay yellow.
- The first reminder waits at least the configured delay (60 seconds by
  default) after the second check becomes active. An older outgoing greeting
  can no longer make the first alarm ring immediately. A later outgoing reply
  still restarts the delay; ordinary incoming messages do not keep postponing it.
- Turning reminders on, or the first start after upgrading from 0.4.155, gives
  a full initial grace period even for existing checked rows. Reloading does
  not repeatedly reset that saved grace period or the repeat cadence.
