## Phase 8 · Profile and My Cue Voice — report
Built: ✓ · Warnings: 0 (clean build at the end of the run) · Tests: unit suites green / 19 new (`VoiceValidationTests`: validator, edits, nudges) · UI: `VoiceV29UITests` (5 new) and `ProfileUITests` green (12)

### Done
- **9.1 Profile card**: meter ("VOICE 65% · GOOD START"), one sentence, live preview, next question with *Answer*, switch, *Edit voice ›* (`MyCueVoiceCard`, `VoiceMeter`, `CreatorProfile.voiceLevel` / `voiceSentence`).
- **9.3 full page** (`MyCueVoicePage`): the 3 layers with their points (Essentials 60 · Personality 25 · Proof 15), one sheet per row (`VoiceSetupSheet` for the four essentials, `VoicePersonalitySheet`, `VoiceExamplesSheet`), "What Cue sends" (`ScriptPromptBuilder.voiceBrief`), no-AI note with the data still editable.
- **F9 validation** (`VoiceTextValidator`, `CreatorProfileService+Personality`): 2–40 characters, typo → "Did you mean “…”? Use · Keep mine", blocked word → not saved, duplicate → "Already added.", limits → "Max n …" toast (topics 3, tones 2, openings 2, endings 2, phrases 5, formats 3, examples 3).
- **Nudges** (`VoiceNudgeService`, `VoiceNudgeCard`, `VoiceNudgeSlot`) on Scripts and Takes: one question at a time, *None of these* (retires it, `declinedVoiceItems`), *+ Something else*, *Not now* = 3 days (persisted); nothing without Apple Intelligence or before the minimum voice.
- 52 new strings in 20 languages; data: `CreatorProfile.declinedVoiceItems` (absent = empty, covered by the migration tests).

### Captures
- `9.1_profile_voice.png`, `9.1_nudge.png`, `9.3_my_cue_voice.png`, `9.3_validation_typo.png`, `9.3_validation_blocked.png`, `9.3_no_ai.png`

### Animations (measured)
| name | duration | curve | Reduce Motion |
| meter fill | none (follows the data) | — | same |
| live sentence on Profile | 0.25 s | smooth | fade |

### Not matched exactly
- **Taxonomy**: the prototype has 18 topic categories with subtopics, 8 tones, a "why do they watch you" list and languages/platforms rows; the app keeps its 8 topics, 6 tones and 4 audiences (the AI instructions and the 20-language catalogs are built on them). The three layers, the validation and the nudges are all there.
- **Blocked-word list** is a stem list in code (several languages), not Apple's own filter, which has no public API: it stops the obvious cases before the model does.
- **Example paste/"My scripts" picker** (prototype) is not there: examples are typed or pasted into the field.
- **Role "+ Something else"** (2.1) is not offered: the 8 creator types stay.
- **Scripts chip** (3.2) with a ready voice still opens the questions sheet; 9.3 is reached from Profile.

### Kept from v27 that the board doesn't show
- "How I sound", "My phrases", "Who I talk to", "My style" and "Niche" groups in Profile (fine-tuning), the "Does it sound like you?" strip on a script written in the voice, and "Just save my voice".

### Next phase starts with
- Settings sheets (L14), every empty state (L13) and the full pass over 03-Screen-map.
