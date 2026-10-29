"""Night Shift, chill hip-hop for gaming, commentary and reviews: a soft boom-bap groove on a dark room microphone (a cross-stick on
the backbeat instead of a hard snare), a muffled upright playing minor-ninth chords behind the beat, a long low bass, and a kalimba hook
every other bar. C minor, 86 BPM swung, under speech (the kit soft and dark, the hook between the voice's phrases)."""
from __future__ import annotations

from typing import List

import instruments as I
from score import Chord, Grid, Part, bass_key, phrase, voice
from track import Mix, Stem, Track

TEMPO = 86
LOOP = ["Cm9", "Abmaj7", "Fm9", "G7b9"]
CHORDS = LOOP + LOOP * 2 + LOOP * 2 + LOOP * 2 + LOOP + ["Cm9", "Cm9"]
SECTIONS = ["intro"] * 4 + ["a"] * 8 + ["b"] * 8 + ["a2"] * 8 + ["outro"] * 4 + ["end"] * 2
BARS = len(CHORDS)
# The kalimba's hook over two bars: (bar of the two, beat, key).
HOOK = [(0, 0.5, 72), (0, 1.0, 75), (0, 1.75, 79), (0, 2.5, 77), (0, 3.0, 75), (1, 0.5, 72), (1, 1.5, 70), (1, 2.0, 67)]


def make() -> Track:
    grid = Grid(TEMPO, swing=0.6, swing_unit=0.25, start=0.05)
    chords = [Chord.parse(symbol) for symbol in CHORDS]
    end = BARS - 2

    keys = Part(grid, 1301, drift_ms=12, jitter_ms=4, spread=0.07)
    bass = Part(grid, 1302, drift_ms=8, jitter_ms=3, spread=0.05)
    shape: List[int] = []
    for bar in range(end):
        chord, part = chords[bar], SECTIONS[bar]
        shape = voice(chord, 53, 70, shape or None, count=4)
        level = 0.46 * phrase(bar, 4, 0.06)
        keys.chord(bar, 0, shape, level, 1.6, strum=0.014)
        keys.chord(bar, 1.75, shape, level * 0.8, 0.6, strum=0.01)
        keys.chord(bar, 2.5, shape, level * 0.86, 1.3, strum=0.012)
        if part not in ("intro",):
            root = bass_key(chord, 31)
            bass.play(bar, 0, root, 0.6, 2.2)
            bass.play(bar, 2.75, root, 0.42, 0.4)
            bass.play(bar, 3.25, root + 12 if bar % 2 else root, 0.4, 0.6)
    keys.chord(end, 0, [51, 58, 62, 63, 67], 0.46, 7, strum=0.03)
    bass.play(end, 0, 36, 0.56, 6)

    kit = Part(grid, 1303, drift_ms=1.5, jitter_ms=2, spread=0.07, accent=0.12)
    for bar in range(4, end):
        part = SECTIONS[bar]
        if part == "outro":
            kit.steps(bar, "x.x. x.x. x.x. x.x.", 42, 0.24)
            continue
        turn = bar % 4 == 3
        kit.steps(bar, "x... ...x ..x. ...." if not turn else "x... ...x ..x. .x..", 36, 0.46)
        kit.steps(bar, ".... x... .... x...", 37, 0.44)
        kit.steps(bar, "x.xg x.x. x.xg x.x." if part == "b" else "x.x. x.x. x.x. x.x.", 42, 0.26)
    kit.play(end, 0, 36, 0.44, 1)

    kalimba = Part(grid, 1304, drift_ms=6, jitter_ms=3, spread=0.06)
    vibes = Part(grid, 1305, drift_ms=10, jitter_ms=4, spread=0.05)
    for bar in range(4, end):
        part = SECTIONS[bar]
        if part in ("a", "a2") and bar % 4 in (0, 1):
            for which, beat, key in HOOK:
                if which == bar % 2:
                    kalimba.play(bar, beat, key, 0.44, 1.5)
        if part == "b" and bar % 2 == 0:
            tones = sorted(voice(chords[bar], 67, 79, None, count=3))
            vibes.chord(bar, 0.5, tones, 0.3, 6)
    kalimba.play(end, 0.5, 72, 0.4, 4)
    kalimba.play(end, 1.0, 79, 0.32, 4)

    seconds = grid.time(end) + 4.0
    mix = Mix(room_seconds=1.2, room_brightness=0.3, room_return_db=-6.5, speech_dip_db=3.0, warmth=1.7,
              bus_eq=(("lowpass", 9500, 0.6), ("lowshelf", 120, 0.7, 1.5)), glue=(-22.0, 2.2, 0.015, 0.2))
    stems = [
        Stem("keys", I.knight_upright(), keys.notes, gain_db=0, eq=(("highpass", 90), ("lowshelf", 250, 0.7, 2.0), ("peak", 2400, 0.9, -4.0),
             ("lowpass", 3400, 0.7)), send=0.18, width=1.0, wow=(9.0, 0.5), duck=("kit", 1.0)),
        Stem("bass", I.strings("Solo Contrabass", "SusNV", release=0.3), bass.notes, gain_db=-2, eq=(("highpass", 30), ("lowshelf", 80, 0.7, 2.5),
             ("lowpass", 900)), send=0.04, compress=(-24, 3.0, 0.006, 0.12)),
        Stem("kit", I.drum_kit("lofi"), kit.notes, gain_db=-10, eq=(("highpass", 40), ("peak", 1800, 0.8, -4.0), ("peak", 3000, 1.0, -5.0),
             ("lowpass", 5000, 0.7)),
             send=0.1, compress=(-22, 2.5, 0.006, 0.12)),
        Stem("kalimba", I.kalimba(), kalimba.notes, gain_db=-7, pan=0.25, eq=(("highpass", 200), ("peak", 3000, 0.8, -4.0), ("lowpass", 6000)),
             send=0.25, wow=(9.0, 0.5)),
        Stem("vibes", I.vibraphone(), vibes.notes, gain_db=-11, pan=-0.3, eq=(("highpass", 200), ("peak", 3000, 0.8, -3.0)), send=0.35),
    ]
    beats = [grid.time(bar) for bar in range(BARS)]
    return Track("nightShift", "Night Shift", TEMPO, 4, BARS, seconds, stems, mix, under_speech=True, beats=beats)
