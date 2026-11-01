#!/usr/bin/env python3
"""How many words a minute each of Cue's languages is spoken at, as a share of English's (ReadTime.pace(for:)).

    python3 tools/pace/measure.py            (prints the table and writes research_notes/Pace/pace.json)

Two measures, which should agree on the direction:
- FLEURS: the words a second of the four people a language read aloud in Cue StudioTests/Fixtures/Speech/Human, with the silence at the start and
  the end trimmed (ffmpeg silencedetect, -35 dB, 0.25 s);
- the catalog: the words each language needs for what English says, over the app's translated sentences of eight words or more
  (Localizable.xcstrings, no placeholders).
Words are counted as ReadTime counts them (spaces; the system dictionary for Japanese, Chinese and Thai), by tools/pace/count.swift.
The pace kept is their geometric mean, brought a quarter of the way back to 1, to the nearest 0.05; 1 when it is within 7% of 1 or when the two
measures point opposite ways (one above 1, the other at or below it: then neither is trusted).
"""
import json
import math
import os
import re
import statistics
import subprocess
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HUMAN = os.path.join(ROOT, "Cue StudioTests", "Fixtures", "Speech", "Human")
CATALOG = os.path.join(ROOT, "Cue Studio", "SupportFiles", "Localizable.xcstrings")
CATALOG_KEY = {"pt-BR": "pt", "zh-CN": "zh-Hans", "zh-TW": "zh-Hant"}


def speech_seconds(path, total):
    out = subprocess.run(["ffmpeg", "-hide_banner", "-i", path, "-af", "silencedetect=noise=-35dB:d=0.25", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    starts = [float(x) for x in re.findall(r"silence_start: ([\d.]+)", out)]
    ends = [float(x) for x in re.findall(r"silence_end: ([\d.]+)", out)]
    lead = ends[0] if starts and starts[0] < 0.05 and ends else 0
    trail = total - starts[-1] if starts and (len(ends) < len(starts) or ends[-1] >= total - 0.05) else 0
    return max(0.5, total - lead - trail)


def main():
    with tempfile.TemporaryDirectory() as folder:
        counts = os.path.join(folder, "counts.json")
        subprocess.run(["swift", os.path.join(ROOT, "tools", "pace", "count.swift"), CATALOG, os.path.join(HUMAN, "human-speech.json"), counts],
                       check=True, capture_output=True)
        data = json.load(open(counts))
    rates = {}
    for clip in data["clips"]:
        seconds = speech_seconds(os.path.join(HUMAN, clip["file"] + ".m4a"), float(clip["seconds"]))
        rates.setdefault(clip["language"], []).append(clip["words"] / seconds)
    english = statistics.mean(rates["en-US"])
    result = {}
    print(f"{'language':9} {'FLEURS':>7} {'catalog':>8} {'pace':>5}")
    for language, values in sorted(rates.items()):
        fleurs = statistics.mean(values) / english
        catalog = 1.0 if language == "en-US" else data["catalog"].get(CATALOG_KEY.get(language, language.split("-")[0]), {}).get("ratio", 1.0)
        mean = math.sqrt(fleurs * catalog)
        pace = round((1 + 0.75 * (mean - 1)) * 20) / 20
        if abs(pace - 1) < 0.07 or (fleurs > 1) != (catalog > 1):
            pace = 1.0
        result[language] = {"fleurs": round(fleurs, 3), "catalog": round(catalog, 3), "pace": pace}
        print(f"{language:9} {fleurs:7.2f} {catalog:8.2f} {pace:5.2f}")
    os.makedirs(os.path.join(ROOT, "research_notes", "Pace"), exist_ok=True)
    json.dump(result, open(os.path.join(ROOT, "research_notes", "Pace", "pace.json"), "w"), indent=1, sort_keys=True)


if __name__ == "__main__":
    main()
