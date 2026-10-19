# 0.4.155 — customer states, sound controls and timed full ignore

- Green scanner rows mean the customer confirmed sending the order; yellow
  means another answer. This does not change the meaning of the second check.
  Confirmations use word boundaries and reject negatives/future statements.
- `/hcsounds` opens **Sounds and reminders** under HironCraftScan in WoW settings.
  Five alert types have separate enable/sound/volume/preview controls. Packaged
  audio includes independent 10% volume steps; the game's mixer is not changed.
  External files and the catalogue's raw game-file ID retain original volume
  and are explicitly labelled. Zero volume always silences the alert.
- Enable **Remind waiting customers on this device** only on the collecting
  laptop. It is deliberately off by default to avoid alarms on both machines.
  Defaults: first reminder after 60 seconds from your last actual sent reply
  (or the customer's first answer if you have not replied), repeat every 60
  seconds. Both colours participate; duplicate aliases give one pending row.
  Removing the second check, crafting/fulfilling/rejecting, full ignore or
  deleting the row stops reminders. The menu can snooze a row for 5 minutes.
- A marked active row no longer vanishes at the normal scanner timeout while
  the client is still waiting. Outgoing chat and reminder cadence survive reload.
- The chat menu separately offers **Mute whisper sound for this player** and
  **Ignore everywhere** (hour/day/week/permanent). Old scanner-only ignores are
  retained as scanner-only. Full ignores and whisper mutes merge between fully
  linked accounts with versioned removals; volumes and reminder enablement do not.
- Full ignore sends no automatic answer, even with an old GIL reply setting.
  The first received ignored whisper produces one local informational notice;
  its flag survives reload until that ignore expires or is replaced. Whispers
  blocked by Blizzard at the server cannot produce a local notice.
- If the separate WhisperAlert addon is loaded, use **Use built-in alerts** in
  `/hcsounds`, then `/reload`. It otherwise owns whisper audio independently and
  cannot obey HironCraft's mute/volume controls. No other addon is disabled
  automatically.

Validation: isolated Lua 5.1 regression harnesses, explicit chronology/identity/
reload/expiry/convergence cases, current removed-API check, generated audio
headers and decoded RMS/duration checks, and release archive hash verification.
These checks do not replace a live in-game check on both linked accounts.
