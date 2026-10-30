#!/usr/bin/env python3
"""Collects what a device run of `UltraDeviceTests` kept (one JSON attachment per Ultra AI script, synthetic data only) into
`research_notes/Ultra AI/ultra-device-<run>.json`, with a short table of each script's length to read before the texts.

  CUE_DEVICE="iago Lima iphone" scripts/test.sh device UltraDeviceTests
  tools/ultra/collect.py <run> build/results/device-….xcresult [more.xcresult …]

A sample found in a later xcresult replaces the one of the same name from an earlier one; samples already in the file are kept unless replaced.
The seconds are an estimate from the word count at 150 words a minute, never a person reading the script.
"""

import glob
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FOLDER = os.path.join(ROOT, "research_notes", "Ultra AI")


def attachments(result):
    with tempfile.TemporaryDirectory() as folder:
        subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", result, "--output-path", folder],
                       check=True, capture_output=True)
        for path in sorted(glob.glob(os.path.join(folder, "*.json"))):
            if os.path.basename(path) == "manifest.json":
                continue
            with open(path, encoding="utf-8") as handle:
                data = json.load(handle)
            if isinstance(data, dict) and "script" in data and "draftPrompt" in data:
                yield data


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(64)
    run, results = sys.argv[1], sys.argv[2:]
    os.makedirs(FOLDER, exist_ok=True)
    path = os.path.join(FOLDER, "ultra-device-" + run + ".json")
    samples = {}
    if os.path.exists(path):
        with open(path, encoding="utf-8") as handle:
            samples = {s["name"]: s for s in json.load(handle)}
    for result in results:
        for sample in attachments(result):
            samples[sample["name"]] = sample
    out = sorted(samples.values(), key=lambda s: s["name"])
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(out, handle, ensure_ascii=False, indent=2, sort_keys=True)
    print(f"{len(out)} scripts in {os.path.relpath(path, ROOT)}")
    print(f"{'case':<26}{'length asked':<24}{'words':>6}{'≈ s':>6}{'draft s':>9}{'polish s':>10}")
    for s in out:
        print(f"{s['name']:<26}{s['length']:<24}{s['words']:>6}{round(s['estimatedSeconds']):>6}"
              f"{s['draftSeconds']:>9.1f}{s['reviewSeconds']:>10.1f}")


if __name__ == "__main__":
    main()
