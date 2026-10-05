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
