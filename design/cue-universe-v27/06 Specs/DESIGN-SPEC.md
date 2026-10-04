# Cue Studio v27 — Design spec ("Cue Universe")

**Scope:** visual system, components, motion, haptics and accessibility for the v27 restyle of Cue Studio (iOS 27, SwiftUI, iPhone 11 and later).
**Source of truth:** the HTML boards in `04 Screens — HTML source/` (they animate; open them in a browser) and the live canvas at https://claude.ai/artifact/Hp4M32mkCAz1nTkxPeLSRx.
**Logic and data:** keep the v26 behaviour unless a screen in `SCREENS.md` says otherwise.
**Why:** see `01 Direção de design — Cue Universe.md`.

---

## 1. Platform rules

- **Dark only.** Set `UIUserInterfaceStyle = Dark` in Info.plist and `.preferredColorScheme(.dark)` at the root. Remove the Appearance setting and the v26 light palette.
- **Fonts in the app:** SF Pro (Text/Display) and SF Mono via `.monospaced` design. Geist and Geist Mono are only used in the mock-ups. The PNG renders substitute Inter and DejaVu because web fonts could not be loaded while rendering.
- **20 languages:** en, es, pt-BR, fr, de, it, ja, ko, zh-Hans, zh-Hant, hi, id, ar, tr, th, vi, nl, sv, da, nb.
  - Every layout must survive +35% text length.
  - Every layout must support right-to-left (Arabic). Mirror the horizontal motion paths in RTL.
- **Dynamic Type** for all UI text, up to AX3 for body styles. Teleprompter text size is its own setting and does not follow Dynamic Type.

---

## 2. Color tokens

| Token | Value | Use |
| --- | --- | --- |
| `bg.night` | `#0A0B12` | App background |
| `bg.deep` | `#07080E` / `#06070D` | Onboarding and celebration backgrounds |
| `surface.card` | `#161826` + inner hairline `rgba(180,167,255,0.16)` | Cards, list groups |
| `surface.row` | `#1F2236` | Rows and tiles inside sheets |
| `surface.panel` | `#14151F` with violet top glow | Editor bottom panels |
| `surface.glass` | `rgba(12,13,22,0.55–0.72)` + blur 18 + hairline `rgba(255,255,255,0.14)` | Controls over camera or video |
| `line.hairline` | `rgba(80,86,120,0.5)` at 0.5 pt | Separators |
| `text.primary` | `#FFFFFF` | Titles, body |
| `text.secondary` | `rgba(225,228,245,0.65)` | Subtitles, descriptions |
| `text.tertiary` | `rgba(225,228,245,0.55)` **minimum** for small text | Mono labels, hints. Do not go below 0.55 for text under 17 pt; 0.55 is about 5:1 on `bg.night`. |
| `accent.yellow` | `#FFD60A` (light `#FFE680`, core `#FFF6C2`) | Primary action, signal, reading line, orbs, active tab |
| `accent.violet` | `#B4A7FF` (light `#E4DEFF`, deep `#5E4EE0`) | AI only |
| `state.record` | `#FF3B30` | Recording only |
| `state.ready` | `#34C759` | Ready, allowed, fits |
| `state.edit` | `#64D2FF` | In edit |
| Topic (world) colors | warm `#FFC46B`, mint `#7EE0B8`, pink `#FF9BD2`, sky `#8FB8FF` | Topic dots and orbs |
| Platform (galaxy) colors | TikTok `#64D2FF`, Reels `#BF5AF2`, Shorts `#FF6B5A`, YouTube `#FF9F0A`, LinkedIn `#0A84FF`, Stories `#FF6FA8` | Platform chips, galaxies |

Aurora backgrounds are radial gradients of `rgba(157,140,255,0.17–0.30)` and `rgba(94,78,224,0.12–0.16)` over `bg.night`. Each screen has its own placement; copy it from the HTML.

---

## 3. Typography (SF Pro mapping)

| Style | Size / line | Weight | Tracking | Use |
| --- | --- | --- | --- | --- |
| Screen title | 34 / 40 | Bold | -0.02em | Tab roots (Scripts, Takes, Settings…) |
| Story title | 30 / 35 | Bold | -0.02em | Onboarding, celebrations |
| Title 2 | 26–28 / 31–34 | Bold | -0.02em | Sheets, script title |
| Headline / button | 17 | Bold (primary) / Semibold | 0 | Buttons, row titles |
| Body | 15–17 / 21–25 | Regular | 0 | Text, descriptions |
| Footnote | 12.5–13 | Regular | 0 | Hints, legal |
| Label (SF Mono) | 10–11 | Semibold | 0.08–0.14em, uppercase | Chapter labels, states (IN EDIT · AUTOSAVED), values |
| Prompter | 24–26 / 1.3 | Semibold | -0.01em | Teleprompter (user setting) |

---

## 4. Shape and layout

- **Gutters:** 16 pt side margins and 20 pt for text blocks.
- **Primary button:** a 54 pt pill (radius 27) in yellow with black text.
- **Secondary button:** text only, at 75% white.
- **Chips:** 38 pt high in onboarding and 34 pt in lists, as full pills.
- **Cards:** radius 20–26. Sheets have a 30–34 pt top radius. Icon tiles are 16 pt.
- **Bottom tab bar:** a floating glass pill, 64 pt high, 16 pt from the sides and 26 pt from the bottom.
- **Shadows:** cards `0 12 30 rgba(0,0,0,0.28)`. The primary button may glow with `0 10 30 rgba(255,214,10,0.25)`, used sparingly.

---

## 5. The sky (browse screens and onboarding only)

**Never** draw the sky over the camera, a take, the editor or a video.

| Layer | Stars per tile | Size | Opacity | Tile | Drift (one tile) |
| --- | --- | --- | --- | --- | --- |
| Far | 16 | 0.6–1.0 pt | 0.30–0.65 | 180 × 170 | 260 s, downward |
| Mid | 12 | 1.0–1.5 pt | 0.45–0.80 | 390 × 310 | 160 s |
| Near | 7 | 1.6–2.4 pt | 0.60–0.95 | 390 × 600 | 85 s |

- **Nebulae:** 1–2 soft blobs (240–320 pt, blur 38, violet at 10–22%). They drift ±20 pt and scale 1→1.16 over 26–34 s, reversing direction each cycle.
- **Twinkles:** 3–8 per screen, 1.8–3 pt, cycle 2.6–4.1 s with irregular keyframes.
  - Opacity runs 0.2 → 1 → 0.45 → 0.95 → 0.25 → 1 → 0.5, with scale between 0.7 and 1.3.
  - About half have a **phone-camera cross glint**: two 16 pt hairlines with a white centre fading to the ends.
  - Some are tinted `#FFF3C4` or `#E4DEFF`.
- **Shooting star:** a 130 × 1.5 pt streak at 160°. It travels about 380 pt in about 0.7 s, once every 11–14 s, with at most 2 per screen, staggered.
- **Implementation:** one `Canvas` inside `TimelineView(.animation(minimumInterval: 1/30))`.
  - Run at 30 fps; it is ambient.
  - Pause when the screen is not visible, in Low Power Mode and when Reduce Motion is on (static frame).
  - Budget: under 2% CPU on an iPhone 12 at idle.
- **Personalize › Starry sky** has three settings, Off · Calm · Lively. Calm is the default. Lively doubles the twinkles and shooting stars.

---

## 6. Components

### 6.1 Orb controls (sliders)

See the board `0.3_Orb-controls`. These replace every slider in the app.

- **Anatomy.**
  - **Rail:** 4 pt, `rgba(110,116,150,0.32)`. Rows use 3 pt.
  - **Trail:** a gradient from `rgba(255,214,10,0.12)` to `#FFD60A` with a soft glow.
  - **Orb:** 26 pt (rows 20 pt, on-camera 16 pt). It is a radial gradient (`#FFFDF2` → `#FFE680` → `#F2C200` → `#8A6400`, highlight at 34%/30%) with a 1 pt dark hairline and a glow `0 0 12 rgba(255,214,10,0.5)`.
  - **Orbit ring:** an ellipse (orb + 22 pt, scaleY 0.38, tilted -18°).
  - **Detent tick:** 1.5 × 18 pt at the default value.
  - **Step stars:** 8 pt 4-point stars. Passed steps turn `#FFE680`.
- **States.**
  - **Rest:** nothing moves.
  - **Holding:**
    - the orb scales ×1.14 with a spring;
    - the ring fades in over 120 ms and turns once every 4 s;
    - the value label brightens to `#FFF6C2` with a glow;
    - the trail brightens.
  - **Release:** the ring fades over 220 ms and the orb springs back.
  - **Focused** (VoiceOver or keyboard): a dashed cyan ring.
  - **Disabled:** a grey orb, no trail, labels at 40%.
- **Variants:**
  - **continuous:** speed, volume, glow;
  - **stepped:** text size, margins, countdown, clean-up, sky. The orb snaps with a spring (response 0.28, damping 0.72);
  - **from center:** caption timing. The trail grows both ways from 0;
  - **in a row:** the label sits left, the track (96–130 pt) in the middle and the value on the right;
  - **on camera:** a glass pill with a 16 pt orb.
- **Precision.**
  - The orb follows the finger 1:1 with no smoothing.
  - Dragging down while holding switches to ½ speed, then ¼ (fine scrubbing). Show "FINE · ½" in the value label.
  - Double-tap the orb to reset to default. Tap the value to type a number.
- **Haptics:** `.selection` on each step and when crossing the detent; `.impact(.soft)` at both ends.
- **Accessibility.**
  - The hit target is 44 × 44 pt.
  - `accessibilityValue` reads the value with its unit, for example "140 words per minute".
  - `accessibilityAdjustableAction` moves one step (continuous controls use 5% steps or the natural unit).
  - The value is always written in text.
  - With Reduce Motion: no ring spin or glow pulse, and the orb still moves.
- **SwiftUI.** Build one `OrbSlider` view with these parameters:
  - `value: Binding<Double>`, `range`, `step: Double?`, `defaultValue`;
  - `style` (`.full`, `.row`, `.compact`), `origin` (`.leading`, `.center`);
  - `label`, `valueText`.
  - Use `DragGesture(minimumDistance: 0)` and `.sensoryFeedback`.

**Where orbs appear:**

| Screen | Controls |
| --- | --- |
| Prompter settings | Speed (wpm, detent at default), Text size (S·M·L·XL), Reading line (Near the camera · Upper third · Middle), Margins (Narrow · Medium · Wide), Countdown (Off · 3 s · 5 s · 10 s) |
| Studio and Recording | Compact speed pill |
| Editor › Sound | Your voice (0–150%, detent 100%), Music (0–100%), Clean up voice (Off · Light · Strong) |
| Editor › Text | Size (24–120 pt), Glow (0–100%) |
| Editor › Captions | Size (S·M·L·XL) |
| Personalize | Starry sky (Off · Calm · Lively) |

### 6.2 Tab bar

- Five tabs, using the v2 icons at 22 pt. Labels are 10.5 pt.
- Resting tabs are at 62% white. The active tab is `#FFD60A`.
- A **6 pt yellow orb** sits under the active label (glow `0 0 8 #FFD60A`). It **travels** to the newly selected tab with `matchedGeometryEffect` and a spring (response 0.35, damping 0.7), slightly overshooting.
- The Record tab uses a ring with a red orb.

### 6.3 Teleprompter (recording, studio, practice)

- **Prompter card:** glass `rgba(6,7,14,0.62–0.8)` + blur 14. Top and bottom fades are 40 and 64 pt.
- **Horizon (reading line):** 2 pt yellow line with fading ends.
  - Glow `0 0 14 rgba(255,214,10,0.8), 0 0 40 rgba(255,214,10,0.35)`, plus a small yellow arrow at the left.
  - It breathes on a 2.4 s cycle. When following the voice, its glow can flicker gently with the input level (0.75–1.0 opacity).
- **Voice-follow scroll:** the current line sits just above the horizon.
  - Moving to the next line is a 0.45 s glide (ease in-out, `cubic-bezier(.45,0,.25,1)`).
  - Words light when spoken: from 42% white to 100% in 0.12 s, with a yellow glow that fades over 0.7 s.
  - Lines already read dim to 42% over 0.5 s.
- **Rising particles:** 3–4 tiny yellow and white specks rise 34 pt from the horizon over 2.4–3.1 s.
- **Section rail:** a 2 pt rail on the right edge with three stars for Hook · Body · CTA.
  - The fill follows reading progress.
  - Entering a section pops its star (scale 1.7 → 1 in 0.55 s) with `.selection` haptic.
  - The label under the prompter crossfades (HOOK · 1 OF 3 → BODY · 2 OF 3).
- **"✦ FOLLOWING YOUR VOICE"** chip sits at the bottom-left of the prompter.

### 6.4 AI states (violet)

- **AI aura:** a 2 pt border with a conic gradient (`#B4A7FF` → `#FFD60A` → `#FFF6C2` → `#E4DEFF`) turning once every 2.8 s. It fades in over 0.5 s while writing and out over 0.9 s when done.
- **Words from light:** each word goes from opacity 0, blur 8 and y +6 to its final state in 0.3 s (`cubic-bezier(.16,1,.3,1)`). It carries a violet text glow that fades over 0.9 s.
  - Stagger 0.16–0.18 s between words.
  - Section labels (HOOK · BODY · CTA) appear 0.15 s before their words.
- **Writing label:** "✦ Writing in your voice" with a shimmer gradient moving across the text every 1.5 s and three bouncing dots.
- **Reading-line preview:** when a script finishes, a yellow line passes once down the card (1.1 s).
- **Never animate text the user is editing.** These effects apply only to text arriving from the model.

### 6.5 Primary button shine

A 70 pt white band at 105° sweeps across the yellow button in 0.8 s, every 4–8 s, on at most one element per screen. It is not shown under Reduce Motion.

---

## 7. Motion primitives

| Primitive | Timing | Curve | Haptic | Reduce Motion |
| --- | --- | --- | --- | --- |
| **Ignite**: core 0 → 1.8 → 1; two light waves (scale 0.4 → 6.5, second +0.18 s); cross flare 0 → 1 in 0.18 s, settling to 0.3 by 0.9 s | 0.65 s core, 1.0 s waves | Overshoot `(.3,1.3,.5,1)`; waves `(.1,.6,.3,1)` | `.success` | Fade in only |
| **World birth**: tap ripple (0.6 s) → spark flies to the orbit (1.25 s) → orbit draws (1.3 s) → planet pops 0 → 1.9 → 1 (0.6 s) → name label 2.7 s | ~3.5 s total | Spark `(.5,0,.3,1)` | `.selection` on tap, `.success` on birth | Planet appears with fade |
| **Comet travel**: route draws while the head (24–34 pt glow) moves along the path with a tail (14–18% of the path) | 1.25–2.0 s | `(.45–.55,0,.25–.3,1)` | `.impact(.light)` on leave | Instant state + fade |
| **Arrival**: flash disc + two waves + cross flare at the destination | 1.0 s | ease-out | `.success` | Fade |
| **Fold into light**: a card scales to 0.05 from its top edge, brightness ×3, radius → circle | 0.55 s | `(.6,0,.3,1)` | — | Fade |
| **Words from light** | 0.3 s per word, stagger 0.16 s | `(.16,1,.3,1)` | — | Words fade in together |
| **Star ring countdown**: 12 stars ignite every 0.25 s; progress arc 3 s linear; numbers enter from scale 1.35 + blur 10 in 0.22 s and leave in 0.2 s; final flare + wave | 3 × 1 s + 0.6 s | numbers `(.2,.9,.25,1)` | `.impact(.light)` ×3, `.impact(.medium)` at "Let's Cue" | Numbers crossfade |
| **Voice-follow glide** | 0.45 s per line | `(.45,0,.25,1)` | — | Jump without glide; word highlight stays (no glow) |
| **Orb hold / snap** | ring 120 ms in, 220 ms out; snap spring 0.28/0.72 | spring | `.selection` per step | No ring spin |
| **Tab orb travel** | ~0.45 s | spring 0.35/0.7 | `.selection` | Instant |
| **Text rise** (story titles): word by word from y +16, blur 10 | 0.8 s, stagger 0.085 s | `(.16,1,.3,1)` | — | Fade |
| **Chapter change** (onboarding): the current chapter scales to 0.96 and fades in 0.35 s while the sky layers shift up 30/50/80 pt (parallax); the next chapter fades in from 1.04 in 0.45 s | 0.6 s | ease in-out | `.impact(.soft)` | Crossfade |

Story sequences (welcome, chapters, send-off, milestone, first star) **play once** in the app. The boards loop them only so they can be reviewed.

---

## 8. Screen-level motion (summary)

The details for each screen are in `SCREENS.md`.

- **Onboarding.**
  - **1.1 Welcome:** sky dolly-in, constellation draws, the Cue star ignites, then the text rises.
  - **1.2 Your universe:** world birth.
  - **1.3 First voyage:** spiral galaxies turning, tap → route and comet → arrival, then the format line types in.
  - **1.4 First script:** AI aura with words from light.
  - **1.5 Give it a voice:** "Continue" → iOS prompt → camera iris opens to the live face.
  - **1.6 Practice:** voice-follow.
  - **1.7 First star:** fold into light → comet → ignite → link to YOU.
- **Script page:** the CTA is written from light and the CTA bar glows while writing.
- **Countdown:** star ring.
- **Recording:** voice-follow, section rail and HOOK → BODY label crossfade.
- **Pick your best take:** side takes slide in, a violet analysis line scans the middle take, then the "✦ Best take" badge pops with a wave and flare. The "why" chips pop in one by one.
- **Editor panels:** orb controls only. **No sky, no particles.**
- **Send-off:** fold into light → comet → TikTok arrival → "It's now a star in your universe".
- **Milestone:** light converges, the icon pops with a flare and slow rays.

---

## 9. Haptics map

| Moment | Feedback |
| --- | --- |
| Choose a topic, platform, tab or step | `.selection` |
| A world is born, a video arrives, first star, milestone, permission granted | `.success` |
| Countdown 3·2·1 / Let's Cue | `.impact(.light)` ×3 / `.impact(.medium)` |
| Orb at the ends | `.impact(.soft)` |
| Best take chosen by Cue | `.impact(.soft)` |
| Recording start and stop | Keep v26 |

Respect the "Haptics" switch in Personalize.

---

## 10. Icons

- **Set v2 "orbit line":** 53 icons in `05 Icons/in-app/`. They use a 24 pt grid, 2 pt padding, a 1.75 pt stroke and round caps and joins. The `currentColor` stroke is used for tinting.
- **Three motifs:** the orb, the orbit and the 4-point star. Their fills use `currentColor`, so the whole icon tints together. Where a motif needs its own colour (the red record orb), it is noted in `SCREENS.md`.
- **Implementation:** add the icons as SVG assets in the catalogue with Preserve Vector Data, rendered as Template. Optionally rebuild them as custom SF Symbols from these drawings.
- **Colour comes from context:**
  - 62% white at rest;
  - yellow when active;
  - violet for AI;
  - red only for record;
  - 25% when disabled.
- **Alternate app icons:** the layers are in `05 Icons/app-icons/` (1024 px: background, middle, reading line or star).
  - Assemble them in Icon Composer (`.icon`) so they get the iOS dark, clear and tinted variants.
  - Ship them as alternate icons and switch with `UIApplication.setAlternateIconName`.
  - **Unlocks:**
    - Aurora at the 1st share;
    - First Light at 10 shares, Pro;
    - Deep Space at 25, Pro;
    - Constellation at 50, Pro.

---

## 11. Editor text styles (free fonts)

| Style | Font (SIL OFL 1.1) | Weight | Notes |
| --- | --- | --- | --- |
| Orbit | Unbounded | 800 | Wide, cosmic; hooks and titles |
| Logbook | Instrument Serif | 400 Italic | Elegant quotes |
| Signal | Space Mono | 700 | Numbers, steps |
| Launch | Anton | 400 | Condensed impact; also the caption style "Bold" (replaces "Impact") |
| Nebula | Syne | 800 | Expressive |
| Comet | Space Grotesk | 700 | Clean, general |
| Postcard | Caveat | 700 | Handwritten notes |

- **Sources and licence:** download the fonts from Google Fonts or `github.com/google/fonts/tree/main/ofl/`. Bundle the `.ttf` files with `UIAppFonts` and show each `OFL.txt` under Settings › About › Licenses.
- **Rendering:** text overlays must render identically in the preview and in the export (Core Text, or a `CALayer` through `AVVideoCompositionCoreAnimationTool`).
- **Glow:** the glow orb maps 0–100% to a two-layer shadow (`blur = g × 18 pt` and `g × 36 pt`, colour = text accent).
- **Other scripts:** for ja, ko, zh, ar, hi and th, fall back to the system font with the same weight, colour and glow. Check each font's glyph coverage before using it in a locale.
- **Existing caption styles:** Poppins (Pop) and Fraunces (Editorial) are OFL too.

---

## 12. Permissions (onboarding chapter 4)

- **Order:** microphone, then camera. If voice-follow uses the Speech framework, the speech-recognition request follows the microphone in the same chapter.
- **The custom screen explains why.** Its only button is **"Continue"**, which opens the iOS alert.
  - Never use "Allow" on our own button.
  - Do not add "Not now" or "Skip" on that screen.
- **If the user denies:** the app keeps working. The prompter falls back to steady scroll without the microphone, and recording asks again in context with a link to Settings.
- **Photos (save video):** ask at the first save, not in onboarding.
- **App Tracking Transparency:** ask only if an ads or attribution SDK that tracks is added. The current design has none.
- **Usage strings:** add `NSMicrophoneUsageDescription`, `NSCameraUsageDescription`, `NSSpeechRecognitionUsageDescription` (if used) and `NSPhotoLibraryAddUsageDescription`, and localise them all.

---

## 13. AI availability

- **Check before every call:** whether the device and the content language are supported (`SystemLanguageModel.default.availability` and its supported languages).
- **Onboarding chapter 3 without AI:** show a curated script for the chosen topic and platform, written by us and localised.
  - Label it "TELEPROMPTER PRACTICE" instead of "✦ WRITING FOR …".
  - Keep the same reveal, but use a plain fade instead of the violet glow.
- **Never sell AI on the paywall** to a device or language that cannot use it.

---

## 14. Accessibility checklist

- 44 × 44 pt targets everywhere. VoiceOver labels on all icon-only buttons, matching the `aria-label`s in the HTML.
- Orb controls are adjustable elements with their value and unit spoken.
- **Reduce Motion:**
  - static sky;
  - no comets, rays, shine or ring spin;
  - state changes as crossfades;
  - prompter words still highlight, without glow.
- Contrast: keep small text at or above 55% white on `bg.night`.
- Colour is never the only signal. Topics and platforms always show their names.
- Captions and text overlays keep their 2 pt dark outline or shadow, so they stay legible on bright video.

---

## 15. Performance

- **One sky per screen,** drawn in a `Canvas` at 30 fps. Pause it off-screen, in Low Power Mode and during camera use.
- **Particles:**
  - at most 12 per celebration;
  - at most 4 at the horizon;
  - no particle systems in the editor.
- **Camera screens:** only the prompter animates. Keep the 60/120 fps camera preview first.
- **Story animations:** use `KeyframeAnimator` and `PhaseAnimator`, and drive them from state changes, not timers.
