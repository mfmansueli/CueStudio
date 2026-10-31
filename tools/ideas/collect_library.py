#!/usr/bin/env python3
"""The idea library's files (DESIGN_PROJECT §30).

    python3 tools/ideas/collect_library.py [build/logs/test-device.log]
        gathers the `LIBRARY` lines of a device test log (IdeaLibraryDeviceTests) into research_notes/Ideas/library-raw/<localization>.jsonl,
        one idea per line; a language/topic already gathered is replaced by the log's (a rerun of a pair replaces that pair's topics). Also
        sums the `LIBRARYCOST` lines.
    python3 tools/ideas/collect_library.py stage <folder>
        copies the raw files to <folder>/raw, where the simulator can read them (it can't open the Desktop).
    python3 tools/ideas/collect_library.py install <folder>
        copies the packs IdeaLibraryBuildTests wrote in <folder>/packs into Cue Studio/SupportFiles/IdeaLibrary.
"""
import json
import pathlib
import re
import shutil
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
RAW = ROOT / "research_notes" / "Ideas" / "library-raw"
PACKS = ROOT / "Cue Studio" / "SupportFiles" / "IdeaLibrary"


def stage(folder: pathlib.Path) -> None:
    target = folder / "raw"
    target.mkdir(parents=True, exist_ok=True)
    for path in RAW.glob("*.jsonl"):
        shutil.copy(path, target / path.name)
    print(f"staged {len(list(target.glob('*.jsonl')))} languages in {target}")


def install(folder: pathlib.Path) -> None:
    PACKS.mkdir(parents=True, exist_ok=True)
    packs = sorted((folder / "packs").glob("IdeaLibrary-*.json"))
    for path in packs:
        shutil.copy(path, PACKS / path.name)
    print(f"installed {len(packs)} packs in {PACKS.relative_to(ROOT)}")


def main() -> None:
    if len(sys.argv) == 3 and sys.argv[1] in ("stage", "install"):
        (stage if sys.argv[1] == "stage" else install)(pathlib.Path(sys.argv[2]))
        return
    log = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ROOT / "build" / "logs" / "test-device.log")
    found: dict[str, dict[str, list[dict]]] = {}
    dollars = 0.0
    for line in log.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("LIBRARY {"):
            idea = json.loads(line[len("LIBRARY "):])
            found.setdefault(idea["language"], {}).setdefault(idea["topic"], []).append(idea)
        elif line.startswith("LIBRARYCOST"):
            match = re.search(r"USD ([0-9.]+)", line)
            dollars += float(match.group(1)) if match else 0
    RAW.mkdir(parents=True, exist_ok=True)
    for language, topics in sorted(found.items()):
        path = RAW / f"{language}.jsonl"
        kept = [json.loads(row) for row in path.read_text(encoding="utf-8").splitlines() if row.strip()] if path.exists() else []
        kept = [idea for idea in kept if idea["topic"] not in topics]
        for ideas in topics.values():
            kept += ideas
        path.write_text("".join(json.dumps(idea, ensure_ascii=False) + "\n" for idea in kept), encoding="utf-8")
        print(f"{language}: {sum(len(v) for v in topics.values())} new, {len(kept)} in {path.relative_to(ROOT)}")
    print(f"cost in this log: USD {dollars:.2f}")


if __name__ == "__main__":
    main()
