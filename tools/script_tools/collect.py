#!/usr/bin/env python3
"""Gathers what ScriptToolsQualityDeviceTests printed (TOOLRUN lines in build/logs/test-device.log) into
research_notes/Script tools/<run>.jsonl, one line per script, kind (whole script, selection, version), tool and model; a case run again
replaces its line.

    python3 tools/script_tools/collect.py [log]
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "research_notes", "Script tools")


def key(row):
    return (row["id"], row.get("kind", "whole"), row["tool"], row["route"])


def main():
    log = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "build", "logs", "test-device.log")
    found = {}
    with open(log, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            at = line.find("TOOLRUN {")
            if at < 0:
                continue
            try:
                row = json.loads(line[at + len("TOOLRUN "):])
            except json.JSONDecodeError:
                continue
            found.setdefault(row["run"], {})[key(row)] = row
    os.makedirs(OUT, exist_ok=True)
    for run, rows in found.items():
        path = os.path.join(OUT, f"{run}.jsonl")
        kept = {}
        if os.path.exists(path):
            with open(path, encoding="utf-8") as handle:
                for line in handle:
                    if line.strip():
                        row = json.loads(line)
                        kept[key(row)] = row
        kept.update(rows)
        with open(path, "w", encoding="utf-8") as handle:
            for row in sorted(kept.values(), key=lambda r: (r.get("kind", "whole"), r["tool"], r["id"], r["route"])):
                handle.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")
        print(f"{run}: {len(rows)} new, {len(kept)} in {os.path.relpath(path, ROOT)}")


if __name__ == "__main__":
    main()
