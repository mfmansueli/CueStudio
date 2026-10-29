"""Clean Slate, a minimal pulse for tutorials and tech: a marimba with soft mallets turning steady eighths low in its range, an upright bass, a soft kick and a shaker,
a vibraphone placing long notes, a few high piano notes and a low string pad in the second part. No melody to follow, nothing that
pushes. A major, 110 BPM, under speech (the pulse soft and below the voice, the top darkened)."""
from __future__ import annotations

from typing import List

import instruments as I
from score import Chord, Grid, Part, bass_key, phrase, voice
from track import Mix, Stem, Track

TEMPO = 110
A = ["Amaj9", "F#m9", "Dmaj9", "E6"]
B = ["Bm9", "Dmaj9", "F#m9", "Esus4"]
CHORDS = A + A * 2 + B * 2 + A * 2 + A + ["Amaj9", "Amaj9"]
SECTIONS = ["intro"] * 4 + ["a"] * 8 + ["b"] * 8 + ["a2"] * 8 + ["outro"] * 4 + ["end"] * 2
BARS = len(CHORDS)
# The marimba's turn on each chord's three notes, low to high, in eighths.
TURN = [0, 2, 1, 2, 0, 2, 1, 2]


def make() -> Track:
    grid = Grid(TEMPO, start=0.05)
    chords = [Chord.parse(symbol) for symbol in CHORDS]
    end = BARS - 2

    marimba = Part(grid, 901, drift_ms=3, jitter_ms=2, spread=0.05, accent=0.1)
    shape: List[int] = []
    for bar in range(end):
        shape = sorted(voice(chords[bar], 50, 65, shape or None, count=3))
        level = (0.36 if SECTIONS[bar] in ("intro", "outro") else 0.42) * phrase(bar, 4, 0.06)
        for step, index in enumerate(TURN):
            marimba.play(bar, step * 0.5, shape[index], level * (1.08 if step % 4 == 0 else 0.95), 0.45)
    marimba.chord(end, 0, [52, 57, 61, 64], 0.4, 3)

    bass = Part(grid, 902, drift_ms=3, jitter_ms=2, spread=0.05)
    kit = Part(grid, 903, drift_ms=1.5, jitter_ms=1.5, spread=0.06)
    shaker = Part(grid, 904, drift_ms=1, jitter_ms=2, spread=0.1)
    for bar in range(4, end):
        part = SECTIONS[bar]
        root = bass_key(chords[bar], 33)
        bass.play(bar, 0, root, 0.56, 1.4)
        bass.play(bar, 1.5, root, 0.4, 0.5)
        bass.play(bar, 2.5, root + 7 if root + 7 <= 47 else root - 5, 0.46, 1.2)
        if part == "outro":
            continue
        kit.steps(bar, "x... .... x... ....", 36, 0.5)
        if part in ("b", "a2"):
            kit.steps(bar, ".... .... .... x...", 40, 0.32)
        shaker.steps(bar, "xgxg xgxg xgxg xgxg", 70, 0.3)
    bass.play(end, 0, 33, 0.5, 6)
    kit.play(end, 0, 36, 0.45, 1)

    vibes = Part(grid, 905, drift_ms=8, jitter_ms=5, spread=0.06)
    piano = Part(grid, 906, drift_ms=8, jitter_ms=5, spread=0.05)
    cellos = Part(grid, 907, drift_ms=8, jitter_ms=5, spread=0.04)
    pads: List[int] = []
    for bar in range(4, end):
        part = SECTIONS[bar]
        tones = sorted(voice(chords[bar], 69, 81, None, count=3))
        if bar % 2 == 0 and part != "outro":
            vibes.play(bar, 0.5, tones[-1], 0.34, 4)
        if part == "b" and bar % 2 == 1:
            for beat, index in ((1, 2), (1.5, 1), (3, 0)):
                piano.play(bar, beat, tones[index] + 12, 0.24, 2)
        if part == "b":
            pads = voice(chords[bar], 45, 60, pads or None, count=3)
            cellos.chord(bar, 0, pads, 0.32, 4.1)
    vibes.play(end, 0.5, 76, 0.32, 6)

    seconds = grid.time(end) + 4.0
    mix = Mix(room_seconds=1.6, room_brightness=0.35, room_return_db=-6.0, speech_dip_db=3.0, warmth=1.1)
    stems = [
        Stem("marimba", I.marimba(), marimba.notes, gain_db=0, eq=(("highpass", 100), ("lowpass", 1300, 0.7), ("lowpass", 1300, 0.7)),
             send=0.18, width=1.1),
        Stem("bass", I.strings("Solo Contrabass", "Pizz", release=0.25), bass.notes, gain_db=-1, eq=(("highpass", 32), ("lowshelf", 90, 0.7, 2.0),
             ("peak", 700, 1.0, -2.5)), send=0.05, compress=(-22, 3.0, 0.005, 0.12)),
        Stem("kit", I.brush_kit(), kit.notes, gain_db=-8, eq=(("highpass", 40), ("peak", 3500, 1.0, -3.0), ("highshelf", 7000, 0.7, -4.0)), send=0.1,
             compress=(-24, 2.0, 0.01, 0.15)),
        Stem("shaker", I.groove_percussion(), shaker.notes, gain_db=-18, pan=0.3, eq=(("highpass", 600), ("highshelf", 7000, 0.7, -6.0)), send=0.12),
        Stem("vibes", I.vibraphone(), vibes.notes, gain_db=-10, pan=-0.3, eq=(("highpass", 250), ("peak", 3000, 0.8, -3.0)), send=0.4),
        Stem("piano", I.steinway_grand(), piano.notes, gain_db=-12, pan=0.3, eq=(("highpass", 300), *I.SOFT_GRAND), send=0.45),
        Stem("cellos", I.strings("Cello Section", "susvib", release=0.8), cellos.notes, gain_db=-11, eq=(("highpass", 60), ("lowpass", 2500, 0.7)),
             send=0.35),
    ]
    beats = [grid.time(bar) for bar in range(BARS)]
    return Track("cleanSlate", "Clean Slate", TEMPO, 4, BARS, seconds, stems, mix, under_speech=True, beats=beats)
