## Phase 4 · Script page — report
Built: ✓ · Warnings: 0 · Tests: unit suite green (the known `ScriptAIServiceTests/privateCloudComputeIsOnOnlyWithTheEntitlement` sandbox failure aside) / ~35 new (`ScriptStripTests`: strip, rules, cue shaper, AI passage; `ScriptPageViewModelTests` rewritten) · UI: `ScriptPageUITests` green; the tests that used `page.mode.*`, `page.draftEditor` and the old Rec were updated

### Done
- **4.1 one page, no Draft | Shaped** (`ScriptPageView`, `ScriptPageTopBar`: back, platform chip, •••): state strip, length bar, Hook / ✦ Improve / Aa, always-editable words (`ScriptTextEditor`, `AttributedString` + selection), tips, takes and **one** Record at the bottom (`ScriptRecordBar`).
- **State strip** (`ScriptStateStrip`, `ScriptStrip`): READY / DRAFT / RECORDED chip, "LIST · 4 CUES" / "EDITED · TAP DONE" / "CHANGED SINCE TAKE n", ✦ Shape (only with 0 cues and AI), Done.
- **Shape is a tool** (`ScriptCueShaper`): adds up to 4 cues, never touches the words or the state; cue bar above the keyboard (`ScriptCuesBar`).
- **04 · F2 states** (`ScriptPageRules`): Done → READY, "Nothing to save yet", "{n} sections are still empty" → Done anyway / Keep writing, edit + leave → DRAFT with "Saved as draft" (also when the app goes to the background).
- **AI bar on a selection** (`AISelectionBar`, `AIPassage`, `SelectionAction`): Rewrite · Shorter · Punchier · More me · Cut; replaced in place in violet, then Keep / Undo / Try again.
- **No AI**: no ✦ Shape, no Improve, no bar, no "Improve with Cue" in •••.

### Captures (`design/cue-v29/reports/captures/`)
- `4.1_ready.png`, `4.1_recorded.png`, `4.1_recorded_changed.png`, `4.1_no_ai.png`, `4.2_draft.png`, `A_ai_bar.png`, `A_ai_replaced.png`

### Animations (measured)
| name | duration | curve | Reduce Motion |
| AI bar in / out | 0.3 s | smooth | fade |
| replaced passage (violet wash) | instant, no animation | — | same |

### Not matched exactly
- **Keep on tap-outside**: the passage is kept when the creator edits, selects other words or leaves, not on a tap in empty space (the page has no empty space to tap).
- **Tips** (long hook, long sentence, no CTA) are neutral text readings, not violet AI: they are computed on the device without a model.
- **The old yellow Rec of the top bar** moved to the bottom bar (one Record per screen).

### Kept from v27 that the board doesn't show
- The full "Versions & options" editor, Hook, Improve, Aa, Script details, versions on edit after a take, and the takes strip stay in ••• and under the text.

### Next phase starts with
- Recorder: shrinking box, pinch on the reading line, Studio that records, F3 failures.
