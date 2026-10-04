# 01 · Direction: Cue v29

## The idea
**A night studio with a quiet sky.** The creator opens the app, sees their scripts, and records in seconds. The universe theme (sky, stars, galaxies, "your stars") is a backdrop and a reward. It never gets in the way of the task. v29 takes the v28 prototype as the single source of truth and turns it into the app.

## Tone
- **Studio focus:** dark backgrounds, little colour, every screen has one clear action.
- **Quiet magic:** motion is slow, low-opacity and ambient. It only gets louder at moments of achievement (sending an idea, the first take, sharing).
- **Speed:** from launch to recording in at most 3 taps (Scripts → ● REC → recorder). Nothing blocks recording.
- **Native iOS 27:** real Liquid Glass on bars and floating controls, SF Pro in the interface, SF Mono in signals.

## Colour roles (the language of the whole app)
| Colour | Meaning | Never |
|---|---|---|
| **Violet** `#B4A7FF` / `#9D8CFF` | AI (✦, My Cue Voice, Smart, rewrite) | Non-AI actions |
| **Solid yellow** `#FFD60A` | The one primary action per screen, plus ✓ | Two solid yellow buttons on the same screen |
| **Yellow in mono text** | HUD signals (time, counters, values) | Long text |
| **Red** `#FF3B30` | Recording (the ● and the recorder button) | Decoration |
| **Green** `#34C759` | Toggle on, READY, connected | Brand or decoration |
| **Platform dot** | Social network (TikTok cyan, Reels purple…) | Topic |
| **3 pt bar** in the world colour | Creator topic | A dot for a topic |

## What changes from v27, and why
| # | Change | Why |
|---|---|---|
| 1 | **Tab bar:** real Liquid Glass (blur 22 + saturation 180%, white 0.5 pt rim, light on the top edge); the active tab is a **56 pt glass capsule**. The yellow orb that travelled between tabs **goes away**. | The orb broke the native shape of the bar and competed with the primary action. |
| 2 | **Icons refined:** 24 grid, rounded strokes, the **same visual weight at every size** (≈1.6 px rendered); tab bar icons at 26 pt, Record at 30 pt (thin ring + solid red dot, no glow). | Small icons were too thin and Record was heavy. |
| 3 | **Simple slider** in place of the orb slider: 4 pt yellow track, 24 pt white thumb, value in mono, **min/max that make sense** for each parameter. The orb, planet and trail **go away**. | The planet effect was too much for a focus tool, and it hurt accessibility. |
| 4 | **Scripts home:** the LET'S CUE! card with its own **ambient sky**, plus **a star that rises** when you send; the list is **grouped by state** (READY TO RECORD · DRAFTS · RECORDED); **● REC** pill; topic shown as a **bar**. | Shows what can be recorded now; the effect makes the card alive without asking for attention. |
| 5 | **Script states follow intent** (Done = READY, back with changes = DRAFT, take = RECORDED). **Shape is a tool**; the Draft \| Shaped switch **goes away**. | "Used Shape" never meant "finished". The same rule as the video editor. |
| 6 | **Formats** (9) on the card and in **Start from a format**, including **Sponsored ad** with a brand brief and **#ad** through to Share. | Many creators record ads; the AI may never invent claims. |
| 7 | **AI rewrite on selection** (Rewrite · Shorter · Punchier · More me · Cut) with Keep / Undo / Try again. | Fine-tune a single sentence without regenerating the whole script. |
| 8 | **v26-style recorder bar** (bar with a background, **compact bar while recording**, box that shrinks with focus, **⌟ resize handle** and **reading-line pinch**). | Fewer controls on screen while you speak. |
| 9 | **My Cue Voice in 3 layers** (Essentials · Personality · Proof): a summary card on Profile, a full page, one-tap nudges, and text validation (typos, blocked words, "+ Something else"). | Personalising the AI without a long form. |
| 10 | **Profile** reorganised into compact cards; "you are the centre" is an **animated core** (no creator photo). | A photo at the centre looked odd and created rights/image problems. |
| 11 | **Empty states** with one pattern (ring + orbiting star, title, a line, one action). | v27 had an empty state only on Scripts. |
| 12 | **Microcopy:** toasts ≤ ~28 characters, helper text 1 sentence ≤ ~60 characters. | Breaks well in 20 languages (German, Arabic, Japanese). |
| 13 | **Settings:** Recording, Remote, Language & Region and Privacy open as sheets; 16 pt between blocks. | Fewer levels of navigation; ended the overlaps. |

## What stays the same (reused as-is)
Night-only palette, `StarfieldView`, `CueMotion`, `Haptics`, onboarding (1.1–1.7), editor (structure and logic of phase 1e), takes pipeline, exports, Pro, Remote, 20 languages, `PaletteContrastTests`, and all the services.

## The 5 principles for any decision not in this document
1. One primary action per screen (the only solid yellow).
2. Motion only on navigation screens; never over the camera, a take or the editor.
3. Everything has a static version (Reduce Motion, Low Power, Starry sky: Off).
4. The creator decides; the AI suggests in violet and always has Undo.
5. No text explains the system; text says the result.
