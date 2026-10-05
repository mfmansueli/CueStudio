# Cue Studio v30: read me first

> **This folder is the only source.** It contains just the approved screens (`SCREENS.md`) and the running prototype that shows them. Ignore every other design folder or file in the repo (`design/cue-v29`, `design/cue-universe-v27`, older `Cue App v2x`, options/test files). They are history.

v30 brings the **approved prototype** (`Cue App v30.dc.html`) into the app with high fidelity. It changes only the design and how the prototype screens connect. **No feature is removed and the business rules do not change** (5 free exports, 7-day trial, $39.99/year, AI quota and the Takes pipeline all stay as they are today).

## Reading order
1. `01-Direction.md`: the idea, the tone, what changes from v27 and why.
2. `02-Tokens.md`: colours, type, radii, spacing, materials, light effects, and the "never do" list.
3. `03-Screen-map.md`: every screen, how you get there, what each element does, transitions, back, failure, status.
4. `04-Flows-and-states.md` · `05-Function-and-logic-changes.md` · `06-Data-map.md`
5. `07-Liquid-Glass.md`: native Liquid Glass first; simulated glass only for custom components (mandatory)
6. `08-My-Cue-Voice-questions.md`: tip frequency, question order and the full question bank for My Cue Voice
7. `prototype/`: open `prototype/Cue App v30.dc.html` in a browser (local server). Side panel: *Jump to any screen*, *TRY TAPPING* and **APP DATA › New account** (empty states). It is a check, not the source of truth: the map and the tables win.
   - The screens live in `prototype/screens/` (same IDs as the map). The recorder (5.2/5.3) is native in the prototype: `CueRecorder30.dc.html`.
6. *(Stage 2b)* `screens/`: PNG @3x per screen and state
7. *(Stage 3)* `motion/`: the HTML for each animation plus a text description.
8. *(Stage 4)* `strings-en.csv`, `icons/`, `07-Accessibility.md`, `08-Phases.md`, `PROMPT-Claude-Code.md`

## Rules of the package
- **Decision means decision.** Nothing in here is "consider" or "maybe". If the prototype and the current code disagree, the prototype wins.
- Every screen in the map has an ID (`3.2`) and a file name (`3.2_Scripts.png`). The prototype uses the same IDs.
- Code that already exists (the v27 phases in `DESIGN_PROJECT.md` §12) gets reused. Each document says what is **new**, what **changes a lot** and what is **only a tweak**.

## Delivery status
| Stage | Content | Status |
|---|---|---|
| 1 | Direction, tokens, screen map | ✅ this delivery |
| 2 | Flows and state machines, changes, data map, prototype | ✅ |
| 2b | PNG @3x per screen and state (normal, empty, loading, error, no AI, XL, RTL) | pending |
| 3 | Motion | pending |
| 4 | Strings, icons, accessibility, phases, prompt | pending |


## Also in this folder
- `09-Decisions.md`: final decisions, which win over every other doc
- `motion/README.md`: every animation, with duration, curve, stagger, repeat and haptic
- `strings-en.csv`: every new v30 text (key, English, context, max length), including all the My Cue Voice questions
