# 0.4.160 — Reminder volume defaults to 50%

- Waiting-customer reminders now default to 50% volume instead of 70%, both
  before opening settings and in the settings slider's default value.
- Explicitly saved volume choices are preserved. Other alert volumes,
  reminder timings and the silent quick-reply default are unchanged.
- Regression checks cover built-in and bundled sound playback at 50%,
  settings defaults and saved volume overrides, including the previous 70%.
