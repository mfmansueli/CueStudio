# Handoff: Cue Studio, from the current app to design v26

## Overview
Cue Studio is a mobile studio for people who talk to the camera: Idea → Script → Record → Pick → Edit → Ready → Share.
This package moves the **current SwiftUI app** (repo `mfmansueli/CueStudio`, `main`, read on 2026-10-03) to the **v26 design**. That means a new visual identity ("Night Session" plus a violet AI layer), a reworked recorder bar, a Takes pipeline, a rebuilt editor UI, a single script page, My Cue Voice, a new Settings, a new Pro screen, and light-mode tokens.

## About the design files
The files in `prototype/` are **design references made in HTML**. They show the intended look and behavior; they are not production code. Recreate them in the existing SwiftUI codebase with its own patterns (`Palette`, `Metrics`, `DesignSystem/Components`, view models, services). Do not port the HTML or JS.
To view a prototype, open `prototype/Cue App v26.dc.html` in a browser. "Jump to a flow" (left panel) opens any screen.

## Fidelity
**High-fidelity.** Colors, type, spacing, radii, states and copy are final. Match them pixel-close using the tokens in `CUE_COLORS.md` / `cue-colors.json`.

## Read first, in this order
1. `DESIGN_DIRECTION.md`: the why. Settle any conflict with it.
2. `CUE_WORKFLOW.md` + `cue-workflow-v26.json`: every screen (IDs S1, R1, K1, E1…), every action and where it goes, the state machines, and the open issues. Each node has a reference image in `screens/` (dark) and in `screens/light/`.
3. `CUE_COLORS.md` + `cue-colors.json`: 23 color tokens with dark and light values.
4. `prototype/Cue Controls.dc.html`: the one control vocabulary.

## What the repo already has (keep it)
- `Palette` with light/dark dynamic colors, the `videoContext()` rule (camera, prompter, review and editor always dark) and **`PaletteContrastTests`**. Keep all of these. Change token **values**, add new tokens, and keep the tests green. Where the repo already has a tested light text value (e.g. `accText` light `#7A5C00`), prefer it over the prototype's.
- The Tab order Scripts · Takes · Record (center, opens Start recording) · Profile · Settings. It already matches v26.
- Voice Following engine, export rules (5 free exports, no watermark), caption models, cover models. These are logic; the design does not change them.

## What changes (current → v26)

### 1. Tokens: `DesignSystem/Tokens/Palette.swift`, `Backgrounds/`
| Current | v26 |
|---|---|
| `bg` dark `.black` | `#0A0B12` + slow aurora on tab screens (`bg/app`) |
| `surface` dark `#1C1C1E` | `#161826` (`bg/card`) |
| `surface2` dark `#2C2C2E` | `#1F2236` (`bg/card-raised`) |
| `fill` dark `#767680 @24%` | `rgba(110,116,150,0.26)` (`fill/control`) |
| `glassBorder` white 12% | 0.5px rim `rgba(180,167,255,0.22)` on night glass `rgba(14,16,28,0.6–0.88)` |
| `ink2` dark `#EBEBF5 @60%` | `rgba(225,228,245,0.62)` |
| `auroraGold` / `auroraAmber` (yellow aurora) | **Violet** aurora for AI cards (`#9D8CFF`, `#5E4EE0`), plus a thin yellow scan line along the bottom edge |
| `accGlow` on Creator Voice / Pro cards | Violet radial glow (AI) on My Cue Voice; violet + a touch of yellow on Pro |
| No AI color | **New:** `aiText` `#B4A7FF` / light `#5B48D9`, `aiTextStrong` `#E4DEFF` / `#3E2DB8`, `aiFill` violet 14–20% / light 10% |
| Lanes: text yellow, captions gray, music blue, VO orange, media purple | Lanes: **Aa white, captions violet, music green, voice-over amber, overlay light blue** on `#1C1C1E`-style strips with a gutter icon |
| Light bg `#F2F2F7` | `#F4F5FA` with a soft violet wash |

Color roles (enforce in review): **violet = AI** (✦, My Cue Voice, Smart, suggestions). **Solid yellow = the one primary action or ✓ per screen.** **Yellow mono text = HUD signals** (counters, time, status). Numbers, durations and status lines use `ui-monospace` / SF Mono.

### 2. Shared components: `DesignSystem/Components/`
Follow `Cue Controls`:
- Selected text chip: white with black text (light mode: `#0F1020` with white text).
- Selected visual tile: 2px yellow ring + 12% yellow tint, white label.
- Active segment: `#636366` (light mode: white + shadow).
- Toggle: `#34C759`.
- Slider: 4px yellow track, 24px white thumb.

Add `GlassNight` (surface + rim), `HUDLine` (mono, dot + values) and `StageBar` (PICK · EDIT · READY · SHARED).

### 3. Screens (workflow ID → repo → change)
| ID | Repo files | Change |
|---|---|---|
| S1 Scripts | `Screens/Scripts/ScriptsView.swift`, `EmptyLibraryView.swift` | Hero "LET'S CUE" card (violet aurora + scan line): idea field, mic, ✦ arrow, "For TikTok ⌄", "✦ My Cue Voice". HUD counter "06 SCRIPTS / 14 TAKES". Each row shows its pipeline stage. Empty state keeps "Record without a script". |
| S2 New script | `CreateScript/NewScriptSheet` | Only **Write my own** and **Import** (Scan · Photo · File · Paste). Remove Prompt / Themes / Formats: the AI lives in S1. |
| S2c / S2d | `CreateScript/GenerateScript/*` | Ideas and Format become small sheets opened from the S1 hero. Retire the 3-tab GenerateScriptSheet. |
| S3 Script page | `ScriptDetail/ScriptDetailView.swift`, `ScriptReadView.swift` | One page with **Draft \| Shaped**. Free writing first; "Shape for <platform>" adds cues and timing on demand. AI writes into the page in violet. The old editor moves to ••• › Versions & options (S4). |
| V1 My Cue Voice | `Profile/*`, `ThemesTabView` copy | Rename **Creator Voice → My Cue Voice** everywhere. 4 questions (01/04): role, topics, audience, tone. Then the script itself is the preview ("My voice \| Without", Sounds like me / Adjust). See `prototype/CueVoiceFlow.dc.html`. |
| R1 / R2 Recorder | `Prompter/Selfie/SelfieControlPanel.swift`, `Controls/ScrollModePicker.swift`, `VoiceIndicator.swift`, `SelfieTopBar.swift` | Night-glass bar: [Voice \| Steady] + ⤒ + play + Aa · SPEED slider (Steady) or hint (Voice) · HUD line "● MIC · SETUP ›" · last take · camera settings · ● · flip · •••. **While recording, a compact bar** (mode chip, ⤒, pause, Stop, 00:23 yellow, "TAKE 4 · TIKTOK SETUP"); tap the screen to show the full bar for 4 s. **Remove "Hide controls while recording"** and the eye button (`DisplayLayoutSection`, `CreatorDisplaySettingsSheet`, `PrompterViewModel` hidden state). |
| K1 Take review | `TakeReview/TakeReviewView.swift` | Opens paused (play button). Top glass bar: back · "TAKE 3 · 1:02" · ★ ring · delete. Compare chip "2 / 3" + swipe. Panel: title, HUD line (✓ FITS), StageBar, "From script ›", ✦ suggested best (violet). Actions: Continue/Edit · Retake · Save (round glass) + **Share** (yellow). |
| K2 Takes | `Takes/TakesView.swift` | Pipeline header **TO PICK › IN EDIT › READY › SHARED** (counts; tap to filter), plus a NEXT line. 9:16 grid by default, list optional. **The stage is derived, never set by hand** (see the state machine). |
| E1–E4 Editor | `Screens/QuickEdit/*` (144 files) | See `prototype/CueEditorEmbed.dc.html`. **Top bar:** back (keeps the draft, asks nothing) · "IN EDIT · AUTOSAVED" · **Done** (yellow). **Done always asks "Is it ready to post?"**: Yes, share to social media · Download video · Ready, I'll post later · Not yet, I'll come back. **Toolbar** in CapCut order, ✦ Smart last in violet. **Panels** have a fixed height and never scroll vertically; overflow becomes chips or tabs. **No touch target in the bottom 34–44 pt** (home indicator). Selected clip: white frame + yellow handles; Delete fixed bottom-right in red. **Adjust:** chips + ruler + ◐ hold. **Cover:** tabs Frame · Text · Elements · Look (layouts Hook/Number/Kicker/Question/Before-After, ✦ titles, highlight word, arrow/circle/EP/NEW/@handle, Text behind me, My cover style, Profile-grid series preview). |
| P1 Profile | `Profile/ProfileView.swift` | Identity, My Cue Voice card ("What Cue uses", editable rows, voice examples), plan card (FREE PLAN / ● PRO ACTIVE on night aurora). |
| G1–G6 Settings | `Settings/SettingsView.swift`, `CreatorSetup/*`, `RemoteControl/*` | "Your setup" card (phone thumbnail with format, Camera / Quality / Mic / Text values), tiles Recording · Prompter · Remote, then General and Purchases & About. Teleprompter page: sticky static proportion preview + section chips. Remote: status ring grey / yellow / green. |
| M1 Pro | paywall | Night + violet/yellow aurora, "● CUE PRO" mono, benefits card (AI rows violet), plans with a 2px yellow ring, glass footer. Out of exports: "05 / 05 FREE EXPORTS USED" meter (no watermark copy). |

### 4. State machines (implement as model logic, not UI flags)
- **Pipeline per video** (all takes of one script). First match wins: more than one take and none ★ → PICK · draft open → IN EDIT · not exported → READY · exported → SHARED.
- **Recorder:** idle → countdown → recording (compact bar) → stop → take saved → K1.
- **Appearance:** Automatic follows iOS. Video screens and the sheets opened from them stay dark; everything else follows the setting.

## Suggested order (each phase ships on its own)
1. **Tokens + components.** Update `Palette` values, add AI/glass/HUD tokens, keep `PaletteContrastTests` passing, build GlassNight / HUDLine / StageBar / chips per Cue Controls. *Done when* every screen is in the new colors with no layout change.
2. **Naming + dead features.** Creator Voice → My Cue Voice; remove "Hide controls while recording"; trim NewScriptSheet to Write my own / Import.
3. **Recorder bar** (R1/R2) with the compact recording state.
4. **Takes pipeline + Take review** (K1/K2) with the derived stage.
5. **Editor** (E1–E4): top bar, Done question, toolbar order, fixed panels, lanes, Cover.
6. **Script page + My Cue Voice** (S1, S3, V1).
7. **Settings + Profile + Pro** (G*, P1, M1).
8. **Light-mode pass** against `screens/light/`.

## Rules that must not break
- Bottom 34–44 pt: no controls (home indicator and multitasking).
- One solid-yellow action per screen.
- Editor panels never scroll vertically.
- Done always asks; back never asks.
- Stages are derived from actions.
- Minimum touch target 44 pt; text contrast 4.5:1 (the existing tests).

## Files in this package
- `README.md` (this file), `DESIGN_DIRECTION.md`
- `CUE_WORKFLOW.md`, `cue-workflow-v26.json`, `screens/` (dark), `screens/light/` (light)
- `CUE_COLORS.md`, `cue-colors.json`
- `prototype/`: `Cue App v26.dc.html` (full app), `CueEditorEmbed.dc.html` (editor), `CueScriptPage.dc.html` (script page), `CueScriptEditorEmbed.dc.html` (legacy editor), `CueVoiceFlow.dc.html` (My Cue Voice), `Cue Controls.dc.html` (controls), `support.js`, `assets/`
