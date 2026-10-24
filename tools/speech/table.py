"""Markdown table of people's readings against the system voice, per language, from the device logs.
Usage: python3 -I table.py captions.log following.log spoken.log latency.log"""
import re, statistics, sys
from collections import defaultdict
cap, fol, spo, lat = (open(p, encoding="utf-8", errors="replace").read() for p in sys.argv[1:5])
N = r"(?P<lang>[a-z]{2}-[A-Z]{2}) (?P<name>(?:speech|human)-[A-Za-z-]+?(?:-\d)?)(?: \((?:female|male)\))?"
rows = defaultdict(dict)
def add(kind, lang, name, value):
    rows[lang].setdefault(kind, {"system": [], "people": []})["system" if name.startswith("speech") else "people"].append(value)
for m in re.finditer(r"CAPTIONS " + N + r": heard (?P<share>\d+)% .*?by letters (?P<letters>\d+)%", cap):
    share = max(int(m["share"]), int(m["letters"])) if m["lang"] in ("ja-JP", "zh-CN", "zh-TW", "th-TH", "ko-KR") else int(m["share"])
    add("cap", m["lang"], m["name"], share)
for m in re.finditer(r"VOICE FOLLOWING " + N + r": (?P<pos>\d+)/(?P<total>\d+) words", fol):
    add("fol", m["lang"], m["name"], 100 * int(m["pos"]) // int(m["total"]))
for m in re.finditer(r"SPOKEN " + N + r": found (?P<found>\S+)", spo):
    add("spo", m["lang"], m["name"], m["found"] == m["lang"])
for m in re.finditer(r"VOICE LATENCY " + N + r" selfie current · .*?word→text p50 (?P<p50>-?\d+) ms p95 (?P<p95>-?\d+) ms", lat):
    add("lat", m["lang"], m["name"], (int(m["p50"]), int(m["p95"])))
def pct(v): return f"{round(statistics.mean(v))}% (≥ {min(v)}%)" if v else "–"
print("| Language | Captions heard: system · people (worst) | Voice Following reached: system · people (worst) | Latency p50 / p95: system · people | Language spoken found: people |")
print("|---|---|---|---|---|")
for lang in sorted(rows):
    r = rows[lang]
    c = r.get("cap", {"system": [], "people": []}); f = r.get("fol", {"system": [], "people": []})
    l = r.get("lat", {"system": [], "people": []}); s = r.get("spo", {"system": [], "people": []})
    ls = f"{l['system'][0][0]} / {l['system'][0][1]} ms" if l["system"] else "–"
    lp = (f"{round(statistics.mean(x[0] for x in l['people']))} / {round(statistics.mean(x[1] for x in l['people']))} ms"
          if l["people"] else "–")
    sp = f"{sum(s['people'])} of {len(s['people'])}" if s["people"] else "not judged (dictation)"
    print(f"| {lang} | {c['system'][0] if c['system'] else '–'}% · {pct(c['people'])} | {f['system'][0] if f['system'] else '–'}% · {pct(f['people'])} | {ls} · {lp} | {sp} |")
