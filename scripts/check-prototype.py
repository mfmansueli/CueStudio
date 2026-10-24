#!/usr/bin/env python3
"""Keeps design/cue-prototype/ honest, in about a second.

1. screens.json is well formed: every `file` and `component` exists, every `appFiles` entry is a real file or folder
   in the repo, and no screen file in screens/ is missing from the map.
2. The prototype follows the app: if a branch changes a Swift file that screens.json maps to a screen, and nothing under
   design/cue-prototype/ changed, it names the screens to look at.

    scripts/check-prototype.py                  # compares HEAD with origin/main (the branch's changes)
    scripts/check-prototype.py --base main      # another base
    scripts/check-prototype.py --strict         # a stale prototype fails (exit 1) instead of warning
    scripts/check-prototype.py --report         # which screens are behind the app, and by which commits
    scripts/check-prototype.py --mark 7.1 7.2   # after redrawing them: they now match HEAD (or --at <commit>); 'all' marks every screen

Each screen in screens.json has `drawnFrom`: the app commit its drawing was made from. "cited" means the screen's own header says so;
"estimated" means the prototype was published on that day and nothing more precise is known.

A broken screens.json always fails. A stale prototype only warns, unless --strict: some Swift changes are not visible
(a refactor, a test), and the author decides that.
"""
import argparse
import json
import signal
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
        since = screen.get("drawnFrom")
        if since and not git("rev-parse", "--verify", "--quiet", f"{since}^{{commit}}").strip():
            problems.append(f"{sid}: drawnFrom {since} is not a commit in this repository")
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


def report(data: dict, ref: str) -> int:
    """For each screen, the app commits that touched its files since the commit the screen was drawn from."""
    rows = []
    for screen in data.get("screens", []):
        apps = screen.get("appFiles", [])
        since = screen.get("drawnFrom")
        if not apps or not since:
            continue
        log = git("log", "--format=%h %s", f"{since}..{ref}", "--", *apps).splitlines()
        if log:
            rows.append((len(log), screen, log))
    behind = sorted(rows, key=lambda row: (-row[0], row[1]["id"]))
    tracked = [s for s in data.get("screens", []) if s.get("appFiles") and s.get("drawnFrom")]
    untracked = [s["id"] for s in data.get("screens", []) if not (s.get("appFiles") and s.get("drawnFrom"))]
    print(f"{len(behind)} of {len(tracked)} screens have app commits since they were drawn (against {ref}).")
    print("A commit is not always a visible change: read the subjects before redrawing.")
    for count, screen, log in behind:
        kind = "" if screen.get("drawnFromKind") == "cited" else " (baseline estimated)"
        print(f"\n{screen['id']}  {screen['title']}  ·  {count} commit(s) since {screen['drawnFrom'][:7]}{kind}")
        for line in log[:3]:
            print(f"    {line[:110]}")
        if count > 3:
            print(f"    … and {count - 3} more")
    if untracked:
        print(f"\nNo way to tell (no app files or no drawnFrom): {', '.join(untracked)}")
    return 0


def mark(data: dict, ids: list[str], at: str) -> int:
    """After redrawing screens (or checking that they still match), record the app commit they now match."""
    sha = git("rev-parse", at).strip()
    if not sha:
        print(f"✘ {at} is not a commit")
        return 1
    wanted = {s["id"] for s in data["screens"]} if ids == ["all"] else set(ids)
    unknown = wanted - {s["id"] for s in data["screens"]}
    if unknown:
        print(f"✘ no such screen: {', '.join(sorted(unknown))}")
        return 1
    for screen in data["screens"]:
        if screen["id"] in wanted:
            screen["drawnFrom"] = sha[:12]
            screen["drawnFromKind"] = "cited"
    INDEX.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"✔ {len(wanted)} screen(s) now match {sha[:12]}")
    return 0


def main() -> int:
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)  # `| head` is not an error
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--base", default="origin/main")
    parser.add_argument("--strict", action="store_true")
    parser.add_argument("--report", action="store_true", help="which screens are behind the app")
    parser.add_argument("--ref", default="origin/main", help="the app version --report compares with")
    parser.add_argument("--mark", nargs="+", metavar="ID", help="screen ids (or 'all') that now match the app at --at")
    parser.add_argument("--at", default="HEAD", help="the commit --mark records")
    args = parser.parse_args()

    if not INDEX.is_file():
        print(f"✘ {INDEX.relative_to(ROOT)} is missing")
        return 1
    data = json.loads(INDEX.read_text(encoding="utf-8"))
    if args.report:
        return report(data, args.ref)
    if args.mark:
        return mark(data, args.mark, args.at)

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
