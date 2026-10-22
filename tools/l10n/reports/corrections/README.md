# Corrections applied in the October 2026 review

`<lang>-corrections.json`: what each reviewer changed, in the format `tools/l10n/review.py apply <lang> <file>` takes
("<catalog>|<key>" → the corrected value). `extra/`: the split keys (`new-keys.json` for `scripts/strings.py add`,
`fix-<lang>.json` for Back and Shape), and the numbered placeholders (`order-<lang>.json`).

Kept so the review can be re-applied on a catalog that changed underneath (a rebase): `apply` writes each value again and
skips the ones already equal. Order: `new-keys.json`, then `fix-*`, then `order-*`, then the language files last (the
reviewers refined the split keys and some numbered strings afterwards, so an earlier file must not overwrite them). The French file
lost its "Back" entry on purpose (the key was split while it was being reviewed).
