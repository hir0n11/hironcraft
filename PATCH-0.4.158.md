# 0.4.158 — Quieter notification defaults

- Waiting-customer reminders default to 70% volume instead of 100%.
- Quick-reply suggestion sounds are disabled by default; they can still be
  enabled in `/hcsounds`.
- Explicitly saved sound preferences are preserved, including zero reminder
  volume and enabled quick-reply sounds. Other alert volumes and reminder
  timings are unchanged.
- Regression checks cover settings defaults, sound playback before opening
  settings, built-in and bundled sounds, and saved preference overrides.
