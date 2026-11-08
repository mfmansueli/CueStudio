#!/usr/bin/env python3
"""Loudness and true peak of exported sounds (E4 audio, owner 07/11/2026: measure in the file before any normalization).

    TEST_RUNNER_CUE_LOUDNESS_DIR=<folder> scripts/test.sh only "Cue StudioTests/RealExports/LoudnessReportExportTests"
    <venv>/bin/python tools/audio/loudness_report.py <folder>

The venv is the music tools' one (tools/music/README.md: numpy, scipy, soundfile, pyloudnorm). Each exported .mov in the folder has its AAC
decoded with ffmpeg (brew install ffmpeg) to 32-bit float, then measured as BS.1770-4 says: integrated loudness (pyloudnorm, K-weighted, gated), true peak (4×
oversampled), sample peak and the loudest 3 s (short-term). Prints a Markdown table and writes loudness.json next to the sounds.
"""
from __future__ import annotations

import json
import math
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
import pyloudnorm
import soundfile
from scipy.signal import resample_poly


def decoded(path: Path, folder: Path) -> tuple[np.ndarray, int]:
    wav = folder / (path.stem + ".wav")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(path), "-vn", "-c:a", "pcm_f32le", str(wav)], check=True, capture_output=True)
    data, rate = soundfile.read(str(wav), always_2d=True, dtype="float64")
    return data, rate


def db(value: float) -> float:
    return 20 * math.log10(max(value, 1e-12))


def measure(data: np.ndarray, rate: int) -> dict:
    meter = pyloudnorm.Meter(rate)
    integrated = meter.integrated_loudness(data)
    window, hop = 3 * rate, rate // 10
    short = [meter.integrated_loudness(data[start:start + window]) for start in range(0, max(1, len(data) - window), hop)] if len(data) > window else []
    short = [value for value in short if math.isfinite(value)]
    over = resample_poly(data, 4, 1, axis=0)
    return {
        "seconds": round(len(data) / rate, 2),
        "channels": data.shape[1],
        "integrated_lufs": round(integrated, 1),
        "true_peak_dbtp": round(db(float(np.max(np.abs(over)))), 1),
        "sample_peak_dbfs": round(db(float(np.max(np.abs(data)))), 1),
        "short_term_max_lufs": round(max(short), 1) if short else None,
    }


def main() -> None:
    folder = Path(sys.argv[1])
    results = {}
    with tempfile.TemporaryDirectory() as scratch:
        for path in sorted(folder.glob("*.mov")):
            data, rate = decoded(path, Path(scratch))
            results[path.stem] = measure(data, rate)
    (folder / "loudness.json").write_text(json.dumps(results, indent=2))
    print("| Sound | s | LUFS | True peak dBTP | Sample peak dBFS | Loudest 3 s LUFS |")
    print("|---|---|---|---|---|---|")
    for name, row in results.items():
        print(f"| {name} | {row['seconds']} | {row['integrated_lufs']} | {row['true_peak_dbtp']} | {row['sample_peak_dbfs']} | {row['short_term_max_lufs']} |")


if __name__ == "__main__":
    main()
