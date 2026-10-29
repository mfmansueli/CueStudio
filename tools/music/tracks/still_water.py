"""Still Water, a slow, open ambient piece for meditation, wellness and skincare: cellos and violas breathing long chords, hand chimes
placed far apart, a kalimba turning three soft notes, a harp rising every four bars and a few high piano notes in a large room. No
drums and no noise bed. D major, 64 BPM, under speech (nothing moves fast; every high note is soft and alone)."""
from __future__ import annotations

from typing import List

import instruments as I
from score import Chord, Grid, Part, bass_key, voice
from track import Mix, Stem, Track

TEMPO = 64
A = ["Dmaj9", "Gmaj9", "Bm9", "Gmaj9"]
B = ["Em9", "A6/9", "Dmaj9", "Gmaj9"]
CHORDS = A + A + B + A + B + ["Dmaj9", "Dmaj9"]
SECTIONS = ["intro"] * 4 + ["a"] * 4 + ["b"] * 4 + ["a2"] * 4 + ["b2"] * 4 + ["end"] * 2
BARS = len(CHORDS)
# The kalimba's turn over a bar: (beat, index into the chord's notes, low to high).
TURN = [(0.5, 0), (1.5, 2), (2.5, 1)]
# The chimes: (bar of the four, beat, index into the chord's high notes).
CHIMES = [(0, 1.0, 1), (2, 2.0, 0)]


def make() -> Track:
    grid = Grid(TEMPO, start=0.05)
    chords = [Chord.parse(symbol) for symbol in CHORDS]
    end = BARS - 2

    cellos = Part(grid, 1901, drift_ms=12, jitter_ms=8, spread=0.04)
    violas = Part(grid, 1902, drift_ms=12, jitter_ms=8, spread=0.04)
    held: List[int] = []
    for bar in range(end):
        chord, part = chords[bar], SECTIONS[bar]
        held = voice(chord, 54, 69, held or None, count=3)
        level = 0.3 if part == "intro" else 0.36 if part in ("a", "a2") else 0.4
        cellos.play(bar, 0, bass_key(chord, 38), level, 4.1)
        violas.chord(bar, 0, held, level * 0.88, 4.1)
    cellos.play(end, 0, 38, 0.36, 8)
    violas.chord(end, 0, [57, 61, 64], 0.32, 8)

    kalimba = Part(grid, 1903, drift_ms=8, jitter_ms=5, spread=0.06)
    chimes = Part(grid, 1904, drift_ms=8, jitter_ms=5, spread=0.05)
    harp = Part(grid, 1905, drift_ms=4, jitter_ms=3, spread=0.05)
    piano = Part(grid, 1906, drift_ms=10, jitter_ms=6, spread=0.05)
    for bar in range(end):
        chord, part = chords[bar], SECTIONS[bar]
        if part != "intro":
            tones = sorted(voice(chord, 62, 76, None, count=3))
            for beat, index in TURN:
                kalimba.play(bar, beat, tones[index], 0.36, 2)
        high = sorted(voice(chord, 76, 88, None, count=2))
        for which, beat, index in CHIMES:
            if which == bar % 4:
                chimes.play(bar, beat, high[index], 0.3, 3)
        if bar % 4 == 0 and part != "intro":
            run = sorted(voice(chord, 50, 79, None, count=7))
            for step, key in enumerate(run):
                harp.play(bar, step * 0.5, key, 0.28 + 0.02 * step, 3)
        if part in ("b", "b2") and bar % 2 == 1:
            piano.play(bar, 2.5, sorted(voice(chord, 79, 88, None, count=2))[0], 0.24, 4)
    chimes.play(end, 0.5, 81, 0.3, 6)
    harp.chord(end, 0, [50, 57, 62, 66, 69, 74], 0.3, 6, strum=0.12)

    seconds = grid.time(end) + 7.0
    mix = Mix(room_seconds=4.0, room_brightness=0.35, room_return_db=-3.0, speech_dip_db=3.0, warmth=1.1)
    stems = [
        Stem("cellos", I.strings("Cello Section", "susvib", release=1.5), cellos.notes, gain_db=-3, pan=0.25, eq=(("highpass", 45), ("lowpass", 2000, 0.7)),
             send=0.45),
        Stem("violas", I.strings("Viola Section", "susvib", release=1.5), violas.notes, gain_db=-6, pan=-0.25, eq=(("highpass", 120), ("lowpass", 1800, 0.7),
             ("lowpass", 1800, 0.7)), send=0.5),
        Stem("kalimba", I.kalimba(), kalimba.notes, gain_db=-6, eq=(("highpass", 200), ("peak", 3000, 0.8, -4.0), ("lowpass", 5000)), send=0.4, width=1.2),
        Stem("chimes", I.hand_chimes(), chimes.notes, gain_db=-13, pan=0.3, eq=(("highpass", 300), ("highshelf", 3000, 0.7, -3.0)), send=0.6),
        Stem("harp", I.harp(), harp.notes, gain_db=-9, pan=-0.3, eq=(("highpass", 100), ("highshelf", 3000, 0.7, -4.0)), send=0.5),
        Stem("piano", I.steinway_grand(), piano.notes, gain_db=-10, pan=0.2, eq=(("highpass", 200), *I.SOFT_GRAND), send=0.6),
    ]
    beats = [grid.time(bar) for bar in range(BARS)]
    return Track("stillWater", "Still Water", TEMPO, 4, BARS, seconds, stems, mix, under_speech=True, beats=beats)
