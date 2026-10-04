# Prompt for Claude Design — create Cue App v27 from v26

Attach this whole folder (unzipped) and paste the prompt below into the Claude Design project that holds **Cue App v26**.

---

You are updating the Cue App design project from **v26 to v27**. v27 keeps every v26 flow, data model and piece of logic, and applies a new visual direction called **"Cue Universe"**. Everything you need is in the attached package.

**Read first, in this order:**

1. `01 Direção de design — Cue Universe.md`: the concept, the journey, the principles and the decisions. It is in Portuguese; all UI copy is in English.
2. `06 Specs/DESIGN-SPEC.md`: tokens, typography, components, orb controls, motion, haptics and accessibility.
3. `06 Specs/SCREENS.md`: every screen, with its v26 counterpart and what changes.
4. `00 Workflow overview.png`, plus the screens in `03 Screens — PNG @3x/` and `04 Screens — HTML source/`. Open the HTML files in a browser: they animate, and the motion is part of the design.

**What to produce in the v26 project (as a new version, v27):**

1. **Design system update.**
   - Dark only: remove the light palette and the Appearance setting.
   - Add the colour tokens, the type scale (SF Pro / SF Mono), the sky (three layers + twinkles + shooting star) and the motion primitives.
   - Add the **orb controls** component with all its states and variants, and the **icon set v2 "orbit line"** from `05 Icons/in-app/`.
2. **Restyle every v26 screen** to match the boards in `03`/`04`, including screens the package does not show.
   - Apply the same rules: sky only on browse screens, never over the camera, a take or the editor; violet only for AI; yellow for action and signal.
3. **Add the new screens and states.**
   - Onboarding "first voyage" (1.1–1.7)
   - Logbook (3.6)
   - Opening the editor (7.1)
   - Text styles (7.3)
   - Sound (7.5)
   - Send-off (8.2)
   - Milestone (8.3)
   - Your universe (9.2)
   - Answer with a video (10.1–10.4)
   - Prompter settings (11.2)
   - Personalize (11.3)
4. **Replace every slider with an orb control.** This covers prompter speed and size, the studio speed pill, editor sound and text, caption size, sky intensity and any other slider in v26.
5. **Swap all icons** for the v2 set: tab bar (with the travelling active orb), editor toolbar, recording controls, settings rows, sheets. If v26 needs an icon that is not in the set, draw it with the same rules: 24 grid, 1.75 stroke, round ends, and at most one motif (orb, orbit or star).
6. **Editor text styles:** use the 7 OFL fonts listed in the spec (Unbounded, Instrument Serif, Space Mono, Anton, Syne, Space Grotesk, Caveat). Rename the "Impact" caption style to "Bold" (Anton).
7. **Motion notes on every animated screen:** add a short annotation with the timeline (what moves, duration, curve, haptic), copied from the spec, so engineering can build it 1:1.

**Keep exactly as in v26:**

- The editor's layout, timeline and tools.
- The take pipeline (TO PICK › IN EDIT › READY › SHARED).
- The My Cue Voice data.
- Pricing logic and the 5 free exports.
- All feature names and the 20-language strategy.

**Do not:**

- call the user "captain";
- use anything from Star Trek (words, sounds, visuals);
- put the starry sky over the camera, takes or the editor;
- use "Allow" on our own permission button. It says "Continue" and the iOS alert follows; there is no Skip or Not now on that screen;
- add a paywall to onboarding.

**Check before you finish:**

- Every screen in `SCREENS.md` exists in v27.
- No v26 screen is left in the old style.
- Small text is at or above 55% white.
- Touch targets are 44 pt.
- Every animated screen has a Reduce Motion note.
- The string list in `06 Specs/strings-en.csv` matches the copy on the screens.

**Deliver** the updated project as v27, and list any v26 screen where you had to make a judgement call.
