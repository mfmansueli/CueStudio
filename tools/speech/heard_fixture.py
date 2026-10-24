"""Writes what CaptionTranscriber heard in a CaptionSpeechTests device run (its CAPTION WORDS lines) as the replay fixture
CaptionReplayTests reads: every reading's words with their times, a word sharing its time with a neighbour marked estimated.

Usage: python3 -I heard_fixture.py <device log> <fixture.json> "<device and system>"
"""
import json, re, sys

log, out, device = sys.argv[1:4]
readings = []
for line in open(log, encoding="utf-8", errors="replace"):
    m = re.search(r"CAPTION WORDS ((?:speech|human)-[a-z]{2}-[A-Z]{2}(?:-\d)?)(?: \(\w+\))?: (.*)$", line)
    if not m:
        continue
    words = [(t, float(a), float(b)) for t, a, b in re.findall(r"(\S+?)@(-?[\d.]+)–(-?[\d.]+)", m[2])]
    shares = lambda i: any(0 <= j < len(words) and words[j][1:] == words[i][1:] for j in (i - 1, i + 1))
    readings.append({"name": m[1], "words": [[t, a, b, shares(i)] for i, (t, a, b) in enumerate(words)]})
readings.sort(key=lambda r: r["name"])
json.dump({"heardOn": device, "readings": readings}, open(out, "w"), ensure_ascii=False, separators=(",", ":"))
print(len(readings), "readings")
