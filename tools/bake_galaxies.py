#!/usr/bin/env python3
"""Extracts the galaxies of the 1.3 board (the creator's "YOU" galaxy and the five platform galaxies) into the resource the app draws them from
(Cue Studio/DesignSystem/Motion/Data/galaxies.json). The board generates the stars with a seeded random generator and writes them into the SVG;
reading them back gives the exact same galaxy, every time:

    python3 tools/bake_galaxies.py
"""
import json, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "design/cue-v30/handoff-telas/screens/1.3_voyage.html")
DST = os.path.join(ROOT, "Cue Studio/DesignSystem/Motion/Data/galaxies.json")

NUM = r"-?(?:\d+\.?\d*|\.\d+)"

def points(d):
    return [[float(a), float(b)] for a, b in re.findall(r"[ML]\s*(" + NUM + r")\s+(" + NUM + r")", d)]

def paths(chunk):
    out = []
    for m in re.finditer(r"<path\b([^>]*)>", chunk):
        a = m.group(1)
        d = re.search(r'\bd="([^"]*)"', a)
        if not d or not d.group(1).startswith("M"):
            continue
        w = re.search(r'stroke-width="([^"]*)"', a)
        o = re.search(r'(?<![-\w])opacity="([^"]*)"', a)
        so = re.search(r'stroke-opacity="([^"]*)"', a)
        s = re.search(r'stroke="([^"]*)"', a)
        b = re.search(r'filter="url\(#(\w+)\)"', a)
        out.append({"points": points(d.group(1)), "width": float(w.group(1)) if w else 1.0,
                    "opacity": float(o.group(1)) if o else (float(so.group(1)) if so else 1.0),
                    "stroke": s.group(1) if s else None, "blurred": b is not None})
    return out

def stars(chunk):
    return [[float(x), float(y), float(r), f, float(o)] for x, y, r, f, o in
            re.findall(r'<circle cx="(' + NUM + r')" cy="(' + NUM + r')" r="(' + NUM + r')" fill="([^"]*)" opacity="([^"]*)"', chunk)]

def gradient_rgb(text, gid):
    m = re.search(r'<radialGradient id="' + gid + r'"[^>]*>(.*?)</radialGradient>', text, re.S)
    if not m:
        return None
    c = re.findall(r'stop-color="rgb\((\d+),(\d+),(\d+)\)"', m.group(1))
    return [int(v) for v in c[0]] if c else None

def main():
    t = open(SRC, encoding="utf-8").read()
    body = t[t.find("<body"):]
    first_svg = body.find("<svg")
    hero_svg = body.find('<svg width="360" height="360"')
    social = body[first_svg:hero_svg]
    out = {"socials": {}, "hero": {}}
    names = {(147, 257): "reels", (212, 330): "youtube", (324, 418): "shorts", (64, 352): "linkedin", (298, 296): "tiktok"}
    for m in re.finditer(r'<g transform="translate\(([\d.]+) ([\d.]+)\) rotate\((-?[\d.]+)\) scale\(1 ([\d.]+)\)">', social):
        cx, cy = float(m.group(1)), float(m.group(2))
        name = names.get((round(cx), round(cy)))
        if not name:
            continue
        end = social.find("</g></g>", m.end())
        chunk = social[m.end():end + 8]
        glow = re.search(r'<circle r="([\d.]+)" fill="url\(#(\w+)\)"', chunk)
        core = re.findall(r'<circle r="([\d.]+)" fill="url\(#(\w+)\)"', chunk)[-1]
        dur = re.search(r'dur="([\d.]+)s"', chunk)
        arms = paths(chunk)
        arm_id = re.search(r'stroke="url\(#(\w+)\)"', chunk).group(1)
        arm_r = re.search(r'<radialGradient id="' + arm_id + r'"[^>]* r="([\d.]+)"', social)
        out["socials"][name] = {
            "center": [cx, cy], "rotation": float(m.group(3)), "squash": float(m.group(4)),
            "glowRadius": float(glow.group(1)), "coreRadius": float(core[0]), "armRadius": float(arm_r.group(1)) if arm_r else 30.0,
            "rgb": gradient_rgb(social, arm_id), "spin": float(dur.group(1)) if dur else 55.0,
            "arms": arms, "stars": stars(chunk),
        }
    hero = body[hero_svg:]
    rot = hero.find('<animateTransform attributeName="transform" type="rotate" from="0" to="360" dur="140s"')
    stars_end = hero.find('<circle r="60" fill="url(#hbu)"/>')
    disc = hero[rot:stars_end]
    out["hero"] = {"arms": paths(disc), "stars": stars(disc)}
    os.makedirs(os.path.dirname(DST), exist_ok=True)
    json.dump(out, open(DST, "w"), separators=(",", ":"))
    print({k: (len(v["stars"]), len(v["arms"])) for k, v in out["socials"].items()}, "hero", len(out["hero"]["stars"]), len(out["hero"]["arms"]),
          os.path.getsize(DST) // 1024, "KB")

if __name__ == "__main__":
    main()
