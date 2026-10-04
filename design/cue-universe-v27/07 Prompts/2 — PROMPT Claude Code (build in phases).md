# Prompt for Claude Code — build the "Cue Universe" v27 design

Put this folder in the repo (suggested path: `design/cue-universe-v27/`). If Claude Design has already produced v27, add its export too. Then paste the prompt below into Claude Code, in the `cuestudio` repo (github.com/mfmansueli/cuestudio).

---

You are implementing the v27 design of **Cue Studio** (SwiftUI, iOS 27, iPhone 11 and later). The design package is in `design/cue-universe-v27/`.

**Read first:**

1. `01 Direção de design — Cue Universe.md`: the concept, the principles and the decisions. It is in Portuguese; UI copy is English.
2. `06 Specs/DESIGN-SPEC.md`: tokens, components, orb controls, motion, haptics, permissions, AI availability and accessibility. This is your build spec.
3. `06 Specs/SCREENS.md`: every screen, its v26 counterpart and its phase.
4. The screens: `03 Screens — PNG @3x/` (static) and `04 Screens — HTML source/` (animated). Open the HTML in a browser for timing. The CSS keyframes are the reference for the motion.

**Ground rules:**

- **Keep the existing architecture, data and business logic.** This is a visual and motion layer on top of v26 behaviour, plus the new screens listed in `SCREENS.md`.
- **Work in phases.** Open one PR per phase (or per sub-step if it gets large). Each PR must build, pass the tests and include screenshots and short screen recordings of the changed screens.
- **Use system fonts (SF Pro, SF Mono) in the UI.** The mock-ups use Geist, but do not bundle Geist.
- **Strings:**
  - Every new string goes into the String Catalog with a comment.
  - Use `06 Specs/strings-en.csv` as the source for English copy and suggested keys.
  - Mark new strings `needs_review` in the other 19 languages.
- **Respect Reduce Motion, Low Power Mode and the user's Haptics and Starry sky settings** everywhere.
- **Do not:**
  - call the user "captain" anywhere;
  - use any Star Trek terms, sounds or visuals;
  - draw the sky over the camera, a take or the editor;
  - use "Allow" on our own permission button.

## Phase 0 — Foundations

1. **Dark only.**
   - Set `UIUserInterfaceStyle = Dark` in Info.plist and `.preferredColorScheme(.dark)` at the root.
   - Remove the Appearance setting and the light palette.
2. **Design tokens:** `CueColor`, `CueFont` (text styles mapped to SF Pro and SF Mono), `CueRadius`, `CueSpacing`, from DESIGN-SPEC §2–4.
3. **Icons:**
   - Import `05 Icons/in-app/**/*.svg` as template vector assets.
   - Create a `CueIcon` enum.
   - Replace the icons in the tab bar, editor toolbar, recording controls and settings rows.
4. **Motion system:** a `CueMotion` namespace with the curves, springs and durations from DESIGN-SPEC §7, and a `CueHaptics` helper wired to the Haptics setting.
5. **Sky:**
   - A `StarfieldView` built on `Canvas` + `TimelineView` at 30 fps, with three layers, twinkles with cross glints, a shooting star and nebulae.
   - It pauses off-screen, in Low Power Mode, under Reduce Motion and when Starry sky is Off.
   - Calm and Lively densities.
6. **Orb controls:** an `OrbSlider` component with every variant and state in §6.1 (full, row, compact; leading or centre origin; continuous or stepped; detent; fine scrubbing; double-tap reset; accessibility adjustable).
   - Unit tests for the value mapping, stepping and accessibility actions.
   - A preview catalogue.
7. **Light effects:** reusable views for the glow line, ignite (waves + cross flare), comet (head + tail along a `Path`), words from light, AI aura and the shine sweep, each with a Reduce Motion fallback.

**Acceptance:** a debug "Design catalogue" screen shows every token, icon, orb variant and effect. Instruments shows the sky under 2% CPU on an iPhone 12 at idle.

## Phase 1 — Launch

1. **Restyle every existing screen** to the boards: Scripts, Takes, Profile, Settings, the script page, recording, studio, takes review, editor, sheets and the paywall.
   - Use platform-first filters.
   - Show the topic as a colour dot.
   - Keep the writing card always visible on Scripts.
2. **Tab bar:** a glass pill with the v2 icons and an active orb that travels with `matchedGeometryEffect`.
3. **Onboarding "first voyage" (1.1–1.7)**, shown once.
   - Topics feed My Cue Voice. The platform sets format, length and safe zones.
   - **Chapter 3:** generate a ~15 s script with the on-device model for the chosen topic and platform.
     - First check device and language availability (`SystemLanguageModel.default.availability` plus the language).
     - If unavailable, use the curated local script for that topic, labelled "TELEPROMPTER PRACTICE".
   - **Chapter 4 permissions:** microphone, then camera, plus speech recognition if voice-follow needs it.
     - Our own button says **Continue** and is followed by the system alert.
     - There is no Skip or Not now on that screen.
     - Denial must not block the app.
     - No App Tracking Transparency request.
   - **Chapter 5:** practice teleprompter with "Record it for real" and "Not now".
   - **Chapter 6:** the first-star animation.
   - Skip, on other chapters, goes to the Scripts empty state.
4. **Teleprompter (recording and studio):**
   - the horizon line;
   - voice-follow glide;
   - word highlight as words are spoken (use the recogniser's timing);
   - read lines dim;
   - the section rail with Hook/Body/CTA dots and haptics;
   - section label crossfade;
   - the compact orb speed pill;
   - "✦ FOLLOWING YOUR VOICE" chip.
5. **Countdown:** the star ring, numbers, flare and haptics. Its length comes from Prompter settings.
6. **Pick your best take:** analysis scan, best-take badge ignite and reason chips (the existing v26 logic decides the best take).
7. **Editor:** keep the layout.
   - **Opening the editor:** the transition (7.1).
   - **Text styles:** 7 styles with bundled OFL fonts (`UIAppFonts`), plus Size and Glow orbs. Text must render identically in preview and export. Use system-font fallback for non-Latin scripts.
   - **Captions:** add the Size orb and rename "Impact" to "Bold" (Anton).
   - **Sound:** voice, music and clean-up orbs (wire them to the existing audio pipeline). If clean-up does not exist yet, ship Off/Light only and hide Strong behind a feature flag.
8. **Ready to post (E3)**, **Ready to travel**, **Send-off** (fold into light → comet → arrival; plays once) and **Milestone** for the 1st share (Aurora icon).
9. **Settings:**
   - **Prompter settings:** a live preview and orb controls for Speed, Text size, Reading line, Margins and Countdown. Persist them with the existing settings store.
   - **Personalize:** the app icon picker (Default and Aurora at launch), topics and colours, the auto-tag switch, the Starry sky orb, and the Celebrations and Haptics switches.
10. **Paywall:** "Take your universe further.", the feature list, yearly pre-selected and 7 days free. Prices come from StoreKit products; do not hard-code them.
    - **Never present AI benefits** on devices or languages without AI.
11. **AI gating everywhere:** check availability before calls and show a clear message when unavailable.

**Acceptance:**

- Every L screen in `SCREENS.md` matches its board.
- The motion matches the HTML timing within about 10%.
- VoiceOver works through onboarding, recording and the orb controls.
- Reduce Motion gives static or crossfade versions.
- There are no layout breaks in German, Japanese or Arabic (RTL) at the largest supported Dynamic Type.
- UI tests cover onboarding (with and without AI, permissions granted and denied), the orb slider, and the share → send-off flow.

## Phase 2 — First update (U1)

1. **Your universe (9.2):** topics as worlds and shared videos as stars with lines to their platforms; next milestone; Share my universe (image export).
2. **Milestones and alternate icons:**
   - First Light at 10, Deep Space at 25, Constellation at 50 (Pro).
   - Assemble them in Icon Composer from `05 Icons/app-icons/`.
   - Switch with `setAlternateIconName`.
   - Count shares locally.
3. **Logbook (3.6):** hold to capture by voice, text capture, "Shape" turns an idea into a script.
4. **Auto topic tagging:**
   - The on-device model picks one of the user's topics for each new script.
   - The user can change it.
   - The switch lives in Personalize.
   - Nothing leaves the device.

## Phase 3 — Later

1. **Answer with a video (10.1–10.4):**
   - a share extension receives a screenshot or link;
   - Vision OCR finds the comment;
   - a confirm step;
   - a draft script in the user's voice;
   - a comment card overlay in the editor.
2. **Year in review** from Your universe.

## When you finish each phase

Report:

- what changed;
- the screenshots and recordings;
- anything you could not match and why;
- new strings added;
- performance numbers for the sky and teleprompter screens.

Ask before changing any business rule, such as the free-export count, prices, the AI quota or the take pipeline.
