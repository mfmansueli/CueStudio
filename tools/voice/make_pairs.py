#!/usr/bin/env python3
"""Ten anonymous pairs for the owner to judge (plan §6): the same creator and idea written by the old engine and by the new one, in a random order,
with nothing to tell them apart. The owner reads `pairs.md` and says, for each, which one sounds more like that creator; `key.json` says which
was which and is only opened afterwards.

  tools/voice/make_pairs.py <before-run> <after-run> [--out build/reports/pairs] [--seed 7] [--count 10]

A run is `Cue StudioTests/Fixtures/VoiceRuns/voice-run-<run>.json` (or the name of the run). Only scripts written with the voice on are compared.
"""

import argparse
import json
import os
import random
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RUNS = os.path.join(ROOT, "Cue StudioTests", "Fixtures", "VoiceRuns")
PERSONAS = os.path.join(ROOT, "Cue StudioTests", "Support", "VoicePersonas.swift")


def load(run):
    path = run if os.path.exists(run) else os.path.join(RUNS, f"voice-run-{run}.json")
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def summaries():
    """`id -> one line` read from the personas' source."""
    text = open(PERSONAS, encoding="utf-8").read()
    return {m.group(1): m.group(2) for m in re.finditer(r'id: "([^"]+)",\s*summary: "([^"]+)"', text)}


def index(samples):
    return {(s["persona"], s["ideaIndex"]): s for s in samples if s["condition"] == "voice" and s.get("text")}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("before")
    parser.add_argument("after")
    parser.add_argument("--out", default=os.path.join(ROOT, "build", "reports", "pairs"))
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument("--count", type=int, default=10)
    args = parser.parse_args()

    before, after = index(load(args.before)), index(load(args.after))
    shared = sorted(set(before) & set(after))
    if not shared:
        raise SystemExit("No creator and idea was written in both runs.")
    rng = random.Random(args.seed)
    # One idea for each creator first, so ten pairs are ten different creators; then any that are left.
    by_persona = {}
    for key in shared:
        by_persona.setdefault(key[0], []).append(key)
    chosen = [rng.choice(keys) for keys in by_persona.values()]
    rng.shuffle(chosen)
    rest = [key for key in shared if key not in chosen]
    rng.shuffle(rest)
    chosen = (chosen + rest)[: args.count]

    names = summaries()
    os.makedirs(args.out, exist_ok=True)
    key_file, lines = [], ["# Which one sounds more like this creator?", "",
                           "For each pair, read both and say A or B (or “same”). Don't open `key.json` until you've answered all of them.", ""]
    for number, (persona, idea) in enumerate(chosen, 1):
        old, new = before[(persona, idea)], after[(persona, idea)]
        swapped = rng.random() < 0.5
        first, second = (new, old) if swapped else (old, new)
        key_file.append({"pair": number, "persona": persona, "idea": old["idea"], "A": "after" if swapped else "before", "B": "before" if swapped else "after"})
        lines += [f"## {number}. {names.get(persona, persona)}", "", f"**The idea:** {old['idea']}", "",
                  "### A", "", f"*{first.get('title') or ''}*", "", first["text"], "",
                  "### B", "", f"*{second.get('title') or ''}*", "", second["text"], "", "---", ""]
    with open(os.path.join(args.out, "pairs.md"), "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))
    with open(os.path.join(args.out, "key.json"), "w", encoding="utf-8") as handle:
        json.dump(key_file, handle, indent=2, ensure_ascii=False)
    print(f"{len(chosen)} pairs in {args.out}/pairs.md (key: key.json)")


if __name__ == "__main__":
    main()
