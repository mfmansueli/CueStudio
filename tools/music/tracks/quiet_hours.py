"""Quiet Hours, solo piano for reflections and soft talk: a grand piano alone, the left hand rocking through each chord in eighths with the
pedal down, the right hand answering with a few notes every other bar, then a middle part in held chords before the opening returns and
settles. E-flat major, 76 BPM, under speech (soft layers only, the melody sparse and the top darkened)."""
from __future__ import annotations

from typing import List

import instruments as I
from score import Chord, Grid, Part, phrase, voice
from track import Mix, Stem, Track

TEMPO = 76
INTRO = ["Ebmaj9", "Bb/D", "Cm9", "Abmaj9"]
A = ["Ebmaj9", "Bb/D", "Cm9", "Abmaj9", "Ebmaj9/G", "Abmaj7", "Fm9", "Bbsus4"]
B = ["Abmaj9", "Bb6", "Gm7", "Cm9", "Abmaj9", "Bb6", "Ebmaj9/G", "Bbsus4"]
A2 = ["Ebmaj9", "Bb/D", "Cm9", "Abmaj9", "Fm9", "Bbsus4"]
CHORDS = INTRO + A + B + A2 + ["Ebmaj9", "Ebmaj9"]
SECTIONS = ["intro"] * 4 + ["a"] * 8 + ["b"] * 8 + ["a2"] * 6 + ["end"] * 2
BARS = len(CHORDS)
# The right hand's answer, as (beat, index into the chord's upper voicing, beats held): it rises and falls back, every other bar.
ANSWER = [(1.0, 2, 1.0), (2.0, 3, 1.5), (3.5, 1, 2.5)]
LAST = [(0.5, 3, 1.5), (2.0, 2, 4.0)]


def _low(chord: Chord) -> int:
    """The chord's bass between A1 and G#2 (33–44)."""
    key = chord.bass + 36
    return key - 12 if key > 44 else key


def make() -> Track:
    grid = Grid(TEMPO, start=0.05)
    chords = [Chord.parse(symbol) for symbol in CHORDS]

    left = Part(grid, 301, drift_ms=10, jitter_ms=4, spread=0.06, accent=0.1)
    right = Part(grid, 302, drift_ms=12, jitter_ms=5, spread=0.05)
    upper: List[int] = []
    for bar, chord in enumerate(chords):
        part = SECTIONS[bar]
        low = _low(chord)
        middle = sorted(voice(chord, 48, 63, None, count=3))
        upper = voice(chord, 63, 79, upper or None, count=4)
        shape = phrase(bar, 4, 0.12)
        if part == "end":
            if bar == BARS - 2:
                left.chord(bar, 0, [low, low + 12] + middle, 0.34, 10, strum=0.05)
                right.chord(bar, 0.5, upper[1:], 0.28, 9, strum=0.07)
            continue
        if part == "b":
            # Held chords: the bass, then the chord a little after, the top note sung out on the third beat.
            left.play(bar, 0, low, 0.4 * shape, 4)
            left.chord(bar, 0.5, middle, 0.3 * shape, 3.5, strum=0.03)
            right.chord(bar, 1.0, upper[:3], 0.27 * shape, 3, strum=0.025)
            right.play(bar, 2.5, upper[3], 0.33 * shape, 1.5)
            continue
        # Rocking eighths: bass, fifth, the chord's colour, fifth, and up again; pedal down, so each rings to the bar line.
        figure = [low, middle[0], middle[2], middle[1], middle[2], middle[0], middle[1], middle[2]]
        level = 0.3 if part == "intro" else 0.34
        for step, key in enumerate(figure):
            left.play(bar, step * 0.5, key, level * shape * (1.12 if step == 0 else 0.92), 4 - step * 0.5)
        if part in ("a", "a2") and bar % 2 == 1:
            line = LAST if part == "a2" and bar == BARS - 3 else ANSWER
            for beat, index, held in line:
                right.play(bar, beat, sorted(upper)[index], 0.31 * shape, held)

    seconds = grid.time(BARS) + 4.0
    mix = Mix(room_seconds=2.6, room_brightness=0.35, room_return_db=-4.0, speech_dip_db=2.5, warmth=1.0)
    stems = [
        Stem("left", I.steinway_grand(), left.notes, gain_db=0, eq=(("highpass", 35), ("peak", 280, 1.0, -2.0), ("highshelf", 5000, 0.7, -3.0), *I.SOFT_GRAND),
             send=0.24, width=1.1),
        Stem("right", I.steinway_grand(), right.notes, gain_db=-1.5, eq=(("highpass", 120), ("peak", 2800, 0.9, -2.5), ("highshelf", 6000, 0.7, -4.0), *I.SOFT_GRAND),
             send=0.3, width=1.1),
    ]
    beats = [grid.time(bar) for bar in range(BARS)]
    return Track("quietHours", "Quiet Hours", TEMPO, 4, BARS, seconds, stems, mix, under_speech=True, beats=beats)
