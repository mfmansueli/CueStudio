#!/usr/bin/env python3
"""Finds interface words cut short ("Manter minh…", "Tam…") in the pictures the UI tests write.

For each `<name>.png` it reads the picture's text with Vision (`tools/layout/ocr.swift`, compiled once into build/tools) and, when a
`<name>.txt` is beside it (the accessibility hierarchy, `XCUIApplication.debugDescription`, as the capture tests write it), compares it with
the labels the hierarchy says are there:

- CUT: a line on screen with "…" (or "...") whose element's label is longer, without that "…": the words were truncated.
- CUT?: a line with "…" that no longer label explains (no hierarchy, or none under it): look at the picture.
- SHORT: a label of a button or text that the picture shows only the start of (no "…" read; Vision may miss it). Leads, look at the picture.

    python3 tools/layout/truncation.py <folder> [--lang pt] [--all]

A line that is one of the app's own strings with "…" in that language ("Drafting…", "Escrevendo…") is never reported. Script titles, take names and other things the creator wrote are not told
apart from interface words: judge them on the picture (the owner's rule is about the interface).
"""
import argparse
import json
import os
import re
import subprocess
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOURCE = os.path.join(ROOT, "tools", "layout", "ocr.swift")
BINARY = os.path.join(ROOT, "build", "tools", "ocr")

ELEMENT = re.compile(r"(StaticText|Button|TextField|SecureTextField|TextView|Link|Cell|Other|Image|SegmentedControl|Switch|Tab),\s*0x[0-9a-f]+,\s*\{\{(-?[\d.]+),\s*(-?[\d.]+)\},\s*\{([\d.]+),\s*([\d.]+)\}\}(.*)")
WINDOW = re.compile(r"Window.*?\{\{(-?[\d.]+),\s*(-?[\d.]+)\},\s*\{([\d.]+),\s*([\d.]+)\}\}")
LABEL = re.compile(r"label:\s*'((?:[^'\\]|\\.)*)'")
VALUE = re.compile(r"value:\s*'((?:[^'\\]|\\.)*)'")
IDENT = re.compile(r"identifier:\s*'([^']*)'")
ELLIPSIS = re.compile(r"(…|\.\.\.|\.\.)")


def ocr_binary():
    if not os.path.exists(BINARY) or os.path.getmtime(BINARY) < os.path.getmtime(SOURCE):
        os.makedirs(os.path.dirname(BINARY), exist_ok=True)
        subprocess.run(["xcrun", "swiftc", "-O", SOURCE, "-o", BINARY], check=True)
    return BINARY


def normalize(text):
    text = unicodedata.normalize("NFKC", text).lower()
    text = text.replace("’", "'").replace("‘", "'")
    return re.sub(r"\s+", " ", text).strip()


def letters(text):
    return re.sub(r"[^\w]", "", normalize(text))


def elements(path):
    found, screen = [], None
    for line in open(path, encoding="utf-8"):
        window = WINDOW.search(line)
        if window and screen is None:
            screen = float(window.group(3))
        match = ELEMENT.search(line)
        if not match:
            continue
        kind, x, y, w, h, rest = match.groups()
        texts = [m.group(1) for m in (LABEL.search(rest), VALUE.search(rest)) if m and m.group(1).strip()]
        if not texts:
            continue
        ident = IDENT.search(rest)
        for text in texts:
            found.append({"kind": kind, "text": text.replace("\\'", "'"), "x": float(x), "y": float(y), "w": float(w), "h": float(h),
                          "id": ident.group(1) if ident else ""})
    return found, screen or 390.0


def own_ellipses(lang):
    """The app's strings in `lang` that have "…" of their own, as letters."""
    catalog = json.load(open(os.path.join(ROOT, "Cue Studio", "SupportFiles", "Localizable.xcstrings"), encoding="utf-8"))["strings"]
    found = set()
    for key, entry in catalog.items():
        unit = entry.get("localizations", {}).get(lang, {}).get("stringUnit", {})
        value = unit.get("value", key if lang == "en" else "")
        if "…" in value:
            found.add(letters(re.sub(r"%(\d\$)?[@dlfs]+", "", value)))
    return {f for f in found if f}


def overlaps(a, b):
    return not (a[0] + a[2] < b[0] or b[0] + b[2] < a[0] or a[1] + a[3] < b[1] or b[1] + b[3] < a[1])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("folder")
    parser.add_argument("--lang", default="pt", help="the app language of the pictures (a String Catalog language)")
    parser.add_argument("--all", action="store_true", help="also list SHORT leads")
    args = parser.parse_args()
    pictures = sorted(os.path.join(args.folder, n) for n in os.listdir(args.folder) if n.endswith(".png"))
    if not pictures:
        print("no pictures")
        return 1
    own = own_ellipses(args.lang)
    vision = {"pt": "pt-BR", "zh-Hans": "zh-Hans", "zh-Hant": "zh-Hant", "en": "en-US"}.get(args.lang, args.lang)
    output = subprocess.run([ocr_binary(), f"{vision},en-US", *pictures], capture_output=True, text=True, check=True).stdout
    cut = short = 0
    for line in output.splitlines():
        picture = json.loads(line)
        name = os.path.basename(picture["file"])[:-4]
        hierarchy = os.path.join(args.folder, name + ".txt")
        items, screen = elements(hierarchy) if os.path.exists(hierarchy) else ([], picture["width"] / 3)
        scale = picture["width"] / screen
        reported = set()
        for read in picture["lines"]:
            text = read["text"].strip()
            if not ELLIPSIS.search(text):
                continue
            box = (read["x"] / scale, read["y"] / scale, read["w"] / scale, read["h"] / scale)
            stem = letters(ELLIPSIS.split(text)[0])
            if len(stem) < 1 or letters(text) in own:
                continue
            match = None
            for item in items:
                if not overlaps(box, (item["x"], item["y"], item["w"], item["h"])):
                    continue
                label = letters(item["text"])
                # The label has the same "…" itself: not cut.
                if "…" in item["text"] and letters(text) == label:
                    match = None
                    break
                if label.startswith(stem[: max(1, len(stem) - 1)]) and len(label) > len(stem) + 1:
                    match = item
            key = (text, match["text"] if match else "")
            if key in reported:
                continue
            reported.add(key)
            if match:
                cut += 1
                print(f"CUT    {name}: '{text}'  ←  '{match['text']}'  [{match['kind']} {match['id']}] at {round(box[0])},{round(box[1])}")
            else:
                print(f"CUT?   {name}: '{text}' (no element under it with a longer label) at {round(box[0])},{round(box[1])}")
                cut += 1
        if not args.all:
            continue
        reads = [(r, (r["x"] / scale, r["y"] / scale, r["w"] / scale, r["h"] / scale)) for r in picture["lines"]]
        for item in items:
            if item["kind"] not in ("StaticText", "Button") or len(item["text"]) > 40 or item["w"] < 8:
                continue
            label = letters(item["text"])
            under = [letters(r["text"]) for r, box in reads if overlaps(box, (item["x"], item["y"], item["w"], item["h"]))]
            if not under or any(label in u for u in under):
                continue
            best = max(under, key=len)
            if len(best) >= 2 and label.startswith(best) and len(label) > len(best) + 1:
                short += 1
                print(f"SHORT  {name}: shows '{best}' of '{item['text']}' [{item['kind']} {item['id']}]")
    print(f"\n{len(pictures)} pictures, {cut} cut" + (f", {short} short leads" if args.all else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
