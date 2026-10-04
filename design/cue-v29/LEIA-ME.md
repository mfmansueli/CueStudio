# Cue Studio v29: read me first

v29 brings the **v28 prototype** (`Cue App v28.dc.html`) into the app with high fidelity. It changes only the design and how the prototype screens connect. **No feature is removed and the business rules do not change** (5 free exports, 7-day trial, $39.99/year, AI quota and the Takes pipeline all stay as they are today).

## Reading order
1. `01-Direction.md`: the idea, the tone, what changes from v27 and why.
2. `02-Tokens.md`: colours, type, radii, spacing, materials, light effects, and the "never do" list.
3. `03-Screen-map.md`: every screen, how you get there, what each element does, transitions, back, failure, status.
4. *(Stage 2)* `04-Flows-and-states.md`, `05-Function-and-logic-changes.md`, `06-Data-map.md`, `screens/`, `prototype/`
5. *(Stage 3)* `motion/`: the HTML for each animation plus a text description.
6. *(Stage 4)* `strings-en.csv`, `icons/`, `07-Accessibility.md`, `08-Phases.md`, `PROMPT-Claude-Code.md`

## Rules of the package
- **Decision means decision.** Nothing in here is "consider" or "maybe". If the prototype and the current code disagree, the prototype wins.
- Every screen in the map has an ID (`3.2`) and a file name (`3.2_Scripts.png`). The prototype uses the same IDs.
- Code that already exists (the v27 phases in `DESIGN_PROJECT.md` §12) gets reused. Each document says what is **new**, what **changes a lot** and what is **only a tweak**.

## Delivery status
| Stage | Content | Status |
|---|---|---|
| 1 | Direction, tokens, screen map | ✅ this delivery |
| 2 | Flows and state machines, changes, PNGs, prototype, data map | pending |
| 3 | Motion | pending |
| 4 | Strings, icons, accessibility, phases, prompt | pending |
