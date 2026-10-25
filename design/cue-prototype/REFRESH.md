# Refresh the prototype from the app

Run this when the owner asks to bring the prototype up to date (or when `scripts/check-prototype.py --report` shows screens behind the app). The prototype is drawn **from the app code**, the way v31 was: it shows what the app does, it does not decide anything.

## 1. See what is behind

```sh
scripts/check-prototype.py --report
```

Each screen lists the app commits that touched its files since the commit it was drawn from (`drawnFrom` in `screens.json`). Read the subjects: refactors, tests and dead-code cleanups change no pixel and need no redraw. Many onboarding screens share one app file, so one commit can show up on all of them.

Screens with `appFiles: []` (the editor proposal 13.x) cannot be measured. Map them first, or leave them as proposals.

## 2. Redraw only the screens that changed on screen

For each such screen:

1. Read `DESIGN_PROJECT.md` for the screen's section (the owner's decisions win over the old board), then the Swift files in `appFiles` and what they use (tokens in `Palette`, the strings in the String Catalog, the motion in `DesignSystem/Motion`).
2. Edit `screens/<file>.html` so it shows what the app shows now: the same elements, copy, spacing, colors and motion timing. Keep the file standalone (a 390 × 844 `.phone`, relative `assets/`, no network except the Google Fonts link).
3. Keep the header comment of the screen, and put the commit you read from in it.
4. If a screen was added, removed or renamed in the app, change `screens.json` (entry, file, `appFiles`) and, if the viewer lists it, `index.html` (the `static F` map and the component that shows it).
5. For a state or flow the viewer shows through a component (`CueBoard30`, `CueSettings30`, `CueRecorder30`, `CueEditor31`, `CueWatch31`), edit the component the same way.

Do not edit `runtime/` (generated) or `vendor/`.

## 3. Check it opens and still animates

```sh
cd design/cue-prototype && python3 -m http.server 8765
```

Open `http://localhost:8765/index.html`, click **First launch**, then the screens you changed. A screen must open on its own too: `http://localhost:8765/screens/<file>.html`.

## 4. Record that it matches

```sh
scripts/check-prototype.py                 # screens.json is consistent
scripts/check-prototype.py --mark 7.1 7.2  # the screens you redrew now match HEAD
```

Then add a line to `CHANGELOG.md` (version, date, what changed), commit, and tag the finished state `proto-vNN`.

## What this is for

The prototype is the reference to look at, to show, and, later, to take screens and motion from for the App Store page and promo content. The design and the presentation of that content are decided separately by the owner; nothing here prepares them.
