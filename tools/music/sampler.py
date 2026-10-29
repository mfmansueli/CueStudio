"""A small offline sampler: plays notes on recorded instruments (multisampled WAV or FLAC), the way an SFZ player would.

An instrument is a list of zones: a recording, the key it was played at, the keys and velocities it covers and its round-robin slot. A note
picks the zone for its key and velocity (the next round robin each time the same cell plays), is pitched from the recording by band-limited
resampling, scaled by its velocity, held for its length and faded out over the instrument's release. Drums ring out (`one_shot`) unless a
later hit of the same choke group cuts them (a closed hi-hat stops an open one).
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field
from fractions import Fraction
from typing import Callable, Dict, List, Optional, Tuple

import numpy as np
import soundfile as sf
from scipy.signal import resample_poly

RATE = 48_000


@dataclass
class Zone:
    path: str
    root: int
    lokey: int
    hikey: int
    lovel: int = 1
    hivel: int = 127
    rr: int = 0
    gain: float = 1.0
    tune: float = 0.0
    offset: int = 0


@dataclass
class Instrument:
    name: str
    zones: List[Zone]
    release: float = 0.3
    one_shot: bool = False
    # How much a note's velocity changes its level on top of the layer it picks (0: not at all, 1: velocity squared, as SFZ does).
    veltrack: float = 0.5
    # Seconds a one-shot rings at most.
    max_length: Optional[float] = None
    # Release by key, for instruments whose top keys have no dampers (a piano).
    release_for_key: Optional[Callable[[int], float]] = None
    # Key → choke group: a hit cuts the notes of its group still ringing.
    chokes: Dict[int, int] = field(default_factory=dict)
    # Time-align the two channels of each recording (a spaced microphone pair): the image keeps its left–right balance, and the
    # channels no longer cancel each other when the music plays on one speaker.
    align: bool = False


@dataclass
class Note:
    time: float
    key: int
    velocity: int
    length: float


_recordings: Dict[Tuple[str, bool], np.ndarray] = {}
_pitched: Dict[Tuple[str, int, float, int, bool], np.ndarray] = {}


def recording(path: str, align: bool = False) -> np.ndarray:
    """The file as stereo float32 at `RATE`; with `align`, the right channel moved to line up with the left."""
    if (path, align) not in _recordings:
        data, rate = sf.read(path, dtype="float32", always_2d=True)
        if data.shape[1] == 1:
            data = np.repeat(data, 2, axis=1)
        data = data[:, :2]
        if rate != RATE:
            step = Fraction(RATE, rate)
            data = resample_poly(data, step.numerator, step.denominator, axis=0).astype(np.float32)
        if align:
            data = _aligned(data)
        _recordings[(path, align)] = data
    return _recordings[(path, align)]


def _aligned(data: np.ndarray, most: float = 0.0015) -> np.ndarray:
    """The right channel shifted by the lag (up to `most` seconds) that best matches the left over the first half second."""
    head = data[: RATE // 2]
    reach = int(most * RATE)
    left, right = head[:, 0], head[:, 1]
    scores = [float(np.dot(left[reach:-reach], np.roll(right, lag)[reach:-reach])) for lag in range(-reach, reach + 1)]
    lag = int(np.argmax(scores)) - reach
    if lag == 0:
        return data
    moved = np.roll(data[:, 1], lag)
    if lag > 0:
        moved[:lag] = 0
    else:
        moved[lag:] = 0
    return np.stack([data[:, 0], moved], axis=1).astype(np.float32)


def pitched(zone: Zone, key: int, align: bool = False) -> np.ndarray:
    """The zone's recording moved from its root to `key` (and its tuning), band-limited."""
    cache = (zone.path, key, zone.tune, zone.offset, align)
    if cache not in _pitched:
        data = recording(zone.path, align)[zone.offset:]
        semitones = key - zone.root + zone.tune / 100
        if abs(semitones) < 1e-6:
            moved = data
        else:
            # Played faster by 2^(s/12): fewer samples, so resample by its inverse.
            step = Fraction(2 ** (-semitones / 12)).limit_denominator(2000)
            moved = resample_poly(data, step.numerator, step.denominator, axis=0).astype(np.float32)
        _pitched[cache] = moved
    return _pitched[cache]


def pick(instrument: Instrument, key: int, velocity: int, turns: Dict[Tuple[int, int, int], int]) -> Optional[Zone]:
    """The zone for the key and velocity; the nearest velocity layer if none covers it; the next round robin of the cell."""
    for_key = [z for z in instrument.zones if z.lokey <= key <= z.hikey]
    if not for_key:
        return None
    layer = [z for z in for_key if z.lovel <= velocity <= z.hivel]
    if not layer:
        nearest = min(for_key, key=lambda z: min(abs(z.lovel - velocity), abs(z.hivel - velocity)))
        layer = [z for z in for_key if (z.lovel, z.hivel) == (nearest.lovel, nearest.hivel)]
    cell = (layer[0].lokey, layer[0].lovel, layer[0].hivel)
    slots = sorted(layer, key=lambda z: z.rr)
    turn = turns.get(cell, 0)
    turns[cell] = turn + 1
    return slots[turn % len(slots)]


def render(instrument: Instrument, notes: List[Note], seconds: float) -> np.ndarray:
    """The notes played on the instrument, as a stereo buffer `seconds` long."""
    out = np.zeros((int(seconds * RATE) + 1, 2), dtype=np.float32)
    turns: Dict[Tuple[int, int, int], int] = {}
    ordered = sorted(notes, key=lambda n: n.time)
    cut_at = _choke_times(instrument, ordered)
    for index, note in enumerate(ordered):
        zone = pick(instrument, note.key, note.velocity, turns)
        if zone is None:
            continue
        source = pitched(zone, note.key, instrument.align)
        release = instrument.release_for_key(note.key) if instrument.release_for_key else instrument.release
        if instrument.one_shot:
            length = len(source)
            if instrument.max_length:
                length = min(length, int(instrument.max_length * RATE))
            held = length
        else:
            held = int(max(0.0, note.length) * RATE)
            length = min(len(source), held + int(release * RATE))
        if index in cut_at:
            # Cut by a later hit of its choke group: a quick fade from there.
            held = min(held, max(0, int((cut_at[index] - note.time) * RATE)))
            release = 0.03
            length = min(length, held + int(release * RATE))
        if length <= 0:
            continue
        envelope = np.ones(length, dtype=np.float32)
        attack = min(length, 48)
        envelope[:attack] = np.linspace(0, 1, attack, dtype=np.float32)
        if held < length:
            fade = length - held
            # Down 60 dB over the release, linear in decibels, then a few samples to silence.
            envelope[held:] *= (10 ** (-3 * np.linspace(0, 1, fade))).astype(np.float32)
            tail = min(fade, 64)
            envelope[length - tail:] *= np.linspace(1, 0, tail, dtype=np.float32)
        level = zone.gain * ((1 - instrument.veltrack) + instrument.veltrack * (note.velocity / 127) ** 2)
        start = int(round(note.time * RATE))
        end = min(len(out), start + length)
        if end <= start:
            continue
        out[start:end] += source[: end - start] * (envelope[: end - start, None] * level)
    return out


def _choke_times(instrument: Instrument, ordered: List[Note]) -> Dict[int, float]:
    """For each note a later hit of its choke group cuts, when."""
    if not instrument.chokes:
        return {}
    cut: Dict[int, float] = {}
    ringing: Dict[int, int] = {}
    for index, note in enumerate(ordered):
        group = instrument.chokes.get(note.key)
        if group is None:
            continue
        if group in ringing and ordered[ringing[group]].time < note.time:
            cut[ringing[group]] = note.time
        ringing[group] = index
    return cut


NOTE_NAMES = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9,
              "A#": 10, "Bb": 10, "B": 11}


def midi(name: str) -> int:
    """`C4` → 60 (scientific pitch: C4 is middle C)."""
    head = name[:2] if len(name) > 1 and name[1] in "#b" else name[:1]
    return NOTE_NAMES[head] + 12 * (int(name[len(head):]) + 1)


def spread(roots: List[int]) -> List[Tuple[int, int, int]]:
    """Key ranges for recordings made every few keys: each covers from halfway to the one below to halfway to the one above."""
    roots = sorted(roots)
    ranges = []
    for index, root in enumerate(roots):
        low = 0 if index == 0 else (roots[index - 1] + root) // 2 + 1
        high = 127 if index == len(roots) - 1 else (root + roots[index + 1]) // 2
        ranges.append((root, low, high))
    return ranges


def db(value: float) -> float:
    return 20 * math.log10(max(value, 1e-12))
