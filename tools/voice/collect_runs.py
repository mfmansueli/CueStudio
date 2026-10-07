#!/usr/bin/env python3
"""Collects the scripts a device run of `VoicePersonaDeviceTests` kept (one JSON attachment per persona) into one file,
`Cue StudioTests/Fixtures/VoiceRuns/voice-run-<run>.json`, so the run can be compared with another (`VoiceRunReportTests`).

  scripts/test.sh device VoicePersonaDeviceTests          (with TEST_RUNNER_CUE_VOICE_RUN=<run>)
  tools/voice/collect_runs.py <run> build/results/device-….xcresult [more.xcresult …]

Every xcresult given is read; a script found in a later one replaces the same script (same creator, idea and condition) of an earlier
one. Only scripts of the named run are kept.
"""

import glob
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def attachments(result):
    """The decoded JSON arrays attached to one xcresult."""
    with tempfile.TemporaryDirectory() as folder:
        subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", result, "--output-path", folder],
                       check=True, capture_output=True)
        for path in sorted(glob.glob(os.path.join(folder, "*.json"))):
            if os.path.basename(path) == "manifest.json":
                continue
            with open(path, encoding="utf-8") as handle:
                data = json.load(handle)
            if isinstance(data, list) and data and "persona" in data[0]:
                yield data
            elif isinstance(data, dict) and "persona" in data and "condition" in data:
                # One script kept as soon as it was written (`voice-sample-…`): what a run that died still has.
                yield [data]


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(64)
    run, results = sys.argv[1], sys.argv[2:]
    # One script is identified by who it is for, which idea and which condition; a later copy replaces an earlier one.
    scripts = {}
    for result in results:
        for samples in attachments(result):
            for sample in samples:
                if sample.get("run") == run:
                    scripts[(sample["persona"], sample["ideaIndex"], sample["condition"])] = sample
    by_persona = {}
    for sample in scripts.values():
        by_persona.setdefault(sample["persona"], []).append(sample)
    out = [sample for persona in sorted(by_persona) for sample in sorted(by_persona[persona], key=lambda s: (s["ideaIndex"], s["condition"]))]
    folder = os.path.join(ROOT, "Cue StudioTests", "Fixtures", "VoiceRuns")
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, "voice-run-" + run + ".json")
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(out, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")
    print("%d scripts of %d creators → %s" % (len(out), len(by_persona), os.path.relpath(path, ROOT)))


if __name__ == "__main__":
    main()
