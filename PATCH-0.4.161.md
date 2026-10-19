# 0.4.161 — Visible slider values and non-overlapping sound previews

- Volume sliders now display percentages; reminder timing sliders display
  seconds. The profession-icon scale also shows its percentage.
- Dragging stops the previous preview and waits for release before playing
  one sample at the latest selected volume. Duplicate settings callbacks do
  not start additional samples or read the previous saved volume.
- Listen buttons and sound selectors replace only earlier preview handles.
  Real notifications are never stopped by a preview and cancel queued samples.
- Zero volume, No sound, closing settings and logging out stop previews and
  cancel pending samples. Listen buttons also work before the sound choice
  has been saved.
- Existing saved preferences, 50% reminder default, silent quick-reply default
  and reminder delays are unchanged.
- Green-row confirmations also recognise `on air`, `inc`, `incoming`, `otw`,
  `posted`, `submitted`, `placed`, additional send typos and immediate-send
  shorthand such as `imma send rn`. Short acknowledgements accept courtesy
  padding, but not negations, questions, delayed/conditional promises or mats.
  Custom confirmation phrases use the same negative/future-context guards.
- Requests such as `log Lavu` and `can u log Lavu?` also highlight the matching
  crafter's active row green, without colouring other crafters in the inquiry
  or completing the craft. Bare `log`, unrelated/unknown names and future
  login promises do not qualify. Ambiguous `omw`, `rdy` and `all set` stay yellow.
