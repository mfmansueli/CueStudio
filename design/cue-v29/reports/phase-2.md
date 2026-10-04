## Phase 2 · Models and migration — report
Built: ✓ · Warnings: 0 · Tests: 1995 passed / 64 new (the one failure, `ScriptAIServiceTests/privateCloudComputeIsOnOnlyWithTheEntitlement`, is the known sandbox issue, unrelated)

### Done
- `Script.isFinished` + `ScriptState` (L1): `Models/Script.swift`, `Models/ScriptState.swift`, `ScriptLibraryService.setFinished/create(isFinished:)`.
- `ScriptType.mythFact` / `.pov` (L3): `Models/ScriptType.swift`, `ScriptType+Brief.swift` (structure, brief, tip, offline draft).
- `BrandBrief` + `BrandStore` + `BrandRepository` (L4), wired in `AppServices` / `LaunchOptions` (in-memory under `-uiTestInMemory`); `ScriptRequest.brand`; `ScriptPromptBuilder.brandLines`.
- `CreatorProfile` new fields, `voiceStrength`, `nextQuestion`, `Swearing`, `VoiceExample`, `VoicePersonalityItem`; `CreatorVoice` + `ScriptPromptBuilder.voiceLines/voiceBrief` carry them (L11).
- `PrompterSettings.boxWidth/boxHeight/readingLine` (L8) as views over the stored box and line (see below).
- `SkyMemory` + `StarPoint` (L16), `DefaultsKey.skyMemory*`.
- 43 new strings in 20 languages (`Localizable.xcstrings`); tools `add_strings.py`, `missing_strings.py`.

### Fixture table (v27 → v29, same visible values)
| Fixture | Field | v27 value | v29 reads |
|---|---|---|---|
| `scripts.json`, `ad` script with text | `isFinished` | absent | `true` (READY) |
| `scripts.json`, empty script | `isFinished` | absent | `false` (DRAFT) |
| `scripts.json`, script with `"type":"holographic"` | `type` | would have failed the whole library | `nil`, text/title kept, library opens |
| same three scripts | id, title, text, version, folder, topic | as saved | identical |
| old `ad` brief (brand, benefit, offer) | `BrandStore` | none | one brand; adopting twice keeps one |
| profile with no new fields | name, handle, niches, customTopics, phrases, role, sounds, vocabulary, defaultPlatform | as saved | identical; `openings/endings/formats/examples/customTags` empty, `swearing` nil, `hasMinimumVoice` unchanged |
| prompter settings v27 (`readingWidth` .75, `textWindowHeight` 300, `readingLineOffset` 40) | `boxWidth/boxHeight/readingLineOffset` | — | .75 / 300 / 40 |
| prompter settings with no box | box and line | — | 0.93 / 380 / recommended spot (118 pt under the lens) |
`voiceStrength` of a v27 profile with its audience and tone confirmed counts them (legacy "unverified" steps count as chosen, like the screens already show them).

### State tests (04 §F2)
Every row: LET'S CUE!/format written by AI → READY; Write it myself → DRAFT; Start from a format → DRAFT; edit after recording stays RECORDED (and the strip rule `version > take.scriptVersion`); duplicate inherits; Shape never changes it (it doesn't touch `isFinished`).

### Captures
- none: no visible change in this phase.

### Animations (measured)
| name | duration | curve | Reduce Motion |
| — | — | — | — |

### Not matched exactly
- `PrompterSettings.boxWidth/boxHeight/readingLine`: 06 says width and height in points and the line 0.10–0.50 defaulting to 22% · the app already stores the box as `readingWidth` (fraction of the screen) and `textWindowHeight` (pt) and the line as points under the lens, so the v29 names are computed views of those (nothing saved twice, v27 settings keep their size). Width stays a fraction so it fits any iPhone; an absent line keeps today's 118 pt (≈17%) because the migration must not move it.
- `nextQuestion` order is the prototype's (endings, openings, formats, then swearing, phrases); 04 §F9 lists the items without an order.
- `SkyMemory` positions are a deterministic low-discrepancy sequence instead of the prototype's random scatter (same look, stable across launches).

### Kept from v27 that the board doesn't show
- The old per-format brief fields (`briefFields`) stay for the non-ad formats and as the offline fallback; ad scripts built from a `BrandBrief` replace the ad fields in the prompt.

### Next phase starts with
- Scripts and creation (3.1, 3.2, 3.5, 3.6, format sheet, brand brief sheet, import review, Logbook "✦ Write", empty states) reading `Script.state`, `SkyMemory`, `BrandStore`.
