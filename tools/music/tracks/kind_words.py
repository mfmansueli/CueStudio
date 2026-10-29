"""Kind Words, a tender waltz for weddings, family moments and thank-yous: a grand piano flowing in broken chords, cellos and violas
holding the harmony, a harp in the second part, and the violins taking a short melody only in the intro and the ending. F major, 3/4 at
84 BPM, under speech (no melody while someone talks; the strings darkened)."""
from __future__ import annotations

from typing import List

import instruments as I
from score import Chord, Grid, Part, bass_key, phrase, voice
from track import Mix, Stem, Track

TEMPO = 84
A = ["F", "C/E", "Dm7", "Bbmaj7", "F/A", "Gm7", "C7sus4", "C7"]
B = ["Bb", "C/Bb", "Am7", "Dm7", "Gm7", "C7", "F", "F"]
CHORDS = A[:4] + A + B + A + B + ["F", "F"]
SECTIONS = ["intro"] * 4 + ["a"] * 8 + ["b"] * 8 + ["a2"] * 8 + ["b2"] * 8 + ["end"] * 2
BARS = len(CHORDS)
# The violins' melody in the intro and the last bars: (bar, beat, key, beats).
MELODY = [(0, 0, 72, 2), (0, 2, 69, 1), (1, 0, 67, 3), (2, 0, 69, 1), (2, 1, 72, 1), (2, 2, 74, 1), (3, 0, 72, 3)]
# The broken chord in six eighths: which voice plays (0 is the bass).
FLOW = [0, 2, 3, 1, 3, 2]


def make() -> Track:
    grid = Grid(TEMPO, beats=3, start=0.05)
    chords = [Chord.parse(symbol) for symbol in CHORDS]
    end = BARS - 2

    piano = Part(grid, 1501, drift_ms=10, jitter_ms=4, spread=0.06, accent=0.12)
    shape: List[int] = []
    for bar in range(end):
        chord = chords[bar]
        shape = sorted(voice(chord, 55, 72, shape or None, count=3))
        notes = [bass_key(chord, 36)] + shape
        level = 0.38 * phrase(bar, 4, 0.08)
        for step, index in enumerate(FLOW):
            piano.play(bar, step * 0.5, notes[index], level * (1.12 if step == 0 else 1.0), 2.5 if step == 0 else 1.2)
    piano.chord(end, 0, [41, 53, 60, 65, 69, 72], 0.42, 7, strum=0.05)

    cellos = Part(grid, 1502, drift_ms=10, jitter_ms=6, spread=0.04)
    violas = Part(grid, 1503, drift_ms=10, jitter_ms=6, spread=0.04)
    held: List[int] = []
    for bar in range(4, end):
        part = SECTIONS[bar]
        held = voice(chords[bar], 53, 67, held or None, count=2)
        level = {"a": 0.32, "b": 0.4, "a2": 0.36, "b2": 0.44}[part]
        cellos.play(bar, 0, bass_key(chords[bar], 36) + 12 if bass_key(chords[bar], 36) < 41 else bass_key(chords[bar], 36), level, 3.1)
        violas.chord(bar, 0, held, level * 0.9, 3.1)
    cellos.play(end, 0, 41, 0.4, 6)
    violas.chord(end, 0, [57, 60], 0.36, 6)

    harp = Part(grid, 1504, drift_ms=3, jitter_ms=2, spread=0.05)
    for bar in range(20, end):
        if SECTIONS[bar] not in ("a2", "b2"):
            continue
        tones = sorted(voice(chords[bar], 60, 79, None, count=4))
        for step, key in enumerate(tones + tones[-2:0:-1]):
            harp.play(bar, step * 0.5, key, 0.32 + 0.02 * (step % 3), 2)

    violins = Part(grid, 1505, drift_ms=8, jitter_ms=5, spread=0.04)
    for bar, beat, key, beats in MELODY:
        violins.play(bar, beat, key, 0.42, beats * 1.02)
    for bar, beat, key, beats in MELODY:
        violins.play(bar + end - 4, beat, key, 0.44, beats * 1.02)
    violins.chord(end, 0, [69, 72], 0.38, 6)

    seconds = grid.time(end) + 4.5
    mix = Mix(room_seconds=2.4, room_brightness=0.4, room_return_db=-4.5, speech_dip_db=2.5, warmth=1.2)
    stems = [
        Stem("piano", I.steinway_grand(), piano.notes, gain_db=0, eq=(("highpass", 60), *I.SOFT_GRAND), send=0.3, width=1.1),
        Stem("cellos", I.strings("Cello Section", "susvib", release=0.9), cellos.notes, gain_db=-5, pan=0.25, eq=(("highpass", 50), ("lowpass", 2500, 0.7)),
             send=0.4),
        Stem("violas", I.strings("Viola Section", "susvib", release=0.9), violas.notes, gain_db=-7, pan=-0.2, eq=(("highpass", 120),
             ("lowpass", 2000, 0.7), ("lowpass", 2000, 0.7)), send=0.42),
        Stem("harp", I.harp(), harp.notes, gain_db=-10, pan=0.3, eq=(("highpass", 120), ("highshelf", 3000, 0.7, -4.0)), send=0.4),
        Stem("violins", I.strings("Violin Section", "susVib", release=0.9), violins.notes, gain_db=-6, pan=-0.3, eq=(("highpass", 250),
             ("highshelf", 3000, 0.7, -4.0)), send=0.45),
    ]
    beats = [grid.time(bar) for bar in range(BARS)]
    return Track("kindWords", "Kind Words", TEMPO, 3, BARS, seconds, stems, mix, under_speech=True, beats=beats)
