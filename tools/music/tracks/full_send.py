"""Full Send, a driving orchestral rock for sports, fitness and challenges: a grand piano hammering low eighths, a drum kit with tom
fills, a concert bass drum and timpani on the big beats, pizzicato basses and cellos pushing eighths, brass stabs, the horns with a
heroic line in the chorus and a percussion break before the last one. D minor, 128 BPM, not under speech (it is the energy itself)."""
from __future__ import annotations

from typing import List

import instruments as I
from score import Chord, Grid, Part, bass_key, voice
from track import Mix, Stem, Track

TEMPO = 128
A = ["Dm", "Bb", "F", "C"]
B = ["Gm", "Bb", "Dm", "A"]
CHORDS = A + A * 2 + B * 2 + ["Dm"] * 4 + B * 2 + ["Dm", "Dm"]
SECTIONS = ["intro"] * 4 + ["a"] * 8 + ["b"] * 8 + ["break"] * 4 + ["b2"] * 8 + ["end"] * 2
BARS = len(CHORDS)
# The horns' line over four bars of the chorus: (bar of the four, beat, key, beats).
LINE = [(0, 0, 62, 1.5), (0, 1.5, 65, 0.5), (0, 2, 67, 2), (1, 0, 65, 1.5), (1, 1.5, 62, 0.5), (1, 2, 70, 2), (2, 0, 69, 3), (2, 3, 65, 1),
        (3, 0, 64, 2), (3, 2, 61, 2)]


def make() -> Track:
    grid = Grid(TEMPO, start=0.05)
    chords = [Chord.parse(symbol) for symbol in CHORDS]
    end = BARS - 2

    piano = Part(grid, 1801, drift_ms=2, jitter_ms=1.5, spread=0.05, accent=0.15)
    bass = Part(grid, 1802, drift_ms=2, jitter_ms=1.5, spread=0.05, accent=0.15)
    cellos = Part(grid, 1803, drift_ms=2, jitter_ms=1.5, spread=0.06, accent=0.15)
    for bar in range(end):
        chord, part = chords[bar], SECTIONS[bar]
        root = bass_key(chord, 33)
        if part != "break":
            for step in range(8):
                accent = 1.12 if step in (0, 3, 6) else 1.0
                piano.chord(bar, step * 0.5, [root + 12, root + 24], 0.42 * accent, 0.4)
        if part in ("a", "b", "b2"):
            for step in range(8):
                bass.play(bar, step * 0.5, root, 0.56 if step % 2 == 0 else 0.48, 0.4)
                cellos.play(bar, step * 0.5, root + 12, 0.46 if step % 2 == 0 else 0.4, 0.4)
    piano.chord(end, 0, [38, 50, 57, 62, 65], 0.56, 6)
    bass.play(end, 0, 38, 0.6, 4)
    cellos.play(end, 0, 50, 0.5, 4)

    kit = Part(grid, 1804, drift_ms=1, jitter_ms=1.2, spread=0.05, accent=0.15)
    big = Part(grid, 1805, drift_ms=1, jitter_ms=1.5, spread=0.05)
    timpani = Part(grid, 1806, drift_ms=1.5, jitter_ms=1.5, spread=0.06)
    toms = Part(grid, 1807, drift_ms=1, jitter_ms=1.5, spread=0.06, accent=0.2)
    for bar in range(end):
        part = SECTIONS[bar]
        root = bass_key(chords[bar], 33)
        if part == "intro":
            timpani.play(bar, 0, root, 0.46, 2)
            continue
        if part == "break":
            toms.steps(bar, "x..x ..x. x..x ..x." if bar < 23 else "x.x. x.x. xxxx XXXX", 45, 0.5)
            big.steps(bar, "x... .... x... ....", 35, 0.5)
            continue
        fill = bar % 4 == 3
        kit.steps(bar, "x... ..x. x... ...." if part == "a" else "x... ..x. x.x. ....", 36, 0.6)
        kit.steps(bar, ".... x... .... x..." if not fill else ".... x... ..x. xxXX", 38, 0.5)
        kit.steps(bar, "x.x. x.x. x.x. x.x.", 42 if part == "a" else 46 if bar % 2 else 42, 0.32)
        if fill:
            toms.steps(bar, ".... .... x.x. ....", 47, 0.46)
        if bar in (4, 12, 24):
            kit.play(bar, 0, 49, 0.56, 3)
        if part in ("b", "b2"):
            big.play(bar, 0, 35, 0.5, 2)
            timpani.steps(bar, "x... .... x.x. ....", root, 0.5)
    kit.play(end, 0, 36, 0.62, 1)
    kit.play(end, 0, 49, 0.62, 4)
    big.play(end, 0, 35, 0.62, 4)
    timpani.play(end, 0, 38, 0.62, 4)

    brass = Part(grid, 1808, drift_ms=1.5, jitter_ms=1.5, spread=0.05)
    low_brass = Part(grid, 1809, drift_ms=1.5, jitter_ms=1.5, spread=0.05)
    horns = Part(grid, 1810, drift_ms=5, jitter_ms=3, spread=0.04)
    strings = Part(grid, 1811, drift_ms=6, jitter_ms=4, spread=0.04)
    pads: List[int] = []
    for bar in range(4, end):
        part = SECTIONS[bar]
        chord = chords[bar]
        pads = voice(chord, 55, 72, pads or None, count=3)
        if part in ("a", "b", "break", "b2"):
            strings.chord(bar, 0, pads, 0.36 if part == "a" else 0.44, 4.1)
        if part in ("b", "b2"):
            top = sorted(voice(chord, 62, 74, None, count=3))
            low = sorted(voice(chord, 45, 57, None, count=3))
            for beat in (0, 1.5, 3):
                brass.chord(bar, beat, top, 0.5, 0.3)
                low_brass.chord(bar, beat, low, 0.5, 0.3)
            for which, beat, key, beats in LINE:
                if which == (bar - 12) % 4:
                    horns.play(bar, beat, key, 0.56, beats * 1.02)
    brass.chord(end, 0, [62, 65, 69], 0.6, 0.6)
    low_brass.chord(end, 0, [38, 45, 50], 0.6, 0.6)
    horns.chord(end, 0, [57, 62], 0.56, 4)
    strings.chord(end, 0, [62, 65, 69, 74], 0.5, 4)

    seconds = grid.time(end) + 3.5
    mix = Mix(room_seconds=1.8, room_brightness=0.5, room_return_db=-5.0, glue=(-18.0, 2.5, 0.008, 0.15), warmth=1.3)
    stems = [
        Stem("piano", I.steinway_grand(), piano.notes, gain_db=-4, pan=-0.1, eq=(("highpass", 50), ("highshelf", 4000, 0.7, -4.0), ("lowpass", 8000)),
             send=0.12, compress=(-20, 2.5, 0.005, 0.1)),
        Stem("bass", I.strings("Solo Contrabass", "Pizz", release=0.2), bass.notes, gain_db=-2, eq=(("highpass", 32), ("lowshelf", 90, 0.7, 2.5)),
             send=0.05, compress=(-22, 3.0, 0.004, 0.08), duck=("kit", 2.0)),
        Stem("cellos", I.strings("Cello Section", "pizzT", release=0.2), cellos.notes, gain_db=-5, pan=0.25, eq=(("highpass", 60),), send=0.15),
        Stem("kit", I.drum_kit("mid"), kit.notes, gain_db=-4, eq=(("highpass", 35), ("peak", 400, 1.0, -3.0), ("highshelf", 8000, 0.7, -2.0)), send=0.12,
             compress=(-18, 3.0, 0.004, 0.1)),
        Stem("big", I.cinematic_percussion(), big.notes, gain_db=-6, eq=(("highpass", 30), ("lowpass", 4000)), send=0.3),
        Stem("timpani", I.timpani(), timpani.notes, gain_db=-5, pan=-0.15, eq=(("highpass", 35),), send=0.3),
        Stem("toms", I.folk_percussion(), toms.notes, gain_db=-6, pan=0.15, eq=(("highpass", 50), ("highshelf", 6000, 0.7, -3.0)), send=0.25),
        Stem("brass", I.brass("Trumpet", "stac", one_shot=True), brass.notes, gain_db=-7, pan=0.3, eq=(("highpass", 200), ("highshelf", 6000, 0.7, -3.0)),
             send=0.25),
        Stem("lowBrass", I.brass("Tenor Trombone", "stac", one_shot=True), low_brass.notes, gain_db=-7, pan=0.2, eq=(("highpass", 80),), send=0.25),
        Stem("horns", I.brass("F Horn", "sus", release=0.5), horns.notes, gain_db=-3, pan=-0.2, eq=(("highpass", 90),), send=0.4),
        Stem("strings", I.strings("Viola Section", "susvib", release=0.6), strings.notes, gain_db=-9, pan=-0.3, eq=(("highpass", 150),
             ("highshelf", 3000, 0.7, -3.0)), send=0.35),
    ]
    beats = [grid.time(bar) for bar in range(BARS)]
    return Track("fullSend", "Full Send", TEMPO, 4, BARS, seconds, stems, mix, under_speech=False, beats=beats)
