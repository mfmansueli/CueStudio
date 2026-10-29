"""Back Porch, warm folk-pop for DIY, travel and family videos: a nylon guitar fingerpicking the verse and strumming the chorus, an
upright bass, a cajon keeping a soft groove with claps joining in the chorus, held violins under the chorus and a glockenspiel answering
between phrases. G major, 104 BPM, under speech (the guitar's top darkened, the claps and the glockenspiel kept low and sparse)."""
from __future__ import annotations

from typing import List

import instruments as I
from score import Chord, Grid, Part, bass_key, phrase, voice
from track import Mix, Stem, Track

TEMPO = 104
VERSE = ["G", "D/F#", "Em7", "Cadd9", "G", "D/F#", "Cadd9", "D"]
CHORUS = ["C", "G/B", "Am7", "D", "C", "G", "Dsus4", "D"]
CHORDS = VERSE[:4] + VERSE + CHORUS + VERSE + CHORUS + ["G", "G"]
SECTIONS = ["intro"] * 4 + ["verse"] * 8 + ["chorus"] * 8 + ["verse2"] * 8 + ["chorus2"] * 8 + ["end"] * 2
BARS = len(CHORDS)
# Fingerpicking in eighths: which voice of the chord each eighth plays (0 is the bass).
PICK = [0, 2, 1, 3, 0, 2, 1, 2]
# The chorus strum: (beat, down?, level).
STRUM = [(0, True, 1.0), (1, True, 0.7), (1.5, False, 0.55), (2.5, False, 0.6), (3, True, 0.75), (3.5, False, 0.55)]
# The glockenspiel's answer after each four bars: (beat, step in the chord's top notes).
ANSWER = [(2, 2), (2.5, 1), (3, 0), (3.5, 1)]


def make() -> Track:
    grid = Grid(TEMPO, swing=0.54, swing_unit=0.25, start=0.05)
    chords = [Chord.parse(symbol) for symbol in CHORDS]
    end = BARS - 2

    guitar = Part(grid, 1201, drift_ms=5, jitter_ms=3, spread=0.07, accent=0.12)
    bass = Part(grid, 1202, drift_ms=3, jitter_ms=2, spread=0.05)
    shape: List[int] = []
    for bar in range(end):
        chord, part = chords[bar], SECTIONS[bar]
        root = bass_key(chord, 40)
        shape = sorted(voice(chord, 52, 67, shape or None, count=3))
        notes = [root] + shape
        if part in ("intro", "verse", "verse2"):
            for step, index in enumerate(PICK):
                guitar.play(bar, step * 0.5, notes[index], (0.5 if index == 0 else 0.42) * phrase(bar, 4, 0.06), 1.2 if index == 0 else 0.9)
        else:
            for beat, down, weight in STRUM:
                guitar.chord(bar, beat, notes if down else shape, 0.46 * weight, 1, strum=0.011, up=not down)
        if part != "intro":
            low = bass_key(chord, 31)
            if part.startswith("verse"):
                bass.play(bar, 0, low, 0.56, 1.8)
                bass.play(bar, 2.5, low + 7 if low + 7 <= 47 else low - 5, 0.44, 1.2)
            else:
                for beat, level in ((0, 0.6), (1.5, 0.46), (2, 0.52), (3, 0.48)):
                    bass.play(bar, beat, low, level, 0.8)
    guitar.chord(end, 0, [43, 47, 50, 55, 59, 67], 0.5, 8, strum=0.035)
    bass.play(end, 0, 31, 0.56, 6)

    percussion = Part(grid, 1203, drift_ms=1.5, jitter_ms=2, spread=0.08, accent=0.15)
    claps = Part(grid, 1204, drift_ms=1, jitter_ms=3, spread=0.1)
    for bar in range(4, end):
        part = SECTIONS[bar]
        if part.startswith("verse"):
            percussion.steps(bar, "x... ..x. x... ....", 36, 0.48)
            percussion.steps(bar, ".... x... .... x..g", 38, 0.36)
            percussion.steps(bar, "x.x. x.x. x.x. x.x.", 82, 0.24)
        else:
            percussion.steps(bar, "x... ..x. x.x. ....", 36, 0.54)
            percussion.steps(bar, ".... x... .... x...", 38, 0.4)
            percussion.steps(bar, "x.x. x.x. x.x. x.x.", 82, 0.28)
            claps.steps(bar, ".... x... .... x...", 39, 0.5)
    percussion.play(end, 0, 36, 0.5, 1)

    violins = Part(grid, 1205, drift_ms=8, jitter_ms=5, spread=0.04)
    glock = Part(grid, 1206, drift_ms=2, jitter_ms=2, spread=0.05)
    held: List[int] = []
    for bar in range(4, end):
        part = SECTIONS[bar]
        if part.startswith("chorus"):
            held = voice(chords[bar], 62, 74, held or None, count=2)
            violins.chord(bar, 0, held, 0.36 if part == "chorus" else 0.42, 4.1)
        if bar % 4 == 3 and part != "intro":
            tops = sorted(voice(chords[bar], 74, 86, None, count=3))
            for beat, index in ANSWER:
                glock.play(bar, beat, tops[index], 0.32, 1)
    violins.chord(end, 0, [67, 71, 74], 0.38, 6)
    glock.play(end, 0.5, 79, 0.3, 4)

    seconds = grid.time(end) + 3.5
    mix = Mix(room_seconds=1.4, room_brightness=0.45, room_return_db=-6.5, speech_dip_db=2.5, warmth=1.2)
    stems = [
        Stem("guitar", I.nylon_guitar(), guitar.notes, gain_db=0, eq=(("highpass", 80), ("peak", 250, 0.9, -1.5), ("peak", 2800, 0.8, -4.0),
             ("highshelf", 5000, 0.7, -3.0)), send=0.15, width=1.1),
        Stem("bass", I.strings("Solo Contrabass", "Pizz", release=0.25), bass.notes, gain_db=-2, eq=(("highpass", 32), ("lowshelf", 90, 0.7, 2.0),
             ("peak", 700, 1.0, -2.5)), send=0.05, compress=(-22, 3.0, 0.005, 0.12)),
        Stem("percussion", I.folk_percussion(), percussion.notes, gain_db=-7, eq=(("highpass", 45), ("peak", 3000, 1.0, -3.0), ("highshelf", 7000, 0.7, -5.0)),
             send=0.12, compress=(-22, 2.5, 0.006, 0.12)),
        Stem("claps", I.groove_percussion(), claps.notes, gain_db=-14, eq=(("highpass", 250), ("lowpass", 6000)), send=0.3, width=0.8),
        Stem("violins", I.strings("Violin Section", "susVib", release=0.8), violins.notes, gain_db=-10, pan=-0.25, eq=(("highpass", 250),
             ("highshelf", 3000, 0.7, -4.0)), send=0.35),
        Stem("glock", I.glockenspiel(), glock.notes, gain_db=-14, pan=0.3, eq=(("highpass", 500), ("highshelf", 6000, 0.7, -3.0)), send=0.3),
    ]
    beats = [grid.time(bar) for bar in range(BARS)]
    return Track("backPorch", "Back Porch", TEMPO, 4, BARS, seconds, stems, mix, under_speech=True, beats=beats)
