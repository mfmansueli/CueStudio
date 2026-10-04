# Cue — Color tokens (dark × light) · v26

Appearance: Automatic follows iOS. Video screens (recorder, review, editor) and sheets opened from them are always dark. Everything else follows Appearance.

Use as SwiftUI Color assets with Any/Dark appearances (names = token names). Video screens use the dark value in both appearances.

| Token | Dark (Night Session) | Light | Use |
|---|---|---|---|
| `bg/app` | #0A0B12 + slow violet aurora | #F4F5FA + soft violet wash | Tab screens, script page |
| `bg/sheet` | rgba(18,20,34,0.96) glass | #F4F5FA | Sheets from tab screens |
| `bg/card` | #161826 | #FFFFFF + shadow 0 1 2 rgba(20,20,60,.05) | Lists, grouped rows |
| `bg/card-raised` | #1F2236 | #E6E8F2 | Inputs, rows inside cards |
| `bg/glass` | rgba(14,16,28,0.6–0.88) + 0.5px rim rgba(180,167,255,.22) | rgba(255,255,255,0.94) + 0.5px rim rgba(60,60,90,.12) | Bars, floating controls, tab bar |
| `bg/hero-ai` | Violet aurora card (rotating 24 s) + yellow scan line | Solid violet gradient, white text | Let’s Cue!, Your setup, My Cue Voice |
| `fill/control` | rgba(110,116,150,0.26) | #E6E8F2 | Unselected chip, segmented track, round buttons |
| `fill/segment-on` | #636366 | #FFFFFF + shadow 0 1 3 rgba(0,0,0,.12) | Active segment |
| `fill/chip-on` | #FFFFFF / text #000 | #0F1020 / text #FFF | Selected text chip |
| `separator` | rgba(80,86,120,0.5) | rgba(60,60,90,0.14) | Hairlines 0.5px |
| `text/primary` | #FFFFFF | #0F1020 |  |
| `text/secondary` | rgba(225,228,245,0.62) | #53566C |  |
| `text/tertiary` | rgba(225,228,245,0.4) | #8A8DA2 | Placeholders, hints |
| `accent/action` | #FFD60A fill, #000 text | #FFD60A fill, #000 text | ONE primary action or ✓ per screen |
| `accent/signal` | #FFD60A text (mono HUD) | #8A6A00 text | Counters, time, status, links |
| `accent/selected-ring` | 2px #FFD60A + 12% tint | 2px #FFD60A + 12% tint | Selected visual tile |
| `ai/text` | #B4A7FF (strong #E4DEFF) | #5B48D9 (strong #3E2DB8) | ✦, My Cue Voice, Smart, suggestions |
| `ai/fill` | rgba(157,140,255,0.14–0.2) | rgba(91,72,217,0.10) | AI chips, AI tiles |
| `status/ok` | #34C759 | #248A3D (text) · #34C759 (toggle) | READY, FITS, toggle on |
| `status/warn` | #FF9F0A | #C26A00 | Duration warnings, export meter |
| `status/danger` | #FF453A | #FF3B30 | Delete, record dot |
| `platform/tiktok` | #64D2FF | #0071A4 (text) · dot unchanged | Platform dots |
| `video/always-dark` | Selfie, Studio, Take review, Editor and their sheets | Same (always dark) | Like Camera/Photos: color judgment needs dark |

Screens in light: `screens/light/` (S1, S2, S3, V1, K2, P1, G1, R0, M1). R1 shows the recorder staying dark.
