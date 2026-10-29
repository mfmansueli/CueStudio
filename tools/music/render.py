#!/usr/bin/env python3
"""Renders tracks of Cue's music library from their scores (tracks/*.py) on recorded instruments, mixes and masters them.

    CUE_AUDIO_SOURCES=<samples folder> venv/bin/python tools/music/render.py <track>… [--stems]

`<track>` is a module in tracks/.

Writes `<renders>/<id>.wav` (48 kHz, 24-bit), `<id>.m4a` (AAC 192 kbps, what the app ships) and `<id>.json` (tempo, beat times, loudness,
true peak, clicks, energy in the voice's band). The renders folder is `CUE_AUDIO_RENDERS` (default next to the sources). README.md has the
sources and their licences.
"""
from __future__ import annotations

import argparse
import importlib
import json
import os
import subprocess
import sys
import time

import numpy as np
import soundfile as sf

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import dsp  # noqa: E402
from sampler import RATE, render  # noqa: E402
from track import Track  # noqa: E402

# Where every stem's playing level is set before its own gain: −20 dBFS, headroom for the sum.
STEM_LEVEL = -20.0
RENDERS = os.environ.get("CUE_AUDIO_RENDERS", os.path.expanduser("~/Desktop/Projects/CueStudio-Audio/renders"))


def mixdown(track: Track, keep_stems: bool = False) -> np.ndarray:
    length = int(track.seconds * RATE) + 1
    rendered = {}
    for stem in track.stems:
        audio = render(stem.instrument, stem.notes, track.seconds)[:length]
        audio = dsp.eq(audio, *stem.eq)
        if stem.compress:
            audio = dsp.compress(audio, *stem.compress)
        active = dsp.active_level(audio)
        rendered[stem.name] = audio * (10 ** ((STEM_LEVEL - active) / 20)) if active > -120 else audio
    dry = np.zeros((length, 2), dtype=np.float32)
    send = np.zeros((length, 2), dtype=np.float32)
    for stem in track.stems:
        audio = rendered[stem.name]
        if stem.duck:
            source, depth = stem.duck
            key = rendered[source]
            level = dsp.envelope(key, 0.002, 0.12)
            reduction = np.clip(level / (np.max(level) + 1e-9), 0, 1) * depth
            audio = audio * (10 ** (-reduction / 20))[:, None]
        if stem.wow:
            audio = dsp.wow(audio, *stem.wow)
        audio = dsp.width(audio, stem.width) if stem.width != 1 else audio
        audio = dsp.pan(audio, stem.pan) if stem.pan else audio
        audio = audio * (10 ** (stem.gain_db / 20))
        dry += audio
        send += audio * stem.send
        if keep_stems:
            sf.write(os.path.join(RENDERS, f"{track.id}-{stem.name}.wav"), audio, RATE, subtype="PCM_24")
    mix = track.mix
    wet = dsp.reverb(send, dsp.room(mix.room_seconds, brightness=mix.room_brightness))
    bus = dry + wet * (10 ** (mix.room_return_db / 20))
    for texture in track.textures:
        bus[: len(texture)] += texture[: len(bus)]
    bus = dsp.compress(bus, *mix.glue)
    bands = list(mix.bus_eq)
    if mix.speech_dip_db:
        bands.append(("peak", 3000, 0.8, -mix.speech_dip_db))
    bus = dsp.eq(bus, ("highpass", 28, 0.6), *bands)
    if mix.warmth:
        bus = dsp.warmth(bus, mix.warmth)
    out = dsp.master(bus, mix.target_lufs, mix.ceiling_db)
    # The last sound fades to silence over its final 80 ms, whatever the reverb left.
    fade = int(0.08 * RATE)
    out[-fade:] *= np.linspace(1, 0, fade, dtype=np.float32)[:, None]
    return out


def measure(track: Track, audio: np.ndarray) -> dict:
    return {
        "id": track.id,
        "title": track.title,
        "tempo": track.tempo,
        "beatsPerBar": track.beats_per_bar,
        "bars": track.bars,
        "seconds": round(len(audio) / RATE, 3),
        "beats": [round(b, 4) for b in track.beats],
        "underSpeech": track.under_speech,
        "lufs": round(dsp.loudness(audio), 2),
        "truePeak": round(dsp.true_peak(audio), 2),
        "clicks": dsp.clicks(audio),
        "voiceBandShareDb": round(dsp.band_share(audio, 1000, 4000), 1),
        "lowShareDb": round(dsp.band_share(audio, 20, 150), 1),
        "monoCorrelation": round(float(np.corrcoef(audio[:, 0], audio[:, 1])[0, 1]), 3),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("tracks", nargs="+")
    parser.add_argument("--stems", action="store_true", help="also write each stem, as mixed")
    args = parser.parse_args()
    os.makedirs(RENDERS, exist_ok=True)
    for name in args.tracks:
        started = time.time()
        track: Track = importlib.import_module(f"tracks.{name}").make()
        audio = mixdown(track, args.stems)
        wav = os.path.join(RENDERS, f"{track.id}.wav")
        m4a = os.path.join(RENDERS, f"{track.id}.m4a")
        sf.write(wav, audio, RATE, subtype="PCM_24")
        subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", "-b", "192000", "-q", "127", wav, m4a], check=True)
        facts = measure(track, audio)
        facts["m4aBytes"] = os.path.getsize(m4a)
        facts["renderSeconds"] = round(time.time() - started, 1)
        with open(os.path.join(RENDERS, f"{track.id}.json"), "w") as file:
            json.dump(facts, file, indent=1)
        print(json.dumps({k: v for k, v in facts.items() if k != "beats"}))


if __name__ == "__main__":
    main()
