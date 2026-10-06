# Motion · v30 (text spec)

The running prototype (`prototype/Cue App v30.dc.html`) shows every motion. This file has the values; where the two differ, the values here win. Static versions (Reduce Motion, Low Power Mode, "Starry sky: Off"): `09-Decisions.md` §7. Curves are written as SwiftUI `timingCurve(x1, y1, x2, y2)`.

| Name | Trigger | Duration | Curve | Stagger / delay | Repeats | Haptic |
|---|---|---|---|---|---|---|
| Shared sky drift (3 layers) | always, on tab screens | 260 s / 160 s / 85 s | linear | — | loop | — |
| Twinkles (14) | always | 7 s cycle; opacity 0.16 → 0.75 at 45% → 0.58 at 60%; scale 0.75 → 1 | ease-in-out | per-star delay 0–5.2 s | loop | — |
| Comet | every 105–135 s (app-wide clock); first one 25 s after launch | 1.7–2.4 s across 520–680 pt; any direction; tail 140–210 pt | (0.3, 0.1, 0.45, 1); opacity 0 → 1 at 12% → 0.9 at 72% → 0 | — | — | — |
| Tab capsule slide | tab change | 0.32 s | spring (response 0.32, damping 0.8) | — | — | `.selection` |
| Glass button press | touch down/up | 0.32 s | spring (0.3, 1.6, 0.5, 1); scale 1.10, brightness +15% | — | — | `.soft` |
| Dock chips fold | scroll (09 §6) | 0.28 s height, 0.20 s opacity | (0.2, 0.8, 0.2, 1) / ease-out | — | — | — |
| Dock focus dim | field focus | 0.25 s | ease-out | — | — | — |
| Constellation in dock field | each word typed | 0.35 s star opacity/size; 0.5 s line draw | ease / ease-out | — | — | — |
| Star to the sky | Send | 0.76 s | (0.35, 0.1, 0.25, 1) | — | — | `.medium` on tap |
| Star as transition: rise | after Send | 0.6 s to the centre (34% of height) | (0.2, 0.8, 0.2, 1) | Scripts dims to brightness 0.35 + blur 10 pt + cover 84% | — | — |
| Star breath (waiting) | while AI writes | 1.6 s | ease-in-out; scale 1.4 ↔ 1.65 | — | loop | — |
| Waiting phrases | every 1.6 s | 0.3 s out (y −4) and in (y +4 → 0) | ease | — | until done; min 3 s total | — |
| Ring reveal | content ready | 0.42 s | (0.4, 0, 0.2, 1) | crossfade to the script 0.22 s | — | `.success` |
| Star lands as caret | after reveal | 0.44 s | (0.3, 0.1, 0.25, 1); scale 2 → 0.6 | — | — | — |
| Script writing (4.1) | after the caret lands | per the 4.1 board (`sc1…`, `shimx`) | as on the board | line by line | once | — |
| Cancel / error exit | Cancel, AI error | star 0.3 s (fade + fall 40 pt), overlay 0.22 s | ease-out | — | — | `.light` |
| AI selection bar | text selected | 0.35 s rise | (0.2, 0.9, 0.25, 1) | — | — | `.selection` |
| Tip enter / exit | eligible / dismiss | 0.40 s / 0.20 s | (0.2, 0.9, 0.25, 1) / ease-out | — | — | — |
| Sheet | open | system | system | — | — | — |
| Countdown ring of stars (5.1) | Record | 1 s per number; ring sweep 1 s linear; stars pop | (0.2, 0.9, 0.25, 1) | 3 · 2 · 1 | per second | `.rigid` per number |
| Send-off (8.2) | after export | 3.6 s | ghost (0.6, 0, 0.3, 1) / arrive ease-out | — | once in the app (the board loops) | `.success` on arrive |
| Milestone (8.3) | milestone reached | 4.5 s: converge (0.5, 0, 0.2, 1) → pop (0.3, 0, 0.2, 1) → burst ease-out | — | — | once | `.success` on pop |
| First star (1.7) | 1st real take | star lights + counter (per board); the bar pulses 0.9 s | ease-in-out | — | once (bar loops) | `.success` |
| Core "YOU" orbits (9.2) | screen visible | 40 s per orbit | linear | — | loop | — |
| Empty-state orbiter | empty states | 12 s per turn | linear | — | loop | — |
| Skeleton shine | loading | 1.4 s | linear | — | loop | — |
| Toast | any toast | in 0.25 s (y −8 → 0), out 0.2 s; on screen 2.0 s | ease-out | — | — | — |

## v30 · today's additions (exact values)
Curves as SwiftUI `timingCurve(x1, y1, x2, y2)`. Reduce Motion / Low Power: final state, no loops (09 §7).
| Name | Trigger | Duration | Curve | Delay / stagger | Repeats | Haptic |
|---|---|---|---|---|---|---|
| Pro · warp (42 streaks, 60–200 pt) | 11.4 opens (not the calm version) | 0.9 s inside 0–1.1 s | (0.5, 0, 0.8, 0.4) | 0–0.24 s per streak | once | — |
| Pro · ignition (core 20% → 160%) | after warp | 0.7 s (0.7–1.4 s) | (0.2, 0.9, 0.25, 1) | — | once | `.soft` at 1.25 s |
| Pro · shockwave (gold ring ×14, warm flash 0.9 s) | 1.25 s | 1.1 s | (0.2, 0.8, 0.2, 1) | — | once | — |
| Pro · "you" planet ignites (0.6 → 1.04 → 1) | 1.5 s | 0.7 s | (0.5, 0, 0.3, 1) | — | once | — |
| Pro · reveal (fade up 18 pt + un-blur) | 1.35 s | 0.7 s each | (0.2, 0.9, 0.25, 1) | 70 ms top to bottom | once | `.success` when the CTA lands |
| Pro · CTA shine | from 2.4 s | sweep inside 4.8 s cycle in the board; 3.6 s in the app | (0.4, 0, 0.2, 1) | — | loop | — |
| Planet growth (9.2) | a share lands / screen opens after a share | 0.6 s on width, height, left and top | (0.3, 1.4, 0.5, 1) | — | once | `.soft` when a size tier is crossed |
| Planet new-dot pulse (9.2) | new video dot | 2.6 s | ease-in-out; brightness 1 → 1.5 | — | loop while "new" | — |
| Universe disc spin / core orbit (9.2) | screen visible | 140 s per turn (disc), 40 s (halo) | linear | — | loop | — |
| Year in review · slide | each of the 5 slides | 3.2 s on screen; enter 0.4 s | ease-out (opacity + scale .94 → 1) | top bars (3 pt) fill linearly over 3.2 s | once per slide | — |
| Year in review · open | tap "Your 2026 in review" | 0.3 s | ease-out | — | once | — |
| Popover (9.2 planet) | tap planet | 0.3 s (scale .94 → 1 + fade) | ease-out | — | once | `.light` |
| Sheets (Share my universe, Share to universe, Your video is ready) | open | 0.36–0.38 s `translateY(100%) → 0` | (0.2, 0.9, 0.25, 1) | content fade 0.25–0.3 s | once | — |
| Share to universe · CTA shine | sheet open | 4.8 s cycle, sweep at 58–78% | (0.4, 0, 0.2, 1) | 1 s | loop | — |
| 8.2 · card becomes a star | after export | 0–0.65 s | (0.5, 0, 0.4, 1) | — | once | — |
| 8.2 · star arcs to the planet (9-dot trail) | 0.52 s | 1.05 s | (0.45, 0.05, 0.35, 1) | **350 ms between stars when several networks** | once per network | — |
| 8.2 · planet pulse ×1.35 → ×1.12, ring ×5, "+1 · NETWORK" | 1.57 s (per star) | 0.6 s | (0.3, 1.4, 0.5, 1) | 350 ms per network | once | `.success` on each arrival (first one only if 3+ in 0.7 s) |
| 8.2 · new tiny star near YOU | 1.87 s | 0.7 s | (0.2, 0.9, 0.25, 1) | — | once | — |
| Share queue · "◀ Cue" note, step change | each step | 0.25 s fade; progress segment 0.3 s | ease-out | — | — | `.selection` on step change |
| Free-exports label → orange / yellow | count changes | 0.25 s colour | ease-out | — | — | — |
| 1.1 Welcome star opening | first launch | see 09 §12 (≈ 5.4 s flight, title ≈ 6.4 s) | see 09 §12 | — | once, then holds | `.soft` dots · `.light` words · `.success` explosion |
| 1.2 topics → worlds | enter / tap a chip | chip light 0.46 s; flight 1.25 s; landing sparks 0.55 s; intro ring 0.9 s | light (0.5, 0, 0.2, 1); ring (0.1, 0.7, 0.3, 1) | tap at 1.0 s in the board | once | `.light` on chip tap |
There is no separate animation for the queue star: the star seen at the end of the queue is the 8.2 send-off.
