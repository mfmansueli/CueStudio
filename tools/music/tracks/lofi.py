"""Lo-fi hip-hop, for vlogs, study and commentary: a muffled upright piano, darkened like a felt piano, playing jazzy chords a
little behind the beat, an upright bass, brushes
on a soft kit with swung sixteenths (or no drums at all), a soft vibraphone line in the last part and tape wow. F major, 82 BPM, under
speech (the keys sit low, the vibraphone is sparse). No record crackle and no hard kit: the owner heard both as noise (29/10)."""
from __future__ import annotations

from typing import List, Tuple

import instruments as I
from score import Chord, Grid, Part, phrase, voice
from track import Mix, Stem, Track

TEMPO = 82
# Each bar's chords as (beat, symbol).
LOOP_A = [[(0, "Fmaj9")], [(0, "Em7"), (2, "A7b9")], [(0, "Dm9")], [(0, "Gm9"), (2, "C13")]]
LOOP_B = [[(0, "Bbmaj9")], [(0, "Am7")], [(0, "Gm9")], [(0, "C7sus4"), (2, "C13")]]
FORM: List[Tuple[str, List[List[Tuple[float, str]]]]] = (
    [("intro", LOOP_A[:2])] + [("a", LOOP_A * 2)] + [("b", LOOP_B * 2)] + [("a2", LOOP_A * 2)] + [("outro", LOOP_A[:2])]
    + [("end", [[(0, "Fmaj9")]])]
)


def make(drums: bool = True) -> Track:
    grid = Grid(TEMPO, swing=0.58, swing_unit=0.25, start=0.05)
    bars: List[Tuple[str, List[Tuple[float, Chord]]]] = []
    for name, loop in FORM:
        for changes in loop:
            bars.append((name, [(beat, Chord.parse(symbol)) for beat, symbol in changes]))
    count = len(bars)

    keys = Part(grid, 101, drift_ms=12, jitter_ms=4, spread=0.07)
    bass = Part(grid, 102, drift_ms=8, jitter_ms=3, spread=0.06)
    voicing: List[int] = []
    for bar, (name, changes) in enumerate(bars):
        for index, (beat, chord) in enumerate(changes):
            until = changes[index + 1][0] if index + 1 < len(changes) else 4
            voicing = voice(chord, 53, 72, voicing or None, count=4)
            if name == "end":
                keys.chord(bar, 0, voicing, 0.5, 7, strum=0.03)
                bass.play(bar, 0, _low(chord), 0.6, 6)
                continue
            level = 0.5 * phrase(bar, 4, 0.06)
            hits = [(beat, until - beat - 0.15)] if until - beat <= 2 else [(beat, 1.3), (beat + 1.5, 0.9), (beat + 2.5, until - beat - 2.65)]
            for start, length in hits:
                keys.chord(bar, start, voicing, level * (1.0 if start == beat else 0.82), length, strum=0.012)
            root = _low(chord)
            if name in ("intro", "outro"):
                bass.play(bar, beat, root, 0.5, until - beat - 0.2)
            else:
                bass.play(bar, beat, root, 0.62, 1.3)
                if until - beat > 2:
                    bass.play(bar, beat + 1.75, root, 0.42, 0.3)
                    bass.play(bar, beat + 2.5, root + 7 if root + 7 <= 52 else root - 5, 0.5, 1.2)

    # Brushes: a soft bass drum, the snare tapped on two and four, the hi-hat closed in eighths and touched by the foot.
    kit = Part(grid, 103, drift_ms=1.5, jitter_ms=2, spread=0.07, accent=0.1)
    for bar, (name, _) in enumerate(bars):
        if name not in ("a", "b", "a2"):
            continue
        turn = bar % 4 == 3
        kit.steps(bar, "x... .... ..x. ...." if bar % 2 == 0 else "x... ...x ..x. ....", 36, 0.5)
        kit.steps(bar, ".... x... .... x..g" if not turn else ".... x... ..g. x.g.", 38, 0.4)
        kit.steps(bar, "x.x. x.x. x.x. x.x." if name != "b" else "x.xg x.x. x.xg x.x.", 42, 0.3)
        kit.steps(bar, "..x. ..x. ..x. ..x.", 44, 0.28)
    kit.play(count - 1, 0, 36, 0.45, 1)

    vibes = Part(grid, 104, drift_ms=10, jitter_ms=4, spread=0.06)
    motif = [(0.5, 2), (1.25, 1), (2.5, 3)]
    for bar, (name, changes) in enumerate(bars):
        if name != "a2" or bar % 2 == 1:
            continue
        tones = sorted(voice(changes[0][1], 69, 84, None, count=4))
        for beat, index in motif:
            vibes.play(bar, beat, tones[index], 0.4, 1.5)

    seconds = grid.time(count) + 4.0
    mix = Mix(room_seconds=1.2, room_brightness=0.3, room_return_db=-6.0, speech_dip_db=2.5, warmth=1.8,
              bus_eq=(("lowpass", 9500, 0.6), ("lowshelf", 120, 0.7, 1.5)), glue=(-22.0, 2.2, 0.015, 0.2))
    stems = [
        Stem("keys", I.knight_upright(), keys.notes, gain_db=0, eq=(("highpass", 90), ("lowshelf", 250, 0.7, 2.0), ("peak", 2400, 0.9, -4.0),
             ("lowpass", 3400, 0.7)), send=0.18, width=1.0,
             wow=(9.0, 0.55), duck=("kit", 1.0) if drums else None),
        Stem("bass", I.strings("Solo Contrabass", "Pizz", release=0.2), bass.notes, gain_db=-2, eq=(("highpass", 35), ("lowshelf", 80, 0.7, 2.5),
             ("peak", 800, 1.0, -3.0)), send=0.05, compress=(-24, 3.0, 0.004, 0.1)),
        Stem("vibes", I.vibraphone(), vibes.notes, gain_db=-9, pan=0.3, eq=(("highpass", 200),), send=0.3, wow=(9.0, 0.55)),
    ]
    if drums:
        stems.insert(2, Stem("kit", I.brush_kit(), kit.notes, gain_db=-8, eq=(("highpass", 40), ("peak", 3500, 1.0, -2.0),
                                                                              ("highshelf", 7000, 0.7, -4.0)), send=0.12, compress=(-24, 2.0, 0.01, 0.15)))
    beats = [grid.time(bar) for bar in range(count)]
    return Track("lofi" if drums else "lofi-nodrums", "Lo-fi", TEMPO, 4, count, seconds, stems, mix, under_speech=True, beats=beats)


def _low(chord: Chord) -> int:
    """The chord's bass note between E1 and E2… D#3 (28–51)."""
    key = chord.bass + 36
    return key - 12 if key > 51 else key
