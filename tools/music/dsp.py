"""Mixing and mastering for the tracks: equalizers, panning, a compressor, a room reverb, tape warmth, a true-peak limiter and loudness.

Everything works on stereo float buffers at `sampler.RATE`, whole-buffer (offline), so each step is vectorized rather than sample by sample.
"""
from __future__ import annotations

import math
from fractions import Fraction
from typing import List, Optional, Tuple

import numpy as np
import pyloudnorm
from scipy.ndimage import maximum_filter1d, uniform_filter1d
from scipy.signal import fftconvolve, lfilter, resample_poly, sosfilt

from sampler import RATE


# MARK: - Equalizer (RBJ cookbook biquads)

def _biquad(kind: str, frequency: float, q: float = 0.707, gain_db: float = 0.0) -> np.ndarray:
    w = 2 * math.pi * frequency / RATE
    alpha = math.sin(w) / (2 * q)
    a = 10 ** (gain_db / 40)
    cos = math.cos(w)
    if kind == "lowpass":
        b = [(1 - cos) / 2, 1 - cos, (1 - cos) / 2]
        d = [1 + alpha, -2 * cos, 1 - alpha]
    elif kind == "highpass":
        b = [(1 + cos) / 2, -(1 + cos), (1 + cos) / 2]
        d = [1 + alpha, -2 * cos, 1 - alpha]
    elif kind == "peak":
        b = [1 + alpha * a, -2 * cos, 1 - alpha * a]
        d = [1 + alpha / a, -2 * cos, 1 - alpha / a]
    elif kind == "lowshelf":
        root = 2 * math.sqrt(a) * alpha
        b = [a * ((a + 1) - (a - 1) * cos + root), 2 * a * ((a - 1) - (a + 1) * cos), a * ((a + 1) - (a - 1) * cos - root)]
        d = [(a + 1) + (a - 1) * cos + root, -2 * ((a - 1) + (a + 1) * cos), (a + 1) + (a - 1) * cos - root]
    elif kind == "highshelf":
        root = 2 * math.sqrt(a) * alpha
        b = [a * ((a + 1) + (a - 1) * cos + root), -2 * a * ((a - 1) + (a + 1) * cos), a * ((a + 1) + (a - 1) * cos - root)]
        d = [(a + 1) - (a - 1) * cos + root, 2 * ((a - 1) - (a + 1) * cos), (a + 1) - (a - 1) * cos - root]
    else:
        raise ValueError(kind)
    return np.array([[b[0] / d[0], b[1] / d[0], b[2] / d[0], 1.0, d[1] / d[0], d[2] / d[0]]])


def eq(x: np.ndarray, *bands: Tuple) -> np.ndarray:
    """Bands as (kind, frequency[, q[, gain dB]]): `eq(x, ("highpass", 40), ("peak", 3000, 1.0, -3))`."""
    if not bands:
        return x
    sos = np.vstack([_biquad(*band) for band in bands])
    return sosfilt(sos, x, axis=0).astype(np.float32)


# MARK: - Space

def pan(x: np.ndarray, position: float) -> np.ndarray:
    """−1 left … 1 right, constant power (a centred source keeps its level)."""
    angle = (position + 1) * math.pi / 4
    return (x * np.array([math.cos(angle), math.sin(angle)], dtype=np.float32) * math.sqrt(2)).astype(np.float32)


def width(x: np.ndarray, amount: float) -> np.ndarray:
    """Side signal scaled: 0 mono, 1 as is, above 1 wider."""
    mid = (x[:, 0] + x[:, 1]) / 2
    side = (x[:, 0] - x[:, 1]) / 2 * amount
    return np.stack([mid + side, mid - side], axis=1).astype(np.float32)


def room(seconds: float = 2.0, predelay: float = 0.018, brightness: float = 0.5, seed: int = 7) -> np.ndarray:
    """A stereo room's impulse response: a few early reflections, then a diffuse tail whose highs die sooner than its lows (as air and
    walls absorb them), left and right uncorrelated so it widens what it carries."""
    random = np.random.default_rng(seed)
    length = int((seconds + predelay) * RATE)
    t = np.arange(length) / RATE
    ir = np.zeros((length, 2), dtype=np.float64)
    # Diffuse tail in three bands, each with its own decay (RT60).
    bands = [(("lowpass", 400), seconds * 1.15), (("peak", 1500, 0.5, 0), seconds), (("highpass", 3500), seconds * (0.35 + 0.4 * brightness))]
    start = int(predelay * RATE)
    for channel in range(2):
        noise = random.standard_normal(length)
        tail = np.zeros(length)
        for band, rt in bands:
            filtered = sosfilt(_biquad(*band), noise)
            tail += filtered * np.exp(-6.9 * np.maximum(0, t - predelay) / rt)
        tail[:start] = 0
        # Onset of the tail: a short swell rather than a wall.
        swell = np.clip((t - predelay) / 0.03, 0, 1)
        ir[:, channel] = tail * swell
        for _ in range(8):
            delay = predelay * 0.3 + random.uniform(0.004, 0.045)
            ir[int(delay * RATE), channel] += random.uniform(0.3, 0.7) * random.choice([-1, 1])
    ir /= np.sqrt(np.sum(ir ** 2) / 2)
    return ir.astype(np.float32)


def reverb(x: np.ndarray, ir: np.ndarray) -> np.ndarray:
    """`x` (the send) through the room, wet only: its middle into both sides of the stereo room."""
    mid = x.mean(axis=1)
    return np.stack([fftconvolve(mid, ir[:, 0])[: len(x)], fftconvolve(mid, ir[:, 1])[: len(x)]], axis=1).astype(np.float32)


def wow(x: np.ndarray, cents: float, rate: float, seed: int = 3) -> np.ndarray:
    """Tape wow and flutter: the pitch swaying `cents` at `rate` Hz (plus a faster, smaller flutter), by a moving read position."""
    t = np.arange(len(x)) / RATE
    random = np.random.default_rng(seed)
    phase = random.uniform(0, 2 * math.pi)
    # A pitch change of c cents for a delay that moves as A·sin(2πft) needs A = c·ln2 / (1200 · 2πf).
    sway = cents * math.log(2) / 1200 / (2 * math.pi * rate) * np.sin(2 * math.pi * rate * t + phase)
    flutter = cents * 0.15 * math.log(2) / 1200 / (2 * math.pi * 7.3) * np.sin(2 * math.pi * 7.3 * t)
    delay = 0.004 + sway + flutter
    positions = np.arange(len(x)) - delay * RATE
    return np.stack([np.interp(positions, np.arange(len(x)), x[:, c]) for c in range(2)], axis=1).astype(np.float32)


def vinyl(seconds: float, level_db: float = -40.0, seed: int = 5) -> np.ndarray:
    """A record's surface: sparse crackles (each a tiny filtered click) over a soft, dull hiss. Made here, not recorded."""
    random = np.random.default_rng(seed)
    length = int(seconds * RATE)
    out = np.zeros((length, 2), dtype=np.float64)
    hiss = random.standard_normal((length, 2))
    hiss = sosfilt(np.vstack([_biquad("lowpass", 3500, 0.6), _biquad("highpass", 300, 0.6)]), hiss, axis=0) * 0.25
    clicks = np.zeros((length, 2))
    count = int(seconds * 9)
    places = random.integers(0, length, count)
    sizes = random.pareto(2.5, count) * 0.15
    sides = random.random(count)
    for place, size, side in zip(places, sizes, sides):
        clicks[place, 0] += size * random.choice([-1, 1]) * (1.0 if side < 0.7 else 0.4)
        clicks[place, 1] += size * random.choice([-1, 1]) * (1.0 if side > 0.3 else 0.4)
    clicks = sosfilt(np.vstack([_biquad("highpass", 900, 0.7), _biquad("lowpass", 7000, 0.7)]), clicks, axis=0)
    out = hiss + clicks * 6
    out *= 10 ** (level_db / 20) / (np.sqrt(np.mean(out ** 2)) + 1e-12)
    return out.astype(np.float32)


# MARK: - Dynamics

def envelope(x: np.ndarray, attack: float, release: float) -> np.ndarray:
    """The level of `x` (its louder channel), following rises in `attack` seconds and falls in `release`: a peak-hold over the attack,
    then a one-pole fall."""
    level = np.max(np.abs(x), axis=1)
    held = maximum_filter1d(level, size=max(1, int(attack * RATE)), origin=0)
    smooth = uniform_filter1d(held, size=max(1, int(attack * RATE)))
    pole = math.exp(-1 / (release * RATE))
    falling = lfilter([1 - pole], [1, -pole], smooth)
    return np.maximum(smooth, falling)


def compress(x: np.ndarray, threshold_db: float, ratio: float, attack: float = 0.01, release: float = 0.15,
             knee_db: float = 6.0, key: Optional[np.ndarray] = None) -> np.ndarray:
    """A feed-forward compressor with a soft knee; `key` compresses `x` by another signal's level (side-chain)."""
    level_db = 20 * np.log10(np.maximum(envelope(key if key is not None else x, attack, release), 1e-9))
    over = level_db - threshold_db
    soft = np.where(over <= -knee_db / 2, 0.0,
                    np.where(over >= knee_db / 2, over, (over + knee_db / 2) ** 2 / (2 * knee_db)))
    reduction = soft * (1 - 1 / ratio)
    gain = 10 ** (-reduction / 20)
    return (x * gain[:, None]).astype(np.float32)


def warmth(x: np.ndarray, drive: float = 1.5) -> np.ndarray:
    """Tape-like saturation: the peaks rounded, a little second harmonic, level kept."""
    peak = float(np.max(np.abs(x))) or 1.0
    shaped = np.tanh(drive * (x / peak + 0.04 * (x / peak) ** 2)) / math.tanh(drive)
    shaped -= np.mean(shaped, axis=0)
    return (shaped * peak).astype(np.float32)


def true_peak(x: np.ndarray) -> float:
    """The highest level between samples, in dBTP (4× oversampled, as BS.1770 measures it)."""
    over = resample_poly(x, 4, 1, axis=0)
    return 20 * math.log10(max(float(np.max(np.abs(over))), 1e-12))


def limit(x: np.ndarray, ceiling_db: float = -1.0, lookahead: float = 0.005, hold: float = 0.06) -> np.ndarray:
    """A look-ahead limiter that keeps the oversampled peaks under the ceiling: the gain a peak needs is reached `lookahead` before
    it, held `hold` after it, and moves smoothly in between (no gain step, so no distortion of its own)."""
    ceiling = 10 ** (ceiling_db / 20)
    over = np.max(np.abs(resample_poly(x, 4, 1, axis=0)), axis=1)[: 4 * len(x)].reshape(-1, 4).max(axis=1)
    needed = np.minimum(1.0, ceiling / np.maximum(over, 1e-12))
    ahead, after = max(1, int(lookahead * RATE)), max(1, int(hold * RATE))
    centred = -maximum_filter1d(-needed, size=ahead + after + 1, mode="nearest")
    # The centred window moved to cover [n − hold, n + lookahead].
    shift = (after - ahead) // 2
    floor = np.concatenate([np.full(shift, centred[0]), centred[: len(centred) - shift]]) if shift > 0 else centred
    gain = np.minimum(uniform_filter1d(floor, size=ahead, mode="nearest"), needed)
    return (x * gain[:, None]).astype(np.float32)


def loudness(x: np.ndarray) -> float:
    return float(pyloudnorm.Meter(RATE).integrated_loudness(x.astype(np.float64)))


def master(x: np.ndarray, target_lufs: float = -16.0, ceiling_db: float = -1.0) -> np.ndarray:
    """Set to the target loudness with peaks under the ceiling: gain, limit, measure again (the limiter takes a little off)."""
    out = x
    for _ in range(3):
        out = out * (10 ** ((target_lufs - loudness(out)) / 20))
        out = limit(out, ceiling_db)
        if abs(loudness(out) - target_lufs) < 0.1:
            break
    return out.astype(np.float32)


# MARK: - Measuring

def band_share(x: np.ndarray, low: float, high: float) -> float:
    """How much of the energy lies between `low` and `high` Hz, in dB of the whole."""
    mono = x.mean(axis=1)
    spectrum = np.abs(np.fft.rfft(mono)) ** 2
    freqs = np.fft.rfftfreq(len(mono), 1 / RATE)
    inside = spectrum[(freqs >= low) & (freqs < high)].sum()
    return 10 * math.log10(max(inside, 1e-20) / max(spectrum.sum(), 1e-20))


def clicks(x: np.ndarray, threshold: float = 0.25) -> int:
    """Sample-to-sample jumps far above what the music around them does: discontinuities a listener hears as clicks."""
    jumps = np.abs(np.diff(x, axis=0)).max(axis=1)
    local = uniform_filter1d(jumps, size=480) + 1e-4
    return int(np.sum((jumps > threshold) & (jumps > 12 * local)))


def active_level(x: np.ndarray, window: float = 0.4) -> float:
    """RMS in dB over the windows where it plays (within 30 dB of its loudest), not diluted by its silences."""
    size = int(window * RATE)
    count = len(x) // size
    if count == 0:
        return -150.0
    blocks = (x[: count * size] ** 2).mean(axis=1).reshape(count, size).mean(axis=1)
    loud = blocks.max()
    if loud <= 0:
        return -150.0
    playing = blocks[blocks > loud * 10 ** (-30 / 10)]
    return 10 * math.log10(playing.mean())


def fit(x: np.ndarray, seconds: float) -> np.ndarray:
    return x[: int(seconds * RATE)]


def stems_sum(stems: List[np.ndarray]) -> np.ndarray:
    length = max(len(s) for s in stems)
    out = np.zeros((length, 2), dtype=np.float32)
    for stem in stems:
        out[: len(stem)] += stem
    return out


def resample_to(x: np.ndarray, rate: int) -> np.ndarray:
    step = Fraction(rate, RATE)
    return resample_poly(x, step.numerator, step.denominator, axis=0).astype(np.float32)
