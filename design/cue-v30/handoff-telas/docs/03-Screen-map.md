# 03 · Screen map (v30)

**Status:** 🆕 new · 🔁 changes a lot · ✏️ tweak only · ＝ unchanged (only the new tokens and icons).
**Transitions:** `push` (from the right, back by swipe), `sheet` (from below, 8 pt inset, radius 34, drag down to close), `full` (full screen, crossfade 0.3 s), `same` (same screen, content swaps), `tab` (tab bar swap, no animation; the capsule slides 0.32 s spring).
**Tab bar** visible on: 3.1/3.2, 6.2, 9.1, 9.2, 9.3, 11.1. Hidden on: onboarding, recorder, editor, sheets.

## 1 · First launch (shown once, empty library only)
| ID | Screen | Status | How you get here | Elements → result (transition) | Back | Failure |
|---|---|---|---|---|---|---|
| 1.1 | Welcome (star opening, wordmark under the C → 09 §12) | ✏️ | first launch | **Get started** → 1.2 (push) · *I already use Cue* → 3.2 (tab) | — | — |
| 1.2 | Your universe (topics) | ✏️ | 1.1 | topic chip toggles (max 3) · *+ Your own* → inline field · **Continue** → 1.3 · *Skip* → 3.1 | 1.1 | blocked word → inline error "Apple Intelligence can't use this word." |
| 1.3 | First voyage (platform) | ✏️ | 1.2 | galaxy (one) → **Head to {Platform}** → 1.4 | 1.2 | — |
| 1.4 | First message (script) | ✏️ | 1.3 | **Load in teleprompter** → 1.5 · not editable here, no *Another*, no *Write my own* | 1.3 | no AI: built-in script tagged "TELEPROMPTER PRACTICE" |
| 1.4b | First message · slow loading | 🆕 | 1.4 when the AI takes > 6 s | skeleton lines · spinner · after 15 s *Use a ready-made message* → 1.4 · after 25 s loads it by itself (09 §16) | 1.3 | no network → built-in message after 3 s |
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
| 3.1 | Scripts (empty) | 🔁 | Scripts tab with 0 scripts | **Top:** title · NO SCRIPTS YET · ring + star · “Your scripts live here” · one line · ✦ IDEAS FOR YOU (3 ideas, tap = generate) · *Write my own ›* → 4.2 (blank DRAFT) · *Import ›* → Import sheet. **Bottom: the AI dock** (same as 3.2, without the Format chip): For {Platform} ⌄ · ✦ My Cue Voice · field (empty = first suggested idea) · mic · ↑ → star rises → 4.1 | — | no AI: ideas become “Write it” (opens 4.2 with the idea as the title) |
| 3.2 | Scripts | 🔁 | Scripts tab | **Top = the world of scripts:** title · *Logbook* (violet, with count) → 3.6 · search · *+* → 3.5 (sheet) · HUD “08 SCRIPTS · 03 READY” · platform filters with counts (same) · groups **READY** (row → 4.1 · **● REC** → 5.1 full) · **DRAFTS** (*Continue ›* → 4.2) · **RECORDED** (*×n ›* → 6.2) · end of list: Logbook section (✦ Write → 4.1, *Open Logbook* → 3.6) · swipe left on a row → ● Record / More · long press → preview + Share / Duplicate / Delete. **Bottom = the AI dock** (fixed above the tab bar, `.safeAreaInset(.bottom)`, glass, radius 28): row 1 chips *Format ⌄* → Format sheet · *For {Platform} ⌄* → 3.4 · *✦ Voice nn%* → 9.3; row 2 field (2 lines max) · *↻* another idea · mic (tap = dictate, hold = record while held) · ↑ (or Enter) → star rises → 4.1. Scrolling down folds row 1 away; scrolling up or stopping brings it back. Focusing the field raises the dock with the keyboard and dims the list. The My Cue Voice tip (08) sits just above the dock. | — | filter with 0 → “No {Platform} scripts yet” + *Create for {Platform}* · no AI: the dock’s arrow becomes “Write it” and opens 4.2 |
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

## 5 · Recording (native: `CueRecorder30` = the v26 recorder in v28 dress)
| ID | Screen | Status | How you get here | Elements → result | Back | Failure |
|---|---|---|---|---|---|---|
| 5.1 | Countdown (ring of stars) | ✏️ | ● REC · Record | 3/5/10 s or Off → 5.2 · tap = cancel → origin | origin | — |
| 5.2 | Selfie recorder | 🔁 | 5.1 | **bar with a background** (Voice \| Steady, ⤒ back to top, play/pause, Aa → prompter sheet, mic/setup HUD, last take, camera settings, ● record, flip, •••) · **text box**: ⌟ handle (resizes height and width) and the **reading-line pinch** on the right edge · ● → recording: **compact bar** (Stop, time in yellow mono, mode, ⤒) and the box shrinks with focus · ••• → More sheet | ✕ → origin | no mic/speech → Steady only (Voice disabled, with an explanation) · no camera → black backdrop |
| 5.3 | Studio · prompter only | 🔁 | 5.2 Studio switch | **no camera, no recording, no camera permission** (mic only for Voice Following) · progress line "0:18 LEFT · IDEAL 0:15–1:00" · transport: Voice \| Steady · ⤒ · ‹‹ previous sentence · ▶ play/pause (yellow; countdown first if set) · ›› next sentence · chips Speed · Size · Line · Width · Mirror (one chip open = its slider in the bar) · tap the screen = hide/show the bar · top right ⚙ → Prompter sheet (countdown before play, Flip vertically, Remote control) · screen stays on · box handle ⌟ and reading-line pinch as in 5.2 | 5.2 | no mic: Voice disabled, Steady only |

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
| 11.1 | Settings | 🔁 | Settings tab | "Your setup" card → Recording sheet · 🆕 **sheets** Recording / Remote / Language & Region / Privacy & AI data · Prompter → 11.2 · Personalize → 11.3 · Pro → 11.4 · Restore purchases · Acknowledgements · 16 pt between blocks | — | Remote: connect → waiting → connected / failure "Couldn't connect" + Try again | **→ v30: native list, see 09 §11.**
| 11.2 | Prompter | 🔁 | 11.1 · Aa | proportion preview · **simple sliders** (table §6 of the tokens) · Follow my voice | 11.1 | — | **→ v30: native list, see 09 §11.**
| 11.3 | Personalize | 🔁 | 11.1 | sky Off/Soft/Full · haptics · celebrations · app icons · *Your topics* → 2.2 | 11.1 | locked icon → 11.4 | **→ v30: native list, see 09 §11.**
| 11.4 | Cue Pro | ✏️ | many | plans · **Start 7-day free trial** · Restore · Terms · Privacy | ✕ | purchase failed → "Purchase didn't go through" |

## Empty states (pattern E)
E-3.1 (= 3.1) · E-6.2 Takes · E-3.6 Logbook · E-9.2 Your universe · E-3.2f filter with no results. Details in stage 2.

## What goes away in v30
| What | Replaced by |
|---|---|
| Yellow orb travelling across the tab bar | Liquid Glass capsule on the active tab |
| `OrbSlider` visuals (orb, planet, trail) | Simple slider (same math, `OrbSliderMath`) |
| Draft \| Shaped switch on the script | State strip + Shape as a tool |
| My Cue Voice editing through the 2.x screens in Profile | Full page 9.3 + sheet per row |
| Static AI aura on the card | Card ambient sky (motion stage) |
| Creator photo at the centre of the universe | Animated core "YOU" |


### 9.2 · Your universe, one per year
**Year selector** at the top (2026 · 2025 · …, a segmented control in glass); swipe left/right on the universe to change year. The line under it reads "{n} VIDEOS SHARED IN {year}" (+ " · SEALED" for past years).
- **Current year = live:** every video shared adds a dot; planets grow. The previous year's universe shows behind it, very faint (ghost layer).
- **Past years = sealed** on Dec 31 at 23:59 local time: animations pause, colours dim slightly (saturation .75, brightness .92), badge "◆ SEALED · DEC 31, {year}". Nothing in a sealed year changes.
- **New year:** starts with only the core and "Your {year} universe starts with your first share."
- Lifetime total stays in Profile ("312 videos · since 2025").

**Platform planets grow with videos shared in that year** (`MilestoneService`, counted per platform per calendar year):
| Videos in the year | Rhythm | Diameter | Detail |
|---|---|---|---|
| 1 | first post | **14 pt (minimum)** | sphere |
| 12 | 1 a month | 24 pt | sphere |
| 52 | 1 a week | 30 pt | brighter glow |
| 156 | 3 a week | 35 pt | + thin ring |
| 365+ | every day | **38 pt (maximum) = the core sphere** | ring + small moon; stops growing |
- **Formula:** `d = 14 + 24 × ln(min(n, 365)) / ln(365)` pt, rounded. Logarithmic: early videos show progress fast; a daily poster reaches the max at the end of the year. A planet never gets bigger than the core.
- Label "TIKTOK · 12" sits 6 pt beyond the planet (beyond the ring when there is one) and moves outward as it grows.
- Growth animates with a 0.6 s spring (`cubic-bezier(.3,1.4,.5,1)`) the next time 9.2 opens after a share. Crossing 52 / 156 / 365 adds the detail with a soft flash and `.soft` haptic, and shows on 8.3 (Milestone).
- VoiceOver: "TikTok, 12 videos in 2026".

**Taps on 9.2**
| Element | Action |
|---|---|
| Planet | popover: "{Platform}", "{n} VIDEOS IN {year}", "{k} more to unlock {next detail}" (live year only), **See in Takes ›** → 6.2 filtered to that platform, stage SHARED, that year |
| Video dot | opens that take (6.3) |
| Theme row (legend) | 6.2 filtered to that theme, that year |
| Your {year} in review | the year story (below) |
| Share my {year} universe | share sheet (below) |


**Under the milestone card (9.2):**
- **Your {year} in review**: glass row, 56 pt high, corner radius 20 (Liquid Glass recipe). On the left, a 32×44 mini story card (night, 5 progress ticks, the year's count, "VIDEOS"); then the title and a mono line ("PREVIEW · READY DEC 1" / "5 MOMENTS · READY TO SHARE"); on the right a glass "▶ Play" chip. Tapping anywhere opens the story.
- **Share my {year} universe**: yellow capsule, 50 pt, 12 pt below the row. Shine sweep (the same `.shine` gradient as the onboarding Get started button) every 4.8 s: hold 0–58 %, sweep 58–78 % (`cubic-bezier(.4,0,.2,1)`), with the glow breathing from 22 % to 42 % yellow at 70 %. Reduce Motion / Low Power: no sweep, static glow at 22 %.


**Empty and partial states (9.2)** — same sky in every state; one yellow action.
| State | Year selector | Universe | Milestone card | Review row | Yellow button |
|---|---|---|---|---|---|
| **New account** (0 shares ever) | hidden; label "NO VIDEOS SHARED YET" | core only, orbits at 55 %, no dots, no planets, no legend; caption "Your universe starts with your first share." | "FIRST STAR · 0 / 1" · "Share your first video" · "It lights the first star of your universe" · bar 0 % | "Your year in review" · "3 VIDEOS TO UNLOCK", mini card shows 0, row at 62 % opacity, no ▶ Play; tap → toast "Share 3 videos to unlock it" | "Record your first video" → Record (Start recording) |
| **New year** (Jan 1 → first share; past years exist) | current year first (2027 · 2026 · 2025), previous year now SEALED | core only + last year's universe as the faint ghost; caption "Your 2027 universe starts with your first share." | "FIRST STAR OF 2027 · 0 / 1" · "Share your first video" · "It starts this year's universe" | shows **last year**: "Your 2026 in review" · "5 MOMENTS · READY TO SHARE"; tap switches the view to 2026 and opens the story | "Share my 2026 universe" (switches to 2026, opens the sheet) |
| **Live year, 1–2 videos** | normal | dots + planets for those videos | normal next milestone | "{3 − n} MORE TO UNLOCK" (story needs ≥ 3 videos in the year); locked look as above | "Share my {year} universe" |
| **Platform with 0 videos in the year** | — | its planet and label are not drawn | — | — | — |
| **Story slides with no data** | — | — | — | best month / streak / theme slides are skipped when they have no data; the story always has ≥ 2 slides | — |
- Profile (9.1) universe card: "NO VIDEOS YET" for a new account; in a new year it shows the live year's count (0) and "2026 · 23 videos" under it.
- The prototype shows these from the side panel: **APP DATA › New year** and **New account**.

**Share sheet** (`.sheet`, medium detent, close = `Button(role: .close)`): 9:16 preview card (the universe of that year, "MY {year} UNIVERSE", count + main platform + top theme, @handle, "MADE IN CUE STUDIO"); segmented **Image | 6 s video** (video = the universe forming star by star, 6 s, 1080×1920); toggles **Show numbers**, **Show @handle**; buttons **Save to Photos** (glass) and **Share…** (yellow, opens the system share sheet). Rendered on device (`ImageRenderer` / AVAssetWriter).

**Year in review** (full-screen story, 5 slides, 3.2 s each, progress bars on top, tap right = next, left = back, close xmark): 1 total videos · 2 main planet · 3 best month (12-bar chart, best in yellow) · 4 longest streak (weeks with ≥1 video) · 5 strongest theme → **Share my {year}** opens the share sheet. Available from Dec 1 for the live year (before that: "Ready December 1 · tap for a preview"); always for sealed years. Reduce Motion: bars fill instantly, no auto-advance.

**Data:** each share is stored with date, platform and theme (`ShareRecord`, new). Existing exported takes are migrated using their export date and the script's platform/theme, so past years are filled from day one.


### 9.1 · Profile (native List)
Built as `NavigationStack` + `List` with `.listStyle(.insetGrouped)` and `.scrollContentBackground(.hidden)` over the sky. Large title "Profile" (`.navigationBarTitleDisplayMode(.large)`) that collapses to the inline title when scrolled; toolbar trailing **Edit** (system glass button) → edit name, @handle, photo (sheet).
| Section (system header, uppercase footnote) | Rows (52 pt, system separators, chevron = `NavigationLink`) | Footer |
|---|---|---|
| — | **Identity**: 60 pt avatar, name (Title 3 semibold), "@mayacooks · Lifestyle creator". Tap = Edit. **Long press = `.contextMenu`** with preview: Copy @handle · Share profile link (`ShareLink`) · Edit profile | — |
| Your universe | Mini core (30 pt, orbit 7 s, static with Reduce Motion) · "Your universe" · "2026 · 3 topics" · trailing "23 videos" → 9.2 | "{n} more videos to your next milestone." |
| My Cue Voice | **Keeps its v28 card** (violet glow): meter "VOICE STRENGTH nn%" + level, summary sentence, "Next: {question}" → Answer, buttons Edit voice · ✦ Preview | — |
| Plan | **Keeps its v28 card**: "Free plan · 4 OF 5 EXPORTS LEFT · Try Pro ›" → 11.4 | — |
- Leading icons: 30 pt rounded squares (8 pt radius), Settings style. AI rows use the violet tint.
- **Profile empty states:** New account → universe row "0 videos" · "Starts with your first share", footer "Share a video to light your first star.", plan "5 OF 5 EXPORTS LEFT". New year → "0 videos" · "2027 · last year 23 videos", footer "Your 2027 universe starts with your first share."
- No custom cards on this screen; the grouped list background is the system material at 62 % over the sky.


### Cascade · v30 (Profile + yearly universe)
- **9.1 → Edit Profile** (identity row tap, toolbar Edit, context menu Edit profile): `.sheet` (large detent) with `NavigationStack`; toolbar **Cancel** (leading) and **Done** (trailing, disabled while invalid); photo (96 pt, "Edit Photo" → PhotosPicker); `Form` rows **Name** (1–40), **Username** "@" + 2–24 of a–z 0–9 . _ (typing is lowercased, spaces removed; footer error "Use 2–24 letters, numbers, . or _"), **Creator type** (picker, the 6 roles). Footer "Shown on the universe cards you share." Done → toast "Profile updated".
- **9.2 → 6.2:** "See in Takes ›" on a planet opens Takes with that platform selected and a yellow mono chip "{YEAR} · SHARED ✕" first in the filter row; only that platform's videos show; ✕ clears.
- **8.2 Send-off:** "A new star in your 2026 universe · TikTok 13" (taps → 9.2).
- **8.3 Milestone:** counts are per year: "MILESTONE · 25 VIDEOS IN 2026", "25 videos in 2026 · Deep Space icon unlocked".
- **1.7 First star:** "Saved in Takes. Share it to light your 2026 universe." (the star lights on share, as in 9.2).
- **9.3 My Cue Voice:** same grouped-list look as 9.1 (system material card, uppercase footnote section headers, 52 pt rows).
- **11.4 Pro:** use `SubscriptionStoreView` with `.storeButton(.visible, for: .restorePurchases)` — the native "Restore Purchases" text button; nothing custom.


### 11.4 · Pro paywall — opening moment ("wow")
Plays once each time 11.4 is presented (from 9.1 Plan card, 6.3 exports, 8.1 out of exports, Settings). Total 2.4 s, the screen is tappable from 1.4 s.
| t (s) | What happens | Curve | Haptic |
|---|---|---|---|
| 0–1.1 | **Warp:** 42 star streaks rush from the edges into the centre (44 % height), each 60–200 pt long, staggered 0–0.24 s | `cubic-bezier(.5,0,.8,.4)` 0.9 s | — |
| 0.7–1.4 | **Ignition:** a golden core grows from 20 % to 160 % | `cubic-bezier(.2,.9,.25,1)` | `.soft` at 1.25 s |
| 1.25–2.35 | **Shockwave:** a thin gold ring expands ×14 and fades; warm flash 0.9 s | `cubic-bezier(.2,.8,.2,1)` | — |
| 1.5–2.3 | The core rises into the centre of the **you planet** and the art ignites (scale .6 → 1.04 → 1, 0.7 s) | `cubic-bezier(.5,0,.3,1)` | — |
| 1.35–2.3 | **Reveal:** title, benefits, plans, CTA and footer fade up 18 pt and un-blur, 70 ms apart (top to bottom) | `cubic-bezier(.2,.9,.25,1)` 0.7 s | `.success` (light) when the CTA lands |
| from 2.4, every 3.6 s | The **Start 7-day free trial** button gets the yellow-button shine sweep | `cubic-bezier(.4,0,.2,1)` | — |
- **Reduce Motion / Low Power:** no warp, core, ring or flash; the content fades in over 0.3 s; no shine.
- SwiftUI: `PhaseAnimator` / `KeyframeAnimator` for the core and ring; the streaks as a `Canvas` with `TimelineView(.animation)`; reveal with staggered `.transition(.opacity.combined(with: .offset(y: 18)))` + `.blur`.
- **9.1 Plan card** keeps its v28 look (card "Free plan · 4 OF 5 EXPORTS LEFT · Try Pro ›"); tapping it opens 11.4 with this moment.

- **Pro art · you are the main planet** (top of 11.4, behind nothing, 390×170 at y 18): a 60 pt golden planet (`#FFF6DC → #FFD98A → #E39A3E → #3A1E10`, light from top-left, thin warm rim) inside a soft gold atmosphere (r 96, 34 % → 0); two tilted (−7°) orbits drawn in two halves so they pass behind and in front of the planet (inner 96×17 warm, outer 150×24 lavender; planet centre at y 100 of the screen, every orbit + planet stays above y 140 so nothing crosses the "CUE PRO" label); three small platform planets travel the orbits (TikTok blue 11 pt and Reels violet 8 pt on the outer, 26 s; Shorts coral 7 pt on the inner, 17 s); a faint light band drifts across the planet (9 s). No photo, no face. Reduce Motion: everything static.


### Free exports running out (rules unchanged: 5 free exports in the Keychain, then Pro; everything else stays free)
| Exports left | 6.3 Take (under Share) | 8.1 Share (meter label) | 9.1 Plan card |
|---|---|---|---|
| 5–2 | "{n} OF 5 FREE EXPORTS LEFT · GO PRO" | "{n} OF 5 LEFT" | "{n} OF 5 EXPORTS LEFT" |
| 1 | "LAST FREE EXPORT · GO PRO" (yellow) | "LAST FREE EXPORT" (yellow) | "LAST FREE EXPORT" |
| 0 | "0 OF 5 FREE EXPORTS LEFT · GO PRO"; after Not now: "READY · EXPORT WITH PRO · GO PRO" | "0 OF 5 LEFT · EXPORT WITH PRO" (orange) | "0 OF 5 EXPORTS LEFT" |
| Pro / trial | "PRO · UNLIMITED EXPORTS" (Go Pro hidden) | "PRO · UNLIMITED EXPORTS" | "PRO · UNLIMITED" |

**At 0, tapping Share to {platform} / Save to Photos / Other apps** opens the sheet **"Your video is ready"** (`.sheet`, medium, close = `Button(role: .close)`): video thumbnail with "✓ READY", "Saved in Takes · nothing is lost. You've used your 5 free exports.", **Start free trial · export now** (yellow, shine), **See what's in Pro** (glass), **Not now** (text) + "7 days free, then $39.99/year. Cancel anytime."
- *Not now* / close / swipe down → back to the take (6.3), toast "Saved in Takes · export with Pro anytime". The take stays READY with "EXPORT WITH PRO". **No other reminder** in the app until the next export attempt (at most one gentle reminder a week, on Takes).
- *Start free trial* / *See what's in Pro* → **calm Pro (11.4)**: no warp/wow (the video is the focus), eyebrow "YOUR VIDEO IS READY", title "Keep sharing your universe.", sub "Start the trial and export it now.", CTA "Start free trial · export now". Success → the export runs at once → 8.2 Send-off, toast "Trial started · video exported". Cancel → back to the sheet's origin with no message.
- The regular Pro (from Profile, Settings) keeps the opening wow.


### Share to universe (6.3 · 8.1 · 7.6) and the send-off (8.2)
- Every share button reads **Share to universe** (7.6 option: "Yes — share to my universe"). Tap on 8.1 → the **system share sheet** (`ShareLink` / `UIActivityViewController` with the exported file): header with the video thumbnail, title and "Video · 0:52 · 1080 × 1920"; app row (TikTok, Instagram/Reels, YouTube/Shorts, LinkedIn, Messages, More); actions Save Video, Save to Files. Picking a network app counts the export, opens that app and plays 8.2 for that network.
- **8.2 send-off** (≈ 2.6 s, once): the user's universe — gold "YOU" planet in the centre, two tilted orbits, **all their networks as planets** on the outer orbit (TikTok, Reels, Shorts, YouTube, LinkedIn, Stories; size = videos that year, same scale as 9.2), the chosen one bright, the others at 38 % opacity with labels "TIKTOK · 12".
  | t (s) | What happens | Curve | Haptic |
  |---|---|---|---|
  | 0–0.65 | The video card lifts 16 pt and shrinks into a star | `cubic-bezier(.5,0,.4,1)` | — |
  | 0.52–1.57 | The star arcs to the chosen planet with a 9-dot fading trail | `cubic-bezier(.45,.05,.35,1)` | — |
  | 1.57–2.17 | Planet pulse ×1.35 → ×1.12 (it grew), white ring ×5 fades, count +1, "+1 · REELS" rises in yellow mono | `cubic-bezier(.3,1.4,.5,1)` | `.success` |
  | 1.87–2.57 | A new tiny gold star appears near YOU (this video's star) | `cubic-bezier(.2,.9,.25,1)` | — |
  Text below: "SHARED TO {NETWORK}" · "On its way." Reduce Motion: final state, no flight.


> **Share to universe (multi-network posting): see `10-Share-to-universe.md`** — pick networks, one clean export, guided queue with checklist and "Posted?", multi-star send-off. [NEGÓCIO] 1 free export per video.
