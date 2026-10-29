"""Neon Overpass, nu-disco played by an orchestra for night scenes, fashion and retro: a four-on-the-floor kit with open hi-hats on the
off-beats and claps on the backbeat, an upright bass bouncing in octaves, piano stabs between the beats, strings holding the chords and
then a high line, trumpets and trombones punching short stabs, congas and a tambourine. A minor, 112 BPM, not under speech (it drives;
the kick and hats are kept moderate)."""
from __future__ import annotations

from typing import List

import instruments as I
from score import Chord, Grid, Part, bass_key, phrase, voice
from track import Mix, Stem, Track

TEMPO = 112
LOOP = ["Am9", "D9", "Fmaj9", "E7sus4"]
CHORDS = LOOP + LOOP * 2 + LOOP * 2 + LOOP + LOOP * 2 + ["Am9", "Am9"]
SECTIONS = ["intro"] * 4 + ["a"] * 8 + ["b"] * 8 + ["break"] * 4 + ["a2"] * 8 + ["end"] * 2
BARS = len(CHORDS)
# The violins' line over the B part and the last part: (bar of the loop, beat, key, beats).
LINE = [(0, 0, 76, 3), (0, 3, 79, 1), (1, 0, 78, 4), (2, 0, 76, 2), (2, 2, 72, 2), (3, 0, 71, 3), (3, 3, 68, 1)]


def make() -> Track:
    grid = Grid(TEMPO, start=0.05)
    chords = [Chord.parse(symbol) for symbol in CHORDS]
    end = BARS - 2

    kit = Part(grid, 1001, drift_ms=1, jitter_ms=1.5, spread=0.06, accent=0.15)
    claps = Part(grid, 1002, drift_ms=1, jitter_ms=2.5, spread=0.08)
    percussion = Part(grid, 1003, drift_ms=1.5, jitter_ms=2, spread=0.1, accent=0.2)
    for bar in range(end):
        part = SECTIONS[bar]
        if part == "break":
            percussion.steps(bar, "xgxg xgxg xgxg xgxg", 54, 0.34)
            if bar == 23:
                kit.steps(bar, ".... .... x.x. xxXX", 38, 0.42)
            continue
        kit.steps(bar, "x... x... x... x...", 36, 0.62)
        kit.steps(bar, "..x. ..x. ..x. ..x.", 46, 0.34)
        if part != "intro":
            kit.steps(bar, "g.g. g.g. g.g. g.g.", 42, 0.34)
            kit.steps(bar, ".... x... .... x...", 38, 0.42)
            claps.steps(bar, ".... x... .... x...", 39, 0.55)
            percussion.steps(bar, "xgxg xgxg xgxg xgxg", 54, 0.32)
            percussion.steps(bar, "..x. .x.. x.x. ..x.", 63, 0.4)
            percussion.steps(bar, "x... ...x .... x...", 64, 0.42)
        if bar in (4, 12, 24):
            kit.play(bar, 0, 49, 0.5, 3)
    kit.play(end, 0, 36, 0.62, 1)
    kit.play(end, 0, 49, 0.58, 4)
    claps.play(end, 0, 39, 0.5, 1)

    bass = Part(grid, 1004, drift_ms=2, jitter_ms=1.5, spread=0.05)
    piano = Part(grid, 1005, drift_ms=3, jitter_ms=2, spread=0.06)
    shape: List[int] = []
    for bar in range(end):
        chord, part = chords[bar], SECTIONS[bar]
        root = bass_key(chord, 33)
        if part == "break":
            bass.play(bar, 0, root, 0.5, 3.5)
        else:
            for step in range(8):
                bass.play(bar, step * 0.5, root + (12 if step % 2 else 0), 0.62 if step % 2 == 0 else 0.5, 0.42)
        shape = voice(chord, 60, 76, shape or None, count=4)
        if part in ("a", "b", "a2"):
            for beat in (0.5, 1.5, 2.5, 3.5):
                piano.chord(bar, beat, shape, 0.44 * phrase(bar, 4, 0.06), 0.3, strum=0.005)
        elif part == "break":
            piano.chord(bar, 0, shape, 0.4, 3.8, strum=0.02)
    bass.play(end, 0, 33, 0.62, 3)
    piano.chord(end, 0, [57, 60, 64, 67, 71], 0.5, 6, strum=0.02)

    cellos = Part(grid, 1006, drift_ms=6, jitter_ms=4, spread=0.04)
    violas = Part(grid, 1007, drift_ms=6, jitter_ms=4, spread=0.04)
    violins = Part(grid, 1008, drift_ms=6, jitter_ms=4, spread=0.04)
    pads: List[int] = []
    for bar in range(4, end):
        part = SECTIONS[bar]
        pads = voice(chords[bar], 52, 69, pads or None, count=3)
        level = {"a": 0.38, "b": 0.44, "break": 0.46, "a2": 0.48}[part]
        cellos.play(bar, 0, pads[0], level, 4.1)
        violas.chord(bar, 0, pads[1:], level * 0.92, 4.1)
        if part in ("b", "a2"):
            for loop_bar, beat, key, beats in LINE:
                if loop_bar == (bar - 4) % 4:
                    violins.play(bar, beat, key, 0.48, beats * 1.02)
    violins.chord(end, 0, [76, 81], 0.46, 6)
    cellos.play(end, 0, 45, 0.44, 6)
    violas.chord(end, 0, [57, 64], 0.42, 6)

    trumpets = Part(grid, 1009, drift_ms=2, jitter_ms=2, spread=0.05)
    trombones = Part(grid, 1010, drift_ms=2, jitter_ms=2, spread=0.05)
    for bar in range(12, end):
        part = SECTIONS[bar]
        if part not in ("b", "a2") or bar % 2 == 0:
            continue
        top = sorted(voice(chords[bar], 67, 79, None, count=3))
        low = sorted(voice(chords[bar], 50, 62, None, count=3))
        for beat in (1.5, 3):
            trumpets.chord(bar, beat, top, 0.55, 0.3)
            trombones.chord(bar, beat, low, 0.55, 0.3)
    trumpets.chord(end, 0, [69, 72, 76], 0.6, 0.6)
    trombones.chord(end, 0, [45, 52, 57], 0.6, 0.6)

    seconds = grid.time(end) + 3.5
    mix = Mix(room_seconds=1.4, room_brightness=0.5, room_return_db=-6.0, glue=(-18.0, 2.2, 0.01, 0.15), warmth=1.2)
    stems = [
        Stem("kit", I.drum_kit("mid"), kit.notes, gain_db=-4, eq=(("highpass", 35), ("peak", 400, 1.0, -3.0), ("highshelf", 8000, 0.7, -2.0)), send=0.1,
             compress=(-18, 3.0, 0.004, 0.1)),
        Stem("claps", I.groove_percussion(), claps.notes, gain_db=-11, eq=(("highpass", 250), ("highshelf", 6000, 0.7, -4.0), ("lowpass", 9000)), send=0.3,
             width=0.8),
        Stem("percussion", I.orchestral_percussion(), percussion.notes, gain_db=-12, pan=0.3, eq=(("highpass", 150), ("highshelf", 8000, 0.7, -3.0)),
             send=0.15),
        Stem("bass", I.strings("Solo Contrabass", "Pizz", release=0.2), bass.notes, gain_db=-1, eq=(("highpass", 32), ("lowshelf", 90, 0.7, 3.0),
             ("peak", 700, 1.0, -2.0)), send=0.04, compress=(-22, 3.5, 0.004, 0.08), duck=("kit", 2.5)),
        Stem("piano", I.steinway_grand(), piano.notes, gain_db=-4, pan=-0.15, eq=(("highpass", 150), ("peak", 2500, 0.8, -3.0), ("highshelf", 4000, 0.7, -3.0), ("lowpass", 9000)),
             send=0.15, compress=(-20, 2.0, 0.006, 0.1)),
        Stem("cellos", I.strings("Cello Section", "susvib", release=0.6), cellos.notes, gain_db=-8, pan=0.25, eq=(("highpass", 60),), send=0.3),
        Stem("violas", I.strings("Viola Section", "susvib", release=0.6), violas.notes, gain_db=-9, pan=-0.2, eq=(("highpass", 120), ("highshelf", 3000, 0.7, -3.0)),
             send=0.32),
        Stem("violins", I.strings("Violin Section", "susVib", release=0.7), violins.notes, gain_db=-6, pan=-0.3, eq=(("highpass", 250), ("highshelf", 3000, 0.7, -3.0)),
             send=0.4),
        Stem("trumpets", I.brass("Trumpet", "stac", one_shot=True), trumpets.notes, gain_db=-7, pan=0.3, eq=(("highpass", 200), ("peak", 2500, 0.8, -3.0),
             ("highshelf", 6000, 0.7, -3.0)),
             send=0.25),
        Stem("trombones", I.brass("Tenor Trombone", "stac", one_shot=True), trombones.notes, gain_db=-7, pan=0.2, eq=(("highpass", 80),), send=0.25),
    ]
    beats = [grid.time(bar) for bar in range(BARS)]
    return Track("neonOverpass", "Neon Overpass", TEMPO, 4, BARS, seconds, stems, mix, under_speech=False, beats=beats)
