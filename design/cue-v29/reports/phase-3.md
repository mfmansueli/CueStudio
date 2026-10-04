## Phase 3 · Scripts and creation — report
Built: ✓ (clean build, new derived data) · Warnings: 0 · Tests: 2020 unit tests passed (`ScriptAIServiceTests/privateCloudComputeIsOnOnlyWithTheEntitlement` is the known sandbox failure; `QuickCreatorExportTests/doubleSpeed…` timed out once under load and passed alone) / ~60 new · UI: the 31 tests that the redesign broke were fixed and re-run green (`ScriptLibraryUITests`, `FirstRunUITests`, `GenerateScriptUITests`, `FreePlanUITests`, `PrompterUITests`, `CueUniverseScreenshotTests`) · new `ScriptsV29UITests` (5) and `CreationSheetsUITests` (7)

### Done
- **3.2 Scripts**: READY TO RECORD / DRAFTS / RECORDED groups, "8 SCRIPTS · 3 READY", network filters, rows with ThemeRail + PlatformDot + "TIKTOK · 0:47 · 4 CUES" and `RecPill` / "Continue ›" / "×n ›", swipe left = Record + More, long press = preview + menu, Undo (4 s) on delete (`ScriptsView`, `ScriptsViewModel`, `ScriptRow`, `ScriptGroup`, `ScriptRowLine`).
- **LET'S CUE! card**: "↻ Another idea", suggested idea, chips Format ⌄ · For {P} ⌄ · ✦ Voice nn%, neutral "Write it" card without Apple Intelligence (`IdeaPromptCard`, `MyCueVoiceChip`, `PromptCardSurface`, `IdeaDraftService`).
- **"Your stars" (L16)**: the star rises from the arrow, glints, stays in the sky above Scripts (`SkyMemory.launchStar`, `StarFlightOverlay`, `SkyStarsLayer`).
- **3.1 first visit** (`EmptyLibraryView`): card, empty-state mark, 3 ideas (tap = write), Write my own ›, Import ›.
- **3.5 Start a video**, **Format sheet** (12 tiles, modes card/blank), **Brand brief**, **Import with review**, **Logbook ✦ Write + empty state** (`NewScriptSheet`, `FormatSheet`, `FormatTile`, `FormatChoice`, `BrandBriefSheet`, `BrandBriefViewModel`, `ImportScriptSheet`, `LogbookView`).
- States: Write it myself / Start from a format → DRAFT; AI delivering → `isFinished`; Import → READY (04 · F2).
- 75 new strings in 20 languages; `missing_strings.py` now uses `xcodebuild -exportLocalizations`, so ternaries and `LocalizedStringKey` parameters are found too.

### Captures (`design/cue-v29/reports/captures/`)
- `3.1_first_visit.png`, `3.1_no_ai.png`
- `3.2_scripts.png` (normal: groups, chips, REC / Continue ›), no AI = `3.1_no_ai.png`; filter/search with no result: asserted by `ScriptsV29UITests` (`scripts.empty`), the unit tests cover platform/folder/search
- `3.5_start_a_video.png`, `F_format_card.png`, `F_format_start.png`, `B_brand_brief.png`, `I_import.png`, `3.6_logbook_empty.png`

### Animations (measured)
| name | duration | curve | Reduce Motion |
| star to the sky (flight) | 760 ms | cubic-bezier(.35,.1,.25,1) along a quadratic curve, scale 1 → 0.55, 6 trail dots | none: waits 150 ms |
| star glint (4-point, fades and turns 45°) | 380 ms wait + 500 ms fade | ease-out | none |
| total until the script opens | 1140 ms | — | 150 ms |
| sky stars twinkle | 4 s | sine | still (also Low Power, inactive app) |

### Not matched exactly
- **Card ambient sky** (dust, nebula, glints, shooting star inside the card): its values are in `motion/` (stage 3 of the package, not delivered) · the existing aurora and light border stay.
- **Format sheet has 12 tiles, not 11**: Hot take / reply (`opinion`) is kept so no format is lost.
- **Brand brief button** reads "✦ Write the ad" only when it writes (card, with Apple Intelligence); from "Start from a format" or without Apple Intelligence it reads "Open the draft".
- **"Another idea" suggestion** is shown as the field's placeholder and written by the arrow when nothing is typed (the board shows it as typed text).
- **Row tap on a RECORDED script** goes to the Takes tab (03 · 3.2); its page is "Open script" in the long-press menu.
- **Import** has no separate "Scan/Photo permission" screen for the photo picker (it needs none); the camera card appears for Scan only.

### Kept from v27 that the board doesn't show
- Studio mode on a row: long-press menu ("Studio mode") and More; Share, Duplicate, Move to folder, Script Language, Make a version: long-press menu.
- The switch "Use my voice in AI scripts" on the card's voice chip: Profile has the same switch (and 9.3 will).
- "Need an idea?" chip: "+" › Let Cue write it (3.3); first visit has its ideas.
- "Record without a script": first visit link and "+".

### Next phase starts with
- Script page (4.1–4.4, 10.3, 1.4): state strip, no Draft | Shaped switch, AI bar on a selection, Done anyway / Keep writing, Saved as draft.
