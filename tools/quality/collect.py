#!/usr/bin/env python3
"""Collects what a device run of `ScriptQualityDeviceTests` kept (one JSON attachment per script or batch of ideas) into one file,
`Cue StudioTests/Fixtures/ScriptQuality/quality-run-<run>.json`, so it can be read, measured (`tools/quality/report.py`) and compared with
another run.

  TEST_RUNNER_CUE_QUALITY_RUN=<run> CUE_DEVICE=<iPhone> scripts/test.sh device ScriptQualityDeviceTests
  tools/quality/collect.py <run> build/results/device-….xcresult [more.xcresult …]

A sample found in a later xcresult replaces the same sample (kind, language, condition, index) of an earlier one, and samples already in the
file are kept unless replaced, so a run can be made of several invocations.
"""

import glob
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FOLDER = os.path.join(ROOT, "Cue StudioTests", "Fixtures", "ScriptQuality")


def key(sample):
    return (sample["kind"], sample["language"], sample["condition"], sample["index"])


def attachments(result):
    with tempfile.TemporaryDirectory() as folder:
        subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", result, "--output-path", folder],
                       check=True, capture_output=True)
        for path in sorted(glob.glob(os.path.join(folder, "*.json"))):
            if os.path.basename(path) == "manifest.json":
                continue
            with open(path, encoding="utf-8") as handle:
                data = json.load(handle)
            if isinstance(data, dict) and "kind" in data and "condition" in data:
                yield data


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(64)
    run, results = sys.argv[1], sys.argv[2:]
    os.makedirs(FOLDER, exist_ok=True)
    path = os.path.join(FOLDER, "quality-run-" + run + ".json")
    samples = {}
    if os.path.exists(path):
        with open(path, encoding="utf-8") as handle:
            samples = {key(s): s for s in json.load(handle)}
    found = 0
    for result in results:
        for sample in attachments(result):
            if sample.get("run") == run:
                samples[key(sample)] = sample
                found += 1
    out = sorted(samples.values(), key=lambda s: (s["kind"], s["language"], s["condition"], s["index"]))
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(out, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")
    print(f"{found} samples read, {len(out)} in {os.path.relpath(path, ROOT)}")


if __name__ == "__main__":
    main()
