"""Bossa nova, for food, travel and lifestyle: a nylon-string guitar with its thumb on the bass strings and its fingers on the clave
(the next bar's chord a little early), an upright bass, brushes tapping the snare with a soft kick and the hi-hat foot, a shaker, and a
flute answering in the second half. G major, 128 BPM felt in two, under speech (the guitar sits under the voice, the flute is sparse).
No brush stirring: its constant swish read as a rough noise under the music (owner, 29/10)."""
from __future__ import annotations

from typing import List, Optional, Tuple

import instruments as I
from score import Chord, Grid, Part, phrase, voice
from track import Mix, Stem, Track

TEMPO = 128
INTRO = ["Gmaj9", "Em9", "Am9", "D13"]
A = ["Gmaj9", "Gmaj9", "Bm7", "E7b9", "Am9", "D13", "Gmaj9", "D7sus4"]
B = ["Cmaj9", "Cm6", "Bm7", "E7b9", "Am9", "D13", "Gmaj9", "D7sus4"]
A2 = ["Gmaj9", "Gmaj9", "Bm7", "E7b9", "Am9", "D13", "Bm7", "E7b9"]
OUTRO = ["Am9", "D13", "Cmaj9", "Cm6"]
CHORDS = INTRO + A + B + A2 + OUTRO + ["Gmaj9", "Gmaj9"]
SECTIONS = ["intro"] * 4 + ["a"] * 8 + ["b"] * 8 + ["a2"] * 8 + ["outro"] * 4 + ["end"] * 2
BARS = len(CHORDS)
# The fingers' strikes in beats: on the clave over two bars; the second bar's last one plays the next bar's chord.
EVEN = [0.0, 1.5, 3.0]
ODD = [1.0, 2.5, 3.5]


def make() -> Track:
    grid = Grid(TEMPO, start=0.05)
    chords = [Chord.parse(symbol) for symbol in CHORDS]

    strikes: List[Tuple[int, float, int]] = []  # (bar, beat, chord bar)
    for bar in range(BARS - 2):
        anticipated = bar % 2 == 0 and bar > 0 and CHORDS[bar] != CHORDS[bar - 1]
        for beat in EVEN if bar % 2 == 0 else ODD:
            if beat == 0.0 and anticipated:
                continue
            ahead = bar % 2 == 1 and beat == 3.5 and bar + 1 < BARS - 2 and CHORDS[bar + 1] != CHORDS[bar]
            strikes.append((bar, beat, bar + 1 if ahead else bar))

    guitar = Part(grid, 201, drift_ms=6, jitter_ms=3, spread=0.06)
    voicings: List[Optional[List[int]]] = [None] * BARS
    previous: Optional[List[int]] = None
    for bar, chord in enumerate(chords):
        voicings[bar] = previous = voice(chord, 55, 71, previous, count=3)
    for index, (bar, beat, of) in enumerate(strikes):
        position = bar * 4 + beat
        following = strikes[index + 1] if index + 1 < len(strikes) else (BARS - 2, 0.0, BARS - 2)
        length = following[0] * 4 + following[1] - position - 0.08
        # Damped at the bar line when the chord changes there and nothing was played early for it.
        if of == bar and bar + 1 < BARS and CHORDS[bar + 1] != CHORDS[bar]:
            length = min(length, (bar + 1) * 4 - position + 0.05)
        level = (0.46 if SECTIONS[bar] == "intro" else 0.5) * phrase(bar, 4, 0.06) * (1.06 if beat in (0.0, 1.0) else 0.95)
        guitar.chord(bar, beat, voicings[of], level, min(length, 3.0), strum=0.007)
    for bar, chord in enumerate(chords[: BARS - 2]):
        root = chord.bass + 36 if chord.bass + 36 >= 40 else chord.bass + 48
        fifth = root + 7 if root + 7 <= 52 else root - 5
        guitar.play(bar, 0, root, 0.5, 1.9)
        guitar.play(bar, 2, fifth, 0.44, 1.9)
    end = BARS - 2
    guitar.chord(end, 0, [chords[end].bass + 36] + sorted(voice(chords[end], 55, 76, None, count=4)), 0.5, 8, strum=0.07)

    bass = Part(grid, 202, drift_ms=4, jitter_ms=2.5, spread=0.05)
    for bar, chord in enumerate(chords):
        if SECTIONS[bar] == "intro":
            continue
        root = chord.bass + 24 if chord.bass + 24 >= 28 else chord.bass + 36
        fifth = root + 7 if root + 7 <= 40 else root - 5
        if SECTIONS[bar] == "end":
            if bar == end:
                bass.play(bar, 0, root, 0.55, 6)
            continue
        bass.play(bar, 0, root, 0.62, 1.4)
        bass.play(bar, 1.5, fifth, 0.5, 2.3)

    brushes = Part(grid, 203, drift_ms=1.5, jitter_ms=2.5, spread=0.08, accent=0.12)
    shaker = Part(grid, 205, drift_ms=1, jitter_ms=2, spread=0.1, accent=0.2)
    for bar in range(1, BARS - 2):
        part = SECTIONS[bar]
        if part == "intro":
            continue
        brushes.steps(bar, "x..x ..x." if bar % 2 == 0 else "..x. .x..", 38, 0.36, unit=0.5)
        brushes.steps(bar, "..x. ..x.", 44, 0.45, unit=0.5)
        brushes.steps(bar, "x..g x..g", 36, 0.52, unit=0.5)
        if part in ("b", "a2"):
            shaker.steps(bar, "x.x. x.x.", 70, 0.42, unit=0.5)
            shaker.steps(bar, ".g.g .g.g", 69, 0.75, unit=0.5)
        if bar in (11, 19, 27):
            brushes.steps(bar, ".... ..xX", 40, 0.5, unit=0.5)
    brushes.play(end, 0, 36, 0.45, 1)

    flute = Part(grid, 206, drift_ms=8, jitter_ms=4, spread=0.05)
    for bar in range(0, BARS - 2, 2):
        if SECTIONS[bar] not in ("b", "a2"):
            continue
        here = sorted(voice(chords[bar], 74, 86, None, count=3))
        there = sorted(voice(chords[bar + 1], 74, 86, None, count=3))
        flute.play(bar, 0.5, here[-1], 0.5, 2.6)
        flute.play(bar, 3.5, here[1], 0.42, 1.4)
        flute.play(bar + 1, 1.0, there[-1] if SECTIONS[bar] == "a2" else there[1], 0.46, 2.2)
    flute.play(end, 0.5, sorted(voice(chords[end], 76, 88, None, count=3))[-1], 0.42, 5)

    seconds = grid.time(BARS) + 3.5
    mix = Mix(room_seconds=1.6, room_brightness=0.45, room_return_db=-5.0, speech_dip_db=2.5, warmth=1.0)
    stems = [
        Stem("guitar", I.nylon_guitar(), guitar.notes, gain_db=0, pan=-0.1, width=0.9, eq=(("highpass", 70), ("peak", 250, 1.0, -2.0),
             ("peak", 3200, 0.9, -2.5), ("lowpass", 9500)), send=0.16, compress=(-20, 2.0, 0.008, 0.15)),
        Stem("bass", I.strings("Solo Contrabass", "Pizz", release=0.2), bass.notes, gain_db=-3, eq=(("highpass", 32), ("lowshelf", 90, 0.7, 2.0),
             ("peak", 700, 1.0, -2.5)), send=0.06, compress=(-24, 3.0, 0.005, 0.12)),
        Stem("brushes", I.brush_kit(), brushes.notes, gain_db=-9, eq=(("highpass", 40), ("peak", 3500, 1.0, -2.0), ("highshelf", 7000, 0.7, -3.0)),
             send=0.15,
             compress=(-22, 2.5, 0.005, 0.1)),
        Stem("shaker", I.groove_percussion(), shaker.notes, gain_db=-17, pan=0.4, eq=(("highpass", 400), ("highshelf", 9000, 0.7, -3.0)), send=0.2),
        Stem("flute", I.flute(), flute.notes, gain_db=-9, pan=0.3, eq=(("highpass", 250), ("peak", 3000, 0.8, -3.0)), send=0.35),
    ]
    beats = [grid.time(bar) for bar in range(BARS)]
    return Track("bossa", "Bossa", TEMPO, 4, BARS, seconds, stems, mix, under_speech=True, beats=beats)
