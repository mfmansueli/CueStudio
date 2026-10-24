"""Reads the device speech suites' report lines from xcodebuild logs and prints, per language, the system voice against the
people's readings (mean and worst of the four).

Usage: python3 -I collect.py <log> [<log> …]
"""
import re, statistics, sys
from collections import defaultdict

NAME = r"(?P<lang>[a-z]{2}-[A-Z]{2}) (?P<name>(?:speech|human)-[A-Za-z-]+?(?:-\d)?)(?: \((?P<who>female|male)\))?"
PATTERNS = {
    "captions": re.compile(r"CAPTIONS " + NAME + r": heard (?P<share>\d+)% of the script · (?P<words>\d+) words · (?P<est>\d+) estimated"
                           r" · first word (?P<first>[\d.]+) s \(voice at (?P<onset>[\d.]+) s\).*?by letters (?P<letters>\d+)%"
                           r" · heard “(?P<heard>.*?)”"),
    "following": re.compile(r"VOICE FOLLOWING " + NAME + r": (?P<pos>\d+)/(?P<total>\d+) words · largest jump (?P<jump>\d+)"
                            r" · backwards (?P<back>\d+) · moved in silence (?P<silence>\d+)"),
    "spoken": re.compile(r"SPOKEN " + NAME + r": found (?P<found>\S+) among .* in (?P<took>[\d.]+) s"),
    "latency": re.compile(r"VOICE LATENCY " + NAME + r" selfie (?P<tuning>\w+) · .*?onset→first move (?P<move>-?\d+ ms|never)"
                          r" · word→text p50 (?P<p50>-?\d+|–)(?: ms)? p95 (?P<p95>-?\d+|–)(?: ms)? \(n=\d+\) · reached (?P<reached>\d+)%"
                          r" · max ahead (?P<ahead>-?\d+) words · speaking before speech (?P<falsespeak>\d+)% · moved before speech (?P<early>\w+)"),
    "edit": re.compile(r"EDIT BY TEXT " + NAME + r": cut “(?P<cut>.*?)”.*?phrase gone (?P<gone>\w+) · neighbours kept (?P<kept>\w+)"),
}


def main(paths):
    rows = defaultdict(lambda: defaultdict(list))
    for path in paths:
        for line in open(path, encoding="utf-8", errors="replace"):
            for kind, pattern in PATTERNS.items():
                match = pattern.search(line)
                if match:
                    rows[kind][match["lang"]].append(match.groupdict())
    for kind, by_language in rows.items():
        print(f"\n## {kind}")
        for language in sorted(by_language):
            entries = by_language[language]
            synthetic = [e for e in entries if e["name"].startswith("speech-")]
            human = [e for e in entries if e["name"].startswith("human-")]
            print(f"{language}: system {describe(kind, synthetic)} | people {describe(kind, human)}")


def describe(kind, entries):
    if not entries:
        return "–"
    if kind == "captions":
        shares = [int(e["share"]) for e in entries]
        letters = [int(e["letters"]) for e in entries]
        late = [abs(float(e["first"]) - float(e["onset"])) for e in entries]
        return (f"heard {mean(shares)}% (worst {min(shares)}%) · letters {mean(letters)}% · first word off by up to "
                f"{max(late):.2f} s · estimated {sum(int(e['est']) for e in entries)}")
    if kind == "following":
        reached = [100 * int(e["pos"]) // max(1, int(e["total"])) for e in entries]
        return (f"reached {mean(reached)}% (worst {min(reached)}%) · jump ≤ {max(int(e['jump']) for e in entries)}"
                f" · back {sum(int(e['back']) for e in entries)} · moved in silence {sum(int(e['silence']) for e in entries)}")
    if kind == "spoken":
        right = sum(e["found"] == e["lang"] for e in entries)
        wrong = [f"{e['name']}→{e['found']}" for e in entries if e["found"] != e["lang"]]
        return f"{right}/{len(entries)} found ({max(float(e['took']) for e in entries):.1f} s max)" + (f" wrong: {wrong}" if wrong else "")
    if kind == "latency":
        p50 = [int(e["p50"]) for e in entries if e["p50"] != "–"]
        p95 = [int(e["p95"]) for e in entries if e["p95"] != "–"]
        reached = [int(e["reached"]) for e in entries]
        return (f"p50 {mean(p50)} ms · p95 {mean(p95)} ms (worst {max(p95) if p95 else '–'}) · reached {mean(reached)}%"
                f" (worst {min(reached)}%) · ahead ≤ {max(int(e['ahead']) for e in entries)}"
                f" · moved early {sum(e['early'] == 'true' for e in entries)} · tunings {sorted({e['tuning'] for e in entries})}")
    if kind == "edit":
        return f"gone {sum(e['gone'] == 'true' for e in entries)}/{len(entries)} · kept {sum(e['kept'] == 'true' for e in entries)}/{len(entries)}"
    return str(len(entries))


def mean(values):
    return round(statistics.mean(values)) if values else "–"


if __name__ == "__main__":
    main(sys.argv[1:])
