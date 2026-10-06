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

## 10 · Studio is a teleprompter only (supersedes v29 "Studio records with the rear camera")
- **Purpose:** rehearse; calibrate where the text sits relative to the eyes, the size and the speed; be the prompter while **another camera** records (tripod, rig, beam-splitter glass).
- **Removed from Studio:** recording, takes, the camera thumbnail, camera settings, flip, the recording setup and countdown menu, the mic/setup HUD line, the compact recording bar. **Recording happens only in Selfie (5.2).** Recording from Studio is removed for good: no separate mode.
- **Permissions:** Studio never starts a capture session and never asks for the camera. It asks for the mic (and speech) only when Voice Following is used, at that moment. It uses less battery and runs cooler.
- **Bar** (night glass, bottom 24 pt, radius 32):
  1. **Progress:** mono, "{m:ss} LEFT" (yellow #FFE680) on the left, "IDEAL {range} · {PLATFORM}" on the right (platform preset), and a 3 pt bar below. In Steady, LEFT = total time at the current wpm × (1 − scroll progress). In Voice, it uses the spoken word index.
  2. **Transport:** Voice | Steady (segment 136 pt) · ⤒ back to the top · ‹‹ previous sentence · **▶ play/pause** (48 pt, solid yellow, the screen's single primary) · ›› next sentence. Targets are 44 pt.
  3. **Chips:** Speed · Size · Line · Width · Mirror (equal width; selected = white/black per Cue Controls). Tapping Speed, Size, Line or Width opens **only that slider**, inside the bar; tapping it again closes it. Mirror is a toggle chip (horizontal mirror).
- **Slider ranges:** Speed 80–220 wpm, step 5 (default 150); Size 20–44 pt, step 1 (default 28); Line 10–50% of the box height, step 1% (default 36%); Width 64–96% of the screen, step 1% (default 92%). The ⌟ handle and the reading-line pinch keep working and update the same values.
- **Tap the screen:** hides the bar and the handles, leaving only the text, with "TAP FOR CONTROLS" (mono, white 35%) at the bottom for orientation. Tap again to show it. A drag on the text doesn't toggle it.
- **Countdown before play:** in the Prompter sheet (Off · 3 · 5 · 10 s; default 3). Play runs the same ring-of-stars count, then scrolls.
- **Top bar:** ✕ close · Selfie | Studio · ⚙ **Prompter sheet** (mono "PROMPTER ONLY · SCREEN STAYS ON"):
  - Countdown before play;
  - **Flip vertically** (for rigs that reflect from below);
  - **Remote control** (same service as Settings › Remote).
- **Screen stays on** while Studio is open (`isIdleTimerDisabled = true`; restored when leaving).
- **Orientation:** portrait only for now; landscape prompter is out of scope.
- **Code:** Studio uses `PrompterView` without `CaptureSession`. Remove the rear-camera capture path from Studio and its tests. Settings › Prompter values are shared with Studio.

## 11 · Settings: native grouped list (replaces the 11.1–11.3 boards)
Build it with `List` + `.listStyle(.insetGrouped)` inside a `NavigationStack`, with `.searchable` on the root. Pages are pushed with `NavigationLink`. The prototype `CueSettings30.dc.html` is the reference for every row, value, range and footer.
- **Root:** large title "Settings" · search · "Your setup" card (phone with the format + Camera / Quality / Mic / Text; each value pushes its page) · sections:
  - **Create:** Recording, Prompter, Remote;
  - **Your Cue:** My Cue Voice → 9.3, Personalize (NEW);
  - **General:** Language & Region, Privacy & AI data;
  - **Pro:** Cue Pro → 11.4, Restore purchases (tinted row);
  - **About:** Privacy policy, Terms of use, Acknowledgements, Version.
  Row icons sit in 30 pt squares with radius 8: Recording #FF453A · Prompter #FFD60A (black glyph) · Remote #0A84FF · My Cue Voice #5E4EE0 · Personalize #BF5AF2 · Language #30B0C7 · Privacy #34C759 · Pro #3A2E00 (yellow glyph) · others #6E7496 at 35%.
- **Recording:** Camera "Starts with" Front | Back (`.segmented`) · Resolution 720p/1080p/4K and Frame rate 24/30/60 (`Picker .menu`) · Default format tiles 9:16, 4:5, 1:1, 16:9 · Microphone › (Automatic, iPhone, AirPods Pro, DJI Mic 2) · While recording: Countdown (Off, 3, 5, 10 s), Grid.
- **Prompter** (also opened by **Aa** in the recorder as a `.sheet` with `.medium` / `.large` detents and `.presentationBackgroundInteraction(.enabled)`; this replaces the Display sheet and its "Advanced" expander). A sticky preview at the top shows size, font, spacing, alignment, colour, line, margins, mirror, flip and AI Coach live. Sections:
  - **Reading:** Follow my voice · Speed 80–220 wpm (step 5) · Countdown before play · AI Coach;
  - **Text:** Text size Small/Medium/Large/XL · Font › (SF Pro, New York, SF Rounded, Lexend, Atkinson Hyperlegible; `PrompterFont` cases) · Line spacing 1.00–1.80 (0.05) · Alignment Left | Center · Text color (White, Warm white, Yellow, Mint; `PrompterTextColor` cases);
  - **Reading line:** Show reading line · Position 10–50% (1) · Reset to recommended;
  - **Text window · Selfie:** Height 150–470 pt (10) · Width 64–96% (1) · Side margins 0–48 pt (2);
  - **Over the camera · Selfie:** Background opacity 0–100% (5) · Camera blur Off–100% (5) · Social safe zone › (Show safe zone; TikTok / Reels / Shorts / Custom; Custom = Top/Bottom/Left/Right risk 0–40%; footer "A guide, not a guarantee · Never recorded");
  - **Studio:** Background color (Night, Black, Dark gray; `StudioBackground` cases);
  - **Rigs:** Mirror text · Flip vertically.
  Footer: "Studio uses these too. The screen stays on while the prompter is open."
  The "· Selfie" sections show when Selfie is the active mode, and "Studio" when Studio is. Existing model ranges (`PrompterSettings.*Range`) win if they differ.
- **Remote:** status card (grey / yellow waiting / green connected) · Connect a device (tinted row) → Waiting → Connected → Disconnect (destructive) · Use this iPhone as a remote: Enter a code, Scan the code · Coming next.
- **Personalize:** App icon › (Default; Deep Space at 25 videos; First Light at 50 videos · Pro) · Your topics → 2.2 · Tag new scripts automatically · Starry sky Off/Calm/Lively (menu) · Celebrations · Haptics.
- **Language & Region:** App language → iPhone Settings › Cue (`openSettingsURLString`) · Voice following (menu) · Script language (menu).
- **Privacy & AI data:** On-device AI · Help improve Cue · Privacy policy · Permissions › (status of each, plus Open iPhone Settings) · **Delete my Cue data** (destructive, then a `confirmationDialog`).
- **Search:** results are the live rows themselves, grouped by path (e.g. "Prompter › Rigs"). Every row has localized keywords.
- **Rules:** no solid yellow button anywhere in Settings (actions are tinted rows); every row is at least 44 pt; one short footer (≤ 60 characters) per section.

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

- **[NEGÓCIO] Confirmed by the owner:** free exports are counted **per export, never per network**. One Share to universe to any number of networks = 1 export. Save video and the system share icon are separate exports (1 each). The count only moves after a successful export.

- **When an export is counted:** the moment the file is delivered for the first time — saved to Photos, or loaded into a network app (TikTok editor, Instagram, YouTube, LinkedIn, the system share sheet) — **even if the creator never publishes it**. Once per export: the next networks in the same queue don't count again. A failed render or a cancel **before** delivery doesn't count.

## 12 · 1.1 Welcome: star opening (final state)
Loop of 14 s in the prototype; in the app it plays once (about 8.5 s to the buttons) and then holds. Reduce Motion / Low Power: final state only (C lit, three words readable, wordmark, title, buttons), no flight.
| t (s) | What happens | Curve | Haptic |
|---|---|---|---|
| 0.55–1.1 | A star with a short trail enters from the top right and reaches the 1st dot of the C | `cubic-bezier(.2,.7,.3,1)` | — |
| 1.1–1.9 | It hits dots 1–5 every 0.2 s (hold 0.03 s). Each dot pops ×2.0 → ×2.6 then settles ×1 with a spring; cross flare, white ring ×3–5, 9 sparks, star dust on the line between dots; the C line draws with the star | dots `cubic-bezier(.3,1.4,.5,1)` | `.soft` on each dot |
| 1.9–2.25 | It draws the "leg" (dot 5 → position of dot 6) without lighting it; dot 6 stays dim (40 %) | linear | — |
| 2.95 / 3.55 / 4.15 | Arcs down to TELEPROMPTER, AUTO CAPTIONS, ✦ AI SCRIPTS (dim 35 % until then). On impact the word jumps 12 pt, scales ×1.1, glows yellow, a soft oval yellow light crosses it left to right (0.45 s, clipped by the pill radius), thin ring and 7 sparks; it settles back to its normal colours | hop `cubic-bezier(.5,0,.8,.6)` then ease-out | `.light` on each word |
| 5.05 | The star returns by the right, stops on dot 6 and explodes in yellow (core ×2.2 → ×1, two rings, cross flare, 12 sparks); it becomes dot 6 of the C | `cubic-bezier(.3,1.3,.5,1)` | `.success` |
| 5.2–6.4 | Wordmark "CUE STUDIO" under the C (SF Mono 13 pt, 600, lavender #E4DEFF): letters leave from the centre outward (S/T first, C/O last), each stretched ×3.4 horizontally and blurred, settling in 0.55 s; tracking closes from 1 em to 0.34 em; a yellow glint runs over the letters once (0.12 s each, 0.05 s apart) | `cubic-bezier(.12,.8,.2,1)` / `.16,1,.3,1` | — |
| 5.5–7 | Title "Every creator has a universe to share." (word by word, 85 ms apart), sub, **Get started**, *I already use Cue* | `cubic-bezier(.16,1,.3,1)` | — |
The yellow eyebrow "CUE STUDIO" above the title was removed (the wordmark replaces it). Build with `Canvas` + `TimelineView` or `KeyframeAnimator`; the star is one moving point with 3 trail copies delayed 0.06 s.

## 13 · Answers to open points of the first hand-off (2026-10-05)
- **Root icons:** colours are in §11 (30 pt, radius 8). Glyphs: Recording = record dot, Prompter = text lines, Remote = antenna, My Cue Voice = waveform, Personalize = sparkles, Language & Region = globe, Privacy & AI data = hand/shield, Cue Pro = star, Restore = circular arrow, doc rows = document, Acknowledgements/Version = info. Use SF Symbols with the closest names. "09 §11" is this file's §11.
- **App icons:** the prototype shows 3 rows: Default, **Deep Space (25 videos)**, **First Light (50 videos · Pro)**. "Aurora" was a leftover name and is now **Deep Space** everywhere (Settings, 8.3, 9.2). The app already has more icons than 3: keep every existing icon selectable; only these two unlock by milestone; any other existing icon keeps the rule the app has today.
- **Phase A, Instagram/TikTok:** nothing beyond the iOS share sheet (system UI). Cue's screens before it: the queue step with "In the share sheet, tap {app}" and **Send to {app}**. After it: "Posted on {app}?". No custom share UI.
- **Reset Creator Setup:** v30 does not design this row and the prototype has only **Delete my Cue data**. Not a decision to remove it: keep the app's existing row untouched until the owner decides.

## 14 · 1.2 Topics: how many, and what the counter says
- **Pick 1 to 3.** Nothing is pre-marked: Cue doesn't know the creator yet. **Continue** is disabled at 0 (label "Pick a topic", grey) and enabled from 1. **Skip** (top right) leaves the step empty; My Cue Voice asks again later.
- **Maximum 3.** At 3, the other chips drop to 40% and a tap on an unmarked chip does nothing but a `.light` haptic; tapping a marked chip unmarks it so another can take its place.
- **+ Your own** counts as one of the 3: a text field, 2–24 characters, any text; it gets the next free theme colour.
- **Counter (always visible):** three 3×16 pt vertical bars (theme rule, no dots): empty = 1 pt outline at 40%, filled = the topic's colour; beside them, SF Mono 12 pt, 82% white, 0.1 em tracking. Texts: 0 "PICK 1 TO 3 TOPICS" · 1 "1 OF 3 · ADD MORE OR CONTINUE" · 2 "2 OF 3 · ADD ONE MORE OR CONTINUE" · 3 "3 OF 3 · TAP ONE TO SWAP" (yellow #FFE680). The new bar pops (scaleY 0 → 1.25 → 1, 0.45 s, `cubic-bezier(.3,1.5,.5,1)`) on the tap. Reduce Motion: no pop.

### 14b · 1.2 chapter opening and the 10 topics
- **Opening (chapter pattern):** the star from the previous chapter arrives with the text. Loop of 10.6 s in the prototype; in the app it plays once and holds. 0.12–1.25 s the star (4 layers, same trail as 1.1) flies from the top right through the title and lands on the centre (195, 366) with a yellow ring (×0.3 → ×5, 0.9 s, `cubic-bezier(.1,.7,.3,1)`); eyebrow, title and subtitle rise 16 pt and un-blur 0.75 s each, 0.45 / 0.58 / 0.72 s, `cubic-bezier(.16,1,.3,1)`; the universe (core "YOU", orbits) fades in 1.15–1.8 s; counter and topic chips rise 14 pt at 1.55–2.2 s; Continue at 1.9–2.5 s. The core then breathes (3 s, ease-in-out) while it waits. The first tap in the board is at 2.6 s. Tapping anywhere during the opening jumps to the final state. Reduce Motion / Low Power: final state, no flight. Haptic: `.soft` when the star lands.
- **Chapter rule (all of 1.2–1.7):** same star, new job per chapter; opening 0.8–1.2 s, long version only the first time. 1.3 travels to the platform icon, 1.4 lands as the script caret, 1.5 pulses while permissions are asked, 1.6 becomes the prompter dot, 1.7 lights as the first star. (Only 1.2 is built.)
- **10 topics offered (order = most common first; the ranking is the designer's estimate, to be replaced by real usage data):** 1 Fitness & wellness · 2 Food & cooking · 3 Beauty & skincare · 4 Fashion & style · 5 Personal finance · 6 Tech & AI · 7 Budget travel (Travel) · 8 Productivity & career · 9 Parenting & family · 10 Morning routines (Lifestyle) · then "+ Your own". The prototype shows the three of the demo first (Morning routines, Personal finance, Budget travel); in the app, show the 10 in the order above. Chip: 32 pt tall, 12.5 pt SF Pro semibold, 5–6 pt gaps; fits in 5 rows above Continue on a 390 × 844 screen. If more are needed later, scroll the chips area; never shrink below 12 pt.
- **Chip tap → planet (1.2):** the planet is born on the **right** side of the orbit (more room): landing at about (325, 317). The route leaves the top of the tapped chip, passes **under the universe** and rises up the right side (1.6 s, 2.75–4.35 s, `cubic-bezier(.5,0,.3,1)`); it never crosses the core. In the app the chip can be in any column: draw the arc around the core, never through it, and put the planet on the free side of its orbit. Route = 1.4 pt gradient line (pink → white) that draws with the head and dissolves 0.9 s after landing; comet head with 8 trailing dots; 5 glints on the route; 8 sparks leave the chip at the tap (2.6 s). Landing (4.35 s): planet spring ×2.4 → ×0.82 → ×1.1 → ×1 over 0.76 s, 3 rings, 10 pink streaks, 9 sparks; the orbit draws in 1.3 s with a white comet running on its stroke. Haptic `.soft` on the tap, `.success` on landing. Reduce Motion: planet and orbit in place, no route.

## 15 · 1.3 Voyage: where is it headed
- **Opening (zoom out from the creator's galaxy):** loop 10.4 s in the prototype, once in the app. The scene starts on **the creator's own galaxy** (gold spiral with the "YOU" core and the 3 topic planets from 1.2) at ×3.8, centred on the screen, taking most of it. After a 0.35 s hold the camera pulls back to ×1 (0.35–2.7 s, `cubic-bezier(.45,0,.2,1)`) while the galaxy glides to its final place at the bottom left (78, 477); the starry sky zooms less (×1.5 → ×1) for depth. **The social galaxies are born during the pull-back**, 0.3 s apart: Reels 1.1 s, YouTube 1.4 s, TikTok 1.7 s, Shorts 2.0 s, LinkedIn 2.3 s. Each is born from a point (scale 0 → 1.35 → 0.94 → 1 over 0.66 s, `cubic-bezier(.2,.9,.3,1)`) with a thin white ring (×0.3 → ×3.2, 0.9 s) and its label fades in 0.25 s later; the dotted route to TikTok appears at 2.3–3.0 s. Title rises and un-blurs at 2.0 / 2.13 / 2.27 s over the galaxies; chips 2.4–3.05 s; CTA 2.7–3.3 s. Then the universe waits, galaxies breathing. Progress bar and Skip stay above the zoom. Tap anywhere = final state. Reduce Motion / Low Power: final state, no zoom. Haptics: `.soft` for each birth (the last one `.light`). SwiftUI: `scaleEffect(anchor:)` + `offset` in a `KeyframeAnimator`; each galaxy `.scaleEffect` with `.spring(response: .5, dampingFraction: .55)` from 0.
- **The creator's galaxy ("YOU") is one hero asset, drawn at full size.** It is drawn natively at 360 pt (3.8× its final size) and **shrinks** to its place (78, 477) at ×0.263, so it is always sharp (a small asset scaled up looks soft). Contents: soft gold/lavender glow; two logarithmic spiral arms (≈1,000 stars of 0.4–2 pt in white, gold and lavender, brighter near the core) over two blurred gas arms (gold and violet) and a thin highlight; a bulge of 260 stars; a faint halo of distant stars; tilt −18° with a 0.52 ellipse; the arms rotate once in 140 s. The "YOU" core is a lit sphere (`#FFF → #F4F0FF → #D2C8FF → #9D8CFF → #6E5BE6`, rim light, specular), with a lavender halo and a slow 4-point flare (40 s). Three orbits (52×27, 92×48, 132×69 pt) carry the 3 topic planets as shaded spheres: pink 10 pt (9 s), mint 12 pt (16 s), orange 15 pt (24 s); they move along the ellipses without being squashed. In the app: `Canvas` / `TimelineView` (vector, never an image), rendered at the large size and scaled down with `scaleEffect`. The topic planets must show the creator's real topics and colours from 1.2.
- **"YOU" label:** 38 pt SF Mono bold at the start (10 pt final); letters arrive from the centre out (O first, then Y and U), each stretched ×3.2 and blurred, settling in 0.6 s (`cubic-bezier(.12,.8,.2,1)`) while the tracking closes from 0.95 em to 0.16 em (0.25–1.3 s, `cubic-bezier(.16,1,.3,1)`) with a lavender glow; a yellow glint runs over the letters (1.35 s, 0.12 s apart, 0.12 s each); it settles at 78% white at 2.9 s. The label travels and shrinks with the galaxy. Reduce Motion: galaxy and label already in their final place.
- **Demo timing (after the opening):** tap on TikTok at 3.4 s; route 3.8–5.8 s; landing 5.8 s.
- **5 galaxies:** TikTok (cyan, 298, 296), Reels (purple, 147, 257), YouTube (orange, 212, 330), Shorts (coral, 324, 418), **LinkedIn (blue #0A84FF, 64, 352, label at the left edge)**. The "(open point: draw a 5th galaxy)" note above is resolved; LinkedIn is selectable like the others.
- **Choice:** one platform, required, nothing pre-selected. The CTA reads "Choose a galaxy" (disabled, 55% yellow) until a chip or a galaxy is tapped; then "Head to {platform}". Tapping a galaxy or its chip selects both; tapping another switches (the first galaxy dims to 42%). LinkedIn has a chip but no galaxy yet: it lights a small blue star near YOU (open point: draw a 5th galaxy).
- **Prototype demo timing:** tap on TikTok at 2.6 s; the route leaves YOU at 3.0 s and reaches TikTok at 5.0 s (2.0 s, `cubic-bezier(.45,0,.25,1)`); yellow line draws with the head; comet head with 6 trailing dots; 4 glints on the route; landing at 5.0 s: cyan flash, 2 rings, 10 streaks and 9 sparks on the galaxy, the galaxy label turns bright cyan. Haptic `.soft` on the tap, `.success` on landing. Bug fixed: the arrival flash used to scale from the corner of the SVG and drifted right; it now scales from its own centre.
- **Hint line under the chips (typed in, mono 10 pt):** TikTok "9:16 · IDEAL 1:00–1:30 · SAFE ZONES ON". The other platforms' lines are the designer's estimates, to be confirmed against each platform's current limits: Reels "9:16 · IDEAL 0:30–1:30 · SAFE ZONES ON" · Shorts "9:16 · UP TO 3:00 · IDEAL 0:30–0:50 · SAFE ZONES ON" · YouTube "16:9 · IDEAL 8:00–12:00 · SAFE ZONES OFF" · LinkedIn "1:1 · IDEAL 0:30–1:30 · SAFE ZONES OFF". Selecting a platform also sets the default format in Settings › Recording (the creator can change it).
- **1.3 one-destination line (mono 12 pt, 82% white, above the chips):** before a choice "PICK ONE DESTINATION"; after, in yellow #FFE680, "{PLATFORM} · TAP ANOTHER TO SWITCH". Chips behave as a single choice (radio): tapping another replaces the first. A single destination per video here; posting to several networks happens later, in Share to universe (10-Share-to-universe.md).

## 16 · 1.4 First message: the transmission console
- **Copy:** eyebrow "CHAPTER 3 · YOUR FIRST MESSAGE" · title "Your first message to new worlds." · sub "You will read it on the teleprompter." · chip "✦ WRITING YOUR MESSAGE" → "✦ READY FOR {PLATFORM} · 15S".
- **One action:** **Load in teleprompter** (full width, bottom 34 pt, yellow, shine). *Another* and *I'll write my own* are removed (the message is not editable here; writing your own lives in Scripts).
- **Cockpit / console (loop 11 s):**
  - **HUD brackets:** four 14 pt corner brackets (1.5 pt, #FFE680 at 85%) close in on the card from ×1.5 to ×1 (0.8–1.4 s, `cubic-bezier(.16,1,.3,1)`).
  - **Destination line** under the header (0.6 s rise at 1.2 s): platform dot (6–7 pt, the galaxy's colour: TikTok #64D2FF) + mono 10 pt "DESTINATION · {PLATFORM}" from 1.3; on the right a **16 pt progress ring** (2 pt, track 22% white, yellow arc with glow) that fills as the message is written (1.9–5.5 s) and ends in a check (5.5–5.8 s), then "15 S" (length of the message). The old 5-bar "signal" meter was removed: it looked like phone coverage.
  - **Capsule ready:** when writing ends the pill rises under the card (6.2–6.9 s, 40 pt, yellow 10% with a 1 pt yellow ring) with the glowing star-capsule (pulse ring every 2 s). Then a **bright dot with a 46 pt tail runs along the pill** (7.0–8.2 s, linear, 296 pt) **revealing "MESSAGE READY FOR LAUNCH"** as it passes (mono 11.5 pt; the text is fully shown when the dot is at 64% of the run); a thin yellow progress line grows under it with the dot and fades at 8.7 s; at the end the dot bursts in a ring (×0.4 → ×2.4, 0.7 s, `cubic-bezier(.1,.7,.3,1)`). Haptic `.success` when the dot reaches the end. Reduce Motion: the text and pill already shown, no run, no pulse.
  - Reduce Motion: brackets, destination line, full meter and the pill shown, no pulse or movement.
- **Theme marker:** the topic chip in the card header uses the 3 × 14 pt bar.
- **Native:** the pill is a `Label` in a capsule `.glassEffect(.regular.tint(.cueYellow.opacity(0.1)))`; the meter a `Canvas`/`HStack` of capsules; button `.buttonStyle(.glassProminent).tint(.cueYellow)`.
- **Slow loading (AI takes long)** · file `1.4_Your-first-script-slow-loading.html`. Thresholds from the tap on 1.3 (the 3.0 s minimum of 09 §8 still applies):
  | Time | What the creator sees |
  |---|---|
  | 0–6 s | Normal writing (above). |
  | > 6 s | The words stop; the card shows **skeleton lines** for HOOK / BODY / CTA (rounded 16 pt bars, 8% white with a light sweep, **1.4 s linear loop** = the app's skeleton shine); the ring becomes an **indeterminate spinner** (16 pt, 14% arc rotating 0.9 s linear, like the system `ProgressView`); length shows "-- S"; chip stays "✦ WRITING YOUR MESSAGE" with its 3 dots; the button is disabled (22% yellow); under the card: "Taking a little longer…" + "Your message is on its way." |
  | > 15 s | A text button appears (0.4 s rise): **Use a ready-made message** (yellow text, 40 pt). It loads the built-in message for the topic (03: "no AI: built-in script"), then the normal ready state. |
  | > 25 s | Cue loads the built-in message by itself; toast "Message ready" (no error tone). |
  | No network / AI error | Straight to the built-in message after 3 s, chip "✦ READY · BUILT-IN". |
  Native: `ProgressView()` circular for the spinner, `.redacted(reason: .placeholder)` + shimmer for the skeleton. Reduce Motion: skeleton without sweep, spinner replaced by a static "…" ring arc.

## 17 · 1.6 Practice: she starts it, Cue counts her in
- **Purpose:** her own text appears again in a prompter box like Studio (09 §10) and she tries the tool, with nothing recorded. Chip "✦ PRACTICE · NOT RECORDING" is the only status label.
- **One message card** (22 pt radius, glass, 96 pt tall, at 372 pt) that changes by phase. **Intro:** **"A quick test run."** (22 pt bold) + "Read your message out loud, like a real take." + "Cue counts you in. Nothing is recorded." It rises at 0.3–0.9 s and leaves when she starts reading. **Done:** **"Nice. That's your teleprompter."** + "Now do it for real, with your own text." (rises 0.5 s after the text ends). The old "Read it out loud" card, the waveform, the side scrub bar with its 3 dots and the sparks over the reading line were removed (redundant).
- **Nothing runs by itself.** Idle: the text sits behind a 70% dark layer with a 5 pt blur (it recedes); in the centre a 76 pt glass play button (yellow ▶, yellow 1.5 pt ring, soft glow) with the mono label "TAP TO START" (white 85%) under it.
- **Tap (`.medium`)** → the button squeezes (×0.9) and fades; **count-in** like the recorder 5.1: "GET READY" (mono, yellow), **3 · 2 · 1** 1 s each (92 pt weight 800; a track ring and a 1 s linear yellow sweep that appear and leave with each number; pop-in from ×1.5, 0.28 s, `cubic-bezier(.16,1,.3,1)`), haptic `.rigid` per number; **"READ!"** (0.6 s, `.success`); the dim and blur lift (0.4 s).
- **Reading (≈ 10 s in the prototype; in the app it follows her voice or the speed in Settings › Prompter):** words light as read, lines scroll under the reading line (the 2 pt yellow line stays).
- **Buttons:** **Record it for real** (yellow, static red dot; available from the start; it gets a soft glow when the practice ends) and "Not now — take me to my studio". **Record it for real** opens the real recorder (5.2) already set up with her text and Settings › Prompter values (`first = true` → 1.7). The studio link goes to 3.2.
- **Reduce Motion / Low Power:** final frame of each phase; count-in becomes a fade of the numbers; the practice still needs her tap.
- **Native:** play button `Button` with `.glassEffect(.regular.interactive())`; count-in as `PhaseAnimator`; text from the real `PrompterView`.
- **1.3 fix:** the line above the chips no longer contains the word "YOU" (it sat right under the galaxy's "YOU" label and read as one phrase). It reads "PICK ONE DESTINATION"; the line and the chips moved 10 pt down (line at 548, chips at 576) so the "YOU" label and the line are ≥ 22 pt apart.

## 18 · 2.2 My Cue Voice topics follow 1.2
- The 2.2 chips use the same 10 topics as 1.2 (09 §14b), with the 3 × 14 pt theme bar and the same compact size (32 pt tall, 12.5 pt); the "more specific" panel moved 16 pt down. `cue-voice-card.js` accepts the new names when saving.
- **Prototype note:** in 1.6 the play button is now tappable (the loop waits on the idle frame; a tap starts the count-in; after the run it goes back to idle).
- **Prototype note (board auto-layout):** the board's `relayout` pushed blocks down to avoid overlaps and moved the hero galaxy of 1.3 (and could move parts of 1.2, 1.4–1.6) by ~36 pt, so the "YOU" label landed on the "PICK ONE DESTINATION" line. Screens 1.2, 1.3, 1.4, 1.4b, 1.5 and 1.6 are pixel-placed and now skip it (`LAYSKIP`). The app has no such step: use the positions in the screen files.
