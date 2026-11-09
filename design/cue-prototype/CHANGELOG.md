# Prototype changelog

## Product page screens (9 Nov 2026)

Redrawn from the app code (main at `d69a5262`) for the App Store product page; `scripts/check-prototype.py --mark` records the ones that now match.

- **Ultra AI** (U1, 3.2, 4.1): permission sheet with the galaxy and the ✦ ignition, the writer chip, the violet send arrow, the galaxy wait and the page opening from the star.
- **Scripts 3.2**: the light list with groups, REC pills, topic rails and the FilterFan chips (28 ms stagger).
- **Onboarding 1.1–1.4**: centred welcome with glass pills and one flight, topic light onto dashed orbits, the thin route, the clean practice card.
- **Teleprompter 5.2 / 5.3**: Selfie with the countdown, REC badge, gathered sheet and text gliding (Record starts a take, Done goes to 6.1); Studio playing.
- **Editor 7.2 + new 7.7**: the 33-tool toolbar that scrolls sideways, and the Clean up panel (pauses, words, text; Quick pass, Remove, Undo, the timeline closing up).
- **Share 8.1 / 8.2**: 3 free exports (was 5), Options · 1080p and its sheet, "target length" lines, no cover-frame line, share icon on the cover; the queue itself (picker, explainer, step, Posted on…?, send-off) is the runtime layer `runtime/07-*.js`.
- **My Cue Voice**: page 9.3 with the fuel tank and the ship's flight (`screens/assets/voicefuel.js`, a port of VoiceFuelPainter / VoiceShipFlight / SpaceshipPainter; Save in 9.4 raises what Cue knows and the ship flies again); 2.1 with search and areas, new 2.1b (how scripts talk about you), 5 tones in 2.4 and 9.4, progress "n / 05".

Known gaps: 1.5–1.7, 1.4b, 3.3, 2.2, 2.3, 2.5, 6.x and 7.3–7.6 are not redrawn; 7.2's timeline and tracks and the Auto edit / My words / Edit by text panels are still v26-style or missing; waits are shortened (about 19 s for the Ultra AI script); 9.3's row values are sample data.

## Unreleased (24 Oct 2026)

- Each screen records `drawnFrom`, the app commit it was drawn from. `scripts/check-prototype.py --report` shows which screens are behind the app and `--mark` records a redrawn screen. `REFRESH.md` is the routine for redrawing them.

## v31 (24 Oct 2026)

First version of the prototype kept in the repository, taken from the published "Cue App v31" (22 Oct 2026).

- Redrawn from the app code: onboarding 1.1–1.5, Scripts 3.2, Find inspiration 3.3, script page 4.1, Prompter 5.2 and 5.3, My Cue Voice 2.x, 9.3 and 9.4, Profile 9.1, Settings 11.1.
- The other screens are still the v30 prototype.
- Apple Watch 12.1–12.6 and editor 13.1–13.4 are proposals awaiting approval.
