# PROMPT for Claude Code · Cue Studio v30

You are implementing Cue Studio v30 in this repository (SwiftUI, iOS 27, Swift 6). The design is final. **Do not ask for confirmation of anything written as a decision.** Work phase by phase, without stopping between phases, and write the report at the end of each one.

## 0. The only source
Use **only** `design/cue-v30/`. Its `SCREENS.md` lists the approved screens; nothing else is in scope. Do **not** read or implement anything from `design/cue-v29/`, `design/cue-universe-v27/`, older prototypes or option/test files. Where those disagree with v30, v30 wins. If a screen is not in `SCREENS.md`, it does not exist.

## 1. Read first, in this order
0. `design/cue-v30/SCREENS.md`: the approved screens and their files
0b. `09-Decisions.md`: **final answers to the open questions (formats, dock, tip, Record tab, My Cue Voice data, motion, statics, star transition, VoiceOver). It wins over every other doc.** Then `motion/README.md` and `strings-en.csv`.
1. `design/cue-v30/LEIA-ME.md`
2. `01-Direction.md`: what v30 is (the v30 prototype brought into the app, keeping every existing feature)
3. `02-Tokens.md`: colours, type, spacing, materials, icons, sliders, "never do"
4. `03-Screen-map.md`: every screen, how you get there, what each tap/gesture does, the transition, what happens on back and on failure
5. `04-Flows-and-states.md`: state machines (first launch, create, record, pick, edit, export, Pro, settings, My Cue Voice) and global states
6. `05-Function-and-logic-changes.md`: L1–L16 + data migration
7. `06-Data-map.md`: where each piece of data comes from, what exists and what is new
7c. `08-My-Cue-Voice-questions.md`: when the My Cue Voice tip appears, which question, the complete question bank and the strength weights (implement as `VoiceQuestionScheduler` + TipKit)
7b. `07-Liquid-Glass.md`: **mandatory** — native Liquid Glass wherever it exists; simulated glass only for custom components; content cards translucent
8. `prototype/Cue App v30.dc.html`: open it in a browser with a local server (`python3 -m http.server` in `design/cue-v30/prototype`). Use *Jump to any screen* to reach any ID. The recorder is `CueRecorder30.dc.html`. The empty states are under **APP DATA › New account**.
9. `DESIGN_PROJECT.md`, `ARCHITECTURE.md`, `LOCALIZATION.md` and the code in `Cue Studio/`: the engineering you reuse.

## 2. Rules of the game
- **Precedence:** design docs > prototype > current code. When the prototype and the code disagree, **the prototype wins**. When a doc and the prototype disagree, the doc wins.
- **Closed decisions:** everything in 01–06 is decided. Pick the documented option; don't propose alternatives.
- **[NEGÓCIO]: none.** Do not change: 5 free exports (counter in the Keychain), 7-day trial, $39.99/year (prices always from StoreKit), AI quota, Takes pipeline.
- **Keep every feature that already exists.** If a v27 screen has a function the v28 board doesn't show, keep it in the closest place and list it in the report.
- **Still requires care:** (a) data migration (05 §Migration) with fixture tests before any change to the models; (b) App Store: permission texts, Restore purchases visible on the paywall, privacy policy reachable, permissions requested only at the moment of use; (c) irreversible actions (delete data, delete a script) always with an alert or Undo.
- **Limits:** everything runs on the device; no server; AI only through Apple Intelligence (the app works without it; see the "No AI" states); there is no API to post: export → Photos → open the network's app.

## 3. Requirements for every phase
- **Liquid Glass (07-Liquid-Glass.md):** use native SwiftUI components first (`TabView`, `NavigationStack` + `.toolbar`, system back button, `.buttonStyle(.glass)` / `.glassProminent`, `.glassEffect`, `GlassEffectContainer`, `.sheet`, `Menu`, `.searchable`). Build a custom control only when no native one exists, and then use the simulated-glass recipe in §2. No solid buttons in navigation/tool/tab bars. Report every custom glass component and why it isn't native.
- Zero warnings; Swift 6 strict concurrency; no force unwraps in new code.
- Texts in `Localizable.xcstrings` in **20 languages**; toast ≤ ~28 characters, helper text ≤ ~60, one sentence; check German, Arabic and Japanese.
- **Reduce Motion** and **Low Power Mode**: a static version of every animation (see `02-Tokens` and, from Stage 3 on, `motion/`).
- **Accessibility:** VoiceOver labels and order on new elements; 44 pt targets; text contrast ≥ 4.5:1 (`PaletteContrastTests`); Dynamic Type up to `.accessibility5` (single column, chips wrap).
- **RTL:** mirrored layout, except media controls (play, ⤒, timeline).
- **Tests** in every phase: unit tests for the new logic + snapshots of the screens you touched.
- Each phase builds, runs and can ship on its own.

## 4. Phases

### Phase 1 · Foundation
**Goal:** visual system with no layout changes.
**Includes:** new tokens (02 §1.2), Liquid Glass `CueTabBar` with the capsule (L10), v30 icons (02 §5), `OrbSlider` → `CueSlider` (L9, ranges in 02 §6), components `ThemeRail`, `PlatformDot`, `RecPill`, `StateChip`, `EmptyState`, microcopy (L15).
**Code:** `DesignSystem/Tokens`, `DesignSystem/Components`, `CueIcon`, `Localizable.xcstrings`.
**Acceptance:** every screen shows the new tab bar, icons and sliders; `PaletteContrastTests` covers the new pairs; no layout regressions.
**Report:** tab bar with each tab active; slider at min/default/max; each component; tests.

### Phase 2 · Models and migration
**Goal:** the data the v30 screens need, with no visible change.
**Includes:** `Script.isFinished` + `Script.state` (L1), `ScriptType.mythFact` and `.pov` (L3), `BrandBrief` + `BrandStore` (L4), new `CreatorProfile` fields + `voiceStrength` + `nextQuestion` (L11), `PrompterSettings.boxWidth/boxHeight/readingLine` (L8), `SkyMemory` (L16).
**Code:** `Models/`, the matching services, `ScriptPromptBuilder` (passes the brand brief and the voice brief).
**Acceptance:** v27 fixtures decode with the same visible values (05 §Migration); `state` tests for every row of 04 §F2; an `ad` brief migrates to `BrandStore` once.
**Report:** fixture table before/after; tests.

### Phase 3 · Scripts and creation
**Goal:** 3.1, 3.2, 3.5, 3.6 and the import/format/brand sheets.
**Includes:** 3.2 with the LET'S CUE! card (Format · For {P} · ✦ Voice nn% chips), READY/DRAFT/RECORDED groups, network filters, rows with ThemeRail + PlatformDot + "TIKTOK · 0:47 · 4 CUES" + RecPill or Continue ›; the "Your stars" sky (L16); 3.1 first visit (ideas + Write my own › + Import ›); 3.5 New script (Let Cue write it · Write it myself · Start from a format · Import · Answer a comment · Record without a script); format sheet (11 tiles, L3); brand brief (L4); Import sheet with review (L5); Logbook "✦ Write" (L7); empty states (L13).
**Acceptance:** each row of the 04 §F2 table reproduced on the device; the filter with no results shows E; with no AI the card shows "Write it" and nothing violet.
**Report:** captures of 3.1, 3.2 (normal, empty, filter with no results, no AI), the sheets; the time of the "star to the sky" animation.

### Phase 4 · Script page
**Goal:** 4.1, 4.2, 4.3, 4.4, 10.3, 1.4.
**Includes:** state strip (state · format · cues · next step: DRAFT = yellow Done; READY = Done as text + ● Record only when the screen has no other record button; RECORDED = Retake + "CHANGED SINCE TAKE n"); Shape as a tool when there are 0 cues (L2); **remove the Draft | Shaped switch**; AI bar on a selection with Keep/Undo/Try again (L6) and the visible buttons for Rewrite/Shorter/Punchier where the board shows them; "Done anyway / Keep writing" for empty sections; "Nothing to save yet".
**Acceptance:** **exactly one** record button and **one** yellow fill per screen; edit + back → DRAFT with a toast; edit after recording stays RECORDED.
**Report:** captures in each state; video/frames of the AI bar.

### Phase 5 · Recorder
**Goal:** 5.1, 5.2, 5.3 (prompter) faithful to `CueRecorder30.dc.html`.
**Includes:** bar with a background (night glass) in IDLE; **compact bar** while RECORDING (Stop, yellow mono time, mode, ⤒) and tapping the screen shows the full bar for 4 s (L8); the text box shrinks with focus on Record; handle ⌟ resizes the box; the pinch on the right edge adjusts the reading line; Voice | Steady; Aa; ring-of-stars countdown; Selfie and Studio modes (the back-camera thumbnail never covers the box). **Remove "Hide controls while recording"** and its button.
**Acceptance:** F3 in 04 including no mic / no speech / storage full / interruption; box and line persist in `PrompterSettings`.
**Report:** captures IDLE/RECORDING/compact in Selfie and Studio; transition durations measured.

### Phase 6 · Takes, review and editor
**Goal:** 6.1, 6.2, 6.3, 7.1–7.6.
**Includes:** pipeline TO PICK › IN EDIT › READY › SHARED with E when empty; 6.3 with ★ filled when best; Delete with 4 s Undo; editor in CapCut order with ✦ Smart last (violet), panels with a fixed height (nothing scrolls vertically), no controls in the bottom 34–44 pt, selected clip = white frame + yellow handles, Delete fixed bottom-right in red, coloured lanes; back = draft; Done → 7.6 "Is it ready to post?" with the 4 options (F5).
**Acceptance:** F4 and F5 in 04; going back from the editor reaches Takes.
**Report:** captures of each panel; the 7.6 sheet; tests of the derived stage.

### Phase 7 · Share, Universe and Pro
**Goal:** 8.1, 8.2, 8.3, 9.2, 11.4.
**Includes:** AD warning + #ad on 8.1; export with progress and error (F6); 9.2 with the animated core "YOU" (no photo, L12); Pro on the night aurora with Restore purchases visible (F7, no changes to rules).
**Acceptance:** 5th export → paywall; cancelling a purchase goes back with no message; no internet → "Can't reach the App Store".
**Report:** captures; the export path with numbers.

### Phase 8 · Profile and My Cue Voice
**Goal:** 9.1, 9.3, the row sheets, 2.1–2.5 and the nudges.
**Includes:** the 3 layers (Essentials, Personality, Proof) with `voiceStrength` (weights in `08` §1); the tip + sheet with `VoiceQuestionScheduler` following `08` §2–§6 exactly; validation (typo, blocked word, duplicate, limits) from 04 §F9; nudges on Scripts/Takes with *None of these* / *+ Something else* / *Not now* (3 days); "What Cue sends" visible.
**Acceptance:** each validation in F9; no AI → "Needs Apple Intelligence" with the data still editable.
**Report:** captures of each sheet and validation.

### Phase 9 · Settings, empty states and final pass
**Goal:** 11.1–11.3, the Recording/Remote/Language/Privacy sheets (L14), every empty state (L13), the full light mode where it exists today, and a pass over all of 03-Screen-map.
**Acceptance:** each row of 03 checked; "Delete my Cue data" with a confirmation alert; Remote OFF → WAITING → CONNECTED → OFF.
**Report:** a checklist of every screen in 03 with ✓/✗ and the reason.

## 5. Report at the end of each phase (format)
```
## Phase N · <name> — report
Built: ✓/✗ · Warnings: 0 · Tests: X passed / Y new
### Done
- <screen/flow>: <what was implemented> (files)
### Captures
- <ID>_<state>.png …
### Animations (measured)
| name | duration | curve | Reduce Motion |
### Not matched exactly
- <item>: <why> · <what was done instead>
### Kept from v27 that the board doesn't show
- <function>: <where it went>
### Next phase starts with
- …
```
