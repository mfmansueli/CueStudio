#!/usr/bin/env python3
"""cmp.py <out.png> <html1.png> <app1.png> [<html2> <app2> ...]: the board's picture (top) over the app's (bottom), one column per pair."""
import sys

from PIL import Image

out = sys.argv[1]
pairs = list(zip(sys.argv[2::2], sys.argv[3::2]))
width, height = 260, 563
sheet = Image.new("RGB", (len(pairs) * (width + 6), height * 2 + 6), (50, 50, 50))
for index, (board, app) in enumerate(pairs):
    sheet.paste(Image.open(board).convert("RGB").resize((width, height)), (index * (width + 6), 0))
    sheet.paste(Image.open(app).convert("RGB").resize((width, height)), (index * (width + 6), height + 6))
sheet.save(out)
