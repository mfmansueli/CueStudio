"""Inspirational, for advice, business and education talks: a soft grand piano ostinato, pizzicato strings and an upright bass, then
string pads and a light pulse, a glockenspiel hook at the top, and back down to the piano. D major, 104 BPM, under speech (no lead line in
the voice's band while the pads play; the hook is sparse and high; the pulse kept soft)."""
from __future__ import annotations

from typing import List

import instruments as I
from score import Chord, Grid, Part, bass_key, phrase, voice
from track import Mix, Stem, Track

TEMPO = 104
INTRO = ["Dadd9", "A/C#", "Bm7", "Gmaj7"]
A = ["Dadd9", "A/C#", "Bm7", "Gmaj7", "Dadd9", "A/C#", "Bm7", "Asus4"]
B = ["Gmaj7", "A", "F#m7", "Bm7", "Gmaj7", "A", "D/F#", "Asus4"]
C = ["Dadd9", "A/C#", "Bm7", "Gmaj7", "Dadd9", "A/C#", "Gmaj7", "A"]
OUTRO = ["Gmaj7", "A", "Bm7", "Asus4"]
CHORDS = INTRO + A + B + C + OUTRO + ["Dadd9", "Dadd9"]
BARS = len(CHORDS)


def make() -> Track:
    grid = Grid(TEMPO, start=0.05)
    chords = [Chord.parse(s) for s in CHORDS]
    section = ["intro"] * 4 + ["a"] * 8 + ["b"] * 8 + ["c"] * 8 + ["outro"] * 4 + ["end"] * 2

    piano = Part(grid, 11, drift_ms=7, spread=0.05)
    left = Part(grid, 12, drift_ms=7, spread=0.04)
    upper: List[int] = []
    for bar, chord in enumerate(chords):
        upper = voice(chord, 62, 81, upper or None)
        shape = phrase(bar, 4, 0.1)
        if section[bar] == "end":
            if bar == BARS - 2:
                piano.chord(bar, 0, upper + [upper[-1] + 12], 0.42, 8, strum=0.02)
                left.chord(bar, 0, [bass_key(chord, 26), bass_key(chord, 26) + 12], 0.45, 8)
            continue
        soft = {"intro": 0.34, "a": 0.38, "b": 0.36, "c": 0.4, "outro": 0.34}[section[bar]]
        order = [0, 2, 1, 3, 2, 1, 3, 2]
        for step, index in enumerate(order):
            # Pedal down through the bar: each note rings until the chord changes.
            piano.play(bar, step * 0.5, upper[index], soft * shape * (1.08 if step % 2 == 0 else 0.94), 4 - step * 0.5)
        low = bass_key(chord, 38)
        left.play(bar, 0, low, 0.46 * shape, 4)
        if section[bar] in ("intro", "a", "outro"):
            # The chord's fifth (not the bass note's: on A/C# that would be a G#).
            fifth = 43 + ((chord.root + 7) - 43) % 12
            left.play(bar, 2, fifth, 0.36 * shape, 2)

    pizz = Part(grid, 21, drift_ms=5, spread=0.07)
    bass = Part(grid, 22, drift_ms=4, spread=0.05)
    cellos = Part(grid, 23, drift_ms=5, spread=0.06)
    violas = Part(grid, 24, drift_ms=5, spread=0.05)
    violins = Part(grid, 25, drift_ms=5, spread=0.05)
    pads: List[int] = []
    high: List[int] = []
    for bar, chord in enumerate(chords):
        part = section[bar]
        root = bass_key(chord, 31)
        if part in ("a", "b", "c"):
            tops = voice(chord, 67, 79, None, count=3)
            for step in (1, 3, 5, 7):
                pizz.chord(bar, step * 0.5, tops if step in (3, 7) else tops[1:], 0.5 * phrase(bar), 0.4)
        if part == "a":
            for beat, level in ((0, 0.62), (1.5, 0.48), (2, 0.55)):
                bass.play(bar, beat, root, level, 0.9)
        elif part in ("b", "c"):
            for step in range(8):
                bass.play(bar, step * 0.5, root, (0.6 if step % 2 == 0 else 0.44) * phrase(bar), 0.45)
        elif part == "outro":
            bass.play(bar, 0, root, 0.5, 3.5)
        elif part == "end" and bar == BARS - 2:
            bass.play(bar, 0, root, 0.5, 6)
        if part in ("b", "c", "outro") or (part == "end" and bar == BARS - 2):
            pads = voice(chord, 50, 69, pads or None, count=3)
            level = {"b": 0.45, "c": 0.58, "outro": 0.42, "end": 0.4}[part]
            beats = 8 if part == "end" else 4.1
            cellos.play(bar, 0, pads[0], level, beats)
            violas.chord(bar, 0, pads[1:], level * 0.95, beats)
        if part == "c" or (part == "end" and bar == BARS - 2):
            high = voice(chord, 74, 88, high or None, count=2)
            violins.chord(bar, 0, high, 0.5 if part == "c" else 0.4, 8 if part == "end" else 4.1)

    glock = Part(grid, 31, drift_ms=3, spread=0.05)
    hook = [(0, 2), (1.5, 1), (2.5, 0), (3, 1)]
    for bar in range(20, 28):
        tones = voice(chords[bar], 79, 91, None, count=3)
        for beat, index in hook if bar % 2 == 0 else hook[:2]:
            glock.play(bar, beat, tones[index], 0.42, 1)

    harp = Part(grid, 41, drift_ms=2, jitter_ms=1, spread=0.05)
    scale = [62, 64, 66, 67, 69, 71, 73]
    for bar in (3, 11, 19):
        run = [k + 12 * octave for octave in range(2) for k in scale] + [86]
        for step, key in enumerate(run):
            harp.play(bar, 2 + step * (2 / len(run)), key, 0.35 + 0.25 * step / len(run), 2)
    end = BARS - 2
    for step, key in enumerate(sorted(voice(chords[end], 50, 86, None, count=6))):
        harp.play(end, step * 0.25, key, 0.45, 6)

    percussion = Part(grid, 51, drift_ms=1.5, jitter_ms=1.5, spread=0.1, accent=0.25)
    for bar in range(4, 28):
        percussion.steps(bar, "xgxg xgxg" if bar < 12 else "Xgxg Xgxg", 70, 0.42, unit=0.5)
        if bar >= 12:
            percussion.steps(bar, ". x . x", 54, 0.4, unit=1)
    for bar in (12, 20):
        percussion.play(bar, 0, 49, 0.45, 4)
    percussion.play(28, 0, 49, 0.35, 4)

    kit = Part(grid, 61, drift_ms=1, jitter_ms=1, spread=0.05, accent=0.2)
    claps = Part(grid, 62, drift_ms=1, jitter_ms=2.5, spread=0.08)
    for bar in range(12, 28):
        last = bar in (19, 27)
        kit.steps(bar, "x... .... x... ...." if bar < 20 else "x... .... x.x. ....", 36, 0.62)
        if bar >= 20:
            kit.steps(bar, "x.x. x.x. x.x. x.x." if not last else "x.x. x.x. x.x. ....", 42, 0.32)
        if last:
            kit.steps(bar, ".... .... .... xxXX", 38, 0.4, loud=1.1)
        claps.steps(bar, ".... x... .... x...", 39, 0.55)
    kit.play(28, 0, 36, 0.6, 1)
    kit.play(BARS - 2, 0, 36, 0.55, 1)

    seconds = grid.time(BARS) + 3.0
    mix = Mix(room_seconds=2.2, room_brightness=0.45, room_return_db=-3.0, speech_dip_db=2.0, warmth=1.1)
    stems = [
        Stem("piano", I.steinway_grand(), piano.notes, gain_db=0, eq=(("highpass", 70), ("peak", 320, 0.9, -2.0), ("peak", 2600, 0.8, -3.0),
             ("highshelf", 5000, 0.7, -4.0), *I.SOFT_GRAND),
             send=0.22, width=1.1),
        Stem("piano-left", I.steinway_grand(), left.notes, gain_db=-5, eq=(("highpass", 35), ("peak", 250, 1.0, -1.5), *I.SOFT_GRAND), send=0.18),
        Stem("pizz", I.strings("Violin Section", "Pizz", release=0.3), pizz.notes, gain_db=-9, pan=-0.35, eq=(("highpass", 180),), send=0.3),
        Stem("bass", I.strings("Solo Contrabass", "Pizz", release=0.25), bass.notes, gain_db=-4, eq=(("highpass", 32), ("lowshelf", 90, 0.7, 2.0),
             ("peak", 700, 1.0, -2.0)), send=0.08, compress=(-22, 3.0, 0.005, 0.12), duck=("kit", 3.0)),
        Stem("cellos", I.strings("Cello Section", "susvib", release=0.6), cellos.notes, gain_db=-8, pan=0.25, eq=(("highpass", 60), ("peak", 2500, 0.8, -2.5), ("highshelf", 3000, 0.7, -4.0)),
             send=0.35),
        Stem("violas", I.strings("Viola Section", "susvib", release=0.6), violas.notes, gain_db=-9, pan=-0.2, eq=(("highpass", 120), ("peak", 2800, 0.8, -3.0), ("highshelf", 3000, 0.7, -6.0)),
             send=0.38),
        Stem("violins", I.strings("Violin Section", "susVib", release=0.7), violins.notes, gain_db=-10, pan=-0.3, eq=(("highpass", 250), ("peak", 3000, 0.8, -3.0), ("highshelf", 3000, 0.7, -6.0)),
             send=0.42),
        Stem("glock", I.glockenspiel(), glock.notes, gain_db=-15, pan=0.35, eq=(("highpass", 400),), send=0.4),
        Stem("harp", I.harp(), harp.notes, gain_db=-10, pan=0.2, eq=(("highpass", 90),), send=0.35),
        Stem("kit", I.drum_kit("mid"), kit.notes, gain_db=-9, eq=(("highpass", 35), ("peak", 400, 1.0, -3.0), ("highshelf", 8000, 0.7, -2.0)), send=0.12,
             compress=(-18, 3.0, 0.004, 0.12)),
        Stem("claps", I.groove_percussion(), claps.notes, gain_db=-15, eq=(("highpass", 250), ("highshelf", 6000, 0.7, -5.0), ("lowpass", 12000)), send=0.35,
             width=0.8),
        Stem("percussion", I.orchestral_percussion(), percussion.notes, gain_db=-15, pan=0.3, eq=(("highpass", 200),), send=0.2),
    ]
    beats = [grid.time(bar) for bar in range(BARS)]
    return Track("inspire", "Inspire", TEMPO, 4, BARS, seconds, stems, mix, under_speech=True, beats=beats)
