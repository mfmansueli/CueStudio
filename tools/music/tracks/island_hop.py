"""Island Hop, a light tropical groove for travel, summer and food: a marimba bouncing on the off-beats, an upright bass in a
three-three-two pattern, a cajon and congas kept soft, a large shaker, a nylon guitar chopping the off-beats in the second part and a
kalimba hook. A minor and C major, 100 BPM, under speech (the marimba darkened, the hook between phrases)."""
from __future__ import annotations

from typing import List

import instruments as I
from score import Chord, Grid, Part, bass_key, phrase, voice
from track import Mix, Stem, Track

TEMPO = 100
A = ["Am7", "Fmaj7", "C", "G"]
B = ["Fmaj7", "G", "Em7", "Am7"]
CHORDS = A + A * 2 + B * 2 + A * 2 + B + ["Am7", "Am7"]
SECTIONS = ["intro"] * 4 + ["a"] * 8 + ["b"] * 8 + ["a2"] * 8 + ["outro"] * 4 + ["end"] * 2
BARS = len(CHORDS)
# The kalimba's hook over two bars: (bar of the two, beat, key).
HOOK = [(0, 0.5, 72), (0, 1.0, 76), (0, 1.75, 79), (0, 2.5, 76), (0, 3.0, 74), (1, 0.5, 72), (1, 1.0, 69), (1, 1.75, 67), (1, 2.5, 69)]


def make() -> Track:
    grid = Grid(TEMPO, swing=0.55, swing_unit=0.25, start=0.05)
    chords = [Chord.parse(symbol) for symbol in CHORDS]
    end = BARS - 2

    marimba = Part(grid, 1701, drift_ms=3, jitter_ms=2, spread=0.06, accent=0.1)
    bass = Part(grid, 1702, drift_ms=3, jitter_ms=2, spread=0.05)
    guitar = Part(grid, 1703, drift_ms=3, jitter_ms=2.5, spread=0.07)
    shape: List[int] = []
    chops: List[int] = []
    for bar in range(end):
        chord, part = chords[bar], SECTIONS[bar]
        shape = voice(chord, 57, 72, shape or None, count=3)
        level = (0.38 if part == "intro" else 0.44) * phrase(bar, 4, 0.06)
        for beat in (0.5, 1.5, 2.5, 3.5):
            marimba.chord(bar, beat, shape, level, 0.4, strum=0.004)
        if part != "intro":
            root = bass_key(chord, 33)
            bass.play(bar, 0, root, 0.6, 1.3)
            bass.play(bar, 1.5, root, 0.48, 1.2)
            bass.play(bar, 3, root + 7 if root + 7 <= 47 else root - 5, 0.5, 0.9)
        if part in ("b", "a2"):
            chops = voice(chord, 60, 74, chops or None, count=3)
            for beat in (0.5, 1.5, 2.5, 3.5):
                guitar.chord(bar, beat, chops, 0.36, 0.25, strum=0.006, up=beat in (1.5, 3.5))
    marimba.chord(end, 0, [57, 60, 64, 67], 0.44, 2)
    bass.play(end, 0, 33, 0.58, 4)

    cajon = Part(grid, 1704, drift_ms=1.5, jitter_ms=2, spread=0.08, accent=0.15)
    congas = Part(grid, 1705, drift_ms=1.5, jitter_ms=2, spread=0.1, accent=0.2)
    for bar in range(4, end):
        part = SECTIONS[bar]
        cajon.steps(bar, "x... .... x... ....", 36, 0.46)
        cajon.steps(bar, ".... x..x .... x..." if part != "outro" else ".... x... .... x...", 38, 0.32)
        cajon.steps(bar, "xgxg xgxg xgxg xgxg", 82, 0.24)
        if part in ("b", "a2"):
            congas.steps(bar, "..x. .x.. x.x. ..x.", 63, 0.36)
            congas.steps(bar, "x... ...x .... x...", 64, 0.38)
    cajon.play(end, 0, 36, 0.46, 1)

    kalimba = Part(grid, 1706, drift_ms=4, jitter_ms=2.5, spread=0.06)
    for bar in range(4, end):
        if SECTIONS[bar] in ("a", "a2") and bar % 4 in (0, 1):
            for which, beat, key in HOOK:
                if which == bar % 2:
                    kalimba.play(bar, beat, key, 0.44, 1.5)
    kalimba.play(end, 0.5, 76, 0.4, 3)
    kalimba.play(end, 1.0, 81, 0.34, 3)

    seconds = grid.time(end) + 3.5
    mix = Mix(room_seconds=1.3, room_brightness=0.45, room_return_db=-6.5, speech_dip_db=2.5, warmth=1.2)
    stems = [
        Stem("marimba", I.marimba(), marimba.notes, gain_db=0, eq=(("highpass", 120), ("peak", 2500, 0.8, -5.0), ("lowpass", 3500, 0.7)), send=0.18,
             width=1.1, duck=("cajon", 1.0)),
        Stem("bass", I.strings("Solo Contrabass", "Pizz", release=0.25), bass.notes, gain_db=-1, eq=(("highpass", 32), ("lowshelf", 90, 0.7, 2.5),
             ("peak", 700, 1.0, -2.5)), send=0.05, compress=(-22, 3.0, 0.005, 0.12), duck=("cajon", 1.5)),
        Stem("guitar", I.nylon_guitar(), guitar.notes, gain_db=-8, pan=-0.3, eq=(("highpass", 180), ("peak", 2800, 0.8, -4.0), ("lowpass", 7000)),
             send=0.15),
        Stem("cajon", I.folk_percussion(), cajon.notes, gain_db=-7, eq=(("highpass", 45), ("peak", 3000, 1.0, -3.0), ("highshelf", 7000, 0.7, -5.0)),
             send=0.1, compress=(-22, 2.5, 0.006, 0.12)),
        Stem("congas", I.orchestral_percussion(), congas.notes, gain_db=-11, pan=0.3, eq=(("highpass", 120), ("highshelf", 6000, 0.7, -4.0)), send=0.15),
        Stem("kalimba", I.kalimba(), kalimba.notes, gain_db=-6, pan=0.25, eq=(("highpass", 200), ("peak", 3000, 0.8, -4.0), ("lowpass", 6500)),
             send=0.25),
    ]
    beats = [grid.time(bar) for bar in range(BARS)]
    return Track("islandHop", "Island Hop", TEMPO, 4, BARS, seconds, stems, mix, under_speech=True, beats=beats)
