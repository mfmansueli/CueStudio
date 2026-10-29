"""Morning Notes, for vlogs and everyday talk: a nylon-string guitar strumming a folk pattern (down, down-up, up-down-up), an upright
bass, brushes on a soft kit from the second part, a glockenspiel picking out a few notes over the chorus, and a last strum left to ring.
G major, 92 BPM, under speech (soft brushes, no shaker, the glockenspiel sparse and high)."""
from __future__ import annotations

from typing import List

import instruments as I
from score import Chord, Grid, Part, bass_key, phrase, voice
from track import Mix, Stem, Track

TEMPO = 92
INTRO = ["G", "Cadd9", "Em7", "D"]
A = ["G", "D/F#", "Em7", "Cadd9", "G", "D", "Cadd9", "D"]
B = ["Em7", "Cadd9", "G", "D", "Em7", "Cadd9", "Am7", "D"]
CHORDS = INTRO + A + B + A + ["Cadd9", "D", "G", "G"]
SECTIONS = ["intro"] * 4 + ["a"] * 8 + ["b"] * 8 + ["a2"] * 8 + ["outro"] * 2 + ["end"] * 2
BARS = len(CHORDS)
# The strum: (beat, down?, level) — down on one, down-up on two, up on three's "and", down-up on four.
STRUM = [(0, True, 1.0), (1, True, 0.8), (1.5, False, 0.62), (2.5, False, 0.66), (3, True, 0.78), (3.5, False, 0.6)]


def make() -> Track:
    grid = Grid(TEMPO, start=0.05)
    chords = [Chord.parse(symbol) for symbol in CHORDS]

    guitar = Part(grid, 601, drift_ms=6, jitter_ms=3, spread=0.06, accent=0.1)
    shape: List[int] = []
    for bar, chord in enumerate(chords):
        part = SECTIONS[bar]
        low = bass_key(chord, 40)
        shape = voice(chord, 50, 67, shape or None, count=4)
        if part == "end":
            if bar == BARS - 2:
                guitar.chord(bar, 0, [low] + shape + [shape[-1] + 5], 0.5, 8, strum=0.045)
            continue
        level = (0.42 if part == "intro" else 0.48) * phrase(bar, 4, 0.06)
        for beat, down, weight in STRUM:
            strings = [low] + shape if down else shape[-3:]
            guitar.chord(bar, beat, strings, level * weight, 1.2, strum=0.011 if down else 0.008, up=not down)

    bass = Part(grid, 602, drift_ms=4, jitter_ms=2.5, spread=0.05)
    for bar, chord in enumerate(chords):
        part = SECTIONS[bar]
        if part == "intro":
            continue
        root = bass_key(chord, 28)
        fifth = root + 7 if root + 7 <= 43 else root - 5
        if part == "end":
            if bar == BARS - 2:
                bass.play(bar, 0, root, 0.5, 6)
            continue
        bass.play(bar, 0, root, 0.6, 1.6)
        bass.play(bar, 2, fifth, 0.5, 1.2)
        if part != "outro":
            bass.play(bar, 3.5, root, 0.36, 0.5)

    kit = Part(grid, 603, drift_ms=1.5, jitter_ms=2, spread=0.07, accent=0.12)
    for bar in range(12, BARS - 2):
        part = SECTIONS[bar]
        kit.steps(bar, "x... .... x.x. ....", 36, 0.46)
        kit.steps(bar, ".... x... .... x...", 38, 0.36)
        if part in ("b", "a2"):
            kit.steps(bar, "x.x. x.x. x.x. x.x.", 42, 0.26)
    kit.play(BARS - 2, 0, 36, 0.4, 1)

    glock = Part(grid, 604, drift_ms=3, jitter_ms=2, spread=0.05)
    hook = [(0.5, 2), (1.5, 1), (2, 2), (3, 0)]
    for bar in range(12, 20):
        if bar % 2 == 0:
            tones = sorted(voice(chords[bar], 79, 91, None, count=3))
            for beat, index in hook:
                glock.play(bar, beat, tones[index], 0.34, 1)
    glock.play(BARS - 2, 0.5, 91, 0.3, 4)

    seconds = grid.time(BARS) + 3.0
    mix = Mix(room_seconds=1.4, room_brightness=0.45, room_return_db=-5.0, speech_dip_db=2.5, warmth=1.1)
    stems = [
        Stem("guitar", I.nylon_guitar(), guitar.notes, gain_db=0, width=1.0, eq=(("highpass", 75), ("peak", 250, 1.0, -2.0), ("peak", 3200, 0.9, -2.5),
             ("lowpass", 9500)), send=0.15, compress=(-20, 2.0, 0.008, 0.15)),
        Stem("bass", I.strings("Solo Contrabass", "Pizz", release=0.25), bass.notes, gain_db=-3, eq=(("highpass", 32), ("lowshelf", 90, 0.7, 2.0),
             ("peak", 700, 1.0, -2.5)), send=0.06, compress=(-24, 3.0, 0.005, 0.12)),
        Stem("kit", I.brush_kit(), kit.notes, gain_db=-9, eq=(("highpass", 40), ("peak", 3500, 1.0, -2.0), ("highshelf", 7000, 0.7, -4.0)), send=0.12,
             compress=(-24, 2.0, 0.01, 0.15)),
        Stem("glock", I.glockenspiel(), glock.notes, gain_db=-14, pan=0.3, eq=(("highpass", 500),), send=0.35),
    ]
    beats = [grid.time(bar) for bar in range(BARS)]
    return Track("morningNotes", "Morning Notes", TEMPO, 4, BARS, seconds, stems, mix, under_speech=True, beats=beats)
