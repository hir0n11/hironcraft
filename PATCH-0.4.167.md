# 0.4.167 — Keep custom replies directly accessible

- Custom explanations stay inline in the chat-name menu, including on short
  screens and with long reply lists. There is no automatic Custom Explanations
  submenu or automatic grouping of all addon actions.
- Overflow uses native menu scrolling instead. Normal font size, bounded
  label widths and full-label tooltips from 0.4.166 remain unchanged.
- The explicit collapse preference is still respected: when enabled, replies
  appear directly inside the chosen HironCraftScan branch, without another
  explanations submenu. Manual matching can still fold automatically.
- Regression checks cover direct access to every reply at multiple screen
  sizes, optional grouping, saved preferences and ordinary/Battle.net actions.
