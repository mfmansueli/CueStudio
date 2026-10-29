#!/usr/bin/env python3
"""Copies the approved renders into the app: the library's tracks as AAC and the recorded sound effects as ALAC, with the facts the app
reads about each track (duration, tempo, beats, the sample libraries it plays).

    venv/bin/python tools/music/export_app.py [--check]

Writes `Cue Studio/SupportFiles/Sounds/Music/music-<id>.m4a` (AAC, 48 kHz stereo, 128 kbps), `Cue Studio/SupportFiles/Sounds/Effects/sfx-<id>.caf`
(ALAC, 48 kHz mono, 16-bit) and `Cue Studio/SupportFiles/Sounds/music-library.json`. File names carry a prefix because Xcode copies a
synchronized folder's resources flat into the bundle. `--check` measures what would ship and writes nothing.
"""
from __future__ import annotations

import argparse
import importlib
import json
import os
import subprocess
import sys
import tempfile
from typing import Dict, List, Tuple

import numpy as np
import soundfile as sf

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import dsp  # noqa: E402
import effects as E  # noqa: E402
from instruments import SOURCES  # noqa: E402
from render import RENDERS  # noqa: E402
from sampler import RATE  # noqa: E402

APP = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "Cue Studio", "SupportFiles", "Sounds"))
EFFECT_RENDERS = os.path.join(RENDERS, "effects")
# App track → the score (tracks/<module>.py) that plays it.
MUSIC: Dict[str, str] = {
    "morningNotes": "morning_notes",
    "lateStudy": "lofi",
    "brightSide": "bright_side",
    "firstLight": "first_light",
    "cleanSlate": "clean_slate",
    "neonOverpass": "neon_overpass",
    "tiptoeParade": "tiptoe_parade",
    "slowTide": "slow_tide",
    "wideOpen": "inspire",
    "quietHours": "quiet_hours",
    "goldenHour": "bossa",
    "cornerBooth": "corner_booth",
    "backPorch": "back_porch",
    "nightShift": "night_shift",
    "coldCase": "cold_case",
    "kindWords": "kind_words",
    "snowGlobe": "snow_globe",
    "islandHop": "island_hop",
    "fullSend": "full_send",
    "stillWater": "still_water",
}

# App effect → its render: the round-1 picks (`effects/<id>.wav`) and the round-2 picks (`effects/variants/<id>-<option>.wav`), owner, 29/10.
# Effects not listed stay synthesized by the app (swish, drop, glitch, tick, ding, buzzer, tada, sadTrombone, countdown, tickTock).
EFFECTS: Dict[str, str] = {
    "whoosh": "whoosh", "riser": "riser", "click": "click", "doubleClick": "doubleClick", "typing": "typing", "coin": "coin",
    "boom": "boom", "drumRoll": "drumRoll", "heartbeat": "heartbeat", "ping": "ping",
    "bloop": "variants/bloop-a", "pop": "variants/pop-a", "boing": "variants/boing-a", "hit": "variants/hit-a",
    "sparkle": "variants/sparkle-b", "shutter": "variants/shutter-c",
    "footsteps": "variants/footsteps-a", "rimshot": "variants/rimshot-a", "cashRegister": "variants/cashRegister-a",
    "recordScratch": "recordScratch", "sting": "sting", "gong": "gong", "slap": "slap", "clang": "clang", "dream": "dream",
    "cartoonRun": "cartoonRun", "sneaky": "sneaky", "referee": "referee", "slideWhistle": "slideWhistle", "pageTurn": "pageTurn",
    "censor": "censor",
    "fanfare": "tada",
}

# The sample libraries, by the folder they sit in under `SOURCES`, and the key the app knows them by (`SoundSource`).
LIBRARIES = {
    "VSCO-2-CE": "vsco2",
    "VCSL": "vcsl",
    "VirtuosityDrums": "virtuosityDrums",
    "SwirlyDrums": "swirlyDrums",
    "freepats": "freepatsGuitar",
}


def quarters(first: float, ending: float, tempo: float) -> List[float]:
    """Every quarter note from the first downbeat to the final chord."""
    step = 60.0 / tempo
    count = int(round((ending - first) / step))
    return [round(first + index * step, 4) for index in range(count + 1)]


def scored(module: str) -> Tuple[dict, str]:
    """A remade track's facts, from its score and its render."""
    track = importlib.import_module(f"tracks.{module}").make()
    onsets = [note.time for stem in track.stems for note in stem.notes]
    last = max(onsets)
    ending = max(time for time in track.beats if time <= last + 1e-3)
    sources = set()
    for stem in track.stems:
        for zone in stem.instrument.zones:
            relative = os.path.relpath(zone.path, SOURCES)
            sources.add(LIBRARIES[relative.split(os.sep)[0]])
    wav = os.path.join(RENDERS, f"{track.id}.wav")
    facts = {"tempo": track.tempo, "beatsPerBar": track.beats_per_bar, "beats": quarters(track.beats[0], ending, track.tempo),
             "forTalking": track.under_speech, "sources": sorted(sources)}
    return facts, wav


def encode(source: np.ndarray, target: str, codec: List[str], subtype: str) -> None:
    with tempfile.TemporaryDirectory() as folder:
        wav = os.path.join(folder, "in.wav")
        sf.write(wav, source, RATE, subtype=subtype)
        subprocess.run(["afconvert", *codec, wav, target], check=True)


def export_music(check: bool) -> Tuple[List[dict], List[str]]:
    entries, problems = [], []
    for app_id, recipe in MUSIC.items():
        facts, wav = scored(recipe)
        audio, rate = sf.read(wav, always_2d=True)
        if rate != RATE:
            problems.append(f"{app_id}: {rate} Hz")
        lufs, peak = dsp.loudness(audio), dsp.true_peak(audio)
        if abs(lufs + 16) > 0.3 or peak > -1.0:
            problems.append(f"{app_id}: {lufs:.1f} LUFS, {peak:.1f} dBTP")
        duration = len(audio) / RATE
        if facts["beats"][-1] >= duration:
            problems.append(f"{app_id}: beats past the end")
        entry = {"id": app_id, "duration": round(duration, 4), **{k: v for k, v in facts.items() if v is not None}}
        entries.append(entry)
        target = os.path.join(APP, "Music", f"music-{app_id}.m4a")
        if not check:
            encode(audio, target, ["-f", "m4af", "-d", "aac", "-b", "128000", "-q", "127", "-s", "2"], "PCM_24")
        size = os.path.getsize(target) / 1e6 if os.path.exists(target) else 0
        print(f"music {app_id:13s} {duration:6.1f} s  {lufs:6.1f} LUFS  {peak:5.1f} dBTP  {len(facts['beats']):3d} beats  {size:4.2f} MB  {','.join(facts['sources'])}")
    return entries, problems


def export_effects(check: bool) -> List[str]:
    problems = []
    for app_id, render in EFFECTS.items():
        audio, rate = sf.read(os.path.join(EFFECT_RENDERS, f"{render}.wav"), always_2d=True)
        mono = audio.mean(axis=1)
        loudest, peak = E.loudness(mono), float(np.max(np.abs(mono)))
        if rate != RATE or loudest > -13.5 or peak > 0.71 or len(mono) < 0.5 * RATE:
            problems.append(f"{app_id}: {rate} Hz, {loudest:.1f} LUFS, peak {peak:.3f}, {len(mono) / RATE:.2f} s")
        target = os.path.join(APP, "Effects", f"sfx-{app_id}.caf")
        if not check:
            encode(mono, target, ["-f", "caff", "-d", "alac"], "PCM_16")
        size = os.path.getsize(target) / 1e3 if os.path.exists(target) else 0
        print(f"effect {app_id:13s} {len(mono) / RATE:5.2f} s  {loudest:6.1f} LUFS  peak {peak:.3f}  {size:5.0f} KB")
    return problems


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if not args.check:
        os.makedirs(os.path.join(APP, "Music"), exist_ok=True)
        os.makedirs(os.path.join(APP, "Effects"), exist_ok=True)
    entries, problems = export_music(args.check)
    problems += export_effects(args.check)
    if not args.check:
        with open(os.path.join(APP, "music-library.json"), "w") as out:
            json.dump({"tracks": entries}, out, indent=1)
            out.write("\n")
    if problems:
        print("\n".join(["PROBLEMS:"] + problems))
        sys.exit(1)


if __name__ == "__main__":
    main()
