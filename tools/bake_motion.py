#!/usr/bin/env python3
"""Bakes design/cue-v30/handoff-telas/motion/screens-motion.json into the numeric resource the app reads
(Cue Studio/DesignSystem/Motion/Data/screens-motion.json, decoded by `MotionClip`).

What it does: keeps only the animated layers of each screen (id + animations), resolves the CSS variables of the
spark-style transforms (`rotate(var(--a)) translateX(var(--d)) scale(.3)`) into numeric channels per layer, and turns the
`raw` CSS fields the boards use (text-shadow / box-shadow glows, filter brightness, clip-path reveals, offset-distance,
top, border-radius, background-position) into numeric channels. Run it again whenever the design's JSON changes:

    python3 tools/bake_motion.py
"""
import json, math, re, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "design/cue-v30/handoff-telas/motion/screens-motion.json")
DST = os.path.join(ROOT, "Cue Studio/DesignSystem/Motion/Data/screens-motion.json")

NUM = r"-?(?:\d+\.?\d*|\.\d+)"

def num(s):
    return float(s)

def css_vars(style):
    """`--a:50deg;--d:20px` -> {'a': 50.0, 'd': 20.0} (units dropped)."""
    out = {}
    for m in re.finditer(r"--([\w-]+)\s*:\s*(" + NUM + r")(?:deg|px|%|em)?", style or ""):
        out[m.group(1)] = num(m.group(2))
    return out

SCREENS = os.path.join(ROOT, "design/cue-v30/handoff-telas/screens")

def html_vars(screen_file):
    """The design's JSON cuts each layer's `style` at ~200 characters, which loses `--a` / `--d` on long styles. The HTML has them whole:
    {animation name: [vars of the 1st, 2nd... element that starts with that animation]}, in document order like the JSON's layers."""
    try:
        text = open(os.path.join(SCREENS, screen_file), encoding="utf-8").read()
    except OSError:
        return {}
    out = {}
    for m in re.finditer(r"<(?:span|div|path|circle|g|button)\b[^>]*?style=\"([^\"]*)\"", text):
        style = m.group(1)
        a = re.search(r"animation:\s*(\w+)", style)
        if a and "--" in style:
            out.setdefault(a.group(1), []).append(css_vars(style))
    return out

def resolve(token, v):
    token = token.strip()
    m = re.fullmatch(r"var\(--([\w-]+)\)", token)
    if m:
        return v.get(m.group(1), 0.0)
    m = re.fullmatch(r"calc\(var\(--([\w-]+)\)\s*\*\s*(" + NUM + r")\)", token)
    if m:
        return v.get(m.group(1), 0.0) * num(m.group(2))
    m = re.fullmatch("(" + NUM + r")(?:px|deg)?", token)
    if m:
        return num(m.group(1))
    return None

def parse_transform(t, v):
    """The transforms the boards write; returns channels (tx, ty, sx, sy, rot, tilt) or {} if unknown."""
    out = {}
    fns = re.findall(r"(\w+)\(((?:[^()]|\([^()]*\))*)\)", t)
    rot = 0.0
    x = 0.0
    y = 0.0
    sx = sy = 1.0
    for name, args in fns:
        parts = [a.strip() for a in re.split(r",(?![^()]*\))", args)]
        if name == "rotate" or name == "rotateZ":
            r = resolve(parts[0], v)
            if r is not None:
                rot = r
        elif name == "translateX":
            r = resolve(parts[0], v)
            if r is not None:
                x = r
        elif name == "translate":
            a = resolve(parts[0], v)
            b = resolve(parts[1], v) if len(parts) > 1 else 0.0
            if a is not None: x = a
            if b is not None: y = b
        elif name == "scale":
            r = resolve(parts[0], v)
            if r is not None:
                sx = sy = r
        elif name == "scaleX":
            r = resolve(parts[0], v)
            if r is not None:
                sx = r
        elif name == "rotateX":
            r = resolve(parts[0], v)
            out["tilt"] = r if r is not None else 0.0
        elif name == "translateZ":
            pass
    # rotate(a) translateX(d) = point at distance d along angle a (the spark pattern); a bare translate keeps its axes
    if any(n in ("rotate",) for n, _ in fns) and any(n == "translateX" for n, _ in fns):
        ang = math.radians(rot)
        out["tx"], out["ty"] = x * math.cos(ang), x * math.sin(ang)
        out["rot"] = rot
    else:
        out["tx"], out["ty"] = x, y
        out["rot"] = rot
    out["sx"], out["sy"] = sx, sy
    return out

RGBA = re.compile(r"rgba?\(\s*(" + NUM + r")\s*,\s*(" + NUM + r")\s*,\s*(" + NUM + r")\s*(?:,\s*(" + NUM + r")\s*)?\)")
HEX = re.compile(r"#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b")

def parse_color(s):
    m = RGBA.search(s)
    if m:
        a = float(m.group(4)) if m.group(4) is not None else 1.0
        return [float(m.group(1)), float(m.group(2)), float(m.group(3)), a]
    m = HEX.search(s)
    if m:
        h = m.group(1)
        if len(h) == 3: h = "".join(c * 2 for c in h)
        return [int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 1.0]
    return None

def parse_shadow(s):
    """First shadow of a text-shadow / box-shadow: blur radius, spread, colour. 'none' -> radius 0, alpha 0."""
    s = s.strip()
    if s == "none":
        return {"glowR": 0.0, "glow": None}
    first = re.split(r",(?![^()]*\))", s)[0]
    col = parse_color(first)
    head = re.sub(r"rgba?\([^)]*\)|#[0-9a-fA-F]{3,6}\b", "", first)
    nums = [float(n) for n in re.findall(NUM, head)]      # x y blur [spread]: the first two are written without a unit when 0
    out = {"glowR": nums[2] if len(nums) >= 3 else 0.0}
    if len(nums) >= 4 and nums[3]:
        out["glowSpread"] = nums[3]
    out["glow"] = col
    return out

def parse_raw(raw, v):
    out = {}
    for k, val in raw.items():
        if k == "transform":
            out.update(parse_transform(val, v))
        elif k == "filter":
            m = re.search(r"brightness\((" + NUM + r")\)", val)
            out["brightness"] = num(m.group(1)) if m else 1.0
            m = re.search(r"blur\((" + NUM + r")(?:px)?\)", val)
            if m:
                out["blur"] = num(m.group(1))
            elif val.strip() == "none":
                out["blur"] = 0.0   # `filter: none` ends a blur: without this the channel would hold its last blur forever
        elif k in ("text-shadow", "box-shadow"):
            out.update(parse_shadow(val))
        elif k == "clip-path":
            m = re.match(r"inset\(\s*(" + NUM + r")(px|%)?\s+(" + NUM + r")(px|%)?\s+(" + NUM + r")(px|%)?\s+(" + NUM + r")(px|%)?\s*\)", val)
            if m:
                g = m.groups()
                out["clipTop"] = num(g[0]); out["clipRight"] = num(g[2]); out["clipBottom"] = num(g[4]); out["clipLeft"] = num(g[6])
                out["clipRightPct"] = 1.0 if g[3] == "%" else 0.0
        elif k == "offset-distance":
            out["offsetDistancePct"] = num(val.strip().rstrip("%"))
        elif k == "top":
            out["topPct"] = num(val.strip().rstrip("%"))
        elif k == "border-radius":
            out["radius"] = num(val.strip().rstrip("px"))
        elif k == "background-position":
            m = re.match(r"\s*(" + NUM + r")(px|%)?", val)
            if m: out["bgX"] = num(m.group(1))
    return out

def uses_vars(frames):
    """The keyframes read a CSS variable of the layer: `var(--a)` in a transform, or an opacity written `var(--o)` (a null in the JSON)."""
    return any(("raw" in f and "var(" in json.dumps(f["raw"])) or ("opacity" in f and f["opacity"] is None) for f in frames)

def convert_frame(f, v):
    out = {k: f[k] for k in f if k not in ("raw", "easing")}
    if "opacity" in out and out["opacity"] is None:
        out["opacity"] = v.get("o", 1.0)
    if "raw" in f:
        out.update(parse_raw(f["raw"], v))
    if "easing" in f:
        out["easing"] = f["easing"]
    return out

def fix_glow(frames):
    """A `none` shadow fades from / to the neighbour's colour at alpha 0 (CSS interpolates shadows premultiplied)."""
    last = None
    for f in frames:
        if f.get("glow"):
            last = f["glow"]
    for f in frames:
        if "glowR" in f and f.get("glow") is None:
            f["glow"] = [last[0], last[1], last[2], 0.0] if last else [255, 255, 255, 0.0]
    return frames

def main():
    d = json.load(open(SRC))
    kfs = {}
    screens = {}
    for sname, sc in d["screens"].items():
        layers = {}
        from_html = html_vars(sname)
        seen = {}
        for l in sc["layers"]:
            anims = l.get("animations") or []
            if not anims:
                continue
            v = css_vars(l.get("style", ""))
            first = anims[0]["name"]
            if first in from_html:
                k = seen.get(first, 0)
                seen[first] = k + 1
                if k < len(from_html[first]):
                    v.update(from_html[first][k])
            out = []
            for a in anims:
                if a.get("duration") is None:
                    continue
                frames = d["keyframes"].get(a["kf"])
                if frames is None:
                    continue
                name = a["kf"]
                if uses_vars(frames):
                    name = f'{a["kf"]}@{sname}:{l["id"]}'
                if name not in kfs:
                    kfs[name] = fix_glow([convert_frame(f, v) for f in frames])
                out.append({"kf": name, "duration": a["duration"], "delay": a.get("delay", 0), "easing": a["easing"],
                            "loops": a.get("iteration") == "infinite"})
            if out:
                layers[l["id"]] = out
        screens[sname.replace(".html", "")] = layers
    os.makedirs(os.path.dirname(DST), exist_ok=True)
    json.dump({"keyframes": kfs, "screens": screens}, open(DST, "w"), separators=(",", ":"))
    print(f"{len(kfs)} keyframe sets, {sum(len(s) for s in screens.values())} animated layers, {os.path.getsize(DST)//1024} KB -> {DST}")

if __name__ == "__main__":
    main()
