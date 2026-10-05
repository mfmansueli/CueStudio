# 08 · My Cue Voice questions: frequency, order and the complete question bank (v30)

> Final lists (roles, topics, tones), new fields and migrations: **09-Decisions.md §5**. Texts: `strings-en.csv` (`vq.*`).

**Purpose:** the tip + sheet (04 §F9) asks, one at a time, **only** the questions needed to bring My Cue Voice to 100%. This file is the source of truth for **when** a question appears, **which** one, and **what counts as complete**. Implement it as `VoiceQuestionScheduler` (a new service) + TipKit; no server.

## 1. What "complete" means: fields and weight (total 100)
These are the weights of `voiceStrength`. They replace the 60/25/15 split mentioned in 04 §F9, which was approximate.
| Layer | Field (`CreatorProfile`) | Weight | Counts as filled when |
|---|---|---|---|
| Essentials | `role` | 10 | 1 role chosen or written |
| Essentials | `topics` | 10 | ≥ 1 topic |
| Essentials | `audience` | 10 | 1 audience + 1 knowledge level |
| Essentials | `tone` | 10 | 1–2 tones |
| Personality | `style` (energy, sentences, words, swearing) | 6 | all 4 answered |
| Personality | `formats` | 6 | ≥ 1 format |
| Personality | `openings` (hooks) | 6 | ≥ 1 opening |
| Personality | `endings` (sign-off / CTA) | 6 | 1 ending |
| Personality | `phrases` | 6 | ≥ 1 phrase of their own |
| Personality | `avoid` | 5 | ≥ 1 item **or** an explicit “Nothing to avoid” |
| Personality | `reach` (platforms + length + humor) | 5 | all 3 answered |
| Proof | `examples` + approvals | 20 | 1 example = 8 · 2 = 14 · 3 = 20. Every 2 “Sounds like me” approvals on 2.5 count as 1 example. |
`voiceStrength = min(100, Σ weights of filled fields)`. A **skipped** question (“None of these”) never adds weight, but it leaves the queue (§3).

## 2. Question bank (all of them, in queue order)
Text in English (keys in `strings-en.csv`, Stage 4). Options in this order; **“+ Something else”** (free text, 2–40 characters, validation 04 §F9) and **“None of these”** appear at the end of every list unless the row says otherwise.
| # | Key | Field | Question | Answer | Options |
|---|---|---|---|---|---|
| E1 | `vq.role` | role | What kind of creator are you? | single | the 8 `CreatorRole` cases (09 §5) |
| E2 | `vq.topics` | topics | What do you talk about? | up to 3 | Suggested from your scripts · the app’s `Niche` list · + Your own (09 §5) |
| E3 | `vq.audience` | audience | Who's watching? | single + level | 3 suggestions for the role + “I'm still figuring it out” · then level: New to it · Some basics · Experienced |
| E4 | `vq.tone` | tone | How do you talk on camera? | up to 2 | the 8 tones in 09 §5 |
| P1 | `vq.endings` | endings | How do you usually end a video? | single | Save this · Follow for more · Comment your answer · Link in bio · Try it and tell me |
| P2 | `vq.openings` | openings | How do you like to open? | single | Bold claim · Question · Story opener · Surprising fact · POV |
| P3 | `vq.formats` | formats | What do you film most? | single | Talking head · Tutorial / how-to · Storytime · List / tips · Review · Reaction |
| P4 | `vq.length` | reach.length | How long are your videos, usually? | single, no free text | Under 30 s · 30–60 s · 1–3 min · Longer |
| P5 | `vq.humor` | reach.humor | How much humor in your videos? | single, no free text | None · A little · A lot |
| P6 | `vq.platforms` | reach.platforms | Where do you post most? | single, no free text | TikTok · Reels · Shorts · YouTube · LinkedIn · Stories |
| P7 | `vq.energy` | style.energy | What's your energy on camera? | single, no free text | Calm · Balanced · High |
| P8 | `vq.sentences` | style.sentences | Short sentences or longer ones? | single, no free text | Short · Mixed · Long |
| P9 | `vq.words` | style.words | How technical are your words? | single, no free text | Plain · Some slang · Expert terms |
| P10 | `vq.swearing` | style.swearing | Any swearing? | single, no free text, no “None of these” | Never · Mild only |
| P11 | `vq.phrases` | phrases | A phrase you always say? | **free text first** (keyboard opens), list below | “Okay, real talk.” · “Here's the thing.” · “Let's go.” (examples to tap and edit) |
| P12 | `vq.avoid` | avoid | Anything Cue should never write? | up to 3 | Clickbait · Hype words · Emojis in captions · Medical claims · Politics · **Nothing to avoid** (counts as filled) |
| X1 | `vq.example` | examples | Paste something you wrote or said | opens the Add example sheet (9.3) | Paste · Speak · My scripts; requires “I said or wrote this myself” |
- “Mild only” on P10 still never allows slurs or strong swearing (Apple Intelligence won't generate them).
- E1–E4 normally come from onboarding (2.1–2.4). They enter the queue only if onboarding was skipped or left incomplete, and then **they come first**.
- X1 appears only after ≥ 2 scripts have been generated with My Cue Voice (so the creator has seen the value).

## 3. Order
1. Missing Essentials (E1→E4).
2. Personality in table order (P1→P12), skipping fields that are already filled.
3. Proof (X1), repeated until there are 3 examples.
- **Contextual pull-forward** (once each): after the 1st export → P6; after editing a generated script for the 2nd time → P9; after the 3rd script recorded → X1.
- A question answered in the full page (9.3) leaves the queue immediately.

## 4. When it appears (frequency) — exact rules
| Rule | Value |
|---|---|
| Surfaces | Scripts (3.2) and Takes (6.2) only. Never in onboarding, the recorder, the editor, sheets, Settings or Pro. |
| First eligibility | after the creator has **≥ 1 script** and has opened the app on **2 different days** |
| Moment | 1.2 s after the screen settles, only if: no sheet, toast, keyboard or tip on screen; the user isn't scrolling; the dock isn't expanded |
| Cap | **1 tip per day**, **3 tips per rolling 7 days** |
| “One more?” after answering | shows the next question in the same sheet; doesn't count toward the cap; at most **3 answers in a row**, then the sheet closes with “✓ Saved · voice nn%” |
| Not now / ✕ / swipe down / tap the backdrop | that question is snoozed for **3 days**; on the next eligible day the **next** question in the queue is shown |
| Same question dismissed 2× | it moves to the end of the queue |
| 3 dismissals in a row with no answer | all tips pause for **14 days** |
| “None of these” | the question is skipped for good (no weight); it can still be answered in 9.3 |
| Stop | at **100%**, or when every question is answered or skipped. At 100%, one toast only: “✓ Cue Voice complete” |
| Turned off | no tips if “Write in my voice” is off, if there is no Apple Intelligence, or if the app language has no Apple Intelligence support |
| Reset | “Reset My Cue Voice” in 9.3 clears the queue history (snoozes, pauses, skips) |

## 5. State to persist (UserDefaults, per device)
`vq.firstEligibleDays` (Set of dates, max 2) · `vq.shownDates` ([Date], last 7 days) · `vq.snoozedUntil` ([key: Date]) · `vq.dismissCount` ([key: Int]) · `vq.consecutiveDismissals` (Int) · `vq.pausedUntil` (Date?) · `vq.skipped` (Set of keys) · `vq.pulledForward` (Set of trigger names) · `vq.completeToastShown` (Bool).

## 6. SwiftUI
- Tip: `struct VoiceQuestionTip: Tip` with `@Parameter static var nextKey`, `rules: [#Rule(Self.$nextKey) { $0 != nil }]`, `options: [Tips.MaxDisplayCount(3)]`. Configure with `Tips.configure([.displayFrequency(.daily)])`. The weekly cap and the pauses are enforced by `VoiceQuestionScheduler`, which sets `nextKey`.
- Show it with `TipView(VoiceQuestionTip(), arrowEdge: .bottom)` above the dock (`.safeAreaInset` content); tapping it calls `scheduler.present()` → `.sheet(item:)` with `.presentationDetents([.medium])`, `.presentationDragIndicator(.visible)`.
- Answers write to `CreatorProfileService` immediately (the same API as 9.3), so the Scripts dock chip “✦ Voice nn%” updates live.
- Test: a unit test per rule in §4 (fake clock), and one checking that answering every row in §2 reaches exactly 100.
