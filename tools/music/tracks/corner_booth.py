"""Corner Booth, a jazz trio in a café for food, interviews and slow conversations: a grand piano comping rootless voicings in the
Charleston rhythm, an upright bass walking quarters, brushes on the ride and the hi-hat foot, and the piano answering in the right hand
at the end of each phrase. B-flat major, 132 BPM swung, under speech (the piano stays in the middle, darkened; no melody over the talk)."""
from __future__ import annotations

from typing import List

import instruments as I
from score import Chord, Grid, Part, bass_key, phrase, voice
from track import Mix, Stem, Track

TEMPO = 132
A = ["Bbmaj7", "Gm7", "Cm7", "F7", "Dm7", "G7", "Cm7", "F7"]
B = ["Ebmaj7", "Ebm6", "Dm7", "G7", "Cm7", "F7", "Bbmaj7", "F7"]
CHORDS = A[:4] + A + A + B + A + ["Bbmaj7", "Bbmaj7"]
SECTIONS = ["intro"] * 4 + ["a"] * 8 + ["a2"] * 8 + ["b"] * 8 + ["a3"] * 8 + ["end"] * 2
BARS = len(CHORDS)
# The comping rhythms, by bar: (beat, beats held).
COMPING = [[(0, 0.9), (1.5, 1.2)], [(0.5, 0.7), (2.5, 1.0)], [(0, 1.4), (3.5, 0.4)], [(1, 0.8), (2.5, 1.2)]]
# The right hand's answers at the end of a phrase: (beat, index into the chord's tones from the top, beats).
FILL = [(1.5, 0, 0.5), (2, 1, 0.5), (2.5, 2, 0.5), (3, 1, 1.0)]


def make() -> Track:
    grid = Grid(TEMPO, swing=0.64, swing_unit=0.5, start=0.05)
    chords = [Chord.parse(symbol) for symbol in CHORDS]
    end = BARS - 2

    piano = Part(grid, 1101, drift_ms=6, jitter_ms=4, spread=0.08, accent=0.1)
    shape: List[int] = []
    for bar in range(end):
        chord, part = chords[bar], SECTIONS[bar]
        shape = voice(chord, 55, 70, shape or None, count=4)
        level = (0.4 if part == "intro" else 0.44) * phrase(bar, 4, 0.08)
        for beat, beats in COMPING[bar % 4]:
            piano.chord(bar, beat, shape, level * (1.0 if beat % 1 == 0 else 0.92), beats, strum=0.006)
        if part == "intro":
            piano.play(bar, 0, bass_key(chord, 36), 0.4, 2)
        if part in ("a2", "a3") and bar % 8 in (3, 7):
            tones = sorted(voice(chord, 70, 82, None, count=3), reverse=True)
            for beat, index, beats in FILL:
                piano.play(bar, beat, tones[index], 0.4, beats)
    piano.chord(end, 0, [46, 57, 62, 65, 69, 74], 0.46, 8, strum=0.05)
    piano.play(end, 1.5, 81, 0.32, 6)

    # The bass walks: the root on one, chord tones on two and three, a half step into the next root on four.
    bass = Part(grid, 1102, drift_ms=4, jitter_ms=3, spread=0.06, accent=0.15)
    for bar in range(4, end):
        chord, upcoming = chords[bar], chords[bar + 1]
        root = bass_key(chord, 31)
        third = root + chord.tones[1]
        fifth = root + 7
        target = bass_key(upcoming, 31)
        approach = target + (1 if bar % 3 == 0 else -1)
        walk = [root, third if bar % 2 == 0 else fifth, fifth if bar % 2 == 0 else third + 12 if third + 12 <= 52 else third, approach]
        for beat, key in enumerate(walk):
            bass.play(bar, beat, key, 0.6 if beat == 0 else 0.52, 0.85)
    bass.play(end, 0, 34, 0.58, 6)

    # Brushes: the ride's swung pattern, the hi-hat foot on two and four, a few snare taps closing phrases.
    kit = Part(grid, 1103, drift_ms=1.5, jitter_ms=2.5, spread=0.08, accent=0.12)
    for bar in range(4, end):
        kit.steps(bar, "x... x.x. x... x.x.", 51, 0.34)
        kit.steps(bar, ".... x... .... x...", 44, 0.3)
        if bar % 4 == 3:
            kit.steps(bar, ".... .... ..g. x.g.", 38, 0.3)
        if bar % 8 == 0 and SECTIONS[bar] != "a":
            kit.play(bar, 0, 36, 0.32, 1)
    kit.play(end, 0, 51, 0.36, 4)
    kit.play(end, 0, 36, 0.34, 1)

    seconds = grid.time(end) + 4.0
    mix = Mix(room_seconds=1.3, room_brightness=0.4, room_return_db=-7.0, speech_dip_db=2.5, warmth=1.3, glue=(-22.0, 1.8, 0.02, 0.25))
    stems = [
        Stem("piano", I.steinway_grand(), piano.notes, gain_db=0, pan=-0.1, eq=(("highpass", 80), *I.SOFT_GRAND), send=0.15, width=1.1),
        Stem("bass", I.strings("Solo Contrabass", "Pizz", release=0.25), bass.notes, gain_db=-1, eq=(("highpass", 32), ("lowshelf", 90, 0.7, 2.0),
             ("peak", 700, 1.0, -2.5)), send=0.06, compress=(-22, 3.0, 0.005, 0.12)),
        Stem("kit", I.brush_kit(), kit.notes, gain_db=-9, pan=0.15, eq=(("highpass", 60), ("peak", 3500, 1.0, -3.0), ("highshelf", 7000, 0.7, -5.0)),
             send=0.12, compress=(-24, 2.0, 0.01, 0.15)),
    ]
    beats = [grid.time(bar) for bar in range(BARS)]
    return Track("cornerBooth", "Corner Booth", TEMPO, 4, BARS, seconds, stems, mix, under_speech=True, beats=beats)
