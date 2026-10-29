"""Building blocks for Cue's sound effects made from recordings: load a take, trim it to where it sounds, pitch it, reverse it,
shape it, layer several, and level the result exactly as the app levels its effects (`SoundEffectSynth`): mono, 48 kHz, its loudest
400 ms K-weighted at −14 LUFS, never peaking above −3 dBFS, at least half a second long.
"""
from __future__ import annotations

import math
import os
from fractions import Fraction
from typing import Dict, List, Optional, Sequence, Tuple

import numpy as np
import soundfile as sf
from scipy.signal import lfilter, resample_poly, sosfilt

import dsp
from sampler import RATE

TARGET_LUFS = -14.0
PEAK = 0.708
SHORTEST = 0.5

_takes: Dict[str, np.ndarray] = {}


def take(path: str) -> np.ndarray:
    """The recording as mono float64 at 48 kHz (both channels averaged)."""
    if path not in _takes:
        data, rate = sf.read(path, dtype="float64", always_2d=True)
        mono = data.mean(axis=1)
        if rate != RATE:
            step = Fraction(RATE, rate)
            mono = resample_poly(mono, step.numerator, step.denominator)
        _takes[path] = mono
    return _takes[path].copy()


def trimmed(x: np.ndarray, floor_db: float = -50.0, pre: float = 0.002) -> np.ndarray:
    """From just before the first sample within `floor_db` of the peak to where the sound falls below that for good."""
    peak = np.max(np.abs(x)) + 1e-12
    loud = np.where(np.abs(x) > peak * 10 ** (floor_db / 20))[0]
    if not len(loud):
        return x[:0]
    start = max(0, loud[0] - int(pre * RATE))
    return x[start: loud[-1] + 1]


def seconds(x: np.ndarray) -> float:
    return len(x) / RATE


def pitched(x: np.ndarray, semitones: float) -> np.ndarray:
    """Played faster or slower (pitch and length together, like tape)."""
    if abs(semitones) < 1e-6:
        return x
    step = Fraction(2 ** (-semitones / 12)).limit_denominator(1000)
    return resample_poly(x, step.numerator, step.denominator)


def gliding(x: np.ndarray, start_semitones: float, end_semitones: float, curve: float = 1.0) -> np.ndarray:
    """Read at a speed that moves from one pitch to another over the sound (a fall, a slide)."""
    count = len(x)
    progress = np.linspace(0, 1, count) ** curve
    speed = 2 ** ((start_semitones + (end_semitones - start_semitones) * progress) / 12)
    positions = np.cumsum(speed)
    positions = positions[positions < count - 1]
    return np.interp(positions, np.arange(count), x)


def reversed_(x: np.ndarray) -> np.ndarray:
    return x[::-1].copy()


def faded(x: np.ndarray, attack: float = 0.002, release: float = 0.01, curve: float = 1.0) -> np.ndarray:
    """Straight (or curved) fades at both ends, so nothing starts or stops with a click."""
    out = x.copy()
    a, r = min(len(out), int(attack * RATE)), min(len(out), int(release * RATE))
    if a:
        out[:a] *= np.linspace(0, 1, a) ** curve
    if r:
        out[-r:] *= np.linspace(1, 0, r) ** curve
    return out


def cut(x: np.ndarray, start: float = 0.0, length: Optional[float] = None, release: float = 0.02) -> np.ndarray:
    """A piece of the take, faded out over `release` at its end."""
    piece = x[int(start * RATE): None if length is None else int((start + length) * RATE)]
    return faded(piece, attack=0.001 if start > 0 else 0.0, release=release)


def decay(x: np.ndarray, after: float, over: float) -> np.ndarray:
    """Let it ring for `after` seconds, then fall 60 dB over `over` seconds (a hand damping a cymbal)."""
    out = x.copy()
    start = int(after * RATE)
    if start >= len(out):
        return out
    tail = len(out) - start
    out[start:] *= 10 ** (-3 * np.minimum(1, np.arange(tail) / (over * RATE)))
    return out[: start + int(over * RATE)] if start + int(over * RATE) < len(out) else out


def gain(x: np.ndarray, db: float) -> np.ndarray:
    return x * 10 ** (db / 20)


def eq(x: np.ndarray, *bands) -> np.ndarray:
    return dsp.eq(np.stack([x, x], axis=1), *bands)[:, 0].astype(np.float64)


def room(x: np.ndarray, mix: float = 0.15, seconds_: float = 0.8, brightness: float = 0.5, seed: int = 9) -> np.ndarray:
    """A little space around a dry recording (the reverb's mid channel)."""
    wet = dsp.reverb(np.stack([x, x], axis=1).astype(np.float32), dsp.room(seconds_, brightness=brightness, seed=seed)).mean(axis=1)
    tail = np.zeros(len(wet))
    tail[: len(x)] = x
    return tail * (1 - mix) + wet * mix


def layer(parts: Sequence[Tuple[float, np.ndarray]]) -> np.ndarray:
    """Sounds placed at their times (seconds), summed."""
    end = max(int(at * RATE) + len(x) for at, x in parts)
    out = np.zeros(end)
    for at, x in parts:
        start = int(at * RATE)
        out[start: start + len(x)] += x
    return out


def normalized(x: np.ndarray) -> np.ndarray:
    return x / (np.max(np.abs(x)) + 1e-12)


# MARK: - The app's leveling

_HEAD = ([1.53512485958697, -2.69169618940638, 1.19839281085285], [1, -1.69065929318241, 0.73248077421585])
_LOWS = ([1, -2, 1], [1, -1.99004745483398, 0.99007225036621])


def loudness(x: np.ndarray) -> float:
    """The loudest 400 ms, K-weighted (ITU-R BS.1770 at 48 kHz), windows 10 ms apart, in LUFS: the app's `loudness(of:)`."""
    window, step = int(0.4 * RATE), int(0.01 * RATE)
    padded = np.concatenate([x, np.zeros(max(0, window - len(x)))])
    weighted = lfilter(*_LOWS, lfilter(*_HEAD, padded))
    sums = np.concatenate([[0.0], np.cumsum(weighted ** 2)])
    last = len(sums) - 1 - window
    starts = list(range(0, last, step)) + [last]
    loudest = max((sums[s + window] - sums[s]) / window for s in starts)
    return -0.691 + 10 * math.log10(loudest) if loudest > 0 else -math.inf


def leveled(x: np.ndarray) -> np.ndarray:
    """At −14 LUFS, or at the −3 dBFS peak when that comes first; at least half a second long; faded at both ends."""
    x = faded(x, attack=0.0005, release=0.004)
    x = np.concatenate([x, np.zeros(max(0, int(SHORTEST * RATE) - len(x)))])
    measured = loudness(x)
    loudest = np.max(np.abs(x))
    if not math.isfinite(measured) or loudest == 0:
        return x
    return x * min(10 ** ((TARGET_LUFS - measured) / 20), PEAK / loudest)


def measure(x: np.ndarray) -> dict:
    """What the effect does, as the app's tests would check it."""
    peak = np.max(np.abs(x))
    above = np.where(np.abs(x) > peak * 0.01)[0]
    stereo = np.stack([x, x], axis=1)
    return {
        "seconds": round(len(x) / RATE, 3),
        "lufs": round(loudness(x), 2),
        "peakDb": round(20 * math.log10(peak + 1e-12), 2),
        "startMs": round(above[0] / RATE * 1000, 1) if len(above) else None,
        "lastSoundMs": round(above[-1] / RATE * 1000, 1) if len(above) else None,
        "tailDb": round(20 * math.log10(np.max(np.abs(x[-int(0.005 * RATE):])) / max(peak, 1e-9) + 1e-12), 1),
        "clicks": dsp.clicks(stereo.astype(np.float32)),
    }


def write(name: str, x: np.ndarray, folder: str) -> dict:
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, f"{name}.wav")
    sf.write(path, x.astype(np.float32), RATE, subtype="PCM_24")
    return measure(x)


def first(paths: List[str]) -> str:
    if not paths:
        raise FileNotFoundError("no recording matched")
    return paths[0]


def wah(x: np.ndarray, notes: Sequence[Tuple[float, float]], closed_hz: float = 450.0, open_time: float = 0.12) -> np.ndarray:
    """A plunger mute: each note (start, length in seconds) starts closed (dark) and opens, then closes again at its end."""
    dark = eq(x, ("lowpass", closed_hz, 0.9))
    openness = np.zeros(len(x))
    for start, length in notes:
        a, n = int(start * RATE), int(length * RATE)
        rise = min(n, int(open_time * RATE))
        shape = np.concatenate([np.linspace(0, 1, rise), np.ones(max(0, n - 2 * rise)), np.linspace(1, 0.3, min(rise, max(0, n - rise)))])
        openness[a: a + len(shape)] = np.maximum(openness[a: a + len(shape)], shape[: max(0, len(openness) - a)])
    return dark * (1 - openness) + x * openness


def swept(x: np.ndarray, low_hz: float, high_hz: float, peak_at: float) -> np.ndarray:
    """A band that opens from `low_hz` to `high_hz` by `peak_at` (0–1 of the sound) and closes again: air moving past."""
    bands = [low_hz * (high_hz / low_hz) ** (k / 4) for k in range(5)]
    copies = [eq(x, ("lowpass", f, 0.7)) for f in bands]
    progress = np.linspace(0, 1, len(x))
    position = np.where(progress < peak_at, progress / peak_at, 1 - (progress - peak_at) / (1 - peak_at)) * (len(bands) - 1)
    out = np.zeros(len(x))
    for k, copy in enumerate(copies):
        weight = np.clip(1 - np.abs(position - k), 0, 1)
        out += copy * weight
    return out


def scratched(x: np.ndarray, moves: Sequence[Tuple[float, float]], start_at: float = 0.0) -> np.ndarray:
    """A record moved by hand from `start_at` seconds into `x`: `moves` are (seconds, speed) points (1 is normal play, negative is
    backwards), eased between them."""
    times = np.array([t for t, _ in moves])
    speeds = np.array([s for _, s in moves])
    count = int(times[-1] * RATE)
    speed = np.interp(np.arange(count) / RATE, times, speeds)
    position = np.clip(start_at * RATE + np.cumsum(speed), 0, len(x) - 2)
    return np.interp(position, np.arange(len(x)), x)
