# 05 · Function and logic changes (v30)

**[NEGÓCIO]: none.** Exports (5 free, counter in the Keychain), the 7-day trial, $39.99/year, the AI quota and the Takes pipeline **do not change**.

| # | What it was (v27) | What it becomes (v30) | Why | Affects |
|---|---|---|---|---|
| L1 | Script with no state of its own (list sorted by date) | **READY / DRAFT / RECORDED** state derived from `isFinished` + takes (04 §F2) | Shows what can be recorded now | `Script` (+`isFinished: Bool`), `ScriptLibraryService`, 3.2, 4.1, 4.2 |
| L2 | Draft \| Shaped switch | Removed. **Shape** is a tool on the strip (only when there are 0 cues) | "Shaped" didn't mean "finished" | 4.1/4.2, `ScriptTool` |
| L3 | Format picked in the brief | **Format sheet**: 9 tiles + “More formats” with every other existing type (nothing removed). New cases `talkingHead`, `mythFact`, `pov`. **Exact rule: 09 §1** | Visual choice next to the idea | `ScriptType`, `ScriptType+Brief`, the 3.2 dock, 3.5 |
| L4 | Ad brief as fields of the `ad` type | **Brand brief** (brand*, product*, must say, never say, link, code) + **saved brands** + `#ad` always on and carried through to Share | The AI never invents claims; brand reuse | `BrandBrief` (new), `BrandStore` (new, JSON in Application Support), `ScriptPromptBuilder`, 8.1 |
| L5 | Import inside the editor | **Import sheet** with review (Paste/Scan/Photo/File) → *Use this script* = Done (READY) | Fix the OCR before using it | 3.1, 3.5, `ScriptStarter` |
| L6 | Rewrite only for the whole script (4.4) | + **AI bar on a selection** (Rewrite/Shorter/Punchier/More me/Cut) with Keep/Undo/Try again | Fine-tune one sentence | `ScriptAIService.rewrite(range:kind:)` (new), 4.1, 4.2, 10.3, 1.4 |
| L7 | Logbook "Shape" | **"✦ Write"** (turns the idea into a script) | Shape only means "add cues" | 3.6 |
| L8 | Recorder with the bar always full | **Compact bar** while recording; box shrinks with focus; handle ⌟ (resizes the box) and reading-line pinch | Fewer controls while you speak | `PrompterViewModel` (+`isCompact`), `PrompterSettings` (+`boxWidth`, `boxHeight`, `readingLine`) |
| L9 | Orb slider | **Simple slider** (same math, new visual, ranges in 02 §6) | Less stimulus; accessibility | `OrbSlider` → `CueSlider` (rename) |
| L10 | Tab bar with the travelling orb | **Liquid Glass + capsule** | Native shape | `CueTabBar` |
| L11 | My Cue Voice through the onboarding screens | **Full page 9.3** + sheet per row + nudges + validation (04 §F9) | Personalising without a form | `CreatorProfile` (+ fields below), `CreatorProfileService`, 9.1, 9.3 |
| L12 | Universe with the creator's photo at the centre | **Animated core "YOU"** | Image/rights; a calmer look | 9.2, `FirstStarView` |
| L13 | Empty state only on Scripts | Pattern **E** on Takes, Logbook, Universe, filter with no results | Consistency | 6.2, 3.6, 9.2, 3.2 |
| L14 | Settings in pushes | **Sheets** Recording / Remote / Language / Privacy | Fewer levels | 11.1 |
| L15 | Toast and helper texts without a limit | ≤ ~28 / ≤ ~60 characters (`CUE_COPY` rules) | 20 languages | `Localizable.xcstrings` |
| L16 | — | **"Your stars"**: each sent idea adds a star to the sky above Scripts (max 14 visible) | Discreet reward | `SkyMemory` (new, UserDefaults, `[StarPoint]`) |

## Data migration (nothing is lost)
| Data | Where it is | v30 migration |
|---|---|---|
| `Script` | `LocalScriptRepository` (JSON) | new field `isFinished: Bool` — `decodeIfPresent`; **if missing: `true` when `!isEmpty`, `false` when empty**. No script changes text, id or version. |
| `ScriptType` | inside `Script.type` | unknown cases (saved by a newer build) read as `nil` (current pattern). Existing cases unchanged. |
| ad brief | `ScriptType+Brief` fields in the script | stays where it is; on opening an `ad` script with no `BrandBrief`, Cue builds the brief from the existing fields (brand ← "brand", product ← "product"…) and **saves the brand once** in `BrandStore`. |
| `CreatorProfile` | `CreatorProfileService` | new optional fields: `openings`, `endings`, `phrases`, `swearing`, `formats`, `examples` (≤3), `customTags`. Absent = empty. Existing fields keep their names. |
| `PrompterSettings` | UserDefaults | `boxWidth`/`boxHeight`/`readingLine` absent → current values (box = today's size; line = 22%). |
| Takes, `QuickEditDraft`, exports, Keychain | as they are | unchanged. |
**Mandatory test:** decoding v27 fixtures (script with no `isFinished`, `ad` script with the old brief, profile with no new fields) produces the same visible values.
