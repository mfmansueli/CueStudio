## Phase 9 · Settings, empty states and final pass — report
Built: ✓ · Warnings: 0 (clean build, simulator SDK; device SDK and Release checked at the end, see the final report) · Tests: see the final report / 6 new unit · UI: `SettingsUITests` (+2), `LanguageRegionUITests`, `CreatorSetupUITests`, `OnboardingUITests` (+1), `FirstRunUITests` green

### Done
- **11.1 Settings**: Recording, Remote and Language & Region are sheets (`SettingsSheet`), Prompter / Personalize / Acknowledgements stay pushed; new **Cue Pro** row (→ 11.4) next to Restore purchases; 16 pt between blocks (`Metrics.blockGap`).
- **F8 Privacy & AI data**: **Delete my Cue data** with a confirmation alert, irreversible (`DataEraserService`); the purchase, the free-export counter, the language and Photos are untouched.
- **F8 Remote**: OFF → WAITING (yellow) → CONNECTED (green) → OFF and the failure with *Try again* were already built (v27 `RemoteStatusHero`, `RemotePairingPanel`) and are now inside the sheet; `CreatorSetupUITests` covers the pairing.
- **1.2 / 3.2 / 10.2** gaps closed (own topic validation, chip → 9.3, comment reply: Write it myself + Save to Logbook).
- **L13 empty states**: Scripts, Scripts-filter, Takes, Logbook, Your universe (all pattern E).

### Checklist of 03-Screen-map
✓ = as the board; ◐ = built with a stated difference; ✗ = not built.
- **1 First launch**: 1.1 ✓ · 1.2 ✓ (blocked word + typo inline) · 1.3 ✓ · 1.4 ◐ (no "rewrite by selection" bar in the first script: the card is a preview; *Write my own* → the script page has the bar) · 1.5 ✓ · 1.6 ✓ · 1.7 ◐ ("Go to my studio" / "Edit this take first")
- **2 My Cue Voice setup**: 2.1 ◐ (8 creator types, no "+ Something else") · 2.2 ◐ (8 topics, no "+ Your own" in the sheet, the typo check is on the free-text rows) · 2.3 ◐ (4 audiences, not New/Some/A lot + free field) · 2.4 ✓ (max 2 toast "Max 2 · tap to remove") · 2.5 ✓ (the script is the preview)
- **3 Scripts**: 3.1 ✓ · 3.2 ✓ (chip ✦ Voice → 9.3 in a sheet, not a push) · 3.3 ✓ · 3.4 ✓ · 3.5 ✓ · F ◐ (12 tiles) · B ✓ · I ✓ · 3.6 ✓
- **4 Script**: 4.1 ✓ · 4.2 ✓ · 4.3 ✓ · 4.4 ◐ (no AI quota: always free, so no 11.4 hop) · A ◐ (Keep also on edit / other selection / leaving, not on a tap in empty space)
- **5 Recording**: 5.1 ✓ (the end-of-countdown flare was removed on request) · 5.2 ✓ · 5.3 ◐ (the corner thumbnail is the rear camera; a "no camera" placeholder in the Simulator)
- **6 Takes**: 6.1 ✓ · 6.2 ✓ · 6.3 ✓
- **7 Editor**: 7.1 ◐ (overlay while the take is read, not a fixed 2.8 s) · 7.2 ◐ (panels fixed-height, content still scrolls inside as a safety) · 7.3 ✓ · 7.4 ✓ · 7.5 ✓ · 7.6 ✓ · 10.4 ✓
- **8 Share**: 8.1 ✓ · 8.2 ✓ · 8.3 ✓
- **9 Profile**: 9.1 ✓ · 9.2 ✓ · 9.3 ✓ (taxonomy smaller than the prototype)
- **10 Comments**: 10.1 ◐ (screenshot or paste → the confirm step; Save to Logbook is on 10.2) · 10.2 ✓ · 10.3 ◐ (Record reply is the page's Record) · 10.4 ✓
- **11 Settings and Pro**: 11.1 ✓ · 11.2 ✓ · 11.3 ✓ ("Your topics" opens the My Cue Voice topics question) · 11.4 ✓
- **Empty states**: E-3.1 ✓ · E-6.2 ✓ · E-3.6 ✓ · E-9.2 ✓ · E-3.2f ✓

### Captures
- `9.2_universe_empty.png`, `11.4_pro.png`, plus the earlier phases' sets in `design/cue-v29/reports/captures/`

### Animations (measured)
| name | duration | curve | Reduce Motion |
| Settings sheets | system sheet | spring | system |

### Not matched exactly
- **"Help improve"** in Privacy & AI data: the app collects nothing, so there is nothing to opt into.
- **Light mode**: there is none (dark only since v27).
- Everything marked ◐ above.

### Kept from v27 that the board doesn't show
- Personalize (sky, haptics, celebrations, app icons), Language & Region's three languages, the exports meter, Studio mode and Share-to's captions and cover options.
