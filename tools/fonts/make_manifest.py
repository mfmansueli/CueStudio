#!/usr/bin/env python3
"""Writes Cue Studio/SupportFiles/FontPacks.json from tools/fonts/packs.py.

    python3 -m venv /tmp/v && /tmp/v/bin/pip install fonttools
    /tmp/v/bin/python tools/fonts/make_manifest.py <download folder>

Every file is downloaded once from the pinned commit of github.com/google/fonts (kept in the download folder, which can be
deleted afterwards), opened with fontTools and checked: it must draw its script's sample, and its PostScript name, weight
(or weight axis), copyright and licence come from the file itself. The manifest records the URL, SHA-256 and size the app
checks before registering a download.
"""
import hashlib
import json
import os
import sys
import urllib.parse
import urllib.request

from fontTools.ttLib import TTFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from packs import COMMIT, FAMILIES, NAMES  # noqa: E402

SAMPLES = {
    "japanese": "こんにちはカタカナ漢字",
    "chineseSimplified": "你好世界这说话",
    "chineseTraditional": "你好世界這說話",
    "korean": "안녕하세요한글",
    "arabic": "مرحبا بالعالم",
    "devanagari": "नमस्ते दुनिया",
    "thai": "สวัสดีชาวโลก",
}
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "Cue Studio", "SupportFiles", "FontPacks.json")


def licence_of(directory):
    tree = json.load(open(os.path.join(os.path.dirname(__file__), "licences.json")))
    return tree[directory]


def main():
    cache = sys.argv[1]
    os.makedirs(cache, exist_ok=True)
    packs = []
    for directory, script, character, files in FAMILIES:
        licence = licence_of(directory)
        entries = []
        family = copyright_text = None
        for name, weight in files:
            path = f"{licence}/{directory}/{name}"
            url = f"https://raw.githubusercontent.com/google/fonts/{COMMIT}/{urllib.parse.quote(path)}"
            local = os.path.join(cache, directory + "__" + name)
            if not os.path.exists(local):
                urllib.request.urlretrieve(url, local)
            data = open(local, "rb").read()
            font = TTFont(local)
            names = font["name"]
            cmap = font.getBestCmap()
            missing = [c for c in SAMPLES[script] if not c.isspace() and ord(c) not in cmap]
            if missing:
                raise SystemExit(f"{name} lacks {''.join(missing)} of its script ({script})")
            family = names.getDebugName(16) or names.getDebugName(1)
            copyright_text = names.getDebugName(0)
            entry = {
                "file": name,
                "url": url,
                "sha256": hashlib.sha256(data).hexdigest(),
                "bytes": len(data),
                "postScriptName": names.getDebugName(6),
            }
            if "fvar" in font:
                axis = next(a for a in font["fvar"].axes if a.axisTag == "wght")
                entry["weightRange"] = [axis.minValue, axis.maxValue]
                entry["weight"] = font["OS/2"].usWeightClass
            else:
                entry["weight"] = weight or font["OS/2"].usWeightClass
            entries.append(entry)
            print(f"{directory:22} {name:38} {len(data) / 1e6:5.1f} MB  {entry['postScriptName']}")
        packs.append({
            "id": directory, "family": NAMES.get(directory, family), "script": script, "character": character, "licence": licence.upper(),
            "copyright": copyright_text, "files": entries,
        })
    manifest = {"source": f"github.com/google/fonts@{COMMIT}", "packs": packs}
    with open(OUT, "w") as out:
        json.dump(manifest, out, ensure_ascii=False, indent=1)
        out.write("\n")
    print(f"{len(packs)} families → {os.path.relpath(OUT, ROOT)}")


if __name__ == "__main__":
    main()
