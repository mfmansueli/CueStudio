# 09 · Decisions (answers to the implementation questions)

These decisions are **final**. Where a line here and another doc disagree, **this file wins**, and the other docs have been corrected to match it.

## 1 · Formats: no format is lost
- The Format sheet has two parts in one native sheet (`.sheet`, detents `.medium` / `.large`; the sheet itself may scroll).
  - **Top grid (9 tiles, in this order):** Auto · Talking head · Tutorial · Storytime · List / tips · Review · Myth vs fact · POV · Sponsored ad.
  - **"More formats" section below the grid:** one row per remaining existing `ScriptType` case, in the current enum order. That includes Launch, Apology, Announcement, Hot take / reply, Opinion, and every other case the app has today.
- **New cases:** `talkingHead`, `mythFact`, `pov`. An existing case that already means one of these is reused instead of adding a new one, and listed in the phase report.
- **Auto:** the AI picks the format. If it can't classify the idea, it uses `talkingHead`.
- 05 L3 ("11 tiles") is replaced by this section.

## 2 · Scripts dock: no ambient sky inside
The dock is **clean glass**, with no dust, nebula, twinkles, cross glints or shooting star inside it. This is the prototype behaviour (`hero.dataset.dock` hides them), and it is the creator's decision.
- **Fill:** two radial auroras (violet `#9D8CFF` at 36% from the top left, `#5E4EE0` at 40% from the bottom right) over `rgba(26,24,64,0.56)`, blur 26 pt, saturation 170%, rim 0.5 pt `rgba(196,184,255,0.5)`, top highlight white 14%, radius 28.
- **What stays:** the app's single shared sky (behind every screen) and the star that rises on Send.
- 01 #4 and 02 §4 ("the LET'S CUE! card has its own ambient sky") are replaced by this section.

## 3 · My Cue Voice tip: TipKit, with a custom style that matches the prototype
- **TipKit does the logic:** eligibility, display frequency and invalidation (`Tip`, `TipView`, `Tips.configure`).
- **A custom `TipViewStyle` does the look:**
  - simulated-glass recipe (07 §2), radius 22;
  - leading ✦ in a 30 pt circle filled `rgba(157,140,255,0.22)`, glyph `#C4B8FF`;
  - title "Make scripts sound more like you" (15 pt semibold);
  - message "One quick question · voice {n}%" (13 pt, white 70%);
  - trailing **system xmark** (`Image(systemName: "xmark")`, 12 pt bold, white 50%, 44 pt hit area).
- **Enter:** opacity 0 → 1, y +10 → 0, scale 0.97 → 1, 0.40 s, `timingCurve(0.2, 0.9, 0.25, 1)`.
- **Exit:** opacity → 0 in 0.20 s, ease-out.
- **Reduce Motion:** opacity only, 0.20 s.
- **Place:** 10 pt above the Scripts dock; on Takes, 10 pt above the tab bar.

## 4 · Record tab: stays in the middle
The order is Scripts · Takes · **Record** · Profile · Settings, as today. Record is a normal tab that opens "Start recording" and is never a destination. **Do not** use `role: .search`. The 07 §1 suggestion has been removed.

## 5 · My Cue Voice data
- **New optional fields** (absent = empty, `decodeIfPresent`):
  - `style { energy, sentences, words, swearing }`;
  - `avoid: [String]` + `avoidNone: Bool` ("Nothing to avoid");
  - `reach { platforms: [Platform], length, humor }`;
  - `audienceLevel` (new / some / experienced).
- **`style.swearing` replaces the existing `swearing` field.** Migration: old value "never" or false → `.never`; any "mild" or true value → `.mildOnly`; absent → empty.
- **Roles:** the app's **8** `CreatorRole` cases, unchanged and in their current order (personal, entertainer, expert, educator, business, brands, news, community). These are also the 8 the prototype shows. 08 E1's "6" is corrected to 8.
- **Topics:** the app's existing `Niche` list, unchanged (keeps the starter ideas and translations). It is shown with "Suggested from your scripts" chips first, then the niches, then "+ Your own" (`OnboardingTopic.custom`). The topic chips on the 2.2 board are examples, not a new list. 08 E2's "12 categories" is corrected.
  - **World colour:** keep `OnboardingTopic.color(at:)` → worldWarm, worldMint, worldPink in pick order (max 3).
- **Tones:** 8, in this order, with these labels and examples:
  | # | Label | Example | Value |
  |---|---|---|---|
  | 1 | Conversational | "So here's the thing…" | existing `casual` |
  | 2 | Straight to the point | "Three steps. No fluff." | existing `professional` |
  | 3 | Educational | "Let's break down why." | existing `educational` |
  | 4 | Confident | "This is the method I trust." | existing `confident` |
  | 5 | Warm & calm | "Let's slow down for a second." | new `warmCalm` |
  | 6 | Energetic | "Okay, quick one today…" | existing `energetic` |
  | 7 | Playful | "My alarm and I are not friends." | existing `funny` |
  | 8 | Dry & sarcastic | "Great. Another life hack." | new `dry` |

  Raw values are unchanged, so **saved values need no migration**; only the labels change. Any other saved value is kept and shown as a custom tone.
- **Weights:** `08` §1 (Essentials 40 · Personality 40 · Proof 20) is the only truth. The app's current 60/25/15 is replaced.

## 6 · Dock fold and focus (motion)
- **Fold** when the list scrolls down past y = 40 pt (with a movement of more than 2 pt). **Unfold** on any upward movement of more than 2 pt, or when y < 40 pt. Never fold while the field is focused.
- **Chips row:** height 40 → 0 pt and margin 0 → −10 pt over **0.28 s, `timingCurve(0.2, 0.8, 0.2, 1)`**; opacity over **0.20 s, ease-out**. The row is hidden from accessibility while folded.
- **Field focus:** the list dims (brightness 0.5 + blur 3 pt) over **0.25 s ease-out**, and comes back the same way on blur. The dock rises with the keyboard (system keyboard animation).
- **Reduce Motion:** the chips row hides and shows with no animation; the dimming is opacity only, 0.15 s.

## 7 · Reduce Motion · Low Power Mode · "Starry sky: Off"
**Rule:** show the **final frame, with no loop**. Low Power Mode behaves like Reduce Motion for loops and ambient effects; one-shot transitions keep their timing at half the duration. "Starry sky: Off" hides the sky layers and the comet (solid night background). Exceptions and exact static states:
| Animation | Static state |
|---|---|
| Star to the sky (Send) | no flight; the star appears at its sky position (fade 0.15 s) |
| Star as transition (overlay) | no rise or ring; overlay fade 0.2 s; text and Cancel visible; on finish a 0.3 s crossfade to the script; the writing animation plays as a 0.2 s fade |
| Countdown, ring of stars | the number only, changing each second, ring static at full |
| Send-off (8.2) | the arrived state (star in place, no ghost trail) |
| Milestone (8.3) | the final constellation, no burst |
| First star (1.7) | the star lit, counter at the final value |
| Core "YOU" (9.2) | static core, orbits stopped |
| Empty-state orbiter | star fixed at the top of the ring |
| AI bar shimmer | static violet fill, no sweep |
| Sky twinkles and the comet | twinkles fixed at 40% opacity; no comet |
| Skeleton shine | static skeleton (no shine) |

## 8 · Star as transition: timing, Cancel, error
- **Minimum 3.0 s** from the tap, even if the AI answers sooner; it lasts longer if the AI needs it (`max(aiDuration, 3.0 s)`).
- **On content ready:** finish phrase "Almost camera-ready" → the ring opens (0.42 s, `timingCurve(0.4, 0, 0.2, 1)`) → crossfade to the script (0.22 s) → the star lands as the caret → the script's writing animation starts from zero.
- **Cancel** (fades in 0.3 s after the overlay appears; 44 pt hit area): cancel the AI request → the star fades out and falls 40 pt (0.3 s) → overlay fades (0.22 s) → back to Scripts with the idea still in the field. No script is created, no toast, haptic `.light`.
- **AI error mid-transition:** the same exit as Cancel, then the toast "Couldn't write it · Try again". The idea is kept.
- **No AI:** no overlay; the arrow is "Write it" and opens 4.2.
- **Phrases** (rotate every 1.6 s: fade out with y −4 pt, then in with y +4 → 0 over 0.3 s; the last one is always shown at the end): see `strings-en.csv`, keys `transition.step.1`–`8`.

## Nice-to-have, decided
- **Motion:** `motion/README.md` (text spec of every animation, with durations and curves). Animated HTML: the running prototype is the reference.
- **Strings:** `strings-en.csv` has every new v30 text, with key, English text, context and max length.
- **Icons:** no new glyphs beyond the v27 set. Keep the code-drawn set and match the stroke and shapes of the boards (02 §5). Use SF Symbols where the control is native (back chevron, xmark, ellipsis, magnifyingglass, plus).
- **Accessibility:** §A below.
- **PNG @3x:** not delivered. Compare against the running prototype (it is the visual truth).
- **Skeleton shine:** 1.4 s (the doc wins).

## A · VoiceOver order and labels (new elements)
| Element | Order / label / trait |
|---|---|
| Scripts dock | after the list, before the tab bar: Format "Format, {value}" (button) → Platform "Platform, {value}" (button) → Voice "My Cue Voice, {n} percent" (button) → field "Your idea" (text field; hint "Say or type an idea") → Another idea "Another idea" (button) → Mic "Dictate" (button; hint "Double-tap to dictate, or hold to record") → Send "Write it" (button) |
| Folded dock | the chips are hidden from VoiceOver |
| My Cue Voice tip | "Make scripts sound more like you. One quick question. Voice {n} percent." (button, opens the sheet) + "Close tip" (button) |
| Tip sheet | Close (system) → title → the question (header) → answers (buttons; selected = selected trait) → Something else → None of these |
| AI selection bar (4.x) | appears as a group "Edit selection": Rewrite · Shorter · Punchier · More me · Cut; then Keep · Undo · Try again |
| State strip (4.x) | one element "{READY / Draft / Recorded}, {format}, {n} cues", followed by its action button (Done / Record / Retake / Shape) |
| Star transition | announces "Writing in your voice", then each phrase (polite live region); Cancel is focused first |
