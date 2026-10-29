"""Writing the parts: a bar-and-beat grid with swing, chords voiced the way a player would (close to the last chord, no muddy low thirds),
and playing that sounds human. Research (Hennig et al. 2011) found listeners prefer timing that drifts in a correlated way to random jitter,
and drums near the grid groove best (Frühauf et al. 2013): so keys, bass and guitar drift a few milliseconds slowly, drums barely, and
velocity follows the beat (downbeats stronger) and the phrase (a rise to its middle), with a little variation note to note.
"""
from __future__ import annotations

import math
import random as _random
from dataclasses import dataclass
from typing import Dict, List, Optional, Sequence

from sampler import Note, midi

QUALITIES: Dict[str, List[int]] = {
    "": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10], "maj7": [0, 4, 7, 11], "m7": [0, 3, 7, 10], "m9": [0, 3, 7, 10, 14],
    "maj9": [0, 4, 7, 11, 14], "9": [0, 4, 7, 10, 14], "add9": [0, 4, 7, 14], "madd9": [0, 3, 7, 14], "sus2": [0, 2, 7], "sus4": [0, 5, 7],
    "6": [0, 4, 7, 9], "m6": [0, 3, 7, 9], "6/9": [0, 4, 7, 9, 14], "m7b5": [0, 3, 6, 10], "dim": [0, 3, 6], "7sus4": [0, 5, 7, 10],
    "13": [0, 4, 10, 14, 21], "7b9": [0, 4, 7, 10, 13], "m11": [0, 3, 7, 10, 14, 17],
}


@dataclass
class Chord:
    root: int
    tones: List[int]
    bass: int

    @staticmethod
    def parse(symbol: str) -> "Chord":
        """`Am7`, `Fmaj9`, `C/E`, `Bb6/9`: root, quality, an optional bass note."""
        body, slash = symbol, ""
        if "/" in symbol:
            left, right = symbol.rsplit("/", 1)
            if right[:1] in "ABCDEFG":
                body, slash = left, right
        head = body[:2] if len(body) > 1 and body[1] in "#b" else body[:1]
        root = midi(head + "0") % 12
        quality = body[len(head):]
        bass = midi(slash + "0") % 12 if slash else root
        return Chord(root, QUALITIES[quality], bass)

    def pitch_classes(self) -> List[int]:
        return [(self.root + t) % 12 for t in self.tones]


def voice(chord: Chord, low: int, high: int, previous: Optional[List[int]] = None, count: int = 4, drop_root: bool = True) -> List[int]:
    """`count` notes of the chord between `low` and `high`, moving as little as possible from `previous`. Without the root when the
    bass plays it and the chord has colour to spare; never a third below C3 (it muddies)."""
    classes = chord.pitch_classes()
    if drop_root and len(classes) > count:
        classes = [c for c in classes if c != chord.root] or classes
    candidates = [k for k in range(low, high + 1) if k % 12 in classes]
    best, best_cost = None, math.inf
    rng = _random.Random(sum(classes) * 31 + low)
    for _ in range(400):
        pick = sorted(rng.sample(candidates, min(count, len(candidates))))
        if len({k % 12 for k in pick}) < min(count, len(classes)):
            continue
        if any(b - a < 2 for a, b in zip(pick, pick[1:])) or any(b - a > 9 for a, b in zip(pick[1:], pick[2:])):
            continue
        third = (chord.root + chord.tones[1]) % 12
        if any(k < 48 and k % 12 == third for k in pick):
            continue
        cost = sum(abs(a - b) for a, b in zip(pick, previous)) if previous and len(previous) == len(pick) else abs(sum(pick) / len(pick) - (low + high) / 2)
        if cost < best_cost:
            best, best_cost = pick, cost
    return best or sorted(candidates[:count])


def bass_key(chord: Chord, lowest: int) -> int:
    """The chord's bass note at or above the key `lowest` (within the octave above it)."""
    return lowest + (chord.bass - lowest) % 12


class Drift:
    """Slow, correlated timing deviation (a few sinusoids of random phase between 0.05 and 1.5 Hz), in seconds."""

    def __init__(self, milliseconds: float, seed: int):
        rng = _random.Random(seed)
        self.parts = [(rng.uniform(0.05, 1.5), rng.uniform(0, 2 * math.pi), rng.uniform(0.3, 1.0)) for _ in range(6)]
        total = sum(a for _, _, a in self.parts)
        self.scale = milliseconds / 1000 / total * 1.6

    def at(self, t: float) -> float:
        return self.scale * sum(a * math.sin(2 * math.pi * f * t + p) for f, p, a in self.parts)


class Grid:
    """Bars and beats to seconds: `tempo` BPM, `beats` per bar, swing delaying every second `swing_unit` (0.5 straight, 0.6 a lazy
    shuffle)."""

    def __init__(self, tempo: float, beats: int = 4, swing: float = 0.5, swing_unit: float = 0.5, start: float = 0.0):
        self.tempo, self.beats, self.swing, self.swing_unit, self.start = tempo, beats, swing, swing_unit, start

    @property
    def beat_seconds(self) -> float:
        return 60 / self.tempo

    def time(self, bar: float, beat: float = 0.0) -> float:
        position = bar * self.beats + beat
        unit = self.swing_unit
        pair = math.floor(position / (2 * unit))
        within = position - pair * 2 * unit
        if self.swing != 0.5 and abs(within - unit) < 1e-6:
            within = 2 * unit * self.swing
        return self.start + (pair * 2 * unit + within) * self.beat_seconds

    def bars_seconds(self, bars: float) -> float:
        return self.start + bars * self.beats * self.beat_seconds


class Part:
    """The notes of one instrument, written in bars and beats and played humanly: `drift_ms` of slow timing deviation, `jitter_ms` of
    note-to-note, velocity shaped by the beat and varied by `spread`."""

    def __init__(self, grid: Grid, seed: int, drift_ms: float = 6.0, jitter_ms: float = 1.5, spread: float = 0.06, accent: float = 0.12):
        self.grid = grid
        self.notes: List[Note] = []
        self.drift = Drift(drift_ms, seed)
        self.rng = _random.Random(seed * 7 + 1)
        self.jitter = jitter_ms / 1000
        self.spread = spread
        self.accent = accent

    def play(self, bar: float, beat: float, key: int, velocity: float, beats: float, early: float = 0.0) -> None:
        """One note: `velocity` 0–1 before shaping, `beats` long, `early` seconds ahead of its place (a strum, a flam)."""
        t = self.grid.time(bar, beat)
        t += self.drift.at(t) + self.rng.gauss(0, self.jitter) - early
        position = (beat % self.grid.beats)
        strength = 1.0 if position == 0 else 0.93 if position % 1 == 0 and position % 2 == 0 else 0.88 if position % 1 == 0 else 0.8
        shaped = velocity * (1 - self.accent + self.accent * strength) * (1 + self.rng.gauss(0, self.spread))
        length = beats * self.grid.beat_seconds
        self.notes.append(Note(max(0.0, t), key, int(max(1, min(127, round(shaped * 127)))), length))

    def chord(self, bar: float, beat: float, keys: Sequence[int], velocity: float, beats: float, strum: float = 0.0, up: bool = False) -> None:
        """Several keys at once; `strum` seconds between them (low to high, or high to low when `up`), the outer ones a touch louder."""
        ordered = sorted(keys, reverse=up)
        for index, key in enumerate(ordered):
            outer = 1.04 if index in (0, len(ordered) - 1) else 0.97
            self.play(bar, beat, key, velocity * outer, beats, early=-index * strum)

    def steps(self, bar: float, pattern: str, key: int, velocity: float, unit: float = 0.25, length: float = 0.2, loud: float = 1.0) -> None:
        """A rhythm in one bar from a pattern of steps `unit` beats long: `x` a hit, `X` an accent, `g` a ghost note, `.` a rest."""
        for index, symbol in enumerate(pattern.replace(" ", "")):
            if symbol == ".":
                continue
            level = {"x": velocity, "X": min(1.0, velocity * 1.25 * loud), "g": velocity * 0.45}[symbol]
            self.play(bar, index * unit, key, level, length)


def phrase(bar: int, length: int = 4, rise: float = 0.08) -> float:
    """Velocity shape over a phrase of `length` bars: up to its middle, back down; 1 ± `rise`."""
    x = (bar % length + 0.5) / length
    return 1 - rise + 2 * rise * math.sin(math.pi * x)
