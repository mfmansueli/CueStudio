# 03 · Screen map (v29)

**Status:** 🆕 new · 🔁 changes a lot · ✏️ tweak only · ＝ unchanged (only the new tokens and icons).
**Transitions:** `push` (from the right, back by swipe), `sheet` (from below, 8 pt inset, radius 34, drag down to close), `full` (full screen, crossfade 0.3 s), `same` (same screen, content swaps), `tab` (tab bar swap, no animation; the capsule slides 0.32 s spring).
**Tab bar** visible on: 3.1/3.2, 6.2, 9.1, 9.2, 9.3, 11.1. Hidden on: onboarding, recorder, editor, sheets.

## 1 · First launch (shown once, empty library only)
| ID | Screen | Status | How you get here | Elements → result (transition) | Back | Failure |
|---|---|---|---|---|---|---|
| 1.1 | Welcome | ✏️ | first launch | **Get started** → 1.2 (push) · *I already use Cue* → 3.2 (tab) | — | — |
| 1.2 | Your universe (topics) | ✏️ | 1.1 | topic chip toggles (max 3) · *+ Your own* → inline field · **Continue** → 1.3 · *Skip* → 3.1 | 1.1 | blocked word → inline error "Apple Intelligence can't use this word." |
| 1.3 | First voyage (platform) | ✏️ | 1.2 | galaxy (one) → **Head to {Platform}** → 1.4 | 1.2 | — |
| 1.4 | First script | ✏️ | 1.3 | **Use this script** → 1.5 · *↻ Another* (same) · *Write my own* → 4.2 (push) · rewrite by selection (bar ✦) | 1.3 | no AI: built-in script tagged "TELEPROMPTER PRACTICE" |
| 1.5 | Give it a voice (permissions) | ✏️ | 1.4 | **Continue** → system alert (mic → speech → camera) → 1.6 | 1.4 | refused: continues; recording works without speech ("Steady" mode) |
| 1.6 | Practice | ✏️ | 1.5 | real prompter without recording · *Record it for real* → 5.1 · *Take me to my studio* → 3.2 | 1.5 | no camera: black backdrop + text |
| 1.7 | First star | ✏️ | after the 1st real take | *Go to my studio* → 3.2 · *Edit this take* → 7.1 | — | — |

## 2 · My Cue Voice (first setup)
| ID | Screen | Status | How you get here | Elements → result | Back | Failure |
|---|---|---|---|---|---|---|
| 2.1 | Creator type | ✏️ | 3.2 voice chip (no voice) · 9.3 | type tile (one) · *+ Something else* → field · **Continue** → 2.2 | sheet/back | — |
| 2.2 | Topics (colours) | ✏️ | 2.1 · 11.3 "Your topics" | chips (max 3, each turns into a world) · *+ Your own* · **Continue** → 2.3 | 2.1 | typo → "Did you mean "…"? Use · Keep mine" |
| 2.3 | Audience | ✏️ | 2.2 | segmented New to it / Some / A lot · free field · **Continue** → 2.4 | 2.2 | — |
| 2.4 | Tone | ✏️ | 2.3 | tones (max 2) · **Write my script** → 2.5 · *Just save my voice* → 9.3 · *Add a voice example* → example sheet | 2.3 | max reached → toast "Max 2 · tap to remove" |
| 2.5 | Does this sound like you? | ✏️ | 2.4 | My voice \| Without · **Sounds like me** → 4.1 (the script is born READY) · *Adjust* → 2.4 | 2.4 | no AI → only "Just save my voice" |

## 3 · Scripts and ideas
| ID | Screen | Status | How you get here | Elements → result | Back | Failure |
|---|---|---|---|---|---|---|
| 3.1 | Scripts (empty) | 🔁 | Scripts tab with 0 scripts | LET'S CUE! card (field, mic, ↑) · 3 ideas (tap = generate) · *Write my own ›* → 4.2 (blank DRAFT) · *Import ›* → Import sheet | — | no AI: ideas become "Write it" (opens 4.2 with the idea as the title) |
| 3.2 | Scripts | 🔁 | Scripts tab | **LET'S CUE!**: field + ↑ (or Enter) → star rises → 4.1 (push) · chip *Format ⌄* → Format sheet · *For {Platform} ⌄* → 3.4 (sheet) · *✦ Voice nn%* → 9.3 (push) · *↻ Another idea* (same) · platform filters (same) · **READY** row → 4.1 · **● REC** → 5.1 (full) · **DRAFT** row (*Continue ›*) → 4.2 · **RECORDED** row (*×n ›*) → 6.2 · *Logbook* → 3.6 (push) · *+* → 3.5 (sheet) · swipe left on a row → ● Record / More · long press → preview + Share / Duplicate / Delete | — | filter with 0 → "No {Platform} scripts yet" + *Create for {Platform}* · no AI: the card says "Write it" and opens 4.2 |
| 3.3 | Need an idea | ✏️ | 3.2 mic · 3.5 "Let Cue write it" | hold-to-talk · ideas (tap → 4.1) · *More ideas* (same) | 3.2 | no speech → typing field |
| 3.4 | Create for (platform) | ✏️ | card chip | one galaxy → back to 3.2 with the chip updated | sheet | — |
| 3.5 | Start a video (+) | 🔁 | 3.2 + | *Let Cue write it* → 3.3 · *Write it myself* → 4.2 (blank DRAFT) · 🆕 *Start from a format* → Format sheet (you-write mode) · 🆕 *Import* → Import sheet · *Answer a comment* → 10.1 · *Record without a script* → 5.1 | sheet | — |
| F | Format sheet | 🆕 | 3.2 chip · 3.5 | 9 tiles (Auto, Talking head, Tutorial, Storytime, List/tips, Review, Myth vs fact, POV, Sponsored ad), each showing its sections · **Done/Open** | sheet | Sponsored ad → Brand brief |
| B | Brand brief (sponsored ad) | 🆕 | F → Sponsored ad | saved brands (chips) · Brand · Product · Must say · Never say · Link · Code · "Paid partnership · #ad ALWAYS ON" · Save brand · **✦ Write the ad** (active with brand + product) | sheet | missing brand/product → toast "Add brand and product" |
| I | Import | 🆕 | 3.1 · 3.5 | Paste \| Scan \| Photo \| File · editable text · **Use this script** → 4.1 (READY) | sheet | Scan/Photo without permission → card "Allow camera in Settings" + *Open Settings* |
| 3.6 | Logbook | ✏️ | 3.2 | hold-to-capture · idea row → 4.1 · *✦ Write* on the row → 4.1 (AI) · *Done* | 3.2 | empty → empty state |

## 4 · Script
| ID | Screen | Status | How you get here | Elements → result | Back | Failure |
|---|---|---|---|---|---|---|
| 4.1 | Script page | 🔁 | 3.2 card/row · 2.5 · I · 3.6 · 10.x | 🆕 **state strip** (READY/DRAFT/RECORDED · format · cues · one next step) · editable text · selection → AI bar · *Hook* → 4.3 · *✦ Improve* → 4.4 · ••• → Versions · Script language · Duplicate · **● Record** (bottom, one per screen) → 5.1 | 3.2 (back with changes = DRAFT + toast "Saved as draft") | no AI: the strip has no ✦ Shape; the AI bar doesn't appear |
| 4.2 | Script editing | 🔁 | 3.2 DRAFT · 3.5 · 1.4 · 10.2 | keyboard + CUES bar (pause, smile, emphasis, look at camera) · AI bar on selection · strip with **Done** (yellow in DRAFT) | 4.1 or the origin | Done with empty sections → "{n} sections are still empty." *Done anyway / Keep writing* · Done with no text → toast "Nothing to save yet" |
| 4.3 | Pick a hook | ✏️ | 4.1 | hook (tap = swap, toast "Hook swapped") · *More hooks* | 4.1 | — |
| 4.4 | Improve this script | ✏️ | 4.1 · ••• | Shorter / Punchier hook / Sound more like me… → back to 4.1 with violet text + Keep/Undo | 4.1 | AI quota ended → 11.4 |
| A | AI bar on a selection | 🆕 | select text (4.1, 4.2, 10.3, 1.4) | Rewrite · Shorter · Punchier · More me · Cut → "✦ WRITING…" → ✓ Keep · ↺ Undo · ✦ Try again | tap outside = Keep | no AI: the bar doesn't exist |

## 5 · Recording (native: `CueRecorder28` = the v26 recorder in v28 dress)
| ID | Screen | Status | How you get here | Elements → result | Back | Failure |
|---|---|---|---|---|---|---|
| 5.1 | Countdown (ring of stars) | ✏️ | ● REC · Record | 3/5/10 s or Off → 5.2 · tap = cancel → origin | origin | — |
| 5.2 | Selfie recorder | 🔁 | 5.1 | **bar with a background** (Voice \| Steady, ⤒ back to top, play/pause, Aa → prompter sheet, mic/setup HUD, last take, camera settings, ● record, flip, •••) · **text box**: ⌟ handle (resizes height and width) and the **reading-line pinch** on the right edge · ● → recording: **compact bar** (Stop, time in yellow mono, mode, ⤒) and the box shrinks with focus · ••• → More sheet | ✕ → origin | no mic/speech → Steady only (Voice disabled, with an explanation) · no camera → black backdrop |
| 5.3 | Studio mode | 🔁 | 5.2 Studio switch | rear camera + selfie preview in the corner (64 × 114) · speed slider · same compact bar | 5.2 | — |

## 6 · Takes
| ID | Screen | Status | How you get here | Elements → result | Back | Failure |
|---|---|---|---|---|---|---|
| 6.1 | Pick your best take | ✏️ | Stop | ★ suggested by Cue (violet) · *Use take {n}* → 6.3 · Play | — | single take → straight to 6.3 |
| 6.2 | Takes | ✏️ | Takes tab | pipeline TO PICK › IN EDIT › READY › SHARED (filters) · NEXT · 9:16 grid · *Select* · long press → preview | — | empty → empty state |
| 6.3 | Open take | ✏️ | 6.2 · 6.1 | ▶ (opens paused) · ★ · 🗑 (Undo 4 s) · **Edit** → 7.1 · Retake → 5.1 · Save → Photos · **Share** → 8.1 · *From script ›* → 4.1 · "{n} of 5 free exports" → 11.4 | 6.2 | Photos denied → card + *Open Settings* |

## 7 · Video editor
| ID | Screen | Status | How you get here | Elements → result | Back | Failure |
|---|---|---|---|---|---|---|
| 7.1 | Opening the editor | ＝ | Edit | auto (2.8 s) → 7.2 | — | — |
| 7.2 | Editor | 🔁 | 7.1 | timeline with lanes (Aa white, captions violet, music green, VO amber, media light blue) · toolbar in CapCut order: Edit · Audio · Text · Captions · Filters · ✦ Smart · Cover; each opens a **fixed-height panel with no vertical scroll** · back (keeps the draft) · **Done** → 7.6 | 6.3 (toast "Draft saved") | — |
| 7.3 | Text | ✏️ | Text | 7 styles · free fonts · Size and Glow sliders | 7.2 | — |
| 7.4 | Captions | ✏️ | Captions · tap the caption on the video | styles · size S–XL · position · highlight | 7.2 | speech unavailable → "Captions need speech recognition" |
| 7.5 | Sound | ✏️ | Audio | Your voice · Music · Clean up | 7.2 | — |
| 7.6 | Is it ready to post? | ✏️ | Done | **Yes, share to social media** → 8.1 · Download video → Photos + 6.3 · Ready, I'll post later → 6.2 (READY) · Not yet, I'll come back → 6.3 (IN EDIT) | swipe = back to the editor | — |
| 10.4 | Comment card in the editor | ✏️ | 10.x | drag/resize · Done → 7.6 | 7.2 | — |

## 8 · Share
| ID | Screen | Status | How you get here | Elements → result | Back | Failure |
|---|---|---|---|---|---|---|
| 8.1 | Ready to travel | ✏️ | Share | platforms · Save to Photos · Other apps · 🆕 "AD · #ad in caption" warning for an ad · "{n} of 5 left" → 11.4 | 6.3 | out of free exports → 11.4; export failed → "Couldn't export · Try again" |
| 8.2 | The send-off | ✏️ | after the export | *Share again* · *Done* → 8.3/6.2 · *Star in your universe* → 9.2 | — | — |
| 8.3 | Milestone unlocked | ✏️ | milestone | *Use Deep Space* → icon + 9.2 · *Keep my current icon* → 6.2 | — | — |

## 9 · Profile
| ID | Screen | Status | How you get here | Elements → result | Back | Failure |
|---|---|---|---|---|---|---|
| 9.1 | Profile | 🔁 | Profile tab | identity (name, @, photo in the iOS sheet) · **Your universe** card → 9.2 · **My Cue Voice** card (meter, one sentence, next question) → 9.3 · plan → 11.4 | — | — |
| 9.2 | Your universe | 🔁 | 9.1 · 8.2 | 🆕 **animated core "YOU"** (no photo) · worlds by topic · next milestone · *Share my universe* → share sheet | 9.1 | empty → "Your first star is one video away" |
| 9.3 | My Cue Voice (full page) | 🆕 | 9.1 · 3.2 chip · 2.4 | 3 layers (Essentials · Personality · Proof) · every row opens its edit sheet · "What Cue sends" (the brief) · voice examples · on/off | 9.1 | no AI: "My Cue Voice needs Apple Intelligence" and the data stays saved |

## 10 · Comments
| ID | Screen | Status | How you get here | Elements → result | Back | Failure |
|---|---|---|---|---|---|---|
| 10.1 | Send a comment | ✏️ | 3.5 | screenshot/paste · *Continue* → 10.2 · *Save to Logbook* → 3.6 | 3.5 | — |
| 10.2 | Is this right? | ✏️ | 10.1 | edit the text read · *✦ Draft my reply* → 10.3 · *Write it myself* → 4.2 | 10.1 | no AI → only "Write it myself" |
| 10.3 | Draft in your voice | ✏️ | 10.2 | AI bar on a selection · *Edit* → 4.2 · **Record reply** → 5.1 | 10.2 | — |

## 11 · Settings and Pro
| ID | Screen | Status | How you get here | Elements → result | Back | Failure |
|---|---|---|---|---|---|---|
| 11.1 | Settings | 🔁 | Settings tab | "Your setup" card → Recording sheet · 🆕 **sheets** Recording / Remote / Language & Region / Privacy & AI data · Prompter → 11.2 · Personalize → 11.3 · Pro → 11.4 · Restore purchases · Acknowledgements · 16 pt between blocks | — | Remote: connect → waiting → connected / failure "Couldn't connect" + Try again |
| 11.2 | Prompter | 🔁 | 11.1 · Aa | proportion preview · **simple sliders** (table §6 of the tokens) · Follow my voice | 11.1 | — |
| 11.3 | Personalize | ✏️ | 11.1 | sky Off/Soft/Full · haptics · celebrations · app icons · *Your topics* → 2.2 | 11.1 | locked icon → 11.4 |
| 11.4 | Cue Pro | ✏️ | many | plans · **Start 7-day free trial** · Restore · Terms · Privacy | ✕ | purchase failed → "Purchase didn't go through" |

## Empty states (pattern E)
E-3.1 (= 3.1) · E-6.2 Takes · E-3.6 Logbook · E-9.2 Your universe · E-3.2f filter with no results. Details in stage 2.

## What goes away in v29
| What | Replaced by |
|---|---|
| Yellow orb travelling across the tab bar | Liquid Glass capsule on the active tab |
| `OrbSlider` visuals (orb, planet, trail) | Simple slider (same math, `OrbSliderMath`) |
| Draft \| Shaped switch on the script | State strip + Shape as a tool |
| My Cue Voice editing through the 2.x screens in Profile | Full page 9.3 + sheet per row |
| Static AI aura on the card | Card ambient sky (motion stage) |
| Creator photo at the centre of the universe | Animated core "YOU" |
