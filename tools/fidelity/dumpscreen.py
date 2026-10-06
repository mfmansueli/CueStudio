#!/usr/bin/env python3
"""dumpscreen.py <screen.html> [maxstyle]: a readable list of the animated layers of one screen, from `motion/screens-motion.json`."""
import json, os, re, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
data = json.load(open(os.path.join(ROOT, "design/cue-v30/handoff-telas/motion/screens-motion.json")))
name = sys.argv[1]
limit = int(sys.argv[2]) if len(sys.argv) > 2 else 200
for layer in data["screens"][name]["layers"]:
    box = layer.get("box") or {}
    place = " ".join(f"{key[0]}{value}" for key, value in box.items())
    style = re.sub(r"\s+", " ", layer.get("style", ""))[:limit]
    animations = []
    for animation in layer.get("animations", []):
        easing = animation["easing"] if isinstance(animation["easing"], str) else ",".join(str(x) for x in animation["easing"])
        animations.append(f"{animation['name']} {animation.get('duration')}s d{animation.get('delay')} [{easing}] {animation.get('iteration')[:3]}")
    text = layer.get("text")
    label = f'"{text[:40]}" ' if text else ""
    print(f"{layer['id']} <{layer['tag']}> {label}{place} | {style} || {' + '.join(animations)}")
