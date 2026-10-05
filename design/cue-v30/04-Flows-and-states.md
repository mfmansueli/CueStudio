# 04 · Flows and state machines (v30)

Notation: `STATE` · *event* → `NEXT` / action. Every flow lists what happens on: **cancel**, **no permission**, **no internet**, **no AI** (Apple Intelligence unavailable, turned off, or the language isn't supported) and **error**.
The app has **no server**. "No internet" only affects the App Store (purchase/restore) and the first download of the speech model. Everything else works offline.

## F1 · First launch
`LAUNCH` → (`OnboardingService.resolve` = library empty and onboarding never shown) → `WELCOME` (1.1), otherwise → `SCRIPTS` (3.2 or 3.1).
| From | Event | To / action |
|---|---|---|
| WELCOME | *Get started* | TOPICS (1.2) |
| WELCOME | *I already use Cue* | SCRIPTS · onboarding marked as seen |
| TOPICS | *Continue* (≥1 topic) · *Skip* | PLATFORM (1.3) · SCRIPTS_EMPTY with what was already picked |
| PLATFORM | *Head to {P}* | FIRST_SCRIPT (1.4): generates ≈15 s on the topic and platform |
| FIRST_SCRIPT | *Use this script* | PERMISSIONS (1.5) · creates the real script with `isFinished = true` |
| FIRST_SCRIPT | *Write my own* | EDIT (4.2), blank DRAFT |
| PERMISSIONS | *Continue* | system alerts in order: mic → speech (only if the mic was allowed) → camera → PRACTICE (1.6) |
| PRACTICE | *Record it for real* | COUNTDOWN (5.1) → F3 |
| PRACTICE | *Take me to my studio* | SCRIPTS |
| after the 1st take | — | FIRST_STAR (1.7), only once |
- **Cancel:** closing the app halfway resumes at the same step (`OnboardingStep` saved).
- **No permission:** refusing never blocks. Without the mic, the prompter starts in Steady. Without the camera, practice runs over a black backdrop.
- **No AI:** 1.4 uses `OnboardingScript` (the built-in script), labelled "TELEPROMPTER PRACTICE".
- **Error** generating: falls back to the built-in script, with no message.

## F2 · Create a script (READY / DRAFT / RECORDED states)
**Single rule:** `RECORDED` if there is ≥1 take of the script · otherwise `READY` if `isFinished` · otherwise `DRAFT`.
`isFinished = true` on: **Done** · AI delivers a complete script (LET'S CUE!, format, Logbook ✦ Write, reply 10.3, 2.5) · **Use this script** (Import) · onboarding.
`isFinished = false` on: editing text and leaving **without** Done (back, swipe, app goes to the background), when the script is not RECORDED.
**Shape, cues and "Remove all cues" never change the state.**
| Path | Starts as | Next |
|---|---|---|
| LET'S CUE! (with or without a format) | READY | edit + Done → READY · edit + back → DRAFT (toast "Saved as draft") |
| Sponsored ad | READY (only generates with brand + product) | `#ad` to Share |
| Start from a format | DRAFT, sections empty | Done with empty sections → "Done anyway / Keep writing" |
| Write it myself | DRAFT, blank | Done with no text → toast "Nothing to save yet" (not saved) |
| Import | review sheet | *Use this script* = Done → READY |
| Edit after recording | RECORDED (stays) | the strip shows "CHANGED SINCE TAKE {n}" when `script.version > take.scriptVersion` |
| Duplicate | inherits the state; title + " (copy)" | — |
- **Cancel** during AI generation: the script isn't created and you go back to the card with the idea preserved.
- **No AI:** the card says "Write it" and opens 4.2 with the idea as the title (DRAFT). There is no ✦ Shape, no AI bar and no Improve.
- **AI error:** toast "Couldn't write it · Try again"; the idea stays in the field.
- **AI quota used up** (current rules): opens 11.4.
- **Recording is always allowed** in any state.

## F3 · Record
`IDLE` (5.2) · *● or ● REC* → `COUNTDOWN` (5.1, Off/3/5/10 s) → `RECORDING` → *Stop* → `SAVING` → `PICK` (6.1 if ≥2 takes of the script in this session, otherwise 6.3).
| State | What you see | Events |
|---|---|---|
| IDLE | full bar with a background, text box with handle ⌟ and pinch | Voice\|Steady · ⤒ · play/pause · Aa · camera settings · flip · ••• · ● |
| COUNTDOWN | ring of stars | tap = cancel → IDLE |
| RECORDING | **compact bar** (Stop, yellow mono time, mode, ⤒); the box shrinks with focus | Stop · tap the screen = shows the full bar for 4 s · pause prompter |
| SAVING | "Saving take…" | — |
- **Cancel:** ✕ in IDLE goes back to the origin. Leaving during RECORDING saves the take recorded up to that point.
- **No mic:** recording disabled, card "Cue needs the microphone" + *Open Settings*.
- **No speech recognition** (permission or language): Voice is disabled with the label "Not available in {language}", and Steady is used.
- **No camera:** "Camera off", and you record audio + text only if allowed (current behaviour).
- **Storage full:** stops, saves what was recorded, toast "Storage full · Take saved".
- **Interruption** (call): stops and saves.

## F4 · Review and pick the best take
`PICK` (6.1): Cue suggests ★ (`BestTakeSuggester`) → *Use take {n}* → `TAKE` (6.3) with ★ marked.
Takes pipeline (unchanged): **TO PICK** (≥2 takes and none ★) → **IN EDIT** (open draft) → **READY** (not exported) → **SHARED** (exported). Derived, never set by hand.
- **Delete** (🗑): removes it right away, with Undo for 4 s.
- **No AI:** the suggestion uses the current heuristic (length closest to the script); without it, it doesn't show the violet ★.

## F5 · Edit
`EDITOR` (7.2) · *back* → save `QuickEditDraft` → TAKE (IN EDIT) + toast "Draft saved" · *Done* → `READY_Q` (7.6):
| 7.6 choice | Result |
|---|---|
| Yes, share to social media | applies the edit → SHARE (8.1) |
| Download video | applies + exports to Photos → TAKE · toast "Saved to Photos" |
| Ready, I'll post later | applies → Takes (READY) |
| Not yet, I'll come back | keeps the draft → TAKE (IN EDIT) |
| swipe down | back to the editor, nothing changes |
- Editor panels have a fixed height; tools open in their own panel; nothing scrolls vertically.
- **No speech:** Captions shows "Captions need speech recognition".
- **No AI:** ✦ Smart shows only the non-AI actions (Cut pauses, Remove "um"s via `VoiceActivity`).

## F6 · Export and share
`SHARE` (8.1) · *platform* → check `KeychainExportCountStore` (free: 5 total) → `EXPORTING` (progress) → saves to Photos → opens the network's app → `SENT` (8.2) → (milestone?) `MILESTONE` (8.3).
- **Ad:** a warning bar on 8.1 and `#ad` in the copied caption.
- **No export left** (free, 5 used): → 11.4.
- **Photos denied:** card + *Open Settings*.
- **Network app not installed:** opens the share sheet.
- **Export error:** "Couldn't export · Try again", and the count doesn't move.

## F7 · Paywall and subscription (unchanged rules)
`PRO` (11.4) · *Start 7-day free trial* → StoreKit → `SUBSCRIBED` (back to the origin) · *Restore* → `RESTORING` → success/none. Free: 5 exports; Pro: unlimited; 7-day trial; $39.99/year (prices come from StoreKit).
- **Purchase cancelled:** back to 11.4, with no message.
- **No internet:** "Can't reach the App Store".
- **Error:** "Purchase didn't go through".

## F8 · Settings
| Sheet | States |
|---|---|
| Recording | front/back camera · quality · fps · format · mic (cycles through the connected ones) |
| Remote | OFF → *Connect* → WAITING (yellow ring) → CONNECTED (green) · *Disconnect* → OFF · failure → "Couldn't connect · Try again" |
| Language & Region | app (iPhone Language) · voice following · script language |
| Privacy & AI data | on-device AI · Help improve · Delete my Cue data (confirmation alert, irreversible) |

## F9 · My Cue Voice (3 layers)
Strength (0–100%) and the full question bank, order and frequency: **see `08-My-Cue-Voice-questions.md`** (source of truth). Summary: Essentials 40 · Personality 40 · Proof 20.
| Input | Validation |
|---|---|
| free text (tag) | 2–40 characters · typo → "Did you mean "{x}"? Use · Keep mine" · blocked word → not saved, "Apple Intelligence can't use this word." |
| duplicate | "Already added." and it gets selected |
| limits | topics ≤ 3, tone ≤ 2 → toast "Max {n}" |
| nudge | **TipKit-style inline tip** above the Scripts dock (or above the tab bar on Takes): ✦ “Make scripts sound more like you · One quick question · voice nn%” + ✕. Tap → **sheet** (`.sheet` + `.presentationDetents([.medium])`, grabber, dimmed backdrop): toolbar close (`Button(role: .close)`, xmark in a glass circle, leading; counts as *Not now*) · title *My Cue Voice* · ✦ nn%; the question as a large title; answers as an inset-grouped list (one tap = answer), then *+ Something else* (violet) and *None of these*. Swipe down / tap the backdrop / close / the tip’s xmark = dismiss, held back for 3 days. Which question and how often: `08-My-Cue-Voice-questions.md` §2–§4. In SwiftUI use TipKit (`TipView`, `Tips.MaxDisplayCount`, `.invalidate`) for the tip. |
- **No AI:** the page shows "Needs Apple Intelligence" and the data stays saved and editable.

## Global states (every screen)
| State | Rule |
|---|---|
| Loading | skeleton of the real structure (cards at `surface` with a 1.4 s shine (decided: 1.4 s)) — no spinners over content |
| Empty | pattern E (02-Tokens §1.2) |
| No AI | violet actions disappear; nothing turns grey with a lock |
| Accessibility XL | single column; chips wrap; mono labels wrap at `.accessibility1` |
| RTL (Arabic) | whole layout mirrored; ⤒, play and the timeline are not mirrored (media direction) |
