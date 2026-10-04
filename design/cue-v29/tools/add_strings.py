#!/usr/bin/env python3
"""Merge translations into a String Catalog, keeping Xcode's formatting.

usage: add_strings.py <catalog.xcstrings> <translations.json> [--check]

translations.json is {"English key": {"es": "...", "pt-BR": "...", ...}}; the English text is the key itself.
All 19 other languages must be present for every key (LOCALIZATION.md: every new text enters the 20 languages).
New keys are appended; Xcode puts them in order the next time it saves the catalog.
--check only validates the translations file.
"""
import json
import sys

LANGS = ["ar", "da", "de", "es", "fr", "hi", "id", "it", "ja", "ko", "nb", "nl", "pt-BR", "sv", "th", "tr", "vi", "zh-Hans", "zh-Hant"]


def dump(catalog):
    """Xcode's layout: ` : ` separators, 2-space indent, an empty dictionary as `{`, a blank line, `}`."""
    text = json.dumps(catalog, indent=2, ensure_ascii=False, separators=(",", " : "))
    out = []
    for line in text.split("\n"):
        bare = line.rstrip(",")
        if bare.endswith("{}"):
            indent = len(line) - len(line.lstrip())
            out += [bare[:-1], "", " " * indent + "}" + ("," if line.endswith(",") else "")]
        else:
            out.append(line)
    return "\n".join(out)


def main():
    path, source = sys.argv[1], sys.argv[2]
    entries = json.load(open(source, encoding="utf-8"))
    problems = [f"{key!r}: missing {[l for l in LANGS if l not in t]}" for key, t in entries.items() if any(l not in t for l in LANGS)]
    if problems:
        print("\n".join(problems))
        sys.exit(1)
    if "--check" in sys.argv:
        return
    catalog = json.load(open(path, encoding="utf-8"))
    strings = catalog["strings"]
    for key, translations in entries.items():
        entry = strings.setdefault(key, {})
        entry.pop("extractionState", None)
        localizations = entry.setdefault("localizations", {})
        for lang in LANGS:
            localizations[lang] = {"stringUnit": {"state": "translated", "value": translations[lang]}}
    with open(path, "w", encoding="utf-8") as f:
        f.write(dump(catalog))


if __name__ == "__main__":
    main()
