# 02 · Tokens and rules of use (v29)

The app is **night only** (v27 decision, kept). Every v27 `Palette` token stays with the same value. This file lists **what v29 adds or changes**, followed by the full reference table of the roles.

## 1. Colours

### 1.1 Base (unchanged, reference)
| Token | Value | Role |
|---|---|---|
| `bg` | `#0A0B12` | Screen background |
| `bgWash` *(new)* | `radial-gradient(70% 30% at 20% 6%, #9D8CFF 20% → 0 at 70%), radial-gradient(55% 28% at 85% 60%, #5E4EE0 12% → 0 at 70%)` over `bg` | Night glow on navigation screens (identical on every one, including empty states) |
| `surface` | `#161826` | Cards and rows |
| `surface2` | `#1F2236` | Controls inside cards and sheets |
| `surface3` | `#2B2F48` | Tiles one level up |
| `fill` | `#6E7496` 26% | Inactive chip, segment track, round button |
| `separator` | `#505678` 50% | 0.5 pt separator |
| `ink` / `ink2` / `ink3` / `inkHint` | white / `#E1E4F5` 62% / 45% / 55% | Text: primary, secondary, does-not-need-reading, mono label |
| `acc` / `accInk` | `#FFD60A` / `#000` | Primary action and the text on it |
| `aiText` / `aiTextStrong` / `aiFill` / `aiBorder` | `#B4A7FF` / `#E4DEFF` / `#9D8CFF` 17% / `#B4A7FF` 30% | AI |
| `record` | `#FF3B30` | Recording |
| `success` / `warn` / `danger` / `info` | `#34C759` / `#FF9F0A` / `#FF453A` / `#64D2FF` | States |
| Worlds (topics) | `#FFC46B` / `#7EE0B8` / `#FF9BD2` / `#8FB8FF` | Up to 3 topics, in that order |
| Galaxies (platforms) | TikTok `#64D2FF` · Reels `#BF5AF2` · Shorts `#FF6B5A` · YouTube `#FF9F0A` · LinkedIn `#0A84FF` · Stories `#FF6FA8` | Destination dot |

### 1.2 New in v29
| Token | Value | Where |
|---|---|---|
| `glassBarFill` | `linear-gradient(180°, white 10% → white 3% at 45% → white 5%)` over `#161826` 42% | Tab bar (Liquid Glass): `.glassEffect(.regular)` on iOS 27; this value is the fallback/reference |
| `glassBarRim` | white 18%, 0.5 pt | Tab bar edge |
| `glassBarHighlight` | inset 0 1 0 white 22% · inset 0 −1 0 white 5% | Light on the top and bottom edges |
| `glassBarShadow` | 0 10 30 black 35% | Tab bar shadow |
| `tabCapsuleFill` | `linear-gradient(180°, white 16% → white 6%)` + 0.5 pt border white 20% + inset 0 1 0 white 25% | Active tab capsule (56 pt high, 4 pt inset from the bar) |
| `themeRail` | world colour, 3 × 30 pt (list row) / 3 × 14 pt (chips and legends), radius 2 | Topic marker |
| `platformDot` | galaxy colour, 6–7 pt circle | Network marker |
| `recPillRing` | `#E1E4F5` 22%, 1 pt inset | "● REC" pill (26 pt high, padding 0 9, radius 13) |
| `recPillDot` | `#FF3B30`, 6 pt | Dot inside the pill |
| `sliderTrack` | `#6E7496` 35%, 4 pt | Slider track |
| `sliderFill` | `#FFD60A`, 4 pt | Slider fill |
| `sliderThumb` | white, 24 pt, shadow 0 2 6 black 40% | Slider thumb |
| `selectionBar` | `#161434` 97% · inset 0.5 pt `#B4A7FF` 45% · shadow 0 12 30 black 50% | AI bar on a text selection (40 pt, radius 20) |
| `aiReplaced` | text `#E4DEFF`, background `#9D8CFF` 16%, radius 4 | AI-rewritten text, still pending Keep/Undo |
| `stripFill` | `#0E101C` 92% + blur 20 · inset 0.5 pt `#B4A7FF` 30% | State strip on the script page (44 pt, radius 16) |
| `stateReady` / `stateDraft` / `stateRecorded` | `#34C759` on `#34C759` 14% / `#E1E4F5` 80% on `fill` / `#E1E4F5` 85% on `fill` | State chip (22 pt, mono 9.5 pt, tracking .08em) |
| `adTag` | `#000` on `#FFD60A` | "#AD" / "AD" tag |
| `emptyRing` | inset 1 pt `#B4A7FF` 22%; core `radial(#9D8CFF 22% → 0)` | Empty-state mark (88 pt) |
| `emptyOrbiter` | `#FFE680`, 5 pt, glow 0 0 8 `#FFD60A` 70% | Star orbiting the mark |
| `skyStarYou` | `#FFE680`, 3 pt, glow 0 0 6 `#FFD60A` 60% | "Your stars" in the sky above Scripts |

## 2. Typography
| Use | Font | Size / weight | Tracking | Case |
|---|---|---|---|---|
| Screen title | SF Pro Display | 34 / 700 | −0.02em | Sentence |
| Story title (onboarding, empty) | SF Pro Display | 22 / 700 (line 28) | −0.02em | Sentence |
| Card title | SF Pro Text | 17–20 / 600–700 | 0 | Sentence |
| Body | SF Pro Text | 15–17 / 400–500 | 0 | Sentence |
| Helper text | SF Pro Text | 13–15 / 400, `ink2` | 0 | 1 sentence |
| **Signal (HUD)** | **SF Mono** | **10–13 / 600–800** | **.06–.12em** | **CAPS** |
| Buttons | SF Pro Text | 15–17 / 600–700 | 0 | Sentence |
| Prompter | Lexend (default), Atkinson Hyperlegible, Source Serif 4, SF Rounded | 24–44 pt (4 steps) | 0 | — |
| On the video (captions, text, cover) | Poppins (Cue default), Anton, Unbounded, Instrument Serif, Syne, Space Grotesk, Space Mono, Caveat (all OFL) | per style | — | — |
- Dynamic Type everywhere in the interface; mono signals cap at `.accessibility1`, and beyond that the label wraps (it never gets cut).
- Numbers that change use tabular digits.

## 3. Shape and spacing
| Token | Value |
|---|---|
| Side margin | 16 (cards) · 20 (titles and loose text) |
| **Gap between stacked blocks** | **16** (never less; nothing touches the block before it) |
| Radii | card 22–26 · inner 20 · tile 16–18 · field 12 · strip 16 · sheet 34 (inset 8 from the edges) · chips/buttons in a capsule |
| Heights | primary button 50–54 · secondary 40–44 · chip 34 (small 30) · row 58–62 · tab bar 64 (bottom 26 from the edge) |
| Touch target | ≥ 44 × 44 (the REC pill and Continue › keep a 44 pt area even when the visual is 26 pt) |
| Home Indicator area | the bottom 34 pt have no controls |

## 4. Materials and light
| Name | Recipe |
|---|---|
| Night glass (floating controls) | `#0E101C` 60/72/88% (over video), blur 20–30, saturation 160%, rim `#B4A7FF` 22% |
| Liquid Glass (tab bar) | `glassBar*` tokens; on iOS 27, `glassEffect(.regular.interactive())` in a capsule |
| LET'S CUE! card | `radial(90% 120% at 0 0, #9D8CFF 55% → 0 at 60%) + radial(80% 100% at 100% 100%, #5E4EE0 60% → 0 at 65%)` over `#1A1840`, 0.5 pt border `#B4A7FF` 40%, radius 22 |
| Card ambient sky | dust (4 layers of 1 px dots), violet nebula, 2 cross glints, 4 twinkles, shooting star (values in `motion/`) |
| Yellow glow | only on: the reading line, ✓ sent, rising star, active orbiter |

## 5. Icons
24 × 24 grid; round caps and joins; the stroke keeps **≈1.6 px rendered** at any size (stroke = 1.6 × 24 / size, between 1.7 and 3.4 grid units); corner radius ~3 on rectangles; a single colour (template). Filled icons: play, pause, best-take star (when marked), the triangle inside Takes, Record (red core). The full set is in `icons/` (stage 4).

## 6. Slider ranges (each one with min/max that make sense)
| Where | Parameter | Range | Step | Default | Labels at the ends |
|---|---|---|---|---|---|
| Settings › Prompter, Studio | Speed | 80–220 wpm | 5 | 150 | 80 wpm · 220 wpm (Steady only) |
| Settings › Prompter | Text size | 4 steps: 24 / 30 / 36 / 44 pt | — | 36 | Small · Extra large |
| Settings › Prompter | Reading line | 10–50% of the height | 1 | 22% | 10% · camera · 50% · middle |
| Settings › Prompter | Margins | 8–40 pt | 2 | 20 | 8 pt · 40 pt |
| Settings › Prompter | Countdown | Off / 3 / 5 / 10 s | — | 3 s | — |
| Personalize | Starry sky | Off / Soft / Full | — | Full | — |
| Editor › Text | Size | 24–120 pt | 2 | 64 | 24 pt · 120 pt |
| Editor › Text | Glow | 0–100% | 5 | 35% | Off · 100% |
| Editor › Captions | Size | S / M / L / XL | — | L | — |
| Editor › Audio | Your voice | 0–200% | 5 | 100% | 0% · 200% (100% = as recorded) |
| Editor › Audio | Music | 0–100% | 5 | 20% | 0% · 100% (ducks under your voice) |
| Editor › Audio | Clean up voice | Off / Light / Strong | — | Light | — |
| Editor › Edit | Clip speed | 0.5–3.0× | 0.1 | 1.0× | 0.5× · 3× |
| Editor › Filters | Intensity | 0–100% | 1 | 70% | — |
Double tap = back to the default; drag down to fine-tune (½ and ¼ speed, "FINE" label), as in v27's `OrbSliderMath`, now without the orb.

## 7. Never do
- Two solid yellow buttons on the same screen; a solid yellow chip (a selected chip is white with black text).
- A dot for a topic; violet on something that isn't AI; red outside recording.
- Motion over the camera, a take or the editor (except the recorder's own feedback).
- A sky or effect without its static version (Reduce Motion, Low Power, Starry sky: Off).
- A toast over ~28 characters, helper text over 1 sentence (~60 characters), a dash followed by an explanation.
- A control in the bottom 34 pt; a target under 44 pt; a vertical scroll inside an editor panel.
- A photo of the creator as "the centre" of something.
- Asking for permission outside the moment of use (only in onboarding step 4 or on the first tap that needs it).
