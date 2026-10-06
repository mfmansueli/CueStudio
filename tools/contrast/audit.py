#!/usr/bin/env python3
"""Measures the contrast of every text on screen, on the pictures the UI tests write.

For each `<name>.png` with a `<name>.txt` beside it (the accessibility hierarchy: `XCUIApplication.debugDescription`) it reads where each
StaticText / Button / TextField is, crops that rectangle from the picture, takes the median color as its background and the most different pixels
as its text, and prints the WCAG 2.2 contrast ratio. Normal text needs 4.5:1; text of 18 pt or more (or 14 pt bold) needs 3:1.

    python3 tools/contrast/audit.py <folder> [--min 4.5] [--scale 3] [--all]

The rectangle of a button includes its fill, and a rectangle over a photo or video has no single background: read the list as leads, then
look at the picture. A rectangle whose pixels are all one color has no text drawn in it (it is behind a cover, under a sheet, or scrolled away,
but the accessibility tree still lists it): it is skipped and counted as "not visible", never as a failure. Needs Pillow (`pip3 install pillow`).
"""
import argparse
import os
import re
import sys
from collections import defaultdict

from PIL import Image

LINE = re.compile(r"(StaticText|Button|TextField|SecureTextField|TextView|Link),\s*0x[0-9a-f]+,\s*\{\{(-?[\d.]+),\s*(-?[\d.]+)\},\s*\{([\d.]+),\s*([\d.]+)\}\}(.*)")
LABEL = re.compile(r"label:\s*'((?:[^'\\]|\\.)*)'")
IDENT = re.compile(r"identifier:\s*'([^']*)'")


def linear(channel):
    channel /= 255
    return channel / 12.92 if channel <= 0.03928 else ((channel + 0.055) / 1.055) ** 2.4


def luminance(rgb):
    return 0.2126 * linear(rgb[0]) + 0.7152 * linear(rgb[1]) + 0.0722 * linear(rgb[2])


def ratio(first, second):
    high, low = sorted((luminance(first), luminance(second)), reverse=True)
    return (high + 0.05) / (low + 0.05)


UNIFORM = 6


def median(values):
    ordered = sorted(values)
    return ordered[len(ordered) // 2]


def measure(image, box):
    crop = image.crop(box).convert("RGB")
    pixels = list(crop.getdata())
    if len(pixels) < 12:
        return None
    background = tuple(median([p[i] for p in pixels]) for i in range(3))
    bg_lum = luminance(background)
    by_distance = sorted(pixels, key=lambda p: abs(luminance(p) - bg_lum), reverse=True)
    take = max(6, len(pixels) // 40)
    strongest = by_distance[:take]
    text = tuple(sum(p[i] for p in strongest) // len(strongest) for i in range(3))
    # Every pixel the same color (give or take compression): nothing is drawn in this rectangle.
    drawn = max(max(abs(a - b) for a, b in zip(p, background)) for p in strongest) > UNIFORM
    return background, text, ratio(background, text), drawn


def hexcolor(rgb):
    return "#%02X%02X%02X" % rgb


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("folder")
    parser.add_argument("--min", type=float, default=4.5)
    parser.add_argument("--scale", type=float, default=0, help="pixels per point (default: picture width / 390)")
    parser.add_argument("--all", action="store_true", help="list passing texts too")
    args = parser.parse_args()
    found = defaultdict(list)
    count = 0
    hidden = 0
    for name in sorted(os.listdir(args.folder)):
        if not name.endswith(".png"):
            continue
        txt = os.path.join(args.folder, name[:-4] + ".txt")
        if not os.path.exists(txt):
            continue
        image = Image.open(os.path.join(args.folder, name))
        scale = args.scale or image.width / 390
        seen = set()
        for line in open(txt, encoding="utf-8"):
            match = LINE.search(line)
            if not match:
                continue
            kind, x, y, w, h, rest = match.groups()
            label = LABEL.search(rest)
            if not label or not label.group(1).strip():
                continue
            text = label.group(1)
            x, y, w, h = float(x), float(y), float(w), float(h)
            if w < 8 or h < 8 or x + w < 0 or y + h < 0 or x > image.width / scale or y > image.height / scale:
                continue
            key = (kind, text, round(x), round(y))
            if key in seen:
                continue
            seen.add(key)
            box = (max(0, int(x * scale)), max(0, int(y * scale)), min(image.width, int((x + w) * scale)), min(image.height, int((y + h) * scale)))
            result = measure(image, box)
            if not result:
                continue
            background, fg, value, drawn = result
            if not drawn:
                hidden += 1
                continue
            # 18 pt or more is large text: one line about 22 pt tall or more.
            large = h >= 22 and len(text) <= 40 and w / max(1, len(text)) > 9
            needed = 3.0 if large else args.min
            count += 1
            if args.all or value < needed:
                ident = IDENT.search(rest)
                found[(text, kind)].append((value, needed, name, hexcolor(background), hexcolor(fg), (round(w), round(h)), ident.group(1) if ident else ""))
    rows = sorted(((min(v)[0], key, v) for key, v in found.items()), key=lambda r: r[0])
    for value, (text, kind), items in rows:
        worst = min(items)
        print(f"{value:5.2f}:1 (needs {worst[1]})  {kind:10} '{text[:60]}'  bg {worst[3]} text {worst[4]}  {worst[5]}  {worst[6]}  x{len(items)}  {worst[2]}")
    print(f"\n{count} texts measured, {hidden} not visible (skipped)" + ("" if args.all else f", {len(rows)} under the minimum"))


if __name__ == "__main__":
    sys.exit(main())
