#!/usr/bin/env python3
"""Holds each result of ScriptToolsQualityDeviceTests to its tool's promise and prints a table per tool and model.

    python3 tools/script_tools/report.py [run ...]      (default: every run in research_notes/Script tools)

Checks (the same ones the script page's safety nets and ScriptToolsDeviceTests use, measured on words without cues):
- every tool: an answer came back, the cues the script had are all still there (none invented), no number the script didn't have;
- fitToTime: the speaking time (150 words a minute, as the page counts) is inside the platform's range, 10% either side counted apart;
- shorterAndDirect: fewer than 90% of the words; fixGrammar: 85–115% of the words; inMyVoice / moreHuman / lessDefensive / moreEnergy:
  changed, 60–140% of the words; strongerCTA: only the last paragraph changed; translate: changed and the cues kept;
- newHooks: three, all different, none longer than 30 words, none the opening it replaces.
"""
import glob
import json
import os
import re
import statistics
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
NOTES = os.path.join(ROOT, "research_notes", "Script tools")
CUE = re.compile(r"\[[^\]\n]*\]")
NUMBER = re.compile(r"\d+(?:[.,]\d+)?")
CJK = re.compile(r"[぀-ヿ㐀-鿿가-힯฀-๿]")


def spoken(text):
    return CUE.sub(" ", text or "")


def words(text):
    text = spoken(text)
    if CJK.search(text):
        # Japanese, Chinese, Korean, Thai: about two characters a word, as a rough measure.
        return max(1, len(re.sub(r"\s", "", text)) // 2)
    return len(re.findall(r"[\w’'-]+", text))


def cues(text):
    return sorted(CUE.findall(text or ""))


def paragraphs(text):
    return [p.strip() for p in re.split(r"\n\s*\n", text or "") if p.strip()]


def same(a, b):
    key = lambda t: re.sub(r"\W", "", spoken(t).lower())
    return key(a) == key(b)


def check(row):
    """(passed, notes) for one result."""
    notes = []
    if row.get("failure"):
        return False, [f"failed: {row['failure'][:60]}"]
    before, tool = row["before"], row["tool"]
    if tool == "newHooks":
        hooks = row.get("hooks") or []
        first = paragraphs(before)[0] if paragraphs(before) else ""
        ok = len(hooks) == 3 and len({h.lower() for h in hooks}) == 3 and all(0 < words(h) <= 30 for h in hooks)
        ok = ok and not any(same(h, first) for h in hooks)
        if not ok:
            notes.append(f"hooks {[words(h) for h in hooks]}")
        return ok, notes
    after = row.get("after") or ""
    ratio = words(after) / max(1, words(before))
    ok = True
    if tool != "translate" and cues(after) != cues(before):
        ok = False
        notes.append(f"cues {len(cues(before))}→{len(cues(after))}")
    if tool == "translate" and len(cues(after)) != len(cues(before)):
        ok = False
        notes.append(f"cues {len(cues(before))}→{len(cues(after))}")
    added = set(NUMBER.findall(spoken(after))) - set(NUMBER.findall(spoken(before)))
    if added and tool != "translate":
        notes.append(f"new numbers {sorted(added)[:3]}")
    if tool == "fitToTime":
        seconds = words(after) / 2.5
        low, high = row["range"]
        if not low <= seconds <= high:
            ok = False
            near = low * 0.9 <= seconds <= high * 1.1
            notes.append(f"{seconds:.0f}s for {low:.0f}–{high:.0f}" + (" (near)" if near else ""))
    elif tool == "shorterAndDirect":
        if ratio >= 0.9:
            ok = False
            notes.append(f"{ratio:.2f}×")
    elif tool == "fixGrammar":
        if not 0.85 <= ratio <= 1.15:
            ok = False
            notes.append(f"{ratio:.2f}×")
    elif tool in ("inMyVoice", "moreHuman", "lessDefensive", "moreEnergy"):
        if same(after, before):
            ok = False
            notes.append("unchanged")
        elif not 0.6 <= ratio <= 1.4:
            ok = False
            notes.append(f"{ratio:.2f}×")
    elif tool == "strongerCTA":
        b, a = paragraphs(before), paragraphs(after)
        if len(b) > 1 and (len(a) != len(b) or any(not same(x, y) for x, y in zip(a[:-1], b[:-1]))):
            ok = False
            notes.append("changed more than the closing")
        if a and b and same(a[-1], b[-1]):
            ok = False
            notes.append("closing unchanged")
    elif tool == "translate" and same(after, before):
        ok = False
        notes.append("unchanged")
    if row.get("parts") and row["parts"][1]:
        notes.append(f"{row['parts'][1]}/{row['parts'][0]} parts left as written")
    return ok, notes


def main():
    runs = sys.argv[1:] or [os.path.splitext(os.path.basename(p))[0] for p in sorted(glob.glob(os.path.join(NOTES, "*.jsonl")))]
    for run in runs:
        rows = [json.loads(line) for line in open(os.path.join(NOTES, f"{run}.jsonl"), encoding="utf-8") if line.strip()]
        print(f"\n=== {run}: {len(rows)} results")
        for tool in sorted({r["tool"] for r in rows}):
            for route in ("device", "cloud"):
                group = [r for r in rows if r["tool"] == tool and r["route"] == route]
                if not group:
                    continue
                results = [(r, *check(r)) for r in group]
                passed = sum(1 for _, ok, _ in results if ok)
                seconds = statistics.median(r["seconds"] for r in group)
                print(f"{tool:17} {route:6} {passed:2}/{len(group):<2} median {seconds:5.1f}s")
                for r, ok, notes in results:
                    if not ok or notes:
                        mark = "  " if ok else "✘ "
                        print(f"   {mark}{r['id']:24} {'; '.join(notes)}")


if __name__ == "__main__":
    main()
