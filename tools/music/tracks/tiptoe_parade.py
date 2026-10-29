"""Tiptoe Parade, for comedy and sketches: a bassoon on the oom and pizzicato strings on the pah, a marimba tune that tiptoes in
staccato eighths, a clarinet taking the minor middle part, a glockenspiel doubling the tune when it comes back, a few claves, and a
staccato button to end on. F major, 124 BPM in two (a cartoon walk, not under speech)."""
from __future__ import annotations

from typing import Dict, List, Tuple

import instruments as I
from score import Chord, Grid, Part, voice
from track import Mix, Stem, Track

TEMPO = 124
A = ["F", "Bb", "C7", "F", "F", "Bb", "G7", "C7"]
B = ["Dm", "A7", "Dm", "G7", "C", "F/A", "G7", "C7"]
CHORDS = ["F", "C7"] + A + B + A + ["F", "F"]
SECTIONS = ["intro"] * 2 + ["a"] * 8 + ["b"] * 8 + ["a2"] * 8 + ["end"] * 2
BARS = len(CHORDS)
# The tune, bar by bar within its eight: (beat, key) in staccato eighths, with rests between.
TUNE: Dict[int, List[Tuple[float, int]]] = {
    0: [(0, 72), (0.5, 69), (1, 72), (2, 77), (2.5, 76), (3, 74)],
    1: [(0, 74), (0.5, 70), (1, 74), (2, 77), (3, 74)],
    2: [(0, 76), (0.5, 72), (1, 70), (1.5, 67), (2, 72), (3, 64)],
    3: [(0, 65), (1, 69), (2, 72), (2.5, 77)],
    4: [(0, 72), (0.5, 69), (1, 72), (2, 77), (2.5, 76), (3, 74)],
    5: [(0, 74), (0.5, 70), (1, 74), (2, 77), (3, 74)],
    6: [(0, 74), (0.5, 71), (1, 67), (2, 71), (2.5, 74), (3, 77)],
    7: [(0, 76), (1, 72), (1.5, 70), (2, 67), (3, 64), (3.5, 67)],
}
MIDDLE: Dict[int, List[Tuple[float, int]]] = {
    0: [(0, 69), (0.5, 74), (1, 77), (2, 76), (3, 74)],
    1: [(0, 73), (0.5, 76), (1, 79), (2, 77), (3, 76)],
    2: [(0, 74), (1, 69), (2, 65), (3, 62)],
    3: [(0, 71), (0.5, 74), (1, 77), (2, 74), (3, 71)],
    4: [(0, 72), (1, 76), (2, 79), (3, 76)],
    5: [(0, 77), (1, 72), (2, 69), (3, 65)],
    6: [(0, 74), (0.5, 71), (1, 67), (2, 71), (3, 74)],
    7: [(0, 76), (1, 79), (2, 82), (3, 79)],
}


def _below(key: int, chord: Chord) -> int:
    """The chord tone a third or a fourth under the tune's note, for a harmony line."""
    for step in (3, 4, 5):
        if (key - step) % 12 in chord.pitch_classes():
            return key - step
    return key - 3


def make() -> Track:
    grid = Grid(TEMPO, start=0.05)
    chords = [Chord.parse(symbol) for symbol in CHORDS]

    bassoon = Part(grid, 401, drift_ms=4, jitter_ms=3, spread=0.06, accent=0.18)
    pizz = Part(grid, 402, drift_ms=4, jitter_ms=3, spread=0.07, accent=0.15)
    cellos = Part(grid, 403, drift_ms=4, jitter_ms=3, spread=0.06)
    for bar, chord in enumerate(chords):
        part = SECTIONS[bar]
        root = chord.bass + 36 if chord.bass + 36 <= 47 else chord.bass + 24
        fifth = root + 7 if root + 7 <= 52 else root - 5
        if part == "end":
            continue
        bassoon.play(bar, 0, root, 0.62, 0.45)
        bassoon.play(bar, 2, fifth, 0.55, 0.45)
        tops = voice(chord, 60, 72, None, count=3)
        pizz.chord(bar, 1, tops, 0.5, 0.4, strum=0.006)
        pizz.chord(bar, 3, tops, 0.46, 0.4, strum=0.006)
        if part == "b":
            cellos.play(bar, 0, root + 12, 0.5, 0.5)
            cellos.play(bar, 2, fifth + 12, 0.45, 0.5)

    marimba = Part(grid, 404, drift_ms=3, jitter_ms=3, spread=0.07, accent=0.15)
    glock = Part(grid, 405, drift_ms=2, jitter_ms=2, spread=0.05)
    clarinet = Part(grid, 406, drift_ms=5, jitter_ms=3, spread=0.06)
    for bar in range(BARS):
        part = SECTIONS[bar]
        index = (bar - 2) % 8
        if part in ("a", "a2"):
            for beat, key in TUNE[index]:
                marimba.play(bar, beat, key, 0.55 if beat % 1 == 0 else 0.46, 0.4)
                if part == "a2":
                    glock.play(bar, beat, key + 12, 0.32, 0.4)
                    if beat % 1 == 0:
                        clarinet.play(bar, beat, _below(key, chords[bar]), 0.36, 0.45)
        elif part == "b":
            for beat, key in MIDDLE[index]:
                clarinet.play(bar, beat, key, 0.5, 0.45)
            # The marimba keeps the time underneath, quietly, on the off-beats.
            for beat in (0.5, 1.5, 2.5, 3.5):
                marimba.chord(bar, beat, voice(Chord.parse(CHORDS[bar]), 60, 72, None, count=2), 0.3, 0.3)

    claves = Part(grid, 407, drift_ms=1, jitter_ms=2, spread=0.08)
    for bar in range(2, BARS - 2):
        if bar % 4 == 1:
            claves.steps(bar, ". . . x", 75, 0.38, unit=1)

    # The button: everyone on one short F chord, a beat after the tune lands.
    end = BARS - 2
    marimba.chord(end, 0, [65, 69, 72, 77], 0.6, 0.6)
    glock.play(end, 0, 89, 0.38, 1)
    pizz.chord(end, 0, [60, 65, 69], 0.6, 0.5)
    bassoon.play(end, 0, 41, 0.66, 0.5)
    clarinet.play(end, 0, 72, 0.5, 0.5)
    claves.play(end, 0, 75, 0.45, 0.5)

    seconds = grid.time(BARS) + 1.5
    mix = Mix(room_seconds=1.3, room_brightness=0.5, room_return_db=-6.0, warmth=1.0)
    stems = [
        Stem("bassoon", I.woodwind("Bassoon", "stac"), bassoon.notes, gain_db=-2, pan=-0.15, eq=(("highpass", 45), ("peak", 600, 1.0, -1.5)), send=0.12),
        Stem("pizz", I.strings("Violin Section", "Pizz", release=0.25), pizz.notes, gain_db=-6, pan=0.3, eq=(("highpass", 200),), send=0.2),
        Stem("cellos", I.strings("Cello Section", "pizzT", release=0.25), cellos.notes, gain_db=-7, pan=-0.3, eq=(("highpass", 70),), send=0.15),
        Stem("marimba", I.marimba(), marimba.notes, gain_db=0, pan=0.05, eq=(("highpass", 150), ("peak", 3000, 1.0, -2.0)), send=0.18),
        Stem("clarinet", I.woodwind("Clarinet", "stac"), clarinet.notes, gain_db=-4, pan=-0.25, eq=(("highpass", 180), ("peak", 3000, 0.9, -2.0)), send=0.22),
        Stem("glock", I.glockenspiel(), glock.notes, gain_db=-14, pan=0.3, eq=(("highpass", 500),), send=0.3),
        Stem("claves", I.orchestral_percussion(), claves.notes, gain_db=-12, pan=0.4, eq=(("highpass", 400),), send=0.2),
    ]
    beats = [grid.time(bar) for bar in range(BARS)]
    return Track("tiptoeParade", "Tiptoe Parade", TEMPO, 4, BARS, seconds, stems, mix, under_speech=False, beats=beats)
