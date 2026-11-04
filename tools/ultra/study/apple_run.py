#!/usr/bin/env python3
"""Writes the Ultra study's cases with Apple Intelligence on an iPhone (`AppleStudyDeviceTests`), as it is ("0") and with the study's
improvements ("1": `ScriptPromptBuilder.definesFormats` and `followsIdeaKind`), and saves each script in the study's record shape in
<out>/out/<job id>.json, where blind.py, score.py and metrics.py read it. Jobs go to the iPhone a few at a time (a device run has a time
allowance and the jobs travel in an environment variable); a job already saved is not written again, so a stopped run resumes.

    tools/ultra/study/apple_run.py --cases tools/ultra/study/cases/phase4.json --route onDevice --device "iago Lima iphone" --out <folder>
        [--only c4-card-…,…] [--arms 0,1] [--windows 75-105,105-150,75-150] [--batch 8] [--no-build] [--parallel]

The arm is named by the route and the arm: D0/D1 on the device's model, P0/P1 on Private Cloud Compute; a window of seconds inside the
network's 1:15–2:30 (`AppleScriptLength.window`) adds it, as D1w105-150, and asks for it in words (`targetsWindow`: on Auto the app's
request says no length, so the window alone would change nothing the model reads). The iPhone must be unlocked with
the screen on (scripts/test.sh refuses a locked one). Only cases an improvement changes are worth both arms: a chosen format or talking
head (format definitions) and an idea from the cards on Auto (the idea's kind).
"""
import argparse
import re
import base64
import glob
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
IMPROVEMENTS = ["formatDefinitions", "ideaKind"]
# The arms: as the app is ("0"), both improvements ("1"), the idea's kind alone ("k": round 2, after the format definitions lost on both routes).
ARMS = {"0": [], "1": IMPROVEMENTS, "k": ["ideaKind"]}


def jobs_for(cases, route, arms, windows):
    prefix = "D" if route == "onDevice" else "P"
    jobs = []
    for case in cases:
        for arm in arms:
            for window in windows or [None]:
                config = f"{prefix}{arm}" + (f"w{window[0]}-{window[1]}" if window else "")
                jobs.append({"id": f"apple_{case['id']}_{config}", "case": case, "route": route,
                             "variants": ARMS[arm] + (["targetsWindow"] if window else []), "config": config,
                             "window": list(window) if window else None})
    return jobs


def export(result, out_folder):
    """Saves every job record attached to `result` in <out>/out; returns how many."""
    saved = 0
    with tempfile.TemporaryDirectory() as folder:
        subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", result, "--output-path", folder],
                       check=True, capture_output=True)
        for path in glob.glob(os.path.join(folder, "*.json")):
            if os.path.basename(path) == "manifest.json":
                continue
            with open(path, encoding="utf-8") as handle:
                record = json.load(handle)
            if not (isinstance(record, dict) and "job" in record and "appDraftPrompt" in record):
                continue
            with open(os.path.join(out_folder, record["job"]["id"] + ".json"), "w", encoding="utf-8") as handle:
                json.dump(record, handle, ensure_ascii=False, indent=1)
            saved += 1
    return saved


def device_tag(device, parallel):
    """How scripts/test.sh names a run that took its iPhone's own lock (CUE_DEVICE_OWN_LOCK), or "" for a run in the Mac's queue."""
    return "-" + re.sub(r"[^A-Za-z0-9]", "", device) if parallel else ""


def newest_result(tag=""):
    pattern = re.compile(r"device" + re.escape(tag) + r"-\d{8}-\d{6}\.xcresult$")
    results = [p for p in glob.glob(os.path.join(ROOT, "build", "results", "device*.xcresult")) if pattern.search(p)]
    return max(results, key=os.path.getmtime) if results else None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cases", required=True)
    parser.add_argument("--route", required=True, choices=["onDevice", "privateCloud"])
    parser.add_argument("--device", required=True, help="the iPhone's name or id (xcrun devicectl list devices)")
    parser.add_argument("--out", required=True, help="the study folder; records go to <out>/out")
    parser.add_argument("--only", default="", help="comma-separated case ids (default all)")
    parser.add_argument("--arms", default="0,1")
    parser.add_argument("--windows", default="", help="seconds inside the network's range, e.g. 75-105,105-150 (default the app's)")
    parser.add_argument("--batch", type=int, default=8)
    parser.add_argument("--no-build", action="store_true", help="reuse the last device build from the first batch on")
    parser.add_argument("--parallel", action="store_true",
                        help="with --no-build: run beside another iPhone's run (its own lock in scripts/test.sh); split the jobs with --only")
    args = parser.parse_args()
    if args.parallel and not args.no_build:
        sys.exit("--parallel needs --no-build: a build waits for every other xcodebuild on the Mac.")
    tag = device_tag(args.device, args.parallel)

    cases = json.load(open(args.cases))
    only = {c for c in args.only.split(",") if c}
    if only:
        cases = [c for c in cases if c["id"] in only]
    out_folder = os.path.join(args.out, "out")
    os.makedirs(out_folder, exist_ok=True)
    windows = [tuple(int(x) for x in w.split("-")) for w in args.windows.split(",") if w]
    jobs = jobs_for(cases, args.route, [a for a in args.arms.split(",") if a], windows)
    pending = [j for j in jobs if not os.path.exists(os.path.join(out_folder, j["id"] + ".json"))]
    print(f"{len(jobs)} jobs, {len(pending)} to write on {args.device} ({args.route})")
    built = args.no_build
    for start in range(0, len(pending), args.batch):
        batch = pending[start:start + args.batch]
        env = dict(os.environ, CUE_DEVICE=args.device,
                   TEST_RUNNER_CUE_APPLE_STUDY_JOBS=base64.b64encode(json.dumps(batch, ensure_ascii=False).encode()).decode())
        if args.parallel:
            env["CUE_DEVICE_OWN_LOCK"] = "1"
        command = [os.path.join(ROOT, "scripts", "test.sh"), "device", "AppleStudyDeviceTests"] + (["--no-build"] if built else [])
        before = newest_result(tag)
        run = subprocess.run(command, cwd=ROOT, env=env)
        built = True
        result = newest_result(tag)
        if result is None or result == before:
            sys.exit(f"No result bundle from the batch starting at {start} (exit {run.returncode}); stopped.")
        saved = export(result, out_folder)
        print(f"batch {start // args.batch + 1}: {saved} of {len(batch)} saved (exit {run.returncode})")
        if saved == 0:
            sys.exit("Nothing saved from this batch: is the iPhone unlocked and Apple Intelligence on? Stopped.")
    done = sum(os.path.exists(os.path.join(out_folder, j["id"] + ".json")) for j in jobs)
    print(f"{done} of {len(jobs)} jobs saved in {out_folder}")


if __name__ == "__main__":
    main()
