## Phase 6 · Takes, review and editor — report
Built: ✓ · Warnings: 0 (clean build checked at the end) · Tests: unit suites for the toolbar, the review, the editor and the prompter green / 6 new · UI: `EditorUITests`, `EditorTaskUITests`, `TakesUITests`, `EditorScreenshotTests` (30 tests) green after one test was updated to the new toolbar

### Done
- **6.1 Pick your best take** opens by itself after a stop that leaves ≥ 2 takes of the script and no ★ (`ReviewLaunchAction.pickBest`, `PrompterViewModel.shouldPickBest`); one take goes straight to 6.3.
- **6.2 Takes**: pipeline, NEXT, grid / list were already in place and derived; the empty state is now pattern E (`EmptyState`, "Write a script first ›").
- **6.3 Open take**: Delete is immediate with **Undo for 4 s** (`TakeLibraryService.remove / restore / purge`: the video goes only after the toast); Photos denied → card + Open Settings (`PhotosDeniedCard`).
- **7.2 editor toolbar**: Edit · Audio · Text · Captions · Filters · ✦ Smart · Cover; Adjust, Crop, Background and Overlay moved to Edit's clip tools; the whole take's Background is a tile in ✦ Smart. Back keeps the draft with the toast "Draft saved".
- **7.4**: "Captions need speech recognition." when the device can't recognize speech.
- Already as the board asks (checked, not changed): white frame + yellow handles on the selected clip, Delete fixed in red at the end of the bar, coloured lanes, Done → "Is it ready to post?" with the 4 outcomes, derived stage (`TakeStage`, tested).

### Captures
- `7.2_editor.png`, `7.2_clip_tools.png`, `7.2_smart.png`, `7.2_cover.png`, `7.2_adjust.png`, `7.3_text.png`, `7.4_captions.png`, `7.5_sound.png`, `7.6_ready_to_post.png`

### Animations (measured)
| name | duration | curve | Reduce Motion |
| Delete Undo toast | 4 s | — | same |
| toolbar context change | 0.25 s | spring | fade |
| panel in / out | 0.3 s | smooth | fade |

### Not matched exactly
- **"Nothing scrolls vertically" in panels**: the panels have a fixed height per kind (mini, medium, full) and nothing scrolls at normal sizes, but the content still scrolls inside as a safety on compact screens and large text; cutting it would hide controls.
- **7.1 opening** shows the overlay while the take is read, not a fixed 2.8 s.
- **No controls in the bottom 34–44 pt**: panels stop above the home-indicator safe area plus 8 pt; the toolbar sits above the safe area.
- The simulator renders the video preview blank (the compositor only renders on a device), so the captures show the editor chrome.

### Kept from v27 that the board doesn't show
- Voice-over, Transition marks, Music, Cover text/elements/look tabs, Pauses and Clean Up inside Smart, comment card in the Text menu, keyframes, Export sheet code (not reachable).

### Next phase starts with
- Share (8.1–8.3), Your universe (9.2) and Pro (11.4).
