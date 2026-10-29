"""Cold Case, quiet suspense for true crime, mysteries and reveals told to the camera: cellos plucking a low ostinato over a held
double-bass pedal, violas leaning on a half step above it, a few high piano notes far apart, soft timpani at the turns and one tubular
bell at the darkest chord. D minor, 92 BPM, no drums, under speech (everything low or sparse; the high notes never in a run)."""
from __future__ import annotations

from typing import List

import instruments as I
from score import Chord, Grid, Part, voice
from track import Mix, Stem, Track

TEMPO = 92
A = ["Dm", "Bb/D", "Gm/D", "A/C#"]
B = ["Bb", "Gm", "Eb/G", "A7"]
CHORDS = A + A * 2 + B * 2 + A * 2 + ["Dm", "Dm"]
SECTIONS = ["intro"] * 4 + ["a"] * 8 + ["b"] * 8 + ["a2"] * 8 + ["end"] * 2
BARS = len(CHORDS)
# The cellos' plucked ostinato in eighths, in semitones above each bar's bass.
OSTINATO = [0, 0, 12, 0, 7, 0, 8, 7]
# The piano's high notes: (bar of the four, beat, key).
BELLS = [(0, 1.5, 81), (1, 2.5, 82), (2, 1.0, 79), (3, 2.5, 77)]


def make() -> Track:
    grid = Grid(TEMPO, start=0.05)
    chords = [Chord.parse(symbol) for symbol in CHORDS]
    end = BARS - 2

    cellos = Part(grid, 1401, drift_ms=3, jitter_ms=2.5, spread=0.06, accent=0.18)
    bass = Part(grid, 1402, drift_ms=8, jitter_ms=5, spread=0.04)
    for bar in range(end):
        chord, part = chords[bar], SECTIONS[bar]
        low = 38 + (chord.bass - 38) % 12
        low = low - 12 if low > 44 else low
        for step, interval in enumerate(OSTINATO):
            if part == "intro" and step % 2:
                continue
            cellos.play(bar, step * 0.5, low + interval if interval != 8 or chord.tones[1] == 3 else low + 7, 0.5 if step % 4 == 0 else 0.4, 0.4)
        if part != "intro":
            bass.play(bar, 0, 26 + (chord.bass - 26) % 12, 0.44 if part != "b" else 0.5, 4.1)
    cellos.play(end, 0, 38, 0.5, 2)
    bass.play(end, 0, 26, 0.5, 8)

    violas = Part(grid, 1403, drift_ms=10, jitter_ms=6, spread=0.04)
    shape: List[int] = []
    for bar in range(4, end):
        part = SECTIONS[bar]
        shape = voice(chords[bar], 50, 65, shape or None, count=2)
        level = {"a": 0.34, "b": 0.42, "a2": 0.38}[part]
        violas.chord(bar, 0, shape, level, 4.1)
        if part == "a2" and bar % 4 == 1:
            violas.play(bar, 0, 63, 0.3, 4.1)
    violas.chord(end, 0, [50, 53, 57], 0.36, 8)

    piano = Part(grid, 1404, drift_ms=10, jitter_ms=6, spread=0.05)
    for bar in range(4, end):
        part = SECTIONS[bar]
        if part == "b":
            continue
        for which, beat, key in BELLS:
            if which == bar % 4 and (part == "a2" or bar % 8 < 4):
                piano.play(bar, beat, key, 0.3, 3)
    piano.play(end, 1.0, 74, 0.28, 6)
    piano.play(end, 2.5, 77, 0.24, 5)

    timpani = Part(grid, 1405, drift_ms=2, jitter_ms=2, spread=0.06)
    bells = Part(grid, 1406, drift_ms=2, jitter_ms=2, spread=0.03)
    for bar in (12, 20, 28):
        for step in range(8):
            timpani.play(bar - 1, 2 + step * 0.25, 38 if bar != 20 else 43, 0.22 + 0.03 * step, 0.25)
        timpani.play(bar, 0, 38 if bar != 20 else 43, 0.5, 2)
    bells.play(18, 0, 63, 0.3, 8)
    timpani.play(end, 0, 38, 0.46, 4)

    seconds = grid.time(end) + 5.0
    mix = Mix(room_seconds=2.4, room_brightness=0.35, room_return_db=-4.0, speech_dip_db=3.0, warmth=1.1)
    stems = [
        Stem("cellos", I.strings("Cello Section", "pizzT", release=0.3), cellos.notes, gain_db=0, pan=0.2, eq=(("highpass", 65), ("peak", 2500, 0.9, -4.0),
             ("lowpass", 4000, 0.7)), send=0.25, compress=(-22, 2.5, 0.005, 0.12)),
        Stem("bass", I.strings("Solo Contrabass", "SusNV", release=1.0), bass.notes, gain_db=-5, eq=(("highpass", 35), ("lowpass", 1200)), send=0.25),
        Stem("violas", I.strings("Viola Section", "susvib", release=1.0), violas.notes, gain_db=-7, pan=-0.25, eq=(("highpass", 120),
             ("highshelf", 2500, 0.7, -5.0)), send=0.4),
        Stem("piano", I.steinway_grand(), piano.notes, gain_db=-9, pan=0.3, eq=(("highpass", 200), *I.SOFT_GRAND), send=0.5),
        Stem("timpani", I.timpani(), timpani.notes, gain_db=-5, pan=-0.1, eq=(("highpass", 35),), send=0.35),
        Stem("bells", I.tubular_bells(), bells.notes, gain_db=-14, pan=0.35, eq=(("highpass", 200), ("highshelf", 4000, 0.7, -5.0)), send=0.5),
    ]
    beats = [grid.time(bar) for bar in range(BARS)]
    return Track("coldCase", "Cold Case", TEMPO, 4, BARS, seconds, stems, mix, under_speech=True, beats=beats)
