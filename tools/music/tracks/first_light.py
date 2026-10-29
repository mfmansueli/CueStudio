"""First Light, a cinematic build for reveals and trailers: a piano ostinato in the dark, strings rising under it, timpani and a concert
bass drum taking the pulse, horns carrying the theme, a cymbal swelling into the climax with trombones and the whole orchestra, and the
minor key opening onto D major for the last chord. 84 BPM, not under speech (a montage or a reveal: it builds and hits)."""
from __future__ import annotations

from typing import List

import instruments as I
from score import Chord, Grid, Part, bass_key, voice
from track import Mix, Stem, Track

TEMPO = 84
CHORDS = ["Dm", "Bb", "F", "C", "Dm", "Bb", "F", "C", "Dm", "Bb", "Gm", "A", "Bb", "F/A", "Gm", "A", "D", "D"]
SECTIONS = ["intro"] * 4 + ["rise"] * 4 + ["build"] * 4 + ["full"] * 4 + ["end"] * 2
BARS = len(CHORDS)
# The horns' theme over the build and the climax: (bar, beat, key, beats).
THEME = [(8, 0, 62, 2), (8, 2, 65, 1), (8, 3, 69, 1), (9, 0, 70, 3), (9, 3, 69, 1), (10, 0, 67, 2), (10, 2, 65, 1), (10, 3, 62, 1),
         (11, 0, 64, 3), (11, 3, 61, 1),
         (12, 0, 70, 2), (12, 2, 69, 1), (12, 3, 65, 1), (13, 0, 69, 3), (13, 3, 72, 1), (14, 0, 74, 2), (14, 2, 72, 1), (14, 3, 70, 1),
         (15, 0, 69, 2), (15, 2, 73, 2), (16, 0, 74, 8)]
END = 16


def make() -> Track:
    grid = Grid(TEMPO, start=0.05)
    chords = [Chord.parse(symbol) for symbol in CHORDS]
    beat_seconds = 60 / TEMPO

    piano = Part(grid, 701, drift_ms=5, jitter_ms=3, spread=0.05)
    shape: List[int] = []
    for bar in range(END):
        chord, part = chords[bar], SECTIONS[bar]
        shape = sorted(voice(chord, 57, 72, shape or None, count=3))
        level = {"intro": 0.32, "rise": 0.36, "build": 0.42, "full": 0.48}[part] + 0.02 * (bar % 4)
        for step, index in enumerate([0, 1, 2, 1, 0, 1, 2, 1]):
            piano.play(bar, step * 0.5, shape[index], level * (1.1 if step % 4 == 0 else 1.0), 0.6)
        if part == "full":
            piano.play(bar, 0, bass_key(chord, 33), 0.5, 4)
    piano.chord(END, 0, [38, 50, 57, 62, 66, 69, 74], 0.5, 10, strum=0.03)

    cellos = Part(grid, 702, drift_ms=8, jitter_ms=5, spread=0.04)
    violas = Part(grid, 703, drift_ms=8, jitter_ms=5, spread=0.04)
    violins = Part(grid, 704, drift_ms=8, jitter_ms=5, spread=0.04)
    bass = Part(grid, 705, drift_ms=6, jitter_ms=4, spread=0.04)
    pads: List[int] = []
    high: List[int] = []
    cellos.play(0, 0, 38, 0.3, 16)
    for bar in range(4, END):
        chord, part = chords[bar], SECTIONS[bar]
        pads = voice(chord, 48, 67, pads or None, count=3)
        swell = {"rise": 0.36, "build": 0.46, "full": 0.6}[part] + 0.02 * (bar % 4)
        cellos.play(bar, 0, pads[0], swell, 4.1)
        violas.chord(bar, 0, pads[1:], swell * 0.92, 4.1)
        if part in ("build", "full"):
            bass.play(bar, 0, bass_key(chord, 28), swell * 0.9, 4.1)
            high = voice(chord, 74 if part == "build" else 79, 88 if part == "build" else 93, high or None, count=2)
            violins.chord(bar, 0, high, swell * 0.85, 4.1)
    cellos.chord(END, 0, [38, 50], 0.62, 10)
    violas.chord(END, 0, [57, 62, 66], 0.6, 10)
    violins.chord(END, 0, [78, 81, 86], 0.56, 10)
    bass.play(END, 0, 26, 0.6, 10)

    horns = Part(grid, 706, drift_ms=6, jitter_ms=4, spread=0.04)
    for bar, beat, key, beats in THEME:
        horns.play(bar, beat, key, 0.48 if bar < 12 else 0.6, beats * 1.02)
    trombones = Part(grid, 707, drift_ms=6, jitter_ms=4, spread=0.04)
    for bar in range(12, END):
        trombones.chord(bar, 0, sorted(voice(chords[bar], 45, 60, None, count=3)), 0.52, 4.1)
    trombones.chord(END, 0, [38, 45, 54, 57], 0.6, 10)

    timpani = Part(grid, 708, drift_ms=2, jitter_ms=2, spread=0.06, accent=0.15)
    drums = Part(grid, 709, drift_ms=2, jitter_ms=2, spread=0.05)
    for bar in range(4, END):
        root = bass_key(chords[bar], 33)
        part = SECTIONS[bar]
        if part == "rise":
            timpani.play(bar, 0, root, 0.38, 2)
        elif part == "build" and bar < 11:
            timpani.steps(bar, "x... .... x... ....", root, 0.48)
            drums.play(bar, 0, 35, 0.5, 2)
        elif bar == 11:
            for step in range(8):
                timpani.play(bar, step * 0.5, root, 0.4 + 0.05 * step, 0.5)
            drums.play(bar, 0, 35, 0.55, 2)
        elif part == "full":
            timpani.steps(bar, "x... ..x. x... x.x.", root, 0.6)
            drums.steps(bar, "x... .... x... ....", 35, 0.66)
    timpani.play(END, 0, 38, 0.8, 6)
    drums.play(END, 0, 35, 0.85, 6)

    cymbals = Part(grid, 710, drift_ms=1, jitter_ms=1, spread=0.03)
    cymbals.play(12, -I.SWELL_PEAKS[52] / beat_seconds, 52, 0.62, 12)
    cymbals.play(12, 0, 49, 0.62, 6)
    cymbals.play(END, -I.SWELL_PEAKS[54] / beat_seconds, 54, 0.6, 4)
    cymbals.play(END, 0, 49, 0.72, 8)
    cymbals.play(END, 0, 58, 0.45, 12)

    harp = Part(grid, 711, drift_ms=1, jitter_ms=1, spread=0.04)
    for bar, top in ((11, 81), (15, 86)):
        run = sorted(voice(chords[bar], 50, top, None, count=8))
        for step, key in enumerate(run):
            harp.play(bar, 2 + step * (2 / len(run)), key, 0.35 + 0.3 * step / len(run), 2)

    seconds = grid.time(END) + 6.5
    mix = Mix(room_seconds=3.0, room_brightness=0.45, room_return_db=-2.5, glue=(-18.0, 2.0, 0.02, 0.3), warmth=1.1)
    stems = [
        Stem("piano", I.steinway_grand(), piano.notes, gain_db=-3, pan=-0.1, eq=(("highpass", 60), *I.SOFT_GRAND), send=0.25, width=1.1),
        Stem("cellos", I.strings("Cello Section", "susvib", release=0.8), cellos.notes, gain_db=-2, pan=0.25, eq=(("highpass", 45),), send=0.4),
        Stem("violas", I.strings("Viola Section", "susvib", release=0.8), violas.notes, gain_db=-4, pan=-0.2, eq=(("highpass", 100), ("highshelf", 3000, 0.7, -3.0)),
             send=0.42),
        Stem("violins", I.strings("Violin Section", "susVib", release=0.9), violins.notes, gain_db=-5, pan=-0.3, eq=(("highpass", 200), ("highshelf", 3000, 0.7, -3.0)),
             send=0.45),
        Stem("bass", I.strings("Solo Contrabass", "SusNV", release=0.8), bass.notes, gain_db=-4, eq=(("highpass", 28), ("lowpass", 1500)), send=0.25),
        Stem("horns", I.brass("F Horn", "sus", release=0.6), horns.notes, gain_db=-1, pan=0.15, eq=(("highpass", 80),), send=0.45),
        Stem("trombones", I.brass("Tenor Trombone", "sus", release=0.6), trombones.notes, gain_db=-6, pan=0.3, eq=(("highpass", 60),), send=0.4),
        Stem("timpani", I.timpani(), timpani.notes, gain_db=-3, pan=-0.15, eq=(("highpass", 35),), send=0.35),
        Stem("drums", I.cinematic_percussion(), drums.notes, gain_db=-4, eq=(("highpass", 30),), send=0.35),
        Stem("cymbals", I.cinematic_percussion(), cymbals.notes, gain_db=-9, eq=(("highpass", 200), ("highshelf", 8000, 0.7, -3.0)), send=0.4, width=1.2),
        Stem("harp", I.harp(), harp.notes, gain_db=-8, pan=0.25, eq=(("highpass", 90),), send=0.4),
    ]
    beats = [grid.time(bar) for bar in range(BARS)]
    return Track("firstLight", "First Light", TEMPO, 4, BARS, seconds, stems, mix, under_speech=False, beats=beats)
