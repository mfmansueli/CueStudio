#!/usr/bin/env python3
"""Keeps design/cue-prototype/ honest, in about a second.

1. screens.json is well formed: every `file` and `component` exists, every `appFiles` entry is a real file or folder
   in the repo, and no screen file in screens/ is missing from the map.
2. The prototype follows the app: if a branch changes a Swift file that screens.json maps to a screen, and nothing under
   design/cue-prototype/ changed, it names the screens to look at.

    scripts/check-prototype.py                  # compares HEAD with origin/main (the branch's changes)
    scripts/check-prototype.py --base main      # another base
    scripts/check-prototype.py --strict         # a stale prototype fails (exit 1) instead of warning

A broken screens.json always fails. A stale prototype only warns, unless --strict: some Swift changes are not visible
(a refactor, a test), and the author decides that.
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROTO = ROOT / "design" / "cue-prototype"
INDEX = PROTO / "screens.json"


def git(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, check=False).stdout


def check_index(data: dict) -> list[str]:
    problems = []
    listed = set()
    for screen in data.get("screens", []):
        sid = screen.get("id", "?")
        if "file" in screen:
            listed.add(screen["file"])
            if not (PROTO / screen["file"]).is_file():
                problems.append(f"{sid}: file {screen['file']} does not exist")
        elif screen.get("component"):
            if not (PROTO / screen["component"]).is_file():
                problems.append(f"{sid}: component {screen['component']} does not exist")
        else:
            problems.append(f"{sid}: no file and no component")
        for app in screen.get("appFiles", []):
            if not (ROOT / app).exists():
                problems.append(f"{sid}: app file {app} does not exist (renamed or deleted? fix screens.json)")
    for path in sorted((PROTO / "screens").glob("*.html")):
        rel = f"screens/{path.name}"
        if rel not in listed:
            problems.append(f"{rel} is not in screens.json")
    return problems


def check_follows_app(data: dict, base: str) -> list[str]:
    changed = [line for line in git("diff", "--name-only", f"{base}...HEAD").splitlines() if line]
    if not changed:
        return []
    if any(path.startswith("design/cue-prototype/") for path in changed):
        return []
    stale = {}
    for screen in data.get("screens", []):
        for app in screen.get("appFiles", []):
            hit = [path for path in changed if path == app or (app.endswith("/") and path.startswith(app))]
            if hit:
                stale.setdefault(screen["id"], set()).update(hit)
    return [f"{sid}: {', '.join(sorted(files))}" for sid, files in sorted(stale.items())]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--base", default="origin/main")
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    if not INDEX.is_file():
        print(f"✘ {INDEX.relative_to(ROOT)} is missing")
        return 1
    data = json.loads(INDEX.read_text(encoding="utf-8"))

    problems = check_index(data)
    for problem in problems:
        print(f"✘ {problem}")

    stale = check_follows_app(data, args.base)
    if stale:
        print(f"{'✘' if args.strict else '!'} The app changed files that design/cue-prototype/screens.json maps to these screens,")
        print("  and the prototype did not change. Update the screen's HTML, its entry and CHANGELOG.md, or say why it needs no change:")
        for line in stale:
            print(f"  - {line}")

    if problems or (stale and args.strict):
        return 1
    if not stale:
        print(f"✔ screens.json is consistent ({len(data['screens'])} screens)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
