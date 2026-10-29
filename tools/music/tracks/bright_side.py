"""Bright Side, feel-good acoustic pop for intros and vlogs: a grand piano pushing eighths, an upright bass, a drum kit with a
cross-stick in the verse and claps on the backbeat in the chorus, a nylon guitar strumming the chorus, and a marimba and glockenspiel
hook on top. C major, 118 BPM, not under speech (bright and forward; the kit stays moderate)."""
from __future__ import annotations

from typing import Dict, List, Tuple

import instruments as I
from score import Chord, Grid, Part, bass_key, phrase, voice
from track import Mix, Stem, Track

TEMPO = 118
INTRO = ["C", "G/B", "Am7", "Fmaj7"]
A = ["C", "G/B", "Am7", "Fmaj7", "C", "G/B", "F", "G"]
B = ["F", "G", "Em7", "Am7", "F", "G", "Csus4", "C"]
CHORDS = INTRO + A + B + A + B + ["C", "C"]
SECTIONS = ["intro"] * 4 + ["a"] * 8 + ["b"] * 8 + ["a2"] * 8 + ["b2"] * 8 + ["end"] * 2
BARS = len(CHORDS)
# The chorus hook, by bar of the eight: (beat, key, beats).
HOOK: Dict[int, List[Tuple[float, int, float]]] = {
    0: [(0, 69, 0.5), (0.5, 72, 0.5), (1, 77, 1), (2, 76, 0.5), (2.5, 74, 0.5), (3, 72, 1)],
    1: [(0, 74, 0.5), (0.5, 71, 0.5), (1, 67, 1), (2, 74, 1), (3, 76, 1)],
    2: [(0, 79, 1), (1, 76, 0.5), (1.5, 74, 0.5), (2, 71, 1), (3, 74, 1)],
    3: [(0, 72, 1), (1, 76, 1), (2, 72, 0.5), (2.5, 69, 0.5), (3, 67, 1)],
    4: [(0, 69, 0.5), (0.5, 72, 0.5), (1, 77, 1), (2, 76, 0.5), (2.5, 74, 0.5), (3, 72, 1)],
    5: [(0, 74, 0.5), (0.5, 71, 0.5), (1, 67, 1), (2, 71, 0.5), (2.5, 74, 0.5), (3, 79, 1)],
    6: [(0, 77, 1.5), (1.5, 77, 0.5), (2, 76, 1), (3, 74, 1)],
    7: [(0, 72, 2), (2, 79, 1), (3, 84, 1)],
}
# The verse's answer, every other bar: (beat, index into the chord's top notes).
ANSWER = [(2.5, 2), (3, 1), (3.5, 0)]
# The chorus strum: (beat, down?, level).
STRUM = [(0, True, 1.0), (1, True, 0.75), (1.5, False, 0.6), (2.5, False, 0.65), (3, True, 0.8), (3.5, False, 0.6)]


def make() -> Track:
    grid = Grid(TEMPO, start=0.05)
    chords = [Chord.parse(symbol) for symbol in CHORDS]
    end = BARS - 2

    piano = Part(grid, 801, drift_ms=4, jitter_ms=2.5, spread=0.06, accent=0.12)
    bass = Part(grid, 802, drift_ms=3, jitter_ms=2, spread=0.05)
    guitar = Part(grid, 803, drift_ms=5, jitter_ms=3, spread=0.06)
    shape: List[int] = []
    strings: List[int] = []
    for bar in range(end):
        chord, part = chords[bar], SECTIONS[bar]
        shape = voice(chord, 55, 72, shape or None, count=4)
        root = bass_key(chord, 33)
        shape_level = phrase(bar, 4, 0.06)
        if part in ("intro", "a", "a2"):
            # Quarter chords with a push into beat three.
            for beat, level in ((0, 0.46), (1, 0.36), (1.5, 0.4), (2.5, 0.42), (3, 0.36)):
                piano.chord(bar, beat, shape, level * shape_level, 0.45 if beat % 1 else 0.9, strum=0.008)
            piano.play(bar, 0, root + 12, 0.42 * shape_level, 2)
        else:
            for step in range(8):
                piano.chord(bar, step * 0.5, shape, (0.5 if step % 2 == 0 else 0.4) * shape_level, 0.45, strum=0.006)
            piano.play(bar, 0, root + 12, 0.48, 2)
            for beat, down, weight in STRUM:
                strings = voice(chord, 52, 69, strings or None, count=4)
                guitar.chord(bar, beat, [bass_key(chord, 40)] + strings if down else strings[-3:], 0.46 * weight, 1, strum=0.01, up=not down)
        if part == "intro":
            continue
        if part in ("a", "a2"):
            for beat, level in ((0, 0.62), (1.5, 0.48), (2, 0.55), (3.5, 0.42)):
                bass.play(bar, beat, root, level, 0.5 if beat % 1 else 0.9)
        else:
            for step in range(8):
                bass.play(bar, step * 0.5, root + (12 if step in (3, 7) else 0), 0.62 if step % 2 == 0 else 0.48, 0.42)
    piano.chord(end, 0, [36, 48, 55, 64, 67, 72, 76], 0.52, 8, strum=0.03)
    bass.play(end, 0, 36, 0.6, 6)
    guitar.chord(end, 0, [40, 48, 52, 55, 60, 64], 0.5, 8, strum=0.04)

    kit = Part(grid, 804, drift_ms=1.5, jitter_ms=1.5, spread=0.06, accent=0.15)
    claps = Part(grid, 805, drift_ms=1, jitter_ms=2.5, spread=0.08)
    shaker = Part(grid, 806, drift_ms=1, jitter_ms=2, spread=0.1)
    for bar in range(4, end):
        part = SECTIONS[bar]
        fill = bar % 8 == 3
        if part in ("a", "a2"):
            kit.steps(bar, "x... ..x. x... ....", 36, 0.55)
            kit.steps(bar, ".... x... .... x...", 37, 0.5)
            kit.steps(bar, "x.x. x.x. x.x. x.x.", 42, 0.3)
            shaker.steps(bar, "xgxg xgxg xgxg xgxg", 70, 0.36)
        else:
            kit.steps(bar, "x... ..x. x.x. ....", 36, 0.62)
            kit.steps(bar, ".... x... .... x..." if not fill else ".... x... .... x.gg", 38, 0.5)
            kit.steps(bar, "x.x. x.x. x.x. x.X." if bar % 2 else "x.x. x.x. x.x. x.x.", 42, 0.32)
            claps.steps(bar, ".... x... .... x...", 39, 0.55)
            shaker.steps(bar, "xgxg xgxg xgxg xgxg", 54, 0.3)
        if bar in (12, 28):
            kit.play(bar, 0, 49, 0.55, 3)
        if bar in (11, 27):
            kit.steps(bar, ".... .... .... xxXX", 38, 0.4)
    kit.play(end, 0, 36, 0.62, 1)
    kit.play(end, 0, 49, 0.6, 4)
    claps.play(end, 0, 39, 0.5, 1)

    marimba = Part(grid, 807, drift_ms=3, jitter_ms=2, spread=0.06, accent=0.12)
    glock = Part(grid, 808, drift_ms=2, jitter_ms=2, spread=0.05)
    pizz = Part(grid, 809, drift_ms=3, jitter_ms=2, spread=0.07)
    for bar in range(4, end):
        part = SECTIONS[bar]
        index = (bar - 4) % 8
        if part in ("b", "b2"):
            for beat, key, beats in HOOK[index]:
                marimba.play(bar, beat, key, 0.55 if beat % 1 == 0 else 0.46, beats)
                glock.play(bar, beat, key + 12, 0.3 if part == "b" else 0.36, beats)
            if part == "b2":
                tops = voice(chords[bar], 64, 76, None, count=3)
                for step in (1, 3, 5, 7):
                    pizz.chord(bar, step * 0.5, tops, 0.42, 0.35)
        elif bar % 2 == 1:
            tops = sorted(voice(chords[bar], 72, 84, None, count=3))
            for beat, slot in ANSWER:
                marimba.play(bar, beat, tops[slot], 0.44, 0.5)
    glock.play(end, 0.5, 84, 0.34, 4)
    marimba.chord(end, 0, [60, 64, 67, 72], 0.5, 2)

    seconds = grid.time(end) + 3.5
    mix = Mix(room_seconds=1.5, room_brightness=0.55, room_return_db=-6.0, warmth=1.1)
    stems = [
        Stem("piano", I.steinway_grand(), piano.notes, gain_db=0, eq=(("highpass", 70), ("peak", 300, 0.9, -2.0), ("peak", 2500, 0.8, -4.0),
             ("highshelf", 4000, 0.7, -3.0), ("lowpass", 9000)), send=0.15, width=1.1, compress=(-20, 2.0, 0.008, 0.12)),
        Stem("bass", I.strings("Solo Contrabass", "Pizz", release=0.22), bass.notes, gain_db=-2, eq=(("highpass", 32), ("lowshelf", 90, 0.7, 2.5),
             ("peak", 700, 1.0, -2.0)), send=0.05, compress=(-22, 3.0, 0.005, 0.1), duck=("kit", 2.0)),
        Stem("guitar", I.nylon_guitar(), guitar.notes, gain_db=-6, pan=-0.3, eq=(("highpass", 120), ("lowpass", 9500)), send=0.15),
        Stem("kit", I.drum_kit("mid"), kit.notes, gain_db=-5, eq=(("highpass", 35), ("peak", 400, 1.0, -2.5), ("highshelf", 8000, 0.7, -2.0)), send=0.12,
             compress=(-18, 3.0, 0.004, 0.12)),
        Stem("claps", I.groove_percussion(), claps.notes, gain_db=-11, eq=(("highpass", 250), ("highshelf", 6000, 0.7, -4.0)), send=0.3, width=0.8),
        Stem("shaker", I.groove_percussion(), shaker.notes, gain_db=-16, pan=0.35, eq=(("highpass", 500), ("highshelf", 8000, 0.7, -4.0)), send=0.15),
        Stem("marimba", I.marimba(), marimba.notes, gain_db=-3, pan=0.15, eq=(("highpass", 150), ("peak", 3000, 0.8, -3.0)), send=0.2),
        Stem("glock", I.glockenspiel(), glock.notes, gain_db=-13, pan=0.3, eq=(("highpass", 500),), send=0.3),
        Stem("pizz", I.strings("Violin Section", "Pizz", release=0.25), pizz.notes, gain_db=-10, pan=-0.35, eq=(("highpass", 200),), send=0.25),
    ]
    beats = [grid.time(bar) for bar in range(BARS)]
    return Track("brightSide", "Bright Side", TEMPO, 4, BARS, seconds, stems, mix, under_speech=False, beats=beats)
