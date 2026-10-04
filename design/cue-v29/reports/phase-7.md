## Phase 7 · Share, Universe and Pro — report
Built: ✓ · Warnings: 0 (clean build at the end of the run) · Tests: unit suites green / 5 new (`TakeReviewViewModelTests` ×3 for #ad and export counting, `StoreErrorMessageTests` ×2) · UI: `ShareUniverseProV29UITests` (2 new), `ShareToUITests`, `FreePlanUITests`, `CueUniverseScreenshotTests/testReadyToTravelAndTheSendOff` green (9)

### Done
- **8.1 Ready to travel / Share to**: sponsored video → "AD · #ad is copied · paste it in your caption" bar, "#ad" on the pasteboard after a successful export (`ShareToSheet`, `TakeReviewViewModel.isSponsored`, `copiesCaption`). Platforms, Save to Photos, Other apps, "{n} of 5 left" + Go Pro → 11.4 were already in place.
- **F6 export**: the export now counts only after the video was saved or handed over; failure → "Couldn't export · Try again" and the count does not move; Photos denied → card (phase 6); free exports used → paywall, which continues the export after the purchase.
- **8.2 send-off / 8.3 milestone**: checked against the board (Share again, Done, star in your universe; Use {icon} / Keep my current icon), unchanged.
- **9.2 Your universe**: animated core "YOU" (no photo, no initial), empty state E, same core in the shared image (`UniverseMap`, `UniverseShareCard`, `YourUniverseView`).
- **11.4 Pro (F7)**: errors per the flow (`StoreManager.message(for:)`), cancel is silent, Restore visible; night aurora kept from v26.
- 8 new strings in 20 languages.

### Captures
- `9.2_universe_empty.png`, `11.4_pro.png` (the export screens `v27-ready-1-to-travel` / `v27-sendoff-1-on-its-way` are unchanged by this phase)

### Animations (measured)
| name | duration | curve | Reduce Motion |
| core "YOU" breathing | 4 s | sine | still |
| core's circling star | 12 s per turn | linear | still |
| universe orbits | 25–70 s per turn | linear | still |
| send-off (unchanged) | 1 s fold + 1.25–2 s comet | cubic | arrives |

### Not matched exactly
- **Photo in the iOS sheet**: the creator's photo is not used anywhere (L12); the Profile card keeps the initial.
- **"{n} of 5 left → 11.4" on the Ready-to-travel screen** is not a button; the way to Pro is "Go Pro" in the Share to sheet and the Profile plan card.
- **No UI test of the ad bar**: the sample data has no ad take; the rule is covered by unit tests (`aSponsoredVideoCarriesHashtagAdAndOthersDoNot`).
- "Share 1 more videos" (milestone card) keeps its plural form from v27.

### Kept from v27 that the board doesn't show
- "My year in Cue" image, the milestone icons and their Pro lock, send-off and First star animations.

### Next phase starts with
- Profile and My Cue Voice: 9.1, 9.3 and the row sheets, validation F9, nudges.
