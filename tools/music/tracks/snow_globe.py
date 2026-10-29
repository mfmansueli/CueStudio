"""Snow Globe, a holiday swing for gifts, recipes and seasonal vlogs: brushes on a swung shuffle, sleigh bells struck only on the
backbeat (never a constant shake), an upright bass walking in two, pizzicato violins on the off-beats, horns holding the chorus,
hand chimes and a glockenspiel with the tune in the intro and the third part, and tubular bells on the final chord. C major, 120 BPM,
under speech (the tune rests in the first two parts and the last)."""
from __future__ import annotations

from typing import List

import instruments as I
from score import Chord, Grid, Part, bass_key, phrase, voice
from track import Mix, Stem, Track

TEMPO = 120
A = ["C", "Am7", "Dm7", "G7", "Em7", "A7", "Dm7", "G7"]
B = ["F", "Fm6", "C/E", "A7", "Dm7", "G7", "C", "G7"]
CHORDS = A[:4] + A + B + A + B + ["C", "C"]
SECTIONS = ["intro"] * 4 + ["a"] * 8 + ["b"] * 8 + ["a2"] * 8 + ["b2"] * 8 + ["end"] * 2
BARS = len(CHORDS)
# The tune over eight bars: (bar of the eight, beat, key, beats).
TUNE = [(0, 0, 76, 1), (0, 1, 79, 1), (0, 2, 84, 2), (1, 0, 81, 1.5), (1, 1.5, 79, 0.5), (1, 2, 76, 2), (2, 0, 77, 1), (2, 1, 81, 1),
        (2, 2, 84, 1), (2, 3, 81, 1), (3, 0, 79, 3), (4, 0, 76, 1), (4, 1, 79, 1), (4, 2, 83, 2), (5, 0, 81, 1.5), (5, 1.5, 79, 0.5),
        (5, 2, 73, 2), (6, 0, 74, 1), (6, 1, 77, 1), (6, 2, 81, 1), (6, 3, 79, 1), (7, 0, 77, 1), (7, 1, 76, 1), (7, 2, 74, 2)]


def make() -> Track:
    grid = Grid(TEMPO, swing=0.64, swing_unit=0.5, start=0.05)
    chords = [Chord.parse(symbol) for symbol in CHORDS]
    end = BARS - 2

    bass = Part(grid, 1601, drift_ms=3, jitter_ms=2.5, spread=0.05)
    pizz = Part(grid, 1602, drift_ms=3, jitter_ms=2.5, spread=0.07)
    shape: List[int] = []
    for bar in range(end):
        chord, part = chords[bar], SECTIONS[bar]
        root = bass_key(chord, 36)
        if part != "intro":
            bass.play(bar, 0, root, 0.58, 1.6)
            bass.play(bar, 2, root + 7 if root + 7 <= 48 else root - 5, 0.5, 1.6)
        shape = voice(chord, 60, 74, shape or None, count=3)
        for beat in (1, 3):
            pizz.chord(bar, beat, shape, 0.4 * phrase(bar, 4, 0.06), 0.4)
    bass.play(end, 0, 36, 0.56, 6)
    pizz.chord(end, 0, [60, 64, 67, 72], 0.44, 1)

    kit = Part(grid, 1603, drift_ms=1.5, jitter_ms=2.5, spread=0.08, accent=0.12)
    bells = Part(grid, 1604, drift_ms=1, jitter_ms=2, spread=0.08)
    for bar in range(4, end):
        kit.steps(bar, "x... x.x. x... x.x.", 51, 0.3)
        kit.steps(bar, ".... x... .... x...", 38, 0.3 if SECTIONS[bar] in ("a", "a2") else 0.34)
        kit.steps(bar, ".... x... .... x...", 44, 0.26)
        if bar % 4 == 3:
            kit.steps(bar, ".... .... ..g. x.g.", 38, 0.28)
        bells.steps(bar, ".... x... .... x...", 83, 0.36)
    kit.play(end, 0, 51, 0.34, 4)
    kit.play(end, 0, 36, 0.36, 1)

    horns = Part(grid, 1605, drift_ms=8, jitter_ms=5, spread=0.04)
    held: List[int] = []
    for bar in range(12, end):
        if SECTIONS[bar] not in ("b", "b2"):
            continue
        held = voice(chords[bar], 55, 67, held or None, count=2)
        horns.chord(bar, 0, held, 0.36, 4.1)
    horns.chord(end, 0, [55, 60, 64], 0.4, 6)

    glock = Part(grid, 1606, drift_ms=2, jitter_ms=2, spread=0.05)
    chimes = Part(grid, 1607, drift_ms=4, jitter_ms=3, spread=0.05)
    for start, length, level in ((0, 4, 0.34), (20, 8, 0.36)):
        for which, beat, key, beats in TUNE:
            if which >= length:
                continue
            bar = start + which
            glock.play(bar, beat, key, level, beats)
            if beat == 0:
                chimes.play(bar, 0, key - 12, 0.3, beats + 1)
    glock.play(end, 0.5, 84, 0.34, 4)

    tubular = Part(grid, 1608, drift_ms=1, jitter_ms=1, spread=0.03)
    tubular.chord(end, 0, [60, 67], 0.36, 8)

    seconds = grid.time(end) + 5.0
    mix = Mix(room_seconds=1.8, room_brightness=0.45, room_return_db=-5.5, speech_dip_db=2.0, warmth=1.2)
    stems = [
        Stem("bass", I.strings("Solo Contrabass", "Pizz", release=0.25), bass.notes, gain_db=-2, eq=(("highpass", 40),
             ("peak", 700, 1.0, -2.5)), send=0.06, compress=(-22, 3.0, 0.005, 0.12)),
        Stem("pizz", I.strings("Violin Section", "Pizz", release=0.25), pizz.notes, gain_db=-6, pan=-0.3, eq=(("highpass", 200), ("peak", 2800, 0.8, -3.0)),
             send=0.25),
        Stem("kit", I.brush_kit(), kit.notes, gain_db=-11, pan=0.1, eq=(("highpass", 60), ("peak", 3000, 1.0, -4.0), ("highshelf", 6000, 0.7, -6.0)),
             send=0.12, compress=(-24, 2.0, 0.01, 0.15)),
        Stem("bells", I.folk_percussion(), bells.notes, gain_db=-17, pan=0.35, eq=(("highpass", 800), ("lowpass", 8000)), send=0.25),
        Stem("horns", I.brass("F Horn", "sus", release=0.6), horns.notes, gain_db=-7, pan=0.2, eq=(("highpass", 100), ("lowpass", 3000, 0.7)), send=0.4),
        Stem("glock", I.glockenspiel(), glock.notes, gain_db=-11, pan=0.2, eq=(("highpass", 500), ("peak", 2500, 0.8, -3.0), ("highshelf", 6000, 0.7, -3.0)),
             send=0.3),
        Stem("chimes", I.hand_chimes(), chimes.notes, gain_db=-12, pan=-0.2, eq=(("highpass", 300),), send=0.45),
        Stem("tubular", I.tubular_bells(), tubular.notes, gain_db=-12, eq=(("highpass", 200), ("highshelf", 4000, 0.7, -4.0)), send=0.5),
    ]
    beats = [grid.time(bar) for bar in range(BARS)]
    return Track("snowGlobe", "Snow Globe", TEMPO, 4, BARS, seconds, stems, mix, under_speech=True, beats=beats)
