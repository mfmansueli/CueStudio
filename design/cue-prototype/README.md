# Cue prototype (v31)

The whole Cue app as a clickable prototype, kept next to the code. It is the visual and motion reference for the full flow. Open it, record it, or hand it to Claude Code.

## Open it

```sh
cd design/cue-prototype
python3 -m http.server 8765
# then open http://localhost:8765/index.html
```

It must be served over HTTP (opening `index.html` from the disk does not load the screens). The fonts come from Google Fonts, so the first load needs internet. React is bundled in `vendor/`.

In the viewer:
- **First launch** and **Returning creator** start the two flows.
- The list on the left jumps to any screen.
- **Sample / New year / New account** and **Free exports** switch the app data.
- Tap anything inside the phone: the buttons follow the flow.

## What is here

| Path | What it is |
| --- | --- |
| `index.html` | The interactive full flow (phone, screen list, data switches) |
| `screens/*.html` | One standalone HTML per screen, with its animation. Open any of them on its own |
| `screens/assets/` | Images used by the screens |
| `Cue*.dc.html` | The components the viewer loads (board, settings, recorder, editor, Watch) |
| `runtime/` | The Claude Design runtime the pages need. Generated code: do not edit |
| `vendor/` | React 18.3.1, so nothing loads from unpkg |
| `screens.json` | The screen map: id, title, group, file, status and the app files that implement it |
| `CHANGELOG.md` | What changed in each version of the prototype |

`screens.json` is the index to start from. Each screen lists `appFiles`, the Swift files that implement it. Those paths are **suggestions** (`appFilesStatus: "suggested"`), made by name; confirm them in the code before relying on them, and fix the entry when you do.

## Keep it current

When a PR changes a screen that is listed in `screens.json`, update that screen's HTML (and its entry, if the title or the files changed) in the same PR, and add a line to `CHANGELOG.md`. Tag a finished state `proto-vNN`.

Screens marked `proposal, awaiting owner approval` (Apple Watch 12.x, editor 13.x) are not decisions yet.

## How it relates to `cue-v30/handoff-telas/`

`design/cue-v30/handoff-telas/` is a handoff of the screens that changed in v30: 55 files in their final state, without JavaScript, with the motion written in `ANIMACOES.md`. This folder is the whole app, with the motion running. Both use the same screen numbers for the first-launch, takes, share, profile and Pro screens. Where they differ, `docs/09-Decisions.md` in the handoff and `DESIGN_PROJECT.md` say what the owner decided.

## Known gaps

- The viewer's side links (screens document, tokens, screen map, "What changed in v31", App Preview v5) pointed to files that are not in this folder, so they do not open.
- The runtime fetches Babel from unpkg only if a page uses JSX; none of the current pages does.
- The only change made to generated code: in `runtime/01-*.js`, the React and ReactDOM URLs point to `vendor/` instead of unpkg.
