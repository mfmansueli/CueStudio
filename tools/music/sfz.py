"""Reads the part of an SFZ file the sampler needs: which recording plays for which keys and velocities, at what root, tuning and level,
and its round robins. Headers nest (<control> < <global> < <master> < <group> < <region>), #define and #include are followed, release
triggers and anything driven by MIDI controllers are left out (the tracks don't use them).
"""
from __future__ import annotations

import os
import re
from typing import Dict, List, Optional

from sampler import Zone, midi

HEADER = re.compile(r"<(\w+)>")
OPCODE = re.compile(r"([A-Za-z0-9_$]+)=(.*?)(?=\s+[A-Za-z0-9_$]+=|\s*<|$)")
LEVELS = ["control", "global", "master", "group", "region"]


def _key(value: str) -> int:
    value = value.strip()
    if value.lstrip("-").isdigit():
        return int(value)
    name = value[0].upper() + value[1:]
    return midi(name)


def _text(path: str, defines: Dict[str, str], seen: Optional[set] = None, base: Optional[str] = None) -> str:
    """The file with its #include files inlined (their paths are relative to the top file, as SFZ players read them) and its
    comments removed; #define values collected into `defines`."""
    seen = seen if seen is not None else set()
    base = base or os.path.dirname(path)
    if path in seen:
        return ""
    seen.add(path)
    out = []
    with open(path, encoding="utf-8", errors="replace") as file:
        for line in file:
            line = line.split("//", 1)[0].rstrip()
            define = re.match(r"\s*#define\s+(\$\w+)\s+(.*)", line)
            if define:
                defines[define.group(1)] = define.group(2).strip()
                continue
            include = re.match(r'\s*#include\s+"([^"]+)"', line)
            if include:
                out.append(_text(os.path.join(base, include.group(1)), defines, seen, base))
                rest = line[include.end():]
                if rest.strip():
                    out.append(rest)
                continue
            out.append(line)
    return "\n".join(out)


def regions(path: str) -> List[Dict[str, str]]:
    """Every region's opcodes, inherited from the headers above it, with #define values filled in."""
    defines: Dict[str, str] = {}
    text = _text(path, defines)
    for name in sorted(defines, key=len, reverse=True):
        text = text.replace(name, defines[name])
    scopes: Dict[str, Dict[str, str]] = {level: {} for level in LEVELS}
    found: List[Dict[str, str]] = []
    tokens = HEADER.split(text)
    # tokens: [before, header, body, header, body, …]
    for index in range(1, len(tokens), 2):
        header, body = tokens[index].lower(), tokens[index + 1]
        if header not in LEVELS:
            continue
        depth = LEVELS.index(header)
        for lower in LEVELS[depth:]:
            scopes[lower] = {}
        opcodes = {m.group(1): m.group(2).strip() for m in OPCODE.finditer(" ".join(body.split()))}
        scopes[header] = opcodes
        if header == "region":
            merged: Dict[str, str] = {}
            for level in LEVELS:
                merged.update(scopes[level])
            found.append(merged)
    return found


def zones(path: str, gain: float = 1.0, folder: Optional[str] = None, key: Optional[int] = None) -> List[Zone]:
    """The regions as sampler zones (release-triggered ones left out). `folder` is what sample paths are relative to (the file's own by
    default); `key` puts regions that name no key (a drum map) on that key."""
    folder = folder or os.path.dirname(path)
    out = []
    for region in regions(path):
        if region.get("trigger", "attack") != "attack" or "sample" not in region:
            continue
        if any(k.startswith(("on_locc", "on_hicc", "locc", "hicc")) for k in region):
            continue
        sample = os.path.join(folder, region.get("default_path", ""), region["sample"].replace("\\", "/"))
        if key is not None and "key" not in region and "lokey" not in region:
            low = high = root = key
        elif "key" in region:
            low = high = root = _key(region["key"])
        else:
            low, high = _key(region.get("lokey", "0")), _key(region.get("hikey", "127"))
            root = _key(region.get("pitch_keycenter", region.get("lokey", "60")))
        if "pitch_keycenter" in region:
            root = _key(region["pitch_keycenter"])
        volume = float(region.get("volume", "0") or 0)
        position = int(region.get("seq_position", "1") or 1)
        out.append(Zone(sample, root, low, high, int(region.get("lovel", "1")), int(region.get("hivel", "127")), position - 1,
                        gain * 10 ** (volume / 20), float(region.get("tune", "0") or 0), int(float(region.get("offset", "0") or 0))))
    return out
