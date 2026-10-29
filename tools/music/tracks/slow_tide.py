"""Slow Tide, ambient for stories and calm moments: string sections breathing in and out on long chords, a harp turning slow arpeggios,
a vibraphone placing single notes into a long room, and a grand piano's high notes now and then. No drums, no texture. D major, 70 BPM,
under speech (everything soft and low, the strings darkened above 2.5–3 kHz, nothing held in the voice's band)."""
from __future__ import annotations

from typing import List

import instruments as I
from score import Chord, Grid, Part, bass_key, voice
from track import Mix, Stem, Track

TEMPO = 70
# Two bars per chord.
PROGRESSION = ["Dmaj9", "Bm9", "Gmaj9", "Aadd9", "Dmaj9", "F#m7", "Gmaj9", "Asus4", "Em9", "Gmaj9", "Bm9", "Aadd9", "Gmaj9"]
CHORDS = [symbol for symbol in PROGRESSION for _ in range(2)] + ["Dmaj9", "Dmaj9"]
BARS = len(CHORDS)
SECTIONS = ["intro"] * 4 + ["a"] * 8 + ["b"] * 10 + ["outro"] * 4 + ["end"] * 2


def make() -> Track:
    grid = Grid(TEMPO, start=0.1)
    chords = [Chord.parse(symbol) for symbol in CHORDS]

    cellos = Part(grid, 501, drift_ms=8, jitter_ms=6, spread=0.04, accent=0.05)
    violas = Part(grid, 502, drift_ms=8, jitter_ms=6, spread=0.04, accent=0.05)
    violins = Part(grid, 503, drift_ms=8, jitter_ms=6, spread=0.04, accent=0.05)
    bass = Part(grid, 504, drift_ms=6, jitter_ms=4, spread=0.04)
    pads: List[int] = []
    high: List[int] = []
    for bar in range(0, BARS - 2, 2):
        chord, part = chords[bar], SECTIONS[bar]
        pads = voice(chord, 45, 62, pads or None, count=3)
        swell = {"intro": 0.3, "a": 0.36, "b": 0.4, "outro": 0.32}[part]
        cellos.play(bar, 0, pads[0], swell, 8.2)
        violas.chord(bar, 0.5, pads[1:], swell * 0.9, 7.7)
        root = bass_key(chord, 30)
        if part != "intro":
            bass.play(bar, 0, root, 0.4, 8.2)
        if part == "b":
            high = voice(chord, 69, 81, high or None, count=2)
            violins.chord(bar, 1, high, 0.3, 7)
    end = BARS - 2
    cellos.play(end, 0, 50, 0.3, 9)
    violas.chord(end, 0, [57, 61, 64], 0.28, 9)
    bass.play(end, 0, 38, 0.36, 9)

    harp = Part(grid, 505, drift_ms=6, jitter_ms=5, spread=0.07)
    for bar in range(4, BARS - 2):
        if SECTIONS[bar] == "outro" and bar % 2:
            continue
        notes = sorted(voice(chords[bar], 50, 76, None, count=5))
        for step, key in enumerate(notes + notes[-2:0:-1]):
            if step * 0.5 < 4:
                harp.play(bar, step * 0.5, key, 0.32 if step else 0.38, 3)
    for step, key in enumerate(sorted(voice(chords[end], 50, 81, None, count=6))):
        harp.play(end, step * 0.33, key, 0.34, 8)

    vibes = Part(grid, 506, drift_ms=10, jitter_ms=6, spread=0.06)
    for bar in range(12, 22, 2):
        tones = sorted(voice(chords[bar], 67, 81, None, count=3))
        vibes.play(bar, 1, tones[-1], 0.34, 6)
        vibes.play(bar + 1, 0.5, tones[0], 0.3, 6)

    piano = Part(grid, 507, drift_ms=12, jitter_ms=6, spread=0.05)
    for bar in (8, 14, 20, 24):
        piano.play(bar, 2, sorted(voice(chords[bar], 74, 86, None, count=2))[-1], 0.24, 6)
    piano.play(end, 1.5, 81, 0.22, 9)

    seconds = grid.time(BARS) + 5.0
    mix = Mix(room_seconds=3.5, room_brightness=0.3, room_return_db=-4.0, speech_dip_db=3.0, warmth=1.2)
    stems = [
        Stem("cellos", I.strings("Cello Section", "susvib", release=1.2), cellos.notes, gain_db=-3, pan=0.2, eq=(("highpass", 55), ("peak", 2500, 0.8, -3.0), ("highshelf", 3000, 0.7, -6.0)),
             send=0.4),
        Stem("violas", I.strings("Viola Section", "susvib", release=1.2), violas.notes, gain_db=-7, pan=-0.2, eq=(("highpass", 110), ("peak", 2800, 0.8, -3.5), ("lowpass", 2600, 0.7)),
             send=0.45),
        Stem("violins", I.strings("Violin Section", "susVib", release=1.4), violins.notes, gain_db=-12, pan=-0.3, eq=(("highpass", 250), ("peak", 3000, 0.8, -4.0),
             ("lowpass", 3000, 0.7)), send=0.5),
        Stem("bass", I.strings("Solo Contrabass", "SusNV", release=1.0), bass.notes, gain_db=-3, eq=(("highpass", 30), ("lowpass", 1500)), send=0.25),
        Stem("harp", I.harp(), harp.notes, gain_db=-4, pan=0.25, eq=(("highpass", 90), ("highshelf", 6000, 0.7, -3.0)), send=0.4),
        Stem("vibes", I.vibraphone(), vibes.notes, gain_db=-11, pan=-0.3, eq=(("highpass", 250),), send=0.55),
        Stem("piano", I.steinway_grand(), piano.notes, gain_db=-13, pan=0.3, eq=(("highpass", 300), ("highshelf", 6000, 0.7, -3.0), *I.SOFT_GRAND), send=0.55),
    ]
    beats = [grid.time(bar) for bar in range(BARS)]
    return Track("slowTide", "Slow Tide", TEMPO, 4, BARS, seconds, stems, mix, under_speech=True, beats=beats)
