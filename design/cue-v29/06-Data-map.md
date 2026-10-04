# 06 · Data map per screen (v29)

✓ = already exists in the code · 🆕 = new (described at the end).

| Screen | Element | Source | Status |
|---|---|---|---|
| 3.2 | title "Scripts" + "{n} SCRIPTS · {n} READY" | `ScriptLibraryService.scripts` + derived state | ✓ + 🆕 state |
| 3.2 | LET'S CUE! field / suggested idea | `IdeaDraftService` (rotates through the profile topics) | ✓ |
| 3.2 | Format chip | `ScriptType?` chosen on the card (session, not persisted) | ✓ + 🆕 2 types |
| 3.2 | For {Platform} chip | `CreatorProfile.defaultPlatform` / last one used | ✓ |
| 3.2 | ✦ Voice nn% | `CreatorProfile.voiceStrength` 🆕 (computed, 04 §F9) | 🆕 |
| 3.2 | READY / DRAFT / RECORDED groups | `Script.state` 🆕 (derived) + `TakeLibraryService.takes(for:)` | 🆕 |
| 3.2 | row: topic bar | `Script.topic` → `OnboardingTopic.world` colour | ✓ |
| 3.2 | row: platform dot + "TIKTOK · 0:47 · 4 CUES" | `Script.platform`, `ScriptLength.estimate`, `CueParser.count` | ✓ |
| 3.2 | ×n (RECORDED) | takes count | ✓ |
| 3.2 | sky stars | `SkyMemory.points` 🆕 | 🆕 |
| 4.1 | strip: state · format · cues | `Script.state`, `Script.type`, `CueParser.count` | 🆕/✓ |
| 4.1 | "CHANGED SINCE TAKE {n}" | `script.version > latestTake.scriptVersion` | ✓ |
| 4.1 | AI bar | `ScriptAIService.rewrite(range:kind:)` 🆕 | 🆕 |
| B | saved brands | `BrandStore.brands` 🆕 | 🆕 |
| 5.2 | Voice\|Steady | `PrompterSettings.mode` | ✓ |
| 5.2 | HUD "● MIC · SETUP" | `CreatorSetup`, audio route | ✓ |
| 5.2 | box size / reading line | `PrompterSettings.boxWidth/boxHeight/readingLine` 🆕 | 🆕 |
| 5.2 | compact bar | `PrompterViewModel.isCompact` 🆕 (= isRecording && !peeking) | 🆕 |
| 6.2 | pipeline + counts | `TakeLibraryService` (derived stage) | ✓ |
| 6.3 | "{n} of 5 free exports" | `KeychainExportCountStore` + `StoreManager.isPro` | ✓ |
| 7.x | lanes, panels | `TakeEdit`, `QuickEditDraft` | ✓ |
| 8.1 | AD warning | `Script.type == .ad` | ✓ |
| 9.1 | Your universe "{n} VIDEOS SHARED" | `MilestoneService.sharedCount` | ✓ |
| 9.1 / 9.3 | meter, sentence, next question | `CreatorProfile` + `voiceStrength` 🆕 + `nextQuestion` 🆕 | 🆕 |
| 9.3 | "What Cue sends" | `ScriptPromptBuilder.voiceBrief(profile)` | ✓ (exposed) |
| 11.1 | Your setup | `CreatorSetup` | ✓ |
| 11.1 | Remote | `RemoteControlService.state` | ✓ |
| 11.2 | sliders | `PrompterSettings` | ✓ |
| 11.4 | plans/prices | `StoreManager` (StoreKit) | ✓ |

## New data
| Data | Type | Who produces it | When it changes |
|---|---|---|---|
| `Script.isFinished` | Bool, persisted | `ScriptLibraryService` | Done / AI delivers complete / Use this script → true · edit + exit without Done → false |
| `Script.state` | enum computed (ready, draft, recorded) | extension on `Script` + takes | on any change to the script or its takes |
| `ScriptType.mythFact`, `.pov` | enum cases | — | — |
| `BrandBrief` | struct {name, product, mustSay, neverSay, link, code} | brief sheet | on Save |
| `BrandStore` | [BrandBrief], JSON | new service | save/remove a brand |
| `CreatorProfile` + openings, endings, phrases, swearing, formats, examples, customTags | optional fields | 9.3 sheets, nudges | on Save in each sheet |
| `voiceStrength` | Int 0–100 computed | `CreatorProfile` | on any profile change |
| `nextQuestion` | the first empty Personality item | `CreatorProfile` | idem |
| `SkyMemory.points` | [CGPoint normalised 0–1], ≤ 50 saved, 14 visible | Scripts on Send | on each idea sent |
| `PrompterSettings.boxWidth/boxHeight/readingLine` | CGFloat (pt) / Double (0.10–0.50) | recorder (handle/pinch) and 11.2 | on drag |
| `PrompterViewModel.isCompact` | Bool | view model | Record/Stop/tap |
